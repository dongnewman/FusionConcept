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
        "candidate_biot_savart_poincare_periodic_axis_fourier_surface_v2"
    @test length(gate.poincare_evidence["traces"]) == 3
    artifact = run_v80_poincare_frontier_v81([9283, 4148];
        target_toroidal_turns = 2, steps_per_turn = 40)
    @test artifact["status"] == "complete"
    @test artifact["candidate_count"] == 2
    @test artifact["uncaught_exception_count"] == 0
    @test artifact["winner"] !== nothing
    @test artifact["device_family_routing_used"] == false

    region = Dict{String,Any}("major_radius_m" => 3.0,
        "minor_radius_m" => 0.65)
    boundary = Dict{String,Any}("major_radius_m" => 3.0,
        "minor_radius_r_m" => 0.70, "minor_radius_z_m" => 0.60,
        "helical_axis_r_m" => 0.10, "helical_axis_z_m" => 0.05,
        "field_periods" => 2, "boundary_model" => "test_periodic_boundary")
    start = FusionConceptAI._v81_boundary_start_point(region, boundary, 0.35)
    frame = FusionConceptAI._v81_boundary_frame(region, boundary, start)
    @test frame.normalized_minor_radius ≈ 0.35
    @test frame.boundary_model == "test_periodic_boundary"
    phi = pi / 4
    axis_r = 3.0 + 0.10 * cos(2phi)
    axis_z = 0.05 * sin(2phi)
    point = [(axis_r + 0.30 * 0.70) * cos(phi),
        (axis_r + 0.30 * 0.70) * sin(phi), axis_z]
    @test FusionConceptAI._v81_boundary_frame(region, boundary,
        point).normalized_minor_radius ≈ 0.30
end
