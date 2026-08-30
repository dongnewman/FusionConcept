#!/usr/bin/env python3
"""Run the v98 FreeGS audit with a declared smooth edge-current tilt."""

from __future__ import annotations

import copy
import sys
import types

import freegs_edge_tilt_runner_v131 as edge


_provider = types.ModuleType("freegs_shared_state_runner_v119")
_provider.solve = edge.solve
sys.modules["freegs_shared_state_runner_v119"] = _provider

import run_v98_freegs_candidate as base  # noqa: E402


ORIGINAL_TRANSFORM = base.transformed_input
base.RUNNER_VERSION = "v131_edge_current_tilt_freegs_candidate_v1"
base.CLAIM_BOUNDARY = (
    "Candidate-bound FreeGS solve with independently declared pressure, current "
    "profile and smooth edge-current tilt. All three-grid equilibrium and physical "
    "gates are rerun; no parent pass, stability, validation or device credit."
)


def transformed_input(candidate: dict, grid: int, coil_vertical_multiplier: float,
                      boundary_vertical_multiplier: float,
                      axis_pressure_multiplier: float = 1.0) -> dict:
    payload = copy.deepcopy(ORIGINAL_TRANSFORM(
        candidate, grid, coil_vertical_multiplier,
        boundary_vertical_multiplier, axis_pressure_multiplier))
    current = candidate["equilibrium_profile_parameters"]["current_profile"]
    alpha_m = float(current["alpha_m"])
    alpha_n = float(current["alpha_n"])
    tilt = float(current["edge_tilt"])
    power = float(current["edge_power"])
    if not (0.25 <= alpha_m <= 8.0 and 0.25 <= alpha_n <= 8.0):
        raise ValueError("current profile exponents exceed audited bounds")
    if not (-0.95 < tilt <= 5.0 and 0.5 <= power <= 8.0):
        raise ValueError("edge-current tilt parameters exceed audited bounds")
    payload["profile"].update({
        "kind": "ConstrainPaxisIpEdgeTiltShapes",
        "current_alpha_m": alpha_m,
        "current_alpha_n": alpha_n,
        "current_edge_tilt": tilt,
        "current_edge_power": power,
        "profile_capability": "independent_pressure_current_and_edge_tilt",
    })
    return payload


base.solve = edge.solve
base.transformed_input = transformed_input


if __name__ == "__main__":
    raise SystemExit(base.main())
