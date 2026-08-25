const _OE_SCREEN_CLAIM_BOUNDARY =
    "Fidelity-0 shared-outer-envelope rejection screen. Every family is packed inside the same " *
    "declared radial and axial bounds at the same plasma field and material limits. Empirical or " *
    "dimensional confinement branches, simplified stability and particle-loss proxies, explicit " *
    "actuator power, finite target area, magnetic-pressure loads, and deterministic perturbations " *
    "do not establish equilibrium, all-mode stability, transport, exhaust, net electricity, or " *
    "reactor engineering feasibility."

"A true outer bounding box layered over the sealed common material and power assumptions."
struct SharedOuterEnvelopeContractV1
    id::String
    outer_radial_extent_m::Float64
    outer_axial_half_extent_m::Float64
    plasma_field_T::Float64
    maximum_exhaust_heat_flux_W_m2::Float64
    base::CommonComparisonContract

    function SharedOuterEnvelopeContractV1(id::AbstractString,
            outer_radial_extent_m::Real, outer_axial_half_extent_m::Real,
            plasma_field_T::Real, maximum_exhaust_heat_flux_W_m2::Real,
            base::CommonComparisonContract = default_common_comparison_contract())
        outer_radial_extent_m > 0 || throw(ArgumentError(
            "outer radial extent must be positive"))
        outer_axial_half_extent_m > 0 || throw(ArgumentError(
            "outer axial half extent must be positive"))
        plasma_field_T > 0 || throw(ArgumentError("plasma field must be positive"))
        maximum_exhaust_heat_flux_W_m2 > 0 || throw(ArgumentError(
            "maximum exhaust heat flux must be positive"))
        return new(String(id), Float64(outer_radial_extent_m),
            Float64(outer_axial_half_extent_m), Float64(plasma_field_T),
            Float64(maximum_exhaust_heat_flux_W_m2), base)
    end
end

function shared_outer_envelope_contracts_v1()
    base = default_common_comparison_contract()
    return SharedOuterEnvelopeContractV1[
        SharedOuterEnvelopeContractV1("outer_small_B3_v1", 8.0, 6.0, 3.0,
            10.0e6, base),
        SharedOuterEnvelopeContractV1("outer_small_B4_v1", 8.0, 6.0, 4.0,
            10.0e6, base),
        SharedOuterEnvelopeContractV1("outer_reference_B3_v1", 11.0, 7.0, 3.0,
            10.0e6, base),
        SharedOuterEnvelopeContractV1("outer_reference_B4_v1", 11.0, 7.0, 4.0,
            10.0e6, base),
        SharedOuterEnvelopeContractV1("outer_large_B3_v1", 14.0, 9.0, 3.0,
            10.0e6, base),
        SharedOuterEnvelopeContractV1("outer_large_B4_v1", 14.0, 9.0, 4.0,
            10.0e6, base),
    ]
end

function _oe_contract_dict(contract::SharedOuterEnvelopeContractV1)
    return Dict{String,Any}(
        "id" => contract.id,
        "outer_radial_extent_m" => contract.outer_radial_extent_m,
        "outer_axial_half_extent_m" => contract.outer_axial_half_extent_m,
        "plasma_field_T" => contract.plasma_field_T,
        "maximum_exhaust_heat_flux_W_m2" =>
            contract.maximum_exhaust_heat_flux_W_m2,
        "base_material_and_power_contract" => _common_contract_dict(contract.base),
    )
end

struct SharedOuterEnvelopeScreenV1 <: AbstractEvaluator
    contract::SharedOuterEnvelopeContractV1
    allowed_contract_hashes::Set{String}
end

function SharedOuterEnvelopeScreenV1(contract::SharedOuterEnvelopeContractV1;
        allowed_contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    hashes = Set(canonical_hash(_oe_contract_dict(item)) for item in allowed_contracts)
    return SharedOuterEnvelopeScreenV1(contract, hashes)
end

function evaluator_spec(::SharedOuterEnvelopeScreenV1)
    return EvaluatorSpec(
        "shared_outer_envelope_screen_v1", "1.0.0",
        ["tokamak_axisymmetric", "stellarator", "magnetic_mirror",
            "field_reversed_configuration", "spheromak"], 0,
        Dict(
            "equilibrium" => :proxy, "basic_constraints" => :proxy,
            "stability" => :proxy, "particle_loss" => :proxy,
            "energy_confinement" => :proxy, "power_balance" => :proxy,
            "finite_build_coils" => :proxy, "coil_stress" => :proxy,
            "shielding" => :proxy, "maintenance_access" => :proxy,
            "exhaust" => :proxy, "manufacturing_tolerance" => :proxy,
        ), _OE_SCREEN_CLAIM_BOUNDARY)
end

function evaluator_applicability(evaluator::SharedOuterEnvelopeScreenV1,
        genome::Genome)
    genome.family in evaluator_spec(evaluator).families || return false,
        "shared outer-envelope v1 does not cover family $(genome.family)"
    genome.mission.fuel == "D-T" || return false,
        "shared outer-envelope v1 is restricted to D-T"
    family = validate_family(default_family_registry(), genome)
    family.valid || return false, join(family.errors, "; ")
    return true, "same outer envelope $(evaluator.contract.id)"
end

function _oe_target(genome::Genome, name::String, default::Real, unit::String)
    value = get(genome.mission.targets, name, nothing)
    value === nothing && return Float64(default)
    value.unit == unit || throw(ArgumentError(
        "mission.targets.$name must use canonical unit $unit, got $(value.unit)"))
    return value.value
end

_oe_fraction(genome, name, default) =
    clamp(_oe_target(genome, name, default, "1"), 0.0, 1.0)

function _oe_target_count(genome::Genome)
    return count(region -> region.kind == "divertor_or_exhaust_region",
        genome.plasma_regions)
end

function _oe_features(genome::Genome)
    topology = _topology_features(genome)
    family = genome.family
    default_shape = family == "magnetic_mirror" ? 4.0 :
        family == "field_reversed_configuration" ? 4.0 :
        family == "spheromak" ? 1.5 : 3.5
    temperature_J = _oe_target(genome, "screen_temperature",
        15.0 * 1.602176634e-16, "J")
    return (
        family = family,
        shape_ratio = _oe_target(genome, "screen_aspect_ratio",
            default_shape, "1"),
        plasma_fill_fraction = _oe_fraction(genome,
            "screen_plasma_fill_fraction", 0.75),
        beta = _oe_fraction(genome, "screen_beta",
            family == "magnetic_mirror" ? 0.18 :
            family == "field_reversed_configuration" ? 0.65 :
            family == "spheromak" ? 0.12 : 0.05),
        temperature_keV = temperature_J / 1.602176634e-16,
        field_quality = _oe_fraction(genome, "screen_field_quality", 0.92),
        q95 = _oe_target(genome, "screen_q95", 3.5, "1"),
        mirror_ratio = family == "magnetic_mirror" ?
            _oe_target(genome, "screen_mirror_ratio", 5.0, "1") : 1.0,
        plasma_current_fraction = topology.plasma_current_fraction,
        external_transform_fraction = topology.external_transform_fraction,
        three_d_fraction = topology.three_d_fraction,
        plug_strength = topology.plug_strength,
        minimum_b_strength = topology.minimum_b_strength,
        shear_strength = topology.shear_strength,
        coil_pack_thickness_m = _oe_target(genome,
            "screen_coil_pack_thickness", 0.50, "m"),
        support_thickness_m = _oe_target(genome,
            "screen_support_thickness", 0.80, "m"),
        exhaust_area_fraction = _oe_fraction(genome,
            "screen_exhaust_area_fraction", 0.20),
        exhaust_flux_expansion = _oe_target(genome,
            "screen_exhaust_flux_expansion", 2.0, "1"),
        target_count = _oe_target_count(genome),
        actuator_power_W = _oe_target(genome,
            "screen_declared_actuator_power", 0.0, "W"),
    )
end

function _oe_geometry(features, contract::SharedOuterEnvelopeContractV1;
        dimension_multiplier::Float64 = 1.0)
    base = contract.base
    build = base.shield_thickness_m + base.maintenance_gap_m +
        features.coil_pack_thickness_m + features.support_thickness_m
    radial_extent = contract.outer_radial_extent_m
    axial_extent = contract.outer_axial_half_extent_m
    fill = features.plasma_fill_fraction * dimension_multiplier
    family = features.family
    if family in ("tokamak_axisymmetric", "stellarator")
        A = max(features.shape_ratio, 1.51)
        kappa = 1.65
        capacity = min((radial_extent - build) / (A + 1.0),
            (axial_extent - build) / kappa)
        a = max(0.01, fill * capacity)
        R = A * a
        c = kappa * a
        volume = 2.0 * pi^2 * R * a^2 * kappa
        area = 4.0 * pi^2 * R * a * sqrt((1.0 + kappa^2) / 2.0)
        radial_margin = radial_extent - (R + a + build)
        axial_margin = axial_extent - (c + build)
        inboard_margin = R - a - build
        curvature = max(0.01, min(a, R - a))
        return (R = R, a = a, c = c, volume = volume, area = area,
            build = build, radial_margin = radial_margin,
            axial_margin = axial_margin, inboard_margin = inboard_margin,
            curvature = curvature, capacity = capacity)
    end
    elongation = max(features.shape_ratio, 1.01)
    capacity = min(radial_extent - build,
        (axial_extent - build) / elongation)
    a = max(0.01, fill * capacity)
    c = elongation * a
    if family == "magnetic_mirror"
        volume = 2.0 * pi * a^2 * c
        area = 4.0 * pi * a * c + 2.0 * pi * a^2
    else
        volume = 4.0 / 3.0 * pi * a^2 * c
        area = _ct_spheroid_area(a, c)
    end
    radial_margin = radial_extent - (a + build)
    axial_margin = axial_extent - (c + build)
    return (R = c, a = a, c = c, volume = volume, area = area,
        build = build, radial_margin = radial_margin,
        axial_margin = axial_margin, inboard_margin = Inf,
        curvature = a, capacity = capacity)
end

function _oe_plasma_current_MA(features, geometry,
        contract::SharedOuterEnvelopeContractV1)
    features.family == "tokamak_axisymmetric" || return 0.05
    kappa = 1.65
    shape_factor = (1.0 + kappa^2) / 2.0
    return max(0.05, 8.0 * geometry.a^2 * contract.plasma_field_T *
        shape_factor * max(features.plasma_current_fraction, 0.08) /
        (geometry.R * max(features.q95, 1.5)))
end

function _oe_confinement_time_s(features, geometry,
        contract::SharedOuterEnvelopeContractV1, density_m3::Float64,
        power_MW::Float64, field_quality::Float64;
        field_multiplier::Float64 = 1.0)
    power = max(power_MW, 0.1)
    family = features.family
    B = contract.plasma_field_T * field_multiplier
    a, R = geometry.a, geometry.R
    plasma_current_MA = _oe_plasma_current_MA(features, geometry, contract)
    if family in ("tokamak_axisymmetric", "stellarator")
        n19 = max(density_m3 / 1.0e19, 0.01)
        kappa = 1.65
        epsilon = a / max(R, 1.0e-9)
        tau_ipb = 0.0562 * plasma_current_MA^0.93 * B^0.15 * n19^0.41 *
            power^(-0.69) * R^1.97 * epsilon^0.58 * kappa^0.78 * 2.5^0.19
        iota = clamp(0.25 + 0.55 * features.external_transform_fraction,
            0.2, 1.0)
        renormalization = clamp(0.55 + 0.55 * field_quality, 0.55, 1.10)
        tau_iss04 = 0.134 * renormalization * a^2.28 * R^0.64 *
            power^(-0.61) * n19^0.54 * B^0.84 * iota^0.41
        tau = family == "tokamak_axisymmetric" ? tau_ipb : tau_iss04
        return tau, tau_ipb, tau_iss04, 0.0, plasma_current_MA
    elseif family == "magnetic_mirror"
        n20 = max(density_m3 / 1.0e20, 0.02)
        effective_ratio = max(1.01, features.mirror_ratio *
            (1.0 + 1.5 * features.plug_strength +
                0.75 * features.minimum_b_strength))
        tau = max(1.0e-4, 0.25 * log10(effective_ratio) / n20)
        return tau, 0.0, 0.0, tau, plasma_current_MA
    end
    elementary_charge = 1.602176634e-19
    temperature_J = features.temperature_keV * 1.602176634e-16
    diffusivity = temperature_J /
        max(16.0 * elementary_charge * B, 1.0e-30)
    tau = geometry.a^2 / max(diffusivity, 1.0e-30) * field_quality
    return tau, 0.0, 0.0, 0.0, plasma_current_MA
end

function _oe_solve_loss_power_W(features, geometry,
        contract::SharedOuterEnvelopeContractV1, density_m3::Float64,
        stored_energy_J::Float64, field_quality::Float64;
        field_multiplier::Float64 = 1.0)
    if !(features.family in ("tokamak_axisymmetric", "stellarator"))
        tau = first(_oe_confinement_time_s(features, geometry, contract,
            density_m3, 1.0, field_quality;
            field_multiplier = field_multiplier))
        return stored_energy_J / max(tau, 1.0e-30)
    end
    residual(power_MW) = begin
        tau = first(_oe_confinement_time_s(features, geometry, contract,
            density_m3, power_MW, field_quality;
            field_multiplier = field_multiplier))
        power_MW - stored_energy_J / max(tau, 1.0e-30) / 1.0e6
    end
    low, high = 0.01, 10000.0
    residual(high) > 0 || return high * 1.0e6
    for _ in 1:80
        mid = sqrt(low * high)
        if residual(mid) > 0
            high = mid
        else
            low = mid
        end
    end
    return sqrt(low * high) * 1.0e6
end

function _oe_stability_margin(features, geometry,
        contract::SharedOuterEnvelopeContractV1, field_quality::Float64)
    family = features.family
    beta = features.beta
    B = contract.plasma_field_T
    if family == "tokamak_axisymmetric"
        current = _oe_plasma_current_MA(features, geometry, contract)
        beta_N = 100.0 * beta * geometry.a * B / max(current, 0.05)
        return (3.5 - beta_N) / 3.5, beta_N
    elseif family == "stellarator"
        cap = 0.055 + 0.025 * field_quality +
            0.020 * features.minimum_b_strength
        return (cap - beta) / max(cap, 1.0e-9), 0.0
    elseif family == "magnetic_mirror"
        cap = 0.20 + 0.15 * features.minimum_b_strength +
            0.10 * features.shear_strength + 0.08 * features.plug_strength
        return (cap - beta) / max(cap, 1.0e-9), 0.0
    elseif family == "field_reversed_configuration"
        mechanism = features.actuator_power_W > 0.0
        range = 0.30 <= beta <= 0.95 && 2.0 <= features.shape_ratio <= 8.0
        return mechanism && range ? min((beta - 0.30) / 0.30,
            (0.95 - beta) / 0.20) : -1.0, 0.0
    end
    mechanism = features.actuator_power_W > 0.0
    range = 0.04 <= beta <= 0.25 && 1.05 <= features.shape_ratio <= 2.5
    return mechanism && range ? min((beta - 0.04) / 0.04,
        (0.25 - beta) / 0.10) : -1.0, 0.0
end

function _oe_particle_loss_fraction(features, geometry,
        contract::SharedOuterEnvelopeContractV1, field_quality::Float64,
        density_m3::Float64)
    family = features.family
    if family in ("tokamak_axisymmetric", "stellarator")
        return 0.02 + (1.0 - field_quality) *
            (0.30 + 0.20 * features.three_d_fraction)
    elseif family == "magnetic_mirror"
        effective_ratio = max(1.0, features.mirror_ratio *
            (1.0 + 1.5 * features.plug_strength +
                0.75 * features.minimum_b_strength))
        return 1.0 / effective_ratio
    end
    elementary_charge = 1.602176634e-19
    deuterium_mass = 3.3435837724e-27
    temperature_J = features.temperature_keV * 1.602176634e-16
    thermal_speed = sqrt(2.0 * temperature_J / deuterium_mass)
    gyro = deuterium_mass * thermal_speed /
        max(elementary_charge * contract.plasma_field_T, 1.0e-30)
    kinetic_size = geometry.a / max(gyro, 1.0e-30)
    return 0.03 + 0.40 * (1.0 - field_quality) +
        min(0.15, 1.0 / max(kinetic_size, 1.0))
end

function _oe_nominal(genome::Genome, contract::SharedOuterEnvelopeContractV1,
        features; field_multiplier::Float64 = 1.0,
        beta_multiplier::Float64 = 1.0,
        dimension_multiplier::Float64 = 1.0,
        field_quality_penalty::Float64 = 0.0,
        actuator_multiplier::Float64 = 1.0,
        target_area_multiplier::Float64 = 1.0)
    mu0 = 4.0e-7 * pi
    elementary_charge = 1.602176634e-19
    geometry = _oe_geometry(features, contract;
        dimension_multiplier = dimension_multiplier)
    B = contract.plasma_field_T * field_multiplier
    beta = features.beta * beta_multiplier
    temperature_J = features.temperature_keV * 1.602176634e-16
    reactivity = _dt_reactivity_m3_s(features.temperature_keV)
    valid_reactivity = isfinite(reactivity)
    field_quality = clamp(features.field_quality - field_quality_penalty, 0.0, 1.0)
    pressure = beta * B^2 / (2.0 * mu0)
    density = pressure / max(2.0 * temperature_J, 1.0e-30)
    fusion_power_density = valid_reactivity ? 0.25 * density^2 * reactivity *
        17.6e6 * elementary_charge : 0.0
    fusion_power = fusion_power_density * geometry.volume
    alpha_power = 0.20 * fusion_power
    stored_energy = 1.5 * pressure * geometry.volume
    loss_power = _oe_solve_loss_power_W(features, geometry, contract, density,
        stored_energy, field_quality; field_multiplier = field_multiplier)
    confinement = _oe_confinement_time_s(features, geometry, contract, density,
        loss_power / 1.0e6, field_quality;
        field_multiplier = field_multiplier)
    tau_E, tau_ipb, tau_iss04, tau_mirror, plasma_current_MA = confinement
    actuator_power = features.actuator_power_W * actuator_multiplier
    transport_auxiliary = max(0.0, loss_power - alpha_power)
    total_auxiliary = transport_auxiliary + actuator_power
    fusion_gain = fusion_power / max(total_auxiliary, 1.0)
    net_power = contract.base.thermal_conversion_efficiency * fusion_power -
        total_auxiliary / contract.base.heating_wall_plug_efficiency -
        contract.base.fixed_balance_of_plant_load_W
    particle_loss = _oe_particle_loss_fraction(features, geometry, contract,
        field_quality, density)
    stability_margin, beta_N = _oe_stability_margin(features, geometry,
        contract, field_quality)

    target_count = max(features.target_count, 1)
    requested_target_area = features.exhaust_area_fraction * geometry.area
    geometric_target_capacity = target_count * pi * (0.50 * geometry.a)^2 *
        max(features.exhaust_flux_expansion, 1.0)
    target_area = min(requested_target_area, geometric_target_capacity) *
        target_area_multiplier
    exhaust_heat_flux = loss_power / max(target_area, 1.0e-9)
    neutron_wall_load = 0.80 * fusion_power / max(geometry.area, 1.0e-9)

    peak_ratio = features.family == "tokamak_axisymmetric" ?
        1.0 + 1.0 / max(features.shape_ratio - 1.0, 0.25) :
        features.family == "stellarator" ?
            1.0 + 1.0 / max(features.shape_ratio - 1.0, 0.25) +
                0.30 * features.three_d_fraction :
        features.family == "magnetic_mirror" ? features.mirror_ratio :
        features.family == "field_reversed_configuration" ? 1.55 : 1.35
    peak_field = B * peak_ratio
    load_amplification = 1.0 + 0.80 * features.three_d_fraction
    current_density = peak_field /
        (mu0 * max(features.coil_pack_thickness_m, 0.02)) / 1.0e6 *
        (1.15 + 0.30 * features.three_d_fraction)
    magnetic_pressure = peak_field^2 / (2.0 * mu0)
    support_stress = magnetic_pressure * load_amplification *
        min(geometry.curvature, 2.5) /
        max(features.support_thickness_m, 0.05)

    base = contract.base
    radial_scale = max(contract.outer_radial_extent_m, 1.0e-9)
    axial_scale = max(contract.outer_axial_half_extent_m, 1.0e-9)
    margins = Dict{String,Float64}(
        "temperature_domain" => min((features.temperature_keV - 5.0) / 5.0,
            (30.0 - features.temperature_keV) / 5.0),
        "stability" => stability_margin,
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
        "outer_radial_envelope" => geometry.radial_margin / radial_scale,
        "outer_axial_envelope" => geometry.axial_margin / axial_scale,
        "inboard_build" => isfinite(geometry.inboard_margin) ?
            geometry.inboard_margin / radial_scale : 1.0,
        "coil_curvature" =>
            (geometry.curvature - base.minimum_coil_curvature_radius_m) /
            base.minimum_coil_curvature_radius_m,
        "neutron_wall_load" =>
            (base.maximum_neutron_wall_load_W_m2 - neutron_wall_load) /
            base.maximum_neutron_wall_load_W_m2,
        "exhaust_target_heat_flux" =>
            (contract.maximum_exhaust_heat_flux_W_m2 - exhaust_heat_flux) /
            contract.maximum_exhaust_heat_flux_W_m2,
    )
    physics_gate = valid_reactivity && all(margins[id] >= 0.0 for id in
        ("temperature_domain", "stability", "particle_loss", "fusion_gain",
            "auxiliary_power", "net_electric_power"))
    engineering_gate = all(margins[id] >= 0.0 for id in
        ("peak_conductor_field", "engineering_current_density", "support_stress",
            "outer_radial_envelope", "outer_axial_envelope", "inboard_build",
            "coil_curvature", "neutron_wall_load", "exhaust_target_heat_flux"))
    return Dict{String,Any}(
        "family" => features.family,
        "major_radius_or_half_length_m" => geometry.R,
        "plasma_minor_radius_m" => geometry.a,
        "plasma_half_height_or_half_length_m" => geometry.c,
        "plasma_volume_m3" => geometry.volume,
        "first_wall_area_m2" => geometry.area,
        "radial_build_m" => geometry.build,
        "outer_radial_margin_m" => geometry.radial_margin,
        "outer_axial_margin_m" => geometry.axial_margin,
        "inboard_build_margin_m" => isfinite(geometry.inboard_margin) ?
            geometry.inboard_margin : 1.0e99,
        "beta" => beta,
        "temperature_keV" => features.temperature_keV,
        "pressure_Pa" => pressure,
        "density_m3" => density,
        "fusion_power_W" => fusion_power,
        "alpha_power_W" => alpha_power,
        "stored_energy_MJ" => stored_energy / 1.0e6,
        "energy_confinement_time_s" => tau_E,
        "ipb98y2_time_s" => tau_ipb,
        "iss04_time_s" => tau_iss04,
        "mirror_time_proxy_s" => tau_mirror,
        "plasma_current_MA" => plasma_current_MA,
        "transport_loss_power_W" => loss_power,
        "declared_actuator_power_W" => actuator_power,
        "required_auxiliary_power_W" => total_auxiliary,
        "fusion_gain_proxy" => fusion_gain,
        "net_electric_power_W" => net_power,
        "particle_loss_fraction_proxy" => particle_loss,
        "minimum_stability_margin_proxy" => stability_margin,
        "tokamak_beta_N_proxy" => beta_N,
        "target_count" => target_count,
        "requested_target_area_m2" => requested_target_area,
        "geometric_target_area_capacity_m2" => geometric_target_capacity,
        "effective_target_area_m2" => target_area,
        "exhaust_heat_flux_W_m2" => exhaust_heat_flux,
        "neutron_wall_load_W_m2" => neutron_wall_load,
        "peak_conductor_field_T" => peak_field,
        "engineering_current_density_A_mm2" => current_density,
        "support_stress_proxy_Pa" => support_stress,
        "minimum_coil_curvature_radius_m" => geometry.curvature,
        "physics_gate_passed" => physics_gate,
        "engineering_gate_passed" => engineering_gate,
        "margins" => margins,
        "minimum_normalized_margin" => minimum(values(margins)),
    )
end

function _oe_graph_errors(genome::Genome, features,
        contract::SharedOuterEnvelopeContractV1)
    errors = String[]
    report = validate_genome(genome)
    append!(errors, report.errors)
    family = validate_family(default_family_registry(), genome)
    append!(errors, family.errors)
    for (name, expected, unit) in (
            ("screen_outer_radial_extent", contract.outer_radial_extent_m, "m"),
            ("screen_outer_axial_half_extent", contract.outer_axial_half_extent_m, "m"),
            ("screen_plasma_field", contract.plasma_field_T, "T"))
        value = get(genome.mission.targets, name, nothing)
        if value === nothing || value.unit != unit ||
                !_contract_isapprox(value.value, expected)
            push!(errors, "$name is inconsistent with outer-envelope contract")
        end
    end
    geometry = _oe_geometry(features, contract)
    function check_parameter(item, name::String, expected::Float64,
            unit::String, label::String)
        value = get(item.parameters, name, nothing)
        if value === nothing || value.unit != unit ||
                !isapprox(value.value, expected; rtol = 1.0e-9, atol = 1.0e-9)
            push!(errors, "$label.$name is inconsistent with scored plasma geometry")
        end
    end
    if features.family in ("tokamak_axisymmetric", "stellarator")
        cores = filter(region -> region.kind == "closed_toroidal_core",
            genome.plasma_regions)
        if length(cores) == 1
            core = only(cores)
            check_parameter(core, "major_radius", geometry.R, "m", core.id)
            check_parameter(core, "minor_radius", geometry.a, "m", core.id)
            check_parameter(core, "half_height", geometry.c, "m", core.id)
            check_parameter(core, "elongation", 1.65, "1", core.id)
        end
        if features.family == "tokamak_axisymmetric"
            expected_current_A = 1.0e6 * _oe_plasma_current_MA(features,
                geometry, contract)
            current = get(genome.mission.targets, "plasma_current", nothing)
            if current === nothing || current.unit != "A" ||
                    !isapprox(current.value, expected_current_A;
                        rtol = 1.0e-9, atol = 1.0e-6)
                push!(errors,
                    "plasma_current target is inconsistent with scored q95 geometry")
            end
        end
    elseif features.family == "magnetic_mirror"
        cells = filter(region -> region.kind == "mirror_central_cell",
            genome.plasma_regions)
        if length(cells) == 1
            cell = only(cells)
            check_parameter(cell, "plasma_radius", geometry.a, "m", cell.id)
            check_parameter(cell, "cell_length", 2.0 * geometry.c, "m", cell.id)
            check_parameter(cell, "central_field", contract.plasma_field_T,
                "T", cell.id)
        end
    else
        cores = filter(region -> region.kind == "compact_toroid_closed_core",
            genome.plasma_regions)
        if length(cores) == 1
            core = only(cores)
            check_parameter(core, "minor_radius", geometry.a, "m", core.id)
            check_parameter(core, "half_length", geometry.c, "m", core.id)
            check_parameter(core, "central_field", contract.plasma_field_T,
                "T", core.id)
        end
    end
    features.target_count >= 2 || push!(errors,
        "at least two explicit exhaust targets are required")
    target_ids = Set(region.id for region in genome.plasma_regions if
        region.kind == "divertor_or_exhaust_region")
    all(id -> id in Set(genome.exhaust.region_ids), target_ids) ||
        push!(errors, "all explicit targets must be listed in exhaust.region_ids")
    if features.family == "magnetic_mirror"
        count(connection -> connection.kind == "open_field_line" &&
            connection.to_region_id in target_ids, genome.flux_connections) >= 2 ||
            push!(errors, "mirror end expanders must connect to explicit targets")
    else
        sol = filter(region -> region.kind == "scrape_off_layer",
            genome.plasma_regions)
        length(sol) == 1 || push!(errors, "exactly one explicit SOL is required")
        cores = filter(region -> region.kind in
            ("closed_toroidal_core", "compact_toroid_closed_core"),
            genome.plasma_regions)
        length(cores) == 1 || push!(errors, "exactly one closed core is required")
        if length(sol) == 1 && length(cores) == 1
            sol_id, core_id = only(sol).id, only(cores).id
            count(connection -> connection.from_region_id == core_id &&
                connection.to_region_id == sol_id &&
                connection.kind == "cross_separatrix_transport",
                genome.flux_connections) == 1 || push!(errors,
                "one core-to-SOL cross-separatrix edge is required")
            count(connection -> connection.from_region_id == sol_id &&
                connection.to_region_id in target_ids &&
                connection.kind == "open_field_line",
                genome.flux_connections) == features.target_count || push!(errors,
                "SOL must connect to every target with open field lines")
        end
    end
    if features.family == "field_reversed_configuration"
        _ct_has_kind(genome.field_sources, "axisymmetric_solenoid") ||
            push!(errors, "FRC requires an axisymmetric solenoid")
        _ct_has_kind(genome.field_sources, "frc_plasma_current") ||
            push!(errors, "FRC requires field-reversing plasma current")
    elseif features.family == "spheromak"
        _ct_has_kind(genome.field_sources, "self_organized_plasma_current") ||
            push!(errors, "spheromak requires self-organized plasma current")
        _ct_has_kind(genome.field_sources, "flux_conserver") ||
            push!(errors, "spheromak requires an explicit flux conserver")
        _ct_has_kind(genome.actuators, "helicity_injector") ||
            push!(errors, "spheromak requires helicity injectors")
    end
    features.family in ("magnetic_mirror", "field_reversed_configuration",
        "spheromak") && features.actuator_power_W <= 0.0 &&
        push!(errors, "active open/compact family requires declared actuator power")
    0.25 <= features.plasma_fill_fraction <= 0.95 ||
        push!(errors, "plasma fill fraction must be in [0.25, 0.95]")
    1.0 <= features.exhaust_flux_expansion <= 6.0 ||
        push!(errors, "exhaust flux expansion must be in [1, 6]")
    return sort!(unique(errors))
end

function _oe_robustness(genome::Genome, contract::SharedOuterEnvelopeContractV1,
        features)
    rng = MersenneTwister(contract.base.robustness_seed)
    records = Dict{String,Any}[]
    pass_count = 0
    worst_margin = Inf
    for sample in 1:contract.base.robustness_samples
        field_delta = 0.02 * (2.0 * rand(rng) - 1.0)
        beta_delta = 0.15 * (2.0 * rand(rng) - 1.0)
        dimension_delta = 0.01 * (2.0 * rand(rng) - 1.0)
        coil_offset_m = 0.003 * (2.0 * rand(rng) - 1.0)
        control_error = 0.10 * (2.0 * rand(rng) - 1.0)
        target_occlusion = 0.10 * rand(rng)
        quality_penalty = abs(coil_offset_m) /
            max(contract.outer_radial_extent_m, 1.0e-9) *
            (1.0 + 3.0 * features.three_d_fraction) +
            0.03 * abs(control_error)
        values = _oe_nominal(genome, contract, features;
            field_multiplier = 1.0 + field_delta,
            beta_multiplier = 1.0 + beta_delta,
            dimension_multiplier = 1.0 + dimension_delta,
            field_quality_penalty = quality_penalty,
            actuator_multiplier = 1.0 + control_error,
            target_area_multiplier = 1.0 - target_occlusion)
        passed = values["physics_gate_passed"] === true &&
            values["engineering_gate_passed"] === true
        passed && (pass_count += 1)
        worst_margin = min(worst_margin,
            Float64(values["minimum_normalized_margin"]))
        push!(records, Dict{String,Any}(
            "sample" => sample,
            "field_delta_fraction" => field_delta,
            "beta_delta_fraction" => beta_delta,
            "dimension_delta_fraction" => dimension_delta,
            "coil_offset_m" => coil_offset_m,
            "actuator_power_error_fraction" => control_error,
            "target_occlusion_fraction" => target_occlusion,
            "passed" => passed,
            "minimum_normalized_margin" => values["minimum_normalized_margin"],
        ))
    end
    fraction = pass_count / contract.base.robustness_samples
    return Dict{String,Any}(
        "sample_count" => contract.base.robustness_samples,
        "common_random_seed" => contract.base.robustness_seed,
        "pass_count" => pass_count,
        "pass_fraction" => fraction,
        "required_pass_fraction" =>
            contract.base.robustness_required_pass_fraction,
        "gate_passed" => fraction >=
            contract.base.robustness_required_pass_fraction,
        "worst_minimum_normalized_margin" => worst_margin,
        "records" => records,
    )
end

function _shared_outer_envelope_result(evaluator::SharedOuterEnvelopeScreenV1,
        genome::Genome)
    contract = evaluator.contract
    contract_dict = _oe_contract_dict(contract)
    contract_hash = canonical_hash(contract_dict)
    features = _oe_features(genome)
    graph_errors = _oe_graph_errors(genome, features, contract)
    graph_gate = isempty(graph_errors)
    nominal = _oe_nominal(genome, contract, features)
    robustness = if graph_gate && nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true
        _oe_robustness(genome, contract, features)
    else
        Dict{String,Any}(
            "sample_count" => 0,
            "maximum_sample_budget" => contract.base.robustness_samples,
            "common_random_seed" => contract.base.robustness_seed,
            "pass_count" => 0, "pass_fraction" => 0.0,
            "required_pass_fraction" =>
                contract.base.robustness_required_pass_fraction,
            "gate_passed" => false,
            "worst_minimum_normalized_margin" =>
                nominal["minimum_normalized_margin"],
            "records" => Dict{String,Any}[],
            "skipped_due_nominal_gate_failure" => true,
        )
    end
    contract_gate = contract_hash in evaluator.allowed_contract_hashes
    all_five = graph_gate && nominal["physics_gate_passed"] === true &&
        nominal["engineering_gate_passed"] === true && contract_gate &&
        robustness["gate_passed"] === true
    complexity = length(genome.field_sources) + 1.5 * length(genome.actuators) +
        0.5 * length(genome.plasma_regions) +
        0.25 * length(genome.flux_connections) +
        0.25 * max(features.target_count - 2, 0) +
        3.0 * features.three_d_fraction
    result = Dict{String,Any}(
        "contract" => contract_dict,
        "contract_hash" => contract_hash,
        "claim_boundary" => _OE_SCREEN_CLAIM_BOUNDARY,
        "topology_features" => Dict(String(key) => value for
            (key, value) in pairs(features)),
        "topology_graph_errors" => graph_errors,
        "nominal" => nominal,
        "robustness" => robustness,
        "gates" => Dict(
            "variable_topology_representation" => graph_gate,
            "unified_low_fidelity_physics" => nominal["physics_gate_passed"],
            "minimal_engineering_closure" => nominal["engineering_gate_passed"],
            "same_outer_envelope_contract" => contract_gate,
            "cheap_robustness_screen" => robustness["gate_passed"],
        ),
        "all_five_gates_passed" => all_five,
        "positive_net_power_closure_passed" =>
            nominal["net_electric_power_W"] > 0.0,
        "classification" => all_five ?
            "shared_envelope_survivor_pending_medium_fidelity" :
            "obviously_infeasible_or_unresolved",
        "device_complexity_proxy" => complexity,
    )
    result["result_hash"] = canonical_hash(result)
    return result
end

function run_evaluator(evaluator::SharedOuterEnvelopeScreenV1, genome::Genome;
        kwargs...)
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return _non_applicable_bundle(evaluator_spec(evaluator), genome,
        reason)
    result = _shared_outer_envelope_result(evaluator, genome)
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "evaluator" => "shared_outer_envelope_screen_v1",
        "version" => "1.0.0",
        "result_hash" => result["result_hash"],
    ))
    status = result["all_five_gates_passed"] === true ? :pass : :fail
    metric = MetricResult("shared_outer_envelope_five_gate_pass",
        result["all_five_gates_passed"] ? 1.0 : 0.0;
        fidelity = 0, applicability = reason, status = status,
        constraints_checked = sort!(collect(keys(result["gates"]))),
        solver_name = "shared_outer_envelope_screen_v1",
        solver_version = "1.0.0", input_hash = genome.physics_hash,
        run_hash = run_hash, source_basis = [
            "bosch_hale_reactivity_1992", "tokamak_iter_physics_basis_1999",
            "tokamak_troyon_limit_1984", "stellarator_iss04_yamada_2005",
            "mirror_beam_2024", "frc_steinhauer_review_2011",
            "spheromak_jarboe_review_1994", "w7x_island_divertor_2019",
            "process_physics_2015", "process_engineering_2016"],
        warnings = [_OE_SCREEN_CLAIM_BOUNDARY])
    return EvaluationBundle("shared_outer_envelope_screen_v1",
        genome.design_id, genome.family, 0, status, [metric],
        [_OE_SCREEN_CLAIM_BOUNDARY], genome.physics_hash, run_hash,
        _OE_SCREEN_CLAIM_BOUNDARY)
end
