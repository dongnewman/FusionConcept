#!/usr/bin/env python3
"""Run FreeGS with a declared shoulder-plus-edge current profile."""

from __future__ import annotations

import copy
import sys
import types

import freegs_two_term_profile_runner_v134 as two_term


_provider = types.ModuleType("freegs_shared_state_runner_v119")
_provider.solve = two_term.solve
sys.modules["freegs_shared_state_runner_v119"] = _provider
import run_v98_freegs_candidate as base  # noqa: E402


ORIGINAL_TRANSFORM = base.transformed_input
base.RUNNER_VERSION = "v134_two_term_current_profile_freegs_candidate_v1"
base.CLAIM_BOUNDARY = (
    "Candidate-bound FreeGS solve with independent pressure/current shapes and "
    "a declared shoulder-plus-edge current modifier. All three-grid equilibrium "
    "and physical gates rerun; no parent or downstream pass credit.")


def transformed_input(candidate: dict, grid: int, coil_vertical_multiplier: float,
                      boundary_vertical_multiplier: float,
                      axis_pressure_multiplier: float = 1.0) -> dict:
    payload = copy.deepcopy(ORIGINAL_TRANSFORM(
        candidate, grid, coil_vertical_multiplier,
        boundary_vertical_multiplier, axis_pressure_multiplier))
    current = candidate["equilibrium_profile_parameters"]["current_profile"]
    payload["profile"].update({
        "kind": "ConstrainPaxisIpTwoTermEdgeShapes",
        "current_alpha_m": float(current["alpha_m"]),
        "current_alpha_n": float(current["alpha_n"]),
        "current_shoulder_amplitude": float(current["shoulder_amplitude"]),
        "current_shoulder_power": float(current["shoulder_power"]),
        "current_edge_amplitude": float(current["edge_tilt"]),
        "current_edge_power": float(current["edge_power"]),
        "profile_capability": "independent_two_term_current_shape",
    })
    return payload


base.solve = two_term.solve
base.transformed_input = transformed_input


if __name__ == "__main__":
    raise SystemExit(base.main())
