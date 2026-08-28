#!/usr/bin/env python3
"""Deterministic JSON runner for a strict subset of FreeGS 0.8.2."""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import math
import platform
import traceback
import warnings
from pathlib import Path

import freegs
import numpy as np
import scipy
from scipy.constants import mu_0

RUNNER_VERSION = "freegs_explicit_filament_runner_v2"


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def require(mapping: dict, key: str):
    if key not in mapping:
        raise ValueError(f"missing required key {key}")
    return mapping[key]


def finite(value, name: str) -> float:
    result = float(value)
    if not math.isfinite(result):
        raise ValueError(f"{name} must be finite")
    return result


def independent_gs_residual(eq) -> dict[str, float]:
    psi = np.asarray(eq.plasma_psi, dtype=float)
    radius = np.asarray(eq.R, dtype=float)
    current = np.asarray(eq.Jtor, dtype=float)
    dr = float(radius[1, 0] - radius[0, 0])
    dz = float(eq.Z[0, 1] - eq.Z[0, 0])
    center = psi[1:-1, 1:-1]
    operator = (
        (psi[2:, 1:-1] - 2.0 * center + psi[:-2, 1:-1]) / dr**2
        - (psi[2:, 1:-1] - psi[:-2, 1:-1])
        / (2.0 * dr * radius[1:-1, 1:-1])
        + (psi[1:-1, 2:] - 2.0 * center + psi[1:-1, :-2]) / dz**2
    )
    rhs = -mu_0 * radius[1:-1, 1:-1] * current[1:-1, 1:-1]
    residual = operator - rhs
    plasma_mask = np.abs(rhs) > max(1.0e-30, 1.0e-12 * np.max(np.abs(rhs)))

    def relative_l2(mask) -> float:
        return float(np.linalg.norm(residual[mask]) / max(np.linalg.norm(rhs[mask]), 1.0e-30))

    def relative_linf(mask) -> float:
        return float(np.max(np.abs(residual[mask])) / max(np.max(np.abs(rhs[mask])), 1.0e-30))

    all_mask = np.ones_like(rhs, dtype=bool)
    return {
        "all_domain_l2_relative": relative_l2(all_mask),
        "all_domain_linf_relative": relative_linf(all_mask),
        "plasma_l2_relative": relative_l2(plasma_mask),
        "plasma_linf_relative": relative_linf(plasma_mask),
        "plasma_rms_absolute": float(np.sqrt(np.mean(residual[plasma_mask] ** 2))),
    }


def solve(payload: dict) -> dict:
    if require(payload, "runner_version") != RUNNER_VERSION:
        raise ValueError("runner_version mismatch")
    machine = require(payload, "machine")
    if require(machine, "kind") != "explicit_filament_coils":
        raise ValueError("only explicit_filament_coils is supported")
    coils = []
    for item in require(machine, "coils"):
        coils.append(
            (
                str(require(item, "id")),
                freegs.machine.Coil(
                    finite(require(item, "major_radius_m"), "coil major radius"),
                    finite(require(item, "vertical_position_m"), "coil vertical position"),
                ),
            )
        )
    if len(coils) < 4:
        raise ValueError("at least four independently controlled PF coils are required")
    tokamak = freegs.machine.Machine(coils)

    domain = require(payload, "domain")
    nx = int(require(domain, "nx"))
    ny = int(require(domain, "ny"))
    if nx < 17 or ny < 17 or nx % 2 != 1 or ny % 2 != 1:
        raise ValueError("nx and ny must be odd and at least 17")
    boundary_name = require(domain, "boundary")
    if boundary_name != "freeBoundaryHagenow":
        raise ValueError("only freeBoundaryHagenow is supported")
    eq = freegs.Equilibrium(
        tokamak=tokamak,
        Rmin=finite(require(domain, "r_min_m"), "r_min_m"),
        Rmax=finite(require(domain, "r_max_m"), "r_max_m"),
        Zmin=finite(require(domain, "z_min_m"), "z_min_m"),
        Zmax=finite(require(domain, "z_max_m"), "z_max_m"),
        nx=nx,
        ny=ny,
        boundary=freegs.boundary.freeBoundaryHagenow,
    )

    profile = require(payload, "profile")
    if require(profile, "kind") != "ConstrainPaxisIp":
        raise ValueError("only ConstrainPaxisIp is supported")
    profiles = freegs.jtor.ConstrainPaxisIp(
        eq,
        finite(require(profile, "axis_pressure_pa"), "axis_pressure_pa"),
        finite(require(profile, "plasma_current_a"), "plasma_current_a"),
        finite(require(profile, "vacuum_f_tm"), "vacuum_f_tm"),
        alpha_m=finite(require(profile, "alpha_m"), "alpha_m"),
        alpha_n=finite(require(profile, "alpha_n"), "alpha_n"),
        Raxis=finite(require(profile, "profile_axis_radius_m"), "profile_axis_radius_m"),
    )

    constraints = require(payload, "constraints")
    xpoints = [tuple(map(float, point)) for point in require(constraints, "xpoints_m")]
    isoflux = [tuple(map(float, item)) for item in require(constraints, "isoflux_m")]
    controller = freegs.control.constrain(
        xpoints=xpoints,
        isoflux=isoflux,
        gamma=finite(require(constraints, "gamma"), "constraint gamma"),
    )
    settings = require(payload, "solver")
    rtol = finite(require(settings, "rtol"), "rtol")
    atol = finite(require(settings, "atol"), "atol")
    max_iterations = int(require(settings, "max_iterations"))

    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        max_change, relative_change = freegs.solve(
            eq,
            profiles,
            controller,
            rtol=rtol,
            atol=atol,
            maxits=max_iterations,
            convergenceInfo=True,
        )
    separatrix = np.asarray(eq.separatrix(npoints=360), dtype=float)
    q_values = np.asarray(eq.q(np.asarray([0.01, 0.50, 0.95])), dtype=float)
    total_flux = np.asarray(eq.psi(), dtype=float)
    flux_span = float(np.ptp(total_flux))
    xpoint_fields = []
    for radius, vertical in xpoints:
        br = float(eq.Br(radius, vertical))
        bz = float(eq.Bz(radius, vertical))
        xpoint_fields.append({"r_m": radius, "z_m": vertical, "br_t": br, "bz_t": bz, "bp_t": math.hypot(br, bz)})
    isoflux_residuals = []
    for r1, z1, r2, z2 in isoflux:
        absolute = abs(float(eq.psiRZ(r1, z1) - eq.psiRZ(r2, z2)))
        isoflux_residuals.append({"absolute_wb_per_rad": absolute, "relative_to_flux_span": absolute / max(flux_span, 1.0e-30)})

    axis_r, axis_z, axis_psi = map(float, eq.magneticAxis())
    geometric_r, geometric_z = map(float, eq.geometricAxis())
    result = {
        "status": "pass",
        "runner_version": RUNNER_VERSION,
        "input_hash": canonical_hash(payload),
        "environment": {
            "python": platform.python_version(),
            "freegs": importlib.metadata.version("FreeGS"),
            "freeqdsk": importlib.metadata.version("freeqdsk"),
            "numpy": np.__version__,
            "scipy": scipy.__version__,
        },
        "convergence": {
            "iterations": int(len(relative_change)),
            "final_relative_change": float(relative_change[-1]),
            "final_max_change": float(max_change[-1]),
            "relative_change_history": [float(item) for item in relative_change],
            "max_change_history": [float(item) for item in max_change],
            "requested_rtol": rtol,
            "requested_atol": atol,
            "max_iterations": max_iterations,
        },
        "independent_residual": independent_gs_residual(eq),
        "constraints": {
            "xpoint_field_residuals": xpoint_fields,
            "isoflux_residuals": isoflux_residuals,
        },
        "equilibrium": {
            "magnetic_axis_r_m": axis_r,
            "magnetic_axis_z_m": axis_z,
            "magnetic_axis_psi_wb_per_rad": axis_psi,
            "geometric_axis_r_m": geometric_r,
            "geometric_axis_z_m": geometric_z,
            "plasma_current_a": float(eq.plasmaCurrent()),
            "plasma_volume_m3": float(eq.plasmaVolume()),
            "minor_radius_m": float(eq.minorRadius()),
            "elongation": float(eq.elongation()),
            "effective_elongation": float(eq.effectiveElongation()),
            "poloidal_beta": float(eq.poloidalBeta()),
            "toroidal_beta": float(eq.toroidalBeta()),
            "beta_n": float(eq.betaN()),
            "internal_inductance": float(eq.internalInductance()),
            "q_01": float(q_values[0]),
            "q_50": float(q_values[1]),
            "q_95": float(q_values[2]),
            "psi_axis_wb_per_rad": float(eq.psi_axis),
            "psi_boundary_wb_per_rad": float(eq.psi_bndry),
            "flux_span_wb_per_rad": flux_span,
        },
        "coil_currents_a": {label: float(coil.current) for label, coil in tokamak.coils},
        "separatrix": {
            "r_m": [float(value) for value in separatrix[:, 0]],
            "z_m": [float(value) for value in separatrix[:, 1]],
        },
        # FreeGS/NumPy can emit the same deprecation warning once per grid
        # operation. Preserve first occurrence order but keep the evidence
        # artifact bounded and deterministic.
        "warnings": list(dict.fromkeys(str(item.message) for item in caught)),
    }
    result["result_hash"] = canonical_hash({key: value for key, value in result.items() if key != "result_hash"})
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    output_path = Path(args.output)
    try:
        payload = json.loads(Path(args.input).read_text(encoding="utf-8"))
        result = solve(payload)
    except Exception as error:  # The Julia adapter converts this to an error bundle.
        result = {
            "status": "error",
            "runner_version": RUNNER_VERSION,
            "message": str(error),
            "error_type": type(error).__name__,
            "traceback": traceback.format_exc(),
        }
    output_path.write_text(json.dumps(result, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
