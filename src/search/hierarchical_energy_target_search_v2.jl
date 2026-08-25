const _ENERGY_V2_DISPOSITIONS = Set((:topology_rejected, :topology_unsupported,
    :c2_terminated, :evidence_queue, :engineering_rejected,
    :net_power_shortfall, :uncertainty_crosses_zero, :target_shortfall, :rankable))

"A candidate-bound optimization metric; it carries evidence but no identity label."
struct EnergySearchMetricV2
    metric_id::String
    value::Union{Nothing,Float64}
    unit::String
    evidence_hash::String
    metric_hash::String
end

"High-fidelity feedback may prioritize evidence acquisition and nothing else."
struct HighFidelityAcquisitionSignalV2
    task_id::String
    expected_information_gain::Float64
    normalized_cost::Float64
    source_hash::String
    signal_hash::String
end

struct EnergySearchInputV2
    state::C2CandidateStatePackageV1
    topology::Stage34TopologyCompilationV2
    decision::C2DecisionEnvelope
    net_power_interval::Union{Nothing,C2UncertaintyIntervalEvidenceV1}
    metrics::Vector{EnergySearchMetricV2}
    acquisition_signals::Vector{HighFidelityAcquisitionSignalV2}
end

struct EnergySearchEntryV2
    candidate_binding_hash::String
    state_package_hash::String
    topology_compilation_hash::String
    decision_hash::String
    disposition::Symbol
    gate_audits::Vector{Dict{String,Any}}
    objective_coordinates::Vector{Dict{String,Any}}
    evidence_tasks::Vector{String}
    acquisition_priority_tasks::Vector{String}
    entry_hash::String
end

struct HierarchicalEnergySearchResultV2
    schema_version::String
    objective_specs::Vector{EnergyObjectiveSpecV1}
    entries::Vector{EnergySearchEntryV2}
    priority_front_binding_hashes::Vector{String}
    topology_rejected_binding_hashes::Vector{String}
    topology_unsupported_binding_hashes::Vector{String}
    c2_terminated_binding_hashes::Vector{String}
    evidence_queue_binding_hashes::Vector{String}
    engineering_rejected_binding_hashes::Vector{String}
    net_power_shortfall_binding_hashes::Vector{String}
    uncertainty_crosses_zero_binding_hashes::Vector{String}
    target_shortfall_binding_hashes::Vector{String}
    scalar_score_used::Bool
    proxy_feasibility_credit_used::Bool
    high_fidelity_feedback_role::String
    search_hash::String
end

function compile_energy_search_metric_v2(metric_id::AbstractString,
        value::Union{Nothing,Real}, unit::AbstractString, evidence_hash::AbstractString)
    id, units = String(metric_id), String(unit)
    all(!isempty, (id, units)) || throw(ArgumentError("metric id and unit are required"))
    number = value === nothing ? nothing : Float64(value)
    number === nothing || isfinite(number) || throw(ArgumentError(
        "energy metric value must be finite"))
    evidence = _c2_check_hash_v1(evidence_hash, "energy metric evidence hash")
    core = Dict{String,Any}("metric_id" => id, "value" => number,
        "unit" => units, "evidence_hash" => evidence)
    return EnergySearchMetricV2(id, number, units, evidence, canonical_hash(core))
end

function compile_high_fidelity_acquisition_signal_v2(task_id::AbstractString;
        expected_information_gain::Real, normalized_cost::Real,
        source_hash::AbstractString)
    id = String(task_id); isempty(id) && throw(ArgumentError("acquisition task id is required"))
    gain, cost = Float64(expected_information_gain), Float64(normalized_cost)
    isfinite(gain) && gain >= 0 || throw(ArgumentError(
        "expected information gain must be finite and nonnegative"))
    isfinite(cost) && cost > 0 || throw(ArgumentError(
        "normalized acquisition cost must be positive and finite"))
    source = _c2_check_hash_v1(source_hash, "acquisition signal source hash")
    core = Dict{String,Any}("task_id" => id, "expected_information_gain" => gain,
        "normalized_cost" => cost, "source_hash" => source,
        "role" => "evidence_acquisition_only")
    return HighFidelityAcquisitionSignalV2(id, gain, cost, source,
        canonical_hash(core))
end

function compile_energy_search_input_v2(state::C2CandidateStatePackageV1,
        topology::Stage34TopologyCompilationV2, decision::C2DecisionEnvelope;
        net_power_interval::Union{Nothing,C2UncertaintyIntervalEvidenceV1} = nothing,
        metrics::Vector{EnergySearchMetricV2} = EnergySearchMetricV2[],
        acquisition_signals::Vector{HighFidelityAcquisitionSignalV2} =
            HighFidelityAcquisitionSignalV2[])
    state.candidate_binding_hash == topology.candidate_binding_hash ==
        decision.candidate_binding_hash || throw(ArgumentError(
        "energy search input candidate binding mismatch"))
    state.package_hash == topology.state_package_hash == decision.state_package_hash ||
        throw(ArgumentError("energy search input state package mismatch"))
    metric_ids = getfield.(metrics, :metric_id)
    length(unique(metric_ids)) == length(metric_ids) || throw(ArgumentError(
        "energy search metric ids must be unique"))
    task_ids = getfield.(acquisition_signals, :task_id)
    length(unique(task_ids)) == length(task_ids) || throw(ArgumentError(
        "acquisition task ids must be unique"))
    if net_power_interval !== nothing
        net_power_interval.candidate_binding_hash == state.candidate_binding_hash ||
            throw(ArgumentError("net-power interval candidate binding mismatch"))
        net_power_interval.state_result_hash == state.state_result_hash ||
            throw(ArgumentError("net-power interval solved-state mismatch"))
        net_power_interval.quantity_id == "net_electric_lower_bound" ||
            throw(ArgumentError("net-power interval quantity must be net_electric_lower_bound"))
        net_power_interval.unit == "W" || throw(ArgumentError(
            "net-power interval unit must be W"))
    end
    return EnergySearchInputV2(state, topology, decision, net_power_interval,
        sort!(copy(metrics); by = item -> item.metric_id),
        sort!(copy(acquisition_signals); by = item -> item.task_id))
end

function _energy_v2_value_map(input::EnergySearchInputV2)
    values = Dict{String,Dict{String,Any}}()
    for item in vcat(input.state.energy_accounts, input.state.power_ledger.accounts)
        haskey(values, item.field_id) && throw(ArgumentError(
            "duplicate energy-search quantity id: $(item.field_id)"))
        values[item.field_id] = Dict{String,Any}("value" => item.value,
            "unit" => item.unit, "evidence_hash" => item.evidence_hash)
    end
    for item in input.metrics
        haskey(values, item.metric_id) && throw(ArgumentError(
            "metric conflicts with state quantity id: $(item.metric_id)"))
        values[item.metric_id] = Dict{String,Any}("value" => item.value,
            "unit" => item.unit, "evidence_hash" => item.evidence_hash)
    end
    return values
end

function _energy_v2_coordinates(input::EnergySearchInputV2,
        objectives::Vector{EnergyObjectiveSpecV1})
    values = _energy_v2_value_map(input); coordinates = Dict{String,Any}[]
    tasks = String[]
    for objective in objectives
        if !haskey(values, objective.account_id)
            push!(tasks, "provide_energy_search_quantity:$(objective.account_id)")
            continue
        end
        quantity = values[objective.account_id]
        if quantity["value"] === nothing
            push!(tasks, "provide_energy_search_value:$(objective.account_id)")
            continue
        elseif quantity["unit"] != objective.unit
            push!(tasks, "repair_energy_search_unit:$(objective.account_id):$(quantity["unit"])_to_$(objective.unit)")
            continue
        end
        value = Float64(quantity["value"])
        satisfied = objective.sense == :maximize ? value >= objective.target :
            value <= objective.target
        coordinate = objective.sense == :maximize ? -value / objective.scale :
            value / objective.scale
        push!(coordinates, Dict{String,Any}("objective_id" => objective.objective_id,
            "quantity_id" => objective.account_id, "sense" => String(objective.sense),
            "tier" => objective.tier, "value" => value, "unit" => objective.unit,
            "target" => objective.target, "target_satisfied" => satisfied,
            "normalized_minimization_coordinate" => coordinate,
            "evidence_hash" => quantity["evidence_hash"]))
    end
    return sort!(coordinates; by = item -> item["objective_id"]), sort!(unique(tasks))
end

function _energy_v2_acquisition_priority(input::EnergySearchInputV2,
        allowed_tasks::Vector{String})
    allowed = Set(allowed_tasks)
    signals = filter(item -> item.task_id in allowed, input.acquisition_signals)
    sort!(signals; by = item -> (-item.expected_information_gain /
        item.normalized_cost, item.task_id))
    return getfield.(signals, :task_id)
end

function _energy_v2_entry(input::EnergySearchInputV2,
        objectives::Vector{EnergyObjectiveSpecV1})
    state, topology, decision = input.state, input.topology, input.decision
    audits = Dict{String,Any}[]; tasks = String[]; coordinates = Dict{String,Any}[]
    topology_pass = topology.status == :pass
    push!(audits, Dict{String,Any}("gate_id" => "topology_compile",
        "status" => String(topology.status), "passed" => topology_pass,
        "evidence_hash" => topology.compilation_hash))
    !topology_pass && append!(tasks, topology.reasons)

    terminal = decision.terminate && decision.candidate_conclusion == :fail
    push!(audits, Dict{String,Any}("gate_id" => "c2_terminal_failure",
        "status" => terminal ? "fail" : "pass", "passed" => !terminal,
        "evidence_hash" => decision.decision_hash))
    complete_c2 = decision.completeness == :complete &&
        decision.candidate_conclusion == :pass
    push!(audits, Dict{String,Any}("gate_id" => "complete_c2",
        "status" => complete_c2 ? "pass" : String(decision.completeness),
        "passed" => complete_c2, "evidence_hash" => decision.decision_hash))
    !complete_c2 && append!(tasks, [task for gate in decision.gate_decisions
        for task in gate.evidence_tasks])

    engineering = filter(gate -> gate.gate_id == "engineering", decision.gate_decisions)
    engineering_pass = length(engineering) == 1 && only(engineering).completeness == :complete &&
        only(engineering).conclusion == :pass
    engineering_failed = any(gate -> gate.completeness == :complete &&
        gate.conclusion == :fail, engineering)
    push!(audits, Dict{String,Any}("gate_id" => "engineering",
        "status" => engineering_pass ? "pass" : engineering_failed ? "fail" : "unknown",
        "passed" => engineering_pass,
        "evidence_hashes" => isempty(engineering) ? String[] : only(engineering).evidence_hashes))
    !engineering_pass && push!(tasks, "complete_candidate_bound_engineering_gate")

    power = filter(item -> item.field_id == "net_electric_lower_bound",
        state.power_ledger.accounts)
    net_value = length(power) == 1 ? only(power).value : nothing
    net_unit_ok = length(power) == 1 && only(power).unit == "W"
    net_positive = net_unit_ok && net_value !== nothing && net_value > 0
    push!(audits, Dict{String,Any}("gate_id" => "positive_net_electric_lower_bound",
        "status" => net_positive ? "pass" : net_value === nothing ? "unknown" : "fail",
        "passed" => net_positive, "value" => net_value, "unit" =>
            length(power) == 1 ? only(power).unit : nothing,
        "evidence_hash" => length(power) == 1 ? only(power).evidence_hash : nothing))
    length(power) == 1 || push!(tasks, "provide_unique_net_electric_lower_bound")
    net_value === nothing && push!(tasks, "provide_net_electric_lower_bound_value")
    !net_unit_ok && push!(tasks, "repair_net_electric_lower_bound_unit_to_W")

    interval = input.net_power_interval
    interval_positive = interval !== nothing && interval.lower > 0
    push!(audits, Dict{String,Any}("gate_id" => "net_power_uncertainty_sign",
        "status" => interval === nothing ? "unknown" : interval_positive ? "pass" : "fail",
        "passed" => interval_positive, "lower" => interval === nothing ? nothing : interval.lower,
        "upper" => interval === nothing ? nothing : interval.upper,
        "evidence_hash" => interval === nothing ? nothing : interval.interval_hash))
    interval === nothing && push!(tasks,
        "acquire_candidate_bound_net_electric_lower_bound_uncertainty_interval")

    disposition = if terminal
        :c2_terminated
    elseif topology.status == :fail
        :topology_rejected
    elseif topology.status == :unsupported
        :topology_unsupported
    elseif topology.status != :pass || !complete_c2
        :evidence_queue
    elseif engineering_failed
        :engineering_rejected
    elseif !engineering_pass
        :evidence_queue
    elseif !net_positive
        net_value === nothing || !net_unit_ok ? :evidence_queue : :net_power_shortfall
    elseif interval === nothing
        :evidence_queue
    elseif !interval_positive
        :uncertainty_crosses_zero
    else
        coordinates, coordinate_tasks = _energy_v2_coordinates(input, objectives)
        append!(tasks, coordinate_tasks)
        if !isempty(coordinate_tasks) || length(coordinates) != length(objectives)
            :evidence_queue
        elseif all(item -> item["target_satisfied"] === true, coordinates)
            :rankable
        else
            :target_shortfall
        end
    end
    disposition in _ENERGY_V2_DISPOSITIONS || error("invalid energy disposition")
    tasks = sort!(unique(tasks))
    priority_tasks = disposition in (:evidence_queue, :topology_unsupported) ?
        _energy_v2_acquisition_priority(input, tasks) : String[]
    core = Dict{String,Any}("candidate_binding_hash" => state.candidate_binding_hash,
        "state_package_hash" => state.package_hash,
        "topology_compilation_hash" => topology.compilation_hash,
        "decision_hash" => decision.decision_hash, "disposition" => String(disposition),
        "gate_audits" => audits, "objective_coordinates" => coordinates,
        "evidence_tasks" => tasks, "acquisition_priority_tasks" => priority_tasks,
        "proxy_feasibility_credit_used" => false)
    return EnergySearchEntryV2(state.candidate_binding_hash, state.package_hash,
        topology.compilation_hash, decision.decision_hash, disposition, audits,
        coordinates, tasks, priority_tasks, canonical_hash(core))
end

function _energy_v2_tier_dominates(a::EnergySearchEntryV2,
        b::EnergySearchEntryV2, tier::Int)
    av = Dict(String(item["objective_id"]) =>
        Float64(item["normalized_minimization_coordinate"])
        for item in a.objective_coordinates if Int(item["tier"]) == tier)
    bv = Dict(String(item["objective_id"]) =>
        Float64(item["normalized_minimization_coordinate"])
        for item in b.objective_coordinates if Int(item["tier"]) == tier)
    ids = sort!(collect(keys(av)))
    ids == sort!(collect(keys(bv))) || throw(ArgumentError(
        "energy entries have inconsistent objective coordinates"))
    isempty(ids) && return false
    return all(av[id] <= bv[id] for id in ids) && any(av[id] < bv[id] for id in ids)
end

function search_hierarchical_energy_targets_v2(inputs::Vector{EnergySearchInputV2},
        objectives::Vector{EnergyObjectiveSpecV1})
    isempty(inputs) && throw(ArgumentError("energy target search requires inputs"))
    isempty(objectives) && throw(ArgumentError("energy target search requires objectives"))
    objective_ids = getfield.(objectives, :objective_id)
    length(unique(objective_ids)) == length(objective_ids) || throw(ArgumentError(
        "energy objective ids must be unique"))
    bindings = getfield.(getfield.(inputs, :state), :candidate_binding_hash)
    length(unique(bindings)) == length(bindings) || throw(ArgumentError(
        "energy search candidate bindings must be unique"))
    ordered = sort!(copy(objectives); by = item -> (item.tier, item.objective_id))
    entries = sort!([_energy_v2_entry(input, ordered) for input in inputs];
        by = item -> item.candidate_binding_hash)
    active = filter(item -> item.disposition == :rankable, entries)
    for tier in sort!(unique(getfield.(ordered, :tier)))
        active = EnergySearchEntryV2[item for item in active if !any(other ->
            other.entry_hash != item.entry_hash && _energy_v2_tier_dominates(other, item, tier),
            active)]
    end
    by_status(status) = sort!(String[item.candidate_binding_hash for item in entries
        if item.disposition == status])
    priority = sort!(getfield.(active, :candidate_binding_hash))
    buckets = [by_status(status) for status in (:topology_rejected,
        :topology_unsupported, :c2_terminated, :evidence_queue,
        :engineering_rejected, :net_power_shortfall, :uncertainty_crosses_zero,
        :target_shortfall)]
    core = Dict{String,Any}("schema_version" => "2.0.0",
        "objective_hashes" => getfield.(ordered, :objective_hash),
        "entry_hashes" => getfield.(entries, :entry_hash),
        "priority_front_binding_hashes" => priority,
        "disposition_binding_hashes" => buckets, "scalar_score_used" => false,
        "proxy_feasibility_credit_used" => false,
        "high_fidelity_feedback_role" => "evidence_acquisition_only")
    return HierarchicalEnergySearchResultV2("2.0.0", ordered, entries, priority,
        buckets[1], buckets[2], buckets[3], buckets[4], buckets[5], buckets[6],
        buckets[7], buckets[8], false, false, "evidence_acquisition_only",
        canonical_hash(core))
end

function energy_search_result_to_dict_v2(item::HierarchicalEnergySearchResultV2)
    objectives = [Dict{String,Any}("objective_id" => objective.objective_id,
        "quantity_id" => objective.account_id, "sense" => String(objective.sense),
        "tier" => objective.tier, "target" => objective.target,
        "scale" => objective.scale, "unit" => objective.unit,
        "objective_hash" => objective.objective_hash) for objective in item.objective_specs]
    entries = [Dict{String,Any}("candidate_binding_hash" => entry.candidate_binding_hash,
        "state_package_hash" => entry.state_package_hash,
        "topology_compilation_hash" => entry.topology_compilation_hash,
        "decision_hash" => entry.decision_hash, "disposition" => String(entry.disposition),
        "gate_audits" => entry.gate_audits,
        "objective_coordinates" => entry.objective_coordinates,
        "evidence_tasks" => entry.evidence_tasks,
        "acquisition_priority_tasks" => entry.acquisition_priority_tasks,
        "entry_hash" => entry.entry_hash) for entry in item.entries]
    return Dict{String,Any}("schema_version" => item.schema_version,
        "objective_specs" => objectives, "entries" => entries,
        "priority_front_binding_hashes" => item.priority_front_binding_hashes,
        "topology_rejected_binding_hashes" => item.topology_rejected_binding_hashes,
        "topology_unsupported_binding_hashes" => item.topology_unsupported_binding_hashes,
        "c2_terminated_binding_hashes" => item.c2_terminated_binding_hashes,
        "evidence_queue_binding_hashes" => item.evidence_queue_binding_hashes,
        "engineering_rejected_binding_hashes" => item.engineering_rejected_binding_hashes,
        "net_power_shortfall_binding_hashes" => item.net_power_shortfall_binding_hashes,
        "uncertainty_crosses_zero_binding_hashes" =>
            item.uncertainty_crosses_zero_binding_hashes,
        "target_shortfall_binding_hashes" => item.target_shortfall_binding_hashes,
        "scalar_score_used" => item.scalar_score_used,
        "proxy_feasibility_credit_used" => item.proxy_feasibility_credit_used,
        "high_fidelity_feedback_role" => item.high_fidelity_feedback_role,
        "search_hash" => item.search_hash)
end
