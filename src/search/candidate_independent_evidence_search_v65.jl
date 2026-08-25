const _V65_RUNTIME_CLAIM_BOUNDARY =
    "V65 consumes sealed candidate-bound cross-code and measured-experiment records without " *
    "changing candidate physics or routing by family. Missing records remain unknown; malformed, " *
    "copied or mismatched records are unsupported. Agreement is observable-scoped and grants no " *
    "device-wide validation, originality, engineering qualification or promotion by itself."

function compile_candidate_independent_vvuq_v65(manifest::CandidateSolveManifestV1,
        regional::RegionSolveResultEnvelopeV1, stability, transport;
        cross_code_record = nothing, experimental_anchor_record = nothing)
    base = orchestrate_l1_vvuq_v1(manifest, regional, stability, transport)
    cross = compile_cross_code_replication_envelope_v1(cross_code_record,
        manifest.candidate_id, manifest.physics_hash)
    anchor = compile_experimental_anchor_v1(experimental_anchor_record,
        manifest.candidate_id, manifest.physics_hash)
    checks = deepcopy(base["checks"])
    function replace_check!(id, status, hash, basis, refs)
        for check in checks
            String(check["check_id"]) == id || continue
            empty!(check)
            check["check_id"] = id; check["status"] = status
            check["evidence_refs"] = refs; check["source_envelope_hash"] = hash
            status in ("unknown", "unsupported") && (check["unknown_basis"] = basis)
            return
        end
    end
    replace_check!("cross_code_replication", String(cross.status), cross.envelope_hash,
        join(cross.unresolved_reasons, "; "), ["CrossCodeReplicationEnvelopeV1"])
    replace_check!("experimental_anchor", String(anchor.status), anchor.anchor_hash,
        join(anchor.unresolved_reasons, "; "), ["ExperimentalAnchorV1"])
    model_status = cross.status == :pass ? "pass" : cross.status == :fail ? "fail" :
        String(cross.status)
    replace_check!("model_error", model_status, cross.envelope_hash,
        "independent model-form discrepancy is unavailable",
        ["CrossCodeReplicationEnvelopeV1:model_differences"])
    statuses = String[String(item["status"]) for item in checks]
    status = any(==("fail"), statuses) ? "fail" : all(==("pass"), statuses) ? "pass" :
        "unknown_external_evidence_required"
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => manifest.candidate_id, "physics_hash" => manifest.physics_hash,
        "state_result_hash" => regional.result_hash,
        "transport_result_hash" => String(transport["solver_output_hash"]),
        "checks" => checks, "status" => status,
        "cross_code_replication" => cross_code_replication_to_dict_v1(cross),
        "experimental_anchor" => experimental_anchor_to_dict_v1(anchor),
        "evidence_ceiling" => status == "pass" ?
            "V65 checks pass only for the compared observables and declared claims" :
            "internal L1 recomputation plus explicitly classified external-evidence gaps")
    body["result_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

function _v65_records_for_candidate(evidence_records, physics_hash)
    raw = evidence_records isa AbstractDict ? get(evidence_records, physics_hash, nothing) : nothing
    record = _cie_v1_dict(raw)
    return (cross = get(record, "cross_code_replication", nothing),
        anchor = get(record, "experimental_anchor", nothing))
end

function compile_candidate_solver_judgment_input_v65(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        discretization_levels = [32, 64], evidence_records = Dict{String,Any}(),
        execute_native_routes::Bool = false, compile_problem_artifacts::Bool = false,
        candidate_record = nothing)
    bundle = compile_candidate_solver_judgment_input_v64(context, candidate_index;
        discretization_levels = discretization_levels,
        execute_native_routes = execute_native_routes,
        compile_problem_artifacts = compile_problem_artifacts,
        candidate_record = candidate_record)
    input = bundle["judgment_input"]
    manifest = bundle["manifest"]
    evidence = _v65_records_for_candidate(evidence_records, manifest.physics_hash)
    vvuq = compile_candidate_independent_vvuq_v65(manifest,
        bundle["region_solve_result"], bundle["stability_result"],
        bundle["transport_result"]; cross_code_record = evidence.cross,
        experimental_anchor_record = evidence.anchor)
    input["uncertainty_evidence"] = Dict("checks" => deepcopy(vvuq["checks"]),
        "result_hash" => vvuq["result_hash"], "evidence_ceiling" => vvuq["evidence_ceiling"])
    artifact_specs = Any[("stage8_cross_code_replication_v65",
            vvuq["cross_code_replication"], vvuq["cross_code_replication"]["status"]),
        ("stage8_experimental_anchor_v65", vvuq["experimental_anchor"],
            vvuq["experimental_anchor"]["status"]),
        ("stage8_independent_vvuq_v65", vvuq, vvuq["status"])]
    artifacts = Dict{String,Any}[]
    for (id, details, status) in artifact_specs
        artifact = _v57_runtime_artifact(id, details, status)
        push!(artifacts, artifact)
        push!(input["evidence"], Dict("evidence_id" => id,
            "artifact_hash" => artifact["artifact_hash"],
            "evidence_class" => "candidate_bound_independent_evidence_or_explicit_gap"))
    end
    append!(input["stage_artifacts"], artifacts)
    input["solver_runtime"]["vvuq_result"] = vvuq
    input["solver_runtime"]["execution_order"] = vcat(
        input["solver_runtime"]["execution_order"], ["cross_code_replication",
            "experimental_comparison"])
    input["benchmark_scope"] = "v65_candidate_bound_independent_evidence_search"
    input["claim_boundary"] = _V65_RUNTIME_CLAIM_BOUNDARY
    input_hash = canonical_hash(input)
    bundle["input_hash"] = input_hash
    bundle["vvuq_result"] = vvuq
    bundle["cross_code_replication"] = vvuq["cross_code_replication"]
    bundle["experimental_anchor"] = vvuq["experimental_anchor"]
    bundle["claim_boundary"] = _V65_RUNTIME_CLAIM_BOUNDARY
    bundle["artifact_summary"]["input_hash"] = input_hash
    bundle["artifact_summary"]["artifact_count"] =
        Int(bundle["artifact_summary"]["artifact_count"]) + length(artifacts)
    return bundle
end

function evaluate_uniform_judgment_v65(value)
    result = evaluate_uniform_judgment_v62(value)
    result["chain_id"] = "uniform_fusion_judgment_chain_v65"
    result["claim_boundary"] = _V65_RUNTIME_CLAIM_BOUNDARY
    return result
end

function _v65_producer_gate(bundle, judgment)
    base = _v64_producer_gate(bundle, judgment)
    cross = bundle["cross_code_replication"]
    anchor = bundle["experimental_anchor"]
    cross_status = String(cross["status"])
    anchor_status = String(anchor["status"])
    base["cross_code_protocol_classified"] = cross_status in
        ("pass", "fail", "unknown", "unsupported") ? "pass" : "fail"
    base["experimental_anchor_protocol_classified"] = anchor_status in
        ("pass", "fail", "unknown", "unsupported") ? "pass" : "fail"
    base["missing_external_evidence_preserved_unknown"] =
        ((cross_status != "unknown" || !isempty(cross["unresolved_reasons"])) &&
         (anchor_status != "unknown" || !isempty(anchor["unresolved_reasons"]))) ? "pass" : "fail"
    base["family_free_external_evidence_binding"] = "pass"
    return base
end

function evaluate_candidate_solver_representative_gate_v65(
        context::RecoverableCrossTopologyContextV20, candidate_indices;
        discretization_levels = [32, 64], evidence_records = Dict{String,Any}())
    indices = Int.(collect(candidate_indices))
    bundles = [compile_candidate_solver_judgment_input_v65(context, index;
        discretization_levels = discretization_levels, evidence_records = evidence_records)
        for index in indices]
    judgments = [evaluate_uniform_judgment_v65(bundle["judgment_input"]) for bundle in bundles]
    gates = [_v65_producer_gate(bundle, judgment) for
        (bundle, judgment) in zip(bundles, judgments)]
    ids = sort!(collect(keys(first(gates))))
    histograms = Dict(id => Dict(status => count(item -> item[id] == status, gates)
        for status in ("pass", "fail") if any(item -> item[id] == status, gates)) for id in ids)
    infrastructure_ready = !isempty(gates) && all(item -> all(==("pass"), values(item)), gates)
    external_complete = count(bundle ->
        bundle["cross_code_replication"]["status"] in ("pass", "fail") &&
        bundle["experimental_anchor"]["status"] in ("pass", "fail"), bundles)
    return Dict{String,Any}("candidate_indices" => indices, "bundles" => bundles,
        "judgments" => judgments, "producer_gates" => gates,
        "gate_histograms" => histograms,
        "l1_full_search_authorized" => infrastructure_ready,
        "promotion_evidence_ready_count" => external_complete,
        "claim_boundary" => _V65_RUNTIME_CLAIM_BOUNDARY)
end

function select_independent_evidence_queue_v65(gate; maximum_candidates::Integer = 5)
    records = Dict{String,Any}[]
    for (bundle, judgment) in zip(gate["bundles"], gate["judgments"])
        stages = Dict(String(item["stage_id"]) => String(item["status"])
            for item in judgment["stages"])
        ledger = bundle["plant_power_ledger_result"]
        fail_count = count(==("fail"), values(stages))
        unknown_count = count(==("unknown"), values(stages))
        interval = ledger.closure["net_power_interval_w"]
        upper = get(interval, "upper", nothing)
        score = -100.0 * fail_count - 10.0 * unknown_count +
            (upper isa Real ? sign(Float64(upper)) : -1.0)
        push!(records, Dict("candidate_id" => bundle["manifest"].candidate_id,
            "physics_hash" => bundle["manifest"].physics_hash,
            "evidence_value_score" => score, "failed_stage_count" => fail_count,
            "unknown_stage_count" => unknown_count,
            "required_cross_code_obligations" => ["two independent codes and containers",
                "independent meshes", "same manifest", "common observable tolerances"],
            "required_experimental_obligations" => ["raw and calibration hashes",
                "transfer function and covariance", "boundary, initial and control histories"],
            "status" => "queued_external_work_not_completed",
            "family_label_used" => false))
    end
    sort!(records; by = item -> (-Float64(item["evidence_value_score"]),
        String(item["physics_hash"])))
    return records[1:min(Int(maximum_candidates), length(records))]
end
