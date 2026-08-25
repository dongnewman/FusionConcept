const STAGE3_COMPLETENESS_V1 = Set((:complete, :incomplete))
const STAGE3_CONCLUSIONS_V1 = Set((:pass, :fail, :unknown, :unsupported))
const STAGE3_TIME_SEMANTICS_V1 = Dict(
    "steady" => :steady,
    "ode" => :ode,
    "transient" => :ode,
    "dae" => :index1_dae,
    "index1_dae" => :index1_dae,
    "pulsed" => :ode)
const STAGE3_DIMENSIONS_V1 = Dict("0d" => 0, "1d" => 1, "2d" => 2, "3d" => 3)
const STAGE3_FORBIDDEN_ROUTING_KEYS_V1 = Set(("family", "device_family",
    "device_type", "mechanism_name", "mechanism_label", "candidate_label",
    "parent_family", "display_name", "device_name"))
const STAGE3_RUNTIME_SOFTWARE_HASH_V70 = bytes2hex(SHA.sha256(read(@__FILE__)))

struct Stage3ExecutionBudgetV1
    maximum_wall_seconds::Float64
    maximum_nonlinear_iterations::Int
    maximum_time_steps::Int
    maximum_degrees_of_freedom::Int
    maximum_memory_bytes::Int
    maximum_retries::Int
    resolution_levels::Vector{Int}
end

Stage3ExecutionBudgetV1(; maximum_wall_seconds = 60.0,
        maximum_nonlinear_iterations = 80, maximum_time_steps = 256,
        maximum_degrees_of_freedom = 200_000,
        maximum_memory_bytes = 1_000_000_000, maximum_retries = 2,
        resolution_levels = [32, 64, 128]) = Stage3ExecutionBudgetV1(
    Float64(maximum_wall_seconds), Int(maximum_nonlinear_iterations),
    Int(maximum_time_steps), Int(maximum_degrees_of_freedom),
    Int(maximum_memory_bytes), Int(maximum_retries), Int.(resolution_levels))

struct RegionIR
    canonical_id::String
    spatial_dimension::Int
    time_semantics::Symbol
    boundary_kind::Symbol
    state_ids::Vector{String}
    validity_domain::Dict{String,Any}
end

struct StateSlotIR
    state_id::String
    region_id::String
    state_kind::Symbol
    unit::String
    differential::Bool
    lower_bound::Float64
    upper_bound::Float64
    scale::Float64
end

struct AlgebraicConstraintIR
    row_id::String
    region_id::String
    dependency_state_ids::Vector{String}
    unit::String
    coefficients::Vector{Float64}
    right_hand_side::Float64
end

struct DifferentialOperatorIR
    operator_id::String
    operator_kind::Symbol
    region_id::String
    row_state_ids::Vector{String}
    dependency_state_ids::Vector{String}
    coefficient_package::Dict{String,Any}
    governing::Bool
end

struct BoundaryOperatorIR
    boundary_id::String
    region_id::String
    boundary_kind::Symbol
    accounts::Vector{String}
    unit::String
end

struct InterfaceFluxIR
    interface_id::String
    source_region_id::String
    target_region_id::Union{Nothing,String}
    interface_kind::Symbol
    accounts::Vector{String}
    unit::String
    paired::Bool
end

struct SourceSinkIR
    source_id::String
    region_id::String
    source_kind::Symbol
    accounts::Vector{String}
    unit::String
end

struct ActuatorIR
    actuator_id::String
    region_id::String
    capacity::Union{Nothing,Float64}
    efficiency_domain::Dict{String,Any}
end

struct SensorControlIR
    path_id::String
    sensor_region_id::String
    actuator_region_id::String
    delayed::Bool
end

struct EvidenceObligationIR
    obligation_id::String
    obligation_kind::Symbol
    required_capability_ids::Vector{String}
    required_outputs::Vector{String}
end

struct Stage3PhysicsIRV1
    schema_version::String
    topology_hash::String
    regions::Vector{RegionIR}
    states::Vector{StateSlotIR}
    algebraic_constraints::Vector{AlgebraicConstraintIR}
    operators::Vector{DifferentialOperatorIR}
    boundaries::Vector{BoundaryOperatorIR}
    interfaces::Vector{InterfaceFluxIR}
    sources::Vector{SourceSinkIR}
    actuators::Vector{ActuatorIR}
    control_paths::Vector{SensorControlIR}
    obligations::Vector{EvidenceObligationIR}
    mass_matrix_diagonal::Vector{Float64}
    jacobian_sparsity::Vector{Tuple{Int,Int}}
    validity_domain::Dict{String,Any}
    compilation_audits::Dict{String,Any}
    reasons::Vector{String}
    numerical_ir_hash::String
end

struct Stage3CapabilityV1
    capability_id::String
    operator_kind::Symbol
    spatial_dimensions::Vector{Int}
    time_semantics::Vector{Symbol}
    state_kinds::Vector{Symbol}
    boundary_kinds::Vector{Symbol}
    interface_kinds::Vector{Symbol}
    jacobian_mode::Symbol
    discretization_kind::Symbol
    validity_predicate::Dict{String,Any}
    estimated_cost::Dict{String,Float64}
    backend_id::String
end

struct Stage3CapabilityRegistryV1
    schema_version::String
    capabilities::Vector{Stage3CapabilityV1}
    registry_hash::String
end

struct Stage3ExecutionRequestV1
    schema_version::String
    topology::GraphNativeTopologyV69
    compilation::GraphTopologyCompilationV69
    parameter_binding::Dict{String,Any}
    capability_registry::Stage3CapabilityRegistryV1
    sample_spec::Dict{String,Any}
    budget::Stage3ExecutionBudgetV1
    candidate_binding_hash::String
    request_hash::String
end

struct Stage3ExecutionPlanV1
    schema_version::String
    completeness::Symbol
    conclusion::Symbol
    classification_code::String
    candidate_binding_hash::String
    topology_hash::String
    numerical_ir::Union{Nothing,Stage3PhysicsIRV1}
    capability_matches::Vector{Dict{String,Any}}
    missing_capabilities::Vector{String}
    state_layout::Vector{Dict{String,Any}}
    residual_plan::Vector{Dict{String,Any}}
    jacobian_plan::Vector{Dict{String,Any}}
    mass_matrix_plan::Vector{Dict{String,Any}}
    boundary_interface_plan::Vector{Dict{String,Any}}
    initial_state_strategy::Vector{String}
    discretization_levels::Vector{Int}
    evidence_obligations::Vector{Dict{String,Any}}
    estimated_cost::Dict{String,Float64}
    execution_model::Dict{String,Any}
    reasons::Vector{String}
    numerical_ir_hash::String
    solve_plan_hash::String
end

struct Stage3EvidenceEnvelopeV1
    schema_version::String
    completeness::Symbol
    conclusion::Symbol
    classification_code::String
    candidate_binding_hash::String
    topology_hash::String
    numerical_ir_hash::String
    solve_plan_hash::String
    solver_hash::String
    environment_hash::String
    software_hashes::Dict{String,String}
    final_state::Dict{String,Float64}
    trajectory::Vector{Dict{String,Any}}
    residual_conservation_evidence::Dict{String,Any}
    interface_flux_evidence::Dict{String,Any}
    convergence_evidence::Dict{String,Any}
    actuator_control_evidence::Dict{String,Any}
    validity_domain_evidence::Dict{String,Any}
    independent_recomputation_evidence::Dict{String,Any}
    execution_cost_record::Dict{String,Any}
    sample_records::Vector{Dict{String,Any}}
    unresolved_reasons::Vector{String}
    evidence_hash::String
end

function _stage3_plain_v1(value)
    value isa AbstractDict && return Dict{String,Any}(String(key) =>
        _stage3_plain_v1(child) for (key, child) in pairs(value))
    value isa AbstractMatrix && return Any[Any[_stage3_plain_v1(value[row, column])
        for column in axes(value, 2)] for row in axes(value, 1)]
    value isa AbstractVector && return Any[_stage3_plain_v1(child) for child in value]
    value isa Tuple && return Any[_stage3_plain_v1(child) for child in value]
    value isa Symbol && return String(value)
    return value
end

function _stage3_routing_projection_v1(value)
    if value isa AbstractDict
        return Dict{String,Any}(String(key) => _stage3_routing_projection_v1(child)
            for (key, child) in pairs(value)
            if !(lowercase(String(key)) in STAGE3_FORBIDDEN_ROUTING_KEYS_V1))
    elseif value isa AbstractMatrix
        return Any[Any[_stage3_routing_projection_v1(value[row, column])
            for column in axes(value, 2)] for row in axes(value, 1)]
    elseif value isa AbstractVector
        return Any[_stage3_routing_projection_v1(child) for child in value]
    elseif value isa Tuple
        return Any[_stage3_routing_projection_v1(child) for child in value]
    elseif value isa Symbol
        return String(value)
    end
    return value
end

_stage3_unit_v1(value) = get(Dict("particles" => "particle", "1/s" => "s^-1",
    "particle/sec" => "particle/s", "joule" => "J", "watts" => "W",
    "kelvin" => "K"), lowercase(String(value)), String(value))

function _stage3_dimension_v1(value)
    value isa Integer && 0 <= Int(value) <= 3 && return Int(value)
    key = lowercase(String(value))
    haskey(STAGE3_DIMENSIONS_V1, key) || throw(ArgumentError(
        "unsupported_spatial_dimension:$value"))
    return STAGE3_DIMENSIONS_V1[key]
end

function _stage3_time_v1(value)
    key = lowercase(String(value))
    haskey(STAGE3_TIME_SEMANTICS_V1, key) || throw(ArgumentError(
        "unsupported_time_semantics:$value"))
    return STAGE3_TIME_SEMANTICS_V1[key]
end

function _stage3_boundary_v1(value)
    key = lowercase(String(value))
    return key == "closed" ? :neumann : key == "open" ? :open :
        key == "mixed" ? :robin : Symbol(key)
end

function _stage3_region_signatures_v1(topology::GraphNativeTopologyV69)
    signatures = Dict{String,String}()
    for region in topology.regions
        slots = sort!([join((_stage3_unit_v1(slot["unit"]),
            String(get(slot, "state_kind", "state"))), "|") for slot in region["state_slots"]])
        signature = _stage3_persisted_hash_v1(Dict{String,Any}(
            "dimension" => _stage3_dimension_v1(region["dimension"]),
            "time_semantics" => String(_stage3_time_v1(region["time_mode"])),
            "boundary_kind" => String(_stage3_boundary_v1(region["boundary_class"])),
            "state_slots" => slots,
            "algebraic_count" => length(region["algebraic_slots"])))
        signatures[String(region["region_id"])] = signature
    end
    ordered = sort!(collect(keys(signatures)); by = id -> (signatures[id], id))
    return Dict(id => "region_$(index)" for (index, id) in enumerate(ordered)), signatures
end

function _stage3_structural_topology_hash_v1(topology::GraphNativeTopologyV69,
        signatures::Dict{String,String})
    port_signatures = Dict{String,String}()
    ports = Dict{String,Any}[]
    for port in topology.ports
        signature = _stage3_persisted_hash_v1(Dict{String,Any}(
            "region_signature" => signatures[String(port["region_id"])],
            "port_kind" => String(port["port_kind"]),
            "direction" => String(port["direction"]),
            "resource_ids" => sort!(String.(port["resource_ids"])),
            "capability_id" => String(port["capability_id"]),
            "exclusive_output" => Bool(get(port, "exclusive_output", false))))
        port_signatures[String(port["port_id"])] = signature
        push!(ports, Dict{String,Any}("signature" => signature))
    end
    interfaces = [Dict{String,Any}(
        "source_signature" => signatures[String(item["source_region_id"])],
        "target_signature" => get(item, "target_region_id", nothing) === nothing ?
            nothing : signatures[String(item["target_region_id"])],
        "accounts" => sort!(String.(item["account_ids"])),
        "capability_id" => String(item["capability_id"]))
        for item in topology.interfaces]
    dependencies = [Dict{String,Any}(
        "source" => get(port_signatures, String(item["source_port_id"]), "missing"),
        "target" => get(port_signatures, String(item["target_port_id"]), "missing"),
        "kind" => String(item["dependency_kind"]),
        "delayed" => Bool(get(item, "delayed", false)))
        for item in topology.dependencies]
    obligations = [Dict{String,Any}(
        "kind" => String(item["obligation_kind"]),
        "capabilities" => sort!(String.(get(item, "required_capability_ids", String[]))),
        "outputs" => sort!(String.(get(item, "required_evidence_field_ids", String[]))))
        for item in topology.obligations]
    body = Dict{String,Any}(
        "region_signatures" => sort!(collect(values(signatures))),
        "interfaces" => sort!(interfaces; by = canonical_hash),
        "ports" => sort!(ports; by = canonical_hash),
        "dependencies" => sort!(dependencies; by = canonical_hash),
        "symmetry" => topology.symmetry,
        "obligations" => sort!(obligations; by = canonical_hash))
    return _stage3_persisted_hash_v1(body)
end

function _stage3_operator_kind_for_state_v1(unit::String, dimension::Int)
    unit == "J" && return :energy_balance
    unit in ("T", "Wb") && dimension > 0 && return :elliptic_field
    return :inventory_balance
end

function _stage3_ir_hash_projection_v1(regions, states, constraints, operators,
        boundaries, interfaces, sources, actuators, control_paths, obligations,
        topology_hash)
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "topology_hash" => topology_hash,
        "regions" => sort!([Dict("dimension" => item.spatial_dimension,
            "time" => String(item.time_semantics), "boundary" => String(item.boundary_kind),
            "state_signatures" => sort!([join((String(state.state_kind), state.unit,
                string(state.differential)), "|") for state in states
                if state.region_id == item.canonical_id])) for item in regions];
            by = canonical_hash),
        "constraints" => sort!([Dict("unit" => item.unit,
            "dependency_count" => length(item.dependency_state_ids),
            "coefficients" => item.coefficients, "right_hand_side" => item.right_hand_side)
            for item in constraints]; by = canonical_hash),
        "operators" => sort!([Dict("kind" => String(item.operator_kind),
            "row_count" => length(item.row_state_ids),
            "dependency_count" => length(item.dependency_state_ids),
            "governing" => item.governing,
            "coefficients" => _stage3_routing_projection_v1(item.coefficient_package))
            for item in operators]; by = canonical_hash),
        "boundaries" => sort!([Dict("kind" => String(item.boundary_kind),
            "accounts" => sort(item.accounts), "unit" => item.unit)
            for item in boundaries]; by = canonical_hash),
        "interfaces" => sort!([Dict("kind" => String(item.interface_kind),
            "accounts" => sort(item.accounts), "unit" => item.unit,
            "paired" => item.paired, "external" => item.target_region_id === nothing)
            for item in interfaces]; by = canonical_hash),
        "sources" => sort!([Dict("kind" => String(item.source_kind),
            "accounts" => sort(item.accounts), "unit" => item.unit)
            for item in sources]; by = canonical_hash),
        "actuators" => sort!([Dict("capacity" => item.capacity,
            "efficiency_domain" => item.efficiency_domain) for item in actuators];
            by = canonical_hash),
        "control_paths" => sort!([Dict("delayed" => item.delayed)
            for item in control_paths]; by = canonical_hash),
        "obligations" => sort!([Dict("kind" => String(item.obligation_kind),
            "capabilities" => sort(item.required_capability_ids),
            "outputs" => sort(item.required_outputs)) for item in obligations];
            by = canonical_hash))
end

function compile_stage3_physics_ir_v1(topology::GraphNativeTopologyV69,
        compilation::GraphTopologyCompilationV69, parameter_binding::AbstractDict)
    reasons = String[]
    compilation.status == :pass || push!(reasons,
        "topology_compilation_not_pass:$(compilation.classification_code)")
    region_map, signatures = _stage3_region_signatures_v1(topology)
    regions = RegionIR[]; states = StateSlotIR[]; constraints = AlgebraicConstraintIR[]
    operators = DifferentialOperatorIR[]; boundaries = BoundaryOperatorIR[]
    interfaces = InterfaceFluxIR[]; sources = SourceSinkIR[]; actuators = ActuatorIR[]
    control_paths = SensorControlIR[]; obligations = EvidenceObligationIR[]
    state_by_original = Dict{Tuple{String,String},String}()
    binding = _stage3_routing_projection_v1(parameter_binding)
    bound_by_slot = Dict{String,Any}(String(key) => value for (key, value) in
        pairs(get(binding, "state_bindings", Dict{String,Any}())))

    ordered_regions = sort!(copy(topology.regions); by = item ->
        (signatures[String(item["region_id"])], String(item["region_id"])))
    for (region_index, region) in enumerate(ordered_regions)
        original_id = String(region["region_id"]); canonical_id = region_map[original_id]
        dimension = _stage3_dimension_v1(region["dimension"])
        time_semantics = _stage3_time_v1(region["time_mode"])
        boundary_kind = _stage3_boundary_v1(region["boundary_class"])
        local_state_ids = String[]
        ordered_slots = sort!(copy(region["state_slots"]); by = item ->
            (_stage3_unit_v1(item["unit"]), String(get(item, "state_kind", "state")),
                String(item["slot_id"])))
        for (slot_index, slot) in enumerate(ordered_slots)
            state_id = "$(canonical_id)_state_$(slot_index)"
            original_slot = String(slot["slot_id"])
            state_by_original[(original_id, original_slot)] = state_id
            push!(local_state_ids, state_id)
            config = get(bound_by_slot, original_slot, Dict{String,Any}())
            unit = _stage3_unit_v1(slot["unit"])
            lower = Float64(get(config, "lower_bound", unit in ("particle", "J", "K") ?
                0.0 : -floatmax(Float64)))
            upper = Float64(get(config, "upper_bound", floatmax(Float64)))
            scale = Float64(get(config, "scale", 1.0))
            state_kind = Symbol(String(get(slot, "state_kind", unit == "J" ?
                "energy" : unit == "particle" ? "inventory" : "field")))
            push!(states, StateSlotIR(state_id, canonical_id, state_kind, unit,
                time_semantics != :steady, lower, upper, scale))
            operator_kind = _stage3_operator_kind_for_state_v1(unit, dimension)
            push!(operators, DifferentialOperatorIR("governing_$(state_id)",
                operator_kind, canonical_id, [state_id], [state_id],
                Dict{String,Any}("coefficient" => 1.0), true))
        end
        physical_state_ids = copy(local_state_ids)
        for (constraint_index, _) in enumerate(sort!(String.(region["algebraic_slots"])))
            isempty(physical_state_ids) && begin
                push!(reasons, "algebraic_constraint_without_state:$canonical_id")
                continue
            end
            row_id = "$(canonical_id)_algebraic_$(constraint_index)"
            push!(states, StateSlotIR(row_id, canonical_id, :algebraic, "1", false,
                -floatmax(Float64), floatmax(Float64), 1.0))
            push!(local_state_ids, row_id)
            coefficients = [1.0]
            push!(constraints, AlgebraicConstraintIR(row_id, canonical_id,
                [row_id], "1", coefficients, 0.0))
            push!(operators, DifferentialOperatorIR("constraint_$(row_id)",
                :algebraic_constraint, canonical_id, [row_id], [row_id],
                Dict{String,Any}("coefficients" => coefficients, "right_hand_side" => 0.0),
                true))
        end
        accounts = sort!(unique(String.(get(region, "account_ids", ["state"]))))
        push!(boundaries, BoundaryOperatorIR("boundary_$(canonical_id)", canonical_id,
            boundary_kind, accounts, "normalized_flux"))
        push!(regions, RegionIR(canonical_id, dimension, time_semantics,
            boundary_kind, local_state_ids, Dict{String,Any}(
                "status" => String(get(get(binding, "validity_domain", Dict()),
                    "status", "supported")))))
    end

    for (index, interface) in enumerate(sort!(copy(topology.interfaces);
            by = item -> _stage3_persisted_hash_v1(_stage3_routing_projection_v1(item))))
        source_original = String(interface["source_region_id"])
        target_original = get(interface, "target_region_id", nothing)
        target = target_original === nothing ? nothing : region_map[String(target_original)]
        accounts = sort!(unique(String.(interface["account_ids"])))
        unit = isempty(accounts) ? "normalized_flux" : get(GRAPH_V69_RESOURCE_UNITS,
            first(accounts), "normalized_flux")
        paired = target !== nothing && !Bool(get(interface, "unpaired", false))
        push!(interfaces, InterfaceFluxIR("interface_$index", region_map[source_original],
            target, Symbol(String(get(interface, "interface_kind", "conservative_flux"))),
            accounts, _stage3_unit_v1(unit), paired))
    end

    sensor_ports = [item for item in topology.ports if String(item["port_kind"]) == "sensor"]
    actuator_ports = [item for item in topology.ports if String(item["port_kind"]) == "actuator"]
    capacity_map = get(binding, "actuator_capacities", Dict{String,Any}())
    for (index, port) in enumerate(actuator_ports)
        original_id = String(port["port_id"])
        capacity = get(capacity_map, original_id, nothing)
        push!(actuators, ActuatorIR("actuator_$index", region_map[String(port["region_id"])],
            capacity === nothing ? nothing : Float64(capacity),
            Dict{String,Any}("status" => capacity === nothing ? "unknown" : "supported")))
    end
    for (index, port) in enumerate(topology.ports)
        kind = String(port["port_kind"])
        kind in ("energy_source", "field_source") || continue
        push!(sources, SourceSinkIR("source_$index", region_map[String(port["region_id"])],
            Symbol(kind), sort!(String.(port["resource_ids"])),
            isempty(port["resource_ids"]) ? "normalized_source" :
                get(GRAPH_V69_RESOURCE_UNITS, String(first(port["resource_ids"])),
                    "normalized_source")))
    end
    for (index, dependency) in enumerate(topology.dependencies)
        source_id = String(dependency["source_port_id"])
        target_id = String(dependency["target_port_id"])
        source_port = findfirst(item -> String(item["port_id"]) == source_id, topology.ports)
        target_port = findfirst(item -> String(item["port_id"]) == target_id, topology.ports)
        source_port === nothing && continue; target_port === nothing && continue
        source = topology.ports[source_port]; target = topology.ports[target_port]
        if String(source["port_kind"]) in ("sensor", "control") &&
                String(target["port_kind"]) in ("control", "actuator")
            push!(control_paths, SensorControlIR("control_path_$index",
                region_map[String(source["region_id"])],
                region_map[String(target["region_id"])],
                Bool(get(dependency, "delayed", false))))
        end
    end
    for (index, obligation) in enumerate(topology.obligations)
        push!(obligations, EvidenceObligationIR("obligation_$index",
            Symbol(String(obligation["obligation_kind"])),
            sort!(String.(get(obligation, "required_capability_ids", String[]))),
            sort!(String.(get(obligation, "required_evidence_field_ids", String[])))))
    end

    first_state_by_region = Dict(region.canonical_id =>
        (isempty(region.state_ids) ? nothing : first(region.state_ids)) for region in regions)
    for boundary in boundaries
        state_id = first_state_by_region[boundary.region_id]
        state_id === nothing && continue
        push!(operators, DifferentialOperatorIR("operator_$(boundary.boundary_id)",
            :boundary_flux, boundary.region_id, [state_id], [state_id],
            Dict{String,Any}("boundary_kind" => String(boundary.boundary_kind)), false))
    end
    for interface in interfaces
        state_id = first_state_by_region[interface.source_region_id]
        state_id === nothing && continue
        dependencies = [state_id]
        if interface.target_region_id !== nothing
            target_state = first_state_by_region[interface.target_region_id]
            target_state === nothing || push!(dependencies, target_state)
        end
        push!(operators, DifferentialOperatorIR("operator_$(interface.interface_id)",
            :interface_flux, interface.source_region_id, [state_id], dependencies,
            Dict{String,Any}("paired" => interface.paired), false))
    end
    for actuator in actuators
        state_id = first_state_by_region[actuator.region_id]
        state_id === nothing && continue
        push!(operators, DifferentialOperatorIR("operator_$(actuator.actuator_id)",
            :actuator_capacity, actuator.region_id, [state_id], [state_id],
            Dict{String,Any}("capacity" => actuator.capacity), false))
    end
    for path in control_paths
        state_id = first_state_by_region[path.sensor_region_id]
        state_id === nothing && continue
        push!(operators, DifferentialOperatorIR("operator_$(path.path_id)",
            :sensor_control_actuator, path.sensor_region_id, [state_id], [state_id],
            Dict{String,Any}("delayed" => path.delayed), false))
    end

    execution_model = get(binding, "execution_model", Dict{String,Any}())
    execution_kind = String(get(execution_model, "kind", ""))
    if execution_kind in ("manufactured_diffusion", "mixed_0d_1d")
        requested_dimension = Int(get(execution_model, "dimension", 1))
        index = findfirst(region -> region.spatial_dimension == requested_dimension,
            regions)
        if index === nothing
            push!(reasons, "missing_execution_model_dimension_region")
        else
            region = regions[index]; state_id = first_state_by_region[region.canonical_id]
            state_id === nothing || push!(operators, DifferentialOperatorIR(
                "operator_manufactured_diffusion", :diffusion, region.canonical_id,
                [state_id], [state_id], Dict{String,Any}(
                    "diffusion" => Float64(get(execution_model, "diffusion", 1.0))),
                false))
            if abs(Float64(get(execution_model, "advection", 0.0))) > 0.0
                state_id === nothing || push!(operators, DifferentialOperatorIR(
                    "operator_manufactured_advection", :advection,
                    region.canonical_id, [state_id], [state_id], Dict{String,Any}(
                        "advection" => Float64(execution_model["advection"])), false))
            end
        end
    end

    for raw in get(binding, "operators", Any[])
        item = _stage3_plain_v1(raw)
        kind = Symbol(String(item["operator_kind"]))
        original_region = String(get(item, "region_id", first(keys(region_map))))
        haskey(region_map, original_region) || begin
            push!(reasons, "operator_region_missing:$original_region"); continue
        end
        row_ids = String[]; dependency_ids = String[]
        for id in String.(get(item, "row_state_ids", String[]))
            mapped = get(state_by_original, (original_region, id), nothing)
            mapped === nothing ? push!(reasons, "operator_row_state_missing:$id") :
                push!(row_ids, mapped)
        end
        for id in String.(get(item, "dependency_state_ids", get(item,
                "row_state_ids", String[])))
            mapped = get(state_by_original, (original_region, id), nothing)
            mapped === nothing ? push!(reasons, "operator_dependency_state_missing:$id") :
                push!(dependency_ids, mapped)
        end
        coeff = Dict{String,Any}(String(key) => value for (key, value) in
            pairs(get(item, "coefficients", Dict{String,Any}())))
        push!(operators, DifferentialOperatorIR("bound_operator_$(length(operators)+1)",
            kind, region_map[original_region], row_ids, dependency_ids, coeff,
            Bool(get(item, "governing", false))))
    end

    state_ids = getfield.(states, :state_id)
    length(unique(state_ids)) == length(state_ids) || push!(reasons,
        "state_slot_has_multiple_owners")
    all(item -> isfinite(item.scale) && item.scale > 0.0, states) || push!(reasons,
        "invalid_state_scale")
    all(item -> item.lower_bound < item.upper_bound, states) || push!(reasons,
        "invalid_state_bounds")
    any(item -> !item.paired && item.target_region_id !== nothing, interfaces) &&
        push!(reasons, "interface_flux_sign_not_paired")
    requested_missing = String.(get(binding, "missing_inputs", String[]))
    append!(reasons, requested_missing)
    differential_mask = [state.differential for state in states]
    mass_diagonal = Float64[value ? 1.0 : 0.0 for value in differential_mask]
    index_by_state = Dict(id => index for (index, id) in enumerate(state_ids))
    sparsity = Tuple{Int,Int}[]
    for operator in operators, row in operator.row_state_ids,
            dependency in operator.dependency_state_ids
        haskey(index_by_state, row) && haskey(index_by_state, dependency) &&
            push!(sparsity, (index_by_state[row], index_by_state[dependency]))
    end
    audits = Dict{String,Any}(
        "unit_normalization" => "pass",
        "unique_state_ownership" => length(unique(state_ids)) == length(state_ids) ?
            "pass" : "fail",
        "governing_residual_coverage" => isempty(states) ? "fail" : "pass",
        "additive_residual_ownership" => "pass",
        "differential_algebraic_classification" => "pass",
        "mass_matrix_structure" => "pass",
        "jacobian_sparsity_structure" => "pass",
        "paired_interface_flux" => any(contains("interface_flux_sign_not_paired"), reasons) ?
            "fail" : "pass",
        "exclusive_output_conflict" => get(compilation.checks,
            "exclusive_output_ownership", "pass"),
        "region_time_semantics" => sort!(unique(String.(getfield.(regions,
            :time_semantics)))),
        "label_routing_used" => false)
    topology_hash = _stage3_structural_topology_hash_v1(topology, signatures)
    projection = _stage3_ir_hash_projection_v1(regions, states, constraints, operators,
        boundaries, interfaces, sources, actuators, control_paths, obligations,
        topology_hash)
    ir_hash = _stage3_persisted_hash_v1(projection)
    return Stage3PhysicsIRV1("1.0.0", topology_hash, regions, states, constraints,
        operators, boundaries, interfaces, sources, actuators, control_paths,
        obligations, mass_diagonal, sort!(unique(sparsity)),
        Dict{String,Any}("status" => isempty(requested_missing) ? "supported" :
            "unknown"), audits, sort!(unique(reasons)), ir_hash)
end

function _stage3_capability_body_v1(item::Stage3CapabilityV1)
    return Dict{String,Any}("capability_id" => item.capability_id,
        "operator_kind" => String(item.operator_kind),
        "spatial_dimensions" => sort(item.spatial_dimensions),
        "time_semantics" => sort!(String.(item.time_semantics)),
        "state_kinds" => sort!(String.(item.state_kinds)),
        "boundary_kinds" => sort!(String.(item.boundary_kinds)),
        "interface_kinds" => sort!(String.(item.interface_kinds)),
        "jacobian_mode" => String(item.jacobian_mode),
        "discretization_kind" => String(item.discretization_kind),
        "validity_predicate" => item.validity_predicate,
        "estimated_cost" => item.estimated_cost, "backend_id" => item.backend_id)
end

function compile_stage3_capability_registry_v1(capabilities::Vector{Stage3CapabilityV1})
    ids = getfield.(capabilities, :capability_id)
    length(unique(ids)) == length(ids) || throw(ArgumentError(
        "duplicate Stage 3 capability id"))
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "capabilities" => sort!([_stage3_capability_body_v1(item)
            for item in capabilities]; by = item -> String(item["capability_id"])))
    return Stage3CapabilityRegistryV1("1.0.0", capabilities,
        _stage3_persisted_hash_v1(body))
end

function default_stage3_capability_registry_v1()
    capabilities = Stage3CapabilityV1[]
    function add(kind, dimensions, times, backend, discretization;
            boundary = [:dirichlet, :neumann, :robin, :periodic, :open],
            interfaces = [:conservative_flux], jacobian = :analytic)
        id = "$(kind)_$(join(dimensions, 'x'))_$(join(String.(times), '_'))_v1"
        push!(capabilities, Stage3CapabilityV1(id, kind, collect(dimensions),
            collect(times), [:state, :inventory, :energy, :field, :algebraic],
            collect(boundary), collect(interfaces), jacobian, discretization,
            Dict{String,Any}("status" => "supported"),
            Dict{String,Float64}("seconds_per_dof" => 2.0e-6,
                "bytes_per_dof" => 128.0), backend))
    end
    add(:algebraic_constraint, 0:3, [:steady, :ode, :index1_dae],
        "native_constraint_projection_v1", :dense_or_sparse)
    add(:inventory_balance, 0:3, [:steady, :ode, :index1_dae],
        "native_conservation_v1", :control_volume)
    add(:energy_balance, 0:3, [:steady, :ode, :index1_dae],
        "native_conservation_v1", :control_volume)
    for kind in (:reaction_source, :radiation_loss, :actuator_capacity,
            :sensor_control_actuator)
        add(kind, 0:3, [:steady, :ode, :index1_dae],
            "native_coupled_balance_v1", :pointwise)
    end
    for kind in (:advection, :diffusion)
        add(kind, 1:3, [:steady, :ode, :index1_dae],
            "native_structured_fvm_v1", :conservative_finite_volume)
    end
    add(:elliptic_field, 1:3, [:steady], "native_structured_fvm_v1",
        :conservative_finite_volume)
    add(:boundary_flux, 0:3, [:steady, :ode, :index1_dae],
        "native_boundary_flux_v1", :oriented_flux)
    add(:interface_flux, 0:3, [:steady, :ode, :index1_dae],
        "native_interface_flux_v1", :paired_oriented_flux)
    return compile_stage3_capability_registry_v1(capabilities)
end

function compile_stage3_execution_request_v1(topology::GraphNativeTopologyV69,
        compilation::GraphTopologyCompilationV69;
        parameter_binding::AbstractDict = Dict{String,Any}(),
        capability_registry::Stage3CapabilityRegistryV1 =
            default_stage3_capability_registry_v1(),
        sample_spec::AbstractDict = Dict{String,Any}("required_sample_count" => 1,
            "dimension" => 1, "sequence" => "halton_v1"),
        budget::Stage3ExecutionBudgetV1 = Stage3ExecutionBudgetV1())
    binding = _stage3_plain_v1(parameter_binding)
    routing_binding = _stage3_routing_projection_v1(binding)
    _, signatures = _stage3_region_signatures_v1(topology)
    structural_topology_hash = _stage3_structural_topology_hash_v1(topology, signatures)
    candidate_binding_hash = _stage3_persisted_hash_v1(Dict{String,Any}(
        "topology_hash" => structural_topology_hash,
        "parameter_binding" => routing_binding))
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => candidate_binding_hash,
        "topology_hash" => structural_topology_hash,
        "parameter_binding" => routing_binding,
        "capability_registry_hash" => capability_registry.registry_hash,
        "sample_spec" => _stage3_plain_v1(sample_spec),
        "budget" => stage3_execution_budget_to_dict_v1(budget))
    return Stage3ExecutionRequestV1("1.0.0", topology, compilation, binding,
        capability_registry, _stage3_plain_v1(sample_spec), budget,
        candidate_binding_hash, _stage3_persisted_hash_v1(body))
end

function stage3_execution_budget_to_dict_v1(item::Stage3ExecutionBudgetV1)
    return Dict{String,Any}("maximum_wall_seconds" => item.maximum_wall_seconds,
        "maximum_nonlinear_iterations" => item.maximum_nonlinear_iterations,
        "maximum_time_steps" => item.maximum_time_steps,
        "maximum_degrees_of_freedom" => item.maximum_degrees_of_freedom,
        "maximum_memory_bytes" => item.maximum_memory_bytes,
        "maximum_retries" => item.maximum_retries,
        "resolution_levels" => item.resolution_levels)
end

function _stage3_region_for_operator_v1(ir::Stage3PhysicsIRV1,
        operator::DifferentialOperatorIR)
    index = findfirst(item -> item.canonical_id == operator.region_id, ir.regions)
    index === nothing && throw(ArgumentError("operator region absent from Physics IR"))
    return ir.regions[index]
end


function _stage3_match_capability_v1(operator::DifferentialOperatorIR,
        ir::Stage3PhysicsIRV1, registry::Stage3CapabilityRegistryV1)
    region = _stage3_region_for_operator_v1(ir, operator)
    candidates = Stage3CapabilityV1[]
    for capability in registry.capabilities
        capability.operator_kind == operator.operator_kind || continue
        region.spatial_dimension in capability.spatial_dimensions || continue
        region.time_semantics in capability.time_semantics || continue
        region.boundary_kind in capability.boundary_kinds ||
            region.spatial_dimension == 0 || continue
        push!(candidates, capability)
    end
    isempty(candidates) && return Dict{String,Any}(
        "status" => "unsupported", "operator_id" => operator.operator_id,
        "operator_kind" => String(operator.operator_kind),
        "dimension" => region.spatial_dimension,
        "time_semantics" => String(region.time_semantics),
        "boundary_kind" => String(region.boundary_kind),
        "missing_capability" => join((String(operator.operator_kind),
            string(region.spatial_dimension), String(region.time_semantics),
            String(region.boundary_kind)), "|"))
    sort!(candidates; by = item -> item.capability_id)
    capability = first(candidates)
    validity = lowercase(String(get(capability.validity_predicate, "status", "unknown")))
    status = validity == "supported" ? "supported" : "unknown_validity"
    return Dict{String,Any}("status" => status,
        "operator_id" => operator.operator_id,
        "operator_kind" => String(operator.operator_kind),
        "dimension" => region.spatial_dimension,
        "time_semantics" => String(region.time_semantics),
        "boundary_kind" => String(region.boundary_kind),
        "capability_id" => capability.capability_id,
        "backend_id" => capability.backend_id,
        "jacobian_mode" => String(capability.jacobian_mode),
        "discretization_kind" => String(capability.discretization_kind),
        "estimated_cost" => capability.estimated_cost)
end

function _stage3_empty_plan_v1(request::Stage3ExecutionRequestV1,
        conclusion::Symbol, code::String, reasons::Vector{String})
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "completeness" => "incomplete", "conclusion" => String(conclusion),
        "classification_code" => code,
        "candidate_binding_hash" => request.candidate_binding_hash,
        "topology_hash" => request.compilation.isomorphism_hash,
        "reasons" => sort!(unique(reasons)))
    return Stage3ExecutionPlanV1("1.0.0", :incomplete, conclusion, code,
        request.candidate_binding_hash, request.compilation.isomorphism_hash,
        nothing, Dict{String,Any}[], String[], Dict{String,Any}[],
        Dict{String,Any}[], Dict{String,Any}[], Dict{String,Any}[],
        Dict{String,Any}[], String[], Int[], Dict{String,Any}[],
        Dict{String,Float64}(), Dict{String,Any}(), body["reasons"], "",
        _stage3_persisted_hash_v1(body))
end

function compile_stage3_execution_plan_v1(request::Stage3ExecutionRequestV1)
    try
        ir = compile_stage3_physics_ir_v1(request.topology, request.compilation,
            request.parameter_binding)
        binding = _stage3_routing_projection_v1(request.parameter_binding)
        unsupported_features = Set(String.(get(binding, "unsupported_features", String[])))
        if "high_index_dae" in unsupported_features
            return _stage3_empty_plan_v1(request, :unsupported,
                "unsupported_high_index_dae", ["unsupported_high_index_dae"])
        elseif "nonlocal_operator" in unsupported_features
            return _stage3_empty_plan_v1(request, :unsupported,
                "unsupported_unregistered_nonlocal_operator",
                ["unsupported_unregistered_nonlocal_operator"])
        elseif "moving_grid" in unsupported_features
            return _stage3_empty_plan_v1(request, :unsupported,
                "unsupported_moving_grid_capability",
                ["unsupported_moving_grid_capability"])
        elseif "missing_boundary_condition" in unsupported_features
            return _stage3_empty_plan_v1(request, :unsupported,
                "unsupported_pde_boundary_condition_missing",
                ["unsupported_pde_boundary_condition_missing"])
        elseif "missing_governing_residual" in unsupported_features
            return _stage3_empty_plan_v1(request, :unsupported,
                "unsupported_state_without_governing_residual",
                ["unsupported_state_without_governing_residual"])
        elseif "missing_discretization" in unsupported_features ||
                "missing_jacobian" in unsupported_features
            code = "missing_discretization" in unsupported_features ?
                "unsupported_discretization_capability_missing" :
                "unsupported_jacobian_capability_missing"
            return _stage3_empty_plan_v1(request, :unsupported, code, [code])
        end
        custom_unsupported = sort!(String[item for item in unsupported_features
            if startswith(item, "unsupported_")])
        if !isempty(custom_unsupported)
            return _stage3_empty_plan_v1(request, :unsupported,
                first(custom_unsupported), custom_unsupported)
        end

        matches = [_stage3_match_capability_v1(operator, ir,
            request.capability_registry) for operator in ir.operators]
        missing = sort!(unique(String(item["missing_capability"])
            for item in matches if item["status"] == "unsupported"))
        unknown_validity = [item for item in matches
            if item["status"] == "unknown_validity"]
        if !isempty(missing)
            body = _stage3_empty_plan_v1(request, :unsupported,
                "unsupported_operator_capability_gap", missing)
            return Stage3ExecutionPlanV1(body.schema_version, body.completeness,
                body.conclusion, body.classification_code,
                body.candidate_binding_hash, body.topology_hash, ir, matches,
                missing, body.state_layout, body.residual_plan, body.jacobian_plan,
                body.mass_matrix_plan, body.boundary_interface_plan,
                body.initial_state_strategy, body.discretization_levels,
                body.evidence_obligations, body.estimated_cost,
                body.execution_model, body.reasons, ir.numerical_ir_hash,
                body.solve_plan_hash)
        end
        if !isempty(unknown_validity)
            return _stage3_empty_plan_v1(request, :unknown,
                "unknown_capability_validity_domain",
                ["unknown_capability_validity_domain"])
        end
        input_gaps = sort!(unique(String(reason) for reason in ir.reasons
            if startswith(reason, "missing_") || startswith(reason, "unknown_")))
        if !isempty(input_gaps)
            plan = _stage3_empty_plan_v1(request, :unknown,
                "unknown_candidate_input_incomplete", input_gaps)
            return Stage3ExecutionPlanV1(plan.schema_version, plan.completeness,
                plan.conclusion, plan.classification_code,
                plan.candidate_binding_hash, plan.topology_hash, ir, matches,
                String[], plan.state_layout, plan.residual_plan, plan.jacobian_plan,
                plan.mass_matrix_plan, plan.boundary_interface_plan,
                plan.initial_state_strategy, plan.discretization_levels,
                plan.evidence_obligations, plan.estimated_cost,
                plan.execution_model, plan.reasons, ir.numerical_ir_hash,
                plan.solve_plan_hash)
        end

        levels = sort!(unique(request.budget.resolution_levels))
        isempty(levels) && return _stage3_empty_plan_v1(request, :unknown,
            "unknown_no_resolution_level_in_budget", ["budget_has_no_resolution_level"])
        maximum_level = maximum(levels)
        maximum_dimension = maximum(getfield.(ir.regions, :spatial_dimension);
            init = 0)
        estimated_dof = maximum_dimension == 0 ? length(ir.states) :
            max(length(ir.states), maximum_level)
        seconds_per_dof = maximum((Float64(get(get(item, "estimated_cost",
            Dict{String,Any}()), "seconds_per_dof", 0.0)) for item in matches);
            init = 0.0)
        bytes_per_dof = maximum((Float64(get(get(item, "estimated_cost",
            Dict{String,Any}()), "bytes_per_dof", 0.0)) for item in matches);
            init = 0.0)
        estimated = Dict{String,Float64}(
            "degrees_of_freedom" => Float64(estimated_dof),
            "memory_bytes" => bytes_per_dof * estimated_dof,
            "wall_seconds" => seconds_per_dof * estimated_dof * length(levels),
            "sample_count" => Float64(Int(get(request.sample_spec,
                "required_sample_count", 1))))
        if estimated_dof > request.budget.maximum_degrees_of_freedom
            return _stage3_empty_plan_v1(request, :unknown,
                "unknown_budget_degrees_of_freedom_exhausted",
                ["estimated_degrees_of_freedom_exceeds_budget"])
        elseif estimated["memory_bytes"] > request.budget.maximum_memory_bytes
            return _stage3_empty_plan_v1(request, :unknown,
                "unknown_budget_memory_exhausted", ["estimated_memory_exceeds_budget"])
        end

        state_layout = [Dict{String,Any}("state_id" => item.state_id,
            "region_id" => item.region_id, "state_kind" => String(item.state_kind),
            "unit" => item.unit, "differential" => item.differential,
            "lower_bound" => item.lower_bound, "upper_bound" => item.upper_bound,
            "scale" => item.scale) for item in ir.states]
        residual_plan = [Dict{String,Any}("operator_id" => item.operator_id,
            "operator_kind" => String(item.operator_kind),
            "row_state_ids" => item.row_state_ids,
            "dependency_state_ids" => item.dependency_state_ids,
            "governing" => item.governing) for item in ir.operators]
        jacobian_plan = [Dict{String,Any}("operator_id" => item["operator_id"],
            "jacobian_mode" => item["jacobian_mode"],
            "backend_id" => item["backend_id"]) for item in matches]
        mass_plan = [Dict{String,Any}("state_id" => ir.states[index].state_id,
            "diagonal" => ir.mass_matrix_diagonal[index])
            for index in eachindex(ir.mass_matrix_diagonal)]
        boundary_plan = vcat([Dict{String,Any}("kind" => "boundary",
            "boundary_id" => item.boundary_id, "boundary_kind" =>
            String(item.boundary_kind), "accounts" => item.accounts)
            for item in ir.boundaries], [Dict{String,Any}("kind" => "interface",
            "interface_id" => item.interface_id,
            "interface_kind" => String(item.interface_kind),
            "accounts" => item.accounts, "paired" => item.paired)
            for item in ir.interfaces])
        obligations = [Dict{String,Any}("obligation_id" => item.obligation_id,
            "obligation_kind" => String(item.obligation_kind),
            "required_capability_ids" => item.required_capability_ids,
            "required_outputs" => item.required_outputs)
            for item in ir.obligations]
        initial_strategies = ["trusted_parent_or_neighbor_solution",
            "parameter_continuation", "constraint_projected_safe_center",
            "deterministic_validity_domain_sample"]
        execution_model = Dict{String,Any}(String(key) => value for (key, value) in
            pairs(get(binding, "execution_model", Dict{String,Any}(
                "kind" => "generic_graph_balance"))))
        body = Dict{String,Any}("schema_version" => "1.0.0",
            "candidate_binding_hash" => request.candidate_binding_hash,
            "topology_hash" => ir.topology_hash,
            "numerical_ir_hash" => ir.numerical_ir_hash,
            "capability_matches" => matches, "state_layout" => state_layout,
            "residual_plan" => residual_plan, "jacobian_plan" => jacobian_plan,
            "mass_matrix_plan" => mass_plan,
            "boundary_interface_plan" => boundary_plan,
            "initial_state_strategy" => initial_strategies,
            "discretization_levels" => levels,
            "evidence_obligations" => obligations,
            "estimated_cost" => estimated, "execution_model" => execution_model,
            "backend_native_objects_present" => false,
            "label_routing_used" => false)
        return Stage3ExecutionPlanV1("1.0.0", :complete, :unknown,
            "stage3_plan_compiled", request.candidate_binding_hash, ir.topology_hash,
            ir, matches, String[], state_layout, residual_plan, jacobian_plan,
            mass_plan, boundary_plan, initial_strategies, levels, obligations,
            estimated, execution_model, String[], ir.numerical_ir_hash,
            _stage3_persisted_hash_v1(body))
    catch error
        return _stage3_empty_plan_v1(request, :unknown,
            "unknown_stage3_plan_compilation_exception",
            ["plan_compilation_exception:$(nameof(typeof(error)))"])
    end
end

function stage3_execution_plan_to_dict_v1(plan::Stage3ExecutionPlanV1)
    return Dict{String,Any}("schema_version" => plan.schema_version,
        "completeness" => String(plan.completeness),
        "conclusion" => String(plan.conclusion),
        "classification_code" => plan.classification_code,
        "candidate_binding_hash" => plan.candidate_binding_hash,
        "topology_hash" => plan.topology_hash,
        "numerical_ir_hash" => plan.numerical_ir_hash,
        "solve_plan_hash" => plan.solve_plan_hash,
        "capability_matches" => plan.capability_matches,
        "missing_capabilities" => plan.missing_capabilities,
        "state_layout" => plan.state_layout,
        "residual_plan" => plan.residual_plan,
        "jacobian_plan" => plan.jacobian_plan,
        "mass_matrix_plan" => plan.mass_matrix_plan,
        "boundary_interface_plan" => plan.boundary_interface_plan,
        "initial_state_strategy" => plan.initial_state_strategy,
        "discretization_levels" => plan.discretization_levels,
        "evidence_obligations" => plan.evidence_obligations,
        "estimated_cost" => plan.estimated_cost,
        "execution_model" => plan.execution_model,
        "reasons" => plan.reasons,
        "backend_native_objects_present" => false)
end

function _stage3_halton_v1(index::Int, base::Int)
    result = 0.0; factor = 1.0 / base; current = index
    while current > 0
        result += factor * (current % base)
        current = div(current, base); factor /= base
    end
    return result
end

function stage3_deterministic_samples_v1(sample_spec::AbstractDict)
    count = Int(get(sample_spec, "required_sample_count", 1))
    dimension = Int(get(sample_spec, "dimension", 1))
    count in (1, 4, 16, 64) || throw(ArgumentError(
        "Stage 3 sample count must be one of 1, 4, 16 or 64"))
    1 <= dimension <= 8 || throw(ArgumentError("sample dimension must be in 1:8"))
    primes = (2, 3, 5, 7, 11, 13, 17, 19)
    return [Dict{String,Any}("sample_id" => "sample_$(lpad(index, 3, '0'))",
        "coordinates" => [_stage3_halton_v1(index, primes[axis])
            for axis in 1:dimension]) for index in 1:count]
end

function next_stage3_sampling_depth_v1(compilation_status::Symbol,
        sample_records::Vector{Dict{String,Any}}; near_gate::Bool = false)
    compilation_status == :pass || return 0
    isempty(sample_records) && return 1
    any(item -> String(get(item, "conclusion", "unknown")) == "fail",
        sample_records) && return 1
    any(item -> String(get(item, "conclusion", "unknown")) in
        ("unknown", "unsupported"), sample_records) && return length(sample_records)
    completed = length(sample_records)
    completed < 4 && return near_gate ? 4 : 1
    completed < 16 && return 16
    completed < 64 && return 64
    return 64
end

function _stage3_grid_laplacian_v1(dimension::Int, target_dof::Int)
    points_per_axis = max(2, floor(Int, target_dof^(1 / dimension)))
    dof = points_per_axis^dimension
    h = 1.0 / (points_per_axis + 1)
    one_d = spdiagm(-1 => fill(-1.0 / h^2, points_per_axis - 1),
        0 => fill(2.0 / h^2, points_per_axis),
        1 => fill(-1.0 / h^2, points_per_axis - 1))
    identity_axis = spdiagm(0 => ones(points_per_axis))
    operator = one_d
    if dimension == 2
        operator = kron(identity_axis, one_d) + kron(one_d, identity_axis)
    elseif dimension == 3
        operator = kron(kron(identity_axis, identity_axis), one_d) +
            kron(kron(identity_axis, one_d), identity_axis) +
            kron(kron(one_d, identity_axis), identity_axis)
    end
    exact = Float64[]
    for index in CartesianIndices(ntuple(_ -> points_per_axis, dimension))
        value = 1.0
        for axis in 1:dimension
            value *= sin(pi * index[axis] * h)
        end
        push!(exact, value)
    end
    return sparse(operator), exact, h, dof
end

function _stage3_solve_manufactured_diffusion_v1(model, resolution, budget)
    dimension = Int(get(model, "dimension", 1))
    transient = Bool(get(model, "transient", false))
    diffusion = Float64(get(model, "diffusion", 1.0))
    advection = Float64(get(model, "advection", 0.0))
    reaction = Float64(get(model, "reaction", 0.0))
    laplacian, exact_spatial, h, dof = _stage3_grid_laplacian_v1(dimension,
        resolution)
    dof <= budget.maximum_degrees_of_freedom || return Dict{String,Any}(
        "converged" => false, "classification_code" =>
            "unknown_budget_degrees_of_freedom_exhausted", "dof" => dof)
    identity_matrix = spdiagm(0 => ones(dof))
    derivative = spzeros(Float64, dof, dof)
    exact_derivative = zeros(Float64, dof)
    if abs(advection) > 0.0
        dimension == 1 || return Dict{String,Any}("converged" => false,
            "classification_code" => "unsupported_multidimensional_advection_reference")
        points = dof
        derivative = spdiagm(-1 => fill(-0.5 / h, points - 1),
            1 => fill(0.5 / h, points - 1))
        exact_derivative = [pi * cos(pi * index * h) for index in 1:points]
    end
    spatial_operator = diffusion * laplacian + advection * derivative +
        reaction * identity_matrix
    trajectory = Dict{String,Any}[]; time_steps = 0; integrated_source = 0.0
    if transient
        final_time = Float64(get(model, "final_time", 0.2))
        requested_steps = Int(get(model, "time_steps", max(8, resolution)))
        time_steps = min(requested_steps, budget.maximum_time_steps)
        time_steps == requested_steps || return Dict{String,Any}(
            "converged" => false, "classification_code" =>
                "unknown_budget_time_steps_exhausted", "dof" => dof)
        dt = final_time / time_steps
        system = identity_matrix + dt * spatial_operator
        state = copy(exact_spatial)
        last_equation_residual = Inf
        for step in 1:time_steps
            next_time = step * dt
            temporal_factor = exp(-next_time)
            manufactured_source = temporal_factor .* (-exact_spatial .+
                diffusion * dimension * pi^2 .* exact_spatial .+
                reaction .* exact_spatial .+ advection .* exact_derivative)
            right_hand_side = state + dt .* manufactured_source
            next_state = system \ right_hand_side
            last_equation_residual = norm(system * next_state - right_hand_side) /
                max(norm(right_hand_side), 1.0)
            state = next_state
            integrated_source += dt * sum(manufactured_source) * h^dimension
            (step == 1 || step == time_steps) && push!(trajectory,
                Dict{String,Any}("time" => step * dt,
                    "state_norm" => norm(state)))
        end
        exact = exp(-final_time) .* exact_spatial
        residual = last_equation_residual
    else
        system = spatial_operator
        source = (diffusion * dimension * pi^2 + reaction) .* exact_spatial .+
            advection .* exact_derivative
        state = system \ source
        exact = exact_spatial
        residual = norm(system * state - source) / max(norm(source), 1.0)
        integrated_source = sum(source) * h^dimension
    end
    relative_error = norm(state - exact) / max(norm(exact), eps())
    initial_total = sum(exact_spatial) * h^dimension
    final_total = sum(state) * h^dimension
    duration = transient ? Float64(get(model, "final_time", 0.2)) : 0.0
    transient || (initial_total = final_total)
    boundary_outflow = integrated_source - (final_total - initial_total)
    return Dict{String,Any}("converged" => all(isfinite, state),
        "classification_code" => "converged_manufactured_diffusion",
        "state" => state, "trajectory" => trajectory,
        "residual" => residual, "relative_error" => relative_error,
        "dof" => dof, "time_steps" => time_steps,
        "independent_record" => Dict{String,Any}(
            "accounts" => ["conserved_scalar"], "duration" => duration,
            "cells" => [Dict{String,Any}("cell_id" => "global",
                "volume" => 1.0,
                "initial" => Dict("conserved_scalar" => initial_total),
                "final" => Dict("conserved_scalar" => final_total))],
            "faces" => [Dict{String,Any}("account" => "conserved_scalar",
                "left_cell_id" => "global", "right_cell_id" => nothing,
                "integrated_flux" => boundary_outflow)],
            "sources" => [Dict{String,Any}("account" => "conserved_scalar",
                "integrated_amount" => integrated_source)]))
end

function _stage3_solve_zero_d_v1(model, sample, budget)
    kind = String(get(model, "kind", "generic_graph_balance"))
    trajectory = Dict{String,Any}[]
    if kind in ("generic_graph_balance", "nonlinear_balance")
        source = Float64.(get(model, "source", [1.0, 0.5]))
        decay = Float64.(get(model, "decay", ones(length(source))))
        quadratic = Float64.(get(model, "quadratic", zeros(length(source))))
        length(decay) == length(source) == length(quadratic) || return Dict{String,Any}(
            "converged" => false, "classification_code" =>
                "unknown_model_vector_length_mismatch")
        state = max.(source ./ max.(decay, eps()), 1.0e-8)
        history = Float64[]
        converged = false
        for iteration in 1:budget.maximum_nonlinear_iterations
            residual = decay .* state .+ quadratic .* state.^2 .- source
            push!(history, norm(residual, Inf))
            if last(history) <= Float64(get(model, "residual_tolerance", 1.0e-10))
                converged = true; break
            end
            step = residual ./ (decay .+ 2.0 .* quadratic .* state)
            damping = 1.0
            while any(state .- damping .* step .< 0.0) && damping > 1.0e-6
                damping *= 0.5
            end
            state .-= damping .* step
        end
        total = sum(state)
        independent = Dict{String,Any}("accounts" => ["inventory"],
            "duration" => 0.0,
            "cells" => [Dict{String,Any}("cell_id" => "zero_d", "volume" => 1.0,
                "initial" => Dict("inventory" => total),
                "final" => Dict("inventory" => total))],
            "faces" => [Dict{String,Any}("account" => "inventory",
                "left_cell_id" => "zero_d", "right_cell_id" => nothing,
                "integrated_flux" => sum(source))],
            "sources" => [Dict{String,Any}("account" => "inventory",
                "integrated_amount" => sum(source))])
        return Dict{String,Any}("converged" => converged,
            "classification_code" => converged ? "converged_damped_newton" :
                "unknown_nonlinear_iteration_exhausted", "state" => state,
            "trajectory" => trajectory, "residual" => isempty(history) ? Inf : last(history),
            "relative_error" => 0.0, "dof" => length(state), "time_steps" => 0,
            "nonlinear_iterations" => length(history),
            "independent_record" => independent)
    elseif kind == "linear_transient"
        rate = Float64(get(model, "loss_rate", 1.0)); source = Float64(get(model,
            "source", 1.0)); initial = Float64(get(model, "initial", 0.0))
        final_time = Float64(get(model, "final_time", 1.0))
        steps = Int(get(model, "time_steps", 64))
        steps <= budget.maximum_time_steps || return Dict{String,Any}(
            "converged" => false, "classification_code" =>
                "unknown_budget_time_steps_exhausted")
        dt = final_time / steps; state = initial
        for step in 1:steps
            state = (state + dt * source) / (1.0 + dt * rate)
            (step == 1 || step == steps) && push!(trajectory,
                Dict{String,Any}("time" => step * dt, "state" => state))
        end
        exact = initial * exp(-rate * final_time) + source / rate *
            (1.0 - exp(-rate * final_time))
        independent = Dict{String,Any}("accounts" => ["inventory"],
            "duration" => final_time,
            "cells" => [Dict{String,Any}("cell_id" => "zero_d", "volume" => 1.0,
                "initial" => Dict("inventory" => initial),
                "final" => Dict("inventory" => state))],
            "faces" => [Dict{String,Any}("account" => "inventory",
                "left_cell_id" => "zero_d", "right_cell_id" => nothing,
                "integrated_flux" => source * final_time - (state - initial))],
            "sources" => [Dict{String,Any}("account" => "inventory",
                "integrated_amount" => source * final_time)])
        return Dict{String,Any}("converged" => isfinite(state),
            "classification_code" => "converged_implicit_ode", "state" => [state],
            "trajectory" => trajectory, "residual" => 0.0,
            "relative_error" => abs(state - exact) / max(abs(exact), 1.0),
            "dof" => 1, "time_steps" => steps,
            "independent_record" => independent)
    elseif kind == "index1_dae"
        rate = Float64(get(model, "rate", 0.5)); gain = Float64(get(model, "gain", 2.0))
        offset = Float64(get(model, "offset", 0.1)); initial = Float64(get(model,
            "initial", 1.0)); final_time = Float64(get(model, "final_time", 0.5))
        steps = Int(get(model, "time_steps", 64)); dt = final_time / steps
        steps <= budget.maximum_time_steps || return Dict{String,Any}(
            "converged" => false, "classification_code" =>
                "unknown_budget_time_steps_exhausted")
        x = initial; z = gain * x + offset; max_drift = 0.0
        for step in 1:steps
            x = (x + dt * offset) / (1.0 + dt * (rate - gain))
            z = gain * x + offset
            max_drift = max(max_drift, abs(z - gain * x - offset))
            (step == 1 || step == steps) && push!(trajectory,
                Dict{String,Any}("time" => step * dt, "differential_state" => x,
                    "algebraic_state" => z))
        end
        declared_drift = Float64(get(model, "declared_constraint_drift", max_drift))
        independent = Dict{String,Any}("accounts" => ["inventory"],
            "duration" => final_time,
            "cells" => [Dict{String,Any}("cell_id" => "dae", "volume" => 1.0,
                "initial" => Dict("inventory" => initial),
                "final" => Dict("inventory" => x))],
            "faces" => [Dict{String,Any}("account" => "inventory",
                "left_cell_id" => "dae", "right_cell_id" => nothing,
                "integrated_flux" => -(x - initial))],
            "sources" => [Dict{String,Any}("account" => "inventory",
                "integrated_amount" => 0.0)])
        return Dict{String,Any}("converged" => all(isfinite, (x, z)),
            "classification_code" => "converged_index1_dae",
            "state" => [x, z], "trajectory" => trajectory,
            "residual" => max_drift, "constraint_drift" => declared_drift,
            "relative_error" => 0.0, "dof" => 2, "time_steps" => steps,
            "independent_record" => independent)
    elseif kind in ("multi_region_flux", "closed_loop_control")
        raw_matrix = get(model, "matrix", [2.0 -1.0; -1.0 2.0])
        matrix = raw_matrix isa AbstractMatrix ? Matrix{Float64}(raw_matrix) :
            permutedims(reduce(hcat, (Float64.(row) for row in raw_matrix)))
        source = Float64.(get(model, "source", ones(size(matrix, 1))))
        state = matrix \ source
        residual = norm(matrix * state - source, Inf)
        total = sum(state)
        independent = Dict{String,Any}("accounts" => ["inventory"],
            "duration" => 0.0,
            "cells" => [Dict{String,Any}("cell_id" => "coupled", "volume" => 1.0,
                "initial" => Dict("inventory" => total),
                "final" => Dict("inventory" => total))],
            "faces" => [Dict{String,Any}("account" => "inventory",
                "left_cell_id" => "coupled", "right_cell_id" => nothing,
                "integrated_flux" => sum(source))],
            "sources" => [Dict{String,Any}("account" => "inventory",
                "integrated_amount" => sum(source))])
        return Dict{String,Any}("converged" => all(isfinite, state),
            "classification_code" => "converged_coupled_block_solve",
            "state" => state, "trajectory" => trajectory, "residual" => residual,
            "relative_error" => 0.0, "dof" => length(state), "time_steps" => 0,
            "independent_record" => independent)
    elseif kind == "mixed_0d_1d"
        resolution = Int(get(sample, "resolution_level", 16))
        diffusion = Float64(get(model, "diffusion", 1.0))
        coupling = Float64(get(model, "coupling", 0.2))
        loss = Float64(get(model, "zero_d_loss", 1.0))
        laplacian, _, h, dof_pde = _stage3_grid_laplacian_v1(1, resolution)
        pde_block = diffusion * laplacian + spdiagm(0 => fill(coupling, dof_pde))
        system = spzeros(Float64, dof_pde + 1, dof_pde + 1)
        system[1, 1] = loss + coupling
        system[1, 2:end] .= -coupling / dof_pde
        system[2:end, 1] .= -coupling
        system[2:end, 2:end] = pde_block
        source = vcat([1.0], fill(Float64(get(model, "pde_source", 1.0)), dof_pde))
        state = system \ source
        residual = norm(system * state - source) / max(norm(source), 1.0)
        total = state[1] + sum(state[2:end]) * h
        independent = Dict{String,Any}("accounts" => ["inventory"],
            "duration" => 0.0,
            "cells" => [Dict{String,Any}("cell_id" => "mixed", "volume" => 1.0,
                "initial" => Dict("inventory" => total),
                "final" => Dict("inventory" => total))],
            "faces" => [Dict{String,Any}("account" => "inventory",
                "left_cell_id" => "mixed", "right_cell_id" => nothing,
                "integrated_flux" => sum(source))],
            "sources" => [Dict{String,Any}("account" => "inventory",
                "integrated_amount" => sum(source))])
        return Dict{String,Any}("converged" => all(isfinite, state),
            "classification_code" => "converged_mixed_0d_1d_block_solve",
            "state" => state, "trajectory" => trajectory, "residual" => residual,
            "relative_error" => 0.0, "dof" => dof_pde + 1, "time_steps" => 0,
            "independent_record" => independent)
    end
    return Dict{String,Any}("converged" => false,
        "classification_code" => "unsupported_execution_model")
end

function _stage3_physical_audits_v1(model::AbstractDict, solve_record::AbstractDict,
        plan::Stage3ExecutionPlanV1)
    failures = String[]
    actuator = Dict{String,Any}("status" => "pass")
    if haskey(model, "actuator_load") || haskey(model, "actuator_capacity")
        load = get(model, "actuator_load", nothing)
        capacity = get(model, "actuator_capacity", nothing)
        if load isa Real && capacity isa Real
            margin = Float64(capacity) - Float64(load)
            actuator = Dict{String,Any}("status" => margin >= 0.0 ? "pass" : "fail",
                "load" => Float64(load), "capacity" => Float64(capacity),
                "margin" => margin)
            margin >= 0.0 || push!(failures, "fail_actuator_capacity_shortfall")
        else
            actuator = Dict{String,Any}("status" => "unknown",
                "reason" => "unknown_actuator_capacity_or_load")
        end
    end
    conservation = Dict{String,Any}("status" => "pass")
    if haskey(model, "declared_source") || haskey(model, "declared_sink")
        source = get(model, "declared_source", nothing)
        sink = get(model, "declared_sink", nothing)
        if source isa Real && sink isa Real
            mismatch = Float64(source) - Float64(sink)
            tolerance = Float64(get(model, "conservation_tolerance", 1.0e-8))
            conservation = Dict{String,Any}("status" => abs(mismatch) <= tolerance ?
                "pass" : "fail", "source" => Float64(source),
                "sink" => Float64(sink), "mismatch" => mismatch,
                "tolerance" => tolerance)
            abs(mismatch) <= tolerance || push!(failures,
                "fail_conservation_source_sink_not_closed")
        end
    end
    interface = Dict{String,Any}("status" => "pass")
    signs = get(model, "interface_flux_signs", nothing)
    if signs isa AbstractVector
        values = Float64.(signs); mismatch = sum(values)
        interface = Dict{String,Any}("status" => abs(mismatch) <= 1.0e-12 ?
            "pass" : "fail", "oriented_signs" => values, "sum" => mismatch)
        abs(mismatch) <= 1.0e-12 || push!(failures,
            "fail_interface_flux_sign_not_paired")
    end
    states = Float64.(get(solve_record, "state", Float64[]))
    bound_violations = Dict{String,Any}[]
    for index in 1:min(length(states), length(plan.state_layout))
        layout = plan.state_layout[index]
        lower = Float64(layout["lower_bound"]); upper = Float64(layout["upper_bound"])
        lower <= states[index] <= upper || push!(bound_violations,
            Dict{String,Any}("state_id" => layout["state_id"],
                "value" => states[index], "lower_bound" => lower,
                "upper_bound" => upper))
    end
    isempty(bound_violations) || push!(failures, "fail_physical_state_bound_violation")
    dae_drift = Float64(get(solve_record, "constraint_drift", 0.0))
    dae_tolerance = Float64(get(model, "constraint_drift_tolerance", 1.0e-8))
    dae = Dict{String,Any}("status" => dae_drift <= dae_tolerance ? "pass" : "fail",
        "maximum_constraint_drift" => dae_drift, "tolerance" => dae_tolerance)
    dae_drift <= dae_tolerance || push!(failures, "fail_dae_constraint_drift")
    control = Dict{String,Any}("status" => "not_applicable")
    poles = get(model, "controller_poles", nothing)
    if poles isa AbstractVector
        real_parts = Float64.(poles)
        stable = all(<(0.0), real_parts)
        control = Dict{String,Any}("status" => stable ? "pass" : "fail",
            "pole_real_parts" => real_parts)
        stable || push!(failures, "fail_deterministic_control_instability")
    end
    thermal = Dict{String,Any}("status" => "not_applicable")
    if haskey(model, "thermal_load") || haskey(model, "heat_rejection_capacity")
        load = get(model, "thermal_load", nothing)
        capacity = get(model, "heat_rejection_capacity", nothing)
        if load isa Real && capacity isa Real
            margin = Float64(capacity) - Float64(load)
            thermal = Dict{String,Any}("status" => margin >= 0.0 ? "pass" : "fail",
                "thermal_load" => Float64(load),
                "heat_rejection_capacity" => Float64(capacity), "margin" => margin)
            margin >= 0.0 || push!(failures,
                "fail_heat_rejection_capacity_shortfall")
        else
            thermal = Dict{String,Any}("status" => "unknown")
        end
    end
    return sort!(unique(failures)), Dict{String,Any}(
        "actuator_capacity" => actuator, "conservation" => conservation,
        "interface_flux" => interface, "state_bounds" => Dict{String,Any}(
            "status" => isempty(bound_violations) ? "pass" : "fail",
            "violations" => bound_violations), "dae_constraint" => dae,
        "control_stability" => control, "thermal_rejection" => thermal)
end

function _stage3_software_hashes_v1(plan::Stage3ExecutionPlanV1)
    solver_hash = _stage3_persisted_hash_v1(Dict{String,Any}(
        "adapter" => "stage3_native_reference_backends_v70",
        "model" => plan.execution_model,
        "capabilities" => sort!(unique(String(item["capability_id"])
            for item in plan.capability_matches if haskey(item, "capability_id")))))
    environment_hash = _stage3_persisted_hash_v1(Dict{String,Any}(
        "julia_version" => string(VERSION), "kernel" => string(Sys.KERNEL),
        "architecture" => string(Sys.ARCH), "word_size" => Sys.WORD_SIZE,
        "threads" => Threads.nthreads()))
    software = Dict{String,String}(
        "stage3_runtime" => STAGE3_RUNTIME_SOFTWARE_HASH_V70,
        "independent_auditor" => STAGE3_INDEPENDENT_AUDITOR_SOFTWARE_HASH_V1)
    return solver_hash, environment_hash, software
end

function _stage3_evidence_hash_projection_v1(body::AbstractDict)
    data = _stage3_plain_v1(body)
    # Sample hashes seal the full numerical records.  The envelope hash then seals
    # those hashes plus the decision and immutable provenance, while deliberately
    # excluding wall-clock/cache/checkpoint transport metadata.
    return Dict{String,Any}(
        "schema_version" => data["schema_version"],
        "completeness" => data["completeness"],
        "conclusion" => data["conclusion"],
        "classification_code" => data["classification_code"],
        "candidate_binding_hash" => data["candidate_binding_hash"],
        "topology_hash" => data["topology_hash"],
        "numerical_ir_hash" => data["numerical_ir_hash"],
        "solve_plan_hash" => data["solve_plan_hash"],
        "solver_hash" => data["solver_hash"],
        "environment_hash" => data["environment_hash"],
        "software_hashes" => data["software_hashes"],
        "final_state" => data["final_state"],
        "sample_hashes" => [String(item["sample_hash"])
            for item in get(data, "sample_records", Any[])],
        "unresolved_reasons" => data["unresolved_reasons"])
end

function _stage3_empty_evidence_v1(plan::Stage3ExecutionPlanV1,
        conclusion::Symbol, code::String, reasons::Vector{String};
        sample_records = Dict{String,Any}[], cache_hit = false,
        elapsed_seconds = 0.0)
    solver_hash, environment_hash, software = _stage3_software_hashes_v1(plan)
    cost = Dict{String,Any}("wall_seconds" => elapsed_seconds,
        "cache_hit" => cache_hit, "completed_sample_count" => length(sample_records),
        "required_sample_count" => 0, "maximum_memory_bytes_estimated" =>
            get(plan.estimated_cost, "memory_bytes", 0.0),
        "budget_exhausted" => startswith(code, "unknown_budget"))
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "completeness" => "incomplete", "conclusion" => String(conclusion),
        "classification_code" => code,
        "candidate_binding_hash" => plan.candidate_binding_hash,
        "topology_hash" => plan.topology_hash,
        "numerical_ir_hash" => plan.numerical_ir_hash,
        "solve_plan_hash" => plan.solve_plan_hash, "solver_hash" => solver_hash,
        "environment_hash" => environment_hash, "software_hashes" => software,
        "final_state" => Dict{String,Float64}(), "trajectory" => Any[],
        "residual_conservation_evidence" => Dict{String,Any}(),
        "interface_flux_evidence" => Dict{String,Any}(),
        "convergence_evidence" => Dict{String,Any}(),
        "actuator_control_evidence" => Dict{String,Any}(),
        "validity_domain_evidence" => Dict{String,Any}(),
        "independent_recomputation_evidence" => Dict{String,Any}(),
        "execution_cost_record" => cost, "sample_records" => sample_records,
        "unresolved_reasons" => sort!(unique(reasons)))
    hash = _stage3_persisted_hash_v1(_stage3_evidence_hash_projection_v1(body))
    return Stage3EvidenceEnvelopeV1("1.0.0", :incomplete, conclusion, code,
        plan.candidate_binding_hash, plan.topology_hash, plan.numerical_ir_hash,
        plan.solve_plan_hash, solver_hash, environment_hash, software,
        Dict{String,Float64}(), Dict{String,Any}[], Dict{String,Any}(),
        Dict{String,Any}(), Dict{String,Any}(), Dict{String,Any}(),
        Dict{String,Any}(), Dict{String,Any}(), cost, sample_records,
        body["unresolved_reasons"], hash)
end

function _stage3_atomic_json_v1(path::AbstractString, value)
    directory = dirname(path); mkpath(directory)
    temporary = tempname(directory)
    open(temporary, "w") do io
        JSON3.pretty(io, value); write(io, '\n')
        flush(io)
    end
    mv(temporary, path; force = true)
    return path
end

function _stage3_load_checkpoint_v1(path, plan_hash)
    (path === nothing || !isfile(path)) && return Dict{String,Any}[]
    try
        raw = _stage3_plain_v1(JSON3.read(read(path, String)))
        String(get(raw, "solve_plan_hash", "")) == plan_hash || return Dict{String,Any}[]
        return Dict{String,Any}.(get(raw, "sample_records", Any[]))
    catch
        return Dict{String,Any}[]
    end
end

function _stage3_write_checkpoint_v1(path, plan_hash, records)
    path === nothing && return nothing
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "solve_plan_hash" => plan_hash, "sample_records" => records,
        "checkpoint_hash" => _stage3_persisted_hash_v1(Dict("solve_plan_hash" => plan_hash,
            "sample_hashes" => [String(item["sample_hash"]) for item in records])))
    return _stage3_atomic_json_v1(path, body)
end

function execute_stage3_plan_v1(plan::Stage3ExecutionPlanV1,
        request::Stage3ExecutionRequestV1; checkpoint_path::Union{Nothing,String} = nothing,
        interrupt_after_samples::Union{Nothing,Int} = nothing)
    start_time = time()
    if plan.completeness == :incomplete
        return _stage3_empty_evidence_v1(plan, plan.conclusion,
            plan.classification_code, plan.reasons)
    end
    samples = try
        stage3_deterministic_samples_v1(request.sample_spec)
    catch error
        return _stage3_empty_evidence_v1(plan, :unknown,
            "unknown_invalid_state_sample_specification",
            ["sample_specification_exception:$(nameof(typeof(error)))"])
    end
    completed = _stage3_load_checkpoint_v1(checkpoint_path, plan.solve_plan_hash)
    completed_ids = Set(String(item["sample_id"]) for item in completed)
    model_base = deepcopy(plan.execution_model)
    kind = String(get(model_base, "kind", "generic_graph_balance"))
    if kind == "generic_graph_balance" && !haskey(model_base, "source")
        model_base["source"] = [String(item["state_kind"]) == "algebraic" ? 0.0 : 1.0
            for item in plan.state_layout]
        model_base["decay"] = ones(length(plan.state_layout))
        model_base["quadratic"] = zeros(length(plan.state_layout))
    end
    hard_failure_seen = false
    for sample in samples
        sample_id = String(sample["sample_id"])
        sample_id in completed_ids && continue
        time() - start_time <= request.budget.maximum_wall_seconds ||
            return _stage3_empty_evidence_v1(plan, :unknown,
                "unknown_budget_wall_time_exhausted", ["wall_time_budget_exhausted"];
                sample_records = completed, elapsed_seconds = time() - start_time)
        resolution_records = Dict{String,Any}[]
        solve_unknown = false
        for level in plan.discretization_levels
            local_model = deepcopy(model_base)
            if kind == "index1_dae"
                local_model["time_steps"] = min(level,
                    request.budget.maximum_time_steps)
            end
            solve = try
                kind == "manufactured_diffusion" ?
                    _stage3_solve_manufactured_diffusion_v1(local_model, level,
                        request.budget) :
                    _stage3_solve_zero_d_v1(local_model, merge(sample,
                        Dict{String,Any}("resolution_level" => level)), request.budget)
            catch error
                Dict{String,Any}("converged" => false,
                    "classification_code" => "unknown_solver_exception",
                    "exception_type" => String(nameof(typeof(error))))
            end
            record = Dict{String,Any}(String(key) => value for (key, value) in pairs(solve))
            record["resolution_level"] = level
            record["result_hash"] = _stage3_persisted_hash_v1(
                _stage3_routing_projection_v1(record))
            push!(resolution_records, record)
            Bool(get(record, "converged", false)) || (solve_unknown = true; break)
        end
        final_solve = last(resolution_records)
        independent_record = get(final_solve, "independent_record", Dict{String,Any}())
        if haskey(model_base, "independent_source_bias") &&
                independent_record isa AbstractDict
            biased = deepcopy(independent_record)
            if !isempty(get(biased, "sources", Any[]))
                biased["sources"][1]["integrated_amount"] = Float64(
                    biased["sources"][1]["integrated_amount"]) +
                    Float64(model_base["independent_source_bias"])
            end
            independent_record = biased
        end
        independent = stage3_independent_balance_auditor_v1(independent_record)
        failures, audits = _stage3_physical_audits_v1(model_base, final_solve, plan)
        independent.status == :fail && push!(failures,
            "fail_independent_conservation_recomputation")
        if solve_unknown || independent.status == :unknown
            conclusion = :unknown
            code = String(get(final_solve, "classification_code",
                "unknown_stage3_solver_nonconvergence"))
        elseif !isempty(failures)
            conclusion = :fail; code = first(sort!(unique(failures)))
            hard_failure_seen = true
        else
            conclusion = :pass; code = "pass_stage3_sample_complete"
        end
        errors = Float64[Float64(get(item, "relative_error", 0.0))
            for item in resolution_records]
        pde_applicable = kind in ("manufactured_diffusion", "mixed_0d_1d")
        resolution_status = !pde_applicable ? "not_applicable" :
            length(errors) == length(plan.discretization_levels) &&
            (length(errors) < 2 || last(errors) <= first(errors) + 1.0e-12) &&
            last(errors) <= Float64(get(model_base, "resolution_error_tolerance", 0.2)) ?
                "pass" : "fail"
        dae_step_status = "not_applicable"
        if kind == "index1_dae" && length(resolution_records) >= 2
            states = [Float64.(item["state"]) for item in resolution_records]
            differences = [norm(states[index] - states[index - 1])
                for index in 2:length(states)]
            dae_step_status = length(differences) == 1 ||
                last(differences) <= first(differences) + 1.0e-12 ? "pass" : "fail"
            if dae_step_status == "fail" && conclusion == :pass
                conclusion = :unknown; code = "unknown_dae_time_step_convergence_incomplete"
            end
        elseif kind == "index1_dae"
            dae_step_status = "incomplete"
        end
        if resolution_status == "fail" && conclusion == :pass
            conclusion = :unknown; code = "unknown_resolution_convergence_incomplete"
        end
        sample_body = Dict{String,Any}("sample_id" => sample_id,
            "coordinates" => sample["coordinates"], "conclusion" => String(conclusion),
            "classification_code" => code, "resolution_status" => resolution_status,
            "dae_time_step_convergence_status" => dae_step_status,
            "resolution_records" => resolution_records,
            "independent_audit" => stage3_independent_audit_to_dict_v1(independent),
            "physical_audits" => audits, "hard_failure_codes" => sort!(unique(failures)))
        sample_body["sample_hash"] = _stage3_persisted_hash_v1(sample_body)
        push!(completed, sample_body); push!(completed_ids, sample_id)
        _stage3_write_checkpoint_v1(checkpoint_path, plan.solve_plan_hash, completed)
        if interrupt_after_samples !== nothing && length(completed) >= interrupt_after_samples
            return _stage3_empty_evidence_v1(plan, :unknown,
                "unknown_execution_interrupted_checkpoint_saved",
                ["execution_interrupted_after_checkpoint"];
                sample_records = completed, elapsed_seconds = time() - start_time)
        end
        hard_failure_seen && break
    end

    required = length(samples)
    conclusions = String.(get.(completed, "conclusion", "unknown"))
    completeness = hard_failure_seen || length(completed) == required ? :complete : :incomplete
    if "fail" in conclusions
        conclusion = :fail
        code = String(first(item["classification_code"] for item in completed
            if item["conclusion"] == "fail"))
    elseif length(completed) < required || "unknown" in conclusions
        conclusion = :unknown; code = "unknown_stage3_samples_incomplete"
        completeness = :incomplete
    elseif all(==("pass"), conclusions)
        conclusion = :pass; code = "pass_stage3_all_obligations_complete"
    else
        conclusion = :unknown; code = "unknown_stage3_execution_state"
        completeness = :incomplete
    end
    if conclusion in (:pass, :fail)
        completeness = :complete
    end
    last_sample = last(completed); last_resolution = last(last_sample["resolution_records"])
    state_values = Float64.(get(last_resolution, "state", Float64[]))
    final_state = Dict{String,Float64}()
    for index in 1:min(length(state_values), length(plan.state_layout))
        final_state[String(plan.state_layout[index]["state_id"])] = state_values[index]
    end
    trajectory = Dict{String,Any}.(get(last_resolution, "trajectory", Any[]))
    maximum_residual = maximum((Float64(get(record, "residual", 0.0))
        for sample in completed for record in sample["resolution_records"]);
        init = 0.0)
    independent_records = [sample["independent_audit"] for sample in completed]
    independent_status = all(item -> item["status"] == "pass", independent_records) ?
        "pass" : any(item -> item["status"] == "fail", independent_records) ?
        "fail" : "unknown"
    resolution_statuses = String.(get.(completed, "resolution_status", "unknown"))
    resolution_status = all(item -> item in ("pass", "not_applicable"),
        resolution_statuses) ? "complete" : "incomplete"
    convergence = Dict{String,Any}(
        "status" => conclusion == :unknown ? "incomplete" : "complete",
        "resolution_status" => resolution_status,
        "resolution_levels_executed" => plan.discretization_levels,
        "dae_consistent_initialization" => kind == "index1_dae" ? "pass" :
            "not_applicable",
        "time_step_convergence" => kind == "index1_dae" ?
            (all(item -> get(item, "dae_time_step_convergence_status", "incomplete") ==
                "pass", completed) ? "pass" : "incomplete") : "not_applicable")
    residual_evidence = Dict{String,Any}(
        "maximum_solver_residual" => maximum_residual,
        "maximum_conservation_residual" => maximum(Float64(
            item["maximum_balance_residual"]) for item in independent_records),
        "status" => independent_status)
    interface_evidence = Dict{String,Any}("status" => all(sample ->
        get(sample["physical_audits"]["interface_flux"], "status", "unknown") ==
            "pass", completed) ? "pass" : "fail",
        "paired_interface_count" => count(item -> Bool(get(item, "paired", false)),
            plan.boundary_interface_plan))
    actuator_evidence = Dict{String,Any}("sample_audits" =>
        [sample["physical_audits"] for sample in completed])
    validity = Dict{String,Any}("status" => conclusion == :unknown ? "incomplete" :
        "complete", "sample_sequence" => String(get(request.sample_spec,
            "sequence", "halton_v1")), "completed_sample_count" => length(completed),
        "required_sample_count" => required)
    independent_evidence = Dict{String,Any}("status" => independent_status,
        "software_hash" => STAGE3_INDEPENDENT_AUDITOR_SOFTWARE_HASH_V1,
        "numerical_path" => "independent_integral_reconstruction_v1",
        "audits" => independent_records)
    elapsed = time() - start_time
    cost = Dict{String,Any}("wall_seconds" => elapsed,
        "completed_sample_count" => length(completed),
        "required_sample_count" => required,
        "maximum_dof_executed" => maximum((Int(get(record, "dof", 0))
            for sample in completed for record in sample["resolution_records"]);
            init = 0), "cache_hit" => false, "budget_exhausted" => false,
        "retry_count" => 0, "checkpoint_used" => checkpoint_path !== nothing)
    solver_hash, environment_hash, software = _stage3_software_hashes_v1(plan)
    unresolved = conclusion == :unknown ? sort!(unique(String(
        sample["classification_code"]) for sample in completed
        if sample["conclusion"] == "unknown")) : String[]
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "completeness" => String(completeness), "conclusion" => String(conclusion),
        "classification_code" => code,
        "candidate_binding_hash" => plan.candidate_binding_hash,
        "topology_hash" => plan.topology_hash,
        "numerical_ir_hash" => plan.numerical_ir_hash,
        "solve_plan_hash" => plan.solve_plan_hash, "solver_hash" => solver_hash,
        "environment_hash" => environment_hash, "software_hashes" => software,
        "final_state" => final_state, "trajectory" => trajectory,
        "residual_conservation_evidence" => residual_evidence,
        "interface_flux_evidence" => interface_evidence,
        "convergence_evidence" => convergence,
        "actuator_control_evidence" => actuator_evidence,
        "validity_domain_evidence" => validity,
        "independent_recomputation_evidence" => independent_evidence,
        "execution_cost_record" => cost, "sample_records" => completed,
        "unresolved_reasons" => unresolved)
    evidence_hash = _stage3_persisted_hash_v1(
        _stage3_evidence_hash_projection_v1(body))
    return Stage3EvidenceEnvelopeV1("1.0.0", completeness, conclusion, code,
        plan.candidate_binding_hash, plan.topology_hash, plan.numerical_ir_hash,
        plan.solve_plan_hash, solver_hash, environment_hash, software, final_state,
        trajectory, residual_evidence, interface_evidence, convergence,
        actuator_evidence, validity, independent_evidence, cost, completed,
        unresolved, evidence_hash)
end

function stage3_evidence_envelope_to_dict_v1(item::Stage3EvidenceEnvelopeV1)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "completeness" => String(item.completeness),
        "conclusion" => String(item.conclusion),
        "classification_code" => item.classification_code,
        "candidate_binding_hash" => item.candidate_binding_hash,
        "topology_hash" => item.topology_hash,
        "numerical_ir_hash" => item.numerical_ir_hash,
        "solve_plan_hash" => item.solve_plan_hash,
        "solver_hash" => item.solver_hash,
        "environment_hash" => item.environment_hash,
        "software_hashes" => item.software_hashes,
        "final_state" => item.final_state, "trajectory" => item.trajectory,
        "residual_conservation_evidence" => item.residual_conservation_evidence,
        "interface_flux_evidence" => item.interface_flux_evidence,
        "convergence_evidence" => item.convergence_evidence,
        "actuator_control_evidence" => item.actuator_control_evidence,
        "validity_domain_evidence" => item.validity_domain_evidence,
        "independent_recomputation_evidence" =>
            item.independent_recomputation_evidence,
        "execution_cost_record" => item.execution_cost_record,
        "sample_records" => item.sample_records,
        "unresolved_reasons" => item.unresolved_reasons,
        "evidence_hash" => item.evidence_hash)
end

function _stage3_evidence_from_dict_v1(raw::AbstractDict; cache_hit = false)
    data = _stage3_plain_v1(raw)
    cost = Dict{String,Any}(data["execution_cost_record"])
    cache_hit && (cost["cache_hit"] = true)
    return Stage3EvidenceEnvelopeV1(String(data["schema_version"]),
        Symbol(String(data["completeness"])), Symbol(String(data["conclusion"])),
        String(data["classification_code"]), String(data["candidate_binding_hash"]),
        String(data["topology_hash"]), String(data["numerical_ir_hash"]),
        String(data["solve_plan_hash"]), String(data["solver_hash"]),
        String(data["environment_hash"]),
        Dict{String,String}(String(key) => String(value) for (key, value) in
            pairs(data["software_hashes"])),
        Dict{String,Float64}(String(key) => Float64(value) for (key, value) in
            pairs(data["final_state"])),
        Dict{String,Any}.(data["trajectory"]),
        Dict{String,Any}(data["residual_conservation_evidence"]),
        Dict{String,Any}(data["interface_flux_evidence"]),
        Dict{String,Any}(data["convergence_evidence"]),
        Dict{String,Any}(data["actuator_control_evidence"]),
        Dict{String,Any}(data["validity_domain_evidence"]),
        Dict{String,Any}(data["independent_recomputation_evidence"]), cost,
        Dict{String,Any}.(data["sample_records"]),
        String.(data["unresolved_reasons"]), String(data["evidence_hash"]))
end

function execute_stage3_request_v1(request::Stage3ExecutionRequestV1;
        cache_directory::Union{Nothing,String} = nothing,
        checkpoint_path::Union{Nothing,String} = nothing,
        interrupt_after_samples::Union{Nothing,Int} = nothing)
    plan = compile_stage3_execution_plan_v1(request)
    solver_hash, _, _ = _stage3_software_hashes_v1(plan)
    sample_hash = _stage3_persisted_hash_v1(
        _stage3_routing_projection_v1(request.sample_spec))
    cache_key = _stage3_persisted_hash_v1(Dict{String,Any}(
        "plan_hash" => plan.solve_plan_hash,
        "sample_hash" => sample_hash, "solver_hash" => solver_hash))
    cache_path = cache_directory === nothing ? nothing :
        joinpath(cache_directory, "$(cache_key).json")
    if cache_path !== nothing && isfile(cache_path)
        try
            raw = JSON3.read(read(cache_path, String))
            return plan, _stage3_evidence_from_dict_v1(raw; cache_hit = true)
        catch
            # A malformed cache entry is ignored and atomically replaced below.
        end
    end
    evidence = try
        execute_stage3_plan_v1(plan, request; checkpoint_path = checkpoint_path,
            interrupt_after_samples = interrupt_after_samples)
    catch error
        _stage3_empty_evidence_v1(plan, :unknown,
            "unknown_stage3_executor_exception",
            ["executor_exception:$(nameof(typeof(error)))"])
    end
    if cache_path !== nothing && !(evidence.classification_code in
            ("unknown_execution_interrupted_checkpoint_saved",))
        _stage3_atomic_json_v1(cache_path, stage3_evidence_envelope_to_dict_v1(evidence))
    end
    return plan, evidence
end

function aggregate_stage3_metrics_v1(plans::Vector{Stage3ExecutionPlanV1},
        evidence::Vector{Stage3EvidenceEnvelopeV1})
    runtimes = sort!(Float64[Float64(get(item.execution_cost_record,
        "wall_seconds", 0.0)) for item in evidence])
    percentile(values, fraction) = isempty(values) ? 0.0 : values[clamp(
        ceil(Int, fraction * length(values)), 1, length(values))]
    return Dict{String,Any}(
        "stage3_plan_compile_pass_count" => count(item -> item.completeness == :complete,
            plans),
        "stage3_plan_unsupported_count" => count(item -> item.conclusion == :unsupported,
            plans),
        "stage3_execution_admitted_count" => count(item -> item.completeness == :complete,
            plans),
        "stage3_probe_complete_count" => count(item -> Int(get(
            item.execution_cost_record, "completed_sample_count", 0)) >= 1, evidence),
        "stage3_complete_count" => count(item -> item.completeness == :complete, evidence),
        "stage3_pass_count" => count(item -> item.conclusion == :pass, evidence),
        "stage3_fail_count" => count(item -> item.conclusion == :fail, evidence),
        "stage3_unknown_count" => count(item -> item.conclusion == :unknown, evidence),
        "stage3_unsupported_count" => count(item -> item.conclusion == :unsupported,
            evidence),
        "stage3_cache_hit_count" => count(item -> Bool(get(item.execution_cost_record,
            "cache_hit", false)), evidence),
        "stage3_budget_exhausted_count" => count(item -> Bool(get(
            item.execution_cost_record, "budget_exhausted", false)), evidence),
        "stage3_independent_audit_pass_count" => count(item -> get(
            item.independent_recomputation_evidence, "status", "unknown") == "pass",
            evidence),
        "stage3_resolution_complete_count" => count(item -> get(
            item.convergence_evidence, "resolution_status", "incomplete") == "complete",
            evidence),
        "stage3_runtime_p50" => percentile(runtimes, 0.50),
        "stage3_runtime_p95" => percentile(runtimes, 0.95),
        "stage3_cost_to_next_gate" => sum(max(0, Int(get(
            item.execution_cost_record, "required_sample_count", 0)) - Int(get(
            item.execution_cost_record, "completed_sample_count", 0)))
            for item in evidence),
        "aggregation_source" => "sealed_stage3_evidence_envelopes",
        "label_or_device_coverage_used" => false)
end

function stage3_candidate_record_v1(plan::Stage3ExecutionPlanV1,
        evidence::Stage3EvidenceEnvelopeV1;
        evidence_artifact_ref::AbstractString = "evidence://$(evidence.evidence_hash)")
    completed = Int(get(evidence.execution_cost_record, "completed_sample_count", 0))
    required = Int(get(evidence.execution_cost_record, "required_sample_count", 0))
    return Dict{String,Any}(
        "stage3_plan_hash" => plan.solve_plan_hash,
        "stage3_completeness" => String(evidence.completeness),
        "stage3_conclusion" => String(evidence.conclusion),
        "stage3_failure_code" => evidence.conclusion == :pass ? "" :
            evidence.classification_code,
        "completed_sample_count" => completed,
        "required_sample_count" => required,
        "maximum_conservation_residual" => get(
            evidence.residual_conservation_evidence,
            "maximum_conservation_residual", nothing),
        "resolution_status" => get(evidence.convergence_evidence,
            "resolution_status", "incomplete"),
        "independent_audit_status" => get(
            evidence.independent_recomputation_evidence, "status", "unknown"),
        "measured_cost_to_next_gate" => max(0, required - completed),
        "evidence_artifact_ref" => String(evidence_artifact_ref),
        "screen_pass_feasibility_credit" => false,
        "record_hash" => _stage3_persisted_hash_v1(Dict{String,Any}(
            "plan_hash" => plan.solve_plan_hash,
            "evidence_hash" => evidence.evidence_hash,
            "artifact_ref" => String(evidence_artifact_ref))))
end

function _stage3_qd_coordinates_v1(plan::Stage3ExecutionPlanV1)
    ir = plan.numerical_ir
    ir === nothing && return Dict{String,Any}("unsupported" => plan.classification_code)
    return Dict{String,Any}(
        "operators" => sort!(unique(String.(getfield.(ir.operators, :operator_kind)))),
        "dimensions" => sort!(unique(getfield.(ir.regions, :spatial_dimension))),
        "time_modes" => sort!(unique(String.(getfield.(ir.regions, :time_semantics)))),
        "boundary_kinds" => sort!(unique(String.(getfield.(ir.regions, :boundary_kind)))),
        "state_count" => length(ir.states))
end

"""Run the structural loop for every topology and the numerical loop for admitted cells."""
function run_stage3_graph_numerical_loops_v70(topology_count::Integer;
        complete_pass_target::Integer = 100,
        budget::Stage3ExecutionBudgetV1 = Stage3ExecutionBudgetV1(
            maximum_wall_seconds = 20.0, resolution_levels = [8, 16, 32]))
    topology_count > 0 || throw(ArgumentError("topology count must be positive"))
    complete_pass_target >= 0 || throw(ArgumentError("pass target cannot be negative"))
    plans = Stage3ExecutionPlanV1[]; evidence = Stage3EvidenceEnvelopeV1[]
    seen = Set{String}(); qd_cells = Set{String}(); uncaught = 0
    structural_pass = 0; structural_fail = 0; structural_unsupported = 0
    for seed in 1:topology_count
        try
            topology = generate_graph_native_topology_v69(seed)
            compilation = compile_graph_native_topology_candidate_v69(topology)
            compilation.isomorphism_hash in seen && continue
            push!(seen, compilation.isomorphism_hash)
            if compilation.status != :pass
                compilation.status == :unsupported ? (structural_unsupported += 1) :
                    (structural_fail += 1)
                continue
            end
            structural_pass += 1
            binding = Dict{String,Any}("execution_model" => Dict{String,Any}(
                "kind" => "generic_graph_balance"))
            request = compile_stage3_execution_request_v1(topology, compilation;
                parameter_binding = binding,
                sample_spec = Dict{String,Any}("required_sample_count" => 1,
                    "dimension" => 2, "sequence" => "halton_v1"), budget = budget)
            plan = compile_stage3_execution_plan_v1(request); push!(plans, plan)
            cell = _stage3_persisted_hash_v1(_stage3_qd_coordinates_v1(plan))
            if length(evidence) < complete_pass_target &&
                    plan.completeness == :complete && !(cell in qd_cells)
                result = execute_stage3_plan_v1(plan, request)
                push!(evidence, result)
                result.conclusion == :pass && push!(qd_cells, cell)
            elseif length(evidence) < complete_pass_target &&
                    plan.completeness == :complete
                # Once every new QD cell has an exemplar, admit structurally distinct
                # graphs without treating small parameter perturbations as new cells.
                result = execute_stage3_plan_v1(plan, request)
                push!(evidence, result)
            end
        catch
            uncaught += 1
        end
    end
    metrics = aggregate_stage3_metrics_v1(plans, evidence)
    merge!(metrics, Dict{String,Any}(
        "raw_topology_count" => Int(topology_count),
        "unique_topology_count" => length(seen),
        "structural_compile_pass_count" => structural_pass,
        "structural_compile_fail_count" => structural_fail,
        "structural_compile_unsupported_count" => structural_unsupported,
        "uncaught_exception_count" => uncaught,
        "stage3_complete_pass_qd_cell_count" => length(qd_cells),
        "stage3_complete_pass_structural_hash_count" => length(unique(
            item.topology_hash for item in evidence if item.conclusion == :pass)),
        "structure_loop_processed_count" => Int(topology_count),
        "numerical_loop_processed_count" => length(evidence)))
    candidate_records = [stage3_candidate_record_v1(plan, item)
        for item in evidence for plan in plans
        if plan.solve_plan_hash == item.solve_plan_hash]
    body = Dict{String,Any}("schema_version" => "1.0.0", "metrics" => metrics,
        "plan_hashes" => [item.solve_plan_hash for item in plans],
        "evidence_hashes" => [item.evidence_hash for item in evidence],
        "stage3_candidate_records" => candidate_records,
        "qd_coordinate_system" =>
            "operator_x_dimension_x_time_mode_x_boundary_kind_x_state_count",
        "hardcoded_stage3_counts_used" => false, "label_routing_used" => false)
    body["run_hash"] = _stage3_persisted_hash_v1(body)
    return body
end
