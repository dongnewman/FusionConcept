using Test

@testset "v81 candidate-bound Poincare flux-surface gate" begin
    topology = generate_graph_native_topology_v69(72)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    binding = generate_modular_multiharmonic_binding_v80(topology, 72, 9283)
    realization = compile_modular_multiharmonic_realization_v80(topology,
        compilation; parameter_binding = binding)
    screen = screen_physical_device_v71(realization, binding;
        particle_count = 1, step_count = 1, required_transit_fraction = 1.0)
    gate = evaluate_poincare_flux_surface_gate_v81(realization, screen, binding;
        target_toroidal_turns = 4, steps_per_turn = 60,
        fourier_order = 1, bin_count = 4)
    @test gate.realization_hash == realization.realization_hash
    @test gate.conclusion in (:fail, :unknown)
    @test gate.poincare_evidence["model_id"] ==
        "candidate_biot_savart_poincare_fourier_surface_v1"
    @test length(gate.poincare_evidence["traces"]) == 3
    artifact = run_v80_poincare_frontier_v81([9283, 4148];
        target_toroidal_turns = 2, steps_per_turn = 40)
    @test artifact["status"] == "complete"
    @test artifact["candidate_count"] == 2
    @test artifact["uncaught_exception_count"] == 0
    @test artifact["winner"] !== nothing
    @test artifact["device_family_routing_used"] == false
end
