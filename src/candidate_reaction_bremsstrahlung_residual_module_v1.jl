const _DT_REACTION_CHANNEL_ID_V1 = "dt_to_alpha_neutron"
const _DT_ALPHA_ENERGY_J_V1 = 3.52e6 * _REACTION_ELECTRON_VOLT_J_V1
const _DT_NEUTRON_ENERGY_J_V1 = 14.06e6 * _REACTION_ELECTRON_VOLT_J_V1
const _FUEL_BREMS_COEFFICIENT_V1 = 1.69e-38

"Additive D-T burn, charged self-heating and fuel-ion bremsstrahlung block."
struct CandidateReactionBremsstrahlungModuleV1 <: AbstractResidualPhysicsModuleV1
    module_id::String
    region_id::String
    candidate_binding_hash::String
    plasma_volume_m3::Float64
    charge_a::Int
    charge_b::Int
    alpha_ion_fraction::Float64
    alpha_electron_fraction::Float64
    evidence_status::Dict{String,String}
    source_result_hash::String
end

function CandidateReactionBremsstrahlungModuleV1(; module_id, region_id,
        candidate_binding_hash, plasma_volume_m3, charge_a = 1, charge_b = 1,
        alpha_ion_fraction, alpha_electron_fraction, evidence_status,
        source_result_hash)
    volume = Float64(plasma_volume_m3)
    isfinite(volume) && volume > 0 || throw(ArgumentError(
        "reaction/radiation plasma volume must be positive and finite"))
    fi, fe = Float64(alpha_ion_fraction), Float64(alpha_electron_fraction)
    isapprox(fi + fe, 1.0; atol = 1.0e-10, rtol = 0.0) || throw(ArgumentError(
        "alpha deposition fractions must sum to one"))
    0.0 <= fi <= 1.0 && 0.0 <= fe <= 1.0 || throw(ArgumentError(
        "alpha deposition fractions must be bounded"))
    binding = _c2_check_hash_v1(String(candidate_binding_hash),
        "reaction/radiation candidate binding hash")
    result_hash = _c2_check_hash_v1(String(source_result_hash),
        "reaction/radiation source result hash")
    evidence = Dict{String,String}(String(key) => String(value)
        for (key, value) in evidence_status)
    return CandidateReactionBremsstrahlungModuleV1(String(module_id),
        String(region_id), binding, volume, Int(charge_a), Int(charge_b), fi, fe,
        evidence, result_hash)
end

residual_module_id(module_instance::CandidateReactionBremsstrahlungModuleV1) =
    module_instance.module_id

coupled_term_contract(::CandidateReactionBremsstrahlungModuleV1) = Dict{String,Any}(
    "expected_term_ids" => String[],
    "provided_term_ids" => ["fusion_reaction", "fuel_ion_bremsstrahlung"])

state_layout(::CandidateReactionBremsstrahlungModuleV1,
    ::CandidateSolveManifestV1) = StateBlockSpecV1[]

function residual_contracts(module_instance::CandidateReactionBremsstrahlungModuleV1,
        manifest::CandidateSolveManifestV1)
    rows = ["fuel_a_inventory", "fuel_b_inventory", "ion_thermal_energy",
        "electron_thermal_energy"]
    return [ResidualBlockContractV1(module_instance.module_id,
        "candidate_dt_reaction_bremsstrahlung", :additive, rows,
        ["particle/s", "particle/s", "W", "W"],
        ["fuel_a_inventory", "fuel_b_inventory", "electron_inventory",
            "ion_thermal_energy", "electron_thermal_energy"],
        [module_instance.region_id], String[], Dict{String,Any}[],
        ["fusion_burn", "charged_fusion_self_heating", "fuel_ion_bremsstrahlung"])]
end

function jacobian_contracts(module_instance::CandidateReactionBremsstrahlungModuleV1,
        manifest::CandidateSolveManifestV1)
    return [JacobianBlockContractV1(module_instance.module_id,
        "candidate_dt_reaction_bremsstrahlung", :analytic,
        ["fuel_a_inventory", "fuel_b_inventory", "ion_thermal_energy",
            "electron_thermal_energy"],
        ["fuel_a_inventory", "fuel_b_inventory", "electron_inventory",
            "ion_thermal_energy", "electron_thermal_energy"], 1.0e-5, 1.0e-8)]
end

mass_matrix_contracts(::CandidateReactionBremsstrahlungModuleV1,
    ::CandidateSolveManifestV1) = MassMatrixBlockContractV1[]

function validity_domain(module_instance::CandidateReactionBremsstrahlungModuleV1)
    required = ["alpha_partition", "candidate_binding", "fully_ionized_fuel",
        "isotropic_maxwellian_ions", "optically_thin_bremsstrahlung",
        "plasma_volume"]
    gaps = sort!(String[id for id in required
        if get(module_instance.evidence_status, id, "unknown") != "complete"])
    return Dict{String,Any}("status" => isempty(gaps) ? "applicable" : "unknown",
        "reason" => isempty(gaps) ? "candidate_bound_dt_reaction_domain_covered" :
            "reaction_radiation_evidence_incomplete:$(join(gaps, ","))",
        "fuel_declaration" => "D-T", "minimum_ion_temperature_keV" => 0.2,
        "maximum_ion_temperature_keV" => 100.0,
        "evidence_gaps" => gaps, "source_result_hash" => module_instance.source_result_hash)
end

function applicability(module_instance::CandidateReactionBremsstrahlungModuleV1,
        manifest::CandidateSolveManifestV1)
    manifest.physics_hash == module_instance.candidate_binding_hash || return
        Dict{String,Any}("status" => "unsupported",
            "reason" => "reaction_radiation_candidate_binding_mismatch")
    return validity_domain(module_instance)
end

function _bosch_hale_value_derivative_v1(channel_id::String, temperature_kev::Float64)
    item = default_bosch_hale_coefficients_v1()[channel_id]
    item.minimum_temperature_kev <= temperature_kev <=
        item.maximum_temperature_kev || return (NaN, NaN)
    c1, c2, c3, c4, c5, c6, c7 = item.coefficients
    t = temperature_kev
    a = c2 + t * (c4 + t * c6)
    da = c4 + 2.0 * t * c6
    b = 1.0 + t * (c3 + t * (c5 + t * c7))
    db = c3 + 2.0 * t * c5 + 3.0 * t^2 * c7
    denominator = 1.0 - t * a / b
    denominator > 0.0 || return (NaN, NaN)
    ddenominator = -(a / b + t * (da * b - a * db) / b^2)
    theta = t / denominator
    dtheta = (denominator - t * ddenominator) / denominator^2
    xi = (item.bg_sqrt_kev^2 / (4.0 * theta))^(1.0 / 3.0)
    value = c1 * theta * sqrt(xi / (item.mrc2_kev * t^3)) * exp(-3.0 * xi) * 1.0e-6
    derivative = value * (dtheta / theta * (5.0 / 6.0 + xi) - 1.5 / t)
    return value, derivative
end

function _candidate_reaction_state_v1(module_instance, u, context)
    index = context["state_index"]
    na = u[index["fuel_a_inventory"]]; nb = u[index["fuel_b_inventory"]]
    ne = u[index["electron_inventory"]]; wi = u[index["ion_thermal_energy"]]
    we = u[index["electron_thermal_energy"]]
    nion = na + nb
    ti_kev = 2.0 * wi / (3.0 * nion * _REACTION_KEV_J_V1)
    te_ev = 2.0 * we / (3.0 * ne * _REACTION_ELECTRON_VOLT_J_V1)
    reactivity, derivative = _bosch_hale_value_derivative_v1(
        _DT_REACTION_CHANNEL_ID_V1, ti_kev)
    burn = na * nb / module_instance.plasma_volume_m3 * reactivity
    charged_power = burn * _DT_ALPHA_ENERGY_J_V1
    neutral_power = burn * _DT_NEUTRON_ENERGY_J_V1
    charge_inventory = module_instance.charge_a^2 * na +
        module_instance.charge_b^2 * nb
    brems = _FUEL_BREMS_COEFFICIENT_V1 * ne * charge_inventory /
        module_instance.plasma_volume_m3 * sqrt(te_ev)
    return (; na, nb, ne, wi, we, nion, ti_kev, te_ev, reactivity, derivative,
        burn, charged_power, neutral_power, charge_inventory, brems)
end

function residual_block!(r, module_instance::CandidateReactionBremsstrahlungModuleV1,
        u, du, parameters, t, context)
    q = _candidate_reaction_state_v1(module_instance, u, context)
    all(isfinite, (q.burn, q.charged_power, q.neutral_power, q.brems)) ||
        throw(DomainError(q.ti_kev, "D-T reactivity state left the Bosch-Hale domain"))
    r[1] = q.burn
    r[2] = q.burn
    r[3] = -module_instance.alpha_ion_fraction * q.charged_power
    r[4] = q.brems - module_instance.alpha_electron_fraction * q.charged_power
    return r
end

function jacobian_block!(J,
        module_instance::CandidateReactionBremsstrahlungModuleV1,
        u, du, parameters, t, context)
    q = _candidate_reaction_state_v1(module_instance, u, context)
    volume = module_instance.plasma_volume_m3
    dti_dwi = 2.0 / (3.0 * q.nion * _REACTION_KEV_J_V1)
    dti_dn = -q.ti_kev / q.nion
    dburn_dna = q.nb / volume * q.reactivity + q.na * q.nb / volume *
        q.derivative * dti_dn
    dburn_dnb = q.na / volume * q.reactivity + q.na * q.nb / volume *
        q.derivative * dti_dn
    dburn_dwi = q.na * q.nb / volume * q.derivative * dti_dwi
    dbrems_dna = _FUEL_BREMS_COEFFICIENT_V1 * q.ne /
        volume * sqrt(q.te_ev) * module_instance.charge_a^2
    dbrems_dnb = _FUEL_BREMS_COEFFICIENT_V1 * q.ne /
        volume * sqrt(q.te_ev) * module_instance.charge_b^2
    dbrems_dne = 0.5 * q.brems / q.ne
    dbrems_dwe = 0.5 * q.brems / q.we
    J[1, 1] = dburn_dna; J[1, 2] = dburn_dnb; J[1, 4] = dburn_dwi
    J[2, 1] = dburn_dna; J[2, 2] = dburn_dnb; J[2, 4] = dburn_dwi
    alpha_i = module_instance.alpha_ion_fraction * _DT_ALPHA_ENERGY_J_V1
    alpha_e = module_instance.alpha_electron_fraction * _DT_ALPHA_ENERGY_J_V1
    J[3, 1] = -alpha_i * dburn_dna; J[3, 2] = -alpha_i * dburn_dnb
    J[3, 4] = -alpha_i * dburn_dwi
    J[4, 1] = dbrems_dna - alpha_e * dburn_dna
    J[4, 2] = dbrems_dnb - alpha_e * dburn_dnb
    J[4, 3] = dbrems_dne; J[4, 4] = -alpha_e * dburn_dwi
    J[4, 5] = dbrems_dwe
    return J
end

function observables(module_instance::CandidateReactionBremsstrahlungModuleV1,
        u, trajectory, context)
    q = _candidate_reaction_state_v1(module_instance, u, context)
    complete_radiation = get(module_instance.evidence_status,
        "complete_radiation_model", "unknown") == "complete"
    return Dict{String,Any}(
        "fuel_declaration" => "D-T", "ion_temperature_keV" => q.ti_kev,
        "electron_temperature_eV" => q.te_ev,
        "burn_rate_per_s" => q.burn,
        "charged_fusion_power_w" => q.charged_power,
        "neutral_fusion_power_w" => q.neutral_power,
        "total_fusion_power_w" => q.charged_power + q.neutral_power,
        "fuel_ion_bremsstrahlung_power_w" => q.brems,
        "complete_radiation_authorized" => complete_radiation,
        "claim_boundary" => complete_radiation ?
            "D-T Maxwellian Bosch-Hale burn, alpha self-heating and candidate-bound complete-radiation closure; the supplied evidence must show omitted channels are zero, not applicable, or included in the declared operating-point correction." :
            "D-T Maxwellian Bosch-Hale burn, alpha self-heating and fully-ionized optically-thin fuel-ion bremsstrahlung only; no line, recombination, neutral or cyclotron/synchrotron radiation.")
end

function power_ledger_contribution(
        module_instance::CandidateReactionBremsstrahlungModuleV1,
        u, trajectory, context)
    q = _candidate_reaction_state_v1(module_instance, u, context)
    complete_radiation = get(module_instance.evidence_status,
        "complete_radiation_model", "unknown") == "complete"
    return Dict{String,Any}(
        "role" => "fusion_reaction_and_radiation",
        "status" => complete_radiation ? "complete" : "unknown",
        "provided_term_ids" => ["fusion_reaction", "fuel_ion_bremsstrahlung"],
        "unresolved_roles" => complete_radiation ? String[] : ["complete_radiation_model"],
        "terms" => Dict{String,Any}(
            "total_fusion_power_w" => q.charged_power + q.neutral_power,
            "charged_fusion_power_w" => q.charged_power,
            "neutral_fusion_power_w" => q.neutral_power,
            "radiation_power_w" => q.brems),
        "source_result_hash" => module_instance.source_result_hash)
end
