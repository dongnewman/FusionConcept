const _V40_CLAIM_BOUNDARY =
    "V40 converts the fifty v36 multilayer co-variation modules into explicit same-sample, fixed-four-layer counterfactual trials. Within each family and topology layer it evaluates every pair of implicated module choices on every compatible sealed frontier background, preserving the other four modules and the paired Halton sample. A changed fidelity-0 response or evidence ledger identifies a controlled module-choice route only inside the existing proxy and declared evidence system. It is not proof of physical causality, superiority, robustness, C1, medium-fidelity validity, or reactor feasibility. Structural rejection is retained, missing evidence is never zero risk, and no old-domain scale-up or promotion is authorized."

_v40_strings(value) = sort!(unique(String.(copy(value))))

function _v40_dict(raw)
    return Dict{String,Any}(String(key) => _plain_json(value)
        for (key, value) in raw)
end

function _v40_layer_index(layer::String)
    index = findfirst(==(Symbol(layer)), collect(_V17_LAYERS))
    index === nothing && throw(ArgumentError("v40 unknown topology layer $layer"))
    return Int(index)
end

function _v40_module_pairs(module_ids::Vector{String})
    pairs = Tuple{String,String}[]
    for first_index in 1:(length(module_ids) - 1)
        for second_index in (first_index + 1):length(module_ids)
            push!(pairs, (module_ids[first_index], module_ids[second_index]))
        end
    end
    return pairs
end

function _v40_build_assembly(context::RecoverableCrossTopologyContextV20,
        module_ids::Vector{String}, expected_family::String)
    modules = [context.modules[id] for id in module_ids]
    validation = validate_topology_assembly_v17(modules)
    if !validation.valid
        return nothing, copy(validation.reason_codes)
    end
    assembly = _v17_build_assembly(modules, validation)
    assembly.family == expected_family || return nothing,
        ["counterfactual_family_drift:$(assembly.family):$expected_family"]
    return assembly, String[]
end

function _v40_evaluate_assembly(context::RecoverableCrossTopologyContextV20,
        assembly::TopologyAssemblyV17, source_candidate_index::Int,
        sample_ordinal::Int; halton_skip::Int = 4096)
    values_u = _v20_unit_vector(sample_ordinal, length(_V20_HALTON_PRIMES);
        skip = halton_skip)
    proxy, evaluator_id, projection_id, limitations = _v20_projection(
        context.compiler_context, assembly, values_u)
    annotated = _v18_annotate_proxy(proxy, assembly, context.modules)
    genome = _v20_sample_annotation(annotated, assembly, sample_ordinal)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError(
        "v40 counterfactual genome invalid: " * join(report.errors, "; ")))
    family_report = assembly.family == "inertial_confinement_fusion" ?
        validate_family(laser_icf_family_registry_v15(), genome) :
        validate_family(default_family_registry(), genome)
    family_report.valid || throw(ArgumentError(
        "v40 counterfactual family invalid: " *
        join(family_report.errors, "; ")))
    mission_contract_for(default_mission_contract_registry(), genome).id ==
        assembly.mission_contract_id || throw(ArgumentError(
        "v40 counterfactual mission contract drifted"))
    declared = _v20_declared_requirements(context, assembly)
    issubset(Set(declared), Set(_requirements(genome))) ||
        throw(ArgumentError(
            "v40 counterfactual genome lost evaluator requirements"))
    warnings = sort!(unique(vcat(report.warnings, family_report.warnings)))
    compiled = CompiledAttributeGenomeV18(assembly.assembly_id,
        assembly.graph_hash, assembly.family, assembly.mission_contract_id,
        copy(assembly.module_ids), genome, evaluator_id, projection_id,
        sort!(unique(limitations)), declared, warnings)
    prescreen = _v18_prescreen(compiled, context.evaluators,
        context.evaluator_registry)
    candidate = CrossTopologyCandidateV20(source_candidate_index, 0,
        sample_ordinal, prescreen)
    raw = _v34_raw_result(context, candidate)
    nominal = get(raw, "nominal", Dict{String,Any}())
    raw_margins = get(nominal, "margins", nothing)
    raw_margins isa AbstractDict || error(
        "v40 counterfactual result has no named-margin dictionary")
    margins = Dict{String,Float64}()
    for (name, raw_value) in raw_margins
        raw_value isa Real || error("v40 margin $name is not numeric")
        value = Float64(raw_value)
        isfinite(value) || error("v40 margin $name is not finite")
        margins[String(name)] = value
    end
    gates = Dict{String,Bool}()
    for (name, raw_value) in raw["gates"]
        raw_value isa Bool || error("v40 gate $name is not Boolean")
        gates[String(name)] = Bool(raw_value)
    end
    missing = sort!(copy(prescreen.missing_proxy_requirements))
    failed = Dict(name => value for (name, value) in margins if value < 0.0)
    evaluated_core = Dict{String,Any}(
        "named_margins" => margins,
        "raw_gates" => gates)
    return Dict{String,Any}(
        "source_candidate_index" => source_candidate_index,
        "sample_ordinal" => sample_ordinal,
        "family" => assembly.family,
        "graph_hash" => assembly.graph_hash,
        "physics_hash" => genome.physics_hash,
        "module_ids" => copy(assembly.module_ids),
        "evaluator_id" => evaluator_id,
        "projection_id" => projection_id,
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
        "proxy_applicable" => prescreen.proxy_applicable,
        "proxy_five_gate_passed" => prescreen.proxy_five_gate_passed,
        "proxy_coverage_complete" => prescreen.proxy_coverage_complete,
        "medium_fidelity_candidate_eligible" =>
            prescreen.medium_fidelity_candidate_eligible,
        "topology_graph_errors" => copy(prescreen.topology_graph_errors),
        "counterfactual_fixed_background_evaluation" => true,
        "old_domain_scale_up_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promoted" => false,
        "claim_level" => "C0_controlled_fidelity0_module_choice_response")
end

function _v40_changed_numeric_keys(first::AbstractDict, second::AbstractDict)
    keys_union = sort!(collect(union(Set(keys(first)), Set(keys(second)))))
    return String[key for key in keys_union if
        !haskey(first, key) || !haskey(second, key) ||
        Float64(first[key]) != Float64(second[key])]
end

function _v40_changed_boolean_keys(first::AbstractDict, second::AbstractDict)
    keys_union = sort!(collect(union(Set(keys(first)), Set(keys(second)))))
    return String[key for key in keys_union if
        !haskey(first, key) || !haskey(second, key) ||
        Bool(first[key]) != Bool(second[key])]
end

function _v40_trial_record(family::String, layer::String,
        background_record::AbstractDict, first_module::String,
        second_module::String, first_response::AbstractDict,
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
    trial_core = Dict{String,Any}(
        "family" => family,
        "layer" => layer,
        "source_background_graph_hash" => String(
            background_record["graph_hash"]),
        "source_candidate_index" => Int(background_record["candidate_index"]),
        "sample_ordinal" => Int(first_response["sample_ordinal"]),
        "first_module_id" => first_module,
        "second_module_id" => second_module,
        "first_graph_hash" => String(first_response["graph_hash"]),
        "second_graph_hash" => String(second_response["graph_hash"]),
        "first_response_signature_hash" => String(first_response[
            "full_evaluated_response_signature_hash"]),
        "second_response_signature_hash" => String(second_response[
            "full_evaluated_response_signature_hash"]),
        "first_evidence_signature_hash" => String(first_response[
            "evidence_gap_signature_hash"]),
        "second_evidence_signature_hash" => String(second_response[
            "evidence_gap_signature_hash"]))
    item = merge(trial_core, classification, Dict{String,Any}(
        "changed_named_margin_ids" => changed_margins,
        "changed_named_margin_count" => length(changed_margins),
        "changed_raw_gate_ids" => changed_gates,
        "changed_raw_gate_count" => length(changed_gates),
        "changed_evidence_requirement_ids" => changed_requirements,
        "changed_evidence_requirement_count" => length(changed_requirements),
        "all_other_layers_fixed" => true,
        "paired_halton_sample_fixed" => true,
        "single_layer_module_choice_effect_identified" =>
            !(classification["full_evaluated_response_identical"] &&
              classification["evidence_gap_ledger_identical"]),
        "single_module_absolute_physical_causality_proven" => false,
        "gate_credit_authorized" => false,
        "medium_fidelity_authorized" => false,
        "old_domain_scale_up_authorized" => false,
        "promoted" => false))
    item["trial_hash"] = canonical_hash(trial_core)
    return item
end

function multilayer_fixed_background_ablation_v40(
        context::RecoverableCrossTopologyContextV20,
        v36_responses_raw::AbstractVector, v36_routes_raw::AbstractVector;
        halton_skip::Integer = 4096)
    responses = [_v40_dict(item) for item in v36_responses_raw]
    routes = [_v40_dict(item) for item in v36_routes_raw]
    length(responses) == 55 || throw(ArgumentError(
        "v40 requires the 55 sealed v36 responses"))
    length(routes) == 74 || throw(ArgumentError(
        "v40 requires the 74 sealed v36 module routes"))
    target_routes = [item for item in routes if item["repair_priority_tier"] ==
        "tier_2_co_difference_with_compiled_or_evidence_change"]
    length(target_routes) == 50 || error(
        "v40 multilayer target-module count changed")
    all(Int(item["family_count"]) == 1 for item in target_routes) || error(
        "v40 requires every multilayer module to belong to one family")
    route_by_module = Dict(String(item["module_id"]) => item
        for item in target_routes)
    length(route_by_module) == 50 || error(
        "v40 multilayer target module IDs are not unique")

    assembly_by_graph = Dict(item.graph_hash => item for item in
        context.assemblies)
    all(haskey(assembly_by_graph, String(item["graph_hash"]))
        for item in responses) || error(
        "v40 sealed frontier graph is missing from the v20 context")
    responses_by_family = Dict{String,Vector{Dict{String,Any}}}()
    for item in responses
        push!(get!(responses_by_family, String(item["family"]),
            Dict{String,Any}[]), item)
    end
    all(length(items) == 5 for items in values(responses_by_family)) || error(
        "v40 requires five sealed frontier graphs per family")

    grouped = Dict{Tuple{String,String},Vector{String}}()
    for item in target_routes
        family = only(_v40_strings(item["families"]))
        layer = String(item["layer"])
        push!(get!(grouped, (family, layer), String[]),
            String(item["module_id"]))
    end
    for ids in values(grouped)
        sort!(ids)
    end
    length(grouped) == 20 || error(
        "v40 family-layer intervention group count changed")
    module_pair_count = sum(binomial(length(ids), 2) for ids in values(grouped))
    module_pair_count == 41 || error(
        "v40 within-group module-choice pair count changed")

    response_records = Dict{String,Dict{String,Any}}()
    accepted_trials = Dict{String,Any}[]
    structural_rejections = Dict{String,Any}[]
    group_records = Dict{String,Any}[]
    planned_trial_count = 0
    valid_intervention_count = 0
    invalid_intervention_count = 0
    for ((family, layer), module_ids) in sort!(collect(grouped);
            by = item -> (item.first[1], item.first[2]))
        layer_index = _v40_layer_index(layer)
        family_backgrounds = sort!(copy(responses_by_family[family]);
            by = item -> String(item["graph_hash"]))
        group_accepted = 0
        group_rejected = 0
        group_response_keys = Set{String}()
        for background in family_backgrounds
            background_modules = String.(copy(background["module_ids"]))
            sample_ordinal = cld(Int(background["candidate_index"]),
                length(context.assemblies))
            local_responses = Dict{String,Dict{String,Any}}()
            local_errors = Dict{String,Vector{String}}()
            for module_id in module_ids
                counterfactual_ids = copy(background_modules)
                counterfactual_ids[layer_index] = module_id
                assembly, errors = _v40_build_assembly(context,
                    counterfactual_ids, family)
                if assembly === nothing
                    local_errors[module_id] = errors
                    invalid_intervention_count += 1
                    continue
                end
                response = _v40_evaluate_assembly(context, assembly,
                    Int(background["candidate_index"]), sample_ordinal;
                    halton_skip = Int(halton_skip))
                response_key = canonical_hash(Dict{String,Any}(
                    "family" => family,
                    "layer" => layer,
                    "source_background_graph_hash" =>
                        String(background["graph_hash"]),
                    "sample_ordinal" => sample_ordinal,
                    "module_id" => module_id,
                    "counterfactual_graph_hash" => assembly.graph_hash))
                response["response_key"] = response_key
                response["intervened_layer"] = layer
                response["intervened_module_id"] = module_id
                response["source_background_graph_hash"] = String(
                    background["graph_hash"])
                response_records[response_key] = response
                local_responses[module_id] = response
                push!(group_response_keys, response_key)
                valid_intervention_count += 1
            end
            for (first_module, second_module) in _v40_module_pairs(module_ids)
                planned_trial_count += 1
                if !haskey(local_responses, first_module) ||
                        !haskey(local_responses, second_module)
                    rejection_core = Dict{String,Any}(
                        "family" => family,
                        "layer" => layer,
                        "source_background_graph_hash" =>
                            String(background["graph_hash"]),
                        "source_candidate_index" =>
                            Int(background["candidate_index"]),
                        "sample_ordinal" => sample_ordinal,
                        "first_module_id" => first_module,
                        "second_module_id" => second_module,
                        "first_reason_codes" => get(local_errors,
                            first_module, String[]),
                        "second_reason_codes" => get(local_errors,
                            second_module, String[]))
                    rejection = deepcopy(rejection_core)
                    rejection["rejection_hash"] = canonical_hash(rejection_core)
                    rejection["structural_counterfactual_accepted"] = false
                    rejection["physical_infeasibility_proven"] = false
                    push!(structural_rejections, rejection)
                    group_rejected += 1
                    continue
                end
                trial = _v40_trial_record(family, layer, background,
                    first_module, second_module,
                    local_responses[first_module],
                    local_responses[second_module])
                push!(accepted_trials, trial)
                group_accepted += 1
            end
        end
        push!(group_records, Dict{String,Any}(
            "family" => family,
            "layer" => layer,
            "module_ids" => copy(module_ids),
            "module_count" => length(module_ids),
            "module_choice_pair_count" => binomial(length(module_ids), 2),
            "frontier_background_count" => length(family_backgrounds),
            "planned_trial_count" =>
                binomial(length(module_ids), 2) * length(family_backgrounds),
            "accepted_trial_count" => group_accepted,
            "structurally_rejected_trial_count" => group_rejected,
            "unique_counterfactual_response_count" =>
                length(group_response_keys)))
    end
    planned_trial_count == 205 || error(
        "v40 planned fixed-background trial count changed")
    sort!(accepted_trials; by = item -> (String(item["family"]),
        String(item["layer"]), String(item["source_background_graph_hash"]),
        String(item["first_module_id"]), String(item["second_module_id"])))
    sort!(structural_rejections; by = item -> (String(item["family"]),
        String(item["layer"]), String(item["source_background_graph_hash"]),
        String(item["first_module_id"]), String(item["second_module_id"])))
    counterfactual_responses = collect(values(response_records))
    sort!(counterfactual_responses; by = item -> (String(item["family"]),
        String(item["intervened_layer"]),
        String(item["source_background_graph_hash"]),
        String(item["intervened_module_id"])))

    module_results = Dict{String,Any}[]
    for module_id in sort!(collect(keys(route_by_module)))
        item = route_by_module[module_id]
        module_trials = [trial for trial in accepted_trials if
            trial["first_module_id"] == module_id ||
            trial["second_module_id"] == module_id]
        evaluated_variation = count(trial ->
            trial["full_evaluated_response_identical"] === false,
            module_trials)
        evidence_variation = count(trial ->
            trial["evidence_gap_ledger_identical"] === false,
            module_trials)
        gate_variation = count(trial ->
            trial["raw_gate_dictionary_identical"] === false,
            module_trials)
        route = isempty(module_trials) ?
            "structurally_non_intervenable_in_frontier_backgrounds" :
            evaluated_variation > 0 && evidence_variation > 0 ?
            "controlled_evaluated_and_evidence_route_observed" :
            evaluated_variation > 0 ?
            "controlled_evaluated_response_route_observed" :
            evidence_variation > 0 ?
            "controlled_evidence_route_observed" :
            "controlled_full_response_and_evidence_alias"
        push!(module_results, Dict{String,Any}(
            "module_id" => module_id,
            "family" => only(_v40_strings(item["families"])),
            "layer" => String(item["layer"]),
            "v36_observed_response_route" => String(
                item["observed_response_route"]),
            "source_ids" => _v40_strings(item["source_ids"]),
            "required_evaluators" => _v40_strings(
                item["required_evaluators"]),
            "accepted_fixed_background_trial_count" => length(module_trials),
            "evaluated_response_variation_trial_count" =>
                evaluated_variation,
            "evidence_variation_trial_count" => evidence_variation,
            "raw_gate_variation_trial_count" => gate_variation,
            "controlled_route_classification" => route,
            "single_module_absolute_physical_causality_proven" => false,
            "gate_credit_authorized" => false,
            "medium_fidelity_authorized" => false,
            "old_domain_scale_up_authorized" => false,
            "promotion_credit" => 0))
    end
    module_route_counts = _v33_count_strings(String[
        item["controlled_route_classification"] for item in module_results])
    pair_background_groups = Dict{String,Vector{Dict{String,Any}}}()
    for trial in accepted_trials
        pair_key = canonical_hash(Dict{String,Any}(
            "family" => trial["family"], "layer" => trial["layer"],
            "module_ids" => sort!([String(trial["first_module_id"]),
                String(trial["second_module_id"])])))
        push!(get!(pair_background_groups, pair_key, Dict{String,Any}[]), trial)
    end
    background_invariant_pair_count = count(values(pair_background_groups)) do trials
        length(unique((String(item["response_classification"]),
            join(item["changed_named_margin_ids"], ","),
            join(item["changed_raw_gate_ids"], ","),
            join(item["changed_evidence_requirement_ids"], ","))
            for item in trials)) == 1
    end
    return Dict{String,Any}(
        "target_module_count" => length(module_results),
        "family_layer_group_count" => length(group_records),
        "within_group_module_choice_pair_count" => module_pair_count,
        "frontier_backgrounds_per_family" => 5,
        "planned_fixed_background_trial_count" => planned_trial_count,
        "accepted_fixed_background_trial_count" => length(accepted_trials),
        "structurally_rejected_trial_count" => length(structural_rejections),
        "valid_counterfactual_intervention_count" => valid_intervention_count,
        "invalid_counterfactual_intervention_count" => invalid_intervention_count,
        "unique_counterfactual_response_count" =>
            length(counterfactual_responses),
        "evaluated_response_variation_trial_count" => count(trial ->
            trial["full_evaluated_response_identical"] === false,
            accepted_trials),
        "evidence_variation_trial_count" => count(trial ->
            trial["evidence_gap_ledger_identical"] === false,
            accepted_trials),
        "raw_gate_variation_trial_count" => count(trial ->
            trial["raw_gate_dictionary_identical"] === false,
            accepted_trials),
        "full_response_and_evidence_alias_trial_count" => count(trial ->
            trial["full_evaluated_response_identical"] === true &&
            trial["evidence_gap_ledger_identical"] === true,
            accepted_trials),
        "controlled_module_choice_effect_trial_count" => count(trial ->
            trial["single_layer_module_choice_effect_identified"] === true,
            accepted_trials),
        "module_route_classification_counts" => module_route_counts,
        "background_invariant_module_pair_count" =>
            background_invariant_pair_count,
        "background_evaluated_module_pair_count" =>
            length(pair_background_groups),
        "single_module_absolute_physical_causality_claimed" => false,
        "gate_credit_authorized_count" => 0,
        "medium_fidelity_authorized_count" => 0,
        "old_domain_scale_up_authorized" => false,
        "promotion_count" => 0,
        "group_records" => group_records,
        "module_results" => module_results,
        "accepted_trials" => accepted_trials,
        "structural_rejections" => structural_rejections,
        "counterfactual_responses" => counterfactual_responses,
        "claim_boundary" => _V40_CLAIM_BOUNDARY)
end
