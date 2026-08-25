@testset "Universal candidate external-resource search v67" begin
    seeds = load_genomes(joinpath(@__DIR__, "..", "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)

    icf = compile_candidate_solver_judgment_input_v67(context, 180;
        discretization_levels = [32, 64])
    icf_requirements = icf["external_resource_requirements"]["requirements"]
    @test any(item -> item["requirement_id"] ==
        "independent_numerical_replication:radiation_hydrodynamics", icf_requirements)
    @test any(item -> item["requirement_id"] ==
        "material_data:equation_of_state", icf_requirements)
    @test any(item -> item["requirement_id"] ==
        "material_data:multigroup_opacity", icf_requirements)
    @test Set(icf["external_resource_requirements"]["candidate_input_blockers"]) ==
        Set(["pulsed_rhd:equation_of_state", "pulsed_rhd:multigroup_opacity"])
    @test icf["stage8_resource_execution_eligible_v67"] === false

    mirror = compile_candidate_solver_judgment_input_v67(context, 3842;
        discretization_levels = [32, 64])
    mirror_requirements = mirror["external_resource_requirements"]["requirements"]
    @test any(item -> item["requirement_id"] ==
        "independent_numerical_replication:open_field_kinetic_transport",
        mirror_requirements)
    @test !any(item -> startswith(item["requirement_id"], "material_data:"),
        mirror_requirements)

    mtf = compile_candidate_solver_judgment_input_v67(context, 4049;
        discretization_levels = [32, 64])
    mtf_requirements = mtf["external_resource_requirements"]["requirements"]
    @test mtf["pulsed_rhd_manifest"]["status"] == "not_applicable"
    @test any(item -> item["requirement_id"] ==
        "independent_numerical_replication:radiation_hydrodynamics", mtf_requirements)
    @test any(item -> item["requirement_id"] ==
        "material_data:equation_of_state", mtf_requirements)
    @test any(contains("time_semantics:"),
        mtf["external_resource_requirements"]["candidate_input_blockers"])

    judgment = evaluate_uniform_judgment_v67(mirror["judgment_input"])
    gates = FusionConceptAI._v67_producer_gate(mirror, judgment)
    @test all(==("pass"), values(gates))
    @test judgment["chain_id"] == "uniform_fusion_judgment_chain_v67"
    @test isempty(select_stage8_ready_queue_v67(Dict(
        "bundles" => [icf, mirror, mtf],
        "judgments" => [evaluate_uniform_judgment_v67(icf["judgment_input"]),
            judgment, evaluate_uniform_judgment_v67(mtf["judgment_input"])])))
end
