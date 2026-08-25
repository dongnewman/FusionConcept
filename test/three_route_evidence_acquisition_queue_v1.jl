@testset "three-route evidence acquisition queue v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "three_route_evidence_acquisition_queue_v1_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    summary = raw["summary"]
    gates = raw["gates"]
    @test summary["candidate_count"] == 64
    @test summary["route_histogram"][
        "pulsed_target_radiation_hydrodynamics"] == 32
    @test summary["route_histogram"]["open_axisymmetric_mirror"] == 18
    @test summary["route_histogram"][
        "three_dimensional_closed_fourier"] == 14
    @test summary["state_histogram"][
        "blocked_external_permission_and_inputs"] == 32
    @test summary["state_histogram"]["implementation_required"] == 18
    @test summary["state_histogram"]["executable_now"] == 10
    @test summary["state_histogram"][
        "hard_falsified_sampled_mercier"] == 3
    @test summary["state_histogram"]["narrow_c2_stability_survivor"] == 1
    @test summary["immediately_executable_count"] == 10
    @test summary["selected_immediately_executable_count"] == 4
    @test summary["selected_mirror_implementation_count"] == 4
    @test summary["selected_narrow_c2_survivor_count"] == 1
    @test summary["hard_falsified_count"] == 3
    @test summary["blocked_external_permission_count"] == 32
    @test summary["complete_c2_evidence_authorized_count"] == 0
    @test summary["promotion_authorized_count"] == 0
    @test sort(Int.(raw["next_actions"][
        "immediate_desc_stability_pool_indices"])) == [15, 17, 24, 50]
    @test length(raw["next_actions"][
        "mirror_finite_build_candidate_ids"]) == 4
    @test raw["next_actions"]["narrow_c2_survivor_candidate_id"] ==
        "stellarator_fourier_41bc23ddd23f210d"
    @test gates["three_physical_routes_present"]
    @test gates["hard_fails_excluded_from_next_actions"]
    @test gates["external_blockers_not_marked_executable"]
    @test !gates["complete_c2_evidence_authorized"]
    @test !gates["performance_ranking_authorized"]
    @test !gates["promotion_authorized"]

    archive_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(archive_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(archive_path)]
    @test length(records) == 64
    @test all(!(item["hard_falsified"] === true &&
        item["selected_for_next_action"] === true) for item in records)
    @test all(!(item["execution_status"] == "blocked_external_permission" &&
        item["selected_for_next_action"] === true) for item in records)
    @test count(item -> item["selected_for_next_action"] === true, records) == 9
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end
