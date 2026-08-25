@testset "Candidate engineering grammar and search v63" begin
    seeds = load_genomes(joinpath(@__DIR__, "..", "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    candidate = evaluate_engineering_ready_candidate_v63(context, 1)
    audit = engineering_ready_contract_audit_v63(candidate.prescreen.compiled.genome)
    @test audit["status"] == "pass"
    @test audit["family_label_used"] == false
    bundle = compile_candidate_solver_judgment_input_v63(context, 1;
        discretization_levels = [32, 64])
    judgment = evaluate_uniform_judgment_v63(bundle["judgment_input"])
    gates = FusionConceptAI._v63_producer_gate(bundle, judgment)
    @test all(==("pass"), values(gates))
    @test bundle["engineering_manifests"]["status"] == :pass
    @test bundle["engineering_multiphysics_result"].status in (:pass, :fail)
    @test length(bundle["engineering_multiphysics_result"].plant_power_roles) == 3
    @test all(item -> item["status"] == "complete",
        bundle["engineering_multiphysics_result"].plant_power_roles)
    @test bundle["engineering_load_context"]["status"] == "complete"
    @test judgment["chain_id"] == "uniform_fusion_judgment_chain_v63"
    @test judgment["family_or_parent_used_for_routing"] == false
    @test judgment["promotion_authorized"] == false
end
