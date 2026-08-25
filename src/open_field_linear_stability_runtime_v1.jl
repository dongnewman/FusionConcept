const _OPEN_LINEAR_MODE_IDS_V1 = Set(("interchange_flute_v2", "m1_global_v2"))

"Candidate-bound second-order open-field perturbation problem M*qdd + C*qd + K*q = 0."
struct OpenFieldLinearModeProblemV1
    candidate_binding_hash::String
    state_result_hash::String
    operator_id::String
    resolution_id::String
    coordinate_m::Vector{Float64}
    mass_matrix::Matrix{Float64}
    damping_matrix::Matrix{Float64}
    stiffness_matrix::Matrix{Float64}
    required_input_ids::Vector{String}
    covered_input_ids::Vector{String}
    validity_domain_covered::Bool
    source_artifact_paths::Vector{String}
    source_artifact_hashes::Vector{String}
    equation::String
    claim_boundary::String
    problem_hash::String
end

struct OpenFieldLinearModeObservationV1
    candidate_binding_hash::String
    state_result_hash::String
    operator_id::String
    resolution_id::String
    status::Symbol
    favorable::Union{Nothing,Bool}
    maximum_growth_rate_s_inv::Union{Nothing,Float64}
    dominant_frequency_rad_s::Union{Nothing,Float64}
    maximum_eigenpair_relative_residual::Union{Nothing,Float64}
    missing_input_ids::Vector{String}
    problem_hash::String
    observation_hash::String
end

struct OpenFieldLinearModeConvergenceV1
    candidate_binding_hash::String
    state_result_hash::String
    operator_id::String
    status::Symbol
    favorable::Union{Nothing,Bool}
    signed_normalized_margin::Union{Nothing,Float64}
    resolution_verified::Bool
    maximum_growth_change_s_inv::Union{Nothing,Float64}
    observations::Vector{OpenFieldLinearModeObservationV1}
    evidence_tasks::Vector{String}
    convergence_hash::String
end

function _open_mode_hash_matrix_v1(A::AbstractMatrix)
    return [collect(Float64, @view(A[i, :])) for i in axes(A, 1)]
end

function compile_open_field_linear_mode_problem_v1(;
        candidate_binding_hash::AbstractString, state_result_hash::AbstractString,
        operator_id::AbstractString, resolution_id::AbstractString,
        coordinate_m::AbstractVector, mass_matrix::AbstractMatrix,
        damping_matrix::AbstractMatrix, stiffness_matrix::AbstractMatrix,
        required_input_ids::AbstractVector, covered_input_ids::AbstractVector,
        validity_domain_covered::Bool, source_artifact_paths::AbstractVector = String[],
        source_artifact_hashes::AbstractVector = String[], equation::AbstractString,
        claim_boundary::AbstractString)
    id = String(operator_id)
    id in _OPEN_LINEAR_MODE_IDS_V1 || throw(ArgumentError(
        "unsupported open-field linear operator $id"))
    z = Float64.(coordinate_m)
    n = length(z)
    n >= 3 || throw(ArgumentError("open-field eigenproblem requires at least 3 cells"))
    all(isfinite, z) && all(diff(z) .> 0.0) || throw(ArgumentError(
        "coordinate must be finite and strictly increasing"))
    M, C, K = Matrix{Float64}(mass_matrix), Matrix{Float64}(damping_matrix),
        Matrix{Float64}(stiffness_matrix)
    all(size(A) == (n, n) for A in (M, C, K)) || throw(DimensionMismatch(
        "mass, damping and stiffness matrices must match the coordinate"))
    all(isfinite, M) && all(isfinite, C) && all(isfinite, K) || throw(ArgumentError(
        "open-field matrices must be finite"))
    isposdef(Symmetric(M)) || throw(ArgumentError("mass matrix must be positive definite"))
    norm(M - transpose(M)) <= 1.0e-11 * max(norm(M), 1.0) || throw(ArgumentError(
        "mass matrix must be symmetric"))
    paths, hashes = String.(source_artifact_paths), String.(source_artifact_hashes)
    length(paths) == length(hashes) || throw(ArgumentError(
        "source artifact paths and hashes must be paired"))
    required, covered = sort!(unique(String.(required_input_ids))),
        sort!(unique(String.(covered_input_ids)))
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "candidate_binding_hash" => String(candidate_binding_hash),
        "state_result_hash" => String(state_result_hash), "operator_id" => id,
        "resolution_id" => String(resolution_id), "coordinate_m" => z,
        "mass_matrix" => _open_mode_hash_matrix_v1(M),
        "damping_matrix" => _open_mode_hash_matrix_v1(C),
        "stiffness_matrix" => _open_mode_hash_matrix_v1(K),
        "required_input_ids" => required, "covered_input_ids" => covered,
        "validity_domain_covered" => validity_domain_covered,
        "source_artifact_paths" => paths, "source_artifact_hashes" => hashes,
        "equation" => String(equation), "claim_boundary" => String(claim_boundary))
    return OpenFieldLinearModeProblemV1(String(candidate_binding_hash),
        String(state_result_hash), id, String(resolution_id), z, M, C, K, required,
        covered, validity_domain_covered, paths, hashes, String(equation),
        String(claim_boundary), canonical_hash(core))
end

"Build a line-tied reduced flute/interchange slice from local inertia, tension and curvature drive."
function compile_open_interchange_problem_v1(; coordinate_m::AbstractVector,
        inertia_kg_m3::AbstractVector, field_line_tension_n_m2::AbstractVector,
        curvature_pressure_drive_n_m4::AbstractVector, damping_kg_m3_s::AbstractVector,
        _operator_id::AbstractString = "interchange_flute_v2", kwargs...)
    z = Float64.(coordinate_m); n = length(z)
    all(length(v) == n for v in (inertia_kg_m3, field_line_tension_n_m2,
        curvature_pressure_drive_n_m4, damping_kg_m3_s)) || throw(DimensionMismatch(
        "interchange coefficient profiles must match coordinate"))
    all(Float64.(inertia_kg_m3) .> 0.0) || throw(ArgumentError("inertia must be positive"))
    K = zeros(n, n)
    for i in 2:n-1
        hm, hp = z[i] - z[i-1], z[i+1] - z[i]
        tm = 0.5 * (field_line_tension_n_m2[i] + field_line_tension_n_m2[i-1])
        tp = 0.5 * (field_line_tension_n_m2[i] + field_line_tension_n_m2[i+1])
        volume = 0.5 * (hm + hp)
        K[i, i-1] = -tm / (hm * volume)
        K[i, i+1] = -tp / (hp * volume)
        K[i, i] = -K[i, i-1] - K[i, i+1] - curvature_pressure_drive_n_m4[i]
    end
    # Strong line tying removes boundary displacement without hiding the boundary model.
    scale = maximum(abs, K[2:n-1, 2:n-1]; init = 1.0)
    K[1, 1] = K[n, n] = 1.0e6 * max(scale, 1.0)
    return compile_open_field_linear_mode_problem_v1(; coordinate_m = z,
        mass_matrix = Diagonal(Float64.(inertia_kg_m3)),
        damping_matrix = Diagonal(Float64.(damping_kg_m3_s)), stiffness_matrix = K,
        operator_id = _operator_id,
        equation = "rho*q_tt + nu*q_t - d_z(T*d_z(q)) - D_curvature*q = 0 with declared line tying",
        kwargs...)
end

"Build a reduced global m=1 line-bending problem with explicit boundary/anchor stiffness."
function compile_open_m1_problem_v1(; coordinate_m::AbstractVector,
        inertia_kg_m3::AbstractVector, field_line_tension_n_m2::AbstractVector,
        pressure_drive_n_m4::AbstractVector, anchor_stiffness_n_m4::AbstractVector,
        damping_kg_m3_s::AbstractVector, kwargs...)
    effective_drive = Float64.(pressure_drive_n_m4) .- Float64.(anchor_stiffness_n_m4)
    return compile_open_interchange_problem_v1(; coordinate_m,
        inertia_kg_m3, field_line_tension_n_m2,
        curvature_pressure_drive_n_m4 = effective_drive, damping_kg_m3_s,
        kwargs..., _operator_id = "m1_global_v2")
end

function solve_open_field_linear_mode_problem_v1(problem::OpenFieldLinearModeProblemV1;
        growth_tolerance_s_inv::Real = 0.0, eigen_residual_tolerance::Real = 1.0e-8)
    missing = sort!(setdiff(problem.required_input_ids, problem.covered_input_ids))
    if !isempty(missing) || !problem.validity_domain_covered
        core = Dict("problem_hash" => problem.problem_hash, "status" => "unknown",
            "missing_input_ids" => missing,
            "validity_domain_covered" => problem.validity_domain_covered)
        return OpenFieldLinearModeObservationV1(problem.candidate_binding_hash,
            problem.state_result_hash, problem.operator_id, problem.resolution_id, :unknown,
            nothing, nothing, nothing, nothing, missing, problem.problem_hash,
            canonical_hash(core))
    end
    n = length(problem.coordinate_m)
    MinvK = problem.mass_matrix \ problem.stiffness_matrix
    MinvC = problem.mass_matrix \ problem.damping_matrix
    A = [zeros(n, n) Matrix{Float64}(I, n, n); -MinvK -MinvC]
    eig = eigen(A)
    residuals = Float64[]
    for j in axes(eig.vectors, 2)
        v, λ = eig.vectors[:, j], eig.values[j]
        push!(residuals, norm(A * v - λ * v) / max(norm(A) * norm(v), eps()))
    end
    max_residual = maximum(residuals)
    max_residual <= eigen_residual_tolerance || throw(ArgumentError(
        "eigenpair residual audit failed: $max_residual"))
    j = argmax(real.(eig.values)); λ = eig.values[j]
    growth, frequency = real(λ), abs(imag(λ))
    favorable = growth <= Float64(growth_tolerance_s_inv)
    core = Dict("problem_hash" => problem.problem_hash, "status" => favorable ? "pass" : "fail",
        "maximum_growth_rate_s_inv" => growth, "dominant_frequency_rad_s" => frequency,
        "maximum_eigenpair_relative_residual" => max_residual)
    return OpenFieldLinearModeObservationV1(problem.candidate_binding_hash,
        problem.state_result_hash, problem.operator_id, problem.resolution_id,
        favorable ? :pass : :fail, favorable, growth, frequency, max_residual,
        String[], problem.problem_hash, canonical_hash(core))
end

function compile_open_field_linear_mode_convergence_v1(
        observations::Vector{OpenFieldLinearModeObservationV1};
        growth_tolerance_s_inv::Real = 0.0, maximum_growth_change_s_inv::Real = 1.0e-4)
    length(observations) >= 3 || throw(ArgumentError("at least three resolutions are required"))
    bindings = unique((o.candidate_binding_hash, o.state_result_hash, o.operator_id)
        for o in observations)
    length(bindings) == 1 || throw(ArgumentError("convergence observations must share bindings"))
    if any(o -> o.status == :unknown, observations)
        tasks = sort!(unique(vcat([o.missing_input_ids for o in observations]...)))
        core = Dict("observation_hashes" => getfield.(observations, :observation_hash),
            "status" => "unknown", "evidence_tasks" => tasks)
        a, b, id = only(bindings)
        return OpenFieldLinearModeConvergenceV1(a, b, id, :unknown, nothing, nothing,
            false, nothing, observations, tasks, canonical_hash(core))
    end
    growth = Float64[o.maximum_growth_rate_s_inv for o in observations]
    change = maximum(abs.(diff(growth)))
    verified = change <= Float64(maximum_growth_change_s_inv)
    favorable = last(growth) <= Float64(growth_tolerance_s_inv)
    status = verified ? (favorable ? :pass : :fail) : :unknown
    margin_scale = max(abs(Float64(growth_tolerance_s_inv)), abs(last(growth)), 1.0)
    margin = (Float64(growth_tolerance_s_inv) - last(growth)) / margin_scale
    tasks = verified ? String[] : ["refine_open_field_linear_mode_resolution"]
    core = Dict("observation_hashes" => getfield.(observations, :observation_hash),
        "status" => String(status), "maximum_growth_change_s_inv" => change,
        "signed_normalized_margin" => margin, "resolution_verified" => verified)
    a, b, id = only(bindings)
    return OpenFieldLinearModeConvergenceV1(a, b, id, status,
        status == :unknown ? nothing : favorable, margin, verified, change,
        observations, tasks, canonical_hash(core))
end

function open_field_linear_mode_observation_to_dict_v1(o::OpenFieldLinearModeObservationV1)
    return Dict{String,Any}(name => getfield(o, name) for name in fieldnames(typeof(o)))
end

function open_field_linear_mode_convergence_to_dict_v1(o::OpenFieldLinearModeConvergenceV1)
    result = Dict{String,Any}(name => getfield(o, name) for name in fieldnames(typeof(o))
        if name != :observations)
    result["observations"] = open_field_linear_mode_observation_to_dict_v1.(o.observations)
    return result
end

"Bridge a converged open-field eigenproblem into the common Stage-4 evidence protocol."
function compile_open_linear_stage4_evidence_v2(
        problems::Vector{OpenFieldLinearModeProblemV1},
        convergence::OpenFieldLinearModeConvergenceV1;
        source_kind::Symbol = :candidate_solver,
        registry::Vector{StabilityCapabilityContractV2} = default_stability_capability_registry_v2())
    length(problems) == length(convergence.observations) || throw(ArgumentError(
        "open-field problems and convergence observations must be paired"))
    all(problem -> problem.candidate_binding_hash == convergence.candidate_binding_hash &&
        problem.state_result_hash == convergence.state_result_hash &&
        problem.operator_id == convergence.operator_id, problems) || throw(ArgumentError(
        "open-field Stage-4 evidence binding mismatch"))
    all(i -> problems[i].problem_hash == convergence.observations[i].problem_hash,
        eachindex(problems)) || throw(ArgumentError(
        "open-field observations are not bound to supplied problems"))
    contract = only(filter(item -> item.operator_id == convergence.operator_id, registry))
    required = sort!(unique(vcat([problem.required_input_ids for problem in problems]...)))
    required == contract.required_input_ids || throw(ArgumentError(
        "open-field problem inputs do not match Stage-4 capability contract"))
    covered = sort!(unique(vcat([problem.covered_input_ids for problem in problems]...)))
    equations = sort!(unique(getfield.(problems, :equation)))
    perturbation = StabilityPerturbationSpecV2(
        "open_field_second_order_eigenproblem_v1", convergence.operator_id;
        equations = equations, state_input_ids = required,
        boundary_conditions = ["boundary and anchor terms are explicit in stiffness matrix"],
        time_semantics = :eigenvalue,
        resolution_levels = getfield.(problems, :resolution_id),
        normalization = "dominant real eigenvalue relative to declared growth tolerance")
    history = Dict{String,Any}[Dict{String,Any}(
        "resolution_id" => observation.resolution_id,
        "problem_hash" => observation.problem_hash,
        "maximum_growth_rate_s_inv" => observation.maximum_growth_rate_s_inv,
        "dominant_frequency_rad_s" => observation.dominant_frequency_rad_s,
        "maximum_eigenpair_relative_residual" =>
            observation.maximum_eigenpair_relative_residual)
        for observation in convergence.observations]
    paths = sort!(unique(vcat([problem.source_artifact_paths for problem in problems]...)))
    hash_by_path = Dict{String,String}()
    for problem in problems, (path, hash) in zip(problem.source_artifact_paths,
            problem.source_artifact_hashes)
        haskey(hash_by_path, path) && hash_by_path[path] != hash && throw(ArgumentError(
            "conflicting source hash for $path"))
        hash_by_path[path] = hash
    end
    hashes = [hash_by_path[path] for path in paths]
    favorable = convergence.status == :unknown ? nothing : convergence.favorable
    scope = convergence.status == :fail ? Dict{String,Any}(
        "scope" => "declared_candidate_state_and_reduced_linear_operator",
        "failed_operator_id" => convergence.operator_id,
        "not_falsified" => ["nonlinear_saturation", "alternative_stabilization_state",
            "other_candidate_states"]) : Dict{String,Any}()
    return compile_stability_evidence_envelope_v2(convergence.candidate_binding_hash,
        convergence.state_result_hash, contract, perturbation;
        favorable = favorable, signed_normalized_margin = convergence.signed_normalized_margin,
        convergence_history = history,
        validity_domain_covered = all(getfield.(problems, :validity_domain_covered)),
        resolution_verified = convergence.resolution_verified,
        covered_input_ids = covered, source_kind = source_kind,
        source_artifact_paths = paths, source_artifact_hashes = hashes,
        source_result_hash = convergence.convergence_hash,
        candidate_binding_verified = true, minimal_failure_scope = scope,
        claim_boundary = last(problems).claim_boundary)
end
