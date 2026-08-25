struct MechanismNativeGeometryResultV1
    compiler_version::String
    source_design_id::String
    source_physics_hash::String
    geometry_route::Symbol
    c1_route::Symbol
    reference_radius_m::Float64
    reference_half_length_m::Float64
    generated_parameter_count::Int
    geometry_primitives::Vector{Dict{String,Any}}
    derived_genome::Genome
    executable_genome::ExecutableGenomeV1
    executable_program::CompiledExecutablePhysicsProgramV1
    physics_problem::CompiledPhysicsProblemV1
    geometry_input_complete::Bool
    family_scramble_invariant::Bool
    c1_evidence_authorized::Bool
    evidence_tasks::Vector{String}
    result_hash::String
end

_geometry_quantity_v1(value, basis) = Dict{String,Any}(
    "value" => Float64(value), "unit" => "m", "basis" => String(basis))
_geometry_unitless_v1(value, basis) = Dict{String,Any}(
    "value" => Float64(value), "unit" => "1", "basis" => String(basis))

function _geometry_hash_unit_v1(hash::String, offset::Int)
    start = mod1(offset, 57)
    return parse(Int, hash[start:start + 7]; base = 16) / Float64(0xffffffff)
end

function _geometry_length_values_v1(genome::Genome, token::String)
    values = Float64[]
    components = vcat(genome.plasma_regions, genome.field_sources,
        genome.compression_systems)
    for component in components, (key, item) in component.parameters
        item.unit == "m" || continue
        occursin(token, lowercase(key)) || continue
        item.value > 0.0 && push!(values, item.value)
    end
    return values
end

function _geometry_reference_scales_v1(genome::Genome,
        c1_route::Symbol)
    radius_specific = vcat(_geometry_length_values_v1(genome, "plasma_radius"),
        _geometry_length_values_v1(genome, "minor_radius"),
        _geometry_length_values_v1(genome, "target_radius"),
        _geometry_length_values_v1(genome, "capsule_radius"))
    any_radius = _geometry_length_values_v1(genome, "radius")
    half_lengths = _geometry_length_values_v1(genome, "half_length")
    lengths = vcat(half_lengths, _geometry_length_values_v1(genome, "length"))
    if c1_route == :pulsed_drive_geometry
        radius = isempty(radius_specific) ?
            1.0e-3 * (1.0 + _geometry_hash_unit_v1(genome.physics_hash, 1)) :
            minimum(radius_specific)
        chamber = isempty(any_radius) ? 4.0 : maximum(any_radius)
        half_length = max(chamber, 4.0 * radius)
    else
        radius = !isempty(radius_specific) ? minimum(radius_specific) :
            !isempty(any_radius) ? minimum(any_radius) :
            0.2 + 0.8 * _geometry_hash_unit_v1(genome.physics_hash, 1)
        half_length = isempty(lengths) ?
            0.8 + 3.2 * _geometry_hash_unit_v1(genome.physics_hash, 11) :
            maximum(lengths)
    end
    return clamp(radius, 1.0e-4, 20.0), clamp(half_length, 1.0e-3, 50.0)
end

function _geometry_route_v1(genome::Genome,
        problem::CompiledPhysicsProblemV1)
    c1 = physics_c1_route_v2(genome)
    c1 == :pulsed_drive_geometry && begin
        text = lowercase(join(vcat(getfield.(genome.plasma_regions, :kind),
            getfield.(genome.plasma_regions, :geometry_model),
            getfield.(genome.compression_systems, :kind)), "|"))
        return occursin("cylind", text) ? :pulsed_cylindrical : :pulsed_spherical
    end
    c1 == :hybrid_magnetic_pulsed && return :hybrid_magnetic_pulsed
    topology = problem.topology
    topology.dimensionality in (:periodic_3d, :fully_3d) &&
        return :periodic_or_full_3d
    topology.closure_class == :open && return :linear_axisymmetric_open
    topology.closure_class in (:closed, :mixed) &&
        return :axisymmetric_toroidal
    return :general_3d
end

function _geometry_position_sign_v1(text::String, index::Int)
    occursin("left", text) && return -1.0
    occursin("right", text) && return 1.0
    occursin("end", text) || occursin("target", text) ||
        occursin("exhaust", text) || occursin("plug", text) ||
        occursin("divertor", text) || return 0.0
    return isodd(index) ? -1.0 : 1.0
end

function _add_generated_length_v1!(parameters::AbstractDict, key::String,
        value::Real, source_hash::String)
    haskey(parameters, key) && return 0
    parameters[key] = _geometry_quantity_v1(value,
        "exploratory mechanism-native geometry gene derived from $source_hash")
    return 1
end

function _complete_component_geometry_v1!(item::AbstractDict, index::Int,
        count::Int, route::Symbol, radius::Float64, half_length::Float64,
        source_hash::String; component_role::Symbol)
    parameters = item["parameters"]
    text = lowercase("$(item["id"])|$(item["kind"])|" *
        String(get(item, "geometry_model", "")))
    generated = 0
    if route in (:linear_axisymmetric_open, :hybrid_magnetic_pulsed)
        sign = _geometry_position_sign_v1(text, index)
        z = sign == 0.0 ? (index - (count + 1) / 2) *
            0.15 * half_length : sign * (1.1 + 0.25 * index) * half_length
        generated += _add_generated_length_v1!(parameters,
            "generated_center_position_r", 0.0, source_hash)
        generated += _add_generated_length_v1!(parameters,
            "generated_center_position_z", z, source_hash)
        generated += _add_generated_length_v1!(parameters,
            "generated_half_width_r", component_role == :field_source ?
                1.25 * radius : radius, source_hash)
        generated += _add_generated_length_v1!(parameters,
            "generated_half_width_z", 0.12 * half_length, source_hash)
    elseif route in (:axisymmetric_toroidal, :periodic_or_full_3d,
            :general_3d)
        major = max(3.0 * radius, half_length)
        generated += _add_generated_length_v1!(parameters,
            "generated_major_radius", major, source_hash)
        generated += _add_generated_length_v1!(parameters,
            "generated_minor_radius", component_role == :field_source ?
                1.3 * radius : radius, source_hash)
        generated += _add_generated_length_v1!(parameters,
            "generated_vertical_position",
            (index - (count + 1) / 2) * 0.12 * radius, source_hash)
        if route == :periodic_or_full_3d
            key = "generated_toroidal_phase_length"
            generated += _add_generated_length_v1!(parameters, key,
                major * 2.0 * pi * (index - 1) / max(count, 1), source_hash)
        end
    else
        outer = occursin("chamber", text) || occursin("wall", text) ?
            max(half_length, 10.0 * radius) :
            occursin("hotspot", text) ? 0.35 * radius : radius
        generated += _add_generated_length_v1!(parameters,
            "generated_center_position_x", 0.0, source_hash)
        generated += _add_generated_length_v1!(parameters,
            "generated_center_position_y", 0.0, source_hash)
        generated += _add_generated_length_v1!(parameters,
            "generated_center_position_z", 0.0, source_hash)
        generated += _add_generated_length_v1!(parameters,
            "generated_outer_radius", outer, source_hash)
        generated += _add_generated_length_v1!(parameters,
            "generated_shell_half_width", max(0.08 * outer, 1.0e-6),
            source_hash)
    end
    model = lowercase(String(get(item, "geometry_model", "")))
    if isempty(model) || any(token -> occursin(token, model),
            ("unmodeled", "unknown", "not_represented", "constraint_only"))
        item["geometry_model"] = "generated_$(route)_$(component_role)_primitive_v1"
    end
    return generated
end

function _complete_actuator_geometry_v1!(item::AbstractDict, index::Int,
        count::Int, route::Symbol, radius::Float64, half_length::Float64,
        source_hash::String)
    parameters = item["parameters"]
    generated = 0
    phase = 2.0 * pi * (index - 1) / max(count, 1)
    source_distance = route in (:pulsed_spherical, :pulsed_cylindrical,
        :hybrid_magnetic_pulsed) ? max(half_length, 20.0 * radius) : half_length
    generated += _add_generated_length_v1!(parameters,
        "generated_source_position_x", source_distance * cos(phase), source_hash)
    generated += _add_generated_length_v1!(parameters,
        "generated_source_position_y", source_distance * sin(phase), source_hash)
    generated += _add_generated_length_v1!(parameters,
        "generated_source_position_z", 0.0, source_hash)
    generated += _add_generated_length_v1!(parameters,
        "generated_target_position_x", 0.0, source_hash)
    generated += _add_generated_length_v1!(parameters,
        "generated_target_position_y", 0.0, source_hash)
    generated += _add_generated_length_v1!(parameters,
        "generated_target_position_z", 0.0, source_hash)
    return generated
end

function _geometry_module_raw_v1(id, role, domains, inputs, outputs,
        state_id, field_type, equation_class, equation_form, boundary_kind,
        capability_id, implementation_id, backend_status, dependencies,
        radius, source_ids)
    convergence_id = last(outputs)
    uncertainty_id = outputs[end - 1]
    return Dict{String,Any}(
        "id" => id, "role" => role, "domain_ids" => domains,
        "input_ids" => inputs, "output_ids" => outputs,
        "state_variables" => [Dict{String,Any}(
            "id" => state_id, "field_type" => field_type,
            "domain_ids" => domains, "species" => String[],
            "unit" => field_type == "geometry" ? "m" : "1",
            "time_behavior" => equation_class == "geometry" ? "static" :
                equation_class == "field_line" ? "static" : "transient")],
        "equations" => [Dict{String,Any}(
            "id" => "$(id)_equation", "equation_class" => equation_class,
            "form" => equation_form, "state_variable_ids" => [state_id],
            "input_ids" => inputs, "output_ids" => outputs,
            "closure_level" => "reduced_physics",
            "applicability_conditions" => ["candidate-specific geometry route"] )],
        "boundary_conditions" => [Dict{String,Any}(
            "id" => "$(id)_boundary", "domain_ids" => domains,
            "state_variable_id" => state_id, "kind" => boundary_kind,
            "data_input_ids" => String[])],
        "source_loss_terms" => [Dict{String,Any}(
            "id" => "$(id)_no_inferred_source", "kind" => "none",
            "conserved_quantities" => String[], "domain_ids" => domains,
            "input_ids" => String[], "output_ids" => String[])],
        "applicability_scales" => [Dict{String,Any}(
            "parameter_id" => "reference_radius", "lower_bound" => 0.0,
            "upper_bound" => nothing, "unit" => "m",
            "derivation" => "candidate geometry gene; reference $(radius) m",
            "status" => "derived")],
        "backend_requirements" => [Dict{String,Any}(
            "capability_id" => capability_id,
            "implementation_id" => implementation_id,
            "minimum_fidelity" => 1, "status" => backend_status,
            "required_input_ids" => inputs,
            "convergence_metric_ids" => [convergence_id],
            "uncertainty_output_ids" => [uncertainty_id])],
        "dependency_module_ids" => dependencies,
        "declaration_status" => "explicit", "source_ids" => source_ids)
end

function _native_geometry_executable_v1(genome::Genome, route::Symbol,
        radius::Float64)
    domains = sort!(vcat(getfield.(genome.plasma_regions, :id),
        getfield.(genome.field_sources, :id)))
    c1_route = physics_c1_route_v2(genome)
    modules = Dict{String,Any}[]
    source_ids = sort!(unique(vcat(genome.provenance.source_ids,
        ["mechanism_native_geometry_compiler_v1"])))
    if c1_route in (:magnetic_field_topology, :hybrid_magnetic_pulsed)
        push!(modules, _geometry_module_raw_v1(
            "candidate_geometry_maxwell_v1", "field", domains,
            ["all_field_source_geometry", "boundary_conditions"],
            ["geometry_layout", "magnetic_field_solution",
                "field_solution_uncertainty", "field_solution_converged"],
            "candidate_magnetic_geometry", "geometry", "maxwell", "pde",
            "conducting", "maxwell_magnetostatic_field_v1",
            "mechanism_native_maxwell_backend_pending", "planned", String[],
            radius, source_ids))
        push!(modules, _geometry_module_raw_v1(
            "candidate_field_line_topology_v1", "topology", domains,
            ["magnetic_field_solution", "all_plasma_region_geometry"],
            ["field_line_map", "connection_length",
                "topology_uncertainty", "field_line_topology_resolved"],
            "candidate_field_line_state", "tensor", "field_line", "ode",
            genome.topology.expected_flux_surfaces === true ?
                "periodic" : "open", "field_line_topology_trace_v1",
            "field_topology_backend_pending", "planned",
            ["candidate_geometry_maxwell_v1"], radius, source_ids))
    end
    if c1_route in (:pulsed_drive_geometry, :hybrid_magnetic_pulsed)
        pulse_dependencies = c1_route == :hybrid_magnetic_pulsed ?
            ["candidate_geometry_maxwell_v1"] : String[]
        push!(modules, _geometry_module_raw_v1(
            "candidate_pulsed_drive_geometry_v2", "coupling", domains,
            ["all_plasma_region_geometry", "all_actuator_geometry",
                "all_compression_geometry", "boundary_conditions"],
            ["drive_geometry", "target_geometry", "drive_source_map",
                "drive_geometry_uncertainty", "drive_geometry_resolved"],
            "candidate_pulsed_geometry", "geometry", "geometry", "constraint",
            "interface", "pulsed_drive_geometry_v2",
            "mechanism_native_geometry_compiler_v1", "available",
            pulse_dependencies, radius, source_ids))
        push!(modules, _geometry_module_raw_v1(
            "candidate_pulsed_radiation_hydrodynamics_v2", "equilibrium", domains,
            ["drive_geometry", "target_geometry", "drive_source_map",
                "thermodynamic_profiles", "material_properties"],
            ["compressed_state", "compression_gain", "mix_state",
                "hydrodynamic_uncertainty", "hydrodynamic_convergence"],
            "candidate_compressed_state", "tensor", "force_balance", "pde",
            "interface", "pulsed_radiation_hydrodynamics_v2",
            "radiation_hydrodynamics_backend_pending", "planned",
            ["candidate_pulsed_drive_geometry_v2"], radius, source_ids))
    end
    raw = Dict{String,Any}("schema_version" => "0.2.0",
        "base_genome_physics_hash" => genome.physics_hash,
        "physics_modules" => modules)
    return parse_executable_genome_v1(genome, raw)
end

"Generate explicit exploratory geometry genes and native C1-route modules from physical attributes."
function compile_mechanism_native_geometry_v1(genome::Genome)
    base_problem = compile_physics_problem_v2(genome)
    c1_route = physics_c1_route_v2(genome)
    route = _geometry_route_v1(genome, base_problem)
    radius, half_length = _geometry_reference_scales_v1(genome, c1_route)
    raw = deepcopy(genome.normalized)
    raw["design_id"] = "pending_mechanism_native_geometry_v1"
    generated = 0
    for (collection, role) in (("plasma_regions", :plasma_region),
            ("field_sources", :field_source))
        items = raw[collection]
        for (index, item) in enumerate(items)
            generated += _complete_component_geometry_v1!(item, index,
                length(items), route, radius, half_length, genome.physics_hash;
                component_role = role)
        end
    end
    actuators = get(raw, "actuators", Any[])
    for (index, item) in enumerate(actuators)
        generated += _complete_actuator_geometry_v1!(item, index,
            length(actuators), route, radius, half_length, genome.physics_hash)
    end
    systems = get(raw, "compression_systems", Any[])
    for (index, item) in enumerate(systems)
        generated += _complete_component_geometry_v1!(item, index,
            length(systems), route, radius, half_length, genome.physics_hash;
            component_role = :compression_system)
    end
    provenance = raw["provenance"]
    provenance["parent_design_ids"] = sort!(unique(vcat(
        String.(provenance["parent_design_ids"]), [genome.design_id])))
    provenance["source_ids"] = sort!(unique(vcat(
        String.(provenance["source_ids"]),
        ["mechanism_native_geometry_compiler_v1"])))
    provenance["notes"] = vcat(String.(provenance["notes"]), [
        "Explicit geometry values added by a deterministic exploratory generator; they are design genes, not measured or validated geometry.",
        "Geometry completion grants no field, topology, equilibrium, stability, transport, engineering or performance evidence."])
    provenance["claim_level"] = "exploratory_C0_geometry_candidate"
    provisional = parse_genome(raw)
    raw["design_id"] = "geomv1_$(genome.physics_hash[1:12])_$(provisional.physics_hash[1:12])"
    derived = parse_genome(raw)
    validation = validate_genome(derived)
    validation.valid || throw(ArgumentError("generated geometry Genome invalid: " *
        join(validation.errors, "; ")))
    problem = compile_physics_problem_v2(derived)
    executable = _native_geometry_executable_v1(derived, route, radius)
    program = compile_executable_physics_program_v2(executable)
    primitives = Dict{String,Any}[]
    for (role, collection) in (("plasma_region", derived.plasma_regions),
            ("field_source", derived.field_sources),
            ("compression_system", derived.compression_systems))
        for item in collection
            push!(primitives, Dict{String,Any}(
                "id" => item.id, "role" => role, "kind" => item.kind,
                "geometry_model" => item.geometry_model,
                "parameters" => _quantity_parameters_to_dict_v1(item.parameters)))
        end
    end
    required_geometry = String["all_plasma_region_geometry"]
    c1_route in (:magnetic_field_topology, :hybrid_magnetic_pulsed) &&
        push!(required_geometry, "all_field_source_geometry")
    c1_route in (:pulsed_drive_geometry, :hybrid_magnetic_pulsed) &&
        append!(required_geometry,
            ["all_actuator_geometry", "all_compression_geometry"])
    geometry_complete = all(id -> id in problem.domain.available_input_ids,
        required_geometry)
    scrambled_raw = deepcopy(derived.normalized)
    scrambled_raw["family"] = "diagnostic_scrambled_family_label"
    scrambled = parse_genome(scrambled_raw)
    scrambled_problem = compile_physics_problem_v2(scrambled)
    invariant = problem.physical_signature_hash ==
        scrambled_problem.physical_signature_hash &&
        problem.routing_hash == scrambled_problem.routing_hash
    tasks = String[]
    append!(tasks, "execute_backend:$id" for id in program.declared_operator_ids)
    append!(tasks, "declare_native_operator:$id" for id in
        program.uncovered_operator_ids)
    geometry_complete || push!(tasks, "repair_generated_geometry_inputs")
    core = Dict{String,Any}(
        "compiler_version" => "mechanism_native_geometry_compiler_v1.0.0",
        "source_design_id" => genome.design_id,
        "source_physics_hash" => genome.physics_hash,
        "geometry_route" => String(route), "c1_route" => String(c1_route),
        "reference_radius_m" => radius,
        "reference_half_length_m" => half_length,
        "generated_parameter_count" => generated,
        "derived_design_id" => derived.design_id,
        "derived_physics_hash" => derived.physics_hash,
        "geometry_input_complete" => geometry_complete,
        "family_scramble_invariant" => invariant,
        "program_hash" => program.program_hash,
        "c1_evidence_authorized" => false,
        "evidence_tasks" => sort!(unique(tasks)))
    return MechanismNativeGeometryResultV1(
        "mechanism_native_geometry_compiler_v1.0.0", genome.design_id,
        genome.physics_hash, route, c1_route, radius, half_length, generated,
        primitives, derived, executable, program, problem, geometry_complete,
        invariant, false, sort!(unique(tasks)), canonical_hash(core))
end

function mechanism_native_geometry_result_to_dict_v1(
        item::MechanismNativeGeometryResultV1)
    return Dict{String,Any}(
        "compiler_version" => item.compiler_version,
        "source_design_id" => item.source_design_id,
        "source_physics_hash" => item.source_physics_hash,
        "geometry_route" => String(item.geometry_route),
        "c1_route" => String(item.c1_route),
        "reference_radius_m" => item.reference_radius_m,
        "reference_half_length_m" => item.reference_half_length_m,
        "generated_parameter_count" => item.generated_parameter_count,
        "geometry_primitives" => item.geometry_primitives,
        "derived_genome" => item.derived_genome.normalized,
        "derived_design_id" => item.derived_genome.design_id,
        "derived_physics_hash" => item.derived_genome.physics_hash,
        "executable_genome" => executable_genome_to_dict_v1(item.executable_genome),
        "executable_program" => compiled_executable_program_to_dict_v1(
            item.executable_program),
        "physics_problem" => physics_problem_to_dict_v2(item.physics_problem,
            item.derived_genome),
        "geometry_input_complete" => item.geometry_input_complete,
        "family_scramble_invariant" => item.family_scramble_invariant,
        "c1_evidence_authorized" => item.c1_evidence_authorized,
        "evidence_tasks" => item.evidence_tasks,
        "claim_boundary" => "Generated geometry values are exploratory candidate genes, not evidence. Complete structural inputs only authorize solver execution tasks; C1 remains false until route-specific field/topology or pulsed-drive results converge with candidate-bound uncertainty.",
        "result_hash" => item.result_hash)
end
