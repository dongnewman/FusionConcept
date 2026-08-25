@testset "Topology-capability external kinetic backend contract v1" begin
    hash_a = repeat("a", 64)
    hash_b = repeat("b", 64)
    hash_c = repeat("c", 64)
    hash_d = repeat("d", 64)
    contract = ExternalKineticBackendContractV1(
        backend_id = "public_cql3d_mainline_v1",
        backend_version = "3565fee",
        source_commit = "3565fee6974deff69371321d8a053593eae1562d",
        source_tree_hash = "209dce964ce32dcd3ddbb37809e18eeb20e064d7",
        phase_space_coordinates = ["generalized_radius", "speed", "pitch_angle"],
        required_input_channels = ["magnetic_geometry", "species_state", "source"],
        available_output_channels = ["distribution", "moments"],
        topology_capabilities = ["toroidal_multiradius", "mirror_single_radius"],
        build_regression_verified = true)
    @test !contract.promotion_authority
    @test contract.build_regression_verified
    @test !contract.exact_published_variant_verified

    blocked = compile_external_kinetic_backend_assessment_v1(contract;
        design_id = "candidate", genome_physics_hash = hash_a,
        executable_candidate_physics_hash = hash_b,
        source_artifact_hash = hash_c, source_result_status = :pass,
        candidate_source_binding_verified = true)
    @test !blocked.c2_phase_space_source_authorized
    @test !blocked.c2_kinetic_state_authorized
    @test blocked.claim_ceiling == "backend_build_regression_only"
    @test "compile_exact_candidate_backend_input" in blocked.evidence_tasks
    @test "verify_backend_applicability_to_candidate_topology" in blocked.evidence_tasks

    passed = compile_external_kinetic_backend_assessment_v1(contract;
        design_id = "candidate", genome_physics_hash = hash_a,
        executable_candidate_physics_hash = hash_b,
        input_artifact_hash = hash_c, equilibrium_artifact_hash = hash_d,
        source_artifact_hash = hash_a, output_artifact_hash = hash_b,
        source_result_status = :pass, process_exit_success = true,
        normal_completion_marker_verified = true, candidate_input_compiled = true,
        candidate_equilibrium_binding_verified = true,
        candidate_source_binding_verified = true,
        candidate_topology_applicability_verified = true, solver_completed = true,
        physical_distribution_normalization_verified = true,
        particle_conservation_verified = true, energy_conservation_verified = true,
        resolution_convergence_verified = true, known_topology_control_verified = true,
        ambipolar_response_verified = true, end_loss_flux_verified = true)
    @test passed.c2_phase_space_source_authorized
    @test passed.c2_kinetic_state_authorized
    @test passed.c2_ambipolar_response_authorized
    @test passed.c2_end_loss_authorized
    @test isempty(passed.evidence_tasks)
    @test passed.claim_ceiling == "C2_candidate_specific_kinetic_state"
    serialized = external_kinetic_backend_assessment_to_dict_v1(passed)
    @test serialized["assessment_hash"] == passed.assessment_hash
    @test !serialized["promotion_authorized"]

    @test_throws ArgumentError ExternalKineticBackendContractV1(
        backend_id = "bad", backend_version = "bad", source_commit = "bad",
        source_tree_hash = contract.source_tree_hash,
        phase_space_coordinates = ["v"], required_input_channels = ["source"],
        available_output_channels = ["f"], topology_capabilities = ["open"],
        build_regression_verified = false)
    @test_throws ArgumentError ExternalKineticBackendContractV1(
        backend_id = "bad", backend_version = "bad",
        source_commit = contract.source_commit, source_tree_hash = contract.source_tree_hash,
        phase_space_coordinates = ["v"], required_input_channels = ["source"],
        available_output_channels = ["f"], topology_capabilities = ["open"],
        build_regression_verified = false, promotion_authority = true)
    @test_throws ArgumentError compile_external_kinetic_backend_assessment_v1(
        contract; design_id = "candidate", genome_physics_hash = hash_a,
        executable_candidate_physics_hash = hash_b, source_result_status = :invalid)
end
