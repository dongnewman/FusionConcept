#!/usr/bin/env python3
"""Materialize only hash-bound v120 DESC survivors for downstream execution."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--desc-acceptance", required=True)
    parser.add_argument("--desc-results", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    source = Path(args.candidates).resolve()
    acceptance_path = Path(args.desc_acceptance).resolve()
    results = Path(args.desc_results).resolve()
    output = Path(args.output).resolve()
    candidates = [json.loads(line) for line in source.read_text(
        encoding="utf-8").splitlines() if line.strip()]
    by_hash = {item["result_hash"]: item for item in candidates}
    acceptance = json.loads(acceptance_path.read_text(encoding="utf-8"))
    survivors = []
    for row in acceptance["rows"]:
        if row["candidate_state"] != "sampled_ideal_mhd_candidate":
            continue
        artifact = json.loads((results / f"v99_{int(row['request_index']):07d}.json")
                              .read_text(encoding="utf-8"))
        candidate_hash = artifact["candidate_result_hash"]
        if candidate_hash not in by_hash:
            raise ValueError("DESC survivor is detached from candidate stream")
        if artifact["candidate_state"] != "sampled_ideal_mhd_candidate":
            raise ValueError("DESC acceptance/result state mismatch")
        if artifact["cross_code_equilibrium"]["status"] != "pass":
            raise ValueError("DESC survivor lacks shared-state cross-code pass")
        survivors.append(by_hash[candidate_hash])
    survivors.sort(key=lambda item: item["result_hash"])
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".partial")
    temporary.write_text("".join(json.dumps(item, sort_keys=True) + "\n"
                                 for item in survivors), encoding="utf-8")
    temporary.replace(output)
    body = {
        "schema_version": "1.0.0",
        "protocol_id": "fusionconceptai-v120-desc-survivor-selection-20260830",
        "status": "complete",
        "source_candidate_stream_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "source_desc_acceptance_hash": acceptance["acceptance_hash"],
        "survivor_count": len(survivors),
        "survivor_stream_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "identity_fields_used_for_routing": False,
        "unsupported_candidate_count": 0,
        "physical_pass_credit": False,
        "validation_credit": False,
        "claim_boundary": "Selection preserves only hash-bound shared-state DESC passes; downstream gates must rerun.",
    }
    body["acceptance_hash"] = canonical_hash(body)
    selection_path = output.with_name("survivor_selection_acceptance.json")
    selection_path.write_text(json.dumps(body, indent=2, sort_keys=True) + "\n",
                              encoding="utf-8")
    print(json.dumps({"status": "complete", "survivor_count": len(survivors),
                      "acceptance_hash": body["acceptance_hash"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
