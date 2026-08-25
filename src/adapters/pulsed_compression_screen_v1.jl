const _PULSED_SCREEN_SOURCE_BASIS = String[
    "mtf_overview_kirkpatrick_1995",
    "mtf_target_formation_lindemuth_1995",
    "mtf_centimeter_liner_ryutov_2005",
    "pjmif_target_hsu_langendorf_2019",
    "pjmif_semi_analytic_langendorf_hsu_2017",
    "maglif_semi_analytic_mcbride_slutz_2015",
    "maglif_high_gain_slutz_vesey_2012",
    "frc_compression_nimrod_ma_2023",
    "bosch_hale_reactivity_1992",
]

const _PULSED_SCREEN_CLAIM_BOUNDARY =
    "Fidelity-0 non-igniting pulsed-compression rejection screen. It applies idealized " *
    "adiabatic spherical or cylindrical scaling with explicit loss retention, target " *
    "lifetime, Bohm-transport, Spitzer-resistive magnetic Reynolds, compression-work, " *
    "driver/preheat/formation energy, repetition, availability, recovery, chamber load, " *
    "mass-throughput, and average-net-electric ledgers. It does not model alpha ignition, " *
    "radiation-MHD, liner instability or mix, end loss, Nernst transport, target formation, " *
    "stand-off, chamber clearing, component fatigue, tritium breeding, or a validated reactor."

"Declared engineering screening assumptions layered over a shared outer envelope."
struct PulsedCompressionContractV1
    id::String
    outer::SharedOuterEnvelopeContractV1
    maximum_convergence_ratio::Float64
    minimum_magnetic_reynolds_number::Float64
    minimum_transport_to_implosion_ratio::Float64
    minimum_target_lifetime_to_implosion_ratio::Float64
    maximum_repetition_rate_Hz::Float64
    maximum_recovery_fraction::Float64
    maximum_solid_liner_throughput_kg_s::Float64
    maximum_plasma_liner_throughput_kg_s::Float64
    maximum_average_chamber_heat_flux_W_m2::Float64

    function PulsedCompressionContractV1(id::AbstractString,
            outer::SharedOuterEnvelopeContractV1;
            maximum_convergence_ratio::Real = 15.0,
            minimum_magnetic_reynolds_number::Real = 100.0,
            minimum_transport_to_implosion_ratio::Real = 3.0,
            minimum_target_lifetime_to_implosion_ratio::Real = 1.0,
            maximum_repetition_rate_Hz::Real = 10.0,
            maximum_recovery_fraction::Real = 0.50,
            maximum_solid_liner_throughput_kg_s::Real = 1.0,
            maximum_plasma_liner_throughput_kg_s::Real = 20.0,
            maximum_average_chamber_heat_flux_W_m2::Real = 10.0e6)
        all(value -> value > 0.0, (maximum_convergence_ratio,
            minimum_magnetic_reynolds_number,
            minimum_transport_to_implosion_ratio,
            minimum_target_lifetime_to_implosion_ratio,
            maximum_repetition_rate_Hz,
            maximum_solid_liner_throughput_kg_s,
            maximum_plasma_liner_throughput_kg_s,
            maximum_average_chamber_heat_flux_W_m2)) ||
            throw(ArgumentError("pulsed contract positive limits are required"))
        0.0 <= maximum_recovery_fraction <= 1.0 ||
            throw(ArgumentError("maximum recovery fraction must be in [0,1]"))
        return new(String(id), outer, Float64(maximum_convergence_ratio),
            Float64(minimum_magnetic_reynolds_number),
            Float64(minimum_transport_to_implosion_ratio),
            Float64(minimum_target_lifetime_to_implosion_ratio),
            Float64(maximum_repetition_rate_Hz),
            Float64(maximum_recovery_fraction),
            Float64(maximum_solid_liner_throughput_kg_s),
            Float64(maximum_plasma_liner_throughput_kg_s),
            Float64(maximum_average_chamber_heat_flux_W_m2))
    end
end

function pulsed_compression_contract_v1(outer::SharedOuterEnvelopeContractV1)
    return PulsedCompressionContractV1("pulsed_average_power_v1__$(outer.id)",
        outer)
end

function _pulsed_contract_dict(contract::PulsedCompressionContractV1)
    return Dict{String,Any}(
        "id" => contract.id,
        "outer_envelope" => _oe_contract_dict(contract.outer),
        "literature_bounded_constraints" => Dict(
            "maximum_convergence_ratio" => contract.maximum_convergence_ratio,
            "minimum_magnetic_reynolds_number" =>
                contract.minimum_magnetic_reynolds_number,
            "minimum_transport_to_implosion_ratio" =>
                contract.minimum_transport_to_implosion_ratio,
            "minimum_target_lifetime_to_implosion_ratio" =>
                contract.minimum_target_lifetime_to_implosion_ratio,
        ),
        "declared_engineering_screening_assumptions" => Dict(
            "maximum_repetition_rate_Hz" => contract.maximum_repetition_rate_Hz,
            "maximum_recovery_fraction" => contract.maximum_recovery_fraction,
            "maximum_solid_liner_throughput_kg_s" =>
                contract.maximum_solid_liner_throughput_kg_s,
            "maximum_plasma_liner_throughput_kg_s" =>
                contract.maximum_plasma_liner_throughput_kg_s,
            "maximum_average_chamber_heat_flux_W_m2" =>
                contract.maximum_average_chamber_heat_flux_W_m2,
            "target_lifetime_sound_crossing_factors" => Dict(
                "frc" => 2.5, "spheromak" => 1.5,
                "diffuse_pinch" => 0.50),
        ),
    )
end

struct PulsedCompressionScreenV1 <: AbstractEvaluator
    contract::PulsedCompressionContractV1
end

function evaluator_spec(::PulsedCompressionScreenV1)
    return EvaluatorSpec("pulsed_compression_screen_v1", "1.0.0",
        ["magnetized_target_fusion"], 0,
        Dict("target_transport" => :proxy, "magnetic_flux_retention" => :proxy,
            "compression_heating" => :proxy, "power_balance" => :proxy,
            "repeat_rate_chamber" => :proxy, "liner_mass_throughput" => :proxy,
            "average_wall_load" => :proxy), _PULSED_SCREEN_CLAIM_BOUNDARY)
end

function evaluator_applicability(evaluator::PulsedCompressionScreenV1,
        genome::Genome)
    genome.family == "magnetized_target_fusion" || return false,
        "pulsed compression screen only covers magnetized_target_fusion"
    genome.mission.fuel == "D-T" || return false,
        "pulsed compression screen v1 is restricted to D-T"
    report = validate_genome(genome)
    report.valid || return false, join(report.errors, "; ")
    return true, "pulsed average-power contract $(evaluator.contract.id)"
end

function _pulsed_system(genome::Genome)
    length(genome.compression_systems) == 1 || throw(ArgumentError(
        "pulsed screen v1 requires exactly one compression system"))
    return only(genome.compression_systems)
end

function _pulsed_parameter(system::CompressionSystem, name::String, unit::String)
    value = get(system.parameters, name, nothing)
    value === nothing && throw(ArgumentError(
        "compression_systems.$(system.id).parameters.$name is required"))
    value.unit == unit || throw(ArgumentError(
        "compression parameter $name must use canonical unit $unit"))
    return value.value
end

function _pulsed_features(genome::Genome)
    system = _pulsed_system(genome)
    model = system.geometry_model
    geometry = occursin("spherical", model) ? "spherical" : "cylindrical"
    target_topology = occursin("frc", model) ? "frc" :
        occursin("spheromak", model) ? "spheromak" : "diffuse_pinch"
    return (
        target_topology = target_topology,
        liner_kind = system.kind,
        compression_geometry = geometry,
        initial_radius_m = _pulsed_parameter(system, "initial_target_radius", "m"),
        initial_half_length_m = _pulsed_parameter(system,
            "initial_target_half_length", "m"),
        convergence_ratio = _pulsed_parameter(system, "convergence_ratio", "1"),
        liner_velocity_m_s = _pulsed_parameter(system, "liner_velocity", "m/s"),
        liner_mass_kg = _pulsed_parameter(system, "liner_mass", "kg"),
        repetition_rate_Hz = _pulsed_parameter(system, "repetition_rate", "Hz"),
        availability = _pulsed_parameter(system, "availability", "1"),
        driver_efficiency = _pulsed_parameter(system, "driver_efficiency", "1"),
        formation_efficiency = _pulsed_parameter(system,
            "formation_efficiency", "1"),
        recovery_fraction = _pulsed_parameter(system, "recovery_fraction", "1"),
        compression_retention = _pulsed_parameter(system,
            "compression_retention", "1"),
        preheat_energy_J = _pulsed_parameter(system, "preheat_energy", "J"),
        initial_temperature_keV = _oe_target(genome,
            "screen_initial_target_temperature", 0.20 * 1.602176634e-16,
            "J") / 1.602176634e-16,
        initial_beta = _oe_target(genome, "screen_initial_target_beta", 1.0, "1"),
        seed_field_T = _oe_target(genome, "screen_plasma_field",
            4.0, "T"),
    )
end

function _pulsed_topology_lifetime_factor(topology::String)
    topology == "frc" && return 2.5
    topology == "spheromak" && return 1.5
    return 0.50
end

function _pulsed_nominal(genome::Genome, contract::PulsedCompressionContractV1,
        features; field_multiplier::Float64 = 1.0,
        convergence_multiplier::Float64 = 1.0,
        velocity_multiplier::Float64 = 1.0,
        retention_multiplier::Float64 = 1.0,
        repetition_multiplier::Float64 = 1.0,
        recovery_delta::Float64 = 0.0,
        lifetime_multiplier::Float64 = 1.0)
    mu0 = 4.0e-7 * pi
    e = 1.602176634e-19
    ion_mass = 0.5 * (3.3435837724e-27 + 5.0073567446e-27)
    B0 = features.seed_field_T * field_multiplier
    C = features.convergence_ratio * convergence_multiplier
    velocity = features.liner_velocity_m_s * velocity_multiplier
    retention = clamp(features.compression_retention * retention_multiplier,
        0.0, 1.0)
    repetition = features.repetition_rate_Hz * repetition_multiplier
    recovery = clamp(features.recovery_fraction + recovery_delta, 0.0, 1.0)
    r0 = features.initial_radius_m
    half_length = features.initial_half_length_m
    dimension = features.compression_geometry == "spherical" ? 3.0 : 2.0
    volume0 = features.compression_geometry == "spherical" ?
        4.0 / 3.0 * pi * r0^3 : 2.0 * pi * r0^2 * half_length
    rstag = r0 / max(C, 1.0e-9)
    volume_stag = volume0 / max(C^dimension, 1.0e-30)
    T0_keV = features.initial_temperature_keV
    T0_J = T0_keV * 1.602176634e-16
    pressure0 = features.initial_beta * B0^2 / (2.0 * mu0)
    density0 = pressure0 / max(2.0 * T0_J, 1.0e-30)
    temperature_exponent = 2.0 * dimension / 3.0
    density_stag = density0 * C^dimension
    Tstag_keV = T0_keV * C^temperature_exponent * retention
    Tstag_J = Tstag_keV * 1.602176634e-16
    Bstag = B0 * C^2 * sqrt(max(retention, 0.0))
    pressure_stag = 2.0 * density_stag * Tstag_J
    implosion_time = max(r0 - rstag, 0.0) / max(velocity, 1.0)

    sound0 = sqrt(max(2.0 * T0_J / ion_mass, 0.0))
    sound_stag = sqrt(max(2.0 * Tstag_J / ion_mass, 0.0))
    topology_factor = _pulsed_topology_lifetime_factor(
        features.target_topology) * lifetime_multiplier
    disassembly_time = topology_factor * r0 / max(sound0, 1.0)
    bohm_diffusivity0 = T0_J / max(16.0 * e * B0, 1.0e-30)
    bohm_transport_time = r0^2 / max(bohm_diffusivity0, 1.0e-30)
    target_lifetime = min(disassembly_time, bohm_transport_time)
    resistivity = 1.03e-4 * 10.0 /
        max((1000.0 * T0_keV)^1.5, 1.0e-30)
    magnetic_reynolds = mu0 * r0 * velocity / max(resistivity, 1.0e-30)

    stored0 = 1.5 * pressure0 * volume0
    stored_stag = 1.5 * pressure_stag * volume_stag
    required_compression_work = max(0.0, stored_stag - stored0)
    liner_kinetic = 0.5 * features.liner_mass_kg * velocity^2
    formation_grid = stored0 / max(features.formation_efficiency, 1.0e-6)
    preheat_grid = features.preheat_energy_J /
        max(contract.outer.base.heating_wall_plug_efficiency, 1.0e-6)
    driver_grid = liner_kinetic / max(features.driver_efficiency, 1.0e-6)
    recovered_electric = recovery * liner_kinetic

    dwell_time = min(0.25 * implosion_time,
        topology_factor * rstag / max(sound_stag, 1.0))
    reactivity = _dt_reactivity_m3_s(Tstag_keV)
    valid_reactivity = isfinite(reactivity) && Tstag_keV > 0.0
    fusion_power_density = valid_reactivity ?
        0.25 * density_stag^2 * reactivity * 17.6e6 * e : 0.0
    unbounded_yield = fusion_power_density * volume_stag * dwell_time
    maximum_fuel_yield = 0.5 * density0 * volume0 * 17.6e6 * e
    fusion_yield = min(unbounded_yield, 0.30 * maximum_fuel_yield) * retention
    burn_fraction = fusion_yield / max(maximum_fuel_yield, 1.0)
    scientific_gain = fusion_yield /
        max(liner_kinetic + stored0 + features.preheat_energy_J, 1.0)
    net_electric_per_shot = contract.outer.base.thermal_conversion_efficiency *
        fusion_yield - formation_grid - preheat_grid - driver_grid +
        recovered_electric
    average_net_electric = repetition * features.availability *
        net_electric_per_shot - contract.outer.base.fixed_balance_of_plant_load_W

    wall_area = 2.0 * pi * contract.outer.outer_radial_extent_m *
        (2.0 * contract.outer.outer_axial_half_extent_m) +
        2.0 * pi * contract.outer.outer_radial_extent_m^2
    neutron_wall_load = 0.80 * fusion_yield * repetition *
        features.availability / max(wall_area, 1.0e-30)
    chamber_heat = (0.20 * fusion_yield + max(0.0,
        liner_kinetic - recovered_electric)) * repetition *
        features.availability / max(wall_area, 1.0e-30)
    mass_throughput = features.liner_mass_kg * repetition *
        features.availability
    throughput_limit = features.liner_kind == "solid_conducting_liner" ?
        contract.maximum_solid_liner_throughput_kg_s :
        contract.maximum_plasma_liner_throughput_kg_s
    outer_margin = min(contract.outer.outer_radial_extent_m - r0,
        contract.outer.outer_axial_half_extent_m -
            (features.compression_geometry == "spherical" ? r0 : half_length))
    margins = Dict{String,Float64}(
        "convergence_domain" => min((C - 2.0) / 2.0,
            (contract.maximum_convergence_ratio - C) /
            contract.maximum_convergence_ratio),
        "stagnation_temperature_domain" => min((Tstag_keV - 5.0) / 5.0,
            (30.0 - Tstag_keV) / 30.0),
        "target_lifetime_ordering" => target_lifetime /
            max(implosion_time, 1.0e-30) /
            contract.minimum_target_lifetime_to_implosion_ratio - 1.0,
        "transport_ordering" => bohm_transport_time /
            max(implosion_time, 1.0e-30) /
            contract.minimum_transport_to_implosion_ratio - 1.0,
        "magnetic_reynolds" => magnetic_reynolds /
            contract.minimum_magnetic_reynolds_number - 1.0,
        "compression_work_authority" => liner_kinetic /
            max(required_compression_work, 1.0) - 1.0,
        "scientific_gain" => scientific_gain - 1.0,
        "average_net_electric" => average_net_electric /
            max(contract.outer.base.fixed_balance_of_plant_load_W, 1.0),
        "repetition_rate" => (contract.maximum_repetition_rate_Hz - repetition) /
            contract.maximum_repetition_rate_Hz,
        "energy_recovery" => (contract.maximum_recovery_fraction - recovery) /
            max(contract.maximum_recovery_fraction, 1.0e-9),
        "liner_mass_throughput" => (throughput_limit - mass_throughput) /
            throughput_limit,
        "neutron_wall_load" =>
            (contract.outer.base.maximum_neutron_wall_load_W_m2 -
                neutron_wall_load) /
            contract.outer.base.maximum_neutron_wall_load_W_m2,
        "average_chamber_heat_flux" =>
            (contract.maximum_average_chamber_heat_flux_W_m2 - chamber_heat) /
            contract.maximum_average_chamber_heat_flux_W_m2,
        "outer_envelope" => outer_margin /
            max(contract.outer.outer_radial_extent_m, 1.0e-9),
        "seed_conductor_field" =>
            (contract.outer.base.peak_conductor_field_limit_T - B0) /
            contract.outer.base.peak_conductor_field_limit_T,
    )
    physics_ids = ("convergence_domain", "stagnation_temperature_domain",
        "target_lifetime_ordering", "transport_ordering", "magnetic_reynolds",
        "compression_work_authority", "scientific_gain")
    engineering_ids = ("average_net_electric", "repetition_rate",
        "energy_recovery", "liner_mass_throughput", "neutron_wall_load",
        "average_chamber_heat_flux", "outer_envelope", "seed_conductor_field")
    physics_gate = valid_reactivity && all(margins[id] >= 0.0 for id in physics_ids)
    engineering_gate = all(margins[id] >= 0.0 for id in engineering_ids)
    return Dict{String,Any}(
        "target_topology" => features.target_topology,
        "liner_kind" => features.liner_kind,
        "compression_geometry" => features.compression_geometry,
        "initial_target_radius_m" => r0,
        "stagnation_radius_m" => rstag,
        "initial_target_volume_m3" => volume0,
        "stagnation_volume_m3" => volume_stag,
        "convergence_ratio" => C,
        "initial_temperature_keV" => T0_keV,
        "stagnation_temperature_keV" => Tstag_keV,
        "initial_density_m3" => density0,
        "stagnation_density_m3" => density_stag,
        "initial_seed_field_T" => B0,
        "compressed_field_proxy_T" => Bstag,
        "implosion_time_s" => implosion_time,
        "target_lifetime_s" => target_lifetime,
        "bohm_transport_time_s" => bohm_transport_time,
        "target_lifetime_to_implosion_ratio" => target_lifetime /
            max(implosion_time, 1.0e-30),
        "transport_to_implosion_ratio" => bohm_transport_time /
            max(implosion_time, 1.0e-30),
        "magnetic_reynolds_number" => magnetic_reynolds,
        "liner_kinetic_energy_J" => liner_kinetic,
        "required_compression_work_J" => required_compression_work,
        "formation_grid_energy_J" => formation_grid,
        "preheat_grid_energy_J" => preheat_grid,
        "driver_grid_energy_J" => driver_grid,
        "recovered_electric_energy_J" => recovered_electric,
        "fusion_yield_J" => fusion_yield,
        "fuel_burn_fraction_proxy" => burn_fraction,
        "scientific_gain_proxy" => scientific_gain,
        "net_electric_energy_per_shot_J" => net_electric_per_shot,
        "repetition_rate_Hz" => repetition,
        "availability" => features.availability,
        "average_net_electric_power_W" => average_net_electric,
        "liner_mass_throughput_kg_s" => mass_throughput,
        "neutron_wall_load_W_m2" => neutron_wall_load,
        "average_chamber_heat_flux_W_m2" => chamber_heat,
        "physics_gate_passed" => physics_gate,
        "engineering_gate_passed" => engineering_gate,
        "margins" => margins,
        "minimum_normalized_margin" => minimum(values(margins)),
    )
end

function _pulsed_graph_errors(genome::Genome,
        contract::PulsedCompressionContractV1, features)
    errors = copy(validate_genome(genome).errors)
    length(genome.compression_systems) == 1 || push!(errors,
        "exactly one compression system is required")
    length(genome.exhaust.region_ids) == 1 || push!(errors,
        "exactly one pulsed chamber region is required")
    for (name, expected, unit) in (
            ("screen_outer_radial_extent", contract.outer.outer_radial_extent_m, "m"),
            ("screen_outer_axial_half_extent", contract.outer.outer_axial_half_extent_m, "m"),
            ("screen_plasma_field", contract.outer.plasma_field_T, "T"))
        value = get(genome.mission.targets, name, nothing)
        (value !== nothing && value.unit == unit &&
            isapprox(value.value, expected; rtol = 1.0e-9, atol = 1.0e-9)) ||
            push!(errors, "$name is inconsistent with pulsed outer contract")
    end
    target_ids = Set(String[id for system in genome.compression_systems
        for id in system.target_region_ids])
    isempty(target_ids) && push!(errors, "compression target edge is missing")
    features.initial_radius_m > 0.0 || push!(errors,
        "initial target radius must be positive")
    return sort!(unique(errors))
end

function _pulsed_robustness(genome::Genome,
        contract::PulsedCompressionContractV1, features)
    rng = MersenneTwister(contract.outer.base.robustness_seed + 6)
    records = Dict{String,Any}[]
    pass_count = 0
    worst_margin = Inf
    for sample in 1:contract.outer.base.robustness_samples
        values = _pulsed_nominal(genome, contract, features;
            field_multiplier = 1.0 + 0.02 * (2.0 * rand(rng) - 1.0),
            convergence_multiplier = 1.0 + 0.05 * (2.0 * rand(rng) - 1.0),
            velocity_multiplier = 1.0 + 0.05 * (2.0 * rand(rng) - 1.0),
            retention_multiplier = 1.0 + 0.20 * (2.0 * rand(rng) - 1.0),
            repetition_multiplier = 1.0 + 0.10 * (2.0 * rand(rng) - 1.0),
            recovery_delta = 0.05 * (2.0 * rand(rng) - 1.0),
            lifetime_multiplier = 1.0 + 0.20 * (2.0 * rand(rng) - 1.0))
        passed = values["physics_gate_passed"] === true &&
            values["engineering_gate_passed"] === true
        passed && (pass_count += 1)
        worst_margin = min(worst_margin,
            Float64(values["minimum_normalized_margin"]))
        push!(records, Dict("sample" => sample, "passed" => passed,
            "minimum_normalized_margin" => values["minimum_normalized_margin"]))
    end
    fraction = pass_count / contract.outer.base.robustness_samples
    return Dict{String,Any}(
        "sample_count" => contract.outer.base.robustness_samples,
        "common_random_seed" => contract.outer.base.robustness_seed + 6,
        "pass_count" => pass_count,
        "pass_fraction" => fraction,
        "required_pass_fraction" =>
            contract.outer.base.robustness_required_pass_fraction,
        "gate_passed" => fraction >=
            contract.outer.base.robustness_required_pass_fraction,
        "worst_minimum_normalized_margin" => worst_margin,
        "records" => records,
    )
end

function _pulsed_compression_result(evaluator::PulsedCompressionScreenV1,
        genome::Genome)
    features = _pulsed_features(genome)
    errors = _pulsed_graph_errors(genome, evaluator.contract, features)
    nominal = _pulsed_nominal(genome, evaluator.contract, features)
    robustness = isempty(errors) && nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true ?
        _pulsed_robustness(genome, evaluator.contract, features) :
        Dict{String,Any}("sample_count" => 0, "pass_count" => 0,
            "pass_fraction" => 0.0, "required_pass_fraction" =>
                evaluator.contract.outer.base.robustness_required_pass_fraction,
            "gate_passed" => false,
            "worst_minimum_normalized_margin" =>
                nominal["minimum_normalized_margin"],
            "records" => Dict{String,Any}[],
            "skipped_due_nominal_gate_failure" => true)
    gates = Dict{String,Bool}(
        "variable_topology_representation" => isempty(errors),
        "timescale_and_flux_ordering" => nominal["physics_gate_passed"],
        "shot_energy_and_average_power_closure" =>
            nominal["engineering_gate_passed"],
        "same_outer_envelope_contract" => true,
        "cheap_robustness_screen" => robustness["gate_passed"],
    )
    result = Dict{String,Any}(
        "contract" => _pulsed_contract_dict(evaluator.contract),
        "contract_hash" => canonical_hash(_pulsed_contract_dict(evaluator.contract)),
        "features" => Dict(String(key) => value for (key, value) in
            pairs(features)),
        "topology_graph_errors" => errors,
        "nominal" => nominal,
        "robustness" => robustness,
        "gates" => gates,
        "all_five_gates_passed" => all(values(gates)),
        "positive_average_net_power_closure_passed" =>
            nominal["average_net_electric_power_W"] > 0.0,
        "classification" => all(values(gates)) ?
            "pulsed_screen_survivor_pending_radiation_mhd" :
            "rejected_or_unresolved_at_pulsed_fidelity_0",
        "claim_boundary" => _PULSED_SCREEN_CLAIM_BOUNDARY,
    )
    result["result_hash"] = canonical_hash(result)
    return result
end

function run_evaluator(evaluator::PulsedCompressionScreenV1, genome::Genome;
        kwargs...)
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return _non_applicable_bundle(evaluator_spec(evaluator), genome,
        reason)
    result = _pulsed_compression_result(evaluator, genome)
    run_hash = canonical_hash(Dict("input_hash" => genome.physics_hash,
        "result_hash" => result["result_hash"]))
    metric = MetricResult("pulsed_compression_five_gate_passed",
        result["all_five_gates_passed"];
        fidelity = 0, applicability = reason,
        status = result["all_five_gates_passed"] ? :pass : :fail,
        solver_name = "pulsed_compression_screen_v1", solver_version = "1.0.0",
        input_hash = genome.physics_hash, run_hash = run_hash,
        source_basis = _PULSED_SCREEN_SOURCE_BASIS,
        warnings = [_PULSED_SCREEN_CLAIM_BOUNDARY])
    return EvaluationBundle("pulsed_compression_screen_v1", genome.design_id,
        genome.family, 0, result["all_five_gates_passed"] ? :pass : :fail,
        [metric], [_PULSED_SCREEN_CLAIM_BOUNDARY], genome.physics_hash,
        run_hash, _PULSED_SCREEN_CLAIM_BOUNDARY)
end
