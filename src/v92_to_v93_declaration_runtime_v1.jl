const V93_PVW_PROTOCOL_ID = "fusionconceptai-v93-pvw-slice1-20260828"
const V92_TO_V93_DECLARATION_CLAIM_BOUNDARY =
    "A regenerated declaration makes every state, equation, region, interface, validity domain, and evidence gap explicit. Unknown or recompute-required values do not satisfy solver capability completeness."

_v93_value(value, status, source) = Dict{String,Any}(
    "value" => value, "status" => status, "source" => source)

function _v93_profile_by_id(realization, id)
    matches = [profile for profile in get(realization, "profiles", Any[]) if
        String(get(profile, "profile_id", "")) == id]
    isempty(matches) ? nothing : first(matches)
end

function _v93_surface_by_id(realization, id)
    matches = [surface for surface in get(realization, "oriented_surfaces", Any[]) if
        String(get(surface, "surface_id", "")) == id]
    isempty(matches) ? nothing : first(matches)
end

function _v93_region_geometry(realization, region)
    kind = String(region["region_type"])
    surface_ids = kind == "plasma" ? ["plasma-boundary"] :
        kind == "wall" ? ["wall-inner", "wall-outer"] :
        kind == "coil" ? ["coil-envelope-inner", "coil-envelope-outer"] :
        kind == "open_loss" ? ["open-source-cap", "open-terminal-cap"] : String[]
    surfaces = Any[_v93_surface_by_id(realization, id) for id in surface_ids]
    filter!(!isnothing, surfaces)
    Dict{String,Any}(
        "coordinate_map" => get(region, "coordinate_map", nothing),
        "radial_extent_normalized" => get(region, "radial_extent_normalized", nothing),
        "length_m" => get(region, "length_m", nothing),
        "surfaces" => surfaces,
        "volume_mesh_levels" => get(realization, "volume_meshes", Any[]),
        "wall_mesh_levels" => kind == "wall" ? get(realization, "wall_meshes", Any[]) : Any[],
        "materialized_coordinates_status" => "must_recompute",
        "partition_status" => "must_recompute")
end

function _v93_region_material(realization, kind)
    if kind == "plasma"
        return Dict{String,Any}(
            "vacuum_permeability_h_per_m" => _v93_value(4pi * 1e-7, "physical_constant", "SI"),
            "pressure_profile" => _v93_value(_v93_profile_by_id(realization, "pressure"), "recovered", "v92.profiles"),
            "density_profile" => _v93_value(_v93_profile_by_id(realization, "density"), "recovered", "v92.profiles"),
            "temperature_profile" => _v93_value(_v93_profile_by_id(realization, "temperature"), "recovered", "v92.profiles"),
            "current_profile" => _v93_value(_v93_profile_by_id(realization, "current"), "recovered", "v92.profiles"),
            "transport_coefficients" => _v93_value(nothing, "must_recompute", "candidate_bound_closure"))
    elseif kind == "vacuum"
        return Dict("vacuum_permeability_h_per_m" => _v93_value(4pi * 1e-7, "physical_constant", "SI"))
    elseif kind == "coil"
        return Dict("field_sources" => _v93_value(get(realization, "field_sources", Any[]), "recovered", "v92.field_sources"),
            "electrical_resistivity_ohm_m" => _v93_value(nothing, "requires_external_evidence", "material_record"),
            "thermal_and_mechanical_properties" => _v93_value(nothing, "requires_external_evidence", "material_record"))
    elseif kind == "wall"
        return Dict("electrical_resistivity_ohm_m" => _v93_value(nothing, "requires_external_evidence", "material_record"),
            "relative_permeability" => _v93_value(nothing, "requires_external_evidence", "material_record"),
            "wall_model" => _v93_value(nothing, "must_recompute", "thin_or_volume_wall_choice"))
    elseif kind == "open_loss"
        return Dict("parallel_transport_closure" => _v93_value(nothing, "must_recompute", "candidate_bound_open_field_model"),
            "collision_and_charge_exchange_data" => _v93_value(nothing, "requires_external_evidence", "atomic_and_material_data"))
    else
        return Dict("terminal_sheath_and_recycling" => _v93_value(nothing, "must_recompute", "candidate_bound_terminal_model"))
    end
end

function _v93_boundaries_for_region(kind)
    if kind == "plasma"
        return [Dict("condition_id" => "plasma_vacuum_trace", "status" => "derived",
            "surface_id" => "plasma-boundary"),
            Dict("condition_id" => "open_source_terminal_if_declared", "status" => "derived",
                "surface_id" => "open-source-cap")]
    elseif kind == "vacuum"
        return [Dict("condition_id" => "plasma_vacuum_trace", "status" => "derived",
            "surface_id" => "plasma-boundary"),
            Dict("condition_id" => "vacuum_wall_trace", "status" => "derived",
                "surface_id" => "wall-inner")]
    elseif kind == "wall"
        return [Dict("condition_id" => "vacuum_wall_trace", "status" => "derived",
            "surface_id" => "wall-inner"), Dict("condition_id" => "wall_outer_boundary",
            "status" => "must_recompute", "surface_id" => "wall-outer")]
    elseif kind == "coil"
        return [Dict("condition_id" => "coil_envelope_inner", "status" => "derived",
            "surface_id" => "coil-envelope-inner"), Dict("condition_id" => "coil_envelope_outer",
            "status" => "derived", "surface_id" => "coil-envelope-outer")]
    elseif kind == "open_loss"
        return [Dict("condition_id" => "open_source", "status" => "derived", "surface_id" => "open-source-cap"),
            Dict("condition_id" => "open_terminal", "status" => "derived", "surface_id" => "open-terminal-cap")]
    end
    [Dict("condition_id" => "absorbing_terminal", "status" => "must_recompute",
        "surface_id" => "open-terminal-cap")]
end

function _v93_state!(states, region_id, state, units, space; status = "must_recompute")
    push!(states, Dict{String,Any}("state_id" => "$(region_id).$(state)",
        "physical_state" => state, "region_id" => region_id, "units" => units,
        "space" => space, "components" => state in ("magnetic_field", "current_density", "flow_velocity") ? 3 : 1,
        "value_status" => status))
end

function _v93_equation!(equations, region_id, suffix, owner, units, governing;
        additive = String[], jacobian = String[owner], conserved = String[], validity = Dict{String,Any}())
    push!(equations, Dict{String,Any}(
        "equation_id" => "$(region_id).$(suffix)", "region_id" => region_id,
        "state_owner" => "$(region_id).$(owner)", "units" => units,
        "governing_operator" => governing, "additive_operators" => additive,
        "jacobian_blocks" => ["$(region_id).$(item)" for item in jacobian],
        "conserved_quantities" => conserved, "validity_domain" => validity,
        "source_citation" => default_operator_registry_v93()[governing].source_citation,
        "coefficient_status" => "must_recompute"))
end

function _v93_full_states_equations(regions, declared_operators)
    states = Dict{String,Any}[]; equations = Dict{String,Any}[]
    operator_set = Set(String.(declared_operators))
    for region in regions
        id = String(region["region_id"]); kind = String(region["region_type"])
        if kind == "plasma"
            _v93_state!(states, id, "magnetic_field", "T", "H_div")
            _v93_state!(states, id, "current_density", "A m^-2", "H_div")
            _v93_state!(states, id, "pressure", "Pa", "H1")
            _v93_state!(states, id, "density", "kg m^-3", "H1")
            _v93_state!(states, id, "species_temperature", "K", "H1")
            _v93_state!(states, id, "flow_velocity", "m s^-1", "H1_vector")
            _v93_state!(states, id, "electric_potential", "V", "H1")
            _v93_equation!(equations, id, "divB", "magnetic_field", "T m^-1",
                "solenoidal_magnetic_constraint"; conserved = ["magnetic_flux"],
                validity = Dict("materialized_mesh_required" => true))
            _v93_equation!(equations, id, "ampere", "current_density", "A m^-2",
                "ampere_field_source_consistency"; jacobian = ["magnetic_field", "current_density"],
                conserved = ["electric_current", "magnetic_flux"])
            additives = String[]
            "cross_field_transport" in operator_set && push!(additives, "material_transport_closure")
            _v93_equation!(equations, id, "force", "pressure", "N m^-3",
                "declared_force_balance"; additive = additives,
                jacobian = ["pressure", "magnetic_field", "current_density", "flow_velocity"],
                conserved = ["momentum"], validity = Dict("positive_pressure" => true,
                    "closure_coefficients_required" => true))
            if any(op -> op in operator_set, ("particle_balance", "parallel_transport", "cross_field_transport"))
                _v93_equation!(equations, id, "particle", "density", "kg m^-3 s^-1",
                    "particle_conservation"; additive = ["material_transport_closure"],
                    conserved = ["particles_by_species"])
            end
            if any(op -> op in operator_set, ("energy_balance", "reaction_radiation"))
                _v93_equation!(equations, id, "energy", "species_temperature", "W m^-3",
                    "energy_conservation"; additive = ["source_sink_terminal_addition"],
                    conserved = ["energy_by_species"])
            end
        elseif kind == "vacuum"
            _v93_state!(states, id, "vacuum_field", "T", "H_curl")
            _v93_equation!(equations, id, "maxwell", "vacuum_field", "A m^-2",
                "vacuum_field_equations"; conserved = ["magnetic_flux"])
        elseif kind == "coil"
            _v93_state!(states, id, "coil_current", "A", "R"; status = "recovered")
            _v93_equation!(equations, id, "circuit", "coil_current", "V",
                "coil_circuit_coupling"; conserved = ["magnetic_flux", "energy"])
        elseif kind == "wall"
            _v93_state!(states, id, "wall_current", "A m^-1", "surface_H_div")
            _v93_equation!(equations, id, "wall_em", "wall_current", "V m^-1",
                "wall_electromagnetic_coupling"; conserved = ["electric_charge", "magnetic_flux", "energy"])
        elseif kind == "open_loss"
            _v93_state!(states, id, "density", "kg m^-3", "H1")
            _v93_state!(states, id, "species_temperature", "K", "H1")
            _v93_state!(states, id, "flow_velocity", "m s^-1", "H1_vector")
            _v93_equation!(equations, id, "particle", "density", "kg m^-3 s^-1",
                "particle_conservation"; additive = ["material_transport_closure", "source_sink_terminal_addition"],
                conserved = ["particles_by_species"])
            _v93_equation!(equations, id, "energy", "species_temperature", "W m^-3",
                "energy_conservation"; additive = ["material_transport_closure", "source_sink_terminal_addition"],
                conserved = ["energy_by_species"])
        else
            _v93_state!(states, id, "density", "kg m^-3", "L2")
            _v93_equation!(equations, id, "terminal_particle", "density", "kg m^-2 s^-1",
                "particle_conservation"; additive = ["source_sink_terminal_addition"],
                conserved = ["particles_by_species"])
        end
    end
    states, equations
end

function _v93_physical_interfaces(regions)
    ids = Dict(String(region["region_type"]) => String(region["region_id"]) for region in regions)
    rows = Dict{String,Any}[]
    if all(haskey(ids, key) for key in ("plasma", "vacuum"))
        push!(rows, Dict("interface_id" => "plasma-vacuum", "minus_region_id" => ids["plasma"],
            "plus_region_id" => ids["vacuum"], "geometry" => Dict("surface_id" => "plasma-boundary",
                "status" => "derived"), "conditions" => [
                Dict("condition_id" => "normal_magnetic_flux_continuity"),
                Dict("condition_id" => "tangential_field_jump_surface_current"),
                Dict("condition_id" => "total_traction_balance")],
            "coupling_method" => "lagrange_multiplier", "multiplier_space" => "mortar_dual"))
    end
    if all(haskey(ids, key) for key in ("vacuum", "wall"))
        push!(rows, Dict("interface_id" => "vacuum-wall", "minus_region_id" => ids["vacuum"],
            "plus_region_id" => ids["wall"], "geometry" => Dict("surface_id" => "wall-inner",
                "status" => "derived"), "conditions" => [
                Dict("condition_id" => "normal_magnetic_flux_continuity"),
                Dict("condition_id" => "tangential_field_jump_surface_current"),
                Dict("condition_id" => "current_continuity")],
            "coupling_method" => "lagrange_multiplier", "multiplier_space" => "mortar_dual"))
    end
    if all(haskey(ids, key) for key in ("plasma", "open_loss"))
        push!(rows, Dict("interface_id" => "plasma-open-loss", "minus_region_id" => ids["plasma"],
            "plus_region_id" => ids["open_loss"], "geometry" => Dict("surface_id" => "open-source-cap",
                "status" => "derived"), "conditions" => [Dict("condition_id" => "particle_flux_balance"),
                Dict("condition_id" => "energy_flux_balance"), Dict("condition_id" => "current_continuity")],
            "coupling_method" => "mortar", "multiplier_space" => "mortar_dual"))
    end
    if all(haskey(ids, key) for key in ("open_loss", "terminal"))
        push!(rows, Dict("interface_id" => "open-loss-terminal", "minus_region_id" => ids["open_loss"],
            "plus_region_id" => ids["terminal"], "geometry" => Dict("surface_id" => "open-terminal-cap",
                "status" => "derived"), "conditions" => [Dict("condition_id" => "particle_flux_balance"),
                Dict("condition_id" => "energy_flux_balance"), Dict("condition_id" => "source_sink_terminal_condition")],
            "coupling_method" => "mortar", "multiplier_space" => "mortar_dual"))
    end
    rows
end

function regenerate_complete_v93_declaration_v1(v91_raw, v92_raw)
    v91 = _v93_plain(v91_raw); v92 = _v93_plain(v92_raw)
    String(v91["dossier_hash"]) == String(v92["candidate_hash"]) ||
        throw(ArgumentError("v91/v92 provenance hash mismatch"))
    topology = Dict{String,Any}(v91["genome"]["topology"])
    applicability = Dict{String,Any}(v92["applicability_obligations"])
    regions = Dict{String,Any}[]
    for source in get(v92, "regions", Any[])
        kind = String(source["region_type"]); id = String(source["region_id"])
        push!(regions, Dict{String,Any}("region_id" => id, "region_type" => kind,
            "dimension" => Int(source["dimension"]), "geometry_fields" => _v93_region_geometry(v92, source),
            "material_fields" => _v93_region_material(v92, kind),
            "boundary_conditions" => _v93_boundaries_for_region(kind)))
    end
    states, equations = _v93_full_states_equations(regions, get(applicability, "declared_operators", Any[]))
    interfaces = _v93_physical_interfaces(regions)
    recompute = String["materialized_mesh_coordinates_and_connectivity", "mesh_partition",
        "candidate_bound_magnetic_field", "candidate_bound_current_density", "free_boundary_geometry",
        "dp_dpsi_on_solved_flux", "F_dF_dpsi_on_solved_flux", "wall_and_coil_response",
        "residual_jacobian_and_conservation_metrics"]
    operators = Set(String.(get(applicability, "declared_operators", Any[])))
    any(op -> op in operators, ("parallel_transport", "cross_field_transport")) && push!(recompute, "transport_coefficients")
    any(op -> op in operators, ("reaction_radiation", "particle_balance", "energy_balance")) && push!(recompute, "source_sink_rates")
    "terminal_balance" in operators && push!(recompute, "terminal_sheath_state")
    external = ["wall_material_properties", "coil_material_properties", "diagnostic_measurements",
        "experimental_uncertainty", "model_discrepancy", "candidate_domain_applicability"]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V93_PVW_PROTOCOL_ID,
        "source_provenance" => Dict("source_protocol_id" => v92["protocol_id"],
            "source_realization_hash" => v92["realization_hash"], "source_dossier_hash" => v91["dossier_hash"],
            "topology_hash" => topology["topology_hash"]),
        "regions" => regions, "states" => states, "equations" => equations,
        "interfaces" => interfaces,
        "sources_sinks" => [Dict("source_id" => "candidate_sources_and_sinks",
            "status" => "must_recompute", "declared_operator_inputs" => sort!(collect(operators)))],
        "model_validity_domains" => [Dict("domain_id" => "full_multiregion_candidate_domain",
            "status" => "must_recompute", "required" => ["geometry_domain", "material_domain",
                "closure_domain", "state_domain"])],
        "evidence_obligations" => String.(get(applicability, "evidence_obligations", Any[])),
        "discretization" => Dict("form" => "not_yet_bound", "monolithic_residual" => false,
            "domain_decomposition" => false, "mesh_levels" => ["coarse", "medium", "fine"],
            "source_mesh_hashes" => [mesh["mesh_hash"] for mesh in get(v92, "volume_meshes", Any[])]),
        "topology_declaration" => Dict("nodes" => topology["nodes"], "interfaces" => topology["interfaces"]),
        "recovery_inventory" => Dict("directly_recovered" => ["topology", "basis", "regions", "surfaces",
            "mesh_level_shapes_and_hashes", "field_sources", "profiles", "initial_conditions", "evidence_obligations"],
            "deterministically_derived" => ["state_ownership", "equation_inventory", "physical_interface_binding",
                "boundary_inventory", "residual_metadata"], "must_recompute" => sort!(unique(recompute)),
            "requires_external_evidence" => external),
        "declaration_completeness" => Dict("schema_complete" => true, "solver_complete" => false,
            "must_recompute_count" => length(unique(recompute)), "external_evidence_gap_count" => length(external)),
        "claim_boundary" => V92_TO_V93_DECLARATION_CLAIM_BOUNDARY)
    physics = deepcopy(body); delete!(physics, "source_provenance"); delete!(physics, "claim_boundary")
    delete!(physics, "topology_declaration")
    body["declaration_hash"] = canonical_hash(physics)
    body
end

function route_pvw_slice_v1(declaration_raw)
    d = _v93_plain(declaration_raw)
    region_types = sort!(unique(String(region["region_type"]) for region in d["regions"]))
    physical_states = sort!(unique(String(state["physical_state"]) for state in d["states"]))
    operators = sort!(unique(String(equation["governing_operator"]) for equation in d["equations"]))
    blockers = String[]
    isempty(setdiff(Set(region_types), Set(["plasma", "vacuum", "wall"]))) ||
        push!(blockers, "extra_region_types_outside_slice")
    isempty(setdiff(Set(physical_states), Set(["poloidal_flux", "radial_flux_gradient", "pressure"]))) ||
        push!(blockers, "extra_state_variables_outside_slice")
    isempty(setdiff(Set(operators), Set(["solenoidal_magnetic_constraint", "ampere_field_source_consistency",
        "declared_force_balance", "vacuum_field_equations"]))) ||
        push!(blockers, "extra_governing_operators_outside_slice")
    get(d["declaration_completeness"], "solver_complete", false) === true ||
        push!(blockers, "solver_parameters_or_discretization_incomplete")
    coordinate = get(d, "coordinate_reduction", nothing)
    coordinate == "axisymmetric_cylindrical_radial_reduction" ||
        push!(blockers, "radial_axisymmetric_reduction_not_attested")
    route_body = Dict{String,Any}("protocol_id" => V93_PVW_PROTOCOL_ID,
        "declaration_hash" => d["declaration_hash"], "region_types" => region_types,
        "physical_states" => physical_states, "governing_operators" => operators,
        "status" => isempty(blockers) ? "pass" : "unsupported_operator_or_backend",
        "blockers" => blockers, "subproblem_projection_used" => false,
        "access_audit" => ["region_types", "physical_states", "governing_operators",
            "declaration_completeness", "coordinate_reduction"])
    route_body["route_hash"] = canonical_hash(route_body)
    route_body
end
