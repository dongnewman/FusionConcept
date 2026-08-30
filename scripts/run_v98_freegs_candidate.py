#!/usr/bin/env python3
"""Candidate-bound FreeGS verification for v98 axisymmetric capability survivors."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from freegs_shared_state_runner_v119 import solve


RUNNER_VERSION = "v98_candidate_bound_freegs_verification_v4"
CLAIM_BOUNDARY = (
    "Three-grid candidate-bound FreeGS 0.8.2 free-boundary equilibrium verification "
    "for an axisymmetric capability route. Passing supports this scalar-pressure "
    "equilibrium realization only; it does not establish transport, complete stability, "
    "engineering qualification, experimental validation, or device feasibility."
)


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def relative(actual: float, expected: float) -> float:
    return abs(actual - expected) / max(abs(expected), 1.0e-30)


def declared_profile_parameters(candidate: dict) -> tuple[int, int]:
    """Return candidate-bound FreeGS shape exponents, with the historical default."""
    declaration = candidate.get("equilibrium_profile_parameters", {})
    alpha_m = declaration.get("alpha_m", 1)
    alpha_n = declaration.get("alpha_n", 2)
    if (isinstance(alpha_m, bool) or isinstance(alpha_n, bool) or
            int(alpha_m) != alpha_m or int(alpha_n) != alpha_n):
        raise ValueError("equilibrium profile exponents must be integers")
    alpha_m, alpha_n = int(alpha_m), int(alpha_n)
    if alpha_m < 1 or alpha_n < 1 or 2 * (alpha_m * alpha_n + 1) > 12:
        raise ValueError("equilibrium profile exponents exceed the shared polynomial basis")
    return alpha_m, alpha_n


def transformed_input(candidate: dict, grid: int, coil_vertical_multiplier: float,
                      boundary_vertical_multiplier: float,
                      axis_pressure_multiplier: float = 1.0) -> dict:
    capability = candidate["capability_profile"]
    if capability["route"] not in ("axisymmetric_closed", "closed_core_open_exhaust"):
        raise ValueError("FreeGS transformer requires an axisymmetric closed-core route")
    if capability.get("closed_core_route", "axisymmetric_closed") != "axisymmetric_closed":
        raise ValueError("FreeGS transformer requires axisymmetric closed-core capability")
    point = candidate["operating_point"]
    physics = candidate["physics_solve"]
    target_r = float(point["major_radius_m"])
    target_a = float(point["minor_radius_m"])
    target_kappa = float(point["elongation"])
    target_delta = float(point["triangularity"])

    def radius_from_axis(minor_units: float) -> float:
        return target_r + target_a * minor_units

    def vertical_from_midplane(elongated_minor_units: float) -> float:
        return target_a * target_kappa * elongated_minor_units

    pressure = float(physics["metrics"]["pressure_pa"])
    current_a = float(physics["confinement_model"]["plasma_current_ma"]) * 1.0e6
    field = float(point["magnetic_field_t"])
    alpha_m, alpha_n = declared_profile_parameters(candidate)
    return {
        "runner_version": "freegs_explicit_filament_runner_v2",
        "machine": {
            "kind": "explicit_filament_coils",
            "coils": [
                {"id": "pf_inner_lower", "major_radius_m": radius_from_axis(-1.45),
                 "vertical_position_m": vertical_from_midplane(-1.10 * coil_vertical_multiplier)},
                {"id": "pf_inner_upper", "major_radius_m": radius_from_axis(-1.45),
                 "vertical_position_m": vertical_from_midplane(1.10 * coil_vertical_multiplier)},
                {"id": "pf_outer_lower", "major_radius_m": radius_from_axis(1.45),
                 "vertical_position_m": vertical_from_midplane(-1.10 * coil_vertical_multiplier)},
                {"id": "pf_outer_upper", "major_radius_m": radius_from_axis(1.45),
                 "vertical_position_m": vertical_from_midplane(1.10 * coil_vertical_multiplier)},
                {"id": "pf_crown_inner", "major_radius_m": radius_from_axis(-0.70),
                 "vertical_position_m": vertical_from_midplane(1.55 * coil_vertical_multiplier)},
                {"id": "pf_crown_outer", "major_radius_m": radius_from_axis(0.70),
                 "vertical_position_m": vertical_from_midplane(1.55 * coil_vertical_multiplier)},
                {"id": "pf_divertor_inner", "major_radius_m": radius_from_axis(-0.70),
                 "vertical_position_m": vertical_from_midplane(-1.55 * coil_vertical_multiplier)},
                {"id": "pf_divertor_outer", "major_radius_m": radius_from_axis(0.70),
                 "vertical_position_m": vertical_from_midplane(-1.55 * coil_vertical_multiplier)},
            ],
        },
        "domain": {
            "r_min_m": max(0.05, radius_from_axis(-1.90)),
            "r_max_m": radius_from_axis(1.90),
            "z_min_m": vertical_from_midplane(-1.90),
            "z_max_m": vertical_from_midplane(1.90),
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
                [radius_from_axis(-target_delta),
                 vertical_from_midplane(-boundary_vertical_multiplier)],
                [radius_from_axis(-target_delta),
                 vertical_from_midplane(boundary_vertical_multiplier)],
            ],
            "isoflux_m": [
                [radius_from_axis(-target_delta),
                 vertical_from_midplane(-boundary_vertical_multiplier),
                 radius_from_axis(1.0), 0.0],
                [radius_from_axis(-target_delta),
                 vertical_from_midplane(-boundary_vertical_multiplier),
                 radius_from_axis(-1.0), 0.0],
                [radius_from_axis(-target_delta),
                 vertical_from_midplane(-boundary_vertical_multiplier),
                 radius_from_axis(-target_delta),
                 vertical_from_midplane(boundary_vertical_multiplier)],
            ],
            "gamma": 1.0e-12,
        },
        "solver": {"rtol": 1.0e-4, "atol": 1.0e-10, "max_iterations": 100},
    }


def compact(result: dict) -> dict:
    equilibrium = result["equilibrium"]
    residual = result["independent_residual"]
    return {
        "status": result["status"], "input_hash": result["input_hash"],
        "result_hash": result["result_hash"],
        "iterations": result["convergence"]["iterations"],
        "final_relative_change": result["convergence"]["final_relative_change"],
        "magnetic_axis_r_m": equilibrium["magnetic_axis_r_m"],
        "minor_radius_m": equilibrium["minor_radius_m"],
        "elongation": equilibrium["elongation"],
        "plasma_current_a": equilibrium["plasma_current_a"],
        "plasma_volume_m3": equilibrium["plasma_volume_m3"],
        "toroidal_beta": equilibrium["toroidal_beta"],
        "pressure_volume_average_pa": equilibrium["pressure_volume_average_pa"],
        "toroidal_field_rms_t": equilibrium["toroidal_field_rms_t"],
        "toroidal_flux_wb": equilibrium["toroidal_flux_wb"],
        "beta_n": equilibrium["beta_n"], "q_95": equilibrium["q_95"],
        "plasma_gs_residual_l2_relative": residual["plasma_l2_relative"],
        "plasma_gs_residual_linf_relative": residual["plasma_linf_relative"],
        "maximum_xpoint_field_residual_t": max(
            row["bp_t"] for row in result["constraints"]["xpoint_field_residuals"]
        ),
        "maximum_isoflux_residual_relative": max(
            row["relative_to_flux_span"]
            for row in result["constraints"]["isoflux_residuals"]
        ),
    }


def calibrate_volume_average_pressure(candidate: dict, coil_multiplier: float,
                                      boundary_multiplier: float) -> tuple[float, list[dict], dict]:
    """Solve the internal axis pressure needed to bind the candidate average pressure."""
    target = float(candidate["physics_solve"]["metrics"]["pressure_pa"])
    trials: list[dict] = []

    def evaluate(multiplier: float) -> dict | None:
        try:
            result = compact(solve(transformed_input(
                candidate, 33, coil_multiplier, boundary_multiplier, multiplier
            )))
            trials.append({"axis_pressure_multiplier": multiplier,
                           "status": "pass", "result": result})
            return result
        except Exception as error:
            trials.append({"axis_pressure_multiplier": multiplier,
                           "status": "solver_fail", "error": str(error)})
            return None

    low = 1.0
    low_result = evaluate(low)
    if low_result is None:
        raise RuntimeError("volume-average pressure calibration baseline failed")
    if float(low_result["pressure_volume_average_pa"]) >= target:
        return low, trials, low_result
    high = 2.0
    high_result = None
    while high <= 32.0:
        high_result = evaluate(high)
        if (high_result is not None and
                float(high_result["pressure_volume_average_pa"]) >= target):
            break
        low = high
        if high_result is not None:
            low_result = high_result
        high *= 2.0
    if high_result is None or float(high_result["pressure_volume_average_pa"]) < target:
        return low, trials, low_result
    best_multiplier, best_result = high, high_result
    for _ in range(10):
        middle = 0.5 * (low + high)
        middle_result = evaluate(middle)
        if middle_result is None:
            high = middle
            continue
        if relative(float(middle_result["pressure_volume_average_pa"]), target) < relative(
                float(best_result["pressure_volume_average_pa"]), target):
            best_multiplier, best_result = middle, middle_result
        if float(middle_result["pressure_volume_average_pa"]) < target:
            low, low_result = middle, middle_result
        else:
            high, high_result = middle, middle_result
    return best_multiplier, trials, best_result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    candidate = json.loads(Path(args.input).read_text(encoding="utf-8"))
    if candidate.get("candidate_state") != "computational_candidate":
        raise ValueError("FreeGS verification requires a v98 computational candidate")
    target = candidate["operating_point"]
    target_r = float(target["major_radius_m"])
    target_a = float(target["minor_radius_m"])
    target_kappa = float(target["elongation"])
    realization_search = []
    for coil_multiplier in (0.75, 0.90, 1.05):
        for boundary_multiplier in (0.65, 0.75, 0.85, 0.95, 1.05):
            try:
                trial = compact(solve(transformed_input(
                    candidate, 33, coil_multiplier, boundary_multiplier)))
                objective = (
                    relative(trial["magnetic_axis_r_m"], target_r)
                    + relative(trial["minor_radius_m"], target_a)
                    + relative(trial["elongation"], target_kappa)
                )
                realization_search.append({
                    "coil_vertical_multiplier": coil_multiplier,
                    "boundary_vertical_multiplier": boundary_multiplier,
                    "objective": objective, "result": trial})
            except Exception as error:
                realization_search.append({
                    "coil_vertical_multiplier": coil_multiplier,
                    "boundary_vertical_multiplier": boundary_multiplier,
                    "objective": None, "error": str(error)})
    successful = [row for row in realization_search if row["objective"] is not None]
    if not successful:
        raise RuntimeError("all candidate-bound FreeGS realization trials failed")
    selected = min(successful, key=lambda row: row["objective"])
    selected_coil_multiplier = selected["coil_vertical_multiplier"]
    selected_boundary_multiplier = selected["boundary_vertical_multiplier"]
    selected_pressure_multiplier, pressure_calibration, selected_coarse = (
        calibrate_volume_average_pressure(
            candidate, selected_coil_multiplier, selected_boundary_multiplier
        )
    )
    target_current = float(candidate["physics_solve"]["confinement_model"][
        "plasma_current_ma"]) * 1.0e6
    target_values = {
        "major_radius_m": float(target["major_radius_m"]),
        "minor_radius_m": float(target["minor_radius_m"]),
        "elongation": float(target["elongation"]),
        "plasma_current_a": target_current,
        "pressure_volume_average_pa": float(
            candidate["physics_solve"]["metrics"]["pressure_pa"]),
        "toroidal_beta": float(candidate["physics_solve"]["metrics"]["beta"]),
    }
    coarse_errors = {
        "magnetic_axis_r_relative": relative(selected_coarse["magnetic_axis_r_m"],
                                               target_values["major_radius_m"]),
        "minor_radius_relative": relative(selected_coarse["minor_radius_m"],
                                            target_values["minor_radius_m"]),
        "elongation_relative": relative(selected_coarse["elongation"],
                                          target_values["elongation"]),
        "plasma_current_relative": relative(selected_coarse["plasma_current_a"],
                                               target_current),
        "pressure_volume_average_relative": relative(
            selected_coarse["pressure_volume_average_pa"],
            target_values["pressure_volume_average_pa"]),
        "toroidal_beta_relative": relative(
            selected_coarse["toroidal_beta"], target_values["toroidal_beta"]),
    }
    coarse_gates = {
        "coarse_magnetic_axis_binding": coarse_errors["magnetic_axis_r_relative"] <= 0.08,
        "coarse_minor_radius_binding": coarse_errors["minor_radius_relative"] <= 0.08,
        "coarse_elongation_binding": coarse_errors["elongation_relative"] <= 0.20,
        "coarse_plasma_current_binding": coarse_errors["plasma_current_relative"] <= 1.0e-6,
        "coarse_volume_average_pressure_binding":
            coarse_errors["pressure_volume_average_relative"] <= 0.05,
        "coarse_toroidal_beta_binding": coarse_errors["toroidal_beta_relative"] <= 0.20,
        "coarse_q95_safety": selected_coarse["q_95"] >= 1.8,
        "coarse_independent_gs_residual":
            selected_coarse["plasma_gs_residual_l2_relative"] <= 0.05,
        "coarse_xpoint_constraint":
            selected_coarse["maximum_xpoint_field_residual_t"] <= 0.08,
        "coarse_isoflux_constraint":
            selected_coarse["maximum_isoflux_residual_relative"] <= 2.0e-3,
    }
    coarse_failed = [key for key, value in coarse_gates.items() if not value]
    if coarse_failed:
        artifact = {
            "schema_version": "1.0.0", "runner_version": RUNNER_VERSION,
            "request_index": candidate["request_index"],
            "candidate_result_hash": candidate["result_hash"],
            "candidate_graph_hash": candidate["graph_hash"],
            "candidate_solver_input_hash": candidate["solver_input_hash"],
            "capability_hash": candidate["capability_profile"]["capability_hash"],
            "candidate_binding_verified": True,
            "identity_fields_used_for_routing": False,
            "realization_search": realization_search,
            "selected_coil_vertical_multiplier": selected_coil_multiplier,
            "selected_boundary_vertical_multiplier": selected_boundary_multiplier,
            "selected_axis_pressure_multiplier": selected_pressure_multiplier,
            "pressure_calibration": pressure_calibration,
            "target_values": target_values, "coarse_geometry_errors": coarse_errors,
            "grid_records": [selected_coarse],
            "gates": {key: "pass" if value else "fail"
                      for key, value in coarse_gates.items()},
            "failed_gates": coarse_failed, "status": "fail",
            "stage_order": ["free_boundary_equilibrium_solve", "numerical_vvuq",
                            "validation_vvuq"],
            "numerical_vvuq": {"status": "not_executed",
                                "reason": "coarse_candidate_physics_gate_failed"},
            "validation_vvuq": {"status": "not_executed",
                                 "reason": "coarse_candidate_physics_gate_failed"},
            "validation_credit": False, "claim_boundary": CLAIM_BOUNDARY,
        }
        artifact["result_hash"] = canonical_hash(artifact)
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        temporary = output.with_suffix(output.suffix + ".partial")
        temporary.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n",
                             encoding="utf-8")
        temporary.replace(output)
        print(json.dumps({"status": artifact["status"],
                          "failed_gates": artifact["failed_gates"],
                          "result_hash": artifact["result_hash"]}, sort_keys=True))
        return 2
    records = []
    for grid in (33, 65, 129):
        payload = transformed_input(candidate, grid, selected_coil_multiplier,
                                    selected_boundary_multiplier,
                                    selected_pressure_multiplier)
        try:
            result = solve(copy.deepcopy(payload))
        except Exception as error:
            artifact = {
                "schema_version": "1.0.0", "runner_version": RUNNER_VERSION,
                "request_index": candidate["request_index"],
                "candidate_result_hash": candidate["result_hash"],
                "candidate_graph_hash": candidate["graph_hash"],
                "candidate_solver_input_hash": candidate["solver_input_hash"],
                "capability_hash": candidate["capability_profile"]["capability_hash"],
                "candidate_binding_verified": True,
                "identity_fields_used_for_routing": False,
                "realization_search": realization_search,
                "selected_coil_vertical_multiplier": selected_coil_multiplier,
                "selected_boundary_vertical_multiplier": selected_boundary_multiplier,
                "selected_axis_pressure_multiplier": selected_pressure_multiplier,
                "pressure_calibration": pressure_calibration,
                "target_values": target_values, "grid_records": records,
                "gates": {"fine_grid_solver_convergence": "fail"},
                "failed_gates": ["fine_grid_solver_convergence"],
                "failed_grid": grid,
                "solver_error": {"type": type(error).__name__, "message": str(error)},
                "status": "fail",
                "stage_order": ["free_boundary_equilibrium_solve", "numerical_vvuq",
                                "validation_vvuq"],
                "numerical_vvuq": {
                    "status": "fail",
                    "reason": "candidate_bound_grid_solver_nonconvergence",
                },
                "validation_vvuq": {
                    "status": "not_executed",
                    "reason": "numerical_vvuq_failed",
                },
                "validation_credit": False, "claim_boundary": CLAIM_BOUNDARY,
            }
            artifact["result_hash"] = canonical_hash(artifact)
            output = Path(args.output)
            output.parent.mkdir(parents=True, exist_ok=True)
            temporary = output.with_suffix(output.suffix + ".partial")
            temporary.write_text(
                json.dumps(artifact, indent=2, sort_keys=True) + "\n",
                encoding="utf-8")
            temporary.replace(output)
            print(json.dumps({"status": artifact["status"],
                              "failed_gates": artifact["failed_gates"],
                              "result_hash": artifact["result_hash"]}, sort_keys=True))
            return 2
        row = compact(result)
        row["grid"] = grid
        row["solver_input_hash"] = canonical_hash(payload)
        records.append(row)
    fine = records[-1]
    geometry_errors = {
        "magnetic_axis_r_relative": relative(fine["magnetic_axis_r_m"],
                                               target_values["major_radius_m"]),
        "minor_radius_relative": relative(fine["minor_radius_m"],
                                            target_values["minor_radius_m"]),
        "elongation_relative": relative(fine["elongation"],
                                          target_values["elongation"]),
        "plasma_current_relative": relative(fine["plasma_current_a"], target_current),
        "pressure_volume_average_relative": relative(
            fine["pressure_volume_average_pa"],
            target_values["pressure_volume_average_pa"]),
        "toroidal_beta_relative": relative(
            fine["toroidal_beta"], target_values["toroidal_beta"]),
    }
    medium = records[-2]
    grid_errors = {
        "magnetic_axis_r_relative": relative(medium["magnetic_axis_r_m"],
                                               fine["magnetic_axis_r_m"]),
        "minor_radius_relative": relative(medium["minor_radius_m"],
                                            fine["minor_radius_m"]),
        "elongation_relative": relative(medium["elongation"], fine["elongation"]),
        "q_95_relative": relative(medium["q_95"], fine["q_95"]),
        "beta_n_relative": relative(medium["beta_n"], fine["beta_n"]),
        "pressure_volume_average_relative": relative(
            medium["pressure_volume_average_pa"], fine["pressure_volume_average_pa"]),
        "toroidal_beta_relative": relative(
            medium["toroidal_beta"], fine["toroidal_beta"]),
    }
    gates = {
        "all_grids_executed": all(row["status"] == "pass" for row in records),
        "grid_convergence": max(grid_errors.values()) <= 0.03,
        "magnetic_axis_binding": geometry_errors["magnetic_axis_r_relative"] <= 0.05,
        "minor_radius_binding": geometry_errors["minor_radius_relative"] <= 0.05,
        "elongation_binding": geometry_errors["elongation_relative"] <= 0.15,
        "plasma_current_binding": geometry_errors["plasma_current_relative"] <= 1.0e-6,
        "volume_average_pressure_binding":
            geometry_errors["pressure_volume_average_relative"] <= 0.05,
        "toroidal_beta_binding": geometry_errors["toroidal_beta_relative"] <= 0.20,
        "q95_safety": fine["q_95"] >= 2.0,
        "independent_gs_residual": fine["plasma_gs_residual_l2_relative"] <= 0.03,
        "xpoint_constraint": fine["maximum_xpoint_field_residual_t"] <= 0.05,
        "isoflux_constraint": fine["maximum_isoflux_residual_relative"] <= 1.0e-3,
    }
    artifact = {
        "schema_version": "1.0.0", "runner_version": RUNNER_VERSION,
        "request_index": candidate["request_index"],
        "candidate_result_hash": candidate["result_hash"],
        "candidate_graph_hash": candidate["graph_hash"],
        "candidate_solver_input_hash": candidate["solver_input_hash"],
        "capability_hash": candidate["capability_profile"]["capability_hash"],
        "candidate_binding_verified": True, "identity_fields_used_for_routing": False,
        "realization_search": realization_search,
        "selected_coil_vertical_multiplier": selected_coil_multiplier,
        "selected_boundary_vertical_multiplier": selected_boundary_multiplier,
        "selected_axis_pressure_multiplier": selected_pressure_multiplier,
        "pressure_calibration": pressure_calibration,
        "target_values": target_values, "grid_records": records,
        "medium_to_fine_errors": grid_errors, "fine_geometry_errors": geometry_errors,
        "gates": {key: "pass" if value else "fail" for key, value in gates.items()},
        "failed_gates": [key for key, value in gates.items() if not value],
        "status": "pass" if all(gates.values()) else "fail",
        "stage_order": ["free_boundary_equilibrium_solve", "numerical_vvuq",
                        "validation_vvuq"],
        "numerical_vvuq": {
            "status": "pass" if all(gates.values()) else "fail",
            "method": "three_grid_33_65_129_independent_residual_and_constraint_audit",
        },
        "validation_vvuq": {
            "status": "unknown_validation_domain" if all(gates.values())
                      else "not_executed",
            "reason": "candidate_bound_independent_measurements_unavailable"
                      if all(gates.values()) else "numerical_vvuq_failed",
        },
        "validation_credit": False, "claim_boundary": CLAIM_BOUNDARY,
    }
    artifact["result_hash"] = canonical_hash(artifact)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".partial")
    temporary.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n",
                         encoding="utf-8")
    temporary.replace(output)
    print(json.dumps({"status": artifact["status"],
                      "failed_gates": artifact["failed_gates"],
                      "result_hash": artifact["result_hash"]}, sort_keys=True))
    return 0 if artifact["status"] == "pass" else 2


if __name__ == "__main__":
    raise SystemExit(main())
