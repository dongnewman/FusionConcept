using Test

@testset "v72 one-sided open-field transport falsification" begin
    candidate = evaluate_physical_device_candidate_v71(98;
        particle_count = 8, step_count = 200, required_transit_fraction = 1.0)
    @test candidate["status"] == "evaluated"
    topology = generate_graph_native_topology_v69(98)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    binding = candidate["parameter_binding"]
    realization = compile_physical_device_realization_v71(topology, compilation;
        parameter_binding = binding)
    screen = screen_physical_device_v71(realization, binding;
        particle_count = 8, step_count = 200, required_transit_fraction = 1.0)
    transport = evaluate_physical_transport_gate_v72(realization, screen, binding)
    @test transport.completeness == :complete
    @test transport.conclusion == :fail
    @test transport.classification_code ==
        "optimistic_open_field_collision_bound_below_required_tau_e"
    @test transport.applicability["device_family_routing_used"] == false
    @test transport.evidence["optimistic_collision_limited_confinement_upper_s"] <
        transport.evidence["required_energy_confinement_s"]
    @test transport.evidence["upper_to_required_ratio"] < 1.0
end

@testset "v72 frontier prefers unresolved transport over confirmed failure" begin
    specs = [
        Dict("seed" => 35, "particle_count" => 4, "step_count" => 2000,
            "required_transit_fraction" => 1.0),
        Dict("seed" => 98, "particle_count" => 4, "step_count" => 200,
            "required_transit_fraction" => 1.0),
    ]
    artifact = run_physical_frontier_v72(specs)
    @test artifact["status"] == "complete"
    @test artifact["uncaught_exception_count"] == 0
    @test artifact["winner"]["seed"] == 35
    @test artifact["winner"]["transport"]["conclusion"] == "unsupported"
    @test artifact["device_family_routing_used"] == false
end

@testset "v72 unsupported geometry remains unsupported" begin
    topology = generate_graph_native_topology_v69(1)
    @test topology.symmetry in ("rotational", "helical")
    compilation = compile_graph_native_topology_candidate_v69(topology)
    binding = generate_physical_parameter_binding_v71(topology, 1)
    realization = compile_physical_device_realization_v71(topology, compilation;
        parameter_binding = binding)
    screen = screen_physical_device_v71(realization, binding;
        particle_count = 2, step_count = 4)
    transport = evaluate_physical_transport_gate_v72(realization, screen, binding)
    @test transport.completeness == :incomplete
    @test transport.conclusion == :unsupported
    @test "candidate_bound_closed_field_transport_backend" in
        transport.missing_requirements
end
