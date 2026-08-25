const _V46_CLAIM_BOUNDARY =
    "V46 routes every v17 levitated-dipole assembly through the explicit v45 " *
    "supported-or-levitated topology graph while preserving the sealed v20 path " *
    "for all non-dipole families. It reuses the v7 fidelity-0 equations and does " *
    "not add an empirical coefficient. Missing support heat leak, material, nuclear " *
    "heating, lifetime, finite-beta equilibrium, and transport evidence force the " *
    "engineering and robustness gates false. A graph-valid route, positive ledger, " *
    "or changed proxy is not independent validation, C1, medium-fidelity authority, " *
    "scale-up authority, superiority, or reactor evidence."

struct DipoleSupportAwareScreenV46 <: AbstractEvaluator
    contract::SharedOuterEnvelopeContractV1
    allowed_contract_hashes::Set{String}
end

function DipoleSupportAwareScreenV46(contract::SharedOuterEnvelopeContractV1;
        allowed_contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    DipoleSupportAwareScreenV46(contract,
        Set(canonical_hash(_oe_contract_dict(item)) for item in allowed_contracts))
end

function evaluator_spec(::DipoleSupportAwareScreenV46)
    EvaluatorSpec("dipole_support_aware_screen_v46", "46.0.0",
        ["levitated_dipole"], 0,
        Dict("finite_beta_dipole_equilibrium" => :proxy,
            "dipole_adiabatic_profile_stability" => :proxy,
            "dipole_turbulent_transport" => :proxy,
            "separatrix_field_line_mapping" => :proxy,
            "sol_transport" => :proxy,
            "target_heat_flux" => :proxy,
            "impurity_and_helium_ash_exhaust" => :proxy,
            "finite_build_coils" => :proxy,
            "coil_stress" => :proxy,
            "shielding" => :proxy,
            "maintenance_access" => :proxy,
            "neutronics" => :proxy,
            "actuator_power" => :proxy),
        _V46_CLAIM_BOUNDARY)
end

function evaluator_applicability(evaluator::DipoleSupportAwareScreenV46,
        genome::Genome)
    genome.family == "levitated_dipole" || return false,
        "v46 support-aware screen applies only to dipole assemblies"
    genome.mission.fuel == "D-T" || return false,
        "v46 support-aware screen uses the common D-T mission"
    family = validate_family(default_family_registry(), genome)
    family.valid || return false, join(family.errors, "; ")
    true, "support-aware dipole graph under $(evaluator.contract.id)"
end

function _v46_support_mode(genome::Genome)
    supported = _so_has_kind(genome.field_sources, "supported_internal_dipole")
    levitated = _so_has_kind(genome.field_sources, "levitated_internal_dipole")
    xor(supported, levitated) || throw(ArgumentError(
        "v46 dipole genome must contain exactly one internal-coil support mode"))
    supported ? "mechanically_supported" : "levitated"
end

function _v46_dipole_result(evaluator::DipoleSupportAwareScreenV46,
        genome::Genome)
    mode = _v46_support_mode(genome)
    features = _so_features(genome)
    graph_errors = _v45_graph_errors(genome, mode, evaluator.contract)
    nominal = _so_nominal(genome, evaluator.contract, features)
    contract_hash = canonical_hash(_oe_contract_dict(evaluator.contract))
    contract_gate = contract_hash in evaluator.allowed_contract_hashes
    graph_gate = isempty(graph_errors)
    physics_gate = nominal["physics_gate_passed"] === true
    engineering_unknowns = mode == "mechanically_supported" ?
        ["support_heat_leak", "material_allowables",
         "nuclear_heat_removal", "internal_coil_replacement"] :
        ["levitation_control", "material_allowables",
         "nuclear_heat_removal", "internal_coil_lifetime"]
    engineering_gate = false
    robustness = Dict{String,Any}(
        "sample_count" => 0,
        "maximum_sample_budget" => evaluator.contract.base.robustness_samples,
        "pass_count" => 0,
        "pass_fraction" => 0.0,
        "required_pass_fraction" =>
            evaluator.contract.base.robustness_required_pass_fraction,
        "gate_passed" => false,
        "skipped_due_hard_unknown_engineering" => true,
        "hard_unknown_classes" => engineering_unknowns,
        "records" => Dict{String,Any}[])
    gates = Dict{String,Bool}(
        "variable_topology_representation" => graph_gate,
        "unified_low_fidelity_physics" => physics_gate,
        "minimal_engineering_closure" => engineering_gate,
        "same_outer_envelope_contract" => contract_gate,
        "cheap_robustness_screen" => false)
    result = Dict{String,Any}(
        "contract" => _oe_contract_dict(evaluator.contract),
        "contract_hash" => contract_hash,
        "support_mode" => mode,
        "claim_boundary" => _V46_CLAIM_BOUNDARY,
        "source_basis" => ["dipole_ldx_design_garnier_2006",
            "dipole_inward_pinch_boxer_2010",
            "ldx_supported_levitated_maue_2010"],
        "topology_features" =>
            Dict(String(key) => value for (key, value) in pairs(features)),
        "topology_graph_errors" => graph_errors,
        "nominal" => nominal,
        "minimal_engineering_proxy_before_unknown_guard" =>
            nominal["engineering_gate_passed"],
        "engineering_hard_unknown_classes" => engineering_unknowns,
        "robustness" => robustness,
        "gates" => gates,
        "all_five_gates_passed" => false,
        "positive_net_power_closure_passed" =>
            nominal["net_electric_power_W"] > 0,
        "classification" => graph_gate ?
            "support_aware_dipole_graph_pending_physics_and_engineering" :
            "invalid_support_aware_dipole_graph",
        "independent_known_device_validation" => false,
        "candidate_route_independently_validated" => false,
        "medium_fidelity_authorized" => false,
        "promotion_credit" => 0)
    result["result_hash"] = canonical_hash(result)
    result
end

function run_evaluator(evaluator::DipoleSupportAwareScreenV46,
        genome::Genome; kwargs...)
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return _non_applicable_bundle(evaluator_spec(evaluator),
        genome, reason)
    result = _v46_dipole_result(evaluator, genome)
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "evaluator" => evaluator_spec(evaluator).id,
        "version" => evaluator_spec(evaluator).version,
        "result_hash" => result["result_hash"]))
    metrics = MetricResult[
        MetricResult("support_aware_graph_valid",
            isempty(result["topology_graph_errors"]) ? 1.0 : 0.0;
            unit = "1", fidelity = 0, applicability = reason,
            status = :proxy, solver_name = evaluator_spec(evaluator).id,
            solver_version = evaluator_spec(evaluator).version,
            run_hash = run_hash, source_ids = result["source_basis"],
            notes = [_V46_CLAIM_BOUNDARY])]
    EvaluationBundle(evaluator_spec(evaluator), genome.design_id,
        genome.physics_hash, metrics, run_hash, now(UTC))
end

struct SupportAwareCrossTopologyContextV46
    base::RecoverableCrossTopologyContextV20
    dipole_evaluator::DipoleSupportAwareScreenV46
    evaluators::Dict{String,AbstractEvaluator}
    evaluator_registry::EvaluatorRegistry
    v45_result_hash::String
end

function build_support_aware_cross_topology_context_v46(
        grammar::AttributeGraphGrammarResultV17, seeds::Vector{Genome};
        v45_result_hash::AbstractString)
    occursin(r"^[0-9a-f]{64}$", String(v45_result_hash)) ||
        throw(ArgumentError("v46 requires a sealed v45 SHA-256 result hash"))
    base = build_recoverable_cross_topology_context_v20(grammar, seeds)
    dipole = DipoleSupportAwareScreenV46(base.compiler_context.outer)
    evaluators = copy(base.evaluators)
    evaluators[evaluator_spec(dipole).id] = dipole
    registry = EvaluatorRegistry()
    for id in sort!(collect(keys(evaluators)))
        register!(registry, evaluators[id])
    end
    SupportAwareCrossTopologyContextV46(base, dipole, evaluators, registry,
        String(v45_result_hash))
end

function _v46_scrub_dipole_source_mismatch(genome::Genome,
        assembly::TopologyAssemblyV17)
    raw = deepcopy(genome.normalized)
    sources = raw["provenance"]["source_ids"]
    filter!(source -> source != "mars_engineering_henning_1986", sources)
    _v18_push_unique!(sources, ["dipole_ldx_design_garnier_2006",
        "dipole_inward_pinch_boxer_2010",
        "ldx_supported_levitated_maue_2010"])
    sort!(sources)
    _v18_push_unique!(raw["provenance"]["notes"], [
        "support_aware_cross_topology_kernel_v46",
        "MARS mirror source excluded from dipole support route",
        "v17 graph identity preserved without transferring mismatched source credit"])
    raw["design_id"] = "pending_support_aware_v46"
    provisional = parse_genome(raw)
    raw["design_id"] = "v46_$(assembly.graph_hash[1:16])_" *
        provisional.physics_hash[1:12]
    parse_genome(raw)
end

function _v46_dipole_genome(context::SupportAwareCrossTopologyContextV46,
        assembly::TopologyAssemblyV17, sample_ordinal::Int,
        values_u::Vector{Float64})
    spec = SelfOrganizedTopologySpecV7(
        "levitated_dipole", "levitated_inward_pinch", 4)
    values = _sov7_ranges(spec, values_u[1:21])
    assembly_dict = topology_assembly_to_dict_v17(assembly)
    proxy, paired_values, mode = _v45_build_graph(
        context.base.compiler_context.tokamak_parent,
        context.base.compiler_context.outer, assembly_dict, values)
    annotated = _v18_annotate_proxy(proxy, assembly, context.base.modules)
    corrected = _v46_scrub_dipole_source_mismatch(annotated, assembly)
    genome = _v20_sample_annotation(corrected, assembly, sample_ordinal)
    return genome, paired_values, mode
end

function _v46_dipole_prescreen(context::SupportAwareCrossTopologyContextV46,
        compiled::CompiledAttributeGenomeV18)
    evaluator = context.dipole_evaluator
    applicable, reason = evaluator_applicability(evaluator, compiled.genome)
    applicable || return AttributeGenomePrescreenV18(compiled, false, reason,
        Dict{String,Bool}(), false, 0.0, false,
        copy(compiled.declared_requirements), false, false, String[],
        canonical_hash(Dict("status" => "not_applicable",
            "reason" => reason, "input_hash" => compiled.genome.physics_hash)))
    result = _v46_dipole_result(evaluator, compiled.genome)
    gates = Dict{String,Bool}(String(key) => value === true
        for (key, value) in result["gates"])
    coverage = coverage_report(context.evaluator_registry, compiled.genome)
    by_requirement = Dict(item.requirement => item.support for item in coverage)
    missing = sort!(String[requirement for requirement in compiled.declared_requirements
        if get(by_requirement, requirement, :missing) == :missing])
    complete = isempty(missing)
    graph_errors = String.(result["topology_graph_errors"])
    AttributeGenomePrescreenV18(compiled, true, reason, gates, false, 0.0,
        result["positive_net_power_closure_passed"] === true,
        missing, complete, false, graph_errors, String(result["result_hash"]))
end

function _v46_add_integration_fields!(record::Dict{String,Any};
        route::String, legacy_record::Dict{String,Any},
        mode::String = "not_applicable",
        structural_graph_hash::Union{Nothing,String} = nothing,
        explicit_dipole_graph::Bool = false)
    v46_core_hash = canonical_hash(record)
    legacy_hash = canonical_hash(legacy_record)
    record["v46_integration_route"] = route
    record["v46_v20_compatible_core_record_hash"] = v46_core_hash
    record["v46_legacy_v20_core_record_hash"] = legacy_hash
    record["v46_core_changed_from_v20"] = v46_core_hash != legacy_hash
    record["v46_support_mode"] = mode
    record["v46_structural_graph_hash"] = structural_graph_hash
    record["v46_explicit_dipole_graph"] = explicit_dipole_graph
    record["v46_candidate_specific_structural_route"] =
        explicit_dipole_graph && isempty(record["topology_graph_errors"])
    record["v46_source_mismatch_removed"] = explicit_dipole_graph ?
        !("mars_engineering_henning_1986" in
            get(record, "provenance_source_ids", String[])) : true
    record["v46_independent_candidate_route_validation"] = false
    record["v46_medium_fidelity_authorized"] = false
    record["v46_promotion_credit"] = 0
    record["v46_claim_boundary"] = _V46_CLAIM_BOUNDARY
    record
end

function evaluate_cross_topology_candidate_v46(
        context::SupportAwareCrossTopologyContextV46, candidate_index::Int;
        halton_skip::Int = 4096)
    candidate_index > 0 || throw(ArgumentError("candidate_index must be positive"))
    topology_count = length(context.base.assemblies)
    assembly_index = mod1(candidate_index, topology_count)
    sample_ordinal = cld(candidate_index, topology_count)
    assembly = context.base.assemblies[assembly_index]
    legacy_candidate = evaluate_cross_topology_candidate_v20(context.base,
        candidate_index; halton_skip = halton_skip)
    legacy_record = cross_topology_candidate_to_dict_v20(legacy_candidate)
    if assembly.family != "levitated_dipole"
        record = deepcopy(legacy_record)
        return _v46_add_integration_fields!(record;
            route = "sealed_v20_non_dipole_passthrough",
            legacy_record = legacy_record)
    end

    values_u = _v20_unit_vector(sample_ordinal, length(_V20_HALTON_PRIMES);
        skip = halton_skip)
    genome, paired_values, mode = _v46_dipole_genome(context, assembly,
        sample_ordinal, values_u)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError("v46 dipole genome invalid: " *
        join(report.errors, "; ")))
    family_report = validate_family(default_family_registry(), genome)
    family_report.valid || throw(ArgumentError("v46 dipole family invalid: " *
        join(family_report.errors, "; ")))
    mission_contract_for(default_mission_contract_registry(), genome).id ==
        assembly.mission_contract_id || throw(ArgumentError(
        "v46 dipole mission contract drifted"))
    declared = _v20_declared_requirements(context.base, assembly)
    issubset(Set(declared), Set(_requirements(genome))) || throw(ArgumentError(
        "v46 dipole genome lost declared requirements"))
    warnings = sort!(unique(vcat(report.warnings, family_report.warnings)))
    limitations = String[
        "v46 realizes internal-coil support topology but retains the v7 fidelity-0 response equations",
        "v17 stability and exhaust module geometry remain annotated identities rather than solved geometry",
        "support heat leak, materials, nuclear heating, lifetime, equilibrium, and transport remain hard unknown",
    ]
    compiled = CompiledAttributeGenomeV18(assembly.assembly_id,
        assembly.graph_hash, assembly.family, assembly.mission_contract_id,
        copy(assembly.module_ids), genome, evaluator_spec(
            context.dipole_evaluator).id,
        "dipole_support_v45|$mode|targets=4",
        limitations, declared, warnings)
    prescreen = _v46_dipole_prescreen(context, compiled)
    candidate = CrossTopologyCandidateV20(candidate_index, assembly_index,
        sample_ordinal, prescreen)
    record = cross_topology_candidate_to_dict_v20(candidate)
    record["provenance_source_ids"] = copy(genome.provenance.source_ids)
    record["v46_non_support_continuous_gene_hash"] =
        _v45_continuous_gene_hash(paired_values)
    record["v46_legacy_v20_physics_hash"] = legacy_record["physics_hash"]
    record["v46_legacy_v20_evaluator_id"] = legacy_record["evaluator_id"]
    return _v46_add_integration_fields!(record;
        route = "support_aware_dipole_projection_v45",
        legacy_record = legacy_record, mode = mode,
        structural_graph_hash = _v45_structural_graph_hash(genome),
        explicit_dipole_graph = true)
end

function support_aware_cross_topology_kernel_v46(
        context::SupportAwareCrossTopologyContextV46)
    return function(candidate_index::Int, config::Dict{String,Any})
        Int(get(config, "topology_archive_size",
            length(context.base.assemblies))) == length(context.base.assemblies) ||
            throw(ArgumentError("v46 topology count mismatch"))
        String(get(config, "topology_archive_hash", context.base.archive_hash)) ==
            context.base.archive_hash || throw(ArgumentError(
            "v46 topology archive hash mismatch"))
        String(get(config, "v45_result_hash", context.v45_result_hash)) ==
            context.v45_result_hash || throw(ArgumentError(
            "v46 sealed v45 result binding mismatch"))
        halton_skip = Int(get(config, "halton_skip", 4096))
        record = evaluate_cross_topology_candidate_v46(context,
            candidate_index; halton_skip = halton_skip)
        RecoverableKernelOutcomeV19(record, true)
    end
end

function support_aware_cross_topology_spec_v46(
        context::SupportAwareCrossTopologyContextV46,
        total_candidates::Integer, shard_size::Integer;
        run_id::AbstractString = "support_aware_cross_topology_search_v46",
        max_retries::Integer = 2, halton_skip::Integer = 4096)
    RecoverableRunSpecV19(run_id,
        "support_aware_cross_topology_fidelity0_kernel", "46.0.0",
        total_candidates, shard_size;
        max_retries = max_retries,
        max_retained_per_shard = Int(shard_size),
        kernel_config = Dict{String,Any}(
            "topology_archive_size" => length(context.base.assemblies),
            "topology_archive_hash" => context.base.archive_hash,
            "topology_catalog_hash" => context.base.catalog_hash,
            "v45_result_hash" => context.v45_result_hash,
            "halton_sequence" => "paired_global_ordinal_halton_24d_v1",
            "halton_skip" => Int(halton_skip),
            "claim_boundary" => _V46_CLAIM_BOUNDARY))
end

function support_aware_cross_topology_audit_v46(records::AbstractVector,
        context::SupportAwareCrossTopologyContextV46)
    normalized = Dict{String,Any}[Dict{String,Any}(String(key) =>
        _plain_json(value) for (key, value) in record) for record in records]
    sort!(normalized; by = record -> Int(record["candidate_index"]))
    candidate_indices = Int.(getindex.(normalized, "candidate_index"))
    length(unique(candidate_indices)) == length(normalized) ||
        throw(ArgumentError("v46 duplicate candidate indices"))
    families = sort!(unique(String.(getindex.(normalized, "family"))))
    assemblies = sort!(unique(String.(getindex.(normalized, "assembly_id"))))
    passthrough = filter(record -> record["v46_integration_route"] ==
        "sealed_v20_non_dipole_passthrough", normalized)
    dipole = filter(record -> record["v46_explicit_dipole_graph"] === true,
        normalized)
    supported = filter(record -> record["v46_support_mode"] ==
        "mechanically_supported", dipole)
    levitated = filter(record -> record["v46_support_mode"] == "levitated",
        dipole)
    qd = cross_topology_failure_aware_archive_v20(normalized)
    Dict{String,Any}(
        "schema_version" => "1.0.0",
        "search_version" => "support_aware_cross_topology_kernel_v46",
        "stage" => "sealed_full_archive_support_aware_integration_audit",
        "integration_contract" => Dict{String,Any}(
            "non_dipole_v20_core_record_must_be_identical" => true,
            "dipole_field_module_selects_explicit_support_graph" => true,
            "same_halton_sample_ordinal_across_archive" => true,
            "hard_unknown_engineering_forces_gate_failure" => true,
            "structural_execution_is_independent_validation" => false,
            "structural_execution_can_promote" => false),
        "aggregate" => Dict{String,Any}(
            "candidate_count" => length(normalized),
            "family_count" => length(families),
            "families" => families,
            "assembly_count" => length(assemblies),
            "samples_per_assembly" => length(normalized) ÷ length(assemblies),
            "non_dipole_passthrough_candidate_count" => length(passthrough),
            "non_dipole_v20_core_preserved_count" => count(record ->
                record["v46_core_changed_from_v20"] === false, passthrough),
            "explicit_dipole_candidate_count" => length(dipole),
            "supported_dipole_candidate_count" => length(supported),
            "levitated_dipole_candidate_count" => length(levitated),
            "supported_legacy_misroute_fixed_count" => count(record ->
                _V45_SUPPORTED_FIELD_MODULE in record["module_ids"] &&
                record["v46_support_mode"] == "mechanically_supported", dipole),
            "dipole_v45_graph_valid_count" => count(record ->
                isempty(record["topology_graph_errors"]), dipole),
            "dipole_structural_graph_hash_count" => length(unique(
                String.(getindex.(dipole, "v46_structural_graph_hash")))),
            "dipole_physics_hash_count" => length(unique(
                String.(getindex.(dipole, "physics_hash")))),
            "mapped_candidate_specific_structural_route_count" => length(unique(
                String[record["module_ids"][2] for record in dipole])),
            "mapped_candidate_specific_structural_route_ids" => sort!(unique(
                String[record["module_ids"][2] for record in dipole])),
            "candidate_specific_independently_validated_route_count" => 0,
            "proxy_five_gate_pass_count" => count(record ->
                record["proxy_five_gate_passed"] === true, normalized),
            "medium_fidelity_candidate_count" => count(record ->
                record["medium_fidelity_candidate_eligible"] === true, normalized),
            "promotion_count" => 0,
            "qd_archive_cell_count" => qd["archive_cell_count"],
            "old_domain_scale_up_authorized" => false),
        "family_candidate_counts" => Dict(family => count(record ->
            record["family"] == family, normalized) for family in families),
        "candidate_records" => normalized,
        "qd_archive_records" => qd["records"],
        "next_actions" => [
            "add held-out LDX magnitude inputs and finite-beta equilibrium without changing the v46 search contract",
            "route the next cross-family structural aliases through candidate-specific solvers rather than adding constants",
            "repeat the full archive audit after every projection repair before increasing candidate count",
            "run the formal 1e7 load only after physics labels and robustness gates become informative"],
        "promotion_credit" => Dict{String,Any}(
            "physics_evidence_level_change" => 0,
            "engineering_evidence_level_change" => 0,
            "medium_fidelity_authorized_count" => 0,
            "promotion_count" => 0),
        "claim_boundary" => _V46_CLAIM_BOUNDARY)
end
