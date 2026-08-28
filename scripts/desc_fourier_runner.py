#!/usr/bin/env python3
"""Deterministic DESC 0.17.3 runner for an explicit Fourier-boundary genome.

This is a fixed-boundary ideal-MHD force-balance calculation. It does not
design external coils and it does not evaluate quasi-symmetry, stability,
transport, exhaust, fusion power, or engineering feasibility.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import importlib.util
import json
import math
import os
import platform
import traceback
import warnings
from pathlib import Path

os.environ.setdefault("JAX_PLATFORMS", "cpu")
os.environ.setdefault("JAX_ENABLE_X64", "true")
os.environ.setdefault(
    "XLA_FLAGS", "--xla_cpu_multi_thread_eigen=false intra_op_parallelism_threads=1"
)
os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("MKL_NUM_THREADS", "1")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")

RUNNER_VERSION = "desc_explicit_fourier_fixed_boundary_runner_v1"
MODEL_ID = "stellarator_symmetric_fourier_fixed_boundary_v1"


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


def integer(value, name: str) -> int:
    result = int(value)
    if float(value) != result:
        raise ValueError(f"{name} must be an integer")
    return result


def scalar(value, name: str, np) -> float:
    array = np.asarray(value, dtype=float)
    if array.size != 1:
        raise RuntimeError(f"DESC quantity {name} is not scalar: shape={array.shape}")
    result = float(array.reshape(-1)[0])
    if not math.isfinite(result):
        raise RuntimeError(f"DESC quantity {name} is not finite")
    return result


def parse_modes(items, label: str) -> tuple[list[float], list[list[int]]]:
    if not isinstance(items, list) or not (1 <= len(items) <= 30):
        raise ValueError(f"{label} must contain 1..30 Fourier modes")
    coefficients: list[float] = []
    modes: list[list[int]] = []
    seen: set[tuple[int, int]] = set()
    for index, item in enumerate(items):
        m = integer(require(item, "m"), f"{label}[{index}].m")
        n = integer(require(item, "n"), f"{label}[{index}].n")
        coefficient = finite(require(item, "coefficient_m"),
                             f"{label}[{index}].coefficient_m")
        if abs(m) > 6 or abs(n) > 6:
            raise ValueError(f"{label}[{index}] mode is outside |m|,|n|<=6")
        if (m, n) in seen:
            raise ValueError(f"{label} contains duplicate mode {(m, n)}")
        seen.add((m, n))
        modes.append([m, n])
        coefficients.append(coefficient)
    return coefficients, modes


def parse_profile(items, label: str) -> list[float]:
    if not isinstance(items, list) or not (1 <= len(items) <= 13):
        raise ValueError(f"{label} must contain 1..13 coefficients")
    return [finite(value, f"{label}[{index}]") for index, value in enumerate(items)]


def equilibrium_metrics(eq, np) -> dict:
    requested = [
        "<|F|>_vol",
        "<|grad(p)|>_vol",
        "<|grad(|B|^2)|/2mu0>_vol",
        "V",
        "<beta>_vol",
        "R0",
        "a",
        "R0/a",
    ]
    data = eq.compute(requested, override_grid=True)
    force = scalar(data["<|F|>_vol"], "<|F|>_vol", np)
    pressure_scale = scalar(data["<|grad(p)|>_vol"], "<|grad(p)|>_vol", np)
    magnetic_scale = scalar(
        data["<|grad(|B|^2)|/2mu0>_vol"],
        "<|grad(|B|^2)|/2mu0>_vol",
        np,
    )
    radii = np.asarray([0.0, 0.5, 0.95], dtype=float)
    iota = np.asarray(eq.iota(radii), dtype=float)
    pressure = np.asarray(eq.pressure(radii), dtype=float)
    return {
        "force_volume_average_n_m3": force,
        "magnetic_pressure_gradient_scale_n_m3": magnetic_scale,
        "pressure_gradient_scale_n_m3": pressure_scale,
        "force_normalized_to_magnetic_gradient": force / max(magnetic_scale, 1.0e-30),
        "force_normalized_to_pressure_gradient": force / max(pressure_scale, 1.0e-30),
        "plasma_volume_m3": scalar(data["V"], "V", np),
        "volume_average_beta": scalar(data["<beta>_vol"], "<beta>_vol", np),
        "major_radius_m": scalar(data["R0"], "R0", np),
        "minor_radius_m": scalar(data["a"], "a", np),
        "aspect_ratio": scalar(data["R0/a"], "R0/a", np),
        "iota_axis": float(iota[0]),
        "iota_mid": float(iota[1]),
        "iota_095": float(iota[2]),
        "pressure_axis_pa": float(pressure[0]),
        "pressure_mid_pa": float(pressure[1]),
        "pressure_095_pa": float(pressure[2]),
    }


def equilibrium_state(eq, np) -> dict:
    return {
        "NFP": int(eq.NFP),
        "sym": bool(eq.sym),
        "L": int(eq.L),
        "M": int(eq.M),
        "N": int(eq.N),
        "L_grid": int(eq.L_grid),
        "M_grid": int(eq.M_grid),
        "N_grid": int(eq.N_grid),
        "Psi_Wb": float(eq.Psi),
        "surface_R_lmn": [float(value) for value in np.asarray(eq.surface.R_lmn)],
        "surface_Z_lmn": [float(value) for value in np.asarray(eq.surface.Z_lmn)],
        "surface_R_modes": [list(map(int, mode[1:])) for mode in np.asarray(eq.surface.R_basis.modes)],
        "surface_Z_modes": [list(map(int, mode[1:])) for mode in np.asarray(eq.surface.Z_basis.modes)],
        "pressure_params": [float(value) for value in np.asarray(eq.pressure.params)],
        "iota_params": [float(value) for value in np.asarray(eq.iota.params)],
    }


def max_abs_difference(left, right, name: str, np) -> float:
    a = np.asarray(left, dtype=float)
    b = np.asarray(right, dtype=float)
    if a.shape != b.shape:
        raise RuntimeError(f"fixed {name} shape changed from {a.shape} to {b.shape}")
    return float(np.max(np.abs(a - b))) if a.size else 0.0


def field_variation(eq, np, LinearGrid) -> dict:
    grid = LinearGrid(
        rho=np.asarray([0.5, 0.95]),
        M=max(2 * eq.M_grid, 8),
        N=max(2 * eq.N_grid, 8),
        NFP=eq.NFP,
        sym=False,
    )
    data = eq.compute(["|B|"], grid=grid)
    field = np.asarray(data["|B|"], dtype=float)
    rho = np.asarray(grid.nodes[:, 0], dtype=float)
    result = {}
    for radius, label in ((0.5, "mid"), (0.95, "095")):
        values = field[np.isclose(rho, radius)]
        if values.size == 0 or not np.isfinite(values).all():
            raise RuntimeError(f"missing finite |B| samples at rho={radius}")
        mean = float(np.mean(values))
        result[f"field_mean_{label}_t"] = mean
        result[f"field_min_{label}_t"] = float(np.min(values))
        result[f"field_max_{label}_t"] = float(np.max(values))
        result[f"field_peak_to_peak_over_mean_{label}"] = (
            float(np.max(values) - np.min(values)) / max(abs(mean), 1.0e-30)
        )
    return result


def solve(payload: dict) -> dict:
    if require(payload, "runner_version") != RUNNER_VERSION:
        raise ValueError("runner_version mismatch")
    if require(payload, "model_id") != MODEL_ID:
        raise ValueError("model_id mismatch")
    if require(payload, "source_binding") != "DESC-0.17.3":
        raise ValueError("source_binding mismatch")

    boundary = require(payload, "boundary")
    nfp = integer(require(boundary, "field_periods"), "field_periods")
    if not (2 <= nfp <= 8):
        raise ValueError("field_periods must be in 2..8")
    if require(boundary, "stellarator_symmetric") is not True:
        raise ValueError("runner v1 only accepts stellarator-symmetric boundaries")
    r_coefficients, r_modes = parse_modes(require(boundary, "R_modes"), "R_modes")
    z_coefficients, z_modes = parse_modes(require(boundary, "Z_modes"), "Z_modes")
    r00 = [value for value, mode in zip(r_coefficients, r_modes) if mode == [0, 0]]
    if len(r00) != 1 or r00[0] <= 0:
        raise ValueError("R_modes must contain one positive (m=0,n=0) major radius")
    nonaxis_r = sum(abs(value) for value, mode in zip(r_coefficients, r_modes)
                    if mode != [0, 0])
    if r00[0] <= 2.0 * nonaxis_r:
        raise ValueError("major radius must exceed twice the summed non-axis R amplitudes")

    profiles = require(payload, "profiles")
    pressure_coefficients = parse_profile(
        require(profiles, "pressure_power_series_pa"), "pressure_power_series_pa"
    )
    iota_coefficients = parse_profile(
        require(profiles, "iota_power_series"), "iota_power_series"
    )
    toroidal_flux = finite(require(profiles, "toroidal_flux_wb"), "toroidal_flux_wb")
    if not (1.0e-4 <= toroidal_flux <= 100.0):
        raise ValueError("toroidal_flux_wb is outside 1e-4..100 Wb")
    profile_radii = [index / 20.0 for index in range(21)]
    pressure_samples = [sum(value * rho**power for power, value in
                            enumerate(pressure_coefficients)) for rho in profile_radii]
    iota_samples = [sum(value * rho**power for power, value in
                        enumerate(iota_coefficients)) for rho in profile_radii]
    if max(pressure_samples) <= 0 or min(pressure_samples) < -1.0e-9 * max(pressure_samples):
        raise ValueError("pressure profile must be non-negative with a positive interior")
    if abs(pressure_samples[-1]) > 1.0e-8 * max(pressure_samples):
        raise ValueError("pressure profile must close to zero at rho=1")
    if (
        max(abs(value) for value in iota_samples) > 3.0
        or min(abs(value) for value in iota_samples) < 0.02
    ):
        raise ValueError("iota profile must remain within 0.02..3 in absolute value")

    resolution = require(payload, "resolution")
    spectral_l = integer(require(resolution, "L"), "L")
    spectral_m = integer(require(resolution, "M"), "M")
    spectral_n = integer(require(resolution, "N"), "N")
    grid_l = integer(require(resolution, "L_grid"), "L_grid")
    grid_m = integer(require(resolution, "M_grid"), "M_grid")
    grid_n = integer(require(resolution, "N_grid"), "N_grid")
    if not (2 <= spectral_l <= 12 and 2 <= spectral_m <= 12 and 1 <= spectral_n <= 12):
        raise ValueError("spectral resolution is outside audited bounds")
    if (
        spectral_m < max(abs(mode[0]) for mode in r_modes + z_modes)
        or spectral_n < max(abs(mode[1]) for mode in r_modes + z_modes)
    ):
        raise ValueError("spectral resolution is below a supplied boundary mode")
    if not (
        spectral_l <= grid_l <= 24
        and spectral_m <= grid_m <= 24
        and spectral_n <= grid_n <= 24
    ):
        raise ValueError("grid resolution must cover the spectral resolution and stay <=24")

    settings = require(payload, "solver")
    if require(settings, "optimizer") != "lsq-exact":
        raise ValueError("only lsq-exact is supported")
    max_iterations = integer(require(settings, "max_iterations"), "max_iterations")
    ftol = finite(require(settings, "ftol"), "ftol")
    xtol = finite(require(settings, "xtol"), "xtol")
    gtol = finite(require(settings, "gtol"), "gtol")
    pressure_step = finite(require(settings, "pressure_step"), "pressure_step")
    boundary_step = finite(require(settings, "boundary_step"), "boundary_step")
    shaping_first = bool(require(settings, "shaping_first"))
    if not (1 <= max_iterations <= 200):
        raise ValueError("max_iterations must be in 1..200")
    if not all(1.0e-12 <= value <= 1.0e-3 for value in (ftol, xtol, gtol)):
        raise ValueError("solver tolerances must be in 1e-12..1e-3")
    if not (0.05 <= pressure_step <= 1.0 and 0.05 <= boundary_step <= 1.0):
        raise ValueError("continuation steps must be in 0.05..1")

    audit = require(payload, "audit")
    force_limit = finite(require(audit, "max_force_normalized_magnetic"),
                         "max_force_normalized_magnetic")
    fixed_limit = finite(require(audit, "max_fixed_constraint_error"),
                         "max_fixed_constraint_error")
    jacobian_minimum = finite(require(audit, "min_sqrt_g"), "min_sqrt_g")
    if not (1.0e-5 <= force_limit <= 0.1):
        raise ValueError("force residual limit must be in 1e-5..0.1")
    if not (1.0e-15 <= fixed_limit <= 1.0e-8):
        raise ValueError("fixed constraint limit must be in 1e-15..1e-8")
    if not (0.0 <= jacobian_minimum <= 1.0):
        raise ValueError("min_sqrt_g threshold must be in 0..1")

    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        import jax
        import numpy as np
        from desc.continuation import solve_continuation_automatic
        from desc.equilibrium import Equilibrium
        from desc.geometry import FourierRZToroidalSurface
        from desc.grid import LinearGrid
        from desc.profiles import PowerSeriesProfile

        expected_versions = {
            "desc-opt": "0.17.3",
            "jax": "0.9.2",
            "jaxlib": "0.9.2",
            "numpy": "2.4.2",
        }
        actual_versions = {
            "desc-opt": importlib.metadata.version("desc-opt"),
            "jax": importlib.metadata.version("jax"),
            "jaxlib": importlib.metadata.version("jaxlib"),
            "numpy": np.__version__,
        }
        if actual_versions != expected_versions:
            raise RuntimeError(
                f"DESC environment mismatch: expected {expected_versions}, got {actual_versions}"
            )
        jax_finufft_available = importlib.util.find_spec("jax_finufft") is not None
        if jax_finufft_available:
            raise RuntimeError("native-Windows runner expects jax_finufft to be absent")

        surface = FourierRZToroidalSurface(
            R_lmn=np.asarray(r_coefficients),
            Z_lmn=np.asarray(z_coefficients),
            modes_R=np.asarray(r_modes),
            modes_Z=np.asarray(z_modes),
            NFP=nfp,
            sym=True,
        )
        pressure = PowerSeriesProfile(pressure_coefficients)
        iota = PowerSeriesProfile(iota_coefficients)
        equilibrium = Equilibrium(
            L=spectral_l,
            M=spectral_m,
            N=spectral_n,
            L_grid=grid_l,
            M_grid=grid_m,
            N_grid=grid_n,
            surface=surface,
            pressure=pressure,
            iota=iota,
            Psi=toroidal_flux,
            sym=True,
        )
        initial_nested = bool(equilibrium.is_nested())
        if not initial_nested:
            raise RuntimeError("DESC initial coordinate map is not nested")
        initial_state = equilibrium_state(equilibrium, np)
        family = solve_continuation_automatic(
            equilibrium,
            objective="force",
            optimizer="lsq-exact",
            maxiter=max_iterations,
            ftol=ftol,
            xtol=xtol,
            gtol=gtol,
            verbose=0,
            pres_step=pressure_step,
            bdry_step=boundary_step,
            shaping_first=shaping_first,
        )
        solved = family[-1]
        after = equilibrium_metrics(solved, np)
        final_nested = bool(solved.is_nested())

        constraint_residuals = {
            "boundary_r_max_abs_m": max_abs_difference(
                solved.surface.R_lmn, equilibrium.surface.R_lmn, "boundary R", np
            ),
            "boundary_z_max_abs_m": max_abs_difference(
                solved.surface.Z_lmn, equilibrium.surface.Z_lmn, "boundary Z", np
            ),
            "pressure_coeff_max_abs_pa": max_abs_difference(
                solved.pressure.params, equilibrium.pressure.params, "pressure", np
            ),
            "iota_coeff_max_abs": max_abs_difference(
                solved.iota.params, equilibrium.iota.params, "iota", np
            ),
            "toroidal_flux_abs_wb": abs(float(solved.Psi - equilibrium.Psi)),
        }
        fixed_max = max(constraint_residuals.values())
        jacobian_grid = LinearGrid(
            rho=np.linspace(0.1, 1.0, 10),
            M=max(grid_m, 8),
            N=max(grid_n, 6),
            NFP=nfp,
            sym=False,
        )
        jacobian = np.asarray(
            solved.compute(["sqrt(g)"], grid=jacobian_grid)["sqrt(g)"], dtype=float
        )
        if not np.isfinite(jacobian).all():
            raise RuntimeError("non-finite coordinate Jacobian")
        min_sqrt_g = float(np.min(jacobian))
        field = field_variation(solved, np, LinearGrid)
        equation_ok = after["force_normalized_to_magnetic_gradient"] <= force_limit
        fixed_ok = fixed_max <= fixed_limit
        jacobian_ok = min_sqrt_g >= jacobian_minimum
        equilibrium_accepted = equation_ok and fixed_ok and jacobian_ok and final_nested
        final_state = equilibrium_state(solved, np)

        result = {
            "status": "pass",
            "runner_version": RUNNER_VERSION,
            "input_hash": canonical_hash(payload),
            "environment": {
                "python": platform.python_version(),
                "desc_opt": actual_versions["desc-opt"],
                "jax": actual_versions["jax"],
                "jaxlib": actual_versions["jaxlib"],
                "numpy": actual_versions["numpy"],
                "device": str(jax.devices()[0]),
                "jax_finufft_available": jax_finufft_available,
            },
            "model": {
                "id": MODEL_ID,
                "initial_state_hash": canonical_hash(initial_state),
                "final_state_hash": canonical_hash(final_state),
                "field_periods": nfp,
                "stellarator_symmetric": True,
                "boundary_mode_count": len(r_modes) + len(z_modes),
                "initial_nested": initial_nested,
                "final_nested": final_nested,
            },
            "solver": {
                "method": "solve_continuation_automatic",
                "optimizer": "lsq-exact",
                "continuation_states": len(family),
                "requested_max_iterations_per_state": max_iterations,
                "requested_ftol": ftol,
                "requested_xtol": xtol,
                "requested_gtol": gtol,
                "pressure_step": pressure_step,
                "boundary_step": boundary_step,
                "shaping_first": shaping_first,
                "equation_residual_accepted": equation_ok,
                "fixed_constraints_accepted": fixed_ok,
                "jacobian_accepted": jacobian_ok,
                "equilibrium_accepted": equilibrium_accepted,
            },
            "after": after,
            "field_variation": field,
            "coordinate_audit": {
                "sample_count": int(jacobian.size),
                "min_sqrt_g": min_sqrt_g,
                "all_finite": True,
            },
            "fixed_constraint_residuals": constraint_residuals,
            "audit_limits": {
                "max_force_normalized_magnetic": force_limit,
                "max_fixed_constraint_error": fixed_limit,
                "min_sqrt_g": jacobian_minimum,
            },
            "warnings": sorted(set(str(item.message) for item in caught)),
        }
    result["result_hash"] = canonical_hash(
        {key: value for key, value in result.items() if key != "result_hash"}
    )
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
    except Exception as error:
        result = {
            "status": "error",
            "runner_version": RUNNER_VERSION,
            "message": str(error),
            "error_type": type(error).__name__,
            "traceback": traceback.format_exc(),
        }
    output_path.write_text(
        json.dumps(result, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
