function _cppl_v1_upstream_heating(regional)
    outputs = get(get(regional.gate_statuses, "actuator_realization", Dict{String,Any}()),
        "outputs", Any[])
    selected = [item for item in outputs if String(get(item, "capability", "")) in
        ("deposited_energy_source", "current_or_flux_drive")]
    value = 0.0
    hashes = String[]
    reasons = String[]
    for item in selected
        actual = get(item, "actual_output", nothing)
        efficiency = get(item, "wall_plug_efficiency", nothing)
        if !(actual isa Real && efficiency isa Real && 0.0 < efficiency <= 1.0)
            push!(reasons, "heating actuator $(get(item, "actuator_id", "unknown")) lacks output or efficiency")
            continue
        end
        value += Float64(actual) / Float64(efficiency)
        push!(hashes, String(get(item, "output_hash", "")))
    end
    return (value = value, hashes = hashes, reasons = reasons,
        status = isempty(reasons) ? "complete" : "unknown")
end

function _cppl_v1_provider_records(engineering, plant)
    result = Dict{String,Dict{String,Any}}()
    for item in engineering.plant_power_roles
        result[String(item["role_id"])] = _cem_v1_dict(item)
    end
    for item in plant.plant_roles
        result[String(item["role_id"])] = _cem_v1_dict(item)
    end
    return result
end

function _cppl_v1_average(value, behavior, time_basis)
    value isa Real || return (value = nothing, energy_per_pulse_j = nothing, factor = nothing)
    if behavior == "pulse_active"
        String(time_basis["mode"]) == "cycle_average" ||
            return (value = Float64(value), energy_per_pulse_j = nothing, factor = 1.0)
        duration = Float64(time_basis["pulse_duration_s"])
        repetition = Float64(time_basis["repetition_rate_hz"])
        energy = Float64(value) * duration
        return (value = energy * repetition, energy_per_pulse_j = energy,
            factor = duration * repetition)
    end
    return (value = Float64(value), energy_per_pulse_j = nothing, factor = 1.0)
end

function _cppl_v1_legacy_power(value, time_basis)
    value isa Real || return nothing
    factor = String(time_basis["mode"]) == "cycle_average" ?
        Float64(time_basis["average_factor"]) : 1.0
    return Float64(value) * factor
end

"Aggregate every applicable plant role and close the net-power uncertainty interval."
function solve_complete_plant_power_ledger_v1(manifest::CandidateSolveManifestV1,
        regional::RegionSolveResultEnvelopeV1, transport,
        engineering::EngineeringMultiphysicsResultEnvelopeV1,
        plant_manifest::PlantSubsystemManifestV1,
        plant::PlantSubsystemResultEnvelopeV1)
    time_basis = deepcopy(plant.time_basis)
    coverage = Float64(plant_manifest.uncertainty_contract["coverage_sigma"])
    heating = _cppl_v1_upstream_heating(regional)
    providers = _cppl_v1_provider_records(engineering, plant)
    roles = Dict{String,Any}[]
    unresolved = String[]
    for id in PLANT_SUBSYSTEM_ROLE_IDS_V1
        applicability = _cem_v1_dict(plant_manifest.role_applicability[id])
        applicability_status = String(applicability["status"])
        behavior = String(applicability["time_behavior"])
        declared_u = Float64(applicability["relative_uncertainty"])
        if applicability_status == "not_applicable"
            role = Dict{String,Any}("role_id" => id, "value_w" => nothing,
                "status" => "not_applicable", "basis" => applicability["basis"],
                "provider" => applicability["provider"], "time_behavior" => behavior,
                "time_basis" => time_basis, "uncertainty_interval" =>
                    Dict("lower_w" => nothing, "upper_w" => nothing),
                "source_output_hashes" => String[])
            role["component_hash"] = canonical_hash(_csr_v1_json_safe(role))
            push!(roles, role)
            continue
        end
        provider = String(applicability["provider"])
        raw = if id == "heating_and_current_drive_wall_plug" &&
                provider == "regional_actuator"
            Dict{String,Any}("value_w" => heating.value, "status" => heating.status,
                "basis" => "realized deposited power divided by declared wall-plug efficiency",
                "source_output_hashes" => heating.hashes)
        else
            get(providers, id, Dict{String,Any}())
        end
        raw_status = String(get(raw, "status", "unknown"))
        value = get(raw, "value_w", nothing)
        averaged = _cppl_v1_average(value, behavior, time_basis)
        complete = raw_status == "complete" && averaged.value isa Real
        complete || push!(unresolved, id)
        runtime_interval = _cem_v1_dict(get(raw, "uncertainty_interval", nothing))
        runtime_relative = get(runtime_interval, "relative_one_sigma", nothing)
        relative = runtime_relative isa Real ? max(declared_u, Float64(runtime_relative)) : declared_u
        interval = complete ? _cpsr_v1_interval(averaged.value, relative, coverage) :
            Dict{String,Any}("lower_w" => nothing, "upper_w" => nothing)
        role = Dict{String,Any}("role_id" => id,
            "value_w" => averaged.value, "status" => complete ? "complete" : "unknown",
            "basis" => get(raw, "basis", applicability["basis"]), "provider" => provider,
            "time_behavior" => behavior, "time_conversion_factor" => averaged.factor,
            "energy_per_pulse_j" => averaged.energy_per_pulse_j,
            "time_basis" => time_basis, "uncertainty_interval" => interval,
            "source_output_hashes" => get(raw, "source_output_hashes",
                [engineering.result_hash, plant.result_hash]))
        role["component_hash"] = canonical_hash(_csr_v1_json_safe(role))
        push!(roles, role)
    end
    by_id = Dict(String(item["role_id"]) => item for item in roles)
    gross_role = by_id["gross_electric_generation"]
    direct_role = by_id["direct_energy_recovery"]
    gross = gross_role["status"] == "complete" ? Float64(gross_role["value_w"]) :
        gross_role["status"] == "not_applicable" ? 0.0 : nothing
    direct = direct_role["status"] == "complete" ? Float64(direct_role["value_w"]) :
        direct_role["status"] == "not_applicable" ? 0.0 : nothing
    recirculating_ids = setdiff(collect(PLANT_SUBSYSTEM_ROLE_IDS_V1),
        ["gross_electric_generation", "direct_energy_recovery"])
    recirculating_complete = all(id -> by_id[id]["status"] in ("complete", "not_applicable"),
        recirculating_ids)
    recirculating = recirculating_complete ? sum(Float64(by_id[id]["value_w"])
        for id in recirculating_ids if by_id[id]["status"] == "complete"; init = 0.0) : nothing
    all_complete = isempty(unresolved) && gross isa Real && direct isa Real &&
        recirculating isa Real
    net = all_complete ? gross + direct - recirculating : nothing
    gross_interval = gross_role["status"] == "not_applicable" ?
        Dict("lower_w" => 0.0, "upper_w" => 0.0) :
        _cem_v1_dict(get(gross_role, "uncertainty_interval", nothing))
    direct_interval = direct_role["status"] == "not_applicable" ?
        Dict("lower_w" => 0.0, "upper_w" => 0.0) :
        _cem_v1_dict(get(direct_role, "uncertainty_interval", nothing))
    recirc_lower = recirculating_complete ? sum(Float64(by_id[id]["uncertainty_interval"]["lower_w"])
        for id in recirculating_ids if by_id[id]["status"] == "complete"; init = 0.0) : nothing
    recirc_upper = recirculating_complete ? sum(Float64(by_id[id]["uncertainty_interval"]["upper_w"])
        for id in recirculating_ids if by_id[id]["status"] == "complete"; init = 0.0) : nothing
    net_lower = all_complete ? Float64(gross_interval["lower_w"]) +
        Float64(direct_interval["lower_w"]) - Float64(recirc_upper) : nothing
    net_upper = all_complete ? Float64(gross_interval["upper_w"]) +
        Float64(direct_interval["upper_w"]) - Float64(recirc_lower) : nothing
    sign_robust = all_complete && (net_lower > 0.0 || net_upper < 0.0)
    sign_status = !all_complete ? "unknown_incomplete_roles" : net_lower > 0.0 ?
        "positive_robust_interval" : net_upper < 0.0 ? "negative_robust_interval" :
        "unknown_interval_crosses_zero"
    status = !all_complete ? :unknown : net_upper < 0.0 ? :fail :
        net_lower > 0.0 ? :pass : :unknown
    fusion = _cppl_v1_legacy_power(get(transport, "fusion_power_w", nothing), time_basis)
    loss = _cppl_v1_legacy_power(get(transport, "loss_power_w", nothing), time_basis)
    drive_peak = sum(Float64(get(item, "actual_output", 0.0)) for item in
        get(get(regional.gate_statuses, "actuator_realization", Dict{String,Any}()),
            "outputs", Any[]) if String(get(item, "capability", "")) ==
            "deposited_energy_source"; init = 0.0)
    drive = _cppl_v1_legacy_power(drive_peak, time_basis)
    terms = Dict{String,Any}[
        Dict("role" => "fusion", "value_w" => fusion,
            "role_completeness" => fusion isa Real ? "complete" : "unknown",
            "source_output_hash" => String(get(transport, "solver_output_hash", ""))),
        Dict("role" => "drive", "value_w" => drive isa Real ? -drive : nothing,
            "role_completeness" => drive isa Real ? "complete" : "unknown",
            "source_output_hash" => regional.result_hash),
        Dict("role" => "loss", "value_w" => loss isa Real ? -loss : nothing,
            "role_completeness" => loss isa Real ? "complete" : "unknown",
            "source_output_hash" => String(get(transport, "solver_output_hash", ""))),
        Dict("role" => "recirculating", "value_w" => recirculating isa Real ?
            -recirculating : nothing, "role_completeness" => recirculating_complete ?
            "complete" : "unknown", "source_output_hash" => plant.result_hash)]
    closure = Dict{String,Any}("complete" => all_complete,
        "power_balance_residual_w" => all_complete ?
            abs(net - (gross + direct - recirculating)) : nothing,
        "tolerance_w" => all_complete ? max(abs(net), 1.0) * 1.0e-12 : nothing,
        "uncertainty_sign_robust" => sign_robust,
        "net_power_interval_w" => Dict("lower" => net_lower, "upper" => net_upper,
            "coverage_sigma" => coverage),
        "recirculating_interval_w" => Dict("lower" => recirc_lower, "upper" => recirc_upper),
        "unresolved_roles" => sort!(unique(unresolved)))
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => manifest.candidate_id, "physics_hash" => manifest.physics_hash,
        "state_result_hash" => regional.result_hash,
        "transport_result_hash" => String(get(transport, "solver_output_hash", "")),
        "engineering_result_hash" => engineering.result_hash,
        "coupled_result_hash" => plant.result_hash, "time_basis" => time_basis,
        "plant_roles" => roles, "terms" => terms,
        "gross_electric_power_w" => gross, "direct_recovery_power_w" => direct,
        "recirculating_power_w" => recirculating, "reported_net_power_w" => net,
        "status" => String(status), "sign_status" => sign_status, "closure" => closure,
        "evidence_ceiling" => "complete candidate-bound L1 plant ledger with uncertainty sign gate")
    hash = canonical_hash(_csr_v1_json_safe(body))
    return PlantPowerLedgerV1("1.0.0", manifest.candidate_id, manifest.physics_hash,
        regional.result_hash, body["transport_result_hash"], engineering.result_hash,
        plant.result_hash, time_basis, roles, terms, gross, direct, recirculating,
        net, status, sign_status, closure, body["evidence_ceiling"], hash)
end
