"""Structural mechanisms available to the failure-aware closed/open hybrid search."""
struct HybridRepairTopologySpec
    plug::Bool
    minimum_b::Bool
    shear::Bool
end

function _fa_mechanism_label(spec::HybridRepairTopologySpec)
    labels = String[]
    spec.plug && push!(labels, "ambipolar_plug")
    spec.minimum_b && push!(labels, "minimum_b")
    spec.shear && push!(labels, "sheared_flow")
    return isempty(labels) ? "interface_only" : join(labels, "+")
end

function _fa_hybrid_repair_transform!(raw::Dict{String,Any},
        spec::HybridRepairTopologySpec, contract::CommonComparisonContract)
    if spec.plug
        for side in ("left", "right")
            push!(raw["plasma_regions"], Dict{String,Any}(
                "id" => "hybrid_$(side)_plug",
                "kind" => "mirror_plug_or_anchor",
                "geometry_model" => "anisotropic_ambipolar_plug_hypothesis",
                "parameters" => Dict{String,Any}(),
            ))
            push!(raw["actuators"], Dict{String,Any}(
                "id" => "hybrid_$(side)_plug_ech",
                "kind" => "ech",
                "parameters" => Dict(
                    "power" => Dict("value" => 2.0e6, "unit" => "W")),
            ))
        end
        raw["flux_connections"] = Any[
            Dict("from_region_id" => "hybrid_closed_core",
                "to_region_id" => "hybrid_left_plug", "kind" => "open_field_line"),
            Dict("from_region_id" => "hybrid_left_plug",
                "to_region_id" => "hybrid_left_open_end", "kind" => "open_field_line"),
            Dict("from_region_id" => "hybrid_closed_core",
                "to_region_id" => "hybrid_right_plug", "kind" => "open_field_line"),
            Dict("from_region_id" => "hybrid_right_plug",
                "to_region_id" => "hybrid_right_open_end", "kind" => "open_field_line"),
        ]
        push!(raw["stability_mechanisms"], Dict{String,Any}(
            "id" => "hybrid_ambipolar_plug_mechanism",
            "mechanism" => "other",
            "target_modes" => ["electron end loss", "ion end loss"],
            "actuator_ids" => ["hybrid_left_plug_ech", "hybrid_right_plug_ech"],
            "assumptions" => [
                "plug electron heating sustains the required ambipolar potential",
                "the declared plug power is added conservatively to the common-screen auxiliary burden",
            ],
            "required_evaluators" => [
                "fokker_planck", "ambipolar_potential", "plug_microstability",
                "electron_heat_loss", "actuator_power"],
            "source_ids" => ["mirror_tandem_fowler_logan_1977", "mirror_post_review_1987"],
        ))
        _set_screen_target!(raw, "screen_plug_strength", 0.40, "1";
            basis = "minimum explicit failure-aware plug hypothesis")
    end
    if spec.minimum_b
        push!(raw["field_sources"], Dict{String,Any}(
            "id" => "hybrid_minimum_b_anchor_set",
            "kind" => "minimum_b_coil",
            "geometry_model" => "external_minimum_b_anchor_hypothesis",
            "parameters" => Dict(
                "coil_count" => Dict("value" => 4, "unit" => "1")),
            "material" => contract.magnet_material_envelope,
        ))
        push!(raw["stability_mechanisms"], Dict{String,Any}(
            "id" => "hybrid_minimum_b_mechanism",
            "mechanism" => "minimum_b",
            "target_modes" => ["interchange", "flute"],
            "actuator_ids" => Any[],
            "assumptions" => [
                "a finite-beta magnetic well survives the closed/open interface",
                "explicit finite-build anchor geometry remains a blocking task",
            ],
            "required_evaluators" => [
                "coupled_closed_open_equilibrium", "interchange_growth",
                "minimum_b_coil_forces"],
            "source_ids" => ["mirror_post_review_1987"],
        ))
        _set_screen_target!(raw, "screen_minimum_b_strength", 0.50, "1";
            basis = "minimum explicit failure-aware minimum-B hypothesis")
    end
    if spec.shear
        push!(raw["actuators"], Dict{String,Any}(
            "id" => "hybrid_bias_system",
            "kind" => "biased_electrode",
            "parameters" => Dict(
                "power" => Dict("value" => 2.0e6, "unit" => "W")),
        ))
        push!(raw["stability_mechanisms"], Dict{String,Any}(
            "id" => "hybrid_sheared_flow_mechanism",
            "mechanism" => "sheared_flow",
            "target_modes" => ["interchange", "closed-open interface mode"],
            "actuator_ids" => ["hybrid_bias_system"],
            "assumptions" => [
                "edge shearing rate exceeds the relevant growth rate",
                "the declared bias power is added conservatively to the common-screen auxiliary burden",
            ],
            "required_evaluators" => [
                "flow_shear", "interchange_growth", "actuator_power"],
            "source_ids" => ["mirror_wham_physics_basis_2023"],
        ))
        _set_screen_target!(raw, "screen_shear_strength", 0.40, "1";
            basis = "minimum explicit failure-aware sheared-flow hypothesis")
    end
    _push_unique!(raw["engineering"]["required_evaluators"], [
        "coupled_closed_open_equilibrium", "separatrix_field_line_mapping",
        "kinetic_open_end_loss", "actuator_power", "power_balance_with_exhaust"])
    return raw
end

"""
Build an explicit closed-core/open-end child with the selected repair mechanisms.

The child still carries hypotheses, not solved equilibrium or engineering evidence.  Active
plug and shear mechanisms receive explicit actuators so the v3 search can count their power.
"""
function build_closed_open_hybrid_repair_genome(parent::Genome,
        spec::HybridRepairTopologySpec;
        contract::CommonComparisonContract = default_common_comparison_contract(),
        random_seed::Int = 20260811)
    rng = MersenneTwister(random_seed)
    hybrid = if parent.family == "closed_open_hybrid"
        parent
    else
        hybrid_rule = only(filter(rule ->
            rule.id == "closed_open_mirror_exhaust_hybrid",
            discovery_graph_rules_v2()))
        applicable_rule(hybrid_rule, parent) || throw(ArgumentError(
            "parent family $(parent.family) cannot enter the closed/open hybrid grammar"))
        apply_rule(hybrid_rule, parent, rng)
    end
    source_ids = String["mirror_post_review_1987", "stellarator_garren_boozer_1991"]
    spec.plug && push!(source_ids, "mirror_tandem_fowler_logan_1977")
    spec.shear && push!(source_ids, "mirror_wham_physics_basis_2023")
    rule = _graph_rule(
        "failure_aware_hybrid_$(_fa_mechanism_label(spec))",
        "Add explicit repair mechanisms selected from failed closed/open gate vectors.",
        ["closed_open_hybrid"], unique(source_ids), genome -> true,
        (raw, _) -> _fa_hybrid_repair_transform!(raw, spec, contract))
    repaired = apply_rule(rule, hybrid, rng)
    return _synchronize_common_envelope(repaired, contract; id_prefix = "concept")
end

function _fa_halton(index::Int, base::Int)
    result, factor, value = 0.0, 1.0 / base, index
    while value > 0
        result += factor * (value % base)
        value ÷= base
        factor /= base
    end
    return result
end


function _fa_bin(value::Float64, cuts::Tuple, labels::Tuple)
    for (cut, label) in zip(cuts, labels)
        value < cut && return label
    end
    return labels[end]
end

function _fa_descriptor(spec::HybridRepairTopologySpec, features)
    closure = _fa_bin(features.closed_fraction, (0.40, 0.75, Inf),
        ("open_dominant", "balanced", "closed_dominant"))
    aspect = _fa_bin(features.aspect_ratio, (3.5, 5.0, Inf),
        ("A_low", "A_mid", "A_high"))
    beta = _fa_bin(features.beta, (0.04, 0.10, Inf),
        ("beta_low", "beta_mid", "beta_high"))
    return join((_fa_mechanism_label(spec), closure, aspect, beta), "|")
end

function _fa_active_power_W(spec::HybridRepairTopologySpec)
    return (spec.plug ? 4.0e6 : 0.0) + (spec.shear ? 2.0e6 : 0.0)
end

function _fa_power_closure(nominal::AbstractDict, spec::HybridRepairTopologySpec,
        contract::CommonComparisonContract)
    active = _fa_active_power_W(spec)
    fusion = Float64(nominal["fusion_power_W"])
    adjusted_aux = Float64(nominal["required_auxiliary_power_W"]) + active
    adjusted_q = fusion / max(adjusted_aux, 1.0)
    adjusted_net = contract.thermal_conversion_efficiency * fusion -
        adjusted_aux / contract.heating_wall_plug_efficiency -
        contract.fixed_balance_of_plant_load_W
    gates = Dict{String,Bool}(
        "nominal_physics_proxy" => nominal["physics_gate_passed"] === true,
        "nominal_minimal_engineering_proxy" =>
            nominal["engineering_gate_passed"] === true,
        "adjusted_auxiliary_budget" =>
            adjusted_aux <= contract.auxiliary_heating_budget_W,
        "adjusted_fusion_gain_at_least_one" => adjusted_q >= 1.0,
        "positive_adjusted_net_electric_proxy" => adjusted_net > 0.0,
    )
    return Dict{String,Any}(
        "declared_additional_actuator_power_W" => active,
        "adjusted_required_auxiliary_power_W" => adjusted_aux,
        "adjusted_fusion_gain_proxy" => adjusted_q,
        "adjusted_net_electric_power_W" => adjusted_net,
        "gates" => gates,
        "all_power_closure_gates_passed" => all(values(gates)),
    )
end

function _fa_acquisition_key(record::AbstractDict)
    nominal = record["nominal"]
    power = record["power_closure"]
    nominal_pass = nominal["physics_gate_passed"] === true &&
        nominal["engineering_gate_passed"] === true
    return (
        nominal_pass ? 0 : 1,
        power["all_power_closure_gates_passed"] === true ? 0 : 1,
        -Float64(power["adjusted_net_electric_power_W"]),
        -Float64(nominal["minimum_normalized_margin"]),
        -Float64(power["adjusted_fusion_gain_proxy"]),
        canonical_hash(record["features"]),
    )
end

function _fa_target!(raw::Dict{String,Any}, name::String, value::Real,
        unit::String = "1")
    _set_screen_target!(raw, name, value, unit;
        basis = "failure-aware v3 low-discrepancy acquisition")
end

function _fa_instantiate(base::Genome, acquisition::AbstractDict,
        contract::CommonComparisonContract)
    raw = deepcopy(base.normalized)
    features = acquisition["features"]
    for name in ("screen_closed_flux_fraction", "screen_mirror_ratio",
            "screen_aspect_ratio", "screen_beta", "screen_field_quality",
            "screen_q95", "screen_plug_strength", "screen_minimum_b_strength",
            "screen_shear_strength")
        _fa_target!(raw, name, Float64(features[name]))
    end
    _fa_target!(raw, "screen_temperature", Float64(features["screen_temperature"]),
        "keV")
    _fa_target!(raw, "screen_coil_pack_thickness",
        Float64(features["screen_coil_pack_thickness"]), "m")
    _fa_target!(raw, "screen_support_thickness",
        Float64(features["screen_support_thickness"]), "m")
    raw["design_id"] = "pending_failure_aware_v3"
    return _synchronize_common_envelope(parse_genome(raw), contract;
        id_prefix = "concept")
end

"""
Run a two-stage failure-aware QD round for explicit closed/open hybrids.

Stage 1 uses the declared fidelity-0 equations as a deterministic acquisition model in
the original conservative `A >= 2.8`, `q95 >= 2.5` search domain.  Stage 2 instantiates
one elite per mechanism/closure/aspect/beta cell and reruns the complete common five-gate
screen, including deterministic robustness.  Positive net electric power is an added v3
selection constraint; it does not retroactively alter the sealed five-gate contract.
"""
function run_failure_aware_hybrid_qd(seeds::Vector{Genome};
        acquisition_samples::Int = 400_000,
        random_seed::Int = 20260811,
        maximum_graph_elites::Int = 256,
        contract::CommonComparisonContract = default_common_comparison_contract())
    acquisition_samples >= 0 || throw(ArgumentError(
        "acquisition_samples must be non-negative"))
    maximum_graph_elites > 0 || throw(ArgumentError(
        "maximum_graph_elites must be positive"))
    baselines = _common_baseline_genomes(seeds, contract)
    tokamak = only(filter(genome -> genome.family == "tokamak_axisymmetric", baselines))
    specs = vec(HybridRepairTopologySpec[
        HybridRepairTopologySpec(plug, minimum_b, shear)
        for plug in (false, true), minimum_b in (false, true), shear in (false, true)])
    structural = Dict{String,Genome}()
    for (index, spec) in enumerate(specs)
        structural[_fa_mechanism_label(spec)] =
            build_closed_open_hybrid_repair_genome(tokamak, spec;
                contract = contract, random_seed = random_seed + index)
    end

    primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37)
    archive = Dict{String,Dict{String,Any}}()
    nominal_physics_engineering_count = 0
    positive_net_count = 0
    for index in 1:acquisition_samples
        spec = specs[mod1(index, length(specs))]
        base = structural[_fa_mechanism_label(spec)]
        u = ntuple(axis -> _fa_halton(index, primes[axis]), length(primes))
        base_features = _topology_features(base)
        features = merge(base_features, (
            closed_fraction = 0.10 + 0.85 * u[1],
            open_fraction = 0.90 - 0.85 * u[1],
            mirror_ratio = 2.0 + 4.0 * u[2],
            aspect_ratio = 2.8 + 3.7 * u[3],
            beta = 0.008 + 0.242 * u[4],
            temperature_keV = 8.0 + 22.0 * u[5],
            field_quality = 0.82 + 0.18 * u[6],
            q95 = 2.5 + 2.5 * u[7],
            coil_pack_thickness_m = 0.30 + 0.45 * u[8],
            support_thickness_m = 0.50 + 0.90 * u[9],
            plug_strength = spec.plug ? 0.40 + 0.60 * u[10] : 0.0,
            minimum_b_strength = spec.minimum_b ? 0.50 + 0.50 * u[11] : 0.0,
            shear_strength = spec.shear ? 0.40 + 0.60 * u[12] : 0.0,
        ))
        nominal = _screen_core(base, contract, features)
        power = _fa_power_closure(nominal, spec, contract)
        nominal_pass = nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true
        nominal_pass && (nominal_physics_engineering_count += 1)
        nominal_pass && power["adjusted_net_electric_power_W"] > 0.0 &&
            (positive_net_count += 1)
        values = Dict{String,Any}(
            "screen_closed_flux_fraction" => features.closed_fraction,
            "screen_mirror_ratio" => features.mirror_ratio,
            "screen_aspect_ratio" => features.aspect_ratio,
            "screen_beta" => features.beta,
            "screen_temperature" => features.temperature_keV,
            "screen_field_quality" => features.field_quality,
            "screen_q95" => features.q95,
            "screen_coil_pack_thickness" => features.coil_pack_thickness_m,
            "screen_support_thickness" => features.support_thickness_m,
            "screen_plug_strength" => features.plug_strength,
            "screen_minimum_b_strength" => features.minimum_b_strength,
            "screen_shear_strength" => features.shear_strength,
        )
        descriptor = _fa_descriptor(spec, features)
        proposal = Dict{String,Any}(
            "descriptor" => descriptor,
            "mechanism" => _fa_mechanism_label(spec),
            "features" => values,
            "nominal" => nominal,
            "power_closure" => power,
        )
        incumbent = get(archive, descriptor, nothing)
        if incumbent === nothing ||
                _fa_acquisition_key(proposal) < _fa_acquisition_key(incumbent)
            archive[descriptor] = proposal
        end
    end

    acquisitions = collect(values(archive))
    sort!(acquisitions; by = record ->
        (record["descriptor"], _fa_acquisition_key(record)))
    acquisitions = first(acquisitions,
        min(maximum_graph_elites, length(acquisitions)))
    evaluator = UnifiedCrossFamilyScreenV1(contract)
    graph_records = Dict{String,Any}[]
    for acquisition in acquisitions
        spec = only(filter(item ->
            _fa_mechanism_label(item) == acquisition["mechanism"], specs))
        candidate = _fa_instantiate(structural[acquisition["mechanism"]],
            acquisition, contract)
        evaluation = _unified_screen_result(evaluator, candidate)
        power = _fa_power_closure(evaluation["nominal"], spec, contract)
        common_pass = evaluation["all_five_gates_passed"] === true
        extended_pass = common_pass &&
            power["all_power_closure_gates_passed"] === true
        push!(graph_records, Dict{String,Any}(
            "design_id" => candidate.design_id,
            "physics_hash" => candidate.physics_hash,
            "descriptor" => acquisition["descriptor"],
            "mechanism" => acquisition["mechanism"],
            "genome" => candidate.normalized,
            "acquisition" => acquisition,
            "evaluation" => evaluation,
            "power_closure" => power,
            "common_five_gate_passed" => common_pass,
            "failure_aware_power_closure_passed" => extended_pass,
            "classification" => extended_pass ?
                "power_closure_survivor_pending_medium_fidelity" :
                common_pass ? "five_gate_survivor_without_positive_net_power" :
                "rejected_by_common_five_gate_screen",
        ))
    end
    sort!(graph_records; by = record -> (
        record["failure_aware_power_closure_passed"] === true ? 0 : 1,
        record["common_five_gate_passed"] === true ? 0 : 1,
        -Float64(record["power_closure"]["adjusted_net_electric_power_W"]),
        record["physics_hash"],
    ))
    return Dict{String,Any}(
        "algorithm" => "two-stage low-discrepancy acquisition plus MAP-Elites-style explicit-graph validation",
        "random_seed" => random_seed,
        "acquisition_samples" => acquisition_samples,
        "declared_search_domain" => Dict(
            "closed_flux_fraction" => [0.10, 0.95],
            "mirror_ratio" => [2.0, 6.0],
            "aspect_ratio" => [2.8, 6.5],
            "beta" => [0.008, 0.25],
            "temperature_keV" => [8.0, 30.0],
            "field_quality" => [0.82, 1.0],
            "q95" => [2.5, 5.0],
            "reason_for_A_and_q95_floor" =>
                "preserves the sealed v1 conservative domain and rejects the observed low-q95/low-A proxy exploit",
        ),
        "mechanism_count" => length(specs),
        "mechanisms" => _fa_mechanism_label.(specs),
        "acquisition_archive_cell_count" => length(archive),
        "nominal_physics_and_engineering_pass_count" =>
            nominal_physics_engineering_count,
        "positive_adjusted_net_power_count" => positive_net_count,
        "explicit_graph_elite_count" => length(graph_records),
        "explicit_graph_common_five_gate_pass_count" =>
            count(record -> record["common_five_gate_passed"] === true,
                graph_records),
        "explicit_graph_power_closure_pass_count" =>
            count(record -> record["failure_aware_power_closure_passed"] === true,
                graph_records),
        "records" => graph_records,
        "claim_boundary" =>
            "This is a failure-aware fidelity-0 acquisition and rejection round. Explicit graph consistency, the common five-gate proxy, and conservative declared actuator power are checked. No coupled closed/open equilibrium, MHD spectrum, orbit/kinetic loss, coil inverse design, material qualification, exhaust solution, or reactor engineering closure is established.",
    )
end
