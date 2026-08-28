const V99_PROTOCOL_ID = "fusionconceptai-v99-full-device-qualification-20260829"

const FULL_DEVICE_QUALIFICATION_V99_CLAIM_BOUNDARY =
    "v99 preserves candidate-bound equilibrium, sampled local ideal-MHD, complete " *
    "stability, transport and exhaust, engineering, numerical VVUQ, and validation " *
    "as separate evidence obligations. Missing evidence is qualification_incomplete, " *
    "not unsupported and not physical rejection. No subgraph result can promote a " *
    "whole device, and manufactured or reference controls receive no candidate credit."

const V99_FULL_DEVICE_STAGES = (
    "free_boundary_equilibrium",
    "cross_code_equilibrium",
    "sampled_local_ideal_mhd",
    "complete_stability",
    "transport_and_confinement",
    "particle_and_heat_exhaust",
    "engineering_qualification",
    "numerical_vvuq",
    "validation_vvuq",
)

function _v99_evidence_record(stage::AbstractString, evidence_raw)
    evidence = Dict{String,Any}(_v93_plain(evidence_raw))
    status = String(get(evidence, "status", "unknown"))
    status in ("pass", "fail", "unknown", "not_executed") ||
        throw(ArgumentError("invalid evidence status for $stage: $status"))
    scope = String(get(evidence, "scope", "missing"))
    credit = status == "pass" && scope == "candidate_bound"
    Dict{String,Any}(
        "stage" => String(stage),
        "status" => status,
        "scope" => scope,
        "candidate_credit" => credit,
        "result_hash" => get(evidence, "result_hash", nothing),
        "reason" => String(get(evidence, "reason",
            status == "unknown" ? "evidence_not_supplied" : "declared_evidence")),
    )
end

function compile_full_device_qualification_dag_v99(capability_raw)
    capability = Dict{String,Any}(_v93_plain(capability_raw))
    route = String(capability["route"])
    semantics = sort!(unique(String.(capability["declared_field_semantics"])))
    boundaries = sort!(unique(String.(capability["declared_boundaries"])))
    operators = sort!(unique(String.(capability["declared_operators"])))
    dimensions = sort!(unique(Int.(capability["declared_dimensions"])))
    nodes = Dict{String,Any}[
        Dict("stage" => stage, "required" => true) for stage in V99_FULL_DEVICE_STAGES
    ]
    edges = [[V99_FULL_DEVICE_STAGES[index], V99_FULL_DEVICE_STAGES[index + 1]]
        for index in 1:length(V99_FULL_DEVICE_STAGES)-1]
    declared_exhaust = route == "closed_core_open_exhaust" ||
        any(value -> value in ("open_guiding_field", "hybrid_field"), semantics) ||
        "open" in boundaries
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "protocol_id" => V99_PROTOCOL_ID,
        "route" => route,
        "routing_declaration" => Dict(
            "field_semantics" => semantics,
            "boundaries" => boundaries,
            "operators" => operators,
            "dimensions" => dimensions,
        ),
        "nodes" => nodes,
        "edges" => edges,
        "declared_exhaust_region" => declared_exhaust,
        "exhaust_declaration_gap" => !declared_exhaust,
        "identity_fields_used_for_routing" => false,
        "all_nodes_required_for_whole_device" => true,
        "claim_boundary" => FULL_DEVICE_QUALIFICATION_V99_CLAIM_BOUNDARY,
    )
    body["dag_hash"] = canonical_hash(body)
    body
end

function _v99_upstream_records(cross_code_raw)
    cross_code = Dict{String,Any}(_v93_plain(cross_code_raw))
    state = String(cross_code["candidate_state"])
    free = state == "provider_system_fail" ? "not_executed" : "pass"
    cross = state in ("sampled_ideal_mhd_candidate", "stability_screen_fail") ?
        "pass" : state == "cross_code_equilibrium_fail" ? "fail" : "not_executed"
    local_status = state == "sampled_ideal_mhd_candidate" ? "pass" :
        state == "stability_screen_fail" ? "fail" : "not_executed"
    Dict{String,Any}(
        "free_boundary_equilibrium" => Dict("status" => free,
            "scope" => "candidate_bound", "result_hash" =>
            get(cross_code, "freegs_full_result_hash", nothing),
            "reason" => "v98_FreeGS_candidate_bound_equilibrium"),
        "cross_code_equilibrium" => Dict("status" => cross,
            "scope" => "candidate_bound", "result_hash" =>
            get(get(cross_code, "desc_result", Dict()), "result_hash", nothing),
            "reason" => state == "transformer_fit_fail" ?
                "freegs_to_desc_boundary_transform_failed" :
                "independent_DESC_fixed_boundary_equilibrium"),
        "sampled_local_ideal_mhd" => Dict("status" => local_status,
            "scope" => "candidate_bound", "result_hash" =>
            get(get(cross_code, "desc_result", Dict()), "result_hash", nothing),
            "reason" => "sampled_Mercier_and_infinite_n_ballooning_only"),
    )
end

function evaluate_full_device_qualification_v99(capability_raw, cross_code_raw;
        downstream_evidence = Dict{String,Any}())
    dag = compile_full_device_qualification_dag_v99(capability_raw)
    cross_code = Dict{String,Any}(_v93_plain(cross_code_raw))
    downstream = Dict{String,Any}(_v93_plain(downstream_evidence))
    supplied = merge(_v99_upstream_records(cross_code), downstream)
    records = Dict{String,Any}[]
    for stage in V99_FULL_DEVICE_STAGES
        evidence = get(supplied, stage, Dict{String,Any}(
            "status" => "unknown", "scope" => "missing",
            "reason" => "required_provider_evidence_not_supplied"))
        push!(records, _v99_evidence_record(stage, evidence))
    end
    if dag["exhaust_declaration_gap"]
        record = only(filter(item -> item["stage"] ==
            "particle_and_heat_exhaust", records))
        if record["status"] == "pass"
            record["candidate_credit"] = false
            record["reason"] = "topology_has_no_declared_exhaust_region"
        end
    end
    physical_failures = [String(item["stage"]) for item in records if
        item["status"] == "fail"]
    missing = [String(item["stage"]) for item in records if
        item["status"] in ("unknown", "not_executed") ||
        (item["status"] == "pass" && item["candidate_credit"] !== true)]
    upstream_state = String(cross_code["candidate_state"])
    state = if upstream_state == "provider_system_fail"
        "provider_system_fail"
    elseif startswith(upstream_state, "transformer_")
        "transformer_reject"
    elseif !isempty(physical_failures)
        "physical_reject"
    elseif isempty(missing) && all(item -> item["candidate_credit"] === true,
            records)
        "whole_device_validation_pass"
    else
        "qualification_incomplete"
    end
    credible = state == "whole_device_validation_pass"
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "protocol_id" => V99_PROTOCOL_ID,
        "dag_hash" => dag["dag_hash"],
        "candidate_result_hash" => cross_code["candidate_result_hash"],
        "cross_code_result_hash" => cross_code["result_hash"],
        "candidate_state" => state,
        "evidence_records" => records,
        "physical_failure_stages" => physical_failures,
        "incomplete_or_noncredit_stages" => missing,
        "whole_device_credible" => credible,
        "validation_pass" => credible,
        "unsupported_candidate_classification_used" => false,
        "subgraph_promotion_allowed" => false,
        "identity_fields_used_for_routing" => false,
        "claim_boundary" => FULL_DEVICE_QUALIFICATION_V99_CLAIM_BOUNDARY,
    )
    body["result_hash"] = canonical_hash(body)
    body
end

function run_v99_reference_controls(project_root::AbstractString)
    anchors = load_candidate_solver_reference_anchors_v1(joinpath(project_root,
        "fixtures", "candidate_solver_reference_anchors_v1.json"))
    v98 = run_v98_reference_acceptance(project_root)
    length(anchors) == length(v98["reference_controls"]) ||
        throw(ArgumentError("reference control census mismatch"))
    rows = Dict{String,Any}[]
    for (anchor_raw, previous_raw) in zip(anchors, v98["reference_controls"])
        anchor = Dict{String,Any}(_v93_plain(anchor_raw))
        previous = Dict{String,Any}(_v93_plain(previous_raw))
        capability = _v98_reference_capability_profile(anchor)
        dag = compile_full_device_qualification_dag_v99(capability)
        route = String(capability["route"])
        desc_applicable = route == "axisymmetric_closed"
        required_class = desc_applicable ?
            "axisymmetric_free_boundary_plus_independent_fixed_boundary" :
            "open_field_extended_mhd_or_kinetic"
        expected = String(anchor["anchor_id"]) ==
            "iter_inductive_baseline_design_v1" ? desc_applicable :
            String(anchor["anchor_id"]) ==
            "c2w_enhanced_performance_experiment_v1" ? !desc_applicable : false
        push!(rows, Dict{String,Any}(
            "control_id" => anchor["anchor_id"],
            "reference_status" => previous["reference_status"],
            "capability_route" => route,
            "required_provider_class" => required_class,
            "freegs_desc_axisymmetric_bridge_applicable" => desc_applicable,
            "route_expectation_passed" => expected,
            "dag_hash" => dag["dag_hash"],
            "validation_credit" => false,
            "whole_device_candidate_credit" => false,
            "identity_fields_used_for_routing" => false,
            "claim_boundary" => anchor["claim_boundary"],
        ))
    end
    status = length(rows) == 2 && all(row -> row["reference_status"] == "pass" &&
        row["route_expectation_passed"] === true, rows) ? "pass" : "fail"
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "protocol_id" => V99_PROTOCOL_ID,
        "status" => status,
        "reference_control_count" => length(rows),
        "reference_controls" => rows,
        "validation_pass_count" => 0,
        "whole_device_credible_count" => 0,
        "identity_fields_used_for_routing" => false,
        "claim_boundary" => FULL_DEVICE_QUALIFICATION_V99_CLAIM_BOUNDARY,
    )
    body["acceptance_hash"] = canonical_hash(body)
    body
end
