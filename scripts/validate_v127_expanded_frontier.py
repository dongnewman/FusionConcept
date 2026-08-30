#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path


def canonical_hash(value: object) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    path = root / "runs" / "v127_expanded_frontier_full_chain_20260830" / "expanded_acceptance.json"
    body = json.loads(path.read_text(encoding="utf-8"))
    stored = body.pop("acceptance_hash")
    assert stored == canonical_hash(body)
    assert body["status"] == "complete"
    assert body["reference_regression_pass_count"] == 2
    assert body["reference_bypass_count"] == 0
    assert body["computational_survivor_candidate_count"] == 4
    assert body["sampled_whole_graph_numerical_vvuq_pass_count"] == 40
    assert body["unsupported_candidate_count"] == 0
    assert body["provider_system_failure_count"] == 0
    assert body["numerical_vvuq_status"] == "sampled_pass"
    assert body["validation_vvuq_status"] == "external_evidence_required"
    assert body["validation_pass_count"] == 0
    assert body["credible_new_device_count"] == 0
    assert body["partial_subgraph_promotion_allowed"] is False
    assert body["identity_fields_used_for_routing"] is False
    print(json.dumps({"status": "pass", "acceptance_hash": stored,
                      "computational_survivor_candidate_count": 4,
                      "credible_new_device_count": 0}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
