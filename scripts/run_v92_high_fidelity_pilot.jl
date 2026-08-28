using FusionConceptAI
using JSON3

root = normpath(joinpath(@__DIR__, ".."))
assert_protocol_sealed_v92(root)
run_root = joinpath(root, "runs", "physical_closure_v92_formal_417_20260828")
pilot = FusionConceptAI._v92_json(joinpath(run_root, "pilot_selection_v92.json"))
control_summary = FusionConceptAI._v92_json(joinpath(run_root, "controls",
    "control_qualification_summary_v92.json"))
installation_audit = FusionConceptAI._v92_json(joinpath(run_root, "controls",
    "solver_installation_audit_v92.json"))

realizations = Dict{String,Dict{String,Any}}()
for row in FusionConceptAI._v92_read_nonempty_jsonl(joinpath(run_root,
        "realization_dossiers_v92.jsonl"))
    realizations[String(row["candidate_hash"])] = row
end

request_rows = Dict{String,Any}[]
for selected in pilot["selected"]
    realization = realizations[String(selected["candidate_hash"])]
    request = compile_equilibrium_request_v92(realization)
    push!(request_rows, request.payload)
end
request_path = joinpath(run_root, "requests", "high_fidelity_pilot",
    "equilibrium_requests_v92.jsonl")
FusionConceptAI._v92_write_immutable(request_path,
    FusionConceptAI._v92_jsonl_text(request_rows))

result_rows = Dict{String,Any}[]
dossier_rows = Dict{String,Any}[]
replay_rows = Dict{String,Any}[]
route_histogram = Dict{String,Int}(); status_histogram = Dict{String,Int}()
for (index, request_payload) in enumerate(request_rows)
    request = EquilibriumRequestV92(request_payload,
        String(request_payload["request_hash"]))
    result = execute_equilibrium_request_v92(request, installation_audit)
    push!(result_rows, result.payload)
    route_id = String(result.payload["route_id"])
    status = String(result.payload["status"])
    route_histogram[route_id] = get(route_histogram, route_id, 0) + 1
    status_histogram[status] = get(status_histogram, status, 0) + 1
    downstream_status = status == "unsupported" ? "unsupported_upstream_equilibrium" :
        "unknown_upstream_equilibrium_not_pass"
    dossier = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "candidate_id" => result.payload["candidate_id"],
        "candidate_hash" => result.payload["candidate_hash"],
        "realization_hash" => result.payload["realization_hash"],
        "capability_signature_hash" =>
            pilot["selected"][index]["capability_signature_hash"],
        "stages" => [
            Dict("stage_id" => "physical_realization", "status" => "pass"),
            Dict("stage_id" => "applicable_equilibrium", "status" => status,
                "result_hash" => result.result_hash, "reason" => result.payload["reason"]),
            Dict("stage_id" => "field_line_orbit_confinement", "status" => downstream_status,
                "reason" => "not_scheduled_because_equilibrium_hard_gate_not_pass"),
            Dict("stage_id" => "ideal_resistive_kinetic_linear_stability", "status" => downstream_status,
                "reason" => "not_scheduled_because_equilibrium_hard_gate_not_pass"),
            Dict("stage_id" => "nonlinear_stability", "status" => downstream_status,
                "reason" => "not_scheduled_because_prior_hard_gates_not_pass"),
            Dict("stage_id" => "independent_solver_comparison", "status" => "unknown",
                "reason" => result.payload["unresolved_solver_disagreement"]),
            Dict("stage_id" => "numerical_vvuq", "status" => downstream_status,
                "reason" => "no_high_fidelity_solution_family"),
            Dict("stage_id" => "parameter_uq", "status" => downstream_status,
                "reason" => "no_high_fidelity_solution_family"),
            Dict("stage_id" => "candidate_bound_validation_vvuq", "status" => "unknown",
                "reason" => "actual_holdout_measurement_dataset_and_candidate_applicability_not_attested"),
            Dict("stage_id" => "engineering_obligations", "status" => "unsupported",
                "reason" => "candidate_bound_engineering_models_and_bounded_evidence_not_complete")],
        "first_blocker" => "applicable_equilibrium:$(status)",
        "computationally_credible_fusion_device_concept" => false,
        "experimentally_validated_new_fusion_device" => false,
        "manufactured_sentinel_or_published_interval_credit" => false,
        "evidence_firewall_status" => "pass",
        "claim_boundary" => "An unsupported equilibrium route blocks every downstream hard gate; no unscheduled stage is treated as pass or not_applicable.")
    dossier["dossier_hash"] = canonical_hash(dossier)
    push!(dossier_rows, dossier)
    replay = execute_equilibrium_request_v92(request, installation_audit)
    push!(replay_rows, Dict("candidate_id" => result.payload["candidate_id"],
        "expected_result_hash" => result.result_hash,
        "replayed_result_hash" => replay.result_hash,
        "status" => replay.result_hash == result.result_hash ? "pass" : "fail"))
end
all(row -> row["status"] == "pass", replay_rows) || error("pilot replay failed")

result_path = joinpath(run_root, "results", "high_fidelity_pilot",
    "equilibrium_results_v92.jsonl")
dossier_path = joinpath(run_root, "high_fidelity_pilot_dossiers_v92.jsonl")
replay_path = joinpath(run_root, "high_fidelity_pilot_replay_v92.jsonl")
FusionConceptAI._v92_write_immutable(result_path,
    FusionConceptAI._v92_jsonl_text(result_rows))
FusionConceptAI._v92_write_immutable(dossier_path,
    FusionConceptAI._v92_jsonl_text(dossier_rows))
FusionConceptAI._v92_write_immutable(replay_path,
    FusionConceptAI._v92_jsonl_text(replay_rows))

coverage = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
    "routing_axes" => collect(V92_ROUTING_AXES),
    "pilot_count" => length(request_rows), "route_histogram" => route_histogram,
    "available_capabilities" => installation_audit["available_capabilities"],
    "mixed_primary_available" => false, "open_primary_available" => false,
    "nested_surface_solver_misrouting_count" => 0,
    "family_or_device_label_routing_count" => 0,
    "solver_coverage_status" => "fail")
coverage["coverage_hash"] = canonical_hash(coverage)
FusionConceptAI._v92_write_immutable(joinpath(run_root,
    "capability_route_coverage_matrix_v92.json"),
    FusionConceptAI._v92_json_text(coverage))

summary = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
    "pilot_request_count" => length(request_rows),
    "pilot_result_count" => length(result_rows),
    "pilot_dossier_count" => length(dossier_rows),
    "route_histogram" => route_histogram,
    "equilibrium_status_histogram" => status_histogram,
    "solver_execution_count" => count(row -> row["solver_executed"], result_rows),
    "deterministic_replay_count" => length(replay_rows),
    "deterministic_replay_pass_count" => count(row -> row["status"] == "pass", replay_rows),
    "known_control_qualification_status" =>
        control_summary["known_device_control_qualification_status"],
    "solver_coverage_status" => coverage["solver_coverage_status"],
    "pilot_to_full_transition_allowed" => false,
    "full_qualification_scheduled_count" => 0,
    "first_campaign_blocker" => "solver_coverage_for_mixed_and_open_routes",
    "computationally_credible_new_device_count" => 0,
    "experimentally_validated_new_fusion_device_count" => 0,
    "claim_boundary" => "All selected pilot requests were executed through the capability router. Unsupported routes are evidence outcomes, not solver runs or readiness claims.")
summary["summary_hash"] = canonical_hash(summary)
FusionConceptAI._v92_write_immutable(joinpath(run_root,
    "high_fidelity_pilot_summary_v92.json"),
    FusionConceptAI._v92_json_text(summary))
JSON3.pretty(stdout, summary; allow_inf = false)
println()
