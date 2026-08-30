#!/usr/bin/env python3
"""Materialize hash-bound nine-case static survivors for the whole-device chain."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def canonical_hash(value: object) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--static-acceptance", required=True)
    parser.add_argument("--static-results", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    source = Path(args.candidates).resolve()
    acceptance_path = Path(args.static_acceptance).resolve()
    result_directory = Path(args.static_results).resolve()
    output = Path(args.output).resolve()
    candidates = [json.loads(line) for line in source.read_text(
        encoding="utf-8").splitlines() if line.strip()]
    by_hash = {candidate["result_hash"]: candidate for candidate in candidates}
    acceptance = json.loads(acceptance_path.read_text(encoding="utf-8"))
    survivors = []
    for row in acceptance["rows"]:
        if row["candidate_state"] != "static_robustness_proxy_pass":
            continue
        artifact = json.loads((result_directory /
            f"static_{int(row['request_index'])}.json").read_text(encoding="utf-8"))
        candidate_hash = artifact["candidate_result_hash"]
        if (candidate_hash not in by_hash or
                artifact["candidate_state"] != "static_robustness_proxy_pass"):
            raise ValueError("static survivor is detached or acceptance/result mismatch")
        survivors.append(by_hash[candidate_hash])
    survivors.sort(key=lambda candidate: candidate["result_hash"])
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".partial")
    temporary.write_text("".join(json.dumps(item, sort_keys=True) + "\n"
                                 for item in survivors), encoding="utf-8")
    temporary.replace(output)
    body = {
        "schema_version": "1.0.0",
        "protocol_id": "fusionconceptai-static-survivor-selection-20260830",
        "status": "complete",
        "source_candidate_stream_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "source_static_acceptance_hash": acceptance["acceptance_hash"],
        "survivor_count": len(survivors),
        "survivor_stream_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "identity_fields_used_for_routing": False,
        "unsupported_candidate_count": 0,
        "physical_pass_credit": False,
        "validation_credit": False,
        "claim_boundary": "Only hash-bound static passes proceed; all whole-device gates rerun.",
    }
    body["acceptance_hash"] = canonical_hash(body)
    output.with_name("static_survivor_selection_acceptance.json").write_text(
        json.dumps(body, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": "complete", "survivor_count": len(survivors),
                      "acceptance_hash": body["acceptance_hash"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
