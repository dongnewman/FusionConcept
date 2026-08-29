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
    path = root / "runs" / "v108_dynamic_fault_campaign_20260829" / "acceptance.json"
    body = json.loads(path.read_text(encoding="utf-8"))
    stored = body.pop("acceptance_hash")
    assert stored == julia_canonical_hash(root, path)
    assert body["status"] == "complete"
    assert body["source_assembly_count"] == 32
    assert body["controller_overlay_count"] == 128
    assert body["dynamic_fault_screen_survivor_count"] == 96
    assert body["dynamic_fault_screen_reject_count"] == 32
    assert body["candidate_state_histogram"] == {
        "dynamic_fault_screen_reject": 32,
        "dynamic_fault_screen_survivor": 96,
    }
    assert body["blocker_histogram"] == {
        "single_pf_coil_trip": 32, "vertical_displacement_event": 32}
    assert body["unsupported_candidate_count"] == 0
    assert body["provider_system_failure_count"] == 0
    assert body["whole_device_pass_count"] == 0
    assert body["whole_device_credible_count"] == 0
    assert body["validation_pass_count"] == 0
    print(json.dumps({"status": "pass", "acceptance_hash": stored,
                      "dynamic_fault_screen_survivor_count": 96}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
