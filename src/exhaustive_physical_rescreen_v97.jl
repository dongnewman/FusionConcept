const V97_PROTOCOL_ID = "fusionconceptai-v97-exhaustive-physical-rescreen-20260829"
const V97_MAXIMUM_REQUEST_INDEX = 1_048_576
const V97_SEALED_REQUEST_COUNT = 1_000_000
const V97_SCREEN_STATUSES = Set([
    "closed", "unsupported", "physical_fail", "numerical_fail", "unknown"])

const EXHAUSTIVE_PHYSICAL_RESCREEN_V97_CLAIM_BOUNDARY =
    "v97 deterministically reconstructs every indexed v91 typed topology, materializes " *
    "candidate-bound physical design parameters, compiles the v96 reduced physical graph, " *
    "plans field dependencies, routes every provider obligation, deduplicates exact graph and " *
    "solver inputs, and executes the strict v96 solve/VVUQ chain only for unique closed inputs. " *
    "It does not reuse historical basis-derived gate metrics and does not establish experimental " *
    "validation, engineering readiness, or device feasibility."

const V97_FIELD_CLASSES = Set([
    "recovered", "derived", "computable", "external_evidence", "unsupported"])

const V97_SLOT_TO_STATE = Dict(
    "particle_inventory" => "density",
    "thermal_energy" => "pressure",
    "field_amplitude" => "magnetic_field",
    "actuator_state" => "actuator_state",
)

_v97_dimension(value) = String(value) == "0d" ? 0 : String(value) == "1d" ? 1 :
    String(value) == "2d" ? 2 : String(value) == "3d" ? 3 : -1

function _v97_region_type(role)
    value = String(role)
    value == "root_control_volume" && return "control"
    value == "terminal_balance_region" && return "terminal"
    value == "field_evolution" && return "vacuum"
    value in ("plasma_inventory", "energy_exchange", "particle_transport") &&
        return "plasma"
    "unsupported"
end

function _v97_boundary_condition(value)
    boundary = String(value)
    boundary == "closed" && return "closed_no_flux"
    boundary == "open" && return "open_outflow"
    boundary == "mixed" && return "mixed_robin"
    boundary == "absorbing" && return "absorbing_terminal"
    boundary == "periodic" && return "periodic_identification"
    "unsupported_boundary"
end

function _v97_design_parameters(index::Integer, topology)
    coordinates = _v91_basis(index)
    nodes = Dict{String,Any}.(topology["nodes"])
    variable_nodes = [node for node in nodes if String(node["role"]) in V91_NODE_ROLES]
    spatial_fraction = count(node -> _v97_dimension(node["dimension"]) >= 2,
        variable_nodes) / max(length(variable_nodes), 1)
    open_fraction = count(node -> String(node["boundary"]) == "open" ||
        String(node["field_semantics"]) == "open_guiding_field", variable_nodes) /
        max(length(variable_nodes), 1)
    field_fraction = count(node -> String(node["role"]) == "field_evolution" ||
        String(node["operator"]) == "field_balance", variable_nodes) /
        max(length(variable_nodes), 1)
    operator_diversity = length(unique(String(node["operator"]) for node in
        variable_nodes)) / length(V91_OPERATORS)
    major = (2.5 + 3.5coordinates[1]) * (0.9 + 0.2spatial_fraction)
    minor = (0.30 + 0.65coordinates[2]) * (0.9 + 0.15field_fraction)
    parameters = Dict{String,Any}(
        "major_radius_m" => major,
        "minor_radius_m" => minor,
        "elongation" => (0.85 + 0.75coordinates[3]) *
            (0.95 + 0.1operator_diversity),
        "triangularity" => 0.45 * (coordinates[4] - 0.5),
        "field_periods" => 1 + floor(Int, 5coordinates[5]),
        "reference_field_t" => (1.0 + 5.0coordinates[6]) *
            (0.9 + 0.2field_fraction),
        "reference_density_m3" => (0.5e19 + 4.5e19coordinates[7]) *
            (0.9 + 0.2spatial_fraction),
        "reference_temperature_ev" => (1.0e3 + 24.0e3coordinates[8]) *
            (0.9 + 0.2operator_diversity),
        "wall_minor_radius_m" => 1.45minor,
        "coil_minor_radius_m" => 1.85minor,
        "open_branch_length_m" => 3.0major * (1.0 + 0.2open_fraction),
        "input_power_w" => 0.0,
        "topology_spatial_fraction" => spatial_fraction,
        "topology_open_fraction" => open_fraction,
        "topology_field_fraction" => field_fraction,
        "topology_operator_diversity" => operator_diversity,
        "design_coordinate_source" =>
            "deterministic_index_design_vector_plus_declared_topology_semantics",
        "historical_gate_metric_consumed" => false,
    )
    parameters["physical_parameter_hash"] = canonical_hash(parameters)
    parameters
end

function _v97_state_scale(state, parameters)
    name = String(state)
    name == "density" && return Float64(parameters["reference_density_m3"])
    name == "pressure" && return Float64(parameters["reference_density_m3"]) *
        Float64(parameters["reference_temperature_ev"]) * 1.602176634e-19
    name == "magnetic_field" && return Float64(parameters["reference_field_t"])
    1.0
end

function _v97_declaration_blockers(nodes)
    variable_nodes = [node for node in nodes if String(node["role"]) in V91_NODE_ROLES]
    spatial = [node for node in variable_nodes if _v97_dimension(node["dimension"]) >= 2]
    plasma = [node for node in spatial if String(node["role"]) in
        ("plasma_inventory", "energy_exchange", "particle_transport") ||
        String(node["operator"]) in ("particle_balance", "energy_balance",
            "reaction_radiation", "parallel_transport", "cross_field_transport")]
    field = [node for node in spatial if String(node["role"]) == "field_evolution" ||
        String(node["operator"]) == "field_balance"]
    blockers = String[]
    isempty(plasma) && push!(blockers, "missing_spatial_plasma_operator_backbone")
    isempty(field) && push!(blockers, "missing_spatial_field_balance_backbone")
    any(node -> _v97_dimension(node["dimension"]) < 0, nodes) &&
        push!(blockers, "unsupported_dimension")
    any(node -> _v97_region_type(node["role"]) == "unsupported", nodes) &&
        push!(blockers, "unsupported_region_role")
    sort!(unique(blockers))
end

"""Reconstruct one candidate-bound physical declaration from only the v91 index.

The deterministic design vector is used as geometry/source/profile input. Historical v91
gate values and survivor flags are neither loaded nor accepted by this function.
"""
function reconstruct_indexed_physics_v97(index::Integer; relabel_nonce::Integer = 0)
    1 <= index <= V97_MAXIMUM_REQUEST_INDEX || throw(ArgumentError(
        "v97 request index is outside the complete 20-bit grammar"))
    topology = generate_family_neutral_topology_v91(index; relabel_nonce)
    order, edge_by_pair = _v91_path_order(topology)
    lookup = Dict(String(node["node_id"]) => Dict{String,Any}(node)
        for node in topology["nodes"])
    parameters = _v97_design_parameters(index, topology)
    regions = Dict{String,Any}[]
    states = Dict{String,Any}[]
    boundaries = Dict{String,Any}[]
    canonical_region = Dict{String,String}()
    for (position, node_id) in enumerate(order)
        node = lookup[node_id]
        region_key = "region-" * lpad(position, 2, '0')
        canonical_region[node_id] = region_key
        dimension = _v97_dimension(node["dimension"])
        raw_coordinate = String(node["field_semantics"])
        region_type = _v97_region_type(node["role"])
        region = Dict{String,Any}(
            "region_key" => region_key,
            "region_type" => region_type,
            "dimension" => dimension,
            "raw_coordinate_map" => raw_coordinate,
            "coordinate_class" => _v96_coordinate_class(raw_coordinate, dimension,
                region_type),
        )
        dimension == 1 && (region["length_m"] = parameters["open_branch_length_m"])
        push!(regions, region)
        declared_operator = String(node["operator"])
        slots = String.(node["state_slots"])
        for (slot_index, slot) in enumerate(slots)
            physical_state = get(V97_SLOT_TO_STATE, slot, slot)
            push!(states, Dict{String,Any}(
                "state_key" => region_key * "::" * physical_state,
                "region_key" => region_key,
                "physical_state" => physical_state,
                "scale" => _v97_state_scale(physical_state, parameters),
                "initial_normalized" => 0.90 + 0.0125position +
                    0.005slot_index + 0.0025findfirst(==(declared_operator),
                        V96_REGION_OPERATORS),
                "primary_operator" => declared_operator,
                "additional_operators" => String[],
            ))
        end
        push!(boundaries, Dict{String,Any}(
            "boundary_key" => region_key * "::outer",
            "region_key" => region_key,
            "condition" => _v97_boundary_condition(node["boundary"]),
        ))
    end
    interfaces = Dict{String,Any}[]
    for position in 1:length(order)-1
        source = order[position]; target = order[position + 1]
        edge = edge_by_pair[(source, target)]
        push!(interfaces, Dict{String,Any}(
            "interface_key" => "interface-" * lpad(position, 2, '0'),
            "minus_region_key" => canonical_region[source],
            "plus_region_key" => canonical_region[target],
            "conditions" => [String(edge["coupling"]), "paired_conservation"],
        ))
    end
    nodes = [lookup[id] for id in order]
    physics = Dict{String,Any}(
        "regions" => regions,
        "states" => states,
        "interfaces" => interfaces,
        "boundaries" => boundaries,
        "parameters" => parameters,
        "declared_observables" => ["beta", "net_power_w", "stability_margin",
            "wall_load_w_m2"],
        "declaration_blockers" => _v97_declaration_blockers(nodes),
        "validation_evidence" => nothing,
        "reconstruction" => Dict(
            "grammar_id" => String(topology["grammar_id"]),
            "topology_hash" => String(topology["topology_hash"]),
            "isomorphism_hash" => String(topology["isomorphism_hash"]),
            "structural_gene_digits" => Int.(topology["structural_gene_digits"]),
            "physical_parameter_hash" => parameters["physical_parameter_hash"],
            "source" => index <= V97_SEALED_REQUEST_COUNT ?
                "sealed_v91_request_index" : "complete_20bit_grammar_tail",
            "historical_result_fields_read" => ["request_index"],
            "historical_gate_metric_consumed" => false,
        ),
        "claim_boundary" => EXHAUSTIVE_PHYSICAL_RESCREEN_V97_CLAIM_BOUNDARY,
    )
    physics
end

function default_physical_provider_registry_v97()
    registry = default_physical_provider_registry_v96()
    capability = ProviderCapabilityV96(
        "periodic_identification_provider_v97", "available", ["boundary"], String[],
        ["periodic_identification"], ["FV0_volume", "FV0_surface", "FV0_line",
            "scalar_0d"], ["FV0_volume", "FV0_surface", "FV0_line", "scalar_0d"],
        [0, 1, 2, 3], [0, 1, 2, 3],
        ["cartesian", "axisymmetric", "curvilinear", "surface", "open_field", "scalar"],
        ["cartesian", "axisymmetric", "curvilinear", "surface", "open_field", "scalar"],
        "v97.0", EXHAUSTIVE_PHYSICAL_RESCREEN_V97_CLAIM_BOUNDARY)
    register_physical_provider_v96!(registry, capability, _v96_declared_fragment)
    registry
end

function _v97_route_histogram(routes)
    result = Dict("closed" => 0, "unsupported" => 0, "ambiguous" => 0)
    for route in routes
        status = String(route["status"])
        result[status] = get(result, status, 0) + 1
    end
    result
end

function plan_indexed_field_dependencies_v97(physics, graph,
        assembly::PhysicalGraphAssemblyV96)
    records = Dict{String,Any}[]
    dag = Dict{String,Any}[]
    push!(records, Dict("field_key" => "topology_structure", "class" => "recovered",
        "available" => true, "dependencies" => String[], "blockers" => String[]))
    push!(records, Dict("field_key" => "physical_design_parameters",
        "class" => "recovered", "available" => true, "dependencies" => String[],
        "blockers" => String[], "historical_gate_metric_consumed" => false))
    push!(records, Dict("field_key" => "candidate_mesh", "class" => "derived",
        "available" => true, "dependencies" => ["topology_structure",
            "physical_design_parameters"], "blockers" => String[]))
    push!(dag, Dict("field_key" => "candidate_mesh", "operation" => "derived",
        "dependencies" => ["topology_structure", "physical_design_parameters"],
        "ready" => true))
    route_closed = all(route -> route["status"] == "closed", assembly.routes)
    provider_blockers = sort!(unique(String.(assembly.blockers)))
    provider_available = route_closed && isempty(provider_blockers) && assembly.solver_allowed
    push!(records, Dict("field_key" => "provider_closure", "class" =>
        (provider_available ? "computable" : "unsupported"),
        "available" => provider_available, "dependencies" => ["candidate_mesh"],
        "blockers" => provider_blockers,
        "provider_route_count" => length(assembly.routes)))
    push!(dag, Dict("field_key" => "provider_closure", "operation" => "computable",
        "dependencies" => ["candidate_mesh"], "ready" => provider_available))
    push!(records, Dict("field_key" => "whole_graph_state", "class" => "computable",
        "available" => false, "dependencies" => ["provider_closure"],
        "blockers" => provider_available ? ["deferred_until_unique_closed_input"] :
            ["unavailable_dependency:provider_closure"]))
    push!(dag, Dict("field_key" => "whole_graph_state", "operation" => "computable",
        "dependencies" => ["provider_closure"], "ready" => false))
    push!(records, Dict("field_key" => "solve_derived_observables", "class" => "derived",
        "available" => false, "dependencies" => ["whole_graph_state"],
        "blockers" => ["unavailable_dependency:whole_graph_state"]))
    push!(dag, Dict("field_key" => "solve_derived_observables", "operation" => "derived",
        "dependencies" => ["whole_graph_state"], "ready" => false))
    push!(records, Dict("field_key" => "candidate_bound_validation", "class" =>
        "external_evidence", "available" => false, "dependencies" => String[],
        "blockers" => ["external_evidence_unavailable"]))
    classes = Set(String(record["class"]) for record in records)
    body = Dict{String,Any}(
        "status" => provider_available ? "computationally_closed" : "unsupported",
        "records" => records,
        "recompute_dag" => dag,
        "recompute_order" => ["candidate_mesh", "provider_closure",
            "whole_graph_state", "solve_derived_observables"],
        "field_classes_present" => sort!(collect(classes)),
        "external_evidence_independent" => true,
        "validation_blocks_numerical_execution" => false,
        "claim_boundary" => EXHAUSTIVE_PHYSICAL_RESCREEN_V97_CLAIM_BOUNDARY,
    )
    body["plan_hash"] = canonical_hash(body)
    body
end

function _v97_solver_input_hash(graph, assembly::PhysicalGraphAssemblyV96)
    canonical_hash(Dict(
        "graph_hash" => graph["graph_hash"],
        "assembly_hash" => assembly.assembly_hash,
        "row_keys" => assembly.row_keys,
        "variable_keys" => assembly.variable_keys,
        "mesh_hash" => assembly.mesh_hash,
    ))
end

function compile_indexed_closure_v97(index::Integer;
        registry = default_physical_provider_registry_v97(), relabel_nonce::Integer = 0)
    physics = reconstruct_indexed_physics_v97(index; relabel_nonce)
    graph = compile_physical_graph_v96(physics)
    assembly = assemble_physical_graph_v96(graph, registry)
    dependency = plan_indexed_field_dependencies_v97(physics, graph, assembly)
    solver_input_hash = _v97_solver_input_hash(graph, assembly)
    dedup_key = canonical_hash(Dict("graph_hash" => graph["graph_hash"],
        "solver_input_hash" => solver_input_hash))
    reconstruction = Dict{String,Any}(physics["reconstruction"])
    status = assembly.solver_allowed && dependency["status"] == "computationally_closed" ?
        "closed" : "unsupported"
    route_histogram = _v97_route_histogram(assembly.routes)
    row = Dict{String,Any}(
        "request_index" => Int(index),
        "source_partition" => reconstruction["source"],
        "topology_hash" => reconstruction["topology_hash"],
        "isomorphism_hash" => reconstruction["isomorphism_hash"],
        "physical_parameter_hash" => reconstruction["physical_parameter_hash"],
        "graph_hash" => graph["graph_hash"],
        "solver_input_hash" => solver_input_hash,
        "dedup_key" => dedup_key,
        "screen_status" => status,
        "blockers" => assembly.blockers,
        "route_histogram" => route_histogram,
        "dependency_plan_hash" => dependency["plan_hash"],
        "whole_graph_solver_eligible" => assembly.solver_allowed,
        "high_cost_executed" => false,
        "historical_result_fields_read" => ["request_index"],
        "historical_gate_metric_consumed" => false,
        "basis_direct_metric_credit" => false,
        "partial_subgraph_credit" => false,
        "physical_conclusion_expanded" => false,
    )
    row["row_hash"] = canonical_hash(row)
    (row = row, physics = physics, graph = graph, assembly = assembly,
        dependency_plan = dependency)
end

function _v97_physical_admissibility(execution)
    solve = Dict{String,Any}(execution["solve"])
    get(solve, "status", "") == "pass" || return Dict{String,Any}(
        "status" => "not_executed", "reasons" => ["solve_not_passed"])
    values = Float64.(get(solve, "state", Float64[]))
    reasons = String[]
    isempty(values) && push!(reasons, "empty_state")
    all(isfinite, values) || push!(reasons, "nonfinite_state")
    any(value -> value < 0.0, values) && push!(reasons, "negative_normalized_state")
    observables = Dict{String,Any}(get(execution, "observables", Dict{String,Any}()))
    metrics = Dict{String,Any}(get(observables, "metrics", Dict{String,Any}()))
    stability = get(metrics, "stability_margin", Dict{String,Any}())
    if get(stability, "status", "") == "available" &&
            Float64(stability["value"]) <= 0.0
        push!(reasons, "nonpositive_reduced_stability_margin")
    end
    Dict{String,Any}(
        "status" => isempty(reasons) ? "pass" : "physical_fail",
        "reasons" => reasons,
        "gate_scope" => "generic_state_admissibility_and_positive_reduced_linear_margin",
        "mission_specific_power_or_wall_threshold_applied" => false,
        "claim_boundary" => EXHAUSTIVE_PHYSICAL_RESCREEN_V97_CLAIM_BOUNDARY)
end

function execute_unique_closed_v97(index::Integer, expected_graph_hash,
        expected_solver_input_hash; registry = default_physical_provider_registry_v97())
    compiled = compile_indexed_closure_v97(index; registry)
    compiled.row["screen_status"] == "closed" || throw(ArgumentError(
        "v97 high-cost execution is forbidden for a non-closed input"))
    compiled.row["graph_hash"] == String(expected_graph_hash) || throw(ArgumentError(
        "v97 graph hash changed between closure and execution"))
    compiled.row["solver_input_hash"] == String(expected_solver_input_hash) ||
        throw(ArgumentError("v97 solver input hash changed between closure and execution"))
    execution = execute_physical_stage_chain_v96(compiled.physics; registry,
        validation_applicable = true, validation_evidence = nothing)
    numerical_status = String(get(execution["numerical_vvuq"], "status", "not_executed"))
    admissibility = _v97_physical_admissibility(execution)
    status = String(execution["status"])
    if status == "unsupported"
        status = "unsupported"
    elseif status == "numerical_fail" || numerical_status == "numerical_fail"
        status = "numerical_fail"
    elseif admissibility["status"] == "physical_fail"
        status = "physical_fail"
    else
        status = "unknown"
    end
    status in V97_SCREEN_STATUSES || (status = "unknown")
    solve = Dict{String,Any}(execution["solve"])
    validation = Dict{String,Any}(execution["validation_vvuq"])
    row = Dict{String,Any}(
        "request_index" => Int(index),
        "graph_hash" => compiled.row["graph_hash"],
        "solver_input_hash" => compiled.row["solver_input_hash"],
        "dedup_key" => compiled.row["dedup_key"],
        "screen_status" => status,
        "closure_status" => "closed",
        "high_cost_executed" => true,
        "stage_order" => execution["stage_order"],
        "solve_hash" => get(solve, "solve_hash", nothing),
        "numerical_vvuq" => numerical_status,
        "physical_admissibility" => admissibility,
        "validation_vvuq" => get(validation, "status", "unknown"),
        "observables" => get(execution, "observables", Dict{String,Any}()),
        "historical_gate_metric_consumed" => false,
        "basis_direct_metric_credit" => false,
        "partial_subgraph_credit" => false,
        "promotion_eligible" => false,
        "physical_conclusion_expanded" => false,
    )
    row["execution_hash"] = canonical_hash(row)
    row
end

function _v97_manufactured_physics()
    physics = reconstruct_indexed_physics_v97(699_051)
    physics["declaration_blockers"] = String[]
    for state in physics["states"]
        state["initial_normalized"] = 1.0
    end
    for boundary in physics["boundaries"]
        boundary["condition"] = "closed_no_flux"
    end
    physics
end

function run_v97_reference_sentinels(project_root::AbstractString;
        registry = default_physical_provider_registry_v97())
    manufactured_physics = _v97_manufactured_physics()
    manufactured = execute_physical_stage_chain_v96(manufactured_physics; registry,
        validation_applicable = false)
    expected = Float64[state["initial_normalized"] * state["scale"]
        for state in manufactured_physics["states"]]
    state_map = Dict{String,Any}(get(manufactured["solve"], "physical_state_map",
        Dict{String,Any}()))
    observed = Float64[get(state_map, String(state["state_key"]), NaN)
        for state in manufactured_physics["states"]]
    manufactured_error = length(expected) == length(observed) ?
        maximum(abs, expected - observed; init = 0.0) : Inf
    anchors = load_candidate_solver_reference_anchors_v1(joinpath(project_root, "fixtures",
        "candidate_solver_reference_anchors_v1.json"))
    references = Dict{String,Any}[]
    for anchor in anchors
        physics = normalize_reference_physics_v96(anchor)
        execution = execute_physical_stage_chain_v96(physics; registry,
            validation_applicable = false)
        trusted = get(execution["assembly"], "status", "") == "closed" &&
            get(execution["solve"], "status", "") == "pass" &&
            get(execution["numerical_vvuq"], "status", "") == "pass"
        push!(references, Dict{String,Any}(
            "anchor_key" => String(anchor["anchor_id"]),
            "status" => trusted ? "pass" : "fail",
            "graph_hash" => execution["graph_hash"],
            "solve_hash" => get(execution["solve"], "solve_hash", nothing),
            "stage_order" => execution["stage_order"],
            "validation_credit" => false,
        ))
    end
    manufactured_pass = get(manufactured["assembly"], "status", "") == "closed" &&
        get(manufactured["solve"], "status", "") == "pass" &&
        get(manufactured["numerical_vvuq"], "status", "") == "pass" &&
        manufactured_error <= 1e-8
    passed = manufactured_pass && length(references) == 2 &&
        all(item -> item["status"] == "pass", references)
    body = Dict{String,Any}(
        "status" => passed ? "pass" : "fail",
        "manufactured" => Dict("status" => manufactured_pass ? "pass" : "fail",
            "maximum_physical_state_error" => manufactured_error,
            "graph_hash" => manufactured["graph_hash"],
            "solve_hash" => get(manufactured["solve"], "solve_hash", nothing)),
        "reference_controls" => references,
        "reference_recall" => Dict("passed" => count(item -> item["status"] == "pass",
            references), "total" => length(references)),
        "fail_fast_required" => true,
        "same_v96_chain" => true,
        "claim_boundary" => EXHAUSTIVE_PHYSICAL_RESCREEN_V97_CLAIM_BOUNDARY,
    )
    body["sentinel_hash"] = canonical_hash(body)
    body
end
