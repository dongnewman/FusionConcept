function offlr_problem(nq, resolution; k = [0.0, 1.0, 3.0])
    return compile_open_field_flr_problem_v1(
        candidate_binding_hash = repeat("4", 64), state_result_hash = repeat("5", 64),
        resolution_id = resolution, perpendicular_wavenumber_m_inv = k,
        perpendicular_temperature_j = fill(1.0e-15, length(k)),
        magnetic_field_t = fill(2.0, length(k)), species_mass_kg = 3.3435837724e-27,
        absolute_charge_c = 1.602176634e-19, angular_quadrature_count = nq,
        source_artifact_paths = ["distribution.json"],
        source_artifact_hashes = [repeat("6", 64)], validity_domain_covered = true,
        claim_boundary = "Local gyroaverage kernel only; no mode stability without coupled response.")
end

@testset "FLR gyroaverage kernel requires coupled mode evidence" begin
    problems = [offlr_problem(nq, "$(nq)_angle") for nq in (32, 64, 128)]
    observations = solve_open_field_flr_problem_v1.(problems)
    @test all(o -> o.gamma0[1] == 1.0, observations)
    @test all(o -> abs(o.gamma1[1]) <= 1.0e-15, observations)
    @test all(o -> all(0.0 .<= o.gamma0 .<= 1.0), observations)
    convergence = compile_open_field_flr_convergence_v1(observations;
        maximum_gamma_change = 1.0e-12)
    @test convergence.status == :pass
    @test convergence.resolution_verified

    kernel_only = compile_flr_stage4_evidence_v2(problems, convergence)
    @test kernel_only.status == :unknown
    @test !kernel_only.evidence_authorized
    @test "provide_operator_input:finite_larmor_radius_v2:coupled_mode_response" in
        kernel_only.evidence_tasks

    coupled = compile_flr_stage4_evidence_v2(problems, convergence;
        coupled_mode_response_hash = repeat("7", 64),
        coupled_mode_response_favorable = false, signed_normalized_margin = -0.2)
    @test coupled.status == :fail
    @test coupled.evidence_authorized
end
