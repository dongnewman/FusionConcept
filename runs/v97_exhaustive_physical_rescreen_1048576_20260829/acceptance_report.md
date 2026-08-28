# v97 Exhaustive Physical Rescreen Acceptance

- Acceptance: `pass`.
- Complete grammar coverage: 1048576/1048576.
- Unique non-isomorphic topologies: 1048576.
- Closure funnel: `{"unsupported":455444,"closed":593132}`.
- Unique closed inputs sent to high-cost execution: 593132.
- Final expanded statuses: `{"numerical_fail":0,"unsupported":455444,"unknown":593132,"closed":0,"physical_fail":0}`.
- Sealed v91-v96 preservation: `pass`.

Every closure shard and high-cost shard ran the manufactured solution, ITER, and C-2W
through the same v96 compiler/provider/solver/numerical-VVUQ chain before candidate work.
Only exact unique closed graph/solver inputs entered high-cost execution. Historical v91
gate metrics were not read or credited.

`unknown` denotes missing candidate-bound validation evidence after numerical execution.
It is independent from `unsupported`, `physical_fail`, and `numerical_fail`. This reduced
campaign does not establish experimental validation or device feasibility.

Acceptance hash: `da62c2468a1c49394619b6fc9204c79cb4bbced7f202e6f78455c9424def97da`.
