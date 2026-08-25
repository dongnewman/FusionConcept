using Test
using JSON3
using FusionConceptAI

@testset "candidate-bound full-chain search v56" begin
    root = normpath(joinpath(@__DIR__, ".."))
    seeds = load_genomes(joinpath(root, "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)

    bundle = compile_candidate_bound_judgment_input_v56(context, 1)
    input = bundle["judgment_input"]
    result = evaluate_uniform_judgment_v55(input)
    @test input["candidate_index"] == 1
    @test input["generation_audit"]["v54_generated_ledgers_rejected_for_v55"]
    @test isempty(input["net_energy"]["terms"])
    @test !input["state_evolution"]["solver_derived"]
    @test !input["transport_burn"]["solver_derived"]
    @test bundle["artifact_summary"]["artifact_count"] == 7
    @test all(status -> status in ("pass", "fail", "unknown", "unsupported", "compiled"),
        values(bundle["artifact_summary"]["artifact_statuses"]))
    @test result["decision"] == "unknown"
    @test result["passed_stage_count"] == 2
    @test isempty(result["failed_stage_ids"])
    @test result["unknown_stage_ids"] == collect(UNIFIED_JUDGMENT_STAGE_IDS_V55[3:8])
    @test result["all_eight_stages_executed"]
    @test !result["promotion_authorized"]
    @test !occursin("NaN", canonical_json(result))

    relabeled = deepcopy(input)
    relabeled["family"] = "deliberately_wrong_family"
    relabeled["parent_family"] = "deliberately_wrong_parent"
    relabeled["display_label"] = "wrong display label"
    relabeled_result = evaluate_uniform_judgment_v55(relabeled)
    @test relabeled_result["routing_input_hash"] == result["routing_input_hash"]
    stage_signature(value) = [
        (stage["stage_id"], stage["status"],
            [(check["check_id"], check["status"], check["reason"])
                for check in stage["checks"]])
        for stage in value["stages"]]
    @test stage_signature(relabeled_result) == stage_signature(result)

    batch = evaluate_candidate_bound_search_batch_v56(context, 1:11)
    archive = batch["judgment_archive"]
    @test length(batch["bundles"]) == 11
    @test archive["input_candidate_count"] == 11
    @test archive["evaluated_candidate_count"] == 11
    @test archive["dropped_candidate_count"] == 0
    @test archive["summary"]["family_or_parent_routed_count"] == 0
    @test archive["summary"]["promotion_authorized_count"] == 0
    @test archive["summary"]["pass_count"] == 0
    @test all(item -> item["all_eight_stages_executed"] === true,
        archive["results"])
    @test all(item -> item["promotion_authorized"] === false,
        archive["results"])

    schema = JSON3.read(read(joinpath(root, "schemas",
        "candidate_bound_eight_stage_search_v56.schema.json"), String))
    @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
end
