@testset "topology DESC stability acquisition round2 v3" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "topology_desc_stability_acquisition_round2_v3_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    search = raw["search"]
    @test Int.(search["selected_pool_indices"]) == [15, 17, 24, 50]
    @test search["selected_count"] == 4
    @test search["completed_count"] == 4
    @test search["sampled_favorable_count"] == 4
    @test search["family_scramble_invariant_count"] == 4
    @test search["unique_stability_problem_hash_count"] == 4
    @test search["sampled_stability_narrow_c2_count"] == 0
    @test search["complete_c2_evidence_authorized_count"] == 0
    @test raw["gates"]["all_selected_executed"]
    @test raw["gates"]["all_family_scramble_invariant"]
    @test !raw["gates"]["medium_to_fine_audit_complete"]
    archive_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(archive_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(archive_path)]
    @test length(records) == 4
    @test sort(collect(Int(item["pool_index"]) for item in records)) ==
        [15, 17, 24, 50]
    @test all(item -> item["sampled_local_ideal_mhd_favorable"] === true,
        records)
    @test all(item -> item["result"]["minimum_mercier_D_normalized"] > 0.0,
        records)
    @test all(item -> item["result"][
        "maximum_infinite_n_ballooning_lambda"] < 0.0, records)
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end

@testset "topology DESC stability round2 audited v4" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "topology_desc_stability_round2_audited_v4_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    summary = raw["summary"]
    audit = raw["pool50_audit"]
    @test summary["round2_candidate_count"] == 4
    @test summary["medium_sampled_favorable_count"] == 4
    @test summary["medium_to_fine_audited_count"] == 1
    @test summary["sampled_stability_narrow_c2_count"] == 1
    @test summary["complete_c2_evidence_authorized_count"] == 0
    @test audit["audit_hash"] ==
        "260a968f826aa9ec79571bfa8be85e34b313e87c7d48e66d50414c8ddfa10e7e"
    @test audit["medium_mercier_minimum_normalized"] > 0.0
    @test audit["fine_mercier_minimum_normalized"] > 0.0
    @test audit["medium_ballooning_maximum"] < 0.0
    @test audit["fine_ballooning_maximum"] < 0.0
    @test audit["fine_force_residual"] < 0.01
    @test raw["gates"]["pool50_medium_to_fine_audit_passed"]
    @test !raw["gates"]["all_mode_stability_established"]
    archive_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(archive_path)]
    @test count(item -> item[
        "sampled_stability_narrow_c2_evidence_authorized"] === true,
        records) == 1
    audited = only(filter(item -> item[
        "sampled_stability_narrow_c2_evidence_authorized"] === true, records))
    @test audited["pool_index"] == 50
    @test bytes2hex(sha256(read(archive_path))) ==
        raw["candidate_archive"]["sha256"]
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end

@testset "three-route evidence acquisition queue v4" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "three_route_evidence_acquisition_queue_v4_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    summary = raw["summary"]
    @test summary["candidate_count"] == 68
    @test summary["round2_medium_favorable_count"] == 4
    @test summary["round2_new_narrow_c2_stability_count"] == 1
    @test summary[
        "total_new_search_narrow_c2_stability_survivor_count"] == 2
    @test summary["remaining_desc_stability_executable_count"] == 6
    @test summary["complete_c2_evidence_authorized_count"] == 0
    @test raw["next_actions"][
        "narrow_c2_stability_survivor_pool_indices"] == [50, 56]
    @test raw["next_actions"][
        "desc_medium_favorable_audit_pending_pool_indices"] == [15, 17, 24]
    @test raw["next_actions"][
        "next_desc_medium_to_fine_audit_pool_index"] == 15
    @test raw["gates"]["three_physical_routes_present"]
    @test raw["gates"]["round2_medium_results_not_all_promoted"]
    @test !raw["gates"]["all_mode_stability_established"]
    @test !raw["gates"]["complete_c2_evidence_authorized"]
    archive_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(archive_path)]
    @test length(records) == 68
    @test count(item -> item["state"] ==
        "medium_stability_favorable_audit_pending", records) == 3
    @test count(item -> item["state"] ==
        "narrow_c2_stability_survivor_round2", records) == 1
    @test bytes2hex(sha256(read(archive_path))) ==
        raw["candidate_archive"]["sha256"]
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end
