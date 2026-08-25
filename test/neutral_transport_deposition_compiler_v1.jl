using Test
using FusionConceptAI

function _deposition_test_observation(; ion = 2.0, cx = 6.0, birth = 8.0,
        electron = 2.0, netion = 2.0, profile = false, atomic = false,
        geometry = false, spectrum = false, slowing = false, heating = nothing,
        same_species = true)
    compile_neutral_transport_deposition_observation_v1(
        design_id = "test", genome_physics_hash = repeat("a", 64),
        domain_id = "plasma", actuator_id = "nbi",
        injected_species_id = "deuterium", ionization_rate_s = ion,
        main_ion_charge_exchange_conversion_rate_s = cx,
        fast_ion_birth_rate_s = birth, electron_source_rate_s = electron,
        net_same_species_ion_source_rate_s = netion,
        represented_fast_ion_birth_kinetic_power_w = 10.0,
        thermalized_heating_power_w = heating,
        same_species_charge_exchange = same_species,
        source_kind = :candidate_solver, source_artifact_id = "run.json",
        source_artifact_hash = repeat("b", 64),
        source_result_hash = repeat("c", 64),
        candidate_binding_verified = true, resolution_verified = true,
        beamline_geometry_candidate_verified = geometry,
        spectrum_basis_candidate_verified = spectrum,
        plasma_profile_applicability_verified = profile,
        atomic_model_applicability_verified = atomic,
        slowing_down_computed = slowing, source_result_status = :pass)
end

@testset "Mechanism-resolved neutral deposition fails closed v1" begin
    observation = _deposition_test_observation()
    @test observation.fast_ion_birth_rate_s == 8.0
    @test observation.net_same_species_ion_source_rate_s == 2.0
    @test !observation.particle_source_c2_authorized
    @test !observation.heating_c2_authorized
    @test !observation.charge_exchange_particle_loss_mapping_authorized
    @test "replace_or_validate_plasma_profile" in observation.evidence_tasks
    @test "validate_atomic_rate_model_applicability" in observation.evidence_tasks
    @test "bind_beamline_geometry_to_executable_genome" in observation.evidence_tasks
    @test "verify_energy_group_fraction_basis" in observation.evidence_tasks
    @test_throws ArgumentError _deposition_test_observation(birth = 7.0)
    @test_throws ArgumentError _deposition_test_observation(electron = 3.0)
    @test_throws ArgumentError _deposition_test_observation(netion = 8.0)
end

@testset "Neutral deposition C2 requires state, atomic, and slowing-down gates v1" begin
    particles = _deposition_test_observation(profile = true, atomic = true,
        geometry = true, spectrum = true)
    @test particles.particle_source_c2_authorized
    @test !particles.heating_c2_authorized
    heating = _deposition_test_observation(profile = true, atomic = true,
        geometry = true, spectrum = true, slowing = true, heating = 9.0)
    @test heating.particle_source_c2_authorized
    @test heating.heating_c2_authorized
end
