@testset "Directed particle deposition source compiler v1" begin
    hash_a = repeat("a", 64)
    hash_b = repeat("b", 64)
    hash_c = repeat("c", 64)
    field_at(point) = (0.0, 0.0, 2.0)
    mass = 2.0 * 1.66053906660e-27
    speed = 1.0e6
    energy = 0.5 * mass * speed^2
    common = (
        design_id = "generic_directed_source_control",
        genome_physics_hash = hash_a,
        executable_candidate_physics_hash = hash_b,
        domain_id = "open_domain", actuator_id = "beam_1",
        injected_species_id = "deuterium", injected_species_mass_kg = mass,
        radial_centers_m = [0.1], axial_centers_m = [0.0],
        toroidal_angles_rad = [0.0], cell_volumes_m3_by_radius = [2.0e-3],
        energy_groups = Any[(0, energy, [0.6e6, 0.0, -0.8e6])],
        rate_records = Any[[0, 0, 0, 0, 3.0e20, 2.0e20]],
        field_at = field_at,
        candidate_binding_verified = true,
        field_candidate_binding_verified = true,
        source_candidate_binding_verified = true,
        coordinate_frame_binding_verified = true,
        resolution_verified = true,
        plasma_profile_applicability_verified = false,
        atomic_model_applicability_verified = false,
        source_kind = :candidate_solver, source_result_status = :pass,
        source_artifact_id = "runs/source.json", source_artifact_hash = hash_c,
        source_result_hash = hash_a,
        field_artifact_id = "knowledge/field.json", field_artifact_hash = hash_b,
        field_result_hash = hash_c,
        expected_ionization_rate_s = 6.0e17,
        expected_charge_exchange_conversion_rate_s = 4.0e17,
        expected_fast_ion_birth_rate_s = 1.0e18,
        expected_electron_birth_rate_s = 6.0e17,
        expected_net_same_species_ion_birth_rate_s = 6.0e17,
        expected_represented_fast_ion_birth_kinetic_power_w = 1.0e18 * energy,
        index_base = 0)
    observation = compile_directed_particle_deposition_source_v1(; common...)
    @test observation.bin_count == 1
    @test observation.candidate_phase_space_binding_verified
    @test observation.physical_source_rate_available
    @test observation.external_aggregate_audit_verified
    @test !observation.c2_phase_space_source_authorized
    @test !observation.c2_kinetic_state_authorized
    @test observation.ionization_rate_s == 6.0e17
    @test observation.charge_exchange_conversion_rate_s == 4.0e17
    @test observation.fast_ion_birth_rate_s == 1.0e18
    @test observation.net_same_species_ion_birth_rate_s == 6.0e17
    @test observation.thermal_same_species_ion_removal_rate_s == 4.0e17
    bin = only(observation.bins)
    @test bin.parallel_speed_m_s == -0.8e6
    @test bin.perpendicular_speed_m_s ≈ 0.6e6
    @test bin.signed_pitch_cosine == -0.8
    @test bin.pitch_angle_rad > pi / 2
    @test "map_charge_exchange_thermal_ion_sink_in_velocity_space" in
        observation.evidence_tasks
    @test directed_particle_deposition_source_to_dict_v1(observation)[
        "bins"][1]["parallel_speed_m_s"] == -0.8e6

    authorized = compile_directed_particle_deposition_source_v1(; common...,
        plasma_profile_applicability_verified = true,
        atomic_model_applicability_verified = true)
    @test authorized.c2_phase_space_source_authorized
    @test !authorized.c2_kinetic_state_authorized

    @test_throws ArgumentError compile_directed_particle_deposition_source_v1(;
        common..., energy_groups = Any[(0, 2.0 * energy,
            [0.6e6, 0.0, -0.8e6])])
    @test_throws ArgumentError compile_directed_particle_deposition_source_v1(;
        common..., rate_records = Any[[0, 1, 0, 0, 3.0e20, 2.0e20]])
    @test_throws ArgumentError compile_directed_particle_deposition_source_v1(;
        common..., field_at = point -> (0.0, 0.0, 0.0))
end
