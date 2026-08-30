#!/usr/bin/env python3
"""Fail-closed integrity checks for the v128 acceptance bundle."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


def canonical_hash(value: object) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    run = root / "runs" / "v128_vmex_transport_qualification_20260830"
    body = json.loads((run / "acceptance.json").read_text(encoding="utf-8"))
    claimed = body.pop("acceptance_hash")
    assert canonical_hash(body) == claimed
    body["acceptance_hash"] = claimed
    assert body["reference_regression_pass_count"] == 2
    assert body["reference_bypass_count"] == 0
    assert body["input_computational_survivor_count"] == 4
    assert body["candidate_state_histogram"] == {
        "numerical_vvuq_reject": 1, "physical_reject": 3}
    assert body["unsupported_candidate_count"] == 0
    assert body["provider_system_failure_count"] == 0
    assert body["advanced_numerical_survivor_count"] == 0
    assert body["credible_new_device_count"] == 0
    assert body["validation_pass_count"] == 0
    assert body["complete_stability_credit"] is False
    assert body["complete_transport_credit"] is False
    assert body["complete_engineering_credit"] is False
    assert body["partial_subgraph_promotion_allowed"] is False
    assert body["identity_fields_used_for_routing"] is False
    assert all(row["unsupported"] is False for row in body["candidate_rows"])
    assert all(row["whole_device_credible"] is False for row in body["candidate_rows"])
    assert all(item["status"] == "pass"
               for item in body["negative_controls"].values())
    order = body["stage_order"]
    assert order.index("candidate_bound_FreeGS_reproducibility_solve") < order.index(
        "VMEX_NEO_GKX_ESSOS_numerical_VVUQ")
    assert order.index("VMEX_NEO_GKX_ESSOS_numerical_VVUQ") < order.index(
        "validation_VVUQ")
    for name, expected in body["provider_source_hashes"].items():
        paths = {
            "sealed_freegs_runner": "scripts/freegs_runner.py",
            "shared_state_freegs_wrapper": "scripts/freegs_shared_state_runner_v119.py",
            "freegs_candidate_runner": "scripts/run_v98_freegs_candidate.py",
            "freegs_materializer": "scripts/materialize_v128_freegs_raw.py",
            "desc_exporter": "scripts/export_v128_desc_wout.py",
            "vmex_qualification_provider": "scripts/run_v128_vmex_qualification.py",
        }
        assert sha256_file(root / paths[name]) == expected
    # Evidence lookup is explicit so an omitted or renamed file fails closed.
    candidates = run / "candidates"
    for key, expected in body["evidence_file_hashes"].items():
        if key.startswith("freegs_recheck_"):
            path = candidates / f"{key}.json"
        elif key.startswith("qualification_"):
            path = candidates / f"{key}.json"
        elif key.startswith("export_"):
            path = candidates / f"export_recheck_{key.removeprefix('export_')}.json"
        elif key.startswith("wout_"):
            path = candidates / f"wout_recheck_{key.removeprefix('wout_')}.nc"
        else:
            raise AssertionError(f"unknown evidence key {key}")
        assert path.exists() and sha256_file(path) == expected
    print(json.dumps({
        "status": "pass",
        "acceptance_hash": claimed,
        "candidate_state_histogram": body["candidate_state_histogram"],
        "negative_control_count": len(body["negative_controls"]),
        "unsupported_candidate_count": body["unsupported_candidate_count"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
