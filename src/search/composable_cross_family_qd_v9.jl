"A compatible core/stability/exhaust composition for v9."
struct ComposableTopologySpecV9
    core_family::String
    stability_or_sustainment::String
    exhaust_topology::String
    target_count::Int

    function ComposableTopologySpecV9(core_family::AbstractString,
            stability_or_sustainment::AbstractString,
            exhaust_topology::AbstractString, target_count::Integer)
        family = String(core_family)
        stability = String(stability_or_sustainment)
        exhaust = String(exhaust_topology)
        family in ("tokamak_axisymmetric", "tokamak_3d_hybrid", "stellarator",
            "magnetic_mirror", "field_reversed_configuration", "spheromak") ||
            throw(ArgumentError("unsupported v9 core family $family"))
        target_count in (2, 4, 8) || throw(ArgumentError(
            "v9 target count must be 2, 4, or 8"))
        compatibility = Dict(
            "tokamak_axisymmetric" => Set(["distributed_targets", "super_x_long_leg"]),
            "tokamak_3d_hybrid" => Set(["distributed_targets", "boundary_island_divertor"]),
            "stellarator" => Set(["distributed_targets", "boundary_island_divertor"]),
            "magnetic_mirror" => Set(["two_end_expander"]),
            "field_reversed_configuration" => Set(["distributed_targets"]),
            "spheromak" => Set(["distributed_targets"]),
        )
        exhaust in compatibility[family] || throw(ArgumentError(
            "$exhaust is incompatible with v9 core family $family"))
        family == "magnetic_mirror" && target_count != 2 && throw(ArgumentError(
            "v9 mirror has two axial targets"))
        exhaust == "boundary_island_divertor" && target_count < 4 &&
            throw(ArgumentError("v9 island divertor requires 4 or 8 targets"))
        return new(family, stability, exhaust, Int(target_count))
    end
end

function _ccv9_topology_specs()
    specs = ComposableTopologySpecV9[]
    # Preserve every v5 same-envelope baseline before adding new mechanisms.
    for count in (2, 4, 8)
        push!(specs, ComposableTopologySpecV9("tokamak_axisymmetric",
            "plasma_current_q_profile", "distributed_targets", count))
        for sustainment in ("beam_driven_fast_ion", "rotating_magnetic_field",
                "beam_plus_end_bias")
            push!(specs, ComposableTopologySpecV9(
                "field_reversed_configuration", sustainment,
                "distributed_targets", count))
        end
        for sustainment in ("steady_inductive_helicity_injection",
                "imposed_dynamo_current_drive")
            push!(specs, ComposableTopologySpecV9("spheromak", sustainment,
                "distributed_targets", count))
        end
    end
    push!(specs, ComposableTopologySpecV9("tokamak_axisymmetric",
        "plasma_current_q_profile", "super_x_long_leg", 2))
    for stability in ("fixed_qa_current", "programmable_qa_current")
        for count in (2, 4, 8)
            push!(specs, ComposableTopologySpecV9("tokamak_3d_hybrid",
                stability, "distributed_targets", count))
        end
        for count in (4, 8)
            push!(specs, ComposableTopologySpecV9("tokamak_3d_hybrid",
                stability, "boundary_island_divertor", count))
        end
    end
    for stability in ("quasi_axisymmetric", "quasi_isodynamic")
        for count in (2, 4, 8)
            push!(specs, ComposableTopologySpecV9("stellarator", stability,
                "distributed_targets", count))
        end
        for count in (4, 8)
            push!(specs, ComposableTopologySpecV9("stellarator", stability,
                "boundary_island_divertor", count))
        end
    end
    push!(specs, ComposableTopologySpecV9("magnetic_mirror",
        "minimum_b_beam_plug", "two_end_expander", 2))
    push!(specs, ComposableTopologySpecV9("magnetic_mirror",
        "centrifugal_exb_shear", "two_end_expander", 2))
    return specs
end

_ccv9_key(spec::ComposableTopologySpecV9) = join((spec.core_family,
    spec.stability_or_sustainment, spec.exhaust_topology,
    "targets=$(spec.target_count)"), "|")

function _ccv9_add_source_id!(raw::Dict{String,Any}, source_id::String)
    ids = raw["provenance"]["source_ids"]
    source_id in ids || push!(ids, source_id)
    return raw
end

function _ccv9_add_evaluator!(raw::Dict{String,Any}, evaluator::String)
    items = raw["engineering"]["required_evaluators"]
    evaluator in items || push!(items, evaluator)
    return raw
end

function _ccv9_build_hybrid!(raw::Dict{String,Any}, spec::ComposableTopologySpecV9)
    raw["family"] = "tokamak_3d_hybrid"
    raw["topology"]["rotation_transform_sources"] =
        ["plasma_current", "three_dimensional_external_field"]
    raw["symmetry"] = Dict{String,Any}(
        "class" => "quasi_axisymmetric", "field_periods" => 3,
        "hard_constraints" => ["quasi-axisymmetric error bound",
            "finite-build external-transform coil clearance",
            "current and external transform admit one equilibrium"])
    material = String(raw["field_sources"][1]["material"])
    kind = spec.stability_or_sustainment == "programmable_qa_current" ?
        "programmable_planar_dipole_coil" : "three_dimensional_modular_coil"
    geometry = spec.stability_or_sustainment == "programmable_qa_current" ?
        "six_geometry_symmetry_reduced_programmable_array" :
        "finite_build_quasi_axisymmetric_modular_coils"
    coil_count = spec.stability_or_sustainment == "programmable_qa_current" ? 288 : 18
    push!(raw["field_sources"], _ctv4_source("ccv9_external_transform",
        kind, geometry, material, Dict(
            "coil_count" => _ctv4_quantity(coil_count, "1"),
            "field_periods" => _ctv4_quantity(3, "1"),
            "external_transform_fraction_gene" => _ctv4_quantity(0.50, "1"))))
    push!(raw["stability_mechanisms"], _ctv4_mechanism(
        "ccv9_qa_current_intersection", "quasi_symmetry",
        ["radial_drift", "external_kink", "vertical_mode", "tearing"], Any[],
        ["tokamak and stellarator rejection proxies must both pass",
            "no hybrid synergy credit is used"],
        ["free_boundary_grad_shafranov", "vmec_or_desc", "boozer_transform",
            "hybrid_current_profile", "all_mode_stability", "coil_optimization"],
        ["ncsx_physics_zarnstorff_2001"]))
    _ccv9_add_source_id!(raw, "ncsx_physics_zarnstorff_2001")
    if spec.stability_or_sustainment == "programmable_qa_current"
        _ccv9_add_source_id!(raw, "programmable_hybrid_yu_2026_preprint")
        push!(raw["actuators"], _ctv4_actuator("ccv9_programmable_trim_power",
            "programmable_external_field_supply", 2.0e6))
    end
    for evaluator in ("free_boundary_grad_shafranov", "vmec_or_desc",
            "boozer_transform", "hybrid_current_profile", "coil_optimization")
        _ccv9_add_evaluator!(raw, evaluator)
    end
    return raw
end

function _ccv9_build_stellarator_variant!(raw::Dict{String,Any},
        spec::ComposableTopologySpecV9)
    raw["symmetry"]["class"] = spec.stability_or_sustainment
    push!(raw["symmetry"]["hard_constraints"],
        "finite-build coils reproduce the selected symmetry class")
    push!(raw["stability_mechanisms"], _ctv4_mechanism(
        "ccv9_selected_symmetry", "quasi_symmetry",
        ["neoclassical_radial_drift", "energetic_particle_loss"], Any[],
        ["the selected symmetry survives finite-beta and coil discretization"],
        ["vmec_or_desc", "boozer_transform", "alpha_orbits", "coil_optimization"],
        ["stellarator_precise_qs_landreman_paul_2022"]))
    return raw
end

function _ccv9_build_exhaust!(raw::Dict{String,Any},
        spec::ComposableTopologySpecV9)
    if spec.core_family == "magnetic_mirror"
        _oev5_mirror_exhaust_graph!(raw)
        raw["exhaust"]["kind"] = "two_end_expander_to_finite_targets"
        return raw
    end
    _oev5_closed_exhaust_graph!(raw, spec.target_count)
    if spec.exhaust_topology == "super_x_long_leg"
        raw["exhaust"]["kind"] = "super_x_long_leg_to_finite_targets"
        for region in raw["plasma_regions"]
            region["kind"] == "divertor_or_exhaust_region" || continue
            region["geometry_model"] = "large_major_radius_super_x_target"
        end
        material = String(raw["field_sources"][1]["material"])
        push!(raw["field_sources"], _ctv4_source("ccv9_super_x_coils",
            "super_x_divertor_coil", "finite_build_axisymmetric_long_leg_coils",
            material, Dict("coil_count" => _ctv4_quantity(4, "1"))))
        _ccv9_add_source_id!(raw, "superx_havlickova_2014")
        _ccv9_add_source_id!(raw, "superx_harrison_2021_preprint")
        _ccv9_add_evaluator!(raw, "solps_or_equivalent_long_leg_exhaust")
    elseif spec.exhaust_topology == "boundary_island_divertor"
        raw["exhaust"]["kind"] = "boundary_island_divertor_to_finite_targets"
        for region in raw["plasma_regions"]
            region["kind"] == "divertor_or_exhaust_region" || continue
            region["geometry_model"] = "replaceable_boundary_island_target"
        end
        material = String(raw["field_sources"][1]["material"])
        push!(raw["field_sources"], _ctv4_source("ccv9_island_trim_coils",
            "boundary_island_control_coil", "finite_build_boundary_resonant_trim_set",
            material, Dict("coil_count" => _ctv4_quantity(spec.target_count, "1"))))
        push!(raw["actuators"], _ctv4_actuator("ccv9_island_trim_power",
            "boundary_island_feedback_supply", 2.0e6))
        _ccv9_add_source_id!(raw, "w7x_divertor_jakubowski_2021")
        _ccv9_add_evaluator!(raw, "spec_or_field_line_island_exhaust")
    end
    return raw
end

function _ccv9_add_rotation!(raw::Dict{String,Any})
    push!(raw["actuators"], _ctv4_actuator("ccv9_central_electrode",
        "high_voltage_central_electrode", 20.0e6))
    push!(raw["stability_mechanisms"], _ctv4_mechanism(
        "ccv9_centrifugal_rotation", "sheared_flow",
        ["parallel_end_loss", "flute_interchange", "convective_cells"],
        ["ccv9_central_electrode"],
        ["centrifugal confinement credit is capped at three",
            "voltage, insulation, neutral fraction, and rotation inventory are gated"],
        ["anisotropic_mirror_equilibrium", "rotation_profile", "flow_shear",
            "critical_ionization_velocity", "high_voltage_insulation"],
        ["mcx_centrifugal_teodorescu_2010", "mcx_final_report_hassam_2012",
            "mcx_civ_short_2021"]))
    for source_id in ("mcx_centrifugal_teodorescu_2010",
            "mcx_final_report_hassam_2012", "mcx_civ_short_2021")
        _ccv9_add_source_id!(raw, source_id)
    end
    for evaluator in ("rotation_profile", "critical_ionization_velocity",
            "high_voltage_insulation")
        _ccv9_add_evaluator!(raw, evaluator)
    end
    return raw
end

function _ccv9_structural_bases(seeds::Vector{Genome})
    baselines = Dict(genome.family => genome for genome in
        _common_baseline_genomes(seeds))
    tokamak = baselines["tokamak_axisymmetric"]
    bases = Dict{String,Genome}()
    for spec in _ccv9_topology_specs()
        raw = if spec.core_family in ("field_reversed_configuration", "spheromak")
            ct_spec = CompactToroidBuildSpec(spec.core_family,
                spec.stability_or_sustainment)
            deepcopy(build_compact_toroid_genome(tokamak, ct_spec).normalized)
        elseif spec.core_family == "tokamak_3d_hybrid"
            value = deepcopy(tokamak.normalized)
            _ccv9_build_hybrid!(value, spec)
        else
            value = deepcopy(baselines[spec.core_family].normalized)
            spec.core_family == "stellarator" &&
                _ccv9_build_stellarator_variant!(value, spec)
            value
        end
        _ccv9_build_exhaust!(raw, spec)
        spec.stability_or_sustainment == "centrifugal_exb_shear" &&
            _ccv9_add_rotation!(raw)
        raw["mission"]["fuel"] = "D-T"
        raw["mission"]["operating_mode"] = "steady_state"
        raw["provenance"]["origin"] = "generated"
        raw["provenance"]["claim_level"] = "structural_example"
        raw["provenance"]["parent_design_ids"] = [tokamak.design_id]
        push!(raw["provenance"]["notes"],
            "composable_cross_family_v9_evidence_compatibility_grammar")
        raw["label"] = "Composable v9 $(_ccv9_key(spec))"
        raw["design_id"] = "pending_composable_v9_structure"
        basis = "fixed evidence-constrained v9 mechanism declaration"
        fixed = spec.exhaust_topology == "super_x_long_leg" ? 0.80 :
            spec.exhaust_topology == "boundary_island_divertor" ? 0.55 :
            spec.exhaust_topology == "two_end_expander" ? 0.45 : 0.0
        _ctv4_set_target!(raw, "screen_exhaust_extra_build", fixed, "m";
            basis = basis)
        if spec.stability_or_sustainment == "centrifugal_exb_shear"
            for (name, value, unit) in (
                    ("screen_rotation_mach", 2.0, "1"),
                    ("screen_rotation_voltage", 8.0e6, "V"),
                    ("screen_rotation_insulation_thickness", 0.50, "m"),
                    ("screen_neutral_fraction", 2.0e-5, "1"))
                _ctv4_set_target!(raw, name, value, unit; basis = basis)
            end
        end
        provisional = parse_genome(raw)
        report = validate_genome(provisional)
        report.valid || error(join(report.errors, "; "))
        family = validate_family(default_family_registry(), provisional)
        family.valid || error(join(family.errors, "; "))
        raw["design_id"] = "structure_$(provisional.physics_hash[1:20])"
        bases[_ccv9_key(spec)] = parse_genome(raw)
    end
    return bases
end

function _ccv9_ranges(spec::ComposableTopologySpecV9, u)
    family = spec.core_family
    shape = family == "spheromak" ? 1.05 + 1.45 * u[1] :
        family in ("magnetic_mirror", "field_reversed_configuration") ?
            2.0 + 6.0 * u[1] : 2.0 + 4.0 * u[1]
    beta = family == "field_reversed_configuration" ? 0.30 + 0.60 * u[3] :
        family == "spheromak" ? 0.04 + 0.21 * u[3] :
        family == "magnetic_mirror" ? 0.05 + 0.30 * u[3] :
        family in ("stellarator", "tokamak_3d_hybrid") ?
            0.015 + 0.075 * u[3] : 0.015 + 0.085 * u[3]
    actuator = family == "magnetic_mirror" ? 20.0e6 + 100.0e6 * u[12] :
        family == "field_reversed_configuration" ? 8.0e6 + 72.0e6 * u[12] :
        family == "spheromak" ? 8.0e6 + 52.0e6 * u[12] :
        spec.stability_or_sustainment == "programmable_qa_current" ?
            2.0e6 + 28.0e6 * u[12] :
        spec.exhaust_topology == "boundary_island_divertor" ?
            2.0e6 + 10.0e6 * u[12] : 0.0
    current_share = family == "tokamak_3d_hybrid" ? 0.20 + 0.45 * u[7] :
        family == "tokamak_axisymmetric" ? 1.0 : 0.0
    external_share = family == "tokamak_3d_hybrid" ? 1.0 - current_share :
        family == "stellarator" ? 1.0 : 0.0
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
        "screen_plasma_current_transform_fraction" => current_share,
        "screen_external_transform_fraction" => external_share,
        "screen_three_dimensional_field_fraction" =>
            family in ("stellarator", "tokamak_3d_hybrid") ?
                0.50 + 0.50 * u[11] : 0.0,
    )
end

function _ccv9_set_targets!(raw::Dict{String,Any}, values::AbstractDict,
        contract::SharedOuterEnvelopeContractV1)
    _oev5_set_targets!(raw, values, contract)
    basis = "composable v9 transform-share gene under $(contract.id)"
    for name in ("screen_plasma_current_transform_fraction",
            "screen_external_transform_fraction",
            "screen_three_dimensional_field_fraction")
        _ctv4_set_target!(raw, name, Float64(values[name]), "1"; basis = basis)
    end
    return raw
end

function _ccv9_update_components!(raw::Dict{String,Any},
        contract::SharedOuterEnvelopeContractV1, features, geometry)
    scored = _ccv9_scored_features(parse_genome(raw), contract, features)
    mapped = features.family == "tokamak_3d_hybrid" ?
        merge(scored, (family = "stellarator",)) : scored
    _oev5_update_components!(raw, contract, mapped, geometry)
    if features.family == "tokamak_3d_hybrid"
        current_features = merge(scored, (family = "tokamak_axisymmetric",))
        current_MA = _oe_plasma_current_MA(current_features, geometry, contract)
        _ctv4_set_target!(raw, "plasma_current", current_MA, "MA";
            basis = "v9 hybrid q95 current consistency")
        for source in raw["field_sources"]
            occursin("plasma_current", lowercase(String(source["kind"]))) || continue
            _set_common_quantity!(source["parameters"], "total_current", current_MA,
                "MA"; basis = "v9 hybrid q95 current consistency")
            source["material"] = "plasma"
        end
    end
    return raw
end

function _ccv9_instantiate(base::Genome, values::AbstractDict,
        contract::SharedOuterEnvelopeContractV1)
    raw = deepcopy(base.normalized)
    _ccv9_set_targets!(raw, values, contract)
    power = Float64(values["screen_declared_actuator_power"])
    if !isempty(raw["actuators"])
        for actuator in raw["actuators"]
            actuator["parameters"]["power"] = _ctv4_quantity(
                power / length(raw["actuators"]), "W";
                basis = "v9 declared total actuator power")
        end
    end
    provisional = parse_genome(raw)
    features = _oe_features(provisional)
    geometry = _ccv9_geometry(provisional, contract, features)
    _ccv9_update_components!(raw, contract, features, geometry)
    raw["design_id"] = "pending_composable_v9_elite"
    provisional = parse_genome(raw)
    raw["design_id"] = "concept_$(provisional.physics_hash[1:20])"
    candidate = parse_genome(raw)
    report = validate_genome(candidate)
    report.valid || error(join(report.errors, "; "))
    return candidate
end

function _ccv9_acquisition_features(base::Genome, values::AbstractDict)
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
        coil_pack_thickness_m = Float64(values["screen_coil_pack_thickness"]),
        support_thickness_m = Float64(values["screen_support_thickness"]),
        exhaust_area_fraction = Float64(values["screen_exhaust_area_fraction"]),
        exhaust_flux_expansion = Float64(values["screen_exhaust_flux_expansion"]),
        actuator_power_W = Float64(values["screen_declared_actuator_power"]),
        plasma_current_fraction =
            Float64(values["screen_plasma_current_transform_fraction"]),
        external_transform_fraction =
            Float64(values["screen_external_transform_fraction"]),
        three_d_fraction =
            Float64(values["screen_three_dimensional_field_fraction"]),
    ))
end

function _ccv9_descriptor(contract::SharedOuterEnvelopeContractV1,
        spec::ComposableTopologySpecV9, features)
    fill = _oev5_bin(features.plasma_fill_fraction, (0.45, 0.70, Inf),
        ("fill_low", "fill_mid", "fill_high"))
    shape = spec.core_family == "spheromak" ?
        _oev5_bin(features.shape_ratio, (1.35, 1.85, Inf),
            ("shape_round", "shape_moderate", "shape_prolate")) :
        _oev5_bin(features.shape_ratio, (3.2, 5.2, Inf),
            ("shape_low", "shape_mid", "shape_high"))
    beta = _oev5_bin(features.beta, (0.06, 0.18, 0.45, Inf),
        ("beta_low", "beta_mid", "beta_high", "beta_very_high"))
    return join((contract.id, spec.core_family,
        spec.stability_or_sustainment, spec.exhaust_topology,
        "targets_$(spec.target_count)", fill, shape, beta), "|")
end

_ccv9_quality_key(record::AbstractDict) = _oev5_quality_key(record)

function _ccv9_baseline_records(structural::Dict{String,Genome},
        contracts::Vector{SharedOuterEnvelopeContractV1})
    chosen = ComposableTopologySpecV9[]
    seen = Set{String}()
    for spec in _ccv9_topology_specs()
        spec.core_family in seen && continue
        push!(chosen, spec)
        push!(seen, spec.core_family)
    end
    records = Dict{String,Any}[]
    u = ntuple(_ -> 0.5, 12)
    for contract in contracts, spec in chosen
        candidate = _ccv9_instantiate(structural[_ccv9_key(spec)],
            _ccv9_ranges(spec, u), contract)
        result = _composable_cross_family_result(
            ComposableCrossFamilyScreenV1(contract;
                allowed_contracts = contracts), candidate)
        push!(records, Dict{String,Any}(
            "contract_id" => contract.id, "core_family" => spec.core_family,
            "stability_or_sustainment" => spec.stability_or_sustainment,
            "exhaust_topology" => spec.exhaust_topology,
            "design_id" => candidate.design_id,
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "net_electric_power_W" => result["nominal"]["net_electric_power_W"],
            "minimum_normalized_margin" =>
                result["nominal"]["minimum_normalized_margin"],
            "result_hash" => result["result_hash"],
        ))
    end
    sort!(records; by = record -> (record["contract_id"], record["core_family"]))
    return records
end

function _ccv9_medium_fidelity_route(family::String, stability::String)
    if family == "tokamak_axisymmetric"
        return ["free_boundary_grad_shafranov", "pf_static_robustness",
            "solps_exhaust"]
    elseif family == "tokamak_3d_hybrid"
        return ["free_boundary_grad_shafranov", "vmec_or_desc",
            "boozer_transform", "hybrid_current_profile", "coil_optimization",
            "spec_or_solps_exhaust"]
    elseif family == "stellarator"
        return ["vmec_or_desc", "boozer_transform", "alpha_orbits",
            "coil_optimization", "spec_island_exhaust"]
    elseif family == "magnetic_mirror"
        return stability == "centrifugal_exb_shear" ?
            ["anisotropic_mirror_equilibrium", "reduced_or_full_orbits",
                "rotation_profile", "critical_ionization_velocity",
                "high_voltage_insulation", "end_expander_transport"] :
            ["anisotropic_mirror_equilibrium", "reduced_or_full_orbits",
                "kinetic_microstability", "end_expander_transport"]
    elseif family == "field_reversed_configuration"
        return ["two_fluid_or_hybrid_frc", "fast_ion_orbits", "sol_exhaust"]
    end
    return ["resistive_mhd_spheromak", "helicity_injection", "sol_exhaust"]
end

"Run balanced, evidence-constrained core/stability/exhaust quality diversity."
function run_composable_cross_family_qd_v9(seeds::Vector{Genome};
        acquisition_samples::Int = 300_000,
        random_seed::Int = 20260813,
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
    structural = _ccv9_structural_bases(seeds)
    specs = _ccv9_topology_specs()
    strata = [(contract, spec) for contract in contracts for spec in specs]
    primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37)
    archive = Dict{String,Dict{String,Any}}()
    positive_net_count = 0
    nominal_pass_count = 0
    family_sample_count = Dict(family => 0 for family in sort!(unique(
        spec.core_family for spec in specs)))
    mechanism_sample_count = Dict(spec.stability_or_sustainment => 0 for spec in specs)
    exhaust_sample_count = Dict(spec.exhaust_topology => 0 for spec in specs)
    contract_sample_count = Dict(contract.id => 0 for contract in contracts)
    for index in 1:acquisition_samples
        contract, spec = strata[mod1(index, length(strata))]
        u = ntuple(axis -> _ctv4_halton(index, primes[axis]), length(primes))
        values = _ccv9_ranges(spec, u)
        base = structural[_ccv9_key(spec)]
        features = _ccv9_acquisition_features(base, values)
        nominal = _ccv9_nominal(base, contract, features)
        nominal["net_electric_power_W"] > 0.0 && (positive_net_count += 1)
        nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true &&
            (nominal_pass_count += 1)
        family_sample_count[spec.core_family] += 1
        mechanism_sample_count[spec.stability_or_sustainment] += 1
        exhaust_sample_count[spec.exhaust_topology] += 1
        contract_sample_count[contract.id] += 1
        structural_key = "$(contract.id)|$(_ccv9_key(spec))"
        proposal = Dict{String,Any}(
            "descriptor" => _ccv9_descriptor(contract, spec, features),
            "structural_stratum" => structural_key,
            "contract_id" => contract.id, "core_family" => spec.core_family,
            "stability_or_sustainment" => spec.stability_or_sustainment,
            "exhaust_topology" => spec.exhaust_topology,
            "target_count" => spec.target_count,
            "features" => values, "nominal" => nominal,
        )
        incumbent = get(archive, proposal["descriptor"], nothing)
        if incumbent === nothing ||
                _ccv9_quality_key(proposal) < _ccv9_quality_key(incumbent)
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
        sort!(candidates; by = _ccv9_quality_key)
        append!(acquisitions, first(candidates,
            min(elites_per_structural_stratum, length(candidates))))
    end
    sort!(acquisitions; by = proposal ->
        (proposal["structural_stratum"], _ccv9_quality_key(proposal)))
    length(acquisitions) > maximum_graph_elites &&
        (acquisitions = first(acquisitions, maximum_graph_elites))
    contract_by_id = Dict(contract.id => contract for contract in contracts)
    spec_by_key = Dict(_ccv9_key(spec) => spec for spec in specs)
    records = Dict{String,Any}[]
    for acquisition in acquisitions
        contract = contract_by_id[String(acquisition["contract_id"])]
        spec_key = join(split(String(acquisition["structural_stratum"]), "|")[2:end], "|")
        spec = spec_by_key[spec_key]
        candidate = _ccv9_instantiate(structural[_ccv9_key(spec)],
            acquisition["features"], contract)
        result = _composable_cross_family_result(
            ComposableCrossFamilyScreenV1(contract;
                allowed_contracts = contracts), candidate)
        promoted = result["all_five_gates_passed"] === true &&
            result["positive_net_power_closure_passed"] === true
        push!(records, Dict{String,Any}(
            "contract_id" => contract.id, "design_id" => candidate.design_id,
            "physics_hash" => candidate.physics_hash,
            "core_family" => spec.core_family,
            "stability_or_sustainment" => spec.stability_or_sustainment,
            "exhaust_topology" => spec.exhaust_topology,
            "target_count" => spec.target_count,
            "descriptor" => acquisition["descriptor"],
            "genome" => candidate.normalized, "acquisition" => acquisition,
            "evaluation" => result,
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "positive_net_power_closure_passed" =>
                result["positive_net_power_closure_passed"],
            "promoted" => promoted,
            "medium_fidelity_route" => promoted ?
                _ccv9_medium_fidelity_route(spec.core_family,
                    spec.stability_or_sustainment) : String[],
        ))
    end
    sort!(records; by = record -> (
        record["promoted"] === true ? 0 : 1,
        count(value -> Float64(value) < 0.0,
            Base.values(record["evaluation"]["nominal"]["margins"])),
        sum(log1p(-min(0.0, Float64(value))) for value in
            Base.values(record["evaluation"]["nominal"]["margins"])),
        -Float64(record["evaluation"]["nominal"]["net_electric_power_W"]),
        record["physics_hash"]))
    return Dict{String,Any}(
        "algorithm" => "Halton acquisition plus compatibility-constrained failure-aware MAP-Elites",
        "random_seed" => random_seed,
        "acquisition_samples" => acquisition_samples,
        "contract_count" => length(contracts),
        "contracts" => [_oe_contract_dict(contract) for contract in contracts],
        "topology_count_per_contract" => length(specs),
        "structural_stratum_count" => length(strata),
        "topologies" => [Dict(
            "core_family" => spec.core_family,
            "stability_or_sustainment" => spec.stability_or_sustainment,
            "exhaust_topology" => spec.exhaust_topology,
            "target_count" => spec.target_count) for spec in specs],
        "compatibility_matrix" => Dict(
            "tokamak_axisymmetric" => ["distributed_targets", "super_x_long_leg"],
            "tokamak_3d_hybrid" => ["distributed_targets", "boundary_island_divertor"],
            "stellarator" => ["distributed_targets", "boundary_island_divertor"],
            "magnetic_mirror" => ["two_end_expander"],
            "field_reversed_configuration" => ["distributed_targets"],
            "spheromak" => ["distributed_targets"]),
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
            "temperature_keV" => [8.0, 30.0],
            "field_quality" => [0.82, 1.0],
            "qa_hybrid_current_transform_share" => [0.20, 0.65],
            "exhaust_flux_expansion" => [1.0, 6.0],
            "centrifugal_mach_fixed_structural_probe" => 2.0,
            "experimental_performance_multiplier_used" => false),
        "family_sample_count" => family_sample_count,
        "mechanism_sample_count" => mechanism_sample_count,
        "exhaust_sample_count" => exhaust_sample_count,
        "contract_sample_count" => contract_sample_count,
        "acquisition_archive_cell_count" => length(archive),
        "acquisition_positive_net_count" => positive_net_count,
        "acquisition_nominal_physics_and_engineering_pass_count" => nominal_pass_count,
        "explicit_graph_elite_count" => length(records),
        "explicit_graph_five_gate_pass_count" => count(record ->
            record["all_five_gates_passed"] === true, records),
        "explicit_graph_positive_net_count" => count(record ->
            record["positive_net_power_closure_passed"] === true, records),
        "promotion_count" => count(record -> record["promoted"] === true, records),
        "same_outer_envelope_baselines" =>
            _ccv9_baseline_records(structural, contracts),
        "records" => records,
        "claim_boundary" => _CCV9_SCREEN_CLAIM_BOUNDARY,
    )
end
