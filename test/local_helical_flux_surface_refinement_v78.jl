using Test

@testset "v78 local helical flux-surface refinement" begin
    topology = generate_graph_native_topology_v69(72)
    binding = generate_local_helical_refinement_binding_v78(topology,
        72, 49, 2, 1.05, 0.01)
    @test binding["v77_parent_candidate_binding_hash"] isa String
    @test binding["v77_parent_local_seed"] == 2
    artifact = run_local_helical_flux_surface_refinement_v78(72, 49, 2;
        current_multipliers = [1.0], radial_scale_offsets = [0.0],
        target_toroidal_turns = 0.25, steps_per_turn = 40)
    @test artifact["status"] == "complete"
    @test artifact["grid_candidate_count"] == 1
    @test artifact["uncaught_exception_count"] == 0
    @test artifact["winner"] !== nothing
    @test artifact["device_family_routing_used"] == false
end
