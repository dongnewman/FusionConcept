const _V30_ALGORITHM_IDS = (
    "stratified_blind_halton",
    "failure_frontier_qd",
    "hierarchical_gate_v14_style",
)

const _V30_CLAIM_BOUNDARY =
    "V30 is a deterministic preregistered confirmation over five new frozen windows in the sealed v12/v13 causal-path domain. Operational non-inferiority means only that the frozen batch-win and aggregate-count conditions passed; it is not a statistical non-inferiority trial. The result cannot establish randomized generalization, transfer to the v17/v20 11-family grammar, C1 evidence, medium-fidelity validity, fusion-concept feasibility, or algorithmic superiority outside this bounded domain."

function run_frozen_acquisition_batch_v30(
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
        "hierarchical_gate_v14_style" => _v29_stratified_select(pool,
            Int(explicit_budget), _hgv14_rank_key))
    all(length(selection) == explicit_budget for selection in
        values(selections)) || error("v30 selection budget drifted")

    evaluation_cache = Dict{Int,Dict{String,Any}}()
    records_by_algorithm = Dict{String,Vector{Dict{String,Any}}}()
    for algorithm in _V30_ALGORITHM_IDS
        records = Dict{String,Any}[]
        for proposal in selections[algorithm]
            index = Int(proposal["sequence_index"])
            record = get!(evaluation_cache, index) do
                _v29_explicit_compact(context, proposal)
            end
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
        for algorithm in _V30_ALGORITHM_IDS)
    blind_score = Float64(metrics["stratified_blind_halton"][
        "discovery_score"])
    comparisons = Dict{String,Any}()
    for algorithm in _V30_ALGORITHM_IDS
        score = Float64(metrics[algorithm]["discovery_score"])
        comparisons[algorithm] = Dict{String,Any}(
            "score_difference_from_blind" => score - blind_score,
            "strict_score_win_against_blind" => score > blind_score,
            "score_tie_with_blind" => score == blind_score,
            "five_gate_difference_from_blind" => metrics[algorithm][
                "gate_pass_counts"]["five_gate"] - metrics[
                    "stratified_blind_halton"]["gate_pass_counts"]["five_gate"],
            "positive_net_difference_from_blind" => metrics[algorithm][
                "gate_pass_counts"]["positive_net"] - metrics[
                    "stratified_blind_halton"]["gate_pass_counts"]["positive_net"])
    end

    qd = metrics["failure_frontier_qd"]
    hierarchical = metrics["hierarchical_gate_v14_style"]
    primary = Dict{String,Any}(
        "score_difference_qd_minus_hierarchical" => Float64(
            qd["discovery_score"]) - Float64(hierarchical["discovery_score"]),
        "qd_strict_score_win" => Float64(qd["discovery_score"]) >
            Float64(hierarchical["discovery_score"]),
        "hierarchical_strict_score_win" => Float64(
            hierarchical["discovery_score"]) > Float64(qd["discovery_score"]),
        "score_tie" => Float64(qd["discovery_score"]) ==
            Float64(hierarchical["discovery_score"]),
        "five_gate_difference_qd_minus_hierarchical" =>
            qd["gate_pass_counts"]["five_gate"] -
            hierarchical["gate_pass_counts"]["five_gate"],
        "positive_net_difference_qd_minus_hierarchical" =>
            qd["gate_pass_counts"]["positive_net"] -
            hierarchical["gate_pass_counts"]["positive_net"],
        "robustness_difference_qd_minus_hierarchical" =>
            qd["gate_pass_counts"]["robustness"] -
            hierarchical["gate_pass_counts"]["robustness"])

    selected_sets = Dict(algorithm => Set(Int(record["sequence_index"])
        for record in records_by_algorithm[algorithm]) for algorithm in
        _V30_ALGORITHM_IDS)
    overlaps = Dict{String,Int}()
    for left_index in eachindex(_V30_ALGORITHM_IDS)
        for right_index in (left_index + 1):length(_V30_ALGORITHM_IDS)
            left_index < right_index || continue
            left = _V30_ALGORITHM_IDS[left_index]
            right = _V30_ALGORITHM_IDS[right_index]
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
        "primary_comparison" => primary,
        "selection_overlap_counts" => overlaps,
        "records_hash" => canonical_hash(Dict(algorithm =>
            records_by_algorithm[algorithm] for algorithm in
            _V30_ALGORITHM_IDS)))
    return deterministic, records_by_algorithm
end

function aggregate_frozen_acquisition_confirmation_v30(batches,
        preregistration::AbstractDict)
    batch_count = length(batches)
    contract = preregistration["batch_contract"]
    batch_count == Int(contract["batch_count"]) || throw(ArgumentError(
        "v30 batch count disagrees with preregistration"))
    aggregate = Dict{String,Any}()
    for algorithm in _V30_ALGORITHM_IDS
        gate_counts = Dict(gate => sum(Int(batch["algorithm_metrics"][
            algorithm]["gate_pass_counts"][gate]) for batch in batches)
            for gate in _HGV14_GATE_IDS)
        aggregate[algorithm] = Dict{String,Any}(
            "batch_count" => batch_count,
            "explicit_evaluation_count" => sum(Int(batch[
                "algorithm_metrics"][algorithm]["evaluation_count"])
                for batch in batches),
            "gate_pass_counts" => gate_counts,
            "discovery_score_sum" => sum(Float64(batch[
                "algorithm_metrics"][algorithm]["discovery_score"])
                for batch in batches),
            "strict_score_wins_against_blind" => count(batch -> batch[
                "comparisons_to_blind"][algorithm][
                    "strict_score_win_against_blind"] === true, batches),
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

    qd = aggregate["failure_frontier_qd"]
    hierarchical = aggregate["hierarchical_gate_v14_style"]
    rule = preregistration["decision_rule"]
    primary_metrics = String.(rule["aggregate_noninferiority_metrics"])
    qd_wins = count(batch -> batch["primary_comparison"][
        "qd_strict_score_win"] === true, batches)
    hierarchical_wins = count(batch -> batch["primary_comparison"][
        "hierarchical_strict_score_win"] === true, batches)
    ties = batch_count - qd_wins - hierarchical_wins
    gate_differences = Dict(metric => qd["gate_pass_counts"][metric] -
        hierarchical["gate_pass_counts"][metric] for metric in
        _HGV14_GATE_IDS)
    qd_unauthorized = qd["negative_anchor_promotion_count"] +
        qd["surrogate_only_promotion_count"]
    primary_conditions = Dict{String,Any}(
        "batch_score_win_condition" => qd_wins >= Int(rule[
            "minimum_strict_score_wins_against_hierarchical"]),
        "blind_sentinel_condition" => qd[
            "strict_score_wins_against_blind"] >= Int(rule[
                "minimum_strict_score_wins_against_blind_sentinel"]),
        "aggregate_count_noninferiority_condition" => all(
            gate_differences[metric] >= 0 for metric in primary_metrics),
        "zero_unauthorized_promotion_condition" => qd_unauthorized == 0)
    operational_noninferiority = all(values(primary_conditions))

    superiority_rule = rule["superiority_conditions"]
    superiority_conditions = Dict{String,Any}(
        "batch_score_win_condition" => qd_wins >= Int(superiority_rule[
            "minimum_strict_score_wins_against_hierarchical"]),
        "aggregate_score_condition" => qd["discovery_score_sum"] >
            hierarchical["discovery_score_sum"],
        "five_gate_condition" => gate_differences["five_gate"] > 0,
        "positive_net_condition" => gate_differences["positive_net"] >= 0,
        "robustness_condition" => gate_differences["robustness"] >= 0,
        "blind_sentinel_condition" => primary_conditions[
            "blind_sentinel_condition"],
        "zero_unauthorized_promotion_condition" => qd_unauthorized == 0)
    superiority = operational_noninferiority &&
        all(values(superiority_conditions))
    recommendation = operational_noninferiority ?
        "failure_frontier_qd" : "hierarchical_gate_v14_style"
    status = superiority ? "superiority_confirmed" :
        (operational_noninferiority ? "operational_noninferiority_confirmed" :
        "qd_confirmation_failed")
    return Dict{String,Any}(
        "algorithm_aggregates" => aggregate,
        "primary_comparison" => Dict{String,Any}(
            "qd_strict_score_wins" => qd_wins,
            "hierarchical_strict_score_wins" => hierarchical_wins,
            "score_ties" => ties,
            "aggregate_gate_count_differences_qd_minus_hierarchical" =>
                gate_differences,
            "aggregate_discovery_score_difference_qd_minus_hierarchical" =>
                qd["discovery_score_sum"] -
                hierarchical["discovery_score_sum"],
            "primary_conditions" => primary_conditions,
            "superiority_conditions" => superiority_conditions),
        "decision" => Dict{String,Any}(
            "confirmation_status" => status,
            "operational_noninferiority_confirmed" =>
                operational_noninferiority,
            "superiority_confirmed" => superiority,
            "recommended_algorithm" => recommendation,
            "post_result_tuning_applied" => false,
            "decision_rule_hash" => canonical_hash(rule)),
        "claim_boundary" => _V30_CLAIM_BOUNDARY)
end
