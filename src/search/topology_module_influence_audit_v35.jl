const _V35_CLAIM_BOUNDARY =
    "V35 compares graph pairs within each sealed v34 family frontier and identifies module co-differences whose complete 24-coordinate primary-margin response signatures remain identical. Pairwise co-difference is not a single-module causal ablation unless explicitly marked as a one-layer substitution. The audit creates a topology-to-evaluator repair queue only; it changes no topology, proxy, gate, evidence level, robustness result, feasibility status, family ranking, C1 status, medium-fidelity authorization, or promotion."

function _v35_module_metadata(catalog::Vector{TopologyModuleV17})
    return Dict(item.id => Dict{String,Any}(
        "module_id" => item.id,
        "layer" => String(item.layer),
        "description" => item.description,
        "required_evaluators" => copy(item.required_evaluators),
        "source_ids" => copy(item.source_ids)) for item in catalog)
end

function _v35_pair_record(first_record::AbstractDict,
        second_record::AbstractDict, metadata::AbstractDict)
    first_record["family"] == second_record["family"] || throw(ArgumentError(
        "v35 pair crossed families"))
    first_record["graph_hash"] != second_record["graph_hash"] ||
        throw(ArgumentError("v35 pair requires distinct graph hashes"))
    first_modules = Set(String.(first_record["module_ids"]))
    second_modules = Set(String.(second_record["module_ids"]))
    first_only = sort!(collect(setdiff(first_modules, second_modules)))
    second_only = sort!(collect(setdiff(second_modules, first_modules)))
    differences = sort!(vcat(first_only, second_only))
    isempty(differences) && error(
        "v35 distinct graph hashes have no module difference")
    all(id -> haskey(metadata, id), differences) || error(
        "v35 module metadata is incomplete")
    differing_layers = sort!(unique(String(metadata[id]["layer"])
        for id in differences))
    response_same = first_record["primary_response_signature_hash"] ==
        second_record["primary_response_signature_hash"]
    gene_path_same = first_record["gene_path_signature_hash"] ==
        second_record["gene_path_signature_hash"]
    first_missing = Set(String.(first_record["missing_proxy_requirements"]))
    second_missing = Set(String.(second_record["missing_proxy_requirements"]))
    missing_difference = sort!(collect(symdiff(first_missing, second_missing)))
    single_layer = length(first_only) == 1 && length(second_only) == 1 &&
        length(differing_layers) == 1
    pair_core = Dict{String,Any}(
        "family" => String(first_record["family"]),
        "first_graph_hash" => String(first_record["graph_hash"]),
        "second_graph_hash" => String(second_record["graph_hash"]),
        "first_candidate_index" => Int(first_record["candidate_index"]),
        "second_candidate_index" => Int(second_record["candidate_index"]),
        "first_only_modules" => first_only,
        "second_only_modules" => second_only,
        "module_symmetric_difference" => differences,
        "module_symmetric_difference_count" => length(differences),
        "differing_layers" => differing_layers,
        "single_layer_substitution" => single_layer,
        "primary_margin_id" => String(first_record["primary_margin_id"]),
        "primary_response_signature_identical" => response_same,
        "gene_path_signature_identical" => gene_path_same,
        "missing_requirement_symmetric_difference" => missing_difference,
        "missing_requirement_signature_identical" =>
            isempty(missing_difference),
        "topology_primary_response_alias_pair" => response_same,
        "single_layer_alias_pair" => single_layer && response_same,
        "module_causal_effect_claimed" => false)
    item = deepcopy(pair_core)
    item["pair_hash"] = canonical_hash(pair_core)
    return item
end

function topology_module_influence_audit_v35(v34_records::AbstractVector,
        catalog::Vector{TopologyModuleV17}; expected_families::Integer = 11,
        expected_per_family::Integer = 5)
    rows = [Dict{String,Any}(String(key) => _plain_json(value)
        for (key, value) in record) for record in v34_records]
    length(rows) == Int(expected_families) * Int(expected_per_family) ||
        throw(ArgumentError("v35 input frontier size changed"))
    all(row -> row["diagnostic_proxy_sensitivity_authorized"] === true &&
        row["promoted"] === false, rows) || throw(ArgumentError(
        "v35 requires sealed unpromoted v34 records"))
    metadata = _v35_module_metadata(catalog)
    families = sort!(unique(String(row["family"]) for row in rows))
    length(families) == Int(expected_families) || throw(ArgumentError(
        "v35 family count changed"))
    pairs = Dict{String,Any}[]
    family_summaries = Dict{String,Any}()
    for family in families
        family_rows = sort!([row for row in rows if row["family"] == family];
            by = row -> String(row["graph_hash"]))
        length(family_rows) == Int(expected_per_family) || throw(ArgumentError(
            "v35 per-family record count changed for $family"))
        family_pairs = Dict{String,Any}[]
        for first_index in 1:(length(family_rows) - 1)
            for second_index in (first_index + 1):length(family_rows)
                item = _v35_pair_record(family_rows[first_index],
                    family_rows[second_index], metadata)
                push!(pairs, item); push!(family_pairs, item)
            end
        end
        expected_pairs = binomial(Int(expected_per_family), 2)
        length(family_pairs) == expected_pairs || error(
            "v35 pair count changed for $family")
        implicated = sort!(unique(String(module_id) for pair in family_pairs
            for module_id in pair["module_symmetric_difference"]))
        family_summaries[family] = Dict{String,Any}(
            "graph_count" => length(family_rows),
            "graph_pair_count" => length(family_pairs),
            "primary_response_alias_pair_count" => count(pair ->
                pair["topology_primary_response_alias_pair"] === true,
                family_pairs),
            "single_layer_substitution_pair_count" => count(pair ->
                pair["single_layer_substitution"] === true, family_pairs),
            "single_layer_alias_pair_count" => count(pair ->
                pair["single_layer_alias_pair"] === true, family_pairs),
            "gene_path_signature_difference_pair_count" => count(pair ->
                pair["gene_path_signature_identical"] === false,
                family_pairs),
            "missing_requirement_difference_pair_count" => count(pair ->
                pair["missing_requirement_signature_identical"] === false,
                family_pairs),
            "implicated_module_count" => length(implicated),
            "implicated_modules" => implicated)
    end
    module_stats = Dict{String,Dict{String,Any}}()
    for pair in pairs, module_id in pair["module_symmetric_difference"]
        id = String(module_id)
        item = get!(module_stats, id, Dict{String,Any}(
            "module_id" => id,
            "layer" => metadata[id]["layer"],
            "description" => metadata[id]["description"],
            "required_evaluators" => metadata[id]["required_evaluators"],
            "source_ids" => metadata[id]["source_ids"],
            "families" => Set{String}(),
            "co_difference_pair_count" => 0,
            "primary_response_alias_pair_count" => 0,
            "single_layer_alias_pair_count" => 0,
            "gene_path_difference_pair_count" => 0,
            "missing_requirement_difference_pair_count" => 0))
        push!(item["families"], String(pair["family"]))
        item["co_difference_pair_count"] += 1
        pair["topology_primary_response_alias_pair"] === true &&
            (item["primary_response_alias_pair_count"] += 1)
        pair["single_layer_alias_pair"] === true &&
            (item["single_layer_alias_pair_count"] += 1)
        pair["gene_path_signature_identical"] === false &&
            (item["gene_path_difference_pair_count"] += 1)
        pair["missing_requirement_signature_identical"] === false &&
            (item["missing_requirement_difference_pair_count"] += 1)
    end
    module_queue = Dict{String,Any}[]
    for item in values(module_stats)
        single_layer_count = Int(item["single_layer_alias_pair_count"])
        gene_count = Int(item["gene_path_difference_pair_count"])
        missing_count = Int(item["missing_requirement_difference_pair_count"])
        tier = single_layer_count > 0 ? "tier_1_matched_layer_alias" :
            (gene_count > 0 || missing_count > 0) ?
            "tier_2_co_difference_with_compiled_or_evidence_change" :
            "tier_3_co_difference_without_observed_primary_influence"
        action = single_layer_count > 0 ?
            "add_single_module_candidate_specific_margin_or_solver_then_repeat_matched_ablation" :
            missing_count > 0 ?
            "bind_declared_evaluator_requirement_or_mark_module_hard_unknown" :
            gene_count > 0 ?
            "connect_existing_genome_path_to_candidate_specific_margin_or_solver" :
            "compile_module_physics_or_remove_it_from_ranked_topology_search"
        push!(module_queue, Dict{String,Any}(
            "module_id" => item["module_id"],
            "layer" => item["layer"],
            "description" => item["description"],
            "required_evaluators" => item["required_evaluators"],
            "source_ids" => item["source_ids"],
            "families" => sort!(collect(item["families"])),
            "family_count" => length(item["families"]),
            "co_difference_pair_count" => item["co_difference_pair_count"],
            "primary_response_alias_pair_count" =>
                item["primary_response_alias_pair_count"],
            "single_layer_alias_pair_count" => single_layer_count,
            "gene_path_difference_pair_count" => gene_count,
            "missing_requirement_difference_pair_count" => missing_count,
            "repair_priority_tier" => tier,
            "required_action" => action,
            "single_module_causal_effect_proven" => false))
    end
    sort!(module_queue; by = item -> (
        String(item["repair_priority_tier"]),
        -Int(item["single_layer_alias_pair_count"]),
        -Int(item["primary_response_alias_pair_count"]),
        String(item["module_id"])))
    sort!(pairs; by = pair -> (String(pair["family"]),
        String(pair["first_graph_hash"]), String(pair["second_graph_hash"])))
    return Dict{String,Any}(
        "input_record_count" => length(rows),
        "family_count" => length(families),
        "graphs_per_family" => Int(expected_per_family),
        "graph_pair_count" => length(pairs),
        "primary_response_alias_pair_count" => count(pair ->
            pair["topology_primary_response_alias_pair"] === true, pairs),
        "single_layer_substitution_pair_count" => count(pair ->
            pair["single_layer_substitution"] === true, pairs),
        "single_layer_alias_pair_count" => count(pair ->
            pair["single_layer_alias_pair"] === true, pairs),
        "gene_path_signature_difference_pair_count" => count(pair ->
            pair["gene_path_signature_identical"] === false, pairs),
        "missing_requirement_difference_pair_count" => count(pair ->
            pair["missing_requirement_signature_identical"] === false, pairs),
        "implicated_module_count" => length(module_queue),
        "tier_1_module_count" => count(item ->
            item["repair_priority_tier"] == "tier_1_matched_layer_alias",
            module_queue),
        "family_summaries" => family_summaries,
        "graph_pairs" => pairs,
        "module_repair_queue" => module_queue,
        "topology_to_primary_proxy_binding_complete" => false,
        "old_domain_scale_up_authorized" => false,
        "module_causal_effect_claimed" => false,
        "promotion_count" => 0,
        "medium_fidelity_authorized_count" => 0,
        "claim_boundary" => _V35_CLAIM_BOUNDARY)
end
