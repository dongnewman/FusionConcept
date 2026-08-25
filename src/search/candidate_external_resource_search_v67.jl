const _V67_RUNTIME_CLAIM_BOUNDARY =
    "V67 derives external numerical, material-data and calibrated-experiment obligations " *
    "from each CandidateSolveManifestV1 capability graph. Providers match only through " *
    "requires/provides, outputs, spatial representation, region scope, time mode, validity, " *
    "artifact hashes, access state and independence group. Family and display labels are " *
    "non-routing fields. Resource readiness authorizes execution only, never validation."

function _v67_candidate_input_blockers(bundle)
    blockers = String[]
    capabilities = Set(String(item["capability_id"])
        for item in bundle["manifest"].capability_declarations)
    if "radiation_hydrodynamics" in capabilities
        rhd = bundle["pulsed_rhd_manifest"]
        append!(blockers, ["pulsed_rhd:$item" for item in
            String.(rhd["blocking_missing_inputs"])])
        append!(blockers, ["pulsed_rhd_conflict:$item" for item in
            String.(rhd["declaration_conflicts"])])
    end
    conflict = bundle["time_semantics_conflict_v1"]
    conflict isa AbstractDict && push!(blockers,
        "time_semantics:$(get(conflict, "conflict_code", "unsupported"))")
    return sort!(unique(blockers))
end

function compile_candidate_solver_judgment_input_v67(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        discretization_levels = [32, 64], evidence_records = Dict{String,Any}(),
        provider_manifests = default_external_evidence_provider_catalog_v1(),
        execute_native_routes::Bool = false, compile_problem_artifacts::Bool = false)
    bundle = compile_candidate_solver_judgment_input_v66(context, candidate_index;
        discretization_levels = discretization_levels,
        evidence_records = evidence_records,
        execute_native_routes = execute_native_routes,
        compile_problem_artifacts = compile_problem_artifacts)
    requirements = compile_external_resource_requirements_v1(bundle["manifest"];
        pulsed_rhd_manifest = bundle["pulsed_rhd_manifest"],
        candidate_input_blockers = _v67_candidate_input_blockers(bundle))
    resource_match = match_external_resources_v1(requirements, provider_manifests)
    requirement_dict = external_resource_requirements_to_dict_v1(requirements)
    match_dict = external_resource_match_to_dict_v1(resource_match)
    input = bundle["judgment_input"]
    requirement_artifact = _v57_runtime_artifact(
        "stage8_external_resource_requirements_v67", requirement_dict,
        String(requirements.status))
    match_artifact = _v57_runtime_artifact(
        "stage8_external_resource_match_v67", match_dict, String(resource_match.status))
    append!(input["stage_artifacts"], [requirement_artifact, match_artifact])
    for (id, artifact) in (("stage8_external_resource_requirements_v67",
            requirement_artifact), ("stage8_external_resource_match_v67", match_artifact))
        push!(input["evidence"], Dict("evidence_id" => id,
            "artifact_hash" => artifact["artifact_hash"],
            "evidence_class" => "candidate_bound_external_resource_readiness_or_explicit_gap"))
    end
    input["solver_runtime"]["external_resource_requirements"] = requirement_dict
    input["solver_runtime"]["external_resource_match"] = match_dict
    input["solver_runtime"]["execution_order"] = vcat(
        input["solver_runtime"]["execution_order"],
        ["capability_routed_external_resource_gate"])
    input["benchmark_scope"] = "v67_candidate_bound_external_resource_search"
    input["claim_boundary"] = _V67_RUNTIME_CLAIM_BOUNDARY
    input_hash = canonical_hash(input)
    bundle["input_hash"] = input_hash
    bundle["external_resource_requirements"] = requirement_dict
    bundle["external_resource_match"] = match_dict
    bundle["stage8_resource_execution_eligible_v67"] =
        resource_match.status == :ready_for_external_execution
    bundle["claim_boundary"] = _V67_RUNTIME_CLAIM_BOUNDARY
    bundle["artifact_summary"]["input_hash"] = input_hash
    bundle["artifact_summary"]["artifact_count"] =
        Int(bundle["artifact_summary"]["artifact_count"]) + 2
    return bundle
end

function evaluate_uniform_judgment_v67(value)
    result = evaluate_uniform_judgment_v66(value)
    result["chain_id"] = "uniform_fusion_judgment_chain_v67"
    result["claim_boundary"] = _V67_RUNTIME_CLAIM_BOUNDARY
    return result
end

function _v67_producer_gate(bundle, judgment)
    base = _v66_producer_gate(bundle, judgment)
    requirements = bundle["external_resource_requirements"]
    resource_match = bundle["external_resource_match"]
    requirement_status = String(requirements["status"])
    match_status = String(resource_match["status"])
    base["external_requirements_candidate_bound"] =
        requirements["candidate_id"] == bundle["manifest"].candidate_id &&
        requirements["physics_hash"] == bundle["manifest"].physics_hash &&
        requirements["solve_manifest_hash"] == bundle["manifest"].manifest_hash ?
        "pass" : "fail"
    base["external_requirements_classified"] = requirement_status in
        ("requirements_complete", "unknown_candidate_input_incomplete", "not_applicable") ?
        "pass" : "fail"
    base["external_provider_match_classified"] = match_status in
        ("ready_for_external_execution", "unknown_acquisition_required",
         "unknown_candidate_input_incomplete", "unsupported_provider_capability_gap",
         "not_applicable") ? "pass" : "fail"
    base["external_provider_match_hash_bound"] =
        resource_match["requirement_hash"] == requirements["requirement_hash"] ?
        "pass" : "fail"
    base["external_stage8_queue_requires_every_resource_ready"] =
        (bundle["stage8_resource_execution_eligible_v67"] ===
            (match_status == "ready_for_external_execution")) ? "pass" : "fail"
    base["external_resource_family_free_routing"] =
        resource_match["family_label_used"] === false &&
        all(item -> get(item, "family_label_used", true) === false,
            requirements["requirements"]) ? "pass" : "fail"
    return base
end

function evaluate_candidate_solver_representative_gate_v67(
        context::RecoverableCrossTopologyContextV20, candidate_indices;
        discretization_levels = [32, 64], evidence_records = Dict{String,Any}(),
        provider_manifests = default_external_evidence_provider_catalog_v1())
    indices = Int.(collect(candidate_indices))
    bundles = [compile_candidate_solver_judgment_input_v67(context, index;
        discretization_levels = discretization_levels,
        evidence_records = evidence_records, provider_manifests = provider_manifests)
        for index in indices]
    judgments = [evaluate_uniform_judgment_v67(bundle["judgment_input"])
        for bundle in bundles]
    gates = [_v67_producer_gate(bundle, judgment) for
        (bundle, judgment) in zip(bundles, judgments)]
    ids = sort!(collect(keys(first(gates))))
    histograms = Dict(id => Dict(status => count(item -> item[id] == status, gates)
        for status in ("pass", "fail") if any(item -> item[id] == status, gates))
        for id in ids)
    status_histogram = Dict(status => count(bundle ->
        bundle["external_resource_match"]["status"] == status, bundles)
        for status in ("ready_for_external_execution", "unknown_acquisition_required",
            "unknown_candidate_input_incomplete", "unsupported_provider_capability_gap",
            "not_applicable"))
    infrastructure_ready = !isempty(gates) &&
        all(item -> all(==("pass"), values(item)), gates)
    return Dict{String,Any}("candidate_indices" => indices, "bundles" => bundles,
        "judgments" => judgments, "producer_gates" => gates,
        "gate_histograms" => histograms,
        "external_resource_status_histogram" => status_histogram,
        "l1_full_search_authorized" => infrastructure_ready,
        "stage8_resource_ready_count" => status_histogram["ready_for_external_execution"],
        "claim_boundary" => _V67_RUNTIME_CLAIM_BOUNDARY)
end

function select_stage8_ready_queue_v67(gate; maximum_candidates::Integer = typemax(Int))
    records = Dict{String,Any}[]
    for (bundle, judgment) in zip(gate["bundles"], gate["judgments"])
        bundle["stage8_resource_execution_eligible_v67"] === true || continue
        stages = Dict(String(item["stage_id"]) => String(item["status"])
            for item in judgment["stages"])
        push!(records, Dict{String,Any}(
            "candidate_id" => bundle["manifest"].candidate_id,
            "physics_hash" => bundle["manifest"].physics_hash,
            "solve_manifest_hash" => bundle["manifest"].manifest_hash,
            "external_requirement_hash" =>
                bundle["external_resource_requirements"]["requirement_hash"],
            "provider_catalog_hash" =>
                bundle["external_resource_match"]["provider_catalog_hash"],
            "external_resource_match_hash" =>
                bundle["external_resource_match"]["match_hash"],
            "failed_stage_count" => count(==("fail"), values(stages)),
            "unknown_stage_count" => count(==("unknown"), values(stages)),
            "status" => "ready_for_capability_matched_external_stage8_execution",
            "family_label_used" => false))
    end
    sort!(records; by = item -> (Int(item["failed_stage_count"]),
        Int(item["unknown_stage_count"]), String(item["physics_hash"])))
    return records[1:min(Int(maximum_candidates), length(records))]
end
