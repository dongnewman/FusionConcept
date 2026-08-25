const PERIODIC_COIL_REGULARIZATION_V83_CLAIM_BOUNDARY =
    "v83 regularizes the sealed v82 frontier by independently scaling nonplanar shape, template-current spread, and template-radius spread, then applies common 8-turn, 32-turn, and 128-turn Poincare gates. It is an evidence-driven physical optimization, not feasibility credit."

function generate_regularized_periodic_binding_v83(topology::GraphNativeTopologyV69,
        deformation_scale::Real, current_spread_scale::Real,
        radius_spread_scale::Real)
    binding = generate_periodic_modular_binding_v82(topology, 72, 7085)
    parent_hash = canonical_hash(binding)
    templates = _v71_plain(binding["periodic_coil_templates"])
    mean_radius = sum(Float64(item["radius_scale"]) for item in templates) /
        length(templates)
    for item in templates
        for key in ("radial_harmonic_2", "radial_harmonic_3",
                "vertical_harmonic_2", "out_of_plane_harmonic_1",
                "out_of_plane_harmonic_2")
            item[key] = Float64(item[key]) * Float64(deformation_scale)
        end
        item["current_scale"] = 1.0 + Float64(current_spread_scale) *
            (Float64(item["current_scale"]) - 1.0)
        item["radius_scale"] = mean_radius + Float64(radius_spread_scale) *
            (Float64(item["radius_scale"]) - mean_radius)
    end
    binding["design_space_id"] = "periodic_coil_regularization_space_v83"
    binding["v82_parent_candidate_binding_hash"] = parent_hash
    binding["deformation_scale"] = Float64(deformation_scale)
    binding["current_spread_scale"] = Float64(current_spread_scale)
    binding["radius_spread_scale"] = Float64(radius_spread_scale)
    binding["periodic_coil_templates"] = templates
    _graph_v69_assert_label_free(binding, "periodic_coil_regularization_binding")
    return binding
end

function _v83_key(deformation, current_spread, radius_spread)
    return "d$(round(Float64(deformation); digits = 3))_" *
        "c$(round(Float64(current_spread); digits = 3))_" *
        "r$(round(Float64(radius_spread); digits = 3))"
end

function run_periodic_coil_regularization_v83(;
        deformation_scales = collect(0.35:0.05:1.05),
        current_spread_scales = collect(0.0:0.2:1.0),
        radius_spread_scales = [0.0, 0.5, 1.0],
        output_path::Union{Nothing,AbstractString} = nothing)
    topology = generate_graph_native_topology_v69(72)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    combinations = [(Float64(d), Float64(c), Float64(r))
        for d in deformation_scales for c in current_spread_scales
        for r in radius_spread_scales]
    eight_rows = Vector{Dict{String,Any}}(undef, length(combinations))
    completed_count = Threads.Atomic{Int}(0)
    Threads.@threads for index in eachindex(combinations)
        deformation, current_spread, radius_spread = combinations[index]
        binding = generate_regularized_periodic_binding_v83(topology,
            deformation, current_spread, radius_spread)
        realization = compile_periodic_modular_realization_v82(topology,
            compilation; parameter_binding = binding)
        screen = screen_physical_device_v71(realization, binding;
            particle_count = 1, step_count = 1, required_transit_fraction = 1.0)
        gate = evaluate_closed_field_transport_gate_v73(realization, screen, binding;
            target_toroidal_turns = 8.0, steps_per_turn = 180)
        row = _v82_trace_row(index, Dict{String,Any}(
            "variant_key" => _v83_key(deformation, current_spread, radius_spread),
            "deformation_scale" => deformation,
            "current_spread_scale" => current_spread,
            "radius_spread_scale" => radius_spread), gate)
        row["periodic_modular_seed"] = index
        eight_rows[index] = row
        completed = Threads.atomic_add!(completed_count, 1) + 1
        if completed % 25 == 0
            println("v83_eight_turn_progress=", completed, "/", length(combinations))
            flush(stdout)
        end
    end
    sort!(eight_rows; by = _v82_trace_rank)
    thirtytwo_candidates = eight_rows[1:min(32, length(eight_rows))]
    thirtytwo_rows = Dict{String,Any}[]
    bindings = Dict{String,Dict{String,Any}}()
    for row8 in thirtytwo_candidates
        deformation = Float64(row8["deformation_scale"])
        current_spread = Float64(row8["current_spread_scale"])
        radius_spread = Float64(row8["radius_spread_scale"])
        binding = generate_regularized_periodic_binding_v83(topology,
            deformation, current_spread, radius_spread)
        realization = compile_periodic_modular_realization_v82(topology,
            compilation; parameter_binding = binding)
        screen = screen_physical_device_v71(realization, binding;
            particle_count = 1, step_count = 1, required_transit_fraction = 1.0)
        gate = evaluate_closed_field_transport_gate_v73(realization, screen, binding;
            target_toroidal_turns = 32.0, steps_per_turn = 180)
        row = _v82_trace_row(Int(row8["periodic_modular_seed"]), row8, gate)
        push!(thirtytwo_rows, row)
        bindings[String(row["variant_key"])] = binding
    end
    sort!(thirtytwo_rows; by = _v82_trace_rank)
    poincare_candidates = thirtytwo_rows[1:min(8, length(thirtytwo_rows))]
    poincare_rows = Dict{String,Any}[]
    full = Dict{String,Dict{String,Any}}()
    for row32 in poincare_candidates
        key = String(row32["variant_key"])
        binding = bindings[key]
        realization = compile_periodic_modular_realization_v82(topology,
            compilation; parameter_binding = binding)
        screen = screen_physical_device_v71(realization, binding;
            particle_count = 1, step_count = 1, required_transit_fraction = 1.0)
        gate = evaluate_poincare_flux_surface_gate_v81(realization, screen, binding;
            target_toroidal_turns = 128, steps_per_turn = 180)
        evidence = gate.poincare_evidence
        row = Dict{String,Any}(
            "variant_key" => key,
            "modular_seed" => Int(row32["periodic_modular_seed"]),
            "deformation_scale" => row32["deformation_scale"],
            "current_spread_scale" => row32["current_spread_scale"],
            "radius_spread_scale" => row32["radius_spread_scale"],
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
        full[key] = Dict{String,Any}(
            "row" => row, "parameter_binding" => binding,
            "topology" => _s70_topology_to_dict(topology),
            "realization" => physical_device_realization_to_dict_v71(realization),
            "screen" => physical_device_screen_to_dict_v71(screen),
            "poincare_gate" => poincare_flux_surface_gate_to_dict_v81(gate))
    end
    sort!(poincare_rows; by = _v81_frontier_rank)
    winner = isempty(poincare_rows) ? nothing : full[String(poincare_rows[1]["variant_key"])]
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0", "status" => winner === nothing ?
            "incomplete" : "complete",
        "grid_candidate_count" => length(combinations),
        "thirtytwo_turn_candidate_count" => length(thirtytwo_candidates),
        "poincare_candidate_count" => length(poincare_candidates),
        "poincare_unknown_count" => count(row -> row["conclusion"] == "unknown",
            poincare_rows),
        "eight_turn_rows" => eight_rows,
        "thirtytwo_turn_rows" => thirtytwo_rows,
        "poincare_rows" => poincare_rows, "winner" => winner,
        "device_family_routing_used" => false,
        "claim_boundary" => PERIODIC_COIL_REGULARIZATION_V83_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
    return artifact
end
