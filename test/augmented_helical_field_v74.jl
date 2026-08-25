using Test

@testset "v74 augmented helical realization and search" begin
    topology = generate_graph_native_topology_v69(72)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    binding = generate_augmented_helical_parameter_binding_v74(topology, 72, 1)
    realization = compile_augmented_helical_realization_v74(topology, compilation;
        parameter_binding = binding)
    coils = [item for item in realization.components if
        item["component_kind"] == "finite_filament_coil_array_v1"]
    @test realization.completeness == :complete
    @test !isempty(coils)
    @test all(item["winding_basis"] ==
        "combined_toroidal_base_and_helical_perturbation_v1" for item in coils)
    @test all(any(loop["winding_role"] == "toroidal_field_base"
        for loop in item["loops"]) for item in coils)
    @test all(any(loop["winding_role"] == "helical_transform_perturbation"
        for loop in item["loops"]) for item in coils)
    artifact = run_augmented_helical_field_search_v74(72, 1, 3;
        target_toroidal_turns = 0.5, steps_per_turn = 60)
    @test artifact["status"] == "complete"
    @test artifact["variant_count"] == 3
    @test artifact["uncaught_exception_count"] == 0
    @test artifact["winner"] !== nothing
    @test artifact["device_family_routing_used"] == false
end
