const _V39_CLAIM_BOUNDARY =
    "V39 applies a versioned evidence-routing overlay to the eleven v37 tier-2 power/exhaust and tier-3 engineering/maintenance modules not covered by v38. It replays all thirteen remaining sealed fixed-background graph pairs and adds candidate-specific requirements as explicit hard unknowns. It executes no solver, changes no numerical named margin or raw gate, chooses no favorable sign, and grants no physical, engineering, robustness, C1, medium-fidelity, family-ranking, old-domain scale-up, or promotion credit. Evidence-route differentiation is an interface repair, not proof of a physical or engineering module effect."

_v39_strings(value) = sort!(unique(String.(copy(value))))

function _v39_dict(raw)
    return Dict{String,Any}(String(key) => _plain_json(value)
        for (key, value) in raw)
end

function _v39_source_record(source)
    record = _v39_dict(source)
    boundary = haskey(record, "claim_boundary") ?
        String(record["claim_boundary"]) :
        haskey(record, "limitation") ? String(record["limitation"]) :
        error("v39 source record lacks a claim boundary or limitation")
    return Dict{String,Any}(
        "id" => String(record["id"]),
        "title" => String(record["title"]),
        "url" => String(record["url"]),
        "year" => get(record, "year", nothing),
        "family" => _v39_strings(get(record, "family", String[])),
        "kind" => get(record, "kind", "candidate_specific_route_source"),
        "evidence_level" => get(record, "evidence_level",
            "primary_source_route_constraint"),
        "claim_boundary" => boundary)
end

function apply_remaining_module_evidence_overlay_v39(response_raw,
        overlay_by_module::AbstractDict)
    response = _v39_dict(response_raw)
    routed_modules = [id for id in _v39_strings(response["module_ids"])
        if haskey(overlay_by_module, id)]
    route_implemented = !isempty(routed_modules)
    route_implemented || error(
        "v39 response contains no remaining routed module")
    route_bindings = [Dict{String,Any}(
        "module_id" => module_id,
        "hard_unknown_requirements" => _v39_strings(
            overlay_by_module[module_id][
                "module_specific_hard_unknown_requirements"]))
        for module_id in routed_modules]
    all(!isempty(binding["hard_unknown_requirements"])
        for binding in route_bindings) || error(
        "v39 module-specific requirement list cannot be empty")
    additional = sort!(unique(String(requirement)
        for binding in route_bindings
        for requirement in binding["hard_unknown_requirements"]))
    base_missing = _v39_strings(response["missing_proxy_requirements"])
    effective_missing = sort!(unique(vcat(base_missing, additional)))
    length(effective_missing) <= length(base_missing) &&
        error("v39 overlay did not add a candidate-specific hard unknown")

    archived_named_margin_hash = canonical_hash(response["named_margins"])
    sealed_named_margin_hash = String(response["full_margin_signature_hash"])
    archived_named_margin_match = archived_named_margin_hash ==
        sealed_named_margin_hash
    raw_gate_hash = canonical_hash(response["raw_gates"])
    raw_gate_hash == response["raw_gate_signature_hash"] || error(
        "v39 v36 raw-gate signature drifted")
    module_signature = canonical_hash(route_bindings)
    source_ids = sort!(unique(String(id) for module_id in routed_modules
        for id in overlay_by_module[module_id]["source_ids"]))
    target_named_margin_ids = sort!(unique(String(id)
        for module_id in routed_modules
        for id in overlay_by_module[module_id]["target_named_margin_ids"]))
    group_ids = sort!(unique(String(overlay_by_module[module_id]["group_id"])
        for module_id in routed_modules))
    priority_tiers = sort!(unique(String(
        overlay_by_module[module_id]["priority_tier"])
        for module_id in routed_modules))
    source_support_status_by_module = Dict{String,Any}(module_id => String(
        overlay_by_module[module_id]["source_support_status"])
        for module_id in routed_modules)
    return Dict{String,Any}(
        "candidate_index" => Int(response["candidate_index"]),
        "family" => String(response["family"]),
        "graph_hash" => String(response["graph_hash"]),
        "physics_hash" => String(response["physics_hash"]),
        "routed_module_ids" => routed_modules,
        "routed_module_count" => length(routed_modules),
        "group_ids" => group_ids,
        "priority_tiers" => priority_tiers,
        "source_ids" => source_ids,
        "source_support_status_by_module" =>
            source_support_status_by_module,
        "target_named_margin_ids" => target_named_margin_ids,
        "base_missing_proxy_requirements" => base_missing,
        "base_missing_proxy_requirement_count" => length(base_missing),
        "module_specific_hard_unknown_requirements" => additional,
        "module_specific_hard_unknown_requirement_count" =>
            length(additional),
        "effective_missing_proxy_requirements" => effective_missing,
        "effective_missing_proxy_requirement_count" =>
            length(effective_missing),
        "module_specific_evidence_signature_hash" => module_signature,
        "effective_evidence_gap_signature_hash" =>
            canonical_hash(effective_missing),
        "v36_named_margin_signature_hash" => sealed_named_margin_hash,
        "archived_named_margin_recomputed_signature_hash" =>
            archived_named_margin_hash,
        "archived_named_margin_signature_recomputed_match" =>
            archived_named_margin_match,
        "archived_named_margin_signature_note" =>
            archived_named_margin_match ?
                "archived numeric representation preserves the v36 signature" :
                "JSON signed-zero normalization prevents archived-vector signature reproduction; the sealed v36 signature remains authoritative",
        "v36_raw_gate_signature_hash" => raw_gate_hash,
        "numeric_named_margins_changed" => false,
        "raw_gates_changed" => false,
        "hard_unknown_evidence_route_implemented" => route_implemented,
        "solver_executed" => false,
        "formula_implemented" => false,
        "direct_gate_credit_authorized" => false,
        "old_domain_scale_up_authorized" => false,
        "promoted" => false,
        "claim_level" => "C0_module_specific_hard_unknown_routing_only")
end

function remaining_module_evidence_ablation_v39(overlay_raw,
        v37_module_contracts_raw::AbstractVector,
        v37_ablation_cases_raw::AbstractVector,
        v36_responses_raw::AbstractVector, source_records_raw::AbstractVector)
    overlay = _v39_dict(overlay_raw)
    overlay["overlay_version"] == "remaining_module_evidence_overlay_v39" ||
        throw(ArgumentError("v39 overlay version changed"))
    overlay["sealed_v37_result_hash"] ==
        "d212d5a4514a7af0ff80e97614aaac0000063fee654f0f7f3b1e73471240c159" ||
        throw(ArgumentError("v39 sealed v37 result hash changed"))
    overlay["sealed_v38_result_hash"] ==
        "1f79ce865486863b4325be09301e604c9bf09fc22f2eba2e96f350189751b6bd" ||
        throw(ArgumentError("v39 sealed v38 result hash changed"))
    contracts = [_v39_dict(item) for item in v37_module_contracts_raw]
    cases = [_v39_dict(item) for item in v37_ablation_cases_raw]
    responses = [_v39_dict(item) for item in v36_responses_raw]
    length(contracts) == 18 || throw(ArgumentError(
        "v39 requires the 18 v37 module contracts"))
    length(cases) == 21 || throw(ArgumentError(
        "v39 requires the 21 v37 ablation cases"))
    length(responses) == 55 || throw(ArgumentError(
        "v39 requires the 55 v36 responses"))

    remaining_contracts = [item for item in contracts if
        item["priority_tier"] != "tier_1_physics_decision_surface"]
    length(remaining_contracts) == 11 || error(
        "v39 remaining v37 module count changed")
    contract_by_module = Dict(String(item["module_id"]) => item
        for item in remaining_contracts)
    overlay_modules = [_v39_dict(item) for item in overlay["modules"]]
    length(overlay_modules) == 11 || throw(ArgumentError(
        "v39 requires eleven module overlays"))
    overlay_by_module = Dict(String(item["module_id"]) => item
        for item in overlay_modules)
    length(overlay_by_module) == 11 || error(
        "v39 overlay contains duplicate module IDs")
    sort!(collect(keys(overlay_by_module))) ==
        sort!(collect(keys(contract_by_module))) || error(
        "v39 overlay modules do not equal the remaining v37 set")
    for (module_id, item) in overlay_by_module
        contract = contract_by_module[module_id]
        String(item["group_id"]) == String(contract["group_id"]) || error(
            "v39 overlay group drifted for $module_id")
        String(item["priority_tier"]) ==
            String(contract["priority_tier"]) || error(
            "v39 overlay priority tier drifted for $module_id")
        target_margins = Set(_v39_strings(item["target_named_margin_ids"]))
        issubset(target_margins,
            Set(_v39_strings(contract["target_named_margin_ids"]))) || error(
            "v39 overlay target margins exceed the v37 contract")
    end

    source_index = Dict{String,Any}()
    for raw in source_records_raw
        item = _v39_source_record(raw)
        id = String(item["id"])
        haskey(source_index, id) && error(
            "v39 duplicate source ID $id")
        source_index[id] = item
    end
    used_source_ids = sort!(unique(String(id) for item in overlay_modules
        for id in item["source_ids"]))
    all(haskey(source_index, id) for id in used_source_ids) || error(
        "v39 overlay source trace is incomplete")
    source_ledger = [source_index[id] for id in used_source_ids]

    response_by_graph = Dict(String(item["graph_hash"]) => item
        for item in responses)
    length(response_by_graph) == 55 || error(
        "v39 response graph hashes are not unique")
    remaining_ids = Set(keys(overlay_by_module))
    remaining_cases = [item for item in cases if any(id in remaining_ids
        for id in _v39_strings(item["module_ids"]))]
    length(remaining_cases) == 13 || error(
        "v39 remaining fixed-background case count changed")

    graph_responses = Dict{String,Any}()
    case_results = Dict{String,Any}[]
    for case in sort!(remaining_cases; by = item -> (
            String(item["family"]), String(item["v35_pair_hash"])))
        first_hash = String(case["first_graph_hash"])
        second_hash = String(case["second_graph_hash"])
        haskey(response_by_graph, first_hash) &&
            haskey(response_by_graph, second_hash) || error(
            "v39 case references an unknown v36 graph")
        first_response = apply_remaining_module_evidence_overlay_v39(
            response_by_graph[first_hash], overlay_by_module)
        second_response = apply_remaining_module_evidence_overlay_v39(
            response_by_graph[second_hash], overlay_by_module)
        first_response["family"] == second_response["family"] ==
            String(case["family"]) || error(
            "v39 matched case family drifted")
        first_routed_modules = _v39_strings(
            first_response["routed_module_ids"])
        second_routed_modules = _v39_strings(
            second_response["routed_module_ids"])
        routed_modules = sort!(collect(union(
            setdiff(Set(first_routed_modules), Set(second_routed_modules)),
            setdiff(Set(second_routed_modules), Set(first_routed_modules)))))
        routed_modules == _v39_strings(case["module_ids"]) || error(
            "v39 case contracted-module identity drifted")
        route_differentiated = first_response[
            "module_specific_evidence_signature_hash"] != second_response[
            "module_specific_evidence_signature_hash"]
        effective_ledger_differentiated = first_response[
            "effective_evidence_gap_signature_hash"] != second_response[
            "effective_evidence_gap_signature_hash"]
        margins_unchanged = first_response[
            "numeric_named_margins_changed"] === false && second_response[
            "numeric_named_margins_changed"] === false
        gates_unchanged = first_response["raw_gates_changed"] === false &&
            second_response["raw_gates_changed"] === false
        routed_hard_unknown_present = Int(first_response[
            "module_specific_hard_unknown_requirement_count"]) > 0 ||
            Int(second_response[
                "module_specific_hard_unknown_requirement_count"]) > 0
        base_hard_unknowns_on_both_sides = Int(first_response[
            "base_missing_proxy_requirement_count"]) > 0 && Int(
            second_response["base_missing_proxy_requirement_count"]) > 0
        accepted = route_differentiated && effective_ledger_differentiated &&
            margins_unchanged && gates_unchanged &&
            routed_hard_unknown_present && base_hard_unknowns_on_both_sides
        accepted || error(
            "v39 fixed-background hard-unknown ablation did not pass")
        graph_responses[first_hash] = first_response
        graph_responses[second_hash] = second_response
        push!(case_results, Dict{String,Any}(
            "v35_pair_hash" => String(case["v35_pair_hash"]),
            "family" => String(case["family"]),
            "first_graph_hash" => first_hash,
            "second_graph_hash" => second_hash,
            "first_routed_module_ids" => first_routed_modules,
            "second_routed_module_ids" => second_routed_modules,
            "contracted_module_ids" => routed_modules,
            "first_module_specific_evidence_signature_hash" =>
                first_response["module_specific_evidence_signature_hash"],
            "second_module_specific_evidence_signature_hash" =>
                second_response["module_specific_evidence_signature_hash"],
            "first_effective_evidence_gap_signature_hash" =>
                first_response["effective_evidence_gap_signature_hash"],
            "second_effective_evidence_gap_signature_hash" =>
                second_response["effective_evidence_gap_signature_hash"],
            "module_specific_evidence_differentiated" =>
                route_differentiated,
            "effective_evidence_ledger_differentiated" =>
                effective_ledger_differentiated,
            "numeric_named_margins_unchanged" => margins_unchanged,
            "raw_gates_unchanged" => gates_unchanged,
            "routed_hard_unknown_present" => routed_hard_unknown_present,
            "base_hard_unknowns_present_on_both_sides" =>
                base_hard_unknowns_on_both_sides,
            "fixed_background_ablation_accepted" => accepted,
            "single_module_physical_causality_proven" => false,
            "formula_implemented" => false,
            "direct_gate_credit_authorized" => false,
            "old_domain_scale_up_authorized" => false,
            "promoted" => false))
    end
    graph_response_records = collect(values(graph_responses))
    sort!(graph_response_records; by = item -> (String(item["family"]),
        String(item["graph_hash"])))

    module_results = Dict{String,Any}[]
    for module_id in sort!(collect(keys(overlay_by_module)))
        item = overlay_by_module[module_id]
        module_cases = [case for case in case_results if
            module_id in case["contracted_module_ids"]]
        isempty(module_cases) && error(
            "v39 remaining module has no matched case")
        all(case["fixed_background_ablation_accepted"] === true
            for case in module_cases) || error(
            "v39 remaining module has an unaccepted case")
        push!(module_results, Dict{String,Any}(
            "module_id" => module_id,
            "group_id" => String(item["group_id"]),
            "priority_tier" => String(item["priority_tier"]),
            "source_ids" => _v39_strings(item["source_ids"]),
            "source_support_status" => String(
                item["source_support_status"]),
            "target_named_margin_ids" => _v39_strings(
                item["target_named_margin_ids"]),
            "module_specific_hard_unknown_requirements" => _v39_strings(
                item["module_specific_hard_unknown_requirements"]),
            "matched_case_count" => length(module_cases),
            "accepted_matched_case_count" => count(case ->
                case["fixed_background_ablation_accepted"] === true,
                module_cases),
            "hard_unknown_evidence_route_implemented" => true,
            "numeric_formula_implemented" => false,
            "direct_gate_credit_authorized" => false,
            "old_domain_scale_up_authorized" => false,
            "single_module_physical_causality_proven" => false,
            "promotion_credit" => 0))
    end
    group_counts = _v33_count_strings(String[
        item["group_id"] for item in module_results])
    tier_counts = _v33_count_strings(String[
        item["priority_tier"] for item in module_results])
    requirement_ids = sort!(unique(String(id) for item in overlay_modules
        for id in item["module_specific_hard_unknown_requirements"]))
    return Dict{String,Any}(
        "remaining_group_count" => length(group_counts),
        "remaining_module_count" => length(module_results),
        "remaining_fixed_background_case_count" => length(case_results),
        "remaining_graph_response_count" => length(graph_response_records),
        "module_specific_hard_unknown_requirement_count" =>
            length(requirement_ids),
        "source_record_count" => length(source_ledger),
        "group_module_counts" => group_counts,
        "priority_tier_module_counts" => tier_counts,
        "evidence_differentiated_case_count" => count(item ->
            item["module_specific_evidence_differentiated"] === true &&
            item["effective_evidence_ledger_differentiated"] === true,
            case_results),
        "fixed_background_ablation_accepted_case_count" => count(item ->
            item["fixed_background_ablation_accepted"] === true,
            case_results),
        "evidence_route_connected_module_count" => count(item ->
            item["hard_unknown_evidence_route_implemented"] === true,
            module_results),
        "cumulative_v38_v39_connected_module_count" => 7 +
            length(module_results),
        "remaining_v37_matched_full_disconnect_module_count" => 18 - 7 -
            length(module_results),
        "numeric_named_margin_update_count" => 0,
        "raw_gate_update_count" => 0,
        "solver_execution_count" => 0,
        "formula_implementation_count" => 0,
        "direct_gate_credit_authorized_count" => 0,
        "old_domain_scale_up_authorized" => false,
        "single_module_physical_causality_claimed" => false,
        "promotion_count" => 0,
        "medium_fidelity_authorized_count" => 0,
        "module_results" => module_results,
        "case_results" => case_results,
        "graph_response_records" => graph_response_records,
        "source_ledger" => source_ledger,
        "acceptance_rule" => String(overlay["acceptance_rule"]),
        "claim_boundary" => _V39_CLAIM_BOUNDARY)
end
