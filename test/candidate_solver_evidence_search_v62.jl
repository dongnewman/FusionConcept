using Test
using JSON3
using FusionConceptAI

@testset "candidate-bound evidence producers v62" begin
    root = normpath(joinpath(@__DIR__, ".."))
    seeds = load_genomes(joinpath(root, "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    for index in (1, 844, 3860, 8002)
        v61 = evaluate_regional_solver_candidate_v61(context, index)
        bundle = compile_candidate_solver_judgment_input_v62(context, index)
        genome = bundle["candidate"].prescreen.compiled.genome
        judgment = evaluate_uniform_judgment_v62(bundle["judgment_input"])
        @test genome.physics_hash != v61.prescreen.compiled.genome.physics_hash
        @test evidence_ready_contract_audit_v62(genome)["status"] == "ready"
        @test !isempty(genome.normalized["species_state_contract_v1"]["species_records"])
        @test all(item -> haskey(item, "reaction_feedback_reserve"),
            [item for item in genome.normalized["regional_solver_contract_v1"]["actuator_sizing_records"]
                if String(item["capability"]) in ("particle_source", "radiation_control",
                    "deposited_energy_source")])
        @test only(stage for stage in judgment["stages"] if
            stage["stage_id"] == "physical_description_completeness")["status"] == "pass"
        @test only(stage for stage in judgment["stages"] if
            stage["stage_id"] == "perturbation_and_stability")["status"] == "pass"
        @test bundle["transport_result"]["reaction_feedback_closure_status"] in
            ("converged_state_reaction_actuator_balance",
                "unknown_reaction_operator_not_applicable",
                "fail_actuator_capacity_shortfall")
        @test Set(String(item["role"]) for item in bundle["plant_power_ledger"]["terms"]) ==
            Set(["fusion", "drive", "loss", "recirculating"])
        @test length(bundle["engineering_result"]["checks"]) == 11
        @test all(id -> any(item -> item["role_id"] == id,
            bundle["engineering_result"]["output_roles"]),
            ("heat_flux", "field_strength", "stress", "quench", "fuel_cycle",
                "component_lifetime"))
        @test length(bundle["plant_power_ledger"]["plant_roles"]) == 11
        @test length(bundle["vvuq_result"]["checks"]) == 6
        @test judgment["promotion_authorized"] === false
        @test judgment["decision"] != "pass"
        @test all(==("pass"), values(FusionConceptAI._v62_producer_gate(bundle, judgment)))
    end
    source = read(joinpath(root, "src", "candidate_solver_evidence_runtime_v1.jl"), String) *
        read(joinpath(root, "src", "search", "evidence_ready_genome_grammar_v62.jl"), String) *
        read(joinpath(root, "src", "search", "candidate_solver_evidence_search_v62.jl"), String)
    @test !occursin("genome.family", source)
    @test !occursin("family ==", source)
    @test occursin("independent", lowercase(source))
    for name in ("species_state_contract_v1.schema.json",
            "candidate_solver_evidence_bundle_v1.schema.json")
        schema = JSON3.read(read(joinpath(root, "schemas", name), String))
        @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
    end
end
