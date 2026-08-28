@testset "candidate-bound VVUQ v87" begin
    digest(label) = canonical_hash(Dict("label" => label))
    candidate = "candidate-v87"
    physics = digest("physics")
    exact_state = digest("exact-state")
    observables = ["aspect_ratio", "volume_average_beta"]

    verification_runs = Any[]
    for (index, mesh) in enumerate((100, 400, 1600))
        push!(verification_runs, Dict(
            "mesh_dof" => mesh,
            "solver_input_hash" => digest("verify-input-$index"),
            "result_hash" => digest("verify-result-$index"),
            "mesh_hash" => digest("verify-mesh-$index"),
            "equation_residual" => 10.0^(-5 - index),
            "observables" => Dict("aspect_ratio" => 6.0 + 1.0e-4 / index,
                "volume_average_beta" => 0.02 + 1.0e-6 / index)))
    end
    verification = Dict(
        "candidate_id" => candidate, "physics_hash" => physics,
        "exact_state_hash" => exact_state,
        "runs" => verification_runs, "required_observables" => observables,
        "maximum_finest_residual" => 1.0e-7,
        "relative_change_tolerances" => Dict(id => 1.0e-3 for id in observables))

    uq_samples = Any[]
    for index in 1:8
        push!(uq_samples, Dict(
            "physical_input_hash" => digest("uq-input-$index"),
            "result_hash" => digest("uq-result-$index"), "weight" => 0.125,
            "hard_gate_pass" => true,
            "observables" => Dict("aspect_ratio" => 6.0 + 0.001 * index,
                "volume_average_beta" => 0.02 + 1.0e-5 * index)))
    end
    uq = Dict(
        "candidate_id" => candidate, "physics_hash" => physics,
        "exact_state_hash" => exact_state,
        "distribution_manifest_hash" => digest("distribution"),
        "covariance_hash" => digest("covariance"),
        "sampling_plan_hash" => digest("sampling"),
        "minimum_sample_count" => 8, "samples" => uq_samples,
        "required_observables" => observables,
        "maximum_observed_failure_fraction" => 0.0)

    input_manifest = digest("common-input")
    cross = Dict(
        "candidate_id" => candidate, "physics_hash" => physics,
        "exact_state_hash" => exact_state,
        "code_runs" => Any[
            Dict("run_id" => "a", "code_name" => "DESC", "code_version" => "1",
                "software_hash" => digest("software-a"),
                "container_hash" => digest("container-a"),
                "input_manifest_hash" => input_manifest,
                "mesh_hash" => digest("mesh-a"), "result_hash" => digest("result-a"),
                "production_authority" => "independent_pipeline",
                "mesh_generation" => "independently_generated"),
            Dict("run_id" => "b", "code_name" => "VMEX", "code_version" => "1",
                "software_hash" => digest("software-b"),
                "container_hash" => digest("container-b"),
                "input_manifest_hash" => input_manifest,
                "mesh_hash" => digest("mesh-b"), "result_hash" => digest("result-b"),
                "production_authority" => "independent_pipeline",
                "mesh_generation" => "independently_generated")],
        "observable_comparisons" => Any[
            Dict("observable_id" => "aspect_ratio", "run_a_id" => "a",
                "run_b_id" => "b", "value_a" => 6.0, "value_b" => 6.001,
                "unit" => "1", "absolute_tolerance" => 0.0,
                "relative_tolerance" => 1.0e-3)],
        "model_differences" => Any[Dict("id" => "independent methods")])
    anchor = Dict(
        "anchor_id" => "measured-anchor", "candidate_id" => candidate,
        "physics_hash" => physics, "exact_state_hash" => exact_state,
        "anchor_kind" => "measured_experiment",
        "device_id" => "device", "campaign_id" => "campaign",
        "shot_or_condition_id" => "shot",
        "provenance" => Dict(
            "raw_data_hash" => digest("raw"), "calibration_hash" => digest("cal"),
            "transfer_function_hash" => digest("transfer"),
            "uncertainty_covariance_hash" => digest("experimental-covariance")),
        "operating_history" => Dict(
            "boundary_history_hash" => digest("boundary-history"),
            "initial_state_hash" => digest("initial-history"),
            "control_history_hash" => digest("control-history")),
        "observable_comparisons" => Any[
            Dict("observable_id" => "aspect_ratio", "measured_value" => 6.0,
                "model_value" => 6.01, "combined_standard_uncertainty" => 0.02,
                "acceptance_sigma" => 2.0, "unit" => "1",
                "model_output_hash" => digest("model-output"))],
        "supported_claims" => ["aspect ratio within declared condition"])

    decision = compile_candidate_vvuq_decision_v87(candidate, physics, exact_state;
        solution_verification_record = verification, parametric_uq_record = uq,
        cross_code_record = cross, experimental_anchor_record = anchor)
    @test decision["status"] == "pass"
    @test decision["numerical_vvuq_status"] == "pass"
    @test decision["validation_vvuq_status"] == "pass"
    @test decision["screening_feedback_authorized"]
    @test decision["engineering_acceptance_authorized"]
    @test decision["solution_verification"]["status"] == "pass"
    @test decision["parametric_uq"]["status"] == "pass"

    incomplete = compile_candidate_vvuq_decision_v87(candidate, physics, exact_state;
        solution_verification_record = verification, parametric_uq_record = uq,
        cross_code_record = cross)
    @test incomplete["status"] == "unknown_external_or_numerical_evidence_required"
    @test incomplete["numerical_vvuq_status"] == "pass"
    @test incomplete["screening_feedback_authorized"]
    @test !incomplete["engineering_acceptance_authorized"]
    @test incomplete["experimental_anchor"]["status"] == "unknown"

    hard_gate_failure = Dict(
        "gate_id" => "sampled_ideal_mhd_stability", "status" => "fail",
        "classification_code" => "sampled_ideal_mhd_stability_unfavorable",
        "evidence_hash" => digest("stability-evidence"))
    rejected = compile_candidate_vvuq_decision_v87(candidate, physics, exact_state;
        solution_verification_record = verification, parametric_uq_record = uq,
        cross_code_record = cross, experimental_anchor_record = anchor,
        pre_vvuq_hard_gate_record = hard_gate_failure)
    @test rejected["status"] == "fail"
    @test rejected["numerical_vvuq_status"] == "fail"
    @test !rejected["screening_feedback_authorized"]
    @test !rejected["engineering_acceptance_authorized"]
    @test rejected["pre_vvuq_hard_physics_gate"]["status"] == "fail"

    copied_uq = deepcopy(uq)
    copied_uq["samples"][2]["physical_input_hash"] =
        copied_uq["samples"][1]["physical_input_hash"]
    unsupported = compile_parametric_uq_v87(copied_uq, candidate, physics)
    @test unsupported["status"] == "unsupported"

    mismatched_cross = deepcopy(cross)
    mismatched_cross["exact_state_hash"] = digest("other-state")
    @test_throws ArgumentError compile_candidate_vvuq_decision_v87(candidate,
        physics, exact_state; solution_verification_record = verification,
        parametric_uq_record = uq, cross_code_record = mismatched_cross,
        experimental_anchor_record = anchor)
end
