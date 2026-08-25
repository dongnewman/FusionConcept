const _C2_COMPLETENESS_V1 = Set((:complete, :incomplete, :unsupported))
const _C2_CONCLUSIONS_V1 = Set((:pass, :fail, :unknown, :unsupported))
const _C2_EVIDENCE_STATES_V1 = Set((:complete, :partial, :unknown, :unsupported,
    :fail, :not_applicable))
const _C2_REQUIRED_POWER_ACCOUNTS_V1 = Set((
    "reaction_power", "self_heating_power", "radiation_loss_power",
    "actuator_delivered_power", "wall_input_power", "gross_electric_power",
    "net_electric_lower_bound"))
const _C2_REQUIRED_EVIDENCE_FIELDS_V1 = Set((
    "state_solution", "residual_convergence", "conservation",
    "interface_flux", "actuator_fulfillment", "physical_bounds",
    "validity_domain", "resolution_trend", "jacobian_audit",
    "independent_residual_audit", "stability", "engineering"))
const _C2_ACTUATOR_ROLES_V1 = Set((:fueling, :heating, :exhaust,
    :radiation_control))
const _C2_BOUND_EVIDENCE_GATE_IDS_V1 = Set(("engineering", "independent_evidence"))

struct C2QuantityFieldV1
    field_id::String
    value::Union{Nothing,Float64}
    unit::String
    evidence_hash::String
    field_hash::String
end

struct C2SpeciesStateV1
    species_id::String
    inventory::Union{Nothing,Float64}
    inventory_unit::String
    charge_number::Union{Nothing,Float64}
    evidence_hash::String
    state_hash::String
end

struct C2ActuatorStateV1
    actuator_id::String
    role::Symbol
    demand::Union{Nothing,Float64}
    output::Union{Nothing,Float64}
    capacity::Union{Nothing,Float64}
    output_unit::String
    wall_plug_efficiency::Union{Nothing,Float64}
    evidence_hash::String
    state_hash::String
end

struct C2PowerLedgerV1
    accounts::Vector{C2QuantityFieldV1}
    balance_residual_w::Union{Nothing,Float64}
    evidence_hash::String
    ledger_hash::String
end

struct C2EvidenceFieldV1
    field_id::String
    status::Symbol
    source_result_hash::String
    claim_boundary::String
    evidence_hash::String
end

"A label-free state/evidence packet shared by every boundary capability."
struct C2CandidateStatePackageV1
    schema_version::String
    candidate_binding_hash::String
    state_result_hash::String
    time_mode::Symbol
    boundary_classes::Vector{String}
    capability_ids::Vector{String}
    region_ids::Vector{String}
    particle_accounts::Vector{C2QuantityFieldV1}
    energy_accounts::Vector{C2QuantityFieldV1}
    species_states::Vector{C2SpeciesStateV1}
    actuator_states::Vector{C2ActuatorStateV1}
    power_ledger::C2PowerLedgerV1
    evidence_fields::Vector{C2EvidenceFieldV1}
    package_hash::String
end

struct C2NarrowFailureV1
    failure_id::String
    gate_id::String
    failure_code::String
    scope_kind::Symbol
    affected_ids::Vector{String}
    excluded_claims::Vector{String}
    authoritative_for_gate::Bool
    terminates_candidate::Bool
    source_result_hash::String
    failure_hash::String
end

struct C2GateDecisionV1
    gate_id::String
    required::Bool
    completeness::Symbol
    conclusion::Symbol
    narrow_failures::Vector{C2NarrowFailureV1}
    evidence_hashes::Vector{String}
    evidence_tasks::Vector{String}
    gate_hash::String
end

"Candidate- and solved-state-bound evidence for post-physics C2 gates."
struct C2BoundGateEvidenceV1
    schema_version::String
    candidate_binding_hash::String
    state_result_hash::String
    gate_id::String
    status::Symbol
    obligation_ids::Vector{String}
    failed_obligation_ids::Vector{String}
    evidence_hashes::Vector{String}
    evidence_tasks::Vector{String}
    terminates_candidate::Bool
    claim_boundary::String
    evidence_bundle_hash::String
end

"A candidate- and solved-state-bound uncertainty interval; sign interpretation is downstream."
struct C2UncertaintyIntervalEvidenceV1
    schema_version::String
    candidate_binding_hash::String
    state_result_hash::String
    quantity_id::String
    lower::Float64
    upper::Float64
    unit::String
    coverage_probability::Float64
    method::String
    source_result_hash::String
    interval_hash::String
end

"C2 aggregation with orthogonal completion, conclusion, scope and stop fields."
struct C2DecisionEnvelope
    schema_version::String
    candidate_binding_hash::String
    state_package_hash::String
    completeness::Symbol
    candidate_conclusion::Symbol
    narrow_failures::Vector{C2NarrowFailureV1}
    terminate::Bool
    termination_scope::Symbol
    termination_reason::String
    required_gate_ids::Vector{String}
    complete_gate_ids::Vector{String}
    incomplete_gate_ids::Vector{String}
    unsupported_gate_ids::Vector{String}
    failed_gate_ids::Vector{String}
    gate_decisions::Vector{C2GateDecisionV1}
    decision_hash::String
end

function _c2_check_hash_v1(value::AbstractString, label::AbstractString)
    occursin(r"^[0-9a-f]{64}$", String(value)) || throw(ArgumentError(
        "$label must be a lowercase sha256 hex digest"))
    return String(value)
end

function compile_c2_quantity_field_v1(field_id::AbstractString,
        value::Union{Nothing,Real},
        unit::AbstractString, evidence_hash::AbstractString)
    isempty(field_id) && throw(ArgumentError("quantity field id cannot be empty"))
    number = value === nothing ? nothing : Float64(value)
    number === nothing || isfinite(number) || throw(ArgumentError(
        "quantity value must be finite when present"))
    isempty(unit) && throw(ArgumentError("quantity unit cannot be empty"))
    evidence = _c2_check_hash_v1(evidence_hash, "quantity evidence hash")
    core = Dict{String,Any}("field_id" => String(field_id), "value" => number,
        "unit" => String(unit), "evidence_hash" => evidence)
    return C2QuantityFieldV1(String(field_id), number, String(unit), evidence,
        canonical_hash(core))
end

function compile_c2_species_state_v1(species_id::AbstractString,
        inventory::Union{Nothing,Real}, inventory_unit::AbstractString,
        charge_number::Union{Nothing,Real},
        evidence_hash::AbstractString)
    isempty(species_id) && throw(ArgumentError("species id cannot be empty"))
    amount = inventory === nothing ? nothing : Float64(inventory)
    charge = charge_number === nothing ? nothing : Float64(charge_number)
    amount === nothing || isfinite(amount) && amount >= 0 || throw(ArgumentError(
        "species inventory must be finite and nonnegative when present"))
    charge === nothing || isfinite(charge) || throw(ArgumentError(
        "species charge must be finite when present"))
    isempty(inventory_unit) && throw(ArgumentError("species inventory unit cannot be empty"))
    evidence = _c2_check_hash_v1(evidence_hash, "species evidence hash")
    core = Dict{String,Any}("species_id" => String(species_id), "inventory" => amount,
        "inventory_unit" => String(inventory_unit), "charge_number" => charge,
        "evidence_hash" => evidence)
    return C2SpeciesStateV1(String(species_id), amount, String(inventory_unit), charge,
        evidence, canonical_hash(core))
end

function compile_c2_actuator_state_v1(actuator_id::AbstractString, role::Symbol;
        demand::Union{Nothing,Real}, output::Union{Nothing,Real},
        capacity::Union{Nothing,Real}, output_unit::AbstractString,
        wall_plug_efficiency::Union{Nothing,Real}, evidence_hash::AbstractString)
    isempty(actuator_id) && throw(ArgumentError("actuator id cannot be empty"))
    role in _C2_ACTUATOR_ROLES_V1 || throw(ArgumentError("unsupported actuator role"))
    convert_optional(value) = value === nothing ? nothing : Float64(value)
    demand_value, output_value, capacity_value = convert_optional(demand),
        convert_optional(output), convert_optional(capacity)
    all(value -> value === nothing || isfinite(value) && value >= 0,
        (demand_value, output_value, capacity_value)) || throw(ArgumentError(
        "actuator demand, output and capacity must be finite and nonnegative when present"))
    output_value === nothing || capacity_value === nothing ||
        output_value <= capacity_value || throw(ArgumentError(
            "actuator output cannot exceed declared capacity"))
    efficiency = convert_optional(wall_plug_efficiency)
    efficiency === nothing || isfinite(efficiency) && 0 < efficiency <= 1 ||
        throw(ArgumentError("wall-plug efficiency must lie in (0, 1] when present"))
    isempty(output_unit) && throw(ArgumentError("actuator output unit cannot be empty"))
    evidence = _c2_check_hash_v1(evidence_hash, "actuator evidence hash")
    core = Dict{String,Any}("actuator_id" => String(actuator_id), "role" => String(role),
        "demand" => demand_value, "output" => output_value, "capacity" => capacity_value,
        "output_unit" => String(output_unit), "wall_plug_efficiency" => efficiency,
        "evidence_hash" => evidence)
    return C2ActuatorStateV1(String(actuator_id), role, demand_value, output_value,
        capacity_value, String(output_unit), efficiency, evidence, canonical_hash(core))
end

function compile_c2_power_ledger_v1(accounts::Vector{C2QuantityFieldV1};
        balance_residual_w::Union{Nothing,Real}, evidence_hash::AbstractString)
    ids = getfield.(accounts, :field_id)
    length(unique(ids)) == length(ids) || throw(ArgumentError("duplicate power account id"))
    missing = setdiff(_C2_REQUIRED_POWER_ACCOUNTS_V1, Set(ids))
    isempty(missing) || throw(ArgumentError("missing required power accounts: $(join(sort!(collect(missing)), ", "))"))
    residual = balance_residual_w === nothing ? nothing : Float64(balance_residual_w)
    residual === nothing || isfinite(residual) || throw(ArgumentError(
        "power balance residual must be finite when present"))
    evidence = _c2_check_hash_v1(evidence_hash, "power-ledger evidence hash")
    ordered = sort!(copy(accounts); by = item -> item.field_id)
    core = Dict{String,Any}("account_hashes" => getfield.(ordered, :field_hash),
        "balance_residual_w" => residual, "evidence_hash" => evidence)
    return C2PowerLedgerV1(ordered, residual, evidence, canonical_hash(core))
end

function compile_c2_evidence_field_v1(field_id::AbstractString, status::Symbol,
        source_result_hash::AbstractString, claim_boundary::AbstractString)
    status in _C2_EVIDENCE_STATES_V1 || throw(ArgumentError("invalid evidence status"))
    isempty(field_id) && throw(ArgumentError("evidence field id cannot be empty"))
    source_hash = _c2_check_hash_v1(source_result_hash, "evidence source result hash")
    isempty(claim_boundary) && throw(ArgumentError("evidence claim boundary cannot be empty"))
    core = Dict{String,Any}("field_id" => String(field_id), "status" => String(status),
        "source_result_hash" => source_hash, "claim_boundary" => String(claim_boundary))
    return C2EvidenceFieldV1(String(field_id), status, source_hash,
        String(claim_boundary), canonical_hash(core))
end

function compile_c2_candidate_state_package_v1(; candidate_binding_hash::AbstractString,
        state_result_hash::AbstractString, time_mode::Symbol,
        boundary_classes::Vector{String}, capability_ids::Vector{String},
        region_ids::Vector{String}, particle_accounts::Vector{C2QuantityFieldV1},
        energy_accounts::Vector{C2QuantityFieldV1},
        species_states::Vector{C2SpeciesStateV1},
        actuator_states::Vector{C2ActuatorStateV1}, power_ledger::C2PowerLedgerV1,
        evidence_fields::Vector{C2EvidenceFieldV1})
    binding = _c2_check_hash_v1(candidate_binding_hash, "candidate binding hash")
    state_hash = _c2_check_hash_v1(state_result_hash, "state result hash")
    time_mode in (:steady, :transient, :dae) || throw(ArgumentError("invalid time mode"))
    isempty(boundary_classes) && throw(ArgumentError("boundary classes cannot be empty"))
    isempty(capability_ids) && throw(ArgumentError("capability ids cannot be empty"))
    isempty(region_ids) && throw(ArgumentError("region ids cannot be empty"))
    isempty(particle_accounts) && throw(ArgumentError("particle accounts cannot be empty"))
    isempty(energy_accounts) && throw(ArgumentError("energy accounts cannot be empty"))
    isempty(species_states) && throw(ArgumentError("species states cannot be empty"))
    roles = Set(getfield.(actuator_states, :role))
    roles == _C2_ACTUATOR_ROLES_V1 || throw(ArgumentError(
        "actuator states must cover fueling, heating, exhaust and radiation control"))
    for records in (particle_accounts, energy_accounts)
        ids = getfield.(records, :field_id)
        length(unique(ids)) == length(ids) || throw(ArgumentError("duplicate account id"))
    end
    species_ids = getfield.(species_states, :species_id)
    length(unique(species_ids)) == length(species_ids) || throw(ArgumentError(
        "duplicate species id"))
    actuator_ids = getfield.(actuator_states, :actuator_id)
    length(unique(actuator_ids)) == length(actuator_ids) || throw(ArgumentError(
        "duplicate actuator id"))
    evidence_ids = getfield.(evidence_fields, :field_id)
    length(unique(evidence_ids)) == length(evidence_ids) || throw(ArgumentError(
        "duplicate evidence field id"))
    missing_evidence = setdiff(_C2_REQUIRED_EVIDENCE_FIELDS_V1, Set(evidence_ids))
    isempty(missing_evidence) || throw(ArgumentError(
        "missing required evidence fields: $(join(sort!(collect(missing_evidence)), ", "))"))
    boundaries = sort!(unique(copy(boundary_classes)))
    capabilities = sort!(unique(copy(capability_ids)))
    regions = sort!(unique(copy(region_ids)))
    particles = sort!(copy(particle_accounts); by = item -> item.field_id)
    energies = sort!(copy(energy_accounts); by = item -> item.field_id)
    species = sort!(copy(species_states); by = item -> item.species_id)
    actuators = sort!(copy(actuator_states); by = item -> item.actuator_id)
    evidence = sort!(copy(evidence_fields); by = item -> item.field_id)
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => binding, "state_result_hash" => state_hash,
        "time_mode" => String(time_mode), "boundary_classes" => boundaries,
        "capability_ids" => capabilities, "region_ids" => regions,
        "particle_account_hashes" => getfield.(particles, :field_hash),
        "energy_account_hashes" => getfield.(energies, :field_hash),
        "species_state_hashes" => getfield.(species, :state_hash),
        "actuator_state_hashes" => getfield.(actuators, :state_hash),
        "power_ledger_hash" => power_ledger.ledger_hash,
        "evidence_hashes" => getfield.(evidence, :evidence_hash))
    return C2CandidateStatePackageV1("1.0.0", binding, state_hash, time_mode,
        boundaries, capabilities, regions, particles, energies, species, actuators,
        power_ledger, evidence, canonical_hash(core))
end

function _c2_v68_unique_observable_v1(result::NonlinearSolveResultEnvelopeV1,
        semantic_key::String)
    records = Dict{String,Any}[]
    for value in values(result.observables)
        value isa AbstractDict && haskey(value, semantic_key) || continue
        push!(records, Dict{String,Any}(String(key) => item for (key, item) in value))
    end
    length(records) <= 1 || throw(ArgumentError(
        "v68 result has competing observable providers for $semantic_key"))
    return isempty(records) ? Dict{String,Any}() : only(records)
end

function _c2_v68_audit_status_v1(value; not_applicable = false)
    status = lowercase(String(value))
    status == "pass" && return :complete
    status == "fail" && return :fail
    not_applicable && status == "not_applicable" && return :not_applicable
    return :unknown
end

"Convert a sealed v68 result into the same label-free C2 state packet for every boundary."
function compile_c2_candidate_state_package_from_v68_v1(
        manifest::CandidateSolveManifestV1, result::NonlinearSolveResultEnvelopeV1)
    manifest.candidate_id == result.candidate_id || throw(ArgumentError(
        "v68 C2 bridge candidate id mismatch"))
    manifest.physics_hash == result.physics_hash || throw(ArgumentError(
        "v68 C2 bridge candidate binding mismatch"))
    manifest.manifest_hash == result.manifest_hash || throw(ArgumentError(
        "v68 C2 bridge manifest hash mismatch"))
    source_hash = result.result_hash
    final = result.final_state
    quantity(id, value, unit) = compile_c2_quantity_field_v1(id, value, unit, source_hash)
    value(id) = haskey(final, id) ? final[id] : nothing
    fuel_a, fuel_b, electrons = value("fuel_a_inventory"),
        value("fuel_b_inventory"), value("electron_inventory")
    total_fuel = fuel_a isa Real && fuel_b isa Real ? fuel_a + fuel_b : nothing
    particles = C2QuantityFieldV1[
        quantity("fuel_particle_inventory", total_fuel, "particle"),
        quantity("electron_inventory", electrons, "particle")]
    energies = C2QuantityFieldV1[
        quantity("ion_thermal_energy", value("ion_thermal_energy"), "J"),
        quantity("electron_thermal_energy", value("electron_thermal_energy"), "J")]

    core = _c2_v68_unique_observable_v1(result, "species_states")
    species = C2SpeciesStateV1[]
    for item_any in get(core, "species_states", Any[])
        item = Dict{String,Any}(String(key) => entry for (key, entry) in pairs(item_any))
        push!(species, compile_c2_species_state_v1(String(item["species_id"]),
            get(item, "inventory", nothing), String(get(item, "inventory_unit", "particle")),
            get(item, "charge_number", nothing), source_hash))
    end
    isempty(species) && push!(species, compile_c2_species_state_v1(
        "fuel_species_group", nothing, "particle", nothing, source_hash))

    actuators = C2ActuatorStateV1[]
    for item_any in get(core, "actuator_states", Any[])
        item = Dict{String,Any}(String(key) => entry for (key, entry) in pairs(item_any))
        push!(actuators, compile_c2_actuator_state_v1(String(item["actuator_id"]),
            Symbol(item["role"]); demand = get(item, "demand", nothing),
            output = get(item, "output", nothing), capacity = get(item, "capacity", nothing),
            output_unit = String(item["output_unit"]),
            wall_plug_efficiency = get(item, "wall_plug_efficiency", nothing),
            evidence_hash = source_hash))
    end
    present_roles = Set(getfield.(actuators, :role))
    placeholder_units = Dict(:fueling => "particle/s", :heating => "W",
        :exhaust => "particle/s", :radiation_control => "W")
    for role in sort!(collect(setdiff(_C2_ACTUATOR_ROLES_V1, present_roles)); by = String)
        push!(actuators, compile_c2_actuator_state_v1("$(role)_actuator", role;
            demand = nothing, output = nothing, capacity = nothing,
            output_unit = placeholder_units[role], wall_plug_efficiency = nothing,
            evidence_hash = source_hash))
    end

    ledger_any = get(result.observables, "candidate_power_ledger", Dict{String,Any}())
    ledger = Dict{String,Any}(String(key) => entry for (key, entry) in pairs(ledger_any))
    terms_any = get(ledger, "terms", Dict{String,Any}())
    terms = Dict{String,Any}(String(key) => entry for (key, entry) in pairs(terms_any))
    actuator_delivered = sum(Float64(item.output) for item in actuators
        if item.role == :heating && item.output_unit == "W" && item.output isa Real;
        init = 0.0)
    power_accounts = C2QuantityFieldV1[
        quantity("reaction_power", get(terms, "total_fusion_power_w", nothing), "W"),
        quantity("self_heating_power", get(terms, "charged_fusion_power_w", nothing), "W"),
        quantity("radiation_loss_power", get(terms, "radiation_power_w", nothing), "W"),
        quantity("actuator_delivered_power", isempty(actuators) ? nothing :
            actuator_delivered, "W"),
        quantity("wall_input_power", get(terms, "total_wall_input_power_w", nothing), "W"),
        quantity("gross_electric_power", get(terms, "gross_electric_power_w", nothing), "W"),
        quantity("net_electric_lower_bound",
            get(terms, "net_electric_lower_bound_w", nothing), "W")]
    slots = get(result.audits, "conservation_slots", Any[])
    energy_residuals = Float64[get(item, "residual", 0.0) for item in slots
        if String(get(item, "state_id", "")) in
            ("ion_thermal_energy", "electron_thermal_energy")]
    balance_residual = length(energy_residuals) == 2 ? sum(energy_residuals) : nothing
    power = compile_c2_power_ledger_v1(power_accounts;
        balance_residual_w = balance_residual, evidence_hash = source_hash)

    all_state_present = all(id -> haskey(final, id), ("fuel_a_inventory",
        "fuel_b_inventory", "electron_inventory", "ion_thermal_energy",
        "electron_thermal_energy"))
    block_status = get(result.audits, "all_residual_blocks", "unknown")
    interface = get(result.audits, "interface_flux_pair_closure", Dict{String,Any}())
    resolution = get(result.audits, "resolution_trend", Dict{String,Any}())
    jacobians = get(result.audits, "jacobian_directional_audits", Any[])
    ledger_status = String(get(ledger, "status", "unknown"))
    actuator_complete = !isempty(get(core, "actuator_states", Any[]))
    evidence_status = Dict{String,Symbol}(
        "state_solution" => all_state_present ? :complete : :unknown,
        "residual_convergence" => _c2_v68_audit_status_v1(block_status),
        "conservation" => block_status == "pass" && ledger_status == "complete" ?
            :complete : block_status == "fail" ? :fail : :unknown,
        "interface_flux" => _c2_v68_audit_status_v1(get(interface, "status", "unknown")),
        "actuator_fulfillment" => result.classification_code ==
            "fail_actuator_capacity_shortfall" ? :fail : actuator_complete ? :complete : :unknown,
        "physical_bounds" => _c2_v68_audit_status_v1(
            get(result.audits, "physical_state_bounds", "unknown")),
        "validity_domain" => isempty(result.audits) ? :unknown : :complete,
        "resolution_trend" => _c2_v68_audit_status_v1(
            get(resolution, "status", "unknown"); not_applicable = true),
        "jacobian_audit" => isempty(jacobians) ? :unknown :
            all(item -> get(item, "status", "unknown") == "pass", jacobians) ?
                :complete : :fail,
        "independent_residual_audit" => _c2_v68_audit_status_v1(
            get(result.audits, "independent_residual_recalculation", "unknown")),
        "stability" => :unknown, "engineering" => :unknown)
    evidence = C2EvidenceFieldV1[compile_c2_evidence_field_v1(id, status,
        source_hash, "Candidate-bound v68 result; no family or device-name routing.")
        for (id, status) in sort!(collect(evidence_status); by = first)]

    boundary_classes = String[]
    for boundary in manifest.boundaries
        for key in ("boundary_class", "flux_semantics", "type")
            haskey(boundary, key) && push!(boundary_classes, String(boundary[key]))
        end
    end
    for observable in values(result.observables)
        observable isa AbstractDict && haskey(observable, "flux_semantics") &&
            push!(boundary_classes, String(observable["flux_semantics"]))
    end
    isempty(boundary_classes) && push!(boundary_classes, "control_volume_boundary")
    capabilities = String["v68_coupled_residual_runtime"]
    for declaration in manifest.capability_declarations
        haskey(declaration, "capability_id") &&
            push!(capabilities, String(declaration["capability_id"]))
    end
    region_ids = String[String(get(region, "region_id", get(region, "id", "")))
        for region in manifest.regions]
    filter!(!isempty, region_ids)
    time_mode = result.classification_code == "unknown_no_steady_state_transient_complete" ?
        :dae : manifest.time_mode == "steady" ? :steady : :transient
    return compile_c2_candidate_state_package_v1(
        candidate_binding_hash = manifest.physics_hash, state_result_hash = source_hash,
        time_mode = time_mode, boundary_classes = boundary_classes,
        capability_ids = capabilities, region_ids = region_ids,
        particle_accounts = particles, energy_accounts = energies,
        species_states = species, actuator_states = actuators,
        power_ledger = power, evidence_fields = evidence)
end

"Build the Stage-3 gate from v68 evidence while keeping numerical gaps non-falsifying."
function c2_gate_from_v68_result_v1(state::C2CandidateStatePackageV1,
        result::NonlinearSolveResultEnvelopeV1;
        gate_id::AbstractString = "stage_3_residual", required::Bool = true)
    state.candidate_binding_hash == result.physics_hash || throw(ArgumentError(
        "v68 C2 gate candidate binding mismatch"))
    residual_field_ids = setdiff(_C2_REQUIRED_EVIDENCE_FIELDS_V1,
        Set(("stability", "engineering")))
    by_id = Dict(item.field_id => item.status for item in state.evidence_fields)
    statuses = Symbol[get(by_id, id, :unknown) for id in residual_field_ids]
    unsupported = result.status == :unsupported || any(==(:unsupported), statuses)
    physical_fail = result.classification_code == "fail_actuator_capacity_shortfall"
    complete = !unsupported && all(status -> status in (:complete, :not_applicable, :fail),
        statuses)
    completeness = unsupported ? :unsupported : complete ? :complete : :incomplete
    conclusion = unsupported ? :unsupported : physical_fail ? :fail :
        complete && result.status == :pass ? :pass : :unknown
    failures = C2NarrowFailureV1[]
    if conclusion == :fail
        push!(failures, compile_c2_narrow_failure_v1(
            "$(gate_id):actuator_capacity", String(gate_id),
            "fail_actuator_capacity_shortfall", :actuator;
            affected_ids = ["actuator_fulfillment"],
            excluded_claims = ["stability", "engineering", "independent_evidence"],
            authoritative_for_gate = true, terminates_candidate = false,
            source_result_hash = result.result_hash))
    end
    tasks = String[]
    for id in sort!(collect(residual_field_ids))
        get(by_id, id, :unknown) in (:complete, :not_applicable, :fail) ||
            push!(tasks, "complete_candidate_bound_v68_field:$id")
    end
    return compile_c2_gate_decision_v1(gate_id; required = required,
        completeness = completeness, conclusion = conclusion,
        narrow_failures = failures, evidence_hashes = [result.result_hash],
        evidence_tasks = tasks)
end

function compile_c2_narrow_failure_v1(failure_id::AbstractString,
        gate_id::AbstractString, failure_code::AbstractString, scope_kind::Symbol;
        affected_ids::Vector{String}, excluded_claims::Vector{String},
        authoritative_for_gate::Bool, terminates_candidate::Bool,
        source_result_hash::AbstractString)
    all(!isempty, (failure_id, gate_id, failure_code)) || throw(ArgumentError(
        "failure id, gate id and failure code cannot be empty"))
    isempty(affected_ids) && throw(ArgumentError("narrow failure must identify affected scope"))
    source_hash = _c2_check_hash_v1(source_result_hash, "failure source result hash")
    affected = sort!(unique(copy(affected_ids)))
    excluded = sort!(unique(copy(excluded_claims)))
    core = Dict{String,Any}("failure_id" => String(failure_id),
        "gate_id" => String(gate_id), "failure_code" => String(failure_code),
        "scope_kind" => String(scope_kind), "affected_ids" => affected,
        "excluded_claims" => excluded,
        "authoritative_for_gate" => authoritative_for_gate,
        "terminates_candidate" => terminates_candidate,
        "source_result_hash" => source_hash)
    return C2NarrowFailureV1(String(failure_id), String(gate_id), String(failure_code),
        scope_kind, affected, excluded, authoritative_for_gate, terminates_candidate,
        source_hash,
        canonical_hash(core))
end

function compile_c2_gate_decision_v1(gate_id::AbstractString; required::Bool,
        completeness::Symbol, conclusion::Symbol,
        narrow_failures::Vector{C2NarrowFailureV1} = C2NarrowFailureV1[],
        evidence_hashes::Vector{String} = String[], evidence_tasks::Vector{String} = String[])
    isempty(gate_id) && throw(ArgumentError("gate id cannot be empty"))
    completeness in _C2_COMPLETENESS_V1 || throw(ArgumentError("invalid gate completeness"))
    conclusion in _C2_CONCLUSIONS_V1 || throw(ArgumentError("invalid gate conclusion"))
    completeness == :complete && !(conclusion in (:pass, :fail)) && throw(ArgumentError(
        "complete gate must conclude pass or fail"))
    completeness == :unsupported && conclusion != :unsupported && throw(ArgumentError(
        "unsupported gate must conclude unsupported"))
    conclusion == :fail && isempty(narrow_failures) && throw(ArgumentError(
        "failed gate must carry at least one narrow failure"))
    all(item -> item.gate_id == gate_id, narrow_failures) || throw(ArgumentError(
        "narrow failure gate mismatch"))
    hashes = sort!(unique(_c2_check_hash_v1(hash, "gate evidence hash")
        for hash in evidence_hashes))
    failures = sort!(copy(narrow_failures); by = item -> item.failure_hash)
    tasks = sort!(unique(copy(evidence_tasks)))
    core = Dict{String,Any}("gate_id" => String(gate_id), "required" => required,
        "completeness" => String(completeness), "conclusion" => String(conclusion),
        "failure_hashes" => getfield.(failures, :failure_hash),
        "evidence_hashes" => hashes, "evidence_tasks" => tasks)
    return C2GateDecisionV1(String(gate_id), required, completeness, conclusion,
        failures, hashes, tasks, canonical_hash(core))
end

function compile_c2_bound_gate_evidence_v1(; candidate_binding_hash::AbstractString,
        state_result_hash::AbstractString, gate_id::AbstractString, status::Symbol,
        obligation_ids::Vector{String}, failed_obligation_ids::Vector{String} = String[],
        evidence_hashes::Vector{String}, evidence_tasks::Vector{String} = String[],
        terminates_candidate::Bool = false,
        claim_boundary::AbstractString)
    binding = _c2_check_hash_v1(candidate_binding_hash, "candidate binding hash")
    state_hash = _c2_check_hash_v1(state_result_hash, "state result hash")
    id = String(gate_id)
    id in _C2_BOUND_EVIDENCE_GATE_IDS_V1 || throw(ArgumentError(
        "bound C2 evidence only supports engineering and independent_evidence gates"))
    status in (:pass, :fail, :unknown, :unsupported) || throw(ArgumentError(
        "invalid bound C2 evidence status"))
    obligations = sort!(unique(copy(obligation_ids)))
    isempty(obligations) && throw(ArgumentError("bound C2 evidence must declare obligations"))
    failed = sort!(unique(copy(failed_obligation_ids)))
    isempty(setdiff(failed, obligations)) || throw(ArgumentError(
        "failed obligations must be declared obligations"))
    status == :fail && isempty(failed) && throw(ArgumentError(
        "failed bound C2 evidence must identify a narrow failed obligation"))
    status != :fail && !isempty(failed) && throw(ArgumentError(
        "only failed bound C2 evidence may declare failed obligations"))
    terminates_candidate && status != :fail && throw(ArgumentError(
        "only failed bound C2 evidence may terminate a candidate"))
    hashes = sort!(unique(_c2_check_hash_v1(hash, "bound evidence hash")
        for hash in evidence_hashes))
    status in (:pass, :fail) && isempty(hashes) && throw(ArgumentError(
        "complete bound C2 evidence requires source hashes"))
    tasks = sort!(unique(copy(evidence_tasks)))
    status in (:unknown, :unsupported) && isempty(tasks) && throw(ArgumentError(
        "incomplete bound C2 evidence requires evidence tasks"))
    boundary = String(claim_boundary)
    isempty(boundary) && throw(ArgumentError("bound C2 evidence claim boundary is required"))
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => binding, "state_result_hash" => state_hash,
        "gate_id" => id, "status" => String(status),
        "obligation_ids" => obligations, "failed_obligation_ids" => failed,
        "evidence_hashes" => hashes, "evidence_tasks" => tasks,
        "terminates_candidate" => terminates_candidate,
        "claim_boundary" => boundary)
    return C2BoundGateEvidenceV1("1.0.0", binding, state_hash, id, status,
        obligations, failed, hashes, tasks, terminates_candidate, boundary,
        canonical_hash(core))
end

function compile_c2_uncertainty_interval_evidence_v1(;
        candidate_binding_hash::AbstractString, state_result_hash::AbstractString,
        quantity_id::AbstractString, lower::Real, upper::Real, unit::AbstractString,
        coverage_probability::Real, method::AbstractString,
        source_result_hash::AbstractString)
    binding = _c2_check_hash_v1(candidate_binding_hash, "candidate binding hash")
    state_hash = _c2_check_hash_v1(state_result_hash, "state result hash")
    lo, hi = Float64(lower), Float64(upper)
    all(isfinite, (lo, hi)) && lo <= hi || throw(ArgumentError(
        "uncertainty interval bounds must be finite and ordered"))
    coverage = Float64(coverage_probability)
    0.0 < coverage < 1.0 || throw(ArgumentError(
        "uncertainty coverage probability must lie strictly between zero and one"))
    quantity, units, method_id = String(quantity_id), String(unit), String(method)
    all(!isempty, (quantity, units, method_id)) || throw(ArgumentError(
        "uncertainty quantity, unit and method are required"))
    source_hash = _c2_check_hash_v1(source_result_hash,
        "uncertainty source result hash")
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => binding, "state_result_hash" => state_hash,
        "quantity_id" => quantity, "lower" => lo, "upper" => hi,
        "unit" => units, "coverage_probability" => coverage,
        "method" => method_id, "source_result_hash" => source_hash)
    return C2UncertaintyIntervalEvidenceV1("1.0.0", binding, state_hash,
        quantity, lo, hi, units, coverage, method_id, source_hash,
        canonical_hash(core))
end

function c2_uncertainty_interval_evidence_to_dict_v1(
        item::C2UncertaintyIntervalEvidenceV1)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "candidate_binding_hash" => item.candidate_binding_hash,
        "state_result_hash" => item.state_result_hash,
        "quantity_id" => item.quantity_id, "lower" => item.lower,
        "upper" => item.upper, "unit" => item.unit,
        "coverage_probability" => item.coverage_probability,
        "method" => item.method, "source_result_hash" => item.source_result_hash,
        "interval_hash" => item.interval_hash)
end

function c2_bound_gate_evidence_to_dict_v1(item::C2BoundGateEvidenceV1)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "candidate_binding_hash" => item.candidate_binding_hash,
        "state_result_hash" => item.state_result_hash, "gate_id" => item.gate_id,
        "status" => String(item.status), "obligation_ids" => item.obligation_ids,
        "failed_obligation_ids" => item.failed_obligation_ids,
        "evidence_hashes" => item.evidence_hashes,
        "evidence_tasks" => item.evidence_tasks,
        "terminates_candidate" => item.terminates_candidate,
        "claim_boundary" => item.claim_boundary,
        "evidence_bundle_hash" => item.evidence_bundle_hash)
end

function c2_gate_from_bound_evidence_v1(state::C2CandidateStatePackageV1,
        evidence::C2BoundGateEvidenceV1; required::Bool = true)
    evidence.candidate_binding_hash == state.candidate_binding_hash ||
        throw(ArgumentError("bound C2 gate candidate binding mismatch"))
    evidence.state_result_hash == state.state_result_hash ||
        throw(ArgumentError("bound C2 gate state result mismatch"))
    completeness = evidence.status == :unsupported ? :unsupported :
        evidence.status in (:pass, :fail) ? :complete : :incomplete
    conclusion = evidence.status
    failures = C2NarrowFailureV1[]
    for obligation in evidence.failed_obligation_ids
        push!(failures, compile_c2_narrow_failure_v1(
            "$(evidence.gate_id):$obligation", evidence.gate_id,
            "fail_$(evidence.gate_id)_obligation", :evidence_obligation;
            affected_ids = [obligation],
            excluded_claims = setdiff(evidence.obligation_ids, [obligation]),
            authoritative_for_gate = true,
            terminates_candidate = evidence.terminates_candidate,
            source_result_hash = evidence.evidence_bundle_hash))
    end
    return compile_c2_gate_decision_v1(evidence.gate_id; required = required,
        completeness = completeness, conclusion = conclusion,
        narrow_failures = failures,
        evidence_hashes = vcat(evidence.evidence_hashes,
            [evidence.evidence_bundle_hash]), evidence_tasks = evidence.evidence_tasks)
end

function compile_c2_engineering_evidence_v1(state::C2CandidateStatePackageV1,
        result::EngineeringMultiphysicsResultEnvelopeV1)
    result.physics_hash == state.candidate_binding_hash || throw(ArgumentError(
        "engineering result candidate binding mismatch"))
    checks = Dict{String,Any}[Dict{String,Any}(String(key) => value
        for (key, value) in pairs(item)) for item in result.engineering_checks]
    obligations = sort!(unique(String(get(item, "check_id", "engineering_check"))
        for item in checks))
    isempty(obligations) && push!(obligations, "engineering_manifest_applicability")
    failed = sort!(unique(String(item["check_id"]) for item in checks
        if String(get(item, "status", "unknown")) == "fail"))
    exact_state = result.state_result_hash !== nothing &&
        result.state_result_hash == state.state_result_hash
    result.state_result_hash === nothing || exact_state || throw(ArgumentError(
        "engineering result state binding mismatch"))
    status = !exact_state ? :unknown : result.status
    status == :fail && isempty(failed) && (status = :unknown)
    tasks = status in (:pass, :fail) ? String[] : copy(result.unresolved_reasons)
    !exact_state && push!(tasks, "recompute_engineering_on_shared_state:$(state.state_result_hash)")
    isempty(tasks) && status in (:unknown, :unsupported) &&
        push!(tasks, "complete_candidate_bound_engineering_constraints")
    return compile_c2_bound_gate_evidence_v1(
        candidate_binding_hash = state.candidate_binding_hash,
        state_result_hash = state.state_result_hash, gate_id = "engineering",
        status = status, obligation_ids = obligations,
        failed_obligation_ids = status == :fail ? failed : String[],
        evidence_hashes = [result.result_hash], evidence_tasks = tasks,
        claim_boundary = result.evidence_ceiling)
end

function compile_c2_independent_evidence_from_v68_v1(
        state::C2CandidateStatePackageV1, result::NonlinearSolveResultEnvelopeV1,
        interval::C2UncertaintyIntervalEvidenceV1)
    state.candidate_binding_hash == result.physics_hash || throw(ArgumentError(
        "independent evidence v68 candidate binding mismatch"))
    state.state_result_hash == result.result_hash || throw(ArgumentError(
        "independent evidence state is detached from v68 result"))
    interval.candidate_binding_hash == state.candidate_binding_hash ||
        throw(ArgumentError("uncertainty interval candidate binding mismatch"))
    interval.state_result_hash == state.state_result_hash ||
        throw(ArgumentError("uncertainty interval state result mismatch"))
    audit = String(get(result.audits, "independent_residual_recalculation", "unknown"))
    status = audit == "pass" ? :pass : audit == "fail" ? :fail : :unknown
    failed = status == :fail ? ["independent_residual"] : String[]
    tasks = status == :unknown ? ["complete_candidate_bound_independent_residual_audit"] :
        String[]
    return compile_c2_bound_gate_evidence_v1(
        candidate_binding_hash = state.candidate_binding_hash,
        state_result_hash = state.state_result_hash,
        gate_id = "independent_evidence", status = status,
        obligation_ids = ["independent_residual", "uncertainty_interval"],
        failed_obligation_ids = failed,
        evidence_hashes = [result.result_hash, interval.interval_hash,
            interval.source_result_hash], evidence_tasks = tasks,
        claim_boundary = "Independent v68 residual recalculation plus a declared candidate-bound uncertainty interval; interval sign is evaluated by downstream energy gates.")
end

function compile_candidate_c2_decision_from_v68_v1(
        state::C2CandidateStatePackageV1, result::NonlinearSolveResultEnvelopeV1,
        stability_compilation::AbstractDict,
        engineering_evidence::C2BoundGateEvidenceV1,
        independent_evidence::C2BoundGateEvidenceV1)
    state.candidate_binding_hash == result.physics_hash || throw(ArgumentError(
        "v68 final C2 candidate binding mismatch"))
    state.state_result_hash == result.result_hash || throw(ArgumentError(
        "v68 final C2 state package is not bound to the nonlinear result"))
    String(stability_compilation["candidate_binding_hash"]) ==
        state.candidate_binding_hash || throw(ArgumentError(
            "v68 final C2 stability candidate binding mismatch"))
    engineering_evidence.gate_id == "engineering" || throw(ArgumentError(
        "engineering evidence carries the wrong gate id"))
    independent_evidence.gate_id == "independent_evidence" || throw(ArgumentError(
        "independent evidence carries the wrong gate id"))
    gates = C2GateDecisionV1[
        c2_gate_from_v68_result_v1(state, result),
        c2_gate_from_stability_compilation_dict_v2(stability_compilation;
            expected_state_result_hash = state.state_result_hash),
        c2_gate_from_bound_evidence_v1(state, engineering_evidence),
        c2_gate_from_bound_evidence_v1(state, independent_evidence)]
    return compile_c2_decision_envelope_v1(state, gates)
end

function compile_c2_decision_envelope_v1(state::C2CandidateStatePackageV1,
        gates::Vector{C2GateDecisionV1})
    isempty(gates) && throw(ArgumentError("C2 aggregation requires gate decisions"))
    gate_ids = getfield.(gates, :gate_id)
    length(unique(gate_ids)) == length(gate_ids) || throw(ArgumentError("duplicate gate id"))
    required = sort!(filter(item -> item.required, copy(gates)); by = item -> item.gate_id)
    isempty(required) && throw(ArgumentError("C2 aggregation requires at least one required gate"))
    complete_ids = sort!(String[item.gate_id for item in required
        if item.completeness == :complete])
    incomplete_ids = sort!(String[item.gate_id for item in required
        if item.completeness == :incomplete])
    unsupported_ids = sort!(String[item.gate_id for item in required
        if item.completeness == :unsupported])
    failed_ids = sort!(String[item.gate_id for item in required
        if item.conclusion == :fail])
    completeness = !isempty(unsupported_ids) ? :unsupported :
        !isempty(incomplete_ids) ? :incomplete : :complete
    failures_by_hash = Dict{String,C2NarrowFailureV1}()
    for gate in gates, failure in gate.narrow_failures
        failures_by_hash[failure.failure_hash] = failure
    end
    failures = sort!(collect(values(failures_by_hash)); by = item -> item.failure_hash)
    required_gate_set = Set(getfield.(required, :gate_id))
    terminal_failure = any(failure -> failure.gate_id in required_gate_set &&
        failure.authoritative_for_gate && failure.terminates_candidate, failures)
    conclusion = terminal_failure ? :fail :
        completeness == :unsupported ? :unsupported :
        completeness == :incomplete ? :unknown :
        !isempty(failed_ids) ? :fail : :pass
    terminate = terminal_failure ||
        (completeness == :complete && conclusion in (:pass, :fail))
    termination_scope = terminate ? :candidate_evaluation : :none
    reason = terminal_failure && completeness != :complete ?
        "authoritative_terminal_failure" : terminate ?
        (conclusion == :fail ? "complete_c2_hard_failure" : "complete_c2_pass") :
        completeness == :unsupported ?
        "required_capability_unsupported" : "required_evidence_incomplete"
    ordered_gates = sort!(copy(gates); by = item -> item.gate_id)
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => state.candidate_binding_hash,
        "state_package_hash" => state.package_hash,
        "completeness" => String(completeness),
        "candidate_conclusion" => String(conclusion),
        "failure_hashes" => getfield.(failures, :failure_hash),
        "terminate" => terminate, "termination_scope" => String(termination_scope),
        "termination_reason" => reason,
        "required_gate_ids" => getfield.(required, :gate_id),
        "complete_gate_ids" => complete_ids, "incomplete_gate_ids" => incomplete_ids,
        "unsupported_gate_ids" => unsupported_ids, "failed_gate_ids" => failed_ids,
        "gate_hashes" => getfield.(ordered_gates, :gate_hash))
    return C2DecisionEnvelope("1.0.0", state.candidate_binding_hash,
        state.package_hash, completeness, conclusion, failures, terminate,
        termination_scope, reason, getfield.(required, :gate_id), complete_ids,
        incomplete_ids, unsupported_ids, failed_ids, ordered_gates, canonical_hash(core))
end

function c2_gate_from_stability_compilation_v2(stage::StabilityStageCompilationV2;
        gate_id::AbstractString = "stage_4_stability", required::Bool = true,
        expected_state_result_hash::Union{Nothing,AbstractString} = nothing)
    expected = expected_state_result_hash === nothing ? nothing :
        _c2_check_hash_v1(String(expected_state_result_hash), "expected Stage-4 state result hash")
    mismatched = Set(String[item.operator_id for item in stage.evidence
        if item.operator_id in stage.required_operator_ids && expected !== nothing &&
            item.state_result_hash != expected])
    effective_failed = setdiff(stage.failed_operator_ids, collect(mismatched))
    complete = stage.stage_complete && isempty(mismatched)
    completeness = !isempty(stage.unsupported_operator_ids) ? :unsupported :
        complete ? :complete : :incomplete
    conclusion = !isempty(effective_failed) ? :fail :
        completeness == :complete ? :pass :
        completeness == :unsupported ? :unsupported : :unknown
    failures = C2NarrowFailureV1[]
    for item in stage.evidence
        item.status == :fail || continue
        not_falsified = String.(get(item.minimal_failure_scope, "not_falsified", String[]))
        terminal = get(item.minimal_failure_scope, "terminates_candidate", false) === true
        push!(failures, compile_c2_narrow_failure_v1(
            "$(gate_id):$(item.operator_id)", gate_id,
            "fail_stability_operator", :operator;
            affected_ids = [item.operator_id], excluded_claims = not_falsified,
            authoritative_for_gate = item.operator_id in stage.required_operator_ids &&
                !(item.operator_id in mismatched),
            terminates_candidate = terminal,
            source_result_hash = item.source_result_hash))
    end
    tasks = copy(stage.evidence_tasks)
    append!(tasks, ["recompute_stability_operator_on_shared_state:$id:$expected"
        for id in sort!(collect(mismatched))])
    return compile_c2_gate_decision_v1(gate_id; required = required,
        completeness = completeness, conclusion = conclusion,
        narrow_failures = failures, evidence_hashes = [stage.compilation_hash],
        evidence_tasks = tasks)
end

function c2_quantity_field_to_dict_v1(item::C2QuantityFieldV1)
    return Dict{String,Any}("field_id" => item.field_id, "value" => item.value,
        "unit" => item.unit, "evidence_hash" => item.evidence_hash,
        "field_hash" => item.field_hash)
end

function c2_candidate_state_package_to_dict_v1(item::C2CandidateStatePackageV1)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "candidate_binding_hash" => item.candidate_binding_hash,
        "state_result_hash" => item.state_result_hash, "time_mode" => String(item.time_mode),
        "boundary_classes" => item.boundary_classes, "capability_ids" => item.capability_ids,
        "region_ids" => item.region_ids,
        "particle_accounts" => c2_quantity_field_to_dict_v1.(item.particle_accounts),
        "energy_accounts" => c2_quantity_field_to_dict_v1.(item.energy_accounts),
        "species_states" => [Dict("species_id" => value.species_id,
            "inventory" => value.inventory, "inventory_unit" => value.inventory_unit,
            "charge_number" => value.charge_number, "evidence_hash" => value.evidence_hash,
            "state_hash" => value.state_hash) for value in item.species_states],
        "actuator_states" => [Dict("actuator_id" => value.actuator_id,
            "role" => String(value.role), "demand" => value.demand, "output" => value.output,
            "capacity" => value.capacity, "output_unit" => value.output_unit,
            "wall_plug_efficiency" => value.wall_plug_efficiency,
            "evidence_hash" => value.evidence_hash, "state_hash" => value.state_hash)
            for value in item.actuator_states],
        "power_ledger" => Dict("accounts" => c2_quantity_field_to_dict_v1.(item.power_ledger.accounts),
            "balance_residual_w" => item.power_ledger.balance_residual_w,
            "evidence_hash" => item.power_ledger.evidence_hash,
            "ledger_hash" => item.power_ledger.ledger_hash),
        "evidence_fields" => [Dict("field_id" => value.field_id,
            "status" => String(value.status), "source_result_hash" => value.source_result_hash,
            "claim_boundary" => value.claim_boundary, "evidence_hash" => value.evidence_hash)
            for value in item.evidence_fields], "package_hash" => item.package_hash)
end

function c2_narrow_failure_to_dict_v1(item::C2NarrowFailureV1)
    return Dict{String,Any}("failure_id" => item.failure_id, "gate_id" => item.gate_id,
        "failure_code" => item.failure_code, "scope_kind" => String(item.scope_kind),
        "affected_ids" => item.affected_ids, "excluded_claims" => item.excluded_claims,
        "authoritative_for_gate" => item.authoritative_for_gate,
        "terminates_candidate" => item.terminates_candidate,
        "source_result_hash" => item.source_result_hash, "failure_hash" => item.failure_hash)
end

function c2_gate_decision_to_dict_v1(item::C2GateDecisionV1)
    return Dict{String,Any}("gate_id" => item.gate_id, "required" => item.required,
        "completeness" => String(item.completeness), "conclusion" => String(item.conclusion),
        "narrow_failures" => c2_narrow_failure_to_dict_v1.(item.narrow_failures),
        "evidence_hashes" => item.evidence_hashes, "evidence_tasks" => item.evidence_tasks,
        "gate_hash" => item.gate_hash)
end

function c2_decision_envelope_to_dict_v1(item::C2DecisionEnvelope)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "candidate_binding_hash" => item.candidate_binding_hash,
        "state_package_hash" => item.state_package_hash,
        "completeness" => String(item.completeness),
        "candidate_conclusion" => String(item.candidate_conclusion),
        "narrow_failures" => c2_narrow_failure_to_dict_v1.(item.narrow_failures),
        "terminate" => item.terminate, "termination_scope" => String(item.termination_scope),
        "termination_reason" => item.termination_reason,
        "required_gate_ids" => item.required_gate_ids,
        "complete_gate_ids" => item.complete_gate_ids,
        "incomplete_gate_ids" => item.incomplete_gate_ids,
        "unsupported_gate_ids" => item.unsupported_gate_ids,
        "failed_gate_ids" => item.failed_gate_ids,
        "gate_decisions" => c2_gate_decision_to_dict_v1.(item.gate_decisions),
        "decision_hash" => item.decision_hash)
end

function c2_state_structural_projection_v1(item::C2CandidateStatePackageV1)
    return Dict{String,Any}("time_mode" => String(item.time_mode),
        "particle_account_ids" => getfield.(item.particle_accounts, :field_id),
        "energy_account_ids" => getfield.(item.energy_accounts, :field_id),
        "species_state_ids" => getfield.(item.species_states, :species_id),
        "actuator_roles" => sort!(String.(getfield.(item.actuator_states, :role))),
        "power_account_ids" => getfield.(item.power_ledger.accounts, :field_id),
        "evidence_field_ids" => getfield.(item.evidence_fields, :field_id))
end

function c2_decision_structural_projection_v1(item::C2DecisionEnvelope)
    return Dict{String,Any}("completeness" => String(item.completeness),
        "candidate_conclusion" => String(item.candidate_conclusion),
        "terminate" => item.terminate, "termination_scope" => String(item.termination_scope),
        "required_gate_ids" => item.required_gate_ids,
        "complete_gate_ids" => item.complete_gate_ids,
        "incomplete_gate_ids" => item.incomplete_gate_ids,
        "unsupported_gate_ids" => item.unsupported_gate_ids,
        "failed_gate_ids" => item.failed_gate_ids,
        "gate_shapes" => [Dict("gate_id" => gate.gate_id, "required" => gate.required,
            "completeness" => String(gate.completeness), "conclusion" => String(gate.conclusion),
            "failure_codes" => sort!(getfield.(gate.narrow_failures, :failure_code)))
            for gate in item.gate_decisions])
end

function _real_panel_obligation_states_v1(result::RealCandidatePanelCompilationV1)
    return Dict{String,String}(String(item["obligation"]) =>
        String(item["evidence_state"]) for item in result.obligation_audits)
end


function _real_panel_evidence_status_v1(states::Dict{String,String}, ids::Vector{String})
    values = String[get(states, id, "unknown") for id in ids]
    any(==("unsupported"), values) && return :unsupported
    all(==("complete"), values) && return :complete
    any(value -> value in ("partial", "complete"), values) && return :partial
    return :unknown
end


"Compile an incomplete real-panel record without inventing missing numerical values."
function compile_real_candidate_state_package_v1(
        result::RealCandidatePanelCompilationV1)
    source_hash = result.result_hash
    states = _real_panel_obligation_states_v1(result)
    q(id, unit) = compile_c2_quantity_field_v1(id, nothing, unit, source_hash)
    particles = [q("total_particle_inventory", "particle")]
    energies = [q("ion_thermal_energy", "J"), q("electron_thermal_energy", "J")]
    species = [compile_c2_species_state_v1("fuel_species_group", nothing,
        "particle", nothing, source_hash)]
    actuator(role, id, unit) = compile_c2_actuator_state_v1(id, role;
        demand = nothing, output = nothing, capacity = nothing, output_unit = unit,
        wall_plug_efficiency = nothing, evidence_hash = source_hash)
    actuators = C2ActuatorStateV1[
        actuator(:fueling, "fueling_actuator", "particle/s"),
        actuator(:heating, "heating_actuator", "W"),
        actuator(:exhaust, "exhaust_actuator", "particle/s"),
        actuator(:radiation_control, "radiation_control_actuator", "W")]
    power = compile_c2_power_ledger_v1([
        q("reaction_power", "W"), q("self_heating_power", "W"),
        q("radiation_loss_power", "W"), q("actuator_delivered_power", "W"),
        q("wall_input_power", "W"), q("gross_electric_power", "W"),
        q("net_electric_lower_bound", "W")]; balance_residual_w = nothing,
        evidence_hash = source_hash)
    field_groups = Dict{String,Vector{String}}(
        "state_solution" => ["particle_state", "ion_energy_state",
            "electron_energy_state", "species_state"],
        "residual_convergence" => String[],
        "conservation" => ["particle_state", "ion_energy_state",
            "electron_energy_state", "species_state", "complete_power_ledger"],
        "interface_flux" => ["transport_operator"],
        "actuator_fulfillment" => ["fueling_actuator", "heating_actuator",
            "exhaust_actuator", "radiation_control_actuator", "actuator_capacity",
            "actuator_efficiency"],
        "physical_bounds" => String[], "validity_domain" => String[],
        "resolution_trend" => String[], "jacobian_audit" => String[],
        "independent_residual_audit" => String[], "stability" => String[],
        "engineering" => String[])
    evidence_fields = C2EvidenceFieldV1[]
    for field_id in sort!(collect(keys(field_groups)))
        ids = field_groups[field_id]
        status = isempty(ids) ? :unknown : _real_panel_evidence_status_v1(states, ids)
        push!(evidence_fields, compile_c2_evidence_field_v1(field_id, status,
            source_hash, "Real fixed-panel inventory only; missing numerical values remain null and grant no C2 credit."))
    end
    complete_capabilities = sort!(String["v68_obligation:$id" for (id, status) in states
        if status == "complete"])
    push!(complete_capabilities, "candidate_v68_residual_obligation_inventory_v1")
    return compile_c2_candidate_state_package_v1(
        candidate_binding_hash = result.candidate_binding_hash,
        state_result_hash = source_hash, time_mode = :steady,
        boundary_classes = [result.route], capability_ids = complete_capabilities,
        region_ids = ["primary_region"], particle_accounts = particles,
        energy_accounts = energies, species_states = species,
        actuator_states = actuators, power_ledger = power,
        evidence_fields = evidence_fields)
end


function c2_gate_from_real_candidate_panel_v1(
        result::RealCandidatePanelCompilationV1;
        gate_id::AbstractString = "stage_3_residual", required::Bool = true)
    completeness = result.status == :unsupported ? :unsupported :
        result.complete_c2_result ? :complete : :incomplete
    conclusion = completeness == :unsupported ? :unsupported :
        result.status == :fail ? :fail :
        completeness == :complete && result.status == :pass ? :pass : :unknown
    failures = C2NarrowFailureV1[]
    for (index, item) in enumerate(result.hard_failures)
        obligation = String(get(item, "obligation", "unspecified_obligation"))
        scope = String(get(item, "scope", obligation))
        push!(failures, compile_c2_narrow_failure_v1(
            "$(gate_id):$(obligation):$index", gate_id,
            String(get(item, "code", "fail_candidate_bound_component")), :residual_component;
            affected_ids = [obligation, scope],
            excluded_claims = ["complete_candidate_c2", "unrelated_residual_obligations"],
            authoritative_for_gate = true, terminates_candidate = false,
            source_result_hash = result.result_hash))
    end
    tasks = String["provide_v68_obligation:$id" for id in result.incomplete_obligations]
    result.v68_execution_authorized && !result.complete_c2_result &&
        push!(tasks, "execute_candidate_bound_v68_residual")
    return compile_c2_gate_decision_v1(gate_id; required = required,
        completeness = completeness, conclusion = conclusion,
        narrow_failures = failures, evidence_hashes = [result.result_hash],
        evidence_tasks = tasks)
end


function c2_gate_from_stability_compilation_dict_v2(compilation::AbstractDict;
        gate_id::AbstractString = "stage_4_stability", required::Bool = true,
        expected_state_result_hash::Union{Nothing,AbstractString} = nothing)
    expected = expected_state_result_hash === nothing ? nothing :
        _c2_check_hash_v1(String(expected_state_result_hash), "expected Stage-4 state result hash")
    required_operators = Set(String.(get(compilation, "required_operator_ids", String[])))
    evidence_records = Dict{String,Any}[Dict{String,Any}(String(key) => value
        for (key, value) in pairs(item_any))
        for item_any in get(compilation, "evidence", Any[])]
    mismatched = Set(String(item["operator_id"]) for item in evidence_records
        if String(item["operator_id"]) in required_operators && expected !== nothing &&
            String(get(item, "state_result_hash", "")) != expected)
    unsupported = String.(get(compilation, "unsupported_operator_ids", String[]))
    failed = setdiff(String.(get(compilation, "failed_operator_ids", String[])),
        collect(mismatched))
    complete = get(compilation, "stage_complete", false) === true && isempty(mismatched)
    completeness = !isempty(unsupported) ? :unsupported : complete ? :complete : :incomplete
    conclusion = !isempty(failed) ? :fail : completeness == :complete ? :pass :
        completeness == :unsupported ? :unsupported : :unknown
    failures = C2NarrowFailureV1[]
    for item in evidence_records
        String(get(item, "status", "unknown")) == "fail" || continue
        operator_id = String(item["operator_id"])
        scope_any = get(item, "minimal_failure_scope", Dict{String,Any}())
        scope = Dict{String,Any}(String(key) => value for (key, value) in pairs(scope_any))
        excluded = String.(get(scope, "not_falsified", String[]))
        terminal = get(scope, "terminates_candidate", false) === true
        source_hash = String(get(item, "source_result_hash",
            get(item, "evidence_hash", compilation["compilation_hash"])))
        push!(failures, compile_c2_narrow_failure_v1(
            "$(gate_id):$operator_id", gate_id, "fail_stability_operator", :operator;
            affected_ids = [operator_id], excluded_claims = excluded,
            authoritative_for_gate = operator_id in failed && !(operator_id in mismatched),
            terminates_candidate = terminal, source_result_hash = source_hash))
    end
    tasks = String.(get(compilation, "evidence_tasks", String[]))
    append!(tasks, ["recompute_stability_operator_on_shared_state:$id:$expected"
        for id in sort!(collect(mismatched))])
    return compile_c2_gate_decision_v1(gate_id; required = required,
        completeness = completeness, conclusion = conclusion,
        narrow_failures = failures,
        evidence_hashes = [String(compilation["compilation_hash"])],
        evidence_tasks = tasks)
end


function compile_real_candidate_c2_decision_v1(state::C2CandidateStatePackageV1,
        residual::RealCandidatePanelCompilationV1,
        stability_compilation::AbstractDict;
        engineering_evidence::Union{Nothing,C2BoundGateEvidenceV1} = nothing,
        independent_evidence::Union{Nothing,C2BoundGateEvidenceV1} = nothing)
    state.candidate_binding_hash == residual.candidate_binding_hash ||
        throw(ArgumentError("real C2 state/residual binding mismatch"))
    String(stability_compilation["candidate_binding_hash"]) ==
        state.candidate_binding_hash || throw(ArgumentError(
            "real C2 state/stability binding mismatch"))
    residual_gate = c2_gate_from_real_candidate_panel_v1(residual)
    stability_gate = c2_gate_from_stability_compilation_dict_v2(stability_compilation;
        expected_state_result_hash = state.state_result_hash)
    engineering = engineering_evidence === nothing ?
        compile_c2_bound_gate_evidence_v1(
            candidate_binding_hash = state.candidate_binding_hash,
            state_result_hash = state.state_result_hash, gate_id = "engineering",
            status = :unknown, obligation_ids = ["engineering_constraints"],
            evidence_hashes = String[],
            evidence_tasks = [
                "run_candidate_engineering_multiphysics_on_shared_state:$(state.state_result_hash)",
                "compile_c2_engineering_evidence_v1"],
            claim_boundary = "No candidate-bound engineering result on the shared state was supplied.") :
        engineering_evidence
    independent = independent_evidence === nothing ?
        compile_c2_bound_gate_evidence_v1(
            candidate_binding_hash = state.candidate_binding_hash,
            state_result_hash = state.state_result_hash,
            gate_id = "independent_evidence", status = :unknown,
            obligation_ids = ["independent_residual", "uncertainty_interval"],
            evidence_hashes = String[], evidence_tasks = [
                "recalculate_independent_residual_on_shared_state:$(state.state_result_hash)",
                "acquire_candidate_bound_uncertainty_interval:$(state.state_result_hash)",
                "compile_c2_independent_evidence_from_v68_v1"],
            claim_boundary = "No candidate-bound independent residual and uncertainty evidence on the shared state was supplied.") :
        independent_evidence
    engineering_gate = c2_gate_from_bound_evidence_v1(state, engineering)
    independent_gate = c2_gate_from_bound_evidence_v1(state, independent)
    return compile_c2_decision_envelope_v1(state,
        [residual_gate, stability_gate, engineering_gate, independent_gate])
end
