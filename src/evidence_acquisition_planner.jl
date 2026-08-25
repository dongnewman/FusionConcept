function default_evidence_capability_registry_v1()
    return Any[
        Dict("capability_id" => "analytic_interval_bound_v1", "type" => "analytic",
            "supported_question_kinds" => Any["parameter_bound", "conservation_bound", "negative_control"],
            "assumptions" => Any["monotone_bounded_quantity"], "outputs" => Any["interval_proof"],
            "VVUQ_status" => "verified_analytic", "validity_domain" => Any["reduced_model"],
            "cost_model" => Dict("relative_cost" => 1.0), "safety_envelope" => "non_experimental",
            "correlation_group" => "analytic_kernel_v1", "provenance" => Dict("source" => "FusionConceptAI")),
        Dict("capability_id" => "generic_ode_event_adapter_v1", "type" => "numerical",
            "supported_question_kinds" => Any["trajectory", "event_response", "negative_control"],
            "assumptions" => Any["resolved_reduced_dynamics"], "outputs" => Any["trajectory", "error_report"],
            "VVUQ_status" => "verified_reduced_fixture", "validity_domain" => Any["reduced_model"],
            "cost_model" => Dict("relative_cost" => 2.0), "safety_envelope" => "non_experimental",
            "correlation_group" => "reduced_balance_model_v1", "provenance" => Dict("source" => "FusionConceptAI")),
        Dict("capability_id" => "existing_data_adapter_v1", "type" => "existing_experimental_data",
            "supported_question_kinds" => Any["heldout_observable", "parameter_bound"],
            "assumptions" => Any["applicability_proof_available"], "outputs" => Any["adapted_observation"],
            "VVUQ_status" => "adapter_prototype", "validity_domain" => Any["declared_dataset_domain"],
            "cost_model" => Dict("relative_cost" => 3.0), "safety_envelope" => "read_only_data",
            "correlation_group" => "source_dataset", "provenance" => Dict("source" => "external_data")),
        Dict("capability_id" => "discriminating_testbed_plan_v1", "type" => "new_discriminating_experiment",
            "supported_question_kinds" => Any["model_discrimination", "heldout_observable"],
            "assumptions" => Any["safety_review_required"], "outputs" => Any["experiment_plan"],
            "VVUQ_status" => "planning_only", "validity_domain" => Any["testbed_only"],
            "cost_model" => Dict("relative_cost" => 20.0), "safety_envelope" => "no_execution_authority",
            "correlation_group" => "future_testbed", "provenance" => Dict("source" => "planning")),
        Dict("capability_id" => "diagnostic_development_queue_v1", "type" => "diagnostic_development",
            "supported_question_kinds" => Any["missing_observable", "model_discrimination"],
            "assumptions" => Any[], "outputs" => Any["diagnostic_requirements"], "VVUQ_status" => "planning_only",
            "validity_domain" => Any["unresolved"], "cost_model" => Dict("relative_cost" => 10.0),
            "safety_envelope" => "no_execution_authority", "correlation_group" => "future_diagnostic",
            "provenance" => Dict("source" => "planning")),
        Dict("capability_id" => "solver_model_rd_queue_v1", "type" => "solver_or_model_rd",
            "supported_question_kinds" => Any["missing_solver", "coupling_unsupported", "unknown_operator"],
            "assumptions" => Any[], "outputs" => Any["R&D_task"], "VVUQ_status" => "planning_only",
            "validity_domain" => Any["unresolved"], "cost_model" => Dict("relative_cost" => 15.0),
            "safety_envelope" => "software_research_only", "correlation_group" => "future_solver",
            "provenance" => Dict("source" => "planning")),
    ]
end

function plan_evidence_acquisition_v1(request; capabilities = default_evidence_capability_registry_v1())
    req = _plain_json(request)
    question_kind = String(get(req, "question_kind", get(req, "question", "unknown")))
    admissible = Set(String.(get(req, "admissible_evidence_classes", Any[])))
    budget = Float64(get(get(req, "budget_limits", Dict{String,Any}()), "relative_cost", Inf))
    routes = Dict{String,Any}[]
    for capability in capabilities
        kind = String(capability["type"])
        supported = question_kind in String.(capability["supported_question_kinds"])
        cost = Float64(capability["cost_model"]["relative_cost"])
        supported && kind in admissible && cost <= budget && push!(routes, capability)
    end
    sort!(routes; by = item -> (Float64(item["cost_model"]["relative_cost"]), String(item["capability_id"])))
    selected = isempty(routes) ? Any[] : Any[routes[1]["capability_id"]]
    return Dict{String,Any}(
        "plan_id" => "plan_$(get(req, "request_id", "unknown"))", "selected_routes" => selected,
        "route_dependencies" => Any[], "expected_information_gain" => isempty(selected) ? 0.0 : 1.0,
        "expected_total_cost" => isempty(routes) ? nothing : routes[1]["cost_model"]["relative_cost"],
        "decision_thresholds" => Any[get(req, "decision_threshold", "change_obligation_state")],
        "fallback_routes" => isempty(routes) ? Any[] : Any[item["capability_id"] for item in routes[2:end]],
        "stop_conditions" => Any["pass", "fail", "unsupported", "budget_exhausted"],
        "route_correlations" => Any[Dict("capability_id" => item["capability_id"],
            "correlation_group" => item["correlation_group"]) for item in routes],
        "status" => isempty(selected) ? "evidence_route_unknown" : "planned",
    )
end

function resolve_obligation_with_analytic_bound_v1(obligation; interval, pass_upper_bound)
    item = _plain_json(obligation)
    lower, upper = Float64(interval[1]), Float64(interval[2])
    status = upper <= Float64(pass_upper_bound) ? "pass" : lower > Float64(pass_upper_bound) ? "fail" : "unknown"
    return Dict{String,Any}(
        "obligation_id" => String(get(item, "obligation_id", "unknown")), "status" => status,
        "evidence_class" => "analytic", "interval" => Any[lower, upper], "decision_threshold" => Float64(pass_upper_bound),
        "failure_scope" => status == "fail" ? "parameter_region" : nothing,
        "promotion_scope_ceiling" => "C1", "independent_confirmation" => false,
        "reproduction_trace" => "compare interval upper/lower bounds with frozen threshold",
    )
end

