@testset "dual-route multi-topology C0/C1 search artifact v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    artifact_path = joinpath(root, "runs",
        "dual_route_multitopology_c1_search_v1_20260816.json")
    raw = JSON3.read(read(artifact_path, String), Dict{String,Any})
    search = raw["search"]
    gates = raw["gates"]
    @test search["route_count"] == 2
    @test search["generated_candidate_count"] == 10000
    @test search["generated_route_histogram"]["pulsed_drive_geometry"] == 5000
    @test search["generated_route_histogram"]["axisymmetric_mirror_field"] == 5000
    @test search["unique_c0_candidate_hash_count"] == 10000
    @test search["c0_geometry_admissible_count"] == 9966
    @test search["c1_selected_count"] == 64
    @test search["c1_selected_route_histogram"]["pulsed_drive_geometry"] == 32
    @test search["c1_selected_route_histogram"]["axisymmetric_mirror_field"] == 32
    @test search["unique_c1_physics_hash_count"] == 64
    @test search["unique_c1_physical_result_hash_count"] == 64
    @test search["family_scramble_invariant_count"] == 64
    @test search["candidate_c1_evidence_authorized_count"] == 63
    @test search["c1_status_histogram"]["pass"] == 63
    @test search["c1_status_histogram"]["unknown"] == 1
    @test search["c2_evidence_authorized_count"] == 0
    @test search["promotion_authorized_count"] == 0
    @test gates["large_scale_c0_generation_validated"]
    @test gates["multiple_physical_routes_executed"]
    @test gates["all_c0_candidates_unique"]
    @test gates["all_selected_c1_candidates_unique"]
    @test gates["family_scramble_invariant"]
    @test !gates["all_selected_candidates_reach_route_c1"]
    @test !gates["c2_evidence_authorized"]
    @test !gates["performance_search_authorized"]
    @test !gates["promotion_authorized"]

    c0_path = joinpath(root, split(raw["archives"]["c0"]["jsonl"], '/')...)
    c1_path = joinpath(root, split(raw["archives"]["c1"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(c0_path))) == raw["archives"]["c0"]["sha256"]
    @test bytes2hex(sha256(read(c1_path))) == raw["archives"]["c1"]["sha256"]
    c0 = [JSON3.read(line, Dict{String,Any}) for line in eachline(c0_path)]
    c1 = [JSON3.read(line, Dict{String,Any}) for line in eachline(c1_path)]
    @test length(c0) == 10000
    @test length(c1) == 64
    @test count(item -> item["c1_selected"] === true, c0) == 64
    @test length(unique(String(item["c0_candidate_hash"]) for item in c0)) == 10000
    @test length(unique(String(item["physics_hash"]) for item in c1)) == 64
    @test length(unique(String(item["physical_result_hash"]) for item in c1)) == 64
    @test count(item -> item["candidate_c1_evidence_authorized"], c1) == 63
    @test count(item -> item["status"] == "unknown", c1) == 1
    @test all(item["family_scramble_invariant"] for item in c1)
    @test all(!item["c2_evidence_authorized"] for item in c1)
    @test Set(String(item["route"]) for item in c1) == Set([
        "pulsed_drive_geometry", "axisymmetric_mirror_field"])
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        !(key in ("deterministic_hash", "runtime_measurements")))
    @test raw["deterministic_hash"] == canonical_hash(core)
end
