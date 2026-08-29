const V115_PROTOCOL_ID = "fusionconceptai-v115-corrected-whole-device-rescreen-20260830"

const CORRECTED_WHOLE_DEVICE_RESCREEN_V115_CLAIM_BOUNDARY =
    "v115 reruns the ITER/C-2W regression, binds v114 FreeGS, DESC and nine-case static " *
    "artifacts, sizes coolant flow from declared 90/110/120 K temperature rises, and " *
    "executes the reduced assembly, provider-DAG, dynamic-fault and source-pinned material " *
    "screens. Actual worst-case static field, current density and support stress replace " *
    "the earlier nominal engineering proxies. A survivor remains high-fidelity pending: " *
    "missing complete transport, exhaust, 3D neutronics/damage, nonlinear control, full " *
    "numerical VVUQ and candidate-bound validation remain independent obligations."

const V115_COOLANT_DELTA_T_K = [90.0, 110.0, 120.0]

function _v115_read_json(path)
    Dict{String,Any}(_v93_plain(JSON3.read(read(path, String))))
end

function load_v114_provider_frontier_v115(project_root::AbstractString)
    root = abspath(project_root)
    directory = joinpath(root, "runs", "v114_similarity_scaled_field_repair_20260830")
    candidates = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in
        readlines(joinpath(directory, "candidates.jsonl")) if !isempty(strip(line))]
    rows = Dict{String,Any}[]
    for candidate in candidates
        index = Int(candidate["request_index"])
        artifacts = Dict{String,Any}(
            "freegs" => _v115_read_json(joinpath(directory, "freegs", "results",
                "freegs_$(index).json")),
            "desc" => _v115_read_json(joinpath(directory, "desc", "results",
                "v99_$(index).json")),
            "static" => _v115_read_json(joinpath(directory, "static", "results",
                "static_$(index).json")),
            "artifact_directory" => basename(directory))
        for artifact in values(artifacts)
            artifact isa AbstractDict || continue
            haskey(artifact, "candidate_result_hash") || continue
            String(artifact["candidate_result_hash"]) == String(candidate["result_hash"]) ||
                throw(ArgumentError("v115 provider artifact binding mismatch"))
        end
        push!(rows, Dict("candidate" => candidate, "artifacts" => artifacts))
    end
    rows
end

function _v115_rehash_assembly!(assembly)
    design = Dict{String,Any}(assembly["physical_design"])
    pop!(design, "physical_design_hash", nothing)
    design["physical_design_hash"] = canonical_hash(design)
    assembly["physical_design"] = design
    assembly["physical_design_hash"] = design["physical_design_hash"]
    pop!(assembly, "assembly_result_hash", nothing)
    assembly["assembly_result_hash"] = canonical_hash(assembly)
    assembly
end

function generate_corrected_whole_device_assemblies_v115(candidate_raw)
    candidate = Dict{String,Any}(_v93_plain(candidate_raw))
    base = generate_whole_device_assemblies_v105(candidate; variants = 8)
    assemblies = Dict{String,Any}[]
    sequence = 0
    for proposal in base, delta_t in V115_COOLANT_DELTA_T_K
        sequence += 1
        assembly = deepcopy(proposal)
        design = Dict{String,Any}(assembly["physical_design"])
        thermal = Dict{String,Any}(design["thermal_cycle"])
        inlet = Float64(thermal["inlet_temperature_k"])
        heat = Float64(thermal["recoverable_heat_input_w"])
        cp = Float64(thermal["specific_heat_j_kg_k"])
        thermal["outlet_temperature_k"] = inlet + delta_t
        thermal["mass_flow_kg_s"] = heat / (cp * delta_t)
        thermal["declared_coolant_delta_t_k"] = delta_t
        thermal["sizing_rule"] = "candidate_power_balance_declared_delta_t_v115"
        design["thermal_cycle"] = thermal
        conductor = Dict{String,Any}(design["finite_conductor"])
        conductor["independent_dump_circuit_count"] = 4
        conductor["dump_topology"] = "four_independently_isolated_equal_energy_segments"
        conductor["per_circuit_terminal_voltage_limit_v"] =
            conductor["maximum_terminal_voltage_v"]
        design["finite_conductor"] = conductor
        design["protocol_id"] = V115_PROTOCOL_ID
        design["proposal_sequence_index"] = sequence
        design["claim_boundary"] = CORRECTED_WHOLE_DEVICE_RESCREEN_V115_CLAIM_BOUNDARY
        assembly["physical_design"] = design
        assembly["candidate_state"] = "corrected_whole_device_assembly_proposal"
        assembly["claim_boundary"] = CORRECTED_WHOLE_DEVICE_RESCREEN_V115_CLAIM_BOUNDARY
        _v115_rehash_assembly!(assembly)
        audit_whole_device_assembly_inputs_v105(assembly)["status"] == "closed" ||
            throw(ArgumentError("v115 generated a structurally invalid assembly"))
        push!(assemblies, assembly)
    end
    assemblies
end

function _v115_quench_result(design, static_raw)
    static = Dict{String,Any}(_v93_plain(static_raw))
    point = Dict{String,Any}(design["operating_point"])
    finite = Dict{String,Any}(design["finite_conductor"])
    conductor = only(item for item in Dict{String,Any}.(
        finite["coil_systems"]) if item["role"] == "poloidal_field")
    peak_field = Float64(actual_static_extrema_v115(static)["peak_field_t"])
    current = Float64(conductor["maximum_current_a_turn"])
    area = Float64(conductor["minimum_conductor_area_m2"])
    volume = 2pi * Float64(point["major_radius_m"]) * area
    magnetic_energy = peak_field^2 / (2 * 4pi * 1e-7) * volume
    total_inductance = 2magnetic_energy / current^2
    segments = Int(finite["independent_dump_circuit_count"])
    segments >= 1 || throw(ArgumentError("v115 dump circuit count must be positive"))
    voltage_limit = Float64(finite["per_circuit_terminal_voltage_limit_v"])
    resistance = voltage_limit / current
    segment_inductance = total_inductance / segments
    time_constant = segment_inductance / resistance
    detection = Float64(finite["quench_detection_time_s"])
    final_fraction = exp(-(2.0 - detection) / time_constant)
    deposited = magnetic_energy * (1 - exp(-2detection / time_constant))
    temperature_rise = deposited / (volume * 8000.0 * 400.0)
    passed = voltage_limit <= 20000.0 && final_fraction <= 0.01 &&
        temperature_rise <= 100.0
    Dict{String,Any}(
        "scenario_id" => "quench", "status" => passed ? "pass" : "fail",
        "actual_static_peak_field_t" => peak_field,
        "magnetic_energy_proxy_j" => magnetic_energy,
        "total_equivalent_inductance_h" => total_inductance,
        "independent_dump_circuit_count" => segments,
        "per_circuit_equivalent_inductance_h" => segment_inductance,
        "per_circuit_dump_resistance_ohm" => resistance,
        "current_decay_time_constant_s" => time_constant,
        "final_current_fraction_at_2s" => final_fraction,
        "conductor_temperature_rise_proxy_k" => temperature_rise,
        "per_circuit_terminal_voltage_v" => voltage_limit,
        "voltage_limit_per_circuit_v" => 20000.0,
        "maximum_final_current_fraction" => 0.01,
        "maximum_temperature_rise_k" => 100.0,
        "lumped_segmented_protection_only" => true)
end

function execute_corrected_dynamic_fault_provider_v115(assembly_raw, overlay_raw,
        candidate_raw, static_raw)
    assembly = Dict{String,Any}(_v93_plain(assembly_raw))
    overlay = Dict{String,Any}(_v93_plain(overlay_raw))
    candidate = Dict{String,Any}(_v93_plain(candidate_raw))
    static = Dict{String,Any}(_v93_plain(static_raw))
    assembly["physical_design_hash"] == overlay["physical_design_hash"] ||
        throw(ArgumentError("v115 controller overlay assembly binding mismatch"))
    static["candidate_result_hash"] == candidate["result_hash"] ||
        throw(ArgumentError("v115 dynamic/static candidate binding mismatch"))
    controller = Dict{String,Any}(overlay["controller_design"])
    design = Dict{String,Any}(assembly["physical_design"])
    required = Set(String.(design["control_fault"]["required_fault_scenarios"]))
    declared = Set(String.(controller["required_fault_scenarios"]))
    required == declared || throw(ArgumentError(
        "v115 controller fault scenario contract mismatch"))
    results = Dict{String,Any}[
        _v108_control_result("single_pf_coil_trip", controller),
        _v108_control_result("density_limit_excursion", controller),
        _v108_control_result("vertical_displacement_event", controller),
        _v108_coolant_result(design),
        _v115_quench_result(design, static),
    ]
    Set(String(item["scenario_id"]) for item in results) == required ||
        throw(ArgumentError("v115 did not execute exactly the declared fault scenarios"))
    passed = all(item -> item["status"] == "pass", results)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V115_PROTOCOL_ID,
        "physical_design_hash" => assembly["physical_design_hash"],
        "controller_design_hash" => overlay["controller_design_hash"],
        "candidate_result_hash" => candidate["result_hash"],
        "static_result_hash" => static["result_hash"],
        "status" => passed ? "pass" : "fail",
        "candidate_state" => passed ? "corrected_dynamic_fault_screen_survivor" :
            "corrected_dynamic_fault_screen_reject",
        "scenario_count" => length(results),
        "scenario_pass_count" => count(item -> item["status"] == "pass", results),
        "failed_scenarios" => String[item["scenario_id"] for item in results if
            item["status"] == "fail"],
        "scenario_results" => results,
        "whole_device_pass_credit" => false, "validation_credit" => false,
        "unsupported_candidate_classification_used" => false,
        "identity_fields_used_for_routing" => false,
        "evidence_ceiling" =>
            "candidate_bound_reduced_control_lumped_cooling_segmented_quench_screen",
        "claim_boundary" => CORRECTED_WHOLE_DEVICE_RESCREEN_V115_CLAIM_BOUNDARY)
    body["result_hash"] = canonical_hash(body)
    body
end

function actual_static_extrema_v115(static_raw)
    static = Dict{String,Any}(_v93_plain(static_raw))
    static["candidate_state"] == "static_robustness_proxy_pass" ||
        throw(ArgumentError("v115 requires a passing nine-case static artifact"))
    records = Dict{String,Any}.(static["records"])
    length(records) == Int(static["scenario_count"]) || throw(ArgumentError(
        "v115 static record count mismatch"))
    Dict{String,Any}(
        "peak_field_t" => maximum(Float64(record["response"][
            "additive_peak_field_proxy_t"]) for record in records),
        "engineering_current_density_a_m2" => maximum(Float64(record["response"][
            "current_density_proxy_a_m2"]) for record in records),
        "support_stress_pa" => maximum(Float64(record["response"][
            "membrane_support_stress_proxy_pa"]) for record in records),
        "static_result_hash" => static["result_hash"],
        "scenario_count" => length(records))
end

function screen_corrected_whole_device_assembly_v115(assembly_raw, candidate_raw,
        static_raw)
    screen = screen_whole_device_assembly_v106(assembly_raw, candidate_raw)
    extrema = actual_static_extrema_v115(static_raw)
    outputs = Dict{String,Any}(screen["outputs"])
    for key in ("peak_field_t", "engineering_current_density_a_m2",
            "support_stress_pa")
        outputs[key] = extrema[key]
    end
    screen["outputs"] = outputs
    thresholds = Dict(
        "peak_field" => V106_SCREEN_LIMITS["maximum_peak_field_t"],
        "engineering_current_density" =>
            V106_SCREEN_LIMITS["maximum_engineering_current_density_a_m2"],
        "support_stress" => V106_SCREEN_LIMITS["maximum_support_stress_pa"])
    output_keys = Dict(
        "peak_field" => "peak_field_t",
        "engineering_current_density" => "engineering_current_density_a_m2",
        "support_stress" => "support_stress_pa")
    for gate_raw in screen["gates"]
        gate = Dict{String,Any}(gate_raw)
        id = String(gate["gate_id"])
        haskey(output_keys, id) || continue
        value = Float64(outputs[output_keys[id]])
        gate["value"] = value
        gate["threshold"] = thresholds[id]
        gate["status"] = value <= thresholds[id] ? "pass" : "fail"
        merge!(gate_raw, gate)
    end
    passed = all(gate -> gate["status"] == "pass", screen["gates"])
    screen["schema_version"] = "1.0.0"
    screen["protocol_id"] = V115_PROTOCOL_ID
    screen["status"] = passed ? "pass" : "fail"
    screen["candidate_state"] = passed ? "actual_static_assembly_screen_survivor" :
        "actual_static_assembly_screen_reject"
    screen["failed_gates"] = String[gate["gate_id"] for gate in screen["gates"] if
        gate["status"] == "fail"]
    screen["actual_static_extrema"] = extrema
    screen["evidence_ceiling"] = "candidate_bound_reduced_screen_with_actual_static_extrema"
    screen["claim_boundary"] = CORRECTED_WHOLE_DEVICE_RESCREEN_V115_CLAIM_BOUNDARY
    pop!(screen, "result_hash", nothing); screen["result_hash"] = canonical_hash(screen)
    screen
end

function execute_corrected_provider_dag_v115(assembly, screen, candidate, artifacts)
    row = execute_whole_device_provider_dag_v107(assembly, screen, candidate, artifacts)
    for stage_raw in row["stages"]
        stage = Dict{String,Any}(stage_raw)
        if stage["stage_id"] == "assembly_reduced_screen"
            stage["provider_key"] = "actual_static_assembly_screen_v115"
        elseif stage["stage_id"] == "reduced_engineering_and_materials"
            stage["provider_key"] = "actual_static_engineering_screen_v115"
        end
        pop!(stage, "stage_hash", nothing); stage["stage_hash"] = canonical_hash(stage)
        merge!(stage_raw, stage)
    end
    row["protocol_id"] = V115_PROTOCOL_ID
    row["claim_boundary"] = CORRECTED_WHOLE_DEVICE_RESCREEN_V115_CLAIM_BOUNDARY
    pop!(row, "result_hash", nothing); row["result_hash"] = canonical_hash(row)
    row
end

function run_corrected_whole_device_rescreen_v115(project_root::AbstractString)
    root = abspath(project_root)
    reference = run_mission_aware_reference_acceptance_v103(root)
    reference["status"] == "pass" &&
        Int(reference["reference_regression_pass_count"]) == 2 &&
        Int(reference["new_reference_bypass_count"]) == 0 || throw(ArgumentError(
        "v115 requires a no-bypass ITER/C-2W regression pass"))
    catalog = load_material_property_catalog_v109(root)
    audit = audit_material_property_catalog_v109(catalog)
    audit["status"] == "closed_for_rejection_screen" || throw(ArgumentError(
        "v115 source-pinned material catalog preflight failed"))
    frontier = load_v114_provider_frontier_v115(root)
    v114_directory = joinpath(root, "runs",
        "v114_similarity_scaled_field_repair_20260830")
    source_acceptance_hashes = Dict{String,Any}()
    for (stage, relative_path) in (
            ("generation", joinpath("generation_acceptance.json")),
            ("freegs", joinpath("freegs", "acceptance.json")),
            ("desc", joinpath("desc", "acceptance.json")),
            ("static", joinpath("static", "acceptance.json")))
        source_acceptance_hashes[stage] = _v115_read_json(joinpath(
            v114_directory, relative_path))["acceptance_hash"]
    end
    assemblies = Dict{String,Any}[]; screens = Dict{String,Any}[]
    dags = Dict{String,Any}[]; dynamics = Dict{String,Any}[]
    materials = Dict{String,Any}[]
    for item in frontier
        candidate = item["candidate"]; artifacts = item["artifacts"]
        for assembly in generate_corrected_whole_device_assemblies_v115(candidate)
            push!(assemblies, assembly)
            screen = screen_corrected_whole_device_assembly_v115(
                assembly, candidate, artifacts["static"])
            push!(screens, screen)
            screen["status"] == "pass" || continue
            dag = execute_corrected_provider_dag_v115(
                assembly, screen, candidate, artifacts)
            push!(dags, dag)
            dag["available_provider_stage_pass"] === true || continue
            for overlay in generate_controller_overlays_v108(assembly)
                dynamic = execute_corrected_dynamic_fault_provider_v115(
                    assembly, overlay, candidate, artifacts["static"])
                push!(dynamics, dynamic)
                dynamic["status"] == "pass" || continue
                push!(materials, execute_material_engineering_provider_v109(
                    assembly, screen, dynamic, catalog))
            end
        end
    end
    material_survivors = [row for row in materials if row["status"] == "pass"]
    assembly_by_hash = Dict(String(item["physical_design_hash"]) => item
        for item in assemblies)
    surviving_assembly_hashes = unique(String(row["physical_design_hash"])
        for row in material_survivors)
    surviving_candidate_hashes = unique(String(assembly_by_hash[hash][
        "source_candidate_result_hash"]) for hash in surviving_assembly_hashes)
    screen_blockers = Dict{String,Int}(); dynamic_blockers = Dict{String,Int}()
    material_blockers = Dict{String,Int}()
    for row in screens, blocker in String.(row["failed_gates"])
        screen_blockers[blocker] = get(screen_blockers, blocker, 0) + 1
    end
    for row in dynamics, blocker in String.(row["failed_scenarios"])
        dynamic_blockers[blocker] = get(dynamic_blockers, blocker, 0) + 1
    end
    for row in materials, blocker in String.(row["failed_gates"])
        material_blockers[blocker] = get(material_blockers, blocker, 0) + 1
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V115_PROTOCOL_ID,
        "status" => "complete",
        "reference_regression_status" => reference["status"],
        "reference_regression_pass_count" => reference["reference_regression_pass_count"],
        "reference_bypass_count" => reference["new_reference_bypass_count"],
        "source_reference_acceptance_hash" => reference["acceptance_hash"],
        "source_v114_acceptance_hashes" => source_acceptance_hashes,
        "source_v114_candidate_count" => length(frontier),
        "assembly_count" => length(assemblies),
        "actual_static_screen_survivor_count" => count(row -> row["status"] == "pass", screens),
        "available_provider_dag_pass_count" => count(row ->
            row["available_provider_stage_pass"] === true, dags),
        "dynamic_fault_screen_survivor_count" => count(row -> row["status"] == "pass", dynamics),
        "material_screen_survivor_count" => length(material_survivors),
        "unique_material_survivor_assembly_count" => length(surviving_assembly_hashes),
        "unique_material_survivor_candidate_count" => length(surviving_candidate_hashes),
        "material_screen_reject_count" => count(row -> row["status"] == "fail", materials),
        "actual_static_screen_blocker_histogram" => Dict(sort!(collect(screen_blockers))),
        "dynamic_fault_blocker_histogram" => Dict(sort!(collect(dynamic_blockers))),
        "material_blocker_histogram" => Dict(sort!(collect(material_blockers))),
        "unsupported_candidate_count" => 0, "provider_system_failure_count" => 0,
        "whole_device_pass_count" => 0, "whole_device_credible_count" => 0,
        "validation_pass_count" => 0,
        "complete_provider_preflight_count" => count(row ->
            row["whole_device_provider_preflight_status"] == "ready", dags),
        "high_fidelity_pending_count" => count(row ->
            row["candidate_state"] == "high_fidelity_pending", dags),
        "partial_subgraph_promotion_allowed" => false,
        "identity_fields_used_for_routing" => false,
        "basis_direct_metric_credit" => false,
        "material_catalog_hash" => catalog["catalog_hash"],
        "claim_boundary" => CORRECTED_WHOLE_DEVICE_RESCREEN_V115_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body, Dict("assemblies" => assemblies, "screens" => screens, "dags" => dags,
        "dynamics" => dynamics, "materials" => materials)
end
