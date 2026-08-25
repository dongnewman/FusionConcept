@testset "candidate-specific minimum-B cage bounded search v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "candidate_specific_minimum_b_cage_search_v1_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    summary = raw["summary"]
    @test summary["parent_count"] == 4
    @test summary["evaluated_configuration_count"] == 31_752
    @test summary["sampled_well_pass_count"] == 12_844
    @test summary["open_field_line_pass_count"] == 150
    @test summary["coarse_peak_field_pass_count"] == 0
    @test summary["minimum_b_vacuum_component_authorized_count"] == 0
    @test summary["complete_c2_evidence_authorized_count"] == 0
    @test raw["gates"]["all_parent_repairs_evaluated"]
    @test raw["gates"]["family_label_used"] === false
    @test !raw["gates"]["minimum_b_vacuum_component_authorized"]
    archive_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(archive_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(archive_path)]
    @test length(records) == 4
    @test all(item -> item["evaluated_configuration_count"] == 7_938,
        records)
    @test all(item -> item["sampled_well_pass_count"] > 0, records)
    @test all(item -> item["open_field_line_pass_count"] > 0, records)
    @test all(item -> item["coarse_peak_field_pass_count"] == 0, records)
    @test all(item -> item["minimum_b_vacuum_component_authorized"] === false,
        records)
    @test all(item -> item["best_bounded_cage_attempt"][
        "refined_peak_winding_field"]["peak_field_T"] >
            item["best_bounded_cage_attempt"]["physical_input"][
                "peak_conductor_field_limit_T"], records)
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end

@testset "minimum-B cage local refinement v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "minimum_b_cage_local_refinement_v1_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    summary = raw["summary"]
    best = raw["best_attempt"]
    @test summary["evaluated_configuration_count"] == 12_285
    @test summary["sampled_well_pass_count"] == 2_808
    @test summary["open_field_line_pass_count"] == 532
    @test summary["peak_field_screen_pass_count"] == 0
    @test summary["minimum_b_vacuum_component_authorized_count"] == 0
    @test raw["gates"]["sampled_transverse_minimum_b_well"]
    @test raw["gates"]["open_field_line_integrity"]
    @test raw["gates"]["peak_field_refinement"]
    @test !raw["gates"]["peak_winding_field_screen"]
    @test !raw["gates"]["minimum_b_vacuum_component_authorized"]
    @test best["fine_peak_winding_field"]["peak_field_T"] > 23.511
    @test best["quadrupole_pack_width_m"] == 2.25
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end

@testset "three-route evidence acquisition queue v3" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "three_route_evidence_acquisition_queue_v3_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    summary = raw["summary"]
    @test summary["candidate_count"] == 68
    @test summary["bounded_cage_configuration_count"] == 31_752
    @test summary["bounded_cage_sampled_well_pass_count"] == 12_844
    @test summary["bounded_cage_open_line_pass_count"] == 150
    @test summary["bounded_cage_peak_field_pass_count"] == 0
    @test summary["local_refinement_configuration_count"] == 12_285
    @test summary["selected_alternative_stabilization_mirror_count"] == 2
    @test summary["complete_c2_evidence_authorized_count"] == 0
    @test length(raw["next_actions"][
        "mirror_alternative_stabilization_candidate_ids"]) == 2
    @test raw["gates"]["three_physical_routes_present"]
    @test raw["gates"]["bounded_cage_negative_not_promoted"]
    @test raw["gates"]["same_cage_grammar_budget_reduced"]
    @test !raw["gates"]["complete_c2_evidence_authorized"]
    archive_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(archive_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(archive_path)]
    mirror_repairs = filter(item -> get(item, "variant", "") ==
        "finite_winding_similarity_repair_v1", records)
    @test length(mirror_repairs) == 4
    @test all(item -> item["state"] ==
        "finite_winding_survivor_bounded_cage_grammar_failed",
        mirror_repairs)
    @test count(item -> item["selected_for_next_action"] === true,
        mirror_repairs) == 2
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end
