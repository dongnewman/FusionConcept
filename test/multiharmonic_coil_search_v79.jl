using Test

@testset "v79 multiharmonic finite-filament coil search" begin
    topology = generate_graph_native_topology_v69(72)
    binding = generate_multiharmonic_coil_binding_v79(topology, 72, 49, 1)
    @test binding["v77_parent_candidate_binding_hash"] isa String
    @test abs(binding["helical_phase_modulation_rad"]) <= 0.60
    @test abs(binding["helical_winding_current_imbalance"]) <= 0.30
    artifact = run_multiharmonic_coil_search_v79(72, 49, 1, 2;
        target_toroidal_turns = 0.25, steps_per_turn = 40)
    @test artifact["status"] == "complete"
    @test artifact["candidate_count"] == 2
    @test artifact["uncaught_exception_count"] == 0
    @test artifact["winner"] !== nothing
    @test artifact["device_family_routing_used"] == false
end
