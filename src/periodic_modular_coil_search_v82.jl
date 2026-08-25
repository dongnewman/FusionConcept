const PERIODIC_MODULAR_COIL_V82_CLAIM_BOUNDARY =
    "v82 searches closed nonplanar modular coils whose independently parameterized templates repeat over declared toroidal field periods. Every candidate receives the same physical realization, Biot-Savart proxy, and engineering screen; promoted candidates receive identical 4-turn, 16-turn, and 128-turn Poincare gates. Survival remains non-feasible until downstream plasma, particle, stability, and engineering evidence closes."

function generate_periodic_modular_binding_v82(topology::GraphNativeTopologyV69,
        structure_seed::Integer, seed::Integer)
    binding = generate_physical_parameter_binding_v71(topology, seed)
    rng = MersenneTwister(8_200_039 + 1009 * structure_seed + seed)
    binding["design_space_id"] = "periodic_nonplanar_modular_coil_space_v82"
    binding["structure_seed"] = Int(structure_seed)
    binding["periodic_modular_seed"] = Int(seed)
    binding["field_current_a"] = 10.0 ^ _v71_sample(rng,
        log10(3.0e4), log10(6.0e5))
    binding["field_turns"] = rand(rng, 4:20)
    field_periods = rand(rng, 2:5)
    templates_per_period = rand(rng, 2:4)
    binding["field_periods"] = field_periods
    binding["templates_per_period"] = templates_per_period
    binding["field_coil_count"] = field_periods * templates_per_period
    templates = Dict{String,Any}[]
    for template_index in 1:templates_per_period
        push!(templates, Dict{String,Any}(
            "template_index" => template_index,
            "toroidal_offset_fraction" => (template_index - 1) /
                templates_per_period,
            "current_scale" => _v71_sample(rng, 0.65, 1.35),
            "radius_scale" => _v71_sample(rng, 1.10, 1.45),
            "radial_harmonic_2" => _v71_sample(rng, -0.08, 0.08),
            "radial_harmonic_3" => _v71_sample(rng, -0.08, 0.08),
            "vertical_harmonic_2" => _v71_sample(rng, -0.12, 0.12),
            "out_of_plane_harmonic_1" => _v71_sample(rng, -0.35, 0.35),
            "out_of_plane_harmonic_2" => _v71_sample(rng, -0.20, 0.20),
            "shape_phase_rad" => _v71_sample(rng, 0.0, 2pi)))
    end
    binding["periodic_coil_templates"] = templates
    _graph_v69_assert_label_free(binding, "periodic_modular_binding")
    return binding
end

function _v82_periodic_field_component(port, region, binding)
    major = Float64(region["major_radius_m"])
    minor = Float64(region["minor_radius_m"])
    base_radius = minor + Float64(binding["coil_clearance_m"])
    current = Float64(binding["field_current_a"])
    turns = Int(binding["field_turns"])
    field_periods = Int(binding["field_periods"])
    templates = _v71_plain(binding["periodic_coil_templates"])
    loops = Dict{String,Any}[]
    point_count = 128
    for period_index in 0:(field_periods - 1), template in templates
        template_index = Int(template["template_index"])
        phi = 2pi * (period_index +
            Float64(template["toroidal_offset_fraction"])) / field_periods
        radial = [cos(phi), sin(phi), 0.0]
        toroidal = [-sin(phi), cos(phi), 0.0]
        vertical = [0.0, 0.0, 1.0]
        center = major .* radial
        phase = Float64(template["shape_phase_rad"])
        radius_scale = Float64(template["radius_scale"])
        centerline = Vector{Vector{Float64}}()
        for point_index in 0:point_count
            alpha = 2pi * point_index / point_count
            radial_shape = base_radius * radius_scale *
                (1.0 + Float64(template["radial_harmonic_2"]) *
                    cos(2alpha + phase) +
                    Float64(template["radial_harmonic_3"]) *
                    cos(3alpha - phase))
            vertical_shape = base_radius * radius_scale *
                (1.0 + Float64(template["vertical_harmonic_2"]) *
                    sin(2alpha + phase))
            out_of_plane = base_radius * (
                Float64(template["out_of_plane_harmonic_1"]) *
                    sin(alpha + phase) +
                Float64(template["out_of_plane_harmonic_2"]) *
                    sin(2alpha - phase))
            point = center .+ radial_shape * cos(alpha) .* radial .+
                vertical_shape * sin(alpha) .* vertical .+
                out_of_plane .* toroidal
            push!(centerline, point)
        end
        push!(loops, Dict{String,Any}(
            "loop_id" => "$(port["port_id"])_p$(period_index + 1)_t$template_index",
            "winding_role" => "periodic_nonplanar_modular_coil",
            "centerline_m" => centerline,
            "current_a" => current * Float64(template["current_scale"]),
            "turns" => turns, "field_period_index" => period_index + 1,
            "template_parameters" => template))
    end
    return Dict{String,Any}(
        "component_kind" => "finite_filament_coil_array_v1",
        "winding_basis" => "periodic_nonplanar_modular_coils_v1",
        "loops" => loops, "field_periods" => field_periods,
        "templates_per_period" => length(templates),
        "periodic_coil_templates" => templates,
        "conductor" => Dict{String,Any}(
            "material_model" => "bounded_hts_screening_proxy_v1",
            "radius_m" => Float64(binding["conductor_radius_m"]),
            "current_density_limit_a_m2" => 3.0e8,
            "allowable_magnetic_stress_pa" => 4.0e8),
        "model_fidelity" => "finite_filament_periodic_nonplanar_screening_v1")
end

function compile_periodic_modular_realization_v82(topology::GraphNativeTopologyV69,
        compilation::GraphTopologyCompilationV69; parameter_binding)
    binding = _v71_plain(parameter_binding)
    haskey(binding, "periodic_coil_templates") || throw(ArgumentError(
        "missing v82 periodic coil templates"))
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
        body = _v82_periodic_field_component(port,
            regions[String(component["region_id"])], binding)
        replacement = merge(Dict{String,Any}(
            "component_id" => component["component_id"],
            "realizer_id" => "periodic_nonplanar_modular_array_v82",
            "region_id" => component["region_id"],
            "bound_port_id" => component["bound_port_id"],
            "bound_resource_ids" => component["bound_resource_ids"]), body)
        replacement["component_hash"] = canonical_hash(replacement)
        components[index] = replacement
    end
    mappings = deepcopy(base.port_mappings)
    for mapping in mappings
        port = ports[String(mapping["port_id"])]
        String(port["port_kind"]) == "field_source" || continue
        mapping["realizer_id"] = "periodic_nonplanar_modular_array_v82"
    end
    registry_hash = canonical_hash(Dict(
        "base_registry_hash" => base.registry_hash,
        "extension_id" => "periodic_nonplanar_modular_array_v82"))
    body = Dict{String,Any}(
        "schema_version" => base.schema_version, "topology_hash" => base.topology_hash,
        "compilation_hash" => base.compilation_hash,
        "candidate_binding_hash" => base.candidate_binding_hash,
        "registry_hash" => registry_hash, "completeness" => String(base.completeness),
        "conclusion" => String(base.conclusion),
        "classification_code" => "periodic_modular_realization_requires_simulation",
        "geometry" => base.geometry, "components" => components,
        "port_mappings" => mappings, "dependency_mappings" => base.dependency_mappings,
        "missing_requirements" => base.missing_requirements,
        "claim_boundary" => PERIODIC_MODULAR_COIL_V82_CLAIM_BOUNDARY)
    return PhysicalDeviceRealizationV71(base.schema_version, base.topology_hash,
        base.compilation_hash, base.candidate_binding_hash, registry_hash,
        base.completeness, base.conclusion,
        "periodic_modular_realization_requires_simulation", base.geometry,
        components, mappings, base.dependency_mappings, base.missing_requirements,
        PERIODIC_MODULAR_COIL_V82_CLAIM_BOUNDARY, canonical_hash(body))
end

function _v82_trace_rank(row)
    escape = Bool(row["any_trace_escaped"]) ? 1 : 0
    completed = Bool(row["all_traces_completed"]) ? 0 : 1
    transform = Float64(row["minimum_absolute_rotational_transform"])
    turns = Float64(row["minimum_completed_toroidal_turns"])
    excursion = Float64(row["maximum_normalized_minor_radius_excursion"])
    return (escape, completed, transform >= 0.02 ? 0 : 1, -turns,
        excursion, -transform, Int(row["periodic_modular_seed"]))
end

function _v82_trace_row(seed, proxy_row, gate)
    evidence = gate.field_line_evidence
    traces = evidence["traces"]
    return merge(deepcopy(proxy_row), Dict{String,Any}(
        "periodic_modular_seed" => Int(seed),
        "closed_field_conclusion" => String(gate.conclusion),
        "classification_code" => gate.classification_code,
        "any_trace_escaped" => Bool(evidence["any_trace_escaped"]),
        "all_traces_completed" => Bool(evidence["all_traces_completed"]),
        "minimum_completed_toroidal_turns" => minimum(Float64(
            trace["toroidal_turns"]) for trace in traces),
        "minimum_absolute_rotational_transform" => Float64(
            evidence["minimum_absolute_rotational_transform"]),
        "maximum_normalized_minor_radius_excursion" => Float64(
            evidence["maximum_normalized_minor_radius_excursion"])))
end

function run_periodic_modular_search_v82(structure_seed::Integer,
        first_seed::Integer, last_seed::Integer;
        shortlist_count::Integer = 256, longlist_count::Integer = 16,
        poincare_count::Integer = 4,
        output_path::Union{Nothing,AbstractString} = nothing,
        progress_interval::Integer = 500)
    topology = generate_graph_native_topology_v69(structure_seed)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    candidate_count = Int(last_seed - first_seed + 1)
    proxy_rows = Vector{Dict{String,Any}}(undef, candidate_count)
    completed_count = Threads.Atomic{Int}(0)
    Threads.@threads for offset in 1:candidate_count
        seed = Int(first_seed + offset - 1)
        try
            binding = generate_periodic_modular_binding_v82(topology, structure_seed, seed)
            realization = compile_periodic_modular_realization_v82(topology,
                compilation; parameter_binding = binding)
            screen = screen_physical_device_v71(realization, binding;
                particle_count = 1, step_count = 1, required_transit_fraction = 1.0)
            proxy = _v80_fast_field_proxy(realization)
            nonparticle_ids = ("finite_field", "dt_power_balance_proxy",
                "conductor_current_density", "magnetic_stress", "heat_rejection_capacity")
            row = Dict{String,Any}(
                "periodic_modular_seed" => seed,
                "candidate_binding_hash" => realization.candidate_binding_hash,
                "realization_hash" => realization.realization_hash,
                "nonparticle_pass_count" => count(id ->
                    get(screen.gate_statuses, id, "unknown") == "pass", nonparticle_ids),
                "median_transform_proxy" => proxy["median_transform_proxy"],
                "minimum_field_t" => proxy["minimum_field_t"],
                "maximum_field_t" => proxy["maximum_field_t"],
                "relative_field_ripple" => proxy["relative_field_ripple"],
                "field_periods" => binding["field_periods"],
                "templates_per_period" => binding["templates_per_period"])
            row["modular_seed"] = seed
            row["row_hash"] = canonical_hash(row)
            proxy_rows[offset] = row
        catch error
            proxy_rows[offset] = Dict{String,Any}(
                "periodic_modular_seed" => seed, "status" => "exception",
                "exception_type" => String(nameof(typeof(error))),
                "exception_message" => sprint(showerror, error))
        end
        completed = Threads.atomic_add!(completed_count, 1) + 1
        if progress_interval > 0 && completed % progress_interval == 0
            println("v82_proxy_progress=", completed, "/", candidate_count)
            flush(stdout)
        end
    end
    exception_count = count(row -> haskey(row, "status"), proxy_rows)
    valid = [row for row in proxy_rows if !haskey(row, "status")]
    sort!(valid; by = _v80_proxy_rank)
    shortlist = valid[1:min(Int(shortlist_count), length(valid))]
    four_rows = Dict{String,Any}[]
    for proxy_row in shortlist
        seed = Int(proxy_row["periodic_modular_seed"])
        binding = generate_periodic_modular_binding_v82(topology, structure_seed, seed)
        realization = compile_periodic_modular_realization_v82(topology,
            compilation; parameter_binding = binding)
        screen = screen_physical_device_v71(realization, binding;
            particle_count = 1, step_count = 1, required_transit_fraction = 1.0)
        gate = evaluate_closed_field_transport_gate_v73(realization, screen, binding;
            target_toroidal_turns = 4.0, steps_per_turn = 180)
        push!(four_rows, _v82_trace_row(seed, proxy_row, gate))
    end
    sort!(four_rows; by = _v82_trace_rank)
    longlist = four_rows[1:min(Int(longlist_count), length(four_rows))]
    sixteen_rows = Dict{String,Any}[]
    for row4 in longlist
        seed = Int(row4["periodic_modular_seed"])
        binding = generate_periodic_modular_binding_v82(topology, structure_seed, seed)
        realization = compile_periodic_modular_realization_v82(topology,
            compilation; parameter_binding = binding)
        screen = screen_physical_device_v71(realization, binding;
            particle_count = 1, step_count = 1, required_transit_fraction = 1.0)
        gate = evaluate_closed_field_transport_gate_v73(realization, screen, binding;
            target_toroidal_turns = 16.0, steps_per_turn = 180)
        push!(sixteen_rows, _v82_trace_row(seed, row4, gate))
    end
    sort!(sixteen_rows; by = _v82_trace_rank)
    poincare_candidates = sixteen_rows[1:min(Int(poincare_count), length(sixteen_rows))]
    poincare_rows = Dict{String,Any}[]
    full = Dict{Int,Dict{String,Any}}()
    for row16 in poincare_candidates
        seed = Int(row16["periodic_modular_seed"])
        binding = generate_periodic_modular_binding_v82(topology, structure_seed, seed)
        realization = compile_periodic_modular_realization_v82(topology,
            compilation; parameter_binding = binding)
        screen = screen_physical_device_v71(realization, binding;
            particle_count = 1, step_count = 1, required_transit_fraction = 1.0)
        gate = evaluate_poincare_flux_surface_gate_v81(realization, screen, binding;
            target_toroidal_turns = 128, steps_per_turn = 180)
        evidence = gate.poincare_evidence
        row = Dict{String,Any}(
            "modular_seed" => seed, "periodic_modular_seed" => seed,
            "conclusion" => String(gate.conclusion),
            "classification_code" => gate.classification_code,
            "any_trace_escaped" => evidence["any_trace_escaped"],
            "minimum_crossing_count" => minimum(Int(trace["crossing_count"])
                for trace in evidence["traces"]),
            "maximum_crossing_count" => maximum(Int(trace["crossing_count"])
                for trace in evidence["traces"]),
            "minimum_absolute_rotational_transform" =>
                evidence["minimum_absolute_rotational_transform"],
            "maximum_fourier_residual" => evidence["maximum_fourier_residual"],
            "maximum_repeated_bin_radial_spread" =>
                evidence["maximum_repeated_bin_radial_spread"],
            "maximum_secular_residual_drift_per_turn" =>
                evidence["maximum_secular_residual_drift_per_turn"],
            "surface_ordering_fraction" => evidence["surface_ordering_fraction"],
            "minimum_fitted_surface_gap" => evidence["minimum_fitted_surface_gap"])
        push!(poincare_rows, row)
        full[seed] = Dict{String,Any}(
            "row" => row, "parameter_binding" => binding,
            "topology" => _s70_topology_to_dict(topology),
            "realization" => physical_device_realization_to_dict_v71(realization),
            "screen" => physical_device_screen_to_dict_v71(screen),
            "poincare_gate" => poincare_flux_surface_gate_to_dict_v81(gate))
    end
    sort!(poincare_rows; by = _v81_frontier_rank)
    winner = isempty(poincare_rows) ? nothing :
        full[Int(poincare_rows[1]["periodic_modular_seed"])]
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "status" => exception_count == 0 && winner !== nothing ? "complete" : "incomplete",
        "searched_candidate_count" => candidate_count,
        "uncaught_exception_count" => exception_count,
        "shortlist_count" => length(shortlist),
        "sixteen_turn_count" => length(longlist),
        "poincare_candidate_count" => length(poincare_candidates),
        "poincare_unknown_count" => count(row -> row["conclusion"] == "unknown",
            poincare_rows),
        "proxy_rows" => proxy_rows, "four_turn_rows" => four_rows,
        "sixteen_turn_rows" => sixteen_rows,
        "poincare_rows" => poincare_rows, "winner" => winner,
        "device_family_routing_used" => false,
        "claim_boundary" => PERIODIC_MODULAR_COIL_V82_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
    return artifact
end
