@testset "pulsed radiation hydrodynamics input compiler v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    input_path = joinpath(root, "runs",
        "native_candidate_c1_backend_candidates_v1_20260816.jsonl")
    inputs = [JSON3.read(line, Dict{String,Any})
        for line in eachline(input_path)]
    pulse = only(first(filter(item ->
        item["candidate_c1_evidence_authorized"] === true &&
        item["c1_route"] == "pulsed_drive_geometry", inputs), 1))
    contract = compile_pulsed_rhd_input_contract_v1(pulse)
    @test contract["candidate_c1_evidence_authorized"]
    @test contract["geometry"]["spherical_1d_mapping_declared"]
    @test contract["geometry"]["outer_radius"]["unit"] == "m"
    @test contract["geometry"]["dt_fuel_mass"]["unit"] == "kg"
    @test contract["drive"]["on_target_energy"]["unit"] == "J"
    @test contract["drive"]["emitter_count"] > 0
    @test !isempty(contract["drive"]["source_map_hashes"])
    @test contract["status"] == "unknown"
    @test !contract["c2_evidence_authorized"]
    @test !contract["promotion_authorized"]
    @test "equation_of_state_tables" in contract["blocking_missing_inputs"]
    @test "multigroup_opacity_tables" in contract["blocking_missing_inputs"]
    @test "time_resolved_drive_history" in contract["blocking_missing_inputs"]
    @test !("spherical_target_geometry" in
        contract["blocking_missing_inputs"])

    scrambled = deepcopy(pulse)
    scrambled["execution_genome"]["family"] =
        "diagnostic_scrambled_family_label"
    scrambled_contract = compile_pulsed_rhd_input_contract_v1(scrambled)
    @test scrambled_contract["physical_contract_hash"] ==
        contract["physical_contract_hash"]
end

@testset "dual-route pulsed radiation hydrodynamics contracts v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    input_path = joinpath(root, "runs",
        "dual_route_multitopology_c1_candidates_v1_20260816.jsonl")
    inputs = [JSON3.read(line, Dict{String,Any})
        for line in eachline(input_path)]
    pulse = only(first(filter(item ->
        item["route"] == "pulsed_drive_geometry", inputs), 1))
    contract = compile_pulsed_rhd_input_contract_v1(pulse)
    @test contract["source_design_id"] ==
        "dual_route_c0_candidate_$(pulse["candidate_index"])"
    @test contract["execution_physics_hash"] == pulse["physics_hash"]
    @test contract["candidate_c1_evidence_authorized"]
    @test contract["geometry"]["outer_radius"]["value"] ==
        pulse["parameters"]["capsule_outer_radius_m"]
    @test contract["geometry"]["outer_radius"]["basis"] ==
        "dual_route_search_parameter"
    @test contract["drive"]["emitter_count"] ==
        pulse["backend_result"]["procedural_emitter_count"]
    @test length(contract["drive"]["source_map_hashes"]) == 2
    @test contract["status"] == "unknown"
    @test !contract["c2_evidence_authorized"]

    artifact_path = joinpath(root, "runs",
        "dual_route_pulsed_rhd_input_contract_v1_20260816.json")
    raw = JSON3.read(read(artifact_path, String), Dict{String,Any})
    @test raw["input"]["selected_candidate_count"] == 64
    @test raw["input"]["pulse_c1_candidate_count"] == 32
    @test raw["summary"]["contract_count"] == 32
    @test raw["summary"]["unique_execution_physics_hash_count"] == 32
    @test raw["summary"]["unique_physical_contract_hash_count"] == 32
    @test raw["summary"]["unknown_count"] == 32
    @test raw["summary"]["external_backend_input_ready_count"] == 0
    @test raw["summary"]["c2_evidence_authorized_count"] == 0
    @test raw["gates"]["all_selected_pulse_c1_candidates_compiled"]
    @test raw["gates"]["all_contracts_unique"]
    @test !raw["gates"]["external_backend_executed"]
    @test !raw["gates"]["performance_search_authorized"]
    record_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(record_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(record_path)]
    @test length(records) == 32
    @test all(item["status"] == "unknown" for item in records)
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end

@testset "pulsed radiation hydrodynamics input batch and backend audit v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    artifact_path = joinpath(root, "runs",
        "pulsed_rhd_input_contract_v1_20260816.json")
    raw = JSON3.read(read(artifact_path, String), Dict{String,Any})
    @test raw["input"]["pulse_c1_candidate_count"] == 15
    @test raw["summary"]["contract_count"] == 15
    @test raw["summary"]["unique_execution_physics_hash_count"] == 15
    @test raw["summary"]["unique_physical_contract_hash_count"] == 15
    @test raw["summary"]["unknown_count"] == 15
    @test raw["summary"]["external_backend_input_ready_count"] == 0
    @test raw["summary"]["c2_evidence_authorized_count"] == 0
    @test raw["gates"]["all_pulse_c1_candidates_compiled"]
    @test raw["gates"]["all_contracts_unique"]
    @test !raw["gates"]["external_backend_executed"]
    @test !raw["gates"]["performance_search_authorized"]

    record_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(record_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(record_path)]
    @test length(records) == 15
    @test all(item["status"] == "unknown" for item in records)
    @test all(!item["c2_evidence_authorized"] for item in records)
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)

    audit_path = joinpath(root, "knowledge",
        "pulsed_radiation_hydrodynamics_backend_audit_v1.json")
    audit = JSON3.read(read(audit_path, String), Dict{String,Any})
    @test audit["selected_backend"] == "multi_ife_aezr_v1_0"
    @test audit["gates"]["primary_backend_identified"]
    @test !audit["gates"]["primary_source_acquired"]
    @test !audit["gates"]["primary_license_use_confirmed"]
    @test !audit["gates"]["c2_evidence_authorized"]
    @test !audit["gates"]["performance_search_authorized"]
    @test length(audit["backends"]) == 3
    audit_core = Dict{String,Any}(key => value for (key, value) in audit if
        key != "deterministic_hash")
    @test audit["deterministic_hash"] == canonical_hash(audit_core)
end
