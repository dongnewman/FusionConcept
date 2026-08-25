function ofdclc_problem(nv, nq, resolution; root_covered = false)
    v = collect(range(0.0, 4.0; length = nv))
    f = exp.(-v .^ 2) ./ pi
    guesses = root_covered ? ComplexF64[n + 0.35 + 0.05im for n in -2:2] :
        ComplexF64[0.5 + 0.01im]
    return compile_open_field_dclc_problem_v1(
        candidate_binding_hash = repeat("8", 64), state_result_hash = repeat("9", 64),
        resolution_id = resolution, normalized_perpendicular_speed = v,
        reduced_distribution = f, normalized_wavenumbers = [1.0],
        normalized_density_gradient = 0.0, ion_plasma_to_cyclotron_ratio_sq = 1.0,
        electron_plasma_to_cyclotron_ratio_sq = 0.01, electron_drift_prefactor = 0.0,
        harmonic_cutoff = 2, bessel_quadrature_count = nq,
        initial_root_guesses = guesses, root_search_domain_covered = root_covered,
        validity_domain_covered = true, source_artifact_paths = ["distribution.json"],
        source_artifact_hashes = [repeat("a", 64)],
        claim_boundary = "Local k_parallel=0 slab DCLC only; no 3-D or nonlinear saturation claim.")
end

@testset "Slab DCLC susceptibility is distribution-bound and fail closed" begin
    @test isapprox(FusionConceptAI._dclc_besselj_v1(0, 0.0, 128), 1.0; atol = 1.0e-14)
    @test abs(FusionConceptAI._dclc_besselj_v1(1, 0.0, 128)) <= 1.0e-14
    @test isapprox(FusionConceptAI._dclc_besselj_v1(0, 1.0, 256),
        0.7651976865579666; atol = 1.0e-12)
    @test isapprox(FusionConceptAI._dclc_besselj_v1(1, 1.0, 256),
        0.4400505857449335; atol = 1.0e-12)

    problem = ofdclc_problem(33, 96, "33v_96q")
    @test abs(FusionConceptAI._dclc_distribution_normalization_v1(problem) - 1.0) < 0.01
    value = open_field_dclc_dispersion_v1(problem, 1.0, 1.5 + 0.1im)
    @test isfinite(real(value)) && isfinite(imag(value))
    observation = solve_open_field_dclc_problem_v1(problem)
    @test observation.status == :unknown
    @test !observation.root_search_complete

    @test_throws ArgumentError compile_open_field_dclc_problem_v1(
        candidate_binding_hash = repeat("8", 64), state_result_hash = repeat("9", 64),
        resolution_id = "bad", normalized_perpendicular_speed = problem.normalized_perpendicular_speed,
        reduced_distribution = problem.reduced_distribution, normalized_wavenumbers = [1.0],
        normalized_density_gradient = 0.0, ion_plasma_to_cyclotron_ratio_sq = 1.0,
        electron_plasma_to_cyclotron_ratio_sq = 0.01, electron_drift_prefactor = 0.0,
        harmonic_cutoff = 2, bessel_quadrature_count = 64,
        initial_root_guesses = ComplexF64[0.5 + 0.01im], root_search_domain_covered = true,
        validity_domain_covered = true, claim_boundary = "bad")
end
