using Test
using FusionConceptAI

@testset "v98 end-to-end device pipeline" begin
    root = normpath(joinpath(@__DIR__, ".."))
    references = run_v98_reference_acceptance(root)
    @test references["status"] == "pass"
    @test references["reference_recall"] == Dict("passed" => 2, "total" => 2)
    @test references["experimental_validation_pass_count"] == 0
    @test all(row -> row["validation_credit"] === false,
        references["reference_controls"])
    @test all(row -> row["identity_fields_used_for_routing"] === false,
        references["reference_controls"])

    rejected = evaluate_indexed_device_v98(1)
    @test rejected["candidate_state"] == "topology_screen_fail"
    @test rejected["unsupported_candidate_classification_used"] === false

    closed_index = findfirst(index -> isempty(
        FusionConceptAI.reconstruct_indexed_physics_v97(index)["declaration_blockers"]),
        1:4096)
    @test closed_index !== nothing
    evaluated = evaluate_indexed_device_v98(closed_index)
    @test evaluated["candidate_state"] in V98_CANDIDATE_STATES
    @test evaluated["candidate_state"] != "provider_system_fail"
    @test evaluated["stage_order"] == ["topology_screen", "provider_closure",
        "physics_solve", "numerical_vvuq", "validation_vvuq"]
    @test evaluated["basis_direct_metric_credit"] === false
    @test evaluated["provider_closure"]["status"] == "pass"

    campaign = run_v98_screening_campaign(1, 256; retain_count = 10)
    @test campaign["status"] == "complete"
    @test campaign["request_count"] == 256
    @test sum(values(campaign["candidate_state_histogram"])) == 256
    @test campaign["provider_system_failure_count"] == 0
    @test campaign["unsupported_candidate_count"] == 0
end
