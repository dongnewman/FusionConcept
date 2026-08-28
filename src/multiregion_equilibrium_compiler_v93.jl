const MULTIREGION_EQUILIBRIUM_COMPILER_V93_CLAIM_BOUNDARY =
    "Compilation and capability routing are label-free evidence operations. Unsupported declarations are not projected onto easier equations and compilation is not a solve."

struct MultiRegionEquilibriumRequestV93
    schema_version::String
    protocol_id::String
    source_provenance::Dict{String,Any}
    problem::Union{Nothing,MultiRegionEquilibriumIRV93}
    problem_hash::String
    route::Dict{String,Any}
    route_hash::String
    request_hash::String
    compilation_status::String
    first_blocker::Union{Nothing,String}
    translation_gaps::Vector{String}
end

function _v93_required_capabilities(ir::MultiRegionEquilibriumIRV93)
    operators = Set{String}()
    for equation in ir.equations
        push!(operators, String(equation["governing_operator"]))
        union!(operators, String.(get(equation, "additive_operators", Any[])))
    end
    Dict{String,Any}(
        "operators" => sort!(collect(operators)),
        "states" => sort!(unique(String(state["state_id"]) for state in ir.states)),
        "region_types" => sort!(unique(String(region["region_type"]) for region in ir.regions)),
        "region_dimensions" => sort!(unique(Int(region["dimension"]) for region in ir.regions)),
        "interface_conditions" => sort!(unique(String(condition["condition_id"])
            for interface in ir.interfaces for condition in get(interface, "conditions", Any[]))),
        "discretization_form" => get(ir.discretization, "form", nothing),
        "monolithic_residual" => get(ir.discretization, "monolithic_residual", false),
        "domain_decomposition" => get(ir.discretization, "domain_decomposition", false),
        "mesh_levels" => sort!(String.(get(ir.discretization, "mesh_levels", Any[]))))
end

function _v93_backend_matches(required, backend)
    get(backend, "candidate_execution", false) === true || return false, "candidate_execution_not_attested"
    for key in ("operators", "states", "region_types", "interface_conditions")
        isempty(setdiff(Set(required[key]), Set(get(backend, key, Any[])))) || return false, "missing_$(key)"
    end
    isempty(setdiff(Set(required["region_dimensions"]), Set(Int.(get(backend, "region_dimensions", Any[]))))) ||
        return false, "missing_region_dimensions"
    required["discretization_form"] in get(backend, "discretization_forms", Any[]) ||
        return false, "discretization_form_mismatch"
    required["monolithic_residual"] === true && get(backend, "monolithic_residual", false) !== true &&
        return false, "monolithic_residual_unavailable"
    required["domain_decomposition"] === true && get(backend, "domain_decomposition", false) !== true &&
        return false, "domain_decomposition_unavailable"
    isempty(setdiff(Set(["coarse", "medium", "fine"]), Set(required["mesh_levels"]))) &&
        get(backend, "independent_mesh_per_level", false) === true || return false, "mesh_contract_incomplete"
    get(backend, "exact_ad_or_symbolic_jacobian", false) === true || return false, "jacobian_contract_incomplete"
    true, "pass"
end

function route_multiregion_equilibrium_v93(ir::MultiRegionEquilibriumIRV93; backends = Any[])
    required = _v93_required_capabilities(ir)
    matches = Dict{String,Any}[]; mismatches = Dict{String,Any}[]
    for raw in backends
        backend = Dict{String,Any}(_v93_plain(raw))
        matched, reason = _v93_backend_matches(required, backend)
        record = Dict{String,Any}("backend_id" => get(backend, "backend_id", "anonymous"),
            "capability_hash" => canonical_hash(backend), "status" => matched ? "pass" : "unsupported",
            "reason" => reason)
        push!(matched ? matches : mismatches, record)
    end
    sort!(matches; by = canonical_hash); sort!(mismatches; by = canonical_hash)
    status = isempty(matches) ? "unsupported_operator_or_backend" : "pass"
    body = Dict{String,Any}(
        "protocol_id" => V93_PROTOCOL_ID, "problem_hash" => ir.problem_hash,
        "required_capabilities" => required, "status" => status,
        "selected_backend" => isempty(matches) ? nothing : first(matches),
        "mismatches" => mismatches, "projection_to_easier_model_used" => false,
        "access_audit" => ["operators", "states", "region_types", "region_dimensions",
            "interface_conditions", "discretization_contract", "backend_capabilities"])
    body["route_hash"] = canonical_hash(body)
    body
end

function _v93_request_from_ir(ir::MultiRegionEquilibriumIRV93, provenance, route)
    request_body = Dict{String,Any}("protocol_id" => V93_PROTOCOL_ID,
        "problem_hash" => ir.problem_hash, "route_hash" => route["route_hash"],
        "execution_contract" => Dict("mesh_levels" => ["coarse", "medium", "fine"],
            "initialization_paths" => ["direct_initial_state_1", "direct_initial_state_2",
                "direct_initial_state_3", "continuation_initialization_only"],
            "recovery_paths" => ["newton_line_search", "trust_region"],
            "final_monolithic_reaudit" => true))
    blocker = route["status"] == "pass" ? nothing : "missing_compatible_candidate_bound_multiregion_backend"
    MultiRegionEquilibriumRequestV93("1.0.0", V93_PROTOCOL_ID,
        Dict{String,Any}(_v93_plain(provenance)), ir, ir.problem_hash, route,
        String(route["route_hash"]), canonical_hash(request_body),
        String(route["status"]), blocker, String[])
end

function compile_multiregion_equilibrium_request_v93(declaration_raw;
        source_provenance = Dict{String,Any}(), backends = Any[])
    ir = compile_multiregion_equilibrium_ir_v93(declaration_raw)
    route = route_multiregion_equilibrium_v93(ir; backends = backends)
    _v93_request_from_ir(ir, source_provenance, route)
end

function compile_v92_realization_request_v93(realization_raw;
        source_provenance = Dict{String,Any}(), backends = Any[])
    raw = _v93_plain(realization_raw)
    applicability = Dict{String,Any}(get(raw, "applicability_obligations", Dict()))
    regions = Any[]
    for region in get(raw, "regions", Any[])
        push!(regions, Dict{String,Any}(
            "region_type" => get(region, "region_type", nothing),
            "dimension" => get(region, "dimension", nothing),
            "geometry_fields" => Dict("coordinate_map" => get(region, "coordinate_map", nothing),
                "radial_extent_normalized" => get(region, "radial_extent_normalized", nothing),
                "length_m" => get(region, "length_m", nothing)),
            "material_fields" => Dict{String,Any}(),
            "boundary_conditions" => Any[]))
    end
    incomplete_projection = Dict{String,Any}(
        "protocol_id" => V93_PROTOCOL_ID, "legacy_source_protocol" => get(raw, "protocol_id", nothing),
        "regions" => _v93_sorted_plain(regions),
        "declared_state_obligations" => sort!(String.(get(applicability, "state_variables", Any[]))),
        "declared_operator_obligations" => sort!(String.(get(applicability, "declared_operators", Any[]))),
        "declared_interface_obligations" => sort!(String.(get(applicability, "interface_conditions", Any[]))),
        "evidence_obligations" => sort!(String.(get(applicability, "evidence_obligations", Any[]))),
        "geometry_fields" => _v93_sorted_plain(get(raw, "oriented_surfaces", Any[])),
        "field_sources" => _v93_sorted_plain(get(raw, "field_sources", Any[])),
        "profiles" => _v93_sorted_plain(get(raw, "profiles", Any[])))
    gaps = [
        "state_ownership_and_discrete_spaces_not_declared",
        "one_governing_residual_per_equation_not_declared",
        "operator_validity_domains_not_declared",
        "region_material_fields_not_declared",
        "region_boundary_conditions_not_bound_to_explicit_regions",
        "interface_endpoints_not_bound_to_explicit_regions",
        "interface_multiplier_or_mortar_spaces_not_declared",
        "candidate_bound_monolithic_residual_not_available",
        "candidate_bound_domain_decomposition_contract_not_available"]
    problem_hash = canonical_hash(incomplete_projection)
    route_body = Dict{String,Any}(
        "protocol_id" => V93_PROTOCOL_ID, "problem_hash" => problem_hash,
        "required_capability" => "candidate_bound_multiregion_fem_snes_fieldsplit",
        "status" => "unsupported_operator_or_backend", "translation_gaps" => gaps,
        "projection_to_easier_model_used" => false,
        "access_audit" => ["regions", "applicability_obligations", "oriented_surfaces",
            "field_sources", "profiles"])
    route_body["route_hash"] = canonical_hash(route_body)
    request_body = Dict{String,Any}("protocol_id" => V93_PROTOCOL_ID,
        "problem_hash" => problem_hash, "route_hash" => route_body["route_hash"],
        "translation_gaps" => gaps)
    MultiRegionEquilibriumRequestV93("1.0.0", V93_PROTOCOL_ID,
        Dict{String,Any}(_v93_plain(source_provenance)), nothing, problem_hash, route_body,
        String(route_body["route_hash"]), canonical_hash(request_body),
        "unsupported_operator_or_backend", first(gaps), gaps)
end

function multiregion_equilibrium_request_to_dict_v93(request::MultiRegionEquilibriumRequestV93)
    Dict{String,Any}(
        "schema_version" => request.schema_version, "protocol_id" => request.protocol_id,
        "source_provenance" => request.source_provenance,
        "problem" => request.problem === nothing ? nothing : multiregion_equilibrium_ir_to_dict_v93(request.problem),
        "problem_hash" => request.problem_hash, "route" => request.route,
        "route_hash" => request.route_hash, "request_hash" => request.request_hash,
        "compilation_status" => request.compilation_status,
        "first_blocker" => request.first_blocker, "translation_gaps" => request.translation_gaps,
        "claim_boundary" => MULTIREGION_EQUILIBRIUM_COMPILER_V93_CLAIM_BOUNDARY)
end
