const _HGV14_CLAIM_BOUNDARY =
    "Disjoint-sequence hierarchical gate-aware acquisition over sealed v12 and v13 explicit evidence. Cheap nominal physics, engineering, and net-power facts are never replaced by a surrogate. Separate local kernel classifiers estimate explicit physics, engineering, robustness, five-gate, and positive-net outcomes only to order an explicit evaluation batch. Uncertainty is capped and cannot outrank a known hard-gate tier. Only an explicit family evaluator can promote a candidate."

const _HGV14_GATE_IDS = (
    "physics", "engineering", "robustness", "five_gate", "positive_net")

struct HierarchicalGateDiscoveryConfigV14
    sequence_skip::Int
    blind_baseline_samples::Int
    proposal_pool_samples::Int
    active_batch_size::Int
    neighbor_count::Int
    uncertainty_tiebreak_cap::Float64

    function HierarchicalGateDiscoveryConfigV14(;
            sequence_skip::Integer = 660,
            blind_baseline_samples::Integer = 360,
            proposal_pool_samples::Integer = 60_000,
            active_batch_size::Integer = 360,
            neighbor_count::Integer = 7,
            uncertainty_tiebreak_cap::Real = 0.25)
        sequence_skip >= 0 || throw(ArgumentError(
            "sequence_skip must be non-negative"))
        blind_baseline_samples >= 0 || throw(ArgumentError(
            "blind_baseline_samples must be non-negative"))
        proposal_pool_samples > 0 || throw(ArgumentError(
            "proposal_pool_samples must be positive"))
        active_batch_size > 0 || throw(ArgumentError(
            "active_batch_size must be positive"))
        neighbor_count >= 2 || throw(ArgumentError(
            "neighbor_count must be at least two"))
        isfinite(uncertainty_tiebreak_cap) && 0.0 <= uncertainty_tiebreak_cap <= 1.0 ||
            throw(ArgumentError("uncertainty cap must be in [0,1]"))
        return new(Int(sequence_skip), Int(blind_baseline_samples), Int(proposal_pool_samples),
            Int(active_batch_size), Int(neighbor_count),
            Float64(uncertainty_tiebreak_cap))
    end
end

function _hgv14_gate_labels(result::AbstractDict)
    gates = result["gates"]
    robustness = result["robustness"]
    return Dict{String,Float64}(
        "physics" => gates["unified_low_fidelity_physics"] === true ? 1.0 : 0.0,
        "engineering" => gates["minimal_engineering_closure"] === true ? 1.0 : 0.0,
        "robustness" => get(robustness, "gate_passed", false) === true ? 1.0 : 0.0,
        "five_gate" => result["all_five_gates_passed"] === true ? 1.0 : 0.0,
        "positive_net" => result["positive_net_power_closure_passed"] === true ?
            1.0 : 0.0)
end

function _hgv14_observation(path_key, contract_id, values, result, origin,
        physics_hash, contract)
    return Dict{String,Any}(
        "origin" => origin,
        "path_key" => String(path_key),
        "contract_id" => String(contract_id),
        "physics_hash" => String(physics_hash),
        "features" => _sav13_augmented_features(values, contract),
        "gate_labels" => _hgv14_gate_labels(result))
end

function _hgv14_explicit_record(proposal, spec, contract, candidate, result,
        selection_stage; hierarchy = nothing)
    promoted = spec.promotion_eligible &&
        result["all_five_gates_passed"] === true &&
        result["positive_net_power_closure_passed"] === true
    return Dict{String,Any}(
        "selection_stage" => selection_stage,
        "sequence_index" => proposal["sequence_index"],
        "path_key" => proposal["path_key"],
        "structural_stratum" => proposal["structural_stratum"],
        "contract_id" => contract.id,
        "core_family" => spec.core_family,
        "mechanism" => spec.mechanism,
        "exhaust_topology" => spec.exhaust_topology,
        "anchor_only" => spec.anchor_only,
        "promotion_eligible" => spec.promotion_eligible,
        "features" => proposal["features"],
        "physics_hash" => candidate.physics_hash,
        "nominal_physics_gate_passed" => proposal["nominal_physics_gate_passed"],
        "nominal_engineering_gate_passed" =>
            proposal["nominal_engineering_gate_passed"],
        "nominal_positive_net" =>
            Float64(proposal["nominal_net_electric_power_W"]) > 0.0,
        "hierarchical_acquisition" => hierarchy,
        "evaluation" => result,
        "explicit_gate_labels" => _hgv14_gate_labels(result),
        "all_five_gates_passed" => result["all_five_gates_passed"],
        "positive_net_power_closure_passed" =>
            result["positive_net_power_closure_passed"],
        "promoted" => promoted,
        "medium_fidelity_route" => promoted ?
            _cbv12_medium_fidelity_route(spec) : String[])
end

function _hgv14_classifier_audit(vectors, labels, neighbor_count)
    squared = Float64[]
    absolute = Float64[]
    correct = 0
    for index in eachindex(vectors)
        prediction = _sav13_kernel_predict(vectors, labels, vectors[index],
            neighbor_count; excluded = index)
        probability = clamp(prediction.mean, 0.0, 1.0)
        error = probability - labels[index]
        push!(squared, error^2)
        push!(absolute, abs(error))
        (probability >= 0.5) == (labels[index] >= 0.5) && (correct += 1)
    end
    return Dict{String,Any}(
        "observation_count" => length(labels),
        "positive_count" => count(>=(0.5), labels),
        "negative_count" => count(<(0.5), labels),
        "loo_brier_score" => sum(squared) / length(squared),
        "loo_mean_absolute_error" => sum(absolute) / length(absolute),
        "loo_classification_accuracy" => correct / length(labels),
        "calibrated_probability_or_safety_guarantee_claimed" => false)
end

function _hgv14_predict_gate_models(observations, candidates, config)
    rows = vcat(Dict{String,Float64}[item["features"] for item in observations],
        Dict{String,Float64}[item["augmented_features"] for item in candidates])
    scaler = _sav13_scaler(rows)
    vectors = [_sav13_vector(item["features"], scaler) for item in observations]
    audits = Dict{String,Any}()
    models = Dict{String,Any}()
    for gate_id in _HGV14_GATE_IDS
        labels = Float64[item["gate_labels"][gate_id] for item in observations]
        audits[gate_id] = _hgv14_classifier_audit(vectors, labels,
            config.neighbor_count)
        models[gate_id] = labels
    end
    for proposal in candidates
        vector = _sav13_vector(proposal["augmented_features"], scaler)
        predictions = Dict{String,Any}()
        for gate_id in _HGV14_GATE_IDS
            prediction = _sav13_kernel_predict(vectors, models[gate_id], vector,
                config.neighbor_count)
            predictions[gate_id] = Dict{String,Any}(
                "local_pass_fraction" => clamp(prediction.mean, 0.0, 1.0),
                "local_uncertainty" => min(1.0, prediction.uncertainty),
                "nearest_observation_distance" => prediction.nearest_distance)
        end
        nominal_physics = proposal["nominal_physics_gate_passed"] === true
        nominal_engineering = proposal["nominal_engineering_gate_passed"] === true
        nominal_positive = Float64(proposal["nominal_net_electric_power_W"]) > 0.0
        exact_gate_count = Int(nominal_physics) + Int(nominal_engineering) +
            Int(nominal_positive)
        robustness_probability = Float64(
            predictions["robustness"]["local_pass_fraction"])
        five_probability = Float64(
            predictions["five_gate"]["local_pass_fraction"])
        uncertainty = min(config.uncertainty_tiebreak_cap,
            Float64(predictions["five_gate"]["local_uncertainty"]))
        proposal["hierarchical_acquisition"] = Dict{String,Any}(
            "predicted_gates" => predictions,
            "exact_nominal_physics" => nominal_physics,
            "exact_nominal_engineering" => nominal_engineering,
            "exact_nominal_positive_net" => nominal_positive,
            "exact_gate_count" => exact_gate_count,
            "exact_nominal_five_ready" => nominal_physics && nominal_engineering,
            "promotion_ready_before_robustness" =>
                proposal["promotion_eligible"] === true && nominal_physics &&
                nominal_engineering && nominal_positive,
            "robustness_probability_tiebreak" => robustness_probability,
            "five_gate_probability_tiebreak" => five_probability,
            "capped_uncertainty_tiebreak" => uncertainty,
            "surrogate_can_authorize_promotion" => false)
    end
    return audits
end

function _hgv14_rank_key(proposal)
    hierarchy = proposal["hierarchical_acquisition"]
    promotion_ready = hierarchy["promotion_ready_before_robustness"] === true
    five_ready = hierarchy["exact_nominal_five_ready"] === true
    gate_count = Int(hierarchy["exact_gate_count"])
    robust = Float64(hierarchy["robustness_probability_tiebreak"])
    five = Float64(hierarchy["five_gate_probability_tiebreak"])
    uncertainty = Float64(hierarchy["capped_uncertainty_tiebreak"])
    # Exact gate tiers dominate every learned value. Within a tier, favor local
    # evidence for five-gate/robustness and use capped uncertainty last.
    return (-Int(promotion_ready), -Int(five_ready), -gate_count,
        -robust, -five, -uncertainty, Int(proposal["sequence_index"]))
end

function _hgv14_v13_max_sequence(v13)
    values = Int[]
    for field in ("blind_baseline_records", "active_records")
        append!(values, Int(item["sequence_index"]) for item in
            v13["safe_active_causal_discovery"][field])
    end
    isempty(values) && error("v13 contains no explicit sequence indices")
    search = v13["safe_active_causal_discovery"]
    v13_pool_end = 300_000 + Int(search["config"]["calibration_samples"]) +
        Int(search["config"]["proposal_pool_samples"])
    maximum(values) <= v13_pool_end || error(
        "v13 selected an index beyond its declared proposal pool")
    return v13_pool_end
end

function run_hierarchical_gate_discovery_v14(seeds::Vector{Genome},
        v12_artifact_raw, v13_artifact_raw;
        config::HierarchicalGateDiscoveryConfigV14 =
            HierarchicalGateDiscoveryConfigV14(),
        contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    v12 = _plain_json(v12_artifact_raw)
    v13 = _plain_json(v13_artifact_raw)
    get(v12, "result_hash", "") ==
        "583fa8dacdafbd017db705fa4cb5a4f40b2eae1ad337ac14ec142844ce1f1bec" ||
        throw(ArgumentError("v14 requires sealed v12 evidence"))
    get(v13, "result_hash", "") ==
        "4ecf08031357668326a047dcb369a3bdc9e9f846ba66e2d5095a7db0c9afa7be" ||
        throw(ArgumentError("v14 requires the formal v13 negative baseline"))
    specs = _cbv12_topology_specs()
    structural = _cbv12_structural_bases(seeds)
    spec_by_key = Dict(_sav13_path_key(spec) => spec for spec in specs)
    contract_by_id = Dict(contract.id => contract for contract in contracts)
    primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61)
    config.active_batch_size <= config.proposal_pool_samples ||
        throw(ArgumentError("active batch exceeds proposal pool"))

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
        push!(observations, _hgv14_observation(_sav13_path_key(spec), contract.id,
            values, record["evaluation"], "sealed_v12_elite",
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
            push!(observations, _hgv14_observation(path_key, contract.id, values,
                record["evaluation"], "formal_v13_explicit",
                candidate.physics_hash, contract))
        end
    end
    reconstruction_violations == 0 || error(
        "v14 input evidence failed deterministic reconstruction")

    baseline_start = _hgv14_v13_max_sequence(v13) + config.sequence_skip + 1
    blind_records = Dict{String,Any}[]
    for offset in 0:(config.blind_baseline_samples - 1)
        proposal = _sav13_candidate(baseline_start + offset, structural, specs,
            contracts, primes)
        spec = spec_by_key[String(proposal["path_key"])]
        proposal["promotion_eligible"] = spec.promotion_eligible
        contract = contract_by_id[String(proposal["contract_id"])]
        candidate, result = _sav13_explicit(structural[_cbv12_key(spec)], spec,
            contract, proposal["features"], contracts)
        push!(blind_records, _hgv14_explicit_record(proposal, spec, contract,
            candidate, result, "disjoint_blind_halton_baseline"))
    end

    pool_start = baseline_start + config.blind_baseline_samples
    pool = Dict{String,Any}[]
    for offset in 0:(config.proposal_pool_samples - 1)
        proposal = _sav13_candidate(pool_start + offset, structural, specs,
            contracts, primes)
        proposal["promotion_eligible"] =
            spec_by_key[String(proposal["path_key"])].promotion_eligible
        push!(pool, proposal)
    end
    observations_by_path = Dict{String,Vector{Dict{String,Any}}}()
    pool_by_path = Dict{String,Vector{Dict{String,Any}}}()
    for observation in observations
        push!(get!(observations_by_path, String(observation["path_key"]),
            Dict{String,Any}[]), observation)
    end
    for proposal in pool
        push!(get!(pool_by_path, String(proposal["path_key"]),
            Dict{String,Any}[]), proposal)
    end
    classifier_audits = Dict{String,Any}()
    for path_key in sort!(collect(keys(pool_by_path)))
        classifier_audits[path_key] = _hgv14_predict_gate_models(
            observations_by_path[path_key], pool_by_path[path_key], config)
    end

    by_stratum = Dict{String,Vector{Dict{String,Any}}}()
    for proposal in pool
        push!(get!(by_stratum, String(proposal["structural_stratum"]),
            Dict{String,Any}[]), proposal)
    end
    selected = Dict{String,Any}[]
    for stratum in sort!(collect(keys(by_stratum)))
        ranked = sort!(by_stratum[stratum]; by = _hgv14_rank_key)
        push!(selected, first(ranked))
    end
    sort!(selected; by = _hgv14_rank_key)
    selected = first(selected, min(config.active_batch_size, length(selected)))
    if length(selected) < config.active_batch_size
        selected_indices = Set(Int(item["sequence_index"]) for item in selected)
        remaining = filter(item ->
            !(Int(item["sequence_index"]) in selected_indices), pool)
        sort!(remaining; by = _hgv14_rank_key)
        append!(selected, first(remaining,
            min(config.active_batch_size - length(selected), length(remaining))))
    end

    active_records = Dict{String,Any}[]
    for proposal in selected
        spec = spec_by_key[String(proposal["path_key"])]
        contract = contract_by_id[String(proposal["contract_id"])]
        candidate, result = _sav13_explicit(structural[_cbv12_key(spec)], spec,
            contract, proposal["features"], contracts)
        push!(active_records, _hgv14_explicit_record(proposal, spec, contract,
            candidate, result, "hierarchical_gate_active_batch";
            hierarchy = proposal["hierarchical_acquisition"]))
    end
    sort!(blind_records; by = item -> String(item["physics_hash"]))
    sort!(active_records; by = item -> String(item["physics_hash"]))
    all_records = vcat(blind_records, active_records)
    promoted = filter(item -> item["promoted"] === true, all_records)
    return Dict{String,Any}(
        "algorithm" => "hierarchical exact-gate tiers plus per-path local gate classifiers and capped uncertainty",
        "claim_boundary" => _HGV14_CLAIM_BOUNDARY,
        "config" => Dict{String,Any}(
            "sequence_skip" => config.sequence_skip,
            "blind_baseline_samples" => config.blind_baseline_samples,
            "proposal_pool_samples" => config.proposal_pool_samples,
            "active_batch_size" => config.active_batch_size,
            "neighbor_count" => config.neighbor_count,
            "uncertainty_tiebreak_cap" => config.uncertainty_tiebreak_cap),
        "path_count" => length(specs),
        "contract_count" => length(contracts),
        "structural_stratum_count" => length(specs) * length(contracts),
        "historical_explicit_observation_count" => length(observations),
        "historical_reconstruction_violation_count" => reconstruction_violations,
        "sequence_start" => baseline_start,
        "sequence_end" => pool_start + config.proposal_pool_samples - 1,
        "v13_max_sequence_index" => _hgv14_v13_max_sequence(v13),
        "sequence_overlap_with_v13_count" => 0,
        "smoke_sequence_skip" => config.sequence_skip,
        "proposal_pool_count" => length(pool),
        "selected_structural_stratum_count" => length(unique(
            String(item["structural_stratum"]) for item in active_records)),
        "classifier_audits" => classifier_audits,
        "blind_baseline_records" => blind_records,
        "active_records" => active_records,
        "explicit_promotion_count" => length(promoted),
        "surrogate_only_promotion_count" => 0,
        "negative_anchor_promotion_count" => count(item ->
            item["anchor_only"] === true && item["promoted"] === true,
            all_records),
        "medium_fidelity_review_queue" => [Dict{String,Any}(
            "physics_hash" => item["physics_hash"],
            "contract_id" => item["contract_id"],
            "core_family" => item["core_family"],
            "mechanism" => item["mechanism"],
            "route" => item["medium_fidelity_route"]) for item in promoted])
end
