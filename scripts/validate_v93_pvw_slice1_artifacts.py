from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / "runs" / "v93_pvw_slice1_formal_246_20260828"
PROTOCOL = "fusionconceptai-v93-pvw-slice1-20260828"


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_jsonl(path: Path):
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    declarations = load_jsonl(RUN / "declarations" / "complete_declarations_v93.jsonl")
    routes = load_jsonl(RUN / "routes" / "pvw_slice_routes_v1.jsonl")
    results = load_jsonl(RUN / "results" / "pvw_slice_results_v1.jsonl")
    gaps = load_jsonl(RUN / "per_candidate_gap_inventory_v93.jsonl")
    census = load_json(RUN / "field_operator_gap_census_v93.json")
    manufactured = load_json(RUN / "controls" / "pvw_manufactured_verification_v1.json")
    acceptance = load_json(RUN / "acceptance_v93_pvw_slice1.json")
    manifest = load_json(RUN / "artifact_hash_manifest_v93_pvw_slice1.json")

    assert len(declarations) == len(routes) == len(results) == len(gaps) == 246
    assert all(item["protocol_id"] == PROTOCOL for item in declarations + results)
    assert all(item["declaration_completeness"]["schema_complete"] for item in declarations)
    assert all(not item["declaration_completeness"]["solver_complete"] for item in declarations)
    assert all({region["region_type"] for region in item["regions"]} ==
               {"plasma", "vacuum", "coil", "wall", "open_loss", "terminal"}
               for item in declarations)
    assert all(route["status"] == "unsupported_operator_or_backend" for route in routes)
    assert all(result["status"] == "unsupported_operator_or_backend" for result in results)
    assert all(not result["solver_executed"] for result in results)
    assert all(result["numerical_vvuq_status"] == "not_executed" for result in results)
    assert all(result["validation_vvuq_status"] == "not_executed" for result in results)
    assert census["candidate_count"] == 246
    assert census["schema_complete_declaration_count"] == 246
    assert census["solver_complete_declaration_count"] == 0
    assert census["slice_eligible_count"] == 0
    assert manufactured["status"] == "pass"
    assert manufactured["candidate_equilibrium_credit"] is False
    assert 1.9 < manufactured["observed_order_medium_fine"] < 2.1
    assert manufactured["gci_fine_percent"] < 2.0
    assert acceptance["complete_declaration_count"] == 246
    assert acceptance["slice_eligible_count"] == 0
    assert acceptance["candidate_solver_execution_count"] == 0
    assert acceptance["candidate_numerical_vvuq_count"] == 0
    assert acceptance["candidate_validation_vvuq_count"] == 0
    assert acceptance["subproblem_projection_used"] is False
    assert len(acceptance["acceptance_hash"]) == 64
    assert manifest["artifact_count"] == len(manifest["artifacts"])
    for artifact in manifest["artifacts"]:
        path = RUN.joinpath(*artifact["path"].split("/"))
        assert path.stat().st_size == artifact["bytes"]
        assert sha256(path) == artifact["sha256"]
    print(json.dumps({
        "status": "pass",
        "declarations": len(declarations),
        "eligible": acceptance["slice_eligible_count"],
        "candidate_solver_executions": acceptance["candidate_solver_execution_count"],
        "artifact_count": manifest["artifact_count"],
        "acceptance_hash": acceptance["acceptance_hash"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
