const _V37_CLAIM_BOUNDARY =
    "V37 converts the 18 v36 matched-pair complete-response disconnect modules into explicit hard-unknown influence contracts. Each contract binds source trace, semantic candidate inputs, existing named-margin targets, missing evaluator targets, eventual gate observability, and fixed-background ablation cases. These are preregistered validation targets, not numerical formulas or favorable signs. No proxy, gate, threshold, evidence credit, single-module physical causality, C1 status, medium-fidelity authorization, family ranking, old-domain scale-up, or promotion changes."

_v37_strings(value) = sort!(unique(String.(copy(value))))

function _v37_dict(raw)
    return Dict{String,Any}(String(key) => _plain_json(value)
        for (key, value) in raw)
end

function _v37_source_record(source)
    record = _v37_dict(source)
    return Dict{String,Any}(
        "id" => String(record["id"]),
        "title" => String(record["title"]),
        "year" => Int(record["year"]),
        "family" => _v37_strings(record["family"]),
        "kind" => String(record["kind"]),
        "evidence_level" => String(record["evidence_level"]),
        "doi" => get(record, "doi", nothing),
        "url" => String(record["url"]),
        "claim_boundary" => String(record["claim_boundary"]))
end

function _v37_matched_cases(module_id::String, pairs)
    cases = Dict{String,Any}[]
    for pair in pairs
        pair["single_layer_substitution"] === true || continue
        difference = _v37_strings(pair["module_symmetric_difference"])
        module_id in difference || continue
        length(difference) == 2 || error(
            "v37 matched substitution does not contain exactly two modules")
        companion = only(filter(!=(module_id), difference))
        pair["full_evaluated_response_identical"] === true || error(
            "v37 disconnect module has a matched evaluated-response variation")
        pair["evidence_gap_ledger_identical"] === true || error(
            "v37 disconnect module has a matched evidence variation")
        pair["raw_gate_dictionary_identical"] === true || error(
            "v37 disconnect module changed a raw gate")
        push!(cases, Dict{String,Any}(
            "case_id" => canonical_hash(Dict{String,Any}(
                "module_id" => module_id,
                "pair_hash" => String(pair["pair_hash"]))),
            "module_id" => module_id,
            "companion_module_id" => companion,
            "family" => String(pair["family"]),
            "first_graph_hash" => String(pair["first_graph_hash"]),
            "second_graph_hash" => String(pair["second_graph_hash"]),
            "first_candidate_index" => Int(pair["first_candidate_index"]),
            "second_candidate_index" => Int(pair["second_candidate_index"]),
            "v35_pair_hash" => String(pair["pair_hash"]),
            "fixed_background_layer" => only(_v37_strings(
                pair["differing_layers"])),
            "complete_evaluated_response_identical" => true,
            "raw_gate_dictionary_identical" => true,
            "evidence_gap_ledger_identical" => true,
            "single_module_physical_causality_proven" => false,
            "ablation_repair_accepted" => false))
    end
    sort!(cases; by = item -> (String(item["family"]),
        String(item["companion_module_id"]), String(item["v35_pair_hash"])))
    return cases
end

function disconnected_module_influence_contract_v37(
        spec_raw, v36_module_queue_raw::AbstractVector,
        v36_pairs_raw::AbstractVector, v36_responses_raw::AbstractVector,
        catalog::AbstractVector, source_records_raw::AbstractVector)
    spec = _v37_dict(spec_raw)
    spec["contract_version"] ==
        "disconnected_module_influence_contract_v37" || throw(ArgumentError(
        "v37 contract version changed"))
    spec["sealed_input_result_hash"] ==
        "c183755775153f6d87ecd264e1a64062ff82506b9b490372c9653d4aa927afe6" ||
        throw(ArgumentError("v37 sealed v36 input hash changed"))
    groups_raw = [_v37_dict(item) for item in spec["groups"]]
    length(groups_raw) == 8 || throw(ArgumentError(
        "v37 requires eight influence groups"))
    queue = [_v37_dict(item) for item in v36_module_queue_raw]
    pairs = [_v37_dict(item) for item in v36_pairs_raw]
    responses = [_v37_dict(item) for item in v36_responses_raw]
    length(queue) == 74 || throw(ArgumentError(
        "v37 requires the 74-entry v36 module queue"))
    length(pairs) == 110 || throw(ArgumentError(
        "v37 requires the 110 v36 graph pairs"))
    length(responses) == 55 || throw(ArgumentError(
        "v37 requires the 55 v36 response records"))

    disconnect_route =
        "matched_pair_no_named_margin_gate_or_evidence_variation"
    disconnect_queue = [item for item in queue if
        item["observed_response_route"] == disconnect_route]
    length(disconnect_queue) == 18 || error(
        "v37 v36 disconnect module count changed")
    queue_by_id = Dict(String(item["module_id"]) => item
        for item in disconnect_queue)
    spec_module_ids = sort!(reduce(vcat,
        [_v37_strings(group["module_ids"]) for group in groups_raw]))
    length(spec_module_ids) == length(unique(spec_module_ids)) || error(
        "v37 a module appears in multiple influence groups")
    spec_module_ids == sort!(collect(keys(queue_by_id))) || error(
        "v37 contract modules do not equal the v36 disconnect set")

    catalog_by_id = Dict(String(item.id) => item for item in catalog)
    source_index = Dict{String,Any}()
    for raw in source_records_raw
        record = _v37_source_record(raw)
        id = String(record["id"])
        haskey(source_index, id) && error(
            "v37 duplicate source ID $id")
        source_index[id] = record
    end
    response_by_family = Dict{String,Vector{Dict{String,Any}}}()
    for record in responses
        push!(get!(response_by_family, String(record["family"]),
            Dict{String,Any}[]), record)
    end

    module_contracts = Dict{String,Any}[]
    group_contracts = Dict{String,Any}[]
    used_source_ids = Set{String}()
    for group in sort!(groups_raw; by = item -> String(item["group_id"]))
        group_id = String(group["group_id"])
        module_ids = _v37_strings(group["module_ids"])
        target_margins = _v37_strings(group["target_named_margin_ids"])
        target_requirements = _v37_strings(
            group["target_evidence_requirement_ids"])
        group_modules = Dict{String,Any}[]
        for module_id in module_ids
            haskey(catalog_by_id, module_id) || error(
                "v37 unknown catalog module $module_id")
            catalog_module = catalog_by_id[module_id]
            queue_item = queue_by_id[module_id]
            String(catalog_module.layer) == String(queue_item["layer"]) || error(
                "v37 module layer drifted for $module_id")
            _v37_strings(catalog_module.required_evaluators) ==
                _v37_strings(queue_item["required_evaluators"]) || error(
                "v37 required evaluators drifted for $module_id")
            _v37_strings(catalog_module.required_evaluators) == target_requirements ||
                error("v37 group evidence targets do not bind $module_id")
            source_ids = _v37_strings(catalog_module.source_ids)
            all(haskey(source_index, id) for id in source_ids) || error(
                "v37 source trace missing for $module_id")
            union!(used_source_ids, source_ids)
            families = _v37_strings(queue_item["families"])
            evaluator_routes = Dict{String,Any}()
            target_margin_presence = Dict{String,Any}()
            evidence_missing_counts = Dict(id => 0
                for id in target_requirements)
            for family in families
                family_records = get(response_by_family, family,
                    Dict{String,Any}[])
                isempty(family_records) && error(
                    "v37 module family has no response record")
                evaluator_ids = sort!(unique(String(record["evaluator_id"])
                    for record in family_records))
                evaluator_routes[family] = evaluator_ids
                available = Set{String}()
                for record in family_records
                    union!(available, String.(keys(record["named_margins"])))
                    missing = Set(_v37_strings(
                        record["missing_proxy_requirements"]))
                    for requirement in target_requirements
                        requirement in missing &&
                            (evidence_missing_counts[requirement] += 1)
                    end
                end
                target_margin_presence[family] = Dict{String,Any}(
                    "present" => sort!([id for id in target_margins if
                        id in available]),
                    "absent" => sort!([id for id in target_margins if
                        !(id in available)]))
            end
            all(any(id in keys(record["named_margins"]) for record in responses
                    if record["family"] in families) for id in target_margins) ||
                error("v37 group contains an unobservable named-margin target")
            cases = _v37_matched_cases(module_id, pairs)
            isempty(cases) && error(
                "v37 disconnect module has no fixed-background matched case")
            contract = Dict{String,Any}(
                "module_id" => module_id,
                "group_id" => group_id,
                "priority_tier" => String(group["priority_tier"]),
                "layer" => String(catalog_module.layer),
                "description" => String(catalog_module.description),
                "families" => families,
                "source_ids" => source_ids,
                "source_trace" => [source_index[id] for id in source_ids],
                "required_evaluators" => _v37_strings(
                    catalog_module.required_evaluators),
                "candidate_specific_input_semantics" => _v37_strings(
                    group["candidate_specific_input_semantics"]),
                "target_named_margin_ids" => target_margins,
                "target_named_margin_presence_by_family" =>
                    target_margin_presence,
                "target_evidence_requirement_ids" => target_requirements,
                "target_evidence_missing_record_counts" =>
                    evidence_missing_counts,
                "eventual_gate_observability_targets" => _v37_strings(
                    group["eventual_gate_observability_targets"]),
                "required_solver_classes" => _v37_strings(
                    group["required_solver_classes"]),
                "current_evaluator_routes_by_family" => evaluator_routes,
                "matched_ablation_cases" => cases,
                "matched_ablation_case_count" => length(cases),
                "observed_v36_route" => disconnect_route,
                "binding_state" =>
                    "hard_unknown_until_candidate_specific_ablation_passes",
                "quantitative_input_evidence_complete" => false,
                "candidate_specific_binding_implemented" => false,
                "formula_implementation_authorized" => false,
                "direct_gate_credit_authorized" => false,
                "old_domain_scale_up_authorized" => false,
                "single_module_physical_causality_proven" => false,
                "promotion_credit" => 0)
            push!(group_modules, contract)
            push!(module_contracts, contract)
        end
        push!(group_contracts, Dict{String,Any}(
            "group_id" => group_id,
            "priority_tier" => String(group["priority_tier"]),
            "module_ids" => module_ids,
            "module_count" => length(module_ids),
            "candidate_specific_input_semantics" => _v37_strings(
                group["candidate_specific_input_semantics"]),
            "target_named_margin_ids" => target_margins,
            "target_evidence_requirement_ids" => target_requirements,
            "eventual_gate_observability_targets" => _v37_strings(
                group["eventual_gate_observability_targets"]),
            "required_solver_classes" => _v37_strings(
                group["required_solver_classes"]),
            "matched_ablation_case_count" => sum(Int(
                item["matched_ablation_case_count"]) for item in group_modules),
            "hard_unknown_module_count" => length(group_modules),
            "formula_implementation_authorized_count" => 0,
            "group_ablation_accepted" => false))
    end
    sort!(module_contracts; by = item -> (
        String(item["priority_tier"]), String(item["group_id"]),
        String(item["module_id"])))

    unique_cases = Dict{String,Any}()
    for contract in module_contracts, case in contract["matched_ablation_cases"]
        key = String(case["v35_pair_hash"])
        if !haskey(unique_cases, key)
            unique_cases[key] = Dict{String,Any}(
                "v35_pair_hash" => key,
                "family" => String(case["family"]),
                "first_graph_hash" => String(case["first_graph_hash"]),
                "second_graph_hash" => String(case["second_graph_hash"]),
                "module_ids" => String[],
                "ablation_repair_accepted" => false)
        end
        push!(unique_cases[key]["module_ids"],
            String(contract["module_id"]))
    end
    ablation_cases = collect(values(unique_cases))
    for case in ablation_cases
        case["module_ids"] = sort!(unique(String.(case["module_ids"])))
        1 <= length(case["module_ids"]) <= 2 || error(
            "v37 unique matched case has an invalid contracted-module count")
        case["contracted_module_count"] = length(case["module_ids"])
    end
    sort!(ablation_cases; by = item -> (String(item["family"]),
        String(item["v35_pair_hash"])))
    source_ledger = [source_index[id] for id in sort!(collect(used_source_ids))]
    priority_counts = _v33_count_strings(String[
        item["priority_tier"] for item in module_contracts])
    family_ids = sort!(unique(String(family) for item in module_contracts
        for family in item["families"]))
    target_margin_ids = sort!(unique(String(id) for item in group_contracts
        for id in item["target_named_margin_ids"]))
    target_requirement_ids = sort!(unique(String(id) for item in group_contracts
        for id in item["target_evidence_requirement_ids"]))
    return Dict{String,Any}(
        "contract_group_count" => length(group_contracts),
        "contract_module_count" => length(module_contracts),
        "family_count" => length(family_ids),
        "families" => family_ids,
        "unique_fixed_background_ablation_case_count" =>
            length(ablation_cases),
        "source_record_count" => length(source_ledger),
        "target_named_margin_count" => length(target_margin_ids),
        "target_named_margin_ids" => target_margin_ids,
        "target_evidence_requirement_count" =>
            length(target_requirement_ids),
        "target_evidence_requirement_ids" => target_requirement_ids,
        "priority_tier_module_counts" => priority_counts,
        "modules_with_source_trace_count" => count(item ->
            !isempty(item["source_trace"]), module_contracts),
        "modules_with_fixed_background_case_count" => count(item ->
            Int(item["matched_ablation_case_count"]) > 0, module_contracts),
        "hard_unknown_module_count" => count(item -> item["binding_state"] ==
            "hard_unknown_until_candidate_specific_ablation_passes",
            module_contracts),
        "formula_implementation_authorized_count" => 0,
        "direct_gate_credit_authorized_count" => 0,
        "old_domain_scale_up_authorized" => false,
        "single_module_physical_causality_claimed" => false,
        "promotion_count" => 0,
        "medium_fidelity_authorized_count" => 0,
        "contract_groups" => group_contracts,
        "module_contracts" => module_contracts,
        "fixed_background_ablation_cases" => ablation_cases,
        "source_ledger" => source_ledger,
        "acceptance_rule" => String(spec["acceptance_rule"]),
        "global_forbidden_shortcuts" => _v37_strings(
            spec["global_forbidden_shortcuts"]),
        "claim_boundary" => _V37_CLAIM_BOUNDARY)
end
