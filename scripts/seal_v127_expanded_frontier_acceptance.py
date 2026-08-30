#!/usr/bin/env python3
"""Seal the expanded repaired frontier without promoting numerical evidence to validation."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


def canonical_hash(value: object) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    v125 = root / "runs" / "v125_profile21_frontier_expansion_20260830"
    v126 = root / "runs" / "v126_frontier_static_repair_20260830"
    v127 = root / "runs" / "v127_expanded_frontier_full_chain_20260830"
    generation125 = read(v125 / "generation" / "generation_acceptance.json")
    freegs125 = read(v125 / "freegs" / "acceptance.json")
    desc125 = read(v125 / "desc" / "acceptance.json")
    static125 = read(v125 / "static" / "acceptance.json")
    generation126 = read(v126 / "generation" / "generation_acceptance.json")
    freegs126 = read(v126 / "freegs" / "acceptance.json")
    desc126 = read(v126 / "desc" / "acceptance.json")
    static126 = read(v126 / "static" / "acceptance.json")
    chain = read(v127 / "acceptance.json")
    channel = read(v127 / "channel_acceptance.json")
    rows = [json.loads(line) for line in (v127 / "v124_channels.jsonl").read_text(
        encoding="utf-8").splitlines() if line.strip()]
    passed = [row for row in rows if row["status"] == "pass"]
    assert generation125["selected_parent_count"] == 23
    assert freegs125["status_histogram"] == {"fail": 7, "pass": 16}
    assert desc125["candidate_state_histogram"] == {
        "sampled_ideal_mhd_candidate": 12, "stability_screen_fail": 4}
    assert static125["candidate_state_histogram"] == {"static_robustness_fail": 12}
    assert generation126["proposal_count"] == 108 and generation126["retained_count"] == 29
    assert freegs126["status_histogram"] == {"fail": 2, "pass": 27}
    assert desc126["provider_system_failure_count"] == 0
    assert desc126["candidate_state_histogram"] == {
        "sampled_ideal_mhd_candidate": 17, "transformer_fit_fail": 10}
    assert static126["candidate_state_histogram"] == {
        "static_robustness_fail": 8, "static_robustness_proxy_pass": 9}
    assert chain["reference_regression_pass_count"] == 2
    assert chain["reference_bypass_count"] == 0
    assert chain["unsupported_candidate_count"] == 0
    assert chain["provider_system_failure_count"] == 0
    assert chain["validation_vvuq_status"] == "external_evidence_required"
    assert chain["validation_pass_count"] == 0 and chain["whole_device_credible_count"] == 0
    assert len(passed) == 40 and all(all(row["gates"].values()) for row in passed)
    survivor_candidates = sorted({row["source_candidate_result_hash"] for row in passed})
    survivor_assemblies = sorted({row["physical_design_hash"] for row in passed})
    assert len(survivor_candidates) == channel["unique_survivor_source_candidate_count"] == 4
    assert len(survivor_assemblies) == channel["unique_survivor_assembly_count"] == 14
    stage_order = chain["stage_order"]
    assert stage_order.index("sampled_numerical_VVUQ") < stage_order.index("validation_VVUQ")
    source_hashes = {
        "v125_generation": generation125["acceptance_hash"],
        "v125_freegs": freegs125["acceptance_hash"],
        "v125_desc": desc125["acceptance_hash"],
        "v125_static": static125["acceptance_hash"],
        "v126_generation": generation126["acceptance_hash"],
        "v126_freegs": freegs126["acceptance_hash"],
        "v126_desc": desc126["acceptance_hash"],
        "v126_static": static126["acceptance_hash"],
        "v127_chain": chain["acceptance_hash"],
        "v127_channel": channel["acceptance_hash"],
    }
    provider_source_hashes = {
        name: hashlib.sha256((root / relative).read_bytes()).hexdigest()
        for name, relative in {
            "sealed_freegs_runner": "scripts/freegs_runner.py",
            "shared_state_freegs_wrapper": "scripts/freegs_shared_state_runner_v119.py",
            "freegs_candidate_runner": "scripts/run_v100_freegs_candidate.py",
            "desc_axisymmetric_wrapper": "scripts/desc_axisymmetric_stability_v99_runner.py",
            "desc_candidate_runner": "scripts/run_v100_desc_candidate.py",
            "channel_thermal_hydraulics_provider":
                "src/channel_thermal_hydraulics_provider_v117.jl",
        }.items()
    }
    assert provider_source_hashes["sealed_freegs_runner"] == (
        "2d2aa2f5941fce6eda7681ce0daa9011b1fba65bb560e23143f132af9889fec8")
    body = {
        "schema_version": "1.0.0",
        "protocol_id": "fusionconceptai-v127-expanded-frontier-acceptance-20260830",
        "status": "complete",
        "source_acceptance_hashes": source_hashes,
        "provider_source_hashes": provider_source_hashes,
        "reference_regression_pass_count": 2,
        "reference_bypass_count": 0,
        "corrected_low_beta_parent_count": 23,
        "profile21_freegs_pass_count": 16,
        "profile21_desc_sampled_ideal_mhd_pass_count": 12,
        "static_repair_proposal_count": 108,
        "static_repair_reduced_retained_count": 29,
        "static_repaired_desc_sampled_ideal_mhd_pass_count": 17,
        "static_robustness_survivor_count": 9,
        "material_survivor_row_count": chain["material_survivor_count"],
        "conservation_provider_survivor_count": chain[
            "conservation_provider_survivor_count"],
        "sampled_whole_graph_numerical_vvuq_pass_count": len(passed),
        "computational_survivor_candidate_count": len(survivor_candidates),
        "computational_survivor_assembly_count": len(survivor_assemblies),
        "minimum_survivor_updated_net_electric_power_w": min(
            row["updated_net_electric_power_w"] for row in passed),
        "maximum_survivor_loss_of_flow_structure_temperature_k": max(
            row["loss_of_flow_structure_temperature_k"] for row in passed),
        "maximum_survivor_pressure_drop_pa": max(
            row["nominal_hydraulics"]["pressure_drop_pa"] for row in passed),
        "unsupported_candidate_count": 0,
        "provider_system_failure_count": 0,
        "unknown_physical_status_count": 0,
        "numerical_vvuq_status": "sampled_pass",
        "validation_vvuq_status": "external_evidence_required",
        "validation_pass_count": 0,
        "credible_new_device_count": 0,
        "complete_stability_credit": False,
        "complete_transport_credit": False,
        "complete_engineering_credit": False,
        "partial_subgraph_promotion_allowed": False,
        "identity_fields_used_for_routing": False,
        "basis_direct_metric_credit": False,
        "survivor_candidate_result_hashes": survivor_candidates,
        "claim_boundary": (
            "v127 establishes four candidate-bound computational survivors through the "
            "declared sampled whole-graph numerical chain. It does not establish complete "
            "MHD/transport/3D engineering, experimental validation or a credible physical "
            "fusion device. Unknown, unsupported, numerical and validation states remain independent."),
    }
    body["acceptance_hash"] = canonical_hash(body)
    path = v127 / "expanded_acceptance.json"
    path.write_text(json.dumps(body, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    report = f"""# v127 扩展候选前沿验收

ITER/C-2W scoped regression 为 2/2，bypass=0。修正低-β 前沿 23 个父候选经
`(alpha_m, alpha_n)=(2,1)` profile 重筛后：FreeGS 16 pass、DESC sampled ideal-MHD
12 pass；静态修复生成 108 条，reduced gates 留下 29 条，最终 17 条通过 DESC、9 条
通过九情景静态扰动。

完整下游图得到 40 条 sampled numerical-VVUQ pass，覆盖 4 个候选、14 个 assembly。
通过行的更新净电最小值为 {body['minimum_survivor_updated_net_electric_power_w']:.3f} W，
50% 流量故障结构温度最大值为
{body['maximum_survivor_loss_of_flow_structure_temperature_k']:.3f} K，实际压降最大值为
{body['maximum_survivor_pressure_drop_pa']:.3f} Pa。

Unsupported=0，provider/system failure=0。Validation VVUQ 仍为
`external_evidence_required`，完整稳定性、完整 transport 与 3D 工程资格也未建立，
因此 credible new device=0。这里的 4 条是计算 survivor，不是物理装置验证通过。

Acceptance hash: `{body['acceptance_hash']}`
"""
    (v127 / "expanded_acceptance_report.md").write_text(report, encoding="utf-8")
    print(json.dumps({key: body[key] for key in (
        "status", "computational_survivor_candidate_count",
        "sampled_whole_graph_numerical_vvuq_pass_count", "unsupported_candidate_count",
        "provider_system_failure_count", "validation_vvuq_status",
        "credible_new_device_count", "acceptance_hash")}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
