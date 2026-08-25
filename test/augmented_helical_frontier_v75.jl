using Test

@testset "v75 candidate-bound cooling refinement" begin
    artifact = refine_augmented_helical_frontier_v75(72, 63;
        particle_count = 2, step_count = 16,
        target_toroidal_turns = 0.5, field_steps_per_turn = 60)
    @test artifact["conclusion"] in ("frontier_unknown", "unknown", "screen_fail")
    @test artifact["refined_cooling_capacity_w"] > artifact["required_thermal_load_w"]
    @test artifact["refined_cooling_capacity_w"] <= artifact["maximum_cooling_capacity_w"]
    @test artifact["screen"]["engineering_evidence"]["heat_rejection_gate"] == "pass"
    @test artifact["parameter_binding"]["parent_candidate_binding_hash"] ==
        artifact["parent_candidate_binding_hash"]
    @test artifact["device_family_routing_used"] == false
end
