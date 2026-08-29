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
    path = root / "runs" / "v104_whole_device_preflight_20260829" / "acceptance.json"
    body = json.loads(path.read_text(encoding="utf-8"))
    stored = body.pop("acceptance_hash")
    assert stored == julia_canonical_hash(root, path)
    assert body["status"] == "not_ready"
    assert body["reference_regression_pass_count"] == 2
    assert body["reference_bypass_count"] == 0
    assert body["whole_device_search_authorized"] is False
    assert body["unsupported_candidate_count"] == 0
    assert body["physical_reject_count_added_by_preflight"] == 0
    assert body["physical_pass_count_added_by_preflight"] == 0
    row = body["survivor_rows"][0]
    assert row["candidate_state"] == "not_adjudicated_provider_gap"
    preflight = row["preflight"]
    assert preflight["closed_obligation_count"] == 2
    assert preflight["required_obligation_count"] == 9
    assert preflight["provider_gap_count"] == 1
    assert preflight["fidelity_gap_count"] == 6
    print(json.dumps({
        "acceptance_hash": stored,
        "closed_obligation_count": 2,
        "required_obligation_count": 9,
        "status": "pass",
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
