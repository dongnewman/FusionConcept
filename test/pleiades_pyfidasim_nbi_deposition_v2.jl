using Test
using JSON3
using SHA

@testset "Executable-source pyFIDASIM deposition remains below C2 v2" begin
    root = normpath(joinpath(@__DIR__, ".."))
    v1 = JSON3.read(read(joinpath(root, "runs",
        "pleiades_pyfidasim_nbi_deposition_v1.json"), String), Dict{String,Any})
    v2 = JSON3.read(read(joinpath(root, "runs",
        "pleiades_pyfidasim_nbi_deposition_v2.json"), String), Dict{String,Any})
    bridge = JSON3.read(read(joinpath(root, "knowledge",
        "pleiades_pyfidasim_nbi_deposition_bridge_v2.json"), String), Dict{String,Any})
    @test v2["status"] == "pass"
    @test v2["candidate_binding_verified"]
    @test v2["candidate_geometry_binding_verified"]
    @test v2["candidate_spectrum_semantics_binding_verified"]
    @test v2["cross_language_backend_input_hash_verified"]
    @test !v2["published_beamline_geometry_verified"]
    @test !v2["published_spectrum_fraction_basis_verified"]
    @test v2["gates"]["beamline_geometry_candidate_verified"]
    @test v2["gates"]["spectrum_basis_candidate_verified"]
    @test !v2["gates"]["plasma_profile_candidate_verified"]
    @test !v2["gates"]["atomic_rate_table_applicability_verified"]
    @test !v2["c2_source_term_authorized"]
    @test !v2["c2_kinetic_response_authorized"]
    @test v2["incident_spectrum"]["component_basis"] ==
        "neutral_particle_number_fraction"
    for key in ("ionization_rate_s", "main_ion_charge_exchange_conversion_rate_s",
            "fast_ion_birth_rate_s", "neutral_destruction_fraction")
        @test isapprox(v2["fine_result"][key], v1["fine_result"][key]; rtol = 1.0e-12)
    end
    @test length(v2["fine_result"]["spatial_velocity_rate_records"]) ==
        length(v1["fine_result"]["spatial_velocity_rate_records"])
    @test !("move_beamline_source_target_and_apertures_into_executable_genome" in
        v2["evidence_tasks"])
    @test !("verify_energy_group_fraction_basis_in_candidate_ir" in
        v2["evidence_tasks"])
    @test bridge["source_binding"]["candidate_binding_verified"]
    @test bridge["source_binding"]["cross_language_backend_input_hash_verified"]
    @test bridge["summary"]["resolved_candidate_binding_task_count"] == 2
    @test bridge["summary"]["numeric_particle_source_term_count"] == 2
    @test bridge["summary"]["c2_authorized_particle_source_term_count"] == 0
    @test bridge["summary"]["unknown_coupled_equation_count"] == 3
    @test all(item -> item["source_kind"] == "proxy" &&
        !item["c2_term_authorized"], bridge["coupled_balance_evidence"])
    for record in v2["source_artifacts"]
        path = joinpath(root, split(record["artifact_id"], '/')...)
        @test bytes2hex(SHA.sha256(read(path))) == record["artifact_hash"]
    end
    for record in bridge["source_artifacts"]
        path = joinpath(root, split(record["artifact_id"], '/')...)
        @test bytes2hex(SHA.sha256(read(path))) == record["artifact_hash"]
    end
end
