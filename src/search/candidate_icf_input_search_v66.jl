const _V66_RUNTIME_CLAIM_BOUNDARY = _V66_ICF_CLAIM_BOUNDARY * " " *
    _V65_RUNTIME_CLAIM_BOUNDARY

function compile_candidate_solver_judgment_input_v66(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        discretization_levels = [32, 64], evidence_records = Dict{String,Any}(),
        execute_native_routes::Bool = false, compile_problem_artifacts::Bool = false)
    candidate = evaluate_icf_input_ready_candidate_v66(context, candidate_index)
    bundle = compile_candidate_solver_judgment_input_v65(context, candidate_index;
        discretization_levels = discretization_levels,
        evidence_records = evidence_records,
        execute_native_routes = execute_native_routes,
        compile_problem_artifacts = compile_problem_artifacts,
        candidate_record = candidate)
    input = bundle["judgment_input"]
    genome = candidate.prescreen.compiled.genome
    rhd = compile_pulsed_rhd_manifest_v1(genome, bundle["manifest"].candidate_id)
    artifact = _v57_runtime_artifact("pulsed_rhd_manifest_v66", rhd,
        String(rhd["status"]))
    push!(input["stage_artifacts"], artifact)
    push!(input["evidence"], Dict("evidence_id" => "pulsed_rhd_manifest_v66",
        "artifact_hash" => artifact["artifact_hash"],
        "evidence_class" => "candidate_bound_external_input_readiness_or_explicit_gap"))
    input["solver_runtime"]["pulsed_rhd_manifest"] = rhd
    input["solver_runtime"]["time_integration_contract_v2"] =
        get(genome.normalized, "time_integration_contract_v2", nothing)
    input["solver_runtime"]["time_semantics_conflict_v1"] =
        get(genome.normalized, "time_semantics_conflict_v1", nothing)
    input["solver_runtime"]["execution_order"] = vcat(
        input["solver_runtime"]["execution_order"], ["external_input_readiness_gate"])
    input["benchmark_scope"] = "v66_candidate_bound_icf_input_readiness_search"
    input["claim_boundary"] = _V66_RUNTIME_CLAIM_BOUNDARY
    input_hash = canonical_hash(input)
    bundle["input_hash"] = input_hash
    bundle["pulsed_rhd_manifest"] = rhd
    bundle["time_integration_contract_v2"] =
        get(genome.normalized, "time_integration_contract_v2", nothing)
    bundle["time_semantics_conflict_v1"] =
        get(genome.normalized, "time_semantics_conflict_v1", nothing)
    bundle["stage8_external_execution_eligible"] =
        String(rhd["status"]) == "ready_for_external_backend"
    bundle["claim_boundary"] = _V66_RUNTIME_CLAIM_BOUNDARY
    bundle["artifact_summary"]["input_hash"] = input_hash
    bundle["artifact_summary"]["artifact_count"] =
        Int(bundle["artifact_summary"]["artifact_count"]) + 1
    return bundle
end

function evaluate_uniform_judgment_v66(value)
    result = evaluate_uniform_judgment_v65(value)
    result["chain_id"] = "uniform_fusion_judgment_chain_v66"
    result["claim_boundary"] = _V66_RUNTIME_CLAIM_BOUNDARY
    return result
end

function _v66_producer_gate(bundle, judgment)
    base = _v65_producer_gate(bundle, judgment)
    rhd = bundle["pulsed_rhd_manifest"]
    status = String(rhd["status"])
    time = bundle["time_integration_contract_v2"]
    time_conflict = bundle["time_semantics_conflict_v1"]
    time_required = bundle["manifest"].time_mode == "pulsed"
    valid_time = time isa AbstractDict &&
        String(get(time, "schema_version", "")) == "2.0.0" &&
        get(time, "family_label_used", true) === false &&
        get(time, "contract_hash", "") == canonical_hash(Dict{String,Any}(
            String(key) => value for (key, value) in time if
                String(key) != "contract_hash"))
    explicit_time_conflict = time_conflict isa AbstractDict &&
        String(get(time_conflict, "status", "")) == "unsupported" &&
        get(time_conflict, "family_label_used", true) === false &&
        get(time_conflict, "conflict_hash", "") == canonical_hash(Dict{String,Any}(
            String(key) => value for (key, value) in time_conflict if
                String(key) != "conflict_hash"))
    time_ok = !time_required || valid_time || explicit_time_conflict
    rhd_ok = status in ("ready_for_external_backend", "unknown", "unsupported",
        "not_applicable")
    missing_is_explicit = status != "unknown" ||
        !isempty(rhd["blocking_missing_inputs"])
    unsupported_is_explicit = status != "unsupported" ||
        !isempty(rhd["declaration_conflicts"])
    base["time_semantics_v2_or_explicit_conflict"] = time_ok ? "pass" : "fail"
    base["pulsed_rhd_input_classified"] = rhd_ok ? "pass" : "fail"
    base["missing_microphysics_preserved_unknown"] = missing_is_explicit ? "pass" : "fail"
    base["malformed_time_or_input_preserved_unsupported"] =
        unsupported_is_explicit ? "pass" : "fail"
    base["stage8_queue_requires_input_ready"] =
        (bundle["stage8_external_execution_eligible"] ===
            (status == "ready_for_external_backend")) ? "pass" : "fail"
    base["family_free_time_and_icf_routing"] = "pass"
    return base
end

function evaluate_candidate_solver_representative_gate_v66(
        context::RecoverableCrossTopologyContextV20, candidate_indices;
        discretization_levels = [32, 64], evidence_records = Dict{String,Any}())
    indices = Int.(collect(candidate_indices))
    bundles = [compile_candidate_solver_judgment_input_v66(context, index;
        discretization_levels = discretization_levels,
        evidence_records = evidence_records) for index in indices]
    judgments = [evaluate_uniform_judgment_v66(bundle["judgment_input"])
        for bundle in bundles]
    gates = [_v66_producer_gate(bundle, judgment) for
        (bundle, judgment) in zip(bundles, judgments)]
    ids = sort!(collect(keys(first(gates))))
    histograms = Dict(id => Dict(status => count(item -> item[id] == status, gates)
        for status in ("pass", "fail") if any(item -> item[id] == status, gates))
        for id in ids)
    infrastructure_ready = !isempty(gates) &&
        all(item -> all(==("pass"), values(item)), gates)
    rhd_histogram = Dict(status => count(bundle ->
        bundle["pulsed_rhd_manifest"]["status"] == status, bundles)
        for status in ("ready_for_external_backend", "unknown", "unsupported",
            "not_applicable"))
    return Dict{String,Any}("candidate_indices" => indices, "bundles" => bundles,
        "judgments" => judgments, "producer_gates" => gates,
        "gate_histograms" => histograms,
        "pulsed_rhd_status_histogram" => rhd_histogram,
        "l1_full_search_authorized" => infrastructure_ready,
        "stage8_external_execution_ready_count" =>
            rhd_histogram["ready_for_external_backend"],
        "claim_boundary" => _V66_RUNTIME_CLAIM_BOUNDARY)
end

function select_stage8_ready_queue_v66(gate; maximum_candidates::Integer = 5)
    ready = Dict{String,Any}[]
    for (bundle, judgment) in zip(gate["bundles"], gate["judgments"])
        bundle["stage8_external_execution_eligible"] === true || continue
        stages = Dict(String(item["stage_id"]) => String(item["status"])
            for item in judgment["stages"])
        push!(ready, Dict{String,Any}(
            "candidate_id" => bundle["manifest"].candidate_id,
            "physics_hash" => bundle["manifest"].physics_hash,
            "pulsed_rhd_manifest_hash" =>
                bundle["pulsed_rhd_manifest"]["manifest_hash"],
            "failed_stage_count" => count(==("fail"), values(stages)),
            "unknown_stage_count" => count(==("unknown"), values(stages)),
            "status" => "ready_for_external_stage8_acquisition",
            "family_label_used" => false))
    end
    sort!(ready; by = item -> (Int(item["failed_stage_count"]),
        Int(item["unknown_stage_count"]), String(item["physics_hash"])))
    return ready[1:min(length(ready), Int(maximum_candidates))]
end
