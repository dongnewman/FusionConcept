#!/usr/bin/env python3
"""FreeGS verification using the v100 candidate's explicit shared radial build."""

from __future__ import annotations

import math

import run_v98_freegs_candidate as base


base.RUNNER_VERSION = "v100_shared_radial_build_freegs_verification_v2"
base.CLAIM_BOUNDARY = (
    "Three-grid candidate-bound FreeGS 0.8.2 free-boundary equilibrium verification "
    "using the same finite PF radial build as the v100 engineering prefilter. Passing "
    "supports this scalar-pressure equilibrium realization only; it does not establish "
    "complete stability, transport, engineering qualification, validation, or device "
    "feasibility."
)


def transformed_input(candidate: dict, grid: int, coil_vertical_multiplier: float,
                      boundary_vertical_multiplier: float,
                      axis_pressure_multiplier: float = 1.0) -> dict:
    capability = candidate["capability_profile"]
    if capability["route"] not in ("axisymmetric_closed", "closed_core_open_exhaust"):
        raise ValueError("FreeGS transformer requires an axisymmetric closed-core route")
    if capability.get("closed_core_route", "axisymmetric_closed") != "axisymmetric_closed":
        raise ValueError("FreeGS transformer requires axisymmetric closed-core capability")
    if candidate["engineering_prefilter"]["status"] != "pass":
        raise ValueError("v100 FreeGS requires an engineering-prefilter survivor")
    point = candidate["operating_point"]
    layout = candidate["magnet_layout"]
    if layout["layout_model"] != "shared_radial_build_v100":
        raise ValueError("unsupported radial-build declaration")
    target_r = float(point["major_radius_m"])
    target_a = float(point["minor_radius_m"])
    target_kappa = float(point["elongation"])
    target_delta = float(point["triangularity"])
    wall_minor = float(point["wall_minor_radius_m"])
    maintenance = float(layout["maintenance_gap_m"])
    pack = float(layout["winding_pack_thickness_m"])
    radial_offset = wall_minor + maintenance + 0.5 * pack
    inner_r = target_r - radial_offset
    outer_r = target_r + radial_offset
    if inner_r - 0.5 * pack <= 0.0:
        raise ValueError("PF winding pack intersects the symmetry axis")

    def vertical(elongated_minor_units: float) -> float:
        return target_a * target_kappa * elongated_minor_units

    primary_z = vertical(1.10 * coil_vertical_multiplier)
    crown_z = vertical(1.55 * coil_vertical_multiplier)
    vertical_extent = max(abs(crown_z) + 0.5 * pack, 1.90 * target_a * target_kappa)
    radial_margin = 0.5 * pack + 0.20 * target_a
    pressure = float(candidate["physics_solve"]["metrics"]["pressure_pa"])
    current_a = float(candidate["physics_solve"]["confinement_model"][
        "plasma_current_ma"]) * 1.0e6
    field = float(point["magnetic_field_t"])
    alpha_m, alpha_n = base.declared_profile_parameters(candidate)
    return {
        "runner_version": "freegs_explicit_filament_runner_v2",
        "machine": {
            "kind": "explicit_filament_coils",
            "coils": [
                {"id": "pf_inner_lower", "major_radius_m": inner_r,
                 "vertical_position_m": -primary_z},
                {"id": "pf_inner_upper", "major_radius_m": inner_r,
                 "vertical_position_m": primary_z},
                {"id": "pf_outer_lower", "major_radius_m": outer_r,
                 "vertical_position_m": -primary_z},
                {"id": "pf_outer_upper", "major_radius_m": outer_r,
                 "vertical_position_m": primary_z},
                {"id": "pf_crown_inner", "major_radius_m": inner_r,
                 "vertical_position_m": crown_z},
                {"id": "pf_crown_outer", "major_radius_m": outer_r,
                 "vertical_position_m": crown_z},
                {"id": "pf_divertor_inner", "major_radius_m": inner_r,
                 "vertical_position_m": -crown_z},
                {"id": "pf_divertor_outer", "major_radius_m": outer_r,
                 "vertical_position_m": -crown_z},
            ],
            "radial_build_declaration": {
                "layout_model": layout["layout_model"],
                "wall_minor_radius_m": wall_minor,
                "maintenance_gap_m": maintenance,
                "winding_pack_thickness_m": pack,
            },
        },
        "domain": {
            "r_min_m": max(0.05, inner_r - radial_margin),
            "r_max_m": outer_r + radial_margin,
            "z_min_m": -vertical_extent,
            "z_max_m": vertical_extent,
            "nx": grid, "ny": grid, "boundary": "freeBoundaryHagenow",
        },
        "profile": {
            "kind": "ConstrainPaxisIp",
            "axis_pressure_pa": pressure * axis_pressure_multiplier,
            "plasma_current_a": current_a, "vacuum_f_tm": field * target_r,
            "alpha_m": float(alpha_m), "alpha_n": float(alpha_n),
            "profile_axis_radius_m": target_r,
        },
        "constraints": {
            "xpoints_m": [
                [target_r - target_a * target_delta,
                 vertical(-boundary_vertical_multiplier)],
                [target_r - target_a * target_delta,
                 vertical(boundary_vertical_multiplier)],
            ],
            "isoflux_m": [
                [target_r - target_a * target_delta,
                 vertical(-boundary_vertical_multiplier), target_r + target_a, 0.0],
                [target_r - target_a * target_delta,
                 vertical(-boundary_vertical_multiplier), target_r - target_a, 0.0],
                [target_r - target_a * target_delta,
                 vertical(-boundary_vertical_multiplier),
                 target_r - target_a * target_delta,
                 vertical(boundary_vertical_multiplier)],
            ],
            "gamma": 1.0e-12,
        },
        "solver": {"rtol": 1.0e-4, "atol": 1.0e-10, "max_iterations": 100},
    }


base.transformed_input = transformed_input

if __name__ == "__main__":
    raise SystemExit(base.main())
