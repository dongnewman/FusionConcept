using Test
using FusionConceptAI

const _NBI_TEST_HASH = repeat("b", 64)
const _NBI_KEV_J = 1.0e3 * 1.602176634e-19

function _nbi_test_problem(; power = 1.0e6, energy_kev = 25.0,
        current = 40.0, absorption = nothing, ionization = nothing,
        binding = false, spectrum = false, deposition = false,
        source_kind = :published_design)
    compile_neutral_beam_source_problem_v1(
        design_id = "nbi_probe", genome_physics_hash = _NBI_TEST_HASH,
        domain_id = "plasma_core", actuator_id = "beam_1",
        injected_species_id = "deuterium", charge_state = 1,
        declared_beam_power_w = power,
        primary_particle_energy_j = energy_kev * _NBI_KEV_J,
        declared_equivalent_current_a = current,
        injection_pitch_angle_rad = pi / 4,
        absorption_fraction = absorption,
        ionization_branch_fraction = ionization,
        actuator_candidate_binding_verified = binding,
        spectrum_interpretation_verified = spectrum,
        deposition_model_applicability_verified = deposition,
        source_kind = source_kind,
        source_ids = ["published_nbi_control"])
end

@testset "Neutral-beam incident ceiling is unit-consistent v1" begin
    problem = _nbi_test_problem()
    observation = evaluate_neutral_beam_source_v1(problem)
    expected = 40.0 / 1.602176634e-19
    @test isapprox(observation.power_limited_incident_particle_rate_s,
        expected; rtol = 1.0e-14)
    @test isapprox(observation.current_limited_incident_particle_rate_s,
        expected; rtol = 1.0e-14)
    @test observation.incident_rate_relative_mismatch == 0.0
    @test observation.incident_particle_rate_ceiling_s == expected
    @test observation.status == :unknown
    @test observation.fueled_particle_source_rate_s === nothing
    @test !observation.c2_source_term_authorized
    @test length(problem.problem_hash) == 64
    @test length(observation.observation_hash) == 64
end

@testset "Absorption and branching remain non-compensating source gates v1" begin
    partial = evaluate_neutral_beam_source_v1(_nbi_test_problem(
        absorption = 0.8, ionization = 0.25))
    @test partial.absorbed_particle_rate_s !== nothing
    @test partial.fueled_particle_source_rate_s !== nothing
    @test isapprox(partial.fueled_particle_source_rate_s,
        partial.incident_particle_rate_ceiling_s * 0.8 * 0.25)
    @test isapprox(partial.charge_exchange_or_nonfuel_rate_s,
        partial.incident_particle_rate_ceiling_s * 0.8 * 0.75)
    @test partial.status == :unknown
    @test !partial.physical_source_rate_authorized
    complete = evaluate_neutral_beam_source_v1(_nbi_test_problem(
        absorption = 0.8, ionization = 0.25, binding = true,
        spectrum = true, deposition = true))
    @test complete.status == :pass
    @test complete.physical_source_rate_authorized
    @test complete.c2_source_term_authorized
    manufactured = evaluate_neutral_beam_source_v1(_nbi_test_problem(
        absorption = 0.8, ionization = 0.25, binding = true,
        spectrum = true, deposition = true, source_kind = :manufactured))
    @test manufactured.status == :unknown
    @test !manufactured.c2_source_term_authorized
end

@testset "Neutral-beam declarations fail closed on inconsistent inputs v1" begin
    inconsistent = evaluate_neutral_beam_source_v1(_nbi_test_problem(
        current = 20.0))
    @test inconsistent.status == :fail
    @test "resolve_beam_power_current_inconsistency" in
        inconsistent.evidence_tasks
    @test_throws ArgumentError _nbi_test_problem(absorption = 1.1)
    @test_throws ArgumentError _nbi_test_problem(energy_kev = -1.0)
    @test neutral_beam_source_observation_to_dict_v1(inconsistent)["status"] ==
        "fail"
    @test neutral_beam_source_problem_to_dict_v1(
        _nbi_test_problem())["source_kind"] == "published_design"
end

@testset "Neutral-beam source maps exact particle terms without false C2 v1" begin
    genome = load_genome(joinpath(@__DIR__, "..", "examples",
        "pleiades_wham_isotropic_regression_genome.json"))
    balance = compile_coupled_plasma_balance_problem_v1(genome)
    source_problem = compile_neutral_beam_source_problem_v1(
        design_id = genome.design_id, genome_physics_hash = genome.physics_hash,
        domain_id = "pleiades_wham_isotropic_core", actuator_id = "nbi_overlay",
        injected_species_id = "deuterium", charge_state = 1,
        declared_beam_power_w = 1.0e6,
        primary_particle_energy_j = 25.0 * _NBI_KEV_J,
        declared_equivalent_current_a = 40.0,
        injection_pitch_angle_rad = pi / 4,
        absorption_fraction = 1.0, ionization_branch_fraction = 0.2,
        actuator_candidate_binding_verified = false,
        spectrum_interpretation_verified = false,
        deposition_model_applicability_verified = false,
        source_kind = :published_design,
        source_ids = ["wham_physics_basis_2023"])
    observation = evaluate_neutral_beam_source_v1(source_problem)
    evidence = neutral_beam_source_coupled_evidence_v1(balance,
        source_problem, observation;
        source_artifact_id = "conditional_nbi_overlay.json",
        source_artifact_hash = repeat("c", 64))
    @test length(evidence) == 2
    @test Set(item.term_id for item in evidence) == Set([
        "particle|pleiades_wham_isotropic_core|deuterium::external_particle_source",
        "particle|pleiades_wham_isotropic_core|electron::external_particle_source"])
    @test all(item -> item.source_kind == :proxy, evidence)
    @test all(item -> !item.c2_term_authorized, evidence)
    assessment = assess_coupled_plasma_balance_v1(balance, evidence)
    @test assessment.observed_term_count == 2
    @test assessment.c2_authorized_term_count == 0
    @test length(assessment.unknown_equation_ids) == 3
end

@testset "Candidate-bound NBI Genome still fails closed without deposition v1" begin
    genome = load_genome(joinpath(@__DIR__, "..", "examples",
        "pleiades_wham_nbi_kinetic_control_v1.json"))
    actuator = only(genome.actuators)
    @test actuator.kind == "neutral_beam"
    problem = compile_neutral_beam_source_problem_v1(
        design_id = genome.design_id, genome_physics_hash = genome.physics_hash,
        domain_id = "pleiades_wham_isotropic_core", actuator_id = actuator.id,
        injected_species_id = "deuterium", charge_state = 1,
        declared_beam_power_w = actuator.parameters["declared_beam_power"].value,
        primary_particle_energy_j =
            actuator.parameters["primary_particle_energy"].value,
        declared_equivalent_current_a =
            actuator.parameters["equivalent_current"].value,
        injection_pitch_angle_rad =
            actuator.parameters["injection_pitch_angle"].value,
        absorption_fraction = 1.0, ionization_branch_fraction = 0.2,
        actuator_candidate_binding_verified = true,
        spectrum_interpretation_verified = false,
        deposition_model_applicability_verified = false,
        source_kind = :published_design,
        source_ids = ["endrizzi_et_al_wham_physics_basis_2023"])
    observation = evaluate_neutral_beam_source_v1(problem)
    @test problem.genome_physics_hash == genome.physics_hash
    @test problem.actuator_candidate_binding_verified
    @test observation.status == :unknown
    @test !observation.physical_source_rate_authorized
    @test !observation.c2_source_term_authorized
    @test "resolve_primary_half_third_energy_component_basis" in
        observation.evidence_tasks
    @test "validate_deposition_model_at_candidate_state" in
        observation.evidence_tasks
end
