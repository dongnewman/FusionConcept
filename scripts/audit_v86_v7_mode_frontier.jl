using FusionConceptAI
using JSON3

const FCA = FusionConceptAI

length(ARGS) in (2, 3) || error(
    "usage: audit_v86_v7_mode_frontier.jl CAMPAIGN MERGED_JSONL [OUTPUT]")
read_json(path) = FCA._stage3_plain_v1(JSON3.read(
    read(abspath(path), String), Dict{String,Any}))

campaign = read_json(ARGS[1])
rows = FCA._v84_read_valid_json_lines(abspath(ARGS[2]))
bounded = [row for row in rows if String(row["gate_chain"]["poincare_32"][
    "classification_code"]) == "insufficient_long_horizon_rotational_transform"]
length(bounded) == 1 || error(
    "v7 mode audit requires exactly one bounded transform-limited frontier")
source = only(bounded)
raw = only([item for item in campaign["requests"] if String(item[
    "request_hash"]) == String(source["request_hash"])])
restored = FCA._v86_restore_request(raw)
design = FCA._v86_joint_design_from_dict(source["optimized_design"],
    restored.grammar)
source_override = FCA._stage3_plain_v1(source["optimized_basis_override"])

audit_rows = Dict{String,Any}[]
for (dominant_m, dominant_n) in ((2, 1), (3, 1), (1, 2), (2, 2))
    override = deepcopy(source_override)
    override["dominant_poloidal_mode_m"] = dominant_m
    override["dominant_toroidal_mode_n"] = dominant_n
    override["mode_probe"] = Dict{String,Any}(
        "dominant_m" => dominant_m, "dominant_n" => dominant_n)
    override["feedback_role"] = "next_request_sampling_only"
    override["retroactive_feasibility_credit"] = false
    compiled = compile_joint_physical_realization_v85(restored.topology,
        restored.compilation, design; basis_override = override,
        base_coil_count = restored.request.base_coil_count)
    hashes = v85_solver_input_hashes_v1(compiled)
    field = evaluate_v85_biot_savart_gate_v1(compiled)
    poincare = evaluate_v85_poincare_gate_v1(compiled, field;
        target_toroidal_turns = 32, steps_per_turn = 120)
    evidence = get(poincare, "evidence", Dict{String,Any}())
    p = get(evidence, "poincare_evidence", Dict{String,Any}())
    traces = get(p, "traces", Any[])
    completion = isempty(traces) ? 0.0 : minimum(min(1.0,
        Float64(get(trace, "toroidal_turns", 0.0)) / 32.0) for trace in traces)
    axis = get(p, "periodic_magnetic_axis", Dict{String,Any}())
    normal = field["evidence"]["candidate_surface_normal_field"]
    push!(audit_rows, Dict{String,Any}(
        "dominant_poloidal_mode_m" => dominant_m,
        "dominant_toroidal_mode_n" => dominant_n,
        "basis_override_hash" => canonical_hash(override),
        "field_solver_input_hash" => hashes["field_solver_input_hash"],
        "poincare_solver_input_hash" => hashes["poincare_solver_input_hash"],
        "field_status" => field["status"],
        "rms_relative_normal_field" => normal["rms_relative_normal_field"],
        "poincare_status" => poincare["status"],
        "poincare_classification_code" => poincare["classification_code"],
        "axis_status" => get(axis, "status", "not_executed"),
        "axis_closure_residual_normalized" => get(axis,
            "closure_residual_normalized", nothing),
        "minimum_trace_completion_fraction" => completion,
        "minimum_absolute_rotational_transform" => get(p,
            "minimum_absolute_rotational_transform", 0.0),
        "surface_ordering_fraction" => get(p,
            "surface_ordering_fraction", 0.0),
        "candidate_feasibility_credit" => false,
        "campaign_promotion_credit" => false))
end

artifact = Dict{String,Any}(
    "schema_version" => "1.0.0",
    "audit_kind" => "v86_v7_current_potential_mode_frontier_v1",
    "source_campaign_hash" => campaign["campaign_hash"],
    "source_request_hash" => source["request_hash"],
    "source_design_hash" => design.design_hash,
    "rows" => audit_rows,
    "candidate_feasibility_credit" => false,
    "campaign_promotion_credit" => false,
    "claim_boundary" => "This discrete mode scan is next-request sampling feedback only. A passing point must be recompiled as an immutable CandidateSolveRequest and rerun through the staged campaign before promotion credit.")
artifact["result_hash"] = canonical_hash(artifact)
length(ARGS) == 3 && FCA._stage3_atomic_json_v1(abspath(ARGS[3]), artifact)
println(JSON3.write(Dict(
    "status" => "complete",
    "row_count" => length(audit_rows),
    "poincare_pass_count" => count(row -> row["poincare_status"] == "pass",
        audit_rows),
    "result_hash" => artifact["result_hash"])))
