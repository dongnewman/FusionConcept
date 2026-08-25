struct EnergyObjectiveSpecV1
    objective_id::String
    account_id::String
    sense::Symbol
    tier::Int
    target::Float64
    scale::Float64
    unit::String
    objective_hash::String
end

struct EnergySearchInputV1
    state::C2CandidateStatePackageV1
    topology::Stage34TopologyCompilationV1
    decision::C2DecisionEnvelope
end

struct EnergySearchEntryV1
    candidate_binding_hash::String
    state_package_hash::String
    topology_compilation_hash::String
    decision_hash::String
    disposition::Symbol
    objective_coordinates::Vector{Dict{String,Any}}
    evidence_tasks::Vector{String}
    entry_hash::String
end

struct HierarchicalEnergySearchResultV1
    schema_version::String
    objective_specs::Vector{EnergyObjectiveSpecV1}
    entries::Vector{EnergySearchEntryV1}
    priority_front_binding_hashes::Vector{String}
    target_shortfall_binding_hashes::Vector{String}
    c2_terminated_binding_hashes::Vector{String}
    evidence_queue_binding_hashes::Vector{String}
    topology_rejected_binding_hashes::Vector{String}
    scalar_score_used::Bool
    search_hash::String
end

function compile_energy_objective_spec_v1(objective_id::AbstractString,
        account_id::AbstractString, sense::Symbol; tier::Integer, target::Real,
        scale::Real, unit::AbstractString)
    all(!isempty, (objective_id, account_id, unit)) || throw(ArgumentError(
        "energy objective identifiers and unit cannot be empty"))
    sense in (:minimize, :maximize) || throw(ArgumentError(
        "energy objective sense must be minimize or maximize"))
    tier >= 1 || throw(ArgumentError("energy objective tier must be positive"))
    target_value, scale_value = Float64(target), Float64(scale)
    isfinite(target_value) || throw(ArgumentError("energy objective target must be finite"))
    isfinite(scale_value) && scale_value > 0 || throw(ArgumentError(
        "energy objective scale must be positive and finite"))
    core = Dict{String,Any}("objective_id" => String(objective_id),
        "account_id" => String(account_id), "sense" => String(sense),
        "tier" => Int(tier), "target" => target_value, "scale" => scale_value,
        "unit" => String(unit))
    return EnergyObjectiveSpecV1(String(objective_id), String(account_id), sense,
        Int(tier), target_value, scale_value, String(unit), canonical_hash(core))
end

function compile_energy_search_input_v1(state::C2CandidateStatePackageV1,
        topology::Stage34TopologyCompilationV1, decision::C2DecisionEnvelope)
    state.candidate_binding_hash == topology.candidate_binding_hash ==
        decision.candidate_binding_hash || throw(ArgumentError(
        "energy search input candidate binding mismatch"))
    state.package_hash == topology.state_package_hash == decision.state_package_hash ||
        throw(ArgumentError("energy search input state package mismatch"))
    return EnergySearchInputV1(state, topology, decision)
end

function _energy_quantity_map_v1(state::C2CandidateStatePackageV1)
    values = Dict{String,C2QuantityFieldV1}()
    for item in vcat(state.energy_accounts, state.power_ledger.accounts)
        haskey(values, item.field_id) && throw(ArgumentError(
            "duplicate energy-search account id: $(item.field_id)"))
        values[item.field_id] = item
    end
    return values
end

function _energy_coordinates_v1(state::C2CandidateStatePackageV1,
        objectives::Vector{EnergyObjectiveSpecV1})
    quantities = _energy_quantity_map_v1(state)
    coordinates = Dict{String,Any}[]
    tasks = String[]
    for objective in objectives
        if !haskey(quantities, objective.account_id)
            push!(tasks, "provide_energy_account:$(objective.account_id)")
            continue
        end
        quantity = quantities[objective.account_id]
        if quantity.value === nothing
            push!(tasks, "provide_energy_account_value:$(objective.account_id)")
            continue
        end
        if quantity.unit != objective.unit
            push!(tasks, "repair_energy_account_unit:$(objective.account_id):$(quantity.unit)_to_$(objective.unit)")
            continue
        end
        satisfied = objective.sense == :maximize ? quantity.value >= objective.target :
            quantity.value <= objective.target
        coordinate = objective.sense == :maximize ? -quantity.value / objective.scale :
            quantity.value / objective.scale
        push!(coordinates, Dict{String,Any}(
            "objective_id" => objective.objective_id,
            "account_id" => objective.account_id, "sense" => String(objective.sense),
            "tier" => objective.tier, "value" => quantity.value, "unit" => quantity.unit,
            "target" => objective.target, "target_satisfied" => satisfied,
            "normalized_minimization_coordinate" => coordinate,
            "evidence_hash" => quantity.evidence_hash))
    end
    return sort!(coordinates; by = item -> item["objective_id"]), sort!(unique(tasks))
end

function _energy_search_entry_v1(input::EnergySearchInputV1,
        objectives::Vector{EnergyObjectiveSpecV1})
    state, topology, decision = input.state, input.topology, input.decision
    coordinates = Dict{String,Any}[]
    tasks = String[]
    disposition = if topology.status != :pass
        append!(tasks, topology.reasons)
        :topology_rejected
    elseif decision.completeness == :unsupported ||
            decision.candidate_conclusion == :unsupported
        append!(tasks, [task for gate in decision.gate_decisions for task in gate.evidence_tasks])
        :evidence_queue
    elseif decision.completeness != :complete ||
            decision.candidate_conclusion == :unknown
        append!(tasks, [task for gate in decision.gate_decisions for task in gate.evidence_tasks])
        :evidence_queue
    elseif decision.candidate_conclusion == :fail
        :c2_terminated
    else
        coordinates, coordinate_tasks = _energy_coordinates_v1(state, objectives)
        append!(tasks, coordinate_tasks)
        if !isempty(tasks) || length(coordinates) != length(objectives)
            :evidence_queue
        elseif all(item -> item["target_satisfied"] === true, coordinates)
            :rankable
        else
            :target_shortfall
        end
    end
    core = Dict{String,Any}("candidate_binding_hash" => state.candidate_binding_hash,
        "state_package_hash" => state.package_hash,
        "topology_compilation_hash" => topology.compilation_hash,
        "decision_hash" => decision.decision_hash, "disposition" => String(disposition),
        "objective_coordinates" => coordinates, "evidence_tasks" => sort!(unique(tasks)))
    return EnergySearchEntryV1(state.candidate_binding_hash, state.package_hash,
        topology.compilation_hash, decision.decision_hash, disposition, coordinates,
        sort!(unique(tasks)), canonical_hash(core))
end

function _energy_tier_dominates_v1(a::EnergySearchEntryV1,
        b::EnergySearchEntryV1, tier::Int)
    av = Dict(String(item["objective_id"]) =>
        Float64(item["normalized_minimization_coordinate"])
        for item in a.objective_coordinates if Int(item["tier"]) == tier)
    bv = Dict(String(item["objective_id"]) =>
        Float64(item["normalized_minimization_coordinate"])
        for item in b.objective_coordinates if Int(item["tier"]) == tier)
    keys_a = sort!(collect(keys(av)))
    keys_a == sort!(collect(keys(bv))) || throw(ArgumentError(
        "energy entries have inconsistent objective coordinates"))
    isempty(keys_a) && return false
    return all(av[id] <= bv[id] for id in keys_a) &&
        any(av[id] < bv[id] for id in keys_a)
end

function _energy_nondominated_front_v1(entries::Vector{EnergySearchEntryV1}, tier::Int)
    return EnergySearchEntryV1[item for item in entries if !any(other ->
        other.entry_hash != item.entry_hash && _energy_tier_dominates_v1(other, item, tier),
        entries)]
end

function search_hierarchical_energy_targets_v1(inputs::Vector{EnergySearchInputV1},
        objectives::Vector{EnergyObjectiveSpecV1})
    isempty(inputs) && throw(ArgumentError("energy target search requires inputs"))
    isempty(objectives) && throw(ArgumentError("energy target search requires objectives"))
    objective_ids = getfield.(objectives, :objective_id)
    length(unique(objective_ids)) == length(objective_ids) || throw(ArgumentError(
        "energy objective ids must be unique"))
    binding_ids = getfield.(getfield.(inputs, :state), :candidate_binding_hash)
    length(unique(binding_ids)) == length(binding_ids) || throw(ArgumentError(
        "energy search candidate bindings must be unique"))
    ordered_objectives = sort!(copy(objectives); by = item -> (item.tier, item.objective_id))
    entries = sort!([_energy_search_entry_v1(input, ordered_objectives)
        for input in inputs]; by = item -> item.candidate_binding_hash)
    active = filter(item -> item.disposition == :rankable, entries)
    for tier in sort!(unique(getfield.(ordered_objectives, :tier)))
        active = _energy_nondominated_front_v1(active, tier)
    end
    bindings(disposition) = sort!(String[item.candidate_binding_hash for item in entries
        if item.disposition == disposition])
    priority = sort!(getfield.(active, :candidate_binding_hash))
    target_shortfall = bindings(:target_shortfall)
    terminated = bindings(:c2_terminated)
    evidence_queue = bindings(:evidence_queue)
    rejected = bindings(:topology_rejected)
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "objective_hashes" => getfield.(ordered_objectives, :objective_hash),
        "entry_hashes" => getfield.(entries, :entry_hash),
        "priority_front_binding_hashes" => priority,
        "target_shortfall_binding_hashes" => target_shortfall,
        "c2_terminated_binding_hashes" => terminated,
        "evidence_queue_binding_hashes" => evidence_queue,
        "topology_rejected_binding_hashes" => rejected,
        "scalar_score_used" => false)
    return HierarchicalEnergySearchResultV1("1.0.0", ordered_objectives, entries,
        priority, target_shortfall, terminated, evidence_queue, rejected, false,
        canonical_hash(core))
end

function energy_search_result_to_dict_v1(item::HierarchicalEnergySearchResultV1)
    objective_dicts = [Dict{String,Any}("objective_id" => objective.objective_id,
        "account_id" => objective.account_id, "sense" => String(objective.sense),
        "tier" => objective.tier, "target" => objective.target,
        "scale" => objective.scale, "unit" => objective.unit,
        "objective_hash" => objective.objective_hash) for objective in item.objective_specs]
    entry_dicts = [Dict{String,Any}(
        "candidate_binding_hash" => entry.candidate_binding_hash,
        "state_package_hash" => entry.state_package_hash,
        "topology_compilation_hash" => entry.topology_compilation_hash,
        "decision_hash" => entry.decision_hash, "disposition" => String(entry.disposition),
        "objective_coordinates" => entry.objective_coordinates,
        "evidence_tasks" => entry.evidence_tasks, "entry_hash" => entry.entry_hash)
        for entry in item.entries]
    return Dict{String,Any}("schema_version" => item.schema_version,
        "objective_specs" => objective_dicts, "entries" => entry_dicts,
        "priority_front_binding_hashes" => item.priority_front_binding_hashes,
        "target_shortfall_binding_hashes" => item.target_shortfall_binding_hashes,
        "c2_terminated_binding_hashes" => item.c2_terminated_binding_hashes,
        "evidence_queue_binding_hashes" => item.evidence_queue_binding_hashes,
        "topology_rejected_binding_hashes" => item.topology_rejected_binding_hashes,
        "scalar_score_used" => item.scalar_score_used, "search_hash" => item.search_hash)
end
