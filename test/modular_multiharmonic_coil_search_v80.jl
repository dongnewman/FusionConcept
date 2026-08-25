using Test

@testset "v80 independent modular multiharmonic search" begin
    topology = generate_graph_native_topology_v69(72)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    binding = generate_modular_multiharmonic_binding_v80(topology, 72, 1)
    @test binding["modular_winding_count"] == length(binding["modular_windings"])
    @test 3 <= binding["modular_winding_count"] <= 8
    realization = compile_modular_multiharmonic_realization_v80(topology,
        compilation; parameter_binding = binding)
    field_components = [component for component in realization.components if
        component["component_kind"] == "finite_filament_coil_array_v1"]
    @test length(field_components) == 1
    @test field_components[1]["winding_basis"] ==
        "independent_modular_multiharmonic_filaments_v1"
    proxy = FusionConceptAI._v80_fast_field_proxy(realization)
    @test proxy["minimum_field_t"] > 0
    artifact = run_modular_multiharmonic_search_v80(72, 1, 3;
        shortlist_count = 2, finalist_count = 1, progress_interval = 0)
    @test artifact["status"] == "complete"
    @test artifact["searched_candidate_count"] == 3
    @test artifact["uncaught_exception_count"] == 0
    @test artifact["winner"] !== nothing
    @test artifact["device_family_routing_used"] == false
end
