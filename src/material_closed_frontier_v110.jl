const V110_PROTOCOL_ID = "fusionconceptai-v110-material-closed-frontier-20260829"

const MATERIAL_CLOSED_FRONTIER_V110_CLAIM_BOUNDARY =
    "v110 selects previously unexecuted reduced-physics candidates using only declared " *
    "reactor mission output, radial build, beta_n and conservative material-screen inputs. " *
    "Candidate hashes are used only to avoid duplicate computation, never as provider or " *
    "metric inputs. Selection grants no FreeGS, stability, engineering, validation or " *
    "whole-device credit."

const V110_FRONTIER_LIMITS = Dict{String,Float64}(
    "minimum_reduced_net_electric_power_w" => 300.0e6,
    "minimum_nuclear_radial_build_m" => 1.2,
    "maximum_conservative_peak_field_t" => 16.0,
    "maximum_conservative_current_density_a_m2" => 20.0e6,
    "maximum_conservative_support_stress_pa" => 450.0e6,
)

function material_frontier_inputs_v110(candidate_raw)
    candidate = Dict{String,Any}(_v93_plain(candidate_raw))
    capability = Dict{String,Any}(candidate["capability_profile"])
    physics = Dict{String,Any}(candidate["physics_solve"])
    engineering = Dict{String,Any}(candidate["engineering_prefilter"])
    layout = Dict{String,Any}(candidate["magnet_layout"])
    metrics = Dict{String,Any}(physics["metrics"])
    engineering_metrics = Dict{String,Any}(engineering["metrics"])
    Dict{String,Any}(
        "closed_core_route" => capability["closed_core_route"],
        "physics_status" => physics["status"],
        "engineering_status" => engineering["status"],
        "net_electric_power_w" => metrics["net_electric_power_w"],
        "beta_n" => metrics["beta_n"],
        "nuclear_radial_build_m" => layout["shield_thickness_m"],
        "conservative_peak_field_t" => 1.05Float64(
            engineering_metrics["additive_peak_field_t"]),
        "conservative_current_density_a_m2" => 1.10Float64(
            engineering_metrics["pf_current_density_a_m2"]),
        "conservative_support_stress_pa" => 1.05Float64(
            engineering_metrics["membrane_support_stress_pa"]),
        "identity_fields_used" => false)
end

function material_frontier_eligible_v110(candidate_raw)
    inputs = material_frontier_inputs_v110(candidate_raw)
    inputs["closed_core_route"] == "axisymmetric_closed" &&
        inputs["physics_status"] == "pass" &&
        inputs["engineering_status"] == "pass" &&
        Float64(inputs["net_electric_power_w"]) >=
            V110_FRONTIER_LIMITS["minimum_reduced_net_electric_power_w"] &&
        Float64(inputs["nuclear_radial_build_m"]) >=
            V110_FRONTIER_LIMITS["minimum_nuclear_radial_build_m"] &&
        Float64(inputs["conservative_peak_field_t"]) <=
            V110_FRONTIER_LIMITS["maximum_conservative_peak_field_t"] &&
        Float64(inputs["conservative_current_density_a_m2"]) <=
            V110_FRONTIER_LIMITS["maximum_conservative_current_density_a_m2"] &&
        Float64(inputs["conservative_support_stress_pa"]) <=
            V110_FRONTIER_LIMITS["maximum_conservative_support_stress_pa"]
end

function select_material_closed_frontier_v110(candidates_raw;
        prior_result_hashes = Set{String}(), retain_count::Integer = 40)
    retain_count > 0 || throw(ArgumentError("v110 retain_count must be positive"))
    candidates = Dict{String,Any}.(_v93_plain(candidates_raw))
    eligible = [candidate for candidate in candidates if
        material_frontier_eligible_v110(candidate)]
    novel = [candidate for candidate in eligible if
        !(String(candidate["result_hash"]) in prior_result_hashes)]
    sort!(novel; by = candidate -> begin
        values = material_frontier_inputs_v110(candidate)
        (Float64(values["beta_n"]),
            -Float64(values["net_electric_power_w"]),
            Float64(values["conservative_peak_field_t"]),
            Float64(values["conservative_support_stress_pa"]),
            Float64(values["nuclear_radial_build_m"]))
    end)
    length(novel) > retain_count && resize!(novel, retain_count)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V110_PROTOCOL_ID,
        "input_candidate_count" => length(candidates),
        "material_gate_eligible_count" => length(eligible),
        "previously_executed_eligible_count" => length(eligible) - length([
            item for item in eligible if !(String(item["result_hash"]) in
                prior_result_hashes)]),
        "retained_count" => length(novel),
        "selection_limits" => V110_FRONTIER_LIMITS,
        "selection_order" => ["beta_n_ascending", "net_electric_power_descending",
            "conservative_peak_field_ascending", "conservative_support_stress_ascending",
            "nuclear_radial_build_ascending"],
        "deduplication_hash_used_for_compute_reuse_only" => true,
        "identity_fields_used_for_selection_metrics" => false,
        "unsupported_candidate_count" => 0,
        "physical_pass_credit" => false, "validation_credit" => false,
        "claim_boundary" => MATERIAL_CLOSED_FRONTIER_V110_CLAIM_BOUNDARY)
    body["selection_hash"] = canonical_hash(body)
    body, novel
end

function _v110_read_json(path)
    isfile(path) || throw(ArgumentError("missing v110 artifact: $path"))
    Dict{String,Any}(_v93_plain(JSON3.read(read(path, String))))
end

function _v110_rows_by_index(artifact)
    Dict(Int(row["request_index"]) => Dict{String,Any}(row)
        for row in Dict{String,Any}.(artifact["rows"]))
end

function run_material_closed_frontier_acceptance_v110(project_root::AbstractString)
    root = abspath(project_root)
    directory = joinpath(root, "runs", "v110_material_closed_frontier_20260829")
    selection = _v110_read_json(joinpath(directory, "selection_acceptance.json"))
    freegs = _v110_read_json(joinpath(directory, "freegs", "acceptance.json"))
    desc = _v110_read_json(joinpath(directory, "desc", "acceptance.json"))
    static = _v110_read_json(joinpath(directory, "static", "acceptance.json"))
    reference = run_mission_aware_reference_acceptance_v103(root)
    candidates = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in
        readlines(joinpath(directory, "candidates.jsonl")) if !isempty(strip(line))]
    candidate_by_index = Dict(Int(item["request_index"]) => item for item in candidates)
    freegs_by_index = _v110_rows_by_index(freegs)
    desc_by_index = _v110_rows_by_index(desc)
    static_by_index = _v110_rows_by_index(static)
    Set(keys(candidate_by_index)) == Set(keys(freegs_by_index)) ||
        throw(ArgumentError("v110 FreeGS candidate census mismatch"))
    rows = Dict{String,Any}[]
    blockers = Dict{String,Int}(); histogram = Dict{String,Int}()
    for index in sort!(collect(keys(candidate_by_index)))
        candidate = candidate_by_index[index]
        freegs_row = freegs_by_index[index]
        state = ""; blocker = ""; desc_state = "not_executed";
        static_state = "not_executed"
        if freegs_row["status"] != "pass"
            state = "physical_reject"; blocker = "free_boundary_equilibrium"
        else
            haskey(desc_by_index, index) || throw(ArgumentError(
                "missing v110 DESC result for FreeGS survivor"))
            desc_row = desc_by_index[index]; desc_state = String(desc_row["candidate_state"])
            if desc_state == "cross_code_equilibrium_fail"
                state = "physical_reject"; blocker = "cross_code_equilibrium"
            elseif desc_state == "stability_screen_fail"
                state = "physical_reject"; blocker = "sampled_local_ideal_mhd"
            elseif desc_state == "sampled_ideal_mhd_candidate"
                haskey(static_by_index, index) || throw(ArgumentError(
                    "missing v110 static result for DESC survivor"))
                static_row = static_by_index[index]
                static_state = String(static_row["candidate_state"])
                if static_state == "static_robustness_proxy_pass"
                    state = "high_fidelity_frontier_survivor"
                else
                    state = "physical_reject"; blocker = "static_engineering_proxy"
                end
            else
                throw(ArgumentError("unexpected v110 DESC state: $desc_state"))
            end
        end
        histogram[state] = get(histogram, state, 0) + 1
        isempty(blocker) || (blockers[blocker] = get(blockers, blocker, 0) + 1)
        row = Dict{String,Any}(
            "candidate_result_hash" => candidate["result_hash"],
            "freegs_status" => freegs_row["status"],
            "desc_state" => desc_state, "static_state" => static_state,
            "candidate_state" => state,
            "physical_failure_stage" => isempty(blocker) ? nothing : blocker,
            "unsupported_candidate_classification_used" => false,
            "identity_fields_used_for_routing" => false,
            "whole_device_pass_credit" => false, "validation_credit" => false)
        row["row_hash"] = canonical_hash(row); push!(rows, row)
    end
    provider_failures = sum(Int(get(item, "provider_system_failure_count", 0))
        for item in (freegs, desc, static))
    complete = reference["status"] == "pass" && selection["status"] == "complete" &&
        freegs["status"] == "complete" && desc["status"] == "complete" &&
        static["status"] == "complete" && provider_failures == 0
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V110_PROTOCOL_ID,
        "status" => complete ? "complete" : "provider_system_failure",
        "reference_regression_status" => reference["status"],
        "reference_regression_pass_count" => reference["reference_regression_pass_count"],
        "reference_bypass_count" => reference["new_reference_bypass_count"],
        "candidate_count" => length(rows),
        "freegs_pass_count" => count(row -> row["freegs_status"] == "pass", rows),
        "sampled_ideal_mhd_candidate_count" => count(row -> row["desc_state"] ==
            "sampled_ideal_mhd_candidate", rows),
        "static_robustness_pass_count" => count(row -> row["static_state"] ==
            "static_robustness_proxy_pass", rows),
        "high_fidelity_frontier_survivor_count" => count(row -> row["candidate_state"] ==
            "high_fidelity_frontier_survivor", rows),
        "candidate_state_histogram" => Dict(sort!(collect(histogram))),
        "blocker_histogram" => Dict(sort!(collect(blockers))),
        "source_acceptance_hashes" => Dict(
            "selection" => selection["acceptance_hash"],
            "freegs" => freegs["acceptance_hash"],
            "desc" => desc["acceptance_hash"], "static" => static["acceptance_hash"]),
        "unsupported_candidate_count" => 0,
        "provider_system_failure_count" => provider_failures,
        "whole_device_pass_count" => 0, "whole_device_credible_count" => 0,
        "validation_pass_count" => 0, "high_cost_expansion_authorized" => false,
        "identity_fields_used_for_routing" => false,
        "rows" => rows, "claim_boundary" => MATERIAL_CLOSED_FRONTIER_V110_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body
end
