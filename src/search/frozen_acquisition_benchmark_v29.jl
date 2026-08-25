const _V29_ALGORITHM_IDS = (
    "stratified_blind_halton",
    "failure_frontier_qd",
    "uncertainty_only",
    "hierarchical_gate_v14_style",
)

const _V29_CLAIM_BOUNDARY =
    "V29 is a preregistered five-batch acquisition benchmark over the sealed v12/v13 causal-path domain. Labels from each frozen batch remain hidden until deterministic selection is complete. Four algorithms receive equal explicit-evaluation budgets. The benchmark measures fidelity-0 label discovery, diversity, calibration, and acquisition cost only. It is not a randomized physical experiment, does not validate transfer to the v17/v20 11-family grammar, cannot create C1 or medium-fidelity credit, and cannot establish concept feasibility or algorithmic superiority outside this bounded domain."

struct FrozenAcquisitionContextV29
    specs::Vector{CausalBridgeTopologySpecV12}
    structural::Dict{String,Genome}
    spec_by_key::Dict{String,CausalBridgeTopologySpecV12}
    contracts::Vector{SharedOuterEnvelopeContractV1}
    contract_by_id::Dict{String,SharedOuterEnvelopeContractV1}
    observations::Vector{Dict{String,Any}}
    primes::NTuple{18,Int}
    v13_pool_end::Int
    sealed_input_hash::String
end

function build_frozen_acquisition_context_v29(seeds::Vector{Genome},
        v12_artifact_raw, v13_artifact_raw)
    v12 = _plain_json(v12_artifact_raw)
    v13 = _plain_json(v13_artifact_raw)
    get(v12, "result_hash", "") ==
        "583fa8dacdafbd017db705fa4cb5a4f40b2eae1ad337ac14ec142844ce1f1bec" ||
        throw(ArgumentError("v29 requires sealed v12 evidence"))
    get(v13, "result_hash", "") ==
        "4ecf08031357668326a047dcb369a3bdc9e9f846ba66e2d5095a7db0c9afa7be" ||
        throw(ArgumentError("v29 requires sealed v13 evidence"))
    specs = _cbv12_topology_specs()
    structural = _cbv12_structural_bases(seeds)
    spec_by_key = Dict(_sav13_path_key(spec) => spec for spec in specs)
    contracts = shared_outer_envelope_contracts_v1()
    contract_by_id = Dict(contract.id => contract for contract in contracts)
    observations = Dict{String,Any}[]
    reconstruction_violations = 0
    for record in v12["causal_bridge_qd"]["records"]
        spec = _sav13_find_spec(record, spec_by_key)
        contract = contract_by_id[String(record["contract_id"])]
        values = Dict{String,Any}(String(key) => value for (key, value) in
            record["acquisition"]["features"])
        candidate = _cbv12_instantiate(structural[_cbv12_key(spec)], spec,
            values, contract)
        candidate.physics_hash == String(record["physics_hash"]) ||
            (reconstruction_violations += 1)
        push!(observations, _hgv14_observation(_sav13_path_key(spec),
            contract.id, values, record["evaluation"], "sealed_v12_elite",
            candidate.physics_hash, contract))
    end
    for field in ("blind_baseline_records", "active_records")
        for record in v13["safe_active_causal_discovery"][field]
            path_key = String(record["path_key"])
            spec = spec_by_key[path_key]
            contract = contract_by_id[String(record["contract_id"])]
            values = Dict{String,Any}(String(key) => value for (key, value) in
                record["features"])
            candidate = _cbv12_instantiate(structural[_cbv12_key(spec)], spec,
                values, contract)
            candidate.physics_hash == String(record["physics_hash"]) ||
                (reconstruction_violations += 1)
            push!(observations, _hgv14_observation(path_key, contract.id,
                values, record["evaluation"], "formal_v13_explicit",
                candidate.physics_hash, contract))
        end
    end
    reconstruction_violations == 0 || error(
        "v29 historical evidence reconstruction failed")
    v13_pool_end = _hgv14_v13_max_sequence(v13)
    input_hash = canonical_hash(Dict{String,Any}(
        "v12_result_hash" => v12["result_hash"],
        "v13_result_hash" => v13["result_hash"],
        "observation_hashes" => sort!(String[String(
            observation["physics_hash"]) for observation in observations]),
        "v13_pool_end" => v13_pool_end))
    return FrozenAcquisitionContextV29(specs, structural, spec_by_key,
        contracts, contract_by_id, observations,
        (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61),
        v13_pool_end, input_hash)
end

function _v29_candidates(context::FrozenAcquisitionContextV29,
        first_index::Int, count::Int)
    result = Dict{String,Any}[]
    for index in first_index:(first_index + count - 1)
        proposal = _sav13_candidate(index, context.structural, context.specs,
            context.contracts, context.primes)
        proposal["promotion_eligible"] = context.spec_by_key[
            String(proposal["path_key"])].promotion_eligible
        push!(result, proposal)
    end
    return result
end

function _v29_predict!(context::FrozenAcquisitionContextV29,
        candidates::Vector{Dict{String,Any}}, config)
    observations_by_path = Dict{String,Vector{Dict{String,Any}}}()
    candidates_by_path = Dict{String,Vector{Dict{String,Any}}}()
    for observation in context.observations
        push!(get!(observations_by_path, String(observation["path_key"]),
            Dict{String,Any}[]), observation)
    end
    for candidate in candidates
        push!(get!(candidates_by_path, String(candidate["path_key"]),
            Dict{String,Any}[]), candidate)
    end
    audits = Dict{String,Any}()
    for path_key in sort!(collect(keys(candidates_by_path)))
        audits[path_key] = _hgv14_predict_gate_models(
            observations_by_path[path_key], candidates_by_path[path_key],
            config)
    end
    return audits
end

function _v29_failure_frontier_rank(proposal::AbstractDict)
    hierarchy = proposal["hierarchical_acquisition"]
    exact_gate_count = Int(hierarchy["exact_gate_count"])
    five_ready = hierarchy["exact_nominal_five_ready"] === true
    promotion_ready = hierarchy["promotion_ready_before_robustness"] === true
    margin = clamp(Float64(proposal["nominal_minimum_margin"]), -1.0e6,
        1.0e6)
    return (-Int(promotion_ready), -Int(five_ready), -exact_gate_count,
        -margin, Int(proposal["sequence_index"]))
end

function _v29_uncertainty_rank(proposal::AbstractDict)
    predictions = proposal["hierarchical_acquisition"]["predicted_gates"]
    uncertainties = Float64[predictions[gate]["local_uncertainty"]
        for gate in _HGV14_GATE_IDS]
    distances = Float64[predictions[gate]["nearest_observation_distance"]
        for gate in _HGV14_GATE_IDS]
    return (-maximum(uncertainties), -sum(uncertainties) /
        length(uncertainties), -maximum(distances),
        Int(proposal["sequence_index"]))
end

function _v29_stratified_select(pool::Vector{Dict{String,Any}}, budget::Int,
        ranker::Function)
    by_stratum = Dict{String,Vector{Dict{String,Any}}}()
    for proposal in pool
        push!(get!(by_stratum, String(proposal["structural_stratum"]),
            Dict{String,Any}[]), proposal)
    end
    selected = Dict{String,Any}[]
    for stratum in sort!(collect(keys(by_stratum)))
        ranked = sort!(by_stratum[stratum]; by = ranker)
        push!(selected, first(ranked))
    end
    sort!(selected; by = ranker)
    selected = first(selected, min(budget, length(selected)))
    if length(selected) < budget
        selected_indices = Set(Int(item["sequence_index"]) for item in selected)
        remaining = filter(item -> !(Int(item["sequence_index"]) in
            selected_indices), pool)
        sort!(remaining; by = ranker)
        append!(selected, first(remaining,
            min(budget - length(selected), length(remaining))))
    end
    return selected
end

function _v29_prediction_compact(proposal::AbstractDict)
    predictions = proposal["hierarchical_acquisition"]["predicted_gates"]
    return Dict{String,Any}(gate => Dict{String,Any}(
        "probability" => predictions[gate]["local_pass_fraction"],
        "uncertainty" => predictions[gate]["local_uncertainty"],
        "nearest_distance" => predictions[gate]["nearest_observation_distance"])
        for gate in _HGV14_GATE_IDS)
end

function _v29_explicit_compact(context::FrozenAcquisitionContextV29,
        proposal::AbstractDict)
    path_key = String(proposal["path_key"])
    spec = context.spec_by_key[path_key]
    contract = context.contract_by_id[String(proposal["contract_id"])]
    candidate, result = _sav13_explicit(
        context.structural[_cbv12_key(spec)], spec, contract,
        proposal["features"], context.contracts)
    labels = _hgv14_gate_labels(result)
    promoted = spec.promotion_eligible &&
        result["all_five_gates_passed"] === true &&
        result["positive_net_power_closure_passed"] === true
    evaluation_hash = String(get(result, "full_evaluation_result_hash",
        get(result, "compact_result_hash", canonical_hash(result))))
    return Dict{String,Any}(
        "sequence_index" => Int(proposal["sequence_index"]),
        "structural_stratum" => String(proposal["structural_stratum"]),
        "path_key" => path_key,
        "contract_id" => String(proposal["contract_id"]),
        "core_family" => spec.core_family,
        "mechanism" => spec.mechanism,
        "anchor_only" => spec.anchor_only,
        "promotion_eligible" => spec.promotion_eligible,
        "physics_hash" => candidate.physics_hash,
        "evaluation_hash" => evaluation_hash,
        "explicit_gate_labels" => labels,
        "prediction" => _v29_prediction_compact(proposal),
        "promoted" => promoted,
        "surrogate_only_promotion" => false,
        "medium_fidelity_route" => promoted ?
            _cbv12_medium_fidelity_route(spec) : String[])
end

function _v29_binary_signature(labels::AbstractDict)
    return join(Int(round(Float64(labels[gate]))) for gate in _HGV14_GATE_IDS)
end

function _v29_metrics(records::Vector{<:AbstractDict})
    counts = Dict{String,Int}(gate => count(record -> Float64(
        record["explicit_gate_labels"][gate]) >= 0.5, records)
        for gate in _HGV14_GATE_IDS)
    brier = Dict{String,Float64}()
    for gate in _HGV14_GATE_IDS
        brier[gate] = sum((Float64(record["prediction"][gate]["probability"]) -
            Float64(record["explicit_gate_labels"][gate]))^2
            for record in records) / length(records)
    end
    signatures = Set(_v29_binary_signature(record["explicit_gate_labels"])
        for record in records)
    score = 8.0 * counts["five_gate"] +
        4.0 * counts["robustness"] + 2.0 * counts["positive_net"] +
        counts["physics"] + counts["engineering"] +
        0.25 * length(signatures)
    return Dict{String,Any}(
        "evaluation_count" => length(records),
        "gate_pass_counts" => counts,
        "discovery_score" => score,
        "family_count" => length(unique(String(record["core_family"])
            for record in records)),
        "path_count" => length(unique(String(record["path_key"])
            for record in records)),
        "structural_stratum_count" => length(unique(String(
            record["structural_stratum"]) for record in records)),
        "unique_gate_signature_count" => length(signatures),
        "gate_signatures" => sort!(collect(signatures)),
        "per_gate_brier" => brier,
        "mean_gate_brier" => sum(values(brier)) / length(brier),
        "promotion_count" => count(record -> record["promoted"] === true,
            records),
        "negative_anchor_promotion_count" => count(record ->
            record["anchor_only"] === true && record["promoted"] === true,
            records),
        "surrogate_only_promotion_count" => count(record ->
            record["surrogate_only_promotion"] === true, records))
end

function run_frozen_acquisition_batch_v29(
        context::FrozenAcquisitionContextV29; batch_id::Integer,
        sequence_skip::Integer, blind_samples::Integer = 360,
        proposal_pool_samples::Integer = 60_000,
        explicit_budget::Integer = 360, neighbor_count::Integer = 7,
        uncertainty_tiebreak_cap::Real = 0.25)
    baseline_start = context.v13_pool_end + Int(sequence_skip) + 1
    pool_start = baseline_start + Int(blind_samples)
    baseline = _v29_candidates(context, baseline_start, Int(blind_samples))
    pool = _v29_candidates(context, pool_start, Int(proposal_pool_samples))
    config = HierarchicalGateDiscoveryConfigV14(
        sequence_skip = Int(sequence_skip),
        blind_baseline_samples = Int(blind_samples),
        proposal_pool_samples = Int(proposal_pool_samples),
        active_batch_size = Int(explicit_budget),
        neighbor_count = Int(neighbor_count),
        uncertainty_tiebreak_cap = Float64(uncertainty_tiebreak_cap))
    audits = _v29_predict!(context, vcat(baseline, pool), config)
    selections = Dict{String,Vector{Dict{String,Any}}}(
        "stratified_blind_halton" => baseline,
        "failure_frontier_qd" => _v29_stratified_select(pool,
            Int(explicit_budget), _v29_failure_frontier_rank),
        "uncertainty_only" => _v29_stratified_select(pool,
            Int(explicit_budget), _v29_uncertainty_rank),
        "hierarchical_gate_v14_style" => _v29_stratified_select(pool,
            Int(explicit_budget), _hgv14_rank_key))
    all(length(selection) == explicit_budget for selection in
        values(selections)) || error("v29 selection budget drifted")
    evaluation_cache = Dict{Int,Dict{String,Any}}()
    records_by_algorithm = Dict{String,Vector{Dict{String,Any}}}()
    for algorithm in _V29_ALGORITHM_IDS
        records = Dict{String,Any}[]
        for proposal in selections[algorithm]
            index = Int(proposal["sequence_index"])
            record = get!(evaluation_cache, index) do
                _v29_explicit_compact(context, proposal)
            end
            # Predictions are selection-specific fields on an otherwise
            # deterministic candidate; copy before attaching them.
            item = deepcopy(record)
            item["prediction"] = _v29_prediction_compact(proposal)
            item["algorithm_id"] = algorithm
            item["batch_id"] = Int(batch_id)
            push!(records, item)
        end
        sort!(records; by = record -> String(record["physics_hash"]))
        records_by_algorithm[algorithm] = records
    end
    metrics = Dict(algorithm => _v29_metrics(records_by_algorithm[algorithm])
        for algorithm in _V29_ALGORITHM_IDS)
    baseline_score = Float64(metrics["stratified_blind_halton"][
        "discovery_score"])
    comparisons = Dict{String,Any}()
    for algorithm in _V29_ALGORITHM_IDS
        score = Float64(metrics[algorithm]["discovery_score"])
        comparisons[algorithm] = Dict{String,Any}(
            "score_difference_from_blind" => score - baseline_score,
            "strict_score_win_against_blind" => score > baseline_score,
            "score_tie_with_blind" => score == baseline_score,
            "five_gate_difference_from_blind" => metrics[algorithm][
                "gate_pass_counts"]["five_gate"] - metrics[
                    "stratified_blind_halton"]["gate_pass_counts"]["five_gate"],
            "positive_net_difference_from_blind" => metrics[algorithm][
                "gate_pass_counts"]["positive_net"] - metrics[
                    "stratified_blind_halton"]["gate_pass_counts"]["positive_net"])
    end
    selected_sets = Dict(algorithm => Set(Int(record["sequence_index"])
        for record in records_by_algorithm[algorithm]) for algorithm in
        _V29_ALGORITHM_IDS)
    overlaps = Dict{String,Int}()
    for left_index in eachindex(_V29_ALGORITHM_IDS)
        for right_index in (left_index + 1):length(_V29_ALGORITHM_IDS)
            left_index < right_index || continue
            left = _V29_ALGORITHM_IDS[left_index]
            right = _V29_ALGORITHM_IDS[right_index]
            overlaps["$left|$right"] = length(intersect(selected_sets[left],
                selected_sets[right]))
        end
    end
    deterministic = Dict{String,Any}(
        "batch_id" => Int(batch_id),
        "sequence_skip" => Int(sequence_skip),
        "baseline_start" => baseline_start,
        "pool_start" => pool_start,
        "pool_end" => pool_start + Int(proposal_pool_samples) - 1,
        "blind_sample_count" => length(baseline),
        "proposal_pool_count" => length(pool),
        "explicit_budget_per_algorithm" => Int(explicit_budget),
        "unique_evaluation_count_after_cache" => length(evaluation_cache),
        "classifier_audit_hash" => canonical_hash(audits),
        "algorithm_metrics" => metrics,
        "comparisons_to_blind" => comparisons,
        "selection_overlap_counts" => overlaps,
        "records_hash" => canonical_hash(Dict(algorithm =>
            records_by_algorithm[algorithm] for algorithm in
            _V29_ALGORITHM_IDS)))
    return deterministic, records_by_algorithm
end

function aggregate_frozen_acquisition_benchmark_v29(batches,
        preregistration::AbstractDict)
    batch_count = length(batches)
    batch_count == Int(preregistration["batch_contract"]["batch_count"]) ||
        throw(ArgumentError("v29 batch count disagrees with preregistration"))
    aggregate = Dict{String,Any}()
    for algorithm in _V29_ALGORITHM_IDS
        gate_counts = Dict(gate => sum(Int(batch["algorithm_metrics"][
            algorithm]["gate_pass_counts"][gate]) for batch in batches)
            for gate in _HGV14_GATE_IDS)
        wins = count(batch -> batch["comparisons_to_blind"][algorithm][
            "strict_score_win_against_blind"] === true, batches)
        aggregate[algorithm] = Dict{String,Any}(
            "batch_count" => batch_count,
            "explicit_evaluation_count" => sum(Int(batch[
                "algorithm_metrics"][algorithm]["evaluation_count"])
                for batch in batches),
            "gate_pass_counts" => gate_counts,
            "discovery_score_sum" => sum(Float64(batch[
                "algorithm_metrics"][algorithm]["discovery_score"])
                for batch in batches),
            "strict_score_wins_against_blind" => wins,
            "mean_gate_brier_across_batches" => sum(Float64(batch[
                "algorithm_metrics"][algorithm]["mean_gate_brier"])
                for batch in batches) / batch_count,
            "promotion_count" => sum(Int(batch["algorithm_metrics"][
                algorithm]["promotion_count"]) for batch in batches),
            "negative_anchor_promotion_count" => sum(Int(batch[
                "algorithm_metrics"][algorithm][
                    "negative_anchor_promotion_count"]) for batch in batches),
            "surrogate_only_promotion_count" => sum(Int(batch[
                "algorithm_metrics"][algorithm][
                    "surrogate_only_promotion_count"]) for batch in batches))
    end
    blind = aggregate["stratified_blind_halton"]
    hierarchical = aggregate["hierarchical_gate_v14_style"]
    unauthorized = hierarchical["negative_anchor_promotion_count"] +
        hierarchical["surrogate_only_promotion_count"]
    retain_hierarchical = hierarchical[
        "strict_score_wins_against_blind"] >= 4 &&
        hierarchical["gate_pass_counts"]["five_gate"] >=
            blind["gate_pass_counts"]["five_gate"] &&
        hierarchical["gate_pass_counts"]["positive_net"] >=
            blind["gate_pass_counts"]["positive_net"] &&
        unauthorized == 0
    recommendation = "stratified_blind_halton"
    reason = "hierarchical retention rule not met and no lower-complexity method qualified"
    if retain_hierarchical
        recommendation = "hierarchical_gate_v14_style"
        reason = "all preregistered hierarchical retention conditions passed"
    else
        for algorithm in ("failure_frontier_qd", "uncertainty_only")
            item = aggregate[algorithm]
            if item["strict_score_wins_against_blind"] >= 3 &&
                    item["gate_pass_counts"]["five_gate"] >=
                        blind["gate_pass_counts"]["five_gate"] &&
                    item["gate_pass_counts"]["positive_net"] >=
                        blind["gate_pass_counts"]["positive_net"] &&
                    item["negative_anchor_promotion_count"] == 0 &&
                    item["surrogate_only_promotion_count"] == 0
                recommendation = algorithm
                reason = "lowest-complexity non-hierarchical method meeting the preregistered fallback rule"
                break
            end
        end
    end
    return Dict{String,Any}(
        "algorithm_aggregates" => aggregate,
        "decision" => Dict{String,Any}(
            "retain_hierarchical_v14_style" => retain_hierarchical,
            "recommended_algorithm" => recommendation,
            "reason" => reason,
            "post_result_tuning_applied" => false,
            "decision_rule_hash" => canonical_hash(
                preregistration["decision_rule"])),
        "claim_boundary" => _V29_CLAIM_BOUNDARY)
end
