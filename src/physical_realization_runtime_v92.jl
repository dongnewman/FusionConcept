const PHYSICAL_REALIZATION_V92_CLAIM_BOUNDARY =
    "PhysicalRealizationV92 is a candidate-bound graph-conditioned spatial and physics compilation. Realization pass means only that the candidate is embeddable, well posed at the declared interface level, and consumable by compatible backends; it is not equilibrium, confinement, stability, engineering, or validation evidence."

const V92_ROLE_ORDER = ("root_control_volume", "plasma_inventory",
    "field_evolution", "energy_exchange", "particle_transport",
    "terminal_balance_region")
const V92_DIMENSION_ORDER = ("0d", "1d", "2d", "3d")
const V92_BOUNDARY_ORDER = ("closed", "open", "mixed", "periodic",
    "absorbing")
const V92_FIELD_SEMANTICS_ORDER = ("declared_by_children",
    "axisymmetric_closed", "three_dimensional_closed",
    "open_guiding_field", "hybrid_field", "terminal_flux")
const V92_OPERATOR_ORDER = ("coupled_inventory_root", "particle_balance",
    "energy_balance", "field_balance", "reaction_radiation",
    "parallel_transport", "cross_field_transport", "actuator_feedback",
    "fault_transition", "terminal_balance")

struct PhysicalRealizationV92
    candidate_id::String
    candidate_hash::String
    topology_hash::String
    genome_hash::String
    basis_hash::String
    status::String
    first_blocker::Union{Nothing,String}
    payload::Dict{String,Any}
    realization_hash::String
end

function _v92_index(value, vocabulary)
    index = findfirst(==(String(value)), vocabulary)
    index === nothing && return 0
    return index
end

function _v92_forbidden_identity(value, path::String = "topology")
    forbidden = Set(("family", "device_family", "device_type", "parent",
        "parent_family", "known_generated_label"))
    if value isa AbstractDict
        for (key_raw, item) in pairs(value)
            key = lowercase(String(key_raw))
            key in forbidden && return "$(path).$(key)"
            found = _v92_forbidden_identity(item, "$(path).$(key)")
            found === nothing || return found
        end
    elseif value isa AbstractVector
        for (index, item) in enumerate(value)
            found = _v92_forbidden_identity(item, "$(path)[$(index)]")
            found === nothing || return found
        end
    end
    return nothing
end

function _v92_node_lookup(nodes)
    result = Dict{String,Dict{String,Any}}()
    for node_raw in nodes
        node = _v92_plain(node_raw)
        id = String(node["node_id"])
        haskey(result, id) && throw(ArgumentError("duplicate v92 node_id $(id)"))
        result[id] = node
    end
    return result
end

function _v92_topological_path(topology)
    nodes = _v92_plain(topology["nodes"])
    interfaces = _v92_plain(topology["interfaces"])
    lookup = _v92_node_lookup(nodes)
    root = String(topology["root_id"])
    haskey(lookup, root) || throw(ArgumentError("v92 root_id is missing"))
    outgoing = Dict{String,Vector{String}}()
    incoming = Dict{String,Int}(id => 0 for id in keys(lookup))
    for interface in interfaces
        source = String(interface["source_node_id"])
        target = String(interface["target_node_id"])
        haskey(lookup, source) && haskey(lookup, target) ||
            throw(ArgumentError("v92 interface endpoint missing"))
        push!(get!(outgoing, source, String[]), target)
        incoming[target] += 1
    end
    order = String[]; queue = [root]
    while !isempty(queue)
        id = popfirst!(queue)
        id in order && throw(ArgumentError("v92 topology contains a cycle"))
        push!(order, id)
        for target in sort(get(outgoing, id, String[]))
            push!(queue, target)
        end
    end
    length(order) == length(nodes) || throw(ArgumentError(
        "v92 topology is disconnected from root"))
    return order, lookup, interfaces
end

function _v92_candidate_scales(basis)
    b = Float64.(basis)
    length(b) == 8 || throw(ArgumentError("v92 requires exactly 8 basis coefficients"))
    all(isfinite, b) || throw(ArgumentError("v92 basis must be finite"))
    all(value -> 0.0 <= value <= 1.0, b) || throw(ArgumentError(
        "v92 basis coefficients must remain inside the v91 unit interval"))
    major = 2.5 + 3.5b[1]
    minor = 0.30 + 0.65b[2]
    elongation = 0.85 + 0.75b[3]
    triangularity = 0.45 * (b[4] - 0.5)
    periods = 1 + floor(Int, 5b[5])
    field = 1.0 + 5.0b[6]
    density = 0.5e19 + 4.5e19b[7]
    temperature = 1.0e3 + 24.0e3b[8]
    return Dict{String,Any}(
        "major_radius_m" => major,
        "minor_radius_m" => minor,
        "elongation" => elongation,
        "triangularity" => triangularity,
        "field_periods" => periods,
        "reference_field_t" => field,
        "reference_density_m3" => density,
        "reference_temperature_ev" => temperature,
        "wall_minor_radius_m" => 1.45minor,
        "coil_minor_radius_m" => 1.85minor,
        "open_branch_length_m" => 3.0major)
end

function _v92_node_semantic_coefficients(order, lookup)
    rows = Dict{String,Any}[]
    count = length(order)
    for (path_index, id) in enumerate(order)
        node = lookup[id]
        push!(rows, Dict{String,Any}(
            "node_id" => id,
            "path_fraction" => (path_index - 1) / max(count - 1, 1),
            "role_code" => _v92_index(node["role"], V92_ROLE_ORDER),
            "dimension_code" => _v92_index(node["dimension"], V92_DIMENSION_ORDER) - 1,
            "boundary_code" => _v92_index(node["boundary"], V92_BOUNDARY_ORDER),
            "field_semantics_code" => _v92_index(node["field_semantics"],
                V92_FIELD_SEMANTICS_ORDER),
            "operator_code" => _v92_index(node["operator"],
                V92_OPERATOR_ORDER)))
    end
    return rows
end

function _v92_region_inventory(order, lookup, scales)
    spatial = [lookup[id] for id in order if String(lookup[id]["dimension"]) in
        ("2d", "3d")]
    plasma_nodes = [String(node["node_id"]) for node in spatial if
        String(node["role"]) in ("plasma_inventory", "energy_exchange",
            "particle_transport") || String(node["operator"]) in
        ("particle_balance", "energy_balance", "reaction_radiation",
            "parallel_transport", "cross_field_transport")]
    field_nodes = [String(node["node_id"]) for node in spatial if
        String(node["role"]) == "field_evolution" ||
        String(node["operator"]) == "field_balance"]
    open_nodes = [String(lookup[id]["node_id"]) for id in order if
        String(lookup[id]["boundary"]) in ("open", "absorbing") ||
        String(lookup[id]["field_semantics"]) in
        ("open_guiding_field", "terminal_flux")]
    closed_nodes = [String(lookup[id]["node_id"]) for id in order if
        String(lookup[id]["field_semantics"]) in
        ("axisymmetric_closed", "three_dimensional_closed")]
    regions = Dict{String,Any}[
        Dict("region_id" => "plasma-core", "region_type" => "plasma",
            "dimension" => 3, "source_nodes" => plasma_nodes,
            "coordinate_map" => "graph_conditioned_toroidal_or_mixed_core_v92",
            "radial_extent_normalized" => [0.0, 1.0]),
        Dict("region_id" => "vacuum-shell", "region_type" => "vacuum",
            "dimension" => 3, "source_nodes" => field_nodes,
            "coordinate_map" => "conformal_shell_of_candidate_plasma_v92",
            "radial_extent_normalized" => [1.0, 1.45]),
        Dict("region_id" => "coil-envelope", "region_type" => "coil",
            "dimension" => 3, "source_nodes" => field_nodes,
            "coordinate_map" => "candidate_field_source_envelope_v92",
            "radial_extent_normalized" => [1.70, 2.00]),
        Dict("region_id" => "wall-shell", "region_type" => "wall",
            "dimension" => 3, "source_nodes" => vcat(plasma_nodes, field_nodes),
            "coordinate_map" => "candidate_wall_envelope_v92",
            "radial_extent_normalized" => [1.40, 1.50])]
    if !isempty(open_nodes)
        push!(regions, Dict("region_id" => "open-loss", "region_type" =>
            "open_loss", "dimension" => 3, "source_nodes" => open_nodes,
            "coordinate_map" => "graph_conditioned_open_flux_tube_v92",
            "length_m" => scales["open_branch_length_m"]))
    end
    push!(regions, Dict("region_id" => "terminal", "region_type" =>
        "terminal", "dimension" => 2, "source_nodes" => open_nodes,
        "coordinate_map" => "oriented_open_branch_terminal_cap_v92"))
    return regions, plasma_nodes, field_nodes, open_nodes, closed_nodes
end

function _v92_oriented_surfaces(regions, scales, semantics)
    three_d = "three_dimensional_closed" in semantics
    helical_r = three_d ? 0.06 * scales["minor_radius_m"] : 0.0
    helical_z = three_d ? 0.04 * scales["minor_radius_m"] : 0.0
    surfaces = Dict{String,Any}[]
    for (id, radius, orientation, kind) in (
            ("plasma-boundary", 1.0, "plasma_to_vacuum", "interface"),
            ("wall-inner", 1.40, "vacuum_to_wall", "wall"),
            ("wall-outer", 1.50, "wall_to_exterior", "wall"),
            ("coil-envelope-inner", 1.70, "exterior_to_coil", "coil"),
            ("coil-envelope-outer", 2.00, "coil_to_exterior", "coil"))
        body = Dict{String,Any}(
            "surface_id" => id, "surface_type" => kind,
            "orientation" => orientation,
            "parameter_domain" => Dict("u" => [0.0, 2pi], "v" => [0.0, 2pi]),
            "coordinate_map" => "periodic_elliptic_fourier_surface_v92",
            "major_radius_m" => scales["major_radius_m"],
            "minor_radius_r_m" => radius * scales["minor_radius_m"],
            "minor_radius_z_m" => radius * scales["minor_radius_m"] *
                scales["elongation"],
            "triangularity" => scales["triangularity"],
            "field_periods" => scales["field_periods"],
            "helical_axis_r_m" => radius * helical_r,
            "helical_axis_z_m" => radius * helical_z)
        body["surface_hash"] = canonical_hash(body)
        push!(surfaces, body)
    end
    if any(region -> region["region_type"] == "open_loss", regions)
        for side in ("source", "terminal")
            body = Dict{String,Any}(
                "surface_id" => "open-$(side)-cap",
                "surface_type" => "terminal_cap",
                "orientation" => side == "source" ? "core_to_open_loss" :
                    "open_loss_to_terminal",
                "coordinate_map" => "elliptic_disk_v92",
                "axial_position_m" => side == "source" ? 0.0 :
                    scales["open_branch_length_m"],
                "minor_radius_r_m" => 0.35scales["minor_radius_m"],
                "minor_radius_z_m" => 0.35scales["minor_radius_m"] *
                    scales["elongation"])
            body["surface_hash"] = canonical_hash(body)
            push!(surfaces, body)
        end
    end
    return surfaces
end

function _v92_mesh_levels(surfaces, scales)
    levels = (("coarse", [64, 64, 64], [224, 224]),
        ("medium", [100, 100, 100], [448, 448]),
        ("fine", [160, 160, 160], [896, 896]))
    volume = Dict{String,Any}[]; wall = Dict{String,Any}[]
    surface_hashes = [surface["surface_hash"] for surface in surfaces]
    for (name, cells, faces) in levels
        v = Dict{String,Any}(
            "level" => name, "mesh_type" =>
                "implicit_tensor_product_curvilinear_hexahedral_v92",
            "cell_shape" => cells, "cell_count" => prod(cells),
            "coordinate_map" => "physical_realization_candidate_map_v92",
            "coordinate_map_parameters" => Dict(
                "major_radius_m" => scales["major_radius_m"],
                "minor_radius_m" => scales["minor_radius_m"],
                "elongation" => scales["elongation"],
                "triangularity" => scales["triangularity"],
                "field_periods" => scales["field_periods"]),
            "surface_hashes" => surface_hashes,
            "materialization" => "deterministic_index_to_coordinate_and_connectivity",
            "backend_consumable" => true,
            "minimum_jacobian_lower_bound" =>
                scales["major_radius_m"] - 2.0scales["minor_radius_m"])
        v["mesh_hash"] = canonical_hash(v); push!(volume, v)
        w = Dict{String,Any}(
            "level" => name, "mesh_type" =>
                "implicit_periodic_quadrilateral_wall_mesh_v92",
            "face_shape" => faces, "face_count" => prod(faces),
            "surface_id" => "wall-inner",
            "materialization" => "deterministic_index_to_coordinate_and_connectivity",
            "backend_consumable" => true)
        w["mesh_hash"] = canonical_hash(w); push!(wall, w)
    end
    return volume, wall
end

function _v92_field_sources(field_nodes, lookup, basis, scales)
    sources = Dict{String,Any}[]
    count = max(length(field_nodes), 1)
    for index in 1:count
        node_id = isempty(field_nodes) ? "missing-field-source" : field_nodes[index]
        node = isempty(field_nodes) ? Dict{String,Any}() : lookup[node_id]
        operator_code = isempty(node) ? 0 : _v92_index(node["operator"],
            V92_OPERATOR_ORDER)
        turns = 12 + 2operator_code + index
        current = scales["reference_field_t"] * scales["major_radius_m"] /
            (2.0e-7 * max(turns, 1))
        source = Dict{String,Any}(
            "source_id" => "field-source-$(index)",
            "source_node_id" => node_id,
            "source_type" => "finite_conductor_centerline_plus_current_potential",
            "centerline" => Dict(
                "coordinate_map" => "periodic_fourier_centerline_v92",
                "major_radius_m" => scales["major_radius_m"],
                "minor_radius_m" => scales["coil_minor_radius_m"],
                "field_periods" => scales["field_periods"],
                "phase_rad" => 2pi * (index - 1) / count,
                "fourier_coefficients" => [basis[4] - 0.5,
                    basis[5] - 0.5, basis[6] - 0.5]),
            "turns" => turns, "current_a" => current,
            "conductor_envelope" => Dict("shape" => "rectangular",
                "width_m" => 0.02 + 0.03basis[7],
                "height_m" => 0.02 + 0.03basis[8]),
            "current_potential_basis" => Dict("basis" => "surface_fourier",
                "mode_numbers" => collect(0:scales["field_periods"]),
                "coefficients_a" => current .* Float64.(basis[1:min(8,
                    scales["field_periods"] + 1)])))
        source["source_hash"] = canonical_hash(source); push!(sources, source)
    end
    return sources
end

function _v92_profiles(order, lookup, basis, scales)
    species = ["electron", "deuterium", "tritium"]
    semantic_rows = _v92_node_semantic_coefficients(order, lookup)
    profile_shape = [1.0, 0.5 + 0.4basis[3], 0.05 + 0.15basis[4]]
    return Dict{String,Any}[
        Dict("profile_id" => "density", "state" => "number_density",
            "species" => species, "coordinate" => "normalized_flux_or_open_arc",
            "basis" => "quadratic_bspline", "coefficients" =>
                scales["reference_density_m3"] .* profile_shape,
            "source_nodes" => [row["node_id"] for row in semantic_rows if
                row["operator_code"] in (2, 3, 6, 7)]),
        Dict("profile_id" => "temperature", "state" => "temperature_ev",
            "species" => species, "coordinate" => "normalized_flux_or_open_arc",
            "basis" => "quadratic_bspline", "coefficients" =>
                scales["reference_temperature_ev"] .* [1.0,
                    0.45 + 0.3basis[2], 0.08 + 0.1basis[8]],
            "source_nodes" => [row["node_id"] for row in semantic_rows if
                row["operator_code"] in (3, 5)]),
        Dict("profile_id" => "pressure", "state" => "scalar_pressure_pa",
            "coordinate" => "normalized_flux_or_open_arc",
            "basis" => "derived_species_moment_bspline",
            "coefficients" => scales["reference_density_m3"] *
                scales["reference_temperature_ev"] * 1.602176634e-19 .* profile_shape),
        Dict("profile_id" => "current", "state" => "parallel_current_density",
            "coordinate" => "normalized_flux_or_open_arc",
            "basis" => "quadratic_bspline", "coefficients" =>
                scales["reference_field_t"] / (4pi * 1e-7 *
                    scales["minor_radius_m"]) .* [basis[6], basis[5], 0.0]),
        Dict("profile_id" => "rotation", "state" => "angular_frequency",
            "coordinate" => "normalized_flux_or_open_arc",
            "basis" => "linear_bspline", "coefficients" =>
                [1e3(basis[8] - 0.5), 0.0])]
end

function _v92_interface_conditions(interfaces, lookup)
    rows = Dict{String,Any}[]
    for interface in interfaces
        coupling = String(interface["coupling"])
        conditions = if coupling == "particle_flux"
            ["particle_flux_continuity", "source_sink_balance"]
        elseif coupling == "energy_flux"
            ["energy_flux_continuity", "enthalpy_and_heat_flux_balance"]
        elseif coupling == "field_coupling"
            ["normal_magnetic_flux_continuity", "tangential_field_jump_from_surface_current", "current_continuity", "force_balance"]
        elseif coupling == "operator_feedback"
            ["actuator_signal_continuity", "bounded_source_response", "fault_state_transition"]
        else
            ["unsupported_coupling"]
        end
        row = Dict{String,Any}(
            "interface_id" => interface["interface_id"],
            "source_node_id" => interface["source_node_id"],
            "target_node_id" => interface["target_node_id"],
            "source_boundary" => lookup[String(interface["source_node_id"])]["boundary"],
            "target_boundary" => lookup[String(interface["target_node_id"])]["boundary"],
            "coupling" => coupling,
            "paired_conservation" => interface["paired_conservation"],
            "conditions" => conditions,
            "solver_residual_channels" => conditions)
        row["interface_hash"] = canonical_hash(row); push!(rows, row)
    end
    return rows
end

function _v92_gene_consumption(order, lookup, interfaces, regions, sources,
        profiles, conditions)
    rows = Dict{String,Any}[]
    region_by_node = Dict{String,Vector{String}}()
    for region in regions, node_id in region["source_nodes"]
        push!(get!(region_by_node, String(node_id), String[]),
            String(region["region_id"]))
    end
    for id in order
        node = lookup[id]
        destinations = get(region_by_node, id, String[])
        isempty(destinations) && (destinations = ["profile_or_boundary_host:$(id)"])
        push!(rows, Dict("gene" => "node[$(id)].role",
            "consumers" => vcat(destinations, ["profile_source_assignment"])))
        push!(rows, Dict("gene" => "node[$(id)].dimension",
            "consumers" => ["region_dimension_or_host_dimension", "mesh_coordinate_map"]))
        push!(rows, Dict("gene" => "node[$(id)].boundary",
            "consumers" => ["oriented_surface_assignment", "boundary_condition"]))
        push!(rows, Dict("gene" => "node[$(id)].field_semantics",
            "consumers" => ["geometry_coordinate_map", "solver_applicability"]))
        push!(rows, Dict("gene" => "node[$(id)].operator",
            "consumers" => ["profile_or_field_source_coefficient", "residual_obligation"]))
    end
    for interface in interfaces
        id = String(interface["interface_id"])
        push!(rows, Dict("gene" => "interface[$(id)].coupling",
            "consumers" => ["interface_condition[$(id)]", "coupled_solver_residual[$(id)]"]))
    end
    return rows
end

function _v92_basis_consumption()
    return Dict{String,Any}[
        Dict("basis_index" => 1, "consumers" => ["geometry.major_radius_m", "current_potential.coefficient[1]", "solver.normalization_length"]),
        Dict("basis_index" => 2, "consumers" => ["geometry.minor_radius_m", "temperature_profile.coefficient[2]", "solver.normalization_length"]),
        Dict("basis_index" => 3, "consumers" => ["geometry.elongation", "density_profile.coefficient[2]", "mesh_coordinate_map"]),
        Dict("basis_index" => 4, "consumers" => ["geometry.triangularity", "density_profile.coefficient[3]", "coil_centerline.fourier[1]"]),
        Dict("basis_index" => 5, "consumers" => ["geometry.field_periods", "current_profile.coefficient[2]", "coil_centerline.fourier[2]"]),
        Dict("basis_index" => 6, "consumers" => ["field_source.reference_field_and_current", "current_profile.coefficient[1]", "coil_centerline.fourier[3]"]),
        Dict("basis_index" => 7, "consumers" => ["density_profile.scale", "conductor_envelope.width", "parameter_uq.coefficient"]),
        Dict("basis_index" => 8, "consumers" => ["temperature_profile.scale", "rotation_profile", "conductor_envelope.height", "boundary_coefficient"])]
end

function _v92_applicability(nodes, regions)
    semantics = Set(String(node["field_semantics"]) for node in nodes)
    operators = Set(String(node["operator"]) for node in nodes)
    boundaries = Set(String(node["boundary"]) for node in nodes)
    dimensions = Set(String(node["dimension"]) for node in nodes)
    return Dict{String,Any}(
        "declared_operators" => sort!(collect(operators)),
        "state_variables" => ["magnetic_field", "pressure", "density",
            "temperature", "current_density", "rotation"],
        "region_dimensions" => sort!(collect(dimensions)),
        "boundary_conditions" => sort!(collect(boundaries)),
        "interface_conditions" => sort!(unique(vcat((String.(condition["conditions"])
            for condition in _v92_interface_conditions([], Dict()))...))),
        "field_semantics" => sort!(collect(semantics)),
        "evidence_obligations" => ["equilibrium", "field_line_orbit",
            "ideal_stability", "resistive_stability", "kinetic_stability",
            "nonlinear_stability", "numerical_vvuq", "parameter_uq",
            "independent_solver_comparison", "candidate_bound_validation_vvuq"],
        "solver_input_compatibility" => ["oriented_surfaces",
            "implicit_curvilinear_mesh", "candidate_field_sources",
            "profiles", "interface_residual_channels"],
        "axisymmetric_closed" => "axisymmetric_closed" in semantics,
        "three_dimensional_closed" => "three_dimensional_closed" in semantics,
        "open_field" => "open_guiding_field" in semantics || "open" in boundaries,
        "mixed_topology" => "hybrid_field" in semantics ||
            (("open_guiding_field" in semantics) && any(item -> item in semantics,
                ("axisymmetric_closed", "three_dimensional_closed"))),
        "controller_fault_coupling" => any(item -> item in operators,
            ("actuator_feedback", "fault_transition")),
        "region_types" => [region["region_type"] for region in regions])
end

function compile_physical_realization_v92(dossier_raw)
    dossier = _v92_plain(dossier_raw)
    candidate_id = String(dossier["candidate_id"])
    candidate_hash = String(dossier["dossier_hash"])
    genome = _v92_plain(dossier["genome"])
    topology = _v92_plain(genome["topology"])
    basis = Float64.(dossier["basis"])
    blockers = String[]
    forbidden = _v92_forbidden_identity(topology)
    forbidden === nothing || push!(blockers, "forbidden_routing_identity:$(forbidden)")
    order = String[]; lookup = Dict{String,Dict{String,Any}}(); interfaces = Any[]
    try
        order, lookup, interfaces = _v92_topological_path(topology)
    catch error
        push!(blockers, "invalid_topology:$(sprint(showerror, error))")
    end
    scales = Dict{String,Any}()
    try
        scales = _v92_candidate_scales(basis)
    catch error
        push!(blockers, "invalid_basis:$(sprint(showerror, error))")
    end
    if !isempty(order)
        all(node -> _v92_index(node["role"], V92_ROLE_ORDER) > 0,
            values(lookup)) || push!(blockers, "unsupported_role")
        all(node -> _v92_index(node["dimension"], V92_DIMENSION_ORDER) > 0,
            values(lookup)) || push!(blockers, "unsupported_dimension")
        all(node -> _v92_index(node["boundary"], V92_BOUNDARY_ORDER) > 0,
            values(lookup)) || push!(blockers, "unsupported_boundary")
        all(node -> _v92_index(node["field_semantics"],
            V92_FIELD_SEMANTICS_ORDER) > 0, values(lookup)) ||
            push!(blockers, "unsupported_field_semantics")
        all(node -> _v92_index(node["operator"], V92_OPERATOR_ORDER) > 0,
            values(lookup)) || push!(blockers, "unsupported_operator")
        all(interface -> get(interface, "paired_conservation", false) == true,
            interfaces) || push!(blockers, "unpaired_interface_conservation")
    end
    regions = Dict{String,Any}[]; plasma_nodes = String[]
    field_nodes = String[]; open_nodes = String[]; closed_nodes = String[]
    if isempty(blockers)
        regions, plasma_nodes, field_nodes, open_nodes, closed_nodes =
            _v92_region_inventory(order, lookup, scales)
        isempty(plasma_nodes) && push!(blockers,
            "missing_spatial_plasma_operator_backbone")
        isempty(field_nodes) && push!(blockers,
            "missing_spatial_field_balance_backbone")
        isempty(open_nodes) && push!(blockers,
            "missing_open_loss_or_terminal_declaration")
        isempty(closed_nodes) && isempty(open_nodes) && push!(blockers,
            "missing_declared_field_semantics")
        scales["major_radius_m"] > 2.0scales["minor_radius_m"] ||
            push!(blockers, "self_intersecting_toroidal_embedding")
    end
    nodes = isempty(order) ? Dict{String,Any}[] : [lookup[id] for id in order]
    semantics = Set(String(node["field_semantics"]) for node in nodes)
    surfaces = isempty(scales) ? Dict{String,Any}[] :
        _v92_oriented_surfaces(regions, scales, semantics)
    volume_meshes, wall_meshes = isempty(scales) ?
        (Dict{String,Any}[], Dict{String,Any}[]) : _v92_mesh_levels(surfaces, scales)
    field_sources = isempty(scales) ? Dict{String,Any}[] :
        _v92_field_sources(field_nodes, lookup, basis, scales)
    profiles = isempty(scales) || isempty(order) ? Dict{String,Any}[] :
        _v92_profiles(order, lookup, basis, scales)
    conditions = isempty(order) ? Dict{String,Any}[] :
        _v92_interface_conditions(interfaces, lookup)
    gene_consumption = isempty(order) ? Dict{String,Any}[] :
        _v92_gene_consumption(order, lookup, interfaces, regions,
            field_sources, profiles, conditions)
    basis_consumption = _v92_basis_consumption()
    expected_gene_count = length(order) * 5 + length(interfaces)
    length(gene_consumption) == expected_gene_count || push!(blockers,
        "incomplete_structural_gene_consumption")
    length(basis_consumption) == 8 || push!(blockers,
        "incomplete_basis_consumption")
    initial = Dict{String,Any}(
        "equilibrium_initial_state" => "analytic_candidate_coordinate_map",
        "density_profile_id" => "density",
        "temperature_profile_id" => "temperature",
        "pressure_profile_id" => "pressure",
        "current_profile_id" => "current",
        "rotation_profile_id" => "rotation",
        "orbit_birth_distribution" => Dict("status" => "declared_not_sampled",
            "seed" => 920003, "species" => ["deuterium", "tritium"],
            "phase_space_coordinates" => ["position", "energy", "pitch", "gyrophase"]),
        "stability_perturbation_seed" => 920005)
    applicability = isempty(nodes) ? Dict{String,Any}() :
        _v92_applicability(nodes, regions)
    applicability["interface_conditions"] = sort!(unique(vcat(
        (String.(condition["conditions"]) for condition in conditions)...)))
    status = isempty(blockers) ? "pass" : "fail"
    first_blocker = isempty(blockers) ? nothing : first(blockers)
    payload = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "candidate_id" => candidate_id, "candidate_hash" => candidate_hash,
        "topology_hash" => String(topology["topology_hash"]),
        "isomorphism_hash" => String(topology["isomorphism_hash"]),
        "genome_hash" => canonical_hash(genome),
        "basis_hash" => canonical_hash(basis),
        "source_solver_input_hash" => dossier["realization"]["solver_input_hash"],
        "coordinate_system" => Dict("type" => "right_handed_cartesian_with_candidate_curvilinear_maps",
            "origin_m" => [0.0, 0.0, 0.0], "axes" => ["x", "y", "z"],
            "handedness" => "right", "length_unit" => "m"),
        "scales" => scales, "regions" => regions,
        "oriented_surfaces" => surfaces, "volume_meshes" => volume_meshes,
        "wall_meshes" => wall_meshes, "field_sources" => field_sources,
        "profiles" => profiles, "initial_conditions" => initial,
        "interface_conditions" => conditions,
        "applicability_obligations" => applicability,
        "structural_gene_consumption" => gene_consumption,
        "basis_consumption" => basis_consumption,
        "qualification" => Dict("status" => status,
            "first_blocker" => first_blocker, "all_blockers" => blockers,
            "spatial_plasma_node_count" => length(plasma_nodes),
            "spatial_field_node_count" => length(field_nodes),
            "open_or_terminal_node_count" => length(open_nodes),
            "closed_field_node_count" => length(closed_nodes),
            "structural_gene_consumption_count" => length(gene_consumption),
            "expected_structural_gene_consumption_count" => expected_gene_count,
            "basis_consumption_count" => length(basis_consumption)),
        "claim_boundary" => PHYSICAL_REALIZATION_V92_CLAIM_BOUNDARY)
    realization_hash = canonical_hash(payload)
    payload["realization_hash"] = realization_hash
    return PhysicalRealizationV92(candidate_id, candidate_hash,
        String(topology["topology_hash"]), String(payload["genome_hash"]),
        String(payload["basis_hash"]), status, first_blocker, payload,
        realization_hash)
end

physical_realization_to_dict_v92(item::PhysicalRealizationV92) = deepcopy(item.payload)
