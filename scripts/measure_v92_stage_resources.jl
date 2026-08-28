using FusionConceptAI
using JSON3

root = normpath(joinpath(@__DIR__, ".."))
run_root = joinpath(root, "runs", "physical_closure_v92_formal_417_20260828")
realization_summary = FusionConceptAI._v92_json(joinpath(run_root,
    "realization_summary_v92.json"))
control = FusionConceptAI._v92_json(joinpath(run_root, "controls",
    "control_qualification_summary_v92.json"))
installation = FusionConceptAI._v92_json(joinpath(run_root, "controls",
    "solver_installation_audit_v92.json"))
realizations = Dict(String(row["candidate_hash"]) => row for row in
    FusionConceptAI._v92_read_nonempty_jsonl(joinpath(run_root,
        "realization_dossiers_v92.jsonl")))
requests = FusionConceptAI._v92_read_nonempty_jsonl(joinpath(run_root,
    "requests", "high_fidelity_pilot", "equilibrium_requests_v92.jsonl"))
timed = @timed begin
    hashes = String[]
    for request_payload in requests
        request = EquilibriumRequestV92(request_payload,
            String(request_payload["request_hash"]))
        realization = realizations[String(request_payload["candidate_hash"])]
        equilibrium = execute_equilibrium_request_v92(request, installation)
        orbit = compile_blocked_orbit_result_v92(realization, equilibrium)
        stability = compile_blocked_stability_result_v92(realization,
            equilibrium)
        comparison = compile_cross_code_comparison_v92(equilibrium, orbit,
            stability)
        vvuq = compile_validation_vvuq_v92(realization, equilibrium, orbit,
            stability)
        decision = compile_promotion_decision_v92(realization, equilibrium,
            orbit, stability, comparison, vvuq)
        push!(hashes, decision["decision_hash"])
    end
    hashes
end
length(timed.value) == 229 || error("v92 resource replay count mismatch")
mesh_root = joinpath(run_root, "farthest_candidate_v92")
mesh_paths = [joinpath(directory, file) for (directory, _, files) in
    walkdir(mesh_root) for file in files if endswith(lowercase(file), ".h5")]
body = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
    "stages" => Dict{String,Any}(
        "physical_realization_417_plus_replay" =>
            realization_summary["resource_usage"],
        "vmex_3d_control" => Dict("wall_seconds" =>
            control["vmex_control"]["wall_seconds"], "solver_executions" => 1),
        "freegs_verification_control" => Dict("wall_seconds" =>
            control["freegs_control"]["wall_seconds"], "solver_executions" => 1),
        "pilot_route_and_blocked_downstream_replay" => Dict(
            "candidate_count" => 229, "wall_seconds" => timed.time,
            "allocated_bytes" => timed.bytes, "gc_seconds" => timed.gctime,
            "threads" => Threads.nthreads(), "solver_executions" => 0,
            "reason" => "all compatible mixed-topology equilibrium backends unsupported"),
        "materialized_farthest_candidate_meshes" => Dict(
            "mesh_count" => length(mesh_paths),
            "artifact_bytes" => sum(filesize(path) for path in mesh_paths),
            "solver_executions" => 0)),
    "claim_boundary" => "Resource use for unsupported solver stages records routing and fail-closed evidence processing, not high-fidelity physics execution.")
body["resource_manifest_hash"] = canonical_hash(body)
path = joinpath(run_root, "per_stage_resource_usage_v92.json")
FusionConceptAI._v92_write_immutable(path, FusionConceptAI._v92_json_text(body))
println(JSON3.write(body))
