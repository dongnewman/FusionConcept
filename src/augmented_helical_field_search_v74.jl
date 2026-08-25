const AUGMENTED_HELICAL_FIELD_V74_CLAIM_BOUNDARY =
    "v74 searches a capability-routed combination of distributed toroidal-field base coils and helical perturbation windings. Surviving the field-line gate remains transport_unknown until kinetic, finite-pressure, stability, and engineering evidence is closed."

function generate_augmented_helical_parameter_binding_v74(
        topology::GraphNativeTopologyV69, structure_seed::Integer,
        physical_variant_seed::Integer)
    topology.symmetry == "helical" || throw(ArgumentError(
        "v74 augmented helical binding requires declared helical symmetry"))
    binding = generate_physical_parameter_binding_v71(topology, physical_variant_seed)
    binding["design_space_id"] = "augmented_helical_closed_surface_space_v74"
    binding["structure_seed"] = Int(structure_seed)
    binding["physical_variant_seed"] = Int(physical_variant_seed)
    rng = MersenneTwister(7_400_003 + 1009 * structure_seed + physical_variant_seed)
    binding["field_current_a"] = 10.0 ^ _v71_sample(rng, log10(2.0e4), log10(5.0e5))
    binding["field_turns"] = rand(rng, 4:20)
    binding["field_coil_count"] = rand(rng, 12:2:30)
    binding["helical_winding_count"] = rand(rng, 2:6)
    binding["helical_poloidal_periods"] = rand(rng, 1:4)
    binding["helical_current_fraction"] = 10.0 ^ _v71_sample(rng, log10(0.005), log10(0.35))
    binding["helical_radial_scale"] = _v71_sample(rng, 0.85, 1.25)
    binding["conductor_radius_m"] = _v71_sample(rng, 0.02, 0.085)
    binding["coil_clearance_m"] = _v71_sample(rng, 0.12, 0.5)
    _graph_v69_assert_label_free(binding, "augmented_helical_parameter_binding")
    return binding
end

function _v74_augmented_field_component(port, region_geometry, binding)
    major = Float64(region_geometry["major_radius_m"])
    minor = Float64(region_geometry["minor_radius_m"])
    base_radius = minor + Float64(binding["coil_clearance_m"])
    base_count = Int(binding["field_coil_count"])
    current = Float64(binding["field_current_a"])
    turns = Int(binding["field_turns"])
    loops = Dict{String,Any}[]
    for coil_index in 1:base_count
        phi = 2pi * (coil_index - 1) / base_count
        radial = [cos(phi), sin(phi), 0.0]
        vertical = [0.0, 0.0, 1.0]
        center = major .* radial
        push!(loops, Dict{String,Any}(
            "loop_id" => "$(port["port_id"])_base_$coil_index",
            "winding_role" => "toroidal_field_base",
            "centerline_m" => _v71_circular_loop(center, radial, vertical,
                base_radius, 64), "current_a" => current, "turns" => turns))
    end
    helical_count = Int(binding["helical_winding_count"])
    periods = Int(binding["helical_poloidal_periods"])
    helical_radius = base_radius * Float64(binding["helical_radial_scale"])
    helical_current = current * Float64(binding["helical_current_fraction"])
    current_pattern = String(get(binding, "helical_current_pattern", "co_directional"))
    current_pattern in ("co_directional", "alternating") || throw(ArgumentError(
        "unsupported helical current pattern $current_pattern"))
    phase_modulation = Float64(get(binding, "helical_phase_modulation_rad", 0.0))
    radial_harmonic = Float64(get(binding, "helical_radial_harmonic_fraction", 0.0))
    vertical_harmonic = Float64(get(binding,
        "helical_vertical_harmonic_fraction", 0.0))
    harmonic_phase = Float64(get(binding, "helical_harmonic_phase_rad", 0.0))
    harmonic_mode = Int(get(binding, "helical_harmonic_toroidal_mode", 1))
    current_imbalance = Float64(get(binding,
        "helical_winding_current_imbalance", 0.0))
    abs(phase_modulation) <= 0.75 || throw(ArgumentError(
        "helical phase modulation outside bounded space"))
    abs(radial_harmonic) <= 0.25 || throw(ArgumentError(
        "helical radial harmonic outside bounded space"))
    abs(vertical_harmonic) <= 0.25 || throw(ArgumentError(
        "helical vertical harmonic outside bounded space"))
    1 <= harmonic_mode <= 6 || throw(ArgumentError(
        "helical harmonic toroidal mode outside bounded space"))
    abs(current_imbalance) <= 0.35 || throw(ArgumentError(
        "helical winding current imbalance outside bounded space"))
    point_count = 256
    for winding_index in 1:helical_count
        phase = 2pi * (winding_index - 1) / helical_count
        centerline = Vector{Vector{Float64}}()
        for point_index in 0:point_count
            phi = 2pi * point_index / point_count
            base_theta = periods * phi + phase
            modulation_phase = harmonic_mode * phi + phase + harmonic_phase
            theta = base_theta + phase_modulation * sin(modulation_phase)
            shape_phase = 2base_theta + harmonic_phase
            radial_radius = helical_radius *
                (1.0 + radial_harmonic * cos(shape_phase))
            vertical_radius = helical_radius *
                (1.0 + vertical_harmonic * sin(shape_phase))
            cylindrical_radius = major + radial_radius * cos(theta)
            push!(centerline, [cylindrical_radius * cos(phi),
                cylindrical_radius * sin(phi), vertical_radius * sin(theta)])
        end
        winding_current_factor = 1.0 + current_imbalance * cos(phase + harmonic_phase)
        push!(loops, Dict{String,Any}(
            "loop_id" => "$(port["port_id"])_helical_$winding_index",
            "winding_role" => "helical_transform_perturbation",
            "centerline_m" => centerline,
            "current_a" => helical_current * winding_current_factor *
                (current_pattern == "alternating" && iseven(winding_index) ? -1.0 : 1.0),
            "turns" => turns, "poloidal_periods" => periods))
    end
    return Dict{String,Any}(
        "component_kind" => "finite_filament_coil_array_v1",
        "winding_basis" => "combined_toroidal_base_and_helical_perturbation_v1",
        "loops" => loops,
        "base_coil_count" => base_count, "helical_winding_count" => helical_count,
        "helical_poloidal_periods" => periods,
        "helical_current_fraction" => Float64(binding["helical_current_fraction"]),
        "helical_current_pattern" => current_pattern,
        "helical_phase_modulation_rad" => phase_modulation,
        "helical_radial_harmonic_fraction" => radial_harmonic,
        "helical_vertical_harmonic_fraction" => vertical_harmonic,
        "helical_harmonic_phase_rad" => harmonic_phase,
        "helical_harmonic_toroidal_mode" => harmonic_mode,
        "helical_winding_current_imbalance" => current_imbalance,
        "conductor" => Dict{String,Any}(
            "material_model" => "bounded_hts_screening_proxy_v1",
            "radius_m" => Float64(binding["conductor_radius_m"]),
            "current_density_limit_a_m2" => 3.0e8,
            "allowable_magnetic_stress_pa" => 4.0e8),
        "model_fidelity" => "finite_filament_augmented_helical_screening_only")
end

function compile_augmented_helical_realization_v74(
        topology::GraphNativeTopologyV69,
        compilation::GraphTopologyCompilationV69; parameter_binding)
    topology.symmetry == "helical" || throw(ArgumentError(
        "v74 realization requires helical symmetry capability"))
    binding = _v71_plain(parameter_binding)
    for key in ("helical_winding_count", "helical_poloidal_periods",
            "helical_current_fraction", "helical_radial_scale")
        haskey(binding, key) || throw(ArgumentError("missing v74 field gene $key"))
    end
    base = compile_physical_device_realization_v71(topology, compilation;
        parameter_binding = binding)
    base.completeness == :complete || return base
    regions = Dict(String(item["region_id"]) => item for item in base.geometry["regions"])
    ports = Dict(String(item["port_id"]) => item for item in topology.ports)
    components = deepcopy(base.components)
    for index in eachindex(components)
        component = components[index]
        component["component_kind"] == "finite_filament_coil_array_v1" || continue
        port = ports[String(component["bound_port_id"])]
        body = _v74_augmented_field_component(port, regions[String(component["region_id"])],
            binding)
        replacement = merge(Dict{String,Any}(
            "component_id" => component["component_id"],
            "realizer_id" => "augmented_helical_field_array_v74",
            "region_id" => component["region_id"],
            "bound_port_id" => component["bound_port_id"],
            "bound_resource_ids" => component["bound_resource_ids"]), body)
        replacement["component_hash"] = canonical_hash(replacement)
        components[index] = replacement
    end
    port_mappings = deepcopy(base.port_mappings)
    for mapping in port_mappings
        port = ports[String(mapping["port_id"])]
        if String(port["port_kind"]) == "field_source"
            mapping["realizer_id"] = "augmented_helical_field_array_v74"
        end
    end
    registry_hash = canonical_hash(Dict{String,Any}(
        "base_registry_hash" => base.registry_hash,
        "extension_id" => "augmented_helical_field_array_v74"))
    body = Dict{String,Any}(
        "schema_version" => base.schema_version, "topology_hash" => base.topology_hash,
        "compilation_hash" => base.compilation_hash,
        "candidate_binding_hash" => base.candidate_binding_hash,
        "registry_hash" => registry_hash, "completeness" => String(base.completeness),
        "conclusion" => String(base.conclusion),
        "classification_code" => "augmented_helical_realization_requires_simulation",
        "geometry" => base.geometry, "components" => components,
        "port_mappings" => port_mappings,
        "dependency_mappings" => base.dependency_mappings,
        "missing_requirements" => base.missing_requirements,
        "claim_boundary" => AUGMENTED_HELICAL_FIELD_V74_CLAIM_BOUNDARY)
    return PhysicalDeviceRealizationV71(base.schema_version, base.topology_hash,
        base.compilation_hash, base.candidate_binding_hash, registry_hash,
        base.completeness, base.conclusion,
        "augmented_helical_realization_requires_simulation", base.geometry,
        components, port_mappings, base.dependency_mappings,
        base.missing_requirements, AUGMENTED_HELICAL_FIELD_V74_CLAIM_BOUNDARY,
        canonical_hash(body))
end

function _v74_candidate_rank(row)
    nonparticle_pass = Int(row["nonparticle_pass_count"])
    disposition = row["closed_field_conclusion"] == "unknown" ? 0 :
        (row["closed_field_conclusion"] == "fail" ? 1 : 2)
    escaped = Bool(row["field_line_escape"])
    transform = Float64(row["minimum_absolute_rotational_transform"])
    excursion = Float64(row["maximum_normalized_minor_radius_excursion"])
    return (-nonparticle_pass, disposition, escaped ? 1 : 0,
        transform >= 0.02 ? 0 : 1, excursion, -transform, Int(row["variant_seed"]))
end

function run_augmented_helical_field_search_v74(structure_seed::Integer,
        first_variant_seed::Integer, last_variant_seed::Integer;
        output_path::Union{Nothing,AbstractString} = nothing,
        target_toroidal_turns::Real = 1.0, steps_per_turn::Integer = 120)
    1 <= first_variant_seed <= last_variant_seed || throw(ArgumentError(
        "invalid v74 variant range"))
    topology = generate_graph_native_topology_v69(structure_seed)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    compilation.status == :pass || throw(ArgumentError(
        "v74 structure topology did not compile"))
    topology.symmetry == "helical" || throw(ArgumentError(
        "v74 structure lacks helical symmetry capability"))
    rows = Dict{String,Any}[]; best = nothing; exception_count = 0
    for variant_seed in first_variant_seed:last_variant_seed
        try
            binding = generate_augmented_helical_parameter_binding_v74(topology,
                structure_seed, variant_seed)
            realization = compile_augmented_helical_realization_v74(topology,
                compilation; parameter_binding = binding)
            screen = screen_physical_device_v71(realization, binding;
                particle_count = 1, step_count = 1,
                required_transit_fraction = 1.0)
            gate = evaluate_closed_field_transport_gate_v73(realization, screen,
                binding; target_toroidal_turns = target_toroidal_turns,
                steps_per_turn = steps_per_turn)
            nonparticle_ids = ("finite_field", "dt_power_balance_proxy",
                "conductor_current_density", "magnetic_stress", "heat_rejection_capacity")
            nonparticle_pass = count(id -> get(screen.gate_statuses, id, "unknown") == "pass",
                nonparticle_ids)
            lines = gate.field_line_evidence
            row = Dict{String,Any}(
                "structure_seed" => Int(structure_seed),
                "variant_seed" => Int(variant_seed),
                "candidate_binding_hash" => realization.candidate_binding_hash,
                "realization_hash" => realization.realization_hash,
                "screen_evidence_hash" => screen.evidence_hash,
                "closed_field_evidence_hash" => gate.evidence_hash,
                "nonparticle_pass_count" => nonparticle_pass,
                "closed_field_conclusion" => String(gate.conclusion),
                "closed_field_classification_code" => gate.classification_code,
                "field_line_escape" => Bool(get(lines, "any_trace_escaped", true)),
                "minimum_absolute_rotational_transform" => Float64(get(lines,
                    "minimum_absolute_rotational_transform", 0.0)),
                "maximum_normalized_minor_radius_excursion" => Float64(get(lines,
                    "maximum_normalized_minor_radius_excursion", Inf)),
                "minimum_field_t" => get(screen.field_evidence, "minimum_field_t", nothing),
                "maximum_field_t" => get(screen.field_evidence, "maximum_field_t", nothing),
                "plasma_gain_proxy" => get(screen.plasma_evidence,
                    "plasma_gain_proxy", nothing),
                "helical_current_fraction" => binding["helical_current_fraction"],
                "helical_poloidal_periods" => binding["helical_poloidal_periods"],
                "base_coil_count" => binding["field_coil_count"])
            row["row_hash"] = canonical_hash(row); push!(rows, row)
            if best === nothing || _v74_candidate_rank(row) < _v74_candidate_rank(best["row"])
                best = Dict{String,Any}(
                    "row" => row, "topology" => _s70_topology_to_dict(topology),
                    "parameter_binding" => binding,
                    "realization" => physical_device_realization_to_dict_v71(realization),
                    "screen" => physical_device_screen_to_dict_v71(screen),
                    "closed_field_gate" => closed_field_transport_gate_to_dict_v73(gate))
            end
        catch error
            exception_count += 1
            push!(rows, Dict{String,Any}(
                "structure_seed" => Int(structure_seed),
                "variant_seed" => Int(variant_seed), "status" => "exception",
                "exception_type" => String(nameof(typeof(error)))))
        end
    end
    sort!(rows; by = row -> Int(row["variant_seed"]))
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "status" => exception_count == 0 && best !== nothing ? "complete" : "incomplete",
        "structure_seed" => Int(structure_seed),
        "first_variant_seed" => Int(first_variant_seed),
        "last_variant_seed" => Int(last_variant_seed),
        "variant_count" => Int(last_variant_seed - first_variant_seed + 1),
        "uncaught_exception_count" => exception_count,
        "unknown_closed_field_count" => count(row -> get(row,
            "closed_field_conclusion", "") == "unknown", rows),
        "field_line_escape_count" => count(row -> get(row,
            "field_line_escape", true) === true, rows),
        "winner_selection_method" =>
            "nonparticle_gates_then_closed_field_disposition_transform_and_excursion_v1",
        "winner" => best, "candidate_rows" => rows,
        "device_family_routing_used" => false,
        "claim_boundary" => AUGMENTED_HELICAL_FIELD_V74_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
    return artifact
end
