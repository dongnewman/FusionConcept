# C2 decision runtime v1

`C2DecisionEnvelope` deliberately separates four questions:

1. `completeness`: whether every required gate has a complete, unsupported, or still-incomplete evidence state.
2. `candidate_conclusion`: `pass` or `fail` only when the required chain is complete; otherwise `unknown` or `unsupported`.
3. `narrow_failures`: candidate-bound failure facts with affected identifiers and explicitly excluded claims.
4. `terminate`: whether this candidate evaluation has reached a complete terminal decision.

An auxiliary diagnostic failure is retained in `narrow_failures`, but it does not change required-gate completeness, the candidate conclusion, or termination. Every failure declares `authoritative_for_gate` and `terminates_candidate` separately. A non-recoverable necessary-condition failure may therefore terminate a candidate while unrelated evidence remains incomplete; a local or auxiliary failure cannot do so unless that scope is explicitly authorized.

`C2CandidateStatePackageV1` has one common inventory for particle accounts, ion/electron energy accounts, species state, four actuator roles, the full power ledger, and evidence fields. Physical boundary classes and capability identifiers are package data; no candidate label controls the aggregation path.

The generated `c2_uniform_decision_panel_v1_20260824` artifact is manufactured protocol-conformance evidence. It demonstrates identical aggregation for one closed-boundary and one open-boundary packet, both ending in a complete actuator-capacity hard failure. It is not physical C2 evidence and grants no promotion credit.
