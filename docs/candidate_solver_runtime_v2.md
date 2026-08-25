# Candidate Solver Runtime v2

Runtime v2 improves the v1 numerical layer without changing the shared
`CandidateSolveManifestV1` and `SolverResultEnvelopeV1` protocols. It adds a
separate `EngineeringResultEnvelopeV1` so that numerical convergence, required
balance demands, engineering loads, and engineering feasibility cannot be
collapsed into one status.

## Capability-matched convergence

V1 advanced every steady candidate for twelve initial transport time constants.
The resulting state normally depleted toward zero because the model contained
particle and energy losses but did not solve the replenishment needed to hold a
declared steady operating state. Its final time-term normalization was therefore
one even when the RK4 trajectory itself was stable.

V2 treats a steady control volume as an algebraic balance problem. It evaluates
the candidate-selected source, transport, reaction, radiation, and boundary
operators at the declared state and solves explicit `required_closure_source`
and `required_closure_sink` slots. These are numerical requirements, not
invented actuators. The resulting fueling and auxiliary-power demands are sent
to Stage 7 for engineering realization.

Pulsed candidates retain a complete time trajectory. A small independent local
RK4 probe recomputes the terminal derivative and audits
`dU/dt + divergence(F) - S` without reusing the final production time step.

Transport is now bound to the state-bearing control volume. When a candidate
declares both a closed core and open exhaust, the global core state receives the
closed-field operator only. An open-field operator is selected only for an
explicit open primary control volume. This selection uses declared region
scope, geometry, capabilities, and time semantics; it does not use family or
parent-family labels.

## Engineering output roles

`EngineeringResultEnvelopeV1` binds every result to the candidate physics,
manifest, Stage-3 result, and Stage-5 result hashes. V2 can numerically produce:

- peak-field magnetic pressure;
- a global electromagnetic force scale;
- an L1 stored-magnetic-energy inventory;
- a global surface-average heat load;
- required steady particle replenishment;
- required auxiliary thermal power; and
- a recirculating-power lower bound.

These are load or inventory outputs. They do not create material allowables,
finite support geometry, local target wetted area, quench protection, fault
loads, lifetime, irradiation, maintenance clearance, fuel-cycle machinery, or
plant efficiency evidence. All eleven uniform Stage-7 checks therefore remain
`unknown` until independently applicable limits and solver outputs are present.

The recirculating role includes only the solved auxiliary-power deficit and
known wall-plug conversion increment. Cryogenics, pumping, current-drive
efficiency, thermal-cycle auxiliaries, fuel processing, and balance of plant are
still incomplete. Its ledger term is marked `role_completeness: lower_bound`.
The v55 kernel now honors `strict_role_completeness_required`; an incomplete
negative-power role can be displayed and hashed but cannot authorize net-power
closure or its sign.

## v58 result

The full v58 run evaluated all 10,000 candidates:

- 9,610 algebraic steady balances converged;
- 180 pulsed trajectories completed and passed the residual audit;
- 210 candidates remained `unsupported` because geometry, pressure,
  temperature, and initial particle/energy states were absent;
- Stage 3 and Stage 5 passed for exactly the 9,790 supported candidates;
- Stage 6 and Stage 7 remained `unknown` for all 10,000 candidates;
- no candidate was promoted.

The maximum conservation residual among supported candidates was
`2.536e-8`. Control-volume transport routing selected 5,450 closed and 4,340
open problems; 210 had no supported scope. Compared with v57, 1,110 erroneous
open-transport bindings on mixed closed-core/open-exhaust candidates were
removed.

The recirculating lower-bound median was `9.681e10 W`; its 25th and 75th
percentiles were `7.689e9 W` and `9.224e12 W`. These large values expose the
severity of the current L1 transport/closure demands. They are not complete
plant-power predictions.

See `reports/candidate_solver_full_search_v58_20260822.md` for the complete
archive and regression audit.
