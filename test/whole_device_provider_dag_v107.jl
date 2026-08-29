using Test
using FusionConceptAI

@testset "v107 whole-device available-provider DAG" begin
    root = normpath(joinpath(@__DIR__, ".."))
    result = run_whole_device_provider_dag_v107(root)
    @test result["status"] == "available_provider_dag_complete"
    @test result["input_survivor_count"] == 32
    @test result["available_provider_dag_pass_count"] == 32
    @test result["candidate_state_histogram"] == Dict("high_fidelity_pending" => 32)
    @test result["complete_whole_device_preflight_count"] == 0
    @test result["unsupported_candidate_count"] == 0
    @test result["provider_system_failure_count"] == 0
    @test result["whole_device_pass_count"] == 0
    @test result["whole_device_credible_count"] == 0
    @test result["validation_pass_count"] == 0
    @test result["high_cost_expansion_authorized"] === false
    @test result["partial_subgraph_promotion_allowed"] === false
    @test all(row -> row["stage_order"] == V107_STAGE_ORDER, result["rows"])
    @test all(row -> length(row["stages"]) == length(V107_STAGE_ORDER), result["rows"])
    @test all(row -> row["complete_obligation_count"] == 2, result["rows"])
    @test all(row -> row["unsupported_candidate_classification_used"] === false,
        result["rows"])
    @test all(row -> only(stage for stage in row["stages"] if
        stage["stage_id"] == "validation_vvuq")["status"] ==
        "not_executed_preflight_not_ready", result["rows"])

    v106, screens = run_whole_device_assembly_screen_v106(root)
    generation, assemblies = run_whole_device_assembly_generation_v105(root)
    assembly_by_hash = Dict(item["physical_design_hash"] => item for item in assemblies)
    candidates = FusionConceptAI._v104_load_v100_candidates(root)
    candidate_by_hash = Dict(item["result_hash"] => item for item in values(candidates))
    screen = first(screens); assembly = assembly_by_hash[screen["physical_design_hash"]]
    candidate = candidate_by_hash[assembly["source_candidate_result_hash"]]
    artifacts = FusionConceptAI._v107_candidate_artifacts(root, candidate)
    original = execute_whole_device_provider_dag_v107(assembly, screen, candidate, artifacts)
    relabeled = deepcopy(candidate)
    relabeled["request_index"] = -1
    relabeled["candidate_id"] = "erased"
    @test execute_whole_device_provider_dag_v107(assembly, screen, relabeled,
        artifacts)["result_hash"] == original["result_hash"]

    broken = deepcopy(artifacts)
    broken["freegs"]["candidate_result_hash"] = "wrong"
    @test_throws ArgumentError execute_whole_device_provider_dag_v107(
        assembly, screen, candidate, broken)
end
