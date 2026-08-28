# v86 medium structural campaign seal

- Seal hash: `196a4c3c473ef9e4541fc76adeaa4eb3279b559df5911fcab5c6f64d25a2f235`
- Unique candidate-bound field inputs: 549
- Duplicate execution keys: 0 at every authoritative merge
- Evidence firewall: passed at every authoritative merge

| Stage | Candidates | Status histogram | Result hash |
|---|---:|---|---|
| open_field | 324 | fail=2, pass=322 | `1932c70533ee990987bf96855250cae147908d2523b1313561a22ace3b741d84` |
| closed_field | 225 | pass=225 | `497707c8ed54fee2ed208f8431bf3ca279a8c201dd305b4094116539bc658d68` |
| open_end_loss | 256 | fail=198, pass=58 | `aa5f64d208dc0ad3ecdd6f1ce364a38c85105640df7b3f87f20897b1d63f0d64` |
| closed_p32 | 223 | fail=164, pass=59 | `803d4ffec79877d40404843e2e488169888f269f015c6cc86b21612bc21d7577` |
| open_finite_pressure | 58 | fail=2, pass=53, unknown=3 | `8cbf731bfb8d379f012239690205207f53a8cb4229b10c824c0819ef56d4432a` |
| closed_p64 | 52 | pass=52 | `67bd15f80eaa8f8868da0477ea51213c04e50556055307709cdc4d22e0a234b8` |
| closed_p128 | 37 | pass=37 | `0f4b4b651deea58a08d54c50201495ce2c7397e473f7a7fea6f3e225b6129092` |
| closed_finite_pressure | 19 | fail=19 | `cc9c74303b784697befbe6dbcdea18e7b92b8f6f63d54505a008bd7fd0b20c86` |

Open-field passes remain bounded screens. Closed-field Poincare survival did not produce a finite-pressure pass: all 19 formally promoted DESC executions failed. Stability is therefore not scheduled. This seal makes no complete-physics, engineering, originality, net-power, or build-ready claim.
