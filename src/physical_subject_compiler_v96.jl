const PHYSICAL_SUBJECT_COMPILER_V96_CLAIM_BOUNDARY =
    "The compiler materializes a reduced candidate-bound finite-volume mesh and normalized perturbation system from declared geometry, states, operators, interfaces, and boundaries. It does not use published output targets as solver inputs and does not claim full-fidelity equilibrium or validation."

const V96_OPERATOR_ALIASES = Dict(
    "control_volume_particle_inventory_v1" => "particle_balance",
    "control_volume_thermal_energy_v1" => "energy_balance",
    "state_derived_bohm_transport_l1_v1" => "cross_field_transport",
    "state_derived_dt_reaction_bremsstrahlung_l1_v1" => "reaction_radiation",
    "fixed_current_flux_inventory_l1_v1" => "field_balance",
    "state_derived_parallel_streaming_l1_v1" => "parallel_transport",
    "candidate_bound_multiregion_nonlinear_dae_v90" => "coupled_inventory_root",
)

_v96_operator_name(value) = get(V96_OPERATOR_ALIASES, String(value), String(value))

function _v96_coordinate_class(raw, dimension, region_type)
    text = lowercase(String(raw)); kind = lowercase(String(region_type))
    Int(dimension) == 0 && return "scalar"
    Int(dimension) == 1 && return "open_field"
    Int(dimension) == 2 && return "surface"
    occursin("axisym", text) && return "axisymmetric"
    (occursin("open", text) || occursin("terminal", kind)) && return "open_field"
    occursin("cartesian", text) && return "cartesian"
    "curvilinear"
end

_v96_function_space(dimension) = Int(dimension) == 3 ? "FV0_volume" :
    Int(dimension) == 2 ? "FV0_surface" : Int(dimension) == 1 ? "FV0_line" : "scalar_0d"

function _v96_region_measure(region, parameters)
    dimension = Int(region["dimension"])
    major = Float64(get(parameters, "major_radius_m", 1.0))
    minor = Float64(get(parameters, "minor_radius_m", get(parameters,
        "wall_minor_radius_m", 0.5)))
    elongation = Float64(get(parameters, "elongation", 1.0))
    kind = String(region["region_type"])
    if dimension == 3
        if haskey(region, "radial_extent_normalized")
            extent = Float64.(region["radial_extent_normalized"])
            outer = max(extent[2], extent[1] + 1e-3) * minor
            inner = max(extent[1], 0.0) * minor
            return max(2pi^2 * major * elongation * (outer^2 - inner^2), 1e-6)
        elseif kind == "open_loss"
            length_value = Float64(get(region, "length_m", get(parameters,
                "open_branch_length_m", 2major)))
            return max(pi * (0.25minor)^2 * length_value, 1e-6)
        end
        return max(Float64(get(parameters, "volume_m3",
            2pi^2 * major * minor^2 * elongation)), 1e-6)
    elseif dimension == 2
        return max(pi * minor^2, 1e-6)
    elseif dimension == 1
        return max(Float64(get(region, "length_m", 2major)), 1e-6)
    end
    1.0
end

function _v96_cell_coordinates(dimension, measure, offset)
    d = Int(dimension); m = Float64(measure); shift = Float64(offset)
    if d == 3
        side = cbrt(m); return [[shift + x * side, y * side, z * side]
            for x in (0.0, 1.0), y in (0.0, 1.0), z in (0.0, 1.0)] |> vec
    elseif d == 2
        side = sqrt(m); return [[shift + x * side, y * side, 0.0]
            for x in (0.0, 1.0), y in (0.0, 1.0)] |> vec
    elseif d == 1
        return [[shift, 0.0, 0.0], [shift + m, 0.0, 0.0]]
    end
    [[shift, 0.0, 0.0]]
end

function _v96_mesh_region(region, parameters, index)
    dimension = Int(region["dimension"])
    measure = _v96_region_measure(region, parameters)
    coordinates = _v96_cell_coordinates(dimension, measure, 3.0 * (index - 1))
    connectivity = [collect(1:length(coordinates))]
    body = Dict{String,Any}(
        "region_key" => String(region["region_key"]),
        "dimension" => dimension, "cell_count" => 1,
        "cell_measure" => measure, "node_coordinates_m" => coordinates,
        "cell_connectivity" => connectivity,
        "function_space" => _v96_function_space(dimension),
        "coordinate_class" => String(region["coordinate_class"]),
        "raw_coordinate_map" => String(region["raw_coordinate_map"]),
        "materialization" => "explicit_candidate_bound_lumped_finite_volume")
    body["mesh_hash"] = canonical_hash(body)
    body
end

function _v96_reference_state_scale(state_id, initial)
    value = abs(Float64(get(initial, state_id, 1.0)))
    max(value, 1e-12)
end

function normalize_reference_physics_v96(record_raw)
    record = Dict{String,Any}(_v93_plain(record_raw))
    parameters = Dict{String,Any}(_v93_plain(record["parameters"]))
    initial = Dict{String,Any}(_v93_plain(record["initial_conditions"]))
    regions = Dict{String,Any}[]
    for raw in Dict{String,Any}.(record["regions"])
        dimension = 3; region_type = String(raw["kind"])
        push!(regions, Dict{String,Any}(
            "region_key" => String(raw["region_id"]), "region_type" => region_type,
            "dimension" => dimension,
            "raw_coordinate_map" => String(get(raw, "geometry_model", "declared_geometry")),
            "coordinate_class" => _v96_coordinate_class(get(raw, "geometry_model", ""),
                dimension, region_type)))
    end
    host = String(first(regions)["region_key"])
    bindings = Dict{String,Any}.(get(record, "module_bindings", Any[]))
    states = Dict{String,Any}[]
    for raw in Dict{String,Any}.(record["state_variables"])
        state_id = String(raw["state_id"])
        operators = unique(_v96_operator_name(binding["operator_id"])
            for binding in bindings if state_id in String.(get(binding, "state_ids", Any[])))
        primary = state_id == "particle_inventory" ? "particle_balance" :
            state_id == "thermal_energy" ? "energy_balance" : "field_balance"
        primary in operators || pushfirst!(operators, primary)
        push!(states, Dict{String,Any}(
            "state_key" => host * "::" * state_id, "region_key" => host,
            "physical_state" => state_id, "scale" => _v96_reference_state_scale(state_id, initial),
            "initial_normalized" => 1.0, "primary_operator" => primary,
            "additional_operators" => [value for value in operators if value != primary]))
    end
    Dict{String,Any}(
        "regions" => regions, "states" => states, "interfaces" => Any[],
        "boundaries" => [Dict("boundary_key" => host * "::outer",
            "region_key" => host, "condition" => "closed_no_flux")],
        "parameters" => parameters, "declared_observables" => Any[],
        "declaration_blockers" => String[],
        "validation_evidence" => nothing,
        "claim_boundary" => PHYSICAL_SUBJECT_COMPILER_V96_CLAIM_BOUNDARY)
end

function _v96_profile_scale(record, profile_id, fallback)
    for raw in Dict{String,Any}.(get(record, "profiles", Any[]))
        String(get(raw, "profile_id", "")) == profile_id || continue
        coefficients = Float64.(get(raw, "coefficients", Any[]))
        isempty(coefficients) || return max(maximum(abs, coefficients), 1e-12)
    end
    max(abs(Float64(fallback)), 1e-12)
end

function _v96_candidate_state_inventory(region, scales, record)
    key = String(region["region_key"]); kind = String(region["region_type"])
    field = Float64(get(scales, "reference_field_t", 1.0))
    density = _v96_profile_scale(record, "density", get(scales, "reference_density_m3", 1e19))
    temperature = _v96_profile_scale(record, "temperature",
        get(scales, "reference_temperature_ev", 1e3))
    pressure = _v96_profile_scale(record, "pressure", density * temperature * 1.602176634e-19)
    current = _v96_profile_scale(record, "current", field / (4pi * 1e-7))
    rotation = _v96_profile_scale(record, "rotation", 1.0)
    inventory = if kind == "plasma"
        [("magnetic_field", field, "field_balance"),
         ("pressure", pressure, "energy_balance"),
         ("density", density, "particle_balance"),
         ("temperature", temperature, "cross_field_transport"),
         ("current_density", current, "field_balance"),
         ("rotation", rotation, "actuator_feedback")]
    elseif kind == "vacuum"
        [("magnetic_field", field, "field_balance")]
    elseif kind == "coil"
        [("magnetic_field", field, "coil_response"),
         ("current_density", current, "coil_response"),
         ("temperature", temperature, "energy_balance")]
    elseif kind == "wall"
        [("magnetic_field", field, "wall_response"),
         ("current_density", current, "wall_response"),
         ("temperature", temperature, "energy_balance")]
    elseif kind == "open_loss"
        [("magnetic_field", field, "field_balance"),
         ("pressure", pressure, "parallel_transport"),
         ("density", density, "parallel_transport"),
         ("temperature", temperature, "parallel_transport")]
    else
        [("pressure", pressure, "terminal_balance"),
         ("density", density, "terminal_balance"),
         ("temperature", temperature, "terminal_balance")]
    end
    [Dict{String,Any}(
        "state_key" => key * "::" * state, "region_key" => key,
        "physical_state" => state, "scale" => max(abs(value), 1e-12),
        "initial_normalized" => 1.0, "primary_operator" => operator,
        "additional_operators" => String[]) for (state, value, operator) in inventory]
end

function _v96_node_region_map(source_regions)
    mapping = Dict{String,Vector{String}}()
    for region in source_regions, node in String.(get(region, "source_nodes", Any[]))
        push!(get!(mapping, node, String[]), String(region["region_id"]))
    end
    mapping
end

function normalize_generated_physics_v96(record_raw)
    record = Dict{String,Any}(_v93_plain(record_raw))
    scales = Dict{String,Any}(_v93_plain(get(record, "scales", Dict{String,Any}())))
    source_regions = Dict{String,Any}.(get(record, "regions", Any[]))
    regions = Dict{String,Any}[]
    for raw in source_regions
        dimension = Int(raw["dimension"]); kind = String(raw["region_type"])
        coordinate = String(get(raw, "coordinate_map", "declared_geometry"))
        item = Dict{String,Any}(
            "region_key" => String(raw["region_id"]), "region_type" => kind,
            "dimension" => dimension, "raw_coordinate_map" => coordinate,
            "coordinate_class" => _v96_coordinate_class(coordinate, dimension, kind))
        haskey(raw, "radial_extent_normalized") &&
            (item["radial_extent_normalized"] = raw["radial_extent_normalized"])
        haskey(raw, "length_m") && (item["length_m"] = raw["length_m"])
        push!(regions, item)
    end
    states = reduce(vcat, (_v96_candidate_state_inventory(region, scales, record)
        for region in regions); init = Dict{String,Any}[])
    obligations = Dict{String,Any}(_v93_plain(get(record, "applicability_obligations",
        Dict{String,Any}())))
    declared = unique(_v96_operator_name(value)
        for value in String.(get(obligations, "declared_operators", Any[])))
    present = Set(String(state["primary_operator"]) for state in states)
    for operator in declared
        operator in present && continue
        target = findfirst(state -> operator == "reaction_radiation" ?
            state["physical_state"] in ("temperature", "pressure") :
            operator in ("fault_transition", "coupled_inventory_root") ?
            state["physical_state"] in ("rotation", "density") : true, states)
        target === nothing || push!(states[target]["additional_operators"], operator)
    end
    node_regions = _v96_node_region_map(source_regions)
    region_keys = String[item["region_key"] for item in regions]
    interfaces = Dict{String,Any}[]
    for raw in Dict{String,Any}.(get(record, "interface_conditions", Any[]))
        source_choices = get(node_regions, String(get(raw, "source_node_id", "")), region_keys)
        target_choices = get(node_regions, String(get(raw, "target_node_id", "")), reverse(region_keys))
        minus = first(source_choices); plus = first(target_choices)
        if minus == plus
            alternative = findfirst(!=(minus), region_keys)
            plus = alternative === nothing ? plus : region_keys[alternative]
        end
        push!(interfaces, Dict{String,Any}(
            "interface_key" => String(raw["interface_id"]),
            "minus_region_key" => minus, "plus_region_key" => plus,
            "conditions" => String.(get(raw, "conditions", Any[]))))
    end
    boundaries = Dict{String,Any}[]
    for region in regions
        kind = String(region["region_type"])
        condition = kind == "terminal" ? "absorbing_terminal" :
            kind == "open_loss" ? "open_outflow" : "closed_no_flux"
        push!(boundaries, Dict{String,Any}(
            "boundary_key" => String(region["region_key"]) * "::outer",
            "region_key" => String(region["region_key"]), "condition" => condition))
    end
    qualification = Dict{String,Any}(_v93_plain(get(record, "qualification",
        Dict{String,Any}())))
    declaration_blockers = get(qualification, "status", "pass") == "pass" ? String[] :
        String.(get(qualification, "all_blockers", [get(qualification, "first_blocker",
            "source_physical_realization_incomplete")]))
    Dict{String,Any}(
        "regions" => regions, "states" => states, "interfaces" => interfaces,
        "boundaries" => boundaries, "parameters" => scales,
        "declaration_blockers" => declaration_blockers,
        "declared_observables" => Any[], "validation_evidence" => nothing,
        "claim_boundary" => PHYSICAL_SUBJECT_COMPILER_V96_CLAIM_BOUNDARY)
end

function _v96_operator_weight(operator)
    index = findfirst(==(String(operator)), V96_REGION_OPERATORS)
    index === nothing ? 0.02 : 0.01 + 0.002 * index
end

function compile_physical_graph_v96(physics_raw; coefficient_scale::Real = 1.0)
    physics = Dict{String,Any}(_v93_plain(physics_raw))
    regions = Dict{String,Any}.(physics["regions"])
    states = Dict{String,Any}.(physics["states"])
    meshes = [_v96_mesh_region(region, physics["parameters"], index)
        for (index, region) in enumerate(regions)]
    mesh_by_region = Dict(String(mesh["region_key"]) => mesh for mesh in meshes)
    region_by_key = Dict(String(region["region_key"]) => region for region in regions)
    variables = Dict{String,Any}[]; equations = Dict{String,Any}[]
    requirements = Dict{String,Any}[]
    for state in states
        key = String(state["state_key"]); region_key = String(state["region_key"])
        region = region_by_key[region_key]; mesh = mesh_by_region[region_key]
        row = "row::" * key; operator = String(state["primary_operator"])
        push!(variables, Dict{String,Any}(
            "variable_key" => key, "region_key" => region_key,
            "physical_state" => String(state["physical_state"]),
            "function_space" => mesh["function_space"], "scale" => Float64(state["scale"])))
        push!(equations, Dict{String,Any}(
            "equation_key" => "equation::" * key, "row_key" => row,
            "region_key" => region_key, "physical_state" => String(state["physical_state"])))
        coefficient = Float64(coefficient_scale) * (1.0 + _v96_operator_weight(operator) *
            log1p(Float64(mesh["cell_measure"])))
        payload = Dict{String,Any}(
            "owned_rows" => [row],
            "entries" => [Dict("row_key" => row, "variable_key" => key,
                "coefficient" => coefficient)],
            "rhs_entries" => [Dict("row_key" => row,
                "value" => coefficient * Float64(state["initial_normalized"]))],
            "conservative" => false)
        push!(requirements, Dict{String,Any}(
            "requirement_key" => "primary::" * key, "kind" => "primary_operator",
            "physical_states" => [String(state["physical_state"])], "operator" => operator,
            "source_space" => mesh["function_space"], "target_space" => mesh["function_space"],
            "source_dimension" => region["dimension"], "target_dimension" => region["dimension"],
            "source_coordinate" => region["coordinate_class"],
            "target_coordinate" => region["coordinate_class"], "payload" => payload))
        for (index, additional) in enumerate(String.(get(state, "additional_operators", Any[])))
            weight = Float64(coefficient_scale) * _v96_operator_weight(additional)
            additional_payload = Dict{String,Any}(
                "owned_rows" => String[],
                "entries" => [Dict("row_key" => row, "variable_key" => key,
                    "coefficient" => weight)],
                "rhs_entries" => [Dict("row_key" => row,
                    "value" => weight * Float64(state["initial_normalized"]))],
                "conservative" => false)
            push!(requirements, Dict{String,Any}(
                "requirement_key" => "additional::" * key * "::" * string(index),
                "kind" => "additional_operator", "physical_states" =>
                    [String(state["physical_state"])], "operator" => additional,
                "source_space" => mesh["function_space"],
                "target_space" => mesh["function_space"],
                "source_dimension" => region["dimension"],
                "target_dimension" => region["dimension"],
                "source_coordinate" => region["coordinate_class"],
                "target_coordinate" => region["coordinate_class"],
                "payload" => additional_payload))
        end
    end
    state_lookup = Dict((String(item["region_key"]), String(item["physical_state"])) =>
        String(item["state_key"]) for item in states)
    variable_lookup = Dict(String(item["variable_key"]) => item for item in variables)
    for interface in Dict{String,Any}.(get(physics, "interfaces", Any[]))
        minus = String(interface["minus_region_key"]); plus = String(interface["plus_region_key"])
        left = region_by_key[minus]; right = region_by_key[plus]
        common = sort!(collect(intersect(
            Set(state for ((region, state), _) in state_lookup if region == minus),
            Set(state for ((region, state), _) in state_lookup if region == plus))))
        operator = Int(left["dimension"]) != Int(right["dimension"]) ?
            "conservative_mixed_dimension_transfer" :
            String(left["coordinate_class"]) != String(right["coordinate_class"]) ?
            "conservative_coordinate_transfer" : "conservative_same_coordinate_flux"
        for state_name in common
            left_key = state_lookup[(minus, state_name)]; right_key = state_lookup[(plus, state_name)]
            left_row = "row::" * left_key; right_row = "row::" * right_key
            coupling = Float64(coefficient_scale) * 0.01 /
                sqrt(max(Float64(mesh_by_region[minus]["cell_measure"]), 1e-12) *
                    max(Float64(mesh_by_region[plus]["cell_measure"]), 1e-12))^0.1
            entries = [
                Dict("row_key" => left_row, "variable_key" => left_key, "coefficient" => coupling),
                Dict("row_key" => left_row, "variable_key" => right_key, "coefficient" => -coupling),
                Dict("row_key" => right_row, "variable_key" => right_key, "coefficient" => coupling),
                Dict("row_key" => right_row, "variable_key" => left_key, "coefficient" => -coupling)]
            payload = Dict{String,Any}("owned_rows" => String[], "entries" => entries,
                "rhs_entries" => Any[], "conservative" => true)
            push!(requirements, Dict{String,Any}(
                "requirement_key" => "interface::" * String(interface["interface_key"]) *
                    "::" * state_name, "kind" => "interface",
                "physical_states" => [state_name], "operator" => operator,
                "source_space" => variable_lookup[left_key]["function_space"],
                "target_space" => variable_lookup[right_key]["function_space"],
                "source_dimension" => left["dimension"], "target_dimension" => right["dimension"],
                "source_coordinate" => left["coordinate_class"],
                "target_coordinate" => right["coordinate_class"], "payload" => payload))
        end
    end
    for boundary in Dict{String,Any}.(get(physics, "boundaries", Any[]))
        region_key = String(boundary["region_key"]); region = region_by_key[region_key]
        condition = String(boundary["condition"])
        local_states = [state for state in states if String(state["region_key"]) == region_key]
        isempty(local_states) && continue
        entries = Dict{String,Any}[]
        if condition != "closed_no_flux"
            for state in local_states
                String(state["physical_state"]) in ("density", "temperature", "pressure") || continue
                push!(entries, Dict("row_key" => "row::" * String(state["state_key"]),
                    "variable_key" => String(state["state_key"]),
                    "coefficient" => Float64(coefficient_scale) * 0.005))
            end
        end
        mesh = mesh_by_region[region_key]
        payload = Dict{String,Any}("owned_rows" => String[], "entries" => entries,
            "rhs_entries" => Any[], "conservative" => condition == "closed_no_flux")
        push!(requirements, Dict{String,Any}(
            "requirement_key" => "boundary::" * String(boundary["boundary_key"]),
            "kind" => "boundary", "physical_states" => unique(String(state["physical_state"])
                for state in local_states), "operator" => condition,
            "source_space" => mesh["function_space"], "target_space" => mesh["function_space"],
            "source_dimension" => region["dimension"], "target_dimension" => region["dimension"],
            "source_coordinate" => region["coordinate_class"],
            "target_coordinate" => region["coordinate_class"], "payload" => payload))
    end
    graph_regions = [Dict{String,Any}(
        "region_key" => String(region["region_key"]), "region_type" => region["region_type"],
        "dimension" => region["dimension"], "coordinate" => region["coordinate_class"],
        "mesh_hash" => mesh_by_region[String(region["region_key"])]["mesh_hash"])
        for region in regions]
    body = Dict{String,Any}(
        "regions" => graph_regions, "meshes" => meshes, "variables" => variables,
        "equations" => equations, "requirements" => requirements,
        "declaration_blockers" => String.(get(physics, "declaration_blockers", Any[])),
        "mesh_hash" => canonical_hash([mesh["mesh_hash"] for mesh in meshes]),
        "coefficient_scale" => Float64(coefficient_scale),
        "compiler" => "physical_subject_graph_compiler_v96",
        "evidence_ceiling" => "reduced_lumped_multiregion_finite_volume",
        "claim_boundary" => PHYSICAL_SUBJECT_COMPILER_V96_CLAIM_BOUNDARY)
    body["graph_hash"] = canonical_hash(body)
    body
end
