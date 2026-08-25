"A structural mechanism and explicit exhaust-target multiplicity for v5."
struct OuterEnvelopeTopologySpecV5
    family::String
    sustainment::String
    target_count::Int

    function OuterEnvelopeTopologySpecV5(family::AbstractString,
            sustainment::AbstractString, target_count::Integer)
        family_string = String(family)
        sustainment_string = String(sustainment)
        family_string in ("tokamak_axisymmetric", "stellarator",
            "magnetic_mirror", "field_reversed_configuration", "spheromak") ||
            throw(ArgumentError("unsupported v5 family $family_string"))
        target_count in (2, 4, 8) || throw(ArgumentError(
            "v5 target count must be 2, 4, or 8"))
        family_string == "magnetic_mirror" && target_count != 2 &&
            throw(ArgumentError("mirror v5 has two axial targets"))
        return new(family_string, sustainment_string, Int(target_count))
    end
end

function _oev5_topology_specs()
    mechanisms = [
        ("tokamak_axisymmetric", "plasma_current_q_profile"),
        ("stellarator", "external_3d_transform"),
        ("magnetic_mirror", "beam_minimum_b_end_plug"),
        ("field_reversed_configuration", "beam_driven_fast_ion"),
        ("field_reversed_configuration", "rotating_magnetic_field"),
        ("field_reversed_configuration", "beam_plus_end_bias"),
        ("spheromak", "steady_inductive_helicity_injection"),
        ("spheromak", "imposed_dynamo_current_drive"),
    ]
    specs = OuterEnvelopeTopologySpecV5[]
    for (family, sustainment) in mechanisms
        counts = family == "magnetic_mirror" ? (2,) : (2, 4, 8)
        append!(specs, [OuterEnvelopeTopologySpecV5(family, sustainment, count)
            for count in counts])
    end
    return specs
end

_oev5_key(spec::OuterEnvelopeTopologySpecV5) =
    "$(spec.family)|$(spec.sustainment)|targets=$(spec.target_count)"

function _oev5_target_region(index::Int)
    return _ctv4_region("oe_target_$index", "divertor_or_exhaust_region",
        "replaceable_finite_area_target", Dict(
            "target_index" => _ctv4_quantity(index, "1")))
end

"Replace implicit exhaust labels by a core/SOL/N-target graph."
function _oev5_closed_exhaust_graph!(raw::Dict{String,Any}, target_count::Int)
    core_matches = filter(region -> String(region["kind"]) in
        ("closed_toroidal_core", "compact_toroid_closed_core"),
        raw["plasma_regions"])
    length(core_matches) == 1 || error("v5 closed family requires one core")
    core = deepcopy(only(core_matches))
    sol = _ctv4_region("oe_sol", "scrape_off_layer",
        "separatrix_to_open_field_line_shell")
    targets = Any[_oev5_target_region(index) for index in 1:target_count]
    raw["plasma_regions"] = Any[core, sol, targets...]
    raw["flux_connections"] = Any[
        Dict("from_region_id" => core["id"], "to_region_id" => "oe_sol",
            "kind" => "cross_separatrix_transport"),
        [Dict("from_region_id" => "oe_sol",
            "to_region_id" => "oe_target_$index",
            "kind" => "open_field_line") for index in 1:target_count]...,
    ]
    raw["exhaust"] = Dict{String,Any}(
        "kind" => "distributed_finite_area_replaceable_targets",
        "region_ids" => ["oe_sol";
            ["oe_target_$index" for index in 1:target_count]],
        "evaluation_requirements" => ["separatrix_field_line_mapping",
            "sol_transport", "target_heat_flux", "target_occlusion",
            "impurity_and_helium_ash_exhaust"],
    )
    return raw
end

"Retain a mirror central cell and expanders while adding plugs and two targets."
function _oev5_mirror_exhaust_graph!(raw::Dict{String,Any})
    central = only(filter(region -> String(region["kind"]) ==
        "mirror_central_cell", raw["plasma_regions"]))
    expanders = sort!(filter(region -> String(region["kind"]) ==
        "end_expander", raw["plasma_regions"]); by = region -> String(region["id"]))
    length(expanders) == 2 || error("v5 mirror requires two end expanders")
    left_plug = _ctv4_region("oe_left_plug", "mirror_end_plug",
        "finite_build_minimum_b_end_plug")
    right_plug = _ctv4_region("oe_right_plug", "mirror_end_plug",
        "finite_build_minimum_b_end_plug")
    targets = Any[_oev5_target_region(1), _oev5_target_region(2)]
    raw["plasma_regions"] = Any[deepcopy(central), left_plug, right_plug,
        deepcopy(expanders[1]), deepcopy(expanders[2]), targets...]
    raw["flux_connections"] = Any[
        Dict("from_region_id" => central["id"],
            "to_region_id" => "oe_left_plug", "kind" => "open_field_line"),
        Dict("from_region_id" => central["id"],
            "to_region_id" => "oe_right_plug", "kind" => "open_field_line"),
        Dict("from_region_id" => "oe_left_plug",
            "to_region_id" => expanders[1]["id"], "kind" => "open_field_line"),
        Dict("from_region_id" => "oe_right_plug",
            "to_region_id" => expanders[2]["id"], "kind" => "open_field_line"),
        Dict("from_region_id" => expanders[1]["id"],
            "to_region_id" => "oe_target_1", "kind" => "open_field_line"),
        Dict("from_region_id" => expanders[2]["id"],
            "to_region_id" => "oe_target_2", "kind" => "open_field_line"),
    ]
    raw["exhaust"] = Dict{String,Any}(
        "kind" => "two_end_expanders_to_replaceable_targets",
        "region_ids" => [String(expanders[1]["id"]),
            String(expanders[2]["id"]), "oe_target_1", "oe_target_2"],
        "evaluation_requirements" => ["end_loss_mapping", "expander_transport",
            "target_heat_flux", "target_occlusion", "direct_energy_recovery"],
    )
    material = String(raw["field_sources"][1]["material"])
    push!(raw["field_sources"], _ctv4_source("oe_minimum_b_anchor",
        "minimum_b_anchor_coil", "finite_build_quadrupole_anchor", material))
    push!(raw["actuators"], _ctv4_actuator("oe_end_bias",
        "biased_electrode", 2.0e6))
    push!(raw["stability_mechanisms"], _ctv4_mechanism(
        "oe_sheared_flow_control", "sheared_flow", ["flute", "dclc"],
        ["oe_end_bias"], ["end bias establishes controllable edge shear"],
        ["anisotropic_mirror_equilibrium", "kinetic_microstability",
            "flow_shear", "actuator_power"], ["mirror_beam_2024"]))
    return raw
end

function _oev5_structural_bases(seeds::Vector{Genome})
    baselines = Dict(genome.family => genome for genome in
        _common_baseline_genomes(seeds))
    tokamak = baselines["tokamak_axisymmetric"]
    bases = Dict{String,Genome}()
    for spec in _oev5_topology_specs()
        raw = if spec.family in ("field_reversed_configuration", "spheromak")
            ct_spec = CompactToroidBuildSpec(spec.family, spec.sustainment)
            deepcopy(build_compact_toroid_genome(tokamak, ct_spec).normalized)
        else
            deepcopy(baselines[spec.family].normalized)
        end
        if spec.family == "magnetic_mirror"
            _oev5_mirror_exhaust_graph!(raw)
        else
            _oev5_closed_exhaust_graph!(raw, spec.target_count)
        end
        raw["mission"]["fuel"] = "D-T"
        raw["mission"]["operating_mode"] = "steady_state"
        raw["provenance"]["origin"] = "generated"
        raw["provenance"]["claim_level"] = "structural_example"
        raw["provenance"]["parent_design_ids"] = [tokamak.design_id]
        push!(raw["provenance"]["notes"],
            "shared_outer_envelope_v5_shape_fill_envelope_separation")
        raw["label"] = "Outer-envelope v5 $(_oev5_key(spec))"
        raw["design_id"] = "pending_outer_envelope_v5_structure"
        provisional = parse_genome(raw)
        report = validate_genome(provisional)
        report.valid || error(join(report.errors, "; "))
        family = validate_family(default_family_registry(), provisional)
        family.valid || error(join(family.errors, "; "))
        raw["design_id"] = "structure_$(provisional.physics_hash[1:20])"
        bases[_oev5_key(spec)] = parse_genome(raw)
    end
    return bases
end

function _oev5_set_targets!(raw::Dict{String,Any}, values::AbstractDict,
        contract::SharedOuterEnvelopeContractV1)
    basis = "shared outer-envelope v5 search gene under $(contract.id)"
    fixed = (
        ("screen_outer_radial_extent", contract.outer_radial_extent_m, "m"),
        ("screen_outer_axial_half_extent", contract.outer_axial_half_extent_m, "m"),
        ("screen_plasma_field", contract.plasma_field_T, "T"),
        ("on_axis_field", contract.plasma_field_T, "T"),
    )
    for (name, value, unit) in fixed
        _ctv4_set_target!(raw, name, value, unit; basis = basis)
    end
    units = Dict(
        "screen_aspect_ratio" => "1", "screen_plasma_fill_fraction" => "1",
        "screen_beta" => "1", "screen_temperature" => "keV",
        "screen_field_quality" => "1", "screen_q95" => "1",
        "screen_mirror_ratio" => "1", "screen_plug_strength" => "1",
        "screen_minimum_b_strength" => "1", "screen_shear_strength" => "1",
        "screen_coil_pack_thickness" => "m", "screen_support_thickness" => "m",
        "screen_exhaust_area_fraction" => "1",
        "screen_exhaust_flux_expansion" => "1",
        "screen_declared_actuator_power" => "W",
    )
    for (name, unit) in units
        _ctv4_set_target!(raw, name, Float64(values[name]), unit; basis = basis)
    end
    return raw
end

function _oev5_update_components!(raw::Dict{String,Any},
        contract::SharedOuterEnvelopeContractV1, features, geometry)
    basis = "v5 component packed inside $(contract.id)"
    for region in raw["plasma_regions"]
        kind = String(region["kind"])
        parameters = region["parameters"]
        if kind == "closed_toroidal_core"
            _set_common_quantity!(parameters, "major_radius", geometry.R, "m";
                basis = basis)
            _set_common_quantity!(parameters, "minor_radius", geometry.a, "m";
                basis = basis)
            _set_common_quantity!(parameters, "half_height", geometry.c, "m";
                basis = basis)
            _set_common_quantity!(parameters, "elongation", 1.65, "1";
                basis = basis)
        elseif kind == "compact_toroid_closed_core"
            _set_common_quantity!(parameters, "half_length", geometry.c, "m";
                basis = basis)
            _set_common_quantity!(parameters, "minor_radius", geometry.a, "m";
                basis = basis)
            _set_common_quantity!(parameters, "central_field",
                contract.plasma_field_T, "T"; basis = basis)
        elseif kind == "mirror_central_cell"
            _set_common_quantity!(parameters, "plasma_radius", geometry.a, "m";
                basis = basis)
            _set_common_quantity!(parameters, "cell_length", 2.0 * geometry.c,
                "m"; basis = basis)
            _set_common_quantity!(parameters, "central_field",
                contract.plasma_field_T, "T"; basis = basis)
        end
    end
    peak_ratio = features.family == "magnetic_mirror" ? features.mirror_ratio :
        features.family == "field_reversed_configuration" ? 1.55 :
        features.family == "spheromak" ? 1.35 :
        1.0 + 1.0 / max(features.shape_ratio - 1.0, 0.25) +
            (features.family == "stellarator" ?
                0.30 * features.three_d_fraction : 0.0)
    current_MA = _oe_plasma_current_MA(features, geometry, contract)
    if features.family == "tokamak_axisymmetric"
        _ctv4_set_target!(raw, "plasma_current", current_MA, "MA";
            basis = basis)
    end
    for source in raw["field_sources"]
        kind = lowercase(String(source["kind"]))
        parameters = source["parameters"]
        if occursin("plasma_current", kind)
            _set_common_quantity!(parameters, "total_current", current_MA, "MA";
                basis = basis)
            source["material"] = "plasma"
        else
            source["material"] = contract.base.magnet_material_envelope
            if occursin("field", kind) || occursin("coil", kind) ||
                    occursin("solenoid", kind)
                _set_common_quantity!(parameters, "on_axis_field",
                    contract.plasma_field_T, "T"; basis = basis)
                _set_common_quantity!(parameters, "peak_field",
                    peak_ratio * contract.plasma_field_T, "T"; basis = basis)
            end
        end
    end
    raw["engineering"]["magnet_technology"] =
        Any[contract.base.magnet_material_envelope]
    return raw
end

function _oev5_instantiate(base::Genome, values::AbstractDict,
        contract::SharedOuterEnvelopeContractV1)
    raw = deepcopy(base.normalized)
    _oev5_set_targets!(raw, values, contract)
    power = Float64(values["screen_declared_actuator_power"])
    actuator_count = length(raw["actuators"])
    if actuator_count > 0
        for actuator in raw["actuators"]
            actuator["parameters"]["power"] = _ctv4_quantity(
                power / actuator_count, "W";
                basis = "v5 declared total actuator power")
        end
    end
    provisional = parse_genome(raw)
    features = _oe_features(provisional)
    geometry = _oe_geometry(features, contract)
    _oev5_update_components!(raw, contract, features, geometry)
    raw["design_id"] = "pending_outer_envelope_v5_elite"
    provisional = parse_genome(raw)
    raw["design_id"] = "concept_$(provisional.physics_hash[1:20])"
    candidate = parse_genome(raw)
    report = validate_genome(candidate)
    report.valid || error(join(report.errors, "; "))
    return candidate
end

function _oev5_ranges(spec::OuterEnvelopeTopologySpecV5, u)
    family = spec.family
    shape = family == "spheromak" ? 1.05 + 1.45 * u[1] :
        family in ("magnetic_mirror", "field_reversed_configuration") ?
            2.0 + 6.0 * u[1] : 2.0 + 4.0 * u[1]
    beta = family == "field_reversed_configuration" ? 0.30 + 0.60 * u[3] :
        family == "spheromak" ? 0.04 + 0.21 * u[3] :
        family == "magnetic_mirror" ? 0.05 + 0.30 * u[3] :
        family == "stellarator" ? 0.015 + 0.075 * u[3] :
        0.015 + 0.085 * u[3]
    actuator = family == "magnetic_mirror" ? 10.0e6 + 70.0e6 * u[12] :
        family == "field_reversed_configuration" ? 8.0e6 + 72.0e6 * u[12] :
        family == "spheromak" ? 8.0e6 + 52.0e6 * u[12] : 0.0
    return Dict{String,Any}(
        "screen_aspect_ratio" => shape,
        "screen_plasma_fill_fraction" => 0.25 + 0.70 * u[2],
        "screen_beta" => beta,
        "screen_temperature" => 8.0 + 22.0 * u[4],
        "screen_field_quality" => 0.82 + 0.18 * u[5],
        "screen_q95" => 2.5 + 3.5 * u[6],
        "screen_mirror_ratio" => 3.0 + 7.0 * u[6],
        "screen_plug_strength" => family == "magnetic_mirror" ?
            0.40 + 0.60 * u[7] : 0.0,
        "screen_minimum_b_strength" => family == "magnetic_mirror" ?
            0.50 + 0.50 * u[8] : 0.0,
        "screen_shear_strength" => family == "magnetic_mirror" ?
            0.30 + 0.70 * u[9] : 0.0,
        "screen_coil_pack_thickness" => 0.30 + 0.60 * u[7],
        "screen_support_thickness" => 0.50 + 1.10 * u[8],
        "screen_exhaust_area_fraction" => 0.08 + 0.42 * u[9],
        "screen_exhaust_flux_expansion" => 1.0 + 5.0 * u[10],
        "screen_declared_actuator_power" => actuator,
    )
end

function _oev5_bin(value::Float64, cuts::Tuple, labels::Tuple)
    for (cut, label) in zip(cuts, labels)
        value < cut && return label
    end
    return labels[end]
end

function _oev5_descriptor(contract::SharedOuterEnvelopeContractV1,
        spec::OuterEnvelopeTopologySpecV5, features)
    fill = _oev5_bin(features.plasma_fill_fraction, (0.45, 0.70, Inf),
        ("fill_low", "fill_mid", "fill_high"))
    shape = if spec.family == "spheromak"
        _oev5_bin(features.shape_ratio, (1.35, 1.85, Inf),
            ("shape_round", "shape_moderate", "shape_prolate"))
    else
        _oev5_bin(features.shape_ratio, (3.2, 5.2, Inf),
            ("shape_low", "shape_mid", "shape_high"))
    end
    beta = _oev5_bin(features.beta, (0.06, 0.18, 0.45, Inf),
        ("beta_low", "beta_mid", "beta_high", "beta_very_high"))
    return join((contract.id, spec.family, spec.sustainment,
        "targets_$(spec.target_count)", fill, shape, beta), "|")
end

function _oev5_quality_key(record::AbstractDict)
    nominal = record["nominal"]
    margin_values = Float64.(collect(Base.values(nominal["margins"])))
    failed = count(value -> value < 0.0, margin_values)
    violation = sum(log1p(-min(0.0, value)) for value in margin_values)
    nominal_pass = nominal["physics_gate_passed"] === true &&
        nominal["engineering_gate_passed"] === true
    return (nominal_pass ? 0 : 1, failed, violation,
        nominal["net_electric_power_W"] > 0.0 ? 0 : 1,
        -Float64(nominal["minimum_normalized_margin"]),
        -Float64(nominal["net_electric_power_W"]),
        canonical_hash(record["features"]))
end

function _oev5_acquisition_features(base::Genome, values::AbstractDict)
    original = _oe_features(base)
    return merge(original, (
        shape_ratio = Float64(values["screen_aspect_ratio"]),
        plasma_fill_fraction = Float64(values["screen_plasma_fill_fraction"]),
        beta = Float64(values["screen_beta"]),
        temperature_keV = Float64(values["screen_temperature"]),
        field_quality = Float64(values["screen_field_quality"]),
        q95 = Float64(values["screen_q95"]),
        mirror_ratio = Float64(values["screen_mirror_ratio"]),
        plug_strength = Float64(values["screen_plug_strength"]),
        minimum_b_strength = Float64(values["screen_minimum_b_strength"]),
        shear_strength = Float64(values["screen_shear_strength"]),
        coil_pack_thickness_m =
            Float64(values["screen_coil_pack_thickness"]),
        support_thickness_m = Float64(values["screen_support_thickness"]),
        exhaust_area_fraction =
            Float64(values["screen_exhaust_area_fraction"]),
        exhaust_flux_expansion =
            Float64(values["screen_exhaust_flux_expansion"]),
        actuator_power_W =
            Float64(values["screen_declared_actuator_power"]),
    ))
end

function _oev5_baseline_records(structural::Dict{String,Genome},
        contracts::Vector{SharedOuterEnvelopeContractV1})
    records = Dict{String,Any}[]
    chosen = OuterEnvelopeTopologySpecV5[]
    seen = Set{String}()
    for spec in _oev5_topology_specs()
        spec.target_count == 2 || continue
        spec.family in seen && continue
        push!(chosen, spec)
        push!(seen, spec.family)
    end
    u = ntuple(_ -> 0.5, 12)
    for contract in contracts, spec in chosen
        base = structural[_oev5_key(spec)]
        candidate = _oev5_instantiate(base, _oev5_ranges(spec, u), contract)
        result = _shared_outer_envelope_result(
            SharedOuterEnvelopeScreenV1(contract;
                allowed_contracts = contracts), candidate)
        push!(records, Dict{String,Any}(
            "contract_id" => contract.id,
            "family" => spec.family,
            "sustainment" => spec.sustainment,
            "target_count" => spec.target_count,
            "design_id" => candidate.design_id,
            "physics_hash" => candidate.physics_hash,
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "net_electric_power_W" => result["nominal"]["net_electric_power_W"],
            "minimum_normalized_margin" =>
                result["nominal"]["minimum_normalized_margin"],
            "result_hash" => result["result_hash"],
        ))
    end
    sort!(records; by = record -> (record["contract_id"], record["family"]))
    return records
end

"""
Run a low-discrepancy, failure-aware QD comparison across five fusion families.

The acquisition model and explicit-graph evaluator use the same radial/axial
outer bounding box. Plasma shape and fill are independent genes. Exhaust target
area is capped by target count and flux expansion, so adding targets is a real
structural choice rather than an unlimited area multiplier.
"""
function run_shared_outer_envelope_qd_v5(seeds::Vector{Genome};
        acquisition_samples::Int = 600_000,
        random_seed::Int = 20260812,
        maximum_graph_elites::Int = 512,
        elites_per_structural_stratum::Int = 3,
        contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    acquisition_samples >= 0 || throw(ArgumentError(
        "acquisition_samples must be non-negative"))
    maximum_graph_elites > 0 || throw(ArgumentError(
        "maximum_graph_elites must be positive"))
    elites_per_structural_stratum > 0 || throw(ArgumentError(
        "elites_per_structural_stratum must be positive"))
    isempty(contracts) && throw(ArgumentError("at least one contract is required"))
    structural = _oev5_structural_bases(seeds)
    specs = _oev5_topology_specs()
    strata = [(contract, spec) for contract in contracts for spec in specs]
    primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37)
    archive = Dict{String,Dict{String,Any}}()
    positive_net_count = 0
    nominal_pass_count = 0
    family_sample_count = Dict(family => 0 for family in sort!(unique(
        spec.family for spec in specs)))
    contract_sample_count = Dict(contract.id => 0 for contract in contracts)
    for index in 1:acquisition_samples
        contract, spec = strata[mod1(index, length(strata))]
        u = ntuple(axis -> _ctv4_halton(index, primes[axis]), length(primes))
        gene_values = _oev5_ranges(spec, u)
        base = structural[_oev5_key(spec)]
        features = _oev5_acquisition_features(base, gene_values)
        nominal = _oe_nominal(base, contract, features)
        nominal["net_electric_power_W"] > 0.0 && (positive_net_count += 1)
        nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true &&
            (nominal_pass_count += 1)
        family_sample_count[spec.family] += 1
        contract_sample_count[contract.id] += 1
        structural_key = "$(contract.id)|$(_oev5_key(spec))"
        proposal = Dict{String,Any}(
            "descriptor" => _oev5_descriptor(contract, spec, features),
            "structural_stratum" => structural_key,
            "contract_id" => contract.id,
            "family" => spec.family,
            "sustainment" => spec.sustainment,
            "target_count" => spec.target_count,
            "features" => gene_values,
            "nominal" => nominal,
        )
        incumbent = get(archive, proposal["descriptor"], nothing)
        if incumbent === nothing ||
                _oev5_quality_key(proposal) < _oev5_quality_key(incumbent)
            archive[proposal["descriptor"]] = proposal
        end
    end

    by_stratum = Dict{String,Vector{Dict{String,Any}}}()
    for proposal in Base.values(archive)
        push!(get!(by_stratum, String(proposal["structural_stratum"]),
            Dict{String,Any}[]), proposal)
    end
    acquisitions = Dict{String,Any}[]
    for stratum in sort!(collect(keys(by_stratum)))
        candidates = by_stratum[stratum]
        sort!(candidates; by = _oev5_quality_key)
        append!(acquisitions, first(candidates,
            min(elites_per_structural_stratum, length(candidates))))
    end
    sort!(acquisitions; by = proposal ->
        (proposal["structural_stratum"], _oev5_quality_key(proposal)))
    if length(acquisitions) > maximum_graph_elites
        acquisitions = first(acquisitions, maximum_graph_elites)
    end

    contract_by_id = Dict(contract.id => contract for contract in contracts)
    spec_by_key = Dict(_oev5_key(spec) => spec for spec in specs)
    records = Dict{String,Any}[]
    for acquisition in acquisitions
        contract = contract_by_id[String(acquisition["contract_id"])]
        spec_key = join(split(String(acquisition["structural_stratum"]), "|")[2:end], "|")
        spec = spec_by_key[spec_key]
        candidate = _oev5_instantiate(structural[_oev5_key(spec)],
            acquisition["features"], contract)
        result = _shared_outer_envelope_result(
            SharedOuterEnvelopeScreenV1(contract;
                allowed_contracts = contracts), candidate)
        push!(records, Dict{String,Any}(
            "contract_id" => contract.id,
            "design_id" => candidate.design_id,
            "physics_hash" => candidate.physics_hash,
            "family" => spec.family,
            "sustainment" => spec.sustainment,
            "target_count" => spec.target_count,
            "descriptor" => acquisition["descriptor"],
            "genome" => candidate.normalized,
            "acquisition" => acquisition,
            "evaluation" => result,
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "positive_net_power_closure_passed" =>
                result["positive_net_power_closure_passed"],
            "promoted" => result["all_five_gates_passed"] === true &&
                result["positive_net_power_closure_passed"] === true,
        ))
    end
    sort!(records; by = record -> (
        record["promoted"] === true ? 0 : 1,
        count(value -> Float64(value) < 0.0,
            Base.values(record["evaluation"]["nominal"]["margins"])),
        sum(log1p(-min(0.0, Float64(value))) for value in
            Base.values(record["evaluation"]["nominal"]["margins"])),
        -Float64(record["evaluation"]["nominal"]["net_electric_power_W"]),
        record["physics_hash"],
    ))
    return Dict{String,Any}(
        "algorithm" => "Halton low-discrepancy acquisition plus balanced failure-aware MAP-Elites graph validation",
        "random_seed" => random_seed,
        "acquisition_samples" => acquisition_samples,
        "contract_count" => length(contracts),
        "contracts" => [_oe_contract_dict(contract) for contract in contracts],
        "topology_count_per_contract" => length(specs),
        "structural_stratum_count" => length(strata),
        "topologies" => [Dict("family" => spec.family,
            "sustainment" => spec.sustainment,
            "target_count" => spec.target_count) for spec in specs],
        "declared_search_domain" => Dict(
            "outer_radial_extent_m" => sort!(unique(
                contract.outer_radial_extent_m for contract in contracts)),
            "outer_axial_half_extent_m" => sort!(unique(
                contract.outer_axial_half_extent_m for contract in contracts)),
            "plasma_field_T" => sort!(unique(
                contract.plasma_field_T for contract in contracts)),
            "plasma_fill_fraction" => [0.25, 0.95],
            "toroidal_aspect_ratio" => [2.0, 6.0],
            "mirror_and_frc_elongation" => [2.0, 8.0],
            "spheromak_elongation" => [1.05, 2.5],
            "temperature_keV" => [8.0, 30.0],
            "field_quality" => [0.82, 1.0],
            "target_count" => [2, 4, 8],
            "exhaust_flux_expansion" => [1.0, 6.0],
        ),
        "family_sample_count" => family_sample_count,
        "contract_sample_count" => contract_sample_count,
        "acquisition_archive_cell_count" => length(archive),
        "acquisition_positive_net_count" => positive_net_count,
        "acquisition_nominal_physics_and_engineering_pass_count" =>
            nominal_pass_count,
        "explicit_graph_elite_count" => length(records),
        "explicit_graph_five_gate_pass_count" => count(record ->
            record["all_five_gates_passed"] === true, records),
        "explicit_graph_positive_net_count" => count(record ->
            record["positive_net_power_closure_passed"] === true, records),
        "promotion_count" => count(record -> record["promoted"] === true, records),
        "same_outer_envelope_baselines" =>
            _oev5_baseline_records(structural, contracts),
        "records" => records,
        "claim_boundary" => _OE_SCREEN_CLAIM_BOUNDARY,
    )
end
