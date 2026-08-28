const MULTITOPOLOGY_CAMPAIGN_V91_CLAIM_BOUNDARY =
    "A v91 campaign seal proves that every indexed topology was generated, canonicalized, compiled, reduced-screened, recorded, recovered, and replayed under frozen gates. It does not promote the reduced evidence ceiling."

function _v91_atomic_json(path, value)
    target = abspath(path); mkpath(dirname(target)); temporary = target * ".partial"
    open(temporary, "w") do io
        JSON3.pretty(io, _v89_plain(value)); write(io, '\n')
    end
    mv(temporary, target; force = true); target
end

function _v91_json_line(io, value)
    JSON3.write(io, _v89_plain(value)); write(io, '\n')
end

function _v91_record_replay_hash(row)
    canonical_hash(Dict{String,Any}(String(key) => value for (key, value) in row
        if String(key) != "record_hash"))
end

function _v91_read_rows(path; repair_tail::Bool = false)
    isfile(path) || return Dict{String,Any}[]
    rows = Dict{String,Any}[]; valid_end = 0
    open(path, "r") do io
        while !eof(io)
            before = position(io); line = readline(io; keep = true)
            isempty(strip(line)) && (valid_end = position(io); continue)
            try
                row = _v89_plain(JSON3.read(line, Dict{String,Any}))
                String(row["record_hash"]) == _v91_record_replay_hash(row) ||
                    throw(ArgumentError("v91 record hash mismatch"))
                push!(rows, row); valid_end = position(io)
            catch error
                if repair_tail && eof(io)
                    break
                end
                throw(ArgumentError("invalid v91 JSONL at byte $before: $(sprint(showerror, error))"))
            end
        end
    end
    if repair_tail && filesize(path) != valid_end
        open(path, "r+") do io; truncate(io, valid_end); end
    end
    rows
end

function compile_multitopology_campaign_v91(output_directory::AbstractString;
        campaign_id::AbstractString, tier::AbstractString,
        total_requests::Integer, shard_size::Integer,
        overwrite::Bool = false)
    total_requests > 0 && shard_size > 0 || throw(ArgumentError(
        "v91 campaign dimensions must be positive"))
    total_requests <= V91_PREREGISTERED_GATES["maximum_request_index"] ||
        throw(ArgumentError("v91 campaign exceeds the injective grammar range"))
    total_requests % shard_size == 0 || throw(ArgumentError(
        "v91 campaign total must divide evenly into shards"))
    tier in ("pilot", "qualification", "formal") || throw(ArgumentError(
        "v91 campaign tier must be pilot, qualification, or formal"))
    root = abspath(output_directory); mkpath(root)
    manifest_path = joinpath(root, "campaign_v91.json")
    isfile(manifest_path) && !overwrite && throw(ArgumentError(
        "v91 campaign already exists: $manifest_path"))
    shard_count = Int(total_requests ÷ shard_size)
    shards = [Dict{String,Any}(
        "shard_id" => shard_id,
        "first_request_index" => (shard_id - 1) * Int(shard_size) + 1,
        "last_request_index" => shard_id * Int(shard_size),
        "expected_count" => Int(shard_size),
        "result_stream" => "results_shard_$(lpad(shard_id, 3, '0')).jsonl")
        for shard_id in 1:shard_count]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "campaign_id" => String(campaign_id),
        "tier" => String(tier), "total_requests" => Int(total_requests),
        "shard_size" => Int(shard_size), "shard_count" => shard_count,
        "index_first" => 1, "index_last" => Int(total_requests),
        "generator_id" => "v91_typed_rooted_tree_injective_20bit",
        "canonicalizer_id" => "v91_exact_rooted_typed_tree_certificate",
        "solver_portfolio_id" => "v91_candidate_bound_reduced_portfolio",
        "preregistered_gates" => deepcopy(V91_PREREGISTERED_GATES),
        "preregistered_gate_hash" => canonical_hash(V91_PREREGISTERED_GATES),
        "shards" => shards, "actual_execution_required" => true,
        "extrapolation_allowed" => false,
        "family_name_parent_routing_allowed" => false,
        "sentinel_or_benchmark_promotion_credit_allowed" => false,
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V91_CLAIM_BOUNDARY)
    normalized = _v89_plain(JSON3.read(JSON3.write(body), Dict{String,Any}))
    normalized["campaign_hash"] = canonical_hash(normalized)
    _v91_atomic_json(manifest_path, normalized); normalized
end

function _v91_load_campaign(root)
    path = joinpath(abspath(root), "campaign_v91.json")
    isfile(path) || throw(ArgumentError("v91 campaign manifest not found: $path"))
    campaign = _v89_plain(JSON3.read(read(path, String), Dict{String,Any}))
    expected = canonical_hash(Dict{String,Any}(String(key) => value for
        (key, value) in campaign if String(key) != "campaign_hash"))
    String(campaign["campaign_hash"]) == expected || throw(ArgumentError(
        "v91 campaign manifest hash mismatch"))
    String(campaign["preregistered_gate_hash"]) ==
        canonical_hash(V91_PREREGISTERED_GATES) || throw(ArgumentError(
            "v91 preregistered thresholds changed after campaign compilation"))
    campaign
end

function run_multitopology_campaign_shard_v91(campaign_directory::AbstractString,
        shard_id::Integer; resume::Bool = true,
        stop_after_candidates::Union{Nothing,Integer} = nothing,
        checkpoint_interval::Integer = 1000)
    root = abspath(campaign_directory); campaign = _v91_load_campaign(root)
    1 <= shard_id <= Int(campaign["shard_count"]) || throw(ArgumentError(
        "invalid v91 shard id"))
    shard = campaign["shards"][Int(shard_id)]
    path = joinpath(root, String(shard["result_stream"]))
    existing = resume ? _v91_read_rows(path; repair_tail = true) : Dict{String,Any}[]
    !resume && isfile(path) && rm(path; force = true)
    completed = length(existing)
    first_index = Int(shard["first_request_index"])
    last_index = Int(shard["last_request_index"])
    completed <= Int(shard["expected_count"]) || throw(ArgumentError(
        "v91 shard has too many records"))
    for (offset, row) in enumerate(existing)
        Int(row["request_index"]) == first_index + offset - 1 || throw(ArgumentError(
            "v91 resumed shard is not contiguous"))
    end
    mode = completed == 0 ? "w" : "a"
    processed_this_call = 0
    interrupted_result = open(path, mode) do io
        for index in first_index + completed:last_index
            record = compile_v91_campaign_record(index)
            _v91_json_line(io, record); completed += 1; processed_this_call += 1
            if checkpoint_interval > 0 && completed % checkpoint_interval == 0
                flush(io)
                _v91_atomic_json(path * ".checkpoint.json", Dict(
                    "campaign_hash" => campaign["campaign_hash"],
                    "shard_id" => Int(shard_id), "completed" => completed,
                    "last_request_index" => index,
                    "last_record_hash" => record["record_hash"]))
            end
            if stop_after_candidates !== nothing &&
                    processed_this_call >= Int(stop_after_candidates)
                flush(io)
                return Dict{String,Any}("status" => "interrupted",
                    "shard_id" => Int(shard_id), "result_count" => completed,
                    "result_stream" => path, "campaign_hash" => campaign["campaign_hash"])
            end
        end
        nothing
    end
    interrupted_result === nothing || return interrupted_result
    rows = _v91_read_rows(path)
    summary = Dict{String,Any}(
        "status" => "complete", "campaign_hash" => campaign["campaign_hash"],
        "shard_id" => Int(shard_id), "first_request_index" => first_index,
        "last_request_index" => last_index, "result_count" => length(rows),
        "result_stream" => basename(path), "result_stream_sha256" => _s70_file_sha256(path),
        "result_set_hash" => canonical_hash(String[row["record_hash"] for row in rows]),
        "hard_gate_survivor_count" => count(row -> row["hard_gate_survivor"] === true, rows))
    summary["summary_hash"] = canonical_hash(summary)
    _v91_atomic_json(path * ".summary.json", summary); summary
end

function run_multitopology_campaign_all_v91(campaign_directory::AbstractString;
        threaded::Bool = true, checkpoint_interval::Integer = 1000)
    root = abspath(campaign_directory); campaign = _v91_load_campaign(root)
    shard_ids = collect(1:Int(campaign["shard_count"]))
    summaries = Vector{Any}(undef, length(shard_ids))
    if threaded && Threads.nthreads() > 1
        Threads.@threads for position in eachindex(shard_ids)
            summaries[position] = run_multitopology_campaign_shard_v91(root,
                shard_ids[position]; checkpoint_interval)
        end
    else
        for position in eachindex(shard_ids)
            summaries[position] = run_multitopology_campaign_shard_v91(root,
                shard_ids[position]; checkpoint_interval)
        end
    end
    Dict("status" => all(item -> item["status"] == "complete", summaries) ?
        "complete" : "incomplete", "campaign_hash" => campaign["campaign_hash"],
        "shard_summaries" => summaries)
end

function perform_v91_recovery_drill(campaign_directory::AbstractString;
        interruption_count::Integer = 137)
    root = abspath(campaign_directory); campaign = _v91_load_campaign(root)
    shard = campaign["shards"][1]
    path = joinpath(root, String(shard["result_stream"]))
    isfile(path) && rm(path; force = true)
    for suffix in (".summary.json", ".checkpoint.json")
        isfile(path * suffix) && rm(path * suffix; force = true)
    end
    interrupted = run_multitopology_campaign_shard_v91(root, 1;
        stop_after_candidates = Int(interruption_count), checkpoint_interval = 17)
    interrupted["status"] == "interrupted" || throw(ArgumentError(
        "v91 recovery drill did not interrupt"))
    open(path, "a") do io; write(io, "{\"truncated_tail\":"); end
    repaired = run_multitopology_campaign_shard_v91(root, 1;
        resume = true, checkpoint_interval = 257)
    rows = _v91_read_rows(path)
    replay_indices = unique([1, min(Int(interruption_count), length(rows)), length(rows)])
    replay_checks = [Dict("request_index" => index,
        "match" => rows[index]["record_hash"] ==
            compile_v91_campaign_record(Int(rows[index]["request_index"]))["record_hash"])
        for index in replay_indices]
    body = Dict{String,Any}(
        "status" => repaired["status"] == "complete" &&
            all(item -> item["match"] === true, replay_checks) ? "pass" : "fail",
        "campaign_hash" => campaign["campaign_hash"],
        "interrupted_after" => Int(interruption_count),
        "truncated_tail_injected" => true, "tail_repaired" => true,
        "final_result_count" => length(rows), "replay_checks" => replay_checks,
        "result_stream_sha256" => _s70_file_sha256(path))
    body["recovery_hash"] = canonical_hash(body)
    _v91_atomic_json(joinpath(root, "recovery_drill_v91.json"), body); body
end

function _v91_sample_indices(total::Int, sample_count::Int)
    count = min(total, sample_count)
    sort!(unique(round.(Int, range(1, total; length = count))))
end

function merge_multitopology_campaign_v91(campaign_directory::AbstractString)
    root = abspath(campaign_directory); campaign = _v91_load_campaign(root)
    iso_hashes = Set{String}(); solver_hashes = Set{String}()
    cells = Dict{String,Int}(); result_count = 0; type_pass = 0
    compile_pass = 0; execute_pass = 0; genes_total = 0; genes_consumed = 0
    basis_total = 0; basis_consumed = 0; firewall = 0; routing = 0
    hard_survivors = Int[]; expected_index = 1; batch_ranges = Dict{String,Any}[]
    sample_targets = Set(_v91_sample_indices(Int(campaign["total_requests"]),
        Int(V91_PREREGISTERED_GATES["deterministic_replay_samples"])))
    sampled_rows = Dict{Int,Dict{String,Any}}()
    for shard_id in 1:Int(campaign["shard_count"])
        shard = campaign["shards"][shard_id]
        path = joinpath(root, String(shard["result_stream"]))
        rows = _v91_read_rows(path)
        length(rows) == Int(shard["expected_count"]) || throw(ArgumentError(
            "v91 shard $shard_id is incomplete"))
        for row in rows
            index = Int(row["request_index"])
            index == expected_index || throw(ArgumentError(
                "v91 campaign has a gap or overlap at request $expected_index"))
            expected_index += 1; result_count += 1
            push!(iso_hashes, String(row["isomorphism_hash"]))
            push!(solver_hashes, String(row["solver_input_hash"]))
            cell = String(row["capability_cell"]); cells[cell] = get(cells, cell, 0) + 1
            type_pass += row["type_status"] == "pass"
            compile_pass += row["route_status"] == "pass"
            execute_pass += row["solver_status"] == "pass"
            genes_total += Int(row["structural_gene_count"])
            genes_consumed += Int(row["consumed_structural_gene_count"])
            basis_total += Int(row["basis_coefficient_count"])
            basis_consumed += Int(row["consumed_basis_coefficient_count"])
            firewall += Int(row["evidence_firewall_violation_count"])
            routing += Int(row["family_name_parent_routing_count"])
            row["hard_gate_survivor"] === true && push!(hard_survivors, index)
            index in sample_targets && (sampled_rows[index] = row)
        end
        push!(batch_ranges, Dict("shard_id" => shard_id,
            "first_request_index" => shard["first_request_index"],
            "last_request_index" => shard["last_request_index"],
            "result_stream_sha256" => _s70_file_sha256(path)))
    end
    total = Int(campaign["total_requests"])
    relabel_targets = _v91_sample_indices(total,
        Int(V91_PREREGISTERED_GATES["canonical_relabel_samples"]))
    relabel_checks = [begin
        left = generate_family_neutral_topology_v91(index; relabel_nonce = 11)
        right = generate_family_neutral_topology_v91(index; relabel_nonce = 97)
        Dict("request_index" => index,
            "canonical_invariant" => left["isomorphism_hash"] == right["isomorphism_hash"] &&
                isomorphic_family_neutral_topology_v91(left, right))
    end for index in relabel_targets]
    replay_checks = [Dict("request_index" => index,
        "record_hash_match" => sampled_rows[index]["record_hash"] ==
            compile_v91_campaign_record(index)["record_hash"])
        for index in sort!(collect(keys(sampled_rows)))]
    duplicate_control_a = generate_family_neutral_topology_v91(1; relabel_nonce = 3)
    duplicate_control_b = generate_family_neutral_topology_v91(1; relabel_nonce = 19)
    distinct_control = generate_family_neutral_topology_v91(2; relabel_nonce = 3)
    duplicate_control = Dict("same_topology_relabel_detected" =>
        isomorphic_family_neutral_topology_v91(duplicate_control_a, duplicate_control_b),
        "different_typed_topology_separated" =>
            !isomorphic_family_neutral_topology_v91(duplicate_control_a, distinct_control))
    recovery_path = joinpath(root, "recovery_drill_v91.json")
    recovery = isfile(recovery_path) ? _v89_plain(JSON3.read(read(recovery_path, String),
        Dict{String,Any})) : Dict{String,Any}("status" => "missing")
    fractions = Dict{String,Any}(
        "unique_isomorphism_fraction" => length(iso_hashes) / total,
        "unique_solver_input_fraction" => length(solver_hashes) / total,
        "type_valid_fraction" => type_pass / total,
        "solver_compile_fraction" => compile_pass / total,
        "solver_execution_fraction" => execute_pass / total,
        "gene_consumption_fraction" => genes_consumed / max(genes_total, 1),
        "basis_consumption_fraction" => basis_consumed / max(basis_total, 1))
    gates = Dict{String,Any}(
        "exact_result_count" => result_count == total,
        "topology_breadth" => fractions["unique_isomorphism_fraction"] >=
            V91_PREREGISTERED_GATES["minimum_unique_isomorphism_fraction"],
        "type_validity" => fractions["type_valid_fraction"] >=
            V91_PREREGISTERED_GATES["minimum_type_valid_fraction"],
        "solver_compile_coverage" => fractions["solver_compile_fraction"] >=
            V91_PREREGISTERED_GATES["minimum_solver_compile_fraction"],
        "solver_execution_coverage" => fractions["solver_execution_fraction"] >=
            V91_PREREGISTERED_GATES["minimum_solver_execution_fraction"],
        "all_structural_genes_consumed" => fractions["gene_consumption_fraction"] >=
            V91_PREREGISTERED_GATES["minimum_gene_consumption_fraction"],
        "all_basis_coefficients_consumed" => fractions["basis_consumption_fraction"] >=
            V91_PREREGISTERED_GATES["minimum_basis_consumption_fraction"],
        "capability_cell_breadth" => length(cells) >=
            V91_PREREGISTERED_GATES["minimum_capability_cells"],
        "canonical_relabel_invariance" => all(item ->
            item["canonical_invariant"] === true, relabel_checks),
        "isomorphism_controls" => all(values(duplicate_control)),
        "recovery" => get(recovery, "status", "missing") == "pass",
        "deterministic_replay" => length(replay_checks) == length(sample_targets) &&
            all(item -> item["record_hash_match"] === true, replay_checks),
        "evidence_firewall" => firewall <=
            V91_PREREGISTERED_GATES["maximum_evidence_firewall_violations"],
        "label_invariant_routing" => routing == 0)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "campaign_id" => campaign["campaign_id"],
        "tier" => campaign["tier"], "status" => all(values(gates)) ? "pass" : "fail",
        "qualification_gates" => gates, "campaign_hash" => campaign["campaign_hash"],
        "preregistered_gate_hash" => campaign["preregistered_gate_hash"],
        "result_count" => result_count, "raw_topology_requests" => total,
        "unique_nonisomorphic_topologies" => length(iso_hashes),
        "unique_solver_inputs" => length(solver_hashes),
        "capability_cell_count" => length(cells),
        "capability_cells" => cells, "fractions" => fractions,
        "hard_gate_survivor_count" => length(hard_survivors),
        "hard_gate_survivor_indices" => hard_survivors,
        "family_name_parent_routing_count" => routing,
        "evidence_firewall_violation_count" => firewall,
        "canonical_relabel_checks" => relabel_checks,
        "deterministic_replay_checks" => replay_checks,
        "isomorphism_controls" => duplicate_control,
        "recovery_drill" => recovery, "shard_ranges" => batch_ranges,
        "no_gap_or_overlap" => expected_index == total + 1,
        "extrapolation_used" => false,
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V91_CLAIM_BOUNDARY)
    body["merge_hash"] = canonical_hash(body)
    _v91_atomic_json(joinpath(root, "campaign_v91_merged.json"), body); body
end
