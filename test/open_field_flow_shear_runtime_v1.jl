function offsr_problem(n, resolution; growth = 0.05, velocity_scale = 1.0,
        covered = ["electric_field_profile", "flow_profile", "magnetic_field", "mode_spectrum"])
    r = collect(range(0.1, 1.0; length = n))
    b = fill(2.0, n)
    v = velocity_scale .* r .^ 2
    return compile_open_field_flow_shear_problem_v1(
        candidate_binding_hash = repeat("1", 64), state_result_hash = repeat("2", 64),
        resolution_id = resolution, radius_m = r,
        radial_electric_field_v_m = -v .* b, magnetic_field_t = b,
        declared_exb_velocity_m_s = v,
        target_mode_growth_rate_s_inv = fill(growth, n), covered_input_ids = covered,
        validity_domain_covered = true, source_artifact_paths = ["flow.json"],
        source_artifact_hashes = [repeat("3", 64)],
        claim_boundary = "Manufactured cylindrical flow profile only.")
end

@testset "Candidate-bound ExB flow-shear criterion is non-compensating" begin
    problems = [offsr_problem(n, "$(n)_radial") for n in (17, 33, 65)]
    observations = solve_open_field_flow_shear_problem_v1.(problems)
    @test all(o -> o.status == :pass, observations)
    @test all(o -> o.maximum_exb_consistency_relative_error <= 1.0e-14, observations)
    convergence = compile_open_field_flow_shear_convergence_v1(observations;
        maximum_margin_change_s_inv = 1.0e-12)
    @test convergence.status == :pass
    @test convergence.resolution_verified
    evidence = compile_flow_shear_stage4_evidence_v2(problems, convergence)
    @test evidence.status == :pass
    @test evidence.evidence_authorized

    failed = solve_open_field_flow_shear_problem_v1(offsr_problem(33, "33_radial";
        growth = 0.2))
    @test failed.status == :fail
    @test failed.minimum_shear_margin_s_inv < 0.0

    missing = solve_open_field_flow_shear_problem_v1(offsr_problem(17, "17_radial";
        covered = ["electric_field_profile", "magnetic_field", "mode_spectrum"]))
    @test missing.status == :unknown
    @test missing.missing_input_ids == ["flow_profile"]
end
