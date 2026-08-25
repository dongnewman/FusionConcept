using Test

@testset "v71 candidate-bound physical component realization" begin
    topology = generate_graph_native_topology_v69(73792)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    @test compilation.status == :pass
    binding_a = generate_physical_parameter_binding_v71(topology, 73792)
    binding_b = generate_physical_parameter_binding_v71(topology, 73792)
    @test canonical_hash(binding_a) == canonical_hash(binding_b)
    realization = compile_physical_device_realization_v71(topology, compilation;
        parameter_binding = binding_a)
    @test realization.completeness == :complete
    @test realization.conclusion == :unknown
    @test length(realization.components) == length(topology.ports)
    @test length(realization.port_mappings) == length(topology.ports)
    @test length(realization.dependency_mappings) == length(topology.dependencies)
    @test isempty(realization.missing_requirements)
    @test length(realization.realization_hash) == 64
    @test Set(String(item["bound_port_id"]) for item in realization.components) ==
        Set(String(item["port_id"]) for item in topology.ports)
    coils = [item for item in realization.components if
        item["component_kind"] == "finite_filament_coil_array_v1"]
    @test !isempty(coils)
    @test all(!isempty(item["loops"]) for item in coils)
    @test all(length(loop["centerline_m"]) == 65 for item in coils for loop in item["loops"])
end

@testset "v71 symmetry-capability field realizers" begin
    helical_topology = generate_graph_native_topology_v69(1)
    @test helical_topology.symmetry == "helical"
    helical_compilation = compile_graph_native_topology_candidate_v69(helical_topology)
    helical_binding = generate_physical_parameter_binding_v71(helical_topology, 1)
    helical = compile_physical_device_realization_v71(helical_topology,
        helical_compilation; parameter_binding = helical_binding)
    helical_coils = [item for item in helical.components if
        item["component_kind"] == "finite_filament_coil_array_v1"]
    @test all(item["winding_basis"] ==
        "closed_toroidal_helical_filament_basis_v1" for item in helical_coils)
    @test all(length(loop["centerline_m"]) == 193 for item in helical_coils
        for loop in item["loops"])

    rotational_topology = generate_graph_native_topology_v69(35)
    @test rotational_topology.symmetry == "rotational"
    rotational_compilation = compile_graph_native_topology_candidate_v69(
        rotational_topology)
    rotational_binding = generate_physical_parameter_binding_v71(rotational_topology, 35)
    rotational = compile_physical_device_realization_v71(rotational_topology,
        rotational_compilation; parameter_binding = rotational_binding)
    rotational_coils = [item for item in rotational.components if
        item["component_kind"] == "finite_filament_coil_array_v1"]
    @test all(item["winding_basis"] == "distributed_poloidal_loop_array_v1"
        for item in rotational_coils)
end

@testset "v71 physical realization fails closed" begin
    topology = generate_graph_native_topology_v69(73792)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    binding = generate_physical_parameter_binding_v71(topology, 73792)
    delete!(binding, "field_current_a")
    incomplete = compile_physical_device_realization_v71(topology, compilation;
        parameter_binding = binding)
    @test incomplete.completeness == :incomplete
    @test incomplete.conclusion == :unknown
    @test "missing_physical_parameter:field_current_a" in incomplete.missing_requirements

    registry = default_physical_component_registry_v71()
    without_field = compile_physical_component_registry_v71([
        capability for capability in registry.capabilities if
            capability.port_kind != "field_source"])
    complete_binding = generate_physical_parameter_binding_v71(topology, 73792)
    unsupported = compile_physical_device_realization_v71(topology, compilation;
        parameter_binding = complete_binding, registry = without_field)
    @test unsupported.completeness == :incomplete
    @test unsupported.conclusion == :unsupported
    @test any(startswith(reason, "unsupported_physical_realizer") for
        reason in unsupported.missing_requirements)
end

@testset "v71 physical field, particle and plasma screen" begin
    topology = generate_graph_native_topology_v69(73792)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    binding = generate_physical_parameter_binding_v71(topology, 73792)
    realization = compile_physical_device_realization_v71(topology, compilation;
        parameter_binding = binding)
    region = first(realization.geometry["regions"])
    point = region["geometry_class"] == "toroidal_volume_v1" ?
        [Float64(region["major_radius_m"]), 0.0, 0.0] : Float64.(region["center_m"])
    field = finite_filament_field_v71(realization, point)
    cache = compile_finite_filament_field_cache_v71(realization)
    cached_field = finite_filament_field_v71(cache, point)
    @test length(field) == 3
    @test all(isfinite, field)
    @test field ≈ cached_field rtol = 1.0e-13
    @test size(cache.midpoint_m, 2) > 0
    screen = screen_physical_device_v71(realization, binding;
        particle_count = 4, step_count = 16)
    @test screen.completeness == :complete
    @test screen.conclusion in (:screen_pass, :screen_fail, :screen_unknown)
    @test Set(keys(screen.gate_statuses)) == Set(("finite_field",
        "collisionless_particle_retention", "dt_power_balance_proxy",
        "conductor_current_density", "magnetic_stress", "heat_rejection_capacity"))
    @test screen.required_gate_count == 6
    @test screen.passed_gate_count == count(==("pass"), values(screen.gate_statuses))
    @test screen.particle_evidence["collision_model"] == "not_included"
    @test 0.0 <= screen.particle_evidence["duration_coverage_fraction"] <= 1.0
    @test 0.0 <= screen.particle_evidence["retained_fraction_wilson_lower_95"] <= 1.0
    @test screen.plasma_evidence["transport_closure"] == "not_included"
    @test length(screen.evidence_hash) == 64
end

@testset "v71 graph-to-device search is on the main candidate chain" begin
    artifact = run_physical_device_search_v71(1, 4;
        particle_count = 2, step_count = 8)
    @test artifact["status"] == "complete"
    @test artifact["raw_candidate_count"] == 4
    @test artifact["evaluated_physical_candidate_count"] > 0
    @test artifact["uncaught_exception_count"] == 0
    @test artifact["winner"] !== nothing
    @test artifact["device_family_routing_used"] == false
    @test all(haskey(row, "physical_component_count") for row in
        artifact["candidate_rows"])
end
