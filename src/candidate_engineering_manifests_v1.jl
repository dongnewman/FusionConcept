const _CEM_V1_ALLOWED_STATUS = Set([:pass, :fail, :unknown, :unsupported])
const _CEM_V1_HASH_PATTERN = r"^[0-9a-fA-F]{64}$"

"Candidate-bound finite component geometry and load-transfer declaration."
struct EngineeringGeometryManifestV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    status::Symbol
    applicable_component_roles::Vector{String}
    applicability_basis::String
    components::Vector{Dict{String,Any}}
    load_mappings::Vector{Dict{String,Any}}
    contacts::Vector{Dict{String,Any}}
    insulation_boundaries::Vector{Dict{String,Any}}
    boundary_conditions::Vector{Dict{String,Any}}
    unresolved_reasons::Vector{String}
    manifest_hash::String
end

"Candidate-bound, versioned material curves with validity and uncertainty domains."
struct MaterialPropertyManifestV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    status::Symbol
    materials::Vector{Dict{String,Any}}
    unresolved_reasons::Vector{String}
    manifest_hash::String
end

"Candidate-bound engineering fault transients and their numerical acceptance metrics."
struct FaultScenarioManifestV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    status::Symbol
    applicable_fault_classes::Vector{String}
    applicability_basis::String
    scenarios::Vector{Dict{String,Any}}
    unresolved_reasons::Vector{String}
    manifest_hash::String
end

_cem_v1_dict(value) = value isa AbstractDict ?
    Dict{String,Any}(String(key) => _csr_v1_json_safe(item) for (key, item) in value) :
    Dict{String,Any}()
_cem_v1_vector(value) = value isa AbstractVector ?
    Dict{String,Any}[_cem_v1_dict(item) for item in value if item isa AbstractDict] :
    Dict{String,Any}[]
_cem_v1_strings(value) = value isa AbstractVector ? sort!(unique(String.(value))) : String[]
_cem_v1_hash(value) = value isa AbstractString && occursin(_CEM_V1_HASH_PATTERN, String(value))
_cem_v1_finite(value) = value isa Real && isfinite(Float64(value))
_cem_v1_positive(value) = _cem_v1_finite(value) && Float64(value) > 0.0

function _cem_v1_missing!(reasons, value::AbstractDict, keys, context)
    for key in keys
        haskey(value, key) || push!(reasons, "$context missing $key")
    end
end

function _cem_v1_unique_ids!(reasons, records, key, context)
    ids = String[]
    for (index, record) in enumerate(records)
        if !haskey(record, key) || isempty(strip(String(get(record, key, ""))))
            push!(reasons, "$context[$index] missing $key")
        else
            push!(ids, String(record[key]))
        end
    end
    length(ids) == length(unique(ids)) || push!(reasons, "$context $key values must be unique")
    return Set(ids)
end

function _cem_v1_engineering_body(genome, status, roles, applicability_basis, components, mappings, contacts,
        insulation, boundaries, reasons)
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "candidate_id" => genome.design_id,
        "physics_hash" => genome.physics_hash, "status" => String(status),
        "applicable_component_roles" => roles, "applicability_basis" => applicability_basis,
        "components" => components,
        "load_mappings" => mappings, "contacts" => contacts,
        "insulation_boundaries" => insulation, "boundary_conditions" => boundaries,
        "unresolved_reasons" => sort!(unique(reasons)),
        "routing_basis" => "explicit candidate engineering declarations only",
        "generated_nominal" => false)
end

"Compile finite geometry without inventing an applicable role, dimension, material, or boundary."
function compile_engineering_geometry_manifest_v1(genome::Genome)
    raw = get(genome.normalized, "engineering_geometry_manifest_v1", nothing)
    if !(raw isa AbstractDict)
        reasons = ["missing explicit engineering_geometry_manifest_v1 declaration"]
        body = _cem_v1_engineering_body(genome, :unknown, String[], "",
            Dict{String,Any}[], Dict{String,Any}[], Dict{String,Any}[],
            Dict{String,Any}[], Dict{String,Any}[], reasons)
        hash = canonical_hash(body)
        return EngineeringGeometryManifestV1("1.0.0", genome.design_id,
            genome.physics_hash, :unknown, String[], "", Dict{String,Any}[],
            Dict{String,Any}[], Dict{String,Any}[], Dict{String,Any}[],
            Dict{String,Any}[], reasons, hash)
    end
    declaration = _cem_v1_dict(raw)
    reasons = String[]
    _cem_v1_missing!(reasons, declaration,
        ("applicable_component_roles", "components", "load_mappings", "contacts",
         "insulation_boundaries", "boundary_conditions"), "engineering geometry manifest")
    roles = _cem_v1_strings(get(declaration, "applicable_component_roles", Any[]))
    applicability_basis = String(get(declaration, "not_applicable_basis", ""))
    isempty(roles) && isempty(strip(applicability_basis)) && push!(reasons,
        "engineering geometry manifest must explicitly declare applicable_component_roles")
    components = _cem_v1_vector(get(declaration, "components", Any[]))
    mappings = _cem_v1_vector(get(declaration, "load_mappings", Any[]))
    contacts = _cem_v1_vector(get(declaration, "contacts", Any[]))
    insulation = _cem_v1_vector(get(declaration, "insulation_boundaries", Any[]))
    boundaries = _cem_v1_vector(get(declaration, "boundary_conditions", Any[]))
    component_ids = _cem_v1_unique_ids!(reasons, components, "component_id", "components")
    represented_roles = Set{String}()
    for (index, component) in enumerate(components)
        context = "components[$index]"
        _cem_v1_missing!(reasons, component,
            ("component_id", "component_role", "material_id", "finite_geometry", "features"),
            context)
        role = String(get(component, "component_role", ""))
        isempty(role) || push!(represented_roles, role)
        role in roles || push!(reasons, "$context role $role is not declared applicable")
        geometry = _cem_v1_dict(get(component, "finite_geometry", nothing))
        _cem_v1_missing!(reasons, geometry,
            ("representation", "geometry_hash", "mesh_hash", "mesh_dimension", "measure"),
            "$context finite_geometry")
        _cem_v1_hash(get(geometry, "geometry_hash", nothing)) ||
            push!(reasons, "$context geometry_hash must be a sha256 hash")
        _cem_v1_hash(get(geometry, "mesh_hash", nothing)) ||
            push!(reasons, "$context mesh_hash must be a sha256 hash")
        dimension = get(geometry, "mesh_dimension", nothing)
        dimension isa Integer && Int(dimension) in (1, 2, 3) ||
            push!(reasons, "$context mesh_dimension must be 1, 2, or 3")
        measure = _cem_v1_dict(get(geometry, "measure", nothing))
        _cem_v1_missing!(reasons, measure, ("value", "unit"), "$context measure")
        _cem_v1_positive(get(measure, "value", nothing)) ||
            push!(reasons, "$context finite geometry measure must be positive")
        features = get(component, "features", nothing)
        features isa AbstractVector && !isempty(features) ||
            push!(reasons, "$context must explicitly describe winding/support/channel/duct/surface features")
    end
    for role in roles
        role in represented_roles || push!(reasons, "applicable component role $role has no finite component")
    end
    region_ids = Set(item.id for item in genome.plasma_regions)
    _cem_v1_unique_ids!(reasons, mappings, "mapping_id", "load_mappings")
    for (index, mapping) in enumerate(mappings)
        context = "load_mappings[$index]"
        _cem_v1_missing!(reasons, mapping,
            ("mapping_id", "source_region_id", "source_load_slot", "target_component_id",
             "mapping_operator_id", "jacobian_operator_id", "sign_convention", "unit"), context)
        String(get(mapping, "source_region_id", "")) in region_ids ||
            push!(reasons, "$context references an unknown plasma region")
        String(get(mapping, "target_component_id", "")) in component_ids ||
            push!(reasons, "$context references an unknown component")
    end
    for (records, id_key, context) in ((contacts, "contact_id", "contacts"),
            (insulation, "boundary_id", "insulation_boundaries"),
            (boundaries, "boundary_id", "boundary_conditions"))
        _cem_v1_unique_ids!(reasons, records, id_key, context)
    end
    for (index, contact) in enumerate(contacts)
        _cem_v1_missing!(reasons, contact,
            ("contact_id", "component_a", "component_b", "contact_model_id",
             "physics_slots", "jacobian_operator_id"), "contacts[$index]")
        for key in ("component_a", "component_b")
            String(get(contact, key, "")) in component_ids ||
                push!(reasons, "contacts[$index] references an unknown $key")
        end
    end
    for (index, boundary) in enumerate(insulation)
        _cem_v1_missing!(reasons, boundary,
            ("boundary_id", "component_id", "insulation_material_id", "thickness_m",
             "breakdown_field_v_per_m", "boundary_operator_id"), "insulation_boundaries[$index]")
        String(get(boundary, "component_id", "")) in component_ids ||
            push!(reasons, "insulation_boundaries[$index] references an unknown component")
        _cem_v1_positive(get(boundary, "thickness_m", nothing)) ||
            push!(reasons, "insulation_boundaries[$index] thickness_m must be positive")
        _cem_v1_positive(get(boundary, "breakdown_field_v_per_m", nothing)) ||
            push!(reasons, "insulation_boundaries[$index] breakdown field must be positive")
    end
    for (index, boundary) in enumerate(boundaries)
        _cem_v1_missing!(reasons, boundary,
            ("boundary_id", "component_id", "physics", "condition_type",
             "boundary_operator_id", "jacobian_operator_id"), "boundary_conditions[$index]")
        String(get(boundary, "component_id", "")) in component_ids ||
            push!(reasons, "boundary_conditions[$index] references an unknown component")
    end
    status = isempty(reasons) ? :pass : :unsupported
    body = _cem_v1_engineering_body(genome, status, roles, applicability_basis, components, mappings,
        contacts, insulation, boundaries, reasons)
    hash = canonical_hash(body)
    return EngineeringGeometryManifestV1("1.0.0", genome.design_id, genome.physics_hash,
        status, roles, applicability_basis, components, mappings, contacts, insulation, boundaries,
        sort!(unique(reasons)), hash)
end

function _cem_v1_material_body(genome, status, materials, reasons)
    return Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => genome.design_id, "physics_hash" => genome.physics_hash,
        "status" => String(status), "materials" => materials,
        "unresolved_reasons" => sort!(unique(reasons)),
        "generated_nominal" => false)
end

"Compile versioned material property curves; a material name alone is never a property model."
function compile_material_property_manifest_v1(genome::Genome)
    raw = get(genome.normalized, "material_property_manifest_v1", nothing)
    if !(raw isa AbstractDict)
        reasons = ["missing explicit material_property_manifest_v1 declaration"]
        body = _cem_v1_material_body(genome, :unknown, Dict{String,Any}[], reasons)
        return MaterialPropertyManifestV1("1.0.0", genome.design_id,
            genome.physics_hash, :unknown, Dict{String,Any}[], reasons, canonical_hash(body))
    end
    declaration = _cem_v1_dict(raw)
    reasons = String[]
    _cem_v1_missing!(reasons, declaration, ("materials",), "material property manifest")
    materials = _cem_v1_vector(get(declaration, "materials", Any[]))
    material_ids = _cem_v1_unique_ids!(reasons, materials, "material_id", "materials")
    isempty(material_ids) && push!(reasons, "material property manifest declares no materials")
    for (mindex, material) in enumerate(materials)
        context = "materials[$mindex]"
        _cem_v1_missing!(reasons, material,
            ("material_id", "grade", "version", "data_source_refs", "data_hash",
             "applicable_property_ids", "properties"), context)
        _cem_v1_hash(get(material, "data_hash", nothing)) ||
            push!(reasons, "$context data_hash must be a sha256 hash")
        refs = get(material, "data_source_refs", nothing)
        refs isa AbstractVector && !isempty(refs) ||
            push!(reasons, "$context must cite at least one data source")
        applicable = _cem_v1_strings(get(material, "applicable_property_ids", Any[]))
        isempty(applicable) && push!(reasons, "$context must declare applicable_property_ids")
        properties = _cem_v1_vector(get(material, "properties", Any[]))
        property_ids = _cem_v1_unique_ids!(reasons, properties, "property_id", "$context properties")
        for property_id in applicable
            property_id in property_ids ||
                push!(reasons, "$context applicable property $property_id has no curve")
        end
        for (pindex, property) in enumerate(properties)
            pcontext = "$context properties[$pindex]"
            _cem_v1_missing!(reasons, property,
                ("property_id", "unit", "independent_variables", "representation",
                 "curve_data", "validity_ranges", "uncertainty", "source_refs", "data_hash"),
                pcontext)
            variables = _cem_v1_strings(get(property, "independent_variables", Any[]))
            all(variable -> variable in ("temperature", "magnetic_field", "strain", "dpa",
                "helium_production", "cycle_count", "frequency", "pressure"), variables) ||
                push!(reasons, "$pcontext has an unsupported independent variable")
            _cem_v1_hash(get(property, "data_hash", nothing)) ||
                push!(reasons, "$pcontext data_hash must be a sha256 hash")
            ranges = _cem_v1_dict(get(property, "validity_ranges", nothing))
            for variable in variables
                range = _cem_v1_dict(get(ranges, variable, nothing))
                _cem_v1_missing!(reasons, range, ("minimum", "maximum", "unit"),
                    "$pcontext validity range $variable")
                minimum = get(range, "minimum", nothing)
                maximum = get(range, "maximum", nothing)
                _cem_v1_finite(minimum) && _cem_v1_finite(maximum) &&
                    Float64(minimum) < Float64(maximum) ||
                    push!(reasons, "$pcontext validity range $variable is not finite and ordered")
            end
            uncertainty = _cem_v1_dict(get(property, "uncertainty", nothing))
            _cem_v1_missing!(reasons, uncertainty, ("kind", "value", "unit"),
                "$pcontext uncertainty")
            _cem_v1_finite(get(uncertainty, "value", nothing)) &&
                Float64(uncertainty["value"]) >= 0.0 ||
                push!(reasons, "$pcontext uncertainty must be finite and nonnegative")
            source_refs = get(property, "source_refs", nothing)
            source_refs isa AbstractVector && !isempty(source_refs) ||
                push!(reasons, "$pcontext must cite source_refs")
            curve = get(property, "curve_data", nothing)
            curve isa AbstractDict && !isempty(curve) ||
                push!(reasons, "$pcontext curve_data cannot be empty")
        end
    end
    status = isempty(reasons) ? :pass : :unsupported
    body = _cem_v1_material_body(genome, status, materials, reasons)
    return MaterialPropertyManifestV1("1.0.0", genome.design_id, genome.physics_hash,
        status, materials, sort!(unique(reasons)), canonical_hash(body))
end

function _cem_v1_fault_body(genome, status, classes, applicability_basis, scenarios, reasons)
    return Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => genome.design_id, "physics_hash" => genome.physics_hash,
        "status" => String(status), "applicable_fault_classes" => classes,
        "applicability_basis" => applicability_basis,
        "scenarios" => scenarios, "unresolved_reasons" => sort!(unique(reasons)),
        "nominal_only" => false, "generated_nominal" => false)
end

"Compile fault timelines and gates; nominal operation is not synthesized as a fault case."
function compile_fault_scenario_manifest_v1(genome::Genome)
    raw = get(genome.normalized, "fault_scenario_manifest_v1", nothing)
    if !(raw isa AbstractDict)
        reasons = ["missing explicit fault_scenario_manifest_v1 declaration"]
        body = _cem_v1_fault_body(genome, :unknown, String[], "", Dict{String,Any}[], reasons)
        return FaultScenarioManifestV1("1.0.0", genome.design_id,
            genome.physics_hash, :unknown, String[], "", Dict{String,Any}[], reasons,
            canonical_hash(body))
    end
    declaration = _cem_v1_dict(raw)
    reasons = String[]
    _cem_v1_missing!(reasons, declaration,
        ("applicable_fault_classes", "scenarios"), "fault scenario manifest")
    classes = _cem_v1_strings(get(declaration, "applicable_fault_classes", Any[]))
    applicability_basis = String(get(declaration, "not_applicable_basis", ""))
    isempty(classes) && isempty(strip(applicability_basis)) && push!(reasons,
        "fault scenario manifest must explicitly declare applicable_fault_classes")
    scenarios = _cem_v1_vector(get(declaration, "scenarios", Any[]))
    _cem_v1_unique_ids!(reasons, scenarios, "scenario_id", "scenarios")
    represented = Set{String}()
    for (index, scenario) in enumerate(scenarios)
        context = "scenarios[$index]"
        _cem_v1_missing!(reasons, scenario,
            ("scenario_id", "fault_class", "applicability_basis",
             "initial_operating_point_hash", "target_component_ids", "trigger", "protection_actions", "timeline",
             "required_solver_capabilities", "acceptance_metrics"), context)
        fault_class = String(get(scenario, "fault_class", ""))
        isempty(fault_class) || push!(represented, fault_class)
        fault_class in classes || push!(reasons, "$context fault class $fault_class is not applicable")
        _cem_v1_hash(get(scenario, "initial_operating_point_hash", nothing)) ||
            push!(reasons, "$context initial_operating_point_hash must be a sha256 hash")
        targets = get(scenario, "target_component_ids", nothing)
        targets isa AbstractVector && !isempty(targets) ||
            push!(reasons, "$context must declare target_component_ids")
        trigger = _cem_v1_dict(get(scenario, "trigger", nothing))
        _cem_v1_missing!(reasons, trigger,
            ("event_type", "time_s", "event_operator_id"), "$context trigger")
        _cem_v1_finite(get(trigger, "time_s", nothing)) && Float64(trigger["time_s"]) >= 0.0 ||
            push!(reasons, "$context trigger time_s must be finite and nonnegative")
        capabilities = get(scenario, "required_solver_capabilities", nothing)
        capabilities isa AbstractVector && !isempty(capabilities) ||
            push!(reasons, "$context must declare required_solver_capabilities")
        actions = _cem_v1_vector(get(scenario, "protection_actions", Any[]))
        isempty(actions) && push!(reasons, "$context must declare protection actions")
        for (aindex, action) in enumerate(actions)
            _cem_v1_missing!(reasons, action,
                ("action_id", "start_time_s", "action_operator_id", "capacity_limit"),
                "$context protection_actions[$aindex]")
            _cem_v1_finite(get(action, "start_time_s", nothing)) &&
                Float64(action["start_time_s"]) >= 0.0 ||
                push!(reasons, "$context protection action start time must be nonnegative")
        end
        timeline = get(scenario, "timeline", nothing)
        timeline isa AbstractVector && length(timeline) >= 2 ||
            push!(reasons, "$context timeline must contain at least two time samples")
        if timeline isa AbstractVector && all(_cem_v1_finite, timeline)
            times = Float64.(timeline)
            issorted(times) && length(times) == length(unique(times)) ||
                push!(reasons, "$context timeline must be strictly increasing")
        end
        metrics = _cem_v1_vector(get(scenario, "acceptance_metrics", Any[]))
        isempty(metrics) && push!(reasons, "$context must declare peak or integral acceptance metrics")
        _cem_v1_unique_ids!(reasons, metrics, "metric_id", "$context acceptance_metrics")
        for (mindex, metric) in enumerate(metrics)
            mcontext = "$context acceptance_metrics[$mindex]"
            _cem_v1_missing!(reasons, metric,
                ("metric_id", "observable_id", "statistic", "comparison", "threshold",
                 "unit", "location"), mcontext)
            String(get(metric, "statistic", "")) in ("peak", "minimum", "integral", "duration") ||
                push!(reasons, "$mcontext statistic must be peak, minimum, integral, or duration")
            String(get(metric, "comparison", "")) in ("<=", "<", ">=", ">") ||
                push!(reasons, "$mcontext comparison is unsupported")
            _cem_v1_finite(get(metric, "threshold", nothing)) ||
                push!(reasons, "$mcontext threshold must be finite")
        end
    end
    for fault_class in classes
        fault_class in represented ||
            push!(reasons, "applicable fault class $fault_class has no scenario")
    end
    status = isempty(reasons) ? :pass : :unsupported
    body = _cem_v1_fault_body(genome, status, classes, applicability_basis, scenarios, reasons)
    return FaultScenarioManifestV1("1.0.0", genome.design_id, genome.physics_hash,
        status, classes, applicability_basis, scenarios, sort!(unique(reasons)), canonical_hash(body))
end

function engineering_geometry_manifest_to_dict_v1(value::EngineeringGeometryManifestV1)
    body = Dict{String,Any}("schema_version" => value.schema_version,
        "candidate_id" => value.candidate_id, "physics_hash" => value.physics_hash,
        "status" => String(value.status),
        "applicable_component_roles" => value.applicable_component_roles,
        "applicability_basis" => value.applicability_basis,
        "components" => value.components, "load_mappings" => value.load_mappings,
        "contacts" => value.contacts, "insulation_boundaries" => value.insulation_boundaries,
        "boundary_conditions" => value.boundary_conditions,
        "unresolved_reasons" => value.unresolved_reasons,
        "routing_basis" => "explicit candidate engineering declarations only",
        "generated_nominal" => false, "manifest_hash" => value.manifest_hash)
    return body
end

function material_property_manifest_to_dict_v1(value::MaterialPropertyManifestV1)
    return Dict{String,Any}("schema_version" => value.schema_version,
        "candidate_id" => value.candidate_id, "physics_hash" => value.physics_hash,
        "status" => String(value.status), "materials" => value.materials,
        "unresolved_reasons" => value.unresolved_reasons,
        "generated_nominal" => false, "manifest_hash" => value.manifest_hash)
end

function fault_scenario_manifest_to_dict_v1(value::FaultScenarioManifestV1)
    return Dict{String,Any}("schema_version" => value.schema_version,
        "candidate_id" => value.candidate_id, "physics_hash" => value.physics_hash,
        "status" => String(value.status),
        "applicable_fault_classes" => value.applicable_fault_classes,
        "applicability_basis" => value.applicability_basis,
        "scenarios" => value.scenarios, "unresolved_reasons" => value.unresolved_reasons,
        "nominal_only" => false, "generated_nominal" => false,
        "manifest_hash" => value.manifest_hash)
end

"Compile and cross-audit all three v63 engineering declarations."
function compile_candidate_engineering_manifests_v1(genome::Genome)
    geometry = compile_engineering_geometry_manifest_v1(genome)
    materials = compile_material_property_manifest_v1(genome)
    faults = compile_fault_scenario_manifest_v1(genome)
    reasons = vcat(geometry.unresolved_reasons, materials.unresolved_reasons,
        faults.unresolved_reasons)
    material_ids = Set(String(item["material_id"]) for item in materials.materials
        if haskey(item, "material_id"))
    for component in geometry.components
        material_id = String(get(component, "material_id", ""))
        component_id = String(get(component, "component_id", "unknown"))
        material_id in material_ids ||
            push!(reasons, "component $component_id references missing material $material_id")
    end
    for boundary in geometry.insulation_boundaries
        material_id = String(get(boundary, "insulation_material_id", ""))
        boundary_id = String(get(boundary, "boundary_id", "unknown"))
        material_id in material_ids ||
            push!(reasons, "insulation boundary $boundary_id references missing material $material_id")
    end
    component_ids = Set(String(item["component_id"]) for item in geometry.components
        if haskey(item, "component_id"))
    for scenario in faults.scenarios, target in get(scenario, "target_component_ids", Any[])
        target_id = String(target)
        target_id in component_ids ||
            push!(reasons, "fault scenario $(get(scenario, "scenario_id", "unknown")) references missing component $target_id")
    end
    statuses = (geometry.status, materials.status, faults.status)
    status = any(==(:unsupported), statuses) ? :unsupported :
        all(==(:pass), statuses) && isempty(reasons) ? :pass : :unknown
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => genome.design_id, "physics_hash" => genome.physics_hash,
        "status" => String(status), "geometry_manifest_hash" => geometry.manifest_hash,
        "material_manifest_hash" => materials.manifest_hash,
        "fault_manifest_hash" => faults.manifest_hash,
        "unresolved_reasons" => sort!(unique(reasons)),
        "family_routing_used" => false, "generated_nominal" => false)
    body["bundle_hash"] = canonical_hash(body)
    return Dict{String,Any}("geometry" => geometry, "materials" => materials,
        "faults" => faults, "status" => status,
        "unresolved_reasons" => body["unresolved_reasons"],
        "bundle_hash" => body["bundle_hash"])
end
