#!/usr/bin/env python3
"""Seal the corrected shared-state audit without rewriting v118 history."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    directory = root / "runs" / "v119_shared_state_binding_20260830"
    reference = read(directory / "reference_v103" / "acceptance.json")
    repaired_freegs = read(directory / "freegs" / "acceptance.json")
    repaired_desc = read(directory / "desc" / "acceptance.json")
    low_freegs = read(directory / "low_beta_freegs" / "acceptance.json")
    low_desc = read(directory / "low_beta_desc" / "acceptance.json")
    assert reference["reference_acceptance"]["reference_regression_pass_count"] == 2
    assert reference["reference_acceptance"]["new_reference_bypass_count"] == 0
    assert repaired_freegs["status_histogram"] == {"pass": 9}
    assert repaired_desc["candidate_state_histogram"] == {
        "cross_code_equilibrium_fail": 9}
    assert low_freegs["status_histogram"] == {"fail": 7, "pass": 23}
    assert low_desc["candidate_state_histogram"] == {
        "cross_code_equilibrium_fail": 3, "stability_screen_fail": 20}
    source = {
        "reference": reference["acceptance_hash"],
        "repaired_freegs": repaired_freegs["acceptance_hash"],
        "repaired_desc": repaired_desc["acceptance_hash"],
        "low_beta_freegs": low_freegs["acceptance_hash"],
        "low_beta_desc": low_desc["acceptance_hash"],
    }
    body = {
        "schema_version": "1.0.0",
        "protocol_id": "fusionconceptai-v119-shared-state-binding-20260830",
        "status": "complete",
        "source_acceptance_hashes": source,
        "reference_regression_pass_count": 2,
        "reference_bypass_count": 0,
        "repaired_v114_freegs_pass_count": 9,
        "repaired_v114_desc_equilibrium_fail_count": 9,
        "low_beta_source_count": 30,
        "low_beta_freegs_pass_count": 23,
        "low_beta_freegs_reject_count": 7,
        "low_beta_desc_equilibrium_fail_count": 3,
        "low_beta_desc_mercier_fail_count": 20,
        "current_shared_state_survivor_count": 0,
        "withdrawn_v118_sampled_survivor_count": 101,
        "withdrawal_reason": (
            "v118 FreeGS and DESC artifacts did not bind the same volume-average "
            "pressure, beta and integrated toroidal-flux state"),
        "v118_history_modified": False,
        "unsupported_candidate_count": 0,
        "provider_system_failure_count": 0,
        "validation_vvuq_status": "not_executed_upstream_no_survivor",
        "validation_pass_count": 0,
        "whole_device_credible_count": 0,
        "partial_subgraph_promotion_allowed": False,
        "claim_boundary": (
            "v119 corrects cross-code state identity and withdraws current survivor "
            "credit from underbound v118 rows. It does not reinterpret those rows as "
            "physical failures, erase sealed history, or grant validation credit."),
    }
    body["acceptance_hash"] = canonical_hash(body)
    path = directory / "acceptance.json"
    temporary = path.with_suffix(".json.partial")
    temporary.write_text(json.dumps(body, indent=2, sort_keys=True) + "\n",
                         encoding="utf-8")
    temporary.replace(path)
    report = f"""# v119 shared-state binding audit

ITER/C-2W scoped regression: 2/2, bypass=0.

Corrected v114 front: FreeGS 9/9 pass, but DESC equilibrium 0/9. Corrected low-beta
front: FreeGS 23/30 pass; DESC rejects 3 at equilibrium and 20 at sampled Mercier.
Therefore the current shared-state survivor count is 0.

The 101 v118 sampled downstream rows are retained as sealed history but their current
survivor credit is withdrawn: the old FreeGS and DESC artifacts represented different
volume-average pressure/beta/flux states. This is an evidence-binding correction, not a
new physical rejection of those candidates.

Unsupported=0, provider-system-failure=0, validation not executed, credible device=0.

Acceptance hash: `{body['acceptance_hash']}`
"""
    (directory / "acceptance_report.md").write_text(report, encoding="utf-8")
    print(json.dumps({key: body[key] for key in (
        "status", "current_shared_state_survivor_count",
        "withdrawn_v118_sampled_survivor_count", "unsupported_candidate_count",
        "provider_system_failure_count", "acceptance_hash")}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
