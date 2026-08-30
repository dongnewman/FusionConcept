#!/usr/bin/env python3
"""FreeGS provider for a declared shoulder-plus-edge current profile."""

from __future__ import annotations

from pathlib import Path

import numpy as np

import freegs_edge_tilt_runner_v131 as v131


PROTOCOL_ID = "fusionconceptai-v134-two-term-current-profile-20260830"


class ConstrainPaxisIpTwoTermEdgeShapes(v131.ConstrainPaxisIpEdgeTiltShapes):
    def __init__(self, *args, current_shoulder_amplitude: float,
                 current_shoulder_power: float, current_edge_amplitude: float,
                 current_edge_power: float, **kwargs):
        super().__init__(*args, current_edge_tilt=0.0,
                         current_edge_power=8.0, **kwargs)
        if not (0.0 <= current_shoulder_amplitude <= 1.0):
            raise ValueError("current_shoulder_amplitude is outside [0, 1]")
        if not (1.0 <= current_shoulder_power <= 8.0):
            raise ValueError("current_shoulder_power is outside [1, 8]")
        if not (-0.95 < current_edge_amplitude <= 0.0):
            raise ValueError("current_edge_amplitude is outside (-0.95, 0]")
        if not (4.0 <= current_edge_power <= 16.0):
            raise ValueError("current_edge_power is outside [4, 16]")
        self.current_shoulder_amplitude = float(current_shoulder_amplitude)
        self.current_shoulder_power = float(current_shoulder_power)
        self.current_edge_amplitude = float(current_edge_amplitude)
        self.current_edge_power = float(current_edge_power)

    def _current_shape(self, pn):
        coordinate = np.clip(pn, 0.0, 1.0)
        base = self._shape(
            coordinate, self.current_alpha_m, self.current_alpha_n)
        modifier = (1.0 + self.current_shoulder_amplitude *
                    coordinate ** self.current_shoulder_power +
                    self.current_edge_amplitude *
                    coordinate ** self.current_edge_power)
        if np.any(modifier <= 0.0):
            raise ValueError("two-term current-profile modifier became non-positive")
        return base * modifier


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if source.count(old) != 1:
        raise RuntimeError(f"v134 FreeGS patch point mismatch: {label}")
    return source.replace(old, new, 1)


def patched_source() -> str:
    source = v131.patched_source()
    source = replace_once(
        source,
        '                             "ConstrainPaxisIpEdgeTiltShapes"):\n',
        '                             "ConstrainPaxisIpEdgeTiltShapes",\n'
        '                             "ConstrainPaxisIpTwoTermEdgeShapes"):\n',
        "two-term capability dispatch",
    )
    old = '''    else:
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
    new = old.replace("    else:\n", (
        '    elif profile_kind == "ConstrainPaxisIpEdgeTiltShapes":\n'), 1) + '''
    else:
        profiles = ConstrainPaxisIpTwoTermEdgeShapes(
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
            current_shoulder_amplitude=finite(
                require(profile, "current_shoulder_amplitude"),
                "current_shoulder_amplitude"),
            current_shoulder_power=finite(
                require(profile, "current_shoulder_power"),
                "current_shoulder_power"),
            current_edge_amplitude=finite(
                require(profile, "current_edge_amplitude"),
                "current_edge_amplitude"),
            current_edge_power=finite(require(profile, "current_edge_power"),
                                      "current_edge_power"),
        )'''
    return replace_once(source, old, new, "two-term profile construction")


_namespace = {
    "__name__": "freegs_two_term_profile_runtime_v134",
    "__file__": str(Path(__file__).with_name("freegs_runner.py")),
    "ConstrainPaxisIpSeparatedShapes": v131.v130.ConstrainPaxisIpSeparatedShapes,
    "ConstrainPaxisIpEdgeTiltShapes": v131.ConstrainPaxisIpEdgeTiltShapes,
    "ConstrainPaxisIpTwoTermEdgeShapes": ConstrainPaxisIpTwoTermEdgeShapes,
}
exec(compile(patched_source(), "freegs_two_term_profile_runtime_v134", "exec"),
     _namespace)
solve = _namespace["solve"]
