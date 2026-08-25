@testset "levitated dipole ring screen functions v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    input_path = joinpath(root, "runs",
        "native_candidate_c1_backend_candidates_v1_20260816.jsonl")
    inputs = [JSON3.read(line, Dict{String,Any})
        for line in eachline(input_path)]
    dipole = only(filter(item -> Int(item["queue_rank"]) == 18, inputs))
    genome = parse_genome(dipole["execution_genome"])
    result = evaluate_levitated_dipole_ring_screen_v1(genome)
    @test result["backend_executed"]
    @test result["status"] == "fail"
    @test result["hard_falsified"]
    @test result["source_semantics_verified"]
    @test result["coil_radius_gene_link_relative_error"] <= 1.0e-12
    @test result["peak_field_gene_link_relative_error"] <= 1.0e-12
    @test result["maxwell_coefficient_evidence_authorized"]
    @test result["biot_savart_coarse_fine_relative_change"] < 1.0e-4
    @test result["target_field_relative_error"] <= 1.0e-12
    @test result["required_equivalent_ampere_turns"] > 1.0e10
    @test result["ring_axis_center_field_t"] > 4.0e4
    @test !result["peak_screen_pass"]
    @test result["assembly_fits_inside_plasma_inner_radius"]
    @test result["envelope_repair_search"]["executed"]
    @test !result["envelope_repair_feasible"]
    @test result["envelope_repair_search"]["best_ring_axis_center_field_t"] >
        result["declared_peak_field_screen_t"]
    @test !result["field_topology_evidence_authorized"]
    @test !result["candidate_c1_evidence_authorized"]
    @test !result["c2_evidence_authorized"]
    @test !result["promotion_authorized"]
    replay = evaluate_levitated_dipole_ring_screen_v1(genome)
    @test replay["physical_result_hash"] == result["physical_result_hash"]
    scrambled_raw = deepcopy(genome.normalized)
    scrambled_raw["family"] = "diagnostic_scrambled_family_label"
    scrambled = evaluate_levitated_dipole_ring_screen_v1(
        parse_genome(scrambled_raw))
    @test scrambled["physical_result_hash"] == result["physical_result_hash"]
end

@testset "levitated dipole ring screen batch artifact v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    artifact_path = joinpath(root, "runs",
        "levitated_dipole_ring_screen_v1_20260816.json")
    raw = JSON3.read(read(artifact_path, String), Dict{String,Any})
    summary = raw["summary"]
    gates = raw["gates"]
    @test raw["input"]["frontier_candidate_count"] == 64
    @test raw["input"]["unknown_dipole_candidate_count"] == 4
    @test summary["evaluated_count"] == 4
    @test summary["source_semantics_verified_count"] == 4
    @test summary["maxwell_coefficient_authorized_count"] == 4
    @test summary["peak_screen_failure_count"] == 4
    @test summary["assembly_overlap_failure_count"] == 1
    @test summary["envelope_repair_search_executed_count"] == 3
    @test summary["envelope_repair_feasible_count"] == 0
    @test summary["hard_falsified_count"] == 4
    @test summary["family_scramble_invariant_count"] == 4
    @test summary["minimum_required_ampere_turns"] > 2.0e9
    @test summary["maximum_required_ampere_turns"] > 2.0e10
    @test summary["minimum_ring_axis_center_field_t"] > 6.0e3
    @test summary["maximum_ring_axis_center_field_t"] > 4.0e4
    @test summary["field_topology_evidence_authorized_count"] == 0
    @test summary["c2_evidence_authorized_count"] == 0
    @test gates["all_unknown_dipole_candidates_evaluated"]
    @test gates["source_semantics_verified"]
    @test gates["family_scramble_invariant"]
    @test gates["hard_falsification_observed"]
    @test !gates["field_topology_evidence_authorized"]
    @test !gates["performance_search_authorized"]
    @test !gates["promotion_authorized"]
    record_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(record_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(record_path)]
    @test length(records) == 4
    @test all(item["hard_falsified"] for item in records)
    @test all(!item["envelope_repair_feasible"] for item in records)
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end
