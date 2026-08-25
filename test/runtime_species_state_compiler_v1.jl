using Test
using FusionConceptAI
using JSON3

const RSS_ROOT = normpath(joinpath(@__DIR__, ".."))
const RSS_PLEIADES_PATH = joinpath(RSS_ROOT, "examples",
    "pleiades_wham_isotropic_regression_genome.json")
const RSS_DESC_PATH = joinpath(RSS_ROOT, "examples",
    "desc_w7x_regression_genome.json")
const RSS_FREEGS_PATH = joinpath(RSS_ROOT, "examples",
    "freegs_pointcoil_wall_control_genome_v1.json")

function rss_state(genome, domain, species; density = 1.0e20,
        tpar = 1.0e-15, tperp = 1.0e-15, volume = 2.0,
        fidelity = 2, binding = true, distribution = :bi_maxwellian)
    return compile_runtime_species_state_evidence_v1(
        design_id = genome.design_id, genome_physics_hash = genome.physics_hash,
        domain_id = domain, species_id = species, density_m3 = density,
        temperature_parallel_j = tpar,
        temperature_perpendicular_j = tperp,
        bulk_velocity_m_s = [0.0, 0.0, 0.0],
        distribution_kind = distribution, plasma_volume_m3 = volume,
        source_kind = :candidate_solver,
        source_artifact_id = "manufactured_species_state.json",
        source_artifact_hash = repeat("a", 64),
        source_result_hash = repeat(species == "electron" ? "b" : "c", 64),
        candidate_binding_verified = binding, resolution_verified = true,
        applicability_verified = true, fidelity = fidelity,
        source_solver_status = :pass)
end

@testset "Runtime species population and topology-independent problem v1" begin
    dd = species_population_catalog_v1("D-D")
    @test [x.species_id for x in dd if x.required_initial_population] ==
        ["electron", "deuterium"]
    @test Set(x.species_id for x in dd if !x.required_initial_population) ==
        Set(["tritium", "helium3", "proton", "neutron"])
    dt = species_population_catalog_v1("D-T")
    @test [x.species_id for x in dt if x.required_initial_population] ==
        ["electron", "deuterium", "tritium"]

    pleiades = load_genome(RSS_PLEIADES_PATH)
    problem = compile_runtime_species_state_problem_v1(pleiades)
    @test problem.population_domain_ids == ["pleiades_wham_isotropic_core"]
    @test length(problem.requirements) == 2
    @test problem.scalar_pressure_reference_required
    @test all(x.anisotropy_resolution_required for x in problem.requirements)
    @test !any(x.species.species_id == "neutron" for x in problem.requirements)

    raw = JSON3.read(read(RSS_PLEIADES_PATH, String), Dict{String,Any})
    raw["family"] = "arbitrary_relabel_without_physics_change"
    relabeled = parse_genome(raw)
    relabeled_problem = compile_runtime_species_state_problem_v1(relabeled)
    @test [(x.domain_id, x.species.species_id, x.required_field_ids,
            x.anisotropy_resolution_required) for x in problem.requirements] ==
        [(x.domain_id, x.species.species_id, x.required_field_ids,
            x.anisotropy_resolution_required) for x in relabeled_problem.requirements]

    desc_problem = compile_runtime_species_state_problem_v1(
        load_genome(RSS_DESC_PATH))
    @test !any(x.anisotropy_resolution_required for x in desc_problem.requirements)
    freegs_problem = compile_runtime_species_state_problem_v1(
        load_genome(RSS_FREEGS_PATH))
    @test Set(x.species.species_id for x in freegs_problem.requirements) ==
        Set(["electron", "ion_unspecified"])
end

@testset "Missing and low-authority states remain unknown v1" begin
    genome = load_genome(RSS_PLEIADES_PATH)
    problem = compile_runtime_species_state_problem_v1(genome)
    missing = assess_runtime_species_state_v1(problem,
        RuntimeSpeciesStateEvidenceV1[];
        reference_scalar_mhd_energy_j =
            Dict(problem.population_domain_ids[1] => 1.0e6))
    @test missing.status == :unknown
    @test !missing.complete_required_state
    @test !missing.c2_state_component_authorized
    @test !missing.conservation_rate_authorized
    @test any(startswith("provide_required_species_state"), missing.evidence_tasks)

    domain = only(problem.population_domain_ids)
    low = [rss_state(genome, domain, "electron"; fidelity = 0),
        rss_state(genome, domain, "deuterium"; fidelity = 0)]
    low_assessment = assess_runtime_species_state_v1(problem, low;
        reference_scalar_mhd_energy_j = Dict(domain => 6.0e5))
    @test low_assessment.status == :unknown
    @test low_assessment.complete_required_state
    @test !low_assessment.c2_state_component_authorized
    @test any(contains("raise_species_state_to_candidate_bound_c2"),
        low_assessment.evidence_tasks)
    manufactured = [rss_state(genome, domain, "electron"),
        rss_state(genome, domain, "deuterium")]
    manufactured = [compile_runtime_species_state_evidence_v1(
        design_id = x.design_id, genome_physics_hash = x.genome_physics_hash,
        domain_id = x.domain_id, species_id = x.species_id,
        density_m3 = x.density_m3,
        temperature_parallel_j = x.temperature_parallel_j,
        temperature_perpendicular_j = x.temperature_perpendicular_j,
        bulk_velocity_m_s = x.bulk_velocity_m_s,
        distribution_kind = x.distribution_kind,
        plasma_volume_m3 = x.plasma_volume_m3, source_kind = :manufactured,
        source_artifact_id = x.source_artifact_id,
        source_artifact_hash = x.source_artifact_hash,
        source_result_hash = x.source_result_hash,
        candidate_binding_verified = true, resolution_verified = true,
        applicability_verified = true, fidelity = 2,
        source_solver_status = :pass) for x in manufactured]
    manufactured_assessment = assess_runtime_species_state_v1(problem,
        manufactured; reference_scalar_mhd_energy_j = Dict(domain => 6.0e5))
    @test manufactured_assessment.status == :unknown
    @test !manufactured_assessment.c2_state_component_authorized
end

@testset "C2 state algebra, quasi-neutrality, and pressure consistency v1" begin
    genome = load_genome(RSS_PLEIADES_PATH)
    problem = compile_runtime_species_state_problem_v1(genome)
    domain = only(problem.population_domain_ids)
    states = [rss_state(genome, domain, "electron"),
        rss_state(genome, domain, "deuterium")]
    # Two species, N=2e20 each, and 3T/2 per particle.
    reference = 6.0e5
    passed = assess_runtime_species_state_v1(problem, states;
        reference_scalar_mhd_energy_j = Dict(domain => reference))
    @test passed.status == :pass
    @test passed.complete_required_state
    @test passed.c2_state_component_authorized
    @test !passed.conservation_rate_authorized
    @test passed.quasi_neutrality_residuals[domain] == 0.0
    @test passed.scalar_pressure_energy_relative_errors[domain] < 1.0e-12
    @test length(passed.particle_inventories) == 2
    @test length(passed.mass_inventories_kg) == 2
    @test all(iszero, Iterators.flatten(values(
        passed.momentum_inventories_kg_m_s)))
    @test length(passed.thermal_energy_inventories_j) == 2
    @test all(iszero, values(passed.bulk_kinetic_energy_inventories_j))

    no_pressure_reference = assess_runtime_species_state_v1(problem, states)
    @test no_pressure_reference.status == :unknown
    @test !no_pressure_reference.c2_state_component_authorized
    @test "provide_independent_scalar_pressure_energy_reference:$domain" in
        no_pressure_reference.evidence_tasks

    overlay = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => genome.design_id,
        "genome_physics_hash" => genome.physics_hash,
        "states" => [runtime_species_state_evidence_to_dict_v1(x) for x in states])
    for item in overlay["states"]
        delete!(item, "design_id"); delete!(item, "genome_physics_hash")
        delete!(item, "evidence_hash")
    end
    parsed = parse_runtime_species_state_overlay_v1(problem, overlay)
    @test getfield.(parsed, :evidence_hash) == getfield.(states, :evidence_hash)

    transport_problem = compile_transport_loss_problem_v1(genome)
    bridged = runtime_species_state_transport_inventory_evidence_v1(
        transport_problem, passed; source_artifact_id = "species_state.json",
        source_artifact_hash = repeat("d", 64))
    @test Set(getfield.(bridged, :metric_id)) ==
        Set(["particle_inventory", "thermal_energy_inventory"])
    @test all(x.c2_component_authorized for x in bridged)
    @test isempty(runtime_species_state_transport_inventory_evidence_v1(
        transport_problem, no_pressure_reference;
        source_artifact_id = "species_state.json",
        source_artifact_hash = repeat("d", 64)))

    charge_bad = [rss_state(genome, domain, "electron"; density = 0.9e20),
        rss_state(genome, domain, "deuterium")]
    charge_assessment = assess_runtime_species_state_v1(problem, charge_bad)
    @test charge_assessment.status == :fail
    @test "quasi_neutrality:$domain" in charge_assessment.failed_check_ids

    pressure_bad = assess_runtime_species_state_v1(problem, states;
        reference_scalar_mhd_energy_j = Dict(domain => 1.2e6))
    @test pressure_bad.status == :fail
    @test "scalar_pressure_energy_consistency:$domain" in
        pressure_bad.failed_check_ids

    incomplete = compile_runtime_species_state_evidence_v1(
        design_id = genome.design_id, genome_physics_hash = genome.physics_hash,
        domain_id = domain, species_id = "electron", density_m3 = 1.0e20)
    incomplete_assessment = assess_runtime_species_state_v1(problem,
        [incomplete, rss_state(genome, domain, "deuterium")])
    @test incomplete_assessment.status == :unknown
    @test !incomplete_assessment.complete_required_state
end
