struct PulsedTopologySpecV6
    target_topology::String
    liner_kind::String
    compression_geometry::String

    function PulsedTopologySpecV6(target_topology::AbstractString,
            liner_kind::AbstractString, compression_geometry::AbstractString)
        topology = String(target_topology)
        liner = String(liner_kind)
        geometry = String(compression_geometry)
        topology in ("frc", "spheromak", "diffuse_pinch") ||
            throw(ArgumentError("unsupported pulsed target topology"))
        liner in ("solid_conducting_liner", "spherical_plasma_liner") ||
            throw(ArgumentError("unsupported liner kind"))
        geometry in ("spherical", "cylindrical") ||
            throw(ArgumentError("unsupported compression geometry"))
        liner == "spherical_plasma_liner" && geometry != "spherical" &&
            throw(ArgumentError("plasma-liner v6 branch is spherical"))
        return new(topology, liner, geometry)
    end
end

function _pulsed_specs_v6()
    return PulsedTopologySpecV6[
        PulsedTopologySpecV6("frc", "solid_conducting_liner", "spherical"),
        PulsedTopologySpecV6("frc", "spherical_plasma_liner", "spherical"),
        PulsedTopologySpecV6("spheromak", "solid_conducting_liner", "spherical"),
        PulsedTopologySpecV6("spheromak", "spherical_plasma_liner", "spherical"),
        PulsedTopologySpecV6("diffuse_pinch", "solid_conducting_liner",
            "cylindrical"),
        PulsedTopologySpecV6("diffuse_pinch", "spherical_plasma_liner",
            "spherical"),
    ]
end

_pulsed_key_v6(spec::PulsedTopologySpecV6) =
    "$(spec.target_topology)|$(spec.liner_kind)|$(spec.compression_geometry)"

_pulsed_q_v6(value, unit; basis = "failure-aware pulsed QD v6 gene") =
    Dict{String,Any}("value" => value, "unit" => unit, "basis" => basis)

function _pulsed_source_ids_v6(spec::PulsedTopologySpecV6)
    ids = String["mtf_overview_kirkpatrick_1995",
        "mtf_target_formation_lindemuth_1995",
        "mtf_centimeter_liner_ryutov_2005"]
    if spec.liner_kind == "spherical_plasma_liner"
        append!(ids, ["pjmif_target_hsu_langendorf_2019",
            "pjmif_semi_analytic_langendorf_hsu_2017"])
    else
        push!(ids, "maglif_semi_analytic_mcbride_slutz_2015")
    end
    spec.target_topology == "frc" &&
        push!(ids, "frc_compression_nimrod_ma_2023")
    return sort!(unique(ids))
end

function _pulsed_stability_v6(spec::PulsedTopologySpecV6,
        source_ids::Vector{String})
    mechanism = spec.target_topology == "frc" ? "finite_larmor_radius" :
        spec.target_topology == "spheromak" ? "self_organized_relaxation" :
        "other"
    return Dict{String,Any}(
        "id" => "pulsed_target_stability",
        "mechanism" => mechanism,
        "target_modes" => Any["tilt", "tearing", "liner_interface_instability"],
        "actuator_ids" => Any[],
        "assumptions" => Any[
            "target survives at least one modeled implosion time",
            "multidimensional liner and target stability remains unresolved"],
        "required_evaluators" => Any["liner_target_radiation_mhd",
            "target_formation_and_lifetime"],
        "source_ids" => Any[source_ids...],
    )
end

function _pulsed_ranges_v6(spec::PulsedTopologySpecV6, u)
    solid = spec.liner_kind == "solid_conducting_liner"
    r0 = 0.04 * (12.5 ^ u[1])
    velocity = solid ? 2.0e3 * (15.0 ^ u[4]) : 30.0e3 * (6.67 ^ u[4])
    liner_mass = solid ? 0.02 * (1000.0 ^ u[5]) :
        0.005 * (1000.0 ^ u[5])
    return Dict{String,Float64}(
        "initial_target_radius_m" => r0,
        "initial_target_half_length_m" => r0 * (1.0 + 3.0 * u[2]),
        "convergence_ratio" => 2.0 + 13.0 * u[3],
        "liner_velocity_m_s" => velocity,
        "liner_mass_kg" => liner_mass,
        "repetition_rate_Hz" => 0.10 * (100.0 ^ u[6]),
        "availability" => 0.20 + 0.70 * u[7],
        "driver_efficiency" => 0.10 + 0.60 * u[8],
        "formation_efficiency" => 0.10 + 0.50 * u[9],
        "recovery_fraction" => 0.50 * u[10],
        "compression_retention" => 0.15 + 0.75 * u[11],
        "preheat_energy_J" => 1.0e4 * (1000.0 ^ u[12]),
        "initial_temperature_keV" => 0.05 * (10.0 ^ u[13]),
        "initial_beta" => 0.30 * (16.67 ^ u[14]),
    )
end

function _pulsed_feature_tuple_v6(spec::PulsedTopologySpecV6,
        values::AbstractDict, contract::PulsedCompressionContractV1)
    return (
        target_topology = spec.target_topology,
        liner_kind = spec.liner_kind,
        compression_geometry = spec.compression_geometry,
        initial_radius_m = Float64(values["initial_target_radius_m"]),
        initial_half_length_m =
            Float64(values["initial_target_half_length_m"]),
        convergence_ratio = Float64(values["convergence_ratio"]),
        liner_velocity_m_s = Float64(values["liner_velocity_m_s"]),
        liner_mass_kg = Float64(values["liner_mass_kg"]),
        repetition_rate_Hz = Float64(values["repetition_rate_Hz"]),
        availability = Float64(values["availability"]),
        driver_efficiency = Float64(values["driver_efficiency"]),
        formation_efficiency = Float64(values["formation_efficiency"]),
        recovery_fraction = Float64(values["recovery_fraction"]),
        compression_retention = Float64(values["compression_retention"]),
        preheat_energy_J = Float64(values["preheat_energy_J"]),
        initial_temperature_keV = Float64(values["initial_temperature_keV"]),
        initial_beta = Float64(values["initial_beta"]),
        seed_field_T = contract.outer.plasma_field_T,
    )
end

function build_pulsed_compression_genome_v6(parent::Genome,
        spec::PulsedTopologySpecV6, values::AbstractDict,
        outer::SharedOuterEnvelopeContractV1)
    source_ids = _pulsed_source_ids_v6(spec)
    target_kind = "formation_or_compression_region"
    target_geometry = "$(spec.target_topology)_$(spec.compression_geometry)_target_v6"
    driver_id = spec.liner_kind == "solid_conducting_liner" ?
        "pulsed_power_liner_driver" : "merging_plasma_jet_driver"
    driver_kind = spec.liner_kind == "solid_conducting_liner" ?
        "pulsed_power" : "plasma_jet_array"
    target_field_class = spec.target_topology == "diffuse_pinch" ?
        "mixed" : "compact_toroid"
    target_material = spec.liner_kind == "solid_conducting_liner" ?
        "replaceable_conducting_liner_screen" : "fully_ionized_plasma_liner"
    raw = Dict{String,Any}(
        "schema_version" => "0.1.0",
        "design_id" => "pending_pulsed_v6",
        "label" => "Pulsed v6 $(_pulsed_key_v6(spec))",
        "mission" => Dict{String,Any}(
            "kind" => "net_electric_pilot",
            "fuel" => "D-T", "operating_mode" => "pulsed",
            "targets" => Dict{String,Any}(
                "screen_outer_radial_extent" => _pulsed_q_v6(
                    outer.outer_radial_extent_m, "m"),
                "screen_outer_axial_half_extent" => _pulsed_q_v6(
                    outer.outer_axial_half_extent_m, "m"),
                "screen_plasma_field" => _pulsed_q_v6(outer.plasma_field_T, "T"),
                "screen_initial_target_temperature" => _pulsed_q_v6(
                    values["initial_temperature_keV"], "keV"),
                "screen_initial_target_beta" => _pulsed_q_v6(
                    values["initial_beta"], "1"),
            )),
        "family" => "magnetized_target_fusion",
        "topology" => Dict{String,Any}(
            "field_line_class" => target_field_class,
            "rotation_transform_sources" => Any["self_organized_current"],
            "expected_flux_surfaces" => spec.target_topology != "diffuse_pinch",
            "expected_separatrix" => spec.target_topology != "diffuse_pinch"),
        "symmetry" => Dict{String,Any}(
            "class" => spec.compression_geometry == "cylindrical" ?
                "axisymmetric" : "none",
            "field_periods" => 1,
            "hard_constraints" => Any["explicit pulsed target-driver-liner graph",
                "average rather than peak power accounting"]),
        "plasma_regions" => Any[
            Dict{String,Any}("id" => "magnetized_target", "kind" => target_kind,
                "geometry_model" => target_geometry,
                "parameters" => Dict{String,Any}(
                    "initial_radius" => _pulsed_q_v6(
                        values["initial_target_radius_m"], "m"),
                    "initial_half_length" => _pulsed_q_v6(
                        values["initial_target_half_length_m"], "m"))),
            Dict{String,Any}("id" => "pulsed_chamber_region",
                "kind" => "divertor_or_exhaust_region",
                "geometry_model" => "replaceable_first_wall_pulsed_chamber_v1",
                "parameters" => Dict{String,Any}(
                    "outer_radius" => _pulsed_q_v6(
                        outer.outer_radial_extent_m, "m"),
                    "outer_half_height" => _pulsed_q_v6(
                        outer.outer_axial_half_extent_m, "m"))),
        ],
        "field_sources" => Any[
            Dict{String,Any}("id" => "target_seed_field",
                "kind" => "compression_seed_coil",
                "geometry_model" => "axisymmetric_seed_field_coil_v1",
                "parameters" => Dict{String,Any}(
                    "on_axis_field" => _pulsed_q_v6(outer.plasma_field_T, "T")),
                "material" => outer.base.magnet_material_envelope),
        ],
        "actuators" => Any[
            Dict{String,Any}("id" => "target_formation_driver",
                "kind" => "other", "parameters" => Dict{String,Any}(
                    "efficiency" => _pulsed_q_v6(
                        values["formation_efficiency"], "1"))),
            Dict{String,Any}("id" => driver_id, "kind" => "other",
                "parameters" => Dict{String,Any}(
                    "efficiency" => _pulsed_q_v6(
                        values["driver_efficiency"], "1"),
                    "preheat_energy" => _pulsed_q_v6(
                        values["preheat_energy_J"], "J"))),
        ],
        "compression_systems" => Any[
            Dict{String,Any}(
                "id" => "primary_compression_system",
                "kind" => spec.liner_kind,
                "geometry_model" => "$(spec.target_topology)_$(spec.compression_geometry)_$(driver_kind)_v1",
                "driver_actuator_ids" => Any[driver_id],
                "target_region_ids" => Any["magnetized_target"],
                "parameters" => Dict{String,Any}(
                    "initial_target_radius" => _pulsed_q_v6(
                        values["initial_target_radius_m"], "m"),
                    "initial_target_half_length" => _pulsed_q_v6(
                        values["initial_target_half_length_m"], "m"),
                    "convergence_ratio" => _pulsed_q_v6(
                        values["convergence_ratio"], "1"),
                    "liner_velocity" => _pulsed_q_v6(
                        values["liner_velocity_m_s"], "m/s"),
                    "liner_mass" => _pulsed_q_v6(values["liner_mass_kg"], "kg"),
                    "repetition_rate" => _pulsed_q_v6(
                        values["repetition_rate_Hz"], "Hz"),
                    "availability" => _pulsed_q_v6(values["availability"], "1"),
                    "driver_efficiency" => _pulsed_q_v6(
                        values["driver_efficiency"], "1"),
                    "formation_efficiency" => _pulsed_q_v6(
                        values["formation_efficiency"], "1"),
                    "recovery_fraction" => _pulsed_q_v6(
                        values["recovery_fraction"], "1"),
                    "compression_retention" => _pulsed_q_v6(
                        values["compression_retention"], "1"),
                    "preheat_energy" => _pulsed_q_v6(
                        values["preheat_energy_J"], "J")),
                "material" => target_material,
                "source_ids" => Any[source_ids...]),
        ],
        "stability_mechanisms" => Any[_pulsed_stability_v6(spec, source_ids)],
        "flux_connections" => Any[
            Dict{String,Any}("from_region_id" => "magnetized_target",
                "to_region_id" => "pulsed_chamber_region",
                "kind" => "compression_transfer")],
        "exhaust" => Dict{String,Any}(
            "kind" => "pulsed_chamber",
            "region_ids" => Any["pulsed_chamber_region"],
            "evaluation_requirements" => Any["repeat_rate_chamber_model",
                "chamber_clearing", "liner_debris_and_first_wall"]),
        "engineering" => Dict{String,Any}(
            "magnet_technology" => Any[outer.base.magnet_material_envelope],
            "blanket" => Dict{String,Any}("required" => true,
                "concept" => "pulsed_chamber_liquid_or_replaceable_blanket_screen",
                "target_tbr" => _pulsed_q_v6(1.10, "1")),
            "maintenance" => Dict{String,Any}(
                "architecture" => "remote_replaceable_pulsed_chamber",
                "access_paths" => Any["driver_ports", "target_injector",
                    "blanket_modules"]),
            "required_evaluators" => Any["liner_target_radiation_mhd",
                "repeat_rate_chamber_model", "driver_wall_plug_and_recovery",
                "neutronics_and_tbr", "fatigue_and_component_lifetime"]),
        "provenance" => Dict{String,Any}(
            "origin" => "generated", "source_ids" => Any[source_ids...],
            "parent_design_ids" => Any[parent.design_id],
            "claim_level" => "structural_example",
            "notes" => Any["grammar_rule:failure_aware_pulsed_qd_v6",
                "screening candidate only; no ignition or reactor claim"]),
    )
    provisional = parse_genome(raw)
    raw["design_id"] = "concept_$(provisional.physics_hash[1:20])"
    candidate = parse_genome(raw)
    report = validate_genome(candidate)
    report.valid || error(join(report.errors, "; "))
    family = validate_family(default_family_registry(), candidate)
    family.valid || error(join(family.errors, "; "))
    return candidate
end

function _pulsed_bin_v6(value::Float64, cuts::Tuple, labels::Tuple)
    for (cut, label) in zip(cuts, labels)
        value < cut && return label
    end
    return labels[end]
end

function _pulsed_descriptor_v6(contract::PulsedCompressionContractV1,
        spec::PulsedTopologySpecV6, features)
    convergence = _pulsed_bin_v6(features.convergence_ratio,
        (6.0, 10.0, Inf), ("C_low", "C_mid", "C_high"))
    repetition = _pulsed_bin_v6(features.repetition_rate_Hz,
        (0.5, 2.0, Inf), ("rep_low", "rep_mid", "rep_high"))
    radius = _pulsed_bin_v6(features.initial_radius_m,
        (0.10, 0.25, Inf), ("target_small", "target_mid", "target_large"))
    return join((contract.outer.id, spec.target_topology, spec.liner_kind,
        spec.compression_geometry, convergence, repetition, radius), "|")
end

function _pulsed_quality_v6(record::AbstractDict)
    nominal = record["nominal"]
    margins = Float64.(collect(values(nominal["margins"])))
    failed = count(value -> value < 0.0, margins)
    violation = sum(log1p(-min(0.0, value)) for value in margins)
    passed = nominal["physics_gate_passed"] === true &&
        nominal["engineering_gate_passed"] === true
    return (passed ? 0 : 1, failed, violation,
        nominal["average_net_electric_power_W"] > 0.0 ? 0 : 1,
        -Float64(nominal["minimum_normalized_margin"]),
        -Float64(nominal["average_net_electric_power_W"]),
        canonical_hash(record["features"]))
end

function run_failure_aware_pulsed_qd_v6(seeds::Vector{Genome};
        acquisition_samples::Int = 300_000,
        maximum_graph_elites::Int = 216,
        elites_per_structural_stratum::Int = 3,
        contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    acquisition_samples >= 0 || throw(ArgumentError(
        "acquisition_samples must be non-negative"))
    maximum_graph_elites > 0 || throw(ArgumentError(
        "maximum_graph_elites must be positive"))
    parent = only(filter(genome -> genome.family == "tokamak_axisymmetric",
        seeds))
    specs = _pulsed_specs_v6()
    strata = [(pulsed_compression_contract_v1(outer), spec)
        for outer in contracts for spec in specs]
    primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43)
    archive = Dict{String,Dict{String,Any}}()
    positive_average_net_count = 0
    nominal_pass_count = 0
    topology_sample_count = Dict(_pulsed_key_v6(spec) => 0 for spec in specs)
    for index in 1:acquisition_samples
        contract, spec = strata[mod1(index, length(strata))]
        u = ntuple(axis -> _ctv4_halton(index, primes[axis]), length(primes))
        values = _pulsed_ranges_v6(spec, u)
        features = _pulsed_feature_tuple_v6(spec, values, contract)
        nominal = _pulsed_nominal(parent, contract, features)
        nominal["average_net_electric_power_W"] > 0.0 &&
            (positive_average_net_count += 1)
        nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true &&
            (nominal_pass_count += 1)
        topology_sample_count[_pulsed_key_v6(spec)] += 1
        descriptor = _pulsed_descriptor_v6(contract, spec, features)
        proposal = Dict{String,Any}(
            "descriptor" => descriptor,
            "structural_stratum" => "$(contract.outer.id)|$(_pulsed_key_v6(spec))",
            "contract_id" => contract.outer.id,
            "target_topology" => spec.target_topology,
            "liner_kind" => spec.liner_kind,
            "compression_geometry" => spec.compression_geometry,
            "features" => values,
            "nominal" => nominal,
        )
        incumbent = get(archive, descriptor, nothing)
        if incumbent === nothing ||
                _pulsed_quality_v6(proposal) < _pulsed_quality_v6(incumbent)
            archive[descriptor] = proposal
        end
    end
    by_stratum = Dict{String,Vector{Dict{String,Any}}}()
    for proposal in values(archive)
        push!(get!(by_stratum, String(proposal["structural_stratum"]),
            Dict{String,Any}[]), proposal)
    end
    acquisitions = Dict{String,Any}[]
    for key in sort!(collect(keys(by_stratum)))
        candidates = by_stratum[key]
        sort!(candidates; by = _pulsed_quality_v6)
        append!(acquisitions, first(candidates,
            min(elites_per_structural_stratum, length(candidates))))
    end
    sort!(acquisitions; by = item ->
        (item["structural_stratum"], _pulsed_quality_v6(item)))
    acquisitions = first(acquisitions,
        min(maximum_graph_elites, length(acquisitions)))
    outer_by_id = Dict(outer.id => outer for outer in contracts)
    spec_by_key = Dict(_pulsed_key_v6(spec) => spec for spec in specs)
    records = Dict{String,Any}[]
    for acquisition in acquisitions
        outer = outer_by_id[String(acquisition["contract_id"])]
        spec = spec_by_key[join(split(String(
            acquisition["structural_stratum"]), "|")[2:end], "|")]
        candidate = build_pulsed_compression_genome_v6(parent, spec,
            acquisition["features"], outer)
        result = _pulsed_compression_result(PulsedCompressionScreenV1(
            pulsed_compression_contract_v1(outer)), candidate)
        promoted = result["all_five_gates_passed"] === true &&
            result["positive_average_net_power_closure_passed"] === true
        push!(records, Dict{String,Any}(
            "contract_id" => outer.id,
            "design_id" => candidate.design_id,
            "physics_hash" => candidate.physics_hash,
            "target_topology" => spec.target_topology,
            "liner_kind" => spec.liner_kind,
            "compression_geometry" => spec.compression_geometry,
            "descriptor" => acquisition["descriptor"],
            "genome" => candidate.normalized,
            "acquisition" => acquisition,
            "evaluation" => result,
            "promoted" => promoted,
        ))
    end
    sort!(records; by = record -> (record["promoted"] ? 0 : 1,
        _pulsed_quality_v6(record["acquisition"]), record["physics_hash"]))
    return Dict{String,Any}(
        "algorithm" => "balanced Halton MAP-Elites with explicit pulsed graph validation and average-power robustness",
        "acquisition_samples" => acquisition_samples,
        "contract_count" => length(contracts),
        "contracts" => [_pulsed_contract_dict(
            pulsed_compression_contract_v1(outer)) for outer in contracts],
        "topology_count_per_contract" => length(specs),
        "structural_stratum_count" => length(strata),
        "topologies" => [Dict("target_topology" => spec.target_topology,
            "liner_kind" => spec.liner_kind,
            "compression_geometry" => spec.compression_geometry)
            for spec in specs],
        "declared_search_domain" => Dict(
            "initial_target_radius_m" => [0.04, 0.50],
            "convergence_ratio" => [2.0, 15.0],
            "solid_liner_velocity_m_s" => [2.0e3, 30.0e3],
            "plasma_liner_velocity_m_s" => [30.0e3, 200.0e3],
            "repetition_rate_Hz" => [0.10, 10.0],
            "availability" => [0.20, 0.90],
            "driver_efficiency" => [0.10, 0.70],
            "energy_recovery_fraction" => [0.0, 0.50],
            "compression_retention" => [0.15, 0.90],
        ),
        "topology_sample_count" => topology_sample_count,
        "acquisition_archive_cell_count" => length(archive),
        "acquisition_positive_average_net_count" => positive_average_net_count,
        "acquisition_nominal_physics_and_engineering_pass_count" =>
            nominal_pass_count,
        "explicit_graph_elite_count" => length(records),
        "explicit_graph_five_gate_pass_count" => count(record ->
            record["evaluation"]["all_five_gates_passed"] === true, records),
        "promotion_count" => count(record -> record["promoted"] === true,
            records),
        "records" => records,
        "claim_boundary" => _PULSED_SCREEN_CLAIM_BOUNDARY,
    )
end
