using Test
using FusionConceptAI

const _END_LOSS_TEST_HASH = repeat("1", 64)

function _end_loss_problem_v1(; authoritative = false, missing = false)
    compile_bounce_averaged_end_loss_problem_v1(
        design_id = "end_loss_probe", genome_physics_hash = _END_LOSS_TEST_HASH,
        domain_id = "core", species_id = "deuterium",
        throat_to_throat_length_m = 2.0,
        throat_to_throat_length_verified = authoritative,
        bin_particle_inventories = missing ? nothing : [1.0e10, 2.0e10],
        bin_parallel_speeds_m_s = missing ? nothing : [1.0e5, 2.0e5],
        bin_boundary_kinetic_energies_j = missing ? nothing : [1.0e-15, 2.0e-15],
        loss_boundary_mask = missing ? nothing : [true, false],
        distribution_physical_normalization_verified = authoritative,
        candidate_loss_boundary_verified = authoritative,
        ambipolar_profile_c2_authorized = authoritative,
        bounce_average_verified = authoritative,
        boundary_energy_verified = authoritative,
        source_sink_complete_verified = authoritative,
        candidate_binding_verified = authoritative,
        resolution_verified = authoritative,
        applicability_verified = authoritative,
        source_kind = authoritative ? :candidate_solver : :manufactured,
        source_artifact_id = "kinetic_response.h5",
        source_artifact_hash = repeat("2", 64),
        source_result_hash = repeat("3", 64),
        source_ids = ["frank_et_al_cql3dm_2025"])
end

@testset "Bounce-averaged end sink is dimensional and conservative v1" begin
    problem = _end_loss_problem_v1()
    observation = solve_bounce_averaged_end_loss_v1(problem)
    @test observation.status == :pass
    @test observation.loss_bin_count == 1
    @test observation.represented_particle_inventory == 3.0e10
    @test observation.parallel_particle_loss_rate_s == 1.0e15
    @test observation.parallel_boundary_kinetic_power_w == 1.0
    @test observation.inventory_depletion_time_s == 3.0e-5
    @test !observation.c2_physical_end_loss_authorized
    @test length(observation.evidence_tasks) == 10
    @test length(problem.problem_hash) == 64
    @test length(observation.observation_hash) == 64
end

@testset "End-loss C2 is an all-gates contract v1" begin
    observation = solve_bounce_averaged_end_loss_v1(
        _end_loss_problem_v1(authoritative = true))
    @test observation.status == :pass
    @test observation.c2_physical_end_loss_authorized
    @test isempty(observation.evidence_tasks)
    @test bounce_averaged_end_loss_problem_to_dict_v1(
        _end_loss_problem_v1())["source_kind"] == "manufactured"
    @test bounce_averaged_end_loss_observation_to_dict_v1(observation)["status"] ==
        "pass"
end

@testset "Missing end-loss distribution fails closed v1" begin
    observation = solve_bounce_averaged_end_loss_v1(
        _end_loss_problem_v1(missing = true))
    @test observation.status == :unknown
    @test observation.parallel_particle_loss_rate_s === nothing
    @test observation.parallel_boundary_kinetic_power_w === nothing
    @test !observation.c2_physical_end_loss_authorized
    @test "provide_physically_normalized_bounce_averaged_distribution_bins" in
        observation.evidence_tasks
end

@testset "End loss maps exact particle and total-energy balance terms v1" begin
    genome = load_genome(joinpath(@__DIR__, "..", "examples",
        "pleiades_wham_nbi_kinetic_control_v1.json"))
    balance = compile_coupled_plasma_balance_problem_v1(genome)
    problem = compile_bounce_averaged_end_loss_problem_v1(
        design_id = genome.design_id, genome_physics_hash = genome.physics_hash,
        domain_id = "pleiades_wham_isotropic_core", species_id = "deuterium",
        throat_to_throat_length_m = 2.0,
        bin_particle_inventories = [1.0e10],
        bin_parallel_speeds_m_s = [1.0e5],
        bin_boundary_kinetic_energies_j = [1.0e-15],
        loss_boundary_mask = [true], source_kind = :proxy,
        source_artifact_id = "proxy.json", source_artifact_hash = repeat("4", 64),
        source_result_hash = repeat("5", 64), source_ids = ["eq_2_6"])
    observation = solve_bounce_averaged_end_loss_v1(problem)
    evidence = bounce_averaged_end_loss_coupled_evidence_v1(balance,
        [(problem, observation)]; source_artifact_id = "proxy.json",
        source_artifact_hash = repeat("4", 64))
    @test length(evidence) == 2
    @test Set(item.term_id for item in evidence) == Set([
        "particle|pleiades_wham_isotropic_core|deuterium::parallel_particle_boundary_flux",
        "thermal_energy|pleiades_wham_isotropic_core|all_plasma::parallel_energy_boundary_flux"])
    @test all(item -> item.source_kind == :proxy, evidence)
    @test all(item -> !item.c2_term_authorized, evidence)
    assessment = assess_coupled_plasma_balance_v1(balance, evidence)
    @test assessment.observed_term_count == 2
    @test assessment.c2_authorized_term_count == 0
end

@testset "End-loss bins enforce physical input shape v1" begin
    @test_throws ArgumentError compile_bounce_averaged_end_loss_problem_v1(
        design_id = "bad", genome_physics_hash = _END_LOSS_TEST_HASH,
        domain_id = "core", species_id = "d", throat_to_throat_length_m = 0.0)
    @test_throws ArgumentError compile_bounce_averaged_end_loss_problem_v1(
        design_id = "bad", genome_physics_hash = _END_LOSS_TEST_HASH,
        domain_id = "core", species_id = "d", throat_to_throat_length_m = 1.0,
        bin_particle_inventories = [1.0])
    @test_throws ArgumentError compile_bounce_averaged_end_loss_problem_v1(
        design_id = "bad", genome_physics_hash = _END_LOSS_TEST_HASH,
        domain_id = "core", species_id = "d", throat_to_throat_length_m = 1.0,
        bin_particle_inventories = [1.0], bin_parallel_speeds_m_s = [1.0],
        bin_boundary_kinetic_energies_j = [1.0], loss_boundary_mask = [false])
end
