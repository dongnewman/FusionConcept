from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / "runs" / "multiregion_equilibrium_v93_formal_20260828"
PROTOCOL = "fusionconceptai-v93-family-neutral-multiregion-20260828"
STATUSES = {
    "fail_physical_model",
    "fail_invalid_geometry",
    "fail_boundary_or_interface_inconsistency",
    "fail_no_equilibrium_under_declared_model",
    "fail_numerical_convergence",
    "unknown_multiple_equilibrium_branches",
    "unknown_solver_disagreement",
    "unknown_validation_domain",
    "unsupported_operator_or_backend",
    "pass",
}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_jsonl(path: Path):
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    requests = load_jsonl(RUN / "requests" / "pilot_requests_v93.jsonl")
    results = load_jsonl(RUN / "results" / "pilot_results_v93.jsonl")
    dossiers = load_jsonl(RUN / "pilot_dossiers_v93.jsonl")
    acceptance = load_json(RUN / "multiregion_acceptance_v93.json")
    manifest = load_json(RUN / "artifact_hash_manifest_v93.json")
    assert len(requests) == len(results) == len(dossiers) == 229
    assert all(item["protocol_id"] == PROTOCOL for item in requests + results)
    assert all(item["compilation_status"] in STATUSES for item in requests)
    assert all(item["status"] in STATUSES for item in results)
    assert all(len(item["problem_hash"]) == len(item["route_hash"]) == len(item["request_hash"]) == 64 for item in requests)
    assert all(not item["solver_executed"] for item in results)
    assert all(item["status"] == "unsupported_operator_or_backend" for item in results)
    assert [item["request_hash"] for item in requests] == [item["request_hash"] for item in results]
    assert acceptance["pilot_count"] == 229
    assert acceptance["pilot_status_histogram"] == {"unsupported_operator_or_backend": 229}
    assert acceptance["pilot_to_full_transition_allowed"] is False
    assert acceptance["full_campaign_executed"] is False
    assert acceptance["computationally_credible_new_device_count"] == 0
    assert acceptance["experimentally_validated_new_fusion_device_count"] == 0
    assert len(acceptance["acceptance_hash"]) == 64
    assert manifest["artifact_count"] == len(manifest["artifacts"])
    for artifact in manifest["artifacts"]:
        path = RUN.joinpath(*artifact["path"].split("/"))
        assert path.stat().st_size == artifact["bytes"]
        assert sha256(path) == artifact["sha256"]
    print(json.dumps({
        "status": "pass",
        "request_count": len(requests),
        "result_count": len(results),
        "artifact_count": manifest["artifact_count"],
        "acceptance_hash": acceptance["acceptance_hash"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
