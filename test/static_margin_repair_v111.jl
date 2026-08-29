using Test
using FusionConceptAI
using JSON3

@testset "v111 static engineering margin repair" begin
    root = normpath(joinpath(@__DIR__, ".."))
    result, candidates = run_static_margin_repair_generation_v111(root)
    @test result["status"] == "complete"
    @test result["source_static_failure_count"] == 2
    @test result["repair_proposal_count"] == 6
    @test result["repair_prefilter_survivor_count"] == 6
    @test length(candidates) == 6
    @test all(item -> item["physics_solve"]["status"] == "pass", candidates)
    @test all(item -> item["engineering_prefilter"]["status"] == "pass", candidates)
    @test all(item -> item["repair_declaration"]["predicted_static_peak_field_t"] <=
        V111_TARGET_STATIC_PEAK_FIELD_T + 1e-9, candidates)
    @test all(item -> item["unsupported_candidate_classification_used"] === false,
        candidates)
    @test result["identity_fields_used_for_generation"] === false

    source_path = joinpath(root, "runs", "v110_material_closed_frontier_20260829",
        "candidates.jsonl")
    parents = [FusionConceptAI._v93_plain(JSON3.read(line)) for line in
        readlines(source_path) if !isempty(strip(line))]
    parent = only(item for item in parents if item["request_index"] == 857022000321)
    static = FusionConceptAI._v110_read_json(joinpath(root, "runs",
        "v110_material_closed_frontier_20260829", "static", "results",
        "static_857022000321.json"))
    original = generate_static_margin_repairs_v111(parent, static)
    relabeled = deepcopy(parent); relabeled["request_index"] = 111
    relabeled_static = deepcopy(static); relabeled_static["request_index"] = 111
    relabeled_static["candidate_result_hash"] = relabeled["result_hash"]
    rerun = generate_static_margin_repairs_v111(relabeled, relabeled_static)
    @test [item["repair_declaration"]["predicted_static_peak_field_t"] for item in rerun] ==
        [item["repair_declaration"]["predicted_static_peak_field_t"] for item in original]
end
