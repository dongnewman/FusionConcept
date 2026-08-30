#!/usr/bin/env python3
"""Materialize the selected fine-grid shared-state FreeGS solution for v128."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path

from freegs_shared_state_runner_v119 import solve
from run_v98_freegs_candidate import transformed_input


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--verification", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    candidate = json.loads(Path(args.candidate).read_text(encoding="utf-8"))
    verification = json.loads(Path(args.verification).read_text(encoding="utf-8"))
    if verification.get("status") != "pass" or verification.get(
            "candidate_result_hash") != candidate.get("result_hash"):
        raise ValueError("v128 FreeGS materialization requires a bound passing result")
    source_records = {int(row["grid"]): row for row in verification["grid_records"]}
    ladder_results = []
    for grid in (33, 65, 129):
        solver_input = transformed_input(
            candidate, grid,
            float(verification["selected_coil_vertical_multiplier"]),
            float(verification["selected_boundary_vertical_multiplier"]),
            float(verification.get("selected_axis_pressure_multiplier", 1.0)),
        )
        result = solve(copy.deepcopy(solver_input))
        source = source_records.get(grid)
        if source is None or source.get("result_hash") != result.get("result_hash"):
            raise ValueError(f"FreeGS grid {grid} does not reproduce sealed evidence")
        ladder_results.append({
            "grid": grid,
            "solver_input_hash": canonical_hash(solver_input),
            "result_hash": result["result_hash"],
        })
    # Preserve the fully materialized finest-grid field state.  The complete
    # ladder is intentional: it exactly reproduces the verified numerical
    # VVUQ execution order and catches warm-runtime/path dependence.
    result["input_echo"] = {
        "axis_pressure_pa": solver_input["profile"]["axis_pressure_pa"],
        "plasma_current_a": solver_input["profile"]["plasma_current_a"],
        "vacuum_f_tm": solver_input["profile"]["vacuum_f_tm"],
    }
    result["candidate_result_hash"] = candidate["result_hash"]
    result["candidate_solver_input_hash"] = candidate["solver_input_hash"]
    result["candidate_graph_hash"] = candidate["graph_hash"]
    result["source_verification_hash"] = verification["result_hash"]
    result["source_grid_reproduction"] = ladder_results
    result["v128_materialization_hash"] = canonical_hash(result)
    target = Path(args.output).resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, indent=2, sort_keys=True,
                                 allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "candidate_result_hash":
                      result["candidate_result_hash"], "result_hash":
                      result["result_hash"], "v128_materialization_hash":
                      result["v128_materialization_hash"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
