using Test
using FusionConceptAI

const OFS_ROOT = normpath(joinpath(@__DIR__, ".."))
const OFS_PLEIADES = joinpath(OFS_ROOT, "examples",
    "pleiades_wham_isotropic_regression_genome.json")
const OFS_HASH = repeat("b", 64)

function ofs_states(; distribution = :maxwellian)
    return [
        compile_open_flux_tube_species_state_v1(species_id = "electron",
            mass_kg = 9.1093837139e-31, density_m3 = 7.0e18,
            temperature_j = 5.0e3 * 1.602176634e-19,
            distribution_kind = distribution),
        compile_open_flux_tube_species_state_v1(species_id = "deuterium",
            mass_kg = 2.013553 * 1.66053906892e-27, density_m3 = 7.0e18,
            temperature_j = 10.0e3 * 1.602176634e-19)]
end

function ofs_observation(problem; rank = 1, volume = 1.0, ratio = 10.0,
        distribution = :maxwellian)
    return compile_open_flux_tube_streaming_observation_v1(
        design_id = problem.design_id,
        genome_physics_hash = problem.genome_physics_hash,
        domain_id = only(problem.population_domain_ids),
        resolution_label = "r$rank", resolution_rank = rank,
        connection_length_m = 2.0, effective_volume_m3 = volume,
        mirror_ratio = ratio, species_states = ofs_states(
            distribution = distribution),
        geometry_candidate_binding_verified = true,
        state_candidate_binding_verified = false,
        full_loss_cone_boundary_condition_verified = false)
end

@testset "Maxwellian full-loss-cone streaming ceiling v1" begin
    state = only(ofs_states()[2:2])
    observation = compile_open_flux_tube_streaming_observation_v1(
        design_id = "analytic", genome_physics_hash = OFS_HASH,
        domain_id = "open", resolution_label = "r1", resolution_rank = 1,
        connection_length_m = 2.0, effective_volume_m3 = 1.0,
        mirror_ratio = 10.0, species_states = [state],
        geometry_candidate_binding_verified = true)
    expected_rate = 2.0 * 0.5 * state.density_m3 *
        sqrt(state.temperature_j / (2.0 * pi * state.mass_kg)) / 10.0
    @test observation.status == :pass
    @test !observation.physical_rate_authorized
    @test observation.flux_weighted_loss_cone_transmission == 0.1
    @test isapprox(observation.total_particle_loss_rate_s, expected_rate;
        rtol = 1.0e-14)
    @test isapprox(observation.total_energy_loss_power_w,
        2.0 * state.temperature_j * expected_rate; rtol = 1.0e-14)
    doubled_ratio = compile_open_flux_tube_streaming_observation_v1(
        design_id = "analytic", genome_physics_hash = OFS_HASH,
        domain_id = "open", resolution_label = "r2", resolution_rank = 2,
        connection_length_m = 2.0, effective_volume_m3 = 1.0,
        mirror_ratio = 20.0, species_states = [state])
    @test isapprox(doubled_ratio.total_particle_loss_rate_s,
        observation.total_particle_loss_rate_s / 2.0; rtol = 1.0e-14)
    @test_throws ArgumentError compile_open_flux_tube_species_state_v1(
        species_id = "bad", mass_kg = -1.0, density_m3 = 1.0,
        temperature_j = 1.0)
end

@testset "Unsupported distributions and resolution audit remain fail closed v1" begin
    problem = compile_coupled_plasma_balance_problem_v1(load_genome(OFS_PLEIADES))
    unsupported = ofs_observation(problem; distribution = :bi_maxwellian)
    @test unsupported.status == :unknown
    @test unsupported.total_particle_loss_rate_s === nothing
    @test !isempty(unsupported.evidence_tasks)
    observations = [ofs_observation(problem; rank = rank,
        volume = 1.0 + 1.0e-4 * rank) for rank in 1:3]
    convergence = compile_open_flux_tube_streaming_convergence_v1(observations)
    @test convergence.status == :pass
    @test !convergence.c2_boundary_flux_authorized
    @test maximum(convergence.energy_adjacent_relative_changes) < 0.02
    divergent = [observations[1], ofs_observation(problem; rank = 2, volume = 2.0)]
    @test compile_open_flux_tube_streaming_convergence_v1(divergent).status == :fail
    @test_throws ArgumentError compile_open_flux_tube_streaming_convergence_v1(
        observations[1:1])
end

@testset "Streaming ceiling maps to exact coupled terms with zero C2 v1" begin
    problem = compile_coupled_plasma_balance_problem_v1(load_genome(OFS_PLEIADES))
    observations = [ofs_observation(problem; rank = rank,
        volume = 1.0 + 1.0e-4 * rank) for rank in 1:3]
    convergence = compile_open_flux_tube_streaming_convergence_v1(observations)
    evidence = open_flux_tube_streaming_coupled_evidence_v1(problem,
        observations, convergence; source_artifact_id = "runs/streaming.json",
        source_artifact_hash = OFS_HASH)
    @test length(evidence) == 3
    @test all(item -> item.source_kind == :proxy, evidence)
    @test all(item -> !item.c2_term_authorized, evidence)
    @test Set(item.unit for item in evidence) == Set(["s^-1", "W"])
    assessment = assess_coupled_plasma_balance_v1(problem, evidence)
    @test assessment.status == :unknown
    @test assessment.observed_term_count == 3
    @test assessment.c2_authorized_term_count == 0
    @test length(assessment.unknown_equation_ids) == 3
end
