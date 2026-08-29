# v118 repaired full-rescreen acceptance

## Repair disposition

- Execution layer: the accepted rerun used the project FreeGS environment; the 67 wrong-environment errors and two DESC out-of-memory rows were rerun, and no operational error received physical rejection credit.
- Selection layer: downstream front selection now spans engineering and material-relevant fronts, and equal-score selection is normalized at the JSONL artifact boundary so in-memory container types cannot change the chosen assemblies.
- Closure layer: fresh candidate-bound FreeGS, sampled DESC, static, assembly, dynamic-fault, material, conservation, exhaust, and channel providers run in declared order. Identity labels and basis coefficients grant no metric credit.

## Acceptance results

- ITER/C-2W scoped reference regression: 2/2; bypass: 0.
- Full 20-bit grammar: 1,048,576 structures; reduced computational candidates: 67.
- Fresh repaired frontier: FreeGS 9/9, sampled DESC 9/9, nine-case static proxy 9/9.
- Whole-device funnel: 384 material-survivor rows, five conservation-provider survivors, and 101 sampled numerical-VVUQ survivor rows.
- Unsupported candidates: 0; unresolved provider-system failures: 0.
- Validation VVUQ: `external_evidence_required`; validation passes: 0; credible whole devices: 0.

Acceptance hash: `732ebaf5e8cb14124dabbb645f182e9e8f81cb29630924172868093557f3ec3c`

The 101 rows are sampled numerical survivors, not complete stability, transport, engineering, or experimental validation. Partial subgraphs are never promoted to whole-device status, and missing external evidence remains independent from physical failure and `unsupported`.
