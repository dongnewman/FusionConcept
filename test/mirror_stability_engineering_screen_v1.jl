@testset "mirror stability and engineering screen functions v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    input_path = joinpath(root, "runs",
        "dual_route_multitopology_c1_candidates_v1_20260816.jsonl")
    inputs = [JSON3.read(line, Dict{String,Any})
        for line in eachline(input_path)]
    mirrors = filter(item -> item["route"] == "axisymmetric_mirror_field" &&
        item["candidate_c1_evidence_authorized"] === true, inputs)
    failing = only(first(filter(item -> item["backend_result"]["central_field_t"] *
        item["backend_result"]["mirror_ratio"] >
        item["parameters"]["declared_peak_field_screen_t"], mirrors), 1))
    surviving = only(first(filter(item -> item["backend_result"]["central_field_t"] *
        item["backend_result"]["mirror_ratio"] <=
        item["parameters"]["declared_peak_field_screen_t"], mirrors), 1))
    failed = evaluate_mirror_stability_engineering_screen_v1(failing)
    unknown = evaluate_mirror_stability_engineering_screen_v1(surviving)
    @test failed["status"] == "fail"
    @test failed["hard_engineering_falsified"]
    @test !failed["on_axis_peak_screen_pass"]
    @test failed["peak_field_margin_t"] < 0.0
    @test unknown["status"] == "unknown"
    @test !unknown["hard_engineering_falsified"]
    @test unknown["on_axis_peak_screen_pass"]
    @test unknown["peak_field_margin_t"] >= 0.0
    for result in (failed, unknown)
        @test result["candidate_c1_evidence_authorized"]
        @test result["minimum_b_evidence_authorized"]
        @test !result["local_minimum_b"]
        @test result["local_field_strength_saddle"]
        @test result["field_strength_radial_curvature_t_per_m2"] < 0.0
        @test result["field_strength_axial_curvature_t_per_m2"] > 0.0
        @test result["magnetic_pressure_at_axis_throat_pa"] > 0.0
        @test length(result["current_density_sensitivities"]) == 3
        @test !result["minimum_b_stability_credit"]
        @test !result["finite_coil_engineering_evidence_authorized"]
        @test result["stability_status"] == "unknown"
        @test !result["c2_evidence_authorized"]
        @test !result["promotion_authorized"]
        replay = evaluate_mirror_stability_engineering_screen_v1(
            result === failed ? failing : surviving)
        @test replay["physical_result_hash"] == result["physical_result_hash"]
    end
end

@testset "mirror stability and engineering screen batch artifact v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    artifact_path = joinpath(root, "runs",
        "mirror_stability_engineering_screen_v1_20260816.json")
    raw = JSON3.read(read(artifact_path, String), Dict{String,Any})
    summary = raw["summary"]
    gates = raw["gates"]
    @test raw["input"]["dual_route_c1_count"] == 64
    @test raw["input"]["mirror_selected_count"] == 32
    @test raw["input"]["mirror_c1_count"] == 31
    @test summary["evaluated_count"] == 31
    @test summary["status_histogram"]["fail"] == 13
    @test summary["status_histogram"]["unknown"] == 18
    @test summary["hard_engineering_falsified_count"] == 13
    @test summary["on_axis_peak_screen_pass_count"] == 18
    @test summary["local_minimum_b_count"] == 0
    @test summary["local_field_strength_saddle_count"] == 31
    @test summary["minimum_throat_field_t"] > 4.0
    @test summary["maximum_throat_field_t"] > 60.0
    @test summary["maximum_magnetic_pressure_pa"] > 1.5e9
    @test summary["stability_evidence_authorized_count"] == 0
    @test summary["finite_coil_engineering_evidence_authorized_count"] == 0
    @test summary["c2_evidence_authorized_count"] == 0
    @test gates["all_mirror_c1_candidates_evaluated"]
    @test gates["minimum_b_diagnostic_complete"]
    @test gates["hard_falsification_observed"]
    @test !gates["stability_evidence_authorized"]
    @test !gates["finite_coil_engineering_evidence_authorized"]
    @test !gates["performance_search_authorized"]
    @test !gates["promotion_authorized"]
    record_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(record_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(record_path)]
    @test length(records) == 31
    @test count(item -> item["hard_engineering_falsified"], records) == 13
    @test all(!item["local_minimum_b"] for item in records)
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end
