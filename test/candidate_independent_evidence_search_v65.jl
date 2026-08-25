@testset "Candidate independent evidence search v65" begin
    seeds = load_genomes(joinpath(@__DIR__, "..", "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    bundle = compile_candidate_solver_judgment_input_v65(context, 1;
        discretization_levels = [32, 64])
    judgment = evaluate_uniform_judgment_v65(bundle["judgment_input"])
    gates = FusionConceptAI._v65_producer_gate(bundle, judgment)
    @test all(==("pass"), values(gates))
    @test bundle["cross_code_replication"]["status"] == "unknown"
    @test bundle["experimental_anchor"]["status"] == "unknown"
    @test any(item -> item["check_id"] == "cross_code_replication" &&
        item["status"] == "unknown", bundle["vvuq_result"]["checks"])
    @test any(item -> item["check_id"] == "experimental_anchor" &&
        item["status"] == "unknown", bundle["vvuq_result"]["checks"])
    @test judgment["chain_id"] == "uniform_fusion_judgment_chain_v65"
    @test judgment["promotion_authorized"] == false
    gate = Dict("bundles" => [bundle], "judgments" => [judgment])
    queue = select_independent_evidence_queue_v65(gate; maximum_candidates = 1)
    @test length(queue) == 1
    @test queue[1]["status"] == "queued_external_work_not_completed"
    @test queue[1]["family_label_used"] == false
end
