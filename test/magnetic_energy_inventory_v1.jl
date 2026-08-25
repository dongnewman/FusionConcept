using Test
using JSON3
using FusionConceptAI

const MEI_ROOT = normpath(joinpath(@__DIR__, ".."))
const MEI_GENOME = joinpath(MEI_ROOT, "examples",
    "freegs_pointcoil_wall_control_genome_v1.json")

function mei_observation(genome; nr = 17, nz = 25, energy = 10.0,
        binding = true, fidelity = 2, solver_status = :pass,
        domain_id = "manufactured_cylinder")
    return compile_magnetic_energy_observation_v1(
        design_id = genome.design_id, genome_physics_hash = genome.physics_hash,
        domain_id = domain_id, coordinate_system = "cylindrical_axisymmetric",
        radial_points = nr, axial_points = nz, domain_volume_m3 = 2pi,
        magnetic_energy_j = energy, poloidal_energy_j = energy,
        toroidal_energy_j = 0.0, peak_energy_density_j_m3 = energy / (2pi),
        source_artifact_id = "manufactured_field_$nr.json",
        source_artifact_hash = repeat("a", 64),
        source_result_hash = repeat("b", 64), source_solver_status = solver_status,
        candidate_binding_verified = binding, fidelity = fidelity)
end

@testset "Axisymmetric magnetic-energy integration v1" begin
    radius = collect(range(0.0, 1.0; length = 41))
    axial = collect(range(-1.0, 1.0; length = 61))
    br = fill(2.0, length(axial), length(radius))
    zero_field = zeros(length(axial), length(radius))
    result = integrate_axisymmetric_magnetic_energy_v1(radius, axial,
        br, zero_field, zero_field)
    analytic_volume = 2pi
    analytic_energy = 4.0 / (2 * (4e-7 * pi)) * analytic_volume
    @test isapprox(result["domain_volume_m3"], analytic_volume; rtol = 1e-12)
    @test isapprox(result["magnetic_energy_j"], analytic_energy; rtol = 1e-12)
    @test result["toroidal_energy_j"] == 0.0
    @test_throws ArgumentError integrate_axisymmetric_magnetic_energy_v1(
        reverse(radius), axial, br, zero_field, zero_field)
end

@testset "Magnetic-energy evidence fails closed v1" begin
    genome = load_genome(MEI_GENOME)
    observations = [mei_observation(genome; nr = nr, nz = nr,
        energy = energy) for (nr, energy) in ((17, 10.3), (33, 10.1), (65, 10.0))]
    convergence = compile_magnetic_energy_convergence_v1(observations)
    @test convergence.status == :pass
    @test convergence.c2_inventory_support_authorized
    @test !convergence.complete_magnet_engineering_authorized
    @test !convergence.conservation_power_term_authorized
    bundle = magnetic_energy_evidence_bundle_v1(genome, convergence)
    @test bundle.claim_ceiling ==
        "C2_support_finite_domain_magnetic_energy_inventory_only"

    unbound = [mei_observation(genome; nr = nr, nz = nr,
        energy = energy, binding = nr != 33) for
        (nr, energy) in ((17, 10.3), (33, 10.1), (65, 10.0))]
    unresolved = compile_magnetic_energy_convergence_v1(unbound)
    @test unresolved.status == :unknown
    @test !unresolved.c2_inventory_support_authorized

    unbound_nonconverged = [mei_observation(genome; nr = nr, nz = nr,
        energy = energy, binding = nr != 33) for
        (nr, energy) in ((17, 5.0), (33, 7.0), (65, 10.0))]
    @test compile_magnetic_energy_convergence_v1(
        unbound_nonconverged).status == :unknown

    low_fidelity = [mei_observation(genome; nr = nr, nz = nr,
        energy = energy, fidelity = 1) for
        (nr, energy) in ((17, 10.3), (33, 10.1), (65, 10.0))]
    @test compile_magnetic_energy_convergence_v1(low_fidelity).status == :unknown

    nonconverged = [mei_observation(genome; nr = nr, nz = nr,
        energy = energy) for
        (nr, energy) in ((17, 5.0), (33, 7.0), (65, 10.0))]
    failed = compile_magnetic_energy_convergence_v1(nonconverged)
    @test failed.status == :fail
    @test !failed.c2_inventory_support_authorized

    wrong_hash = MagneticEnergyObservationV1(observations[1].design_id,
        repeat("0", 64), observations[1].domain_id,
        observations[1].coordinate_system, observations[1].radial_points,
        observations[1].axial_points, observations[1].domain_volume_m3,
        observations[1].magnetic_energy_j, observations[1].poloidal_energy_j,
        observations[1].toroidal_energy_j,
        observations[1].peak_energy_density_j_m3,
        observations[1].source_artifact_id,
        observations[1].source_artifact_hash,
        observations[1].source_result_hash,
        observations[1].source_solver_status,
        observations[1].candidate_binding_verified, observations[1].fidelity,
        observations[1].finite_build_resolved, observations[1].status,
        observations[1].evidence_tasks, observations[1].warnings,
        observations[1].observation_hash)
    @test_throws ArgumentError compile_magnetic_energy_convergence_v1(
        [wrong_hash, observations[2], observations[3]])

    raw = JSON3.read(read(MEI_GENOME, String), Dict{String,Any})
    raw["family"] = "declassified_physical_control"
    renamed = parse_genome(raw)
    renamed_observations = [mei_observation(renamed; nr = nr, nz = nr,
        energy = energy) for (nr, energy) in
        ((17, 10.3), (33, 10.1), (65, 10.0))]
    renamed_convergence = compile_magnetic_energy_convergence_v1(
        renamed_observations)
    renamed_bundle = magnetic_energy_evidence_bundle_v1(renamed,
        renamed_convergence)
    @test renamed_bundle.status == bundle.status
    @test renamed_bundle.claim_ceiling == bundle.claim_ceiling
    @test renamed_convergence.medium_to_fine_relative_change ==
        convergence.medium_to_fine_relative_change
end
