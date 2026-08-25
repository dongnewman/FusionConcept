using Test
using FusionConceptAI

const STC_ROOT = normpath(joinpath(@__DIR__, ".."))
const STC_PLEIADES_PATH = joinpath(STC_ROOT, "examples",
    "pleiades_wham_isotropic_regression_genome.json")
const STC_KEV_J = 1.0e3 * 1.602176634e-19

function stc_pressure(genome, domain; rank = 1, source_kind = :candidate_solver)
    return compile_scalar_pressure_spatial_grid_v1(
        design_id = genome.design_id, genome_physics_hash = genome.physics_hash,
        domain_id = domain, resolution_label = "grid_$rank",
        resolution_rank = rank, cell_volumes_m3 = [0.25, 0.25, 0.5],
        scalar_pressure_pa = [1.0e4, 2.0e4, 3.0e4],
        source_kind = source_kind, source_artifact_id = "pressure_grid.h5",
        source_artifact_hash = repeat("a", 64),
        source_result_hash = repeat(rank == 1 ? "b" : "c", 64),
        candidate_binding_verified = true, resolution_verified = true,
        applicability_verified = true, fidelity = 2,
        source_solver_status = :pass)
end

function stc_temperature_input(genome, domain; rank = 1,
        source_kind = :design_assumption, distribution = :maxwellian)
    return compile_independent_thermodynamic_profile_v1(
        design_id = genome.design_id, genome_physics_hash = genome.physics_hash,
        domain_id = domain, resolution_label = "grid_$rank",
        closure_mode = :temperature_to_density,
        temperature_parallel_j = Dict(
            "electron" => fill(5.0 * STC_KEV_J, 3),
            "deuterium" => fill(10.0 * STC_KEV_J, 3)),
        temperature_perpendicular_j = Dict(
            "electron" => fill(5.0 * STC_KEV_J, 3),
            "deuterium" => fill(10.0 * STC_KEV_J, 3)),
        ion_number_fractions = Dict("deuterium" => 1.0),
        distribution_kinds = Dict("electron" => :maxwellian,
            "deuterium" => distribution),
        source_kind = source_kind,
        source_artifact_id = "independent_temperature.h5",
        source_artifact_hash = repeat("d", 64),
        source_result_hash = repeat(rank == 1 ? "e" : "f", 64),
        candidate_binding_verified = true, resolution_verified = true,
        applicability_verified = true, fidelity = 2,
        source_solver_status = :pass)
end

function stc_reference_energy(pressure)
    return 1.5 * sum(pressure.scalar_pressure_pa .* pressure.cell_volumes_m3)
end

@testset "Pressure plus independent temperature closes density without C2 inflation v1" begin
    genome = load_genome(STC_PLEIADES_PATH)
    problem = compile_runtime_species_state_problem_v1(genome)
    domain = only(problem.population_domain_ids)
    pressure = stc_pressure(genome, domain)
    input = stc_temperature_input(genome, domain)
    closure = compile_spatial_thermodynamic_closure_v1(problem, pressure, input)
    @test closure.status == :pass
    @test !closure.c2_state_closure_authorized
    @test closure.maximum_pressure_relative_residual < 1.0e-12
    @test closure.maximum_quasi_neutrality_relative_residual == 0.0
    @test closure.species_density_m3["electron"] ==
        closure.species_density_m3["deuterium"]
    @test "replace_thermodynamic_assumption_with_candidate_solver_or_measurement" in
        closure.evidence_tasks

    evidence = spatial_thermodynamic_closure_runtime_state_evidence_v1(closure;
        source_artifact_id = "closure.json",
        source_artifact_hash = repeat("1", 64))
    assessment = assess_runtime_species_state_v1(problem, evidence;
        reference_scalar_mhd_energy_j = Dict(domain =>
            stc_reference_energy(pressure)))
    @test assessment.complete_required_state
    @test assessment.status == :unknown
    @test !assessment.c2_state_component_authorized
    grid = spatial_thermodynamic_closure_collocated_grid_v1(
        closure, assessment; source_artifact_id = "closure.json",
        source_artifact_hash = repeat("1", 64))
    @test grid.runtime_inventory_consistency_verified
    @test grid.cellwise_quasi_neutrality_verified
    @test !grid.runtime_state_c2_authorized

    reaction_problem = compile_fusion_reaction_radiation_problem_v1(genome)
    reaction = compile_fusion_reaction_radiation_observation_v1(
        reaction_problem, problem, grid)
    @test reaction.fusion_status == :pass
    @test reaction.total_fusion_power_w > 0.0
    @test !reaction.fusion_observation_c2_authorized
end

@testset "Candidate-solver state closes an auditable C2 component v1" begin
    genome = load_genome(STC_PLEIADES_PATH)
    problem = compile_runtime_species_state_problem_v1(genome)
    domain = only(problem.population_domain_ids)
    pressure = stc_pressure(genome, domain)
    input = stc_temperature_input(genome, domain;
        source_kind = :candidate_solver)
    closure = compile_spatial_thermodynamic_closure_v1(problem, pressure, input)
    @test closure.status == :pass
    @test closure.c2_state_closure_authorized
    evidence = spatial_thermodynamic_closure_runtime_state_evidence_v1(closure;
        source_artifact_id = "candidate_closure.json",
        source_artifact_hash = repeat("2", 64))
    assessment = assess_runtime_species_state_v1(problem, evidence;
        reference_scalar_mhd_energy_j = Dict(domain =>
            stc_reference_energy(pressure)))
    @test assessment.status == :pass
    @test assessment.c2_state_component_authorized
    grid = spatial_thermodynamic_closure_collocated_grid_v1(
        closure, assessment; source_artifact_id = "candidate_closure.json",
        source_artifact_hash = repeat("2", 64))
    @test grid.runtime_state_c2_authorized
    @test grid.runtime_inventory_consistency_verified
    reaction = compile_fusion_reaction_radiation_observation_v1(
        compile_fusion_reaction_radiation_problem_v1(genome), problem, grid)
    @test reaction.fusion_observation_c2_authorized
    @test !reaction.fuel_ion_bremsstrahlung_observation_c2_authorized
end

@testset "Independent density closes temperature and validates charge v1" begin
    genome = load_genome(STC_PLEIADES_PATH)
    problem = compile_runtime_species_state_problem_v1(genome)
    domain = only(problem.population_domain_ids)
    pressure = stc_pressure(genome, domain)
    density = fill(1.0e20, 3)
    input = compile_independent_thermodynamic_profile_v1(
        design_id = genome.design_id, genome_physics_hash = genome.physics_hash,
        domain_id = domain, resolution_label = "grid_1",
        closure_mode = :density_to_temperature,
        species_density_m3 = Dict("electron" => density,
            "deuterium" => density),
        temperature_parallel_j = Dict("electron" => ones(3),
            "deuterium" => 2.0 .* ones(3)),
        temperature_perpendicular_j = Dict("electron" => ones(3),
            "deuterium" => 2.0 .* ones(3)),
        distribution_kinds = Dict("electron" => :maxwellian,
            "deuterium" => :maxwellian),
        source_kind = :design_assumption,
        source_artifact_id = "density_prior.json",
        source_artifact_hash = repeat("3", 64),
        source_result_hash = repeat("4", 64),
        candidate_binding_verified = true, resolution_verified = true,
        applicability_verified = true, fidelity = 1,
        source_solver_status = :pass)
    closure = compile_spatial_thermodynamic_closure_v1(problem, pressure, input)
    @test closure.status == :pass
    @test closure.maximum_pressure_relative_residual < 1.0e-12
    @test closure.maximum_quasi_neutrality_relative_residual == 0.0
    @test all(closure.temperature_parallel_j["deuterium"] .==
        2.0 .* closure.temperature_parallel_j["electron"])
    @test !closure.c2_state_closure_authorized

    bad_input = compile_independent_thermodynamic_profile_v1(
        design_id = genome.design_id, genome_physics_hash = genome.physics_hash,
        domain_id = domain, resolution_label = "grid_1",
        closure_mode = :density_to_temperature,
        species_density_m3 = Dict("electron" => fill(0.5e20, 3),
            "deuterium" => density),
        temperature_parallel_j = Dict("electron" => ones(3),
            "deuterium" => ones(3)),
        temperature_perpendicular_j = Dict("electron" => ones(3),
            "deuterium" => ones(3)),
        distribution_kinds = Dict("electron" => :maxwellian,
            "deuterium" => :maxwellian), source_kind = :candidate_solver,
        source_artifact_id = "bad_density.json",
        source_artifact_hash = repeat("5", 64),
        source_result_hash = repeat("6", 64),
        candidate_binding_verified = true, resolution_verified = true,
        applicability_verified = true, fidelity = 2,
        source_solver_status = :pass)
    failed = compile_spatial_thermodynamic_closure_v1(
        problem, pressure, bad_input)
    @test failed.status == :fail
    @test !failed.c2_state_closure_authorized
    @test "resolve:cellwise_quasi_neutrality" in failed.evidence_tasks
end
