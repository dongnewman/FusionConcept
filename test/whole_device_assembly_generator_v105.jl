using Test
using FusionConceptAI

@testset "v105 whole-device assembly generator" begin
    root = normpath(joinpath(@__DIR__, ".."))
    result, assemblies = run_whole_device_assembly_generation_v105(root)
    @test result["status"] == "assembly_inputs_closed"
    @test result["source_survivor_count"] == 1
    @test result["assembly_proposal_count"] == 64
    @test result["assembly_input_closed_count"] == 64
    @test result["whole_device_provider_preflight_ready"] === false
    @test result["whole_device_search_authorized"] === false
    @test result["unsupported_candidate_count"] == 0
    @test result["physical_reject_count"] == 0
    @test result["physical_pass_count"] == 0
    @test result["whole_device_credible_count"] == 0
    @test result["validation_pass_count"] == 0
    @test all(row -> row["candidate_state"] == "assembly_input_closed",
        result["assembly_rows"])
    @test all(row -> row["provider_execution_status"] ==
        "not_executed_preflight_not_ready", result["assembly_rows"])
    @test all(item -> item["unsupported_candidate_classification_used"] === false,
        assemblies)
    @test all(item -> item["physical_design"]["basis_direct_metric_credit"] === false,
        assemblies)

    candidates = FusionConceptAI._v104_load_v100_candidates(root)
    source = only(value for value in values(candidates) if
        value["result_hash"] == first(assemblies)["source_candidate_result_hash"])
    mutated = deepcopy(source)
    mutated["request_index"] = -1
    mutated["result_hash"] = repeat("f", 64)
    mutated["solver_input_hash"] = repeat("e", 64)
    replay = generate_whole_device_assemblies_v105(mutated)
    @test getindex.(assemblies, "physical_design_hash") ==
        getindex.(replay, "physical_design_hash")
    @test getindex.(assemblies, "assembly_result_hash") !=
        getindex.(replay, "assembly_result_hash")

    invalid = deepcopy(first(assemblies))
    invalid["physical_design"]["material_stack"]["layers"][1]["thickness_m"] = -1.0
    @test audit_whole_device_assembly_inputs_v105(invalid)["status"] == "invalid"
    @test_throws ArgumentError generate_whole_device_assemblies_v105(source; variants = 32)
end
