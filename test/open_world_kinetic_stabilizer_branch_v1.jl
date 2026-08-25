@testset "open-world kinetic stabilizer branch v1 artifact" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "open_world_kinetic_stabilizer_branch_v1_20260821.json")
    report = JSON3.read(read(path, String), Dict{String,Any})
    summary = report["summary"]
    @test summary["branch_candidate_count"] == 480
    @test summary["unique_candidate_hash_count"] == 480
    @test summary["ledger_gate_pass_count"] == 480
    @test summary["dclc_size_proxy_pass_count"] == 192
    @test summary["flr_m2_length_proxy_pass_count"] == 0
    @test summary["complete_stability_gate_pass_count"] == 0
    @test summary["complete_c2_evidence_authorized_count"] == 0
    @test summary["promotion_authorized_count"] == 0

    @test report["parent_binding"]["scalar_pressure_parent_unchanged"]
    @test report["parent_binding"]["geometry_unchanged"]
    selected = report["selected_evidence_parent"]
    @test selected["candidate_id"] == "ks_b6819c9d964c387a"
    @test selected["genes"]["pressure_fraction"] == 0.10
    @test selected["genes"]["replenishment_time_s"] == 0.05
    @test selected["genes"]["beam_particle_energy_kev"] == 25.0
    @test selected["genes"]["injection_pitch_deg"] == 45.0
    @test selected["ledger_gate_pass"]
    @test selected["particle_ledger"]["residual_s"] == 0.0
    @test selected["energy_ledger"]["deposited_power_residual_w"] == 0.0
    @test selected["gates"]["dclc_size_proxy"]
    @test !selected["gates"]["flr_m2_length_proxy"]
    @test !selected["complete_stability_gate_pass"]

    stages = Dict(String(item["stage"]) => item
        for item in report["ordered_test_chain"])
    @test stages["kinetic_stabilizer_operator_and_ledgers"]["status"] == "pass"
    @test stages["anisotropic_finite_beta_equilibrium"]["status"] == "unknown"
    @test stages["interchange_and_global_m1"]["status"] == "unknown"
    @test stages["dclc_and_aic"]["status"] == "fail_unknown"
    @test stages["end_loss"]["status"] ==
        "component_pass_physical_rate_unknown"
    @test stages["finite_coil_structure"]["status"] ==
        "necessary_conditions_pass_structure_unknown"
    kinetic_convergence = stages["dclc_and_aic"]["evidence"][
        "reduced_loss_cone_solver_convergence"]
    @test kinetic_convergence["status"] == "pass"
    @test kinetic_convergence["maximum_adjacent_relative_change"] < 0.04
    @test !kinetic_convergence["c2_physical_rate_authorized"]

    verdict = report["verdict"]
    @test verdict["kinetic_stabilizer_operator_and_ledgers_added"]
    @test verdict["end_loss_component_executed"]
    @test verdict["finite_coil_necessary_conditions_passed"]
    @test !verdict["anisotropic_finite_beta_equilibrium_passed"]
    @test !verdict["interchange_m1_passed"]
    @test !verdict["dclc_aic_passed"]
    @test !verdict["physical_end_loss_rate_authorized"]
    @test !verdict["finite_coil_structure_passed"]
    @test !verdict["complete_c2_passed"]
    @test !verdict["promotion_authorized"]

    archive_path = joinpath(root,
        split(String(report["archive"]["path"]), '/')...)
    @test report["archive"]["record_count"] == 480
    @test bytes2hex(sha256(read(archive_path))) == report["archive"]["sha256"]
    @test countlines(archive_path) == 480
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(String(item["artifact_id"]), '/')...)))) == item["sha256"]
        for item in report["source_artifacts"])
end
