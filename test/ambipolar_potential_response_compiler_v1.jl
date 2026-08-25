using Test
using FusionConceptAI

const _AMBIPOLAR_TEST_HASH = repeat("d", 64)

function _ambipolar_manufactured_problem_v1(; authoritative = false,
        missing = false, multiple = false)
    z = [-0.5, 0.0, 0.5]
    missing && return compile_ambipolar_potential_response_problem_v1(
        design_id = "ambipolar_probe", genome_physics_hash = _AMBIPOLAR_TEST_HASH,
        domain_id = "core", axial_positions_m = z)
    phi = 1.0e-17 .* [-2.0, -1.0, 0.0, 1.0, 2.0]
    n0 = [1.0e19, 1.2e19, 1.0e19]
    electron = zeros(5, 3)
    deuterium = zeros(5, 3)
    for iphi in eachindex(phi), iz in eachindex(z)
        x = phi[iphi] / 1.0e-17
        deuterium[iphi, iz] = n0[iz] * (1.0 + 0.02x)
        electron[iphi, iz] = multiple ?
            deuterium[iphi, iz] - 1.0e17 * (x^2 - 1.0) :
            deuterium[iphi, iz] - 1.0e17 * x
    end
    compile_ambipolar_potential_response_problem_v1(
        design_id = "ambipolar_probe", genome_physics_hash = _AMBIPOLAR_TEST_HASH,
        domain_id = "core", axial_positions_m = z,
        elementary_charge_times_potential_grid_j = phi,
        electron_density_response_m3 = electron,
        ion_density_responses_m3 = Dict("deuterium" => deuterium),
        ion_charge_numbers = Dict("deuterium" => 1),
        response_source_kind = authoritative ? :candidate_solver : :manufactured,
        response_source_artifact_id = "kinetic_response.h5",
        response_source_artifact_hash = repeat("e", 64),
        response_source_result_hash = repeat("f", 64),
        response_candidate_binding_verified = authoritative,
        nonlinear_multispecies_response_verified = authoritative,
        bounce_average_verified = authoritative,
        resolution_verified = authoritative,
        applicability_verified = authoritative,
        source_solver_status = :pass,
        source_ids = ["frank_et_al_cql3dm_2025"])
end

@testset "Ambipolar response root is local and non-family-routed v1" begin
    problem = _ambipolar_manufactured_problem_v1()
    observation = solve_ambipolar_potential_response_v1(problem)
    @test observation.status == :pass
    @test observation.numerical_root_complete
    @test observation.elementary_charge_times_potential_roots_j == zeros(3)
    @test observation.root_count_by_axial_location == ones(Int, 3)
    @test observation.maximum_relative_quasineutrality_residual == 0.0
    @test !observation.c2_ambipolar_profile_authorized
    @test "solve_nonlinear_multispecies_coulomb_response" in
        observation.evidence_tasks
    @test length(problem.problem_hash) == 64
    @test length(observation.observation_hash) == 64
end

@testset "Ambipolar C2 requires every independent evidence gate v1" begin
    authorized = solve_ambipolar_potential_response_v1(
        _ambipolar_manufactured_problem_v1(authoritative = true))
    @test authorized.status == :pass
    @test authorized.c2_ambipolar_profile_authorized
    @test isempty(authorized.evidence_tasks)
    proxy = solve_ambipolar_potential_response_v1(
        _ambipolar_manufactured_problem_v1())
    @test !proxy.c2_ambipolar_profile_authorized
    @test ambipolar_potential_response_observation_to_dict_v1(proxy)["status"] ==
        "pass"
    @test ambipolar_potential_response_problem_to_dict_v1(
        _ambipolar_manufactured_problem_v1())["response_source_kind"] ==
        "manufactured"
end

@testset "Missing and multiple ambipolar responses fail closed v1" begin
    missing = solve_ambipolar_potential_response_v1(
        _ambipolar_manufactured_problem_v1(missing = true))
    @test missing.status == :unknown
    @test !missing.numerical_root_complete
    @test missing.elementary_charge_times_potential_roots_j === nothing
    @test "provide_candidate_electron_density_response_vs_ephi" in
        missing.evidence_tasks
    multiple = solve_ambipolar_potential_response_v1(
        _ambipolar_manufactured_problem_v1(multiple = true))
    @test multiple.status == :unknown
    @test !multiple.numerical_root_complete
    @test all(==(2), multiple.root_count_by_axial_location)
    @test any(startswith("resolve_multiple_ambipolar_roots"),
        multiple.evidence_tasks)
end

@testset "Ambipolar response tensors enforce physical shape v1" begin
    @test_throws ArgumentError compile_ambipolar_potential_response_problem_v1(
        design_id = "bad", genome_physics_hash = _AMBIPOLAR_TEST_HASH,
        domain_id = "core", axial_positions_m = [0.0, 0.0])
    @test_throws ArgumentError compile_ambipolar_potential_response_problem_v1(
        design_id = "bad", genome_physics_hash = _AMBIPOLAR_TEST_HASH,
        domain_id = "core", axial_positions_m = [0.0, 1.0],
        elementary_charge_times_potential_grid_j = [-1.0, 0.0, 1.0],
        electron_density_response_m3 = ones(3, 2))
    @test_throws ArgumentError compile_ambipolar_potential_response_problem_v1(
        design_id = "bad", genome_physics_hash = _AMBIPOLAR_TEST_HASH,
        domain_id = "core", axial_positions_m = [0.0, 1.0],
        elementary_charge_times_potential_grid_j = [-1.0, 0.0, 1.0],
        electron_density_response_m3 = ones(3, 2),
        ion_density_responses_m3 = Dict("d" => ones(3, 2)),
        ion_charge_numbers = Dict("t" => 1))
end
