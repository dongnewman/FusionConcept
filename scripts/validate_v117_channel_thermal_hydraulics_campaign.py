#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def canonical_hash(root: Path, path: Path) -> str:
    code = (
        "using FusionConceptAI,JSON3; "
        "d=FusionConceptAI._v93_plain(JSON3.read(read(ARGS[1],String),Dict{String,Any})); "
        "pop!(d,\"acceptance_hash\",nothing); print(canonical_hash(d))"
    )
    result = subprocess.run(["julia", f"--project={root}", "-e", code, str(path)],
                            check=True, capture_output=True, text=True)
    return result.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", required=True)
    args = parser.parse_args(); root = Path(args.project_root).resolve()
    path = root / "runs" / "v117_channel_thermal_hydraulics_20260830" / "acceptance.json"
    body = json.loads(path.read_text(encoding="utf-8")); stored = body.pop("acceptance_hash")
    assert stored == canonical_hash(root, path)
    stream = path.parent / "channel_results.jsonl"
    assert hashlib.sha256(stream.read_bytes()).hexdigest() == \
        body["channel_result_stream_sha256"]
    rows = [json.loads(line) for line in stream.read_text(encoding="utf-8").splitlines()
            if line.strip()]
    assert len(rows) == body["channel_result_stream_row_count"]
    assert body["status"] == "complete"
    assert body["reference_regression_pass_count"] == 2
    assert body["reference_bypass_count"] == 0
    assert body["source_assembly_count"] == 18
    assert body["channel_overlay_count"] == 540
    assert body["channel_thermal_hydraulics_survivor_count"] == 101
    assert body["unique_survivor_assembly_count"] == 12
    assert body["unique_survivor_source_candidate_count"] == 6
    assert body["channel_thermal_hydraulics_reject_count"] == 439
    assert body["blocker_histogram"] == {
        "loss_of_flow_structure_temperature": 360,
        "nominal_structure_temperature": 30,
        "updated_net_electric_power": 137,
    }
    assert body["unsupported_candidate_count"] == 0
    assert body["provider_system_failure_count"] == 0
    assert body["whole_device_credible_count"] == 0
    assert body["validation_pass_count"] == 0
    assert body["partial_subgraph_promotion_allowed"] is False
    assert all(row["unsupported_candidate_classification_used"] is False for row in rows)
    assert any(row["status"] == "pass" for row in rows)
    assert any(row["status"] == "fail" for row in rows)
    print(json.dumps({"status": "pass", "acceptance_hash": stored,
                      "survivor_count": 101, "whole_device_credible_count": 0},
                     sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
