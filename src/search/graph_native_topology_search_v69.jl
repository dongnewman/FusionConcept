const GRAPH_V69_PORT_KINDS = Set((:flux, :field_source, :energy_source, :boundary,
    :heat_rejection, :actuator, :sensor, :control))
const GRAPH_V69_DIRECTIONS = Set((:input, :output, :bidirectional))
const GRAPH_V69_CONSERVED_ACCOUNTS = Set(("particle", "ion_energy",
    "electron_energy", "species", "charge"))
const GRAPH_V69_CAPABILITIES = Set(vcat(collect(UNIFIED_PORT_CAPABILITY_IDS_V69), [
    "declared_boundary_flux_v1", "regional_particle_continuity_v1",
    "regional_power_ledger_v1", "conservation_obligation_compiler_v69"]))
const GRAPH_V69_STATE_LIBRARY = (
    ("fuel_a_inventory", "particle"), ("fuel_b_inventory", "particle"),
    ("electron_inventory", "particle"), ("ion_thermal_energy", "J"),
    ("electron_thermal_energy", "J"), ("field_amplitude", "T"),
    ("parallel_momentum", "kg*m/s"), ("radial_flux", "Wb"),
    ("impurity_inventory", "particle"), ("neutral_inventory", "particle"),
    ("wall_temperature", "K"), ("coolant_enthalpy", "J"))
const GRAPH_V69_RESOURCE_UNITS = Dict(
    "particle" => "particle/s", "ion_energy" => "W",
    "electron_energy" => "W", "species" => "particle/s",
    "charge" => "C/s", "field_state" => "T", "thermal_energy" => "W",
    "actuator_command" => "1", "state_vector" => "1")

struct GraphNativeTopologyV69
    schema_version::String
    regions::Vector{Dict{String,Any}}
    interfaces::Vector{Dict{String,Any}}
    ports::Vector{Dict{String,Any}}
    dependencies::Vector{Dict{String,Any}}
    symmetry::String
    obligations::Vector{Dict{String,Any}}
    topology_hash::String
end

struct GraphTopologyCompilationV69
    schema_version::String
    topology_hash::String
    normalized_hash::String
    isomorphism_hash::String
    status::Symbol
    classification_code::String
    checks::Dict{String,Any}
    reasons::Vector{String}
    compilation_hash::String
end

struct GraphTopologyCandidateV69
    topology_hash::String
    isomorphism_hash::String
    compilation_hash::String
    sample_depth::Int
    deepest_gate::Int
    recent_failure_code::String
    evidence_cost_to_next_gate::Float64
    conservation_residual::Union{Nothing,Float64}
    engineering_margin::Union{Nothing,Float64}
    structural_novelty::Float64
    candidate_hash::String
end

mutable struct StructuredQDArchiveV69
    schema_version::String
    cells::Dict{String,Dict{String,Any}}
    scalar_score_used::Bool
end

struct TopologyQueueBundleV69
    schema_version::String
    depth_queue::Vector{Dict{String,Any}}
    exploration_queue::Vector{Dict{String,Any}}
    regression_queue::Vector{Dict{String,Any}}
    terminated_assembly_hashes::Vector{String}
    high_fidelity_feedback_role::String
    queue_hash::String
end

struct GraphNativeSearchResultV69
    schema_version::String
    metrics::Dict{String,Int}
    archive::StructuredQDArchiveV69
    queues::TopologyQueueBundleV69
    search_hash::String
end

function _graph_v69_plain(value)
    value isa AbstractDict && return Dict{String,Any}(String(key) =>
        _graph_v69_plain(child) for (key, child) in pairs(value))
    value isa AbstractVector && return Any[_graph_v69_plain(child) for child in value]
    value isa Tuple && return Any[_graph_v69_plain(child) for child in value]
    return value
end

function _graph_v69_assert_label_free(value, path = "topology")
    if value isa AbstractDict
        for (key_any, child) in pairs(value)
            key = lowercase(String(key_any))
            key in ("family", "device_family", "device_type", "parent_family",
                "mechanism_label") && throw(ArgumentError(
                "label routing field is forbidden at $path.$key"))
            _graph_v69_assert_label_free(child, "$path.$key")
        end
    elseif value isa AbstractVector
        for (index, child) in enumerate(value)
            _graph_v69_assert_label_free(child, "$path[$index]")
        end
    end
    return true
end

function compile_graph_native_topology_v69(; regions, interfaces, ports,
        dependencies, symmetry::AbstractString, obligations)
    data = Dict{String,Any}(
        "regions" => _graph_v69_plain(regions),
        "interfaces" => _graph_v69_plain(interfaces),
        "ports" => _graph_v69_plain(ports),
        "dependencies" => _graph_v69_plain(dependencies),
        "symmetry" => String(symmetry),
        "obligations" => _graph_v69_plain(obligations))
    _graph_v69_assert_label_free(data)
    isempty(symmetry) && throw(ArgumentError("graph topology symmetry is required"))
    body = merge(Dict{String,Any}("schema_version" => "1.0.0"), data)
    return GraphNativeTopologyV69("1.0.0",
        Dict{String,Any}.(data["regions"]),
        Dict{String,Any}.(data["interfaces"]),
        Dict{String,Any}.(data["ports"]),
        Dict{String,Any}.(data["dependencies"]), String(symmetry),
        Dict{String,Any}.(data["obligations"]), canonical_hash(body))
end

function normalize_graph_native_topology_v69(topology::GraphNativeTopologyV69)
    regions = sort!([_graph_v69_plain(item) for item in topology.regions];
        by = item -> String(item["region_id"]))
    for region in regions
        region["state_slots"] = sort!([_graph_v69_plain(item)
            for item in region["state_slots"]]; by = item -> String(item["slot_id"]))
        region["algebraic_slots"] = sort!(unique(String.(region["algebraic_slots"])))
    end
    interfaces = sort!([_graph_v69_plain(item) for item in topology.interfaces];
        by = item -> String(item["interface_id"]))
    for interface in interfaces
        interface["account_ids"] = sort!(unique(String.(interface["account_ids"])))
    end
    ports = sort!([_graph_v69_plain(item) for item in topology.ports];
        by = item -> String(item["port_id"]))
    for port in ports
        port["resource_ids"] = sort!(unique(String.(port["resource_ids"])))
    end
    dependencies = sort!([_graph_v69_plain(item) for item in topology.dependencies];
        by = item -> String(item["dependency_id"]))
    obligations = sort!([_graph_v69_plain(item) for item in topology.obligations];
        by = item -> String(item["obligation_id"]))
    for obligation in obligations
        obligation["required_capability_ids"] = sort!(unique(String.(get(obligation,
            "required_capability_ids", String[]))))
        obligation["required_evidence_field_ids"] = sort!(unique(String.(get(obligation,
            "required_evidence_field_ids", String[]))))
    end
    return compile_graph_native_topology_v69(regions = regions,
        interfaces = interfaces, ports = ports, dependencies = dependencies,
        symmetry = topology.symmetry, obligations = obligations)
end

function _graph_v69_permutations(values::Vector{String})
    isempty(values) && return [String[]]
    result = Vector{Vector{String}}()
    function visit(prefix::Vector{String}, remaining::Vector{String})
        isempty(remaining) && return push!(result, copy(prefix))
        for index in eachindex(remaining)
            push!(prefix, remaining[index])
            visit(prefix, vcat(remaining[1:index-1], remaining[index+1:end]))
            pop!(prefix)
        end
    end
    visit(String[], values)
    return result
end

"Exact graph-isomorphism canonical hash for the bounded (at most six-region) grammar."
function graph_isomorphism_hash_v69(topology::GraphNativeTopologyV69)
    normalized = normalize_graph_native_topology_v69(topology)
    region_ids = String[String(item["region_id"]) for item in normalized.regions]
    length(region_ids) <= 6 || throw(ArgumentError(
        "exact graph isomorphism canonicalization supports at most six regions"))
    candidates = String[]
    for permutation in _graph_v69_permutations(region_ids)
        mapping = Dict(permutation[index] => "n$(index)" for index in eachindex(permutation))
        mapped_regions = [Dict{String,Any}(
            "node" => mapping[String(item["region_id"])],
            "dimension" => String(item["dimension"]),
            "time_mode" => String(item["time_mode"]),
            "boundary_class" => String(item["boundary_class"]),
            "state_slots" => item["state_slots"],
            "algebraic_slots" => item["algebraic_slots"])
            for item in normalized.regions]
        sort!(mapped_regions; by = item -> String(item["node"]))
        port_signature = Dict{String,String}()
        mapped_ports = Dict{String,Any}[]
        for port in normalized.ports
            signature = join((mapping[String(port["region_id"])],
                String(port["port_kind"]), String(port["direction"]),
                join(String.(port["resource_ids"]), "+"),
                String(port["capability_id"]),
                string(Bool(get(port, "exclusive_output", false)))), "|")
            port_signature[String(port["port_id"])] = signature
            push!(mapped_ports, Dict{String,Any}("signature" => signature))
        end
        sort!(mapped_ports; by = item -> String(item["signature"]))
        mapped_interfaces = Dict{String,Any}[]
        for interface in normalized.interfaces
            target = get(interface, "target_region_id", nothing)
            push!(mapped_interfaces, Dict{String,Any}(
                "source" => mapping[String(interface["source_region_id"])],
                "target" => target === nothing ? nothing : mapping[String(target)],
                "account_ids" => interface["account_ids"],
                "capability_id" => String(interface["capability_id"])))
        end
        sort!(mapped_interfaces; by = canonical_hash)
        mapped_dependencies = [Dict{String,Any}(
            "source" => get(port_signature, String(item["source_port_id"]), "missing"),
            "target" => get(port_signature, String(item["target_port_id"]), "missing"),
            "dependency_kind" => String(item["dependency_kind"]),
            "delayed" => Bool(get(item, "delayed", false)))
            for item in normalized.dependencies]
        sort!(mapped_dependencies; by = canonical_hash)
        mapped_obligations = [Dict{String,Any}(
            "obligation_kind" => String(item["obligation_kind"]),
            "required_capability_ids" => item["required_capability_ids"],
            "required_evidence_field_ids" => item["required_evidence_field_ids"])
            for item in normalized.obligations]
        sort!(mapped_obligations; by = canonical_hash)
        push!(candidates, canonical_hash(Dict{String,Any}(
            "regions" => mapped_regions, "interfaces" => mapped_interfaces,
            "ports" => mapped_ports, "dependencies" => mapped_dependencies,
            "symmetry" => normalized.symmetry, "obligations" => mapped_obligations)))
    end
    return minimum(candidates)
end

function _graph_v69_causal_dag(port_ids::Vector{String}, dependencies)
    outgoing = Dict(id => String[] for id in port_ids)
    indegree = Dict(id => 0 for id in port_ids)
    for item in dependencies
        Bool(get(item, "delayed", false)) && continue
        source, target = String(item["source_port_id"]), String(item["target_port_id"])
        haskey(outgoing, source) && haskey(indegree, target) || continue
        push!(outgoing[source], target); indegree[target] += 1
    end
    ready = sort!(String[id for id in port_ids if indegree[id] == 0]); visited = 0
    while !isempty(ready)
        id = popfirst!(ready); visited += 1
        for target in outgoing[id]
            indegree[target] -= 1
            indegree[target] == 0 && push!(ready, target)
        end
    end
    return visited == length(port_ids)
end

"Run the seven mandatory post-mutation checks before a numerical candidate exists."
function compile_graph_native_topology_candidate_v69(topology::GraphNativeTopologyV69;
        capability_registry::Set{String} = copy(GRAPH_V69_CAPABILITIES))
    normalized = normalize_graph_native_topology_v69(topology)
    iso_hash = graph_isomorphism_hash_v69(normalized)
    fail = String[]; unsupported = String[]
    region_ids = String[String(item["region_id"]) for item in normalized.regions]
    isempty(region_ids) && push!(fail, "no_regions")
    length(unique(region_ids)) == length(region_ids) || push!(fail, "duplicate_region_id")
    for region in normalized.regions
        String(region["dimension"]) in ("0d", "1d", "2d", "3d") ||
            push!(fail, "invalid_dimension:$(region["region_id"])")
        String(region["time_mode"]) in ("steady", "transient", "dae") ||
            push!(fail, "invalid_time_mode:$(region["region_id"])")
        for slot_any in region["state_slots"]
            slot = Dict{String,Any}(String(key) => value for (key, value) in pairs(slot_any))
            isempty(String(get(slot, "slot_id", ""))) && push!(fail, "empty_state_slot")
            isempty(String(get(slot, "unit", ""))) && push!(fail,
                "missing_state_slot_unit:$(get(slot, "slot_id", ""))")
        end
    end
    port_ids = String[String(item["port_id"]) for item in normalized.ports]
    length(unique(port_ids)) == length(port_ids) || push!(fail, "duplicate_port_id")
    port_by_id = Dict(String(item["port_id"]) => item for item in normalized.ports)
    exclusive = Dict{Tuple{String,String,String},Int}()
    required_kinds = Set(String.(collect(GRAPH_V69_PORT_KINDS)))
    actual_kinds = Set{String}()
    for port in normalized.ports
        id = String(port["port_id"]); region = String(port["region_id"])
        kind = String(port["port_kind"]); direction = String(port["direction"])
        push!(actual_kinds, kind)
        region in region_ids || push!(fail, "port_region_missing:$id")
        Symbol(kind) in GRAPH_V69_PORT_KINDS || push!(fail, "invalid_port_kind:$id")
        Symbol(direction) in GRAPH_V69_DIRECTIONS || push!(fail, "invalid_port_direction:$id")
        for resource in String.(port["resource_ids"])
            haskey(GRAPH_V69_RESOURCE_UNITS, resource) || push!(fail,
                "unknown_resource_unit:$id:$resource")
            if Bool(get(port, "exclusive_output", false))
                key = (region, kind, resource); exclusive[key] = get(exclusive, key, 0) + 1
            end
        end
        capability = String(port["capability_id"])
        capability in capability_registry || push!(unsupported,
            "missing_capability:$capability")
    end
    isempty(setdiff(required_kinds, actual_kinds)) || push!(fail,
        "required_port_kinds_missing")
    for region_id in region_ids
        region_kinds = Set(String(item["port_kind"]) for item in normalized.ports
            if String(item["region_id"]) == region_id)
        isempty(setdiff(required_kinds, region_kinds)) || push!(fail,
            "required_region_port_kinds_missing:$region_id")
    end
    for (key, count) in exclusive
        count <= 1 || push!(fail, "exclusive_output_conflict:$(join(key, ':'))")
    end
    for dependency in normalized.dependencies
        id = String(dependency["dependency_id"])
        source, target = String(dependency["source_port_id"]),
            String(dependency["target_port_id"])
        haskey(port_by_id, source) || push!(fail, "dependency_source_missing:$id")
        haskey(port_by_id, target) || push!(fail, "dependency_target_missing:$id")
        if haskey(port_by_id, source) && String(port_by_id[source]["direction"]) == "input"
            push!(fail, "dependency_source_input_only:$id")
        end
        if haskey(port_by_id, target) && String(port_by_id[target]["direction"]) == "output"
            push!(fail, "dependency_target_output_only:$id")
        end
        if haskey(port_by_id, source) && haskey(port_by_id, target)
            source_resources = Set(String.(port_by_id[source]["resource_ids"]))
            target_resources = Set(String.(port_by_id[target]["resource_ids"]))
            isempty(intersect(source_resources, target_resources)) && push!(fail,
                "dependency_resource_mismatch:$id")
        end
    end
    causal_dag = _graph_v69_causal_dag(port_ids, normalized.dependencies)
    causal_dag || push!(fail, "undeclared_immediate_causal_loop")
    interface_ids = String[]
    for interface in normalized.interfaces
        id = String(interface["interface_id"]); push!(interface_ids, id)
        source = String(interface["source_region_id"])
        target = get(interface, "target_region_id", nothing)
        source in region_ids || push!(fail, "interface_source_missing:$id")
        target === nothing || String(target) in region_ids || push!(fail,
            "interface_target_missing:$id")
        accounts = Set(String.(interface["account_ids"]))
        isempty(accounts) && push!(fail, "interface_accounts_empty:$id")
        isempty(setdiff(accounts, GRAPH_V69_CONSERVED_ACCOUNTS)) || push!(fail,
            "interface_unknown_conserved_account:$id")
        String(interface["capability_id"]) in capability_registry || push!(unsupported,
            "missing_capability:$(interface["capability_id"])")
    end
    length(unique(interface_ids)) == length(interface_ids) || push!(fail,
        "duplicate_interface_id")
    obligation_kinds = Set{String}()
    conservation_accounts = Set{String}()
    for obligation in normalized.obligations
        kind = String(obligation["obligation_kind"]); push!(obligation_kinds, kind)
        kind == "conservation" && union!(conservation_accounts,
            String.(get(obligation, "account_ids", String[])))
        for capability in String.(obligation["required_capability_ids"])
            capability in capability_registry || push!(unsupported,
                "missing_capability:$capability")
        end
    end
    required_obligations = Set(("conservation", "causal", "validity", "boundary", "evidence"))
    isempty(setdiff(required_obligations, obligation_kinds)) || push!(fail,
        "required_obligation_kinds_missing")
    interface_accounts = Set(String(account) for item in normalized.interfaces
        for account in item["account_ids"])
    isempty(setdiff(interface_accounts, conservation_accounts)) || push!(fail,
        "conservation_obligation_incomplete")
    fail = sort!(unique(fail)); unsupported = sort!(unique(unsupported))
    status = !isempty(fail) ? :fail : !isempty(unsupported) ? :unsupported : :pass
    code = status == :pass ? "pass_graph_native_compile_v69" : status == :unsupported ?
        "unsupported_graph_capability_v69" : first(fail)
    checks = Dict{String,Any}(
        "normalization" => "pass",
        "graph_isomorphism_hash" => iso_hash,
        "unit_and_port_check" => any(contains(reason, "unit") || contains(reason, "port")
            for reason in fail) ? "fail" : "pass",
        "causal_loop_check" => causal_dag ? "pass" : "fail",
        "exclusive_output_conflict_check" => any(contains(reason,
            "exclusive_output_conflict") for reason in fail) ? "fail" : "pass",
        "conservation_obligation_compilation" => any(contains(reason,
            "conservation_obligation") for reason in fail) ? "fail" : "pass",
        "capability_availability" => isempty(unsupported) ? "pass" : "unsupported",
        "label_routing_used" => false)
    reasons = vcat(fail, unsupported)
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "topology_hash" => topology.topology_hash,
        "normalized_hash" => normalized.topology_hash,
        "isomorphism_hash" => iso_hash, "status" => String(status),
        "classification_code" => code, "checks" => checks, "reasons" => reasons)
    return GraphTopologyCompilationV69("1.0.0", topology.topology_hash,
        normalized.topology_hash, iso_hash, status, code, checks, reasons,
        canonical_hash(body))
end

function _graph_v69_port(region, kind, direction, resources, capability;
        suffix = "", exclusive = false)
    id = "$(region)_$(kind)$(suffix)"
    return Dict{String,Any}("port_id" => id, "region_id" => region,
        "port_kind" => String(kind), "direction" => String(direction),
        "resource_ids" => collect(resources), "capability_id" => capability,
        "exclusive_output" => exclusive)
end

"Generate structural genes only: regions, slots, boundaries, ports and obligations."
function generate_graph_native_topology_v69(seed::Integer)
    rng = MersenneTwister(seed)
    region_count = rand(rng, 1:4)
    dimensions = ("0d", "1d", "2d", "3d")
    time_modes = ("steady", "transient", "dae")
    boundaries = ("closed", "open", "mixed")
    regions = Dict{String,Any}[]
    for index in 1:region_count
        required = collect(GRAPH_V69_STATE_LIBRARY[1:5])
        optional = [item for item in GRAPH_V69_STATE_LIBRARY[6:end] if rand(rng, Bool)]
        slots = [Dict{String,Any}("slot_id" => id, "unit" => unit)
            for (id, unit) in vcat(required, optional)]
        algebraic_count = rand(rng, 1:4)
        push!(regions, Dict{String,Any}(
            "region_id" => "r$index", "state_slots" => slots,
            "algebraic_slots" => ["constraint_$(index)_$j" for j in 1:algebraic_count],
            "dimension" => rand(rng, dimensions), "time_mode" => rand(rng, time_modes),
            "boundary_class" => rand(rng, boundaries)))
    end
    interfaces = Dict{String,Any}[]
    accounts_library = collect(GRAPH_V69_CONSERVED_ACCOUNTS)
    for index in 1:max(region_count - 1, 0)
        accounts = sort!(String[item for item in accounts_library if rand(rng, Bool)])
        isempty(accounts) && push!(accounts, "particle")
        push!(interfaces, Dict{String,Any}("interface_id" => "internal_$index",
            "source_region_id" => "r$index", "target_region_id" => "r$(index + 1)",
            "account_ids" => accounts, "capability_id" => "declared_boundary_flux_v1"))
    end
    for index in 1:region_count
        rand(rng) < 0.7 || continue
        accounts = sort!(String[item for item in accounts_library if rand(rng, Bool)])
        isempty(accounts) && push!(accounts, "electron_energy")
        push!(interfaces, Dict{String,Any}("interface_id" => "external_$index",
            "source_region_id" => "r$index", "target_region_id" => nothing,
            "account_ids" => accounts, "capability_id" => "declared_boundary_flux_v1"))
    end
    isempty(interfaces) && push!(interfaces, Dict{String,Any}(
        "interface_id" => "external_1", "source_region_id" => "r1",
        "target_region_id" => nothing, "account_ids" => ["particle", "electron_energy"],
        "capability_id" => "declared_boundary_flux_v1"))
    ports = Dict{String,Any}[]; dependencies = Dict{String,Any}[]
    for index in 1:region_count
        region = "r$index"
        append!(ports, [
            _graph_v69_port(region, :flux, :bidirectional,
                ("particle", "ion_energy", "electron_energy", "species", "charge"),
                "declared_boundary_flux_v1"),
            _graph_v69_port(region, :field_source, :output, ("field_state",),
                "field_source_port_v2"; exclusive = true),
            _graph_v69_port(region, :energy_source, :output, ("thermal_energy",),
                "energy_source_port_v2"),
            _graph_v69_port(region, :boundary, :bidirectional,
                ("particle", "ion_energy", "electron_energy", "species", "field_state"),
                "declared_boundary_flux_v1"),
            _graph_v69_port(region, :heat_rejection, :input, ("thermal_energy",),
                "heat_rejection_port_v2"),
            _graph_v69_port(region, :actuator, :input, ("actuator_command",),
                "actuator_port_v2"),
            _graph_v69_port(region, :sensor, :output, ("state_vector",),
                "sensor_port_v2")])
        control_depth = rand(rng, 1:3)
        for level in 1:control_depth
            push!(ports, _graph_v69_port(region, :control, :bidirectional,
                ("state_vector", "actuator_command"), "control_port_v2";
                suffix = "_$level"))
        end
        edge(id, source, target, kind; delayed = false) = Dict{String,Any}(
            "dependency_id" => "$(region)_$id", "source_port_id" => source,
            "target_port_id" => target, "dependency_kind" => kind, "delayed" => delayed)
        append!(dependencies, [
            edge("field_boundary", "$(region)_field_source", "$(region)_boundary", "field"),
            edge("energy_heat", "$(region)_energy_source", "$(region)_heat_rejection", "energy"),
            edge("sensor_control", "$(region)_sensor", "$(region)_control_1", "data")])
        for level in 1:control_depth-1
            push!(dependencies, edge("control_$(level)_$(level+1)",
                "$(region)_control_$level", "$(region)_control_$(level+1)", "control"))
        end
        push!(dependencies, edge("control_actuator", "$(region)_control_$control_depth",
            "$(region)_actuator", "control"))
    end
    obligations = Dict{String,Any}[
        Dict("obligation_id" => "conservation", "obligation_kind" => "conservation",
            "account_ids" => sort!(collect(GRAPH_V69_CONSERVED_ACCOUNTS)),
            "required_capability_ids" => ["regional_particle_continuity_v1",
                "regional_power_ledger_v1", "conservation_obligation_compiler_v69"],
            "required_evidence_field_ids" => ["conservation", "interface_flux"]),
        Dict("obligation_id" => "causal", "obligation_kind" => "causal",
            "required_capability_ids" => ["sensor_port_v2", "control_port_v2",
                "actuator_port_v2"], "required_evidence_field_ids" => ["actuator_fulfillment"]),
        Dict("obligation_id" => "validity", "obligation_kind" => "validity",
            "required_capability_ids" => String[],
            "required_evidence_field_ids" => ["validity_domain", "physical_bounds"]),
        Dict("obligation_id" => "boundary", "obligation_kind" => "boundary",
            "required_capability_ids" => ["declared_boundary_flux_v1"],
            "required_evidence_field_ids" => ["interface_flux"]),
        Dict("obligation_id" => "evidence", "obligation_kind" => "evidence",
            "required_capability_ids" => String[],
            "required_evidence_field_ids" => ["resolution_trend", "independent_residual_audit"])]
    topology = compile_graph_native_topology_v69(regions = regions,
        interfaces = interfaces, ports = ports, dependencies = dependencies,
        symmetry = rand(rng, ("none", "reflection", "rotational", "helical")),
        obligations = obligations)
    # Deterministic negative controls exercise fail-closed post-mutation checks.
    if seed % 29 == 0
        mutated_ports = deepcopy(topology.ports)
        mutated_ports[1]["capability_id"] = "unavailable_flux_capability_v69"
        topology = compile_graph_native_topology_v69(regions = topology.regions,
            interfaces = topology.interfaces, ports = mutated_ports,
            dependencies = topology.dependencies, symmetry = topology.symmetry,
            obligations = topology.obligations)
    elseif seed % 31 == 0
        mutated_dependencies = deepcopy(topology.dependencies)
        push!(mutated_dependencies, Dict{String,Any}("dependency_id" => "negative_cycle",
            "source_port_id" => "r1_control_1", "target_port_id" => "r1_control_1",
            "dependency_kind" => "control", "delayed" => false))
        topology = compile_graph_native_topology_v69(regions = topology.regions,
            interfaces = topology.interfaces, ports = topology.ports,
            dependencies = mutated_dependencies, symmetry = topology.symmetry,
            obligations = topology.obligations)
    elseif seed % 37 == 0
        mutated_ports = deepcopy(topology.ports)
        duplicate = deepcopy(only(filter(item -> item["port_id"] == "r1_field_source",
            mutated_ports)))
        duplicate["port_id"] = "r1_field_source_competing"
        push!(mutated_ports, duplicate)
        topology = compile_graph_native_topology_v69(regions = topology.regions,
            interfaces = topology.interfaces, ports = mutated_ports,
            dependencies = topology.dependencies, symmetry = topology.symmetry,
            obligations = topology.obligations)
    end
    return topology
end

"Every mutation returns its normalized, deduplicable and fully checked compilation."
function mutate_graph_native_topology_v69(topology::GraphNativeTopologyV69,
        mutation::AbstractDict)
    data = Dict{String,Any}(String(key) => _graph_v69_plain(value)
        for (key, value) in pairs(mutation))
    _graph_v69_assert_label_free(data, "mutation")
    kind = Symbol(String(data["mutation_kind"]))
    regions, interfaces, ports = deepcopy(topology.regions), deepcopy(topology.interfaces),
        deepcopy(topology.ports)
    dependencies, symmetry = deepcopy(topology.dependencies), topology.symmetry
    if kind == :set_symmetry
        symmetry = String(data["symmetry"])
    elseif kind == :set_boundary
        id = String(data["region_id"])
        for region in regions
            String(region["region_id"]) == id && (region["boundary_class"] =
                String(data["boundary_class"]))
        end
    elseif kind == :replace_capability
        id = String(data["port_id"])
        for port in ports
            String(port["port_id"]) == id && (port["capability_id"] =
                String(data["capability_id"]))
        end
    elseif kind == :remove_port
        id = String(data["port_id"])
        filter!(item -> String(item["port_id"]) != id, ports)
        filter!(item -> String(item["source_port_id"]) != id &&
            String(item["target_port_id"]) != id, dependencies)
    elseif kind == :reconnect_interface
        id = String(data["interface_id"])
        for interface in interfaces
            String(interface["interface_id"]) == id || continue
            interface["source_region_id"] = String(data["source_region_id"])
            interface["target_region_id"] = get(data, "target_region_id", nothing)
        end
    elseif kind == :set_state_slots
        id = String(data["region_id"])
        for region in regions
            String(region["region_id"]) == id &&
                (region["state_slots"] = _graph_v69_plain(data["state_slots"]))
        end
    else
        throw(ArgumentError("unsupported graph-native mutation: $kind"))
    end
    mutated = compile_graph_native_topology_v69(regions = regions,
        interfaces = interfaces, ports = ports, dependencies = dependencies,
        symmetry = symmetry, obligations = topology.obligations)
    return normalize_graph_native_topology_v69(mutated),
        compile_graph_native_topology_candidate_v69(mutated)
end

function adaptive_state_sampling_depth_v69(compilation_status::Symbol,
        stage3_status::Symbol, proximity_to_next_gate::Real)
    compilation_status == :pass || return 0
    stage3_status == :fail && return 1
    stage3_status == :pass && return 64
    proximity = Float64(proximity_to_next_gate)
    isfinite(proximity) && 0.0 <= proximity <= 1.0 || throw(ArgumentError(
        "gate proximity must be finite and in [0,1]"))
    proximity < 0.5 && return 1
    proximity < 0.75 && return 4
    proximity < 0.9 && return 16
    return 64
end

StructuredQDArchiveV69() = StructuredQDArchiveV69("1.0.0",
    Dict{String,Dict{String,Any}}(), false)

function _graph_v69_coordinates(topology::GraphNativeTopologyV69,
        candidate::GraphTopologyCandidateV69)
    internal = count(item -> get(item, "target_region_id", nothing) !== nothing,
        topology.interfaces)
    open = length(topology.interfaces) - internal
    state_count = sum(length(item["state_slots"]) for item in topology.regions)
    algebraic_count = sum(length(item["algebraic_slots"]) for item in topology.regions)
    field_count = count(item -> String(item["port_kind"]) == "field_source", topology.ports)
    actuator_count = count(item -> String(item["port_kind"]) == "actuator", topology.ports)
    control_depth = maximum(count(port -> String(port["region_id"]) ==
        String(region["region_id"]) && String(port["port_kind"]) == "control",
        topology.ports) for region in topology.regions)
    dimensions = sort!(unique(String(item["dimension"]) for item in topology.regions))
    modes = sort!(unique(String(item["time_mode"]) for item in topology.regions))
    return Dict{String,Any}("region_count" => length(topology.regions),
        "internal_interface_count" => internal, "open_boundary_count" => open,
        "state_slot_count" => state_count, "algebraic_slot_count" => algebraic_count,
        "field_source_port_count" => field_count,
        "actuator_degrees_of_freedom" => actuator_count,
        "control_feedback_depth" => control_depth, "dimensions" => dimensions,
        "symmetry" => topology.symmetry, "time_modes" => modes,
        "deepest_gate" => candidate.deepest_gate,
        "recent_narrow_failure_code" => candidate.recent_failure_code)
end

function insert_structured_qd_v69!(archive::StructuredQDArchiveV69,
        topology::GraphNativeTopologyV69, candidate::GraphTopologyCandidateV69)
    coordinates = _graph_v69_coordinates(topology, candidate)
    cell_id = canonical_hash(coordinates)
    cell = get!(archive.cells, cell_id, Dict{String,Any}(
        "coordinates" => coordinates, "lowest_evidence_cost" => nothing,
        "smallest_conservation_residual" => nothing,
        "largest_engineering_margin" => nothing,
        "highest_structural_novelty" => nothing))
    record = Dict{String,Any}("candidate_hash" => candidate.candidate_hash,
        "topology_hash" => candidate.topology_hash,
        "isomorphism_hash" => candidate.isomorphism_hash,
        "evidence_cost_to_next_gate" => candidate.evidence_cost_to_next_gate,
        "conservation_residual" => candidate.conservation_residual,
        "engineering_margin" => candidate.engineering_margin,
        "structural_novelty" => candidate.structural_novelty)
    current = cell["lowest_evidence_cost"]
    (current === nothing || candidate.evidence_cost_to_next_gate <
        Float64(current["evidence_cost_to_next_gate"])) &&
        (cell["lowest_evidence_cost"] = record)
    if candidate.conservation_residual !== nothing
        current = cell["smallest_conservation_residual"]
        (current === nothing || candidate.conservation_residual <
            Float64(current["conservation_residual"])) &&
            (cell["smallest_conservation_residual"] = record)
    end
    if candidate.engineering_margin !== nothing
        current = cell["largest_engineering_margin"]
        (current === nothing || candidate.engineering_margin >
            Float64(current["engineering_margin"])) &&
            (cell["largest_engineering_margin"] = record)
    end
    current = cell["highest_structural_novelty"]
    (current === nothing || candidate.structural_novelty >
        Float64(current["structural_novelty"])) &&
        (cell["highest_structural_novelty"] = record)
    return cell_id
end

function build_topology_queues_v69(candidates::Vector{GraphTopologyCandidateV69};
        terminated_assembly_hashes::Vector{String} = String[],
        regression_records::Vector{Dict{String,Any}} = Dict{String,Any}[])
    depth = sort!(copy(candidates); by = item ->
        (item.evidence_cost_to_next_gate, -item.deepest_gate, item.candidate_hash))
    exploration = sort!(copy(candidates); by = item ->
        (-item.structural_novelty, item.evidence_cost_to_next_gate, item.candidate_hash))
    pack(item) = Dict{String,Any}("candidate_hash" => item.candidate_hash,
        "topology_hash" => item.topology_hash, "deepest_gate" => item.deepest_gate,
        "evidence_cost_to_next_gate" => item.evidence_cost_to_next_gate,
        "structural_novelty" => item.structural_novelty,
        "feasibility_credit_from_high_fidelity_feedback" => false)
    depth_records = [pack(item) for item in first(depth, min(4, length(depth)))]
    exploration_records = [pack(item) for item in first(exploration,
        min(16, length(exploration)))]
    regression = sort!([_graph_v69_plain(item) for item in regression_records];
        by = item -> String(get(item, "candidate_id", get(item, "candidate_hash", ""))))
    terminated = _v69_sorted_hashes(terminated_assembly_hashes,
        "terminated assembly hash")
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "depth_queue" => depth_records, "exploration_queue" => exploration_records,
        "regression_queue" => regression, "terminated_assembly_hashes" => terminated,
        "high_fidelity_feedback_role" => "next_evidence_selection_only",
        "scalar_score_used" => false)
    return TopologyQueueBundleV69("1.0.0", depth_records, exploration_records,
        regression, terminated, "next_evidence_selection_only", canonical_hash(body))
end

function legacy_candidate_cost_priorities_v69()
    records = Dict{String,Any}[
        Dict("candidate_id" => "closed_candidate_pool24", "stage3_missing" => 55,
            "stage4_missing" => 11),
        Dict("candidate_id" => "closed_candidate_pool56", "stage3_missing" => 55,
            "stage4_missing" => 11),
        Dict("candidate_id" => "open_candidate_mirror_high_ratio", "stage3_missing" => 56,
            "stage4_missing" => 26),
        Dict("candidate_id" => "open_candidate_mirror_low_force", "stage3_missing" => 56,
            "stage4_missing" => 26)]
    for item in records
        item["evidence_cost_to_next_gate"] = item["stage3_missing"] + item["stage4_missing"]
        item["priority_basis"] = "cost_to_next_gate_only"
        item["label_routing_used"] = false
    end
    return sort!(records; by = item ->
        (Int(item["evidence_cost_to_next_gate"]), String(item["candidate_id"])))
end

function run_graph_native_topology_search_v69(raw_structure_count::Integer;
        terminated_assembly_hashes::Vector{String} = String[],
        regression_records::Vector{Dict{String,Any}} = Dict{String,Any}[])
    raw_structure_count > 0 || throw(ArgumentError("raw structure count must be positive"))
    seen = Set{String}(); archive = StructuredQDArchiveV69()
    queue_candidates = GraphTopologyCandidateV69[]
    compile_pass = 0; compile_fail = 0; compile_unsupported = 0
    for seed in 1:raw_structure_count
        topology = generate_graph_native_topology_v69(seed)
        compilation = compile_graph_native_topology_candidate_v69(topology)
        if compilation.isomorphism_hash in seen
            continue
        end
        push!(seen, compilation.isomorphism_hash)
        if compilation.status == :pass
            compile_pass += 1
            state_slots = sum(length(item["state_slots"]) for item in topology.regions)
            evidence_cost = Float64(state_slots + 2length(topology.interfaces) +
                length(topology.obligations))
            novelty = Float64(length(topology.regions) + length(topology.interfaces) +
                length(unique(String(item["dimension"]) for item in topology.regions)) +
                length(unique(String(item["time_mode"]) for item in topology.regions)))
            body = Dict{String,Any}("topology_hash" => topology.topology_hash,
                "isomorphism_hash" => compilation.isomorphism_hash,
                "compilation_hash" => compilation.compilation_hash,
                "sample_depth" => 1, "deepest_gate" => 2,
                "recent_failure_code" => "missing_candidate_bound_stage3_evidence",
                "evidence_cost_to_next_gate" => evidence_cost,
                "structural_novelty" => novelty)
            candidate = GraphTopologyCandidateV69(topology.topology_hash,
                compilation.isomorphism_hash, compilation.compilation_hash, 1, 2,
                "missing_candidate_bound_stage3_evidence", evidence_cost, nothing,
                nothing, novelty, canonical_hash(body))
            insert_structured_qd_v69!(archive, topology, candidate)
            push!(queue_candidates, candidate)
            if length(queue_candidates) > 256
                depth = sort!(copy(queue_candidates); by = item ->
                    (item.evidence_cost_to_next_gate, item.candidate_hash))[1:64]
                explore = sort!(copy(queue_candidates); by = item ->
                    (-item.structural_novelty, item.candidate_hash))[1:64]
                queue_by_hash = Dict(item.candidate_hash => item
                    for item in vcat(depth, explore))
                queue_candidates = collect(values(queue_by_hash))
            end
        elseif compilation.status == :unsupported
            compile_unsupported += 1
        else
            compile_fail += 1
        end
    end
    queues = build_topology_queues_v69(queue_candidates;
        terminated_assembly_hashes = terminated_assembly_hashes,
        regression_records = regression_records)
    metrics = Dict{String,Int}(
        "raw_topology_count" => Int(raw_structure_count),
        "unique_topology_count" => length(seen),
        "unique_topology_compile_pass_count" => compile_pass,
        "topology_compile_fail_count" => compile_fail,
        "topology_compile_unsupported_count" => compile_unsupported,
        "stage3_complete_count" => 0,
        "stage4_complete_count" => 0,
        "engineering_complete_count" => 0,
        "complete_c2_count" => 0,
        "complete_c2_pass_count" => 0)
    body = Dict{String,Any}("schema_version" => "1.0.0", "metrics" => metrics,
        "qd_cell_count" => length(archive.cells), "queue_hash" => queues.queue_hash,
        "scalar_score_used" => false, "label_routing_used" => false)
    return GraphNativeSearchResultV69("1.0.0", metrics, archive, queues,
        canonical_hash(body))
end

function graph_native_search_result_to_dict_v69(item::GraphNativeSearchResultV69)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "metrics" => item.metrics, "qd_archive" => Dict{String,Any}(
            "cell_count" => length(item.archive.cells), "cells" => item.archive.cells,
            "scalar_score_used" => item.archive.scalar_score_used),
        "queues" => Dict{String,Any}("depth_queue" => item.queues.depth_queue,
            "exploration_queue" => item.queues.exploration_queue,
            "regression_queue" => item.queues.regression_queue,
            "terminated_assembly_hashes" => item.queues.terminated_assembly_hashes,
            "high_fidelity_feedback_role" => item.queues.high_fidelity_feedback_role,
            "queue_hash" => item.queues.queue_hash),
        "search_hash" => item.search_hash)
end
