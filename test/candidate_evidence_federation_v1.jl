@testset "candidate evidence federation functions v1" begin
    physics_hash = repeat("a", 64)
    observations = Dict{String,Any}[
        Dict("component_id" => "equilibrium",
            "required_for_complete_c2" => true, "status" => "pass",
            "evidence_level" => "C2", "hard_gate" => true,
            "source_physics_hash" => physics_hash,
            "evidence_values" => Dict("residual" => 1.0e-5)),
        Dict("component_id" => "transport",
            "required_for_complete_c2" => true, "status" => "unknown",
            "evidence_level" => "C1", "hard_gate" => true,
            "source_physics_hash" => physics_hash)]
    result = federate_candidate_evidence_v1(physics_hash, observations)
    @test result["family_label_used"] === false
    @test result["component_count"] == 2
    @test result["component_c2_pass_count"] == 1
    @test result["complete_c2_missing_components"] == ["transport"]
    @test result["status"] == "unknown"
    @test !result["hard_falsified"]
    @test !result["complete_c2_evidence_authorized"]
    @test !result["promotion_authorized"]

    metadata_changed = deepcopy(observations)
    metadata_changed[1]["family"] = "scrambled_family_label"
    @test federate_candidate_evidence_v1(physics_hash,
        metadata_changed)["physical_evidence_hash"] ==
        result["physical_evidence_hash"]

    failed = deepcopy(observations)
    failed[2]["status"] = "fail"
    @test federate_candidate_evidence_v1(physics_hash,
        failed)["hard_falsified"]
    @test_throws ArgumentError federate_candidate_evidence_v1(physics_hash,
        [merge(observations[1], Dict("source_physics_hash" => repeat("b", 64)))])
    @test_throws ArgumentError federate_candidate_evidence_v1(physics_hash,
        [observations[1], observations[1]])
end

@testset "pool16 candidate evidence federation artifact v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "stellarator_pool16_candidate_evidence_federation_v1_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    federation = raw["federation"]
    @test raw["design_id"] == "stellarator_fourier_71cef0178bcf03a2"
    @test raw["physics_hash"] ==
        "8bc6df1ccf3cb758a4b76ee207315de6df8f31a15ae631dbb5d057f4a451dd6a"
    @test federation["candidate_physics_hash"] == raw["physics_hash"]
    @test federation["family_label_used"] === false
    @test federation["component_count"] == 10
    @test federation["required_complete_c2_component_count"] == 10
    @test federation["component_c2_pass_count"] == 2
    @test federation["status"] == "unknown"
    @test !federation["hard_falsified"]
    @test !federation["complete_c2_evidence_authorized"]
    @test !federation["promotion_authorized"]
    @test length(federation["complete_c2_missing_components"]) == 8
    @test "drift_kinetic_transport" in
        federation["complete_c2_missing_components"]
    @test "finite_build_magnet_engineering" in
        federation["complete_c2_missing_components"]
    @test "coupled_energy_balance" in
        federation["complete_c2_missing_components"]
    by_id = Dict(String(item["component_id"]) => item
        for item in federation["components"])
    @test by_id["fixed_boundary_equilibrium"]["status"] == "pass"
    @test by_id["sampled_local_ideal_mhd_stability"]["status"] == "pass"
    @test by_id["drift_kinetic_transport"]["status"] == "unknown"
    @test by_id["filament_coil_field_realization"]["evidence_level"] == "C1"
    @test by_id["filament_coil_field_realization"]["evidence_values"][
        "three_mm_screen_passed"] === false
    @test length(raw["observed_non_authorizing_failures"]) == 2
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end
