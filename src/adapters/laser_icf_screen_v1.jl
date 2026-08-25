const _LICFV15_SOURCE_BASIS = String[
    "nif_target_gain_unity_2024",
    "nif_burning_plasma_2022",
    "nif_indirect_drive_basis_lindl_2004",
    "direct_drive_review_campbell_2015",
    "fast_ignition_tabak_1994",
    "ife_assessment_nas_2013",
]

const _LICFV15_CLAIM_BOUNDARY =
    "Fidelity-0 laser-ICF pulse and plant-ledger rejection screen. Target gain is " *
    "kept distinct from driver wall-plug gain and average net electricity. Candidate " *
    "target gain, repetition, availability, driver efficiency, target-factory load, " *
    "injection, clearing, and component life are searched hypotheses, not experimental " *
    "credits. The NIF branch is a bounded single-shot target-gain anchor and can never " *
    "promote. Net-electric candidates cannot pass without separate target-gain, " *
    "repeat-rate driver, target-factory, and chamber-lifetime evidence. Passing this " *
    "screen would establish neither ignition hydrodynamics, mix/LPI control, target " *
    "fabricability, tritium breeding, materials lifetime, novelty, nor a reactor."

"Versioned append-only family package; the sealed base registry is not modified."
function laser_icf_family_extension_v15()
    spec = FamilySpec("inertial_confinement_fusion",
        Set(["not_applicable_inertial"]), Set(["axisymmetric", "none"]),
        "explicit capsule, driver, beam-path, target-factory, and pulsed-chamber graph",
        ["icf_radiation_hydrodynamics", "repeat_rate_laser_driver",
            "target_factory_and_injection", "pulsed_chamber_clearing"],
        "screening_only")
    return FamilyExtensionPackage("laser_icf_v15", "1.0.0",
        "laser_icf_extension_v15", [spec], _LICFV15_SOURCE_BASIS,
        _LICFV15_CLAIM_BOUNDARY)
end

function laser_icf_family_registry_v15()
    registry = FamilyExtensionRegistry()
    register_extension!(registry, laser_icf_family_extension_v15())
    return effective_family_registry(registry)
end

function _licfv15_semantic_errors(genome::Genome)
    errors = copy(validate_genome(genome).errors)
    genome.family == "inertial_confinement_fusion" || push!(errors,
        "laser ICF overlay requires inertial_confinement_fusion family")
    genome.mission.operating_mode == "pulsed" || push!(errors,
        "inertial confinement fusion requires pulsed operating mode")
    genome.topology.field_line_class == "not_applicable_inertial" ||
        push!(errors, "laser ICF requires not_applicable_inertial topology")
    genome.topology.rotation_transform_sources == ["not_applicable"] ||
        push!(errors, "laser ICF transform source must be only not_applicable")
    length(genome.compression_systems) == 1 || push!(errors,
        "laser ICF requires exactly one explicit laser drive system")
    genome.exhaust.kind == "pulsed_chamber" || push!(errors,
        "laser ICF requires a pulsed chamber model")
    append!(errors, validate_family(laser_icf_family_registry_v15(),
        genome).errors)
    return sort!(unique(errors))
end

"A declared pulsed ICF comparison envelope; numerical limits are screening contracts."
struct LaserICFPulsedContractV1
    id::String
    chamber_radius_m::Float64
    chamber_half_height_m::Float64
    maximum_neutron_wall_load_W_m2::Float64
    maximum_average_chamber_heat_flux_W_m2::Float64
    thermal_conversion_efficiency::Float64
    fixed_balance_of_plant_load_W::Float64
    robustness_samples::Int
    robustness_required_pass_fraction::Float64
    robustness_seed::Int

    function LaserICFPulsedContractV1(id::AbstractString,
            chamber_radius_m::Real, chamber_half_height_m::Real;
            maximum_neutron_wall_load_W_m2::Real = 5.0e6,
            maximum_average_chamber_heat_flux_W_m2::Real = 10.0e6,
            thermal_conversion_efficiency::Real = 0.40,
            fixed_balance_of_plant_load_W::Real = 30.0e6,
            robustness_samples::Integer = 64,
            robustness_required_pass_fraction::Real = 0.90,
            robustness_seed::Integer = 20260815)
        all(x -> x > 0.0, (chamber_radius_m, chamber_half_height_m,
            maximum_neutron_wall_load_W_m2,
            maximum_average_chamber_heat_flux_W_m2,
            fixed_balance_of_plant_load_W)) || throw(ArgumentError(
            "laser ICF contract dimensions and limits must be positive"))
        0.0 < thermal_conversion_efficiency <= 1.0 || throw(ArgumentError(
            "thermal conversion efficiency must be in (0,1]"))
        robustness_samples > 0 || throw(ArgumentError(
            "robustness_samples must be positive"))
        0.0 <= robustness_required_pass_fraction <= 1.0 || throw(ArgumentError(
            "robustness pass fraction must be in [0,1]"))
        return new(String(id), Float64(chamber_radius_m),
            Float64(chamber_half_height_m),
            Float64(maximum_neutron_wall_load_W_m2),
            Float64(maximum_average_chamber_heat_flux_W_m2),
            Float64(thermal_conversion_efficiency),
            Float64(fixed_balance_of_plant_load_W), Int(robustness_samples),
            Float64(robustness_required_pass_fraction), Int(robustness_seed))
    end
end

function laser_icf_pulsed_contracts_v1()
    return LaserICFPulsedContractV1[
        LaserICFPulsedContractV1("laser_icf_compact_chamber_v1", 5.0, 5.0),
        LaserICFPulsedContractV1("laser_icf_reference_chamber_v1", 8.0, 8.0),
        LaserICFPulsedContractV1("laser_icf_large_chamber_v1", 12.0, 12.0),
    ]
end

function _laser_icf_contract_dict(contract::LaserICFPulsedContractV1)
    return Dict{String,Any}(
        "id" => contract.id,
        "declared_screening_assumptions_not_material_truth" => Dict(
            "chamber_radius_m" => contract.chamber_radius_m,
            "chamber_half_height_m" => contract.chamber_half_height_m,
            "maximum_neutron_wall_load_W_m2" =>
                contract.maximum_neutron_wall_load_W_m2,
            "maximum_average_chamber_heat_flux_W_m2" =>
                contract.maximum_average_chamber_heat_flux_W_m2,
            "thermal_conversion_efficiency" =>
                contract.thermal_conversion_efficiency,
            "fixed_balance_of_plant_load_W" =>
                contract.fixed_balance_of_plant_load_W),
        "robustness_samples" => contract.robustness_samples,
        "robustness_required_pass_fraction" =>
            contract.robustness_required_pass_fraction,
        "robustness_seed" => contract.robustness_seed,
        "same_envelope_policy" =>
            "all drive pathways use this identical chamber and plant contract")
end

struct LaserICFScreenV1 <: AbstractEvaluator
    contract::LaserICFPulsedContractV1
    allowed_contract_hashes::Set{String}
end

function LaserICFScreenV1(contract::LaserICFPulsedContractV1;
        allowed_contracts::Vector{LaserICFPulsedContractV1} =
            laser_icf_pulsed_contracts_v1())
    return LaserICFScreenV1(contract, Set(canonical_hash(
        _laser_icf_contract_dict(item)) for item in allowed_contracts))
end

function evaluator_spec(::LaserICFScreenV1)
    return EvaluatorSpec("laser_icf_screen_v1", "1.0.0",
        ["inertial_confinement_fusion"], 0,
        Dict("icf_radiation_hydrodynamics" => :proxy,
            "laser_plasma_interaction" => :proxy,
            "fast_ignition_transport" => :proxy,
            "repeat_rate_laser_driver" => :proxy,
            "target_factory_and_injection" => :proxy,
            "pulsed_chamber_clearing" => :proxy,
            "first_wall_lifetime" => :proxy), _LICFV15_CLAIM_BOUNDARY)
end

function evaluator_applicability(evaluator::LaserICFScreenV1, genome::Genome)
    genome.family == "inertial_confinement_fusion" || return false,
        "laser ICF screen only covers inertial_confinement_fusion"
    genome.mission.fuel == "D-T" || return false,
        "laser ICF screen is restricted to D-T"
    errors = _licfv15_semantic_errors(genome)
    isempty(errors) || return false, join(errors, "; ")
    return true, "laser ICF pulsed contract $(evaluator.contract.id)"
end

_licfv15_system(genome::Genome) = only(genome.compression_systems)

function _licfv15_parameter(system::CompressionSystem, name::String,
        unit::String, default = nothing)
    value = get(system.parameters, name, nothing)
    value === nothing && default !== nothing && return Float64(default)
    value === nothing && throw(ArgumentError(
        "compression_systems.$(name) is required"))
    value.unit == unit || throw(ArgumentError(
        "laser ICF parameter $name must normalize to $unit"))
    return value.value
end

function _licfv15_features(genome::Genome)
    system = _licfv15_system(genome)
    return Dict{String,Float64}(
        "anchor_only" => _licfv15_parameter(system, "anchor_only", "1"),
        "on_target_energy_J" => _licfv15_parameter(system,
            "on_target_energy", "J"),
        "target_gain_assumption" => _licfv15_parameter(system,
            "target_gain_assumption", "1"),
        "driver_wall_plug_efficiency" => _licfv15_parameter(system,
            "driver_wall_plug_efficiency", "1"),
        "repetition_rate_Hz" => _licfv15_parameter(system,
            "repetition_rate", "Hz"),
        "availability" => _licfv15_parameter(system, "availability", "1"),
        "dt_fuel_mass_kg" => _licfv15_parameter(system, "dt_fuel_mass", "kg"),
        "burn_fraction_assumption" => _licfv15_parameter(system,
            "burn_fraction_assumption", "1"),
        "target_factory_energy_J" => _licfv15_parameter(system,
            "target_factory_energy_per_shot", "J"),
        "target_injection_speed_m_s" => _licfv15_parameter(system,
            "target_injection_speed", "m/s"),
        "chamber_clearing_speed_m_s" => _licfv15_parameter(system,
            "chamber_clearing_speed", "m/s"),
        "neutron_energy_fraction" => _licfv15_parameter(system,
            "neutron_energy_fraction", "1"),
        "path_coupling_assumption" => _licfv15_parameter(system,
            "path_coupling_assumption", "1"),
        "fast_ignitor_energy_fraction" => _licfv15_parameter(system,
            "fast_ignitor_energy_fraction", "1"),
        "illumination_quality_assumption" => _licfv15_parameter(system,
            "illumination_quality_assumption", "1"),
        "port_area_fraction" => _licfv15_parameter(system,
            "port_area_fraction", "1"),
        "target_factory_yield_assumption" => _licfv15_parameter(system,
            "target_factory_yield_assumption", "1"),
        "driver_lifetime_shots_assumption" => _licfv15_parameter(system,
            "driver_lifetime_shots_assumption", "1"),
        "first_wall_lifetime_shots_assumption" => _licfv15_parameter(system,
            "first_wall_lifetime_shots_assumption", "1"))
end

_licfv15_drive_path(genome::Genome) = _licfv15_system(genome).kind

function _licfv15_science_anchor_nominal()
    margins = Dict{String,Float64}(
        "reported_target_gain_larger_than_unity" => 0.0,
        "target_gain_not_wall_plug_gain" => 1.0,
        "single_shot_evidence_boundary" => 1.0,
        "normalized_energy_conservation" => 0.0)
    return Dict{String,Any}(
        "mission_scope" => "single_shot_target_gain_science_anchor",
        "target_gain_lower_bound" => 1.0,
        "absolute_shot_energy_imported_from_memory" => false,
        "wall_plug_or_net_electric_credit" => false,
        "conditional_physics_gate_passed" => true,
        "physics_gate_passed" => true,
        "conditional_engineering_gate_passed" => true,
        "engineering_gate_passed" => true,
        "average_net_electric_power_W" => 0.0,
        "margins" => margins,
        "minimum_normalized_margin" => minimum(Base.values(margins)))
end

function _licfv15_candidate_nominal(path::String,
        protection::String, contract::LaserICFPulsedContractV1,
        f::AbstractDict; energy_multiplier::Float64 = 1.0,
        gain_multiplier::Float64 = 1.0,
        efficiency_multiplier::Float64 = 1.0,
        repetition_multiplier::Float64 = 1.0,
        availability_multiplier::Float64 = 1.0,
        injection_multiplier::Float64 = 1.0,
        clearing_multiplier::Float64 = 1.0,
        coupling_multiplier::Float64 = 1.0)
    e_target = f["on_target_energy_J"] * energy_multiplier
    q_target = f["target_gain_assumption"] * gain_multiplier
    eta_driver = clamp(f["driver_wall_plug_efficiency"] *
        efficiency_multiplier, 1.0e-6, 1.0)
    repetition = f["repetition_rate_Hz"] * repetition_multiplier
    availability = clamp(f["availability"] * availability_multiplier, 0.0, 1.0)
    effective_rate = repetition * availability
    e_fusion = e_target * q_target
    dt_specific_energy_J_kg = 3.39e14
    fuel_energy_ceiling = f["dt_fuel_mass_kg"] *
        f["burn_fraction_assumption"] * dt_specific_energy_J_kg
    driver_grid_energy = e_target / eta_driver
    target_factory_grid_energy = f["target_factory_energy_J"] /
        max(f["target_factory_yield_assumption"], 1.0e-6)
    gross_electric_energy = contract.thermal_conversion_efficiency * e_fusion
    average_net = effective_rate * (gross_electric_energy -
        driver_grid_energy - target_factory_grid_energy) -
        contract.fixed_balance_of_plant_load_W
    area = 4.0pi * contract.chamber_radius_m^2 *
        (1.0 - f["port_area_fraction"])
    neutron_load = f["neutron_energy_fraction"] * e_fusion *
        effective_rate / max(area, 1.0e-9)
    chamber_heat = (1.0 - f["neutron_energy_fraction"]) * e_fusion *
        effective_rate / max(area, 1.0e-9)
    injection_time = contract.chamber_radius_m /
        max(f["target_injection_speed_m_s"] * injection_multiplier, 1.0e-9)
    clearing_time = contract.chamber_radius_m /
        max(f["chamber_clearing_speed_m_s"] * clearing_multiplier, 1.0e-9)
    period = 1.0 / max(repetition, 1.0e-9)
    coupling = f["path_coupling_assumption"] * coupling_multiplier
    coupling_floor = path == "laser_indirect_drive" ? 0.03 :
        path == "laser_direct_drive" ? 0.10 : 0.02
    path_consistency = path == "laser_fast_ignition" ? min(
        (f["fast_ignitor_energy_fraction"] - 0.02) / 0.02,
        (0.60 - f["fast_ignitor_energy_fraction"]) / 0.10) : 1.0
    protection_credit = protection == "liquid_protected" ? 1.30 :
        protection == "replaceable_modular" ? 1.10 : 1.0
    required_annual_shots = effective_rate * 365.25 * 24.0 * 3600.0
    margins = Dict{String,Float64}(
        "fuel_inventory_energy_conservation" =>
            (fuel_energy_ceiling - e_fusion) / max(fuel_energy_ceiling, 1.0),
        "path_coupling_hypothesis_domain" => (coupling - coupling_floor) /
            coupling_floor,
        "illumination_quality_hypothesis_domain" =>
            (f["illumination_quality_assumption"] - 0.80) / 0.20,
        "dual_pulse_fast_ignition_consistency" => path_consistency,
        "target_gain_experimental_validation" => -1.0,
        "driver_wall_plug_and_repeat_rate_validation" => -1.0,
        "target_factory_throughput_and_yield_validation" => -1.0,
        "first_wall_and_final_optics_lifetime_validation" => -1.0,
        "target_injection_timing" => (period - injection_time) / period,
        "chamber_clearing_timing" => (period - clearing_time) / period,
        "neutron_wall_load" =>
            (contract.maximum_neutron_wall_load_W_m2 * protection_credit -
                neutron_load) /
            (contract.maximum_neutron_wall_load_W_m2 * protection_credit),
        "average_chamber_heat_flux" =>
            (contract.maximum_average_chamber_heat_flux_W_m2 *
                protection_credit - chamber_heat) /
            (contract.maximum_average_chamber_heat_flux_W_m2 * protection_credit),
        "driver_lifetime_hypothesis" =>
            (f["driver_lifetime_shots_assumption"] - required_annual_shots) /
            max(required_annual_shots, 1.0),
        "first_wall_lifetime_hypothesis" =>
            (f["first_wall_lifetime_shots_assumption"] -
                required_annual_shots) / max(required_annual_shots, 1.0),
        "port_area_fraction" => (0.30 - f["port_area_fraction"]) / 0.30,
        "conditional_net_electric_power" => average_net /
            contract.fixed_balance_of_plant_load_W)
    conditional_physics_ids = ["fuel_inventory_energy_conservation",
        "path_coupling_hypothesis_domain",
        "illumination_quality_hypothesis_domain",
        "dual_pulse_fast_ignition_consistency"]
    physics_ids = [conditional_physics_ids...,
        "target_gain_experimental_validation"]
    conditional_engineering_ids = ["target_injection_timing",
        "chamber_clearing_timing", "neutron_wall_load",
        "average_chamber_heat_flux", "driver_lifetime_hypothesis",
        "first_wall_lifetime_hypothesis", "port_area_fraction",
        "conditional_net_electric_power"]
    engineering_ids = [conditional_engineering_ids...,
        "driver_wall_plug_and_repeat_rate_validation",
        "target_factory_throughput_and_yield_validation",
        "first_wall_and_final_optics_lifetime_validation"]
    return Dict{String,Any}(
        "mission_scope" => "conditional_net_electric_hypothesis",
        "drive_path" => path, "chamber_protection" => protection,
        "on_target_energy_J" => e_target,
        "target_gain_assumption" => q_target,
        "fusion_yield_assumption_J" => e_fusion,
        "dt_fuel_energy_ceiling_J" => fuel_energy_ceiling,
        "driver_grid_energy_per_shot_J" => driver_grid_energy,
        "target_factory_grid_energy_per_shot_J" => target_factory_grid_energy,
        "gross_electric_energy_per_shot_J" => gross_electric_energy,
        "repetition_rate_Hz" => repetition, "availability" => availability,
        "effective_shot_rate_Hz" => effective_rate,
        "average_net_electric_power_W" => average_net,
        "first_wall_area_after_ports_m2" => area,
        "neutron_wall_load_W_m2" => neutron_load,
        "average_chamber_heat_flux_W_m2" => chamber_heat,
        "target_injection_time_s" => injection_time,
        "chamber_clearing_time_s" => clearing_time,
        "shot_period_s" => period,
        "annual_full_power_shot_count" => required_annual_shots,
        "searched_quantities_are_hypotheses" => true,
        "conditional_physics_gate_passed" => all(margins[id] >= 0.0
            for id in conditional_physics_ids),
        "physics_gate_passed" => all(margins[id] >= 0.0 for id in physics_ids),
        "conditional_engineering_gate_passed" => all(margins[id] >= 0.0
            for id in conditional_engineering_ids),
        "engineering_gate_passed" => all(margins[id] >= 0.0
            for id in engineering_ids),
        "margins" => margins,
        "minimum_normalized_margin" => minimum(Base.values(margins)))
end

function _licfv15_graph_errors(genome::Genome,
        contract::LaserICFPulsedContractV1, allowed_hashes::Set{String})
    errors = _licfv15_semantic_errors(genome)
    canonical_hash(_laser_icf_contract_dict(contract)) in allowed_hashes ||
        push!(errors, "undeclared laser ICF comparison contract")
    length(genome.compression_systems) == 1 || push!(errors,
        "exactly one laser drive system is required")
    length(genome.exhaust.region_ids) == 1 || push!(errors,
        "exactly one pulsed chamber exhaust region is required")
    for (name, expected, unit) in (
            ("screen_chamber_radius", contract.chamber_radius_m, "m"),
            ("screen_chamber_half_height", contract.chamber_half_height_m, "m"))
        value = get(genome.mission.targets, name, nothing)
        (value !== nothing && value.unit == unit &&
            isapprox(value.value, expected; rtol = 1.0e-12, atol = 1.0e-12)) ||
            push!(errors, "$name is inconsistent with the ICF contract")
    end
    return sort!(unique(errors))
end

function _licfv15_robustness(path::String, protection::String,
        contract::LaserICFPulsedContractV1, features::AbstractDict)
    rng = MersenneTwister(contract.robustness_seed +
        sum(Int(codeunit(path, i)) for i in eachindex(codeunits(path))))
    pass_count = 0
    worst = Inf
    records = Dict{String,Any}[]
    for sample in 1:contract.robustness_samples
        nominal = _licfv15_candidate_nominal(path, protection, contract, features;
            energy_multiplier = 1.0 + 0.05 * (2rand(rng) - 1.0),
            gain_multiplier = 1.0 + 0.20 * (2rand(rng) - 1.0),
            efficiency_multiplier = 1.0 + 0.10 * (2rand(rng) - 1.0),
            repetition_multiplier = 1.0 + 0.10 * (2rand(rng) - 1.0),
            availability_multiplier = 1.0 + 0.05 * (2rand(rng) - 1.0),
            injection_multiplier = 1.0 + 0.10 * (2rand(rng) - 1.0),
            clearing_multiplier = 1.0 + 0.20 * (2rand(rng) - 1.0),
            coupling_multiplier = 1.0 + 0.20 * (2rand(rng) - 1.0))
        passed = nominal["conditional_physics_gate_passed"] === true &&
            nominal["conditional_engineering_gate_passed"] === true
        passed && (pass_count += 1)
        evidence_ids = Set(["target_gain_experimental_validation",
            "driver_wall_plug_and_repeat_rate_validation",
            "target_factory_throughput_and_yield_validation",
            "first_wall_and_final_optics_lifetime_validation"])
        conditional_margin = minimum(Float64(value) for (id, value) in
            nominal["margins"] if !(id in evidence_ids))
        worst = min(worst, conditional_margin)
        push!(records, Dict("sample" => sample, "passed" => passed,
            "minimum_conditional_normalized_margin" => conditional_margin))
    end
    fraction = pass_count / contract.robustness_samples
    return Dict{String,Any}(
        "sample_count" => contract.robustness_samples,
        "pass_count" => pass_count, "pass_fraction" => fraction,
        "required_pass_fraction" => contract.robustness_required_pass_fraction,
        "gate_passed" => fraction >= contract.robustness_required_pass_fraction,
        "conditional_hypothesis_robustness_only" => true,
        "worst_minimum_conditional_normalized_margin" => worst,
        "records" => records)
end

function _laser_icf_result(evaluator::LaserICFScreenV1, genome::Genome)
    features = _licfv15_features(genome)
    anchor = features["anchor_only"] > 0.5
    path = _licfv15_drive_path(genome)
    protection = genome.exhaust.evaluation_requirements[1]
    errors = _licfv15_graph_errors(genome, evaluator.contract,
        evaluator.allowed_contract_hashes)
    nominal = anchor ? _licfv15_science_anchor_nominal() :
        _licfv15_candidate_nominal(path, protection, evaluator.contract, features)
    robustness = if anchor && isempty(errors)
        Dict{String,Any}("sample_count" => 0, "pass_count" => 0,
            "pass_fraction" => 1.0, "required_pass_fraction" => 1.0,
            "gate_passed" => true,
            "experimental_evidence_is_not_perturbed_as_a_design_hypothesis" => true,
            "records" => Dict{String,Any}[])
    elseif isempty(errors) &&
            nominal["conditional_physics_gate_passed"] === true &&
            nominal["conditional_engineering_gate_passed"] === true
        _licfv15_robustness(path, protection, evaluator.contract, features)
    else
        Dict{String,Any}("sample_count" => 0, "pass_count" => 0,
            "pass_fraction" => 0.0,
            "required_pass_fraction" =>
                evaluator.contract.robustness_required_pass_fraction,
            "gate_passed" => false,
            "worst_minimum_normalized_margin" =>
                nominal["minimum_normalized_margin"],
            "skipped_due_conditional_nominal_failure" => true,
            "records" => Dict{String,Any}[])
    end
    gates = Dict{String,Bool}(
        "variable_topology_representation" => isempty(errors),
        "first_principles_pulse_and_evidence_separation" =>
            nominal["physics_gate_passed"],
        "minimal_engineering_closure" => nominal["engineering_gate_passed"],
        "same_pulsed_outer_envelope_contract" => true,
        "cheap_robustness_screen" => robustness["gate_passed"])
    all_five = all(Base.values(gates))
    result = Dict{String,Any}(
        "contract" => _laser_icf_contract_dict(evaluator.contract),
        "contract_hash" => canonical_hash(
            _laser_icf_contract_dict(evaluator.contract)),
        "source_basis" => _LICFV15_SOURCE_BASIS,
        "anchor_only" => anchor, "promotion_eligible" => !anchor,
        "topology_graph_errors" => errors,
        "features" => features, "nominal" => nominal,
        "robustness" => robustness, "gates" => gates,
        "all_five_gates_passed" => all_five,
        "positive_average_net_power_closure_passed" => !anchor &&
            nominal["average_net_electric_power_W"] > 0.0,
        "promotable" => !anchor && all_five &&
            nominal["average_net_electric_power_W"] > 0.0,
        "classification" => anchor && all_five ?
            "bounded_single_shot_science_anchor_not_reactor" :
            all_five ? "icf_screen_survivor_pending_medium_fidelity" :
            "conditional_hypothesis_or_rejected_at_icf_fidelity_0",
        "claim_boundary" => _LICFV15_CLAIM_BOUNDARY)
    result["result_hash"] = canonical_hash(result)
    return result
end

function run_evaluator(evaluator::LaserICFScreenV1, genome::Genome; kwargs...)
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return _non_applicable_bundle(evaluator_spec(evaluator),
        genome, reason)
    result = _laser_icf_result(evaluator, genome)
    run_hash = canonical_hash(Dict("input_hash" => genome.physics_hash,
        "result_hash" => result["result_hash"]))
    metric = MetricResult("laser_icf_five_gate_passed",
        result["all_five_gates_passed"];
        fidelity = 0, applicability = reason,
        status = result["all_five_gates_passed"] ? :pass : :fail,
        solver_name = "laser_icf_screen_v1", solver_version = "1.0.0",
        input_hash = genome.physics_hash, run_hash = run_hash,
        source_basis = _LICFV15_SOURCE_BASIS,
        warnings = [_LICFV15_CLAIM_BOUNDARY])
    return EvaluationBundle("laser_icf_screen_v1", genome.design_id,
        genome.family, 0, result["all_five_gates_passed"] ? :pass : :fail,
        [metric], [_LICFV15_CLAIM_BOUNDARY], genome.physics_hash, run_hash,
        _LICFV15_CLAIM_BOUNDARY)
end
