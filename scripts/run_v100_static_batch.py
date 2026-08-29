#!/usr/bin/env python3
"""Run v100 static PF robustness only for sampled ideal-MHD survivors."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def run_one(job: tuple[dict, str, str, str, str, str]) -> dict:
    candidate, freegs_raw, cross_raw, input_raw, output_raw, runner_raw = job
    input_path, output_path = Path(input_raw), Path(output_raw)
    input_path.write_text(json.dumps(candidate, indent=2, sort_keys=True) + "\n",
                          encoding="utf-8")
    process = subprocess.run([
        sys.executable, runner_raw, "--candidate", str(input_path),
        "--freegs-verification", freegs_raw, "--cross-code-result", cross_raw,
        "--output", str(output_path)], capture_output=True, text=True, check=False)
    if output_path.is_file():
        artifact = json.loads(output_path.read_text(encoding="utf-8"))
        return {"request_index": candidate["request_index"],
                "candidate_state": artifact["candidate_state"],
                "failed_gates": artifact["failed_gates"],
                "result_hash": artifact["result_hash"],
                "process_exit_code": process.returncode}
    return {"request_index": candidate["request_index"],
            "candidate_state": "provider_system_fail",
            "failed_gates": ["static_runner_artifact_missing"],
            "result_hash": None, "process_exit_code": process.returncode,
            "stderr_tail": process.stderr[-2000:]}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--freegs-results", required=True)
    parser.add_argument("--cross-code-acceptance", required=True)
    parser.add_argument("--cross-code-results", required=True)
    parser.add_argument("--output-directory", required=True)
    parser.add_argument("--workers", type=int, default=2)
    args = parser.parse_args()
    source = Path(args.candidates).resolve()
    freegs_results = Path(args.freegs_results).resolve()
    cross_acceptance_path = Path(args.cross_code_acceptance).resolve()
    cross_results = Path(args.cross_code_results).resolve()
    output = Path(args.output_directory).resolve()
    inputs, results = output / "inputs", output / "results"
    inputs.mkdir(parents=True, exist_ok=True)
    results.mkdir(parents=True, exist_ok=True)
    candidates = {int(item["request_index"]): item for item in
                  (json.loads(line) for line in source.read_text(
                      encoding="utf-8").splitlines() if line.strip())}
    cross_acceptance = json.loads(cross_acceptance_path.read_text(encoding="utf-8"))
    survivor_ids = sorted(int(row["request_index"])
                          for row in cross_acceptance["rows"]
                          if row["candidate_state"] == "sampled_ideal_mhd_candidate")
    runner = Path(__file__).with_name("run_v100_freegs_static_robustness.py").resolve()
    jobs = []
    for request_index in survivor_ids:
        candidate = candidates[request_index]
        freegs = freegs_results / f"freegs_{request_index}.json"
        cross = cross_results / f"v99_{request_index:07d}.json"
        if not freegs.is_file() or not cross.is_file():
            raise ValueError(f"missing upstream artifact for {request_index}")
        jobs.append((candidate, str(freegs), str(cross),
                     str(inputs / f"candidate_{request_index}.json"),
                     str(results / f"static_{request_index}.json"), str(runner)))
    with ProcessPoolExecutor(max_workers=max(1, args.workers)) as executor:
        rows = list(executor.map(run_one, jobs))
    rows.sort(key=lambda row: row["request_index"])
    states = Counter(row["candidate_state"] for row in rows)
    failures = Counter(gate for row in rows for gate in row["failed_gates"])
    system_failures = states.get("provider_system_fail", 0)
    artifact = {
        "schema_version": "1.0.0",
        "protocol_id": "fusionconceptai-v100-static-robustness-batch-20260829",
        "status": "complete" if system_failures == 0 else "system_fail",
        "source_candidate_stream_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "source_cross_code_acceptance_hash": cross_acceptance["acceptance_hash"],
        "candidate_count": len(jobs), "processed_count": len(rows),
        "candidate_state_histogram": dict(sorted(states.items())),
        "failed_gate_histogram": dict(sorted(failures.items())),
        "provider_system_failure_count": system_failures,
        "unsupported_candidate_count": 0,
        "validation_pass_count": 0,
        "whole_device_credible_count": 0,
        "rows": rows,
        "claim_boundary": "Static PF perturbation and explicit radial-build engineering "
                          "proxies only; no complete engineering or validation credit.",
    }
    artifact["acceptance_hash"] = canonical_hash(artifact)
    path = output / "acceptance.json"
    partial = path.with_suffix(".json.partial")
    partial.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n",
                       encoding="utf-8")
    partial.replace(path)
    print(json.dumps({key: artifact[key] for key in
                      ("status", "candidate_count", "candidate_state_histogram",
                       "failed_gate_histogram", "acceptance_hash")}, sort_keys=True))
    return 0 if artifact["status"] == "complete" else 1


if __name__ == "__main__":
    raise SystemExit(main())
