using Test

@testset "v82 periodic nonplanar modular coil search" begin
    topology = generate_graph_native_topology_v69(72)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    binding = generate_periodic_modular_binding_v82(topology, 72, 1)
    @test binding["field_coil_count"] == binding["field_periods"] *
        binding["templates_per_period"]
    realization = compile_periodic_modular_realization_v82(topology, compilation;
        parameter_binding = binding)
    fields = [component for component in realization.components if
        component["component_kind"] == "finite_filament_coil_array_v1"]
    @test length(fields) == 1
    @test fields[1]["winding_basis"] == "periodic_nonplanar_modular_coils_v1"
    @test length(fields[1]["loops"]) == binding["field_coil_count"]
    artifact = run_periodic_modular_search_v82(72, 1, 4;
        shortlist_count = 2, longlist_count = 1, poincare_count = 1,
        progress_interval = 0)
    @test artifact["status"] == "complete"
    @test artifact["searched_candidate_count"] == 4
    @test artifact["uncaught_exception_count"] == 0
    @test artifact["winner"] !== nothing
    @test artifact["device_family_routing_used"] == false
end
