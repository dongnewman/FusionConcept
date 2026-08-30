#!/usr/bin/env python3
"""Generate current-profile repair proposals from the best v129 Glasser case."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path


PROTOCOL_ID = "fusionconceptai-v130-current-profile-repair-generation-20260830"
CURRENT_PROFILES = (
    (0.50, 0.50), (0.50, 1.00), (0.50, 2.00),
    (0.75, 1.00),
    (1.00, 0.50), (1.00, 1.00), (1.00, 2.00), (1.00, 3.00),
    (1.50, 1.00),
    (2.00, 0.50), (2.00, 1.00), (2.00, 2.00),
    (3.00, 0.50), (3.00, 1.00),
    (4.00, 0.50), (6.00, 0.50),
    # Local refinement around the only coarse profile that materially reduced
    # the candidate-bound Glasser maximum, (1.5, 1.0).
    (1.20, 0.80), (1.20, 1.00), (1.20, 1.20),
    (1.35, 0.85), (1.35, 1.00), (1.35, 1.15),
    (1.50, 0.85), (1.50, 1.15),
    (1.65, 0.85), (1.65, 1.00), (1.65, 1.15),
    (1.80, 0.90), (1.80, 1.10),
    # Edge-current falloff refinement: the remaining Glasser violation is on
    # the outermost validated surfaces, so vary n just above one without
    # weakening the stability gate or excluding those surfaces.
    (1.40, 1.05),
    (1.45, 1.00), (1.45, 1.025), (1.45, 1.05), (1.45, 1.075),
    (1.50, 1.025), (1.50, 1.05),
    (1.55, 1.025),
)


def canonical_hash(value: object) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    parent_path = (root / "runs" / "v126_frontier_static_repair_20260830" /
                   "freegs" / "inputs" / "candidate_381661974746383708.json")
    parent = json.loads(parent_path.read_text(encoding="utf-8"))
    run = root / "runs" / "v130_current_profile_repair_20260830"
    inputs = run / "inputs"
    inputs.mkdir(parents=True, exist_ok=True)
    rows = []
    for index, (alpha_m, alpha_n) in enumerate(CURRENT_PROFILES, start=1):
        candidate = copy.deepcopy(parent)
        request_index = int(parent["request_index"]) * 100 + index
        declaration = copy.deepcopy(candidate["equilibrium_profile_parameters"])
        declaration["current_profile"] = {
            "kind": "independent_ffprime_shape",
            "alpha_m": alpha_m,
            "alpha_n": alpha_n,
            "coordinate": "normalized_poloidal_flux",
            "shape": "(1-psi_normalized^alpha_m)^alpha_n",
            "separate_from_pressure_profile": True,
        }
        declaration["identity_fields_used_for_generation"] = False
        declaration["prior_stability_pass_credit"] = False
        declaration["profile_declaration_hash"] = canonical_hash({
            key: value for key, value in declaration.items()
            if key != "profile_declaration_hash"})
        candidate["schema_version"] = "1.0.0"
        candidate["protocol_id"] = PROTOCOL_ID
        candidate["request_index"] = request_index
        candidate["parent_candidate_result_hash"] = parent["result_hash"]
        candidate["parent_request_index"] = parent["request_index"]
        candidate["equilibrium_profile_parameters"] = declaration
        candidate["candidate_state"] = "computational_candidate"
        candidate["physical_pass_credit"] = False
        candidate["validation_credit"] = False
        candidate["whole_device_credible"] = False
        candidate["unsupported_candidate_classification_used"] = False
        candidate["identity_fields_used_for_routing"] = False
        candidate["claim_boundary"] = (
            "v130 adds an independently declared current-profile shape to the best "
            "v129 Glasser-margin parent. Parent metrics receive no pass credit; every "
            "proposal must rerun FreeGS, DESC, VMEX stability, transport, engineering, "
            "whole-graph numerical VVUQ and validation VVUQ in order."
        )
        candidate["solver_input_hash"] = canonical_hash({
            "parent_solver_input_hash": parent["solver_input_hash"],
            "graph_hash": parent["graph_hash"],
            "pressure_profile": {
                "alpha_m": declaration["alpha_m"],
                "alpha_n": declaration["alpha_n"],
            },
            "current_profile": declaration["current_profile"],
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
            "current_alpha_m": alpha_m,
            "current_alpha_n": alpha_n,
            "input_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        })
    body = {
        "schema_version": "1.0.0",
        "protocol_id": PROTOCOL_ID,
        "status": "complete",
        "parent_candidate_result_hash": parent["result_hash"],
        "proposal_count": len(rows),
        "identity_fields_used_for_generation": False,
        "prior_pass_credit": False,
        "proposals": rows,
        "claim_boundary": (
            "These are deterministic current-profile proposals, not physical or "
            "numerical survivors. Identity is retained only for evidence binding."
        ),
    }
    body["acceptance_hash"] = canonical_hash(body)
    (run / "generation_acceptance.json").write_text(
        json.dumps(body, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8")
    print(json.dumps({
        "status": body["status"], "proposal_count": len(rows),
        "acceptance_hash": body["acceptance_hash"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
