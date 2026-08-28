using Test
using JSON3
using FusionConceptAI

@testset "v97 exhaustive candidate-bound physical rescreen" begin
    root = normpath(joinpath(@__DIR__, ".."))
    manifest = compile_exhaustive_campaign_manifest_v97(root)
    @test manifest["total_request_count"] == 1_048_576
    @test manifest["sealed_request_count"] == 1_000_000
    @test manifest["grammar_tail_count"] == 48_576
    @test length(manifest["closure_shards"]) == 21
    @test manifest["historical_result_fields_allowed"] == ["request_index"]
    @test manifest["historical_gate_metric_consumed"] === false

    original = reconstruct_indexed_physics_v97(129)
    relabeled = reconstruct_indexed_physics_v97(129; relabel_nonce = 19)
    @test canonical_hash(original) == canonical_hash(relabeled)
    @test original["reconstruction"]["historical_result_fields_read"] == ["request_index"]
    @test original["reconstruction"]["historical_gate_metric_consumed"] === false
    @test original["parameters"]["historical_gate_metric_consumed"] === false

    closed = compile_indexed_closure_v97(129)
    @test closed.row["screen_status"] == "closed"
    @test closed.row["whole_graph_solver_eligible"] === true
    @test closed.row["graph_hash"] == compile_physical_graph_v96(original)["graph_hash"]
    @test Set(closed.dependency_plan["field_classes_present"]) ==
        Set(["recovered", "derived", "computable", "external_evidence"])
    @test closed.dependency_plan["external_evidence_independent"] === true
    @test closed.dependency_plan["validation_blocks_numerical_execution"] === false
    @test closed.row["basis_direct_metric_credit"] === false

    unsupported = compile_indexed_closure_v97(1)
    @test unsupported.row["screen_status"] == "unsupported"
    @test "unsupported" in unsupported.dependency_plan["field_classes_present"]
    @test unsupported.row["high_cost_executed"] === false
    @test_throws ArgumentError execute_unique_closed_v97(1,
        unsupported.row["graph_hash"], unsupported.row["solver_input_hash"])

    registry = default_physical_provider_registry_v97()
    first_route = first(closed.assembly.routes)
    unregister_physical_provider_v96!(registry, first_route["selected_provider"])
    missing = assemble_physical_graph_v96(closed.graph, registry)
    @test missing.status == "unsupported"
    @test missing.solver_allowed === false

    execution = execute_unique_closed_v97(129, closed.row["graph_hash"],
        closed.row["solver_input_hash"])
    @test execution["screen_status"] == "unknown"
    @test execution["high_cost_executed"] === true
    @test execution["stage_order"] == ["graph_compile", "provider_closure", "solve",
        "numerical_vvuq", "solve_derived_observables", "validation_vvuq"]
    @test execution["numerical_vvuq"] == "pass"
    @test execution["validation_vvuq"] == "unknown_validation_domain"
    @test execution["solve_hash"] !== nothing
    @test execution["promotion_eligible"] === false

    sentinels = run_v97_reference_sentinels(root)
    @test sentinels["status"] == "pass"
    @test sentinels["manufactured"]["maximum_physical_state_error"] <= 1e-8
    @test sentinels["reference_recall"] == Dict("passed" => 2, "total" => 2)
    @test all(item -> item["stage_order"] == ["graph_compile", "provider_closure",
        "solve", "numerical_vvuq", "solve_derived_observables", "validation_vvuq"],
        sentinels["reference_controls"])

    mktempdir() do output_dir
        pilot = deepcopy(manifest)
        pilot["closure_shards"] = [Dict(
            "shard_id" => 1, "first_request_index" => 1,
            "last_request_index" => 32, "expected_count" => 32,
            "source_partition" => "pilot_deterministic_index_range",
            "sealed_result_stream" => nothing,
            "sealed_result_stream_sha256" => nothing)]
        pilot["campaign_hash"] = canonical_hash(pilot)
        summary = run_v97_closure_shard(root, 1; output_dir, manifest = pilot,
            force = true)
        @test summary["status"] == "pass"
        @test summary["sentinels"]["status"] == "pass"
        @test summary["funnel"]["row_count"] == 32
        rows = [JSON3.read(line, Dict{String,Any}) for line in
            eachline(joinpath(output_dir, "closure_shard_001.jsonl"))]
        @test [row["request_index"] for row in rows] == collect(1:32)
        @test all(row -> row["historical_result_fields_read"] == ["request_index"], rows)
        @test all(row -> row["high_cost_executed"] === false, rows)
    end
end
