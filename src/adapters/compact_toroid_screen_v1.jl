const _CT_SCREEN_CLAIM_BOUNDARY =
    "Fidelity-0 compact-toroid rejection screen under the common D-T comparison contract. " *
    "The core/SOL graph, Bohm transport reference, stability-mechanism coverage, actuator power, " *
    "and minimal magnet/build/heat-load proxies do not establish equilibrium, stability, transport, " *
    "exhaust, net electricity, or reactor engineering feasibility."

"Family-specific low-fidelity screen for FRC and spheromak compact toroids."
struct CompactToroidScreenV1 <: AbstractEvaluator
    contract::CommonComparisonContract
end

CompactToroidScreenV1() = CompactToroidScreenV1(default_common_comparison_contract())

function evaluator_spec(::CompactToroidScreenV1)
    return EvaluatorSpec(
        "compact_toroid_screen_v1",
        "1.0.0",
        ["field_reversed_configuration", "spheromak"],
        0,
        Dict(
            "equilibrium" => :proxy,
            "stability" => :proxy,
            "energy_confinement" => :proxy,
            "power_balance" => :proxy,
            "exhaust" => :proxy,
            "actuator_power" => :proxy,
            "minimal_engineering" => :proxy,
            "manufacturing_tolerance" => :proxy,
        ),
        _CT_SCREEN_CLAIM_BOUNDARY,
    )
end

function evaluator_applicability(evaluator::CompactToroidScreenV1, genome::Genome)
    genome.family in evaluator_spec(evaluator).families || return false,
        "compact_toroid_screen_v1 applies only to FRC and spheromak families"
    genome.mission.fuel == "D-T" || return false,
        "compact_toroid_screen_v1 version 1 is restricted to the common D-T mission"
    family = validate_family(default_family_registry(), genome)
    family.valid || return false, join(family.errors, "; ")
    return true, "compact-toroid branch under common contract $(evaluator.contract.id)"
end

function _ct_target(genome::Genome, name::String, default::Real, unit::String)
    value = get(genome.mission.targets, name, nothing)
    value === nothing && return Float64(default)
    value.unit == unit || throw(ArgumentError(
        "mission.targets.$name must use canonical unit $unit, got $(value.unit)"))
    return value.value
end

_ct_fraction(genome, name, default) =
    clamp(_ct_target(genome, name, default, "1"), 0.0, 1.0)

function _ct_actuator_power_W(genome::Genome)
    total = 0.0
    for actuator in genome.actuators
        power = get(actuator.parameters, "power", nothing)
        power === nothing && continue
        power.unit == "W" || throw(ArgumentError(
            "actuator $(actuator.id).power must use canonical unit W"))
        total += power.value
    end
    return total
end

function _compact_toroid_features(genome::Genome)
    family = genome.family
    temperature_J = _ct_target(genome, "screen_temperature",
        15.0 * 1.602176634e-16, "J")
    return (
        family = family,
        elongation = _ct_target(genome, "screen_aspect_ratio",
            family == "field_reversed_configuration" ? 4.0 : 1.5, "1"),
        beta = _ct_fraction(genome, "screen_beta",
            family == "field_reversed_configuration" ? 0.65 : 0.12),
        temperature_keV = temperature_J / 1.602176634e-16,
        edge_open_volume_fraction = _ct_fraction(genome,
            "screen_edge_open_volume_fraction", 0.08),
        exhaust_area_fraction = _ct_fraction(genome,
            "screen_exhaust_area_fraction", 0.20),
        field_quality = _ct_fraction(genome, "screen_field_quality", 0.90),
        coil_pack_thickness_m = _ct_target(genome,
            "screen_coil_pack_thickness", 0.50, "m"),
        support_thickness_m = _ct_target(genome,
            "screen_support_thickness", 0.80, "m"),
        actuator_power_W = _ct_actuator_power_W(genome),
    )
end

function _ct_has_kind(items, fragment::String)
    return any(item -> occursin(fragment, lowercase(item.kind)), items)
end

function _ct_graph_errors(genome::Genome, features,
        contract::CommonComparisonContract)
    errors = String[]
    report = validate_genome(genome)
    append!(errors, report.errors)
    genome.topology.field_line_class == "compact_toroid" ||
        push!(errors, "compact-toroid family requires compact_toroid field-line class")
    genome.topology.expected_flux_surfaces === true ||
        push!(errors, "compact-toroid core must declare expected closed flux surfaces")
    genome.topology.expected_separatrix === true ||
        push!(errors, "compact-toroid core must declare a separatrix")
    core_regions = filter(region -> region.kind == "compact_toroid_closed_core",
        genome.plasma_regions)
    length(core_regions) == 1 ||
        push!(errors, "exactly one compact_toroid_closed_core region is required")
    sol_regions = filter(region -> region.kind == "scrape_off_layer",
        genome.plasma_regions)
    length(sol_regions) == 1 || push!(errors, "exactly one scrape_off_layer is required")
    targets = filter(region -> region.kind == "divertor_or_exhaust_region",
        genome.plasma_regions)
    length(targets) == 2 || push!(errors, "exactly two explicit exhaust targets are required")
    if length(core_regions) == 1 && length(sol_regions) == 1
        core_id = only(core_regions).id
        sol_id = only(sol_regions).id
        cross = count(connection ->
            connection.from_region_id == core_id && connection.to_region_id == sol_id &&
            connection.kind == "cross_separatrix_transport", genome.flux_connections)
        cross == 1 || push!(errors,
            "one explicit core-to-SOL cross_separatrix_transport edge is required")
        open_to_targets = count(connection ->
            connection.from_region_id == sol_id && connection.kind == "open_field_line" &&
            any(target -> target.id == connection.to_region_id, targets),
            genome.flux_connections)
        open_to_targets == 2 || push!(errors,
            "the SOL must connect to both targets with open_field_line edges")
        core_id in genome.exhaust.region_ids &&
            push!(errors, "closed core cannot be listed as an exhaust region")
        sol_id in genome.exhaust.region_ids ||
            push!(errors, "SOL must be listed in the exhaust region set")
    end
    any(source -> occursin("toroidal_field_coil", lowercase(source.kind)),
        genome.field_sources) && push!(errors,
        "compact-toroid v1 forbids an external toroidal-field-coil set")
    if genome.family == "field_reversed_configuration"
        genome.topology.rotation_transform_sources == ["not_applicable"] ||
            push!(errors, "FRC transform source must be only not_applicable")
        _ct_has_kind(genome.field_sources, "axisymmetric_solenoid") ||
            push!(errors, "FRC requires an explicit axisymmetric solenoidal field source")
        _ct_has_kind(genome.field_sources, "frc_plasma_current") ||
            push!(errors, "FRC requires an explicit field-reversing plasma-current source")
        any(mechanism -> "global_tilt" in mechanism.target_modes,
            genome.stability_mechanisms) ||
            push!(errors, "FRC requires an explicit global-tilt mechanism")
        any(mechanism -> "shift" in mechanism.target_modes,
            genome.stability_mechanisms) ||
            push!(errors, "FRC requires an explicit shift-mode mechanism")
    elseif genome.family == "spheromak"
        genome.topology.rotation_transform_sources == ["self_organized_current"] ||
            push!(errors, "spheromak requires self_organized_current as its transform source")
        _ct_has_kind(genome.field_sources, "self_organized_plasma_current") ||
            push!(errors, "spheromak requires an explicit self-organized plasma-current source")
        _ct_has_kind(genome.field_sources, "flux_conserver") ||
            push!(errors, "spheromak requires an explicit close-fitting flux conserver")
        _ct_has_kind(genome.actuators, "helicity_injector") ||
            push!(errors, "spheromak requires explicit helicity injectors")
        any(mechanism -> "resistive_tearing" in mechanism.target_modes,
            genome.stability_mechanisms) ||
            push!(errors, "spheromak requires explicit resistive-tearing coverage")
    end
    features.actuator_power_W > 0.0 ||
        push!(errors, "active compact-toroid sustainment requires nonzero declared actuator power")
    0.0 < features.edge_open_volume_fraction <= 0.30 ||
        push!(errors, "edge open-volume fraction must be in (0, 0.30]")
    0.02 <= features.exhaust_area_fraction <= 0.50 ||
        push!(errors, "exhaust area fraction must be in [0.02, 0.50]")
    return sort!(unique(errors))
end

function _ct_spheroid_area(a::Float64, c::Float64)
    p = 1.6075
    return 4.0 * pi * ((a^(2.0 * p) + 2.0 * (a * c)^p) / 3.0)^(1.0 / p)
end

function _ct_required_tau_for_positive_net_s(stored_energy_J::Float64,
        fusion_power_W::Float64, actuator_power_W::Float64,
        contract::CommonComparisonContract)
    alpha_power = 0.20 * fusion_power_W
    maximum_total_auxiliary = contract.heating_wall_plug_efficiency *
        (contract.thermal_conversion_efficiency * fusion_power_W -
            contract.fixed_balance_of_plant_load_W)
    maximum_transport_auxiliary = maximum_total_auxiliary - actuator_power_W
    allowed_transport_loss = alpha_power + maximum_transport_auxiliary
    allowed_transport_loss > 0.0 || return Inf
    return stored_energy_J / allowed_transport_loss
end

function _compact_toroid_nominal(genome::Genome,
        contract::CommonComparisonContract, features;
        field_multiplier::Float64 = 1.0,
        beta_multiplier::Float64 = 1.0,
        dimension_multiplier::Float64 = 1.0,
        actuator_multiplier::Float64 = 1.0,
        field_quality_penalty::Float64 = 0.0)
    mu0 = 4.0e-7 * pi
    elementary_charge = 1.602176634e-19
    deuterium_mass = 3.3435837724e-27
    c = contract.major_scale_m * dimension_multiplier
    elongation = max(features.elongation, 1.01)
    a = c / elongation
    beta = features.beta * beta_multiplier
    B0 = contract.plasma_field_T * field_multiplier
    T_keV = features.temperature_keV
    T_J = T_keV * 1.602176634e-16
    reactivity = _dt_reactivity_m3_s(T_keV)
    valid_reactivity = isfinite(reactivity)
    field_quality = clamp(features.field_quality - field_quality_penalty, 0.0, 1.0)

    core_volume = 4.0 / 3.0 * pi * a^2 * c
    first_wall_area = _ct_spheroid_area(a, c)
    edge_volume = features.edge_open_volume_fraction * core_volume
    exhaust_area = max(features.exhaust_area_fraction * first_wall_area, 1.0e-9)
    pressure = beta * B0^2 / (2.0 * mu0)
    density = pressure / max(2.0 * T_J, 1.0e-30)
    fusion_energy_J = 17.6e6 * elementary_charge
    fusion_power_density = valid_reactivity ?
        0.25 * density^2 * reactivity * fusion_energy_J : 0.0
    fusion_power = fusion_power_density * core_volume
    alpha_power = 0.20 * fusion_power
    stored_energy_J = 1.5 * pressure * core_volume

    # D_B = T_e / (16 e B); using T_e in joules keeps dimensions explicit.
    bohm_diffusivity_m2_s = T_J / max(16.0 * elementary_charge * B0, 1.0e-30)
    bohm_time_s = a^2 / max(bohm_diffusivity_m2_s, 1.0e-30) * field_quality
    thermal_speed = sqrt(2.0 * T_J / deuterium_mass)
    ion_gyro_radius_m = deuterium_mass * thermal_speed /
        max(elementary_charge * B0, 1.0e-30)
    kinetic_size_parameter = a / max(ion_gyro_radius_m, 1.0e-30)
    transport_loss_W = stored_energy_J / max(bohm_time_s, 1.0e-30)
    actuator_power = features.actuator_power_W * actuator_multiplier
    transport_auxiliary = max(0.0, transport_loss_W - alpha_power)
    total_auxiliary = transport_auxiliary + actuator_power
    fusion_gain = fusion_power / max(total_auxiliary, 1.0)
    net_electric_power = contract.thermal_conversion_efficiency * fusion_power -
        total_auxiliary / contract.heating_wall_plug_efficiency -
        contract.fixed_balance_of_plant_load_W
    required_tau_s = _ct_required_tau_for_positive_net_s(stored_energy_J,
        fusion_power, actuator_power, contract)
    confinement_ratio = isfinite(required_tau_s) ?
        bohm_time_s / max(required_tau_s, 1.0e-30) : 0.0
    exhaust_heat_flux = transport_loss_W / exhaust_area
    neutron_wall_load = 0.80 * fusion_power / max(first_wall_area, 1.0e-9)

    peak_ratio = genome.family == "field_reversed_configuration" ? 1.55 : 1.35
    peak_field = B0 * peak_ratio
    engineering_current_density = peak_field /
        (mu0 * max(features.coil_pack_thickness_m, 0.02)) / 1.0e6 * 1.15
    magnetic_pressure = peak_field^2 / (2.0 * mu0)
    support_stress = magnetic_pressure * min(a, 2.5) /
        max(features.support_thickness_m, 0.05)
    radial_available = max(0.0, contract.major_scale_m - a)
    radial_required = contract.shield_thickness_m + contract.maintenance_gap_m +
        features.coil_pack_thickness_m + features.support_thickness_m
    radial_build_margin = radial_available - radial_required
    minimum_curvature_radius = a

    has_stability_mechanism = if genome.family == "field_reversed_configuration"
        any(mechanism -> mechanism.mechanism in
            ("finite_larmor_radius", "fast_ion_kinetic", "rotating_magnetic_field"),
            genome.stability_mechanisms)
    else
        any(mechanism -> mechanism.mechanism in
            ("imposed_dynamo_current_drive", "steady_inductive_helicity_injection"),
            genome.stability_mechanisms)
    end
    beta_range_pass = genome.family == "field_reversed_configuration" ?
        0.30 <= beta <= 0.95 : 0.04 <= beta <= 0.25
    shape_range_pass = genome.family == "field_reversed_configuration" ?
        2.0 <= elongation <= 8.0 : 1.05 <= elongation <= 2.5
    stability_mechanism_gate = has_stability_mechanism && beta_range_pass &&
        shape_range_pass

    margins = Dict{String,Float64}(
        "temperature_domain" => min((T_keV - 5.0) / 5.0,
            (30.0 - T_keV) / 5.0),
        "bohm_transport_to_positive_net_requirement" => confinement_ratio - 1.0,
        "fusion_gain" => fusion_gain - 1.0,
        "auxiliary_power" =>
            (contract.auxiliary_heating_budget_W - total_auxiliary) /
            contract.auxiliary_heating_budget_W,
        "net_electric_power" => net_electric_power /
            max(contract.fixed_balance_of_plant_load_W, 1.0),
        "peak_conductor_field" =>
            (contract.peak_conductor_field_limit_T - peak_field) /
            contract.peak_conductor_field_limit_T,
        "engineering_current_density" =>
            (contract.engineering_current_density_limit_A_mm2 -
                engineering_current_density) /
            contract.engineering_current_density_limit_A_mm2,
        "support_stress" => (contract.support_stress_limit_Pa - support_stress) /
            contract.support_stress_limit_Pa,
        "radial_build" => radial_build_margin / max(radial_required, 1.0e-9),
        "coil_curvature" =>
            (minimum_curvature_radius - contract.minimum_coil_curvature_radius_m) /
            contract.minimum_coil_curvature_radius_m,
        "neutron_wall_load" =>
            (contract.maximum_neutron_wall_load_W_m2 - neutron_wall_load) /
            contract.maximum_neutron_wall_load_W_m2,
        "exhaust_target_heat_flux" => (10.0e6 - exhaust_heat_flux) / 10.0e6,
    )
    physics_gate = valid_reactivity && stability_mechanism_gate &&
        margins["bohm_transport_to_positive_net_requirement"] >= 0.0 &&
        margins["fusion_gain"] >= 0.0 && margins["auxiliary_power"] >= 0.0 &&
        margins["net_electric_power"] > 0.0
    engineering_gate = all(margins[id] >= 0.0 for id in (
        "peak_conductor_field", "engineering_current_density", "support_stress",
        "radial_build", "coil_curvature", "neutron_wall_load",
        "exhaust_target_heat_flux"))
    return Dict{String,Any}(
        "family" => genome.family,
        "minor_radius_m" => a,
        "half_length_m" => c,
        "elongation" => elongation,
        "core_plasma_volume_m3" => core_volume,
        "edge_open_volume_m3" => edge_volume,
        "first_wall_area_m2" => first_wall_area,
        "exhaust_target_area_m2" => exhaust_area,
        "beta" => beta,
        "temperature_keV" => T_keV,
        "pressure_Pa" => pressure,
        "density_m3" => density,
        "fusion_power_W" => fusion_power,
        "alpha_power_W" => alpha_power,
        "stored_energy_MJ" => stored_energy_J / 1.0e6,
        "bohm_diffusivity_m2_s" => bohm_diffusivity_m2_s,
        "bohm_energy_confinement_reference_s" => bohm_time_s,
        "required_energy_confinement_for_positive_net_s" =>
            isfinite(required_tau_s) ? required_tau_s : 1.0e99,
        "bohm_to_required_confinement_ratio" => confinement_ratio,
        "ion_gyro_radius_m" => ion_gyro_radius_m,
        "kinetic_size_parameter_a_over_rhoi" => kinetic_size_parameter,
        "transport_loss_power_W" => transport_loss_W,
        "declared_actuator_power_W" => actuator_power,
        "required_auxiliary_power_W" => total_auxiliary,
        "fusion_gain_proxy" => fusion_gain,
        "net_electric_power_W" => net_electric_power,
        "exhaust_heat_flux_W_m2" => exhaust_heat_flux,
        "neutron_wall_load_W_m2" => neutron_wall_load,
        "peak_conductor_field_T" => peak_field,
        "engineering_current_density_A_mm2" => engineering_current_density,
        "support_stress_proxy_Pa" => support_stress,
        "radial_build_margin_m" => radial_build_margin,
        "minimum_coil_curvature_radius_m" => minimum_curvature_radius,
        "stability_mechanism_coverage_passed" => stability_mechanism_gate,
        "physics_gate_passed" => physics_gate,
        "engineering_gate_passed" => engineering_gate,
        "margins" => margins,
        "minimum_normalized_margin" => minimum(values(margins)),
    )
end

function _compact_toroid_robustness(genome::Genome,
        contract::CommonComparisonContract, features)
    rng = MersenneTwister(contract.robustness_seed)
    records = Dict{String,Any}[]
    pass_count = 0
    worst_margin = Inf
    for sample in 1:contract.robustness_samples
        field_delta = 0.02 * (2.0 * rand(rng) - 1.0)
        beta_delta = 0.15 * (2.0 * rand(rng) - 1.0)
        dimension_delta = 0.01 * (2.0 * rand(rng) - 1.0)
        coil_offset_m = 0.003 * (2.0 * rand(rng) - 1.0)
        control_error = 0.10 * (2.0 * rand(rng) - 1.0)
        quality_penalty = abs(coil_offset_m) /
            max(contract.major_scale_m / features.elongation, 1.0e-9) +
            0.05 * abs(control_error)
        values = _compact_toroid_nominal(genome, contract, features;
            field_multiplier = 1.0 + field_delta,
            beta_multiplier = 1.0 + beta_delta,
            dimension_multiplier = 1.0 + dimension_delta,
            actuator_multiplier = 1.0 + control_error,
            field_quality_penalty = quality_penalty)
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
        "gate_passed" =>
            pass_fraction >= contract.robustness_required_pass_fraction,
        "worst_minimum_normalized_margin" => worst_margin,
        "records" => records,
    )
end

function _compact_toroid_screen_result(evaluator::CompactToroidScreenV1,
        genome::Genome)
    contract = evaluator.contract
    contract_hash = canonical_hash(_common_contract_dict(contract))
    features = _compact_toroid_features(genome)
    graph_errors = _ct_graph_errors(genome, features, contract)
    graph_gate = isempty(graph_errors)
    nominal = _compact_toroid_nominal(genome, contract, features)
    robustness = if graph_gate && nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true
        _compact_toroid_robustness(genome, contract, features)
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
                nominal["minimum_normalized_margin"],
            "records" => Dict{String,Any}[],
            "skipped_due_nominal_gate_failure" => true,
        )
    end
    baseline_gate = contract_hash == canonical_hash(_common_contract_dict(
        default_common_comparison_contract()))
    all_five = graph_gate && nominal["physics_gate_passed"] === true &&
        nominal["engineering_gate_passed"] === true && baseline_gate &&
        robustness["gate_passed"] === true
    complexity = length(genome.field_sources) + 1.5 * length(genome.actuators) +
        0.5 * length(genome.plasma_regions) +
        0.25 * length(genome.flux_connections)
    result = Dict{String,Any}(
        "contract" => _common_contract_dict(contract),
        "contract_hash" => contract_hash,
        "claim_boundary" => _CT_SCREEN_CLAIM_BOUNDARY,
        "topology_features" => Dict(String(key) => value for
            (key, value) in pairs(features)),
        "topology_graph_errors" => graph_errors,
        "nominal" => nominal,
        "robustness" => robustness,
        "gates" => Dict(
            "variable_topology_representation" => graph_gate,
            "unified_low_fidelity_physics" => nominal["physics_gate_passed"],
            "minimal_engineering_closure" => nominal["engineering_gate_passed"],
            "common_baseline_contract" => baseline_gate,
            "cheap_robustness_screen" => robustness["gate_passed"],
        ),
        "all_five_gates_passed" => all_five,
        "positive_net_power_closure_passed" =>
            nominal["net_electric_power_W"] > 0.0,
        "classification" => all_five ?
            "compact_toroid_low_fidelity_survivor_pending_medium_fidelity" :
            "obviously_infeasible_or_unresolved",
        "device_complexity_proxy" => complexity,
    )
    result["result_hash"] = canonical_hash(result)
    return result
end

function run_evaluator(evaluator::CompactToroidScreenV1, genome::Genome; kwargs...)
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return _non_applicable_bundle(evaluator_spec(evaluator), genome, reason)
    result = _compact_toroid_screen_result(evaluator, genome)
    nominal = result["nominal"]
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "evaluator" => "compact_toroid_screen_v1",
        "version" => "1.0.0",
        "result_hash" => result["result_hash"],
    ))
    status = result["all_five_gates_passed"] === true ? :pass : :fail
    metrics = MetricResult[
        MetricResult("compact_toroid_five_gate_pass",
            result["all_five_gates_passed"] ? 1.0 : 0.0;
            fidelity = 0, status = status,
            applicability = reason,
            constraints_checked = sort!(collect(keys(result["gates"]))),
            solver_name = "compact_toroid_screen_v1",
            solver_version = "1.0.0", input_hash = genome.physics_hash,
            run_hash = run_hash, source_basis = [
                "frc_steinhauer_review_2011", "frc_gerhardt_inductive_sustainment_2007",
                "frc_c2u_gota_2017", "frc_c2w_gota_2024",
                "spheromak_jarboe_review_1994", "spheromak_hit_si_jarboe_2006",
                "dynomak_2014", "w7x_island_divertor_2019",
                "bosch_hale_reactivity_1992"],
            warnings = [_CT_SCREEN_CLAIM_BOUNDARY]),
        MetricResult("net_electric_power_proxy",
            nominal["net_electric_power_W"];
            unit = "W", fidelity = 0,
            status = nominal["net_electric_power_W"] > 0.0 ? :pass : :fail,
            applicability = reason,
            constraints_checked = ["declared Bohm-reference transport and actuator power"],
            solver_name = "compact_toroid_screen_v1",
            solver_version = "1.0.0", input_hash = genome.physics_hash,
            run_hash = run_hash, source_basis = ["bosch_hale_reactivity_1992"],
            warnings = [_CT_SCREEN_CLAIM_BOUNDARY]),
    ]
    return EvaluationBundle("compact_toroid_screen_v1", genome.design_id,
        genome.family, 0, status, metrics, [_CT_SCREEN_CLAIM_BOUNDARY],
        genome.physics_hash, run_hash, _CT_SCREEN_CLAIM_BOUNDARY)
end
