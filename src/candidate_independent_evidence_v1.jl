const _CIE_V1_HASH_RE = r"^[0-9a-f]{64}$"

"Two independently produced numerical results bound to one candidate physics hash."
struct CrossCodeReplicationEnvelopeV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    status::Symbol
    code_runs::Vector{Dict{String,Any}}
    observable_comparisons::Vector{Dict{String,Any}}
    model_differences::Vector{Dict{String,Any}}
    unresolved_reasons::Vector{String}
    evidence_ceiling::String
    envelope_hash::String
end

"Measured experimental evidence with calibration and operating-history provenance."
struct ExperimentalAnchorV1
    schema_version::String
    anchor_id::String
    candidate_id::String
    physics_hash::String
    anchor_kind::String
    status::Symbol
    device_id::String
    campaign_id::String
    shot_or_condition_id::String
    provenance::Dict{String,Any}
    operating_history::Dict{String,Any}
    observable_comparisons::Vector{Dict{String,Any}}
    supported_claims::Vector{String}
    unresolved_reasons::Vector{String}
    evidence_ceiling::String
    anchor_hash::String
end

_cie_v1_hash(value) = value isa AbstractString && occursin(_CIE_V1_HASH_RE, String(value))
_cie_v1_dict(value) = value isa AbstractDict ?
    Dict{String,Any}(String(key) => item for (key, item) in value) : Dict{String,Any}()

function _cie_v1_cross_empty(candidate_id, physics_hash, status, reasons)
    body = Dict{String,Any}("schema_version" => "1.0.0", "candidate_id" => candidate_id,
        "physics_hash" => physics_hash, "status" => String(status), "code_runs" => Any[],
        "observable_comparisons" => Any[], "model_differences" => Any[],
        "unresolved_reasons" => sort!(unique(reasons)),
        "evidence_ceiling" => status == :unknown ?
            "no candidate-bound independent code replication supplied" :
            "malformed or non-independent cross-code evidence grants no credit")
    hash = canonical_hash(_csr_v1_json_safe(body))
    return CrossCodeReplicationEnvelopeV1("1.0.0", candidate_id, physics_hash, status,
        Dict{String,Any}[], Dict{String,Any}[], Dict{String,Any}[],
        body["unresolved_reasons"], body["evidence_ceiling"], hash)
end

function compile_cross_code_replication_envelope_v1(raw, candidate_id, physics_hash)
    raw === nothing && return _cie_v1_cross_empty(String(candidate_id), String(physics_hash),
        :unknown, ["missing CrossCodeReplicationEnvelopeV1 record"])
    record = _cie_v1_dict(raw)
    reasons = String[]
    String(get(record, "candidate_id", "")) == String(candidate_id) ||
        push!(reasons, "cross-code candidate_id mismatch")
    String(get(record, "physics_hash", "")) == String(physics_hash) ||
        push!(reasons, "cross-code physics_hash mismatch")
    runs = Dict{String,Any}[_cie_v1_dict(item) for item in get(record, "code_runs", Any[])]
    length(runs) >= 2 || push!(reasons, "at least two independently produced code runs are required")
    required_hashes = ("software_hash", "container_hash", "input_manifest_hash",
        "mesh_hash", "result_hash")
    run_ids = String[]; code_names = String[]; software_hashes = String[]
    container_hashes = String[]; mesh_hashes = String[]
    for (index, run) in enumerate(runs)
        id = String(get(run, "run_id", "")); isempty(id) && push!(reasons, "run $index lacks run_id")
        push!(run_ids, id)
        name = String(get(run, "code_name", "")); isempty(name) &&
            push!(reasons, "run $id lacks code_name")
        push!(code_names, name)
        isempty(String(get(run, "code_version", ""))) && push!(reasons, "run $id lacks code_version")
        for key in required_hashes
            _cie_v1_hash(get(run, key, nothing)) || push!(reasons, "run $id lacks valid $key")
        end
        push!(software_hashes, String(get(run, "software_hash", "")))
        push!(container_hashes, String(get(run, "container_hash", "")))
        push!(mesh_hashes, String(get(run, "mesh_hash", "")))
        String(get(run, "production_authority", "")) in ("independent_team", "independent_pipeline") ||
            push!(reasons, "run $id lacks independent production authority")
        String(get(run, "mesh_generation", "")) == "independently_generated" ||
            push!(reasons, "run $id mesh was not independently generated")
    end
    length(unique(run_ids)) == length(run_ids) || push!(reasons, "cross-code run_ids are not unique")
    length(unique(code_names)) >= 2 || push!(reasons, "cross-code evidence uses fewer than two codes")
    length(unique(software_hashes)) >= 2 || push!(reasons, "cross-code software hashes are not independent")
    length(unique(container_hashes)) >= 2 || push!(reasons, "cross-code container hashes are not independent")
    length(unique(mesh_hashes)) >= 2 || push!(reasons, "cross-code meshes are not independently distinct")
    manifests = unique(String(get(run, "input_manifest_hash", "")) for run in runs)
    length(manifests) == 1 || push!(reasons, "code runs do not share the same input manifest hash")
    comparisons = Dict{String,Any}[]
    failed = false
    for item in get(record, "observable_comparisons", Any[])
        comparison = _cie_v1_dict(item)
        id = String(get(comparison, "observable_id", ""))
        run_a = String(get(comparison, "run_a_id", "")); run_b = String(get(comparison, "run_b_id", ""))
        run_a in run_ids && run_b in run_ids && run_a != run_b ||
            push!(reasons, "comparison $id does not bind two declared runs")
        a = get(comparison, "value_a", nothing); b = get(comparison, "value_b", nothing)
        atol = get(comparison, "absolute_tolerance", nothing)
        rtol = get(comparison, "relative_tolerance", nothing)
        if !(a isa Real && b isa Real && atol isa Real && rtol isa Real &&
                isfinite(Float64(a)) && isfinite(Float64(b)) && Float64(atol) >= 0.0 &&
                Float64(rtol) >= 0.0 && !isempty(String(get(comparison, "unit", ""))))
            push!(reasons, "comparison $id lacks finite values, unit or tolerances")
            continue
        end
        difference = abs(Float64(a) - Float64(b))
        allowed = Float64(atol) + Float64(rtol) * max(abs(Float64(a)), abs(Float64(b)))
        status = difference <= allowed ? "pass" : "fail"
        failed |= status == "fail"
        comparison["absolute_difference"] = difference
        comparison["allowed_difference"] = allowed
        comparison["normalized_discrepancy"] = difference / max(allowed, eps(Float64))
        comparison["status"] = status
        comparison["comparison_hash"] = canonical_hash(_csr_v1_json_safe(comparison))
        push!(comparisons, comparison)
    end
    isempty(comparisons) && push!(reasons, "no common observable comparison was supplied")
    differences = Dict{String,Any}[_cie_v1_dict(item) for item in
        get(record, "model_differences", Any[])]
    isempty(differences) && push!(reasons, "model-form differences were not declared")
    !isempty(reasons) && return _cie_v1_cross_empty(String(candidate_id), String(physics_hash),
        :unsupported, reasons)
    status = failed ? :fail : :pass
    body = Dict{String,Any}("schema_version" => "1.0.0", "candidate_id" => candidate_id,
        "physics_hash" => physics_hash, "status" => String(status), "code_runs" => runs,
        "observable_comparisons" => comparisons, "model_differences" => differences,
        "unresolved_reasons" => String[],
        "evidence_ceiling" => "candidate-bound cross-code agreement for explicitly compared observables only")
    hash = canonical_hash(_csr_v1_json_safe(body))
    return CrossCodeReplicationEnvelopeV1("1.0.0", String(candidate_id), String(physics_hash),
        status, runs, comparisons, differences, String[], body["evidence_ceiling"], hash)
end

function _cie_v1_anchor_empty(anchor_id, candidate_id, physics_hash, kind, status, reasons)
    body = Dict{String,Any}("schema_version" => "1.0.0", "anchor_id" => anchor_id,
        "candidate_id" => candidate_id, "physics_hash" => physics_hash,
        "anchor_kind" => kind, "status" => String(status), "device_id" => "",
        "campaign_id" => "", "shot_or_condition_id" => "", "provenance" => Dict(),
        "operating_history" => Dict(), "observable_comparisons" => Any[],
        "supported_claims" => String[], "unresolved_reasons" => sort!(unique(reasons)),
        "evidence_ceiling" => kind == "published_design_reference" ?
            "design reference only; no experimental-validation credit" :
            "no complete candidate-bound calibrated experimental comparison")
    hash = canonical_hash(_csr_v1_json_safe(body))
    return ExperimentalAnchorV1("1.0.0", String(anchor_id), String(candidate_id),
        String(physics_hash), String(kind), status, "", "", "", Dict{String,Any}(),
        Dict{String,Any}(), Dict{String,Any}[], String[], body["unresolved_reasons"],
        body["evidence_ceiling"], hash)
end

function compile_experimental_anchor_v1(raw, candidate_id, physics_hash)
    raw === nothing && return _cie_v1_anchor_empty("", candidate_id, physics_hash, "missing",
        :unknown, ["missing ExperimentalAnchorV1 record"])
    record = _cie_v1_dict(raw)
    anchor_id = String(get(record, "anchor_id", ""))
    kind = String(get(record, "anchor_kind", ""))
    if kind == "published_design_reference"
        return _cie_v1_anchor_empty(anchor_id, candidate_id, physics_hash, kind, :unknown,
            ["published design reference is not a measured experimental anchor"])
    end
    reasons = String[]
    kind == "measured_experiment" || push!(reasons, "anchor_kind must be measured_experiment")
    String(get(record, "candidate_id", "")) == String(candidate_id) ||
        push!(reasons, "experimental anchor candidate_id mismatch")
    String(get(record, "physics_hash", "")) == String(physics_hash) ||
        push!(reasons, "experimental anchor physics_hash mismatch")
    isempty(anchor_id) && push!(reasons, "experimental anchor lacks anchor_id")
    device = String(get(record, "device_id", "")); isempty(device) && push!(reasons, "anchor lacks device_id")
    campaign = String(get(record, "campaign_id", "")); isempty(campaign) && push!(reasons, "anchor lacks campaign_id")
    shot = String(get(record, "shot_or_condition_id", "")); isempty(shot) &&
        push!(reasons, "anchor lacks shot_or_condition_id")
    provenance = _cie_v1_dict(get(record, "provenance", nothing))
    for key in ("raw_data_hash", "calibration_hash", "transfer_function_hash",
            "uncertainty_covariance_hash")
        _cie_v1_hash(get(provenance, key, nothing)) || push!(reasons, "anchor lacks valid $key")
    end
    history = _cie_v1_dict(get(record, "operating_history", nothing))
    for key in ("boundary_history_hash", "initial_state_hash", "control_history_hash")
        _cie_v1_hash(get(history, key, nothing)) || push!(reasons, "anchor lacks valid $key")
    end
    comparisons = Dict{String,Any}[]; failed = false
    for item in get(record, "observable_comparisons", Any[])
        comparison = _cie_v1_dict(item)
        id = String(get(comparison, "observable_id", ""))
        measured = get(comparison, "measured_value", nothing)
        predicted = get(comparison, "model_value", nothing)
        sigma = get(comparison, "combined_standard_uncertainty", nothing)
        tolerance = get(comparison, "acceptance_sigma", nothing)
        model_hash = get(comparison, "model_output_hash", nothing)
        if !(measured isa Real && predicted isa Real && sigma isa Real && tolerance isa Real &&
                isfinite(Float64(measured)) && isfinite(Float64(predicted)) &&
                Float64(sigma) > 0.0 && Float64(tolerance) > 0.0 &&
                !isempty(String(get(comparison, "unit", ""))) && _cie_v1_hash(model_hash))
            push!(reasons, "experimental comparison $id is incomplete")
            continue
        end
        bias = Float64(predicted) - Float64(measured)
        bias_sigma = bias / Float64(sigma)
        status = abs(bias_sigma) <= Float64(tolerance) ? "pass" : "fail"
        failed |= status == "fail"
        comparison["model_experiment_bias"] = bias
        comparison["normalized_bias_sigma"] = bias_sigma
        comparison["status"] = status
        comparison["comparison_hash"] = canonical_hash(_csr_v1_json_safe(comparison))
        push!(comparisons, comparison)
    end
    isempty(comparisons) && push!(reasons, "anchor has no calibrated observable comparison")
    claims = sort!(unique(String.(get(record, "supported_claims", String[]))))
    isempty(claims) && push!(reasons, "anchor does not declare its bounded supported claims")
    !isempty(reasons) && return _cie_v1_anchor_empty(anchor_id, candidate_id, physics_hash,
        kind, :unsupported, reasons)
    status = failed ? :fail : :pass
    body = Dict{String,Any}("schema_version" => "1.0.0", "anchor_id" => anchor_id,
        "candidate_id" => candidate_id, "physics_hash" => physics_hash,
        "anchor_kind" => kind, "status" => String(status), "device_id" => device,
        "campaign_id" => campaign, "shot_or_condition_id" => shot,
        "provenance" => provenance, "operating_history" => history,
        "observable_comparisons" => comparisons, "supported_claims" => claims,
        "unresolved_reasons" => String[],
        "evidence_ceiling" => "measured anchor supports only listed observables and claims")
    hash = canonical_hash(_csr_v1_json_safe(body))
    return ExperimentalAnchorV1("1.0.0", anchor_id, String(candidate_id), String(physics_hash),
        kind, status, device, campaign, shot, provenance, history, comparisons, claims,
        String[], body["evidence_ceiling"], hash)
end

function cross_code_replication_to_dict_v1(value::CrossCodeReplicationEnvelopeV1)
    return Dict{String,Any}("schema_version" => value.schema_version,
        "candidate_id" => value.candidate_id, "physics_hash" => value.physics_hash,
        "status" => String(value.status), "code_runs" => value.code_runs,
        "observable_comparisons" => value.observable_comparisons,
        "model_differences" => value.model_differences,
        "unresolved_reasons" => value.unresolved_reasons,
        "evidence_ceiling" => value.evidence_ceiling, "envelope_hash" => value.envelope_hash)
end

function experimental_anchor_to_dict_v1(value::ExperimentalAnchorV1)
    return Dict{String,Any}("schema_version" => value.schema_version,
        "anchor_id" => value.anchor_id, "candidate_id" => value.candidate_id,
        "physics_hash" => value.physics_hash, "anchor_kind" => value.anchor_kind,
        "status" => String(value.status), "device_id" => value.device_id,
        "campaign_id" => value.campaign_id, "shot_or_condition_id" => value.shot_or_condition_id,
        "provenance" => value.provenance, "operating_history" => value.operating_history,
        "observable_comparisons" => value.observable_comparisons,
        "supported_claims" => value.supported_claims,
        "unresolved_reasons" => value.unresolved_reasons,
        "evidence_ceiling" => value.evidence_ceiling, "anchor_hash" => value.anchor_hash)
end
