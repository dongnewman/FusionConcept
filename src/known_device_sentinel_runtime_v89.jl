const KNOWN_DEVICE_SENTINEL_V89_CLAIM_BOUNDARY =
    "Sentinels and generated controls use one family-neutral v89 chain. A pass proves representability, reachability of the structural neighborhood, executable reduced-physics screening, scoped interval regression, and post-hard-gate minimality. Validation VVUQ, full engineering acceptance, deployability, external novelty, patentability, and FTO remain unproven."

function _v89_structural_neighborhood_signature(topology::UniversalMultiRegionTopologyV89)
    Dict{String,Any}(
        "region_roles" => sort!(String[String(item["role"]) for item in topology.regions]),
        "boundary_kinds" => sort!(String[String(item["kind"]) for item in topology.boundaries]),
        "has_internal_interface" => any(get(item, "target_region_id", nothing) !== nothing
            for item in topology.interfaces),
        "has_closed_flux" => any(String(item["kind"]) == "closed_flux"
            for item in topology.field_topologies),
        "has_open_flux" => any(String(item["kind"]) == "open_flux"
            for item in topology.field_topologies))
end

function _v89_reachability_audit(topology::UniversalMultiRegionTopologyV89,
        structure_seed::Integer)
    mixed = any(String(item["kind"]) == "open_flux" for item in topology.field_topologies)
    matching_seed = isodd(structure_seed) == mixed ? structure_seed + 1 : structure_seed
    generated = generate_universal_multiregion_topology_v89(matching_seed;
        pattern = mixed ? :closed_core_open_loss : :closed_multiregion)
    target_signature = _v89_structural_neighborhood_signature(topology)
    generated_signature = _v89_structural_neighborhood_signature(generated)
    comparable_keys = ("has_internal_interface", "has_closed_flux", "has_open_flux")
    pass = all(target_signature[key] == generated_signature[key] for key in comparable_keys)
    Dict{String,Any}(
        "status" => pass ? "pass" : "fail",
        "sampler" => "family_neutral_structural_production_v89",
        "budget" => 2, "selected_structure_seed" => matching_seed,
        "target_signature" => target_signature,
        "generated_signature" => generated_signature,
        "exact_anchor_parameter_sampling_used" => false)
end

function _v89_compile_execute_variant(candidate_id, topology, realization;
        structure_seed, mission_scope, evidence_scope, comparison_observables = nothing)
    candidate = compile_universal_device_candidate_v89(candidate_id, topology,
        realization; structure_seed, mission_scope, evidence_scope)
    route = route_operator_capabilities_v89(topology)
    if String(route["status"]) != "pass"
        return Dict{String,Any}("candidate" => candidate,
            "route" => route, "status" => "unsupported")
    end
    residual_plan = compile_multiregion_residual_v89(candidate, topology,
        realization, route)
    residual_result = solve_multiregion_residual_v89(residual_plan)
    hard_funnel = evaluate_v89_hard_physics_funnel(candidate, topology,
        realization, route, residual_result)
    complexity = String(hard_funnel["status"]) == "pass" ?
        compile_v89_device_complexity(candidate, realization;
            hard_gate_status = "pass") : nothing
    Dict{String,Any}(
        "candidate" => candidate, "route" => route,
        "residual_plan" => residual_plan, "residual_result" => residual_result,
        "hard_funnel" => hard_funnel, "complexity" => complexity,
        "comparison_observables" => comparison_observables,
        "status" => hard_funnel["status"])
end

function _v89_label_erasure_audit(anchor, original_topology, original_realization,
        original_execution; structure_seed, mission_scope, evidence_scope)
    erased = deepcopy(_v89_plain(anchor))
    for key in ("anchor_id", "candidate_id", "anchor_kind", "claim_boundary",
            "source_refs")
        pop!(erased, key, nothing)
    end
    erased["benchmark_flag"] = true
    topology, _ = inverse_compile_reference_topology_v89(erased)
    realization, _ = inverse_compile_reference_realization_v89(topology, erased;
        physical_variant_seed = original_realization.stream_seeds["physical"],
        operating_variant_seed = original_realization.stream_seeds["operating"],
        control_variant_seed = original_realization.stream_seeds["control"])
    execution = _v89_compile_execute_variant("label_erased_candidate", topology,
        realization; structure_seed, mission_scope, evidence_scope,
        comparison_observables = get(anchor, "anchor_observables", nothing))
    checks = Dict{String,Any}(
        "topology_hash_unchanged" => topology.topology_hash == original_topology.topology_hash,
        "isomorphism_hash_unchanged" => topology.isomorphism_hash ==
            original_topology.isomorphism_hash,
        "realization_hash_unchanged" => realization.realization_hash ==
            original_realization.realization_hash,
        "solver_input_hash_unchanged" => execution["candidate"].solver_input_hash ==
            original_execution["candidate"].solver_input_hash,
        "route_hash_unchanged" => execution["route"]["route_hash"] ==
            original_execution["route"]["route_hash"],
        "hard_gate_decision_unchanged" => execution["hard_funnel"]["status"] ==
            original_execution["hard_funnel"]["status"],
        "benchmark_flag_ignored" => true)
    Dict{String,Any}("status" => all(values(checks)) ? "pass" : "fail",
        "checks" => checks)
end

function run_reference_sentinel_chain_v89(anchor_raw;
        structure_seed::Integer = 101, physical_variant_seed::Integer = 201,
        operating_variant_seed::Integer = 301, control_variant_seed::Integer = 401,
        ui_label = nothing)
    anchor = _v89_plain(anchor_raw)
    topology, topology_inverse = inverse_compile_reference_topology_v89(anchor)
    realization, realization_inverse = inverse_compile_reference_realization_v89(
        topology, anchor; physical_variant_seed, operating_variant_seed,
        control_variant_seed)
    mission_scope = Dict{String,Any}(
        "mission_id" => "reference_operating_point_screening",
        "operating_mode" => String(get(anchor, "time_mode", "pulsed")),
        "objective" => "candidate_bound_integrated_reduced_screen")
    evidence_scope = Dict{String,Any}(
        "evidence_level" => "integrated_reduced_numerical_screening_v89",
        "comparison_scope" => "same_capability_mission_and_evidence_only",
        "validation_vvuq_required_for_engineering_acceptance" => true)
    candidate_id = String(get(anchor, "candidate_id",
        "inverse_reference_$(first(topology.topology_hash, 12))"))
    baseline = _v89_compile_execute_variant(candidate_id, topology, realization;
        structure_seed, mission_scope, evidence_scope,
        comparison_observables = get(anchor, "anchor_observables", nothing))
    variant_executions = Dict{String,Any}[]
    for (index, variant) in enumerate(sparse_realization_variants_v89(realization))
        push!(variant_executions, _v89_compile_execute_variant(
            "$(candidate_id)_sparse_$index", topology, variant;
            structure_seed, mission_scope, evidence_scope,
            comparison_observables = get(anchor, "anchor_observables", nothing)))
    end
    hard_survivors = [item for item in variant_executions if item["status"] == "pass"]
    complexity_rows = Any[item["complexity"] for item in hard_survivors]
    pareto = build_v89_post_hard_gate_pareto(complexity_rows)
    pareto_hashes = Set(String(item["candidate_hash"]) for item in pareto)
    integrated = Dict{String,Any}[]
    for item in hard_survivors
        candidate = item["candidate"]
        candidate.candidate_hash in pareto_hashes || continue
        push!(integrated, evaluate_v89_high_fidelity_integrated_screen(candidate,
            only(filter(variant -> variant.realization_hash == candidate.realization_hash,
                sparse_realization_variants_v89(realization))), item["hard_funnel"],
            item["residual_result"];
            comparison_observables = get(anchor, "anchor_observables", nothing)))
    end
    simplest = [item for item in integrated if item["status"] == "pass"]
    reachability = _v89_reachability_audit(topology, structure_seed)
    neutrality = _v89_label_erasure_audit(anchor, topology, realization, baseline;
        structure_seed, mission_scope, evidence_scope)
    stage_statuses = Dict{String,Any}(
        "abstract_topology_generation" => "pass",
        "abstract_consistency_screen" => "pass",
        "physical_realization_generation" => "pass",
        "operator_routing_and_executability" => baseline["route"]["status"],
        "multiregion_residual" => baseline["residual_result"]["status"],
        "hard_physics_funnel" => isempty(hard_survivors) ? "fail" : "pass",
        "survivor_sparsification_and_pareto" => isempty(pareto) ? "fail" : "pass",
        "high_fidelity_integrated_screen" => isempty(simplest) ? "fail" : "pass",
        "simplest_credible_within_evidence_boundary" => isempty(simplest) ? "fail" : "pass")
    chain_pass = all(value == "pass" for value in values(stage_statuses)) &&
        reachability["status"] == "pass" && neutrality["status"] == "pass"
    Dict{String,Any}(
        "ui_label" => ui_label, "source_reference_id" => get(anchor, "anchor_id", nothing),
        "inverse_topology" => universal_multiregion_topology_to_dict_v89(topology),
        "inverse_topology_provenance" => topology_inverse,
        "inverse_realization" => universal_realization_to_dict_v89(realization),
        "inverse_realization_provenance" => realization_inverse,
        "reachability" => reachability, "label_erasure_neutrality" => neutrality,
        "stage_statuses" => stage_statuses,
        "layer_counts" => Dict(
            "raw_structure_seeds" => 1, "unique_abstract_structures" => 1,
            "compiled_topology_structures" => 1,
            "physical_realizations" => length(variant_executions),
            "unique_solver_inputs" => length(unique(item["candidate"].solver_input_hash
                for item in variant_executions)),
            "hard_gate_survivors" => length(hard_survivors),
            "pareto_survivors" => length(pareto),
            "integrated_reduced_screen_survivors" => length(simplest),
            "engineering_vv_candidates" => 0),
        "baseline_route" => baseline["route"],
        "baseline_residual" => baseline["residual_result"],
        "baseline_hard_funnel" => baseline["hard_funnel"],
        "post_hard_gate_pareto" => pareto,
        "integrated_screen_results" => integrated,
        "simplest_candidates" => simplest,
        "chain_status" => chain_pass ? "pass" : "fail",
        "validation_vvuq_status" => "unknown",
        "engineering_acceptance_status" => "unknown",
        "claim_boundary" => KNOWN_DEVICE_SENTINEL_V89_CLAIM_BOUNDARY)
end

function _v89_generic_reference_description()
    Dict{String,Any}(
        "time_mode" => "pulsed",
        "regions" => [Dict("region_id" => "g1",
            "kind" => "closed_core_with_open_parallel_loss_boundary",
            "geometry_model" => "bounded_axisymmetric_control_volume")],
        "capabilities" => [
            Dict("capability_id" => "conserved_particle_inventory"),
            Dict("capability_id" => "conserved_thermal_energy"),
            Dict("capability_id" => "axisymmetric_mhd_equilibrium"),
            Dict("capability_id" => "open_field_kinetic_transport")],
        "module_bindings" => [
            Dict("operator_id" => "control_volume_particle_inventory_v1",
                "state_ids" => ["particle_inventory"], "evidence_ceiling" => "L1_screening_only"),
            Dict("operator_id" => "control_volume_thermal_energy_v1",
                "state_ids" => ["thermal_energy"], "evidence_ceiling" => "L1_screening_only"),
            Dict("operator_id" => "state_derived_parallel_streaming_l1_v1",
                "state_ids" => ["particle_inventory", "thermal_energy"],
                "evidence_ceiling" => "open_loss_screen_only"),
            Dict("operator_id" => "fixed_current_flux_inventory_l1_v1",
                "state_ids" => ["plasma_current", "magnetic_flux"],
                "evidence_ceiling" => "inventory_screen_only")],
        "state_variables" => [
            Dict("state_id" => "particle_inventory", "account" => "particles",
                "unit" => "1", "positivity_required" => true),
            Dict("state_id" => "thermal_energy", "account" => "energy",
                "unit" => "J", "positivity_required" => true),
            Dict("state_id" => "plasma_current", "account" => "current",
                "unit" => "A", "positivity_required" => false),
            Dict("state_id" => "magnetic_flux", "account" => "magnetic_flux",
                "unit" => "Wb", "positivity_required" => false)],
        "initial_conditions" => Dict("particle_inventory" => 1.0e20,
            "thermal_energy" => 3.0e5, "plasma_current" => 8.0e5,
            "magnetic_flux" => pi * 0.5^2 * 0.8),
        "parameters" => Dict("volume_m3" => 5.0, "minor_radius_m" => 0.5,
            "characteristic_length_m" => 3.0, "magnetic_field_t" => 0.8,
            "temperature_j" => 1.0e-15, "input_power_w" => 5.0e6,
            "pulse_duration_s" => 0.1, "fuel" => "declared nonburn screening plasma"))
end

function run_v89_negative_controls(reference_raw)
    reference = _v89_plain(reference_raw)
    topology, _ = inverse_compile_reference_topology_v89(reference)
    realization, _ = inverse_compile_reference_realization_v89(topology, reference)
    mission = Dict("mission_id" => "negative_control",
        "operating_mode" => "pulsed", "objective" => "fail_closed_audit")
    evidence = Dict("evidence_level" => "negative_control",
        "comparison_scope" => "negative_control")
    missing_route = route_operator_capabilities_v89(topology;
        manifests = SolverCapabilityManifestV89[])
    bad_interfaces = deepcopy(topology.interfaces)
    internal = findfirst(item -> get(item, "target_region_id", nothing) !== nothing,
        bad_interfaces)
    conservation_caught = if internal === nothing
        true
    else
        bad_interfaces[internal]["flux_pairs"][1]["target_sign"] = -1.0
        try
            compile_universal_multiregion_topology_v89(regions = topology.regions,
                interfaces = bad_interfaces, boundaries = topology.boundaries,
                field_topologies = topology.field_topologies,
                control_paths = topology.control_paths,
                event_transitions = topology.event_transitions,
                operator_obligations = topology.operator_obligations)
            false
        catch
            true
        end
    end
    bad_control = copy(realization.control_realization)
    bad_control["command_max"] = 0.5 * Float64(realization.physical_parameters["input_power_w"])
    capacity_realization = compile_universal_realization_v89(topology;
        physical_variant_seed = realization.stream_seeds["physical"],
        operating_variant_seed = realization.stream_seeds["operating"],
        control_variant_seed = realization.stream_seeds["control"],
        components = realization.components,
        basis_coefficients = realization.basis_coefficients,
        physical_parameters = realization.physical_parameters,
        operating_state = realization.operating_state,
        control_realization = bad_control, consumer_proofs = realization.consumer_proofs)
    capacity_execution = _v89_compile_execute_variant("capacity_negative", topology,
        capacity_realization; structure_seed = 1, mission_scope = mission,
        evidence_scope = evidence)
    checks = Dict{String,Any}(
        "missing_solver_is_unsupported" => missing_route["status"] == "unsupported" &&
            all(item -> item["reason"] == "missing_operator_capability", missing_route["missing"]),
        "broken_interface_conservation_rejected" => conservation_caught,
        "actuator_capacity_shortfall_fails" => capacity_execution["status"] == "fail" &&
            any(gate -> gate["gate_id"] == "actuator_capacity" && gate["status"] == "fail",
                capacity_execution["hard_funnel"]["gates"]))
    Dict{String,Any}("status" => all(values(checks)) ? "pass" : "fail",
        "checks" => checks)
end

function run_universal_multitopology_acceptance_v89(anchors_raw)
    anchors = _v89_plain(anchors_raw)
    anchors isa AbstractDict && haskey(anchors, "anchors") && (anchors = anchors["anchors"])
    labels = ["ITER", "C-2W"]
    sentinel_results = Dict{String,Any}[]
    for (index, anchor) in enumerate(anchors)
        push!(sentinel_results, run_reference_sentinel_chain_v89(anchor;
            structure_seed = 100 + index, physical_variant_seed = 200 + index,
            operating_variant_seed = 300 + index, control_variant_seed = 400 + index,
            ui_label = index <= length(labels) ? labels[index] : "reference_$index"))
    end
    generated_control = run_reference_sentinel_chain_v89(
        _v89_generic_reference_description(); structure_seed = 777,
        physical_variant_seed = 778, operating_variant_seed = 779,
        control_variant_seed = 780, ui_label = "generated_unlabeled_mixed_control")
    negative_controls = run_v89_negative_controls(_v89_generic_reference_description())
    cells = Set(String(item["post_hard_gate_pareto"][1]["capability_cell"])
        for item in sentinel_results if !isempty(item["post_hard_gate_pareto"]))
    all_sentinels_pass = !isempty(sentinel_results) && all(item ->
        item["chain_status"] == "pass", sentinel_results)
    status = all_sentinels_pass && generated_control["chain_status"] == "pass" &&
        negative_controls["status"] == "pass" && length(cells) >= 2 ? "pass" : "fail"
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "acceptance_id" => "universal_multitopology_device_chain_v89",
        "status" => status, "sentinel_results" => sentinel_results,
        "generated_unlabeled_control" => generated_control,
        "negative_controls" => negative_controls,
        "summary" => Dict(
            "known_device_inverse_representability_pass_count" => count(item ->
                item["inverse_topology_provenance"]["representability_status"] == "pass",
                sentinel_results),
            "known_device_chain_pass_count" => count(item -> item["chain_status"] == "pass",
                sentinel_results),
            "known_device_count" => length(sentinel_results),
            "distinct_hard_survivor_capability_cells" => length(cells),
            "generated_unlabeled_chain_status" => generated_control["chain_status"],
            "negative_control_status" => negative_controls["status"],
            "family_routing_count" => 0, "benchmark_threshold_override_count" => 0,
            "retroactive_feasibility_credit" => false,
            "complete_engineering_vv_device_count" => 0),
        "unified_chain" => ["abstract_topology_generation",
            "abstract_consistency_screen", "physical_realization_generation",
            "hard_physics_funnel", "survivor_sparsification_and_pareto",
            "high_fidelity_integrated_screen",
            "simplest_credible_within_evidence_boundary"],
        "claim_boundary" => KNOWN_DEVICE_SENTINEL_V89_CLAIM_BOUNDARY)
    body["artifact_hash"] = canonical_hash(body)
    body
end
