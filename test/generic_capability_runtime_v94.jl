using Test
using FusionConceptAI

@testset "v94 generic multiregion capability runtime" begin
    root = normpath(joinpath(@__DIR__, ".."))
    @test verify_protocol_seal_v93(root)["status"] == "pass"
    @test verify_v93_pvw_protocol_seal_v1(root)["status"] == "pass"

    registry = default_operator_provider_registry_v94()
    manifest = provider_registry_manifest_v94(registry)
    @test manifest["provider_count"] == 7
    @test manifest["routing_unit"] == "single_declared_obligation"
    @test audit_provider_anti_specialization_v94(root)["status"] == "pass"
    @test all(item -> item["routing_unit"] == "single_declared_obligation",
        manifest["providers"])

    field_registry = OperatorProviderRegistryV94()
    register_provider_v94!(field_registry, ProviderCapabilityV94(
        "test_scalar_recipe", "available", String[], ["compute_scalar"], String[],
        String[], [0], ["scalar"], ["field_value"], "test"),
        requirement -> residual_fragment_v94(requirement.requirement_key, String[], [], []))
    field_plan = plan_field_dependency_closure_v94([
        Dict("field_key" => "source", "class" => "recovered", "value" => 1.0),
        Dict("field_key" => "geometry", "class" => "derived", "dependencies" => ["source"]),
        Dict("field_key" => "closure", "class" => "computable", "dependencies" => ["geometry"],
            "operator" => "compute_scalar", "dimension" => 0, "coordinate" => "scalar"),
        Dict("field_key" => "measurement", "class" => "external_evidence"),
        Dict("field_key" => "missing", "class" => "computable", "dependencies" => ["source"],
            "operator" => "not_registered", "dimension" => 0, "coordinate" => "scalar")];
        registry = field_registry)
    field_classes = Dict(item["field_key"] => item["class"] for item in field_plan.records)
    @test field_classes["source"] == "recovered"
    @test field_classes["geometry"] == "derived"
    @test field_classes["closure"] == "computable"
    @test field_classes["measurement"] == "external_evidence"
    @test field_classes["missing"] == "unsupported"
    @test field_plan.recompute_order == ["geometry", "closure", "missing"]
    cyclic = plan_field_dependency_closure_v94([
        Dict("field_key" => "a", "class" => "derived", "dependencies" => ["b"]),
        Dict("field_key" => "b", "class" => "derived", "dependencies" => ["a"])])
    @test cyclic.status == "incomplete"
    @test all(item -> item["class"] == "unsupported", cyclic.records)

    problem, _ = manufactured_pvw_problem_v1()
    graph = compile_pvw_graph_v94(problem; points = 33)
    assembly = assemble_graph_residual_jacobian_v94(graph, registry)
    @test assembly.status == "closed"
    @test assembly.solver_allowed
    @test assembly.field_plan.status == "incomplete" # validation evidence is independent
    solve = solve_graph_system_v94(assembly)
    @test solve["status"] == "pass"
    @test solve["whole_graph_closed"]
    @test solve["normalized_residual"] <= 1e-10
    @test solve["jacobian_relative_error"] <= 1e-7

    absent = deepcopy(registry)
    unregister_provider_v94!(absent, "mixed_trace_continuity_v1")
    missing_assembly = assemble_graph_residual_jacobian_v94(graph, absent)
    @test missing_assembly.status == "unsupported"
    missing_solve = solve_graph_system_v94(missing_assembly)
    @test !missing_solve["solver_executed"]
    @test !missing_solve["partial_subgraph_credit"]

    partial = compile_pvw_graph_v94(problem; points = 33,
        extra_inner_operator = "not_registered_additive")
    partial_assembly = assemble_graph_residual_jacobian_v94(partial, registry)
    @test partial_assembly.status == "unsupported"
    @test !partial_assembly.solver_allowed
    @test !solve_graph_system_v94(partial_assembly)["partial_subgraph_credit"]

    unseen = manufactured_chain_graph_v94(5; order = [4, 2, 5, 1, 3])
    unseen_assembly = assemble_graph_residual_jacobian_v94(unseen, registry)
    @test unseen_assembly.status == "closed"
    @test solve_graph_system_v94(unseen_assembly)["status"] == "pass"

    relabeled = compile_pvw_graph_v94(problem; points = 33, labels = ("", ""))
    relabeled_assembly = assemble_graph_residual_jacobian_v94(relabeled, registry)
    @test assembly.matrix == relabeled_assembly.matrix
    @test assembly.rhs == relabeled_assembly.rhs
    @test [route["selected_provider"] for route in assembly.routes] ==
        [route["selected_provider"] for route in relabeled_assembly.routes]

    stage_chain = execute_pvw_generic_stage_chain_v94(problem; registry = registry)
    @test stage_chain["stage_order"] == ["solve", "numerical_vvuq", "validation_vvuq"]
    @test stage_chain["solve"]["status"] == "pass"
    @test stage_chain["numerical_vvuq"]["status"] == "pass"
    @test stage_chain["validation_vvuq"]["status"] == "unknown_validation_domain"
    @test stage_chain["status"] == "unknown_validation_domain"
    @test stage_chain["physical_conclusion_expanded"] == false

    acceptance = run_generic_capability_acceptance_v94(root)
    @test acceptance["status"] == "pass"
    @test acceptance["controls"]["v93_preservation"]["status"] == "pass"
    @test acceptance["controls"]["invariance"]["label_erasure"]["status"] == "pass"
    @test acceptance["controls"]["invariance"]["identity_and_order_permutation"]["status"] == "pass"
    @test acceptance["controls"]["negative_controls"]["status"] == "pass"
    @test acceptance["controls"]["unseen_topology"]["status"] == "pass"
    @test acceptance["conclusions"]["experimental_validation"] == "unknown_validation_domain"
    @test acceptance["physical_conclusion_expanded"] == false
end
