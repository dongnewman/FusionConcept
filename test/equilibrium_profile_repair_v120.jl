using Test
using FusionConceptAI

@testset "v120 equilibrium profile repair" begin
    parent = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => "synthetic-parent",
        "request_index" => 7, "result_hash" => repeat("a", 64),
        "solver_input_hash" => repeat("b", 64), "candidate_state" =>
            "computational_candidate", "physics_solve" => Dict("status" => "pass"),
        "engineering_prefilter" => Dict("status" => "pass"),
        "identity_fields_used_for_routing" => false)
    candidates = generate_equilibrium_profile_repairs_v120([parent])
    @test length(candidates) == length(V120_PROFILE_VARIANTS)
    @test Set((item["equilibrium_profile_parameters"]["alpha_m"],
        item["equilibrium_profile_parameters"]["alpha_n"]) for item in candidates) ==
        Set(V120_PROFILE_VARIANTS)
    @test length(unique(item["solver_input_hash"] for item in candidates)) ==
        length(candidates)
    @test all(item -> item["physical_pass_credit"] === false &&
        item["validation_credit"] === false &&
        item["identity_fields_used_for_routing"] === false, candidates)
    tampered = deepcopy(first(candidates))
    tampered["equilibrium_profile_parameters"]["alpha_m"] = 9
    @test canonical_hash(Dict("parent_solver_input_hash" => parent["solver_input_hash"],
        "equilibrium_profile_parameters" =>
            tampered["equilibrium_profile_parameters"])) != first(candidates)["solver_input_hash"]
end
