@testset "universal multi-topology device chain v89" begin
    anchors = load_candidate_solver_reference_anchors_v1(joinpath(@__DIR__, "..",
        "fixtures", "candidate_solver_reference_anchors_v1.json"))
    result = run_universal_multitopology_acceptance_v89(anchors)
    @test result["status"] == "pass"
    summary = result["summary"]
    @test summary["known_device_inverse_representability_pass_count"] == 2
    @test summary["known_device_chain_pass_count"] == 2
    @test summary["known_device_count"] == 2
    @test summary["distinct_hard_survivor_capability_cells"] == 2
    @test summary["generated_unlabeled_chain_status"] == "pass"
    @test summary["negative_control_status"] == "pass"
    @test summary["family_routing_count"] == 0
    @test summary["benchmark_threshold_override_count"] == 0
    @test !summary["retroactive_feasibility_credit"]
    @test summary["complete_engineering_vv_device_count"] == 0

    sentinels = result["sentinel_results"]
    @test [item["ui_label"] for item in sentinels] == ["ITER", "C-2W"]
    @test all(item -> item["chain_status"] == "pass", sentinels)
    @test length(sentinels[1]["inverse_topology"]["regions"]) == 1
    @test length(sentinels[2]["inverse_topology"]["regions"]) == 2
    @test Set(String(item["kind"]) for item in
        sentinels[2]["inverse_topology"]["boundaries"]) == Set(["mixed", "open"])
    @test any(item -> item["kind"] == "open_flux",
        sentinels[2]["inverse_topology"]["field_topologies"])
    @test any(item -> item["target_region_id"] !== nothing,
        sentinels[2]["inverse_topology"]["interfaces"])

    for sentinel in sentinels
        @test sentinel["inverse_topology_provenance"]["representability_status"] == "pass"
        @test !sentinel["inverse_topology_provenance"]["anchor_observables_consumed_by_inverse"]
        @test !sentinel["inverse_realization_provenance"]["anchor_observables_consumed_by_inverse"]
        @test sentinel["reachability"]["status"] == "pass"
        @test !sentinel["reachability"]["exact_anchor_parameter_sampling_used"]
        @test sentinel["label_erasure_neutrality"]["status"] == "pass"
        @test all(values(sentinel["label_erasure_neutrality"]["checks"]))
        @test all(value == "pass" for value in values(sentinel["stage_statuses"]))
        @test sentinel["baseline_route"]["status"] == "pass"
        @test !sentinel["baseline_route"]["family_routing_used"]
        @test !sentinel["baseline_route"]["name_routing_used"]
        @test !sentinel["baseline_route"]["benchmark_routing_used"]
        @test sentinel["baseline_residual"]["status"] == "pass"
        @test sentinel["baseline_residual"]["maximum_normalized_residual"] == 0.0
        @test sentinel["baseline_residual"]["maximum_interface_conservation_error"] == 0.0
        @test length(sentinel["baseline_residual"]["resolution_evidence"]) == 3
        @test sentinel["baseline_hard_funnel"]["status"] == "pass"
        @test sentinel["baseline_hard_funnel"]["hard_gate_count"] == 9
        @test sentinel["baseline_hard_funnel"]["passed_hard_gate_count"] == 9
        @test sentinel["layer_counts"]["hard_gate_survivors"] >= 1
        @test sentinel["layer_counts"]["pareto_survivors"] >= 1
        @test sentinel["layer_counts"]["integrated_reduced_screen_survivors"] >= 1
        @test sentinel["layer_counts"]["engineering_vv_candidates"] == 0
        @test length(sentinel["post_hard_gate_pareto"]) >= 1
        @test all(item -> item["hard_gate_status"] == "pass",
            sentinel["post_hard_gate_pareto"])
        @test all(item -> item["status"] == "pass",
            sentinel["integrated_screen_results"])
        @test all(item -> item["published_interval_regression_status"] == "pass",
            sentinel["integrated_screen_results"])
        @test all(item -> !item["anchor_values_used_as_predictions"],
            sentinel["integrated_screen_results"])
        @test all(item -> item["numerical_vvuq_status"] == "pass",
            sentinel["integrated_screen_results"])
        @test all(item -> item["validation_vvuq_status"] == "unknown",
            sentinel["integrated_screen_results"])
        @test all(item -> item["engineering_acceptance_status"] == "unknown",
            sentinel["integrated_screen_results"])
        @test sentinel["validation_vvuq_status"] == "unknown"
        @test sentinel["engineering_acceptance_status"] == "unknown"
        streams = sentinel["inverse_realization"]["stream_hashes"]
        @test length(unique(values(streams))) == 3
    end

    iter_comparisons = only(sentinels[1]["integrated_screen_results"])[
        "published_interval_comparisons"]
    @test Set(item["observable_id"] for item in iter_comparisons) ==
        Set(["fusion_power_w", "pulse_duration_s"])
    @test all(item -> item["status"] == "pass", iter_comparisons)
    @test all(item -> !item["reference_used_as_model_input"], iter_comparisons)
    c2w_comparisons = only(sentinels[2]["integrated_screen_results"])[
        "published_interval_comparisons"]
    @test Set(item["observable_id"] for item in c2w_comparisons) ==
        Set(["effective_temperature_ev", "pulse_duration_s"])
    @test all(item -> item["status"] == "pass", c2w_comparisons)

    generated = result["generated_unlabeled_control"]
    @test generated["chain_status"] == "pass"
    @test generated["source_reference_id"] === nothing
    @test generated["baseline_hard_funnel"]["status"] == "pass"
    @test result["negative_controls"]["status"] == "pass"
    @test all(values(result["negative_controls"]["checks"]))

    @test_throws ArgumentError build_v89_post_hard_gate_pareto([
        Dict("hard_gate_status" => "fail")])
    @test_throws ArgumentError compile_universal_multiregion_topology_v89(
        regions = [Dict("region_id" => "r1", "role" => "plasma_core",
            "dimension" => "0d", "time_semantics" => "steady",
            "reservoir_accounts" => ["energy"],
            "state_slots" => [Dict("slot_id" => "e", "unit" => "J",
                "positivity_required" => true)], "family" => "forbidden")],
        interfaces = [Dict("interface_id" => "i1", "source_region_id" => "r1",
            "target_region_id" => nothing, "kind" => "external",
            "flux_pairs" => [Dict("account_id" => "energy", "unit" => "W",
                "source_sign" => -1.0, "target_sign" => 0.0)])],
        boundaries = [Dict("region_id" => "r1", "kind" => "closed")],
        field_topologies = [Dict("region_id" => "r1", "kind" => "closed_flux")],
        operator_obligations = [Dict("obligation_id" => "o1",
            "operator_id" => "control_volume_thermal_energy_v1", "region_id" => "r1",
            "spatial_dimension" => "0d", "time_semantics" => "steady",
            "boundary_kinds" => ["closed"], "required_state_ids" => ["e"],
            "evidence_obligation" => "screen")])
end
