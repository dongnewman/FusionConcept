const _MAGNET_GATE_KINDS_V1 = Set((:boolean_true, :upper_limit,
    :lower_limit, :inventory))
const _MAGNET_SOURCE_KINDS_V1 = Set((:candidate_solver, :measured,
    :manufactured, :structural, :proxy))

"One non-compensating magnet-engineering requirement selected from physical sources."
struct MagnetEngineeringRequirementV1
    metric_id::String
    unit::String
    gate_kind::Symbol
    description::String
    required_for_complete_engineering::Bool
end

"Candidate-specific magnet-engineering problem compiled without family routing."
struct MagnetEngineeringProblemV1
    design_id::String
    genome_physics_hash::String
    magnetic_source_ids::Vector{String}
    geometry_models::Vector{String}
    idealized_source_ids::Vector{String}
    declared_engineering_evaluators::Vector{String}
    requirements::Vector{MagnetEngineeringRequirementV1}
    evidence_tasks::Vector{String}
    problem_hash::String
end

"One observed engineering quantity plus its independently sourced acceptance limit."
struct MagnetEngineeringEvidenceV1
    design_id::String
    genome_physics_hash::String
    metric_id::String
    value::Union{Nothing,Float64}
    unit::String
    source_kind::Symbol
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    resolution_artifact_id::String
    resolution_artifact_hash::String
    candidate_binding_verified::Bool
    resolution_verified::Bool
    fidelity::Int
    source_result_status::Symbol
    limit_value::Union{Nothing,Float64}
    limit_unit::String
    limit_source_id::String
    limit_source_hash::String
    limit_applicability_verified::Bool
    observation_status::Symbol
    c2_observation_authorized::Bool
    feasibility_status::Symbol
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    evidence_hash::String
end

"Non-compensating aggregation of every required magnet-engineering component."
struct MagnetEngineeringAssessmentV1
    design_id::String
    genome_physics_hash::String
    problem_hash::String
    required_metric_ids::Vector{String}
    observed_metric_ids::Vector{String}
    c2_authorized_metric_ids::Vector{String}
    feasibility_pass_metric_ids::Vector{String}
    feasibility_fail_metric_ids::Vector{String}
    feasibility_unknown_metric_ids::Vector{String}
    status::Symbol
    complete_magnet_engineering_authorized::Bool
    complete_c2_authorized::Bool
    evidence_tasks::Vector{String}
    assessment_hash::String
end

function default_magnet_engineering_requirements_v1()
    specifications = [
        ("conductor_geometry_resolved", "1", :boolean_true,
            "Finite conductor and current-density domain are explicitly resolved."),
        ("peak_internal_conductor_field", "T", :upper_limit,
            "Peak total field inside the conductor is below an applicable material critical-surface limit."),
        ("engineering_current_density", "A/m^2", :upper_limit,
            "Engineering current density is below an applicable material and operating-state limit."),
        ("minimum_coil_coil_clearance", "m", :lower_limit,
            "Minimum coil clearance exceeds insulation, structure, tolerance, and assembly allowance."),
        ("minimum_plasma_coil_clearance", "m", :lower_limit,
            "Plasma-to-coil clearance exceeds wall, blanket, shield, tolerance, and maintenance allowance."),
        ("maximum_lorentz_line_load", "N/m", :upper_limit,
            "Maximum electromagnetic line load is below a support-system-derived limit."),
        ("maximum_structural_stress", "Pa", :upper_limit,
            "Maximum stress including support and fault cases is below the applicable allowable."),
        ("stored_magnetic_energy", "J", :inventory,
            "Candidate-bound stored magnetic energy inventory is resolution verified."),
        ("equivalent_inductance", "H", :inventory,
            "Candidate-bound inductance or inductance matrix is resolution verified."),
        ("quench_protection_resolved", "1", :boolean_true,
            "Quench detection, energy extraction, voltage, and hotspot response are resolved."),
        ("power_supply_requirements_resolved", "1", :boolean_true,
            "Ramp voltage, steady current, stored-energy handling, and supply power are resolved."),
        ("cryogenic_power_resolved", "1", :boolean_true,
            "Static and dynamic cryogenic loads and wall-plug power are resolved."),
        ("fault_loads_resolved", "1", :boolean_true,
            "Asymmetric fault, discharge, misalignment, and failed-coil loads are resolved."),
        ("maintainability_path_resolved", "1", :boolean_true,
            "Assembly, replacement, access, and remote-maintenance paths are geometrically resolved."),
    ]
    return MagnetEngineeringRequirementV1[
        MagnetEngineeringRequirementV1(id, unit, gate, description, true)
        for (id, unit, gate, description) in specifications]
end

function _magnetic_hardware_sources_v1(genome::Genome)
    return FieldSource[source for source in genome.field_sources if
        source.kind != "plasma_current" && lowercase(source.material) != "plasma"]
end

"Compile required magnet-engineering gates from explicit non-plasma field sources."
function compile_magnet_engineering_problem_v1(genome::Genome;
        requirements::Vector{MagnetEngineeringRequirementV1} =
            default_magnet_engineering_requirements_v1())
    isempty(requirements) && throw(ArgumentError("magnet requirements cannot be empty"))
    ids = [item.metric_id for item in requirements]
    length(ids) == length(unique(ids)) || throw(ArgumentError(
        "magnet requirement metric IDs must be unique"))
    all(item -> item.gate_kind in _MAGNET_GATE_KINDS_V1, requirements) ||
        throw(ArgumentError("invalid magnet gate kind"))
    sources = _magnetic_hardware_sources_v1(genome)
    source_ids = sort!(String[item.id for item in sources])
    geometry_models = sort!(unique(String[item.geometry_model for item in sources]))
    idealized = sort!(String[item.id for item in sources if
        occursin("filament", lowercase(item.geometry_model)) ||
        occursin("ideal", lowercase(item.material)) ||
        occursin("not_designed", lowercase(item.geometry_model))])
    tasks = String[]
    isempty(sources) && push!(tasks, "declare_non_plasma_magnetic_field_sources")
    append!(tasks, ["supply_magnet_metric:$(item.metric_id)" for item in requirements])
    append!(tasks, ["replace_idealized_magnetic_source:$id" for id in idealized])
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => genome.design_id,
        "genome_physics_hash" => genome.physics_hash,
        "magnetic_source_ids" => source_ids, "geometry_models" => geometry_models,
        "idealized_source_ids" => idealized,
        "declared_engineering_evaluators" => sort!(unique(copy(
            genome.engineering.required_evaluators))),
        "requirements" => [Dict{String,Any}(
            "metric_id" => item.metric_id, "unit" => item.unit,
            "gate_kind" => String(item.gate_kind), "description" => item.description,
            "required_for_complete_engineering" =>
                item.required_for_complete_engineering) for item in requirements],
        "evidence_tasks" => sort!(unique(tasks)))
    return MagnetEngineeringProblemV1(genome.design_id, genome.physics_hash,
        source_ids, geometry_models, idealized,
        sort!(unique(copy(genome.engineering.required_evaluators))),
        copy(requirements), sort!(unique(tasks)), canonical_hash(core))
end

function magnet_engineering_requirement_to_dict_v1(item::MagnetEngineeringRequirementV1)
    return Dict{String,Any}("metric_id" => item.metric_id, "unit" => item.unit,
        "gate_kind" => String(item.gate_kind), "description" => item.description,
        "required_for_complete_engineering" => item.required_for_complete_engineering)
end

function magnet_engineering_problem_to_dict_v1(item::MagnetEngineeringProblemV1)
    return Dict{String,Any}(
        "design_id" => item.design_id, "genome_physics_hash" => item.genome_physics_hash,
        "magnetic_source_ids" => item.magnetic_source_ids,
        "geometry_models" => item.geometry_models,
        "idealized_source_ids" => item.idealized_source_ids,
        "declared_engineering_evaluators" => item.declared_engineering_evaluators,
        "requirements" => [magnet_engineering_requirement_to_dict_v1(req)
            for req in item.requirements], "evidence_tasks" => item.evidence_tasks,
        "problem_hash" => item.problem_hash)
end

function _magnet_requirement_v1(problem::MagnetEngineeringProblemV1,
        metric_id::AbstractString)
    matches = filter(item -> item.metric_id == metric_id, problem.requirements)
    length(matches) == 1 || throw(ArgumentError(
        "unknown or duplicate magnet metric $metric_id"))
    return only(matches)
end

"Compile one component without allowing a numeric observation to invent its limit."
function compile_magnet_engineering_evidence_v1(
        problem::MagnetEngineeringProblemV1; metric_id::AbstractString,
        value::Union{Nothing,Real}, unit::AbstractString, source_kind::Symbol,
        source_artifact_id::AbstractString, source_artifact_hash::AbstractString,
        source_result_hash::AbstractString, resolution_artifact_id::AbstractString,
        resolution_artifact_hash::AbstractString,
        candidate_binding_verified::Bool, resolution_verified::Bool,
        fidelity::Integer, source_result_status::Symbol,
        limit_value::Union{Nothing,Real} = nothing,
        limit_unit::AbstractString = "", limit_source_id::AbstractString = "",
        limit_source_hash::AbstractString = "",
        limit_applicability_verified::Bool = false)
    requirement = _magnet_requirement_v1(problem, metric_id)
    source_kind in _MAGNET_SOURCE_KINDS_V1 || throw(ArgumentError(
        "invalid magnet evidence source kind"))
    source_result_status in (:pass, :fail, :unknown, :error) ||
        throw(ArgumentError("invalid magnet source result status"))
    fidelity >= 0 || throw(ArgumentError("magnet evidence fidelity must be non-negative"))
    numeric_value = value === nothing ? nothing : Float64(value)
    numeric_limit = limit_value === nothing ? nothing : Float64(limit_value)
    numeric_value === nothing || isfinite(numeric_value) || throw(ArgumentError(
        "magnet metric value must be finite or nothing"))
    numeric_limit === nothing || isfinite(numeric_limit) || throw(ArgumentError(
        "magnet metric limit must be finite or nothing"))
    tasks = String[]
    warnings = String[]
    isempty(source_artifact_id) && push!(tasks, "provide_source_artifact_id")
    length(source_artifact_hash) == 64 || push!(tasks, "provide_source_artifact_hash")
    length(source_result_hash) == 64 || push!(tasks, "provide_source_result_hash")
    isempty(resolution_artifact_id) && push!(tasks, "provide_resolution_artifact_id")
    length(resolution_artifact_hash) == 64 || push!(tasks,
        "provide_resolution_artifact_hash")
    candidate_binding_verified || push!(tasks, "verify_candidate_binding")
    resolution_verified || push!(tasks, "verify_metric_resolution")
    numeric_value === nothing && push!(tasks, "compute_metric:$(requirement.metric_id)")
    String(unit) == requirement.unit || push!(tasks,
        "convert_metric_unit:$(requirement.unit)")
    fidelity >= 2 || push!(tasks, "raise_metric_fidelity_to_c2")
    source_kind in (:candidate_solver, :measured) || push!(tasks,
        "replace_non_authoritative_source")

    provenance_complete = !isempty(source_artifact_id) &&
        length(source_artifact_hash) == 64 && length(source_result_hash) == 64 &&
        !isempty(resolution_artifact_id) && length(resolution_artifact_hash) == 64
    evidence_ready = candidate_binding_verified && resolution_verified &&
        provenance_complete && numeric_value !== nothing &&
        String(unit) == requirement.unit
    authoritative_kind = source_kind in (:candidate_solver, :measured)
    authoritative_failure = evidence_ready && authoritative_kind && fidelity >= 2 &&
        source_result_status in (:fail, :error)
    observation_status = authoritative_failure ? :fail :
        evidence_ready && source_result_status == :pass ? :pass : :unknown
    c2_observation = observation_status == :pass && authoritative_kind && fidelity >= 2

    limit_required = requirement.gate_kind in (:upper_limit, :lower_limit)
    if limit_required
        numeric_limit === nothing && push!(tasks, "provide_applicable_limit:$(requirement.metric_id)")
        String(limit_unit) == requirement.unit || push!(tasks,
            "provide_limit_unit:$(requirement.unit)")
        isempty(limit_source_id) && push!(tasks, "provide_limit_source:$(requirement.metric_id)")
        length(limit_source_hash) == 64 || push!(tasks,
            "provide_limit_source_hash:$(requirement.metric_id)")
        limit_applicability_verified || push!(tasks,
            "verify_limit_applicability:$(requirement.metric_id)")
    end
    limit_ready = !limit_required || (numeric_limit !== nothing &&
        String(limit_unit) == requirement.unit && !isempty(limit_source_id) &&
        length(limit_source_hash) == 64 && limit_applicability_verified)

    feasibility_status = authoritative_failure ? :fail : :unknown
    if c2_observation && limit_ready
        if requirement.gate_kind == :inventory
            feasibility_status = :pass
        elseif requirement.gate_kind == :boolean_true
            feasibility_status = numeric_value == 1.0 ? :pass : :fail
        elseif requirement.gate_kind == :upper_limit
            feasibility_status = numeric_value <= numeric_limit ? :pass : :fail
        elseif requirement.gate_kind == :lower_limit
            feasibility_status = numeric_value >= numeric_limit ? :pass : :fail
        end
    end
    observation_status == :pass && !c2_observation && push!(warnings,
        "Observed quantity is retained as lower-fidelity context but has no C2 authority.")
    observation_status == :pass && limit_required && !limit_ready && push!(warnings,
        "A computed value without an applicable material/structure limit is not an engineering pass.")
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => problem.design_id,
        "genome_physics_hash" => problem.genome_physics_hash,
        "problem_hash" => problem.problem_hash, "metric_id" => String(metric_id),
        "value" => numeric_value, "unit" => String(unit),
        "source_kind" => String(source_kind),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "resolution_artifact_id" => String(resolution_artifact_id),
        "resolution_artifact_hash" => String(resolution_artifact_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "resolution_verified" => resolution_verified, "fidelity" => Int(fidelity),
        "source_result_status" => String(source_result_status),
        "limit_value" => numeric_limit, "limit_unit" => String(limit_unit),
        "limit_source_id" => String(limit_source_id),
        "limit_source_hash" => String(limit_source_hash),
        "limit_applicability_verified" => limit_applicability_verified,
        "observation_status" => String(observation_status),
        "c2_observation_authorized" => c2_observation,
        "feasibility_status" => String(feasibility_status),
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return MagnetEngineeringEvidenceV1(problem.design_id,
        problem.genome_physics_hash, String(metric_id), numeric_value, String(unit),
        source_kind, String(source_artifact_id), String(source_artifact_hash),
        String(source_result_hash), String(resolution_artifact_id),
        String(resolution_artifact_hash), candidate_binding_verified,
        resolution_verified, Int(fidelity), source_result_status, numeric_limit,
        String(limit_unit), String(limit_source_id), String(limit_source_hash),
        limit_applicability_verified, observation_status, c2_observation,
        feasibility_status, sort!(unique(tasks)), warnings, canonical_hash(core))
end

function magnet_engineering_evidence_to_dict_v1(item::MagnetEngineeringEvidenceV1)
    return Dict{String,Any}(
        "design_id" => item.design_id, "genome_physics_hash" => item.genome_physics_hash,
        "metric_id" => item.metric_id, "value" => item.value, "unit" => item.unit,
        "source_kind" => String(item.source_kind),
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "resolution_artifact_id" => item.resolution_artifact_id,
        "resolution_artifact_hash" => item.resolution_artifact_hash,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "resolution_verified" => item.resolution_verified,
        "fidelity" => item.fidelity, "source_result_status" => String(item.source_result_status),
        "limit_value" => item.limit_value, "limit_unit" => item.limit_unit,
        "limit_source_id" => item.limit_source_id,
        "limit_source_hash" => item.limit_source_hash,
        "limit_applicability_verified" => item.limit_applicability_verified,
        "observation_status" => String(item.observation_status),
        "c2_observation_authorized" => item.c2_observation_authorized,
        "feasibility_status" => String(item.feasibility_status),
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "evidence_hash" => item.evidence_hash)
end

function assess_magnet_engineering_v1(problem::MagnetEngineeringProblemV1,
        evidence::Vector{MagnetEngineeringEvidenceV1})
    by_id = Dict{String,MagnetEngineeringEvidenceV1}()
    required = sort!(String[item.metric_id for item in problem.requirements if
        item.required_for_complete_engineering])
    for item in evidence
        item.design_id == problem.design_id || throw(ArgumentError(
            "magnet evidence design mismatch"))
        item.genome_physics_hash == problem.genome_physics_hash ||
            throw(ArgumentError("magnet evidence Genome hash mismatch"))
        item.metric_id in required || throw(ArgumentError(
            "magnet evidence metric is not required"))
        haskey(by_id, item.metric_id) && throw(ArgumentError(
            "duplicate magnet evidence for $(item.metric_id)"))
        by_id[item.metric_id] = item
    end
    observed = sort!(String[id for id in required if
        haskey(by_id, id) && by_id[id].observation_status == :pass])
    authorized = sort!(String[id for id in required if
        haskey(by_id, id) && by_id[id].c2_observation_authorized])
    passed = sort!(String[id for id in required if
        haskey(by_id, id) && by_id[id].feasibility_status == :pass])
    failed = sort!(String[id for id in required if
        haskey(by_id, id) && by_id[id].feasibility_status == :fail])
    unknown = sort!(String[id for id in required if
        !haskey(by_id, id) || by_id[id].feasibility_status == :unknown])
    status = !isempty(failed) ? :fail : isempty(unknown) ? :pass : :unknown
    complete = status == :pass && length(authorized) == length(required)
    tasks = String[]
    append!(tasks, ["supply_magnet_metric:$id" for id in unknown if !haskey(by_id, id)])
    for id in unknown
        haskey(by_id, id) && append!(tasks, by_id[id].evidence_tasks)
    end
    append!(tasks, ["repair_failed_magnet_gate:$id" for id in failed])
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => problem.design_id,
        "genome_physics_hash" => problem.genome_physics_hash,
        "problem_hash" => problem.problem_hash, "required_metric_ids" => required,
        "observed_metric_ids" => observed,
        "c2_authorized_metric_ids" => authorized,
        "feasibility_pass_metric_ids" => passed,
        "feasibility_fail_metric_ids" => failed,
        "feasibility_unknown_metric_ids" => unknown,
        "status" => String(status),
        "complete_magnet_engineering_authorized" => complete,
        "complete_c2_authorized" => complete,
        "evidence_hashes" => sort!(String[item.evidence_hash for item in values(by_id)]),
        "evidence_tasks" => sort!(unique(tasks)))
    return MagnetEngineeringAssessmentV1(problem.design_id,
        problem.genome_physics_hash, problem.problem_hash, required, observed,
        authorized, passed, failed, unknown, status, complete, complete,
        sort!(unique(tasks)), canonical_hash(core))
end

function magnet_engineering_assessment_to_dict_v1(item::MagnetEngineeringAssessmentV1)
    return Dict{String,Any}(
        "design_id" => item.design_id, "genome_physics_hash" => item.genome_physics_hash,
        "problem_hash" => item.problem_hash,
        "required_metric_ids" => item.required_metric_ids,
        "observed_metric_ids" => item.observed_metric_ids,
        "c2_authorized_metric_ids" => item.c2_authorized_metric_ids,
        "feasibility_pass_metric_ids" => item.feasibility_pass_metric_ids,
        "feasibility_fail_metric_ids" => item.feasibility_fail_metric_ids,
        "feasibility_unknown_metric_ids" => item.feasibility_unknown_metric_ids,
        "status" => String(item.status),
        "complete_magnet_engineering_authorized" =>
            item.complete_magnet_engineering_authorized,
        "complete_c2_authorized" => item.complete_c2_authorized,
        "evidence_tasks" => item.evidence_tasks,
        "assessment_hash" => item.assessment_hash)
end

function magnet_engineering_evidence_bundle_v1(genome::Genome,
        item::MagnetEngineeringAssessmentV1)
    genome.design_id == item.design_id || throw(ArgumentError(
        "magnet assessment design mismatch"))
    genome.physics_hash == item.genome_physics_hash || throw(ArgumentError(
        "magnet assessment Genome hash mismatch"))
    value = item.status == :pass ? true : item.status == :fail ? false : nothing
    metric = MetricResult("magnet_engineering_complete", value;
        fidelity = 2,
        applicability = "Candidate-specific non-plasma magnetic sources and all non-compensating finite-conductor, load, energy, protection, power, fault, and maintenance requirements.",
        status = item.status, constraints_checked = item.required_metric_ids,
        solver_name = "magnet_engineering_compiler_v1",
        solver_version = "1.0.0", input_hash = item.genome_physics_hash,
        run_hash = item.assessment_hash,
        source_basis = ["component_evidence_hashes_in_assessment"],
        warnings = item.evidence_tasks)
    claim = item.complete_c2_authorized ?
        "C2_support_complete_magnet_engineering" :
        "C2_magnet_engineering_unknown_or_failed"
    return EvaluationBundle("magnet_engineering_compiler_v1",
        item.design_id, genome.family, 2, item.status, [metric],
        copy(metric.warnings), item.genome_physics_hash, item.assessment_hash, claim)
end
