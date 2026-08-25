const _V47_CLAIM_BOUNDARY =
    "V47 is a fail-closed known-device benchmark-readiness audit across RFP, " *
    "levitated-dipole, and stellarator routes. It keeps calibration sources " *
    "disjoint from held-out sources, never converts a protocol tolerance into a " *
    "measurement error bar, and reports missing model outputs explicitly. The two " *
    "RFP routes support a numerical comparison but do not reproduce the measured " *
    "MST operating point and fail the preregistered factor-two protocol. The dipole " *
    "and stellarator routes lack the measured bulk or exhaust outputs. No known-device " *
    "result grants candidate-specific validation, medium-fidelity authorization, " *
    "promotion credit, C1, scale-up, engineering closure, or net-electric credibility."

function _v47_lookup(items::AbstractVector, key::String, value::String)
    matches = filter(item -> String(item[key]) == value, items)
    length(matches) == 1 || throw(ArgumentError(
        "v47 expected exactly one $key=$value record, found $(length(matches))"))
    return only(matches)
end

function _v47_string_vector(item::AbstractDict, key::String)
    sort!(String.(collect(item[key])))
end

function _v47_source_disjoint(benchmark::AbstractDict)
    calibration = Set(_v47_string_vector(benchmark, "calibration_source_ids"))
    heldout = Set(_v47_string_vector(benchmark, "heldout_source_ids"))
    return isempty(intersect(calibration, heldout))
end

function _v47_common_route_record(route_id::String, benchmark::AbstractDict;
        available_outputs::Vector{String}, missing_outputs::Vector{String},
        status::String, benchmark_executable::Bool,
        numeric_protocol_passed::Bool,
        model_operating_point_matched::Bool,
        model_prediction = nothing, comparison = nothing)
    record = Dict{String,Any}(
        "route_id" => route_id,
        "family" => String(benchmark["family"]),
        "benchmark_id" => String(benchmark["benchmark_id"]),
        "heldout_source_ids" => _v47_string_vector(
            benchmark, "heldout_source_ids"),
        "calibration_source_ids" => _v47_string_vector(
            benchmark, "calibration_source_ids"),
        "calibration_source_disjoint_from_heldout" =>
            _v47_source_disjoint(benchmark),
        "measurement" => deepcopy(benchmark["measurement"]),
        "comparison_protocol" => deepcopy(benchmark["comparison_protocol"]),
        "available_model_output_ids" => sort!(available_outputs),
        "missing_required_model_output_ids" => sort!(missing_outputs),
        "benchmark_status" => status,
        "benchmark_executable" => benchmark_executable,
        "numeric_protocol_passed" => numeric_protocol_passed,
        "model_operating_point_matched" => model_operating_point_matched,
        "independent_known_device_magnitude_validation" => false,
        "candidate_specific_independently_validated" => false,
        "medium_fidelity_authorized" => false,
        "promotion_credit" => 0,
    )
    model_prediction === nothing ||
        (record["model_prediction"] = model_prediction)
    comparison === nothing || (record["comparison"] = comparison)
    return record
end

function _v47_rfp_record(route_id::String, trial::AbstractDict,
        benchmark::AbstractDict)
    quantity_id = String(benchmark["measurement"]["quantity_id"])
    measured = Float64(benchmark["measurement"]["reported_value"])
    predicted = Float64(trial["high_state"][quantity_id])
    factor_error = max(predicted / measured, measured / predicted)
    maximum_factor = Float64(
        benchmark["comparison_protocol"]["maximum_factor_error"])
    passed = factor_error <= maximum_factor
    return _v47_common_route_record(route_id, benchmark;
        available_outputs = String.(collect(keys(trial["high_state"]))),
        missing_outputs = String[],
        status = passed ?
            "numeric_protocol_pass_but_operating_point_unmatched" :
            "numeric_protocol_fail_and_operating_point_unmatched",
        benchmark_executable = true,
        numeric_protocol_passed = passed,
        model_operating_point_matched = false,
        model_prediction = Dict{String,Any}(
            "quantity_id" => quantity_id,
            "value" => predicted,
            "unit" => String(benchmark["measurement"]["unit"]),
            "source_trial_id" => String(trial["trial_id"]),
            "source_state" => "high_state",
            "fixed_background_coordinate" => 0.5,
            "operating_point_note" => "The v44 midpoint candidate is not a reconstruction of the Craig 2000 MST discharge."),
        comparison = Dict{String,Any}(
            "measured_value" => measured,
            "predicted_to_measured_ratio" => predicted / measured,
            "factor_error" => factor_error,
            "maximum_factor_error" => maximum_factor,
            "numeric_protocol_passed" => passed))
end

function _v47_dipole_record(route_id::String, endpoint::AbstractDict,
        benchmark::AbstractDict)
    required = sort!(String[String(item["quantity_id"])
        for item in benchmark["measurement"]["quantities"]])
    available = sort!(String.(collect(keys(
        endpoint["nominal_direction_metrics"]))))
    missing = sort!(setdiff(required, available))
    return _v47_common_route_record(route_id, benchmark;
        available_outputs = available,
        missing_outputs = missing,
        status = "model_output_missing",
        benchmark_executable = false,
        numeric_protocol_passed = false,
        model_operating_point_matched = false,
        model_prediction = Dict{String,Any}(
            "source_endpoint_id" => String(endpoint["endpoint_id"]),
            "support_mode" => String(endpoint["support_mode"]),
            "paired_ratio_outputs_present" => isempty(missing),
            "operating_point_note" => "The v45 midpoint endpoints are structurally paired but are not reconstructions of the IAEA 2008 LDX shots."))
end

function _v47_stellarator_record(route::AbstractDict,
        benchmark::AbstractDict)
    required = sort!(String[String(item["quantity_id"])
        for item in benchmark["measurement"]["quantities"]])
    return _v47_common_route_record("stellarator_boundary_control", benchmark;
        available_outputs = String[],
        missing_outputs = required,
        status = "model_output_missing",
        benchmark_executable = false,
        numeric_protocol_passed = false,
        model_operating_point_matched = false,
        model_prediction = Dict{String,Any}(
            "family_solver_baseline_available" =>
                route["family_solver_baseline_available"],
            "route_anchor_class" => String(route["route_anchor_class"]),
            "output_note" => "The current route has equilibrium and direction metadata but no radiated-power, divertor-load, or particle-flux response outputs."))
end

function cross_family_heldout_quantitative_benchmark_v47(
        v44_trials::AbstractVector, v45_endpoints::AbstractVector,
        v43_routes::AbstractVector, evidence::AbstractDict)
    String(evidence["catalog_version"]) ==
        "cross_family_heldout_quantitative_v47_1.0.0" ||
        throw(ArgumentError("v47 evidence overlay version mismatch"))
    contract = evidence["evidence_contract"]
    all(value === false for value in values(contract)) ||
        throw(ArgumentError("v47 evidence contract must fail closed"))

    benchmarks = evidence["benchmarks"]
    rfp = _v47_lookup(benchmarks, "benchmark_id",
        "mst_ppcd_absolute_tau_e_v47")
    ldx = _v47_lookup(benchmarks, "benchmark_id",
        "ldx_supported_levitated_bulk_response_v47")
    w7x = _v47_lookup(benchmarks, "benchmark_id",
        "w7x_island_divertor_detachment_v47")

    records = Dict{String,Any}[]
    push!(records, _v47_rfp_record("rfp_ppcd",
        _v47_lookup(v44_trials, "trial_id",
            "rfp_ppcd_v7_calibration_replay"), rfp))
    push!(records, _v47_rfp_record("rfp_ppcd_profile",
        _v47_lookup(v44_trials, "trial_id",
            "rfp_ppcd_profile_v8_calibration_replay"), rfp))
    push!(records, _v47_dipole_record("dipole_supported",
        _v47_lookup(v45_endpoints, "endpoint_id", "v45_dipole_supported"),
        ldx))
    push!(records, _v47_dipole_record("dipole_levitated",
        _v47_lookup(v45_endpoints, "endpoint_id", "v45_dipole_levitated"),
        ldx))
    push!(records, _v47_stellarator_record(
        _v47_lookup(v43_routes, "module_id", "stellarator_boundary_control"),
        w7x))

    route_ids = sort!(String.(getindex.(records, "route_id")))
    families = sort!(unique(String.(getindex.(records, "family"))))
    missing_outputs = sort!(unique(String[String(output_id)
        for record in records
        for output_id in record["missing_required_model_output_ids"]]))
    all(_v47_source_disjoint, benchmarks) ||
        throw(ArgumentError("v47 calibration and held-out sources overlap"))

    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "search_version" => "cross_family_heldout_quantitative_benchmark_v47",
        "stage" => "sealed_cross_family_heldout_benchmark_readiness_audit",
        "benchmark_contract" => Dict{String,Any}(
            "heldout_sources_disjoint_from_calibration" => true,
            "measurement_uncertainty_separate_from_protocol_tolerance" => true,
            "missing_output_fails_closed" => true,
            "operating_point_match_required_for_known_device_validation" => true,
            "known_device_result_can_promote_candidate" => false,
        ),
        "aggregate" => Dict{String,Any}(
            "route_record_count" => length(records),
            "route_ids" => route_ids,
            "family_count" => length(families),
            "families" => families,
            "heldout_primary_source_count" => length(
                evidence["primary_sources"]),
            "calibration_heldout_disjoint_route_count" => count(record ->
                record["calibration_source_disjoint_from_heldout"] === true,
                records),
            "numeric_comparator_executable_route_count" => count(record ->
                record["benchmark_executable"] === true, records),
            "numeric_protocol_pass_route_count" => count(record ->
                record["numeric_protocol_passed"] === true, records),
            "numeric_protocol_fail_route_count" => count(record ->
                record["benchmark_executable"] === true &&
                record["numeric_protocol_passed"] === false, records),
            "model_output_missing_route_count" => count(record ->
                record["benchmark_status"] == "model_output_missing", records),
            "missing_required_output_class_count" => length(missing_outputs),
            "missing_required_output_ids" => missing_outputs,
            "operating_point_matched_route_count" => count(record ->
                record["model_operating_point_matched"] === true, records),
            "independent_known_device_magnitude_validation_route_count" => 0,
            "candidate_specific_independently_validated_route_count" => 0,
            "v43_observable_route_count" => 23,
            "candidate_specific_validation_fraction_of_v43_routes" => 0.0,
            "medium_fidelity_authorized_count" => 0,
            "promotion_count" => 0,
            "old_domain_scale_up_authorized" => false,
        ),
        "route_records" => records,
        "next_actions" => [
            "reconstruct the Craig 2000 MST operating point and replace midpoint inputs before interpreting absolute tau_E error as model validation",
            "add density and stored-energy outputs to the supported/levitated dipole paired evaluator",
            "add radiated-power, divertor-load, and particle-flux outputs to the stellarator boundary/exhaust route",
            "repeat the same held-out protocol on additional mirror, tokamak, and compact-toroid routes without changing gate thresholds",
        ],
        "promotion_credit" => Dict{String,Any}(
            "physics_evidence_level_change" => 0,
            "engineering_evidence_level_change" => 0,
            "medium_fidelity_authorized_count" => 0,
            "promotion_count" => 0,
        ),
        "claim_boundary" => _V47_CLAIM_BOUNDARY,
    )
end
