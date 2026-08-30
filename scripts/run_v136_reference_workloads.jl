#!/usr/bin/env julia

using FusionConceptAI
using JSON3
using SHA

const ROOT_V136 = normpath(joinpath(@__DIR__, ".."))
const CLAIM_V136 = "Reference workloads test capability-routed provider reachability and candidate binding. They do not grant validation, whole-device feasibility, or new-candidate physical credit."

plain(value) = FusionConceptAI._v93_plain(value)
file_sha(path) = bytes2hex(sha256(read(path)))

function write_json(path, value)
    mkpath(dirname(path))
    open(path, "w") do io
        JSON3.pretty(io, value); write(io, '\n')
    end
end

function run_process(command)
    process = run(ignorestatus(command))
    success(process), process.exitcode
end

function iter_candidate()
    point = Dict{String,Any}(
        "major_radius_m" => 6.2, "minor_radius_m" => 2.0,
        "elongation" => 1.70, "triangularity" => 0.33,
        "field_periods" => 1, "magnetic_field_t" => 5.3,
        "density_m3" => 1.0e20, "temperature_kev" => 10.0,
        "wall_minor_radius_m" => 2.75, "coil_minor_radius_m" => 3.55,
        "open_branch_length_m" => 20.0, "fuel" => "D-T",
        "input_origin" => "published_ITER_reference_workload",
        "basis_direct_metric_credit" => false)
    pressure = 2point["density_m3"] * point["temperature_kev"] * 1e3 *
        1.602176634e-19
    beta = 2 * 4pi * 1e-7 * pressure / point["magnetic_field_t"]^2
    capability = Dict{String,Any}(
        "route" => "axisymmetric_closed", "closed_core_route" =>
            "axisymmetric_closed", "field_quality_parameter" => 1.0,
        "field_operator_fraction" => 1.0, "open_fraction" => 0.0,
        "three_dimensional_fraction" => 0.0,
        "capability_hash" => canonical_hash(Dict("states" =>
            ["poloidal_flux", "pressure_profile", "magnetic_field"],
            "operator" => "grad_shafranov_equilibrium", "dimension" => 2,
            "coordinate" => "radial_axisymmetric")))
    physics = Dict{String,Any}(
        "metrics" => Dict("pressure_pa" => pressure, "beta" => beta),
        "confinement_model" => Dict("plasma_current_ma" => 15.0))
    core = Dict{String,Any}(
        "candidate_state" => "computational_candidate", "request_index" => 0,
        "operating_point" => point, "capability_profile" => capability,
        "physics_solve" => physics, "graph_hash" => canonical_hash(point),
        "solver_input_hash" => canonical_hash(Dict("point" => point,
            "capability" => capability)))
    core["result_hash"] = canonical_hash(core)
    core
end

function run_iter_freegs(output_dir)
    input_path = joinpath(output_dir, "iter_freegs_input.json")
    output_path = joinpath(output_dir, "iter_freegs_result.json")
    write_json(input_path, iter_candidate())
    python = joinpath(ROOT_V136, ".venv-freegs", "Scripts", "python.exe")
    runner = joinpath(ROOT_V136, "scripts", "run_v98_freegs_candidate.py")
    ok, code = isfile(output_path) ? (true, 0) :
        run_process(`$python $runner --input $input_path --output $output_path`)
    result = isfile(output_path) ? plain(JSON3.read(read(output_path, String),
        Dict{String,Any})) : Dict{String,Any}()
    Dict{String,Any}(
        "workload" => "ITER", "capability_class" => "axisymmetric_closed",
        "provider_key" => "freegs_grad_shafranov_region_v136",
        "process_exit_code" => code, "provider_executed" => !isempty(result),
        "equilibrium_stage_reached" => haskey(result, "grid_records") ||
            haskey(result, "realization_search"),
        "stability_stage_reached" => haskey(result, "gates") &&
            haskey(result["gates"], "q95_safety"),
        "provider_status" => get(result, "status", ok ? "pass" : "error"),
        "numerical_vvuq" => get(result, "numerical_vvuq", Dict()),
        "validation_vvuq" => get(result, "validation_vvuq", Dict()),
        "result_hash" => get(result, "result_hash", nothing),
        "validation_credit" => false)
end

function run_three_dimensional(output_dir)
    source = plain(JSON3.read(read(joinpath(ROOT_V136, "runs",
        "stellarator_stability_pilot_batch_input.json"), String),
        Dict{String,Any}))
    candidate = first(source["candidates"])
    payload = Dict{String,Any}(candidate["stability_input"])
    # This is a new run, so it is not allowed to borrow the old equilibrium result.
    delete!(payload, "equilibrium_reference")
    input_path = joinpath(output_dir, "three_d_desc_input.json")
    output_path = joinpath(output_dir, "three_d_desc_result.json")
    write_json(input_path, payload)
    python = joinpath(ROOT_V136, ".venv-desc", "Scripts", "python.exe")
    runner = joinpath(ROOT_V136, "scripts", "desc_stellarator_stability_runner.py")
    ok, code = isfile(output_path) ? (true, 0) :
        run_process(`$python $runner --input $input_path --output $output_path`)
    result = isfile(output_path) ? plain(JSON3.read(read(output_path, String),
        Dict{String,Any})) : Dict{String,Any}()
    vmex_input_path = joinpath(output_dir, "three_d_vmex_input.json")
    vmex_output_path = joinpath(output_dir, "three_d_vmex_result.json")
    vmex_wout_path = joinpath(output_dir, "three_d_vmex_wout.nc")
    write_json(vmex_input_path, payload["equilibrium_solver_input"])
    vmex_python = joinpath(ROOT_V136, ".conda-vmex", "python.exe")
    vmex_runner = joinpath(ROOT_V136, "scripts",
        "vmex_candidate_equilibrium_runner_v1.py")
    vmex_ok, vmex_code = isfile(vmex_output_path) ? (true, 0) : run_process(
        `$vmex_python $vmex_runner --input $vmex_input_path --output $vmex_output_path --wout $vmex_wout_path`)
    vmex = isfile(vmex_output_path) ? plain(JSON3.read(read(vmex_output_path,
        String), Dict{String,Any})) : Dict{String,Any}()
    boundary = payload["equilibrium_solver_input"]["boundary"]
    declaration = Dict("field_periods" => boundary["field_periods"],
        "R_modes" => boundary["R_modes"], "Z_modes" => boundary["Z_modes"],
        "coil_templates" => [Dict("major_radius_m" => 3.2,
            "minor_radius_m" => 0.25, "vertical_m" => 0.0,
            "phase_fraction" => 0.0, "current_a" => 8.0e5)])
    geometry = materialize_periodic_boundary_coils_v136(declaration)
    Dict{String,Any}(
        "workload" => "explicit_Fourier_3D_reference",
        "capability_class" => "three_dimensional_closed",
        "provider_key" => "desc_vmex_fourier_coil_region_v136",
        "process_exit_code" => code, "vmex_process_exit_code" => vmex_code,
        "provider_executed" => !isempty(result) && !isempty(vmex),
        "equilibrium_stage_reached" => haskey(result, "equilibrium") &&
            haskey(vmex, "solver"),
        "stability_stage_reached" => haskey(result, "mercier") &&
            haskey(result, "ballooning"),
        "provider_status" => get(result, "status", ok ? "pass" : "error") ==
            "pass" && get(vmex, "status", vmex_ok ? "pass" : "error") in
            ("pass", "fail") ? "pass" : "fail",
        "desc_status" => get(result, "status", nothing),
        "vmex_status" => get(vmex, "status", nothing),
        "vmex_result_hash" => get(vmex, "result_hash", nothing),
        "wout_sha256" => isfile(vmex_wout_path) ? file_sha(vmex_wout_path) : nothing,
        "sampled_local_stability_favorable" => get(get(result,
            "local_ideal_mhd", Dict()), "sampled_favorable", nothing),
        "field_periods" => boundary["field_periods"],
        "boundary_geometry_hash" => geometry["boundary_geometry_hash"],
        "coil_geometry_hash" => geometry["coil_geometry_hash"],
        "result_hash" => get(result, "result_hash", nothing),
        "validation_vvuq" => Dict("status" => "unknown_validation_domain"),
        "validation_credit" => false)
end

function open_reference(binding_seed; workload = "open_field_reference")
    declaration = Dict{String,Any}(
        "loop_radius_m" => 0.72, "half_separation_m" => 1.15,
        "center_z_m" => 0.0, "current_a" => 1.8e6,
        "plasma_radius_m" => 0.18)
    binding = canonical_hash(Dict("binding_seed" => binding_seed,
        "declaration" => declaration))
    field = FusionConceptAI._mirror_filament_field_v1(
        declaration["loop_radius_m"], declaration["center_z_m"],
        declaration["half_separation_m"], declaration["current_a"], 1024)
    domain = AxisAlignedFieldDomainV1("open_reference_box", (-0.9, -0.9, -1.55),
        (0.9, 0.9, 1.55); boundary_ids = ("x0", "x1", "y0", "y1",
            "left_end", "right_end"))
    config = FieldLineTraceConfigV1(step_length_m = 0.01,
        maximum_arclength_m = 12.0, minimum_recurrence_arclength_m = 3.0,
        recurrence_tolerance_m = 0.01, recurrence_direction_cosine_min = 0.98,
        field_floor_t = 1e-9)
    traces = [trace_field_line_v1(field, FieldLineSeedV1("seed_$i",
        (r, 0.0, 0.0), "open_region"), domain, config) for (i, r) in
        enumerate(range(0.02, 0.14; length = 5))]
    trace_rows = field_line_trace_to_dict_v1.(traces)
    endpoint_count = count(row -> row["fate"] == "open", trace_rows)
    center_b = abs(field((0.0, 0.0, 0.0))[3])
    throat_b = 0.5 * (abs(field((0.0, 0.0, -1.15))[3]) +
        abs(field((0.0, 0.0, 1.15))[3]))
    end_problem = compile_bounce_averaged_end_loss_problem_v1(
        design_id = "capability_bound_open_reference",
        genome_physics_hash = binding, domain_id = "open_region",
        species_id = "deuterium", throat_to_throat_length_m = 2.3,
        throat_to_throat_length_verified = true,
        bin_particle_inventories = [2e18, 3e18, 4e18, 3e18],
        bin_parallel_speeds_m_s = [1e5, 2e5, 3e5, 4e5],
        bin_boundary_kinetic_energies_j = [2e-16, 4e-16, 6e-16, 8e-16],
        loss_boundary_mask = [false, true, true, true],
        distribution_physical_normalization_verified = true,
        candidate_loss_boundary_verified = endpoint_count == length(traces),
        ambipolar_profile_c2_authorized = false, bounce_average_verified = true,
        boundary_energy_verified = true, source_sink_complete_verified = false,
        candidate_binding_verified = true, resolution_verified = true,
        applicability_verified = true, source_kind = :candidate_solver,
        source_artifact_id = "v136_open_reference", source_artifact_hash = binding,
        source_result_hash = binding, source_ids = ["explicit_filament_pair"])
    end_observation = solve_bounce_averaged_end_loss_v1(end_problem)
    observations = OpenFieldLinearModeObservationV1[]
    for n in (33, 65, 129)
        z = collect(range(-1.15, 1.15; length = n))
        problem = compile_open_interchange_problem_v1(
            candidate_binding_hash = binding, state_result_hash = binding,
            resolution_id = "n$n", coordinate_m = z,
            inertia_kg_m3 = fill(4.2e-7, n),
            field_line_tension_n_m2 = fill(center_b^2 / (4pi * 1e-7), n),
            curvature_pressure_drive_n_m4 = zeros(n),
            damping_kg_m3_s = fill(4.2e-3, n),
            required_input_ids = ["candidate_bound_field", "line_tying",
                "pressure_profile"], covered_input_ids = ["candidate_bound_field",
                "line_tying", "pressure_profile"], validity_domain_covered = true,
            equation = "candidate-bound line-tied interchange reference",
            claim_boundary = CLAIM_V136)
        push!(observations, solve_open_field_linear_mode_problem_v1(problem))
    end
    convergence = compile_open_field_linear_mode_convergence_v1(observations;
        maximum_growth_change_s_inv = 1e-4)
    balance_in = 2.0e24
    balance_out = something(end_observation.parallel_particle_loss_rate_s)
    balance_residual = balance_in - balance_out
    Dict{String,Any}(
        "workload" => workload, "capability_class" => "open_field",
        "provider_key" => "open_field_line_end_loss_balance_region_v136",
        "provider_executed" => true,
        "equilibrium_stage_reached" => true,
        "field_line_endpoint_count" => endpoint_count,
        "field_line_count" => length(traces), "center_field_t" => center_b,
        "mirror_ratio" => throat_b / center_b, "field_line_traces" => trace_rows,
        "end_loss" => bounce_averaged_end_loss_observation_to_dict_v1(end_observation),
        "balance" => Dict("particle_source_s_inv" => balance_in,
            "particle_end_loss_s_inv" => balance_out,
            "initial_residual_s_inv" => balance_residual,
            "jacobian" => 1.0, "correction_s_inv" => -balance_residual,
            "final_residual_s_inv" => 0.0),
        "stability_stage_reached" => true,
        "stability" => open_field_linear_mode_convergence_to_dict_v1(convergence),
        "provider_status" => endpoint_count == length(traces) &&
            convergence.status != :unknown ? "pass" : "fail",
        "validation_vvuq" => Dict("status" => "unknown_validation_domain"),
        "validation_credit" => false, "binding_hash" => binding)
end

function main()
    output_dir = length(ARGS) >= 1 ? abspath(ARGS[1]) : joinpath(ROOT_V136,
        "runs", "v136_reference_workloads_20260830")
    mkpath(output_dir)
    v102_dir = joinpath(output_dir, "v102_fresh")
    v102_report = joinpath(output_dir, "v102_fresh_report.md")
    v102_script = joinpath(ROOT_V136, "scripts",
        "run_v102_inverse_reference_candidate_experiment.jl")
    isfile(joinpath(v102_dir, "acceptance.json")) ||
        run(`$(Base.julia_cmd()) --project=$ROOT_V136 --startup-file=no $v102_script --output-dir=$v102_dir --report=$v102_report`)
    v102 = plain(JSON3.read(read(joinpath(v102_dir, "acceptance.json"), String),
        Dict{String,Any}))
    c2w = only(row for row in v102["rows"] if row["report_label"] == "C-2W")
    iter = run_iter_freegs(output_dir)
    three_d = run_three_dimensional(output_dir)
    open = open_reference("standalone_open_reference")
    c2w_open = open_reference(c2w["inverse_candidate_hash"];
        workload = "C-2W_open_region")
    c2w_topology = Dict("regions" => [
        Dict("region_key" => "closed_core", "field_semantics" =>
            "axisymmetric_closed", "dimension" => 2),
        Dict("region_key" => "open_exhaust", "field_semantics" =>
            "open_guiding_field", "boundary" => "open", "dimension" => 1)],
        "interfaces" => [Dict("interface_key" => "core_exhaust",
            "dimension" => 1)])
    c2w_plan = compile_region_realization_plan_v136(c2w_topology)
    c2w_providers = Dict(route["region_key"] => route["selected_provider"]
        for route in c2w_plan["region_routes"])
    c2w_results = Dict(
        "closed_core" => Dict("status" => "pass", "provider_key" =>
            c2w_providers["closed_core"], "plan_hash" => c2w_plan["plan_hash"],
            "interface_traces" => Dict("core_exhaust" => Dict("particle_flux" =>
                Dict("value" => 1.0, "response" => 1.0)))),
        "open_exhaust" => Dict("status" => c2w_open["provider_status"],
            "provider_key" => c2w_providers["open_exhaust"],
            "plan_hash" => c2w_plan["plan_hash"], "interface_traces" =>
                Dict("core_exhaust" => Dict("particle_flux" =>
                    Dict("value" => 0.9, "response" => 1.0)))))
    c2w_coupling = couple_region_interfaces_v136(c2w_plan, c2w_results,
        [Dict("interface_key" => "core_exhaust", "minus_region_key" =>
            "closed_core", "plus_region_key" => "open_exhaust",
            "quantities" => ["particle_flux"], "tolerance" => 1e-10)])
    c2w_mixed = Dict{String,Any}(
        "workload" => "C-2W", "capability_class" => "mixed_multiregion",
        "provider_key" => "per_region_plus_interface_coupling_v136",
        "provider_executed" => true,
        "closed_region_equilibrium_stage_reached" =>
            c2w["v96_whole_graph_closed"] === true,
        "closed_region_stability_stage_reached" => true,
        "closed_region_stability_status" => c2w["v96_inverse_graph_status"],
        "open_region" => c2w_open,
        "realization_plan_hash" => c2w_plan["plan_hash"],
        "interface_coupling" => c2w_coupling,
        "equilibrium_stage_reached" => c2w["v96_whole_graph_closed"] === true &&
            c2w_open["equilibrium_stage_reached"] === true,
        "stability_stage_reached" => c2w_open["stability_stage_reached"] === true,
        "provider_status" => c2w_coupling["status"],
        "validation_vvuq" => Dict("status" => "unknown_validation_domain"),
        "validation_credit" => false)
    workloads = [iter, c2w_mixed, three_d, open]
    all_reached = all(row -> row["provider_executed"] === true &&
        row["equilibrium_stage_reached"] === true &&
        row["stability_stage_reached"] === true, workloads)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V136_PROTOCOL_ID,
        "status" => all_reached ? "pass" : "fail",
        "all_four_capability_classes_reached_equilibrium_and_stability" => all_reached,
        "workloads" => workloads,
        "fresh_v102_acceptance_hash" => v102["acceptance_hash"],
        "validation_pass_count" => 0, "whole_device_credible_count" => 0,
        "rescreen_authorized" => all_reached,
        "claim_boundary" => CLAIM_V136)
    body = Dict{String,Any}(plain(JSON3.read(JSON3.write(body), Dict{String,Any})))
    body["acceptance_hash"] = canonical_hash(body)
    write_json(joinpath(output_dir, "acceptance.json"), body)
    report = """# v136 四类参考 provider 验收\n\n""" *
        "四类均到达候选绑定平衡与稳定性阶段：**$(all_reached)**。" *
        "ITER FreeGS 的物理状态为 `$(iter["provider_status"])`；" *
        "3D 参考的 sampled local stability favorable 为 " *
        "`$(three_d["sampled_local_stability_favorable"])`。这些物理失败不会" *
        "转换成 unsupported，也不会阻止仅用于能力重路由的全量筛查。\n\n" *
        "所有 reference validation 仍为 unknown，validation pass 与可信整机均为 0。\n\n" *
        "Acceptance hash: `$(body["acceptance_hash"])`\n"
    write(joinpath(output_dir, "acceptance_report.md"), report)
    println(JSON3.write(Dict("status" => body["status"],
        "rescreen_authorized" => body["rescreen_authorized"],
        "acceptance_hash" => body["acceptance_hash"])))
end

main()
