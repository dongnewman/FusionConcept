# Candidate Solver Runtime v1

`Candidate Solver Runtime v1` adds an executable, candidate-bound numerical
layer between the explicit physics-module graph and the existing uniform v55
eight-stage judgment chain. The shared contract is the manifest, residual,
evidence, and acceptance protocol. Numerical operators are selected only from
declared module capabilities and applicability; family and parent-family labels
are not routing inputs.

## Protocols

- `CandidateSolveManifestV1` seals the candidate physics hash, regions,
  discretization, state layout, operator bindings, boundaries, sources, initial
  conditions, tolerances, requested outputs, and applicability scope.
- `SolverResultEnvelopeV1` seals the manifest, software/environment and result
  hashes, convergence status, residual history, complete output trajectory,
  conservation slots, resolution/error estimates, status, and evidence ceiling.
- The terminal status vocabulary is `pass`, `fail`, `unknown`, and
  `unsupported`. Missing numerical inputs or an inapplicable operator is
  `unsupported`; a computed but non-converged trajectory is `unknown`.

The module interface is defined by `state_layout`, `residual!`,
`boundary_flux!`, `source_terms!`, `observables`, and `applicability`.
Capabilities such as `axisymmetric_mhd_equilibrium`,
`open_field_kinetic_transport`, or `radiation_hydrodynamics` select the
operators. A candidate with no matching capability remains `unsupported`.

## Stage 3-6 vertical slice

The first executable slice provides control-volume particle and thermal-energy
states, fixed current/flux inventory where declared, state-derived Bohm or
parallel-streaming L1 transport, reduced D-T reaction/bremsstrahlung/alpha
self-heating, RK4 time integration, and an independent finite-difference audit
of `dU/dt + divergence(F) - S`.

Stage 5 consumes only state trajectories admitted by the solver envelope.
Stage 6 is a strict hashed ledger: every included term must cite a Stage 3, 5,
or 7 solver-output hash. A missing recirculating-power or engineering role is
`unknown`; it is not synthesized from a nominal `tau_E`, `Q`, or proxy value.

Stage 1 now requires one explicit control policy:

- active closed-loop control with declared controllers;
- open-loop actuation with declared actuators;
- passive stability with an applicability basis; or
- explicit no-controller with an applicability basis.

An empty controller array is not a declaration, and no controller is inherited
from a parent family.

## Search policy and evidence boundary

All 10,000 v57 candidates execute the real L1 runtime. One representative from
each of 74 mechanism clusters receives a two-resolution recomputation and the
existing conservation, stability, transport, and v56 problem compilers. Higher
fidelity is stratified by mechanism/evidence need, not device family.

The ITER fixture is a published design/reference-scenario baseline, not an
experimental D-T validation point. The C-2W fixture uses published experimental
ranges, but the L1 parallel-streaming model omits fast-ion trapping, beam
deposition, charge exchange, edge bias, active control, and reconstructed FRC
equilibrium. Both fixtures currently return `model_discrepancy`. That result
falsifies the adequacy of the reduced L1 operator for the anchor; it does not
falsify ITER, C-2W, or either topology.

## Reproduction

```powershell
julia --project=. scripts\run_candidate_solver_full_search_v57.jl 10000 v57_20260822
julia --project=. test\runtests.jl
```

The machine-readable report and append-only JSONL archives are under `runs/`.
The audited acceptance summary is
`reports/candidate_solver_full_search_v57_20260822.md`.
