const LOCAL_HELICAL_FLUX_SURFACE_V77_CLAIM_BOUNDARY =
    "v77 locally searches physical helical-winding genes around a sealed parent candidate and ranks four-turn candidate-bound field-line evidence. It does not grant plasma, transport, stability, or engineering feasibility credit."

function generate_local_helical_flux_binding_v77(topology::GraphNativeTopologyV69,
        structure_seed::Integer, parent_variant_seed::Integer,
        local_variant_seed::Integer)
    binding = generate_augmented_helical_parameter_binding_v74(topology,
        structure_seed, parent_variant_seed)
    parent_hash = canonical_hash(binding)
    rng = MersenneTwister(7_700_019 + 1009 * parent_variant_seed + local_variant_seed)
    binding["design_space_id"] = "local_helical_flux_surface_space_v77"
    binding["parent_candidate_binding_hash"] = parent_hash
    binding["local_variant_seed"] = Int(local_variant_seed)
    binding["helical_current_fraction"] = 10.0 ^ _v71_sample(rng,
        log10(0.006), log10(0.09))
    binding["helical_radial_scale"] = _v71_sample(rng, 0.72, 1.32)
    binding["helical_poloidal_periods"] = rand(rng, 2:4)
    binding["helical_winding_count"] = rand(rng, 2:6)
    binding["helical_current_pattern"] = rand(rng, ("co_directional", "alternating"))
    binding["field_coil_count"] = rand(rng, 20:2:32)
    _graph_v69_assert_label_free(binding, "local_helical_flux_binding")
    return binding
end

function _v77_rank(row)
    conclusion_rank = row["closed_field_conclusion"] == "unknown" ? 0 : 1
    escaped_rank = Bool(row["field_line_escape"]) ? 1 : 0
    transform = Float64(row["minimum_absolute_rotational_transform"])
    excursion = Float64(row["maximum_normalized_minor_radius_excursion"])
    return (conclusion_rank, escaped_rank, transform >= 0.02 ? 0 : 1,
        excursion, -transform, Int(row["local_variant_seed"]))
end

function run_local_helical_flux_surface_search_v77(structure_seed::Integer,
        parent_variant_seed::Integer, first_local_seed::Integer,
        last_local_seed::Integer;
        output_path::Union{Nothing,AbstractString} = nothing,
        target_toroidal_turns::Real = 4.0, steps_per_turn::Integer = 180)
    1 <= first_local_seed <= last_local_seed || throw(ArgumentError(
        "invalid v77 local seed range"))
    topology = generate_graph_native_topology_v69(structure_seed)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    rows = Dict{String,Any}[]; best = nothing; exception_count = 0
    for local_seed in first_local_seed:last_local_seed
        try
            binding = generate_local_helical_flux_binding_v77(topology,
                structure_seed, parent_variant_seed, local_seed)
            realization = compile_augmented_helical_realization_v74(topology,
                compilation; parameter_binding = binding)
            screen = screen_physical_device_v71(realization, binding;
                particle_count = 1, step_count = 1,
                required_transit_fraction = 1.0)
            gate = evaluate_closed_field_transport_gate_v73(realization, screen,
                binding; target_toroidal_turns = target_toroidal_turns,
                steps_per_turn = steps_per_turn)
            lines = gate.field_line_evidence
            row = Dict{String,Any}(
                "local_variant_seed" => Int(local_seed),
                "candidate_binding_hash" => realization.candidate_binding_hash,
                "realization_hash" => realization.realization_hash,
                "closed_field_evidence_hash" => gate.evidence_hash,
                "closed_field_conclusion" => String(gate.conclusion),
                "classification_code" => gate.classification_code,
                "field_line_escape" => Bool(get(lines, "any_trace_escaped", true)),
                "minimum_absolute_rotational_transform" => Float64(get(lines,
                    "minimum_absolute_rotational_transform", 0.0)),
                "maximum_normalized_minor_radius_excursion" => Float64(get(lines,
                    "maximum_normalized_minor_radius_excursion", Inf)),
                "helical_current_fraction" => binding["helical_current_fraction"],
                "helical_radial_scale" => binding["helical_radial_scale"],
                "helical_poloidal_periods" => binding["helical_poloidal_periods"],
                "helical_winding_count" => binding["helical_winding_count"],
                "helical_current_pattern" => binding["helical_current_pattern"],
                "base_coil_count" => binding["field_coil_count"])
            row["row_hash"] = canonical_hash(row); push!(rows, row)
            if best === nothing || _v77_rank(row) < _v77_rank(best["row"])
                best = Dict{String,Any}(
                    "row" => row, "parameter_binding" => binding,
                    "topology" => _s70_topology_to_dict(topology),
                    "realization" => physical_device_realization_to_dict_v71(realization),
                    "screen" => physical_device_screen_to_dict_v71(screen),
                    "closed_field_gate" => closed_field_transport_gate_to_dict_v73(gate))
            end
        catch error
            exception_count += 1
            push!(rows, Dict{String,Any}(
                "local_variant_seed" => Int(local_seed), "status" => "exception",
                "exception_type" => String(nameof(typeof(error)))))
        end
    end
    sort!(rows; by = row -> Int(row["local_variant_seed"]))
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "status" => exception_count == 0 && best !== nothing ? "complete" : "incomplete",
        "structure_seed" => Int(structure_seed),
        "parent_variant_seed" => Int(parent_variant_seed),
        "first_local_seed" => Int(first_local_seed),
        "last_local_seed" => Int(last_local_seed),
        "local_variant_count" => Int(last_local_seed - first_local_seed + 1),
        "uncaught_exception_count" => exception_count,
        "four_turn_unknown_count" => count(row -> get(row,
            "closed_field_conclusion", "") == "unknown", rows),
        "field_line_escape_count" => count(row -> get(row,
            "field_line_escape", true) === true, rows),
        "winner_selection_method" =>
            "four_turn_disposition_escape_transform_excursion_v1",
        "winner" => best, "candidate_rows" => rows,
        "device_family_routing_used" => false,
        "claim_boundary" => LOCAL_HELICAL_FLUX_SURFACE_V77_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
    return artifact
end
