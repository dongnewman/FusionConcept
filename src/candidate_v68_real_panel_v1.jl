const REAL_CANDIDATE_V68_ROUTES_V1 = Set(["closed_flux", "open_flux"])
const REAL_CANDIDATE_V68_CONTROL_ROLES_V1 = Set(["positive_control", "candidate",
    "negative_control"])
const REAL_CANDIDATE_V68_EVIDENCE_STATES_V1 = Set(["complete", "partial", "unknown",
    "unsupported", "fail", "not_applicable"])

"A hash-bound fixed-panel entry. Candidate names are metadata, not routing inputs."
struct RealCandidatePanelEntryV1
    panel_entry_id::String
    candidate_id::String
    candidate_binding_hash::String
    binding_hash_kind::String
    route::String
    control_role::String
    sources::Vector{Dict{String,Any}}
    evidence::Dict{String,String}
    hard_failures::Vector{Dict{String,Any}}
    evidence_ceiling::String
end

"Fail-closed compilation result for one real candidate's v68 residual obligations."
struct RealCandidatePanelCompilationV1
    schema_version::String
    panel_entry_id::String
    candidate_id::String
    candidate_binding_hash::String
    route::String
    control_role::String
    status::Symbol
    classification_code::String
    source_audits::Vector{Dict{String,Any}}
    obligation_audits::Vector{Dict{String,Any}}
    complete_obligations::Vector{String}
    incomplete_obligations::Vector{String}
    hard_failures::Vector{Dict{String,Any}}
    v68_execution_authorized::Bool
    complete_c2_result::Bool
    evidence_ceiling::String
    routing_projection_hash::String
    result_hash::String
end

function _v68_panel_entry_v1(raw)
    item = _csr_v1_plain_dict(raw)
    sources = Dict{String,Any}[_csr_v1_plain_dict(value) for value in item["sources"]]
    evidence = Dict{String,String}(String(key) => String(value)
        for (key, value) in get(item, "evidence", Dict{String,Any}()))
    failures = Dict{String,Any}[_csr_v1_plain_dict(value)
        for value in get(item, "hard_failures", Any[])]
    return RealCandidatePanelEntryV1(String(item["panel_entry_id"]),
        String(item["candidate_id"]), String(item["candidate_binding_hash"]),
        String(item["binding_hash_kind"]), String(item["route"]),
        String(item["control_role"]), sources, evidence, failures,
        String(item["evidence_ceiling"]))
end

function load_candidate_v68_real_panel_v1(path::AbstractString)
    raw = JSON3.read(read(path, String), Dict{String,Any})
    get(raw, "schema_version", nothing) == "1.0.0" || throw(ArgumentError(
        "unsupported candidate v68 real-panel schema"))
    get(raw, "panel_id", nothing) == "candidate_v68_real_panel_v1" ||
        throw(ArgumentError("unexpected candidate v68 real-panel id"))
    required = sort!(unique(String.(get(raw, "required_residual_obligations", Any[]))))
    isempty(required) && throw(ArgumentError("real panel has no residual obligations"))
    entries = RealCandidatePanelEntryV1[_v68_panel_entry_v1(item)
        for item in get(raw, "entries", Any[])]
    isempty(entries) && throw(ArgumentError("real panel has no entries"))
    length(unique(item.panel_entry_id for item in entries)) == length(entries) ||
        throw(ArgumentError("real panel entry ids must be unique"))
    for item in entries
        length(item.candidate_binding_hash) == 64 || throw(ArgumentError(
            "candidate binding hash must be sha256-sized: $(item.panel_entry_id)"))
        item.route in REAL_CANDIDATE_V68_ROUTES_V1 || throw(ArgumentError(
            "unsupported real-panel route: $(item.route)"))
        item.control_role in REAL_CANDIDATE_V68_CONTROL_ROLES_V1 ||
            throw(ArgumentError("unsupported real-panel control role: $(item.control_role)"))
        all(value -> value in REAL_CANDIDATE_V68_EVIDENCE_STATES_V1,
            values(item.evidence)) || throw(ArgumentError(
            "invalid real-panel evidence state: $(item.panel_entry_id)"))
        all(key -> key in required, keys(item.evidence)) || throw(ArgumentError(
            "entry declares an unknown residual obligation: $(item.panel_entry_id)"))
    end
    for route in REAL_CANDIDATE_V68_ROUTES_V1
        route_entries = filter(item -> item.route == route, entries)
        count(item -> item.control_role == "positive_control", route_entries) == 2 ||
            throw(ArgumentError("route $route must have exactly two positive controls"))
        count(item -> item.control_role == "candidate", route_entries) == 2 ||
            throw(ArgumentError("route $route must have exactly two candidates"))
        count(item -> item.control_role == "negative_control", route_entries) == 1 ||
            throw(ArgumentError("route $route must have exactly one negative control"))
    end
    return Dict{String,Any}("schema_version" => "1.0.0",
        "panel_id" => String(raw["panel_id"]), "required_obligations" => required,
        "claim_boundary" => String(raw["claim_boundary"]), "entries" => entries,
        "source_hash" => bytes2hex(sha256(read(path))))
end

function _v68_panel_source_audit_v1(root::AbstractString, source)
    relative = replace(String(source["path"]), '/' => Base.Filesystem.path_separator)
    path = normpath(joinpath(root, relative))
    expected = lowercase(String(source["sha256"]))
    exists = isfile(path)
    observed = exists ? bytes2hex(sha256(read(path))) : ""
    status = !exists ? "unsupported_missing_source_artifact" :
        observed == expected ? "pass" : "unsupported_source_hash_mismatch"
    return Dict{String,Any}("path" => String(source["path"]),
        "expected_sha256" => expected, "observed_sha256" => observed,
        "exists" => exists, "status" => status)
end

function _v68_panel_routing_projection_v1(entry::RealCandidatePanelEntryV1,
        source_audits, obligation_audits)
    return Dict{String,Any}("candidate_binding_hash" => entry.candidate_binding_hash,
        "binding_hash_kind" => entry.binding_hash_kind, "route" => entry.route,
        "sources" => [Dict("sha256" => item["observed_sha256"],
            "status" => item["status"]) for item in source_audits],
        "obligations" => [Dict("obligation" => item["obligation"],
            "evidence_state" => item["evidence_state"]) for item in obligation_audits],
        "hard_failures" => entry.hard_failures)
end

function real_candidate_panel_compilation_to_dict_v1(result::RealCandidatePanelCompilationV1)
    return Dict{String,Any}("schema_version" => result.schema_version,
        "panel_entry_id" => result.panel_entry_id, "candidate_id" => result.candidate_id,
        "candidate_binding_hash" => result.candidate_binding_hash, "route" => result.route,
        "control_role" => result.control_role, "status" => String(result.status),
        "classification_code" => result.classification_code,
        "source_audits" => result.source_audits,
        "obligation_audits" => result.obligation_audits,
        "complete_obligations" => result.complete_obligations,
        "incomplete_obligations" => result.incomplete_obligations,
        "hard_failures" => result.hard_failures,
        "v68_execution_authorized" => result.v68_execution_authorized,
        "complete_c2_result" => result.complete_c2_result,
        "evidence_ceiling" => result.evidence_ceiling,
        "routing_projection_hash" => result.routing_projection_hash,
        "result_hash" => result.result_hash)
end

function compile_real_candidate_panel_entry_v1(entry::RealCandidatePanelEntryV1,
        root::AbstractString, required_obligations)
    required = sort!(unique(String.(required_obligations)))
    source_audits = [_v68_panel_source_audit_v1(root, source) for source in entry.sources]
    obligation_audits = Dict{String,Any}[]
    complete = String[]
    incomplete = String[]
    for obligation in required
        state = get(entry.evidence, obligation, "unknown")
        state == "complete" ? push!(complete, obligation) : push!(incomplete, obligation)
        push!(obligation_audits, Dict("obligation" => obligation,
            "evidence_state" => state, "enters_same_v68_residual" => state == "complete"))
    end
    source_unsupported = any(item -> item["status"] != "pass", source_audits)
    evidence_unsupported = any(item -> item["evidence_state"] == "unsupported",
        obligation_audits)
    has_hard_failure = !isempty(entry.hard_failures)
    all_complete = isempty(incomplete)
    status, code = source_unsupported || evidence_unsupported ?
        (:unsupported, "unsupported_source_or_operator") :
        all_complete && has_hard_failure ?
        (:fail, "fail_complete_candidate_bound_residual") : all_complete ?
        (:unknown, "unknown_ready_for_v68_execution_not_yet_solved") :
        has_hard_failure ?
        (:unknown, "unknown_incomplete_inputs_with_narrow_failure") :
        (:unknown, "unknown_incomplete_real_candidate_residual_inputs")
    execution_authorized = !source_unsupported && !evidence_unsupported &&
        !has_hard_failure && all_complete
    complete_c2 = false
    projection = _v68_panel_routing_projection_v1(entry, source_audits, obligation_audits)
    routing_hash = canonical_hash(projection)
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "panel_entry_id" => entry.panel_entry_id, "candidate_id" => entry.candidate_id,
        "candidate_binding_hash" => entry.candidate_binding_hash, "route" => entry.route,
        "control_role" => entry.control_role, "status" => String(status),
        "classification_code" => code, "source_audits" => source_audits,
        "obligation_audits" => obligation_audits,
        "complete_obligations" => complete, "incomplete_obligations" => incomplete,
        "hard_failures" => entry.hard_failures,
        "v68_execution_authorized" => execution_authorized,
        "complete_c2_result" => complete_c2, "evidence_ceiling" => entry.evidence_ceiling,
        "routing_projection_hash" => routing_hash)
    result_hash = canonical_hash(body)
    return RealCandidatePanelCompilationV1("1.0.0", entry.panel_entry_id,
        entry.candidate_id, entry.candidate_binding_hash, entry.route, entry.control_role,
        status, code, source_audits, obligation_audits, complete, incomplete,
        deepcopy(entry.hard_failures), execution_authorized, complete_c2,
        entry.evidence_ceiling, routing_hash, result_hash)
end

function audit_candidate_v68_real_panel_v1(root::AbstractString,
        panel_path::AbstractString = joinpath(root, "fixtures", "candidate_v68_real_panel_v1.json"))
    panel = load_candidate_v68_real_panel_v1(panel_path)
    results = [compile_real_candidate_panel_entry_v1(entry, root,
        panel["required_obligations"]) for entry in panel["entries"]]
    result_dicts = real_candidate_panel_compilation_to_dict_v1.(results)
    route_summaries = Dict{String,Any}()
    for route in sort!(collect(REAL_CANDIDATE_V68_ROUTES_V1))
        records = filter(item -> item.route == route, results)
        route_summaries[route] = Dict{String,Any}(
            "entry_count" => length(records),
            "source_integrity_pass_count" => count(item ->
                all(record -> record["status"] == "pass", item.source_audits), records),
            "component_fail_count" => count(item -> item.status == :fail, records),
            "narrow_failure_count" => count(item -> !isempty(item.hard_failures), records),
            "unsupported_count" => count(item -> item.status == :unsupported, records),
            "unknown_count" => count(item -> item.status == :unknown, records),
            "v68_execution_authorized_count" => count(item ->
                item.v68_execution_authorized, records),
            "complete_c2_result_count" => count(item -> item.complete_c2_result, records))
    end
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "stage" => "candidate_v68_real_panel_v1", "panel_id" => panel["panel_id"],
        "panel_source_hash" => panel["source_hash"],
        "required_residual_obligations" => panel["required_obligations"],
        "entries" => result_dicts, "route_summaries" => route_summaries,
        "complete_c2_acceptance" => Dict("required_per_route" => 1,
            "closed_flux_observed" => route_summaries["closed_flux"]["complete_c2_result_count"],
            "open_flux_observed" => route_summaries["open_flux"]["complete_c2_result_count"],
            "passed" => all(route_summaries[route]["complete_c2_result_count"] >= 1
                for route in keys(route_summaries))),
        "routing_basis" => "candidate-bound hashes, declared capabilities, source integrity and residual obligations only",
        "claim_boundary" => panel["claim_boundary"])
    body["deterministic_hash"] = canonical_hash(body)
    return body
end
