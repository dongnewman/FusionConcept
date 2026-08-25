"A sealed-v11 control or a new v12 causal bridge / negative anchor."
struct CausalBridgeTopologySpecV12
    core_family::String
    mechanism::String
    exhaust_topology::String
    target_count::Int
    control_v11_key::Union{Nothing,String}
    anchor_only::Bool
    promotion_eligible::Bool
end

function _cbv12_topology_specs()
    specs = CausalBridgeTopologySpecV12[]
    for old in _olv11_topology_specs()
        push!(specs, CausalBridgeTopologySpecV12(old.core_family,
            old.mechanism, old.exhaust_topology, old.target_count,
            _olv11_key(old), false, false))
    end
    for mechanism in ("two_component_gdt", "two_component_gdmt")
        push!(specs, CausalBridgeTopologySpecV12("magnetic_mirror", mechanism,
            "two_end_expander", 2, nothing, false, true))
    end
    push!(specs, CausalBridgeTopologySpecV12(
        "inertial_electrostatic_confinement", "gridded_iec_neutron_anchor",
        "grid_and_spherical_wall", 1, nothing, true, false))
    push!(specs, CausalBridgeTopologySpecV12(
        "inertial_electrostatic_confinement",
        "gridded_iec_net_electric_candidate", "grid_and_spherical_wall", 1,
        nothing, false, true))
    push!(specs, CausalBridgeTopologySpecV12("dense_plasma_focus",
        "dpf_experimental_saturation_anchor", "pulsed_electrode_chamber", 1,
        nothing, true, false))
    return specs
end

_cbv12_is_control(spec::CausalBridgeTopologySpecV12) =
    spec.control_v11_key !== nothing

function _cbv12_key(spec::CausalBridgeTopologySpecV12)
    kind = _cbv12_is_control(spec) ? "v11_control" :
        spec.anchor_only ? "negative_anchor" : "new_bridge"
    return join((kind, spec.core_family, spec.mechanism, spec.exhaust_topology,
        "targets=$(spec.target_count)"), "|")
end

function _cbv12_build_two_component_gdt(base::Genome,
        spec::CausalBridgeTopologySpecV12)
    raw = deepcopy(base.normalized)
    multimirror = spec.mechanism == "two_component_gdmt"
    raw["label"] = "Causal bridge v12 $(_cbv12_key(spec))"
    raw["design_id"] = "pending_cbv12_gdt_structure"
    raw["mission"]["kind"] = "net_electric_pilot"
    raw["mission"]["fuel"] = "D-T"
    raw["mission"]["operating_mode"] = "steady_state"
    central_index = findfirst(region -> String(region["id"]) ==
        "v11_gdt_central", raw["plasma_regions"])
    central_index === nothing && error("missing v11 GDT central cell")
    central = raw["plasma_regions"][central_index]
    central["kind"] = "gas_dynamic_target_plasma"
    central["geometry_model"] = "collisional_warm_target_axisymmetric_cell"
    fast = deepcopy(central)
    fast["id"] = "v12_gdt_fast_ions"
    fast["kind"] = "anisotropic_fast_ion_population"
    fast["geometry_model"] = "oblique_nbi_mirror_turning_point_population"
    push!(raw["plasma_regions"], fast)
    raw["actuators"] = Any[
        _ctv4_actuator("v12_gdt_neutral_beam", "nbi", 80.0e6),
        _ctv4_actuator("v12_gdt_vortex_bias", "other", 5.0e6)]
    raw["stability_mechanisms"] = Any[
        _ctv4_mechanism("v12_two_component_gdt_bridge", "other",
            ["flute", "dclc", "fast_ion_pitch_angle_scattering",
                "axial_end_loss", "transverse_transport"],
            ["v12_gdt_neutral_beam", "v12_gdt_vortex_bias"],
            ["warm target and fast ions are separate populations",
                "fast-ion slowing reference is applicability bounded",
                "no single-temperature Maxwellian fusion credit",
                "no ideal N or N-squared multiple-mirror credit"],
            ["two_component_fokker_planck_gdt", "beam_target_nuclear_rate",
                "gas_dynamic_end_loss", "transverse_loss_floor"],
            ["gdt_fast_ion_relaxation_anikeev_2000",
                "gdt_overview_ivanov_2013", "gdt_neutron_source_molvik_2010",
                "bosch_hale_cross_sections_1992"])]
    push!(raw["flux_connections"], Dict{String,Any}(
        "from_region_id" => "v12_gdt_fast_ions",
        "to_region_id" => "v11_gdt_central",
        "kind" => "collisional_energy_and_beam_target_coupling"))
    raw["engineering"]["required_evaluators"] = Any[
        "two_component_fokker_planck_gdt", "beam_target_nuclear_rate",
        "gas_dynamic_end_loss", "transverse_loss_floor", "finite_build_coils",
        "neutronics", "remote_maintenance"]
    raw["provenance"]["origin"] = "generated"
    raw["provenance"]["claim_level"] = "structural_example"
    raw["provenance"]["parent_design_ids"] = [base.design_id]
    raw["provenance"]["source_ids"] = [
        "gdt_fast_ion_relaxation_anikeev_2000", "gdt_overview_ivanov_2013",
        "gdt_neutron_source_molvik_2010", "bosch_hale_cross_sections_1992"]
    push!(raw["provenance"]["notes"],
        "v12_two_component_bridge_no_single_temperature_fusion_credit")
    basis = "fixed v12 two-component GDT declaration"
    for (name, value, unit) in (
            ("screen_cbv12_two_component_gdt_active", 1.0, "1"),
            ("screen_olv11_gdt_active", 1.0, "1"),
            ("screen_olv11_cell_count", multimirror ? 8.0 : 1.0, "1"),
            ("screen_cbv12_target_electron_temperature", 0.25, "keV"),
            ("screen_cbv12_target_ion_temperature", 0.25, "keV"),
            ("screen_cbv12_fast_ion_energy", 50.0, "keV"),
            ("screen_cbv12_fast_beta_fraction", 0.50, "1"),
            ("screen_cbv12_nbi_absorption_fraction", 0.75, "1"),
            ("screen_cbv12_nbi_wall_efficiency", 0.45, "1"),
            ("screen_cbv12_nbi_power", 80.0e6, "W"))
        _ctv4_set_target!(raw, name, value, unit; basis = basis)
    end
    provisional = parse_genome(raw)
    report = validate_genome(provisional)
    report.valid || error(join(report.errors, "; "))
    raw["design_id"] = "structure_$(provisional.physics_hash[1:20])"
    return parse_genome(raw)
end

function _cbv12_build_iec(seed::Genome, spec::CausalBridgeTopologySpecV12)
    raw = deepcopy(seed.normalized)
    anchor = spec.anchor_only
    raw["label"] = "Causal bridge v12 $(_cbv12_key(spec))"
    raw["design_id"] = "pending_cbv12_iec_structure"
    raw["family"] = "inertial_electrostatic_confinement"
    raw["mission"]["kind"] = anchor ? "fusion_neutron_source" :
        "net_electric_pilot"
    raw["mission"]["fuel"] = anchor ? "D-D" : "D-T"
    raw["mission"]["operating_mode"] = "steady_state"
    raw["topology"] = Dict{String,Any}(
        "field_line_class" => "electrostatic_radial",
        "rotation_transform_sources" => ["not_applicable"],
        "expected_flux_surfaces" => false, "expected_separatrix" => false)
    raw["symmetry"] = Dict{String,Any}(
        "class" => "none", "field_periods" => 1,
        "hard_constraints" => ["explicit material cathode grid",
            "grid interception and nonequilibrium recirculation retained",
            "experimental neutron efficiency is an upper bound"])
    raw["plasma_regions"] = Any[
        _ctv4_region("v12_iec_core", "iec_acceleration_core",
            "finite_spherical_gridded_electrostatic_core", Dict(
                "chamber_radius" => _ctv4_quantity(1.0, "m"),
                "grid_radius" => _ctv4_quantity(0.25, "m"))),
        _ctv4_region("v12_iec_wall", "divertor_or_exhaust_region",
            "spherical_neutron_and_particle_wall")]
    raw["field_sources"] = Any[
        _ctv4_source("v12_iec_grid", "electrostatic_grid",
            "finite_wire_spherical_cathode_grid", "refractory_metal")]
    raw["actuators"] = Any[
        _ctv4_actuator("v12_iec_hv_supply", "other", 1.0e6)]
    raw["stability_mechanisms"] = Any[
        _ctv4_mechanism("v12_gridded_iec_boundary", "other",
            ["space_charge", "ion_thermalization", "grid_interception",
                "bremsstrahlung"], ["v12_iec_hv_supply"],
            ["neutron production does not establish energy gain",
                "no persistent reactor-scale virtual electrode is credited"],
            ["iec_poisson_orbit_grid_model",
                "nonequilibrium_fokker_planck_power"],
            ["iec_hirsch_1967", "nonequilibrium_limit_rider_1997",
                "iec_efficiency_anchor_biswas_2019"])]
    raw["flux_connections"] = Any[
        Dict("from_region_id" => "v12_iec_core",
            "to_region_id" => "v12_iec_wall", "kind" => "grid_and_wall_loss")]
    raw["exhaust"] = Dict{String,Any}(
        "kind" => "grid_and_spherical_wall",
        "region_ids" => ["v12_iec_wall"],
        "evaluation_requirements" => ["grid_interception",
            "high_voltage_breakdown", "particle_implantation"])
    raw["engineering"]["magnet_technology"] =
        ["no magnetic confinement; high-voltage feedthroughs"]
    raw["engineering"]["blanket"] = Dict{String,Any}(
        "required" => !anchor,
        "concept" => anchor ? nothing :
            "spherical modular D-T breeding blanket placeholder")
    !anchor && (raw["engineering"]["blanket"]["target_tbr"] =
        _ctv4_quantity(1.10, "1";
            basis = "v12 declared target, not a neutronics result"))
    raw["engineering"]["maintenance"] = Dict(
        "architecture" => "replaceable inner grid and feedthrough assembly",
        "access_paths" => ["radial grid cartridge", "high-voltage feedthrough"])
    raw["engineering"]["required_evaluators"] = [
        "iec_poisson_orbit_grid_model", "nonequilibrium_fokker_planck_power",
        "grid_thermal_stress", "high_voltage_breakdown"]
    raw["provenance"]["origin"] = "generated"
    raw["provenance"]["claim_level"] = "structural_example"
    raw["provenance"]["parent_design_ids"] = [seed.design_id]
    raw["provenance"]["source_ids"] = ["iec_hirsch_1967",
        "nonequilibrium_limit_rider_1997", "iec_efficiency_anchor_biswas_2019"]
    push!(raw["provenance"]["notes"],
        "v12_iec_experimental_neutron_source_not_reactor_credit")
    basis = "fixed v12 gridded IEC declaration"
    for (name, value, unit) in (
            ("screen_cbv12_anchor_only", anchor ? 1.0 : 0.0, "1"),
            ("screen_cbv12_iec_voltage", 80.0e3, "V"),
            ("screen_cbv12_iec_input_power", 1.0e6, "W"),
            ("screen_cbv12_iec_grid_transparency", 0.95, "1"),
            ("screen_cbv12_iec_grid_radius_fraction", 0.25, "1"))
        _ctv4_set_target!(raw, name, value, unit; basis = basis)
    end
    provisional = parse_genome(raw)
    report = validate_genome(provisional)
    report.valid || error(join(report.errors, "; "))
    raw["design_id"] = "structure_$(provisional.physics_hash[1:20])"
    return parse_genome(raw)
end

function _cbv12_build_dpf(seed::Genome, spec::CausalBridgeTopologySpecV12)
    raw = deepcopy(seed.normalized)
    raw["label"] = "Causal bridge v12 $(_cbv12_key(spec))"
    raw["design_id"] = "pending_cbv12_dpf_structure"
    raw["family"] = "dense_plasma_focus"
    raw["mission"]["kind"] = "fusion_neutron_source"
    raw["mission"]["fuel"] = "D-D"
    raw["mission"]["operating_mode"] = "pulsed"
    raw["topology"] = Dict{String,Any}(
        "field_line_class" => "coaxial_pulsed_pinch",
        "rotation_transform_sources" => ["not_applicable"],
        "expected_flux_surfaces" => false, "expected_separatrix" => false)
    raw["symmetry"] = Dict{String,Any}(
        "class" => "axisymmetric", "field_periods" => 1,
        "hard_constraints" => ["explicit electrodes and capacitor bank",
            "no unbounded current-yield power law",
            "Q=0.01 is an optimistic upper bound"])
    raw["plasma_regions"] = Any[
        _ctv4_region("v12_dpf_discharge", "dpf_coaxial_discharge",
            "finite_mather_type_coaxial_sheath_and_pinch", Dict(
                "anode_radius" => _ctv4_quantity(0.20, "m"),
                "anode_half_length" => _ctv4_quantity(0.50, "m"))),
        _ctv4_region("v12_dpf_chamber", "divertor_or_exhaust_region",
            "replaceable_pulsed_electrode_chamber")]
    raw["field_sources"] = Any[
        _ctv4_source("v12_dpf_electrodes", "coaxial_electrode",
            "finite_coaxial_anode_cathode", "refractory_metal"),
        _ctv4_source("v12_dpf_bank", "capacitor_bank",
            "pulsed_power_storage_and_switch", "electrical_components")]
    raw["actuators"] = Any[
        _ctv4_actuator("v12_dpf_capacitor_driver", "other", 1.0e6)]
    raw["stability_mechanisms"] = Any[
        _ctv4_mechanism("v12_dpf_saturation_boundary", "other",
            ["sausage", "kink", "beam_target_partition", "yield_saturation"],
            ["v12_dpf_capacitor_driver"],
            ["experimental neutron production is credited only inside domain",
                "I^4 or steeper extrapolation is forbidden"],
            ["dpf_kinetic_discharge", "electrode_erosion_and_repetition"],
            ["dpf_kinetic_schmidt_2012", "dpf_scaling_failure_auluck_2023",
                "dpf_q_ceiling_lee_2022"])]
    raw["flux_connections"] = Any[
        Dict("from_region_id" => "v12_dpf_discharge",
            "to_region_id" => "v12_dpf_chamber", "kind" => "pulsed_debris_and_radiation")]
    raw["exhaust"] = Dict{String,Any}(
        "kind" => "pulsed_electrode_chamber",
        "region_ids" => ["v12_dpf_chamber"],
        "evaluation_requirements" => ["electrode_erosion_and_repetition",
            "pulsed_chamber_clearing"])
    raw["engineering"]["magnet_technology"] =
        ["self-field coaxial discharge with capacitor bank"]
    raw["engineering"]["blanket"] = Dict{String,Any}(
        "required" => false, "concept" => nothing)
    raw["engineering"]["maintenance"] = Dict(
        "architecture" => "replaceable coaxial electrode cartridge",
        "access_paths" => ["axial electrode cartridge", "switchyard"])
    raw["engineering"]["required_evaluators"] = ["dpf_kinetic_discharge",
        "electrode_erosion_and_repetition", "pulsed_power_lifetime"]
    raw["provenance"]["origin"] = "generated"
    raw["provenance"]["claim_level"] = "structural_example"
    raw["provenance"]["parent_design_ids"] = [seed.design_id]
    raw["provenance"]["source_ids"] = ["dpf_kinetic_schmidt_2012",
        "dpf_scaling_failure_auluck_2023", "dpf_q_ceiling_lee_2022"]
    push!(raw["provenance"]["notes"],
        "v12_dpf_negative_anchor_no_unbounded_yield_scaling")
    basis = "fixed v12 DPF saturation anchor declaration"
    for (name, value, unit) in (
            ("screen_cbv12_anchor_only", 1.0, "1"),
            ("screen_cbv12_dpf_stored_energy", 100.0e3, "J"),
            ("screen_cbv12_dpf_peak_current", 1.0e6, "A"),
            ("screen_cbv12_dpf_repetition_rate", 1.0, "Hz"),
            ("screen_cbv12_dpf_availability", 0.50, "1"),
            ("screen_cbv12_dpf_driver_efficiency", 0.50, "1"))
        _ctv4_set_target!(raw, name, value, unit; basis = basis)
    end
    provisional = parse_genome(raw)
    report = validate_genome(provisional)
    report.valid || error(join(report.errors, "; "))
    raw["design_id"] = "structure_$(provisional.physics_hash[1:20])"
    return parse_genome(raw)
end

function _cbv12_structural_bases(seeds::Vector{Genome})
    v11 = _olv11_structural_bases(seeds)
    result = Dict{String,Genome}()
    for spec in _cbv12_topology_specs()
        if _cbv12_is_control(spec)
            result[_cbv12_key(spec)] = v11[spec.control_v11_key]
        end
    end
    tokamak = only(filter(genome -> genome.family == "tokamak_axisymmetric",
        _common_baseline_genomes(seeds)))
    single_v11 = only(filter(spec -> spec.core_family == "magnetic_mirror" &&
        spec.mechanism == "gas_dynamic_single_cell" &&
        spec.exhaust_topology == "two_end_expander", _olv11_topology_specs()))
    multi_v11 = only(filter(spec -> spec.core_family == "magnetic_mirror" &&
        spec.mechanism == "gas_dynamic_multimirror" &&
        spec.exhaust_topology == "two_end_expander", _olv11_topology_specs()))
    for spec in _cbv12_topology_specs()
        _cbv12_is_control(spec) && continue
        if spec.mechanism == "two_component_gdt"
            result[_cbv12_key(spec)] = _cbv12_build_two_component_gdt(
                v11[_olv11_key(single_v11)], spec)
        elseif spec.mechanism == "two_component_gdmt"
            result[_cbv12_key(spec)] = _cbv12_build_two_component_gdt(
                v11[_olv11_key(multi_v11)], spec)
        elseif spec.core_family == "inertial_electrostatic_confinement"
            result[_cbv12_key(spec)] = _cbv12_build_iec(tokamak, spec)
        else
            result[_cbv12_key(spec)] = _cbv12_build_dpf(tokamak, spec)
        end
    end
    return result
end

function _cbv12_common_values(u)
    return Dict{String,Any}(
        "screen_aspect_ratio" => 1.0,
        "screen_plasma_fill_fraction" => 0.15 + 0.70u[2],
        "screen_beta" => 0.01,
        "screen_temperature" => 1.0,
        "screen_field_quality" => 0.80 + 0.20u[5],
        "screen_q95" => 3.5, "screen_mirror_ratio" => 1.0,
        "screen_plug_strength" => 0.0,
        "screen_minimum_b_strength" => 0.0,
        "screen_shear_strength" => 0.0,
        "screen_coil_pack_thickness" => 0.10 + 0.40u[9],
        "screen_support_thickness" => 0.10 + 0.50u[10],
        "screen_exhaust_area_fraction" => 0.10 + 0.40u[8],
        "screen_exhaust_flux_expansion" => 1.0,
        "screen_declared_actuator_power" => 0.0,
        "screen_plasma_current_transform_fraction" => 0.0,
        "screen_external_transform_fraction" => 0.0,
        "screen_three_dimensional_field_fraction" => 0.0)
end

function _cbv12_ranges(spec::CausalBridgeTopologySpecV12, u)
    if _cbv12_is_control(spec)
        old = only(filter(item -> _olv11_key(item) == spec.control_v11_key,
            _olv11_topology_specs()))
        return _olv11_ranges(old, u)
    elseif spec.core_family == "magnetic_mirror"
        old = only(filter(item -> item.mechanism ==
            (spec.mechanism == "two_component_gdmt" ?
                "gas_dynamic_multimirror" : "gas_dynamic_single_cell") &&
            item.exhaust_topology == "two_end_expander", _olv11_topology_specs()))
        values = _olv11_ranges(old, u)
        values["screen_temperature"] = 1.0
        # The v11 single-temperature beta interval implies target densities far
        # outside the warm GDT regime at a common 4 T plasma-field contract.
        # Sample the two physical pressure components independently, then store
        # their sum/fraction in the common genome fields.
        target_beta = 1.0e-4 * 100.0^u[3]
        fast_beta = 1.0e-3 * 100.0^u[7]
        values["screen_beta"] = target_beta + fast_beta
        values["screen_cbv12_fast_beta_fraction"] =
            fast_beta / (target_beta + fast_beta)
        values["screen_plasma_fill_fraction"] = 0.03 + 0.27u[2]
        values["screen_olv11_central_aspect_ratio"] = 2.0 + 10.0u[13]
        values["screen_cbv12_two_component_gdt_active"] = 1.0
        values["screen_cbv12_target_electron_temperature"] =
            0.05 * 24.0^u[4]
        values["screen_cbv12_target_ion_temperature"] =
            0.05 * 20.0^u[5]
        values["screen_cbv12_fast_ion_energy"] = 20.0 + 60.0u[6]
        values["screen_cbv12_nbi_absorption_fraction"] = 0.50 + 0.45u[8]
        values["screen_cbv12_nbi_wall_efficiency"] = 0.30 + 0.40u[9]
        values["screen_cbv12_nbi_power"] = 5.0e6 * 40.0^u[16]
        values["screen_olv11_nbi_power"] = values["screen_cbv12_nbi_power"]
        values["screen_olv11_bias_power"] = 1.0e6 + 14.0e6u[17]
        values["screen_declared_actuator_power"] =
            values["screen_cbv12_nbi_power"] + values["screen_olv11_bias_power"]
        return values
    elseif spec.core_family == "inertial_electrostatic_confinement"
        values = _cbv12_common_values(u)
        values["screen_cbv12_anchor_only"] = spec.anchor_only ? 1.0 : 0.0
        values["screen_cbv12_iec_voltage"] = 10.0e3 * 20.0^u[4]
        values["screen_cbv12_iec_input_power"] = 1.0e3 * 2.0e5^u[6]
        values["screen_cbv12_iec_grid_transparency"] = 0.75 + 0.245u[7]
        values["screen_cbv12_iec_grid_radius_fraction"] = 0.10 + 0.50u[8]
        values["screen_declared_actuator_power"] =
            values["screen_cbv12_iec_input_power"]
        return values
    end
    values = _cbv12_common_values(u)
    values["screen_aspect_ratio"] = 1.0 + 4.0u[1]
    values["screen_cbv12_anchor_only"] = 1.0
    values["screen_cbv12_dpf_stored_energy"] = 100.0 * 1.3e4^u[4]
    values["screen_cbv12_dpf_peak_current"] = 0.10e6 + 3.50e6u[5]
    values["screen_cbv12_dpf_repetition_rate"] = 0.01 * 1000.0^u[6]
    values["screen_cbv12_dpf_availability"] = 0.20 + 0.70u[7]
    values["screen_cbv12_dpf_driver_efficiency"] = 0.10 + 0.60u[8]
    values["screen_declared_actuator_power"] =
        values["screen_cbv12_dpf_stored_energy"] *
        values["screen_cbv12_dpf_repetition_rate"]
    return values
end

const _CBV12_CUSTOM_UNITS = Dict(
    "screen_cbv12_two_component_gdt_active" => "1",
    "screen_cbv12_target_electron_temperature" => "keV",
    "screen_cbv12_target_ion_temperature" => "keV",
    "screen_cbv12_fast_ion_energy" => "keV",
    "screen_cbv12_fast_beta_fraction" => "1",
    "screen_cbv12_nbi_absorption_fraction" => "1",
    "screen_cbv12_nbi_wall_efficiency" => "1",
    "screen_cbv12_nbi_power" => "W",
    "screen_cbv12_anchor_only" => "1",
    "screen_cbv12_iec_voltage" => "V",
    "screen_cbv12_iec_input_power" => "W",
    "screen_cbv12_iec_grid_transparency" => "1",
    "screen_cbv12_iec_grid_radius_fraction" => "1",
    "screen_cbv12_dpf_stored_energy" => "J",
    "screen_cbv12_dpf_peak_current" => "A",
    "screen_cbv12_dpf_repetition_rate" => "Hz",
    "screen_cbv12_dpf_availability" => "1",
    "screen_cbv12_dpf_driver_efficiency" => "1")

function _cbv12_set_targets!(raw::Dict{String,Any}, values::AbstractDict,
        contract::SharedOuterEnvelopeContractV1)
    _ccv9_set_targets!(raw, values, contract)
    _olv11_set_custom_targets!(raw, values, contract)
    basis = "causal bridge v12 search gene under $(contract.id)"
    for (name, unit) in _CBV12_CUSTOM_UNITS
        haskey(values, name) || continue
        _ctv4_set_target!(raw, name, Float64(values[name]), unit; basis = basis)
    end
    return raw
end

function _cbv12_update_components!(raw::Dict{String,Any},
        spec::CausalBridgeTopologySpecV12, values::AbstractDict,
        contract::SharedOuterEnvelopeContractV1)
    if spec.core_family == "magnetic_mirror"
        nbi = Float64(values["screen_cbv12_nbi_power"])
        bias = Float64(values["screen_olv11_bias_power"])
        for actuator in raw["actuators"]
            id = String(actuator["id"])
            power = id == "v12_gdt_neutral_beam" ? nbi :
                id == "v12_gdt_vortex_bias" ? bias : 0.0
            actuator["parameters"]["power"] = _ctv4_quantity(power, "W";
                basis = "v12 explicit two-component GDT actuator")
        end
        provisional = parse_genome(raw)
        features = _oe_features(provisional)
        geometry = _olv11_gdt_geometry(provisional, features, contract, values)
        for region in raw["plasma_regions"]
            String(region["kind"]) in ("gas_dynamic_target_plasma",
                "anisotropic_fast_ion_population") || continue
            _set_common_quantity!(region["parameters"], "plasma_radius",
                geometry.a, "m"; basis = "v12 scored two-component GDT geometry")
            _set_common_quantity!(region["parameters"], "half_length",
                geometry.central_half, "m";
                basis = "v12 scored two-component GDT geometry")
        end
    elseif spec.core_family == "inertial_electrostatic_confinement"
        only(raw["actuators"])["parameters"]["power"] = _ctv4_quantity(
            values["screen_cbv12_iec_input_power"], "W";
            basis = "v12 IEC high-voltage supply input")
        provisional = parse_genome(raw)
        features = _oe_features(provisional)
        geometry = _cbv12_geometry(features, contract; extra_build_m = 0.10)
        grid_radius = geometry.radius *
            Float64(values["screen_cbv12_iec_grid_radius_fraction"])
        core = only(filter(region -> String(region["kind"]) ==
            "iec_acceleration_core", raw["plasma_regions"]))
        _set_common_quantity!(core["parameters"], "chamber_radius",
            geometry.radius, "m"; basis = "v12 scored IEC geometry")
        _set_common_quantity!(core["parameters"], "grid_radius",
            grid_radius, "m"; basis = "v12 scored IEC geometry")
        grid = only(filter(source -> String(source["kind"]) ==
            "electrostatic_grid", raw["field_sources"]))
        _set_common_quantity!(grid["parameters"], "grid_radius", grid_radius,
            "m"; basis = "v12 scored IEC geometry")
        _set_common_quantity!(grid["parameters"], "voltage",
            values["screen_cbv12_iec_voltage"], "V";
            basis = "v12 scored IEC voltage")
        _set_common_quantity!(grid["parameters"], "transparency",
            values["screen_cbv12_iec_grid_transparency"], "1";
            basis = "v12 scored IEC grid transparency")
    else
        only(raw["actuators"])["parameters"]["power"] = _ctv4_quantity(
            values["screen_declared_actuator_power"], "W";
            basis = "v12 DPF average stored-energy rate")
        provisional = parse_genome(raw)
        features = _oe_features(provisional)
        geometry = _cbv12_geometry(features, contract; axial = true,
            extra_build_m = 0.20)
        discharge = only(filter(region -> String(region["kind"]) ==
            "dpf_coaxial_discharge", raw["plasma_regions"]))
        _set_common_quantity!(discharge["parameters"], "anode_radius",
            geometry.radius, "m"; basis = "v12 scored DPF geometry")
        _set_common_quantity!(discharge["parameters"], "anode_half_length",
            geometry.half_length, "m"; basis = "v12 scored DPF geometry")
        electrodes = only(filter(source -> String(source["kind"]) ==
            "coaxial_electrode", raw["field_sources"]))
        _set_common_quantity!(electrodes["parameters"], "peak_current",
            values["screen_cbv12_dpf_peak_current"], "A";
            basis = "v12 scored DPF current")
        bank = only(filter(source -> String(source["kind"]) ==
            "capacitor_bank", raw["field_sources"]))
        _set_common_quantity!(bank["parameters"], "stored_energy",
            values["screen_cbv12_dpf_stored_energy"], "J";
            basis = "v12 scored DPF stored energy")
    end
    return raw
end

function _cbv12_instantiate(base::Genome, spec::CausalBridgeTopologySpecV12,
        values::AbstractDict, contract::SharedOuterEnvelopeContractV1)
    if _cbv12_is_control(spec)
        old = only(filter(item -> _olv11_key(item) == spec.control_v11_key,
            _olv11_topology_specs()))
        return _olv11_instantiate(base, old, values, contract)
    end
    raw = deepcopy(base.normalized)
    _cbv12_set_targets!(raw, values, contract)
    _cbv12_update_components!(raw, spec, values, contract)
    raw["design_id"] = "pending_cbv12_elite"
    provisional = parse_genome(raw)
    report = validate_genome(provisional)
    report.valid || error(join(report.errors, "; "))
    raw["design_id"] = "concept_$(provisional.physics_hash[1:20])"
    return parse_genome(raw)
end

function _cbv12_acquisition_features(base::Genome, values::AbstractDict)
    return _olv11_acquisition_features(base, values)
end

function _cbv12_descriptor(contract::SharedOuterEnvelopeContractV1,
        spec::CausalBridgeTopologySpecV12, features, values, nominal)
    fill = _oev5_bin(features.plasma_fill_fraction, (0.40, 0.70, Inf),
        ("fill_low", "fill_mid", "fill_high"))
    mechanism_bin = if _cbv12_is_control(spec)
        "sealed_v11_control"
    elseif spec.core_family == "magnetic_mirror"
        _oev5_bin(Float64(nominal["target_electron_temperature_keV"]),
            (0.15, 0.50, Inf), ("Te_warm_low", "Te_warm_mid", "Te_warm_high"))
    elseif spec.core_family == "inertial_electrostatic_confinement"
        _oev5_bin(Float64(nominal["iec_voltage_V"]),
            (50.0e3, 120.0e3, Inf), ("V_low", "V_mid", "V_high"))
    else
        _oev5_bin(Float64(nominal["stored_energy_per_shot_J"]),
            (10.0e3, 300.0e3, Inf), ("E_low", "E_mid", "E_high"))
    end
    return join((contract.id, spec.core_family, spec.mechanism,
        spec.exhaust_topology, "targets_$(spec.target_count)", fill,
        mechanism_bin), "|")
end

_cbv12_quality_key(record::AbstractDict) = _oev5_quality_key(record)

function _cbv12_medium_fidelity_route(spec::CausalBridgeTopologySpecV12)
    !spec.promotion_eligible && return String[]
    spec.core_family == "magnetic_mirror" && return [
        "anisotropic_mirror_equilibrium", "two_component_fokker_planck_gdt",
        "neutral_beam_deposition_and_fast_ion_orbits", "beam_target_nuclear_rate",
        "vortex_mhd_stability", "end_expander_transport", "finite_build_coils"]
    return ["iec_poisson_orbit_grid_model", "collisional_fokker_planck",
        "grid_thermal_stress", "high_voltage_breakdown", "neutronics"]
end

"Run 55 sealed v11 controls and five v12 bridge/anchor structures under six contracts."
function run_causal_bridge_qd_v12(seeds::Vector{Genome};
        acquisition_samples::Int = 300_000,
        random_seed::Int = 20260813,
        maximum_graph_elites::Int = 720,
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
    structural = _cbv12_structural_bases(seeds)
    specs = _cbv12_topology_specs()
    strata = [(contract, spec) for contract in contracts for spec in specs]
    primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61)
    archive = Dict{String,Dict{String,Any}}()
    positive_net_count = 0
    nominal_pass_count = 0
    family_sample_count = Dict(family => 0 for family in sort!(unique(
        spec.core_family for spec in specs)))
    mechanism_sample_count = Dict(spec.mechanism => 0 for spec in specs)
    contract_sample_count = Dict(contract.id => 0 for contract in contracts)
    for index in 1:acquisition_samples
        contract, spec = strata[mod1(index, length(strata))]
        u = ntuple(axis -> _ctv4_halton(index, primes[axis]), length(primes))
        values = _cbv12_ranges(spec, u)
        base = structural[_cbv12_key(spec)]
        features = _cbv12_acquisition_features(base, values)
        nominal = if _cbv12_is_control(spec)
            old = only(filter(item -> _olv11_key(item) == spec.control_v11_key,
                _olv11_topology_specs()))
            _olv11_is_control(old) ? _mev10_nominal(base, contract, features, values) :
                _olv11_nominal(base, contract, features, values)
        else
            _cbv12_nominal(base, contract, features, values)
        end
        nominal["net_electric_power_W"] > 0.0 && (positive_net_count += 1)
        nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true &&
            (nominal_pass_count += 1)
        family_sample_count[spec.core_family] += 1
        mechanism_sample_count[spec.mechanism] += 1
        contract_sample_count[contract.id] += 1
        proposal = Dict{String,Any}(
            "descriptor" => _cbv12_descriptor(contract, spec, features, values, nominal),
            "structural_stratum" => "$(contract.id)|$(_cbv12_key(spec))",
            "contract_id" => contract.id, "core_family" => spec.core_family,
            "mechanism" => spec.mechanism,
            "exhaust_topology" => spec.exhaust_topology,
            "target_count" => spec.target_count,
            "control_v11_key" => spec.control_v11_key,
            "anchor_only" => spec.anchor_only,
            "promotion_eligible" => spec.promotion_eligible,
            "features" => values, "nominal" => nominal)
        incumbent = get(archive, proposal["descriptor"], nothing)
        if incumbent === nothing ||
                _cbv12_quality_key(proposal) < _cbv12_quality_key(incumbent)
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
        sort!(candidates; by = _cbv12_quality_key)
        append!(acquisitions, first(candidates,
            min(elites_per_structural_stratum, length(candidates))))
    end
    sort!(acquisitions; by = proposal ->
        (proposal["structural_stratum"], _cbv12_quality_key(proposal)))
    length(acquisitions) > maximum_graph_elites &&
        (acquisitions = first(acquisitions, maximum_graph_elites))
    contract_by_id = Dict(contract.id => contract for contract in contracts)
    spec_by_key = Dict(_cbv12_key(spec) => spec for spec in specs)
    records = Dict{String,Any}[]
    for acquisition in acquisitions
        contract = contract_by_id[String(acquisition["contract_id"])]
        spec_key = join(split(String(acquisition["structural_stratum"]), "|")[2:end], "|")
        spec = spec_by_key[spec_key]
        candidate = _cbv12_instantiate(structural[_cbv12_key(spec)], spec,
            acquisition["features"], contract)
        result = if _cbv12_is_control(spec)
            _open_loss_pathway_result(OpenLossPathwayScreenV1(contract;
                allowed_contracts = contracts), candidate)
        else
            _causal_bridge_result(CausalBridgeScreenV1(contract;
                allowed_contracts = contracts), candidate)
        end
        promoted = result["all_five_gates_passed"] === true &&
            result["positive_net_power_closure_passed"] === true &&
            spec.promotion_eligible
        push!(records, Dict{String,Any}(
            "contract_id" => contract.id, "design_id" => candidate.design_id,
            "physics_hash" => candidate.physics_hash,
            "core_family" => spec.core_family, "mechanism" => spec.mechanism,
            "exhaust_topology" => spec.exhaust_topology,
            "target_count" => spec.target_count,
            "is_v11_control" => _cbv12_is_control(spec),
            "anchor_only" => spec.anchor_only,
            "promotion_eligible" => spec.promotion_eligible,
            "descriptor" => acquisition["descriptor"],
            "genome" => candidate.normalized, "acquisition" => acquisition,
            "evaluation" => result,
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "positive_net_power_closure_passed" =>
                result["positive_net_power_closure_passed"],
            "promoted" => promoted,
            "medium_fidelity_route" => promoted ?
                _cbv12_medium_fidelity_route(spec) : String[]))
    end
    sort!(records; by = record -> (
        record["promoted"] === true ? 0 : 1,
        record["is_v11_control"] === true ? 1 : 0,
        count(value -> Float64(value) < 0.0,
            Base.values(record["evaluation"]["nominal"]["margins"])),
        sum(log1p(-min(0.0, Float64(value))) for value in
            Base.values(record["evaluation"]["nominal"]["margins"])),
        -Float64(record["evaluation"]["nominal"]["net_electric_power_W"]),
        record["physics_hash"]))
    return Dict{String,Any}(
        "algorithm" => "balanced Halton acquisition plus causal-bridge and negative-anchor failure-aware MAP-Elites",
        "random_seed" => random_seed,
        "acquisition_samples" => acquisition_samples,
        "contract_count" => length(contracts),
        "contracts" => [_oe_contract_dict(contract) for contract in contracts],
        "topology_count_per_contract" => length(specs),
        "v11_control_topology_count_per_contract" => count(_cbv12_is_control, specs),
        "new_bridge_or_anchor_topology_count_per_contract" =>
            count(spec -> !_cbv12_is_control(spec), specs),
        "negative_anchor_topology_count_per_contract" =>
            count(spec -> spec.anchor_only, specs),
        "promotion_eligible_new_topology_count_per_contract" =>
            count(spec -> spec.promotion_eligible, specs),
        "structural_stratum_count" => length(strata),
        "acquisition_archive_cell_count" => length(archive),
        "acquisition_positive_net_count" => positive_net_count,
        "acquisition_nominal_physics_and_engineering_pass_count" => nominal_pass_count,
        "explicit_graph_elite_count" => length(records),
        "explicit_graph_five_gate_pass_count" => count(record ->
            record["all_five_gates_passed"] === true, records),
        "explicit_graph_positive_net_count" => count(record ->
            record["positive_net_power_closure_passed"] === true, records),
        "promotion_count" => count(record -> record["promoted"] === true, records),
        "family_sample_count" => family_sample_count,
        "mechanism_sample_count" => mechanism_sample_count,
        "contract_sample_count" => contract_sample_count,
        "topologies" => [Dict{String,Any}(
            "key" => _cbv12_key(spec), "core_family" => spec.core_family,
            "mechanism" => spec.mechanism,
            "exhaust_topology" => spec.exhaust_topology,
            "target_count" => spec.target_count,
            "is_v11_control" => _cbv12_is_control(spec),
            "anchor_only" => spec.anchor_only,
            "promotion_eligible" => spec.promotion_eligible) for spec in specs],
        "declared_search_domain" => Dict{String,Any}(
            "acquisition_dimensions" => 18, "source_sequence" => "Halton",
            "gdt_target_electron_temperature_keV" => [0.05, 1.20],
            "gdt_target_ion_temperature_keV" => [0.05, 1.00],
            "gdt_fast_ion_energy_keV_lab" => [20.0, 80.0],
            "gdt_target_beta" => [1.0e-4, 1.0e-2],
            "gdt_fast_ion_beta" => [1.0e-3, 1.0e-1],
            "gdt_plasma_fill_fraction" => [0.03, 0.30],
            "gdt_fast_ion_relaxation" =>
                "0.70 ms experimental reference scaled as Te^1.5/n inside bounded domain",
            "iec_fusion_to_input_efficiency" => "bounded to <=1e-5",
            "dpf_fusion_gain" => "bounded to <=0.01; no unbounded current power law"),
        "sealed_v11_control_lineage" => Dict{String,Any}(
            "formal_result_hash" =>
                "5284d5cae8a79e3ef7a26bf241bbe8ad8836472f00873bcff8c4cabb5d76da27",
            "policy" => "read-only equations and structural controls"),
        "records" => records, "claim_boundary" => _CBV12_SCREEN_CLAIM_BOUNDARY)
end
