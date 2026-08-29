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
    directory = root / "runs" / "v106_whole_device_assembly_screen_20260829"
    path = directory / "acceptance.json"
    body = json.loads(path.read_text(encoding="utf-8"))
    stored = body.pop("acceptance_hash")
    assert stored == julia_canonical_hash(root, path)
    assert body["status"] == "complete"
    assert body["assembly_count"] == 64
    assert body["assembly_reject_count"] == 32
    assert body["screen_survivor_count"] == 32
    assert body["candidate_state_histogram"] == {
        "whole_device_assembly_reject": 32,
        "whole_device_screen_survivor": 32,
    }
    assert body["blocker_histogram"] == {
        "blanket_thickness": 16, "shield_thickness": 16}
    assert body["unsupported_candidate_count"] == 0
    assert body["provider_system_failure_count"] == 0
    assert body["whole_device_pass_count"] == 0
    assert body["whole_device_credible_count"] == 0
    assert body["validation_pass_count"] == 0
    survivors = [json.loads(line) for line in
                 (directory / "screen_survivors.jsonl").read_text(
                     encoding="utf-8").splitlines() if line.strip()]
    assert len(survivors) == 32
    assert all(item["status"] == "pass" for item in survivors)
    print(json.dumps({"status": "pass", "acceptance_hash": stored,
                      "screen_survivor_count": 32}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
