const _EXTERNAL_KINETIC_RUN_STATUSES_V1 = Set((:pass, :fail, :unknown, :error))

"A topology-capability contract for a kinetic solver reached through a process boundary."
struct ExternalKineticBackendContractV1
    backend_id::String
    backend_version::String
    source_commit::String
    source_tree_hash::String
    phase_space_coordinates::Vector{String}
    required_input_channels::Vector{String}
    available_output_channels::Vector{String}
    topology_capabilities::Vector{String}
    build_regression_verified::Bool
    exact_published_variant_verified::Bool
    process_boundary_required::Bool
    promotion_authority::Bool
end

function ExternalKineticBackendContractV1(; backend_id::AbstractString,
        backend_version::AbstractString, source_commit::AbstractString,
        source_tree_hash::AbstractString, phase_space_coordinates,
        required_input_channels, available_output_channels,
        topology_capabilities, build_regression_verified::Bool,
        exact_published_variant_verified::Bool = false,
        process_boundary_required::Bool = true,
        promotion_authority::Bool = false)
    isempty(strip(String(backend_id))) && throw(ArgumentError("backend_id is required"))
    isempty(strip(String(backend_version))) && throw(ArgumentError("backend_version is required"))
    commit = lowercase(String(source_commit))
    tree = lowercase(String(source_tree_hash))
    length(commit) == 40 && all(isxdigit, commit) || throw(ArgumentError(
        "source_commit must contain 40 hexadecimal characters"))
    length(tree) == 40 && all(isxdigit, tree) || throw(ArgumentError(
        "source_tree_hash must contain 40 hexadecimal characters"))
    coordinates = sort!(unique(String.(collect(phase_space_coordinates))))
    inputs = sort!(unique(String.(collect(required_input_channels))))
    outputs = sort!(unique(String.(collect(available_output_channels))))
    capabilities = sort!(unique(String.(collect(topology_capabilities))))
    isempty(coordinates) && throw(ArgumentError("phase_space_coordinates are required"))
    isempty(inputs) && throw(ArgumentError("required_input_channels are required"))
    isempty(outputs) && throw(ArgumentError("available_output_channels are required"))
    isempty(capabilities) && throw(ArgumentError("topology_capabilities are required"))
    promotion_authority && throw(ArgumentError(
        "external kinetic backend contracts cannot grant promotion authority"))
    return ExternalKineticBackendContractV1(String(backend_id),
        String(backend_version), commit, tree, coordinates, inputs, outputs,
        capabilities, build_regression_verified, exact_published_variant_verified,
        process_boundary_required, false)
end

"Fail-closed C2 assessment of one exact candidate run against one backend contract."
struct ExternalKineticBackendAssessmentV1
    design_id::String
    genome_physics_hash::String
    executable_candidate_physics_hash::String
    backend_id::String
    backend_version::String
    gates::Dict{String,Bool}
    c2_phase_space_source_authorized::Bool
    c2_kinetic_state_authorized::Bool
    c2_ambipolar_response_authorized::Bool
    c2_end_loss_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    claim_ceiling::String
    assessment_hash::String
end

function _external_kinetic_hash_v1(value, name::String; allow_empty::Bool = false)
    text = lowercase(String(value))
    allow_empty && isempty(text) && return text
    length(text) == 64 && all(isxdigit, text) || throw(ArgumentError(
        "$name must contain 64 hexadecimal characters"))
    return text
end

function external_kinetic_backend_contract_to_dict_v1(
        contract::ExternalKineticBackendContractV1)
    return Dict{String,Any}(
        "backend_id" => contract.backend_id,
        "backend_version" => contract.backend_version,
        "source_commit" => contract.source_commit,
        "source_tree_hash" => contract.source_tree_hash,
        "phase_space_coordinates" => contract.phase_space_coordinates,
        "required_input_channels" => contract.required_input_channels,
        "available_output_channels" => contract.available_output_channels,
        "topology_capabilities" => contract.topology_capabilities,
        "build_regression_verified" => contract.build_regression_verified,
        "exact_published_variant_verified" => contract.exact_published_variant_verified,
        "process_boundary_required" => contract.process_boundary_required,
        "promotion_authority" => false)
end

function compile_external_kinetic_backend_assessment_v1(
        contract::ExternalKineticBackendContractV1;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        executable_candidate_physics_hash::AbstractString,
        input_artifact_hash::AbstractString = "",
        equilibrium_artifact_hash::AbstractString = "",
        source_artifact_hash::AbstractString = "",
        output_artifact_hash::AbstractString = "",
        source_result_status::Symbol = :unknown,
        process_exit_success::Bool = false,
        normal_completion_marker_verified::Bool = false,
        candidate_input_compiled::Bool = false,
        candidate_equilibrium_binding_verified::Bool = false,
        candidate_source_binding_verified::Bool = false,
        candidate_topology_applicability_verified::Bool = false,
        solver_completed::Bool = false,
        physical_distribution_normalization_verified::Bool = false,
        particle_conservation_verified::Bool = false,
        energy_conservation_verified::Bool = false,
        resolution_convergence_verified::Bool = false,
        known_topology_control_verified::Bool = false,
        ambipolar_response_verified::Bool = false,
        end_loss_flux_verified::Bool = false)
    source_result_status in _EXTERNAL_KINETIC_RUN_STATUSES_V1 || throw(ArgumentError(
        "source_result_status must be pass, fail, unknown, or error"))
    design = String(design_id)
    isempty(strip(design)) && throw(ArgumentError("design_id is required"))
    genome_hash = _external_kinetic_hash_v1(genome_physics_hash,
        "genome_physics_hash")
    candidate_hash = _external_kinetic_hash_v1(executable_candidate_physics_hash,
        "executable_candidate_physics_hash")
    input_hash = _external_kinetic_hash_v1(input_artifact_hash,
        "input_artifact_hash"; allow_empty = true)
    equilibrium_hash = _external_kinetic_hash_v1(equilibrium_artifact_hash,
        "equilibrium_artifact_hash"; allow_empty = true)
    source_hash = _external_kinetic_hash_v1(source_artifact_hash,
        "source_artifact_hash"; allow_empty = true)
    output_hash = _external_kinetic_hash_v1(output_artifact_hash,
        "output_artifact_hash"; allow_empty = true)

    gates = Dict{String,Bool}(
        "backend_build_regression" => contract.build_regression_verified,
        "candidate_input_artifact" => candidate_input_compiled && !isempty(input_hash),
        "candidate_equilibrium_binding" =>
            candidate_equilibrium_binding_verified && !isempty(equilibrium_hash),
        "candidate_phase_space_source_binding" =>
            candidate_source_binding_verified && source_result_status == :pass &&
            !isempty(source_hash),
        "candidate_topology_applicability" => candidate_topology_applicability_verified,
        "solver_process_completion" => solver_completed && process_exit_success &&
            normal_completion_marker_verified && !isempty(output_hash),
        "physical_distribution_normalization" =>
            physical_distribution_normalization_verified,
        "particle_conservation" => particle_conservation_verified,
        "energy_conservation" => energy_conservation_verified,
        "resolution_convergence" => resolution_convergence_verified,
        "known_topology_control" => known_topology_control_verified,
        "ambipolar_response" => ambipolar_response_verified,
        "end_loss_flux" => end_loss_flux_verified)

    source_authorized = all(gates[id] for id in (
        "backend_build_regression", "candidate_input_artifact",
        "candidate_equilibrium_binding", "candidate_phase_space_source_binding",
        "candidate_topology_applicability"))
    kinetic_authorized = source_authorized && all(gates[id] for id in (
        "solver_process_completion", "physical_distribution_normalization",
        "particle_conservation", "energy_conservation", "resolution_convergence",
        "known_topology_control"))
    ambipolar_authorized = kinetic_authorized && gates["ambipolar_response"]
    end_loss_authorized = kinetic_authorized && gates["end_loss_flux"]

    tasks = String[]
    task_for_gate = Dict(
        "backend_build_regression" => "pass_pinned_backend_build_and_upstream_regression",
        "candidate_input_artifact" => "compile_exact_candidate_backend_input",
        "candidate_equilibrium_binding" => "bind_exact_candidate_equilibrium",
        "candidate_phase_space_source_binding" => "bind_signed_physical_phase_space_source",
        "candidate_topology_applicability" => "verify_backend_applicability_to_candidate_topology",
        "solver_process_completion" => "obtain_hash_bound_normal_candidate_solver_completion",
        "physical_distribution_normalization" => "verify_physical_distribution_normalization",
        "particle_conservation" => "close_species_particle_ledger",
        "energy_conservation" => "close_species_energy_ledger",
        "resolution_convergence" => "run_two_resolution_candidate_convergence",
        "known_topology_control" => "pass_known_topology_control",
        "ambipolar_response" => "verify_self_consistent_ambipolar_response",
        "end_loss_flux" => "verify_species_resolved_end_loss_flux")
    for id in sort!(collect(keys(gates)))
        gates[id] || push!(tasks, task_for_gate[id])
    end
    warnings = String[]
    contract.exact_published_variant_verified || push!(warnings,
        "Exact equivalence to the published solver variant is not established.")
    kinetic_authorized || push!(warnings,
        "Unknown or failed gates remain non-compensable; no C2 kinetic state is authorized.")
    claim_ceiling = kinetic_authorized ? "C2_candidate_specific_kinetic_state" :
        contract.build_regression_verified ? "backend_build_regression_only" :
        "backend_interface_contract_only"
    payload = Dict{String,Any}(
        "contract" => external_kinetic_backend_contract_to_dict_v1(contract),
        "design_id" => design, "genome_physics_hash" => genome_hash,
        "executable_candidate_physics_hash" => candidate_hash,
        "input_artifact_hash" => input_hash,
        "equilibrium_artifact_hash" => equilibrium_hash,
        "source_artifact_hash" => source_hash, "output_artifact_hash" => output_hash,
        "source_result_status" => String(source_result_status), "gates" => gates,
        "c2_phase_space_source_authorized" => source_authorized,
        "c2_kinetic_state_authorized" => kinetic_authorized,
        "c2_ambipolar_response_authorized" => ambipolar_authorized,
        "c2_end_loss_authorized" => end_loss_authorized,
        "evidence_tasks" => tasks, "claim_ceiling" => claim_ceiling)
    return ExternalKineticBackendAssessmentV1(design, genome_hash, candidate_hash,
        contract.backend_id, contract.backend_version, gates, source_authorized,
        kinetic_authorized, ambipolar_authorized, end_loss_authorized, tasks,
        warnings, claim_ceiling, canonical_hash(payload))
end

function external_kinetic_backend_assessment_to_dict_v1(
        item::ExternalKineticBackendAssessmentV1)
    return Dict{String,Any}(
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "executable_candidate_physics_hash" => item.executable_candidate_physics_hash,
        "backend_id" => item.backend_id, "backend_version" => item.backend_version,
        "gates" => item.gates,
        "c2_phase_space_source_authorized" => item.c2_phase_space_source_authorized,
        "c2_kinetic_state_authorized" => item.c2_kinetic_state_authorized,
        "c2_ambipolar_response_authorized" => item.c2_ambipolar_response_authorized,
        "c2_end_loss_authorized" => item.c2_end_loss_authorized,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "claim_ceiling" => item.claim_ceiling, "assessment_hash" => item.assessment_hash,
        "promotion_authorized" => false)
end
