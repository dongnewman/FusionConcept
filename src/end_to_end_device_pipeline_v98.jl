const V98_PROTOCOL_ID = "fusionconceptai-v98-end-to-end-device-pipeline-20260829"

const V98_CANDIDATE_STATES = Set([
    "topology_screen_fail", "provider_system_fail", "physics_screen_fail",
    "numerical_vvuq_fail", "computational_candidate", "validation_pass",
])

const END_TO_END_DEVICE_PIPELINE_V98_CLAIM_BOUNDARY =
    "v98 separates topology rejection, provider-system failure, candidate-bound reduced " *
    "physics rejection, numerical VVUQ, computational candidacy, and validation. Design " *
    "coordinates may propose geometry and operating inputs, but no basis coordinate receives " *
    "direct metric or gate credit. The reduced empirical confinement, Bosch-Hale reaction, " *
    "zero-dimensional power, and engineering screens are candidate-ranking evidence only; " *
    "they are not high-fidelity equilibrium, complete stability, materials qualification, " *
    "experimental validation, or a credible-device claim."

const V98_SCREEN_THRESHOLDS = Dict{String,Float64}(
    "minimum_temperature_kev" => 5.0,
    "maximum_temperature_kev" => 30.0,
    "minimum_aspect_ratio" => 1.8,
    "minimum_beta" => 0.002,
    "maximum_axisymmetric_beta_n" => 3.5,
    "minimum_fusion_gain" => 5.0,
    "minimum_net_electric_power_w" => 0.0,
    "maximum_neutron_wall_load_w_m2" => 5.0e6,
    "maximum_exhaust_heat_flux_w_m2" => 10.0e6,
    "maximum_peak_conductor_field_t" => 16.0,
    "maximum_support_stress_pa" => 650.0e6,
    "maximum_plasma_current_ma" => 25.0,
)

function _v98_capability_profile(topology_raw)
    topology = Dict{String,Any}(_v93_plain(topology_raw))
    nodes = Dict{String,Any}.(topology["nodes"])
    active = [node for node in nodes if String(node["role"]) in V91_NODE_ROLES]
    semantics = String[String(node["field_semantics"]) for node in active]
    boundaries = String[String(node["boundary"]) for node in active]
    operators = String[String(node["operator"]) for node in active]
    dimensions = Int[_v97_dimension(node["dimension"]) for node in active]
    plasma_nodes = [node for node in active if String(node["role"]) in
        ("plasma_inventory", "energy_exchange", "particle_transport")]
    closed_plasma = [node for node in plasma_nodes if String(node["field_semantics"]) in
        ("axisymmetric_closed", "three_dimensional_closed")]
    count_active = max(length(active), 1)
    open_fraction = count(value -> value in ("open_guiding_field", "hybrid_field"),
        semantics) / count_active
    three_d_fraction = count(==("three_dimensional_closed"), semantics) / count_active
    axisymmetric_fraction = count(==("axisymmetric_closed"), semantics) / count_active
    hybrid_fraction = count(==("hybrid_field"), semantics) / count_active
    spatial_fraction = count(>=(2), dimensions) / count_active
    field_operator_fraction = count(==("field_balance"), operators) / count_active
    closed_core_route = three_d_fraction > axisymmetric_fraction ?
        "three_dimensional_closed" : "axisymmetric_closed"
    route = if !isempty(closed_plasma) && open_fraction > 0
        "closed_core_open_exhaust"
    elseif hybrid_fraction > 0 || (open_fraction > 0 &&
            axisymmetric_fraction + three_d_fraction > 0)
        "mixed_open_closed"
    elseif open_fraction > 0
        "open_field"
    elseif three_d_fraction > axisymmetric_fraction
        "three_dimensional_closed"
    else
        "axisymmetric_closed"
    end
    field_quality = clamp(0.50 + 0.16spatial_fraction + 0.18field_operator_fraction +
        0.08axisymmetric_fraction + 0.04three_d_fraction - 0.12hybrid_fraction,
        0.35, 0.95)
    body = Dict{String,Any}(
        "route" => route,
        "closed_core_route" => closed_core_route,
        "closed_plasma_region_count" => length(closed_plasma),
        "declared_field_semantics" => sort!(unique(semantics)),
        "declared_boundaries" => sort!(unique(boundaries)),
        "declared_operators" => sort!(unique(operators)),
        "declared_dimensions" => sort!(unique(dimensions)),
        "open_fraction" => open_fraction,
        "three_dimensional_fraction" => three_d_fraction,
        "axisymmetric_fraction" => axisymmetric_fraction,
        "hybrid_fraction" => hybrid_fraction,
        "spatial_fraction" => spatial_fraction,
        "field_operator_fraction" => field_operator_fraction,
        "field_quality_parameter" => field_quality,
        "routing_axes" => ["field_semantics", "boundary", "operator", "dimension"],
        "identity_fields_used" => false,
    )
    body["capability_hash"] = canonical_hash(body)
    body
end

function _v98_reference_capability_profile(anchor_raw)
    anchor = Dict{String,Any}(_v93_plain(anchor_raw))
    capabilities = Set(String(item["capability_id"])
        for item in Dict{String,Any}.(anchor["capabilities"]))
    open = "open_field_kinetic_transport" in capabilities
    route = open ? "open_field" : "axisymmetric_closed"
    body = Dict{String,Any}(
        "route" => route,
        "declared_capabilities" => sort!(collect(capabilities)),
        "declared_field_semantics" => [open ? "open_guiding_field" :
            "axisymmetric_closed"],
        "declared_boundaries" => [open ? "open" : "closed"],
        "declared_operators" => sort!(unique(String(binding["operator_id"])
            for binding in Dict{String,Any}.(anchor["module_bindings"]))),
        "declared_dimensions" => [0, 1, 2],
        "open_fraction" => open ? 1.0 : 0.0,
        "three_dimensional_fraction" => 0.0,
        "axisymmetric_fraction" => open ? 0.0 : 1.0,
        "hybrid_fraction" => 0.0,
        "spatial_fraction" => 1.0,
        "field_operator_fraction" => 1.0,
        "field_quality_parameter" => open ? 0.70 : 0.85,
        "routing_axes" => ["declared_capability", "operator", "boundary"],
        "identity_fields_used" => false,
    )
    body["capability_hash"] = canonical_hash(body)
    body
end

function _v98_halton(index::Integer, base::Integer)
    value = Int(index); factor = 1.0; result = 0.0
    while value > 0
        factor /= base
        result += factor * mod(value, base)
        value = fld(value, base)
    end
    result
end

function _v98_operating_point_from_generated(physics_raw, index::Integer)
    physics = Dict{String,Any}(_v93_plain(physics_raw))
    major = 3.0 + 7.0_v98_halton(index, 2)
    aspect = 2.0 + 4.0_v98_halton(index, 3)
    minor = major / aspect
    elongation = 0.9 + 1.3_v98_halton(index, 5)
    density = 10.0^(19.0 + 1.3_v98_halton(index, 7))
    temperature_kev = 5.0 + 25.0_v98_halton(index, 11)
    field = 2.0 + 10.0_v98_halton(index, 13)
    field_periods = 1 + floor(Int, 8.0_v98_halton(index, 17))
    Dict{String,Any}(
        "major_radius_m" => major,
        "minor_radius_m" => minor,
        "elongation" => elongation,
        "triangularity" => -0.4 + 0.8_v98_halton(index, 19),
        "field_periods" => field_periods,
        "magnetic_field_t" => field,
        "density_m3" => density,
        "temperature_kev" => temperature_kev,
        "wall_minor_radius_m" => 1.35minor,
        "coil_minor_radius_m" => 1.80minor,
        "open_branch_length_m" => 2major * (1.0 + 2.0_v98_halton(index, 23)),
        "fuel" => "D-T",
        "input_origin" => "candidate_bound_halton_low_discrepancy_physical_design_v98",
        "design_sequence" => "halton_bases_2_3_5_7_11_13_17_19_23",
        "historical_v91_basis_consumed" => false,
        "basis_direct_metric_credit" => false,
    )
end

function _v98_operating_point_from_reference(anchor_raw)
    anchor = Dict{String,Any}(_v93_plain(anchor_raw))
    p = Dict{String,Any}(anchor["parameters"])
    initial = Dict{String,Any}(anchor["initial_conditions"])
    volume = Float64(p["volume_m3"])
    particles = Float64(initial["particle_inventory"])
    thermal = Float64(initial["thermal_energy"])
    density = particles / volume
    temperature_kev = thermal / max(3particles, eps()) /
        (1.0e3 * 1.602176634e-19)
    minor = Float64(p["minor_radius_m"])
    major = Float64(get(p, "major_radius_m", max(Float64(p["characteristic_length_m"]),
        2.5minor)))
    Dict{String,Any}(
        "major_radius_m" => major,
        "minor_radius_m" => minor,
        "elongation" => 1.0,
        "triangularity" => 0.0,
        "field_periods" => 1,
        "magnetic_field_t" => Float64(p["magnetic_field_t"]),
        "density_m3" => density,
        "temperature_kev" => temperature_kev,
        "wall_minor_radius_m" => 1.45minor,
        "coil_minor_radius_m" => 1.85minor,
        "open_branch_length_m" => Float64(p["characteristic_length_m"]),
        "volume_override_m3" => volume,
        "plasma_current_a" => Float64(get(initial, "plasma_current", 0.0)),
        "pulse_duration_s" => Float64(p["pulse_duration_s"]),
        "fuel" => String(p["fuel"]),
        "input_origin" => "published_reference_state_and_geometry",
        "basis_direct_metric_credit" => false,
    )
end

function _v98_geometry(point, capability)
    major = Float64(point["major_radius_m"]); minor = Float64(point["minor_radius_m"])
    elongation = Float64(point["elongation"]); route = String(capability["route"])
    toroidal = route != "open_field"
    volume = haskey(point, "volume_override_m3") ? Float64(point["volume_override_m3"]) :
        toroidal ? 2pi^2 * major * minor^2 * elongation :
        pi * minor^2 * Float64(point["open_branch_length_m"])
    area = toroidal ? 4pi^2 * major * minor * sqrt(max(elongation, 0.2)) :
        2pi * minor * Float64(point["open_branch_length_m"]) + 2pi * minor^2
    Dict{String,Any}(
        "volume_m3" => volume, "first_wall_area_m2" => area,
        "aspect_ratio" => major / max(minor, eps()),
        "plasma_to_wall_clearance_m" => Float64(point["wall_minor_radius_m"]) - minor,
        "wall_to_coil_clearance_m" => Float64(point["coil_minor_radius_m"]) -
            Float64(point["wall_minor_radius_m"]),
        "geometry_model" => toroidal ? "elliptic_toroidal_control_volume_v98" :
            "finite_cylindrical_open_control_volume_v98",
    )
end

function _v98_confinement_coefficients(point, capability, geometry)
    route = String(capability["route"]); density = Float64(point["density_m3"])
    field = Float64(point["magnetic_field_t"]); major = Float64(point["major_radius_m"])
    minor = Float64(point["minor_radius_m"]); elongation = Float64(point["elongation"])
    quality = Float64(capability["field_quality_parameter"])
    q95 = 2.5 + 0.35Int(point["field_periods"]) +
        0.30Float64(capability["field_operator_fraction"])
    shape = (1 + elongation^2) / 2
    current_ma = haskey(point, "plasma_current_a") && point["plasma_current_a"] > 0 ?
        Float64(point["plasma_current_a"]) / 1.0e6 :
        5minor^2 * field * shape / max(major * q95, 1e-9)
    n19 = max(density / 1e19, 0.01); epsilon = minor / max(major, 1e-9)
    effective_closed_route = route == "closed_core_open_exhaust" ?
        String(capability["closed_core_route"]) : route
    exhaust_penalty = route == "closed_core_open_exhaust" ?
        clamp(1.0 - 0.50Float64(capability["open_fraction"]), 0.55, 0.95) : 1.0
    if effective_closed_route == "axisymmetric_closed"
        coefficient = 0.0562 * max(current_ma, 0.05)^0.93 * field^0.15 *
            n19^0.41 * major^1.97 * epsilon^0.58 * max(elongation, 0.2)^0.78 *
            2.5^0.19 * quality * exhaust_penalty
        return Dict("model" => "IPB98y2_capability_scoped_v98", "coefficient" =>
            coefficient, "power_exponent" => 0.69, "q95" => q95,
            "plasma_current_ma" => current_ma)
    elseif effective_closed_route == "three_dimensional_closed"
        iota = 1 / q95
        coefficient = 0.134 * quality * minor^2.28 * major^0.64 * n19^0.54 *
            field^0.84 * iota^0.41 * exhaust_penalty
        return Dict("model" => "ISS04_capability_scoped_v98", "coefficient" =>
            coefficient, "power_exponent" => 0.61, "q95" => q95,
            "plasma_current_ma" => current_ma)
    end
    ion_mass = 2.5 * 1.66053906660e-27
    temperature_j = Float64(point["temperature_kev"]) * 1e3 * 1.602176634e-19
    thermal_speed = sqrt(2temperature_j / ion_mass)
    transit = Float64(point["open_branch_length_m"]) / max(thermal_speed, eps())
    trapping_multiplier = 1 + 8quality * Int(point["field_periods"])
    open_tau = transit * trapping_multiplier
    if route == "mixed_open_closed"
        closed_coefficient = 0.134 * quality * minor^2.28 * major^0.64 * n19^0.54 *
            field^0.84 * (1 / q95)^0.41
        closed_tau_at_one_mw = closed_coefficient
        open_fraction = Float64(capability["open_fraction"])
        mixed_tau = 1 / (open_fraction / max(open_tau, eps()) +
            (1 - open_fraction) / max(closed_tau_at_one_mw, eps()))
        return Dict("model" => "harmonic_open_closed_loss_bound_v98",
            "coefficient" => mixed_tau, "power_exponent" => 0.0,
            "q95" => q95, "plasma_current_ma" => current_ma)
    end
    Dict("model" => "untrapped_parallel_transit_loss_bound_v98",
        "coefficient" => open_tau, "power_exponent" => 0.0,
        "q95" => q95, "plasma_current_ma" => current_ma)
end

function _v98_loss_power_bisection(stored_energy_j, coefficient, exponent)
    coefficient > 0 || return (power_w = nothing, tau_s = nothing, converged = false,
        iterations = 0)
    exponent == 0 && return (power_w = stored_energy_j / coefficient,
        tau_s = coefficient, converged = true, iterations = 0)
    residual(power_mw) = power_mw - stored_energy_j / 1e6 /
        (coefficient * power_mw^(-exponent))
    analytic_mw = (stored_energy_j / 1e6 / coefficient)^(1 / (1 - exponent))
    isfinite(analytic_mw) && analytic_mw > 0 || return (power_w = nothing,
        tau_s = nothing, converged = false, iterations = 0)
    low, high = max(analytic_mw * 1e-6, 1e-18), analytic_mw * 1e6
    residual(low) <= 0 && residual(high) >= 0 || return (power_w = nothing,
        tau_s = nothing, converged = false, iterations = 0)
    iterations = 0
    for iteration in 1:100
        iterations = iteration; mid = sqrt(low * high)
        residual(mid) > 0 ? (high = mid) : (low = mid)
    end
    power_mw = sqrt(low * high)
    (power_w = power_mw * 1e6, tau_s = coefficient * power_mw^(-exponent),
        converged = true, iterations = iterations)
end

function _v98_gate(id, value, passed; threshold = nothing, units = "1")
    Dict{String,Any}("gate_id" => String(id), "status" => passed ? "pass" : "fail",
        "value" => value, "threshold" => threshold, "units" => String(units))
end

function solve_candidate_physics_v98(point_raw, capability_raw)
    point = Dict{String,Any}(_v93_plain(point_raw))
    capability = Dict{String,Any}(_v93_plain(capability_raw))
    geometry = _v98_geometry(point, capability)
    mu0 = 4pi * 1e-7; e = 1.602176634e-19
    field = Float64(point["magnetic_field_t"]); density = Float64(point["density_m3"])
    temperature_kev = Float64(point["temperature_kev"])
    temperature_j = temperature_kev * 1e3 * e
    pressure = 2density * temperature_j
    beta = 2mu0 * pressure / max(field^2, eps())
    volume = Float64(geometry["volume_m3"]); area = Float64(geometry["first_wall_area_m2"])
    stored_energy = 1.5pressure * volume
    confinement = _v98_confinement_coefficients(point, capability, geometry)
    loss = _v98_loss_power_bisection(stored_energy, Float64(confinement["coefficient"]),
        Float64(confinement["power_exponent"]))
    fuel = uppercase(replace(String(point["fuel"]), " " => ""))
    dt_applicable = fuel in ("D-T", "DT")
    reactivity = dt_applicable ? bosch_hale_maxwellian_reactivity_v1(
        "dt_to_alpha_neutron", temperature_kev) : NaN
    fusion_power = dt_applicable && isfinite(reactivity) ?
        0.25density^2 * reactivity * 17.6e6 * e * volume : nothing
    bremsstrahlung = 1.69e-38 * density^2 * sqrt(max(temperature_kev * 1e3, 0.0)) * volume
    alpha_power = fusion_power === nothing ? 0.0 : 0.20fusion_power
    loss_available = loss.power_w !== nothing && isfinite(loss.power_w)
    required_auxiliary = loss_available ?
        max(loss.power_w + bremsstrahlung - alpha_power, 0.0) : nothing
    self_heated = fusion_power !== nothing && required_auxiliary !== nothing &&
        required_auxiliary <= 1.0
    fusion_gain = fusion_power === nothing || required_auxiliary === nothing || self_heated ?
        nothing : fusion_power / required_auxiliary
    net_electric = fusion_power === nothing || required_auxiliary === nothing ? nothing :
        0.40fusion_power - required_auxiliary / 0.50 - 15.0e6
    neutron_wall_load = fusion_power === nothing ? nothing : 0.80fusion_power / max(area, eps())
    exhaust_heat_flux = loss_available ? loss.power_w / max(0.15area, eps()) : nothing
    minor = Float64(point["minor_radius_m"]); major = Float64(point["major_radius_m"])
    coil_thickness = max(Float64(point["coil_minor_radius_m"]) -
        Float64(point["wall_minor_radius_m"]), 0.05)
    peak_field = field * (1 + minor / max(major - minor, 0.2minor)) *
        (1 + 0.12Float64(capability["three_dimensional_fraction"]))
    support_stress = peak_field^2 / (2mu0) * min(minor / coil_thickness, 4.0)
    route = String(capability["route"])
    beta_n = 100beta * minor * field / max(Float64(confinement["plasma_current_ma"]), 0.05)
    stability_route = route == "closed_core_open_exhaust" ?
        String(capability["closed_core_route"]) : route
    stability_cap = stability_route == "axisymmetric_closed" ? nothing :
        stability_route == "three_dimensional_closed" ? 0.05Float64(capability["field_quality_parameter"]) :
        route == "open_field" ? 0.30Float64(capability["field_quality_parameter"]) :
        0.08Float64(capability["field_quality_parameter"])
    stability_pass = stability_route == "axisymmetric_closed" ?
        beta_n <= V98_SCREEN_THRESHOLDS["maximum_axisymmetric_beta_n"] :
        beta <= stability_cap
    gates = Dict{String,Any}[
        _v98_gate("temperature_fit_domain", temperature_kev,
            V98_SCREEN_THRESHOLDS["minimum_temperature_kev"] <= temperature_kev <=
                V98_SCREEN_THRESHOLDS["maximum_temperature_kev"];
            threshold = [V98_SCREEN_THRESHOLDS["minimum_temperature_kev"],
                V98_SCREEN_THRESHOLDS["maximum_temperature_kev"]], units = "keV"),
        _v98_gate("geometry_aspect_ratio", geometry["aspect_ratio"],
            geometry["aspect_ratio"] >= V98_SCREEN_THRESHOLDS["minimum_aspect_ratio"];
            threshold = V98_SCREEN_THRESHOLDS["minimum_aspect_ratio"]),
        _v98_gate("radial_build", min(geometry["plasma_to_wall_clearance_m"],
            geometry["wall_to_coil_clearance_m"]),
            geometry["plasma_to_wall_clearance_m"] > 0 &&
                geometry["wall_to_coil_clearance_m"] > 0; threshold = 0.0, units = "m"),
        _v98_gate("minimum_beta", beta,
            beta >= V98_SCREEN_THRESHOLDS["minimum_beta"];
            threshold = V98_SCREEN_THRESHOLDS["minimum_beta"]),
        _v98_gate("capability_scoped_stability", stability_route == "axisymmetric_closed" ?
            beta_n : beta, stability_pass; threshold = stability_route == "axisymmetric_closed" ?
                V98_SCREEN_THRESHOLDS["maximum_axisymmetric_beta_n"] : stability_cap),
        _v98_gate("confinement_power_balance", loss.power_w, loss.converged &&
            loss_available; threshold = "finite_converged", units = "W"),
        _v98_gate("fusion_gain", fusion_gain,
            self_heated || (fusion_gain !== nothing && fusion_gain >=
                V98_SCREEN_THRESHOLDS["minimum_fusion_gain"]);
            threshold = V98_SCREEN_THRESHOLDS["minimum_fusion_gain"]),
        _v98_gate("net_electric_power", net_electric,
            net_electric !== nothing && net_electric >=
                V98_SCREEN_THRESHOLDS["minimum_net_electric_power_w"];
            threshold = V98_SCREEN_THRESHOLDS["minimum_net_electric_power_w"], units = "W"),
        _v98_gate("neutron_wall_load", neutron_wall_load,
            neutron_wall_load !== nothing && neutron_wall_load <=
                V98_SCREEN_THRESHOLDS["maximum_neutron_wall_load_w_m2"];
            threshold = V98_SCREEN_THRESHOLDS["maximum_neutron_wall_load_w_m2"], units = "W/m^2"),
        _v98_gate("exhaust_heat_flux", exhaust_heat_flux,
            exhaust_heat_flux !== nothing && exhaust_heat_flux <=
                V98_SCREEN_THRESHOLDS["maximum_exhaust_heat_flux_w_m2"];
            threshold = V98_SCREEN_THRESHOLDS["maximum_exhaust_heat_flux_w_m2"], units = "W/m^2"),
        _v98_gate("peak_conductor_field", peak_field,
            peak_field <= V98_SCREEN_THRESHOLDS["maximum_peak_conductor_field_t"];
            threshold = V98_SCREEN_THRESHOLDS["maximum_peak_conductor_field_t"], units = "T"),
        _v98_gate("support_stress", support_stress,
            support_stress <= V98_SCREEN_THRESHOLDS["maximum_support_stress_pa"];
            threshold = V98_SCREEN_THRESHOLDS["maximum_support_stress_pa"], units = "Pa"),
        _v98_gate("plasma_current", confinement["plasma_current_ma"],
            Float64(confinement["plasma_current_ma"]) <=
                V98_SCREEN_THRESHOLDS["maximum_plasma_current_ma"];
            threshold = V98_SCREEN_THRESHOLDS["maximum_plasma_current_ma"], units = "MA"),
    ]
    status = all(gate -> gate["status"] == "pass", gates) ? "pass" : "fail"
    metrics = Dict{String,Any}(
        "pressure_pa" => pressure, "beta" => beta, "beta_n" => beta_n,
        "reactivity_m3_s" => isfinite(reactivity) ? reactivity : nothing,
        "fusion_power_w" => fusion_power, "bremsstrahlung_power_w" => bremsstrahlung,
        "stored_energy_j" => stored_energy, "energy_confinement_time_s" => loss.tau_s,
        "transport_loss_power_w" => loss.power_w,
        "required_auxiliary_power_w" => required_auxiliary,
        "fusion_gain" => fusion_gain, "self_heated_power_balance" => self_heated,
        "net_electric_power_w" => net_electric,
        "neutron_wall_load_w_m2" => neutron_wall_load,
        "exhaust_heat_flux_w_m2" => exhaust_heat_flux,
        "peak_conductor_field_t" => peak_field, "support_stress_pa" => support_stress,
    )
    body = Dict{String,Any}(
        "status" => status, "capability_route" => route, "geometry" => geometry,
        "confinement_model" => confinement, "metrics" => metrics, "gates" => gates,
        "failed_gates" => String[gate["gate_id"] for gate in gates if gate["status"] == "fail"],
        "loss_root_iterations" => loss.iterations,
        "basis_direct_metric_credit" => false,
        "evidence_ceiling" => "candidate_bound_reduced_empirical_physics_and_engineering_screen",
        "claim_boundary" => END_TO_END_DEVICE_PIPELINE_V98_CLAIM_BOUNDARY,
    )
    body["solve_hash"] = canonical_hash(body)
    body
end

function numerical_vvuq_candidate_v98(point_raw, capability_raw, nominal_raw)
    point = Dict{String,Any}(_v93_plain(point_raw))
    capability = Dict{String,Any}(_v93_plain(capability_raw))
    nominal = Dict{String,Any}(_v93_plain(nominal_raw))
    confinement = Dict{String,Any}(nominal["confinement_model"])
    metrics = Dict{String,Any}(nominal["metrics"])
    coefficient = Float64(confinement["coefficient"])
    exponent = Float64(confinement["power_exponent"])
    stored = Float64(metrics["stored_energy_j"])
    analytic_power = exponent == 0 ? stored / coefficient :
        (stored / 1e6 / coefficient)^(1 / (1 - exponent)) * 1e6
    primary_power = Float64(metrics["transport_loss_power_w"])
    relative_difference = abs(primary_power - analytic_power) /
        max(abs(analytic_power), 1.0)
    replay = solve_candidate_physics_v98(point, capability)
    replay_match = replay["solve_hash"] == nominal["solve_hash"]
    perturbations = Dict{String,Any}[]
    for density_factor in (0.95, 1.05), temperature_factor in (0.95, 1.05),
            field_factor in (0.95, 1.05)
        perturbed = deepcopy(point)
        perturbed["density_m3"] = Float64(point["density_m3"]) * density_factor
        perturbed["temperature_kev"] = Float64(point["temperature_kev"]) * temperature_factor
        perturbed["magnetic_field_t"] = Float64(point["magnetic_field_t"]) * field_factor
        result = solve_candidate_physics_v98(perturbed, capability)
        push!(perturbations, Dict{String,Any}(
            "density_factor" => density_factor, "temperature_factor" => temperature_factor,
            "field_factor" => field_factor, "status" => result["status"],
            "solve_hash" => result["solve_hash"], "failed_gates" => result["failed_gates"],
            "fusion_gain" => result["metrics"]["fusion_gain"],
            "net_electric_power_w" => result["metrics"]["net_electric_power_w"],
        ))
    end
    numerical_pass = isfinite(relative_difference) && relative_difference <= 1e-10 && replay_match
    robust_pass = all(item -> item["status"] == "pass", perturbations)
    body = Dict{String,Any}(
        "status" => numerical_pass ? "pass" : "fail",
        "deterministic_replay_match" => replay_match,
        "primary_root_method" => "log_bisection_v98",
        "independent_root_method" => "closed_form_power_law_v98",
        "independent_loss_power_w" => analytic_power,
        "loss_power_relative_difference" => relative_difference,
        "parametric_uq" => Dict("status" => robust_pass ? "pass" : "fail",
            "sample_count" => length(perturbations), "samples" => perturbations,
            "uncertainty_model" => "full_factorial_density_temperature_field_plus_minus_5_percent"),
        "robust_physics_pass" => robust_pass,
        "experimental_validation_credit" => false,
        "claim_boundary" => END_TO_END_DEVICE_PIPELINE_V98_CLAIM_BOUNDARY,
    )
    body["vvuq_hash"] = canonical_hash(body)
    body
end

function evaluate_indexed_device_v98(index::Integer;
        registry = default_physical_provider_registry_v97(), validation_evidence = nothing)
    physics = reconstruct_indexed_physics_v97(index)
    topology = generate_family_neutral_topology_v91(index)
    blockers = String.(physics["declaration_blockers"])
    if !isempty(blockers)
        body = Dict{String,Any}(
            "request_index" => Int(index), "candidate_state" => "topology_screen_fail",
            "topology_screen" => Dict("status" => "fail", "reasons" => blockers),
            "provider_closure" => Dict("status" => "not_executed"),
            "physics_solve" => Dict("status" => "not_executed"),
            "numerical_vvuq" => Dict("status" => "not_executed"),
            "validation_vvuq" => Dict("status" => "not_executed"),
            "unsupported_candidate_classification_used" => false,
            "claim_boundary" => END_TO_END_DEVICE_PIPELINE_V98_CLAIM_BOUNDARY)
        body["result_hash"] = canonical_hash(body); return body
    end
    closure = compile_indexed_closure_v97(index; registry)
    if closure.row["screen_status"] != "closed"
        body = Dict{String,Any}(
            "request_index" => Int(index), "candidate_state" => "provider_system_fail",
            "topology_screen" => Dict("status" => "pass"),
            "provider_closure" => Dict("status" => "fail", "blockers" =>
                closure.row["blockers"], "route_histogram" => closure.row["route_histogram"]),
            "physics_solve" => Dict("status" => "not_executed"),
            "numerical_vvuq" => Dict("status" => "not_executed"),
            "validation_vvuq" => Dict("status" => "not_executed"),
            "candidate_rejection_credit" => false,
            "unsupported_candidate_classification_used" => false,
            "claim_boundary" => END_TO_END_DEVICE_PIPELINE_V98_CLAIM_BOUNDARY)
        body["result_hash"] = canonical_hash(body); return body
    end
    capability = _v98_capability_profile(topology)
    point = _v98_operating_point_from_generated(physics, index)
    solve = solve_candidate_physics_v98(point, capability)
    numerical = solve["status"] == "pass" ?
        numerical_vvuq_candidate_v98(point, capability, solve) :
        Dict{String,Any}("status" => "not_executed", "reason" => "physical_screen_failed")
    validation = solve["status"] == "pass" && numerical["status"] == "pass" &&
        get(numerical, "robust_physics_pass", false) ?
        audit_validation_vvuq_v94(validation_evidence) :
        Dict{String,Any}("status" => "not_executed", "reason" =>
            "upstream_physics_or_numerical_vvuq_not_passed")
    state = solve["status"] != "pass" ? "physics_screen_fail" :
        numerical["status"] != "pass" || !get(numerical, "robust_physics_pass", false) ?
            "numerical_vvuq_fail" : validation["status"] == "pass" ?
                "validation_pass" : "computational_candidate"
    body = Dict{String,Any}(
        "request_index" => Int(index), "candidate_state" => state,
        "topology_hash" => closure.row["topology_hash"],
        "graph_hash" => closure.row["graph_hash"],
        "solver_input_hash" => closure.row["solver_input_hash"],
        "topology_screen" => Dict("status" => "pass"),
        "provider_closure" => Dict("status" => "pass", "route_histogram" =>
            closure.row["route_histogram"]),
        "capability_profile" => capability, "operating_point" => point,
        "physics_solve" => solve, "numerical_vvuq" => numerical,
        "validation_vvuq" => validation,
        "stage_order" => ["topology_screen", "provider_closure", "physics_solve",
            "numerical_vvuq", "validation_vvuq"],
        "basis_direct_metric_credit" => false,
        "unsupported_candidate_classification_used" => false,
        "experimental_validation_independent" => true,
        "claim_boundary" => END_TO_END_DEVICE_PIPELINE_V98_CLAIM_BOUNDARY,
    )
    body["result_hash"] = canonical_hash(body)
    body
end

function _v98_intervals_overlap(low_a, high_a, low_b, high_b)
    max(Float64(low_a), Float64(low_b)) <= min(Float64(high_a), Float64(high_b))
end

function run_v98_reference_acceptance(project_root::AbstractString)
    anchors = load_candidate_solver_reference_anchors_v1(joinpath(project_root, "fixtures",
        "candidate_solver_reference_anchors_v1.json"))
    rows = Dict{String,Any}[]
    for anchor_raw in anchors
        anchor = Dict{String,Any}(_v93_plain(anchor_raw))
        capability = _v98_reference_capability_profile(anchor)
        point = _v98_operating_point_from_reference(anchor)
        solve = solve_candidate_physics_v98(point, capability)
        numerical = numerical_vvuq_candidate_v98(point, capability, solve)
        observables = Dict(String(item["observable_id"]) => Dict{String,Any}(item)
            for item in Dict{String,Any}.(anchor["anchor_observables"]))
        checks = Dict{String,Any}[]
        if haskey(observables, "fusion_power_w")
            target = observables["fusion_power_w"]
            predicted = solve["metrics"]["fusion_power_w"]
            uncertainty = predicted === nothing ? (low = Inf, high = -Inf) :
                (low = 0.85Float64(predicted), high = 1.15Float64(predicted))
            push!(checks, Dict("check" => "fusion_power_model_interval_overlap",
                "status" => predicted !== nothing && _v98_intervals_overlap(uncertainty.low,
                    uncertainty.high, target["minimum"], target["maximum"]) ? "pass" : "fail",
                "prediction_w" => predicted, "model_interval_w" =>
                    [uncertainty.low, uncertainty.high], "reference_interval_w" =>
                    [target["minimum"], target["maximum"]],
                "validation_credit" => false))
        end
        if haskey(observables, "effective_temperature_ev")
            target = observables["effective_temperature_ev"]
            derived = Float64(point["temperature_kev"]) * 1e3
            push!(checks, Dict("check" => "state_derived_temperature_interval",
                "status" => target["minimum"] <= derived <= target["maximum"] ?
                    "pass" : "fail", "derived_temperature_ev" => derived,
                "reference_interval_ev" => [target["minimum"], target["maximum"]],
                "validation_credit" => false))
        end
        if haskey(observables, "pulse_duration_s")
            target = observables["pulse_duration_s"]
            duration = Float64(point["pulse_duration_s"])
            push!(checks, Dict("check" => "declared_pulse_duration_binding",
                "status" => target["minimum"] <= duration <= target["maximum"] ?
                    "pass" : "fail", "declared_duration_s" => duration,
                "reference_interval_s" => [target["minimum"], target["maximum"]],
                "validation_credit" => false))
        end
        reference_pass = numerical["status"] == "pass" &&
            all(item -> item["status"] == "pass", checks)
        push!(rows, Dict{String,Any}(
            "anchor_kind" => anchor["anchor_kind"],
            "capability_hash" => capability["capability_hash"],
            "reference_status" => reference_pass ? "pass" : "fail",
            "physics_screen_status" => solve["status"],
            "numerical_vvuq_status" => numerical["status"],
            "checks" => checks, "solve_hash" => solve["solve_hash"],
            "validation_vvuq" => Dict("status" => "unknown_validation_domain",
                "reason" => "reference_values_are_not_an_independent_holdout_for_this_binding"),
            "validation_credit" => false,
            "identity_fields_used_for_routing" => false,
            "claim_boundary" => anchor["claim_boundary"],
        ))
    end
    body = Dict{String,Any}(
        "protocol_id" => V98_PROTOCOL_ID,
        "status" => length(rows) == 2 && all(row -> row["reference_status"] == "pass", rows) ?
            "pass" : "fail",
        "reference_controls" => rows,
        "reference_recall" => Dict("passed" => count(row -> row["reference_status"] ==
            "pass", rows), "total" => length(rows)),
        "experimental_validation_pass_count" => 0,
        "fail_fast_before_campaign" => true,
        "claim_boundary" => END_TO_END_DEVICE_PIPELINE_V98_CLAIM_BOUNDARY,
    )
    body["acceptance_hash"] = canonical_hash(body)
    body
end

function run_v98_screening_campaign(first_index::Integer, last_index::Integer;
        registry = default_physical_provider_registry_v97(), retain_count::Integer = 100)
    1 <= first_index <= last_index <= V97_MAXIMUM_REQUEST_INDEX || throw(ArgumentError(
        "v98 campaign bounds are outside the complete v91 grammar"))
    histogram = Dict(state => 0 for state in sort!(collect(V98_CANDIDATE_STATES)))
    failed_gates = Dict{String,Int}(); route_histogram = Dict{String,Int}()
    retained = Dict{String,Any}[]; stream_hash = bytes2hex(sha256("v98-stream-v1"))
    provider_system_failures = 0
    for index in first_index:last_index
        result = evaluate_indexed_device_v98(index; registry)
        state = String(result["candidate_state"])
        histogram[state] = get(histogram, state, 0) + 1
        provider_system_failures += state == "provider_system_fail"
        if haskey(result, "capability_profile")
            route = String(result["capability_profile"]["route"])
            route_histogram[route] = get(route_histogram, route, 0) + 1
        end
        if haskey(result, "physics_solve")
            for gate in String.(get(result["physics_solve"], "failed_gates", String[]))
                failed_gates[gate] = get(failed_gates, gate, 0) + 1
            end
        end
        if state in ("computational_candidate", "validation_pass")
            push!(retained, result)
            sort!(retained; by = item -> -Float64(item["physics_solve"]["metrics"][
                "net_electric_power_w"]))
            length(retained) > retain_count && resize!(retained, retain_count)
        end
        stream_hash = canonical_hash(Dict("previous" => stream_hash,
            "result_hash" => result["result_hash"]))
    end
    body = Dict{String,Any}(
        "protocol_id" => V98_PROTOCOL_ID, "first_index" => Int(first_index),
        "last_index" => Int(last_index), "request_count" => Int(last_index-first_index+1),
        "status" => provider_system_failures == 0 ? "complete" : "system_fail",
        "candidate_state_histogram" => histogram,
        "provider_system_failure_count" => provider_system_failures,
        "failed_gate_histogram" => failed_gates,
        "capability_route_histogram" => route_histogram,
        "retained_computational_candidates" => retained,
        "retained_count" => length(retained),
        "validation_pass_count" => histogram["validation_pass"],
        "unsupported_candidate_count" => 0,
        "result_stream_hash" => stream_hash,
        "claim_boundary" => END_TO_END_DEVICE_PIPELINE_V98_CLAIM_BOUNDARY,
    )
    body["campaign_hash"] = canonical_hash(body)
    body
end
