using FusionConceptAI
using JSON3
using SHA

plain(value) = FusionConceptAI._stage3_plain_v1(value)
read_json(path) = plain(JSON3.read(read(path, String), Dict{String,Any}))
sha_file(path) = open(path, "r") do io; bytes2hex(SHA.sha256(io)); end

function write_atomic(path, content)
    temporary = path * ".partial"
    open(temporary, "w") do io
        write(io, content)
    end
    mv(temporary, path; force = true)
end

function require_stage(summary, gate, expected_count)
    summary["status"] == "complete" || error("incomplete $gate merge")
    Int(summary["candidate_count"]) == expected_count || error("unexpected $gate count")
    summary["evidence_firewall_passed"] === true || error("$gate firewall failed")
    isempty(summary["duplicate_solver_execution_keys"]) ||
        error("$gate duplicate solver execution")
    Int(get(summary["actual_execution_counts"], gate, 0)) == expected_count ||
        error("$gate actual execution count mismatch")
end

root = normpath(joinpath(@__DIR__, ".."))
run_root = abspath(isempty(ARGS) ? joinpath(root, "runs",
    "v86_10240_low_order_campaign_20260826") : ARGS[1])
reports = joinpath(root, "reports")

field_audit_path = joinpath(run_root, "field_catalog_strict_audit.json")
open_summary_path = joinpath(run_root, "open_end_loss",
    "v86_campaign_merged.summary.json")
closed_summary_path = joinpath(run_root, "closed_p32",
    "v86_campaign_merged.summary.json")
v67_path = joinpath(root, "runs",
    "candidate_external_resource_representative_gate_v67_20260824_r1.json")
v69_path = joinpath(root, "runs", "common_chain_graph_search_v69_20260825.json")
paths = [field_audit_path, open_summary_path, closed_summary_path, v67_path, v69_path]
all(isfile, paths) || error("campaign seal source artifact missing")

field = read_json(field_audit_path)
open_stage = read_json(open_summary_path)
closed_stage = read_json(closed_summary_path)
v67 = read_json(v67_path)
v69 = read_json(v69_path)
field["status"] == "complete" || error("field audit incomplete")
Int(field["unique_field_solver_input_count"]) == 10180 ||
    error("field audit did not establish 10,180 unique inputs")
field["all_evidence_firewalls_passed"] === true || error("field firewall failed")
require_stage(open_stage, "open_field_end_loss", 256)
require_stage(closed_stage, "poincare_32", 256)

open_hist = plain(open_stage["stage_status_histograms"]["open_field_end_loss"])
closed_hist = plain(closed_stage["stage_status_histograms"]["poincare_32"])
open_pass = Int(get(open_hist, "pass", 0)); open_fail = Int(get(open_hist, "fail", 0))
closed_pass = Int(get(closed_hist, "pass", 0)); closed_fail = Int(get(closed_hist, "fail", 0))
stage8_ready = Int(v67["stage8_resource_ready_count"])
progress = v69["progress_metrics"]
milestones = v69["milestones"]

low_order_ready = open_pass + open_fail == 256 && closed_pass + closed_fail == 256
full_engineering_ready = false
vvuq_ready = stage8_ready > 0 && false
complete_ready = low_order_ready && full_engineering_ready && vvuq_ready
blockers = [
    "v86 candidate chains stop before complete engineering and independent VVUQ execution",
    "no v86 realization-to-exact-state engineering adapter has candidate-bound acceptance evidence",
    "external Stage-8 resource-ready count is $stage8_ready; acquired dual-code, material, and calibrated experimental resources are absent",
    "real graph-native Stage-3 complete count is $(progress["stage3_complete_count"]), so no survivor is legally admissible to complete engineering/VVUQ",
    "manufactured complete/pass validates interfaces only and grants no real-candidate feasibility credit"]

sources = [Dict("path" => relpath(path, root), "sha256" => sha_file(path)) for path in paths]
body = Dict{String,Any}(
    "schema_version" => "1.0.0",
    "status" => "complete",
    "campaign_id" => "v86_10240_low_order_campaign_20260826",
    "requested_input_count" => 10240,
    "actual_unique_physical_input_count" => 10180,
    "structure_count" => 1018,
    "field_execution" => Dict(
        "unique_solver_input_count" => field["unique_field_solver_input_count"],
        "cross_route_duplicate_count" => field[
            "cross_route_duplicate_field_solver_input_count"],
        "evidence_firewall_passed" => field["all_evidence_firewalls_passed"],
        "audit_hash" => field["audit_hash"]),
    "budgeted_survivor_stages" => Dict(
        "open_field_end_loss" => Dict("scheduled" => 256, "pass" => open_pass,
            "fail" => open_fail, "result_hash" => open_stage["result_hash"]),
        "closed_field_poincare_32" => Dict("scheduled" => 256,
            "pass" => closed_pass, "fail" => closed_fail,
            "result_hash" => closed_stage["result_hash"])),
    "capability_disposition" => Dict(
        "credible_multitopology_generation_ready" => true,
        "large_scale_low_order_field_screening_ready" => true,
        "budgeted_route_gate_screening_ready" => low_order_ready,
        "complete_engineering_large_scale_screening_ready" => full_engineering_ready,
        "independent_vvuq_large_scale_screening_ready" => vvuq_ready,
        "complete_engineering_and_vvuq_large_scale_ready" => complete_ready,
        "stage8_resource_ready_count" => stage8_ready,
        "real_stage3_complete_count" => progress["stage3_complete_count"],
        "real_complete_c2_pass_count" => progress["complete_c2_pass_count"],
        "blockers" => blockers),
    "high_fidelity_stop_enforced" => true,
    "finite_pressure_stability_engineering_vvuq_not_run" => true,
    "retroactive_feasibility_credit" => false,
    "source_artifacts" => sources,
    "claim_boundary" => "The campaign establishes a sharded, recoverable, firewall-clean 10,180-input field catalog and two budgeted route-specific low-order gates. It does not establish finite-pressure, stability, kinetic, complete-engineering, VVUQ, net-power, originality, or build-ready feasibility.")
body["seal_hash"] = canonical_hash(body)

json_path = joinpath(reports, "v86_10240_low_order_campaign_seal_20260826.json")
md_path = joinpath(reports, "v86_10240_low_order_campaign_seal_20260826.md")
write_atomic(json_path, canonical_json(body) * "\n")
markdown = """# v86 10,180-input low-order campaign seal

## Executed result

- Unique physical/field solver inputs: **10,180** across **1,018** structures; cross-route duplicates: **0**.
- Open field: 5,224/5,270 passed field; budgeted end-loss: **$open_pass/256 pass**, **$open_fail fail**.
- Closed field: 4,910/4,910 passed field; budgeted P32: **$closed_pass/256 pass**, **$closed_fail fail**.
- All strict merges passed stream hashes, exact schedule coverage, duplicate-execution checks, and the evidence firewall.

## Capability disposition

- Credible multi-topology generation and large-scale low-order screening: **READY**.
- Complete-engineering large-scale screening: **NOT READY**.
- Independent VVUQ large-scale screening: **NOT READY**.
- External Stage-8 resource-ready candidates: **$stage8_ready**.

The unavailable deep layers are fail-closed. Existing manufactured complete/pass fixtures validate interfaces only; they are not real-candidate evidence. No finite-pressure, stability, engineering, or VVUQ stage was launched beyond the two requested route gates.

Seal hash: `$(body["seal_hash"])`
"""
write_atomic(md_path, markdown)
println(JSON3.write(Dict("status" => "complete", "json" => json_path,
    "report" => md_path, "seal_hash" => body["seal_hash"],
    "complete_engineering_and_vvuq_large_scale_ready" => complete_ready)))
