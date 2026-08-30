#!/usr/bin/env python3
"""Materialize a v134 two-term-profile three-grid FreeGS result."""

import materialize_v128_freegs_raw as base
from freegs_two_term_profile_runner_v134 import solve
from run_v134_freegs_candidate import transformed_input

base.solve = solve
base.transformed_input = transformed_input

if __name__ == "__main__":
    raise SystemExit(base.main())
