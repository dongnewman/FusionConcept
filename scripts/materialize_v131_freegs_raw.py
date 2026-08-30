#!/usr/bin/env python3
"""Materialize a v131 edge-current-tilt three-grid FreeGS result."""

from __future__ import annotations

import materialize_v128_freegs_raw as base
from freegs_edge_tilt_runner_v131 import solve
from run_v131_freegs_candidate import transformed_input


base.solve = solve
base.transformed_input = transformed_input


if __name__ == "__main__":
    raise SystemExit(base.main())
