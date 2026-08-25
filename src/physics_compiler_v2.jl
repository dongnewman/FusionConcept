"Append-only Physics Compiler registry with distinct magnetic and non-magnetic pulsed C1 routes."
function default_physics_operator_registry_v2()
    spec(id, category, fidelity, rule, inputs, outputs;
            empirical_prior = false, promotion_authority = true) =
        PhysicsOperatorSpecV1(id, category, fidelity, rule,
            String.(inputs), String.(outputs), empirical_prior, promotion_authority)
    return vcat(default_physics_operator_registry_v1(), PhysicsOperatorSpecV1[
        spec("pulsed_drive_geometry_v2", :geometry, 1,
            "non-magnetic pulsed target with explicit driver and target domains",
            ["all_plasma_region_geometry", "all_actuator_geometry",
                "all_compression_geometry", "boundary_conditions"],
            ["drive_geometry", "target_geometry", "drive_source_map"]),
        spec("pulsed_radiation_hydrodynamics_v2", :equilibrium, 2,
            "time-dependent compression or inertial target",
            ["drive_geometry", "target_geometry", "drive_source_map",
                "thermodynamic_profiles", "material_properties"],
            ["compressed_state", "hydrodynamic_convergence",
                "compression_gain", "mix_state"]),
        spec("pulsed_instability_spectrum_v2", :stability, 2,
            "compressed target with interface acceleration and material gradients",
            ["compressed_state", "mix_state", "thermodynamic_profiles"],
            ["minimum_stability_margin", "unstable_mode_ids"]),
        spec("pulsed_chamber_cycle_v2", :engineering, 3,
            "repetitive pulse mission with chamber and replaceable target interfaces",
            ["compressed_state", "wall_geometry", "material_properties",
                "power_conversion_model"],
            ["peak_heat_flux", "wall_load", "chamber_recovery_time",
                "target_throughput", "availability"]),
    ])
end

function _actuator_geometry_available_v2(item::Actuator)
    return _has_coordinate_content_v1(item.parameters)
end

function _compression_geometry_available_v2(item::CompressionSystem)
    model = lowercase(item.geometry_model)
    any(token -> occursin(token, model), ("unmodeled", "unknown")) && return false
    return _has_coordinate_content_v1(item.parameters)
end

function _domain_ir_v2(genome::Genome, topology::PhysicalTopologyDescriptorV1)
    base = _domain_ir_v1(genome, topology)
    available = copy(base.available_input_ids)
    missing = copy(base.missing_input_ids)
    if isempty(genome.actuators)
        push!(missing, "all_actuator_geometry")
    else
        complete = true
        for actuator in genome.actuators
            id = "actuator_geometry:$(actuator.id)"
            if _actuator_geometry_available_v2(actuator)
                push!(available, id)
            else
                complete = false
                push!(missing, id)
            end
        end
        complete && push!(available, "all_actuator_geometry")
    end
    if isempty(genome.compression_systems)
        push!(missing, "all_compression_geometry")
    else
        complete = true
        for system in genome.compression_systems
            id = "compression_geometry:$(system.id)"
            if _compression_geometry_available_v2(system)
                push!(available, id)
            else
                complete = false
                push!(missing, id)
            end
        end
        complete && push!(available, "all_compression_geometry")
    end
    filter!(id -> !(id in available), missing)
    return PhysicsDomainIRV1(base.region_ids, base.source_ids,
        base.connection_kinds, base.boundary_condition_ids,
        base.state_variable_ids, base.source_term_ids, base.loss_term_ids,
        available, sort!(unique(missing)))
end

function _magnetic_field_sources_v2(genome::Genome)
    tokens = ("coil", "magnet", "plasma_current", "current_channel",
        "current_density", "solenoid", "toroidal_field", "poloidal_field",
        "helical_winding", "dipole", "passive_conductor", "electrode")
    return FieldSource[item for item in genome.field_sources if any(token ->
        occursin(token, lowercase("$(item.kind)|$(item.geometry_model)")), tokens)]
end

function _nonmagnetic_pulsed_candidate_v2(genome::Genome)
    isempty(_magnetic_field_sources_v2(genome)) || return false
    text = lowercase(join(vcat(genome.mission.operating_mode,
        getfield.(genome.plasma_regions, :kind),
        getfield.(genome.plasma_regions, :geometry_model),
        getfield.(genome.actuators, :kind),
        getfield.(genome.compression_systems, :kind)), "|"))
    return occursin("pulse", text) || occursin("inertial", text) ||
        occursin("liner", text) || occursin("implosion", text) ||
        occursin("compression", text) || occursin("laser", text) ||
        occursin("target", text)
end

function physics_c1_route_v2(genome::Genome)
    magnetic = !isempty(_magnetic_field_sources_v2(genome))
    pulsed = _nonmagnetic_pulsed_candidate_v2(genome) ||
        !isempty(genome.compression_systems)
    magnetic && pulsed && return :hybrid_magnetic_pulsed
    magnetic && return :magnetic_field_topology
    pulsed && return :pulsed_drive_geometry
    return :unknown
end

function _operator_active_v2(spec::PhysicsOperatorSpecV1,
        topology::PhysicalTopologyDescriptorV1, genome::Genome)
    id = spec.id
    route = physics_c1_route_v2(genome)
    pulsed_ids = Set(("pulsed_drive_geometry_v2",
        "pulsed_radiation_hydrodynamics_v2", "pulsed_instability_spectrum_v2",
        "pulsed_chamber_cycle_v2"))
    id in pulsed_ids && return route in
        (:pulsed_drive_geometry, :hybrid_magnetic_pulsed)
    magnetic_only = Set(("maxwell_magnetostatic_field_v1",
        "field_line_topology_trace_v1", "closed_flux_surface_analysis_v1",
        "open_field_connection_analysis_v1", "separatrix_and_xpoint_analysis_v1",
        "axisymmetric_current_equilibrium_v1",
        "three_dimensional_mhd_equilibrium_v1",
        "open_field_finite_beta_equilibrium_v1",
        "guiding_center_orbit_following_v1",
        "topology_conditioned_transport_v1",
        "magnet_force_stress_and_build_v1", "ipb98_calibration_prior_v1",
        "iss04_calibration_prior_v1", "classical_open_end_loss_prior_v1"))
    id in magnetic_only && return route in
        (:magnetic_field_topology, :hybrid_magnetic_pulsed) &&
        _operator_active_v1(spec, topology, genome)
    id == "applicable_mode_stability_spectrum_v1" &&
        return route in (:magnetic_field_topology, :hybrid_magnetic_pulsed)
    id in ("species_conservation_ledger_v1", "fusion_radiation_power_kernel_v1",
        "wall_blanket_exhaust_balance_v1") && return true
    id == "net_electric_and_availability_ledger_v1" &&
        return genome.mission.kind == "net_electric_pilot" ||
            genome.engineering.blanket_required
    return false
end

function _resolve_operators_v2(genome::Genome,
        topology::PhysicalTopologyDescriptorV1, domain::PhysicsDomainIRV1,
        registry::Vector{PhysicsOperatorSpecV1})
    active = filter(spec -> _operator_active_v2(spec, topology, genome), registry)
    available = copy(domain.available_input_ids)
    compiled = CompiledPhysicsOperatorV1[]
    remaining = copy(active)
    while !isempty(remaining)
        progressed = false
        next_remaining = PhysicsOperatorSpecV1[]
        for spec in remaining
            missing = sort!(String[input for input in spec.required_inputs if
                !(input in available)])
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
                missing = sort!(String[input for input in spec.required_inputs if
                    !(input in available)])
                push!(compiled, CompiledPhysicsOperatorV1(spec,
                    :blocked_unknown_inputs, missing))
            end
            break
        end
        remaining = next_remaining
    end
    sort!(compiled; by = item -> item.spec.id)
    return compiled
end

function compile_physics_problem_v2(genome::Genome;
        registry::Vector{PhysicsOperatorSpecV1} =
            default_physics_operator_registry_v2())
    validation = validate_genome(genome)
    topology = _topology_descriptor_v1(genome)
    domain = _domain_ir_v2(genome, topology)
    operators = _resolve_operators_v2(genome, topology, domain, registry)
    balances = _conservation_balances_v1(genome, domain)
    tasks = _evidence_tasks_v1(operators)
    physical_signature = _physical_signature_payload_v1(genome, topology,
        domain, operators, balances)
    routing = [_operator_to_dict_v1(item) for item in operators]
    claim = validation.valid ? "C0_executable_physics_IR_v2_only" :
        "invalid_structure"
    return CompiledPhysicsProblemV1("2.0.0", genome.design_id, genome.family,
        genome.physics_hash, topology, domain, operators, balances, tasks,
        validation, canonical_hash(physical_signature), canonical_hash(routing),
        claim)
end

function physics_problem_to_dict_v2(problem::CompiledPhysicsProblemV1,
        genome::Genome)
    raw = physics_problem_to_dict_v1(problem)
    raw["c1_route"] = String(physics_c1_route_v2(genome))
    route = physics_c1_route_v2(genome)
    raw["required_c1_metrics"] = route == :magnetic_field_topology ?
        ["field_solution_converged", "field_line_topology_resolved"] :
        route == :pulsed_drive_geometry ?
        ["drive_geometry_resolved", "drive_source_map_resolved"] : String[]
    route == :hybrid_magnetic_pulsed && (raw["required_c1_metrics"] = [
        "field_solution_converged", "field_line_topology_resolved",
        "drive_geometry_resolved", "drive_source_map_resolved"])
    return raw
end

function compile_executable_physics_program_v2(executable::ExecutableGenomeV1;
        registry::Vector{PhysicsOperatorSpecV1} =
            default_physics_operator_registry_v2())
    validation = validate_executable_genome_v1(executable; registry = registry)
    base = compile_physics_problem_v2(executable.base_genome; registry = registry)
    schedule, compiled_modules = validation.valid ?
        _compile_modules_v1(executable, base) :
        (String[], CompiledExecutableModuleV1[])
    active_specs = [item.spec for item in base.operators if !item.spec.empirical_prior]
    active_ids = sort!(getfield.(active_specs, :id))
    prior_ids = sort!(String[item.spec.id for item in base.operators if
        item.spec.empirical_prior])
    declared_ids = sort!(unique(String[backend.capability_id for item in
        executable.modules for backend in item.backend_requirements]))
    uncovered = sort!(String[id for id in active_ids if !(id in declared_ids)])
    misapplied = sort!(String[id for id in declared_ids if !(id in active_ids)])
    tasks = copy(base.evidence_tasks)
    for id in uncovered
        push!(tasks, PhysicsEvidenceTaskV1("declare_operator:$id",
            "Active v2 physics operator has no native executable module declaration.",
            String[], [id]))
    end
    for item in compiled_modules
        item.status == :ready_for_execution && continue
        push!(tasks, PhysicsEvidenceTaskV1("repair_module:$(item.module_id)",
            "Executable module is not ready; repair its inputs, backend or scale.",
            item.missing_input_ids, item.unavailable_capability_ids))
    end
    sort!(tasks; by = item -> item.id)
    explicit_count = count(item -> item.declaration_status == :explicit,
        executable.modules)
    migrated_count = length(executable.modules) - explicit_count
    ready_count = count(item -> item.status == :ready_for_execution,
        compiled_modules)
    claim = validation.valid && isempty(uncovered) && isempty(misapplied) &&
        migrated_count == 0 && ready_count == length(executable.modules) ?
        "C0_native_executable_program_v2_ready_for_solver_execution" :
        "C0_executable_program_v2_incomplete_unknown"
    payload = Dict{String,Any}(
        "base_physical_signature_hash" => base.physical_signature_hash,
        "modules" => executable_module_to_dict_v1.(executable.modules),
        "schedule" => schedule, "active_operator_ids" => active_ids,
        "declared_operator_ids" => declared_ids,
        "uncovered_operator_ids" => uncovered,
        "misapplied_operator_ids" => misapplied,
        "compiled_statuses" => Dict(item.module_id => String(item.status)
            for item in compiled_modules))
    return CompiledExecutablePhysicsProgramV1("2.0.0",
        executable.base_genome.design_id, base, validation, schedule,
        compiled_modules, active_ids, declared_ids, uncovered, misapplied,
        prior_ids, explicit_count, migrated_count, ready_count, tasks,
        canonical_hash(payload), claim)
end
