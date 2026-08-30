#!/usr/bin/env python3
"""Run the v98 FreeGS audit with declared independent current-profile shape."""

from __future__ import annotations

import copy
import sys
import types

import freegs_separated_profile_runner_v130 as separated


# Import the unchanged campaign logic against the new capability provider.
_provider = types.ModuleType("freegs_shared_state_runner_v119")
_provider.solve = separated.solve
sys.modules["freegs_shared_state_runner_v119"] = _provider

import run_v98_freegs_candidate as base  # noqa: E402


ORIGINAL_TRANSFORM = base.transformed_input
base.RUNNER_VERSION = "v130_separated_pressure_current_freegs_candidate_v1"
base.CLAIM_BOUNDARY = (
    "Candidate-bound FreeGS solve with independently declared pressure and current "
    "profile shapes. All geometry, equilibrium, three-grid numerical VVUQ and physical "
    "gates are rerun. A pass is not stability, transport, engineering, validation, or "
    "whole-device credibility."
)


def transformed_input(candidate: dict, grid: int, coil_vertical_multiplier: float,
                      boundary_vertical_multiplier: float,
                      axis_pressure_multiplier: float = 1.0) -> dict:
    payload = copy.deepcopy(ORIGINAL_TRANSFORM(
        candidate, grid, coil_vertical_multiplier,
        boundary_vertical_multiplier, axis_pressure_multiplier))
    declaration = candidate.get("equilibrium_profile_parameters", {})
    current = declaration.get("current_profile")
    if not isinstance(current, dict):
        raise ValueError("v130 requires a declared current_profile capability")
    alpha_m = float(current.get("alpha_m"))
    alpha_n = float(current.get("alpha_n"))
    if not (0.25 <= alpha_m <= 8.0 and 0.25 <= alpha_n <= 8.0):
        raise ValueError("current profile exponents exceed audited bounds")
    payload["profile"]["kind"] = "ConstrainPaxisIpSeparatedShapes"
    payload["profile"]["current_alpha_m"] = alpha_m
    payload["profile"]["current_alpha_n"] = alpha_n
    payload["profile"]["profile_capability"] = (
        "independent_pressure_and_current_shape")
    return payload


base.solve = separated.solve
base.transformed_input = transformed_input


if __name__ == "__main__":
    raise SystemExit(base.main())
