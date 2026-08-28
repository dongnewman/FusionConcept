using Test
using FusionConceptAI

function v99_fixture(; state = "sampled_ideal_mhd_candidate")
    Dict{String,Any}(
        "candidate_state" => state,
        "candidate_result_hash" => "candidate-hash",
        "result_hash" => "cross-code-hash",
        "freegs_full_result_hash" => "freegs-hash",
        "desc_result" => Dict("result_hash" => "desc-hash"),
    )
end

@testset "v99 ITER and C-2W route controls" begin
    controls = run_v99_reference_controls(normpath(joinpath(@__DIR__, "..")))
    @test controls["status"] == "pass"
    @test controls["reference_control_count"] == 2
    @test controls["validation_pass_count"] == 0
    @test controls["whole_device_credible_count"] == 0
    iter = only(filter(row -> row["control_id"] ==
        "iter_inductive_baseline_design_v1", controls["reference_controls"]))
    c2w = only(filter(row -> row["control_id"] ==
        "c2w_enhanced_performance_experiment_v1", controls["reference_controls"]))
    @test iter["freegs_desc_axisymmetric_bridge_applicable"] === true
    @test c2w["freegs_desc_axisymmetric_bridge_applicable"] === false
    @test c2w["required_provider_class"] == "open_field_extended_mhd_or_kinetic"
    @test all(row -> row["validation_credit"] === false,
        controls["reference_controls"])
end

const V99_CAPABILITY_FIXTURE = Dict{String,Any}(
    "route" => "closed_core_open_exhaust",
    "declared_field_semantics" => ["axisymmetric_closed", "open_guiding_field"],
    "declared_boundaries" => ["closed", "open"],
    "declared_operators" => ["field_balance", "particle_transport"],
    "declared_dimensions" => [1, 2],
)

@testset "v99 complete device qualification is fail closed" begin
    dag = compile_full_device_qualification_dag_v99(V99_CAPABILITY_FIXTURE)
    @test dag["declared_exhaust_region"] === true
    @test dag["identity_fields_used_for_routing"] === false
    @test length(dag["nodes"]) == length(V99_FULL_DEVICE_STAGES)

    partial = evaluate_full_device_qualification_v99(
        V99_CAPABILITY_FIXTURE, v99_fixture())
    @test partial["candidate_state"] == "qualification_incomplete"
    @test partial["whole_device_credible"] === false
    @test "complete_stability" in partial["incomplete_or_noncredit_stages"]
    @test partial["unsupported_candidate_classification_used"] === false

    unstable = evaluate_full_device_qualification_v99(
        V99_CAPABILITY_FIXTURE, v99_fixture(state = "stability_screen_fail"))
    @test unstable["candidate_state"] == "physical_reject"
    @test "sampled_local_ideal_mhd" in unstable["physical_failure_stages"]

    transformed = evaluate_full_device_qualification_v99(
        V99_CAPABILITY_FIXTURE, v99_fixture(state = "transformer_fit_fail"))
    @test transformed["candidate_state"] == "transformer_reject"

    controls = Dict(stage => Dict("status" => "pass", "scope" =>
        "manufactured_control", "result_hash" => "control-$stage")
        for stage in V99_FULL_DEVICE_STAGES[4:end])
    no_credit = evaluate_full_device_qualification_v99(
        V99_CAPABILITY_FIXTURE, v99_fixture(); downstream_evidence = controls)
    @test no_credit["candidate_state"] == "qualification_incomplete"
    @test no_credit["validation_pass"] === false

    candidate_bound = Dict(stage => Dict("status" => "pass", "scope" =>
        "candidate_bound", "result_hash" => "candidate-$stage")
        for stage in V99_FULL_DEVICE_STAGES[4:end])
    closed = evaluate_full_device_qualification_v99(
        V99_CAPABILITY_FIXTURE, v99_fixture(); downstream_evidence = candidate_bound)
    @test closed["candidate_state"] == "whole_device_validation_pass"
    @test closed["whole_device_credible"] === true

    permuted = deepcopy(V99_CAPABILITY_FIXTURE)
    permuted["declared_field_semantics"] = reverse(permuted["declared_field_semantics"])
    permuted["declared_boundaries"] = reverse(permuted["declared_boundaries"])
    permuted["declared_operators"] = reverse(permuted["declared_operators"])
    permuted["candidate_id"] = "erased-and-permuted"
    @test compile_full_device_qualification_dag_v99(permuted)["dag_hash"] ==
        dag["dag_hash"]
end
