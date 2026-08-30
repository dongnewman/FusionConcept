#!/usr/bin/env python3
"""Generate edge-current-tilt proposals from the best v130 profile."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path


PROTOCOL_ID = "fusionconceptai-v131-edge-current-repair-generation-20260830"
EDGE_TILTS = (
    (0.00, 2.0),
    (-0.10, 1.0), (-0.10, 2.0), (-0.10, 4.0),
    (-0.20, 1.0), (-0.20, 2.0), (-0.20, 4.0),
    (-0.35, 2.0), (-0.35, 4.0),
    (-0.50, 2.0), (-0.50, 4.0),
    (-0.70, 2.0), (-0.70, 4.0),
    (0.20, 2.0),
)


def canonical_hash(value: object) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    v130 = root / "runs" / "v130_current_profile_repair_20260830"
    parent_id = 38166197474638370832
    parent = json.loads((v130 / "inputs" / f"candidate_{parent_id}.json").read_text(
        encoding="utf-8"))
    run = root / "runs" / "v131_edge_current_repair_20260830"
    inputs = run / "inputs"; inputs.mkdir(parents=True, exist_ok=True)
    rows = []
    for index, (tilt, power) in enumerate(EDGE_TILTS, start=1):
        candidate = copy.deepcopy(parent)
        request_index = int(parent["request_index"]) * 100 + index
        declaration = copy.deepcopy(candidate["equilibrium_profile_parameters"])
        current = copy.deepcopy(declaration["current_profile"])
        current.update({
            "kind": "independent_ffprime_shape_with_edge_tilt",
            "edge_tilt": tilt,
            "edge_power": power,
            "shape": (
                "(1-psi_normalized^alpha_m)^alpha_n*"
                "(1+edge_tilt*psi_normalized^edge_power)"),
        })
        declaration["current_profile"] = current
        declaration["prior_stability_pass_credit"] = False
        declaration["profile_declaration_hash"] = canonical_hash({
            key: value for key, value in declaration.items()
            if key != "profile_declaration_hash"})
        candidate["protocol_id"] = PROTOCOL_ID
        candidate["request_index"] = request_index
        candidate["parent_candidate_result_hash"] = parent["result_hash"]
        candidate["parent_request_index"] = parent["request_index"]
        candidate["equilibrium_profile_parameters"] = declaration
        candidate["physical_pass_credit"] = False
        candidate["validation_credit"] = False
        candidate["whole_device_credible"] = False
        candidate["claim_boundary"] = (
            "v131 adds one declared smooth edge-current tilt to the best v130 "
            "Glasser-margin proposal. No parent pass is inherited; the complete "
            "equilibrium, stability and downstream device chain must rerun."
        )
        candidate["solver_input_hash"] = canonical_hash({
            "parent_solver_input_hash": parent["solver_input_hash"],
            "graph_hash": parent["graph_hash"],
            "pressure_profile": {
                "alpha_m": declaration["alpha_m"],
                "alpha_n": declaration["alpha_n"],
            },
            "current_profile": current,
            "operating_point": candidate["operating_point"],
            "magnet_layout": candidate["magnet_layout"],
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
        "status": "complete", "parent_candidate_result_hash": parent["result_hash"],
        "proposal_count": len(rows), "prior_pass_credit": False,
        "identity_fields_used_for_generation": False, "proposals": rows,
        "claim_boundary": "v131 outputs are proposals only; all credit requires rerun.",
    }
    body["acceptance_hash"] = canonical_hash(body)
    (run / "generation_acceptance.json").write_text(
        json.dumps(body, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": "complete", "proposal_count": len(rows),
                      "acceptance_hash": body["acceptance_hash"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
