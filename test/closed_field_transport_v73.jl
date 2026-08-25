using Test

@testset "v73 rotational field candidate is drift-falsified" begin
    topology = generate_graph_native_topology_v69(35)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    binding = generate_physical_parameter_binding_v71(topology, 35)
    realization = compile_physical_device_realization_v71(topology, compilation;
        parameter_binding = binding)
    screen = screen_physical_device_v71(realization, binding;
        particle_count = 8, step_count = 2000, required_transit_fraction = 1.0)
    gate = evaluate_closed_field_transport_gate_v73(realization, screen, binding;
        target_toroidal_turns = 1.0, steps_per_turn = 180)
    @test gate.completeness == :complete
    @test gate.conclusion == :fail
    @test gate.classification_code in (
        "candidate_field_lines_escape_toroidal_volume",
        "insufficient_rotational_transform_for_curvature_drift_cancellation",
        "excessive_flux_surface_radial_excursion")
    @test gate.drift_evidence["optimistic_uncompensated_drift_exit_time_s"] <
        gate.drift_evidence["required_energy_confinement_s"]
    @test gate.field_line_evidence["minimum_absolute_rotational_transform"] < 0.02 ||
        gate.field_line_evidence["any_trace_escaped"]
end

@testset "v73 non-toroidal route is explicit" begin
    topology = generate_graph_native_topology_v69(98)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    binding = generate_physical_parameter_binding_v71(topology, 98)
    realization = compile_physical_device_realization_v71(topology, compilation;
        parameter_binding = binding)
    screen = screen_physical_device_v71(realization, binding;
        particle_count = 2, step_count = 8)
    gate = evaluate_closed_field_transport_gate_v73(realization, screen, binding)
    @test gate.completeness == :incomplete
    @test gate.conclusion == :unsupported
    @test gate.classification_code == "not_applicable_non_toroidal_geometry"
end
