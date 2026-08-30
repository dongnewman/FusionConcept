#!/usr/bin/env python3
"""Capability extension for independent pressure and current profile shapes.

The sealed FreeGS runner is kept byte-for-byte intact.  This wrapper extends
only the profile construction lane and retains all shared-state diagnostics.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

import freegs
import numpy as np
from scipy.integrate import quad, romb

from freegs_shared_state_runner_v119 import patched_source as shared_patched_source


PROTOCOL_ID = "fusionconceptai-v130-separated-pressure-current-profile-20260830"


class ConstrainPaxisIpSeparatedShapes(freegs.jtor.Profile):
    """Constrain axis pressure and total current with independent shapes."""

    def __init__(self, eq, paxis: float, ip: float, fvac: float, *,
                 pressure_alpha_m: float, pressure_alpha_n: float,
                 current_alpha_m: float, current_alpha_n: float):
        values = (paxis, ip, fvac, pressure_alpha_m, pressure_alpha_n,
                  current_alpha_m, current_alpha_n)
        if not all(np.isfinite(values)):
            raise ValueError("separated profile parameters must be finite")
        if paxis <= 0.0 or pressure_alpha_m <= 0.0 or pressure_alpha_n <= 0.0:
            raise ValueError("pressure profile parameters must be positive")
        if current_alpha_m <= 0.0 or current_alpha_n <= 0.0:
            raise ValueError("current profile parameters must be positive")
        self.eq = eq
        self.paxis = float(paxis)
        self.Ip = float(ip)
        self._fvac = float(fvac)
        self.pressure_alpha_m = float(pressure_alpha_m)
        self.pressure_alpha_n = float(pressure_alpha_n)
        self.current_alpha_m = float(current_alpha_m)
        self.current_alpha_n = float(current_alpha_n)

    @staticmethod
    def _shape(pn, alpha_m: float, alpha_n: float):
        return (1.0 - np.clip(pn, 0.0, 1.0) ** alpha_m) ** alpha_n

    def Jtor(self, R, Z, psi, psi_bndry=None):
        self.eq._updateBoundaryPsi(psi)
        psi_bndry = self.eq.psi_bndry
        opt, xpt = freegs.critical.find_critical(R, Z, psi)
        if not opt:
            raise ValueError("No O-points found!")
        psi_axis = opt[0][2]
        if psi_bndry is not None:
            mask = freegs.critical.core_mask(R, Z, psi, opt, xpt, psi_bndry)
        elif xpt:
            psi_bndry = xpt[0][2]
            mask = freegs.critical.core_mask(R, Z, psi, opt, xpt)
        else:
            psi_bndry = psi[0, 0]
            mask = None
        flux_span = float(psi_bndry - psi_axis)
        if abs(flux_span) <= 1.0e-30:
            raise ValueError("axis-boundary flux span vanished")
        psi_norm = (psi - psi_axis) / flux_span
        pressure_shape = self._shape(
            psi_norm, self.pressure_alpha_m, self.pressure_alpha_n)
        current_shape = self._shape(
            psi_norm, self.current_alpha_m, self.current_alpha_n)
        if mask is not None:
            pressure_shape = pressure_shape * mask
            current_shape = current_shape * mask
        pressure_integral, _ = quad(
            lambda x: (1.0 - x ** self.pressure_alpha_m) **
            self.pressure_alpha_n, 0.0, 1.0)
        self._pprime_coefficient = -self.paxis / (pressure_integral * flux_span)
        dR = float(R[1, 0] - R[0, 0])
        dZ = float(Z[0, 1] - Z[0, 0])
        pressure_current = self._pprime_coefficient * romb(
            romb(R * pressure_shape)) * dR * dZ
        inverse_radius_current_integral = romb(
            romb(current_shape / R)) * dR * dZ
        if abs(inverse_radius_current_integral) <= 1.0e-30:
            raise ValueError("current-profile integral vanished")
        self._ffprime_coefficient = freegs.gradshafranov.mu0 * (
            self.Ip - pressure_current) / inverse_radius_current_integral
        current = (R * self._pprime_coefficient * pressure_shape +
                   self._ffprime_coefficient * current_shape /
                   (R * freegs.gradshafranov.mu0))
        self.psi_bndry = psi_bndry
        self.psi_axis = psi_axis
        return current

    def pprime(self, psinorm):
        return self._pprime_coefficient * self._shape(
            psinorm, self.pressure_alpha_m, self.pressure_alpha_n)

    def ffprime(self, psinorm):
        return self._ffprime_coefficient * self._shape(
            psinorm, self.current_alpha_m, self.current_alpha_n)

    def fvac(self):
        return self._fvac


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if source.count(old) != 1:
        raise RuntimeError(f"v130 FreeGS patch point mismatch: {label}")
    return source.replace(old, new, 1)


def patched_source() -> str:
    source = shared_patched_source()
    source = replace_once(
        source,
        '    if require(profile, "kind") != "ConstrainPaxisIp":\n'
        '        raise ValueError("only ConstrainPaxisIp is supported")',
        '    profile_kind = require(profile, "kind")\n'
        '    if profile_kind not in ("ConstrainPaxisIp",\n'
        '                             "ConstrainPaxisIpSeparatedShapes"):\n'
        '        raise ValueError("unsupported declared profile capability")',
        "profile capability dispatch",
    )
    source = replace_once(
        source,
        '    profiles = freegs.jtor.ConstrainPaxisIp(\n'
        '        eq,\n'
        '        finite(require(profile, "axis_pressure_pa"), "axis_pressure_pa"),\n'
        '        finite(require(profile, "plasma_current_a"), "plasma_current_a"),\n'
        '        finite(require(profile, "vacuum_f_tm"), "vacuum_f_tm"),\n'
        '        alpha_m=finite(require(profile, "alpha_m"), "alpha_m"),\n'
        '        alpha_n=finite(require(profile, "alpha_n"), "alpha_n"),\n'
        '        Raxis=finite(require(profile, "profile_axis_radius_m"), "profile_axis_radius_m"),\n'
        '    )',
        '    if profile_kind == "ConstrainPaxisIp":\n'
        '        profiles = freegs.jtor.ConstrainPaxisIp(\n'
        '            eq,\n'
        '            finite(require(profile, "axis_pressure_pa"), "axis_pressure_pa"),\n'
        '            finite(require(profile, "plasma_current_a"), "plasma_current_a"),\n'
        '            finite(require(profile, "vacuum_f_tm"), "vacuum_f_tm"),\n'
        '            alpha_m=finite(require(profile, "alpha_m"), "alpha_m"),\n'
        '            alpha_n=finite(require(profile, "alpha_n"), "alpha_n"),\n'
        '            Raxis=finite(require(profile, "profile_axis_radius_m"),\n'
        '                         "profile_axis_radius_m"),\n'
        '        )\n'
        '    else:\n'
        '        profiles = ConstrainPaxisIpSeparatedShapes(\n'
        '            eq,\n'
        '            finite(require(profile, "axis_pressure_pa"), "axis_pressure_pa"),\n'
        '            finite(require(profile, "plasma_current_a"), "plasma_current_a"),\n'
        '            finite(require(profile, "vacuum_f_tm"), "vacuum_f_tm"),\n'
        '            pressure_alpha_m=finite(require(profile, "alpha_m"), "alpha_m"),\n'
        '            pressure_alpha_n=finite(require(profile, "alpha_n"), "alpha_n"),\n'
        '            current_alpha_m=finite(require(profile, "current_alpha_m"),\n'
        '                                   "current_alpha_m"),\n'
        '            current_alpha_n=finite(require(profile, "current_alpha_n"),\n'
        '                                   "current_alpha_n"),\n'
        '        )',
        "separated profile construction",
    )
    return source


_namespace = {
    "__name__": "freegs_separated_profile_runtime_v130",
    "__file__": str(Path(__file__).with_name("freegs_runner.py")),
    "ConstrainPaxisIpSeparatedShapes": ConstrainPaxisIpSeparatedShapes,
}
exec(compile(patched_source(), "freegs_separated_profile_runtime_v130", "exec"),
     _namespace)
solve = _namespace["solve"]
canonical_hash = _namespace["canonical_hash"]


def source_hash() -> str:
    return hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
