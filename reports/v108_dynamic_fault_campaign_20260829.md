# v108 dynamic control and fault screen

The 32 v107 assemblies generated four explicit controller overlays each. All 128 overlays
executed PF-trip, density-excursion, vertical-displacement, coolant-flow-loss and quench
scenarios. 32 controller overlays were
rejected and 96 survived.

Blockers: `{"vertical_displacement_event":32,"single_pf_coil_trip":32}`.

Unsupported and provider-system failure counts are zero. This reduced state-space/lumped
fault pass does not close complete dynamic engineering or grant whole-device credibility,
validation or high-cost expansion credit.

Acceptance hash: `241479064488d836dd7df1bd66ab348e2bb1ae12ca38cea1643eee0bb7a48ea0`

v108 executes a candidate-bound reduced time-domain control and protection model for all fault classes declared by the v105 assembly. Controller coordinates are explicit design inputs and receive no metric credit. A scenario failure rejects that controller overlay. A pass is limited to the reduced state-space and lumped protection models; it is not complete nonlinear plasma, thermal-hydraulic, quench, engineering, validation, or whole-device evidence.
