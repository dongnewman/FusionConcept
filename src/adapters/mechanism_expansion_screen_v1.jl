const _MEV10_SCREEN_CLAIM_BOUNDARY =
    "Fidelity-0 mechanism-expansion rejection screen. The v9 controls retain their " *
    "sealed proxy equations and receive a rejection-only PF failure label. Tandem-mirror " *
    "barriers use a capped analytic end-loss allocation, explicit beam/ECH power, unresolved " *
    "MHD and trapped-particle gates, and optional recovery of charged end loss only. The " *
    "sheared-flow Z-pinch branch uses a cylindrical pulsed inventory, explicit flow power, " *
    "the mode-specific 0.1 normalized-shear rejection threshold, a separate m=0 profile gate, " *
    "finite electrodes and two end targets. Passing establishes neither equilibrium, all-mode " *
    "stability, transport, component lifetime, net electricity, nor superiority."

const _MEV10_SOURCE_BASIS = String[
    "zpinch_shear_shumlak_hartman_1995",
    "fuze_neutron_zhang_2019",
    "tandem_pic_caneses_marin_2025",
    "tandem_high_field_frank_2025",
    "kinetic_stabilizer_post_2004",
    "mars_engineering_henning_1986",
]

"Independent v10 wrapper; v5-v9 evaluators and sealed artifacts remain unchanged."
struct MechanismExpansionScreenV1 <: AbstractEvaluator
    contract::SharedOuterEnvelopeContractV1
    allowed_contract_hashes::Set{String}
end

function MechanismExpansionScreenV1(contract::SharedOuterEnvelopeContractV1;
        allowed_contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    hashes = Set(canonical_hash(_oe_contract_dict(item)) for item in allowed_contracts)
    return MechanismExpansionScreenV1(contract, hashes)
end

function evaluator_spec(::MechanismExpansionScreenV1)
    return EvaluatorSpec("mechanism_expansion_screen_v1", "1.0.0",
        ["tokamak_axisymmetric", "tokamak_3d_hybrid", "stellarator",
            "magnetic_mirror", "sheared_flow_z_pinch",
            "field_reversed_configuration", "spheromak"], 0,
        Dict(
            "topology_compatibility" => :proxy,
            "equilibrium" => :proxy, "stability" => :proxy,
            "particle_loss" => :proxy, "power_balance" => :proxy,
            "pf_failure_prescreen" => :proxy,
            "electrostatic_plug" => :proxy,
            "kinetic_stabilizer" => :proxy,
            "direct_energy_conversion" => :proxy,
            "resistive_mhd_with_axial_flow" => :proxy,
            "coaxial_accelerator_and_electrode_model" => :proxy,
            "finite_build" => :proxy, "exhaust" => :proxy,
            "manufacturing_tolerance" => :proxy,
        ), _MEV10_SCREEN_CLAIM_BOUNDARY)
end

function evaluator_applicability(evaluator::MechanismExpansionScreenV1,
        genome::Genome)
    genome.family in evaluator_spec(evaluator).families || return false,
        "mechanism expansion v10 does not cover family $(genome.family)"
    genome.mission.fuel == "D-T" || return false,
        "mechanism expansion v10 is restricted to D-T"
    family = validate_family(default_family_registry(), genome)
    family.valid || return false, join(family.errors, "; ")
    return true, "mechanism expansion under $(evaluator.contract.id)"
end

_mev10_target(genome::Genome, name::String, default::Real, unit::String) =
    _oe_target(genome, name, default, unit)

function _mev10_value(genome::Genome, values, name::String, default::Real,
        unit::String)
    values !== nothing && haskey(values, name) && return Float64(values[name])
    return _mev10_target(genome, name, default, unit)
end

function _mev10_mechanism(genome::Genome)
    genome.family == "sheared_flow_z_pinch" && return
        _mev10_target(genome, "screen_z_repetition_rate", 0.0, "Hz") > 0.0 ?
            "sheared_flow_repetitive_z_pinch" : "sheared_flow_single_pulse_z_pinch"
    potential = _mev10_target(genome, "screen_tandem_potential_ratio", 0.0, "1")
    stabilizer = _mev10_target(genome,
        "screen_kinetic_stabilizer_pressure_fraction", 0.0, "1")
    if genome.family == "magnetic_mirror" && (potential > 0.0 || stabilizer > 0.0)
        prefix = potential > 0.0 && stabilizer > 0.0 ? "thermal_barrier_plus_kinetic" :
            potential > 0.0 ? "thermal_electrostatic_barrier" : "kinetic_stabilizer"
        recovery = _mev10_target(genome,
            "screen_direct_converter_recovery_fraction", 0.0, "1")
        return recovery > 0.0 ? "$(prefix)_with_direct_converter" : prefix
    end
    return _ccv9_stability_drive(genome)
end

function _mev10_pf_failure_label(features,
        contract::SharedOuterEnvelopeContractV1)
    scored = merge(features, (family = "tokamak_axisymmetric",))
    geometry = _oe_geometry(scored, contract)
    base = contract.base
    pack = features.coil_pack_thickness_m
    support = features.support_thickness_m
    inner_radius = geometry.R - geometry.a -
        (base.shield_thickness_m + base.maintenance_gap_m + 0.5 * pack)
    plasma_current_A = 1.0e6 * _oe_plasma_current_MA(scored, geometry, contract)
    optimistic_pf_current_A_turn = 0.60 * plasma_current_A
    safe_inner_radius = max(inner_radius, 1.0e-6)
    tf_at_inner = contract.plasma_field_T * geometry.R / safe_inner_radius
    local_self = 4.0e-7 * pi * optimistic_pf_current_A_turn /
        (pi * max(pack, 1.0e-6))
    additive_peak = tf_at_inner + local_self
    magnetic_pressure = additive_peak^2 / (2.0 * 4.0e-7 * pi)
    membrane_stress = magnetic_pressure * max(inner_radius, 0.0) /
        max(support, 1.0e-6)
    margins = Dict{String,Float64}(
        "v9_pf_inner_centerline" => inner_radius /
            max(contract.outer_radial_extent_m, 1.0e-9),
        "v9_pf_optimistic_additive_peak_field" =>
            (base.peak_conductor_field_limit_T - additive_peak) /
            base.peak_conductor_field_limit_T,
        "v9_pf_optimistic_membrane_support_stress" =>
            (base.support_stress_limit_Pa - membrane_stress) /
            base.support_stress_limit_Pa,
    )
    return Dict{String,Any}(
        "status" => all(>=(0.0), Base.values(margins)) ? "pass_unresolved" : "reject",
        "v9_review_result_hash" =>
            "41b8341e19f440e58a75320a1f53d9da281086a5c27d9c00c96710b61cc0caa4",
        "observed_parent_count" => 6,
        "observed_refined_completed_count" => 11,
        "observed_failure_counts" => Dict(
            "pf_membrane_support_stress_proxy" => 9,
            "pf_additive_peak_field_proxy" => 8),
        "optimistic_pf_current_fraction_of_plasma_current" => 0.60,
        "inner_pf_centerline_radius_m" => inner_radius,
        "optimistic_pf_current_A_turn" => optimistic_pf_current_A_turn,
        "additive_peak_field_proxy_T" => additive_peak,
        "membrane_support_stress_proxy_Pa" => membrane_stress,
        "margins" => margins,
        "claim_boundary" => "rejection-only optimistic prescreen derived from the sealed v9 review",
    )
end

function _mev10_add_pf_label!(nominal::Dict{String,Any}, features,
        contract::SharedOuterEnvelopeContractV1)
    label = _mev10_pf_failure_label(features, contract)
    merge!(nominal["margins"], label["margins"])
    nominal["v9_pf_failure_label"] = label
    nominal["engineering_gate_passed"] = nominal["engineering_gate_passed"] === true &&
        all(>=(0.0), Base.values(label["margins"]))
    nominal["minimum_normalized_margin"] = minimum(Base.values(nominal["margins"]))
    return nominal
end

function _mev10_mirror_nominal(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features, values = nothing;
        field_multiplier::Float64 = 1.0,
        beta_multiplier::Float64 = 1.0,
        dimension_multiplier::Float64 = 1.0,
        field_quality_penalty::Float64 = 0.0,
        actuator_multiplier::Float64 = 1.0,
        target_area_multiplier::Float64 = 1.0,
        potential_multiplier::Float64 = 1.0,
        stabilizer_multiplier::Float64 = 1.0,
        converter_multiplier::Float64 = 1.0)
    nominal = _ccv9_nominal(genome, contract, features;
        field_multiplier = field_multiplier,
        beta_multiplier = beta_multiplier,
        dimension_multiplier = dimension_multiplier,
        field_quality_penalty = field_quality_penalty,
        actuator_multiplier = actuator_multiplier,
        target_area_multiplier = target_area_multiplier)
    potential_ratio = max(0.0, potential_multiplier * _mev10_value(genome,
        values, "screen_tandem_potential_ratio", 0.0, "1"))
    stabilizer_fraction = max(0.0, stabilizer_multiplier * _mev10_value(genome,
        values, "screen_kinetic_stabilizer_pressure_fraction", 0.0, "1"))
    (potential_ratio > 0.0 || stabilizer_fraction > 0.0) || return nominal

    density_ratio = _mev10_value(genome, values,
        "screen_tandem_plug_density_ratio", 1.0, "1")
    beam_energy_keV = _mev10_value(genome, values,
        "screen_tandem_beam_energy", 0.0, "J") / 1.602176634e-16
    plug_beam_power = _mev10_value(genome, values,
        "screen_tandem_beam_power", 0.0, "W")
    ech_power = _mev10_value(genome, values,
        "screen_tandem_ech_power", 0.0, "W")
    replenish_time = _mev10_value(genome, values,
        "screen_kinetic_stabilizer_replenishment_time", 0.05, "s")
    recovery_fraction = clamp(converter_multiplier * _mev10_value(genome,
        values, "screen_direct_converter_recovery_fraction", 0.0, "1"), 0.0, 0.50)
    converter_voltage = _mev10_value(genome, values,
        "screen_direct_converter_voltage", 0.0, "V")
    converter_build = _mev10_value(genome, values,
        "screen_direct_converter_build", 0.0, "m")

    # Allocate, rather than erase, the v9 transport loss. The 35% floor is an
    # explicit conservative cross-field/unresolved-loss share. No PIC result is
    # imported as a performance multiplier.
    base_loss = Float64(nominal["transport_loss_power_W"])
    end_loss_share = 0.65 * base_loss
    end_loss_after_barrier = end_loss_share * exp(-potential_ratio)
    effective_loss = 0.35 * base_loss + end_loss_after_barrier
    base_particle_loss = Float64(nominal["particle_loss_fraction_proxy"])
    particle_loss = base_particle_loss * (0.35 + 0.65 * exp(-potential_ratio))
    stabilizer_inventory = stabilizer_fraction * nominal["pressure_Pa"] *
        nominal["plasma_volume_m3"]
    stabilizer_power = stabilizer_fraction > 0.0 ?
        stabilizer_inventory / max(replenish_time, 1.0e-6) : 0.0
    declared_actuator = Float64(nominal["declared_actuator_power_W"])
    explicit_actuator_requirement = plug_beam_power + ech_power + stabilizer_power
    transport_auxiliary = max(0.0, effective_loss - nominal["alpha_power_W"])
    charged_actuator_power = max(declared_actuator, explicit_actuator_requirement)
    total_auxiliary = transport_auxiliary + charged_actuator_power
    recovered_electric = recovery_fraction * end_loss_after_barrier
    net_power = contract.base.thermal_conversion_efficiency *
        nominal["fusion_power_W"] + recovered_electric -
        total_auxiliary / contract.base.heating_wall_plug_efficiency -
        contract.base.fixed_balance_of_plant_load_W
    fusion_gain = nominal["fusion_power_W"] / max(total_auxiliary, 1.0)
    margins = nominal["margins"]
    target_area = Float64(nominal["effective_target_area_m2"])
    exhaust_heat_flux = end_loss_after_barrier / max(target_area, 1.0e-9)
    margins["particle_loss"] = (0.25 - particle_loss) / 0.25
    margins["exhaust_target_heat_flux"] =
        (contract.maximum_exhaust_heat_flux_W_m2 - exhaust_heat_flux) /
        contract.maximum_exhaust_heat_flux_W_m2
    if potential_ratio > 0.0
        required_density_ratio = exp(potential_ratio)
        margins["tandem_potential_domain"] = min((potential_ratio - 0.5) / 0.5,
            (3.0 - potential_ratio) / 0.5)
        margins["tandem_plug_density_consistency"] =
            (density_ratio - required_density_ratio) / required_density_ratio
        required_beam_energy = potential_ratio * features.temperature_keV
        margins["tandem_beam_energy_authority"] =
            (beam_energy_keV - required_beam_energy) / max(required_beam_energy, 1.0)
        margins["tandem_trapped_particle_screen"] = min(
            (features.field_quality - 0.90) / 0.10,
            (features.minimum_b_strength - 0.60) / 0.40)
    end
    if stabilizer_fraction > 0.0
        margins["kinetic_stabilizer_pressure_inventory"] = min(
            (stabilizer_fraction - 0.03) / 0.03,
            (0.25 - stabilizer_fraction) / 0.10)
        margins["kinetic_stabilizer_replenishment"] =
            (declared_actuator - explicit_actuator_requirement) /
            contract.base.auxiliary_heating_budget_W
    end
    margins["tandem_explicit_actuator_authority"] =
        (declared_actuator - explicit_actuator_requirement) /
        contract.base.auxiliary_heating_budget_W
    if recovery_fraction > 0.0
        grid_field = converter_voltage / max(converter_build, 1.0e-6)
        margins["direct_converter_recovery_domain"] = min(
            recovery_fraction / 0.50, (0.50 - recovery_fraction) / 0.25)
        margins["direct_converter_grid_field"] = (20.0e6 - grid_field) / 20.0e6
        margins["direct_converter_energy_conservation"] =
            (end_loss_after_barrier - recovered_electric) /
            max(end_loss_after_barrier, 1.0)
    end
    margins["fusion_gain"] = fusion_gain - 1.0
    margins["auxiliary_power"] =
        (contract.base.auxiliary_heating_budget_W - total_auxiliary) /
        contract.base.auxiliary_heating_budget_W
    margins["net_electric_power"] = net_power /
        max(contract.base.fixed_balance_of_plant_load_W, 1.0)
    nominal["transport_loss_power_W"] = effective_loss
    nominal["unmitigated_v9_transport_loss_power_W"] = base_loss
    nominal["charged_end_loss_power_W"] = end_loss_after_barrier
    nominal["particle_loss_fraction_proxy"] = particle_loss
    nominal["exhaust_heat_flux_W_m2"] = exhaust_heat_flux
    nominal["required_auxiliary_power_W"] = total_auxiliary
    nominal["explicit_mechanism_actuator_requirement_W"] =
        explicit_actuator_requirement
    nominal["charged_actuator_power_W"] = charged_actuator_power
    nominal["kinetic_stabilizer_replenishment_power_W"] = stabilizer_power
    nominal["fusion_gain_proxy"] = fusion_gain
    nominal["direct_converter_recovered_electric_power_W"] = recovered_electric
    nominal["net_electric_power_W"] = net_power
    nominal["tandem_potential_ratio"] = potential_ratio
    nominal["tandem_plug_density_ratio"] = density_ratio
    nominal["kinetic_stabilizer_pressure_fraction"] = stabilizer_fraction
    nominal["direct_converter_recovery_fraction"] = recovery_fraction
    nominal["experimental_performance_multiplier_used"] = false
    physics_ids = ["temperature_domain", "stability", "particle_loss",
        "fusion_gain", "auxiliary_power", "net_electric_power",
        "tandem_explicit_actuator_authority"]
    potential_ratio > 0.0 && append!(physics_ids,
        ["tandem_potential_domain", "tandem_plug_density_consistency",
            "tandem_beam_energy_authority", "tandem_trapped_particle_screen"])
    stabilizer_fraction > 0.0 && append!(physics_ids,
        ["kinetic_stabilizer_pressure_inventory",
            "kinetic_stabilizer_replenishment"])
    engineering_ids = ["peak_conductor_field", "engineering_current_density",
        "support_stress", "outer_radial_envelope", "outer_axial_envelope",
        "inboard_build", "coil_curvature", "neutron_wall_load",
        "exhaust_target_heat_flux", "finite_exhaust_and_voltage_build"]
    recovery_fraction > 0.0 && append!(engineering_ids,
        ["direct_converter_recovery_domain", "direct_converter_grid_field",
            "direct_converter_energy_conservation"])
    nominal["physics_gate_passed"] = all(margins[id] >= 0.0 for id in physics_ids)
    nominal["engineering_gate_passed"] =
        all(margins[id] >= 0.0 for id in engineering_ids)
    nominal["minimum_normalized_margin"] = minimum(Base.values(margins))
    nominal["composition"] = Dict(
        "core_family" => "magnetic_mirror",
        "stability_or_sustainment" => _mev10_mechanism(genome),
        "exhaust_topology" => recovery_fraction > 0.0 ?
            "two_end_direct_converter" : "two_end_expander",
        "end_loss_suppression_model" =>
            "35_percent_floor_plus_65_percent_exp_minus_phi_over_T",
    )
    return nominal
end

function _mev10_z_geometry(genome::Genome, features,
        contract::SharedOuterEnvelopeContractV1, values = nothing;
        dimension_multiplier::Float64 = 1.0)
    wall = _mev10_value(genome, values, "screen_z_wall_thickness", 0.25, "m")
    electrode = _mev10_value(genome, values,
        "screen_z_electrode_build", 0.25, "m")
    build = contract.base.shield_thickness_m + contract.base.maintenance_gap_m +
        wall + electrode
    radial_capacity = contract.outer_radial_extent_m - build
    axial_capacity = contract.outer_axial_half_extent_m - build
    aspect = max(features.shape_ratio, 1.0)
    fill = features.plasma_fill_fraction * dimension_multiplier
    radius = max(0.01, fill * min(radial_capacity, axial_capacity / aspect))
    half_length = aspect * radius
    volume = 2.0 * pi * radius^2 * half_length
    wall_area = 4.0 * pi * radius * half_length + 2.0 * pi * radius^2
    return (a = radius, c = half_length, volume = volume, area = wall_area,
        build = build,
        radial_margin = contract.outer_radial_extent_m - radius - build,
        axial_margin = contract.outer_axial_half_extent_m - half_length - build,
        wall_thickness = wall, electrode_build = electrode)
end

function _mev10_z_nominal(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features, values = nothing;
        field_multiplier::Float64 = 1.0,
        beta_multiplier::Float64 = 1.0,
        dimension_multiplier::Float64 = 1.0,
        actuator_multiplier::Float64 = 1.0,
        target_area_multiplier::Float64 = 1.0,
        shear_multiplier::Float64 = 1.0,
        efficiency_multiplier::Float64 = 1.0)
    mu0 = 4.0e-7 * pi
    elementary_charge = 1.602176634e-19
    ion_mass = 2.5 * 1.66053906660e-27
    geometry = _mev10_z_geometry(genome, features, contract, values;
        dimension_multiplier = dimension_multiplier)
    B = contract.plasma_field_T * field_multiplier
    beta = features.beta * beta_multiplier
    temperature_keV = features.temperature_keV
    temperature_J = temperature_keV * 1.602176634e-16
    pressure = beta * B^2 / (2.0 * mu0)
    density = pressure / max(2.0 * temperature_J, 1.0e-30)
    mass_density = density * ion_mass
    reactivity = _dt_reactivity_m3_s(temperature_keV)
    valid_reactivity = isfinite(reactivity)
    fusion_density = valid_reactivity ? 0.25 * density^2 * reactivity *
        17.6e6 * elementary_charge : 0.0
    fusion_instant = fusion_density * geometry.volume
    alpha_instant = 0.20 * fusion_instant
    stored_energy = 1.5 * pressure * geometry.volume
    pulse_duration = _mev10_value(genome, values,
        "screen_z_pulse_duration", 1.0e-4, "s")
    repetition_rate = _mev10_value(genome, values,
        "screen_z_repetition_rate", 0.0, "Hz")
    duty = clamp(pulse_duration * repetition_rate, 0.0, 1.0)
    shear_normalized = shear_multiplier * _mev10_value(genome, values,
        "screen_z_normalized_shear", 0.0, "1")
    m0_profile = _mev10_value(genome, values,
        "screen_z_m0_profile_margin", 0.0, "1")
    accelerator_efficiency = clamp(efficiency_multiplier * _mev10_value(genome,
        values, "screen_z_accelerator_efficiency", 0.5, "1"), 0.05, 0.90)
    axial_wave_number = pi / max(2.0 * geometry.c, 1.0e-9)
    alfven_speed = B / sqrt(max(mu0 * mass_density, 1.0e-30))
    flow_gradient = shear_normalized * axial_wave_number * alfven_speed
    flow_speed = flow_gradient * geometry.a
    flow_mach_alfven = flow_speed / max(alfven_speed, 1.0)
    advective_time = 2.0 * geometry.c / max(flow_speed, 1.0)
    confinement = min(pulse_duration, advective_time)
    thermal_loss_instant = stored_energy / max(confinement, 1.0e-9)
    flow_inventory = 0.5 * mass_density * flow_speed^2 * geometry.volume
    flow_electric_peak = flow_inventory /
        max(pulse_duration * accelerator_efficiency, 1.0e-12)
    flow_electric_average = flow_electric_peak * duty
    thermal_aux_average = max(0.0, thermal_loss_instant - alpha_instant) * duty
    fusion_average = fusion_instant * duty
    alpha_average = alpha_instant * duty
    total_auxiliary = thermal_aux_average + flow_electric_average
    electrical_auxiliary = thermal_aux_average /
        contract.base.heating_wall_plug_efficiency + flow_electric_average
    declared_actuator = actuator_multiplier * _mev10_value(genome, values,
        "screen_declared_actuator_power", 0.0, "W")
    fusion_gain = fusion_average / max(total_auxiliary, 1.0)
    net_power = contract.base.thermal_conversion_efficiency * fusion_average -
        electrical_auxiliary - contract.base.fixed_balance_of_plant_load_W
    plasma_current = 2.0 * pi * geometry.a * B / mu0
    electrode_area = 2.0 * pi * geometry.a * max(geometry.electrode_build, 1.0e-3)
    current_density = plasma_current / electrode_area / 1.0e6
    magnetic_pressure = B^2 / (2.0 * mu0)
    support_stress = magnetic_pressure * geometry.a /
        max(geometry.wall_thickness, 1.0e-3)
    target_area = 2.0 * pi * geometry.a^2 *
        max(features.exhaust_flux_expansion, 1.0) * target_area_multiplier
    exhaust_heat_flux = thermal_loss_instant * duty / max(target_area, 1.0e-9)
    neutron_wall_load = 0.80 * fusion_average / max(geometry.area, 1.0e-9)
    electrode_pulse_loading = (thermal_loss_instant * pulse_duration +
        flow_inventory) / max(target_area, 1.0e-9)
    particle_loss = pulse_duration / max(advective_time, 1.0e-9)
    base = contract.base
    margins = Dict{String,Float64}(
        "temperature_domain" => min((temperature_keV - 5.0) / 5.0,
            (30.0 - temperature_keV) / 5.0),
        "mode_specific_normalized_shear" => (shear_normalized - 0.10) / 0.10,
        "m0_pressure_profile" => (m0_profile - 0.50) / 0.50,
        "flow_mach_domain" => min(flow_mach_alfven / 0.25,
            (3.0 - flow_mach_alfven) / 1.0),
        "pulse_advection_closure" => (advective_time - pulse_duration) /
            max(pulse_duration, 1.0e-9),
        "particle_loss" => (0.25 - particle_loss) / 0.25,
        "fusion_gain" => fusion_gain - 1.0,
        "auxiliary_power" => (base.auxiliary_heating_budget_W - total_auxiliary) /
            base.auxiliary_heating_budget_W,
        "accelerator_peak_power_authority" =>
            (declared_actuator - flow_electric_peak) /
            max(base.auxiliary_heating_budget_W, 1.0),
        "net_electric_power" => net_power /
            max(base.fixed_balance_of_plant_load_W, 1.0),
        "plasma_electrode_current_density" =>
            (base.engineering_current_density_limit_A_mm2 - current_density) /
            base.engineering_current_density_limit_A_mm2,
        "conducting_wall_support_stress" =>
            (base.support_stress_limit_Pa - support_stress) /
            base.support_stress_limit_Pa,
        "outer_radial_envelope" => geometry.radial_margin /
            max(contract.outer_radial_extent_m, 1.0e-9),
        "outer_axial_envelope" => geometry.axial_margin /
            max(contract.outer_axial_half_extent_m, 1.0e-9),
        "neutron_wall_load" =>
            (base.maximum_neutron_wall_load_W_m2 - neutron_wall_load) /
            base.maximum_neutron_wall_load_W_m2,
        "end_target_heat_flux" =>
            (contract.maximum_exhaust_heat_flux_W_m2 - exhaust_heat_flux) /
            contract.maximum_exhaust_heat_flux_W_m2,
        "electrode_pulse_surface_loading" =>
            (20.0e6 - electrode_pulse_loading) / 20.0e6,
        "repetition_duty_cycle" => (0.20 - duty) / 0.20,
    )
    physics_ids = ["temperature_domain", "mode_specific_normalized_shear",
        "m0_pressure_profile", "flow_mach_domain", "pulse_advection_closure",
        "particle_loss", "fusion_gain", "auxiliary_power",
        "accelerator_peak_power_authority", "net_electric_power"]
    engineering_ids = ["plasma_electrode_current_density",
        "conducting_wall_support_stress", "outer_radial_envelope",
        "outer_axial_envelope", "neutron_wall_load", "end_target_heat_flux",
        "electrode_pulse_surface_loading", "repetition_duty_cycle"]
    return Dict{String,Any}(
        "family" => "sheared_flow_z_pinch",
        "major_radius_or_half_length_m" => geometry.c,
        "plasma_minor_radius_m" => geometry.a,
        "plasma_half_height_or_half_length_m" => geometry.c,
        "plasma_volume_m3" => geometry.volume,
        "first_wall_area_m2" => geometry.area,
        "radial_build_m" => geometry.build,
        "outer_radial_margin_m" => geometry.radial_margin,
        "outer_axial_margin_m" => geometry.axial_margin,
        "beta" => beta, "temperature_keV" => temperature_keV,
        "pressure_Pa" => pressure, "density_m3" => density,
        "fusion_power_W" => fusion_average, "instantaneous_fusion_power_W" => fusion_instant,
        "alpha_power_W" => alpha_average,
        "stored_energy_MJ" => stored_energy / 1.0e6,
        "energy_confinement_time_s" => confinement,
        "pulse_duration_s" => pulse_duration, "repetition_rate_Hz" => repetition_rate,
        "duty_cycle" => duty, "alfven_speed_m_s" => alfven_speed,
        "axial_flow_speed_m_s" => flow_speed,
        "normalized_flow_shear" => shear_normalized,
        "m0_profile_margin_gene" => m0_profile,
        "flow_energy_inventory_J" => flow_inventory,
        "required_flow_electric_peak_power_W" => flow_electric_peak,
        "transport_loss_power_W" => thermal_loss_instant * duty,
        "declared_actuator_power_W" => declared_actuator,
        "required_auxiliary_power_W" => total_auxiliary,
        "required_electrical_auxiliary_power_W" => electrical_auxiliary,
        "fusion_gain_proxy" => fusion_gain, "net_electric_power_W" => net_power,
        "particle_loss_fraction_proxy" => particle_loss,
        "minimum_stability_margin_proxy" => min(
            margins["mode_specific_normalized_shear"], margins["m0_pressure_profile"]),
        "target_count" => 2, "effective_target_area_m2" => target_area,
        "exhaust_heat_flux_W_m2" => exhaust_heat_flux,
        "neutron_wall_load_W_m2" => neutron_wall_load,
        "plasma_current_A" => plasma_current,
        "engineering_current_density_A_mm2" => current_density,
        "support_stress_proxy_Pa" => support_stress,
        "electrode_pulse_surface_loading_J_m2" => electrode_pulse_loading,
        "physics_gate_passed" => valid_reactivity &&
            all(margins[id] >= 0.0 for id in physics_ids),
        "engineering_gate_passed" => all(margins[id] >= 0.0 for id in engineering_ids),
        "margins" => margins, "minimum_normalized_margin" => minimum(Base.values(margins)),
        "experimental_performance_multiplier_used" => false,
        "composition" => Dict(
            "core_family" => "sheared_flow_z_pinch",
            "stability_or_sustainment" => _mev10_mechanism(genome),
            "exhaust_topology" => "two_linear_end_targets",
            "stability_credit" => "mode_specific_rejection_threshold_only"),
    )
end

function _mev10_nominal(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features = _oe_features(genome),
        values = nothing;
        field_multiplier::Float64 = 1.0,
        beta_multiplier::Float64 = 1.0,
        dimension_multiplier::Float64 = 1.0,
        field_quality_penalty::Float64 = 0.0,
        actuator_multiplier::Float64 = 1.0,
        target_area_multiplier::Float64 = 1.0,
        potential_multiplier::Float64 = 1.0,
        stabilizer_multiplier::Float64 = 1.0,
        converter_multiplier::Float64 = 1.0,
        shear_multiplier::Float64 = 1.0,
        efficiency_multiplier::Float64 = 1.0)
    if genome.family == "sheared_flow_z_pinch"
        return _mev10_z_nominal(genome, contract, features, values;
            field_multiplier = field_multiplier,
            beta_multiplier = beta_multiplier,
            dimension_multiplier = dimension_multiplier,
            actuator_multiplier = actuator_multiplier,
            target_area_multiplier = target_area_multiplier,
            shear_multiplier = shear_multiplier,
            efficiency_multiplier = efficiency_multiplier)
    elseif genome.family == "magnetic_mirror" &&
            (_mev10_value(genome, values, "screen_tandem_potential_ratio", 0.0, "1") > 0.0 ||
             _mev10_value(genome, values,
                "screen_kinetic_stabilizer_pressure_fraction", 0.0, "1") > 0.0)
        return _mev10_mirror_nominal(genome, contract, features, values;
            field_multiplier = field_multiplier,
            beta_multiplier = beta_multiplier,
            dimension_multiplier = dimension_multiplier,
            field_quality_penalty = field_quality_penalty,
            actuator_multiplier = actuator_multiplier,
            target_area_multiplier = target_area_multiplier,
            potential_multiplier = potential_multiplier,
            stabilizer_multiplier = stabilizer_multiplier,
            converter_multiplier = converter_multiplier)
    end
    nominal = _ccv9_nominal(genome, contract, features;
        field_multiplier = field_multiplier,
        beta_multiplier = beta_multiplier,
        dimension_multiplier = dimension_multiplier,
        field_quality_penalty = field_quality_penalty,
        actuator_multiplier = actuator_multiplier,
        target_area_multiplier = target_area_multiplier)
    genome.family == "tokamak_axisymmetric" &&
        _mev10_add_pf_label!(nominal, features, contract)
    return nominal
end

function _mev10_z_graph_errors(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features)
    errors = String[]
    append!(errors, validate_genome(genome).errors)
    append!(errors, validate_family(default_family_registry(), genome).errors)
    _ccv9_contract_errors!(errors, genome, contract)
    cores = filter(region -> region.kind == "linear_pinch_core", genome.plasma_regions)
    targets = filter(region -> region.kind == "divertor_or_exhaust_region",
        genome.plasma_regions)
    length(cores) == 1 || push!(errors, "v10 Z pinch requires one linear pinch core")
    length(targets) == 2 || push!(errors, "v10 Z pinch requires two explicit end targets")
    _ct_has_kind(genome.field_sources, "plasma_current") ||
        push!(errors, "v10 Z pinch requires an explicit plasma-current field source")
    _ct_has_kind(genome.field_sources, "passive_conductor") ||
        push!(errors, "v10 Z pinch requires an explicit conducting wall/electrode source")
    any(actuator -> actuator.id == "v10_coaxial_plasma_accelerator",
        genome.actuators) ||
        push!(errors, "v10 Z pinch requires an explicit coaxial accelerator")
    count(edge -> edge.kind == "open_field_line", genome.flux_connections) == 2 ||
        push!(errors, "v10 Z pinch core must connect to two open ends")
    geometry = _mev10_z_geometry(genome, features, contract)
    if length(cores) == 1
        core = only(cores)
        for (name, expected) in (("plasma_radius", geometry.a),
                ("half_length", geometry.c))
            value = get(core.parameters, name, nothing)
            (value !== nothing && value.unit == "m" &&
                isapprox(value.value, expected; rtol = 1.0e-9, atol = 1.0e-9)) ||
                push!(errors, "$(core.id).$name is inconsistent with scored v10 geometry")
        end
    end
    return sort!(unique(errors))
end

function _mev10_mirror_graph_errors!(errors::Vector{String}, genome::Genome)
    potential = _mev10_target(genome, "screen_tandem_potential_ratio", 0.0, "1")
    stabilizer = _mev10_target(genome,
        "screen_kinetic_stabilizer_pressure_fraction", 0.0, "1")
    potential > 0.0 && begin
        count(region -> occursin("plug", lowercase(region.kind)),
            genome.plasma_regions) >= 2 ||
            push!(errors, "tandem barrier requires two explicit plug regions")
        any(actuator -> startswith(actuator.id, "v10_tandem_plug_nbi"),
            genome.actuators) ||
            push!(errors, "tandem barrier requires explicit plug neutral beams")
        any(actuator -> actuator.id == "v10_tandem_plug_ech",
            genome.actuators) ||
            push!(errors, "thermal barrier requires explicit plug ECH")
    end
    stabilizer > 0.0 && !any(actuator ->
        actuator.id == "v10_kinetic_stabilizer_beam", genome.actuators) &&
        push!(errors, "kinetic stabilizer requires an explicit reflected-ion beam")
    recovery = _mev10_target(genome,
        "screen_direct_converter_recovery_fraction", 0.0, "1")
    recovery > 0.0 && !occursin("direct_converter", genome.exhaust.kind) &&
        push!(errors, "direct-converter credit requires an explicit direct-converter exhaust")
    return errors
end

function _mev10_graph_errors(genome::Genome, features,
        contract::SharedOuterEnvelopeContractV1)
    genome.family == "sheared_flow_z_pinch" &&
        return _mev10_z_graph_errors(genome, contract, features)
    errors = _ccv9_graph_errors(genome, features, contract)
    genome.family == "magnetic_mirror" &&
        _mev10_mirror_graph_errors!(errors, genome)
    return sort!(unique(errors))
end

function _mev10_robustness(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features)
    rng = MersenneTwister(contract.base.robustness_seed)
    records = Dict{String,Any}[]
    pass_count = 0
    worst_margin = Inf
    for sample in 1:contract.base.robustness_samples
        field_delta = 0.02 * (2.0 * rand(rng) - 1.0)
        beta_delta = 0.15 * (2.0 * rand(rng) - 1.0)
        dimension_delta = 0.01 * (2.0 * rand(rng) - 1.0)
        actuator_error = 0.10 * (2.0 * rand(rng) - 1.0)
        target_occlusion = 0.10 * rand(rng)
        mechanism_error = 0.15 * (2.0 * rand(rng) - 1.0)
        efficiency_error = 0.10 * (2.0 * rand(rng) - 1.0)
        nominal = if genome.family == "sheared_flow_z_pinch"
            _mev10_nominal(genome, contract, features, nothing;
                field_multiplier = 1.0 + field_delta,
                beta_multiplier = 1.0 + beta_delta,
                dimension_multiplier = 1.0 + dimension_delta,
                actuator_multiplier = 1.0 + actuator_error,
                target_area_multiplier = 1.0 - target_occlusion,
                shear_multiplier = 1.0 + mechanism_error,
                efficiency_multiplier = 1.0 + efficiency_error)
        else
            quality_penalty = 0.02 * abs(mechanism_error)
            _mev10_nominal(genome, contract, features, nothing;
                field_multiplier = 1.0 + field_delta,
                beta_multiplier = 1.0 + beta_delta,
                dimension_multiplier = 1.0 + dimension_delta,
                field_quality_penalty = quality_penalty,
                actuator_multiplier = 1.0 + actuator_error,
                target_area_multiplier = 1.0 - target_occlusion,
                potential_multiplier = 1.0 + mechanism_error,
                stabilizer_multiplier = 1.0 + mechanism_error,
                converter_multiplier = 1.0 - abs(efficiency_error))
        end
        passed = nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true
        passed && (pass_count += 1)
        worst_margin = min(worst_margin, Float64(nominal["minimum_normalized_margin"]))
        push!(records, Dict{String,Any}(
            "sample" => sample, "field_delta_fraction" => field_delta,
            "beta_delta_fraction" => beta_delta,
            "dimension_delta_fraction" => dimension_delta,
            "actuator_error_fraction" => actuator_error,
            "target_occlusion_fraction" => target_occlusion,
            "mechanism_error_fraction" => mechanism_error,
            "passed" => passed,
            "minimum_normalized_margin" => nominal["minimum_normalized_margin"]))
    end
    fraction = pass_count / contract.base.robustness_samples
    return Dict{String,Any}(
        "sample_count" => contract.base.robustness_samples,
        "common_random_seed" => contract.base.robustness_seed,
        "pass_count" => pass_count, "pass_fraction" => fraction,
        "required_pass_fraction" => contract.base.robustness_required_pass_fraction,
        "gate_passed" => fraction >= contract.base.robustness_required_pass_fraction,
        "worst_minimum_normalized_margin" => worst_margin,
        "records" => records)
end

function _mechanism_expansion_result(evaluator::MechanismExpansionScreenV1,
        genome::Genome)
    contract = evaluator.contract
    contract_dict = _oe_contract_dict(contract)
    contract_hash = canonical_hash(contract_dict)
    features = _oe_features(genome)
    graph_errors = _mev10_graph_errors(genome, features, contract)
    graph_gate = isempty(graph_errors)
    nominal = _mev10_nominal(genome, contract, features)
    robustness = if graph_gate && nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true
        _mev10_robustness(genome, contract, features)
    else
        Dict{String,Any}(
            "sample_count" => 0,
            "maximum_sample_budget" => contract.base.robustness_samples,
            "common_random_seed" => contract.base.robustness_seed,
            "pass_count" => 0, "pass_fraction" => 0.0,
            "required_pass_fraction" => contract.base.robustness_required_pass_fraction,
            "gate_passed" => false,
            "worst_minimum_normalized_margin" => nominal["minimum_normalized_margin"],
            "records" => Dict{String,Any}[],
            "skipped_due_nominal_gate_failure" => true)
    end
    contract_gate = contract_hash in evaluator.allowed_contract_hashes
    all_five = graph_gate && nominal["physics_gate_passed"] === true &&
        nominal["engineering_gate_passed"] === true && contract_gate &&
        robustness["gate_passed"] === true
    complexity = length(genome.field_sources) + 1.5length(genome.actuators) +
        0.5length(genome.plasma_regions) + 0.25length(genome.flux_connections)
    result = Dict{String,Any}(
        "contract" => contract_dict, "contract_hash" => contract_hash,
        "claim_boundary" => _MEV10_SCREEN_CLAIM_BOUNDARY,
        "composition" => nominal["composition"],
        "topology_features" => Dict(String(key) => value for
            (key, value) in pairs(features)),
        "topology_graph_errors" => graph_errors,
        "nominal" => nominal, "robustness" => robustness,
        "gates" => Dict(
            "variable_topology_representation_and_compatibility" => graph_gate,
            "unified_low_fidelity_physics" => nominal["physics_gate_passed"],
            "minimal_engineering_closure" => nominal["engineering_gate_passed"],
            "same_outer_envelope_contract" => contract_gate,
            "cheap_robustness_screen" => robustness["gate_passed"]),
        "all_five_gates_passed" => all_five,
        "positive_net_power_closure_passed" => nominal["net_electric_power_W"] > 0.0,
        "classification" => all_five ?
            "v10_survivor_pending_family_specific_medium_fidelity" :
            "obviously_infeasible_or_unresolved",
        "device_complexity_proxy" => complexity)
    result["result_hash"] = canonical_hash(result)
    return result
end

function run_evaluator(evaluator::MechanismExpansionScreenV1, genome::Genome;
        kwargs...)
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return _non_applicable_bundle(evaluator_spec(evaluator), genome, reason)
    result = _mechanism_expansion_result(evaluator, genome)
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "evaluator" => "mechanism_expansion_screen_v1",
        "version" => "1.0.0", "result_hash" => result["result_hash"]))
    status = result["all_five_gates_passed"] === true ? :pass : :fail
    metric = MetricResult("mechanism_expansion_five_gate_pass",
        result["all_five_gates_passed"] ? 1.0 : 0.0;
        fidelity = 0, applicability = reason, status = status,
        constraints_checked = sort!(collect(keys(result["gates"]))),
        solver_name = "mechanism_expansion_screen_v1", solver_version = "1.0.0",
        input_hash = genome.physics_hash, run_hash = run_hash,
        source_basis = _MEV10_SOURCE_BASIS,
        warnings = [_MEV10_SCREEN_CLAIM_BOUNDARY])
    return EvaluationBundle("mechanism_expansion_screen_v1", genome.design_id,
        genome.family, 0, status, [metric], [_MEV10_SCREEN_CLAIM_BOUNDARY],
        genome.physics_hash, run_hash, _MEV10_SCREEN_CLAIM_BOUNDARY)
end
