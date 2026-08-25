struct OpenFieldFlowShearProblemV1
    candidate_binding_hash::String
    state_result_hash::String
    resolution_id::String
    radius_m::Vector{Float64}
    radial_electric_field_v_m::Vector{Float64}
    magnetic_field_t::Vector{Float64}
    declared_exb_velocity_m_s::Vector{Float64}
    target_mode_growth_rate_s_inv::Vector{Float64}
    required_input_ids::Vector{String}
    covered_input_ids::Vector{String}
    validity_domain_covered::Bool
    source_artifact_paths::Vector{String}
    source_artifact_hashes::Vector{String}
    claim_boundary::String
    problem_hash::String
end

struct OpenFieldFlowShearObservationV1
    candidate_binding_hash::String
    state_result_hash::String
    resolution_id::String
    status::Symbol
    favorable::Union{Nothing,Bool}
    minimum_shear_margin_s_inv::Union{Nothing,Float64}
    maximum_exb_consistency_relative_error::Union{Nothing,Float64}
    maximum_target_growth_rate_s_inv::Union{Nothing,Float64}
    minimum_exb_shearing_rate_s_inv::Union{Nothing,Float64}
    missing_input_ids::Vector{String}
    problem_hash::String
    observation_hash::String
end

struct OpenFieldFlowShearConvergenceV1
    candidate_binding_hash::String
    state_result_hash::String
    status::Symbol
    favorable::Union{Nothing,Bool}
    signed_normalized_margin::Union{Nothing,Float64}
    resolution_verified::Bool
    maximum_margin_change_s_inv::Union{Nothing,Float64}
    observations::Vector{OpenFieldFlowShearObservationV1}
    evidence_tasks::Vector{String}
    convergence_hash::String
end

function compile_open_field_flow_shear_problem_v1(; candidate_binding_hash::AbstractString,
        state_result_hash::AbstractString, resolution_id::AbstractString,
        radius_m::AbstractVector, radial_electric_field_v_m::AbstractVector,
        magnetic_field_t::AbstractVector, declared_exb_velocity_m_s::AbstractVector,
        target_mode_growth_rate_s_inv::AbstractVector,
        required_input_ids::AbstractVector = ["electric_field_profile", "flow_profile",
            "magnetic_field", "mode_spectrum"], covered_input_ids::AbstractVector,
        validity_domain_covered::Bool, source_artifact_paths::AbstractVector = String[],
        source_artifact_hashes::AbstractVector = String[], claim_boundary::AbstractString)
    r, er, b, v, gamma = Float64.(radius_m), Float64.(radial_electric_field_v_m),
        Float64.(magnetic_field_t), Float64.(declared_exb_velocity_m_s),
        Float64.(target_mode_growth_rate_s_inv)
    n = length(r)
    n >= 5 || throw(ArgumentError("flow-shear audit requires at least five radial points"))
    all(length(x) == n for x in (er, b, v, gamma)) || throw(DimensionMismatch(
        "flow-shear profiles must share one radial grid"))
    all(isfinite, r) && all(diff(r) .> 0.0) && first(r) > 0.0 || throw(ArgumentError(
        "flow-shear radius must be positive, finite and strictly increasing"))
    all(isfinite, er) && all(isfinite, b) && all(isfinite, v) && all(isfinite, gamma) ||
        throw(ArgumentError("flow-shear profiles must be finite"))
    all(abs.(b) .> 0.0) || throw(ArgumentError("magnetic field cannot vanish"))
    all(gamma .>= 0.0) || throw(ArgumentError("target growth rates must be non-negative"))
    paths, hashes = String.(source_artifact_paths), String.(source_artifact_hashes)
    length(paths) == length(hashes) || throw(ArgumentError("source paths and hashes must pair"))
    required, covered = sort!(unique(String.(required_input_ids))),
        sort!(unique(String.(covered_input_ids)))
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => String(candidate_binding_hash),
        "state_result_hash" => String(state_result_hash), "resolution_id" => String(resolution_id),
        "radius_m" => r, "radial_electric_field_v_m" => er, "magnetic_field_t" => b,
        "declared_exb_velocity_m_s" => v, "target_mode_growth_rate_s_inv" => gamma,
        "required_input_ids" => required, "covered_input_ids" => covered,
        "validity_domain_covered" => validity_domain_covered,
        "source_artifact_paths" => paths, "source_artifact_hashes" => hashes,
        "claim_boundary" => String(claim_boundary))
    return OpenFieldFlowShearProblemV1(String(candidate_binding_hash), String(state_result_hash),
        String(resolution_id), r, er, b, v, gamma, required, covered,
        validity_domain_covered, paths, hashes, String(claim_boundary), canonical_hash(core))
end

function _nonuniform_first_derivative_v1(x::Vector{Float64}, y::Vector{Float64})
    n = length(x); d = zeros(n)
    d[1] = (y[2] - y[1]) / (x[2] - x[1])
    d[n] = (y[n] - y[n-1]) / (x[n] - x[n-1])
    for i in 2:n-1
        hm, hp = x[i] - x[i-1], x[i+1] - x[i]
        d[i] = -hp / (hm * (hm + hp)) * y[i-1] +
            (hp - hm) / (hm * hp) * y[i] + hm / (hp * (hm + hp)) * y[i+1]
    end
    return d
end

function solve_open_field_flow_shear_problem_v1(problem::OpenFieldFlowShearProblemV1;
        exb_consistency_tolerance::Real = 1.0e-6)
    missing = sort!(setdiff(problem.required_input_ids, problem.covered_input_ids))
    if !isempty(missing) || !problem.validity_domain_covered
        core = Dict("problem_hash" => problem.problem_hash, "status" => "unknown",
            "missing_input_ids" => missing)
        return OpenFieldFlowShearObservationV1(problem.candidate_binding_hash,
            problem.state_result_hash, problem.resolution_id, :unknown, nothing, nothing,
            nothing, nothing, nothing, missing, problem.problem_hash, canonical_hash(core))
    end
    expected_v = -problem.radial_electric_field_v_m ./ problem.magnetic_field_t
    consistency = maximum(abs.(problem.declared_exb_velocity_m_s .- expected_v) ./
        max.(abs.(expected_v), 1.0))
    if consistency > Float64(exb_consistency_tolerance)
        core = Dict("problem_hash" => problem.problem_hash, "status" => "fail",
            "maximum_exb_consistency_relative_error" => consistency,
            "failed_gate" => "declared_flow_matches_e_cross_b")
        return OpenFieldFlowShearObservationV1(problem.candidate_binding_hash,
            problem.state_result_hash, problem.resolution_id, :fail, false,
            -Inf, consistency, maximum(problem.target_mode_growth_rate_s_inv),
            nothing, String[], problem.problem_hash, canonical_hash(core))
    end
    omega = problem.declared_exb_velocity_m_s ./ problem.radius_m
    shear = abs.(problem.radius_m .* _nonuniform_first_derivative_v1(problem.radius_m, omega))
    margin_profile = shear .- problem.target_mode_growth_rate_s_inv
    margin = minimum(margin_profile)
    favorable = margin >= 0.0
    core = Dict("problem_hash" => problem.problem_hash,
        "status" => favorable ? "pass" : "fail", "minimum_shear_margin_s_inv" => margin,
        "maximum_exb_consistency_relative_error" => consistency,
        "maximum_target_growth_rate_s_inv" => maximum(problem.target_mode_growth_rate_s_inv),
        "minimum_exb_shearing_rate_s_inv" => minimum(shear))
    return OpenFieldFlowShearObservationV1(problem.candidate_binding_hash,
        problem.state_result_hash, problem.resolution_id, favorable ? :pass : :fail,
        favorable, margin, consistency, maximum(problem.target_mode_growth_rate_s_inv),
        minimum(shear), String[], problem.problem_hash, canonical_hash(core))
end

function compile_open_field_flow_shear_convergence_v1(
        observations::Vector{OpenFieldFlowShearObservationV1};
        maximum_margin_change_s_inv::Real)
    length(observations) >= 3 || throw(ArgumentError("at least three resolutions are required"))
    bindings = unique((o.candidate_binding_hash, o.state_result_hash) for o in observations)
    length(bindings) == 1 || throw(ArgumentError("flow-shear observations must share bindings"))
    if any(o -> o.status == :unknown, observations)
        tasks = sort!(unique(vcat([o.missing_input_ids for o in observations]...)))
        a, b = only(bindings); core = Dict("status" => "unknown",
            "observation_hashes" => getfield.(observations, :observation_hash))
        return OpenFieldFlowShearConvergenceV1(a, b, :unknown, nothing, nothing,
            false, nothing, observations, tasks, canonical_hash(core))
    end
    any(o -> !isfinite(something(o.minimum_shear_margin_s_inv, NaN)), observations) && begin
        a, b = only(bindings); core = Dict("status" => "fail",
            "observation_hashes" => getfield.(observations, :observation_hash),
            "failed_gate" => "declared_flow_matches_e_cross_b")
        return OpenFieldFlowShearConvergenceV1(a, b, :fail, false, -1.0, true, 0.0,
            observations, String[], canonical_hash(core))
    end
    margins = Float64[o.minimum_shear_margin_s_inv for o in observations]
    change = maximum(abs.(diff(margins)))
    verified = change <= Float64(maximum_margin_change_s_inv)
    favorable = last(margins) >= 0.0
    status = verified ? (favorable ? :pass : :fail) : :unknown
    scale = max(abs(last(margins)), maximum(o.maximum_target_growth_rate_s_inv for o in observations), 1.0)
    signed = last(margins) / scale
    tasks = verified ? String[] : ["refine_open_field_flow_shear_resolution"]
    a, b = only(bindings); core = Dict("status" => String(status),
        "observation_hashes" => getfield.(observations, :observation_hash),
        "maximum_margin_change_s_inv" => change, "signed_normalized_margin" => signed)
    return OpenFieldFlowShearConvergenceV1(a, b, status,
        status == :unknown ? nothing : favorable, signed, verified, change,
        observations, tasks, canonical_hash(core))
end

function compile_flow_shear_stage4_evidence_v2(problems::Vector{OpenFieldFlowShearProblemV1},
        convergence::OpenFieldFlowShearConvergenceV1;
        source_kind::Symbol = :candidate_solver,
        registry::Vector{StabilityCapabilityContractV2} = default_stability_capability_registry_v2())
    length(problems) == length(convergence.observations) || throw(ArgumentError(
        "flow-shear problems and observations must be paired"))
    all(i -> problems[i].problem_hash == convergence.observations[i].problem_hash,
        eachindex(problems)) || throw(ArgumentError("flow-shear problem binding mismatch"))
    contract = only(filter(item -> item.operator_id == "flow_shear_v2", registry))
    required = sort!(unique(vcat([p.required_input_ids for p in problems]...)))
    required == contract.required_input_ids || throw(ArgumentError(
        "flow-shear problem inputs do not match capability contract"))
    covered = sort!(unique(vcat([p.covered_input_ids for p in problems]...)))
    perturbation = StabilityPerturbationSpecV2("cylindrical_exb_shear_suppression_v1",
        contract.operator_id; equations = ["omega_E = abs(r*d_r(v_E/r)); margin = omega_E - gamma_mode"],
        state_input_ids = required, boundary_conditions = ["declared radial profile domain"],
        time_semantics = :steady, resolution_levels = getfield.(problems, :resolution_id),
        normalization = "minimum local shear margin normalized by mode growth scale")
    history = Dict{String,Any}[Dict("resolution_id" => o.resolution_id,
        "minimum_shear_margin_s_inv" => o.minimum_shear_margin_s_inv,
        "maximum_exb_consistency_relative_error" => o.maximum_exb_consistency_relative_error,
        "problem_hash" => o.problem_hash) for o in convergence.observations]
    hash_by_path = Dict{String,String}()
    for p in problems, (path, hash) in zip(p.source_artifact_paths, p.source_artifact_hashes)
        haskey(hash_by_path, path) && hash_by_path[path] != hash && throw(ArgumentError(
            "conflicting flow-shear source hash")); hash_by_path[path] = hash
    end
    paths = sort!(collect(keys(hash_by_path))); hashes = [hash_by_path[p] for p in paths]
    favorable = convergence.status == :unknown ? nothing : convergence.favorable
    return compile_stability_evidence_envelope_v2(convergence.candidate_binding_hash,
        convergence.state_result_hash, contract, perturbation; favorable,
        signed_normalized_margin = convergence.signed_normalized_margin,
        convergence_history = history,
        validity_domain_covered = all(getfield.(problems, :validity_domain_covered)),
        resolution_verified = convergence.resolution_verified, covered_input_ids = covered,
        source_kind, source_artifact_paths = paths, source_artifact_hashes = hashes,
        source_result_hash = convergence.convergence_hash, candidate_binding_verified = true,
        claim_boundary = last(problems).claim_boundary)
end
