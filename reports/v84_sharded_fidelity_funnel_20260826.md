# v84 sharded recovery and physical-fidelity funnel

## Outcome

The fixed-topology v84 search now has a repairable, append-only analytic shard
runner and a candidate-bound two-level physical funnel with separate queues:

1. analytic v68 residual hard gates and global six-coordinate Pareto merge;
2. an at-most-100 finite-filament Biot–Savart queue;
3. an at-most-20 Poincaré queue emitted only after the Biot–Savart merge.

Every persisted row has a deterministic record hash. Completed shards bind the
stream SHA-256, grid or queue hash, grammar hash, structure hash, candidate
range, and deterministic shard-result hash. Merge rejects gaps, overlaps,
cross-grid shards, changed physical budgets, stream corruption, and candidate
or analytic-evidence mismatches.

## Recovery acceptance

Both analytic and physical tests deliberately stopped after one candidate,
appended a truncated JSON fragment, and resumed. The runner retained the valid
prefix, removed the damaged suffix, completed the contiguous range, and passed
strict merge validation.

- Analytic interruption/recovery/merge tests: 15/15 passed.
- Separately bounded Biot–Savart/Poincaré queue tests: 12/12 passed.
- Candidate-bound physical funnel compatibility tests: 22/22 passed.
- Merge-summary schema validations: 3/3 passed.

Exceptions remain explicit `exception` records. They are not deleted, converted
to physical failures, or treated as evidence-bearing candidates.

## Candidate binding chain

The physical adapter embeds the original `v84_candidate_binding_hash`, analytic
record hash, variant tuple hash, route, and all six low-order basis coefficient
sets inside a separate physical-execution binding. v71 verifies the execution
binding hash against the finite-filament realization; v81 verifies the same
realization and screen evidence hashes before tracing.

Fourier coil, periodic cubic B-spline coil, and current-potential coefficients
are compiled into closed helical finite-filament centerlines. Plasma-boundary,
operating-point, actuator-timing, and controller-modal coefficients remain bound
in the execution input and evidence chain; they receive no field-quality credit
unless an applicable physical operator consumes them.

## Separate-queue CLI acceptance

Configuration:

- Physical variants: 1
- Operating variants: 1
- Control variants: 1
- Routes: `closed/mixed`, `open/mixed`
- Analytic shards: 2
- Biot–Savart shards: 2
- Poincaré shards: 1
- Biot–Savart queue limit: 2
- Poincaré queue limit: 1
- Acceptance Poincaré budget: 4 turns × 30 steps/turn, 4 bins

Results:

- Analytic candidates: 2
- Analytic hard-gate passes: 2
- Global Pareto queue: 2
- Biot–Savart passes: 2
- Poincaré admissions: 1
- Poincaré narrow failures: 1
- Uncaught exceptions: 0
- Analytic merge hash:
  `33492c62837832e868f5a877cc5a98a14bcdf8329af728e0fdda708c04f0fa79`
- Biot–Savart merge hash:
  `dc12f4aa45d2510a6bb9ec32d47dea8fae6737500701890f5d01cb412a066e96`
- Poincaré merge hash:
  `d1e9eb20114815f46407684c67416101916892433f0996de145a3591493aca29`

Both candidates produced the same bound finite-filament field sample because
they differ only in the longitudinal route:

- minimum sampled field: 0.710973384478127 T
- maximum sampled field: 1.45060817990311 T
- relative spread: 0.843814623965788

The admitted representative failed the acceptance-budget Poincaré gate with
`poincare_field_line_escape`. This rejects only the bound centerline/current
realization under that tracing budget. It does not reject the grammar, all basis
orders, the analytic residual result, or the full device concept.

## Evidence firewall

- Analytic Pareto admission is required before Biot–Savart.
- A candidate-bound Biot–Savart field pass is required before Poincaré.
- Poincaré survival remains `unknown` physical status while its gate status may
  admit the candidate to the next fidelity level.
- Later evidence can update sampling and basis order only.
- Retroactive analytic feasibility credit is always false.
- Retroactive Biot–Savart feasibility credit is always false.

## Fixed-topology 2,000-candidate run

The production-sized pilot ran `10 physical × 10 operating × 10 control × 2
routes = 2,000` analytic candidates in four shards. It then used two
Biot–Savart shards and two Poincaré shards with the formal 32 turns × 180
steps/turn, 16-bin tracing budget.

Results:

- Analytic execution: 2,000/2,000 records, 2,000 current hard-gate passes,
  zero exceptions.
- Global six-coordinate Pareto archive: 160 (8% of the analytic grid).
- Bounded Biot–Savart queue: 100; 60 additional Pareto records were excluded
  by the declared queue limit, not physically rejected.
- Physical signatures in that queue: 4 unique, 96 duplicates (96% duplicate
  rate).
- Biot–Savart: 100 pass, 0 fail, 0 exception under the current v71 fast field
  gate.
- Poincaré queue after route-plus-physical-signature de-duplication: 8; 92
  duplicate field-pass records were not retraced.
- Poincaré: 0 pass, 8 `poincare_field_line_escape` failures, 0 unknown, 0
  exception.
- Both `closed/mixed` and `open/mixed` routes were represented for physical
  variants 3, 4, 7, and 9.

Measured shard critical paths were approximately 37.32 s for analytic, 5.40 s
for Biot–Savart, and 3.67 s for Poincaré. The first run progressed from shard
launch to completed Poincaré shard summaries in about 90 s; process startup and
merge serialization account for the difference from kernel times. A resume
replay completed in 50.00 s and reproduced all three merge hashes:

- Analytic:
  `ea068a5f27d613867b36b544929ce7823372c190c562d5cae4aada6c9dae243e`
- Biot–Savart:
  `4e50c53ad8a260442eb91a22dce2c136589f775b9f93306c6f76a91cffd1fa13`
- Poincaré:
  `de84a29bf863be33dbadf0c97a041d0b9960a061c392d09811e3a93a7820e27d`

## Scale decision

Do not expand this binding distribution directly to 100,000 candidates. The
software chain is stable and exception-free, but the analytic hard gate passed
100%, the Biot–Savart queue was 96% duplicate by actual field inputs, and none
of the eight distinct route/field representatives survived Poincaré. A larger
run would mostly repeat the same low-order physical realizations.

The Poincaré failures may inform only the next physical-variant sampling and
basis-order choice. They do not add feasibility credit to analytic candidates
or reject the declared grammar. Before a wider run, increase physically unique
coil/current-potential variants, make field-result reuse explicit, and require
a small nonzero Poincaré-survival signal without increasing exception rate.

## Reproduction

The default command launches a 2,000-candidate analytic grid over four analytic
shards, then applies the global Pareto gate before two physical shards:

```powershell
./scripts/run_v84_sharded_fidelity_funnel.ps1
```

The default physical budget is 32 Poincaré turns at 180 steps/turn. Shards run
in hidden Julia processes with one Julia thread each; rerunning with `-Resume
$true` reuses completed shards and repairs valid partial prefixes.

## Claim boundary

This completes the engineering path for larger fixed-topology, staged searches.
It does not authorize cross-topology minimality, finite-pressure equilibrium,
stability, kinetic transport, complete engineering, VVUQ, net-power, or
originality claims.
