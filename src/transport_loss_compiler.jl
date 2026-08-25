const _TRANSPORT_SOURCE_KINDS_V1 = Set((:candidate_solver, :measured,
    :proxy, :manufactured, :structural))

"One physical loss or transport quantity required by the candidate topology."
struct TransportLossRequirementV1
    metric_id::String
    unit::String
    mechanism_class::Symbol
    description::String
end

"Topology-routed transport/loss problem with no family-name dispatch."
struct TransportLossProblemV1
    design_id::String
    genome_physics_hash::String
    has_open_field_regions::Bool
    has_closed_field_regions::Bool
    has_material_endpoints::Bool
    is_three_dimensional::Bool
    requirement_ids::Vector{String}
    requirements::Vector{TransportLossRequirementV1}
    evidence_tasks::Vector{String}
    problem_hash::String
end

"Candidate-bound evidence for one transport or loss component."
struct TransportLossEvidenceV1
    design_id::String
    genome_physics_hash::String
    metric_id::String
    value::Union{Nothing,Float64}
    unit::String
    source_kind::Symbol
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    candidate_binding_verified::Bool
    resolution_verified::Bool
    applicability_verified::Bool
    fidelity::Int
    source_result_status::Symbol
    status::Symbol
    c2_component_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    evidence_hash::String
end

"Non-compensating completeness state of the topology-selected loss problem."
struct TransportLossAssessmentV1
    design_id::String
    genome_physics_hash::String
    problem_hash::String
    required_metric_ids::Vector{String}
    observed_metric_ids::Vector{String}
    c2_authorized_metric_ids::Vector{String}
    failed_metric_ids::Vector{String}
    unknown_metric_ids::Vector{String}
    status::Symbol
    complete_transport_c2_authorized::Bool
    evidence_tasks::Vector{String}
    assessment_hash::String
end

function _transport_requirement_v1(id, unit, mechanism, description)
    return TransportLossRequirementV1(String(id), String(unit), mechanism,
        String(description))
end

function _transport_physical_features_v1(genome::Genome)
    class = lowercase(genome.topology.field_line_class)
    open_flux = any(connection -> occursin("open", lowercase(connection.kind)),
        genome.flux_connections)
    has_open = occursin("open", class) || occursin("mixed", class) || open_flux
    expected_closed = genome.topology.expected_flux_surfaces === true
    has_closed = occursin("closed", class) || occursin("toroidal", class) ||
        occursin("mixed", class) || expected_closed
    endpoint_kinds = Set(("material_wall", "end_expander", "divertor",
        "limiter", "electrode", "target"))
    has_material = any(region -> region.kind in endpoint_kinds,
        genome.plasma_regions) || !isempty(genome.exhaust.region_ids)
    is_3d = genome.symmetry.class != "axisymmetric" ||
        any(source -> occursin("three_dimensional", lowercase(source.kind)) ||
            occursin("3d", lowercase(source.geometry_model)), genome.field_sources)
    return has_open, has_closed, has_material, is_3d
end

"Compile loss mechanisms from field topology, boundaries, and dimensionality."
function compile_transport_loss_problem_v1(genome::Genome)
    has_open, has_closed, has_material, is_3d =
        _transport_physical_features_v1(genome)
    requirements = TransportLossRequirementV1[
        _transport_requirement_v1("particle_inventory", "1", :inventory,
            "Species-resolved particle inventory inside each plasma control volume."),
        _transport_requirement_v1("thermal_energy_inventory", "J", :inventory,
            "Species-resolved thermal energy inventory inside each plasma control volume."),
        _transport_requirement_v1("charge_exchange_particle_loss_rate", "s^-1", :atomic,
            "Charge-exchange particle loss integrated over the candidate volume."),
        _transport_requirement_v1("radiation_power_loss", "W", :radiation,
            "Bremsstrahlung, synchrotron, line, recombination, and impurity radiation as applicable."),
        _transport_requirement_v1("orbit_wall_loss_fraction", "1", :orbit,
            "Finite-time full/guiding-center orbit intersection fraction with declared material domains."),
        _transport_requirement_v1("cross_field_particle_flux", "s^-1", :cross_field,
            "Integrated cross-field particle flow through the candidate boundary."),
        _transport_requirement_v1("cross_field_energy_flux", "W", :cross_field,
            "Integrated cross-field energy flow through the candidate boundary."),
    ]
    if has_open
        append!(requirements, TransportLossRequirementV1[
            _transport_requirement_v1("adiabatic_prompt_loss_fraction", "1",
                :open_field_orbit, "Collisionless first-invariant prompt loss for the declared pitch distribution."),
            _transport_requirement_v1("open_field_connection_length", "m",
                :open_field_geometry, "Candidate-bound field-line connection length to each physical endpoint."),
            _transport_requirement_v1("collisional_loss_cone_refill_rate", "s^-1",
                :collisional, "Collision-operator refill of open-field loss regions."),
            _transport_requirement_v1("parallel_particle_boundary_flux", "s^-1",
                :parallel, "Species-resolved parallel particle flow through open boundaries."),
            _transport_requirement_v1("parallel_energy_boundary_flux", "W",
                :parallel, "Species-resolved parallel energy flow through open boundaries."),
            _transport_requirement_v1("electrostatic_barrier_energy", "J",
                :electrostatic, "Self-consistent electrostatic potential contribution to particle escape."),
            _transport_requirement_v1("end_loss_recovery_power", "W",
                :energy_recovery, "Recoverable and unrecoverable open-end power with conversion efficiency."),
        ])
    end
    if has_closed
        append!(requirements, TransportLossRequirementV1[
            _transport_requirement_v1("guiding_center_orbit_loss_fraction", "1",
                :closed_field_orbit, "Finite-time guiding-center/full-orbit loss from closed regions."),
            _transport_requirement_v1("neoclassical_transport_driver_effective_ripple", "1",
                :neoclassical_diagnostic, "Candidate-specific three-dimensional neoclassical transport driver diagnostic."),
            _transport_requirement_v1("neoclassical_particle_flux", "s^-1",
                :neoclassical, "Integrated neoclassical particle flux through the closed-region boundary."),
            _transport_requirement_v1("neoclassical_energy_flux", "W",
                :neoclassical, "Integrated neoclassical energy flux through the closed-region boundary."),
            _transport_requirement_v1("turbulent_particle_flux", "s^-1",
                :turbulence, "Integrated turbulent particle flux at resolved scales."),
            _transport_requirement_v1("turbulent_energy_flux", "W",
                :turbulence, "Integrated turbulent energy flux at resolved scales."),
            _transport_requirement_v1("stochastic_field_particle_flux", "s^-1",
                :stochastic_field, "Particle loss associated with islands or stochastic field-line regions."),
        ])
    end
    ids = [item.metric_id for item in requirements]
    length(ids) == length(unique(ids)) || error("transport requirement IDs are not unique")
    tasks = ["compute_transport_metric:$id" for id in ids]
    !has_material && push!(tasks, "declare_material_loss_boundaries")
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => genome.design_id,
        "genome_physics_hash" => genome.physics_hash,
        "has_open_field_regions" => has_open,
        "has_closed_field_regions" => has_closed,
        "has_material_endpoints" => has_material,
        "is_three_dimensional" => is_3d,
        "requirements" => [Dict{String,Any}(
            "metric_id" => item.metric_id, "unit" => item.unit,
            "mechanism_class" => String(item.mechanism_class),
            "description" => item.description) for item in requirements],
        "evidence_tasks" => sort!(unique(tasks)))
    return TransportLossProblemV1(genome.design_id, genome.physics_hash,
        has_open, has_closed, has_material, is_3d, sort!(copy(ids)),
        requirements, sort!(unique(tasks)), canonical_hash(core))
end

function transport_loss_requirement_to_dict_v1(item::TransportLossRequirementV1)
    return Dict{String,Any}("metric_id" => item.metric_id, "unit" => item.unit,
        "mechanism_class" => String(item.mechanism_class),
        "description" => item.description)
end

function transport_loss_problem_to_dict_v1(item::TransportLossProblemV1)
    return Dict{String,Any}(
        "design_id" => item.design_id, "genome_physics_hash" => item.genome_physics_hash,
        "has_open_field_regions" => item.has_open_field_regions,
        "has_closed_field_regions" => item.has_closed_field_regions,
        "has_material_endpoints" => item.has_material_endpoints,
        "is_three_dimensional" => item.is_three_dimensional,
        "requirement_ids" => item.requirement_ids,
        "requirements" => [transport_loss_requirement_to_dict_v1(req)
            for req in item.requirements], "evidence_tasks" => item.evidence_tasks,
        "problem_hash" => item.problem_hash)
end

function _transport_requirement_by_id_v1(problem::TransportLossProblemV1,
        metric_id::AbstractString)
    matches = filter(item -> item.metric_id == metric_id, problem.requirements)
    length(matches) == 1 || throw(ArgumentError(
        "transport metric is not required by candidate topology: $metric_id"))
    return only(matches)
end

function compile_transport_loss_evidence_v1(problem::TransportLossProblemV1;
        metric_id::AbstractString, value::Union{Nothing,Real}, unit::AbstractString,
        source_kind::Symbol, source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString, source_result_hash::AbstractString,
        candidate_binding_verified::Bool, resolution_verified::Bool,
        applicability_verified::Bool, fidelity::Integer,
        source_result_status::Symbol)
    requirement = _transport_requirement_by_id_v1(problem, metric_id)
    source_kind in _TRANSPORT_SOURCE_KINDS_V1 || throw(ArgumentError(
        "invalid transport evidence source kind"))
    source_result_status in (:pass, :fail, :unknown, :error) ||
        throw(ArgumentError("invalid transport source result status"))
    fidelity >= 0 || throw(ArgumentError("transport fidelity must be non-negative"))
    numeric = value === nothing ? nothing : Float64(value)
    numeric === nothing || isfinite(numeric) || throw(ArgumentError(
        "transport value must be finite or nothing"))
    tasks = String[]
    isempty(source_artifact_id) && push!(tasks, "provide_source_artifact_id")
    length(source_artifact_hash) == 64 || push!(tasks, "provide_source_artifact_hash")
    length(source_result_hash) == 64 || push!(tasks, "provide_source_result_hash")
    candidate_binding_verified || push!(tasks, "verify_candidate_binding")
    resolution_verified || push!(tasks, "verify_transport_resolution")
    applicability_verified || push!(tasks, "verify_operator_applicability")
    numeric === nothing && push!(tasks, "compute_transport_metric:$(requirement.metric_id)")
    String(unit) == requirement.unit || push!(tasks,
        "convert_transport_unit:$(requirement.unit)")
    fidelity >= 2 || push!(tasks, "raise_transport_fidelity_to_c2")
    source_kind in (:candidate_solver, :measured) || push!(tasks,
        "replace_non_authoritative_transport_source")
    provenance = !isempty(source_artifact_id) && length(source_artifact_hash) == 64 &&
        length(source_result_hash) == 64
    ready = provenance && candidate_binding_verified && resolution_verified &&
        applicability_verified && numeric !== nothing && String(unit) == requirement.unit
    authoritative = ready && fidelity >= 2 &&
        source_kind in (:candidate_solver, :measured)
    status = authoritative && source_result_status in (:fail, :error) ? :fail :
        ready && source_result_status == :pass ? :pass : :unknown
    authorized = status == :pass && authoritative
    warnings = String[]
    status == :pass && !authorized && push!(warnings,
        "Observed loss/transport quantity is lower-fidelity context and has no C2 authority.")
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => problem.design_id,
        "genome_physics_hash" => problem.genome_physics_hash,
        "problem_hash" => problem.problem_hash, "metric_id" => String(metric_id),
        "value" => numeric, "unit" => String(unit),
        "source_kind" => String(source_kind),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "resolution_verified" => resolution_verified,
        "applicability_verified" => applicability_verified,
        "fidelity" => Int(fidelity), "source_result_status" => String(source_result_status),
        "status" => String(status), "c2_component_authorized" => authorized,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return TransportLossEvidenceV1(problem.design_id,
        problem.genome_physics_hash, String(metric_id), numeric, String(unit),
        source_kind, String(source_artifact_id), String(source_artifact_hash),
        String(source_result_hash), candidate_binding_verified, resolution_verified,
        applicability_verified, Int(fidelity), source_result_status, status,
        authorized, sort!(unique(tasks)), warnings, canonical_hash(core))
end

function transport_loss_evidence_to_dict_v1(item::TransportLossEvidenceV1)
    return Dict{String,Any}(
        "design_id" => item.design_id, "genome_physics_hash" => item.genome_physics_hash,
        "metric_id" => item.metric_id, "value" => item.value, "unit" => item.unit,
        "source_kind" => String(item.source_kind),
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "resolution_verified" => item.resolution_verified,
        "applicability_verified" => item.applicability_verified,
        "fidelity" => item.fidelity,
        "source_result_status" => String(item.source_result_status),
        "status" => String(item.status),
        "c2_component_authorized" => item.c2_component_authorized,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "evidence_hash" => item.evidence_hash)
end

function assess_transport_loss_v1(problem::TransportLossProblemV1,
        evidence::Vector{TransportLossEvidenceV1})
    by_id = Dict{String,TransportLossEvidenceV1}()
    for item in evidence
        item.design_id == problem.design_id || throw(ArgumentError(
            "transport evidence design mismatch"))
        item.genome_physics_hash == problem.genome_physics_hash ||
            throw(ArgumentError("transport evidence Genome hash mismatch"))
        item.metric_id in problem.requirement_ids || throw(ArgumentError(
            "transport evidence metric mismatch"))
        haskey(by_id, item.metric_id) && throw(ArgumentError(
            "duplicate transport evidence for $(item.metric_id)"))
        by_id[item.metric_id] = item
    end
    required = problem.requirement_ids
    observed = sort!(String[id for id in required if
        haskey(by_id, id) && by_id[id].status == :pass])
    authorized = sort!(String[id for id in required if
        haskey(by_id, id) && by_id[id].c2_component_authorized])
    failed = sort!(String[id for id in required if
        haskey(by_id, id) && by_id[id].status == :fail])
    # A lower-fidelity observation is useful context, but it has not answered
    # the C2 transport requirement. Keep every non-authorized, non-failed
    # component in the unknown set so its upgrade task cannot disappear.
    unknown = sort!(String[id for id in required if
        !(id in authorized) && !(id in failed)])
    status = !isempty(failed) ? :fail : isempty(unknown) &&
        length(authorized) == length(required) ? :pass : :unknown
    complete = status == :pass
    tasks = String[]
    append!(tasks, ["compute_transport_metric:$id" for id in unknown if !haskey(by_id, id)])
    for id in unknown
        haskey(by_id, id) && append!(tasks, by_id[id].evidence_tasks)
    end
    append!(tasks, ["repair_failed_transport_metric:$id" for id in failed])
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => problem.design_id,
        "genome_physics_hash" => problem.genome_physics_hash,
        "problem_hash" => problem.problem_hash,
        "required_metric_ids" => required, "observed_metric_ids" => observed,
        "c2_authorized_metric_ids" => authorized,
        "failed_metric_ids" => failed, "unknown_metric_ids" => unknown,
        "status" => String(status),
        "complete_transport_c2_authorized" => complete,
        "evidence_hashes" => sort!(String[item.evidence_hash for item in values(by_id)]),
        "evidence_tasks" => sort!(unique(tasks)))
    return TransportLossAssessmentV1(problem.design_id,
        problem.genome_physics_hash, problem.problem_hash, required, observed,
        authorized, failed, unknown, status, complete, sort!(unique(tasks)),
        canonical_hash(core))
end

function transport_loss_assessment_to_dict_v1(item::TransportLossAssessmentV1)
    return Dict{String,Any}(
        "design_id" => item.design_id, "genome_physics_hash" => item.genome_physics_hash,
        "problem_hash" => item.problem_hash,
        "required_metric_ids" => item.required_metric_ids,
        "observed_metric_ids" => item.observed_metric_ids,
        "c2_authorized_metric_ids" => item.c2_authorized_metric_ids,
        "failed_metric_ids" => item.failed_metric_ids,
        "unknown_metric_ids" => item.unknown_metric_ids,
        "status" => String(item.status),
        "complete_transport_c2_authorized" => item.complete_transport_c2_authorized,
        "evidence_tasks" => item.evidence_tasks,
        "assessment_hash" => item.assessment_hash)
end

function transport_loss_evidence_bundle_v1(genome::Genome,
        item::TransportLossAssessmentV1)
    genome.design_id == item.design_id || throw(ArgumentError("transport design mismatch"))
    genome.physics_hash == item.genome_physics_hash || throw(ArgumentError(
        "transport Genome hash mismatch"))
    value = item.status == :pass ? true : item.status == :fail ? false : nothing
    metric = MetricResult("transport_and_particle_loss_complete", value;
        fidelity = 2,
        applicability = "Candidate topology-selected orbit, parallel, cross-field, neoclassical, turbulent, atomic, radiation, and recovery quantities.",
        status = item.status, constraints_checked = item.required_metric_ids,
        solver_name = "transport_loss_compiler_v1", solver_version = "1.0.0",
        input_hash = item.genome_physics_hash, run_hash = item.assessment_hash,
        source_basis = ["component_evidence_hashes_in_assessment"],
        warnings = item.evidence_tasks)
    claim = item.complete_transport_c2_authorized ?
        "C2_support_complete_transport_and_loss" :
        "C2_transport_and_loss_unknown_or_failed"
    return EvaluationBundle("transport_loss_compiler_v1", item.design_id,
        genome.family, 2, item.status, [metric], copy(metric.warnings),
        item.genome_physics_hash, item.assessment_hash, claim)
end
