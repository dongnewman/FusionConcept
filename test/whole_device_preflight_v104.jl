using Test
using FusionConceptAI

@testset "v104 whole-device campaign preflight" begin
    root = normpath(joinpath(@__DIR__, ".."))
    result = run_whole_device_preflight_v104(root)
    @test result["status"] == "not_ready"
    @test result["reference_regression_pass_count"] == 2
    @test result["reference_bypass_count"] == 0
    @test result["survivor_preflight_count"] == 1
    @test result["whole_device_search_authorized"] === false
    @test result["unsupported_candidate_count"] == 0
    @test result["physical_reject_count_added_by_preflight"] == 0
    @test result["physical_pass_count_added_by_preflight"] == 0
    @test result["whole_device_credible_count"] == 0
    @test result["validation_pass_count"] == 0
    row = only(result["survivor_rows"])
    @test row["candidate_state"] == "not_adjudicated_provider_gap"
    @test row["unsupported_candidate_classification_used"] === false
    preflight = row["preflight"]
    @test preflight["closed_obligation_count"] == 2
    @test preflight["required_obligation_count"] == 9
    @test preflight["provider_gap_count"] == 1
    @test preflight["fidelity_gap_count"] == 6
    @test preflight["candidate_identity_used_for_routing"] === false

    candidates = FusionConceptAI._v104_load_v100_candidates(root)
    candidate = only(value for value in values(candidates) if
        value["result_hash"] == row["source_candidate_result_hash"])
    original = compile_whole_device_preflight_v104(candidate["capability_profile"])
    erased = deepcopy(candidate["capability_profile"])
    erased["candidate_id"] = "erased"
    erased["candidate_hash"] = "erased"
    permuted = Dict{String,Any}(reverse(collect(erased)))
    replay = compile_whole_device_preflight_v104(permuted)
    @test original["preflight_hash"] == replay["preflight_hash"]

    complete = deepcopy(default_whole_device_provider_inventory_v104())
    for obligation in V104_WHOLE_DEVICE_OBLIGATIONS
        push!(complete, Dict("provider_key" => "complete_" * obligation["obligation_id"],
            "obligation_id" => obligation["obligation_id"],
            "evidence_level" => obligation["required_evidence_level"],
            "status" => "available", "input_contract" => ["declared_test_input"]))
    end
    ready = compile_whole_device_preflight_v104(candidate["capability_profile"];
        providers = complete)
    @test ready["status"] == "ready"
    @test ready["whole_device_search_authorized"] === true

    missing = filter(item -> item["obligation_id"] != "validation_vvuq", complete)
    negative = compile_whole_device_preflight_v104(candidate["capability_profile"];
        providers = missing)
    @test negative["status"] == "not_ready"
    @test negative["whole_device_search_authorized"] === false
end
