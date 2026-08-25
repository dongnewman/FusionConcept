# Stage 3 universal runtime v70

v70 is additive. It does not modify or reinterpret the sealed v68 residual-graph
or v69 graph-search results.

## Contract and decision semantics

`Stage3ExecutionRequestV1` compiles into a serializable
`Stage3ExecutionPlanV1` and produces a `Stage3EvidenceEnvelopeV1`.
Completeness and conclusion are independent:

- `complete/pass`: every applicable sample, convergence, conservation,
  interface, validity and independent-audit obligation passed;
- `complete/fail`: execution and audits completed and established a physical,
  conservation, stability, bound or capacity violation;
- `incomplete/unknown`: input, validity, convergence, budget, interruption or
  audit evidence is incomplete;
- `incomplete/unsupported`: the capability registry has no exact match.

Non-convergence, exceptions and budget exhaustion cannot become physical fail.
Low-fidelity screen output is not an input to feasibility credit.

## Family-free compilation

The Physics IR contains regions, state/algebraic slots, governing and additive
operators, boundary operators, paired interface fluxes, sources, actuators,
control paths and evidence obligations. Dimensions and time modes are normalized,
including `dae -> index1_dae`. Region names, port order, label metadata and
equivalent supported units are absent from routing hashes.

Capabilities are selected only by operator kind, spatial dimension, time
semantics, state/boundary/interface kinds, Jacobian mode, discretization and
validity domain. Missing exact capabilities remain `unsupported`; there is no
device-name fallback.

## Reference backends

The bounded native registry provides:

- damped Newton for nonlinear 0D balances;
- implicit source-loss ODE integration;
- index-1 DAE consistent initialization, drift audit and repeated time-step
  comparison;
- conservative structured finite-volume/finite-difference reference solves in
  1D, 2D and 3D for diffusion/reaction, with 1D conservative advection;
- paired multi-region flux solves;
- sensor-controller-actuator stability/capacity audits;
- repeated mixed 0D-1D block diffusion coupling.

High-index DAEs, unregistered nonlocal operators, missing PDE boundaries,
moving grids and missing discretization/Jacobian capabilities are explicitly
unsupported. Unstructured meshes, moving boundaries and high-dimensional kinetic
problems require capability adapters and are not native v70 capabilities.

## Evidence and execution

PDE evidence comes from actual repeated solves at every admitted resolution.
The independent balance auditor lives in a separate source file, accepts only
archived cells, sources, oriented faces and geometry, and never calls the main
solver path. Runtime and auditor hashes are SHA-256 hashes of their source files.

Execution supports deterministic Halton samples at depths 1, 4, 16 and 64,
budgets, atomic cache writes, checkpoints, resume and cache replay keyed by plan,
sample and solver hashes. Every persisted hash is calculated from JSON-normalized
content so it can be recomputed from the artifact.

The graph integration uses separate structural and numerical loops. Candidate
records contain the Stage 3 plan, completeness/conclusion, exact failure code,
sample counts, conservation residual, resolution and independent-audit status,
measured cost to the next gate and the evidence artifact reference. Metrics are
aggregated from these records rather than copied from the v69 historical zero.

## Acceptance boundary

The formal acceptance artifact covers 11 positive controls, 7 physical negative
controls, 7 unsupported controls, 2,000 label/family metamorphic trials,
checkpoint/cache replay, and 10,000 graph topologies. It admits the bounded v70
Stage 3 capability registry to the graph numerical loop. It does not establish
that an input-incomplete real fusion candidate is feasible, stable, net-power,
engineering-ready or original.
