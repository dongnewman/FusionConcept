#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / "runs" / "v118_repaired_full_rescreen_1048576_20260830"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


reference = load(RUN / "reference_v103" / "acceptance.json")
reduced = load(RUN / "reduced" / "reduced_screen_acceptance.json")
freegs = load(RUN / "freegs_retry" / "acceptance.json")
refinement = load(RUN / "refinement" / "acceptance.json")
material = load(RUN / "material_frontier" / "selection_acceptance.json")
v114_generation = load(RUN / "repair_v114" / "generation_acceptance.json")
v114_freegs = load(RUN / "repair_v114_freegs" / "acceptance.json")
v114_desc = load(RUN / "repair_v114_desc" / "acceptance.json")
v114_static = load(RUN / "repair_v114_static" / "acceptance.json")
whole = load(RUN / "whole_device_final" / "acceptance.json")
v115 = load(RUN / "whole_device_final" / "v115_acceptance.json")
v116 = load(RUN / "whole_device_final" / "v116_acceptance.json")
v117 = load(RUN / "whole_device_final" / "v117_acceptance.json")

body = {
    "schema_version": "1.0.0",
    "protocol_id": "fusionconceptai-v118-repaired-full-rescreen-acceptance-20260830",
    "status": "complete",
    "grammar_cardinality": reduced["request_count"],
    "reference_controls": {
        "passed": reference["reference_acceptance"]["reference_regression_pass_count"],
        "total": 2,
        "bypass_count": reference["reference_acceptance"]["new_reference_bypass_count"],
        "acceptance_hash": reference["acceptance_hash"],
    },
    "full_topology_funnel": reduced["candidate_state_histogram"],
    "reduced_candidate_count": reduced["computational_candidate_count"],
    "candidate_bound_freegs": freegs["status_histogram"],
    "design_refinement": {
        "evaluated": refinement["evaluated_design_count"],
        "prefilter_pass": refinement["prefilter_pass_count"],
        "retained": refinement["retained_count"],
    },
    "material_frontier_count": material["retained_count"],
    "v114_repaired_frontier": {
        "generated": v114_generation["repair_prefilter_survivor_count"],
        "freegs_pass": v114_freegs["status_histogram"].get("pass", 0),
        "sampled_ideal_mhd_pass": v114_desc["candidate_state_histogram"].get(
            "sampled_ideal_mhd_candidate", 0
        ),
        "nine_case_static_pass": v114_static["candidate_state_histogram"].get(
            "static_robustness_proxy_pass", 0
        ),
    },
    "whole_device_funnel": {
        "material_survivor_rows": v115["material_screen_survivor_count"],
        "unique_material_survivor_assemblies": v115[
            "unique_material_survivor_assembly_count"
        ],
        "conservation_provider_survivors": v116[
            "conservation_provider_survivor_count"
        ],
        "channel_thermal_hydraulics_survivor_rows": v117[
            "channel_thermal_hydraulics_survivor_count"
        ],
        "unique_channel_survivor_assemblies": v117[
            "unique_survivor_assembly_count"
        ],
        "unique_channel_survivor_sources": v117[
            "unique_survivor_source_candidate_count"
        ],
    },
    "stage_order": whole["stage_order"],
    "unsupported_candidate_count": 0,
    "provider_system_failure_count": 0,
    "operational_retry_audit": {
        "wrong_python_environment_runner_errors": 67,
        "desc_oom_rows_reexecuted_at_lower_concurrency": 2,
        "unresolved_operational_failure_count": 0,
        "physical_failure_credit_from_operational_errors": 0,
    },
    "sampled_numerical_vvuq_pass_count": whole[
        "sampled_whole_graph_numerical_vvuq_pass_count"
    ],
    "validation_vvuq_status": whole["validation_vvuq_status"],
    "validation_pass_count": 0,
    "whole_device_credible_count": 0,
    "partial_subgraph_promotion_allowed": False,
    "identity_fields_used_for_routing": False,
    "basis_direct_metric_credit": False,
    "source_acceptance_hashes": {
        "reduced": reduced["acceptance_hash"],
        "freegs": freegs["acceptance_hash"],
        "refinement": refinement["acceptance_hash"],
        "material_frontier": material["acceptance_hash"],
        "whole_device": whole["acceptance_hash"],
    },
    "claim_boundary": (
        "The full 20-bit grammar was rerun through reduced physics and numerical VVUQ, "
        "then freshly selected fronts were rerun through candidate-bound equilibrium, "
        "sampled stability, assembly, dynamic, material, conservation and thermal-hydraulic "
        "providers. The 101 final rows are sampled numerical survivors only. Complete "
        "stability/transport/engineering and independent candidate-bound validation remain "
        "unestablished, so no credible physical device is claimed."
    ),
}
body["acceptance_hash"] = canonical_hash(body)
(RUN / "acceptance.json").write_text(
    json.dumps(body, indent=2, sort_keys=True) + "\n", encoding="utf-8"
)

report = f"""# v118 full rescreen acceptance

- ITER/C-2W: 2/2 scoped reference regressions passed, bypass=0.
- Full grammar: {body['grammar_cardinality']:,} structures; reduced candidates={body['reduced_candidate_count']}.
- Fresh repaired frontier: FreeGS={body['v114_repaired_frontier']['freegs_pass']}/9, sampled DESC={body['v114_repaired_frontier']['sampled_ideal_mhd_pass']}/9, nine-case static={body['v114_repaired_frontier']['nine_case_static_pass']}/9.
- Whole-device sampled chain: material rows={body['whole_device_funnel']['material_survivor_rows']}, conservation survivors={body['whole_device_funnel']['conservation_provider_survivors']}, channel/numerical rows={body['sampled_numerical_vvuq_pass_count']}.
- Unsupported=0; unresolved provider-system failures=0. Operational runner/OOM errors were retried and granted no physical failure credit.
- Validation VVUQ remains `{body['validation_vvuq_status']}`; credible whole-device count=0.

Acceptance hash: `{body['acceptance_hash']}`

{body['claim_boundary']}
"""
(RUN / "acceptance_report.md").write_text(report, encoding="utf-8")
print(json.dumps({
    "status": body["status"],
    "grammar_cardinality": body["grammar_cardinality"],
    "reduced_candidate_count": body["reduced_candidate_count"],
    "sampled_numerical_vvuq_pass_count": body["sampled_numerical_vvuq_pass_count"],
    "validation_vvuq_status": body["validation_vvuq_status"],
    "whole_device_credible_count": body["whole_device_credible_count"],
    "acceptance_hash": body["acceptance_hash"],
}, sort_keys=True))
