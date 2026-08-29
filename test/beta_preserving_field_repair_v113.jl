using Test
using FusionConceptAI

@testset "v113 beta-preserving field repair" begin
    root = normpath(joinpath(@__DIR__, ".."))
    result, candidates = run_beta_preserving_field_repair_generation_v113(root)
    @test result["status"] == "complete"
    @test result["repair_proposal_count"] == 4
    @test result["repair_prefilter_survivor_count"] == 3
    @test result["repair_prefilter_reject_count"] == 1
    @test length(candidates) == 3
    @test [item["repair_declaration"]["field_multiplier"] for item in candidates] ==
        V113_FIELD_MULTIPLIERS[2:end]
    @test all(item -> isapprox(item["repair_declaration"][
        "leading_beta_scaling_ratio"], 1.0; atol = 1e-12), candidates)
    @test all(item -> item["physics_solve"]["status"] == "pass", candidates)
    @test all(item -> item["engineering_prefilter"]["status"] == "pass", candidates)
    @test all(item -> item["unsupported_candidate_classification_used"] === false,
        candidates)
    @test result["identity_fields_used_for_generation"] === false
end
