const _CSR_V2_MU0 = 4.0e-7 * pi

"Hash-sealed Stage-7 numerical loads and deliberately incomplete engineering roles."
struct EngineeringResultEnvelopeV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    manifest_hash::String
    state_result_hash::String
    transport_result_hash::String
    status::Symbol
    output_roles::Vector{Dict{String,Any}}
    checks::Vector{Dict{String,Any}}
    recirculating_power::Dict{String,Any}
    evidence_ceiling::String
    unknown_reasons::Vector{String}
    result_hash::String
end

function candidate_engineering_parameters_v1(genome::Genome, module_ids)
    peak_fields = Float64[]
    on_axis_fields = Float64[]
    coil_count = 0.0
    for source in genome.field_sources, (id, value) in source.parameters
        key = lowercase(String(id))
        if value.unit == "T" && occursin("peak", key) && isfinite(value.value)
            push!(peak_fields, Float64(value.value))
        elseif value.unit == "T" && occursin("field", key) && isfinite(value.value)
            push!(on_axis_fields, Float64(value.value))
        elseif value.unit == "1" && occursin("count", key) && isfinite(value.value)
            coil_count += max(0.0, Float64(value.value))
        end
    end
    declared_drive_power = 0.0
    known_wall_plug_power = 0.0
    drive_count = 0
    efficiency_count = 0
    for actuator in genome.actuators
        powers = Float64[value.value for (id, value) in actuator.parameters if
            value.unit == "W" && occursin("power", lowercase(String(id))) &&
            isfinite(value.value) && value.value >= 0.0]
        isempty(powers) && continue
        power = sum(powers)
        declared_drive_power += power
        drive_count += 1
        efficiencies = Float64[value.value for (id, value) in actuator.parameters if
            value.unit == "1" && occursin("efficien", lowercase(String(id))) &&
            isfinite(value.value) && 0.0 < value.value <= 1.0]
        if !isempty(efficiencies)
            known_wall_plug_power += power / minimum(efficiencies)
            efficiency_count += 1
        else
            known_wall_plug_power += power
        end
    end
    time_semantics = get(genome.normalized, "time_integration_contract_v2", nothing)
    pulse_duration = time_semantics isa AbstractDict ?
        get(time_semantics, "active_phase_duration_s", nothing) :
        _csr_v1_quantity(genome,
            id -> occursin("duration", id) || occursin("pulse", id), "s")
    repetition_rate = time_semantics isa AbstractDict ?
        get(time_semantics, "shot_repetition_rate_hz", nothing) :
        _csr_v1_quantity(genome,
            id -> occursin("repetition", id) || occursin("repeat", id) ||
                occursin("frequency", id), "Hz")
    catalog = Dict(item.id => item for item in default_topology_module_catalog_v17())
    target_counts = Int[]
    for raw_id in module_ids
        spec = get(catalog, String(raw_id), nothing)
        spec === nothing && continue
        for tag in spec.provides
            text = String(tag)
            startswith(text, "target_count:") || continue
            parsed = tryparse(Int, split(text, ":"; limit = 2)[2])
            parsed === nothing || push!(target_counts, parsed)
        end
    end
    target_tbr = genome.engineering.target_tbr === nothing ? nothing :
        Float64(genome.engineering.target_tbr.value)
    return Dict{String,Any}(
        "peak_declared_field_t" => isempty(peak_fields) ? nothing : maximum(peak_fields),
        "maximum_declared_on_axis_field_t" => isempty(on_axis_fields) ? nothing :
            maximum(on_axis_fields),
        "declared_coil_count" => coil_count,
        "declared_drive_power_w" => declared_drive_power,
        "known_wall_plug_power_w" => known_wall_plug_power,
        "wall_plug_efficiency_coverage" => drive_count == 0 ? "not_applicable_no_watt_drive" :
            efficiency_count == drive_count ? "complete_for_declared_watt_drives" :
            "incomplete_missing_efficiency",
        "pulse_duration_s" => pulse_duration,
        "repetition_rate_hz" => repetition_rate,
        "time_semantics_version" => time_semantics isa AbstractDict ? "2.0.0" : "1.0.0",
        "plant_availability_factor" => time_semantics isa AbstractDict ?
            get(time_semantics, "plant_availability_factor", nothing) : nothing,
        "declared_target_count" => isempty(target_counts) ? nothing : maximum(target_counts),
        "blanket_required" => genome.engineering.blanket_required,
        "declared_target_tbr" => target_tbr,
        "maintenance_architecture" => genome.engineering.maintenance_architecture,
        "maintenance_access_paths" => copy(genome.engineering.access_paths),
        "engineering_materials" => copy(genome.engineering.magnet_technology),
        "engineering_evaluators" => copy(genome.engineering.required_evaluators),
        "exhaust_kind" => genome.exhaust.kind)
end

"Bind the global conserved state only to transport matching its declared control volume."
function compile_candidate_solve_manifest_v2(genome::Genome, module_ids;
        discretization_levels = [32], parameter_overrides = Dict{String,Any}())
    base = compile_candidate_solve_manifest_v1(genome, module_ids;
        discretization_levels = discretization_levels,
        parameter_overrides = parameter_overrides)
    operators = Set(String(item["operator_id"]) for item in base.module_bindings)
    has_closed = "state_derived_bohm_transport_l1_v1" in operators
    has_open = "state_derived_parallel_streaming_l1_v1" in operators
    primary = isempty(base.regions) ? Dict{String,Any}() : first(base.regions)
    primary_scope_text = lowercase(join(String[
        String(get(primary, "kind", "")), String(get(primary, "geometry_model", ""))], "|"))
    scope = if has_closed && has_open
        occursin("closed", primary_scope_text) ? "closed" :
            occursin("open", primary_scope_text) ? "open" : "ambiguous"
    elseif has_closed
        "closed"
    elseif has_open
        "open"
    else
        "none"
    end
    bindings = Dict{String,Any}[]
    for item in base.module_bindings
        operator = String(item["operator_id"])
        operator == "state_derived_bohm_transport_l1_v1" && scope == "open" && continue
        operator == "state_derived_parallel_streaming_l1_v1" && scope == "closed" && continue
        operator in ("state_derived_bohm_transport_l1_v1",
            "state_derived_parallel_streaming_l1_v1") && scope == "ambiguous" && continue
        push!(bindings, deepcopy(item))
    end
    applicability_scope = deepcopy(base.applicability_scope)
    reasons = String.(get(applicability_scope, "unsupported_reasons", String[]))
    scope == "ambiguous" && push!(reasons,
        "global conserved state has both open and closed transport capabilities but its primary control-volume scope is not explicit")
    applicability_scope["status"] = isempty(reasons) ? "applicable" : "unsupported"
    applicability_scope["unsupported_reasons"] = sort!(unique(reasons))
    applicability_scope["transport_control_volume_scope"] = scope
    applicability_scope["transport_scope_basis"] =
        "declared primary region kind/geometry plus declared open/closed capabilities"
    parameters = deepcopy(base.parameters)
    parameters["transport_control_volume_scope"] = scope
    return CandidateSolveManifestV1(candidate_id = base.candidate_id,
        physics_hash = base.physics_hash, regions = base.regions, mesh = base.mesh,
        state_variables = base.state_variables,
        capability_declarations = base.capability_declarations,
        module_bindings = bindings, boundaries = base.boundaries,
        sources_sinks = base.sources_sinks, time_mode = base.time_mode,
        initial_conditions = base.initial_conditions,
        numerical_tolerances = base.numerical_tolerances,
        discretization_levels = base.discretization_levels,
        required_outputs = base.required_outputs,
        applicability_scope = applicability_scope, parameters = parameters)
end

function _csr_v2_make_envelope(manifest; status, convergence_status,
        residual_history = Dict{String,Any}[], state_trajectory = Dict{String,Any}(),
        conservation_slots = Dict{String,Any}[], resolution = Dict{String,Any}(),
        error_estimates = Dict{String,Any}(), module_results = Dict{String,Any}[],
        evidence_ceiling = "L1_candidate_bound_screening_only",
        unsupported_reasons = String[])
    status in CANDIDATE_SOLVE_STATUS_V1 || throw(ArgumentError("invalid solver status"))
    software_hash = canonical_hash(Dict("runtime" => "candidate_solver_runtime_v2",
        "algorithm" => "capability_matched_steady_balance_and_rk4_probe_v2"))
    container_hash = canonical_hash(Dict("julia_version" => string(VERSION),
        "machine" => Sys.MACHINE, "kernel" => Sys.KERNEL,
        "environment_kind" => "process_environment_not_sealed_container_image"))
    body = _csr_v1_envelope_body(candidate_id = manifest.candidate_id,
        physics_hash = manifest.physics_hash, manifest_hash = manifest.manifest_hash,
        input_hash = manifest.manifest_hash, software_hash = software_hash,
        container_hash = container_hash, status = status,
        convergence_status = convergence_status, residual_history = residual_history,
        state_trajectory = state_trajectory, conservation_slots = conservation_slots,
        resolution = resolution, error_estimates = error_estimates,
        module_results = module_results, evidence_ceiling = evidence_ceiling,
        unsupported_reasons = sort!(unique(String.(unsupported_reasons))))
    body = _csr_v1_json_safe(body)
    result_hash = canonical_hash(body)
    return SolverResultEnvelopeV1(body["schema_version"], body["candidate_id"],
        body["physics_hash"], body["manifest_hash"], body["input_hash"],
        body["software_hash"], body["container_hash"], status,
        body["convergence_status"], body["residual_history"],
        body["state_trajectory"], body["conservation_slots"], body["resolution"],
        body["error_estimates"], body["module_results"], body["evidence_ceiling"],
        body["unsupported_reasons"], result_hash)
end

function _csr_v2_steady_balance(manifest, modules)
    state_ids = String[String(item["state_id"]) for item in manifest.state_variables]
    state = Float64[manifest.initial_conditions[id] for id in state_ids]
    physical_source, physical_flux = _csr_v1_source_flux(modules, state, 0.0, manifest)
    required_source = max.(physical_flux .- physical_source, 0.0)
    required_sink = max.(physical_source .- physical_flux, 0.0)
    slots = Dict{String,Any}[]
    source_demands = Dict{String,Float64}()
    sink_demands = Dict{String,Float64}()
    for (index, item) in enumerate(manifest.state_variables)
        source_total = physical_source[index] + required_source[index]
        flux_total = physical_flux[index] + required_sink[index]
        normalization = max(abs(source_total) + abs(flux_total), 1.0)
        residual = abs(flux_total - source_total) / normalization
        state_id = String(item["state_id"])
        source_demands[state_id] = required_source[index]
        sink_demands[state_id] = required_sink[index]
        push!(slots, Dict("state_id" => state_id, "account" => String(item["account"]),
            "dU_dt" => 0.0, "divergence_F" => flux_total, "source_S" => source_total,
            "physical_divergence_F" => physical_flux[index],
            "physical_source_S" => physical_source[index],
            "required_closure_source" => required_source[index],
            "required_closure_sink" => required_sink[index],
            "normalization" => normalization, "normalized_residual" => residual))
    end
    closure = Dict{String,Any}(
        "module_id" => "steady_balance_closure_demands",
        "capability_id" => "generic_control_volume_steady_balance",
        "operator_id" => "required_steady_source_sink_roles_v2",
        "status" => "computed_requirement_not_engineering_realization",
        "required_source_by_state" => source_demands,
        "required_sink_by_state" => sink_demands,
        "claim_boundary" => "A solved balance demand is not evidence that a fueling, heating, exhaust, or power-supply system can realize it.")
    closure["observation_hash"] = canonical_hash(closure)
    trajectory = Dict{String,Any}("time_samples_s" => [0.0], "state_ids" => state_ids,
        "states" => [copy(state)], "complete" => true,
        "final_state" => Dict(state_ids[index] => state[index] for index in eachindex(state_ids)),
        "trajectory_kind" => "algebraic_steady_state_with_explicit_closure_demands")
    return state, slots, closure, trajectory
end

function _csr_v2_rk4_probe(manifest, modules, state, t, dt)
    rhs(value, time) = begin
        source, flux = _csr_v1_source_flux(modules, value, time, manifest)
        source .- flux
    end
    k1 = rhs(state, t)
    k2 = rhs(state .+ 0.5dt .* k1, t + 0.5dt)
    k3 = rhs(state .+ 0.5dt .* k2, t + 0.5dt)
    k4 = rhs(state .+ dt .* k3, t + dt)
    candidate = state .+ dt .* (k1 .+ 2k2 .+ 2k3 .+ k4) ./ 6.0
    positive = Bool[get(item, "positivity_required", false) === true
        for item in manifest.state_variables]
    for index in eachindex(candidate)
        positive[index] && (candidate[index] = max(candidate[index], 0.0))
    end
    return candidate
end

function _csr_v2_transient_audit(manifest, modules, trajectory)
    final = trajectory["states"][end]
    final_time = Float64(trajectory["times"][end])
    tau = _csr_v1_characteristic_time(modules, final, manifest)
    scale = isfinite(tau) && tau > 0.0 ? tau : max(final_time, 1.0)
    probe_dt = max(scale * 1.0e-7, eps(max(final_time, scale, 1.0)))
    probe = _csr_v2_rk4_probe(manifest, modules, final, final_time, probe_dt)
    derivative = (probe .- final) ./ probe_dt
    source, flux = _csr_v1_source_flux(modules, final, final_time, manifest)
    records = Dict{String,Any}[]
    for (index, item) in enumerate(manifest.state_variables)
        normalization = max(abs(derivative[index]) + abs(flux[index]) +
            abs(source[index]), 1.0)
        normalized = abs(derivative[index] + flux[index] - source[index]) /
            normalization
        push!(records, Dict("state_id" => String(item["state_id"]),
            "account" => String(item["account"]), "dU_dt" => derivative[index],
            "divergence_F" => flux[index], "source_S" => source[index],
            "normalization" => normalization, "normalized_residual" => normalized,
            "audit_method" => "independent_local_rk4_probe"))
    end
    return records, probe_dt
end

"Solve steady candidates as explicit balance demands and audit pulse trajectories locally."
function solve_candidate_manifest_v2(manifest::CandidateSolveManifestV1)
    unsupported = String.(get(manifest.applicability_scope,
        "unsupported_reasons", String[]))
    if get(manifest.applicability_scope, "status", "unsupported") != "applicable"
        return _csr_v2_make_envelope(manifest; status = :unsupported,
            convergence_status = "not_run_missing_inputs_or_operator",
            unsupported_reasons = unsupported, evidence_ceiling = "none_unsupported_problem")
    end
    modules = _csr_v1_modules(manifest)
    state_ids = String[String(item["state_id"]) for item in manifest.state_variables]
    if manifest.time_mode == "steady"
        final, slots, closure, trajectory = _csr_v2_steady_balance(manifest, modules)
        maximum_residual = isempty(slots) ? Inf : maximum(Float64(item["normalized_residual"])
            for item in slots)
        module_results = [observables(physics_module, final, trajectory, manifest)
            for physics_module in modules]
        push!(module_results, closure)
        converged = maximum_residual <= manifest.numerical_tolerances["normalized_residual"]
        return _csr_v2_make_envelope(manifest; status = converged ? :pass : :unknown,
            convergence_status = converged ? "converged_with_required_closure_demands" :
                "steady_balance_residual_not_converged",
            residual_history = [Dict("time_s" => 0.0,
                "maximum_normalized_residual" => maximum_residual,
                "normalized_time_term" => 0.0)], state_trajectory = trajectory,
            conservation_slots = slots,
            resolution = Dict("levels" => manifest.discretization_levels,
                "selected_level" => maximum(manifest.discretization_levels),
                "method" => "algebraic_control_volume_balance"),
            error_estimates = Dict("maximum_normalized_conservation_residual" =>
                maximum_residual, "final_normalized_time_term" => 0.0,
                "closure_demand_observation_hash" => closure["observation_hash"]),
            module_results = module_results, unsupported_reasons = unsupported)
    end
    runs = Dict(level => _csr_v1_integrate(manifest, modules, level)
        for level in manifest.discretization_levels)
    finest_level = maximum(manifest.discretization_levels)
    finest = runs[finest_level]
    if finest["status"] != "computed"
        return _csr_v2_make_envelope(manifest; status = :fail,
            convergence_status = String(get(finest, "reason", "solver_failure")),
            resolution = Dict("levels" => manifest.discretization_levels),
            unsupported_reasons = unsupported)
    end
    slots, probe_dt = _csr_v2_transient_audit(manifest, modules, finest)
    maximum_residual = isempty(slots) ? Inf : maximum(Float64(item["normalized_residual"])
        for item in slots)
    tolerance = manifest.numerical_tolerances["normalized_residual"]
    converged = maximum_residual <= tolerance
    final = finest["states"][end]
    trajectory = Dict{String,Any}("time_samples_s" => finest["times"],
        "state_ids" => state_ids, "states" => finest["states"], "complete" => true,
        "final_state" => Dict(state_ids[index] => final[index] for index in eachindex(state_ids)),
        "trajectory_kind" => "complete_$(manifest.time_mode)_trajectory")
    module_results = [observables(physics_module, final, trajectory, manifest)
        for physics_module in modules]
    normalized_time_terms = Float64[abs(Float64(get(item, "dU_dt", 0.0))) /
        max(Float64(get(item, "normalization", 1.0)), 1.0) for item in slots]
    error_estimates = Dict{String,Any}(
        "maximum_normalized_conservation_residual" => maximum_residual,
        "final_normalized_time_term" => maximum(normalized_time_terms; init = 0.0),
        "audit_probe_time_step_s" => probe_dt)
    if length(manifest.discretization_levels) >= 2
        coarse = runs[manifest.discretization_levels[end - 1]]
        if coarse["status"] == "computed"
            coarse_final = coarse["states"][end]
            relative = maximum(abs.(final .- coarse_final) ./ max.(abs.(final), 1.0))
            error_estimates["relative_resolution_change"] = relative
            error_estimates["resolution_converged"] = relative <=
                manifest.numerical_tolerances["relative_resolution"]
        end
    end
    return _csr_v2_make_envelope(manifest; status = converged ? :pass : :unknown,
        convergence_status = converged ? "complete_$(manifest.time_mode)_trajectory" :
            "trajectory_computed_residual_not_converged",
        residual_history = [Dict("time_s" => finest["times"][end],
            "maximum_normalized_residual" => maximum_residual)],
        state_trajectory = trajectory, conservation_slots = slots,
        resolution = Dict("levels" => manifest.discretization_levels,
            "selected_level" => finest_level, "time_step_s" => finest["time_step_s"],
            "maximum_internal_time_step_s" => finest["maximum_internal_time_step_s"],
            "audit_probe_time_step_s" => probe_dt), error_estimates = error_estimates,
        module_results = module_results, unsupported_reasons = unsupported)
end

function _csr_v2_engineering_body(; candidate_id, physics_hash, manifest_hash,
        state_result_hash, transport_result_hash, status, output_roles, checks,
        recirculating_power, evidence_ceiling, unknown_reasons)
    return Dict{String,Any}("schema_version" => "1.0.0", "candidate_id" => candidate_id,
        "physics_hash" => physics_hash, "manifest_hash" => manifest_hash,
        "state_result_hash" => state_result_hash,
        "transport_result_hash" => transport_result_hash, "status" => String(status),
        "output_roles" => output_roles, "checks" => checks,
        "recirculating_power" => recirculating_power,
        "evidence_ceiling" => evidence_ceiling, "unknown_reasons" => unknown_reasons)
end

function engineering_result_envelope_to_dict_v1(result::EngineeringResultEnvelopeV1)
    body = _csr_v2_engineering_body(candidate_id = result.candidate_id,
        physics_hash = result.physics_hash, manifest_hash = result.manifest_hash,
        state_result_hash = result.state_result_hash,
        transport_result_hash = result.transport_result_hash, status = result.status,
        output_roles = result.output_roles, checks = result.checks,
        recirculating_power = result.recirculating_power,
        evidence_ceiling = result.evidence_ceiling,
        unknown_reasons = result.unknown_reasons)
    body["result_hash"] = result.result_hash
    return body
end

function _csr_v2_role(id, value, unit, status, basis, source_hashes)
    body = Dict{String,Any}("role_id" => String(id), "value" => value,
        "unit" => String(unit), "status" => String(status), "basis" => String(basis),
        "source_output_hashes" => sort!(unique(filter(!isempty, String.(source_hashes)))))
    body["output_role_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

function solve_engineering_roles_v1(manifest::CandidateSolveManifestV1,
        result::SolverResultEnvelopeV1, transport)
    roles = Dict{String,Any}[]
    reasons = String[]
    parameters = manifest.parameters
    state_hash = result.status == :unsupported ? "" : result.result_hash
    transport_hash = String(get(transport, "solver_output_hash", ""))
    volume = get(parameters, "volume_m3", nothing)
    radius = get(parameters, "minor_radius_m", nothing)
    length_m = get(parameters, "characteristic_length_m", nothing)
    peak_field = get(parameters, "peak_declared_field_t", nothing)
    peak_field isa Real || (peak_field = get(parameters, "magnetic_field_t", nothing))
    pressure = peak_field isa Real && isfinite(peak_field) ? Float64(peak_field)^2 /
        (2.0 * _CSR_V2_MU0) : nothing
    surface_area = radius isa Real && length_m isa Real && radius > 0 && length_m > 0 ?
        2.0pi * Float64(radius) * Float64(length_m) : nothing
    pressure === nothing && push!(reasons, "missing finite declared magnetic field")
    pressure !== nothing && push!(roles, _csr_v2_role("magnetic_pressure_load", pressure,
        "Pa", "computed_load_no_limit", "B_peak^2/(2*mu0)", [state_hash]))
    pressure !== nothing && surface_area !== nothing && push!(roles,
        _csr_v2_role("global_magnetic_force_scale", pressure * surface_area, "N",
            "computed_load_no_support_solution", "magnetic pressure times declared global surface area",
            [state_hash]))
    pressure !== nothing && volume isa Real && volume > 0 && push!(roles,
        _csr_v2_role("stored_magnetic_energy_l1", pressure * Float64(volume), "J",
            "computed_inventory_l1", "uniform-field control-volume inventory", [state_hash]))
    loss = get(transport, "loss_power_w", nothing)
    heat_flux = loss isa Real && surface_area !== nothing && surface_area > 0 ?
        Float64(loss) / surface_area : nothing
    heat_flux === nothing && push!(reasons, "missing converged loss power or finite global surface area")
    heat_flux !== nothing && push!(roles, _csr_v2_role("global_surface_average_heat_load",
        heat_flux, "W/m^2", "computed_load_not_local_target_solution",
        "state-derived loss divided by declared global surface area", [transport_hash]))
    closure = findfirst(item -> String(get(item, "operator_id", "")) ==
        "required_steady_source_sink_roles_v2", result.module_results)
    source_demands = closure === nothing ? Dict{String,Any}() :
        get(result.module_results[closure], "required_source_by_state", Dict{String,Any}())
    particle_makeup = get(source_demands, "particle_inventory", nothing)
    auxiliary_power = get(source_demands, "thermal_energy", nothing)
    particle_makeup isa Real && push!(roles, _csr_v2_role("required_particle_replenishment",
        Float64(particle_makeup), "1/s", "computed_requirement_no_fuel_cycle_realization",
        "steady control-volume particle balance", [state_hash]))
    auxiliary_power isa Real && push!(roles, _csr_v2_role("required_auxiliary_thermal_power",
        Float64(auxiliary_power), "W", "computed_requirement_no_power_supply_realization",
        "steady control-volume energy balance", [state_hash]))
    declared_drive = Float64(get(parameters, "declared_drive_power_w",
        get(parameters, "input_power_w", 0.0)))
    wall_plug = Float64(get(parameters, "known_wall_plug_power_w", declared_drive))
    known_conversion_increment = max(wall_plug - declared_drive, 0.0)
    recirculating_lower_bound = max(auxiliary_power isa Real ? Float64(auxiliary_power) : 0.0,
        0.0) + known_conversion_increment
    coverage = String(get(parameters, "wall_plug_efficiency_coverage", "missing"))
    push!(reasons, "cryogenic, pumping, current-drive, thermal-cycle, and balance-of-plant loads are incomplete")
    coverage == "incomplete_missing_efficiency" &&
        push!(reasons, "one or more declared watt-level actuators lack wall-plug efficiency")
    recirculating = Dict{String,Any}(
        "value_w" => recirculating_lower_bound,
        "role_completeness" => "lower_bound",
        "included_components" => Dict("required_auxiliary_thermal_power_w" =>
            max(auxiliary_power isa Real ? Float64(auxiliary_power) : 0.0, 0.0),
            "known_wall_plug_conversion_increment_w" => known_conversion_increment),
        "missing_components" => sort!(unique(copy(reasons))),
        "source_output_hashes" => sort!(unique(filter(!isempty,
            [state_hash, transport_hash]))),
        "claim_boundary" => "This is a solver-derived recirculating-power lower bound, not complete plant recirculating power.")
    recirculating["role_hash"] = canonical_hash(_csr_v1_json_safe(recirculating))
    push!(roles, _csr_v2_role("recirculating_power_lower_bound", recirculating_lower_bound,
        "W", "computed_lower_bound_incomplete", recirculating["claim_boundary"],
        recirculating["source_output_hashes"]))
    role_by_id = Dict(String(item["role_id"]) => item for item in roles)
    checks = Dict{String,Any}[]
    function check!(id, role_id = nothing)
        role = role_id === nothing ? nothing : get(role_by_id, String(role_id), nothing)
        item = Dict{String,Any}("check_id" => String(id), "status" => "unknown",
            "evidence_refs" => ["stage7_engineering_result_v1"],
            "normalized_margin" => nothing,
            "unknown_basis" => "numeric load alone cannot invent geometry, material, fault, lifetime, or acceptance limits")
        role === nothing || begin
            item["observed_value"] = role["value"]
            item["unit"] = role["unit"]
            item["output_role_hash"] = role["output_role_hash"]
        end
        push!(checks, item)
    end
    check!("field_strength", pressure === nothing ? nothing : "magnetic_pressure_load")
    check!("force", pressure === nothing ? nothing : "global_magnetic_force_scale")
    check!("stress", pressure === nothing ? nothing : "magnetic_pressure_load")
    check!("heat_flux", heat_flux === nothing ? nothing : "global_surface_average_heat_load")
    check!("material_temperature")
    check!("irradiation")
    check!("quench")
    check!("repetition_rate")
    check!("maintenance_space")
    check!("fuel_cycle", particle_makeup isa Real ? "required_particle_replenishment" : nothing)
    check!("component_lifetime")
    body = _csr_v2_engineering_body(candidate_id = manifest.candidate_id,
        physics_hash = manifest.physics_hash, manifest_hash = manifest.manifest_hash,
        state_result_hash = state_hash, transport_result_hash = transport_hash,
        status = :unknown, output_roles = roles, checks = checks,
        recirculating_power = recirculating,
        evidence_ceiling = "L1_engineering_loads_and_recirculating_lower_bound_only",
        unknown_reasons = sort!(unique(reasons)))
    safe = _csr_v1_json_safe(body)
    hash = canonical_hash(safe)
    return EngineeringResultEnvelopeV1(safe["schema_version"], safe["candidate_id"],
        safe["physics_hash"], safe["manifest_hash"], safe["state_result_hash"],
        safe["transport_result_hash"], :unknown, safe["output_roles"], safe["checks"],
        safe["recirculating_power"], safe["evidence_ceiling"],
        safe["unknown_reasons"], hash)
end

"Strict ledger v2 exposes incomplete power roles without converting bounds into sign evidence."
function strict_power_ledger_v2(result::SolverResultEnvelopeV1, transport,
        engineering::EngineeringResultEnvelopeV1)
    terms = Dict{String,Any}[]
    state_hash = result.status == :unsupported ? "" : result.result_hash
    transport_hash = String(get(transport, "solver_output_hash", ""))
    engineering_hash = engineering.result_hash
    fusion = get(transport, "fusion_power_w", nothing)
    loss = get(transport, "loss_power_w", nothing)
    thermal = findfirst(item -> String(get(item, "operator_id", "")) ==
        "control_volume_thermal_energy_v1", result.module_results)
    drive = thermal === nothing ? nothing : get(result.module_results[thermal], "input_power_w", nothing)
    fusion isa Real && push!(terms, Dict("role" => "fusion", "value_w" => Float64(fusion),
        "solver_derived" => true, "role_completeness" => "complete",
        "source_output_hash" => transport_hash))
    drive isa Real && push!(terms, Dict("role" => "drive", "value_w" => -Float64(drive),
        "solver_derived" => true, "role_completeness" => "complete",
        "source_output_hash" => state_hash))
    loss isa Real && push!(terms, Dict("role" => "loss", "value_w" => -Float64(loss),
        "solver_derived" => true, "role_completeness" => "complete",
        "source_output_hash" => transport_hash))
    recirculating = engineering.recirculating_power
    value = get(recirculating, "value_w", nothing)
    value isa Real && push!(terms, Dict("role" => "recirculating",
        "value_w" => -Float64(value), "solver_derived" => true,
        "role_completeness" => String(get(recirculating, "role_completeness", "unknown")),
        "source_output_hash" => engineering_hash,
        "component_hash" => String(get(recirculating, "role_hash", ""))))
    reported = sum((Float64(item["value_w"]) for item in terms); init = 0.0)
    roles = Set(String(item["role"]) for item in terms)
    complete = all(role -> role in roles, ("fusion", "drive", "loss", "recirculating")) &&
        all(item -> String(get(item, "role_completeness", "unknown")) == "complete", terms)
    return Dict{String,Any}(
        "generated_nominal" => false, "artificially_closed" => false,
        "strict_role_completeness_required" => true, "terms" => terms,
        "reported_net_power_w" => reported,
        "reported_net_power_interpretation" => complete ? "complete_net_power" :
            "upper_bound_only_due_to_incomplete_negative_power_roles",
        "closure_tolerance_w" => max(abs(reported), 1.0) * 1.0e-12,
        "status" => complete ? "complete" : "unknown_incomplete_solver_output_role",
        "ledger_hash" => canonical_hash(terms),
        "evidence_ceiling" => "L1_power_ledger_with_incomplete_recirculating_lower_bound")
end
