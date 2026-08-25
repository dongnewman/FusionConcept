# Candidate Solver Runtime v67 full search

- Status: `candidate_solver_full_search_complete`
- Candidates / topologies: 10000/1000
- Resource states: `{"unknown_candidate_input_incomplete":390,"unsupported_provider_capability_gap":9610}`
- Requirement classes: `{"experimental_dataset":10000,"material_data":780,"numerical_backend":51790}`
- Required capabilities: `{"axisymmetric_mhd_equilibrium":8110,"calibrated_observables":10000,"closed_field_control_volume":5450,"equation_of_state":390,"finite_conductor_electromagnetics":9790,"fusion_reaction_radiation":10000,"multigroup_opacity":390,"open_field_control_volume":5450,"open_field_kinetic_transport":3620,"radiation_hydrodynamics":390,"state_derived_transport":7300,"three_dimensional_mhd_equilibrium":1680}`
- Decisions: `{"fail":9549,"unknown":451}`
- Stage-8 resource-ready: 0
- Producer failures: `{}`
- Family-routed / promotions: 0/0
- Deterministic replay: 7/7
- Deterministic result hash: `3a538b4553928f5497bb2f670f55b5d7146523a12e62fafbc7cf1eb8150221b1`

All candidates use the same capability-routed resource compiler. An empty Stage-8 queue means
the provider catalog lacks acquired, hash-complete, independently grouped resources; it does not
erase candidates or turn missing external evidence into a failure of the candidate physics.
