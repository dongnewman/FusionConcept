@testset "Pleiades candidate kinetic problem IR v1" begin
    path = joinpath(@__DIR__, "..", "knowledge",
        "pleiades_candidate_kinetic_problem_ir_v1.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    @test raw["design_id"] == "pleiades_wham_nbi_kinetic_control_v1"
    @test raw["phase_space_source_binding"]["source_bin_count"] == 618
    @test raw["phase_space_source_binding"]["unique_source_bin_count"] == 618
    @test raw["phase_space_source_binding"]["signed_parallel_velocity_preserved"]
    @test raw["phase_space_source_binding"]["all_positions_in_field_domain"]
    @test raw["phase_space_source_binding"]["maximum_field_magnitude_identity_relative_residual"] < 1.0e-12
    @test raw["phase_space_source_binding"]["maximum_recomputed_aggregate_relative_residual"] < 1.0e-12
    @test raw["gates"]["candidate_geometry_source_binding_verified"]
    @test raw["gates"]["backend_neutral_kinetic_input_ready"]
    @test !raw["gates"]["public_cql3d_input_authorized"]
    @test !raw["gates"]["c2_phase_space_source_authorized"]
    @test !raw["gates"]["c2_kinetic_state_authorized"]
    @test raw["backend_routing"]["public_cql3d_mainline"] ==
        "rejected_physical_domain_mismatch"
    @test raw["deterministic_hash"] == canonical_hash(Dict{String,Any}(
        key => value for (key, value) in raw if key != "deterministic_hash"))
end
