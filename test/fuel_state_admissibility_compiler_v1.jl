using Test
using FusionConceptAI

@testset "Local fuel-state power partition and pressure invariance v1" begin
    dd = compile_fuel_state_operating_point_v1("D-D";
        ion_temperature_kev = 10.0, electron_temperature_kev = 5.0)
    @test dd.status == :pass
    @test isapprox(dd.total_fusion_to_bremsstrahlung_ratio,
        0.2882055528945568; rtol = 1.0e-12)
    @test !dd.total_fusion_exceeds_fuel_bremsstrahlung
    @test !dd.charged_self_heating_exceeds_fuel_bremsstrahlung
    @test isapprox(dd.total_fusion_power_density_w_m3,
        dd.charged_fusion_power_density_w_m3 +
            dd.neutral_fusion_power_density_w_m3; rtol = 1.0e-14)
    @test length(dd.channel_reaction_rate_density_m3_s) == 2

    scaled = compile_fuel_state_operating_point_v1("D-D";
        ion_temperature_kev = 10.0, electron_temperature_kev = 5.0,
        scalar_pressure_pa = 1.0e5)
    @test isapprox(scaled.total_fusion_to_bremsstrahlung_ratio,
        dd.total_fusion_to_bremsstrahlung_ratio; rtol = 1.0e-14)
    @test isapprox(scaled.charged_fusion_to_bremsstrahlung_ratio,
        dd.charged_fusion_to_bremsstrahlung_ratio; rtol = 1.0e-14)
    @test isapprox(scaled.electron_density_m3 / dd.electron_density_m3,
        1.0e5; rtol = 1.0e-14)
    @test isapprox(scaled.total_fusion_power_density_w_m3 /
        dd.total_fusion_power_density_w_m3, 1.0e10; rtol = 1.0e-13)

    dt_equal = compile_fuel_state_operating_point_v1("D-T";
        ion_temperature_kev = 10.0, electron_temperature_kev = 5.0)
    dt_skewed = compile_fuel_state_operating_point_v1("D-T";
        ion_temperature_kev = 10.0, electron_temperature_kev = 5.0,
        ion_number_fractions = Dict("deuterium" => 0.8, "tritium" => 0.2))
    @test dt_equal.total_fusion_to_bremsstrahlung_ratio >
        dt_skewed.total_fusion_to_bremsstrahlung_ratio
    @test dt_equal.charged_fusion_to_bremsstrahlung_ratio <
        dt_equal.total_fusion_to_bremsstrahlung_ratio
    @test_throws ArgumentError compile_fuel_state_operating_point_v1("D-T";
        ion_temperature_kev = 10.0, electron_temperature_kev = 5.0,
        ion_number_fractions = Dict("deuterium" => 1.0))
end

@testset "Reactivity domain and unsupported fuel remain unknown v1" begin
    cold = compile_fuel_state_operating_point_v1("D-D";
        ion_temperature_kev = 0.1, electron_temperature_kev = 0.1)
    @test cold.status == :unknown
    @test cold.total_fusion_power_density_w_m3 === nothing
    @test "resolve_reactivity_temperature_out_of_domain" in cold.evidence_tasks
    unsupported = compile_fuel_state_operating_point_v1("p-B11";
        ion_temperature_kev = 20.0, electron_temperature_kev = 10.0)
    @test unsupported.status == :unknown
    @test unsupported.electron_density_m3 === nothing
    @test any(contains("declare_supported_fusion_reaction_network"),
        unsupported.evidence_tasks)
end

@testset "D-D and D-T necessary temperature envelopes v1" begin
    dd = compile_fuel_state_admissibility_envelope_v1("D-D")
    dt = compile_fuel_state_admissibility_envelope_v1("D-T")
    @test !dd.promotion_authorized
    @test !dt.promotion_authorized
    @test dd.claim_ceiling == "C0_local_fuel_state_necessary_condition_only"
    @test length(dd.thresholds) == length(dt.thresholds) == 3
    @test all(item.total_threshold_status == :crossed for item in dd.thresholds)
    @test all(item.charged_threshold_status == :crossed for item in dd.thresholds)
    @test all(item.charged_self_heating_threshold_ion_temperature_kev >
        item.total_fusion_threshold_ion_temperature_kev for item in dd.thresholds)
    @test all(item.charged_self_heating_threshold_ion_temperature_kev >
        item.total_fusion_threshold_ion_temperature_kev for item in dt.thresholds)
    @test isapprox(dd.thresholds[2].total_fusion_threshold_ion_temperature_kev,
        22.443154806970714; rtol = 1.0e-8)
    @test isapprox(dd.thresholds[2].charged_self_heating_threshold_ion_temperature_kev,
        33.01498625746049; rtol = 1.0e-8)
    @test isapprox(dt.thresholds[2].total_fusion_threshold_ion_temperature_kev,
        2.5044864261728472; rtol = 1.0e-8)
    @test isapprox(dt.thresholds[2].charged_self_heating_threshold_ion_temperature_kev,
        3.873481680312067; rtol = 1.0e-8)
    @test all(dt.thresholds[index].charged_self_heating_threshold_ion_temperature_kev <
        dd.thresholds[index].charged_self_heating_threshold_ion_temperature_kev
        for index in eachindex(dd.thresholds))
    @test_throws ArgumentError compile_fuel_state_admissibility_envelope_v1(
        "D-D"; maximum_ion_temperature_kev = 101.0)
end
