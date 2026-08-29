# v109 source-pinned material and engineering screen

ITER and C-2W first reran through the v103 reference regression: 2/2 passed with 0 bypasses.

All 96 v108 dynamic survivors then ran the source-pinned conservative material screen. 96 were physically rejected and 0 survived. The blocker histogram is `{"full_nuclear_radial_build":96,"blanket_loss_of_flow_temperature":96}`.

The current designs have about 1.158 m of declared plasma-to-wall nuclear build, below the 1.2 m rejection-screen lower bound, and the 50 percent coolant-flow fault reaches 873 K, above the 823.15 K EUROFER blanket-structure limit. These are candidate-bound screen failures, not provider gaps.

Unsupported and provider-system failure counts are zero. Complete 3D neutronics, damage/lifetime, component thermal hydraulics, stress/strain/fatigue, manufacturing, whole-device numerical VVUQ and validation remain uncomputed. No whole-device or credibility credit is granted.

Acceptance hash: `e2d5ea49d0483f2b77e71420782fef12e7e12fe71fb2823d0df5f014b5202bd7`

v109 applies source-pinned, one-sided conservative material and radial-build rejection gates to v108 dynamic survivors. A failed computed gate rejects that exact assembly/controller design. Passing every computed gate would remain a reduced screen only: 3D neutronics, irradiation damage and lifetime, detailed thermal hydraulics, component stress/strain, joints, fatigue, manufacturing, numerical VVUQ and validation remain independent obligations. Missing catalog data is a provider-system failure, never a candidate unsupported or physical-failure classification.
