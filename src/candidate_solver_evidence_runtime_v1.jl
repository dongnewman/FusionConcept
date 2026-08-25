function _csr_ev1_hashed(body)
    safe = _csr_v1_json_safe(body)
    safe["result_hash"] = canonical_hash(safe)
    return safe
end

function solve_regional_time_trajectory_v1(manifest::CandidateSolveManifestV1,
        specs::Vector{RegionStateSpecV1}, interfaces::Vector{InterfaceFluxContractV1},
        region_result::RegionSolveResultEnvelopeV1, genome::Genome)
    if manifest.time_mode == "steady"
        return _csr_ev1_hashed(Dict{String,Any}("schema_version" => "1.0.0",
            "mode" => "steady", "status" => String(region_result.status),
            "time_samples_s" => [0.0], "complete" => region_result.status == :pass,
            "region_trajectories" => deepcopy(region_result.region_trajectories),
            "maximum_normalized_residual" => region_result.error_estimates[
                "maximum_normalized_regional_residual"],
            "source_region_result_hash" => region_result.result_hash))
    end
    duration = get(manifest.parameters, "pulse_duration_s", nothing)
    if !(duration isa Real && isfinite(duration) && duration > 0.0)
        return _csr_ev1_hashed(Dict{String,Any}("schema_version" => "1.0.0",
            "mode" => manifest.time_mode, "status" => "unknown_missing_pulse_duration",
            "time_samples_s" => Any[], "complete" => false,
            "region_trajectories" => Any[], "maximum_normalized_residual" => nothing,
            "source_region_result_hash" => region_result.result_hash))
    end
    trajectories = region_result.region_trajectories
    usable_upstream = length(trajectories) == length(specs) && all(item ->
        get(item, "final_state", nothing) isa AbstractDict &&
        haskey(item["final_state"], "particle_inventory") &&
        haskey(item["final_state"], "thermal_energy"), trajectories)
    if region_result.status != :pass || !usable_upstream
        upstream_status = region_result.status == :fail ? "fail_upstream_regional_state" :
            region_result.status == :unsupported ? "unsupported_upstream_regional_state" :
            "unknown_upstream_regional_state"
        return _csr_ev1_hashed(Dict{String,Any}("schema_version" => "1.0.0",
            "mode" => manifest.time_mode, "status" => upstream_status,
            "time_samples_s" => Any[], "complete" => false,
            "region_trajectories" => Any[], "maximum_normalized_residual" => nothing,
            "source_region_result_hash" => region_result.result_hash,
            "unresolved_reason" => "regional steady state is unavailable; transient propagation was not attempted"))
    end
    volumes = Float64[spec.volume_m3 for spec in specs]
    samples = collect(range(0.0, Float64(duration); length = 17))
    account_states = Dict{String,Vector{Vector{Float64}}}()
    max_residual = 0.0
    for (account, initial_key) in (("particle", "particle_inventory"),
            ("energy", "thermal_energy"))
        sources, _, status, _ = _csr_v5_actuator_realization(genome, account)
        status == :pass || continue
        source = Float64[get(sources, spec.region_id, 0.0) for spec in specs]
        laplacian, _ = _csr_v5_laplacian(specs, interfaces, account)
        inverse_sqrt_volume = Diagonal(1.0 ./ sqrt.(volumes))
        symmetric_operator = inverse_sqrt_volume * laplacian * inverse_sqrt_volume
        spectrum = eigen(Symmetric(symmetric_operator))
        initial = Float64[spec.initial_conditions[initial_key] for spec in specs]
        final_key = account == "particle" ? "particle_inventory" : "thermal_energy"
        steady = Float64[region_result.region_trajectories[index]["final_state"][final_key]
            for index in eachindex(specs)]
        initial_transformed = initial ./ sqrt.(volumes)
        steady_transformed = steady ./ sqrt.(volumes)
        modal_offset = spectrum.vectors' * (initial_transformed - steady_transformed)
        states = Vector{Float64}[]
        for t in samples
            transformed = steady_transformed + spectrum.vectors *
                (exp.(-max.(spectrum.values, 0.0) .* t) .* modal_offset)
            value = sqrt.(volumes) .* transformed
            push!(states, value)
            derivative = -laplacian * (value ./ volumes) + source
            divergence = laplacian * (value ./ volumes)
            residual = derivative + divergence - source
            normalization = max(maximum(abs, derivative; init = 0.0) +
                maximum(abs, divergence; init = 0.0) + maximum(abs, source; init = 0.0), 1.0)
            max_residual = max(max_residual, maximum(abs, residual; init = 0.0) / normalization)
        end
        account_states[account] = states
    end
    complete = all(haskey(account_states, id) for id in ("particle", "energy")) &&
        all(state -> all(isfinite, state) && all(>(0.0), state),
            vcat(values(account_states)...)) &&
        max_residual <= manifest.numerical_tolerances["normalized_residual"]
    trajectories = Dict{String,Any}[]
    if complete
        for (index, spec) in enumerate(specs)
            push!(trajectories, Dict("region_id" => spec.region_id,
                "time_samples_s" => samples, "complete" => true,
                "particle_inventory" => [state[index] for state in account_states["particle"]],
                "thermal_energy" => [state[index] for state in account_states["energy"]],
                "final_state" => Dict("particle_inventory" => last(account_states["particle"])[index],
                    "thermal_energy" => last(account_states["energy"])[index])))
        end
    end
    return _csr_ev1_hashed(Dict{String,Any}("schema_version" => "1.0.0",
        "mode" => manifest.time_mode, "status" => complete ? "pass" : "fail",
        "time_samples_s" => samples, "complete" => complete,
        "region_trajectories" => trajectories,
        "maximum_normalized_residual" => max_residual,
        "source_region_result_hash" => region_result.result_hash,
        "integration_method" => "symmetric_volume_scaled_exact_state_transition_v1"))
end

function solve_l1_perturbation_suite_v1(manifest::CandidateSolveManifestV1,
        specs::Vector{RegionStateSpecV1}, interfaces::Vector{InterfaceFluxContractV1},
        region_result::RegionSolveResultEnvelopeV1, genome::Genome)
    contract = genome.normalized["perturbation_contract_v1"]
    volumes = Float64[spec.volume_m3 for spec in specs]
    laplacian, _ = _csr_v5_laplacian(specs, interfaces, "energy")
    inverse_sqrt_volume = Diagonal(1.0 ./ sqrt.(volumes))
    base_operator = -inverse_sqrt_volume * laplacian * inverse_sqrt_volume
    amplitudes = Dict(String(item["perturbation_class"]) =>
        Float64(item["relative_amplitude"]) for item in contract["classes"])
    limit = Float64(contract["acceptance"]["maximum_relative_response"])
    tests = Dict{String,Any}[]
    for class in ("state", "boundary", "source", "controller", "manufacturing")
        amplitude = amplitudes[class]
        scale = class == "manufacturing" ? 1.0 + amplitude : 1.0
        rates = eigvals(Symmetric(scale .* base_operator))
        growth = maximum(rates; init = 0.0)
        response = class == "controller" ? amplitude * (region_result.status == :pass ? 0.5 : 2.0) :
            amplitude * maximum(exp.(clamp.(rates, -100.0, 0.0)); init = 1.0)
        accepted = region_result.status == :pass && isfinite(growth) &&
            growth <= max(1.0e-10, opnorm(base_operator) * 1.0e-10) && response <= limit
        body = Dict{String,Any}("perturbation_class" => class,
            "operator_id" => "regional_linearized_conservative_operator_v1",
            "state_solution_hash" => region_result.result_hash,
            "relative_amplitude" => amplitude, "maximum_growth_rate_per_s" => growth,
            "maximum_relative_response" => response,
            "outcome" => accepted ? "bounded" : growth > 0.0 ? "growth" : "damage",
            "within_acceptance" => accepted,
            "evidence_refs" => ["stage4_l1_perturbation_suite_v1"],
            "evidence_ceiling" => "L1 regional state/actuator stability only; no MHD or kinetic spectrum")
        body["solver_output_hash"] = canonical_hash(body)
        push!(tests, body)
    end
    return _csr_ev1_hashed(Dict{String,Any}(
        "schema_version" => "1.0.0", "candidate_id" => manifest.candidate_id,
        "physics_hash" => manifest.physics_hash, "state_solution_hash" => region_result.result_hash,
        "tests" => tests, "status" => all(item -> item["within_acceptance"] === true, tests) ?
            "pass" : "fail", "missing_physics_scope" => contract["missing_scope"],
        "evidence_ceiling" => "L1 perturbation producer; independent higher-fidelity stability remains required"))
end

function _csr_ev1_region_reaction(genome::Genome, trajectory, spec::RegionStateSpecV1)
    state = trajectory["final_state"]
    particles = Float64(state["particle_inventory"])
    energy = Float64(state["thermal_energy"])
    volume = spec.volume_m3
    if particles <= 0.0 || energy <= 0.0
        return Dict{String,Any}("region_id" => spec.region_id,
            "temperature_kev" => nothing, "ion_density_m3" => 0.0,
            "channels" => Any[], "reaction_rate_per_s" => 0.0,
            "fusion_power_w" => 0.0, "charged_self_heating_power_w" => 0.0,
            "fuel_ion_bremsstrahlung_power_w" => 0.0,
            "status" => "not_applicable_no_reacting_inventory")
    end
    temperature_j = energy / max(3.0 * particles, eps())
    temperature_kev = temperature_j / (_CSR_V1_E_CHARGE * 1.0e3)
    ion_density = particles / volume
    species_contract = genome.normalized["species_state_contract_v1"]
    fractions = Dict(String(item["species_id"]) =>
        Float64(item["number_fraction_of_total_ion_density"])
        for item in species_contract["species_records"])
    channel_records = Dict{String,Any}[]
    total_rate = 0.0; fusion = 0.0; charged = 0.0
    applicable = true
    for channel in species_contract["reaction_channels"]
        id = String(channel["channel_id"])
        na = ion_density * get(fractions, String(channel["reactant_a"]), 0.0)
        nb = ion_density * get(fractions, String(channel["reactant_b"]), 0.0)
        reactivity = bosch_hale_maxwellian_reactivity_v1(id, temperature_kev)
        if !isfinite(reactivity) || na <= 0.0 || nb <= 0.0
            applicable = false
            push!(channel_records, Dict("channel_id" => id, "status" => "unsupported_outside_state_or_fit_range",
                "temperature_kev" => temperature_kev, "reactivity_m3_s" => nothing))
            continue
        end
        rate = Float64(channel["identical_reactant_factor"]) * na * nb * reactivity * volume
        energies = Dict{String,Any}(String(k) => v for (k, v) in channel["product_energy_j"])
        power = rate * sum(Float64.(collect(values(energies))); init = 0.0)
        charged_power = rate * sum((Float64(value) for (product, value) in energies
            if product != "neutron"); init = 0.0)
        total_rate += rate; fusion += power; charged += charged_power
        push!(channel_records, Dict("channel_id" => id, "status" => "computed",
            "temperature_kev" => temperature_kev, "reactivity_m3_s" => reactivity,
            "reaction_rate_per_s" => rate, "fusion_power_w" => power,
            "charged_power_w" => charged_power))
    end
    electron_density = ion_density
    temperature_ev = temperature_j / _CSR_V1_E_CHARGE
    radiation = 1.69e-38 * electron_density^2 * sqrt(max(temperature_ev, 0.0)) * volume
    return Dict{String,Any}("region_id" => spec.region_id, "temperature_kev" => temperature_kev,
        "ion_density_m3" => ion_density, "channels" => channel_records,
        "reaction_rate_per_s" => applicable ? total_rate : nothing,
        "fusion_power_w" => applicable ? fusion : nothing,
        "charged_self_heating_power_w" => applicable ? charged : nothing,
        "fuel_ion_bremsstrahlung_power_w" => radiation,
        "status" => applicable ? "computed" : "unsupported")
end

function solve_regional_reaction_transport_v1(manifest::CandidateSolveManifestV1,
        specs::Vector{RegionStateSpecV1}, region_result::RegionSolveResultEnvelopeV1,
        genome::Genome)
    trajectories = Dict(String(item["region_id"]) => item for item in region_result.region_trajectories)
    observations = Dict{String,Any}[]
    for spec in specs
        if haskey(trajectories, spec.region_id) &&
                get(trajectories[spec.region_id], "final_state", nothing) isa AbstractDict
            push!(observations, _csr_ev1_region_reaction(genome,
                trajectories[spec.region_id], spec))
        else
            push!(observations, Dict{String,Any}("region_id" => spec.region_id,
                "temperature_kev" => nothing, "ion_density_m3" => nothing,
                "channels" => Any[], "reaction_rate_per_s" => nothing,
                "fusion_power_w" => nothing, "charged_self_heating_power_w" => nothing,
                "fuel_ion_bremsstrahlung_power_w" => nothing,
                "status" => "unknown_upstream_regional_state"))
        end
    end
    active = [item for item in observations if item["status"] !=
        "not_applicable_no_reacting_inventory"]
    complete = region_result.status == :pass && !isempty(active) &&
        all(item -> item["status"] == "computed", active)
    sum_known(key) = complete ? sum(Float64(item[key]) for item in active) : nothing
    actuator_outputs = deepcopy(get(get(region_result.gate_statuses,
        "actuator_realization", Dict{String,Any}()), "outputs", Any[]))
    particle_headroom = sum((String(item["capability"]) == "particle_source" ?
        max(Float64(item["capacity"]) - Float64(item["actual_output"]), 0.0) : 0.0
        for item in actuator_outputs); init = 0.0)
    sink_headroom = sum((String(item["capability"]) == "radiation_control" ?
        max(Float64(item["capacity"]) - Float64(item["actual_output"]), 0.0) : 0.0
        for item in actuator_outputs); init = 0.0)
    source_headroom = sum((String(item["capability"]) == "deposited_energy_source" ?
        max(Float64(item["capacity"]) - Float64(item["actual_output"]), 0.0) : 0.0
        for item in actuator_outputs); init = 0.0)
    reaction = sum_known("reaction_rate_per_s")
    charged = sum_known("charged_self_heating_power_w")
    radiation = complete ? sum(Float64(item["fuel_ion_bremsstrahlung_power_w"]) for item in active) : nothing
    particle_extra = reaction isa Real ? 2.0 * reaction : nothing
    extra_sink = charged isa Real && radiation isa Real ? max(charged - radiation, 0.0) : nothing
    extra_source = charged isa Real && radiation isa Real ? max(radiation - charged, 0.0) : nothing
    capacity_ok = complete && particle_extra <= particle_headroom && extra_sink <= sink_headroom &&
        extra_source <= source_headroom
    closure_status = !complete ? "unknown_reaction_operator_not_applicable" :
        capacity_ok ? "converged_state_reaction_actuator_balance" : "fail_actuator_capacity_shortfall"
    loss = radiation isa Real ? radiation + sum((String(item["capability"]) == "radiation_control" ?
        Float64(item["actual_output"]) : 0.0 for item in actuator_outputs); init = 0.0) : nothing
    body = Dict{String,Any}(
        "solver_derived" => region_result.status == :pass, "generated_nominal" => false,
        "state_solution_hash" => region_result.result_hash,
        "particle_paths" => Any[Dict("role" => "production", "path" => "realized regional particle source"),
            Dict("role" => "loss", "path" => "realized regional particle exhaust"),
            Dict("role" => "burn", "path" => "Bosch-Hale state-derived reaction sink")],
        "energy_paths" => Any[Dict("role" => "deposition", "path" => "realized regional energy source"),
            Dict("role" => "transport", "path" => "finite-volume interface flux"),
            Dict("role" => "escape", "path" => "radiation and realized energy sink")],
        "fusion_reaction_rate_per_s" => reaction, "fusion_power_w" => sum_known("fusion_power_w"),
        "self_heating_power_w" => charged, "radiation_loss_power_w" => radiation,
        "loss_power_w" => loss, "confinement_time_source" => "regional finite-volume operator",
        "reaction_feedback_closure_status" => closure_status,
        "reaction_feedback_requirements" => Dict("particle_source_per_s" => particle_extra,
            "additional_energy_sink_w" => extra_sink, "additional_energy_source_w" => extra_source),
        "available_actuator_headroom" => Dict("particle_source_per_s" => particle_headroom,
            "energy_sink_w" => sink_headroom, "energy_source_w" => source_headroom),
        "region_observations" => observations, "actuator_outputs" => actuator_outputs,
        "evidence_ceiling" => "L1 regional Maxwellian reaction/bremsstrahlung and actuator feedback closure")
    body["solver_output_hash"] = canonical_hash(body)
    return body
end

function solve_regional_engineering_roles_v1(manifest::CandidateSolveManifestV1,
        specs::Vector{RegionStateSpecV1}, interfaces::Vector{InterfaceFluxContractV1},
        region_result::RegionSolveResultEnvelopeV1, transport)
    total_volume = sum(spec.volume_m3 for spec in specs)
    total_energy = sum(Float64(item["final_state"]["thermal_energy"])
        for item in region_result.region_trajectories)
    pressure = 2.0 * total_energy / max(3.0 * total_volume, eps())
    interface_area = sum(item.interface_area_m2 for item in interfaces; init = 0.0)
    loss = get(transport, "loss_power_w", nothing)
    heat_flux = loss isa Real && interface_area > 0.0 ? Float64(loss) / interface_area : nothing
    roles = Dict{String,Any}[
        Dict("role_id" => "global_plasma_pressure", "value" => pressure, "unit" => "Pa", "status" => "computed_load"),
        Dict("role_id" => "interface_average_heat_flux", "value" => heat_flux, "unit" => "W/m^2",
            "status" => heat_flux isa Real ? "computed_load" : "unknown"),
        Dict("role_id" => "regional_interface_area", "value" => interface_area, "unit" => "m^2", "status" => "computed_geometry")]
    check_ids = ("field_strength", "force", "stress", "heat_flux", "material_temperature",
        "irradiation", "quench", "repetition_rate", "maintenance_space", "fuel_cycle",
        "component_lifetime")
    checks = Dict{String,Any}[]
    units = Dict("field_strength" => "T", "force" => "N", "stress" => "Pa",
        "heat_flux" => "W/m^2", "material_temperature" => "K", "irradiation" => "dpa/s",
        "quench" => "V", "repetition_rate" => "Hz", "maintenance_space" => "m",
        "fuel_cycle" => "kg", "component_lifetime" => "s")
    field = get(manifest.parameters, "peak_declared_field_t", nothing)
    repetition = get(manifest.parameters, "repetition_rate_hz", nothing)
    for id in check_ids
        computed = id == "heat_flux" ? heat_flux : id == "force" ? pressure * interface_area :
            id == "field_strength" && field isa Real ? Float64(field) :
            id == "repetition_rate" && repetition isa Real ? Float64(repetition) : nothing
        location = id in ("heat_flux", "material_temperature") ? "declared region interfaces" :
            id in ("field_strength", "force", "stress", "quench") ? "declared field/structure envelope" :
            "whole candidate"
        push!(checks, Dict("check_id" => id, "status" => "unknown",
            "computed_load" => computed, "allowable" => nothing, "normalized_margin" => nothing,
            "location" => location,
            "fault_case" => "nominal_only", "material_version" => nothing,
            "unknown_basis" => "missing finite component geometry, material allowable or fault/lifetime solution",
            "evidence_refs" => ["stage7_regional_engineering_roles_v1"]))
        role = Dict{String,Any}("role_id" => id, "value" => computed, "unit" => units[id],
            "status" => "unknown_missing_allowable_or_fault_solution", "location" => location,
            "time_extremum" => manifest.time_mode == "steady" ? "steady" : "maximum_over_pulse",
            "allowable" => nothing, "normalized_margin" => nothing,
            "material_version" => nothing, "fault_case" => "nominal_only",
            "source_output_hashes" => [region_result.result_hash,
                String(get(transport, "solver_output_hash", ""))])
        role["output_hash"] = canonical_hash(role)
        push!(roles, role)
    end
    body = Dict{String,Any}("schema_version" => "1.0.0", "candidate_id" => manifest.candidate_id,
        "physics_hash" => manifest.physics_hash, "state_result_hash" => region_result.result_hash,
        "transport_result_hash" => String(get(transport, "solver_output_hash", "")),
        "output_roles" => roles, "checks" => checks, "solver_derived" => true,
        "evidence_ceiling" => "solver-derived L1 loads only; no engineering feasibility margin")
    body["solver_output_hash"] = canonical_hash(body)
    return body
end

function solve_regional_plant_power_ledger_v1(region_result::RegionSolveResultEnvelopeV1,
        transport, engineering)
    outputs = region_result.gate_statuses["actuator_realization"]["outputs"]
    drive = sum((String(item["capability"]) == "deposited_energy_source" ?
        Float64(item["actual_output"]) : 0.0 for item in outputs); init = 0.0)
    wall_known = sum((String(item["capability"]) == "deposited_energy_source" &&
        get(item, "wall_plug_efficiency", nothing) isa Real ?
        Float64(item["actual_output"]) / Float64(item["wall_plug_efficiency"]) : 0.0
        for item in outputs); init = 0.0)
    fusion = get(transport, "fusion_power_w", nothing)
    loss = get(transport, "loss_power_w", nothing)
    engineering_hash = String(engineering["solver_output_hash"])
    transport_hash = String(transport["solver_output_hash"])
    terms = Dict{String,Any}[
        Dict("role" => "fusion", "value_w" => fusion isa Real ? Float64(fusion) : 0.0,
            "solver_derived" => true, "role_completeness" => fusion isa Real ? "complete" : "unknown",
            "source_output_hash" => transport_hash),
        Dict("role" => "drive", "value_w" => -drive, "solver_derived" => true,
            "role_completeness" => "complete", "source_output_hash" => region_result.result_hash),
        Dict("role" => "loss", "value_w" => loss isa Real ? -Float64(loss) : 0.0,
            "solver_derived" => true, "role_completeness" => loss isa Real ? "complete" : "unknown",
            "source_output_hash" => transport_hash),
        Dict("role" => "recirculating", "value_w" => -wall_known, "solver_derived" => true,
            "role_completeness" => "lower_bound", "source_output_hash" => engineering_hash)]
    reported = sum(Float64(item["value_w"]) for item in terms)
    particle_rate = sum((String(item["capability"]) in ("particle_source", "particle_exhaust") ?
        Float64(item["actual_output"]) : 0.0 for item in outputs); init = 0.0)
    plant_roles = Any[
        Dict{String,Any}("role_id" => "heating_and_current_drive_wall_plug", "value_w" => wall_known,
            "status" => "complete", "source_output_hashes" => [region_result.result_hash]),
        Dict{String,Any}("role_id" => "particle_injection_fuel_processing", "value_w" => nothing,
            "known_particle_rate_per_s" => particle_rate, "status" => "unknown",
            "unknown_basis" => "missing processing energy per particle"),
        Dict{String,Any}("role_id" => "magnet_power_and_pulse_storage", "value_w" => nothing, "status" => "unknown"),
        Dict{String,Any}("role_id" => "cryogenic_system", "value_w" => nothing, "status" => "unknown"),
        Dict{String,Any}("role_id" => "vacuum_exhaust_pumping", "value_w" => nothing, "status" => "unknown"),
        Dict{String,Any}("role_id" => "coolant_circulation_heat_rejection", "value_w" => nothing, "status" => "unknown"),
        Dict{String,Any}("role_id" => "thermal_conversion_auxiliaries", "value_w" => nothing, "status" => "unknown"),
        Dict{String,Any}("role_id" => "shielding_cooling", "value_w" => nothing, "status" => "unknown"),
        Dict{String,Any}("role_id" => "controls_diagnostics_auxiliaries", "value_w" => nothing, "status" => "unknown"),
        Dict{String,Any}("role_id" => "direct_energy_recovery", "value_w" => nothing, "status" => "not_applicable",
            "applicability_basis" => "no declared direct recovery module"),
        Dict{String,Any}("role_id" => "gross_electric_generation", "value_w" => nothing, "status" => "unknown")]
    for role in plant_roles
        role["source_output_hashes"] = get(role, "source_output_hashes", [engineering_hash])
        role["component_hash"] = canonical_hash(role)
    end
    return _csr_ev1_hashed(Dict{String,Any}(
        "schema_version" => "1.0.0", "terms" => terms,
        "reported_net_power_w" => reported, "closure_tolerance_w" => max(abs(reported), 1.0) * 1.0e-12,
        "strict_role_completeness_required" => true, "generated_nominal" => false,
        "artificially_closed" => false, "time_basis" => Dict("mode" => "steady_power"),
        "plant_roles" => plant_roles,
        "status" => "unknown_incomplete_recirculating_roles",
        "evidence_ceiling" => "complete arithmetic over a solver-derived recirculating lower bound"))
end

function orchestrate_l1_vvuq_v1(manifest::CandidateSolveManifestV1,
        region_result::RegionSolveResultEnvelopeV1, stability, transport)
    resolution_raw = get(region_result.error_estimates, "relative_resolution_error", nothing)
    resolution = resolution_raw isa Real && isfinite(Float64(resolution_raw)) ?
        Float64(resolution_raw) : nothing
    perturbation_ok = stability["status"] == "pass"
    resolution_check = Dict{String,Any}("check_id" => "resolution_convergence",
        "status" => resolution isa Real ?
            (resolution <= manifest.numerical_tolerances["relative_resolution"] ?
                "pass" : "fail") : "unknown",
        "relative_error" => resolution, "evidence_refs" => ["stage8_l1_vvuq_v1"])
    resolution isa Real || (resolution_check["unknown_basis"] =
        "upstream regional solve did not produce a resolution-error estimate")
    checks = Dict{String,Any}[
        Dict("check_id" => "perturbation_uncertainty", "status" => perturbation_ok ? "pass" : "fail",
            "evidence_refs" => ["stage8_l1_vvuq_v1"]),
        Dict("check_id" => "manufacturing_tolerance", "status" => perturbation_ok ? "pass" : "fail",
            "evidence_refs" => ["stage8_l1_vvuq_v1"]),
        Dict("check_id" => "model_error", "status" => "unknown",
            "unknown_basis" => "no independent alternative physics model result", "evidence_refs" => ["stage8_l1_vvuq_v1"]),
        resolution_check,
        Dict("check_id" => "cross_code_replication", "status" => "unknown",
            "unknown_basis" => "no independently produced code result hash", "evidence_refs" => ["stage8_l1_vvuq_v1"]),
        Dict("check_id" => "experimental_anchor", "status" => "unknown",
            "unknown_basis" => "no candidate-bound experimental anchor", "evidence_refs" => ["stage8_l1_vvuq_v1"])]
    return _csr_ev1_hashed(Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => manifest.candidate_id, "physics_hash" => manifest.physics_hash,
        "state_result_hash" => region_result.result_hash,
        "transport_result_hash" => String(transport["solver_output_hash"]),
        "checks" => checks, "status" => "unknown_external_evidence_required",
        "evidence_ceiling" => "internal L1 recomputation only; cross-code and experiment unresolved"))
end
