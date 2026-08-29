#!/usr/bin/env python3
"""Validate v100 evidence hashes, bindings, censuses, and non-promotion rules."""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "runs" / "v100_candidate_bound_design_refinement_20260829"
FRONT = ROOT / "runs" / "v100_candidate_bound_design_refinement_expanded_20260829"
FINAL = ROOT / "runs" / "v100_full_device_qualification_20260829" / "acceptance.json"


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def read_stream(path: Path) -> dict[int, dict]:
    return {int(item["request_index"]): item for item in
            (json.loads(line) for line in path.read_text(
                encoding="utf-8").splitlines() if line.strip())}


def verify_hash(artifact: dict, field: str, context: str) -> None:
    expected = artifact[field]
    body = {key: value for key, value in artifact.items() if key != field}
    if canonical_hash(body) != expected:
        raise ValueError(f"{context} {field} mismatch")


def verify_julia_hash(path: Path, field: str, context: str) -> None:
    code = (
        "using FusionConceptAI,JSON3; "
        "x=FusionConceptAI._v93_plain(JSON3.read(read(ARGS[1],String))); "
        f"h=pop!(x,\"{field}\"); "
        "h==FusionConceptAI.canonical_hash(x) || error(\"hash mismatch\")"
    )
    process = subprocess.run(
        ["julia", f"--project={ROOT}", "-e", code, str(path)],
        capture_output=True, text=True, check=False)
    if process.returncode != 0:
        raise ValueError(f"{context} {field} mismatch: {process.stderr[-1000:]}")


def verify_campaign(candidate_stream: Path, freegs_dir: Path,
                    desc_dir: Path, static_dir: Path) -> tuple[dict[int, dict], set[int]]:
    candidates = read_stream(candidate_stream)
    freegs_acceptance = read_json(freegs_dir / "acceptance.json")
    desc_acceptance = read_json(desc_dir / "acceptance.json")
    static_acceptance = read_json(static_dir / "acceptance.json")
    for name, acceptance in (("FreeGS", freegs_acceptance),
                             ("DESC", desc_acceptance),
                             ("static", static_acceptance)):
        verify_hash(acceptance, "acceptance_hash", name)
        if acceptance["status"] != "complete":
            raise ValueError(f"{name} acceptance is not complete")
        if int(acceptance.get("provider_system_failure_count", 0)) != 0:
            raise ValueError(f"{name} retains provider system failures")
        if int(acceptance.get("unsupported_candidate_count", 0)) != 0:
            raise ValueError(f"{name} retains unsupported candidates")
    freegs_pass = set()
    freegs_hashes = {}
    for row in freegs_acceptance["rows"]:
        request_index = int(row["request_index"])
        candidate = candidates[request_index]
        artifact = read_json(freegs_dir / "results" / f"freegs_{request_index}.json")
        verify_hash(artifact, "result_hash", f"FreeGS {request_index}")
        if artifact["candidate_result_hash"] != candidate["result_hash"]:
            raise ValueError(f"FreeGS candidate binding mismatch for {request_index}")
        if (artifact["status"], artifact["result_hash"]) != (
                row["status"], row["result_hash"]):
            raise ValueError(f"FreeGS acceptance row mismatch for {request_index}")
        freegs_hashes[request_index] = artifact["result_hash"]
        if artifact["status"] == "pass":
            if artifact["numerical_vvuq"]["status"] != "pass":
                raise ValueError(f"FreeGS pass lacks numerical VVUQ for {request_index}")
            freegs_pass.add(request_index)
    desc_survivors = set()
    for row in desc_acceptance["rows"]:
        request_index = int(row["request_index"])
        if request_index not in freegs_pass:
            raise ValueError(f"DESC contains a non-FreeGS survivor {request_index}")
        artifact = read_json(desc_dir / "results" / f"v99_{request_index:07d}.json")
        verify_hash(artifact, "result_hash", f"DESC {request_index}")
        if artifact["candidate_result_hash"] != candidates[request_index]["result_hash"]:
            raise ValueError(f"DESC candidate binding mismatch for {request_index}")
        if artifact["freegs_verification_hash"] != freegs_hashes[request_index]:
            raise ValueError(f"DESC FreeGS binding mismatch for {request_index}")
        if (artifact["candidate_state"], artifact["result_hash"]) != (
                row["candidate_state"], row["result_hash"]):
            raise ValueError(f"DESC acceptance row mismatch for {request_index}")
        if artifact["candidate_state"] == "sampled_ideal_mhd_candidate":
            desc_survivors.add(request_index)
    static_seen = set()
    for row in static_acceptance["rows"]:
        request_index = int(row["request_index"])
        artifact = read_json(static_dir / "results" / f"static_{request_index}.json")
        verify_hash(artifact, "result_hash", f"static {request_index}")
        if request_index not in desc_survivors:
            raise ValueError(f"static result contains non-MHD survivor {request_index}")
        if artifact["candidate_result_hash"] != candidates[request_index]["result_hash"]:
            raise ValueError(f"static candidate binding mismatch for {request_index}")
        if (artifact["candidate_state"], artifact["result_hash"]) != (
                row["candidate_state"], row["result_hash"]):
            raise ValueError(f"static acceptance row mismatch for {request_index}")
        static_seen.add(request_index)
    if static_seen != desc_survivors:
        raise ValueError("not every sampled ideal-MHD candidate received static qualification")
    return candidates, freegs_pass


def main() -> int:
    main_candidates, main_freegs = verify_campaign(
        MAIN / "computational_candidates.jsonl",
        MAIN / "freegs_shared_radial_build", MAIN / "desc_cross_code",
        MAIN / "static_robustness")
    front_candidates, front_freegs = verify_campaign(
        FRONT / "low_beta_frontier_30.jsonl",
        FRONT / "freegs_low_beta_frontier", FRONT / "desc_low_beta_frontier",
        FRONT / "static_robustness")
    final = read_json(FINAL)
    verify_hash(final, "acceptance_hash", "final v100")
    union = set(main_candidates) | set(front_candidates)
    if len(union) != final["unique_design_candidate_count"] or len(union) != 79:
        raise ValueError("final unique candidate census mismatch")
    if (len(main_freegs | front_freegs) !=
            final["freegs_numerical_vvuq_pass_count"] or
            len(main_freegs | front_freegs) != 73):
        raise ValueError("final FreeGS pass census mismatch")
    expected = {
        "sampled_local_ideal_mhd_candidate_count": 4,
        "static_engineering_proxy_pass_count": 1,
        "provider_system_failure_count": 0,
        "unsupported_candidate_count": 0,
        "whole_device_credible_count": 0,
        "validation_pass_count": 0,
        "reference_control_count": 2,
        "reference_validation_credit_count": 0,
    }
    for key, value in expected.items():
        if final[key] != value:
            raise ValueError(f"final {key} mismatch")
    incomplete = [row for row in final["rows"]
                  if row["candidate_state"] == "qualification_incomplete"]
    if len(incomplete) != 1 or int(incomplete[0]["request_index"]) != 609214000287:
        raise ValueError("qualification-incomplete survivor mismatch")
    if any(row["whole_device_credible"] or row["validation_pass"] or
           row["unsupported_candidate_classification_used"] for row in final["rows"]):
        raise ValueError("final rows contain forbidden promotion or unsupported state")
    reference = read_json(MAIN / "reference_controls.json")
    verify_julia_hash(MAIN / "reference_controls.json", "acceptance_hash",
                      "reference controls")
    if reference["status"] != "pass" or reference["reference_control_count"] != 2 or \
            reference["validation_pass_count"] != 0 or \
            reference["whole_device_candidate_credit"] is not False:
        raise ValueError("ITER/C-2W reference control boundary mismatch")
    print(json.dumps({
        "status": "pass", "unique_candidates": len(union),
        "freegs_pass": len(main_freegs | front_freegs),
        "qualification_incomplete": 1, "credible": 0, "validation_pass": 0,
        "acceptance_hash": final["acceptance_hash"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
