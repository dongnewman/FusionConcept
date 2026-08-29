using Test
using FusionConceptAI

@testset "v108 candidate-bound dynamic fault provider" begin
    root = normpath(joinpath(@__DIR__, ".."))
    result = run_dynamic_fault_campaign_v108(root)
    @test result["status"] == "complete"
    @test result["source_assembly_count"] == 32
    @test result["controller_overlay_count"] == 128
    @test result["dynamic_fault_screen_survivor_count"] == 96
    @test result["dynamic_fault_screen_reject_count"] == 32
    @test result["candidate_state_histogram"] == Dict(
        "dynamic_fault_screen_reject" => 32,
        "dynamic_fault_screen_survivor" => 96)
    @test result["blocker_histogram"] == Dict(
        "single_pf_coil_trip" => 32, "vertical_displacement_event" => 32)
    @test result["unsupported_candidate_count"] == 0
    @test result["provider_system_failure_count"] == 0
    @test result["whole_device_pass_count"] == 0
    @test result["whole_device_credible_count"] == 0
    @test result["validation_pass_count"] == 0
    @test result["complete_dynamic_fault_obligation_credit"] === false
    @test result["high_cost_expansion_authorized"] === false
    @test all(row -> row["scenario_count"] == 5, result["rows"])
    @test all(row -> row["unsupported_candidate_classification_used"] === false,
        result["rows"])

    generation, assemblies = run_whole_device_assembly_generation_v105(root)
    assembly = first(assemblies)
    overlays = generate_controller_overlays_v108(assembly)
    @test length(overlays) == 4
    @test length(unique(item["controller_design_hash"] for item in overlays)) == 4
    candidates = FusionConceptAI._v104_load_v100_candidates(root)
    candidate = only(value for value in values(candidates) if
        value["result_hash"] == assembly["source_candidate_result_hash"])
    original = execute_dynamic_fault_provider_v108(assembly, overlays[2], candidate)
    relabeled = deepcopy(candidate); relabeled["request_index"] = -1
    @test execute_dynamic_fault_provider_v108(assembly, overlays[2], relabeled)[
        "result_hash"] == original["result_hash"]
    broken = deepcopy(overlays[2]); broken["physical_design_hash"] = repeat("0", 64)
    @test_throws ArgumentError execute_dynamic_fault_provider_v108(
        assembly, broken, candidate)
end
