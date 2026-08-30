#!/usr/bin/env python3
"""Generate localized high-order edge-current proposals from the v130 optimum."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path


PROTOCOL_ID = "fusionconceptai-v133-localized-edge-current-generation-20260830"
MODIFIERS = (
    (0.0, 8.0),
    (-0.05, 6.0), (-0.10, 6.0), (-0.20, 6.0),
    (-0.05, 7.0), (-0.10, 7.0), (-0.20, 7.0),
    (-0.025, 8.0), (-0.05, 8.0), (-0.075, 8.0), (-0.10, 8.0),
    (-0.15, 8.0), (-0.20, 8.0), (-0.30, 8.0), (-0.50, 8.0),
)


def canonical_hash(value: object) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    source = (root / "runs" / "v130_current_profile_repair_20260830" /
              "inputs" / "candidate_38166197474638370832.json")
    parent = json.loads(source.read_text(encoding="utf-8"))
    run = root / "runs" / "v133_localized_edge_current_repair_20260830"
    inputs = run / "inputs"; inputs.mkdir(parents=True, exist_ok=True)
    rows = []
    for index, (tilt, power) in enumerate(MODIFIERS, start=1):
        candidate = copy.deepcopy(parent)
        request_index = int(parent["result_hash"][:12], 16) * 100 + index
        declaration = copy.deepcopy(candidate["equilibrium_profile_parameters"])
        current = copy.deepcopy(declaration["current_profile"])
        current.update({
            "kind": "independent_ffprime_shape_with_localized_edge_modifier",
            "edge_tilt": tilt, "edge_power": power,
            "shape": ("(1-psi_normalized^alpha_m)^alpha_n*"
                      "(1+edge_tilt*psi_normalized^edge_power)"),
            "localization_semantics": "higher_power_confines_change_to_outer_flux",
        })
        declaration["current_profile"] = current
        declaration["prior_stability_pass_credit"] = False
        declaration["profile_declaration_hash"] = canonical_hash({
            key: value for key, value in declaration.items()
            if key != "profile_declaration_hash"})
        candidate.update({
            "protocol_id": PROTOCOL_ID,
            "request_index": request_index,
            "parent_candidate_result_hash": parent["result_hash"],
            "parent_request_index": parent["request_index"],
            "equilibrium_profile_parameters": declaration,
            "physical_pass_credit": False, "validation_credit": False,
            "whole_device_credible": False,
            "claim_boundary": (
                "v133 changes only a declared high-order localized edge-current "
                "modifier around the v130 optimum. Total current, pressure, geometry "
                "and operating state remain bound; all equilibrium and stability "
                "credit requires rerun."),
        })
        candidate["solver_input_hash"] = canonical_hash({
            "graph_hash": parent["graph_hash"],
            "operating_point": candidate["operating_point"],
            "magnet_layout": candidate["magnet_layout"],
            "pressure_profile": {"alpha_m": declaration["alpha_m"],
                                 "alpha_n": declaration["alpha_n"]},
            "current_profile": current,
        })
        candidate.pop("result_hash", None)
        candidate["result_hash"] = canonical_hash(candidate)
        path = inputs / f"candidate_{request_index}.json"
        path.write_text(json.dumps(candidate, indent=2, sort_keys=True,
                                   allow_nan=False) + "\n", encoding="utf-8")
        rows.append({
            "request_index": request_index,
            "candidate_result_hash": candidate["result_hash"],
            "edge_tilt": tilt, "edge_power": power,
            "input_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        })
    body = {
        "schema_version": "1.0.0", "protocol_id": PROTOCOL_ID,
        "campaign_kind": "localized_edge_current", "status": "complete",
        "source_candidate_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "parent_candidate_result_hash": parent["result_hash"],
        "proposal_count": len(rows), "prior_pass_credit": False,
        "identity_fields_used_for_generation": False, "proposals": rows,
        "claim_boundary": "v133 proposals receive no pass credit until rerun.",
    }
    body["acceptance_hash"] = canonical_hash(body)
    (run / "generation_acceptance.json").write_text(
        json.dumps(body, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": "complete", "proposal_count": len(rows),
                      "acceptance_hash": body["acceptance_hash"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
