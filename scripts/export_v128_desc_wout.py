#!/usr/bin/env python3
"""Re-solve one shared-state candidate in DESC and export a hash-bound wout."""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import sys
import types
from pathlib import Path

import numpy as np

from desc_axisymmetric_stability_v99_runner import (
    FOURIER_SHA256,
    STABILITY_SHA256,
    patched_fourier,
    patched_stability,
)


def _declared_profile_parameters(candidate: dict) -> tuple[int, int]:
    declaration = candidate.get("equilibrium_profile_parameters", {})
    alpha_m = declaration.get("alpha_m", 1)
    alpha_n = declaration.get("alpha_n", 2)
    if (isinstance(alpha_m, bool) or isinstance(alpha_n, bool) or
            int(alpha_m) != alpha_m or int(alpha_n) != alpha_n):
        raise ValueError("equilibrium profile exponents must be integers")
    alpha_m, alpha_n = int(alpha_m), int(alpha_n)
    if alpha_m < 1 or alpha_n < 1 or 2 * (alpha_m * alpha_n + 1) > 12:
        raise ValueError("equilibrium profile exponents exceed the shared basis")
    return alpha_m, alpha_n


# The v99 transform module imports the FreeGS execution module even though its pure
# boundary/profile transformers do not execute FreeGS.  Supply narrow import stubs so
# this exporter remains runnable in the independent DESC environment.
_freegs_stub = types.ModuleType("freegs_shared_state_runner_v119")
_freegs_stub.solve = None
sys.modules["freegs_shared_state_runner_v119"] = _freegs_stub
_transform_stub = types.ModuleType("run_v98_freegs_candidate")
_transform_stub.declared_profile_parameters = _declared_profile_parameters
_transform_stub.transformed_input = None
sys.modules["run_v98_freegs_candidate"] = _transform_stub

from run_v99_desc_candidate import (  # noqa: E402
    canonical_hash,
    desc_payload,
    fit_axisymmetric_boundary,
)


PROTOCOL_ID = "fusionconceptai-v128-desc-wout-export-20260830"


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_axisymmetric_runtime(directory: Path):
    fourier_path = directory / "desc_fourier_runner.py"
    stability_path = directory / "desc_stellarator_stability_runner.py"
    fourier = types.ModuleType("desc_fourier_runner")
    fourier.__file__ = str(fourier_path)
    exec(compile(patched_fourier(fourier_path),
                 "desc_fourier_axisymmetric_v99_runtime", "exec"), fourier.__dict__)
    sys.modules["desc_fourier_runner"] = fourier
    stability = types.ModuleType("desc_axisymmetric_stability_v99_runtime")
    stability.__file__ = str(stability_path)
    exec(compile(patched_stability(stability_path),
                 "desc_axisymmetric_stability_v99_runtime", "exec"),
         stability.__dict__)
    return stability


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--freegs-result", required=True)
    parser.add_argument("--wout", required=True)
    parser.add_argument("--manifest", required=True)
    args = parser.parse_args()
    candidate_path = Path(args.candidate).resolve()
    freegs_path = Path(args.freegs_result).resolve()
    wout_path = Path(args.wout).resolve()
    manifest_path = Path(args.manifest).resolve()
    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    freegs = json.loads(freegs_path.read_text(encoding="utf-8"))
    if freegs["candidate_result_hash"] != candidate["result_hash"]:
        raise ValueError("candidate/FreeGS result binding mismatch")
    boundary = fit_axisymmetric_boundary(freegs)
    payload = desc_payload(candidate, freegs, boundary)
    runtime = load_axisymmetric_runtime(Path(__file__).resolve().parent)
    equilibrium, record = runtime.construct_and_solve(
        payload["equilibrium_solver_input"], np)
    if record["accepted"] is not True:
        raise RuntimeError("DESC equilibrium did not pass its declared audit")
    from desc.vmec import VMECIO

    wout_path.parent.mkdir(parents=True, exist_ok=True)
    VMECIO.save(equilibrium, str(wout_path), surfs=65, verbose=0)
    body = {
        "schema_version": "1.0.0",
        "protocol_id": PROTOCOL_ID,
        "status": "pass",
        "candidate_result_hash": candidate["result_hash"],
        "candidate_solver_input_hash": candidate["solver_input_hash"],
        "candidate_graph_hash": candidate["graph_hash"],
        "candidate_path_sha256": sha256_file(candidate_path),
        "freegs_result_hash": freegs["result_hash"],
        "freegs_path_sha256": sha256_file(freegs_path),
        "desc_solver_input_hash": canonical_hash(payload["equilibrium_solver_input"]),
        "desc_solved_volume_state_hash": record["solved_volume_state_hash"],
        "desc_equilibrium_after": record["after"],
        "boundary_transform": boundary,
        "wout_sha256": sha256_file(wout_path),
        "environment": {
            "desc_opt": importlib.metadata.version("desc-opt"),
            "jax": importlib.metadata.version("jax"),
            "jaxlib": importlib.metadata.version("jaxlib"),
            "numpy": np.__version__,
        },
        "sealed_source_hashes": {
            "desc_fourier_runner": FOURIER_SHA256,
            "desc_stability_runner": STABILITY_SHA256,
            "axisymmetric_wrapper": sha256_file(
                Path(__file__).with_name("desc_axisymmetric_stability_v99_runner.py")),
        },
        "claim_boundary": (
            "A candidate-bound DESC equilibrium was re-solved and exported in VMEC wout "
            "format. Export is a cross-code input bridge, not stability, transport, "
            "engineering, validation, or device-feasibility evidence."
        ),
    }
    body["result_hash"] = canonical_hash(body)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(body, indent=2, sort_keys=True,
                                        allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"status": "pass", "candidate_result_hash":
                      body["candidate_result_hash"], "wout_sha256":
                      body["wout_sha256"], "result_hash": body["result_hash"]},
                     sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
