#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def julia_canonical_hash(root: Path, path: Path) -> str:
    code = (
        "using FusionConceptAI,JSON3; "
        "d=FusionConceptAI._v93_plain(JSON3.read(read(ARGS[1],String),Dict{String,Any})); "
        "pop!(d,\"acceptance_hash\",nothing); print(canonical_hash(d))"
    )
    process = subprocess.run(
        ["julia", f"--project={root}", "-e", code, str(path)], check=True,
        capture_output=True, text=True)
    return process.stdout.strip()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rows(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()
            if line.strip()]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", required=True)
    args = parser.parse_args()
    root = Path(args.project_root).resolve()
    directory = root / "runs" / "v115_corrected_whole_device_rescreen_20260830"
    path = directory / "acceptance.json"
    body = json.loads(path.read_text(encoding="utf-8"))
    stored = body.pop("acceptance_hash")
    assert stored == julia_canonical_hash(root, path)
    assert body["status"] == "complete"
    assert body["reference_regression_pass_count"] == 2
    assert body["reference_bypass_count"] == 0
    assert body["source_v114_candidate_count"] == 9
    assert body["assembly_count"] == 216
    assert set(body["source_v114_acceptance_hashes"]) == {
        "generation", "freegs", "desc", "static"}
    assert all(len(value) == 64 for value in body["source_v114_acceptance_hashes"].values())
    assert body["actual_static_screen_survivor_count"] == 200
    assert body["available_provider_dag_pass_count"] == 200
    assert body["dynamic_fault_screen_survivor_count"] == 600
    assert body["material_screen_survivor_count"] == 384
    assert body["unique_material_survivor_assembly_count"] == 128
    assert body["unique_material_survivor_candidate_count"] == 6
    assert body["material_screen_reject_count"] == 216
    assert body["actual_static_screen_blocker_histogram"] == {
        "net_electric_power": 16}
    assert body["dynamic_fault_blocker_histogram"] == {
        "single_pf_coil_trip": 200, "vertical_displacement_event": 200}
    assert body["material_blocker_histogram"] == {"rebco_peak_field": 216}
    assert body["unsupported_candidate_count"] == 0
    assert body["provider_system_failure_count"] == 0
    assert body["whole_device_pass_count"] == 0
    assert body["whole_device_credible_count"] == 0
    assert body["validation_pass_count"] == 0
    assert body["partial_subgraph_promotion_allowed"] is False
    for name, expected in body["stream_row_counts"].items():
        stream = directory / f"{name}.jsonl"
        assert sha256(stream) == body["stream_hashes"][f"{name}_sha256"]
        assert len(rows(stream)) == expected
    assemblies = rows(directory / "assemblies.jsonl")
    assert sorted({a["physical_design"]["thermal_cycle"][
        "declared_coolant_delta_t_k"] for a in assemblies}) == [90.0, 110.0, 120.0]
    screens = rows(directory / "screens.jsonl")
    assert all("actual_static_extrema" in row for row in screens)
    assert body["material_screen_survivor_count"] > 0
    assert body["unique_material_survivor_assembly_count"] > 0
    assert body["unique_material_survivor_candidate_count"] > 0
    assert body["material_screen_survivor_count"] >= \
        body["unique_material_survivor_assembly_count"]
    assert body["complete_provider_preflight_count"] == 0
    print(json.dumps({"status": "pass", "acceptance_hash": stored,
                      "material_screen_survivor_count":
                          body["material_screen_survivor_count"],
                      "whole_device_credible_count": 0}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
