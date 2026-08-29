#!/usr/bin/env python3
"""Parallel fail-closed FreeGS verification for all retained v100 designs."""

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


def run_one(job: tuple[dict, str, str, str]) -> dict:
    candidate, input_path_raw, result_path_raw, runner_raw = job
    input_path, result_path = Path(input_path_raw), Path(result_path_raw)
    input_path.write_text(json.dumps(candidate, indent=2, sort_keys=True) + "\n",
                          encoding="utf-8")
    process = subprocess.run(
        [sys.executable, runner_raw, "--input", str(input_path), "--output",
         str(result_path)], capture_output=True, text=True, check=False)
    if result_path.is_file():
        artifact = json.loads(result_path.read_text(encoding="utf-8"))
        return {"request_index": candidate["request_index"],
                "parent_request_index": candidate["parent_request_index"],
                "status": artifact["status"],
                "failed_gates": artifact["failed_gates"],
                "result_hash": artifact["result_hash"],
                "process_exit_code": process.returncode}
    return {"request_index": candidate["request_index"],
            "parent_request_index": candidate["parent_request_index"],
            "status": "error", "failed_gates": ["runner_error"],
            "result_hash": None, "process_exit_code": process.returncode,
            "stderr_tail": process.stderr[-2000:]}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-directory", required=True)
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    source = Path(args.input).resolve()
    output = Path(args.output_directory).resolve()
    inputs, results = output / "inputs", output / "results"
    inputs.mkdir(parents=True, exist_ok=True)
    results.mkdir(parents=True, exist_ok=True)
    runner = Path(__file__).with_name("run_v100_freegs_candidate.py").resolve()
    candidates = [json.loads(line) for line in source.read_text(
        encoding="utf-8").splitlines() if line.strip()]
    jobs = [(item, str(inputs / f"candidate_{item['request_index']}.json"),
             str(results / f"freegs_{item['request_index']}.json"), str(runner))
            for item in candidates]
    with ProcessPoolExecutor(max_workers=max(1, args.workers)) as executor:
        rows = list(executor.map(run_one, jobs))
    rows.sort(key=lambda row: row["request_index"])
    status_histogram = Counter(row["status"] for row in rows)
    failed_histogram = Counter(gate for row in rows for gate in row["failed_gates"])
    artifact = {
        "schema_version": "1.0.0",
        "protocol_id": "fusionconceptai-v100-shared-radial-build-freegs-batch-v1-20260829",
        "source_candidate_stream": source.name,
        "source_candidate_stream_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "candidate_count": len(candidates), "processed_count": len(rows),
        "status": "complete" if not status_histogram.get("error", 0) else "system_fail",
        "status_histogram": dict(sorted(status_histogram.items())),
        "failed_gate_histogram": dict(sorted(failed_histogram.items())),
        "rows": rows, "validation_pass_count": 0,
        "unsupported_candidate_count": 0,
        "identity_fields_used_for_routing": False,
        "claim_boundary": (
            "Candidate-bound FreeGS equilibrium and numerical VVUQ only. Subset passes "
            "cannot be promoted to whole-device, stability, engineering, or validation pass."),
    }
    artifact["acceptance_hash"] = canonical_hash(artifact)
    path = output / "acceptance.json"
    temporary = path.with_suffix(".json.partial")
    temporary.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n",
                         encoding="utf-8")
    temporary.replace(path)
    print(json.dumps({key: artifact[key] for key in
                      ("status", "candidate_count", "status_histogram",
                       "failed_gate_histogram", "acceptance_hash")}, sort_keys=True))
    return 0 if artifact["status"] == "complete" else 1


if __name__ == "__main__":
    raise SystemExit(main())
