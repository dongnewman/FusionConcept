@testset "axisymmetric mirror filament search functions v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    input_path = joinpath(root, "runs",
        "native_candidate_c1_backend_candidates_v1_20260816.jsonl")
    inputs = [JSON3.read(line, Dict{String,Any})
        for line in eachline(input_path)]
    mirror = only(filter(item -> Int(item["queue_rank"]) == 2, inputs))
    source = parse_genome(mirror["execution_genome"])
    derived, refinement = refine_axisymmetric_mirror_filament_candidate_v1(
        source)
    @test refinement["derived"]
    @test refinement["current_per_loop_a"] > 1.0e7
    @test refinement["cell_length_relative_change"] < 0.20
    @test refinement["search"]["log_ratio_error"] < 1.0e-12
    @test derived.physics_hash != source.physics_hash
    explicit = only(filter(item -> item.geometry_model ==
        "axisymmetric_circular_filament_pair_v1", derived.field_sources))
    @test explicit.parameters["current_per_loop"].unit == "A"
    disabled = only(filter(item -> item.geometry_model ==
        "disabled_zero_current_anchor_v1", derived.field_sources))
    @test disabled.parameters["total_current"].value == 0.0

    result = execute_axisymmetric_mirror_filament_c1_v1(derived)
    @test result["backend_executed"]
    @test result["status"] == "pass"
    @test result["candidate_c1_evidence_authorized"]
    @test result["maxwell_evidence_authorized"]
    @test result["field_topology_evidence_authorized"]
    @test result["resolved_topology_class"] == "open_dominated"
    @test result["declared_topology_match"]
    @test result["central_field_t"] ≈ 4.0 rtol = 2.0e-5
    @test result["mirror_ratio"] ≈ 5.0 rtol = 5.0e-5
    @test result["segment_field_max_relative_change"] < 5.0e-4
    @test result["vacuum_divergence_normalized_residual"]["fine"] <
        result["vacuum_divergence_normalized_residual"]["coarse"]
    @test result["vacuum_curl_normalized_residual"]["fine"] <
        result["vacuum_curl_normalized_residual"]["coarse"]
    @test !result["minimum_b_anchor_enabled"]
    @test !result["stability_evidence_authorized"]
    @test !result["c2_evidence_authorized"]
    @test !result["promotion_authorized"]

    replay = execute_axisymmetric_mirror_filament_c1_v1(derived)
    @test replay["physical_result_hash"] == result["physical_result_hash"]
    scrambled_raw = deepcopy(derived.normalized)
    scrambled_raw["family"] = "diagnostic_scrambled_family_label"
    scrambled = execute_axisymmetric_mirror_filament_c1_v1(
        parse_genome(scrambled_raw))
    @test scrambled["physical_result_hash"] == result["physical_result_hash"]
end

@testset "axisymmetric mirror filament search batch artifact v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    artifact_path = joinpath(root, "runs",
        "axisymmetric_mirror_filament_search_v1_20260816.json")
    raw = JSON3.read(read(artifact_path, String), Dict{String,Any})
    summary = raw["search_summary"]
    gates = raw["gates"]
    @test raw["input"]["frontier_candidate_count"] == 64
    @test raw["input"]["unknown_mirror_candidate_count"] == 2
    @test summary["derived_candidate_count"] == 2
    @test summary["unique_derived_physics_hash_count"] == 2
    @test summary["family_scramble_invariant_count"] == 2
    @test summary["maxwell_evidence_authorized_count"] == 2
    @test summary["field_topology_evidence_authorized_count"] == 2
    @test summary["open_dominated_count"] == 2
    @test summary["candidate_c1_evidence_authorized_count"] == 2
    @test summary["minimum_current_per_loop_a"] > 1.9e7
    @test summary["maximum_current_per_loop_a"] < 2.5e7
    @test summary["maximum_cell_length_relative_change"] < 0.20
    @test summary["stability_evidence_authorized_count"] == 0
    @test summary["c2_evidence_authorized_count"] == 0
    @test gates["all_unknown_mirror_inputs_refined"]
    @test gates["all_derived_candidates_unique"]
    @test gates["family_scramble_invariant"]
    @test gates["axisymmetric_mirror_field_and_topology_c1"]
    @test !gates["minimum_b_stability_evidence_authorized"]
    @test !gates["coil_engineering_evidence_authorized"]
    @test !gates["performance_search_authorized"]
    @test !gates["promotion_authorized"]

    record_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(record_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(record_path)]
    @test length(records) == 2
    @test all(item["candidate_c1_evidence_authorized"] for item in records)
    @test all(item["family_scramble_invariant"] for item in records)
    @test all(!item["c2_evidence_authorized"] for item in records)
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        !(key in ("deterministic_hash", "runtime_measurements")))
    @test raw["deterministic_hash"] == canonical_hash(core)
end
