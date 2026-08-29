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
    path = root / "runs" / "v103_mission_aware_reference_and_candidate_rescreen_20260829" / "acceptance.json"
    body = json.loads(path.read_text(encoding="utf-8"))
    stored = body.pop("acceptance_hash")
    assert stored == julia_canonical_hash(root, path)
    refs = body["reference_acceptance"]
    candidates = body["candidate_rescreen"]
    assert body["status"] == "complete"
    assert refs["status"] == "pass"
    assert refs["reference_regression_pass_count"] == 2
    assert refs["old_reference_bypass_count"] == 2
    assert refs["new_reference_bypass_count"] == 0
    assert refs["full_qualification_pass_count"] == 0
    assert refs["validation_pass_count"] == 0
    assert candidates["candidate_count"] == 79
    assert candidates["candidate_state_histogram"] == {
        "physical_reject": 78, "qualification_incomplete": 1}
    assert body["unsupported_candidate_count"] == 0
    assert body["provider_system_failure_count"] == 0
    assert body["whole_device_credible_count"] == 0
    assert body["validation_pass_count"] == 0
    print(json.dumps({"status": "pass", "acceptance_hash": stored,
                      "reference_regression_pass_count": 2,
                      "candidate_count": 79}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
