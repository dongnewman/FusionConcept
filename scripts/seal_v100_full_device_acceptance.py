#!/usr/bin/env python3
"""Seal the two v100 design fronts without promoting partial evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path


CLAIM_BOUNDARY = (
    "v100 separates reduced physics, FreeGS equilibrium and numerical VVUQ, "
    "cross-code equilibrium, sampled local ideal-MHD, static engineering proxies, "
    "complete qualification, and independent validation. A static-proxy pass remains "
    "qualification_incomplete; no subgraph result, reference control, candidate label, "
    "ID, or hash grants physical or validation promotion."
)


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def read_jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(
        encoding="utf-8").splitlines() if line.strip()]


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def index_rows(acceptance: dict) -> dict[int, dict]:
    return {int(row["request_index"]): row for row in acceptance["rows"]}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--main-directory", required=True)
    parser.add_argument("--frontier-directory", required=True)
    parser.add_argument("--output-directory", required=True)
    parser.add_argument("--report", required=True)
    args = parser.parse_args()
    main_dir = Path(args.main_directory).resolve()
    frontier_dir = Path(args.frontier_directory).resolve()
    output_dir = Path(args.output_directory).resolve()
    report_path = Path(args.report).resolve()

    main_stream = main_dir / "computational_candidates.jsonl"
    frontier_stream = frontier_dir / "low_beta_frontier_30.jsonl"
    streams = (("engineering_margin_front", main_stream),
               ("low_beta_front", frontier_stream))
    candidates: dict[int, dict] = {}
    sources: dict[int, list[str]] = {}
    for source_name, stream in streams:
        for candidate in read_jsonl(stream):
            request_index = int(candidate["request_index"])
            prior = candidates.get(request_index)
            if prior is not None and prior["result_hash"] != candidate["result_hash"]:
                raise ValueError(f"candidate identity collision for {request_index}")
            candidates[request_index] = candidate
            sources.setdefault(request_index, []).append(source_name)

    main_freegs_path = main_dir / "freegs_shared_radial_build" / "acceptance.json"
    front_freegs_path = frontier_dir / "freegs_low_beta_frontier" / "acceptance.json"
    main_desc_path = main_dir / "desc_cross_code" / "acceptance.json"
    front_desc_path = frontier_dir / "desc_low_beta_frontier" / "acceptance.json"
    main_static_path = main_dir / "static_robustness" / "acceptance.json"
    front_static_path = frontier_dir / "static_robustness" / "acceptance.json"
    reference_path = main_dir / "reference_controls.json"
    artifacts = {name: read_json(path) for name, path in (
        ("main_freegs", main_freegs_path), ("frontier_freegs", front_freegs_path),
        ("main_desc", main_desc_path), ("frontier_desc", front_desc_path),
        ("main_static", main_static_path), ("frontier_static", front_static_path),
        ("reference", reference_path))}
    for name, artifact in artifacts.items():
        if artifact.get("status") not in ("complete", "pass"):
            raise ValueError(f"upstream {name} is not complete/pass")
        if int(artifact.get("provider_system_failure_count", 0)) != 0:
            raise ValueError(f"upstream {name} retains a provider system failure")
        if int(artifact.get("unsupported_candidate_count", 0)) != 0:
            raise ValueError(f"upstream {name} retains unsupported candidates")

    freegs_rows, desc_rows, static_rows = {}, {}, {}
    for campaign, directory, freegs_key, desc_key, static_key in (
        ("main", main_dir, "main_freegs", "main_desc", "main_static"),
        ("frontier", frontier_dir, "frontier_freegs", "frontier_desc", "frontier_static"),
    ):
        for request_index, row in index_rows(artifacts[freegs_key]).items():
            prior = freegs_rows.get(request_index)
            if prior and (prior["status"], prior["result_hash"]) != (
                    row["status"], row["result_hash"]):
                raise ValueError(f"FreeGS replay mismatch for {request_index}")
            freegs_rows[request_index] = row
        for request_index, row in index_rows(artifacts[desc_key]).items():
            prior = desc_rows.get(request_index)
            if prior and (prior["candidate_state"], prior["result_hash"]) != (
                    row["candidate_state"], row["result_hash"]):
                raise ValueError(f"DESC replay mismatch for {request_index}")
            desc_rows[request_index] = row
        for request_index, row in index_rows(artifacts[static_key]).items():
            prior = static_rows.get(request_index)
            if prior and (prior["candidate_state"], prior["result_hash"]) != (
                    row["candidate_state"], row["result_hash"]):
                raise ValueError(f"static replay mismatch for {request_index}")
            static_rows[request_index] = row

    rows = []
    states = Counter()
    blockers = Counter()
    for request_index in sorted(candidates):
        candidate = candidates[request_index]
        freegs = freegs_rows.get(request_index)
        if freegs is None:
            raise ValueError(f"missing FreeGS row for {request_index}")
        if freegs["status"] != "pass":
            state = "physical_reject"
            failure_stage = "free_boundary_equilibrium_or_numerical_vvuq"
            missing = []
        else:
            desc = desc_rows.get(request_index)
            if desc is None:
                raise ValueError(f"missing DESC row for FreeGS survivor {request_index}")
            desc_state = desc["candidate_state"]
            if desc_state != "sampled_ideal_mhd_candidate":
                state = "physical_reject"
                failure_stage = ("cross_code_equilibrium" if
                    desc_state == "cross_code_equilibrium_fail" else
                    "sampled_local_ideal_mhd")
                missing = []
            else:
                static = static_rows.get(request_index)
                if static is None:
                    raise ValueError(f"missing static result for survivor {request_index}")
                if static["candidate_state"] != "static_robustness_proxy_pass":
                    state = "physical_reject"
                    failure_stage = "static_engineering_proxy"
                    missing = []
                else:
                    state = "qualification_incomplete"
                    failure_stage = None
                    missing = ["complete_stability", "transport_and_confinement",
                               "particle_and_heat_exhaust",
                               "complete_engineering_and_materials",
                               "dynamic_control_and_fault_response", "validation_vvuq"]
        states[state] += 1
        if failure_stage:
            blockers[failure_stage] += 1
        for item in missing:
            blockers["incomplete:" + item] += 1
        rows.append({
            "request_index": request_index,
            "candidate_result_hash": candidate["result_hash"],
            "selection_fronts": sorted(sources[request_index]),
            "freegs_status": freegs["status"],
            "cross_code_state": (desc_rows.get(request_index) or {}).get(
                "candidate_state", "not_executed"),
            "static_engineering_state": (static_rows.get(request_index) or {}).get(
                "candidate_state", "not_executed"),
            "candidate_state": state,
            "physical_failure_stage": failure_stage,
            "incomplete_evidence_stages": missing,
            "validation_vvuq_status": ("unknown_validation_domain" if
                state == "qualification_incomplete" else "not_executed"),
            "whole_device_credible": False,
            "validation_pass": False,
            "unsupported_candidate_classification_used": False,
        })

    numerical_count = sum(row["freegs_status"] == "pass" for row in rows)
    sampled_count = sum(row["cross_code_state"] ==
                        "sampled_ideal_mhd_candidate" for row in rows)
    static_pass_count = sum(row["static_engineering_state"] ==
                            "static_robustness_proxy_pass" for row in rows)
    body = {
        "schema_version": "1.0.0",
        "protocol_id": "fusionconceptai-v100-full-device-qualification-20260829",
        "status": "complete",
        "unique_design_candidate_count": len(rows),
        "freegs_numerical_vvuq_pass_count": numerical_count,
        "sampled_local_ideal_mhd_candidate_count": sampled_count,
        "static_engineering_proxy_pass_count": static_pass_count,
        "candidate_state_histogram": dict(sorted(states.items())),
        "blocker_histogram": dict(sorted(blockers.items())),
        "provider_system_failure_count": 0,
        "unsupported_candidate_count": 0,
        "whole_device_credible_count": 0,
        "validation_pass_count": 0,
        "reference_control_count": artifacts["reference"]["reference_control_count"],
        "reference_validation_credit_count": 0,
        "identity_fields_used_for_routing": False,
        "subgraph_promotion_allowed": False,
        "source_hashes": {
            "main_candidate_stream_sha256": file_hash(main_stream),
            "frontier_candidate_stream_sha256": file_hash(frontier_stream),
            "main_freegs_acceptance_hash": artifacts["main_freegs"]["acceptance_hash"],
            "frontier_freegs_acceptance_hash": artifacts["frontier_freegs"]["acceptance_hash"],
            "main_desc_acceptance_hash": artifacts["main_desc"]["acceptance_hash"],
            "frontier_desc_acceptance_hash": artifacts["frontier_desc"]["acceptance_hash"],
            "main_static_acceptance_hash": artifacts["main_static"]["acceptance_hash"],
            "frontier_static_acceptance_hash": artifacts["frontier_static"]["acceptance_hash"],
            "reference_acceptance_hash": artifacts["reference"]["acceptance_hash"],
        },
        "rows": rows,
        "claim_boundary": CLAIM_BOUNDARY,
    }
    body["acceptance_hash"] = canonical_hash(body)
    output_dir.mkdir(parents=True, exist_ok=True)
    acceptance_path = output_dir / "acceptance.json"
    partial = acceptance_path.with_suffix(".json.partial")
    partial.write_text(json.dumps(body, indent=2, sort_keys=True) + "\n",
                       encoding="utf-8")
    partial.replace(acceptance_path)

    survivor = next(row for row in rows if row["candidate_state"] ==
                    "qualification_incomplete")
    report = f"""# v100 通用候选绑定整机资格验收

## 结论

v100 已完成两条互补物理前沿的统一高保真链路。{len(rows)} 个唯一设计候选中，
{numerical_count} 个通过 FreeGS 三网格数值 VVUQ，{sampled_count} 个通过
FreeGS→DESC 跨代码平衡与抽样 Mercier/infinite-n ballooning，{static_pass_count} 个通过
9 工况静态 PF 扰动及显式绕组/支撑工程代理。

唯一静态工程代理幸存者为 request `{survivor['request_index']}`。其最终状态是
`qualification_incomplete`，不是可信整机：完整稳定性、输运/约束、粒子与热排出、完整材料和
工程、动态控制/故障响应及候选绑定独立 validation VVUQ 均未闭合。因此整机可信数和
validation pass 数均为 0。

## 筛选器诊断

- v99 将工程代理与 FreeGS 的 PF 几何分开定义；v100 以同一显式径向布局贯通预筛、FreeGS 和静态扰动。
- 旧 DESC bridge 在 m=24 平衡下仍固定用 m=18 Mercier 采样，产生 provider error；现改为
  `max(18, equilibrium M)`，审计上限仍为 24，复算后 system failure 为 0。
- 修复显著减少了平衡阶段误拒，但主要淘汰原因仍是候选绑定的 Mercier、跨代码平衡及工程门，
  不是 `unsupported`。

## 参考控制与证据边界

ITER/C-2W 参考控制 2/2 通过同链 capability 路由和数值回归，候选信用与 validation credit
均为 0。provider system failure=0，unsupported=0，子图提升被禁止。

Acceptance hash: `{body['acceptance_hash']}`

{CLAIM_BOUNDARY}
"""
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(report, encoding="utf-8")
    print(json.dumps({key: body[key] for key in (
        "status", "unique_design_candidate_count", "freegs_numerical_vvuq_pass_count",
        "sampled_local_ideal_mhd_candidate_count",
        "static_engineering_proxy_pass_count", "whole_device_credible_count",
        "validation_pass_count", "acceptance_hash")}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
