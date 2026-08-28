#!/usr/bin/env python3
"""Hash-pinned v99 axisymmetric extension of the sealed DESC v2 runners."""

from __future__ import annotations

import hashlib
import sys
import types
from pathlib import Path


FOURIER_SHA256 = "9e0130c1968ba0a99c6a4c0e956b1dd453d3b690787ab4d5b1a71a9a9b79f252"
STABILITY_SHA256 = "274d91f3105244968ccb4700c6ce54ee582b44128f6e6d241dfbb3c0e37add67"


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if source.count(old) != 1:
        raise RuntimeError(f"v99 source patch {label} expected exactly one match")
    return source.replace(old, new)


def load_pinned(path: Path, expected: str) -> str:
    raw = path.read_bytes()
    actual = hashlib.sha256(raw).hexdigest()
    if actual != expected:
        raise RuntimeError(f"sealed base runner hash mismatch for {path.name}: {actual}")
    return raw.decode("utf-8")


def patched_fourier(path: Path) -> str:
    source = load_pinned(path, FOURIER_SHA256)
    source = replace_once(source,
        'MODEL_ID = "stellarator_symmetric_fourier_fixed_boundary_v1"',
        'MODEL_ID = "stellarator_symmetric_fourier_fixed_boundary_v1"\n'
        'AXISYMMETRIC_MODEL_ID = "axisymmetric_fourier_fixed_boundary_v99"',
        "axisymmetric model constant")
    source = replace_once(source,
        'def parse_modes(items, label: str) -> tuple[list[float], list[list[int]]]:',
        'def parse_modes(items, label: str,\n'
        '                maximum_mode: int = 6) -> tuple[list[float], list[list[int]]]:',
        "mode signature")
    source = replace_once(source,
        '        if abs(m) > 6 or abs(n) > 6:\n'
        '            raise ValueError(f"{label}[{index}] mode is outside |m|,|n|<=6")',
        '        if abs(m) > maximum_mode or abs(n) > maximum_mode:\n'
        '            raise ValueError(\n'
        '                f"{label}[{index}] mode is outside |m|,|n|<={maximum_mode}"\n'
        '            )', "mode bound")
    source = replace_once(source,
        '    if require(payload, "model_id") != MODEL_ID:\n'
        '        raise ValueError("model_id mismatch")',
        '    model_id = require(payload, "model_id")\n'
        '    if model_id not in (MODEL_ID, AXISYMMETRIC_MODEL_ID):\n'
        '        raise ValueError("model_id mismatch")', "model dispatch")
    source = replace_once(source,
        '    if not (2 <= nfp <= 8):\n'
        '        raise ValueError("field_periods must be in 2..8")',
        '    if model_id == AXISYMMETRIC_MODEL_ID:\n'
        '        if nfp != 1:\n'
        '            raise ValueError("axisymmetric v99 model requires field_periods=1")\n'
        '    elif not (2 <= nfp <= 8):\n'
        '        raise ValueError("stellarator model field_periods must be in 2..8")',
        "field periods")
    source = replace_once(source,
        '    r_coefficients, r_modes = parse_modes(require(boundary, "R_modes"), "R_modes")\n'
        '    z_coefficients, z_modes = parse_modes(require(boundary, "Z_modes"), "Z_modes")',
        '    maximum_boundary_mode = 24 if model_id == AXISYMMETRIC_MODEL_ID else 6\n'
        '    r_coefficients, r_modes = parse_modes(\n'
        '        require(boundary, "R_modes"), "R_modes", maximum_boundary_mode)\n'
        '    z_coefficients, z_modes = parse_modes(\n'
        '        require(boundary, "Z_modes"), "Z_modes", maximum_boundary_mode)\n'
        '    if model_id == AXISYMMETRIC_MODEL_ID and any(\n'
        '        mode[1] != 0 for mode in r_modes + z_modes\n'
        '    ):\n'
        '        raise ValueError("axisymmetric v99 boundary requires n=0 for every mode")',
        "boundary modes")
    source = replace_once(source,
        '    if not (1.0e-4 <= toroidal_flux <= 100.0):\n'
        '        raise ValueError("toroidal_flux_wb is outside 1e-4..100 Wb")',
        '    maximum_flux = 500.0 if model_id == AXISYMMETRIC_MODEL_ID else 100.0\n'
        '    if not (1.0e-4 <= toroidal_flux <= maximum_flux):\n'
        '        raise ValueError(\n'
        '            f"toroidal_flux_wb is outside 1e-4..{maximum_flux:g} Wb"\n'
        '        )', "flux bound")
    source = replace_once(source,
        '    if not (2 <= spectral_l <= 12 and 2 <= spectral_m <= 12 and 1 <= spectral_n <= 12):\n'
        '        raise ValueError("spectral resolution is outside audited bounds")',
        '    maximum_spectral_m = 24 if model_id == AXISYMMETRIC_MODEL_ID else 12\n'
        '    maximum_grid_m = 48 if model_id == AXISYMMETRIC_MODEL_ID else 24\n'
        '    if not (2 <= spectral_l <= 12 and 2 <= spectral_m <= maximum_spectral_m and 1 <= spectral_n <= 12):\n'
        '        raise ValueError("spectral resolution is outside audited bounds")',
        "spectral bound")
    source = replace_once(source,
        '        and spectral_m <= grid_m <= 24\n',
        '        and spectral_m <= grid_m <= maximum_grid_m\n', "grid bound")
    source = replace_once(source,
        '        raise ValueError("grid resolution must cover the spectral resolution and stay <=24")',
        '        raise ValueError("grid resolution must cover the spectral resolution and stay in audited bounds")',
        "grid message")
    return source


def patched_stability(path: Path) -> str:
    source = load_pinned(path, STABILITY_SHA256)
    source = replace_once(source,
        'from desc_fourier_runner import (  # noqa: E402\n    MODEL_ID,',
        'from desc_fourier_runner import (  # noqa: E402\n'
        '    AXISYMMETRIC_MODEL_ID,\n    MODEL_ID,', "axisymmetric import")
    source = replace_once(source,
        '    if require(solver_input, "model_id") != MODEL_ID:\n'
        '        raise ValueError("embedded equilibrium model_id mismatch")',
        '    model_id = require(solver_input, "model_id")\n'
        '    if model_id not in (MODEL_ID, AXISYMMETRIC_MODEL_ID):\n'
        '        raise ValueError("embedded equilibrium model_id mismatch")',
        "model dispatch")
    source = replace_once(source,
        '    if not (2 <= nfp <= 8) or require(boundary, "stellarator_symmetric") is not True:\n'
        '        raise ValueError("stability runner requires a 2..8-period stellarator-symmetric boundary")',
        '    if require(boundary, "stellarator_symmetric") is not True:\n'
        '        raise ValueError("stability runner requires a symmetric Fourier boundary")\n'
        '    if model_id == AXISYMMETRIC_MODEL_ID:\n'
        '        if nfp != 1:\n'
        '            raise ValueError("axisymmetric v99 model requires field_periods=1")\n'
        '    elif not (2 <= nfp <= 8):\n'
        '        raise ValueError("stellarator model requires field_periods in 2..8")',
        "field periods")
    source = replace_once(source,
        '    r_coefficients, r_modes = parse_modes(require(boundary, "R_modes"), "R_modes")\n'
        '    z_coefficients, z_modes = parse_modes(require(boundary, "Z_modes"), "Z_modes")',
        '    maximum_boundary_mode = 24 if model_id == AXISYMMETRIC_MODEL_ID else 6\n'
        '    r_coefficients, r_modes = parse_modes(\n'
        '        require(boundary, "R_modes"), "R_modes", maximum_boundary_mode)\n'
        '    z_coefficients, z_modes = parse_modes(\n'
        '        require(boundary, "Z_modes"), "Z_modes", maximum_boundary_mode)\n'
        '    if model_id == AXISYMMETRIC_MODEL_ID and any(\n'
        '        mode[1] != 0 for mode in r_modes + z_modes\n'
        '    ):\n'
        '        raise ValueError("axisymmetric v99 boundary requires n=0 for every mode")',
        "boundary modes")
    source = replace_once(source,
        '    if not (1.0e-4 <= toroidal_flux <= 100.0):\n'
        '        raise ValueError("toroidal flux is outside the audited range")',
        '    maximum_flux = 500.0 if model_id == AXISYMMETRIC_MODEL_ID else 100.0\n'
        '    if not (1.0e-4 <= toroidal_flux <= maximum_flux):\n'
        '        raise ValueError("toroidal flux is outside the audited range")',
        "flux bound")
    source = replace_once(source,
        '    if not (2 <= spectral_l <= 12 and 2 <= spectral_m <= 12 and 1 <= spectral_n <= 12):\n'
        '        raise ValueError("spectral resolution is outside audited bounds")',
        '    maximum_spectral_m = 24 if model_id == AXISYMMETRIC_MODEL_ID else 12\n'
        '    maximum_grid_m = 48 if model_id == AXISYMMETRIC_MODEL_ID else 24\n'
        '    if not (2 <= spectral_l <= 12 and 2 <= spectral_m <= maximum_spectral_m and 1 <= spectral_n <= 12):\n'
        '        raise ValueError("spectral resolution is outside audited bounds")',
        "spectral bound")
    source = replace_once(source,
        '        and spectral_m <= grid_m <= 24\n',
        '        and spectral_m <= grid_m <= maximum_grid_m\n', "grid bound")
    return source


def main() -> int:
    directory = Path(__file__).resolve().parent
    fourier_module = types.ModuleType("desc_fourier_runner")
    fourier_module.__file__ = str(directory / "desc_fourier_runner.py")
    exec(compile(patched_fourier(Path(fourier_module.__file__)),
                 "desc_fourier_axisymmetric_v99_runtime", "exec"),
         fourier_module.__dict__)
    sys.modules["desc_fourier_runner"] = fourier_module
    stability_module = types.ModuleType("desc_axisymmetric_stability_v99_runtime")
    stability_module.__file__ = str(directory / "desc_stellarator_stability_runner.py")
    exec(compile(patched_stability(Path(stability_module.__file__)),
                 "desc_axisymmetric_stability_v99_runtime", "exec"),
         stability_module.__dict__)
    return int(stability_module.main())


if __name__ == "__main__":
    raise SystemExit(main())
