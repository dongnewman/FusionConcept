"A v9 control or a new evidence-bounded mechanism composition for v10."
struct MechanismExpansionTopologySpecV10
    core_family::String
    mechanism::String
    exhaust_topology::String
    target_count::Int
    control_v9_key::Union{Nothing,String}

    function MechanismExpansionTopologySpecV10(core_family::AbstractString,
            mechanism::AbstractString, exhaust_topology::AbstractString,
            target_count::Integer; control_v9_key::Union{Nothing,String} = nothing)
        family = String(core_family)
        mechanism_string = String(mechanism)
        exhaust = String(exhaust_topology)
        family in ("tokamak_axisymmetric", "tokamak_3d_hybrid", "stellarator",
            "magnetic_mirror", "sheared_flow_z_pinch",
            "field_reversed_configuration", "spheromak") ||
            throw(ArgumentError("unsupported v10 family $family"))
        family == "sheared_flow_z_pinch" && target_count != 2 &&
            throw(ArgumentError("v10 Z pinch requires two axial targets"))
        family == "magnetic_mirror" && target_count != 2 &&
            throw(ArgumentError("v10 mirror requires two axial targets"))
        return new(family, mechanism_string, exhaust, Int(target_count), control_v9_key)
    end
end

function _mev10_topology_specs()
    specs = MechanismExpansionTopologySpecV10[]
    for old in _ccv9_topology_specs()
        push!(specs, MechanismExpansionTopologySpecV10(old.core_family,
            old.stability_or_sustainment, old.exhaust_topology, old.target_count;
            control_v9_key = _ccv9_key(old)))
    end
    for mechanism in ("thermal_electrostatic_barrier", "kinetic_stabilizer",
            "thermal_barrier_plus_kinetic")
        for exhaust in ("two_end_expander", "two_end_direct_converter")
            push!(specs, MechanismExpansionTopologySpecV10("magnetic_mirror",
                mechanism, exhaust, 2))
        end
    end
    for mechanism in ("sheared_flow_single_pulse_z_pinch",
            "sheared_flow_repetitive_z_pinch")
        push!(specs, MechanismExpansionTopologySpecV10("sheared_flow_z_pinch",
            mechanism, "two_linear_end_targets", 2))
    end
    return specs
end

function _mev10_key(spec::MechanismExpansionTopologySpecV10)
    kind = spec.control_v9_key === nothing ? "new" : "v9_control"
    return join((kind, spec.core_family, spec.mechanism, spec.exhaust_topology,
        "targets=$(spec.target_count)"), "|")
end

_mev10_is_control(spec::MechanismExpansionTopologySpecV10) =
    spec.control_v9_key !== nothing

function _mev10_add_source_id!(raw::Dict{String,Any}, source_id::String)
    ids = raw["provenance"]["source_ids"]
    source_id in ids || push!(ids, source_id)
    return raw
end

function _mev10_add_required_evaluator!(raw::Dict{String,Any}, id::String)
    evaluators = raw["engineering"]["required_evaluators"]
    id in evaluators || push!(evaluators, id)
    return raw
end

function _mev10_build_tandem!(raw::Dict{String,Any},
        spec::MechanismExpansionTopologySpecV10)
    has_barrier = occursin("thermal", spec.mechanism)
    has_stabilizer = occursin("kinetic", spec.mechanism)
    direct = spec.exhaust_topology == "two_end_direct_converter"
    raw["label"] = "Mechanism v10 $(_mev10_key(spec))"
    raw["provenance"]["origin"] = "generated"
    raw["provenance"]["claim_level"] = "structural_example"
    push!(raw["provenance"]["notes"],
        "mechanism_expansion_v10_no_imported_performance_multiplier")
    basis = "fixed v10 tandem mechanism declaration"
    for (name, value, unit) in (
            ("screen_tandem_potential_ratio", has_barrier ? 1.5 : 0.0, "1"),
            ("screen_tandem_plug_density_ratio", has_barrier ? exp(1.5) : 1.0, "1"),
            ("screen_tandem_beam_energy", has_barrier ? 75.0 : 0.0, "keV"),
            ("screen_tandem_beam_power", has_barrier ? 20.0e6 : 0.0, "W"),
            ("screen_tandem_ech_power", has_barrier ? 5.0e6 : 0.0, "W"),
            ("screen_kinetic_stabilizer_pressure_fraction",
                has_stabilizer ? 0.08 : 0.0, "1"),
            ("screen_kinetic_stabilizer_replenishment_time", 0.05, "s"),
            ("screen_direct_converter_recovery_fraction", direct ? 0.25 : 0.0, "1"),
            ("screen_direct_converter_voltage", direct ? 500.0e3 : 0.0, "V"),
            ("screen_direct_converter_build", direct ? 0.20 : 0.0, "m"))
        _ctv4_set_target!(raw, name, value, unit; basis = basis)
    end
    _ctv4_set_target!(raw, "screen_exhaust_extra_build", direct ? 0.80 : 0.50,
        "m"; basis = basis)
    if has_barrier
        push!(raw["actuators"], _ctv4_actuator("v10_tandem_plug_nbi_left",
            "nbi", 10.0e6))
        push!(raw["actuators"], _ctv4_actuator("v10_tandem_plug_nbi_right",
            "nbi", 10.0e6))
        push!(raw["actuators"], _ctv4_actuator("v10_tandem_plug_ech",
            "ech", 5.0e6))
        push!(raw["stability_mechanisms"], _ctv4_mechanism(
            "v10_tandem_thermal_barrier", "other",
            ["parallel_end_loss", "trapped_particle_mode", "dclc"],
            ["v10_tandem_plug_nbi_left", "v10_tandem_plug_nbi_right",
                "v10_tandem_plug_ech"],
            ["plug density and potential satisfy an explicit consistency gate",
                "MHD and trapped-particle stability remain blocking gates"],
            ["one_d_two_v_hybrid_pic", "nonlinear_fokker_planck",
                "trapped_particle_stability", "anisotropic_mhd"],
            ["tandem_pic_caneses_marin_2025",
                "tandem_high_field_frank_2025"]))
        for id in ("tandem_pic_caneses_marin_2025",
                "tandem_high_field_frank_2025")
            _mev10_add_source_id!(raw, id)
        end
        for id in ("one_d_two_v_hybrid_pic", "nonlinear_fokker_planck",
                "trapped_particle_stability")
            _mev10_add_required_evaluator!(raw, id)
        end
    end
    if has_stabilizer
        push!(raw["actuators"], _ctv4_actuator("v10_kinetic_stabilizer_beam",
            "nbi", 10.0e6))
        push!(raw["stability_mechanisms"], _ctv4_mechanism(
            "v10_kinetic_stabilizer", "other",
            ["axisymmetric_interchange", "ballooning", "mhd_flute"],
            ["v10_kinetic_stabilizer_beam"],
            ["reflected beam pressure is finite and its replenishment is charged",
                "no axial-confinement multiplier is awarded"],
            ["kinetic_mhd_energy_principle", "reflected_beam_orbits",
                "beam_replenishment"], ["kinetic_stabilizer_post_2004"]))
        _mev10_add_source_id!(raw, "kinetic_stabilizer_post_2004")
        _mev10_add_required_evaluator!(raw, "kinetic_mhd_energy_principle")
    end
    if direct
        raw["exhaust"]["kind"] =
            "two_end_expanders_with_direct_converter_to_finite_targets"
        for requirement in ("charged_end_loss_spectrum", "grid_transparency",
                "high_voltage_breakdown", "converter_energy_conservation")
            requirement in raw["exhaust"]["evaluation_requirements"] ||
                push!(raw["exhaust"]["evaluation_requirements"], requirement)
        end
        _mev10_add_source_id!(raw, "mars_engineering_henning_1986")
        _mev10_add_required_evaluator!(raw, "direct_converter_grid_model")
    end
    raw["design_id"] = "pending_mechanism_v10_tandem_structure"
    provisional = parse_genome(raw)
    validate_genome(provisional).valid || error(join(
        validate_genome(provisional).errors, "; "))
    raw["design_id"] = "structure_$(provisional.physics_hash[1:20])"
    return parse_genome(raw)
end

function _mev10_build_z_pinch(tokamak::Genome,
        spec::MechanismExpansionTopologySpecV10)
    raw = deepcopy(tokamak.normalized)
    raw["family"] = "sheared_flow_z_pinch"
    raw["mission"]["fuel"] = "D-T"
    raw["mission"]["operating_mode"] = "pulsed"
    raw["mission"]["kind"] = "science_gain_demo"
    raw["topology"] = Dict{String,Any}(
        "field_line_class" => "open_linear",
        "rotation_transform_sources" => ["not_applicable"],
        "expected_flux_surfaces" => false,
        "expected_separatrix" => false)
    raw["symmetry"] = Dict{String,Any}(
        "class" => "axisymmetric", "field_periods" => 1,
        "hard_constraints" => ["finite-radius linear current channel",
            "two explicit open ends", "conducting wall",
            "separate m equals zero pressure-profile gate"])
    raw["plasma_regions"] = Any[
        _ctv4_region("v10_z_core", "linear_pinch_core",
            "finite_radius_cylindrical_current_channel", Dict(
                "plasma_radius" => _ctv4_quantity(0.30, "m"),
                "half_length" => _ctv4_quantity(1.50, "m"),
                "edge_azimuthal_field" => _ctv4_quantity(4.0, "T"))),
        _ctv4_region("v10_z_left_target", "divertor_or_exhaust_region",
            "replaceable_linear_end_target"),
        _ctv4_region("v10_z_right_target", "divertor_or_exhaust_region",
            "replaceable_linear_end_target")]
    raw["field_sources"] = Any[
        _ctv4_source("v10_z_plasma_current", "plasma_current",
            "finite_radius_axial_current_density", "plasma", Dict(
                "total_current" => _ctv4_quantity(0.20, "MA"))),
        _ctv4_source("v10_z_conducting_wall", "passive_conductor",
            "coaxial_finite_thickness_wall_and_electrodes",
            "replaceable_refractory_conductor", Dict(
                "wall_thickness" => _ctv4_quantity(0.25, "m"),
                "electrode_build" => _ctv4_quantity(0.25, "m")))]
    raw["actuators"] = Any[
        _ctv4_actuator("v10_coaxial_plasma_accelerator", "other", 60.0e6)]
    raw["stability_mechanisms"] = Any[
        _ctv4_mechanism("v10_z_axial_shear", "sheared_flow",
            ["m1_kink", "m0_sausage"], ["v10_coaxial_plasma_accelerator"],
            ["0.1 normalized shear is a mode-specific rejection threshold only",
                "m0 pressure-profile margin is independently gated"],
            ["resistive_mhd_with_axial_flow", "all_mode_spectrum",
                "coaxial_accelerator_and_electrode_model"],
            ["zpinch_shear_shumlak_hartman_1995",
                "fuze_neutron_zhang_2019"])]
    raw["flux_connections"] = Any[
        Dict("from_region_id" => "v10_z_core",
            "to_region_id" => "v10_z_left_target", "kind" => "open_field_line"),
        Dict("from_region_id" => "v10_z_core",
            "to_region_id" => "v10_z_right_target", "kind" => "open_field_line")]
    raw["exhaust"] = Dict{String,Any}(
        "kind" => "two_linear_open_ends_to_replaceable_targets",
        "region_ids" => ["v10_z_left_target", "v10_z_right_target"],
        "evaluation_requirements" => ["advective_thermal_loss",
            "end_target_heat_flux", "electrode_erosion", "neutral_recycling"])
    raw["engineering"]["magnet_technology"] = ["self-field plasma current channel"]
    raw["engineering"]["maintenance"] = Dict(
        "architecture" => "linear replaceable electrode and end-target modules",
        "access_paths" => ["left end", "right end", "radial wall sectors"])
    raw["engineering"]["required_evaluators"] = [
        "resistive_mhd_with_axial_flow", "coaxial_accelerator_and_electrode_model",
        "pulsed_power", "electrode_erosion", "neutronics", "remote_maintenance"]
    raw["provenance"]["origin"] = "generated"
    raw["provenance"]["claim_level"] = "structural_example"
    raw["provenance"]["parent_design_ids"] = [tokamak.design_id]
    raw["provenance"]["source_ids"] = ["zpinch_shear_shumlak_hartman_1995",
        "fuze_neutron_zhang_2019"]
    push!(raw["provenance"]["notes"],
        "mechanism_expansion_v10_no_fuze_performance_transplant")
    raw["label"] = "Mechanism v10 $(_mev10_key(spec))"
    raw["design_id"] = "pending_mechanism_v10_z_structure"
    basis = "fixed v10 sheared-flow Z-pinch declaration"
    for (name, value, unit) in (
            ("screen_aspect_ratio", 5.0, "1"),
            ("screen_plasma_fill_fraction", 0.50, "1"),
            ("screen_beta", 0.50, "1"),
            ("screen_temperature", 15.0, "keV"),
            ("screen_field_quality", 0.95, "1"),
            ("screen_exhaust_area_fraction", 0.20, "1"),
            ("screen_exhaust_flux_expansion", 2.0, "1"),
            ("screen_declared_actuator_power", 60.0e6, "W"),
            ("screen_z_pulse_duration", 100.0e-6, "s"),
            ("screen_z_repetition_rate",
                occursin("repetitive", spec.mechanism) ? 100.0 : 0.0, "Hz"),
            ("screen_z_normalized_shear", 0.20, "1"),
            ("screen_z_m0_profile_margin", 0.70, "1"),
            ("screen_z_accelerator_efficiency", 0.50, "1"),
            ("screen_z_wall_thickness", 0.25, "m"),
            ("screen_z_electrode_build", 0.25, "m"))
        _ctv4_set_target!(raw, name, value, unit; basis = basis)
    end
    provisional = parse_genome(raw)
    validate_genome(provisional).valid || error(join(
        validate_genome(provisional).errors, "; "))
    validate_family(default_family_registry(), provisional).valid || error(join(
        validate_family(default_family_registry(), provisional).errors, "; "))
    raw["design_id"] = "structure_$(provisional.physics_hash[1:20])"
    return parse_genome(raw)
end

function _mev10_structural_bases(seeds::Vector{Genome})
    old = _ccv9_structural_bases(seeds)
    by_family = Dict(genome.family => genome for genome in
        _common_baseline_genomes(seeds))
    controls = Dict(_mev10_key(spec) => old[spec.control_v9_key] for spec in
        _mev10_topology_specs() if _mev10_is_control(spec))
    result = Dict{String,Genome}(controls)
    mirror_control = only(filter(spec -> _mev10_is_control(spec) &&
        spec.core_family == "magnetic_mirror" &&
        spec.mechanism == "minimum_b_beam_plug", _mev10_topology_specs()))
    for spec in _mev10_topology_specs()
        _mev10_is_control(spec) && continue
        if spec.core_family == "magnetic_mirror"
            result[_mev10_key(spec)] = _mev10_build_tandem!(
                deepcopy(old[mirror_control.control_v9_key].normalized), spec)
        else
            result[_mev10_key(spec)] = _mev10_build_z_pinch(
                by_family["tokamak_axisymmetric"], spec)
        end
    end
    return result
end

function _mev10_ranges(spec::MechanismExpansionTopologySpecV10, u)
    if _mev10_is_control(spec)
        old = only(filter(item -> _ccv9_key(item) == spec.control_v9_key,
            _ccv9_topology_specs()))
        return _ccv9_ranges(old, u)
    elseif spec.core_family == "magnetic_mirror"
        old = ComposableTopologySpecV9("magnetic_mirror",
            "minimum_b_beam_plug", "two_end_expander", 2)
        values = _ccv9_ranges(old, u)
        has_barrier = occursin("thermal", spec.mechanism)
        has_stabilizer = occursin("kinetic", spec.mechanism)
        direct = spec.exhaust_topology == "two_end_direct_converter"
        potential = has_barrier ? 0.5 + 2.5u[13] : 0.0
        values["screen_tandem_potential_ratio"] = potential
        values["screen_tandem_plug_density_ratio"] = has_barrier ?
            exp(potential) * (0.75 + 1.50u[14]) : 1.0
        values["screen_tandem_beam_energy"] = has_barrier ?
            (25.0 + 125.0u[15]) * 1.602176634e-16 : 0.0
        values["screen_tandem_beam_power"] = has_barrier ?
            10.0e6 + 50.0e6u[16] : 0.0
        values["screen_tandem_ech_power"] = has_barrier ?
            2.0e6 + 18.0e6u[17] : 0.0
        values["screen_kinetic_stabilizer_pressure_fraction"] = has_stabilizer ?
            0.02 + 0.23u[13] : 0.0
        values["screen_kinetic_stabilizer_replenishment_time"] =
            0.005 * 20.0^u[14]
        values["screen_direct_converter_recovery_fraction"] = direct ?
            0.05 + 0.45u[15] : 0.0
        values["screen_direct_converter_voltage"] = direct ?
            100.0e3 + 900.0e3u[16] : 0.0
        values["screen_direct_converter_build"] = direct ?
            0.05 + 0.25u[17] : 0.0
        values["screen_declared_actuator_power"] = 30.0e6 + 90.0e6u[18]
        return values
    end
    repetitive = occursin("repetitive", spec.mechanism)
    return Dict{String,Any}(
        "screen_aspect_ratio" => 2.0 + 10.0u[1],
        "screen_plasma_fill_fraction" => 0.15 + 0.70u[2],
        "screen_beta" => 0.10 + 0.90u[3],
        "screen_temperature" => 8.0 + 22.0u[4],
        "screen_field_quality" => 0.82 + 0.18u[5],
        "screen_q95" => 3.5,
        "screen_mirror_ratio" => 1.0,
        "screen_plug_strength" => 0.0,
        "screen_minimum_b_strength" => 0.0,
        "screen_shear_strength" => 0.30 + 0.70u[9],
        "screen_coil_pack_thickness" => 0.0,
        "screen_support_thickness" => 0.10 + 0.70u[8],
        "screen_exhaust_area_fraction" => 0.10 + 0.40u[9],
        "screen_exhaust_flux_expansion" => 1.0 + 5.0u[10],
        "screen_declared_actuator_power" => 20.0e6 + 100.0e6u[12],
        "screen_plasma_current_transform_fraction" => 0.0,
        "screen_external_transform_fraction" => 0.0,
        "screen_three_dimensional_field_fraction" => 0.0,
        "screen_z_pulse_duration" => 20.0e-6 * 100.0^u[13],
        "screen_z_repetition_rate" => repetitive ? 10.0 * 100.0^u[14] : 0.0,
        "screen_z_normalized_shear" => 0.05 + 0.45u[15],
        "screen_z_m0_profile_margin" => 0.30 + 0.70u[16],
        "screen_z_accelerator_efficiency" => 0.20 + 0.60u[17],
        "screen_z_wall_thickness" => 0.10 + 0.70u[18],
        "screen_z_electrode_build" => 0.05 + 0.45u[11])
end

const _MEV10_CUSTOM_UNITS = Dict(
    "screen_tandem_potential_ratio" => "1",
    "screen_tandem_plug_density_ratio" => "1",
    "screen_tandem_beam_energy" => "J",
    "screen_tandem_beam_power" => "W",
    "screen_tandem_ech_power" => "W",
    "screen_kinetic_stabilizer_pressure_fraction" => "1",
    "screen_kinetic_stabilizer_replenishment_time" => "s",
    "screen_direct_converter_recovery_fraction" => "1",
    "screen_direct_converter_voltage" => "V",
    "screen_direct_converter_build" => "m",
    "screen_z_pulse_duration" => "s",
    "screen_z_repetition_rate" => "Hz",
    "screen_z_normalized_shear" => "1",
    "screen_z_m0_profile_margin" => "1",
    "screen_z_accelerator_efficiency" => "1",
    "screen_z_wall_thickness" => "m",
    "screen_z_electrode_build" => "m")

function _mev10_set_custom_targets!(raw::Dict{String,Any}, values::AbstractDict,
        contract::SharedOuterEnvelopeContractV1)
    basis = "mechanism expansion v10 search gene under $(contract.id)"
    for (name, unit) in _MEV10_CUSTOM_UNITS
        haskey(values, name) || continue
        _ctv4_set_target!(raw, name, Float64(values[name]), unit; basis = basis)
    end
    return raw
end

function _mev10_update_actuator_powers!(raw::Dict{String,Any}, values::AbstractDict)
    declared = Float64(values["screen_declared_actuator_power"])
    if String(raw["family"]) == "sheared_flow_z_pinch"
        only(raw["actuators"])["parameters"]["power"] =
            _ctv4_quantity(declared, "W"; basis = "v10 declared accelerator power")
        return raw
    end
    beam = Float64(get(values, "screen_tandem_beam_power", 0.0))
    ech = Float64(get(values, "screen_tandem_ech_power", 0.0))
    fixed = filter(actuator -> occursin("tandem_plug_nbi",
            String(actuator["id"])) || occursin("tandem_plug_ech",
            String(actuator["id"])), raw["actuators"])
    flexible = filter(actuator -> !(actuator in fixed), raw["actuators"])
    for actuator in fixed
        id = String(actuator["id"])
        power = occursin("tandem_plug_nbi", id) ? 0.5beam : ech
        actuator["parameters"]["power"] = _ctv4_quantity(power, "W";
            basis = "v10 explicit mechanism power")
    end
    remaining = max(0.0, declared - beam - ech)
    count = length(flexible)
    if count > 0
        for actuator in flexible
            actuator["parameters"]["power"] = _ctv4_quantity(remaining / count,
                "W"; basis = "v10 remaining declared actuator allocation")
        end
    end
    return raw
end

function _mev10_instantiate(base::Genome,
        spec::MechanismExpansionTopologySpecV10, values::AbstractDict,
        contract::SharedOuterEnvelopeContractV1)
    if _mev10_is_control(spec)
        return _ccv9_instantiate(base, values, contract)
    end
    raw = deepcopy(base.normalized)
    _ccv9_set_targets!(raw, values, contract)
    _mev10_set_custom_targets!(raw, values, contract)
    _mev10_update_actuator_powers!(raw, values)
    provisional = parse_genome(raw)
    features = _oe_features(provisional)
    if spec.core_family == "magnetic_mirror"
        geometry = _ccv9_geometry(provisional, contract, features)
        _ccv9_update_components!(raw, contract, features, geometry)
    else
        geometry = _mev10_z_geometry(provisional, features, contract, values)
        for region in raw["plasma_regions"]
            String(region["kind"]) == "linear_pinch_core" || continue
            _set_common_quantity!(region["parameters"], "plasma_radius",
                geometry.a, "m"; basis = "v10 scored Z-pinch geometry")
            _set_common_quantity!(region["parameters"], "half_length",
                geometry.c, "m"; basis = "v10 scored Z-pinch geometry")
            _set_common_quantity!(region["parameters"], "edge_azimuthal_field",
                contract.plasma_field_T, "T"; basis = "v10 common field contract")
        end
        plasma_current = 2.0pi * geometry.a * contract.plasma_field_T /
            (4.0e-7pi)
        for source in raw["field_sources"]
            kind = String(source["kind"])
            if kind == "plasma_current"
                _set_common_quantity!(source["parameters"], "total_current",
                    plasma_current, "A"; basis = "v10 edge self-field consistency")
            elseif kind == "passive_conductor"
                _set_common_quantity!(source["parameters"], "wall_thickness",
                    Float64(values["screen_z_wall_thickness"]), "m";
                    basis = "v10 wall-build gene")
                _set_common_quantity!(source["parameters"], "electrode_build",
                    Float64(values["screen_z_electrode_build"]), "m";
                    basis = "v10 electrode-build gene")
            end
        end
    end
    raw["design_id"] = "pending_mechanism_v10_elite"
    provisional = parse_genome(raw)
    raw["design_id"] = "concept_$(provisional.physics_hash[1:20])"
    candidate = parse_genome(raw)
    report = validate_genome(candidate)
    report.valid || error(join(report.errors, "; "))
    return candidate
end

function _mev10_acquisition_features(base::Genome,
        spec::MechanismExpansionTopologySpecV10, values::AbstractDict)
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
            Float64(values["screen_three_dimensional_field_fraction"])))
end

function _mev10_descriptor(contract::SharedOuterEnvelopeContractV1,
        spec::MechanismExpansionTopologySpecV10, features, values)
    fill = _oev5_bin(features.plasma_fill_fraction, (0.40, 0.70, Inf),
        ("fill_low", "fill_mid", "fill_high"))
    shape_edges = spec.core_family == "sheared_flow_z_pinch" ?
        (4.0, 8.0, Inf) : spec.core_family == "spheromak" ?
        (1.35, 1.85, Inf) : (3.2, 5.2, Inf)
    shape = _oev5_bin(features.shape_ratio, shape_edges,
        ("shape_low", "shape_mid", "shape_high"))
    beta = _oev5_bin(features.beta, (0.06, 0.18, 0.45, Inf),
        ("beta_low", "beta_mid", "beta_high", "beta_very_high"))
    mechanism_bin = if spec.core_family == "sheared_flow_z_pinch"
        _oev5_bin(Float64(values["screen_z_normalized_shear"]),
            (0.10, 0.25, Inf), ("shear_subthreshold", "shear_mid", "shear_high"))
    elseif !_mev10_is_control(spec) && spec.core_family == "magnetic_mirror"
        _oev5_bin(Float64(values["screen_tandem_potential_ratio"]),
            (0.5, 1.5, Inf), ("plug_none", "plug_mid", "plug_high"))
    else
        "sealed_v9_control"
    end
    return join((contract.id, spec.core_family, spec.mechanism,
        spec.exhaust_topology, "targets_$(spec.target_count)", fill, shape,
        beta, mechanism_bin), "|")
end

_mev10_quality_key(record::AbstractDict) = _oev5_quality_key(record)

function _mev10_control_baselines(structural::Dict{String,Genome},
        contracts::Vector{SharedOuterEnvelopeContractV1})
    chosen = MechanismExpansionTopologySpecV10[]
    seen = Set{String}()
    for spec in _mev10_topology_specs()
        _mev10_is_control(spec) || continue
        spec.core_family in seen && continue
        push!(chosen, spec)
        push!(seen, spec.core_family)
    end
    records = Dict{String,Any}[]
    u = ntuple(_ -> 0.5, 18)
    for contract in contracts, spec in chosen
        values = _mev10_ranges(spec, u)
        candidate = _mev10_instantiate(structural[_mev10_key(spec)], spec,
            values, contract)
        result = _mechanism_expansion_result(MechanismExpansionScreenV1(contract;
            allowed_contracts = contracts), candidate)
        push!(records, Dict{String,Any}(
            "contract_id" => contract.id, "core_family" => spec.core_family,
            "mechanism" => spec.mechanism, "design_id" => candidate.design_id,
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "net_electric_power_W" => result["nominal"]["net_electric_power_W"],
            "minimum_normalized_margin" =>
                result["nominal"]["minimum_normalized_margin"],
            "result_hash" => result["result_hash"]))
    end
    sort!(records; by = record -> (record["contract_id"], record["core_family"]))
    return records
end

function _mev10_medium_fidelity_route(spec::MechanismExpansionTopologySpecV10)
    _mev10_is_control(spec) && return _ccv9_medium_fidelity_route(
        spec.core_family, spec.mechanism)
    if spec.core_family == "sheared_flow_z_pinch"
        return ["resistive_mhd_with_axial_flow", "all_mode_spectrum",
            "coaxial_accelerator_and_electrode_model", "pulsed_power",
            "electrode_erosion", "pulsed_end_target_transport"]
    end
    route = ["anisotropic_mirror_equilibrium", "one_d_two_v_hybrid_pic",
        "nonlinear_fokker_planck", "trapped_particle_stability",
        "kinetic_microstability", "end_expander_transport"]
    occursin("kinetic", spec.mechanism) && append!(route,
        ["kinetic_mhd_energy_principle", "reflected_beam_orbits"])
    spec.exhaust_topology == "two_end_direct_converter" && append!(route,
        ["charged_end_loss_spectrum", "direct_converter_grid_model",
            "high_voltage_breakdown"])
    return route
end

"Run v9 controls and eight new mechanism strata under the same six contracts."
function run_mechanism_expansion_qd_v10(seeds::Vector{Genome};
        acquisition_samples::Int = 300_000,
        random_seed::Int = 20260813,
        maximum_graph_elites::Int = 588,
        elites_per_structural_stratum::Int = 2,
        contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    acquisition_samples >= 0 || throw(ArgumentError(
        "acquisition_samples must be non-negative"))
    maximum_graph_elites > 0 || throw(ArgumentError(
        "maximum_graph_elites must be positive"))
    elites_per_structural_stratum > 0 || throw(ArgumentError(
        "elites_per_structural_stratum must be positive"))
    isempty(contracts) && throw(ArgumentError("at least one contract is required"))
    structural = _mev10_structural_bases(seeds)
    specs = _mev10_topology_specs()
    strata = [(contract, spec) for contract in contracts for spec in specs]
    primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61)
    archive = Dict{String,Dict{String,Any}}()
    positive_net_count = 0
    nominal_pass_count = 0
    family_sample_count = Dict(family => 0 for family in sort!(unique(
        spec.core_family for spec in specs)))
    mechanism_sample_count = Dict(spec.mechanism => 0 for spec in specs)
    exhaust_sample_count = Dict(spec.exhaust_topology => 0 for spec in specs)
    contract_sample_count = Dict(contract.id => 0 for contract in contracts)
    for index in 1:acquisition_samples
        contract, spec = strata[mod1(index, length(strata))]
        u = ntuple(axis -> _ctv4_halton(index, primes[axis]), length(primes))
        values = _mev10_ranges(spec, u)
        base = structural[_mev10_key(spec)]
        features = _mev10_acquisition_features(base, spec, values)
        nominal = _mev10_nominal(base, contract, features, values)
        nominal["net_electric_power_W"] > 0.0 && (positive_net_count += 1)
        nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true &&
            (nominal_pass_count += 1)
        family_sample_count[spec.core_family] += 1
        mechanism_sample_count[spec.mechanism] += 1
        exhaust_sample_count[spec.exhaust_topology] += 1
        contract_sample_count[contract.id] += 1
        structural_key = "$(contract.id)|$(_mev10_key(spec))"
        proposal = Dict{String,Any}(
            "descriptor" => _mev10_descriptor(contract, spec, features, values),
            "structural_stratum" => structural_key,
            "contract_id" => contract.id, "core_family" => spec.core_family,
            "mechanism" => spec.mechanism,
            "exhaust_topology" => spec.exhaust_topology,
            "target_count" => spec.target_count,
            "control_v9_key" => spec.control_v9_key,
            "features" => values, "nominal" => nominal)
        incumbent = get(archive, proposal["descriptor"], nothing)
        if incumbent === nothing ||
                _mev10_quality_key(proposal) < _mev10_quality_key(incumbent)
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
        sort!(candidates; by = _mev10_quality_key)
        append!(acquisitions, first(candidates,
            min(elites_per_structural_stratum, length(candidates))))
    end
    sort!(acquisitions; by = proposal ->
        (proposal["structural_stratum"], _mev10_quality_key(proposal)))
    length(acquisitions) > maximum_graph_elites &&
        (acquisitions = first(acquisitions, maximum_graph_elites))
    contract_by_id = Dict(contract.id => contract for contract in contracts)
    spec_by_key = Dict(_mev10_key(spec) => spec for spec in specs)
    records = Dict{String,Any}[]
    for acquisition in acquisitions
        contract = contract_by_id[String(acquisition["contract_id"])]
        spec_key = join(split(String(acquisition["structural_stratum"]), "|")[2:end], "|")
        spec = spec_by_key[spec_key]
        candidate = _mev10_instantiate(structural[_mev10_key(spec)], spec,
            acquisition["features"], contract)
        result = _mechanism_expansion_result(MechanismExpansionScreenV1(contract;
            allowed_contracts = contracts), candidate)
        promoted = result["all_five_gates_passed"] === true &&
            result["positive_net_power_closure_passed"] === true &&
            !_mev10_is_control(spec)
        push!(records, Dict{String,Any}(
            "contract_id" => contract.id, "design_id" => candidate.design_id,
            "physics_hash" => candidate.physics_hash,
            "core_family" => spec.core_family, "mechanism" => spec.mechanism,
            "exhaust_topology" => spec.exhaust_topology,
            "target_count" => spec.target_count,
            "is_v9_control" => _mev10_is_control(spec),
            "descriptor" => acquisition["descriptor"],
            "genome" => candidate.normalized, "acquisition" => acquisition,
            "evaluation" => result,
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "positive_net_power_closure_passed" =>
                result["positive_net_power_closure_passed"],
            "promoted" => promoted,
            "medium_fidelity_route" => promoted ?
                _mev10_medium_fidelity_route(spec) : String[]))
    end
    sort!(records; by = record -> (
        record["promoted"] === true ? 0 : 1,
        record["is_v9_control"] === true ? 1 : 0,
        count(value -> Float64(value) < 0.0,
            Base.values(record["evaluation"]["nominal"]["margins"])),
        sum(log1p(-min(0.0, Float64(value))) for value in
            Base.values(record["evaluation"]["nominal"]["margins"])),
        -Float64(record["evaluation"]["nominal"]["net_electric_power_W"]),
        record["physics_hash"]))
    return Dict{String,Any}(
        "algorithm" => "balanced Halton acquisition plus mechanism-preserving failure-aware MAP-Elites",
        "random_seed" => random_seed,
        "acquisition_samples" => acquisition_samples,
        "contract_count" => length(contracts),
        "contracts" => [_oe_contract_dict(contract) for contract in contracts],
        "topology_count_per_contract" => length(specs),
        "v9_control_topology_count_per_contract" => count(_mev10_is_control, specs),
        "new_mechanism_topology_count_per_contract" =>
            count(spec -> !_mev10_is_control(spec), specs),
        "structural_stratum_count" => length(strata),
        "topologies" => [Dict(
            "core_family" => spec.core_family, "mechanism" => spec.mechanism,
            "exhaust_topology" => spec.exhaust_topology,
            "target_count" => spec.target_count,
            "is_v9_control" => _mev10_is_control(spec)) for spec in specs],
        "declared_search_domain" => Dict(
            "outer_radial_extent_m" => sort!(unique(
                contract.outer_radial_extent_m for contract in contracts)),
            "outer_axial_half_extent_m" => sort!(unique(
                contract.outer_axial_half_extent_m for contract in contracts)),
            "plasma_field_T" => sort!(unique(
                contract.plasma_field_T for contract in contracts)),
            "tandem_potential_over_temperature" => [0.5, 3.0],
            "tandem_beam_energy_keV" => [25.0, 150.0],
            "kinetic_stabilizer_pressure_fraction" => [0.02, 0.25],
            "direct_converter_recovery_fraction" => [0.05, 0.50],
            "z_pulse_duration_s" => [20.0e-6, 2.0e-3],
            "z_repetition_rate_Hz" => [10.0, 1000.0],
            "z_normalized_shear" => [0.05, 0.50],
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
        "same_outer_envelope_v9_control_baselines" =>
            _mev10_control_baselines(structural, contracts),
        "records" => records,
        "v9_failure_label_lineage" => Dict(
            "review_result_hash" =>
                "41b8341e19f440e58a75320a1f53d9da281086a5c27d9c00c96710b61cc0caa4",
            "policy" => "rejection-only optimistic PF prescreen on tokamak controls"),
        "claim_boundary" => _MEV10_SCREEN_CLAIM_BOUNDARY)
end
