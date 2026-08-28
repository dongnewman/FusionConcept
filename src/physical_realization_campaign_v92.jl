const PHYSICAL_REALIZATION_CAMPAIGN_V92_CLAIM_BOUNDARY =
    "The v92 realization campaign qualifies candidate-bound embedding, well-posedness, mesh specification, and complete gene/basis consumption for all 417 v91 survivors. It grants no equilibrium, confinement, stability, engineering, validation, or promotion credit."

_v92_sha256_text(value::AbstractString) = bytes2hex(SHA.sha256(codeunits(value)))

function _v92_write_immutable(path::AbstractString, content::AbstractString)
    mkpath(dirname(path))
    if isfile(path)
        existing = read(path, String)
        existing == content || throw(ArgumentError(
            "immutable v92 artifact already exists with different content: $(path)"))
        return "verified_existing"
    end
    temporary = "$(path).tmp-$(getpid())-$(time_ns())"
    open(temporary, "w") do io
        write(io, content)
        flush(io)
    end
    mv(temporary, path)
    return "written"
end

function _v92_json_text(value)
    io = IOBuffer()
    JSON3.pretty(io, value; allow_inf = false)
    write(io, '\n')
    return String(take!(io))
end

function _v92_jsonl_text(rows)
    io = IOBuffer()
    for row in rows
        JSON3.write(io, row; allow_inf = false)
        write(io, '\n')
    end
    return String(take!(io))
end

function _v92_read_nonempty_jsonl(path::AbstractString)
    rows = Dict{String,Any}[]
    open(path, "r") do io
        for (line_number, line) in enumerate(eachline(io))
            isempty(strip(line)) && continue
            try
                push!(rows, _v92_plain(JSON3.read(line)))
            catch error
                throw(ArgumentError("corrupt v92 JSONL $(path):$(line_number): " *
                    sprint(showerror, error)))
            end
        end
    end
    isempty(rows) && throw(ArgumentError("empty v92 shard rejected: $(path)"))
    return rows
end

function _v92_load_realization_inputs(project_root::AbstractString)
    source_relative = joinpath("runs",
        "multitopology_v91_formal_1000000_20260827",
        "survivor_dossiers_v91.jsonl")
    source_path = joinpath(project_root, source_relative)
    rows = NamedTuple[]
    open(source_path, "r") do io
        for (line_number, line) in enumerate(eachline(io))
            isempty(strip(line)) && continue
            dossier = _v92_plain(JSON3.read(line))
            push!(rows, (request_index = Int(dossier["request_index"]),
                candidate_id = String(dossier["candidate_id"]),
                candidate_hash = String(dossier["dossier_hash"]),
                source_line_number = line_number,
                source_line_sha256 = _v92_sha256_text(line),
                source_line = line,
                dossier = dossier))
        end
    end
    length(rows) == 417 || throw(ArgumentError(
        "v92 realization campaign requires 417 inputs, found $(length(rows))"))
    sort!(rows; by = item -> item.request_index)
    length(unique(item.request_index for item in rows)) == 417 ||
        throw(ArgumentError("duplicate v92 request_index"))
    length(unique(item.candidate_id for item in rows)) == 417 ||
        throw(ArgumentError("duplicate v92 candidate_id"))
    length(unique(item.candidate_hash for item in rows)) == 417 ||
        throw(ArgumentError("duplicate v92 candidate_hash"))
    return rows, source_relative
end

function _v92_request_row(item, source_relative, rank, shard_index)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "campaign_id" => "physical_closure_v92_formal_417_20260828",
        "stage_id" => "physical_realization",
        "rank" => rank, "shard_index" => shard_index,
        "request_index" => item.request_index,
        "candidate_id" => item.candidate_id,
        "candidate_hash" => item.candidate_hash,
        "source_path" => replace(source_relative, '\\' => '/'),
        "source_line_number" => item.source_line_number,
        "source_line_sha256" => item.source_line_sha256,
        "threshold_manifest_sha256" =>
            "5c6ca832d0693a341429fab44b1876196bd6fcde3153b3e78659656686679bd1",
        "capability_route_manifest_sha256" =>
            "5e202d5a09ed4436889a94860d0a53c01a65a918693e73045f913c84c9484312")
    body["request_hash"] = canonical_hash(body)
    return body
end

function _v92_result_row(item, request, realization, elapsed_seconds,
        allocated_bytes)
    body = physical_realization_to_dict_v92(realization)
    body["campaign_id"] = "physical_closure_v92_formal_417_20260828"
    body["stage_id"] = "physical_realization"
    body["rank"] = request["rank"]
    body["shard_index"] = request["shard_index"]
    body["request_index"] = request["request_index"]
    body["request_hash"] = request["request_hash"]
    body["source_line_sha256"] = item.source_line_sha256
    body["resource_usage"] = Dict{String,Any}(
        "wall_seconds" => elapsed_seconds,
        "allocated_bytes" => allocated_bytes,
        "threads" => Threads.nthreads(),
        "processes" => 1)
    body["result_replay_hash"] = canonical_hash(Dict(
        "protocol_id" => body["protocol_id"],
        "request_hash" => body["request_hash"],
        "realization_hash" => body["realization_hash"],
        "qualification" => body["qualification"]))
    return body
end

function _v92_capability_signature(result)
    obligations = result["applicability_obligations"]
    body = Dict{String,Any}(
        "declared_operators" => obligations["declared_operators"],
        "state_variables" => obligations["state_variables"],
        "region_dimensions" => obligations["region_dimensions"],
        "boundary_conditions" => obligations["boundary_conditions"],
        "interface_conditions" => obligations["interface_conditions"],
        "field_semantics" => obligations["field_semantics"],
        "evidence_obligations" => obligations["evidence_obligations"],
        "solver_input_compatibility" => obligations["solver_input_compatibility"])
    return canonical_hash(body), body
end

function _v92_declared_complexity(result)
    return length(result["regions"]) * 10 +
        length(result["oriented_surfaces"]) * 4 +
        length(result["field_sources"]) * 8 +
        length(result["profiles"]) * 3 +
        length(result["interface_conditions"]) * 2 +
        result["qualification"]["structural_gene_consumption_count"]
end

function _v92_select_pilot(results)
    eligible = [result for result in results if
        result["qualification"]["status"] == "pass"]
    groups = Dict{String,Vector{Dict{String,Any}}}()
    signatures = Dict{String,Dict{String,Any}}()
    for result in eligible
        signature_hash, signature = _v92_capability_signature(result)
        push!(get!(groups, signature_hash, Dict{String,Any}[]), result)
        signatures[signature_hash] = signature
    end
    selected = Dict{String,Any}[]
    for signature_hash in sort!(collect(keys(groups)))
        candidates = groups[signature_hash]
        sort!(candidates; by = item -> (_v92_declared_complexity(item),
            String(item["candidate_hash"])))
        winner = first(candidates)
        push!(selected, Dict{String,Any}(
            "capability_signature_hash" => signature_hash,
            "capability_signature" => signatures[signature_hash],
            "candidate_id" => winner["candidate_id"],
            "candidate_hash" => winner["candidate_hash"],
            "realization_hash" => winner["realization_hash"],
            "declared_complexity" => _v92_declared_complexity(winner),
            "tie_break" => "ascending_canonical_candidate_hash",
            "selected_before_high_fidelity_result" => true))
    end
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "campaign_id" => "physical_closure_v92_formal_417_20260828",
        "selection_rule" => "one minimum-declared-complexity candidate per observed capability signature; canonical candidate hash breaks ties",
        "realization_pass_count" => length(eligible),
        "observed_capability_signature_count" => length(groups),
        "selected_count" => length(selected), "selected" => selected,
        "high_fidelity_results_read_before_selection" => false,
        "claim_boundary" => "Pilot selection is preregistered coverage selection, not ranking evidence or feasibility credit.")
end

function _v92_realization_summary(results, replay_rows, pilot, total_seconds,
        total_allocated)
    status_histogram = Dict{String,Int}()
    blocker_histogram = Dict{String,Int}()
    for result in results
        status = String(result["qualification"]["status"])
        status_histogram[status] = get(status_histogram, status, 0) + 1
        blocker = result["qualification"]["first_blocker"]
        blocker === nothing || (blocker_histogram[String(blocker)] =
            get(blocker_histogram, String(blocker), 0) + 1)
    end
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "campaign_id" => "physical_closure_v92_formal_417_20260828",
        "stage_id" => "physical_realization",
        "input_count" => 417, "output_count" => length(results),
        "unique_candidate_id_count" => length(unique(String(result["candidate_id"])
            for result in results)),
        "unique_candidate_hash_count" => length(unique(String(result["candidate_hash"])
            for result in results)),
        "unique_realization_hash_count" => length(unique(String(result["realization_hash"])
            for result in results)),
        "shard_count" => 16, "empty_or_corrupt_shards" => 0,
        "status_histogram" => status_histogram,
        "first_blocker_histogram" => blocker_histogram,
        "deterministic_replay_count" => length(replay_rows),
        "deterministic_replay_pass_count" => count(row ->
            row["status"] == "pass", replay_rows),
        "pilot_selected_count" => pilot["selected_count"],
        "resource_usage" => Dict("wall_seconds" => total_seconds,
            "allocated_bytes" => total_allocated,
            "threads" => Threads.nthreads(), "processes" => 1),
        "computationally_credible_new_device_count" => 0,
        "experimentally_validated_new_fusion_device_count" => 0,
        "claim_boundary" => PHYSICAL_REALIZATION_CAMPAIGN_V92_CLAIM_BOUNDARY)
end

function run_physical_realization_campaign_v92(project_root::AbstractString)
    root = abspath(project_root)
    seal_audit = assert_protocol_sealed_v92(root)
    inputs, source_relative = _v92_load_realization_inputs(root)
    run_root = joinpath(root, "runs",
        "physical_closure_v92_formal_417_20260828")
    request_root = joinpath(run_root, "requests", "physical_realization")
    result_root = joinpath(run_root, "results", "physical_realization")
    checkpoint_root = joinpath(run_root, "checkpoints", "physical_realization")
    mkpath.(String[request_root, result_root, checkpoint_root])

    requests = Dict{String,Any}[]
    for (rank, item) in enumerate(inputs)
        shard_index = (rank - 1) % 16
        push!(requests, _v92_request_row(item, source_relative, rank,
            shard_index))
    end
    _v92_write_immutable(joinpath(request_root,
        "realization_requests_v92.jsonl"), _v92_jsonl_text(requests))

    all_results = Dict{String,Any}[]
    campaign_start = time_ns(); total_allocated = 0
    for shard_index in 0:15
        positions = findall(index -> requests[index]["shard_index"] ==
            shard_index, eachindex(requests))
        shard_path = joinpath(result_root,
            "realization_shard_$(lpad(shard_index, 2, '0'))_v92.jsonl")
        shard_results = Dict{String,Any}[]
        if isfile(shard_path)
            shard_results = _v92_read_nonempty_jsonl(shard_path)
            length(shard_results) == length(positions) || throw(ArgumentError(
                "v92 shard count mismatch during resume: $(shard_path)"))
        else
            for position in positions
                item = inputs[position]; request = requests[position]
                timed = @timed compile_physical_realization_v92(item.dossier)
                total_allocated += timed.bytes
                push!(shard_results, _v92_result_row(item, request,
                    timed.value, timed.time, timed.bytes))
            end
            _v92_write_immutable(shard_path, _v92_jsonl_text(shard_results))
        end
        checkpoint = Dict{String,Any}(
            "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
            "stage_id" => "physical_realization", "shard_index" => shard_index,
            "expected_count" => length(positions),
            "completed_count" => length(shard_results), "status" => "complete",
            "request_hashes" => [requests[position]["request_hash"] for
                position in positions],
            "result_replay_hashes" => [result["result_replay_hash"] for
                result in shard_results], "shard_sha256" =>
                _v92_sha256_file(shard_path))
        checkpoint["checkpoint_hash"] = canonical_hash(checkpoint)
        _v92_write_immutable(joinpath(checkpoint_root,
            "realization_shard_$(lpad(shard_index, 2, '0'))_checkpoint_v92.json"),
            _v92_json_text(checkpoint))
        append!(all_results, shard_results)
    end
    sort!(all_results; by = result -> Int(result["rank"]))
    length(all_results) == 417 || throw(ArgumentError(
        "v92 merged realization count must be 417"))
    [Int(result["request_index"]) for result in all_results] ==
        [item.request_index for item in inputs] || throw(ArgumentError(
        "v92 merged realization ordering or coverage mismatch"))

    replay_rows = Dict{String,Any}[]
    for (position, item) in enumerate(inputs)
        replay = compile_physical_realization_v92(item.dossier)
        expected = all_results[position]
        status = replay.realization_hash == expected["realization_hash"] &&
            replay.status == expected["qualification"]["status"] ? "pass" :
            "fail"
        push!(replay_rows, Dict{String,Any}(
            "request_index" => item.request_index,
            "candidate_id" => item.candidate_id,
            "expected_realization_hash" => expected["realization_hash"],
            "replayed_realization_hash" => replay.realization_hash,
            "status" => status))
    end
    all(row -> row["status"] == "pass", replay_rows) || throw(ArgumentError(
        "v92 deterministic realization replay failed"))
    pilot = _v92_select_pilot(all_results)
    elapsed = (time_ns() - campaign_start) / 1e9
    summary = _v92_realization_summary(all_results, replay_rows, pilot,
        elapsed, total_allocated)
    artifacts = Dict{String,String}(
        "dossiers" => joinpath(run_root, "realization_dossiers_v92.jsonl"),
        "replay" => joinpath(run_root, "realization_replay_v92.jsonl"),
        "pilot" => joinpath(run_root, "pilot_selection_v92.json"),
        "summary" => joinpath(run_root, "realization_summary_v92.json"))
    _v92_write_immutable(artifacts["dossiers"],
        _v92_jsonl_text(all_results))
    _v92_write_immutable(artifacts["replay"],
        _v92_jsonl_text(replay_rows))
    _v92_write_immutable(artifacts["pilot"], _v92_json_text(pilot))
    _v92_write_immutable(artifacts["summary"], _v92_json_text(summary))
    hash_manifest = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "seal_material_sha256" => seal_audit["seal_material_sha256"],
        "artifacts_sha256" => Dict(replace(relpath(path, root), '\\' => '/') =>
            _v92_sha256_file(path) for path in values(artifacts)))
    hash_manifest["artifact_manifest_hash"] = canonical_hash(hash_manifest)
    _v92_write_immutable(joinpath(run_root,
        "realization_artifact_hashes_v92.json"), _v92_json_text(hash_manifest))
    return summary
end
