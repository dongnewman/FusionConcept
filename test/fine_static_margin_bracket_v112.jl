using Test
using FusionConceptAI

@testset "v112 fine static margin bracket" begin
    root = normpath(joinpath(@__DIR__, ".."))
    result, candidates = run_fine_static_margin_bracket_generation_v112(root)
    @test result["status"] == "complete"
    @test result["bracket_proposal_count"] == 7
    @test result["bracket_prefilter_survivor_count"] == 7
    @test length(candidates) == 7
    @test [item["bracket_declaration"]["pack_multiplier_from_v111_lower_bracket"]
        for item in candidates] == V112_PACK_MULTIPLIERS
    @test all(item -> item["physics_solve"]["status"] == "pass", candidates)
    @test all(item -> item["engineering_prefilter"]["status"] == "pass", candidates)
    @test all(item -> item["unsupported_candidate_classification_used"] === false,
        candidates)
    @test result["identity_fields_used_for_generation"] === false
end
