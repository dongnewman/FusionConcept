const UNIFIED_JUDGMENT_STAGE_IDS_V55 = (
    "physical_description_completeness",
    "topology_and_causality",
    "conservation_and_state_evolution",
    "perturbation_and_stability",
    "particle_energy_transport_and_burn",
    "net_energy_closure",
    "engineering_realizability",
    "uncertainty_and_evidence",
)

const _V55_REQUIRED_DESCRIPTION_COLLECTIONS = (
    "regions", "species", "fields", "materials", "boundaries", "sources",
    "sinks", "observables",
)

const _V55_CONTROL_POLICY_MODES = Set([
    "active_closed_loop", "open_loop_actuation", "passive_stability",
    "explicit_no_controller",
])

const _V55_REQUIRED_PERTURBATION_CLASSES = Set([
    "state", "boundary", "source", "controller", "manufacturing",
])

const _V55_REQUIRED_ENGINEERING_CHECKS = Set([
    "field_strength", "force", "stress", "heat_flux", "material_temperature",
    "irradiation", "quench", "repetition_rate", "maintenance_space",
    "fuel_cycle", "component_lifetime",
])

const _V55_REQUIRED_UNCERTAINTY_CHECKS = Set([
    "perturbation_uncertainty", "manufacturing_tolerance", "model_error",
    "resolution_convergence", "cross_code_replication", "experimental_anchor",
])

const _V55_ALLOWED_CHECK_STATES = Set([
    "pass", "fail", "unknown", "unsupported", "not_applicable",
])

const _V55_NON_ROUTING_KEYS = Set([
    "family", "parent_family", "device_class", "classification", "classifications",
    "human_label", "display_label", "lineage_parent_revision_ids",
])

const _V55_FORBIDDEN_DEFAULT_MARKERS = (
    "family_default", "family-derived", "family_derived", "parent_default",
    "parent-derived", "parent_derived", "parent_template", "class_default",
)

const _V55_CLAIM_BOUNDARY =
    "A v55 chain pass means that the submitted candidate-bound artifacts satisfy the " *
    "same eight-stage judgment contract for the declared mission. It is not independent " *
    "verification of the artifacts, net-electric success, buildability, reactor readiness, " *
    "or authorization for promotion. Reference fixtures test contract recovery and label " *
    "invariance only."

function _v55_record(value)
    plain = _plain_json(value)
    plain isa AbstractDict || throw(ArgumentError("v55 judgment input must be an object"))
    return Dict{String,Any}(String(key) => _plain_json(item) for (key, item) in plain)
end

function _v55_check(id::String, status::String, reason::String;
        details = Dict{String,Any}())
    status in _V55_ALLOWED_CHECK_STATES ||
        throw(ArgumentError("invalid v55 check state $status"))
    return Dict{String,Any}(
        "check_id" => id,
        "status" => status,
        "reason" => reason,
        "details" => _plain_json(details),
    )
end

function _v55_stage(id::String, checks)
    records = Dict{String,Any}[Dict{String,Any}(String(key) => _plain_json(value)
        for (key, value) in check) for check in checks]
    states = String[String(check["status"]) for check in records]
    status = any(==("fail"), states) ? "fail" :
        any(state -> state in ("unknown", "unsupported"), states) ? "unknown" :
        isempty(states) || all(==("not_applicable"), states) ? "unknown" : "pass"
    return Dict{String,Any}(
        "stage_id" => id,
        "status" => status,
        "checks" => records,
        "check_count" => length(records),
    )
end

function _v55_collection(record, key::String)
    value = get(record, key, nothing)
    return value isa AbstractVector ? collect(value) : Any[]
end

function _v55_string_id(item, keys)
    item isa AbstractDict || return ""
    for key in keys
        value = get(item, key, nothing)
        value === nothing || return String(value)
    end
    return ""
end

function _v55_find_forbidden_defaults!(paths, value, path = "\$")
    if value isa AbstractDict
        for (raw_key, child) in value
            key = lowercase(String(raw_key))
            child_path = "$path.$key"
            if key in ("origin", "value_origin", "default_source", "assumption_source",
                    "routing_source")
                if child isa AbstractString
                    marker = lowercase(String(child))
                    any(token -> occursin(token, marker), _V55_FORBIDDEN_DEFAULT_MARKERS) &&
                        push!(paths, child_path)
                end
            end
            _v55_find_forbidden_defaults!(paths, child, child_path)
        end
    elseif value isa AbstractVector
        for (index, child) in enumerate(value)
            _v55_find_forbidden_defaults!(paths, child, "$path[$index]")
        end
    end
    return paths
end

function _v55_non_routing_projection(value)
    if value isa AbstractDict
        projected = Dict{String,Any}()
        for (raw_key, child) in value
            key = String(raw_key)
            lowercase(key) in _V55_NON_ROUTING_KEYS && continue
            projected[key] = _v55_non_routing_projection(child)
        end
        return projected
    elseif value isa AbstractVector
        return Any[_v55_non_routing_projection(child) for child in value]
    end
    return _plain_json(value)
end

function _v55_observed_non_routing_fields!(paths, value, path = "\$")
    if value isa AbstractDict
        for (raw_key, child) in value
            key = lowercase(String(raw_key))
            child_path = "$path.$key"
            key in _V55_NON_ROUTING_KEYS && push!(paths, child_path)
            _v55_observed_non_routing_fields!(paths, child, child_path)
        end
    elseif value isa AbstractVector
        for (index, child) in enumerate(value)
            _v55_observed_non_routing_fields!(paths, child, "$path[$index]")
        end
    end
    return paths
end

function _v55_evidence_index(record)
    evidence = _v55_collection(record, "evidence")
    ids = Set{String}()
    invalid = String[]
    for (index, item) in enumerate(evidence)
        id = _v55_string_id(item, ("evidence_id",))
        isempty(id) && (push!(invalid, "evidence[$index] missing evidence_id"); continue)
        id in ids && push!(invalid, "duplicate evidence_id $id")
        push!(ids, id)
        item isa AbstractDict || continue
        hash = String(get(item, "artifact_hash", ""))
        length(hash) == 64 || push!(invalid, "evidence $id artifact_hash is not sha256-sized")
        isempty(String(get(item, "evidence_class", ""))) &&
            push!(invalid, "evidence $id missing evidence_class")
    end
    return ids, invalid
end

function _v55_evidence_refs(item)
    item isa AbstractDict || return String[]
    refs = get(item, "evidence_refs", Any[])
    refs isa AbstractVector || return String[]
    return String.(refs)
end

function _v55_missing_evidence_refs(items, evidence_ids)
    missing = String[]
    for item in items, ref in _v55_evidence_refs(item)
        ref in evidence_ids || push!(missing, ref)
    end
    return sort!(unique(missing))
end

function _v55_description_stage(record)
    description = get(record, "physical_description", Dict{String,Any}())
    description isa AbstractDict || return _v55_stage(
        UNIFIED_JUDGMENT_STAGE_IDS_V55[1], [
            _v55_check("physical_description_object", "fail",
                "physical_description must be an object")])
    checks = Dict{String,Any}[]
    for key in _V55_REQUIRED_DESCRIPTION_COLLECTIONS
        present = haskey(description, key) && get(description, key, nothing) isa AbstractVector
        nonempty = present && !isempty(description[key])
        push!(checks, _v55_check("declare_$key", nonempty ? "pass" : "fail",
            nonempty ? "$key explicitly declared" : "$key must be an explicit non-empty collection"))
    end
    controllers_present = haskey(description, "controllers") &&
        get(description, "controllers", nothing) isa AbstractVector
    controllers = controllers_present ? collect(description["controllers"]) : Any[]
    policy = get(description, "control_policy", nothing)
    policy_object = policy isa AbstractDict
    mode = policy_object ? String(get(policy, "mode", "")) : ""
    mode_valid = mode in _V55_CONTROL_POLICY_MODES
    actuator_refs = policy_object && get(policy, "actuator_refs", nothing) isa AbstractVector ?
        String.(policy["actuator_refs"]) : String[]
    applicability_basis = policy_object ? String(get(policy, "applicability_basis", "")) : ""
    policy_consistent = if !controllers_present || !policy_object || !mode_valid
        false
    elseif mode == "active_closed_loop"
        !isempty(controllers)
    elseif mode == "open_loop_actuation"
        isempty(controllers) && !isempty(actuator_refs)
    elseif mode in ("passive_stability", "explicit_no_controller")
        isempty(controllers) && !isempty(applicability_basis)
    else
        false
    end
    push!(checks, _v55_check("declare_control_policy",
        policy_consistent ? "pass" : "fail",
        policy_consistent ? "control semantics are explicitly declared" :
            "declare one consistent control policy; an empty controllers array alone is not a no-controller declaration";
        details = Dict("mode" => mode, "controllers_present" => controllers_present,
            "controller_count" => length(controllers), "actuator_refs" => actuator_refs,
            "applicability_basis" => applicability_basis)))
    default_paths = _v55_find_forbidden_defaults!(String[], record)
    push!(checks, _v55_check("no_family_or_parent_defaults",
        isempty(default_paths) ? "pass" : "fail",
        isempty(default_paths) ? "no parent/family default marker found" :
            "parent/family-derived defaults are prohibited";
        details = Dict("paths" => default_paths)))
    return _v55_stage(UNIFIED_JUDGMENT_STAGE_IDS_V55[1], checks)
end

function _v55_topology_stage(record)
    topology = get(record, "topology_causality", Dict{String,Any}())
    description = get(record, "physical_description", Dict{String,Any}())
    nodes = topology isa AbstractDict ? _v55_collection(topology, "nodes") : Any[]
    edges = topology isa AbstractDict ? _v55_collection(topology, "edges") : Any[]
    node_ids = String[_v55_string_id(node, ("node_id", "id")) for node in nodes]
    node_set = Set(filter(!isempty, node_ids))
    endpoint_errors = String[]
    incident = Set{String}()
    direction_errors = String[]
    for (index, edge) in enumerate(edges)
        from = _v55_string_id(edge, ("from", "source_ref"))
        to = _v55_string_id(edge, ("to", "target_ref"))
        from in node_set || push!(endpoint_errors, "edge[$index].from=$from")
        to in node_set || push!(endpoint_errors, "edge[$index].to=$to")
        from in node_set && push!(incident, from)
        to in node_set && push!(incident, to)
        edge isa AbstractDict || continue
        get(edge, "direction", nothing) == "directed" ||
            push!(direction_errors, "edge[$index] missing directed flow")
        accounts = get(edge, "accounts", Any[])
        accounts isa AbstractVector && !isempty(accounts) ||
            push!(direction_errors, "edge[$index] missing particle/energy account")
    end
    reference_errors = String[]
    if description isa AbstractDict
        for (collection, key) in (("sources", "target_ref"), ("sinks", "source_ref"),
                ("controllers", "target_ref"), ("observables", "source_ref"))
            for (index, item) in enumerate(_v55_collection(description, collection))
                ref = item isa AbstractDict ? String(get(item, key, "")) : ""
                ref in node_set || push!(reference_errors, "$collection[$index].$key=$ref")
            end
        end
    end
    isolated = sort!(collect(setdiff(node_set, incident)))
    checks = [
        _v55_check("unique_declared_nodes",
            !isempty(nodes) && length(node_set) == length(nodes) ? "pass" : "fail",
            "topology nodes must be non-empty, identified, and unique"),
        _v55_check("valid_directed_edges",
            !isempty(edges) && isempty(endpoint_errors) && isempty(direction_errors) ? "pass" : "fail",
            "edges must connect declared nodes with explicit directed accounts";
            details = Dict("endpoint_errors" => endpoint_errors,
                "direction_errors" => direction_errors)),
        _v55_check("no_suspended_modules", isempty(isolated) ? "pass" : "fail",
            isempty(isolated) ? "all nodes participate in the causal graph" :
                "isolated topology nodes are prohibited"; details = Dict("isolated_nodes" => isolated)),
        _v55_check("source_sink_control_observable_bindings",
            isempty(reference_errors) ? "pass" : "fail",
            isempty(reference_errors) ? "all causal endpoints bind to graph nodes" :
                "unbound causal endpoints found"; details = Dict("errors" => reference_errors)),
    ]
    return _v55_stage(UNIFIED_JUDGMENT_STAGE_IDS_V55[2], checks)
end

function _v55_float(item, key::String, fallback = NaN)
    value = item isa AbstractDict ? get(item, key, fallback) : fallback
    value isa Real || return Float64(fallback)
    return Float64(value)
end

function _v55_state_stage(record)
    state = get(record, "state_evolution", Dict{String,Any}())
    state isa AbstractDict || return _v55_stage(UNIFIED_JUDGMENT_STAGE_IDS_V55[3], [
        _v55_check("state_evolution_object", "fail", "state_evolution must be an object")])
    solver_hash = String(get(state, "solver_output_hash", ""))
    generated_nominal = get(state, "generated_nominal", nothing)
    provenance_status = generated_nominal === true ? "fail" :
        get(state, "solver_derived", false) !== true || length(solver_hash) != 64 ?
            "unknown" : "pass"
    residuals = _v55_collection(state, "residuals")
    tolerance = _v55_float(state, "normalized_residual_tolerance", NaN)
    required_accounts = Set(String.(get(state, "required_accounts", Any[])))
    seen_accounts = Set{String}()
    residual_errors = String[]
    residual_exceedances = String[]
    computed = Dict{String,Any}[]
    for (index, residual) in enumerate(residuals)
        account = residual isa AbstractDict ? String(get(residual, "account", "")) : ""
        !isempty(account) && push!(seen_accounts, account)
        dU = _v55_float(residual, "dU_dt")
        divF = _v55_float(residual, "divergence_F")
        source = _v55_float(residual, "source_S")
        normalization = _v55_float(residual, "normalization")
        values = (dU, divF, source, normalization)
        if !all(isfinite, values) || normalization <= 0.0
            push!(residual_errors, "residual[$index] has invalid terms")
            continue
        end
        normalized = abs(dU + divF - source) / normalization
        push!(computed, Dict("account" => account, "normalized_residual" => normalized))
        isfinite(tolerance) && tolerance >= 0.0 && normalized > tolerance &&
            push!(residual_exceedances, "residual[$index] exceeds tolerance")
    end
    missing_accounts = sort!(collect(setdiff(required_accounts, seen_accounts)))
    mode = String(get(state, "mode", ""))
    times = Float64[]
    raw_times = get(state, "time_samples_s", Any[])
    if raw_times isa AbstractVector && all(value -> value isa Real, raw_times)
        times = Float64.(raw_times)
    end
    trajectory_ok = if mode == "steady"
        !isempty(residuals) && all(item -> begin
            dU = abs(_v55_float(item, "dU_dt"))
            normalization = _v55_float(item, "normalization")
            isfinite(dU) && isfinite(normalization) && normalization > 0 &&
                dU / normalization <= _v55_float(state, "steady_time_term_tolerance", NaN)
        end, residuals)
    elseif mode in ("transient", "pulsed")
        length(times) >= 3 && issorted(times) && all(diff(times) .> 0.0) &&
            get(state, "complete_time_trajectory", false) === true
    else
        false
    end
    checks = [
        _v55_check("candidate_bound_solver_output", provenance_status,
            "state evolution must come from a candidate-bound solver artifact, never a nominal generator"),
        _v55_check("generalized_conservation_residual",
            !isempty(residual_exceedances) ? "fail" :
                isempty(residuals) || !isempty(residual_errors) || !isempty(missing_accounts) ||
                    !isfinite(tolerance) || tolerance < 0.0 ? "unknown" : "pass",
            "every required account must satisfy dU/dt + div(F) - S = 0 within tolerance";
            details = Dict("computed_residuals" => computed,
                "errors" => vcat(residual_errors, residual_exceedances),
                "missing_accounts" => missing_accounts)),
        _v55_check("steady_or_complete_trajectory", trajectory_ok ? "pass" : "unknown",
            "steady candidates require a negligible time term; pulsed/transient candidates require a complete trajectory"),
    ]
    return _v55_stage(UNIFIED_JUDGMENT_STAGE_IDS_V55[3], checks)
end

function _v55_stability_stage(record, evidence_ids)
    stability = get(record, "perturbation_stability", Dict{String,Any}())
    tests = stability isa AbstractDict ? _v55_collection(stability, "tests") : Any[]
    classes = Set(String(get(item, "perturbation_class", "")) for item in tests if item isa AbstractDict)
    missing_classes = sort!(collect(setdiff(_V55_REQUIRED_PERTURBATION_CLASSES, classes)))
    missing_outputs = String[]
    explicit_failures = String[]
    for (index, item) in enumerate(tests)
        item isa AbstractDict || (push!(missing_outputs, "tests[$index] is not an object"); continue)
        isempty(String(get(item, "operator_id", ""))) && push!(missing_outputs, "tests[$index] missing operator_id")
        length(String(get(item, "solver_output_hash", ""))) == 64 ||
            push!(missing_outputs, "tests[$index] missing solver output hash")
        String(get(item, "outcome", "")) in ("growth", "saturation", "escape", "damage", "bounded") ||
            push!(missing_outputs, "tests[$index] missing growth/saturation/escape/damage outcome")
        acceptance = get(item, "within_acceptance", nothing)
        acceptance === false && push!(explicit_failures, "tests[$index] exceeds declared acceptance")
        acceptance === nothing && push!(missing_outputs, "tests[$index] lacks acceptance result")
    end
    missing_refs = _v55_missing_evidence_refs(tests, evidence_ids)
    checks = [
        _v55_check("uniform_perturbation_set", isempty(missing_classes) ? "pass" : "unknown",
            "the same perturbation classes are required for every candidate";
            details = Dict("missing_classes" => missing_classes)),
        _v55_check("candidate_bound_perturbation_responses",
            !isempty(explicit_failures) ? "fail" :
                isempty(tests) || !isempty(missing_outputs) ? "unknown" : "pass",
            "operators may differ, but every response must be solved and classified by the same contract";
            details = Dict("missing_outputs" => missing_outputs,
                "explicit_failures" => explicit_failures)),
        _v55_check("perturbation_evidence_bindings", isempty(missing_refs) ? "pass" : "unknown",
            "all perturbation evidence references must resolve";
            details = Dict("missing_evidence_refs" => missing_refs)),
    ]
    return _v55_stage(UNIFIED_JUDGMENT_STAGE_IDS_V55[4], checks)
end

function _v55_transport_stage(record)
    transport = get(record, "transport_burn", Dict{String,Any}())
    state = get(record, "state_evolution", Dict{String,Any}())
    transport isa AbstractDict || return _v55_stage(UNIFIED_JUDGMENT_STAGE_IDS_V55[5], [
        _v55_check("transport_burn_object", "fail", "transport_burn must be an object")])
    state_hash = String(get(state, "solver_output_hash", ""))
    generated_nominal = get(transport, "generated_nominal", nothing)
    binding_ok = get(transport, "solver_derived", false) === true &&
        generated_nominal === false &&
        String(get(transport, "state_solution_hash", "")) == state_hash &&
        length(String(get(transport, "solver_output_hash", ""))) == 64
    particle_paths = _v55_collection(transport, "particle_paths")
    energy_paths = _v55_collection(transport, "energy_paths")
    particle_roles = Set(String(get(item, "role", "")) for item in particle_paths if item isa AbstractDict)
    energy_roles = Set(String(get(item, "role", "")) for item in energy_paths if item isa AbstractDict)
    particle_ok = all(role -> role in particle_roles, ("production", "loss", "burn"))
    energy_ok = all(role -> role in energy_roles, ("deposition", "transport", "escape"))
    reaction = _v55_float(transport, "fusion_reaction_rate_per_s")
    fusion_power = _v55_float(transport, "fusion_power_w")
    self_heating = _v55_float(transport, "self_heating_power_w")
    mission = get(record, "mission", Dict{String,Any}())
    burn_required = mission isa AbstractDict && get(mission, "fusion_burn_required", false) === true
    burn_known = all(isfinite, (reaction, fusion_power, self_heating))
    burn_ok = burn_known && reaction >= 0.0 && fusion_power >= 0.0 && self_heating >= 0.0 &&
        (!burn_required || (reaction > 0.0 && fusion_power > 0.0))
    confinement_source = lowercase(String(get(transport, "confinement_time_source", "")))
    missing_confinement_source = isempty(confinement_source)
    nominal_dependency = occursin("nominal", confinement_source) || occursin("assumed", confinement_source)
    checks = [
        _v55_check("state_solution_binding", generated_nominal === true ? "fail" :
            binding_ok ? "pass" : "unknown",
            "transport and burn outputs must bind to the solved candidate state"),
        _v55_check("particle_production_loss_burn_paths", particle_ok ? "pass" : "unknown",
            "particle production, loss, and burn paths must all be explicit"),
        _v55_check("energy_deposition_transport_escape_paths", energy_ok ? "pass" : "unknown",
            "energy deposition, transport, and escape paths must all be explicit"),
        _v55_check("state_derived_fusion_and_self_heating", !burn_known ? "unknown" :
            burn_ok ? "pass" : "fail",
            "reaction rate, fusion power, and self-heating must be nonnegative state-derived outputs"),
        _v55_check("no_nominal_confinement_or_gain", nominal_dependency ? "fail" :
            missing_confinement_source ? "unknown" : "pass",
            "nominal or assumed confinement time/gain cannot satisfy the chain"),
    ]
    return _v55_stage(UNIFIED_JUDGMENT_STAGE_IDS_V55[5], checks)
end

function _v55_net_energy_stage(record)
    ledger = get(record, "net_energy", Dict{String,Any}())
    state = get(record, "state_evolution", Dict{String,Any}())
    transport = get(record, "transport_burn", Dict{String,Any}())
    ledger isa AbstractDict || return _v55_stage(UNIFIED_JUDGMENT_STAGE_IDS_V55[6], [
        _v55_check("net_energy_object", "fail", "net_energy must be an object")])
    terms = _v55_collection(ledger, "terms")
    allowed_hashes = Set(filter(!isempty, String[
        String(get(state, "solver_output_hash", "")),
        String(get(transport, "solver_output_hash", "")),
        String(get(get(record, "engineering", Dict{String,Any}()),
            "solver_output_hash", "")),
    ]))
    missing_outputs = String[]
    invalid_values = String[]
    incomplete_roles = String[]
    strict_role_completeness = get(ledger,
        "strict_role_completeness_required", false) === true
    total = 0.0
    required_roles = Set(["fusion", "drive", "loss", "recirculating"])
    seen_roles = Set{String}()
    for (index, term) in enumerate(terms)
        term isa AbstractDict || (push!(missing_outputs, "terms[$index] is not an object"); continue)
        role = String(get(term, "role", ""))
        push!(seen_roles, role)
        value = _v55_float(term, "value_w")
        completeness = String(get(term, "role_completeness", "unknown"))
        if isfinite(value)
            total += value
        elseif completeness == "complete"
            push!(invalid_values, "terms[$index] value is not finite despite complete role")
        else
            push!(missing_outputs, "terms[$index] value is unavailable for incomplete $role role")
        end
        get(term, "solver_derived", false) === true ||
            push!(missing_outputs, "terms[$index] is not solver-derived")
        String(get(term, "source_output_hash", "")) in allowed_hashes ||
            push!(missing_outputs, "terms[$index] does not bind to a prior-stage solver output")
        if strict_role_completeness &&
                completeness != "complete"
            push!(incomplete_roles, isempty(role) ? "terms[$index]" : role)
            push!(missing_outputs, "terms[$index] is an incomplete $role power role")
        end
    end
    missing_roles = sort!(collect(setdiff(required_roles, seen_roles)))
    reported = _v55_float(ledger, "reported_net_power_w")
    tolerance = _v55_float(ledger, "closure_tolerance_w")
    closure_known = isfinite(reported) && isfinite(tolerance) && tolerance >= 0.0
    closure_ok = closure_known &&
        abs(total - reported) <= tolerance
    provenance_fail = get(ledger, "generated_nominal", nothing) === true ||
        get(ledger, "artificially_closed", nothing) === true
    provenance_known = haskey(ledger, "generated_nominal") && haskey(ledger, "artificially_closed")
    mission = get(record, "mission", Dict{String,Any}())
    positive_required = mission isa AbstractDict &&
        get(mission, "positive_net_energy_required", false) === true
    ledger_roles_complete = isempty(missing_roles) && isempty(missing_outputs) &&
        isempty(invalid_values) && !isempty(terms)
    sign_known = !positive_required || (isfinite(reported) && ledger_roles_complete && closure_known)
    sign_ok = !positive_required || (isfinite(reported) && reported > 0.0)
    checks = [
        _v55_check("prior_solver_output_terms",
            !isempty(invalid_values) ? "fail" :
                isempty(terms) || !isempty(missing_outputs) || !isempty(missing_roles) ? "unknown" : "pass",
            "fusion, drive, loss, and recirculating terms must come only from prior solver outputs";
            details = Dict("missing_outputs" => missing_outputs,
                "invalid_values" => invalid_values, "missing_roles" => missing_roles,
                "incomplete_roles" => sort!(unique(incomplete_roles)))),
        _v55_check("recomputed_net_energy_closure", !closure_known ? "unknown" :
            closure_ok ? "pass" : "fail",
            "the judgment kernel recomputes the submitted net ledger";
            details = Dict("recomputed_net_power_w" => total,
                "reported_net_power_w" => isfinite(reported) ? reported : nothing)),
        _v55_check("no_generated_nominal_ledger", provenance_fail ? "fail" :
            provenance_known ? "pass" : "unknown",
            "generation-stage artificial closure cannot be passing evidence"),
        _v55_check("mission_net_energy_requirement", !sign_known ? "unknown" :
            sign_ok ? "pass" : "fail",
            positive_required ? "declared net-energy mission requires positive solved net power" :
                "reference/science mission requires ledger closure, not a fabricated positive sign"),
    ]
    return _v55_stage(UNIFIED_JUDGMENT_STAGE_IDS_V55[6], checks)
end

function _v55_engineering_stage(record, evidence_ids)
    engineering = get(record, "engineering", Dict{String,Any}())
    checks_in = engineering isa AbstractDict ? _v55_collection(engineering, "checks") : Any[]
    by_id = Dict{String,Any}()
    duplicates = String[]
    structural_errors = String[]
    explicit_failures = String[]
    unresolved = String[]
    for (index, item) in enumerate(checks_in)
        id = _v55_string_id(item, ("check_id",))
        isempty(id) && (push!(structural_errors, "checks[$index] missing check_id"); continue)
        haskey(by_id, id) && push!(duplicates, id)
        by_id[id] = item
        status = item isa AbstractDict ? String(get(item, "status", "unknown")) : "unknown"
        status in _V55_ALLOWED_CHECK_STATES || push!(structural_errors, "$id has invalid status")
        status == "fail" && push!(explicit_failures, "$id failed")
        status in ("unknown", "unsupported") && push!(unresolved, "$id status=$status")
        if status == "not_applicable"
            isempty(String(get(item, "applicability_basis", ""))) &&
                push!(structural_errors, "$id not_applicable lacks applicability_basis")
        elseif status == "pass"
            margin = _v55_float(item, "normalized_margin")
            !isfinite(margin) && push!(unresolved, "$id lacks a numeric margin")
            isfinite(margin) && margin < 0.0 && push!(explicit_failures, "$id margin is negative")
        end
        isempty(_v55_evidence_refs(item)) && push!(unresolved, "$id lacks evidence_refs")
    end
    missing = sort!(collect(setdiff(_V55_REQUIRED_ENGINEERING_CHECKS, Set(keys(by_id)))))
    missing_refs = _v55_missing_evidence_refs(checks_in, evidence_ids)
    checks = [
        _v55_check("complete_engineering_checklist",
            !isempty(duplicates) ? "fail" : isempty(missing) ? "pass" : "unknown",
            "the identical engineering checklist applies to every candidate";
            details = Dict("missing_checks" => missing, "duplicate_checks" => duplicates)),
        _v55_check("engineering_limits_and_applicability",
            !isempty(structural_errors) || !isempty(explicit_failures) ? "fail" :
                isempty(checks_in) || !isempty(unresolved) ? "unknown" : "pass",
            "each applicable check needs a nonnegative margin; N/A needs an explicit basis";
            details = Dict("structural_errors" => structural_errors,
                "explicit_failures" => explicit_failures, "unresolved" => unresolved)),
        _v55_check("engineering_evidence_bindings", isempty(missing_refs) ? "pass" : "unknown",
            "engineering evidence references must resolve";
            details = Dict("missing_evidence_refs" => missing_refs)),
    ]
    return _v55_stage(UNIFIED_JUDGMENT_STAGE_IDS_V55[7], checks)
end

function _v55_uncertainty_stage(record, evidence_ids, evidence_errors)
    uncertainty = get(record, "uncertainty_evidence", Dict{String,Any}())
    checks_in = uncertainty isa AbstractDict ? _v55_collection(uncertainty, "checks") : Any[]
    by_id = Dict{String,Any}()
    structural_errors = String[]
    explicit_failures = String[]
    unresolved = String[]
    duplicates = String[]
    for (index, item) in enumerate(checks_in)
        id = _v55_string_id(item, ("check_id",))
        isempty(id) && (push!(structural_errors, "checks[$index] missing check_id"); continue)
        haskey(by_id, id) && push!(duplicates, id)
        by_id[id] = item
        status = item isa AbstractDict ? String(get(item, "status", "unknown")) : "unknown"
        status in _V55_ALLOWED_CHECK_STATES || push!(structural_errors, "$id has invalid status")
        status == "fail" && push!(explicit_failures, "$id failed")
        status in ("unknown", "unsupported", "not_applicable") &&
            push!(unresolved, "$id status=$status")
        isempty(_v55_evidence_refs(item)) && push!(unresolved, "$id lacks evidence_refs")
    end
    missing = sort!(collect(setdiff(_V55_REQUIRED_UNCERTAINTY_CHECKS, Set(keys(by_id)))))
    missing_refs = _v55_missing_evidence_refs(checks_in, evidence_ids)
    checks = [
        _v55_check("complete_uncertainty_and_validation_suite",
            !isempty(duplicates) ? "fail" : isempty(missing) ? "pass" : "unknown",
            "perturbations, tolerances, model error, convergence, cross-code, and experiment are mandatory";
            details = Dict("missing_checks" => missing, "duplicate_checks" => duplicates)),
        _v55_check("all_promotion_uncertainties_resolved",
            !isempty(structural_errors) || !isempty(explicit_failures) ? "fail" :
                isempty(checks_in) || !isempty(unresolved) ? "unknown" : "pass",
            "unknown, unsupported, or failed uncertainty evidence blocks chain pass";
            details = Dict("structural_errors" => structural_errors,
                "explicit_failures" => explicit_failures, "unresolved" => unresolved)),
        _v55_check("evidence_manifest_integrity",
            !isempty(evidence_errors) ? "fail" :
                !isempty(missing_refs) || isempty(evidence_ids) ? "unknown" : "pass",
            "all evidence must have a unique ID, artifact hash, class, and resolving reference";
            details = Dict("manifest_errors" => evidence_errors,
                "missing_evidence_refs" => missing_refs)),
    ]
    return _v55_stage(UNIFIED_JUDGMENT_STAGE_IDS_V55[8], checks)
end

"Evaluate every candidate with one fixed eight-stage chain; labels and parents are non-routing metadata."
function evaluate_uniform_judgment_v55(value)
    record = _v55_record(value)
    evidence_ids, evidence_errors = _v55_evidence_index(record)
    stages = Dict{String,Any}[
        _v55_description_stage(record),
        _v55_topology_stage(record),
        _v55_state_stage(record),
        _v55_stability_stage(record, evidence_ids),
        _v55_transport_stage(record),
        _v55_net_energy_stage(record),
        _v55_engineering_stage(record, evidence_ids),
        _v55_uncertainty_stage(record, evidence_ids, evidence_errors),
    ]
    stage_ids = Tuple(String(stage["stage_id"]) for stage in stages)
    stage_ids == UNIFIED_JUDGMENT_STAGE_IDS_V55 ||
        error("v55 internal error: judgment chain order changed")
    states = String[String(stage["status"]) for stage in stages]
    decision = any(==("fail"), states) ? "fail" :
        all(==("pass"), states) ? "pass" : "unknown"
    non_routing_fields = sort!(unique(_v55_observed_non_routing_fields!(String[], record)))
    routing_projection = _v55_non_routing_projection(record)
    routing_hash = canonical_hash(routing_projection)
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "chain_id" => "uniform_fusion_judgment_chain_v55",
        "candidate_id" => String(get(record, "candidate_id", "unknown")),
        "mission_id" => String(get(get(record, "mission", Dict{String,Any}()), "mission_id", "unknown")),
        "stage_order" => collect(UNIFIED_JUDGMENT_STAGE_IDS_V55),
        "stages" => stages,
        "decision" => decision,
        "passed_stage_count" => count(==("pass"), states),
        "failed_stage_ids" => String[stage["stage_id"] for stage in stages if stage["status"] == "fail"],
        "unknown_stage_ids" => String[stage["stage_id"] for stage in stages if stage["status"] == "unknown"],
        "routing_input_hash" => routing_hash,
        "non_routing_fields_observed" => non_routing_fields,
        "family_or_parent_used_for_routing" => false,
        "all_eight_stages_executed" => length(stages) == 8,
        "eligible_for_promotion_review" => decision == "pass",
        "promotion_authorized" => false,
        "claim_boundary" => _V55_CLAIM_BOUNDARY,
    )
end

"Erase labels and lineage metadata, preserving every judgment input."
function erase_judgment_labels_v55(value)
    return _v55_non_routing_projection(_v55_record(value))
end

"No prefilter is permitted: input and evaluated candidate counts must be identical."
function evaluate_all_search_results_v55(values)
    inputs = collect(values)
    results = evaluate_uniform_judgment_v55.(inputs)
    length(results) == length(inputs) || error("v55 dropped a search result")
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "chain_id" => "uniform_fusion_judgment_chain_v55",
        "input_candidate_count" => length(inputs),
        "evaluated_candidate_count" => length(results),
        "dropped_candidate_count" => 0,
        "results" => results,
        "summary" => Dict(
            "pass_count" => count(result -> result["decision"] == "pass", results),
            "fail_count" => count(result -> result["decision"] == "fail", results),
            "unknown_count" => count(result -> result["decision"] == "unknown", results),
            "family_or_parent_routed_count" => count(result ->
                result["family_or_parent_used_for_routing"] === true, results),
            "promotion_authorized_count" => count(result ->
                result["promotion_authorized"] === true, results),
        ),
        "claim_boundary" => _V55_CLAIM_BOUNDARY,
    )
end
