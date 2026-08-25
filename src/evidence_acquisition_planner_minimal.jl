function default_evidence_capabilities_minimal_v1()
    return Any[
        Dict("capability_id" => "analytic_linear_balance_v1", "type" => "analytic",
            "supported_requests" => Any["negative_control", "bounded_error", "model_discrimination"],
            "assumptions" => Any["lumped_state", "bounded_coefficients"],
            "outputs" => Any["analytic_trajectory", "residual_bound"], "VVUQ_status" => "verified_fixture",
            "validity_domain" => Any["plasma", "material", "circuit"],
            "cost_model" => Dict("relative_cost" => 1.0), "safety_envelope" => "non_experimental",
            "provenance" => Dict("implementation" => "FusionConceptAI")),
        Dict("capability_id" => "generic_ode_event_adapter_v1", "type" => "numerical",
            "supported_requests" => Any["negative_control", "bounded_error", "event_trajectory"],
            "assumptions" => Any["0d_or_1d_reduced_model", "nonstiff_or_resolved_timestep"],
            "outputs" => Any["trajectory", "convergence_report", "conservation_residual"],
            "VVUQ_status" => "code_verified_for_linear_fixture", "validity_domain" => Any["plasma", "material", "circuit"],
            "cost_model" => Dict("relative_cost" => 2.0), "safety_envelope" => "non_experimental",
            "provenance" => Dict("implementation" => "FusionConceptAI")),
        Dict("capability_id" => "diagnostic_design_task_v1", "type" => "diagnostic_development",
            "supported_requests" => Any["model_discrimination", "missing_observable"], "assumptions" => Any[],
            "outputs" => Any["diagnostic_requirements"], "VVUQ_status" => "planning_only",
            "validity_domain" => Any["plasma", "material", "radiation", "environment"],
            "cost_model" => Dict("relative_cost" => 10.0), "safety_envelope" => "requires_later_review",
            "provenance" => Dict("implementation" => "FusionConceptAI")),
    ]
end

function build_evidence_request_minimal_v1(obligation; budget_limit = 5.0)
    item = _plain_json(obligation)
    return Dict{String,Any}(
        "request_id" => "request_$(get(item, "obligation_id", "unknown"))",
        "question" => String(get(item, "discrimination_requirement", "resolve_obligation")),
        "target_obligations" => Any[String(get(item, "obligation_id", "unknown"))],
        "admissible_evidence_classes" => Any[String.(get(item, "acceptable_evidence_classes", Any["analytic", "numerical"]))...],
        "required_discrimination_power" => String(get(item, "discrimination_requirement", "bounded")),
        "required_uncertainty" => String(get(item, "uncertainty_requirement", "bounded")),
        "validity_domain" => Any["plasma"], "safety_constraints" => Any["non_experimental_first"],
        "budget_limits" => Dict("relative_cost" => Float64(budget_limit)), "deadline_or_priority" => "normal",
    )
end

"Cheapest admissible evidence route first; information gain never overrides a gate failure."
function plan_evidence_acquisition_minimal_v1(request;
        capabilities = default_evidence_capabilities_minimal_v1())
    req = _plain_json(request)
    admissible = Set(String.(get(req, "admissible_evidence_classes", Any[])))
    question = String(get(req, "required_discrimination_power", get(req, "question", "")))
    budget = Float64(get(get(req, "budget_limits", Dict{String,Any}()), "relative_cost", Inf))
    matches = Dict{String,Any}[]
    for capability in capabilities
        kind = String(get(capability, "type", ""))
        supported = String.(get(capability, "supported_requests", Any[]))
        cost = Float64(get(get(capability, "cost_model", Dict{String,Any}()), "relative_cost", Inf))
        class_allowed = kind in admissible || (kind == "diagnostic_development" && "experimental" in admissible)
        question_supported = any(token -> occursin(token, question) || occursin(question, token), supported)
        class_allowed && question_supported && cost <= budget && push!(matches, capability)
    end
    sort!(matches; by = item -> Float64(item["cost_model"]["relative_cost"]))
    selected = isempty(matches) ? Any[] : Any[String(matches[1]["capability_id"])]
    fallbacks = length(matches) <= 1 ? Any[] : Any[String(item["capability_id"]) for item in matches[2:end]]
    return Dict{String,Any}(
        "plan_id" => "plan_$(get(req, "request_id", "unknown"))",
        "selected_routes" => selected, "route_dependencies" => Any[],
        "expected_information_gain" => isempty(selected) ? 0.0 : 1.0,
        "expected_total_cost" => isempty(matches) ? nothing : matches[1]["cost_model"]["relative_cost"],
        "decision_thresholds" => Any["obligation_status_changes_from_unknown"],
        "fallback_routes" => fallbacks,
        "stop_conditions" => Any["pass", "fail", "unsupported", "budget_exhausted"],
        "status" => isempty(selected) ? "evidence_route_unknown" : "planned",
    )
end

function plan_candidate_evidence_minimal_v1(compilation::OpenWorldCompilationV2; budget_limit = 5.0)
    plans = Dict{String,Any}[]
    for obligation in compilation.obligation_graph["obligations"]
        get(obligation, "status", "unknown") == "unknown" || continue
        request = build_evidence_request_minimal_v1(obligation; budget_limit = budget_limit)
        plan = plan_evidence_acquisition_minimal_v1(request)
        push!(plans, Dict("obligation_id" => obligation["obligation_id"], "request" => request, "plan" => plan))
    end
    return plans
end

