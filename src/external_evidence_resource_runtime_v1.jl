const _EERR_V1_HASH_RE = r"^[0-9a-f]{64}$"

"Candidate-bound, family-neutral resource obligations for external recomputation and validation."
struct ExternalResourceRequirementManifestV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    solve_manifest_hash::String
    requirements::Vector{Dict{String,Any}}
    candidate_input_blockers::Vector{String}
    status::Symbol
    claim_boundary::String
    requirement_hash::String
end

"A provider declaration whose eligibility is determined only by explicit capabilities and artifacts."
struct EvidenceProviderManifestV1
    schema_version::String
    provider_id::String
    resource_class::String
    provides_capabilities::Vector{String}
    provides_outputs::Vector{String}
    spatial_representations::Vector{String}
    time_modes::Vector{String}
    region_kinds::Vector{String}
    validity_domain::Dict{String,Any}
    artifact_hashes::Dict{String,Any}
    access_state::String
    independence_group::String
    authority::String
    status::Symbol
    unresolved_reasons::Vector{String}
    provider_hash::String
end

"Deterministic requires/provides matching result for one candidate."
struct ExternalResourceMatchEnvelopeV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    requirement_hash::String
    provider_catalog_hash::String
    requirement_matches::Vector{Dict{String,Any}}
    status::Symbol
    ready_requirement_count::Int
    total_requirement_count::Int
    unresolved_reasons::Vector{String}
    family_label_used::Bool
    evidence_ceiling::String
    match_hash::String
end

_eerr_v1_hash(value) = value isa AbstractString &&
    occursin(_EERR_V1_HASH_RE, String(value))
_eerr_v1_strings(values) = sort!(unique(String.(values)))

const _EERR_V1_CAPABILITY_OUTPUTS = Dict{String,Vector{String}}(
    "axisymmetric_mhd_equilibrium" => ["equilibrium_state", "magnetic_field", "flux_surfaces"],
    "three_dimensional_mhd_equilibrium" => ["equilibrium_state", "magnetic_field", "flux_surfaces"],
    "radiation_hydrodynamics" => ["state_trajectory", "shock_timing", "energy_balance"],
    "open_field_kinetic_transport" => ["distribution_function", "particle_flux", "energy_flux"],
    "state_derived_transport" => ["particle_flux", "energy_flux", "transport_coefficients"],
    "finite_conductor_electromagnetics" => ["magnetic_field", "current_density", "electromagnetic_loss"],
    "fusion_reaction_radiation" => ["reaction_rate", "radiation_loss", "reaction_power"],
    "closed_field_control_volume" => ["state_trajectory", "conservation_slots"],
    "open_field_control_volume" => ["state_trajectory", "boundary_flux", "conservation_slots"])

function _eerr_v1_spatial_representation(manifest::CandidateSolveManifestV1)
    capabilities = Set(String(item["capability_id"]) for item in
        manifest.capability_declarations)
    geometries = lowercase.(String[get(region, "geometry_model", "")
        for region in manifest.regions])
    any(value -> occursin("spherical", value), geometries) && return "spherical_radial"
    "three_dimensional_mhd_equilibrium" in capabilities && return "three_dimensional"
    "axisymmetric_mhd_equilibrium" in capabilities && return "axisymmetric"
    return "declared_region_network"
end

function _eerr_v1_requirement(id, resource_class, capabilities, outputs, spatial,
        time_mode, region_kinds, minimum_providers, independence_required, details)
    body = Dict{String,Any}(
        "requirement_id" => String(id), "resource_class" => String(resource_class),
        "requires_capabilities" => _eerr_v1_strings(capabilities),
        "requires_outputs" => _eerr_v1_strings(outputs),
        "spatial_representation" => String(spatial),
        "time_mode" => String(time_mode), "region_kinds" => _eerr_v1_strings(region_kinds),
        "minimum_provider_count" => Int(minimum_providers),
        "independent_provider_groups_required" => independence_required === true,
        "validity_requirements" => Dict{String,Any}(String(key) => value
            for (key, value) in details), "family_label_used" => false)
    body["requirement_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

function compile_external_resource_requirements_v1(
        manifest::CandidateSolveManifestV1; pulsed_rhd_manifest = nothing,
        candidate_input_blockers = String[])
    capability_ids = _eerr_v1_strings(String(item["capability_id"])
        for item in manifest.capability_declarations)
    solver_capabilities = [id for id in capability_ids if
        !startswith(id, "conserved_") && haskey(_EERR_V1_CAPABILITY_OUTPUTS, id)]
    spatial = _eerr_v1_spatial_representation(manifest)
    region_kinds = _eerr_v1_strings(get(region, "kind", "") for region in manifest.regions)
    requirements = Dict{String,Any}[]
    for capability in solver_capabilities
        push!(requirements, _eerr_v1_requirement(
            "independent_numerical_replication:$capability", "numerical_backend",
            [capability], _EERR_V1_CAPABILITY_OUTPUTS[capability], spatial,
            manifest.time_mode, region_kinds, 2, true,
            Dict("same_candidate_physics_hash" => manifest.physics_hash,
                "same_solve_manifest_hash" => manifest.manifest_hash,
                "independently_generated_meshes" => true,
                "observable_tolerances_required" => true)))
    end
    if "radiation_hydrodynamics" in capability_ids
        target_layers = pulsed_rhd_manifest isa AbstractDict ?
            get(pulsed_rhd_manifest, "target_layers", Any[]) : Any[]
        materials = _eerr_v1_strings(get(layer, "material_id", "unresolved_material_scope")
            for layer in target_layers)
        isempty(materials) && (materials = ["unresolved_material_scope"])
        for role in ("equation_of_state", "multigroup_opacity")
            push!(requirements, _eerr_v1_requirement("material_data:$role",
                "material_data", [role], [role], spatial, manifest.time_mode,
                region_kinds, 1, false, Dict("material_ids" => materials,
                    "version_and_byte_hash_required" => true,
                    "validity_domain_and_uncertainty_required" => true)))
        end
    end
    observable_outputs = _eerr_v1_strings(vcat(manifest.required_outputs,
        reduce(vcat, [_EERR_V1_CAPABILITY_OUTPUTS[id] for id in solver_capabilities];
            init = String[])))
    push!(requirements, _eerr_v1_requirement("calibrated_experimental_anchor",
        "experimental_dataset", ["calibrated_observables"], observable_outputs,
        spatial, manifest.time_mode, region_kinds, 1, false,
        Dict("raw_data_hash_required" => true, "calibration_hash_required" => true,
            "transfer_function_hash_required" => true,
            "uncertainty_covariance_hash_required" => true,
            "boundary_initial_control_histories_required" => true)))
    blockers = _eerr_v1_strings(candidate_input_blockers)
    status = isempty(requirements) ? :not_applicable :
        isempty(blockers) ? :requirements_complete : :unknown_candidate_input_incomplete
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => manifest.candidate_id, "physics_hash" => manifest.physics_hash,
        "solve_manifest_hash" => manifest.manifest_hash, "requirements" => requirements,
        "candidate_input_blockers" => blockers, "status" => String(status),
        "claim_boundary" => "Resource requirements authorize no external result or validation claim.")
    hash = canonical_hash(_csr_v1_json_safe(body))
    return ExternalResourceRequirementManifestV1("1.0.0", manifest.candidate_id,
        manifest.physics_hash, manifest.manifest_hash, requirements, blockers, status,
        body["claim_boundary"], hash)
end

function _eerr_v1_required_artifact_keys(resource_class)
    resource_class == "numerical_backend" && return ["software_hash", "container_hash"]
    resource_class == "material_data" && return ["data_hash"]
    resource_class == "experimental_dataset" && return ["raw_data_hash",
        "calibration_hash", "transfer_function_hash", "uncertainty_covariance_hash"]
    return ["artifact_hash"]
end

function compile_evidence_provider_manifest_v1(raw)
    record = raw isa AbstractDict ? Dict{String,Any}(String(key) => value
        for (key, value) in raw) : Dict{String,Any}()
    reasons = String[]
    provider_id = String(get(record, "provider_id", ""));
    isempty(provider_id) && push!(reasons, "missing provider_id")
    resource_class = String(get(record, "resource_class", ""))
    resource_class in ("numerical_backend", "material_data", "experimental_dataset") ||
        push!(reasons, "unsupported resource_class")
    capabilities = _eerr_v1_strings(get(record, "provides_capabilities", String[]))
    isempty(capabilities) && push!(reasons, "no provided capabilities")
    outputs = _eerr_v1_strings(get(record, "provides_outputs", String[]))
    isempty(outputs) && push!(reasons, "no provided outputs")
    spatial = _eerr_v1_strings(get(record, "spatial_representations", String[]))
    isempty(spatial) && push!(reasons, "no spatial representations")
    time_modes = _eerr_v1_strings(get(record, "time_modes", String[]))
    isempty(time_modes) && push!(reasons, "no time modes")
    regions = _eerr_v1_strings(get(record, "region_kinds", ["*"]))
    validity = get(record, "validity_domain", Dict{String,Any}())
    validity = validity isa AbstractDict ? Dict{String,Any}(String(key) => value
        for (key, value) in validity) : Dict{String,Any}()
    artifacts = get(record, "artifact_hashes", Dict{String,Any}())
    artifacts = artifacts isa AbstractDict ? Dict{String,Any}(String(key) => value
        for (key, value) in artifacts) : Dict{String,Any}()
    access = String(get(record, "access_state", "not_acquired"))
    group = String(get(record, "independence_group", ""))
    isempty(group) && push!(reasons, "missing independence_group")
    authority = String(get(record, "authority", ""))
    isempty(authority) && push!(reasons, "missing authority")
    acquired = access == "acquired"
    if acquired
        for key in _eerr_v1_required_artifact_keys(resource_class)
            _eerr_v1_hash(get(artifacts, key, nothing)) ||
                push!(reasons, "acquired provider lacks valid $key")
        end
        isempty(validity) && push!(reasons, "acquired provider lacks validity_domain")
    end
    status = !isempty(reasons) ? :unsupported : acquired ? :available : :declared_unacquired
    body = Dict{String,Any}("schema_version" => "1.0.0", "provider_id" => provider_id,
        "resource_class" => resource_class, "provides_capabilities" => capabilities,
        "provides_outputs" => outputs, "spatial_representations" => spatial,
        "time_modes" => time_modes, "region_kinds" => regions,
        "validity_domain" => validity, "artifact_hashes" => artifacts,
        "access_state" => access, "independence_group" => group,
        "authority" => authority, "status" => String(status),
        "unresolved_reasons" => sort!(unique(reasons)))
    hash = canonical_hash(_csr_v1_json_safe(body))
    return EvidenceProviderManifestV1("1.0.0", provider_id, resource_class,
        capabilities, outputs, spatial, time_modes, regions, validity, artifacts,
        access, group, authority, status, body["unresolved_reasons"], hash)
end

function evidence_provider_to_dict_v1(value::EvidenceProviderManifestV1)
    return Dict{String,Any}("schema_version" => value.schema_version,
        "provider_id" => value.provider_id, "resource_class" => value.resource_class,
        "provides_capabilities" => value.provides_capabilities,
        "provides_outputs" => value.provides_outputs,
        "spatial_representations" => value.spatial_representations,
        "time_modes" => value.time_modes, "region_kinds" => value.region_kinds,
        "validity_domain" => value.validity_domain,
        "artifact_hashes" => value.artifact_hashes, "access_state" => value.access_state,
        "independence_group" => value.independence_group, "authority" => value.authority,
        "status" => String(value.status), "unresolved_reasons" => value.unresolved_reasons,
        "provider_hash" => value.provider_hash)
end

function _eerr_v1_set_supported(required, provided)
    "*" in provided || Set(required) <= Set(provided)
end

function _eerr_v1_declared_match(requirement, provider::EvidenceProviderManifestV1)
    provider.resource_class == String(requirement["resource_class"]) || return false
    _eerr_v1_set_supported(requirement["requires_capabilities"],
        provider.provides_capabilities) || return false
    _eerr_v1_set_supported(requirement["requires_outputs"], provider.provides_outputs) ||
        return false
    ("*" in provider.spatial_representations ||
        String(requirement["spatial_representation"]) in provider.spatial_representations) ||
        return false
    ("*" in provider.time_modes || String(requirement["time_mode"]) in
        provider.time_modes) || return false
    _eerr_v1_set_supported(requirement["region_kinds"], provider.region_kinds) ||
        return false
    return true
end

function match_external_resources_v1(requirements::ExternalResourceRequirementManifestV1,
        raw_providers)
    providers = EvidenceProviderManifestV1[raw isa EvidenceProviderManifestV1 ? raw :
        compile_evidence_provider_manifest_v1(raw) for raw in raw_providers]
    provider_dicts = [evidence_provider_to_dict_v1(item) for item in providers]
    catalog_hash = canonical_hash(_csr_v1_json_safe(provider_dicts))
    matches = Dict{String,Any}[]; unresolved = String[]; ready_count = 0
    for requirement in requirements.requirements
        declared = [item for item in providers if _eerr_v1_declared_match(requirement, item)]
        available = [item for item in declared if item.status == :available]
        minimum = Int(requirement["minimum_provider_count"])
        groups = unique(item.independence_group for item in available)
        independent = requirement["independent_provider_groups_required"] !== true ||
            length(groups) >= minimum
        ready = length(available) >= minimum && independent
        status = ready ? "ready" : isempty(declared) ? "unsupported_no_capability_match" :
            "unknown_acquisition_or_artifact_required"
        ready_count += ready ? 1 : 0
        ready || push!(unresolved, "$(requirement["requirement_id"]):$status")
        record = Dict{String,Any}(
            "requirement_id" => requirement["requirement_id"],
            "requirement_hash" => requirement["requirement_hash"], "status" => status,
            "minimum_provider_count" => minimum,
            "declared_matching_provider_ids" => sort!(String[item.provider_id for item in declared]),
            "available_provider_ids" => sort!(String[item.provider_id for item in available]),
            "available_independence_groups" => sort!(String.(groups)),
            "family_label_used" => false)
        record["match_record_hash"] = canonical_hash(_csr_v1_json_safe(record))
        push!(matches, record)
    end
    total = length(matches)
    status = requirements.status == :not_applicable ? :not_applicable :
        !isempty(requirements.candidate_input_blockers) ? :unknown_candidate_input_incomplete :
        ready_count == total ? :ready_for_external_execution :
        any(item -> item["status"] == "unsupported_no_capability_match", matches) ?
            :unsupported_provider_capability_gap : :unknown_acquisition_required
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => requirements.candidate_id,
        "physics_hash" => requirements.physics_hash,
        "requirement_hash" => requirements.requirement_hash,
        "provider_catalog_hash" => catalog_hash, "requirement_matches" => matches,
        "status" => String(status), "ready_requirement_count" => ready_count,
        "total_requirement_count" => total,
        "unresolved_reasons" => sort!(unique(vcat(unresolved,
            requirements.candidate_input_blockers))), "family_label_used" => false,
        "evidence_ceiling" => status == :ready_for_external_execution ?
            "provider acquisition and capability matching only; no numerical or experimental result" :
            "explicit provider, access, artifact or candidate-input gaps only")
    hash = canonical_hash(_csr_v1_json_safe(body))
    return ExternalResourceMatchEnvelopeV1("1.0.0", requirements.candidate_id,
        requirements.physics_hash, requirements.requirement_hash, catalog_hash, matches,
        status, ready_count, total, body["unresolved_reasons"], false,
        body["evidence_ceiling"], hash)
end

function external_resource_requirements_to_dict_v1(value::ExternalResourceRequirementManifestV1)
    return Dict{String,Any}("schema_version" => value.schema_version,
        "candidate_id" => value.candidate_id, "physics_hash" => value.physics_hash,
        "solve_manifest_hash" => value.solve_manifest_hash,
        "requirements" => value.requirements,
        "candidate_input_blockers" => value.candidate_input_blockers,
        "status" => String(value.status), "claim_boundary" => value.claim_boundary,
        "requirement_hash" => value.requirement_hash)
end

function external_resource_match_to_dict_v1(value::ExternalResourceMatchEnvelopeV1)
    return Dict{String,Any}("schema_version" => value.schema_version,
        "candidate_id" => value.candidate_id, "physics_hash" => value.physics_hash,
        "requirement_hash" => value.requirement_hash,
        "provider_catalog_hash" => value.provider_catalog_hash,
        "requirement_matches" => value.requirement_matches, "status" => String(value.status),
        "ready_requirement_count" => value.ready_requirement_count,
        "total_requirement_count" => value.total_requirement_count,
        "unresolved_reasons" => value.unresolved_reasons,
        "family_label_used" => value.family_label_used,
        "evidence_ceiling" => value.evidence_ceiling, "match_hash" => value.match_hash)
end

function default_external_evidence_provider_catalog_v1()
    common = Dict("artifact_hashes" => Dict{String,Any}(),
        "validity_domain" => Dict("status" => "requires_provider_confirmation"),
        "access_state" => "not_acquired", "authority" => "external_provider")
    raws = [
        merge(deepcopy(common), Dict("provider_id" => "flash_4_8",
            "resource_class" => "numerical_backend",
            "provides_capabilities" => ["radiation_hydrodynamics"],
            "provides_outputs" => ["state_trajectory", "shock_timing", "energy_balance"],
            "spatial_representations" => ["spherical_radial", "axisymmetric", "three_dimensional"],
            "time_modes" => ["pulsed", "transient"], "region_kinds" => ["*"],
            "independence_group" => "flash_center")),
        merge(deepcopy(common), Dict("provider_id" => "multi_abbv_v1_0",
            "resource_class" => "numerical_backend",
            "provides_capabilities" => ["radiation_hydrodynamics"],
            "provides_outputs" => ["state_trajectory", "shock_timing", "energy_balance"],
            "spatial_representations" => ["one_dimensional_planar"],
            "time_modes" => ["pulsed", "transient"], "region_kinds" => ["*"],
            "independence_group" => "multi_cpc")),
        merge(deepcopy(common), Dict("provider_id" => "fpeos_2025_10_26",
            "resource_class" => "material_data",
            "provides_capabilities" => ["equation_of_state"],
            "provides_outputs" => ["equation_of_state"],
            "spatial_representations" => ["*"], "time_modes" => ["*"],
            "region_kinds" => ["*"], "independence_group" => "fpeos")),
        merge(deepcopy(common), Dict("provider_id" => "lanl_oplib_tops",
            "resource_class" => "material_data",
            "provides_capabilities" => ["multigroup_opacity"],
            "provides_outputs" => ["multigroup_opacity"],
            "spatial_representations" => ["*"], "time_modes" => ["*"],
            "region_kinds" => ["*"], "independence_group" => "lanl_oplib")),
        merge(deepcopy(common), Dict("provider_id" => "nif_archive",
            "resource_class" => "experimental_dataset",
            "provides_capabilities" => ["calibrated_observables"],
            "provides_outputs" => ["*"], "spatial_representations" => ["*"],
            "time_modes" => ["pulsed"], "region_kinds" => ["*"],
            "independence_group" => "nif_archive")),
        merge(deepcopy(common), Dict("provider_id" => "omega_archive",
            "resource_class" => "experimental_dataset",
            "provides_capabilities" => ["calibrated_observables"],
            "provides_outputs" => ["*"], "spatial_representations" => ["*"],
            "time_modes" => ["pulsed", "transient"], "region_kinds" => ["*"],
            "independence_group" => "omega_archive"))]
    return EvidenceProviderManifestV1[compile_evidence_provider_manifest_v1(raw)
        for raw in raws]
end
