# v115 corrected whole-device rescreen

ITER/C-2W was rerun before candidate screening: 2/2 passed with 0 bypasses.

The campaign bound 9 v114 candidates to their FreeGS, DESC and nine-case static artifacts. It generated 216 assemblies with declared 90/110/120 K coolant rises and four independently isolated equal-energy dump segments. Actual-static assembly survivors: 200; available-provider DAG passes: 200; reduced dynamic survivors: 600; source-pinned material survivor rows: 384, representing 128 unique assemblies from 6 source candidates.

Screen blockers: `{"net_electric_power":16}`. Dynamic blockers: `{"vertical_displacement_event":200,"single_pf_coil_trip":200}`. Material blockers: `{"rebco_peak_field":216}`.

Unsupported=0, provider-system-failure=0, complete provider preflight=0, whole-device credible=0, validation pass=0. Surviving reduced subgraphs remain high-fidelity pending and are not promoted to whole-device status.

Acceptance hash: `531abeb2d136c4fa1ade0496fb48996af8a3b2987d81f1d768c92dcbf742f526`

v115 reruns the ITER/C-2W regression, binds v114 FreeGS, DESC and nine-case static artifacts, sizes coolant flow from declared 90/110/120 K temperature rises, and executes the reduced assembly, provider-DAG, dynamic-fault and source-pinned material screens. Actual worst-case static field, current density and support stress replace the earlier nominal engineering proxies. A survivor remains high-fidelity pending: missing complete transport, exhaust, 3D neutronics/damage, nonlinear control, full numerical VVUQ and candidate-bound validation remain independent obligations.
