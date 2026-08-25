@testset "mechanism-diverse frontier evidence queue v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    artifact_path = joinpath(root, "runs",
        "mechanism_frontier_evidence_queue_v1_20260816.json")
    raw = JSON3.read(read(artifact_path, String), Dict{String,Any})
    population = raw["input_population"]
    audit = raw["reconstruction_audit"]
    selection = raw["selection"]
    gates = raw["gates"]
    @test population["search_candidate_count"] == 10_000
    @test population["topology_archive_record_count"] == 1_000
    @test population["highest_gate_variant_count"] == 698
    @test population["highest_gate_unique_graph_count"] == 410
    @test population["audited_union_candidate_count"] == 1_288
    @test audit["exact_replay_count"] == 1_288
    @test audit["family_scramble_invariant_count"] == 1_288
    @test audit["unique_physics_signature_count"] == 273
    @test audit["unique_mechanism_cell_count"] == 20
    @test audit["native_executable_physics_count"] == 0
    @test audit["c1_problem_input_ready_count"] == 0
    @test audit["missing_explicit_geometry_candidate_count"] == 1_288
    @test selection["selection_uses_family_label"] === false
    @test selection["raw_frontier_pool_count"] == 698
    @test selection["frontier_pool_count"] == 9
    @test selection["selected_candidate_count"] == 64
    @test selection["selected_unique_physical_signature_count"] == 64
    @test selection["selected_mechanism_cell_count"] == 20
    @test gates["all_candidates_exactly_replayed"]
    @test gates["family_scramble_invariant"]
    @test gates["selection_family_independent"]
    @test gates["all_selected_have_candidate_specific_physics_problem"]
    @test !gates["any_selected_c1_input_ready"]
    @test !gates["medium_fidelity_admission_authorized"]
    @test !gates["promotion_authorized"]

    queue_path = joinpath(root, split(raw["queue_archive"]["candidate_jsonl"], '/')...)
    @test bytes2hex(sha256(read(queue_path))) ==
        raw["queue_archive"]["candidate_sha256"]
    records = [JSON3.read(line, Dict{String,Any}) for line in eachline(queue_path)]
    @test length(records) == 64
    @test length(unique(String(item["physical_signature_hash"]) for item in
        records)) == 64
    @test length(unique(Int(item["candidate_index"]) for item in records)) == 64
    @test all(item["exact_candidate_replay_verified"] for item in records)
    @test all(item["family_scramble_physics_invariant"] for item in records)
    @test all(item["family_label_used_for_selection"] === false for item in records)
    @test all(!item["native_executable_physics_declared"] for item in records)
    @test all(!item["c1_problem_input_ready"] for item in records)
    @test all(!isempty(item["missing_explicit_geometry_ids"]) for item in records)
    @test all(item["physics_problem_hash"] == canonical_hash(
        item["physics_problem"]) for item in records)
    @test all(parse_genome(item["genome"]).physics_hash == item["physics_hash"]
        for item in records)
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        !(key in ("deterministic_hash", "runtime_measurements")))
    @test raw["deterministic_hash"] == canonical_hash(core)
end
