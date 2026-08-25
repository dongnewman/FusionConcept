"Result of the minimal trusted compilation kernel."
struct OpenWorldCompilationV2
    genome::OpenWorldGenomeV2
    ruleset_hash::String
    coverage_hash::String
    errors::Vector{String}
    warnings::Vector{String}
    unknowns::Vector{Dict{String,Any}}
    obligation_graph::Dict{String,Any}
    assessments::Dict{String,Any}
    evaluation_hash::String
end

const _OWV2_REQUIRED_TOP_LEVEL = [
    "schema_version", "identity", "provenance", "mission_contracts", "governance_policy_ref",
    "spacetime_support", "domains", "state_variables", "interactions", "boundaries",
    "reservoirs", "invariants", "observables", "unknowns", "evidence_obligation_graph",
    "promotion_scopes", "classifications", "equivalence_claims", "extensions",
]
const _OWV2_ASSESSMENT_STATES = Set(["pass", "fail", "unknown", "unsupported", "not_applicable"])
const _OWV2_FAILURE_SCOPES = Set(["parameter_instance", "parameter_region", "control_policy",
    "closure_model", "interaction_hypothesis", "topology_skeleton", "mission_contract",
    "numerical_method", "coupling_contract"])
const _OWV2_GATE_ORDER = Dict("none" => 0, "C0" => 1, "C1" => 2, "C2" => 3, "C3" => 4)

function _owv2_ids(data)
    definitions = Set{String}()
    for (collection, id_key) in (("domains", "domain_id"), ("state_variables", "state_id"),
            ("interactions", "interaction_id"), ("boundaries", "boundary_id"),
            ("reservoirs", "reservoir_id"), ("observables", "observable_id"),
            ("actuators", "actuator_id"), ("sensors", "sensor_id"), ("controls", "control_id"))
        for item in get(data, collection, Any[])
            haskey(item, id_key) && push!(definitions, String(item[id_key]))
        end
    end
    return definitions
end

function _owv2_add_obligation!(obligations, unknowns, subject, kind, level, action; reason = kind)
    index = length(obligations) + 1
    unknown_id = "unknown_$(lpad(index, 4, '0'))"
    obligation_id = "obligation_$(lpad(index, 4, '0'))"
    push!(unknowns, Dict{String,Any}(
        "unknown_id" => unknown_id, "subject_refs" => Any[String(subject)], "kind" => String(kind),
        "impact_scope" => String(subject), "risk_class" => level == "C0" ? "gate_blocking" : "evidence_gap",
        "obligation_refs" => Any[obligation_id], "reason" => String(reason),
    ))
    push!(obligations, Dict{String,Any}(
        "obligation_id" => obligation_id, "unknown_refs" => Any[unknown_id], "level" => String(level),
        "activation_predicate" => "generated_by_trusted_kernel", "assessment_scope" => String(subject),
        "mandatory_for_missions" => Any[], "required_data_products" => Any[],
        "acceptable_evidence_classes" => Any["analytic", "numerical", "experimental", "expert_review"],
        "discrimination_requirement" => "resolve:$kind", "calibration_requirements" => Any[],
        "uncertainty_requirement" => "bounded", "promotion_scope_required" => level,
        "failure_scope_options" => Any["closure_model", "interaction_hypothesis"],
        "applicability_proof_ref" => nothing, "dependencies" => Any[], "resolution_value" => 1.0,
        "status" => "unknown", "evidence_refs" => Any[], "next_action_refs" => Any[String(action)],
        "termination_conditions" => Any["pass", "fail", "unsupported"],
    ))
end

function _owv2_validate_partial_operator!(errors, warnings, unknowns, obligations, interaction)
    id = String(get(interaction, "interaction_id", "unknown_interaction"))
    spec = get(interaction, "operator_spec", Dict{String,Any}())
    String(get(spec, "form", "")) == "partial_operator" || return
    required = ["inputs", "outputs", "domain_and_time_scope", "dimension_signature", "causal_direction",
        "allowed_conservation_effects", "forbidden_conservation_effects", "parameter_bounds", "scale_bounds",
        "symmetry_or_limit_constraints", "null_models", "alternative_models", "identifiability_conditions",
        "minimum_effect_size", "noise_and_numerical_floor", "complexity_budget", "out_of_sample_prediction_refs",
        "failure_scope_options", "safety_limits", "completion_routes", "promotion_scope_ref"]
    missing = String[key for key in required if !haskey(spec, key)]
    isempty(missing) || push!(errors, "partial operator $id missing $(join(missing, ", "))")
    for (key, action) in (("null_models", "define_null_model"), ("alternative_models", "define_alternative_model"),
            ("identifiability_conditions", "design_identifiability_intervention"),
            ("out_of_sample_prediction_refs", "define_out_of_sample_prediction"))
        isempty(get(spec, key, Any[])) && _owv2_add_obligation!(obligations, unknowns, id,
            key == "identifiability_conditions" ? "missing_observable" : "missing_closure", "C0", action)
    end
    effect = get(spec, "minimum_effect_size", nothing)
    floor = get(spec, "noise_and_numerical_floor", nothing)
    if effect isa Number && floor isa Number
        effect > floor || push!(errors, "partial operator $id minimum effect does not exceed noise and numerical floor")
    elseif effect isa AbstractDict && floor isa AbstractDict && haskey(effect, "value") && haskey(floor, "value")
        get(effect, "unit", nothing) == get(floor, "unit", nothing) ||
            push!(errors, "partial operator $id effect and floor units differ")
        Float64(effect["value"]) > Float64(floor["value"]) ||
            push!(errors, "partial operator $id minimum effect does not exceed noise and numerical floor")
    else
        _owv2_add_obligation!(obligations, unknowns, id, "missing_observable", "C0", "quantify_effect_and_floor";
            reason = "minimum effect and noise floor are not directly comparable")
    end
    budget = get(spec, "complexity_budget", Dict{String,Any}())
    for key in ("max_free_parameters", "max_free_functions", "max_memory_length", "max_suboperators")
        haskey(budget, key) || push!(warnings, "partial operator $id complexity budget omits $key")
    end
end

function validate_promotion_scope_v1(scope; ruleset_hash = nothing)
    item = _plain_json(scope)
    errors = String[]
    required = ["scope_id", "max_gate", "valid_missions", "valid_domains", "valid_parameter_ranges",
        "valid_observables", "calibration_refs", "required_ruleset_hash", "independent_confirmation_required",
        "expiry_or_version"]
    for key in required
        haskey(item, key) || push!(errors, "PromotionScope missing $key")
    end
    haskey(item, "max_gate") && !haskey(_OWV2_GATE_ORDER, String(item["max_gate"])) &&
        push!(errors, "invalid promotion max_gate $(item["max_gate"])")
    if ruleset_hash !== nothing && haskey(item, "required_ruleset_hash")
        declared = String(item["required_ruleset_hash"])
        declared in ("pending", String(ruleset_hash)) || push!(errors, "promotion scope ruleset hash mismatch")
    end
    return errors
end

function validate_failure_record_v1(value)
    item = _plain_json(value)
    errors = String[]
    required = ["failure_id", "failed_obligation_ids", "scope_type", "scope_refs", "excluded_alternatives",
        "tuning_budget_consumed", "evidence_refs", "ruleset_hash", "escalation_conditions"]
    for key in required
        haskey(item, key) || push!(errors, "FailureRecord missing $key")
    end
    haskey(item, "scope_type") && !(String(item["scope_type"]) in _OWV2_FAILURE_SCOPES) &&
        push!(errors, "invalid failure scope $(item["scope_type"])")
    if get(item, "scope_type", "") == "topology_skeleton"
        isempty(get(item, "excluded_alternatives", Any[])) && push!(errors, "topology failure requires excluded alternatives")
        Float64(get(item, "tuning_budget_consumed", 0.0)) > 0 || push!(errors, "topology failure requires consumed tuning budget")
    end
    return errors
end

function compile_open_world_genome_v2(value;
        rules = default_open_world_physics_rules_v1(),
        coverage = default_open_world_rule_coverage_v1(rules),
        mission_id = nothing)
    genome = value isa OpenWorldGenomeV2 ? value : parse_open_world_genome_v2(value)
    data = genome.data
    errors = String[]
    warnings = String[]
    for key in _OWV2_REQUIRED_TOP_LEVEL
        haskey(data, key) || push!(errors, "OpenWorldGenomeV2 missing $key")
    end
    get(data, "schema_version", nothing) == "2.0.0" || push!(errors, "unsupported OTG schema version")
    haskey(data, "family") && push!(errors, "family is prohibited as a core routing field")
    for classification in get(data, "classifications", Any[])
        get(classification, "non_routing", false) === true || push!(errors, "classification must declare non_routing=true")
    end
    for rule in rules
        append!(errors, validate_physics_rule_manifest_v1(rule))
    end
    append!(errors, validate_rule_coverage_manifest_v1(coverage))
    ruleset_hash = open_world_ruleset_hash_v1(rules)
    String(get(coverage, "ruleset_hash", "")) == ruleset_hash || push!(errors, "coverage manifest ruleset hash mismatch")

    obligations = Dict{String,Any}[]
    graph = get(data, "evidence_obligation_graph", Dict{String,Any}())
    for item in get(graph, "obligations", Any[])
        push!(obligations, Dict{String,Any}(String(k) => _plain_json(v) for (k, v) in item))
    end
    unknowns = Dict{String,Any}[]
    for item in get(data, "unknowns", Any[])
        push!(unknowns, Dict{String,Any}(String(k) => _plain_json(v) for (k, v) in item))
    end

    ids = _owv2_ids(data)
    length(ids) == sum(length(get(data, collection, Any[])) for collection in
        ("domains", "state_variables", "interactions", "boundaries", "reservoirs", "observables", "actuators", "sensors", "controls")) ||
        push!(errors, "core object IDs are missing or duplicated")
    domain_ids = Set(String(get(item, "domain_id", "")) for item in get(data, "domains", Any[]))
    for interaction in get(data, "interactions", Any[])
        id = String(get(interaction, "interaction_id", "unknown_interaction"))
        for ref in get(interaction, "affected_domains", Any[])
            String(ref) in domain_ids || push!(errors, "interaction $id references missing domain $ref")
        end
        haskey(interaction, "conservation_effects") || _owv2_add_obligation!(obligations, unknowns, id,
            "missing_conservation_path", "C0", "declare_conservation_effects")
        _owv2_validate_partial_operator!(errors, warnings, unknowns, obligations, interaction)
    end

    for gap in open_world_coverage_gaps_v1(genome, coverage)
        _owv2_add_obligation!(obligations, unknowns, gap["subject_ref"], "ruleset_coverage_gap", "C0",
            "extend_ruleset_or_route_expert_review"; reason = gap["reason"])
    end
    for scope in get(data, "promotion_scopes", Any[])
        append!(errors, validate_promotion_scope_v1(scope; ruleset_hash = ruleset_hash))
    end
    scopes = Dict(String(get(scope, "scope_id", "")) => scope for scope in get(data, "promotion_scopes", Any[]))
    for interaction in get(data, "interactions", Any[])
        epistemic = String(get(interaction, "epistemic_state", "unknown_placeholder"))
        scope_ref = String(get(interaction, "promotion_scope_ref", ""))
        if epistemic in ("empirical_prior", "learned") && haskey(scopes, scope_ref)
            max_gate = String(get(scopes[scope_ref], "max_gate", "none"))
            epistemic == "empirical_prior" && max_gate != "none" &&
                push!(errors, "empirical prior $(get(interaction, "interaction_id", "")) exceeds max_gate=none")
        end
    end

    mandatory_c0_unknown = any(item -> get(item, "level", "") == "C0" &&
        get(item, "status", "unknown") == "unknown", obligations)
    c0_status = !isempty(errors) ? "fail" : mandatory_c0_unknown ? "unknown" : "pass"
    c1_status = c0_status == "pass" ? "unsupported" : "unknown"
    assessments = Dict{String,Any}(
        "C0" => Dict("status" => c0_status, "assessment_scope" => "candidate",
            "ruleset_hash" => ruleset_hash, "evidence_refs" => Any[], "promotion_scope_ref" => nothing,
            "failure_scope" => isempty(errors) ? nothing : "parameter_instance"),
        "C1" => Dict("status" => c1_status, "assessment_scope" => "candidate",
            "ruleset_hash" => ruleset_hash, "evidence_refs" => Any[], "promotion_scope_ref" => nothing,
            "failure_scope" => nothing),
    )
    obligation_graph = Dict{String,Any}(
        "obligations" => obligations, "dependencies" => get(graph, "dependencies", Any[]),
        "shared_evidence_correlations" => get(graph, "shared_evidence_correlations", Any[]),
    )
    coverage_hash = canonical_hash(coverage)
    evaluation_hash = canonical_hash(Dict(
        "identity_hash" => genome.identity_hash, "structural_hash" => genome.structural_hash,
        "ruleset_hash" => ruleset_hash, "coverage_hash" => coverage_hash,
        "mission_id" => mission_id, "obligation_graph" => obligation_graph,
    ))
    return OpenWorldCompilationV2(genome, ruleset_hash, coverage_hash, errors, warnings,
        unknowns, obligation_graph, assessments, evaluation_hash)
end

function open_world_compilation_to_dict_v2(result::OpenWorldCompilationV2)
    return Dict{String,Any}(
        "report_schema" => "open_world_compilation_report_v2",
        "identity_hash" => result.genome.identity_hash,
        "structural_hash" => result.genome.structural_hash,
        "semantic_normal_form_hash" => result.genome.semantic_normal_form_hash,
        "behavioral_signature_hash" => result.genome.behavioral_signature_hash,
        "ruleset_hash" => result.ruleset_hash, "coverage_hash" => result.coverage_hash,
        "evaluation_hash" => result.evaluation_hash, "errors" => result.errors,
        "warnings" => result.warnings, "unknowns" => result.unknowns,
        "evidence_obligation_graph" => result.obligation_graph,
        "assessments" => result.assessments,
        "claim_limits" => Any[
            "C0/C1 result does not establish net energy, buildability, or reactor readiness",
            "coverage gaps are unknowns, never passes",
        ],
    )
end

