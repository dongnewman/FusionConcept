using Test
using JSON3
using FusionConceptAI

@testset "candidate solver runtime search v57" begin
    root = normpath(joinpath(@__DIR__, ".."))
    seeds = load_genomes(joinpath(root, "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    bundle = compile_candidate_solver_judgment_input_v57(context, 1;
        discretization_levels = [16])
    input = bundle["judgment_input"]
    result = evaluate_uniform_judgment_v55(input)
    summary = bundle["artifact_summary"]

    @test input["solver_runtime"]["routing_basis"] ==
        "declared_module_capabilities_only"
    @test !isempty(input["solver_runtime"]["operator_ids"])
    @test input["state_evolution"]["generated_nominal"] === false
    @test input["transport_burn"]["generated_nominal"] === false
    @test input["net_energy"]["generated_nominal"] === false
    @test input["net_energy"]["strict_aggregation"] === true
    @test summary["candidate_solver_status"] in ("pass", "unknown", "unsupported")
    @test summary["selected_operator_count"] > 0
    @test length(summary["mechanism_cluster_id"]) == length("mechanism_") + 20
    @test summary["artifact_count"] >= 10
    @test result["decision"] == "unknown"
    @test isempty(result["failed_stage_ids"])
    @test result["stages"][1]["status"] == "pass"
    @test result["stages"][2]["status"] == "pass"
    @test result["stages"][5]["status"] in ("pass", "unknown")
    @test result["stages"][6]["status"] == "unknown"
    @test !result["promotion_authorized"]

    relabeled = deepcopy(input)
    relabeled["family"] = "wrong_label"
    relabeled["parent_family"] = "wrong_parent"
    relabeled["display_label"] = "wrong display"
    relabeled_result = evaluate_uniform_judgment_v55(relabeled)
    @test relabeled_result["routing_input_hash"] == result["routing_input_hash"]
    @test relabeled_result["stages"] == result["stages"]

    replay = compile_candidate_solver_judgment_input_v57(context, 1;
        discretization_levels = [16])
    @test replay["input_hash"] == bundle["input_hash"]
    @test replay["solver_result"].result_hash == bundle["solver_result"].result_hash

    anchors = load_candidate_solver_reference_anchors_v1(joinpath(root, "fixtures",
        "candidate_solver_reference_anchors_v1.json"))
    @test length(anchors) == 2
    anchor_results = [evaluate_reference_vertical_slice_v1(anchor;
        discretization_levels = [8]) for anchor in anchors]
    @test Set(result["validation"]["anchor_kind"] for result in anchor_results) == Set([
        "published_design_baseline_not_experimental_measurement",
        "published_experimental_parameter_range"])
    @test all(result -> result["validation"]["comparison_status"] in
        ("within_all_declared_anchor_ranges", "model_discrepancy", "runtime_unsupported"),
        anchor_results)
    @test all(result -> length(result["validation"]["validation_hash"]) == 64,
        anchor_results)
    iter = only(result for result in anchor_results if
        result["validation"]["anchor_id"] == "iter_inductive_baseline_design_v1")
    c2w = only(result for result in anchor_results if
        result["validation"]["anchor_id"] == "c2w_enhanced_performance_experiment_v1")
    @test occursin("design", lowercase(iter["validation"]["anchor_kind"]))
    @test occursin("experimental", lowercase(c2w["validation"]["anchor_kind"]))
    @test all(!isempty(result["validation"]["source_refs"]) for result in anchor_results)
end
