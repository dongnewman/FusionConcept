const _V19_EXECUTION_CLAIM_BOUNDARY =
    "This layer proves deterministic sharding, atomic commit, cache reuse, retry, and resume equivalence only. It does not add physics fidelity, engineering closure, or promotion credit."

function _v19_json_normalize(value)
    # Generic JSON readers legitimately collapse values such as 0.0 to 0.
    # Hash exactly the representation that can be reconstructed after storage.
    return _plain_json(JSON3.read(canonical_json(value), Dict{String,Any}))
end

struct RecoverableRunSpecV19
    run_id::String
    kernel_id::String
    kernel_version::String
    total_candidates::Int
    shard_size::Int
    max_retries::Int
    max_retained_per_shard::Int
    kernel_config::Dict{String,Any}
    spec_hash::String
end

struct RecoverableShardSpecV19
    shard_id::Int
    first_index::Int
    last_index::Int
    input_hash::String
end

struct RecoverableKernelOutcomeV19
    record::Dict{String,Any}
    retain::Bool
end

struct RecoverableRunResultV19
    spec::RecoverableRunSpecV19
    run_directory::String
    cache_directory::String
    total_shards::Int
    completed_shards::Int
    new_commits::Int
    cache_hits::Int
    retry_failures::Int
    interrupted::Bool
    complete::Bool
    result_hash::Union{Nothing,String}
    manifest_hash::String
    claim_boundary::String
end

function RecoverableRunSpecV19(run_id::AbstractString, kernel_id::AbstractString,
        kernel_version::AbstractString, total_candidates::Integer,
        shard_size::Integer; max_retries::Integer = 2,
        max_retained_per_shard::Integer = 64,
        kernel_config::AbstractDict = Dict{String,Any}())
    total_candidates > 0 || throw(ArgumentError("total_candidates must be positive"))
    shard_size > 0 || throw(ArgumentError("shard_size must be positive"))
    max_retries >= 0 || throw(ArgumentError("max_retries must be non-negative"))
    max_retained_per_shard >= 0 || throw(ArgumentError(
        "max_retained_per_shard must be non-negative"))
    config = _v19_json_normalize(Dict{String,Any}(
        String(key) => _plain_json(value) for (key, value) in kernel_config))
    core = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "run_id" => String(run_id),
        "kernel_id" => String(kernel_id),
        "kernel_version" => String(kernel_version),
        "total_candidates" => Int(total_candidates),
        "shard_size" => Int(shard_size),
        "max_retries" => Int(max_retries),
        "max_retained_per_shard" => Int(max_retained_per_shard),
        "kernel_config" => config,
    )
    return RecoverableRunSpecV19(String(run_id), String(kernel_id),
        String(kernel_version), Int(total_candidates), Int(shard_size),
        Int(max_retries), Int(max_retained_per_shard), config,
        canonical_hash(core))
end

function recoverable_run_spec_to_dict_v19(spec::RecoverableRunSpecV19)
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "run_id" => spec.run_id,
        "kernel_id" => spec.kernel_id,
        "kernel_version" => spec.kernel_version,
        "total_candidates" => spec.total_candidates,
        "shard_size" => spec.shard_size,
        "max_retries" => spec.max_retries,
        "max_retained_per_shard" => spec.max_retained_per_shard,
        "kernel_config" => deepcopy(spec.kernel_config),
        "spec_hash" => spec.spec_hash,
    )
end

function deterministic_shards_v19(spec::RecoverableRunSpecV19)
    count = cld(spec.total_candidates, spec.shard_size)
    shards = RecoverableShardSpecV19[]
    for shard_id in 1:count
        first_index = (shard_id - 1) * spec.shard_size + 1
        last_index = min(shard_id * spec.shard_size, spec.total_candidates)
        input_hash = canonical_hash(Dict{String,Any}(
            "spec_hash" => spec.spec_hash,
            "shard_id" => shard_id,
            "first_index" => first_index,
            "last_index" => last_index,
        ))
        push!(shards, RecoverableShardSpecV19(shard_id, first_index,
            last_index, input_hash))
    end
    return shards
end

function _v19_atomic_write(path::AbstractString, text::AbstractString)
    directory = dirname(path)
    mkpath(directory)
    temporary_path, io = mktemp(directory)
    committed = false
    try
        write(io, text)
        flush(io)
        close(io)
        # Base.mv(force=true) removes an existing destination before rename.
        # Call libuv rename directly so same-directory replacement is one
        # filesystem operation and never falls back to copy-then-delete.
        error_code = ccall(:jl_fs_rename, Int32, (Cstring, Cstring),
            temporary_path, path)
        error_code < 0 && Base.uv_error("v19 atomic rename", error_code)
        committed = true
    finally
        isopen(io) && close(io)
        !committed && isfile(temporary_path) && rm(temporary_path; force = true)
    end
    return String(path)
end

_v19_atomic_write_json(path::AbstractString, value) =
    _v19_atomic_write(path, canonical_json(value) * "\n")

function _v19_read_json(path::AbstractString)
    return _plain_json(JSON3.read(read(path, String), Dict{String,Any}))
end

function _v19_state_path(run_directory::AbstractString, shard_id::Int)
    return joinpath(run_directory, "states", "shard_$(lpad(shard_id, 6, '0')).json")
end

function _v19_object_path(cache_directory::AbstractString, result_hash::String)
    return joinpath(cache_directory, "objects", result_hash[1:2], "$result_hash.json")
end

function _v19_commit_path(cache_directory::AbstractString, input_hash::String)
    return joinpath(cache_directory, "commits", input_hash[1:2], "$input_hash.json")
end

function _v19_state(run_directory::AbstractString, shard::RecoverableShardSpecV19)
    path = _v19_state_path(run_directory, shard.shard_id)
    isfile(path) || return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "shard_id" => shard.shard_id,
        "input_hash" => shard.input_hash,
        "attempt_count" => 0,
        "status" => "pending",
    )
    state = _v19_read_json(path)
    state["shard_id"] == shard.shard_id || throw(ArgumentError(
        "v19 state shard ID mismatch at $path"))
    state["input_hash"] == shard.input_hash || throw(ArgumentError(
        "v19 state input hash mismatch at $path"))
    return state
end

function _v19_write_state(run_directory::AbstractString,
        shard::RecoverableShardSpecV19, attempt_count::Int, status::String;
        result_hash::Union{Nothing,String} = nothing,
        error_message::Union{Nothing,String} = nothing)
    value = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "shard_id" => shard.shard_id,
        "input_hash" => shard.input_hash,
        "attempt_count" => attempt_count,
        "status" => status,
    )
    result_hash === nothing || (value["result_hash"] = result_hash)
    error_message === nothing || (value["error_message"] = error_message)
    return _v19_atomic_write_json(_v19_state_path(run_directory, shard.shard_id), value)
end

function _v19_normalize_outcome(value)
    if value isa RecoverableKernelOutcomeV19
        return value
    elseif value isa AbstractDict
        return RecoverableKernelOutcomeV19(Dict{String,Any}(
            String(key) => _plain_json(item) for (key, item) in value), false)
    end
    throw(ArgumentError("v19 kernel must return a dictionary or RecoverableKernelOutcomeV19"))
end

function _v19_evaluate_shard(spec::RecoverableRunSpecV19,
        shard::RecoverableShardSpecV19, kernel::Function)
    digest = SHA.SHA256_CTX()
    retained_records = Any[]
    first_sample = nothing
    last_sample = nothing
    for candidate_index in shard.first_index:shard.last_index
        outcome = _v19_normalize_outcome(kernel(candidate_index, spec.kernel_config))
        envelope = _v19_json_normalize(Dict{String,Any}(
            "candidate_index" => candidate_index,
            "record" => outcome.record,
        ))
        record_hash = canonical_hash(envelope)
        SHA.update!(digest, codeunits(record_hash))
        first_sample === nothing && (first_sample = envelope)
        last_sample = envelope
        if outcome.retain
            length(retained_records) < spec.max_retained_per_shard ||
                throw(ArgumentError("shard $(shard.shard_id) exceeded retained-record limit"))
            push!(retained_records, envelope)
        end
    end
    records_digest = bytes2hex(SHA.digest!(digest))
    core = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "spec_hash" => spec.spec_hash,
        "kernel_id" => spec.kernel_id,
        "kernel_version" => spec.kernel_version,
        "shard" => Dict{String,Any}(
            "shard_id" => shard.shard_id,
            "first_index" => shard.first_index,
            "last_index" => shard.last_index,
            "input_hash" => shard.input_hash,
        ),
        "candidate_count" => shard.last_index - shard.first_index + 1,
        "records_digest" => records_digest,
        "retained_count" => length(retained_records),
        "retained_records" => retained_records,
        "boundary_samples" => Any[first_sample, last_sample],
        "claim_boundary" => _V19_EXECUTION_CLAIM_BOUNDARY,
    )
    normalized_core = _v19_json_normalize(core)
    return normalized_core, canonical_hash(normalized_core)
end

function _v19_write_object(cache_directory::AbstractString,
        core::Dict{String,Any}, result_hash::String)
    path = _v19_object_path(cache_directory, result_hash)
    value = copy(core)
    value["result_hash"] = result_hash
    if isfile(path)
        existing = _v19_read_json(path)
        existing == value || throw(ArgumentError(
            "v19 content-addressed object collision at $path"))
        return path
    end
    return _v19_atomic_write_json(path, value)
end

function _v19_write_commit(cache_directory::AbstractString,
        shard::RecoverableShardSpecV19, result_hash::String)
    path = _v19_commit_path(cache_directory, shard.input_hash)
    value = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "shard_id" => shard.shard_id,
        "input_hash" => shard.input_hash,
        "result_hash" => result_hash,
    )
    if isfile(path)
        existing = _v19_read_json(path)
        existing == value || throw(ArgumentError(
            "v19 input-addressed commit collision at $path"))
        return path
    end
    return _v19_atomic_write_json(path, value)
end

function _v19_load_commit(cache_directory::AbstractString,
        shard::RecoverableShardSpecV19)
    commit_path = _v19_commit_path(cache_directory, shard.input_hash)
    isfile(commit_path) || return nothing
    commit = _v19_read_json(commit_path)
    commit["shard_id"] == shard.shard_id || throw(ArgumentError(
        "v19 commit shard ID mismatch at $commit_path"))
    commit["input_hash"] == shard.input_hash || throw(ArgumentError(
        "v19 commit input hash mismatch at $commit_path"))
    result_hash = String(commit["result_hash"])
    object_path = _v19_object_path(cache_directory, result_hash)
    isfile(object_path) || throw(ArgumentError(
        "v19 commit references missing object $object_path"))
    object = _v19_read_json(object_path)
    object["result_hash"] == result_hash || throw(ArgumentError(
        "v19 object result hash field mismatch at $object_path"))
    core = Dict{String,Any}(String(key) => value for (key, value) in object
        if key != "result_hash")
    canonical_hash(core) == result_hash || throw(ArgumentError(
        "v19 object content hash mismatch at $object_path"))
    return result_hash
end

function _v19_attempt_counts(run_directory::AbstractString,
        shards::Vector{RecoverableShardSpecV19})
    return Dict(string(shard.shard_id) => Int(_v19_state(run_directory,
        shard)["attempt_count"]) for shard in shards)
end

function _v19_manifest(spec::RecoverableRunSpecV19,
        shards::Vector{RecoverableShardSpecV19}, result_hashes::Dict{Int,String},
        run_directory::AbstractString, cache_directory::AbstractString)
    completed_ids = sort!(collect(keys(result_hashes)))
    complete = length(completed_ids) == length(shards)
    ordered_hashes = complete ? [result_hashes[shard.shard_id] for shard in shards] : String[]
    result_hash = complete ? canonical_hash(Dict{String,Any}(
        "spec_hash" => spec.spec_hash,
        "ordered_shard_result_hashes" => ordered_hashes,
    )) : nothing
    core = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "execution_version" => "recoverable_sharded_execution_v19",
        "spec" => recoverable_run_spec_to_dict_v19(spec),
        "run_directory" => abspath(run_directory),
        "cache_directory" => abspath(cache_directory),
        "total_shards" => length(shards),
        "completed_shard_ids" => completed_ids,
        "completed_shards" => length(completed_ids),
        "pending_shards" => length(shards) - length(completed_ids),
        "complete" => complete,
        "result_hash" => result_hash,
        "ordered_shard_result_hashes" => ordered_hashes,
        "attempt_counts" => _v19_attempt_counts(run_directory, shards),
        "claim_boundary" => _V19_EXECUTION_CLAIM_BOUNDARY,
    )
    normalized_core = _v19_json_normalize(core)
    manifest_hash = canonical_hash(normalized_core)
    value = copy(normalized_core)
    value["manifest_hash"] = manifest_hash
    return value
end

function _v19_write_manifest(spec::RecoverableRunSpecV19,
        shards::Vector{RecoverableShardSpecV19}, result_hashes::Dict{Int,String},
        run_directory::AbstractString, cache_directory::AbstractString)
    value = _v19_manifest(spec, shards, result_hashes, run_directory, cache_directory)
    _v19_atomic_write_json(joinpath(run_directory, "manifest.json"), value)
    return value
end

function recoverable_manifest_v19(run_directory::AbstractString)
    path = joinpath(run_directory, "manifest.json")
    isfile(path) || throw(ArgumentError("v19 manifest does not exist at $path"))
    value = _v19_read_json(path)
    manifest_hash = String(value["manifest_hash"])
    core = Dict{String,Any}(String(key) => item for (key, item) in value
        if key != "manifest_hash")
    canonical_hash(core) == manifest_hash || throw(ArgumentError(
        "v19 manifest hash mismatch at $path"))
    return value
end

function _v19_result(spec::RecoverableRunSpecV19, run_directory::String,
        cache_directory::String, shards::Vector{RecoverableShardSpecV19},
        manifest::Dict{String,Any}, new_commits::Int, cache_hits::Int,
        retry_failures::Int, interrupted::Bool)
    return RecoverableRunResultV19(spec, run_directory, cache_directory,
        length(shards), Int(manifest["completed_shards"]), new_commits,
        cache_hits, retry_failures, interrupted, Bool(manifest["complete"]),
        manifest["result_hash"] === nothing ? nothing : String(manifest["result_hash"]),
        String(manifest["manifest_hash"]), _V19_EXECUTION_CLAIM_BOUNDARY)
end

function run_recoverable_search_v19(spec::RecoverableRunSpecV19, kernel::Function;
        run_directory::AbstractString,
        cache_directory::AbstractString = joinpath(run_directory, "cache"),
        shard_ids::Union{Nothing,AbstractVector{<:Integer}} = nothing,
        stop_after_commits::Union{Nothing,Integer} = nothing,
        failure_injector::Function = (shard_id, attempt) -> false)
    stop_after_commits === nothing || stop_after_commits >= 0 ||
        throw(ArgumentError("stop_after_commits must be non-negative"))
    run_path = abspath(run_directory)
    cache_path = abspath(cache_directory)
    mkpath(run_path)
    mkpath(cache_path)
    shards = deterministic_shards_v19(spec)
    selected_ids = shard_ids === nothing ? collect(1:length(shards)) :
        sort!(unique(Int.(shard_ids)))
    all(id -> 1 <= id <= length(shards), selected_ids) ||
        throw(ArgumentError("shard_ids contains an out-of-range shard"))

    existing_manifest_path = joinpath(run_path, "manifest.json")
    if isfile(existing_manifest_path)
        existing = recoverable_manifest_v19(run_path)
        existing["spec"]["spec_hash"] == spec.spec_hash || throw(ArgumentError(
            "run directory already belongs to a different v19 spec"))
    end

    result_hashes = Dict{Int,String}()
    for shard in shards
        result_hash = _v19_load_commit(cache_path, shard)
        result_hash === nothing || (result_hashes[shard.shard_id] = result_hash)
    end
    manifest = _v19_write_manifest(spec, shards, result_hashes, run_path, cache_path)
    new_commits = 0
    cache_hits = 0
    retry_failures = 0
    if stop_after_commits === 0
        return _v19_result(spec, run_path, cache_path, shards, manifest,
            new_commits, cache_hits, retry_failures, true)
    end

    for shard_id in selected_ids
        shard = shards[shard_id]
        if haskey(result_hashes, shard_id)
            cache_hits += 1
            state = _v19_state(run_path, shard)
            _v19_write_state(run_path, shard, Int(state["attempt_count"]),
                "complete"; result_hash = result_hashes[shard_id])
            continue
        end
        state = _v19_state(run_path, shard)
        attempt = Int(state["attempt_count"])
        max_attempts = 1 + spec.max_retries
        committed = false
        while attempt < max_attempts && !committed
            attempt += 1
            _v19_write_state(run_path, shard, attempt, "running")
            try
                failure_injector(shard_id, attempt) && error(
                    "injected v19 failure for shard $shard_id attempt $attempt")
                core, result_hash = _v19_evaluate_shard(spec, shard, kernel)
                _v19_write_object(cache_path, core, result_hash)
                _v19_write_commit(cache_path, shard, result_hash)
                result_hashes[shard_id] = result_hash
                _v19_write_state(run_path, shard, attempt, "complete";
                    result_hash = result_hash)
                committed = true
                new_commits += 1
            catch exception
                exception isa InterruptException && rethrow()
                retry_failures += 1
                message = sprint(showerror, exception)
                _v19_write_state(run_path, shard, attempt, "failed";
                    error_message = message)
                attempt < max_attempts || rethrow()
            end
        end
        manifest = _v19_write_manifest(spec, shards, result_hashes,
            run_path, cache_path)
        if stop_after_commits !== nothing && new_commits >= stop_after_commits
            return _v19_result(spec, run_path, cache_path, shards, manifest,
                new_commits, cache_hits, retry_failures, true)
        end
    end
    manifest = _v19_write_manifest(spec, shards, result_hashes,
        run_path, cache_path)
    return _v19_result(spec, run_path, cache_path, shards, manifest,
        new_commits, cache_hits, retry_failures, false)
end

function recoverable_run_result_to_dict_v19(result::RecoverableRunResultV19)
    return Dict{String,Any}(
        "execution_version" => "recoverable_sharded_execution_v19",
        "spec" => recoverable_run_spec_to_dict_v19(result.spec),
        "run_directory" => result.run_directory,
        "cache_directory" => result.cache_directory,
        "total_shards" => result.total_shards,
        "completed_shards" => result.completed_shards,
        "new_commits" => result.new_commits,
        "cache_hits" => result.cache_hits,
        "retry_failures" => result.retry_failures,
        "interrupted" => result.interrupted,
        "complete" => result.complete,
        "result_hash" => result.result_hash,
        "manifest_hash" => result.manifest_hash,
        "claim_boundary" => result.claim_boundary,
    )
end
