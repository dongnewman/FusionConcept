#!/usr/bin/env python3
"""Checkpointed FreeGS→DESC→VMEX screen of v130 current-profile proposals."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import time
from pathlib import Path


PROTOCOL_ID = "fusionconceptai-v130-current-profile-stability-campaign-20260830"


def canonical_hash(value: object) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".partial")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True,
                                    allow_nan=False) + "\n", encoding="utf-8")
    temporary.replace(path)


def run_stage(command: list[str]) -> dict:
    started = time.perf_counter()
    process = subprocess.run(command, capture_output=True, text=True, check=False)
    return {
        "exit_code": process.returncode,
        "wall_time_s": time.perf_counter() - started,
        "stdout_tail": process.stdout[-2000:],
        "stderr_tail": process.stderr[-2000:],
    }


def classify(freegs: dict, qualification: dict | None,
             failure: str | None) -> tuple[str, list[str]]:
    if failure:
        return "provider_system_failure", [failure]
    if freegs.get("status") != "pass":
        return "physical_reject", list(freegs.get("failed_gates", ()))
    if qualification is None:
        return "provider_system_failure", ["local_stability_missing"]
    if qualification.get("provider_failures"):
        return "provider_system_failure", list(qualification["provider_failures"])
    if qualification.get("numerical_failures"):
        return "numerical_vvuq_reject", list(qualification["numerical_failures"])
    if qualification.get("physical_failures"):
        return "physical_reject", list(qualification["physical_failures"])
    return "local_stability_survivor", []


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-candidates", type=int)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--run-directory",
                        default="v130_current_profile_repair_20260830")
    parser.add_argument("--freegs-runner", default="run_v130_freegs_candidate.py")
    parser.add_argument("--materializer", default="materialize_v130_freegs_raw.py")
    parser.add_argument("--protocol-id", default=PROTOCOL_ID)
    parser.add_argument("--control-parent-local", default=(
        "runs/v129_glasser_frontier_20260830/evidence/"
        "local_stability_381661974746383708.json"))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    run = root / "runs" / args.run_directory
    evidence = run / "evidence"
    generation = read(run / "generation_acceptance.json")
    proposals = list(generation["proposals"])
    if args.max_candidates is not None:
        proposals = proposals[:args.max_candidates]
    rows = []
    for proposal in proposals:
        request_index = int(proposal["request_index"])
        token = str(request_index)
        row_path = evidence / f"row_{token}.json"
        if row_path.exists() and not args.force:
            rows.append(read(row_path))
            continue
        candidate_path = run / "inputs" / f"candidate_{token}.json"
        candidate = read(candidate_path)
        if not proposal.get("retained", True):
            current = candidate["equilibrium_profile_parameters"]["current_profile"]
            reasons = [f"physics:{gate}" for gate in
                       proposal.get("failed_physics_gates", ())]
            reasons += [f"engineering:{gate}" for gate in
                        proposal.get("failed_engineering_gates", ())]
            row = {
                "schema_version": "1.0.0", "protocol_id": args.protocol_id,
                "candidate_result_hash": candidate["result_hash"],
                "candidate_graph_hash": candidate["graph_hash"],
                "current_alpha_m": float(current["alpha_m"]),
                "current_alpha_n": float(current["alpha_n"]),
                "current_edge_tilt": (None if "edge_tilt" not in current else
                                      float(current["edge_tilt"])),
                "current_edge_power": (None if "edge_power" not in current else
                                       float(current["edge_power"])),
                "elongation": float(candidate["operating_point"]["elongation"]),
                "triangularity": float(candidate["operating_point"]["triangularity"]),
                "is_parent_shape_control": bool(proposal.get(
                    "is_parent_shape_control", False)),
                "identity_fields_used_for_provider_routing": False,
                "stages": {"recomputed_reduced_physics_and_engineering": {
                    "status": "physical_reject"}},
                "freegs_status": "not_run_after_prefilter_reject",
                "freegs_failed_gates": reasons,
                "local_stability_executed": False,
                "numerical_failures": [], "physical_failures": reasons,
                "glasser_maximum": None, "mercier_minimum": None,
                "ballooning_maximum": None,
                "candidate_state": "physical_reject", "reasons": reasons,
                "unsupported": False,
                "partial_subgraph_promotion_allowed": False,
                "whole_device_credible": False, "validation_credit": False,
            }
            row["row_hash"] = canonical_hash(row)
            write(row_path, row); rows.append(row)
            print(json.dumps({"request_index": request_index,
                              "candidate_state": "physical_reject",
                              "reasons": reasons}, sort_keys=True), flush=True)
            continue
        freegs_path = evidence / f"freegs_{token}.json"
        raw_path = evidence / f"freegs_raw_{token}.json"
        wout_path = evidence / f"wout_{token}.nc"
        manifest_path = evidence / f"export_{token}.json"
        local_path = evidence / f"local_stability_{token}.json"
        stages = {}
        failure = None
        if not freegs_path.exists() or args.force:
            stages["freegs_recheck"] = run_stage([
                str(root / ".venv-freegs" / "Scripts" / "python.exe"),
                str(root / "scripts" / args.freegs_runner),
                "--input", str(candidate_path), "--output", str(freegs_path),
            ])
        else:
            stages["freegs_recheck"] = {"reused_checkpoint": True}
        freegs = read(freegs_path) if freegs_path.exists() else {
            "status": "error", "failed_gates": []}
        if not freegs_path.exists():
            failure = "freegs_result_missing"
        if failure is None and freegs.get("status") == "pass":
            if not raw_path.exists() or args.force:
                stages["freegs_materialization"] = run_stage([
                    str(root / ".venv-freegs" / "Scripts" / "python.exe"),
                    str(root / "scripts" / args.materializer),
                    "--candidate", str(candidate_path),
                    "--verification", str(freegs_path), "--output", str(raw_path),
                ])
                if stages["freegs_materialization"]["exit_code"] != 0:
                    failure = "freegs_materialization_failure"
            else:
                stages["freegs_materialization"] = {"reused_checkpoint": True}
        if failure is None and freegs.get("status") == "pass":
            if not manifest_path.exists() or not wout_path.exists() or args.force:
                stages["desc_wout_export"] = run_stage([
                    str(root / ".venv-desc" / "Scripts" / "python.exe"),
                    str(root / "scripts" / "export_v128_desc_wout.py"),
                    "--candidate", str(candidate_path),
                    "--freegs-result", str(raw_path), "--wout", str(wout_path),
                    "--manifest", str(manifest_path),
                ])
                if stages["desc_wout_export"]["exit_code"] != 0:
                    failure = "desc_wout_export_failure"
            else:
                stages["desc_wout_export"] = {"reused_checkpoint": True}
        if failure is None and freegs.get("status") == "pass":
            if not local_path.exists() or args.force:
                stages["vmex_local_stability"] = run_stage([
                    str(root / ".conda-vmex" / "python.exe"),
                    str(root / "scripts" / "run_v128_vmex_qualification.py"),
                    "--candidate", str(candidate_path), "--manifest", str(manifest_path),
                    "--wout", str(wout_path), "--output", str(local_path),
                    "--local-stability-only",
                ])
                if stages["vmex_local_stability"]["exit_code"] not in (0, 2):
                    failure = "vmex_local_stability_crash"
            else:
                stages["vmex_local_stability"] = {"reused_checkpoint": True}
        qualification = read(local_path) if local_path.exists() else None
        state, reasons = classify(freegs, qualification, failure)
        current = candidate["equilibrium_profile_parameters"]["current_profile"]
        row = {
            "schema_version": "1.0.0",
            "protocol_id": args.protocol_id,
            "candidate_result_hash": candidate["result_hash"],
            "candidate_graph_hash": candidate["graph_hash"],
            "current_alpha_m": float(current["alpha_m"]),
            "current_alpha_n": float(current["alpha_n"]),
            "current_edge_tilt": (None if "edge_tilt" not in current else
                                  float(current["edge_tilt"])),
            "current_edge_power": (None if "edge_power" not in current else
                                   float(current["edge_power"])),
            "current_shoulder_amplitude": (None if "shoulder_amplitude" not in current else
                                           float(current["shoulder_amplitude"])),
            "current_shoulder_power": (None if "shoulder_power" not in current else
                                       float(current["shoulder_power"])),
            "elongation": float(candidate["operating_point"]["elongation"]),
            "triangularity": float(candidate["operating_point"]["triangularity"]),
            "is_parent_shape_control": bool(
                candidate.get("shape_repair_declaration", {}).get(
                    "is_parent_shape_control", False)),
            "identity_fields_used_for_provider_routing": False,
            "stages": stages,
            "freegs_status": freegs.get("status"),
            "freegs_failed_gates": list(freegs.get("failed_gates", ())),
            "local_stability_executed": qualification is not None,
            "numerical_failures": ([] if qualification is None else
                                   list(qualification.get("numerical_failures", ()))),
            "physical_failures": ([] if qualification is None else
                                  list(qualification.get("physical_failures", ()))),
            "glasser_maximum": (None if qualification is None else
                qualification["providers"]["local_stability"]["glasser"]
                ["interior_summary"]["maximum"]),
            "mercier_minimum": (None if qualification is None else
                qualification["providers"]["local_stability"]["mercier"]
                ["interior_summary"]["minimum"]),
            "ballooning_maximum": (None if qualification is None else
                qualification["providers"]["local_stability"]
                ["infinite_n_ballooning"]["refined_maximum"]),
            "candidate_state": state,
            "reasons": reasons,
            "unsupported": False,
            "partial_subgraph_promotion_allowed": False,
            "whole_device_credible": False,
            "validation_credit": False,
        }
        row["row_hash"] = canonical_hash(row)
        write(row_path, row)
        rows.append(row)
        print(json.dumps({
            "request_index": request_index,
            "current_profile": [row["current_alpha_m"], row["current_alpha_n"]],
            "candidate_state": state, "reasons": reasons,
            "glasser_maximum": row["glasser_maximum"],
        }, sort_keys=True), flush=True)

    rows.sort(key=lambda row: (
        row["elongation"], row["triangularity"],
        row["current_alpha_m"], row["current_alpha_n"],
        -99.0 if row["current_edge_tilt"] is None else row["current_edge_tilt"],
        -99.0 if row["current_edge_power"] is None else row["current_edge_power"],
        -99.0 if row.get("current_shoulder_amplitude") is None else
        row["current_shoulder_amplitude"]))
    histogram = {}
    for row in rows:
        histogram[row["candidate_state"]] = histogram.get(row["candidate_state"], 0) + 1
    parent_local = read(root / args.control_parent_local)
    parent_glasser = parent_local["providers"]["local_stability"]["glasser"][
        "interior_summary"]["maximum"]
    campaign_kind = generation.get("campaign_kind", "current_profile")
    edge_campaign = any(row["current_edge_tilt"] is not None for row in rows)
    control = next((row for row in rows if (
        row["is_parent_shape_control"] if campaign_kind == "boundary_shape" else
        (row["current_edge_tilt"] == 0.0 if edge_campaign else
         row["current_alpha_m"] == 2.0 and row["current_alpha_n"] == 1.0))), None)
    control_relative = (None if control is None else abs(
        control["glasser_maximum"] - parent_glasser) / abs(parent_glasser))
    control_pass = control is not None and control_relative <= 0.02
    body = {
        "schema_version": "1.0.0",
        "protocol_id": args.protocol_id,
        "status": "complete" if len(rows) == len(proposals) and control_pass else "fail",
        "source_generation_acceptance_hash": generation["acceptance_hash"],
        "proposal_count": len(proposals),
        "processed_count": len(rows),
        "candidate_state_histogram": histogram,
        "local_stability_survivor_hashes": sorted(
            row["candidate_result_hash"] for row in rows
            if row["candidate_state"] == "local_stability_survivor"),
        "best_glasser_maximum": min(
            (row["glasser_maximum"] for row in rows
             if row["glasser_maximum"] is not None), default=None),
        "matched_parent_control": {
            "status": "pass" if control_pass else "fail",
            "parent_glasser_maximum": parent_glasser,
            "control_glasser_maximum": None if control is None else control["glasser_maximum"],
            "relative_difference": control_relative,
        },
        "unsupported_candidate_count": 0,
        "provider_system_failure_count": histogram.get("provider_system_failure", 0),
        "partial_subgraph_promotion_allowed": False,
        "validation_pass_count": 0,
        "credible_new_device_count": 0,
        "candidate_rows": rows,
        "claim_boundary": (
            "This capability-scoped campaign varies only its explicitly declared design "
            "variables and reruns the bound equilibrium and local-stability chain. A "
            "local survivor is not a transport, engineering, validation, or whole-device "
            "survivor."
        ),
    }
    body["acceptance_hash"] = canonical_hash(body)
    write(run / "acceptance.json", body)
    print(json.dumps({
        "status": body["status"], "proposal_count": len(proposals),
        "candidate_state_histogram": histogram,
        "local_stability_survivor_count": len(body["local_stability_survivor_hashes"]),
        "best_glasser_maximum": body["best_glasser_maximum"],
        "acceptance_hash": body["acceptance_hash"],
    }, sort_keys=True))
    return 0 if body["status"] == "complete" and not histogram.get(
        "provider_system_failure", 0) else 2


if __name__ == "__main__":
    raise SystemExit(main())
