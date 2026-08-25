const _PHYSICS_COMPILER_STATUSES_V1 = Set((:ready, :blocked_unknown_inputs))
const _PHYSICS_CRITERION_STATUSES_V1 = Set((:pass, :fail, :unknown))

"A device-name-independent summary of the magnetic domain declared by a Genome."
struct PhysicalTopologyDescriptorV1
    closure_class::Symbol
    dimensionality::Symbol
    symmetry_class::String
    field_periods::Int
    expected_flux_surfaces::Union{Nothing,Bool}
    expected_separatrix::Union{Nothing,Bool}
    open_end_count::Int
    transform_sources::Vector{String}
    field_source_kinds::Vector{String}
    plasma_region_kinds::Vector{String}
end

"Executable-physics inputs extracted from the typed Genome without inventing missing data."
struct PhysicsDomainIRV1
    region_ids::Vector{String}
    source_ids::Vector{String}
    connection_kinds::Vector{String}
    boundary_condition_ids::Vector{String}
    state_variable_ids::Vector{String}
    source_term_ids::Vector{String}
    loss_term_ids::Vector{String}
    available_input_ids::Set{String}
    missing_input_ids::Vector{String}
end

"A composable physics operator selected from physical attributes, never from family."
struct PhysicsOperatorSpecV1
    id::String
    category::Symbol
    minimum_fidelity::Int
    activation_rule::String
    required_inputs::Vector{String}
    output_ids::Vector{String}
    empirical_prior::Bool
    promotion_authority::Bool
end

struct CompiledPhysicsOperatorV1
    spec::PhysicsOperatorSpecV1
    status::Symbol
    missing_input_ids::Vector{String}

    function CompiledPhysicsOperatorV1(spec::PhysicsOperatorSpecV1,
            status::Symbol, missing_input_ids::Vector{String})
        status in _PHYSICS_COMPILER_STATUSES_V1 ||
            throw(ArgumentError("invalid compiled operator status $status"))
        return new(spec, status, sort!(unique(missing_input_ids)))
    end
end

struct ConservationBalanceSpecV1
    conserved_quantity::String
    species::Vector{String}
    source_ids::Vector{String}
    loss_ids::Vector{String}
    status::Symbol
    missing_input_ids::Vector{String}
end

struct PhysicsEvidenceTaskV1
    id::String
    reason::String
    required_input_ids::Vector{String}
    unlocks_operator_ids::Vector{String}
end

struct CompiledPhysicsProblemV1
    compiler_version::String
    design_id::String
    source_family_label::String
    genome_physics_hash::String
    topology::PhysicalTopologyDescriptorV1
    domain::PhysicsDomainIRV1
    operators::Vector{CompiledPhysicsOperatorV1}
    conservation_balances::Vector{ConservationBalanceSpecV1}
    evidence_tasks::Vector{PhysicsEvidenceTaskV1}
    structural_validation::ValidationReport
    physical_signature_hash::String
    routing_hash::String
    claim_ceiling::String
end

"One non-compensating axis in the simplicity/stability/output standard."
struct PhysicsCriterionResultV1
    id::String
    status::Symbol
    observed_metric_ids::Vector{String}
    failed_metric_ids::Vector{String}
    unknown_metric_ids::Vector{String}

    function PhysicsCriterionResultV1(id::AbstractString, status::Symbol,
            observed_metric_ids, failed_metric_ids, unknown_metric_ids)
        status in _PHYSICS_CRITERION_STATUSES_V1 ||
            throw(ArgumentError("invalid criterion status $status"))
        return new(String(id), status,
            sort!(unique(String.(collect(observed_metric_ids)))),
            sort!(unique(String.(collect(failed_metric_ids)))),
            sort!(unique(String.(collect(unknown_metric_ids)))))
    end
end

struct PhysicsAssessmentV1
    design_id::String
    criteria::Vector{PhysicsCriterionResultV1}
    component_observations::Dict{String,Any}
    hard_gate_status::Symbol
    highest_evidence_stage::String
    promotion_authorized::Bool
    evidence_tasks::Vector{PhysicsEvidenceTaskV1}
    assessment_hash::String
end

function _closure_class_v1(genome::Genome)
    kinds = Set(connection.kind for connection in genome.flux_connections)
    declared = lowercase(genome.topology.field_line_class)
    has_open = any(kind -> occursin("open", lowercase(kind)), kinds) ||
        occursin("open", declared)
    has_closed = occursin("closed", declared) || occursin("toroidal", declared) ||
        occursin("compact_toroid", declared)
    declared == "mixed" && return :mixed
    return has_open && has_closed ? :mixed : has_open ? :open :
        has_closed ? :closed : :unknown
end

function _dimensionality_v1(genome::Genome)
    genome.symmetry.class == "axisymmetric" && return :axisymmetric_2d
    genome.symmetry.field_periods > 1 && return :periodic_3d
    any(source -> occursin("three_dimensional", lowercase(source.kind)) ||
            occursin("3d", lowercase(source.geometry_model)), genome.field_sources) &&
        return :fully_3d
    return :general_3d
end

function _topology_descriptor_v1(genome::Genome)
    open_end_count = count(connection ->
        occursin("open", lowercase(connection.kind)), genome.flux_connections)
    return PhysicalTopologyDescriptorV1(
        _closure_class_v1(genome), _dimensionality_v1(genome),
        genome.symmetry.class, genome.symmetry.field_periods,
        genome.topology.expected_flux_surfaces,
        genome.topology.expected_separatrix,
        open_end_count,
        sort!(unique(copy(genome.topology.rotation_transform_sources))),
        sort!(unique(source.kind for source in genome.field_sources)),
        sort!(unique(region.kind for region in genome.plasma_regions)),
    )
end

function _has_coordinate_content_v1(parameters::Dict{String,Quantity})
    keys_lower = lowercase.(collect(keys(parameters)))
    tokens = ("radius", "position", "domain_", "boundary_", "coefficient",
        "half_width", "rmin", "rmax", "zmin", "zmax", "length")
    return any(key -> any(token -> occursin(token, key), tokens), keys_lower)
end

function _region_geometry_available_v1(region::PlasmaRegion)
    model = lowercase(region.geometry_model)
    any(token -> occursin(token, model),
        ("unmodeled", "outside", "constraint_only", "unknown")) && return false
    return _has_coordinate_content_v1(region.parameters) ||
        startswith(model, "desc_builtin_")
end

function _source_geometry_available_v1(source::FieldSource)
    model = lowercase(source.geometry_model)
    any(token -> occursin(token, model),
        ("unmodeled", "not_represented", "unknown")) && return false
    return _has_coordinate_content_v1(source.parameters)
end

function _profile_inputs_v1(genome::Genome)
    parameter_names = lowercase.(vcat(
        [collect(keys(region.parameters)) for region in genome.plasma_regions]...,
        [collect(keys(source.parameters)) for source in genome.field_sources]...))
    available = Set{String}()
    any(key -> occursin("pressure", key), parameter_names) &&
        push!(available, "pressure_profile")
    any(key -> occursin("current", key), parameter_names) &&
        push!(available, "current_profile")
    any(key -> occursin("density", key), parameter_names) &&
        push!(available, "density_profile")
    any(key -> occursin("temperature", key), parameter_names) &&
        push!(available, "temperature_profile")
    return available
end

function _boundary_conditions_v1(genome::Genome, topology::PhysicalTopologyDescriptorV1)
    result = String[]
    topology.dimensionality in (:periodic_3d, :fully_3d) &&
        push!(result, "field_periodicity")
    topology.expected_flux_surfaces === true && push!(result, "magnetic_surface_boundary")
    topology.expected_separatrix === true && push!(result, "separatrix_boundary")
    for connection in genome.flux_connections
        push!(result, "connection:$(connection.kind):$(connection.from_region_id)->$(connection.to_region_id)")
    end
    isempty(result) && push!(result, "boundary_conditions_unknown")
    return sort!(unique(result))
end

function _species_v1(fuel::String)
    normalized = uppercase(replace(fuel, " " => ""))
    normalized in ("D-T", "DT") &&
        return ["electron", "deuterium", "tritium", "alpha", "neutron"]
    normalized in ("D-D", "DD") &&
        return ["electron", "deuterium", "tritium", "helium3", "proton", "neutron"]
    return ["electron", "ion_unspecified"]
end

function _domain_ir_v1(genome::Genome, topology::PhysicalTopologyDescriptorV1)
    available = _profile_inputs_v1(genome)
    missing = String[]
    for region in genome.plasma_regions
        input = "plasma_region_geometry:$(region.id)"
        _region_geometry_available_v1(region) ? push!(available, input) : push!(missing, input)
    end
    source_geometry_complete = true
    for source in genome.field_sources
        input = "field_source_geometry:$(source.id)"
        if _source_geometry_available_v1(source)
            push!(available, input)
        else
            source_geometry_complete = false
            push!(missing, input)
        end
    end
    source_geometry_complete && push!(available, "all_field_source_geometry")
    all(_region_geometry_available_v1, genome.plasma_regions) &&
        push!(available, "all_plasma_region_geometry")
    !isempty(genome.flux_connections) && push!(available, "declared_flux_connections")
    !isempty(genome.engineering.magnet_technology) &&
        push!(available, "magnet_technology_declaration")
    genome.engineering.blanket_concept !== nothing && push!(available, "blanket_model")
    !isempty(genome.engineering.access_paths) && push!(available, "maintenance_access_declaration")

    boundary_ids = _boundary_conditions_v1(genome, topology)
    "boundary_conditions_unknown" in boundary_ids || push!(available, "boundary_conditions")
    state_variables = ["magnetic_field", "electric_field", "current_density",
        "species_density", "species_momentum", "species_energy"]
    source_terms = sort!(unique(vcat(
        ["magnetic_source:$(source.id)" for source in genome.field_sources],
        ["actuator_source:$(actuator.id)" for actuator in genome.actuators],
        ["fusion_reaction_source", "radiation_source"])))
    loss_terms = sort!(unique(vcat(
        ["exhaust_loss:$(item)" for item in genome.exhaust.evaluation_requirements],
        ["transport_loss", "orbit_loss", "radiation_loss"])))
    append!(missing, ["thermodynamic_profiles", "particle_distribution",
        "wall_geometry", "material_properties", "power_conversion_model"])
    return PhysicsDomainIRV1(
        sort!(getfield.(genome.plasma_regions, :id)),
        sort!(getfield.(genome.field_sources, :id)),
        sort!(unique(getfield.(genome.flux_connections, :kind))),
        boundary_ids, state_variables, source_terms, loss_terms,
        available, sort!(unique(filter(id -> !(id in available), missing))))
end

function default_physics_operator_registry_v1()
    spec(id, category, fidelity, rule, inputs, outputs;
            empirical_prior = false, promotion_authority = true) =
        PhysicsOperatorSpecV1(id, category, fidelity, rule,
            String.(inputs), String.(outputs), empirical_prior, promotion_authority)
    return PhysicsOperatorSpecV1[
        spec("maxwell_magnetostatic_field_v1", :field, 1, "any magnetic source",
            ["all_field_source_geometry", "boundary_conditions"],
            ["magnetic_field_solution", "field_energy"]),
        spec("field_line_topology_trace_v1", :topology, 1, "any magnetic topology",
            ["magnetic_field_solution", "all_plasma_region_geometry"],
            ["field_line_map", "connection_length", "stochastic_fraction"]),
        spec("closed_flux_surface_analysis_v1", :topology, 1, "closed or mixed field lines",
            ["field_line_map"], ["flux_surface_existence", "rotational_transform", "magnetic_shear"]),
        spec("open_field_connection_analysis_v1", :topology, 1, "open or mixed field lines",
            ["field_line_map", "declared_flux_connections"],
            ["open_end_connectivity", "end_connection_length", "loss_cone_geometry"]),
        spec("separatrix_and_xpoint_analysis_v1", :topology, 1, "declared separatrix",
            ["magnetic_field_solution", "all_plasma_region_geometry"],
            ["separatrix_geometry", "xpoint_geometry"]),
        spec("axisymmetric_current_equilibrium_v1", :equilibrium, 2,
            "axisymmetry plus plasma-current transform plus closed field lines",
            ["magnetic_field_solution", "pressure_profile", "current_profile", "boundary_conditions"],
            ["force_balance_residual", "equilibrium_state"]),
        spec("three_dimensional_mhd_equilibrium_v1", :equilibrium, 2,
            "non-axisymmetric closed or mixed field lines",
            ["magnetic_field_solution", "pressure_profile", "boundary_conditions"],
            ["force_balance_residual", "equilibrium_state"]),
        spec("open_field_finite_beta_equilibrium_v1", :equilibrium, 2,
            "open or mixed field lines",
            ["magnetic_field_solution", "pressure_profile", "particle_distribution", "boundary_conditions"],
            ["force_balance_residual", "equilibrium_state", "pressure_anisotropy"]),
        spec("guiding_center_orbit_following_v1", :transport, 2, "any magnetic topology",
            ["magnetic_field_solution", "particle_distribution", "wall_geometry"],
            ["orbit_loss_fraction", "radial_drift", "loss_location_map"]),
        spec("topology_conditioned_transport_v1", :transport, 2, "any solved field topology",
            ["field_line_map", "equilibrium_state", "thermodynamic_profiles"],
            ["particle_loss_power", "energy_loss_power", "momentum_loss_rate"]),
        spec("applicable_mode_stability_spectrum_v1", :stability, 2,
            "mode set derived from local curvature, shear, closure, profiles, and distribution",
            ["equilibrium_state", "field_line_map", "thermodynamic_profiles", "particle_distribution"],
            ["minimum_stability_margin", "unstable_mode_ids"]),
        spec("species_conservation_ledger_v1", :conservation, 2, "all concepts",
            ["thermodynamic_profiles", "particle_distribution"],
            ["particle_balance_residual", "energy_balance_residual", "momentum_balance_residual", "current_balance_residual"]),
        spec("fusion_radiation_power_kernel_v1", :production, 2, "all fusion fuels",
            ["thermodynamic_profiles", "all_plasma_region_geometry"],
            ["fusion_power", "neutron_power", "charged_particle_power", "radiation_power"]),
        spec("magnet_force_stress_and_build_v1", :engineering, 2, "any field source",
            ["magnetic_field_solution", "material_properties", "all_field_source_geometry"],
            ["peak_field", "coil_force", "coil_stress", "minimum_coil_separation", "stored_magnetic_energy"]),
        spec("wall_blanket_exhaust_balance_v1", :engineering, 3, "all concepts",
            ["loss_location_map", "wall_geometry", "material_properties"],
            ["peak_heat_flux", "wall_load", "blanket_power", "tritium_breeding_ratio"]),
        spec("net_electric_and_availability_ledger_v1", :production, 3, "reactor or pilot mission",
            ["fusion_power", "radiation_power", "particle_loss_power", "energy_loss_power",
                "power_conversion_model", "maintenance_access_declaration"],
            ["recirculating_power", "net_electric_power", "availability"]),
        spec("ipb98_calibration_prior_v1", :calibration_prior, 0,
            "axisymmetric closed field with plasma-current transform",
            ["thermodynamic_profiles"], ["confinement_prior"],
            empirical_prior = true, promotion_authority = false),
        spec("iss04_calibration_prior_v1", :calibration_prior, 0,
            "non-axisymmetric closed field with external-field transform",
            ["thermodynamic_profiles", "field_line_map"], ["confinement_prior"],
            empirical_prior = true, promotion_authority = false),
        spec("classical_open_end_loss_prior_v1", :calibration_prior, 0,
            "open field lines with explicit ends", ["particle_distribution", "field_line_map"],
            ["end_loss_prior"], empirical_prior = true, promotion_authority = false),
    ]
end

function _operator_active_v1(spec::PhysicsOperatorSpecV1,
        topology::PhysicalTopologyDescriptorV1, genome::Genome)
    id = spec.id
    closure = topology.closure_class
    nonaxisymmetric = topology.dimensionality != :axisymmetric_2d
    plasma_current_transform = "plasma_current" in topology.transform_sources
    external_transform = "three_dimensional_external_field" in topology.transform_sources
    id == "closed_flux_surface_analysis_v1" && return closure in (:closed, :mixed)
    id == "open_field_connection_analysis_v1" && return closure in (:open, :mixed)
    id == "separatrix_and_xpoint_analysis_v1" &&
        return topology.expected_separatrix === true
    id == "axisymmetric_current_equilibrium_v1" &&
        return topology.dimensionality == :axisymmetric_2d &&
            plasma_current_transform && closure in (:closed, :mixed)
    id == "three_dimensional_mhd_equilibrium_v1" &&
        return nonaxisymmetric && closure in (:closed, :mixed)
    id == "open_field_finite_beta_equilibrium_v1" && return closure in (:open, :mixed)
    id == "ipb98_calibration_prior_v1" &&
        return topology.dimensionality == :axisymmetric_2d &&
            plasma_current_transform && closure == :closed
    id == "iss04_calibration_prior_v1" &&
        return nonaxisymmetric && external_transform && closure == :closed
    id == "classical_open_end_loss_prior_v1" &&
        return closure in (:open, :mixed) && topology.open_end_count > 0
    id == "net_electric_and_availability_ledger_v1" &&
        return genome.mission.kind == "net_electric_pilot" ||
            genome.engineering.blanket_required
    return id in ("maxwell_magnetostatic_field_v1", "field_line_topology_trace_v1",
        "guiding_center_orbit_following_v1", "topology_conditioned_transport_v1",
        "applicable_mode_stability_spectrum_v1", "species_conservation_ledger_v1",
        "fusion_radiation_power_kernel_v1", "magnet_force_stress_and_build_v1",
        "wall_blanket_exhaust_balance_v1")
end

function _resolve_operators_v1(genome::Genome, topology::PhysicalTopologyDescriptorV1,
        domain::PhysicsDomainIRV1, registry::Vector{PhysicsOperatorSpecV1})
    active = filter(spec -> _operator_active_v1(spec, topology, genome), registry)
    produced_by = Dict{String,String}()
    for spec in active, output in spec.output_ids
        get!(produced_by, output, spec.id)
    end
    available = copy(domain.available_input_ids)
    compiled = CompiledPhysicsOperatorV1[]
    # Fixed-point scheduling marks outputs of structurally ready operators available.
    remaining = copy(active)
    while !isempty(remaining)
        progressed = false
        next_remaining = PhysicsOperatorSpecV1[]
        for spec in remaining
            missing = sort!(String[input for input in spec.required_inputs if !(input in available)])
            if isempty(missing)
                push!(compiled, CompiledPhysicsOperatorV1(spec, :ready, String[]))
                union!(available, spec.output_ids)
                progressed = true
            else
                push!(next_remaining, spec)
            end
        end
        if !progressed
            for spec in next_remaining
                missing = sort!(String[input for input in spec.required_inputs if !(input in available)])
                push!(compiled, CompiledPhysicsOperatorV1(spec, :blocked_unknown_inputs, missing))
            end
            break
        end
        remaining = next_remaining
    end
    sort!(compiled; by = item -> item.spec.id)
    return compiled
end

function _conservation_balances_v1(genome::Genome, domain::PhysicsDomainIRV1)
    species = _species_v1(genome.mission.fuel)
    missing = sort!(String[input for input in
        ("thermodynamic_profiles", "particle_distribution")
        if !(input in domain.available_input_ids)])
    status = isempty(missing) ? :ready : :blocked_unknown_inputs
    balances = ConservationBalanceSpecV1[]
    for quantity in ("particle", "energy", "momentum", "current", "magnetic_flux")
        push!(balances, ConservationBalanceSpecV1(quantity, copy(species),
            copy(domain.source_term_ids), copy(domain.loss_term_ids), status, copy(missing)))
    end
    return balances
end

function _evidence_tasks_v1(operators::Vector{CompiledPhysicsOperatorV1})
    by_missing = Dict{String,Vector{String}}()
    for operator in operators, input in operator.missing_input_ids
        push!(get!(by_missing, input, String[]), operator.spec.id)
    end
    tasks = PhysicsEvidenceTaskV1[
        PhysicsEvidenceTaskV1("acquire:$input",
            "Required physical input is absent; keep every dependent result unknown.",
            [input], sort!(unique(operator_ids)))
        for (input, operator_ids) in sort!(collect(by_missing); by = first)
    ]
    for operator in operators
        operator.status == :ready || continue
        operator.spec.empirical_prior && continue
        push!(tasks, PhysicsEvidenceTaskV1("execute:$(operator.spec.id)",
            "Inputs are structurally available, but an actual solver result is still required.",
            String[], [operator.spec.id]))
    end
    sort!(tasks; by = item -> item.id)
    return tasks
end

function _topology_to_dict_v1(item::PhysicalTopologyDescriptorV1)
    return Dict{String,Any}(
        "closure_class" => String(item.closure_class),
        "dimensionality" => String(item.dimensionality),
        "symmetry_class" => item.symmetry_class,
        "field_periods" => item.field_periods,
        "expected_flux_surfaces" => item.expected_flux_surfaces,
        "expected_separatrix" => item.expected_separatrix,
        "open_end_count" => item.open_end_count,
        "transform_sources" => item.transform_sources,
        "field_source_kinds" => item.field_source_kinds,
        "plasma_region_kinds" => item.plasma_region_kinds)
end

function _domain_to_dict_v1(item::PhysicsDomainIRV1)
    return Dict{String,Any}(
        "region_ids" => item.region_ids,
        "source_ids" => item.source_ids,
        "connection_kinds" => item.connection_kinds,
        "boundary_condition_ids" => item.boundary_condition_ids,
        "state_variable_ids" => item.state_variable_ids,
        "source_term_ids" => item.source_term_ids,
        "loss_term_ids" => item.loss_term_ids,
        "available_input_ids" => sort!(collect(item.available_input_ids)),
        "missing_input_ids" => item.missing_input_ids)
end

function _operator_to_dict_v1(item::CompiledPhysicsOperatorV1)
    spec = item.spec
    return Dict{String,Any}(
        "id" => spec.id, "category" => String(spec.category),
        "minimum_fidelity" => spec.minimum_fidelity,
        "activation_rule" => spec.activation_rule,
        "required_inputs" => spec.required_inputs,
        "output_ids" => spec.output_ids,
        "empirical_prior" => spec.empirical_prior,
        "promotion_authority" => spec.promotion_authority,
        "status" => String(item.status),
        "missing_input_ids" => item.missing_input_ids)
end

function _balance_to_dict_v1(item::ConservationBalanceSpecV1)
    return Dict{String,Any}(
        "conserved_quantity" => item.conserved_quantity,
        "species" => item.species,
        "source_ids" => item.source_ids,
        "loss_ids" => item.loss_ids,
        "status" => String(item.status),
        "missing_input_ids" => item.missing_input_ids)
end

function _quantity_parameters_to_dict_v1(parameters::Dict{String,Quantity})
    return Dict{String,Any}(key => Dict{String,Any}(
        "value" => quantity.value, "unit" => quantity.unit)
        for (key, quantity) in parameters)
end

function _physical_signature_payload_v1(genome::Genome,
        topology::PhysicalTopologyDescriptorV1, domain::PhysicsDomainIRV1,
        operators::Vector{CompiledPhysicsOperatorV1},
        balances::Vector{ConservationBalanceSpecV1})
    regions = [Dict{String,Any}(
        "kind" => item.kind,
        "geometry_model" => item.geometry_model,
        "parameters" => _quantity_parameters_to_dict_v1(item.parameters))
        for item in genome.plasma_regions]
    sources = [Dict{String,Any}(
        "kind" => item.kind,
        "geometry_model" => item.geometry_model,
        "parameters" => _quantity_parameters_to_dict_v1(item.parameters),
        "material" => item.material)
        for item in genome.field_sources]
    actuators = [Dict{String,Any}(
        "kind" => item.kind,
        "parameters" => _quantity_parameters_to_dict_v1(item.parameters))
        for item in genome.actuators]
    mechanisms = [Dict{String,Any}(
        "mechanism" => item.mechanism,
        "target_modes" => sort!(copy(item.target_modes)))
        for item in genome.stability_mechanisms]
    sort_by_hash(items) = sort!(items; by = canonical_hash)
    available_classes = sort!(String[
        startswith(input, "plasma_region_geometry:") ? "plasma_region_geometry" :
        startswith(input, "field_source_geometry:") ? "field_source_geometry" : input
        for input in domain.available_input_ids])
    missing_classes = sort!(String[
        startswith(input, "plasma_region_geometry:") ? "plasma_region_geometry" :
        startswith(input, "field_source_geometry:") ? "field_source_geometry" : input
        for input in domain.missing_input_ids])
    boundary_classes = sort!(String[
        startswith(item, "connection:") ? join(split(item, ':')[1:2], ':') : item
        for item in domain.boundary_condition_ids])
    balance_contracts = [Dict{String,Any}(
        "conserved_quantity" => item.conserved_quantity,
        "species" => item.species,
        "source_term_classes" => sort!(unique(first(split(source, ':'))
            for source in item.source_ids)),
        "loss_term_classes" => sort!(unique(first(split(loss, ':'))
            for loss in item.loss_ids)),
        "status" => String(item.status),
        "missing_input_ids" => item.missing_input_ids)
        for item in balances]
    return Dict{String,Any}(
        "mission" => Dict{String,Any}(
            "kind" => genome.mission.kind,
            "fuel" => genome.mission.fuel,
            "operating_mode" => genome.mission.operating_mode,
            "targets" => _quantity_parameters_to_dict_v1(genome.mission.targets)),
        "topology" => _topology_to_dict_v1(topology),
        "region_physics" => sort_by_hash(regions),
        "field_source_physics" => sort_by_hash(sources),
        "actuator_physics" => sort_by_hash(actuators),
        "stability_mechanisms" => sort_by_hash(mechanisms),
        "connection_kinds" => domain.connection_kinds,
        "boundary_condition_classes" => boundary_classes,
        "state_variable_ids" => domain.state_variable_ids,
        "available_input_classes" => sort!(unique(available_classes)),
        "missing_input_classes" => sort!(unique(missing_classes)),
        "operator_ids" => [item.spec.id for item in operators],
        "operator_dependencies" => Dict(item.spec.id => item.spec.required_inputs for item in operators),
        "balances" => balance_contracts)
end

function _task_to_dict_v1(item::PhysicsEvidenceTaskV1)
    return Dict{String,Any}("id" => item.id, "reason" => item.reason,
        "required_input_ids" => item.required_input_ids,
        "unlocks_operator_ids" => item.unlocks_operator_ids)
end

"Compile a Genome into a physical problem. Family is retained only as audit metadata."
function compile_physics_problem_v1(genome::Genome;
        registry::Vector{PhysicsOperatorSpecV1} = default_physics_operator_registry_v1())
    validation = validate_genome(genome)
    topology = _topology_descriptor_v1(genome)
    domain = _domain_ir_v1(genome, topology)
    operators = _resolve_operators_v1(genome, topology, domain, registry)
    balances = _conservation_balances_v1(genome, domain)
    tasks = _evidence_tasks_v1(operators)
    physical_signature = _physical_signature_payload_v1(genome, topology,
        domain, operators, balances)
    routing = [_operator_to_dict_v1(item) for item in operators]
    claim = validation.valid ? "C0_executable_physics_IR_only" : "invalid_structure"
    return CompiledPhysicsProblemV1("1.0.0", genome.design_id, genome.family,
        genome.physics_hash, topology, domain, operators, balances, tasks,
        validation, canonical_hash(physical_signature), canonical_hash(routing),
        claim)
end

function physics_problem_to_dict_v1(problem::CompiledPhysicsProblemV1)
    return Dict{String,Any}(
        "compiler_version" => problem.compiler_version,
        "design_id" => problem.design_id,
        "source_family_label" => problem.source_family_label,
        "genome_physics_hash" => problem.genome_physics_hash,
        "topology" => _topology_to_dict_v1(problem.topology),
        "domain" => _domain_to_dict_v1(problem.domain),
        "operators" => [_operator_to_dict_v1(item) for item in problem.operators],
        "conservation_balances" => [_balance_to_dict_v1(item) for item in problem.conservation_balances],
        "evidence_tasks" => [_task_to_dict_v1(item) for item in problem.evidence_tasks],
        "structural_validation" => Dict(
            "valid" => problem.structural_validation.valid,
            "errors" => problem.structural_validation.errors,
            "warnings" => problem.structural_validation.warnings),
        "physical_signature_hash" => problem.physical_signature_hash,
        "routing_hash" => problem.routing_hash,
        "claim_ceiling" => problem.claim_ceiling)
end

const _CRITERION_METRICS_V1 = Dict(
    "simplicity" => ["minimum_coil_separation", "coil_curvature", "assembly_tolerance",
        "maintenance_access", "fault_tolerance"],
    "stability" => ["force_balance_residual", "minimum_stability_margin",
        "orbit_loss_fraction", "perturbation_robustness"],
    "output" => ["fusion_power", "recirculating_power", "net_electric_power",
        "peak_heat_flux", "wall_load", "availability"])

const _EVIDENCE_STAGE_METRICS_V1 = [
    "C1" => ["field_solution_converged", "field_line_topology_resolved"],
    "C2" => ["equilibrium_converged", "conservation_residuals_passed",
        "applicable_stability_modes_evaluated", "candidate_specific_transport_evaluated",
        "magnet_engineering_evaluated"],
    "C3" => ["coupled_power_exhaust_closure", "perturbation_robustness",
        "fault_scenario_robustness"],
    "C4" => ["independent_cross_code_agreement", "heldout_known_device_validation",
        "uncertainty_calibration_validated"],
]

function _metric_evidence_map_v1(bundles::Vector{EvaluationBundle})
    result = Dict{String,Vector{MetricResult}}()
    for bundle in bundles, metric in bundle.metrics
        push!(get!(result, metric.metric_id, MetricResult[]), metric)
    end
    return result
end

function _criterion_v1(id::String, evidence::Dict{String,Vector{MetricResult}})
    observed = String[]
    failed = String[]
    unknown = String[]
    for metric_id in _CRITERION_METRICS_V1[id]
        metric_records = get(evidence, metric_id, MetricResult[])
        metric_statuses = getfield.(metric_records, :status)
        if isempty(metric_records) || all(status -> status in (:unknown, :not_applicable, :error), metric_statuses)
            push!(unknown, metric_id)
        elseif any(==(:fail), metric_statuses)
            push!(failed, metric_id)
            push!(observed, metric_id)
        elseif any(==(:pass), metric_statuses)
            push!(observed, metric_id)
        else
            push!(unknown, metric_id)
        end
    end
    status = !isempty(failed) ? :fail : !isempty(unknown) ? :unknown : :pass
    return PhysicsCriterionResultV1(id, status, observed, failed, unknown)
end

function _highest_stage_v1(problem::CompiledPhysicsProblemV1,
        criteria::Vector{PhysicsCriterionResultV1}, evidence::Dict{String,Vector{MetricResult}})
    problem.structural_validation.valid || return "invalid"
    stage = "C0"
    for (stage_index, (candidate_stage, required_metrics)) in enumerate(_EVIDENCE_STAGE_METRICS_V1)
        all(metric_id -> any(metric -> metric.status == :pass &&
                metric.fidelity >= stage_index,
                get(evidence, metric_id, MetricResult[])), required_metrics) || break
        if candidate_stage == "C3"
            all(item -> item.status == :pass, criteria) || break
        end
        stage = candidate_stage
    end
    return stage
end

"Apply the non-compensating standard; unknown or failed axes can never be offset."
function assess_physics_problem_v1(problem::CompiledPhysicsProblemV1,
        genome::Genome, bundles::Vector{EvaluationBundle} = EvaluationBundle[])
    all(bundle -> bundle.design_id == genome.design_id, bundles) ||
        throw(ArgumentError("all evaluation bundles must match the assessed design"))
    all(bundle -> bundle.input_hash == genome.physics_hash, bundles) ||
        throw(ArgumentError("all evaluation bundles must bind to the exact Genome physics hash"))
    all(metric -> metric.input_hash == genome.physics_hash,
        (metric for bundle in bundles for metric in bundle.metrics)) ||
        throw(ArgumentError("all metric evidence must bind to the exact Genome physics hash"))
    evidence = _metric_evidence_map_v1(bundles)
    criteria = [_criterion_v1(id, evidence) for id in ("simplicity", "stability", "output")]
    hard_status = any(item -> item.status == :fail, criteria) ? :fail :
        any(item -> item.status == :unknown, criteria) ? :unknown : :pass
    observations = Dict{String,Any}(
        "field_source_count" => length(genome.field_sources),
        "actuator_count" => length(genome.actuators),
        "plasma_region_count" => length(genome.plasma_regions),
        "connection_count" => length(genome.flux_connections),
        "declared_geometry_parameter_count" => sum(length(item.parameters)
            for item in vcat(genome.plasma_regions, genome.field_sources)),
        "maintenance_access_path_count" => length(genome.engineering.access_paths))
    stage = _highest_stage_v1(problem, criteria, evidence)
    promotion = hard_status == :pass && stage in ("C3", "C4")
    payload = Dict{String,Any}(
        "design_id" => genome.design_id,
        "physical_signature_hash" => problem.physical_signature_hash,
        "criteria" => [Dict("id" => item.id, "status" => String(item.status),
            "observed" => item.observed_metric_ids, "failed" => item.failed_metric_ids,
            "unknown" => item.unknown_metric_ids) for item in criteria],
        "component_observations" => observations,
        "hard_gate_status" => String(hard_status),
        "highest_evidence_stage" => stage,
        "promotion_authorized" => promotion)
    return PhysicsAssessmentV1(genome.design_id, criteria, observations,
        hard_status, stage, promotion, copy(problem.evidence_tasks), canonical_hash(payload))
end

function physics_assessment_to_dict_v1(item::PhysicsAssessmentV1)
    return Dict{String,Any}(
        "design_id" => item.design_id,
        "criteria" => [Dict{String,Any}(
            "id" => criterion.id,
            "status" => String(criterion.status),
            "observed_metric_ids" => criterion.observed_metric_ids,
            "failed_metric_ids" => criterion.failed_metric_ids,
            "unknown_metric_ids" => criterion.unknown_metric_ids)
            for criterion in item.criteria],
        "component_observations" => item.component_observations,
        "hard_gate_status" => String(item.hard_gate_status),
        "highest_evidence_stage" => item.highest_evidence_stage,
        "promotion_authorized" => item.promotion_authorized,
        "evidence_tasks" => [_task_to_dict_v1(task) for task in item.evidence_tasks],
        "assessment_hash" => item.assessment_hash)
end
