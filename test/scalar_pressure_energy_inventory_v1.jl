using Test
using FusionConceptAI

const SPE_ROOT = normpath(joinpath(@__DIR__, ".."))
const SPE_FREEGS = joinpath(SPE_ROOT, "examples",
    "freegs_pointcoil_wall_control_genome_v1.json")

function spe_observation(rank, energy; fidelity = 2, binding = true,
        source_status = :pass, species = false, distribution = false,
        model = :scalar_isotropic_mhd)
    gamma = 5.0 / 3.0
    integral = energy * (gamma - 1.0)
    return compile_scalar_pressure_energy_observation_v1(
        design_id = "freegs_pointcoil_wall_control_v1",
        genome_physics_hash = load_genome(SPE_FREEGS).physics_hash,
        domain_id = "plasma_core", pressure_model = model,
        resolution_label = "grid_$rank", resolution_rank = rank,
        point_count = rank^2, plasma_volume_m3 = 5.0,
        pressure_volume_integral_j = integral,
        adiabatic_index = gamma, scalar_mhd_thermal_energy_j = energy,
        source_artifact_id = "candidate_pressure_result.json",
        source_artifact_hash = repeat("a", 64),
        source_result_hash = repeat(string(rank % 10), 64),
        candidate_binding_verified = binding,
        species_resolved = species, distribution_resolved = distribution,
        fidelity = fidelity, source_solver_status = source_status)
end

@testset "Scalar-pressure energy observation contract v1" begin
    item = spe_observation(1, 1.0e6)
    @test item.status == :pass
    @test item.c2_observation_authorized
    @test !item.species_resolved
    @test "resolve_species_density_profiles" in item.evidence_tasks
    @test any(contains("not a species particle inventory"), item.warnings)

    low = spe_observation(1, 1.0e6; fidelity = 1)
    @test low.status == :pass
    @test !low.c2_observation_authorized
    @test "raise_scalar_pressure_inventory_to_c2" in low.evidence_tasks
    unbound_failure = spe_observation(1, 1.0e6; binding = false,
        source_status = :fail)
    @test unbound_failure.status == :unknown
    failed = spe_observation(1, 1.0e6; source_status = :fail)
    @test failed.status == :fail
    @test_throws ArgumentError compile_scalar_pressure_energy_observation_v1(
        design_id = "x", genome_physics_hash = repeat("a", 64),
        domain_id = "core", pressure_model = :scalar_isotropic_mhd,
        resolution_label = "bad", resolution_rank = 1, point_count = 1,
        plasma_volume_m3 = 1.0, pressure_volume_integral_j = 2.0,
        adiabatic_index = 5 / 3, scalar_mhd_thermal_energy_j = 9.0,
        source_artifact_id = "x", source_artifact_hash = repeat("b", 64),
        source_result_hash = repeat("c", 64),
        candidate_binding_verified = true, species_resolved = false,
        distribution_resolved = false, fidelity = 2,
        source_solver_status = :pass)
end

@testset "Scalar-pressure energy convergence and claim boundary v1" begin
    observations = ScalarPressureEnergyObservationV1[
        spe_observation(1, 1.02e6), spe_observation(2, 1.01e6),
        spe_observation(3, 1.00e6)]
    passed = compile_scalar_pressure_energy_convergence_v1(observations;
        convergence_limit = 0.02)
    @test passed.status == :pass
    @test passed.resolution_verified
    @test passed.c2_scalar_mhd_energy_authorized
    @test !passed.complete_particle_state_authorized
    @test passed.resolution_labels == ["grid_1", "grid_2", "grid_3"]
    bundle = scalar_pressure_energy_evidence_bundle_v1(
        load_genome(SPE_FREEGS), passed)
    @test bundle.status == :pass
    @test bundle.metrics[1].value == 1.00e6
    @test bundle.claim_ceiling ==
        "C2_support_scalar_mhd_thermal_energy_only"

    nonconverged = compile_scalar_pressure_energy_convergence_v1([
        spe_observation(1, 1.0e6), spe_observation(2, 2.0e6)])
    @test nonconverged.status == :fail
    @test !nonconverged.c2_scalar_mhd_energy_authorized
    low = compile_scalar_pressure_energy_convergence_v1([
        spe_observation(1, 1.0e6; fidelity = 1),
        spe_observation(2, 1.0e6; fidelity = 1)])
    @test low.status == :unknown
    @test !low.resolution_verified
    authoritative_failure = compile_scalar_pressure_energy_convergence_v1([
        spe_observation(1, 1.0e6),
        spe_observation(2, 1.0e6; source_status = :fail)])
    @test authoritative_failure.status == :fail
    @test_throws ArgumentError compile_scalar_pressure_energy_convergence_v1([
        spe_observation(1, 1.0e6), spe_observation(1, 1.0e6)])
end
