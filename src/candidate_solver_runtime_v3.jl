const _CSR_V3_ALLOWED_STATUS = Set([:pass, :fail, :unknown, :unsupported])

"Hash-sealed regional balance and actuator-demand realization result."
struct RegionalCoupledSolveEnvelopeV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    manifest_hash::String
    state_result_hash::String
    status::Symbol
    convergence_status::String
    dependency_graph::Dict{String,Any}
    region_states::Vector{Dict{String,Any}}
    interface_fluxes::Vector{Dict{String,Any}}
    actuator_demands::Vector{Dict{String,Any}}
    actuator_outputs::Vector{Dict{String,Any}}
    residual_history::Vector{Dict{String,Any}}
    conservation_slots::Vector{Dict{String,Any}}
    evidence_ceiling::String
    unresolved_reasons::Vector{String}
    result_hash::String
end

"Strict plant-power aggregation with explicit completeness for every applicable role."
struct PlantPowerLedgerV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    state_result_hash::String
    transport_result_hash::String
    engineering_result_hash::String
    coupled_result_hash::String
    time_basis::Dict{String,Any}
    plant_roles::Vector{Dict{String,Any}}
    terms::Vector{Dict{String,Any}}
    gross_electric_power_w::Union{Nothing,Float64}
    direct_recovery_power_w::Union{Nothing,Float64}
    recirculating_power_w::Union{Nothing,Float64}
    reported_net_power_w::Union{Nothing,Float64}
    status::Symbol
    sign_status::String
    closure::Dict{String,Any}
    evidence_ceiling::String
    result_hash::String
end

function _csr_v3_power_w(value, unit)
    scale = get(Dict("W" => 1.0, "kW" => 1.0e3, "MW" => 1.0e6,
        "GW" => 1.0e9), String(unit), nothing)
    scale === nothing && return nothing
    numeric = Float64(value)
    return isfinite(numeric) ? numeric * scale : nothing
end

function _csr_v3_energy_j(value, unit)
    scale = get(Dict("J" => 1.0, "eV" => _CSR_V1_E_CHARGE,
        "keV" => 1.0e3 * _CSR_V1_E_CHARGE,
        "MeV" => 1.0e6 * _CSR_V1_E_CHARGE), String(unit), nothing)
    scale === nothing && return nothing
    numeric = Float64(value)
    return isfinite(numeric) ? numeric * scale : nothing
end

function _csr_v3_efficiency(parameters, tokens)
    values = Float64[]
    for (id, quantity) in parameters
        key = lowercase(String(id))
        quantity.unit == "1" || continue
        any(token -> occursin(token, key), tokens) || continue
        0.0 < quantity.value <= 1.0 && isfinite(quantity.value) &&
            push!(values, Float64(quantity.value))
    end
    return isempty(values) ? nothing : minimum(values)
end

function _csr_v3_actuator_contract(actuator::Actuator)
    power_capacity = 0.0
    power_found = false
    particle_capacity = 0.0
    particle_found = false
    beam_energy = nothing
    response_time = nothing
    parameter_records = Dict{String,Any}[]
    for (id, quantity) in actuator.parameters
        key = lowercase(String(id))
        push!(parameter_records, Dict("id" => String(id), "value" => quantity.value,
            "unit" => quantity.unit))
        if occursin("power", key)
            converted = _csr_v3_power_w(quantity.value, quantity.unit)
            converted === nothing || begin
                power_capacity += max(0.0, converted)
                power_found = true
            end
        end
        if occursin("rate", key) && quantity.unit in ("1/s", "s^-1")
            particle_capacity += max(0.0, Float64(quantity.value))
            particle_found = true
        end
        if occursin("energy", key)
            converted = _csr_v3_energy_j(quantity.value, quantity.unit)
            converted === nothing || (beam_energy = converted)
        end
        if any(token -> occursin(token, key), ("response", "rise_time", "time_constant")) &&
                quantity.unit == "s" && quantity.value >= 0.0
            response_time = Float64(quantity.value)
        end
    end
    kind = lowercase(actuator.kind)
    deposition_efficiency = _csr_v3_efficiency(actuator.parameters,
        ("deposition", "coupling", "absorption"))
    wall_plug_efficiency = _csr_v3_efficiency(actuator.parameters,
        ("wall_plug", "wallplug", "electrical_efficiency"))
    if !particle_found && power_found && beam_energy isa Real && beam_energy > 0.0 &&
            any(token -> occursin(token, kind), ("beam", "inject", "nbi"))
        particle_capacity = power_capacity / beam_energy
        particle_found = true
    end
    capabilities = String[]
    power_found && push!(capabilities, "deposited_energy_source")
    particle_found && push!(capabilities, "particle_source")
    any(token -> occursin(token, kind), ("exhaust", "pump", "divert")) &&
        push!(capabilities, "particle_sink")
    body = Dict{String,Any}(
        "actuator_id" => actuator.id, "declared_kind" => actuator.kind,
        "provided_capabilities" => sort!(unique(capabilities)),
        "plasma_side_power_capacity_w" => power_found ? power_capacity : nothing,
        "particle_rate_capacity_per_s" => particle_found ? particle_capacity : nothing,
        "deposition_efficiency" => deposition_efficiency,
        "wall_plug_efficiency" => wall_plug_efficiency,
        "dynamic_response_time_s" => response_time,
        "parameters" => sort!(parameter_records; by = item -> String(item["id"])),
        "capacity_basis" => power_found ?
            "candidate-declared actuator power; no family default" :
            particle_found ? "candidate-declared or power/particle-energy-derived rate" :
            "no supported numeric capacity")
    body["contract_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

const _CSR_V3_PLANT_ROLE_TOKENS = Dict(
    "magnet_power_supplies" => ("magnet_power", "coil_power", "magnet_supply"),
    "cryogenic_system" => ("cryo", "refriger"),
    "vacuum_exhaust_pumping" => ("vacuum_power", "pump_power", "exhaust_power"),
    "coolant_heat_rejection" => ("coolant_power", "cooling_power", "heat_rejection"),
    "thermal_cycle_auxiliaries" => ("thermal_cycle", "balance_of_plant"),
    "fuel_processing" => ("fuel_processing", "tritium_processing", "pellet_factory"),
    "controls_diagnostics" => ("control_power", "diagnostic_power"),
    "target_factory" => ("target_factory", "target_manufacturing"),
)

function _csr_v3_declared_plant_roles(genome::Genome)
    roles = Dict{String,Float64}()
    collections = Any[genome.mission.targets]
    append!(collections, [item.parameters for item in genome.plasma_regions])
    append!(collections, [item.parameters for item in genome.field_sources])
    append!(collections, [item.parameters for item in genome.actuators])
    for parameters in collections, (id, quantity) in parameters
        power = _csr_v3_power_w(quantity.value, quantity.unit)
        power === nothing && continue
        key = lowercase(String(id))
        for (role, tokens) in _CSR_V3_PLANT_ROLE_TOKENS
            any(token -> occursin(token, key), tokens) || continue
            roles[role] = get(roles, role, 0.0) + max(0.0, power)
        end
    end
    return roles
end

function _csr_v3_named_efficiency(genome::Genome, tokens)
    collections = Any[genome.mission.targets]
    append!(collections, [item.parameters for item in genome.actuators])
    values = Float64[]
    for parameters in collections, (id, quantity) in parameters
        key = lowercase(String(id))
        quantity.unit == "1" && any(token -> occursin(token, key), tokens) &&
            0.0 < quantity.value <= 1.0 && push!(values, Float64(quantity.value))
    end
    return isempty(values) ? nothing : minimum(values)
end

"Compile explicit actuator and plant-role declarations without adding nominal values."
function candidate_runtime_parameters_v2(genome::Genome, module_ids)
    result = candidate_engineering_parameters_v1(genome, module_ids)
    result["actuator_contracts"] = [_csr_v3_actuator_contract(item)
        for item in genome.actuators]
    result["declared_plant_power_roles_w"] = _csr_v3_declared_plant_roles(genome)
    result["thermal_conversion_efficiency"] = _csr_v3_named_efficiency(genome,
        ("thermal_conversion", "electric_conversion"))
    result["direct_recovery_efficiency"] = _csr_v3_named_efficiency(genome,
        ("direct_conversion", "direct_recovery", "energy_recovery"))
    result["field_source_count"] = length(genome.field_sources)
    result["plasma_region_count"] = length(genome.plasma_regions)
    return result
end

function _csr_v3_binding_contract(binding)
    operator = String(binding["operator_id"])
    states = String.(get(binding, "state_ids", Any[]))
    provides = String["residual", "observables"]
    requires = String["state:$id" for id in states]
    if operator in ("state_derived_bohm_transport_l1_v1",
            "state_derived_parallel_streaming_l1_v1")
        append!(provides, ["boundary_flux:particles", "boundary_flux:energy"])
        append!(requires, ["parameter:finite_geometry", "parameter:absolute_temperature"])
    elseif operator == "state_derived_dt_reaction_bremsstrahlung_l1_v1"
        append!(provides, ["source:self_heating", "sink:burn", "sink:radiation"])
        push!(requires, "state:species_inventory")
    elseif startswith(operator, "control_volume_")
        push!(provides, "conservation_slot")
    end
    body = Dict{String,Any}("module_id" => String(binding["module_id"]),
        "capability_id" => String(binding["capability_id"]), "operator_id" => operator,
        "requires" => sort!(unique(requires)), "provides" => sort!(unique(provides)),
        "jacobian" => Dict("availability" => "finite_difference_block",
            "assembly" => "sparse_block_compatible"),
        "unit_convention" => "SI", "sign_convention" => "dU_dt + divergence_F - source_S")
    body["contract_hash"] = canonical_hash(body)
    return body
end

function _csr_v3_region_network(manifest::CandidateSolveManifestV1)
    state_ids = String[String(item["state_id"]) for item in manifest.state_variables]
    nodes = Dict{String,Any}[]
    for (index, region) in enumerate(manifest.regions)
        push!(nodes, Dict("region_id" => String(region["region_id"]),
            "kind" => String(get(region, "kind", "")),
            "geometry_model" => String(get(region, "geometry_model", "")),
            "state_ids" => index == 1 ? state_ids : String[],
            "state_partition_status" => index == 1 ? "primary_control_volume" :
                "unknown_missing_region_inventory_partition"))
    end
    edges = Dict{String,Any}[Dict("from_region_id" => String(item["from_region_id"]),
        "to_region_id" => String(item["to_region_id"]), "kind" => String(item["kind"]),
        "flux_partition_status" => "unknown_until_interface_operator_supplies_flux")
        for item in manifest.boundaries]
    isempty(nodes) || push!(edges, Dict("from_region_id" => String(nodes[1]["region_id"]),
        "to_region_id" => "__external_boundary__", "kind" => "transport_loss_boundary",
        "flux_partition_status" => "computed_from_selected_transport_operator"))
    complete = length(nodes) == 1
    return Dict{String,Any}("nodes" => nodes, "edges" => edges,
        "status" => complete ? "complete_single_declared_control_volume" :
            "unknown_missing_multi_region_state_partition",
        "routing_basis" => "declared regions, connections, capabilities and operator scope only")
end

"Add dependency contracts and an explicit declared-region network to the v2 manifest."
function compile_candidate_solve_manifest_v3(genome::Genome, module_ids;
        discretization_levels = [32], parameter_overrides = Dict{String,Any}())
    runtime_parameters = candidate_runtime_parameters_v2(genome, module_ids)
    merge!(runtime_parameters, _csr_v1_plain_dict(parameter_overrides))
    base = compile_candidate_solve_manifest_v2(genome, module_ids;
        discretization_levels = discretization_levels,
        parameter_overrides = runtime_parameters)
    state_ids = Set(String(item["state_id"]) for item in base.state_variables)
    capability_ids = Set(String(item["capability_id"])
        for item in base.capability_declarations)
    contracts = [_csr_v3_binding_contract(item) for item in base.module_bindings]
    compatibility_errors = String[]
    for item in base.module_bindings
        module_id = String(item["module_id"])
        String(item["capability_id"]) in capability_ids || push!(compatibility_errors,
            "binding $module_id requires an undeclared capability")
        missing = setdiff(Set(String.(get(item, "state_ids", Any[]))), state_ids)
        isempty(missing) || push!(compatibility_errors,
            "binding $module_id references missing states $(join(sort!(collect(missing)), ','))")
    end
    dependency_graph = Dict{String,Any}(
        "module_contracts" => contracts,
        "compatibility_status" => isempty(compatibility_errors) ? "compatible" : "unsupported",
        "compatibility_errors" => sort!(unique(compatibility_errors)),
        "matching_basis" => "requires/provides, region scope, state layout, time mode, units and signs",
        "nonrouting_fields" => ["family", "parent_family", "display_label"])
    parameters = deepcopy(base.parameters)
    parameters["capability_dependency_graph_v1"] = dependency_graph
    parameters["declared_region_network_v1"] = _csr_v3_region_network(base)
    applicability = deepcopy(base.applicability_scope)
    reasons = String.(get(applicability, "unsupported_reasons", String[]))
    append!(reasons, compatibility_errors)
    applicability["status"] = isempty(reasons) ? "applicable" : "unsupported"
    applicability["unsupported_reasons"] = sort!(unique(reasons))
    applicability["numeric_composition_status"] = dependency_graph["compatibility_status"]
    return CandidateSolveManifestV1(candidate_id = base.candidate_id,
        physics_hash = base.physics_hash, regions = base.regions, mesh = base.mesh,
        state_variables = base.state_variables,
        capability_declarations = base.capability_declarations,
        module_bindings = base.module_bindings, boundaries = base.boundaries,
        sources_sinks = base.sources_sinks, time_mode = base.time_mode,
        initial_conditions = base.initial_conditions,
        numerical_tolerances = base.numerical_tolerances,
        discretization_levels = base.discretization_levels,
        required_outputs = base.required_outputs,
        applicability_scope = applicability, parameters = parameters)
end

function _csr_v3_coupled_body(; manifest, result, status, convergence_status,
        dependency_graph, region_states, interface_fluxes, actuator_demands,
        actuator_outputs, residual_history, conservation_slots, evidence_ceiling,
        unresolved_reasons)
    return Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => manifest.candidate_id, "physics_hash" => manifest.physics_hash,
        "manifest_hash" => manifest.manifest_hash,
        "state_result_hash" => result.status == :unsupported ? "" : result.result_hash,
        "status" => String(status), "convergence_status" => convergence_status,
        "dependency_graph" => dependency_graph, "region_states" => region_states,
        "interface_fluxes" => interface_fluxes, "actuator_demands" => actuator_demands,
        "actuator_outputs" => actuator_outputs, "residual_history" => residual_history,
        "conservation_slots" => conservation_slots,
        "evidence_ceiling" => evidence_ceiling,
        "unresolved_reasons" => sort!(unique(String.(unresolved_reasons))))
end

function regional_coupled_solve_to_dict_v1(result::RegionalCoupledSolveEnvelopeV1)
    body = Dict{String,Any}("schema_version" => result.schema_version,
        "candidate_id" => result.candidate_id, "physics_hash" => result.physics_hash,
        "manifest_hash" => result.manifest_hash,
        "state_result_hash" => result.state_result_hash, "status" => String(result.status),
        "convergence_status" => result.convergence_status,
        "dependency_graph" => result.dependency_graph,
        "region_states" => result.region_states, "interface_fluxes" => result.interface_fluxes,
        "actuator_demands" => result.actuator_demands,
        "actuator_outputs" => result.actuator_outputs,
        "residual_history" => result.residual_history,
        "conservation_slots" => result.conservation_slots,
        "evidence_ceiling" => result.evidence_ceiling,
        "unresolved_reasons" => result.unresolved_reasons,
        "result_hash" => result.result_hash)
    return body
end

function _csr_v3_make_coupled(manifest, result; status, convergence_status,
        dependency_graph = Dict{String,Any}(), region_states = Dict{String,Any}[],
        interface_fluxes = Dict{String,Any}[], actuator_demands = Dict{String,Any}[],
        actuator_outputs = Dict{String,Any}[], residual_history = Dict{String,Any}[],
        conservation_slots = Dict{String,Any}[],
        evidence_ceiling = "L1_regional_actuator_coupling_only",
        unresolved_reasons = String[])
    status in _CSR_V3_ALLOWED_STATUS || throw(ArgumentError("invalid coupled status"))
    body = _csr_v3_coupled_body(; manifest, result, status, convergence_status,
        dependency_graph, region_states, interface_fluxes, actuator_demands,
        actuator_outputs, residual_history, conservation_slots, evidence_ceiling,
        unresolved_reasons)
    safe = _csr_v1_json_safe(body)
    hash = canonical_hash(safe)
    return RegionalCoupledSolveEnvelopeV1(safe["schema_version"], safe["candidate_id"],
        safe["physics_hash"], safe["manifest_hash"], safe["state_result_hash"], status,
        safe["convergence_status"], safe["dependency_graph"], safe["region_states"],
        safe["interface_fluxes"], safe["actuator_demands"], safe["actuator_outputs"],
        safe["residual_history"], safe["conservation_slots"], safe["evidence_ceiling"],
        safe["unresolved_reasons"], hash)
end

function _csr_v3_nonactuator_modules(manifest)
    modules = CandidatePhysicsModuleV1[]
    for item in _csr_v1_modules(manifest)
        parameters = deepcopy(item.parameters)
        item.operator_id == "control_volume_thermal_energy_v1" &&
            (parameters["input_power_w"] = 0.0)
        push!(modules, CandidatePhysicsModuleV1(item.module_id, item.capability_id,
            item.operator_id, item.state_ids, parameters))
    end
    return modules
end

function _csr_v3_allocate_outputs(contracts, demands)
    outputs = Dict{String,Any}[]
    totals = Dict("particle_inventory" => 0.0, "thermal_energy" => 0.0)
    evidence_complete = Dict("particle_inventory" => true, "thermal_energy" => true)
    for contract in contracts
        capabilities = Set(String.(get(contract, "provided_capabilities", Any[])))
        energy_capacity = get(contract, "plasma_side_power_capacity_w", nothing)
        particle_capacity = get(contract, "particle_rate_capacity_per_s", nothing)
        energy = "deposited_energy_source" in capabilities && energy_capacity isa Real ?
            max(0.0, Float64(energy_capacity)) : 0.0
        particles = "particle_source" in capabilities && particle_capacity isa Real ?
            max(0.0, Float64(particle_capacity)) : 0.0
        totals["thermal_energy"] += energy
        totals["particle_inventory"] += particles
        energy > 0.0 && get(contract, "wall_plug_efficiency", nothing) === nothing &&
            (evidence_complete["thermal_energy"] = false)
        body = Dict{String,Any}("actuator_id" => String(contract["actuator_id"]),
            "contract_hash" => String(contract["contract_hash"]),
            "provided_capabilities" => sort!(collect(capabilities)),
            "available_particle_rate_per_s" => particles,
            "available_deposited_power_w" => energy,
            "wall_plug_efficiency" => get(contract, "wall_plug_efficiency", nothing),
            "dynamic_response_time_s" => get(contract, "dynamic_response_time_s", nothing))
        push!(outputs, body)
    end
    for state_id in keys(totals)
        demand = get(demands, state_id, 0.0)
        capacity = totals[state_id]
        remaining = min(max(0.0, demand), capacity)
        available = sum(Float64(get(item, state_id == "thermal_energy" ?
            "available_deposited_power_w" : "available_particle_rate_per_s", 0.0))
            for item in outputs; init = 0.0)
        for item in outputs
            key = state_id == "thermal_energy" ? "available_deposited_power_w" :
                "available_particle_rate_per_s"
            output_key = state_id == "thermal_energy" ? "realized_deposited_power_w" :
                "realized_particle_rate_per_s"
            share = available > 0.0 ? Float64(item[key]) / available : 0.0
            item[output_key] = remaining * share
        end
    end
    for item in outputs
        item["output_hash"] = canonical_hash(_csr_v1_json_safe(item))
    end
    return outputs, totals, evidence_complete
end

"Iterate actual actuator outputs back into regional conservation slots."
function solve_region_actuator_coupling_v1(manifest::CandidateSolveManifestV1,
        result::SolverResultEnvelopeV1)
    dependency = deepcopy(get(manifest.parameters, "capability_dependency_graph_v1",
        Dict{String,Any}()))
    if result.status == :unsupported
        return _csr_v3_make_coupled(manifest, result; status = :unsupported,
            convergence_status = "not_run_state_problem_unsupported",
            dependency_graph = dependency, unresolved_reasons = result.unsupported_reasons,
            evidence_ceiling = "none_unsupported_problem")
    end
    state_ids = String[String(item["state_id"]) for item in manifest.state_variables]
    final_state = get(result.state_trajectory, "final_state", Dict{String,Any}())
    state = Float64[get(final_state, id, manifest.initial_conditions[id]) for id in state_ids]
    modules = _csr_v3_nonactuator_modules(manifest)
    physical_source, physical_flux = _csr_v1_source_flux(modules, state, 0.0, manifest)
    required_source = max.(physical_flux .- physical_source, 0.0)
    required_sink = max.(physical_source .- physical_flux, 0.0)
    if manifest.time_mode != "steady"
        thermal_index = findfirst(==("thermal_energy"), state_ids)
        thermal_index === nothing || (required_source[thermal_index] = max(0.0,
            Float64(get(manifest.parameters, "input_power_w", 0.0))))
    end
    demands_by_state = Dict(state_ids[index] => required_source[index]
        for index in eachindex(state_ids))
    contracts = Dict{String,Any}[_csr_v1_plain_dict(item)
        for item in get(manifest.parameters, "actuator_contracts", Any[])]
    outputs, capacities, evidence_complete = _csr_v3_allocate_outputs(contracts,
        demands_by_state)
    demand_records = Dict{String,Any}[]
    missing = String[]
    insufficient = String[]
    for (index, state_id) in enumerate(state_ids)
        demand = required_source[index]
        demand <= 0.0 && continue
        capacity = get(capacities, state_id, 0.0)
        account = String(manifest.state_variables[index]["account"])
        unit = String(manifest.state_variables[index]["unit"])
        margin = capacity - demand
        status = capacity <= 0.0 ? "unsupported_missing_actuator_module" :
            margin < -max(demand, 1.0) * 1.0e-9 ? "fail_capacity_shortfall" :
            get(evidence_complete, state_id, true) ? "numerically_realized" :
            "unknown_missing_efficiency_evidence"
        capacity <= 0.0 && push!(missing, "no actuator supplies demanded account $account")
        margin < -max(demand, 1.0) * 1.0e-9 && capacity > 0.0 &&
            push!(insufficient, "actuator capacity is below demanded account $account")
        body = Dict{String,Any}("state_id" => state_id, "account" => account,
            "required_source" => demand, "required_sink" => required_sink[index],
            "available_capacity" => capacity, "capacity_margin" => margin,
            "unit_per_second" => unit == "J" ? "W" : unit == "1" ? "1/s" : "$unit/s",
            "status" => status)
        body["demand_hash"] = canonical_hash(body)
        push!(demand_records, body)
    end
    target = min.(required_source, Float64[get(capacities, id, 0.0) for id in state_ids])
    realized = zeros(length(state_ids))
    residual_history = Dict{String,Any}[]
    tolerance = manifest.numerical_tolerances["normalized_residual"]
    maximum_residual = Inf
    maximum_mismatch = Inf
    for iteration in 1:64
        realized .+= 0.65 .* (target .- realized)
        residual = physical_flux .+ required_sink .- physical_source .- realized
        normalization = max.(abs.(physical_flux) .+ abs.(physical_source) .+
            abs.(realized) .+ abs.(required_sink), 1.0)
        maximum_residual = maximum(abs.(residual) ./ normalization; init = 0.0)
        maximum_mismatch = maximum(abs.(target .- realized) ./ max.(abs.(target), 1.0);
            init = 0.0)
        push!(residual_history, Dict("iteration" => iteration,
            "maximum_normalized_conservation_residual" => maximum_residual,
            "maximum_normalized_demand_realization_mismatch" => maximum_mismatch,
            "method" => iteration == 1 ? "pseudo_transient_relaxation" :
                "damped_fixed_point_with_block_scaling"))
        max(maximum_residual, maximum_mismatch) <= tolerance && break
    end
    slots = Dict{String,Any}[]
    interface_fluxes = Dict{String,Any}[]
    primary_region = isempty(manifest.regions) ? "unknown" :
        String(first(manifest.regions)["region_id"])
    for (index, item) in enumerate(manifest.state_variables)
        normalization = max(abs(physical_flux[index]) + abs(physical_source[index]) +
            abs(realized[index]) + abs(required_sink[index]), 1.0)
        residual = physical_flux[index] + required_sink[index] -
            physical_source[index] - realized[index]
        push!(slots, Dict("region_id" => primary_region,
            "state_id" => String(item["state_id"]), "account" => String(item["account"]),
            "dU_dt" => 0.0, "divergence_F" => physical_flux[index] + required_sink[index],
            "physical_source_S" => physical_source[index],
            "realized_actuator_source_S" => realized[index],
            "normalized_residual" => abs(residual) / normalization))
        push!(interface_fluxes, Dict("from_region_id" => primary_region,
            "to_region_id" => "__external_boundary__",
            "state_id" => String(item["state_id"]), "value_per_s" => physical_flux[index],
            "paired_internal_flux_residual" => 0.0,
            "status" => "computed_external_boundary_flux"))
    end
    network = deepcopy(get(manifest.parameters, "declared_region_network_v1",
        Dict{String,Any}()))
    region_states = Dict{String,Any}[]
    for node in get(network, "nodes", Any[])
        id = String(node["region_id"])
        values = id == primary_region ? Dict(state_ids[index] => state[index]
            for index in eachindex(state_ids)) : Dict{String,Any}()
        push!(region_states, Dict("region_id" => id, "states" => values,
            "status" => String(get(node, "state_partition_status", "unknown"))))
    end
    converged = max(maximum_residual, maximum_mismatch) <= tolerance
    unresolved = vcat(missing, insufficient)
    network_complete = get(network, "status", "unknown") ==
        "complete_single_declared_control_volume"
    network_complete || push!(unresolved,
        "multi-region inventories and internal interface fluxes are not explicitly partitioned")
    any_missing_efficiency = any(record -> String(get(record, "status", "")) ==
        "unknown_missing_efficiency_evidence", demand_records)
    any_missing_efficiency && push!(unresolved,
        "one or more realized energy actuators lack wall-plug efficiency evidence")
    status = !isempty(missing) ? :unsupported : !isempty(insufficient) ? :fail :
        !converged || !network_complete || any_missing_efficiency ? :unknown : :pass
    convergence_status = !isempty(missing) ? "unsupported_missing_actuator_module" :
        !isempty(insufficient) ? "capacity_constrained_infeasible" :
        !converged ? "coupled_residual_not_converged" :
        !network_complete ? "numerically_converged_region_partition_unknown" :
        any_missing_efficiency ? "numerically_converged_efficiency_evidence_unknown" :
        "coupled_state_and_actuator_demands_converged"
    return _csr_v3_make_coupled(manifest, result; status = status,
        convergence_status = convergence_status, dependency_graph = dependency,
        region_states = region_states, interface_fluxes = interface_fluxes,
        actuator_demands = demand_records, actuator_outputs = outputs,
        residual_history = residual_history, conservation_slots = slots,
        unresolved_reasons = sort!(unique(unresolved)))
end

function _csr_v3_plant_component(role_id, value, status, basis, source_hashes;
        applicability_basis = "applicable by declared candidate capabilities")
    body = Dict{String,Any}("role_id" => String(role_id), "value_w" => value,
        "status" => String(status), "basis" => String(basis),
        "applicability_basis" => String(applicability_basis),
        "source_output_hashes" => sort!(unique(filter(!isempty, String.(source_hashes)))))
    body["component_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

function _csr_v3_recirculating_components(manifest, coupled)
    components = Dict{String,Any}[]
    coupled_hash = coupled.result_hash
    deposited = sum((Float64(get(item, "realized_deposited_power_w", 0.0))
        for item in coupled.actuator_outputs); init = 0.0)
    known_wall = 0.0
    missing_wall = false
    for item in coupled.actuator_outputs
        plasma = Float64(get(item, "realized_deposited_power_w", 0.0))
        plasma <= 0.0 && continue
        efficiency = get(item, "wall_plug_efficiency", nothing)
        if efficiency isa Real && efficiency > 0.0
            known_wall += plasma / Float64(efficiency)
        else
            missing_wall = true
        end
    end
    heating_status = deposited <= 0.0 ? "not_applicable" :
        missing_wall ? "unknown" : "complete"
    push!(components, _csr_v3_plant_component("heating_and_current_drive_wall_plug",
        heating_status == "complete" ? known_wall : nothing, heating_status,
        missing_wall ? "realized plasma-side power lacks wall-plug efficiency" :
            "sum of realized deposited power divided by declared wall-plug efficiency",
        [coupled_hash]; applicability_basis = deposited <= 0.0 ?
            "no realized deposited actuator power" : "realized energy-source actuator"))
    particle_output = sum((Float64(get(item, "realized_particle_rate_per_s", 0.0))
        for item in coupled.actuator_outputs); init = 0.0)
    push!(components, _csr_v3_plant_component("particle_injection_and_fuel_processing",
        nothing, particle_output > 0.0 ? "unknown" : "not_applicable",
        particle_output > 0.0 ? "particle rate is known but processing power is not declared" :
            "no realized particle-source demand", [coupled_hash];
        applicability_basis = particle_output > 0.0 ? "realized particle-source actuator" :
            "no realized particle-source demand"))
    declared = get(manifest.parameters, "declared_plant_power_roles_w",
        Dict{String,Any}())
    required = (
        ("magnet_power_supplies", "magnetic field-source and pulsed supply demand"),
        ("cryogenic_system", "declared conductors or cryogenic plant applicability"),
        ("vacuum_exhaust_pumping", "declared exhaust and particle removal"),
        ("coolant_heat_rejection", "solver-derived thermal and boundary loads"),
        ("thermal_cycle_auxiliaries", "gross-electric conversion and heat cycle"),
        ("controls_diagnostics", "control and diagnostic plant services"),
    )
    for (role, basis) in required
        value = get(declared, role, nothing)
        status = value isa Real ? "complete" : "unknown"
        push!(components, _csr_v3_plant_component(role,
            value isa Real ? Float64(value) : nothing, status,
            value isa Real ? "candidate-declared power role" : "missing explicit power output",
            [coupled_hash]; applicability_basis = basis))
    end
    target_count = get(manifest.parameters, "declared_target_count", nothing)
    target_value = get(declared, "target_factory", nothing)
    target_applicable = target_count isa Real && target_count > 0
    push!(components, _csr_v3_plant_component("target_factory",
        target_value isa Real ? Float64(target_value) : nothing,
        !target_applicable ? "not_applicable" : target_value isa Real ? "complete" : "unknown",
        target_value isa Real ? "candidate-declared target factory power" :
            target_applicable ? "target production power is not declared" :
            "no declared target-production count", [coupled_hash];
        applicability_basis = target_applicable ? "declared target count" :
            "no declared target-production requirement"))
    return components
end

"Produce Stage-7 roles from regional/actuator outputs without inventing limits."
function solve_engineering_roles_v2(manifest::CandidateSolveManifestV1,
        result::SolverResultEnvelopeV1, transport,
        coupled::RegionalCoupledSolveEnvelopeV1)
    base = solve_engineering_roles_v1(manifest, result, transport)
    roles = deepcopy(base.output_roles)
    checks = deepcopy(base.checks)
    reasons = copy(base.unknown_reasons)
    coupled_hash = coupled.result_hash
    max_interface_residual = maximum((Float64(get(item,
        "paired_internal_flux_residual", 0.0)) for item in coupled.interface_fluxes); init = 0.0)
    push!(roles, _csr_v2_role("region_interface_conservation_residual",
        max_interface_residual, "1", "computed_external_boundary_or_paired_interface_audit",
        "equal-and-opposite interface accounting; unresolved partitions remain explicit",
        [coupled_hash]))
    max_mismatch = isempty(coupled.residual_history) ? nothing : Float64(get(
        last(coupled.residual_history), "maximum_normalized_demand_realization_mismatch", Inf))
    max_mismatch isa Real && isfinite(max_mismatch) && push!(roles,
        _csr_v2_role("actuator_demand_realization_mismatch", max_mismatch, "1",
            "computed_coupled_residual", "damped fixed-point actuator realization",
            [coupled_hash]))
    requested_roles = (
        ("local_target_heat_flux", "W/m^2", "unknown_missing_local_wetted_geometry"),
        ("conductor_hotspot_temperature", "K", "unknown_missing_finite_conductor_thermal_solution"),
        ("quench_voltage", "V", "unknown_missing_fault_and_quench_solution"),
        ("structural_peak_stress", "Pa", "unknown_missing_support_geometry_and_material_allowable"),
        ("irradiation_damage_rate", "dpa/s", "unknown_missing_neutronics_material_solution"),
        ("component_lifetime", "s", "unknown_missing_damage_limit_and_duty_cycle"),
        ("fuel_cycle_inventory", "kg", "unknown_missing_fuel_cycle_machinery"),
        ("maintenance_access_margin", "m", "unknown_missing_maintenance_geometry"),
    )
    for (id, unit, status) in requested_roles
        push!(roles, _csr_v2_role(id, nothing, unit, status,
            "no global proxy is promoted to a local engineering solution", [coupled_hash]))
    end
    components = _csr_v3_recirculating_components(manifest, coupled)
    complete_values = Float64[Float64(item["value_w"]) for item in components if
        String(item["status"]) == "complete" && get(item, "value_w", nothing) isa Real]
    lower_bound = sum(complete_values; init = 0.0)
    incomplete = [String(item["role_id"]) for item in components if
        String(item["status"]) in ("unknown", "unsupported")]
    completeness = isempty(incomplete) ? "complete" : "lower_bound"
    recirculating = Dict{String,Any}(
        "value_w" => lower_bound, "role_completeness" => completeness,
        "components" => components, "missing_components" => sort!(incomplete),
        "source_output_hashes" => [coupled_hash, result.result_hash,
            String(get(transport, "solver_output_hash", ""))],
        "claim_boundary" => completeness == "complete" ?
            "All applicable declared recirculating roles have numeric outputs." :
            "Only complete declared components are summed; missing plant roles keep this a lower bound.")
    recirculating["role_hash"] = canonical_hash(_csr_v1_json_safe(recirculating))
    push!(roles, _csr_v2_role("recirculating_power_v1", lower_bound, "W",
        completeness == "complete" ? "computed_complete" : "computed_lower_bound_incomplete",
        recirculating["claim_boundary"], recirculating["source_output_hashes"]))
    append!(reasons, ["plant role incomplete: $id" for id in incomplete])
    coupled.status == :fail && push!(reasons, "actuator capacity is numerically infeasible")
    coupled.status == :unsupported && push!(reasons, "required actuator capability is unsupported")
    actuator_margins = Float64[]
    for demand in coupled.actuator_demands
        required = get(demand, "required_source", nothing)
        margin = get(demand, "capacity_margin", nothing)
        required isa Real && margin isa Real && push!(actuator_margins,
            Float64(margin) / max(abs(Float64(required)), 1.0))
    end
    actuator_check_status = isempty(coupled.actuator_demands) ? "not_applicable" :
        coupled.status == :fail ? "fail" : coupled.status == :unsupported ? "unsupported" :
        coupled.status == :pass ? "pass" : "unknown"
    actuator_check = Dict{String,Any}(
        "check_id" => "actuator_capacity", "status" => actuator_check_status,
        "evidence_refs" => ["stage7_engineering_result_v2"],
        "normalized_margin" => isempty(actuator_margins) ? nothing : minimum(actuator_margins),
        "output_role_hash" => isempty(coupled.result_hash) ? nothing : coupled.result_hash,
        "applicability_basis" => isempty(coupled.actuator_demands) ?
            "no nonzero actuator source demand" :
            "candidate-specific source demand and declared actuator capacity",
        "unknown_basis" => actuator_check_status in ("unknown", "unsupported") ?
            join(coupled.unresolved_reasons, "; ") : "")
    push!(checks, actuator_check)
    body = _csr_v2_engineering_body(candidate_id = manifest.candidate_id,
        physics_hash = manifest.physics_hash, manifest_hash = manifest.manifest_hash,
        state_result_hash = result.status == :unsupported ? "" : result.result_hash,
        transport_result_hash = String(get(transport, "solver_output_hash", "")),
        status = coupled.status == :fail ? :fail : :unknown,
        output_roles = roles, checks = checks,
        recirculating_power = recirculating,
        evidence_ceiling = "L1_regional_actuator_and_explicit_plant_role_outputs_only",
        unknown_reasons = sort!(unique(reasons)))
    safe = _csr_v1_json_safe(body)
    hash = canonical_hash(safe)
    return EngineeringResultEnvelopeV1(safe["schema_version"], safe["candidate_id"],
        safe["physics_hash"], safe["manifest_hash"], safe["state_result_hash"],
        safe["transport_result_hash"], coupled.status == :fail ? :fail : :unknown,
        safe["output_roles"], safe["checks"],
        safe["recirculating_power"], safe["evidence_ceiling"],
        safe["unknown_reasons"], hash)
end

function _csr_v3_time_basis(manifest)
    if manifest.time_mode == "pulsed"
        duration = get(manifest.parameters, "pulse_duration_s", nothing)
        rate = get(manifest.parameters, "repetition_rate_hz", nothing)
        return Dict{String,Any}("mode" => "cycle_average",
            "pulse_duration_s" => duration, "repetition_rate_hz" => rate,
            "conversion_status" => duration isa Real && rate isa Real ? "complete" :
                "unknown_missing_pulse_duration_or_repetition_rate")
    end
    return Dict{String,Any}("mode" => "steady_power", "conversion_status" => "complete")
end

function plant_power_ledger_to_dict_v1(ledger::PlantPowerLedgerV1)
    return Dict{String,Any}("schema_version" => ledger.schema_version,
        "candidate_id" => ledger.candidate_id, "physics_hash" => ledger.physics_hash,
        "state_result_hash" => ledger.state_result_hash,
        "transport_result_hash" => ledger.transport_result_hash,
        "engineering_result_hash" => ledger.engineering_result_hash,
        "coupled_result_hash" => ledger.coupled_result_hash,
        "time_basis" => ledger.time_basis, "plant_roles" => ledger.plant_roles,
        "terms" => ledger.terms, "gross_electric_power_w" => ledger.gross_electric_power_w,
        "direct_recovery_power_w" => ledger.direct_recovery_power_w,
        "recirculating_power_w" => ledger.recirculating_power_w,
        "reported_net_power_w" => ledger.reported_net_power_w,
        "reported_net_power_interpretation" => ledger.status == :pass ?
            "complete_net_electric_power" : "unknown_incomplete_plant_roles",
        "status" => ledger.status == :pass ? "complete" :
            ledger.status == :fail ? "fail" : "unknown_incomplete_solver_output_role",
        "sign_status" => ledger.sign_status, "closure" => ledger.closure,
        "strict_role_completeness_required" => true, "generated_nominal" => false,
        "artificially_closed" => false,
        "closure_tolerance_w" => get(ledger.closure, "tolerance_w", nothing),
        "evidence_ceiling" => ledger.evidence_ceiling,
        "ledger_hash" => ledger.result_hash, "result_hash" => ledger.result_hash)
end

"Aggregate gross electric output, direct recovery and every applicable plant role."
function solve_plant_power_ledger_v1(manifest::CandidateSolveManifestV1,
        result::SolverResultEnvelopeV1, transport,
        coupled::RegionalCoupledSolveEnvelopeV1,
        engineering::EngineeringResultEnvelopeV1)
    transport_hash = String(get(transport, "solver_output_hash", ""))
    fusion = get(transport, "fusion_power_w", nothing)
    thermal_efficiency = get(manifest.parameters, "thermal_conversion_efficiency", nothing)
    gross = fusion isa Real && thermal_efficiency isa Real ?
        Float64(fusion) * Float64(thermal_efficiency) : nothing
    recovery_efficiency = get(manifest.parameters, "direct_recovery_efficiency", nothing)
    loss = get(transport, "loss_power_w", nothing)
    direct = loss isa Real && recovery_efficiency isa Real ?
        Float64(loss) * Float64(recovery_efficiency) : nothing
    recirculating = engineering.recirculating_power
    recirc_complete = String(get(recirculating, "role_completeness", "unknown")) ==
        "complete"
    recirc = recirc_complete && get(recirculating, "value_w", nothing) isa Real ?
        Float64(recirculating["value_w"]) : nothing
    time_basis = _csr_v3_time_basis(manifest)
    time_complete = String(time_basis["conversion_status"]) == "complete"
    plant_roles = deepcopy(get(recirculating, "components", Any[]))
    push!(plant_roles, _csr_v3_plant_component("gross_electric_generation", gross,
        gross isa Real ? "complete" : "unknown",
        gross isa Real ? "fusion output times declared thermal conversion efficiency" :
            "missing fusion output or declared thermal conversion efficiency",
        [transport_hash]))
    push!(plant_roles, _csr_v3_plant_component("direct_energy_recovery", direct,
        recovery_efficiency === nothing ? "not_applicable" : direct isa Real ? "complete" :
            "unknown", recovery_efficiency === nothing ?
            "no declared direct-recovery efficiency" : "declared recovery efficiency times solved loss",
        [transport_hash]; applicability_basis = recovery_efficiency === nothing ?
            "no declared direct-recovery module" : "declared direct-recovery efficiency"))
    complete = gross isa Real && recirc isa Real && time_complete &&
        all(item -> String(get(item, "status", "unknown")) in ("complete", "not_applicable"),
            plant_roles)
    net = complete ? gross + (direct isa Real ? direct : 0.0) - recirc : nothing
    sign_status = !complete ? "unknown_incomplete_roles" : net > 0.0 ?
        "positive_point_estimate_uncertainty_not_closed" : net < 0.0 ?
        "negative_point_estimate" : "zero_point_estimate"
    status = complete && net !== nothing && net < 0.0 ? :fail :
        complete ? :unknown : :unknown
    legacy_terms = Dict{String,Any}[]
    fusion isa Real && push!(legacy_terms, Dict("role" => "fusion",
        "value_w" => Float64(fusion), "solver_derived" => true,
        "role_completeness" => "complete", "source_output_hash" => transport_hash))
    loss isa Real && push!(legacy_terms, Dict("role" => "loss",
        "value_w" => -Float64(loss), "solver_derived" => true,
        "role_completeness" => "complete", "source_output_hash" => transport_hash))
    drive = sum((Float64(get(item, "realized_deposited_power_w", 0.0))
        for item in coupled.actuator_outputs); init = 0.0)
    push!(legacy_terms, Dict("role" => "drive", "value_w" => -drive,
        "solver_derived" => true, "role_completeness" =>
            coupled.status == :pass ? "complete" : "unknown",
        "source_output_hash" => engineering.result_hash,
        "component_hash" => coupled.result_hash))
    push!(legacy_terms, Dict("role" => "recirculating",
        "value_w" => -(get(recirculating, "value_w", 0.0) isa Real ?
            Float64(recirculating["value_w"]) : 0.0), "solver_derived" => true,
        "role_completeness" => recirc_complete ? "complete" : "lower_bound",
        "source_output_hash" => engineering.result_hash,
        "component_hash" => String(get(recirculating, "role_hash", ""))))
    closure = Dict{String,Any}("complete" => complete,
        "power_balance_residual_w" => complete ? 0.0 : nothing,
        "tolerance_w" => complete ? max(abs(net), 1.0) * 1.0e-12 : nothing,
        "uncertainty_sign_robust" => false,
        "unresolved_roles" => sort!([String(item["role_id"]) for item in plant_roles if
            String(item["status"]) == "unknown"]))
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => manifest.candidate_id, "physics_hash" => manifest.physics_hash,
        "state_result_hash" => result.status == :unsupported ? "" : result.result_hash,
        "transport_result_hash" => transport_hash,
        "engineering_result_hash" => engineering.result_hash,
        "coupled_result_hash" => coupled.result_hash, "time_basis" => time_basis,
        "plant_roles" => plant_roles, "terms" => legacy_terms,
        "gross_electric_power_w" => gross, "direct_recovery_power_w" => direct,
        "recirculating_power_w" => recirc, "reported_net_power_w" => net,
        "status" => String(status), "sign_status" => sign_status, "closure" => closure,
        "evidence_ceiling" => "solver_output_plant_ledger_with_explicit_role_completeness")
    safe = _csr_v1_json_safe(body)
    hash = canonical_hash(safe)
    return PlantPowerLedgerV1(safe["schema_version"], safe["candidate_id"],
        safe["physics_hash"], safe["state_result_hash"], safe["transport_result_hash"],
        safe["engineering_result_hash"], safe["coupled_result_hash"], safe["time_basis"],
        safe["plant_roles"], safe["terms"], safe["gross_electric_power_w"],
        safe["direct_recovery_power_w"], safe["recirculating_power_w"],
        safe["reported_net_power_w"], status, safe["sign_status"], safe["closure"],
        safe["evidence_ceiling"], hash)
end

"Evaluate an anchor through v3 without converting missing actuator evidence into agreement."
function evaluate_reference_vertical_slice_v3(anchor; discretization_levels = [32, 64])
    item = _csr_v1_plain_dict(anchor)
    manifest_v1 = compile_reference_candidate_solve_manifest_v1(item;
        discretization_levels = discretization_levels)
    parameters = deepcopy(manifest_v1.parameters)
    parameters["actuator_contracts"] = get(parameters, "actuator_contracts", Any[])
    parameters["declared_plant_power_roles_w"] = get(parameters,
        "declared_plant_power_roles_w", Dict{String,Any}())
    parameters["thermal_conversion_efficiency"] = get(parameters,
        "thermal_conversion_efficiency", nothing)
    parameters["direct_recovery_efficiency"] = get(parameters,
        "direct_recovery_efficiency", nothing)
    parameters["capability_dependency_graph_v1"] = Dict("module_contracts" =>
        [_csr_v3_binding_contract(binding) for binding in manifest_v1.module_bindings],
        "compatibility_status" => "compatible",
        "matching_basis" => "anchor-declared capabilities and operators")
    parameters["declared_region_network_v1"] = _csr_v3_region_network(manifest_v1)
    manifest = CandidateSolveManifestV1(candidate_id = manifest_v1.candidate_id,
        physics_hash = manifest_v1.physics_hash, regions = manifest_v1.regions,
        mesh = manifest_v1.mesh, state_variables = manifest_v1.state_variables,
        capability_declarations = manifest_v1.capability_declarations,
        module_bindings = manifest_v1.module_bindings, boundaries = manifest_v1.boundaries,
        sources_sinks = manifest_v1.sources_sinks, time_mode = manifest_v1.time_mode,
        initial_conditions = manifest_v1.initial_conditions,
        numerical_tolerances = manifest_v1.numerical_tolerances,
        discretization_levels = manifest_v1.discretization_levels,
        required_outputs = manifest_v1.required_outputs,
        applicability_scope = manifest_v1.applicability_scope, parameters = parameters)
    result = solve_candidate_manifest_v2(manifest)
    coupled = solve_region_actuator_coupling_v1(manifest, result)
    observed = _csr_anchor_observed_values_v1(result)
    comparisons = Dict{String,Any}[]
    for requirement in item["anchor_observables"]
        id = String(requirement["observable_id"])
        value = get(observed, id, nothing)
        lower = Float64(requirement["minimum"])
        upper = Float64(requirement["maximum"])
        within = value isa Real && isfinite(value) && lower <= value <= upper
        push!(comparisons, Dict("observable_id" => id, "computed" => value,
            "minimum" => lower, "maximum" => upper, "within_anchor_range" => within,
            "evidence_state" => String(requirement["evidence_state"]),
            "source_ref" => String(requirement["source_ref"])))
    end
    validation = Dict{String,Any}("anchor_id" => String(item["anchor_id"]),
        "anchor_kind" => String(item["anchor_kind"]),
        "solver_status" => String(result.status),
        "coupled_status" => String(coupled.status),
        "coupled_convergence_status" => coupled.convergence_status,
        "comparison_status" => all(record -> record["within_anchor_range"] === true,
            comparisons) ? "within_all_declared_anchor_ranges" : "model_discrepancy",
        "comparisons" => comparisons, "claim_boundary" => String(item["claim_boundary"]))
    body = Dict{String,Any}("schema_version" => "1.0.0", "validation" => validation,
        "manifest" => candidate_solve_manifest_to_dict_v1(manifest),
        "solver_result" => solver_result_envelope_to_dict_v1(result),
        "regional_coupled_result" => regional_coupled_solve_to_dict_v1(coupled),
        "source_refs" => item["source_refs"])
    body["record_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end
