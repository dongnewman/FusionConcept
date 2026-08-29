#!/usr/bin/env python3
"""Candidate-bound static PF perturbation and reduced engineering screen for v99."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from freegs_runner import solve as solve_freegs
from run_v98_freegs_candidate import transformed_input


RUNNER_VERSION = "v99_generic_freegs_static_robustness_v1"
CLAIM_BOUNDARY = (
    "Candidate-bound deterministic FreeGS static perturbation re-solves and reduced "
    "PF current, additive-field, and membrane-stress proxies only. A pass is not "
    "dynamic control, complete engineering, superconducting qualification, disruption "
    "analysis, transport/exhaust, experimental validation, or a credible-device claim."
)


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def scenarios(nominal: dict) -> list[tuple[str, dict]]:
    cases = [("nominal", copy.deepcopy(nominal))]
    for name, shift in (("all_pf_z_plus", 0.005), ("all_pf_z_minus", -0.005)):
        value = copy.deepcopy(nominal)
        for coil in value["machine"]["coils"]:
            coil["vertical_position_m"] += shift
        cases.append((name, value))
    value = copy.deepcopy(nominal)
    for coil in value["machine"]["coils"]:
        coil["vertical_position_m"] += math.copysign(
            0.005, coil["vertical_position_m"] or 1.0)
    cases.append(("paired_pf_vertical_separation", value))
    value = copy.deepcopy(nominal)
    for index, coil in enumerate(value["machine"]["coils"]):
        coil["major_radius_m"] += 0.005 * (-1.0 if index % 2 == 0 else 1.0)
        coil["vertical_position_m"] += 0.005 * (-1.0 if (index // 2) % 2 == 0 else 1.0)
    cases.append(("alternating_pf_rz_offsets", value))
    for name, fraction in (("plasma_current_plus", 0.03),
                           ("plasma_current_minus", -0.03)):
        value = copy.deepcopy(nominal)
        value["profile"]["plasma_current_a"] *= 1.0 + fraction
        cases.append((name, value))
    for name, fraction in (("axis_pressure_plus", 0.05),
                           ("axis_pressure_minus", -0.05)):
        value = copy.deepcopy(nominal)
        value["profile"]["axis_pressure_pa"] *= 1.0 + fraction
        cases.append((name, value))
    return cases


def pair_imbalance(currents: dict[str, float], nominal_max: float) -> float:
    values = []
    for name, current in currents.items():
        if "lower" not in name:
            continue
        other = name.replace("lower", "upper")
        if other in currents:
            values.append(abs(float(current) - float(currents[other])) / nominal_max)
    return max(values, default=0.0)


def solver_passed(raw: dict, solver_input: dict) -> tuple[bool, dict]:
    if raw.get("status") != "pass":
        return False, {"runner_completed": False}
    convergence = raw["convergence"]
    residual = raw["independent_residual"]
    constraints = raw["constraints"]
    equilibrium = raw["equilibrium"]
    xpoint_max = max(float(item["bp_t"])
                     for item in constraints["xpoint_field_residuals"])
    isoflux_max = max(float(item["relative_to_flux_span"])
                      for item in constraints["isoflux_residuals"])
    target_current = float(solver_input["profile"]["plasma_current_a"])
    current_error = abs(float(equilibrium["plasma_current_a"]) - target_current) / abs(target_current)
    gates = {
        "runner_completed": True,
        "picard_converged": float(convergence["final_relative_change"]) <= float(convergence["requested_rtol"]),
        "independent_residual": float(residual["plasma_l2_relative"]) <= 0.02,
        "shape_constraints": xpoint_max <= 0.02 and isoflux_max <= 0.03,
        "plasma_current": current_error <= 1.0e-10,
    }
    return all(gates.values()), gates


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--freegs-verification", required=True)
    parser.add_argument("--cross-code-result", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    candidate = json.loads(Path(args.candidate).read_text(encoding="utf-8"))
    verification = json.loads(Path(args.freegs_verification).read_text(encoding="utf-8"))
    cross_code = json.loads(Path(args.cross_code_result).read_text(encoding="utf-8"))
    if cross_code.get("candidate_state") != "sampled_ideal_mhd_candidate":
        raise ValueError("static robustness requires sampled_ideal_mhd_candidate")
    if verification.get("status") != "pass" or verification.get("numerical_vvuq", {}).get("status") != "pass":
        raise ValueError("static robustness requires passing FreeGS numerical VVUQ")
    expected = candidate.get("result_hash")
    if expected != verification.get("candidate_result_hash") or expected != cross_code.get("candidate_result_hash"):
        raise ValueError("candidate evidence binding mismatch")
    nominal = transformed_input(
        candidate, 129, float(verification["selected_coil_vertical_multiplier"]),
        float(verification["selected_boundary_vertical_multiplier"]),
    )
    records = []
    nominal_result = None
    nominal_currents = None
    for name, solver_input in scenarios(nominal):
        raw = solve_freegs(solver_input)
        passed, gates = solver_passed(raw, solver_input)
        if name == "nominal" and passed:
            nominal_result = raw
            nominal_currents = {key: float(value) for key, value in raw["coil_currents_a"].items()}
        records.append({
            "name": name,
            "solver_input_hash": canonical_hash(solver_input),
            "solver_result_hash": raw.get("result_hash"),
            "solver_status": raw.get("status", "error"),
            "solver_gates": gates,
            "solver_passed": passed,
            "raw": raw,
            "solver_input": solver_input,
        })
    radial_build_allocation = "not_evaluated_nominal_equilibrium_failed"
    if nominal_result is None or nominal_currents is None:
        state = "static_robustness_fail"
        failed = ["nominal_static_equilibrium"]
    else:
        nominal_eq = nominal_result["equilibrium"]
        nominal_minor = float(nominal_eq["minor_radius_m"])
        nominal_axis_r = float(nominal_eq["magnetic_axis_r_m"])
        nominal_axis_z = float(nominal_eq["magnetic_axis_z_m"])
        nominal_q95 = float(nominal_eq["q_95"])
        nominal_max = max(abs(value) for value in nominal_currents.values())
        point = candidate["operating_point"]
        layout = candidate.get("magnet_layout")
        if layout is not None:
            if layout.get("layout_model") != "shared_radial_build_v100":
                raise ValueError("unsupported explicit magnet layout")
            pack_thickness = float(layout["winding_pack_thickness_m"])
            support_thickness = float(layout["support_thickness_m"])
            radial_build_allocation = "candidate_declared_shared_radial_build_v100"
        else:
            build = (float(point["coil_minor_radius_m"])
                     - float(point["wall_minor_radius_m"]))
            pack_thickness = 0.5 * build
            support_thickness = 0.5 * build
            radial_build_allocation = "equal_split_winding_and_support_v99"
        for record in records:
            raw = record.pop("raw")
            solver_input = record.pop("solver_input")
            if not record["solver_passed"]:
                record["response"] = None
                record["response_gates"] = {}
                record["case_passed"] = False
                continue
            eq = raw["equilibrium"]
            currents = {key: float(value) for key, value in raw["coil_currents_a"].items()}
            maximum_current = max(abs(value) for value in currents.values())
            displacement = math.hypot(float(eq["magnetic_axis_r_m"]) - nominal_axis_r,
                                      float(eq["magnetic_axis_z_m"]) - nominal_axis_z) / nominal_minor
            q95_change = abs(float(eq["q_95"]) / nominal_q95 - 1.0)
            minor_change = abs(float(eq["minor_radius_m"]) / nominal_minor - 1.0)
            minimum_pf_radius = min(float(coil["major_radius_m"])
                                    for coil in solver_input["machine"]["coils"])
            current_density = maximum_current / pack_thickness**2
            toroidal_field = float(point["magnetic_field_t"]) * float(point["major_radius_m"]) / minimum_pf_radius
            self_field = 4.0e-7 * maximum_current / pack_thickness
            peak_field = toroidal_field + self_field
            support_stress = peak_field**2 / (2.0 * 4.0e-7 * math.pi) * minimum_pf_radius / support_thickness
            response = {
                "normalized_axis_displacement": displacement,
                "q95_relative_change": q95_change,
                "minor_radius_relative_change": minor_change,
                "maximum_pf_current_a_turn": maximum_current,
                "pf_current_amplification": maximum_current / nominal_max,
                "maximum_paired_current_imbalance_fraction": pair_imbalance(currents, nominal_max),
                "current_density_proxy_a_m2": current_density,
                "additive_peak_field_proxy_t": peak_field,
                "membrane_support_stress_proxy_pa": support_stress,
            }
            gates = {
                "axis_displacement": displacement <= 0.02,
                "q95_response": q95_change <= 0.10,
                "minor_radius_response": minor_change <= 0.05,
                "pf_current_amplification": maximum_current / nominal_max <= 1.25,
                "paired_current_imbalance": response["maximum_paired_current_imbalance_fraction"] <= 0.20,
                "current_density_proxy": current_density <= 500.0e6,
                "additive_peak_field_proxy": peak_field <= 16.0,
                "membrane_support_stress_proxy": support_stress <= 650.0e6,
            }
            record["response"] = response
            record["response_gates"] = gates
            record["case_passed"] = all(gates.values())
        failed = sorted({gate for record in records
                         for gate, passed in record["solver_gates"].items() if not passed} |
                        {gate for record in records
                         for gate, passed in record["response_gates"].items() if not passed})
        state = "static_robustness_proxy_pass" if all(record["case_passed"] for record in records) else "static_robustness_fail"
    body = {
        "schema_version": "1.0.0",
        "runner_version": RUNNER_VERSION,
        "request_index": candidate["request_index"],
        "candidate_result_hash": expected,
        "freegs_verification_hash": verification["result_hash"],
        "cross_code_result_hash": cross_code["result_hash"],
        "routing_axes": ["field_semantics", "boundary", "operator", "dimension"],
        "identity_fields_used_for_routing": False,
        "unsupported_candidate_classification_used": False,
        "perturbation_contract": {"pf_centerline_offset_m": 0.005,
                                  "plasma_current_fraction": 0.03,
                                  "axis_pressure_fraction": 0.05},
        "engineering_proxy_contract": {"radial_build_allocation": radial_build_allocation,
                                        "current_density_limit_a_m2": 500.0e6,
                                        "peak_field_limit_t": 16.0,
                                        "support_stress_limit_pa": 650.0e6},
        "scenario_count": len(records),
        "case_pass_count": sum(record.get("case_passed", False) for record in records),
        "candidate_state": state,
        "failed_gates": failed,
        "records": records,
        "engineering_qualification": {"status": "partial_pass" if state == "static_robustness_proxy_pass" else "fail",
                                      "complete": False},
        "validation_vvuq": {"status": "unknown_validation_domain",
                            "reason": "candidate_bound_independent_measurements_unavailable"},
        "whole_device_credible": False,
        "claim_boundary": CLAIM_BOUNDARY,
    }
    body["result_hash"] = canonical_hash(body)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = output.with_suffix(output.suffix + ".partial")
    partial.write_text(json.dumps(body, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    partial.replace(output)
    print(json.dumps({key: body[key] for key in ("request_index", "candidate_state", "failed_gates", "result_hash")}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
