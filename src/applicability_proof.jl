function validate_applicability_proof_v1(value)
    item = _plain_json(value)
    errors = String[]
    required = ["obligation_id", "predicate_id", "predicate_version", "evaluated_inputs",
        "evidence_refs", "result", "validity_domain", "uncertainty", "reproduction_trace"]
    for key in required
        haskey(item, key) || push!(errors, "ApplicabilityProof missing $key")
    end
    get(item, "result", nothing) isa Bool || push!(errors, "ApplicabilityProof result must be boolean")
    isempty(get(item, "evidence_refs", Any[])) && push!(errors, "ApplicabilityProof requires evidence refs")
    isempty(String(get(item, "reproduction_trace", ""))) && push!(errors, "ApplicabilityProof requires reproduction trace")
    return errors
end

function audit_not_applicable_v1(assessment, proof = nothing)
    item = _plain_json(assessment)
    status = String(get(item, "status", "unknown"))
    status == "not_applicable" || return Dict("status" => "not_required", "valid" => true, "errors" => Any[])
    proof === nothing && return Dict("status" => "unknown", "valid" => false,
        "errors" => Any["not_applicable requires ApplicabilityProof"])
    errors = validate_applicability_proof_v1(proof)
    return Dict("status" => isempty(errors) ? "not_applicable" : "unknown",
        "valid" => isempty(errors), "errors" => errors)
end

