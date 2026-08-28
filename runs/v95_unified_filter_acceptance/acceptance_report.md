# v95 Unified Reference/Candidate Filter Acceptance

## Outcome

- Selector acceptance: `blocked_reference_control_false_negative`.
- Software controls: `pass`.
- Known-positive recall: 0/2 (0.0).
- Generated candidates rerun: 417; v92/v93 closure cohort: 246.
- Classification: `{"unsupported":417}`.

ITER and C-2W were executed first as `reference_control` through the same declaration compiler, v94 provider registry, graph assembler, whole-graph solver contract, numerical VVUQ, and validation VVUQ ordering used for generated candidates. Their identity and role were retained only for reporting and known-positive accounting.

## Interpretation

The selector is not accepted because both reference controls encounter missing whole-graph provider closure. This is a selector false-negative/capability gap. It is not evidence that ITER or C-2W fails physically. The 417 generated candidates, including the 246 v92/v93 realization-closure records, are currently `unsupported`; none has a candidate-bound whole-system solve from which beta, net power, stability, or wall load can be derived. Therefore the historical v91 basis-derived proxy survivors receive no v95 promotion credit.

No physical device passed the complete solve -> numerical VVUQ -> validation VVUQ chain. Numerical verification, experimental validation, unsupported capability, unknown evidence, and physical failure remain independent. No device-feasibility claim is made.

## Preserved inputs

The acceptance hashed the sealed reference fixture and the authoritative v91-v94 candidate/acceptance inputs before and after execution. Existing candidate-data writes: 0.

Acceptance hash: `a5c7f57e659e7c3f5cbcda6a08244c59447267c2bc6750b528b2e191e7e01c7e`.
