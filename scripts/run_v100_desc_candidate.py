#!/usr/bin/env python3
"""DESC qualification bound to the v100 shared-radial-build FreeGS transform."""

from __future__ import annotations

import run_v99_desc_candidate as base
from run_v100_freegs_candidate import transformed_input


base.RUNNER_VERSION = "v100_shared_radial_build_cross_code_qualification_v1"
base.CLAIM_BOUNDARY = (
    "Candidate-bound v100 FreeGS-to-DESC cross-code equilibrium and sampled Mercier/"
    "infinite-n ballooning qualification using one shared PF radial build. A pass does "
    "not establish finite-n, resistive, kinetic, nonlinear, transport, materials, "
    "experimental-validation, or whole-device feasibility."
)
base.transformed_input = transformed_input

if __name__ == "__main__":
    raise SystemExit(base.main())
