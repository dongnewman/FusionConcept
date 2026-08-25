"A v7 structural branch: RFP baseline, RFP with boundary-mode control, or dipole."
struct SelfOrganizedTopologySpecV7
    family::String
    mechanism::String
    target_count::Int

    function SelfOrganizedTopologySpecV7(family::AbstractString,
            mechanism::AbstractString, target_count::Integer)
        f, m, n = String(family), String(mechanism), Int(target_count)
        f in ("reversed_field_pinch", "levitated_dipole") ||
            throw(ArgumentError("unsupported v7 family $f"))
        allowed = f == "reversed_field_pinch" ?
            ("self_organized_qsh", "qsh_pulsed_poloidal_current_drive",
                "qsh_ppcd_boundary_mode_control") :
            ("levitated_inward_pinch",)
        m in allowed || throw(ArgumentError("unsupported $f mechanism $m"))
        n in (2, 4, 8) || throw(ArgumentError("target count must be 2, 4, or 8"))
        new(f, m, n)
    end
end

function _sov7_specs()
    [SelfOrganizedTopologySpecV7(f, m, n)
        for (f, m) in (
            ("reversed_field_pinch", "self_organized_qsh"),
            ("reversed_field_pinch", "qsh_pulsed_poloidal_current_drive"),
            ("reversed_field_pinch", "qsh_ppcd_boundary_mode_control"),
            ("levitated_dipole", "levitated_inward_pinch"))
        for n in (2, 4, 8)]
end

_sov7_key(s::SelfOrganizedTopologySpecV7) =
    "$(s.family)|$(s.mechanism)|targets=$(s.target_count)"

function _sov7_closed_exhaust_graph(target_count::Int)
    core = _ctv4_region("so_core", "closed_toroidal_core",
        "v7_same_envelope_toroidal_proxy")
    sol = _ctv4_region("so_sol", "scrape_off_layer",
        "separatrix_to_open_field_line_shell")
    targets = Any[_ctv4_region("so_target_$i", "divertor_or_exhaust_region",
        "replaceable_finite_area_target") for i in 1:target_count]
    regions = Any[core, sol, targets...]
    connections = Any[
        Dict("from_region_id" => "so_core", "to_region_id" => "so_sol",
            "kind" => "cross_separatrix_transport"),
        [Dict("from_region_id" => "so_sol", "to_region_id" => "so_target_$i",
            "kind" => "open_field_line") for i in 1:target_count]...]
    exhaust = Dict{String,Any}(
        "kind" => "distributed_finite_area_replaceable_targets",
        "region_ids" => ["so_sol";
            ["so_target_$i" for i in 1:target_count]],
        "evaluation_requirements" => ["separatrix_field_line_mapping",
            "sol_transport", "target_heat_flux",
            "impurity_and_helium_ash_exhaust"])
    regions, connections, exhaust
end

function _sov7_stability(spec::SelfOrganizedTopologySpecV7)
    if spec.family == "reversed_field_pinch"
        ids = ["rfp_sha_lorenzini_2008", "rfp_helical_lorenzini_2009"]
        assumptions = [
            "a dominant helical state produces partial flux-surface recovery",
            "secondary tearing modes remain a fidelity-1 unknown"]
        actuators = String[]
        if spec.mechanism in ("qsh_pulsed_poloidal_current_drive",
                "qsh_ppcd_boundary_mode_control")
            push!(ids, "rfp_ppcd_sarff_1997")
            push!(assumptions,
                "PPCD confinement credit is transient and pays declared power")
            push!(actuators, "rfp_ppcd")
        end
        if spec.mechanism == "qsh_ppcd_boundary_mode_control"
            push!(ids, "rfp_active_control_luchetta_2009")
            push!(assumptions,
                "boundary coils suppress RWMs and wall locking but do not prescribe QSH")
            push!(actuators, "rfp_boundary_feedback")
        end
        return Any[_ctv4_mechanism("rfp_qsh_mechanism",
            "self_organized_relaxation", ["tearing", "resistive_wall_mode",
                "wall_locked_mode"], actuators, assumptions,
            ["resistive_mhd_rfp", "rfp_mode_spectrum",
                "rfp_current_profile_and_sustainment", "actuator_power"], ids)]
    end
    Any[
        _ctv4_mechanism("dipole_adiabatic_stability",
            "other", ["interchange", "ballooning"], String[],
            ["pressure profile remains below the p-times-flux-volume adiabatic limit",
             "levitation removes support-associated parallel loss"],
            ["finite_beta_dipole_equilibrium",
                "dipole_adiabatic_profile_stability"],
            ["dipole_ldx_design_garnier_2006"]),
        _ctv4_mechanism("dipole_inward_pinch",
            "other", ["cross_field_particle_loss"], String[],
            ["measured turbulent inward particle pinch does not imply an energy-confinement gain"],
            ["dipole_turbulent_transport"],
            ["dipole_inward_pinch_boxer_2010"])]
end

function _sov7_structural_base(parent::Genome,
        spec::SelfOrganizedTopologySpecV7)
    regions, connections, exhaust = _sov7_closed_exhaust_graph(spec.target_count)
    sources, actuators = Any[], Any[]
    if spec.family == "reversed_field_pinch"
        sources = Any[
            _ctv4_source("rfp_plasma_current",
                "self_organized_plasma_current",
                "reversed_toroidal_field_current_profile", "plasma"),
            _ctv4_source("rfp_conducting_shell", "conducting_shell",
                "close_fitting_segmented_shell", "conceptual copper shell"),
            _ctv4_source("rfp_low_field_coils", "toroidal_and_poloidal_field_coils",
                "finite_build_axisymmetric_low_field_coils",
                "conceptual copper or superconducting winding"),
            _ctv4_source("rfp_inductive_transformer", "inductive_transformer",
                "finite_flux_swing_transformer",
                "conceptual pulsed superconducting winding")]
        if spec.mechanism == "qsh_ppcd_boundary_mode_control"
            push!(sources, _ctv4_source("rfp_boundary_coils",
                "three_dimensional_boundary_mode_control_coil",
                "finite_harmonic_saddle_coil_array",
                "conceptual copper saddle coils"))
            push!(actuators, _ctv4_actuator("rfp_boundary_feedback",
                "magnetic_feedback_controller", 5e6))
        end
        if spec.mechanism in ("qsh_pulsed_poloidal_current_drive",
                "qsh_ppcd_boundary_mode_control")
            push!(actuators, _ctv4_actuator("rfp_ppcd",
                "pulsed_poloidal_current_drive", 20e6))
        end
    else
        sources = Any[
            _ctv4_source("dipole_internal_coil", "levitated_internal_dipole_coil",
                "finite_build_floating_superconducting_ring",
                "conceptual radiation-shielded superconductor"),
            _ctv4_source("dipole_levitation_coil", "external_levitation_coil",
                "axisymmetric_feedback_levitation_coil",
                "conceptual superconducting winding"),
            _ctv4_source("dipole_charging_coil", "external_inductive_charging_coil",
                "axisymmetric_inductive_charging_coil",
                "conceptual superconducting winding")]
        push!(actuators, _ctv4_actuator("dipole_drift_exhaust",
            "low_frequency_drift_pump", 2e6))
    end
    raw = Dict{String,Any}(
        "schema_version" => "0.1.0",
        "design_id" => "pending_self_organized_v7",
        "label" => "Self-organized v7 $(_sov7_key(spec))",
        "mission" => Dict{String,Any}(
            "kind" => "science_gain_demo", "fuel" => "D-T",
            "operating_mode" => spec.family == "reversed_field_pinch" ?
                "pulsed" : "steady_state",
            "targets" => Dict{String,Any}()),
        "family" => spec.family,
        "topology" => Dict{String,Any}(
            "field_line_class" => spec.family == "reversed_field_pinch" ?
                "closed_toroidal_separatrix" : "closed_toroidal_nested",
            "rotation_transform_sources" => spec.family == "reversed_field_pinch" ?
                ["plasma_current"] : ["levitated_internal_dipole_coil"],
            "expected_flux_surfaces" => true,
            "expected_separatrix" => true),
        "symmetry" => Dict{String,Any}(
            "class" => spec.family == "reversed_field_pinch" ? "none" : "axisymmetric",
            "field_periods" => 1,
            "hard_constraints" => spec.family == "reversed_field_pinch" ?
                ["single dominant helical axis may break axisymmetry",
                 "finite close-fitting shell"] :
                ["axisymmetric levitated internal coil",
                 "no mechanical supports crossing confined field"]),
        "plasma_regions" => regions, "field_sources" => sources,
        "actuators" => actuators,
        "stability_mechanisms" => _sov7_stability(spec),
        "flux_connections" => connections, "exhaust" => exhaust,
        "engineering" => Dict{String,Any}(
            "magnet_technology" => [String(s["material"]) for s in sources],
            "blanket" => Dict("required" => true,
                "concept" => "same-envelope D-T screening placeholder",
                "target_tbr" => _ctv4_quantity(1.05, "1")),
            "maintenance" => Dict(
                "architecture" => spec.family == "reversed_field_pinch" ?
                    "segmented shell and replaceable targets" :
                    "recoverable levitated ring through vertical hot cell",
                "access_paths" => spec.family == "reversed_field_pinch" ?
                    ["segmented shell module", "replaceable target cassette"] :
                    ["vertical internal-coil retrieval path",
                     "levitated coil hot-cell transfer"]),
            "required_evaluators" => ["finite_build_coils", "coil_stress",
                "shielding", "maintenance_access", "neutronics"]),
        "provenance" => Dict{String,Any}(
            "origin" => "generated",
            "source_ids" => spec.family == "reversed_field_pinch" ?
                ["rfp_reactor_1981", "rfp_tperx_sago_1999",
                 "rfp_ppcd_sarff_1997"] :
                ["levitated_dipole_hasegawa_1990",
                 "dipole_ldx_design_garnier_2006",
                 "dipole_inward_pinch_boxer_2010"],
            "parent_design_ids" => [parent.design_id],
            "claim_level" => "structural_example",
            "notes" => ["self_organized_qd_v7",
                "same outer envelope; fidelity-0 rejection only"]))
    provisional = parse_genome(raw)
    report = validate_genome(provisional)
    report.valid || error(join(report.errors, "; "))
    family = validate_family(default_family_registry(), provisional)
    family.valid || error(join(family.errors, "; "))
    raw["design_id"] = "structure_$(provisional.physics_hash[1:20])"
    parse_genome(raw)
end

function _sov7_ranges(spec::SelfOrganizedTopologySpecV7, u)
    rfp = spec.family == "reversed_field_pinch"
    Dict{String,Float64}(
        "screen_aspect_ratio" => rfp ? 2.0 + 3.0u[1] : 2.0 + 2.5u[1],
        "screen_plasma_fill_fraction" => 0.35 + 0.55u[2],
        "screen_beta" => rfp ? 0.04 + 0.20u[3] : 0.10 + 0.80u[3],
        "screen_temperature" => 8.0 + 22.0u[4],
        "screen_field_quality" => 0.82 + 0.18u[5],
        "plasma_current" => rfp ? 1.0e6 * 15.0^u[6] : 0.05e6,
        "screen_reversal_parameter" => -0.35 + 0.33u[7],
        "screen_pinch_parameter" => 1.35 + 0.60u[8],
        "screen_mode_dominance_ratio" => 0.50 + 5.50u[9],
        "screen_current_profile_control" =>
            spec.mechanism in ("qsh_pulsed_poloidal_current_drive",
                "qsh_ppcd_boundary_mode_control") ? u[10] : 0.0,
        "screen_boundary_feedback_strength" =>
            spec.mechanism == "qsh_ppcd_boundary_mode_control" ?
                0.10 + 0.90u[11] : 0.0,
        "screen_ppcd_power" =>
            spec.mechanism in ("qsh_pulsed_poloidal_current_drive",
                "qsh_ppcd_boundary_mode_control") ?
                2.0e6 * 50.0^u[12] : 0.0,
        "screen_boundary_control_power" =>
            spec.mechanism == "qsh_ppcd_boundary_mode_control" ?
                0.5e6 * 40.0^u[12] : 0.0,
        "screen_declared_actuator_power" =>
            spec.family == "levitated_dipole" ? 2e6 : 0.0,
        "screen_pulse_duty_fraction" => rfp ? 0.25 + 0.65u[13] : 1.0,
        "screen_inward_pinch_strength" => rfp ? 0.0 : u[11],
        "screen_levitation_quality" => rfp ? 0.0 : 0.90 + 0.10u[12],
        "screen_pressure_profile_exponent" => rfp ? 0.0 : 2.0 + 6.0u[13],
        "screen_internal_coil_radius_fraction" => rfp ? 0.0 : 0.10 + 0.30u[14],
        "screen_internal_coil_field_ratio" => rfp ? 0.0 : 2.0 + 5.0u[15],
        "screen_internal_shield_thickness" => rfp ? 0.0 : 0.30 + 1.20u[16],
        "screen_internal_maintenance_gap" => rfp ? 0.0 : 0.20 + 0.60u[17],
        "screen_coil_pack_thickness" => 0.25 + 0.75u[18],
        "screen_support_thickness" => 0.35 + 1.10u[19],
        "screen_exhaust_area_fraction" => 0.08 + 0.42u[20],
        "screen_exhaust_flux_expansion" => 1.0 + 5.0u[21])
end

function _sov7_acquisition_features(spec::SelfOrganizedTopologySpecV7, values)
    rfp = spec.family == "reversed_field_pinch"
    (
        family = spec.family,
        aspect_ratio = values["screen_aspect_ratio"],
        plasma_fill_fraction = values["screen_plasma_fill_fraction"],
        beta = values["screen_beta"],
        temperature_keV = values["screen_temperature"],
        field_quality = values["screen_field_quality"],
        plasma_current_MA = values["plasma_current"] / 1e6,
        reversal_parameter = values["screen_reversal_parameter"],
        pinch_parameter = values["screen_pinch_parameter"],
        mode_dominance = values["screen_mode_dominance_ratio"],
        current_profile_control = values["screen_current_profile_control"],
        boundary_feedback_strength =
            values["screen_boundary_feedback_strength"],
        ppcd_power_W = values["screen_ppcd_power"],
        boundary_control_power_W =
            values["screen_boundary_control_power"],
        dipole_actuator_power_W =
            values["screen_declared_actuator_power"],
        pulse_duty_fraction = values["screen_pulse_duty_fraction"],
        inward_pinch_strength = values["screen_inward_pinch_strength"],
        levitation_quality = values["screen_levitation_quality"],
        pressure_profile_exponent =
            values["screen_pressure_profile_exponent"],
        internal_coil_radius_fraction =
            values["screen_internal_coil_radius_fraction"],
        internal_coil_field_ratio =
            values["screen_internal_coil_field_ratio"],
        internal_shield_thickness_m =
            values["screen_internal_shield_thickness"],
        internal_maintenance_gap_m =
            values["screen_internal_maintenance_gap"],
        coil_pack_thickness_m = values["screen_coil_pack_thickness"],
        support_thickness_m = values["screen_support_thickness"],
        exhaust_area_fraction = values["screen_exhaust_area_fraction"],
        exhaust_flux_expansion = values["screen_exhaust_flux_expansion"],
        target_count = spec.target_count,
    )
end

function _sov7_set_targets!(raw, values, c)
    fixed = (
        ("screen_outer_radial_extent", c.outer_radial_extent_m, "m"),
        ("screen_outer_axial_half_extent", c.outer_axial_half_extent_m, "m"),
        ("screen_plasma_field", c.plasma_field_T, "T"),
        ("on_axis_field", c.plasma_field_T, "T"))
    for (name, value, unit) in fixed
        _ctv4_set_target!(raw, name, value, unit;
            basis = "shared outer-envelope v7 contract")
    end
    units = Dict(
        "screen_aspect_ratio" => "1", "screen_plasma_fill_fraction" => "1",
        "screen_beta" => "1", "screen_temperature" => "keV",
        "screen_field_quality" => "1", "plasma_current" => "A",
        "screen_reversal_parameter" => "1", "screen_pinch_parameter" => "1",
        "screen_mode_dominance_ratio" => "1",
        "screen_current_profile_control" => "1",
        "screen_boundary_feedback_strength" => "1",
        "screen_declared_actuator_power" => "W",
        "screen_ppcd_power" => "W",
        "screen_boundary_control_power" => "W",
        "screen_pulse_duty_fraction" => "1",
        "screen_inward_pinch_strength" => "1",
        "screen_levitation_quality" => "1",
        "screen_pressure_profile_exponent" => "1",
        "screen_internal_coil_radius_fraction" => "1",
        "screen_internal_coil_field_ratio" => "1",
        "screen_internal_shield_thickness" => "m",
        "screen_internal_maintenance_gap" => "m",
        "screen_coil_pack_thickness" => "m",
        "screen_support_thickness" => "m",
        "screen_exhaust_area_fraction" => "1",
        "screen_exhaust_flux_expansion" => "1")
    for (name, unit) in units
        _ctv4_set_target!(raw, name, values[name], unit;
            basis = "self-organized QD v7 gene")
    end
    raw
end

function _sov7_instantiate(base::Genome, values, c)
    raw = deepcopy(base.normalized)
    _sov7_set_targets!(raw, values, c)
    f = _so_features(parse_genome(raw))
    geo = _so_geometry(f, c)
    core = only(filter(r -> r["id"] == "so_core", raw["plasma_regions"]))
    core["parameters"] = Dict(
        "major_radius" => _ctv4_quantity(geo.R, "m"),
        "minor_radius" => _ctv4_quantity(geo.a, "m"),
        "half_height" => _ctv4_quantity(geo.z, "m"),
        "elongation" => _ctv4_quantity(geo.kappa, "1"))
    for source in raw["field_sources"]
        if source["kind"] == "self_organized_plasma_current"
            source["parameters"]["total_current"] =
                _ctv4_quantity(values["plasma_current"], "A")
        elseif source["kind"] == "levitated_internal_dipole_coil"
            source["parameters"]["coil_radius"] =
                _ctv4_quantity(values["screen_internal_coil_radius_fraction"] *
                    geo.a, "m")
            source["parameters"]["peak_field"] =
                _ctv4_quantity(c.plasma_field_T *
                    values["screen_internal_coil_field_ratio"], "T")
        end
    end
    for actuator in raw["actuators"]
        if actuator["id"] == "rfp_boundary_feedback"
            actuator["parameters"]["power"] = _ctv4_quantity(
                values["screen_boundary_control_power"], "W")
        elseif actuator["id"] == "rfp_ppcd"
            actuator["parameters"]["power"] =
                _ctv4_quantity(values["screen_ppcd_power"], "W")
        elseif actuator["id"] == "dipole_drift_exhaust"
            actuator["parameters"]["power"] =
                _ctv4_quantity(values["screen_declared_actuator_power"], "W")
        end
    end
    raw["design_id"] = "pending_self_organized_v7"
    p = parse_genome(raw)
    raw["design_id"] = "concept_$(p.physics_hash[1:20])"
    candidate = parse_genome(raw)
    validate_genome(candidate).valid || error("invalid v7 candidate")
    candidate
end

function _sov7_descriptor(c, spec, f)
    beta_bin = clamp(floor(Int, 5f.beta), 0, 4)
    field_bin = clamp(floor(Int, 4(f.field_quality - 0.80) / 0.20), 0, 3)
    fill_bin = clamp(floor(Int, 4(f.plasma_fill_fraction - 0.30) / 0.65), 0, 3)
    "$(c.id)|$(_sov7_key(spec))|beta=$beta_bin|field=$field_bin|fill=$fill_bin"
end

function _sov7_quality(record)
    n = record["nominal"]
    margins = Float64.(collect(values(n["margins"])))
    (count(x -> x < 0.0, margins),
        sum(log1p(-min(0.0, x)) for x in margins),
        -Float64(n["net_electric_power_W"]),
        canonical_hash(record["features"]))
end

function run_self_organized_qd_v7(seeds::Vector{Genome};
        acquisition_samples::Int = 300_000, random_seed::Int = 20260812,
        maximum_graph_elites::Int = 216,
        elites_per_structural_stratum::Int = 3,
        contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    acquisition_samples >= 0 || throw(ArgumentError("negative sample count"))
    parent = only(filter(g -> g.family == "tokamak_axisymmetric", seeds))
    specs = _sov7_specs()
    structural = Dict(_sov7_key(s) => _sov7_structural_base(parent, s)
        for s in specs)
    strata = [(c, s) for c in contracts for s in specs]
    primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37,
        41, 43, 47, 53, 59, 61, 67, 71, 73)
    archive = Dict{String,Dict{String,Any}}()
    positive_net, nominal_pass = 0, 0
    for index in 1:acquisition_samples
        c, spec = strata[mod1(index, length(strata))]
        u = ntuple(axis -> _ctv4_halton(index, primes[axis]), length(primes))
        values = _sov7_ranges(spec, u)
        base = structural[_sov7_key(spec)]
        f = _sov7_acquisition_features(spec, values)
        nominal = _so_nominal(base, c, f)
        nominal["net_electric_power_W"] > 0 && (positive_net += 1)
        nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true &&
            (nominal_pass += 1)
        proposal = Dict{String,Any}(
            "descriptor" => _sov7_descriptor(c, spec, f),
            "stratum" => "$(c.id)|$(_sov7_key(spec))",
            "contract_id" => c.id, "spec_key" => _sov7_key(spec),
            "features" => values, "nominal" => nominal)
        incumbent = get(archive, proposal["descriptor"], nothing)
        if incumbent === nothing ||
                _sov7_quality(proposal) < _sov7_quality(incumbent)
            archive[proposal["descriptor"]] = proposal
        end
    end
    by_stratum = Dict{String,Vector{Dict{String,Any}}}()
    for p in values(archive)
        push!(get!(by_stratum, p["stratum"], Dict{String,Any}[]), p)
    end
    acquisitions = Dict{String,Any}[]
    for stratum in sort!(collect(keys(by_stratum)))
        items = by_stratum[stratum]
        sort!(items; by = _sov7_quality)
        append!(acquisitions, first(items,
            min(elites_per_structural_stratum, length(items))))
    end
    sort!(acquisitions; by = p -> (p["stratum"], _sov7_quality(p)))
    length(acquisitions) > maximum_graph_elites &&
        (acquisitions = first(acquisitions, maximum_graph_elites))
    contract_by_id = Dict(c.id => c for c in contracts)
    spec_by_key = Dict(_sov7_key(s) => s for s in specs)
    records = Dict{String,Any}[]
    for a in acquisitions
        c = contract_by_id[a["contract_id"]]
        spec = spec_by_key[a["spec_key"]]
        candidate = _sov7_instantiate(structural[a["spec_key"]],
            a["features"], c)
        result = _self_organized_result(
            SelfOrganizedScreenV1(c; allowed_contracts = contracts), candidate)
        push!(records, Dict{String,Any}(
            "contract_id" => c.id, "design_id" => candidate.design_id,
            "physics_hash" => candidate.physics_hash, "family" => spec.family,
            "mechanism" => spec.mechanism, "target_count" => spec.target_count,
            "descriptor" => a["descriptor"], "genome" => candidate.normalized,
            "acquisition" => a, "evaluation" => result,
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "positive_net_power_closure_passed" =>
                result["positive_net_power_closure_passed"],
            "promoted" => result["all_five_gates_passed"] === true &&
                result["positive_net_power_closure_passed"] === true))
    end
    sort!(records; by = r -> (
        r["promoted"] === true ? 0 : 1,
        _sov7_quality(Dict("nominal" => r["evaluation"]["nominal"],
            "features" => r["acquisition"]["features"])),
        r["physics_hash"]))
    Dict{String,Any}(
        "algorithm" => "21D Halton acquisition plus mechanism-stratified failure-aware MAP-Elites",
        "random_seed" => random_seed,
        "acquisition_samples" => acquisition_samples,
        "contract_count" => length(contracts),
        "contracts" => [_oe_contract_dict(c) for c in contracts],
        "topology_count_per_contract" => length(specs),
        "structural_stratum_count" => length(strata),
        "topologies" => [Dict("family" => s.family,
            "mechanism" => s.mechanism, "target_count" => s.target_count)
            for s in specs],
        "acquisition_archive_cell_count" => length(archive),
        "acquisition_positive_net_count" => positive_net,
        "acquisition_nominal_physics_and_engineering_pass_count" => nominal_pass,
        "explicit_graph_elite_count" => length(records),
        "explicit_graph_five_gate_pass_count" =>
            count(r -> r["all_five_gates_passed"] === true, records),
        "explicit_graph_positive_net_count" =>
            count(r -> r["positive_net_power_closure_passed"] === true, records),
        "promotion_count" => count(r -> r["promoted"] === true, records),
        "records" => records,
        "claim_boundary" => _SELF_ORGANIZED_SCREEN_CLAIM_BOUNDARY)
end
