const _V36_CLAIM_BOUNDARY =
    "V36 reconstructs the complete executed nominal named-margin vector, raw five-gate dictionary, and declared missing-evaluator ledger for the 55 sealed v34 records, then reclassifies the 110 v35 graph pairs. A differing full response shows that at least one co-differing module or projection path is represented somewhere in the current proxy; it does not identify a single-module physical causal effect. An identical response is a binding gap only within the executed fidelity-0 model and declared evidence ledger. No gate, topology, evidence credit, robustness result, C1 status, medium-fidelity authorization, family ranking, or promotion changes."

function reconstruct_full_response_v36(
        context::RecoverableCrossTopologyContextV20, v34_raw;
        halton_skip::Integer = 4096)
    record = _plain_json(v34_raw)
    record["diagnostic_proxy_sensitivity_authorized"] === true ||
        throw(ArgumentError("v36 requires a sealed v34 sensitivity record"))
    record["promoted"] === false || throw(ArgumentError(
        "v36 cannot ingest a promoted record"))
    candidate = evaluate_cross_topology_candidate_v20(context,
        Int(record["candidate_index"]); halton_skip = Int(halton_skip))
    raw = _v34_raw_result(context, candidate)
    compiled = candidate.prescreen.compiled
    compiled.family == String(record["family"]) || error(
        "v36 reconstructed family drifted")
    compiled.graph_hash == String(record["graph_hash"]) || error(
        "v36 reconstructed graph hash drifted")
    compiled.genome.physics_hash == String(record["physics_hash"]) || error(
        "v36 reconstructed physics hash drifted")
    compiled.evaluator_id == String(record["evaluator_id"]) || error(
        "v36 reconstructed evaluator drifted")
    compiled.module_ids == String.(record["module_ids"]) || error(
        "v36 reconstructed module list drifted")
    candidate.prescreen.proxy_result_hash == String(raw["result_hash"]) ||
        error("v36 prescreen/raw-result reconstruction drifted")
    stored_primary_response = canonical_hash([Dict{String,Any}(
        "coordinate_dimension" => item["coordinate_dimension"],
        "low_margin" => item["low_margin"],
        "high_margin" => item["high_margin"])
        for item in record["coordinate_sensitivities"]])
    stored_primary_response_match = stored_primary_response == String(
        record["primary_response_signature_hash"])
    nominal = get(raw, "nominal", Dict{String,Any}())
    raw_margins = get(nominal, "margins", nothing)
    raw_margins isa AbstractDict || error(
        "v36 record has no complete named-margin dictionary")
    margins = Dict{String,Float64}()
    for (name, raw_value) in raw_margins
        raw_value isa Real || error("v36 margin $name is not numeric")
        value = Float64(raw_value)
        isfinite(value) || error("v36 margin $name is not finite")
        margins[String(name)] = value
    end
    primary_margin_id = String(record["primary_margin_id"])
    haskey(margins, primary_margin_id) || error(
        "v36 reconstructed result lost its primary margin")
    margins[primary_margin_id] == Float64(
        record["baseline_primary_margin"]) || error(
        "v36 reconstructed primary margin drifted")
    gates = Dict{String,Bool}()
    for (name, raw_value) in raw["gates"]
        raw_value isa Bool || error("v36 gate $name is not Boolean")
        gates[String(name)] = Bool(raw_value)
    end
    missing = sort!(String.(copy(record["missing_proxy_requirements"])))
    failed = Dict(name => value for (name, value) in margins if value < 0.0)
    evaluated_core = Dict{String,Any}(
        "named_margins" => margins,
        "raw_gates" => gates)
    return Dict{String,Any}(
        "candidate_index" => Int(record["candidate_index"]),
        "family" => String(record["family"]),
        "graph_hash" => String(record["graph_hash"]),
        "physics_hash" => String(record["physics_hash"]),
        "module_ids" => String.(copy(record["module_ids"])),
        "evaluator_id" => String(record["evaluator_id"]),
        "primary_margin_id" => primary_margin_id,
        "named_margins" => margins,
        "named_margin_count" => length(margins),
        "failed_named_margins" => failed,
        "failed_named_margin_count" => length(failed),
        "raw_gates" => gates,
        "raw_gate_pass_count" => count(values(gates)),
        "missing_proxy_requirements" => missing,
        "missing_proxy_requirement_count" => length(missing),
        "full_evaluated_response_signature_hash" =>
            canonical_hash(evaluated_core),
        "full_margin_signature_hash" => canonical_hash(margins),
        "failed_margin_signature_hash" => canonical_hash(failed),
        "raw_gate_signature_hash" => canonical_hash(gates),
        "evidence_gap_signature_hash" => canonical_hash(missing),
        "raw_result_hash" => String(raw["result_hash"]),
        "raw_result_reconstruction_match" => true,
        "v34_primary_response_signature_hash" => String(
            record["primary_response_signature_hash"]),
        "v34_archived_primary_response_recomputed_hash" =>
            stored_primary_response,
        "v34_archived_primary_response_signature_recomputed_match" =>
            stored_primary_response_match,
        "v34_signature_recompute_note" => stored_primary_response_match ?
            "archived numeric representation preserved the v34 signature" :
            "JSON numeric normalization including signed zero prevents archived-vector signature reproduction; sealed archive SHA remains authoritative",
        "full_response_audit_authorized" => true,
        "single_module_causal_effect_claimed" => false,
        "old_domain_scale_up_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promoted" => false,
        "claim_level" => "C0_full_executed_response_audit_only")
end

function _v36_pair_classification(first_response::AbstractDict,
        second_response::AbstractDict)
    full_same = first_response["full_evaluated_response_signature_hash"] ==
        second_response["full_evaluated_response_signature_hash"]
    margins_same = first_response["full_margin_signature_hash"] ==
        second_response["full_margin_signature_hash"]
    gates_same = first_response["raw_gate_signature_hash"] ==
        second_response["raw_gate_signature_hash"]
    evidence_same = first_response["evidence_gap_signature_hash"] ==
        second_response["evidence_gap_signature_hash"]
    raw_same = first_response["raw_result_hash"] ==
        second_response["raw_result_hash"]
    classification = full_same && evidence_same ?
        "full_evaluated_and_evidence_alias" :
        !full_same && evidence_same ?
        "evaluated_response_variation_only" :
        full_same && !evidence_same ?
        "evidence_variation_only" :
        "evaluated_response_and_evidence_variation"
    return Dict{String,Any}(
        "full_evaluated_response_identical" => full_same,
        "full_margin_vector_identical" => margins_same,
        "raw_gate_dictionary_identical" => gates_same,
        "evidence_gap_ledger_identical" => evidence_same,
        "raw_result_hash_identical" => raw_same,
        "response_classification" => classification)
end

function full_margin_evidence_response_audit_v36(
        response_records::AbstractVector, v35_pairs::AbstractVector,
        v35_module_queue::AbstractVector)
    responses = [Dict{String,Any}(String(key) => _plain_json(value)
        for (key, value) in record) for record in response_records]
    length(responses) == 55 || throw(ArgumentError(
        "v36 requires 55 full-response records"))
    response_by_graph = Dict(String(record["graph_hash"]) => record
        for record in responses)
    length(response_by_graph) == 55 || error(
        "v36 graph hashes are not unique")
    pairs = Dict{String,Any}[]
    for raw_pair in v35_pairs
        pair = Dict{String,Any}(String(key) => _plain_json(value)
            for (key, value) in raw_pair)
        first_hash = String(pair["first_graph_hash"])
        second_hash = String(pair["second_graph_hash"])
        haskey(response_by_graph, first_hash) &&
            haskey(response_by_graph, second_hash) || error(
            "v36 v35 pair references an unknown graph")
        classification = _v36_pair_classification(
            response_by_graph[first_hash], response_by_graph[second_hash])
        item = deepcopy(pair)
        merge!(item, classification)
        item["single_module_causal_effect_claimed"] = false
        item["full_response_pair_audit_authorized"] = true
        push!(pairs, item)
    end
    length(pairs) == 110 || throw(ArgumentError(
        "v36 requires 110 v35 graph pairs"))
    sort!(pairs; by = pair -> (String(pair["family"]),
        String(pair["first_graph_hash"]), String(pair["second_graph_hash"])))
    family_summaries = Dict{String,Any}()
    for family in sort!(unique(String(pair["family"]) for pair in pairs))
        family_pairs = [pair for pair in pairs if pair["family"] == family]
        family_summaries[family] = Dict{String,Any}(
            "graph_pair_count" => length(family_pairs),
            "full_evaluated_and_evidence_alias_pair_count" => count(pair ->
                pair["response_classification"] ==
                    "full_evaluated_and_evidence_alias", family_pairs),
            "evaluated_response_variation_pair_count" => count(pair ->
                pair["full_evaluated_response_identical"] === false,
                family_pairs),
            "full_margin_variation_pair_count" => count(pair ->
                pair["full_margin_vector_identical"] === false,
                family_pairs),
            "raw_gate_variation_pair_count" => count(pair ->
                pair["raw_gate_dictionary_identical"] === false,
                family_pairs),
            "evidence_variation_pair_count" => count(pair ->
                pair["evidence_gap_ledger_identical"] === false,
                family_pairs),
            "raw_result_variation_pair_count" => count(pair ->
                pair["raw_result_hash_identical"] === false, family_pairs),
            "single_layer_full_alias_pair_count" => count(pair ->
                pair["single_layer_substitution"] === true &&
                pair["full_evaluated_response_identical"] === true &&
                pair["evidence_gap_ledger_identical"] === true,
                family_pairs))
    end
    enriched_queue = Dict{String,Any}[]
    for raw_item in v35_module_queue
        item = Dict{String,Any}(String(key) => _plain_json(value)
            for (key, value) in raw_item)
        module_id = String(item["module_id"])
        module_pairs = [pair for pair in pairs if module_id in
            String.(pair["module_symmetric_difference"])]
        isempty(module_pairs) && error(
            "v36 module queue entry has no graph pair")
        evaluated_variation = count(pair ->
            pair["full_evaluated_response_identical"] === false,
            module_pairs)
        evidence_variation = count(pair ->
            pair["evidence_gap_ledger_identical"] === false, module_pairs)
        matched_evaluated_variation = count(pair ->
            pair["single_layer_substitution"] === true &&
            pair["full_evaluated_response_identical"] === false,
            module_pairs)
        matched_evidence_variation = count(pair ->
            pair["single_layer_substitution"] === true &&
            pair["evidence_gap_ledger_identical"] === false,
            module_pairs)
        matched_full_alias = count(pair ->
            pair["single_layer_substitution"] === true &&
            pair["full_evaluated_response_identical"] === true &&
            pair["evidence_gap_ledger_identical"] === true,
            module_pairs)
        route = matched_evaluated_variation > 0 ?
            "matched_pair_evaluated_response_variation_observed" :
            matched_evidence_variation > 0 ?
            "matched_pair_evidence_variation_only" :
            matched_full_alias > 0 ?
            "matched_pair_no_named_margin_gate_or_evidence_variation" :
            evaluated_variation > 0 ?
            "multilayer_co_difference_evaluated_response_variation" :
            evidence_variation > 0 ?
            "multilayer_co_difference_evidence_variation_only" :
            "multilayer_co_difference_full_response_alias"
        result = deepcopy(item)
        result["evaluated_response_variation_pair_count"] =
            evaluated_variation
        result["evidence_variation_pair_count"] = evidence_variation
        result["matched_evaluated_response_variation_pair_count"] =
            matched_evaluated_variation
        result["matched_evidence_variation_pair_count"] =
            matched_evidence_variation
        result["matched_full_response_alias_pair_count"] = matched_full_alias
        result["observed_response_route"] = route
        result["single_module_causal_effect_proven"] = false
        push!(enriched_queue, result)
    end
    route_counts = _v33_count_strings(String[
        item["observed_response_route"] for item in enriched_queue])
    sort!(enriched_queue; by = item -> (
        String(item["observed_response_route"]),
        -Int(item["matched_full_response_alias_pair_count"]),
        -Int(item["co_difference_pair_count"]), String(item["module_id"])))
    classifications = _v33_count_strings(String[
        pair["response_classification"] for pair in pairs])
    return Dict{String,Any}(
        "response_record_count" => length(responses),
        "family_count" => length(family_summaries),
        "graph_pair_count" => length(pairs),
        "response_classification_counts" => classifications,
        "full_evaluated_response_alias_pair_count" => count(pair ->
            pair["full_evaluated_response_identical"] === true, pairs),
        "full_margin_alias_pair_count" => count(pair ->
            pair["full_margin_vector_identical"] === true, pairs),
        "raw_gate_alias_pair_count" => count(pair ->
            pair["raw_gate_dictionary_identical"] === true, pairs),
        "evidence_alias_pair_count" => count(pair ->
            pair["evidence_gap_ledger_identical"] === true, pairs),
        "raw_result_hash_alias_pair_count" => count(pair ->
            pair["raw_result_hash_identical"] === true, pairs),
        "v34_archived_primary_response_signature_recomputed_match_count" =>
            count(record -> record[
                "v34_archived_primary_response_signature_recomputed_match"] ===
                true, responses),
        "single_layer_full_response_alias_pair_count" => count(pair ->
            pair["single_layer_substitution"] === true &&
            pair["full_evaluated_response_identical"] === true &&
            pair["evidence_gap_ledger_identical"] === true, pairs),
        "module_count" => length(enriched_queue),
        "module_response_route_counts" => route_counts,
        "family_summaries" => family_summaries,
        "graph_pair_responses" => pairs,
        "module_response_queue" => enriched_queue,
        "full_response_audit_complete" => true,
        "old_domain_scale_up_authorized" => false,
        "single_module_causal_effect_claimed" => false,
        "promotion_count" => 0,
        "medium_fidelity_authorized_count" => 0,
        "claim_boundary" => _V36_CLAIM_BOUNDARY)
end
