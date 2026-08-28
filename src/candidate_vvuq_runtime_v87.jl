const _V87_VVUQ_CLAIM_BOUNDARY =
    "V87 binds numerical verification, sampled input uncertainty, independent cross-code " *
    "replication and calibrated measured validation to one candidate physics and exact-state " *
    "hash. Missing or malformed evidence remains unknown/unsupported. Engineering acceptance " *
    "is authorized only when all four records pass; no lower-fidelity result receives " *
    "retroactive feasibility credit."

function _v87_empty_record(kind, candidate_id, physics_hash, status, reasons)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "record_kind" => kind,
        "candidate_id" => String(candidate_id), "physics_hash" => String(physics_hash),
        "status" => String(status), "unresolved_reasons" => sort!(unique(reasons)),
        "evidence_ceiling" => "no promotion or engineering-acceptance credit")
    body["record_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

"Compile a three-or-more-mesh solution-verification record with explicit observables."
function compile_solution_verification_v87(raw, candidate_id, physics_hash,
        exact_state_hash = nothing)
    raw === nothing && return _v87_empty_record("solution_verification_v87",
        candidate_id, physics_hash, :unknown, ["missing numerical verification record"])
    record = _cie_v1_dict(raw); reasons = String[]
    String(get(record, "candidate_id", "")) == String(candidate_id) ||
        push!(reasons, "verification candidate_id mismatch")
    String(get(record, "physics_hash", "")) == String(physics_hash) ||
        push!(reasons, "verification physics_hash mismatch")
    exact_state_hash === nothing || String(get(record, "exact_state_hash", "")) ==
        String(exact_state_hash) || push!(reasons,
        "verification exact_state_hash mismatch")
    runs = Dict{String,Any}[_cie_v1_dict(item) for item in get(record, "runs", Any[])]
    length(runs) >= 3 || push!(reasons, "at least three executed mesh levels are required")
    required = sort!(unique(String.(get(record, "required_observables", String[]))))
    isempty(required) && push!(reasons, "required_observables is empty")
    maximum_residual = get(record, "maximum_finest_residual", nothing)
    maximum_residual isa Real && isfinite(Float64(maximum_residual)) &&
        Float64(maximum_residual) >= 0.0 || push!(reasons,
            "maximum_finest_residual must be finite and nonnegative")
    tolerances = _cie_v1_dict(get(record, "relative_change_tolerances", nothing))
    meshes = Int[]; result_hashes = String[]; input_hashes = String[]
    normalized_runs = Dict{String,Any}[]
    for (index, run) in enumerate(runs)
        mesh = get(run, "mesh_dof", nothing)
        mesh isa Integer && Int(mesh) > 0 || push!(reasons,
            "verification run $index lacks positive mesh_dof")
        mesh isa Integer && push!(meshes, Int(mesh))
        for key in ("solver_input_hash", "result_hash", "mesh_hash")
            _cie_v1_hash(get(run, key, nothing)) || push!(reasons,
                "verification run $index lacks valid $key")
        end
        push!(input_hashes, String(get(run, "solver_input_hash", "")))
        push!(result_hashes, String(get(run, "result_hash", "")))
        residual = get(run, "equation_residual", nothing)
        residual isa Real && isfinite(Float64(residual)) && Float64(residual) >= 0.0 ||
            push!(reasons, "verification run $index lacks a finite equation_residual")
        observables = _cie_v1_dict(get(run, "observables", nothing))
        for id in required
            value = get(observables, id, nothing)
            value isa Real && isfinite(Float64(value)) || push!(reasons,
                "verification run $index lacks finite observable $id")
        end
        push!(normalized_runs, run)
    end
    length(unique(meshes)) == length(meshes) || push!(reasons,
        "verification mesh_dof values are not unique")
    length(unique(result_hashes)) == length(result_hashes) || push!(reasons,
        "verification result hashes are not unique")
    length(unique(input_hashes)) == length(input_hashes) || push!(reasons,
        "verification solver input hashes are not unique")
    !isempty(reasons) && return _v87_empty_record("solution_verification_v87",
        candidate_id, physics_hash, :unsupported, reasons)
    order = sortperm(meshes)
    normalized_runs = normalized_runs[order]; meshes = meshes[order]
    changes = Dict{String,Any}[]; failed = false
    coarse = normalized_runs[end - 1]; fine = normalized_runs[end]
    for id in required
        tolerance = get(tolerances, id, nothing)
        tolerance isa Real && isfinite(Float64(tolerance)) && Float64(tolerance) >= 0.0 ||
            return _v87_empty_record("solution_verification_v87", candidate_id,
                physics_hash, :unsupported, ["missing valid relative tolerance for $id"])
        a = Float64(coarse["observables"][id]); b = Float64(fine["observables"][id])
        change = abs(b - a) / max(abs(a), abs(b), eps(Float64))
        passed = change <= Float64(tolerance); failed |= !passed
        push!(changes, Dict("observable_id" => id, "coarse_value" => a,
            "fine_value" => b, "relative_change" => change,
            "relative_tolerance" => Float64(tolerance),
            "status" => passed ? "pass" : "fail"))
    end
    finest_residual = Float64(fine["equation_residual"])
    residual_pass = finest_residual <= Float64(maximum_residual); failed |= !residual_pass
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "record_kind" => "solution_verification_v87",
        "candidate_id" => String(candidate_id), "physics_hash" => String(physics_hash),
        "exact_state_hash" => exact_state_hash === nothing ? nothing :
            String(exact_state_hash),
        "status" => failed ? "fail" : "pass", "runs" => normalized_runs,
        "required_observables" => required, "finest_pair_changes" => changes,
        "finest_equation_residual" => finest_residual,
        "maximum_finest_residual" => Float64(maximum_residual),
        "finest_residual_status" => residual_pass ? "pass" : "fail",
        "unresolved_reasons" => String[],
        "evidence_ceiling" => "mesh-convergence evidence for listed observables only")
    body["record_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

"Compile actual sampled input-uncertainty propagation; summaries alone receive no credit."
function compile_parametric_uq_v87(raw, candidate_id, physics_hash,
        exact_state_hash = nothing)
    raw === nothing && return _v87_empty_record("parametric_uq_v87", candidate_id,
        physics_hash, :unknown, ["missing sampled parametric uncertainty record"])
    record = _cie_v1_dict(raw); reasons = String[]
    String(get(record, "candidate_id", "")) == String(candidate_id) ||
        push!(reasons, "UQ candidate_id mismatch")
    String(get(record, "physics_hash", "")) == String(physics_hash) ||
        push!(reasons, "UQ physics_hash mismatch")
    exact_state_hash === nothing || String(get(record, "exact_state_hash", "")) ==
        String(exact_state_hash) || push!(reasons, "UQ exact_state_hash mismatch")
    for key in ("distribution_manifest_hash", "covariance_hash", "sampling_plan_hash")
        _cie_v1_hash(get(record, key, nothing)) || push!(reasons, "UQ lacks valid $key")
    end
    minimum_samples = Int(get(record, "minimum_sample_count", 8))
    minimum_samples >= 8 || push!(reasons, "minimum_sample_count must be at least 8")
    samples = Dict{String,Any}[_cie_v1_dict(item) for item in get(record, "samples", Any[])]
    length(samples) >= minimum_samples || push!(reasons,
        "UQ has fewer executed samples than minimum_sample_count")
    required = sort!(unique(String.(get(record, "required_observables", String[]))))
    isempty(required) && push!(reasons, "UQ required_observables is empty")
    input_hashes = String[]; result_hashes = String[]; weights = Float64[]
    failure_count = 0
    for (index, sample) in enumerate(samples)
        for key in ("physical_input_hash", "result_hash")
            _cie_v1_hash(get(sample, key, nothing)) || push!(reasons,
                "UQ sample $index lacks valid $key")
        end
        push!(input_hashes, String(get(sample, "physical_input_hash", "")))
        push!(result_hashes, String(get(sample, "result_hash", "")))
        weight = get(sample, "weight", nothing)
        weight isa Real && isfinite(Float64(weight)) && Float64(weight) > 0.0 ||
            push!(reasons, "UQ sample $index lacks positive finite weight")
        weight isa Real && push!(weights, Float64(weight))
        observables = _cie_v1_dict(get(sample, "observables", nothing))
        for id in required
            value = get(observables, id, nothing)
            value isa Real && isfinite(Float64(value)) || push!(reasons,
                "UQ sample $index lacks finite observable $id")
        end
        get(sample, "hard_gate_pass", false) === true || (failure_count += 1)
    end
    length(unique(input_hashes)) == length(input_hashes) || push!(reasons,
        "UQ physical inputs are not unique")
    length(unique(result_hashes)) == length(result_hashes) || push!(reasons,
        "UQ result hashes are not unique")
    isempty(weights) || isapprox(sum(weights), 1.0; atol = 1.0e-8, rtol = 1.0e-8) ||
        push!(reasons, "UQ sample weights do not sum to one")
    limit = get(record, "maximum_observed_failure_fraction", nothing)
    limit isa Real && isfinite(Float64(limit)) && 0.0 <= Float64(limit) <= 1.0 ||
        push!(reasons, "maximum_observed_failure_fraction must be within 0..1")
    !isempty(reasons) && return _v87_empty_record("parametric_uq_v87", candidate_id,
        physics_hash, :unsupported, reasons)
    fraction = failure_count / length(samples); passed = fraction <= Float64(limit)
    summaries = Dict{String,Any}[]
    for id in required
        values = Float64[Float64(sample["observables"][id]) for sample in samples]
        mean_value = sum(weight * value for (weight, value) in zip(weights, values))
        variance = sum(weight * (value - mean_value)^2 for
            (weight, value) in zip(weights, values))
        push!(summaries, Dict("observable_id" => id, "weighted_mean" => mean_value,
            "weighted_standard_deviation" => sqrt(max(variance, 0.0)),
            "minimum" => minimum(values), "maximum" => maximum(values)))
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "record_kind" => "parametric_uq_v87",
        "candidate_id" => String(candidate_id), "physics_hash" => String(physics_hash),
        "exact_state_hash" => exact_state_hash === nothing ? nothing :
            String(exact_state_hash),
        "status" => passed ? "pass" : "fail", "samples" => samples,
        "distribution_manifest_hash" => String(record["distribution_manifest_hash"]),
        "covariance_hash" => String(record["covariance_hash"]),
        "sampling_plan_hash" => String(record["sampling_plan_hash"]),
        "required_observables" => required, "observable_summaries" => summaries,
        "observed_failure_count" => failure_count,
        "observed_failure_fraction" => fraction,
        "maximum_observed_failure_fraction" => Float64(limit),
        "unresolved_reasons" => String[],
        "evidence_ceiling" => "propagated declared input distributions for listed observables only")
    body["record_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

"Fail-closed VVUQ decision and engineering-acceptance admission gate."
function compile_candidate_vvuq_decision_v87(candidate_id, physics_hash,
        exact_state_hash; solution_verification_record = nothing,
        parametric_uq_record = nothing, cross_code_record = nothing,
        experimental_anchor_record = nothing, pre_vvuq_hard_gate_record = nothing)
    _cie_v1_hash(exact_state_hash) || throw(ArgumentError(
        "exact_state_hash must be a lowercase SHA-256 digest"))
    verification = compile_solution_verification_v87(solution_verification_record,
        candidate_id, physics_hash, exact_state_hash)
    uq = compile_parametric_uq_v87(parametric_uq_record, candidate_id, physics_hash,
        exact_state_hash)
    for (name, record) in (("cross-code", cross_code_record),
            ("experimental-anchor", experimental_anchor_record))
        record === nothing && continue
        candidate_record = _cie_v1_dict(record)
        String(get(candidate_record, "exact_state_hash", "")) ==
            String(exact_state_hash) || throw(ArgumentError(
            "$name evidence exact_state_hash mismatch"))
    end
    cross = compile_cross_code_replication_envelope_v1(cross_code_record,
        candidate_id, physics_hash)
    anchor = compile_experimental_anchor_v1(experimental_anchor_record,
        candidate_id, physics_hash)
    hard_gate = if pre_vvuq_hard_gate_record === nothing
        nothing
    else
        record = _cie_v1_dict(pre_vvuq_hard_gate_record)
        gate_status = String(get(record, "status", "unknown"))
        gate_status in ("pass", "fail", "unknown", "unsupported") ||
            throw(ArgumentError("pre-VVUQ hard-gate status is invalid"))
        Dict{String,Any}(
            "gate_id" => String(get(record, "gate_id", "pre_vvuq_hard_physics")),
            "status" => gate_status,
            "classification_code" => get(record, "classification_code", nothing),
            "evidence_hash" => get(record, "evidence_hash", nothing),
            "claim_boundary" => get(record, "claim_boundary",
                "Pre-VVUQ hard-physics admission evidence only."))
    end
    numerical_statuses = String[verification["status"], uq["status"],
        String(cross.status)]
    hard_gate === nothing || push!(numerical_statuses, String(hard_gate["status"]))
    numerical_status = any(==("fail"), numerical_statuses) ? "fail" :
        all(==("pass"), numerical_statuses) ? "pass" :
        "unknown_numerical_evidence_required"
    statuses = vcat(numerical_statuses, String[String(anchor.status)])
    status = any(==("fail"), statuses) ? "fail" : all(==("pass"), statuses) ?
        "pass" : "unknown_external_or_numerical_evidence_required"
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "candidate_id" => String(candidate_id),
        "physics_hash" => String(physics_hash), "exact_state_hash" => String(exact_state_hash),
        "status" => status,
        "numerical_vvuq_status" => numerical_status,
        "validation_vvuq_status" => status,
        "screening_feedback_authorized" => numerical_status == "pass",
        "solution_verification" => verification,
        "parametric_uq" => uq,
        "cross_code_replication" => cross_code_replication_to_dict_v1(cross),
        "experimental_anchor" => experimental_anchor_to_dict_v1(anchor),
        "pre_vvuq_hard_physics_gate" => hard_gate,
        "engineering_acceptance_authorized" => status == "pass",
        "retroactive_feasibility_credit" => false,
        "claim_boundary" => _V87_VVUQ_CLAIM_BOUNDARY)
    body["result_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end
