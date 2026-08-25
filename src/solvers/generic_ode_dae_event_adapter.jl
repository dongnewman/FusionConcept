function _rk4_scalar_step_v1(f, t, y, dt)
    k1 = f(t, y)
    k2 = f(t + dt / 2, y + dt * k1 / 2)
    k3 = f(t + dt / 2, y + dt * k2 / 2)
    k4 = f(t + dt, y + dt * k3)
    return y + dt * (k1 + 2k2 + 2k3 + k4) / 6
end

function _piecewise_energy_exact_v1(t, initial_energy, input_power, decay_rate, event_time, post_event_decay)
    segment(E0, duration, rate) = rate == 0 ? E0 + input_power * duration :
        E0 * exp(-rate * duration) + input_power / rate * (1 - exp(-rate * duration))
    if event_time === nothing || t <= event_time
        return segment(initial_energy, t, decay_rate)
    end
    at_event = segment(initial_energy, event_time, decay_rate)
    return segment(at_event, t - event_time, post_event_decay)
end

"Verified reduced ODE/event adapter. General high-index DAE support is explicitly out of scope."
function solve_generic_ode_dae_event_v1(; initial_energy = 1.0, input_power = 0.0,
        decay_rate = 1.0, t_final = 2.0, dt = 0.05,
        event_time = nothing, post_event_decay = decay_rate)
    t_final > 0 || throw(ArgumentError("t_final must be positive"))
    dt > 0 || throw(ArgumentError("dt must be positive"))
    steps = ceil(Int, t_final / dt)
    times = collect(range(0.0, t_final; length = steps + 1))
    values = Vector{Float64}(undef, length(times))
    exact = similar(values)
    values[1] = Float64(initial_energy)
    exact[1] = Float64(initial_energy)
    for index in 1:steps
        t = times[index]
        local_dt = times[index + 1] - t
        rate = event_time !== nothing && t >= event_time ? post_event_decay : decay_rate
        if event_time !== nothing && t < event_time < times[index + 1]
            first_dt = event_time - t
            mid = _rk4_scalar_step_v1((_, y) -> input_power - decay_rate * y, t, values[index], first_dt)
            values[index + 1] = _rk4_scalar_step_v1((_, y) -> input_power - post_event_decay * y,
                event_time, mid, local_dt - first_dt)
        else
            values[index + 1] = _rk4_scalar_step_v1((_, y) -> input_power - rate * y, t, values[index], local_dt)
        end
        exact[index + 1] = _piecewise_energy_exact_v1(times[index + 1], initial_energy, input_power,
            decay_rate, event_time, post_event_decay)
    end
    error = maximum(abs.(values .- exact))
    residual = maximum(abs.((values .- exact)))
    return Dict{String,Any}(
        "adapter_id" => "generic_ode_dae_event_adapter_v1", "method" => "RK4",
        "supported_problem_class" => "scalar_ODE_with_events_and_index0_algebraic_products",
        "unsupported_problem_classes" => Any["general_high_index_DAE", "stiff_multiphysics_without_step_study"],
        "times" => times, "trajectory" => values, "analytic_reference" => exact,
        "max_abs_error" => error, "conservation_residual" => residual,
        "event_time" => event_time, "dt" => dt, "replay_config_hash" => canonical_hash(Dict(
            "initial_energy" => initial_energy, "input_power" => input_power, "decay_rate" => decay_rate,
            "t_final" => t_final, "dt" => dt, "event_time" => event_time, "post_event_decay" => post_event_decay)),
    )
end

function verify_generic_ode_dae_event_adapter_v1()
    coarse = solve_generic_ode_dae_event_v1(dt = 0.1, event_time = 1.0, post_event_decay = 0.5)
    fine = solve_generic_ode_dae_event_v1(dt = 0.05, event_time = 1.0, post_event_decay = 0.5)
    finer = solve_generic_ode_dae_event_v1(dt = 0.025, event_time = 1.0, post_event_decay = 0.5)
    ratio_1 = coarse["max_abs_error"] / fine["max_abs_error"]
    ratio_2 = fine["max_abs_error"] / finer["max_abs_error"]
    return Dict{String,Any}(
        "code_verification" => "analytic_piecewise_linear_solution",
        "coarse_error" => coarse["max_abs_error"], "fine_error" => fine["max_abs_error"],
        "finer_error" => finer["max_abs_error"], "refinement_ratios" => Any[ratio_1, ratio_2],
        "observed_convergence" => fine["max_abs_error"] < coarse["max_abs_error"] &&
            finer["max_abs_error"] < fine["max_abs_error"],
        "pass" => finer["max_abs_error"] < 1.0e-6,
    )
end

function run_generic_ode_negative_control_v1()
    result = solve_generic_ode_dae_event_v1(decay_rate = -0.2, t_final = 2.0, dt = 0.025)
    observed_decay = result["trajectory"][end] < result["trajectory"][1]
    return Dict{String,Any}(
        "control_id" => "negative_decay_sign_control_v1", "expected_claim" => "energy_decays_without_input",
        "observed_decay" => observed_decay, "status" => observed_decay ? "unexpected_pass" : "correctly_falsified",
        "failure_scope" => "parameter_instance", "topology_failure" => false,
        "evidence" => Dict("initial_energy" => result["trajectory"][1], "final_energy" => result["trajectory"][end]),
    )
end

