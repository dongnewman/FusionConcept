using Test
using FusionConceptAI

@testset "v95 unified reference/candidate filter" begin
    root = normpath(joinpath(@__DIR__, ".."))
    result = run_unified_filter_acceptance_v95(root)
    acceptance = result.acceptance
    rows = result.rows

    @test acceptance["software_controls_status"] == "pass"
    @test acceptance["status"] == "fail"
    @test acceptance["selector_acceptance"] == "blocked_reference_control_false_negative"
    @test acceptance["reference_control_count"] == 2
    @test acceptance["generated_candidate_count"] == 417
    @test acceptance["closure_246_retest_count"] == 246
    @test acceptance["known_positive_recall"]["false_negative_count"] == 2
    @test acceptance["known_positive_recall"]["rate"] == 0.0
    @test acceptance["candidate_status_histogram"] == Dict("unsupported" => 417)
    @test acceptance["conclusions"]["generated_candidates_physically_failed"] == 0
    @test acceptance["conclusions"]["experimental_validation"] == "not_established"
    @test acceptance["controls"]["sealed_v91_v94_inputs"]["existing_candidate_data_write_count"] == 0
    @test acceptance["controls"]["core_anti_specialization"]["status"] == "pass"
    @test acceptance["controls"]["runtime_negative_and_invariance_controls"]["status"] == "pass"
    invariance = acceptance["controls"]["runtime_negative_and_invariance_controls"]
    @test invariance["label_id_role_and_order_invariance"]["reference_identity_erasure"]
    @test invariance["label_id_role_and_order_invariance"]["candidate_identity_erasure"]
    @test invariance["label_id_role_and_order_invariance"]["declaration_order_permutation"]
    @test invariance["basis_erasure_invariance"]["status"] == "pass"

    @test all(row -> row["source_role"] == "reference_control", rows[1:2])
    @test all(row -> row["source_role"] == "generated_candidate", rows[3:end])
    @test all(row -> !row["promotion_eligible"], rows)
    @test all(row -> !row["basis_direct_proxy_credit"], rows)
    @test all(row -> !row["partial_subgraph_credit"], rows)
    @test all(row -> !row["physical_conclusion_expanded"], rows)
    @test all(row -> !row["novelty_credit_allowed"], rows[1:2])
    @test all(row -> "v92_v93_closure_246" in row["cohorts"],
        filter(row -> "v92_v93_closure_246" in row["cohorts"], rows))

    rejected_proxy = solved_metric_record_v95("net_power_w", 1.0,
        Dict("status" => "pass", "whole_graph_closed" => true,
            "solve_hash" => "test"); origin = "basis_direct_proxy")
    @test rejected_proxy["status"] == "unsupported"
    @test rejected_proxy["value"] === nothing
end
