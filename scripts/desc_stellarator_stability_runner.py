#!/usr/bin/env python3
"""DESC 0.17.3 sampled Mercier and infinite-n ballooning evaluator.

This runner re-solves an explicit-Fourier fixed-boundary equilibrium, checks
that equilibrium independently, then evaluates two local ideal-MHD criteria.
It does not establish finite-n, resistive, kinetic, nonlinear, disruption, or
all-mode plasma stability, and it does not evaluate transport or engineering.
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
import re
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

from desc_fourier_runner import (  # noqa: E402
    MODEL_ID,
    RUNNER_VERSION as EQUILIBRIUM_RUNNER_VERSION,
    canonical_hash,
    equilibrium_metrics,
    finite,
    integer,
    max_abs_difference,
    parse_modes,
    parse_profile,
    require,
)

RUNNER_VERSION = "desc_stellarator_sampled_ideal_mhd_stability_runner_v1"
CLAIM_BOUNDARY = (
    "Sampled Mercier and infinite-n ideal-ballooning criteria on a re-solved "
    "fixed-boundary equilibrium only; not finite-n, resistive, kinetic, nonlinear, "
    "disruption, transport, engineering, all-mode stability, or device superiority."
)
HEX64 = re.compile(r"^[0-9a-f]{64}$")


def source_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def numeric_list(value, name: str, minimum_count: int, maximum_count: int) -> list[float]:
    if not isinstance(value, list) or not (minimum_count <= len(value) <= maximum_count):
        raise ValueError(f"{name} must contain {minimum_count}..{maximum_count} items")
    result = [finite(item, f"{name}[{index}]") for index, item in enumerate(value)]
    if any(right <= left for left, right in zip(result, result[1:])):
        raise ValueError(f"{name} must be strictly increasing")
    return result


def construct_and_solve(solver_input: dict, np):
    if require(solver_input, "runner_version") != EQUILIBRIUM_RUNNER_VERSION:
        raise ValueError("embedded equilibrium runner_version mismatch")
    if require(solver_input, "model_id") != MODEL_ID:
        raise ValueError("embedded equilibrium model_id mismatch")
    if require(solver_input, "source_binding") != "DESC-0.17.3":
        raise ValueError("embedded equilibrium source binding mismatch")

    boundary = require(solver_input, "boundary")
    nfp = integer(require(boundary, "field_periods"), "field_periods")
    if not (2 <= nfp <= 8) or require(boundary, "stellarator_symmetric") is not True:
        raise ValueError("stability runner requires a 2..8-period stellarator-symmetric boundary")
    r_coefficients, r_modes = parse_modes(require(boundary, "R_modes"), "R_modes")
    z_coefficients, z_modes = parse_modes(require(boundary, "Z_modes"), "Z_modes")
    r00 = [value for value, mode in zip(r_coefficients, r_modes) if mode == [0, 0]]
    if len(r00) != 1 or r00[0] <= 0:
        raise ValueError("boundary must contain one positive R(0,0)")
    nonaxis_r = sum(
        abs(value) for value, mode in zip(r_coefficients, r_modes) if mode != [0, 0]
    )
    if r00[0] <= 2.0 * nonaxis_r:
        raise ValueError("major radius is too small for supplied radial amplitudes")

    profiles = require(solver_input, "profiles")
    pressure_coefficients = parse_profile(
        require(profiles, "pressure_power_series_pa"), "pressure_power_series_pa"
    )
    iota_coefficients = parse_profile(
        require(profiles, "iota_power_series"), "iota_power_series"
    )
    toroidal_flux = finite(require(profiles, "toroidal_flux_wb"), "toroidal_flux_wb")
    radii = [index / 20.0 for index in range(21)]
    pressure_samples = [
        sum(value * rho**power for power, value in enumerate(pressure_coefficients))
        for rho in radii
    ]
    iota_samples = [
        sum(value * rho**power for power, value in enumerate(iota_coefficients))
        for rho in radii
    ]
    if not (1.0e-4 <= toroidal_flux <= 100.0):
        raise ValueError("toroidal flux is outside the audited range")
    if max(pressure_samples) <= 0 or min(pressure_samples) < -1.0e-9 * max(pressure_samples):
        raise ValueError("pressure profile must be non-negative")
    if abs(pressure_samples[-1]) > 1.0e-8 * max(pressure_samples):
        raise ValueError("pressure profile must close to zero at rho=1")
    if max(abs(value) for value in iota_samples) > 3.0 or min(
        abs(value) for value in iota_samples
    ) < 0.02:
        raise ValueError("iota profile is outside the audited range")

    resolution = require(solver_input, "resolution")
    spectral_l = integer(require(resolution, "L"), "L")
    spectral_m = integer(require(resolution, "M"), "M")
    spectral_n = integer(require(resolution, "N"), "N")
    grid_l = integer(require(resolution, "L_grid"), "L_grid")
    grid_m = integer(require(resolution, "M_grid"), "M_grid")
    grid_n = integer(require(resolution, "N_grid"), "N_grid")
    if not (2 <= spectral_l <= 12 and 2 <= spectral_m <= 12 and 1 <= spectral_n <= 12):
        raise ValueError("spectral resolution is outside audited bounds")
    if not (
        spectral_l <= grid_l <= 24
        and spectral_m <= grid_m <= 24
        and spectral_n <= grid_n <= 24
    ):
        raise ValueError("collocation grid does not cover spectral resolution")

    settings = require(solver_input, "solver")
    if require(settings, "optimizer") != "lsq-exact":
        raise ValueError("only lsq-exact equilibrium solves are supported")
    max_iterations = integer(require(settings, "max_iterations"), "max_iterations")
    ftol = finite(require(settings, "ftol"), "ftol")
    xtol = finite(require(settings, "xtol"), "xtol")
    gtol = finite(require(settings, "gtol"), "gtol")
    pressure_step = finite(require(settings, "pressure_step"), "pressure_step")
    boundary_step = finite(require(settings, "boundary_step"), "boundary_step")
    shaping_first = require(settings, "shaping_first")
    if not isinstance(shaping_first, bool):
        raise ValueError("shaping_first must be boolean")
    if not (1 <= max_iterations <= 200):
        raise ValueError("max_iterations is outside audited bounds")
    if not all(1.0e-12 <= value <= 1.0e-3 for value in (ftol, xtol, gtol)):
        raise ValueError("solver tolerance is outside audited bounds")
    if not (0.05 <= pressure_step <= 1.0 and 0.05 <= boundary_step <= 1.0):
        raise ValueError("continuation step is outside audited bounds")

    audit = require(solver_input, "audit")
    force_limit = finite(
        require(audit, "max_force_normalized_magnetic"),
        "max_force_normalized_magnetic",
    )
    fixed_limit = finite(
        require(audit, "max_fixed_constraint_error"), "max_fixed_constraint_error"
    )
    jacobian_minimum = finite(require(audit, "min_sqrt_g"), "min_sqrt_g")

    from desc.continuation import solve_continuation_automatic
    from desc.equilibrium import Equilibrium
    from desc.geometry import FourierRZToroidalSurface
    from desc.grid import LinearGrid
    from desc.profiles import PowerSeriesProfile

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
    if not bool(equilibrium.is_nested()):
        raise RuntimeError("initial equilibrium coordinate map is not nested")
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
    fixed_residuals = {
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
    min_sqrt_g = float(np.min(jacobian))
    equilibrium_accepted = (
        bool(solved.is_nested())
        and np.isfinite(jacobian).all()
        and min_sqrt_g >= jacobian_minimum
        and max(fixed_residuals.values()) <= fixed_limit
        and after["force_normalized_to_magnetic_gradient"] <= force_limit
    )
    if not equilibrium_accepted:
        raise RuntimeError("re-solved equilibrium failed its declared physical gates")
    state = {
        "R_lmn": [float(value) for value in np.asarray(solved.R_lmn)],
        "Z_lmn": [float(value) for value in np.asarray(solved.Z_lmn)],
        "L_lmn": [float(value) for value in np.asarray(solved.L_lmn)],
        "surface_R_lmn": [float(value) for value in np.asarray(solved.surface.R_lmn)],
        "surface_Z_lmn": [float(value) for value in np.asarray(solved.surface.Z_lmn)],
        "pressure_params": [float(value) for value in np.asarray(solved.pressure.params)],
        "iota_params": [float(value) for value in np.asarray(solved.iota.params)],
        "Psi_Wb": float(solved.Psi),
        "resolution": [spectral_l, spectral_m, spectral_n, grid_l, grid_m, grid_n],
    }
    equilibrium_record = {
        "accepted": True,
        "continuation_states": len(family),
        "after": after,
        "fixed_constraint_residuals": fixed_residuals,
        "minimum_sampled_sqrt_g": min_sqrt_g,
        "solved_volume_state_hash": canonical_hash(state),
    }
    return solved, equilibrium_record


def validate_reference_binding(reference: dict | None, solver_input: dict) -> None:
    """Reject detached evidence before paying for a fresh equilibrium solve."""
    if reference is None:
        return
    if not isinstance(reference, dict):
        raise ValueError("equilibrium_reference must be an object or null")
    input_hash = require(reference, "input_hash")
    result_hash = require(reference, "result_hash")
    if not isinstance(input_hash, str) or HEX64.fullmatch(input_hash) is None:
        raise ValueError("invalid reference input_hash")
    if not isinstance(result_hash, str) or HEX64.fullmatch(result_hash) is None:
        raise ValueError("invalid reference result_hash")
    if input_hash != canonical_hash(solver_input):
        raise ValueError("reference input hash does not match embedded equilibrium input")


def compare_reference(reference: dict | None, solver_input: dict, equilibrium: dict) -> dict:
    if reference is None:
        return {"provided": False, "matched": None, "maximum_relative_difference": None}
    validate_reference_binding(reference, solver_input)
    input_hash = require(reference, "input_hash")
    result_hash = require(reference, "result_hash")
    expected = require(reference, "after")
    keys = (
        "force_normalized_to_magnetic_gradient",
        "plasma_volume_m3",
        "volume_average_beta",
        "major_radius_m",
        "minor_radius_m",
        "aspect_ratio",
        "iota_axis",
        "iota_095",
    )
    differences = {}
    for key in keys:
        observed = finite(require(equilibrium["after"], key), f"observed {key}")
        target = finite(require(expected, key), f"reference {key}")
        differences[key] = abs(observed - target) / max(abs(target), 1.0e-30)
    maximum = max(differences.values())
    if maximum > 1.0e-8:
        raise RuntimeError("re-solved equilibrium does not match prior accepted diagnostics")
    return {
        "provided": True,
        "matched": True,
        "reference_result_hash": result_hash,
        "maximum_relative_difference": maximum,
        "relative_differences": differences,
    }


def mercier_scan(eq, settings: dict, np):
    from desc.grid import LinearGrid

    rho = numeric_list(require(settings, "rho"), "mercier.rho", 3, 32)
    if rho[0] < 0.1 or rho[-1] > 0.97:
        raise ValueError("Mercier rho must stay within 0.1..0.97 and exclude the axis")
    angular_m = integer(require(settings, "angular_m"), "mercier.angular_m")
    angular_n = integer(require(settings, "angular_n"), "mercier.angular_n")
    if not (eq.M <= angular_m <= 24 and eq.N <= angular_n <= 24):
        raise ValueError("Mercier angular resolution is outside audited bounds")
    margin = finite(
        require(settings, "minimum_normalized_positive_margin"),
        "mercier.minimum_normalized_positive_margin",
    )
    if not (0.0 <= margin <= 0.1):
        raise ValueError("Mercier normalized margin must be in 0..0.1")
    grid = LinearGrid(
        rho=np.asarray(rho), M=angular_m, N=angular_n, NFP=eq.NFP, sym=False
    )
    keys = ["D_Mercier", "D_shear", "D_current", "D_well", "D_geodesic"]
    data = eq.compute(keys, grid=grid)
    profiles = {
        key: np.asarray(grid.compress(data[key]), dtype=float) for key in keys
    }
    if any(values.shape != (len(rho),) for values in profiles.values()):
        raise RuntimeError("Mercier profile shape mismatch")
    if not all(np.isfinite(values).all() for values in profiles.values()):
        raise RuntimeError("non-finite Mercier profile")
    closure = profiles["D_Mercier"] - (
        profiles["D_shear"]
        + profiles["D_current"]
        + profiles["D_well"]
        + profiles["D_geodesic"]
    )
    closure_max = float(np.max(np.abs(closure)))
    if closure_max > 1.0e-10:
        raise RuntimeError("Mercier term closure failed")
    normalized = profiles["D_Mercier"] * float(eq.Psi) ** 2
    minimum_index = int(np.argmin(normalized))
    favorable = bool(float(normalized[minimum_index]) >= margin)
    return {
        "rho": rho,
        "angular_m": angular_m,
        "angular_n": angular_n,
        "D_Mercier_wb_minus2": [float(value) for value in profiles["D_Mercier"]],
        "D_Mercier_normalized": [float(value) for value in normalized],
        "D_shear_wb_minus2": [float(value) for value in profiles["D_shear"]],
        "D_current_wb_minus2": [float(value) for value in profiles["D_current"]],
        "D_well_wb_minus2": [float(value) for value in profiles["D_well"]],
        "D_geodesic_wb_minus2": [float(value) for value in profiles["D_geodesic"]],
        "term_closure_max_abs_wb_minus2": closure_max,
        "minimum_D_Mercier_wb_minus2": float(profiles["D_Mercier"][minimum_index]),
        "minimum_D_Mercier_normalized": float(normalized[minimum_index]),
        "worst_rho": rho[minimum_index],
        "positive_fraction": float(np.mean(normalized > 0.0)),
        "required_normalized_positive_margin": margin,
        "sampled_favorable": favorable,
    }


def ballooning_scan(eq, settings: dict, np):
    from desc.objectives import BallooningStability

    rho = numeric_list(require(settings, "rho"), "ballooning.rho", 1, 12)
    if rho[0] < 0.1 or rho[-1] > 0.95:
        raise ValueError("ballooning rho must stay within 0.1..0.95")
    alpha_count = integer(require(settings, "alpha_count"), "ballooning.alpha_count")
    nturns = integer(require(settings, "nturns"), "ballooning.nturns")
    nzetaperturn = integer(
        require(settings, "nzetaperturn"), "ballooning.nzetaperturn"
    )
    zeta0_count = integer(require(settings, "zeta0_count"), "ballooning.zeta0_count")
    if not (2 <= alpha_count <= 16):
        raise ValueError("alpha_count must be in 2..16")
    if not (1 <= nturns <= 6 and 32 <= nzetaperturn <= 256):
        raise ValueError("field-line resolution is outside audited bounds")
    if not (3 <= zeta0_count <= 21 and zeta0_count % 2 == 1):
        raise ValueError("zeta0_count must be an odd value in 3..21")
    maximum_allowed = finite(
        require(settings, "maximum_lambda"), "ballooning.maximum_lambda"
    )
    if not (-0.1 <= maximum_allowed <= 0.0):
        raise ValueError("maximum_lambda must be in -0.1..0")
    shift = finite(require(settings, "extraction_shift"), "ballooning.extraction_shift")
    if not (-10.0 <= shift <= -0.1):
        raise ValueError("extraction_shift must be in -10..-0.1")
    alpha = np.linspace(0.0, 2.0 * np.pi, alpha_count, endpoint=False)
    zeta0 = np.linspace(-0.5 * np.pi, 0.5 * np.pi, zeta0_count)
    objective = BallooningStability(
        eq,
        rho=np.asarray(rho),
        alpha=alpha,
        nturns=nturns,
        nzetaperturn=nzetaperturn,
        zeta0=zeta0,
        Neigvals=1,
        lambda0=shift,
        w0=0.0,
        w1=1.0,
    )
    objective.build(use_jit=True, verbose=0)
    shifted = np.asarray(objective.compute(eq.params_dict), dtype=float)
    if shifted.shape != (len(rho),) or not np.isfinite(shifted).all():
        raise RuntimeError("ballooning result shape or finiteness failure")
    if np.any(shifted <= 0.0):
        raise RuntimeError("ballooning extraction shift clipped the scanned maximum")
    raw = shifted + shift
    second_shift = 2.0 * shift
    original_shift = objective._constants["lambda0"]
    objective._constants["lambda0"] = second_shift
    shifted_second = np.asarray(objective.compute(eq.params_dict), dtype=float)
    objective._constants["lambda0"] = original_shift
    raw_second = shifted_second + second_shift
    extraction_difference = float(np.max(np.abs(raw - raw_second)))
    if extraction_difference > 1.0e-10:
        raise RuntimeError("ballooning raw-eigenvalue shift extraction is inconsistent")
    maximum_index = int(np.argmax(raw))
    maximum = float(raw[maximum_index])
    return {
        "rho": rho,
        "alpha_count": alpha_count,
        "nturns": nturns,
        "nzetaperturn": nzetaperturn,
        "zeta0_count": zeta0_count,
        "maximum_lambda_by_rho": [float(value) for value in raw],
        "maximum_lambda": maximum,
        "worst_rho": rho[maximum_index],
        "required_maximum_lambda": maximum_allowed,
        "sampled_favorable": bool(maximum <= maximum_allowed),
        "extraction_shift": shift,
        "shift_extraction_max_abs_difference": extraction_difference,
        "scan_count": len(rho) * alpha_count * zeta0_count,
        "field_line_point_count": nturns * nzetaperturn,
    }


def solve(payload: dict) -> dict:
    if require(payload, "runner_version") != RUNNER_VERSION:
        raise ValueError("runner_version mismatch")
    if require(payload, "source_binding") != "DESC-0.17.3":
        raise ValueError("source_binding mismatch")
    if require(payload, "claim_boundary") != CLAIM_BOUNDARY:
        raise ValueError("claim_boundary mismatch")
    physics_hash = require(payload, "physics_hash")
    if not isinstance(physics_hash, str) or HEX64.fullmatch(physics_hash) is None:
        raise ValueError("invalid physics_hash")
    solver_input = require(payload, "equilibrium_solver_input")
    stability = require(payload, "stability")

    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        import jax
        import numpy as np

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
            raise RuntimeError("DESC stability environment version mismatch")
        jax_finufft_available = importlib.util.find_spec("jax_finufft") is not None
        if jax_finufft_available:
            raise RuntimeError("native-Windows stability runner expects jax_finufft absent")

        validate_reference_binding(payload.get("equilibrium_reference"), solver_input)
        equilibrium, equilibrium_record = construct_and_solve(solver_input, np)
        reference_record = compare_reference(
            payload.get("equilibrium_reference"), solver_input, equilibrium_record
        )
        mercier = mercier_scan(equilibrium, require(stability, "mercier"), np)
        ballooning = ballooning_scan(
            equilibrium, require(stability, "ballooning"), np
        )
        local_favorable = bool(
            mercier["sampled_favorable"] and ballooning["sampled_favorable"]
        )
        result = {
            "status": "pass",
            "runner_version": RUNNER_VERSION,
            "claim_boundary": CLAIM_BOUNDARY,
            "physics_hash": physics_hash,
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
            "equilibrium": equilibrium_record,
            "equilibrium_reference": reference_record,
            "mercier": mercier,
            "ballooning": ballooning,
            "local_ideal_mhd": {
                "sampled_favorable": local_favorable,
                "mercier_sampled_favorable": mercier["sampled_favorable"],
                "infinite_n_ballooning_sampled_favorable": ballooning[
                    "sampled_favorable"
                ],
                "all_mode_plasma_stability_established": False,
            },
            "warnings": sorted(set(str(item.message) for item in caught)),
        }
    result["result_hash"] = canonical_hash(result)
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
