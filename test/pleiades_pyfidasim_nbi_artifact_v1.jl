using Test
using JSON3
using SHA

@testset "Candidate-bound pyFIDASIM attenuation stays below source C2 v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    artifact_path = joinpath(root, "runs", "pleiades_pyfidasim_nbi_v1.json")
    input_path = joinpath(root, "knowledge", "pleiades_pyfidasim_nbi_input_v1.json")
    artifact = JSON3.read(read(artifact_path, String), Dict{String,Any})
    input = JSON3.read(read(input_path, String), Dict{String,Any})
    @test artifact["status"] == "pass"
    @test artifact["design_id"] == input["design_id"]
    @test artifact["genome_physics_hash"] == input["genome_physics_hash"]
    @test artifact["candidate_binding_verified"]
    @test artifact["neutral_density_field_computed"]
    @test !artifact["ionized_particle_deposition_rate_computed"]
    @test !artifact["charge_exchange_sink_rate_computed"]
    @test !artifact["nonlinear_multispecies_response_computed"]
    @test !artifact["ambipolar_profile_computed"]
    @test !artifact["c2_source_term_authorized"]
    @test !artifact["c2_kinetic_response_authorized"]
    @test artifact["gates"]["monte_carlo_inventory_convergence"]
    @test !artifact["gates"]["external_backend_license_resolved"]
    @test artifact["inventory_relative_change"] <=
        input["run_settings"]["maximum_inventory_relative_change"]
    @test [item["marker_count"] for item in artifact["observations"]] ==
        input["run_settings"]["marker_counts"]
    @test all(item -> item["density_nonzero_cell_count"] > 0,
        artifact["observations"])
    @test length(artifact["result_hash"]) == 64
    for record in artifact["source_artifacts"]
        path = joinpath(root, split(record["artifact_id"], '/')...)
        @test isfile(path)
        @test bytes2hex(sha256(read(path))) == record["artifact_hash"]
    end
end
