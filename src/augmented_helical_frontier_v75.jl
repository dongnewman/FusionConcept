const AUGMENTED_HELICAL_FRONTIER_V75_CLAIM_BOUNDARY =
    "v75 performs a candidate-bound heat-rejection refinement inside the declared physical design bounds, then reruns the complete v71 screen and v73 closed-field gate. A surviving result remains incomplete/unknown until collisional kinetic transport, finite-pressure equilibrium, stability, and full plant closure are demonstrated."

function refine_augmented_helical_frontier_v75(structure_seed::Integer,
        parent_variant_seed::Integer;
        cooling_capacity_factor::Real = 1.20,
        maximum_cooling_capacity_w::Real = 2.0e9,
        particle_count::Integer = 64, step_count::Integer = 3000,
        required_transit_fraction::Real = 1.0,
        target_toroidal_turns::Real = 2.0,
        field_steps_per_turn::Integer = 360,
        output_path::Union{Nothing,AbstractString} = nothing)
    cooling_capacity_factor > 1 || throw(ArgumentError(
        "v75 cooling capacity factor must exceed one"))
    topology = generate_graph_native_topology_v69(structure_seed)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    binding = generate_augmented_helical_parameter_binding_v74(topology,
        structure_seed, parent_variant_seed)
    parent_realization = compile_augmented_helical_realization_v74(topology,
        compilation; parameter_binding = binding)
    parent_screen = screen_physical_device_v71(parent_realization, binding;
        particle_count = 1, step_count = 1,
        required_transit_fraction = required_transit_fraction)
    required_thermal_load = Float64(parent_screen.engineering_evidence[
        "screened_thermal_load_w"])
    requested_capacity = cooling_capacity_factor * required_thermal_load
    if requested_capacity > maximum_cooling_capacity_w
        artifact = Dict{String,Any}(
            "schema_version" => "1.0.0", "status" => "incomplete",
            "conclusion" => "unknown", "classification_code" =>
                "cooling_refinement_exceeds_declared_design_bound",
            "structure_seed" => Int(structure_seed),
            "parent_variant_seed" => Int(parent_variant_seed),
            "required_thermal_load_w" => required_thermal_load,
            "requested_cooling_capacity_w" => requested_capacity,
            "maximum_cooling_capacity_w" => Float64(maximum_cooling_capacity_w),
            "claim_boundary" => AUGMENTED_HELICAL_FRONTIER_V75_CLAIM_BOUNDARY)
        artifact["result_hash"] = canonical_hash(artifact)
        output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
        return artifact
    end
    parent_binding_hash = canonical_hash(binding)
    binding["parent_candidate_binding_hash"] = parent_binding_hash
    binding["refinement_id"] = "candidate_bound_heat_rejection_capacity_v75"
    binding["cooling_capacity_w"] = requested_capacity
    binding["cooling_capacity_design_bound_w"] = Float64(maximum_cooling_capacity_w)
    realization = compile_augmented_helical_realization_v74(topology, compilation;
        parameter_binding = binding)
    screen = screen_physical_device_v71(realization, binding;
        particle_count = particle_count, step_count = step_count,
        required_transit_fraction = required_transit_fraction)
    closed_field = evaluate_closed_field_transport_gate_v73(realization, screen,
        binding; target_toroidal_turns = target_toroidal_turns,
        steps_per_turn = field_steps_per_turn)
    screen_pass = screen.conclusion == :screen_pass
    closed_not_failed = closed_field.conclusion in (:unknown, :unsupported)
    conclusion = screen_pass && closed_not_failed ? "frontier_unknown" :
        (screen.conclusion == :screen_fail || closed_field.conclusion == :fail ?
            "screen_fail" : "unknown")
    status = conclusion == "screen_fail" ? "complete" : "incomplete"
    classification = conclusion == "frontier_unknown" ?
        "augmented_helical_frontier_requires_kinetic_transport_and_stability" :
        conclusion == "screen_fail" ? "refined_augmented_helical_candidate_rejected" :
        "refined_augmented_helical_candidate_evidence_incomplete"
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0", "status" => status,
        "conclusion" => conclusion, "classification_code" => classification,
        "structure_seed" => Int(structure_seed),
        "parent_variant_seed" => Int(parent_variant_seed),
        "parent_candidate_binding_hash" => parent_binding_hash,
        "required_thermal_load_w" => required_thermal_load,
        "refined_cooling_capacity_w" => requested_capacity,
        "maximum_cooling_capacity_w" => Float64(maximum_cooling_capacity_w),
        "parameter_binding" => binding,
        "topology" => _s70_topology_to_dict(topology),
        "realization" => physical_device_realization_to_dict_v71(realization),
        "screen" => physical_device_screen_to_dict_v71(screen),
        "closed_field_gate" => closed_field_transport_gate_to_dict_v73(closed_field),
        "device_family_routing_used" => false,
        "claim_boundary" => AUGMENTED_HELICAL_FRONTIER_V75_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
    return artifact
end
