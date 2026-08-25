const _STABILITY_STAGE_STATUSES_V2 = Set((:pass, :fail, :unknown, :unsupported))

"A solver-independent definition of the perturbation actually evaluated."
struct StabilityPerturbationSpecV2
    perturbation_id::String
    operator_id::String
    equations::Vector{String}
    state_input_ids::Vector{String}
    boundary_conditions::Vector{String}
    time_semantics::Symbol
    resolution_levels::Vector{String}
    normalization::String
    perturbation_hash::String
end

"Capability declaration only; it contains no device or family selector."
struct StabilityCapabilityContractV2
    capability_id::String
    operator_id::String
    required_input_ids::Vector{String}
    supported_dimensions::Vector{String}
    supported_boundary_classes::Vector{String}
    supported_time_modes::Vector{String}
    solver_id::String
    backend_available::Bool
    validity_domain::Dict{String,Any}
    claim_boundary::String
    contract_hash::String
end

"Candidate-bound result returned by any stability backend."
struct StabilityEvidenceEnvelopeV2
    candidate_binding_hash::String
    state_result_hash::String
    operator_id::String
    capability_id::String
    perturbation::StabilityPerturbationSpecV2
    status::Symbol
    favorable::Union{Nothing,Bool}
    signed_normalized_margin::Union{Nothing,Float64}
    convergence_history::Vector{Dict{String,Any}}
    validity_domain_covered::Bool
    resolution_verified::Bool
    covered_input_ids::Vector{String}
    source_kind::Symbol
    source_artifact_paths::Vector{String}
    source_artifact_hashes::Vector{String}
    source_result_hash::String
    candidate_binding_verified::Bool
    evidence_authorized::Bool
    minimal_failure_scope::Dict{String,Any}
    claim_boundary::String
    evidence_tasks::Vector{String}
    evidence_hash::String
end

"Fail-closed Stage-4 inventory compiled from operator capabilities, not labels."
struct StabilityStageCompilationV2
    candidate_binding_hash::String
    required_operator_ids::Vector{String}
    compatible_operator_ids::Vector{String}
    unsupported_operator_ids::Vector{String}
    missing_evidence_operator_ids::Vector{String}
    unknown_operator_ids::Vector{String}
    passed_operator_ids::Vector{String}
    failed_operator_ids::Vector{String}
    auxiliary_failed_operator_ids::Vector{String}
    stage_status::Symbol
    stage_complete::Bool
    c2_stability_support_authorized::Bool
    authoritative_hard_failure::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    evidence::Vector{StabilityEvidenceEnvelopeV2}
    compilation_hash::String
end

function StabilityPerturbationSpecV2(perturbation_id::AbstractString,
        operator_id::AbstractString; equations::Vector{String},
        state_input_ids::Vector{String}, boundary_conditions::Vector{String},
        time_semantics::Symbol, resolution_levels::Vector{String},
        normalization::AbstractString)
    isempty(equations) && throw(ArgumentError("perturbation equations cannot be empty"))
    isempty(resolution_levels) && throw(ArgumentError("resolution levels cannot be empty"))
    core = Dict{String,Any}(
        "schema_version" => "2.0.0",
        "perturbation_id" => String(perturbation_id),
        "operator_id" => String(operator_id),
        "equations" => sort!(unique(copy(equations))),
        "state_input_ids" => sort!(unique(copy(state_input_ids))),
        "boundary_conditions" => sort!(unique(copy(boundary_conditions))),
        "time_semantics" => String(time_semantics),
        "resolution_levels" => copy(resolution_levels),
        "normalization" => String(normalization))
    return StabilityPerturbationSpecV2(String(perturbation_id), String(operator_id),
        core["equations"], core["state_input_ids"], core["boundary_conditions"],
        time_semantics, core["resolution_levels"], String(normalization), canonical_hash(core))
end

function StabilityCapabilityContractV2(capability_id::AbstractString,
        operator_id::AbstractString; required_input_ids::Vector{String},
        supported_dimensions::Vector{String}, supported_boundary_classes::Vector{String},
        supported_time_modes::Vector{String}, solver_id::AbstractString,
        backend_available::Bool, validity_domain::Dict{String,Any},
        claim_boundary::AbstractString)
    core = Dict{String,Any}(
        "schema_version" => "2.0.0", "capability_id" => String(capability_id),
        "operator_id" => String(operator_id),
        "required_input_ids" => sort!(unique(copy(required_input_ids))),
        "supported_dimensions" => sort!(unique(copy(supported_dimensions))),
        "supported_boundary_classes" => sort!(unique(copy(supported_boundary_classes))),
        "supported_time_modes" => sort!(unique(copy(supported_time_modes))),
        "solver_id" => String(solver_id), "backend_available" => backend_available,
        "validity_domain" => validity_domain,
        "claim_boundary" => String(claim_boundary))
    return StabilityCapabilityContractV2(String(capability_id), String(operator_id),
        core["required_input_ids"], core["supported_dimensions"],
        core["supported_boundary_classes"], core["supported_time_modes"],
        String(solver_id), backend_available, deepcopy(validity_domain),
        String(claim_boundary), canonical_hash(core))
end

function default_stability_capability_registry_v2()
    local_only = "One declared perturbation/operator result only; not nonlinear saturation, disruption avoidance, transport, engineering, robustness, or all-mode stability."
    c(id, inputs, dims, boundaries, solver; available = false,
            time_modes = ["steady", "eigenvalue"],
            validity = Dict{String,Any}()) =
        StabilityCapabilityContractV2("$(id)_capability", id;
            required_input_ids = String.(inputs), supported_dimensions = String.(dims),
            supported_boundary_classes = String.(boundaries),
            supported_time_modes = String.(time_modes), solver_id = solver,
            backend_available = available, validity_domain = validity,
            claim_boundary = local_only)
    return StabilityCapabilityContractV2[
        c("three_dimensional_equilibrium_v2", ["boundary_geometry", "pressure_profile",
            "field_or_current_state"], ["periodic_3d"], ["closed_flux"],
            "equilibrium_backend_adapter_v2"; available = true),
        c("mercier_interchange_v2", ["equilibrium_state", "pressure_profile",
            "magnetic_well", "magnetic_shear"], ["periodic_3d"], ["closed_flux"],
            "mercier_backend_adapter_v2"; available = true),
        c("infinite_n_ballooning_v2", ["equilibrium_state", "pressure_profile",
            "field_line_geometry", "magnetic_shear"], ["periodic_3d"], ["closed_flux"],
            "ballooning_backend_adapter_v2"; available = true),
        c("error_field_response_v2", ["equilibrium_state", "coil_error_spectrum",
            "response_model"], ["periodic_3d"], ["closed_flux"],
            "desc_vacuum_current_error_response_adapter_v2"; available = true),
        c("fast_ion_orbit_v2", ["equilibrium_state", "fast_ion_distribution",
            "wall_geometry"], ["periodic_3d"], ["closed_flux"],
            "desc_guiding_center_backend_adapter_v2"; available = true,
            time_modes = ["steady", "transient"]),
        c("interchange_flute_v2", ["finite_beta_state", "pressure_profile",
            "magnetic_curvature", "stabilization_model"], ["axisymmetric_2d", "periodic_3d"],
            ["open_flux"], "open_linear_interchange_eigen_adapter_v2"; available = true),
        c("m1_global_v2", ["finite_beta_equilibrium", "conducting_boundary",
            "axial_profile"], ["axisymmetric_2d", "periodic_3d"], ["open_flux"],
            "open_linear_m1_eigen_adapter_v2"; available = true),
        c("finite_larmor_radius_v2", ["ion_distribution", "density_profile",
            "temperature_profile", "magnetic_field", "mode_spectrum",
            "species_mass_charge", "coupled_mode_response"],
            ["axisymmetric_2d", "periodic_3d"], ["open_flux"],
            "gyroaveraged_flr_kernel_adapter_v2"; available = true),
        c("drift_cyclotron_loss_cone_v2", ["ion_distribution", "loss_cone_boundary",
            "density_gradient", "electron_temperature", "finite_larmor_radius"],
            ["axisymmetric_2d", "periodic_3d"], ["open_flux"],
            "slab_perpendicular_dclc_dispersion_adapter_v2"; available = true),
        c("alfven_ion_cyclotron_v2", ["ion_distribution", "pressure_anisotropy",
            "beta_profile", "cyclotron_spectrum"], ["axisymmetric_2d", "periodic_3d"],
            ["open_flux"], "parallel_bimaxwellian_aic_dispersion_adapter_v2";
            available = true),
        c("ambipolar_response_v2", ["species_fluxes", "potential_profile",
            "loss_boundary"], ["axisymmetric_2d", "periodic_3d"], ["open_flux"],
            "ambipolar_backend_adapter_v2"; available = true),
        c("flow_shear_v2", ["electric_field_profile", "flow_profile", "magnetic_field",
            "mode_spectrum"], ["axisymmetric_2d", "periodic_3d"], ["open_flux"],
            "open_exb_flow_shear_adapter_v2"; available = true),
        c("minimum_b_stabilization_path_v2", ["vacuum_field_state",
            "radial_field_strength_curvature", "axial_field_strength_curvature"],
            ["axisymmetric_2d", "periodic_3d"], ["open_flux"],
            "minimum_b_diagnostic_adapter_v2"; available = true)]
end

function stability_capability_registry_hash_v2(registry = default_stability_capability_registry_v2())
    return canonical_hash(Dict("schema_version" => "2.0.0",
        "contract_hashes" => sort!(getfield.(registry, :contract_hash))))
end

function compile_stability_evidence_envelope_v2(candidate_binding_hash::AbstractString,
        state_result_hash::AbstractString, contract::StabilityCapabilityContractV2,
        perturbation::StabilityPerturbationSpecV2; favorable::Union{Nothing,Bool} = nothing,
        signed_normalized_margin::Union{Nothing,Real} = nothing,
        convergence_history::Vector{Dict{String,Any}} = Dict{String,Any}[],
        validity_domain_covered::Bool = false, resolution_verified::Bool = false,
        covered_input_ids::Vector{String} = String[], source_kind::Symbol = :candidate_solver,
        source_artifact_paths::Vector{String} = String[],
        source_artifact_hashes::Vector{String} = String[],
        source_result_hash::AbstractString = "", candidate_binding_verified::Bool = false,
        minimal_failure_scope::Dict{String,Any} = Dict{String,Any}(),
        claim_boundary::AbstractString = contract.claim_boundary)
    perturbation.operator_id == contract.operator_id || throw(ArgumentError(
        "perturbation operator does not match capability contract"))
    source_kind in (:candidate_solver, :measured, :manufactured, :screening) ||
        throw(ArgumentError("invalid stability evidence source kind"))
    margin = signed_normalized_margin === nothing ? nothing : Float64(signed_normalized_margin)
    margin === nothing || isfinite(margin) || throw(ArgumentError("stability margin must be finite"))
    covered = sort!(unique(copy(covered_input_ids)))
    missing_inputs = sort!(setdiff(contract.required_input_ids, covered))
    perturbation_time_compatible = String(perturbation.time_semantics) in
        contract.supported_time_modes
    tasks = String[]
    candidate_binding_verified || push!(tasks, "verify_candidate_binding")
    isempty(state_result_hash) && push!(tasks, "provide_candidate_state_result_hash")
    length(source_artifact_paths) == length(source_artifact_hashes) ||
        push!(tasks, "repair_source_artifact_hash_inventory")
    isempty(source_artifact_paths) && push!(tasks, "provide_source_artifact")
    isempty(source_result_hash) && push!(tasks, "provide_source_result_hash")
    favorable === nothing && push!(tasks, "evaluate_operator:$(contract.operator_id)")
    margin === nothing && push!(tasks, "provide_signed_margin:$(contract.operator_id)")
    isempty(convergence_history) && push!(tasks, "provide_convergence_history:$(contract.operator_id)")
    validity_domain_covered || push!(tasks, "verify_validity_domain:$(contract.operator_id)")
    resolution_verified || push!(tasks, "verify_resolution:$(contract.operator_id)")
    append!(tasks, ["provide_operator_input:$(contract.operator_id):$id" for id in missing_inputs])
    perturbation_time_compatible || push!(tasks,
        "repair_perturbation_time_semantics:$(contract.operator_id)")
    source_kind in (:manufactured, :screening) && push!(tasks,
        "replace_nonphysical_source:$(contract.operator_id)")
    provenance_complete = !isempty(state_result_hash) && !isempty(source_artifact_paths) &&
        length(source_artifact_paths) == length(source_artifact_hashes) &&
        all(!isempty, source_artifact_hashes) && !isempty(source_result_hash)
    authorized = candidate_binding_verified && provenance_complete && favorable !== nothing &&
        margin !== nothing && !isempty(convergence_history) && validity_domain_covered &&
        resolution_verified && isempty(missing_inputs) && perturbation_time_compatible &&
        source_kind in (:candidate_solver, :measured)
    status = authorized ? (favorable === true && margin >= 0 ? :pass : :fail) : :unknown
    core = Dict{String,Any}(
        "schema_version" => "2.0.0", "candidate_binding_hash" => String(candidate_binding_hash),
        "state_result_hash" => String(state_result_hash), "operator_id" => contract.operator_id,
        "capability_id" => contract.capability_id, "perturbation_hash" => perturbation.perturbation_hash,
        "status" => String(status), "favorable" => favorable,
        "signed_normalized_margin" => margin, "convergence_history" => convergence_history,
        "validity_domain_covered" => validity_domain_covered,
        "perturbation_time_compatible" => perturbation_time_compatible,
        "resolution_verified" => resolution_verified, "covered_input_ids" => covered,
        "source_kind" => String(source_kind), "source_artifact_paths" => source_artifact_paths,
        "source_artifact_hashes" => source_artifact_hashes,
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "evidence_authorized" => authorized, "minimal_failure_scope" => minimal_failure_scope,
        "claim_boundary" => String(claim_boundary), "evidence_tasks" => sort!(unique(tasks)))
    return StabilityEvidenceEnvelopeV2(String(candidate_binding_hash), String(state_result_hash),
        contract.operator_id, contract.capability_id, perturbation, status, favorable, margin,
        deepcopy(convergence_history), validity_domain_covered, resolution_verified, covered,
        source_kind, copy(source_artifact_paths), copy(source_artifact_hashes),
        String(source_result_hash), candidate_binding_verified, authorized,
        deepcopy(minimal_failure_scope), String(claim_boundary), sort!(unique(tasks)), canonical_hash(core))
end

"Bridge a candidate-bound ambipolar response solve into the common Stage-4 protocol."
function compile_ambipolar_stage4_evidence_v2(candidate_binding_hash::AbstractString,
        observation::AmbipolarPotentialResponseObservationV1;
        source_artifact_paths::Vector{String}, source_artifact_hashes::Vector{String},
        convergence_history::Vector{Dict{String,Any}},
        candidate_binding_verified::Bool,
        quasineutrality_tolerance::Real = 1.0e-6,
        registry::Vector{StabilityCapabilityContractV2} = default_stability_capability_registry_v2())
    tolerance = Float64(quasineutrality_tolerance)
    isfinite(tolerance) && tolerance > 0 || throw(ArgumentError(
        "quasineutrality tolerance must be positive and finite"))
    contract = only(filter(item -> item.operator_id == "ambipolar_response_v2", registry))
    perturbation = StabilityPerturbationSpecV2("multispecies_ambipolar_root_v2",
        contract.operator_id;
        equations = ["sum_s Z_s n_s(ePhi) minus n_e(ePhi) equals zero"],
        state_input_ids = copy(contract.required_input_ids),
        boundary_conditions = ["candidate loss boundary from response problem"],
        time_semantics = :steady,
        resolution_levels = String[string(get(item, "resolution", index))
            for (index, item) in enumerate(convergence_history)],
        normalization = "relative quasineutrality residual")
    residual = observation.maximum_relative_quasineutrality_residual
    authorized = observation.c2_ambipolar_profile_authorized
    favorable = authorized ? true : observation.status == :fail ? false : nothing
    margin = residual === nothing ? nothing : 1.0 - Float64(residual) / tolerance
    binding_ok = candidate_binding_verified &&
        observation.genome_physics_hash == candidate_binding_hash
    return compile_stability_evidence_envelope_v2(candidate_binding_hash,
        observation.problem_hash, contract, perturbation; favorable = favorable,
        signed_normalized_margin = margin, convergence_history = convergence_history,
        validity_domain_covered = authorized, resolution_verified = authorized,
        covered_input_ids = copy(contract.required_input_ids), source_kind = :candidate_solver,
        source_artifact_paths = source_artifact_paths,
        source_artifact_hashes = source_artifact_hashes,
        source_result_hash = observation.observation_hash,
        candidate_binding_verified = binding_ok,
        claim_boundary = "Candidate-bound quasineutral ambipolar response only; not interchange, m=1, FLR, DCLC/AIC, flow-shear, end-loss, or complete stability.")
end

function _stage4_context_compatible_v2(contract::StabilityCapabilityContractV2,
        context::Dict{String,Any})
    dimension = String(get(context, "dimension", ""))
    boundary = String(get(context, "boundary_class", ""))
    time_mode = String(get(context, "time_mode", ""))
    return dimension in contract.supported_dimensions &&
        boundary in contract.supported_boundary_classes && time_mode in contract.supported_time_modes
end

function compile_stability_stage_v2(candidate_binding_hash::AbstractString,
        required_operator_ids::Vector{String}, context::Dict{String,Any},
        evidence::Vector{StabilityEvidenceEnvelopeV2} = StabilityEvidenceEnvelopeV2[];
        registry::Vector{StabilityCapabilityContractV2} = default_stability_capability_registry_v2())
    required = sort!(unique(copy(required_operator_ids)))
    isempty(required) && throw(ArgumentError("Stage-4 requires at least one operator"))
    contracts = Dict(item.operator_id => item for item in registry)
    length(contracts) == length(registry) || throw(ArgumentError("duplicate stability operator contract"))
    evidence_by_operator = Dict{String,StabilityEvidenceEnvelopeV2}()
    for item in evidence
        item.candidate_binding_hash == candidate_binding_hash || throw(ArgumentError(
            "stability evidence candidate binding mismatch"))
        haskey(evidence_by_operator, item.operator_id) && throw(ArgumentError(
            "duplicate stability evidence for $(item.operator_id)"))
        evidence_by_operator[item.operator_id] = item
    end
    unsupported = sort!(String[id for id in required if !haskey(contracts, id) ||
        !contracts[id].backend_available ||
        !_stage4_context_compatible_v2(contracts[id], context)])
    compatible = sort!(setdiff(required, unsupported))
    missing = sort!(String[id for id in compatible if !haskey(evidence_by_operator, id)])
    unknown = sort!(String[id for id in compatible if haskey(evidence_by_operator, id) &&
        evidence_by_operator[id].status == :unknown])
    passed = sort!(String[id for id in compatible if haskey(evidence_by_operator, id) &&
        evidence_by_operator[id].status == :pass])
    failed = sort!(String[id for id in required if haskey(evidence_by_operator, id) &&
        evidence_by_operator[id].status == :fail])
    auxiliary_failed = sort!(String[id for (id, item) in evidence_by_operator if
        !(id in required) && item.status == :fail])
    required_hard_failure = !isempty(failed)
    complete = isempty(unsupported) && isempty(missing) && isempty(unknown) &&
        length(passed) + length(failed) == length(required)
    support_authorized = complete && !required_hard_failure
    status = required_hard_failure ? :fail : !isempty(unsupported) ? :unsupported :
        support_authorized ? :pass : :unknown
    status in _STABILITY_STAGE_STATUSES_V2 || error("internal Stage-4 status error")
    tasks = String[]
    append!(tasks, ["provide_capability_or_repair_context:$id" for id in unsupported])
    append!(tasks, ["evaluate_stability_operator:$id" for id in missing])
    append!(tasks, ["complete_stability_evidence:$id" for id in unknown])
    for item in evidence
        append!(tasks, item.evidence_tasks)
    end
    warnings = [
        "stability operators are non-compensating; favorable evidence cannot offset fail or unknown",
        "an auxiliary failure preserves its minimal scope but cannot set the required Stage-4 conclusion or completion"]
    core = Dict{String,Any}(
        "schema_version" => "2.0.0", "candidate_binding_hash" => String(candidate_binding_hash),
        "registry_hash" => stability_capability_registry_hash_v2(registry),
        "required_operator_ids" => required, "context" => context,
        "compatible_operator_ids" => compatible, "unsupported_operator_ids" => unsupported,
        "missing_evidence_operator_ids" => missing, "unknown_operator_ids" => unknown,
        "passed_operator_ids" => passed, "failed_operator_ids" => failed,
        "auxiliary_failed_operator_ids" => auxiliary_failed, "stage_status" => String(status),
        "stage_complete" => complete,
        "c2_stability_support_authorized" => support_authorized,
        "authoritative_hard_failure" => required_hard_failure,
        "evidence_hashes" => sort!(getfield.(evidence, :evidence_hash)),
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return StabilityStageCompilationV2(String(candidate_binding_hash), required, compatible,
        unsupported, missing, unknown, passed, failed, auxiliary_failed, status, complete,
        support_authorized, required_hard_failure, sort!(unique(tasks)), warnings,
        sort!(copy(evidence); by = x -> x.operator_id), canonical_hash(core))
end

function stability_evidence_to_dict_v2(item::StabilityEvidenceEnvelopeV2)
    p = item.perturbation
    return Dict{String,Any}(
        "candidate_binding_hash" => item.candidate_binding_hash,
        "state_result_hash" => item.state_result_hash, "operator_id" => item.operator_id,
        "capability_id" => item.capability_id,
        "perturbation" => Dict("perturbation_id" => p.perturbation_id,
            "operator_id" => p.operator_id, "equations" => p.equations,
            "state_input_ids" => p.state_input_ids,
            "boundary_conditions" => p.boundary_conditions,
            "time_semantics" => String(p.time_semantics),
            "resolution_levels" => p.resolution_levels,
            "normalization" => p.normalization, "perturbation_hash" => p.perturbation_hash),
        "status" => String(item.status), "favorable" => item.favorable,
        "signed_normalized_margin" => item.signed_normalized_margin,
        "convergence_history" => item.convergence_history,
        "validity_domain_covered" => item.validity_domain_covered,
        "resolution_verified" => item.resolution_verified,
        "covered_input_ids" => item.covered_input_ids, "source_kind" => String(item.source_kind),
        "source_artifact_paths" => item.source_artifact_paths,
        "source_artifact_hashes" => item.source_artifact_hashes,
        "source_result_hash" => item.source_result_hash,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "evidence_authorized" => item.evidence_authorized,
        "minimal_failure_scope" => item.minimal_failure_scope,
        "claim_boundary" => item.claim_boundary, "evidence_tasks" => item.evidence_tasks,
        "evidence_hash" => item.evidence_hash)
end

function stability_stage_compilation_to_dict_v2(item::StabilityStageCompilationV2)
    return Dict{String,Any}(
        "candidate_binding_hash" => item.candidate_binding_hash,
        "required_operator_ids" => item.required_operator_ids,
        "compatible_operator_ids" => item.compatible_operator_ids,
        "unsupported_operator_ids" => item.unsupported_operator_ids,
        "missing_evidence_operator_ids" => item.missing_evidence_operator_ids,
        "unknown_operator_ids" => item.unknown_operator_ids,
        "passed_operator_ids" => item.passed_operator_ids,
        "failed_operator_ids" => item.failed_operator_ids,
        "auxiliary_failed_operator_ids" => item.auxiliary_failed_operator_ids,
        "stage_status" => String(item.stage_status), "stage_complete" => item.stage_complete,
        "c2_stability_support_authorized" => item.c2_stability_support_authorized,
        "authoritative_hard_failure" => item.authoritative_hard_failure,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "evidence" => stability_evidence_to_dict_v2.(item.evidence),
        "compilation_hash" => item.compilation_hash)
end

"Identifier-free view used to prove that routing depends only on capability declarations."
function stability_stage_structural_projection_v2(item::StabilityStageCompilationV2)
    return Dict{String,Any}(
        "required_operator_ids" => item.required_operator_ids,
        "compatible_operator_ids" => item.compatible_operator_ids,
        "unsupported_operator_ids" => item.unsupported_operator_ids,
        "missing_evidence_operator_ids" => item.missing_evidence_operator_ids,
        "unknown_operator_ids" => item.unknown_operator_ids,
        "passed_operator_ids" => item.passed_operator_ids,
        "failed_operator_ids" => item.failed_operator_ids,
        "auxiliary_failed_operator_ids" => item.auxiliary_failed_operator_ids,
        "stage_status" => String(item.stage_status), "stage_complete" => item.stage_complete)
end
