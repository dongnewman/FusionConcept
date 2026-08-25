const _V41_CLAIM_BOUNDARY =
    "V41 repairs every v40 structural counterfactual rejection by exhaustively searching the complete compatible v17 assembly set for a minimum dependency-closed pair. It first minimizes the number of layers that differ between the two compared assemblies, then the number of support layers changed from the sealed source background, and finally the total and maximum source Hamming distances. A one-layer comparison on a jointly repaired support background is a controlled route inside the existing fidelity-0 proxy; a multi-layer comparison identifies only a coupled-block route. Neither case proves physical causality, benefit, infeasibility, robustness, C1, medium-fidelity validity, or reactor feasibility. No new formula, gate credit, old-domain scale-up, or promotion is authorized."

function _v41_changed_layers(first_ids::AbstractVector,
        second_ids::AbstractVector)
    length(first_ids) == length(_V17_LAYERS) || throw(ArgumentError(
        "v41 first assembly does not have five layers"))
    length(second_ids) == length(_V17_LAYERS) || throw(ArgumentError(
        "v41 second assembly does not have five layers"))
    return String[String(_V17_LAYERS[index]) for index in eachindex(first_ids)
        if String(first_ids[index]) != String(second_ids[index])]
end

function _v41_complete_assemblies(
        context::RecoverableCrossTopologyContextV20)
    grammar = run_attribute_graph_grammar_v17(catalog = context.catalog,
        maximum_archive = 1200)
    grammar.catalog_hash == context.catalog_hash || error(
        "v41 complete grammar catalog drifted from the v20 context")
    grammar.compatible_assembly_count == length(grammar.archive) || error(
        "v41 complete grammar archive is truncated")
    grammar.compatible_assembly_count == 1129 || error(
        "v41 compatible v17 assembly count changed")
    return grammar.archive, grammar.compatible_assembly_count
end

function _v41_module_candidates(assemblies::Vector{TopologyAssemblyV17},
        family::String, mission_contract_id::String, layer_index::Int,
        module_id::String)
    candidates = [item for item in assemblies if item.family == family &&
        item.mission_contract_id == mission_contract_id &&
        item.module_ids[layer_index] == module_id]
    sort!(candidates; by = item -> (item.graph_hash, item.assembly_id))
    isempty(candidates) && error(
        "v41 found no dependency-closed assembly for $family/$module_id")
    return candidates
end

function _v41_select_minimum_pair(background::TopologyAssemblyV17,
        layer_index::Int, first_candidates::Vector{TopologyAssemblyV17},
        second_candidates::Vector{TopologyAssemblyV17})
    target_layer = String(_V17_LAYERS[layer_index])
    best_objective = nothing
    best_tie_count = 0
    selected = nothing
    for first in first_candidates, second in second_candidates
        comparison_layers = _v41_changed_layers(first.module_ids,
            second.module_ids)
        target_layer in comparison_layers || error(
            "v41 candidate pair lost the intervened layer")
        first_source_layers = _v41_changed_layers(background.module_ids,
            first.module_ids)
        second_source_layers = _v41_changed_layers(background.module_ids,
            second.module_ids)
        support_layers = sort!(collect(setdiff(union(
            Set(first_source_layers), Set(second_source_layers)),
            Set([target_layer]))))
        first_distance = length(first_source_layers)
        second_distance = length(second_source_layers)
        objective = (length(comparison_layers), length(support_layers),
            first_distance + second_distance,
            max(first_distance, second_distance))
        tie_break = (first.graph_hash, second.graph_hash)
        if best_objective === nothing || objective < best_objective
            best_objective = objective
            best_tie_count = 1
            selected = (first = first, second = second,
                comparison_layers = comparison_layers,
                first_source_layers = first_source_layers,
                second_source_layers = second_source_layers,
                support_layers = support_layers,
                first_distance = first_distance,
                second_distance = second_distance,
                tie_break = tie_break)
        elseif objective == best_objective
            best_tie_count += 1
            if tie_break < selected.tie_break
                selected = (first = first, second = second,
                    comparison_layers = comparison_layers,
                    first_source_layers = first_source_layers,
                    second_source_layers = second_source_layers,
                    support_layers = support_layers,
                    first_distance = first_distance,
                    second_distance = second_distance,
                    tie_break = tie_break)
            end
        end
    end
    selected === nothing && error("v41 failed to select a dependency-closed pair")
    return merge(selected, (
        objective = best_objective,
        minimum_objective_tie_count = best_tie_count,
        exhaustive_pair_count = length(first_candidates) *
            length(second_candidates)))
end

function _v41_response!(cache::Dict{String,Dict{String,Any}},
        context::RecoverableCrossTopologyContextV20,
        assembly::TopologyAssemblyV17, rejection::AbstractDict,
        layer::String, module_id::String, source_changed_layers::Vector{String};
        halton_skip::Int)
    response_key = canonical_hash(Dict{String,Any}(
        "family" => rejection["family"],
        "layer" => layer,
        "source_background_graph_hash" =>
            rejection["source_background_graph_hash"],
        "sample_ordinal" => rejection["sample_ordinal"],
        "module_id" => module_id,
        "dependency_closed_graph_hash" => assembly.graph_hash))
    if !haskey(cache, response_key)
        response = _v40_evaluate_assembly(context, assembly,
            Int(rejection["source_candidate_index"]),
            Int(rejection["sample_ordinal"]); halton_skip = halton_skip)
        response["response_key"] = response_key
        response["intervened_layer"] = layer
        response["intervened_module_id"] = module_id
        response["source_background_graph_hash"] = String(
            rejection["source_background_graph_hash"])
        response["source_changed_layer_ids"] = copy(source_changed_layers)
        response["source_hamming_distance"] = length(source_changed_layers)
        response["dependency_closed_block_evaluation"] = true
        response["claim_level"] =
            "C0_dependency_closed_fidelity0_block_response"
        cache[response_key] = response
    end
    return cache[response_key]
end

function _v41_trial_record(rejection::AbstractDict,
        selection, first_response::AbstractDict,
        second_response::AbstractDict)
    classification = _v36_pair_classification(first_response, second_response)
    changed_margins = _v40_changed_numeric_keys(
        first_response["named_margins"], second_response["named_margins"])
    changed_gates = _v40_changed_boolean_keys(
        first_response["raw_gates"], second_response["raw_gates"])
    first_missing = Set(String.(first_response["missing_proxy_requirements"]))
    second_missing = Set(String.(second_response["missing_proxy_requirements"]))
    changed_requirements = sort!(collect(union(
        setdiff(first_missing, second_missing),
        setdiff(second_missing, first_missing))))
    comparison_layer_count = length(selection.comparison_layers)
    comparison_type = comparison_layer_count == 1 ?
        "dependency_closed_matched_single_layer_comparison" :
        "dependency_closed_coupled_block_comparison"
    effect_identified = !(classification[
        "full_evaluated_response_identical"] &&
        classification["evidence_gap_ledger_identical"])
    trial_core = Dict{String,Any}(
        "family" => String(rejection["family"]),
        "intervened_layer" => String(rejection["layer"]),
        "source_v40_rejection_hash" => String(rejection["rejection_hash"]),
        "source_background_graph_hash" => String(
            rejection["source_background_graph_hash"]),
        "source_candidate_index" => Int(rejection["source_candidate_index"]),
        "sample_ordinal" => Int(rejection["sample_ordinal"]),
        "first_module_id" => String(rejection["first_module_id"]),
        "second_module_id" => String(rejection["second_module_id"]),
        "first_dependency_closed_graph_hash" => selection.first.graph_hash,
        "second_dependency_closed_graph_hash" => selection.second.graph_hash)
    item = merge(trial_core, classification, Dict{String,Any}(
        "first_module_ids" => copy(selection.first.module_ids),
        "second_module_ids" => copy(selection.second.module_ids),
        "first_source_changed_layer_ids" =>
            copy(selection.first_source_layers),
        "second_source_changed_layer_ids" =>
            copy(selection.second_source_layers),
        "first_source_hamming_distance" => selection.first_distance,
        "second_source_hamming_distance" => selection.second_distance,
        "support_adjustment_layer_ids" => copy(selection.support_layers),
        "support_adjustment_layer_count" => length(selection.support_layers),
        "comparison_changed_layer_ids" => copy(selection.comparison_layers),
        "comparison_changed_layer_count" => comparison_layer_count,
        "comparison_type" => comparison_type,
        "exhaustive_valid_pair_count" => selection.exhaustive_pair_count,
        "minimum_objective" => collect(selection.objective),
        "minimum_objective_tie_count" =>
            selection.minimum_objective_tie_count,
        "minimum_dependency_closed_pair_selected" => true,
        "complete_compatible_assembly_search" => true,
        "paired_halton_sample_fixed" => true,
        "changed_named_margin_ids" => changed_margins,
        "changed_named_margin_count" => length(changed_margins),
        "changed_raw_gate_ids" => changed_gates,
        "changed_raw_gate_count" => length(changed_gates),
        "changed_evidence_requirement_ids" => changed_requirements,
        "changed_evidence_requirement_count" => length(changed_requirements),
        "dependency_closed_route_effect_identified" => effect_identified,
        "single_module_absolute_physical_causality_proven" => false,
        "physical_infeasibility_proven" => false,
        "gate_credit_authorized" => false,
        "medium_fidelity_authorized" => false,
        "old_domain_scale_up_authorized" => false,
        "promoted" => false))
    item["trial_hash"] = canonical_hash(trial_core)
    return item
end

function dependency_closed_block_ablation_v41(
        context::RecoverableCrossTopologyContextV20,
        v36_responses_raw::AbstractVector, v40_modules_raw::AbstractVector,
        v40_rejections_raw::AbstractVector; halton_skip::Integer = 4096)
    responses = [_v40_dict(item) for item in v36_responses_raw]
    modules = [_v40_dict(item) for item in v40_modules_raw]
    rejections = [_v40_dict(item) for item in v40_rejections_raw]
    length(responses) == 55 || throw(ArgumentError(
        "v41 requires the 55 sealed v36 frontier responses"))
    length(modules) == 50 || throw(ArgumentError(
        "v41 requires the 50 sealed v40 module routes"))
    length(rejections) == 141 || throw(ArgumentError(
        "v41 requires all 141 sealed v40 structural rejections"))
    target_modules = [item for item in modules if item[
        "controlled_route_classification"] ==
        "structurally_non_intervenable_in_frontier_backgrounds"]
    length(target_modules) == 23 || error(
        "v41 structurally coupled target-module count changed")
    target_ids = Set(String(item["module_id"]) for item in target_modules)
    rejection_module_ids = Set{String}()
    for item in rejections
        push!(rejection_module_ids, String(item["first_module_id"]))
        push!(rejection_module_ids, String(item["second_module_id"]))
    end
    issubset(target_ids, rejection_module_ids) || error(
        "v41 structural rejections do not cover all 23 target modules")

    complete_assemblies, compatible_count = _v41_complete_assemblies(context)
    background_by_graph = Dict(item.graph_hash => item for item in
        context.assemblies)
    response_backgrounds = Set(String(item["graph_hash"]) for item in responses)
    all(String(item["source_background_graph_hash"]) in response_backgrounds
        for item in rejections) || error(
        "v41 rejection background is not in the sealed v36 frontier")

    candidate_cache = Dict{Tuple{String,String,Int,String},
        Vector{TopologyAssemblyV17}}()
    response_cache = Dict{String,Dict{String,Any}}()
    trials = Dict{String,Any}[]
    for rejection in sort!(rejections; by = item -> String(
            item["rejection_hash"]))
        background_hash = String(rejection["source_background_graph_hash"])
        haskey(background_by_graph, background_hash) || error(
            "v41 background graph is missing from the v20 context")
        background = background_by_graph[background_hash]
        family = String(rejection["family"])
        layer = String(rejection["layer"])
        layer_index = _v40_layer_index(layer)
        first_module = String(rejection["first_module_id"])
        second_module = String(rejection["second_module_id"])
        first_key = (family, background.mission_contract_id, layer_index,
            first_module)
        second_key = (family, background.mission_contract_id, layer_index,
            second_module)
        first_candidates = get!(candidate_cache, first_key) do
            _v41_module_candidates(complete_assemblies, family,
                background.mission_contract_id, layer_index, first_module)
        end
        second_candidates = get!(candidate_cache, second_key) do
            _v41_module_candidates(complete_assemblies, family,
                background.mission_contract_id, layer_index, second_module)
        end
        selection = _v41_select_minimum_pair(background, layer_index,
            first_candidates, second_candidates)
        first_response = _v41_response!(response_cache, context,
            selection.first, rejection, layer, first_module,
            selection.first_source_layers; halton_skip = Int(halton_skip))
        second_response = _v41_response!(response_cache, context,
            selection.second, rejection, layer, second_module,
            selection.second_source_layers; halton_skip = Int(halton_skip))
        push!(trials, _v41_trial_record(rejection, selection,
            first_response, second_response))
    end
    sort!(trials; by = item -> (String(item["family"]),
        String(item["intervened_layer"]),
        String(item["source_background_graph_hash"]),
        String(item["first_module_id"]), String(item["second_module_id"])))
    response_records = collect(values(response_cache))
    sort!(response_records; by = item -> (String(item["family"]),
        String(item["intervened_layer"]),
        String(item["source_background_graph_hash"]),
        String(item["intervened_module_id"]), String(item["graph_hash"])))

    pair_groups = Dict{String,Vector{Dict{String,Any}}}()
    for item in trials
        pair_key = canonical_hash(Dict{String,Any}(
            "family" => item["family"],
            "layer" => item["intervened_layer"],
            "module_ids" => sort!([String(item["first_module_id"]),
                String(item["second_module_id"])])))
        push!(get!(pair_groups, pair_key, Dict{String,Any}[]), item)
    end
    pair_records = Dict{String,Any}[]
    for (pair_key, items) in sort!(collect(pair_groups); by = first)
        first_item = first(items)
        signatures = unique((String(item["response_classification"]),
            join(item["comparison_changed_layer_ids"], ","),
            join(item["changed_named_margin_ids"], ","),
            join(item["changed_raw_gate_ids"], ","),
            join(item["changed_evidence_requirement_ids"], ","))
            for item in items)
        push!(pair_records, Dict{String,Any}(
            "pair_key" => pair_key,
            "family" => first_item["family"],
            "layer" => first_item["intervened_layer"],
            "module_ids" => sort!([String(first_item["first_module_id"]),
                String(first_item["second_module_id"])]),
            "repaired_trial_count" => length(items),
            "matched_single_layer_comparison_count" => count(item ->
                item["comparison_changed_layer_count"] == 1, items),
            "coupled_block_comparison_count" => count(item ->
                item["comparison_changed_layer_count"] > 1, items),
            "route_effect_trial_count" => count(item -> item[
                "dependency_closed_route_effect_identified"] === true, items),
            "raw_gate_variation_trial_count" => count(item -> item[
                "raw_gate_dictionary_identical"] === false, items),
            "background_route_invariant" => length(signatures) == 1))
    end

    target_results = Dict{String,Any}[]
    for target in sort!(target_modules; by = item -> String(item["module_id"]))
        module_id = String(target["module_id"])
        related = [item for item in trials if item["first_module_id"] ==
            module_id || item["second_module_id"] == module_id]
        isempty(related) && error("v41 target module has no repaired trial")
        matched = count(item -> item["comparison_changed_layer_count"] == 1,
            related)
        coupled = length(related) - matched
        effects = count(item -> item[
            "dependency_closed_route_effect_identified"] === true, related)
        evaluated = count(item -> item[
            "full_evaluated_response_identical"] === false, related)
        evidence = count(item -> item[
            "evidence_gap_ledger_identical"] === false, related)
        gates = count(item -> item[
            "raw_gate_dictionary_identical"] === false, related)
        route = effects == 0 ?
            "dependency_closed_block_alias_observed" :
            matched > 0 ?
            "dependency_closed_matched_route_observed" :
            "dependency_closed_coupled_block_route_observed"
        push!(target_results, Dict{String,Any}(
            "module_id" => module_id,
            "family" => String(target["family"]),
            "layer" => String(target["layer"]),
            "source_ids" => _v40_strings(target["source_ids"]),
            "required_evaluators" => _v40_strings(
                target["required_evaluators"]),
            "v40_controlled_route_classification" => String(target[
                "controlled_route_classification"]),
            "repaired_trial_count" => length(related),
            "matched_single_layer_comparison_count" => matched,
            "coupled_block_comparison_count" => coupled,
            "evaluated_response_variation_trial_count" => evaluated,
            "evidence_variation_trial_count" => evidence,
            "raw_gate_variation_trial_count" => gates,
            "route_effect_trial_count" => effects,
            "dependency_closed_route_classification" => route,
            "single_module_absolute_physical_causality_proven" => false,
            "physical_infeasibility_proven" => false,
            "gate_credit_authorized" => false,
            "medium_fidelity_authorized" => false,
            "old_domain_scale_up_authorized" => false,
            "promotion_credit" => 0))
    end
    route_counts = _v33_count_strings(String[item[
        "dependency_closed_route_classification"] for item in target_results])
    comparison_histogram = _v33_count_strings(String[
        string(item["comparison_changed_layer_count"]) for item in trials])
    support_histogram = _v33_count_strings(String[
        string(item["support_adjustment_layer_count"]) for item in trials])
    return Dict{String,Any}(
        "complete_compatible_assembly_count" => compatible_count,
        "source_v40_structural_rejection_count" => length(rejections),
        "target_structurally_coupled_module_count" => length(target_results),
        "unique_module_pair_count" => length(pair_records),
        "accepted_dependency_closed_trial_count" => length(trials),
        "unresolved_dependency_closed_trial_count" => 0,
        "unique_dependency_closed_response_count" => length(response_records),
        "matched_single_layer_comparison_count" => count(item ->
            item["comparison_changed_layer_count"] == 1, trials),
        "coupled_block_comparison_count" => count(item ->
            item["comparison_changed_layer_count"] > 1, trials),
        "comparison_changed_layer_count_histogram" => comparison_histogram,
        "support_adjustment_layer_count_histogram" => support_histogram,
        "maximum_comparison_changed_layer_count" => maximum(Int(item[
            "comparison_changed_layer_count"]) for item in trials),
        "evaluated_response_variation_trial_count" => count(item -> item[
            "full_evaluated_response_identical"] === false, trials),
        "evidence_variation_trial_count" => count(item -> item[
            "evidence_gap_ledger_identical"] === false, trials),
        "raw_gate_variation_trial_count" => count(item -> item[
            "raw_gate_dictionary_identical"] === false, trials),
        "full_response_and_evidence_alias_trial_count" => count(item ->
            item["full_evaluated_response_identical"] === true &&
            item["evidence_gap_ledger_identical"] === true, trials),
        "dependency_closed_route_effect_trial_count" => count(item -> item[
            "dependency_closed_route_effect_identified"] === true, trials),
        "target_module_route_classification_counts" => route_counts,
        "proxy_five_gate_passed_response_count" => count(item -> item[
            "proxy_five_gate_passed"] === true, response_records),
        "proxy_coverage_complete_response_count" => count(item -> item[
            "proxy_coverage_complete"] === true, response_records),
        "medium_fidelity_candidate_eligible_response_count" => count(item ->
            item["medium_fidelity_candidate_eligible"] === true,
            response_records),
        "new_numerical_formula_implemented" => false,
        "single_module_absolute_physical_causality_claimed" => false,
        "physical_infeasibility_claimed" => false,
        "gate_credit_authorized_count" => 0,
        "medium_fidelity_authorized_count" => 0,
        "old_domain_scale_up_authorized" => false,
        "promotion_count" => 0,
        "pair_records" => pair_records,
        "target_module_results" => target_results,
        "trial_records" => trials,
        "response_records" => response_records,
        "claim_boundary" => _V41_CLAIM_BOUNDARY)
end
