#!/usr/bin/env python3
"""FreeGS provider with a declared smooth edge-current tilt capability."""

from __future__ import annotations

from pathlib import Path

import freegs
import numpy as np
from scipy.integrate import quad, romb

import freegs_separated_profile_runner_v130 as v130


PROTOCOL_ID = "fusionconceptai-v131-edge-current-tilt-20260830"


class ConstrainPaxisIpEdgeTiltShapes(v130.ConstrainPaxisIpSeparatedShapes):
    def __init__(self, *args, current_edge_tilt: float,
                 current_edge_power: float, **kwargs):
        super().__init__(*args, **kwargs)
        if not (-0.95 < current_edge_tilt <= 5.0):
            raise ValueError("current_edge_tilt is outside (-0.95, 5]")
        if not (0.5 <= current_edge_power <= 8.0):
            raise ValueError("current_edge_power is outside [0.5, 8]")
        self.current_edge_tilt = float(current_edge_tilt)
        self.current_edge_power = float(current_edge_power)

    def _current_shape(self, pn):
        coordinate = np.clip(pn, 0.0, 1.0)
        base = self._shape(
            coordinate, self.current_alpha_m, self.current_alpha_n)
        return base * (1.0 + self.current_edge_tilt *
                       coordinate ** self.current_edge_power)

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
        current_shape = self._current_shape(psi_norm)
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
            raise ValueError("edge-tilted current-profile integral vanished")
        self._ffprime_coefficient = freegs.gradshafranov.mu0 * (
            self.Ip - pressure_current) / inverse_radius_current_integral
        current = (R * self._pprime_coefficient * pressure_shape +
                   self._ffprime_coefficient * current_shape /
                   (R * freegs.gradshafranov.mu0))
        self.psi_bndry = psi_bndry
        self.psi_axis = psi_axis
        return current

    def ffprime(self, psinorm):
        return self._ffprime_coefficient * self._current_shape(psinorm)


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if source.count(old) != 1:
        raise RuntimeError(f"v131 FreeGS patch point mismatch: {label}")
    return source.replace(old, new, 1)


def patched_source() -> str:
    source = v130.patched_source()
    source = replace_once(
        source,
        '    if profile_kind not in ("ConstrainPaxisIp",\n'
        '                             "ConstrainPaxisIpSeparatedShapes"):\n',
        '    if profile_kind not in ("ConstrainPaxisIp",\n'
        '                             "ConstrainPaxisIpSeparatedShapes",\n'
        '                             "ConstrainPaxisIpEdgeTiltShapes"):\n',
        "edge profile capability dispatch",
    )
    old = '''    else:
        profiles = ConstrainPaxisIpSeparatedShapes(
            eq,
            finite(require(profile, "axis_pressure_pa"), "axis_pressure_pa"),
            finite(require(profile, "plasma_current_a"), "plasma_current_a"),
            finite(require(profile, "vacuum_f_tm"), "vacuum_f_tm"),
            pressure_alpha_m=finite(require(profile, "alpha_m"), "alpha_m"),
            pressure_alpha_n=finite(require(profile, "alpha_n"), "alpha_n"),
            current_alpha_m=finite(require(profile, "current_alpha_m"),
                                   "current_alpha_m"),
            current_alpha_n=finite(require(profile, "current_alpha_n"),
                                   "current_alpha_n"),
        )'''
    new = '''    elif profile_kind == "ConstrainPaxisIpSeparatedShapes":
        profiles = ConstrainPaxisIpSeparatedShapes(
            eq,
            finite(require(profile, "axis_pressure_pa"), "axis_pressure_pa"),
            finite(require(profile, "plasma_current_a"), "plasma_current_a"),
            finite(require(profile, "vacuum_f_tm"), "vacuum_f_tm"),
            pressure_alpha_m=finite(require(profile, "alpha_m"), "alpha_m"),
            pressure_alpha_n=finite(require(profile, "alpha_n"), "alpha_n"),
            current_alpha_m=finite(require(profile, "current_alpha_m"),
                                   "current_alpha_m"),
            current_alpha_n=finite(require(profile, "current_alpha_n"),
                                   "current_alpha_n"),
        )
    else:
        profiles = ConstrainPaxisIpEdgeTiltShapes(
            eq,
            finite(require(profile, "axis_pressure_pa"), "axis_pressure_pa"),
            finite(require(profile, "plasma_current_a"), "plasma_current_a"),
            finite(require(profile, "vacuum_f_tm"), "vacuum_f_tm"),
            pressure_alpha_m=finite(require(profile, "alpha_m"), "alpha_m"),
            pressure_alpha_n=finite(require(profile, "alpha_n"), "alpha_n"),
            current_alpha_m=finite(require(profile, "current_alpha_m"),
                                   "current_alpha_m"),
            current_alpha_n=finite(require(profile, "current_alpha_n"),
                                   "current_alpha_n"),
            current_edge_tilt=finite(require(profile, "current_edge_tilt"),
                                     "current_edge_tilt"),
            current_edge_power=finite(require(profile, "current_edge_power"),
                                      "current_edge_power"),
        )'''
    return replace_once(source, old, new, "edge profile construction")


_namespace = {
    "__name__": "freegs_edge_tilt_runtime_v131",
    "__file__": str(Path(__file__).with_name("freegs_runner.py")),
    "ConstrainPaxisIpSeparatedShapes": v130.ConstrainPaxisIpSeparatedShapes,
    "ConstrainPaxisIpEdgeTiltShapes": ConstrainPaxisIpEdgeTiltShapes,
}
exec(compile(patched_source(), "freegs_edge_tilt_runtime_v131", "exec"), _namespace)
solve = _namespace["solve"]
