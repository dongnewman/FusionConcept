@testset "Pinned CQL3D backend audit v1" begin
    path = joinpath(@__DIR__, "..", "knowledge", "cql3d_backend_audit_v1.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    @test raw["schema_version"] == "1.0.0"
    @test raw["commit"] == "3565fee6974deff69371321d8a053593eae1562d"
    @test raw["license"]["gpl_v3_or_later_detected"]
    @test raw["source_capabilities"]["public_multispecies_2v_1r_solver_declared"]
    @test raw["source_capabilities"]["public_mirror_mode_declared"]
    @test !raw["source_capabilities"]["public_mirror_lrz_greater_than_one_enabled"]
    @test raw["source_capabilities"]["cql3d_m_change_transfers_observed"]
    @test !raw["source_capabilities"]["exact_published_cql3d_m_equivalence_verified"]
    @test raw["source_capabilities"]["tracked_mirror_regression_input_count"] == 0
    @test !raw["gates"]["build_verified"]
    @test !raw["gates"]["candidate_solver_output_available"]
    @test !raw["gates"]["c2_kinetic_state_authorized"]
    @test raw["integration_policy"]["process_boundary_required"]
    @test !raw["integration_policy"]["vendored_into_project"]
    @test raw["deterministic_hash"] == canonical_hash(Dict{String,Any}(
        key => value for (key, value) in raw if key != "deterministic_hash"))
end
