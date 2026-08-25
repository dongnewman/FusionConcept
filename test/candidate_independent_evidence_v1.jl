@testset "Candidate independent evidence protocols v1" begin
    candidate_id = "candidate_v65_test"
    physics_hash = repeat("a", 64)
    missing_cross = compile_cross_code_replication_envelope_v1(nothing,
        candidate_id, physics_hash)
    @test missing_cross.status == :unknown
    @test isempty(missing_cross.code_runs)
    run_a = Dict("run_id" => "a", "code_name" => "code_a", "code_version" => "1.0",
        "software_hash" => repeat("b", 64), "container_hash" => repeat("c", 64),
        "input_manifest_hash" => repeat("d", 64), "mesh_hash" => repeat("e", 64),
        "result_hash" => repeat("f", 64), "production_authority" => "independent_team",
        "mesh_generation" => "independently_generated")
    run_b = Dict("run_id" => "b", "code_name" => "code_b", "code_version" => "2.0",
        "software_hash" => repeat("1", 64), "container_hash" => repeat("2", 64),
        "input_manifest_hash" => repeat("d", 64), "mesh_hash" => repeat("3", 64),
        "result_hash" => repeat("4", 64), "production_authority" => "independent_pipeline",
        "mesh_generation" => "independently_generated")
    raw_cross = Dict("candidate_id" => candidate_id, "physics_hash" => physics_hash,
        "code_runs" => [run_a, run_b],
        "observable_comparisons" => [Dict("observable_id" => "peak_field",
            "run_a_id" => "a", "run_b_id" => "b", "value_a" => 10.0,
            "value_b" => 10.1, "unit" => "T", "absolute_tolerance" => 0.2,
            "relative_tolerance" => 0.01)],
        "model_differences" => [Dict("difference_id" => "discretization",
            "code_a_basis" => "finite_volume", "code_b_basis" => "finite_element")])
    cross = compile_cross_code_replication_envelope_v1(raw_cross,
        candidate_id, physics_hash)
    @test cross.status == :pass
    @test cross.observable_comparisons[1]["status"] == "pass"
    @test cross.observable_comparisons[1]["normalized_discrepancy"] <= 1.0
    copied = deepcopy(raw_cross)
    copied["code_runs"][2]["software_hash"] = copied["code_runs"][1]["software_hash"]
    copied["code_runs"][2]["container_hash"] = copied["code_runs"][1]["container_hash"]
    copied_cross = compile_cross_code_replication_envelope_v1(copied,
        candidate_id, physics_hash)
    @test copied_cross.status == :unsupported
    @test any(contains("not independent"), copied_cross.unresolved_reasons)

    design = compile_experimental_anchor_v1(Dict("anchor_id" => "iter_design",
        "anchor_kind" => "published_design_reference"), candidate_id, physics_hash)
    @test design.status == :unknown
    @test occursin("no experimental-validation credit", design.evidence_ceiling)
    raw_anchor = Dict("anchor_id" => "measured_anchor", "anchor_kind" => "measured_experiment",
        "candidate_id" => candidate_id, "physics_hash" => physics_hash,
        "device_id" => "device", "campaign_id" => "campaign",
        "shot_or_condition_id" => "shot_1",
        "provenance" => Dict("raw_data_hash" => repeat("5", 64),
            "calibration_hash" => repeat("6", 64),
            "transfer_function_hash" => repeat("7", 64),
            "uncertainty_covariance_hash" => repeat("8", 64)),
        "operating_history" => Dict("boundary_history_hash" => repeat("9", 64),
            "initial_state_hash" => repeat("a", 64),
            "control_history_hash" => repeat("b", 64)),
        "observable_comparisons" => [Dict("observable_id" => "temperature",
            "measured_value" => 100.0, "model_value" => 101.0, "unit" => "eV",
            "combined_standard_uncertainty" => 2.0, "acceptance_sigma" => 2.0,
            "model_output_hash" => repeat("c", 64))],
        "supported_claims" => ["temperature at declared diagnostic location and time"])
    anchor = compile_experimental_anchor_v1(raw_anchor, candidate_id, physics_hash)
    @test anchor.status == :pass
    @test anchor.observable_comparisons[1]["normalized_bias_sigma"] == 0.5
    mismatched = compile_experimental_anchor_v1(raw_anchor, candidate_id, repeat("d", 64))
    @test mismatched.status == :unsupported
end
