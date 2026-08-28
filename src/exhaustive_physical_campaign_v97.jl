const V97_FORMAL_CAMPAIGN_ID = "v97_exhaustive_physical_rescreen_1048576_20260829"
const V97_FORMAL_SHARD_SIZE = 50_000

const EXHAUSTIVE_PHYSICAL_CAMPAIGN_V97_CLAIM_BOUNDARY =
    "The v97 campaign is an exhaustive, resume-safe execution over the complete declared " *
    "20-bit v91 grammar. Closure rows and high-cost rows remain separate funnel layers; " *
    "deduplication never promotes a representative result beyond identical graph and solver " *
    "inputs, and missing external validation remains unknown."

_v97_campaign_plain(value) = Dict{String,Any}(_v93_plain(value))

function _v97_json_write(path::AbstractString, value)
    mkpath(dirname(path))
    temporary = String(path) * ".tmp"
    open(temporary, "w") do io
        JSON3.pretty(io, value)
    end
    mv(temporary, path; force = true)
    path
end

function _v97_jsonl_write(path::AbstractString, rows)
    mkpath(dirname(path))
    temporary = String(path) * ".tmp"
    open(temporary, "w") do io
        for row in rows
            JSON3.write(io, row)
            write(io, '\n')
        end
    end
    mv(temporary, path; force = true)
    path
end

_v97_file_sha256(path) = bytes2hex(open(sha256, path))

function _v97_preservation_snapshot(project_root::AbstractString)
    relative = [
        "runs/multitopology_v91_formal_1000000_20260827/campaign_v91.json",
        "runs/multitopology_v91_formal_1000000_20260827/campaign_v91_merged.json",
        "runs/physical_closure_v92_formal_417_20260828/physical_closure_acceptance_v92_20260828.json",
        "runs/v93_pvw_slice1_formal_246_20260828/acceptance_v93_pvw_slice1.json",
        "runs/v94_generic_capability_acceptance/acceptance.json",
        "runs/v95_unified_filter_acceptance/acceptance.json",
        "runs/v96_provider_closure_acceptance/acceptance.json",
    ]
    Dict(item => _v97_file_sha256(joinpath(project_root, split(item, '/')...))
        for item in relative)
end

function compile_exhaustive_campaign_manifest_v97(project_root::AbstractString)
    sealed_root = joinpath(project_root, "runs",
        "multitopology_v91_formal_1000000_20260827")
    merged = JSON3.read(read(joinpath(sealed_root, "campaign_v91_merged.json"), String),
        Dict{String,Any})
    sealed_ranges = Dict{Int,Dict{String,Any}}(Int(item["shard_id"]) =>
        Dict{String,Any}(item) for item in merged["shard_ranges"])
    shards = Dict{String,Any}[]
    for shard_id in 1:20
        source = sealed_ranges[shard_id]
        push!(shards, Dict{String,Any}(
            "shard_id" => shard_id,
            "first_request_index" => Int(source["first_request_index"]),
            "last_request_index" => Int(source["last_request_index"]),
            "expected_count" => Int(source["last_request_index"]) -
                Int(source["first_request_index"]) + 1,
            "source_partition" => "sealed_v91_request_indices",
            "sealed_result_stream" => "results_shard_$(lpad(shard_id, 3, '0')).jsonl",
            "sealed_result_stream_sha256" => String(source["result_stream_sha256"]),
        ))
    end
    push!(shards, Dict{String,Any}(
        "shard_id" => 21,
        "first_request_index" => V97_SEALED_REQUEST_COUNT + 1,
        "last_request_index" => V97_MAXIMUM_REQUEST_INDEX,
        "expected_count" => V97_MAXIMUM_REQUEST_INDEX - V97_SEALED_REQUEST_COUNT,
        "source_partition" => "complete_20bit_grammar_tail",
        "sealed_result_stream" => nothing,
        "sealed_result_stream_sha256" => nothing,
    ))
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "protocol_id" => V97_PROTOCOL_ID,
        "campaign_id" => V97_FORMAL_CAMPAIGN_ID,
        "index_first" => 1,
        "index_last" => V97_MAXIMUM_REQUEST_INDEX,
        "total_request_count" => V97_MAXIMUM_REQUEST_INDEX,
        "sealed_request_count" => V97_SEALED_REQUEST_COUNT,
        "grammar_tail_count" => V97_MAXIMUM_REQUEST_INDEX - V97_SEALED_REQUEST_COUNT,
        "grammar_cardinality" => V97_MAXIMUM_REQUEST_INDEX,
        "grammar_exhaustive" => true,
        "closure_shards" => shards,
        "execution_order" => ["per_shard_manufactured_iter_c2w_sentinels",
            "deterministic_index_reconstruction", "v96_graph_compile",
            "field_dependency_closure", "provider_routing", "exact_input_dedup",
            "closed_unique_solve", "numerical_vvuq", "validation_vvuq"],
        "deduplication_key" => ["graph_hash", "solver_input_hash"],
        "historical_result_fields_allowed" => ["request_index"],
        "historical_gate_metric_consumed" => false,
        "closed_only_high_cost_execution" => true,
        "reference_controls" => ["manufactured_solution", "ITER", "C-2W"],
        "reference_failure_policy" => "fail_fast_before_each_shard",
        "sealed_artifact_snapshot" => _v97_preservation_snapshot(project_root),
        "claim_boundary" => EXHAUSTIVE_PHYSICAL_CAMPAIGN_V97_CLAIM_BOUNDARY,
    )
    body["campaign_hash"] = canonical_hash(body)
    body
end

function _v97_manifest_shard(manifest, shard_id::Integer)
    found = findfirst(item -> Int(item["shard_id"]) == Int(shard_id),
        manifest["closure_shards"])
    found === nothing && throw(ArgumentError("unknown v97 closure shard"))
    Dict{String,Any}(manifest["closure_shards"][found])
end

function _v97_sealed_indices(project_root, shard)
    shard_id = Int(shard["shard_id"])
    path = joinpath(project_root, "runs", "multitopology_v91_formal_1000000_20260827",
        String(shard["sealed_result_stream"]))
    observed_sha = _v97_file_sha256(path)
    observed_sha == String(shard["sealed_result_stream_sha256"]) || throw(ArgumentError(
        "sealed v91 result stream hash mismatch for shard $(shard_id)"))
    indices = Int[]
    open(path, "r") do io
        for line in eachline(io)
            matched = match(r"\"request_index\":([0-9]+)", line)
            matched === nothing && throw(ArgumentError(
                "sealed v91 row is missing request_index"))
            push!(indices, parse(Int, matched.captures[1]))
        end
    end
    expected = collect(Int(shard["first_request_index"]):Int(shard["last_request_index"]))
    indices == expected || throw(ArgumentError(
        "sealed v91 request indices have a gap, overlap, or ordering change"))
    indices, observed_sha
end

function _v97_shard_indices(project_root, shard)
    if String(shard["source_partition"]) == "sealed_v91_request_indices"
        return _v97_sealed_indices(project_root, shard)
    end
    indices = collect(Int(shard["first_request_index"]):Int(shard["last_request_index"]))
    indices, nothing
end

function _v97_histogram_increment!(histogram, key, amount::Integer = 1)
    value = String(key)
    histogram[value] = get(histogram, value, 0) + Int(amount)
    histogram
end

function _v97_closure_summary(rows)
    status = Dict{String,Int}(); blockers = Dict{String,Int}()
    routes = Dict{String,Int}(); topology_hashes = Set{String}()
    dedup_keys = Set{String}()
    for row in rows
        _v97_histogram_increment!(status, row["screen_status"])
        for blocker in row["blockers"]
            _v97_histogram_increment!(blockers, blocker)
        end
        for (key, count) in row["route_histogram"]
            _v97_histogram_increment!(routes, key, Int(count))
        end
        push!(topology_hashes, String(row["topology_hash"]))
        push!(dedup_keys, String(row["dedup_key"]))
    end
    Dict{String,Any}(
        "row_count" => length(rows),
        "status_histogram" => status,
        "blocker_histogram" => blockers,
        "route_histogram" => routes,
        "unique_topology_count" => length(topology_hashes),
        "unique_graph_solver_input_count" => length(dedup_keys),
    )
end

function run_v97_closure_shard(project_root::AbstractString, shard_id::Integer;
        output_dir = joinpath(project_root, "runs", V97_FORMAL_CAMPAIGN_ID),
        manifest = compile_exhaustive_campaign_manifest_v97(project_root),
        force::Bool = false)
    shard = _v97_manifest_shard(manifest, shard_id)
    summary_path = joinpath(output_dir,
        "closure_shard_$(lpad(Int(shard_id), 3, '0'))_summary.json")
    rows_path = joinpath(output_dir,
        "closure_shard_$(lpad(Int(shard_id), 3, '0')).jsonl")
    if !force && isfile(summary_path) && isfile(rows_path)
        existing = JSON3.read(read(summary_path, String), Dict{String,Any})
        if get(existing, "status", "") == "pass" &&
                get(existing, "output_sha256", "") == _v97_file_sha256(rows_path)
            return existing
        end
    end
    sentinels = run_v97_reference_sentinels(project_root)
    sentinels["status"] == "pass" || throw(ArgumentError(
        "v97 reference sentinel failed before closure shard $(shard_id)"))
    indices, sealed_sha = _v97_shard_indices(project_root, shard)
    length(indices) == Int(shard["expected_count"]) || throw(ArgumentError(
        "v97 closure shard request count mismatch"))
    registry = default_physical_provider_registry_v97()
    rows = Vector{Dict{String,Any}}(undef, length(indices))
    Threads.@threads for position in eachindex(indices)
        rows[position] = compile_indexed_closure_v97(indices[position]; registry).row
    end
    all(position -> Int(rows[position]["request_index"]) == indices[position],
        eachindex(indices)) || throw(ArgumentError("v97 threaded closure reordered rows"))
    _v97_jsonl_write(rows_path, rows)
    aggregate = _v97_closure_summary(rows)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "protocol_id" => V97_PROTOCOL_ID,
        "campaign_hash" => manifest["campaign_hash"],
        "shard_id" => Int(shard_id),
        "first_request_index" => first(indices),
        "last_request_index" => last(indices),
        "expected_count" => length(indices),
        "source_partition" => shard["source_partition"],
        "sealed_source_sha256" => sealed_sha,
        "sealed_source_hash_status" => sealed_sha === nothing || sealed_sha ==
            shard["sealed_result_stream_sha256"] ? "pass" : "fail",
        "sentinels" => sentinels,
        "funnel" => aggregate,
        "historical_result_fields_read" => ["request_index"],
        "historical_gate_metric_consumed" => false,
        "output_file" => basename(rows_path),
        "output_sha256" => _v97_file_sha256(rows_path),
        "status" => "pass",
        "claim_boundary" => EXHAUSTIVE_PHYSICAL_CAMPAIGN_V97_CLAIM_BOUNDARY,
    )
    body["summary_hash"] = canonical_hash(body)
    _v97_json_write(summary_path, body)
    body
end

function merge_v97_closure_shards(project_root::AbstractString;
        output_dir = joinpath(project_root, "runs", V97_FORMAL_CAMPAIGN_ID),
        manifest = JSON3.read(read(joinpath(output_dir, "campaign_manifest.json"), String),
            Dict{String,Any}))
    status = Dict{String,Int}(); blockers = Dict{String,Int}(); routes = Dict{String,Int}()
    topology_hashes = Set{String}(); all_dedup_keys = Set{String}()
    closed = Dict{String,Dict{String,Any}}()
    total = 0; previous_index = 0; shard_summaries = Dict{String,Any}[]
    for shard_raw in manifest["closure_shards"]
        shard = Dict{String,Any}(shard_raw); shard_id = Int(shard["shard_id"])
        summary_path = joinpath(output_dir,
            "closure_shard_$(lpad(shard_id, 3, '0'))_summary.json")
        rows_path = joinpath(output_dir, "closure_shard_$(lpad(shard_id, 3, '0')).jsonl")
        isfile(summary_path) && isfile(rows_path) || throw(ArgumentError(
            "v97 closure shard $(shard_id) is incomplete"))
        summary = JSON3.read(read(summary_path, String), Dict{String,Any})
        summary["status"] == "pass" && summary["sentinels"]["status"] == "pass" &&
            summary["sealed_source_hash_status"] == "pass" &&
            summary["output_sha256"] == _v97_file_sha256(rows_path) || throw(ArgumentError(
                "v97 closure shard $(shard_id) failed integrity verification"))
        push!(shard_summaries, Dict("shard_id" => shard_id,
            "summary_hash" => summary["summary_hash"],
            "sentinel_hash" => summary["sentinels"]["sentinel_hash"]))
        open(rows_path, "r") do io
            for line in eachline(io)
                row = JSON3.read(line, Dict{String,Any})
                index = Int(row["request_index"])
                index == previous_index + 1 || throw(ArgumentError(
                    "v97 merged closure indices are not contiguous"))
                previous_index = index; total += 1
                _v97_histogram_increment!(status, row["screen_status"])
                for blocker in row["blockers"]
                    _v97_histogram_increment!(blockers, blocker)
                end
                for (key, count) in row["route_histogram"]
                    _v97_histogram_increment!(routes, key, Int(count))
                end
                push!(topology_hashes, String(row["topology_hash"]))
                key = String(row["dedup_key"]); push!(all_dedup_keys, key)
                if row["screen_status"] == "closed"
                    if haskey(closed, key)
                        closed[key]["multiplicity"] += 1
                    else
                        closed[key] = Dict{String,Any}(
                            "dedup_key" => key,
                            "representative_request_index" => index,
                            "multiplicity" => 1,
                            "graph_hash" => String(row["graph_hash"]),
                            "solver_input_hash" => String(row["solver_input_hash"]),
                            "closure_row_hash" => String(row["row_hash"]),
                        )
                    end
                end
            end
        end
    end
    total == V97_MAXIMUM_REQUEST_INDEX && previous_index == V97_MAXIMUM_REQUEST_INDEX ||
        throw(ArgumentError("v97 closure merge did not cover the complete grammar"))
    length(topology_hashes) == V97_MAXIMUM_REQUEST_INDEX || throw(ArgumentError(
        "v97 topology reconstruction is not injective over the complete grammar"))
    representatives = sort!(collect(values(closed)); by = item ->
        Int(item["representative_request_index"]))
    representative_path = joinpath(output_dir, "unique_closed_inputs.jsonl")
    _v97_jsonl_write(representative_path, representatives)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "protocol_id" => V97_PROTOCOL_ID,
        "campaign_hash" => manifest["campaign_hash"],
        "status" => "pass",
        "processed" => total,
        "index_first" => 1,
        "index_last" => previous_index,
        "grammar_exhaustive" => true,
        "unique_nonisomorphic_topologies" => length(topology_hashes),
        "unique_graph_solver_inputs_all" => length(all_dedup_keys),
        "closure_status_histogram" => status,
        "blocker_histogram" => blockers,
        "route_histogram" => routes,
        "closed_row_count" => get(status, "closed", 0),
        "unique_closed_input_count" => length(representatives),
        "closed_deduplication_count" => get(status, "closed", 0) -
            length(representatives),
        "deduplication_key" => ["graph_hash", "solver_input_hash"],
        "unique_closed_input_file" => basename(representative_path),
        "unique_closed_input_sha256" => _v97_file_sha256(representative_path),
        "shard_summaries" => shard_summaries,
        "closure_shard_count" => length(shard_summaries),
        "sentinel_pass_shard_count" => length(shard_summaries),
        "historical_gate_metric_consumed" => false,
        "claim_boundary" => EXHAUSTIVE_PHYSICAL_CAMPAIGN_V97_CLAIM_BOUNDARY,
    )
    body["merge_hash"] = canonical_hash(body)
    _v97_json_write(joinpath(output_dir, "closure_merged.json"), body)
    body
end

function compile_v97_high_cost_manifest(project_root::AbstractString;
        output_dir = joinpath(project_root, "runs", V97_FORMAL_CAMPAIGN_ID),
        batch_size::Integer = 4096)
    merged = JSON3.read(read(joinpath(output_dir, "closure_merged.json"), String),
        Dict{String,Any})
    representatives_path = joinpath(output_dir, String(merged["unique_closed_input_file"]))
    merged["unique_closed_input_sha256"] == _v97_file_sha256(representatives_path) ||
        throw(ArgumentError("v97 unique closed input file hash mismatch"))
    count = Int(merged["unique_closed_input_count"]); size = Int(batch_size)
    size > 0 || throw(ArgumentError("v97 high-cost batch size must be positive"))
    shards = Dict{String,Any}[]
    first_row = 1; shard_id = 1
    while first_row <= count
        last_row = min(first_row + size - 1, count)
        push!(shards, Dict("shard_id" => shard_id, "first_representative_row" => first_row,
            "last_representative_row" => last_row, "expected_count" => last_row-first_row+1))
        first_row = last_row + 1; shard_id += 1
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V97_PROTOCOL_ID,
        "campaign_hash" => merged["campaign_hash"], "closure_merge_hash" => merged["merge_hash"],
        "unique_closed_input_count" => count, "batch_size" => size,
        "shards" => shards, "closed_only_high_cost_execution" => true,
        "strict_stage_order" => ["solve", "numerical_vvuq", "validation_vvuq"],
        "reference_failure_policy" => "fail_fast_before_each_shard",
        "claim_boundary" => EXHAUSTIVE_PHYSICAL_CAMPAIGN_V97_CLAIM_BOUNDARY)
    body["manifest_hash"] = canonical_hash(body)
    _v97_json_write(joinpath(output_dir, "high_cost_manifest.json"), body)
    body
end

function _v97_read_jsonl_range(path, first_row::Integer, last_row::Integer)
    rows = Dict{String,Any}[]
    for (line_number, line) in enumerate(eachline(path))
        line_number < first_row && continue
        line_number > last_row && break
        push!(rows, JSON3.read(line, Dict{String,Any}))
    end
    length(rows) == last_row - first_row + 1 || throw(ArgumentError(
        "v97 representative row range is incomplete"))
    rows
end

function run_v97_high_cost_shard(project_root::AbstractString, shard_id::Integer;
        output_dir = joinpath(project_root, "runs", V97_FORMAL_CAMPAIGN_ID),
        manifest = JSON3.read(read(joinpath(output_dir, "high_cost_manifest.json"), String),
            Dict{String,Any}), force::Bool = false)
    found = findfirst(item -> Int(item["shard_id"]) == Int(shard_id), manifest["shards"])
    found === nothing && throw(ArgumentError("unknown v97 high-cost shard"))
    shard = Dict{String,Any}(manifest["shards"][found])
    prefix = "high_cost_shard_$(lpad(Int(shard_id), 3, '0'))"
    rows_path = joinpath(output_dir, prefix * ".jsonl")
    summary_path = joinpath(output_dir, prefix * "_summary.json")
    if !force && isfile(rows_path) && isfile(summary_path)
        existing = JSON3.read(read(summary_path, String), Dict{String,Any})
        if existing["status"] == "pass" && existing["manifest_hash"] ==
                manifest["manifest_hash"] && existing["output_sha256"] ==
                _v97_file_sha256(rows_path)
            return existing
        end
    end
    sentinels = run_v97_reference_sentinels(project_root)
    sentinels["status"] == "pass" || throw(ArgumentError(
        "v97 reference sentinel failed before high-cost shard $(shard_id)"))
    representatives = _v97_read_jsonl_range(joinpath(output_dir,
        "unique_closed_inputs.jsonl"), Int(shard["first_representative_row"]),
        Int(shard["last_representative_row"]))
    registry = default_physical_provider_registry_v97()
    rows = Vector{Dict{String,Any}}(undef, length(representatives))
    Threads.@threads for position in eachindex(representatives)
        item = representatives[position]
        result = execute_unique_closed_v97(Int(item["representative_request_index"]),
            item["graph_hash"], item["solver_input_hash"]; registry)
        result["multiplicity"] = Int(item["multiplicity"])
        result["execution_hash"] = canonical_hash(result)
        rows[position] = result
    end
    all(row -> row["closure_status"] == "closed" && row["high_cost_executed"] === true,
        rows) || throw(ArgumentError("v97 high-cost execution escaped the closed-only gate"))
    _v97_jsonl_write(rows_path, rows)
    status = Dict{String,Int}(); expanded = Dict{String,Int}()
    for row in rows
        _v97_histogram_increment!(status, row["screen_status"])
        _v97_histogram_increment!(expanded, row["screen_status"], Int(row["multiplicity"]))
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V97_PROTOCOL_ID,
        "manifest_hash" => manifest["manifest_hash"], "shard_id" => Int(shard_id),
        "representative_count" => length(rows), "expected_count" => shard["expected_count"],
        "unique_status_histogram" => status, "expanded_status_histogram" => expanded,
        "sentinels" => sentinels, "closed_only_gate" => "pass",
        "output_file" => basename(rows_path), "output_sha256" => _v97_file_sha256(rows_path),
        "status" => "pass", "claim_boundary" => EXHAUSTIVE_PHYSICAL_CAMPAIGN_V97_CLAIM_BOUNDARY)
    body["summary_hash"] = canonical_hash(body)
    _v97_json_write(summary_path, body)
    body
end

function merge_v97_high_cost_shards(project_root::AbstractString;
        output_dir = joinpath(project_root, "runs", V97_FORMAL_CAMPAIGN_ID))
    manifest = JSON3.read(read(joinpath(output_dir, "high_cost_manifest.json"), String),
        Dict{String,Any})
    unique_status = Dict{String,Int}(); expanded_status = Dict{String,Int}()
    blocker_status = Dict{String,Int}(); total = 0; expanded = 0; sentinel_pass = 0
    representative_path = joinpath(output_dir, "unique_closed_inputs.jsonl")
    representative_sha = _v97_file_sha256(representative_path)
    representatives = Iterators.Stateful(eachline(representative_path))
    survivor_path = joinpath(output_dir, "new_survivors.jsonl")
    temporary = survivor_path * ".tmp"
    open(temporary, "w") do output
        for shard_raw in manifest["shards"]
            shard = Dict{String,Any}(shard_raw); shard_id = Int(shard["shard_id"])
            prefix = "high_cost_shard_$(lpad(shard_id, 3, '0'))"
            summary_path = joinpath(output_dir, prefix * "_summary.json")
            rows_path = joinpath(output_dir, prefix * ".jsonl")
            isfile(summary_path) && isfile(rows_path) || throw(ArgumentError(
                "v97 high-cost shard $(shard_id) is incomplete"))
            summary = JSON3.read(read(summary_path, String), Dict{String,Any})
            summary["status"] == "pass" && summary["sentinels"]["status"] == "pass" &&
                summary["closed_only_gate"] == "pass" && summary["output_sha256"] ==
                _v97_file_sha256(rows_path) || throw(ArgumentError(
                    "v97 high-cost shard $(shard_id) failed integrity verification"))
            sentinel_pass += 1
            open(rows_path, "r") do io
                for line in eachline(io)
                    row = JSON3.read(line, Dict{String,Any}); total += 1
                    isempty(representatives) && throw(ArgumentError(
                        "v97 high-cost results exceed the closed representative inventory"))
                    representative = JSON3.read(popfirst!(representatives), Dict{String,Any})
                    Int(row["request_index"]) ==
                        Int(representative["representative_request_index"]) &&
                        row["graph_hash"] == representative["graph_hash"] &&
                        row["solver_input_hash"] == representative["solver_input_hash"] &&
                        row["dedup_key"] == representative["dedup_key"] &&
                        Int(row["multiplicity"]) == Int(representative["multiplicity"]) ||
                        throw(ArgumentError(
                            "v97 high-cost result does not match its exact closed input"))
                    multiplicity = Int(row["multiplicity"]); expanded += multiplicity
                    _v97_histogram_increment!(unique_status, row["screen_status"])
                    _v97_histogram_increment!(expanded_status, row["screen_status"], multiplicity)
                    if row["screen_status"] in ("physical_fail", "numerical_fail", "unsupported")
                        _v97_histogram_increment!(blocker_status, row["screen_status"], multiplicity)
                    else
                        JSON3.write(output, row); write(output, '\n')
                    end
                end
            end
        end
    end
    mv(temporary, survivor_path; force = true)
    isempty(representatives) || throw(ArgumentError(
        "v97 high-cost results do not exhaust the closed representative inventory"))
    total == Int(manifest["unique_closed_input_count"]) || throw(ArgumentError(
        "v97 high-cost merge count does not match unique closed inputs"))
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V97_PROTOCOL_ID,
        "manifest_hash" => manifest["manifest_hash"], "status" => "pass",
        "unique_closed_executed" => total, "expanded_closed_rows" => expanded,
        "unique_status_histogram" => unique_status,
        "expanded_status_histogram" => expanded_status,
        "blocking_outcome_histogram" => blocker_status,
        "closure_unique_input_sha256" => representative_sha,
        "representative_match_count" => total,
        "high_cost_shard_count" => length(manifest["shards"]),
        "sentinel_pass_shard_count" => sentinel_pass,
        "new_survivor_count" => get(unique_status, "unknown", 0) +
            get(unique_status, "closed", 0),
        "survivor_definition" =>
            "unique closed input with solve and numerical VVUQ completed; validation may remain unknown",
        "survivor_file" => basename(survivor_path),
        "survivor_file_sha256" => _v97_file_sha256(survivor_path),
        "experimental_validation" => "not_established",
        "physical_device_feasibility" => "not_claimed",
        "claim_boundary" => EXHAUSTIVE_PHYSICAL_CAMPAIGN_V97_CLAIM_BOUNDARY)
    body["merge_hash"] = canonical_hash(body)
    _v97_json_write(joinpath(output_dir, "high_cost_merged.json"), body)
    body
end

function write_v97_exhaustive_acceptance(project_root::AbstractString;
        output_dir = joinpath(project_root, "runs", V97_FORMAL_CAMPAIGN_ID))
    manifest = JSON3.read(read(joinpath(output_dir, "campaign_manifest.json"), String),
        Dict{String,Any})
    closure = JSON3.read(read(joinpath(output_dir, "closure_merged.json"), String),
        Dict{String,Any})
    high_cost = JSON3.read(read(joinpath(output_dir, "high_cost_merged.json"), String),
        Dict{String,Any})
    after = _v97_preservation_snapshot(project_root)
    before = Dict{String,String}(String(key) => String(value)
        for (key, value) in manifest["sealed_artifact_snapshot"])
    preservation = Dict("status" => before == after ? "pass" : "fail",
        "changed" => sort!([key for key in keys(before) if before[key] != after[key]]),
        "sealed_artifact_count" => length(before))
    closure_hist = Dict{String,Int}(String(key) => Int(value)
        for (key, value) in closure["closure_status_histogram"])
    high_hist = Dict{String,Int}(String(key) => Int(value)
        for (key, value) in high_cost["expanded_status_histogram"])
    final_hist = Dict{String,Int}(
        "closed" => 0,
        "unsupported" => get(closure_hist, "unsupported", 0) +
            get(high_hist, "unsupported", 0),
        "physical_fail" => get(high_hist, "physical_fail", 0),
        "numerical_fail" => get(high_hist, "numerical_fail", 0),
        "unknown" => get(high_hist, "unknown", 0),
    )
    all_statuses_explicit = Set(keys(final_hist)) == V97_SCREEN_STATUSES
    count_conserved = sum(values(final_hist)) == V97_MAXIMUM_REQUEST_INDEX
    sentinels_per_shard = Int(closure["sentinel_pass_shard_count"]) ==
        Int(closure["closure_shard_count"]) && Int(high_cost["sentinel_pass_shard_count"]) ==
        Int(high_cost["high_cost_shard_count"])
    exact_high_cost_input_match = high_cost["closure_unique_input_sha256"] ==
        closure["unique_closed_input_sha256"] && Int(high_cost["representative_match_count"]) ==
        Int(closure["unique_closed_input_count"])
    accepted = manifest["grammar_exhaustive"] === true && closure["status"] == "pass" &&
        high_cost["status"] == "pass" && preservation["status"] == "pass" &&
        all_statuses_explicit && count_conserved && sentinels_per_shard &&
        exact_high_cost_input_match &&
        Int(high_cost["unique_closed_executed"]) == Int(closure["unique_closed_input_count"])
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V97_PROTOCOL_ID,
        "campaign_id" => V97_FORMAL_CAMPAIGN_ID,
        "status" => accepted ? "pass" : "fail",
        "processed" => closure["processed"], "grammar_cardinality" => V97_MAXIMUM_REQUEST_INDEX,
        "grammar_exhaustive" => closure["grammar_exhaustive"],
        "unique_nonisomorphic_topologies" => closure["unique_nonisomorphic_topologies"],
        "closure_funnel" => closure_hist,
        "unique_closed_input_count" => closure["unique_closed_input_count"],
        "closed_deduplication_count" => closure["closed_deduplication_count"],
        "high_cost_unique_status" => high_cost["unique_status_histogram"],
        "final_expanded_status_histogram" => final_hist,
        "all_statuses_explicit" => all_statuses_explicit,
        "count_conserved" => count_conserved,
        "closed_only_high_cost_execution" => true,
        "exact_high_cost_input_match" => exact_high_cost_input_match,
        "sentinels_per_shard" => sentinels_per_shard,
        "sentinel_shard_count" => Int(closure["closure_shard_count"]) +
            Int(high_cost["high_cost_shard_count"]),
        "historical_result_fields_read" => ["request_index"],
        "historical_gate_metric_consumed" => false,
        "deduplication_key" => ["graph_hash", "solver_input_hash"],
        "sealed_v91_v96_preservation" => preservation,
        "external_validation" => "not_established",
        "physical_device_passed_complete_vvuq" => false,
        "physical_device_feasibility" => "not_claimed",
        "physical_conclusion_expanded" => false,
        "artifacts" => Dict("closure_rows" => "closure_shard_*.jsonl",
            "unique_closed_inputs" => "unique_closed_inputs.jsonl",
            "new_survivors" => high_cost["survivor_file"],
            "blocker_statistics" => "blocker_statistics.json",
            "funnel" => "full_funnel.json"),
        "claim_boundary" => EXHAUSTIVE_PHYSICAL_CAMPAIGN_V97_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    _v97_json_write(joinpath(output_dir, "acceptance.json"), body)
    _v97_json_write(joinpath(output_dir, "blocker_statistics.json"),
        closure["blocker_histogram"])
    _v97_json_write(joinpath(output_dir, "full_funnel.json"), Dict(
        "closure" => closure_hist, "high_cost_unique" => high_cost["unique_status_histogram"],
        "high_cost_expanded" => high_hist, "final_expanded" => final_hist))
    report = """# v97 Exhaustive Physical Rescreen Acceptance

- Acceptance: `$(body["status"])`.
- Complete grammar coverage: $(body["processed"])/$(body["grammar_cardinality"]).
- Unique non-isomorphic topologies: $(body["unique_nonisomorphic_topologies"]).
- Closure funnel: `$(JSON3.write(closure_hist))`.
- Unique closed inputs sent to high-cost execution: $(body["unique_closed_input_count"]).
- Final expanded statuses: `$(JSON3.write(final_hist))`.
- Sealed v91-v96 preservation: `$(preservation["status"])`.

Every closure shard and high-cost shard ran the manufactured solution, ITER, and C-2W
through the same v96 compiler/provider/solver/numerical-VVUQ chain before candidate work.
Only exact unique closed graph/solver inputs entered high-cost execution. Historical v91
gate metrics were not read or credited.

`unknown` denotes missing candidate-bound validation evidence after numerical execution.
It is independent from `unsupported`, `physical_fail`, and `numerical_fail`. This reduced
campaign does not establish experimental validation or device feasibility.

Acceptance hash: `$(body["acceptance_hash"])`.
"""
    write(joinpath(output_dir, "acceptance_report.md"), report)
    body
end

function run_exhaustive_physical_campaign_v97(project_root::AbstractString;
        output_dir = joinpath(project_root, "runs", V97_FORMAL_CAMPAIGN_ID),
        force::Bool = false, high_cost_batch_size::Integer = 4096)
    mkpath(output_dir)
    manifest_path = joinpath(output_dir, "campaign_manifest.json")
    manifest = if isfile(manifest_path) && !force
        JSON3.read(read(manifest_path, String), Dict{String,Any})
    else
        value = compile_exhaustive_campaign_manifest_v97(project_root)
        _v97_json_write(manifest_path, value); value
    end
    for shard in manifest["closure_shards"]
        run_v97_closure_shard(project_root, Int(shard["shard_id"]); output_dir,
            manifest, force)
    end
    merge_v97_closure_shards(project_root; output_dir, manifest)
    high_manifest = compile_v97_high_cost_manifest(project_root; output_dir,
        batch_size = high_cost_batch_size)
    for shard in high_manifest["shards"]
        run_v97_high_cost_shard(project_root, Int(shard["shard_id"]); output_dir,
            manifest = high_manifest, force)
    end
    merge_v97_high_cost_shards(project_root; output_dir)
    write_v97_exhaustive_acceptance(project_root; output_dir)
end
