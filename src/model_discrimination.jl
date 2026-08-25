"Evaluate the C0.3a/b/c contract without converting missing evidence into a pass."
function evaluate_model_discrimination_v1(operator_spec)
    spec = _plain_json(operator_spec)
    form = String(get(spec, "form", ""))
    if form != "partial_operator"
        return Dict{String,Any}(
            "detectability_status" => "not_applicable",
            "distinguishability_status" => "not_applicable",
            "identifiability_status" => "not_applicable",
            "reason" => "operator is fully specified for this method fixture",
        )
    end
    effect = get(spec, "minimum_effect_size", nothing)
    floor = get(spec, "noise_and_numerical_floor", nothing)
    comparable = effect isa AbstractDict && floor isa AbstractDict &&
        haskey(effect, "value") && haskey(floor, "value") &&
        get(effect, "unit", nothing) == get(floor, "unit", nothing)
    detectable = comparable && Float64(effect["value"]) > Float64(floor["value"])
    nulls = get(spec, "null_models", Any[])
    alternatives = get(spec, "alternative_models", Any[])
    identifiable = !isempty(get(spec, "identifiability_conditions", Any[])) &&
        !isempty(get(spec, "out_of_sample_prediction_refs", Any[]))
    return Dict{String,Any}(
        "detectability_status" => detectable ? "pass" : comparable ? "fail" : "unknown",
        "distinguishability_status" => !isempty(nulls) && !isempty(alternatives) ? "pass" : "unknown",
        "identifiability_status" => identifiable ? "pass" : "unknown",
        "minimum_effect_size" => effect, "noise_and_numerical_floor" => floor,
        "null_model_count" => length(nulls), "alternative_model_count" => length(alternatives),
        "out_of_sample_prediction_count" => length(get(spec, "out_of_sample_prediction_refs", Any[])),
    )
end

function evaluate_candidate_discrimination_v1(value)
    genome = value isa OpenWorldGenomeV2 ? value : parse_open_world_genome_v2(value)
    results = Dict{String,Any}()
    for interaction in get(genome.data, "interactions", Any[])
        results[String(get(interaction, "interaction_id", "unknown_interaction"))] =
            evaluate_model_discrimination_v1(get(interaction, "operator_spec", Dict{String,Any}()))
    end
    return results
end

