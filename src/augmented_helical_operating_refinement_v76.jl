const AUGMENTED_HELICAL_OPERATING_V76_CLAIM_BOUNDARY =
    "v76 refines density and heat-rejection capacity inside the declared candidate design bounds to reach a target low-fidelity plasma-gain proxy. It then requires a longer closed-field trace before particle refinement. Surviving remains unknown, not feasible, without kinetic transport, finite-pressure equilibrium, stability, and full plant evidence."

function refine_augmented_helical_operating_point_v76(structure_seed::Integer,
        parent_variant_seed::Integer;
        target_plasma_gain_proxy::Real = 1.20,
        cooling_capacity_factor::Real = 1.20,
        maximum_cooling_capacity_w::Real = 2.0e9,
        particle_count::Integer = 64, step_count::Integer = 6000,
        required_transit_fraction::Real = 1.0,
        target_toroidal_turns::Real = 4.0,
        field_steps_per_turn::Integer = 360,
        output_path::Union{Nothing,AbstractString} = nothing)
    target_plasma_gain_proxy >= 1 || throw(ArgumentError(
        "v76 target plasma gain must be at least one"))
    topology = generate_graph_native_topology_v69(structure_seed)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    binding = generate_augmented_helical_parameter_binding_v74(topology,
        structure_seed, parent_variant_seed)
    parent_hash = canonical_hash(binding)
    parent_realization = compile_augmented_helical_realization_v74(topology,
        compilation; parameter_binding = binding)
    parent_screen = screen_physical_device_v71(parent_realization, binding;
        particle_count = 1, step_count = 1,
        required_transit_fraction = required_transit_fraction)
    parent_gain = Float64(parent_screen.plasma_evidence["plasma_gain_proxy"])
    parent_gain > 0 || throw(ArgumentError("v76 parent plasma gain must be positive"))
    density_scale = sqrt(Float64(target_plasma_gain_proxy) / parent_gain)
    refined_density = Float64(binding["target_total_ion_density_m3"]) * density_scale
    density_bounds = Float64.(binding["design_bounds"]["target_total_ion_density_m3"])
    if !(density_bounds[1] <= refined_density <= density_bounds[2])
        artifact = Dict{String,Any}(
            "schema_version" => "1.0.0", "status" => "incomplete",
            "conclusion" => "unknown", "classification_code" =>
                "target_gain_requires_density_outside_declared_design_bound",
            "parent_candidate_binding_hash" => parent_hash,
            "parent_plasma_gain_proxy" => parent_gain,
            "target_plasma_gain_proxy" => Float64(target_plasma_gain_proxy),
            "requested_density_m3" => refined_density,
            "density_bounds_m3" => density_bounds,
            "claim_boundary" => AUGMENTED_HELICAL_OPERATING_V76_CLAIM_BOUNDARY)
        artifact["result_hash"] = canonical_hash(artifact)
        output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
        return artifact
    end
    binding["parent_candidate_binding_hash"] = parent_hash
    binding["refinement_id"] = "density_gain_and_heat_rejection_v76"
    binding["target_total_ion_density_m3"] = refined_density
    binding["target_plasma_gain_proxy"] = Float64(target_plasma_gain_proxy)
    first_realization = compile_augmented_helical_realization_v74(topology,
        compilation; parameter_binding = binding)
    first_screen = screen_physical_device_v71(first_realization, binding;
        particle_count = 1, step_count = 1,
        required_transit_fraction = required_transit_fraction)
    thermal_load = Float64(first_screen.engineering_evidence["screened_thermal_load_w"])
    refined_cooling = cooling_capacity_factor * thermal_load
    if refined_cooling > maximum_cooling_capacity_w
        artifact = Dict{String,Any}(
            "schema_version" => "1.0.0", "status" => "incomplete",
            "conclusion" => "unknown", "classification_code" =>
                "target_gain_heat_load_exceeds_declared_cooling_bound",
            "parent_candidate_binding_hash" => parent_hash,
            "refined_density_m3" => refined_density,
            "required_thermal_load_w" => thermal_load,
            "requested_cooling_capacity_w" => refined_cooling,
            "maximum_cooling_capacity_w" => Float64(maximum_cooling_capacity_w),
            "claim_boundary" => AUGMENTED_HELICAL_OPERATING_V76_CLAIM_BOUNDARY)
        artifact["result_hash"] = canonical_hash(artifact)
        output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
        return artifact
    end
    binding["cooling_capacity_w"] = refined_cooling
    binding["cooling_capacity_design_bound_w"] = Float64(maximum_cooling_capacity_w)
    realization = compile_augmented_helical_realization_v74(topology, compilation;
        parameter_binding = binding)
    scheduling_screen = screen_physical_device_v71(realization, binding;
        particle_count = 1, step_count = 1,
        required_transit_fraction = required_transit_fraction)
    closed_field = evaluate_closed_field_transport_gate_v73(realization,
        scheduling_screen, binding; target_toroidal_turns = target_toroidal_turns,
        steps_per_turn = field_steps_per_turn)
    if closed_field.conclusion == :fail
        artifact = Dict{String,Any}(
            "schema_version" => "1.0.0", "status" => "complete",
            "conclusion" => "screen_fail",
            "classification_code" => closed_field.classification_code,
            "structure_seed" => Int(structure_seed),
            "parent_variant_seed" => Int(parent_variant_seed),
            "parent_candidate_binding_hash" => parent_hash,
            "parameter_binding" => binding,
            "realization" => physical_device_realization_to_dict_v71(realization),
            "scheduling_screen" => physical_device_screen_to_dict_v71(scheduling_screen),
            "closed_field_gate" => closed_field_transport_gate_to_dict_v73(closed_field),
            "high_particle_execution_skipped" => true,
            "device_family_routing_used" => false,
            "claim_boundary" => AUGMENTED_HELICAL_OPERATING_V76_CLAIM_BOUNDARY)
        artifact["result_hash"] = canonical_hash(artifact)
        output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
        return artifact
    end
    screen = screen_physical_device_v71(realization, binding;
        particle_count = particle_count, step_count = step_count,
        required_transit_fraction = required_transit_fraction)
    conclusion = screen.conclusion == :screen_pass ? "frontier_unknown" :
        (screen.conclusion == :screen_fail ? "screen_fail" : "unknown")
    status = conclusion == "screen_fail" ? "complete" : "incomplete"
    classification = conclusion == "frontier_unknown" ?
        "four_turn_augmented_helical_frontier_requires_kinetic_transport_and_stability" :
        conclusion == "screen_fail" ? "operating_refined_candidate_rejected" :
        "operating_refined_candidate_evidence_incomplete"
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0", "status" => status,
        "conclusion" => conclusion, "classification_code" => classification,
        "structure_seed" => Int(structure_seed),
        "parent_variant_seed" => Int(parent_variant_seed),
        "parent_candidate_binding_hash" => parent_hash,
        "parent_plasma_gain_proxy" => parent_gain,
        "target_plasma_gain_proxy" => Float64(target_plasma_gain_proxy),
        "density_scale" => density_scale, "refined_density_m3" => refined_density,
        "refined_cooling_capacity_w" => refined_cooling,
        "parameter_binding" => binding,
        "topology" => _s70_topology_to_dict(topology),
        "realization" => physical_device_realization_to_dict_v71(realization),
        "screen" => physical_device_screen_to_dict_v71(screen),
        "closed_field_gate" => closed_field_transport_gate_to_dict_v73(closed_field),
        "high_particle_execution_skipped" => false,
        "device_family_routing_used" => false,
        "claim_boundary" => AUGMENTED_HELICAL_OPERATING_V76_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
    return artifact
end
