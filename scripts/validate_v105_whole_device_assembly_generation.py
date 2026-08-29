#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def canonical_hash(value: object) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"),
                                     allow_nan=False).encode()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", required=True)
    args = parser.parse_args()
    root = Path(args.project_root).resolve()
    directory = root / "runs" / "v105_whole_device_assembly_generation_20260829"
    acceptance = json.loads((directory / "acceptance.json").read_text(encoding="utf-8"))
    stored = acceptance.pop("acceptance_hash")
    assert stored == canonical_hash(acceptance)
    assert acceptance["status"] == "assembly_inputs_closed"
    assert acceptance["assembly_proposal_count"] == 64
    assert acceptance["assembly_input_closed_count"] == 64
    assert acceptance["whole_device_provider_preflight_ready"] is False
    assert acceptance["whole_device_search_authorized"] is False
    assert acceptance["unsupported_candidate_count"] == 0
    assert acceptance["physical_reject_count"] == 0
    assert acceptance["physical_pass_count"] == 0
    assert acceptance["whole_device_credible_count"] == 0
    assert acceptance["validation_pass_count"] == 0
    proposals = [json.loads(line) for line in
                 (directory / "assembly_proposals.jsonl").read_text(
                     encoding="utf-8").splitlines() if line.strip()]
    assert len(proposals) == 64
    assert len({item["physical_design_hash"] for item in proposals}) == 64
    assert all(item["candidate_state"] == "whole_device_assembly_proposal"
               for item in proposals)
    assert all(item["basis_direct_metric_credit"] is False
               for item in (proposal["physical_design"] for proposal in proposals))
    print(json.dumps({"status": "pass", "acceptance_hash": stored,
                      "assembly_proposal_count": 64}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
