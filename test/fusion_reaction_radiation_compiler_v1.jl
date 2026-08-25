using Test
using FusionConceptAI
using JSON3

const FRR_ROOT = normpath(joinpath(@__DIR__, ".."))
const FRR_PLEIADES_PATH = joinpath(FRR_ROOT, "examples",
    "pleiades_wham_isotropic_regression_genome.json")
const FRR_DESC_PATH = joinpath(FRR_ROOT, "examples",
    "desc_w7x_regression_genome.json")
const FRR_FREEGS_PATH = joinpath(FRR_ROOT, "examples",
    "freegs_pointcoil_wall_control_genome_v1.json")
const FRR_KEV_J = 1.0e3 * 1.602176634e-19

function frr_grid(genome, state_problem; rank = 1, cells = 2,
        source_kind = :candidate_solver, fidelity = 2,
        runtime_state_c2 = true, distribution = :maxwellian,
        include_deuterium = true, inventory_verified = true,
        quasi_neutrality_verified = true)
    domain = only(state_problem.population_domain_ids)
    density = Dict{String,Vector{Float64}}(
        "electron" => fill(1.0e20, cells))
    tpar = Dict{String,Vector{Float64}}(
        "electron" => fill(10.0 * FRR_KEV_J, cells))
    tperp = deepcopy(tpar)
    kinds = Dict{String,Symbol}("electron" => :maxwellian)
    if include_deuterium
        density["deuterium"] = fill(1.0e20, cells)
        tpar["deuterium"] = fill(10.0 * FRR_KEV_J, cells)
        tperp["deuterium"] = fill(10.0 * FRR_KEV_J, cells)
        kinds["deuterium"] = distribution
    end
    return compile_collocated_plasma_state_grid_v1(
        design_id = genome.design_id,
        genome_physics_hash = genome.physics_hash, domain_id = domain,
        resolution_label = "grid_$rank", resolution_rank = rank,
        cell_volumes_m3 = fill(1.0 / cells, cells),
        species_density_m3 = density, temperature_parallel_j = tpar,
        temperature_perpendicular_j = tperp, distribution_kinds = kinds,
        runtime_state_assessment_hash = repeat("a", 64),
        runtime_state_c2_authorized = runtime_state_c2,
        cellwise_quasi_neutrality_verified = quasi_neutrality_verified,
        runtime_inventory_consistency_verified = inventory_verified,
        fully_ionized_fuel_verified = true,
        optically_thin_bremsstrahlung_verified = true,
        source_kind = source_kind, source_artifact_id = "state_grid.h5",
        source_artifact_hash = repeat("b", 64),
        source_result_hash = repeat(rank == 1 ? "c" : "d", 64),
        candidate_binding_verified = true, resolution_verified = true,
        applicability_verified = true, fidelity = fidelity,
        source_solver_status = :pass)
end

@testset "Topology-independent reaction network and Bosch-Hale v1" begin
    @test length(fusion_reaction_channels_v1("D-T")) == 1
    @test length(fusion_reaction_channels_v1("D-D")) == 2
    @test isempty(fusion_reaction_channels_v1("other"))
    @test all(x.identical_reactant_factor == 0.5 for x in
        fusion_reaction_channels_v1("D-D"))

    dt10 = bosch_hale_maxwellian_reactivity_v1(
        "dt_to_alpha_neutron", 10.0)
    @test isapprox(dt10, 1.1361654705836232e-22; rtol = 1.0e-12)
    @test isnan(bosch_hale_maxwellian_reactivity_v1(
        "dt_to_alpha_neutron", 0.1))
    @test isnan(bosch_hale_maxwellian_reactivity_v1(
        "dt_to_alpha_neutron", 101.0))
    @test all(bosch_hale_maxwellian_reactivity_v1(id, 10.0) > 0.0 for id in
        ("dd_to_tritium_proton", "dd_to_helium3_neutron"))

    genome = load_genome(FRR_PLEIADES_PATH)
    problem = compile_fusion_reaction_radiation_problem_v1(genome)
    raw = JSON3.read(read(FRR_PLEIADES_PATH, String), Dict{String,Any})
    raw["family"] = "family_label_must_not_route_physics"
    relabeled = compile_fusion_reaction_radiation_problem_v1(parse_genome(raw))
    @test fusion_reaction_channel_to_dict_v1.(problem.channels) ==
        fusion_reaction_channel_to_dict_v1.(relabeled.channels)
    @test problem.population_domain_ids == relabeled.population_domain_ids
    @test problem.radiation_component_ids == relabeled.radiation_component_ids
    @test problem.required_input_ids == relabeled.required_input_ids
    @test problem.evidence_tasks == relabeled.evidence_tasks
    @test length(compile_fusion_reaction_radiation_problem_v1(
        load_genome(FRR_DESC_PATH)).channels) == 2
    @test isempty(compile_fusion_reaction_radiation_problem_v1(
        load_genome(FRR_FREEGS_PATH)).channels)
end

@testset "Collocated profiles compute components without false C2 v1" begin
    genome = load_genome(FRR_PLEIADES_PATH)
    state_problem = compile_runtime_species_state_problem_v1(genome)
    problem = compile_fusion_reaction_radiation_problem_v1(genome)
    manufactured = frr_grid(genome, state_problem;
        source_kind = :manufactured)
    observation = compile_fusion_reaction_radiation_observation_v1(
        problem, state_problem, manufactured)
    @test observation.fusion_status == :pass
    @test observation.fuel_ion_bremsstrahlung_status == :pass
    @test observation.total_fusion_power_w > 0.0
    @test observation.charged_fusion_power_w > 0.0
    @test observation.neutral_fusion_power_w > 0.0
    @test observation.fuel_ion_bremsstrahlung_power_w > 0.0
    @test !observation.fusion_observation_c2_authorized
    @test !observation.fuel_ion_bremsstrahlung_observation_c2_authorized
    @test "raise_collocated_species_grid_to_candidate_bound_c2" in
        observation.evidence_tasks

    ddt = bosch_hale_maxwellian_reactivity_v1(
        "dd_to_tritium_proton", 10.0)
    expected_rate = 0.5 * (1.0e20)^2 * ddt
    @test isapprox(observation.channel_reaction_rates_s[
        "dd_to_tritium_proton"], expected_rate; rtol = 1.0e-12)

    missing = frr_grid(genome, state_problem; include_deuterium = false)
    missing_observation = compile_fusion_reaction_radiation_observation_v1(
        problem, state_problem, missing)
    @test missing_observation.fusion_status == :unknown
    @test missing_observation.total_fusion_power_w === nothing
    @test any(contains("provide_collocated_reactant_profiles"),
        missing_observation.evidence_tasks)

    anisotropic = frr_grid(genome, state_problem;
        distribution = :bi_maxwellian)
    anisotropic_observation = compile_fusion_reaction_radiation_observation_v1(
        problem, state_problem, anisotropic)
    @test anisotropic_observation.fusion_status == :unknown
    @test any(contains("run_velocity_space_reactivity_integral"),
        anisotropic_observation.evidence_tasks)

    unverified = frr_grid(genome, state_problem;
        inventory_verified = false, quasi_neutrality_verified = false)
    unverified_observation = compile_fusion_reaction_radiation_observation_v1(
        problem, state_problem, unverified)
    @test !unverified_observation.fusion_observation_c2_authorized
    @test "verify_cellwise_quasi_neutrality" in
        unverified_observation.evidence_tasks
    @test "verify_spatial_profiles_against_runtime_state_inventories" in
        unverified_observation.evidence_tasks

    @test_throws ArgumentError compile_collocated_plasma_state_grid_v1(
        design_id = genome.design_id, genome_physics_hash = genome.physics_hash,
        domain_id = only(state_problem.population_domain_ids),
        resolution_label = "bad", resolution_rank = 1,
        cell_volumes_m3 = [1.0],
        species_density_m3 = Dict("electron" => [-1.0]),
        temperature_parallel_j = Dict("electron" => [FRR_KEV_J]),
        temperature_perpendicular_j = Dict("electron" => [FRR_KEV_J]),
        distribution_kinds = Dict("electron" => :maxwellian),
        runtime_state_assessment_hash = repeat("a", 64),
        runtime_state_c2_authorized = true,
        cellwise_quasi_neutrality_verified = true,
        runtime_inventory_consistency_verified = true,
        fully_ionized_fuel_verified = true,
        optically_thin_bremsstrahlung_verified = true,
        source_kind = :candidate_solver, source_artifact_id = "bad.h5",
        source_artifact_hash = repeat("b", 64),
        source_result_hash = repeat("c", 64),
        candidate_binding_verified = true, resolution_verified = true,
        applicability_verified = true, fidelity = 2,
        source_solver_status = :pass)
end

@testset "Two-resolution component convergence cannot imply net power v1" begin
    genome = load_genome(FRR_PLEIADES_PATH)
    state_problem = compile_runtime_species_state_problem_v1(genome)
    problem = compile_fusion_reaction_radiation_problem_v1(genome)
    observations = [compile_fusion_reaction_radiation_observation_v1(
        problem, state_problem, frr_grid(genome, state_problem;
            rank = rank, cells = rank == 1 ? 2 : 4)) for rank in 1:2]
    convergence = compile_fusion_reaction_radiation_convergence_v1(observations)
    @test convergence.fusion_status == :pass
    @test convergence.fuel_ion_bremsstrahlung_status == :pass
    @test convergence.c2_fusion_power_authorized
    @test convergence.c2_fuel_ion_bremsstrahlung_authorized
    @test !convergence.complete_radiation_authorized
    @test !convergence.complete_power_balance_authorized
    @test convergence.status == :unknown
    @test "compute_complete_radiation_power" in convergence.evidence_tasks
    @test "compute_recirculating_and_net_electric_power" in
        convergence.evidence_tasks
end
