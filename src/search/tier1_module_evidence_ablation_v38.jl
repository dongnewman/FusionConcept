const _V38_CLAIM_BOUNDARY =
    "V38 applies a versioned evidence-routing overlay to the seven v37 tier-1 physics modules and replays their eight sealed fixed-background graph pairs. The overlay adds module-specific candidate solver requirements as explicit hard unknowns. It executes no solver, changes no numerical named margin or raw gate, chooses no favorable sign, and grants no physical, robustness, C1, medium-fidelity, family-ranking, old-domain scale-up, or promotion credit. Evidence-route differentiation is an interface repair, not proof of a physical module effect."

_v38_strings(value) = sort!(unique(String.(copy(value))))

function _v38_dict(raw)
    return Dict{String,Any}(String(key) => _plain_json(value)
        for (key, value) in raw)
end

function _v38_source_record(source)
    record = _v38_dict(source)
    boundary = haskey(record, "claim_boundary") ?
        String(record["claim_boundary"]) :
        haskey(record, "limitation") ? String(record["limitation"]) :
        error("v38 source record lacks a claim boundary or limitation")
    return Dict{String,Any}(
        "id" => String(record["id"]),
        "title" => String(record["title"]),
        "url" => String(record["url"]),
        "year" => get(record, "year", nothing),
        "family" => _v38_strings(get(record, "family", String[])),
        "kind" => get(record, "kind", "candidate_specific_route_source"),
        "evidence_level" => get(record, "evidence_level",
            "primary_source_route_constraint"),
        "claim_boundary" => boundary)
end

function apply_tier1_module_evidence_overlay_v38(response_raw,
        overlay_by_module::AbstractDict)
    response = _v38_dict(response_raw)
    modules = [id for id in _v38_strings(response["module_ids"])
        if haskey(overlay_by_module, id)]
    length(modules) == 1 || error(
        "v38 tier-1 response must contain exactly one overlaid module")
    module_id = only(modules)
    overlay = overlay_by_module[module_id]
    additional = _v38_strings(
        overlay["module_specific_hard_unknown_requirements"])
    isempty(additional) && error(
        "v38 module-specific requirement list cannot be empty")
    base_missing = _v38_strings(response["missing_proxy_requirements"])
    effective_missing = sort!(unique(vcat(base_missing, additional)))
    length(effective_missing) > length(base_missing) || error(
        "v38 overlay did not add a candidate-specific hard unknown")
    archived_named_margin_hash = canonical_hash(response["named_margins"])
    sealed_named_margin_hash = String(
        response["full_margin_signature_hash"])
    archived_named_margin_match = archived_named_margin_hash ==
        sealed_named_margin_hash
    raw_gate_hash = canonical_hash(response["raw_gates"])
    raw_gate_hash == response["raw_gate_signature_hash"] || error(
        "v38 v36 raw-gate signature drifted")
    module_signature = canonical_hash(Dict{String,Any}(
        "module_id" => module_id,
        "hard_unknown_requirements" => additional))
    return Dict{String,Any}(
        "candidate_index" => Int(response["candidate_index"]),
        "family" => String(response["family"]),
        "graph_hash" => String(response["graph_hash"]),
        "physics_hash" => String(response["physics_hash"]),
        "tier1_module_id" => module_id,
        "group_id" => String(overlay["group_id"]),
        "source_ids" => _v38_strings(overlay["source_ids"]),
        "source_support_status" => String(
            overlay["source_support_status"]),
        "target_named_margin_ids" => _v38_strings(
            overlay["target_named_margin_ids"]),
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
        "hard_unknown_evidence_route_implemented" => true,
        "solver_executed" => false,
        "formula_implemented" => false,
        "direct_gate_credit_authorized" => false,
        "old_domain_scale_up_authorized" => false,
        "promoted" => false,
        "claim_level" => "C0_module_specific_hard_unknown_routing_only")
end

function tier1_module_evidence_ablation_v38(overlay_raw,
        v37_module_contracts_raw::AbstractVector,
        v37_ablation_cases_raw::AbstractVector,
        v36_responses_raw::AbstractVector, source_records_raw::AbstractVector)
    overlay = _v38_dict(overlay_raw)
    overlay["overlay_version"] == "tier1_module_evidence_overlay_v38" ||
        throw(ArgumentError("v38 overlay version changed"))
    overlay["sealed_v37_result_hash"] ==
        "d212d5a4514a7af0ff80e97614aaac0000063fee654f0f7f3b1e73471240c159" ||
        throw(ArgumentError("v38 sealed v37 result hash changed"))
    contracts = [_v38_dict(item) for item in v37_module_contracts_raw]
    cases = [_v38_dict(item) for item in v37_ablation_cases_raw]
    responses = [_v38_dict(item) for item in v36_responses_raw]
    length(contracts) == 18 || throw(ArgumentError(
        "v38 requires the 18 v37 module contracts"))
    length(cases) == 21 || throw(ArgumentError(
        "v38 requires the 21 v37 ablation cases"))
    length(responses) == 55 || throw(ArgumentError(
        "v38 requires the 55 v36 responses"))

    tier1_contracts = [item for item in contracts if
        item["priority_tier"] == "tier_1_physics_decision_surface"]
    length(tier1_contracts) == 7 || error(
        "v38 v37 tier-1 module count changed")
    contract_by_module = Dict(String(item["module_id"]) => item
        for item in tier1_contracts)
    overlay_modules = [_v38_dict(item) for item in overlay["modules"]]
    length(overlay_modules) == 7 || throw(ArgumentError(
        "v38 requires seven module overlays"))
    overlay_by_module = Dict(String(item["module_id"]) => item
        for item in overlay_modules)
    length(overlay_by_module) == 7 || error(
        "v38 overlay contains duplicate module IDs")
    sort!(collect(keys(overlay_by_module))) ==
        sort!(collect(keys(contract_by_module))) || error(
        "v38 overlay modules do not equal the v37 tier-1 set")
    for (module_id, item) in overlay_by_module
        contract = contract_by_module[module_id]
        String(item["group_id"]) == String(contract["group_id"]) || error(
            "v38 overlay group drifted for $module_id")
        target_margins = Set(_v38_strings(item["target_named_margin_ids"]))
        issubset(target_margins,
            Set(_v38_strings(contract["target_named_margin_ids"]))) || error(
            "v38 overlay target margins exceed the v37 contract")
    end

    source_index = Dict{String,Any}()
    for raw in source_records_raw
        item = _v38_source_record(raw)
        id = String(item["id"])
        haskey(source_index, id) && error(
            "v38 duplicate source ID $id")
        source_index[id] = item
    end
    used_source_ids = sort!(unique(String(id) for item in overlay_modules
        for id in item["source_ids"]))
    all(haskey(source_index, id) for id in used_source_ids) || error(
        "v38 overlay source trace is incomplete")
    source_ledger = [source_index[id] for id in used_source_ids]

    response_by_graph = Dict(String(item["graph_hash"]) => item
        for item in responses)
    length(response_by_graph) == 55 || error(
        "v38 response graph hashes are not unique")
    tier1_ids = Set(keys(overlay_by_module))
    tier1_cases = [item for item in cases if any(id in tier1_ids
        for id in _v38_strings(item["module_ids"]))]
    length(tier1_cases) == 8 || error(
        "v38 fixed-background tier-1 case count changed")

    graph_responses = Dict{String,Any}()
    case_results = Dict{String,Any}[]
    for case in sort!(tier1_cases; by = item -> (
            String(item["family"]), String(item["v35_pair_hash"])))
        first_hash = String(case["first_graph_hash"])
        second_hash = String(case["second_graph_hash"])
        haskey(response_by_graph, first_hash) &&
            haskey(response_by_graph, second_hash) || error(
            "v38 case references an unknown v36 graph")
        first_response = apply_tier1_module_evidence_overlay_v38(
            response_by_graph[first_hash], overlay_by_module)
        second_response = apply_tier1_module_evidence_overlay_v38(
            response_by_graph[second_hash], overlay_by_module)
        first_response["family"] == second_response["family"] ==
            String(case["family"]) || error(
            "v38 matched case family drifted")
        first_module = String(first_response["tier1_module_id"])
        second_module = String(second_response["tier1_module_id"])
        first_module != second_module || error(
            "v38 matched case did not substitute a tier-1 module")
        Set([first_module, second_module]) ==
            Set(_v38_strings(case["module_ids"])) || error(
            "v38 case module identity drifted")
        evidence_differentiated = first_response[
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
        hard_unknowns_present = Int(first_response[
            "module_specific_hard_unknown_requirement_count"]) > 0 &&
            Int(second_response[
                "module_specific_hard_unknown_requirement_count"]) > 0
        accepted = evidence_differentiated &&
            effective_ledger_differentiated && margins_unchanged &&
            gates_unchanged && hard_unknowns_present
        accepted || error(
            "v38 fixed-background hard-unknown ablation did not pass")
        graph_responses[first_hash] = first_response
        graph_responses[second_hash] = second_response
        push!(case_results, Dict{String,Any}(
            "v35_pair_hash" => String(case["v35_pair_hash"]),
            "family" => String(case["family"]),
            "first_graph_hash" => first_hash,
            "second_graph_hash" => second_hash,
            "first_module_id" => first_module,
            "second_module_id" => second_module,
            "first_module_specific_evidence_signature_hash" =>
                first_response["module_specific_evidence_signature_hash"],
            "second_module_specific_evidence_signature_hash" =>
                second_response["module_specific_evidence_signature_hash"],
            "first_effective_evidence_gap_signature_hash" =>
                first_response["effective_evidence_gap_signature_hash"],
            "second_effective_evidence_gap_signature_hash" =>
                second_response["effective_evidence_gap_signature_hash"],
            "module_specific_evidence_differentiated" =>
                evidence_differentiated,
            "effective_evidence_ledger_differentiated" =>
                effective_ledger_differentiated,
            "numeric_named_margins_unchanged" => margins_unchanged,
            "raw_gates_unchanged" => gates_unchanged,
            "hard_unknowns_present_on_both_sides" => hard_unknowns_present,
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
            case["first_module_id"] == module_id ||
            case["second_module_id"] == module_id]
        isempty(module_cases) && error(
            "v38 tier-1 module has no matched case")
        all(case["fixed_background_ablation_accepted"] === true
            for case in module_cases) || error(
            "v38 tier-1 module has an unaccepted case")
        push!(module_results, Dict{String,Any}(
            "module_id" => module_id,
            "group_id" => String(item["group_id"]),
            "source_ids" => _v38_strings(item["source_ids"]),
            "source_support_status" => String(
                item["source_support_status"]),
            "target_named_margin_ids" => _v38_strings(
                item["target_named_margin_ids"]),
            "module_specific_hard_unknown_requirements" => _v38_strings(
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
    requirement_ids = sort!(unique(String(id) for item in overlay_modules
        for id in item["module_specific_hard_unknown_requirements"]))
    return Dict{String,Any}(
        "tier1_group_count" => length(group_counts),
        "tier1_module_count" => length(module_results),
        "tier1_fixed_background_case_count" => length(case_results),
        "tier1_graph_response_count" => length(graph_response_records),
        "module_specific_hard_unknown_requirement_count" =>
            length(requirement_ids),
        "source_record_count" => length(source_ledger),
        "group_module_counts" => group_counts,
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
        "remaining_v37_matched_full_disconnect_module_count" => 18 -
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
        "claim_boundary" => _V38_CLAIM_BOUNDARY)
end
