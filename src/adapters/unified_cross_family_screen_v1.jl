"Fixed comparison envelope shared by every baseline and generated candidate."
struct CommonComparisonContract
    id::String
    major_scale_m::Float64
    plasma_field_T::Float64
    magnet_material_envelope::String
    support_material_envelope::String
    peak_conductor_field_limit_T::Float64
    engineering_current_density_limit_A_mm2::Float64
    support_stress_limit_Pa::Float64
    minimum_coil_curvature_radius_m::Float64
    shield_thickness_m::Float64
    maintenance_gap_m::Float64
    maximum_neutron_wall_load_W_m2::Float64
    auxiliary_heating_budget_W::Float64
    thermal_conversion_efficiency::Float64
    heating_wall_plug_efficiency::Float64
    fixed_balance_of_plant_load_W::Float64
    robustness_samples::Int
    robustness_required_pass_fraction::Float64
    robustness_seed::Int
end

function default_common_comparison_contract()
    return CommonComparisonContract(
        "cross_family_common_envelope_v2",
        6.2,
        4.0,
        "generic_superconducting_winding_screen_v1_no_critical_surface",
        "generic_support_allowable_800MPa_screen_v1",
        24.0,
        500.0,
        800.0e6,
        0.35,
        1.0,
        0.60,
        5.0e6,
        120.0e6,
        0.40,
        0.50,
        30.0e6,
        64,
        0.95,
        20260811,
    )
end

function _common_contract_dict(contract::CommonComparisonContract)
    return Dict{String,Any}(
        "id" => contract.id,
        "major_scale_m" => contract.major_scale_m,
        "plasma_field_T" => contract.plasma_field_T,
        "magnet_material_envelope" => contract.magnet_material_envelope,
        "support_material_envelope" => contract.support_material_envelope,
        "peak_conductor_field_limit_T" => contract.peak_conductor_field_limit_T,
        "engineering_current_density_limit_A_mm2" =>
            contract.engineering_current_density_limit_A_mm2,
        "support_stress_limit_Pa" => contract.support_stress_limit_Pa,
        "minimum_coil_curvature_radius_m" => contract.minimum_coil_curvature_radius_m,
        "shield_thickness_m" => contract.shield_thickness_m,
        "maintenance_gap_m" => contract.maintenance_gap_m,
        "maximum_neutron_wall_load_W_m2" => contract.maximum_neutron_wall_load_W_m2,
        "auxiliary_heating_budget_W" => contract.auxiliary_heating_budget_W,
        "thermal_conversion_efficiency" => contract.thermal_conversion_efficiency,
        "heating_wall_plug_efficiency" => contract.heating_wall_plug_efficiency,
        "fixed_balance_of_plant_load_W" => contract.fixed_balance_of_plant_load_W,
        "robustness_samples" => contract.robustness_samples,
        "robustness_required_pass_fraction" =>
            contract.robustness_required_pass_fraction,
        "robustness_seed" => contract.robustness_seed,
    )
end

struct UnifiedCrossFamilyScreenV1 <: AbstractEvaluator
    contract::CommonComparisonContract
end

UnifiedCrossFamilyScreenV1() =
    UnifiedCrossFamilyScreenV1(default_common_comparison_contract())

const _UNIFIED_SCREEN_SOURCE_BASIS = String[
    "lawson_wurzel_hsu_2022",
    "bosch_hale_reactivity_1992",
    "tokamak_iter_physics_basis_1999",
    "tokamak_troyon_limit_1984",
    "stellarator_iss04_yamada_2005",
    "mirror_beam_2024",
    "mirror_ryutov_mhd_2011",
    "process_physics_2015",
    "process_engineering_2016",
    "arc_sorbom_2015",
]

const _UNIFIED_SCREEN_CLAIM_BOUNDARY =
    "Common-envelope fidelity-0 rejection screen using empirical confinement scalings, a tabulated Bosch-Hale D-T reactivity approximation, reduced magnetic-pressure/current-sheet engineering estimates, and deterministic perturbations. Passing means temporarily plausible under this declared proxy contract only; it is not a solved equilibrium, all-mode stability result, orbit/transport calculation, coil design, material qualification, power-plant design, global optimum, or evidence of superiority."

function evaluator_spec(::UnifiedCrossFamilyScreenV1)
    return EvaluatorSpec(
        "unified_cross_family_screen_v1",
        "1.0.0",
        collect(keys(default_family_registry().specs)),
        0,
        Dict(
            "equilibrium" => :proxy,
            "basic_constraints" => :proxy,
            "stability" => :proxy,
            "particle_loss" => :proxy,
            "fusion_gain" => :proxy,
            "actuator_power" => :proxy,
            "finite_build_coils" => :proxy,
            "coil_stress" => :proxy,
            "shielding" => :proxy,
            "maintenance_access" => :proxy,
            "power_balance" => :proxy,
            "manufacturing_tolerance" => :proxy,
            "error_field_sensitivity" => :proxy,
        ),
        "physics_proxy",
    )
end

function evaluator_applicability(evaluator::UnifiedCrossFamilyScreenV1, genome::Genome)
    genome.mission.fuel == "D-T" || return false,
        "unified_cross_family_screen_v1 version 1 is restricted to the common D-T mission"
    family = validate_family(default_family_registry(), genome)
    family.valid || return false, join(family.errors, "; ")
    return true,
        "common D-T envelope $(evaluator.contract.id); topology-specific scaling branches remain proxies"
end

function _screen_target(genome::Genome, name::String, default::Real, unit::String)
    value = get(genome.mission.targets, name, nothing)
    value === nothing && return Float64(default)
    value.unit == unit || throw(ArgumentError(
        "mission.targets.$name must use canonical unit $unit, got $(value.unit)"))
    return value.value
end

_screen_fraction(genome, name, default) =
    clamp(_screen_target(genome, name, default, "1"), 0.0, 1.0)

function _screen_temperature_keV(genome::Genome)
    temperature_J = _screen_target(genome, "screen_temperature", 15.0 * 1.602176634e-16, "J")
    return temperature_J / 1.602176634e-16
end

function _has_kind_fragment(items, fragment::AbstractString)
    return any(item -> occursin(fragment, lowercase(item.kind)), items)
end

function _topology_features(genome::Genome)
    line_class = genome.topology.field_line_class
    default_closed = startswith(line_class, "closed") ? 1.0 :
        line_class == "open_mirror" ? 0.0 : line_class == "compact_toroid" ? 0.95 : 0.65
    closed_fraction = _screen_fraction(genome, "screen_closed_flux_fraction", default_closed)
    plasma_current_declared = "plasma_current" in genome.topology.rotation_transform_sources
    external_transform_declared =
        "three_dimensional_external_field" in genome.topology.rotation_transform_sources
    plasma_current_fraction_raw = _screen_fraction(genome,
        "screen_plasma_current_transform_fraction", plasma_current_declared ? 1.0 : 0.0)
    external_transform_fraction_raw = _screen_fraction(genome,
        "screen_external_transform_fraction", external_transform_declared ? 1.0 : 0.0)
    plasma_current_fraction_raw = plasma_current_declared ?
        max(plasma_current_fraction_raw, 0.05) : 0.0
    external_transform_fraction_raw = external_transform_declared ?
        max(external_transform_fraction_raw, 0.05) : 0.0
    transform_total = plasma_current_fraction_raw + external_transform_fraction_raw
    plasma_current_fraction = transform_total > 0 ?
        plasma_current_fraction_raw / transform_total : 0.0
    external_transform_fraction = transform_total > 0 ?
        external_transform_fraction_raw / transform_total : 0.0
    three_d_default = genome.symmetry.class in
        ("stellarator_symmetric", "quasi_axisymmetric", "quasi_helical",
            "quasi_isodynamic", "mixed", "none") ? 1.0 : 0.0
    three_d_source_present = external_transform_declared ||
        _has_kind_fragment(genome.field_sources, "three_dimensional") ||
        _has_kind_fragment(genome.field_sources, "nonplanar") ||
        _has_kind_fragment(genome.field_sources, "helical")
    three_d_fraction = three_d_source_present ?
        _screen_fraction(genome, "screen_three_dimensional_field_fraction",
            three_d_default) : 0.0
    three_d_source_present && (three_d_fraction = max(three_d_fraction, 0.50))
    internal_present = _has_kind_fragment(genome.field_sources, "internal") ||
        _has_kind_fragment(genome.field_sources, "levitated") ||
        genome.family == "levitated_dipole"
    internal_coil_fraction = internal_present ?
        _screen_fraction(genome, "screen_internal_coil_fraction", 1.0) : 0.0
    internal_present && (internal_coil_fraction = max(internal_coil_fraction, 0.25))
    plug_present = any(region -> occursin("plug", lowercase(region.kind)), genome.plasma_regions)
    minimum_b_present = genome.symmetry.class == "minimum_b" ||
        _has_kind_fragment(genome.field_sources, "minimum_b")
    shear_present = any(mechanism -> mechanism.mechanism == "sheared_flow",
        genome.stability_mechanisms)
    return (
        closed_fraction = closed_fraction,
        open_fraction = 1.0 - closed_fraction,
        plasma_current_fraction = plasma_current_fraction,
        external_transform_fraction = external_transform_fraction,
        three_d_fraction = three_d_fraction,
        internal_coil_fraction = internal_coil_fraction,
        mirror_ratio = closed_fraction < 1.0 - 1.0e-9 ?
            _screen_target(genome, "screen_mirror_ratio",
                line_class == "open_mirror" ? 5.0 : 4.0, "1") : 1.0,
        plug_strength = plug_present ?
            max(_screen_fraction(genome, "screen_plug_strength", 0.6), 0.40) : 0.0,
        minimum_b_strength = minimum_b_present ?
            max(_screen_fraction(genome, "screen_minimum_b_strength", 0.8), 0.50) : 0.0,
        shear_strength = shear_present ?
            _screen_fraction(genome, "screen_shear_strength", 0.6) : 0.0,
        field_quality = _screen_fraction(genome, "screen_field_quality", 0.82),
        q95 = _screen_target(genome, "screen_q95", 3.5, "1"),
        aspect_ratio = _screen_target(genome, "screen_aspect_ratio",
            line_class == "open_mirror" ? 4.5 : 3.5, "1"),
        beta = _screen_fraction(genome, "screen_beta",
            line_class == "open_mirror" ? 0.22 : line_class == "mixed" ? 0.10 : 0.05),
        temperature_keV = _screen_temperature_keV(genome),
        coil_pack_thickness_m = _screen_target(genome,
            "screen_coil_pack_thickness", 0.45, "m"),
        support_thickness_m = _screen_target(genome,
            "screen_support_thickness", 0.70, "m"),
    )
end

"Log-linear interpolation of a predeclared D-T Maxwellian reactivity table."
function _dt_reactivity_m3_s(temperature_keV::Float64)
    temperatures = Float64[5.0, 8.0, 10.0, 15.0, 20.0, 25.0, 30.0]
    reactivities = Float64[1.37e-23, 5.03e-23, 1.10e-22, 2.65e-22,
        4.33e-22, 5.63e-22, 6.64e-22]
    temperatures[1] <= temperature_keV <= temperatures[end] || return NaN
    index = searchsortedlast(temperatures, temperature_keV)
    index == length(temperatures) && return reactivities[end]
    t0, t1 = temperatures[index], temperatures[index + 1]
    y0, y1 = log(reactivities[index]), log(reactivities[index + 1])
    weight = (temperature_keV - t0) / (t1 - t0)
    return exp(y0 + weight * (y1 - y0))
end

_contract_isapprox(actual::Real, expected::Real) =
    isapprox(Float64(actual), Float64(expected); rtol = 1.0e-10, atol = 1.0e-10)

function _expected_screen_plasma_current_MA(features,
        contract::CommonComparisonContract)
    a = contract.major_scale_m / features.aspect_ratio
    kappa = 1.65
    shape_factor = (1.0 + kappa^2) / 2.0
    return max(0.05, 8.0 * a^2 * contract.plasma_field_T * shape_factor *
        max(features.plasma_current_fraction, 0.08) /
        (contract.major_scale_m * max(features.q95, 1.5)))
end

function _common_envelope_consistency_errors(genome::Genome, features,
        contract::CommonComparisonContract)
    errors = String[]
    target_checks = (
        ("screen_common_envelope_version", 2.0, "1"),
        ("screen_major_scale", contract.major_scale_m, "m"),
        ("screen_plasma_field", contract.plasma_field_T, "T"),
        ("screen_peak_conductor_field_limit",
            contract.peak_conductor_field_limit_T, "T"),
        ("screen_material_envelope_version", 1.0, "1"),
        ("on_axis_field", contract.plasma_field_T, "T"),
    )
    for (name, expected, unit) in target_checks
        quantity = get(genome.mission.targets, name, nothing)
        if quantity === nothing
            push!(errors, "missing common-envelope target $name")
        elseif quantity.unit != unit || !_contract_isapprox(quantity.value, expected)
            push!(errors, "common-envelope target $name does not match $(expected) $unit")
        end
    end
    feature_target_checks = (
        ("screen_closed_flux_fraction", features.closed_fraction),
        ("screen_plasma_current_transform_fraction", features.plasma_current_fraction),
        ("screen_external_transform_fraction", features.external_transform_fraction),
        ("screen_three_dimensional_field_fraction", features.three_d_fraction),
        ("screen_internal_coil_fraction", features.internal_coil_fraction),
        ("screen_mirror_ratio", features.mirror_ratio),
        ("screen_plug_strength", features.plug_strength),
        ("screen_minimum_b_strength", features.minimum_b_strength),
        ("screen_shear_strength", features.shear_strength),
    )
    for (name, expected) in feature_target_checks
        quantity = get(genome.mission.targets, name, nothing)
        if quantity === nothing
            push!(errors, "missing topology-feature target $name")
        elseif quantity.unit != "1" || !_contract_isapprox(quantity.value, expected)
            push!(errors, "topology-feature target $name contradicts explicit components")
        end
    end

    minor_radius = contract.major_scale_m / features.aspect_ratio
    expected_current_A = 1.0e6 * _expected_screen_plasma_current_MA(features, contract)
    expected_peak_T = contract.plasma_field_T * max(features.mirror_ratio, 1.0)
    for source in genome.field_sources
        if source.kind != "plasma_current" &&
                source.material != contract.magnet_material_envelope
            push!(errors, "field source $(source.id) does not use the common magnet envelope")
        end
        for (name, expected, unit) in (
                ("on_axis_field", contract.plasma_field_T, "T"),
                ("nominal_field", contract.plasma_field_T, "T"),
                ("total_current", expected_current_A, "A"),
                ("external_transform_fraction_gene",
                    features.external_transform_fraction, "1"),
                ("peak_field", expected_peak_T, "T"))
            quantity = get(source.parameters, name, nothing)
            quantity === nothing && continue
            if quantity.unit != unit || !_contract_isapprox(quantity.value, expected)
                push!(errors, "field source $(source.id).$name is inconsistent with the common envelope")
            end
        end
    end
    for region in genome.plasma_regions
        for (name, expected, unit) in (
                ("major_radius", contract.major_scale_m, "m"),
                ("minor_radius", minor_radius, "m"),
                ("minor_radius_r", minor_radius, "m"),
                ("minor_radius_z", minor_radius, "m"),
                ("central_field", contract.plasma_field_T, "T"),
                ("plasma_radius", minor_radius, "m"),
                ("cell_length", 2.0 * contract.major_scale_m, "m"),
                ("mirror_ratio_gene", features.mirror_ratio, "1"),
                ("peak_field", expected_peak_T, "T"))
            quantity = get(region.parameters, name, nothing)
            quantity === nothing && continue
            if quantity.unit != unit || !_contract_isapprox(quantity.value, expected)
                push!(errors, "plasma region $(region.id).$name is inconsistent with the common envelope")
            end
        end
    end
    if features.closed_fraction > 1.0e-9
        any(region -> region.kind == "closed_toroidal_core" &&
            haskey(region.parameters, "major_radius") &&
            haskey(region.parameters, "minor_radius"), genome.plasma_regions) ||
            push!(errors, "closed component lacks explicit common-envelope radii")
    end
    if features.open_fraction > 1.0e-9
        any(source -> occursin("mirror", source.kind) &&
            haskey(source.parameters, "peak_field"), genome.field_sources) ||
            push!(errors, "open component lacks an explicit common-envelope mirror peak field")
    end
    if features.plasma_current_fraction > 1.0e-9
        any(source -> source.kind == "plasma_current" &&
            haskey(source.parameters, "total_current"), genome.field_sources) ||
            push!(errors, "plasma-current transform lacks synchronized total current")
    end
    if features.external_transform_fraction > 1.0e-9
        any(source -> occursin("three_dimensional", source.kind) &&
            haskey(source.parameters, "external_transform_fraction_gene"),
            genome.field_sources) ||
            push!(errors, "external transform lacks a synchronized component fraction")
    end
    return sort!(unique(errors))
end

function _topology_contract_gate(genome::Genome, features,
        contract::CommonComparisonContract)
    report = validate_genome(genome)
    report.valid || return false, join(report.errors, "; ")
    consistency_errors = _common_envelope_consistency_errors(genome, features, contract)
    isempty(consistency_errors) || return false, join(consistency_errors, "; ")
    features.aspect_ratio > 1.5 || return false, "aspect ratio must exceed 1.5"
    0.0 <= features.closed_fraction <= 1.0 || return false, "invalid closed-flux fraction"
    if features.open_fraction > 1.0e-9
        open_connections = count(item -> item.kind == "open_field_line", genome.flux_connections)
        open_connections >= 2 || return false,
            "an open-field component requires two explicit end connections"
        features.mirror_ratio >= 2.0 || return false,
            "an open-field component requires mirror ratio at least 2"
    end
    if features.closed_fraction > 1.0e-9
        genome.topology.expected_flux_surfaces !== false || return false,
            "closed-flux fraction contradicts expected_flux_surfaces=false"
    end
    if features.internal_coil_fraction > 1.0e-9
        any(path -> occursin("internal", lowercase(path)) ||
            occursin("levitated", lowercase(path)), genome.engineering.access_paths) ||
            return false, "internal coil requires an explicit maintenance/access path"
    end
    return true, "typed topology graph, component invariants, and explicit common-envelope consistency passed"
end

function _confinement_time_at_power_s(features, contract, minor_radius_m,
        density_m3, power_MW, field_quality)
    power = max(power_MW, 0.1)
    R = contract.major_scale_m
    B = contract.plasma_field_T
    n19 = max(density_m3 / 1.0e19, 0.01)
    a = minor_radius_m
    kappa = 1.65
    plasma_current_MA = _expected_screen_plasma_current_MA(features, contract)
    epsilon = a / R
    tau_ipb = 0.0562 * plasma_current_MA^0.93 * B^0.15 * n19^0.41 *
        power^(-0.69) * R^1.97 * epsilon^0.58 * kappa^0.78 * 2.5^0.19
    iota = clamp(0.25 + 0.55 * features.external_transform_fraction, 0.2, 1.0)
    renormalization = clamp(0.55 + 0.55 * field_quality, 0.55, 1.10)
    tau_iss04 = 0.134 * renormalization * a^2.28 * R^0.64 *
        power^(-0.61) * n19^0.54 * B^0.84 * iota^0.41
    n20 = max(density_m3 / 1.0e20, 0.02)
    effective_mirror_ratio = max(1.01, features.mirror_ratio *
        (1.0 + 1.5 * features.plug_strength + 0.75 * features.minimum_b_strength))
    n20_tau = 0.25 * log10(effective_mirror_ratio)
    tau_mirror = max(1.0e-4, n20_tau / n20)
    closed_weight_sum = features.plasma_current_fraction +
        features.external_transform_fraction
    tau_closed = closed_weight_sum <= 1.0e-9 ? tau_iss04 : begin
        tokamak_weight = features.plasma_current_fraction / closed_weight_sum
        stellarator_weight = features.external_transform_fraction / closed_weight_sum
        1.0 / (tokamak_weight / max(tau_ipb, 1.0e-5) +
            stellarator_weight / max(tau_iss04, 1.0e-5))
    end
    if features.closed_fraction >= 1.0 - 1.0e-9
        return tau_closed, tau_ipb, tau_iss04, tau_mirror, plasma_current_MA
    elseif features.open_fraction >= 1.0 - 1.0e-9
        return tau_mirror, tau_ipb, tau_iss04, tau_mirror, plasma_current_MA
    end
    interface_penalty = 1.0 + 0.35 * features.open_fraction * features.closed_fraction
    tau_mixed = 1.0 / (features.closed_fraction / max(tau_closed, 1.0e-5) +
        features.open_fraction / max(tau_mirror, 1.0e-5)) / interface_penalty
    return tau_mixed, tau_ipb, tau_iss04, tau_mirror, plasma_current_MA
end

function _solve_loss_power_MW(features, contract, minor_radius_m, density_m3,
        stored_energy_MJ, field_quality)
    residual(power) = begin
        tau = first(_confinement_time_at_power_s(features, contract,
            minor_radius_m, density_m3, power, field_quality))
        power - stored_energy_MJ / max(tau, 1.0e-9)
    end
    low, high = 0.01, 10000.0
    residual(high) > 0 || return high
    for _ in 1:80
        mid = sqrt(low * high)
        if residual(mid) > 0
            high = mid
        else
            low = mid
        end
    end
    return sqrt(low * high)
end

function _screen_core(genome::Genome, contract::CommonComparisonContract, features;
        field_multiplier::Float64 = 1.0, beta_multiplier::Float64 = 1.0,
        dimension_multiplier::Float64 = 1.0, field_quality_penalty::Float64 = 0.0)
    mu0 = 4.0e-7 * pi
    R = contract.major_scale_m
    aspect_ratio = features.aspect_ratio
    a = R / aspect_ratio * dimension_multiplier
    beta = features.beta * beta_multiplier
    B0 = contract.plasma_field_T * field_multiplier
    T_keV = features.temperature_keV
    T_J = T_keV * 1.602176634e-16
    reactivity = _dt_reactivity_m3_s(T_keV)
    valid_reactivity = isfinite(reactivity)
    field_quality = clamp(features.field_quality - field_quality_penalty, 0.0, 1.0)

    kappa = 1.65
    closed_volume = 2.0 * pi^2 * R * a^2 * kappa
    open_length = 2.0 * R
    open_volume = pi * a^2 * open_length
    volume = features.closed_fraction * closed_volume + features.open_fraction * open_volume
    closed_area = 4.0 * pi^2 * R * a * sqrt((1.0 + kappa^2) / 2.0)
    open_area = 2.0 * pi * a * open_length + 2.0 * pi * a^2
    first_wall_area = features.closed_fraction * closed_area +
        features.open_fraction * open_area

    pressure = beta * B0^2 / (2.0 * mu0)
    density = pressure / max(2.0 * T_J, 1.0e-30)
    fusion_energy_J = 17.6e6 * 1.602176634e-19
    fusion_power_density = valid_reactivity ?
        0.25 * density^2 * reactivity * fusion_energy_J : 0.0
    fusion_power = fusion_power_density * volume
    alpha_power = 0.20 * fusion_power
    stored_energy_MJ = 1.5 * pressure * volume / 1.0e6
    loss_power_MW = _solve_loss_power_MW(features, contract, a, density,
        stored_energy_MJ, field_quality)
    confinement = _confinement_time_at_power_s(features, contract, a, density,
        loss_power_MW, field_quality)
    tau_E, tau_ipb, tau_iss04, tau_mirror, plasma_current_MA = confinement
    required_auxiliary_power = max(0.0, loss_power_MW * 1.0e6 - alpha_power)
    fusion_gain = fusion_power / max(required_auxiliary_power, 1.0)
    net_electric_power = contract.thermal_conversion_efficiency * fusion_power -
        required_auxiliary_power / contract.heating_wall_plug_efficiency -
        contract.fixed_balance_of_plant_load_W
    neutron_wall_load = 0.80 * fusion_power / max(first_wall_area, 1.0e-9)

    closed_peak_ratio = 1.0 + 1.0 / max(aspect_ratio - 1.0, 0.25) +
        0.30 * features.three_d_fraction + 0.45 * features.internal_coil_fraction
    open_peak_ratio = max(1.0, features.mirror_ratio)
    peak_ratio = max(features.closed_fraction > 1.0e-9 ? closed_peak_ratio : 0.0,
        features.open_fraction > 1.0e-9 ? open_peak_ratio : 0.0)
    peak_field = B0 * peak_ratio
    winding_factor = 1.15 + 0.30 * features.three_d_fraction +
        0.20 * features.internal_coil_fraction
    engineering_current_density = peak_field /
        (mu0 * max(features.coil_pack_thickness_m, 0.02)) / 1.0e6 * winding_factor
    magnetic_pressure = peak_field^2 / (2.0 * mu0)
    external_coil_radius = max(0.05, R - a - contract.shield_thickness_m)
    open_coil_radius = max(0.05, a)
    internal_coil_radius = max(0.05, 0.30 * a)
    curvature_radius = minimum(filter(>(0.0), Float64[
        features.closed_fraction > 1.0e-9 ?
            external_coil_radius / (1.0 + 1.4 * features.three_d_fraction) : Inf,
        features.open_fraction > 1.0e-9 ? open_coil_radius : Inf,
        features.internal_coil_fraction > 1.0e-9 ? internal_coil_radius : Inf,
    ]))
    load_amplification = 1.0 + 0.80 * features.three_d_fraction +
        0.75 * features.internal_coil_fraction
    support_stress = magnetic_pressure * load_amplification *
        min(external_coil_radius, 2.5) / max(features.support_thickness_m, 0.05)
    force_per_length = magnetic_pressure *
        (features.coil_pack_thickness_m + features.support_thickness_m) * load_amplification
    radial_available = max(0.0, R - a)
    radial_required = contract.shield_thickness_m + contract.maintenance_gap_m +
        features.coil_pack_thickness_m + features.support_thickness_m
    radial_build_margin = radial_available - radial_required
    internal_access_margin = features.internal_coil_fraction <= 1.0e-9 ? Inf :
        a - (internal_coil_radius + contract.shield_thickness_m +
            contract.maintenance_gap_m)

    tokamak_beta_N = 100.0 * beta * a * B0 / max(plasma_current_MA, 0.05)
    tokamak_stability_margin = 3.5 - tokamak_beta_N
    stellarator_beta_cap = 0.055 + 0.025 * field_quality +
        0.020 * features.minimum_b_strength
    stellarator_stability_margin = stellarator_beta_cap - beta
    mirror_beta_cap = 0.20 + 0.15 * features.minimum_b_strength +
        0.10 * features.shear_strength + 0.08 * features.plug_strength
    mirror_stability_margin = mirror_beta_cap - beta
    closed_stability_margin = begin
        weights = features.plasma_current_fraction + features.external_transform_fraction
        if weights <= 1.0e-9
            stellarator_stability_margin
        else
            (features.plasma_current_fraction * tokamak_stability_margin / 3.5 +
                features.external_transform_fraction *
                    stellarator_stability_margin / max(stellarator_beta_cap, 1.0e-9)) / weights
        end
    end
    open_stability_margin = mirror_stability_margin / max(mirror_beta_cap, 1.0e-9)
    stability_margin = features.closed_fraction * closed_stability_margin +
        features.open_fraction * open_stability_margin

    closed_particle_loss = 0.02 + (1.0 - field_quality) *
        (0.30 + 0.20 * features.three_d_fraction) +
        0.025 * features.internal_coil_fraction
    effective_mirror_ratio = max(1.0, features.mirror_ratio *
        (1.0 + 1.5 * features.plug_strength + 0.75 * features.minimum_b_strength))
    open_particle_loss = 1.0 / effective_mirror_ratio
    particle_loss_fraction = features.closed_fraction * closed_particle_loss +
        features.open_fraction * open_particle_loss

    auxiliary_margin = (contract.auxiliary_heating_budget_W - required_auxiliary_power) /
        contract.auxiliary_heating_budget_W
    peak_field_margin = (contract.peak_conductor_field_limit_T - peak_field) /
        contract.peak_conductor_field_limit_T
    current_density_margin = (contract.engineering_current_density_limit_A_mm2 -
        engineering_current_density) / contract.engineering_current_density_limit_A_mm2
    stress_margin = (contract.support_stress_limit_Pa - support_stress) /
        contract.support_stress_limit_Pa
    curvature_margin = (curvature_radius - contract.minimum_coil_curvature_radius_m) /
        contract.minimum_coil_curvature_radius_m
    wall_load_margin = (contract.maximum_neutron_wall_load_W_m2 - neutron_wall_load) /
        contract.maximum_neutron_wall_load_W_m2
    net_power_margin = net_electric_power /
        max(contract.fixed_balance_of_plant_load_W, 1.0)
    particle_loss_margin = (0.25 - particle_loss_fraction) / 0.25
    fusion_gain_margin = fusion_gain - 1.0
    build_margin = radial_build_margin / max(radial_required, 1.0e-9)
    internal_margin = isfinite(internal_access_margin) ?
        internal_access_margin / max(a, 1.0e-9) : 1.0
    temperature_margin = min((T_keV - 5.0) / 5.0, (30.0 - T_keV) / 5.0)
    margins = Dict{String,Float64}(
        "temperature_domain" => temperature_margin,
        "stability" => stability_margin,
        "particle_loss" => particle_loss_margin,
        "fusion_gain" => fusion_gain_margin,
        "auxiliary_power" => auxiliary_margin,
        "peak_conductor_field" => peak_field_margin,
        "engineering_current_density" => current_density_margin,
        "support_stress" => stress_margin,
        "radial_build" => build_margin,
        "internal_access" => internal_margin,
        "coil_curvature" => curvature_margin,
        "neutron_wall_load" => wall_load_margin,
    )
    physics_gate = valid_reactivity && stability_margin >= 0.0 &&
        particle_loss_margin >= 0.0 && auxiliary_margin >= 0.0 &&
        fusion_gain_margin >= 0.0
    engineering_gate = all(margins[id] >= 0.0 for id in
        ("peak_conductor_field", "engineering_current_density", "support_stress",
            "radial_build", "internal_access", "coil_curvature", "neutron_wall_load"))
    return Dict{String,Any}(
        "minor_radius_m" => a,
        "plasma_volume_m3" => volume,
        "first_wall_area_m2" => first_wall_area,
        "beta" => beta,
        "temperature_keV" => T_keV,
        "pressure_Pa" => pressure,
        "density_m3" => density,
        "dt_reactivity_m3_s" => valid_reactivity ? reactivity : 0.0,
        "fusion_power_density_W_m3" => fusion_power_density,
        "fusion_power_W" => fusion_power,
        "alpha_power_W" => alpha_power,
        "stored_energy_MJ" => stored_energy_MJ,
        "energy_confinement_time_s" => tau_E,
        "ipb98y2_time_s" => tau_ipb,
        "iss04_time_s" => tau_iss04,
        "mirror_time_proxy_s" => tau_mirror,
        "plasma_current_MA" => plasma_current_MA,
        "required_auxiliary_power_W" => required_auxiliary_power,
        "fusion_gain_proxy" => fusion_gain,
        "net_electric_power_W" => net_electric_power,
        "neutron_wall_load_W_m2" => neutron_wall_load,
        "particle_loss_fraction_proxy" => particle_loss_fraction,
        "minimum_stability_margin_proxy" => stability_margin,
        "peak_conductor_field_T" => peak_field,
        "engineering_current_density_A_mm2" => engineering_current_density,
        "magnetic_pressure_Pa" => magnetic_pressure,
        "support_stress_proxy_Pa" => support_stress,
        "force_per_length_proxy_N_m" => force_per_length,
        "minimum_coil_curvature_radius_m" => curvature_radius,
        "radial_build_margin_m" => radial_build_margin,
        "internal_access_margin_m" => isfinite(internal_access_margin) ?
            internal_access_margin : 1.0e9,
        "tokamak_beta_N_proxy" => tokamak_beta_N,
        "physics_gate_passed" => physics_gate,
        "engineering_gate_passed" => engineering_gate,
        "margins" => margins,
        "minimum_normalized_margin" => minimum(values(margins)),
    )
end

function _robustness_audit(genome::Genome, contract::CommonComparisonContract, features)
    rng = MersenneTwister(contract.robustness_seed)
    records = Dict{String,Any}[]
    pass_count = 0
    worst_margin = Inf
    for sample in 1:contract.robustness_samples
        field_delta = 0.02 * (2.0 * rand(rng) - 1.0)
        beta_delta = 0.15 * (2.0 * rand(rng) - 1.0)
        dimension_delta = 0.01 * (2.0 * rand(rng) - 1.0)
        coil_offset_m = 0.003 * (2.0 * rand(rng) - 1.0)
        control_error = 0.02 * (2.0 * rand(rng) - 1.0)
        a_nominal = contract.major_scale_m / features.aspect_ratio
        quality_penalty = abs(coil_offset_m) / max(a_nominal, 1.0e-9) *
            (1.0 + 3.0 * features.three_d_fraction +
                4.0 * features.internal_coil_fraction) +
            abs(control_error) * features.plasma_current_fraction
        values = _screen_core(genome, contract, features;
            field_multiplier = 1.0 + field_delta,
            beta_multiplier = 1.0 + beta_delta,
            dimension_multiplier = 1.0 + dimension_delta,
            field_quality_penalty = quality_penalty)
        passed = values["physics_gate_passed"] === true &&
            values["engineering_gate_passed"] === true
        passed && (pass_count += 1)
        worst_margin = min(worst_margin, Float64(values["minimum_normalized_margin"]))
        push!(records, Dict{String,Any}(
            "sample" => sample,
            "field_delta_fraction" => field_delta,
            "beta_delta_fraction" => beta_delta,
            "dimension_delta_fraction" => dimension_delta,
            "coil_offset_m" => coil_offset_m,
            "control_error_fraction" => control_error,
            "field_quality_penalty" => quality_penalty,
            "passed" => passed,
            "minimum_normalized_margin" => values["minimum_normalized_margin"],
        ))
    end
    pass_fraction = pass_count / contract.robustness_samples
    return Dict{String,Any}(
        "sample_count" => contract.robustness_samples,
        "common_random_seed" => contract.robustness_seed,
        "pass_count" => pass_count,
        "pass_fraction" => pass_fraction,
        "required_pass_fraction" => contract.robustness_required_pass_fraction,
        "gate_passed" => pass_fraction >= contract.robustness_required_pass_fraction,
        "worst_minimum_normalized_margin" => worst_margin,
        "records" => records,
    )
end

function _unified_metric(id, value; unit = "1", status = :pass,
        input_hash, run_hash, contract_hash, warnings = String[],
        residuals = Dict{String,Float64}())
    return MetricResult(id, value;
        unit = unit,
        fidelity = 0,
        applicability = "D-T common-envelope comparison contract $contract_hash; topology-specific branches are rejection proxies.",
        status = status,
        constraints_checked = ["five-gate common-envelope screen"],
        solver_name = "unified_cross_family_screen_v1",
        solver_version = "1.0.0",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = _UNIFIED_SCREEN_SOURCE_BASIS,
        warnings = warnings,
        residuals = residuals,
        wall_time_s = 0.0)
end

function _unified_screen_result(evaluator::UnifiedCrossFamilyScreenV1, genome::Genome)
    contract = evaluator.contract
    contract_hash = canonical_hash(_common_contract_dict(contract))
    features = _topology_features(genome)
    topology_gate, topology_reason = _topology_contract_gate(genome, features, contract)
    nominal = _screen_core(genome, contract, features)
    robustness = if topology_gate && nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true
        _robustness_audit(genome, contract, features)
    else
        Dict{String,Any}(
            "sample_count" => 0,
            "maximum_sample_budget" => contract.robustness_samples,
            "common_random_seed" => contract.robustness_seed,
            "pass_count" => 0,
            "pass_fraction" => 0.0,
            "required_pass_fraction" => contract.robustness_required_pass_fraction,
            "gate_passed" => false,
            "worst_minimum_normalized_margin" =>
                Float64(nominal["minimum_normalized_margin"]),
            "records" => Dict{String,Any}[],
            "skipped_due_nominal_gate_failure" => true,
        )
    end
    baseline_gate = contract_hash == canonical_hash(_common_contract_dict(
        default_common_comparison_contract()))
    all_gates = topology_gate && nominal["physics_gate_passed"] === true &&
        nominal["engineering_gate_passed"] === true && baseline_gate &&
        robustness["gate_passed"] === true
    complexity = length(genome.field_sources) + 1.5 * length(genome.actuators) +
        0.5 * length(genome.plasma_regions) + 0.25 * length(genome.flux_connections) +
        3.0 * features.three_d_fraction + 4.0 * features.internal_coil_fraction +
        2.0 * features.open_fraction
    result = Dict{String,Any}(
        "contract" => _common_contract_dict(contract),
        "contract_hash" => contract_hash,
        "claim_boundary" => _UNIFIED_SCREEN_CLAIM_BOUNDARY,
        "topology_features" => Dict(String(key) => value for (key, value) in pairs(features)),
        "topology_gate_reason" => topology_reason,
        "nominal" => nominal,
        "robustness" => robustness,
        "gates" => Dict(
            "variable_topology_representation" => topology_gate,
            "unified_low_fidelity_physics" => nominal["physics_gate_passed"],
            "minimal_engineering_closure" => nominal["engineering_gate_passed"],
            "common_baseline_contract" => baseline_gate,
            "cheap_robustness_screen" => robustness["gate_passed"],
        ),
        "all_five_gates_passed" => all_gates,
        "classification" => all_gates ? "temporarily_plausible" : "obviously_infeasible_or_unresolved",
        "device_complexity_proxy" => complexity,
    )
    result["result_hash"] = canonical_hash(result)
    return result
end

function run_evaluator(evaluator::UnifiedCrossFamilyScreenV1, genome::Genome; kwargs...)
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return _non_applicable_bundle(evaluator_spec(evaluator), genome, reason)
    result = _unified_screen_result(evaluator, genome)
    nominal = result["nominal"]
    robustness = result["robustness"]
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "evaluator" => "unified_cross_family_screen_v1",
        "version" => "1.0.0",
        "result_hash" => result["result_hash"],
    ))
    warnings = String[
        _UNIFIED_SCREEN_CLAIM_BOUNDARY,
        "IPB98(y,2), ISS04, and mirror confinement branches have different empirical domains; common outputs do not make their model-form uncertainties equal.",
        "The robustness scan perturbs the reduced model only; missing failure modes cannot be passed by Monte Carlo sampling.",
        "A generated field-quality gene is a search hypothesis that must be replaced by an equilibrium/field-line calculation before promotion.",
        "Blanket neutronics, divertor/end recovery, radiation damage, quench, joints, detailed supports, and RAMI remain unresolved.",
    ]
    metrics = MetricResult[]
    units = Dict(
        "minor_radius_m" => "m", "plasma_volume_m3" => "m^3",
        "first_wall_area_m2" => "m^2", "pressure_Pa" => "Pa",
        "density_m3" => "m^-3", "dt_reactivity_m3_s" => "m^3/s",
        "fusion_power_density_W_m3" => "W/m^3", "fusion_power_W" => "W",
        "alpha_power_W" => "W", "stored_energy_MJ" => "MJ",
        "energy_confinement_time_s" => "s", "ipb98y2_time_s" => "s",
        "iss04_time_s" => "s", "mirror_time_proxy_s" => "s",
        "required_auxiliary_power_W" => "W", "net_electric_power_W" => "W",
        "neutron_wall_load_W_m2" => "W/m^2", "peak_conductor_field_T" => "T",
        "engineering_current_density_A_mm2" => "A/mm^2",
        "magnetic_pressure_Pa" => "Pa", "support_stress_proxy_Pa" => "Pa",
        "force_per_length_proxy_N_m" => "N/m",
        "minimum_coil_curvature_radius_m" => "m", "radial_build_margin_m" => "m",
        "internal_access_margin_m" => "m", "plasma_current_MA" => "MA",
    )
    for id in sort!(String[key for key in keys(nominal) if key != "margins"])
        value = nominal[id]
        value isa AbstractDict && continue
        status = id in ("physics_gate_passed", "engineering_gate_passed") ?
            (value === true ? :pass : :fail) : :pass
        push!(metrics, _unified_metric(id, value;
            unit = get(units, id, "1"), status = status,
            input_hash = genome.physics_hash, run_hash = run_hash,
            contract_hash = result["contract_hash"], warnings = warnings))
    end
    for id in sort!(collect(keys(result["gates"])))
        value = result["gates"][id]
        push!(metrics, _unified_metric("gate_$id", value;
            status = value === true ? :pass : :fail,
            input_hash = genome.physics_hash, run_hash = run_hash,
            contract_hash = result["contract_hash"], warnings = warnings))
    end
    push!(metrics, _unified_metric("robustness_pass_fraction",
        robustness["pass_fraction"];
        status = robustness["gate_passed"] === true ? :pass : :fail,
        input_hash = genome.physics_hash, run_hash = run_hash,
        contract_hash = result["contract_hash"], warnings = warnings,
        residuals = Dict("worst_minimum_normalized_margin" => Float64(
            robustness["worst_minimum_normalized_margin"]))))
    push!(metrics, _unified_metric("device_complexity_proxy",
        result["device_complexity_proxy"];
        input_hash = genome.physics_hash, run_hash = run_hash,
        contract_hash = result["contract_hash"], warnings = warnings))
    push!(metrics, _unified_metric("temporarily_plausible_under_proxy_contract",
        result["all_five_gates_passed"];
        status = result["all_five_gates_passed"] === true ? :pass : :fail,
        input_hash = genome.physics_hash, run_hash = run_hash,
        contract_hash = result["contract_hash"], warnings = warnings))
    for (id, message) in (
            ("equilibrium_solved", "no topology-specific equilibrium was solved"),
            ("all_mode_stability_feasible", "only reduced stability screens were applied"),
            ("particle_transport_validated", "no orbit or kinetic transport solve was run"),
            ("integrated_engineering_feasible", "minimal engineering closure is not integrated engineering"),
            ("device_superiority_established", "common proxy comparison cannot establish superiority"))
        push!(metrics, _unified_metric(id, nothing; status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            contract_hash = result["contract_hash"], warnings = vcat(warnings, [message])))
    end
    return EvaluationBundle("unified_cross_family_screen_v1", genome.design_id,
        genome.family, 0, result["all_five_gates_passed"] === true ? :pass : :fail,
        metrics, warnings, genome.physics_hash, run_hash, "physics_proxy")
end
