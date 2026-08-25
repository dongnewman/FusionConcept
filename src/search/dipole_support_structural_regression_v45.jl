const _V45_CLAIM_BOUNDARY =
    "V45 makes the mechanically supported and levitated internal-dipole routes " *
    "two distinct, schema-valid topology graphs under one outer-envelope contract. " *
    "It reuses the existing v7 0.65 + 0.35*levitation-quality directional response " *
    "without fitting a coefficient. The LDX supported/levitated experiment is used " *
    "only as a direction anchor. Neither endpoint is independently magnitude-validated. " *
    "Support heat leak, material allowables, nuclear heat removal, lifetime, equilibrium, " *
    "and transport remain unresolved. Structural execution grants no physics or " *
    "engineering evidence-level increase, medium-fidelity authorization, robustness, " *
    "promotion, C1, reactor closure, scale-up, or net-electric credibility."

const _V45_SUPPORTED_FIELD_MODULE = "dipole_supported"
const _V45_LEVITATED_FIELD_MODULE = "dipole_levitated"

function _v45_mode(module_ids::Vector{String})
    supported = _V45_SUPPORTED_FIELD_MODULE in module_ids
    levitated = _V45_LEVITATED_FIELD_MODULE in module_ids
    xor(supported, levitated) || throw(ArgumentError(
        "v45 assembly must contain exactly one dipole support field module"))
    if supported
        "supported_dipole_cartridge" in module_ids || throw(ArgumentError(
            "supported dipole field module requires supported cartridge engineering"))
        return "mechanically_supported"
    end
    "levitated_coil_service" in module_ids || throw(ArgumentError(
        "levitated dipole field module requires levitated-coil service engineering"))
    return "levitated"
end

function _v45_assembly_value(assembly::AbstractDict, key::String)
    haskey(assembly, key) || throw(ArgumentError("v45 assembly is missing $key"))
    assembly[key]
end

function _v45_continuous_gene_hash(values::Dict{String,Float64})
    canonical_hash(Dict(key => value for (key, value) in values
        if key != "screen_levitation_quality"))
end

function _v45_structural_projection(g::Genome)
    Dict{String,Any}(
        "family" => g.family,
        "topology" => Dict(
            "field_line_class" => g.topology.field_line_class,
            "rotation_transform_sources" => g.topology.rotation_transform_sources),
        "symmetry" => g.symmetry.class,
        "plasma_regions" => [Dict("id" => item.id, "kind" => item.kind,
            "geometry_model" => item.geometry_model) for item in g.plasma_regions],
        "field_sources" => [Dict("id" => item.id, "kind" => item.kind,
            "geometry_model" => item.geometry_model) for item in g.field_sources],
        "actuators" => [Dict("id" => item.id, "kind" => item.kind)
            for item in g.actuators],
        "flux_connections" => [Dict("from" => item.from_region_id,
            "to" => item.to_region_id, "kind" => item.kind)
            for item in g.flux_connections],
        "exhaust" => Dict("kind" => g.exhaust.kind,
            "region_ids" => g.exhaust.region_ids),
        "maintenance" => Dict("architecture" =>
            g.engineering.maintenance_architecture,
            "access_paths" => g.engineering.access_paths))
end

_v45_structural_graph_hash(g::Genome) = canonical_hash(_v45_structural_projection(g))

function _v45_push_unique!(items, additions)
    for addition in additions
        addition in items || push!(items, addition)
    end
    items
end

function _v45_rebuild(raw::Dict{String,Any}, mode::String)
    raw["design_id"] = "pending_dipole_support_v45"
    provisional = parse_genome(raw)
    raw["design_id"] = "dipole_$(mode)_v45_$(provisional.physics_hash[1:16])"
    parse_genome(raw)
end

function _v45_build_graph(parent::Genome, contract,
        assembly::AbstractDict, values::Dict{String,Float64})
    module_ids = String.(collect(_v45_assembly_value(assembly, "module_ids")))
    mode = _v45_mode(module_ids)
    String(_v45_assembly_value(assembly, "family")) == "levitated_dipole" ||
        throw(ArgumentError("v45 supports only levitated_dipole assemblies"))

    paired_values = copy(values)
    paired_values["screen_levitation_quality"] =
        mode == "levitated" ? 1.0 : 0.0
    spec = SelfOrganizedTopologySpecV7(
        "levitated_dipole", "levitated_inward_pinch", 4)
    base = _sov7_structural_base(parent, spec)
    seed = _sov7_instantiate(base, paired_values, contract)
    raw = deepcopy(seed.normalized)

    raw["label"] = mode == "levitated" ?
        "V45 levitated internal-dipole structural route" :
        "V45 mechanically supported internal-dipole structural route"
    raw["topology"]["rotation_transform_sources"] = [mode == "levitated" ?
        "levitated_internal_dipole_coil" : "supported_internal_dipole_coil"]
    constraints = raw["symmetry"]["hard_constraints"]
    empty!(constraints)
    _v45_push_unique!(constraints, mode == "levitated" ?
        ["axisymmetric levitated internal coil",
         "no mechanical supports crossing confined field"] :
        ["axisymmetric mechanically supported internal coil",
         "finite supports cross and intercept confined-field trajectories"])
    _v45_push_unique!(constraints,
        ["v45_attribute_module:$id" for id in module_ids])
    push!(constraints, "v45_v17_graph_hash:" *
        String(_v45_assembly_value(assembly, "graph_hash")))

    if mode == "mechanically_supported"
        filter!(source -> source["id"] != "dipole_levitation_coil",
            raw["field_sources"])
        internal = only(filter(source -> source["id"] == "dipole_internal_coil",
            raw["field_sources"]))
        internal["kind"] = "supported_internal_dipole_coil"
        internal["geometry_model"] =
            "finite_build_superconducting_ring_with_four_mechanical_supports"
        support_count = 4.0
        support_radius = paired_values["screen_support_thickness"] / 2
        support_length = contract.outer_axial_half_extent_m
        support_area = support_count * pi * support_radius^2
        internal["parameters"]["support_count"] =
            _ctv4_quantity(support_count, "1")
        internal["parameters"]["support_radius"] =
            _ctv4_quantity(support_radius, "m")
        internal["parameters"]["support_length"] =
            _ctv4_quantity(support_length, "m")
        internal["parameters"]["total_support_cross_section"] =
            _ctv4_quantity(support_area, "m^2")

        sink = Dict{String,Any}(
            "id" => "dipole_support_loss_sink",
            "kind" => "mechanical_support_intercept_loss_sink",
            "geometry_model" => "four_finite_support_penetrations",
            "parameters" => Dict{String,Any}(
                "support_count" => _ctv4_quantity(support_count, "1"),
                "support_radius" => _ctv4_quantity(support_radius, "m"),
                "support_length" => _ctv4_quantity(support_length, "m"),
                "total_support_cross_section" =>
                    _ctv4_quantity(support_area, "m^2")))
        push!(raw["plasma_regions"], sink)
        push!(raw["flux_connections"], Dict{String,Any}(
            "from_region_id" => "so_core",
            "to_region_id" => "dipole_support_loss_sink",
            "kind" => "support_intercepted_field_line"))
        _v45_push_unique!(raw["exhaust"]["region_ids"],
            ["dipole_support_loss_sink"])
        _v45_push_unique!(raw["exhaust"]["evaluation_requirements"],
            ["support_intercepted_particle_and_heat_loss"])
        raw["engineering"]["maintenance"]["architecture"] =
            "replaceable supported internal-coil cartridge"
        raw["engineering"]["maintenance"]["access_paths"] =
            ["vertical supported internal-coil cartridge retrieval path",
             "replaceable mechanical support penetrations"]
        _v45_push_unique!(raw["engineering"]["required_evaluators"],
            ["internal_coil_support", "support_heat_leak",
             "nuclear_heat_removal", "internal_coil_replacement"])
        for mechanism in raw["stability_mechanisms"]
            filter!(assumption -> !occursin("levitation removes", assumption),
                mechanism["assumptions"])
            push!(mechanism["assumptions"],
                "mechanical supports create an explicit intercepted-loss route")
        end
    else
        _v45_push_unique!(raw["engineering"]["required_evaluators"],
            ["levitation_control", "internal_coil_lifetime",
             "nuclear_heat_removal"])
    end

    raw["engineering"]["magnet_technology"] =
        unique(String[source["material"] for source in raw["field_sources"]])
    raw["provenance"]["origin"] = "generated"
    raw["provenance"]["source_ids"] =
        ["dipole_ldx_design_garnier_2006",
         "dipole_inward_pinch_boxer_2010",
         "ldx_supported_levitated_maue_2010"]
    raw["provenance"]["claim_level"] = "structural_example"
    raw["provenance"]["notes"] = [
        "dipole_support_structural_regression_v45",
        "v17 assembly " * String(_v45_assembly_value(assembly, "assembly_id")),
        "support mode $mode is categorical; all other v7 continuous genes are paired",
        "MARS mirror-reactor source is deliberately excluded from dipole support provenance",
        "direction anchor only; no candidate performance validation"]
    genome = _v45_rebuild(raw, mode)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError("invalid v45 genome: " *
        join(report.errors, "; ")))
    family = validate_family(default_family_registry(), genome)
    family.valid || throw(ArgumentError("invalid v45 family graph: " *
        join(family.errors, "; ")))
    return genome, paired_values, mode
end

function _v45_graph_errors(g::Genome, mode::String, contract)
    errors = String[]
    append!(errors, validate_genome(g).errors)
    append!(errors, validate_family(default_family_registry(), g).errors)
    for (name, expected, unit) in (
            ("screen_outer_radial_extent", contract.outer_radial_extent_m, "m"),
            ("screen_outer_axial_half_extent", contract.outer_axial_half_extent_m, "m"),
            ("screen_plasma_field", contract.plasma_field_T, "T"))
        q = get(g.mission.targets, name, nothing)
        (q !== nothing && q.unit == unit &&
            isapprox(q.value, expected; rtol = 1e-12, atol = 1e-12)) ||
            push!(errors, "$name is inconsistent with the paired envelope")
    end
    cores = filter(r -> r.kind == "closed_toroidal_core", g.plasma_regions)
    sols = filter(r -> r.kind == "scrape_off_layer", g.plasma_regions)
    targets = filter(r -> r.kind == "divertor_or_exhaust_region", g.plasma_regions)
    length(cores) == 1 || push!(errors, "exactly one closed toroidal core is required")
    length(sols) == 1 || push!(errors, "exactly one SOL is required")
    length(targets) == 4 || push!(errors, "four paired exhaust targets are required")
    if length(cores) == 1 && length(sols) == 1
        count(edge -> edge.from_region_id == only(cores).id &&
            edge.to_region_id == only(sols).id &&
            edge.kind == "cross_separatrix_transport", g.flux_connections) == 1 ||
            push!(errors, "one core-to-SOL connection is required")
    end
    target_ids = Set(target.id for target in targets)
    if length(sols) == 1
        count(edge -> edge.from_region_id == only(sols).id &&
            edge.to_region_id in target_ids && edge.kind == "open_field_line",
            g.flux_connections) == length(target_ids) ||
            push!(errors, "SOL must connect to all paired targets")
    end

    sinks = filter(r -> r.kind == "mechanical_support_intercept_loss_sink",
        g.plasma_regions)
    supported_coil = _so_has_kind(g.field_sources, "supported_internal_dipole")
    levitated_coil = _so_has_kind(g.field_sources, "levitated_internal_dipole")
    levitation_hardware = _so_has_kind(g.field_sources, "external_levitation_coil")
    f = _so_features(g)
    if mode == "mechanically_supported"
        supported_coil || push!(errors, "supported route requires a supported internal coil")
        !levitated_coil || push!(errors, "supported route retains a levitated internal coil")
        !levitation_hardware || push!(errors, "supported route retains levitation hardware")
        length(sinks) == 1 || push!(errors, "supported route requires one support-loss sink")
        if length(sinks) == 1 && length(cores) == 1
            count(edge -> edge.from_region_id == only(cores).id &&
                edge.to_region_id == only(sinks).id &&
                edge.kind == "support_intercepted_field_line",
                g.flux_connections) == 1 || push!(errors,
                "supported route requires one core-to-support intercepted-loss edge")
            only(sinks).id in Set(g.exhaust.region_ids) || push!(errors,
                "support-loss sink must be declared by the exhaust graph")
        end
        f.levitation_quality == 0.0 || push!(errors,
            "supported categorical mode must map to zero levitation quality")
        any(path -> occursin("supported", lowercase(path)),
            g.engineering.access_paths) || push!(errors,
            "supported route requires a supported-coil maintenance path")
    else
        levitated_coil || push!(errors, "levitated route requires a levitated internal coil")
        levitation_hardware || push!(errors, "levitated route requires levitation hardware")
        !supported_coil || push!(errors, "levitated route retains a supported internal coil")
        isempty(sinks) || push!(errors, "levitated route contains a mechanical support sink")
        f.levitation_quality == 1.0 || push!(errors,
            "levitated categorical mode must map to unit levitation quality")
        any(path -> occursin("levitated", lowercase(path)) ||
            occursin("internal-coil", lowercase(path)),
            g.engineering.access_paths) || push!(errors,
            "levitated route requires an internal-coil service path")
    end
    sort!(unique(errors))
end

function _v45_endpoint_record(parent::Genome, contract,
        assembly::AbstractDict, values::Dict{String,Float64})
    genome, paired_values, mode = _v45_build_graph(parent, contract,
        assembly, values)
    features = _so_features(genome)
    nominal = _so_nominal(genome, contract, features)
    graph_errors = _v45_graph_errors(genome, mode, contract)
    legacy_errors = _so_graph_errors(genome, features, contract)
    module_ids = String.(collect(assembly["module_ids"]))
    field_module = mode == "levitated" ?
        _V45_LEVITATED_FIELD_MODULE : _V45_SUPPORTED_FIELD_MODULE
    selected = ["energy_confinement_time_s", "particle_loss_fraction_proxy",
        "minimum_stability_margin_proxy", "internal_coil_peak_field_T",
        "support_stress_proxy_Pa", "internal_coil_nuclear_heat_flux_W_m2"]
    Dict{String,Any}(
        "endpoint_id" => "v45_$field_module",
        "support_mode" => mode,
        "mapped_v43_module_id" => field_module,
        "v17_assembly_id" => String(assembly["assembly_id"]),
        "v17_graph_hash" => String(assembly["graph_hash"]),
        "v17_module_ids" => module_ids,
        "genome_design_id" => genome.design_id,
        "genome_content_hash" => genome.content_hash,
        "genome_physics_hash" => genome.physics_hash,
        "structural_graph_hash" => _v45_structural_graph_hash(genome),
        "continuous_gene_hash_excluding_support_mode" =>
            _v45_continuous_gene_hash(paired_values),
        "generic_genome_valid" => validate_genome(genome).valid,
        "family_graph_valid" => validate_family(
            default_family_registry(), genome).valid,
        "v45_topology_graph_errors" => graph_errors,
        "v45_topology_graph_valid" => isempty(graph_errors),
        "legacy_v7_graph_error_count" => length(legacy_errors),
        "legacy_v7_graph_errors" => legacy_errors,
        "nominal_direction_metrics" => Dict(key => nominal[key] for key in selected),
        "candidate_module_structurally_executed" => isempty(graph_errors),
        "independent_known_device_validation" => false,
        "candidate_module_independently_validated" => false,
        "engineering_closure_status" => "hard_unknown",
        "unresolved_engineering_classes" => mode == "levitated" ?
            ["levitation_control", "internal_coil_lifetime",
             "nuclear_heat_removal", "material_allowables"] :
            ["support_heat_leak", "internal_coil_replacement",
             "nuclear_heat_removal", "material_allowables"],
        "medium_fidelity_authorized" => false,
        "promotion_credit" => 0,
        "source_ids" => genome.provenance.source_ids)
end

function dipole_support_structural_regression_v45(seeds::Vector{Genome},
        supported_assembly::AbstractDict, levitated_assembly::AbstractDict)
    isempty(seeds) && throw(ArgumentError("v45 requires a parent seed"))
    parent = first(seeds)
    contract = only(filter(item -> item.id == "outer_small_B3_v1",
        shared_outer_envelope_contracts_v1()))
    spec = SelfOrganizedTopologySpecV7(
        "levitated_dipole", "levitated_inward_pinch", 4)
    base_values = _sov7_ranges(spec, fill(0.5, 21))
    supported = _v45_endpoint_record(parent, contract,
        supported_assembly, base_values)
    levitated = _v45_endpoint_record(parent, contract,
        levitated_assembly, base_values)
    low = supported["nominal_direction_metrics"]
    high = levitated["nominal_direction_metrics"]
    checks = Dict{String,Bool}(
        "both_generic_genomes_valid" => supported["generic_genome_valid"] &&
            levitated["generic_genome_valid"],
        "both_family_graphs_valid" => supported["family_graph_valid"] &&
            levitated["family_graph_valid"],
        "both_v45_topology_graphs_valid" =>
            supported["v45_topology_graph_valid"] &&
            levitated["v45_topology_graph_valid"],
        "structural_graph_hashes_distinct" =>
            supported["structural_graph_hash"] != levitated["structural_graph_hash"],
        "physics_hashes_distinct" =>
            supported["genome_physics_hash"] != levitated["genome_physics_hash"],
        "non_support_continuous_genes_paired" =>
            supported["continuous_gene_hash_excluding_support_mode"] ==
            levitated["continuous_gene_hash_excluding_support_mode"],
        "levitated_confinement_proxy_increased" =>
            high["energy_confinement_time_s"] > low["energy_confinement_time_s"],
        "levitated_particle_loss_proxy_decreased" =>
            high["particle_loss_fraction_proxy"] <
            low["particle_loss_fraction_proxy"],
        "levitated_stability_proxy_increased" =>
            high["minimum_stability_margin_proxy"] >
            low["minimum_stability_margin_proxy"],
        "mars_source_removed_from_both_routes" => all(endpoint ->
            !("mars_engineering_henning_1986" in endpoint["source_ids"]),
            (supported, levitated)))
    endpoints = [supported, levitated]
    pair_record = Dict{String,Any}(
        "trial_id" => "ldx_explicit_supported_to_levitated_topology_pair",
        "direction_anchor_source_id" => "ldx_supported_levitated_maue_2010",
        "direction_replay_class" =>
            "paired_structural_direction_replay_not_independent_validation",
        "same_outer_envelope_contract_id" => contract.id,
        "support_mode_is_categorical" => true,
        "non_support_continuous_genes_paired" =>
            checks["non_support_continuous_genes_paired"],
        "expected_direction" => Dict(
            "energy_confinement_time_s" => "increase",
            "particle_loss_fraction_proxy" => "decrease",
            "minimum_stability_margin_proxy" => "increase"),
        "supported_state" => low,
        "levitated_state" => high,
        "levitated_minus_supported" => Dict(key => high[key] - low[key]
            for key in keys(low)),
        "direction_and_structure_checks" => checks,
        "all_checks_passed" => all(values(checks)),
        "independent_known_device_validation" => false,
        "candidate_module_independently_validated" => false,
        "engineering_closure" => false,
        "medium_fidelity_authorized" => false,
        "promotion_credit" => 0)
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "search_version" => "dipole_support_structural_regression_v45",
        "stage" => "sealed_explicit_dipole_support_topology_regression",
        "regression_contract" => Dict{String,Any}(
            "same_outer_envelope_required" => true,
            "same_non_support_continuous_genes_required" => true,
            "distinct_structural_graphs_required" => true,
            "existing_v7_direction_equation_only" => true,
            "new_empirical_coefficient_allowed" => false,
            "direction_anchor_is_independent_validation" => false,
            "structural_execution_can_promote_candidate" => false,
            "unresolved_engineering_can_pass_closure" => false),
        "aggregate" => Dict{String,Any}(
            "endpoint_count" => 2,
            "mapped_v43_experimental_anchor_module_count" => 2,
            "mapped_v43_experimental_anchor_module_ids" =>
                [_V45_LEVITATED_FIELD_MODULE, _V45_SUPPORTED_FIELD_MODULE],
            "v43_observable_route_count" => 23,
            "candidate_specific_structurally_executable_route_count" =>
                count(endpoint -> endpoint[
                    "candidate_module_structurally_executed"] === true, endpoints),
            "candidate_specific_structurally_executable_route_fraction" => 2 / 23,
            "candidate_specific_independently_validated_route_count" => 0,
            "independent_known_device_validation_count" => 0,
            "paired_direction_trial_count" => 1,
            "paired_direction_trial_pass_count" => pair_record["all_checks_passed"] ? 1 : 0,
            "engineering_closure_count" => 0,
            "medium_fidelity_authorized_count" => 0,
            "promotion_count" => 0,
            "old_domain_scale_up_authorized" => false),
        "paired_trial" => pair_record,
        "endpoint_records" => endpoints,
        "source_route_correction" => Dict{String,Any}(
            "sealed_v17_source_mismatch" =>
                "dipole_supported and supported_dipole_cartridge cite MARS mirror engineering",
            "v45_action" =>
                "exclude MARS from both dipole endpoint provenance without mutating v17",
            "replacement_direction_sources" =>
                ["dipole_ldx_design_garnier_2006",
                 "dipole_inward_pinch_boxer_2010",
                 "ldx_supported_levitated_maue_2010"],
            "candidate_specific_performance_credit" => 0),
        "next_actions" => [
            "implement support heat-conduction and material-temperature inputs without inventing constants",
            "run finite-beta dipole equilibrium for both explicit topology graphs",
            "compare held-out LDX discharge magnitudes rather than only direction",
            "route v17/v20 dipole assemblies through the v45 support-aware projection during broad search"],
        "promotion_credit" => Dict{String,Any}(
            "physics_evidence_level_change" => 0,
            "engineering_evidence_level_change" => 0,
            "medium_fidelity_authorized_count" => 0,
            "promotion_count" => 0),
        "claim_boundary" => _V45_CLAIM_BOUNDARY)
end
