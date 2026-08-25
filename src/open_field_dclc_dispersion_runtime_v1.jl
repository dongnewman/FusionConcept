struct OpenFieldDCLCProblemV1
    candidate_binding_hash::String
    state_result_hash::String
    resolution_id::String
    normalized_perpendicular_speed::Vector{Float64}
    reduced_distribution::Vector{Float64}
    normalized_wavenumbers::Vector{Float64}
    normalized_density_gradient::Float64
    ion_plasma_to_cyclotron_ratio_sq::Float64
    electron_plasma_to_cyclotron_ratio_sq::Float64
    electron_drift_prefactor::Float64
    harmonic_cutoff::Int
    bessel_quadrature_count::Int
    initial_root_guesses::Vector{ComplexF64}
    root_search_domain_covered::Bool
    validity_domain_covered::Bool
    source_artifact_paths::Vector{String}
    source_artifact_hashes::Vector{String}
    claim_boundary::String
    problem_hash::String
end

struct OpenFieldDCLCRootV1
    normalized_wavenumber::Float64
    normalized_frequency::ComplexF64
    dispersion_residual::Float64
    converged::Bool
end

struct OpenFieldDCLCObservationV1
    candidate_binding_hash::String
    state_result_hash::String
    resolution_id::String
    status::Symbol
    maximum_normalized_growth_rate::Union{Nothing,Float64}
    maximum_dispersion_residual::Union{Nothing,Float64}
    distribution_normalization_error::Float64
    root_search_complete::Bool
    roots::Vector{OpenFieldDCLCRootV1}
    problem_hash::String
    observation_hash::String
end

struct OpenFieldDCLCConvergenceV1
    candidate_binding_hash::String
    state_result_hash::String
    status::Symbol
    favorable::Union{Nothing,Bool}
    maximum_normalized_growth_rate::Union{Nothing,Float64}
    maximum_growth_change::Union{Nothing,Float64}
    resolution_verified::Bool
    observations::Vector{OpenFieldDCLCObservationV1}
    convergence_hash::String
end

function _complex_pairs_v1(values)
    return [Dict("real" => real(z), "imag" => imag(z)) for z in values]
end

function _trapz_v1(x::Vector{Float64}, y)
    total = zero(eltype(y))
    for i in 1:length(x)-1
        total += 0.5 * (x[i+1] - x[i]) * (y[i+1] + y[i])
    end
    return total
end

function compile_open_field_dclc_problem_v1(; candidate_binding_hash::AbstractString,
        state_result_hash::AbstractString, resolution_id::AbstractString,
        normalized_perpendicular_speed::AbstractVector,
        reduced_distribution::AbstractVector, normalized_wavenumbers::AbstractVector,
        normalized_density_gradient::Real, ion_plasma_to_cyclotron_ratio_sq::Real,
        electron_plasma_to_cyclotron_ratio_sq::Real, electron_drift_prefactor::Real,
        harmonic_cutoff::Integer, bessel_quadrature_count::Integer,
        initial_root_guesses::AbstractVector, root_search_domain_covered::Bool,
        validity_domain_covered::Bool, source_artifact_paths::AbstractVector = String[],
        source_artifact_hashes::AbstractVector = String[], claim_boundary::AbstractString)
    v, f, ks = Float64.(normalized_perpendicular_speed), Float64.(reduced_distribution),
        Float64.(normalized_wavenumbers)
    length(v) >= 16 && length(v) == length(f) || throw(DimensionMismatch(
        "DCLC reduced distribution requires at least 16 speed points"))
    first(v) == 0.0 && all(diff(v) .> 0.0) || throw(ArgumentError(
        "DCLC speed grid must start at zero and strictly increase"))
    all(isfinite, f) && all(f .>= 0.0) || throw(ArgumentError(
        "DCLC reduced distribution must be finite and non-negative"))
    !isempty(ks) && all(isfinite, ks) && all(ks .> 0.0) || throw(ArgumentError(
        "DCLC normalized wavenumbers must be positive"))
    h, nq = Int(harmonic_cutoff), Int(bessel_quadrature_count)
    h >= 1 || throw(ArgumentError("DCLC harmonic cutoff must be positive"))
    nq >= 64 && iseven(nq) || throw(ArgumentError(
        "DCLC Bessel quadrature must be even and at least 64"))
    ratios = Float64.((ion_plasma_to_cyclotron_ratio_sq,
        electron_plasma_to_cyclotron_ratio_sq, electron_drift_prefactor))
    all(isfinite, ratios) && all(ratios .>= 0.0) || throw(ArgumentError(
        "DCLC plasma/cyclotron ratios must be finite and non-negative"))
    epsilon = Float64(normalized_density_gradient)
    isfinite(epsilon) || throw(ArgumentError("DCLC density gradient must be finite"))
    guesses = ComplexF64.(initial_root_guesses)
    isempty(guesses) && throw(ArgumentError("DCLC root guesses are required"))
    all(z -> isfinite(real(z)) && isfinite(imag(z)), guesses) || throw(ArgumentError(
        "DCLC root guesses must be finite"))
    root_search_domain_covered && length(guesses) < 2h + 1 && throw(ArgumentError(
        "covered DCLC root search requires at least one seed per retained harmonic interval"))
    paths, hashes = String.(source_artifact_paths), String.(source_artifact_hashes)
    length(paths) == length(hashes) || throw(ArgumentError("source paths and hashes must pair"))
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => String(candidate_binding_hash),
        "state_result_hash" => String(state_result_hash), "resolution_id" => String(resolution_id),
        "normalized_perpendicular_speed" => v, "reduced_distribution" => f,
        "normalized_wavenumbers" => ks, "normalized_density_gradient" => epsilon,
        "ion_plasma_to_cyclotron_ratio_sq" => ratios[1],
        "electron_plasma_to_cyclotron_ratio_sq" => ratios[2],
        "electron_drift_prefactor" => ratios[3], "harmonic_cutoff" => h,
        "bessel_quadrature_count" => nq, "initial_root_guesses" => _complex_pairs_v1(guesses),
        "root_search_domain_covered" => root_search_domain_covered,
        "validity_domain_covered" => validity_domain_covered,
        "source_artifact_paths" => paths, "source_artifact_hashes" => hashes,
        "claim_boundary" => String(claim_boundary))
    return OpenFieldDCLCProblemV1(String(candidate_binding_hash), String(state_result_hash),
        String(resolution_id), v, f, ks, epsilon, ratios[1], ratios[2], ratios[3],
        h, nq, guesses, root_search_domain_covered, validity_domain_covered,
        paths, hashes, String(claim_boundary), canonical_hash(core))
end

"Integer Bessel J_n from its periodic integral; valid for positive and negative n."
function _dclc_besselj_v1(n::Int, x::Float64, count::Int)
    order = abs(n); total = 0.0
    for j in 0:count-1
        theta = 2.0 * pi * (j + 0.5) / count
        total += cos(order * theta - x * sin(theta))
    end
    value = total / count
    return n < 0 && isodd(order) ? -value : value
end

function _dclc_distribution_normalization_v1(problem::OpenFieldDCLCProblemV1)
    return _trapz_v1(problem.normalized_perpendicular_speed,
        2.0 .* pi .* problem.normalized_perpendicular_speed .* problem.reduced_distribution)
end

function open_field_dclc_dispersion_v1(problem::OpenFieldDCLCProblemV1,
        k::Real, omega::Complex)
    kb, w = Float64(k), ComplexF64(omega)
    v, f = problem.normalized_perpendicular_speed, problem.reduced_distribution
    df = _nonuniform_first_derivative_v1(v, f)
    sum_derivative = 0.0 + 0.0im; sum_distribution = 0.0 + 0.0im
    for n in -problem.harmonic_cutoff:problem.harmonic_cutoff
        denom = w - n
        abs(denom) > 1.0e-12 || return ComplexF64(Inf, Inf)
        j2 = [_dclc_besselj_v1(n, kb * value,
            problem.bessel_quadrature_count)^2 for value in v]
        derivative_integral = _trapz_v1(v, 2.0 .* pi .* df .* j2)
        distribution_integral = _trapz_v1(v, 2.0 .* pi .* v .* f .* j2)
        sum_derivative += n / denom * derivative_integral
        sum_distribution += 1.0 / denom * distribution_integral
    end
    chi_i = problem.ion_plasma_to_cyclotron_ratio_sq * (
        (1.0 - problem.normalized_density_gradient * w / kb) / kb^2 * sum_derivative -
        problem.normalized_density_gradient / kb * sum_distribution)
    cold_electron = problem.electron_plasma_to_cyclotron_ratio_sq +
        problem.electron_drift_prefactor * problem.normalized_density_gradient / (kb * w)
    return 1.0 + chi_i + cold_electron
end

function _refine_dclc_root_v1(problem, k, initial; tolerance = 1.0e-9, max_iterations = 60)
    w = ComplexF64(initial)
    for _ in 1:max_iterations
        value = open_field_dclc_dispersion_v1(problem, k, w)
        isfinite(abs(value)) || return w, Inf, false
        abs(value) <= tolerance && return w, abs(value), true
        h = 1.0e-6 * max(abs(w), 1.0)
        derivative = (open_field_dclc_dispersion_v1(problem, k, w + h) -
            open_field_dclc_dispersion_v1(problem, k, w - h)) / (2.0 * h)
        abs(derivative) > 1.0e-14 || return w, abs(value), false
        step = value / derivative
        abs(step) > 1.0 && (step /= abs(step))
        w -= step
    end
    residual = abs(open_field_dclc_dispersion_v1(problem, k, w))
    return w, residual, residual <= tolerance
end

function solve_open_field_dclc_problem_v1(problem::OpenFieldDCLCProblemV1;
        normalization_tolerance::Real = 2.0e-2, root_tolerance::Real = 1.0e-8,
        growth_tolerance::Real = 1.0e-8)
    normalization_error = abs(_dclc_distribution_normalization_v1(problem) - 1.0)
    if !problem.validity_domain_covered || normalization_error > normalization_tolerance
        core = Dict("problem_hash" => problem.problem_hash, "status" => "unknown",
            "distribution_normalization_error" => normalization_error)
        return OpenFieldDCLCObservationV1(problem.candidate_binding_hash,
            problem.state_result_hash, problem.resolution_id, :unknown, nothing, nothing,
            normalization_error, false, OpenFieldDCLCRootV1[], problem.problem_hash,
            canonical_hash(core))
    end
    roots = OpenFieldDCLCRootV1[]
    all_converged = true
    for k in problem.normalized_wavenumbers
        local_roots = OpenFieldDCLCRootV1[]
        for guess in problem.initial_root_guesses
            w, residual, converged = _refine_dclc_root_v1(problem, k, guess;
                tolerance = Float64(root_tolerance))
            all_converged &= converged
            converged || continue
            any(item -> abs(item.normalized_frequency - w) <= 1.0e-5, local_roots) && continue
            push!(local_roots, OpenFieldDCLCRootV1(k, w, residual, true))
        end
        isempty(local_roots) && (all_converged = false)
        append!(roots, local_roots)
    end
    root_complete = all_converged && problem.root_search_domain_covered
    if isempty(roots) || !root_complete
        core = Dict("problem_hash" => problem.problem_hash, "status" => "unknown",
            "root_search_complete" => false, "converged_root_count" => length(roots))
        return OpenFieldDCLCObservationV1(problem.candidate_binding_hash,
            problem.state_result_hash, problem.resolution_id, :unknown, nothing,
            isempty(roots) ? nothing : maximum(getfield.(roots, :dispersion_residual)),
            normalization_error, false, roots, problem.problem_hash, canonical_hash(core))
    end
    growth = maximum(imag(item.normalized_frequency) for item in roots)
    residual = maximum(item.dispersion_residual for item in roots)
    status = growth <= Float64(growth_tolerance) ? :pass : :fail
    core = Dict("problem_hash" => problem.problem_hash, "status" => String(status),
        "maximum_normalized_growth_rate" => growth, "maximum_dispersion_residual" => residual,
        "root_search_complete" => true,
        "roots" => [Dict("k" => r.normalized_wavenumber,
            "omega" => Dict("real" => real(r.normalized_frequency),
                "imag" => imag(r.normalized_frequency)), "residual" => r.dispersion_residual)
            for r in roots])
    return OpenFieldDCLCObservationV1(problem.candidate_binding_hash,
        problem.state_result_hash, problem.resolution_id, status, growth, residual,
        normalization_error, true, roots, problem.problem_hash, canonical_hash(core))
end

function compile_open_field_dclc_convergence_v1(
        observations::Vector{OpenFieldDCLCObservationV1};
        maximum_growth_change::Real, growth_tolerance::Real = 1.0e-8)
    length(observations) >= 3 || throw(ArgumentError("DCLC requires at least three resolutions"))
    bindings = unique((o.candidate_binding_hash, o.state_result_hash) for o in observations)
    length(bindings) == 1 || throw(ArgumentError("DCLC observations must share bindings"))
    if any(o -> o.status == :unknown, observations)
        a, b = only(bindings); core = Dict("status" => "unknown",
            "observation_hashes" => getfield.(observations, :observation_hash))
        return OpenFieldDCLCConvergenceV1(a, b, :unknown, nothing, nothing, nothing,
            false, observations, canonical_hash(core))
    end
    growth = Float64[o.maximum_normalized_growth_rate for o in observations]
    change = maximum(abs.(diff(growth)))
    verified = change <= Float64(maximum_growth_change)
    favorable = last(growth) <= Float64(growth_tolerance)
    status = verified ? (favorable ? :pass : :fail) : :unknown
    core = Dict("status" => String(status),
        "observation_hashes" => getfield.(observations, :observation_hash),
        "maximum_normalized_growth_rate" => last(growth),
        "maximum_growth_change" => change, "resolution_verified" => verified)
    a, b = only(bindings)
    return OpenFieldDCLCConvergenceV1(a, b, status,
        status == :unknown ? nothing : favorable, last(growth), change,
        verified, observations, canonical_hash(core))
end

function compile_dclc_stage4_evidence_v2(problems::Vector{OpenFieldDCLCProblemV1},
        convergence::OpenFieldDCLCConvergenceV1;
        candidate_distribution_verified::Bool, loss_cone_boundary_verified::Bool,
        electron_model_authorized::Bool, known_control_verified::Bool,
        flr_kernel_hash::AbstractString,
        growth_tolerance::Real = 1.0e-8,
        registry::Vector{StabilityCapabilityContractV2} = default_stability_capability_registry_v2())
    length(problems) == length(convergence.observations) || throw(ArgumentError(
        "DCLC problems and observations must be paired"))
    all(i -> problems[i].problem_hash == convergence.observations[i].problem_hash,
        eachindex(problems)) || throw(ArgumentError("DCLC observation binding mismatch"))
    contract = only(filter(item -> item.operator_id ==
        "drift_cyclotron_loss_cone_v2", registry))
    perturbation = StabilityPerturbationSpecV2("slab_perpendicular_dclc_v1",
        contract.operator_id;
        equations = ["D=1+chi_i+omega_pe^2/Omega_e^2+(omega_pe^2/(abs(Omega_e)*Omega_i))*epsilon_bar/(k_bar*omega_bar)=0",
            "chi_i from the full cyclotron-harmonic integral of F(v_perp) and dF/dv_perp"],
        state_input_ids = copy(contract.required_input_ids),
        boundary_conditions = ["local slab; k_parallel=0; uniform background B; cold fluid electrons"],
        time_semantics = :eigenvalue, resolution_levels = getfield.(problems, :resolution_id),
        normalization = "growth rate normalized by signed ion cyclotron frequency")
    history = Dict{String,Any}[Dict("resolution_id" => o.resolution_id,
        "problem_hash" => o.problem_hash,
        "maximum_normalized_growth_rate" => o.maximum_normalized_growth_rate,
        "maximum_dispersion_residual" => o.maximum_dispersion_residual,
        "root_search_complete" => o.root_search_complete) for o in convergence.observations]
    hash_by_path = Dict{String,String}()
    for p in problems, (path, hash) in zip(p.source_artifact_paths, p.source_artifact_hashes)
        hash_by_path[path] = hash
    end
    paths = sort!(collect(keys(hash_by_path))); hashes = [hash_by_path[p] for p in paths]
    gates = candidate_distribution_verified && loss_cone_boundary_verified &&
        electron_model_authorized && known_control_verified && !isempty(flr_kernel_hash)
    favorable = gates && convergence.status != :unknown ? convergence.favorable : nothing
    margin = gates && convergence.maximum_normalized_growth_rate !== nothing ?
        (Float64(growth_tolerance) - convergence.maximum_normalized_growth_rate) /
            max(abs(convergence.maximum_normalized_growth_rate), abs(Float64(growth_tolerance)), 1.0) : nothing
    covered = String[]
    candidate_distribution_verified && append!(covered, ["ion_distribution", "density_gradient"])
    loss_cone_boundary_verified && push!(covered, "loss_cone_boundary")
    electron_model_authorized && push!(covered, "electron_temperature")
    !isempty(flr_kernel_hash) && push!(covered, "finite_larmor_radius")
    return compile_stability_evidence_envelope_v2(convergence.candidate_binding_hash,
        convergence.state_result_hash, contract, perturbation; favorable,
        signed_normalized_margin = margin, convergence_history = history,
        validity_domain_covered = all(getfield.(problems, :validity_domain_covered)),
        resolution_verified = convergence.resolution_verified, covered_input_ids = covered,
        source_kind = :candidate_solver, source_artifact_paths = paths,
        source_artifact_hashes = hashes,
        source_result_hash = gates ? convergence.convergence_hash : String(flr_kernel_hash),
        candidate_binding_verified = true, claim_boundary = last(problems).claim_boundary)
end
