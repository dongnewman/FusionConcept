const _AMBIPOLAR_RESPONSE_SOURCE_KINDS_V1 = Set((:candidate_solver,
    :measured, :proxy, :manufactured, :structural))

"A family-independent tabulated quasineutrality-response root problem."
struct AmbipolarPotentialResponseProblemV1
    compiler_version::String
    design_id::String
    genome_physics_hash::String
    domain_id::String
    axial_positions_m::Vector{Float64}
    elementary_charge_times_potential_grid_j::Union{Nothing,Vector{Float64}}
    electron_density_response_m3::Union{Nothing,Matrix{Float64}}
    ion_density_responses_m3::Dict{String,Matrix{Float64}}
    ion_charge_numbers::Dict{String,Int}
    response_source_kind::Symbol
    response_source_artifact_id::String
    response_source_artifact_hash::String
    response_source_result_hash::String
    response_candidate_binding_verified::Bool
    nonlinear_multispecies_response_verified::Bool
    bounce_average_verified::Bool
    resolution_verified::Bool
    applicability_verified::Bool
    source_solver_status::Symbol
    source_ids::Vector{String}
    problem_hash::String
end

"A unique per-axial-location root of sum_s Z_s n_s(ePhi)-n_e(ePhi)."
struct AmbipolarPotentialResponseObservationV1
    solver_version::String
    problem_hash::String
    design_id::String
    genome_physics_hash::String
    domain_id::String
    axial_positions_m::Vector{Float64}
    elementary_charge_times_potential_roots_j::Union{Nothing,Vector{Float64}}
    root_bracket_indices::Vector{Vector{Int}}
    root_count_by_axial_location::Vector{Int}
    maximum_relative_quasineutrality_residual::Union{Nothing,Float64}
    status::Symbol
    numerical_root_complete::Bool
    c2_ambipolar_profile_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    observation_hash::String
end

function _ambipolar_matrix_v1(value, name)
    value === nothing && return nothing
    result = Matrix{Float64}(value)
    all(isfinite, result) || throw(ArgumentError("$name must be finite"))
    all(>=(0.0), result) || throw(ArgumentError("$name must be non-negative"))
    return result
end

_ambipolar_matrix_rows_v1(value::Matrix{Float64}) =
    [collect(view(value, row, :)) for row in axes(value, 1)]

function compile_ambipolar_potential_response_problem_v1(;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        domain_id::AbstractString, axial_positions_m::AbstractVector{<:Real},
        elementary_charge_times_potential_grid_j = nothing,
        electron_density_response_m3 = nothing,
        ion_density_responses_m3::AbstractDict = Dict{String,Matrix{Float64}}(),
        ion_charge_numbers::AbstractDict = Dict{String,Int}(),
        response_source_kind::Symbol = :structural,
        response_source_artifact_id::AbstractString = "",
        response_source_artifact_hash::AbstractString = "",
        response_source_result_hash::AbstractString = "",
        response_candidate_binding_verified::Bool = false,
        nonlinear_multispecies_response_verified::Bool = false,
        bounce_average_verified::Bool = false,
        resolution_verified::Bool = false,
        applicability_verified::Bool = false,
        source_solver_status::Symbol = :unknown,
        source_ids::AbstractVector{<:AbstractString} = String[])
    response_source_kind in _AMBIPOLAR_RESPONSE_SOURCE_KINDS_V1 ||
        throw(ArgumentError("unsupported ambipolar response source kind"))
    source_solver_status in (:pass, :fail, :unknown, :error) ||
        throw(ArgumentError("invalid ambipolar response solver status"))
    z = Float64.(axial_positions_m)
    length(z) >= 2 && all(isfinite, z) && all(diff(z) .> 0.0) ||
        throw(ArgumentError("axial positions must contain at least two strictly increasing finite values"))
    phi = elementary_charge_times_potential_grid_j === nothing ? nothing :
        Float64.(elementary_charge_times_potential_grid_j)
    phi === nothing || (length(phi) >= 3 && all(isfinite, phi) &&
        all(diff(phi) .> 0.0)) || throw(ArgumentError(
        "e*potential grid must contain at least three strictly increasing finite values"))
    ne = _ambipolar_matrix_v1(electron_density_response_m3,
        "electron density response")
    ions = Dict{String,Matrix{Float64}}()
    for (species, response) in ion_density_responses_m3
        ions[String(species)] = something(_ambipolar_matrix_v1(response,
            "ion density response $(String(species))"))
    end
    charges = Dict{String,Int}(String(species) => Int(charge)
        for (species, charge) in ion_charge_numbers)
    Set(keys(ions)) == Set(keys(charges)) || throw(ArgumentError(
        "ion response species and charge-number species must match exactly"))
    all(>(0), values(charges)) || throw(ArgumentError(
        "ion charge numbers must be positive"))
    response_present = phi !== nothing || ne !== nothing || !isempty(ions)
    response_complete = phi !== nothing && ne !== nothing && !isempty(ions)
    !response_present || response_complete || throw(ArgumentError(
        "potential, electron, and ion response tensors must be supplied together"))
    if response_complete
        expected = (length(something(phi)), length(z))
        size(something(ne)) == expected || throw(ArgumentError(
            "electron response tensor must have size $expected"))
        all(size(response) == expected for response in values(ions)) ||
            throw(ArgumentError("every ion response tensor must have size $expected"))
        all(something(ne) .> 0.0) || throw(ArgumentError(
            "electron density response must be positive"))
        all(all(response .> 0.0) for response in values(ions)) ||
            throw(ArgumentError("ion density responses must be positive"))
    end
    sources = sort!(unique(String.(source_ids)))
    core = Dict{String,Any}(
        "compiler_version" => "ambipolar_potential_response_compiler_v1.0.0",
        "design_id" => String(design_id),
        "genome_physics_hash" => String(genome_physics_hash),
        "domain_id" => String(domain_id), "axial_positions_m" => z,
        "elementary_charge_times_potential_grid_j" => phi,
        "electron_density_response_m3" => ne === nothing ? nothing :
            _ambipolar_matrix_rows_v1(ne),
        "ion_density_responses_m3" => Dict{String,Any}(species =>
            _ambipolar_matrix_rows_v1(response)
            for (species, response) in ions),
        "ion_charge_numbers" => charges,
        "response_source_kind" => String(response_source_kind),
        "response_source_artifact_id" => String(response_source_artifact_id),
        "response_source_artifact_hash" => String(response_source_artifact_hash),
        "response_source_result_hash" => String(response_source_result_hash),
        "response_candidate_binding_verified" => response_candidate_binding_verified,
        "nonlinear_multispecies_response_verified" =>
            nonlinear_multispecies_response_verified,
        "bounce_average_verified" => bounce_average_verified,
        "resolution_verified" => resolution_verified,
        "applicability_verified" => applicability_verified,
        "source_solver_status" => String(source_solver_status),
        "source_ids" => sources)
    return AmbipolarPotentialResponseProblemV1(
        "ambipolar_potential_response_compiler_v1.0.0", String(design_id),
        String(genome_physics_hash), String(domain_id), z, phi, ne, ions,
        charges, response_source_kind, String(response_source_artifact_id),
        String(response_source_artifact_hash), String(response_source_result_hash),
        response_candidate_binding_verified,
        nonlinear_multispecies_response_verified, bounce_average_verified,
        resolution_verified, applicability_verified, source_solver_status,
        sources, canonical_hash(core))
end

function _ambipolar_relative_residual_v1(ne, positive)
    abs(positive - ne) / max(abs(positive) + abs(ne), 1.0e-30)
end

"Solve unique roots of the tabulated candidate kinetic density response."
function solve_ambipolar_potential_response_v1(
        problem::AmbipolarPotentialResponseProblemV1;
        quasineutrality_tolerance::Real = 1.0e-6)
    tolerance = Float64(quasineutrality_tolerance)
    isfinite(tolerance) && 0.0 <= tolerance < 1.0 || throw(ArgumentError(
        "quasineutrality tolerance must lie in [0,1)"))
    tasks = String[]
    warnings = String[
        "The root enforces local quasineutrality on supplied density-response tensors; it does not create the kinetic response.",
        "Physical authority requires a candidate-bound nonlinear multispecies, bounce-averaged, resolution-converged response including applicable sources and sinks.",
        "A quasineutrality root alone does not establish equal end current, confinement, stability, heating balance, or feasibility."]
    phi = problem.elementary_charge_times_potential_grid_j
    ne = problem.electron_density_response_m3
    if phi === nothing || ne === nothing || isempty(problem.ion_density_responses_m3)
        append!(tasks, [
            "provide_candidate_electron_density_response_vs_ephi",
            "provide_candidate_ion_density_responses_vs_ephi",
            "solve_nonlinear_multispecies_bounce_averaged_kinetic_response"])
        core = Dict{String,Any}(
            "solver_version" => "ambipolar_potential_response_solver_v1.0.0",
            "problem_hash" => problem.problem_hash,
            "elementary_charge_times_potential_roots_j" => nothing,
            "root_bracket_indices" => Vector{Int}[],
            "root_count_by_axial_location" => Int[],
            "maximum_relative_quasineutrality_residual" => nothing,
            "status" => "unknown", "numerical_root_complete" => false,
            "c2_ambipolar_profile_authorized" => false,
            "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
        return AmbipolarPotentialResponseObservationV1(
            "ambipolar_potential_response_solver_v1.0.0", problem.problem_hash,
            problem.design_id, problem.genome_physics_hash, problem.domain_id,
            problem.axial_positions_m, nothing, Vector{Int}[], Int[], nothing,
            :unknown, false, false, sort!(unique(tasks)), warnings,
            canonical_hash(core))
    end

    potential = something(phi)
    electron = something(ne)
    nphi, nz = size(electron)
    roots = Float64[]
    brackets_by_z = Vector{Int}[]
    root_counts = Int[]
    residuals = Float64[]
    complete = true
    for iz in 1:nz
        positive = zeros(Float64, nphi)
        for (species, density) in problem.ion_density_responses_m3
            positive .+= problem.ion_charge_numbers[species] .* view(density, :, iz)
        end
        residual = positive .- view(electron, :, iz)
        candidates = Vector{Int}[]
        exact = findall(index -> residual[index] == 0.0, eachindex(residual))
        for index in exact
            push!(candidates, [index])
        end
        for index in 1:(nphi - 1)
            residual[index] == 0.0 && continue
            residual[index + 1] == 0.0 && continue
            signbit(residual[index]) != signbit(residual[index + 1]) &&
                push!(candidates, [index, index + 1])
        end
        push!(root_counts, length(candidates))
        if length(candidates) != 1
            complete = false
            push!(brackets_by_z, Int[])
            push!(roots, NaN)
            push!(residuals, Inf)
            length(candidates) == 0 ? push!(tasks,
                "extend_ephi_response_bracket_at_axial_index:$iz") :
                push!(tasks, "resolve_multiple_ambipolar_roots_at_axial_index:$iz")
            continue
        end
        bracket = only(candidates)
        push!(brackets_by_z, bracket)
        if length(bracket) == 1
            index = only(bracket)
            root = potential[index]
            ne_root = electron[index, iz]
            positive_root = positive[index]
        else
            left, right = bracket
            weight = -residual[left] / (residual[right] - residual[left])
            root = potential[left] + weight * (potential[right] - potential[left])
            ne_root = electron[left, iz] +
                weight * (electron[right, iz] - electron[left, iz])
            positive_root = positive[left] +
                weight * (positive[right] - positive[left])
        end
        push!(roots, root)
        push!(residuals, _ambipolar_relative_residual_v1(ne_root, positive_root))
    end
    maxresidual = complete ? maximum(residuals) : nothing
    complete &= maxresidual !== nothing && maxresidual <= tolerance
    complete || push!(tasks, "refine_ambipolar_density_response_grid")
    provenance = !isempty(problem.response_source_artifact_id) &&
        length(problem.response_source_artifact_hash) == 64 &&
        length(problem.response_source_result_hash) == 64 &&
        !isempty(problem.source_ids)
    authority = complete && provenance &&
        problem.response_candidate_binding_verified &&
        problem.nonlinear_multispecies_response_verified &&
        problem.bounce_average_verified && problem.resolution_verified &&
        problem.applicability_verified &&
        problem.response_source_kind in (:candidate_solver, :measured) &&
        problem.source_solver_status == :pass
    problem.response_candidate_binding_verified || push!(tasks,
        "bind_ambipolar_response_to_candidate_genome")
    problem.nonlinear_multispecies_response_verified || push!(tasks,
        "solve_nonlinear_multispecies_coulomb_response")
    problem.bounce_average_verified || push!(tasks,
        "bounce_average_response_on_candidate_equilibrium")
    problem.resolution_verified || push!(tasks,
        "verify_ambipolar_response_resolution")
    problem.applicability_verified || push!(tasks,
        "verify_ambipolar_response_model_applicability")
    status = complete ? :pass : :unknown
    root_output = complete ? roots : nothing
    core = Dict{String,Any}(
        "solver_version" => "ambipolar_potential_response_solver_v1.0.0",
        "problem_hash" => problem.problem_hash,
        "elementary_charge_times_potential_roots_j" => root_output,
        "root_bracket_indices" => brackets_by_z,
        "root_count_by_axial_location" => root_counts,
        "maximum_relative_quasineutrality_residual" => maxresidual,
        "status" => String(status), "numerical_root_complete" => complete,
        "c2_ambipolar_profile_authorized" => authority,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return AmbipolarPotentialResponseObservationV1(
        "ambipolar_potential_response_solver_v1.0.0", problem.problem_hash,
        problem.design_id, problem.genome_physics_hash, problem.domain_id,
        problem.axial_positions_m, root_output, brackets_by_z, root_counts,
        maxresidual, status, complete, authority, sort!(unique(tasks)), warnings,
        canonical_hash(core))
end

function ambipolar_potential_response_problem_to_dict_v1(problem)
    result = Dict{String,Any}(String(name) => getfield(problem, name)
        for name in fieldnames(typeof(problem)))
    result["response_source_kind"] = String(problem.response_source_kind)
    result["source_solver_status"] = String(problem.source_solver_status)
    result["electron_density_response_m3"] =
        problem.electron_density_response_m3 === nothing ? nothing :
        _ambipolar_matrix_rows_v1(problem.electron_density_response_m3)
    result["ion_density_responses_m3"] = Dict{String,Any}(species =>
        _ambipolar_matrix_rows_v1(response)
        for (species, response) in problem.ion_density_responses_m3)
    return result
end

function ambipolar_potential_response_observation_to_dict_v1(observation)
    result = Dict{String,Any}(String(name) => getfield(observation, name)
        for name in fieldnames(typeof(observation)))
    result["status"] = String(observation.status)
    return result
end
