@testset "family-neutral million-scale topology campaign v91" begin
    first_topology = generate_family_neutral_topology_v91(1; relabel_nonce = 3)
    relabeled = generate_family_neutral_topology_v91(1; relabel_nonce = 29)
    distinct = generate_family_neutral_topology_v91(2; relabel_nonce = 3)
    @test validate_family_neutral_topology_v91(first_topology)["status"] == "pass"
    @test isomorphic_family_neutral_topology_v91(first_topology, relabeled)
    @test first_topology["isomorphism_hash"] == relabeled["isomorphism_hash"]
    @test !isomorphic_family_neutral_topology_v91(first_topology, distinct)

    hashes = Set{String}()
    for index in 1:4096
        topology = generate_family_neutral_topology_v91(index;
            relabel_nonce = mod(index, 17) + 1)
        push!(hashes, topology["isomorphism_hash"])
    end
    @test length(hashes) == 4096

    input = compile_candidate_bound_screen_input_v91(first_topology, 1)
    @test length(input["structural_gene_consumers"]) == 41
    @test length(input["basis_consumers"]) == 8
    @test input["family_name_parent_routing_used"] === false
    screen = solve_candidate_bound_screen_v91(input)
    @test screen["status"] == "pass"
    @test screen["normalized_residual"] <=
        V91_PREREGISTERED_GATES["screen_residual_tolerance"]
    @test screen["independent_balance_error"] <=
        V91_PREREGISTERED_GATES["independent_balance_tolerance"]

    survivor_index = 3052
    survivor_record = compile_v91_campaign_record(survivor_index)
    @test survivor_record["hard_gate_survivor"] === true
    catalog = Dict("search_date" => "2026-08-27",
        "search_scope" => "unit-test mapped references",
        "replay_record" => Dict("queries" => ["unit-test"]),
        "references" => [Dict("reference_id" => "control",
            "source_url" => "https://example.invalid/control",
            "source_title" => "control", "mapped_region_count" => 2,
            "mapping_scope" => "unit-test")])
    dossier = audit_hard_gate_survivor_v91(survivor_index, catalog)
    @test dossier["classification"]["novel_topology_candidate"] === true
    @test dossier["classification"][
        "computationally_credible_fusion_device_concept"] === false
    @test dossier["numerical_vvuq_status"] == "pass"
    @test dossier["validation_vvuq_status"] == "unknown"
    @test dossier["engineering_obligations_status"] == "unsupported"

    mktempdir() do root
        campaign = compile_multitopology_campaign_v91(root;
            campaign_id = "v91-test-64", tier = "pilot",
            total_requests = 64, shard_size = 32)
        @test campaign["preregistered_gate_hash"] ==
            canonical_hash(V91_PREREGISTERED_GATES)
        recovery = perform_v91_recovery_drill(root; interruption_count = 7)
        @test recovery["status"] == "pass"
        executed = run_multitopology_campaign_all_v91(root; threaded = false,
            checkpoint_interval = 8)
        @test executed["status"] == "complete"
        merged = merge_multitopology_campaign_v91(root)
        @test merged["result_count"] == 64
        @test merged["unique_nonisomorphic_topologies"] == 64
        @test merged["unique_solver_inputs"] == 64
        @test merged["fractions"]["gene_consumption_fraction"] == 1.0
        @test merged["fractions"]["basis_consumption_fraction"] == 1.0
        @test merged["qualification_gates"]["canonical_relabel_invariance"]
        @test merged["qualification_gates"]["deterministic_replay"]
        @test merged["qualification_gates"]["recovery"]
    end
end
