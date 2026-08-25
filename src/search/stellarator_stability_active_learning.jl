"One exact sampled-stability observation tied to a proposal physics hash."
struct StellaratorStabilityObservation
    pool_index::Int
    physics_hash::String
    minimum_mercier_D_normalized::Float64
    maximum_infinite_n_ballooning_lambda::Float64
    resolution_audited::Bool

    function StellaratorStabilityObservation(pool_index::Integer,
            physics_hash::AbstractString, minimum_mercier_D_normalized::Real,
            maximum_infinite_n_ballooning_lambda::Real,
            resolution_audited::Bool)
        pool_index >= 1 || throw(ArgumentError("pool_index must be positive"))
        length(physics_hash) == 64 || throw(ArgumentError(
            "physics_hash must contain 64 hexadecimal characters"))
        all(isxdigit, physics_hash) || throw(ArgumentError("invalid physics_hash"))
        all(isfinite, (minimum_mercier_D_normalized,
            maximum_infinite_n_ballooning_lambda)) || throw(ArgumentError(
            "stability observations must be finite"))
        return new(Int(pool_index), lowercase(String(physics_hash)),
            Float64(minimum_mercier_D_normalized),
            Float64(maximum_infinite_n_ballooning_lambda), resolution_audited)
    end
end

struct StellaratorStabilityActiveLearningConfig
    batch_size::Int
    candidate_lengthscales::Vector{Float64}
    audited_noise_variance::Float64
    medium_noise_variance::Float64
    exploration_weight::Float64
    diversity_weight::Float64
    mercier_scale::Float64
    ballooning_scale::Float64
    mercier_required_margin::Float64
    ballooning_required_maximum::Float64

    function StellaratorStabilityActiveLearningConfig(;
            batch_size::Integer = 4,
            candidate_lengthscales = [0.35, 0.55, 0.80, 1.10],
            audited_noise_variance::Real = 1.0e-6,
            medium_noise_variance::Real = 0.04,
            exploration_weight::Real = 1.0,
            diversity_weight::Real = 0.20,
            mercier_scale::Real = 0.01,
            ballooning_scale::Real = 0.001,
            mercier_required_margin::Real = 1.0e-5,
            ballooning_required_maximum::Real = -1.0e-5)
        batch_size >= 1 || throw(ArgumentError("batch_size must be positive"))
        scales = sort!(unique(Float64.(collect(candidate_lengthscales))))
        !isempty(scales) && all(value -> isfinite(value) && value > 0, scales) ||
            throw(ArgumentError("candidate lengthscales must be positive and finite"))
        0 < audited_noise_variance <= medium_noise_variance < 1 ||
            throw(ArgumentError("observation noise variances are invalid"))
        all(value -> isfinite(value) && value >= 0,
            (exploration_weight, diversity_weight)) || throw(ArgumentError(
            "acquisition weights must be finite and non-negative"))
        all(value -> isfinite(value) && value > 0,
            (mercier_scale, ballooning_scale)) || throw(ArgumentError(
            "stability scales must be positive and finite"))
        isfinite(mercier_required_margin) || throw(ArgumentError(
            "Mercier margin must be finite"))
        isfinite(ballooning_required_maximum) && ballooning_required_maximum <= 0 ||
            throw(ArgumentError("ballooning threshold must be finite and non-positive"))
        return new(Int(batch_size), scales, Float64(audited_noise_variance),
            Float64(medium_noise_variance), Float64(exploration_weight),
            Float64(diversity_weight), Float64(mercier_scale),
            Float64(ballooning_scale), Float64(mercier_required_margin),
            Float64(ballooning_required_maximum))
    end
end

struct StellaratorStabilityAcquisition
    acquisition_rank::Int
    proposal::StellaratorFourierPilotProposal
    predicted_mercier_scaled_margin::Float64
    predicted_ballooning_scaled_margin::Float64
    predicted_joint_scaled_margin::Float64
    posterior_standard_deviation::Float64
    exploration_bonus::Float64
    diversity_distance::Float64
    diversity_bonus::Float64
    acquisition_score::Float64
end

struct StellaratorStabilityActiveLearningPlan
    algorithm::String
    config::StellaratorStabilityActiveLearningConfig
    chosen_lengthscale::Float64
    lengthscale_loo_scores::Dict{Float64,Float64}
    mercier_loo_rmse::Float64
    ballooning_loo_rmse::Float64
    observations::Vector{StellaratorStabilityObservation}
    acquisitions::Vector{StellaratorStabilityAcquisition}
    remaining_count::Int
end

function stellarator_stability_observation_from_dict(
        plan::StellaratorFourierPilotPlan, evaluation_raw;
        resolution_audited::Bool = false)
    raw = _plain_json(evaluation_raw)
    get(raw, "evaluator_id", "") ==
        "stellarator_sampled_ideal_mhd_stability_desc_v1" || throw(ArgumentError(
        "evaluation is not sampled stellarator stability evidence"))
    get(raw, "status", "error") == "pass" || throw(ArgumentError(
        "sampled stability evaluation did not pass computation"))
    physics_hash = String(raw["input_hash"])
    proposals = filter(item -> item.genome.physics_hash == physics_hash,
        plan.proposals)
    length(proposals) == 1 || throw(ArgumentError(
        "evaluation physics hash is absent or duplicated in the proposal pool"))
    metrics = Dict(String(item["metric_id"]) => item for item in raw["metrics"])
    for id in ("minimum_sampled_mercier_D_normalized",
            "maximum_sampled_infinite_n_ballooning_lambda")
        haskey(metrics, id) || throw(ArgumentError("evaluation lacks metric $id"))
        metrics[id]["status"] == "pass" || throw(ArgumentError(
            "evaluation metric $id did not pass"))
    end
    for id in ("plasma_stability_feasible", "minimum_stability_margin")
        haskey(metrics, id) || throw(ArgumentError("evaluation lacks unknown metric $id"))
        metrics[id]["status"] == "unknown" && metrics[id]["value"] === nothing ||
            throw(ArgumentError("evaluation crossed the all-mode stability boundary"))
    end
    proposal = only(proposals)
    return StellaratorStabilityObservation(proposal.pool_index, physics_hash,
        Float64(metrics["minimum_sampled_mercier_D_normalized"]["value"]),
        Float64(metrics["maximum_sampled_infinite_n_ballooning_lambda"]["value"]),
        resolution_audited)
end

_stability_kernel(left::Vector{Float64}, right::Vector{Float64}, lengthscale) =
    exp(-sum((left .- right) .^ 2) / (2.0 * lengthscale^2))

function _stability_gp_fit(features::Vector{Vector{Float64}}, values::Vector{Float64},
        noises::Vector{Float64}, lengthscale::Float64)
    count = length(features)
    count == length(values) == length(noises) || error("GP input length mismatch")
    count >= 2 || throw(ArgumentError("at least two observations are required"))
    kernel = Matrix{Float64}(undef, count, count)
    for row in 1:count, column in 1:count
        kernel[row, column] = _stability_kernel(features[row], features[column],
            lengthscale)
    end
    for index in 1:count
        kernel[index, index] += noises[index] + 1.0e-10
    end
    mean_value = sum(values) / count
    factor = cholesky(Symmetric(kernel); check = true)
    weights = factor \ (values .- mean_value)
    return (features = features, factor = factor, weights = weights,
        mean_value = mean_value, lengthscale = lengthscale)
end

function _stability_gp_predict(model, feature::Vector{Float64})
    covariance = Float64[_stability_kernel(item, feature, model.lengthscale)
        for item in model.features]
    mean_value = model.mean_value + dot(covariance, model.weights)
    variance = max(0.0, 1.0 - dot(covariance, model.factor \ covariance))
    return mean_value, variance
end

function _stability_loo_predictions(features, values, noises, lengthscale)
    predictions = Float64[]
    for excluded in eachindex(features)
        retained = filter(!=(excluded), collect(eachindex(features)))
        model = _stability_gp_fit(features[retained], values[retained],
            noises[retained], lengthscale)
        prediction, _ = _stability_gp_predict(model, features[excluded])
        push!(predictions, prediction)
    end
    return predictions
end

function plan_stellarator_stability_active_learning(
        proposal_plan::StellaratorFourierPilotPlan,
        observations::Vector{StellaratorStabilityObservation};
        config::StellaratorStabilityActiveLearningConfig =
            StellaratorStabilityActiveLearningConfig())
    length(observations) >= 4 || throw(ArgumentError(
        "active learning requires at least four exact observations"))
    observed_indices = getfield.(observations, :pool_index)
    length(unique(observed_indices)) == length(observed_indices) ||
        throw(ArgumentError("duplicate observed pool index"))
    proposal_by_index = Dict(item.pool_index => item for item in proposal_plan.proposals)
    for observation in observations
        haskey(proposal_by_index, observation.pool_index) || throw(ArgumentError(
            "observed pool index is outside the proposal plan"))
        proposal_by_index[observation.pool_index].genome.physics_hash ==
            observation.physics_hash || throw(ArgumentError(
            "observed physics hash is detached from its pool index"))
    end
    remaining = filter(item -> !(item.pool_index in observed_indices),
        proposal_plan.proposals)
    config.batch_size <= length(remaining) || throw(ArgumentError(
        "batch_size exceeds the remaining proposal count"))
    sort!(observations; by = item -> item.pool_index)
    features = [proposal_by_index[item.pool_index].normalized_parameters
        for item in observations]
    mercier_values = Float64[
        (item.minimum_mercier_D_normalized - config.mercier_required_margin) /
            config.mercier_scale for item in observations]
    ballooning_values = Float64[
        (-item.maximum_infinite_n_ballooning_lambda +
            config.ballooning_required_maximum) / config.ballooning_scale
        for item in observations]
    noises = Float64[item.resolution_audited ? config.audited_noise_variance :
        config.medium_noise_variance for item in observations]
    scores = Dict{Float64,Float64}()
    loo_records = Dict{Float64,Tuple{Vector{Float64},Vector{Float64}}}()
    for lengthscale in config.candidate_lengthscales
        mercier_loo = _stability_loo_predictions(features, mercier_values,
            noises, lengthscale)
        ballooning_loo = _stability_loo_predictions(features, ballooning_values,
            noises, lengthscale)
        score = sum((mercier_loo .- mercier_values) .^ 2) +
            sum((ballooning_loo .- ballooning_values) .^ 2)
        scores[lengthscale] = score
        loo_records[lengthscale] = (mercier_loo, ballooning_loo)
    end
    chosen_lengthscale = first(sort!(collect(keys(scores));
        by = value -> (scores[value], value)))
    mercier_loo, ballooning_loo = loo_records[chosen_lengthscale]
    mercier_rmse = sqrt(sum((mercier_loo .- mercier_values) .^ 2) /
        length(observations))
    ballooning_rmse = sqrt(sum((ballooning_loo .- ballooning_values) .^ 2) /
        length(observations))
    mercier_model = _stability_gp_fit(features, mercier_values, noises,
        chosen_lengthscale)
    ballooning_model = _stability_gp_fit(features, ballooning_values, noises,
        chosen_lengthscale)

    candidates = NamedTuple[]
    for proposal in remaining
        mercier_mean, mercier_variance = _stability_gp_predict(mercier_model,
            proposal.normalized_parameters)
        ballooning_mean, ballooning_variance = _stability_gp_predict(
            ballooning_model, proposal.normalized_parameters)
        posterior_std = sqrt(max(mercier_variance, ballooning_variance))
        exploration = config.exploration_weight * posterior_std
        distance = minimum(_pilot_distance(proposal.normalized_parameters,
            proposal_by_index[index].normalized_parameters)
            for index in observed_indices)
        diversity = config.diversity_weight * distance
        joint = min(mercier_mean, ballooning_mean)
        push!(candidates, (
            proposal = proposal,
            mercier_mean = mercier_mean,
            ballooning_mean = ballooning_mean,
            joint = joint,
            posterior_std = posterior_std,
            exploration = exploration,
            distance = distance,
            diversity = diversity,
            score = joint + exploration + diversity,
        ))
    end
    # The first active round remains field-period stratified: the surrogate
    # chooses within each stratum, while the batch preserves topology diversity.
    selected = NamedTuple[]
    if config.batch_size >= 4
        for period in sort!(unique(item.proposal.build_spec.field_periods
                for item in candidates))
            in_period = filter(item -> item.proposal.build_spec.field_periods == period,
                candidates)
            isempty(in_period) && continue
            push!(selected, first(sort!(in_period; by = item ->
                (-item.score, item.proposal.pool_index))))
            length(selected) == config.batch_size && break
        end
    end
    while length(selected) < config.batch_size
        selected_indices = Set(item.proposal.pool_index for item in selected)
        available = filter(item -> !(item.proposal.pool_index in selected_indices),
            candidates)
        push!(selected, first(sort!(available; by = item ->
            (-item.score, item.proposal.pool_index))))
    end
    sort!(selected; by = item -> (-item.score, item.proposal.pool_index))
    acquisitions = StellaratorStabilityAcquisition[
        StellaratorStabilityAcquisition(rank, item.proposal,
            item.mercier_mean, item.ballooning_mean, item.joint,
            item.posterior_std, item.exploration, item.distance,
            item.diversity, item.score)
        for (rank, item) in enumerate(selected)]
    return StellaratorStabilityActiveLearningPlan(
        "heteroscedastic_rbf_gp_loo_ucb_plus_diversity_field_period_stratified_v1",
        config, chosen_lengthscale, scores, mercier_rmse, ballooning_rmse,
        observations, acquisitions, length(remaining))
end

function stellarator_stability_active_learning_plan_to_dict(
        plan::StellaratorStabilityActiveLearningPlan)
    config = plan.config
    return Dict{String,Any}(
        "algorithm" => plan.algorithm,
        "claim_boundary" => "Gaussian-process predictions and acquisition scores choose evidence to buy; they are not plasma-stability evidence, device merit, or proof that a selected candidate is favorable.",
        "training_observation_count" => length(plan.observations),
        "resolution_audited_training_count" => count(item ->
            item.resolution_audited, plan.observations),
        "remaining_candidate_count_before_acquisition" => plan.remaining_count,
        "acquisition_count" => length(plan.acquisitions),
        "configuration" => Dict{String,Any}(
            "batch_size" => config.batch_size,
            "candidate_lengthscales" => config.candidate_lengthscales,
            "audited_noise_variance" => config.audited_noise_variance,
            "medium_noise_variance" => config.medium_noise_variance,
            "exploration_weight" => config.exploration_weight,
            "diversity_weight" => config.diversity_weight,
            "mercier_scale" => config.mercier_scale,
            "ballooning_scale" => config.ballooning_scale,
            "mercier_required_margin" => config.mercier_required_margin,
            "ballooning_required_maximum" =>
                config.ballooning_required_maximum,
        ),
        "model_diagnostics" => Dict{String,Any}(
            "chosen_lengthscale" => plan.chosen_lengthscale,
            "lengthscale_loo_scores" => Dict(string(key) => value
                for (key, value) in sort!(collect(plan.lengthscale_loo_scores);
                    by = first)),
            "mercier_scaled_margin_loo_rmse" => plan.mercier_loo_rmse,
            "ballooning_scaled_margin_loo_rmse" => plan.ballooning_loo_rmse,
            "warning" => "$(length(plan.observations)) observations support this acquisition fit but do not by themselves validate surrogate accuracy. LOO errors and posterior uncertainty must remain attached to every acquisition.",
        ),
        "observations" => [Dict{String,Any}(
            "pool_index" => item.pool_index,
            "physics_hash" => item.physics_hash,
            "minimum_mercier_D_normalized" =>
                item.minimum_mercier_D_normalized,
            "maximum_infinite_n_ballooning_lambda" =>
                item.maximum_infinite_n_ballooning_lambda,
            "resolution_audited" => item.resolution_audited,
        ) for item in plan.observations],
        "acquisitions" => [Dict{String,Any}(
            "acquisition_rank" => item.acquisition_rank,
            "pool_index" => item.proposal.pool_index,
            "design_id" => item.proposal.genome.design_id,
            "physics_hash" => item.proposal.genome.physics_hash,
            "field_periods" => item.proposal.build_spec.field_periods,
            "genome" => item.proposal.genome.normalized,
            "predicted_mercier_scaled_margin" =>
                item.predicted_mercier_scaled_margin,
            "predicted_ballooning_scaled_margin" =>
                item.predicted_ballooning_scaled_margin,
            "predicted_joint_scaled_margin" =>
                item.predicted_joint_scaled_margin,
            "posterior_standard_deviation" =>
                item.posterior_standard_deviation,
            "exploration_bonus" => item.exploration_bonus,
            "diversity_distance" => item.diversity_distance,
            "diversity_bonus" => item.diversity_bonus,
            "acquisition_score" => item.acquisition_score,
            "physical_evidence_status" => "not_evaluated",
        ) for item in plan.acquisitions],
    )
end
