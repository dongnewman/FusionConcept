#!/usr/bin/env python3
"""Checkpointed high-fidelity local-stability rescreen of the v126 frontier."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import time
from pathlib import Path


PROTOCOL_ID = "fusionconceptai-v129-glasser-frontier-20260830"


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
             stage_failure: str | None) -> tuple[str, list[str]]:
    if stage_failure is not None:
        return "provider_system_failure", [stage_failure]
    if freegs.get("status") != "pass":
        return "physical_reject", list(freegs.get("failed_gates", ()))
    if qualification is None:
        return "provider_system_failure", ["qualification_missing"]
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
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    source = root / "runs" / "v126_frontier_static_repair_20260830"
    run = root / "runs" / "v129_glasser_frontier_20260830"
    evidence = run / "evidence"
    desc_acceptance = read(source / "desc" / "acceptance.json")
    selected = sorted(
        int(row["request_index"]) for row in desc_acceptance["rows"]
        if row["candidate_state"] == "sampled_ideal_mhd_candidate")
    if args.max_candidates is not None:
        selected = selected[:args.max_candidates]
    rows = []
    for request_index in selected:
        token = str(request_index)
        row_path = evidence / f"row_{token}.json"
        if row_path.exists() and not args.force:
            rows.append(read(row_path))
            continue
        candidate_path = source / "freegs" / "inputs" / f"candidate_{token}.json"
        candidate = read(candidate_path)
        freegs_path = evidence / f"freegs_{token}.json"
        raw_path = evidence / f"freegs_raw_{token}.json"
        wout_path = evidence / f"wout_{token}.nc"
        manifest_path = evidence / f"export_{token}.json"
        qualification_path = evidence / f"local_stability_{token}.json"
        stages = {}
        failure = None
        stages["freegs_recheck"] = run_stage([
            str(root / ".venv-freegs" / "Scripts" / "python.exe"),
            str(root / "scripts" / "run_v98_freegs_candidate.py"),
            "--input", str(candidate_path), "--output", str(freegs_path),
        ])
        if not freegs_path.exists():
            failure = "freegs_result_missing"
            freegs = {"status": "error", "failed_gates": []}
        else:
            freegs = read(freegs_path)
        if failure is None and freegs.get("status") == "pass":
            stages["freegs_materialization"] = run_stage([
                str(root / ".venv-freegs" / "Scripts" / "python.exe"),
                str(root / "scripts" / "materialize_v128_freegs_raw.py"),
                "--candidate", str(candidate_path), "--verification", str(freegs_path),
                "--output", str(raw_path),
            ])
            if stages["freegs_materialization"]["exit_code"] != 0:
                failure = "freegs_materialization_failure"
        if failure is None and freegs.get("status") == "pass":
            stages["desc_wout_export"] = run_stage([
                str(root / ".venv-desc" / "Scripts" / "python.exe"),
                str(root / "scripts" / "export_v128_desc_wout.py"),
                "--candidate", str(candidate_path), "--freegs-result", str(raw_path),
                "--wout", str(wout_path), "--manifest", str(manifest_path),
            ])
            if stages["desc_wout_export"]["exit_code"] != 0:
                failure = "desc_wout_export_failure"
        if failure is None and freegs.get("status") == "pass":
            stages["vmex_local_stability"] = run_stage([
                str(root / ".conda-vmex" / "python.exe"),
                str(root / "scripts" / "run_v128_vmex_qualification.py"),
                "--candidate", str(candidate_path), "--manifest", str(manifest_path),
                "--wout", str(wout_path), "--output", str(qualification_path),
                "--local-stability-only",
            ])
            if stages["vmex_local_stability"]["exit_code"] not in (0, 2):
                failure = "vmex_local_stability_crash"
        qualification = read(qualification_path) if qualification_path.exists() else None
        state, reasons = classify(freegs, qualification, failure)
        row = {
            "schema_version": "1.0.0",
            "protocol_id": PROTOCOL_ID,
            "candidate_result_hash": candidate["result_hash"],
            "candidate_graph_hash": candidate["graph_hash"],
            "candidate_solver_input_hash": candidate["solver_input_hash"],
            "selection_source": "v126_sampled_ideal_mhd_frontier",
            "identity_fields_used_for_provider_routing": False,
            "stages": stages,
            "freegs_status": freegs.get("status"),
            "freegs_failed_gates": list(freegs.get("failed_gates", ())),
            "local_stability_executed": qualification is not None,
            "numerical_failures": ([] if qualification is None else
                                   list(qualification.get("numerical_failures", ()))),
            "physical_failures": ([] if qualification is None else
                                  list(qualification.get("physical_failures", ()))),
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
            "request_index": request_index, "candidate_state": state,
            "reasons": reasons, "row_hash": row["row_hash"],
        }, sort_keys=True), flush=True)

    rows.sort(key=lambda row: row["candidate_result_hash"])
    histogram = {}
    for row in rows:
        histogram[row["candidate_state"]] = histogram.get(row["candidate_state"], 0) + 1
    body = {
        "schema_version": "1.0.0",
        "protocol_id": PROTOCOL_ID,
        "status": "complete" if len(rows) == len(selected) else "incomplete",
        "source_desc_acceptance_hash": desc_acceptance["acceptance_hash"],
        "selected_candidate_count": len(selected),
        "processed_candidate_count": len(rows),
        "candidate_state_histogram": histogram,
        "local_stability_survivor_hashes": sorted(
            row["candidate_result_hash"] for row in rows
            if row["candidate_state"] == "local_stability_survivor"),
        "unsupported_candidate_count": 0,
        "provider_system_failure_count": histogram.get("provider_system_failure", 0),
        "partial_subgraph_promotion_allowed": False,
        "validation_pass_count": 0,
        "credible_new_device_count": 0,
        "candidate_rows": rows,
        "claim_boundary": (
            "v129 is a fail-closed local-stability prefilter over every v126 sampled "
            "ideal-MHD candidate. A local survivor must still execute the remaining "
            "transport, alpha, engineering, whole-graph, numerical and validation "
            "stages; no partial-subgraph whole-device credit is granted."
        ),
    }
    body["acceptance_hash"] = canonical_hash(body)
    write(run / "acceptance.json", body)
    print(json.dumps({
        "status": body["status"], "selected_candidate_count": len(selected),
        "candidate_state_histogram": histogram,
        "local_stability_survivor_count": len(body["local_stability_survivor_hashes"]),
        "acceptance_hash": body["acceptance_hash"],
    }, sort_keys=True))
    return 0 if not histogram.get("provider_system_failure", 0) else 2


if __name__ == "__main__":
    raise SystemExit(main())
