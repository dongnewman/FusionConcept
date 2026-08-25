struct MirrorBeam0DV1 <: AbstractEvaluator end

const _MIRROR_BASIS = String[
    "mirror_egedal_fbis_2022",
    "mirror_wham_physics_basis_2023",
    "mirror_beam_2024",
    "mirror_ryutov_mhd_2011",
]

function evaluator_spec(::MirrorBeam0DV1)
    return EvaluatorSpec(
        "mirror_beam_0d_v1",
        "1.0.0",
        ["magnetic_mirror"],
        0,
        Dict(
            "fokker_planck" => :proxy,
            "flr_stability" => :proxy,
            "fast_ion_adiabaticity" => :proxy,
            "dclc" => :proxy,
            "actuator_power" => :proxy,
            "beam_absorption" => :proxy,
            "fusion_gain" => :proxy,
        ),
        "physics_proxy",
    )
end

function _one_by_kind(items, kind, label)
    matches = filter(item -> item.kind == kind, items)
    length(matches) == 1 || throw(ArgumentError("expected exactly one $label of kind $kind"))
    return only(matches)
end

function _parameter(item, name, unit)
    value = get(item.parameters, name, nothing)
    value === nothing && throw(ArgumentError("$(item.id) is missing parameter $name"))
    value.unit == unit || throw(ArgumentError("$(item.id).$name must use canonical unit $unit"))
    return value.value
end

function _mirror_beam_inputs(genome::Genome)
    central = _one_by_kind(genome.plasma_regions, "mirror_central_cell", "plasma region")
    mirror_coils = _one_by_kind(genome.field_sources, "mirror_coil", "field source")
    nbi = _one_by_kind(genome.actuators, "nbi", "actuator")
    central_field_T = _parameter(central, "central_field", "T")
    radius_m = _parameter(central, "plasma_radius", "m")
    length_m = _parameter(central, "cell_length", "m")
    density_m3 = _parameter(central, "ion_density", "m^-3")
    beta_limit = _parameter(central, "beta_limit", "1")
    volume_q = get(central.parameters, "effective_plasma_volume", nothing)
    volume_m3 = volume_q === nothing ? pi * radius_m^2 * length_m : begin
        volume_q.unit == "m^3" || throw(ArgumentError("effective_plasma_volume must use m^3"))
        volume_q.value
    end
    peak_field_T = _parameter(mirror_coils, "peak_field", "T")
    beam_energy_J = _parameter(nbi, "beam_energy", "J")
    injection_angle_rad = _parameter(nbi, "injection_angle", "rad")
    return (
        central = central,
        central_field_T = central_field_T,
        radius_m = radius_m,
        length_m = length_m,
        density_m3 = density_m3,
        beta_limit = beta_limit,
        volume_m3 = volume_m3,
        peak_field_T = peak_field_T,
        beam_energy_J = beam_energy_J,
        injection_angle_rad = injection_angle_rad,
    )
end

function _mirror_beam_mismatches(genome::Genome)
    mismatches = String[]
    genome.family == "magnetic_mirror" || push!(mismatches, "family must be magnetic_mirror")
    genome.mission.fuel == "D-T" || push!(mismatches, "fuel must be D-T")
    genome.topology.field_line_class == "open_mirror" || push!(mismatches, "field lines must be open_mirror")
    genome.symmetry.class == "axisymmetric" || push!(mismatches, "symmetry must be axisymmetric")
    any(region -> region.kind == "mirror_plug_or_anchor", genome.plasma_regions) &&
        push!(mismatches, "tandem plugs require a different evaluator")
    any(source -> source.kind == "minimum_b_coil", genome.field_sources) &&
        push!(mismatches, "minimum-B coils require a 3D evaluator")
    any(mechanism -> mechanism.id == "mirror_gas_dynamic_regime_mechanism",
        genome.stability_mechanisms) &&
        push!(mismatches, "gas-dynamic regime requires the GDT evaluator")
    try
        input = _mirror_beam_inputs(genome)
        input.central.geometry_model == "beam_classical_mirror_0d" ||
            push!(mismatches, "central cell must declare beam_classical_mirror_0d")
        energy_100 = input.beam_energy_J / (100.0 * 1.602176634e-16)
        angle_deg = input.injection_angle_rad * 180.0 / pi
        n20 = input.density_m3 / 1.0e20
        vacuum_ratio = input.peak_field_T / input.central_field_T
        beta = 3.0 * n20 * energy_100 / input.central_field_T^2
        1.0 <= energy_100 <= 2.0 || push!(mismatches, "beam energy must be 100-200 keV")
        80.0 <= angle_deg <= 100.0 || push!(mismatches, "injection must be near perpendicular (80-100 deg)")
        1.5 <= input.central_field_T <= 6.0 || push!(mismatches, "central field outside 1.5-6 T model range")
        0.2 <= n20 <= 3.0 || push!(mismatches, "density outside 0.2-3e20 m^-3 model range")
        0.15 <= input.radius_m <= 1.0 || push!(mismatches, "radius outside 0.15-1 m model range")
        3.0 <= input.length_m <= 50.0 || push!(mismatches, "length outside 3-50 m model range")
        5.0 <= vacuum_ratio <= 20.0 || push!(mismatches, "vacuum mirror ratio outside 5-20 model range")
        0.05 <= beta < 0.70 || push!(mismatches, "beta outside 0.05-0.70 model range")
        input.volume_m3 > 0.0 || push!(mismatches, "effective volume must be positive")
        0.1 <= input.beta_limit <= 0.6 || push!(mismatches, "beta limit outside 0.1-0.6 declared range")
    catch error
        push!(mismatches, sprint(showerror, error))
    end
    return mismatches
end

function evaluator_applicability(evaluator::MirrorBeam0DV1, genome::Genome)
    spec = evaluator_spec(evaluator)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    mismatches = _mirror_beam_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "high-energy, low-collisionality, axisymmetric simple-mirror scaling domain" :
        "mirror_beam_0d_v1 applicability mismatch: $(join(mismatches, "; "))"
end

function _mirror_metric(id, value; unit = "1", uncertainty = nothing,
        status = :pass, constraints = String[], input_hash, run_hash,
        warnings = String[], wall_time = 0.0)
    return MetricResult(id, value;
        unit = unit,
        uncertainty = uncertainty,
        fidelity = 0,
        applicability = "BEAM/Egedal high-energy classical simple-mirror 0-D scaling domain only.",
        status = status,
        constraints_checked = constraints,
        solver_name = "mirror_beam_0d_v1",
        solver_version = "1.0.0",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = _MIRROR_BASIS,
        warnings = warnings,
        wall_time_s = wall_time)
end

function run_evaluator(evaluator::MirrorBeam0DV1, genome::Genome; kwargs...)
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return _non_applicable_bundle(evaluator_spec(evaluator), genome, reason)
    input = _mirror_beam_inputs(genome)
    values = Dict{String,Any}()
    elapsed = @elapsed begin
        energy_100 = input.beam_energy_J / (100.0 * 1.602176634e-16)
        n20 = input.density_m3 / 1.0e20
        vacuum_ratio = input.peak_field_T / input.central_field_T
        beta = 3.0 * n20 * energy_100 / input.central_field_T^2
        effective_ratio = vacuum_ratio / sqrt(1.0 - beta)
        log_ratio = log10(effective_ratio)
        n20_tau_s = 0.25 * energy_100^(3 / 2) * log_ratio
        confinement_s = n20_tau_s / n20
        gain = sqrt(energy_100) * log_ratio
        beam_power_W = 6.4e6 * n20^2 * input.volume_m3 /
            (sqrt(energy_100) * log_ratio)
        fusion_power_W = gain * beam_power_W
        n_rho = 25.0 * input.radius_m * input.central_field_T / sqrt(energy_100)
        flr_factor = input.length_m / (n_rho * input.radius_m)
        beam_absorption_margin_m = n20 * input.radius_m - 0.3 * sqrt(energy_100)
        beta_margin = input.beta_limit - beta
        adiabaticity_ratio = n_rho /
            (5.0 * (1.0 - sqrt(1.0 - beta)))

        values = Dict{String,Any}(
            "vacuum_mirror_ratio" => vacuum_ratio,
            "effective_mirror_ratio_proxy" => effective_ratio,
            "beta_proxy" => beta,
            "beta_limit_margin_proxy" => beta_margin,
            "classical_n_tau_proxy" => n20_tau_s * 1.0e20,
            "particle_confinement_time_proxy" => confinement_s,
            "fusion_gain_proxy" => gain,
            "fusion_gain" => gain,
            "absorbed_beam_power_proxy" => beam_power_W,
            "fusion_power_proxy" => fusion_power_W,
            "fusion_power" => fusion_power_W,
            "effective_plasma_volume" => input.volume_m3,
            "n_rho_proxy" => n_rho,
            "flr_m2_factor_proxy" => flr_factor,
            "flr_m2_length_margin_proxy" => input.length_m - n_rho * input.radius_m,
            "beam_absorption_margin_proxy" => beam_absorption_margin_m,
            "radial_adiabaticity_ratio_proxy" => adiabaticity_ratio,
            "peak_field_25T_margin_proxy" => 25.0 - input.peak_field_T,
            "high_mirror_ratio_margin_proxy" => effective_ratio - 10.0,
            "beta_limit_feasible_proxy" => beta_margin >= 0.0,
            "beam_absorption_90pct_feasible_proxy" => beam_absorption_margin_m >= -1.0e-12,
            "dclc_size_feasible_proxy" => n_rho >= 25.0,
            "flr_m2_feasible_proxy" => flr_factor > 1.0,
            "fast_ion_adiabaticity_feasible_proxy" => adiabaticity_ratio > 10.0 && beta < 0.75,
            "peak_field_25T_feasible_proxy" => input.peak_field_T <= 25.0,
            "high_mirror_ratio_feasible_proxy" => effective_ratio >= 10.0,
        )
    end
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "evaluator" => "mirror_beam_0d_v1",
        "version" => "1.0.0",
        "formula_set" => ["WHAM 3.4", "BEAM 1.2", "BEAM 2.1-2.12"],
        "values" => values,
    ))
    warnings = String[
        "Model-form uncertainty values are conservative adapter assumptions, not paper-reported confidence intervals.",
        "The Q scaling assumes 100-200 keV near-perpendicular NBI and classical parallel confinement.",
        "No self-consistent Fokker-Planck distribution, ambipolar potential, radiation, charge exchange, or cross-field transport is solved.",
        "FLR only screens m>=2 interchange; the global m=1 mode remains unknown.",
        "Net electricity, TBR, blanket, magnet stress/quench, end recovery, and RAMI remain unknown.",
    ]
    fractional_uncertainty = Dict(
        "vacuum_mirror_ratio" => 0.02,
        "effective_mirror_ratio_proxy" => 0.20,
        "beta_proxy" => 0.15,
        "beta_limit_margin_proxy" => 0.25,
        "classical_n_tau_proxy" => 0.35,
        "particle_confinement_time_proxy" => 0.35,
        "fusion_gain_proxy" => 0.35,
        "fusion_gain" => 0.35,
        "absorbed_beam_power_proxy" => 0.50,
        "fusion_power_proxy" => 0.60,
        "fusion_power" => 0.60,
        "effective_plasma_volume" => 0.25,
        "n_rho_proxy" => 0.20,
        "flr_m2_factor_proxy" => 0.35,
        "flr_m2_length_margin_proxy" => 0.50,
        "beam_absorption_margin_proxy" => 0.50,
        "radial_adiabaticity_ratio_proxy" => 0.35,
        "peak_field_25T_margin_proxy" => 0.10,
        "high_mirror_ratio_margin_proxy" => 0.50,
    )
    units = Dict(
        "classical_n_tau_proxy" => "s/m^3",
        "particle_confinement_time_proxy" => "s",
        "absorbed_beam_power_proxy" => "W",
        "fusion_power_proxy" => "W",
        "fusion_power" => "W",
        "effective_plasma_volume" => "m^3",
        "flr_m2_length_margin_proxy" => "m",
        "beam_absorption_margin_proxy" => "m",
        "peak_field_25T_margin_proxy" => "T",
    )
    metrics = MetricResult[]
    for id in sort!(collect(keys(values)))
        value = values[id]
        uncertainty = value isa Bool ? nothing :
            get(fractional_uncertainty, id, 0.35) * max(abs(Float64(value)), 1.0e-12)
        push!(metrics, _mirror_metric(id, value;
            unit = get(units, id, "1"),
            uncertainty = uncertainty,
            constraints = ["BEAM analytic scaling applicability"],
            input_hash = genome.physics_hash,
            run_hash = run_hash,
            warnings = warnings,
            wall_time = elapsed))
    end
    for (id, unit, message) in (
            ("m1_interchange_stability", "1", "global m=1 interchange was not evaluated"),
            ("minimum_stability_margin", "1", "no complete all-mode stability margin was evaluated"),
            ("plasma_stability_feasible", "1", "all required plasma instabilities were not evaluated"),
            ("device_complexity_index", "1", "physics-based device complexity was not evaluated"),
            ("cross_field_transport_feasible", "1", "cross-field transport was not evaluated"),
            ("atomic_loss_power", "W", "charge exchange and atomic loss power were not evaluated"),
            ("engineering_feasible", "1", "integrated engineering was not evaluated"),
            ("net_electric_power", "W", "power conversion and recirculating loads were not evaluated"),
            ("tritium_breeding_ratio", "1", "neutronics and breeding were not evaluated"))
        push!(metrics, _mirror_metric(id, nothing;
            unit = unit,
            status = :unknown,
            input_hash = genome.physics_hash,
            run_hash = run_hash,
            warnings = vcat(warnings, [message]),
            wall_time = elapsed))
    end
    proxy_gates = String[
        "beta_limit_feasible_proxy",
        "beam_absorption_90pct_feasible_proxy",
        "dclc_size_feasible_proxy",
        "flr_m2_feasible_proxy",
        "fast_ion_adiabaticity_feasible_proxy",
        "peak_field_25T_feasible_proxy",
        "high_mirror_ratio_feasible_proxy",
    ]
    all_proxy_gates = all(id -> values[id] === true, proxy_gates)
    return EvaluationBundle("mirror_beam_0d_v1", genome.design_id, genome.family,
        0, all_proxy_gates ? :pass : :fail, metrics, warnings,
        genome.physics_hash, run_hash, "physics_proxy")
end
