using Test
using JSON3
using FusionConceptAI

function unified_v52_fixture(; family = "mirror", physics_hash = "abc", candidate_index = 1,
        low_physics = true, positive_net = true, lineage = Any[])
    return Dict{String,Any}(
        "candidate_index" => candidate_index,
        "assembly_index" => 1,
        "sample_ordinal" => candidate_index,
        "design_id" => "candidate_$candidate_index",
        "physics_hash" => physics_hash,
        "proxy_result_hash" => "proxy_$physics_hash",
        "graph_hash" => "graph_a",
        "family" => family,
        "mission_contract_id" => "net_electric_steady-state_v1",
        "module_ids" => Any["mirror_single_cell", "mirror_tandem_plugs", "mirror_kinetic_stabilizer", "two_targets", "finite_coils"],
        "evaluator_id" => "common_evaluator_v1",
        "projection_id" => "mirror_projection_v1",
        "lineage_parent_revision_ids" => lineage,
        "physics_reference_ids" => Any["published_reference_a"],
        "proxy_applicable" => true,
        "topology_graph_errors" => Any[],
        "gates" => Dict(
            "variable_topology_representation_and_compatibility" => true,
            "same_outer_envelope_contract" => true,
            "unified_low_fidelity_physics" => low_physics,
            "minimal_engineering_closure" => true,
            "cheap_robustness_screen" => true,
        ),
        "positive_net_power_closure" => positive_net,
        "proxy_coverage_complete" => false,
        "gate_pass_count" => low_physics ? 5 : 4,
        "robustness_pass_fraction" => 1.0,
        "missing_proxy_requirements" => Any["physical_end_loss_rate"],
    )
end

@testset "unified broad-screen and representative-validation architecture v52" begin
    candidate = unified_v52_fixture(lineage = Any["real_parent_r3"])
    relationships = unified_search_relationships_v52(candidate)
    @test relationships["lineage_parent_revision_ids"] == ["real_parent_r3"]
    @test relationships["physics_reference_ids"] == ["published_reference_a"]
    @test !relationships["parent_synthesized_for_validation"]
    @test "anisotropic_kinetic_stability_v1" in relationships["validation_profile_ids"]
    @test "open_field_end_loss_v1" in relationships["validation_profile_ids"]

    screened = unified_screen_candidate_v52(candidate)
    @test screened["decision"] == "common_screen_pass"
    @test !screened["routing_basis"]["family_field_used_for_routing"]
    @test all(item -> !item["candidate_specific_override_allowed"], screened["screens"])
    @test !haskey(screened, "candidate_specific_validation_plan")

    relabeled = unified_screen_candidate_v52(unified_v52_fixture(family = "tokamak"))
    @test relabeled["mechanism_cluster_id"] == screened["mechanism_cluster_id"]
    @test relabeled["routing_basis"] == screened["routing_basis"]
    @test relabeled["non_routing_classifications"] != screened["non_routing_classifications"]

    failed = unified_screen_candidate_v52(unified_v52_fixture(
        candidate_index = 2, physics_hash = "def", low_physics = false))
    @test failed["decision"] == "hard_reject_candidate_instance"
    @test "low_fidelity_physics" in failed["failed_common_screen_ids"]
    archive = build_unified_search_archive_v52([candidate, unified_v52_fixture(
        candidate_index = 2, physics_hash = "def", low_physics = false)])
    @test archive["summary"]["input_candidate_count"] == 2
    @test archive["summary"]["mechanism_cluster_count"] == 1
    @test archive["summary"]["candidate_specific_plan_count"] == 1
    @test archive["summary"]["parent_synthesis_count"] == 0
    @test archive["summary"]["family_routed_count"] == 0
    @test length(archive["representative_records"]) == 1
    representative = only(archive["representative_records"])
    @test representative["candidate_id"] == "candidate_1"
    @test representative["candidate_specific_validation_plan"]["lineage_parent_created"] == false
    @test "solve_anisotropic_finite_beta_equilibrium" in
        representative["candidate_specific_validation_plan"]["ordered_tasks"]

    schema = JSON3.read(read(joinpath(@__DIR__, "..", "schemas",
        "unified_search_candidate_v52.schema.json"), String))
    @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
end
