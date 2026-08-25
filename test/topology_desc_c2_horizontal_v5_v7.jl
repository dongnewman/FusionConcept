@testset "topology DESC round2 audit completion" begin
    root = normpath(joinpath(@__DIR__, ".."))
    audit_specs = Dict(
        15 => ("topology_desc_stability_pool15_medium_fine_audit_v4_20260816.json",
            "1cd2de6d4075004512fd225486975d8c421373f3d085d7cfbbfedbafd82b098c"),
        17 => ("topology_desc_stability_pool17_medium_fine_audit_v4_20260816.json",
            "7b16cded94c490b5def7c8ba1dc702e13bbbf9e3b4dfc776481cd0c940eae0c8"),
        24 => ("topology_desc_stability_pool24_medium_fine_audit_v4_20260816.json",
            "9c4cc45dc6443ef0b387402df461e53a1134d4e64daa7840cefa5fc22a1f9fe0"),
    )
    for (pool, (name, expected_hash)) in audit_specs
        raw = JSON3.read(read(joinpath(root, "runs", name), String),
            Dict{String,Any})
        @test raw["all_passed"] === true
        @test raw["audit_hash"] == expected_hash
        @test raw["comparisons"]["mercier_minimum_medium_normalized"] > 0
        @test raw["comparisons"]["mercier_minimum_fine_normalized"] > 0
        @test raw["comparisons"]["ballooning_maximum_medium"] < 0
        @test raw["comparisons"]["ballooning_maximum_fine"] < 0
        @test raw["comparisons"]["force_residual_fine"] < 0.01
        @test all(value === true for value in values(raw["gates"]))
    end
end

@testset "topology DESC stability acquisition round3 v5" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "topology_desc_stability_acquisition_round3_v5_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    search = raw["search"]
    @test Int.(search["selected_pool_indices"]) == [23, 26, 44, 51, 55, 64]
    @test search["selected_count"] == 6
    @test search["completed_count"] == 6
    @test search["sampled_favorable_count"] == 4
    @test search["family_scramble_invariant_count"] == 6
    @test search["unique_stability_problem_hash_count"] == 6
    @test search["complete_c2_evidence_authorized_count"] == 0
    @test raw["gates"]["all_selected_executed"]
    @test raw["gates"]["all_family_scramble_invariant"]
    @test !raw["gates"]["complete_c2_evidence_authorized"]
    archive_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(archive_path)]
    @test length(records) == 6
    @test sort(collect(Int(item["pool_index"]) for item in records if item[
        "sampled_local_ideal_mhd_favorable"] === true)) == [23, 26, 44, 64]
    @test sort(collect(Int(item["pool_index"]) for item in records if item[
        "sampled_local_ideal_mhd_favorable"] === false)) == [51, 55]
    @test all(item["result"]["minimum_mercier_D_normalized"] < 0
        for item in records if item["pool_index"] in (51, 55))
    @test bytes2hex(sha256(read(archive_path))) ==
        raw["candidate_archive"]["sha256"]
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end

@testset "candidate-bound surface-current and discrete-coil evidence" begin
    root = normpath(joinpath(@__DIR__, ".."))
    surface_path = joinpath(root, "runs",
        "topology_desc_surface_current_survivors_v6_20260816.json")
    surface = JSON3.read(read(surface_path, String), Dict{String,Any})
    @test surface["summary"]["selected_pool_indices"] == [15, 17, 24, 50]
    @test surface["summary"]["completed_count"] == 2
    @test surface["summary"]["reference_normalized_bn_rms_met_count"] == 2
    @test surface["summary"]["discrete_coils_created_count"] == 0
    @test !surface["gates"]["family_label_used"]
    @test !surface["gates"]["complete_c2_evidence_authorized"]
    surface_archive = joinpath(root,
        split(surface["candidate_archive"]["jsonl"], '/')...)
    surface_records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(surface_archive)]
    @test sort(collect(Int(item["pool_index"]) for item in surface_records if
        item["continuous_surface_current_completed"] === true)) == [17, 24]
    @test sort(collect(Int(item["pool_index"]) for item in surface_records if
        item["continuous_surface_current_completed"] === false)) == [15, 50]
    @test bytes2hex(sha256(read(surface_archive))) ==
        surface["candidate_archive"]["sha256"]
    surface_core = Dict{String,Any}(key => value for (key, value) in surface if
        key != "deterministic_hash")
    @test surface["deterministic_hash"] == canonical_hash(surface_core)

    failure = JSON3.read(read(joinpath(root, "runs",
        "topology_desc_surface_current_pool17_resolution_failure_v6_20260816.json"),
        String), Dict{String,Any})
    @test failure["target"]["pool_index"] == 17
    @test failure["gates"]["failure_reproduced"]
    @test !failure["gates"][
        "constant_offset_winding_surface_resolution_audited"]
    @test failure["refined_attempt"]["error_message"] ==
        "constant-offset winding surface failed declared gates"
    failure_core = Dict{String,Any}(key => value for (key, value) in failure if
        key != "deterministic_hash")
    @test failure["deterministic_hash"] == canonical_hash(failure_core)

    audit = JSON3.read(read(joinpath(root, "runs",
        "topology_desc_surface_current_pool24_resolution_audit_v6_20260816.json"),
        String), Dict{String,Any})
    @test audit["target"]["pool_index"] == 24
    @test audit["all_passed"]
    @test audit["comparisons"]["minimum_normalized_bn_rms_refined"] < 0.01
    @test audit["comparisons"]["reference_normalized_bn_rms_refined"] < 0.01

    coil = JSON3.read(read(joinpath(root, "runs",
        "topology_desc_discrete_coil_cut_pool24_v7_20260816.json"), String),
        Dict{String,Any})
    @test coil["summary"]["cut_count"] == 3
    @test coil["summary"]["integrity_pass_count"] == 3
    @test coil["summary"]["normalized_bn_reference_met_count"] == 0
    @test coil["summary"][
        "all_three_comparison_references_met_count"] == 0
    @test minimum(item["normalized_bn_rms"] for item in coil["cuts"]) > 0.06
    @test coil["gates"]["discrete_coils_created"]
    @test !coil["gates"][
        "at_least_one_cut_meets_all_comparison_references"]
    @test !coil["gates"]["finite_build_coils_feasibility_established"]
    @test coil["deterministic_hash"] ==
        "5ff66e9777415ab95111f958a91e7d08277e35f3e611ac39c4ad41ee36052901"
end

@testset "three-route evidence acquisition queue v5" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "three_route_evidence_acquisition_queue_v5_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    summary = raw["summary"]
    @test summary["candidate_count"] == 68
    @test summary["round3_medium_completed_count"] == 6
    @test summary["round3_medium_favorable_count"] == 4
    @test summary["round3_candidate_specific_mercier_hard_fail_count"] == 2
    @test summary[
        "total_new_search_narrow_c2_stability_survivor_count"] == 5
    @test summary["surface_current_resolution_audited_survivor_count"] == 1
    @test summary["discrete_coil_sets_created_count"] == 3
    @test summary[
        "discrete_coil_sets_meeting_all_comparison_references_count"] == 0
    @test summary["hard_falsified_candidate_count"] == 9
    @test summary["complete_c2_evidence_authorized_count"] == 0
    @test raw["next_actions"][
        "desc_medium_favorable_audit_pending_pool_indices"] == [23, 26, 44, 64]
    @test raw["next_actions"][
        "narrow_c2_stability_survivor_pool_indices"] == [15, 17, 24, 50, 56]
    @test raw["next_actions"]["next_surface_current_pool_indices"] == [56]
    @test raw["next_actions"][
        "next_discrete_coil_optimization_pool_indices"] == [24]
    @test raw["gates"]["three_physical_routes_present"]
    @test raw["gates"]["all_desc_medium_stability_tasks_executed"]
    @test !raw["gates"]["complete_c2_evidence_authorized"]
    archive_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(archive_path)]
    @test length(records) == 68
    @test count(item -> item["hard_falsified"] === true, records) == 9
    @test bytes2hex(sha256(read(archive_path))) ==
        raw["candidate_archive"]["sha256"]
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end
