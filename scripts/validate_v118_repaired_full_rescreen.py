#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / "runs" / "v118_repaired_full_rescreen_1048576_20260830"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def hashes(path: Path) -> set[str]:
    return {
        json.loads(line)["result_hash"]
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    }


reference = load(RUN / "reference_v103" / "acceptance.json")
reduced = load(RUN / "reduced" / "reduced_screen_acceptance.json")
freegs = load(RUN / "freegs_retry" / "acceptance.json")
refinement = load(RUN / "refinement" / "acceptance.json")
material_selection = load(RUN / "material_frontier" / "selection_acceptance.json")
v114_generation = load(RUN / "repair_v114" / "generation_acceptance.json")
v114_freegs = load(RUN / "repair_v114_freegs" / "acceptance.json")
v114_desc = load(RUN / "repair_v114_desc" / "acceptance.json")
v114_static = load(RUN / "repair_v114_static" / "acceptance.json")
final = load(RUN / "whole_device_final" / "acceptance.json")
v115 = load(RUN / "whole_device_final" / "v115_acceptance.json")
v116 = load(RUN / "whole_device_final" / "v116_acceptance.json")
v117 = load(RUN / "whole_device_final" / "v117_acceptance.json")

assert reference["reference_acceptance"]["reference_regression_pass_count"] == 2
assert reference["reference_acceptance"]["new_reference_bypass_count"] == 0
assert reduced["request_count"] == 1_048_576
assert sum(reduced["candidate_state_histogram"].values()) == 1_048_576
assert reduced["computational_candidate_count"] == 67
assert reduced["unsupported_candidate_count"] == 0
assert reduced["provider_system_failure_count"] == 0
assert freegs["status"] == "complete"
assert freegs["status_histogram"] == {"fail": 36, "pass": 31}
assert refinement["evaluated_design_count"] == 31_744
assert refinement["retained_count"] == 319
assert material_selection["retained_count"] == 40
assert v114_generation["repair_prefilter_survivor_count"] == 9
assert v114_freegs["status_histogram"] == {"pass": 9}
assert v114_desc["candidate_state_histogram"] == {
    "sampled_ideal_mhd_candidate": 9
}
assert v114_static["candidate_state_histogram"] == {
    "static_robustness_proxy_pass": 9
}

assert final["status"] == "complete"
assert final["reference_regression_pass_count"] == 2
assert final["reference_bypass_count"] == 0
assert final["unsupported_candidate_count"] == 0
assert final["provider_system_failure_count"] == 0
assert final["validation_vvuq_status"] == "external_evidence_required"
assert final["validation_pass_count"] == 0
assert final["whole_device_credible_count"] == 0
assert final["partial_subgraph_promotion_allowed"] is False
assert final["identity_fields_used_for_routing"] is False
assert final["basis_direct_metric_credit"] is False
assert final["stage_order"][-2:] == ["sampled_numerical_VVUQ", "validation_VVUQ"]
assert v115["material_screen_survivor_count"] == 384
assert v116["conservation_provider_survivor_count"] == 5
assert v117["channel_thermal_hydraulics_survivor_count"] == 101

assert hashes(RUN / "whole_device_final" / "v116_provider_results.jsonl") == hashes(
    ROOT / "runs" / "v116_multiregion_conservation_20260830" /
    "provider_results.jsonl"
)
assert hashes(RUN / "whole_device_final" / "v117_channel_results.jsonl") == hashes(
    ROOT / "runs" / "v117_channel_thermal_hydraulics_20260830" /
    "channel_results.jsonl"
)

print(json.dumps({
    "status": "pass",
    "grammar_count": reduced["request_count"],
    "reduced_candidate_count": reduced["computational_candidate_count"],
    "v114_static_pass_count": v114_static["candidate_state_histogram"][
        "static_robustness_proxy_pass"
    ],
    "material_survivor_count": v115["material_screen_survivor_count"],
    "conservation_survivor_count": v116["conservation_provider_survivor_count"],
    "sampled_numerical_vvuq_pass_count": v117[
        "channel_thermal_hydraulics_survivor_count"
    ],
    "validation_status": final["validation_vvuq_status"],
    "credible_count": final["whole_device_credible_count"],
    "acceptance_hash": final["acceptance_hash"],
}, sort_keys=True))
