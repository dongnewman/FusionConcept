const LONGITUDINAL_STATE_IDS_V1 = ["fuel_a_inventory", "fuel_b_inventory",
    "electron_inventory", "ion_thermal_energy", "electron_thermal_energy",
    "fueling_output", "ion_heating_output", "electron_heating_output",
    "exhaust_output", "radiation_control_output"]

const LONGITUDINAL_REQUIRED_PARAMETERS_V1 = Set([
    "charge_a", "charge_b", "particle_scale", "energy_scale", "particle_rate_scale",
    "power_scale", "particle_transport_a_s", "particle_transport_b_s",
    "ion_energy_loss_s", "electron_energy_loss_s", "reaction_coefficient_per_particle_s",
    "reaction_energy_j", "alpha_ion_fraction", "alpha_electron_fraction",
    "radiation_coefficient_per_particle_s", "ion_electron_exchange_rate_s",
    "fuel_fraction_a", "fuel_fraction_b", "exhaust_fraction_a", "exhaust_fraction_b",
    "fueling_capacity_s", "ion_heating_capacity_w", "electron_heating_capacity_w",
    "exhaust_capacity_s", "radiation_control_capacity_w", "fueling_baseline_s",
    "ion_heating_baseline_w", "electron_heating_baseline_w", "exhaust_baseline_s",
    "radiation_control_baseline_w", "target_particle_inventory", "target_ion_energy_j",
    "target_electron_energy_j", "fueling_controller_gain_s", "ion_heating_controller_gain_s",
    "electron_heating_controller_gain_s", "exhaust_controller_gain_s",
    "radiation_controller_gain_s", "ion_heating_deposition_efficiency",
    "electron_heating_deposition_efficiency", "fueling_wall_energy_j_per_particle",
    "exhaust_wall_energy_j_per_particle", "ion_heating_wall_plug_efficiency",
    "electron_heating_wall_plug_efficiency", "radiation_control_wall_plug_efficiency",
    "electric_conversion_efficiency"])

"Candidate-bound two-species, two-temperature, transport/burn/actuator control volume."
struct CandidateLongitudinalBalanceModuleV1 <: AbstractResidualPhysicsModuleV1
    module_id::String
    region_id::String
    transport_operator_id::String
    parameters::Dict{String,Float64}
    parameter_evidence::Dict{String,String}
    external_term_ids::Set{Symbol}
end

function CandidateLongitudinalBalanceModuleV1(; module_id, region_id,
        transport_operator_id, parameters, parameter_evidence = Dict{String,String}(),
        external_term_ids = Symbol[])
    values = Dict{String,Float64}(String(key) => Float64(value)
        for (key, value) in parameters)
    external = Set(Symbol.(external_term_ids))
    allowed_external = Set((:fusion_reaction, :fuel_ion_bremsstrahlung,
        :transport_response))
    isempty(setdiff(external, allowed_external)) || throw(ArgumentError(
        "unsupported external longitudinal term ownership"))
    externally_owned_parameters = Set{String}()
    :fusion_reaction in external && union!(externally_owned_parameters,
        ["reaction_coefficient_per_particle_s", "reaction_energy_j"])
    :fuel_ion_bremsstrahlung in external && push!(externally_owned_parameters,
        "radiation_coefficient_per_particle_s")
    :transport_response in external && union!(externally_owned_parameters,
        ["particle_transport_a_s", "particle_transport_b_s",
            "ion_energy_loss_s", "electron_energy_loss_s"])
    required = setdiff(LONGITUDINAL_REQUIRED_PARAMETERS_V1,
        externally_owned_parameters)
    missing = setdiff(required, Set(keys(values)))
    isempty(missing) || throw(ArgumentError(
        "missing longitudinal parameters: $(join(sort!(collect(missing)), ", "))"))
    evidence = Dict{String,String}(String(key) => String(value)
        for (key, value) in parameter_evidence)
    return CandidateLongitudinalBalanceModuleV1(String(module_id), String(region_id),
        String(transport_operator_id), values, evidence, external)
end

residual_module_id(module_instance::CandidateLongitudinalBalanceModuleV1) =
    module_instance.module_id

coupled_term_contract(module_instance::CandidateLongitudinalBalanceModuleV1) =
    Dict{String,Any}("expected_term_ids" =>
        sort!(String.(collect(module_instance.external_term_ids))),
        "provided_term_ids" => String[])

function state_layout(module_instance::CandidateLongitudinalBalanceModuleV1,
        manifest::CandidateSolveManifestV1)
    p = module_instance.parameters
    units = ["particle", "particle", "particle", "J", "J", "particle/s",
        "W", "W", "particle/s", "W"]
    residual_units = ["particle/s", "particle/s", "particle", "W", "W",
        "particle/s", "W", "W", "particle/s", "W"]
    scales = [p["particle_scale"], p["particle_scale"], p["particle_scale"],
        p["energy_scale"], p["energy_scale"], p["particle_rate_scale"],
        p["power_scale"], p["power_scale"], p["particle_rate_scale"], p["power_scale"]]
    lower = [1.0e-12 * p["particle_scale"], 1.0e-12 * p["particle_scale"],
        1.0e-12 * p["particle_scale"], 1.0e-12 * p["energy_scale"],
        1.0e-12 * p["energy_scale"], 0.0, 0.0, 0.0, 0.0, 0.0]
    upper = [floatmax(Float64), floatmax(Float64), floatmax(Float64),
        floatmax(Float64), floatmax(Float64), p["fueling_capacity_s"],
        p["ion_heating_capacity_w"], p["electron_heating_capacity_w"],
        p["exhaust_capacity_s"], p["radiation_control_capacity_w"]]
    return [StateBlockSpecV1(module_instance.module_id, "longitudinal_state",
        module_instance.region_id, copy(LONGITUDINAL_STATE_IDS_V1), units, residual_units,
        scales, lower, upper, 0, ["steady", "transient", "pulsed"])]
end

function residual_contracts(module_instance::CandidateLongitudinalBalanceModuleV1,
        manifest::CandidateSolveManifestV1)
    return [ResidualBlockContractV1(module_instance.module_id,
        "longitudinal_particle_energy_species_actuator_balance", :governing,
        copy(LONGITUDINAL_STATE_IDS_V1),
        ["particle/s", "particle/s", "particle", "W", "W", "particle/s",
            "W", "W", "particle/s", "W"],
        copy(LONGITUDINAL_STATE_IDS_V1), [module_instance.region_id], String[],
        Dict{String,Any}[], ["fueling_output", "ion_heating_output",
            "electron_heating_output", "exhaust_output", "radiation_control_output"])]
end

function jacobian_contracts(module_instance::CandidateLongitudinalBalanceModuleV1,
        manifest::CandidateSolveManifestV1)
    return [JacobianBlockContractV1(module_instance.module_id,
        "longitudinal_particle_energy_species_actuator_balance", :analytic,
        copy(LONGITUDINAL_STATE_IDS_V1), copy(LONGITUDINAL_STATE_IDS_V1), 3.0e-6, 1.0e-8)]
end

function mass_matrix_contracts(module_instance::CandidateLongitudinalBalanceModuleV1,
        manifest::CandidateSolveManifestV1)
    kinds = [:differential, :differential, :algebraic, :differential, :differential,
        :algebraic, :algebraic, :algebraic, :algebraic, :algebraic]
    return [MassMatrixBlockContractV1(module_instance.module_id, "longitudinal_mass",
        copy(LONGITUDINAL_STATE_IDS_V1), kinds)]
end

function _longitudinal_evidence_gaps_v1(module_instance)
    externally_owned_parameters = Set{String}()
    :fusion_reaction in module_instance.external_term_ids && union!(
        externally_owned_parameters,
        ["reaction_coefficient_per_particle_s", "reaction_energy_j"])
    :fuel_ion_bremsstrahlung in module_instance.external_term_ids && push!(
        externally_owned_parameters, "radiation_coefficient_per_particle_s")
    :transport_response in module_instance.external_term_ids && union!(
        externally_owned_parameters, ["particle_transport_a_s",
            "particle_transport_b_s", "ion_energy_loss_s",
            "electron_energy_loss_s"])
    return sort!(String[key for key in setdiff(LONGITUDINAL_REQUIRED_PARAMETERS_V1,
            externally_owned_parameters)
        if get(module_instance.parameter_evidence, key, "unknown") != "complete"])
end

function validity_domain(module_instance::CandidateLongitudinalBalanceModuleV1)
    p = module_instance.parameters
    gaps = _longitudinal_evidence_gaps_v1(module_instance)
    fractions = [("fuel", p["fuel_fraction_a"] + p["fuel_fraction_b"]),
        ("exhaust", p["exhaust_fraction_a"] + p["exhaust_fraction_b"]),
        ("alpha", p["alpha_ion_fraction"] + p["alpha_electron_fraction"])]
    invalid = String[]
    for (id, value) in fractions
        isapprox(value, 1.0; atol = 1.0e-10, rtol = 0.0) || push!(invalid,
            "$(id)_fractions_do_not_sum_to_one")
    end
    for key in ("ion_heating_deposition_efficiency", "electron_heating_deposition_efficiency",
            "ion_heating_wall_plug_efficiency", "electron_heating_wall_plug_efficiency",
            "radiation_control_wall_plug_efficiency", "electric_conversion_efficiency")
        0.0 < p[key] <= 1.0 || push!(invalid, "invalid_efficiency:$key")
    end
    status = !isempty(invalid) ? "unsupported" : isempty(gaps) ? "applicable" : "unknown"
    reason = !isempty(invalid) ? join(invalid, ";") : isempty(gaps) ?
        "candidate_bound_parameter_domain_covered" :
        "parameter_evidence_incomplete:$(join(gaps, ","))"
    return Dict{String,Any}("status" => status, "reason" => reason,
        "transport_operator_id" => module_instance.transport_operator_id,
        "parameter_evidence_gaps" => gaps)
end

applicability(module_instance::CandidateLongitudinalBalanceModuleV1,
    manifest::CandidateSolveManifestV1) = validity_domain(module_instance)

function _longitudinal_state_v1(module_instance, u, context)
    p = module_instance.parameters
    index = context["state_index"]
    value(id) = u[index[id]]
    na = value("fuel_a_inventory"); nb = value("fuel_b_inventory")
    ne = value("electron_inventory"); wi = value("ion_thermal_energy")
    we = value("electron_thermal_energy"); xf = value("fueling_output")
    xhi = value("ion_heating_output"); xhe = value("electron_heating_output")
    xe = value("exhaust_output"); xr = value("radiation_control_output")
    burn = :fusion_reaction in module_instance.external_term_ids ? 0.0 :
        p["reaction_coefficient_per_particle_s"] * na * nb
    reaction_power = :fusion_reaction in module_instance.external_term_ids ? 0.0 :
        burn * p["reaction_energy_j"]
    radiation = :fuel_ion_bremsstrahlung in module_instance.external_term_ids ? 0.0 :
        p["radiation_coefficient_per_particle_s"] * ne * we
    transport_a = :transport_response in module_instance.external_term_ids ? 0.0 :
        p["particle_transport_a_s"]
    transport_b = :transport_response in module_instance.external_term_ids ? 0.0 :
        p["particle_transport_b_s"]
    ion_loss = :transport_response in module_instance.external_term_ids ? 0.0 :
        p["ion_energy_loss_s"]
    electron_loss = :transport_response in module_instance.external_term_ids ? 0.0 :
        p["electron_energy_loss_s"]
    exchange = p["ion_electron_exchange_rate_s"] * (wi - we)
    total_particles = na + nb
    fuel_demand = p["fueling_baseline_s"] + p["fueling_controller_gain_s"] *
        (p["target_particle_inventory"] - total_particles)
    ion_heat_demand = p["ion_heating_baseline_w"] +
        p["ion_heating_controller_gain_s"] * (p["target_ion_energy_j"] - wi)
    electron_heat_demand = p["electron_heating_baseline_w"] +
        p["electron_heating_controller_gain_s"] * (p["target_electron_energy_j"] - we)
    exhaust_demand = p["exhaust_baseline_s"] + p["exhaust_controller_gain_s"] *
        (total_particles - p["target_particle_inventory"])
    radiation_demand = p["radiation_control_baseline_w"] +
        p["radiation_controller_gain_s"] * (we - p["target_electron_energy_j"])
    realized_fuel = clamp(fuel_demand, 0.0, p["fueling_capacity_s"])
    realized_hi = clamp(ion_heat_demand, 0.0, p["ion_heating_capacity_w"])
    realized_he = clamp(electron_heat_demand, 0.0, p["electron_heating_capacity_w"])
    realized_exhaust = clamp(exhaust_demand, 0.0, p["exhaust_capacity_s"])
    realized_radiation = clamp(radiation_demand, 0.0, p["radiation_control_capacity_w"])
    return (; na, nb, ne, wi, we, xf, xhi, xhe, xe, xr, burn, reaction_power,
        radiation, exchange, transport_a, transport_b, ion_loss, electron_loss,
        total_particles, fuel_demand, ion_heat_demand,
        electron_heat_demand, exhaust_demand, radiation_demand, realized_fuel,
        realized_hi, realized_he, realized_exhaust, realized_radiation)
end

function residual_block!(r, module_instance::CandidateLongitudinalBalanceModuleV1,
        u, du, parameters, t, context)
    p = module_instance.parameters
    q = _longitudinal_state_v1(module_instance, u, context)
    index = context["state_index"]
    r[1] = du[index["fuel_a_inventory"]] + q.transport_a * q.na +
        q.burn - p["fuel_fraction_a"] * q.xf + p["exhaust_fraction_a"] * q.xe
    r[2] = du[index["fuel_b_inventory"]] + q.transport_b * q.nb +
        q.burn - p["fuel_fraction_b"] * q.xf + p["exhaust_fraction_b"] * q.xe
    r[3] = q.ne - p["charge_a"] * q.na - p["charge_b"] * q.nb
    r[4] = du[index["ion_thermal_energy"]] + q.ion_loss * q.wi +
        q.exchange - p["ion_heating_deposition_efficiency"] * q.xhi -
        p["alpha_ion_fraction"] * q.reaction_power
    r[5] = du[index["electron_thermal_energy"]] + q.electron_loss * q.we +
        q.radiation - q.exchange - p["electron_heating_deposition_efficiency"] * q.xhe -
        p["alpha_electron_fraction"] * q.reaction_power + q.xr
    r[6] = q.xf - q.realized_fuel
    r[7] = q.xhi - q.realized_hi
    r[8] = q.xhe - q.realized_he
    r[9] = q.xe - q.realized_exhaust
    r[10] = q.xr - q.realized_radiation
    return r
end

function jacobian_block!(J, module_instance::CandidateLongitudinalBalanceModuleV1,
        u, du, parameters, t, context)
    p = module_instance.parameters
    q = _longitudinal_state_v1(module_instance, u, context)
    k = :fusion_reaction in module_instance.external_term_ids ? 0.0 :
        p["reaction_coefficient_per_particle_s"]
    energy_k = :fusion_reaction in module_instance.external_term_ids ? 0.0 :
        p["reaction_energy_j"] * k
    J[1, 1] = q.transport_a + k * q.nb
    J[1, 2] = k * q.na; J[1, 6] = -p["fuel_fraction_a"]
    J[1, 9] = p["exhaust_fraction_a"]
    J[2, 1] = k * q.nb; J[2, 2] = q.transport_b + k * q.na
    J[2, 6] = -p["fuel_fraction_b"]; J[2, 9] = p["exhaust_fraction_b"]
    J[3, 1] = -p["charge_a"]; J[3, 2] = -p["charge_b"]; J[3, 3] = 1.0
    J[4, 1] = -p["alpha_ion_fraction"] * energy_k * q.nb
    J[4, 2] = -p["alpha_ion_fraction"] * energy_k * q.na
    J[4, 4] = q.ion_loss + p["ion_electron_exchange_rate_s"]
    J[4, 5] = -p["ion_electron_exchange_rate_s"]
    J[4, 7] = -p["ion_heating_deposition_efficiency"]
    J[5, 1] = -p["alpha_electron_fraction"] * energy_k * q.nb
    J[5, 2] = -p["alpha_electron_fraction"] * energy_k * q.na
    radiation_k = :fuel_ion_bremsstrahlung in module_instance.external_term_ids ?
        0.0 : p["radiation_coefficient_per_particle_s"]
    J[5, 3] = radiation_k * q.we
    J[5, 4] = -p["ion_electron_exchange_rate_s"]
    J[5, 5] = q.electron_loss +
        radiation_k * q.ne +
        p["ion_electron_exchange_rate_s"]
    J[5, 8] = -p["electron_heating_deposition_efficiency"]; J[5, 10] = 1.0
    fuel_unsaturated = 0.0 < q.fuel_demand < p["fueling_capacity_s"]
    hi_unsaturated = 0.0 < q.ion_heat_demand < p["ion_heating_capacity_w"]
    he_unsaturated = 0.0 < q.electron_heat_demand < p["electron_heating_capacity_w"]
    exhaust_unsaturated = 0.0 < q.exhaust_demand < p["exhaust_capacity_s"]
    radiation_unsaturated = 0.0 < q.radiation_demand < p["radiation_control_capacity_w"]
    J[6, 1] = fuel_unsaturated ? p["fueling_controller_gain_s"] : 0.0
    J[6, 2] = J[6, 1]; J[6, 6] = 1.0
    J[7, 4] = hi_unsaturated ? p["ion_heating_controller_gain_s"] : 0.0; J[7, 7] = 1.0
    J[8, 5] = he_unsaturated ? p["electron_heating_controller_gain_s"] : 0.0; J[8, 8] = 1.0
    J[9, 1] = exhaust_unsaturated ? -p["exhaust_controller_gain_s"] : 0.0
    J[9, 2] = J[9, 1]; J[9, 9] = 1.0
    J[10, 5] = radiation_unsaturated ? -p["radiation_controller_gain_s"] : 0.0
    J[10, 10] = 1.0
    return J
end

function mass_matrix_block!(M, module_instance::CandidateLongitudinalBalanceModuleV1,
        u, parameters, t, context)
    for index in (1, 2, 4, 5)
        M[index, index] = 1.0
    end
    return M
end

function source_terms!(s, module_instance::CandidateLongitudinalBalanceModuleV1,
        u, actuator_state, t, context)
    p = module_instance.parameters
    q = _longitudinal_state_v1(module_instance, u, context)
    s[1] = p["fuel_fraction_a"] * q.xf
    s[2] = p["fuel_fraction_b"] * q.xf
    s[3] = p["ion_heating_deposition_efficiency"] * q.xhi +
        p["alpha_ion_fraction"] * q.reaction_power
    s[4] = p["electron_heating_deposition_efficiency"] * q.xhe +
        p["alpha_electron_fraction"] * q.reaction_power
    return s
end

function boundary_flux!(f, module_instance::CandidateLongitudinalBalanceModuleV1,
        u, boundary, t, context)
    p = module_instance.parameters
    q = _longitudinal_state_v1(module_instance, u, context)
    f[1] = q.transport_a * q.na + p["exhaust_fraction_a"] * q.xe + q.burn
    f[2] = q.transport_b * q.nb + p["exhaust_fraction_b"] * q.xe + q.burn
    f[3] = q.ion_loss * q.wi + q.exchange
    f[4] = q.electron_loss * q.we + q.radiation - q.exchange + q.xr
    return f
end

function observables(module_instance::CandidateLongitudinalBalanceModuleV1,
        u, trajectory, context)
    p = module_instance.parameters
    q = _longitudinal_state_v1(module_instance, u, context)
    wall_fuel = q.xf * p["fueling_wall_energy_j_per_particle"]
    wall_exhaust = q.xe * p["exhaust_wall_energy_j_per_particle"]
    wall_hi = q.xhi / p["ion_heating_wall_plug_efficiency"]
    wall_he = q.xhe / p["electron_heating_wall_plug_efficiency"]
    wall_radiation = q.xr / p["radiation_control_wall_plug_efficiency"]
    wall_total = wall_fuel + wall_exhaust + wall_hi + wall_he + wall_radiation
    gross_electric = p["electric_conversion_efficiency"] * q.reaction_power
    target_error = max(abs(q.total_particles - p["target_particle_inventory"]) /
        max(p["target_particle_inventory"], 1.0),
        abs(q.wi - p["target_ion_energy_j"]) / max(p["target_ion_energy_j"], 1.0),
        abs(q.we - p["target_electron_energy_j"]) / max(p["target_electron_energy_j"], 1.0))
    saturated = q.fuel_demand >= p["fueling_capacity_s"] * (1.0 - 1.0e-10) ||
        q.ion_heat_demand >= p["ion_heating_capacity_w"] * (1.0 - 1.0e-10) ||
        q.electron_heat_demand >= p["electron_heating_capacity_w"] * (1.0 - 1.0e-10) ||
        q.exhaust_demand >= p["exhaust_capacity_s"] * (1.0 - 1.0e-10) ||
        q.radiation_demand >= p["radiation_control_capacity_w"] * (1.0 - 1.0e-10)
    return Dict{String,Any}("transport_operator_id" => module_instance.transport_operator_id,
        "external_term_ids" => sort!(String.(collect(module_instance.external_term_ids))),
        "burn_rate_per_s" => q.burn, "reaction_power_w" => q.reaction_power,
        "radiation_power_w" => q.radiation, "self_heating_power_w" =>
            (p["alpha_ion_fraction"] + p["alpha_electron_fraction"]) * q.reaction_power,
        "actuator_actuals" => Dict("fueling_output_s" => q.xf,
            "ion_heating_output_w" => q.xhi, "electron_heating_output_w" => q.xhe,
            "exhaust_output_s" => q.xe, "radiation_control_output_w" => q.xr),
        "species_states" => [
            Dict("species_id" => "fuel_a", "inventory" => q.na,
                "inventory_unit" => "particle", "charge_number" => p["charge_a"]),
            Dict("species_id" => "fuel_b", "inventory" => q.nb,
                "inventory_unit" => "particle", "charge_number" => p["charge_b"]),
            Dict("species_id" => "electron", "inventory" => q.ne,
                "inventory_unit" => "particle", "charge_number" => -1.0)],
        "actuator_states" => [
            Dict("actuator_id" => "fueling", "role" => "fueling",
                "demand" => max(q.fuel_demand, 0.0), "output" => q.xf,
                "capacity" => p["fueling_capacity_s"], "output_unit" => "particle/s",
                "wall_plug_efficiency" => nothing),
            Dict("actuator_id" => "ion_heating", "role" => "heating",
                "demand" => max(q.ion_heat_demand, 0.0), "output" => q.xhi,
                "capacity" => p["ion_heating_capacity_w"], "output_unit" => "W",
                "wall_plug_efficiency" => p["ion_heating_wall_plug_efficiency"]),
            Dict("actuator_id" => "electron_heating", "role" => "heating",
                "demand" => max(q.electron_heat_demand, 0.0), "output" => q.xhe,
                "capacity" => p["electron_heating_capacity_w"], "output_unit" => "W",
                "wall_plug_efficiency" => p["electron_heating_wall_plug_efficiency"]),
            Dict("actuator_id" => "exhaust", "role" => "exhaust",
                "demand" => max(q.exhaust_demand, 0.0), "output" => q.xe,
                "capacity" => p["exhaust_capacity_s"], "output_unit" => "particle/s",
                "wall_plug_efficiency" => nothing),
            Dict("actuator_id" => "radiation_control", "role" => "radiation_control",
                "demand" => max(q.radiation_demand, 0.0), "output" => q.xr,
                "capacity" => p["radiation_control_capacity_w"], "output_unit" => "W",
                "wall_plug_efficiency" =>
                    p["radiation_control_wall_plug_efficiency"])],
        "complete_power_ledger" => Dict("gross_electric_power_w" => gross_electric,
            "fueling_wall_power_w" => wall_fuel, "exhaust_wall_power_w" => wall_exhaust,
            "ion_heating_wall_power_w" => wall_hi, "electron_heating_wall_power_w" => wall_he,
            "radiation_control_wall_power_w" => wall_radiation,
            "total_wall_input_power_w" => wall_total,
            "net_electric_lower_bound_w" => gross_electric - wall_total),
        "complete_power_ledger_authorized" => false,
        "power_ledger_evidence_tier" => isempty(module_instance.external_term_ids) ?
            "L1_declared_parameter_only" : "requires_cross_module_aggregation",
        "maximum_target_relative_error" => target_error,
        "capacity_shortfall" => saturated && target_error > 1.0e-6)
end

function power_ledger_contribution(module_instance::CandidateLongitudinalBalanceModuleV1,
        u, trajectory, context)
    p = module_instance.parameters
    q = _longitudinal_state_v1(module_instance, u, context)
    wall = Dict{String,Any}(
        "fueling_wall_power_w" => q.xf * p["fueling_wall_energy_j_per_particle"],
        "exhaust_wall_power_w" => q.xe * p["exhaust_wall_energy_j_per_particle"],
        "ion_heating_wall_power_w" => q.xhi / p["ion_heating_wall_plug_efficiency"],
        "electron_heating_wall_power_w" => q.xhe /
            p["electron_heating_wall_plug_efficiency"],
        "radiation_control_wall_power_w" => q.xr /
            p["radiation_control_wall_plug_efficiency"])
    wall_total = sum(Float64(value) for value in values(wall))
    embedded_fusion = isempty(module_instance.external_term_ids) ? q.reaction_power : nothing
    embedded_transport = isempty(module_instance.external_term_ids) ?
        q.ion_loss * q.wi + q.electron_loss * q.we : nothing
    return Dict{String,Any}(
        "role" => "longitudinal_balance",
        "status" => isempty(module_instance.external_term_ids) ? "unknown" : "complete",
        "provided_term_ids" => String[],
        "externally_owned_term_ids" =>
            sort!(String.(collect(module_instance.external_term_ids))),
        "unresolved_roles" => isempty(module_instance.external_term_ids) ?
            ["full_reaction_transport_radiation_capabilities"] : String[],
        "terms" => Dict{String,Any}(
            "total_fusion_power_w" => embedded_fusion,
            "charged_fusion_power_w" => embedded_fusion,
            "neutral_fusion_power_w" => isempty(module_instance.external_term_ids) ? 0.0 : nothing,
            "radiation_power_w" => isempty(module_instance.external_term_ids) ? q.radiation : nothing,
            "total_energy_transport_power_w" => embedded_transport,
            "actuator_wall_power" => wall,
            "total_wall_input_power_w" => wall_total,
            "electric_conversion_efficiency" => p["electric_conversion_efficiency"]))
end

function compile_longitudinal_candidate_manifest_v1(
        module_instance::CandidateLongitudinalBalanceModuleV1;
        candidate_id, physics_hash, initial_conditions, time_mode = "steady",
        discretization_levels = [32, 64, 128], numerical_tolerances = Dict(
            "normalized_residual" => 1.0e-8, "steady_time_term" => 1.0e-8,
            "relative_resolution" => 1.0e-8))
    states = state_layout(module_instance, CandidateSolveManifestV1(
        candidate_id = String(candidate_id), physics_hash = String(physics_hash),
        regions = [Dict{String,Any}("region_id" => module_instance.region_id,
            "spatial_dimension" => 0)],
        state_variables = [Dict{String,Any}("state_id" => id, "unit" => "1")
            for id in LONGITUDINAL_STATE_IDS_V1],
        capability_declarations = Dict{String,Any}[], module_bindings = Dict{String,Any}[],
        time_mode = String(time_mode), initial_conditions = initial_conditions,
        discretization_levels = discretization_levels))[1]
    state_variables = [Dict{String,Any}("state_id" => id, "unit" => unit)
        for (id, unit) in zip(states.state_ids, states.units)]
    return CandidateSolveManifestV1(candidate_id = String(candidate_id),
        physics_hash = String(physics_hash), regions = [Dict{String,Any}(
            "region_id" => module_instance.region_id, "spatial_dimension" => 0)],
        state_variables = state_variables,
        capability_declarations = [Dict{String,Any}("capability_id" => id) for id in (
            "longitudinal_particle_energy_species_transport_burn_actuator",
            "regional_particle_continuity_v1", "regional_ion_energy_balance_v1",
            "regional_electron_energy_balance_v1", "regional_species_balance_v1",
            "regional_actuator_fulfillment_v1", "regional_power_ledger_v1",
            "declared_boundary_flux_v1")],
        module_bindings = [Dict{String,Any}("module_id" => module_instance.module_id,
            "transport_operator_id" => module_instance.transport_operator_id)],
        time_mode = String(time_mode), initial_conditions = initial_conditions,
        numerical_tolerances = numerical_tolerances,
        discretization_levels = discretization_levels,
        parameters = Dict{String,Any}(module_instance.parameters))
end
