const _OLV11_SCREEN_CLAIM_BOUNDARY =
    "Fidelity-0 open-loss-pathway rejection screen. V10 controls retain their sealed equations. " *
    "Gas-dynamic and multiple-mirror branches derive Coulomb collisionality from the searched " *
    "state, retain a Bohm-reference transverse-loss channel, bound any corrugated-section axial " *
    "credit, and charge beams, bias electrodes, coils, expanders, and collectors. The high-beta " *
    "cusp branch credits only experimentally supported electron confinement; high-beta ion " *
    "confinement and persistence of a quasineutral electrostatic well remain blocking gates. " *
    "Passing establishes neither equilibrium, all-mode stability, transport, component lifetime, " *
    "net electricity, novelty, nor superiority."

const _OLV11_SOURCE_BASIS = String[
    "open_traps_ryutov_1988",
    "multiple_mirror_logan_1974",
    "gdt_bagryansky_2019",
    "golnb_postupaev_2026",
    "nrl_plasma_formulary_2023",
    "high_beta_cusp_park_2015",
    "polywell_potential_cornish_2014",
    "cusp_loss_jiang_2020",
]

"Append-only v11 evaluator; v10 source and artifact hashes remain unchanged."
struct OpenLossPathwayScreenV1 <: AbstractEvaluator
    contract::SharedOuterEnvelopeContractV1
    allowed_contract_hashes::Set{String}
end

function OpenLossPathwayScreenV1(contract::SharedOuterEnvelopeContractV1;
        allowed_contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    hashes = Set(canonical_hash(_oe_contract_dict(item)) for item in allowed_contracts)
    return OpenLossPathwayScreenV1(contract, hashes)
end

function evaluator_spec(::OpenLossPathwayScreenV1)
    return EvaluatorSpec("open_loss_pathway_screen_v1", "1.0.0",
        ["tokamak_axisymmetric", "tokamak_3d_hybrid", "stellarator",
            "magnetic_mirror", "sheared_flow_z_pinch", "high_beta_magnetic_cusp",
            "field_reversed_configuration", "spheromak"], 0,
        Dict(
            "topology_compatibility" => :proxy,
            "gas_dynamic_end_loss" => :proxy,
            "coulomb_collisionality" => :proxy,
            "multiple_mirror_axial_flow" => :proxy,
            "transverse_loss_floor" => :proxy,
            "high_beta_cusp_electron_confinement" => :proxy,
            "electrostatic_well_inventory" => :proxy,
            "cusp_loss_aperture" => :proxy,
            "power_balance" => :proxy,
            "finite_build" => :proxy,
            "exhaust" => :proxy,
            "manufacturing_tolerance" => :proxy),
        _OLV11_SCREEN_CLAIM_BOUNDARY)
end

function evaluator_applicability(evaluator::OpenLossPathwayScreenV1,
        genome::Genome)
    genome.family in evaluator_spec(evaluator).families || return false,
        "open-loss-pathway v11 does not cover family $(genome.family)"
    genome.mission.fuel == "D-T" || return false,
        "open-loss-pathway v11 is restricted to D-T"
    if genome.family == "high_beta_magnetic_cusp"
        genome.topology.field_line_class == "open_cusp" || return false,
            "high-beta cusp requires open_cusp field lines"
        genome.symmetry.class in ("none", "mixed") || return false,
            "polyhedral cusp must declare none or mixed symmetry"
        return true, "high-beta cusp under $(evaluator.contract.id)"
    end
    family = validate_family(default_family_registry(), genome)
    family.valid || return false, join(family.errors, "; ")
    return true, "v10 control or gas-dynamic mirror under $(evaluator.contract.id)"
end

_olv11_target(genome::Genome, name::String, default::Real, unit::String) =
    _oe_target(genome, name, default, unit)

function _olv11_value(genome::Genome, values, name::String, default::Real,
        unit::String)
    values !== nothing && haskey(values, name) && return Float64(values[name])
    return _olv11_target(genome, name, default, unit)
end

_olv11_is_gdt(genome::Genome, values = nothing) = genome.family == "magnetic_mirror" &&
    _olv11_value(genome, values, "screen_olv11_gdt_active", 0.0, "1") > 0.5

function _olv11_mechanism(genome::Genome, values = nothing)
    if genome.family == "high_beta_magnetic_cusp"
        ratio = _olv11_value(genome, values,
            "screen_olv11_cusp_well_temperature_ratio", 0.0, "1")
        return ratio > 0.0 ? "high_beta_cusp_electrostatic_ion_candidate" :
            "high_beta_cusp_electron_anchor"
    elseif _olv11_is_gdt(genome, values)
        cells = round(Int, _olv11_value(genome, values,
            "screen_olv11_cell_count", 1.0, "1"))
        return cells > 1 ? "gas_dynamic_multimirror" : "gas_dynamic_single_cell"
    end
    return _mev10_mechanism(genome)
end

function _olv11_gdt_geometry(genome::Genome, features,
        contract::SharedOuterEnvelopeContractV1, values = nothing;
        dimension_multiplier::Float64 = 1.0)
    base = contract.base
    pack = features.coil_pack_thickness_m
    support = features.support_thickness_m
    converter_build = _olv11_value(genome, values,
        "screen_olv11_converter_build", 0.0, "m")
    build = base.shield_thickness_m + base.maintenance_gap_m + pack + support +
        converter_build
    radial_capacity = contract.outer_radial_extent_m - build
    a = max(0.01, features.plasma_fill_fraction * dimension_multiplier *
        radial_capacity)
    central_aspect = _olv11_value(genome, values,
        "screen_olv11_central_aspect_ratio", 4.0, "1")
    central_half = central_aspect * a
    cells = max(1, round(Int, _olv11_value(genome, values,
        "screen_olv11_cell_count", 1.0, "1")))
    cell_length = _olv11_value(genome, values,
        "screen_olv11_cell_length", 0.20, "m")
    corrugated_length_each = cells > 1 ? cells * cell_length : 0.0
    total_half = central_half + corrugated_length_each
    volume = 2.0 * pi * a^2 * central_half
    first_wall_area = 4.0 * pi * a * central_half + 2.0 * pi * a^2
    return (a = a, central_half = central_half, total_half = total_half,
        cells = cells, cell_length = cell_length,
        corrugated_length_each = corrugated_length_each,
        volume = volume, area = first_wall_area, build = build,
        radial_margin = contract.outer_radial_extent_m - (a + build),
        axial_margin = contract.outer_axial_half_extent_m - (total_half + build))
end

function _olv11_ion_collision_scales(temperature_keV::Float64,
        density_m3::Float64)
    # NRL 2023 hydrogenic-ion collision-time form. Density is converted to cm^-3,
    # temperature to eV, and the D-T mean mass number is 2.5. lnLambda=15 is
    # recorded as an uncertain fidelity-0 reference rather than a fitted gene.
    temperature_eV = 1.0e3 * temperature_keV
    density_cm3 = density_m3 * 1.0e-6
    coulomb_log = 15.0
    mean_mass_number = 2.5
    tau_ii = 2.09e7 * sqrt(mean_mass_number) * temperature_eV^1.5 /
        max(density_cm3 * coulomb_log, 1.0e-30)
    ion_mass = mean_mass_number * 1.66053906660e-27
    thermal_speed = sqrt(2.0 * temperature_keV * 1.602176634e-16 / ion_mass)
    return (collision_time_s = tau_ii,
        thermal_speed_m_s = thermal_speed,
        mean_free_path_m = tau_ii * thermal_speed,
        coulomb_log = coulomb_log,
        mean_mass_number = mean_mass_number)
end

function _olv11_gdt_nominal(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features, values = nothing;
        field_multiplier::Float64 = 1.0,
        beta_multiplier::Float64 = 1.0,
        dimension_multiplier::Float64 = 1.0,
        actuator_multiplier::Float64 = 1.0,
        target_area_multiplier::Float64 = 1.0,
        mechanism_multiplier::Float64 = 1.0,
        converter_multiplier::Float64 = 1.0)
    mu0 = 4.0e-7pi
    elementary_charge = 1.602176634e-19
    geometry = _olv11_gdt_geometry(genome, features, contract, values;
        dimension_multiplier = dimension_multiplier)
    B = contract.plasma_field_T * field_multiplier
    beta = features.beta * beta_multiplier
    temperature_keV = features.temperature_keV
    temperature_J = temperature_keV * 1.602176634e-16
    pressure = beta * B^2 / (2.0mu0)
    density = pressure / max(2.0temperature_J, 1.0e-30)
    reactivity = _dt_reactivity_m3_s(temperature_keV)
    valid_reactivity = isfinite(reactivity)
    fusion_density = valid_reactivity ? 0.25density^2 * reactivity *
        17.6e6 * elementary_charge : 0.0
    fusion_power = fusion_density * geometry.volume
    alpha_power = 0.20fusion_power
    stored_energy = 1.5pressure * geometry.volume
    collision = _olv11_ion_collision_scales(temperature_keV, density)
    mirror_ratio = _olv11_value(genome, values,
        "screen_mirror_ratio", features.mirror_ratio, "1")
    gas_dynamic_parameter = 2.0geometry.central_half * mirror_ratio /
        max(collision.mean_free_path_m, 1.0e-30)
    cell_collisionality = geometry.cell_length /
        max(collision.mean_free_path_m, 1.0e-30)
    applicability = geometry.cells > 1 ?
        exp(-abs(log(max(cell_collisionality, 1.0e-12)))) : 0.0
    ideal_cell_credit = geometry.cells > 1 ? min(geometry.cells, 12) : 1
    # GOL-NB has not demonstrated ideal N or N^2 reactor scaling. The analytic
    # rejection credit is capped at 4 and reduced continuously outside nu*=1.
    axial_suppression = geometry.cells > 1 ?
        min(4.0, 1.0 + 0.35 * (ideal_cell_credit - 1) * applicability *
            mechanism_multiplier) : 1.0
    tau_axial_unmodified = 2.0geometry.central_half * mirror_ratio /
        max(collision.thermal_speed_m_s, 1.0)
    tau_axial = tau_axial_unmodified * axial_suppression
    bohm_diffusivity = temperature_J /
        max(16.0elementary_charge * B, 1.0e-30)
    tau_transverse = geometry.a^2 * max(features.field_quality, 0.05) /
        max(bohm_diffusivity, 1.0e-30)
    axial_loss = stored_energy / max(tau_axial, 1.0e-30)
    transverse_loss = stored_energy / max(tau_transverse, 1.0e-30)
    total_loss = axial_loss + transverse_loss
    beam_power = _olv11_value(genome, values,
        "screen_olv11_nbi_power", 0.0, "W")
    bias_power = _olv11_value(genome, values,
        "screen_olv11_bias_power", 0.0, "W")
    declared_actuator = actuator_multiplier * _olv11_value(genome, values,
        "screen_declared_actuator_power", 0.0, "W")
    explicit_actuator = beam_power + bias_power
    charged_actuator = max(declared_actuator, explicit_actuator)
    transport_auxiliary = max(0.0, total_loss - alpha_power)
    total_auxiliary = transport_auxiliary + charged_actuator
    recovery_fraction = clamp(converter_multiplier * _olv11_value(genome, values,
        "screen_olv11_recovery_fraction", 0.0, "1"), 0.0, 0.35)
    recovered_electric = recovery_fraction * axial_loss
    fusion_gain = fusion_power / max(total_auxiliary, 1.0)
    net_power = contract.base.thermal_conversion_efficiency * fusion_power +
        recovered_electric - total_auxiliary /
        contract.base.heating_wall_plug_efficiency -
        contract.base.fixed_balance_of_plant_load_W
    target_area = 2.0pi * geometry.a^2 *
        max(features.exhaust_flux_expansion, 1.0) * target_area_multiplier
    target_heat_flux = axial_loss / max(target_area, 1.0e-9)
    transverse_wall_heat_flux = transverse_loss / max(geometry.area, 1.0e-9)
    neutron_wall_load = 0.80fusion_power / max(geometry.area, 1.0e-9)
    peak_field = B * mirror_ratio
    current_density = peak_field /
        (mu0 * max(features.coil_pack_thickness_m, 0.02)) / 1.0e6
    support_stress = peak_field^2 / (2.0mu0) * geometry.a /
        max(features.support_thickness_m, 0.05)
    particle_loss = min(1.0, 1.0 / max(mirror_ratio * axial_suppression, 1.0))
    converter_build = _olv11_value(genome, values,
        "screen_olv11_converter_build", 0.0, "m")
    converter_voltage = _olv11_value(genome, values,
        "screen_olv11_converter_voltage", 0.0, "V")
    grid_field = converter_voltage / max(converter_build, 1.0e-6)
    base = contract.base
    margins = Dict{String,Float64}(
        "temperature_domain" => min((temperature_keV - 5.0) / 5.0,
            (30.0 - temperature_keV) / 5.0),
        "gas_dynamic_collisionality" => gas_dynamic_parameter - 1.0,
        "multiple_mirror_cell_collisionality" => geometry.cells > 1 ?
            min((cell_collisionality - 0.10) / 0.10,
                (3.0 - cell_collisionality) / 1.0) : 1.0,
        "multiple_mirror_credit_cap" => (4.0 - axial_suppression) / 3.0,
        "transverse_loss_floor" => (tau_transverse - tau_axial) /
            max(tau_axial, 1.0e-30),
        "minimum_b_and_vortex_stability" => min(
            (features.minimum_b_strength - 0.60) / 0.40,
            (features.shear_strength - 0.30) / 0.30),
        "particle_loss" => (0.25 - particle_loss) / 0.25,
        "fusion_gain" => fusion_gain - 1.0,
        "auxiliary_power" => (base.auxiliary_heating_budget_W - total_auxiliary) /
            base.auxiliary_heating_budget_W,
        "explicit_actuator_authority" => (declared_actuator - explicit_actuator) /
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
            (contract.maximum_exhaust_heat_flux_W_m2 - transverse_wall_heat_flux) /
            contract.maximum_exhaust_heat_flux_W_m2,
        "direct_converter_energy_conservation" =>
            (axial_loss - recovered_electric) / max(axial_loss, 1.0),
        "direct_converter_grid_field" => recovery_fraction > 0.0 ?
            (20.0e6 - grid_field) / 20.0e6 : 1.0)
    physics_ids = ["temperature_domain", "gas_dynamic_collisionality",
        "multiple_mirror_cell_collisionality", "multiple_mirror_credit_cap",
        "transverse_loss_floor", "minimum_b_and_vortex_stability",
        "particle_loss", "fusion_gain", "auxiliary_power",
        "explicit_actuator_authority", "net_electric_power"]
    engineering_ids = ["peak_conductor_field", "engineering_current_density",
        "support_stress", "outer_radial_envelope", "outer_axial_envelope",
        "coil_curvature", "neutron_wall_load", "end_target_heat_flux",
        "transverse_wall_heat_flux", "direct_converter_energy_conservation",
        "direct_converter_grid_field"]
    return Dict{String,Any}(
        "family" => "magnetic_mirror",
        "major_radius_or_half_length_m" => geometry.central_half,
        "plasma_minor_radius_m" => geometry.a,
        "plasma_half_height_or_half_length_m" => geometry.central_half,
        "total_magnetic_half_length_m" => geometry.total_half,
        "plasma_volume_m3" => geometry.volume,
        "first_wall_area_m2" => geometry.area,
        "radial_build_m" => geometry.build,
        "outer_radial_margin_m" => geometry.radial_margin,
        "outer_axial_margin_m" => geometry.axial_margin,
        "beta" => beta, "temperature_keV" => temperature_keV,
        "pressure_Pa" => pressure, "density_m3" => density,
        "fusion_power_W" => fusion_power, "alpha_power_W" => alpha_power,
        "stored_energy_MJ" => stored_energy / 1.0e6,
        "energy_confinement_time_s" => 1.0 /
            (1.0 / max(tau_axial, 1.0e-30) + 1.0 / max(tau_transverse, 1.0e-30)),
        "gas_dynamic_axial_time_s" => tau_axial,
        "bohm_reference_transverse_time_s" => tau_transverse,
        "ion_collision_time_s" => collision.collision_time_s,
        "ion_mean_free_path_m" => collision.mean_free_path_m,
        "coulomb_log_reference" => collision.coulomb_log,
        "gas_dynamic_parameter" => gas_dynamic_parameter,
        "cell_collisionality" => cell_collisionality,
        "multiple_mirror_cell_count" => geometry.cells,
        "multiple_mirror_axial_suppression" => axial_suppression,
        "ideal_N_or_N_squared_performance_transplanted" => false,
        "transport_loss_power_W" => total_loss,
        "axial_loss_power_W" => axial_loss,
        "transverse_loss_power_W" => transverse_loss,
        "declared_actuator_power_W" => declared_actuator,
        "explicit_mechanism_actuator_requirement_W" => explicit_actuator,
        "required_auxiliary_power_W" => total_auxiliary,
        "fusion_gain_proxy" => fusion_gain,
        "net_electric_power_W" => net_power,
        "particle_loss_fraction_proxy" => particle_loss,
        "minimum_stability_margin_proxy" =>
            margins["minimum_b_and_vortex_stability"],
        "target_count" => 2, "effective_target_area_m2" => target_area,
        "exhaust_heat_flux_W_m2" => target_heat_flux,
        "transverse_wall_heat_flux_W_m2" => transverse_wall_heat_flux,
        "neutron_wall_load_W_m2" => neutron_wall_load,
        "peak_conductor_field_T" => peak_field,
        "engineering_current_density_A_mm2" => current_density,
        "support_stress_proxy_Pa" => support_stress,
        "direct_converter_recovery_fraction" => recovery_fraction,
        "direct_converter_recovered_electric_power_W" => recovered_electric,
        "charged_end_loss_power_W" => axial_loss,
        "physics_gate_passed" => valid_reactivity &&
            all(margins[id] >= 0.0 for id in physics_ids),
        "engineering_gate_passed" =>
            all(margins[id] >= 0.0 for id in engineering_ids),
        "margins" => margins,
        "minimum_normalized_margin" => minimum(Base.values(margins)),
        "experimental_performance_multiplier_used" => false,
        "composition" => Dict(
            "core_family" => "magnetic_mirror",
            "stability_or_sustainment" => _olv11_mechanism(genome, values),
            "exhaust_topology" => recovery_fraction > 0.0 ?
                "two_end_bounded_direct_converter" : "two_end_expander",
            "loss_model" => "gas_dynamic_axial_plus_bohm_reference_transverse"))
end

function _olv11_cusp_geometry(features,
        contract::SharedOuterEnvelopeContractV1;
        dimension_multiplier::Float64 = 1.0)
    base = contract.base
    build = base.shield_thickness_m + base.maintenance_gap_m +
        features.coil_pack_thickness_m + features.support_thickness_m
    capacity = min(contract.outer_radial_extent_m - build,
        contract.outer_axial_half_extent_m - build)
    a = max(0.01, features.plasma_fill_fraction * dimension_multiplier * capacity)
    volume = 4.0pi * a^3 / 3.0
    area = 4.0pi * a^2
    return (a = a, volume = volume, area = area, build = build,
        radial_margin = contract.outer_radial_extent_m - (a + build),
        axial_margin = contract.outer_axial_half_extent_m - (a + build))
end

function _olv11_cusp_nominal(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features, values = nothing;
        field_multiplier::Float64 = 1.0,
        beta_multiplier::Float64 = 1.0,
        dimension_multiplier::Float64 = 1.0,
        actuator_multiplier::Float64 = 1.0,
        target_area_multiplier::Float64 = 1.0,
        mechanism_multiplier::Float64 = 1.0)
    mu0 = 4.0e-7pi
    epsilon0 = 8.8541878128e-12
    elementary_charge = 1.602176634e-19
    electron_mass = 9.1093837139e-31
    ion_mass = 2.5 * 1.66053906660e-27
    geometry = _olv11_cusp_geometry(features, contract;
        dimension_multiplier = dimension_multiplier)
    B = contract.plasma_field_T * field_multiplier
    beta = features.beta * beta_multiplier
    temperature_keV = features.temperature_keV
    temperature_J = temperature_keV * 1.602176634e-16
    pressure = beta * B^2 / (2.0mu0)
    density = pressure / max(2.0temperature_J, 1.0e-30)
    reactivity = _dt_reactivity_m3_s(temperature_keV)
    valid_reactivity = isfinite(reactivity)
    potential_ratio = _olv11_value(genome, values,
        "screen_olv11_cusp_well_temperature_ratio", 0.0, "1")
    ion_candidate = potential_ratio > 0.0
    # The electron-only high-beta anchor receives no D-T fusion-output credit.
    fusion_density = ion_candidate && valid_reactivity ?
        0.25density^2 * reactivity * 17.6e6 * elementary_charge : 0.0
    fusion_power = fusion_density * geometry.volume
    alpha_power = 0.20fusion_power
    stored_energy = 1.5pressure * geometry.volume
    cusp_count = max(6, round(Int, _olv11_value(genome, values,
        "screen_olv11_cusp_count", 6.0, "1")))
    ion_speed = sqrt(2.0temperature_J / ion_mass)
    electron_speed = sqrt(2.0temperature_J / electron_mass)
    ion_gyroradius = ion_mass * ion_speed /
        max(elementary_charge * B, 1.0e-30)
    electron_gyroradius = electron_mass * electron_speed /
        max(elementary_charge * B, 1.0e-30)
    aperture_width = max(2.0ion_gyroradius, 2.0electron_gyroradius)
    cusp_loss_area = cusp_count * pi * aperture_width^2
    ion_loss_time = 4.0geometry.volume /
        max(cusp_loss_area * ion_speed, 1.0e-30)
    charged_loss = stored_energy / max(ion_loss_time, 1.0e-30)
    beam_voltage = _olv11_value(genome, values,
        "screen_olv11_cusp_beam_voltage", 0.0, "V")
    beam_current = _olv11_value(genome, values,
        "screen_olv11_cusp_beam_current", 0.0, "A")
    replenish_time = _olv11_value(genome, values,
        "screen_olv11_cusp_well_replenishment_time", 1.0e-4, "s")
    well_voltage = potential_ratio * temperature_keV * 1.0e3
    capacitance = 4.0pi * epsilon0 * geometry.a
    well_inventory = 0.5capacitance * well_voltage^2
    inventory_power = well_inventory / max(replenish_time, 1.0e-9)
    beam_electric_power = beam_voltage * beam_current
    explicit_actuator = max(beam_electric_power, inventory_power)
    declared_actuator = actuator_multiplier * _olv11_value(genome, values,
        "screen_declared_actuator_power", 0.0, "W")
    transport_auxiliary = max(0.0, charged_loss - alpha_power)
    total_auxiliary = transport_auxiliary + max(declared_actuator, explicit_actuator)
    fusion_gain = fusion_power / max(total_auxiliary, 1.0)
    net_power = contract.base.thermal_conversion_efficiency * fusion_power -
        total_auxiliary / contract.base.heating_wall_plug_efficiency -
        contract.base.fixed_balance_of_plant_load_W
    collector_area = cusp_count * pi * (0.25geometry.a)^2 *
        max(features.exhaust_flux_expansion, 1.0) * target_area_multiplier
    collector_heat_flux = charged_loss / max(collector_area, 1.0e-9)
    neutron_wall_load = 0.80fusion_power / max(geometry.area, 1.0e-9)
    peak_field = 1.50B
    current_density = peak_field /
        (mu0 * max(features.coil_pack_thickness_m, 0.02)) / 1.0e6
    support_stress = peak_field^2 / (2.0mu0) * geometry.a /
        max(features.support_thickness_m, 0.05)
    particle_loss = min(1.0, cusp_loss_area / max(geometry.area, 1.0e-30))
    base = contract.base
    margins = Dict{String,Float64}(
        "temperature_domain" => min((temperature_keV - 5.0) / 5.0,
            (30.0 - temperature_keV) / 5.0),
        "high_beta_electron_confinement_domain" => min(
            (beta - 0.80) / 0.20, (1.10 - beta) / 0.10),
        "high_beta_ion_confinement_evidence" => -1.0,
        "high_beta_quasineutral_well_persistence" => ion_candidate ? -1.0 : -2.0,
        "cusp_loss_model_validity" => -1.0,
        "beam_voltage_authority" => ion_candidate ?
            (beam_voltage - well_voltage) / max(well_voltage, 1.0) : 1.0,
        "well_inventory_replenishment" => ion_candidate ?
            (declared_actuator - explicit_actuator) /
                base.auxiliary_heating_budget_W : 1.0,
        "particle_loss" => (0.25 - particle_loss) / 0.25,
        "fusion_gain" => fusion_gain - 1.0,
        "auxiliary_power" => (base.auxiliary_heating_budget_W - total_auxiliary) /
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
        "cusp_collector_heat_flux" =>
            (contract.maximum_exhaust_heat_flux_W_m2 - collector_heat_flux) /
            contract.maximum_exhaust_heat_flux_W_m2)
    physics_ids = ["temperature_domain", "high_beta_electron_confinement_domain",
        "high_beta_ion_confinement_evidence",
        "high_beta_quasineutral_well_persistence", "cusp_loss_model_validity",
        "beam_voltage_authority", "well_inventory_replenishment", "particle_loss",
        "fusion_gain", "auxiliary_power", "net_electric_power"]
    engineering_ids = ["peak_conductor_field", "engineering_current_density",
        "support_stress", "outer_radial_envelope", "outer_axial_envelope",
        "coil_curvature", "neutron_wall_load", "cusp_collector_heat_flux"]
    return Dict{String,Any}(
        "family" => "high_beta_magnetic_cusp",
        "major_radius_or_half_length_m" => geometry.a,
        "plasma_minor_radius_m" => geometry.a,
        "plasma_half_height_or_half_length_m" => geometry.a,
        "plasma_volume_m3" => geometry.volume,
        "first_wall_area_m2" => geometry.area,
        "radial_build_m" => geometry.build,
        "outer_radial_margin_m" => geometry.radial_margin,
        "outer_axial_margin_m" => geometry.axial_margin,
        "beta" => beta, "temperature_keV" => temperature_keV,
        "pressure_Pa" => pressure, "density_m3" => density,
        "fusion_power_W" => fusion_power, "alpha_power_W" => alpha_power,
        "stored_energy_MJ" => stored_energy / 1.0e6,
        "energy_confinement_time_s" => ion_loss_time,
        "cusp_count" => cusp_count,
        "ion_gyroradius_m" => ion_gyroradius,
        "electron_gyroradius_m" => electron_gyroradius,
        "cusp_loss_aperture_area_m2" => cusp_loss_area,
        "cusp_loss_model_claim" => "kinetic-scale diagnostic only; high-beta ion loss unresolved",
        "electron_confinement_experiment_used_for_ion_credit" => false,
        "low_beta_well_experiment_transplanted_to_high_beta" => false,
        "transport_loss_power_W" => charged_loss,
        "declared_actuator_power_W" => declared_actuator,
        "explicit_mechanism_actuator_requirement_W" => explicit_actuator,
        "electrostatic_well_inventory_J" => well_inventory,
        "required_auxiliary_power_W" => total_auxiliary,
        "fusion_gain_proxy" => fusion_gain,
        "net_electric_power_W" => net_power,
        "particle_loss_fraction_proxy" => particle_loss,
        "minimum_stability_margin_proxy" =>
            margins["high_beta_electron_confinement_domain"],
        "target_count" => cusp_count,
        "effective_target_area_m2" => collector_area,
        "exhaust_heat_flux_W_m2" => collector_heat_flux,
        "neutron_wall_load_W_m2" => neutron_wall_load,
        "peak_conductor_field_T" => peak_field,
        "engineering_current_density_A_mm2" => current_density,
        "support_stress_proxy_Pa" => support_stress,
        "physics_gate_passed" => valid_reactivity && ion_candidate &&
            all(margins[id] >= 0.0 for id in physics_ids),
        "engineering_gate_passed" =>
            all(margins[id] >= 0.0 for id in engineering_ids),
        "margins" => margins,
        "minimum_normalized_margin" => minimum(Base.values(margins)),
        "experimental_performance_multiplier_used" => false,
        "composition" => Dict(
            "core_family" => "high_beta_magnetic_cusp",
            "stability_or_sustainment" => _olv11_mechanism(genome, values),
            "exhaust_topology" => "explicit_cusp_collectors",
            "evidence_credit" => "high_beta_high_energy_electron_confinement_only"))
end

function _olv11_nominal(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features = _oe_features(genome),
        values = nothing; kwargs...)
    genome.family == "high_beta_magnetic_cusp" &&
        return _olv11_cusp_nominal(genome, contract, features, values; kwargs...)
    _olv11_is_gdt(genome, values) &&
        return _olv11_gdt_nominal(genome, contract, features, values; kwargs...)
    return _mev10_nominal(genome, contract, features, values; kwargs...)
end

function _olv11_cusp_graph_errors(genome::Genome,
        contract::SharedOuterEnvelopeContractV1)
    errors = copy(validate_genome(genome).errors)
    genome.topology.field_line_class == "open_cusp" ||
        push!(errors, "v11 cusp requires open_cusp field lines")
    genome.topology.rotation_transform_sources == ["not_applicable"] ||
        push!(errors, "v11 cusp transform source must be not_applicable")
    count(region -> region.kind == "high_beta_cusp_core", genome.plasma_regions) == 1 ||
        push!(errors, "v11 cusp requires one high-beta cusp core")
    count(region -> region.kind == "divertor_or_exhaust_region",
        genome.plasma_regions) >= 1 ||
        push!(errors, "v11 cusp requires explicit cusp collectors")
    _ct_has_kind(genome.field_sources, "external_3d_coils") ||
        push!(errors, "v11 cusp requires explicit polyhedral cusp coils")
    any(actuator -> actuator.id == "v11_cusp_electron_injector", genome.actuators) ||
        push!(errors, "v11 cusp requires an explicit electron injector")
    isempty(setdiff(genome.exhaust.region_ids,
        getfield.(genome.plasma_regions, :id))) ||
        push!(errors, "v11 cusp exhaust references a missing collector")
    _ccv9_contract_errors!(errors, genome, contract)
    return sort!(unique(errors))
end

function _olv11_gdt_graph_errors(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features)
    errors = _mev10_graph_errors(genome, features, contract)
    count(region -> region.kind == "gas_dynamic_central_cell",
        genome.plasma_regions) == 1 ||
        push!(errors, "v11 GDT requires one explicit gas-dynamic central cell")
    count(region -> region.kind == "divertor_or_exhaust_region",
        genome.plasma_regions) == 2 ||
        push!(errors, "v11 GDT requires two explicit end receivers")
    any(actuator -> actuator.id == "v11_gdt_neutral_beam", genome.actuators) ||
        push!(errors, "v11 GDT requires explicit neutral-beam heating")
    any(actuator -> actuator.id == "v11_gdt_vortex_bias", genome.actuators) ||
        push!(errors, "v11 GDT requires explicit vortex-bias hardware")
    cells = round(Int, _olv11_target(genome,
        "screen_olv11_cell_count", 1.0, "1"))
    corrugated = count(source -> source.kind == "external_axisymmetric_coils" &&
        occursin("corrugated", source.geometry_model), genome.field_sources)
    cells > 1 && corrugated < 2 &&
        push!(errors, "v11 GDMT requires two explicit corrugated end sections")
    return sort!(unique(errors))
end

function _olv11_graph_errors(genome::Genome, features,
        contract::SharedOuterEnvelopeContractV1)
    genome.family == "high_beta_magnetic_cusp" &&
        return _olv11_cusp_graph_errors(genome, contract)
    _olv11_is_gdt(genome) &&
        return _olv11_gdt_graph_errors(genome, contract, features)
    return _mev10_graph_errors(genome, features, contract)
end

function _olv11_robustness(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features)
    !_olv11_is_gdt(genome) && genome.family != "high_beta_magnetic_cusp" &&
        return _mev10_robustness(genome, contract, features)
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
        nominal = _olv11_nominal(genome, contract, features, nothing;
            field_multiplier = 1.0 + field_delta,
            beta_multiplier = 1.0 + beta_delta,
            dimension_multiplier = 1.0 + dimension_delta,
            actuator_multiplier = 1.0 + actuator_error,
            target_area_multiplier = 1.0 - target_occlusion,
            mechanism_multiplier = 1.0 + mechanism_error)
        passed = nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true
        passed && (pass_count += 1)
        worst_margin = min(worst_margin,
            Float64(nominal["minimum_normalized_margin"]))
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

function _open_loss_pathway_result(evaluator::OpenLossPathwayScreenV1,
        genome::Genome)
    contract = evaluator.contract
    contract_dict = _oe_contract_dict(contract)
    contract_hash = canonical_hash(contract_dict)
    features = _oe_features(genome)
    graph_errors = _olv11_graph_errors(genome, features, contract)
    graph_gate = isempty(graph_errors)
    nominal = _olv11_nominal(genome, contract, features)
    robustness = if graph_gate && nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true
        _olv11_robustness(genome, contract, features)
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
        "claim_boundary" => _OLV11_SCREEN_CLAIM_BOUNDARY,
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
            "v11_survivor_pending_family_specific_medium_fidelity" :
            "obviously_infeasible_or_unresolved",
        "device_complexity_proxy" => complexity)
    result["result_hash"] = canonical_hash(result)
    return result
end

function run_evaluator(evaluator::OpenLossPathwayScreenV1, genome::Genome;
        kwargs...)
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return _non_applicable_bundle(evaluator_spec(evaluator), genome, reason)
    result = _open_loss_pathway_result(evaluator, genome)
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "evaluator" => "open_loss_pathway_screen_v1",
        "version" => "1.0.0", "result_hash" => result["result_hash"]))
    status = result["all_five_gates_passed"] === true ? :pass : :fail
    metric = MetricResult("open_loss_pathway_five_gate_pass",
        result["all_five_gates_passed"] ? 1.0 : 0.0;
        fidelity = 0, applicability = reason, status = status,
        constraints_checked = sort!(collect(keys(result["gates"]))),
        solver_name = "open_loss_pathway_screen_v1", solver_version = "1.0.0",
        input_hash = genome.physics_hash, run_hash = run_hash,
        source_basis = _OLV11_SOURCE_BASIS,
        warnings = [_OLV11_SCREEN_CLAIM_BOUNDARY])
    return EvaluationBundle("open_loss_pathway_screen_v1", genome.design_id,
        genome.family, 0, status, [metric], [_OLV11_SCREEN_CLAIM_BOUNDARY],
        genome.physics_hash, run_hash, _OLV11_SCREEN_CLAIM_BOUNDARY)
end
