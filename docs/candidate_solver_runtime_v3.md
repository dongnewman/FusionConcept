# Candidate Solver Runtime v3 / full search v59

V3 is additive beside the sealed v1 and v2 runtime paths. It does not replace the
eight-stage judgment chain. It binds three new numerical products between the v2 state
solution and the existing Stage-5/6/7 inputs:

1. a declared-region and module dependency graph;
2. a regional state/source/sink and explicit actuator realization envelope; and
3. a complete-role plant-power ledger protocol.

## Capability and region composition

`compile_candidate_solve_manifest_v3` augments `CandidateSolveManifestV1` with a
`capability_dependency_graph_v1`. Every selected operator exposes its required states and
parameters, provided residual/flux/source/observable slots, Jacobian availability, SI unit
convention, and the common `dU_dt + divergence_F - source_S` sign convention. Compatibility
is checked against the candidate-declared capabilities and state layout. Family and
parent-family fields remain non-routing.

The manifest also contains `declared_region_network_v1`. Only explicitly declared plasma
regions and flux connections are included. The current state compiler supplies one global
inventory to the primary control volume. If a candidate declares more regions but supplies
no region-specific inventories and interface operators, the network is sealed as
`unknown_missing_multi_region_state_partition`. V3 does not manufacture volume fractions,
SOL widths, target areas, or end-cell inventories.

Consequently V3 is an auditable transition to region-resolved transport, not a claim that the
existing Bohm or parallel-streaming L1 operators have become geometry-resolved PDE models.

## RegionalCoupledSolveEnvelopeV1

`RegionalCoupledSolveEnvelopeV1` records:

- the capability dependency graph;
- declared region states and interface fluxes;
- source/sink demands by conserved account;
- candidate-declared actuator capacities, realized outputs, efficiencies, and hashes;
- per-iteration state-conservation and demand-realization residuals; and
- explicit unresolved reasons and an evidence ceiling.

For steady problems, actuator-independent transport/reaction/radiation source and loss terms
are recomputed at the declared state. Required sources are then allocated only to declared
actuator contracts. A damped, block-scaled fixed-point iteration feeds realized outputs back
into the conservation slots. Both the normalized conservation residual and normalized
demand-realization mismatch must satisfy the manifest tolerance.

The classifications are deliberately distinct:

- `pass`: sufficient explicit capacity, converged residuals, complete declared efficiency
  evidence, and a complete declared-region inventory partition;
- `fail`: numeric actuator capacity is below the candidate-specific demand;
- `unsupported`: a demanded conserved account has no compatible actuator module; and
- `unknown`: the numeric coupling converges but efficiency, regional partition, or evidence is
  incomplete.

The bundled positive/negative protocol fixtures demonstrate all four boundaries. They do not
add those fixture capacities to generated candidates.

## PlantPowerLedgerV1

`PlantPowerLedgerV1` aggregates only solver outputs and explicitly declared plant roles. The
role checklist includes:

- heating and current-drive wall-plug power;
- particle injection and fuel processing;
- magnet supplies;
- cryogenics;
- vacuum, exhaust, and pumping;
- coolant circulation and heat rejection;
- thermal-cycle auxiliaries;
- controls and diagnostics;
- target manufacture when explicitly applicable;
- gross electric generation; and
- direct energy recovery when explicitly declared.

Each role has `complete`, `unknown`, or `not_applicable` status, an applicability basis, source
hashes, and a component hash. No default efficiency or fixed plant fraction is supplied.

For pulsed candidates, ledger closure additionally requires pulse energy and an explicit
repetition rate so powers share a cycle-average basis. Net power is only defined when gross
electric output, all applicable recirculating roles, and the time basis are complete. A point
estimate cannot authorize a Stage-6 pass until uncertainty establishes that its sign is
robust.

## Stage-7 output roles

V3 adds explicit role slots for local target heat flux, conductor hotspot temperature, quench
voltage, structural peak stress, irradiation damage rate, component lifetime, fuel-cycle
inventory, and maintenance access margin. They remain `unknown` until finite geometry,
materials, applicable limits, faults, and independent solver outputs exist. Global magnetic
pressure or average surface heat load is retained as an input load and cannot satisfy these
local engineering roles.

## Reference slices and claim boundary

ITER remains a published design baseline and C-2W remains a published experimental parameter
range. The bundled fixtures do not declare measured fueling capacity or a capability-complete
deposition/control model. Missing actuator realization therefore remains `unsupported`, and
reduced-model mismatch remains `model_discrepancy`. Neither state is converted into failure of
the physical device or into anchor agreement.

The full v59 search runs the same chain for every candidate, recomputes one representative of
each mechanism cluster at two resolutions, evaluates both reference slices, checks deterministic
replay, and seals all raw runtime, judgment, representative, and anchor archives.
