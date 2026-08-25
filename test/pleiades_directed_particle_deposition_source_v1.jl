@testset "Pleiades directed particle deposition source v1" begin
    path = joinpath(@__DIR__, "..", "knowledge",
        "pleiades_directed_particle_deposition_source_v1.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    observation = raw["observation"]
    summary = raw["summary"]
    bins = observation["bins"]
    @test raw["schema_version"] == "1.0.0"
    @test raw["deterministic_hash"] == canonical_hash(Dict{String,Any}(
        key => value for (key, value) in raw if key != "deterministic_hash"))
    @test length(bins) == 618 == observation["bin_count"]
    @test observation["candidate_phase_space_binding_verified"]
    @test observation["external_aggregate_audit_verified"]
    @test observation["physical_source_rate_available"]
    @test !observation["c2_phase_space_source_authorized"]
    @test !observation["c2_kinetic_state_authorized"]
    @test Float64(observation["maximum_external_aggregate_relative_residual"]) < 1e-10
    @test Float64(observation["fast_ion_birth_rate_s"]) ≈
        Float64(observation["ionization_rate_s"]) +
        Float64(observation["charge_exchange_conversion_rate_s"]) rtol=1e-12
    @test Float64(observation["electron_birth_rate_s"]) ==
        Float64(observation["ionization_rate_s"])
    @test Float64(observation["net_same_species_ion_birth_rate_s"]) ==
        Float64(observation["ionization_rate_s"])
    @test Float64(observation["thermal_same_species_ion_removal_rate_s"]) ==
        Float64(observation["charge_exchange_conversion_rate_s"])
    @test Float64(summary["signed_pitch_cosine_min"]) < 0.0
    @test Float64(summary["signed_pitch_cosine_max"]) > 0.0
    @test all(0.0 <= Float64(bin["pitch_angle_rad"]) <= pi for bin in bins)
    @test any(Float64(bin["parallel_speed_m_s"]) < 0.0 for bin in bins)
    @test any(Float64(bin["parallel_speed_m_s"]) > 0.0 for bin in bins)
    @test "solve_multispecies_nonlinear_bounce_averaged_fokker_planck" in
        String.(observation["evidence_tasks"])
    @test raw["claim_ceiling"] == "candidate_bound_si_phase_space_source_tensor"
    @test length(raw["coupled_balance_evidence"]) == 2
    @test count(item -> Bool(item["c2_term_authorized"]),
        raw["coupled_balance_evidence"]) == 0
    @test summary["unknown_coupled_equation_count"] == 3
    @test summary["charge_exchange_thermal_sink_term_count"] == 0
    @test summary["thermal_heating_term_count"] == 0
    @test summary["complete_c2_count"] == 0
end
