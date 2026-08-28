using JSON3
using FusionConceptAI
using SHA
using Base.Threads

function main()
length(ARGS) == 2 || error(
    "usage: run_v98_end_to_end_campaign.jl V97_RUN_DIRECTORY V98_OUTPUT_DIRECTORY")
v97_directory = abspath(ARGS[1])
output_directory = abspath(ARGS[2])
closed_path = joinpath(v97_directory, "unique_closed_inputs.jsonl")
v97_acceptance_path = joinpath(v97_directory, "acceptance.json")
isfile(closed_path) || error("missing v97 unique closed input stream")
isfile(v97_acceptance_path) || error("missing v97 acceptance")
mkpath(output_directory)

function write_json(path, value)
    temporary = path * ".partial"
    open(temporary, "w") do io
        JSON3.pretty(io, value)
        write(io, '\n')
    end
    mv(temporary, path; force = true)
end

reference = run_v98_reference_acceptance(normpath(joinpath(@__DIR__, "..")))
reference["status"] == "pass" || error("v98 ITER/C-2W reference acceptance failed")
write_json(joinpath(output_directory, "reference_acceptance.json"), reference)

v97_acceptance = JSON3.read(read(v97_acceptance_path, String), Dict{String,Any})
expected_closed = Int(v97_acceptance["unique_closed_input_count"])
expected_total = Int(v97_acceptance["processed"])
lines = readlines(closed_path)
length(lines) == expected_closed || error("v97 closed stream count mismatch")

histogram = Dict(state => 0 for state in sort!(collect(V98_CANDIDATE_STATES)))
histogram["topology_screen_fail"] = expected_total - expected_closed
gate_histogram = Dict{String,Int}()
route_histogram = Dict{String,Int}()
candidates = Dict{String,Any}[]
stream_hash = bytes2hex(sha256("v98-sealed-closed-stream-v1"))
provider_replay = Dict{String,Any}[]

chunk_size = 4096
for chunk_start in 1:chunk_size:length(lines)
    chunk_stop = min(chunk_start + chunk_size - 1, length(lines))
    rows = [JSON3.read(lines[position], Dict{String,Any})
        for position in chunk_start:chunk_stop]
    results = Vector{Dict{String,Any}}(undef, length(rows))
    @threads for offset in eachindex(rows)
        closed = rows[offset]
        index = Int(closed["representative_request_index"])
        physics = reconstruct_indexed_physics_v97(index)
        isempty(physics["declaration_blockers"]) || error(
            "sealed v97 closed input reconstructed with a topology blocker")
        topology = generate_family_neutral_topology_v91(index)
        capability = FusionConceptAI._v98_capability_profile(topology)
        point = FusionConceptAI._v98_operating_point_from_generated(physics, index)
        solve = solve_candidate_physics_v98(point, capability)
        numerical = solve["status"] == "pass" ?
            numerical_vvuq_candidate_v98(point, capability, solve) :
            Dict{String,Any}("status" => "not_executed")
        robust = get(numerical, "robust_physics_pass", false) === true
        state = solve["status"] != "pass" ? "physics_screen_fail" :
            numerical["status"] != "pass" || !robust ? "numerical_vvuq_fail" :
                "computational_candidate"
        result = Dict{String,Any}(
            "request_index" => index, "candidate_state" => state,
            "topology_hash" => topology["topology_hash"],
            "graph_hash" => closed["graph_hash"],
            "solver_input_hash" => closed["solver_input_hash"],
            "v97_closure_row_hash" => closed["closure_row_hash"],
            "provider_closure" => Dict("status" => "pass",
                "source" => "sealed_v97_provider_rerun", "multiplicity" => closed["multiplicity"]),
            "capability_profile" => capability, "operating_point" => point,
            "physics_solve" => solve, "numerical_vvuq" => numerical,
            "validation_vvuq" => robust ? Dict("status" => "unknown_validation_domain",
                "actual_measurement_dataset_count" => 0,
                "reason" => "candidate_bound_validation_measurements_unavailable") :
                Dict("status" => "not_executed"),
            "stage_order" => ["topology_screen", "provider_closure", "physics_solve",
                "numerical_vvuq", "validation_vvuq"],
            "basis_direct_metric_credit" => false,
            "unsupported_candidate_classification_used" => false,
            "claim_boundary" => END_TO_END_DEVICE_PIPELINE_V98_CLAIM_BOUNDARY)
        result["result_hash"] = canonical_hash(result)
        results[offset] = result
    end
    for result in results
        state = String(result["candidate_state"])
        histogram[state] = get(histogram, state, 0) + 1
        route = String(result["capability_profile"]["route"])
        route_histogram[route] = get(route_histogram, route, 0) + 1
        for gate in String.(result["physics_solve"]["failed_gates"])
            gate_histogram[gate] = get(gate_histogram, gate, 0) + 1
        end
        state == "computational_candidate" && push!(candidates, result)
        stream_hash = canonical_hash(Dict("previous" => stream_hash,
            "result_hash" => result["result_hash"]))
    end
    if chunk_start == 1 || chunk_stop == length(lines) || mod(chunk_stop, 65536) < chunk_size
        println(JSON3.write(Dict("processed_closed" => chunk_stop,
            "expected_closed" => expected_closed, "computational_candidates" =>
                histogram["computational_candidate"])))
        flush(stdout)
    end
end

for position in unique(round.(Int, range(1, length(lines); length = 16)))
    closed = JSON3.read(lines[position], Dict{String,Any})
    index = Int(closed["representative_request_index"])
    replay = compile_indexed_closure_v97(index)
    matched = replay.row["screen_status"] == "closed" &&
        replay.row["graph_hash"] == closed["graph_hash"] &&
        replay.row["solver_input_hash"] == closed["solver_input_hash"]
    push!(provider_replay, Dict("request_index" => index, "status" =>
        matched ? "pass" : "fail", "graph_hash_match" =>
        replay.row["graph_hash"] == closed["graph_hash"], "solver_input_hash_match" =>
        replay.row["solver_input_hash"] == closed["solver_input_hash"]))
end
all(row -> row["status"] == "pass", provider_replay) || error(
    "v98 provider replay sample failed")

sort!(candidates; by = item -> -Float64(item["physics_solve"]["metrics"][
    "net_electric_power_w"]))
candidate_path = joinpath(output_directory, "computational_candidates.jsonl")
temporary = candidate_path * ".partial"
open(temporary, "w") do io
    for candidate in candidates
        JSON3.write(io, candidate)
        write(io, '\n')
    end
end
mv(temporary, candidate_path; force = true)

acceptance = Dict{String,Any}(
    "protocol_id" => V98_PROTOCOL_ID,
    "status" => "complete_reduced_screen",
    "v97_acceptance_hash" => v97_acceptance["acceptance_hash"],
    "request_count" => expected_total, "sealed_provider_closed_count" => expected_closed,
    "candidate_state_histogram" => histogram,
    "capability_route_histogram" => route_histogram,
    "failed_gate_histogram" => gate_histogram,
    "provider_system_failure_count" => 0,
    "unsupported_candidate_count" => 0,
    "provider_replay_samples" => provider_replay,
    "reference_acceptance_hash" => reference["acceptance_hash"],
    "computational_candidate_count" => length(candidates),
    "validation_pass_count" => 0,
    "high_fidelity_pending_count" => length(candidates),
    "result_stream_hash" => stream_hash,
    "candidate_stream" => basename(candidate_path),
    "experimental_validation_independent" => true,
    "claim_boundary" => END_TO_END_DEVICE_PIPELINE_V98_CLAIM_BOUNDARY)
acceptance["acceptance_hash"] = canonical_hash(acceptance)
write_json(joinpath(output_directory, "reduced_screen_acceptance.json"), acceptance)
println(JSON3.pretty(JSON3.write(acceptance)))
end

main()
