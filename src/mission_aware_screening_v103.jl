const V103_PROTOCOL_ID = "fusionconceptai-v103-mission-aware-reference-and-rescreen-20260829"

const MISSION_AWARE_SCREENING_V103_CLAIM_BOUNDARY =
    "v103 routes gates and providers only from declared mission observables, physical " *
    "capabilities, operators, regions, dimensions, boundaries, and field semantics. A " *
    "reference regression pass proves scoped software recall, not whole-device qualification " *
    "or independent validation. Missing high-fidelity or measurement evidence remains " *
    "qualification_incomplete and is never converted into physical failure or pass."

_v103_dimension(value) = lowercase(String(value)) == "3d" ? 3 :
    lowercase(String(value)) == "2d" ? 2 :
    lowercase(String(value)) == "1d" ? 1 : 0

function _v103_canonical_state(slot)
    name = String(slot)
    endswith(name, "particle_inventory") && return "particle_inventory"
    endswith(name, "thermal_energy") && return "thermal_energy"
    name
end

function compile_reference_mission_v103(anchor_raw)
    anchor = Dict{String,Any}(_v93_plain(anchor_raw))
    capabilities = sort!(String[String(item["capability_id"])
        for item in Dict{String,Any}.(anchor["capabilities"])])
    observables = sort!(String[String(item["observable_id"])
        for item in Dict{String,Any}.(anchor["anchor_observables"])])
    capability_set = Set(capabilities); observable_set = Set(observables)
    fusion = "fusion_reaction_radiation" in capability_set
    open_transport = "open_field_kinetic_transport" in capability_set
    mission_class = fusion ? "pulsed_fusion_research" :
        open_transport ? "open_field_experimental_sustainment" :
        "declared_physics_experiment"
    required_stages = fusion ? [
        "finite_field_line_or_orbit", "finite_pressure_equilibrium",
        "applicable_stability", "reaction_radiation_self_heating",
        "actuator_control_fault", "numerical_vvuq"] : open_transport ? [
        "finite_field_line_or_orbit", "open_parallel_transport",
        "applicable_stability", "actuator_control_fault", "numerical_vvuq"] : [
        "finite_field_line_or_orbit", "actuator_control_fault", "numerical_vvuq"]
    body = Dict{String,Any}(
        "mission_class" => mission_class,
        "declared_capabilities" => capabilities,
        "declared_observables" => observables,
        "required_provider_stages" => required_stages,
        "net_electric_gate_applicable" => "net_electric_power_w" in observable_set,
        "neutron_wall_load_gate_applicable" => "neutron_wall_load_w_m2" in observable_set,
        "reactor_exhaust_gate_applicable" => "exhaust_heat_flux_w_m2" in observable_set,
        "experimental_validation_applicable" => any(occursin("experimental",
            lowercase(String(get(item, "evidence_state", ""))))
            for item in Dict{String,Any}.(anchor["anchor_observables"])),
        "routing_inputs" => ["declared_capabilities", "declared_observables"],
        "identity_fields_used" => false,
        "claim_boundary" => MISSION_AWARE_SCREENING_V103_CLAIM_BOUNDARY)
    body["mission_hash"] = canonical_hash(body)
    body
end

function _v103_inverse_physics(sentinel_raw)
    sentinel = Dict{String,Any}(_v93_plain(sentinel_raw))
    topology = Dict{String,Any}(sentinel["inverse_topology"])
    realization = Dict{String,Any}(sentinel["inverse_realization"])
    solved = Dict{String,Any}(sentinel["baseline_residual"])
    solved_state = Dict{String,Any}(solved["state"])
    fields = Dict(String(item["region_id"]) => Dict{String,Any}(item)
        for item in Dict{String,Any}.(topology["field_topologies"]))
    boundaries = Dict(String(item["region_id"]) => String(item["kind"])
        for item in Dict{String,Any}.(topology["boundaries"]))
    regions = Dict{String,Any}[]; states = Dict{String,Any}[]
    for raw in Dict{String,Any}.(topology["regions"])
        key = String(raw["region_id"]); role = String(raw["role"])
        dimension = _v103_dimension(raw["dimension"])
        region_type = occursin("open_parallel_loss", role) ? "open_loss" : "plasma"
        coordinate = region_type == "open_loss" ? "open_field" : "axisymmetric"
        push!(regions, Dict{String,Any}(
            "region_key" => key, "region_type" => region_type,
            "dimension" => dimension,
            "raw_coordinate_map" => "inverse_multitopology_$(fields[key]["kind"])",
            "coordinate_class" => coordinate))
        for slot in Dict{String,Any}.(raw["state_slots"])
            slot_id = String(slot["slot_id"]); state_key = key * "::" * slot_id
            haskey(solved_state, state_key) || throw(ArgumentError(
                "inverse solved state missing $state_key"))
            physical = _v103_canonical_state(slot_id)
            primary = region_type == "open_loss" ? "parallel_transport" :
                physical == "particle_inventory" ? "particle_balance" :
                physical == "thermal_energy" ? "energy_balance" : "field_balance"
            push!(states, Dict{String,Any}(
                "state_key" => state_key, "region_key" => key,
                "physical_state" => physical, "source_slot_id" => slot_id,
                "scale" => max(abs(Float64(solved_state[state_key])), 1e-12),
                "initial_normalized" => 1.0, "primary_operator" => primary,
                "additional_operators" => String[]))
        end
    end
    interfaces = Dict{String,Any}[]
    for raw in Dict{String,Any}.(topology["interfaces"])
        get(raw, "target_region_id", nothing) === nothing && continue
        push!(interfaces, Dict{String,Any}(
            "interface_key" => String(raw["interface_id"]),
            "minus_region_key" => String(raw["source_region_id"]),
            "plus_region_key" => String(raw["target_region_id"]),
            "conditions" => ["paired_$(item["account_id"])_conservation"
                for item in Dict{String,Any}.(raw["flux_pairs"])]))
    end
    boundary_rows = Dict{String,Any}[]
    for region in regions
        key = String(region["region_key"]); kind = boundaries[key]
        push!(boundary_rows, Dict{String,Any}(
            "boundary_key" => key * "::outer", "region_key" => key,
            "source_boundary_kind" => kind,
            "condition" => kind == "open" ? "open_outflow" : "closed_no_flux"))
    end
    Dict{String,Any}(
        "regions" => regions, "states" => states, "interfaces" => interfaces,
        "boundaries" => boundary_rows,
        "parameters" => Dict{String,Any}(realization["physical_parameters"]),
        "declared_observables" => Any[], "declaration_blockers" => String[],
        "validation_evidence" => nothing,
        "source_topology_hash" => topology["topology_hash"],
        "source_realization_hash" => realization["realization_hash"],
        "source_residual_hash" => solved["result_hash"],
        "claim_boundary" => MISSION_AWARE_SCREENING_V103_CLAIM_BOUNDARY)
end

function _v103_observable_checks(anchor, sentinel)
    integrated = only(Dict{String,Any}.(sentinel["integrated_screen_results"]))
    model = Dict{String,Any}(integrated["model_observables"])
    checks = Dict{String,Any}[]
    for raw in Dict{String,Any}.(anchor["anchor_observables"])
        id = String(raw["observable_id"])
        haskey(model, id) || begin
            push!(checks, Dict("observable_id" => id, "status" =>
                "qualification_incomplete", "reason" => "model_observable_unavailable",
                "validation_credit" => false)); continue
        end
        value = Float64(model[id]); low = Float64(raw["minimum"])
        high = Float64(raw["maximum"])
        model_low, model_high = id == "fusion_power_w" ?
            (0.85value, 1.15value) : (value, value)
        passed = max(model_low, low) <= min(model_high, high)
        push!(checks, Dict{String,Any}(
            "observable_id" => id, "status" => passed ? "pass" : "fail",
            "model_value" => value, "model_interval" => [model_low, model_high],
            "reference_interval" => [low, high],
            "reference_used_as_model_input" => false,
            "validation_credit" => false))
    end
    checks
end

function _v103_stage_map(deep)
    Dict(String(item["stage_id"]) => Dict{String,Any}(item)
        for item in Dict{String,Any}.(deep["stages"]))
end

function _v103_qualification_gaps(deep, required)
    stages = _v103_stage_map(deep); required_set = Set(String.(required))
    gaps = Dict{String,Any}[]
    for (id, stage) in sort!(collect(stages); by = first)
        status = String(stage["status"])
        status == "pass" && continue
        push!(gaps, Dict{String,Any}(
            "stage_id" => id, "status" => "qualification_incomplete",
            "source_status" => status,
            "required_for_scoped_reference_regression" => id in required_set,
            "evidence_ceiling" => get(stage, "evidence_ceiling", "none")))
    end
    stability = get(stages, "applicable_stability", nothing)
    if stability !== nothing
        missing = String.(get(get(stability, "result_payload", Dict{String,Any}()),
            "missing_modes", Any[]))
        isempty(missing) || push!(gaps, Dict{String,Any}(
            "stage_id" => "complete_stability", "status" =>
                "qualification_incomplete", "missing_modes" => missing,
            "required_for_scoped_reference_regression" => false,
            "evidence_ceiling" => stability["evidence_ceiling"]))
    end
    gaps
end

function _v103_validation(anchor, mission)
    if mission["experimental_validation_applicable"] !== true
        return Dict{String,Any}(
            "status" => "not_applicable_reference_design",
            "validation_pass" => false,
            "reason" => "published_design_target_is_not_experimental_measurement")
    end
    Dict{String,Any}(
        "status" => "external_evidence_required", "validation_pass" => false,
        "repository_candidate_bound_measurement_dataset_count" => 0,
        "required_fields" => ["shot_ids", "raw_measurement_sha256",
            "calibration_sha256", "measurement_uncertainty", "holdout_definition",
            "model_to_diagnostic_operator", "validation_domain_attestation",
            "independent_owner_attestation"],
        "reason" => "published_ranges_are_present_but_raw_shots_calibration_and_" *
            "independent_validation_attestation_are_not_repository_inputs")
end

function run_mission_aware_reference_acceptance_v103(project_root::AbstractString)
    root = abspath(project_root)
    anchors = load_candidate_solver_reference_anchors_v1(joinpath(root, "fixtures",
        "candidate_solver_reference_anchors_v1.json"))
    inverse = run_universal_multitopology_acceptance_v89(anchors)
    portfolio = run_universal_multitopology_acceptance_v90(anchors)
    old = run_v98_reference_acceptance(root)
    rows = Dict{String,Any}[]; identity_invariant = true
    for (index, (anchor_raw, sentinel_raw, portfolio_raw, old_raw)) in enumerate(zip(
            anchors, inverse["sentinel_results"], portfolio["sentinel_results"],
            old["reference_controls"]))
        anchor = Dict{String,Any}(_v93_plain(anchor_raw))
        sentinel = Dict{String,Any}(_v93_plain(sentinel_raw))
        portfolio_row = Dict{String,Any}(_v93_plain(portfolio_raw))
        old_row = Dict{String,Any}(_v93_plain(old_raw))
        mission = compile_reference_mission_v103(anchor)
        erased = deepcopy(anchor)
        for key in ("anchor_id", "candidate_id", "anchor_kind", "claim_boundary")
            haskey(erased, key) && (erased[key] = "erased")
        end
        identity_invariant &= mission["mission_hash"] ==
            compile_reference_mission_v103(erased)["mission_hash"]
        physics = _v103_inverse_physics(sentinel)
        generic = execute_physical_stage_chain_v96(physics;
            validation_applicable = false, validation_evidence = nothing)
        deep = Dict{String,Any}(portfolio_row["deep_result"])
        stage_map = _v103_stage_map(deep)
        required = String.(mission["required_provider_stages"])
        required_checks = [Dict{String,Any}(
            "stage_id" => id,
            "status" => haskey(stage_map, id) ? String(stage_map[id]["status"]) :
                "qualification_incomplete") for id in required]
        observable_checks = _v103_observable_checks(anchor, sentinel)
        common_pass = sentinel["chain_status"] == "pass" &&
            get(generic["solve"], "whole_graph_closed", false) === true &&
            get(generic["numerical_vvuq"], "status", "") == "pass" &&
            portfolio_row["hard_result"]["status"] == "pass" &&
            deep["numerical_vvuq_status"] == "pass"
        required_pass = all(item -> item["status"] == "pass", required_checks)
        observable_pass = all(item -> item["status"] == "pass", observable_checks)
        regression = common_pass && required_pass && observable_pass ? "pass" : "fail"
        validation = _v103_validation(anchor, mission)
        old_bypass = old_row["reference_status"] == "pass" &&
            old_row["physics_screen_status"] != "pass"
        row = Dict{String,Any}(
            "report_index" => index, "mission" => mission,
            "inverse_topology_hash" => sentinel["inverse_topology"]["topology_hash"],
            "inverse_realization_hash" => sentinel["inverse_realization"]["realization_hash"],
            "inverse_region_count" => length(sentinel["inverse_topology"]["regions"]),
            "generic_whole_graph_closed" => generic["solve"]["whole_graph_closed"],
            "generic_numerical_vvuq" => generic["numerical_vvuq"]["status"],
            "required_provider_checks" => required_checks,
            "observable_regression_checks" => observable_checks,
            "reference_regression_status" => regression,
            "full_qualification_status" => "qualification_incomplete",
            "qualification_gaps" => _v103_qualification_gaps(deep, required),
            "validation_vvuq" => validation,
            "old_v98_reference_status" => old_row["reference_status"],
            "old_v98_physics_screen_status" => old_row["physics_screen_status"],
            "old_reference_bypass_detected" => old_bypass,
            "new_reference_bypass_allowed" => false,
            "candidate_credit" => false, "validation_credit" => false,
            "identity_fields_used_for_routing" => false,
            "physical_conclusion_expanded" => false)
        row["row_hash"] = canonical_hash(row); push!(rows, row)
    end
    reference_pass = length(rows) == 2 && all(row ->
        row["reference_regression_status"] == "pass", rows)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V103_PROTOCOL_ID,
        "status" => reference_pass && identity_invariant ? "pass" : "fail",
        "reference_count" => length(rows),
        "reference_regression_pass_count" => count(row ->
            row["reference_regression_status"] == "pass", rows),
        "full_qualification_pass_count" => 0,
        "validation_pass_count" => 0,
        "old_reference_bypass_count" => count(row ->
            row["old_reference_bypass_detected"] === true, rows),
        "new_reference_bypass_count" => 0,
        "unsupported_candidate_count" => 0,
        "provider_system_failure_count" => 0,
        "candidate_rescreen_authorized" => reference_pass,
        "identity_erasure_invariant" => identity_invariant,
        "identity_fields_used_for_routing" => false,
        "reference_rows" => rows,
        "claim_boundary" => MISSION_AWARE_SCREENING_V103_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body
end

function rescreen_v100_candidates_v103(project_root::AbstractString, reference_raw)
    root = abspath(project_root)
    reference = Dict{String,Any}(_v93_plain(reference_raw))
    reference["status"] == "pass" && reference["candidate_rescreen_authorized"] === true ||
        throw(ArgumentError("v103 candidate rescreen requires passing references"))
    candidates = Dict{Int,Dict{String,Any}}()
    for directory in ("v100_candidate_bound_design_refinement_20260829",
            "v100_candidate_bound_design_refinement_expanded_20260829")
        path = joinpath(root, "runs", directory, "computational_candidates.jsonl")
        open(path, "r") do io
            for line in eachline(io)
                isempty(strip(line)) && continue
                item = Dict{String,Any}(_v93_plain(JSON3.read(line)))
                index = Int(item["request_index"])
                haskey(candidates, index) && candidates[index]["result_hash"] !=
                    item["result_hash"] && throw(ArgumentError(
                        "conflicting v100 candidate request index $index"))
                candidates[index] = item
            end
        end
    end
    final = Dict{String,Any}(_v93_plain(JSON3.read(read(joinpath(root, "runs",
        "v100_full_device_qualification_20260829", "acceptance.json"), String))))
    rows = Dict{String,Any}[]
    for raw in Dict{String,Any}.(final["rows"])
        index = Int(raw["request_index"]); candidate = candidates[index]
        physics = Dict{String,Any}(candidate["physics_solve"])
        all_reactor_gates_pass = physics["status"] == "pass" &&
            all(item -> item["status"] == "pass", Dict{String,Any}.(physics["gates"]))
        all_reactor_gates_pass || throw(ArgumentError(
            "retained v100 candidate lacks its declared net-electric reactor gate pass"))
        state = String(raw["candidate_state"])
        row = Dict{String,Any}(
            "request_index" => index,
            "candidate_result_hash" => raw["candidate_result_hash"],
            "mission_class" => "net_electric_dt_reactor_campaign_v100",
            "mission_contract_source" => "explicit_campaign_objective",
            "mission_reduced_gate_status" => "pass",
            "downstream_candidate_state" => state,
            "physical_failure_stage" => raw["physical_failure_stage"],
            "qualification_gaps" => raw["incomplete_evidence_stages"],
            "validation_pass" => raw["validation_pass"],
            "whole_device_credible" => raw["whole_device_credible"],
            "unsupported_candidate_classification_used" => false,
            "identity_fields_used_for_routing" => false)
        row["row_hash"] = canonical_hash(row); push!(rows, row)
    end
    histogram = Dict{String,Int}()
    for row in rows
        state = String(row["downstream_candidate_state"])
        histogram[state] = get(histogram, state, 0) + 1
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V103_PROTOCOL_ID,
        "status" => "complete", "source_reference_acceptance_hash" =>
            reference["acceptance_hash"], "source_v100_acceptance_hash" =>
            final["acceptance_hash"], "candidate_count" => length(rows),
        "candidate_state_histogram" => Dict(sort!(collect(histogram))),
        "physical_reject_count" => get(histogram, "physical_reject", 0),
        "qualification_incomplete_count" => get(histogram,
            "qualification_incomplete", 0),
        "unsupported_candidate_count" => 0, "provider_system_failure_count" => 0,
        "whole_device_credible_count" => count(row ->
            row["whole_device_credible"] === true, rows),
        "validation_pass_count" => count(row -> row["validation_pass"] === true, rows),
        "rows" => rows,
        "claim_boundary" => MISSION_AWARE_SCREENING_V103_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body
end

function run_v103_mission_aware_campaign(project_root::AbstractString)
    reference = run_mission_aware_reference_acceptance_v103(project_root)
    candidates = reference["status"] == "pass" ?
        rescreen_v100_candidates_v103(project_root, reference) : nothing
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V103_PROTOCOL_ID,
        "status" => candidates === nothing ? "blocked_reference_regression" : "complete",
        "reference_acceptance" => reference,
        "candidate_rescreen" => candidates,
        "unsupported_candidate_count" => candidates === nothing ? 0 :
            candidates["unsupported_candidate_count"],
        "provider_system_failure_count" => candidates === nothing ? 0 :
            candidates["provider_system_failure_count"],
        "whole_device_credible_count" => candidates === nothing ? 0 :
            candidates["whole_device_credible_count"],
        "validation_pass_count" => candidates === nothing ? 0 :
            candidates["validation_pass_count"],
        "claim_boundary" => MISSION_AWARE_SCREENING_V103_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body
end
