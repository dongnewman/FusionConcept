using Test
using FusionConceptAI

@testset "v114 similarity-scaled field repair" begin
    root = normpath(joinpath(@__DIR__, ".."))
    result, candidates = run_similarity_scaled_field_repair_generation_v114(root)
    @test result["status"] == "complete"
    @test result["repair_proposal_count"] == 9
    @test result["repair_prefilter_survivor_count"] > 0
    @test length(candidates) == result["repair_prefilter_survivor_count"]
    @test all(item -> item["physics_solve"]["status"] == "pass", candidates)
    @test all(item -> item["engineering_prefilter"]["status"] == "pass", candidates)
    @test all(item -> item["repair_declaration"]["leading_beta_scaling_ratio"] == 1.0,
        candidates)
    @test all(item -> item["unsupported_candidate_classification_used"] === false,
        candidates)
    @test result["identity_fields_used_for_generation"] === false
end
