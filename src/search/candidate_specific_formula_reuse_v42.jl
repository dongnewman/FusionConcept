const _V42_CLAIM_BOUNDARY =
    "V42 reconnects six previously aliased v17 module identities to already registered " *
    "candidate-dependent fidelity-0 equations: magnetic-mirror end-loss/direct-conversion " *
    "routes from v9-v11 and RFP PPCD/boundary-feedback routes from v7-v8. It adds no " *
    "empirical performance multiplier, promotion credit, or medium-fidelity authorization. " *
    "A changed margin identifies formula observability only; unchanged routes remain aliases, " *
    "missing measurements remain unknown, and no result establishes causality, superiority, " *
    "robustness, C1, or reactor feasibility."

const _V42_REUSE_MODULES = Set([
    "mirror_direct_converter", "mirror_gas_dynamic_targets",
    "mirror_solenoidal_plugs", "mirror_tandem_plugs",
    "rfp_ppcd", "rfp_saddle_control",
])

const _V42_FORMULA_OWNERS = Dict(
    "magnetic_mirror" => [
        "src/adapters/composable_cross_family_screen_v1.jl",
        "src/adapters/mechanism_expansion_screen_v1.jl",
        "src/adapters/open_loss_pathway_screen_v1.jl",
        "src/search/composable_cross_family_qd_v9.jl",
        "src/search/mechanism_expansion_qd_v10.jl",
        "src/search/open_loss_pathway_qd_v11.jl",
    ],
    "reversed_field_pinch" => [
        "src/adapters/self_organized_screen_v1.jl",
        "src/adapters/profile_coupled_rfp_screen_v1.jl",
        "src/search/self_organized_qd_v7.jl",
        "src/search/profile_coupled_rfp_qd_v8.jl",
    ],
    "field_reversed_configuration" => [
        "src/adapters/compact_toroid_screen_v1.jl",
        "src/search/compact_toroid_edge_qd_v4.jl",
    ],
    "spheromak" => [
        "src/adapters/compact_toroid_screen_v1.jl",
        "src/search/compact_toroid_edge_qd_v4.jl",
    ],
    "stellarator" => [
        "src/adapters/stellarator_desc_stability_v1.jl",
        "src/adapters/stellarator_desc_transport_proxy_v1.jl",
        "src/adapters/stellarator_desc_discrete_coil_optimization_v1.jl",
    ],
    "tokamak_axisymmetric" => [
        "src/adapters/composable_cross_family_screen_v1.jl",
        "src/search/composable_cross_family_qd_v9.jl",
    ],
    "inertial_confinement_fusion" => [
        "src/adapters/laser_icf_screen_v1.jl",
        "src/search/laser_icf_qd_v15.jl",
    ],
)

_v42_dict(raw) = Dict{String,Any}(String(key) => _plain_json(value)
    for (key, value) in raw)

function _v42_route_class(v40::AbstractDict,
        v41_by_module::Dict{String,Dict{String,Any}})
    module_id = String(v40["module_id"])
    haskey(v41_by_module, module_id) && return String(v41_by_module[module_id][
        "dependency_closed_route_classification"])
    return String(v40["controlled_route_classification"])
end

_v42_is_alias(route::String) = occursin("alias", route)

function _v42_recommended_action(module_id::String, family::String,
        route::String)
    !_v42_is_alias(route) && return "existing_observed_route_hold"
    module_id in _V42_REUSE_MODULES && return "reuse_existing_candidate_formula"
    family == "inertial_confinement_fusion" &&
        return "quantitative_evidence_missing_keep_unknown"
    return "candidate_specific_solver_required"
end

function _v42_evidence_summary(family::String, source_ids::Vector{String},
        evidence_entries::Vector{Dict{String,Any}})
    family_entries = [item for item in evidence_entries if family in
        String.(get(item, "family", Any[]))]
    matched = [item for item in family_entries if !isempty(intersect(
        Set(source_ids), Set(String.(get(item, "source_ids", Any[])))))]
    histogram = Dict{String,Int}()
    for item in matched
        status = String(get(item, "evidence_provenance", "unspecified"))
        histogram[status] = get(histogram, status, 0) + 1
    end
    return Dict{String,Any}(
        "matched_record_count" => length(matched),
        "matched_record_ids" => sort!(String[String(item["id"]) for item in matched]),
        "provenance_histogram" => histogram,
        "family_missing_record_count" => count(item ->
            String(get(item, "value_kind", "")) == "missing", family_entries),
        "candidate_specific_promotion_record_count" => count(item ->
            get(item, "promotion_credit", false) === true, matched),
    )
end

function _v42_module_audit(v40_modules_raw::AbstractVector,
        v41_modules_raw::AbstractVector, evidence_entries_raw::AbstractVector)
    v40_modules = [_v42_dict(item) for item in v40_modules_raw]
    v41_modules = [_v42_dict(item) for item in v41_modules_raw]
    evidence_entries = [_v42_dict(item) for item in evidence_entries_raw]
    length(v40_modules) == 50 || throw(ArgumentError(
        "v42 requires the fifty sealed v40 target modules"))
    length(v41_modules) == 23 || throw(ArgumentError(
        "v42 requires the twenty-three sealed v41 dependency-closed modules"))
    v41_by_module = Dict(String(item["module_id"]) => item
        for item in v41_modules)
    records = Dict{String,Any}[]
    for item in sort!(v40_modules; by = item -> (
            String(item["family"]), String(item["layer"]),
            String(item["module_id"])))
        family = String(item["family"])
        module_id = String(item["module_id"])
        route = _v42_route_class(item, v41_by_module)
        action = _v42_recommended_action(module_id, family, route)
        source_ids = sort!(String.(item["source_ids"]))
        push!(records, Dict{String,Any}(
            "family" => family,
            "layer" => String(item["layer"]),
            "module_id" => module_id,
            "source_route_classification" => route,
            "source_alias" => _v42_is_alias(route),
            "source_ids" => source_ids,
            "required_evaluators" => sort!(String.(item["required_evaluators"])),
            "reusable_formula_owner_paths" => copy(get(_V42_FORMULA_OWNERS,
                family, String[])),
            "candidate_input_availability" => action ==
                "reuse_existing_candidate_formula" ? "available_and_wired_v42" :
                action == "existing_observed_route_hold" ?
                    "available_in_existing_route" : "insufficient_for_module_identity",
            "recommended_action" => action,
            "quantitative_evidence" => _v42_evidence_summary(family,
                source_ids, evidence_entries),
            "new_gate_credit_authorized" => false,
            "medium_fidelity_authorized" => false,
            "promotion_credit" => 0,
        ))
    end
    return records
end

function _v42_mirror_common(context::RecoverableCrossTopologyContextV20,
        assembly::TopologyAssemblyV17, values_u::Vector{Float64};
        exhaust_extra_build::Union{Nothing,Float64} = nothing,
        force_minimum_b::Bool = false)
    mechanism = !force_minimum_b &&
            assembly.module_ids[3] == "mirror_vortex_bias" ?
        "centrifugal_exb_shear" : "minimum_b_beam_plug"
    spec = ComposableTopologySpecV9("magnetic_mirror", mechanism,
        "two_end_expander", 2)
    key = _ccv9_key(spec)
    values = _ccv9_ranges(spec, values_u[1:12])
    exhaust_extra_build === nothing ||
        (values["screen_exhaust_extra_build"] = exhaust_extra_build)
    genome = _ccv9_instantiate(context.compiler_context.v9_bases[key],
        values, context.compiler_context.outer)
    return genome, spec, values
end

function _v42_simple_direct_converter_result(
        context::RecoverableCrossTopologyContextV20, genome::Genome,
        values_u::Vector{Float64})
    recovery_fraction = 0.05 + 0.45values_u[15]
    converter_voltage = 100.0e3 + 900.0e3values_u[16]
    converter_build = 0.05 + 0.25values_u[17]
    raw = deepcopy(genome.normalized)
    raw["exhaust"]["kind"] =
        "two_end_expanders_with_direct_converter_to_finite_targets"
    basis = "exact v10 direct-converter candidate-gene reuse in v42"
    for (name, value, unit) in (
            ("screen_direct_converter_recovery_fraction", recovery_fraction, "1"),
            ("screen_direct_converter_voltage", converter_voltage, "V"),
            ("screen_direct_converter_build", converter_build, "m"))
        _ctv4_set_target!(raw, name, value, unit; basis = basis)
    end
    raw["design_id"] = "pending_v42_simple_mirror_direct_converter"
    provisional = parse_genome(raw)
    raw["design_id"] = "v42_$(provisional.physics_hash[1:20])"
    candidate = parse_genome(raw)
    result = deepcopy(_composable_cross_family_result(
        ComposableCrossFamilyScreenV1(context.compiler_context.outer), candidate))
    nominal = result["nominal"]
    margins = nominal["margins"]
    charged_end_loss = 0.65Float64(nominal["transport_loss_power_W"])
    recovered_electric = recovery_fraction * charged_end_loss
    nominal["net_electric_power_W"] =
        Float64(nominal["net_electric_power_W"]) + recovered_electric
    nominal["charged_end_loss_power_W"] = charged_end_loss
    nominal["direct_converter_recovered_electric_power_W"] = recovered_electric
    nominal["direct_converter_recovery_fraction"] = recovery_fraction
    base = context.compiler_context.outer.base
    margins["net_electric_power"] = nominal["net_electric_power_W"] /
        max(base.fixed_balance_of_plant_load_W, 1.0)
    grid_field = converter_voltage / max(converter_build, 1.0e-6)
    margins["direct_converter_recovery_domain"] = min(
        recovery_fraction / 0.50, (0.50 - recovery_fraction) / 0.25)
    margins["direct_converter_grid_field"] = (20.0e6 - grid_field) / 20.0e6
    margins["direct_converter_energy_conservation"] =
        (charged_end_loss - recovered_electric) / max(charged_end_loss, 1.0)
    nominal["engineering_gate_passed"] =
        nominal["engineering_gate_passed"] === true && all(
            margins[id] >= 0.0 for id in (
                "direct_converter_recovery_domain",
                "direct_converter_grid_field",
                "direct_converter_energy_conservation"))
    nominal["minimum_normalized_margin"] = minimum(Base.values(margins))
    result["gates"]["minimal_engineering_closure"] =
        nominal["engineering_gate_passed"]
    result["gates"]["cheap_robustness_screen"] = false
    result["all_five_gates_passed"] = false
    result["classification"] =
        "v42_formula_observable_pending_direct_converter_robustness_and_evidence"
    result["claim_boundary"] = _V42_CLAIM_BOUNDARY
    result["result_hash"] = canonical_hash(result)
    return candidate, result,
        "simple_mirror_v9_plus_exact_v10_direct_converter_ledger"
end

function _v42_mirror_projection(context::RecoverableCrossTopologyContextV20,
        assembly::TopologyAssemblyV17, values_u::Vector{Float64})
    field = assembly.module_ids[2]
    exhaust = assembly.module_ids[4]
    tandem = field == "mirror_tandem_plugs"
    gas_dynamic = exhaust == "mirror_gas_dynamic_targets"
    direct = exhaust == "mirror_direct_converter"
    if gas_dynamic
        spec = OpenLossPathwayTopologySpecV11("magnetic_mirror",
            "gas_dynamic_single_cell", "two_end_expander", 2)
        common, _, _ = _v42_mirror_common(context, assembly, values_u;
            force_minimum_b = true)
        base = _olv11_build_gdt(common, spec)
        values = _olv11_ranges(spec, values_u)
        genome = _olv11_instantiate(base, spec, values,
            context.compiler_context.outer)
        result = _open_loss_pathway_result(OpenLossPathwayScreenV1(
            context.compiler_context.outer), genome)
        return genome, result, "gas_dynamic_single_cell_v11"
    elseif tandem
        spec = MechanismExpansionTopologySpecV10("magnetic_mirror",
            "thermal_electrostatic_barrier", direct ?
                "two_end_direct_converter" : "two_end_expander", 2)
        common, _, _ = _v42_mirror_common(context, assembly, values_u)
        base = _mev10_build_tandem!(deepcopy(common.normalized), spec)
        values = _mev10_ranges(spec, values_u)
        genome = _mev10_instantiate(base, spec, values,
            context.compiler_context.outer)
        result = _mechanism_expansion_result(MechanismExpansionScreenV1(
            context.compiler_context.outer), genome)
        return genome, result, direct ?
            "thermal_barrier_tandem_direct_converter_v10" :
            "thermal_barrier_tandem_expander_v10"
    elseif direct
        genome, _, _ = _v42_mirror_common(context, assembly, values_u;
            exhaust_extra_build = 0.80)
        return _v42_simple_direct_converter_result(context, genome, values_u)
    end
    genome, _, _ = _v42_mirror_common(context, assembly, values_u)
    result = _composable_cross_family_result(ComposableCrossFamilyScreenV1(
        context.compiler_context.outer), genome)
    return genome, result, "simple_open_mirror_v9"
end

function _v42_rfp_projection(context::RecoverableCrossTopologyContextV20,
        assembly::TopologyAssemblyV17, values_u::Vector{Float64})
    field, stability = assembly.module_ids[2], assembly.module_ids[3]
    mechanism = stability == "rfp_boundary_control" ?
        "qsh_ppcd_boundary_mode_control" :
        stability == "rfp_ppcd_profile" ?
            "qsh_pulsed_poloidal_current_drive" :
        field == "rfp_ppcd" ? "qsh_pulsed_poloidal_current_drive" :
        field == "rfp_saddle_control" ? "boundary_feedback_only" :
            "self_organized_qsh"
    registered = mechanism == "boundary_feedback_only" ?
        "qsh_ppcd_boundary_mode_control" : mechanism
    count = _v18_nearest_target_count(_v18_target_count(assembly))
    spec = ProfileCoupledRFPTopologySpecV8(registered, count)
    base = _pcrfp_structural_base_v8(
        context.compiler_context.tokamak_parent, spec)
    values = _pcrfp_ranges_v8(spec, values_u)
    if mechanism == "boundary_feedback_only"
        values["screen_current_profile_control"] = 0.0
        values["screen_ppcd_power"] = 0.0
    end
    genome = _pcrfp_instantiate_v8(base, values,
        context.compiler_context.outer)
    if mechanism == "boundary_feedback_only"
        raw = deepcopy(genome.normalized)
        filter!(item -> String(item["id"]) != "rfp_ppcd", raw["actuators"])
        for item in raw["stability_mechanisms"]
            filter!(id -> String(id) != "rfp_ppcd", item["actuator_ids"])
        end
        raw["design_id"] = "pending_v42_boundary_feedback_only"
        provisional = parse_genome(raw)
        raw["design_id"] = "v42_$(provisional.physics_hash[1:20])"
        genome = parse_genome(raw)
    end
    result = _profile_coupled_rfp_result(ProfileCoupledRFPScreenV1(
        context.compiler_context.outer), genome)
    return genome, result, "rfp_$(mechanism)_v42_from_v7_v8"
end

function _v42_response(context::RecoverableCrossTopologyContextV20,
        assembly::TopologyAssemblyV17, sample_ordinal::Int;
        halton_skip::Int = 4096)
    values_u = _v20_unit_vector(sample_ordinal, length(_V20_HALTON_PRIMES);
        skip = halton_skip)
    genome, raw, projection_id = assembly.family == "magnetic_mirror" ?
        _v42_mirror_projection(context, assembly, values_u) :
        assembly.family == "reversed_field_pinch" ?
            _v42_rfp_projection(context, assembly, values_u) :
            throw(ArgumentError("v42 has no formula-reuse projection for " *
                assembly.family))
    margins = Dict{String,Float64}(String(name) => Float64(value)
        for (name, value) in raw["nominal"]["margins"])
    gates = Dict{String,Bool}(String(name) => Bool(value)
        for (name, value) in raw["gates"])
    declared = _v20_declared_requirements(context, assembly)
    by_requirement = Dict(item.requirement => item.support for item in
        coverage_report(context.evaluator_registry, genome))
    missing = sort!(String[item for item in declared if
        get(by_requirement, item, :missing) == :missing])
    core = Dict("named_margins" => margins, "raw_gates" => gates)
    return Dict{String,Any}(
        "family" => assembly.family,
        "graph_hash" => assembly.graph_hash,
        "module_ids" => copy(assembly.module_ids),
        "sample_ordinal" => sample_ordinal,
        "physics_hash" => genome.physics_hash,
        "projection_id" => projection_id,
        "named_margins" => margins,
        "named_margin_count" => length(margins),
        "raw_gates" => gates,
        "raw_gate_pass_count" => count(Base.values(gates)),
        "missing_proxy_requirements" => missing,
        "missing_proxy_requirement_count" => length(missing),
        "topology_graph_errors" => String.(get(raw,
            "topology_graph_errors", Any[])),
        "full_evaluated_response_signature_hash" => canonical_hash(core),
        "full_margin_signature_hash" => canonical_hash(margins),
        "raw_gate_signature_hash" => canonical_hash(gates),
        "evidence_gap_signature_hash" => canonical_hash(missing),
        "raw_result_hash" => String(raw["result_hash"]),
        "proxy_five_gate_passed" => raw["all_five_gates_passed"] === true,
        "proxy_coverage_complete" => isempty(missing),
        "candidate_specific_formula_inputs_wired" => true,
        "new_empirical_performance_multiplier_used" => false,
        "gate_credit_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promoted" => false,
        "claim_level" => "C0_candidate_specific_formula_observability_only",
    )
end

function _v42_trial_record(source_version::String, source::AbstractDict,
        first_response::AbstractDict, second_response::AbstractDict)
    changed_margins = _v40_changed_numeric_keys(
        first_response["named_margins"], second_response["named_margins"])
    changed_gates = _v40_changed_boolean_keys(
        first_response["raw_gates"], second_response["raw_gates"])
    first_missing = Set(String.(first_response["missing_proxy_requirements"]))
    second_missing = Set(String.(second_response["missing_proxy_requirements"]))
    changed_requirements = sort!(collect(union(
        setdiff(first_missing, second_missing),
        setdiff(second_missing, first_missing))))
    response_changed = first_response[
        "full_evaluated_response_signature_hash"] != second_response[
        "full_evaluated_response_signature_hash"]
    evidence_changed = first_response["evidence_gap_signature_hash"] !=
        second_response["evidence_gap_signature_hash"]
    core = Dict{String,Any}(
        "source_version" => source_version,
        "family" => String(source["family"]),
        "layer" => String(get(source, "layer",
            get(source, "intervened_layer", ""))),
        "first_module_id" => String(source["first_module_id"]),
        "second_module_id" => String(source["second_module_id"]),
        "first_graph_hash" => String(first_response["graph_hash"]),
        "second_graph_hash" => String(second_response["graph_hash"]),
        "sample_ordinal" => Int(source["sample_ordinal"]),
        "first_response_signature_hash" => String(first_response[
            "full_evaluated_response_signature_hash"]),
        "second_response_signature_hash" => String(second_response[
            "full_evaluated_response_signature_hash"]))
    item = merge(core, Dict{String,Any}(
        "source_trial_hash" => String(source["trial_hash"]),
        "source_response_classification" => String(source[
            "response_classification"]),
        "changed_named_margin_ids" => changed_margins,
        "changed_named_margin_count" => length(changed_margins),
        "changed_raw_gate_ids" => changed_gates,
        "changed_raw_gate_count" => length(changed_gates),
        "changed_evidence_requirement_ids" => changed_requirements,
        "changed_evidence_requirement_count" => length(changed_requirements),
        "formula_observable_response_change" => response_changed,
        "evidence_gap_ledger_change" => evidence_changed,
        "v42_response_classification" => response_changed ?
            "candidate_specific_formula_response_variation" :
            evidence_changed ? "evidence_variation_only" :
                "remaining_formula_and_evidence_alias",
        "single_module_absolute_physical_causality_proven" => false,
        "gate_credit_authorized" => false,
        "medium_fidelity_authorized" => false,
        "old_domain_scale_up_authorized" => false,
        "promoted" => false))
    item["trial_hash"] = canonical_hash(core)
    return item
end

function candidate_specific_formula_reuse_v42(
        context::RecoverableCrossTopologyContextV20,
        v40_modules_raw::AbstractVector, v40_trials_raw::AbstractVector,
        v41_modules_raw::AbstractVector, v41_trials_raw::AbstractVector,
        evidence_entries_raw::AbstractVector; halton_skip::Integer = 4096)
    module_audit = _v42_module_audit(v40_modules_raw, v41_modules_raw,
        evidence_entries_raw)
    v40_trials = [_v42_dict(item) for item in v40_trials_raw]
    v41_trials = [_v42_dict(item) for item in v41_trials_raw]
    assembly_by_graph = Dict(item.graph_hash => item for item in
        context.assemblies)
    selected = Tuple{String,Dict{String,Any},String,String}[]
    for item in v40_trials
        item["family"] == "magnetic_mirror" || continue
        item["response_classification"] ==
            "full_evaluated_and_evidence_alias" || continue
        push!(selected, ("v40", item, String(item["first_graph_hash"]),
            String(item["second_graph_hash"])))
    end
    for item in v41_trials
        item["family"] == "reversed_field_pinch" || continue
        item["intervened_layer"] == "field_source" || continue
        item["response_classification"] ==
            "full_evaluated_and_evidence_alias" || continue
        push!(selected, ("v41", item,
            String(item["first_dependency_closed_graph_hash"]),
            String(item["second_dependency_closed_graph_hash"])))
    end
    length(selected) == 15 || error("v42 targeted alias trial count changed")
    responses = Dict{String,Dict{String,Any}}()
    trials = Dict{String,Any}[]
    for (source_version, source, first_hash, second_hash) in selected
        first_key = canonical_hash(Dict("graph_hash" => first_hash,
            "sample_ordinal" => source["sample_ordinal"]))
        second_key = canonical_hash(Dict("graph_hash" => second_hash,
            "sample_ordinal" => source["sample_ordinal"]))
        if !haskey(responses, first_key)
            responses[first_key] = _v42_response(context,
                assembly_by_graph[first_hash], Int(source["sample_ordinal"]);
                halton_skip = Int(halton_skip))
            responses[first_key]["response_key"] = first_key
        end
        if !haskey(responses, second_key)
            responses[second_key] = _v42_response(context,
                assembly_by_graph[second_hash], Int(source["sample_ordinal"]);
                halton_skip = Int(halton_skip))
            responses[second_key]["response_key"] = second_key
        end
        push!(trials, _v42_trial_record(source_version, source,
            responses[first_key], responses[second_key]))
    end
    sort!(trials; by = item -> (String(item["family"]),
        String(item["layer"]), String(item["first_graph_hash"])))
    response_records = sort!(collect(Base.values(responses)); by = item ->
        String(item["response_key"]))
    observable_modules = Set{String}()
    for item in trials
        item["formula_observable_response_change"] === true || continue
        push!(observable_modules, String(item["first_module_id"]))
        push!(observable_modules, String(item["second_module_id"]))
    end
    action_counts = Dict(action => count(item ->
        item["recommended_action"] == action, module_audit) for action in (
            "reuse_existing_candidate_formula",
            "known_device_anchor_only",
            "candidate_specific_solver_required",
            "quantitative_evidence_missing_keep_unknown",
            "existing_observed_route_hold"))
    filter!(pair -> pair.second > 0, action_counts)
    source_alias_count = count(item -> item["source_alias"] === true,
        module_audit)
    aggregate = Dict{String,Any}(
        "audited_module_count" => length(module_audit),
        "source_alias_module_count" => source_alias_count,
        "source_observed_route_module_count" => length(module_audit) -
            source_alias_count,
        "recommended_action_counts" => action_counts,
        "formula_reuse_target_module_count" => length(_V42_REUSE_MODULES),
        "formula_observable_module_count" => length(observable_modules),
        "formula_observable_module_ids" => sort!(collect(observable_modules)),
        "remaining_alias_module_count" => source_alias_count -
            length(observable_modules),
        "observed_route_module_count_after_v42" => length(module_audit) -
            source_alias_count + length(observable_modules),
        "targeted_alias_trial_count" => length(trials),
        "formula_response_variation_trial_count" => count(item ->
            item["formula_observable_response_change"] === true, trials),
        "remaining_formula_alias_trial_count" => count(item ->
            item["v42_response_classification"] ==
                "remaining_formula_and_evidence_alias", trials),
        "raw_gate_variation_trial_count" => count(item ->
            item["changed_raw_gate_count"] > 0, trials),
        "unique_response_count" => length(response_records),
        "topology_graph_error_response_count" => count(item ->
            !isempty(item["topology_graph_errors"]), response_records),
        "proxy_five_gate_passed_response_count" => count(item ->
            item["proxy_five_gate_passed"] === true, response_records),
        "proxy_coverage_complete_response_count" => count(item ->
            item["proxy_coverage_complete"] === true, response_records),
        "new_empirical_performance_multiplier_used" => false,
        "new_physics_constant_introduced" => false,
        "existing_candidate_formula_composition_implemented" => true,
        "gate_credit_authorized_count" => 0,
        "medium_fidelity_authorized_count" => 0,
        "old_domain_scale_up_authorized" => false,
        "promotion_count" => 0,
    )
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "search_version" => "candidate_specific_formula_reuse_v42",
        "stage" => "sealed_cross_family_candidate_formula_reuse_audit",
        "audit_scope" => Dict{String,Any}(
            "source_module_count" => 50,
            "source_alias_module_count" => 33,
            "target_families" => ["magnetic_mirror", "reversed_field_pinch"],
            "paired_halton_sample_fixed" => true,
            "all_fifty_modules_classified" => true,
            "existing_formula_reuse_only" => true,
            "constant_performance_bonus_allowed" => false),
        "aggregate" => aggregate,
        "module_audit_records" => module_audit,
        "trial_records" => trials,
        "response_records" => response_records,
        "promotion_credit" => Dict{String,Any}(
            "single_module_absolute_physical_causality_claimed" => false,
            "physical_infeasibility_claimed" => false,
            "gate_credit_authorized_count" => 0,
            "medium_fidelity_authorized_count" => 0,
            "old_domain_scale_up_authorized" => false,
            "promotion_count" => 0,
            "physics_evidence_level_change" => 0,
            "engineering_evidence_level_change" => 0),
        "claim_boundary" => _V42_CLAIM_BOUNDARY,
    )
end
