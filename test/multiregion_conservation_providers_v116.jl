using Test
using FusionConceptAI

@testset "v116 multi-region conservation providers" begin
    root = normpath(joinpath(@__DIR__, ".."))
    frontier = load_v114_provider_frontier_v115(root)
    candidate = first(frontier)["candidate"]
    graph = compile_core_edge_transport_graph_v116(candidate; points = 33)
    assembly = assemble_graph_residual_jacobian_v94(graph,
        FusionConceptAI._v116_linear_registry())
    @test assembly.status == "closed"
    @test assembly.solver_allowed
    solve = solve_graph_system_v94(assembly)
    @test solve["status"] == "pass"
    missing_interface = assemble_graph_residual_jacobian_v94(graph,
        FusionConceptAI._v116_linear_registry(; include_interface = false))
    @test missing_interface.status == "unsupported"
    @test !missing_interface.solver_allowed
    @test solve_graph_system_v94(missing_interface)["solver_executed"] === false
    transport = execute_core_edge_transport_provider_v116(candidate)
    @test transport["status"] in ("pass", "fail")
    @test transport["unsupported_candidate_classification_used"] === false
    selected = select_v115_source_assemblies_v116(root)
    @test length(selected) == 6
    exhaust = execute_sol_exhaust_provider_v116(first(selected), candidate)
    @test exhaust["status"] in ("pass", "fail")
    @test exhaust["unsupported_candidate_classification_used"] === false
end
