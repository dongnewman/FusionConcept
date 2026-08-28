const PLASMA_VACUUM_WALL_SLICE_V1_CLAIM_BOUNDARY =
    "This solver executes the preregistered one-dimensional axisymmetric radial Grad-Shafranov slice with explicit plasma-vacuum trace constraints. It cannot solve or credit open, terminal, coil-dynamic, wall-dynamic, three-dimensional, anisotropic, flow, extended-MHD, or transport declarations."

struct PlasmaVacuumWallProblemV1
    plasma_radius_m::Float64
    wall_radius_m::Float64
    psi_wall_wb_per_rad::Float64
    dp_dpsi_pa_per_wb_per_rad::Float64
    F_dF_dpsi_t2m2_per_wb_per_rad::Float64
    surface_current_a_per_m::Float64
    problem_hash::String
end

function compile_pvw_problem_v1(; plasma_radius_m, wall_radius_m,
        psi_wall_wb_per_rad, dp_dpsi_pa_per_wb_per_rad,
        F_dF_dpsi_t2m2_per_wb_per_rad = 0.0, surface_current_a_per_m = 0.0)
    a = Float64(plasma_radius_m); b = Float64(wall_radius_m)
    all(isfinite, (a, b, psi_wall_wb_per_rad, dp_dpsi_pa_per_wb_per_rad,
        F_dF_dpsi_t2m2_per_wb_per_rad, surface_current_a_per_m)) ||
        throw(ArgumentError("PVW parameters must be finite"))
    0.0 < a < b || throw(ArgumentError("PVW requires 0 < plasma radius < wall radius"))
    body = Dict{String,Any}("protocol_id" => V93_PVW_PROTOCOL_ID,
        "slice_id" => "axisymmetric_radial_plasma_vacuum_wall_static_equilibrium_v1",
        "plasma_radius_m" => a, "wall_radius_m" => b,
        "psi_wall_wb_per_rad" => Float64(psi_wall_wb_per_rad),
        "dp_dpsi_pa_per_wb_per_rad" => Float64(dp_dpsi_pa_per_wb_per_rad),
        "F_dF_dpsi_t2m2_per_wb_per_rad" => Float64(F_dF_dpsi_t2m2_per_wb_per_rad),
        "surface_current_a_per_m" => Float64(surface_current_a_per_m))
    PlasmaVacuumWallProblemV1(a, b, Float64(psi_wall_wb_per_rad),
        Float64(dp_dpsi_pa_per_wb_per_rad), Float64(F_dF_dpsi_t2m2_per_wb_per_rad),
        Float64(surface_current_a_per_m), canonical_hash(body))
end

function _pvw_indices(np, nv)
    psi_p = 1:np; q_p = (np + 1):(2np)
    psi_v = (2np + 1):(2np + nv); q_v = (2np + nv + 1):(2np + 2nv)
    psi_p, q_p, psi_v, q_v
end

function assemble_pvw_monolithic_v1(problem::PlasmaVacuumWallProblemV1, points::Int)
    points >= 5 && isodd(points) || throw(ArgumentError("PVW mesh points must be odd and at least five"))
    np = (points + 1) ÷ 2; nv = points - np + 1
    rp = collect(range(0.0, problem.plasma_radius_m; length = np))
    rv = collect(range(problem.plasma_radius_m, problem.wall_radius_m; length = nv))
    n = 2np + 2nv; A = zeros(Float64, n, n); b = zeros(Float64, n)
    psi_p, q_p, psi_v, q_v = _pvw_indices(np, nv)
    row = 0; mu0 = 4pi * 1e-7
    for i in 1:(np - 1)
        row += 1; dr = rp[i + 1] - rp[i]; rm = (rp[i + 1] + rp[i]) / 2
        A[row, psi_p[i]] = -1 / dr; A[row, psi_p[i + 1]] = 1 / dr
        A[row, q_p[i]] = -rm / 2; A[row, q_p[i + 1]] = -rm / 2
    end
    for i in 1:(np - 1)
        row += 1; dr = rp[i + 1] - rp[i]; rm = (rp[i + 1] + rp[i]) / 2
        A[row, q_p[i]] = -rm / dr; A[row, q_p[i + 1]] = rm / dr
        b[row] = -(mu0 * rm^2 * problem.dp_dpsi_pa_per_wb_per_rad +
            problem.F_dF_dpsi_t2m2_per_wb_per_rad)
    end
    row += 1; A[row, q_p[1]] = 1.0
    plasma_rows = 1:row
    vacuum_start = row + 1
    for i in 1:(nv - 1)
        row += 1; dr = rv[i + 1] - rv[i]; rm = (rv[i + 1] + rv[i]) / 2
        A[row, psi_v[i]] = -1 / dr; A[row, psi_v[i + 1]] = 1 / dr
        A[row, q_v[i]] = -rm / 2; A[row, q_v[i + 1]] = -rm / 2
    end
    for i in 1:(nv - 1)
        row += 1; dr = rv[i + 1] - rv[i]; rm = (rv[i + 1] + rv[i]) / 2
        A[row, q_v[i]] = -rm / dr; A[row, q_v[i + 1]] = rm / dr
    end
    row += 1; A[row, psi_v[end]] = 1.0; b[row] = problem.psi_wall_wb_per_rad
    vacuum_rows = vacuum_start:row
    row += 1; A[row, psi_p[end]] = 1.0; A[row, psi_v[1]] = -1.0
    row += 1; A[row, q_p[end]] = 1.0; A[row, q_v[1]] = -1.0
    b[row] = mu0 * problem.surface_current_a_per_m
    row == n || error("PVW monolithic assembly row mismatch")
    body = Dict("problem_hash" => problem.problem_hash, "points" => points,
        "plasma_grid" => rp, "vacuum_grid" => rv, "matrix" => vec(A), "rhs" => b,
        "interface_method" => "mixed_conforming_trace_constraints")
    Dict{String,Any}("matrix" => A, "rhs" => b, "plasma_grid" => rp,
        "vacuum_grid" => rv, "plasma_rows" => plasma_rows, "vacuum_rows" => vacuum_rows,
        "interface_rows" => (row - 1):row, "indices" => (psi_p, q_p, psi_v, q_v),
        "mesh_hash" => canonical_hash(Dict("plasma_grid" => rp, "vacuum_grid" => rv)),
        "assembly_hash" => canonical_hash(body))
end

function _pvw_solution_audit(problem, assembly, x)
    A = assembly["matrix"]; b = assembly["rhs"]
    rp = assembly["plasma_grid"]; rv = assembly["vacuum_grid"]
    psi_p, q_p, psi_v, q_v = assembly["indices"]
    residual = A * x - b
    interface_flux = x[psi_p[end]] - x[psi_v[1]]
    interface_field = x[q_p[end]] - x[q_v[1]] - 4pi * 1e-7 * problem.surface_current_a_per_m
    force = Float64[]; mu0 = 4pi * 1e-7
    for i in 1:(length(rp) - 1)
        dr = rp[i + 1] - rp[i]; rm = (rp[i + 1] + rp[i]) / 2
        qm = (x[q_p[i + 1]] + x[q_p[i]]) / 2
        dq = (x[q_p[i + 1]] - x[q_p[i]]) / dr
        push!(force, -(dq / mu0) * qm - problem.dp_dpsi_pa_per_wb_per_rad * rm * qm)
    end
    force_reference = problem.dp_dpsi_pa_per_wb_per_rad .* ((rp[1:end-1] .+ rp[2:end]) ./ 2) .*
        ((x[q_p[1:end-1]] .+ x[q_p[2:end]]) ./ 2)
    force_scale = max(maximum(abs, force_reference; init = 0.0), 1.0)
    magnetic_energy_proxy = 0.0
    for (grid, qidx) in ((rp, q_p), (rv, q_v))
        for i in 1:(length(grid) - 1)
            dr = grid[i + 1] - grid[i]
            magnetic_energy_proxy += dr * (grid[i] * x[qidx[i]]^2 +
                grid[i + 1] * x[qidx[i + 1]]^2) / 2
        end
    end
    Dict{String,Any}("normalized_monolithic_residual" => norm(residual) / max(norm(b), 1.0),
        "interface_flux_residual" => abs(interface_flux),
        "interface_field_jump_residual" => abs(interface_field),
        "normalized_force_balance_l2" => norm(force) / max(sqrt(length(force)) * force_scale, 1.0),
        "normalized_force_balance_linf" => maximum(abs, force; init = 0.0) / force_scale,
        "psi_axis" => x[psi_p[1]], "psi_interface" => x[psi_p[end]],
        "maximum_abs_magnetic_field_t" => maximum(abs, vcat(x[q_p], x[q_v])),
        "magnetic_energy_proxy_t2_m2" => magnetic_energy_proxy,
        "state_hash" => canonical_hash(x), "final_monolithic_reaudit" => true)
end

function solve_pvw_monolithic_v1(problem::PlasmaVacuumWallProblemV1; points = 65,
        initial_state = nothing)
    assembly = assemble_pvw_monolithic_v1(problem, Int(points))
    x0 = initial_state === nothing ? zeros(Float64, length(assembly["rhs"])) : Float64.(initial_state)
    length(x0) == length(assembly["rhs"]) || throw(ArgumentError("PVW initial state size mismatch"))
    residual0 = assembly["matrix"] * x0 - assembly["rhs"]
    x = x0 - assembly["matrix"] \ residual0
    audit = _pvw_solution_audit(problem, assembly, x)
    Dict{String,Any}("status" => audit["normalized_monolithic_residual"] <= 1e-8 &&
        audit["interface_flux_residual"] <= 1e-8 && audit["interface_field_jump_residual"] <= 1e-7 ? "pass" : "fail_numerical_convergence",
        "algorithm" => "exact_jacobian_newton_one_step_linear_slice",
        "points" => points, "mesh_hash" => assembly["mesh_hash"], "assembly_hash" => assembly["assembly_hash"],
        "state" => x, "audit" => audit, "initial_residual_norm" => norm(residual0),
        "iteration_count" => 1, "problem_hash" => problem.problem_hash)
end

function _pvw_affine_region_solution(A, b)
    factor = svd(A; full = true)
    rank_a = count(>(maximum(factor.S) * eps(Float64) * max(size(A)...)), factor.S)
    rank_a == size(A, 1) || throw(ArgumentError("PVW regional operator lost row rank"))
    particular = A \ b
    null_basis = factor.V[:, (rank_a + 1):end]
    size(null_basis, 2) == 1 || throw(ArgumentError("PVW region must expose one trace degree"))
    particular, vec(null_basis)
end

function solve_pvw_domain_decomposed_v1(problem::PlasmaVacuumWallProblemV1; points = 65)
    assembly = assemble_pvw_monolithic_v1(problem, Int(points))
    A = assembly["matrix"]; b = assembly["rhs"]
    pr = assembly["plasma_rows"]; vr = assembly["vacuum_rows"]; ir = assembly["interface_rows"]
    npvars = 2length(assembly["plasma_grid"]); pcols = 1:npvars
    vcols = (npvars + 1):size(A, 2)
    xp0, np = _pvw_affine_region_solution(A[pr, pcols], b[pr])
    xv0, nv = _pvw_affine_region_solution(A[vr, vcols], b[vr])
    C0 = A[ir, pcols] * xp0 + A[ir, vcols] * xv0 - b[ir]
    S = hcat(A[ir, pcols] * np, A[ir, vcols] * nv)
    alpha = -(S \ C0)
    x = [xp0 + np * alpha[1]; xv0 + nv * alpha[2]]
    audit = _pvw_solution_audit(problem, assembly, x)
    Dict{String,Any}("status" => audit["normalized_monolithic_residual"] <= 1e-8 ? "pass" : "fail_numerical_convergence",
        "algorithm" => "two_region_nullspace_schur_domain_decomposition",
        "points" => points, "mesh_hash" => assembly["mesh_hash"], "assembly_hash" => assembly["assembly_hash"],
        "state" => x, "audit" => audit, "interface_schur_hash" => canonical_hash(vec(S)),
        "final_monolithic_reaudit" => true, "problem_hash" => problem.problem_hash)
end

function manufactured_pvw_problem_v1(; plasma_radius_m = 1.0, wall_radius_m = 2.0,
        quartic_coefficient = 0.1)
    mu0 = 4pi * 1e-7; c = Float64(quartic_coefficient)
    problem = compile_pvw_problem_v1(plasma_radius_m = plasma_radius_m,
        wall_radius_m = wall_radius_m, psi_wall_wb_per_rad = 0.0,
        dp_dpsi_pa_per_wb_per_rad = -8c / mu0,
        F_dF_dpsi_t2m2_per_wb_per_rad = 0.0, surface_current_a_per_m = 0.0)
    a = problem.plasma_radius_m; b = problem.wall_radius_m
    constant = 2c * a^2 * (a^2 - b^2) - c * a^4
    exact = function (r, region)
        region == "plasma" ? (c * r^4 + constant, 4c * r^2) :
            (2c * a^2 * (r^2 - b^2), 4c * a^2)
    end
    problem, exact
end

function _pvw_function_space_error(solution, assembly, exact)
    psi_p, q_p, psi_v, q_v = assembly["indices"]
    state = solution["state"]; error_sq = 0.0; reference_sq = 0.0
    gauss = (-inv(sqrt(3.0)), inv(sqrt(3.0)))
    for (grid, psi_idx, q_idx, region) in ((assembly["plasma_grid"], psi_p, q_p, "plasma"),
            (assembly["vacuum_grid"], psi_v, q_v, "vacuum"))
        for i in 1:(length(grid) - 1)
            left = grid[i]; right = grid[i + 1]; half = (right - left) / 2; center = (right + left) / 2
            for xi in gauss
                r = center + half * xi; t = (r - left) / (right - left)
                psi_h = (1 - t) * state[psi_idx[i]] + t * state[psi_idx[i + 1]]
                q_h = (1 - t) * state[q_idx[i]] + t * state[q_idx[i + 1]]
                psi_exact, q_exact = exact(r, region)
                error_sq += half * ((psi_h - psi_exact)^2 + (q_h - q_exact)^2)
                reference_sq += half * (psi_exact^2 + q_exact^2)
            end
        end
    end
    sqrt(error_sq / max(reference_sq, eps()))
end

function run_pvw_manufactured_verification_v1()
    problem, exact = manufactured_pvw_problem_v1()
    levels = Dict{String,Any}[]
    for points in (33, 65, 129)
        mono = solve_pvw_monolithic_v1(problem; points = points)
        dd = solve_pvw_domain_decomposed_v1(problem; points = points)
        assembly = assemble_pvw_monolithic_v1(problem, points)
        rp = assembly["plasma_grid"]; rv = assembly["vacuum_grid"]
        psi_p, q_p, psi_v, q_v = assembly["indices"]
        relative_error = _pvw_function_space_error(mono, assembly, exact)
        push!(levels, Dict("points" => points, "relative_state_error" => relative_error,
            "monolithic" => mono, "domain_decomposed_state_difference" => norm(mono["state"] - dd["state"]),
            "domain_decomposed_audit" => dd["audit"]))
    end
    e = [Float64(level["relative_state_error"]) for level in levels]
    p_cm = log2(e[1] / e[2]); p_mf = log2(e[2] / e[3])
    p = min(p_cm, p_mf); gci = 1.25 * e[3] / max(2.0^p - 1.0, eps()) * 100
    pass = all(level -> level["monolithic"]["status"] == "pass" &&
        level["domain_decomposed_state_difference"] <= 1e-9, levels) && p > 0 && gci <= 2.0
    body = Dict{String,Any}("status" => pass ? "pass" : "fail",
        "control_type" => "analytic_manufactured_verification",
        "candidate_equilibrium_credit" => false, "problem_hash" => problem.problem_hash,
        "levels" => levels, "observed_order_coarse_medium" => p_cm,
        "observed_order_medium_fine" => p_mf, "gci_fine_percent" => gci,
        "numerical_vvuq_status" => pass ? "pass" : "fail",
        "claim_boundary" => PLASMA_VACUUM_WALL_SLICE_V1_CLAIM_BOUNDARY)
    body["verification_hash"] = canonical_hash(body)
    body
end
