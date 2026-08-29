using Test
using FusionConceptAI

@testset "v106 whole-device assembly reduced screen" begin
    root = normpath(joinpath(@__DIR__, ".."))
    result, survivors = run_whole_device_assembly_screen_v106(root)
    @test result["status"] == "complete"
    @test result["assembly_count"] == 64
    @test result["screen_survivor_count"] == 32
    @test result["assembly_reject_count"] == 32
    @test result["candidate_state_histogram"] == Dict(
        "whole_device_assembly_reject" => 32,
        "whole_device_screen_survivor" => 32)
    @test result["blocker_histogram"] == Dict(
        "blanket_thickness" => 16, "shield_thickness" => 16)
    @test result["unsupported_candidate_count"] == 0
    @test result["provider_system_failure_count"] == 0
    @test result["whole_device_pass_count"] == 0
    @test result["whole_device_credible_count"] == 0
    @test result["validation_pass_count"] == 0
    @test result["whole_device_high_fidelity_search_authorized"] === false
    @test all(row -> row["whole_device_pass_credit"] === false, result["rows"])
    @test all(row -> row["validation_credit"] === false, result["rows"])
    @test all(row -> row["unsupported_candidate_classification_used"] === false,
        result["rows"])
    @test all(row -> row["status"] == "pass", survivors)

    generation, assemblies = run_whole_device_assembly_generation_v105(root)
    candidates = FusionConceptAI._v104_load_v100_candidates(root)
    source = only(value for value in values(candidates) if
        value["result_hash"] == first(assemblies)["source_candidate_result_hash"])
    original = screen_whole_device_assembly_v106(first(assemblies), source)
    relabeled = deepcopy(source)
    relabeled["request_index"] = -10
    relabeled["result_hash"] = repeat("d", 64)
    replay = screen_whole_device_assembly_v106(first(assemblies), relabeled)
    @test original["result_hash"] == replay["result_hash"]

    invalid = deepcopy(first(assemblies))
    invalid["physical_design"]["material_stack"]["layers"][2]["thickness_m"] = -1.0
    @test_throws ArgumentError screen_whole_device_assembly_v106(invalid, source)
end
