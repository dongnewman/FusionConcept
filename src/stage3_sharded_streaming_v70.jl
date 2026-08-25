const STAGE3_STREAMING_V70_CLAIM_BOUNDARY =
    "This run exhaustively compiles graph-native structures over the declared seed range and executes bounded generic balance probes for one representative per QD cell. It is Stage-3 computational evidence only; it does not establish a realizable device, fusion gain, engineering closure, or promotion authorization."

function _s70_topology_to_dict(topology::GraphNativeTopologyV69)
    return Dict{String,Any}(
        "schema_version" => topology.schema_version,
        "regions" => topology.regions,
        "interfaces" => topology.interfaces,
        "ports" => topology.ports,
        "dependencies" => topology.dependencies,
        "symmetry" => topology.symmetry,
        "obligations" => topology.obligations,
        "topology_hash" => topology.topology_hash,
    )
end

function _s70_file_sha256(path::AbstractString)
    return open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end
end

function _s70_json_line(io, value)
    write(io, canonical_json(value)); write(io, '\n')
end

function _s70_read_json_lines(path::AbstractString)
    rows = Dict{String,Any}[]
    isfile(path) || return rows
    open(path, "r") do io
        for line in eachline(io)
            isempty(strip(line)) && continue
            push!(rows, _stage3_plain_v1(JSON3.read(line, Dict{String,Any})))
        end
    end
    return rows
end

function _s70_repair_partial(path::AbstractString)
    isfile(path) || return Dict{String,Any}[]
    rows = Dict{String,Any}[]; valid_lines = String[]; damaged = false
    open(path, "r") do io
        for line in eachline(io)
            isempty(strip(line)) && continue
            try
                push!(rows, _stage3_plain_v1(JSON3.read(line, Dict{String,Any})))
                push!(valid_lines, line)
            catch
                damaged = true
                break
            end
        end
    end
    if damaged
        temporary = path * ".repair"
        open(temporary, "w") do io
            foreach(line -> (write(io, line); write(io, '\n')), valid_lines)
        end
        mv(temporary, path; force = true)
    end
    return rows
end

function _s70_structure_score(topology::GraphNativeTopologyV69,
        plan::Stage3ExecutionPlanV1)
    ir = plan.numerical_ir
    return Dict{String,Int}(
        "region_count" => length(topology.regions),
        "interface_count" => length(topology.interfaces),
        "port_count" => length(topology.ports),
        "dependency_count" => length(topology.dependencies),
        "obligation_count" => length(topology.obligations),
        "state_count" => ir === nothing ? 0 : length(ir.states),
        "operator_count" => ir === nothing ? 0 : length(ir.operators),
        "boundary_operator_count" => ir === nothing ? 0 : length(ir.boundaries),
        "interface_flux_count" => ir === nothing ? 0 : length(ir.interfaces),
    )
end

_s70_richness(score::AbstractDict) = sum(Int(value) for value in values(score))

function _s70_candidate(seed::Int, topology::GraphNativeTopologyV69,
        compilation::GraphTopologyCompilationV69,
        budget::Stage3ExecutionBudgetV1)
    binding = Dict{String,Any}("execution_model" => Dict{String,Any}(
        "kind" => "generic_graph_balance"))
    request = compile_stage3_execution_request_v1(topology, compilation;
        parameter_binding = binding,
        sample_spec = Dict{String,Any}("required_sample_count" => 1,
            "dimension" => 2, "sequence" => "halton_v1"), budget = budget)
    plan = compile_stage3_execution_plan_v1(request)
    qd = _stage3_qd_coordinates_v1(plan)
    qd_hash = _stage3_persisted_hash_v1(qd)
    score = _s70_structure_score(topology, plan)
    return (seed = seed, topology = topology, compilation = compilation,
        request = request, plan = plan, qd = qd, qd_hash = qd_hash, score = score)
end

function _s70_structural_record(shard_id::Int, seed::Int,
        compilation::GraphTopologyCompilationV69, candidate, is_unique::Bool)
    qd = candidate === nothing ? Dict{String,Any}() : candidate.qd
    plan = candidate === nothing ? nothing : candidate.plan
    score = candidate === nothing ? Dict{String,Int}() : candidate.score
    payload = Dict{String,Any}(
        "structure_hash" => compilation.isomorphism_hash,
        "compilation_status" => String(compilation.status),
        "classification_code" => compilation.classification_code,
        "plan_completeness" => plan === nothing ? "not_compiled" : String(plan.completeness),
        "plan_conclusion" => plan === nothing ? "not_compiled" : String(plan.conclusion),
        "plan_classification_code" => plan === nothing ? "" : plan.classification_code,
        "solve_plan_hash" => plan === nothing ? nothing : plan.solve_plan_hash,
        "numerical_ir_hash" => plan === nothing ? nothing : plan.numerical_ir_hash,
        "qd_coordinates" => qd,
        "qd_cell_hash" => isempty(qd) ? nothing : _stage3_persisted_hash_v1(qd),
        "structure_score" => score,
    )
    return merge(Dict{String,Any}(
        "schema_version" => "1.0.0",
        "shard_id" => shard_id,
        "seed" => seed,
        "is_unique_within_shard" => is_unique,
        "payload_hash" => _stage3_persisted_hash_v1(payload),
    ), payload)
end

function _s70_update_representative!(representatives::Dict{String,Any}, candidate)
    candidate.plan.completeness == :complete || return
    old = get(representatives, candidate.qd_hash, nothing)
    if old === nothing || (_s70_richness(candidate.score), -candidate.seed) >
            (_s70_richness(old.score), -old.seed)
        representatives[candidate.qd_hash] = candidate
    end
end

function _s70_rebuild_prefix!(representatives::Dict{String,Any},
        first_seed::Int, last_seed::Int, budget::Stage3ExecutionBudgetV1)
    first_seed > last_seed && return
    for seed in first_seed:last_seed
        topology = generate_graph_native_topology_v69(seed)
        compilation = compile_graph_native_topology_candidate_v69(topology)
        compilation.status == :pass || continue
        candidate = _s70_candidate(seed, topology, compilation, budget)
        _s70_update_representative!(representatives, candidate)
    end
end

function _s70_evidence_row(shard_id::Int, candidate, evidence,
        evidence_path::AbstractString, output_directory::AbstractString)
    residual = get(evidence.residual_conservation_evidence,
        "maximum_conservation_residual", nothing)
    artifact_ref = replace(relpath(evidence_path, output_directory), '\\' => '/')
    record = stage3_candidate_record_v1(candidate.plan, evidence;
        evidence_artifact_ref = artifact_ref)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "shard_id" => shard_id,
        "seed" => candidate.seed,
        "structure_hash" => candidate.compilation.isomorphism_hash,
        "topology_hash" => candidate.topology.topology_hash,
        "solve_plan_hash" => candidate.plan.solve_plan_hash,
        "numerical_ir_hash" => candidate.plan.numerical_ir_hash,
        "evidence_hash" => evidence.evidence_hash,
        "evidence_artifact_ref" => artifact_ref,
        "completeness" => String(evidence.completeness),
        "conclusion" => String(evidence.conclusion),
        "classification_code" => evidence.classification_code,
        "independent_audit_status" => get(evidence.independent_recomputation_evidence,
            "status", "unknown"),
        "resolution_status" => get(evidence.convergence_evidence,
            "resolution_status", "incomplete"),
        "completed_sample_count" => get(evidence.execution_cost_record,
            "completed_sample_count", 0),
        "required_sample_count" => get(evidence.execution_cost_record,
            "required_sample_count", 0),
        "maximum_conservation_residual" => residual,
        "wall_seconds" => get(evidence.execution_cost_record, "wall_seconds", 0.0),
        "qd_coordinates" => candidate.qd,
        "qd_cell_hash" => candidate.qd_hash,
        "structure_score" => candidate.score,
        "topology" => _s70_topology_to_dict(candidate.topology),
        "candidate_record" => record,
    )
    deterministic = Dict{String,Any}(key => value for (key, value) in body
        if key != "wall_seconds")
    body["row_hash"] = _stage3_persisted_hash_v1(deterministic)
    return body
end

"""Execute one bounded-memory v70 shard and stream one structural row per seed."""
function run_stage3_streaming_shard_v70(shard_id::Integer,
        first_seed::Integer, last_seed::Integer;
        output_directory::AbstractString,
        numerical_per_shard::Integer = 100,
        checkpoint_interval::Integer = 250,
        resume::Bool = true,
        stop_after_seeds::Union{Nothing,Integer} = nothing,
        budget::Stage3ExecutionBudgetV1 = Stage3ExecutionBudgetV1(
            maximum_wall_seconds = 20.0, resolution_levels = [8, 16, 32]))
    shard_id > 0 || throw(ArgumentError("shard_id must be positive"))
    1 <= first_seed <= last_seed || throw(ArgumentError("invalid seed range"))
    numerical_per_shard >= 0 || throw(ArgumentError("numerical_per_shard must be non-negative"))
    checkpoint_interval > 0 || throw(ArgumentError("checkpoint_interval must be positive"))
    mkpath(output_directory)
    prefix = "stage3_v70_shard_$(lpad(shard_id, 2, '0'))"
    partial_path = joinpath(output_directory, prefix * ".structures.jsonl.partial")
    structure_path = joinpath(output_directory, prefix * ".structures.jsonl")
    evidence_path = joinpath(output_directory, prefix * ".evidence.jsonl")
    summary_path = joinpath(output_directory, prefix * ".summary.json")
    if isfile(summary_path) && isfile(structure_path) && isfile(evidence_path)
        return _stage3_plain_v1(JSON3.read(read(summary_path, String), Dict{String,Any}))
    end
    if !resume
        isfile(partial_path) && rm(partial_path; force = true)
    end
    previous = resume ? _s70_repair_partial(partial_path) : Dict{String,Any}[]
    processed = length(previous)
    processed <= last_seed - first_seed + 1 || throw(ArgumentError(
        "partial shard contains too many records"))
    if processed > 0
        expected = collect(first_seed:first_seed + processed - 1)
        Int.(getindex.(previous, "seed")) == expected || throw(ArgumentError(
            "partial shard seed sequence is not contiguous"))
    end
    representatives = Dict{String,Any}()
    _s70_rebuild_prefix!(representatives, first_seed,
        first_seed + processed - 1, budget)
    seen = Set{String}(String(row["structure_hash"]) for row in previous)
    status_counts = Dict{String,Int}()
    for row in previous
        status = String(row["compilation_status"])
        status_counts[status] = get(status_counts, status, 0) + 1
    end
    start_time = time(); added = 0; uncaught = 0; interrupted = false
    open(partial_path, processed == 0 ? "w" : "a") do io
        for seed in (first_seed + processed):last_seed
            candidate = nothing
            try
                topology = generate_graph_native_topology_v69(seed)
                compilation = compile_graph_native_topology_candidate_v69(topology)
                unique_here = !(compilation.isomorphism_hash in seen)
                push!(seen, compilation.isomorphism_hash)
                if compilation.status == :pass
                    candidate = _s70_candidate(seed, topology, compilation, budget)
                    _s70_update_representative!(representatives, candidate)
                end
                row = _s70_structural_record(Int(shard_id), seed, compilation,
                    candidate, unique_here)
                _s70_json_line(io, row)
                status = String(compilation.status)
                status_counts[status] = get(status_counts, status, 0) + 1
            catch error
                uncaught += 1
                row = Dict{String,Any}("schema_version" => "1.0.0",
                    "shard_id" => Int(shard_id), "seed" => seed,
                    "structure_hash" => "exception://$seed",
                    "compilation_status" => "exception",
                    "classification_code" => "uncaught_$(nameof(typeof(error)))",
                    "payload_hash" => _stage3_persisted_hash_v1(Dict(
                        "seed" => seed, "error_type" => String(nameof(typeof(error))))) )
                _s70_json_line(io, row)
                status_counts["exception"] = get(status_counts, "exception", 0) + 1
            end
            added += 1
            if added % checkpoint_interval == 0
                flush(io)
            end
            if stop_after_seeds !== nothing && added >= stop_after_seeds
                flush(io)
                interrupted = true
                break
            end
        end
        flush(io)
    end
    if interrupted
        return Dict{String,Any}("status" => "interrupted",
            "shard_id" => Int(shard_id), "processed_count" => processed + added,
            "partial_path" => partial_path,
            "claim_boundary" => STAGE3_STREAMING_V70_CLAIM_BOUNDARY)
    end
    mv(partial_path, structure_path; force = true)
    selected = sort!(collect(values(representatives)); by = item ->
        (-_s70_richness(item.score), item.qd_hash, item.seed))
    length(selected) > numerical_per_shard && resize!(selected, numerical_per_shard)
    evidence_rows = Dict{String,Any}[]
    evidence_root = joinpath(output_directory, "evidence_objects")
    open(evidence_path * ".partial", "w") do io
        for candidate in selected
            evidence = execute_stage3_plan_v1(candidate.plan, candidate.request)
            object_path = joinpath(evidence_root, evidence.evidence_hash[1:2],
                evidence.evidence_hash * ".json")
            isfile(object_path) || _stage3_atomic_json_v1(object_path,
                stage3_evidence_envelope_to_dict_v1(evidence))
            row = _s70_evidence_row(Int(shard_id), candidate, evidence,
                object_path, output_directory)
            push!(evidence_rows, row); _s70_json_line(io, row); flush(io)
        end
    end
    mv(evidence_path * ".partial", evidence_path; force = true)
    summary = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "status" => "complete",
        "shard_id" => Int(shard_id),
        "first_seed" => Int(first_seed),
        "last_seed" => Int(last_seed),
        "raw_seed_count" => Int(last_seed - first_seed + 1),
        "unique_structure_count" => length(seen),
        "compilation_status_counts" => status_counts,
        "uncaught_exception_count" => uncaught,
        "qd_representative_count" => length(representatives),
        "numerical_evidence_count" => length(evidence_rows),
        "complete_pass_evidence_count" => count(row ->
            row["completeness"] == "complete" && row["conclusion"] == "pass",
            evidence_rows),
        "structures_sha256" => _s70_file_sha256(structure_path),
        "evidence_sha256" => _s70_file_sha256(evidence_path),
        "elapsed_seconds" => time() - start_time,
        "claim_boundary" => STAGE3_STREAMING_V70_CLAIM_BOUNDARY,
    )
    deterministic = Dict{String,Any}(key => value for (key, value) in summary
        if key != "elapsed_seconds")
    summary["shard_result_hash"] = _stage3_persisted_hash_v1(deterministic)
    _stage3_atomic_json_v1(summary_path, summary)
    return summary
end

function _s70_winner_rank(row::AbstractDict)
    completed = Int(get(row, "completed_sample_count", 0))
    required = max(1, Int(get(row, "required_sample_count", 0)))
    residual_raw = get(row, "maximum_conservation_residual", nothing)
    residual = residual_raw === nothing ? Inf : Float64(residual_raw)
    richness = _s70_richness(get(row, "structure_score", Dict{String,Any}()))
    return (get(row, "completeness", "incomplete") == "complete" ? 0 : 1,
        get(row, "conclusion", "unknown") == "pass" ? 0 : 1,
        get(row, "independent_audit_status", "unknown") == "pass" ? 0 : 1,
        get(row, "resolution_status", "incomplete") == "complete" ? 0 : 1,
        -completed / required, residual, -richness,
        String(get(row, "structure_hash", "")), String(get(row, "evidence_hash", "")))
end

"""Merge completed shard streams by isomorphism hash and evidence hash."""
function merge_stage3_streaming_shards_v70(output_directory::AbstractString;
        shard_ids = collect(1:10), expected_raw_count::Integer = 100_000,
        expected_shard_size::Integer = 10_000)
    summaries = Dict{String,Any}[]
    structure_paths = String[]; evidence_paths = String[]
    for shard_id in shard_ids
        prefix = "stage3_v70_shard_$(lpad(shard_id, 2, '0'))"
        summary_path = joinpath(output_directory, prefix * ".summary.json")
        isfile(summary_path) || throw(ArgumentError("missing shard summary: $summary_path"))
        summary = _stage3_plain_v1(JSON3.read(read(summary_path, String), Dict{String,Any}))
        summary["status"] == "complete" || throw(ArgumentError("shard $shard_id incomplete"))
        structure_path = joinpath(output_directory, prefix * ".structures.jsonl")
        evidence_path = joinpath(output_directory, prefix * ".evidence.jsonl")
        _s70_file_sha256(structure_path) == summary["structures_sha256"] ||
            throw(ArgumentError("shard $shard_id structure hash mismatch"))
        _s70_file_sha256(evidence_path) == summary["evidence_sha256"] ||
            throw(ArgumentError("shard $shard_id evidence hash mismatch"))
        push!(summaries, summary); push!(structure_paths, structure_path)
        push!(evidence_paths, evidence_path)
    end
    merged_structures = joinpath(output_directory,
        "stage3_v70_100000_structures_merged.jsonl")
    merged_evidence = joinpath(output_directory,
        "stage3_v70_100000_evidence_merged.jsonl")
    structure_payloads = Dict{String,String}(); raw_count = 0; duplicate_count = 0
    open(merged_structures * ".partial", "w") do out
        for path in structure_paths
            open(path, "r") do io
                for line in eachline(io)
                    isempty(strip(line)) && continue
                    row = _stage3_plain_v1(JSON3.read(line, Dict{String,Any})); raw_count += 1
                    structure_hash = String(row["structure_hash"])
                    payload_hash = String(row["payload_hash"])
                    if haskey(structure_payloads, structure_hash)
                        structure_payloads[structure_hash] == payload_hash ||
                            throw(ArgumentError("structure payload conflict for $structure_hash"))
                        duplicate_count += 1
                    else
                        structure_payloads[structure_hash] = payload_hash
                        _s70_json_line(out, row)
                    end
                end
            end
        end
    end
    mv(merged_structures * ".partial", merged_structures; force = true)
    evidence_hashes = Set{String}(); structure_evidence = Dict{String,Set{String}}()
    evidence_rows = Dict{String,Any}[]; evidence_duplicate_count = 0
    open(merged_evidence * ".partial", "w") do out
        for path in evidence_paths
            open(path, "r") do io
                for line in eachline(io)
                    isempty(strip(line)) && continue
                    row = _stage3_plain_v1(JSON3.read(line, Dict{String,Any}))
                    evidence_hash = String(row["evidence_hash"])
                    structure_hash = String(row["structure_hash"])
                    if evidence_hash in evidence_hashes
                        evidence_duplicate_count += 1; continue
                    end
                    push!(evidence_hashes, evidence_hash)
                    push!(get!(structure_evidence, structure_hash, Set{String}()), evidence_hash)
                    push!(evidence_rows, row); _s70_json_line(out, row)
                end
            end
        end
    end
    mv(merged_evidence * ".partial", merged_evidence; force = true)
    isempty(evidence_rows) && throw(ArgumentError("merged evidence is empty"))
    sort!(evidence_rows; by = _s70_winner_rank)
    winner = first(evidence_rows)
    first_seeds = Int[summary["first_seed"] for summary in summaries]
    last_seeds = Int[summary["last_seed"] for summary in summaries]
    contiguous = first_seeds == [1 + (index - 1) * expected_shard_size
        for index in eachindex(shard_ids)] &&
        last_seeds == [index * expected_shard_size for index in eachindex(shard_ids)]
    exit_gate = Dict{String,Bool}(
        "ten_shards_complete" => length(summaries) == 10,
        "ten_by_ten_thousand_ranges_contiguous" => contiguous,
        "raw_candidate_count_exact" => raw_count == expected_raw_count,
        "all_uncaught_exception_counts_zero" => all(summary ->
            Int(summary["uncaught_exception_count"]) == 0, summaries),
        "structure_hash_merge_complete" => raw_count == length(structure_payloads) + duplicate_count,
        "evidence_hash_merge_complete" => !isempty(evidence_hashes),
        "winner_has_complete_pass_evidence" => winner["completeness"] == "complete" &&
            winner["conclusion"] == "pass",
        "winner_independent_audit_pass" => winner["independent_audit_status"] == "pass",
    )
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "status" => all(values(exit_gate)) ? "accepted" : "rejected",
        "worker_count" => 4,
        "shard_count" => length(summaries),
        "raw_candidate_count" => raw_count,
        "unique_structure_count" => length(structure_payloads),
        "duplicate_structure_count" => duplicate_count,
        "unique_evidence_count" => length(evidence_hashes),
        "duplicate_evidence_count" => evidence_duplicate_count,
        "complete_pass_evidence_count" => count(row ->
            row["completeness"] == "complete" && row["conclusion"] == "pass",
            evidence_rows),
        "qd_cell_count" => length(unique(String(row["qd_cell_hash"])
            for row in evidence_rows)),
        "structures_sha256" => _s70_file_sha256(merged_structures),
        "evidence_sha256" => _s70_file_sha256(merged_evidence),
        "shard_result_hashes" => Dict(string(summary["shard_id"]) =>
            summary["shard_result_hash"] for summary in summaries),
        "winner_selection" => Dict{String,Any}(
            "method" => "lexicographic_evidence_then_residual_then_structural_richness_v1",
            "scalar_proxy_score_used" => false,
            "winner" => winner),
        "exit_gate" => exit_gate,
        "label_or_device_family_routing_used" => false,
        "claim_boundary" => STAGE3_STREAMING_V70_CLAIM_BOUNDARY,
    )
    artifact["result_hash"] = _stage3_persisted_hash_v1(artifact)
    artifact_path = joinpath(output_directory,
        "stage3_v70_100000_merged_acceptance.json")
    _stage3_atomic_json_v1(artifact_path, artifact)
    all(values(exit_gate)) || throw(ArgumentError("merged v70 exit gate failed"))
    return artifact
end
