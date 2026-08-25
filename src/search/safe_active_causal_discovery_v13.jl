const _SAV13_CLAIM_BOUNDARY =
    "Family-neutral surrogate-assisted evaluation scheduler over the sealed v12 causal paths. The dependency-free kernel surrogate ranks proposals and estimates local uncertainty only. It cannot pass a physics gate, override a negative anchor, impute missing evidence, authorize medium fidelity, establish feasibility, or claim an optimum. Every promotion requires reconstruction and explicit evaluation under the recorded family evaluator."

const _SAV13_SOURCE_BASIS = String[
    "map_elites_mouret_clune_2015",
    "constrained_bo_gardner_2014",
    "unknown_constraints_gelbart_2014",
    "safeopt_sui_2015",
    "sail_gaier_2018",
]

struct SafeActiveCausalDiscoveryConfigV13
    calibration_samples::Int
    proposal_pool_samples::Int
    explicit_batch_size::Int
    neighbor_count::Int
    exploration_weight::Float64
    diversity_weight::Float64
    label_floor::Float64
    label_ceiling::Float64

    function SafeActiveCausalDiscoveryConfigV13(;
            calibration_samples::Integer = 360,
            proposal_pool_samples::Integer = 60_000,
            explicit_batch_size::Integer = 360,
            neighbor_count::Integer = 5,
            exploration_weight::Real = 1.0,
            diversity_weight::Real = 0.15,
            label_floor::Real = -5.0,
            label_ceiling::Real = 1.0)
        calibration_samples >= 0 || throw(ArgumentError(
            "calibration_samples must be non-negative"))
        proposal_pool_samples > 0 || throw(ArgumentError(
            "proposal_pool_samples must be positive"))
        explicit_batch_size > 0 || throw(ArgumentError(
            "explicit_batch_size must be positive"))
        neighbor_count >= 2 || throw(ArgumentError(
            "neighbor_count must be at least two"))
        all(isfinite, (exploration_weight, diversity_weight)) &&
            exploration_weight >= 0 && diversity_weight >= 0 ||
            throw(ArgumentError("acquisition weights must be finite and non-negative"))
        isfinite(label_floor) && isfinite(label_ceiling) &&
            label_floor < label_ceiling || throw(ArgumentError(
            "label bounds must be finite and increasing"))
        return new(Int(calibration_samples), Int(proposal_pool_samples),
            Int(explicit_batch_size), Int(neighbor_count),
            Float64(exploration_weight), Float64(diversity_weight),
            Float64(label_floor), Float64(label_ceiling))
    end
end

_sav13_path_key(spec::CausalBridgeTopologySpecV12) = _cbv12_key(spec)

function _sav13_path_record(spec::CausalBridgeTopologySpecV12)
    input_path, confinement_path, loss_path, conversion_path, evidence_boundary =
        if _cbv12_is_control(spec)
            ("sealed_v11_declared_input", "sealed_v11_family_model",
                spec.exhaust_topology, occursin("converter", spec.exhaust_topology) ?
                    "bounded_direct_conversion" : "thermal_conversion_only",
                "sealed_v11_gate_set")
        elseif spec.core_family == "magnetic_mirror"
            ("neutral_beam_plus_vortex_bias", "warm_target_plus_fast_ion_mirror",
                "gas_dynamic_axial_plus_bohm_transverse",
                "thermal_conversion_only", "two_component_inventory_and_stability")
        elseif spec.core_family == "inertial_electrostatic_confinement"
            ("electrostatic_high_voltage", "gridded_nonequilibrium_orbits",
                "grid_interception_plus_spherical_wall", "thermal_conversion_only",
                spec.anchor_only ? "negative_anchor_nonpromotion" :
                    "nonequilibrium_recirculating_power_hard_gate")
        else
            ("capacitor_bank_pulse", "coaxial_dense_plasma_focus",
                "electrode_plus_pulsed_chamber", "thermal_conversion_only",
                "negative_anchor_nonpromotion_and_electrode_lifetime")
        end
    evaluator = _cbv12_is_control(spec) ? "OpenLossPathwayScreenV1" :
        "CausalBridgeScreenV1"
    return Dict{String,Any}(
        "path_key" => _sav13_path_key(spec),
        "core_family" => spec.core_family,
        "mechanism" => spec.mechanism,
        "exhaust_topology" => spec.exhaust_topology,
        "target_count" => spec.target_count,
        "input_path" => input_path,
        "confinement_path" => confinement_path,
        "stability_or_sustainment_path" => spec.mechanism,
        "loss_path" => loss_path,
        "conversion_path" => conversion_path,
        "evidence_boundary" => evidence_boundary,
        "explicit_evaluator" => evaluator,
        "anchor_only" => spec.anchor_only,
        "promotion_eligible" => spec.promotion_eligible,
        "surrogate_can_authorize_promotion" => false)
end

function _sav13_nominal(base::Genome, spec::CausalBridgeTopologySpecV12,
        contract::SharedOuterEnvelopeContractV1, values::AbstractDict)
    features = _cbv12_acquisition_features(base, values)
    if _cbv12_is_control(spec)
        old = only(filter(item -> _olv11_key(item) == spec.control_v11_key,
            _olv11_topology_specs()))
        return _olv11_is_control(old) ?
            _mev10_nominal(base, contract, features, values) :
            _olv11_nominal(base, contract, features, values)
    end
    return _cbv12_nominal(base, contract, features, values)
end

function _sav13_explicit(base::Genome, spec::CausalBridgeTopologySpecV12,
        contract::SharedOuterEnvelopeContractV1, values::AbstractDict, contracts)
    candidate = _cbv12_instantiate(base, spec, values, contract)
    result = if _cbv12_is_control(spec)
        _open_loss_pathway_result(OpenLossPathwayScreenV1(contract;
            allowed_contracts = contracts), candidate)
    else
        _causal_bridge_result(CausalBridgeScreenV1(contract;
            allowed_contracts = contracts), candidate)
    end
    return candidate, result
end

function _sav13_explicit_margin(result::AbstractDict)
    nominal = result["nominal"]
    nominal_margin = minimum(Float64(value) for value in
        Base.values(nominal["margins"]))
    robustness = result["robustness"]
    get(robustness, "skipped_due_nominal_gate_failure", false) === true &&
        return nominal_margin
    pass_fraction = Float64(get(robustness, "pass_fraction", 0.0))
    required = Float64(get(robustness, "required_pass_fraction", 0.95))
    robustness_margin = (pass_fraction - required) / max(required, 1.0e-12)
    return min(nominal_margin, robustness_margin)
end

function _sav13_augmented_features(values::AbstractDict,
        contract::SharedOuterEnvelopeContractV1)
    result = Dict{String,Float64}()
    for (key, value) in values
        value isa Real || continue
        isfinite(Float64(value)) || continue
        result[String(key)] = Float64(value)
    end
    result["contract_plasma_field_T"] = contract.plasma_field_T
    result["contract_outer_radial_extent_m"] = contract.outer_radial_extent_m
    result["contract_outer_axial_half_extent_m"] = contract.outer_axial_half_extent_m
    result["contract_maximum_exhaust_heat_flux_W_m2"] =
        contract.maximum_exhaust_heat_flux_W_m2
    return result
end

function _sav13_scaler(rows::Vector{Dict{String,Float64}})
    keys_all = sort!(unique(reduce(vcat, [collect(keys(row)) for row in rows];
        init = String[])))
    scaler = Dict{String,NamedTuple}()
    for key in keys_all
        values = Float64[get(row, key, 0.0) for row in rows]
        positive = all(>(0.0), values)
        spread = positive ? maximum(values) / max(minimum(values), 1.0e-300) : 1.0
        mode = positive && spread > 100.0 ? :log10 : :linear
        transformed = mode == :log10 ? log10.(values) : values
        low, high = minimum(transformed), maximum(transformed)
        high > low + 1.0e-15 || continue
        scaler[key] = (mode = mode, low = low, high = high)
    end
    return scaler
end

function _sav13_vector(row::Dict{String,Float64}, scaler::AbstractDict)
    result = Float64[]
    for key in sort!(collect(keys(scaler)))
        item = scaler[key]
        raw = get(row, key, 0.0)
        value = item.mode == :log10 ? log10(max(raw, 1.0e-300)) : raw
        push!(result, (value - item.low) / (item.high - item.low))
    end
    return result
end

_sav13_distance(left::Vector{Float64}, right::Vector{Float64}) =
    sqrt(sum((left .- right) .^ 2) / max(length(left), 1))

function _sav13_kernel_predict(vectors::Vector{Vector{Float64}},
        labels::Vector{Float64}, query::Vector{Float64}, neighbor_count::Int;
        excluded::Int = 0)
    distances = Tuple{Float64,Int}[]
    for index in eachindex(vectors)
        index == excluded && continue
        push!(distances, (_sav13_distance(vectors[index], query), index))
    end
    isempty(distances) && throw(ArgumentError("surrogate has no observations"))
    sort!(distances; by = item -> (first(item), last(item)))
    retained = first(distances, min(neighbor_count, length(distances)))
    bandwidth = max(last(retained)[1], 1.0e-6)
    weights = Float64[exp(-0.5(first(item) / bandwidth)^2) for item in retained]
    weight_sum = sum(weights)
    mean_value = sum(weights[i] * labels[retained[i][2]] for i in eachindex(retained)) /
        weight_sum
    disagreement = sqrt(sum(weights[i] *
        (labels[retained[i][2]] - mean_value)^2 for i in eachindex(retained)) /
        weight_sum)
    nearest = first(first(retained))
    uncertainty = sqrt(disagreement^2 + nearest^2)
    return (mean = mean_value, uncertainty = uncertainty,
        nearest_distance = nearest, neighbor_count = length(retained))
end

function _sav13_model_audit(vectors, labels, neighbor_count)
    errors = Float64[]
    for index in eachindex(vectors)
        prediction = _sav13_kernel_predict(vectors, labels, vectors[index],
            neighbor_count; excluded = index)
        push!(errors, prediction.mean - labels[index])
    end
    return (loo_rmse = sqrt(sum(errors .^ 2) / length(errors)),
        loo_maximum_absolute_error = maximum(abs.(errors)))
end

function _sav13_candidate(index::Int, structural, specs, contracts, primes)
    strata_count = length(specs) * length(contracts)
    stratum_index = mod1(index, strata_count)
    contract_index = fld(stratum_index - 1, length(specs)) + 1
    spec_index = mod1(stratum_index, length(specs))
    contract, spec = contracts[contract_index], specs[spec_index]
    u = ntuple(axis -> _ctv4_halton(index, primes[axis]), length(primes))
    values = _cbv12_ranges(spec, u)
    base = structural[_cbv12_key(spec)]
    nominal = _sav13_nominal(base, spec, contract, values)
    margin = minimum(Float64(value) for value in Base.values(nominal["margins"]))
    return Dict{String,Any}(
        "sequence_index" => index,
        "path_key" => _sav13_path_key(spec),
        "structural_stratum" => "$(contract.id)|$(_sav13_path_key(spec))",
        "contract_id" => contract.id,
        "features" => values,
        "augmented_features" => _sav13_augmented_features(values, contract),
        "nominal_minimum_margin" => margin,
        "nominal_net_electric_power_W" => Float64(nominal["net_electric_power_W"]),
        "nominal_physics_gate_passed" => nominal["physics_gate_passed"],
        "nominal_engineering_gate_passed" => nominal["engineering_gate_passed"])
end

function _sav13_find_spec(record::AbstractDict, spec_by_key)
    stratum = String(record["acquisition"]["structural_stratum"])
    key = join(split(stratum, "|")[2:end], "|")
    haskey(spec_by_key, key) || error("v12 record uses unknown path $key")
    return spec_by_key[key]
end

function run_safe_active_causal_discovery_v13(seeds::Vector{Genome},
        v12_artifact_raw;
        config::SafeActiveCausalDiscoveryConfigV13 =
            SafeActiveCausalDiscoveryConfigV13(),
        contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    artifact = _plain_json(v12_artifact_raw)
    get(artifact, "search_version", "") == "causal_bridge_qd_v12" ||
        throw(ArgumentError("v13 requires the sealed v12 artifact"))
    get(artifact, "result_hash", "") ==
        "583fa8dacdafbd017db705fa4cb5a4f40b2eae1ad337ac14ec142844ce1f1bec" ||
        throw(ArgumentError("v13 input v12 result hash is not sealed"))
    specs = _cbv12_topology_specs()
    structural = _cbv12_structural_bases(seeds)
    spec_by_key = Dict(_sav13_path_key(spec) => spec for spec in specs)
    contract_by_id = Dict(contract.id => contract for contract in contracts)
    strata_count = length(specs) * length(contracts)
    config.explicit_batch_size <= config.proposal_pool_samples ||
        throw(ArgumentError("explicit batch exceeds proposal pool"))
    primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61)

    observations = Dict{String,Any}[]
    reconstruction_violations = 0
    for record in artifact["causal_bridge_qd"]["records"]
        spec = _sav13_find_spec(record, spec_by_key)
        contract = contract_by_id[String(record["contract_id"])]
        values = Dict{String,Any}(String(key) => value for (key, value) in
            record["acquisition"]["features"])
        candidate = _cbv12_instantiate(structural[_cbv12_key(spec)], spec,
            values, contract)
        candidate.physics_hash == String(record["physics_hash"]) ||
            (reconstruction_violations += 1)
        push!(observations, Dict{String,Any}(
            "origin" => "sealed_v12_elite",
            "path_key" => _sav13_path_key(spec),
            "structural_stratum" => "$(contract.id)|$(_sav13_path_key(spec))",
            "contract_id" => contract.id,
            "physics_hash" => candidate.physics_hash,
            "features" => _sav13_augmented_features(values, contract),
            "explicit_margin" => _sav13_explicit_margin(record["evaluation"]),
            "all_five_gates_passed" => record["all_five_gates_passed"],
            "positive_net_power_closure_passed" =>
                record["positive_net_power_closure_passed"]))
    end
    reconstruction_violations == 0 || error(
        "v12 compact records failed deterministic genome reconstruction")

    calibration_start = Int(artifact["causal_bridge_qd"]["acquisition_samples"]) + 1
    baseline_records = Dict{String,Any}[]
    for offset in 0:(config.calibration_samples - 1)
        proposal = _sav13_candidate(calibration_start + offset, structural, specs,
            contracts, primes)
        spec = spec_by_key[String(proposal["path_key"])]
        contract = contract_by_id[String(proposal["contract_id"])]
        candidate, result = _sav13_explicit(structural[_cbv12_key(spec)], spec,
            contract, proposal["features"], contracts)
        promoted = spec.promotion_eligible &&
            result["all_five_gates_passed"] === true &&
            result["positive_net_power_closure_passed"] === true
        push!(baseline_records, Dict{String,Any}(
            "selection_stage" => "blind_halton_calibration_baseline",
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
            "surrogate_prediction" => nothing,
            "acquisition_score" => nothing,
            "explicit_margin" => _sav13_explicit_margin(result),
            "evaluation" => result,
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "positive_net_power_closure_passed" =>
                result["positive_net_power_closure_passed"],
            "promoted" => promoted,
            "medium_fidelity_route" => promoted ?
                _cbv12_medium_fidelity_route(spec) : String[]))
        push!(observations, Dict{String,Any}(
            "origin" => "v13_explicit_calibration",
            "path_key" => proposal["path_key"],
            "structural_stratum" => proposal["structural_stratum"],
            "contract_id" => proposal["contract_id"],
            "physics_hash" => candidate.physics_hash,
            "features" => proposal["augmented_features"],
            "explicit_margin" => _sav13_explicit_margin(result),
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "positive_net_power_closure_passed" =>
                result["positive_net_power_closure_passed"]))
    end

    pool_start = calibration_start + config.calibration_samples
    pool = Dict{String,Any}[_sav13_candidate(pool_start + offset, structural,
        specs, contracts, primes) for offset in 0:(config.proposal_pool_samples - 1)]
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

    model_audits = Dict{String,Any}()
    for path_key in sort!(collect(keys(pool_by_path)))
        obs = observations_by_path[path_key]
        candidates = pool_by_path[path_key]
        rows = vcat(Dict{String,Float64}[item["features"] for item in obs],
            Dict{String,Float64}[item["augmented_features"] for item in candidates])
        scaler = _sav13_scaler(rows)
        vectors = [_sav13_vector(item["features"], scaler) for item in obs]
        labels = clamp.([Float64(item["explicit_margin"]) for item in obs],
            config.label_floor, config.label_ceiling)
        audit = _sav13_model_audit(vectors, labels, config.neighbor_count)
        model_audits[path_key] = Dict{String,Any}(
            "observation_count" => length(obs),
            "historical_observation_count" => count(item ->
                item["origin"] == "sealed_v12_elite", obs),
            "calibration_observation_count" => count(item ->
                item["origin"] == "v13_explicit_calibration", obs),
            "feature_dimension" => length(scaler),
            "neighbor_count" => min(config.neighbor_count, length(obs) - 1),
            "loo_rmse" => audit.loo_rmse,
            "loo_maximum_absolute_error" => audit.loo_maximum_absolute_error,
            "posterior_or_safeopt_guarantee_claimed" => false)
        for proposal in candidates
            vector = _sav13_vector(proposal["augmented_features"], scaler)
            prediction = _sav13_kernel_predict(vectors, labels, vector,
                config.neighbor_count)
            nominal = clamp(Float64(proposal["nominal_minimum_margin"]),
                config.label_floor, config.label_ceiling)
            conservative_mean = min(nominal, prediction.mean)
            proposal["surrogate_prediction"] = Dict{String,Any}(
                "predicted_explicit_margin" => prediction.mean,
                "local_uncertainty" => prediction.uncertainty,
                "nearest_observation_distance" => prediction.nearest_distance,
                "conservative_joint_margin" => conservative_mean,
                "surrogate_can_authorize_promotion" => false)
            proposal["acquisition_score"] = conservative_mean +
                config.exploration_weight * prediction.uncertainty +
                config.diversity_weight * prediction.nearest_distance
        end
    end

    by_stratum = Dict{String,Vector{Dict{String,Any}}}()
    for proposal in pool
        push!(get!(by_stratum, String(proposal["structural_stratum"]),
            Dict{String,Any}[]), proposal)
    end
    first_round = Dict{String,Any}[]
    for stratum in sort!(collect(keys(by_stratum)))
        ranked = sort!(by_stratum[stratum]; by = item ->
            (-Float64(item["acquisition_score"]), Int(item["sequence_index"])))
        push!(first_round, first(ranked))
    end
    sort!(first_round; by = item ->
        (-Float64(item["acquisition_score"]), String(item["structural_stratum"])))
    selected = first(first_round, min(config.explicit_batch_size, length(first_round)))
    if length(selected) < config.explicit_batch_size
        selected_indices = Set(Int(item["sequence_index"]) for item in selected)
        remaining = filter(item -> !(Int(item["sequence_index"]) in selected_indices), pool)
        sort!(remaining; by = item ->
            (-Float64(item["acquisition_score"]), Int(item["sequence_index"])))
        append!(selected, first(remaining,
            min(config.explicit_batch_size - length(selected), length(remaining))))
    end
    sort!(selected; by = item -> Int(item["sequence_index"]))

    active_records = Dict{String,Any}[]
    for proposal in selected
        spec = spec_by_key[String(proposal["path_key"])]
        contract = contract_by_id[String(proposal["contract_id"])]
        candidate, result = _sav13_explicit(structural[_cbv12_key(spec)], spec,
            contract, proposal["features"], contracts)
        promoted = spec.promotion_eligible &&
            result["all_five_gates_passed"] === true &&
            result["positive_net_power_closure_passed"] === true
        push!(active_records, Dict{String,Any}(
            "selection_stage" => "surrogate_active_batch",
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
            "surrogate_prediction" => proposal["surrogate_prediction"],
            "acquisition_score" => proposal["acquisition_score"],
            "explicit_margin" => _sav13_explicit_margin(result),
            "evaluation" => result,
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "positive_net_power_closure_passed" =>
                result["positive_net_power_closure_passed"],
            "promoted" => promoted,
            "medium_fidelity_route" => promoted ?
                _cbv12_medium_fidelity_route(spec) : String[]))
    end
    sort!(baseline_records; by = item -> (item["promoted"] === true ? 0 : 1,
        -Float64(item["explicit_margin"]), String(item["physics_hash"])))
    sort!(active_records; by = item -> (item["promoted"] === true ? 0 : 1,
        -Float64(item["explicit_margin"]), String(item["physics_hash"])))
    all_explicit_records = vcat(baseline_records, active_records)
    promoted_records = filter(item -> item["promoted"] === true,
        all_explicit_records)
    return Dict{String,Any}(
        "algorithm" => "causal-path-stratified kernel surrogate acquisition followed by mandatory explicit evaluation",
        "claim_boundary" => _SAV13_CLAIM_BOUNDARY,
        "config" => Dict{String,Any}(
            "calibration_samples" => config.calibration_samples,
            "proposal_pool_samples" => config.proposal_pool_samples,
            "explicit_batch_size" => config.explicit_batch_size,
            "neighbor_count" => config.neighbor_count,
            "exploration_weight" => config.exploration_weight,
            "diversity_weight" => config.diversity_weight,
            "label_floor" => config.label_floor,
            "label_ceiling" => config.label_ceiling),
        "path_count" => length(specs),
        "contract_count" => length(contracts),
        "structural_stratum_count" => strata_count,
        "causal_paths" => [_sav13_path_record(spec) for spec in specs],
        "historical_observation_count" => length(
            artifact["causal_bridge_qd"]["records"]),
        "historical_reconstruction_violation_count" => reconstruction_violations,
        "explicit_calibration_count" => length(baseline_records),
        "total_observation_count" => length(observations),
        "proposal_pool_count" => length(pool),
        "selected_explicit_evaluation_count" => length(active_records),
        "selected_structural_stratum_count" => length(unique(
            String(item["structural_stratum"]) for item in active_records)),
        "model_audits" => model_audits,
        "blind_baseline_records" => baseline_records,
        "active_records" => active_records,
        "total_new_explicit_evaluation_count" => length(all_explicit_records),
        "blind_baseline_five_gate_pass_count" => count(item ->
            item["all_five_gates_passed"] === true, baseline_records),
        "active_five_gate_pass_count" => count(item ->
            item["all_five_gates_passed"] === true, active_records),
        "blind_baseline_positive_net_count" => count(item ->
            item["positive_net_power_closure_passed"] === true, baseline_records),
        "active_positive_net_count" => count(item ->
            item["positive_net_power_closure_passed"] === true, active_records),
        "explicit_five_gate_pass_count" => count(item ->
            item["all_five_gates_passed"] === true, all_explicit_records),
        "explicit_positive_net_count" => count(item ->
            item["positive_net_power_closure_passed"] === true,
            all_explicit_records),
        "explicit_promotion_count" => length(promoted_records),
        "negative_anchor_promotion_count" => count(item ->
            item["anchor_only"] === true && item["promoted"] === true,
            all_explicit_records),
        "surrogate_only_promotion_count" => 0,
        "surrogate_positive_explicit_rejection_count" => count(item ->
            Float64(item["surrogate_prediction"]["conservative_joint_margin"]) >= 0.0 &&
            item["all_five_gates_passed"] !== true, active_records),
        "medium_fidelity_review_queue" => [Dict{String,Any}(
            "physics_hash" => item["physics_hash"],
            "contract_id" => item["contract_id"],
            "core_family" => item["core_family"],
            "mechanism" => item["mechanism"],
            "route" => item["medium_fidelity_route"]) for item in promoted_records])
end
