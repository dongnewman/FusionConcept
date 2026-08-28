const OPERATOR_CAPABILITY_ROUTER_V89_CLAIM_BOUNDARY =
    "Routing is determined only by operators, states, dimensions, boundaries, time semantics, validity domains, outputs, and evidence obligations. A route match proves executability of the declared reduced operator, not device-family feasibility."

struct SolverCapabilityManifestV89
    schema_version::String
    manifest_id::String
    operator_ids::Vector{String}
    state_variables::Vector{String}
    spatial_dimensions::Vector{String}
    boundary_kinds::Vector{String}
    time_semantics::Vector{String}
    validity_domain::Dict{String,Any}
    supported_observables::Vector{String}
    numerical_tolerances::Dict{String,Float64}
    software_hash::String
    container_hash::String
    mesh_hash::String
    independence_group::String
    manifest_hash::String
end

function compile_solver_capability_manifest_v89(; manifest_id, operator_ids,
        state_variables, spatial_dimensions, boundary_kinds, time_semantics,
        validity_domain, supported_observables, numerical_tolerances,
        software_hash, container_hash, mesh_hash, independence_group)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "manifest_id" => String(manifest_id),
        "operator_ids" => sort!(unique(String.(operator_ids))),
        "state_variables" => sort!(unique(String.(state_variables))),
        "spatial_dimensions" => sort!(unique(String.(spatial_dimensions))),
        "boundary_kinds" => sort!(unique(String.(boundary_kinds))),
        "time_semantics" => sort!(unique(String.(time_semantics))),
        "validity_domain" => _v89_plain(validity_domain),
        "supported_observables" => sort!(unique(String.(supported_observables))),
        "numerical_tolerances" => Dict{String,Float64}(String(key) => Float64(value)
            for (key, value) in pairs(numerical_tolerances)),
        "software_hash" => String(software_hash),
        "container_hash" => String(container_hash), "mesh_hash" => String(mesh_hash),
        "independence_group" => String(independence_group))
    _v89_assert_scientific_payload_label_free(body, "solver_manifest")
    isempty(body["operator_ids"]) && throw(ArgumentError(
        "solver capability manifest requires at least one operator"))
    isempty(body["spatial_dimensions"]) && throw(ArgumentError(
        "solver capability manifest requires spatial dimensions"))
    hash = canonical_hash(body)
    SolverCapabilityManifestV89("1.0.0", body["manifest_id"], body["operator_ids"],
        body["state_variables"], body["spatial_dimensions"], body["boundary_kinds"],
        body["time_semantics"], Dict{String,Any}(body["validity_domain"]),
        body["supported_observables"], body["numerical_tolerances"],
        body["software_hash"], body["container_hash"], body["mesh_hash"],
        body["independence_group"], hash)
end

function solver_capability_manifest_to_dict_v89(item::SolverCapabilityManifestV89)
    Dict{String,Any}(
        "schema_version" => item.schema_version, "manifest_id" => item.manifest_id,
        "operator_ids" => item.operator_ids, "state_variables" => item.state_variables,
        "spatial_dimensions" => item.spatial_dimensions,
        "boundary_kinds" => item.boundary_kinds,
        "time_semantics" => item.time_semantics,
        "validity_domain" => item.validity_domain,
        "supported_observables" => item.supported_observables,
        "numerical_tolerances" => item.numerical_tolerances,
        "software_hash" => item.software_hash, "container_hash" => item.container_hash,
        "mesh_hash" => item.mesh_hash, "independence_group" => item.independence_group,
        "manifest_hash" => item.manifest_hash)
end

function default_solver_capability_manifests_v89()
    definitions = [
        ("conservative_inventory_runtime_v89",
            ["control_volume_particle_inventory_v1", "control_volume_thermal_energy_v1"],
            ["particle_inventory", "thermal_energy"],
            ["particle_inventory", "thermal_energy", "interface_flux"]),
        ("fixed_current_flux_inventory_runtime_v89",
            ["fixed_current_flux_inventory_l1_v1"],
            ["plasma_current", "magnetic_flux"], ["magnetic_flux", "beta_proxy"]),
        ("closed_transport_reaction_runtime_v89",
            ["state_derived_bohm_transport_l1_v1",
                "state_derived_dt_reaction_bremsstrahlung_l1_v1"],
            ["particle_inventory", "thermal_energy"],
            ["fusion_power_w", "transport_loss_w", "radiation_loss_w"]),
        ("open_parallel_transport_runtime_v89",
            ["state_derived_parallel_streaming_l1_v1"],
            ["particle_inventory", "thermal_energy"],
            ["parallel_particle_loss_rate", "parallel_energy_loss_w"]),
        ("multiregion_coupling_control_runtime_v89",
            ["conservative_multiregion_interface_v89", "bounded_control_response_v89",
                "integrated_reduced_device_audit_v89"],
            ["particle_inventory", "thermal_energy", "plasma_current", "magnetic_flux"],
            ["coupled_residual_norm", "interface_conservation_error",
                "actuator_capacity_margin"])]
    manifests = SolverCapabilityManifestV89[]
    for (id, operators, states, observables) in definitions
        push!(manifests, compile_solver_capability_manifest_v89(
            manifest_id = id, operator_ids = operators, state_variables = states,
            spatial_dimensions = ["0d", "1d", "2d", "3d"],
            boundary_kinds = collect(V89_BOUNDARY_KINDS),
            time_semantics = collect(V89_TIME_SEMANTICS),
            validity_domain = Dict("minimum_volume_m3" => 1e-9,
                "minimum_magnetic_field_t" => 1e-9,
                "maximum_beta_proxy" => 1.0, "finite_inputs_required" => true),
            supported_observables = observables,
            numerical_tolerances = Dict("normalized_residual" => 1e-8,
                "interface_conservation" => 1e-12),
            software_hash = canonical_hash(Dict("runtime" => id, "version" => "v89")),
            container_hash = canonical_hash(Dict("environment" => "repository_julia_project")),
            mesh_hash = canonical_hash(Dict("mesh" => "multi_region_control_volume_v89")),
            independence_group = id))
    end
    manifests
end

function _v89_manifest_matches(obligation, manifest::SolverCapabilityManifestV89)
    operator = String(obligation["operator_id"])
    operator in manifest.operator_ids || return false, "operator_id"
    String(obligation["spatial_dimension"]) in manifest.spatial_dimensions ||
        return false, "spatial_dimension"
    String(obligation["time_semantics"]) in manifest.time_semantics ||
        return false, "time_semantics"
    isempty(setdiff(Set(String.(obligation["boundary_kinds"])),
        Set(manifest.boundary_kinds))) || return false, "boundary_kind"
    isempty(setdiff(Set(String.(obligation["required_state_ids"])),
        Set(manifest.state_variables))) || return false, "state_variables"
    true, "pass"
end

function route_operator_capabilities_v89(topology::UniversalMultiRegionTopologyV89;
        manifests = default_solver_capability_manifests_v89())
    bindings = Dict{String,Any}[]; missing = Dict{String,Any}[]
    for obligation in topology.operator_obligations
        matches = SolverCapabilityManifestV89[]
        mismatch_axes = String[]
        for manifest in manifests
            matched, axis = _v89_manifest_matches(obligation, manifest)
            matched ? push!(matches, manifest) : push!(mismatch_axes, axis)
        end
        if isempty(matches)
            push!(missing, Dict("obligation_id" => obligation["obligation_id"],
                "operator_id" => obligation["operator_id"],
                "status" => "unsupported", "reason" => "missing_operator_capability",
                "mismatch_axes" => sort!(unique(mismatch_axes))))
        else
            selected = first(sort!(matches; by = item -> item.manifest_hash))
            push!(bindings, Dict("obligation_id" => obligation["obligation_id"],
                "operator_id" => obligation["operator_id"],
                "manifest_id" => selected.manifest_id,
                "manifest_hash" => selected.manifest_hash,
                "independence_group" => selected.independence_group,
                "status" => "pass"))
        end
    end
    status = isempty(missing) ? "pass" : "unsupported"
    body = Dict{String,Any}(
        "topology_hash" => topology.topology_hash, "status" => status,
        "classification" => status == "pass" ? "all_operator_obligations_routed" :
            "missing_operator_capability", "bindings" => bindings,
        "missing" => missing, "family_routing_used" => false,
        "name_routing_used" => false, "benchmark_routing_used" => false)
    body["route_hash"] = canonical_hash(body)
    body["claim_boundary"] = OPERATOR_CAPABILITY_ROUTER_V89_CLAIM_BOUNDARY
    body
end
