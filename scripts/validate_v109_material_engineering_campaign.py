#!/usr/bin/env python3
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = Path(args.project_root).resolve()
    path = root / "runs" / "v109_material_engineering_campaign_20260829" / "acceptance.json"
    body = json.loads(path.read_text(encoding="utf-8"))
    saved_hash = body.pop("acceptance_hash")
    assert julia_canonical_hash(root, path) == saved_hash
    body["acceptance_hash"] = saved_hash
    assert body["status"] == "complete"
    assert body["reference_regression_status"] == "pass"
    assert body["reference_regression_pass_count"] == 2
    assert body["reference_bypass_count"] == 0
    assert body["input_dynamic_survivor_count"] == 96
    assert body["material_screen_reject_count"] == 96
    assert body["material_screen_survivor_count"] == 0
    assert body["candidate_state_histogram"] == {"material_screen_reject": 96}
    assert body["blocker_histogram"] == {
        "blanket_loss_of_flow_temperature": 96,
        "full_nuclear_radial_build": 96,
    }
    assert body["unsupported_candidate_count"] == 0
    assert body["provider_system_failure_count"] == 0
    assert body["whole_device_pass_count"] == 0
    assert body["whole_device_credible_count"] == 0
    assert body["validation_pass_count"] == 0
    assert body["complete_engineering_obligation_credit"] is False
    assert all(row["candidate_state"] == "material_screen_reject" for row in body["rows"])
    print(json.dumps({
        "status": "pass",
        "acceptance_hash": saved_hash,
        "material_screen_reject_count": 96,
        "unsupported_candidate_count": 0,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
