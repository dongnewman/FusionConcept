# v117 channel thermal-hydraulics campaign

ITER/C-2W reran first: 2/2 passed with 0 bypasses.

The Pareto-preserving handoff retained 18 assemblies across source candidate, coolant temperature rise and divertor target area. It evaluated 540 explicit helium-channel designs. 101 rows passed, representing 12 assemblies and 6 source candidates. 439 rows were physically rejected.

Blockers: `{"updated_net_electric_power":137,"nominal_structure_temperature":30,"loss_of_flow_structure_temperature":360}`. Unsupported=0, provider failure=0, whole-device credible=0.

Acceptance hash: `9309d5bdc2ff3edcd607e80524ddd151b6e306f06d72e93ebe62bf1d0b660124`

v117 generates explicit helium-channel overlays and solves nominal and 50-percent-flow axial energy graphs at three mesh levels through the v94 registry and whole-graph assembler. Gnielinski heat transfer, Petukhov smooth-tube friction, a 20-percent one-sided heat-transfer derating, coolant pumping power and source-pinned EUROFER temperature limits are evaluated candidate-by-candidate. A pass is a one-dimensional lumped channel screen, not 3D conjugate CFD, manifold/maldistribution qualification, irradiation damage, LOCA safety, component certification or whole-device evidence.
