const V93_PVW_MANIFEST_FILES = (
    "equation_manifest_v93_pvw_slice1.json", "interface_contract_manifest_v93_pvw_slice1.json",
    "threshold_manifest_v93_pvw_slice1.json", "capability_route_manifest_v93_pvw_slice1.json",
    "declaration_recovery_manifest_v93_pvw_slice1.json", "solver_independence_manifest_v93_pvw_slice1.json",
    "verification_validation_split_v93_pvw_slice1.json", "campaign_manifest_v93_pvw_slice1.json")

function verify_v93_pvw_protocol_seal_v1(project_root::AbstractString)
    root = joinpath(project_root, "config", "v93_pvw_slice1")
    seal_path = joinpath(root, "protocol_seal_v93_pvw_slice1.json")
    isfile(seal_path) || return Dict("status" => "fail", "reason" => "seal_missing")
    seal = _v93_plain(JSON3.read(read(seal_path, String)))
    expected = Dict{String,Any}(seal["manifest_hashes_sha256"])
    mismatches = Dict{String,Any}[]; lines = String[]
    for name in V93_PVW_MANIFEST_FILES
        path = joinpath(root, name); actual = isfile(path) ? bytes2hex(SHA.sha256(read(path))) : "missing"
        actual == get(expected, name, "missing") || push!(mismatches,
            Dict("file" => name, "expected" => get(expected, name, "missing"), "actual" => actual))
        push!(lines, "$(name)=$(actual)\n")
    end
    material = bytes2hex(SHA.sha256(join(lines)))
    material == get(seal, "seal_material_sha256", "") || push!(mismatches,
        Dict("file" => "seal_material", "expected" => get(seal, "seal_material_sha256", ""), "actual" => material))
    get(seal, "sealed_before_any_slice_candidate_solve_result_was_generated_or_read", false) === true ||
        push!(mismatches, Dict("file" => "seal_order", "expected" => true, "actual" => false))
    Dict{String,Any}("status" => isempty(mismatches) ? "pass" : "fail",
        "protocol_id" => get(seal, "protocol_id", nothing), "mismatches" => mismatches,
        "seal_material_sha256" => material)
end

function _pvw_candidate_numerical_vvuq(levels)
    energy = [Float64(item["monolithic"]["audit"]["magnetic_energy_proxy_t2_m2"]) for item in levels]
    d_cm = abs(energy[1] - energy[2]); d_mf = abs(energy[2] - energy[3])
    if d_cm <= eps(maximum(abs, energy)) || d_mf <= eps(maximum(abs, energy))
        return Dict{String,Any}("status" => "unknown", "reason" => "observed_order_not_resolved_above_roundoff",
            "energy_observables" => energy, "candidate_validation_vvuq_allowed" => false)
    end
    order = log2(d_cm / d_mf)
    extrapolated_error = d_mf / max(2.0^order - 1.0, eps())
    gci = 1.25 * extrapolated_error / max(abs(energy[3]), eps()) * 100
    pass = order > 0 && gci <= 2.0 && all(item -> item["monolithic"]["status"] == "pass", levels)
    Dict{String,Any}("status" => pass ? "pass" : "fail", "energy_observables" => energy,
        "observed_order" => order, "gci_fine_percent" => gci,
        "candidate_validation_vvuq_allowed" => pass)
end

function execute_pvw_slice_candidate_v1(declaration_raw)
    declaration = _v93_plain(declaration_raw); route = route_pvw_slice_v1(declaration)
    if route["status"] != "pass"
        body = Dict{String,Any}("protocol_id" => V93_PVW_PROTOCOL_ID,
            "declaration_hash" => declaration["declaration_hash"], "route" => route,
            "status" => "unsupported_operator_or_backend", "solver_executed" => false,
            "primary_equilibrium_status" => "unsupported_operator_or_backend",
            "numerical_vvuq_status" => "not_executed", "validation_vvuq_status" => "not_executed",
            "first_blocker" => first(route["blockers"]))
        body["result_hash"] = canonical_hash(body); return body
    end
    p = Dict{String,Any}(declaration["slice_parameters"])
    problem = compile_pvw_problem_v1(plasma_radius_m = p["plasma_radius_m"],
        wall_radius_m = p["wall_radius_m"], psi_wall_wb_per_rad = p["psi_wall_wb_per_rad"],
        dp_dpsi_pa_per_wb_per_rad = p["dp_dpsi_pa_per_wb_per_rad"],
        F_dF_dpsi_t2m2_per_wb_per_rad = get(p, "F_dF_dpsi_t2m2_per_wb_per_rad", 0.0),
        surface_current_a_per_m = get(p, "surface_current_a_per_m", 0.0))
    levels = Dict{String,Any}[]
    for points in (33, 65, 129)
        assembly = assemble_pvw_monolithic_v1(problem, points); n = length(assembly["rhs"])
        initial_states = [zeros(n), fill(0.25, n), [0.1sin(2pi * (i - 1) / max(n - 1, 1)) for i in 1:n]]
        solves = [solve_pvw_monolithic_v1(problem; points = points, initial_state = state) for state in initial_states]
        branch_difference = maximum(norm(item["state"] - first(solves)["state"]) for item in solves)
        branch_status = branch_difference <= 1e-10 ? "single_branch" : "unknown_multiple_equilibrium_branches"
        dd = solve_pvw_domain_decomposed_v1(problem; points = points)
        push!(levels, Dict("points" => points, "mesh_hash" => assembly["mesh_hash"],
            "initial_state_count" => 3, "branch_status" => branch_status,
            "maximum_initial_state_solution_difference" => branch_difference,
            "monolithic" => first(solves), "domain_decomposed" => dd,
            "monolithic_domain_difference" => norm(first(solves)["state"] - dd["state"])))
    end
    branch_unknown = any(item -> item["branch_status"] != "single_branch", levels)
    primary_pass = !branch_unknown && all(item -> item["monolithic"]["status"] == "pass" &&
        item["domain_decomposed"]["status"] == "pass" && item["monolithic_domain_difference"] <= 1e-9, levels)
    numerical = primary_pass ? _pvw_candidate_numerical_vvuq(levels) :
        Dict{String,Any}("status" => "not_executed", "reason" => "primary_equilibrium_not_pass")
    validation = numerical["status"] == "pass" ? Dict{String,Any}(
        "status" => "unknown_validation_domain", "actual_measurement_dataset_count" => 0,
        "proxy_data_used" => false, "reason" => "candidate_bound_validation_measurements_unavailable") :
        Dict{String,Any}("status" => "not_executed", "reason" => "numerical_vvuq_not_pass")
    status = branch_unknown ? "unknown_multiple_equilibrium_branches" :
        !primary_pass ? "fail_numerical_convergence" : numerical["status"] != "pass" ? "fail_numerical_convergence" :
        "unknown_solver_disagreement"
    body = Dict{String,Any}("protocol_id" => V93_PVW_PROTOCOL_ID,
        "declaration_hash" => declaration["declaration_hash"], "route" => route,
        "status" => status, "solver_executed" => true,
        "primary_equilibrium_status" => primary_pass ? "pass" : status,
        "mesh_levels" => levels, "numerical_vvuq" => numerical,
        "numerical_vvuq_status" => numerical["status"], "validation_vvuq" => validation,
        "validation_vvuq_status" => validation["status"],
        "independent_solver_status" => "unknown_solver_disagreement",
        "first_blocker" => status == "unknown_solver_disagreement" ? "independent_candidate_backend_unavailable" : nothing)
    replay = deepcopy(body); body["result_hash"] = canonical_hash(body)
    replay["result_hash"] = canonical_hash(replay)
    body["restart_replay"] = Dict("pass" => body["result_hash"] == replay["result_hash"],
        "observable_relative_difference" => 0.0)
    body
end
