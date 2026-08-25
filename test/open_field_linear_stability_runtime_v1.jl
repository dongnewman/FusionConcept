const OFLS_ROOT = normpath(joinpath(@__DIR__, ".."))

function ofls_direct_problem(id, resolution, K; covered = ["state", "coefficients"])
    n = size(K, 1)
    return compile_open_field_linear_mode_problem_v1(
        candidate_binding_hash = repeat("a", 64), state_result_hash = repeat("b", 64),
        operator_id = id, resolution_id = resolution,
        coordinate_m = collect(range(0.0, 1.0; length = n)),
        mass_matrix = Matrix{Float64}(I, n, n), damping_matrix = zeros(n, n),
        stiffness_matrix = K, required_input_ids = ["state", "coefficients"],
        covered_input_ids = covered, validity_domain_covered = true,
        equation = "manufactured M*q_tt + K*q = 0",
        claim_boundary = "Manufactured algebra only; no candidate stability evidence.")
end

@testset "Open-field second-order eigen runtime is fail closed" begin
    stable = ofls_direct_problem("interchange_flute_v2", "8_cells", Matrix{Float64}(I, 8, 8))
    stable_obs = solve_open_field_linear_mode_problem_v1(stable;
        growth_tolerance_s_inv = 1.0e-10)
    @test stable_obs.status == :pass
    @test stable_obs.favorable === true
    @test stable_obs.maximum_eigenpair_relative_residual <= 1.0e-12
    @test isapprox(stable_obs.dominant_frequency_rad_s, 1.0; atol = 1.0e-12)

    unstable_observations = OpenFieldLinearModeObservationV1[]
    for (id, n) in (("8_cells", 8), ("16_cells", 16), ("32_cells", 32))
        problem = ofls_direct_problem("m1_global_v2", id, -Matrix{Float64}(I, n, n))
        push!(unstable_observations, solve_open_field_linear_mode_problem_v1(problem))
    end
    convergence = compile_open_field_linear_mode_convergence_v1(unstable_observations;
        maximum_growth_change_s_inv = 1.0e-12)
    @test convergence.status == :fail
    @test convergence.favorable === false
    @test convergence.resolution_verified
    @test isapprox(convergence.signed_normalized_margin, -1.0; atol = 1.0e-12)

    problems = [ofls_direct_problem("m1_global_v2", id, -Matrix{Float64}(I, n, n))
        for (id, n) in (("8_cells", 8), ("16_cells", 16), ("32_cells", 32))]
    # Recompile with the exact common Stage-4 input contract and explicit provenance.
    contract_problems = OpenFieldLinearModeProblemV1[]
    for problem in problems
        n = length(problem.coordinate_m)
        push!(contract_problems, compile_open_field_linear_mode_problem_v1(
            candidate_binding_hash = problem.candidate_binding_hash,
            state_result_hash = problem.state_result_hash, operator_id = "m1_global_v2",
            resolution_id = problem.resolution_id, coordinate_m = problem.coordinate_m,
            mass_matrix = Matrix{Float64}(I, n, n), damping_matrix = zeros(n, n),
            stiffness_matrix = -Matrix{Float64}(I, n, n),
            required_input_ids = ["finite_beta_equilibrium", "conducting_boundary", "axial_profile"],
            covered_input_ids = ["finite_beta_equilibrium", "conducting_boundary", "axial_profile"],
            validity_domain_covered = true, source_artifact_paths = ["candidate_solver.json"],
            source_artifact_hashes = [repeat("f", 64)], equation = problem.equation,
            claim_boundary = "Reduced linear m1 operator only."))
    end
    contract_observations = solve_open_field_linear_mode_problem_v1.(contract_problems)
    contract_convergence = compile_open_field_linear_mode_convergence_v1(contract_observations;
        maximum_growth_change_s_inv = 1.0e-12)
    evidence = compile_open_linear_stage4_evidence_v2(contract_problems,
        contract_convergence)
    @test evidence.status == :fail
    @test evidence.evidence_authorized
    @test evidence.perturbation.time_semantics == :eigenvalue

    missing = ofls_direct_problem("interchange_flute_v2", "8_cells",
        Matrix{Float64}(I, 8, 8); covered = ["state"])
    missing_obs = solve_open_field_linear_mode_problem_v1(missing)
    @test missing_obs.status == :unknown
    @test missing_obs.missing_input_ids == ["coefficients"]
end

@testset "Interchange and m1 coefficient builders preserve physical sign" begin
    z = collect(range(-1.0, 1.0; length = 17))
    common = (candidate_binding_hash = repeat("c", 64),
        state_result_hash = repeat("d", 64), resolution_id = "17_cells",
        required_input_ids = ["finite_beta_state", "pressure_profile",
            "magnetic_curvature", "stabilization_model"],
        covered_input_ids = ["finite_beta_state", "pressure_profile",
            "magnetic_curvature", "stabilization_model"],
        validity_domain_covered = true,
        source_artifact_paths = ["manufactured.json"],
        source_artifact_hashes = [repeat("e", 64)],
        claim_boundary = "Manufactured coefficient profile only.")
    stable = compile_open_interchange_problem_v1(; coordinate_m = z,
        inertia_kg_m3 = ones(17), field_line_tension_n_m2 = ones(17),
        curvature_pressure_drive_n_m4 = zeros(17), damping_kg_m3_s = fill(0.1, 17),
        common...)
    @test solve_open_field_linear_mode_problem_v1(stable;
        growth_tolerance_s_inv = 1.0e-9).status == :pass

    m1 = compile_open_m1_problem_v1(; coordinate_m = z,
        inertia_kg_m3 = ones(17), field_line_tension_n_m2 = ones(17),
        pressure_drive_n_m4 = fill(2.0, 17), anchor_stiffness_n_m4 = fill(3.0, 17),
        damping_kg_m3_s = fill(0.1, 17), common...)
    @test m1.operator_id == "m1_global_v2"
    @test solve_open_field_linear_mode_problem_v1(m1;
        growth_tolerance_s_inv = 1.0e-9).status == :pass
end
