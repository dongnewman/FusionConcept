const _CBV12_SCREEN_CLAIM_BOUNDARY =
    "Fidelity-0 causal-bridge and negative-anchor rejection screen. V11 controls retain " *
    "their sealed equations. The two-component GDT branch separates collisional warm target " *
    "plasma from anisotropic fast ions and closes beam-target reactions, fast-ion relaxation, " *
    "neutral-beam wall power, gas-dynamic axial loss, Bohm-reference transverse loss, radiation, " *
    "finite build, and end heat flux. IEC and DPF branches are experimentally bounded negative " *
    "anchors: observed neutron production cannot be extrapolated beyond an optimistic 1e-5 IEC " *
    "fusion/input ratio or Q=0.01 DPF ceiling. Passing establishes neither distribution-function " *
    "self-consistency, equilibrium, all-mode stability, component lifetime, net electricity, " *
    "novelty, nor superiority."

const _CBV12_SOURCE_BASIS = String[
    "gdt_fast_ion_relaxation_anikeev_2000",
    "gdt_overview_ivanov_2013",
    "gdt_neutron_source_molvik_2010",
    "bosch_hale_cross_sections_1992",
    "iec_hirsch_1967",
    "nonequilibrium_limit_rider_1997",
    "iec_efficiency_anchor_biswas_2019",
    "dpf_kinetic_schmidt_2012",
    "dpf_scaling_failure_auluck_2023",
    "dpf_q_ceiling_lee_2022",
]

"Append-only v12 evaluator; all v1-v11 source and artifact hashes remain unchanged."
struct CausalBridgeScreenV1 <: AbstractEvaluator
    contract::SharedOuterEnvelopeContractV1
    allowed_contract_hashes::Set{String}
end

function CausalBridgeScreenV1(contract::SharedOuterEnvelopeContractV1;
        allowed_contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    return CausalBridgeScreenV1(contract,
        Set(canonical_hash(_oe_contract_dict(item)) for item in allowed_contracts))
end

function evaluator_spec(::CausalBridgeScreenV1)
    return EvaluatorSpec("causal_bridge_screen_v1", "1.0.0",
        ["magnetic_mirror", "inertial_electrostatic_confinement",
            "dense_plasma_focus"], 0,
        Dict(
            "two_component_fokker_planck_gdt" => :proxy,
            "beam_target_nuclear_rate" => :proxy,
            "gas_dynamic_end_loss" => :proxy,
            "transverse_loss_floor" => :proxy,
            "iec_poisson_orbit_grid_model" => :proxy,
            "nonequilibrium_fokker_planck_power" => :proxy,
            "dpf_kinetic_discharge" => :proxy,
            "electrode_erosion_and_repetition" => :proxy,
            "finite_build" => :proxy,
            "power_balance" => :proxy,
            "exhaust" => :proxy),
        _CBV12_SCREEN_CLAIM_BOUNDARY)
end

function evaluator_applicability(evaluator::CausalBridgeScreenV1, genome::Genome)
    genome.family in evaluator_spec(evaluator).families || return false,
        "causal-bridge v12 does not cover family $(genome.family)"
    genome.mission.fuel in ("D-T", "D-D") || return false,
        "causal-bridge v12 is restricted to D-T or D-D"
    return true, "v12 causal bridge or negative anchor under $(evaluator.contract.id)"
end

_cbv12_target(genome::Genome, name::String, default::Real, unit::String) =
    _oe_target(genome, name, default, unit)

function _cbv12_value(genome::Genome, values, name::String, default::Real,
        unit::String)
    values !== nothing && haskey(values, name) && return Float64(values[name])
    return _cbv12_target(genome, name, default, unit)
end

function _cbv12_energy_keV(genome::Genome, values, name::String, default::Real)
    values !== nothing && haskey(values, name) && return Float64(values[name])
    value = get(genome.mission.targets, name, nothing)
    value === nothing && return Float64(default)
    value.unit == "J" || throw(ArgumentError(
        "mission.targets.$name must normalize to J, got $(value.unit)"))
    return value.value / 1.602176634e-16
end

_cbv12_is_two_component_gdt(genome::Genome, values = nothing) =
    genome.family == "magnetic_mirror" && _cbv12_value(genome, values,
        "screen_cbv12_two_component_gdt_active", 0.0, "1") > 0.5

function _cbv12_mechanism(genome::Genome, values = nothing)
    if _cbv12_is_two_component_gdt(genome, values)
        return _cbv12_value(genome, values,
            "screen_olv11_cell_count", 1.0, "1") > 1.5 ?
            "two_component_gdmt" : "two_component_gdt"
    elseif genome.family == "inertial_electrostatic_confinement"
        return _cbv12_value(genome, values,
            "screen_cbv12_anchor_only", 0.0, "1") > 0.5 ?
            "gridded_iec_neutron_anchor" : "gridded_iec_net_electric_candidate"
    elseif genome.family == "dense_plasma_focus"
        return "dpf_experimental_saturation_anchor"
    end
    return "unknown_v12_mechanism"
end

function _cbv12_features(genome::Genome)
    features = _oe_features(genome)
    _cbv12_is_two_component_gdt(genome) || return features
    return merge(features, (
        minimum_b_strength = _cbv12_target(genome,
            "screen_minimum_b_strength", features.minimum_b_strength, "1"),
        shear_strength = _cbv12_target(genome,
            "screen_shear_strength", features.shear_strength, "1")))
end

"Bosch-Hale T(d,n)4He cross section, E in keV and result in m^2."
function _cbv12_dt_cross_section_m2(energy_keV::Real)
    E = Float64(energy_keV)
    0.5 <= E <= 5000.0 || return NaN
    A1, A2, A3, A4, A5 = 6.927e1, 7.454e5, 2.050e3, 5.2002e1, 0.0
    B1, B2, B3, B4 = 6.38e1, -9.95e-1, 6.981e-5, 1.728e-4
    gamow_energy_keV = 1182.2
    numerator = A1 + E * (A2 + E * (A3 + E * (A4 + E * A5)))
    denominator = 1.0 + E * (B1 + E * (B2 + E * (B3 + E * B4)))
    s_keV_barn = numerator / denominator
    sigma_barn = s_keV_barn / (E * exp(sqrt(gamow_energy_keV / E)))
    return sigma_barn * 1.0e-28
end

function _cbv12_geometry(features, contract::SharedOuterEnvelopeContractV1;
        axial::Bool = false, dimension_multiplier::Float64 = 1.0,
        extra_build_m::Float64 = 0.0)
    base = contract.base
    build = base.shield_thickness_m + base.maintenance_gap_m +
        features.coil_pack_thickness_m + features.support_thickness_m + extra_build_m
    radial_capacity = contract.outer_radial_extent_m - build
    radius = max(0.01, features.plasma_fill_fraction * dimension_multiplier *
        radial_capacity)
    half_length = axial ? max(radius, features.shape_ratio * radius) : radius
    volume = axial ? 2.0pi * radius^2 * half_length : 4.0pi * radius^3 / 3.0
    area = axial ? 4.0pi * radius * half_length + 2.0pi * radius^2 :
        4.0pi * radius^2
    return (radius = radius, half_length = half_length, volume = volume,
        area = area, build = build,
        radial_margin = contract.outer_radial_extent_m - (radius + build),
        axial_margin = contract.outer_axial_half_extent_m - (half_length + build))
end

function _cbv12_two_component_gdt_nominal(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features, values = nothing;
        field_multiplier::Float64 = 1.0, beta_multiplier::Float64 = 1.0,
        dimension_multiplier::Float64 = 1.0,
        actuator_multiplier::Float64 = 1.0,
        target_area_multiplier::Float64 = 1.0,
        mechanism_multiplier::Float64 = 1.0)
    mu0 = 4.0e-7pi
    e = 1.602176634e-19
    amu = 1.66053906660e-27
    B = contract.plasma_field_T * field_multiplier
    geometry = _olv11_gdt_geometry(genome, features, contract, values;
        dimension_multiplier = dimension_multiplier)
    total_beta = features.beta * beta_multiplier
    fast_beta_fraction = _cbv12_value(genome, values,
        "screen_cbv12_fast_beta_fraction", 0.50, "1")
    target_beta = total_beta * (1.0 - fast_beta_fraction)
    fast_beta = total_beta * fast_beta_fraction
    electron_temperature_keV = _cbv12_energy_keV(genome, values,
        "screen_cbv12_target_electron_temperature", 0.25)
    ion_temperature_keV = _cbv12_energy_keV(genome, values,
        "screen_cbv12_target_ion_temperature", 0.25)
    fast_energy_keV = _cbv12_energy_keV(genome, values,
        "screen_cbv12_fast_ion_energy", 50.0)
    absorption_fraction = _cbv12_value(genome, values,
        "screen_cbv12_nbi_absorption_fraction", 0.75, "1")
    nbi_efficiency = _cbv12_value(genome, values,
        "screen_cbv12_nbi_wall_efficiency", 0.45, "1")
    target_pressure = target_beta * B^2 / (2.0mu0)
    target_density = target_pressure / max((electron_temperature_keV +
        ion_temperature_keV) * 1.602176634e-16, 1.0e-30)
    fast_pressure = fast_beta * B^2 / (2.0mu0)
    fast_density = 1.5fast_pressure /
        max(fast_energy_keV * 1.602176634e-16, 1.0e-30)
    collision = _olv11_ion_collision_scales(ion_temperature_keV, target_density)
    mirror_ratio = _cbv12_value(genome, values,
        "screen_mirror_ratio", features.mirror_ratio, "1")
    gas_dynamic_parameter = 2.0geometry.central_half * mirror_ratio /
        max(collision.mean_free_path_m, 1.0e-30)
    cell_collisionality = geometry.cell_length /
        max(collision.mean_free_path_m, 1.0e-30)
    applicability = geometry.cells > 1 ?
        exp(-abs(log(max(cell_collisionality, 1.0e-12)))) : 0.0
    axial_suppression = geometry.cells > 1 ? min(4.0,
        1.0 + 0.35 * (min(geometry.cells, 12) - 1) * applicability *
            mechanism_multiplier) : 1.0
    tau_axial = 2.0geometry.central_half * mirror_ratio /
        max(collision.thermal_speed_m_s, 1.0) * axial_suppression
    target_stored = 1.5target_pressure * geometry.volume
    bohm_diffusivity = electron_temperature_keV * 1.602176634e-16 /
        max(16.0e * B, 1.0e-30)
    tau_transverse = geometry.a^2 * max(features.field_quality, 0.05) /
        max(bohm_diffusivity, 1.0e-30)
    axial_loss = target_stored / max(tau_axial, 1.0e-30)
    transverse_loss = target_stored / max(tau_transverse, 1.0e-30)
    n20 = target_density / 1.0e20
    bremsstrahlung = 5.35e3 * n20^2 * sqrt(max(electron_temperature_keV, 0.0)) *
        geometry.volume
    slowing_time = 0.70e-3 * (electron_temperature_keV / 0.070)^1.5 *
        (1.0e20 / max(target_density, 1.0))
    fast_inventory = fast_density * geometry.volume * fast_energy_keV *
        1.602176634e-16
    fast_drag_power = fast_inventory / max(slowing_time, 1.0e-30)
    fast_direct_loss = 0.05fast_drag_power
    required_absorbed_beam = fast_drag_power + fast_direct_loss
    required_injected_beam = required_absorbed_beam / max(absorption_fraction, 1.0e-6)
    declared_nbi = actuator_multiplier * _cbv12_value(genome, values,
        "screen_cbv12_nbi_power", 0.0, "W")
    bias_power = actuator_multiplier * _cbv12_value(genome, values,
        "screen_olv11_bias_power", 0.0, "W")
    # The searched fast-ion energy is a laboratory beam energy. Evaluate equal
    # D/T fast and target populations explicitly: D-on-T has E_cm=3E_lab/5,
    # T-on-D has E_cm=2E_lab/5, and the projectile speeds differ by mass.
    d_center_of_mass_energy_keV = 0.60fast_energy_keV
    t_center_of_mass_energy_keV = 0.40fast_energy_keV
    sigma_d_on_t = _cbv12_dt_cross_section_m2(d_center_of_mass_energy_keV)
    sigma_t_on_d = _cbv12_dt_cross_section_m2(t_center_of_mass_energy_keV)
    d_speed = sqrt(2.0 * fast_energy_keV * 1.602176634e-16 / (2.0amu))
    t_speed = sqrt(2.0 * fast_energy_keV * 1.602176634e-16 / (3.0amu))
    valid_cross_sections = isfinite(sigma_d_on_t) && isfinite(sigma_t_on_d)
    reaction_rate = valid_cross_sections ? 0.25fast_density * target_density *
        (sigma_d_on_t * d_speed + sigma_t_on_d * t_speed) * geometry.volume : 0.0
    fusion_power = reaction_rate * 17.6e6 * e
    alpha_power = 0.20fusion_power
    target_heating_gap = max(0.0, axial_loss + transverse_loss +
        bremsstrahlung - fast_drag_power - alpha_power)
    plasma_auxiliary = required_injected_beam + bias_power + target_heating_gap
    wall_electric = required_injected_beam / max(nbi_efficiency, 1.0e-6) +
        (bias_power + target_heating_gap) /
            contract.base.heating_wall_plug_efficiency
    fusion_gain = fusion_power / max(plasma_auxiliary, 1.0)
    net_power = contract.base.thermal_conversion_efficiency * fusion_power -
        wall_electric - contract.base.fixed_balance_of_plant_load_W
    target_area = 2.0pi * geometry.a^2 *
        max(features.exhaust_flux_expansion, 1.0) * target_area_multiplier
    target_heat_flux = (axial_loss + fast_direct_loss) / max(target_area, 1.0e-9)
    transverse_heat_flux = transverse_loss / max(geometry.area, 1.0e-9)
    neutron_wall_load = 0.80fusion_power / max(geometry.area, 1.0e-9)
    peak_field = B * mirror_ratio
    current_density = peak_field /
        (mu0 * max(features.coil_pack_thickness_m, 0.02)) / 1.0e6
    support_stress = peak_field^2 / (2.0mu0) * geometry.a /
        max(features.support_thickness_m, 0.05)
    base = contract.base
    calibration_temperature_margin = min(
        (electron_temperature_keV - 0.05) / 0.05,
        (1.20 - electron_temperature_keV) / 0.20)
    calibration_density_margin = min(
        (target_density - 0.5e20) / 0.5e20,
        (5.0e20 - target_density) / 1.0e20)
    margins = Dict{String,Float64}(
        "warm_target_temperature_domain" => calibration_temperature_margin,
        "warm_target_density_domain" => calibration_density_margin,
        "fast_ion_energy_domain" => min((fast_energy_keV - 20.0) / 10.0,
            (80.0 - fast_energy_keV) / 20.0),
        "gas_dynamic_target_collisionality" => gas_dynamic_parameter - 1.0,
        "multiple_mirror_cell_collisionality" => geometry.cells > 1 ? min(
            (cell_collisionality - 0.10) / 0.10,
            (3.0 - cell_collisionality) / 1.0) : 1.0,
        "two_component_beta" => min((fast_beta_fraction - 0.10) / 0.10,
            (0.85 - fast_beta_fraction) / 0.15),
        "fast_ion_relaxation_applicability" => min(
            calibration_temperature_margin, calibration_density_margin),
        "nbi_inventory_closure" => (declared_nbi - required_injected_beam) /
            max(declared_nbi, 1.0),
        "minimum_b_and_vortex_stability" => min(
            (features.minimum_b_strength - 0.60) / 0.40,
            (features.shear_strength - 0.30) / 0.30),
        "fusion_gain" => fusion_gain - 1.0,
        "auxiliary_power" => (base.auxiliary_heating_budget_W - plasma_auxiliary) /
            base.auxiliary_heating_budget_W,
        "net_electric_power" => net_power /
            max(base.fixed_balance_of_plant_load_W, 1.0),
        "peak_conductor_field" => (base.peak_conductor_field_limit_T - peak_field) /
            base.peak_conductor_field_limit_T,
        "engineering_current_density" =>
            (base.engineering_current_density_limit_A_mm2 - current_density) /
                base.engineering_current_density_limit_A_mm2,
        "support_stress" => (base.support_stress_limit_Pa - support_stress) /
            base.support_stress_limit_Pa,
        "outer_radial_envelope" => geometry.radial_margin /
            max(contract.outer_radial_extent_m, 1.0e-9),
        "outer_axial_envelope" => geometry.axial_margin /
            max(contract.outer_axial_half_extent_m, 1.0e-9),
        "coil_curvature" => (geometry.a - base.minimum_coil_curvature_radius_m) /
            base.minimum_coil_curvature_radius_m,
        "neutron_wall_load" =>
            (base.maximum_neutron_wall_load_W_m2 - neutron_wall_load) /
                base.maximum_neutron_wall_load_W_m2,
        "end_target_heat_flux" =>
            (contract.maximum_exhaust_heat_flux_W_m2 - target_heat_flux) /
                contract.maximum_exhaust_heat_flux_W_m2,
        "transverse_wall_heat_flux" =>
            (contract.maximum_exhaust_heat_flux_W_m2 - transverse_heat_flux) /
                contract.maximum_exhaust_heat_flux_W_m2)
    physics_ids = ["warm_target_temperature_domain", "warm_target_density_domain",
        "fast_ion_energy_domain", "gas_dynamic_target_collisionality",
        "multiple_mirror_cell_collisionality", "two_component_beta",
        "fast_ion_relaxation_applicability", "nbi_inventory_closure",
        "minimum_b_and_vortex_stability", "fusion_gain", "auxiliary_power",
        "net_electric_power"]
    engineering_ids = ["peak_conductor_field", "engineering_current_density",
        "support_stress", "outer_radial_envelope", "outer_axial_envelope",
        "coil_curvature", "neutron_wall_load", "end_target_heat_flux",
        "transverse_wall_heat_flux"]
    return Dict{String,Any}(
        "family" => "magnetic_mirror", "mechanism" => _cbv12_mechanism(genome, values),
        "plasma_minor_radius_m" => geometry.a,
        "plasma_half_height_or_half_length_m" => geometry.central_half,
        "plasma_volume_m3" => geometry.volume, "first_wall_area_m2" => geometry.area,
        "outer_radial_margin_m" => geometry.radial_margin,
        "outer_axial_margin_m" => geometry.axial_margin,
        "total_beta" => total_beta, "target_beta" => target_beta,
        "fast_ion_beta" => fast_beta, "fast_beta_fraction" => fast_beta_fraction,
        "target_electron_temperature_keV" => electron_temperature_keV,
        "target_ion_temperature_keV" => ion_temperature_keV,
        "target_density_m3" => target_density, "fast_ion_energy_keV" => fast_energy_keV,
        "fast_ion_density_m3" => fast_density, "fast_ion_slowing_time_s" => slowing_time,
        "fast_ion_inventory_J" => fast_inventory,
        "d_on_t_center_of_mass_energy_keV" => d_center_of_mass_energy_keV,
        "t_on_d_center_of_mass_energy_keV" => t_center_of_mass_energy_keV,
        "bosch_hale_d_on_t_cross_section_m2" => sigma_d_on_t,
        "bosch_hale_t_on_d_cross_section_m2" => sigma_t_on_d,
        "beam_target_reaction_rate_s1" => reaction_rate,
        "fusion_power_W" => fusion_power, "alpha_power_W" => alpha_power,
        "gas_dynamic_parameter" => gas_dynamic_parameter,
        "cell_collisionality" => cell_collisionality,
        "multiple_mirror_cell_count" => geometry.cells,
        "multiple_mirror_axial_suppression" => axial_suppression,
        "ideal_N_or_N_squared_performance_transplanted" => false,
        "target_axial_loss_power_W" => axial_loss,
        "target_transverse_loss_power_W" => transverse_loss,
        "bremsstrahlung_power_W" => bremsstrahlung,
        "fast_ion_drag_power_W" => fast_drag_power,
        "fast_ion_direct_loss_power_W" => fast_direct_loss,
        "required_injected_nbi_power_W" => required_injected_beam,
        "declared_nbi_power_W" => declared_nbi,
        "nbi_absorption_fraction" => absorption_fraction,
        "nbi_wall_efficiency" => nbi_efficiency,
        "required_auxiliary_power_W" => plasma_auxiliary,
        "wall_electric_input_W" => wall_electric,
        "fusion_gain_proxy" => fusion_gain, "net_electric_power_W" => net_power,
        "exhaust_heat_flux_W_m2" => target_heat_flux,
        "transverse_wall_heat_flux_W_m2" => transverse_heat_flux,
        "neutron_wall_load_W_m2" => neutron_wall_load,
        "peak_conductor_field_T" => peak_field,
        "engineering_current_density_A_mm2" => current_density,
        "support_stress_proxy_Pa" => support_stress,
        "physics_gate_passed" => valid_cross_sections &&
            all(margins[id] >= 0.0 for id in physics_ids),
        "engineering_gate_passed" =>
            all(margins[id] >= 0.0 for id in engineering_ids),
        "margins" => margins,
        "minimum_normalized_margin" => minimum(Base.values(margins)),
        "experimental_performance_multiplier_used" => false,
        "single_temperature_gdt_model_used" => false,
        "composition" => Dict(
            "core_family" => "magnetic_mirror",
            "stability_or_sustainment" => _cbv12_mechanism(genome, values),
            "exhaust_topology" => "two_end_expander",
            "reaction_model" => "bosch_hale_beam_target_dt"))
end

function _cbv12_iec_nominal(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features, values = nothing;
        dimension_multiplier::Float64 = 1.0,
        actuator_multiplier::Float64 = 1.0,
        target_area_multiplier::Float64 = 1.0, kwargs...)
    anchor = _cbv12_value(genome, values, "screen_cbv12_anchor_only", 0.0, "1") > 0.5
    geometry = _cbv12_geometry(features, contract;
        dimension_multiplier = dimension_multiplier, extra_build_m = 0.10)
    voltage = _cbv12_value(genome, values, "screen_cbv12_iec_voltage", 80.0e3, "V")
    input_power = actuator_multiplier * _cbv12_value(genome, values,
        "screen_cbv12_iec_input_power", 1.0e6, "W")
    transparency = _cbv12_value(genome, values,
        "screen_cbv12_iec_grid_transparency", 0.95, "1")
    grid_radius_fraction = _cbv12_value(genome, values,
        "screen_cbv12_iec_grid_radius_fraction", 0.25, "1")
    optimistic_efficiency_ceiling = 1.0e-5
    fusion_power = optimistic_efficiency_ceiling * input_power
    grid_intercept_power = (1.0 - transparency) * input_power
    grid_radius = geometry.radius * grid_radius_fraction
    wire_area = max(4.0pi * grid_radius^2 * (1.0 - transparency), 1.0e-9)
    grid_heat_flux = grid_intercept_power /
        max(wire_area * target_area_multiplier, 1.0e-9)
    electric_field = voltage / max(geometry.radius - grid_radius, 1.0e-6)
    neutron_wall_load = 0.80fusion_power / max(geometry.area, 1.0e-9)
    net_power = contract.base.thermal_conversion_efficiency * fusion_power -
        input_power - contract.base.fixed_balance_of_plant_load_W
    fusion_gain = fusion_power / max(input_power, 1.0)
    base = contract.base
    margins = Dict{String,Float64}(
        "measured_iec_voltage_domain" => min((voltage - 10.0e3) / 10.0e3,
            (200.0e3 - voltage) / 50.0e3),
        "grid_transparency_domain" => min((transparency - 0.75) / 0.10,
            (0.995 - transparency) / 0.005),
        "experimental_efficiency_ceiling" =>
            (optimistic_efficiency_ceiling - fusion_gain) /
                optimistic_efficiency_ceiling,
        "nonequilibrium_recirculating_power" => anchor ? 0.0 : -1.0,
        "fusion_gain" => fusion_gain - 1.0,
        "net_electric_power" => net_power /
            max(base.fixed_balance_of_plant_load_W, 1.0),
        "outer_radial_envelope" => geometry.radial_margin /
            max(contract.outer_radial_extent_m, 1.0e-9),
        "outer_axial_envelope" => geometry.axial_margin /
            max(contract.outer_axial_half_extent_m, 1.0e-9),
        "high_voltage_field" => (20.0e6 - electric_field) / 20.0e6,
        "grid_heat_flux" =>
            (contract.maximum_exhaust_heat_flux_W_m2 - grid_heat_flux) /
                contract.maximum_exhaust_heat_flux_W_m2,
        "neutron_wall_load" =>
            (base.maximum_neutron_wall_load_W_m2 - neutron_wall_load) /
                base.maximum_neutron_wall_load_W_m2)
    physics_ids = anchor ? ["measured_iec_voltage_domain",
        "grid_transparency_domain", "experimental_efficiency_ceiling"] :
        ["measured_iec_voltage_domain", "grid_transparency_domain",
            "experimental_efficiency_ceiling", "nonequilibrium_recirculating_power",
            "fusion_gain", "net_electric_power"]
    engineering_ids = ["outer_radial_envelope", "outer_axial_envelope",
        "high_voltage_field", "grid_heat_flux", "neutron_wall_load"]
    return Dict{String,Any}(
        "family" => "inertial_electrostatic_confinement",
        "mechanism" => _cbv12_mechanism(genome, values),
        "plasma_minor_radius_m" => geometry.radius,
        "plasma_volume_m3" => geometry.volume, "first_wall_area_m2" => geometry.area,
        "outer_radial_margin_m" => geometry.radial_margin,
        "outer_axial_margin_m" => geometry.axial_margin,
        "iec_voltage_V" => voltage, "grid_transparency" => transparency,
        "grid_radius_m" => grid_radius, "electrical_input_power_W" => input_power,
        "optimistic_fusion_to_input_efficiency_ceiling" =>
            optimistic_efficiency_ceiling,
        "fusion_power_W" => fusion_power, "fusion_gain_proxy" => fusion_gain,
        "net_electric_power_W" => net_power,
        "grid_intercept_power_W" => grid_intercept_power,
        "grid_heat_flux_W_m2" => grid_heat_flux,
        "neutron_wall_load_W_m2" => neutron_wall_load,
        "physics_gate_passed" => all(margins[id] >= 0.0 for id in physics_ids),
        "engineering_gate_passed" =>
            all(margins[id] >= 0.0 for id in engineering_ids),
        "margins" => margins,
        "minimum_normalized_margin" => minimum(Base.values(margins)),
        "experimental_neutron_production_credited" => true,
        "reactor_scale_potential_well_credited" => false,
        "unbounded_ion_recirculation_credited" => false,
        "anchor_only" => anchor,
        "composition" => Dict(
            "core_family" => "inertial_electrostatic_confinement",
            "stability_or_sustainment" => _cbv12_mechanism(genome, values),
            "exhaust_topology" => "grid_and_spherical_wall"))
end

function _cbv12_dpf_nominal(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features, values = nothing;
        dimension_multiplier::Float64 = 1.0,
        actuator_multiplier::Float64 = 1.0,
        target_area_multiplier::Float64 = 1.0, kwargs...)
    geometry = _cbv12_geometry(features, contract; axial = true,
        dimension_multiplier = dimension_multiplier, extra_build_m = 0.20)
    stored_energy = actuator_multiplier * _cbv12_value(genome, values,
        "screen_cbv12_dpf_stored_energy", 100.0e3, "J")
    current = _cbv12_value(genome, values, "screen_cbv12_dpf_peak_current", 1.0e6, "A")
    repetition = _cbv12_value(genome, values,
        "screen_cbv12_dpf_repetition_rate", 1.0, "Hz")
    availability = _cbv12_value(genome, values,
        "screen_cbv12_dpf_availability", 0.50, "1")
    driver_efficiency = _cbv12_value(genome, values,
        "screen_cbv12_dpf_driver_efficiency", 0.50, "1")
    optimistic_q_ceiling = 0.01
    fusion_energy_per_shot = optimistic_q_ceiling * stored_energy
    fusion_power = fusion_energy_per_shot * repetition * availability
    wall_power = stored_energy * repetition / max(driver_efficiency, 1.0e-6)
    net_power = contract.base.thermal_conversion_efficiency * fusion_power -
        wall_power - contract.base.fixed_balance_of_plant_load_W
    electrode_area = max(2.0pi * geometry.radius * 2.0geometry.half_length,
        1.0e-9) * target_area_multiplier
    electrode_heat_flux = (stored_energy - fusion_energy_per_shot) * repetition /
        max(electrode_area, 1.0e-9)
    neutron_wall_load = 0.80fusion_power / max(geometry.area, 1.0e-9)
    base = contract.base
    margins = Dict{String,Float64}(
        "experimental_stored_energy_domain" => min(
            (stored_energy - 100.0) / 1000.0,
            (1.30e6 - stored_energy) / 0.30e6),
        "experimental_peak_current_domain" => min(
            (current - 0.10e6) / 0.10e6,
            (3.60e6 - current) / 0.60e6),
        "yield_scaling_saturation" => 0.0,
        "optimistic_q_ceiling" => optimistic_q_ceiling - 0.01,
        "fusion_gain" => optimistic_q_ceiling - 1.0,
        "net_electric_power" => net_power /
            max(base.fixed_balance_of_plant_load_W, 1.0),
        "outer_radial_envelope" => geometry.radial_margin /
            max(contract.outer_radial_extent_m, 1.0e-9),
        "outer_axial_envelope" => geometry.axial_margin /
            max(contract.outer_axial_half_extent_m, 1.0e-9),
        "electrode_heat_flux" =>
            (contract.maximum_exhaust_heat_flux_W_m2 - electrode_heat_flux) /
                contract.maximum_exhaust_heat_flux_W_m2,
        "neutron_wall_load" =>
            (base.maximum_neutron_wall_load_W_m2 - neutron_wall_load) /
                base.maximum_neutron_wall_load_W_m2,
        "electrode_lifetime_and_repetition_evidence" => -1.0)
    physics_ids = ["experimental_stored_energy_domain",
        "experimental_peak_current_domain", "yield_scaling_saturation"]
    engineering_ids = ["outer_radial_envelope", "outer_axial_envelope",
        "electrode_heat_flux", "neutron_wall_load",
        "electrode_lifetime_and_repetition_evidence"]
    return Dict{String,Any}(
        "family" => "dense_plasma_focus",
        "mechanism" => "dpf_experimental_saturation_anchor",
        "plasma_minor_radius_m" => geometry.radius,
        "plasma_volume_m3" => geometry.volume, "first_wall_area_m2" => geometry.area,
        "outer_radial_margin_m" => geometry.radial_margin,
        "outer_axial_margin_m" => geometry.axial_margin,
        "stored_energy_per_shot_J" => stored_energy,
        "peak_current_A" => current, "repetition_rate_Hz" => repetition,
        "availability" => availability, "optimistic_q_ceiling" => optimistic_q_ceiling,
        "fusion_energy_per_shot_J" => fusion_energy_per_shot,
        "fusion_power_W" => fusion_power, "wall_electric_input_W" => wall_power,
        "net_electric_power_W" => net_power,
        "electrode_heat_flux_W_m2" => electrode_heat_flux,
        "neutron_wall_load_W_m2" => neutron_wall_load,
        "physics_gate_passed" => all(margins[id] >= 0.0 for id in physics_ids),
        "engineering_gate_passed" =>
            all(margins[id] >= 0.0 for id in engineering_ids),
        "margins" => margins,
        "minimum_normalized_margin" => minimum(Base.values(margins)),
        "unbounded_current_power_law_used" => false,
        "experimental_neutron_production_credited" => true,
        "anchor_only" => true,
        "composition" => Dict(
            "core_family" => "dense_plasma_focus",
            "stability_or_sustainment" => "dpf_experimental_saturation_anchor",
            "exhaust_topology" => "pulsed_electrode_chamber"))
end

function _cbv12_nominal(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features = _oe_features(genome),
        values = nothing; kwargs...)
    if _cbv12_is_two_component_gdt(genome, values)
        return _cbv12_two_component_gdt_nominal(genome, contract, features,
            values; kwargs...)
    elseif genome.family == "inertial_electrostatic_confinement"
        return _cbv12_iec_nominal(genome, contract, features, values; kwargs...)
    elseif genome.family == "dense_plasma_focus"
        return _cbv12_dpf_nominal(genome, contract, features, values; kwargs...)
    end
    return _olv11_nominal(genome, contract, features, values; kwargs...)
end

function _cbv12_graph_errors(genome::Genome, features,
        contract::SharedOuterEnvelopeContractV1)
    errors = copy(validate_genome(genome).errors)
    _ccv9_contract_errors!(errors, genome, contract)
    if _cbv12_is_two_component_gdt(genome)
        genome.topology.field_line_class == "open_mirror" ||
            push!(errors, "v12 two-component GDT requires open mirror field lines")
        count(region -> region.kind == "gas_dynamic_target_plasma",
            genome.plasma_regions) == 1 ||
            push!(errors, "v12 requires one collisional warm target region")
        count(region -> region.kind == "anisotropic_fast_ion_population",
            genome.plasma_regions) == 1 ||
            push!(errors, "v12 requires one anisotropic fast-ion region")
        any(actuator -> actuator.id == "v12_gdt_neutral_beam", genome.actuators) ||
            push!(errors, "v12 two-component GDT requires explicit neutral beams")
        geometry = _olv11_gdt_geometry(genome, features, contract)
        for region in filter(region -> region.kind in
                ("gas_dynamic_target_plasma", "anisotropic_fast_ion_population"),
                genome.plasma_regions)
            for (name, expected) in (("plasma_radius", geometry.a),
                    ("half_length", geometry.central_half))
                value = get(region.parameters, name, nothing)
                (value !== nothing && value.unit == "m" &&
                    isapprox(value.value, expected; rtol = 1.0e-9, atol = 1.0e-9)) ||
                    push!(errors, "$(region.id).$name is inconsistent with scored v12 GDT geometry")
            end
        end
    elseif genome.family == "inertial_electrostatic_confinement"
        genome.topology.field_line_class == "electrostatic_radial" ||
            push!(errors, "v12 IEC requires electrostatic_radial topology")
        count(source -> source.kind == "electrostatic_grid", genome.field_sources) >= 1 ||
            push!(errors, "v12 IEC requires an explicit electrostatic grid")
        any(actuator -> actuator.id == "v12_iec_hv_supply", genome.actuators) ||
            push!(errors, "v12 IEC requires an explicit high-voltage supply")
        geometry = _cbv12_geometry(features, contract; extra_build_m = 0.10)
        fraction = _cbv12_target(genome,
            "screen_cbv12_iec_grid_radius_fraction", 0.25, "1")
        expected_grid_radius = geometry.radius * fraction
        core = only(filter(region -> region.kind == "iec_acceleration_core",
            genome.plasma_regions))
        for (name, expected) in (("chamber_radius", geometry.radius),
                ("grid_radius", expected_grid_radius))
            value = get(core.parameters, name, nothing)
            (value !== nothing && value.unit == "m" &&
                isapprox(value.value, expected; rtol = 1.0e-9, atol = 1.0e-9)) ||
                push!(errors, "$(core.id).$name is inconsistent with scored v12 IEC geometry")
        end
    elseif genome.family == "dense_plasma_focus"
        genome.topology.field_line_class == "coaxial_pulsed_pinch" ||
            push!(errors, "v12 DPF requires coaxial_pulsed_pinch topology")
        count(source -> source.kind == "coaxial_electrode", genome.field_sources) >= 1 ||
            push!(errors, "v12 DPF requires explicit coaxial electrodes")
        any(actuator -> actuator.id == "v12_dpf_capacitor_driver", genome.actuators) ||
            push!(errors, "v12 DPF requires an explicit capacitor-bank driver")
        geometry = _cbv12_geometry(features, contract; axial = true,
            extra_build_m = 0.20)
        discharge = only(filter(region -> region.kind == "dpf_coaxial_discharge",
            genome.plasma_regions))
        for (name, expected) in (("anode_radius", geometry.radius),
                ("anode_half_length", geometry.half_length))
            value = get(discharge.parameters, name, nothing)
            (value !== nothing && value.unit == "m" &&
                isapprox(value.value, expected; rtol = 1.0e-9, atol = 1.0e-9)) ||
                push!(errors, "$(discharge.id).$name is inconsistent with scored v12 DPF geometry")
        end
    end
    return sort!(unique(errors))
end

function _cbv12_robustness(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features)
    rng = MersenneTwister(contract.base.robustness_seed)
    records = Dict{String,Any}[]
    pass_count = 0
    worst_margin = Inf
    for sample in 1:contract.base.robustness_samples
        field_delta = 0.02 * (2.0rand(rng) - 1.0)
        beta_delta = 0.15 * (2.0rand(rng) - 1.0)
        dimension_delta = 0.01 * (2.0rand(rng) - 1.0)
        actuator_error = 0.10 * (2.0rand(rng) - 1.0)
        target_occlusion = 0.10rand(rng)
        mechanism_error = 0.15 * (2.0rand(rng) - 1.0)
        nominal = _cbv12_nominal(genome, contract, features, nothing;
            field_multiplier = 1.0 + field_delta,
            beta_multiplier = 1.0 + beta_delta,
            dimension_multiplier = 1.0 + dimension_delta,
            actuator_multiplier = 1.0 + actuator_error,
            target_area_multiplier = 1.0 - target_occlusion,
            mechanism_multiplier = 1.0 + mechanism_error)
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

function _causal_bridge_result(evaluator::CausalBridgeScreenV1, genome::Genome)
    contract = evaluator.contract
    contract_dict = _oe_contract_dict(contract)
    contract_hash = canonical_hash(contract_dict)
    features = _cbv12_features(genome)
    graph_errors = _cbv12_graph_errors(genome, features, contract)
    graph_gate = isempty(graph_errors)
    nominal = _cbv12_nominal(genome, contract, features)
    robustness = if graph_gate && nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true
        _cbv12_robustness(genome, contract, features)
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
        "claim_boundary" => _CBV12_SCREEN_CLAIM_BOUNDARY,
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
        "positive_net_power_closure_passed" =>
            nominal["net_electric_power_W"] > 0.0,
        "classification" => all_five ?
            "v12_survivor_pending_family_specific_medium_fidelity" :
            "obviously_infeasible_or_unresolved",
        "device_complexity_proxy" => complexity)
    result["result_hash"] = canonical_hash(result)
    return result
end

function run_evaluator(evaluator::CausalBridgeScreenV1, genome::Genome; kwargs...)
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return _non_applicable_bundle(evaluator_spec(evaluator), genome, reason)
    result = _causal_bridge_result(evaluator, genome)
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "evaluator" => "causal_bridge_screen_v1",
        "version" => "1.0.0", "result_hash" => result["result_hash"]))
    status = result["all_five_gates_passed"] === true ? :pass : :fail
    metric = MetricResult("causal_bridge_five_gate_pass",
        result["all_five_gates_passed"] ? 1.0 : 0.0;
        fidelity = 0, applicability = reason, status = status,
        constraints_checked = sort!(collect(keys(result["gates"]))),
        solver_name = "causal_bridge_screen_v1", solver_version = "1.0.0",
        input_hash = genome.physics_hash, run_hash = run_hash,
        source_basis = _CBV12_SOURCE_BASIS,
        warnings = [_CBV12_SCREEN_CLAIM_BOUNDARY])
    return EvaluationBundle("causal_bridge_screen_v1", genome.design_id,
        genome.family, 0, status, [metric], [_CBV12_SCREEN_CLAIM_BOUNDARY],
        genome.physics_hash, run_hash, _CBV12_SCREEN_CLAIM_BOUNDARY)
end
