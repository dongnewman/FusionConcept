@testset "Physics Compiler v2 separates magnetic, pulsed, and hybrid C1 routes" begin
    root = normpath(joinpath(@__DIR__, ".."))
    queue_path = joinpath(root, "runs",
        "mechanism_frontier_evidence_queue_candidates_v1_20260816.jsonl")
    records = [JSON3.read(line, Dict{String,Any}) for line in eachline(queue_path)]
    by_label(label) = parse_genome(first(filter(item ->
        item["diagnostic_legacy_family_label"] == label, records))["genome"])
    pulse = by_label("inertial_confinement_fusion")
    magnetic = by_label("magnetic_mirror")
    hybrid = by_label("magnetized_target_fusion")
    @test physics_c1_route_v2(pulse) == :pulsed_drive_geometry
    @test physics_c1_route_v2(magnetic) == :magnetic_field_topology
    @test physics_c1_route_v2(hybrid) == :hybrid_magnetic_pulsed
    pulse_ids = Set(item.spec.id for item in compile_physics_problem_v2(pulse).operators)
    magnetic_ids = Set(item.spec.id for item in compile_physics_problem_v2(magnetic).operators)
    hybrid_ids = Set(item.spec.id for item in compile_physics_problem_v2(hybrid).operators)
    @test "pulsed_drive_geometry_v2" in pulse_ids
    @test "pulsed_radiation_hydrodynamics_v2" in pulse_ids
    @test !("maxwell_magnetostatic_field_v1" in pulse_ids)
    @test !("field_line_topology_trace_v1" in pulse_ids)
    @test "maxwell_magnetostatic_field_v1" in magnetic_ids
    @test "field_line_topology_trace_v1" in magnetic_ids
    @test !("pulsed_drive_geometry_v2" in magnetic_ids)
    @test "maxwell_magnetostatic_field_v1" in hybrid_ids
    @test "pulsed_drive_geometry_v2" in hybrid_ids
    @test length(default_physics_operator_registry_v2()) == 23
end

@testset "mechanism-native geometry generation v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    artifact_path = joinpath(root, "runs",
        "mechanism_native_geometry_generation_v1_20260816.json")
    raw = JSON3.read(read(artifact_path, String), Dict{String,Any})
    summary = raw["generation_summary"]
    gates = raw["gates"]
    @test raw["input"]["candidate_count"] == 64
    @test raw["input"]["mechanism_cell_count"] == 20
    @test summary["derived_candidate_count"] == 64
    @test summary["unique_derived_physics_hash_count"] == 64
    @test summary["geometry_input_complete_count"] == 64
    @test summary["family_scramble_invariant_count"] == 64
    @test summary["native_executable_validation_pass_count"] == 64
    @test summary["candidate_with_structurally_ready_c1_operator_count"] == 64
    @test summary["generated_parameter_count"] == 2_051
    @test summary["explicit_native_module_count"] == 152
    @test summary["ready_native_module_count"] == 27
    @test summary["complete_native_program_count"] == 0
    @test summary["c1_evidence_authorized_count"] == 0
    @test summary["c1_route_histogram"]["magnetic_field_topology"] == 37
    @test summary["c1_route_histogram"]["pulsed_drive_geometry"] == 15
    @test summary["c1_route_histogram"]["hybrid_magnetic_pulsed"] == 12
    @test gates["all_source_candidates_physically_unique"]
    @test gates["all_derived_candidates_physically_unique"]
    @test gates["all_geometry_inputs_complete"]
    @test gates["all_native_executable_declarations_valid"]
    @test gates["family_scramble_invariant"]
    @test !gates["backend_solver_execution_complete"]
    @test !gates["c1_evidence_authorized"]
    @test !gates["medium_fidelity_admission_authorized"]
    @test !gates["promotion_authorized"]

    candidate_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(candidate_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any}) for line in eachline(candidate_path)]
    @test length(records) == 64
    @test length(unique(String(item["derived_physics_hash"]) for item in
        records)) == 64
    @test all(parse_genome(item["derived_genome"]).physics_hash ==
        item["derived_physics_hash"] for item in records)
    @test all(item["geometry_input_complete"] for item in records)
    @test all(item["family_scramble_invariant"] for item in records)
    @test all(!item["c1_evidence_authorized"] for item in records)
    @test all(item["executable_program"]["validation"]["valid"]
        for item in records)
    @test all(occursin("exploratory", join(String.(
        item["derived_genome"]["provenance"]["notes"]), " "))
        for item in records)
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        !(key in ("deterministic_hash", "runtime_measurements")))
    @test raw["deterministic_hash"] == canonical_hash(core)

    queue_path = joinpath(root, "runs",
        "mechanism_frontier_evidence_queue_candidates_v1_20260816.jsonl")
    source_records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(queue_path)]
    source_by_hash = Dict(String(item["physics_hash"]) => item
        for item in source_records)
    for item in records[1:3]
        source_hash = String(item["source_physics_hash"])
        @test haskey(source_by_hash, source_hash)
        replay = compile_mechanism_native_geometry_v1(
            parse_genome(source_by_hash[source_hash]["genome"]))
        @test replay.result_hash == item["result_hash"]
        @test replay.derived_genome.physics_hash == item["derived_physics_hash"]
        @test replay.geometry_input_complete
        @test !replay.c1_evidence_authorized
    end
end
