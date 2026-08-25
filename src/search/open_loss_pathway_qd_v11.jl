"A sealed-v10 control or a new v11 open-loss-pathway composition."
struct OpenLossPathwayTopologySpecV11
    core_family::String
    mechanism::String
    exhaust_topology::String
    target_count::Int
    control_v10_key::Union{Nothing,String}

    function OpenLossPathwayTopologySpecV11(core_family::AbstractString,
            mechanism::AbstractString, exhaust_topology::AbstractString,
            target_count::Integer;
            control_v10_key::Union{Nothing,String} = nothing)
        family = String(core_family)
        family in ("tokamak_axisymmetric", "tokamak_3d_hybrid", "stellarator",
            "magnetic_mirror", "sheared_flow_z_pinch", "high_beta_magnetic_cusp",
            "field_reversed_configuration", "spheromak") ||
            throw(ArgumentError("unsupported v11 family $family"))
        family == "magnetic_mirror" && target_count != 2 &&
            throw(ArgumentError("v11 GDT/GDMT requires two axial receivers"))
        family == "high_beta_magnetic_cusp" && target_count < 6 &&
            throw(ArgumentError("v11 cusp requires at least six explicit cusp exits"))
        return new(family, String(mechanism), String(exhaust_topology),
            Int(target_count), control_v10_key)
    end
end

function _olv11_topology_specs()
    specs = OpenLossPathwayTopologySpecV11[]
    for old in _mev10_topology_specs()
        push!(specs, OpenLossPathwayTopologySpecV11(old.core_family,
            old.mechanism, old.exhaust_topology, old.target_count;
            control_v10_key = _mev10_key(old)))
    end
    for mechanism in ("gas_dynamic_single_cell", "gas_dynamic_multimirror")
        for exhaust in ("two_end_expander", "two_end_bounded_direct_converter")
            push!(specs, OpenLossPathwayTopologySpecV11("magnetic_mirror",
                mechanism, exhaust, 2))
        end
    end
    push!(specs, OpenLossPathwayTopologySpecV11("high_beta_magnetic_cusp",
        "high_beta_cusp_electron_anchor", "explicit_cusp_collectors", 6))
    push!(specs, OpenLossPathwayTopologySpecV11("high_beta_magnetic_cusp",
        "high_beta_cusp_electrostatic_ion_candidate",
        "explicit_cusp_collectors", 6))
    return specs
end

function _olv11_key(spec::OpenLossPathwayTopologySpecV11)
    kind = spec.control_v10_key === nothing ? "new" : "v10_control"
    return join((kind, spec.core_family, spec.mechanism, spec.exhaust_topology,
        "targets=$(spec.target_count)"), "|")
end

_olv11_is_control(spec::OpenLossPathwayTopologySpecV11) =
    spec.control_v10_key !== nothing

function _olv11_build_gdt(base::Genome,
        spec::OpenLossPathwayTopologySpecV11)
    raw = deepcopy(base.normalized)
    multimirror = spec.mechanism == "gas_dynamic_multimirror"
    direct = spec.exhaust_topology == "two_end_bounded_direct_converter"
    raw["family"] = "magnetic_mirror"
    raw["mission"]["fuel"] = "D-T"
    raw["mission"]["operating_mode"] = "steady_state"
    raw["mission"]["kind"] = "net_electric_pilot"
    raw["topology"] = Dict{String,Any}(
        "field_line_class" => "open_mirror",
        "rotation_transform_sources" => ["not_applicable"],
        "expected_flux_surfaces" => false,
        "expected_separatrix" => false)
    raw["symmetry"] = Dict{String,Any}(
        "class" => "axisymmetric", "field_periods" => 1,
        "hard_constraints" => ["gas-dynamic collisionality derived from state",
            "two explicit end receivers", "transverse loss retained",
            "multiple-mirror credit bounded and applicability gated"])
    raw["plasma_regions"] = Any[
        _ctv4_region("v11_gdt_central", "gas_dynamic_central_cell",
            "finite_radius_axisymmetric_gas_dynamic_cell", Dict(
                "plasma_radius" => _ctv4_quantity(0.50, "m"),
                "half_length" => _ctv4_quantity(2.00, "m"))),
        _ctv4_region("v11_gdt_left_receiver", "divertor_or_exhaust_region",
            direct ? "charged_particle_expander_and_collector" :
                "magnetic_expander_and_plasma_receiver"),
        _ctv4_region("v11_gdt_right_receiver", "divertor_or_exhaust_region",
            direct ? "charged_particle_expander_and_collector" :
                "magnetic_expander_and_plasma_receiver")]
    raw["field_sources"] = Any[
        _ctv4_source("v11_gdt_central_solenoid", "external_axisymmetric_coils",
            "finite_build_central_solenoid", "generic_superconductor"),
        _ctv4_source("v11_gdt_left_mirror", "external_axisymmetric_coils",
            "finite_build_high_field_mirror", "generic_superconductor"),
        _ctv4_source("v11_gdt_right_mirror", "external_axisymmetric_coils",
            "finite_build_high_field_mirror", "generic_superconductor")]
    if multimirror
        push!(raw["field_sources"], _ctv4_source(
            "v11_gdt_left_corrugated_section", "external_axisymmetric_coils",
            "finite_build_corrugated_multiple_mirror_cells",
            "generic_superconductor"))
        push!(raw["field_sources"], _ctv4_source(
            "v11_gdt_right_corrugated_section", "external_axisymmetric_coils",
            "finite_build_corrugated_multiple_mirror_cells",
            "generic_superconductor"))
    end
    raw["actuators"] = Any[
        _ctv4_actuator("v11_gdt_neutral_beam", "nbi", 50.0e6),
        _ctv4_actuator("v11_gdt_vortex_bias", "other", 5.0e6)]
    raw["stability_mechanisms"] = Any[
        _ctv4_mechanism("v11_gdt_open_loss_pathway",
            multimirror ? "multiple_mirror" : "other",
            ["flute", "dclc", "axial_end_loss", "transverse_transport"],
            ["v11_gdt_neutral_beam", "v11_gdt_vortex_bias"],
            ["gas-dynamic and cell collisionality are derived, not free genes",
                "transverse Bohm-reference loss is never erased",
                "no ideal N or N-squared experimental multiplier is imported"],
            ["anisotropic_mirror_equilibrium", "fokker_planck_open_trap",
                "multiple_mirror_flow_transport", "vortex_mhd_stability",
                "end_expander_transport"],
            ["open_traps_ryutov_1988", "multiple_mirror_logan_1974",
                "gdt_bagryansky_2019", "golnb_postupaev_2026",
                "nrl_plasma_formulary_2023"])]
    raw["flux_connections"] = Any[
        Dict("from_region_id" => "v11_gdt_central",
            "to_region_id" => "v11_gdt_left_receiver",
            "kind" => "open_field_line"),
        Dict("from_region_id" => "v11_gdt_central",
            "to_region_id" => "v11_gdt_right_receiver",
            "kind" => "open_field_line")]
    raw["exhaust"] = Dict{String,Any}(
        "kind" => direct ? "two_end_bounded_direct_converter" :
            "two_end_magnetic_expanders_and_receivers",
        "region_ids" => ["v11_gdt_left_receiver", "v11_gdt_right_receiver"],
        "evaluation_requirements" => ["gas_dynamic_end_loss",
            "multiple_mirror_flow_transport", "transverse_loss_floor",
            "end_target_heat_flux", "neutral_recycling"])
    raw["engineering"]["magnet_technology"] =
        ["finite-build axisymmetric solenoid and mirror windings"]
    raw["engineering"]["blanket"] = Dict{String,Any}(
        "required" => true,
        "concept" => "linear modular D-T breeding blanket placeholder",
        "target_tbr" => _ctv4_quantity(1.10, "1";
            basis = "v11 declared mission target, not a neutronics result"))
    raw["engineering"]["maintenance"] = Dict(
        "architecture" => "linear replaceable end receivers and coil modules",
        "access_paths" => ["left end", "right end", "radial central modules"])
    raw["engineering"]["required_evaluators"] = [
        "anisotropic_mirror_equilibrium", "fokker_planck_open_trap",
        "multiple_mirror_flow_transport", "vortex_mhd_stability",
        "end_expander_transport", "finite_build_coils", "neutronics",
        "remote_maintenance"]
    raw["provenance"]["origin"] = "generated"
    raw["provenance"]["claim_level"] = "structural_example"
    raw["provenance"]["parent_design_ids"] = [base.design_id]
    raw["provenance"]["source_ids"] = ["open_traps_ryutov_1988",
        "multiple_mirror_logan_1974", "gdt_bagryansky_2019",
        "golnb_postupaev_2026", "nrl_plasma_formulary_2023"]
    push!(raw["provenance"]["notes"],
        "open_loss_pathways_v11_no_ideal_cell_scaling_transplant")
    raw["label"] = "Open-loss v11 $(_olv11_key(spec))"
    raw["design_id"] = "pending_open_loss_v11_gdt_structure"
    basis = "fixed v11 gas-dynamic mirror declaration"
    for (name, value, unit) in (
            ("screen_olv11_gdt_active", 1.0, "1"),
            ("screen_olv11_central_aspect_ratio", 4.0, "1"),
            ("screen_olv11_cell_count", multimirror ? 8.0 : 1.0, "1"),
            ("screen_olv11_cell_length", 0.20, "m"),
            ("screen_olv11_nbi_power", 50.0e6, "W"),
            ("screen_olv11_bias_power", 5.0e6, "W"),
            ("screen_olv11_recovery_fraction", direct ? 0.20 : 0.0, "1"),
            ("screen_olv11_converter_voltage", direct ? 300.0e3 : 0.0, "V"),
            ("screen_olv11_converter_build", direct ? 0.20 : 0.0, "m"))
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

function _olv11_build_cusp(seed::Genome,
        spec::OpenLossPathwayTopologySpecV11)
    raw = deepcopy(seed.normalized)
    ion_candidate = occursin("ion_candidate", spec.mechanism)
    raw["family"] = "high_beta_magnetic_cusp"
    raw["mission"]["fuel"] = "D-T"
    raw["mission"]["operating_mode"] = "steady_state"
    raw["mission"]["kind"] = ion_candidate ? "net_electric_pilot" :
        "science_gain_demo"
    raw["topology"] = Dict{String,Any}(
        "field_line_class" => "open_cusp",
        "rotation_transform_sources" => ["not_applicable"],
        "expected_flux_surfaces" => false,
        "expected_separatrix" => true)
    raw["symmetry"] = Dict{String,Any}(
        "class" => "none", "field_periods" => 1,
        "hard_constraints" => ["polyhedral point-cusp array",
            "high-beta electron evidence cannot establish ion confinement",
            "explicit electron injection and cusp collectors"])
    raw["plasma_regions"] = Any[
        _ctv4_region("v11_cusp_core", "high_beta_cusp_core",
            "spherical_diamagnetic_core_with_polyhedral_cusps", Dict(
                "plasma_radius" => _ctv4_quantity(1.0, "m"),
                "cusp_count" => _ctv4_quantity(6.0, "1"))),
        _ctv4_region("v11_cusp_collectors", "divertor_or_exhaust_region",
            "distributed_replaceable_cusp_collectors", Dict(
                "cusp_count" => _ctv4_quantity(6.0, "1")))]
    raw["field_sources"] = Any[
        _ctv4_source("v11_cusp_polyhedral_coils", "external_3d_coils",
            "six_or_more_finite_build_point_cusp_coils",
            "generic_superconductor", Dict(
                "coil_radius" => _ctv4_quantity(1.5, "m"),
                "cusp_count" => _ctv4_quantity(6.0, "1")))]
    raw["actuators"] = Any[
        _ctv4_actuator("v11_cusp_electron_injector", "other", 20.0e6)]
    raw["stability_mechanisms"] = Any[
        _ctv4_mechanism("v11_high_beta_cusp_boundary", "other",
            ["macroscopic_interchange", "electron_cusp_loss", "ion_cusp_loss"],
            ["v11_cusp_electron_injector"],
            ["high-beta evidence applies to injected high-energy electrons only",
                "low-beta electron-only well does not establish a high-beta ion well",
                "ion loss and quasineutral well persistence remain blocking"],
            ["high_beta_kinetic_pic", "ambipolar_potential_solver",
                "ion_cusp_loss_orbits", "finite_beta_cusp_mhd"],
            ["high_beta_cusp_park_2015", "polywell_potential_cornish_2014",
                "cusp_loss_jiang_2020", "nrl_plasma_formulary_2023"])]
    raw["flux_connections"] = Any[
        Dict("from_region_id" => "v11_cusp_core",
            "to_region_id" => "v11_cusp_collectors", "kind" => "open_field_line")]
    raw["exhaust"] = Dict{String,Any}(
        "kind" => "distributed_point_cusps_to_replaceable_collectors",
        "region_ids" => ["v11_cusp_collectors"],
        "evaluation_requirements" => ["electron_cusp_loss", "ion_cusp_loss",
            "cusp_collector_heat_flux", "neutral_recycling"])
    raw["engineering"]["magnet_technology"] =
        ["finite-build polyhedral cusp coils"]
    raw["engineering"]["blanket"] = Dict{String,Any}(
        "required" => ion_candidate,
        "concept" => ion_candidate ?
            "polyhedral modular D-T breeding blanket placeholder" : nothing)
    ion_candidate && (raw["engineering"]["blanket"]["target_tbr"] =
        _ctv4_quantity(1.10, "1";
            basis = "v11 declared mission target, not a neutronics result"))
    raw["engineering"]["maintenance"] = Dict(
        "architecture" => "replaceable cusp collectors between coil modules",
        "access_paths" => ["polyhedral faces", "cusp collector ports"])
    raw["engineering"]["required_evaluators"] = ["high_beta_kinetic_pic",
        "ambipolar_potential_solver", "ion_cusp_loss_orbits",
        "finite_beta_cusp_mhd", "finite_build_coils", "neutronics",
        "remote_maintenance"]
    raw["provenance"]["origin"] = "generated"
    raw["provenance"]["claim_level"] = "structural_example"
    raw["provenance"]["parent_design_ids"] = [seed.design_id]
    raw["provenance"]["source_ids"] = ["high_beta_cusp_park_2015",
        "polywell_potential_cornish_2014", "cusp_loss_jiang_2020",
        "nrl_plasma_formulary_2023"]
    push!(raw["provenance"]["notes"],
        "open_loss_pathways_v11_electron_evidence_not_ion_credit")
    raw["label"] = "Open-loss v11 $(_olv11_key(spec))"
    raw["design_id"] = "pending_open_loss_v11_cusp_structure"
    basis = "fixed v11 high-beta cusp declaration"
    for (name, value, unit) in (
            ("screen_olv11_cusp_count", 6.0, "1"),
            ("screen_olv11_cusp_well_temperature_ratio",
                ion_candidate ? 1.5 : 0.0, "1"),
            ("screen_olv11_cusp_beam_voltage",
                ion_candidate ? 100.0e3 : 7.0e3, "V"),
            ("screen_olv11_cusp_beam_current", 10.0, "A"),
            ("screen_olv11_cusp_well_replenishment_time", 100.0e-6, "s"))
        _ctv4_set_target!(raw, name, value, unit; basis = basis)
    end
    provisional = parse_genome(raw)
    validate_genome(provisional).valid || error(join(
        validate_genome(provisional).errors, "; "))
    raw["design_id"] = "structure_$(provisional.physics_hash[1:20])"
    return parse_genome(raw)
end

function _olv11_structural_bases(seeds::Vector{Genome})
    old = _mev10_structural_bases(seeds)
    controls = Dict(_olv11_key(spec) => old[spec.control_v10_key] for spec in
        _olv11_topology_specs() if _olv11_is_control(spec))
    result = Dict{String,Genome}(controls)
    mirror_control = only(filter(spec -> _olv11_is_control(spec) &&
        spec.core_family == "magnetic_mirror" &&
        spec.mechanism == "minimum_b_beam_plug", _olv11_topology_specs()))
    tokamak = only(filter(genome -> genome.family == "tokamak_axisymmetric",
        _common_baseline_genomes(seeds)))
    for spec in _olv11_topology_specs()
        _olv11_is_control(spec) && continue
        if spec.core_family == "magnetic_mirror"
            result[_olv11_key(spec)] = _olv11_build_gdt(
                old[mirror_control.control_v10_key], spec)
        else
            result[_olv11_key(spec)] = _olv11_build_cusp(tokamak, spec)
        end
    end
    return result
end

function _olv11_ranges(spec::OpenLossPathwayTopologySpecV11, u)
    if _olv11_is_control(spec)
        old = only(filter(item -> _mev10_key(item) == spec.control_v10_key,
            _mev10_topology_specs()))
        return _mev10_ranges(old, u)
    elseif spec.core_family == "magnetic_mirror"
        old = ComposableTopologySpecV9("magnetic_mirror",
            "minimum_b_beam_plug", "two_end_expander", 2)
        values = _ccv9_ranges(old, u)
        multimirror = spec.mechanism == "gas_dynamic_multimirror"
        direct = spec.exhaust_topology == "two_end_bounded_direct_converter"
        values["screen_aspect_ratio"] = 2.0 + 8.0u[1]
        values["screen_plasma_fill_fraction"] = 0.25 + 0.65u[2]
        values["screen_beta"] = 0.05 + 0.45u[3]
        values["screen_temperature"] = 5.0 + 20.0u[4]
        values["screen_field_quality"] = 0.80 + 0.20u[5]
        values["screen_mirror_ratio"] = 2.0 + 6.0u[6]
        values["screen_minimum_b_strength"] = 0.40 + 0.60u[7]
        values["screen_shear_strength"] = 0.20 + 0.80u[8]
        values["screen_coil_pack_thickness"] = 0.20 + 0.80u[9]
        values["screen_support_thickness"] = 0.20 + 1.00u[10]
        values["screen_exhaust_flux_expansion"] = 1.0 + 5.0u[11]
        values["screen_declared_actuator_power"] = 20.0e6 + 100.0e6u[12]
        values["screen_olv11_gdt_active"] = 1.0
        values["screen_olv11_central_aspect_ratio"] = 2.0 + 8.0u[13]
        values["screen_olv11_cell_count"] = multimirror ?
            Float64(4 + floor(Int, 17u[14])) : 1.0
        values["screen_olv11_cell_length"] = 0.05 + 0.45u[15]
        values["screen_olv11_nbi_power"] = 10.0e6 + 70.0e6u[16]
        values["screen_olv11_bias_power"] = 1.0e6 + 14.0e6u[17]
        values["screen_olv11_recovery_fraction"] = direct ?
            0.05 + 0.30u[18] : 0.0
        values["screen_olv11_converter_voltage"] = direct ?
            100.0e3 + 700.0e3u[15] : 0.0
        values["screen_olv11_converter_build"] = direct ?
            0.05 + 0.30u[16] : 0.0
        return values
    end
    ion_candidate = occursin("ion_candidate", spec.mechanism)
    cusp_count = Float64(6 + 2floor(Int, 5u[11]))
    return Dict{String,Any}(
        "screen_aspect_ratio" => 1.0,
        "screen_plasma_fill_fraction" => 0.15 + 0.70u[2],
        "screen_beta" => 0.70 + 0.40u[3],
        "screen_temperature" => 5.0 + 25.0u[4],
        "screen_field_quality" => 0.80 + 0.20u[5],
        "screen_q95" => 3.5,
        "screen_mirror_ratio" => 1.0,
        "screen_plug_strength" => 0.0,
        "screen_minimum_b_strength" => 0.30 + 0.70u[7],
        "screen_shear_strength" => 0.0,
        "screen_coil_pack_thickness" => 0.20 + 0.80u[9],
        "screen_support_thickness" => 0.20 + 1.00u[10],
        "screen_exhaust_area_fraction" => 0.10 + 0.40u[8],
        "screen_exhaust_flux_expansion" => 1.0 + 5.0u[12],
        "screen_declared_actuator_power" => 10.0e6 + 110.0e6u[13],
        "screen_plasma_current_transform_fraction" => 0.0,
        "screen_external_transform_fraction" => 0.0,
        "screen_three_dimensional_field_fraction" => 1.0,
        "screen_olv11_cusp_count" => cusp_count,
        "screen_olv11_cusp_well_temperature_ratio" => ion_candidate ?
            0.50 + 2.50u[14] : 0.0,
        "screen_olv11_cusp_beam_voltage" =>
            10.0e3 * 100.0^u[15],
        "screen_olv11_cusp_beam_current" => 1.0 * 1000.0^u[16],
        "screen_olv11_cusp_well_replenishment_time" =>
            1.0e-6 * 1000.0^u[17])
end

const _OLV11_CUSTOM_UNITS = Dict(
    "screen_olv11_gdt_active" => "1",
    "screen_olv11_central_aspect_ratio" => "1",
    "screen_olv11_cell_count" => "1",
    "screen_olv11_cell_length" => "m",
    "screen_olv11_nbi_power" => "W",
    "screen_olv11_bias_power" => "W",
    "screen_olv11_recovery_fraction" => "1",
    "screen_olv11_converter_voltage" => "V",
    "screen_olv11_converter_build" => "m",
    "screen_olv11_cusp_count" => "1",
    "screen_olv11_cusp_well_temperature_ratio" => "1",
    "screen_olv11_cusp_beam_voltage" => "V",
    "screen_olv11_cusp_beam_current" => "A",
    "screen_olv11_cusp_well_replenishment_time" => "s")

function _olv11_set_custom_targets!(raw::Dict{String,Any}, values::AbstractDict,
        contract::SharedOuterEnvelopeContractV1)
    basis = "open-loss pathway v11 search gene under $(contract.id)"
    for (name, unit) in _OLV11_CUSTOM_UNITS
        haskey(values, name) || continue
        _ctv4_set_target!(raw, name, Float64(values[name]), unit; basis = basis)
    end
    return raw
end

function _olv11_update_components!(raw::Dict{String,Any},
        spec::OpenLossPathwayTopologySpecV11, values::AbstractDict,
        contract::SharedOuterEnvelopeContractV1)
    declared = Float64(values["screen_declared_actuator_power"])
    if spec.core_family == "magnetic_mirror"
        nbi = Float64(values["screen_olv11_nbi_power"])
        bias = Float64(values["screen_olv11_bias_power"])
        for actuator in raw["actuators"]
            id = String(actuator["id"])
            power = id == "v11_gdt_neutral_beam" ? nbi :
                id == "v11_gdt_vortex_bias" ? bias : 0.0
            actuator["parameters"]["power"] = _ctv4_quantity(power, "W";
                basis = "v11 explicit GDT actuator")
        end
        provisional = parse_genome(raw)
        features = _oe_features(provisional)
        geometry = _olv11_gdt_geometry(provisional, features, contract, values)
        for region in raw["plasma_regions"]
            String(region["kind"]) == "gas_dynamic_central_cell" || continue
            _set_common_quantity!(region["parameters"], "plasma_radius",
                geometry.a, "m"; basis = "v11 scored GDT geometry")
            _set_common_quantity!(region["parameters"], "half_length",
                geometry.central_half, "m"; basis = "v11 scored GDT geometry")
        end
    else
        only(raw["actuators"])["parameters"]["power"] =
            _ctv4_quantity(declared, "W"; basis = "v11 declared electron injector")
        provisional = parse_genome(raw)
        features = _oe_features(provisional)
        geometry = _olv11_cusp_geometry(features, contract)
        cusp_count = Float64(values["screen_olv11_cusp_count"])
        for region in raw["plasma_regions"]
            if String(region["kind"]) == "high_beta_cusp_core"
                _set_common_quantity!(region["parameters"], "plasma_radius",
                    geometry.a, "m"; basis = "v11 scored cusp geometry")
                _set_common_quantity!(region["parameters"], "cusp_count",
                    cusp_count, "1"; basis = "v11 cusp-count gene")
            elseif String(region["kind"]) == "divertor_or_exhaust_region"
                _set_common_quantity!(region["parameters"], "cusp_count",
                    cusp_count, "1"; basis = "v11 cusp-count gene")
            end
        end
        for source in raw["field_sources"]
            _set_common_quantity!(source["parameters"], "coil_radius",
                1.5geometry.a, "m"; basis = "v11 finite cusp-coil geometry")
            _set_common_quantity!(source["parameters"], "cusp_count",
                cusp_count, "1"; basis = "v11 cusp-count gene")
        end
    end
    return raw
end

function _olv11_instantiate(base::Genome,
        spec::OpenLossPathwayTopologySpecV11, values::AbstractDict,
        contract::SharedOuterEnvelopeContractV1)
    if _olv11_is_control(spec)
        old = only(filter(item -> _mev10_key(item) == spec.control_v10_key,
            _mev10_topology_specs()))
        return _mev10_instantiate(base, old, values, contract)
    end
    raw = deepcopy(base.normalized)
    _ccv9_set_targets!(raw, values, contract)
    _olv11_set_custom_targets!(raw, values, contract)
    _olv11_update_components!(raw, spec, values, contract)
    raw["design_id"] = "pending_open_loss_v11_elite"
    provisional = parse_genome(raw)
    raw["design_id"] = "concept_$(provisional.physics_hash[1:20])"
    candidate = parse_genome(raw)
    report = validate_genome(candidate)
    report.valid || error(join(report.errors, "; "))
    if spec.core_family != "high_beta_magnetic_cusp"
        family = validate_family(default_family_registry(), candidate)
        family.valid || error(join(family.errors, "; "))
    end
    return candidate
end

function _olv11_acquisition_features(base::Genome,
        values::AbstractDict)
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

function _olv11_descriptor(contract::SharedOuterEnvelopeContractV1,
        spec::OpenLossPathwayTopologySpecV11, features, values, nominal)
    fill = _oev5_bin(features.plasma_fill_fraction, (0.40, 0.70, Inf),
        ("fill_low", "fill_mid", "fill_high"))
    beta = _oev5_bin(features.beta, (0.10, 0.40, 0.80, Inf),
        ("beta_low", "beta_mid", "beta_high", "beta_very_high"))
    mechanism_bin = if _olv11_is_control(spec)
        "sealed_v10_control"
    elseif spec.core_family == "magnetic_mirror"
        _oev5_bin(Float64(nominal["cell_collisionality"]),
            (0.10, 1.0, 3.0, Inf),
            ("nu_cell_low", "nu_cell_mid", "nu_cell_high", "nu_cell_out"))
    else
        _oev5_bin(Float64(values["screen_olv11_cusp_well_temperature_ratio"]),
            (0.01, 1.0, 2.0, Inf),
            ("well_anchor", "well_low", "well_mid", "well_high"))
    end
    return join((contract.id, spec.core_family, spec.mechanism,
        spec.exhaust_topology, "targets_$(spec.target_count)", fill, beta,
        mechanism_bin), "|")
end

_olv11_quality_key(record::AbstractDict) = _oev5_quality_key(record)

function _olv11_medium_fidelity_route(spec::OpenLossPathwayTopologySpecV11)
    _olv11_is_control(spec) && return String[]
    if spec.core_family == "magnetic_mirror"
        route = ["anisotropic_mirror_equilibrium", "fokker_planck_open_trap",
            "multiple_mirror_flow_transport", "vortex_mhd_stability",
            "neutral_beam_fast_ion_distribution", "end_expander_transport",
            "finite_build_coils"]
        spec.exhaust_topology == "two_end_bounded_direct_converter" &&
            append!(route, ["charged_end_loss_spectrum",
                "direct_converter_grid_model", "high_voltage_breakdown"])
        return route
    end
    return ["high_beta_kinetic_pic", "ambipolar_potential_solver",
        "ion_cusp_loss_orbits", "finite_beta_cusp_mhd",
        "cusp_collector_transport", "finite_build_polyhedral_coils"]
end

"Run 49 sealed v10 controls and six new open-loss pathways under six contracts."
function run_open_loss_pathway_qd_v11(seeds::Vector{Genome};
        acquisition_samples::Int = 300_000,
        random_seed::Int = 20260813,
        maximum_graph_elites::Int = 660,
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
    structural = _olv11_structural_bases(seeds)
    specs = _olv11_topology_specs()
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
        values = _olv11_ranges(spec, u)
        base = structural[_olv11_key(spec)]
        features = _olv11_acquisition_features(base, values)
        nominal = if _olv11_is_control(spec)
            _mev10_nominal(base, contract, features, values)
        else
            _olv11_nominal(base, contract, features, values)
        end
        nominal["net_electric_power_W"] > 0.0 && (positive_net_count += 1)
        nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true &&
            (nominal_pass_count += 1)
        family_sample_count[spec.core_family] += 1
        mechanism_sample_count[spec.mechanism] += 1
        exhaust_sample_count[spec.exhaust_topology] += 1
        contract_sample_count[contract.id] += 1
        structural_key = "$(contract.id)|$(_olv11_key(spec))"
        proposal = Dict{String,Any}(
            "descriptor" => _olv11_descriptor(contract, spec, features,
                values, nominal),
            "structural_stratum" => structural_key,
            "contract_id" => contract.id,
            "core_family" => spec.core_family,
            "mechanism" => spec.mechanism,
            "exhaust_topology" => spec.exhaust_topology,
            "target_count" => spec.target_count,
            "control_v10_key" => spec.control_v10_key,
            "features" => values, "nominal" => nominal)
        incumbent = get(archive, proposal["descriptor"], nothing)
        if incumbent === nothing ||
                _olv11_quality_key(proposal) < _olv11_quality_key(incumbent)
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
        sort!(candidates; by = _olv11_quality_key)
        append!(acquisitions, first(candidates,
            min(elites_per_structural_stratum, length(candidates))))
    end
    sort!(acquisitions; by = proposal ->
        (proposal["structural_stratum"], _olv11_quality_key(proposal)))
    length(acquisitions) > maximum_graph_elites &&
        (acquisitions = first(acquisitions, maximum_graph_elites))
    contract_by_id = Dict(contract.id => contract for contract in contracts)
    spec_by_key = Dict(_olv11_key(spec) => spec for spec in specs)
    records = Dict{String,Any}[]
    for acquisition in acquisitions
        contract = contract_by_id[String(acquisition["contract_id"])]
        spec_key = join(split(String(acquisition["structural_stratum"]), "|")[2:end], "|")
        spec = spec_by_key[spec_key]
        candidate = _olv11_instantiate(structural[_olv11_key(spec)], spec,
            acquisition["features"], contract)
        result = _open_loss_pathway_result(OpenLossPathwayScreenV1(contract;
            allowed_contracts = contracts), candidate)
        promoted = result["all_five_gates_passed"] === true &&
            result["positive_net_power_closure_passed"] === true &&
            !_olv11_is_control(spec)
        push!(records, Dict{String,Any}(
            "contract_id" => contract.id, "design_id" => candidate.design_id,
            "physics_hash" => candidate.physics_hash,
            "core_family" => spec.core_family,
            "mechanism" => spec.mechanism,
            "exhaust_topology" => spec.exhaust_topology,
            "target_count" => spec.target_count,
            "is_v10_control" => _olv11_is_control(spec),
            "descriptor" => acquisition["descriptor"],
            "genome" => candidate.normalized, "acquisition" => acquisition,
            "evaluation" => result,
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "positive_net_power_closure_passed" =>
                result["positive_net_power_closure_passed"],
            "promoted" => promoted,
            "medium_fidelity_route" => promoted ?
                _olv11_medium_fidelity_route(spec) : String[]))
    end
    sort!(records; by = record -> (
        record["promoted"] === true ? 0 : 1,
        record["is_v10_control"] === true ? 1 : 0,
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
        "v10_control_topology_count_per_contract" =>
            count(_olv11_is_control, specs),
        "new_mechanism_topology_count_per_contract" =>
            count(spec -> !_olv11_is_control(spec), specs),
        "structural_stratum_count" => length(strata),
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
        "family_sample_count" => family_sample_count,
        "mechanism_sample_count" => mechanism_sample_count,
        "exhaust_sample_count" => exhaust_sample_count,
        "contract_sample_count" => contract_sample_count,
        "topologies" => [Dict{String,Any}(
            "key" => _olv11_key(spec), "core_family" => spec.core_family,
            "mechanism" => spec.mechanism,
            "exhaust_topology" => spec.exhaust_topology,
            "target_count" => spec.target_count,
            "is_v10_control" => _olv11_is_control(spec)) for spec in specs],
        "declared_search_domain" => Dict{String,Any}(
            "acquisition_dimensions" => 18,
            "source_sequence" => "Halton",
            "gas_dynamic_collisionality" => "derived from n and T",
            "multiple_mirror_axial_credit" => "bounded to <=4 and applicability weighted",
            "transverse_loss" => "Bohm-reference channel retained",
            "cusp_evidence_boundary" => "high-beta electron confinement only"),
        "sealed_v10_control_lineage" => Dict{String,Any}(
            "formal_result_hash" =>
                "73c1086ee8be13231e89c657e28fafd90e5da0e098f24f1b7eec1a7b381c4d42",
            "policy" => "read-only equations and structural controls"),
        "records" => records,
        "claim_boundary" => _OLV11_SCREEN_CLAIM_BOUNDARY)
end
