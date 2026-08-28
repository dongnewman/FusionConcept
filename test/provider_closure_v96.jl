using Test
using FusionConceptAI

@testset "v96 physical provider closure" begin
    root = normpath(joinpath(@__DIR__, ".."))
    registry = default_physical_provider_registry_v96()
    manifest = physical_provider_registry_manifest_v96(registry)
    @test manifest["provider_count"] == length(V96_REGION_OPERATORS) +
        length(V96_INTERFACE_OPERATORS) + length(V96_BOUNDARY_OPERATORS)
    @test manifest["routing_unit"] == "single_declared_obligation"

    result = run_provider_closure_acceptance_v96(root)
    acceptance = result.acceptance
    @test acceptance["status"] == "pass"
    @test acceptance["selector_acceptance"] == "pass"
    @test acceptance["software_controls_status"] == "pass"
    @test acceptance["known_positive_recall"]["passed"] == 2
    @test acceptance["known_positive_recall"]["total"] == 2
    @test acceptance["known_positive_recall"]["rate"] == 1.0
    @test acceptance["known_positive_recall"]["false_negative_count"] == 0
    @test acceptance["generated_candidate_count"] == 417
    @test acceptance["closure_246_retest_count"] == 246
    @test acceptance["candidate_status_histogram"] ==
        Dict("unknown" => 246, "unsupported" => 171)
    @test acceptance["provider_coverage"]["status"] == "pass"
    @test acceptance["provider_coverage"]["unsupported"] == 0
    @test acceptance["provider_coverage"]["ambiguous"] == 0
    @test acceptance["controls"]["sealed_v91_v95_inputs"][
        "existing_candidate_or_acceptance_write_count"] == 0
    @test acceptance["controls"]["core_anti_specialization"]["status"] == "pass"
    @test acceptance["controls"]["runtime_controls"]["status"] == "pass"
    @test acceptance["conclusions"]["physical_device_passed_complete_vvuq"] == false
    @test acceptance["conclusions"]["experimental_validation"] == "not_established"
    @test !acceptance["physical_conclusion_expanded"]

    @test all(row -> row["source_role"] == "reference_control", result.rows[1:2])
    @test all(row -> row["source_role"] == "generated_candidate", result.rows[3:end])
    @test all(row -> !row["promotion_eligible"], result.rows)
    @test all(row -> !row["basis_direct_proxy_credit"], result.rows)
    @test all(row -> !row["partial_subgraph_credit"], result.rows)
    @test all(row -> row["solve_hash"] !== nothing,
        filter(row -> row["whole_graph_closed"], result.rows))
    for row in filter(item -> item["whole_graph_closed"], result.rows)
        for metric in values(row["metrics"])
            metric["status"] == "available" || continue
            @test metric["solve_hash"] == row["solve_hash"]
            @test metric["origin"] == "whole_graph_solve_derived"
        end
    end

    replay = replay_million_no_proxy_v96(root; total = 1000, execute_frontier = false)
    @test replay.summary["status"] == "pass"
    @test replay.summary["processed"] == 1000
    @test replay.summary["basis_or_historical_physical_metrics_used_for_selection"] == false
    @test replay.summary["exhaustive_high_cost_solve_of_all_million"] == false
end
