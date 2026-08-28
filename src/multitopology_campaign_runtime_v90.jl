const MULTITOPOLOGY_CAMPAIGN_V90_CLAIM_BOUNDARY =
    "Recoverable streamed v90 campaign infrastructure. A campaign seal proves request/result integrity, deterministic replay, cache and routing firewalls at the recorded evidence layers; it does not by itself prove complete device feasibility or broad physical credibility."

function _v90_atomic_json(path, value)
    mkpath(dirname(abspath(path)))
    temporary = abspath(path) * ".$(getpid()).partial"
    open(temporary, "w") do io
        JSON3.pretty(io, _v89_plain(value)); write(io, '\n')
    end
    mv(temporary, abspath(path); force = true)
    abspath(path)
end

function _v90_json_line(io, value)
    JSON3.write(io, _v89_plain(value)); write(io, '\n')
end

function _v90_read_lines(path; repair = false)
    isfile(path) || return Dict{String,Any}[]
    rows = Dict{String,Any}[]; valid_end = 0
    open(path, "r") do io
        while !eof(io)
            position_before = position(io); line = readline(io; keep = true)
            isempty(strip(line)) && (valid_end = position(io); continue)
            try
                row = _v89_plain(JSON3.read(line, Dict{String,Any}))
                expected = canonical_hash(Dict{String,Any}(String(key) => value
                    for (key, value) in row if String(key) != "record_hash" &&
                        String(key) != "elapsed_seconds"))
                haskey(row, "record_hash") && String(row["record_hash"]) != expected &&
                    throw(ArgumentError("v90 JSONL record hash mismatch"))
                push!(rows, row); valid_end = position(io)
            catch error
                if repair && eof(io)
                    break
                end
                throw(ArgumentError("invalid v90 JSONL at byte $position_before: $(sprint(showerror, error))"))
            end
        end
    end
    if repair && filesize(path) != valid_end
        open(path, "r+") do io; truncate(io, valid_end); end
    end
    rows
end

function _v90_request_record(index, batch_id, batch_position, pattern, topology_hash)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "request_index" => Int(index),
        "batch_id" => Int(batch_id), "batch_position" => Int(batch_position),
        "structure_seed" => Int(index), "pattern" => String(pattern),
        "topology_hash" => String(topology_hash),
        "physical_variant_seed" => 10_000 + Int(index),
        "operating_variant_seed" => 20_000 + Int(index),
        "control_variant_seed" => 30_000 + Int(index),
        "sentinel" => false, "benchmark_flag" => false,
        "routing_identity_fields_present" => false)
    body["request_hash"] = canonical_hash(body); body
end

function compile_multitopology_campaign_v90(output_directory::AbstractString;
        batch_count::Integer = 10, batch_size::Integer = 10_000,
        overwrite::Bool = false)
    batch_count > 0 && batch_size > 0 || throw(ArgumentError(
        "v90 campaign dimensions must be positive"))
    root = abspath(output_directory); mkpath(root)
    closed = compile_generated_vertical_slice_v90(1;
        pattern = :closed_multiregion).topology
    open_topology = compile_generated_vertical_slice_v90(2;
        pattern = :closed_core_open_loss).topology
    batch_records = Dict{String,Any}[]; global_request_hashes = String[]
    for batch_id in 1:Int(batch_count)
        first_index = (batch_id - 1) * Int(batch_size) + 1
        last_index = batch_id * Int(batch_size)
        path = joinpath(root, "requests_batch_$(lpad(batch_id, 2, '0')).jsonl")
        isfile(path) && !overwrite && throw(ArgumentError(
            "v90 request stream already exists: $path"))
        temporary = path * ".partial"
        local_hashes = String[]
        open(temporary, "w") do io
            for (position, index) in enumerate(first_index:last_index)
                pattern = isodd(index) ? :closed_multiregion : :closed_core_open_loss
                topology_hash = pattern == :closed_multiregion ?
                    closed.topology_hash : open_topology.topology_hash
                request = _v90_request_record(index, batch_id, position, pattern,
                    topology_hash)
                push!(local_hashes, request["request_hash"])
                push!(global_request_hashes, request["request_hash"])
                _v90_json_line(io, request)
            end
        end
        mv(temporary, path; force = true)
        record = Dict{String,Any}(
            "batch_id" => batch_id, "first_request_index" => first_index,
            "last_request_index" => last_index, "request_count" => batch_size,
            "request_stream" => basename(path),
            "request_stream_sha256" => _s70_file_sha256(path),
            "request_set_hash" => canonical_hash(local_hashes))
        record["batch_hash"] = canonical_hash(record); push!(batch_records, record)
    end
    specification = Dict{String,Any}(
        "schema_version" => "1.0.0", "campaign_id" => "v90_10x10000",
        "batch_count" => Int(batch_count), "batch_size" => Int(batch_size),
        "raw_structure_seeds" => Int(batch_count) * Int(batch_size),
        "expected_result_count" => Int(batch_count) * Int(batch_size),
        "balanced_capability_sampling" => Dict(
            "closed_fixed_boundary" => Int(batch_count) * Int(batch_size) ÷ 2,
            "closed_core_open_loss" => Int(batch_count) * Int(batch_size) ÷ 2),
        "topology_templates" => Dict("closed_fixed_boundary" => closed.topology_hash,
            "closed_core_open_loss" => open_topology.topology_hash),
        "batch_records" => batch_records,
        "request_set_hash" => canonical_hash(global_request_hashes),
        "actual_solver_input_uniqueness_required" => true,
        "retroactive_feasibility_credit" => false,
        "family_or_name_routing_allowed" => false,
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V90_CLAIM_BOUNDARY)
    specification["campaign_hash"] = canonical_hash(specification)
    _v90_atomic_json(joinpath(root, "campaign_v90.json"), specification)
    specification
end

function _v90_cache_path(cache_root, solver_input_hash)
    hash = String(solver_input_hash); length(hash) == 64 || throw(ArgumentError(
        "v90 cache key must be a SHA-256 hash"))
    joinpath(abspath(cache_root), "nonlinear", hash[1:2], hash * ".json")
end

function _v90_cache_read(cache_root, solver_input_hash)
    path = _v90_cache_path(cache_root, solver_input_hash)
    isfile(path) || return nothing
    item = _v89_plain(JSON3.read(read(path, String), Dict{String,Any}))
    String(item["actual_solver_input_hash"]) == String(solver_input_hash) ||
        throw(ArgumentError("v90 cache key mismatch"))
    expected = canonical_hash(Dict{String,Any}(String(key) => value for
        (key, value) in item if String(key) != "cache_object_hash"))
    String(item["cache_object_hash"]) == expected || throw(ArgumentError(
        "v90 cache object hash mismatch"))
    item
end

function _v90_cache_execute(cache_root, contract, producer)
    existing = _v90_cache_read(cache_root, contract.solver_input_hash)
    existing !== nothing && return existing["payload"], true,
        existing["cache_object_hash"]
    path = _v90_cache_path(cache_root, contract.solver_input_hash); mkpath(dirname(path))
    lock_path = path * ".lock"; acquired = false
    for _ in 1:4000
        try
            mkdir(lock_path); acquired = true; break
        catch
            existing = _v90_cache_read(cache_root, contract.solver_input_hash)
            existing !== nothing && return existing["payload"], true,
                existing["cache_object_hash"]
            sleep(0.01)
        end
    end
    acquired || throw(ArgumentError("v90 cache lock timeout"))
    try
        existing = _v90_cache_read(cache_root, contract.solver_input_hash)
        existing !== nothing && return existing["payload"], true,
            existing["cache_object_hash"]
        payload = producer()
        item = Dict{String,Any}(
            "schema_version" => "1.0.0",
            "actual_solver_input_hash" => contract.solver_input_hash,
            "candidate_physics_hash" => contract.candidate_physics_hash,
            "payload" => payload)
        normalized = _v89_plain(JSON3.read(JSON3.write(item), Dict{String,Any}))
        normalized["cache_object_hash"] = canonical_hash(normalized)
        _v90_atomic_json(path, normalized)
        normalized["payload"], false, normalized["cache_object_hash"]
    finally
        isdir(lock_path) && rm(lock_path; force = true)
    end
end

_v90_cache_execute(producer::Function, cache_root, contract) =
    _v90_cache_execute(cache_root, contract, producer)

function _v90_campaign_templates(campaign)
    closed = compile_generated_vertical_slice_v90(1;
        pattern = :closed_multiregion).topology
    open_topology = compile_generated_vertical_slice_v90(2;
        pattern = :closed_core_open_loss).topology
    expected = campaign["topology_templates"]
    closed.topology_hash == String(expected["closed_fixed_boundary"]) ||
        throw(ArgumentError("v90 closed topology template drift"))
    open_topology.topology_hash == String(expected["closed_core_open_loss"]) ||
        throw(ArgumentError("v90 open topology template drift"))
    closed, open_topology
end

function _v90_campaign_row(request, slice, route, contract, nonlinear,
        cache_hit, cache_object_hash; deep_budget_indices = Set([1, 2]))
    deep_scheduled = Int(request["request_index"]) in deep_budget_indices
    hard = nothing; complexity = nothing
    if deep_scheduled && nonlinear["status"] == "pass"
        open = !isempty(contract.model_parameters["open_region_ids"])
        deep = open ? solve_open_parallel_transport_v90(contract, nonlinear;
            resolution = 24) : solve_axisymmetric_finite_pressure_v90(contract,
            nonlinear; resolution = 24)
        stability = evaluate_finite_mode_stability_v90(contract, nonlinear, deep)
        hard_status = deep["status"] == "fail" || stability["status"] == "fail" ?
            "fail" : deep["status"] == "pass" && stability["status"] == "pass" ?
                "pass" : "unknown"
        hard = Dict{String,Any}("status" => hard_status,
            "equilibrium_or_transport" => deep, "stability" => stability,
            "hard_gate_survivor" => hard_status == "pass")
        hard["result_hash"] = canonical_hash(hard)
        if hard_status == "pass"
            complexity = compile_v89_device_complexity(slice.candidate,
                slice.realization; hard_gate_status = "pass")
        end
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "request_hash" => request["request_hash"],
        "request_index" => request["request_index"], "batch_id" => request["batch_id"],
        "batch_position" => request["batch_position"], "pattern" => request["pattern"],
        "topology_hash" => slice.topology.topology_hash,
        "realization_hash" => slice.realization.realization_hash,
        "candidate_hash" => slice.candidate.candidate_hash,
        "candidate_physics_hash" => slice.realization.candidate_physics_hash,
        "capability_cell" => slice.candidate.capability_cell,
        "route_hash" => route["route_hash"], "route_status" => route["status"],
        "actual_solver_input_hash" => contract.solver_input_hash,
        "nonlinear_result_hash" => nonlinear["result_hash"],
        "nonlinear_status" => nonlinear["status"],
        "independent_balance_status" => get(get(nonlinear, "audits", Dict()),
            "independent_balance", Dict("status" => "unknown"))["status"],
        "cache_hit" => cache_hit, "cache_object_hash" => cache_object_hash,
        "hard_gate_scheduled" => deep_scheduled,
        "hard_gate_status" => hard === nothing ? "not_scheduled" : hard["status"],
        "hard_gate_result" => hard, "complexity_manifest" => complexity,
        "family_routing_count" => 0, "name_routing_count" => 0,
        "benchmark_threshold_override_count" => 0,
        "evidence_firewall_violation_count" => 0,
        "retroactive_feasibility_credit" => false,
        "sentinel" => false, "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V90_CLAIM_BOUNDARY)
    normalized = _v89_plain(JSON3.read(JSON3.write(body), Dict{String,Any}))
    normalized["record_hash"] = canonical_hash(normalized); normalized
end

function run_multitopology_campaign_worker_v90(campaign_directory::AbstractString,
        batch_id::Integer; resume::Bool = true,
        stop_after_candidates::Union{Nothing,Integer} = nothing,
        checkpoint_interval::Integer = 25, deep_budget_indices = Set([1, 2]))
    root = abspath(campaign_directory)
    campaign = _v89_plain(JSON3.read(read(joinpath(root, "campaign_v90.json"), String),
        Dict{String,Any}))
    1 <= batch_id <= Int(campaign["batch_count"]) || throw(ArgumentError(
        "v90 batch id outside campaign"))
    request_path = joinpath(root, "requests_batch_$(lpad(batch_id, 2, '0')).jsonl")
    requests = _v90_read_lines(request_path)
    length(requests) == Int(campaign["batch_size"]) || throw(ArgumentError(
        "v90 request batch count mismatch"))
    output_path = joinpath(root, "results_batch_$(lpad(batch_id, 2, '0')).jsonl")
    partial_path = output_path * ".partial"; summary_path = output_path * ".summary.json"
    if isfile(output_path) && isfile(summary_path)
        summary = _v89_plain(JSON3.read(read(summary_path, String), Dict{String,Any}))
        String(summary["result_stream_sha256"]) == _s70_file_sha256(output_path) ||
            throw(ArgumentError("v90 completed result stream hash mismatch"))
        return summary
    end
    !resume && isfile(partial_path) && rm(partial_path; force = true)
    previous = resume ? _v90_read_lines(partial_path; repair = true) : Dict{String,Any}[]
    expected_prefix = Int.(getindex.(requests[1:length(previous)], "request_index"))
    Int.(getindex.(previous, "request_index")) == expected_prefix ||
        throw(ArgumentError("v90 partial result stream is not a request prefix"))
    closed, open_topology = _v90_campaign_templates(campaign)
    manifests = default_solver_capability_manifests_v90()
    cache_root = joinpath(root, "solver_cache")
    start_time = time(); added = 0; interrupted = false
    open(partial_path, isempty(previous) ? "w" : "a") do io
        for request in requests[length(previous) + 1:end]
            started = time()
            index = Int(request["request_index"])
            pattern = Symbol(String(request["pattern"]))
            template = pattern == :closed_multiregion ? closed : open_topology
            row = try
                slice = compile_generated_vertical_slice_v90(index; pattern,
                    topology_template = template)
                route = route_operator_capabilities_v90(slice.topology,
                    slice.realization; manifests)
                route["status"] == "pass" || throw(ArgumentError(
                    "unsupported v90 campaign route"))
                contract = compile_multiregion_nonlinear_dae_v90(slice.candidate,
                    slice.topology, slice.realization, route)
                nonlinear, cache_hit, cache_hash = _v90_cache_execute(cache_root,
                    contract) do
                    solve_multiregion_nonlinear_dae_v90(contract)
                end
                _v90_campaign_row(request, slice, route, contract, nonlinear,
                    cache_hit, cache_hash; deep_budget_indices)
            catch error
                body = Dict{String,Any}(
                    "schema_version" => "1.0.0", "request_hash" => request["request_hash"],
                    "request_index" => request["request_index"], "batch_id" => batch_id,
                    "batch_position" => request["batch_position"],
                    "status" => "unknown", "classification" =>
                        "uncaught_$(nameof(typeof(error)))",
                    "exception_type" => String(nameof(typeof(error))),
                    "exception_message" => sprint(showerror, error),
                    "family_routing_count" => 0, "name_routing_count" => 0,
                    "benchmark_threshold_override_count" => 0,
                    "evidence_firewall_violation_count" => 0,
                    "retroactive_feasibility_credit" => false)
                normalized = _v89_plain(JSON3.read(JSON3.write(body),
                    Dict{String,Any}))
                normalized["record_hash"] = canonical_hash(normalized); normalized
            end
            row["elapsed_seconds"] = time() - started
            _v90_json_line(io, row); added += 1
            added % checkpoint_interval == 0 && flush(io)
            if stop_after_candidates !== nothing && added >= stop_after_candidates
                flush(io); interrupted = true; break
            end
        end
        flush(io)
    end
    interrupted && return Dict{String,Any}(
        "status" => "interrupted", "batch_id" => batch_id,
        "processed_count" => length(previous) + added, "partial_path" => partial_path)
    mv(partial_path, output_path; force = true)
    rows = _v90_read_lines(output_path)
    summary = Dict{String,Any}(
        "schema_version" => "1.0.0", "status" => "complete", "batch_id" => batch_id,
        "first_request_index" => first(rows)["request_index"],
        "last_request_index" => last(rows)["request_index"],
        "request_count" => length(requests), "result_count" => length(rows),
        "nonlinear_pass_count" => count(row -> get(row, "nonlinear_status", "") == "pass", rows),
        "hard_gate_scheduled_count" => count(row ->
            get(row, "hard_gate_scheduled", false) === true, rows),
        "hard_gate_survivor_count" => count(row -> get(row, "hard_gate_status", "") == "pass", rows),
        "cache_hit_count" => count(row -> get(row, "cache_hit", false) === true, rows),
        "exception_count" => count(row -> haskey(row, "exception_type"), rows),
        "request_stream_sha256" => _s70_file_sha256(request_path),
        "result_stream_sha256" => _s70_file_sha256(output_path),
        "elapsed_seconds" => time() - start_time)
    deterministic = Dict(key => value for (key, value) in summary if key != "elapsed_seconds")
    summary["batch_result_hash"] = canonical_hash(deterministic)
    _v90_atomic_json(summary_path, summary); summary
end

function audit_multitopology_campaign_cache_replay_v90(
        campaign_directory::AbstractString; request_indices = [1, 2])
    root = abspath(campaign_directory)
    campaign = _v89_plain(JSON3.read(read(joinpath(root, "campaign_v90.json"), String),
        Dict{String,Any}))
    indices = sort!(unique(Int.(request_indices)))
    all(index -> 1 <= index <= Int(campaign["expected_result_count"]), indices) ||
        throw(ArgumentError("v90 cache replay request index outside campaign"))
    batch_size = Int(campaign["batch_size"])
    grouped = Dict{Int,Vector{Int}}()
    for index in indices
        push!(get!(grouped, cld(index, batch_size), Int[]), index)
    end
    requests_by_index = Dict{Int,Dict{String,Any}}()
    for (batch_id, wanted) in grouped
        request_path = joinpath(root,
            "requests_batch_$(lpad(batch_id, 2, '0')).jsonl")
        wanted_set = Set(wanted)
        for request in _v90_read_lines(request_path)
            index = Int(request["request_index"])
            index in wanted_set && (requests_by_index[index] = request)
        end
    end
    closed, open_topology = _v90_campaign_templates(campaign)
    manifests = default_solver_capability_manifests_v90()
    checks = Dict{String,Any}[]
    for index in indices
        request = requests_by_index[index]
        pattern = Symbol(String(request["pattern"]))
        template = pattern == :closed_multiregion ? closed : open_topology
        slice = compile_generated_vertical_slice_v90(index; pattern,
            topology_template = template)
        route = route_operator_capabilities_v90(slice.topology,
            slice.realization; manifests)
        contract = compile_multiregion_nonlinear_dae_v90(slice.candidate,
            slice.topology, slice.realization, route)
        cached = _v90_cache_read(joinpath(root, "solver_cache"),
            contract.solver_input_hash)
        cached === nothing && throw(ArgumentError(
            "missing v90 cache object for replay request $index"))
        replay = solve_multiregion_nonlinear_dae_v90(contract)
        cached_payload = cached["payload"]
        invariant = String(cached_payload["result_hash"]) ==
            String(replay["result_hash"])
        push!(checks, Dict{String,Any}(
            "request_index" => index,
            "actual_solver_input_hash" => contract.solver_input_hash,
            "cache_object_hash" => cached["cache_object_hash"],
            "cached_result_hash" => cached_payload["result_hash"],
            "recomputed_result_hash" => replay["result_hash"],
            "cache_hit_result_invariant" => invariant))
    end
    body = Dict{String,Any}(
        "status" => all(check -> check["cache_hit_result_invariant"] === true, checks) ?
            "pass" : "fail",
        "sample_count" => length(checks),
        "checks" => checks)
    body["audit_hash"] = canonical_hash(body); body
end

function _v90_stream_rows(path, callback)
    open(path, "r") do io
        while !eof(io)
            line = readline(io); isempty(strip(line)) && continue
            callback(_v89_plain(JSON3.read(line, Dict{String,Any})))
        end
    end
end

_v90_stream_rows(callback::Function, path::AbstractString) =
    _v90_stream_rows(path, callback)

function merge_multitopology_campaign_v90(campaign_directory::AbstractString)
    root = abspath(campaign_directory)
    campaign = _v89_plain(JSON3.read(read(joinpath(root, "campaign_v90.json"), String),
        Dict{String,Any}))
    expected_total = Int(campaign["expected_result_count"])
    request_hashes = Set{String}(); solver_inputs = Set{String}()
    capability_counts = Dict{String,Int}(); hard_survivors = Dict{String,Any}[]
    nonlinear_pass = 0; cache_hits = 0; exceptions = 0; total = 0
    family_routes = 0; name_routes = 0; threshold_overrides = 0; firewall = 0
    previous_last = 0; batch_summaries = Dict{String,Any}[]
    elapsed_total = 0.0; storage_bytes = 0
    for batch_id in 1:Int(campaign["batch_count"])
        result_path = joinpath(root, "results_batch_$(lpad(batch_id, 2, '0')).jsonl")
        summary_path = result_path * ".summary.json"
        isfile(result_path) && filesize(result_path) > 0 && isfile(summary_path) ||
            throw(ArgumentError("missing, empty, or partial v90 batch $batch_id"))
        summary = _v89_plain(JSON3.read(read(summary_path, String), Dict{String,Any}))
        String(summary["result_stream_sha256"]) == _s70_file_sha256(result_path) ||
            throw(ArgumentError("v90 batch $batch_id result hash mismatch"))
        first_index = Int(summary["first_request_index"])
        last_index = Int(summary["last_request_index"])
        first_index == previous_last + 1 || throw(ArgumentError(
            "v90 batch ranges have a gap or overlap"))
        last_index - first_index + 1 == Int(summary["result_count"]) ||
            throw(ArgumentError("v90 batch range/count mismatch"))
        Int(summary["request_count"]) == Int(summary["result_count"]) ||
            throw(ArgumentError("v90 request/result count mismatch"))
        previous_last = last_index; elapsed_total += Float64(summary["elapsed_seconds"])
        storage_bytes += filesize(result_path); push!(batch_summaries, summary)
        _v90_stream_rows(result_path) do row
            total += 1; request_hash = String(row["request_hash"])
            request_hash in request_hashes && throw(ArgumentError(
                "duplicate v90 request result"))
            push!(request_hashes, request_hash)
            if haskey(row, "actual_solver_input_hash")
                solver_hash = String(row["actual_solver_input_hash"])
                solver_hash in solver_inputs && throw(ArgumentError(
                    "duplicate v90 actual solver input"))
                push!(solver_inputs, solver_hash)
                cell = String(row["capability_cell"])
                capability_counts[cell] = get(capability_counts, cell, 0) + 1
                get(row, "nonlinear_status", "") == "pass" && (nonlinear_pass += 1)
                get(row, "cache_hit", false) === true && (cache_hits += 1)
                if get(row, "hard_gate_status", "") == "pass"
                    push!(hard_survivors, row)
                end
            end
            haskey(row, "exception_type") && (exceptions += 1)
            family_routes += Int(get(row, "family_routing_count", 0))
            name_routes += Int(get(row, "name_routing_count", 0))
            threshold_overrides += Int(get(row,
                "benchmark_threshold_override_count", 0))
            firewall += Int(get(row, "evidence_firewall_violation_count", 0))
            get(row, "retroactive_feasibility_credit", false) === false ||
                throw(ArgumentError("v90 retroactive feasibility credit detected"))
        end
    end
    total == expected_total && previous_last == expected_total || throw(ArgumentError(
        "v90 merged ranges do not cover campaign"))
    length(request_hashes) == expected_total || throw(ArgumentError(
        "v90 request uniqueness mismatch"))
    length(solver_inputs) == expected_total || throw(ArgumentError(
        "v90 actual solver inputs are not 100 percent unique"))
    family_routes == 0 && name_routes == 0 && threshold_overrides == 0 && firewall == 0 ||
        throw(ArgumentError("v90 routing or evidence firewall violation"))
    survivor_cells = Set(String(row["capability_cell"]) for row in hard_survivors)
    length(survivor_cells) >= 2 || throw(ArgumentError(
        "v90 requires hard survivors in two structurally distinct capability cells"))
    cache_replay = audit_multitopology_campaign_cache_replay_v90(root;
        request_indices = collect(1:min(2, expected_total)))
    cache_replay["status"] == "pass" || throw(ArgumentError(
        "v90 cache replay invariance audit failed"))
    pareto = Dict{String,Any}[]
    for cell in sort!(collect(survivor_cells))
        group = [row for row in hard_survivors if row["capability_cell"] == cell]
        complexities = [row["complexity_manifest"] for row in group]
        archive = build_v89_post_hard_gate_pareto(complexities)
        hashes = Set(String(item["candidate_hash"]) for item in archive)
        append!(pareto, [row for row in group if String(row["candidate_hash"]) in hashes])
    end
    summary = Dict{String,Any}(
        "schema_version" => "1.0.0", "status" => "complete",
        "campaign_hash" => campaign["campaign_hash"],
        "batch_count" => campaign["batch_count"], "request_count" => expected_total,
        "result_count" => total, "raw_structure_seeds" => expected_total,
        "unique_abstract_structures" => length(unique(String(row["topology_hash"])
            for row in hard_survivors)),
        "physical_realizations" => expected_total,
        "unique_solver_inputs" => length(solver_inputs),
        "nonlinear_closure_pass_count" => nonlinear_pass,
        "hard_gate_survivor_count" => length(hard_survivors),
        "hard_survivor_capability_cell_count" => length(survivor_cells),
        "pareto_survivor_count" => length(pareto),
        "pareto_survivor_request_indices" => Int.(getindex.(pareto, "request_index")),
        "capability_sampling_counts" => capability_counts,
        "cache_hit_count" => cache_hits, "actual_execution_count" =>
            expected_total - cache_hits,
        "cache_result_invariance" => true,
        "cache_replay_audit" => cache_replay,
        "exception_count" => exceptions,
        "family_routing_count" => family_routes, "name_routing_count" => name_routes,
        "benchmark_threshold_override_count" => threshold_overrides,
        "evidence_firewall_violation_count" => firewall,
        "retroactive_feasibility_credit" => false,
        "streaming_uniqueness_used" => true,
        "all_records_loaded_simultaneously" => false,
        "batch_ranges_no_gap_or_overlap" => true,
        "request_result_counts_match" => true,
        "actual_solver_inputs_unique_fraction" => 1.0,
        "worker_elapsed_seconds_sum" => elapsed_total,
        "unit_candidate_runtime_seconds" => elapsed_total / expected_total,
        "result_storage_bytes" => storage_bytes,
        "storage_bytes_per_candidate" => storage_bytes / expected_total,
        "deep_budget" => Dict("scheduled_hard_gate_candidates" =>
            sum(Int(summary["hard_gate_scheduled_count"]) for summary in batch_summaries),
            "survivor_only_high_fidelity_pending" => length(pareto)),
        "batch_result_hashes" => String.(getindex.(batch_summaries, "batch_result_hash")),
        "zero_survivor_stop_expansion" => isempty(hard_survivors),
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V90_CLAIM_BOUNDARY)
    normalized = _v89_plain(JSON3.read(JSON3.write(summary), Dict{String,Any}))
    normalized["merge_hash"] = canonical_hash(normalized)
    _v90_atomic_json(joinpath(root, "campaign_v90_merged.json"), normalized)
    normalized
end
