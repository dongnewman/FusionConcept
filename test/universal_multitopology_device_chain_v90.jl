@testset "universal multi-topology nonlinear device chain v90" begin
    slices = [compile_generated_vertical_slice_v90(101),
        compile_generated_vertical_slice_v90(102)]
    @test length(Set(slice.candidate.capability_cell for slice in slices)) == 2

    hard_results = Dict{String,Any}[]
    deep_results = Dict{String,Any}[]
    for slice in slices
        route = route_operator_capabilities_v90(slice.topology, slice.realization)
        @test route["status"] == "pass"
        @test all(route[key] === false for key in
            ("family_routing_used", "name_routing_used",
                "candidate_id_routing_used", "parent_routing_used",
                "sentinel_routing_used", "benchmark_routing_used"))
        contract = compile_multiregion_nonlinear_dae_v90(slice.candidate,
            slice.topology, slice.realization, route)
        governing = [block for block in contract.residual_blocks
            if block["block_kind"] == "governing"]
        @test sort(String.(getindex.(governing, "equation_id"))) ==
            sort(contract.state_ids)
        @test all(count(block -> block["block_kind"] == "governing" &&
            block["equation_id"] == state_id, contract.residual_blocks) == 1
            for state_id in contract.state_ids)
        @test all(pair -> pair["same_nonlinear_iteration"] === true &&
            pair["source_sign"] == -pair["target_sign"], contract.interface_pairs)

        nonlinear = solve_multiregion_nonlinear_dae_v90(contract)
        @test nonlinear["status"] == "pass"
        @test nonlinear["maximum_normalized_residual"] <=
            contract.stopping_contract["normalized_residual_tolerance"]
        @test nonlinear["initial_guess_equals_final_state"] === false
        @test nonlinear["audits"]["governing_block_ownership"] == "pass"
        @test nonlinear["audits"]["interface_same_iteration"] == "pass"
        @test nonlinear["audits"]["jacobian"]["status"] == "pass"
        @test nonlinear["audits"]["independent_balance"]["status"] == "pass"
        @test nonlinear["audits"]["independent_balance"][
            "main_residual_assembly_reused"] === false

        hard = evaluate_v90_hard_physics_vertical_slice(slice)
        @test hard["status"] == "pass"
        @test all(gate -> gate["status"] == "pass", hard["gates"])
        deep = evaluate_survivor_fidelity_vvuq_v90(slice, hard)
        @test deep["numerical_vvuq_status"] == "pass"
        @test deep["status"] == "unknown"
        stages = Dict(stage["stage_id"] => stage for stage in deep["stages"])
        @test stages["validation_vvuq"]["status"] == "unknown"
        @test stages["transport_or_kinetic"]["status"] == "unknown"
        for stage_id in ("structure", "thermal_material", "shielding",
                "cryogenic", "maintenance")
            @test stages[stage_id]["status"] == "unsupported"
            @test stages[stage_id]["result_payload"]["metric"] === nothing
            @test !isempty(stages[stage_id]["result_payload"]["unavailable_reason"])
        end
        push!(hard_results, hard); push!(deep_results, deep)
    end

    missing = route_operator_capabilities_v90(slices[1].topology,
        slices[1].realization; manifests = SolverCapabilityManifestV90[])
    @test missing["status"] == "unsupported"
    @test all(item -> item["reason"] == "missing_operator_capability",
        missing["missing"])

    controls = run_v90_negative_controls()
    @test controls["status"] == "pass"
    @test all(values(controls["checks"]))

    anchors = load_candidate_solver_reference_anchors_v1(joinpath(@__DIR__, "..",
        "fixtures", "candidate_solver_reference_anchors_v1.json"))
    acceptance = run_universal_multitopology_acceptance_v90(anchors)
    @test acceptance["implementation_acceptance_status"] == "pass"
    @test acceptance["credible_large_range_search_claim_status"] == "fail"
    @test acceptance["credible_large_range_search_claim_authorized"] === false
    @test all(item -> item["hard_result"]["status"] == "pass",
        acceptance["sentinel_results"])
    @test all(item -> item["promotion_credit"] === false &&
        item["label_erasure_neutrality"]["status"] == "pass",
        acceptance["sentinel_results"])
    normalized_acceptance = JSON3.read(JSON3.write(Dict(key => value for
        (key, value) in acceptance if key != "artifact_hash")), Dict{String,Any})
    @test canonical_hash(normalized_acceptance) == acceptance["artifact_hash"]

    mktempdir() do campaign_dir
        specification = compile_multitopology_campaign_v90(campaign_dir;
            batch_count = 2, batch_size = 2)
        @test specification["expected_result_count"] == 4
        interrupted = run_multitopology_campaign_worker_v90(campaign_dir, 1;
            stop_after_candidates = 1, checkpoint_interval = 1)
        @test interrupted["status"] == "interrupted"
        open(interrupted["partial_path"], "a") do io
            write(io, "{\"truncated_tail\":")
        end
        resumed = run_multitopology_campaign_worker_v90(campaign_dir, 1;
            checkpoint_interval = 1)
        @test resumed["status"] == "complete"
        @test resumed["result_count"] == 2
        second = run_multitopology_campaign_worker_v90(campaign_dir, 2;
            checkpoint_interval = 1)
        @test second["status"] == "complete"
        cache_audit = audit_multitopology_campaign_cache_replay_v90(campaign_dir)
        @test cache_audit["status"] == "pass"
        @test all(check -> check["cache_hit_result_invariant"] === true,
            cache_audit["checks"])
        merged = merge_multitopology_campaign_v90(campaign_dir)
        @test merged["status"] == "complete"
        @test merged["result_count"] == 4
        @test merged["unique_solver_inputs"] == 4
        @test merged["actual_solver_inputs_unique_fraction"] == 1.0
        @test merged["hard_survivor_capability_cell_count"] == 2
        @test merged["batch_ranges_no_gap_or_overlap"] === true
        @test merged["cache_replay_audit"]["status"] == "pass"
        @test merged["deep_budget"]["scheduled_hard_gate_candidates"] == 2
        sealed = run_universal_multitopology_acceptance_v90(anchors;
            campaign_merge = merged)
        @test sealed["implementation_acceptance_status"] == "pass"
        @test sealed["credible_large_range_search_claim_authorized"] === false
    end
end
