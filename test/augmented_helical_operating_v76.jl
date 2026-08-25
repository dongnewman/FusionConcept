using Test

@testset "v76 operating-point refinement is bounded and fail-closed" begin
    artifact = refine_augmented_helical_operating_point_v76(72, 49;
        particle_count = 2, step_count = 8,
        target_toroidal_turns = 0.5, field_steps_per_turn = 60)
    @test artifact["conclusion"] in ("frontier_unknown", "unknown", "screen_fail")
    if haskey(artifact, "refined_density_m3")
        @test artifact["refined_density_m3"] > 0
    end
    if haskey(artifact, "screen")
        @test artifact["screen"]["plasma_evidence"]["plasma_gain_proxy"] >= 1.0
        @test artifact["screen"]["engineering_evidence"]["heat_rejection_gate"] == "pass"
    end
    @test get(artifact, "device_family_routing_used", false) == false
end
