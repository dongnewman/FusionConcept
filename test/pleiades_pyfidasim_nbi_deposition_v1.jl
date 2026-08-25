using Test
using JSON3
using SHA

@testset "Field/actuator-bound pyFIDASIM deposition remains below C2 v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    run_path = joinpath(root, "runs", "pleiades_pyfidasim_nbi_deposition_v1.json")
    bridge_path = joinpath(root, "knowledge",
        "pleiades_pyfidasim_nbi_deposition_bridge_v1.json")
    run = JSON3.read(read(run_path, String), Dict{String,Any})
    bridge = JSON3.read(read(bridge_path, String), Dict{String,Any})
    fine = run["fine_result"]
    @test run["status"] == "pass"
    @test !run["candidate_binding_verified"]
    @test run["actuator_candidate_binding_verified"]
    @test run["field_candidate_binding_verified"]
    @test run["ionized_particle_deposition_rate_computed"]
    @test run["charge_exchange_conversion_rate_computed"]
    @test run["spatial_velocity_deposition_computed"]
    @test !run["charge_exchange_particle_loss_rate_computed"]
    @test !run["thermal_heating_deposition_computed"]
    @test !run["c2_source_term_authorized"]
    @test !run["c2_kinetic_response_authorized"]
    @test isapprox(fine["fast_ion_birth_rate_s"], fine["ionization_rate_s"] +
        fine["main_ion_charge_exchange_conversion_rate_s"]; rtol = 1.0e-12)
    @test fine["electron_source_rate_s"] == fine["ionization_rate_s"]
    @test fine["net_same_species_ion_source_rate_s"] == fine["ionization_rate_s"]
    @test fine["neutral_destruction_fraction"] <= 1.0
    @test length(fine["energy_groups"]) == 3
    @test !isempty(fine["spatial_velocity_rate_records"])
    @test all(item -> length(item) == 6, fine["spatial_velocity_rate_records"])
    @test run["gates"]["total_rate_resolution_converged"]
    @test run["gates"]["component_rates_resolution_converged"]
    @test !run["gates"]["plasma_profile_candidate_verified"]
    @test !run["gates"]["atomic_rate_table_applicability_verified"]
    @test !run["gates"]["beamline_geometry_candidate_verified"]
    @test !run["gates"]["spectrum_basis_candidate_verified"]
    @test bridge["summary"]["numeric_particle_source_term_count"] == 2
    @test bridge["summary"]["c2_authorized_particle_source_term_count"] == 0
    @test bridge["summary"]["charge_exchange_loss_term_count"] == 0
    @test bridge["summary"]["thermal_heating_term_count"] == 0
    @test all(item -> item["source_kind"] == "proxy" &&
        item["resolution_verified"] && !item["applicability_verified"] &&
        !item["c2_term_authorized"], bridge["coupled_balance_evidence"])
    @test Set(item["term_id"] for item in bridge["coupled_balance_evidence"]) == Set([
        "particle|pleiades_wham_isotropic_core|deuterium::external_particle_source",
        "particle|pleiades_wham_isotropic_core|electron::external_particle_source"])
    @test !bridge["mechanism_accounting"]["charge_exchange_particle_loss_term_mapped"]
    @test !bridge["mechanism_accounting"]["represented_fast_ion_birth_power_mapped_as_thermal_heating"]
    for record in run["source_artifacts"]
        path = joinpath(root, split(record["artifact_id"], '/')...)
        @test bytes2hex(sha256(read(path))) == record["artifact_hash"]
    end
end
