#!/usr/bin/env python3
"""Validate the sealed v102 inverse-reference candidate experiment."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", required=True)
    args = parser.parse_args()
    root = Path(args.project_root).resolve()
    path = root / "runs" / "v102_inverse_reference_candidate_experiment_20260829" / "acceptance.json"
    body = json.loads(path.read_text(encoding="utf-8"))
    stored = body.pop("acceptance_hash")
    assert stored == canonical_hash(body)
    assert body["status"] == "complete"
    assert body["selector_acceptance"] == "fail"
    assert body["reference_subject_count"] == 2
    assert body["inverse_representability_pass_count"] == 2
    assert body["v89_reduced_chain_pass_count"] == 2
    assert body["v96_inverse_graph_numerical_pass_count"] == 2
    assert body["current_reference_control_pass_count"] == 2
    assert body["ordinary_candidate_pass_count"] == 0
    assert body["ordinary_candidate_current_filter_reject_count"] == 2
    assert body["ordinary_candidate_physical_reject_count"] == 0
    assert body["reference_control_bypass_count"] == 2
    assert body["selector_applicability_mismatch_count"] == 2
    assert body["unsupported_candidate_count"] == 0
    assert body["provider_system_failure_count"] == 0
    assert body["validation_pass_count"] == 0
    assert body["whole_device_credible_count"] == 0
    assert all(row["v96_whole_graph_closed"] for row in body["rows"])
    assert all(row["v96_numerical_vvuq_status"] == "pass" for row in body["rows"])
    assert all(row["ordinary_candidate_physics_screen_status"] == "fail" for row in body["rows"])
    assert all(row["ordinary_candidate_final_status"] == "selector_applicability_reject"
               for row in body["rows"])
    assert all(row["reference_control_bypass_detected"] for row in body["rows"])
    assert all(not row["selector_applicability"]["rejection_is_device_physics_evidence"]
               for row in body["rows"])
    print(json.dumps({"status": "pass", "acceptance_hash": stored,
                      "ordinary_candidate_pass_count": 0,
                      "reference_control_bypass_count": 2}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
