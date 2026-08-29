using Test
using FusionConceptAI

@testset "v117 channel thermal hydraulics" begin
    root = normpath(joinpath(@__DIR__, ".."))
    assemblies = select_v116_survivor_assemblies_v117(root)
    @test length(assemblies) > 5
    assembly = first(assemblies); overlay = first(generate_channel_overlays_v117(assembly))
    @test length(generate_channel_overlays_v117(assembly)) == 30
    graph = compile_coolant_channel_graph_v117(assembly, overlay; points = 17)
    assembled = assemble_graph_residual_jacobian_v94(graph, FusionConceptAI._v117_registry())
    @test assembled.status == "closed"
    @test solve_graph_system_v94(assembled)["status"] == "pass"
    empty_registry = OperatorProviderRegistryV94()
    missing = assemble_graph_residual_jacobian_v94(graph, empty_registry)
    @test missing.status == "unsupported"
    @test !missing.solver_allowed
end
