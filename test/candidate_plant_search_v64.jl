@testset "Candidate plant grammar and search v64" begin
    seeds = load_genomes(joinpath(@__DIR__, "..", "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    candidate = evaluate_plant_ready_candidate_v64(context, 1)
    audit = plant_ready_contract_audit_v64(candidate.prescreen.compiled.genome)
    @test audit["status"] == "pass"
    @test audit["family_label_used"] == false
    bundle = compile_candidate_solver_judgment_input_v64(context, 1;
        discretization_levels = [32, 64])
    judgment = evaluate_uniform_judgment_v64(bundle["judgment_input"])
    gates = FusionConceptAI._v64_producer_gate(bundle, judgment)
    @test all(==("pass"), values(gates))
    @test bundle["plant_subsystem_manifest"].status == :pass
    @test bundle["plant_subsystem_result"].status in (:pass, :fail)
    ledger = bundle["plant_power_ledger_result"]
    @test Set(String(item["role_id"]) for item in ledger.plant_roles) ==
        Set(PLANT_SUBSYSTEM_ROLE_IDS_V1)
    @test all(item -> item["status"] in ("complete", "not_applicable"),
        ledger.plant_roles)
    @test ledger.closure["complete"] == true
    @test ledger.status in (:pass, :fail, :unknown)
    @test ledger.sign_status != "unknown_incomplete_roles"
    @test judgment["chain_id"] == "uniform_fusion_judgment_chain_v64"
    @test judgment["family_or_parent_used_for_routing"] == false
    @test judgment["promotion_authorized"] == false
end
