using Test
using FusionConceptAI

const _SLCFP_HASH = repeat("a", 64)

function _slcfp_test_observation(; design_id = "kinetic_probe", mirror_ratio = 4.0,
        potential = 0.0, nz = 24, nt = 22)
    problem = compile_sourced_loss_cone_fokker_planck_problem_v1(
        design_id = design_id, genome_physics_hash = _SLCFP_HASH,
        domain_id = "open_core", species_id = "deuterium",
        mirror_ratio = mirror_ratio,
        normalized_confining_potential = potential,
        speed_cell_count = nz, pitch_cell_count = nt,
        geometry_candidate_binding_verified = true,
        source_model_candidate_binding_verified = false,
        equation_source_ids = ["ochs_munirov_fisch_2024_equations_3_29_to_3_31"])
    return problem, solve_sourced_loss_cone_fokker_planck_v1(problem)
end

@testset "Sourced loss-cone kinetic problem is physical-property routed v1" begin
    problem, observation = _slcfp_test_observation()
    @test problem.mirror_ratio == 4.0
    @test problem.geometry_candidate_binding_verified
    @test !problem.source_model_candidate_binding_verified
    @test observation.status == :pass
    @test observation.trapped_cell_count + observation.loss_cell_count == 24 * 22
    @test observation.minimum_distribution_value >= 0.0
    @test observation.maximum_distribution_value > 0.0
    @test !observation.c2_physical_rate_authorized
    @test "solve_ambipolar_potential_from_quasineutrality_and_equal_end_current" in
        observation.evidence_tasks
    @test "bind_source_distribution_to_candidate_actuator" in
        observation.evidence_tasks
    @test length(problem.problem_hash) == 64
    @test length(observation.observation_hash) == 64
    @test_throws ArgumentError compile_sourced_loss_cone_fokker_planck_problem_v1(
        design_id = "bad", genome_physics_hash = _SLCFP_HASH,
        domain_id = "core", species_id = "D", mirror_ratio = 1.0)
end

@testset "Kinetic finite volume conserves source and resolves depletion v1" begin
    _, low_r = _slcfp_test_observation(mirror_ratio = 2.0, nz = 32, nt = 28)
    _, high_r = _slcfp_test_observation(mirror_ratio = 8.0, nz = 32, nt = 28)
    _, potential = _slcfp_test_observation(mirror_ratio = 4.0,
        potential = 1.0, nz = 32, nt = 28)
    _, baseline = _slcfp_test_observation(mirror_ratio = 4.0,
        potential = 0.0, nz = 32, nt = 28)
    for observation in (low_r, high_r, potential, baseline)
        @test observation.source_loss_relative_residual <= 1.0e-10
        @test observation.linear_system_relative_residual <= 1.0e-10
        @test isapprox(sum(observation.normalized_speed_projection), 1.0;
            atol = 1.0e-10)
        @test isapprox(sum(observation.normalized_pitch_projection), 1.0;
            atol = 1.0e-10)
    end
    @test high_r.normalized_confinement_time > low_r.normalized_confinement_time
    @test potential.normalized_confinement_time >
        baseline.normalized_confinement_time
    @test potential.mean_lost_energy_over_temperature >
        baseline.mean_lost_energy_over_temperature
end

@testset "Reduced kinetic convergence cannot authorize physical C2 v1" begin
    _, coarse = _slcfp_test_observation(potential = 0.5, nz = 32, nt = 28)
    _, fine = _slcfp_test_observation(potential = 0.5, nz = 48, nt = 42)
    convergence = compile_sourced_loss_cone_fokker_planck_convergence_v1(
        [fine, coarse]; convergence_limit = 0.15)
    @test convergence.status == :pass
    @test convergence.maximum_adjacent_relative_change < 0.10
    @test !convergence.c2_physical_rate_authorized
    @test length(convergence.convergence_hash) == 64
    observation_dict = sourced_loss_cone_fokker_planck_observation_to_dict_v1(fine)
    convergence_dict = sourced_loss_cone_fokker_planck_convergence_to_dict_v1(
        convergence)
    @test observation_dict["status"] == "pass"
    @test convergence_dict["status"] == "pass"
    @test convergence_dict["c2_physical_rate_authorized"] == false
end
