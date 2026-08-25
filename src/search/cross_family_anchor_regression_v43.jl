const _V43_CLAIM_BOUNDARY =
    "V43 audits the twenty-three v42 observable routes against route-level primary " *
    "sources, sealed quantitative-evidence records, and three known-solution solver " *
    "artifacts. Experimental direction, family-level solver sanity, and candidate-specific " *
    "validation are separate axes. Passing a known-device control cannot validate an " *
    "unseen topology module, transfer a measured scalar to a searched operating point, " *
    "authorize medium fidelity, or establish C1, robustness, superiority, reactor closure, " *
    "or net electricity."

const _V43_OBSERVED_ACTIONS = Set([
    "reuse_existing_candidate_formula",
    "existing_observed_route_hold",
])

_v43_dict(raw) = Dict{String,Any}(String(key) => _plain_json(value)
    for (key, value) in raw)

function _v43_metric_map(artifact::AbstractDict)
    evaluation = get(artifact, "evaluation", Dict{String,Any}())
    metrics = get(evaluation, "metrics", Any[])
    return Dict(String(item["metric_id"]) => _v43_dict(item) for item in metrics)
end

function _v43_regression_record(control::Dict{String,Any},
        artifact::Dict{String,Any})
    metrics = _v43_metric_map(artifact)
    required_pass = sort!(String.(control["required_pass_metrics"]))
    required_unknown = sort!(String.(control["required_unknown_metrics"]))
    missing = sort!(String[id for id in vcat(required_pass, required_unknown)
        if !haskey(metrics, id)])
    bad_pass = sort!(String[id for id in required_pass if haskey(metrics, id) &&
        String(metrics[id]["status"]) != "pass"])
    bad_unknown = sort!(String[id for id in required_unknown if haskey(metrics, id) &&
        String(metrics[id]["status"]) != "unknown"])
    passed = isempty(missing) && isempty(bad_pass) && isempty(bad_unknown)
    return Dict{String,Any}(
        "control_id" => String(control["control_id"]),
        "family" => String(control["family"]),
        "artifact" => String(control["artifact"]),
        "scope" => String(control["scope"]),
        "required_pass_metrics" => required_pass,
        "required_unknown_metrics" => required_unknown,
        "missing_metric_ids" => missing,
        "wrong_pass_status_metric_ids" => bad_pass,
        "wrong_unknown_status_metric_ids" => bad_unknown,
        "positive_control_passed" => passed,
        "unknown_claim_guard_passed" => isempty(missing) && isempty(bad_unknown),
        "candidate_specific_module_validation" => false,
        "promotion_credit" => 0,
        "artifact_regression_version" => String(get(artifact,
            "regression_version", "unspecified")),
        "artifact_claim_boundary" => String(get(artifact,
            "claim_boundary", "unspecified")),
    )
end

function cross_family_anchor_regression_v43(v42_modules_raw::AbstractVector,
        evidence_entries_raw::AbstractVector, overlay_raw::AbstractDict,
        regression_artifacts_raw::AbstractDict)
    v42_modules = [_v43_dict(item) for item in v42_modules_raw]
    evidence_entries = [_v43_dict(item) for item in evidence_entries_raw]
    overlay = _v43_dict(overlay_raw)
    regression_artifacts = Dict{String,Dict{String,Any}}(String(key) =>
        _v43_dict(value) for (key, value) in regression_artifacts_raw)
    observed = sort!([item for item in v42_modules if String(
        item["recommended_action"]) in _V43_OBSERVED_ACTIONS]; by = item ->
        (String(item["family"]), String(item["module_id"])))
    length(observed) == 23 || throw(ArgumentError(
        "v43 requires the twenty-three sealed v42 observable routes"))
    bindings = [_v43_dict(item) for item in overlay["module_bindings"]]
    length(bindings) == 23 || throw(ArgumentError(
        "v43 requires one route-anchor binding per observable module"))
    binding_by_module = Dict(String(item["module_id"]) => item for item in bindings)
    Set(keys(binding_by_module)) == Set(String(item["module_id"]) for item in observed) ||
        throw(ArgumentError("v43 module bindings do not match v42 observable routes"))

    controls = [_v43_dict(item) for item in overlay["global_solver_controls"]]
    regression_records = Dict{String,Any}[]
    for control in sort!(controls; by = item -> String(item["control_id"]))
        control_id = String(control["control_id"])
        haskey(regression_artifacts, control_id) || throw(ArgumentError(
            "missing v43 solver-control artifact $control_id"))
        push!(regression_records, _v43_regression_record(control,
            regression_artifacts[control_id]))
    end
    target_solver_families = Set(String(item["family"]) for item in controls
        if String(item["scope"]) == "target_family_baseline_only")

    route_records = Dict{String,Any}[]
    for item in observed
        module_id = String(item["module_id"])
        family = String(item["family"])
        binding = binding_by_module[module_id]
        String(binding["family"]) == family || throw(ArgumentError(
            "v43 binding family mismatch for $module_id"))
        route_class = String(binding["route_anchor_class"])
        matched_evidence_ids = sort!(String.(item["quantitative_evidence"][
            "matched_record_ids"]))
        matched_evidence = [record for record in evidence_entries if String(
            record["id"]) in matched_evidence_ids]
        measured_ids = sort!(String[String(record["id"]) for record in
            matched_evidence if String(get(record, "evidence_provenance", "")) ==
                "measured"])
        missing_ids = sort!(String[String(record["id"]) for record in
            matched_evidence if String(get(record, "value_kind", "")) == "missing"])
        push!(route_records, Dict{String,Any}(
            "family" => family,
            "module_id" => module_id,
            "v42_recommended_action" => String(item["recommended_action"]),
            "v42_source_ids" => sort!(String.(item["source_ids"])),
            "route_anchor_class" => route_class,
            "anchor_source_ids" => sort!(String.(binding["anchor_source_ids"])),
            "route_repair" => String(get(binding, "route_repair", "none")),
            "route_issue" => String(get(binding, "route_issue", "none")),
            "v42_matched_quantitative_evidence_ids" => matched_evidence_ids,
            "v42_measured_evidence_ids" => measured_ids,
            "v42_missing_evidence_ids" => missing_ids,
            "family_solver_baseline_available" => family in target_solver_families,
            "route_level_experimental_direction_available" =>
                route_class == "experimental_directional_anchor",
            "candidate_specific_executable_validation_available" => false,
            "candidate_specific_promotion_evidence_available" => false,
            "unknown_or_nontransferability_guard_required" => true,
            "medium_fidelity_authorized" => false,
            "promotion_credit" => 0,
        ))
    end

    class_counts = Dict{String,Int}()
    for record in route_records
        route_class = String(record["route_anchor_class"])
        class_counts[route_class] = get(class_counts, route_class, 0) + 1
    end
    families = sort!(unique(String(item["family"]) for item in route_records))
    experimental_families = sort!(unique(String(item["family"]) for item in
        route_records if item["route_level_experimental_direction_available"] === true))
    family_summaries = Dict{String,Any}[]
    for family in families
        records = [item for item in route_records if item["family"] == family]
        push!(family_summaries, Dict{String,Any}(
            "family" => family,
            "route_count" => length(records),
            "experimental_direction_route_count" => count(item -> item[
                "route_level_experimental_direction_available"] === true, records),
            "source_only_route_count" => count(item -> item[
                "route_anchor_class"] == "source_only_no_directional_regression",
                records),
            "source_family_mismatch_route_count" => count(item -> item[
                "route_anchor_class"] == "source_family_mismatch", records),
            "family_solver_baseline_available" => family in target_solver_families,
            "candidate_specific_executable_route_count" => 0,
            "promotion_count" => 0,
        ))
    end

    aggregate = Dict{String,Any}(
        "observable_route_count" => length(route_records),
        "family_count" => length(families),
        "route_anchor_class_counts" => class_counts,
        "route_level_experimental_direction_count" => count(item -> item[
            "route_level_experimental_direction_available"] === true,
            route_records),
        "route_level_experimental_family_count" => length(experimental_families),
        "family_solver_baseline_route_count" => count(item -> item[
            "family_solver_baseline_available"] === true, route_records),
        "target_family_solver_baseline_count" => length(target_solver_families),
        "global_solver_control_count" => length(regression_records),
        "global_solver_control_pass_count" => count(item -> item[
            "positive_control_passed"] === true, regression_records),
        "unknown_claim_guard_pass_count" => count(item -> item[
            "unknown_claim_guard_passed"] === true, regression_records),
        "candidate_specific_executable_validation_count" => 0,
        "candidate_specific_promotion_evidence_count" => 0,
        "source_family_mismatch_count" => get(class_counts,
            "source_family_mismatch", 0),
        "medium_fidelity_authorized_count" => 0,
        "promotion_count" => 0,
        "old_domain_scale_up_authorized" => false,
    )
    aggregate["route_level_experimental_fraction"] =
        aggregate["route_level_experimental_direction_count"] /
        aggregate["observable_route_count"]
    aggregate["family_solver_baseline_fraction"] =
        aggregate["target_family_solver_baseline_count"] /
        aggregate["family_count"]

    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "search_version" => "cross_family_anchor_regression_v43",
        "stage" => "sealed_cross_family_known_device_anchor_regression",
        "anchor_contract" => Dict{String,Any}(
            "route_level_experiment_is_not_candidate_validation" => true,
            "family_solver_control_is_not_module_validation" => true,
            "source_only_route_receives_no_directional_credit" => true,
            "source_family_mismatch_is_blocking" => true,
            "unknown_metrics_must_remain_unknown" => true,
            "known_device_anchor_cannot_promote_unseen_candidate" => true,
        ),
        "aggregate" => aggregate,
        "family_summaries" => family_summaries,
        "route_records" => route_records,
        "regression_records" => regression_records,
        "highest_leverage_gaps" => [
            Dict("priority" => 1, "gap" =>
                "candidate-specific executable route validation", "open_routes" => 23),
            Dict("priority" => 2, "gap" =>
                "MTF chamber and replaceability route experiments/models", "open_routes" => 4),
            Dict("priority" => 3, "gap" =>
                "mirror end-loss, plug, GDT, and direct-conversion route regressions",
                "open_routes" => 4),
            Dict("priority" => 4, "gap" =>
                "supported-dipole cartridge source-family repair", "open_routes" => 1),
            Dict("priority" => 5, "gap" =>
                "stellarator QA/QH/QI drift route-specific regressions", "open_routes" => 3),
        ],
        "promotion_credit" => Dict{String,Any}(
            "physics_evidence_level_change" => 0,
            "engineering_evidence_level_change" => 0,
            "medium_fidelity_authorized_count" => 0,
            "promotion_count" => 0,
            "old_domain_scale_up_authorized" => false,
        ),
        "claim_boundary" => _V43_CLAIM_BOUNDARY,
    )
end
