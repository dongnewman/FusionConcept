@testset "CQL3D public build and upstream regression v2" begin
    path = joinpath(@__DIR__, "..", "knowledge",
        "cql3d_public_build_regression_v2.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    @test raw["schema_version"] == "1.0.0"
    @test raw["commit"] == "3565fee6974deff69371321d8a053593eae1562d"
    @test raw["source_tree_hash"] == "209dce964ce32dcd3ddbb37809e18eeb20e064d7"
    @test raw["source_checkout_clean"]
    @test raw["gates"]["build_verified"]
    @test raw["gates"]["public_mainline_toroidal_regression_verified"]
    @test raw["regression"]["normal_completion_marker_verified"]
    @test raw["regression"]["netcdf_error_absent"]
    @test raw["regression"]["stderr_empty"]
    @test raw["regression"]["netcdf_types_verified"]
    @test raw["regression"]["sum_f_relative_error"] < 1.0e-9
    @test raw["regression"]["max_f_relative_error"] < 1.0e-9
    @test !raw["build"]["plotting_validated"]
    @test raw["build"]["adc_source_object_count"] == 16
    @test !raw["gates"]["mirror_regression_verified"]
    @test !raw["gates"]["exact_published_cql3d_m_equivalence_verified"]
    @test !raw["gates"]["candidate_solver_output_available"]
    @test !raw["gates"]["c2_kinetic_state_authorized"]
    @test raw["claim_ceiling"] == "public_mainline_build_and_toroidal_regression_only"
    @test raw["deterministic_hash"] == canonical_hash(Dict{String,Any}(
        key => value for (key, value) in raw if key != "deterministic_hash"))
end
