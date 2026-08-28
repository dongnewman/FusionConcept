# v84 fixed-topology realization minimality slice

## Outcome

The additive v84 layer implements a bounded answer to: “what is the simplest
candidate inside the declared grammar and evidence level?” It does not redefine
or overwrite the sealed v68–v83 chain.

- Fixed structure hash: `aaa020ed2465cd2ae92fdec4def1c46b8c5fcf6a5a9caaf89befb74f02c96639`
- Realization grammar hash: `475efe2278309146dd9886bf780691e39cfe79573a7b39e4714ffdcd7cacb006`
- Evidence level: `analytic_lower_bound`
- Grid: 2 physical variants × 2 operating variants × 2 control variants ×
  `closed/mixed` and `open/mixed` = 16 evaluations
- v68 plan/residual/declared hard-gate passes: 16/16
- Six-coordinate nondominated archive: 4 records
- Result hash: `4c4b4b17cd968a459c3222a84c09e4b133c3c61787435b5509a2f95fe3352349`

## Declared representative

The lexicographic representative of the Pareto-equivalent minimum-complexity
records is `v84_closed_mixed_7b84b4f0b60e`.

| Complexity coordinate | Value |
|---|---:|
| Components | 6 |
| Power supplies | 3 |
| Conductor length | 37.421044737854416 m |
| Maximum curvature | 0.3452766517564002 1/m |
| Support mass | 1323.2629842327972 kg |
| Control complexity | 7 |

Candidate binding hash:
`a2728ac636f91c4ba13a4f2bd1a8a3539ff738f6b8b1f676dcfd186885ecaee9`

v68 result hash:
`e8bc4533b2c42fe919bb9081e7f8066698ea0cb7297a291de91fed7064db394f`

This representative is not unique. Four records have the same six complexity
coordinates: two operating/control tuples on each of the two longitudinal
routes. No scalar weighted score was used to separate them.

## Implemented contracts

- `CandidateRealizationGrammarV2`: fixed structure, explicit required/optional
  components, count ranges, allowed low-order bases, and allowed routes.
- `DeviceComplexityManifestV1`: records component count, supply count, conductor
  length, curvature, support mass, and control complexity independently.
- `MinimalityScopeV1`: binds a claim to a grammar hash, structure hash, evidence
  level, hard gates, included/excluded components, and fidelity ladder.
- `RealizationParetoArchiveV1`: rejects candidates before Pareto insertion unless
  all declared hard gates pass and the grammar/structure/evidence level matches.

The seed protocol uses independent deterministic streams for physical,
operating, and control variants. Changing one variant was regression-tested not
to change the other two projections.

## Basis and residual coverage

The low-order library includes periodic Fourier coils, periodic cubic B-spline
coils, current potential, plasma boundary, actuator timing, and controller modal
bases. All six affect the candidate-bound realization block. Conductor length,
maximum centerline curvature, and support mass are derived from sampled low-order
coil centerlines rather than independent random complexity proxies.

For each route, the v68 solve contains the existing Stage 3 longitudinal
particle/energy/actuator balance and the new Stage 4–5 field, boundary,
operating-point, actuator-timing, controller-modal, and low-order margin rows.
Both routes passed v68 analytic directional-Jacobian audits.

## Fidelity firewall

The ordered ladder is:

1. analytic lower bound
2. fast Biot–Savart
3. Poincaré
4. finite-pressure equilibrium
5. stability
6. kinetic transport
7. complete engineering
8. VVUQ / dual code

Progression records must start at the first level and be contiguous. Higher
fidelity may change the next sample count and basis order, but every level keeps
its own feasibility status and higher-fidelity evidence cannot rewrite a lower
level’s result.

## Evidence boundary and next acquisition

The result is a software- and low-order-residual-complete vertical slice only.
It is not finite-pressure equilibrium, all-mode stability, kinetic transport,
complete engineering, VVUQ, net-power, deployability, or originality evidence.

The four Pareto records are queued next for candidate-bound fast Biot–Savart.
Only those that pass that level should advance to Poincaré; feedback should be
used to choose the next sample count and basis order, not to backfill feasibility
credit into this analytic level.

Follow-on update (2026-08-26): the repairable sharded runner and the
candidate-bound finite-filament Biot–Savart → Poincaré queue consumer are now
implemented in `candidate_realization_sharded_fidelity_v84.jl`; see
`reports/v84_sharded_fidelity_funnel_20260826.md`.
