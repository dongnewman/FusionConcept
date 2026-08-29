#!/usr/bin/env python3
"""Seal the exact software and external-evidence blockers for the v100 survivor."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


PROTOCOL = "fusionconceptai-v101-candidate-completion-blocker-20260829"
CLAIM_BOUNDARY = (
    "This audit proves only that the repository has exhausted the declared v100 "
    "candidate-bound software chain and contains no independent validation record bound "
    "to the surviving generated design. It does not prove physical infeasibility, does "
    "not convert proxy evidence into qualification, and cannot replace measurements "
    "from a constructed experiment or an independently governed validation campaign."
)


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def read_jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(
        encoding="utf-8").splitlines() if line.strip()]


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def find_external_bindings(root: Path, candidate_hash: str) -> list[str]:
    matches = []
    for relative in ("fixtures", "examples", "data", "evidence", "external"):
        base = root / relative
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in (
                    ".json", ".jsonl", ".csv", ".tsv", ".toml", ".yaml", ".yml"):
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            if candidate_hash in text:
                matches.append(path.relative_to(root).as_posix())
    return sorted(matches)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--output-directory", required=True)
    parser.add_argument("--report", required=True)
    args = parser.parse_args()
    root = Path(args.project_root).resolve()
    output_dir = Path(args.output_directory).resolve()
    report_path = Path(args.report).resolve()
    main_dir = root / "runs" / "v100_candidate_bound_design_refinement_20260829"
    final_path = root / "runs" / "v100_full_device_qualification_20260829" / "acceptance.json"
    final = read_json(final_path)
    if final["status"] != "complete" or final["provider_system_failure_count"] != 0 or \
            final["unsupported_candidate_count"] != 0:
        raise ValueError("v100 final acceptance is not a complete zero-system-failure input")
    survivors = [row for row in final["rows"]
                 if row["candidate_state"] == "qualification_incomplete"]
    if len(survivors) != 1:
        raise ValueError("v101 requires exactly one v100 qualification-incomplete survivor")
    row = survivors[0]
    request_index = int(row["request_index"])
    candidates = {int(item["request_index"]): item for item in read_jsonl(
        main_dir / "computational_candidates.jsonl")}
    candidate = candidates[request_index]
    candidate_hash = candidate["result_hash"]
    if candidate_hash != row["candidate_result_hash"]:
        raise ValueError("final survivor is detached from the candidate stream")
    freegs = read_json(main_dir / "freegs_shared_radial_build" / "results" /
                       f"freegs_{request_index}.json")
    desc = read_json(main_dir / "desc_cross_code" / "results" /
                     f"v99_{request_index:07d}.json")
    static = read_json(main_dir / "static_robustness" / "results" /
                       f"static_{request_index}.json")
    reference = read_json(main_dir / "reference_controls.json")
    if any(item["candidate_result_hash"] != candidate_hash
           for item in (freegs, desc, static)):
        raise ValueError("candidate evidence binding mismatch")
    if freegs["status"] != "pass" or freegs["numerical_vvuq"]["status"] != "pass":
        raise ValueError("survivor lacks FreeGS numerical VVUQ")
    if desc["candidate_state"] != "sampled_ideal_mhd_candidate":
        raise ValueError("survivor lacks sampled local ideal-MHD pass")
    if static["candidate_state"] != "static_robustness_proxy_pass" or \
            static["engineering_qualification"]["complete"] is not False:
        raise ValueError("survivor static engineering evidence boundary mismatch")
    if reference["status"] != "pass" or reference["validation_pass_count"] != 0:
        raise ValueError("reference control boundary mismatch")

    bindings = find_external_bindings(root, candidate_hash)
    if bindings:
        raise ValueError("candidate-bound external evidence unexpectedly exists")
    responses = [record["response"] for record in static["records"]]
    maximum_peak = max(float(item["additive_peak_field_proxy_t"]) for item in responses)
    maximum_stress = max(float(item["membrane_support_stress_proxy_pa"])
                         for item in responses)
    maximum_current_density = max(float(item["current_density_proxy_a_m2"])
                                  for item in responses)
    stages = [
        {"stage": "free_boundary_equilibrium", "status": "pass",
         "authority": "candidate_bound_FreeGS_three_grid_numerical_VVUQ",
         "result_hash": freegs["result_hash"]},
        {"stage": "cross_code_equilibrium", "status": "pass",
         "authority": "candidate_bound_FreeGS_to_DESC_fixed_boundary_comparison",
         "result_hash": desc["result_hash"]},
        {"stage": "sampled_local_ideal_mhd", "status": "pass",
         "authority": "sampled_Mercier_and_infinite_n_ballooning_only",
         "result_hash": desc["desc_result"]["result_hash"]},
        {"stage": "static_engineering_proxy", "status": "pass",
         "authority": "nine_static_FreeGS_perturbations_and_reduced_explicit_build_proxies",
         "complete_qualification": False, "result_hash": static["result_hash"]},
    ]
    computational_gaps = [
        {"stage": "complete_stability", "status": "input_or_provider_required",
         "required": ["finite_n_ideal_modes", "resistive_modes", "kinetic_modes",
                      "nonlinear_saturation", "disruption_transients"],
         "why_existing_evidence_is_insufficient": desc["claim_boundary"]},
        {"stage": "transport_and_confinement", "status": "input_or_provider_required",
         "required": ["candidate_bound_profile_evolution", "turbulent_and_neoclassical_fluxes",
                      "independent_transport_code_comparison", "uncertainty_ensemble"],
         "why_existing_evidence_is_insufficient":
             candidate["physics_solve"]["evidence_ceiling"]},
        {"stage": "particle_and_heat_exhaust", "status": "input_or_provider_required",
         "required": ["explicit_divertor_or_exhaust_geometry", "plasma_neutral_coupling",
                      "target_heat_and_particle_flux", "detachment_and_material_limits"]},
        {"stage": "complete_engineering_and_materials", "status": "input_or_provider_required",
         "required": ["conductor_and_joint_definition", "versioned_material_property_curves",
                      "mutual_force_structural_solution", "thermal_hydraulics",
                      "quench_protection", "shielding_blanket_TBR_and_maintenance"]},
        {"stage": "dynamic_control_and_fault_response", "status": "input_or_provider_required",
         "required": ["sensor_actuator_layout", "controller_limits_and_latency",
                      "fault_inventory", "disruption_and_protection_transients"]},
    ]
    validation = {
        "stage": "validation_vvuq",
        "status": "external_evidence_required",
        "repository_candidate_bound_external_record_count": len(bindings),
        "required_record_fields": [
            "candidate_result_hash", "independent_dataset_id", "measurement_file_sha256",
            "calibration_file_sha256", "uncertainty_model", "holdout_definition",
            "measured_observables", "applicability_assessment", "independent_owner_attestation"],
        "reason": "the surviving design is generated and has no independent measurement "
                  "dataset bound to its exact physical realization",
        "software_rerun_can_close_this_stage": False,
    }
    point = candidate["operating_point"]
    body = {
        "schema_version": "1.0.0", "protocol_id": PROTOCOL,
        "status": "external_evidence_required",
        "candidate": {
            "request_index": request_index, "candidate_result_hash": candidate_hash,
            "graph_hash": candidate["graph_hash"],
            "solver_input_hash": candidate["solver_input_hash"],
            "capability_hash": candidate["capability_profile"]["capability_hash"],
            "input_origin": point["input_origin"],
            "major_radius_m": point["major_radius_m"],
            "minor_radius_m": point["minor_radius_m"],
            "magnetic_field_t": point["magnetic_field_t"],
        },
        "completed_candidate_bound_stages": stages,
        "computational_qualification_gaps": computational_gaps,
        "validation_vvuq": validation,
        "static_proxy_extrema": {
            "scenario_count": static["scenario_count"],
            "case_pass_count": static["case_pass_count"],
            "maximum_additive_peak_field_t": maximum_peak,
            "maximum_membrane_support_stress_pa": maximum_stress,
            "maximum_current_density_a_m2": maximum_current_density,
        },
        "reference_controls": {"status": "pass", "count": 2,
                               "candidate_credit": False, "validation_credit": False},
        "provider_system_failure_count": 0, "unsupported_candidate_count": 0,
        "whole_device_credible_count": 0, "validation_pass_count": 0,
        "subgraph_promotion_allowed": False,
        "identity_fields_used_for_routing": False,
        "physical_conclusion_expanded": False,
        "software_only_completion_possible": False,
        "blocking_external_state": "candidate_bound_independent_physical_measurements_absent",
        "source_acceptance_hash": final["acceptance_hash"],
        "claim_boundary": CLAIM_BOUNDARY,
    }
    body["acceptance_hash"] = canonical_hash(body)
    output_dir.mkdir(parents=True, exist_ok=True)
    acceptance_path = output_dir / "acceptance.json"
    partial = acceptance_path.with_suffix(".json.partial")
    partial.write_text(json.dumps(body, indent=2, sort_keys=True) + "\n",
                       encoding="utf-8")
    partial.replace(acceptance_path)

    report = f"""# v101 候选完成性与外部阻塞验收

候选 `{request_index}` 已通过 FreeGS 三网格 numerical VVUQ、FreeGS→DESC 跨代码平衡、
抽样 Mercier/infinite-n ballooning，以及 9/9 个静态 PF 扰动和工程代理。最大峰值场代理为
{maximum_peak:.3f} T，最大支撑应力代理为 {maximum_stress / 1e6:.3f} MPa。

它仍不是可信整机。完整有限 n/电阻/动力学/非线性/破裂稳定性、候选绑定输运和排热、完整
材料与工程、动态控制和故障响应均没有达到完整 provider 证据级别。仓库外部证据目录中与
精确 candidate hash `{candidate_hash}` 绑定的独立数据集数量为 0。

因此软件侧不能通过继续重跑、参考装置回归或 manufactured control 生成 validation VVUQ。
下一状态变化必须来自新的高保真 provider 输入，最终还必须有按本 acceptance 所列字段封装的
独立物理测量和 owner attestation。ITER/C-2W 仍只提供 2/2 路由回归，候选与验证信用均为 0。

Acceptance hash: `{body['acceptance_hash']}`

{CLAIM_BOUNDARY}
"""
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(report, encoding="utf-8")
    print(json.dumps({key: body[key] for key in (
        "status", "provider_system_failure_count", "unsupported_candidate_count",
        "whole_device_credible_count", "validation_pass_count", "blocking_external_state",
        "acceptance_hash")}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
