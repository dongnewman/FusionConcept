const MULTIREGION_EQUILIBRIUM_RUNTIME_V93_CLAIM_BOUNDARY =
    "Runtime outcomes preserve unsupported, numerical failure, branch ambiguity, disagreement, and validation unknown. Verification controls never grant candidate equilibrium credit."

struct MultiRegionEquilibriumResultV93
    schema_version::String
    protocol_id::String
    request_hash::String
    status::String
    first_blocker::Union{Nothing,String}
    solver_executed::Bool
    mesh_results::Vector{Dict{String,Any}}
    branch_audit::Dict{String,Any}
    residual_audit::Dict{String,Any}
    restart_replay::Dict{String,Any}
    resource_usage::Dict{String,Any}
    result_hash::String
end

function _v93_result(request, status, blocker; solver_executed = false,
        mesh_results = Dict{String,Any}[], branch_audit = Dict{String,Any}(),
        residual_audit = Dict{String,Any}(), restart_replay = Dict{String,Any}(),
        resource_usage = Dict{String,Any}())
    status in V93_RESULT_STATUSES || throw(ArgumentError("invalid v93 result status"))
    body = Dict{String,Any}("schema_version" => "1.0.0", "protocol_id" => V93_PROTOCOL_ID,
        "request_hash" => request.request_hash, "status" => status,
        "first_blocker" => blocker, "solver_executed" => solver_executed,
        "mesh_results" => mesh_results, "branch_audit" => branch_audit,
        "residual_audit" => residual_audit, "restart_replay" => restart_replay,
        "resource_usage" => resource_usage)
    hash = canonical_hash(body)
    MultiRegionEquilibriumResultV93("1.0.0", V93_PROTOCOL_ID, request.request_hash,
        status, blocker, solver_executed, mesh_results, branch_audit, residual_audit,
        restart_replay, resource_usage, hash)
end

function execute_multiregion_equilibrium_request_v93(request::MultiRegionEquilibriumRequestV93;
        backend_executor = nothing)
    request.compilation_status == "pass" || return _v93_result(request,
        request.compilation_status, request.first_blocker)
    backend_executor === nothing && return _v93_result(request,
        "unsupported_operator_or_backend", "selected_backend_has_no_attested_runtime_executor")
    started = time_ns(); allocated = @allocated raw = backend_executor(request)
    elapsed = (time_ns() - started) / 1e9
    result = Dict{String,Any}(_v93_plain(raw))
    status = String(get(result, "status", "fail_numerical_convergence"))
    status in V93_RESULT_STATUSES || (status = "fail_numerical_convergence")
    meshes = Dict{String,Any}.(get(result, "mesh_results", Any[]))
    branches = Dict{String,Any}(get(result, "branch_audit", Dict()))
    if get(branches, "different_decision_branches", false) === true
        status = "unknown_multiple_equilibrium_branches"
    end
    audit = Dict{String,Any}(get(result, "residual_audit", Dict()))
    get(audit, "final_monolithic_reaudit_pass", false) === true ||
        (status == "pass" && (status = "fail_numerical_convergence"))
    replay = Dict{String,Any}(get(result, "restart_replay", Dict()))
    get(replay, "pass", false) === true || (status == "pass" && (status = "fail_numerical_convergence"))
    blocker = status == "pass" ? nothing : String(get(result, "first_blocker", "runtime_hard_gate_not_passed"))
    _v93_result(request, status, blocker; solver_executed = true, mesh_results = meshes,
        branch_audit = branches, residual_audit = audit, restart_replay = replay,
        resource_usage = Dict("wall_seconds" => elapsed, "allocated_bytes" => allocated,
            "threads" => Threads.nthreads(), "processes" => 1))
end

function multiregion_equilibrium_result_to_dict_v93(result::MultiRegionEquilibriumResultV93)
    Dict{String,Any}("schema_version" => result.schema_version, "protocol_id" => result.protocol_id,
        "request_hash" => result.request_hash, "status" => result.status,
        "first_blocker" => result.first_blocker, "solver_executed" => result.solver_executed,
        "mesh_results" => result.mesh_results, "branch_audit" => result.branch_audit,
        "residual_audit" => result.residual_audit, "restart_replay" => result.restart_replay,
        "resource_usage" => result.resource_usage, "result_hash" => result.result_hash,
        "claim_boundary" => MULTIREGION_EQUILIBRIUM_RUNTIME_V93_CLAIM_BOUNDARY)
end
