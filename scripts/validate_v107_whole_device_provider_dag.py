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
        ["julia", f"--project={root}", "-e", code, str(path)],
        check=True, capture_output=True, text=True,
    )
    return process.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", required=True)
    args = parser.parse_args()
    root = Path(args.project_root).resolve()
    path = root / "runs" / "v107_whole_device_provider_dag_20260829" / "acceptance.json"
    body = json.loads(path.read_text(encoding="utf-8"))
    stored = body.pop("acceptance_hash")
    assert stored == julia_canonical_hash(root, path)
    assert body["status"] == "available_provider_dag_complete"
    assert body["input_survivor_count"] == 32
    assert body["available_provider_dag_pass_count"] == 32
    assert body["candidate_state_histogram"] == {"high_fidelity_pending": 32}
    assert body["complete_whole_device_preflight_count"] == 0
    assert body["unsupported_candidate_count"] == 0
    assert body["provider_system_failure_count"] == 0
    assert body["whole_device_pass_count"] == 0
    assert body["whole_device_credible_count"] == 0
    assert body["validation_pass_count"] == 0
    assert body["high_cost_expansion_authorized"] is False
    print(json.dumps({"status": "pass", "acceptance_hash": stored,
                      "available_provider_dag_pass_count": 32}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
