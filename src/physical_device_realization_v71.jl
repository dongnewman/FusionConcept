const PHYSICAL_REALIZATION_V71_CLAIM_BOUNDARY =
    "A complete realization means that every declared graph port is bound to a candidate-specific geometric or hardware manifest. It does not by itself establish field quality, plasma confinement, fusion gain, engineering feasibility, manufacturability, or originality."

struct PhysicalComponentCapabilityV71
    realizer_id::String
    port_kind::String
    required_resource_ids::Vector{String}
    supported_symmetries::Vector{String}
    component_kind::String
end

struct PhysicalComponentRegistryV71
    schema_version::String
    capabilities::Vector{PhysicalComponentCapabilityV71}
    registry_hash::String
end

struct PhysicalDeviceRealizationV71
    schema_version::String
    topology_hash::String
    compilation_hash::String
    candidate_binding_hash::String
    registry_hash::String
    completeness::Symbol
    conclusion::Symbol
    classification_code::String
    geometry::Dict{String,Any}
    components::Vector{Dict{String,Any}}
    port_mappings::Vector{Dict{String,Any}}
    dependency_mappings::Vector{Dict{String,Any}}
    missing_requirements::Vector{String}
    claim_boundary::String
    realization_hash::String
end

_v71_plain(value) = value isa AbstractDict ? Dict{String,Any}(String(key) =>
    _v71_plain(child) for (key, child) in pairs(value)) :
    value isa AbstractVector ? Any[_v71_plain(child) for child in value] :
    value isa Tuple ? Any[_v71_plain(child) for child in value] : value

function _v71_capability_to_dict(item::PhysicalComponentCapabilityV71)
    return Dict{String,Any}(
        "realizer_id" => item.realizer_id,
        "port_kind" => item.port_kind,
        "required_resource_ids" => item.required_resource_ids,
        "supported_symmetries" => item.supported_symmetries,
        "component_kind" => item.component_kind)
end

function compile_physical_component_registry_v71(capabilities)
    normalized = PhysicalComponentCapabilityV71[]
    for raw in capabilities
        item = raw isa PhysicalComponentCapabilityV71 ? raw :
            PhysicalComponentCapabilityV71(String(raw["realizer_id"]),
                String(raw["port_kind"]), sort!(unique(String.(raw["required_resource_ids"]))),
                sort!(unique(String.(raw["supported_symmetries"]))),
                String(raw["component_kind"]))
        item.port_kind in String.(collect(GRAPH_V69_PORT_KINDS)) ||
            throw(ArgumentError("unsupported realization port kind $(item.port_kind)"))
        isempty(item.realizer_id) && throw(ArgumentError("realizer_id is required"))
        isempty(item.component_kind) && throw(ArgumentError("component_kind is required"))
        push!(normalized, item)
    end
    sort!(normalized; by = item -> (item.port_kind, item.realizer_id))
    length(unique(item.realizer_id for item in normalized)) == length(normalized) ||
        throw(ArgumentError("physical realizer ids must be unique"))
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "capabilities" => _v71_capability_to_dict.(normalized))
    return PhysicalComponentRegistryV71("1.0.0", normalized, canonical_hash(body))
end

function default_physical_component_registry_v71()
    all_symmetries = ["none", "reflection", "rotational", "helical"]
    return compile_physical_component_registry_v71([
        PhysicalComponentCapabilityV71("particle_flux_manifold_v1", "flux",
            ["particle"], all_symmetries, "fuel_exhaust_manifold_v1"),
        PhysicalComponentCapabilityV71("finite_filament_field_array_v1", "field_source",
            ["field_state"], all_symmetries, "finite_filament_coil_array_v1"),
        PhysicalComponentCapabilityV71("directed_energy_injector_v1", "energy_source",
            ["thermal_energy"], all_symmetries, "directed_particle_energy_injector_v1"),
        PhysicalComponentCapabilityV71("vacuum_boundary_shell_v1", "boundary",
            String[], all_symmetries, "vacuum_boundary_shell_v1"),
        PhysicalComponentCapabilityV71("closed_coolant_loop_v1", "heat_rejection",
            ["thermal_energy"], all_symmetries, "closed_coolant_loop_v1"),
        PhysicalComponentCapabilityV71("power_conditioner_actuator_v1", "actuator",
            ["actuator_command"], all_symmetries, "power_conditioner_actuator_v1"),
        PhysicalComponentCapabilityV71("state_sensor_array_v1", "sensor",
            ["state_vector"], all_symmetries, "state_sensor_array_v1"),
        PhysicalComponentCapabilityV71("digital_control_stage_v1", "control",
            ["actuator_command", "state_vector"], all_symmetries,
            "digital_control_stage_v1"),
    ])
end

function _v71_sample(rng, lower::Real, upper::Real)
    return Float64(lower) + rand(rng) * (Float64(upper) - Float64(lower))
end

"""Generate bounded physical design genes without reading any device-family metadata."""
function generate_physical_parameter_binding_v71(topology::GraphNativeTopologyV69,
        seed::Integer)
    _graph_v69_assert_label_free(_s70_topology_to_dict(topology), "topology")
    rng = MersenneTwister(seed)
    toroidal = topology.symmetry in ("rotational", "helical")
    geometry_class = toroidal ? "toroidal_volume_v1" : "linear_volume_v1"
    major_radius = _v71_sample(rng, 1.6, 4.8)
    minor_radius = _v71_sample(rng, 0.25, min(1.0, 0.32 * major_radius))
    half_length = _v71_sample(rng, 0.8, 3.0)
    coil_clearance = _v71_sample(rng, 0.10, 0.45)
    field_current = 10.0 ^ _v71_sample(rng, log10(2.0e4), log10(6.0e5))
    field_turns = rand(rng, 4:24)
    conductor_radius = _v71_sample(rng, 0.015, 0.080)
    coil_count = toroidal ? rand(rng, 8:2:24) : 2
    target_temperature = _v71_sample(rng, 6.0, 35.0)
    target_density = 10.0 ^ _v71_sample(rng, 19.2, 20.8)
    heating_power = _v71_sample(rng, 8.0e6, 180.0e6)
    cooling_capacity = 10.0 ^ _v71_sample(rng, log10(40.0e6), log10(2.0e9))
    binding = Dict{String,Any}(
        "binding_schema_version" => "1.0.0",
        "design_space_id" => "bounded_physical_component_space_v71",
        "sampling_method" => "deterministic_uniform_logmix_v1",
        "seed" => Int(seed),
        "geometry_class" => geometry_class,
        "major_radius_m" => major_radius,
        "minor_radius_m" => minor_radius,
        "half_length_m" => half_length,
        "coil_clearance_m" => coil_clearance,
        "field_coil_count" => coil_count,
        "field_current_a" => field_current,
        "field_turns" => field_turns,
        "conductor_radius_m" => conductor_radius,
        "boundary_thickness_m" => _v71_sample(rng, 0.025, 0.12),
        "injector_energy_kev" => _v71_sample(rng, 40.0, 320.0),
        "heating_power_w" => heating_power,
        "injector_efficiency" => _v71_sample(rng, 0.35, 0.82),
        "fueling_capacity_per_s" => 10.0 ^ _v71_sample(rng, 20.0, 23.0),
        "exhaust_capacity_per_s" => 10.0 ^ _v71_sample(rng, 20.0, 23.0),
        "cooling_capacity_w" => cooling_capacity,
        "coolant_inlet_k" => _v71_sample(rng, 70.0, 560.0),
        "sensor_bandwidth_hz" => _v71_sample(rng, 1.0e3, 2.0e5),
        "actuator_capacity_w" => 1.25 * heating_power,
        "control_period_s" => 10.0 ^ _v71_sample(rng, -6.0, -3.0),
        "target_ion_temperature_kev" => target_temperature,
        "target_electron_temperature_kev" => _v71_sample(rng, 4.0, target_temperature),
        "target_total_ion_density_m3" => target_density,
        "effective_charge" => _v71_sample(rng, 1.0, 2.5),
        "design_bounds" => Dict{String,Any}(
            "major_radius_m" => [1.6, 4.8], "minor_radius_m" => [0.25, 1.0],
            "field_current_a" => [2.0e4, 6.0e5], "field_turns" => [4, 24],
            "target_ion_temperature_kev" => [6.0, 35.0],
            "target_total_ion_density_m3" => [10.0^19.2, 10.0^20.8]))
    _graph_v69_assert_label_free(binding, "physical_parameter_binding")
    return binding
end

function _v71_circular_loop(center, axis_u, axis_v, radius, point_count = 64)
    points = Vector{Vector{Float64}}()
    for index in 0:point_count
        angle = 2pi * index / point_count
        push!(points, Float64[center[j] + radius * (cos(angle) * axis_u[j] +
            sin(angle) * axis_v[j]) for j in 1:3])
    end
    return points
end

function _v71_region_geometry(topology::GraphNativeTopologyV69, binding)
    result = Dict{String,Any}[]
    count_regions = length(topology.regions)
    toroidal = binding["geometry_class"] == "toroidal_volume_v1"
    for (index, region) in enumerate(sort(topology.regions; by = item -> String(item["region_id"])))
        scale = max(0.55, 1.0 - 0.10 * (index - 1))
        entry = Dict{String,Any}(
            "region_id" => String(region["region_id"]),
            "computational_dimension" => String(region["dimension"]),
            "time_mode" => String(region["time_mode"]),
            "boundary_class" => String(region["boundary_class"]),
            "geometry_class" => binding["geometry_class"],
            "nested_region_index" => index,
            "nested_region_count" => count_regions,
            "minor_radius_m" => scale * Float64(binding["minor_radius_m"]))
        if toroidal
            entry["center_m"] = [0.0, 0.0, 0.0]
            entry["major_radius_m"] = Float64(binding["major_radius_m"])
            entry["volume_m3"] = 2pi^2 * entry["major_radius_m"] * entry["minor_radius_m"]^2
        else
            entry["center_m"] = [0.0, 0.0,
                (index - (count_regions + 1) / 2) * 0.35 * Float64(binding["half_length_m"])]
            entry["half_length_m"] = scale * Float64(binding["half_length_m"])
            entry["volume_m3"] = pi * entry["minor_radius_m"]^2 *
                (2 * entry["half_length_m"])
        end
        push!(result, entry)
    end
    return result
end

function _v71_field_component(port, region_geometry, binding, symmetry)
    toroidal = binding["geometry_class"] == "toroidal_volume_v1"
    radius = Float64(region_geometry["minor_radius_m"]) + Float64(binding["coil_clearance_m"])
    loops = Dict{String,Any}[]
    winding_basis = "paired_axial_circular_loops_v1"
    if toroidal && symmetry == "helical"
        winding_basis = "closed_toroidal_helical_filament_basis_v1"
        major = Float64(region_geometry["major_radius_m"])
        winding_count = clamp(div(Int(binding["field_coil_count"]), 4), 2, 6)
        poloidal_periods = 2 + mod(Int(binding["field_turns"]), 3)
        point_count = 192
        for winding_index in 1:winding_count
            phase = 2pi * (winding_index - 1) / winding_count
            centerline = Vector{Vector{Float64}}()
            for point_index in 0:point_count
                phi = 2pi * point_index / point_count
                theta = poloidal_periods * phi + phase
                cylindrical_radius = major + radius * cos(theta)
                push!(centerline, [cylindrical_radius * cos(phi),
                    cylindrical_radius * sin(phi), radius * sin(theta)])
            end
            push!(loops, Dict{String,Any}(
                "loop_id" => "$(port["port_id"])_helical_$winding_index",
                "centerline_m" => centerline,
                "current_a" => Float64(binding["field_current_a"]),
                "turns" => Int(binding["field_turns"]),
                "poloidal_periods" => poloidal_periods))
        end
    elseif toroidal
        winding_basis = "distributed_poloidal_loop_array_v1"
        major = Float64(region_geometry["major_radius_m"])
        coil_count = Int(binding["field_coil_count"])
        for coil_index in 1:coil_count
            phi = 2pi * (coil_index - 1) / coil_count
            radial = [cos(phi), sin(phi), 0.0]
            vertical = [0.0, 0.0, 1.0]
            center = major .* radial
            push!(loops, Dict{String,Any}(
                "loop_id" => "$(port["port_id"])_loop_$coil_index",
                "centerline_m" => _v71_circular_loop(center, radial, vertical, radius),
                "current_a" => Float64(binding["field_current_a"]),
                "turns" => Int(binding["field_turns"])))
        end
    else
        center = Float64.(region_geometry["center_m"])
        separation = 1.45 * Float64(region_geometry["half_length_m"])
        for (coil_index, sign) in enumerate((-1.0, 1.0))
            coil_center = copy(center); coil_center[3] += sign * separation / 2
            push!(loops, Dict{String,Any}(
                "loop_id" => "$(port["port_id"])_loop_$coil_index",
                "centerline_m" => _v71_circular_loop(coil_center,
                    [1.0, 0.0, 0.0], [0.0, 1.0, 0.0], radius),
                "current_a" => Float64(binding["field_current_a"]),
                "turns" => Int(binding["field_turns"])))
        end
    end
    return Dict{String,Any}(
        "component_kind" => "finite_filament_coil_array_v1",
        "winding_basis" => winding_basis,
        "loops" => loops,
        "conductor" => Dict{String,Any}(
            "material_model" => "bounded_hts_screening_proxy_v1",
            "radius_m" => Float64(binding["conductor_radius_m"]),
            "current_density_limit_a_m2" => 3.0e8,
            "allowable_magnetic_stress_pa" => 4.0e8),
        "model_fidelity" => "finite_filament_screening_only")
end

function _v71_component_for_port(port, region_geometry, capability, binding, symmetry)
    kind = capability.component_kind
    if kind == "finite_filament_coil_array_v1"
        return _v71_field_component(port, region_geometry, binding, symmetry)
    elseif kind == "vacuum_boundary_shell_v1"
        return Dict{String,Any}("component_kind" => kind,
            "geometry" => deepcopy(region_geometry),
            "wall_thickness_m" => Float64(binding["boundary_thickness_m"]),
            "material_model" => "stainless_steel_316ln_screening_v1",
            "maximum_wall_temperature_k" => 850.0)
    elseif kind == "directed_particle_energy_injector_v1"
        toroidal = binding["geometry_class"] == "toroidal_volume_v1"
        major = Float64(get(region_geometry, "major_radius_m", 0.0))
        center = toroidal ? [major, -1.6 * Float64(region_geometry["minor_radius_m"]), 0.0] :
            Float64.(region_geometry["center_m"]) .+ [0.0, 0.0, -Float64(region_geometry["half_length_m"])]
        direction = toroidal ? [0.0, 1.0, 0.0] : [0.0, 0.0, 1.0]
        return Dict{String,Any}("component_kind" => kind,
            "aperture_center_m" => center, "direction_unit" => direction,
            "aperture_radius_m" => 0.10,
            "particle_energy_kev" => Float64(binding["injector_energy_kev"]),
            "delivered_power_w" => Float64(binding["heating_power_w"]),
            "wall_plug_efficiency" => Float64(binding["injector_efficiency"]),
            "model_fidelity" => "directed_source_geometry_and_capacity_v1")
    elseif kind == "fuel_exhaust_manifold_v1"
        return Dict{String,Any}("component_kind" => kind,
            "fueling_capacity_per_s" => Float64(binding["fueling_capacity_per_s"]),
            "exhaust_capacity_per_s" => Float64(binding["exhaust_capacity_per_s"]),
            "port_geometry_basis" => "region_boundary_penetration_v1")
    elseif kind == "closed_coolant_loop_v1"
        return Dict{String,Any}("component_kind" => kind,
            "heat_rejection_capacity_w" => Float64(binding["cooling_capacity_w"]),
            "coolant_inlet_k" => Float64(binding["coolant_inlet_k"]),
            "loop_count" => 2, "independent_loops" => true)
    elseif kind == "power_conditioner_actuator_v1"
        return Dict{String,Any}("component_kind" => kind,
            "capacity_w" => Float64(binding["actuator_capacity_w"]),
            "response_time_s" => 4.0 * Float64(binding["control_period_s"]),
            "efficiency_domain" => [0.25, 0.97])
    elseif kind == "state_sensor_array_v1"
        return Dict{String,Any}("component_kind" => kind,
            "bandwidth_hz" => Float64(binding["sensor_bandwidth_hz"]),
            "observed_resources" => String.(port["resource_ids"]),
            "redundant_channel_count" => 2)
    elseif kind == "digital_control_stage_v1"
        return Dict{String,Any}("component_kind" => kind,
            "sample_period_s" => Float64(binding["control_period_s"]),
            "input_resources" => ["state_vector"],
            "output_resources" => ["actuator_command"],
            "stability_evidence" => "required_not_supplied")
    end
    throw(ArgumentError("unimplemented component capability $(capability.realizer_id)"))
end

function _v71_match_capability(port, symmetry, registry)
    resources = Set(String.(port["resource_ids"]))
    matches = filter(registry.capabilities) do capability
        capability.port_kind == String(port["port_kind"]) &&
            symmetry in capability.supported_symmetries &&
            all(resource -> resource in resources, capability.required_resource_ids)
    end
    length(matches) == 1 || return nothing
    return only(matches)
end

function compile_physical_device_realization_v71(topology::GraphNativeTopologyV69,
        compilation::GraphTopologyCompilationV69;
        parameter_binding,
        registry::PhysicalComponentRegistryV71 = default_physical_component_registry_v71())
    binding = _v71_plain(parameter_binding)
    _graph_v69_assert_label_free(binding, "physical_parameter_binding")
    binding_hash = canonical_hash(binding)
    missing = String[]
    compilation.topology_hash == topology.topology_hash ||
        push!(missing, "topology_compilation_binding_mismatch")
    compilation.status == :pass || push!(missing,
        "topology_compilation_not_pass:$(compilation.classification_code)")
    required_binding_keys = ("geometry_class", "major_radius_m", "minor_radius_m",
        "half_length_m", "coil_clearance_m", "field_current_a", "field_turns",
        "conductor_radius_m", "boundary_thickness_m", "heating_power_w",
        "cooling_capacity_w", "target_ion_temperature_kev",
        "target_total_ion_density_m3")
    for key in required_binding_keys
        haskey(binding, key) || push!(missing, "missing_physical_parameter:$key")
    end
    geometry = Dict{String,Any}()
    components = Dict{String,Any}[]
    port_mappings = Dict{String,Any}[]
    dependency_mappings = Dict{String,Any}[]
    if isempty(missing)
        regions = _v71_region_geometry(topology, binding)
        geometry = Dict{String,Any}(
            "geometry_class" => binding["geometry_class"],
            "symmetry" => topology.symmetry,
            "regions" => regions)
        region_index = Dict(String(item["region_id"]) => item for item in regions)
        component_by_port = Dict{String,String}()
        for port in sort(topology.ports; by = item -> String(item["port_id"]))
            capability = _v71_match_capability(port, topology.symmetry, registry)
            if capability === nothing
                push!(missing, "unsupported_physical_realizer:$(port["port_id"]):$(port["port_kind"])")
                continue
            end
            region_id = String(port["region_id"])
            haskey(region_index, region_id) || begin
                push!(missing, "missing_region_geometry:$region_id"); continue
            end
            component_id = "component://$(port["port_id"])/$(capability.realizer_id)"
            body = _v71_component_for_port(port, region_index[region_id], capability,
                binding, topology.symmetry)
            component = merge(Dict{String,Any}(
                "component_id" => component_id,
                "realizer_id" => capability.realizer_id,
                "region_id" => region_id,
                "bound_port_id" => String(port["port_id"]),
                "bound_resource_ids" => sort!(String.(port["resource_ids"]))), body)
            component["component_hash"] = canonical_hash(component)
            push!(components, component)
            component_by_port[String(port["port_id"])] = component_id
            push!(port_mappings, Dict{String,Any}(
                "port_id" => String(port["port_id"]),
                "component_id" => component_id,
                "realizer_id" => capability.realizer_id,
                "status" => "bound"))
        end
        for dependency in sort(topology.dependencies; by = item -> String(item["dependency_id"]))
            source = String(dependency["source_port_id"])
            target = String(dependency["target_port_id"])
            if haskey(component_by_port, source) && haskey(component_by_port, target)
                push!(dependency_mappings, Dict{String,Any}(
                    "dependency_id" => String(dependency["dependency_id"]),
                    "source_component_id" => component_by_port[source],
                    "target_component_id" => component_by_port[target],
                    "dependency_kind" => String(dependency["dependency_kind"]),
                    "status" => "bound"))
            else
                push!(missing, "unbound_component_dependency:$(dependency["dependency_id"])")
            end
        end
    end
    completeness = isempty(missing) ? :complete : :incomplete
    conclusion = isempty(missing) ? :unknown :
        (any(startswith(reason, "unsupported_physical_realizer") for reason in missing) ?
            :unsupported : :unknown)
    classification = isempty(missing) ?
        "physical_realization_compiled_requires_simulation" :
        (conclusion == :unsupported ? "unsupported_physical_component_capability" :
            "incomplete_physical_realization")
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "topology_hash" => topology.topology_hash,
        "compilation_hash" => compilation.compilation_hash,
        "candidate_binding_hash" => binding_hash, "registry_hash" => registry.registry_hash,
        "completeness" => String(completeness), "conclusion" => String(conclusion),
        "classification_code" => classification, "geometry" => geometry,
        "components" => components, "port_mappings" => port_mappings,
        "dependency_mappings" => dependency_mappings,
        "missing_requirements" => sort!(unique(missing)),
        "claim_boundary" => PHYSICAL_REALIZATION_V71_CLAIM_BOUNDARY)
    return PhysicalDeviceRealizationV71("1.0.0", topology.topology_hash,
        compilation.compilation_hash, binding_hash, registry.registry_hash,
        completeness, conclusion, classification, geometry, components,
        port_mappings, dependency_mappings, sort!(unique(missing)),
        PHYSICAL_REALIZATION_V71_CLAIM_BOUNDARY, canonical_hash(body))
end

function physical_device_realization_to_dict_v71(item::PhysicalDeviceRealizationV71)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "topology_hash" => item.topology_hash,
        "compilation_hash" => item.compilation_hash,
        "candidate_binding_hash" => item.candidate_binding_hash,
        "registry_hash" => item.registry_hash,
        "completeness" => String(item.completeness),
        "conclusion" => String(item.conclusion),
        "classification_code" => item.classification_code,
        "geometry" => item.geometry,
        "components" => item.components,
        "port_mappings" => item.port_mappings,
        "dependency_mappings" => item.dependency_mappings,
        "missing_requirements" => item.missing_requirements,
        "claim_boundary" => item.claim_boundary,
        "realization_hash" => item.realization_hash)
end
