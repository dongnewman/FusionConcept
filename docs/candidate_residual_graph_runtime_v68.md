# Candidate residual graph runtime v68

v68 is a backend-neutral assembly, convergence, and audit runtime. Physics remains in capability modules. `CandidateSolveManifestV1` remains the candidate-bound input contract; the runtime adds versioned state, residual, Jacobian, mass-matrix, solve-plan, and result-envelope protocols.

## Implemented boundary

- One governing residual producer is required for each state equation; any number of declared additive physics blocks may contribute to the same row.
- Every state has exactly one differential mass declaration or algebraic constraint declaration.
- Regions, spatial dimensions, time modes, boundaries, units, Jacobian row/column slots, exclusive outputs, and paired interface-flux signs are compiled before solve.
- Missing operators are `unsupported`; unresolved applicability or validity evidence is `unknown`; converged capacity violations are `fail`; only a converged full residual with post-solve audits is `pass`.
- The L1 state is only the initial state, homotopy origin, and diagnostic baseline. The solver advances `(1-lambda) R_L1 + lambda R_full` through declared homotopy steps and requires `lambda = 1` convergence.
- The reference backend performs nondimensional row/state scaling, bound-preserving line search, sparse block assembly, damped Newton-Krylov iteration, and an implicit index-1 DAE trajectory fallback when no steady solve is obtained.
- Each analytic Jacobian block is checked against a directional finite difference and is also probed for undeclared dependencies. `finite_difference_l1_only` lowers the compiled evidence ceiling and `unavailable` is rejected.
- Post-solve evidence includes residual history, per-block residuals, conservation slots, dynamic paired interface-flux closure, physical-state bounds, independent residual recomputation, actuator observables, and Jacobian audits.
- A nonzero-dimensional module cannot receive `pass` from requested grid labels alone. It must return an actual passing `[32,64,128]` trend record; otherwise a converged state remains `unknown_missing_resolution_trend`. Zero-dimensional manufactured balances record this gate as `not_applicable`.

The numerical implementation is accessed only through `AbstractNonlinearBackendAdapterV1`; backend library types do not enter manifests, plans, or result envelopes.

## Current validation scope

The focused v68 suite covers a nonlinear zero-dimensional particle-energy-reaction-radiation-actuator balance, an independent additive exchange module, a two-region conservative diffusion interface, a three-region core-edge-wall loop, open-boundary depletion, reaction-radiation-style thermal growth, actuator saturation, strict unknown applicability, and no-steady-state cases that return complete implicit DAE trajectories. The two-region state remains `unknown` after its numerical/interface audits because no spatial resolution-trend producer is attached. These are numerical-kernel/manufactured-problem results, not device validation.

ITER, C-2W, and ICF/HEDP representative closure, three-level spatial trends for nonzero-dimensional modules, and the 74-representative/10,000-candidate reruns remain later acceptance work. They must not be inferred from the v68 kernel tests.
