#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def canonical_hash(root: Path, path: Path) -> str:
    code = (
        "using FusionConceptAI,JSON3; "
        "d=FusionConceptAI._v93_plain(JSON3.read(read(ARGS[1],String),Dict{String,Any})); "
        "pop!(d,\"acceptance_hash\",nothing); print(canonical_hash(d))"
    )
    result = subprocess.run(["julia", f"--project={root}", "-e", code, str(path)],
                            check=True, capture_output=True, text=True)
    return result.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", required=True)
    args = parser.parse_args()
    root = Path(args.project_root).resolve()
    path = root / "runs" / "v116_multiregion_conservation_20260830" / "acceptance.json"
    body = json.loads(path.read_text(encoding="utf-8"))
    stored = body.pop("acceptance_hash")
    assert stored == canonical_hash(root, path)
    assert body["status"] == "complete"
    assert body["reference_regression_pass_count"] == 2
    assert body["reference_bypass_count"] == 0
    assert body["selected_source_candidate_count"] == 6
    assert body["transport_pass_count"] == 6
    assert body["exhaust_pass_count"] == 5
    assert body["conservation_provider_survivor_count"] == 5
    assert body["conservation_provider_reject_count"] == 1
    assert body["unsupported_candidate_count"] == 0
    assert body["provider_system_failure_count"] == 0
    assert body["whole_device_credible_count"] == 0
    assert body["validation_pass_count"] == 0
    assert body["post_v116_preflight_status"] == "not_ready"
    assert body["post_v116_closed_obligation_count"] == 2
    assert body["partial_subgraph_promotion_allowed"] is False
    stream = path.parent / "provider_results.jsonl"
    assert hashlib.sha256(stream.read_bytes()).hexdigest() == \
        body["provider_result_stream_sha256"]
    detailed = [json.loads(line) for line in stream.read_text(encoding="utf-8").splitlines()
                if line.strip()]
    assert len(detailed) == body["provider_result_stream_row_count"] == 6
    failed = [row for row in detailed if
              row["candidate_state"] == "conservation_provider_reject"]
    assert len(failed) == 1
    assert failed[0]["exhaust"]["failed_gates"] == ["collisional_flux_limiter"]
    for row in detailed:
        assert row["transport"]["unsupported_candidate_classification_used"] is False
        if row["exhaust"]["status"] in {"pass", "fail"}:
            assert row["exhaust"]["unsupported_candidate_classification_used"] is False
    print(json.dumps({"status": "pass", "acceptance_hash": stored,
                      "conservation_provider_survivor_count": 5,
                      "whole_device_credible_count": 0}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
