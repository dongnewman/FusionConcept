# v104 whole-device provider preflight

ITER/C-2W mission-aware reference regression: 2/2 pass; bypass=0.

The sole v100 qualification-incomplete survivor was preflighted before any new
high-cost search. Only 2/9
whole-device obligations are closed, so whole-device search is not authorized.
The candidate is `not_adjudicated_provider_gap`: it is neither unsupported,
physically rejected, physically passed, nor validated.

| Obligation | Preflight status | Best available | Required |
|---|---|---|---|
| complete_stability | insufficient_evidence_level | sampled_candidate_bound | complete_candidate_bound |
| transport_and_confinement | insufficient_evidence_level | reduced_candidate_bound | complete_candidate_bound |
| particle_and_heat_exhaust | insufficient_evidence_level | reduced_candidate_bound | complete_candidate_bound |
| complete_engineering_and_materials | insufficient_evidence_level | sampled_candidate_bound | complete_candidate_bound |
| dynamic_control_and_fault_response | insufficient_evidence_level | sampled_candidate_bound | complete_candidate_bound |
| numerical_vvuq | insufficient_evidence_level | sampled_candidate_bound | complete_candidate_bound |
| validation_vvuq | missing_provider | none | independent_validation |

The next generator revision must create candidate-bound edge/divertor, material,
blanket/shield, finite-conductor, coolant/thermal-cycle, fuel-cycle, quench/fault,
controller/diagnostic and validation-observable inputs. Existing reduced or static
outputs cannot be relabelled as complete evidence.

Acceptance hash: `d2ab4d0e3cc4a0ba8ab2744ceaa95a128bf33e842b4b33049ded51b589564ed6`

v104 is a fail-closed campaign preflight. It does not promote, reject, or classify a candidate when a required whole-device provider or candidate-bound input is absent. Such a campaign is not executed; the candidate remains not_adjudicated_provider_gap, never unsupported and never a physical pass or failure. Existing reduced or sampled evidence cannot satisfy a complete whole-device obligation.
