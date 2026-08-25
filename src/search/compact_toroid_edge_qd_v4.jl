"Discrete compact-toroid structural choice used by topology v4."
struct CompactToroidBuildSpec
    family::String
    sustainment::String

    function CompactToroidBuildSpec(family::AbstractString,
            sustainment::AbstractString)
        family_string = String(family)
        sustainment_string = String(sustainment)
        family_string in ("field_reversed_configuration", "spheromak") ||
            throw(ArgumentError("unsupported compact-toroid family $family_string"))
        allowed = family_string == "field_reversed_configuration" ?
            ("beam_driven_fast_ion", "rotating_magnetic_field", "beam_plus_end_bias") :
            ("steady_inductive_helicity_injection", "imposed_dynamo_current_drive")
        sustainment_string in allowed || throw(ArgumentError(
            "unsupported $family_string sustainment $sustainment_string"))
        return new(family_string, sustainment_string)
    end
end

function _ctv4_quantity(value::Real, unit::String; basis::String = "")
    result = Dict{String,Any}("value" => Float64(value), "unit" => unit)
    isempty(basis) || (result["basis"] = basis)
    return result
end

function _ctv4_region(id::String, kind::String, geometry::String,
        parameters::AbstractDict = Dict{String,Any}())
    return Dict{String,Any}(
        "id" => id,
        "kind" => kind,
        "geometry_model" => geometry,
        "parameters" => Dict{String,Any}(parameters),
    )
end

function _ctv4_source(id::String, kind::String, geometry::String,
        material::String, parameters::AbstractDict = Dict{String,Any}())
    return Dict{String,Any}(
        "id" => id,
        "kind" => kind,
        "geometry_model" => geometry,
        "parameters" => Dict{String,Any}(parameters),
        "material" => material,
    )
end

function _ctv4_actuator(id::String, kind::String, power_W::Real)
    return Dict{String,Any}(
        "id" => id,
        "kind" => kind,
        "parameters" => Dict(
            "power" => _ctv4_quantity(power_W, "W")),
    )
end

function _ctv4_mechanism(id::String, mechanism::String, target_modes,
        actuator_ids, assumptions, required_evaluators, source_ids)
    return Dict{String,Any}(
        "id" => id,
        "mechanism" => mechanism,
        "target_modes" => String.(target_modes),
        "actuator_ids" => String.(actuator_ids),
        "assumptions" => String.(assumptions),
        "required_evaluators" => String.(required_evaluators),
        "source_ids" => String.(source_ids),
    )
end

function _ctv4_set_target!(raw::Dict{String,Any}, name::String,
        value::Real, unit::String; basis::String = "topology v4 compact-toroid search")
    raw["mission"]["targets"][name] = _ctv4_quantity(value, unit; basis = basis)
    return raw
end

function _ctv4_common_graph!(raw::Dict{String,Any},
        contract::CommonComparisonContract, elongation::Float64)
    minor_radius = contract.major_scale_m / elongation
    raw["topology"] = Dict{String,Any}(
        "field_line_class" => "compact_toroid",
        "rotation_transform_sources" => ["not_applicable"],
        "expected_flux_surfaces" => true,
        "expected_separatrix" => true,
    )
    raw["symmetry"] = Dict{String,Any}(
        "class" => "axisymmetric",
        "field_periods" => 1,
        "hard_constraints" => [
            "closed compact-toroid core",
            "explicit separatrix",
            "open SOL terminates on two targets",
            "no external toroidal-field coils",
        ],
    )
    raw["plasma_regions"] = Any[
        _ctv4_region("ct_closed_core", "compact_toroid_closed_core",
            "prolate_separatrix_proxy", Dict(
                "half_length" => _ctv4_quantity(contract.major_scale_m, "m"),
                "minor_radius" => _ctv4_quantity(minor_radius, "m"),
                "central_field" => _ctv4_quantity(contract.plasma_field_T, "T"),
            )),
        _ctv4_region("ct_sol", "scrape_off_layer",
            "separatrix_to_open_field_line_shell"),
        _ctv4_region("ct_left_target", "divertor_or_exhaust_region",
            "replaceable_end_target"),
        _ctv4_region("ct_right_target", "divertor_or_exhaust_region",
            "replaceable_end_target"),
    ]
    raw["flux_connections"] = Any[
        Dict("from_region_id" => "ct_closed_core", "to_region_id" => "ct_sol",
            "kind" => "cross_separatrix_transport"),
        Dict("from_region_id" => "ct_sol", "to_region_id" => "ct_left_target",
            "kind" => "open_field_line"),
        Dict("from_region_id" => "ct_sol", "to_region_id" => "ct_right_target",
            "kind" => "open_field_line"),
    ]
    raw["exhaust"] = Dict{String,Any}(
        "kind" => "selective_open_sol_to_replaceable_targets",
        "region_ids" => ["ct_sol", "ct_left_target", "ct_right_target"],
        "evaluation_requirements" => [
            "separatrix_field_line_mapping", "sol_transport",
            "target_heat_flux", "impurity_and_helium_ash_exhaust"],
    )
    return raw
end

function _ctv4_frc_graph!(raw::Dict{String,Any}, spec::CompactToroidBuildSpec,
        contract::CommonComparisonContract)
    raw["family"] = "field_reversed_configuration"
    raw["field_sources"] = Any[
        _ctv4_source("frc_external_solenoid", "axisymmetric_solenoid_coil",
            "finite_build_axisymmetric_solenoid", contract.magnet_material_envelope,
            Dict(
                "on_axis_field" => _ctv4_quantity(contract.plasma_field_T, "T"),
                "peak_field" => _ctv4_quantity(1.55 * contract.plasma_field_T, "T"),
                "coil_count" => _ctv4_quantity(12, "1"),
            )),
        _ctv4_source("frc_diamagnetic_current", "frc_plasma_current",
            "field_reversing_diamagnetic_current_distribution", "plasma",
            Dict("field_reversal_fraction" => _ctv4_quantity(1.0, "1"))),
    ]
    raw["actuators"] = Any[]
    raw["stability_mechanisms"] = Any[]
    if spec.sustainment == "beam_driven_fast_ion"
        push!(raw["actuators"], _ctv4_actuator("frc_left_nbi",
            "neutral_beam_injector", 10.0e6))
        push!(raw["actuators"], _ctv4_actuator("frc_right_nbi",
            "neutral_beam_injector", 10.0e6))
        push!(raw["stability_mechanisms"], _ctv4_mechanism(
            "frc_fast_ion_stability", "fast_ion_kinetic",
            ["global_tilt", "shift", "rotation"],
            ["frc_left_nbi", "frc_right_nbi"],
            ["fast-ion orbits provide finite-Larmor-radius and kinetic stabilization",
             "neutral-beam power is included in the power balance"],
            ["two_fluid_or_hybrid_frc", "global_mhd_spectrum", "fast_ion_orbits",
             "beam_deposition", "actuator_power"],
            ["frc_steinhauer_review_2011", "frc_c2u_gota_2017",
             "frc_c2w_gota_2024"]))
    elseif spec.sustainment == "rotating_magnetic_field"
        push!(raw["actuators"], _ctv4_actuator("frc_rmf_antenna_a",
            "rotating_magnetic_field_antenna", 8.0e6))
        push!(raw["actuators"], _ctv4_actuator("frc_rmf_antenna_b",
            "rotating_magnetic_field_antenna", 8.0e6))
        push!(raw["stability_mechanisms"], _ctv4_mechanism(
            "frc_rmf_stability", "rotating_magnetic_field",
            ["global_tilt", "shift", "rotation"],
            ["frc_rmf_antenna_a", "frc_rmf_antenna_b"],
            ["RMF penetrates sufficiently to sustain current and stabilize the configuration",
             "antenna power is included in the power balance"],
            ["two_fluid_or_hybrid_frc", "rmf_penetration", "global_mhd_spectrum",
             "actuator_power"],
            ["frc_steinhauer_review_2011"]))
    else
        push!(raw["actuators"], _ctv4_actuator("frc_nbi",
            "neutral_beam_injector", 16.0e6))
        push!(raw["actuators"], _ctv4_actuator("frc_left_end_bias",
            "biased_electrode", 2.0e6))
        push!(raw["actuators"], _ctv4_actuator("frc_right_end_bias",
            "biased_electrode", 2.0e6))
        push!(raw["stability_mechanisms"], _ctv4_mechanism(
            "frc_beam_bias_stability", "fast_ion_kinetic",
            ["global_tilt", "shift", "rotation"],
            ["frc_nbi", "frc_left_end_bias", "frc_right_end_bias"],
            ["fast ions and edge bias jointly control global and rotational modes",
             "all active power is included in the power balance"],
            ["two_fluid_or_hybrid_frc", "global_mhd_spectrum", "fast_ion_orbits",
             "flow_shear", "actuator_power"],
            ["frc_c2u_gota_2017", "frc_c2w_gota_2024"]))
    end
    push!(raw["stability_mechanisms"], _ctv4_mechanism(
        "frc_shape_flr_requirement", "finite_larmor_radius",
        ["global_tilt", "shift"], Any[],
        ["reactor-scale deuterium FLR and shaping must be recomputed rather than inherited from argon experiments"],
        ["two_fluid_or_hybrid_frc", "global_mhd_spectrum", "ion_orbit_width"],
        ["frc_gerhardt_inductive_sustainment_2007", "frc_steinhauer_review_2011"]))
    return raw
end

function _ctv4_spheromak_graph!(raw::Dict{String,Any},
        spec::CompactToroidBuildSpec, contract::CommonComparisonContract)
    raw["family"] = "spheromak"
    raw["topology"]["rotation_transform_sources"] = ["self_organized_current"]
    raw["field_sources"] = Any[
        _ctv4_source("spheromak_equilibrium_coils", "axisymmetric_equilibrium_coil",
            "external_axisymmetric_bias_and_shape_coils",
            contract.magnet_material_envelope, Dict(
                "on_axis_field" => _ctv4_quantity(contract.plasma_field_T, "T"),
                "peak_field" => _ctv4_quantity(1.35 * contract.plasma_field_T, "T"),
                "coil_count" => _ctv4_quantity(8, "1"),
            )),
        _ctv4_source("spheromak_plasma_current", "self_organized_plasma_current",
            "relaxed_helical_current_distribution", "plasma",
            Dict("current_profile_control_required" => _ctv4_quantity(1, "1"))),
        _ctv4_source("spheromak_flux_conserver", "external_flux_conserver",
            "close_fitting_conducting_shell_with_exhaust_slots",
            "radiation-tolerant conducting structure",
            Dict("normalized_shell_gap" => _ctv4_quantity(0.12, "1"))),
    ]
    injector_count = spec.sustainment == "imposed_dynamo_current_drive" ? 6 : 2
    injector_power = spec.sustainment == "imposed_dynamo_current_drive" ? 4.0e6 : 6.0e6
    raw["actuators"] = Any[_ctv4_actuator("spheromak_injector_$index",
        "helicity_injector", injector_power) for index in 1:injector_count]
    mechanism = spec.sustainment == "imposed_dynamo_current_drive" ?
        "imposed_dynamo_current_drive" : "steady_inductive_helicity_injection"
    sources = spec.sustainment == "imposed_dynamo_current_drive" ?
        ["spheromak_jarboe_review_1994", "spheromak_hit_si_jarboe_2006",
         "dynomak_2014"] :
        ["spheromak_jarboe_review_1994", "spheromak_hit_si_jarboe_2006"]
    raw["stability_mechanisms"] = Any[
        _ctv4_mechanism("spheromak_sustainment_and_profile", mechanism,
            ["resistive_tearing", "global_tilt", "current_profile_relaxation"],
            ["spheromak_injector_$index" for index in 1:injector_count],
            ["helicity injection sustains the required current profile without intolerable magnetic fluctuations",
             "injector power is included in the power balance"],
            ["resistive_mhd_spheromak", "helicity_balance", "current_profile_control",
             "tearing_spectrum", "actuator_power"], sources),
    ]
    return raw
end

"Build an explicit compact-core/SOL/two-target FRC or spheromak graph."
function build_compact_toroid_genome(parent::Genome, spec::CompactToroidBuildSpec;
        contract::CommonComparisonContract = default_common_comparison_contract())
    raw = deepcopy(parent.normalized)
    elongation = spec.family == "field_reversed_configuration" ? 4.0 : 1.5
    beta = spec.family == "field_reversed_configuration" ? 0.65 : 0.12
    _ctv4_common_graph!(raw, contract, elongation)
    if spec.family == "field_reversed_configuration"
        _ctv4_frc_graph!(raw, spec, contract)
    else
        _ctv4_spheromak_graph!(raw, spec, contract)
    end
    for (name, value, unit) in (
            ("screen_closed_flux_fraction", 1.0, "1"),
            ("screen_edge_open_volume_fraction", 0.08, "1"),
            ("screen_exhaust_area_fraction", 0.20, "1"),
            ("screen_aspect_ratio", elongation, "1"),
            ("screen_beta", beta, "1"),
            ("screen_temperature", 15.0, "keV"),
            ("screen_field_quality", 0.90, "1"),
            ("screen_coil_pack_thickness", 0.50, "m"),
            ("screen_support_thickness", 0.80, "m"),
            ("on_axis_field", contract.plasma_field_T, "T"))
        _ctv4_set_target!(raw, name, value, unit)
    end
    raw["engineering"]["magnet_technology"] = [
        contract.magnet_material_envelope,
        "external axisymmetric coils without linked toroidal-field coils",
    ]
    raw["engineering"]["maintenance"]["architecture"] =
        "axially removable compact-toroid chamber with replaceable end targets"
    raw["engineering"]["maintenance"]["access_paths"] = [
        "left axial target replacement", "right axial target replacement",
        "external coil radial access"]
    raw["engineering"]["required_evaluators"] = [
        "reduced_support_stress", "radial_build", "neutronics_and_tbr",
        "target_heat_flux", "thermal_and_quench", "remote_maintenance",
    ]
    raw["provenance"]["origin"] = "generated"
    raw["provenance"]["source_ids"] = sort!(unique(
        spec.family == "field_reversed_configuration" ?
            ["frc_steinhauer_review_2011", "frc_gerhardt_inductive_sustainment_2007",
             "frc_c2u_gota_2017", "frc_c2w_gota_2024",
             "w7x_island_divertor_2019"] :
            ["spheromak_jarboe_review_1994", "spheromak_hit_si_jarboe_2006",
             "dynomak_2014", "w7x_island_divertor_2019"]))
    raw["provenance"]["parent_design_ids"] = [parent.design_id]
    raw["provenance"]["claim_level"] = "structural_example"
    raw["provenance"]["notes"] = [
        "topology_v4:closed_core_separate_from_open_sol",
        "Bohm transport is a conservative promotion reference, not a validated confinement law",
    ]
    raw["design_id"] = "pending_compact_toroid_v4"
    raw["label"] = "Topology v4 $(spec.family) $(spec.sustainment)"
    provisional = parse_genome(raw)
    report = validate_genome(provisional)
    report.valid || error(join(report.errors, "; "))
    family_report = validate_family(default_family_registry(), provisional)
    family_report.valid || error(join(family_report.errors, "; "))
    raw["design_id"] = "concept_$(provisional.physics_hash[1:20])"
    return parse_genome(raw)
end

function _ctv4_halton(index::Int, base::Int)
    result, factor, value = 0.0, 1.0 / base, index
    while value > 0
        result += factor * (value % base)
        value ÷= base
        factor /= base
    end
    return result
end

function _ctv4_bin(value::Float64, cuts::Tuple, labels::Tuple)
    for (cut, label) in zip(cuts, labels)
        value < cut && return label
    end
    return labels[end]
end

function _ctv4_descriptor(spec::CompactToroidBuildSpec, features)
    elongation = _ctv4_bin(features.elongation, (1.8, 3.5, 5.5, Inf),
        ("compact", "moderate", "elongated", "very_elongated"))
    beta = _ctv4_bin(features.beta, (0.10, 0.25, 0.55, Inf),
        ("beta_low", "beta_mid", "beta_high", "beta_very_high"))
    edge = _ctv4_bin(features.edge_open_volume_fraction, (0.08, 0.16, Inf),
        ("edge_small", "edge_mid", "edge_large"))
    return join((spec.family, spec.sustainment, elongation, beta, edge), "|")
end

function _ctv4_quality_key(record::AbstractDict)
    nominal = record["nominal"]
    nominal_pass = nominal["physics_gate_passed"] === true &&
        nominal["engineering_gate_passed"] === true
    margin_values = Float64.(collect(values(nominal["margins"])))
    failed_margin_count = count(margin -> margin < 0.0, margin_values)
    aggregate_log_violation = sum(log1p(-min(0.0, margin)) for
        margin in margin_values)
    return (
        nominal_pass ? 0 : 1,
        failed_margin_count,
        aggregate_log_violation,
        nominal["net_electric_power_W"] > 0.0 ? 0 : 1,
        -Float64(nominal["bohm_to_required_confinement_ratio"]),
        -Float64(nominal["net_electric_power_W"]),
        -Float64(nominal["minimum_normalized_margin"]),
        canonical_hash(record["features"]),
    )
end

function _ctv4_instantiate(base::Genome, values::AbstractDict,
        contract::CommonComparisonContract)
    raw = deepcopy(base.normalized)
    for (name, unit) in (
            ("screen_aspect_ratio", "1"),
            ("screen_beta", "1"),
            ("screen_temperature", "keV"),
            ("screen_edge_open_volume_fraction", "1"),
            ("screen_exhaust_area_fraction", "1"),
            ("screen_field_quality", "1"),
            ("screen_coil_pack_thickness", "m"),
            ("screen_support_thickness", "m"))
        _ctv4_set_target!(raw, name, Float64(values[name]), unit)
    end
    actuator_count = length(raw["actuators"])
    power_each = Float64(values["declared_total_actuator_power_W"]) / actuator_count
    for actuator in raw["actuators"]
        actuator["parameters"]["power"] = _ctv4_quantity(power_each, "W";
            basis = "topology v4 declared total actuator power")
    end
    elongation = Float64(values["screen_aspect_ratio"])
    radius = contract.major_scale_m / elongation
    core = only(filter(region -> region["id"] == "ct_closed_core",
        raw["plasma_regions"]))
    core["parameters"]["minor_radius"] = _ctv4_quantity(radius, "m")
    raw["design_id"] = "pending_compact_toroid_v4_elite"
    provisional = parse_genome(raw)
    raw["design_id"] = "concept_$(provisional.physics_hash[1:20])"
    return parse_genome(raw)
end

function _ctv4_baseline_records(seeds::Vector{Genome},
        contract::CommonComparisonContract)
    evaluator = UnifiedCrossFamilyScreenV1(contract)
    records = Dict{String,Any}[]
    for genome in _common_baseline_genomes(seeds, contract)
        result = _unified_screen_result(evaluator, genome)
        push!(records, Dict{String,Any}(
            "design_id" => genome.design_id,
            "family" => genome.family,
            "physics_hash" => genome.physics_hash,
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "net_electric_power_W" => result["nominal"]["net_electric_power_W"],
            "result_hash" => result["result_hash"],
            "evaluator" => "sealed unified_cross_family_screen_v1",
        ))
    end
    sort!(records; by = record -> (record["family"], record["design_id"]))
    return records
end

"Run low-discrepancy MAP-Elites-style search over explicit FRC and spheromak graphs."
function run_compact_toroid_edge_qd(seeds::Vector{Genome};
        acquisition_samples::Int = 200_000,
        random_seed::Int = 20260811,
        maximum_graph_elites::Int = 256,
        contract::CommonComparisonContract = default_common_comparison_contract())
    acquisition_samples >= 0 || throw(ArgumentError(
        "acquisition_samples must be non-negative"))
    maximum_graph_elites > 0 || throw(ArgumentError(
        "maximum_graph_elites must be positive"))
    parent = only(filter(genome -> genome.family == "tokamak_axisymmetric", seeds))
    specs = CompactToroidBuildSpec[
        CompactToroidBuildSpec("field_reversed_configuration", variant) for
            variant in ("beam_driven_fast_ion", "rotating_magnetic_field",
                "beam_plus_end_bias")]
    append!(specs, CompactToroidBuildSpec[
        CompactToroidBuildSpec("spheromak", variant) for variant in
            ("steady_inductive_helicity_injection", "imposed_dynamo_current_drive")])
    structural = Dict{String,Genome}()
    for spec in specs
        key = "$(spec.family)|$(spec.sustainment)"
        structural[key] = build_compact_toroid_genome(parent, spec;
            contract = contract)
    end
    primes = (2, 3, 5, 7, 11, 13, 17, 19, 23)
    archive = Dict{String,Dict{String,Any}}()
    positive_net_count = 0
    nominal_pass_count = 0
    for index in 1:acquisition_samples
        spec = specs[mod1(index, length(specs))]
        key = "$(spec.family)|$(spec.sustainment)"
        base = structural[key]
        u = ntuple(axis -> _ctv4_halton(index, primes[axis]), length(primes))
        base_features = _compact_toroid_features(base)
        elongation = spec.family == "field_reversed_configuration" ?
            2.0 + 6.0 * u[1] : 1.05 + 1.45 * u[1]
        beta = spec.family == "field_reversed_configuration" ?
            0.30 + 0.60 * u[2] : 0.04 + 0.21 * u[2]
        actuator_power = spec.family == "field_reversed_configuration" ?
            8.0e6 + 32.0e6 * u[9] : 8.0e6 + 40.0e6 * u[9]
        features = merge(base_features, (
            elongation = elongation,
            beta = beta,
            temperature_keV = 8.0 + 22.0 * u[3],
            edge_open_volume_fraction = 0.02 + 0.23 * u[4],
            exhaust_area_fraction = 0.08 + 0.32 * u[5],
            field_quality = 0.82 + 0.18 * u[6],
            coil_pack_thickness_m = 0.30 + 0.50 * u[7],
            support_thickness_m = 0.50 + 0.90 * u[8],
            actuator_power_W = actuator_power,
        ))
        nominal = _compact_toroid_nominal(base, contract, features)
        nominal["net_electric_power_W"] > 0.0 && (positive_net_count += 1)
        nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true &&
            (nominal_pass_count += 1)
        values = Dict{String,Any}(
            "screen_aspect_ratio" => features.elongation,
            "screen_beta" => features.beta,
            "screen_temperature" => features.temperature_keV,
            "screen_edge_open_volume_fraction" =>
                features.edge_open_volume_fraction,
            "screen_exhaust_area_fraction" => features.exhaust_area_fraction,
            "screen_field_quality" => features.field_quality,
            "screen_coil_pack_thickness" => features.coil_pack_thickness_m,
            "screen_support_thickness" => features.support_thickness_m,
            "declared_total_actuator_power_W" => features.actuator_power_W,
        )
        proposal = Dict{String,Any}(
            "descriptor" => _ctv4_descriptor(spec, features),
            "family" => spec.family,
            "sustainment" => spec.sustainment,
            "features" => values,
            "nominal" => nominal,
        )
        incumbent = get(archive, proposal["descriptor"], nothing)
        if incumbent === nothing ||
                _ctv4_quality_key(proposal) < _ctv4_quality_key(incumbent)
            archive[proposal["descriptor"]] = proposal
        end
    end
    acquisitions = collect(values(archive))
    sort!(acquisitions; by = record ->
        (record["descriptor"], _ctv4_quality_key(record)))
    acquisitions = first(acquisitions,
        min(maximum_graph_elites, length(acquisitions)))
    evaluator = CompactToroidScreenV1(contract)
    records = Dict{String,Any}[]
    for acquisition in acquisitions
        key = "$(acquisition["family"])|$(acquisition["sustainment"])"
        candidate = _ctv4_instantiate(structural[key], acquisition["features"],
            contract)
        result = _compact_toroid_screen_result(evaluator, candidate)
        push!(records, Dict{String,Any}(
            "design_id" => candidate.design_id,
            "physics_hash" => candidate.physics_hash,
            "family" => acquisition["family"],
            "sustainment" => acquisition["sustainment"],
            "descriptor" => acquisition["descriptor"],
            "genome" => candidate.normalized,
            "acquisition" => acquisition,
            "evaluation" => result,
            "common_five_gate_passed" => result["all_five_gates_passed"],
            "positive_net_power_closure_passed" =>
                result["positive_net_power_closure_passed"],
            "promoted" => result["all_five_gates_passed"] === true &&
                result["positive_net_power_closure_passed"] === true,
        ))
    end
    sort!(records; by = record -> (
        record["promoted"] === true ? 0 : 1,
        -Float64(record["evaluation"]["nominal"][
            "bohm_to_required_confinement_ratio"]),
        -Float64(record["evaluation"]["nominal"]["net_electric_power_W"]),
        record["physics_hash"],
    ))
    return Dict{String,Any}(
        "algorithm" =>
            "low-discrepancy acquisition plus MAP-Elites-style explicit compact-toroid graph validation",
        "random_seed" => random_seed,
        "acquisition_samples" => acquisition_samples,
        "declared_search_domain" => Dict(
            "frc_elongation" => [2.0, 8.0],
            "spheromak_elongation" => [1.05, 2.5],
            "frc_beta" => [0.30, 0.90],
            "spheromak_beta" => [0.04, 0.25],
            "temperature_keV" => [8.0, 30.0],
            "edge_open_volume_fraction" => [0.02, 0.25],
            "exhaust_area_fraction" => [0.08, 0.40],
            "field_quality" => [0.82, 1.0],
            "declared_actuator_power_W" => [8.0e6, 48.0e6],
        ),
        "topology_count" => length(specs),
        "topologies" => [Dict("family" => spec.family,
            "sustainment" => spec.sustainment) for spec in specs],
        "same_contract_sealed_v1_baselines" =>
            _ctv4_baseline_records(seeds, contract),
        "acquisition_archive_cell_count" => length(archive),
        "acquisition_positive_net_count" => positive_net_count,
        "acquisition_nominal_physics_and_engineering_pass_count" =>
            nominal_pass_count,
        "explicit_graph_elite_count" => length(records),
        "explicit_graph_five_gate_pass_count" => count(record ->
            record["common_five_gate_passed"] === true, records),
        "explicit_graph_positive_net_count" => count(record ->
            record["positive_net_power_closure_passed"] === true, records),
        "promotion_count" => count(record -> record["promoted"] === true, records),
        "records" => records,
        "claim_boundary" => _CT_SCREEN_CLAIM_BOUNDARY,
    )
end
