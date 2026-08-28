using FusionConceptAI
using JSON3
using SHA

plain(value) = FusionConceptAI._stage3_plain_v1(value)

function read_json(path)
    return plain(JSON3.read(read(path, String), Dict{String,Any}))
end

function sha256_file(path)
    open(path, "r") do io
        return bytes2hex(SHA.sha256(io))
    end
end

function audit_route(run_root, route_id, directory_name, expected_count)
    directory = joinpath(run_root, directory_name)
    summary_path = joinpath(directory, "v86_campaign_merged.summary.json")
    stream_path = joinpath(directory, "v86_campaign_merged.jsonl")
    isfile(summary_path) || error("missing strict merge summary: $summary_path")
    isfile(stream_path) || error("missing strict merge stream: $stream_path")
    summary = read_json(summary_path)
    summary["status"] == "complete" || error("incomplete strict merge: $route_id")
    summary["evidence_firewall_passed"] === true || error("firewall failed: $route_id")
    isempty(summary["duplicate_solver_execution_keys"]) ||
        error("duplicate solver execution key: $route_id")
    summary["merged_stream_sha256"] == sha256_file(stream_path) ||
        error("merged stream hash mismatch: $route_id")

    request_hashes = Set{String}()
    solver_hashes = Set{String}()
    record_hashes = Set{String}()
    status_histogram = Dict{String,Int}()
    row_count = 0
    cache_hit_count = 0
    for line in eachline(stream_path)
        isempty(strip(line)) && continue
        row = plain(JSON3.read(line, Dict{String,Any}))
        row_count += 1
        push!(request_hashes, String(row["request_hash"]))
        push!(record_hashes, String(row["record_hash"]))
        solver_hash = String(row["solver_input_hashes"]["finite_filament_field"])
        length(solver_hash) == 64 || error("invalid field solver hash: $route_id")
        push!(solver_hashes, solver_hash)
        status = String(row["gate_chain"]["finite_filament_field"]["status"])
        status_histogram[status] = get(status_histogram, status, 0) + 1
        cache_hit_count += get(row["cache_hits"], "finite_filament_field", false) === true
        get(row, "retroactive_feasibility_credit", true) === false ||
            error("retroactive feasibility credit detected: $route_id")
    end

    row_count == expected_count || error("unexpected row count: $route_id")
    length(request_hashes) == row_count || error("duplicate request hash: $route_id")
    length(solver_hashes) == row_count || error("duplicate field solver hash: $route_id")
    length(record_hashes) == row_count || error("duplicate record hash: $route_id")
    Int(summary["candidate_count"]) == row_count || error("summary row mismatch: $route_id")
    Int(summary["unique_request_count"]) == row_count || error("summary request mismatch: $route_id")
    Int(summary["unique_solver_input_counts"]["finite_filament_field"]) == row_count ||
        error("summary solver hash mismatch: $route_id")
    Int(get(summary["cache_hit_counts"], "finite_filament_field", 0)) == cache_hit_count ||
        error("summary cache-hit mismatch: $route_id")

    return Dict{String,Any}(
        "route" => route_id,
        "candidate_count" => row_count,
        "unique_request_count" => length(request_hashes),
        "unique_field_solver_input_count" => length(solver_hashes),
        "unique_record_count" => length(record_hashes),
        "field_status_histogram" => status_histogram,
        "field_cache_hit_count" => cache_hit_count,
        "field_actual_execution_count" => Int(get(summary["actual_execution_counts"],
            "finite_filament_field", 0)),
        "exception_count" => sum(Int.(values(summary["exception_counts_by_capability_cell"]))),
        "evidence_firewall_passed" => summary["evidence_firewall_passed"],
        "duplicate_solver_execution_keys" => summary["duplicate_solver_execution_keys"],
        "campaign_hash" => summary["campaign_hash"],
        "merge_result_hash" => summary["result_hash"],
        "merged_stream_sha256" => summary["merged_stream_sha256"],
        "solver_hashes" => solver_hashes)
end

run_root = abspath(isempty(ARGS) ?
    joinpath(@__DIR__, "..", "runs", "v86_10240_low_order_campaign_20260826") : ARGS[1])
open_route = audit_route(run_root, "open/mixed", "open_field", 5270)
closed_route = audit_route(run_root, "closed/mixed", "closed_field", 4910)
all_solver_hashes = union(open_route["solver_hashes"], closed_route["solver_hashes"])
total = Int(open_route["candidate_count"]) + Int(closed_route["candidate_count"])
length(all_solver_hashes) == total || error("cross-route duplicate field solver input")
delete!(open_route, "solver_hashes"); delete!(closed_route, "solver_hashes")

body = Dict{String,Any}(
    "schema_version" => "1.0.0",
    "status" => "complete",
    "audit_kind" => "v86_dual_route_strict_field_catalog_audit_v1",
    "catalog_request_count" => total,
    "unique_request_count" => total,
    "unique_field_solver_input_count" => length(all_solver_hashes),
    "cross_route_duplicate_field_solver_input_count" => 0,
    "all_actual_field_solver_inputs_unique" => true,
    "all_evidence_firewalls_passed" => true,
    "all_duplicate_solver_execution_key_sets_empty" => true,
    "retroactive_feasibility_credit" => false,
    "routes" => [open_route, closed_route],
    "claim_boundary" => "This audit establishes complete, unique, firewall-clean finite-filament field execution only. It grants no end-loss, Poincare, finite-pressure, stability, engineering, VVUQ, net-power, originality, or build-ready credit.")
body["audit_hash"] = canonical_hash(body)
output = joinpath(run_root, "field_catalog_strict_audit.json")
temporary = output * ".partial"
open(temporary, "w") do io
    write(io, canonical_json(body)); write(io, '\n')
end
mv(temporary, output; force = true)
println(JSON3.write(Dict("status" => "complete", "output" => output,
    "audit_hash" => body["audit_hash"], "unique_field_solver_input_count" =>
        body["unique_field_solver_input_count"])))
