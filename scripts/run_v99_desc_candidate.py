#!/usr/bin/env python3
"""Cross-code DESC equilibrium and sampled ideal-MHD audit for a v98 survivor."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

from desc_stellarator_stability_runner import CLAIM_BOUNDARY as DESC_CLAIM_BOUNDARY
from freegs_runner import solve as solve_freegs
from run_v98_freegs_candidate import transformed_input


RUNNER_VERSION = "v99_axisymmetric_cross_code_qualification_v2"
CLAIM_BOUNDARY = (
    "Candidate-bound FreeGS-to-DESC cross-code equilibrium and sampled Mercier/"
    "infinite-n ballooning qualification only. A pass does not establish finite-n, "
    "resistive, kinetic, nonlinear, disruption, transport, exhaust, materials, "
    "engineering, experimental validation, whole-device feasibility, or credibility."
)


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def require(mapping: dict, key: str):
    if key not in mapping:
        raise ValueError(f"missing required key {key}")
    return mapping[key]


def fit_axisymmetric_boundary(freegs: dict, shrink: float = 0.90) -> dict:
    separatrix = require(freegs, "separatrix")
    radius = np.asarray(require(separatrix, "r_m"), dtype=float)
    vertical = np.asarray(require(separatrix, "z_m"), dtype=float)
    equilibrium = require(freegs, "equilibrium")
    axis_r = float(require(equilibrium, "magnetic_axis_r_m"))
    axis_z = float(require(equilibrium, "magnetic_axis_z_m"))
    if radius.size < 64 or radius.shape != vertical.shape:
        raise ValueError("FreeGS separatrix is missing a resolved closed contour")
    if not np.isfinite(radius).all() or not np.isfinite(vertical).all():
        raise ValueError("FreeGS separatrix contains non-finite coordinates")
    radial_scale = max(float(np.max(np.abs(radius - axis_r))), 1.0e-9)
    vertical_scale = max(float(np.max(np.abs(vertical - axis_z))), 1.0e-9)
    theta = np.arctan2((vertical - axis_z) / vertical_scale,
                       (radius - axis_r) / radial_scale)
    inner_r = axis_r + shrink * (radius - axis_r)
    inner_z = axis_z + shrink * (vertical - axis_z)
    minor = float(require(equilibrium, "minor_radius_m")) * shrink
    fits = []
    for maximum_mode in (12, 16, 20, 24):
        r_matrix = np.column_stack(
            [np.ones(theta.size)] + [np.cos(mode * theta)
                                     for mode in range(1, maximum_mode + 1)])
        z_matrix = np.column_stack(
            [np.sin(mode * theta) for mode in range(1, maximum_mode + 1)])
        r_coefficients, *_ = np.linalg.lstsq(r_matrix, inner_r, rcond=None)
        z_coefficients, *_ = np.linalg.lstsq(z_matrix, inner_z, rcond=None)
        fitted_r = r_matrix @ r_coefficients
        fitted_z = z_matrix @ z_coefficients
        point_error = np.hypot(fitted_r - inner_r, fitted_z - inner_z)
        maximum_relative_error = float(np.max(point_error) / max(minor, 1.0e-30))
        rms_relative_error = float(np.sqrt(np.mean(point_error**2)) /
                                   max(minor, 1.0e-30))
        fits.append({"maximum_mode": maximum_mode,
                     "fit_max_relative_to_minor_radius": maximum_relative_error,
                     "fit_rms_relative_to_minor_radius": rms_relative_error})
        if maximum_relative_error <= 0.08:
            break
    modes_r = [{"m": mode, "n": 0, "coefficient_m": float(coefficient)}
               for mode, coefficient in enumerate(r_coefficients)
               if mode == 0 or abs(float(coefficient)) >= 1.0e-8]
    # DESC's symmetric Z basis uses sin(m*theta); negative m with the opposite
    # coefficient preserves the positive-poloidal-angle convention used above.
    modes_z = [{"m": -mode, "n": 0, "coefficient_m": -float(coefficient)}
               for mode, coefficient in enumerate(z_coefficients, start=1)
               if abs(float(coefficient)) >= 1.0e-8]
    return {
        "shrink_from_separatrix": shrink,
        "selected_maximum_mode": maximum_mode,
        "adaptive_mode_fit_audit": fits,
        "R_modes": modes_r,
        "Z_modes": modes_z,
        "fit_rms_relative_to_minor_radius": rms_relative_error,
        "fit_max_relative_to_minor_radius": maximum_relative_error,
        "fit_gate_passed": maximum_relative_error <= 0.08,
        "fitted_minor_radius_m": minor,
        "fitted_vertical_minor_radius_m": 0.5 *
            (float(np.max(fitted_z)) - float(np.min(fitted_z))),
    }


def fit_iota_profile(equilibrium: dict) -> list[float]:
    rho = np.asarray([0.01, 0.50, 0.95], dtype=float)
    q = np.asarray([
        float(require(equilibrium, "q_01")),
        float(require(equilibrium, "q_50")),
        float(require(equilibrium, "q_95")),
    ])
    if not np.isfinite(q).all() or np.any(q <= 0.0):
        raise ValueError("FreeGS q profile samples must be finite and positive")
    matrix = np.column_stack([np.ones(3), rho**2, rho**4])
    even = np.linalg.solve(matrix, 1.0 / q)
    coefficients = [float(even[0]), 0.0, float(even[1]), 0.0,
                    float(even[2])]
    audit_rho = np.linspace(0.0, 1.0, 101)
    audit_iota = sum(value * audit_rho**power
                     for power, value in enumerate(coefficients))
    if (not np.isfinite(audit_iota).all() or
            float(np.min(np.abs(audit_iota))) < 0.02 or
            float(np.max(np.abs(audit_iota))) > 3.0):
        raise ValueError("FreeGS-derived iota interpolant leaves the audited domain")
    return coefficients


def desc_payload(candidate: dict, freegs: dict, boundary: dict) -> dict:
    point = require(candidate, "operating_point")
    pressure = float(require(require(candidate, "physics_solve"), "metrics")
                     ["pressure_pa"])
    equilibrium = require(freegs, "equilibrium")
    radial_minor = float(boundary["fitted_minor_radius_m"])
    vertical_minor = float(boundary["fitted_vertical_minor_radius_m"])
    magnetic_field = float(require(point, "magnetic_field_t"))
    toroidal_flux = magnetic_field * math.pi * radial_minor * vertical_minor
    maximum_mode = int(boundary["selected_maximum_mode"])
    solver_input = {
        "runner_version": "desc_explicit_fourier_fixed_boundary_runner_v1",
        "model_id": "axisymmetric_fourier_fixed_boundary_v99",
        "source_binding": "DESC-0.17.3",
        "boundary": {
            "field_periods": 1,
            "stellarator_symmetric": True,
            "R_modes": boundary["R_modes"],
            "Z_modes": boundary["Z_modes"],
        },
        "profiles": {
            "pressure_power_series_pa": [pressure, 0.0, -2.0 * pressure,
                                           0.0, pressure],
            "iota_power_series": fit_iota_profile(equilibrium),
            "toroidal_flux_wb": toroidal_flux,
        },
        "resolution": {"L": 8, "M": maximum_mode, "N": 1,
                       "L_grid": 16, "M_grid": max(18, int(math.ceil(1.5 * maximum_mode))),
                       "N_grid": 4},
        "solver": {
            "optimizer": "lsq-exact", "max_iterations": 50,
            "ftol": 1.0e-8, "xtol": 1.0e-8, "gtol": 1.0e-6,
            "pressure_step": 0.5, "boundary_step": 0.5,
            "shaping_first": False,
        },
        "audit": {
            "max_force_normalized_magnetic": 0.02,
            "max_fixed_constraint_error": 1.0e-10,
            "min_sqrt_g": 1.0e-5,
        },
    }
    return {
        "runner_version": "desc_stellarator_sampled_ideal_mhd_stability_runner_v1",
        "source_binding": "DESC-0.17.3",
        "claim_boundary": DESC_CLAIM_BOUNDARY,
        "physics_hash": require(candidate, "result_hash"),
        "equilibrium_solver_input": solver_input,
        "equilibrium_reference": None,
        "stability": {
            "mercier": {
                "rho": [0.15, 0.25, 0.40, 0.55, 0.70, 0.85, 0.95],
                "angular_m": 18, "angular_n": 4,
                "minimum_normalized_positive_margin": 1.0e-5,
            },
            "ballooning": {
                "rho": [0.25, 0.50, 0.75, 0.90],
                "alpha_count": 8, "nturns": 3,
                "nzetaperturn": 128, "zeta0_count": 15,
                "maximum_lambda": -1.0e-5, "extraction_shift": -1.0,
            },
        },
    }


def classify_desc_result(result: dict) -> tuple[str, list[str]]:
    if result.get("status") == "pass":
        local = require(result, "local_ideal_mhd")
        if local["sampled_favorable"] is True:
            return "sampled_ideal_mhd_candidate", []
        failed = []
        if not local["mercier_sampled_favorable"]:
            failed.append("sampled_mercier")
        if not local["infinite_n_ballooning_sampled_favorable"]:
            failed.append("sampled_infinite_n_ballooning")
        return "stability_screen_fail", failed
    message = str(result.get("message", "unknown DESC error"))
    candidate_markers = (
        "not nested", "failed its declared physical gates", "failed to converge",
        "singular", "non-finite", "coordinate map", "iota interpolant",
        "automatic continuation failed",
    )
    if any(marker in message.lower() for marker in candidate_markers):
        return "cross_code_equilibrium_fail", ["desc_candidate_equilibrium"]
    return "provider_system_fail", ["desc_provider_execution"]


def cross_code_equilibrium_audit(freegs: dict, desc: dict,
                                 boundary: dict) -> dict:
    if desc.get("status") != "pass":
        return {"status": "not_executed", "reason": "desc_equilibrium_unavailable"}
    free = require(freegs, "equilibrium")
    other = require(require(desc, "equilibrium"), "after")
    shrink = float(boundary["shrink_from_separatrix"])
    expected_inner_volume = float(require(free, "plasma_volume_m3")) * shrink**2

    def relative(left: float, right: float) -> float:
        return abs(left - right) / max(abs(right), 1.0e-30)

    errors = {
        "major_radius_relative": relative(
            float(other["major_radius_m"]), float(free["magnetic_axis_r_m"])),
        "inner_volume_relative": relative(
            float(other["plasma_volume_m3"]), expected_inner_volume),
        "iota_095_relative": relative(
            float(other["iota_095"]), 1.0 / float(free["q_95"])),
        "axis_pressure_relative": relative(
            float(other["pressure_axis_pa"]),
            float(require(require(freegs, "input_echo"), "axis_pressure_pa"))
            if "input_echo" in freegs else float(other["pressure_axis_pa"])),
    }
    gates = {
        "major_radius_binding": errors["major_radius_relative"] <= 0.05,
        "inner_volume_binding": errors["inner_volume_relative"] <= 0.20,
        "edge_iota_binding": errors["iota_095_relative"] <= 0.05,
        "axis_pressure_binding": errors["axis_pressure_relative"] <= 1.0e-8,
        "desc_force_residual":
            float(other["force_normalized_to_magnetic_gradient"]) <= 0.02,
    }
    return {
        "status": "pass" if all(gates.values()) else "fail",
        "freegs": {
            "magnetic_axis_r_m": free["magnetic_axis_r_m"],
            "minor_radius_m": free["minor_radius_m"],
            "plasma_volume_m3": free["plasma_volume_m3"],
            "q_95": free["q_95"],
            "toroidal_beta": free["toroidal_beta"],
        },
        "desc": {
            "major_radius_m": other["major_radius_m"],
            "minor_radius_m": other["minor_radius_m"],
            "plasma_volume_m3": other["plasma_volume_m3"],
            "iota_095": other["iota_095"],
            "volume_average_beta": other["volume_average_beta"],
            "force_normalized_to_magnetic_gradient":
                other["force_normalized_to_magnetic_gradient"],
        },
        "expected_inner_volume_m3": expected_inner_volume,
        "relative_errors": errors,
        "gates": {key: "pass" if value else "fail"
                  for key, value in gates.items()},
        "failed_gates": [key for key, value in gates.items() if not value],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--freegs-result", required=True)
    parser.add_argument("--desc-python", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    candidate = json.loads(Path(args.input).read_text(encoding="utf-8"))
    verification = json.loads(Path(args.freegs_result).read_text(encoding="utf-8"))
    if candidate.get("candidate_state") != "computational_candidate":
        raise ValueError("v99 requires a v98 computational candidate")
    if verification.get("status") != "pass":
        raise ValueError("v99 requires a passing v98 FreeGS verification")
    if verification.get("numerical_vvuq", {}).get("status") != "pass":
        raise ValueError("v99 requires passing v98 numerical VVUQ")
    if verification.get("candidate_result_hash") != candidate.get("result_hash"):
        raise ValueError("FreeGS verification is detached from the candidate")
    freegs_input = transformed_input(
        candidate, 129,
        float(verification["selected_coil_vertical_multiplier"]),
        float(verification["selected_boundary_vertical_multiplier"]),
    )
    freegs = solve_freegs(freegs_input)
    freegs["input_echo"] = {
        "axis_pressure_pa": freegs_input["profile"]["axis_pressure_pa"],
        "plasma_current_a": freegs_input["profile"]["plasma_current_a"],
        "vacuum_f_tm": freegs_input["profile"]["vacuum_f_tm"],
    }
    boundary = fit_axisymmetric_boundary(freegs)
    if not boundary["fit_gate_passed"]:
        desc = {"status": "not_executed", "reason": "boundary_fit_gate_failed"}
        state, failed = "transformer_fit_fail", ["freegs_to_desc_boundary_fit"]
    else:
        try:
            payload = desc_payload(candidate, freegs, boundary)
        except ValueError as error:
            desc = {"status": "not_executed",
                    "reason": "freegs_to_desc_profile_transform_failed",
                    "message": str(error)}
            state = "transformer_profile_fail"
            failed = ["freegs_to_desc_iota_profile"]
            payload = None
    if boundary["fit_gate_passed"] and payload is not None:
        runner = Path(__file__).with_name("desc_axisymmetric_stability_v99_runner.py")
        with tempfile.TemporaryDirectory(prefix="fusionconcept_v99_") as temporary:
            input_path = Path(temporary) / "desc_input.json"
            result_path = Path(temporary) / "desc_result.json"
            input_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n",
                                  encoding="utf-8")
            process = subprocess.run(
                [str(Path(args.desc_python).resolve()), str(runner.resolve()),
                 "--input", str(input_path), "--output", str(result_path)],
                capture_output=True, text=True, check=False,
            )
            if not result_path.is_file():
                desc = {"status": "error", "message": "DESC result artifact missing",
                        "process_exit_code": process.returncode,
                        "stderr_tail": process.stderr[-2000:]}
            else:
                desc = json.loads(result_path.read_text(encoding="utf-8"))
                desc["process_exit_code"] = process.returncode
        state, failed = classify_desc_result(desc)
    cross_code = cross_code_equilibrium_audit(freegs, desc, boundary)
    if cross_code.get("status") == "fail":
        state = "cross_code_equilibrium_fail"
        failed = [f"cross_code_{gate}" for gate in cross_code["failed_gates"]]
    body = {
        "schema_version": "1.0.0", "runner_version": RUNNER_VERSION,
        "request_index": candidate["request_index"],
        "candidate_result_hash": candidate["result_hash"],
        "freegs_verification_hash": verification["result_hash"],
        "freegs_full_result_hash": freegs["result_hash"],
        "capability_route": candidate["capability_profile"]["route"],
        "routing_axes": ["field_semantics", "boundary", "operator", "dimension"],
        "identity_fields_used_for_routing": False,
        "unsupported_candidate_classification_used": False,
        "stage_order": ["freegs_verified_equilibrium", "freegs_to_desc_transform",
                        "desc_fixed_boundary_equilibrium", "sampled_ideal_mhd",
                        "numerical_vvuq", "validation_vvuq"],
        "boundary_transform": boundary,
        "cross_code_equilibrium": cross_code,
        "desc_result": desc,
        "candidate_state": state, "failed_gates": failed,
        "numerical_vvuq": {
            "status": "partial_pass" if state == "sampled_ideal_mhd_candidate"
                      else "fail",
            "reason": "cross_code_equilibrium_and_sampled_local_ideal_mhd_only",
        },
        "validation_vvuq": {
            "status": "unknown_validation_domain" if
                      state == "sampled_ideal_mhd_candidate" else "not_executed",
            "reason": "candidate_bound_independent_measurements_unavailable" if
                      state == "sampled_ideal_mhd_candidate" else
                      "upstream_qualification_failed",
        },
        "whole_device_credible": False,
        "claim_boundary": CLAIM_BOUNDARY,
    }
    body["result_hash"] = canonical_hash(body)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = output.with_suffix(output.suffix + ".partial")
    partial.write_text(json.dumps(body, indent=2, sort_keys=True) + "\n",
                       encoding="utf-8")
    partial.replace(output)
    print(json.dumps({"candidate_state": state, "failed_gates": failed,
                      "result_hash": body["result_hash"]}, sort_keys=True))
    return 1 if state == "provider_system_fail" else 0


if __name__ == "__main__":
    raise SystemExit(main())
