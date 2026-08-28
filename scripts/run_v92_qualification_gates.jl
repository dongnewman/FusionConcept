using FusionConceptAI
using JSON3

root = normpath(joinpath(@__DIR__, ".."))
assert_protocol_sealed_v92(root)
run_root = joinpath(root, "runs", "physical_closure_v92_formal_417_20260828")
realizations = Dict(String(row["candidate_hash"]) => row for row in
    FusionConceptAI._v92_read_nonempty_jsonl(joinpath(run_root,
        "realization_dossiers_v92.jsonl")))
equilibrium_requests = FusionConceptAI._v92_read_nonempty_jsonl(joinpath(
    run_root, "requests", "high_fidelity_pilot", "equilibrium_requests_v92.jsonl"))
equilibrium_results = FusionConceptAI._v92_read_nonempty_jsonl(joinpath(
    run_root, "results", "high_fidelity_pilot", "equilibrium_results_v92.jsonl"))
length(equilibrium_requests) == length(equilibrium_results) == 229 ||
    error("v92 pilot request/result count mismatch")

mode_rows = Dict{String,Any}[]; orbit_rows = Dict{String,Any}[]
stability_rows = Dict{String,Any}[]; comparison_rows = Dict{String,Any}[]
vvuq_rows = Dict{String,Any}[]; decision_rows = Dict{String,Any}[]
for index in eachindex(equilibrium_results)
    request_payload = equilibrium_requests[index]
    result_payload = equilibrium_results[index]
    request = EquilibriumRequestV92(request_payload,
        String(request_payload["request_hash"]))
    equilibrium = EquilibriumResultV92(result_payload,
        String(result_payload["result_hash"]))
    request.payload["candidate_hash"] == result_payload["candidate_hash"] ||
        error("v92 pilot request/result candidate mismatch")
    realization = realizations[String(result_payload["candidate_hash"])]
    modes = compile_mode_coverage_manifest_v92(realization)
    orbit = compile_blocked_orbit_result_v92(realization, equilibrium)
    stability = compile_blocked_stability_result_v92(realization, equilibrium)
    comparison = compile_cross_code_comparison_v92(equilibrium, orbit,
        stability)
    vvuq = compile_validation_vvuq_v92(realization, equilibrium, orbit,
        stability)
    decision = compile_promotion_decision_v92(realization, equilibrium, orbit,
        stability, comparison, vvuq)
    push!(mode_rows, modes.payload); push!(orbit_rows, orbit.payload)
    push!(stability_rows, stability.payload); push!(comparison_rows, comparison)
    push!(vvuq_rows, vvuq); push!(decision_rows, decision)
end

artifacts = Dict{String,Any}(
    "mode_coverage" => mode_rows, "orbit" => orbit_rows,
    "stability" => stability_rows, "cross_code" => comparison_rows,
    "vvuq" => vvuq_rows, "decisions" => decision_rows)
paths = Dict(
    "mode_coverage" => joinpath(run_root, "mode_coverage_manifests_v92.jsonl"),
    "orbit" => joinpath(run_root, "results", "high_fidelity_pilot",
        "orbit_results_v92.jsonl"),
    "stability" => joinpath(run_root, "results", "high_fidelity_pilot",
        "stability_results_v92.jsonl"),
    "cross_code" => joinpath(run_root, "cross_code_comparison_matrix_v92.jsonl"),
    "vvuq" => joinpath(run_root, "validation_vvuq_dossiers_v92.jsonl"),
    "decisions" => joinpath(run_root, "promotion_decisions_v92.jsonl"))
for key in keys(artifacts)
    FusionConceptAI._v92_write_immutable(paths[key],
        FusionConceptAI._v92_jsonl_text(artifacts[key]))
end

first_blockers = Dict{String,Int}(); stage_status = Dict{String,Dict{String,Int}}()
for decision in decision_rows
    blocker = String(decision["first_blocker"])
    first_blockers[blocker] = get(first_blockers, blocker, 0) + 1
    for gate in decision["gates"]
        gate_id = String(gate["gate"]); status = String(gate["status"])
        histogram = get!(stage_status, gate_id, Dict{String,Int}())
        histogram[status] = get(histogram, status, 0) + 1
    end
end
summary = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
    "candidate_count" => length(decision_rows),
    "mode_coverage_count" => length(mode_rows),
    "orbit_result_count" => length(orbit_rows),
    "stability_result_count" => length(stability_rows),
    "cross_code_comparison_count" => length(comparison_rows),
    "validation_vvuq_count" => length(vvuq_rows),
    "promotion_decision_count" => length(decision_rows),
    "first_blocker_histogram" => first_blockers,
    "stage_status_histogram" => stage_status,
    "unresolved_solver_disagreement_count" => count(row ->
        row["unresolved_solver_disagreement"], comparison_rows),
    "computationally_credible_new_device_count" => count(row ->
        row["computationally_credible_fusion_device_concept"], decision_rows),
    "experimentally_validated_new_fusion_device_count" => 0,
    "manufactured_sentinel_or_published_interval_credit_count" => count(row ->
        row["manufactured_sentinel_or_published_interval_credit"], decision_rows),
    "claim_boundary" => QUALIFICATION_VVUQ_V92_CLAIM_BOUNDARY)
summary["summary_hash"] = canonical_hash(summary)
FusionConceptAI._v92_write_immutable(joinpath(run_root,
    "qualification_gate_summary_v92.json"),
    FusionConceptAI._v92_json_text(summary))
JSON3.pretty(stdout, summary; allow_inf = false)
println()
