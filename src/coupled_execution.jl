function _run_two_reservoir_exchange_v1(; energy_a = 2.0, energy_b = 0.0,
        exchange_rate = 0.5, t_final = 2.0, dt = 0.01)
    steps = ceil(Int, t_final / dt)
    a, b = Float64(energy_a), Float64(energy_b)
    initial_total = a + b
    max_residual = 0.0
    for _ in 1:steps
        flux = exchange_rate * (a - b)
        delta = min(dt, t_final / steps) * flux
        next_a = a - delta
        next_b = b + delta
        max_residual = max(max_residual, abs((next_a + next_b) - (a + b)))
        a, b = next_a, next_b
    end
    exact_difference = (energy_a - energy_b) * exp(-2exchange_rate * t_final)
    exact_a = (initial_total + exact_difference) / 2
    return Dict("energy_a" => a, "energy_b" => b, "initial_total" => initial_total,
        "final_total" => a + b, "interface_conservation_residual" => max_residual,
        "solution_error" => abs(a - exact_a), "dt" => dt)
end

function run_coupled_two_reservoir_v1(contract = default_two_reservoir_coupling_contract_v1())
    errors = validate_coupling_contract_v1(contract)
    isempty(errors) || return Dict("status" => "coupling_unsupported", "errors" => errors,
        "promotion_scope" => "none")
    coarse = _run_two_reservoir_exchange_v1(dt = 0.01)
    fine = _run_two_reservoir_exchange_v1(dt = 0.005)
    global_budget = contract["global_error_budget"]
    pass = fine["interface_conservation_residual"] <= Float64(global_budget["energy_conservation_absolute"]) &&
        fine["solution_error"] <= Float64(global_budget["solution_absolute"]) &&
        fine["solution_error"] < coarse["solution_error"]
    return Dict{String,Any}(
        "status" => pass ? "pass" : "fail", "coupling_id" => contract["coupling_id"],
        "coarse" => coarse, "fine" => fine, "convergence_ratio" => coarse["solution_error"] / fine["solution_error"],
        "interface_conservation_pass" => fine["interface_conservation_residual"] <=
            Float64(global_budget["energy_conservation_absolute"]),
        "global_error_budget_pass" => fine["solution_error"] <= Float64(global_budget["solution_absolute"]),
        "promotion_scope" => pass ? "C1_reduced_coupling_only" : "none", "errors" => errors,
    )
end
