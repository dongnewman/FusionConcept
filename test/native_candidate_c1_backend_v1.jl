@testset "native candidate C1 backend functions v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    input_path = joinpath(root, "runs",
        "mechanism_native_geometry_candidates_v1_20260816.jsonl")
    inputs = [JSON3.read(line, Dict{String,Any})
        for line in eachline(input_path)]
    by_rank(rank) = only(filter(item -> Int(item["queue_rank"]) == rank,
        inputs))

    magnetic_input = by_rank(1)
    magnetic_genome = parse_genome(magnetic_input["derived_genome"])
    magnetic = execute_native_candidate_c1_backend_v1(magnetic_genome)
    @test magnetic["status"] == "fail"
    @test magnetic["hard_falsified"]
    @test !magnetic["candidate_c1_evidence_authorized"]
    @test magnetic["execution_refinement"]["derived"]
    @test magnetic["magnetic"]["field_solution_evidence_authorized"]
    @test magnetic["magnetic"]["field_topology_evidence_authorized"]
    @test !magnetic["magnetic"]["declared_topology_match"]
    @test magnetic["magnetic"]["resolved_topology_class"] ==
        "closed_dominated"
    @test magnetic["magnetic"]["fine_topology"]["closed_fraction"] == 1.0
    @test magnetic["magnetic"]["edge_field_t"] ≈ 4.0 rtol = 1.0e-12
    @test magnetic["magnetic"]["declared_edge_field_relative_error"] == 0.0
    @test magnetic["magnetic"]["ampere_relative_residual"]["fine"] <
        magnetic["magnetic"]["ampere_relative_residual"]["coarse"]
    @test magnetic["magnetic"]["divergence_normalized_residual"]["fine"] <
        magnetic["magnetic"]["divergence_normalized_residual"]["coarse"]

    pulse_input = by_rank(13)
    pulse_genome = parse_genome(pulse_input["derived_genome"])
    pulse = execute_native_candidate_c1_backend_v1(pulse_genome)
    @test pulse["status"] == "pass"
    @test pulse["candidate_c1_evidence_authorized"]
    @test !pulse["hard_falsified"]
    @test pulse["execution_refinement"]["derived"]
    @test pulse["pulse"]["drive_geometry_evidence_authorized"]
    @test pulse["pulse"]["drive_source_map_evidence_authorized"]
    @test pulse["pulse"]["procedural_emitter_count"] == 48
    @test !pulse["pulse"]["hydrodynamics_input_ready"]
    @test !pulse["promotion_authorized"]

    hybrid_input = by_rank(10)
    hybrid_genome = parse_genome(hybrid_input["derived_genome"])
    hybrid = execute_native_candidate_c1_backend_v1(hybrid_genome)
    @test hybrid["status"] == "unknown"
    @test !hybrid["candidate_c1_evidence_authorized"]
    @test hybrid["pulse"]["drive_geometry_evidence_authorized"]
    @test hybrid["pulse"]["drive_source_map_evidence_authorized"]
    @test !hybrid["magnetic"]["backend_executed"]

    for (genome, result) in ((magnetic_genome, magnetic),
            (pulse_genome, pulse), (hybrid_genome, hybrid))
        replay = execute_native_candidate_c1_backend_v1(genome)
        @test replay["physical_result_hash"] == result["physical_result_hash"]
        @test replay["execution_physics_hash"] ==
            result["execution_physics_hash"]
        scrambled_raw = deepcopy(genome.normalized)
        scrambled_raw["family"] = "test_scrambled_family_label"
        scrambled = execute_native_candidate_c1_backend_v1(
            parse_genome(scrambled_raw))
        @test scrambled["physical_result_hash"] ==
            result["physical_result_hash"]
    end
end

@testset "native candidate C1 backend batch artifact v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    artifact_path = joinpath(root, "runs",
        "native_candidate_c1_backend_v1_20260816.json")
    raw = JSON3.read(read(artifact_path, String), Dict{String,Any})
    summary = raw["execution_summary"]
    gates = raw["gates"]
    @test raw["input"]["candidate_count"] == 64
    @test raw["input"]["mechanism_cell_count"] == 20
    @test summary["execution_candidate_count"] == 64
    @test summary["unique_execution_physics_hash_count"] == 64
    @test summary["execution_refined_candidate_count"] == 42
    @test summary["family_scramble_invariant_count"] == 64
    @test summary["status_histogram"]["pass"] == 15
    @test summary["status_histogram"]["fail"] == 15
    @test summary["status_histogram"]["unknown"] == 34
    @test summary["magnetic_backend_execution_count"] == 15
    @test summary["field_solution_evidence_authorized_count"] == 15
    @test summary["field_topology_evidence_authorized_count"] == 15
    @test summary["declared_topology_mismatch_count"] == 15
    @test summary["pulsed_geometry_backend_execution_count"] == 27
    @test summary["drive_geometry_evidence_authorized_count"] == 27
    @test summary["drive_source_map_evidence_authorized_count"] == 27
    @test summary["procedural_emitter_count"] == 726
    @test summary["candidate_c1_evidence_authorized_count"] == 15
    @test summary["hard_falsified_candidate_count"] == 15
    @test summary["c2_evidence_authorized_count"] == 0
    @test summary["promotion_authorized_count"] == 0
    @test gates["all_inputs_unique"]
    @test gates["all_execution_candidates_unique"]
    @test gates["family_scramble_invariant"]
    @test gates["at_least_one_real_backend_executed"]
    @test gates["at_least_one_generated_candidate_reaches_c1"]
    @test !gates["c2_evidence_authorized"]
    @test !gates["performance_search_authorized"]
    @test !gates["promotion_authorized"]

    record_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(record_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(record_path)]
    @test length(records) == 64
    @test length(unique(String(item["execution_physics_hash"])
        for item in records)) == 64
    @test all(item["family_scramble_invariant"] for item in records)
    @test all(!item["promotion_authorized"] for item in records)
    @test count(item -> item["status"] == "pass", records) == 15
    @test count(item -> item["status"] == "fail", records) == 15
    @test count(item -> item["status"] == "unknown", records) == 34
    @test all(item["c1_route"] == "pulsed_drive_geometry"
        for item in records if item["status"] == "pass")
    @test all(item["magnetic"]["resolved_topology_class"] ==
        "closed_dominated" for item in records if item["status"] == "fail")
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        !(key in ("deterministic_hash", "runtime_measurements")))
    @test raw["deterministic_hash"] == canonical_hash(core)
end
