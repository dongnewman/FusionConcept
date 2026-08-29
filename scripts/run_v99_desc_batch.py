#!/usr/bin/env python3
"""Parallel FreeGS-to-DESC v99 qualification of every v98 equilibrium survivor."""

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


def run_one(job: tuple[dict, str, str, str, str, str, bool]) -> dict:
    candidate, freegs_result_raw, input_raw, output_raw, runner_raw, desc_python, reuse = job
    input_path = Path(input_raw)
    output_path = Path(output_raw)
    if reuse and output_path.is_file():
        artifact = json.loads(output_path.read_text(encoding="utf-8"))
        version = artifact.get("runner_version")
        reusable_version = (
            (version == "v100_shared_radial_build_cross_code_qualification_v1" and
             artifact.get("candidate_state") != "provider_system_fail") or
            (version == "v99_axisymmetric_cross_code_qualification_v2" and
             artifact.get("candidate_state") != "provider_system_fail") or
            (version == "v99_axisymmetric_cross_code_qualification_v1" and
             artifact.get("candidate_state") != "transformer_fit_fail")
        )
        if (artifact.get("candidate_result_hash") == candidate.get("result_hash") and
                reusable_version):
            return {
                "request_index": candidate["request_index"],
                "candidate_state": artifact["candidate_state"],
                "failed_gates": artifact["failed_gates"],
                "result_hash": artifact["result_hash"],
                "runner_version": artifact["runner_version"],
                "process_exit_code": 0,
            }
    input_path.write_text(json.dumps(candidate, indent=2, sort_keys=True) + "\n",
                          encoding="utf-8")
    process = subprocess.run(
        [sys.executable, runner_raw, "--input", str(input_path),
         "--freegs-result", freegs_result_raw, "--desc-python", desc_python,
         "--output", str(output_path)],
        capture_output=True, text=True, check=False,
    )
    if output_path.is_file():
        artifact = json.loads(output_path.read_text(encoding="utf-8"))
        return {
            "request_index": candidate["request_index"],
            "candidate_state": artifact["candidate_state"],
            "failed_gates": artifact["failed_gates"],
            "result_hash": artifact["result_hash"],
            "runner_version": artifact["runner_version"],
            "process_exit_code": process.returncode,
        }
    return {
        "request_index": candidate["request_index"],
        "candidate_state": "provider_system_fail",
        "failed_gates": ["v99_runner_artifact_missing"],
        "result_hash": None,
        "runner_version": None,
        "process_exit_code": process.returncode,
        "stderr_tail": process.stderr[-2000:],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--freegs-acceptance", required=True)
    parser.add_argument("--freegs-results", required=True)
    parser.add_argument("--desc-python", required=True)
    parser.add_argument("--output-directory", required=True)
    parser.add_argument("--workers", type=int, default=3)
    parser.add_argument("--reuse-existing", action="store_true")
    parser.add_argument("--candidate-runner")
    parser.add_argument("--protocol-id",
                        default="fusionconceptai-v99-cross-code-qualification-20260829")
    args = parser.parse_args()
    source = Path(args.candidates).resolve()
    freegs_acceptance_path = Path(args.freegs_acceptance).resolve()
    freegs_results = Path(args.freegs_results).resolve()
    output = Path(args.output_directory).resolve()
    inputs = output / "inputs"
    results = output / "results"
    inputs.mkdir(parents=True, exist_ok=True)
    results.mkdir(parents=True, exist_ok=True)
    candidates = {
        int(item["request_index"]): item
        for item in (json.loads(line) for line in source.read_text(
            encoding="utf-8").splitlines() if line.strip())
    }
    freegs_acceptance = json.loads(
        freegs_acceptance_path.read_text(encoding="utf-8"))
    survivor_ids = sorted(int(row["request_index"])
                          for row in freegs_acceptance["rows"]
                          if row["status"] == "pass")
    if len(survivor_ids) != freegs_acceptance["status_histogram"].get("pass", 0):
        raise ValueError("FreeGS pass census is inconsistent")
    runner = (Path(args.candidate_runner).resolve() if args.candidate_runner else
              Path(__file__).with_name("run_v99_desc_candidate.py").resolve())
    desc_python = str(Path(args.desc_python).resolve())
    jobs = []
    for request_index in survivor_ids:
        if request_index not in candidates:
            raise ValueError(f"missing candidate {request_index}")
        freegs_result = freegs_results / f"freegs_{request_index:07d}.json"
        if not freegs_result.is_file():
            raise ValueError(f"missing FreeGS result for {request_index}")
        jobs.append((
            candidates[request_index], str(freegs_result),
            str(inputs / f"candidate_{request_index:07d}.json"),
            str(results / f"v99_{request_index:07d}.json"), str(runner),
            desc_python, args.reuse_existing,
        ))
    with ProcessPoolExecutor(max_workers=max(1, args.workers)) as executor:
        rows = list(executor.map(run_one, jobs))
    rows.sort(key=lambda row: row["request_index"])
    states = Counter(row["candidate_state"] for row in rows)
    failed = Counter(gate for row in rows for gate in row["failed_gates"])
    versions = Counter(str(row["runner_version"]) for row in rows
                       if row["runner_version"] is not None)
    system_failures = states.get("provider_system_fail", 0)
    artifact = {
        "schema_version": "1.0.0",
        "protocol_id": args.protocol_id,
        "status": "complete" if system_failures == 0 else "system_fail",
        "source_candidate_stream": source.name,
        "source_candidate_stream_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "source_freegs_acceptance_hash": freegs_acceptance["acceptance_hash"],
        "candidate_count": len(jobs), "processed_count": len(rows),
        "candidate_state_histogram": dict(sorted(states.items())),
        "runner_version_histogram": dict(sorted(versions.items())),
        "failed_gate_histogram": dict(sorted(failed.items())),
        "provider_system_failure_count": system_failures,
        "unsupported_candidate_count": 0,
        "whole_device_credible_count": 0,
        "validation_pass_count": 0,
        "rows": rows,
        "claim_boundary": (
            "A v99 pass covers cross-code fixed-boundary equilibrium and sampled "
            "Mercier/infinite-n ballooning only. It is not complete stability, transport, "
            "engineering, validation, whole-device feasibility, or credibility."
        ),
    }
    artifact["acceptance_hash"] = canonical_hash(artifact)
    path = output / "acceptance.json"
    partial = path.with_suffix(".json.partial")
    partial.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n",
                       encoding="utf-8")
    partial.replace(path)
    print(json.dumps({key: artifact[key] for key in (
        "status", "candidate_count", "candidate_state_histogram",
        "failed_gate_histogram", "acceptance_hash")}, sort_keys=True))
    return 0 if artifact["status"] == "complete" else 1


if __name__ == "__main__":
    raise SystemExit(main())
