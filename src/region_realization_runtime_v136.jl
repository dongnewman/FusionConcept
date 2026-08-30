const V136_PROTOCOL_ID = "fusionconceptai-v136-region-realization-runtime-20260830"
const V136_CAPABILITY_CLASSES = (
    "axisymmetric_closed", "three_dimensional_closed", "open_field",
    "mixed_multiregion")
const REGION_REALIZATION_RUNTIME_V136_CLAIM_BOUNDARY =
    "v136 routes every declared region independently by state, operator, interface, " *
    "function space, dimension and coordinate capability. Resource quotas and proxy " *
    "scores grant no physical credit. Whole-device execution requires every region " *
    "solve and every declared interface residual/Jacobian coupling to close."

const V136_FORBIDDEN_PROVIDER_INPUT_KEYS = Set([
    "candidate_id", "candidate_hash", "request_index", "device_family",
    "family", "label", "design_id"])
const V136_FORBIDDEN_PHYSICAL_PROXY_KEYS = Set([
    "field_quality", "field_quality_parameter", "field_quality_penalty",
    "fixed_3d_peak_field_penalty", "fixed_three_dimensional_peak_field_penalty"])

function _v136_execution_request(requirement::CapabilityRequirementV94)
    Dict{String,Any}(
        "status" => "execution_request_compiled",
        "requirement_key" => requirement.requirement_key,
        "states" => requirement.states,
        "operator" => requirement.operator,
        "interface" => requirement.interface,
        "function_spaces" => requirement.function_spaces,
        "dimension" => requirement.dimension,
        "coordinate" => requirement.coordinate,
        "required_output" => requirement.required_output,
        "identity_fields_used" => false,
        "physical_credit" => false)
end

function default_region_realization_registry_v136()
    registry = OperatorProviderRegistryV94()
    register_provider_v94!(registry, ProviderCapabilityV94(
        "freegs_grad_shafranov_region_v136", "available",
        ["poloidal_flux", "pressure_profile", "magnetic_field"],
        ["grad_shafranov_equilibrium"], ["magnetic_flux_trace"],
        ["H1_axisymmetric", "L2_axisymmetric"], [2, 3],
        ["radial_axisymmetric"], ["candidate_bound_equilibrium_and_stability"],
        "v136.0"), _v136_execution_request)
    register_provider_v94!(registry, ProviderCapabilityV94(
        "desc_vmex_fourier_coil_region_v136", "available",
        ["fourier_boundary", "three_dimensional_coils", "pressure_profile",
            "magnetic_field"], ["three_dimensional_mhd_equilibrium"],
        ["magnetic_flux_trace"], ["Fourier_Zernike", "filament_curve"], [3],
        ["periodic_fourier"], ["candidate_bound_equilibrium_and_stability"],
        "v136.0"), _v136_execution_request)
    register_provider_v94!(registry, ProviderCapabilityV94(
        "open_field_line_end_loss_balance_region_v136", "available",
        ["magnetic_field", "particle_inventory", "thermal_energy",
            "endpoint_flux"], ["open_field_equilibrium_end_loss"],
        ["particle_energy_flux_trace"], ["field_line", "finite_volume_1d"],
        [1, 2, 3], ["open_field_line"],
        ["candidate_bound_equilibrium_and_stability"], "v136.0"),
        _v136_execution_request)
    register_provider_v94!(registry, ProviderCapabilityV94(
        "interface_residual_jacobian_coupler_v136", "available",
        ["conserved_interface_fluxes"], String[],
        ["coupled_flux_force_energy_continuity"], ["mortar_dual"], [1, 2, 3],
        ["multiregion_interface"], ["coupled_interface_residual_jacobian"],
        "v136.0"), _v136_execution_request)
    registry
end

function _v136_region_class(region)
    semantics = String(get(region, "field_semantics",
        get(region, "raw_coordinate_map", get(region, "coordinate", ""))))
    boundary = String(get(region, "boundary",
        get(region, "boundary_condition", "")))
    semantics == "axisymmetric_closed" && return "axisymmetric_closed"
    semantics == "three_dimensional_closed" && return "three_dimensional_closed"
    (semantics == "open_guiding_field" || semantics == "open_field" ||
        boundary in ("open", "open_outflow", "absorbing", "absorbing_terminal")) &&
        return "open_field"
    semantics == "hybrid_field" && return "explicit_subregions_required"
    "unsupported"
end

function _v136_dimension(value, fallback)
    value isa Integer && return Int(value)
    text = lowercase(strip(String(value)))
    match_result = match(r"[123]", text)
    match_result === nothing ? fallback : parse(Int, match_result.match)
end

function _v136_requirement(region, region_class)
    key = String(get(region, "region_key", get(region, "node_id", "region")))
    if region_class == "axisymmetric_closed"
        return CapabilityRequirementV94(key * "::realization", "operator",
            ["poloidal_flux", "pressure_profile", "magnetic_field"],
            "grad_shafranov_equilibrium", nothing,
            ["H1_axisymmetric", "L2_axisymmetric"],
            _v136_dimension(get(region, "dimension", 2), 2), "radial_axisymmetric",
            "candidate_bound_equilibrium_and_stability", Dict{String,Any}())
    elseif region_class == "three_dimensional_closed"
        return CapabilityRequirementV94(key * "::realization", "operator",
            ["fourier_boundary", "three_dimensional_coils", "pressure_profile",
                "magnetic_field"], "three_dimensional_mhd_equilibrium", nothing,
            ["Fourier_Zernike", "filament_curve"],
            _v136_dimension(get(region, "dimension", 3), 3), "periodic_fourier",
            "candidate_bound_equilibrium_and_stability", Dict{String,Any}())
    end
    CapabilityRequirementV94(key * "::realization", "operator",
        ["magnetic_field", "particle_inventory", "thermal_energy", "endpoint_flux"],
        "open_field_equilibrium_end_loss", nothing,
        ["field_line", "finite_volume_1d"],
        _v136_dimension(get(region, "dimension", 1), 1),
        "open_field_line", "candidate_bound_equilibrium_and_stability",
        Dict{String,Any}())
end

function _v136_interface_requirement(interface)
    key = String(get(interface, "interface_key",
        get(interface, "interface_id", "interface")))
    CapabilityRequirementV94(key * "::coupling", "interface",
        ["conserved_interface_fluxes"], nothing,
        "coupled_flux_force_energy_continuity", ["mortar_dual"],
        _v136_dimension(get(interface, "dimension", 2), 2),
        "multiregion_interface",
        "coupled_interface_residual_jacobian", Dict{String,Any}())
end

function _v136_normalized_regions(topology)
    source = haskey(topology, "regions") ? topology["regions"] : topology["nodes"]
    regions = [Dict{String,Any}(_v93_plain(item)) for item in source]
    [region for region in regions if String(get(region, "field_semantics",
        get(region, "raw_coordinate_map", ""))) in (
            "axisymmetric_closed", "three_dimensional_closed",
            "open_guiding_field", "open_field", "hybrid_field")]
end

function compile_region_realization_plan_v136(topology_raw;
        registry = default_region_realization_registry_v136())
    topology = Dict{String,Any}(_v93_plain(topology_raw))
    regions = _v136_normalized_regions(topology)
    interfaces = Dict{String,Any}.(_v93_plain(get(topology, "interfaces", Any[])))
    sort!(regions; by = item -> String(get(item, "region_key",
        get(item, "node_id", "region"))))
    sort!(interfaces; by = item -> String(get(item, "interface_key",
        get(item, "interface_id", "interface"))))
    region_routes = Dict{String,Any}[]; blockers = String[]
    classes = String[]
    for region in regions
        key = String(get(region, "region_key", get(region, "node_id", "region")))
        region_class = _v136_region_class(region)
        if region_class in ("unsupported", "explicit_subregions_required")
            push!(blockers, region_class == "explicit_subregions_required" ?
                "$key:hybrid_region_requires_explicit_subregions" :
                "$key:unsupported_region_semantics")
            push!(region_routes, Dict{String,Any}(
                "region_key" => key, "capability_class" => region_class,
                "status" => "unsupported", "selected_provider" => nothing,
                "identity_fields_used" => false))
            continue
        end
        requirement = _v136_requirement(region, region_class)
        route = route_provider_v94(registry, requirement)
        route["region_key"] = key
        route["capability_class"] = region_class
        route["identity_fields_used"] = false
        push!(classes, region_class); push!(region_routes, route)
        route["status"] == "closed" || push!(blockers,
            "$key:missing_region_realization_provider")
    end
    interface_routes = Dict{String,Any}[]
    for interface in interfaces
        route = route_provider_v94(registry, _v136_interface_requirement(interface))
        route["interface_key"] = String(get(interface, "interface_key",
            get(interface, "interface_id", "interface")))
        route["identity_fields_used"] = false
        push!(interface_routes, route)
        route["status"] == "closed" || push!(blockers,
            "$(route["interface_key"]):missing_interface_coupler")
    end
    unique_classes = sort!(unique(classes))
    capability_class = length(unique_classes) == 1 && isempty(blockers) ?
        first(unique_classes) : "mixed_multiregion"
    closed = isempty(blockers) && length(region_routes) == length(regions) &&
        all(route -> route["status"] == "closed", region_routes) &&
        all(route -> route["status"] == "closed", interface_routes)
    body = Dict{String,Any}(
        "protocol_id" => V136_PROTOCOL_ID,
        "status" => closed ? "closed" : "unsupported",
        "capability_class" => capability_class,
        "region_routes" => region_routes, "interface_routes" => interface_routes,
        "blockers" => sort!(unique(blockers)),
        "routing_unit" => "single_region_or_single_interface",
        "majority_route_used" => false, "identity_fields_used" => false,
        "partial_subgraph_promotion_allowed" => false,
        "physical_credit" => false,
        "claim_boundary" => REGION_REALIZATION_RUNTIME_V136_CLAIM_BOUNDARY)
    body["plan_hash"] = canonical_hash(body)
    body
end

function audit_proxy_gate_separation_v136(candidate_raw)
    candidate = Dict{String,Any}(_v93_plain(candidate_raw))
    gates = Dict{String,Any}.(_v93_plain(get(candidate, "physical_gates", Any[])))
    violations = String[]
    for gate in gates
        serialized = lowercase(String(JSON3.write(gate)))
        for key in V136_FORBIDDEN_PHYSICAL_PROXY_KEYS
            occursin(lowercase(key), serialized) && push!(violations,
                "physical_gate_consumes_proxy:$key")
        end
    end
    body = Dict{String,Any}(
        "status" => isempty(violations) ? "pass" : "fail",
        "violations" => sort!(unique(violations)),
        "scheduling_proxy_keys" => sort!(collect(intersect(
            Set(String.(keys(Dict{String,Any}(_v93_plain(get(candidate,
                "scheduling_features", Dict{String,Any}())))))),
            V136_FORBIDDEN_PHYSICAL_PROXY_KEYS))),
        "proxy_physical_credit" => false)
    body["audit_hash"] = canonical_hash(body)
    body
end

function _v136_fourier_point(modes, theta, phi, nfp, trig)
    sum(Float64(mode["coefficient_m"]) * trig(Int(mode["m"]) * theta -
        Int(mode["n"]) * nfp * phi) for mode in modes; init = 0.0)
end

function materialize_periodic_boundary_coils_v136(declaration_raw)
    declaration = Dict{String,Any}(_v93_plain(declaration_raw))
    nfp = Int(declaration["field_periods"])
    2 <= nfp <= 8 || throw(ArgumentError("3D field_periods must be in 2:8"))
    r_modes = Dict{String,Any}.(_v93_plain(declaration["R_modes"]))
    z_modes = Dict{String,Any}.(_v93_plain(declaration["Z_modes"]))
    any(Int(mode["n"]) != 0 && Float64(mode["coefficient_m"]) != 0.0
        for mode in vcat(r_modes, z_modes)) || throw(ArgumentError(
        "3D boundary requires a nonzero toroidal Fourier mode"))
    samples = Dict{String,Any}[]
    for phi in range(0.0, 2pi; length = 4nfp + 1)[1:end-1],
            theta in range(0.0, 2pi; length = 17)[1:end-1]
        radius = _v136_fourier_point(r_modes, theta, phi, nfp, cos)
        vertical = _v136_fourier_point(z_modes, theta, phi, nfp, sin)
        push!(samples, Dict("x" => radius * cos(phi), "y" => radius * sin(phi),
            "z" => vertical))
    end
    templates = Dict{String,Any}.(_v93_plain(declaration["coil_templates"]))
    coils = Dict{String,Any}[]
    for period in 0:nfp-1, template in templates
        angle = 2pi * (period + Float64(get(template, "phase_fraction", 0.0))) / nfp
        push!(coils, Dict("period_index" => period,
            "center" => [Float64(template["major_radius_m"]) * cos(angle),
                Float64(template["major_radius_m"]) * sin(angle),
                Float64(get(template, "vertical_m", 0.0))],
            "normal" => [cos(angle), sin(angle), 0.0],
            "minor_radius_m" => Float64(template["minor_radius_m"]),
            "current_a" => Float64(template["current_a"])))
    end
    body = Dict{String,Any}(
        "field_periods" => nfp, "boundary_samples" => samples, "coils" => coils,
        "boundary_geometry_hash" => canonical_hash(samples),
        "coil_geometry_hash" => canonical_hash(coils),
        "field_geometry_hash" => canonical_hash(Dict(
            "boundary" => samples, "coils" => coils)),
        "physical_credit" => false)
    body["materialization_hash"] = canonical_hash(body)
    body
end

function audit_field_period_sensitivity_v136(first_raw, second_raw)
    first = Dict{String,Any}(_v93_plain(first_raw))
    second = Dict{String,Any}(_v93_plain(second_raw))
    checks = Dict{String,Bool}(
        "field_periods_changed" => first["field_periods"] != second["field_periods"],
        "boundary_geometry_changed" => first["boundary_geometry_hash"] !=
            second["boundary_geometry_hash"],
        "coil_geometry_changed" => first["coil_geometry_hash"] !=
            second["coil_geometry_hash"],
        "field_geometry_changed" => first["field_geometry_hash"] !=
            second["field_geometry_hash"])
    if haskey(first, "wout_sha256") || haskey(second, "wout_sha256")
        checks["wout_changed"] = get(first, "wout_sha256", nothing) !=
            get(second, "wout_sha256", nothing)
    end
    body = Dict{String,Any}(
        "status" => all(values(checks)) ? "pass" : "fail",
        "checks" => Dict(sort!(collect(checks))),
        "physical_credit" => false)
    body["audit_hash"] = canonical_hash(body)
    body
end

function capability_quota_frontier_v136(candidates_raw, quotas_raw)
    candidates = Dict{String,Any}.(_v93_plain(candidates_raw))
    quotas = Dict{String,Int}(String(key) => Int(value) for (key, value) in
        Dict{String,Any}(_v93_plain(quotas_raw)))
    selected = Dict{String,Any}(); rejected = Dict{String,Any}()
    for class in V136_CAPABILITY_CLASSES
        rows = [candidate for candidate in candidates if
            candidate["realization_plan"]["capability_class"] == class]
        sort!(rows; by = item -> (-Float64(item["scheduler_score"]),
            canonical_hash(get(item, "scheduling_features", Dict{String,Any}()))))
        limit = get(quotas, class, 0)
        selected[class] = [Dict("candidate_ref" => get(item, "candidate_ref", nothing),
            "plan_hash" => item["realization_plan"]["plan_hash"],
            "scheduler_score" => item["scheduler_score"],
            "physical_credit" => false) for item in first(rows, min(limit, length(rows)))]
        rejected[class] = max(length(rows) - limit, 0)
    end
    body = Dict{String,Any}(
        "protocol_id" => V136_PROTOCOL_ID, "selected_by_class" => selected,
        "resource_rejected_count_by_class" => rejected,
        "quota_is_physical_gate" => false, "physical_credit" => false,
        "identity_fields_used_for_routing" => false)
    body["frontier_hash"] = canonical_hash(body)
    body
end

function couple_region_interfaces_v136(plan_raw, region_results_raw, interfaces_raw)
    plan = Dict{String,Any}(_v93_plain(plan_raw))
    results = Dict{String,Any}(String(key) => _v93_plain(value) for (key, value) in
        Dict{String,Any}(_v93_plain(region_results_raw)))
    interfaces = Dict{String,Any}.(_v93_plain(interfaces_raw))
    blockers = String[]
    plan["status"] == "closed" || push!(blockers, "realization_plan_not_closed")
    for route in plan["region_routes"]
        key = String(route["region_key"])
        haskey(results, key) || (push!(blockers, "$key:result_missing"); continue)
        result = Dict{String,Any}(results[key])
        get(result, "status", "") == "pass" || push!(blockers, "$key:solve_not_passed")
        get(result, "provider_key", nothing) == route["selected_provider"] ||
            push!(blockers, "$key:provider_binding_mismatch")
        get(result, "plan_hash", nothing) == plan["plan_hash"] ||
            push!(blockers, "$key:plan_binding_mismatch")
    end
    isempty(blockers) || return Dict{String,Any}(
        "status" => "not_solved", "whole_graph_closed" => false,
        "blockers" => sort!(unique(blockers)), "partial_subgraph_credit" => false)
    region_keys = sort!(collect(keys(results))); column = Dict(key => index
        for (index, key) in enumerate(region_keys))
    rows = Tuple{String,String,String,String,Float64}[]
    for interface in interfaces
        ikey = String(interface["interface_key"])
        minus = String(interface["minus_region_key"])
        plus = String(interface["plus_region_key"])
        for quantity in String.(interface["quantities"])
            push!(rows, (ikey, quantity, minus, plus, Float64(get(interface,
                "tolerance", 1e-8))))
        end
    end
    residual = zeros(length(rows)); jacobian = zeros(length(rows), length(region_keys))
    row_keys = String[]
    for (index, (ikey, quantity, minus, plus, _)) in enumerate(rows)
        minus_trace = results[minus]["interface_traces"][ikey][quantity]
        plus_trace = results[plus]["interface_traces"][ikey][quantity]
        residual[index] = Float64(minus_trace["value"]) - Float64(plus_trace["value"])
        jacobian[index, column[minus]] = Float64(minus_trace["response"])
        jacobian[index, column[plus]] = -Float64(plus_trace["response"])
        push!(row_keys, "$ikey::$quantity")
    end
    correction = try
        -jacobian \ residual
    catch error
        return Dict{String,Any}("status" => "numerical_fail",
            "whole_graph_closed" => false, "reason" => sprint(showerror, error),
            "partial_subgraph_credit" => false)
    end
    final_residual = residual + jacobian * correction
    tolerances = Float64[row[5] for row in rows]
    passed = all(abs.(final_residual) .<= tolerances)
    body = Dict{String,Any}(
        "status" => passed ? "pass" : "physical_fail",
        "whole_graph_closed" => passed,
        "row_keys" => row_keys, "region_correction_keys" => region_keys,
        "initial_residual" => residual,
        "jacobian" => [collect(row) for row in eachrow(jacobian)],
        "correction" => correction, "final_residual" => final_residual,
        "exact_declared_jacobian_used" => true,
        "partial_subgraph_credit" => false,
        "interface_coupling_credit" => passed,
        "whole_device_physical_credit" => false)
    body["coupling_hash"] = canonical_hash(body)
    body
end
