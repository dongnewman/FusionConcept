# FusionConceptAI v93 PVW slice-1 acceptance

- Protocol seal: **pass**
- Regenerated complete v93 declarations: **246 / 246**
- Schema-complete declarations: **246**
- Solver-complete declarations: **0**
- Exact plasma-vacuum-wall slice matches: **0**
- Candidate solver executions: **0**
- Candidate numerical VVUQ executions: **0**
- Candidate validation VVUQ executions: **0**
- Manufactured PVW verification: **pass**
- Manufactured observed order: **1.9999179980167734**
- Manufactured fine GCI: **0.000991077573883784 %**
- First blocker: `all_candidate_declarations_exceed_pvw_slice_and_require_recomputed_physics`

Every v92 realization-pass record was regenerated as a structurally complete v93 declaration with explicit regions, state ownership, exactly one governing operator per equation, residual metadata, physical interfaces, validity-domain obligations, discretization status, and evidence obligations. Each declaration separately records directly recoverable data, deterministic derivations, quantities that require candidate-bound recomputation, and quantities requiring external evidence.

All 246 declarations include coil, open-loss, terminal, plasma, vacuum, and wall regions. They also contain states and governing operators outside the sealed radial plasma-vacuum-wall slice, lack an attested cylindrical radial reduction, and require candidate-bound field/material/closure recomputation. The router therefore admitted zero candidates. No subproblem was projected out for candidate credit.

The native PVW solver is a real mixed radial Grad-Shafranov discretization with explicit plasma-vacuum flux and tangential-field constraints, a monolithic exact-Jacobian solve, a two-region nullspace-Schur domain decomposition, final monolithic residual/force/conservation audit, and coarse/medium/fine verification. Its manufactured result is code verification only.
