#!/usr/bin/env python3
"""Materialize a v130 separated-profile three-grid FreeGS result."""

from __future__ import annotations

import materialize_v128_freegs_raw as base
from freegs_separated_profile_runner_v130 import solve
from run_v130_freegs_candidate import transformed_input


base.solve = solve
base.transformed_input = transformed_input


if __name__ == "__main__":
    raise SystemExit(base.main())
