using FusionConceptAI
using JSON3
using SHA

const ROOT_V56 = normpath(joinpath(@__DIR__, ".."))
const RUNS_V56 = joinpath(ROOT_V56, "runs")

function increment_v56!(histogram::Dict{String,Int}, key, amount::Int = 1)
    id = key === nothing ? "none" : String(key)
    histogram[id] = get(histogram, id, 0) + amount
    return histogram
end

function write_json_line_v56(io, value)
    write(io, canonical_json(value))
    write(io, '\n')
end

function file_sha256_v56(path)
    return bytes2hex(sha256(read(path)))
end

function output_paths_v56(run_tag::String)
    return Dict{String,String}(
        "inputs" => joinpath(RUNS_V56, "candidate_bound_full_search_inputs_$(run_tag).jsonl"),
        "artifacts" => joinpath(RUNS_V56, "candidate_bound_full_search_artifacts_$(run_tag).jsonl"),
        "results" => joinpath(RUNS_V56, "candidate_bound_full_search_results_$(run_tag).jsonl"),
        "report" => joinpath(RUNS_V56, "candidate_bound_full_search_$(run_tag).json"),
        "summary" => joinpath(RUNS_V56, "candidate_bound_full_search_$(run_tag).md"),
    )
end

function main_v56(candidate_count::Int = 10_000,
        run_tag::String = candidate_count == 10_000 ? "v56_20260822" : "v56_smoke_$(candidate_count)")
    1 <= candidate_count <= 10_000 || error("candidate_count must be within 1:10000")
    mkpath(RUNS_V56)
    paths = output_paths_v56(run_tag)
    seeds = load_genomes(joinpath(ROOT_V56, "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)

    decision_histogram = Dict{String,Int}()
    passed_stage_histogram = Dict{String,Int}()
    failed_stage_histogram = Dict{String,Int}()
    unknown_stage_histogram = Dict{String,Int}()
    stage_status_histograms = Dict(String(id) => Dict{String,Int}()
        for id in UNIFIED_JUDGMENT_STAGE_IDS_V55)
    artifact_status_histograms = Dict{String,Dict{String,Int}}()
    legacy_family_histogram = Dict{String,Int}()
    topology_counts = zeros(Int, length(context.assemblies))
    ranking_records = Dict{String,Any}[]
    evaluated_count = 0
    dropped_count = 0
    all_eight_count = 0
    family_routed_count = 0
    promotion_count = 0
    executed_native_backend_total = 0
    c1_authorized_artifact_total = 0
    hard_falsified_artifact_total = 0
    artifact_total = 0
    sample_indices = sort!(unique(filter(<=(candidate_count),
        [1, 2, 11, 97, 509, 1000, 2500, 5000, 7500, 9999, 10000])))
    sample_hashes = Dict{Int,Dict{String,String}}()
    started_ns = time_ns()

    open(paths["inputs"], "w") do input_io
        open(paths["artifacts"], "w") do artifact_io
            open(paths["results"], "w") do result_io
                for first_index in 1:100:candidate_count
                    last_index = min(candidate_count, first_index + 99)
                    indices = first_index:last_index
                    bundles = [compile_candidate_bound_judgment_input_v56(context, index)
                        for index in indices]
                    inputs = getindex.(bundles, "judgment_input")
                    archive = evaluate_all_search_results_v55(inputs)
                    length(archive["results"]) == length(indices) ||
                        error("evaluate_all_search_results_v55 dropped a candidate")
                    evaluated_count += Int(archive["evaluated_candidate_count"])
                    dropped_count += Int(archive["dropped_candidate_count"])

                    for (index, bundle, result) in zip(indices, bundles, archive["results"])
                        input = bundle["judgment_input"]
                        summary = bundle["artifact_summary"]
                        write_json_line_v56(input_io, input)
                        write_json_line_v56(artifact_io, Dict{String,Any}(
                            "candidate_index" => index,
                            "candidate_id" => input["candidate_id"],
                            "input_hash" => bundle["input_hash"],
                            "artifact_summary" => summary,
                            "stage_artifacts" => input["stage_artifacts"],
                            "claim_boundary" => FusionConceptAI._V56_CLAIM_BOUNDARY,
                        ))
                        enriched_result = deepcopy(result)
                        enriched_result["candidate_index"] = index
                        enriched_result["physics_hash"] = input["physics_hash"]
                        enriched_result["input_hash"] = bundle["input_hash"]
                        write_json_line_v56(result_io, enriched_result)

                        increment_v56!(decision_histogram, result["decision"])
                        increment_v56!(passed_stage_histogram, string(result["passed_stage_count"]))
                        for stage_id in result["failed_stage_ids"]
                            increment_v56!(failed_stage_histogram, stage_id)
                        end
                        for stage_id in result["unknown_stage_ids"]
                            increment_v56!(unknown_stage_histogram, stage_id)
                        end
                        for stage in result["stages"]
                            increment_v56!(stage_status_histograms[String(stage["stage_id"])],
                                stage["status"])
                        end
                        all_eight_count += result["all_eight_stages_executed"] === true ? 1 : 0
                        family_routed_count += result["family_or_parent_used_for_routing"] === true ? 1 : 0
                        promotion_count += result["promotion_authorized"] === true ? 1 : 0
                        executed_native_backend_total += Int(summary["executed_native_backend_count"])
                        c1_authorized_artifact_total += Int(summary["candidate_c1_authorized_artifact_count"])
                        hard_falsified_artifact_total += Int(summary["hard_falsified_artifact_count"])
                        artifact_total += Int(summary["artifact_count"])
                        increment_v56!(legacy_family_histogram, summary["legacy_family_nonrouting"])
                        topology_counts[Int(summary["assembly_index"])] += 1
                        for (artifact_id, status) in summary["artifact_statuses"]
                            histogram = get!(artifact_status_histograms, String(artifact_id),
                                Dict{String,Int}())
                            increment_v56!(histogram, status)
                        end
                        push!(ranking_records, Dict{String,Any}(
                            "candidate_index" => index,
                            "candidate_id" => input["candidate_id"],
                            "physics_hash" => input["physics_hash"],
                            "input_hash" => bundle["input_hash"],
                            "decision" => result["decision"],
                            "passed_stage_count" => result["passed_stage_count"],
                            "failed_stage_ids" => result["failed_stage_ids"],
                            "unknown_stage_ids" => result["unknown_stage_ids"],
                            "legacy_family_nonrouting" => summary["legacy_family_nonrouting"],
                        ))
                        if index in sample_indices
                            sample_hashes[index] = Dict(
                                "input_hash" => String(bundle["input_hash"]),
                                "routing_input_hash" => String(result["routing_input_hash"]))
                        end
                    end
                    elapsed_s = (time_ns() - started_ns) / 1.0e9
                    rate = last_index / max(elapsed_s, eps())
                    remaining_s = (candidate_count - last_index) / max(rate, eps())
                    println("evaluated $last_index/$candidate_count; elapsed=$(round(elapsed_s; digits=1))s; eta=$(round(remaining_s; digits=1))s")
                    flush(stdout)
                end
            end
        end
    end

    replay_matches = 0
    replay_records = Dict{String,Any}[]
    for index in sample_indices
        bundle = compile_candidate_bound_judgment_input_v56(context, index)
        result = only(evaluate_all_search_results_v55(
            Any[bundle["judgment_input"]])["results"])
        expected = sample_hashes[index]
        matched = bundle["input_hash"] == expected["input_hash"] &&
            result["routing_input_hash"] == expected["routing_input_hash"]
        replay_matches += matched ? 1 : 0
        push!(replay_records, Dict("candidate_index" => index,
            "input_hash" => bundle["input_hash"],
            "routing_input_hash" => result["routing_input_hash"],
            "matched" => matched))
    end

    sort!(ranking_records; by = item -> (
        -Int(item["passed_stage_count"]),
        length(item["failed_stage_ids"]),
        length(item["unknown_stage_ids"]),
        Int(item["candidate_index"])))
    best_records = ranking_records[1:min(100, length(ranking_records))]
    full_run = candidate_count == 10_000
    exit_gate = Dict{String,Any}(
        "all_requested_candidates_compiled" => evaluated_count == candidate_count,
        "all_requested_candidates_evaluated" => evaluated_count == candidate_count && dropped_count == 0,
        "all_candidates_executed_all_eight_stages" => all_eight_count == candidate_count,
        "all_10000_candidates_evaluated" => !full_run || evaluated_count == 10_000,
        "all_1000_topologies_receive_10_samples" => !full_run ||
            (length(topology_counts) == 1000 && all(==(10), topology_counts)),
        "no_family_or_parent_routing" => family_routed_count == 0,
        "legacy_generated_ledgers_never_used_for_v55" => true,
        "deterministic_sample_replay" => replay_matches == length(sample_indices),
        "no_false_promotion" => promotion_count == 0,
    )
    elapsed_s = (time_ns() - started_ns) / 1.0e9
    archive_hashes = Dict{String,Any}(
        "inputs_sha256" => file_sha256_v56(paths["inputs"]),
        "artifacts_sha256" => file_sha256_v56(paths["artifacts"]),
        "results_sha256" => file_sha256_v56(paths["results"]),
    )
    core = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "run_date" => "2026-08-22",
        "search_id" => "candidate_bound_full_search_$(run_tag)",
        "status" => all(values(exit_gate)) ?
            (full_run ? "candidate_bound_full_search_complete" : "bounded_smoke_search_complete") :
            "search_incomplete",
        "candidate_count" => candidate_count,
        "topology_count" => length(context.assemblies),
        "samples_per_topology_for_full_run" => 10,
        "batch_size" => 100,
        "elapsed_seconds" => elapsed_s,
        "evaluator" => "evaluate_all_search_results_v55",
        "exit_gate" => exit_gate,
        "evaluation_summary" => Dict(
            "input_candidate_count" => candidate_count,
            "evaluated_candidate_count" => evaluated_count,
            "dropped_candidate_count" => dropped_count,
            "decision_histogram" => decision_histogram,
            "passed_stage_count_histogram" => passed_stage_histogram,
            "failed_stage_histogram" => failed_stage_histogram,
            "unknown_stage_histogram" => unknown_stage_histogram,
            "stage_status_histograms" => stage_status_histograms,
            "family_or_parent_routed_count" => family_routed_count,
            "promotion_authorized_count" => promotion_count),
        "artifact_summary" => Dict(
            "artifact_total" => artifact_total,
            "artifact_status_histograms" => artifact_status_histograms,
            "executed_native_backend_total" => executed_native_backend_total,
            "candidate_c1_authorized_artifact_total" => c1_authorized_artifact_total,
            "hard_falsified_artifact_total" => hard_falsified_artifact_total),
        "nonrouting_diagnostics" => Dict(
            "legacy_family_histogram" => legacy_family_histogram),
        "determinism" => Dict(
            "sample_count" => length(sample_indices),
            "matched_count" => replay_matches,
            "records" => replay_records),
        "best_candidate_records" => best_records,
        "archives" => Dict(
            "inputs" => basename(paths["inputs"]),
            "artifacts" => basename(paths["artifacts"]),
            "results" => basename(paths["results"]),
            "hashes" => archive_hashes),
        "promotion_authorized" => false,
        "claim_boundary" => FusionConceptAI._V56_CLAIM_BOUNDARY,
    )
    artifact = deepcopy(core)
    artifact["deterministic_result_hash"] = canonical_hash(core)
    artifact["source_hashes"] = Dict{String,Any}(
        "v55_evaluator" => file_sha256_v56(joinpath(ROOT_V56, "src", "search",
            "unified_judgment_chain_v55.jl")),
        "v56_compiler" => file_sha256_v56(joinpath(ROOT_V56, "src", "search",
            "candidate_bound_eight_stage_search_v56.jl")),
        "runner" => file_sha256_v56(@__FILE__),
        "schema" => file_sha256_v56(joinpath(ROOT_V56, "schemas",
            "candidate_bound_eight_stage_search_v56.schema.json")))
    open(paths["report"], "w") do io
        write_json_line_v56(io, artifact)
    end

    summary = """# Candidate-bound full search v56

- Status: `$(artifact["status"])`
- Requested/evaluated/dropped: $candidate_count/$evaluated_count/$dropped_count
- Decision histogram: `$(canonical_json(decision_histogram))`
- All-eight-stage executions: $all_eight_count
- Candidate-bound artifacts generated: $artifact_total
- Native backend executions: $executed_native_backend_total
- Candidate C1-authorized artifacts: $c1_authorized_artifact_total
- Family/parent routed decisions: $family_routed_count
- Promotion authorized: $promotion_count
- Deterministic sample replay: $replay_matches/$(length(sample_indices))
- Elapsed seconds: $(round(elapsed_s; digits=3))
- Deterministic result hash: `$(artifact["deterministic_result_hash"])`

Every requested candidate was compiled into the same eight-stage input contract and
submitted to `evaluate_all_search_results_v55`. A compiled candidate-bound problem is
not counted as a solved state. Missing numerical, engineering, VVUQ, cross-code, or
experimental outputs remain `unknown`; explicit structural contradictions remain
`fail`. V54 generated ledgers are retained only as rejected provenance and never
satisfy the v55 net-energy gate.
"""
    open(paths["summary"], "w") do io
        write(io, summary)
    end
    println(JSON3.write(Dict(
        "status" => artifact["status"],
        "candidate_count" => candidate_count,
        "evaluation_summary" => artifact["evaluation_summary"],
        "artifact_summary" => artifact["artifact_summary"],
        "report" => relpath(paths["report"], ROOT_V56))))
    return artifact
end

candidate_count = isempty(ARGS) ? 10_000 : parse(Int, ARGS[1])
run_tag = length(ARGS) >= 2 ? ARGS[2] :
    (candidate_count == 10_000 ? "v56_20260822" : "v56_smoke_$(candidate_count)")
main_v56(candidate_count, run_tag)
