# Unified fusion judgment chain v55

## Outcome

V55 replaces parent/family-shaped post-search screening with one fixed eight-stage judgment contract. Every submitted search result is evaluated exactly once by `evaluate_all_search_results_v55`; the input count must equal the evaluated count and there is no family prefilter.

`family`, `parent_family`, classification labels, display labels, and lineage IDs are retained only as non-routing metadata. They are removed from the routing-input projection and cannot change a stage result or its hash. A declared value whose provenance is a family default, parent template, or class default is an explicit stage-1 failure.

## Fixed chain

| Stage | Required candidate-bound answer | Pass boundary |
|---|---|---|
| 1. Physical description completeness | Regions, species, fields, materials, boundaries, sources, sinks, controllers, observables | All are explicit and non-empty; no family/parent default provenance |
| 2. Topology and causality | Nodes, directed account-carrying edges, source/sink/control/observable bindings | No missing endpoint, isolated module, implicit source, or unbound control |
| 3. Conservation and state evolution | Solver artifact and residual terms for `dU/dt + div(F) - S` | Kernel-recomputed normalized residuals meet tolerance; steady time term is negligible or a complete time trajectory is supplied |
| 4. Perturbation and stability | State, boundary, source, controller, and manufacturing perturbations | Every perturbation has a candidate-bound operator result and a bounded accepted outcome |
| 5. Particle/energy transport and burn | Explicit particle production/loss/burn and energy deposition/transport/escape paths | Fusion rate and self-heating bind to the solved state; nominal confinement time or nominal gain is forbidden |
| 6. Net-energy closure | Signed fusion, drive, loss, and recirculating terms | Every term binds to a stage-3/5 solver hash; the kernel recomputes the ledger; generated artificial closure is forbidden |
| 7. Engineering realizability | Field, force, stress, heat flux, temperature, irradiation, quench, repetition rate, access, fuel cycle, lifetime | The same checklist is complete; pass has a non-negative margin; N/A requires an evidence-backed applicability basis |
| 8. Uncertainty and evidence | Perturbation UQ, manufacturing tolerance, model error, convergence, cross-code replication, experiment | All six are resolved with referenced evidence before promotion review eligibility |

Different devices may declare different stage-internal operators. `interchange`, `m=1`, DCLC, AIC, global MHD, flow instability, or ablation instability are operator IDs inside stage 4; none selects a different chain. Steady, transient, and pulsed operation are likewise modes inside stage 3.

## Status semantics

- `fail`: a supplied candidate violates physics/causality/residual/limit requirements, explicitly exceeds an acceptance limit, or attempts a forbidden family default or artificial ledger closure.
- `unknown`: a required solver output, evidence item, perturbation, cross-code result, or other obligation is absent or unsupported. Unknown blocks chain pass but is not a physical falsification.
- `pass`: all checks in the stage are resolved and accepted for the declared mission.

All eight stages execute even after an earlier failure. The overall decision is `fail` if any stage fails, `pass` only if all eight pass, otherwise `unknown`. A pass makes a record eligible for promotion review but never sets `promotion_authorized=true`.

## Legacy boundary

V52 remains a sealed historical low-fidelity screen. Although it sets `family_field_used_for_routing=false`, it still infers different profiles from module-name tokens and consumes legacy boolean ledgers. V54 remains a solver-contract search artifact; its generation-time exactly closed nominal ledgers are not v55 passing evidence. Neither is silently upgraded.

New search workflows must construct the v55 input contract from candidate-bound solver artifacts and call `evaluate_all_search_results_v55` on the entire result set. Missing v55 artifacts yield `unknown` or input-contract failure; the kernel never fabricates a parent or fills a ledger from a device class.

## ITER and C-2W regression boundary

The focused regression contains representative ITER and C-2W contract fixtures. Both traverse the same stage order, use different stage-internal perturbation operators, and pass all eight contract checks. Deliberately changing their family/parent/display labels leaves both the routing hash and stage results unchanged.

These fixtures test the judgment contract, label erasure, evidence binding, and mission semantics. They do not independently reproduce ITER or C-2W physics, prove net-electric production, or authorize a reactor/device promotion. For reference/science missions, stage 6 requires a solver-derived closed ledger but not a fabricated positive net sign; a mission that declares positive net energy requires a positive solved result.

## Verification

Focused regression:

```powershell
julia --project=. --startup-file=no test/unified_judgment_chain_v55.jl
```

Auditable representative report:

```powershell
julia --project=. --startup-file=no scripts/run_uniform_judgment_regression_v55.jl
```

Maximum repository suite:

```powershell
julia --project=. --startup-file=no test/runtests.jl
```
