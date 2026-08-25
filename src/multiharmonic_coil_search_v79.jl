const MULTIHARMONIC_COIL_SEARCH_V79_CLAIM_BOUNDARY =
    "v79 searches bounded multi-harmonic finite-filament winding geometry and current imbalance around sealed v77 parents. Four-turn field-line survival remains transport_unknown and grants no finite-pressure, stability, particle, engineering, or device-feasibility claim."

const _V79_PARENT_LOCAL_SEEDS = (2, 8, 24, 43, 45, 48, 57)

function generate_multiharmonic_coil_binding_v79(topology::GraphNativeTopologyV69,
        structure_seed::Integer, parent_variant_seed::Integer,
        multiharmonic_seed::Integer)
    rng = MersenneTwister(7_900_021 + 1009 * structure_seed + multiharmonic_seed)
    parent_local_seed = rand(rng, _V79_PARENT_LOCAL_SEEDS)
    binding = generate_local_helical_flux_binding_v77(topology, structure_seed,
        parent_variant_seed, parent_local_seed)
    parent_hash = canonical_hash(binding)
    binding["design_space_id"] = "bounded_multiharmonic_coil_space_v79"
    binding["v77_parent_local_seed"] = parent_local_seed
    binding["v77_parent_candidate_binding_hash"] = parent_hash
    binding["multiharmonic_seed"] = Int(multiharmonic_seed)
    binding["helical_current_fraction"] *= 10.0 ^ _v71_sample(rng,
        log10(0.75), log10(1.8))
    binding["helical_radial_scale"] = clamp(
        binding["helical_radial_scale"] + _v71_sample(rng, -0.12, 0.16),
        0.68, 1.45)
    binding["helical_phase_modulation_rad"] = _v71_sample(rng, -0.60, 0.60)
    binding["helical_radial_harmonic_fraction"] = _v71_sample(rng, -0.20, 0.20)
    binding["helical_vertical_harmonic_fraction"] = _v71_sample(rng, -0.20, 0.20)
    binding["helical_harmonic_phase_rad"] = _v71_sample(rng, 0.0, 2pi)
    binding["helical_harmonic_toroidal_mode"] = rand(rng, 1:4)
    binding["helical_winding_current_imbalance"] = _v71_sample(rng, -0.30, 0.30)
    _graph_v69_assert_label_free(binding, "multiharmonic_coil_binding")
    return binding
end

function run_multiharmonic_coil_search_v79(structure_seed::Integer,
        parent_variant_seed::Integer, first_seed::Integer, last_seed::Integer;
        output_path::Union{Nothing,AbstractString} = nothing,
        target_toroidal_turns::Real = 4.0, steps_per_turn::Integer = 180)
    1 <= first_seed <= last_seed || throw(ArgumentError("invalid v79 seed range"))
    topology = generate_graph_native_topology_v69(structure_seed)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    rows = Dict{String,Any}[]
    best = nothing
    exception_count = 0
    for seed in first_seed:last_seed
        try
            binding = generate_multiharmonic_coil_binding_v79(topology,
                structure_seed, parent_variant_seed, seed)
            realization = compile_augmented_helical_realization_v74(topology,
                compilation; parameter_binding = binding)
            screen = screen_physical_device_v71(realization, binding;
                particle_count = 1, step_count = 1, required_transit_fraction = 1.0)
            gate = evaluate_closed_field_transport_gate_v73(realization, screen,
                binding; target_toroidal_turns = target_toroidal_turns,
                steps_per_turn = steps_per_turn)
            lines = gate.field_line_evidence
            row = Dict{String,Any}(
                "multiharmonic_seed" => Int(seed),
                "parent_local_seed" => binding["v77_parent_local_seed"],
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
                "helical_phase_modulation_rad" =>
                    binding["helical_phase_modulation_rad"],
                "helical_radial_harmonic_fraction" =>
                    binding["helical_radial_harmonic_fraction"],
                "helical_vertical_harmonic_fraction" =>
                    binding["helical_vertical_harmonic_fraction"],
                "helical_harmonic_phase_rad" => binding["helical_harmonic_phase_rad"],
                "helical_harmonic_toroidal_mode" =>
                    binding["helical_harmonic_toroidal_mode"],
                "helical_winding_current_imbalance" =>
                    binding["helical_winding_current_imbalance"])
            row["row_hash"] = canonical_hash(row)
            push!(rows, row)
            rank_row = merge(row, Dict("local_variant_seed" => seed))
            if best === nothing || _v77_rank(rank_row) < best["rank"]
                best = Dict{String,Any}(
                    "rank" => _v77_rank(rank_row), "row" => row,
                    "parameter_binding" => binding,
                    "topology" => _s70_topology_to_dict(topology),
                    "realization" => physical_device_realization_to_dict_v71(realization),
                    "screen" => physical_device_screen_to_dict_v71(screen),
                    "closed_field_gate" => closed_field_transport_gate_to_dict_v73(gate))
            end
        catch error
            exception_count += 1
            push!(rows, Dict{String,Any}(
                "multiharmonic_seed" => Int(seed), "status" => "exception",
                "exception_type" => String(nameof(typeof(error)))))
        end
    end
    best === nothing || delete!(best, "rank")
    sort!(rows; by = row -> Int(row["multiharmonic_seed"]))
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "status" => exception_count == 0 && best !== nothing ? "complete" : "incomplete",
        "structure_seed" => Int(structure_seed),
        "parent_variant_seed" => Int(parent_variant_seed),
        "first_multiharmonic_seed" => Int(first_seed),
        "last_multiharmonic_seed" => Int(last_seed),
        "candidate_count" => Int(last_seed - first_seed + 1),
        "uncaught_exception_count" => exception_count,
        "four_turn_unknown_count" => count(row -> get(row,
            "closed_field_conclusion", "") == "unknown", rows),
        "field_line_escape_count" => count(row -> get(row,
            "field_line_escape", true) === true, rows),
        "winner_selection_method" =>
            "four_turn_disposition_escape_transform_excursion_v1",
        "winner" => best, "candidate_rows" => rows,
        "device_family_routing_used" => false,
        "claim_boundary" => MULTIHARMONIC_COIL_SEARCH_V79_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
    return artifact
end
