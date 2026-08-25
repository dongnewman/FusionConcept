function ofaic_problem(nq, resolution; validity = true, ion_anisotropy = 1.0,
        wavenumbers = [0.15, 0.3], real_bounds = (0.03, 1.2),
        growth_bounds = (0.02, 0.6), seed_counts = (8, 5), contour_count = 48)
    ion = AICBiMaxwellianSpeciesV1("ion";
        cyclotron_to_reference_ratio = 1.0,
        plasma_to_reference_cyclotron_ratio_sq = 400.0,
        parallel_thermal_to_alfven_ratio = sqrt(0.2),
        perpendicular_to_parallel_temperature_ratio = ion_anisotropy)
    electron = AICBiMaxwellianSpeciesV1("electron";
        cyclotron_to_reference_ratio = -25.0,
        plasma_to_reference_cyclotron_ratio_sq = 10_000.0,
        parallel_thermal_to_alfven_ratio = sqrt(5.0),
        perpendicular_to_parallel_temperature_ratio = 1.0)
    return compile_open_field_aic_problem_v1(
        candidate_binding_hash = repeat("b", 64), state_result_hash = repeat("c", 64),
        resolution_id = resolution, normalized_wavenumbers = wavenumbers,
        light_to_alfven_speed_ratio = 20.0, polarization_sign = 1,
        species = [ion, electron], root_real_bounds = real_bounds,
        root_growth_bounds = growth_bounds, root_seed_counts = seed_counts,
        contour_points_per_side = contour_count, plasma_dispersion_quadrature_count = nq,
        validity_domain_covered = validity, source_artifact_paths = ["anisotropy.json"],
        source_artifact_hashes = [repeat("d", 64)],
        claim_boundary = "Uniform parallel bi-Maxwellian AIC only; no finite-length, non-Maxwellian, oblique, or nonlinear-saturation claim.")
end

@testset "Parallel bi-Maxwellian AIC response and root census fail closed" begin
    z0 = plasma_dispersion_function_v1(0.0, 64)
    @test abs(real(z0)) < 1.0e-12
    @test isapprox(imag(z0), sqrt(pi); atol = 1.0e-12)
    z = 0.4 + 0.5im
    h = 1.0e-6
    derivative = (plasma_dispersion_function_v1(z + h, 128) -
        plasma_dispersion_function_v1(z - h, 128)) / (2h)
    @test isapprox(derivative, -2.0 * (1.0 + z * plasma_dispersion_function_v1(z, 128));
        rtol = 2.0e-5, atol = 2.0e-5)

    problem = ofaic_problem(32, "q32")
    value = open_field_aic_dispersion_v1(problem, 0.3, 0.5 + 0.1im)
    @test isfinite(real(value)) && isfinite(imag(value))
    observation = solve_open_field_aic_problem_v1(problem)
    @test observation.status in (:pass, :fail, :unknown)
    @test observation.status == :unknown || observation.root_census_complete

    unstable = ofaic_problem(64, "anisotropic"; ion_anisotropy = 3.0,
        wavenumbers = collect(0.5:0.1:1.0), real_bounds = (0.02, 1.3),
        growth_bounds = (0.005, 0.8), seed_counts = (20, 12), contour_count = 256)
    unstable_observation = solve_open_field_aic_problem_v1(unstable)
    @test unstable_observation.status == :fail
    @test unstable_observation.root_census_complete
    @test unstable_observation.unstable_root_count == 6
    @test unstable_observation.maximum_normalized_growth_rate > 0.05
    @test unstable_observation.maximum_dispersion_residual < 1.0e-8

    invalid = ofaic_problem(32, "invalid"; validity = false)
    invalid_observation = solve_open_field_aic_problem_v1(invalid)
    @test invalid_observation.status == :unknown
    @test !invalid_observation.root_census_complete

    @test_throws ArgumentError compile_open_field_aic_problem_v1(
        candidate_binding_hash = repeat("b", 64), state_result_hash = repeat("c", 64),
        resolution_id = "bad", normalized_wavenumbers = [0.2],
        light_to_alfven_speed_ratio = 20.0, species = problem.species,
        root_real_bounds = (0.0, 1.0), root_growth_bounds = (0.01, 0.5),
        validity_domain_covered = true, claim_boundary = "bad")
end

@testset "AIC Stage-4 bridge requires candidate inputs and known control" begin
    problems = [ofaic_problem(nq, "q$(nq)") for nq in (32, 64, 128)]
    observations = solve_open_field_aic_problem_v1.(problems)
    convergence = compile_open_field_aic_convergence_v1(observations;
        maximum_growth_change = 0.05)
    evidence = compile_aic_stage4_evidence_v2(problems, convergence;
        ion_distribution_verified = true, pressure_anisotropy_verified = true,
        beta_profile_verified = true, cyclotron_spectrum_verified = true,
        known_control_verified = false)
    @test evidence.status == :unknown
    @test !evidence.evidence_authorized
    @test "provide_source_result_hash" in evidence.evidence_tasks
end
