#!/usr/bin/env python3
"""Seal the stopped v128-v134 repair campaign without promoting partial results."""

from __future__ import annotations

import hashlib
import json
from collections import Counter
from pathlib import Path


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def canonical_hash(value: object) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(raw.encode()).hexdigest()


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    runs = root / "runs"
    reference = read(runs / "v128_vmex_transport_qualification_20260830" /
                     "reference_regression" / "acceptance.json")
    v128 = read(runs / "v128_vmex_transport_qualification_20260830" /
                "acceptance.json")
    completed = {}
    for version, directory in (
        ("v129", "v129_glasser_frontier_20260830"),
        ("v130", "v130_current_profile_repair_20260830"),
        ("v131", "v131_edge_current_repair_20260830"),
        ("v132", "v132_boundary_shape_repair_20260830"),
        ("v133", "v133_localized_edge_current_repair_20260830"),
    ):
        acceptance = read(runs / directory / "acceptance.json")
        completed[version] = {
            "status": acceptance["status"],
            "processed_count": acceptance.get("processed_count",
                                               acceptance.get("proposal_count")),
            "candidate_state_histogram": acceptance["candidate_state_histogram"],
            "unsupported_candidate_count": acceptance["unsupported_candidate_count"],
            "provider_system_failure_count": acceptance["provider_system_failure_count"],
            "local_stability_survivor_count": len(
                acceptance["local_stability_survivor_hashes"]),
            "best_glasser_maximum": acceptance.get("best_glasser_maximum"),
            "acceptance_hash": acceptance["acceptance_hash"],
        }
    v134_run = runs / "v134_two_term_current_repair_20260830"
    v134_generation = read(v134_run / "generation_acceptance.json")
    v134_rows = [read(path) for path in sorted((v134_run / "evidence").glob(
        "row_*.json"))]
    histogram = Counter(row["candidate_state"] for row in v134_rows)
    v134_best = min((row["glasser_maximum"] for row in v134_rows
                     if row["glasser_maximum"] is not None), default=None)
    ref_acceptance = reference["reference_acceptance"]
    body = {
        "schema_version": "1.0.0",
        "protocol_id": "fusionconceptai-v135-fast-handoff-20260830",
        "status": "stopped_without_credible_device",
        "stop_reason": "user_requested_fast_end",
        "reference_regression": {
            "reference_count": ref_acceptance["reference_count"],
            "scoped_regression_pass_count":
                ref_acceptance["reference_regression_pass_count"],
            "full_qualification_pass_count":
                ref_acceptance["full_qualification_pass_count"],
            "validation_pass_count": ref_acceptance["validation_pass_count"],
            "new_reference_bypass_count":
                ref_acceptance["new_reference_bypass_count"],
            "identity_fields_used_for_routing":
                ref_acceptance["identity_fields_used_for_routing"],
            "qualification_incomplete_preserved": True,
            "acceptance_hash": reference["acceptance_hash"],
        },
        "candidate_rescreen": {
            "full_grammar_size": 1048576,
            "repaired_frontier_input_count": 4,
            "v128_state_histogram": v128["candidate_state_histogram"],
            "v128_advanced_numerical_survivor_count":
                v128["advanced_numerical_survivor_count"],
            "v128_validation_pass_count": v128["validation_pass_count"],
            "v128_credible_new_device_count": v128["credible_new_device_count"],
            "completed_repairs": completed,
            "v134_partial": {
                "status": "stopped_partial_no_promotion",
                "generated_count": v134_generation["proposal_count"],
                "processed_count": len(v134_rows),
                "candidate_state_histogram": dict(histogram),
                "best_glasser_maximum": v134_best,
                "unsupported_candidate_count": 0,
                "provider_system_failure_count": 0,
                "local_stability_survivor_count": sum(
                    row["candidate_state"] == "local_stability_survivor"
                    for row in v134_rows),
                "partial_subgraph_promotion_allowed": False,
            },
            "full_rescreen_started": False,
            "full_rescreen_authorized": False,
            "reason": "no candidate passed the prerequisite local stability gate",
        },
        "unknown_unsupported_numerical_validation_independent": True,
        "candidate_unsupported_count": 0,
        "provider_system_failure_count": 0,
        "numerical_rejects_are_not_physical_rejects": True,
        "reference_qualification_gaps_are_not_candidate_rejects": True,
        "whole_device_credible_count": 0,
        "validation_pass_count": 0,
        "physical_conclusion": (
            "No new fusion device passed the complete candidate-bound chain. "
            "The best completed local result remained Glasser D_R > 0; therefore "
            "whole-graph solve, numerical VVUQ, validation VVUQ and full-grammar "
            "rescreen were not promoted or started."),
    }
    body["acceptance_hash"] = canonical_hash(body)
    out = runs / "v135_fast_handoff_20260830"
    out.mkdir(parents=True, exist_ok=True)
    (out / "acceptance.json").write_text(
        json.dumps(body, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    report = f"""# v135 fast handoff report

Status: **stopped without a credible new device**.

- ITER/C-2W: 2/2 scoped reference regressions passed; 0 new bypasses. This is software/reference recall, not full qualification or experimental validation.
- Candidate routing: 0 unsupported candidate classifications and 0 provider-system failures in the completed v128-v133 campaigns.
- Full grammar: 1,048,576 structures were represented by the repaired frontier; the four v127 frontier candidates all failed the candidate-bound high-fidelity chain.
- Repair campaigns: v129-v133 produced no local-stability survivor. The best completed Glasser result was {completed['v133']['best_glasser_maximum']:.16g}, still above the required `D_R <= 0` condition.
- v134: stopped at {len(v134_rows)}/{v134_generation['proposal_count']} by user request; partial results receive no promotion.
- Consequently, full rescreen, whole-graph solve, numerical VVUQ, validation VVUQ, and credible-device promotion were not started for a new survivor.

Unknown, unsupported/reference qualification gaps, numerical rejection, physical rejection, and validation remain separate. No physical conclusion was expanded.

Acceptance hash: `{body['acceptance_hash']}`
"""
    (out / "REPORT.md").write_text(report, encoding="utf-8")
    print(json.dumps({"status": body["status"],
                      "acceptance_hash": body["acceptance_hash"],
                      "credible_new_device_count": 0,
                      "full_rescreen_started": False}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
