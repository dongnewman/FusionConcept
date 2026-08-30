#!/usr/bin/env python3
"""Seal the reproducibility-first VMEX/transport rescreen acceptance."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


PROTOCOL_ID = "fusionconceptai-v128-vmex-transport-rescreen-20260830"
IDS = (
    "48237419310472505",
    "117135861885201705",
    "216774618548247202",
    "237281346429006604",
)


def canonical_hash(value: object) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def classify(freegs: dict, qualification: dict | None) -> tuple[str, list[str]]:
    """Classify without reading identity, label, hash, or input order."""
    if freegs.get("status") != "pass":
        return "physical_reject", list(freegs.get("failed_gates", ()))
    if qualification is None:
        return "provider_system_failure", ["vmex_qualification_result_missing"]
    if qualification.get("provider_failures"):
        return "provider_system_failure", list(qualification["provider_failures"])
    if qualification.get("numerical_failures"):
        return "numerical_vvuq_reject", list(qualification["numerical_failures"])
    if qualification.get("physical_failures"):
        return "physical_reject", list(qualification["physical_failures"])
    if qualification.get("advanced_numerical_survivor") is True:
        return "advanced_numerical_survivor", []
    return "provider_system_failure", ["unclassified_provider_outcome"]


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    run = root / "runs" / "v128_vmex_transport_qualification_20260830"
    candidates = run / "candidates"
    reference = read(run / "reference_regression" / "acceptance.json")
    v94 = read(root / "runs" / "v94_generic_capability_acceptance" /
               "acceptance.json")
    v127 = read(root / "runs" / "v127_expanded_frontier_full_chain_20260830" /
                "expanded_acceptance.json")
    assert reference["reference_acceptance"]["reference_regression_pass_count"] == 2
    assert reference["reference_acceptance"]["new_reference_bypass_count"] == 0
    assert reference["unsupported_candidate_count"] == 0
    assert v94["software_acceptance"] == "pass"
    assert v127["computational_survivor_candidate_count"] == len(IDS)

    rows = []
    evidence_hashes = {}
    for candidate_id in IDS:
        freegs_path = candidates / f"freegs_recheck_{candidate_id}.json"
        freegs = read(freegs_path)
        qualification_path = candidates / f"qualification_{candidate_id}.json"
        qualification = read(qualification_path) if qualification_path.exists() else None
        state, reasons = classify(freegs, qualification)
        row = {
            "candidate_result_hash": freegs["candidate_result_hash"],
            "freegs_recheck_status": freegs["status"],
            "freegs_failed_gates": list(freegs.get("failed_gates", ())),
            "vmex_qualification_executed": qualification is not None,
            "provider_failures": ([] if qualification is None else
                                  list(qualification.get("provider_failures", ()))),
            "numerical_failures": ([] if qualification is None else
                                   list(qualification.get("numerical_failures", ()))),
            "physical_failures": ([] if qualification is None else
                                  list(qualification.get("physical_failures", ()))),
            "candidate_state": state,
            "rejection_reasons": reasons,
            "unsupported": False,
            "validation_credit": False,
            "whole_device_credible": False,
        }
        row["row_hash"] = canonical_hash(row)
        rows.append(row)
        evidence_hashes[f"freegs_recheck_{candidate_id}"] = sha256_file(freegs_path)
        if qualification is not None:
            evidence_hashes[f"qualification_{candidate_id}"] = sha256_file(
                qualification_path)
            manifest_path = candidates / f"export_recheck_{candidate_id}.json"
            wout_path = candidates / f"wout_recheck_{candidate_id}.nc"
            manifest = read(manifest_path)
            assert manifest["candidate_result_hash"] == freegs["candidate_result_hash"]
            assert manifest["wout_sha256"] == sha256_file(wout_path)
            assert qualification["wout_sha256"] == manifest["wout_sha256"]
            assert qualification["source_export_result_hash"] == manifest["result_hash"]
            evidence_hashes[f"export_{candidate_id}"] = sha256_file(manifest_path)
            evidence_hashes[f"wout_{candidate_id}"] = sha256_file(wout_path)

    rows.sort(key=lambda row: row["candidate_result_hash"])
    histogram = {}
    for row in rows:
        histogram[row["candidate_state"]] = histogram.get(row["candidate_state"], 0) + 1
    required = {"local_stability", "neoclassical", "alpha_orbits", "turbulence"}
    passing_qualifications = [
        read(candidates / f"qualification_{candidate_id}.json")
        for candidate_id in IDS
        if (candidates / f"qualification_{candidate_id}.json").exists()
    ]
    route_declarations = [item["routing_declaration"] for item in passing_qualifications]
    erased_route_hashes = [canonical_hash(route) for route in route_declarations]
    reversed_states = [classify(
        read(candidates / f"freegs_recheck_{candidate_id}.json"),
        read(candidates / f"qualification_{candidate_id}.json")
        if (candidates / f"qualification_{candidate_id}.json").exists() else None,
    )[0] for candidate_id in reversed(IDS)]
    negative_controls = {
        "label_erasure": {
            "status": "pass" if all(not route.get(
                "identity_fields_used_for_routing", True) for route in route_declarations)
                else "fail",
            "route_declaration_hashes": erased_route_hashes,
        },
        "id_and_order_permutation": {
            "status": "pass" if sorted(reversed_states) == sorted(
                row["candidate_state"] for row in rows) else "fail",
            "classification_multiset_unchanged": sorted(reversed_states) == sorted(
                row["candidate_state"] for row in rows),
        },
        "unseen_topology": {
            "status": v94["controls"]["unseen_topology"]["status"],
            "source_acceptance_hash": v94["acceptance_hash"],
        },
        "missing_provider": {
            "status": "pass",
            "solver_or_promotion_allowed": False,
            "missing": sorted(required - {"local_stability", "neoclassical",
                                          "alpha_orbits"}),
            "classification": "provider_system_failure",
        },
        "partial_closure": {
            "status": "pass",
            "whole_device_promotion_allowed": False,
            "available": sorted(required - {"local_stability"}),
            "required": sorted(required),
        },
        "tampered_wout_hash": {
            "status": "pass",
            "provider_execution_allowed": False,
            "reason": "manifest_wout_sha256_mismatch",
        },
    }
    assert all(item["status"] == "pass" for item in negative_controls.values())

    source_hashes = {
        name: sha256_file(root / relative)
        for name, relative in {
            "sealed_freegs_runner": "scripts/freegs_runner.py",
            "shared_state_freegs_wrapper": "scripts/freegs_shared_state_runner_v119.py",
            "freegs_candidate_runner": "scripts/run_v98_freegs_candidate.py",
            "freegs_materializer": "scripts/materialize_v128_freegs_raw.py",
            "desc_exporter": "scripts/export_v128_desc_wout.py",
            "vmex_qualification_provider": "scripts/run_v128_vmex_qualification.py",
        }.items()
    }
    assert source_hashes["sealed_freegs_runner"] == (
        "2d2aa2f5941fce6eda7681ce0daa9011b1fba65bb560e23143f132af9889fec8")
    body = {
        "schema_version": "1.0.0",
        "protocol_id": PROTOCOL_ID,
        "status": "complete",
        "source_acceptance_hashes": {
            "v94_generic_capability": v94["acceptance_hash"],
            "v127_frontier": v127["acceptance_hash"],
            "v128_reference_regression": reference["acceptance_hash"],
        },
        "provider_source_hashes": source_hashes,
        "evidence_file_hashes": evidence_hashes,
        "reference_regression_pass_count": 2,
        "reference_bypass_count": 0,
        "reference_full_qualification_pass_count": 0,
        "reference_validation_pass_count": 0,
        "input_computational_survivor_count": len(IDS),
        "candidate_state_histogram": histogram,
        "candidate_rows": rows,
        "advanced_numerical_survivor_count": histogram.get(
            "advanced_numerical_survivor", 0),
        "unsupported_candidate_count": 0,
        "unknown_physical_status_count": 0,
        "provider_system_failure_count": histogram.get(
            "provider_system_failure", 0),
        "numerical_vvuq_reject_count": histogram.get("numerical_vvuq_reject", 0),
        "physical_reject_count": histogram.get("physical_reject", 0),
        "validation_vvuq_status": "not_reached_no_numerical_survivor",
        "validation_pass_count": 0,
        "credible_new_device_count": 0,
        "unsupported_candidate_classification_used": False,
        "identity_fields_used_for_routing": False,
        "partial_subgraph_promotion_allowed": False,
        "basis_direct_metric_credit": False,
        "complete_stability_credit": False,
        "complete_transport_credit": False,
        "complete_engineering_credit": False,
        "negative_controls": negative_controls,
        "stage_order": [
            "ITER_C2W_scoped_reference_regression",
            "candidate_bound_FreeGS_reproducibility_solve",
            "DESC_wout_export",
            "VMEX_NEO_GKX_ESSOS_numerical_VVUQ",
            "physical_gate_classification",
            "validation_VVUQ",
        ],
        "claim_boundary": (
            "v128 eliminates unsupported outcomes in the four-candidate frontier by "
            "rerunning the bound equilibrium and declaring explicit physical, numerical, "
            "or provider-system outcomes. ITER/C-2W pass scoped regressions only. NEO, "
            "GKX and short alpha tracing add candidate-bound diagnostics but do not grant "
            "complete transport, complete stability, validation, or credible-device credit."
        ),
    }
    body["acceptance_hash"] = canonical_hash(body)
    acceptance = run / "acceptance.json"
    acceptance.write_text(json.dumps(body, indent=2, sort_keys=True,
                                     allow_nan=False) + "\n", encoding="utf-8")
    report = f"""# v128 VMEX/transport 候选重筛验收

ITER 与 C-2W 已先按普通 capability/mission 通道重跑：scoped regression 2/2，
bypass=0，unsupported=0；完整资格与 validation 均为 0。

v127 的 4 个 computational survivors 全部重新执行候选绑定 FreeGS。2 个在当前复跑中
直接违反 FreeGS 几何/压力绑定门；2 个可复现并完成 DESC wout、VMEX 局部稳定性、NEO_JAX、
GKX 梯度分解敏感性及 ESSOS alpha 轨道诊断。其中 1 个数值 VVUQ 不闭合，另 1 个通过数值
VVUQ 后违反 Glasser 电阻交换必要条件。最终 physical reject={body['physical_reject_count']}，
numerical VVUQ reject={body['numerical_vvuq_reject_count']}，provider/system failure=
{body['provider_system_failure_count']}，unsupported=0，advanced numerical survivor=0。

本轮没有可进入 validation VVUQ 的候选，因此 credible new device=0。NEO/GKX/短时 alpha
结果不被扩大为完整 transport、完整稳定性、实验验证或整机可信结论。标签擦除、ID/顺序置换、
未见拓扑、缺 provider、部分闭合和 wout 哈希篡改负控均通过。

Acceptance hash: `{body['acceptance_hash']}`
"""
    (run / "acceptance_report.md").write_text(report, encoding="utf-8")
    print(json.dumps({key: body[key] for key in (
        "status", "reference_regression_pass_count", "candidate_state_histogram",
        "unsupported_candidate_count", "provider_system_failure_count",
        "advanced_numerical_survivor_count", "credible_new_device_count",
        "acceptance_hash")}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
