@testset "candidate-specific mirror winding v1 compiler" begin
    root = normpath(joinpath(@__DIR__, ".."))
    input_path = joinpath(root, "runs",
        "dual_route_multitopology_c1_candidates_v1_20260816.jsonl")
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(input_path)]
    source = only(filter(item -> String(item["physics_hash"]) ==
        "0784543758c3dab514e588b161e1be06acb7efcc1f0b071a0d9a7e60f80f80cd",
        records))
    compiled = compile_candidate_specific_mirror_winding_problem_v1(source)
    @test compiled["status"] == "ready"
    @test compiled["family_label_used"] === false
    @test length(String(compiled["solver_problem_hash"])) == 64
    scrambled = deepcopy(source)
    scrambled["route"] = "not_a_family"
    @test compile_candidate_specific_mirror_winding_problem_v1(scrambled)[
        "solver_problem_hash"] == compiled["solver_problem_hash"]
    changed = deepcopy(source)
    changed["parameters"]["coil_radius_m"] =
        Float64(changed["parameters"]["coil_radius_m"]) + 0.01
    @test compile_candidate_specific_mirror_winding_problem_v1(changed)[
        "solver_problem_hash"] != compiled["solver_problem_hash"]

    evaluated = evaluate_candidate_specific_mirror_winding_v1(source;
        coarse_pack_grid = 5, refined_pack_grid = 7,
        coarse_circle_segments = 64, refined_circle_segments = 128)
    @test evaluated["original_candidate_hard_falsified"] === true
    @test evaluated[
        "candidate_specific_finite_winding_vacuum_component_authorized"] === true
    @test evaluated["family_label_used"] === false
    @test evaluated["complete_c2_evidence_authorized"] === false
    @test evaluated["promotion_authorized"] === false
    @test length(evaluated["repair_cases"]) == 4
    selected = evaluated["selected_repair"]
    @test all(values(selected["repair_gates"]))
    @test selected["refined_numerical_result"][
        "peak_winding_field_upper_bound_T"] <=
        evaluated["shared_engineering_boundary"][
            "peak_conductor_field_limit_T"]
    @test selected["minimum_similarity_repair"]["similarity_scale"] > 1.0
end

@testset "candidate-specific mirror winding v1 artifact" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "candidate_specific_mirror_winding_v1_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    summary = raw["summary"]
    @test summary["evaluated_parent_count"] == 4
    @test summary["original_declared_geometry_hard_falsified_count"] == 4
    @test summary["repair_generated_count"] == 4
    @test summary["narrow_finite_winding_vacuum_component_count"] == 4
    @test summary["complete_c2_evidence_authorized_count"] == 0
    @test summary["promotion_authorized_count"] == 0
    @test raw["gates"]["route_label_scramble_invariant"]
    @test raw["gates"]["repair_vacuum_components_numerically_converged"]
    @test !raw["gates"]["complete_c2_evidence_authorized"]
    archive_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(archive_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(archive_path)]
    @test length(records) == 4
    @test length(Set(String(item["repair_candidate_id"])
        for item in records)) == 4
    @test all(item -> item["original_candidate_hard_falsified"] === true,
        records)
    @test all(item -> item[
        "candidate_specific_finite_winding_vacuum_component_authorized"] === true,
        records)
    @test all(item -> item["selected_repair"]["repair_gates"][
        "numerical_refinement"] === true, records)
    @test all(item -> item["complete_c2_evidence_authorized"] === false,
        records)
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end

@testset "three-route evidence acquisition queue v2" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "three_route_evidence_acquisition_queue_v2_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    summary = raw["summary"]
    @test summary["candidate_count"] == 68
    @test summary["route_histogram"]["open_axisymmetric_mirror"] == 22
    @test summary["route_histogram"][
        "three_dimensional_closed_fourier"] == 14
    @test summary["route_histogram"][
        "pulsed_target_radiation_hydrodynamics"] == 32
    @test summary["declared_mirror_parent_hard_falsified_count"] == 4
    @test summary["mirror_repair_child_count"] == 4
    @test summary["selected_mirror_repair_child_count"] == 4
    @test summary["narrow_c2_finite_winding_vacuum_component_count"] == 4
    @test summary["hard_falsified_count"] == 7
    @test summary["complete_c2_evidence_authorized_count"] == 0
    @test length(raw["next_actions"][
        "mirror_finite_winding_repair_candidate_ids"]) == 4
    @test raw["gates"]["three_physical_routes_present"]
    @test raw["gates"][
        "declared_parent_hard_fails_excluded_from_next_actions"]
    @test raw["gates"]["repair_children_have_distinct_physical_identity"]
    @test !raw["gates"]["complete_c2_evidence_authorized"]
    archive_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(archive_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(archive_path)]
    @test length(records) == 68
    @test count(item -> get(item, "variant", "") ==
        "finite_winding_similarity_repair_v1", records) == 4
    @test all(item -> item["selected_for_next_action"] === false,
        filter(item -> item["state"] ==
            "hard_falsified_shared_radial_build_as_declared", records))
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end
