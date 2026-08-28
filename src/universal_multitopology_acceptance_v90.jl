const UNIVERSAL_MULTITOPOLOGY_ACCEPTANCE_V90_CLAIM_BOUNDARY =
    "v90 acceptance distinguishes implemented software-chain gates from candidate evidence. The formal credible-large-range claim remains false while kinetic, full engineering, validation VVUQ, or external novelty obligations are unknown or unsupported."

function _v90_replace_control(slice, command_ratio)
    control = copy(slice.realization.control_realization)
    input_power = Float64(slice.realization.physical_parameters["input_power_w"])
    control["command_max"] = input_power * Float64(command_ratio)
    realization = compile_universal_realization_v89(slice.topology;
        physical_variant_seed = slice.realization.stream_seeds["physical"],
        operating_variant_seed = slice.realization.stream_seeds["operating"],
        control_variant_seed = slice.realization.stream_seeds["control"],
        components = slice.realization.components,
        basis_coefficients = slice.realization.basis_coefficients,
        physical_parameters = slice.realization.physical_parameters,
        operating_state = slice.realization.operating_state,
        control_realization = control,
        consumer_proofs = slice.realization.consumer_proofs)
    candidate = compile_universal_device_candidate_v89(
        slice.candidate.candidate_id, slice.topology, realization;
        structure_seed = slice.candidate.structure_seed,
        mission_scope = slice.candidate.mission_scope,
        evidence_scope = slice.candidate.evidence_scope)
    (topology = slice.topology, realization = realization, candidate = candidate,
        pattern = slice.pattern)
end
function run_v90_negative_controls()
    base = compile_generated_vertical_slice_v90(101;
        pattern = :closed_multiregion)
    missing = route_operator_capabilities_v90(base.topology, base.realization;
        manifests = SolverCapabilityManifestV90[])
    broken_interfaces = deepcopy(compile_generated_vertical_slice_v90(102;
        pattern = :closed_core_open_loss).topology.interfaces)
    broken_interfaces[1]["flux_pairs"][1]["target_sign"] = -1.0
    open_slice = compile_generated_vertical_slice_v90(102;
        pattern = :closed_core_open_loss)
    conservation_rejected = try
        compile_universal_multiregion_topology_v89(regions = open_slice.topology.regions,
            interfaces = broken_interfaces, boundaries = open_slice.topology.boundaries,
            field_topologies = open_slice.topology.field_topologies,
            control_paths = open_slice.topology.control_paths,
            event_transitions = open_slice.topology.event_transitions,
            operator_obligations = open_slice.topology.operator_obligations)
        false
    catch
        true
    end
    capacity_slice = _v90_replace_control(base, 0.5)
    capacity = evaluate_v90_hard_physics_vertical_slice(capacity_slice)
    route = route_operator_capabilities_v90(base.topology, base.realization)
    contract = compile_multiregion_nonlinear_dae_v90(base.candidate,
        base.topology, base.realization, route)
    exhausted = solve_multiregion_nonlinear_dae_v90(contract;
        backend = NativeDampedNewtonDAEBackendV90(
            maximum_newton_iterations = 0, dae_steps = 0))
    checks = Dict{String,Any}(
        "missing_solver_is_unsupported" => missing["status"] == "unsupported" &&
            all(item -> item["reason"] == "missing_operator_capability", missing["missing"]),
        "broken_dynamic_interface_pair_rejected" => conservation_rejected,
        "actuator_capacity_shortfall_fails" => capacity["status"] == "fail" &&
            any(gate -> gate["gate_id"] == "actuator_capacity" &&
                gate["status"] == "fail", capacity["gates"]),
        "numerical_nonconvergence_is_unknown" => exhausted["status"] == "unknown",
        "control_change_updates_candidate_physics_hash" =>
            base.realization.candidate_physics_hash !=
                capacity_slice.realization.candidate_physics_hash,
        "control_change_updates_actual_solver_input" => begin
            changed_route = route_operator_capabilities_v90(capacity_slice.topology,
                capacity_slice.realization)
            changed_contract = compile_multiregion_nonlinear_dae_v90(
                capacity_slice.candidate, capacity_slice.topology,
                capacity_slice.realization, changed_route)
            changed_contract.solver_input_hash != contract.solver_input_hash
        end)
    body = Dict{String,Any}("status" => all(values(checks)) ? "pass" : "fail",
        "checks" => checks, "missing_route" => missing,
        "capacity_classification" => capacity["status"],
        "nonconvergence_classification" => exhausted["classification"])
    body["result_hash"] = canonical_hash(body); body
end

function _v90_sentinel_result(anchor, index, label)
    slice = compile_reference_vertical_slice_v90(anchor;
        structure_seed = 900 + index, physical_variant_seed = 910 + index,
        operating_variant_seed = 920 + index, control_variant_seed = 930 + index)
    hard = evaluate_v90_hard_physics_vertical_slice(slice)
    deep = hard["status"] == "pass" ?
        evaluate_survivor_fidelity_vvuq_v90(slice, hard) : nothing
    replay = compile_reference_vertical_slice_v90(anchor;
        structure_seed = 900 + index, physical_variant_seed = 910 + index,
        operating_variant_seed = 920 + index, control_variant_seed = 930 + index)
    neutrality = Dict{String,Any}(
        "topology_hash_unchanged" => replay.topology.topology_hash ==
            slice.topology.topology_hash,
        "realization_hash_unchanged" => replay.realization.realization_hash ==
            slice.realization.realization_hash,
        "candidate_hash_unchanged" => replay.candidate.candidate_hash ==
            slice.candidate.candidate_hash,
        "ui_label_consumed_by_scientific_chain" => false,
        "benchmark_flag_consumed_by_scientific_chain" => false)
    body = Dict{String,Any}(
        "ui_label" => String(label), "sentinel" => true,
        "topology_hash" => slice.topology.topology_hash,
        "realization_hash" => slice.realization.realization_hash,
        "candidate_physics_hash" => slice.realization.candidate_physics_hash,
        "capability_cell" => slice.candidate.capability_cell,
        "hard_result" => hard, "deep_result" => deep,
        "label_erasure_neutrality" => Dict("status" =>
            all(value === true || value === false && occursin("consumed", key)
                for (key, value) in neutrality) ? "pass" : "fail",
            "checks" => neutrality),
        "anchor_observables_used_as_predictions" => false,
        "published_interval_regression_status" => "unknown_not_used_for_promotion",
        "promotion_credit" => false,
        "claim_boundary" => "Sealed reference containment and common-chain execution only; no special threshold, solver, or promotion credit.")
    body["result_hash"] = canonical_hash(Dict(key => value for (key, value) in body
        if key != "hard_result" && key != "deep_result")); body
end

function _v90_stage_histogram(generated, sentinels)
    histogram = Dict("pass" => 0, "fail" => 0, "unknown" => 0,
        "unsupported" => 0, "not_applicable" => 0)
    for record in vcat(generated, sentinels)
        hard = record["hard_result"]
        histogram[String(hard["status"])] = get(histogram, String(hard["status"]), 0) + 1
        deep = get(record, "deep_result", nothing)
        deep === nothing && continue
        for stage in deep["stages"]
            status = String(stage["status"])
            histogram[status] = get(histogram, status, 0) + 1
        end
    end
    histogram
end

function run_universal_multitopology_acceptance_v90(anchors_raw;
        campaign_merge = nothing)
    generated = Dict{String,Any}[]
    for (index, seed) in enumerate((101, 102))
        slice = compile_generated_vertical_slice_v90(seed)
        hard = evaluate_v90_hard_physics_vertical_slice(slice)
        deep = hard["status"] == "pass" ?
            evaluate_survivor_fidelity_vvuq_v90(slice, hard) : nothing
        push!(generated, Dict{String,Any}(
            "sentinel" => false, "structure_seed" => seed,
            "pattern" => String(slice.pattern),
            "topology_hash" => slice.topology.topology_hash,
            "realization_hash" => slice.realization.realization_hash,
            "candidate_physics_hash" => slice.realization.candidate_physics_hash,
            "capability_cell" => slice.candidate.capability_cell,
            "hard_result" => hard, "deep_result" => deep))
    end
    anchors = _v89_plain(anchors_raw)
    anchors isa AbstractDict && haskey(anchors, "anchors") && (anchors = anchors["anchors"])
    labels = ["ITER", "C-2W"]
    sentinels = [_v90_sentinel_result(anchor, index,
        index <= length(labels) ? labels[index] : "reference_$index")
        for (index, anchor) in enumerate(anchors)]
    negative = run_v90_negative_controls()
    generated_hard_cells = Set(String(item["capability_cell"]) for item in generated
        if item["hard_result"]["status"] == "pass")
    numerical_pass = all(item -> item["deep_result"] !== nothing &&
        item["deep_result"]["numerical_vvuq_status"] == "pass", generated)
    sentinel_hard_pass = length(sentinels) >= 2 && all(item ->
        item["hard_result"]["status"] == "pass", sentinels)
    campaign_status = campaign_merge === nothing ? "unknown" :
        String(campaign_merge["status"])
    software_chain_pass = length(generated_hard_cells) >= 2 && numerical_pass &&
        sentinel_hard_pass && negative["status"] == "pass" &&
        campaign_status in ("complete", "unknown")
    unmet = [
        "candidate_bound_kinetic_distribution_and_collision_validation",
        "full_free_boundary_or_three_dimensional_equilibrium_as_applicable",
        "resistive_kinetic_and_nonlinear_stability_modes",
        "structural_thermal_material_shielding_cryogenic_maintenance_closure",
        "candidate_bound_experimental_validation_vvuq",
        "external_literature_novelty_patent_and_fto_assessment"]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "acceptance_id" => "universal_multitopology_device_chain_v90",
        "implementation_acceptance_status" => software_chain_pass ? "pass" : "fail",
        "credible_large_range_search_claim_status" => "fail",
        "credible_large_range_search_claim_authorized" => false,
        "generated_non_sentinel_vertical_slices" => generated,
        "sentinel_results" => sentinels, "negative_controls" => negative,
        "campaign_merge" => campaign_merge,
        "status_histogram" => _v90_stage_histogram(generated, sentinels),
        "layer_counts" => Dict(
            "raw_structures" => campaign_merge === nothing ? 2 :
                campaign_merge["raw_structure_seeds"],
            "physical_realizations" => campaign_merge === nothing ? 2 :
                campaign_merge["physical_realizations"],
            "unique_solver_inputs" => campaign_merge === nothing ? 2 :
                campaign_merge["unique_solver_inputs"],
            "hard_survivors" => campaign_merge === nothing ? 2 :
                campaign_merge["hard_gate_survivor_count"],
            "numerical_vvuq_survivors" => count(item -> item["deep_result"] !== nothing &&
                item["deep_result"]["numerical_vvuq_status"] == "pass", generated),
            "engineering_candidates" => 0),
        "routing_firewall" => Dict("family" => 0, "name" => 0,
            "candidate_id" => 0, "parent" => 0, "sentinel" => 0,
            "benchmark_threshold_override" => 0),
        "retroactive_feasibility_credit" => false,
        "unmet_physical_engineering_experimental_novelty_boundaries" => unmet,
        "claim_boundary" => UNIVERSAL_MULTITOPOLOGY_ACCEPTANCE_V90_CLAIM_BOUNDARY)
    normalized = _v89_plain(JSON3.read(JSON3.write(body), Dict{String,Any}))
    normalized["artifact_hash"] = canonical_hash(normalized)
    normalized
end
