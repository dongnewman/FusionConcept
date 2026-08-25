const _FAILURE_SCOPE_RANK_V1 = Dict(
    "parameter_instance" => 1, "parameter_region" => 2, "control_policy" => 2,
    "closure_model" => 3, "interaction_hypothesis" => 4, "topology_skeleton" => 5,
    "mission_contract" => 5, "numerical_method" => 1, "coupling_contract" => 3,
)

function audit_failure_scope_escalation_v1(record, target_scope::AbstractString;
        minimum_tuning_budget = 3.0, required_alternative_count = 1)
    item = deepcopy(_plain_json(record))
    errors = validate_failure_record_v1(item)
    current = String(get(item, "scope_type", "parameter_instance"))
    target = String(target_scope)
    haskey(_FAILURE_SCOPE_RANK_V1, target) || push!(errors, "unknown target failure scope $target")
    if haskey(_FAILURE_SCOPE_RANK_V1, current) && haskey(_FAILURE_SCOPE_RANK_V1, target)
        _FAILURE_SCOPE_RANK_V1[target] >= _FAILURE_SCOPE_RANK_V1[current] ||
            push!(errors, "failure scope audit only handles escalation; requested target is narrower")
    end
    if target == "topology_skeleton"
        length(get(item, "excluded_alternatives", Any[])) >= required_alternative_count ||
            push!(errors, "topology escalation lacks required excluded alternatives")
        Float64(get(item, "tuning_budget_consumed", 0.0)) >= Float64(minimum_tuning_budget) ||
            push!(errors, "topology escalation lacks minimum tuning budget")
        !isempty(get(item, "escalation_conditions", Any[])) ||
            push!(errors, "topology escalation lacks predefined escalation conditions")
        current == "numerical_method" && push!(errors, "numerical method failure cannot directly become topology failure")
    end
    return Dict{String,Any}(
        "current_scope" => current, "target_scope" => target,
        "allowed" => isempty(errors), "errors" => unique(errors),
    )
end

