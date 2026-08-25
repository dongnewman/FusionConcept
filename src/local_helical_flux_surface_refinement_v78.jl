const LOCAL_HELICAL_FLUX_SURFACE_V78_CLAIM_BOUNDARY =
    "v78 refines two continuous physical winding parameters around a sealed v77 parent and ranks candidate-bound four-turn field-line evidence. It does not grant plasma, transport, stability, or engineering feasibility credit."

function generate_local_helical_refinement_binding_v78(
        topology::GraphNativeTopologyV69, structure_seed::Integer,
        parent_variant_seed::Integer, parent_local_seed::Integer,
        current_multiplier::Real, radial_scale_offset::Real)
    binding = generate_local_helical_flux_binding_v77(topology, structure_seed,
        parent_variant_seed, parent_local_seed)
    parent_hash = canonical_hash(binding)
    binding["design_space_id"] = "local_helical_flux_surface_refinement_v78"
    binding["v77_parent_candidate_binding_hash"] = parent_hash
    binding["v77_parent_local_seed"] = Int(parent_local_seed)
    binding["helical_current_fraction"] = Float64(
        binding["helical_current_fraction"]) * Float64(current_multiplier)
    binding["helical_radial_scale"] = Float64(
        binding["helical_radial_scale"]) + Float64(radial_scale_offset)
    binding["v78_current_multiplier"] = Float64(current_multiplier)
    binding["v78_radial_scale_offset"] = Float64(radial_scale_offset)
    0.001 <= binding["helical_current_fraction"] <= 0.2 ||
        throw(ArgumentError("v78 helical current fraction outside bounded space"))
    0.6 <= binding["helical_radial_scale"] <= 1.5 ||
        throw(ArgumentError("v78 helical radial scale outside bounded space"))
    _graph_v69_assert_label_free(binding, "local_helical_refinement_binding")
    return binding
end

function run_local_helical_flux_surface_refinement_v78(structure_seed::Integer,
        parent_variant_seed::Integer, parent_local_seed::Integer;
        current_multipliers = collect(0.95:0.025:1.20),
        radial_scale_offsets = collect(-0.08:0.02:0.08),
        output_path::Union{Nothing,AbstractString} = nothing,
        target_toroidal_turns::Real = 4.0, steps_per_turn::Integer = 180)
    topology = generate_graph_native_topology_v69(structure_seed)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    rows = Dict{String,Any}[]
    best = nothing
    exception_count = 0
    for current_multiplier in current_multipliers,
            radial_scale_offset in radial_scale_offsets
        try
            binding = generate_local_helical_refinement_binding_v78(topology,
                structure_seed, parent_variant_seed, parent_local_seed,
                current_multiplier, radial_scale_offset)
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
                "current_multiplier" => Float64(current_multiplier),
                "radial_scale_offset" => Float64(radial_scale_offset),
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
                "helical_radial_scale" => binding["helical_radial_scale"])
            row["row_hash"] = canonical_hash(row)
            push!(rows, row)
            rank_row = merge(row, Dict("local_variant_seed" => length(rows)))
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
                "current_multiplier" => Float64(current_multiplier),
                "radial_scale_offset" => Float64(radial_scale_offset),
                "status" => "exception",
                "exception_type" => String(nameof(typeof(error)))))
        end
    end
    if best !== nothing
        delete!(best, "rank")
    end
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0", "status" =>
            exception_count == 0 && best !== nothing ? "complete" : "incomplete",
        "structure_seed" => Int(structure_seed),
        "parent_variant_seed" => Int(parent_variant_seed),
        "parent_local_seed" => Int(parent_local_seed),
        "grid_candidate_count" => length(current_multipliers) *
            length(radial_scale_offsets),
        "uncaught_exception_count" => exception_count,
        "four_turn_unknown_count" => count(row -> get(row,
            "closed_field_conclusion", "") == "unknown", rows),
        "field_line_escape_count" => count(row -> get(row,
            "field_line_escape", true) === true, rows),
        "winner_selection_method" =>
            "four_turn_disposition_escape_transform_excursion_v1",
        "winner" => best, "candidate_rows" => rows,
        "device_family_routing_used" => false,
        "claim_boundary" => LOCAL_HELICAL_FLUX_SURFACE_V78_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
    return artifact
end
