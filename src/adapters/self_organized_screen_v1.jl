const _SELF_ORGANIZED_V7_SOURCE_BASIS = [
    "rfp_ppcd_sarff_1997", "rfp_sha_lorenzini_2008",
    "rfp_helical_lorenzini_2009", "rfp_tperx_sago_1999",
    "rfp_active_control_luchetta_2009", "dipole_ldx_design_garnier_2006",
    "dipole_inward_pinch_boxer_2010",
]

const _SELF_ORGANIZED_SCREEN_CLAIM_BOUNDARY =
    "Fidelity-0 rejection screen for RFP and levitated-dipole prototypes inside the sealed " *
    "v5 outer-envelope contracts. RFP confinement is a lower-anchor extrapolation from TPE-RX " *
    "and MST experiments, with QSH and boundary feedback represented as explicit domain gates; " *
    "dipole confinement is a conservative Bohm transport proxy and its inward pinch changes " *
    "particle loss only. No result establishes a self-consistent equilibrium, all-mode resistive " *
    "MHD stability, reactor-scale transport, divertor operation, internal-coil neutronics, tritium " *
    "breeding, maintenance, net electricity, or superiority over another family."

struct SelfOrganizedScreenV1 <: AbstractEvaluator
    contract::SharedOuterEnvelopeContractV1
    allowed_contract_hashes::Set{String}
end

function SelfOrganizedScreenV1(contract::SharedOuterEnvelopeContractV1;
        allowed_contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    SelfOrganizedScreenV1(contract,
        Set(canonical_hash(_oe_contract_dict(item)) for item in allowed_contracts))
end

function evaluator_spec(::SelfOrganizedScreenV1)
    EvaluatorSpec("self_organized_screen_v1", "1.0.0",
        ["reversed_field_pinch", "levitated_dipole"], 0,
        Dict("resistive_mhd_rfp" => :proxy,
            "rfp_mode_spectrum" => :proxy,
            "rfp_current_profile_and_sustainment" => :proxy,
            "finite_beta_dipole_equilibrium" => :proxy,
            "dipole_adiabatic_profile_stability" => :proxy,
            "dipole_turbulent_transport" => :proxy,
            "separatrix_field_line_mapping" => :proxy,
            "sol_transport" => :proxy, "target_heat_flux" => :proxy,
            "impurity_and_helium_ash_exhaust" => :proxy,
            "finite_build_coils" => :proxy, "coil_stress" => :proxy,
            "shielding" => :proxy, "maintenance_access" => :proxy,
            "neutronics" => :proxy, "actuator_power" => :proxy),
        _SELF_ORGANIZED_SCREEN_CLAIM_BOUNDARY)
end

function evaluator_applicability(evaluator::SelfOrganizedScreenV1,
        genome::Genome)
    genome.family in evaluator_spec(evaluator).families || return false,
        "self-organized v1 covers only RFP and levitated dipole"
    genome.mission.fuel == "D-T" || return false,
        "self-organized v1 is restricted to the common D-T mission"
    family = validate_family(default_family_registry(), genome)
    family.valid || return false, join(family.errors, "; ")
    true, "same outer-envelope contract $(evaluator.contract.id)"
end

_so_target(g::Genome, name::String, default::Real, unit::String) =
    _oe_target(g, name, default, unit)
_so_fraction(g::Genome, name::String, default::Real) =
    clamp(_so_target(g, name, default, "1"), 0.0, 1.0)
_so_has_kind(items, fragment::String) =
    any(item -> occursin(lowercase(fragment), lowercase(item.kind)), items)

function _so_features(g::Genome)
    rfp = g.family == "reversed_field_pinch"
    feedback = _so_has_kind(g.field_sources, "boundary_mode_control") &&
        _so_has_kind(g.actuators, "magnetic_feedback")
    ppcd_present = _so_has_kind(g.actuators,
        "pulsed_poloidal_current_drive")
    (
        family = g.family,
        aspect_ratio = _so_target(g, "screen_aspect_ratio", rfp ? 3.5 : 3.0, "1"),
        plasma_fill_fraction = _so_fraction(g, "screen_plasma_fill_fraction", 0.65),
        beta = _so_fraction(g, "screen_beta", rfp ? 0.12 : 0.45),
        temperature_keV = _so_target(g, "screen_temperature",
            15.0 * 1.602176634e-16, "J") / 1.602176634e-16,
        field_quality = _so_fraction(g, "screen_field_quality", 0.92),
        plasma_current_MA = _so_target(g, "plasma_current",
            rfp ? 8.0e6 : 0.05e6, "A") / 1.0e6,
        reversal_parameter = _so_target(g, "screen_reversal_parameter", -0.10, "1"),
        pinch_parameter = _so_target(g, "screen_pinch_parameter", 1.65, "1"),
        mode_dominance = _so_target(g, "screen_mode_dominance_ratio", 2.0, "1"),
        current_profile_control = ppcd_present ? _so_fraction(g,
            "screen_current_profile_control", 0.0) : 0.0,
        boundary_feedback_strength = feedback ? _so_fraction(g,
            "screen_boundary_feedback_strength", 0.0) : 0.0,
        ppcd_power_W = ppcd_present ? _so_target(g,
            "screen_ppcd_power", 0.0, "W") : 0.0,
        boundary_control_power_W = feedback ? _so_target(g,
            "screen_boundary_control_power", 0.0, "W") : 0.0,
        dipole_actuator_power_W = !rfp ? _so_target(g,
            "screen_declared_actuator_power", 0.0, "W") : 0.0,
        pulse_duty_fraction = rfp ? _so_fraction(g,
            "screen_pulse_duty_fraction", 0.50) : 1.0,
        inward_pinch_strength = _so_fraction(g,
            "screen_inward_pinch_strength", 0.0),
        levitation_quality = _so_fraction(g,
            "screen_levitation_quality", rfp ? 0.0 : 0.95),
        pressure_profile_exponent = _so_target(g,
            "screen_pressure_profile_exponent", 4.0, "1"),
        internal_coil_radius_fraction = _so_fraction(g,
            "screen_internal_coil_radius_fraction", 0.25),
        internal_coil_field_ratio = _so_target(g,
            "screen_internal_coil_field_ratio", 4.0, "1"),
        internal_shield_thickness_m = _so_target(g,
            "screen_internal_shield_thickness", 1.0, "m"),
        internal_maintenance_gap_m = _so_target(g,
            "screen_internal_maintenance_gap", 0.60, "m"),
        coil_pack_thickness_m = _so_target(g,
            "screen_coil_pack_thickness", 0.50, "m"),
        support_thickness_m = _so_target(g,
            "screen_support_thickness", 0.80, "m"),
        exhaust_area_fraction = _so_fraction(g,
            "screen_exhaust_area_fraction", 0.20),
        exhaust_flux_expansion = _so_target(g,
            "screen_exhaust_flux_expansion", 2.0, "1"),
        target_count = count(r -> r.kind == "divertor_or_exhaust_region",
            g.plasma_regions),
    )
end

function _so_geometry(f, c::SharedOuterEnvelopeContractV1;
        dimension_multiplier::Float64 = 1.0)
    b = c.base.shield_thickness_m + c.base.maintenance_gap_m +
        f.coil_pack_thickness_m + f.support_thickness_m
    A = max(f.aspect_ratio, 1.55)
    kappa = f.family == "reversed_field_pinch" ? 1.0 : 1.35
    capacity = min((c.outer_radial_extent_m - b) / (A + 1.0),
        (c.outer_axial_half_extent_m - b) / kappa)
    a = max(0.01, f.plasma_fill_fraction * dimension_multiplier * capacity)
    R, z = A * a, kappa * a
    (R = R, a = a, z = z, kappa = kappa,
        volume = 2pi^2 * R * a^2 * kappa,
        area = 4pi^2 * R * a * sqrt((1 + kappa^2) / 2),
        radial_margin = c.outer_radial_extent_m - (R + a + b),
        axial_margin = c.outer_axial_half_extent_m - (z + b),
        inboard_margin = R - a - b,
        curvature = max(0.01, min(a, R - a)))
end

function _so_rfp_tau(f, geo, density_m3::Float64)
    column = max(2geo.a * density_m3, 1.0)
    ion = f.plasma_current_MA * 1e6 / column
    ion_factor = clamp((ion / 8e-14)^0.33, 0.50, 1.50)
    theta_factor = clamp((f.pinch_parameter / 1.65)^2.97, 0.50, 1.50)
    tau0 = 0.003 * (geo.a / 0.45)^1.63 *
        max(f.plasma_current_MA, 0.05)^0.78 * ion_factor * theta_factor
    ppcd = 1 + 3f.current_profile_control
    tau0 * ppcd, ion, ppcd
end

function _so_dipole_tau(f, geo, c, quality, field_multiplier)
    T = f.temperature_keV * 1.602176634e-16
    D = T / max(16 * 1.602176634e-19 *
        c.plasma_field_T * field_multiplier, 1e-30)
    geo.a^2 / max(D, 1e-30) * quality *
        (0.65 + 0.35f.levitation_quality)
end

function _so_nominal(g::Genome, c::SharedOuterEnvelopeContractV1, f;
        field_multiplier::Float64 = 1.0, beta_multiplier::Float64 = 1.0,
        dimension_multiplier::Float64 = 1.0,
        field_quality_penalty::Float64 = 0.0,
        control_multiplier::Float64 = 1.0,
        target_area_multiplier::Float64 = 1.0,
        levitation_penalty::Float64 = 0.0)
    mu0, e = 4e-7pi, 1.602176634e-19
    geo = _so_geometry(f, c; dimension_multiplier = dimension_multiplier)
    B, beta = c.plasma_field_T * field_multiplier, f.beta * beta_multiplier
    T = f.temperature_keV * 1.602176634e-16
    reactivity = _dt_reactivity_m3_s(f.temperature_keV)
    quality = clamp(f.field_quality - field_quality_penalty, 0.0, 1.0)
    levitation = clamp(f.levitation_quality - levitation_penalty, 0.0, 1.0)
    pressure = beta * B^2 / (2mu0)
    density = pressure / max(2T, 1e-30)
    fusion = isfinite(reactivity) ?
        0.25density^2 * reactivity * 17.6e6e * geo.volume : 0.0
    alpha, stored = 0.20fusion, 1.5pressure * geo.volume
    rfp_tau, ion, ppcd = _so_rfp_tau(f, geo, density)
    dipole_tau = _so_dipole_tau(f, geo, c, quality, field_multiplier)
    tau = f.family == "reversed_field_pinch" ? rfp_tau : dipole_tau
    loss = stored / max(tau, 1e-30)
    actuator = (f.ppcd_power_W + f.boundary_control_power_W +
        f.dipole_actuator_power_W) * control_multiplier
    auxiliary = max(0.0, loss - alpha) + actuator
    gain = fusion / max(auxiliary, 1.0)
    net = f.pulse_duty_fraction *
        (c.base.thermal_conversion_efficiency * fusion -
            auxiliary / c.base.heating_wall_plug_efficiency) -
        c.base.fixed_balance_of_plant_load_W

    if f.family == "reversed_field_pinch"
        stability = min((f.mode_dominance - 1.0),
            min((f.reversal_parameter + 0.35) / 0.25,
                (-0.02 - f.reversal_parameter) / 0.08),
            min((beta - 0.04) / 0.04, (0.25 - beta) / 0.10))
        particle_loss = max(0.01, 0.08 + 0.45(1 - quality) +
            0.18 / max(f.mode_dominance, 0.25) -
            0.06f.boundary_feedback_strength)
    else
        # For a dipole U scales approximately as R^4, so p*U^(5/3)
        # is marginal at a pressure exponent 20/3. Search the profile,
        # then derive the margin rather than searching a free stability bonus.
        profile = (20 / 3 - f.pressure_profile_exponent) / (20 / 3)
        stability = min(profile,
            min((beta - 0.10) / 0.10, (1 - beta) / 0.25),
            (levitation - 0.90) / 0.10)
        particle_loss = max(0.01, 0.35(1 - levitation) +
            0.10 + 0.35(1 - quality) - 0.08f.inward_pinch_strength)
    end

    n_targets = max(f.target_count, 1)
    target_area = min(f.exhaust_area_fraction * geo.area,
        n_targets * pi * (0.5geo.a)^2 * max(f.exhaust_flux_expansion, 1.0)) *
        target_area_multiplier
    q_exhaust = loss / max(target_area, 1e-9)
    q_neutron = 0.80fusion / max(geo.area, 1e-9)
    external_peak = B * (f.family == "reversed_field_pinch" ?
        1.30 + 0.20f.boundary_feedback_strength : 1.20)
    internal_peak = f.family == "levitated_dipole" ?
        B * f.internal_coil_field_ratio : 0.0
    peak = max(external_peak, internal_peak)
    J = peak / (mu0 * max(f.coil_pack_thickness_m, 0.02)) / 1e6 *
        (f.family == "levitated_dipole" ? 1.35 : 1.15)
    r_internal = f.internal_coil_radius_fraction * geo.a
    curvature = f.family == "levitated_dipole" ? max(0.01, r_internal) : geo.curvature
    stress = peak^2 / (2mu0) *
        (f.family == "levitated_dipole" ? 1.75 :
            1 + 0.25f.boundary_feedback_strength) *
        min(curvature, 2.5) / max(f.support_thickness_m, 0.05)
    internal_access = f.family == "levitated_dipole" ?
        geo.a - r_internal - f.internal_shield_thickness_m -
            f.internal_maintenance_gap_m : geo.a
    internal_surface = max(4pi^2 * max(r_internal, 0.01) *
        max(f.coil_pack_thickness_m, 0.05), 1e-9)
    internal_heat = f.family == "levitated_dipole" ?
        0.80fusion * 0.12 /
            (internal_surface * exp(f.internal_shield_thickness_m / 0.35)) : 0.0
    formation_flux_swing = f.family == "reversed_field_pinch" ?
        3.9 * f.plasma_current_MA : 0.0
    b = c.base
    margins = Dict{String,Float64}(
        "temperature_domain" => min((f.temperature_keV - 5) / 5,
            (30 - f.temperature_keV) / 5),
        "stability" => stability,
        "particle_loss" => (0.25 - particle_loss) / 0.25,
        "fusion_gain" => gain - 1,
        "auxiliary_power" => (b.auxiliary_heating_budget_W - auxiliary) /
            b.auxiliary_heating_budget_W,
        "net_electric_power" => net / max(b.fixed_balance_of_plant_load_W, 1),
        "peak_conductor_field" => (b.peak_conductor_field_limit_T - peak) /
            b.peak_conductor_field_limit_T,
        "engineering_current_density" =>
            (b.engineering_current_density_limit_A_mm2 - J) /
            b.engineering_current_density_limit_A_mm2,
        "support_stress" => (b.support_stress_limit_Pa - stress) /
            b.support_stress_limit_Pa,
        "outer_radial_envelope" => geo.radial_margin / c.outer_radial_extent_m,
        "outer_axial_envelope" => geo.axial_margin / c.outer_axial_half_extent_m,
        "inboard_build" => geo.inboard_margin / c.outer_radial_extent_m,
        "coil_curvature" => (curvature - b.minimum_coil_curvature_radius_m) /
            b.minimum_coil_curvature_radius_m,
        "neutron_wall_load" => (b.maximum_neutron_wall_load_W_m2 - q_neutron) /
            b.maximum_neutron_wall_load_W_m2,
        "exhaust_target_heat_flux" =>
            (c.maximum_exhaust_heat_flux_W_m2 - q_exhaust) /
            c.maximum_exhaust_heat_flux_W_m2,
        "internal_coil_access" => f.family == "levitated_dipole" ?
            internal_access / max(geo.a, 1e-9) : 1.0,
        "internal_coil_nuclear_heating" => f.family == "levitated_dipole" ?
            (0.50e6 - internal_heat) / 0.50e6 : 1.0,
        "inductive_formation_flux_swing" =>
            f.family == "reversed_field_pinch" ?
                (100.0 - formation_flux_swing) / 100.0 : 1.0)
    physics = isfinite(reactivity) && all(margins[id] >= 0 for id in
        ("temperature_domain", "stability", "particle_loss", "fusion_gain",
         "auxiliary_power", "net_electric_power"))
    engineering = all(margins[id] >= 0 for id in
        ("peak_conductor_field", "engineering_current_density", "support_stress",
         "outer_radial_envelope", "outer_axial_envelope", "inboard_build",
         "coil_curvature", "neutron_wall_load", "exhaust_target_heat_flux",
         "internal_coil_access", "internal_coil_nuclear_heating",
         "inductive_formation_flux_swing"))
    Dict{String,Any}(
        "family" => f.family, "major_radius_m" => geo.R,
        "plasma_minor_radius_m" => geo.a, "plasma_half_height_m" => geo.z,
        "plasma_volume_m3" => geo.volume, "first_wall_area_m2" => geo.area,
        "beta" => beta, "temperature_keV" => f.temperature_keV,
        "pressure_Pa" => pressure, "density_m3" => density,
        "fusion_power_W" => fusion, "alpha_power_W" => alpha,
        "stored_energy_MJ" => stored / 1e6,
        "energy_confinement_time_s" => tau,
        "rfp_lower_anchor_time_s" => rfp_tau, "rfp_i_over_n_A_m" => ion,
        "rfp_ppcd_multiplier" => ppcd, "dipole_bohm_time_s" => dipole_tau,
        "rfp_total_extrapolation_from_3ms_anchor" =>
            f.family == "reversed_field_pinch" ? rfp_tau / 0.003 : 0.0,
        "rfp_size_current_extrapolation_before_ppcd" =>
            f.family == "reversed_field_pinch" ?
                rfp_tau / max(0.003 * ppcd, 1e-30) : 0.0,
        "transport_loss_power_W" => loss,
        "declared_actuator_power_W" => actuator,
        "declared_ppcd_power_W" => f.ppcd_power_W * control_multiplier,
        "declared_boundary_control_power_W" =>
            f.boundary_control_power_W * control_multiplier,
        "required_auxiliary_power_W" => auxiliary, "fusion_gain_proxy" => gain,
        "pulse_duty_fraction" => f.pulse_duty_fraction,
        "average_net_electric_power_W" => net,
        "net_electric_power_W" => net,
        "particle_loss_fraction_proxy" => particle_loss,
        "minimum_stability_margin_proxy" => stability,
        "target_count" => n_targets, "effective_target_area_m2" => target_area,
        "exhaust_heat_flux_W_m2" => q_exhaust,
        "external_neutron_wall_load_W_m2" => q_neutron,
        "internal_coil_nuclear_heat_flux_W_m2" => internal_heat,
        "minimum_inductive_formation_flux_swing_Wb" => formation_flux_swing,
        "external_peak_field_T" => external_peak,
        "internal_coil_peak_field_T" => internal_peak,
        "peak_conductor_field_T" => peak,
        "engineering_current_density_A_mm2" => J,
        "support_stress_proxy_Pa" => stress,
        "minimum_coil_curvature_radius_m" => curvature,
        "internal_coil_access_margin_m" => internal_access,
        "outer_radial_margin_m" => geo.radial_margin,
        "outer_axial_margin_m" => geo.axial_margin,
        "inboard_build_margin_m" => geo.inboard_margin,
        "physics_gate_passed" => physics,
        "engineering_gate_passed" => engineering,
        "margins" => margins,
        "minimum_normalized_margin" => minimum(values(margins)))
end

function _so_graph_errors(g::Genome, f, c::SharedOuterEnvelopeContractV1)
    errors = String[]
    append!(errors, validate_genome(g).errors)
    append!(errors, validate_family(default_family_registry(), g).errors)
    for (name, expected, unit) in (
            ("screen_outer_radial_extent", c.outer_radial_extent_m, "m"),
            ("screen_outer_axial_half_extent", c.outer_axial_half_extent_m, "m"),
            ("screen_plasma_field", c.plasma_field_T, "T"))
        q = get(g.mission.targets, name, nothing)
        if q === nothing || q.unit != unit ||
                !isapprox(q.value, expected; rtol = 1e-12, atol = 1e-12)
            push!(errors, "$name is inconsistent with outer-envelope contract")
        end
    end
    cores = filter(r -> r.kind == "closed_toroidal_core", g.plasma_regions)
    sols = filter(r -> r.kind == "scrape_off_layer", g.plasma_regions)
    targets = filter(r -> r.kind == "divertor_or_exhaust_region",
        g.plasma_regions)
    length(cores) == 1 ||
        push!(errors, "exactly one closed toroidal core is required")
    length(sols) == 1 || push!(errors, "exactly one explicit SOL is required")
    length(targets) >= 2 ||
        push!(errors, "at least two explicit targets are required")
    target_ids = Set(r.id for r in targets)
    all(id -> id in Set(g.exhaust.region_ids), target_ids) ||
        push!(errors, "all targets must be listed by the exhaust graph")
    if length(cores) == 1 && length(sols) == 1
        count(e -> e.from_region_id == only(cores).id &&
            e.to_region_id == only(sols).id &&
            e.kind == "cross_separatrix_transport",
            g.flux_connections) == 1 ||
            push!(errors, "one core-to-SOL cross-separatrix edge is required")
        count(e -> e.from_region_id == only(sols).id &&
            e.to_region_id in target_ids && e.kind == "open_field_line",
            g.flux_connections) == length(targets) ||
            push!(errors, "SOL must connect to every target by open field lines")
    end
    if f.family == "reversed_field_pinch"
        _so_has_kind(g.field_sources, "self_organized_plasma_current") ||
            push!(errors, "RFP requires self-organized plasma current")
        _so_has_kind(g.field_sources, "conducting_shell") ||
            push!(errors, "RFP requires an explicit close-fitting conducting shell")
        "plasma_current" in g.topology.rotation_transform_sources ||
            push!(errors, "RFP transform source must include plasma current")
        if f.current_profile_control > 1e-9
            _so_has_kind(g.actuators, "pulsed_poloidal_current_drive") ||
                push!(errors, "PPCD credit requires an explicit PPCD actuator")
            f.ppcd_power_W > 0 ||
                push!(errors, "PPCD credit requires declared positive power")
        end
        if f.boundary_feedback_strength > 1e-9
            _so_has_kind(g.field_sources, "boundary_mode_control") ||
                push!(errors, "boundary-control credit requires saddle coils")
            _so_has_kind(g.actuators, "magnetic_feedback") ||
                push!(errors,
                    "boundary-control credit requires a feedback actuator")
            f.boundary_feedback_strength >= 0.10 ||
                push!(errors,
                    "boundary-control branch requires strength at least 0.10")
            f.boundary_control_power_W > 0 ||
                push!(errors,
                    "boundary-control credit requires declared positive power")
        end
    else
        _so_has_kind(g.field_sources, "levitated_internal_dipole") ||
            push!(errors, "dipole requires an explicit levitated internal coil")
        any(path -> occursin("internal", lowercase(path)) ||
            occursin("levitated", lowercase(path)),
            g.engineering.access_paths) ||
            push!(errors, "dipole requires an internal-coil maintenance path")
        f.levitation_quality >= 0.90 ||
            push!(errors, "dipole requires levitation quality at least 0.90")
    end
    2 <= f.target_count <= 8 ||
        push!(errors, "target count must be within [2, 8]")
    sort!(unique(errors))
end

function _so_robustness(g::Genome, c::SharedOuterEnvelopeContractV1, f)
    rng = MersenneTwister(c.base.robustness_seed + 7)
    records, pass_count, worst = Dict{String,Any}[], 0, Inf
    for sample in 1:c.base.robustness_samples
        field_delta = 0.02 * (2rand(rng) - 1)
        beta_delta = 0.15 * (2rand(rng) - 1)
        dimension_delta = 0.01 * (2rand(rng) - 1)
        coil_offset_m = 0.003 * (2rand(rng) - 1)
        control_error = 0.10 * (2rand(rng) - 1)
        target_occlusion = 0.10rand(rng)
        levitation_penalty = f.family == "levitated_dipole" ?
            abs(coil_offset_m) / 0.03 : 0.0
        quality_penalty = abs(coil_offset_m) /
            max(c.outer_radial_extent_m, 1e-9) + 0.03abs(control_error)
        nominal = _so_nominal(g, c, f;
            field_multiplier = 1 + field_delta,
            beta_multiplier = 1 + beta_delta,
            dimension_multiplier = 1 + dimension_delta,
            field_quality_penalty = quality_penalty,
            control_multiplier = 1 + control_error,
            target_area_multiplier = 1 - target_occlusion,
            levitation_penalty = levitation_penalty)
        passed = nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true
        passed && (pass_count += 1)
        worst = min(worst, Float64(nominal["minimum_normalized_margin"]))
        push!(records, Dict{String,Any}(
            "sample" => sample, "field_delta_fraction" => field_delta,
            "beta_delta_fraction" => beta_delta,
            "dimension_delta_fraction" => dimension_delta,
            "coil_offset_m" => coil_offset_m,
            "control_power_error_fraction" => control_error,
            "target_occlusion_fraction" => target_occlusion,
            "passed" => passed,
            "minimum_normalized_margin" => nominal["minimum_normalized_margin"]))
    end
    fraction = pass_count / c.base.robustness_samples
    Dict{String,Any}(
        "sample_count" => c.base.robustness_samples,
        "common_random_seed" => c.base.robustness_seed + 7,
        "pass_count" => pass_count, "pass_fraction" => fraction,
        "required_pass_fraction" => c.base.robustness_required_pass_fraction,
        "gate_passed" => fraction >= c.base.robustness_required_pass_fraction,
        "worst_minimum_normalized_margin" => worst, "records" => records)
end

function _self_organized_result(e::SelfOrganizedScreenV1, g::Genome)
    f = _so_features(g)
    graph_errors = _so_graph_errors(g, f, e.contract)
    graph_gate = isempty(graph_errors)
    nominal = _so_nominal(g, e.contract, f)
    robustness = if graph_gate && nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true
        _so_robustness(g, e.contract, f)
    else
        Dict{String,Any}(
            "sample_count" => 0,
            "maximum_sample_budget" => e.contract.base.robustness_samples,
            "common_random_seed" => e.contract.base.robustness_seed + 7,
            "pass_count" => 0, "pass_fraction" => 0.0,
            "required_pass_fraction" =>
                e.contract.base.robustness_required_pass_fraction,
            "gate_passed" => false,
            "worst_minimum_normalized_margin" =>
                nominal["minimum_normalized_margin"],
            "records" => Dict{String,Any}[],
            "skipped_due_nominal_gate_failure" => true)
    end
    contract_hash = canonical_hash(_oe_contract_dict(e.contract))
    contract_gate = contract_hash in e.allowed_contract_hashes
    all_five = graph_gate && nominal["physics_gate_passed"] === true &&
        nominal["engineering_gate_passed"] === true && contract_gate &&
        robustness["gate_passed"] === true
    complexity = length(g.field_sources) + 1.5length(g.actuators) +
        0.5length(g.plasma_regions) + 0.25length(g.flux_connections) +
        (f.family == "levitated_dipole" ? 4.0 : 0.0)
    result = Dict{String,Any}(
        "contract" => _oe_contract_dict(e.contract),
        "contract_hash" => contract_hash,
        "claim_boundary" => _SELF_ORGANIZED_SCREEN_CLAIM_BOUNDARY,
        "source_basis" => _SELF_ORGANIZED_V7_SOURCE_BASIS,
        "topology_features" =>
            Dict(String(k) => v for (k, v) in pairs(f)),
        "topology_graph_errors" => graph_errors,
        "nominal" => nominal, "robustness" => robustness,
        "gates" => Dict(
            "variable_topology_representation" => graph_gate,
            "unified_low_fidelity_physics" => nominal["physics_gate_passed"],
            "minimal_engineering_closure" => nominal["engineering_gate_passed"],
            "same_outer_envelope_contract" => contract_gate,
            "cheap_robustness_screen" => robustness["gate_passed"]),
        "all_five_gates_passed" => all_five,
        "positive_net_power_closure_passed" =>
            nominal["net_electric_power_W"] > 0,
        "classification" => all_five ?
            "self_organized_survivor_pending_family_solver" :
            "obviously_infeasible_or_unresolved",
        "device_complexity_proxy" => complexity)
    result["result_hash"] = canonical_hash(result)
    result
end

function run_evaluator(e::SelfOrganizedScreenV1, g::Genome; kwargs...)
    applicable, reason = evaluator_applicability(e, g)
    applicable || return _non_applicable_bundle(evaluator_spec(e), g, reason)
    result = _self_organized_result(e, g)
    run_hash = canonical_hash(Dict(
        "input_hash" => g.physics_hash,
        "evaluator" => "self_organized_screen_v1",
        "version" => "1.0.0", "result_hash" => result["result_hash"]))
    status = result["all_five_gates_passed"] === true ? :pass : :fail
    metric = MetricResult("self_organized_five_gate_pass",
        result["all_five_gates_passed"] ? 1.0 : 0.0;
        fidelity = 0, applicability = reason, status = status,
        constraints_checked = sort!(collect(keys(result["gates"]))),
        solver_name = "self_organized_screen_v1",
        solver_version = "1.0.0", input_hash = g.physics_hash,
        run_hash = run_hash, source_basis = _SELF_ORGANIZED_V7_SOURCE_BASIS,
        warnings = [result["claim_boundary"]])
    EvaluationBundle("self_organized_screen_v1", g.design_id, g.family, 0,
        status, [metric], String[], g.physics_hash, run_hash,
        _SELF_ORGANIZED_SCREEN_CLAIM_BOUNDARY)
end
