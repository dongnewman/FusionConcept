#!/usr/bin/env python3
"""Hash-pinned extension of the sealed FreeGS runner with shared-state outputs."""

from __future__ import annotations

import hashlib
from pathlib import Path


SEALED_FREEGS_SHA256 = "2d2aa2f5941fce6eda7681ce0daa9011b1fba65bb560e23143f132af9889fec8"


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if source.count(old) != 1:
        raise RuntimeError(f"sealed FreeGS patch point mismatch: {label}")
    return source.replace(old, new, 1)


def patched_source() -> str:
    path = Path(__file__).with_name("freegs_runner.py")
    raw = path.read_bytes()
    actual = hashlib.sha256(raw).hexdigest()
    if actual != SEALED_FREEGS_SHA256:
        raise RuntimeError(f"sealed FreeGS runner hash mismatch: {actual}")
    source = raw.decode("utf-8")
    source = replace_once(source,
        "    geometric_r, geometric_z = map(float, eq.geometricAxis())\n"
        "    result = {",
        "    geometric_r, geometric_z = map(float, eq.geometricAxis())\n"
        "    pressure_volume_average = float(eq.pressure_ave())\n"
        "    toroidal_beta = float(eq.toroidalBeta())\n"
        "    toroidal_field = np.asarray(eq.Btor(eq.R, eq.Z), dtype=float)\n"
        "    toroidal_field = np.nan_to_num(toroidal_field)\n"
        "    if eq.mask is not None:\n"
        "        toroidal_field = toroidal_field * np.asarray(eq.mask, dtype=float)\n"
        "    radial_step = float(eq.R[1, 0] - eq.R[0, 0])\n"
        "    vertical_step = float(eq.Z[0, 1] - eq.Z[0, 0])\n"
        "    toroidal_flux = abs(float(scipy.integrate.romb(\n"
        "        scipy.integrate.romb(toroidal_field)\n"
        "    ) * radial_step * vertical_step))\n"
        "    result = {",
        "shared-state integration")
    source = replace_once(source,
        '            "toroidal_beta": float(eq.toroidalBeta()),\n',
        '            "toroidal_beta": toroidal_beta,\n'
        '            "pressure_volume_average_pa": pressure_volume_average,\n'
        '            "toroidal_field_rms_t": math.sqrt(\n'
        '                2.0 * mu_0 * pressure_volume_average /\n'
        '                max(toroidal_beta, 1.0e-30)\n'
        '            ),\n'
        '            "toroidal_flux_wb": toroidal_flux,\n',
        "shared-state outputs")
    return source


_namespace = {"__name__": "freegs_shared_state_runtime_v119",
              "__file__": str(Path(__file__).with_name("freegs_runner.py"))}
exec(compile(patched_source(), "freegs_shared_state_runtime_v119", "exec"), _namespace)
solve = _namespace["solve"]
