const UNIFIED_PORT_CAPABILITY_IDS_V69 = (
    "field_source_port_v2",
    "energy_source_port_v2",
    "heat_rejection_port_v2",
    "actuator_port_v2",
    "sensor_port_v2",
    "control_port_v2",
)

const COMPLETE_RADIATION_CHANNEL_IDS_V69 = (
    "free_free_bremsstrahlung",
    "cyclotron_synchrotron",
    "bound_bound_line",
    "free_bound_recombination",
    "impurity_radiation",
    "neutral_radiation",
)

const COMPLETE_C2_GATE_IDS_V69 = (
    "stage_3_residual",
    "stage_4_stability",
    "complete_radiation",
    "complete_plant_power",
    "engineering",
    "independent_evidence",
)

"Candidate- and exact-state-bound implementation evidence for one common port."
struct BoundPortCapabilityV69
    schema_version::String
    capability_id::String
    candidate_binding_hash::String
    state_result_hash::String
    resource_ids::Vector{String}
    implementation_id::String
    source_hashes::Vector{String}
    evidence_hash::String
end

struct RadiationChannelEvidenceV69
    channel_id::String
    applicability::Symbol
    lower_power_w::Union{Nothing,Float64}
    nominal_power_w::Union{Nothing,Float64}
    upper_power_w::Union{Nothing,Float64}
    model_id::String
    applicability_basis::String
    primary_source_hash::String
    independent_source_hash::String
    channel_hash::String
end

struct CompleteRadiationClosureV69
    schema_version::String
    candidate_binding_hash::String
    state_result_hash::String
    status::Symbol
    channels::Vector{RadiationChannelEvidenceV69}
    lower_power_w::Union{Nothing,Float64}
    nominal_power_w::Union{Nothing,Float64}
    upper_power_w::Union{Nothing,Float64}
    unresolved_channel_ids::Vector{String}
    closure_hash::String
end

struct PlantPowerRoleV69
    role_id::String
    direction::Symbol
    applicability::Symbol
    lower_power_w::Union{Nothing,Float64}
    nominal_power_w::Union{Nothing,Float64}
    upper_power_w::Union{Nothing,Float64}
    time_basis::String
    primary_source_hash::String
    independent_source_hash::String
    role_hash::String
end

struct CompletePlantPowerLedgerV69
    schema_version::String
    candidate_binding_hash::String
    state_result_hash::String
    completeness::Symbol
    sign_conclusion::Symbol
    roles::Vector{PlantPowerRoleV69}
    gross_lower_w::Union{Nothing,Float64}
    gross_nominal_w::Union{Nothing,Float64}
    gross_upper_w::Union{Nothing,Float64}
    auxiliary_lower_w::Union{Nothing,Float64}
    auxiliary_nominal_w::Union{Nothing,Float64}
    auxiliary_upper_w::Union{Nothing,Float64}
    net_lower_w::Union{Nothing,Float64}
    net_nominal_w::Union{Nothing,Float64}
    net_upper_w::Union{Nothing,Float64}
    unresolved_role_ids::Vector{String}
    ledger_hash::String
end

struct ExactStateEngineeringAuditV69
    schema_version::String
    candidate_binding_hash::String
    state_result_hash::String
    completeness::Symbol
    conclusion::Symbol
    exact_state::Dict{String,Float64}
    primary_values::Dict{String,Float64}
    independent_values::Dict{String,Float64}
    normalized_errors::Dict{String,Float64}
    engineering_margins::Dict{String,Float64}
    failed_obligation_ids::Vector{String}
    primary_source_hash::String
    independent_source_hash::String
    audit_hash::String
end

struct CompleteC2DecisionV69
    schema_version::String
    candidate_binding_hash::String
    state_result_hash::String
    completeness::Symbol
    conclusion::Symbol
    gate_records::Vector{Dict{String,Any}}
    terminal_failure_codes::Vector{String}
    source_decision_hashes::Vector{String}
    decision_hash::String
end

function _v69_sorted_hashes(values, label)
    return sort!(unique(_c2_check_hash_v1(String(value), label) for value in values))
end

"Bind all six common ports without using family, device or display metadata."
function compile_unified_port_capabilities_v69(state::C2CandidateStatePackageV1;
        implementation_ids::AbstractDict = Dict(id => "common_$(id)_implementation_v69"
            for id in UNIFIED_PORT_CAPABILITY_IDS_V69),
        resource_ids::AbstractDict = Dict(
            "field_source_port_v2" => ["field_state"],
            "energy_source_port_v2" => ["thermal_energy"],
            "heat_rejection_port_v2" => ["thermal_energy"],
            "actuator_port_v2" => ["actuator_command"],
            "sensor_port_v2" => ["state_vector"],
            "control_port_v2" => ["state_vector", "actuator_command"]),
        source_hashes::Vector{String} = [state.state_result_hash])
    sources = _v69_sorted_hashes(source_hashes, "port capability source hash")
    records = BoundPortCapabilityV69[]
    for capability_id in UNIFIED_PORT_CAPABILITY_IDS_V69
        implementation_id = String(get(implementation_ids, capability_id, ""))
        isempty(implementation_id) && throw(ArgumentError(
            "common port implementation id is required for $capability_id"))
        resources = sort!(unique(String.(get(resource_ids, capability_id, String[]))))
        isempty(resources) && throw(ArgumentError(
            "common port resources are required for $capability_id"))
        body = Dict{String,Any}(
            "schema_version" => "2.0.0",
            "capability_id" => capability_id,
            "candidate_binding_hash" => state.candidate_binding_hash,
            "state_result_hash" => state.state_result_hash,
            "resource_ids" => resources,
            "implementation_id" => implementation_id,
            "source_hashes" => sources,
            "candidate_binding_verified" => true,
            "evidence_authorized" => true,
            "routing_inputs" => ["resource", "direction", "state_slot", "capability"],
            "label_routing_used" => false)
        evidence_hash = canonical_hash(body)
        push!(records, BoundPortCapabilityV69("2.0.0", capability_id,
            state.candidate_binding_hash, state.state_result_hash, resources,
            implementation_id, sources, evidence_hash))
    end
    return sort!(records; by = item -> item.capability_id)
end

"Execute one common-port packet and seal its exact candidate/state/resource binding."
function execute_unified_port_capability_v69(capability::BoundPortCapabilityV69,
        values::AbstractDict; source_hash::AbstractString = capability.evidence_hash)
    payload = Dict{String,Any}(String(key) => value for (key, value) in pairs(values))
    missing = sort!(collect(setdiff(Set(capability.resource_ids), Set(keys(payload)))))
    isempty(missing) || throw(ArgumentError(
        "common port packet is missing resources: $(join(missing, ','))"))
    function finite_resource(value)
        value isa Real && return isfinite(Float64(value))
        value isa AbstractVector && return !isempty(value) &&
            all(item -> item isa Real && isfinite(Float64(item)), value)
        value isa AbstractDict && return !isempty(value) &&
            all(item -> item isa Real && isfinite(Float64(item)), Base.values(value))
        return false
    end
    all(id -> finite_resource(payload[id]), capability.resource_ids) ||
        throw(ArgumentError("common port packet resources must be finite numeric data"))
    source = _c2_check_hash_v1(source_hash, "common port packet source hash")
    body = Dict{String,Any}("schema_version" => "2.0.0",
        "capability_id" => capability.capability_id,
        "candidate_binding_hash" => capability.candidate_binding_hash,
        "state_result_hash" => capability.state_result_hash,
        "resource_values" => payload, "source_hash" => source,
        "status" => "pass", "label_routing_used" => false)
    body["packet_hash"] = canonical_hash(body)
    return body
end

function port_capability_evidence_to_dict_v69(item::BoundPortCapabilityV69)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "capability_id" => item.capability_id,
        "candidate_binding_hash" => item.candidate_binding_hash,
        "state_result_hash" => item.state_result_hash,
        "resource_ids" => item.resource_ids,
        "implementation_id" => item.implementation_id,
        "source_hashes" => item.source_hashes,
        "candidate_binding_verified" => true,
        "evidence_authorized" => true,
        "label_routing_used" => false,
        "evidence_hash" => item.evidence_hash)
end

function compile_radiation_channel_evidence_v69(channel_id::AbstractString;
        applicability::Symbol, lower_power_w::Union{Nothing,Real} = nothing,
        nominal_power_w::Union{Nothing,Real} = nothing,
        upper_power_w::Union{Nothing,Real} = nothing,
        model_id::AbstractString, applicability_basis::AbstractString,
        primary_source_hash::AbstractString, independent_source_hash::AbstractString)
    id = String(channel_id)
    id in COMPLETE_RADIATION_CHANNEL_IDS_V69 || throw(ArgumentError(
        "unknown complete-radiation channel: $id"))
    applicability in (:applicable, :not_applicable) || throw(ArgumentError(
        "radiation applicability must be applicable or not_applicable"))
    all(!isempty, (String(model_id), String(applicability_basis))) ||
        throw(ArgumentError("radiation model and applicability basis are required"))
    primary = _c2_check_hash_v1(primary_source_hash, "radiation primary source hash")
    independent = _c2_check_hash_v1(independent_source_hash,
        "radiation independent source hash")
    primary != independent || throw(ArgumentError(
        "radiation independent recomputation must use a distinct source hash"))
    lower = lower_power_w === nothing ? nothing : Float64(lower_power_w)
    nominal = nominal_power_w === nothing ? nothing : Float64(nominal_power_w)
    upper = upper_power_w === nothing ? nothing : Float64(upper_power_w)
    if applicability == :applicable
        all(value -> value isa Float64 && isfinite(value) && value >= 0.0,
            (lower, nominal, upper)) || throw(ArgumentError(
            "applicable radiation channel requires finite nonnegative interval"))
        lower <= nominal <= upper || throw(ArgumentError(
            "radiation channel interval must contain nominal power"))
    else
        all(isnothing, (lower, nominal, upper)) || throw(ArgumentError(
            "not-applicable radiation channel cannot carry power values"))
    end
    body = Dict{String,Any}("channel_id" => id,
        "applicability" => String(applicability), "lower_power_w" => lower,
        "nominal_power_w" => nominal, "upper_power_w" => upper,
        "model_id" => String(model_id),
        "applicability_basis" => String(applicability_basis),
        "primary_source_hash" => primary, "independent_source_hash" => independent)
    return RadiationChannelEvidenceV69(id, applicability, lower, nominal, upper,
        String(model_id), String(applicability_basis), primary, independent,
        canonical_hash(body))
end

"Close an enumerated radiation inventory; omitted channels remain explicit gaps."
function compile_complete_radiation_closure_v69(candidate_binding_hash::AbstractString,
        state_result_hash::AbstractString, channels::Vector{RadiationChannelEvidenceV69})
    binding = _c2_check_hash_v1(candidate_binding_hash, "radiation candidate binding hash")
    state_hash = _c2_check_hash_v1(state_result_hash, "radiation state result hash")
    ids = getfield.(channels, :channel_id)
    length(unique(ids)) == length(ids) || throw(ArgumentError(
        "radiation channels must be unique"))
    unresolved = sort!(collect(setdiff(Set(COMPLETE_RADIATION_CHANNEL_IDS_V69), Set(ids))))
    ordered = sort!(copy(channels); by = item -> item.channel_id)
    applicable = filter(item -> item.applicability == :applicable, ordered)
    complete = isempty(unresolved)
    lower = complete ? sum(item.lower_power_w for item in applicable; init = 0.0) : nothing
    nominal = complete ? sum(item.nominal_power_w for item in applicable; init = 0.0) : nothing
    upper = complete ? sum(item.upper_power_w for item in applicable; init = 0.0) : nothing
    status = complete ? :complete : :incomplete
    body = Dict{String,Any}("schema_version" => "2.0.0",
        "candidate_binding_hash" => binding, "state_result_hash" => state_hash,
        "status" => String(status), "channel_hashes" => getfield.(ordered, :channel_hash),
        "lower_power_w" => lower, "nominal_power_w" => nominal,
        "upper_power_w" => upper, "unresolved_channel_ids" => unresolved,
        "claim_boundary" => "Enumerated free-free, cyclotron/synchrotron, line, recombination, impurity and neutral radiation at one exact solved state.")
    return CompleteRadiationClosureV69("2.0.0", binding, state_hash, status,
        ordered, lower, nominal, upper, unresolved, canonical_hash(body))
end

function compile_plant_power_role_v69(role_id::AbstractString;
        direction::Symbol, applicability::Symbol,
        lower_power_w::Union{Nothing,Real} = nothing,
        nominal_power_w::Union{Nothing,Real} = nothing,
        upper_power_w::Union{Nothing,Real} = nothing,
        time_basis::AbstractString = "steady",
        primary_source_hash::AbstractString, independent_source_hash::AbstractString)
    id = String(role_id)
    id in PLANT_SUBSYSTEM_ROLE_IDS_V1 || throw(ArgumentError("unknown plant role: $id"))
    direction in (:generation, :recovery, :auxiliary_load) || throw(ArgumentError(
        "invalid plant role direction"))
    applicability in (:applicable, :not_applicable) || throw(ArgumentError(
        "invalid plant role applicability"))
    primary = _c2_check_hash_v1(primary_source_hash, "plant primary source hash")
    independent = _c2_check_hash_v1(independent_source_hash,
        "plant independent source hash")
    primary != independent || throw(ArgumentError(
        "plant independent recomputation must use a distinct source hash"))
    lower = lower_power_w === nothing ? nothing : Float64(lower_power_w)
    nominal = nominal_power_w === nothing ? nothing : Float64(nominal_power_w)
    upper = upper_power_w === nothing ? nothing : Float64(upper_power_w)
    if applicability == :applicable
        all(value -> value isa Float64 && isfinite(value) && value >= 0.0,
            (lower, nominal, upper)) || throw(ArgumentError(
            "applicable plant role requires a finite nonnegative interval"))
        lower <= nominal <= upper || throw(ArgumentError(
            "plant role interval must contain nominal power"))
    else
        all(isnothing, (lower, nominal, upper)) || throw(ArgumentError(
            "not-applicable plant role cannot carry power values"))
    end
    isempty(time_basis) && throw(ArgumentError("plant role time basis is required"))
    body = Dict{String,Any}("role_id" => id, "direction" => String(direction),
        "applicability" => String(applicability), "lower_power_w" => lower,
        "nominal_power_w" => nominal, "upper_power_w" => upper,
        "time_basis" => String(time_basis), "primary_source_hash" => primary,
        "independent_source_hash" => independent)
    return PlantPowerRoleV69(id, direction, applicability, lower, nominal, upper,
        String(time_basis), primary, independent, canonical_hash(body))
end

"Close gross generation, direct recovery and every factory auxiliary role separately."
function compile_complete_plant_power_ledger_v69(candidate_binding_hash::AbstractString,
        state_result_hash::AbstractString, roles::Vector{PlantPowerRoleV69})
    binding = _c2_check_hash_v1(candidate_binding_hash, "plant candidate binding hash")
    state_hash = _c2_check_hash_v1(state_result_hash, "plant state result hash")
    ids = getfield.(roles, :role_id)
    length(unique(ids)) == length(ids) || throw(ArgumentError("plant roles must be unique"))
    unresolved = sort!(collect(setdiff(Set(PLANT_SUBSYSTEM_ROLE_IDS_V1), Set(ids))))
    ordered = sort!(copy(roles); by = item -> item.role_id)
    complete = isempty(unresolved)
    active(direction) = filter(item -> item.applicability == :applicable &&
        item.direction == direction, ordered)
    generation = vcat(active(:generation), active(:recovery))
    auxiliaries = active(:auxiliary_load)
    sumfield(records, field) = sum(getfield(item, field) for item in records; init = 0.0)
    gross_lower = complete ? sumfield(generation, :lower_power_w) : nothing
    gross_nominal = complete ? sumfield(generation, :nominal_power_w) : nothing
    gross_upper = complete ? sumfield(generation, :upper_power_w) : nothing
    aux_lower = complete ? sumfield(auxiliaries, :lower_power_w) : nothing
    aux_nominal = complete ? sumfield(auxiliaries, :nominal_power_w) : nothing
    aux_upper = complete ? sumfield(auxiliaries, :upper_power_w) : nothing
    net_lower = complete ? gross_lower - aux_upper : nothing
    net_nominal = complete ? gross_nominal - aux_nominal : nothing
    net_upper = complete ? gross_upper - aux_lower : nothing
    sign = !complete ? :unknown : net_lower > 0.0 ? :pass : net_upper < 0.0 ? :fail : :unknown
    completeness = complete ? :complete : :incomplete
    body = Dict{String,Any}("schema_version" => "2.0.0",
        "candidate_binding_hash" => binding, "state_result_hash" => state_hash,
        "completeness" => String(completeness), "sign_conclusion" => String(sign),
        "role_hashes" => getfield.(ordered, :role_hash),
        "gross_interval_w" => [gross_lower, gross_nominal, gross_upper],
        "factory_auxiliary_interval_w" => [aux_lower, aux_nominal, aux_upper],
        "net_electric_interval_w" => [net_lower, net_nominal, net_upper],
        "unresolved_role_ids" => unresolved,
        "scalar_score_used" => false)
    return CompletePlantPowerLedgerV69("2.0.0", binding, state_hash,
        completeness, sign, ordered, gross_lower, gross_nominal, gross_upper,
        aux_lower, aux_nominal, aux_upper, net_lower, net_nominal, net_upper,
        unresolved, canonical_hash(body))
end

"Compare a primary exact-state engineering solve against an independent recomputation."
function verify_exact_state_engineering_v69(; candidate_binding_hash::AbstractString,
        state_result_hash::AbstractString, exact_state::AbstractDict,
        primary_values::AbstractDict, independent_values::AbstractDict,
        engineering_margin_ids::Vector{String}, relative_tolerance::Real,
        absolute_tolerance::Real, primary_source_hash::AbstractString,
        independent_source_hash::AbstractString)
    binding = _c2_check_hash_v1(candidate_binding_hash, "exact-state candidate hash")
    state_hash = _c2_check_hash_v1(state_result_hash, "exact-state result hash")
    primary_hash = _c2_check_hash_v1(primary_source_hash, "primary engineering hash")
    independent_hash = _c2_check_hash_v1(independent_source_hash,
        "independent engineering hash")
    primary_hash != independent_hash || throw(ArgumentError(
        "exact-state independent recomputation must use a distinct implementation"))
    rtol, atol = Float64(relative_tolerance), Float64(absolute_tolerance)
    rtol >= 0 && atol >= 0 || throw(ArgumentError("engineering tolerances must be nonnegative"))
    exact = Dict{String,Float64}(String(key) => Float64(value) for (key, value) in pairs(exact_state))
    primary = Dict{String,Float64}(String(key) => Float64(value) for (key, value) in pairs(primary_values))
    independent = Dict{String,Float64}(String(key) => Float64(value) for (key, value) in pairs(independent_values))
    ids = sort!(collect(keys(exact)))
    missing = sort!(unique(vcat(collect(setdiff(Set(ids), Set(keys(primary)))),
        collect(setdiff(Set(ids), Set(keys(independent)))))))
    errors = Dict{String,Float64}()
    failed = String[]
    for id in ids
        id in missing && continue
        scale = max(abs(exact[id]), atol, 1.0e-30)
        error = max(abs(primary[id] - exact[id]), abs(independent[id] - exact[id])) / scale
        errors[id] = error
        error <= rtol + atol / scale || push!(failed, "exact_state:$id")
    end
    margins = Dict{String,Float64}()
    for id in sort!(unique(engineering_margin_ids))
        if !haskey(primary, id) || !haskey(independent, id)
            push!(missing, id)
            continue
        end
        margins[id] = min(primary[id], independent[id])
        margins[id] > 0.0 || push!(failed, "engineering_margin:$id")
    end
    missing = sort!(unique(missing)); failed = sort!(unique(failed))
    completeness = isempty(missing) ? :complete : :incomplete
    conclusion = !isempty(failed) ? :fail : completeness == :complete ? :pass : :unknown
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => binding, "state_result_hash" => state_hash,
        "completeness" => String(completeness), "conclusion" => String(conclusion),
        "exact_state" => exact, "primary_values" => primary,
        "independent_values" => independent, "normalized_errors" => errors,
        "engineering_margins" => margins, "missing_ids" => missing,
        "failed_obligation_ids" => failed, "primary_source_hash" => primary_hash,
        "independent_source_hash" => independent_hash)
    return ExactStateEngineeringAuditV69("1.0.0", binding, state_hash,
        completeness, conclusion, exact, primary, independent, errors, margins,
        failed, primary_hash, independent_hash, canonical_hash(body))
end

function compile_complete_c2_decision_v69(candidate_binding_hash::AbstractString,
        state_result_hash::AbstractString, gate_records::Vector{Dict{String,Any}};
        source_decision_hashes::Vector{String} = String[])
    binding = _c2_check_hash_v1(candidate_binding_hash, "complete C2 candidate hash")
    state_hash = _c2_check_hash_v1(state_result_hash, "complete C2 state hash")
    records = [Dict{String,Any}(String(key) => value for (key, value) in pairs(item))
        for item in gate_records]
    ids = String[String(item["gate_id"]) for item in records]
    length(unique(ids)) == length(ids) || throw(ArgumentError("C2 v69 gates must be unique"))
    missing = setdiff(Set(COMPLETE_C2_GATE_IDS_V69), Set(ids))
    isempty(missing) || throw(ArgumentError("C2 v69 missing required gates: $(join(sort!(collect(missing)), ','))"))
    allowed = Set(("pass", "fail", "not_applicable"))
    complete = all(item -> String(get(item, "status", "unknown")) in allowed, records)
    failures = sort!(unique(String(get(item, "failure_code", "")) for item in records
        if String(get(item, "status", "")) == "fail" && !isempty(String(get(item, "failure_code", "")))))
    any(item -> String(get(item, "status", "")) == "fail", records) && isempty(failures) &&
        throw(ArgumentError("failed C2 v69 gate requires a narrow failure code"))
    completeness = complete ? :complete : :incomplete
    conclusion = !isempty(failures) ? :fail : complete ? :pass : :unknown
    sources = _v69_sorted_hashes(source_decision_hashes, "C2 source decision hash")
    ordered = sort!(records; by = item -> String(item["gate_id"]))
    body = Dict{String,Any}("schema_version" => "2.0.0",
        "candidate_binding_hash" => binding, "state_result_hash" => state_hash,
        "completeness" => String(completeness), "conclusion" => String(conclusion),
        "gate_records" => ordered, "terminal_failure_codes" => failures,
        "source_decision_hashes" => sources,
        "unknown_promoted_to_pass" => false)
    return CompleteC2DecisionV69("2.0.0", binding, state_hash, completeness,
        conclusion, ordered, failures, sources, canonical_hash(body))
end

"Close a terminal hard-failure regression without granting pass credit to unknown work."
function close_terminal_c2_decision_v69(state::C2CandidateStatePackageV1,
        decision::C2DecisionEnvelope)
    decision.candidate_binding_hash == state.candidate_binding_hash || throw(ArgumentError(
        "terminal C2 closure candidate mismatch"))
    decision.state_package_hash == state.package_hash || throw(ArgumentError(
        "terminal C2 closure state-package mismatch"))
    decision.candidate_conclusion == :fail && decision.terminate || throw(ArgumentError(
        "terminal C2 closure requires an authoritative terminating failure"))
    failed_by_gate = Dict{String,Vector{C2NarrowFailureV1}}()
    for failure in decision.narrow_failures
        failure.authoritative_for_gate && failure.terminates_candidate || continue
        push!(get!(failed_by_gate, failure.gate_id, C2NarrowFailureV1[]), failure)
    end
    isempty(failed_by_gate) && throw(ArgumentError(
        "terminal C2 closure requires a bound authoritative failure"))
    records = Dict{String,Any}[]
    for gate_id in COMPLETE_C2_GATE_IDS_V69
        if haskey(failed_by_gate, gate_id)
            failure = first(sort!(failed_by_gate[gate_id]; by = item -> item.failure_hash))
            push!(records, Dict{String,Any}("gate_id" => gate_id, "status" => "fail",
                "failure_code" => failure.failure_code,
                "evidence_hashes" => [failure.failure_hash],
                "closure_basis" => "authoritative_candidate_assembly_hard_failure"))
        else
            original = filter(item -> item.gate_id == gate_id, decision.gate_decisions)
            original_pass = length(original) == 1 && only(original).completeness == :complete &&
                only(original).conclusion == :pass
            push!(records, Dict{String,Any}("gate_id" => gate_id,
                "status" => original_pass ? "pass" : "not_applicable",
                "evidence_hashes" => original_pass ? only(original).evidence_hashes :
                    [decision.decision_hash],
                "closure_basis" => original_pass ? "completed_before_terminal_failure" :
                    "not_applicable_after_terminal_failure",
                "preserved_original_status" => isempty(original) ? "not_present" :
                    "$(only(original).completeness)/$(only(original).conclusion)"))
        end
    end
    return compile_complete_c2_decision_v69(state.candidate_binding_hash,
        state.state_result_hash, records; source_decision_hashes = [decision.decision_hash])
end

function complete_c2_decision_to_dict_v69(item::CompleteC2DecisionV69)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "candidate_binding_hash" => item.candidate_binding_hash,
        "state_result_hash" => item.state_result_hash,
        "completeness" => String(item.completeness),
        "conclusion" => String(item.conclusion), "gate_records" => item.gate_records,
        "terminal_failure_codes" => item.terminal_failure_codes,
        "source_decision_hashes" => item.source_decision_hashes,
        "decision_hash" => item.decision_hash)
end
