from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import h5py
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / "runs" / "physical_closure_v92_formal_417_20260828"
OUT = RUN / "farthest_candidate_v92"


def rows(path: Path) -> list[dict]:
    with path.open("r", encoding="utf-8") as stream:
        return [json.loads(line) for line in stream if line.strip()]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json_immutable(path: Path, value: object) -> None:
    content = json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False) + "\n"
    if path.exists():
        if path.read_text(encoding="utf-8") != content:
            raise RuntimeError(f"immutable artifact differs: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(content, encoding="utf-8")
    temporary.replace(path)


def materialize_volume(path: Path, shape: list[int], scales: dict) -> None:
    if path.exists():
        return
    nr, nt, np_ = (int(value) for value in shape)
    rho = np.linspace(0.0, float(scales["minor_radius_m"]), nr + 1,
                      dtype=np.float32)[:, None, None]
    theta = np.linspace(0.0, 2.0 * math.pi, nt + 1,
                        dtype=np.float32)[None, :, None]
    phi = np.linspace(0.0, 2.0 * math.pi, np_ + 1,
                      dtype=np.float32)[None, None, :]
    major = float(scales["major_radius_m"])
    elongation = float(scales["elongation"])
    triangularity = float(scales["triangularity"])
    nfp = int(scales["field_periods"])
    helical_r = 0.06 * float(scales["minor_radius_m"])
    helical_z = 0.04 * float(scales["minor_radius_m"])
    shaped_theta = theta + triangularity * np.sin(theta)
    radial = major + rho * np.cos(shaped_theta) + helical_r * np.cos(nfp * phi)
    z = rho * elongation * np.sin(theta) + helical_z * np.sin(nfp * phi)
    x = radial * np.cos(phi)
    y = radial * np.sin(phi)
    x = np.broadcast_to(x, (nr + 1, nt + 1, np_ + 1)).astype(np.float32)
    y = np.broadcast_to(y, (nr + 1, nt + 1, np_ + 1)).astype(np.float32)
    z = np.broadcast_to(z, (nr + 1, nt + 1, np_ + 1)).astype(np.float32)
    temporary = path.with_suffix(path.suffix + ".tmp")
    with h5py.File(temporary, "w") as handle:
        handle.attrs["mesh_type"] = "structured_curvilinear_hexahedral_v92"
        handle.attrs["cell_shape"] = shape
        handle.attrs["cell_count"] = nr * nt * np_
        handle.attrs["connectivity"] = "implicit_i_j_k_hexahedral"
        handle.attrs["coordinate_unit"] = "m"
        handle.create_dataset("x_m", data=x, compression="gzip", compression_opts=4,
                              shuffle=True, chunks=True)
        handle.create_dataset("y_m", data=y, compression="gzip", compression_opts=4,
                              shuffle=True, chunks=True)
        handle.create_dataset("z_m", data=z, compression="gzip", compression_opts=4,
                              shuffle=True, chunks=True)
    temporary.replace(path)


def materialize_wall(path: Path, shape: list[int], scales: dict) -> None:
    if path.exists():
        return
    nu, nv = (int(value) for value in shape)
    theta = np.linspace(0.0, 2.0 * math.pi, nu + 1,
                        dtype=np.float32)[:, None]
    phi = np.linspace(0.0, 2.0 * math.pi, nv + 1,
                      dtype=np.float32)[None, :]
    major = float(scales["major_radius_m"])
    minor = 1.40 * float(scales["minor_radius_m"])
    elongation = float(scales["elongation"])
    triangularity = float(scales["triangularity"])
    nfp = int(scales["field_periods"])
    shaped_theta = theta + triangularity * np.sin(theta)
    radial = major + minor * np.cos(shaped_theta) + 0.06 * minor * np.cos(nfp * phi)
    x = (radial * np.cos(phi)).astype(np.float32)
    y = (radial * np.sin(phi)).astype(np.float32)
    z = np.broadcast_to(minor * elongation * np.sin(theta) +
                        0.04 * minor * np.sin(nfp * phi), x.shape).astype(np.float32)
    temporary = path.with_suffix(path.suffix + ".tmp")
    with h5py.File(temporary, "w") as handle:
        handle.attrs["mesh_type"] = "structured_periodic_quadrilateral_wall_v92"
        handle.attrs["face_shape"] = shape
        handle.attrs["face_count"] = nu * nv
        handle.attrs["connectivity"] = "implicit_u_v_quadrilateral"
        handle.attrs["orientation"] = "vacuum_to_wall"
        handle.create_dataset("x_m", data=x, compression="gzip", compression_opts=4,
                              shuffle=True, chunks=True)
        handle.create_dataset("y_m", data=y, compression="gzip", compression_opts=4,
                              shuffle=True, chunks=True)
        handle.create_dataset("z_m", data=z, compression="gzip", compression_opts=4,
                              shuffle=True, chunks=True)
    temporary.replace(path)


def main() -> None:
    realizations = {row["candidate_hash"]: row for row in rows(
        RUN / "realization_dossiers_v92.jsonl")}
    decisions = rows(RUN / "promotion_decisions_v92.jsonl")
    decisions.sort(key=lambda row: row["candidate_hash"])
    decision = decisions[0]
    candidate_hash = decision["candidate_hash"]
    realization = realizations[candidate_hash]
    candidate_id = realization["candidate_id"]
    keyed_files = {
        "equilibrium_request": RUN / "requests" / "high_fidelity_pilot" / "equilibrium_requests_v92.jsonl",
        "equilibrium_result": RUN / "results" / "high_fidelity_pilot" / "equilibrium_results_v92.jsonl",
        "orbit_result": RUN / "results" / "high_fidelity_pilot" / "orbit_results_v92.jsonl",
        "stability_result": RUN / "results" / "high_fidelity_pilot" / "stability_results_v92.jsonl",
        "mode_coverage": RUN / "mode_coverage_manifests_v92.jsonl",
        "cross_code": RUN / "cross_code_comparison_matrix_v92.jsonl",
        "vvuq": RUN / "validation_vvuq_dossiers_v92.jsonl",
    }
    evidence = {}
    for key, path in keyed_files.items():
        matches = [row for row in rows(path) if row["candidate_id"] == candidate_id]
        if len(matches) != 1:
            raise RuntimeError(f"expected one {key} row for {candidate_id}")
        evidence[key] = matches[0]

    OUT.mkdir(parents=True, exist_ok=True)
    mesh_files = []
    scales = realization["scales"]
    for mesh in realization["volume_meshes"]:
        path = OUT / f"volume_mesh_{mesh['level']}_v92.h5"
        materialize_volume(path, mesh["cell_shape"], scales)
        mesh_files.append({"role": f"volume_mesh_{mesh['level']}",
                           "path": path.relative_to(ROOT).as_posix(),
                           "sha256": sha256(path), "bytes": path.stat().st_size,
                           "cell_count": mesh["cell_count"]})
    for mesh in realization["wall_meshes"]:
        path = OUT / f"wall_mesh_{mesh['level']}_v92.h5"
        materialize_wall(path, mesh["face_shape"], scales)
        mesh_files.append({"role": f"wall_mesh_{mesh['level']}",
                           "path": path.relative_to(ROOT).as_posix(),
                           "sha256": sha256(path), "bytes": path.stat().st_size,
                           "face_count": mesh["face_count"]})

    bundle = {
        "schema_version": "1.0.0",
        "protocol_id": "fusionconceptai-v92-hifi-closure-20260828",
        "selection_rule": "minimum canonical candidate hash among pilot candidates reaching the maximum stage",
        "candidate_id": candidate_id,
        "candidate_hash": candidate_hash,
        "GeometryIR": realization,
        "materialized_meshes": mesh_files,
        "field_sources": realization["field_sources"],
        "profiles": realization["profiles"],
        "solver_inputs": evidence["equilibrium_request"],
        "equilibrium": evidence["equilibrium_result"],
        "residuals": evidence["equilibrium_result"]["residuals"],
        "convergence": None,
        "orbits": evidence["orbit_result"],
        "modes": {"coverage": evidence["mode_coverage"],
                  "results": evidence["stability_result"]},
        "cross_code_comparison": evidence["cross_code"],
        "VVUQ_and_validation": evidence["vvuq"],
        "promotion_decision": decision,
        "claim_boundary": "Materialized meshes are candidate-bound inputs. Equilibrium fields, residuals, convergence, orbits, and modes remain unavailable because the compatible equilibrium hard gate is unsupported; null values are not replaced by synthetic evidence.",
    }
    bundle_without_hash = json.dumps(bundle, sort_keys=True, separators=(",", ":"),
                                     ensure_ascii=False).encode("utf-8")
    bundle["bundle_hash"] = hashlib.sha256(bundle_without_hash).hexdigest()
    write_json_immutable(OUT / "farthest_candidate_complete_dossier_v92.json", bundle)
    print(json.dumps({"candidate_id": candidate_id, "candidate_hash": candidate_hash,
                      "mesh_count": len(mesh_files),
                      "mesh_bytes": sum(item["bytes"] for item in mesh_files),
                      "bundle_hash": bundle["bundle_hash"]}, sort_keys=True))


if __name__ == "__main__":
    main()
