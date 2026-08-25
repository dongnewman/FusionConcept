using Test

@testset "v77 local helical flux-surface search" begin
    topology = generate_graph_native_topology_v69(72)
    binding = generate_local_helical_flux_binding_v77(topology, 72, 49, 1)
    @test binding["parent_candidate_binding_hash"] isa String
    @test binding["helical_current_pattern"] in ("co_directional", "alternating")
    artifact = run_local_helical_flux_surface_search_v77(72, 49, 1, 3;
        target_toroidal_turns = 0.5, steps_per_turn = 60)
    @test artifact["status"] == "complete"
    @test artifact["local_variant_count"] == 3
    @test artifact["uncaught_exception_count"] == 0
    @test artifact["winner"] !== nothing
    @test artifact["device_family_routing_used"] == false
end
