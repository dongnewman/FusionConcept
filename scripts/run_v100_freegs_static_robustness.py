#!/usr/bin/env python3
"""Static robustness using the explicit v100 PF radial-build declaration."""

from __future__ import annotations

import run_v99_freegs_static_robustness as base
from run_v100_freegs_candidate import transformed_input


base.RUNNER_VERSION = "v100_shared_radial_build_static_robustness_v1"
base.CLAIM_BOUNDARY = (
    "Candidate-bound deterministic v100 FreeGS static perturbation re-solves and "
    "explicit winding-pack/additive-field/membrane-stress proxies only. A pass is not "
    "dynamic control, complete engineering, superconducting qualification, disruption "
    "analysis, transport/exhaust, experimental validation, or whole-device credibility."
)
base.transformed_input = transformed_input

if __name__ == "__main__":
    raise SystemExit(base.main())
