@testset "open-world Pleiades geometry search v1 artifacts" begin
    root = normpath(joinpath(@__DIR__, ".."))
    search_path = joinpath(root, "runs",
        "open_world_pleiades_geometry_search_v1_20260821.json")
    stability_path = joinpath(root, "runs",
        "open_world_pleiades_candidate_stability_screen_v1_20260821.json")
    search = JSON3.read(read(search_path, String), Dict{String,Any})
    summary = search["summary"]
    @test search["decision"] == "bounded_new_geometry_candidate_found"
    @test summary["unique_vacuum_candidate_count"] == 729
    @test summary["vacuum_necessary_condition_pass_count"] == 716
    @test summary["finite_beta_executed_count"] == 8592
    @test summary["finite_beta_coarse_pass_count"] == 8379
    @test summary["multi_grid_pass_count"] == 8
    @test summary["complete_device_pass_count"] == 0
    @test summary["promotion_authorized_count"] == 0
    @test search["archive"]["record_count"] == 9321
    archive_path = joinpath(root,
        split(String(search["archive"]["path"]), '/')...)
    @test bytes2hex(sha256(read(archive_path))) == search["archive"]["sha256"]

    best = search["best_bounded_candidate"]
    @test best !== nothing
    @test best["candidate_id"] == "pleiades_finite_beta_8f0f1fdeee636895"
    @test best["geometry"]["hts_radius_m"] == 0.225
    @test best["geometry"]["hts_half_separation_m"] == 1.0
    @test best["geometry"]["central_radius_m"] == 0.9
    @test best["geometry"]["central_half_separation_m"] == 0.15
    @test best["vacuum_screen"]["pass"]
    @test best["vacuum_screen"]["sampled_axis_peak_field_t"] < 25.0
    @test all(values(best["resolution_gates"]))
    @test length(best["resolution_solves"]) == 3
    @test all(item["pass"] for item in best["resolution_solves"])
    @test !search["evidence_authority"]["minimum_b_stability"]
    @test !search["evidence_authority"]["transport_and_end_loss"]
    @test !search["evidence_authority"]["complete_c2"]
    @test !search["evidence_authority"]["promotion_authorized"]

    stability = JSON3.read(read(stability_path, String), Dict{String,Any})
    @test stability["input"]["candidate_hash"] == best["candidate_hash"]
    @test stability["input"]["sha256"] == bytes2hex(sha256(read(search_path)))
    @test stability["gates"]["curvature_refinement_below_1pct"]
    @test stability["gates"]["center_is_local_field_strength_saddle"]
    @test !stability["gates"]["center_is_local_minimum_b"]
    @test !stability["gates"]["alternative_stabilization_mechanism_declared"]
    @test !stability["gates"]["complete_stability_evidence_authorized"]
    @test !stability["gates"]["promotion_authorized"]

    handoff_path = joinpath(root, "reports",
        "open_world_deep_search_handoff_v1.json")
    handoff = JSON3.read(read(handoff_path, String), Dict{String,Any})
    @test handoff["best_bounded_candidate"]["candidate_hash"] ==
        best["candidate_hash"]
    @test handoff["verdict"]["bounded_new_candidate_found"]
    @test handoff["verdict"]["candidate_passes_more_candidate_bound_numerical_tests"]
    @test !handoff["verdict"]["complete_fusion_device_found"]
    @test !handoff["verdict"]["promotion_authorized"]
    @test handoff["new_search_failure_analysis"]["failed_finite_beta_state_count"] == 213
    @test handoff["new_search_failure_analysis"]["failure_dimensions"][
        "pressure_exponent"] == Dict("1.5" => 213)
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(String(item["artifact_id"]), '/')...)))) == item["sha256"]
        for item in handoff["source_artifacts"])
    @test isfile(joinpath(root, "docs",
        "open_world_deep_search_handoff_v1_20260821.md"))
end
