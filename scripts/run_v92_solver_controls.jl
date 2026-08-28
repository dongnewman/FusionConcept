using FusionConceptAI
using JSON3

root = normpath(joinpath(@__DIR__, ".."))
assert_protocol_sealed_v92(root)
run_root = joinpath(root, "runs", "physical_closure_v92_formal_417_20260828")
control_root = joinpath(run_root, "controls")
request_root = joinpath(control_root, "requests")
result_root = joinpath(control_root, "results")
mkpath.(String[request_root, result_root])

function immutable_json(path, value)
    FusionConceptAI._v92_write_immutable(path,
        FusionConceptAI._v92_json_text(value))
end

function capture_command(command::Cmd)
    stdout_buffer = IOBuffer(); stderr_buffer = IOBuffer()
    process = run(pipeline(ignorestatus(command), stdout = stdout_buffer,
        stderr = stderr_buffer))
    return process.exitcode, String(take!(stdout_buffer)),
        String(take!(stderr_buffer))
end

installation_audit = audit_solver_installations_v92(root)
immutable_json(joinpath(control_root, "solver_installation_audit_v92.json"),
    installation_audit)

vmex_input = joinpath(root, ".conda-vmex", "Lib", "site-packages",
    "vmex", "resources", "input.nfp4_QH_warm_start")
vmex_executable = joinpath(root, ".conda-vmex", "Scripts", "vmec.exe")
vmex_output = joinpath(control_root, "vmex_3d_equilibrium_output")
mkpath(vmex_output)
vmex_request = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
    "control_id" => "vmex_bundled_nfp4_qh_fixed_boundary_v92",
    "control_class" => "three_dimensional_equilibrium_verification_control",
    "backend_id" => "vmex_0_7_0", "backend_version" => "VMEX 0.7.0",
    "backend_executable_sha256" => FusionConceptAI._v92_sha256_file(vmex_executable),
    "input_path" => replace(relpath(vmex_input, root), '\\' => '/'),
    "input_sha256" => FusionConceptAI._v92_sha256_file(vmex_input),
    "command" => [replace(relpath(vmex_executable, root), '\\' => '/'),
        replace(relpath(vmex_input, root), '\\' => '/'), "--device", "cpu",
        "--outdir", replace(relpath(vmex_output, root), '\\' => '/')],
    "equation_scope" => "three_dimensional_nested_surface_fixed_boundary",
    "validation_credit" => false, "candidate_feasibility_credit" => false)
vmex_request["request_hash"] = canonical_hash(vmex_request)
immutable_json(joinpath(request_root, "vmex_3d_equilibrium_request_v92.json"),
    vmex_request)

vmex_result_path = joinpath(result_root,
    "vmex_3d_equilibrium_result_v92.json")
if !isfile(vmex_result_path)
    started = time_ns()
    exit_code, stdout_text, stderr_text = capture_command(`$vmex_executable $vmex_input --device cpu --outdir $vmex_output`)
    wall_seconds = (time_ns() - started) / 1e9
    FusionConceptAI._v92_write_immutable(joinpath(control_root,
        "vmex_3d_equilibrium_stdout.log"), stdout_text)
    FusionConceptAI._v92_write_immutable(joinpath(control_root,
        "vmex_3d_equilibrium_stderr.log"), stderr_text)
    wout_files = sort!(filter(path -> startswith(basename(path), "wout_") &&
        endswith(lowercase(path), ".nc"), [joinpath(directory, file) for
        (directory, _, files) in walkdir(vmex_output) for file in files]))
    metrics = Dict{String,Any}()
    if exit_code == 0 && !isempty(wout_files)
        parser = joinpath(root, ".conda-vmex", "python.exe")
        code = "from netCDF4 import Dataset; import json,sys; d=Dataset(sys.argv[1]); keys=['ier_flag','fsqr','fsqz','fsql','niter','ftolv','aspect','betatotal']; out={};\nfor k in keys:\n v=d.variables.get(k); out[k]=None if v is None else v[:].tolist();\nprint(json.dumps(out,sort_keys=True))"
        parse_exit, parse_stdout, parse_stderr = capture_command(
            `$parser -c $code $(first(wout_files))`)
        parse_exit == 0 || error("VMEX WOUT metric extraction failed: $(parse_stderr)")
        metrics = FusionConceptAI._v92_plain(JSON3.read(strip(parse_stdout)))
    end
    convergence_pass = exit_code == 0 && !isempty(wout_files) &&
        get(metrics, "ier_flag", 1) == 0 &&
        all(key -> get(metrics, key, Inf) !== nothing &&
            Float64(metrics[key]) <= 1e-8, ("fsqr", "fsqz", "fsql"))
    result = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "control_id" => vmex_request["control_id"],
        "request_hash" => vmex_request["request_hash"],
        "backend_id" => "vmex_0_7_0", "solver_executed" => true,
        "exit_code" => exit_code, "wall_seconds" => wall_seconds,
        "output_files" => [Dict("path" => replace(relpath(path, root), '\\' => '/'),
            "sha256" => FusionConceptAI._v92_sha256_file(path),
            "bytes" => filesize(path)) for path in wout_files],
        "metrics" => metrics,
        "solver_convergence_control_status" => convergence_pass ? "pass" : "fail",
        "qualification_status" => convergence_pass ?
            "unknown_incomplete_divB_boundary_and_cross_code_observables" : "fail",
        "validation_credit" => false, "candidate_feasibility_credit" => false,
        "claim_boundary" => "This is a bundled fixed-boundary verification control. It is not a candidate-bound solve, independent cross-code comparison, or experimental validation.")
    result["result_hash"] = canonical_hash(result)
    immutable_json(vmex_result_path, result)
end

freegs_python = joinpath(root, ".venv-freegs", "Scripts", "python.exe")
freegs_test = joinpath(root, ".venv-freegs", "Lib", "site-packages", "freegs",
    "test_equilibrium.py")
freegs_request = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
    "control_id" => "freegs_equilibrium_verification_v92",
    "control_class" => "axisymmetric_equilibrium_code_verification",
    "backend_id" => "freegs_0_8_2", "backend_version" => "FreeGS 0.8.2",
    "backend_executable_sha256" => FusionConceptAI._v92_sha256_file(freegs_python),
    "test_path" => replace(relpath(freegs_test, root), '\\' => '/'),
    "test_sha256" => FusionConceptAI._v92_sha256_file(freegs_test),
    "command" => [replace(relpath(freegs_python, root), '\\' => '/'), "-m",
        "pytest", replace(relpath(freegs_test, root), '\\' => '/'), "-q"],
    "validation_credit" => false, "candidate_feasibility_credit" => false)
freegs_request["request_hash"] = canonical_hash(freegs_request)
immutable_json(joinpath(request_root, "freegs_verification_request_v92.json"),
    freegs_request)
freegs_result_path = joinpath(result_root, "freegs_verification_result_v92.json")
if !isfile(freegs_result_path)
    started = time_ns()
    exit_code, stdout_text, stderr_text = capture_command(
        `$freegs_python -m pytest $freegs_test -q`)
    wall_seconds = (time_ns() - started) / 1e9
    FusionConceptAI._v92_write_immutable(joinpath(control_root,
        "freegs_verification_stdout.log"), stdout_text)
    FusionConceptAI._v92_write_immutable(joinpath(control_root,
        "freegs_verification_stderr.log"), stderr_text)
    result = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "control_id" => freegs_request["control_id"],
        "request_hash" => freegs_request["request_hash"],
        "backend_id" => "freegs_0_8_2", "solver_executed" => true,
        "exit_code" => exit_code, "wall_seconds" => wall_seconds,
        "code_verification_status" => exit_code == 0 ? "pass" : "fail",
        "qualification_status" => exit_code == 0 ?
            "verification_pass_no_validation_or_candidate_credit" : "fail",
        "validation_credit" => false, "candidate_feasibility_credit" => false,
        "claim_boundary" => "FreeGS package tests are code verification only; they do not validate a model or qualify a candidate.")
    result["result_hash"] = canonical_hash(result)
    immutable_json(freegs_result_path, result)
end

missing_controls = Dict{String,Any}[
    Dict("control_id" => "iter_design_engineering_control_v92",
        "status" => "unknown_candidate_bound_design_control_not_compiled",
        "validation_credit" => false,
        "reason" => "no immutable ITER design regression input and engineering-obligation transformer is attested"),
    Dict("control_id" => "c2w_experimental_control_v92",
        "status" => "unknown_actual_measurement_dataset_not_attested",
        "validation_credit" => false,
        "reason" => "no exact C-2W shot/run inventory with two diagnostics, calibration, uncertainties, boundaries, and data hashes is present"),
    Dict("control_id" => "independent_3d_equilibrium_cross_code_control_v92",
        "status" => "unknown_matched_desc_vmex_execution_not_completed",
        "validation_credit" => false,
        "reason" => "VMEX control executed but no matched candidate-independent DESC solve on the identical profiles and boundary has been executed")]
for control in missing_controls
    control["schema_version"] = "1.0.0"; control["protocol_id"] = V92_PROTOCOL_ID
    control["candidate_feasibility_credit"] = false
    control["result_hash"] = canonical_hash(control)
end
immutable_json(joinpath(result_root, "missing_known_controls_v92.json"),
    Dict("controls" => missing_controls))

summary = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
    "vmex_control" => FusionConceptAI._v92_json(vmex_result_path),
    "freegs_control" => FusionConceptAI._v92_json(freegs_result_path),
    "missing_controls" => missing_controls,
    "known_device_control_qualification_status" => "fail",
    "first_blocker" => "c2w_actual_measurement_dataset_not_attested",
    "pilot_to_full_transition_allowed" => false,
    "computationally_credible_new_device_count" => 0,
    "experimentally_validated_new_fusion_device_count" => 0,
    "claim_boundary" => "Known controls are not candidate feasibility credit. The transition remains blocked until every preregistered control and independent comparison passes.")
summary["summary_hash"] = canonical_hash(summary)
immutable_json(joinpath(control_root, "control_qualification_summary_v92.json"),
    summary)
JSON3.pretty(stdout, summary; allow_inf = false)
println()
