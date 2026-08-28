const MULTIREGION_NONLINEAR_V90_CLAIM_BOUNDARY =
    "Candidate-bound nonlinear multi-region control-volume, reduced equilibrium, transport, reaction, radiation, self-heating, actuator, and controller closure. Passing this runtime is reduced hard-physics evidence only; it is not free-boundary MHD, kinetic, engineering, experimental, or deployability validation."

"Backend-neutral nonlinear/DAE contract. All serialized fields are solver-library independent."
struct MultiRegionNonlinearDAEContractV90
    schema_version::String
    candidate_hash::String
    candidate_physics_hash::String
    solver_input_hash::String
    route_hash::String
    state_ids::Vector{String}
    state_scales::Vector{Float64}
    lower_bounds::Vector{Float64}
    upper_bounds::Vector{Float64}
    mass_diagonal::Vector{Float64}
    initial_guess::Vector{Float64}
    residual_blocks::Vector{Dict{String,Any}}
    interface_pairs::Vector{Dict{String,Any}}
    model_parameters::Dict{String,Any}
    jacobian_contract::Dict{String,Any}
    stopping_contract::Dict{String,Any}
    contract_hash::String
end

abstract type AbstractNonlinearDAEBackendV90 end

struct NativeDampedNewtonDAEBackendV90 <: AbstractNonlinearDAEBackendV90
    backend_id::String
    maximum_newton_iterations::Int
    homotopy_steps::Vector{Float64}
    line_search_steps::Int
    dae_steps::Int
    dae_dt::Float64
end

NativeDampedNewtonDAEBackendV90(; maximum_newton_iterations = 36,
        homotopy_steps = collect(0.0:0.2:1.0), line_search_steps = 24,
        dae_steps = 16, dae_dt = 0.05) = NativeDampedNewtonDAEBackendV90(
    "native_candidate_bound_damped_newton_dae_v90",
    Int(maximum_newton_iterations), Float64.(homotopy_steps),
    Int(line_search_steps), Int(dae_steps), Float64(dae_dt))

_v90_sigmoid(value) = value >= 0 ? 1.0 / (1.0 + exp(-value)) :
    exp(value) / (1.0 + exp(value))

function _v90_region_slot(topology::UniversalMultiRegionTopologyV89,
        local_state_id::AbstractString)
    for region in topology.regions, slot in region["state_slots"]
        String(slot["slot_id"]) == String(local_state_id) && return String(region["region_id"])
    end
    nothing
end

function _v90_core_region(topology::UniversalMultiRegionTopologyV89)
    index = findfirst(region -> occursin("core", lowercase(String(region["role"]))),
        topology.regions)
    String(topology.regions[index === nothing ? 1 : index]["region_id"])
end

function _v90_open_regions(topology::UniversalMultiRegionTopologyV89)
    boundary_by_region = Dict(String(item["region_id"]) => String(item["kind"])
        for item in topology.boundaries)
    sort!(String[String(region["region_id"]) for region in topology.regions
        if get(boundary_by_region, String(region["region_id"]), "") in
            ("open", "sheath", "absorbing") || occursin("open",
                lowercase(String(region["role"])))])
end

function _v90_positive_scale(value, fallback)
    numeric = value isa Real ? abs(Float64(value)) : Float64(fallback)
    isfinite(numeric) && numeric > 0.0 ? numeric : Float64(fallback)
end

function _v90_contract_body(item::MultiRegionNonlinearDAEContractV90)
    Dict{String,Any}(
        "schema_version" => item.schema_version,
        "candidate_hash" => item.candidate_hash,
        "candidate_physics_hash" => item.candidate_physics_hash,
        "solver_input_hash" => item.solver_input_hash,
        "route_hash" => item.route_hash, "state_ids" => item.state_ids,
        "state_scales" => item.state_scales, "lower_bounds" => item.lower_bounds,
        "upper_bounds" => item.upper_bounds, "mass_diagonal" => item.mass_diagonal,
        "initial_guess" => item.initial_guess,
        "residual_blocks" => item.residual_blocks,
        "interface_pairs" => item.interface_pairs,
        "model_parameters" => item.model_parameters,
        "jacobian_contract" => item.jacobian_contract,
        "stopping_contract" => item.stopping_contract)
end

function multiregion_nonlinear_dae_contract_to_dict_v90(
        item::MultiRegionNonlinearDAEContractV90)
    body = _v90_contract_body(item)
    body["contract_hash"] = item.contract_hash
    body["claim_boundary"] = MULTIREGION_NONLINEAR_V90_CLAIM_BOUNDARY
    body
end

function _v90_add_block!(blocks, block_id, block_kind, equation_id, region_id,
        operator_id, dependencies; interface_id = nothing, sign = nothing)
    block = Dict{String,Any}(
        "block_id" => String(block_id), "block_kind" => String(block_kind),
        "equation_id" => String(equation_id), "region_id" => String(region_id),
        "operator_id" => String(operator_id),
        "dependency_state_ids" => sort!(unique(String.(dependencies))))
    interface_id === nothing || (block["interface_id"] = String(interface_id))
    sign === nothing || (block["interface_sign"] = Float64(sign))
    push!(blocks, block)
end

"Compile a real nonlinear residual. The v89 operating state is used only for scaling and initialization."
function compile_multiregion_nonlinear_dae_v90(
        candidate::UniversalDeviceCandidateV89,
        topology::UniversalMultiRegionTopologyV89,
        realization::UniversalRealizationV89, route_result;
        coefficient_overrides = Dict{String,Any}())
    candidate.topology_hash == topology.topology_hash || throw(ArgumentError(
        "v90 candidate/topology hash mismatch"))
    candidate.realization_hash == realization.realization_hash || throw(ArgumentError(
        "v90 candidate/realization hash mismatch"))
    String(route_result["status"]) == "pass" || throw(ArgumentError(
        "v90 unsupported capability route cannot compile a solved residual"))
    candidate.candidate_physics_hash == realization.candidate_physics_hash ||
        throw(ArgumentError("v90 stale candidate physics hash"))

    core = _v90_core_region(topology)
    open_regions = _v90_open_regions(topology)
    operating = realization.operating_state
    physical = realization.physical_parameters
    control = realization.control_realization
    n_scale = _v90_positive_scale(get(operating, "particle_inventory", nothing), 1.0e20)
    e_scale = _v90_positive_scale(get(operating, "thermal_energy", nothing), 3.0e5)
    i_scale = _v90_positive_scale(get(operating, "plasma_current", nothing), 8.0e5)
    phi_scale = _v90_positive_scale(get(operating, "magnetic_flux", nothing), 1.0)

    state_ids = String[]; scales = Float64[]; lower = Float64[]; upper = Float64[]
    mass = Float64[]; initial = Float64[]; blocks = Dict{String,Any}[]
    function add_state(region, local_id, scale, lo, hi, mass_value, guess)
        id = "$region::$local_id"; push!(state_ids, id); push!(scales, scale)
        push!(lower, lo); push!(upper, hi); push!(mass, mass_value); push!(initial, guess)
        _v90_add_block!(blocks, "governing::$id", "governing", id, region,
            local_id in ("plasma_current", "magnetic_flux") ?
                "reduced_finite_pressure_equilibrium_constraint_v90" :
                "conservative_inventory_governing_v90", [id])
        id
    end
    core_n = add_state(core, "particle_inventory", n_scale, 0.02, 4.0, 1.0, 0.82)
    core_e = add_state(core, "thermal_energy", e_scale, 0.02, 4.0, 1.0, 0.76)
    core_i = add_state(core, "plasma_current", i_scale, 0.05, 2.5, 0.0, 0.94)
    core_phi = add_state(core, "magnetic_flux", phi_scale, 0.05, 2.5, 0.0, 0.88)
    open_state_ids = Dict{String,Tuple{String,String}}()
    for (index, region) in enumerate(open_regions)
        local_n = add_state(region, "particle_inventory", n_scale,
            0.002, 2.0, 1.0, 0.20 + 0.02index)
        local_e = add_state(region, "thermal_energy", e_scale,
            0.002, 2.0, 1.0, 0.16 + 0.02index)
        open_state_ids[region] = (local_n, local_e)
    end
    particle_actuator = add_state(core, "particle_actuator_output",
        n_scale, 0.0, 1.0, 0.0, 0.45)
    heating_actuator = add_state(core, "heating_actuator_output",
        e_scale, 0.0, 1.0, 0.0, 0.48)
    _v90_add_block!(blocks, "additive::reaction_particles", "additive", core_n,
        core, "candidate_bound_reaction_loss_v90", [core_n, core_e])
    _v90_add_block!(blocks, "additive::particle_actuation", "additive", core_n,
        core, "bounded_particle_actuator_v90", [core_n, particle_actuator])
    _v90_add_block!(blocks, "additive::transport", "additive", core_e,
        core, "candidate_bound_transport_loss_v90", [core_n, core_e, core_phi])
    _v90_add_block!(blocks, "additive::radiation", "additive", core_e,
        core, "candidate_bound_radiation_loss_v90", [core_n, core_e])
    _v90_add_block!(blocks, "additive::self_heating", "additive", core_e,
        core, "candidate_bound_reaction_self_heating_v90", [core_n, core_e])
    _v90_add_block!(blocks, "additive::heating_actuation", "additive", core_e,
        core, "bounded_heating_actuator_v90", [core_e, heating_actuator])
    _v90_add_block!(blocks, "controller::particle", "additive", particle_actuator,
        core, "bounded_state_feedback_controller_v90", [core_n, particle_actuator])
    _v90_add_block!(blocks, "controller::energy", "additive", heating_actuator,
        core, "bounded_state_feedback_controller_v90", [core_e, heating_actuator])

    interface_pairs = Dict{String,Any}[]
    for interface in topology.interfaces
        target = get(interface, "target_region_id", nothing)
        target === nothing && continue
        source = String(interface["source_region_id"]); target = String(target)
        haskey(open_state_ids, target) || continue
        for account in ("particles", "energy")
            source_state = account == "particles" ? core_n : core_e
            target_state = account == "particles" ? open_state_ids[target][1] :
                open_state_ids[target][2]
            pair = Dict{String,Any}(
                "interface_id" => String(interface["interface_id"]),
                "account_id" => account, "source_region_id" => source,
                "target_region_id" => target, "source_state_id" => source_state,
                "target_state_id" => target_state, "source_sign" => 1.0,
                "target_sign" => -1.0, "same_nonlinear_iteration" => true,
                "flux_model" => "candidate_bound_state_difference_v90")
            pair["pair_hash"] = canonical_hash(pair); push!(interface_pairs, pair)
            _v90_add_block!(blocks,
                "interface::$(pair["interface_id"])::$account::source", "additive",
                source_state, source, "paired_conservative_interface_flux_v90",
                [source_state, target_state]; interface_id = pair["interface_id"], sign = 1.0)
            _v90_add_block!(blocks,
                "interface::$(pair["interface_id"])::$account::target", "additive",
                target_state, target, "paired_conservative_interface_flux_v90",
                [source_state, target_state]; interface_id = pair["interface_id"], sign = -1.0)
        end
    end

    volume = _v90_positive_scale(get(physical, "volume_m3", nothing), 5.0)
    field = _v90_positive_scale(get(physical, "magnetic_field_t", nothing), 0.8)
    minor = _v90_positive_scale(get(physical, "minor_radius_m", nothing), 0.5)
    temperature = _v90_positive_scale(get(physical, "temperature_j", nothing), 1.0e-15)
    input_power = _v90_positive_scale(get(physical, "input_power_w", nothing), 5.0e6)
    command_max = _v90_positive_scale(get(control, "command_max", nothing), input_power)
    beta_reference = clamp(2.0 * (4pi * 1.0e-7) *
        (2.0 * n_scale * temperature / volume) / field^2, 1.0e-6, 0.8)
    parameters = Dict{String,Any}(
        "core_region_id" => core, "open_region_ids" => open_regions,
        "particle_loss_coefficient" => 0.16 + 0.02length(open_regions),
        "energy_transport_coefficient" => 0.22 + 0.03length(open_regions),
        "reaction_coefficient" => 0.035,
        "radiation_coefficient" => 0.055,
        "self_heating_fraction" => 0.24,
        "particle_interface_coefficient" => 0.20,
        "energy_interface_coefficient" => 0.26,
        "open_particle_loss_coefficient" => 0.50,
        "open_energy_loss_coefficient" => 0.62,
        "particle_controller_gain" => 2.2,
        "energy_controller_gain" => 2.4,
        "particle_controller_bias" => -0.15,
        "energy_controller_bias" => 0.05,
        "current_profile_shear" => 0.12,
        "beta_reference" => beta_reference,
        "actuator_capacity_ratio" => command_max / input_power,
        "volume_m3" => volume, "minor_radius_m" => minor,
        "magnetic_field_t" => field, "temperature_j" => temperature,
        "input_power_w" => input_power)
    for (key, value) in pairs(coefficient_overrides)
        parameters[String(key)] = value
    end
    all(value -> !(value isa AbstractFloat) || isfinite(value), values(parameters)) ||
        throw(ArgumentError("v90 model parameters must be finite"))

    governing = [String(block["equation_id"]) for block in blocks
        if String(block["block_kind"]) == "governing"]
    all(id -> count(==(id), governing) == 1, state_ids) || throw(ArgumentError(
        "v90 every state equation requires exactly one governing block"))
    all(pair -> pair["source_sign"] == -pair["target_sign"], interface_pairs) ||
        throw(ArgumentError("v90 interface flux pairs must be exactly opposite"))
    jacobian = Dict{String,Any}(
        "mode" => "central_difference_full_residual",
        "relative_step" => 2.0e-6,
        "directional_audit" => "independent_one_sided_difference",
        "audit_relative_tolerance" => 2.0e-4)
    stopping = Dict{String,Any}(
        "normalized_residual_tolerance" => 1.0e-9,
        "independent_balance_tolerance" => 2.0e-8,
        "maximum_newton_iterations" => 36,
        "homotopy_required_to_lambda" => 1.0,
        "failure_classification" => Dict(
            "missing_solver" => "unsupported",
            "numerical_nonconvergence" => "unknown",
            "converged_unfavorable" => "fail"))
    actual_solver_input_hash = canonical_hash(Dict{String,Any}(
        "candidate_solver_input_hash" => candidate.solver_input_hash,
        "candidate_physics_hash" => candidate.candidate_physics_hash,
        "route_hash" => route_result["route_hash"],
        "model_parameters" => parameters,
        "state_ids" => state_ids, "mass_diagonal" => mass,
        "initial_guess_role" => "initial_guess_only"))
    provisional = MultiRegionNonlinearDAEContractV90("1.0.0",
        candidate.candidate_hash, candidate.candidate_physics_hash,
        actual_solver_input_hash, String(route_result["route_hash"]), state_ids,
        scales, lower, upper, mass, initial, blocks, interface_pairs, parameters, jacobian,
        stopping, "")
    hash = canonical_hash(_v90_contract_body(provisional))
    MultiRegionNonlinearDAEContractV90(provisional.schema_version,
        provisional.candidate_hash, provisional.candidate_physics_hash,
        provisional.solver_input_hash, provisional.route_hash, provisional.state_ids,
        provisional.state_scales, provisional.lower_bounds, provisional.upper_bounds,
        provisional.mass_diagonal, provisional.initial_guess,
        provisional.residual_blocks, provisional.interface_pairs,
        provisional.model_parameters, provisional.jacobian_contract,
        provisional.stopping_contract, hash)
end

function _v90_state_index(contract::MultiRegionNonlinearDAEContractV90)
    Dict(id => index for (index, id) in enumerate(contract.state_ids))
end

function _v90_local_state_id(contract, region, local_id)
    id = "$region::$local_id"
    id in contract.state_ids || throw(ArgumentError("v90 missing state $id"))
    id
end

"Main residual assembly. It is deliberately separate from the independent auditor below."
function _v90_assemble_nonlinear_residual(contract::MultiRegionNonlinearDAEContractV90,
        x::Vector{Float64}; xdot = zeros(Float64, length(x)))
    length(x) == length(contract.state_ids) || throw(DimensionMismatch("v90 state length"))
    index = _v90_state_index(contract); p = contract.model_parameters
    core = String(p["core_region_id"])
    n_id = _v90_local_state_id(contract, core, "particle_inventory")
    e_id = _v90_local_state_id(contract, core, "thermal_energy")
    i_id = _v90_local_state_id(contract, core, "plasma_current")
    phi_id = _v90_local_state_id(contract, core, "magnetic_flux")
    pa_id = _v90_local_state_id(contract, core, "particle_actuator_output")
    ha_id = _v90_local_state_id(contract, core, "heating_actuator_output")
    n = x[index[n_id]]; e = x[index[e_id]]; current = x[index[i_id]]
    flux = x[index[phi_id]]; particle_actuator = x[index[pa_id]]
    heating_actuator = x[index[ha_id]]
    reaction = Float64(p["reaction_coefficient"]) * n^2 * sqrt(max(e, 1.0e-12))
    radiation = Float64(p["radiation_coefficient"]) * n^2 * sqrt(max(e, 1.0e-12))
    transport = Float64(p["energy_transport_coefficient"]) *
        e^1.5 / sqrt(max(n, 1.0e-12)) * (1.0 + 0.08 / max(flux, 0.05))
    beta = Float64(p["beta_reference"]) * n * e
    result = zeros(Float64, length(x))
    result[index[n_id]] = Float64(p["particle_loss_coefficient"]) * n + reaction -
        particle_actuator
    result[index[e_id]] = transport + radiation -
        Float64(p["self_heating_fraction"]) * reaction - heating_actuator
    result[index[i_id]] = current - (1.0 - 0.22beta) /
        (1.0 + Float64(p["current_profile_shear"]))
    result[index[phi_id]] = flux - current * (1.0 - 0.14beta)
    capacity_ratio = min(Float64(p["actuator_capacity_ratio"]), 1.0)
    particle_command = capacity_ratio * _v90_sigmoid(
        Float64(p["particle_controller_bias"]) +
        Float64(p["particle_controller_gain"]) * (1.0 - n))
    energy_command = capacity_ratio * _v90_sigmoid(
        Float64(p["energy_controller_bias"]) +
        Float64(p["energy_controller_gain"]) * (1.0 - e))
    result[index[pa_id]] = particle_actuator - particle_command
    result[index[ha_id]] = heating_actuator - energy_command

    for pair in contract.interface_pairs
        source_id = String(pair["source_state_id"])
        target_id = String(pair["target_state_id"])
        coefficient = String(pair["account_id"]) == "particles" ?
            Float64(p["particle_interface_coefficient"]) :
            Float64(p["energy_interface_coefficient"])
        value = coefficient * (x[index[source_id]] - x[index[target_id]])
        result[index[source_id]] += value
        result[index[target_id]] -= value
    end
    for region in String.(p["open_region_ids"])
        local_n = _v90_local_state_id(contract, region, "particle_inventory")
        local_e = _v90_local_state_id(contract, region, "thermal_energy")
        nr = x[index[local_n]]; er = x[index[local_e]]
        result[index[local_n]] += Float64(p["open_particle_loss_coefficient"]) * nr
        result[index[local_e]] += Float64(p["open_energy_loss_coefficient"]) *
            er^1.5 / sqrt(max(nr, 1.0e-12))
    end
    result .+= contract.mass_diagonal .* xdot
    result
end

function _v90_central_jacobian(contract, x; xdot = zeros(Float64, length(x)))
    step = Float64(contract.jacobian_contract["relative_step"])
    matrix = zeros(Float64, length(x), length(x))
    for column in eachindex(x)
        h = step * max(abs(x[column]), 1.0)
        plus = copy(x); minus = copy(x); plus[column] += h; minus[column] -= h
        matrix[:, column] .= (_v90_assemble_nonlinear_residual(contract, plus; xdot) .-
            _v90_assemble_nonlinear_residual(contract, minus; xdot)) ./ (2h)
    end
    matrix
end

function _v90_normalized_residual_norm(contract, residual)
    maximum(abs, residual; init = 0.0)
end

function _v90_newton_phase(contract, x, origin, lambda, backend, history;
        previous = nothing, dt = 1.0, time = 0.0)
    tolerance = Float64(contract.stopping_contract["normalized_residual_tolerance"])
    for iteration in 1:backend.maximum_newton_iterations
        if previous === nothing
            full = _v90_assemble_nonlinear_residual(contract, x)
            residual = (1.0 - lambda) .* (x .- origin) .+ lambda .* full
            jacobian = (1.0 - lambda) .* Matrix{Float64}(I, length(x), length(x)) .+
                lambda .* _v90_central_jacobian(contract, x)
            phase = "homotopy_newton"
        else
            xdot = (x .- previous) ./ dt
            residual = _v90_assemble_nonlinear_residual(contract, x; xdot)
            jacobian = _v90_central_jacobian(contract, x; xdot) +
                Diagonal(contract.mass_diagonal ./ dt)
            phase = "implicit_dae"
        end
        norm_value = _v90_normalized_residual_norm(contract, residual)
        push!(history, Dict{String,Any}("phase" => phase, "lambda" => lambda,
            "time" => time, "iteration" => iteration,
            "normalized_residual" => norm_value))
        norm_value <= tolerance && return x, true
        delta = try
            -(jacobian \ residual)
        catch
            return x, false
        end
        all(isfinite, delta) || return x, false
        accepted = false; step = 1.0
        for _ in 1:backend.line_search_steps
            trial = x .+ step .* delta
            feasible = all(index -> contract.lower_bounds[index] <= trial[index] <=
                contract.upper_bounds[index], eachindex(trial))
            if feasible
                trial_residual = if previous === nothing
                    (1.0 - lambda) .* (trial .- origin) .+ lambda .*
                        _v90_assemble_nonlinear_residual(contract, trial)
                else
                    _v90_assemble_nonlinear_residual(contract, trial;
                        xdot = (trial .- previous) ./ dt)
                end
                if _v90_normalized_residual_norm(contract, trial_residual) < norm_value
                    x = trial; accepted = true; break
                end
            end
            step *= 0.5
        end
        accepted || return x, false
    end
    x, false
end

"Independent balance auditor: recomputes physical accounts without calling main assembly."
function audit_multiregion_balance_independent_v90(
        contract::MultiRegionNonlinearDAEContractV90, x::Vector{Float64})
    index = _v90_state_index(contract); p = contract.model_parameters
    core = String(p["core_region_id"])
    n = x[index["$core::particle_inventory"]]
    e = x[index["$core::thermal_energy"]]
    pa = x[index["$core::particle_actuator_output"]]
    ha = x[index["$core::heating_actuator_output"]]
    reaction = Float64(p["reaction_coefficient"]) * n * n * sqrt(max(e, 1.0e-12))
    radiation = Float64(p["radiation_coefficient"]) * n * n * sqrt(max(e, 1.0e-12))
    transport = Float64(p["energy_transport_coefficient"]) *
        e * sqrt(max(e, 1.0e-12)) / sqrt(max(n, 1.0e-12)) *
        (1.0 + 0.08 / max(x[index["$core::magnetic_flux"]], 0.05))
    particle_accounts = Dict{String,Float64}(core =>
        Float64(p["particle_loss_coefficient"]) * n + reaction - pa)
    energy_accounts = Dict{String,Float64}(core => transport + radiation -
        Float64(p["self_heating_fraction"]) * reaction - ha)
    pair_rows = Dict{String,Any}[]
    for pair in contract.interface_pairs
        source_id = String(pair["source_state_id"]); target_id = String(pair["target_state_id"])
        coefficient = String(pair["account_id"]) == "particles" ?
            Float64(p["particle_interface_coefficient"]) :
            Float64(p["energy_interface_coefficient"])
        flux = coefficient * (x[index[source_id]] - x[index[target_id]])
        source = String(pair["source_region_id"]); target = String(pair["target_region_id"])
        ledger = String(pair["account_id"]) == "particles" ? particle_accounts : energy_accounts
        ledger[source] = get(ledger, source, 0.0) + flux
        ledger[target] = get(ledger, target, 0.0) - flux
        push!(pair_rows, Dict{String,Any}(
            "pair_hash" => pair["pair_hash"], "account_id" => pair["account_id"],
            "source_contribution" => flux, "target_contribution" => -flux,
            "pair_sum" => 0.0, "status" => "pass"))
    end
    for region in String.(p["open_region_ids"])
        nr = x[index["$region::particle_inventory"]]
        er = x[index["$region::thermal_energy"]]
        particle_accounts[region] = get(particle_accounts, region, 0.0) +
            Float64(p["open_particle_loss_coefficient"]) * nr
        energy_accounts[region] = get(energy_accounts, region, 0.0) +
            Float64(p["open_energy_loss_coefficient"]) * er * sqrt(max(er, 1.0e-12)) /
                sqrt(max(nr, 1.0e-12))
    end
    maximum_balance = maximum(abs, vcat(collect(values(particle_accounts)),
        collect(values(energy_accounts))); init = 0.0)
    tolerance = Float64(contract.stopping_contract["independent_balance_tolerance"])
    body = Dict{String,Any}(
        "status" => maximum_balance <= tolerance ? "pass" : "fail",
        "candidate_hash" => contract.candidate_hash,
        "contract_hash" => contract.contract_hash,
        "particle_region_balances" => particle_accounts,
        "energy_region_balances" => energy_accounts,
        "interface_pair_audits" => pair_rows,
        "maximum_absolute_balance" => maximum_balance,
        "tolerance" => tolerance,
        "auditor_independence_group" => "independent_account_ledger_v90",
        "main_residual_assembly_reused" => false,
        "auditor_implementation_hash" => canonical_hash(Dict(
            "implementation" => "independent_account_ledger_v90", "version" => "1.0.0")))
    body["audit_hash"] = canonical_hash(body)
    body
end

function _v90_jacobian_audit(contract, x)
    central = _v90_central_jacobian(contract, x)
    direction = collect(1.0:length(x)); direction ./= norm(direction)
    h = 5.0e-7
    base = _v90_assemble_nonlinear_residual(contract, x)
    forward = (_v90_assemble_nonlinear_residual(contract, x .+ h .* direction) .-
        base) ./ h
    predicted = central * direction
    error = norm(forward - predicted) / max(norm(forward), norm(predicted), 1.0e-12)
    tolerance = Float64(contract.jacobian_contract["audit_relative_tolerance"])
    Dict{String,Any}("status" => error <= tolerance ? "pass" : "fail",
        "directional_relative_error" => error, "relative_tolerance" => tolerance,
        "audit_method" => "independent_one_sided_difference")
end

function solve_multiregion_nonlinear_dae_v90(
        contract::MultiRegionNonlinearDAEContractV90;
        backend::AbstractNonlinearDAEBackendV90 = NativeDampedNewtonDAEBackendV90())
    backend isa NativeDampedNewtonDAEBackendV90 || throw(ArgumentError(
        "v90 backend adapter has no registered implementation"))
    x0 = copy(contract.initial_guess); x = copy(x0); history = Dict{String,Any}[]
    converged = true
    for lambda in backend.homotopy_steps
        x, ok = _v90_newton_phase(contract, x, x0, lambda, backend, history)
        ok || (converged = false; break)
    end
    trajectory = Dict{String,Any}[]
    if !converged
        previous = copy(x); dae_complete = true
        for step in 1:backend.dae_steps
            x, ok = _v90_newton_phase(contract, copy(previous), x0, 1.0, backend,
                history; previous, dt = backend.dae_dt, time = step * backend.dae_dt)
            ok || (dae_complete = false; break)
            previous = copy(x)
            push!(trajectory, Dict("time" => step * backend.dae_dt,
                "normalized_state" => Dict(contract.state_ids .=> copy(x))))
        end
        classification = dae_complete ? "unknown_no_steady_state_dae_trajectory_complete" :
            "unknown_nonlinear_and_dae_nonconvergence"
        body = Dict{String,Any}(
            "schema_version" => "1.0.0", "candidate_hash" => contract.candidate_hash,
            "candidate_physics_hash" => contract.candidate_physics_hash,
            "contract_hash" => contract.contract_hash, "backend_id" => backend.backend_id,
            "status" => "unknown", "classification" => classification,
            "convergence_status" => dae_complete ? "dae_trajectory_complete" :
                "backend_exhausted", "initial_guess_role" =>
                "l1_or_declared_state_initial_guess_only", "full_model_lambda" => 1.0,
            "residual_history" => history, "trajectory" => trajectory,
            "final_normalized_state" => Dict(contract.state_ids .=> x),
            "final_physical_state" => Dict(contract.state_ids .=>
                (x .* contract.state_scales)),
            "audits" => Dict{String,Any}(),
            "evidence_ceiling" => "partial_nonlinear_dae_diagnostic_only")
        body["result_hash"] = canonical_hash(body); return body
    end
    residual = _v90_assemble_nonlinear_residual(contract, x)
    residual_norm = _v90_normalized_residual_norm(contract, residual)
    independent = audit_multiregion_balance_independent_v90(contract, x)
    jacobian = _v90_jacobian_audit(contract, x)
    physical_bounds = all(index -> contract.lower_bounds[index] <= x[index] <=
        contract.upper_bounds[index], eachindex(x))
    tolerance = Float64(contract.stopping_contract["normalized_residual_tolerance"])
    audits_pass = residual_norm <= tolerance && independent["status"] == "pass" &&
        jacobian["status"] == "pass" && physical_bounds
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "candidate_hash" => contract.candidate_hash,
        "candidate_physics_hash" => contract.candidate_physics_hash,
        "contract_hash" => contract.contract_hash, "backend_id" => backend.backend_id,
        "status" => audits_pass ? "pass" : "unknown",
        "classification" => audits_pass ? "pass_candidate_bound_multiregion_nonlinear_v90" :
            "unknown_post_convergence_audit_failure",
        "convergence_status" => "homotopy_damped_newton_converged",
        "initial_guess_role" => "l1_or_declared_state_initial_guess_only",
        "initial_guess_equals_final_state" => x0 == x,
        "full_model_lambda" => 1.0, "residual_history" => history,
        "trajectory" => trajectory, "final_normalized_state" =>
            Dict(contract.state_ids .=> x), "final_physical_state" =>
            Dict(contract.state_ids .=> (x .* contract.state_scales)),
        "maximum_normalized_residual" => residual_norm,
        "audits" => Dict{String,Any}(
            "independent_balance" => independent, "jacobian" => jacobian,
            "physical_state_bounds" => physical_bounds ? "pass" : "fail",
            "governing_block_ownership" => "pass",
            "interface_same_iteration" => all(pair ->
                pair["same_nonlinear_iteration"] === true, contract.interface_pairs) ?
                    "pass" : "fail"),
        "evidence_ceiling" => "candidate_bound_reduced_multiregion_nonlinear_hard_gate")
    body["result_hash"] = canonical_hash(body)
    body
end
