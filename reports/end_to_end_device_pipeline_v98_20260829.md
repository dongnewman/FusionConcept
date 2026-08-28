# FusionConceptAI v98 end-to-end device pipeline acceptance

Date: 2026-08-29

## Outcome

The 1,048,576-topology campaign completed without candidate-level `unsupported` and without provider-system failures. It produced 67 reduced computational candidates. After repairing the candidate-to-FreeGS realization transformer, 31 passed candidate-bound free-boundary equilibrium and three-grid numerical VVUQ; 36 failed explicit physical or numerical gates. No candidate passed validation VVUQ, so the number of credible or experimentally validated whole devices remains zero.

## Stage census

| Stage result | Count |
|---|---:|
| topology screen fail | 455,444 |
| provider system fail | 0 |
| reduced physics screen fail | 592,897 |
| reduced numerical VVUQ fail | 168 |
| reduced computational candidate | 67 |
| FreeGS equilibrium plus numerical VVUQ pass | 31 |
| FreeGS fail | 36 |
| validation VVUQ pass | 0 |

The counts distinguish topology rejection, provider defects, candidate physics rejection, numerical verification, and validation. A provider defect is never converted into a candidate failure, and a subgraph or equilibrium pass is never promoted to whole-device validation.

## Why the earlier candidates all failed

The initial normalized four-coil transformer rejected 67/67 candidates. Its dominant failure was elongation binding: 65 candidates requested elongation near 2.1 while the fixed grammar commonly realized about 1.3–1.5. This was a transformer false-negative, not evidence that all 67 devices were physically impossible.

The replacement transformer derives an eight-coil layout and X-point/isoflux constraints from each candidate's declared major radius, minor radius, elongation, and triangularity. No candidate ID, hash, device label, device family, or fixed operator combination is used for routing. The physical and numerical thresholds were not relaxed. Under this corrected grammar, 31/67 passed and 36/67 still failed. The remaining failure histogram is:

| Gate | Failures |
|---|---:|
| coarse elongation binding | 20 |
| coarse minor-radius binding | 8 |
| coarse q95 safety | 15 |
| fine elongation binding | 6 |
| fine minor-radius binding | 2 |
| fine q95 safety | 1 |
| fine-grid solver convergence | 1 |

Thus the previous zero-pass result was substantially a filter/transformer problem, while the post-repair failures are candidate-bound realization or numerical failures.

## Reference controls

ITER and C-2W were rerun before the full campaign through capability declarations rather than identity routing. Both reference-regression controls passed, and both retained `validation_credit=false`. ITER is a published design/reference scenario rather than an experimental D-T validation fixture here. The C-2W check is bounded to published parameter ranges and does not validate the omitted fast-ion, deposition, charge-exchange, control, or reconstructed-equilibrium physics.

## VVUQ and evidence boundary

All 31 FreeGS survivors executed `free-boundary equilibrium solve -> three-grid numerical VVUQ -> validation VVUQ`. Their numerical VVUQ status is `pass`; their validation status is independently `unknown_validation_domain` because no candidate-bound independent measurement set is available. Experimental validation credit is zero.

The 31 survivors are therefore high-fidelity equilibrium candidates only. They have not passed complete MHD stability, transport, materials, engineering qualification, independent experimental validation, or whole-device VVUQ. No credible fusion device is claimed.

## Reproducibility evidence

- Reference acceptance hash: `ec992b1d69713380d948569045f95ba5cdc44abc5a04b6f3a29ece7828f9e6eb`
- Reduced full-campaign acceptance hash: `3286606eb98e6388b9c00e53473f978eba0c10b6ff77a92438eb8d7c30d68591`
- Four-coil negative-control acceptance hash: `56e03390ea59ae284be4fe22dfd70a23cb73aa930c8065a343129f92f437f7ae`
- Eight-coil FreeGS v3 acceptance hash: `b559c7c8cc4d3fc7195dbff7b8f860662ed15df657521ca239e0bf0e5fdb076d`
- v98 targeted tests: 18/18 pass
- Full FusionConceptAI test suite: pass

The sealed v93 products and pre-existing candidate data were not modified by the v98 campaign.
