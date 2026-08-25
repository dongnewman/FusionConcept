"Local fully-ionized Maxwellian fuel-state necessary-power screen."
struct FuelStateOperatingPointV1
    compiler_version::String
    fuel_declaration::String
    ion_temperature_kev::Float64
    electron_temperature_kev::Float64
    scalar_pressure_pa::Float64
    ion_number_fractions::Dict{String,Float64}
    electron_density_m3::Union{Nothing,Float64}
    ion_density_m3::Dict{String,Float64}
    channel_reaction_rate_density_m3_s::Dict{String,Float64}
    total_fusion_power_density_w_m3::Union{Nothing,Float64}
    charged_fusion_power_density_w_m3::Union{Nothing,Float64}
    neutral_fusion_power_density_w_m3::Union{Nothing,Float64}
    fuel_ion_bremsstrahlung_power_density_w_m3::Union{Nothing,Float64}
    total_fusion_to_bremsstrahlung_ratio::Union{Nothing,Float64}
    charged_fusion_to_bremsstrahlung_ratio::Union{Nothing,Float64}
    total_fusion_exceeds_fuel_bremsstrahlung::Union{Nothing,Bool}
    charged_self_heating_exceeds_fuel_bremsstrahlung::Union{Nothing,Bool}
    status::Symbol
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    operating_point_hash::String
end

"One Te/Ti slice of the bounded fuel-state necessary-condition envelope."
struct FuelStateThresholdV1
    electron_to_ion_temperature_ratio::Float64
    total_fusion_threshold_ion_temperature_kev::Union{Nothing,Float64}
    charged_self_heating_threshold_ion_temperature_kev::Union{Nothing,Float64}
    maximum_total_fusion_to_bremsstrahlung_ratio::Float64
    maximum_charged_fusion_to_bremsstrahlung_ratio::Float64
    total_threshold_status::Symbol
    charged_threshold_status::Symbol
end

"Temperature envelope for a fixed fuel mixture; topology and family labels are absent."
struct FuelStateAdmissibilityEnvelopeV1
    compiler_version::String
    fuel_declaration::String
    ion_number_fractions::Dict{String,Float64}
    minimum_ion_temperature_kev::Float64
    maximum_ion_temperature_kev::Float64
    thresholds::Vector{FuelStateThresholdV1}
    claim_ceiling::String
    promotion_authorized::Bool
    warnings::Vector{String}
    envelope_hash::String
end

function _normalized_fuel_v1(fuel::AbstractString)
    value = uppercase(replace(String(fuel), " " => ""))
    return value in ("D-D", "DD") ? "D-D" : value in ("D-T", "DT") ? "D-T" :
        String(fuel)
end

function _default_fuel_fractions_v1(fuel::String)
    fuel == "D-D" && return Dict("deuterium" => 1.0)
    fuel == "D-T" && return Dict("deuterium" => 0.5, "tritium" => 0.5)
    return Dict{String,Float64}()
end

function _validate_fuel_fractions_v1(fuel::String, raw)
    fractions = Dict{String,Float64}(String(k) => Float64(v) for (k, v) in raw)
    expected = fuel == "D-D" ? Set(["deuterium"]) :
        fuel == "D-T" ? Set(["deuterium", "tritium"]) : Set{String}()
    Set(keys(fractions)) == expected || throw(ArgumentError(
        "fuel fractions do not exactly cover the declared reactants"))
    all(value -> isfinite(value) && value >= 0.0, values(fractions)) ||
        throw(ArgumentError("fuel fractions must be finite and non-negative"))
    isapprox(sum(values(fractions)), 1.0; rtol = 1.0e-12, atol = 1.0e-12) ||
        throw(ArgumentError("fuel fractions must sum to one"))
    return fractions
end

function compile_fuel_state_operating_point_v1(fuel::AbstractString;
        ion_temperature_kev::Real, electron_temperature_kev::Real,
        scalar_pressure_pa::Real = 1.0,
        ion_number_fractions = nothing)
    normalized = _normalized_fuel_v1(fuel)
    ti = Float64(ion_temperature_kev)
    te = Float64(electron_temperature_kev)
    pressure = Float64(scalar_pressure_pa)
    all(isfinite, (ti, te, pressure)) || throw(ArgumentError(
        "fuel-state temperatures and pressure must be finite"))
    ti > 0.0 && te > 0.0 && pressure > 0.0 || throw(ArgumentError(
        "fuel-state temperatures and pressure must be positive"))
    channels = fusion_reaction_channels_v1(normalized)
    tasks = String[]
    warnings = String[
        "This is a local fully-ionized Maxwellian necessary-condition screen, not a heating, transport, burn, exhaust, or net-electric solution.",
        "Only fuel-ion bremsstrahlung is included; impurity, line, recombination, neutral, cyclotron, synchrotron, transport, and engineering losses remain unknown."]
    if isempty(channels)
        push!(tasks, "declare_supported_fusion_reaction_network:$normalized")
        core = Dict{String,Any}("compiler_version" =>
            "fuel_state_admissibility_compiler_v1.0.0",
            "fuel_declaration" => normalized, "ion_temperature_kev" => ti,
            "electron_temperature_kev" => te, "scalar_pressure_pa" => pressure,
            "ion_number_fractions" => Dict{String,Float64}(),
            "status" => "unknown", "evidence_tasks" => tasks,
            "warnings" => warnings)
        return FuelStateOperatingPointV1(
            "fuel_state_admissibility_compiler_v1.0.0", normalized, ti, te,
            pressure, Dict{String,Float64}(), nothing, Dict{String,Float64}(),
            Dict{String,Float64}(), nothing, nothing, nothing, nothing, nothing,
            nothing, nothing, nothing, :unknown, tasks, warnings,
            canonical_hash(core))
    end
    fractions = _validate_fuel_fractions_v1(normalized,
        ion_number_fractions === nothing ? _default_fuel_fractions_v1(normalized) :
            ion_number_fractions)
    registry = default_bosch_hale_coefficients_v1()
    in_domain = all(channel -> begin
        coefficients = registry[channel.channel_id]
        coefficients.minimum_temperature_kev <= ti <=
            coefficients.maximum_temperature_kev
    end, channels)
    if !in_domain
        push!(tasks, "resolve_reactivity_temperature_out_of_domain")
        core = Dict{String,Any}("compiler_version" =>
            "fuel_state_admissibility_compiler_v1.0.0",
            "fuel_declaration" => normalized, "ion_temperature_kev" => ti,
            "electron_temperature_kev" => te, "scalar_pressure_pa" => pressure,
            "ion_number_fractions" => fractions, "status" => "unknown",
            "evidence_tasks" => tasks, "warnings" => warnings)
        return FuelStateOperatingPointV1(
            "fuel_state_admissibility_compiler_v1.0.0", normalized, ti, te,
            pressure, fractions, nothing, Dict{String,Float64}(),
            Dict{String,Float64}(), nothing, nothing, nothing, nothing, nothing,
            nothing, nothing, nothing, :unknown, tasks, warnings,
            canonical_hash(core))
    end
    te_j = te * _REACTION_KEV_J_V1
    ti_j = ti * _REACTION_KEV_J_V1
    # D and T are singly charged, so ne equals total fuel-ion density.
    total_ion_density = pressure / (te_j + ti_j)
    densities = Dict(species => fraction * total_ion_density
        for (species, fraction) in fractions)
    rates = Dict{String,Float64}()
    total_power = 0.0
    charged_power = 0.0
    neutral_power = 0.0
    for channel in channels
        reactivity = bosch_hale_maxwellian_reactivity_v1(channel.channel_id, ti)
        rate = channel.identical_reactant_factor *
            densities[channel.reactant_a] * densities[channel.reactant_b] * reactivity
        rates[channel.channel_id] = rate
        for (product, energy) in channel.product_energy_j
            value = rate * energy
            total_power += value
            product == "neutron" ? (neutral_power += value) :
                (charged_power += value)
        end
    end
    te_ev = te * 1.0e3
    brems = 1.69e-38 * total_ion_density^2 * sqrt(te_ev)
    total_ratio = total_power / brems
    charged_ratio = charged_power / brems
    core = Dict{String,Any}("compiler_version" =>
        "fuel_state_admissibility_compiler_v1.0.0",
        "fuel_declaration" => normalized, "ion_temperature_kev" => ti,
        "electron_temperature_kev" => te, "scalar_pressure_pa" => pressure,
        "ion_number_fractions" => fractions,
        "electron_density_m3" => total_ion_density,
        "ion_density_m3" => densities,
        "channel_reaction_rate_density_m3_s" => rates,
        "total_fusion_power_density_w_m3" => total_power,
        "charged_fusion_power_density_w_m3" => charged_power,
        "neutral_fusion_power_density_w_m3" => neutral_power,
        "fuel_ion_bremsstrahlung_power_density_w_m3" => brems,
        "total_fusion_to_bremsstrahlung_ratio" => total_ratio,
        "charged_fusion_to_bremsstrahlung_ratio" => charged_ratio,
        "total_fusion_exceeds_fuel_bremsstrahlung" => total_ratio > 1.0,
        "charged_self_heating_exceeds_fuel_bremsstrahlung" => charged_ratio > 1.0,
        "status" => "pass", "evidence_tasks" => tasks,
        "warnings" => warnings)
    return FuelStateOperatingPointV1(
        "fuel_state_admissibility_compiler_v1.0.0", normalized, ti, te,
        pressure, fractions, total_ion_density, densities, rates, total_power,
        charged_power, neutral_power, brems, total_ratio, charged_ratio,
        total_ratio > 1.0, charged_ratio > 1.0, :pass, tasks, warnings,
        canonical_hash(core))
end

function _fuel_ratio_at_v1(fuel::String, ti::Float64, te_ti::Float64,
        fractions::Dict{String,Float64}, metric::Symbol)
    item = compile_fuel_state_operating_point_v1(fuel;
        ion_temperature_kev = ti, electron_temperature_kev = te_ti * ti,
        ion_number_fractions = fractions)
    item.status == :pass || return NaN
    return metric == :total ? something(
        item.total_fusion_to_bremsstrahlung_ratio) : something(
        item.charged_fusion_to_bremsstrahlung_ratio)
end

function _first_fuel_threshold_v1(fuel::String, te_ti::Float64,
        fractions::Dict{String,Float64}, minimum::Float64, maximum::Float64,
        metric::Symbol; sample_count::Int = 512, tolerance::Float64 = 1.0e-8)
    temperatures = exp.(range(log(minimum), log(maximum); length = sample_count))
    ratios = [_fuel_ratio_at_v1(fuel, value, te_ti, fractions, metric)
        for value in temperatures]
    maximum_ratio = Base.maximum(filter(isfinite, ratios))
    first_pass = findfirst(value -> isfinite(value) && value >= 1.0, ratios)
    first_pass === nothing && return (nothing, :not_reached, maximum_ratio)
    first_pass == 1 && return (minimum, :below_scan_floor, maximum_ratio)
    low = temperatures[first_pass - 1]
    high = temperatures[first_pass]
    for _ in 1:100
        high - low <= tolerance * max(high, 1.0) && break
        middle = (low + high) / 2.0
        ratio = _fuel_ratio_at_v1(fuel, middle, te_ti, fractions, metric)
        ratio >= 1.0 ? (high = middle) : (low = middle)
    end
    return (high, :crossed, maximum_ratio)
end

function compile_fuel_state_admissibility_envelope_v1(fuel::AbstractString;
        electron_to_ion_temperature_ratios = [0.2, 0.5, 1.0],
        minimum_ion_temperature_kev::Real = 0.2,
        maximum_ion_temperature_kev::Real = 100.0,
        ion_number_fractions = nothing)
    normalized = _normalized_fuel_v1(fuel)
    normalized in ("D-D", "D-T") || throw(ArgumentError(
        "fuel-state envelope supports D-D and D-T only"))
    minimum = Float64(minimum_ion_temperature_kev)
    maximum = Float64(maximum_ion_temperature_kev)
    0.2 <= minimum < maximum <= 100.0 || throw(ArgumentError(
        "fuel-state envelope must stay inside the 0.2--100 keV fit domain"))
    ratios = Float64.(electron_to_ion_temperature_ratios)
    !isempty(ratios) && all(value -> isfinite(value) && value > 0.0, ratios) ||
        throw(ArgumentError("Te/Ti ratios must be finite and positive"))
    fractions = _validate_fuel_fractions_v1(normalized,
        ion_number_fractions === nothing ? _default_fuel_fractions_v1(normalized) :
            ion_number_fractions)
    thresholds = FuelStateThresholdV1[]
    for ratio in ratios
        total_temperature, total_status, max_total = _first_fuel_threshold_v1(
            normalized, ratio, fractions, minimum, maximum, :total)
        charged_temperature, charged_status, max_charged = _first_fuel_threshold_v1(
            normalized, ratio, fractions, minimum, maximum, :charged)
        push!(thresholds, FuelStateThresholdV1(ratio, total_temperature,
            charged_temperature, max_total, max_charged, total_status,
            charged_status))
    end
    warnings = String[
        "Crossing unity is necessary but not sufficient: omitted radiation, transport, exhaust, auxiliary, recirculating, conversion, availability, and engineering terms can only reduce feasibility.",
        "The charged threshold addresses local fusion-product self-heating versus fuel bremsstrahlung; it is not an ignition criterion because all other plasma losses are absent.",
        "The total-fusion threshold is not a net-electric threshold and neutron energy does not directly self-heat the plasma."]
    core = Dict{String,Any}("compiler_version" =>
        "fuel_state_admissibility_compiler_v1.0.0",
        "fuel_declaration" => normalized,
        "ion_number_fractions" => fractions,
        "minimum_ion_temperature_kev" => minimum,
        "maximum_ion_temperature_kev" => maximum,
        "thresholds" => fuel_state_threshold_to_dict_v1.(thresholds),
        "claim_ceiling" => "C0_local_fuel_state_necessary_condition_only",
        "promotion_authorized" => false, "warnings" => warnings)
    return FuelStateAdmissibilityEnvelopeV1(
        "fuel_state_admissibility_compiler_v1.0.0", normalized, fractions,
        minimum, maximum, thresholds,
        "C0_local_fuel_state_necessary_condition_only", false, warnings,
        canonical_hash(core))
end

function fuel_state_operating_point_to_dict_v1(item::FuelStateOperatingPointV1)
    return Dict{String,Any}("compiler_version" => item.compiler_version,
        "fuel_declaration" => item.fuel_declaration,
        "ion_temperature_kev" => item.ion_temperature_kev,
        "electron_temperature_kev" => item.electron_temperature_kev,
        "scalar_pressure_pa" => item.scalar_pressure_pa,
        "ion_number_fractions" => item.ion_number_fractions,
        "electron_density_m3" => item.electron_density_m3,
        "ion_density_m3" => item.ion_density_m3,
        "channel_reaction_rate_density_m3_s" =>
            item.channel_reaction_rate_density_m3_s,
        "total_fusion_power_density_w_m3" => item.total_fusion_power_density_w_m3,
        "charged_fusion_power_density_w_m3" =>
            item.charged_fusion_power_density_w_m3,
        "neutral_fusion_power_density_w_m3" =>
            item.neutral_fusion_power_density_w_m3,
        "fuel_ion_bremsstrahlung_power_density_w_m3" =>
            item.fuel_ion_bremsstrahlung_power_density_w_m3,
        "total_fusion_to_bremsstrahlung_ratio" =>
            item.total_fusion_to_bremsstrahlung_ratio,
        "charged_fusion_to_bremsstrahlung_ratio" =>
            item.charged_fusion_to_bremsstrahlung_ratio,
        "total_fusion_exceeds_fuel_bremsstrahlung" =>
            item.total_fusion_exceeds_fuel_bremsstrahlung,
        "charged_self_heating_exceeds_fuel_bremsstrahlung" =>
            item.charged_self_heating_exceeds_fuel_bremsstrahlung,
        "status" => String(item.status), "evidence_tasks" => item.evidence_tasks,
        "warnings" => item.warnings,
        "operating_point_hash" => item.operating_point_hash)
end

function fuel_state_threshold_to_dict_v1(item::FuelStateThresholdV1)
    return Dict{String,Any}(
        "electron_to_ion_temperature_ratio" =>
            item.electron_to_ion_temperature_ratio,
        "total_fusion_threshold_ion_temperature_kev" =>
            item.total_fusion_threshold_ion_temperature_kev,
        "charged_self_heating_threshold_ion_temperature_kev" =>
            item.charged_self_heating_threshold_ion_temperature_kev,
        "maximum_total_fusion_to_bremsstrahlung_ratio" =>
            item.maximum_total_fusion_to_bremsstrahlung_ratio,
        "maximum_charged_fusion_to_bremsstrahlung_ratio" =>
            item.maximum_charged_fusion_to_bremsstrahlung_ratio,
        "total_threshold_status" => String(item.total_threshold_status),
        "charged_threshold_status" => String(item.charged_threshold_status))
end

function fuel_state_admissibility_envelope_to_dict_v1(
        item::FuelStateAdmissibilityEnvelopeV1)
    return Dict{String,Any}("compiler_version" => item.compiler_version,
        "fuel_declaration" => item.fuel_declaration,
        "ion_number_fractions" => item.ion_number_fractions,
        "minimum_ion_temperature_kev" => item.minimum_ion_temperature_kev,
        "maximum_ion_temperature_kev" => item.maximum_ion_temperature_kev,
        "thresholds" => fuel_state_threshold_to_dict_v1.(item.thresholds),
        "claim_ceiling" => item.claim_ceiling,
        "promotion_authorized" => item.promotion_authorized,
        "warnings" => item.warnings, "envelope_hash" => item.envelope_hash)
end
