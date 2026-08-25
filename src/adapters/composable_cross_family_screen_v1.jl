const _CCV9_SCREEN_CLAIM_BOUNDARY =
    "Fidelity-0 evidence-constrained composition rejection screen. It reuses the sealed " *
    "shared-outer-envelope v5 physics and engineering proxies, then adds compatibility, " *
    "finite exhaust-build, conservative hybrid-intersection, centrifugal-voltage, " *
    "insulation, neutral-control, rotation-power, and deterministic robustness gates. " *
    "Experimental heat-load or density-drop factors are not used as reactor multipliers. " *
    "Passing does not establish equilibrium, all-mode stability, transport, detachment, " *
    "rotation sustainment, coil feasibility, materials qualification, net electricity, " *
    "a new device, or superiority."

"An independent v9 wrapper; sealed v5 code and artifacts remain unchanged."
struct ComposableCrossFamilyScreenV1 <: AbstractEvaluator
    contract::SharedOuterEnvelopeContractV1
    allowed_contract_hashes::Set{String}
end

function ComposableCrossFamilyScreenV1(contract::SharedOuterEnvelopeContractV1;
        allowed_contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    hashes = Set(canonical_hash(_oe_contract_dict(item)) for item in allowed_contracts)
    return ComposableCrossFamilyScreenV1(contract, hashes)
end

function evaluator_spec(::ComposableCrossFamilyScreenV1)
    return EvaluatorSpec(
        "composable_cross_family_screen_v1", "1.0.0",
        ["tokamak_axisymmetric", "tokamak_3d_hybrid", "stellarator",
            "magnetic_mirror", "field_reversed_configuration", "spheromak"], 0,
        Dict(
            "topology_compatibility" => :proxy,
            "equilibrium" => :proxy, "basic_constraints" => :proxy,
            "stability" => :proxy, "particle_loss" => :proxy,
            "energy_confinement" => :proxy, "power_balance" => :proxy,
            "finite_build_coils" => :proxy, "coil_stress" => :proxy,
            "shielding" => :proxy, "maintenance_access" => :proxy,
            "finite_exhaust_build" => :proxy, "exhaust" => :proxy,
            "centrifugal_voltage" => :proxy, "insulation" => :proxy,
            "neutral_control" => :proxy, "rotation_power" => :proxy,
            "manufacturing_tolerance" => :proxy,
        ), _CCV9_SCREEN_CLAIM_BOUNDARY)
end

function evaluator_applicability(evaluator::ComposableCrossFamilyScreenV1,
        genome::Genome)
    genome.family in evaluator_spec(evaluator).families || return false,
        "composable cross-family v9 does not cover family $(genome.family)"
    genome.mission.fuel == "D-T" || return false,
        "composable cross-family v9 is restricted to D-T"
    family = validate_family(default_family_registry(), genome)
    family.valid || return false, join(family.errors, "; ")
    return true, "evidence-constrained composition under $(evaluator.contract.id)"
end

_ccv9_target(genome::Genome, name::String, default::Real, unit::String) =
    _oe_target(genome, name, default, unit)

function _ccv9_exhaust_topology(genome::Genome)
    kind = genome.exhaust.kind
    occursin("super_x", kind) && return "super_x_long_leg"
    occursin("island_divertor", kind) && return "boundary_island_divertor"
    occursin("end_expander", kind) && return "two_end_expander"
    return "distributed_targets"
end

function _ccv9_stability_drive(genome::Genome)
    _ccv9_target(genome, "screen_rotation_mach", 0.0, "1") > 0.0 &&
        return "centrifugal_exb_shear"
    genome.family == "tokamak_3d_hybrid" && return
        (_ct_has_kind(genome.field_sources, "programmable_planar_dipole_coil") ?
            "programmable_qa_current" : "fixed_qa_current")
    genome.family == "stellarator" && return String(genome.symmetry.class)
    genome.family == "magnetic_mirror" && return "minimum_b_beam_plug"
    mechanisms = sort!(unique(mechanism.mechanism for mechanism in
        genome.stability_mechanisms))
    return isempty(mechanisms) ? "declared_family_mechanism" : join(mechanisms, "+")
end

function _ccv9_extra_build_m(genome::Genome)
    exhaust = _ccv9_target(genome, "screen_exhaust_extra_build", 0.0, "m")
    insulation = _ccv9_target(genome, "screen_rotation_insulation_thickness",
        0.0, "m")
    return max(0.0, exhaust) + 0.25 * max(0.0, insulation)
end

function _ccv9_toroidal_features(features)
    return merge(features, (family = features.family == "tokamak_3d_hybrid" ?
        "stellarator" : features.family,))
end

"Reserve exhaust and high-voltage hardware inside the same outer envelope."
function _ccv9_scored_features(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features = _oe_features(genome))
    mapped = _ccv9_toroidal_features(features)
    unreserved = _oe_geometry(mapped, contract)
    extra_build = _ccv9_extra_build_m(genome)
    capacity = max(unreserved.capacity, 1.0e-9)
    effective_fill = max(0.0,
        (features.plasma_fill_fraction * capacity - extra_build) / capacity)
    return merge(features, (
        plasma_fill_fraction = effective_fill,
    ))
end

function _ccv9_geometry(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features = _oe_features(genome);
        dimension_multiplier::Float64 = 1.0)
    scored = _ccv9_scored_features(genome, contract, features)
    return _oe_geometry(_ccv9_toroidal_features(scored), contract;
        dimension_multiplier = dimension_multiplier)
end

function _ccv9_hybrid_nominal(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features; kwargs...)
    tokamak_features = merge(features, (family = "tokamak_axisymmetric",))
    stellarator_features = merge(features, (family = "stellarator",))
    tokamak = _oe_nominal(genome, contract, tokamak_features; kwargs...)
    stellarator = _oe_nominal(genome, contract, stellarator_features; kwargs...)
    selected = tokamak["required_auxiliary_power_W"] >=
        stellarator["required_auxiliary_power_W"] ? deepcopy(tokamak) :
        deepcopy(stellarator)
    margins = Dict{String,Float64}()
    for name in union(keys(tokamak["margins"]), keys(stellarator["margins"]))
        margins[String(name)] = min(Float64(get(tokamak["margins"], name, Inf)),
            Float64(get(stellarator["margins"], name, Inf)))
    end
    current_share = features.plasma_current_fraction
    external_share = features.external_transform_fraction
    margins["hybrid_transform_share"] = min(
        (current_share - 0.20) / 0.20, (0.65 - current_share) / 0.20,
        (external_share - 0.35) / 0.20, (0.80 - external_share) / 0.20)
    margins["hybrid_field_quality"] = (features.field_quality - 0.90) / 0.10
    selected["family"] = "tokamak_3d_hybrid"
    selected["margins"] = margins
    selected["minimum_normalized_margin"] = minimum(values(margins))
    selected["physics_gate_passed"] = all(margins[id] >= 0.0 for id in
        ("temperature_domain", "stability", "particle_loss", "fusion_gain",
            "auxiliary_power", "net_electric_power", "hybrid_transform_share",
            "hybrid_field_quality"))
    selected["engineering_gate_passed"] = all(margins[id] >= 0.0 for id in
        ("peak_conductor_field", "engineering_current_density", "support_stress",
            "outer_radial_envelope", "outer_axial_envelope", "inboard_build",
            "coil_curvature", "neutron_wall_load", "exhaust_target_heat_flux"))
    selected["hybrid_proxy_policy"] =
        "elementwise margin intersection; lower-net confinement branch retained"
    selected["tokamak_branch"] = Dict(
        "energy_confinement_time_s" => tokamak["energy_confinement_time_s"],
        "required_auxiliary_power_W" => tokamak["required_auxiliary_power_W"],
        "net_electric_power_W" => tokamak["net_electric_power_W"],
        "minimum_normalized_margin" => tokamak["minimum_normalized_margin"])
    selected["stellarator_branch"] = Dict(
        "energy_confinement_time_s" => stellarator["energy_confinement_time_s"],
        "required_auxiliary_power_W" => stellarator["required_auxiliary_power_W"],
        "net_electric_power_W" => stellarator["net_electric_power_W"],
        "minimum_normalized_margin" => stellarator["minimum_normalized_margin"])
    return selected
end

function _ccv9_rotation_features(features, mach::Float64)
    ratio = max(1.01, features.mirror_ratio *
        (1.0 + 1.5 * features.plug_strength +
            0.75 * features.minimum_b_strength))
    multiplier = 1.0 + min(2.0, 0.50 * mach^2)
    effective_ratio = min(1.0e4, ratio^multiplier)
    effective_plug = max(0.0, (effective_ratio / features.mirror_ratio - 1.0 -
        0.75 * features.minimum_b_strength) / 1.5)
    return merge(features, (plug_strength = effective_plug,)), multiplier
end

function _ccv9_add_rotation_gates!(nominal::Dict{String,Any}, genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features;
        rotation_voltage_multiplier::Float64 = 1.0,
        neutral_multiplier::Float64 = 1.0,
        field_multiplier::Float64 = 1.0,
        field_quality_penalty::Float64 = 0.0)
    mach = _ccv9_target(genome, "screen_rotation_mach", 0.0, "1")
    mach <= 0.0 && return nominal
    ion_mass = 2.5 * 1.66053906660e-27
    temperature_J = features.temperature_keV * 1.602176634e-16
    thermal_speed = sqrt(2.0 * temperature_J / ion_mass)
    rotation_speed = mach * thermal_speed
    required_voltage = rotation_speed * contract.plasma_field_T * field_multiplier *
        nominal["plasma_minor_radius_m"]
    declared_voltage = rotation_voltage_multiplier * _ccv9_target(genome,
        "screen_rotation_voltage", 0.0, "V")
    insulation = _ccv9_target(genome,
        "screen_rotation_insulation_thickness", 0.0, "m")
    neutral_fraction = neutral_multiplier * _ccv9_target(genome,
        "screen_neutral_fraction", 1.0, "1")
    rotation_inventory = 0.5 * nominal["density_m3"] * ion_mass *
        rotation_speed^2 * nominal["plasma_volume_m3"]
    required_rotation_power = rotation_inventory /
        max(nominal["energy_confinement_time_s"], 1.0e-4)
    declared_power = nominal["declared_actuator_power_W"]
    margins = nominal["margins"]
    margins["rotation_mach_domain"] = min((mach - 1.0) / 1.0,
        (3.0 - mach) / 1.0)
    margins["rotation_voltage_authority"] =
        (declared_voltage - required_voltage) / max(required_voltage, 1.0)
    electric_field = declared_voltage / max(insulation, 1.0e-6)
    margins["rotation_insulation_field"] = (20.0e6 - electric_field) / 20.0e6
    margins["neutral_fraction_control"] = (1.0e-4 - neutral_fraction) / 1.0e-4
    margins["rotation_power_authority"] = (declared_power - required_rotation_power) /
        contract.base.auxiliary_heating_budget_W
    base_particle_loss = _oe_particle_loss_fraction(features,
        _oe_geometry(features, contract), contract, features.field_quality,
        nominal["density_m3"])
    multiplier = 1.0 + min(2.0, 0.50 * mach^2)
    particle_loss = base_particle_loss / multiplier
    nominal["particle_loss_fraction_proxy"] = particle_loss
    margins["particle_loss"] = (0.25 - particle_loss) / 0.25
    stability_margin, beta_N = _oe_stability_margin(features,
        _oe_geometry(features, contract), contract,
        clamp(features.field_quality - field_quality_penalty, 0.0, 1.0))
    nominal["minimum_stability_margin_proxy"] = stability_margin
    nominal["tokamak_beta_N_proxy"] = beta_N
    margins["stability"] = stability_margin
    nominal["rotation_mach"] = mach
    nominal["rotation_speed_m_s"] = rotation_speed
    nominal["required_rotation_voltage_V"] = required_voltage
    nominal["declared_rotation_voltage_V"] = declared_voltage
    nominal["rotation_insulation_field_V_m"] = electric_field
    nominal["neutral_fraction"] = neutral_fraction
    nominal["rotation_energy_inventory_J"] = rotation_inventory
    nominal["required_rotation_power_W"] = required_rotation_power
    nominal["centrifugal_confinement_multiplier_cap"] = multiplier
    return nominal
end

function _ccv9_nominal(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features = _oe_features(genome);
        field_multiplier::Float64 = 1.0,
        beta_multiplier::Float64 = 1.0,
        dimension_multiplier::Float64 = 1.0,
        field_quality_penalty::Float64 = 0.0,
        actuator_multiplier::Float64 = 1.0,
        target_area_multiplier::Float64 = 1.0,
        rotation_voltage_multiplier::Float64 = 1.0,
        neutral_multiplier::Float64 = 1.0)
    scored = _ccv9_scored_features(genome, contract, features)
    mach = _ccv9_target(genome, "screen_rotation_mach", 0.0, "1")
    confinement_features, rotation_multiplier = mach > 0.0 ?
        _ccv9_rotation_features(scored, mach) : (scored, 1.0)
    kwargs = (
        field_multiplier = field_multiplier,
        beta_multiplier = beta_multiplier,
        dimension_multiplier = dimension_multiplier,
        field_quality_penalty = field_quality_penalty,
        actuator_multiplier = actuator_multiplier,
        target_area_multiplier = target_area_multiplier,
    )
    nominal = if features.family == "tokamak_3d_hybrid"
        _ccv9_hybrid_nominal(genome, contract, confinement_features; kwargs...)
    else
        _oe_nominal(genome, contract, confinement_features; kwargs...)
    end
    _ccv9_add_rotation_gates!(nominal, genome, contract, scored;
        rotation_voltage_multiplier = rotation_voltage_multiplier,
        neutral_multiplier = neutral_multiplier,
        field_multiplier = field_multiplier,
        field_quality_penalty = field_quality_penalty)
    margins = nominal["margins"]
    extra_build = _ccv9_extra_build_m(genome)
    unreserved_capacity = _oe_geometry(_ccv9_toroidal_features(features),
        contract).capacity
    margins["finite_exhaust_and_voltage_build"] =
        (features.plasma_fill_fraction * unreserved_capacity - extra_build) /
        max(unreserved_capacity, 1.0e-9)
    nominal["unreserved_plasma_capacity_m"] = unreserved_capacity
    nominal["reserved_exhaust_and_voltage_build_m"] = extra_build
    nominal["effective_plasma_fill_fraction"] = scored.plasma_fill_fraction
    nominal["experimental_performance_multiplier_used"] = false
    physics_ids = ["temperature_domain", "stability", "particle_loss",
        "fusion_gain", "auxiliary_power", "net_electric_power"]
    features.family == "tokamak_3d_hybrid" && append!(physics_ids,
        ["hybrid_transform_share", "hybrid_field_quality"])
    mach > 0.0 && append!(physics_ids, ["rotation_mach_domain",
        "rotation_voltage_authority", "neutral_fraction_control",
        "rotation_power_authority"])
    engineering_ids = ["peak_conductor_field", "engineering_current_density",
        "support_stress", "outer_radial_envelope", "outer_axial_envelope",
        "inboard_build", "coil_curvature", "neutron_wall_load",
        "exhaust_target_heat_flux", "finite_exhaust_and_voltage_build"]
    mach > 0.0 && push!(engineering_ids, "rotation_insulation_field")
    nominal["physics_gate_passed"] = all(margins[id] >= 0.0 for id in physics_ids)
    nominal["engineering_gate_passed"] = all(margins[id] >= 0.0 for id in engineering_ids)
    nominal["minimum_normalized_margin"] = minimum(values(margins))
    nominal["composition"] = Dict(
        "core_family" => features.family,
        "stability_or_sustainment" => _ccv9_stability_drive(genome),
        "exhaust_topology" => _ccv9_exhaust_topology(genome),
        "rotation_confinement_multiplier_cap" => rotation_multiplier,
    )
    return nominal
end

function _ccv9_contract_errors!(errors::Vector{String}, genome::Genome,
        contract::SharedOuterEnvelopeContractV1)
    for (name, expected, unit) in (
            ("screen_outer_radial_extent", contract.outer_radial_extent_m, "m"),
            ("screen_outer_axial_half_extent", contract.outer_axial_half_extent_m, "m"),
            ("screen_plasma_field", contract.plasma_field_T, "T"))
        value = get(genome.mission.targets, name, nothing)
        if value === nothing || value.unit != unit ||
                !_contract_isapprox(value.value, expected)
            push!(errors, "$name is inconsistent with v9 outer-envelope contract")
        end
    end
end

function _ccv9_closed_graph_errors!(errors::Vector{String}, genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features)
    geometry = _ccv9_geometry(genome, contract, features)
    cores = filter(region -> region.kind == "closed_toroidal_core",
        genome.plasma_regions)
    sols = filter(region -> region.kind == "scrape_off_layer",
        genome.plasma_regions)
    targets = Set(region.id for region in genome.plasma_regions if
        region.kind == "divertor_or_exhaust_region")
    length(cores) == 1 || push!(errors, "v9 toroidal composition requires one closed core")
    length(sols) == 1 || push!(errors, "v9 toroidal composition requires one explicit SOL")
    length(targets) >= 2 || push!(errors, "v9 requires at least two explicit targets")
    if length(cores) == 1
        core = only(cores)
        for (name, expected) in (("major_radius", geometry.R),
                ("minor_radius", geometry.a), ("half_height", geometry.c))
            value = get(core.parameters, name, nothing)
            (value !== nothing && value.unit == "m" &&
                isapprox(value.value, expected; rtol = 1.0e-9, atol = 1.0e-9)) ||
                push!(errors, "$(core.id).$name is inconsistent with scored v9 geometry")
        end
    end
    if length(cores) == 1 && length(sols) == 1
        core, sol = only(cores), only(sols)
        count(edge -> edge.from_region_id == core.id &&
            edge.to_region_id == sol.id &&
            edge.kind == "cross_separatrix_transport", genome.flux_connections) == 1 ||
            push!(errors, "v9 requires one core-to-SOL cross-separatrix edge")
        count(edge -> edge.from_region_id == sol.id &&
            edge.to_region_id in targets && edge.kind == "open_field_line",
            genome.flux_connections) == length(targets) ||
            push!(errors, "v9 SOL must connect to every explicit target")
    end
    all(id -> id in Set(genome.exhaust.region_ids), targets) ||
        push!(errors, "all v9 targets must be listed in exhaust.region_ids")
end

function _ccv9_graph_errors(genome::Genome, features,
        contract::SharedOuterEnvelopeContractV1)
    errors = String[]
    append!(errors, validate_genome(genome).errors)
    append!(errors, validate_family(default_family_registry(), genome).errors)
    _ccv9_contract_errors!(errors, genome, contract)
    if features.family == "tokamak_3d_hybrid"
        _ccv9_closed_graph_errors!(errors, genome, contract, features)
        _ct_has_kind(genome.field_sources, "plasma_current") ||
            push!(errors, "QA-current hybrid requires an explicit plasma-current source")
        (_ct_has_kind(genome.field_sources, "three_dimensional_modular_coil") ||
            _ct_has_kind(genome.field_sources, "programmable_planar_dipole_coil")) ||
            push!(errors, "QA-current hybrid requires an explicit 3D external-field source")
        expected_current = 1.0e6 * _oe_plasma_current_MA(
            merge(_ccv9_scored_features(genome, contract, features),
                (family = "tokamak_axisymmetric",)),
            _ccv9_geometry(genome, contract, features), contract)
        current = get(genome.mission.targets, "plasma_current", nothing)
        (current !== nothing && current.unit == "A" &&
            isapprox(current.value, expected_current; rtol = 1.0e-9, atol = 1.0e-6)) ||
            push!(errors, "hybrid plasma_current is inconsistent with scored q95 geometry")
    else
        scored = _ccv9_scored_features(genome, contract, features)
        inherited = _oe_graph_errors(genome, scored, contract)
        # v5 treats fill as a direct gene. v9 deliberately reduces that fill to
        # reserve mechanism hardware, while checking the declared gene below.
        filter!(!=("plasma fill fraction must be in [0.25, 0.95]"), inherited)
        append!(errors, inherited)
    end
    exhaust = _ccv9_exhaust_topology(genome)
    if exhaust == "super_x_long_leg"
        features.family == "tokamak_axisymmetric" ||
            push!(errors, "Super-X v9 branch is restricted to axisymmetric tokamak cores")
        _ct_has_kind(genome.field_sources, "super_x_divertor_coil") ||
            push!(errors, "Super-X branch requires explicit finite-build divertor coils")
    elseif exhaust == "boundary_island_divertor"
        features.family in ("stellarator", "tokamak_3d_hybrid") ||
            push!(errors, "island divertor requires a three-dimensional toroidal core")
        features.three_d_fraction >= 0.50 ||
            push!(errors, "island divertor requires an explicit 3D boundary field")
    elseif exhaust == "two_end_expander"
        features.family == "magnetic_mirror" ||
            push!(errors, "two-end expander is restricted to open mirror cores")
    end
    mach = _ccv9_target(genome, "screen_rotation_mach", 0.0, "1")
    if mach > 0.0
        features.family == "magnetic_mirror" ||
            push!(errors, "centrifugal rotation branch is restricted to magnetic mirrors")
        _ct_has_kind(genome.actuators, "high_voltage_central_electrode") ||
            push!(errors, "centrifugal branch requires a high-voltage central electrode")
        _ccv9_target(genome, "screen_rotation_voltage", 0.0, "V") > 0.0 ||
            push!(errors, "centrifugal branch requires declared rotation voltage")
        _ccv9_target(genome, "screen_rotation_insulation_thickness", 0.0, "m") > 0.0 ||
            push!(errors, "centrifugal branch requires declared insulation thickness")
    end
    0.0 <= _ccv9_extra_build_m(genome) < min(contract.outer_radial_extent_m,
        contract.outer_axial_half_extent_m) ||
        push!(errors, "v9 reserved exhaust/voltage build exceeds outer envelope")
    0.25 <= features.plasma_fill_fraction <= 0.95 ||
        push!(errors, "v9 plasma fill fraction must be in [0.25, 0.95]")
    1.0 <= features.exhaust_flux_expansion <= 6.0 ||
        push!(errors, "v9 exhaust flux expansion must be in [1, 6]")
    return sort!(unique(errors))
end

function _ccv9_robustness(genome::Genome,
        contract::SharedOuterEnvelopeContractV1, features)
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
        neutral_error = 0.50 * rand(rng)
        quality_penalty = abs(coil_offset_m) /
            max(contract.outer_radial_extent_m, 1.0e-9) *
            (1.0 + 3.0 * features.three_d_fraction) +
            0.03 * abs(control_error)
        values = _ccv9_nominal(genome, contract, features;
            field_multiplier = 1.0 + field_delta,
            beta_multiplier = 1.0 + beta_delta,
            dimension_multiplier = 1.0 + dimension_delta,
            field_quality_penalty = quality_penalty,
            actuator_multiplier = 1.0 + control_error,
            target_area_multiplier = 1.0 - target_occlusion,
            rotation_voltage_multiplier = 1.0 - abs(control_error),
            neutral_multiplier = 1.0 + neutral_error)
        passed = values["physics_gate_passed"] === true &&
            values["engineering_gate_passed"] === true
        passed && (pass_count += 1)
        worst_margin = min(worst_margin,
            Float64(values["minimum_normalized_margin"]))
        push!(records, Dict{String,Any}(
            "sample" => sample, "field_delta_fraction" => field_delta,
            "beta_delta_fraction" => beta_delta,
            "dimension_delta_fraction" => dimension_delta,
            "coil_offset_m" => coil_offset_m,
            "actuator_power_error_fraction" => control_error,
            "target_occlusion_fraction" => target_occlusion,
            "neutral_fraction_error" => neutral_error,
            "passed" => passed,
            "minimum_normalized_margin" => values["minimum_normalized_margin"],
        ))
    end
    fraction = pass_count / contract.base.robustness_samples
    return Dict{String,Any}(
        "sample_count" => contract.base.robustness_samples,
        "common_random_seed" => contract.base.robustness_seed,
        "pass_count" => pass_count, "pass_fraction" => fraction,
        "required_pass_fraction" => contract.base.robustness_required_pass_fraction,
        "gate_passed" => fraction >= contract.base.robustness_required_pass_fraction,
        "worst_minimum_normalized_margin" => worst_margin,
        "records" => records,
    )
end

function _composable_cross_family_result(
        evaluator::ComposableCrossFamilyScreenV1, genome::Genome)
    contract = evaluator.contract
    contract_dict = _oe_contract_dict(contract)
    contract_hash = canonical_hash(contract_dict)
    features = _oe_features(genome)
    graph_errors = _ccv9_graph_errors(genome, features, contract)
    graph_gate = isempty(graph_errors)
    nominal = _ccv9_nominal(genome, contract, features)
    robustness = if graph_gate && nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true
        _ccv9_robustness(genome, contract, features)
    else
        Dict{String,Any}(
            "sample_count" => 0,
            "maximum_sample_budget" => contract.base.robustness_samples,
            "common_random_seed" => contract.base.robustness_seed,
            "pass_count" => 0, "pass_fraction" => 0.0,
            "required_pass_fraction" => contract.base.robustness_required_pass_fraction,
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
    exhaust = _ccv9_exhaust_topology(genome)
    exhaust_complexity = exhaust == "distributed_targets" ? 0.0 :
        exhaust == "two_end_expander" ? 1.0 : exhaust == "super_x_long_leg" ? 2.0 : 3.0
    complexity = length(genome.field_sources) + 1.5 * length(genome.actuators) +
        0.5 * length(genome.plasma_regions) +
        0.25 * length(genome.flux_connections) +
        0.25 * max(features.target_count - 2, 0) +
        3.0 * features.three_d_fraction + exhaust_complexity
    result = Dict{String,Any}(
        "contract" => contract_dict, "contract_hash" => contract_hash,
        "claim_boundary" => _CCV9_SCREEN_CLAIM_BOUNDARY,
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
            "cheap_robustness_screen" => robustness["gate_passed"],
        ),
        "all_five_gates_passed" => all_five,
        "positive_net_power_closure_passed" =>
            nominal["net_electric_power_W"] > 0.0,
        "classification" => all_five ?
            "composable_v9_survivor_pending_family_specific_medium_fidelity" :
            "obviously_infeasible_or_unresolved",
        "device_complexity_proxy" => complexity,
    )
    result["result_hash"] = canonical_hash(result)
    return result
end

function run_evaluator(evaluator::ComposableCrossFamilyScreenV1, genome::Genome;
        kwargs...)
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return _non_applicable_bundle(evaluator_spec(evaluator), genome,
        reason)
    result = _composable_cross_family_result(evaluator, genome)
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "evaluator" => "composable_cross_family_screen_v1",
        "version" => "1.0.0", "result_hash" => result["result_hash"]))
    status = result["all_five_gates_passed"] === true ? :pass : :fail
    metric = MetricResult("composable_cross_family_five_gate_pass",
        result["all_five_gates_passed"] ? 1.0 : 0.0;
        fidelity = 0, applicability = reason, status = status,
        constraints_checked = sort!(collect(keys(result["gates"]))),
        solver_name = "composable_cross_family_screen_v1",
        solver_version = "1.0.0", input_hash = genome.physics_hash,
        run_hash = run_hash, source_basis = [
            "tokamak_iter_physics_basis_1999", "stellarator_iss04_yamada_2005",
            "mirror_beam_2024", "ncsx_physics_zarnstorff_2001",
            "superx_havlickova_2014", "w7x_divertor_jakubowski_2021",
            "mcx_centrifugal_teodorescu_2010"],
        warnings = [_CCV9_SCREEN_CLAIM_BOUNDARY])
    return EvaluationBundle("composable_cross_family_screen_v1",
        genome.design_id, genome.family, 0, status, [metric],
        [_CCV9_SCREEN_CLAIM_BOUNDARY], genome.physics_hash, run_hash,
        _CCV9_SCREEN_CLAIM_BOUNDARY)
end
