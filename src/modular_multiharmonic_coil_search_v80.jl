const MODULAR_MULTIHARMONIC_COIL_V80_CLAIM_BOUNDARY =
    "v80 independently samples modular finite-filament windings with per-module phase, current, helicity, period, radius, and bounded harmonics. All candidates receive the same fast candidate-bound field and engineering screen; shortlisted candidates receive the same RK4 field-line gates. A winner remains non-feasible until every downstream plasma, transport, stability, particle, and engineering gate closes."

function generate_modular_multiharmonic_binding_v80(
        topology::GraphNativeTopologyV69, structure_seed::Integer,
        modular_seed::Integer)
    binding = generate_augmented_helical_parameter_binding_v74(topology,
        structure_seed, modular_seed)
    rng = MersenneTwister(8_000_033 + 1009 * structure_seed + modular_seed)
    binding["design_space_id"] = "independent_modular_multiharmonic_coil_space_v80"
    binding["modular_seed"] = Int(modular_seed)
    binding["field_coil_count"] = rand(rng, 16:2:32)
    binding["field_current_a"] = 10.0 ^ _v71_sample(rng, log10(3.0e4), log10(5.0e5))
    binding["field_turns"] = rand(rng, 4:20)
    module_count = rand(rng, 3:8)
    modules = Dict{String,Any}[]
    for module_index in 1:module_count
        magnitude = 10.0 ^ _v71_sample(rng, log10(0.004), log10(0.20))
        push!(modules, Dict{String,Any}(
            "module_index" => module_index,
            "phase_rad" => _v71_sample(rng, 0.0, 2pi),
            "signed_current_fraction" => (rand(rng, Bool) ? 1.0 : -1.0) * magnitude,
            "helicity_sign" => rand(rng, Bool) ? 1 : -1,
            "poloidal_periods" => rand(rng, 1:5),
            "radial_scale" => _v71_sample(rng, 1.05, 1.45),
            "phase_modulation_rad" => _v71_sample(rng, -0.65, 0.65),
            "radial_harmonic_fraction" => _v71_sample(rng, -0.16, 0.16),
            "vertical_harmonic_fraction" => _v71_sample(rng, -0.16, 0.16),
            "harmonic_phase_rad" => _v71_sample(rng, 0.0, 2pi),
            "harmonic_toroidal_mode" => rand(rng, 1:5)))
    end
    binding["modular_windings"] = modules
    binding["modular_winding_count"] = module_count
    _graph_v69_assert_label_free(binding, "modular_multiharmonic_binding")
    return binding
end

function _v80_modular_field_component(port, region_geometry, binding)
    major = Float64(region_geometry["major_radius_m"])
    minor = Float64(region_geometry["minor_radius_m"])
    base_radius = minor + Float64(binding["coil_clearance_m"])
    current = Float64(binding["field_current_a"])
    turns = Int(binding["field_turns"])
    base_count = Int(binding["field_coil_count"])
    loops = Dict{String,Any}[]
    for coil_index in 1:base_count
        phi = 2pi * (coil_index - 1) / base_count
        radial = [cos(phi), sin(phi), 0.0]
        center = major .* radial
        push!(loops, Dict{String,Any}(
            "loop_id" => "$(port["port_id"])_base_$coil_index",
            "winding_role" => "toroidal_field_base",
            "centerline_m" => _v71_circular_loop(center, radial,
                [0.0, 0.0, 1.0], base_radius, 48),
            "current_a" => current, "turns" => turns))
    end
    modules = _v71_plain(binding["modular_windings"])
    for winding in modules
        module_index = Int(winding["module_index"])
        phase = Float64(winding["phase_rad"])
        periods = Int(winding["poloidal_periods"])
        helicity = Int(winding["helicity_sign"])
        radial_scale = Float64(winding["radial_scale"])
        phase_modulation = Float64(winding["phase_modulation_rad"])
        radial_harmonic = Float64(winding["radial_harmonic_fraction"])
        vertical_harmonic = Float64(winding["vertical_harmonic_fraction"])
        harmonic_phase = Float64(winding["harmonic_phase_rad"])
        harmonic_mode = Int(winding["harmonic_toroidal_mode"])
        helical_radius = base_radius * radial_scale
        centerline = Vector{Vector{Float64}}()
        point_count = 128
        for point_index in 0:point_count
            phi = 2pi * point_index / point_count
            base_theta = helicity * periods * phi + phase
            modulation_phase = harmonic_mode * phi + harmonic_phase
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
        push!(loops, Dict{String,Any}(
            "loop_id" => "$(port["port_id"])_module_$module_index",
            "winding_role" => "independent_multiharmonic_module",
            "centerline_m" => centerline,
            "current_a" => current * Float64(winding["signed_current_fraction"]),
            "turns" => turns, "module_parameters" => winding))
    end
    return Dict{String,Any}(
        "component_kind" => "finite_filament_coil_array_v1",
        "winding_basis" => "independent_modular_multiharmonic_filaments_v1",
        "loops" => loops, "base_coil_count" => base_count,
        "modular_winding_count" => length(modules),
        "modular_windings" => modules,
        "conductor" => Dict{String,Any}(
            "material_model" => "bounded_hts_screening_proxy_v1",
            "radius_m" => Float64(binding["conductor_radius_m"]),
            "current_density_limit_a_m2" => 3.0e8,
            "allowable_magnetic_stress_pa" => 4.0e8),
        "model_fidelity" => "finite_filament_modular_multiharmonic_screening_v1")
end

function compile_modular_multiharmonic_realization_v80(
        topology::GraphNativeTopologyV69,
        compilation::GraphTopologyCompilationV69; parameter_binding)
    binding = _v71_plain(parameter_binding)
    haskey(binding, "modular_windings") || throw(ArgumentError(
        "missing v80 modular winding definitions"))
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
        body = _v80_modular_field_component(port,
            regions[String(component["region_id"])], binding)
        replacement = merge(Dict{String,Any}(
            "component_id" => component["component_id"],
            "realizer_id" => "modular_multiharmonic_field_array_v80",
            "region_id" => component["region_id"],
            "bound_port_id" => component["bound_port_id"],
            "bound_resource_ids" => component["bound_resource_ids"]), body)
        replacement["component_hash"] = canonical_hash(replacement)
        components[index] = replacement
    end
    port_mappings = deepcopy(base.port_mappings)
    for mapping in port_mappings
        port = ports[String(mapping["port_id"])]
        String(port["port_kind"]) == "field_source" || continue
        mapping["realizer_id"] = "modular_multiharmonic_field_array_v80"
    end
    registry_hash = canonical_hash(Dict{String,Any}(
        "base_registry_hash" => base.registry_hash,
        "extension_id" => "modular_multiharmonic_field_array_v80"))
    body = Dict{String,Any}(
        "schema_version" => base.schema_version, "topology_hash" => base.topology_hash,
        "compilation_hash" => base.compilation_hash,
        "candidate_binding_hash" => base.candidate_binding_hash,
        "registry_hash" => registry_hash, "completeness" => String(base.completeness),
        "conclusion" => String(base.conclusion),
        "classification_code" => "modular_multiharmonic_requires_simulation",
        "geometry" => base.geometry, "components" => components,
        "port_mappings" => port_mappings,
        "dependency_mappings" => base.dependency_mappings,
        "missing_requirements" => base.missing_requirements,
        "claim_boundary" => MODULAR_MULTIHARMONIC_COIL_V80_CLAIM_BOUNDARY)
    return PhysicalDeviceRealizationV71(base.schema_version, base.topology_hash,
        base.compilation_hash, base.candidate_binding_hash, registry_hash,
        base.completeness, base.conclusion,
        "modular_multiharmonic_requires_simulation", base.geometry,
        components, port_mappings, base.dependency_mappings,
        base.missing_requirements, MODULAR_MULTIHARMONIC_COIL_V80_CLAIM_BOUNDARY,
        canonical_hash(body))
end

function _v80_fast_field_proxy(realization::PhysicalDeviceRealizationV71)
    cache = compile_finite_filament_field_cache_v71(realization)
    region = _v71_primary_region(realization)
    major = Float64(region["major_radius_m"])
    minor = Float64(region["minor_radius_m"])
    transforms = Float64[]
    magnitudes = Float64[]
    for fraction in (0.20, 0.40, 0.60), phi in (0.0, 0.5pi, pi, 1.5pi)
        point = [(major + fraction * minor) * cos(phi),
            (major + fraction * minor) * sin(phi), 0.0]
        field = finite_filament_field_v71(cache, point)
        magnitude = norm(field)
        toroidal = abs(dot(field, [-sin(phi), cos(phi), 0.0]))
        poloidal = abs(field[3])
        push!(magnitudes, magnitude)
        push!(transforms, toroidal > 1.0e-12 ?
            poloidal / toroidal * major / (fraction * minor) : 0.0)
    end
    sorted_transforms = sort(transforms)
    proxy_transform = sorted_transforms[div(length(sorted_transforms) + 1, 2)]
    mean_field = sum(magnitudes) / length(magnitudes)
    ripple = mean_field > 0 ? (maximum(magnitudes) - minimum(magnitudes)) /
        mean_field : Inf
    return Dict{String,Any}(
        "model_id" => "twelve_point_candidate_biot_savart_transform_proxy_v1",
        "median_transform_proxy" => proxy_transform,
        "minimum_field_t" => minimum(magnitudes),
        "maximum_field_t" => maximum(magnitudes),
        "relative_field_ripple" => ripple,
        "field_cache_hash" => cache.cache_hash)
end

function _v80_proxy_rank(row)
    nonparticle = Int(row["nonparticle_pass_count"])
    transform = Float64(row["median_transform_proxy"])
    ripple = Float64(row["relative_field_ripple"])
    useful_transform = 0.015 <= transform <= 0.8
    return (-nonparticle, useful_transform ? 0 : 1,
        useful_transform ? abs(log(transform / 0.06)) : abs(transform - 0.06),
        ripple, Int(row["modular_seed"]))
end

function run_modular_multiharmonic_search_v80(structure_seed::Integer,
        first_seed::Integer, last_seed::Integer;
        shortlist_count::Integer = 128, finalist_count::Integer = 8,
        output_path::Union{Nothing,AbstractString} = nothing,
        progress_interval::Integer = 500)
    1 <= first_seed <= last_seed || throw(ArgumentError("invalid v80 seed range"))
    topology = generate_graph_native_topology_v69(structure_seed)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    candidate_count = Int(last_seed - first_seed + 1)
    proxy_rows = Vector{Dict{String,Any}}(undef, candidate_count)
    completed_count = Threads.Atomic{Int}(0)
    Threads.@threads for offset in 1:candidate_count
        seed = Int(first_seed + offset - 1)
        try
            binding = generate_modular_multiharmonic_binding_v80(topology,
                structure_seed, seed)
            realization = compile_modular_multiharmonic_realization_v80(topology,
                compilation; parameter_binding = binding)
            screen = screen_physical_device_v71(realization, binding;
                particle_count = 1, step_count = 1, required_transit_fraction = 1.0)
            proxy = _v80_fast_field_proxy(realization)
            nonparticle_ids = ("finite_field", "dt_power_balance_proxy",
                "conductor_current_density", "magnetic_stress", "heat_rejection_capacity")
            row = Dict{String,Any}(
                "modular_seed" => Int(seed),
                "candidate_binding_hash" => realization.candidate_binding_hash,
                "realization_hash" => realization.realization_hash,
                "nonparticle_pass_count" => count(id ->
                    get(screen.gate_statuses, id, "unknown") == "pass", nonparticle_ids),
                "median_transform_proxy" => proxy["median_transform_proxy"],
                "minimum_field_t" => proxy["minimum_field_t"],
                "maximum_field_t" => proxy["maximum_field_t"],
                "relative_field_ripple" => proxy["relative_field_ripple"],
                "modular_winding_count" => binding["modular_winding_count"])
            row["row_hash"] = canonical_hash(row)
            proxy_rows[offset] = row
        catch error
            proxy_rows[offset] = Dict{String,Any}(
                "modular_seed" => Int(seed), "status" => "exception",
                "exception_type" => String(nameof(typeof(error))))
        end
        completed = Threads.atomic_add!(completed_count, 1) + 1
        if progress_interval > 0 && completed % progress_interval == 0
            println("v80_proxy_progress=", completed, "/", candidate_count)
            flush(stdout)
        end
    end
    exception_count = count(row -> haskey(row, "status"), proxy_rows)
    valid_proxy_rows = [row for row in proxy_rows if !haskey(row, "status")]
    sort!(valid_proxy_rows; by = _v80_proxy_rank)
    shortlist = valid_proxy_rows[1:min(Int(shortlist_count), length(valid_proxy_rows))]
    field_rows = Dict{String,Any}[]
    full_by_seed = Dict{Int,Dict{String,Any}}()
    for proxy_row in shortlist
        seed = Int(proxy_row["modular_seed"])
        binding = generate_modular_multiharmonic_binding_v80(topology,
            structure_seed, seed)
        realization = compile_modular_multiharmonic_realization_v80(topology,
            compilation; parameter_binding = binding)
        screen = screen_physical_device_v71(realization, binding;
            particle_count = 1, step_count = 1, required_transit_fraction = 1.0)
        gate = evaluate_closed_field_transport_gate_v73(realization, screen,
            binding; target_toroidal_turns = 4.0, steps_per_turn = 180)
        lines = gate.field_line_evidence
        row = merge(deepcopy(proxy_row), Dict{String,Any}(
            "closed_field_conclusion" => String(gate.conclusion),
            "classification_code" => gate.classification_code,
            "field_line_escape" => Bool(get(lines, "any_trace_escaped", true)),
            "minimum_absolute_rotational_transform" => Float64(get(lines,
                "minimum_absolute_rotational_transform", 0.0)),
            "maximum_normalized_minor_radius_excursion" => Float64(get(lines,
                "maximum_normalized_minor_radius_excursion", Inf))))
        push!(field_rows, row)
        full_by_seed[seed] = Dict{String,Any}(
            "row" => row, "parameter_binding" => binding,
            "topology" => _s70_topology_to_dict(topology),
            "realization" => physical_device_realization_to_dict_v71(realization),
            "screen" => physical_device_screen_to_dict_v71(screen),
            "four_turn_gate" => closed_field_transport_gate_to_dict_v73(gate))
    end
    sort!(field_rows; by = row -> _v77_rank(merge(row,
        Dict("local_variant_seed" => Int(row["modular_seed"])))))
    finalists = field_rows[1:min(Int(finalist_count), length(field_rows))]
    final_rows = Dict{String,Any}[]
    for row4 in finalists
        seed = Int(row4["modular_seed"])
        binding = generate_modular_multiharmonic_binding_v80(topology,
            structure_seed, seed)
        realization = compile_modular_multiharmonic_realization_v80(topology,
            compilation; parameter_binding = binding)
        screen = screen_physical_device_v71(realization, binding;
            particle_count = 1, step_count = 1, required_transit_fraction = 1.0)
        gate8 = evaluate_closed_field_transport_gate_v73(realization, screen,
            binding; target_toroidal_turns = 8.0, steps_per_turn = 360)
        lines = gate8.field_line_evidence
        row8 = merge(deepcopy(row4), Dict{String,Any}(
            "closed_field_conclusion" => String(gate8.conclusion),
            "classification_code" => gate8.classification_code,
            "field_line_escape" => Bool(get(lines, "any_trace_escaped", true)),
            "minimum_absolute_rotational_transform" => Float64(get(lines,
                "minimum_absolute_rotational_transform", 0.0)),
            "maximum_normalized_minor_radius_excursion" => Float64(get(lines,
                "maximum_normalized_minor_radius_excursion", Inf))))
        push!(final_rows, row8)
        full_by_seed[seed]["row"] = row8
        full_by_seed[seed]["eight_turn_gate"] =
            closed_field_transport_gate_to_dict_v73(gate8)
    end
    sort!(final_rows; by = row -> _v77_rank(merge(row,
        Dict("local_variant_seed" => Int(row["modular_seed"])))))
    winner = isempty(final_rows) ? nothing : full_by_seed[Int(final_rows[1]["modular_seed"])]
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "status" => exception_count == 0 && winner !== nothing ? "complete" : "incomplete",
        "structure_seed" => Int(structure_seed), "first_seed" => Int(first_seed),
        "last_seed" => Int(last_seed),
        "searched_candidate_count" => Int(last_seed - first_seed + 1),
        "uncaught_exception_count" => exception_count,
        "shortlist_count" => length(shortlist), "finalist_count" => length(finalists),
        "four_turn_unknown_count" => count(row ->
            row["closed_field_conclusion"] == "unknown", field_rows),
        "eight_turn_unknown_count" => count(row ->
            row["closed_field_conclusion"] == "unknown", final_rows),
        "search_protocol" => Dict{String,Any}(
            "stage_a" => "all candidates: physical realization plus candidate-bound field and nonparticle screen",
            "stage_b" => "top proxy candidates: four-turn RK4 field-line gate",
            "stage_c" => "top field candidates: eight-turn 360-step RK4 verification"),
        "proxy_rows" => proxy_rows, "four_turn_rows" => field_rows,
        "eight_turn_rows" => final_rows, "winner" => winner,
        "device_family_routing_used" => false,
        "claim_boundary" => MODULAR_MULTIHARMONIC_COIL_V80_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
    return artifact
end
