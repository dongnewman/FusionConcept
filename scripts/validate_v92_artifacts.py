from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import h5py
import jsonschema

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / "runs" / "physical_closure_v92_formal_417_20260828"
SCHEMAS = ROOT / "schemas"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"),
                      parse_constant=lambda value: (_ for _ in ()).throw(
                          ValueError(f"non-finite JSON constant {value}")))


def rows(path: Path):
    with path.open("r", encoding="utf-8") as stream:
        return [json.loads(line, parse_constant=lambda value: (_ for _ in ()).throw(
            ValueError(f"non-finite JSON constant {value}")))
                for line in stream if line.strip()]


def sha256(path: Path) -> str:
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return digest


def finite(value):
    if isinstance(value, float):
        assert math.isfinite(value)
    elif isinstance(value, dict):
        for item in value.values():
            finite(item)
    elif isinstance(value, list):
        for item in value:
            finite(item)


def validate_file(schema_name: str, records: list[dict]) -> int:
    schema_path = SCHEMAS / schema_name
    schema = load(schema_path)
    jsonschema.Draft202012Validator.check_schema(schema)
    store = {}
    for path in SCHEMAS.glob("*.schema.json"):
        item = load(path)
        if "$id" in item:
            store[item["$id"]] = item
            store[item["$id"].rsplit("/", 1)[0] + "/" + path.name] = item
    resolver = jsonschema.RefResolver.from_schema(schema, store=store)
    validator = jsonschema.Draft202012Validator(schema, resolver=resolver)
    for record in records:
        validator.validate(record)
    return len(records)


def main() -> None:
    for path in SCHEMAS.glob("*v92.schema.json"):
        jsonschema.Draft202012Validator.check_schema(load(path))
    protocol_count = validate_file("protocol_seal_v92.schema.json", [load(
        ROOT / "config" / "v92" / "protocol_seal_v92.json")])
    requests = rows(RUN / "requests" / "high_fidelity_pilot" /
                    "equilibrium_requests_v92.jsonl")
    equilibrium = rows(RUN / "results" / "high_fidelity_pilot" /
                       "equilibrium_results_v92.jsonl")
    orbit = rows(RUN / "results" / "high_fidelity_pilot" /
                 "orbit_results_v92.jsonl")
    stability = rows(RUN / "results" / "high_fidelity_pilot" /
                     "stability_results_v92.jsonl")
    modes = rows(RUN / "mode_coverage_manifests_v92.jsonl")
    comparisons = rows(RUN / "cross_code_comparison_matrix_v92.jsonl")
    vvuq = rows(RUN / "validation_vvuq_dossiers_v92.jsonl")
    decisions = rows(RUN / "promotion_decisions_v92.jsonl")
    validate_file("equilibrium_request_v92.schema.json", requests)
    validate_file("equilibrium_result_v92.schema.json", equilibrium)
    validate_file("orbit_result_v92.schema.json", orbit)
    validate_file("stability_result_v92.schema.json", stability)
    validate_file("mode_coverage_manifest_v92.schema.json", modes)
    validate_file("cross_code_comparison_v92.schema.json", comparisons)
    validate_file("validation_vvuq_v92.schema.json", vvuq)
    validate_file("promotion_decision_v92.schema.json", decisions)

    realizations = rows(RUN / "realization_dossiers_v92.jsonl")
    physical_schema = load(SCHEMAS / "physical_realization_v92.schema.json")
    allowed = set(physical_schema["properties"])
    physical_core = [{key: value for key, value in row.items() if key in allowed}
                     for row in realizations]
    validate_file("physical_realization_v92.schema.json", physical_core)
    assert len(realizations) == 417
    assert len({row["candidate_hash"] for row in realizations}) == 417
    assert len({row["realization_hash"] for row in realizations}) == 417
    assert len(requests) == len(equilibrium) == len(orbit) == len(stability) == len(modes) == 229
    assert all(row["status"] == "unsupported" for row in equilibrium)
    assert all(row["status"] == "unsupported" for row in orbit)
    assert all(row["status"] == "unsupported" for row in stability)
    assert all(set(row["route"]["routing_axes"]) == {
        "declared_operators", "state_variables", "region_dimensions",
        "boundary_conditions", "interface_conditions", "field_semantics",
        "evidence_obligations", "solver_input_compatibility"} for row in requests)
    assert all(not row["route"]["family_or_device_label_used"] for row in requests)
    assert all(not row["route"]["open_field_sent_to_nested_surface_solver"] for row in requests)
    for collection in (realizations, requests, equilibrium, orbit, stability, modes):
        finite(collection)

    bundle = load(RUN / "farthest_candidate_v92" /
                  "farthest_candidate_complete_dossier_v92.json")
    mesh_count = 0
    for item in bundle["materialized_meshes"]:
        path = ROOT / item["path"]
        assert path.exists() and sha256(path) == item["sha256"]
        with h5py.File(path, "r") as handle:
            assert {"x_m", "y_m", "z_m"} <= set(handle)
            assert handle["x_m"].shape == handle["y_m"].shape == handle["z_m"].shape
            if "cell_count" in item:
                assert int(handle.attrs["cell_count"]) == item["cell_count"]
            else:
                assert int(handle.attrs["face_count"]) == item["face_count"]
        mesh_count += 1
    assert mesh_count == 6
    assert len(decisions) == 229
    assert not any(row["computationally_credible_fusion_device_concept"] for row in decisions)
    assert not any(row["experimentally_validated_new_fusion_device"] for row in decisions)
    negative_controls = load(RUN / "controls" / "negative_control_results_v92.json")
    assert negative_controls["status"] == "pass"
    assert negative_controls["control_count"] == negative_controls["control_pass_count"] == 8

    report = {
        "schema_version": "1.0.0",
        "protocol_id": "fusionconceptai-v92-hifi-closure-20260828",
        "status": "pass",
        "v92_schema_count": len(list(SCHEMAS.glob("*v92.schema.json"))),
        "protocol_records_validated": protocol_count,
        "realization_records_validated": len(realizations),
        "equilibrium_requests_validated": len(requests),
        "equilibrium_results_validated": len(equilibrium),
        "orbit_results_validated": len(orbit),
        "stability_results_validated": len(stability),
        "mode_coverage_records_validated": len(modes),
        "cross_code_records_validated": len(comparisons),
        "validation_vvuq_records_validated": len(vvuq),
        "promotion_decisions_validated": len(decisions),
        "materialized_meshes_validated": mesh_count,
        "nonfinite_json_values": 0,
        "family_or_device_label_routes": 0,
        "open_to_nested_surface_misroutes": 0,
        "computationally_credible_new_device_count": 0,
        "experimentally_validated_new_fusion_device_count": 0,
        "negative_control_count": 8,
        "negative_control_pass_count": 8,
    }
    report["report_hash"] = hashlib.sha256(json.dumps(
        report, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    output = ROOT / "reports" / "v92_artifact_validation_20260828.json"
    content = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if output.exists() and output.read_text(encoding="utf-8") != content:
        raise RuntimeError(f"immutable validation report differs: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(content, encoding="utf-8")
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
