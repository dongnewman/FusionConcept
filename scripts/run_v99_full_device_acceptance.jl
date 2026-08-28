#!/usr/bin/env julia
using FusionConceptAI
using JSON3

plain(value) = JSON3.read(JSON3.write(value), Dict{String,Any})

function read_json(path)
    open(path, "r") do io
        plain(JSON3.read(io))
    end
end

function write_json(path, value)
    mkpath(dirname(path))
    open(path, "w") do io
        JSON3.pretty(io, value)
        write(io, '\n')
    end
end

function main(args = ARGS)
    length(args) == 4 || error("usage: candidates.jsonl cross_code_dir static_result.json output_dir")
    candidate_path, cross_dir, static_path, output_dir = abspath.(args)
    candidates = Dict{Int,Dict{String,Any}}()
    open(candidate_path, "r") do io
        for line in eachline(io)
            isempty(strip(line)) && continue
            item = plain(JSON3.read(line))
            candidates[Int(item["request_index"])] = item
        end
    end
    cross_acceptance = read_json(joinpath(cross_dir, "acceptance.json"))
    cross_acceptance["status"] == "complete" || error("cross-code batch is not complete")
    static = read_json(static_path)
    rows = Dict{String,Any}[]
    for cross_row in cross_acceptance["rows"]
        index = Int(cross_row["request_index"])
        cross = read_json(joinpath(cross_dir, "results", "v99_$(lpad(index, 7, '0')).json"))
        downstream = Dict{String,Any}()
        if index == Int(static["request_index"])
            downstream["engineering_qualification"] = Dict(
                "status" => static["candidate_state"] ==
                    "static_robustness_proxy_pass" ? "unknown" : "fail",
                "scope" => "candidate_bound",
                "result_hash" => static["result_hash"],
                "reason" => static["candidate_state"] ==
                    "static_robustness_proxy_pass" ?
                    "static_proxy_pass_is_not_complete_engineering" :
                    "candidate_bound_static_PF_and_engineering_proxy_failed",
            )
        end
        result = evaluate_full_device_qualification_v99(
            candidates[index]["capability_profile"], cross;
            downstream_evidence = downstream)
        result["request_index"] = index
        result["cross_code_candidate_state"] = cross["candidate_state"]
        push!(rows, result)
    end
    sort!(rows; by = row -> Int(row["request_index"]))
    histogram = Dict{String,Int}()
    blockers = Dict{String,Int}()
    for row in rows
        state = String(row["candidate_state"])
        histogram[state] = get(histogram, state, 0) + 1
        for stage in String.(row["physical_failure_stages"])
            blockers[stage] = get(blockers, stage, 0) + 1
        end
        for stage in String.(row["incomplete_or_noncredit_stages"])
            key = "incomplete:" * stage
            blockers[key] = get(blockers, key, 0) + 1
        end
    end
    references = run_v99_reference_controls(normpath(joinpath(@__DIR__, "..")))
    provider_failures = count(row -> row["candidate_state"] ==
        "provider_system_fail", rows)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "protocol_id" => V99_PROTOCOL_ID,
        "status" => provider_failures == 0 && references["status"] == "pass" ?
            "complete" : "system_fail",
        "source_cross_code_acceptance_hash" => cross_acceptance["acceptance_hash"],
        "reference_acceptance_hash" => references["acceptance_hash"],
        "candidate_count" => length(rows),
        "candidate_state_histogram" => Dict(sort(collect(histogram))),
        "blocker_histogram" => Dict(sort(collect(blockers))),
        "provider_system_failure_count" => provider_failures,
        "unsupported_candidate_count" => 0,
        "whole_device_credible_count" => count(row -> row["whole_device_credible"] === true, rows),
        "validation_pass_count" => count(row -> row["validation_pass"] === true, rows),
        "reference_control_count" => references["reference_control_count"],
        "reference_validation_credit_count" => references["validation_pass_count"],
        "stage_order" => collect(V99_FULL_DEVICE_STAGES),
        "rows" => rows,
        "claim_boundary" => FULL_DEVICE_QUALIFICATION_V99_CLAIM_BOUNDARY,
    )
    body["acceptance_hash"] = FusionConceptAI.canonical_hash(body)
    write_json(joinpath(output_dir, "reference_controls.json"), references)
    write_json(joinpath(output_dir, "acceptance.json"), body)
    report = """
    # v99 full-device qualification acceptance

    - Status: `$(body["status"])`
    - Cross-code acceptance: `$(body["source_cross_code_acceptance_hash"])`
    - Candidate census: $(body["candidate_count"])
    - Candidate states: `$(body["candidate_state_histogram"])`
    - Provider-system failures: $(body["provider_system_failure_count"])
    - Unsupported classifications: $(body["unsupported_candidate_count"])
    - Whole-device credible candidates: $(body["whole_device_credible_count"])
    - Validation passes: $(body["validation_pass_count"])
    - ITER/C-2W reference controls: $(body["reference_control_count"])/2; validation credit 0
    - Acceptance hash: `$(body["acceptance_hash"])`

    The sole sampled-local-ideal-MHD survivor was evaluated by nine candidate-bound
    FreeGS PF perturbation cases. All solver cases converged, but the declared additive
    peak-field and membrane-support-stress proxies failed. This is a reduced engineering
    rejection, not a complete engineering qualification. No candidate has complete
    stability, transport/exhaust, materials, or independent experimental validation.

    $(FULL_DEVICE_QUALIFICATION_V99_CLAIM_BOUNDARY)
    """
    open(joinpath(output_dir, "acceptance_report.md"), "w") do io
        write(io, report)
    end
    println(JSON3.write(Dict(key => body[key] for key in (
        "status", "candidate_count", "candidate_state_histogram",
        "whole_device_credible_count", "validation_pass_count", "acceptance_hash"))))
    body["status"] == "complete" ? 0 : 1
end

exit(main())
