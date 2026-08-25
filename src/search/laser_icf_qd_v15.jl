struct LaserICFTopologySpecV15
    drive_path::String
    chamber_protection::String
    anchor_only::Bool
    promotion_eligible::Bool

    function LaserICFTopologySpecV15(drive_path::AbstractString,
            chamber_protection::AbstractString;
            anchor_only::Bool = false, promotion_eligible::Bool = true)
        path = String(drive_path)
        protection = String(chamber_protection)
        path in ("laser_indirect_drive", "laser_direct_drive",
            "laser_fast_ignition") || throw(ArgumentError(
            "unsupported laser ICF drive path"))
        protection in ("dry_wall", "liquid_protected",
            "replaceable_modular", "single_shot_experiment") ||
            throw(ArgumentError("unsupported laser ICF chamber protection"))
        anchor_only && promotion_eligible && throw(ArgumentError(
            "science anchors cannot be promotion eligible"))
        return new(path, protection, anchor_only, promotion_eligible)
    end
end

function _licfv15_topology_specs()
    specs = LaserICFTopologySpecV15[
        LaserICFTopologySpecV15("laser_indirect_drive",
            "single_shot_experiment"; anchor_only = true,
            promotion_eligible = false)]
    for path in ("laser_indirect_drive", "laser_direct_drive",
            "laser_fast_ignition"), protection in
            ("dry_wall", "liquid_protected", "replaceable_modular")
        push!(specs, LaserICFTopologySpecV15(path, protection))
    end
    return specs
end

_licfv15_key(spec::LaserICFTopologySpecV15) =
    "$(spec.drive_path)|$(spec.chamber_protection)|$(spec.anchor_only ? "anchor" : "plant")"

_licfv15_q(value, unit; basis = "laser ICF QD v15 searched hypothesis") =
    Dict{String,Any}("value" => value, "unit" => unit, "basis" => basis)

function _licfv15_source_ids(spec::LaserICFTopologySpecV15)
    ids = String["ife_assessment_nas_2013"]
    if spec.anchor_only
        append!(ids, ["nif_target_gain_unity_2024",
            "nif_burning_plasma_2022"])
    elseif spec.drive_path == "laser_indirect_drive"
        push!(ids, "nif_indirect_drive_basis_lindl_2004")
    elseif spec.drive_path == "laser_direct_drive"
        push!(ids, "direct_drive_review_campbell_2015")
    else
        push!(ids, "fast_ignition_tabak_1994")
    end
    return sort!(unique(ids))
end

function _licfv15_ranges(spec::LaserICFTopologySpecV15, u)
    if spec.anchor_only
        return Dict{String,Float64}(
            "on_target_energy_J" => 1.0,
            "target_gain_assumption" => 1.0,
            "driver_wall_plug_efficiency" => 1.0,
            "repetition_rate_Hz" => 1.0,
            "availability" => 1.0,
            "dt_fuel_mass_kg" => 1.0,
            "burn_fraction_assumption" => 1.0,
            "target_factory_energy_J" => 0.0,
            "target_injection_speed_m_s" => 1.0,
            "chamber_clearing_speed_m_s" => 1.0,
            "neutron_energy_fraction" => 0.80,
            "path_coupling_assumption" => 1.0,
            "fast_ignitor_energy_fraction" => 0.0,
            "illumination_quality_assumption" => 1.0,
            "port_area_fraction" => 0.0,
            "target_factory_yield_assumption" => 1.0,
            "driver_lifetime_shots_assumption" => 1.0,
            "first_wall_lifetime_shots_assumption" => 1.0)
    end
    coupling_lo, coupling_hi = spec.drive_path == "laser_indirect_drive" ?
        (0.01, 0.35) : spec.drive_path == "laser_direct_drive" ?
        (0.03, 0.80) : (0.01, 0.50)
    return Dict{String,Float64}(
        "on_target_energy_J" => 3.0e5 * (33.3333333333 ^ u[1]),
        "target_gain_assumption" => 1.0 * (500.0 ^ u[2]),
        "driver_wall_plug_efficiency" => 0.003 * (100.0 ^ u[3]),
        "repetition_rate_Hz" => 0.05 * (600.0 ^ u[4]),
        "availability" => 0.10 + 0.85 * u[5],
        "dt_fuel_mass_kg" => 1.0e-7 * (1000.0 ^ u[6]),
        "burn_fraction_assumption" => 0.005 * (120.0 ^ u[7]),
        "target_factory_energy_J" => 1.0e4 * (1.0e4 ^ u[8]),
        "target_injection_speed_m_s" => 20.0 * (50.0 ^ u[9]),
        "chamber_clearing_speed_m_s" => 100.0 * (200.0 ^ u[10]),
        "neutron_energy_fraction" => 0.70 + 0.20 * u[11],
        "path_coupling_assumption" => coupling_lo *
            ((coupling_hi / coupling_lo) ^ u[12]),
        "fast_ignitor_energy_fraction" => spec.drive_path ==
            "laser_fast_ignition" ? 0.01 + 0.69 * u[13] : 0.0,
        "illumination_quality_assumption" => 0.60 + 0.40 * u[14],
        "port_area_fraction" => 0.01 + 0.29 * u[15],
        "target_factory_yield_assumption" => 0.50 + 0.50 * u[16],
        "driver_lifetime_shots_assumption" => 1.0e4 * (1.0e6 ^ u[17]),
        "first_wall_lifetime_shots_assumption" => 1.0e4 * (1.0e6 ^ u[18]))
end

function _licfv15_build_genome(parent::Genome, spec::LaserICFTopologySpecV15,
        values::AbstractDict, contract::LaserICFPulsedContractV1)
    ids = _licfv15_source_ids(spec)
    anchor = spec.anchor_only
    driver_ids = spec.drive_path == "laser_fast_ignition" ?
        Any["compression_laser_driver", "fast_ignitor_driver"] :
        Any["compression_laser_driver"]
    field_sources = Any[
        Dict{String,Any}("id" => "compression_beam_array",
            "kind" => "laser_beam_array",
            "geometry_model" => "multi_beam_final_optics_graph_v15",
            "parameters" => Dict{String,Any}(
                "port_area_fraction" => _licfv15_q(
                    values["port_area_fraction"], "1")),
            "material" => "searched_repeat_rate_laser_and_final_optics")]
    spec.drive_path == "laser_indirect_drive" && push!(field_sources,
        Dict{String,Any}("id" => "hohlraum_xray_enclosure",
            "kind" => "hohlraum_xray_enclosure",
            "geometry_model" => "indirect_drive_hohlraum_v15",
            "parameters" => Dict{String,Any}(
                "path_coupling_assumption" => _licfv15_q(
                    values["path_coupling_assumption"], "1")),
            "material" => "searched_hohlraum_hypothesis"))
    spec.drive_path == "laser_fast_ignition" && push!(field_sources,
        Dict{String,Any}("id" => "fast_ignitor_beam_path",
            "kind" => "fast_ignitor_beam",
            "geometry_model" => "separate_fast_ignitor_path_v15",
            "parameters" => Dict{String,Any}(
                "energy_fraction" => _licfv15_q(
                    values["fast_ignitor_energy_fraction"], "1")),
            "material" => "searched_fast_ignitor_transport_hypothesis"))
    actuators = Any[
        Dict{String,Any}("id" => "compression_laser_driver",
            "kind" => "other", "parameters" => Dict{String,Any}(
                "wall_plug_efficiency" => _licfv15_q(
                    values["driver_wall_plug_efficiency"], "1"),
                "on_target_energy" => _licfv15_q(
                    values["on_target_energy_J"], "J")))]
    spec.drive_path == "laser_fast_ignition" && push!(actuators,
        Dict{String,Any}("id" => "fast_ignitor_driver", "kind" => "other",
            "parameters" => Dict{String,Any}(
                "energy_fraction" => _licfv15_q(
                    values["fast_ignitor_energy_fraction"], "1"))))
    raw = Dict{String,Any}(
        "schema_version" => "0.1.0",
        "design_id" => "pending_laser_icf_v15",
        "label" => "Laser ICF v15 $(_licfv15_key(spec))",
        "mission" => Dict{String,Any}(
            "kind" => anchor ? "single_shot_target_gain_science" :
                "net_electric_pilot",
            "fuel" => "D-T", "operating_mode" => "pulsed",
            "targets" => Dict{String,Any}(
                "screen_chamber_radius" => _licfv15_q(
                    contract.chamber_radius_m, "m";
                    basis = "declared same-envelope ICF screening contract"),
                "screen_chamber_half_height" => _licfv15_q(
                    contract.chamber_half_height_m, "m";
                    basis = "declared same-envelope ICF screening contract"))),
        "family" => "inertial_confinement_fusion",
        "topology" => Dict{String,Any}(
            "field_line_class" => "not_applicable_inertial",
            "rotation_transform_sources" => Any["not_applicable"],
            "expected_flux_surfaces" => false,
            "expected_separatrix" => false),
        "symmetry" => Dict{String,Any}(
            "class" => spec.drive_path == "laser_fast_ignition" ? "none" :
                "axisymmetric", "field_periods" => 1,
            "hard_constraints" => Any[
                "target gain is distinct from wall-plug and net-electric gain",
                "driver target chamber and factory are explicit subsystems"]),
        "plasma_regions" => Any[
            Dict{String,Any}("id" => "fuel_capsule",
                "kind" => "formation_or_compression_region",
                "geometry_model" => "spherical_dt_capsule_v15",
                "parameters" => Dict{String,Any}(
                    "dt_fuel_mass" => _licfv15_q(
                        values["dt_fuel_mass_kg"], "kg"))),
            Dict{String,Any}("id" => "ignition_hotspot",
                "kind" => "formation_or_compression_region",
                "geometry_model" => "compressed_hotspot_and_shell_v15",
                "parameters" => Dict{String,Any}()),
            Dict{String,Any}("id" => "pulsed_chamber_region",
                "kind" => "divertor_or_exhaust_region",
                "geometry_model" => "$(spec.chamber_protection)_laser_icf_chamber_v15",
                "parameters" => Dict{String,Any}(
                    "radius" => _licfv15_q(contract.chamber_radius_m, "m"),
                    "half_height" => _licfv15_q(
                        contract.chamber_half_height_m, "m")))],
        "field_sources" => field_sources,
        "actuators" => actuators,
        "compression_systems" => Any[
            Dict{String,Any}("id" => "primary_laser_drive_system",
                "kind" => spec.drive_path,
                "geometry_model" => "$(spec.drive_path)_capsule_path_v15",
                "driver_actuator_ids" => driver_ids,
                "target_region_ids" => Any["fuel_capsule", "ignition_hotspot"],
                "parameters" => Dict{String,Any}(
                    "anchor_only" => _licfv15_q(anchor ? 1.0 : 0.0, "1"),
                    "on_target_energy" => _licfv15_q(
                        values["on_target_energy_J"], "J"),
                    "target_gain_assumption" => _licfv15_q(
                        values["target_gain_assumption"], "1"),
                    "driver_wall_plug_efficiency" => _licfv15_q(
                        values["driver_wall_plug_efficiency"], "1"),
                    "repetition_rate" => _licfv15_q(
                        values["repetition_rate_Hz"], "Hz"),
                    "availability" => _licfv15_q(values["availability"], "1"),
                    "dt_fuel_mass" => _licfv15_q(
                        values["dt_fuel_mass_kg"], "kg"),
                    "burn_fraction_assumption" => _licfv15_q(
                        values["burn_fraction_assumption"], "1"),
                    "target_factory_energy_per_shot" => _licfv15_q(
                        values["target_factory_energy_J"], "J"),
                    "target_injection_speed" => _licfv15_q(
                        values["target_injection_speed_m_s"], "m/s"),
                    "chamber_clearing_speed" => _licfv15_q(
                        values["chamber_clearing_speed_m_s"], "m/s"),
                    "neutron_energy_fraction" => _licfv15_q(
                        values["neutron_energy_fraction"], "1"),
                    "path_coupling_assumption" => _licfv15_q(
                        values["path_coupling_assumption"], "1"),
                    "fast_ignitor_energy_fraction" => _licfv15_q(
                        values["fast_ignitor_energy_fraction"], "1"),
                    "illumination_quality_assumption" => _licfv15_q(
                        values["illumination_quality_assumption"], "1"),
                    "port_area_fraction" => _licfv15_q(
                        values["port_area_fraction"], "1"),
                    "target_factory_yield_assumption" => _licfv15_q(
                        values["target_factory_yield_assumption"], "1"),
                    "driver_lifetime_shots_assumption" => _licfv15_q(
                        values["driver_lifetime_shots_assumption"], "1"),
                    "first_wall_lifetime_shots_assumption" => _licfv15_q(
                        values["first_wall_lifetime_shots_assumption"], "1")),
                "material" => anchor ? "reported_experiment_topology_anchor" :
                    "searched_target_and_driver_hypothesis",
                "source_ids" => Any[ids...])],
        "stability_mechanisms" => Any[
            Dict{String,Any}("id" => "implosion_symmetry_and_mix_control",
                "mechanism" => "other",
                "target_modes" => Any["implosion_asymmetry", "mix",
                    "laser_plasma_instability"],
                "actuator_ids" => Any[driver_ids...],
                "assumptions" => Any[
                    anchor ? "bounded reported experiment" :
                        "searched target gain is not validated",
                    "no scalar multiplier substitutes for radiation hydrodynamics"],
                "required_evaluators" => Any[
                    "icf_radiation_hydrodynamics",
                    "laser_plasma_interaction",
                    spec.drive_path == "laser_fast_ignition" ?
                        "fast_ignition_transport" : "icf_radiation_hydrodynamics"],
                "source_ids" => Any[ids...])],
        "flux_connections" => Any[
            Dict{String,Any}("from_region_id" => "fuel_capsule",
                "to_region_id" => "ignition_hotspot",
                "kind" => "compression_transfer"),
            Dict{String,Any}("from_region_id" => "ignition_hotspot",
                "to_region_id" => "pulsed_chamber_region", "kind" => "other")],
        "exhaust" => Dict{String,Any}(
            "kind" => "pulsed_chamber",
            "region_ids" => Any["pulsed_chamber_region"],
            "evaluation_requirements" => Any[spec.chamber_protection,
                "pulsed_chamber_clearing", "first_wall_lifetime"]),
        "engineering" => Dict{String,Any}(
            "magnet_technology" => Any["not_applicable_laser_driver"],
            "blanket" => anchor ? Dict{String,Any}(
                "required" => false, "concept" => nothing) :
                Dict{String,Any}(
                    "required" => true,
                    "concept" =>
                        "searched_$(spec.chamber_protection)_breeding_blanket",
                    "target_tbr" => _licfv15_q(1.10, "1";
                        basis = "declared screening target, not demonstrated TBR")),
            "maintenance" => Dict{String,Any}(
                "architecture" => anchor ? "single_shot_experiment" :
                    "remote_maintained_$(spec.chamber_protection)_chamber",
                "access_paths" => Any["laser_ports", "target_injector",
                    "blanket_modules"]),
            "required_evaluators" => Any["repeat_rate_laser_driver",
                "target_factory_and_injection", "pulsed_chamber_clearing",
                "first_wall_lifetime"]),
        "provenance" => Dict{String,Any}(
            "origin" => anchor ? "known_device_seed" : "generated",
            "source_ids" => Any[ids...],
            "parent_design_ids" => Any[parent.design_id],
            "claim_level" => "structural_example",
            "notes" => Any["grammar_rule:laser_icf_qd_v15",
                anchor ? "single-shot target-gain anchor; never promotable" :
                    "all numerical performance values are searched hypotheses"])
    )
    provisional = parse_genome(raw)
    raw["design_id"] = "concept_$(provisional.physics_hash[1:20])"
    candidate = parse_genome(raw)
    errors = _licfv15_semantic_errors(candidate)
    isempty(errors) || error(join(errors, "; "))
    return candidate
end

function _licfv15_bin(value::Float64, cuts::Tuple, labels::Tuple)
    for (cut, label) in zip(cuts, labels)
        value <= cut && return label
    end
    return last(labels)
end

function _licfv15_descriptor(contract::LaserICFPulsedContractV1,
        spec::LaserICFTopologySpecV15, f::AbstractDict)
    spec.anchor_only && return join((contract.id, spec.drive_path,
        spec.chamber_protection, "reported_anchor"), "|")
    repetition = _licfv15_bin(Float64(f["repetition_rate_Hz"]),
        (0.5, 5.0, Inf), ("rep_low", "rep_mid", "rep_high"))
    gain = _licfv15_bin(Float64(f["target_gain_assumption"]),
        (10.0, 100.0, Inf), ("gain_low", "gain_mid", "gain_high"))
    yield = _licfv15_bin(Float64(f["on_target_energy_J"] *
        f["target_gain_assumption"]), (1.0e8, 1.0e9, Inf),
        ("yield_low", "yield_mid", "yield_high"))
    return join((contract.id, spec.drive_path, spec.chamber_protection,
        repetition, gain, yield), "|")
end

function _licfv15_quality(record::AbstractDict)
    nominal = record["nominal"]
    margins = nominal["margins"]
    evidence = Set(["target_gain_experimental_validation",
        "driver_wall_plug_and_repeat_rate_validation",
        "target_factory_throughput_and_yield_validation",
        "first_wall_and_final_optics_lifetime_validation"])
    conditional = Float64[value for (id, value) in margins if !(id in evidence)]
    failed = count(value -> value < 0.0, conditional)
    violation = sum(log1p(-min(0.0, value)) for value in conditional)
    conditional_pass = nominal["conditional_physics_gate_passed"] === true &&
        nominal["conditional_engineering_gate_passed"] === true
    return (conditional_pass ? 0 : 1,
        nominal["average_net_electric_power_W"] > 0.0 ? 0 : 1,
        failed, violation, -Float64(nominal["average_net_electric_power_W"]),
        canonical_hash(record["features"]))
end

function run_laser_icf_qd_v15(seeds::Vector{Genome};
        acquisition_samples::Int = 300_000,
        maximum_graph_elites::Int = 90,
        elites_per_structural_stratum::Int = 2,
        contracts::Vector{LaserICFPulsedContractV1} =
            laser_icf_pulsed_contracts_v1())
    acquisition_samples >= 0 || throw(ArgumentError(
        "acquisition_samples must be non-negative"))
    maximum_graph_elites > 0 || throw(ArgumentError(
        "maximum_graph_elites must be positive"))
    elites_per_structural_stratum > 0 || throw(ArgumentError(
        "elites_per_structural_stratum must be positive"))
    parent = only(filter(genome -> genome.family == "tokamak_axisymmetric",
        seeds))
    specs = _licfv15_topology_specs()
    strata = [(contract, spec) for contract in contracts for spec in specs]
    candidate_strata = [(contract, spec) for (contract, spec) in strata
        if !spec.anchor_only]
    sort!(candidate_strata; by = item -> (item[1].id,
        item[2].chamber_protection, item[2].drive_path))
    anchor_strata = [(contract, spec) for (contract, spec) in strata
        if spec.anchor_only]
    primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47,
        53, 59, 61)
    archive = Dict{String,Dict{String,Any}}()
    positive_net_count = 0
    conditional_pass_count = 0
    path_sample_count = Dict(path => 0 for path in
        sort!(unique(spec.drive_path for spec in specs)))
    protection_sample_count = Dict(protection => 0 for protection in
        sort!(unique(spec.chamber_protection for spec in specs)))
    # Anchors are fixed evidence records, not searchable hypotheses. Evaluate
    # each once and reserve the entire declared acquisition budget for plants.
    for (contract, spec) in anchor_strata
        f = _licfv15_ranges(spec, ntuple(_ -> 0.5, length(primes)))
        nominal = _licfv15_science_anchor_nominal()
        descriptor = _licfv15_descriptor(contract, spec, f)
        archive[descriptor] = Dict{String,Any}(
            "descriptor" => descriptor,
            "structural_stratum" => "$(contract.id)|$(_licfv15_key(spec))",
            "contract_id" => contract.id, "drive_path" => spec.drive_path,
            "chamber_protection" => spec.chamber_protection,
            "anchor_only" => true, "promotion_eligible" => false,
            "features" => f, "nominal" => nominal)
    end
    for index in 1:acquisition_samples
        stratum_index = mod1(index, length(candidate_strata))
        contract, spec = candidate_strata[stratum_index]
        local_index = fld(index - 1, length(candidate_strata)) + 1
        # Common low-discrepancy coordinates make drive/chamber comparisons
        # paired and avoid correlations between a Halton base and stratum cycle.
        u = ntuple(axis -> _ctv4_halton(local_index, primes[axis]),
            length(primes))
        f = _licfv15_ranges(spec, u)
        nominal = spec.anchor_only ? _licfv15_science_anchor_nominal() :
            _licfv15_candidate_nominal(spec.drive_path,
                spec.chamber_protection, contract, f)
        nominal["average_net_electric_power_W"] > 0.0 &&
            (positive_net_count += 1)
        nominal["conditional_physics_gate_passed"] === true &&
            nominal["conditional_engineering_gate_passed"] === true &&
            (conditional_pass_count += 1)
        path_sample_count[spec.drive_path] += 1
        protection_sample_count[spec.chamber_protection] += 1
        descriptor = _licfv15_descriptor(contract, spec, f)
        proposal = Dict{String,Any}(
            "descriptor" => descriptor,
            "structural_stratum" => "$(contract.id)|$(_licfv15_key(spec))",
            "contract_id" => contract.id, "drive_path" => spec.drive_path,
            "chamber_protection" => spec.chamber_protection,
            "anchor_only" => spec.anchor_only,
            "promotion_eligible" => spec.promotion_eligible,
            "features" => f, "nominal" => nominal)
        incumbent = get(archive, descriptor, nothing)
        if incumbent === nothing ||
                _licfv15_quality(proposal) < _licfv15_quality(incumbent)
            archive[descriptor] = proposal
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
        sort!(candidates; by = _licfv15_quality)
        append!(acquisitions, first(candidates,
            min(elites_per_structural_stratum, length(candidates))))
    end
    sort!(acquisitions; by = item ->
        (item["structural_stratum"], _licfv15_quality(item)))
    acquisitions = first(acquisitions,
        min(maximum_graph_elites, length(acquisitions)))
    contract_by_id = Dict(contract.id => contract for contract in contracts)
    spec_by_key = Dict(_licfv15_key(spec) => spec for spec in specs)
    records = Dict{String,Any}[]
    for acquisition in acquisitions
        contract = contract_by_id[String(acquisition["contract_id"])]
        spec_key = join(split(String(acquisition["structural_stratum"]),
            "|")[2:end], "|")
        spec = spec_by_key[spec_key]
        genome = _licfv15_build_genome(parent, spec,
            acquisition["features"], contract)
        evaluation = _laser_icf_result(LaserICFScreenV1(contract;
            allowed_contracts = contracts), genome)
        promoted = evaluation["promotable"] === true &&
            spec.promotion_eligible
        push!(records, Dict{String,Any}(
            "contract_id" => contract.id, "design_id" => genome.design_id,
            "physics_hash" => genome.physics_hash,
            "drive_path" => spec.drive_path,
            "chamber_protection" => spec.chamber_protection,
            "anchor_only" => spec.anchor_only,
            "promotion_eligible" => spec.promotion_eligible,
            "descriptor" => acquisition["descriptor"],
            "genome" => genome.normalized, "acquisition" => acquisition,
            "evaluation" => evaluation,
            "all_five_gates_passed" =>
                evaluation["all_five_gates_passed"],
            "conditional_physics_gate_passed" => evaluation["nominal"][
                "conditional_physics_gate_passed"],
            "conditional_engineering_gate_passed" => evaluation["nominal"][
                "conditional_engineering_gate_passed"],
            "positive_average_net_power_closure_passed" => evaluation[
                "positive_average_net_power_closure_passed"],
            "promoted" => promoted,
            "required_evidence_route" => spec.anchor_only ? String[] :
                ["icf_radiation_hydrodynamics",
                    spec.drive_path == "laser_fast_ignition" ?
                        "fast_ignition_transport" : "laser_plasma_interaction",
                    "repeat_rate_laser_driver", "target_factory_and_injection",
                    "pulsed_chamber_clearing", "first_wall_lifetime"],
            "medium_fidelity_route" => promoted ?
                ["icf_radiation_hydrodynamics", "laser_plasma_interaction",
                    "repeat_rate_laser_driver", "target_factory_and_injection",
                    "pulsed_chamber_clearing", "first_wall_lifetime"] :
                String[]))
    end
    sort!(records; by = record -> (
        record["anchor_only"] === true ? 1 : 0,
        record["conditional_physics_gate_passed"] === true &&
            record["conditional_engineering_gate_passed"] === true ? 0 : 1,
        record["positive_average_net_power_closure_passed"] === true ? 0 : 1,
        -Float64(record["evaluation"]["nominal"][
            "average_net_electric_power_W"]), record["physics_hash"]))
    return Dict{String,Any}(
        "algorithm" => "balanced Halton plus failure-aware laser-ICF MAP-Elites",
        "acquisition_samples" => acquisition_samples,
        "fixed_anchor_evaluation_count_outside_acquisition_budget" =>
            length(anchor_strata),
        "contract_count" => length(contracts),
        "contracts" => [_laser_icf_contract_dict(contract)
            for contract in contracts],
        "topology_count_per_contract" => length(specs),
        "science_anchor_topology_count_per_contract" =>
            count(spec -> spec.anchor_only, specs),
        "net_electric_hypothesis_topology_count_per_contract" =>
            count(spec -> !spec.anchor_only, specs),
        "structural_stratum_count" => length(strata),
        "acquisition_archive_cell_count" => length(archive),
        "acquisition_positive_average_net_count" => positive_net_count,
        "acquisition_conditional_physics_and_engineering_pass_count" =>
            conditional_pass_count,
        "explicit_graph_elite_count" => length(records),
        "explicit_graph_science_anchor_five_gate_count" => count(record ->
            record["anchor_only"] === true &&
                record["all_five_gates_passed"] === true, records),
        "explicit_graph_net_candidate_five_gate_count" => count(record ->
            record["anchor_only"] !== true &&
                record["all_five_gates_passed"] === true, records),
        "explicit_graph_conditional_survivor_count" => count(record ->
            record["anchor_only"] !== true &&
                record["conditional_physics_gate_passed"] === true &&
                record["conditional_engineering_gate_passed"] === true &&
                record["evaluation"]["robustness"]["gate_passed"] === true,
            records),
        "explicit_graph_positive_average_net_count" => count(record ->
            record["positive_average_net_power_closure_passed"] === true,
            records),
        "promotion_count" => count(record -> record["promoted"] === true,
            records),
        "path_sample_count" => path_sample_count,
        "protection_sample_count" => protection_sample_count,
        "topologies" => [Dict{String,Any}(
            "key" => _licfv15_key(spec), "drive_path" => spec.drive_path,
            "chamber_protection" => spec.chamber_protection,
            "anchor_only" => spec.anchor_only,
            "promotion_eligible" => spec.promotion_eligible) for spec in specs],
        "declared_search_domain" => Dict{String,Any}(
            "dimensions" => 18, "source_sequence" => "Halton",
            "stratum_sequence_policy" =>
                "paired local Halton coordinates shared across plant strata",
            "on_target_energy_J" => [3.0e5, 1.0e7],
            "target_gain_assumption" => [1.0, 500.0],
            "driver_wall_plug_efficiency_assumption" => [0.003, 0.30],
            "repetition_rate_Hz_assumption" => [0.05, 30.0],
            "availability_assumption" => [0.10, 0.95],
            "all_numerical_ranges" =>
                "broad search hypotheses, not evidence-backed reactor limits"),
        "admission_policy" => Dict{String,Any}(
            "science_anchor_can_promote" => false,
            "surrogate_or_hypothesis_can_promote" => false,
            "required_hard_evidence_gates" => [
                "target_gain_experimental_validation",
                "driver_wall_plug_and_repeat_rate_validation",
                "target_factory_throughput_and_yield_validation",
                "first_wall_and_final_optics_lifetime_validation"]),
        "records" => records, "claim_boundary" => _LICFV15_CLAIM_BOUNDARY)
end
