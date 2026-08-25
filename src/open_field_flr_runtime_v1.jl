struct OpenFieldFLRProblemV1
    candidate_binding_hash::String
    state_result_hash::String
    resolution_id::String
    perpendicular_wavenumber_m_inv::Vector{Float64}
    perpendicular_temperature_j::Vector{Float64}
    magnetic_field_t::Vector{Float64}
    species_mass_kg::Float64
    absolute_charge_c::Float64
    angular_quadrature_count::Int
    source_artifact_paths::Vector{String}
    source_artifact_hashes::Vector{String}
    validity_domain_covered::Bool
    claim_boundary::String
    problem_hash::String
end

struct OpenFieldFLRObservationV1
    candidate_binding_hash::String
    state_result_hash::String
    resolution_id::String
    b_parameter::Vector{Float64}
    gamma0::Vector{Float64}
    gamma1::Vector{Float64}
    thermal_larmor_radius_m::Vector{Float64}
    quadrature_identity_error::Float64
    problem_hash::String
    observation_hash::String
end

struct OpenFieldFLRConvergenceV1
    candidate_binding_hash::String
    state_result_hash::String
    status::Symbol
    resolution_verified::Bool
    maximum_gamma_change::Float64
    observations::Vector{OpenFieldFLRObservationV1}
    convergence_hash::String
end

function compile_open_field_flr_problem_v1(; candidate_binding_hash::AbstractString,
        state_result_hash::AbstractString, resolution_id::AbstractString,
        perpendicular_wavenumber_m_inv::AbstractVector,
        perpendicular_temperature_j::AbstractVector, magnetic_field_t::AbstractVector,
        species_mass_kg::Real, absolute_charge_c::Real, angular_quadrature_count::Integer,
        source_artifact_paths::AbstractVector = String[],
        source_artifact_hashes::AbstractVector = String[], validity_domain_covered::Bool,
        claim_boundary::AbstractString)
    k, t, b = Float64.(perpendicular_wavenumber_m_inv),
        Float64.(perpendicular_temperature_j), Float64.(magnetic_field_t)
    !isempty(k) && length(k) == length(t) == length(b) || throw(DimensionMismatch(
        "FLR wavenumber, temperature and field profiles must share a nonempty grid"))
    all(isfinite, k) && all(k .>= 0.0) || throw(ArgumentError(
        "perpendicular wavenumber must be finite and non-negative"))
    all(isfinite, t) && all(t .>= 0.0) || throw(ArgumentError(
        "perpendicular temperature must be finite and non-negative"))
    all(isfinite, b) && all(abs.(b) .> 0.0) || throw(ArgumentError(
        "magnetic field must be finite and nonzero"))
    mass, charge, nq = Float64(species_mass_kg), Float64(absolute_charge_c),
        Int(angular_quadrature_count)
    isfinite(mass) && mass > 0.0 || throw(ArgumentError("species mass must be positive"))
    isfinite(charge) && charge > 0.0 || throw(ArgumentError("absolute charge must be positive"))
    nq >= 8 && iseven(nq) || throw(ArgumentError(
        "FLR angular quadrature must be even and at least 8"))
    paths, hashes = String.(source_artifact_paths), String.(source_artifact_hashes)
    length(paths) == length(hashes) || throw(ArgumentError("source paths and hashes must pair"))
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => String(candidate_binding_hash),
        "state_result_hash" => String(state_result_hash), "resolution_id" => String(resolution_id),
        "perpendicular_wavenumber_m_inv" => k, "perpendicular_temperature_j" => t,
        "magnetic_field_t" => b, "species_mass_kg" => mass,
        "absolute_charge_c" => charge, "angular_quadrature_count" => nq,
        "source_artifact_paths" => paths, "source_artifact_hashes" => hashes,
        "validity_domain_covered" => validity_domain_covered,
        "claim_boundary" => String(claim_boundary))
    return OpenFieldFLRProblemV1(String(candidate_binding_hash), String(state_result_hash),
        String(resolution_id), k, t, b, mass, charge, nq, paths, hashes,
        validity_domain_covered, String(claim_boundary), canonical_hash(core))
end

function _scaled_modified_bessel_pair_v1(b::Float64, count::Int)
    total0 = 0.0; total1 = 0.0
    for j in 0:count-1
        theta = 2.0 * pi * (j + 0.5) / count
        weight = exp(-b * (1.0 - cos(theta)))
        total0 += weight
        total1 += weight * cos(theta)
    end
    return total0 / count, total1 / count
end

function solve_open_field_flr_problem_v1(problem::OpenFieldFLRProblemV1)
    problem.validity_domain_covered || throw(ArgumentError(
        "FLR kernel cannot run outside a covered validity domain"))
    rho = sqrt.(2.0 .* problem.species_mass_kg .* problem.perpendicular_temperature_j) ./
        (problem.absolute_charge_c .* abs.(problem.magnetic_field_t))
    b = 0.5 .* (problem.perpendicular_wavenumber_m_inv .* rho) .^ 2
    pair = [_scaled_modified_bessel_pair_v1(value, problem.angular_quadrature_count)
        for value in b]
    gamma0, gamma1 = first.(pair), last.(pair)
    identity_error = maximum(abs.(gamma0 .- 1.0) .* (b .== 0.0); init = 0.0)
    core = Dict{String,Any}("problem_hash" => problem.problem_hash,
        "b_parameter" => b, "gamma0" => gamma0, "gamma1" => gamma1,
        "thermal_larmor_radius_m" => rho,
        "quadrature_identity_error" => identity_error)
    return OpenFieldFLRObservationV1(problem.candidate_binding_hash,
        problem.state_result_hash, problem.resolution_id, b, gamma0, gamma1, rho,
        identity_error, problem.problem_hash, canonical_hash(core))
end

function compile_open_field_flr_convergence_v1(observations::Vector{OpenFieldFLRObservationV1};
        maximum_gamma_change::Real)
    length(observations) >= 3 || throw(ArgumentError("FLR requires at least three quadratures"))
    bindings = unique((o.candidate_binding_hash, o.state_result_hash) for o in observations)
    length(bindings) == 1 || throw(ArgumentError("FLR observations must share bindings"))
    shapes = unique(length(o.gamma0) for o in observations)
    length(shapes) == 1 || throw(ArgumentError("FLR observations must share profile shape"))
    changes = Float64[]
    for i in 2:length(observations)
        push!(changes, maximum(abs.(observations[i].gamma0 .- observations[i-1].gamma0)))
        push!(changes, maximum(abs.(observations[i].gamma1 .- observations[i-1].gamma1)))
    end
    change = maximum(changes)
    verified = change <= Float64(maximum_gamma_change)
    core = Dict("observation_hashes" => getfield.(observations, :observation_hash),
        "status" => verified ? "pass" : "unknown", "maximum_gamma_change" => change,
        "resolution_verified" => verified)
    a, b = only(bindings)
    return OpenFieldFLRConvergenceV1(a, b, verified ? :pass : :unknown,
        verified, change, observations, canonical_hash(core))
end

"FLR kernel evidence stays unknown until a candidate-bound mode response consumes its hash."
function compile_flr_stage4_evidence_v2(problems::Vector{OpenFieldFLRProblemV1},
        convergence::OpenFieldFLRConvergenceV1;
        coupled_mode_response_hash::AbstractString = "",
        coupled_mode_response_favorable::Union{Nothing,Bool} = nothing,
        signed_normalized_margin::Union{Nothing,Real} = nothing,
        registry::Vector{StabilityCapabilityContractV2} = default_stability_capability_registry_v2())
    length(problems) == length(convergence.observations) || throw(ArgumentError(
        "FLR problems and observations must be paired"))
    all(i -> problems[i].problem_hash == convergence.observations[i].problem_hash,
        eachindex(problems)) || throw(ArgumentError("FLR observation binding mismatch"))
    contract = only(filter(item -> item.operator_id == "finite_larmor_radius_v2", registry))
    perturbation = StabilityPerturbationSpecV2("gyroaveraged_finite_larmor_kernel_v1",
        contract.operator_id;
        equations = ["rho_i=sqrt(2*m_i*T_perp)/(abs(q_i)*B); b=(k_perp*rho_i)^2/2; Gamma_n=exp(-b)*I_n(b)"],
        state_input_ids = copy(contract.required_input_ids),
        boundary_conditions = ["local candidate profile support"], time_semantics = :eigenvalue,
        resolution_levels = getfield.(problems, :resolution_id),
        normalization = "coupled mode response margin; FLR kernel alone grants no favorable result")
    history = Dict{String,Any}[Dict("resolution_id" => o.resolution_id,
        "problem_hash" => o.problem_hash, "maximum_b" => maximum(o.b_parameter),
        "quadrature_identity_error" => o.quadrature_identity_error)
        for o in convergence.observations]
    hash_by_path = Dict{String,String}()
    for p in problems, (path, hash) in zip(p.source_artifact_paths, p.source_artifact_hashes)
        hash_by_path[path] = hash
    end
    paths = sort!(collect(keys(hash_by_path))); hashes = [hash_by_path[p] for p in paths]
    coupled = !isempty(coupled_mode_response_hash) &&
        coupled_mode_response_favorable !== nothing && signed_normalized_margin !== nothing
    covered = coupled ? copy(contract.required_input_ids) :
        setdiff(contract.required_input_ids, ["coupled_mode_response"])
    return compile_stability_evidence_envelope_v2(convergence.candidate_binding_hash,
        convergence.state_result_hash, contract, perturbation;
        favorable = coupled ? coupled_mode_response_favorable : nothing,
        signed_normalized_margin = coupled ? signed_normalized_margin : nothing,
        convergence_history = history,
        validity_domain_covered = all(getfield.(problems, :validity_domain_covered)),
        resolution_verified = convergence.resolution_verified, covered_input_ids = covered,
        source_kind = :candidate_solver, source_artifact_paths = paths,
        source_artifact_hashes = hashes,
        source_result_hash = coupled ? String(coupled_mode_response_hash) : convergence.convergence_hash,
        candidate_binding_verified = true, claim_boundary = last(problems).claim_boundary)
end
