# v116 multi-region conservation providers

ITER/C-2W reran first: 2/2 passed, bypass=0.

Six distinct v115 source candidates each supplied one assembly chosen by declared net-power output and a canonical-hash tie break. Core/edge particle and energy conservation passed 6/6. Field-aligned Spitzer-Harm exhaust passed 5/6. The resulting conservation-provider frontier contains 5 candidates; blockers: `{"exhaust:collisional_flux_limiter":1}`.

All solves used the v94 provider registry, field dependency closure, complete graph residual/Jacobian assembly, three mesh levels and independent analytic solutions. Missing-interface negative control remains solver-ineligible. Unsupported=0, provider failure=0.

The whole-device preflight deliberately remains `not_ready` with 2/9 complete obligations. This provider pack does not claim 3D turbulent/neoclassical transport, kinetic SOL/neutral physics, experimental validation or whole-device credibility.

Acceptance hash: `9d777ad053ac0a27ba6869cf4d158ebce95a700996cd5bb9d0416d776caa70fa`

v116 executes candidate-bound core/edge particle and energy diffusion plus a field-aligned Spitzer-Harm transformed-temperature exhaust solve through the v94 operator registry, dependency closure planner and whole-graph residual/Jacobian assembler. Three mesh levels and analytic independent solutions audit numerical closure. These are one-dimensional collisional conservation providers, not 3D turbulent or neoclassical transport, kinetic SOL/neutral transport, complete exhaust qualification, experimental validation, or whole-device evidence.
