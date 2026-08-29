#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


def julia_canonical_hash(root: Path, path: Path) -> str:
    code = (
        "using FusionConceptAI,JSON3; "
        "d=FusionConceptAI._v93_plain(JSON3.read(read(ARGS[1],String),Dict{String,Any})); "
        "pop!(d,\"acceptance_hash\",nothing); print(canonical_hash(d))"
    )
    process = subprocess.run(
        ["julia", f"--project={root}", "-e", code, str(path)], check=True,
        capture_output=True, text=True)
    return process.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", required=True)
    args = parser.parse_args()
    root = Path(args.project_root).resolve()
    path = root / "runs" / "v110_material_closed_frontier_20260829" / "acceptance.json"
    body = json.loads(path.read_text(encoding="utf-8"))
    stored = body.pop("acceptance_hash")
    assert stored == julia_canonical_hash(root, path)
    assert body["status"] == "complete"
    assert body["reference_regression_pass_count"] == 2
    assert body["reference_bypass_count"] == 0
    assert body["candidate_count"] == 40
    assert body["freegs_pass_count"] == 39
    assert body["sampled_ideal_mhd_candidate_count"] == 2
    assert body["static_robustness_pass_count"] == 0
    assert body["high_fidelity_frontier_survivor_count"] == 0
    assert body["candidate_state_histogram"] == {"physical_reject": 40}
    assert body["blocker_histogram"] == {
        "cross_code_equilibrium": 5,
        "free_boundary_equilibrium": 1,
        "sampled_local_ideal_mhd": 32,
        "static_engineering_proxy": 2,
    }
    assert body["unsupported_candidate_count"] == 0
    assert body["provider_system_failure_count"] == 0
    assert body["whole_device_credible_count"] == 0
    print(json.dumps({"status": "pass", "acceptance_hash": stored,
                      "high_fidelity_frontier_survivor_count": 0,
                      "provider_system_failure_count": 0}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
