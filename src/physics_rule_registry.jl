const OPEN_WORLD_RULE_CHECK_MODES_V1 = Set([
    "static", "symbolic", "numerical", "experimental", "expert_review",
])

function _open_world_rule_v1(rule_id, rule_class, activation_predicate, generated_obligations;
        failure_scope_options = Any["parameter_instance"],
        promotion_scope_ceiling = "C0")
    return Dict{String,Any}(
        "rule_id" => String(rule_id), "version" => "1.0.0",
        "rule_class" => String(rule_class),
        "activation_predicate" => String(activation_predicate),
        "assumptions" => Any[], "check_mode" => "static",
        "inputs" => Any["OpenWorldGenomeV2"], "outputs" => Any["assessment", "obligations"],
        "generated_obligations" => Any[generated_obligations...],
        "pass_conditions" => Any["all activated checks pass"],
        "failure_scope_options" => Any[failure_scope_options...],
        "evidence_requirements" => Any[], "applicability_proof_requirements" => Any[],
        "regression_fixtures" => Any[], "promotion_scope_ceiling" => promotion_scope_ceiling,
        "provenance" => Dict("authority" => "FusionConceptAI", "status" => "minimal_trusted_kernel"),
    )
end

"Versioned R1 rule set. It is deliberately small and reports its coverage gaps."
function default_open_world_physics_rules_v1()
    return Any[
        _open_world_rule_v1("ow.schema.core", "type_and_reference", "always", ["repair_schema"]),
        _open_world_rule_v1("ow.references.integrity", "type_and_reference", "always", ["repair_references"]),
        _open_world_rule_v1("ow.conservation.accounts", "conservation", "interactions_present", ["close_conservation_accounts"];
            failure_scope_options = Any["interaction_hypothesis", "closure_model"]),
        _open_world_rule_v1("ow.partial_operator.discrimination", "observability", "partial_operator_present",
            ["establish_detectability", "establish_distinguishability", "establish_identifiability"];
            failure_scope_options = Any["interaction_hypothesis", "closure_model"]),
        _open_world_rule_v1("ow.promotion.scope", "promotion_authority", "evidence_or_models_present", ["repair_promotion_scope"];
            failure_scope_options = Any["mission_contract"]),
        _open_world_rule_v1("ow.coverage.explicit", "model_applicability", "always", ["acquire_coverage_evidence"];
            failure_scope_options = Any["closure_model"], promotion_scope_ceiling = "none"),
    ]
end

open_world_ruleset_hash_v1(rules = default_open_world_physics_rules_v1()) = canonical_hash(rules)

function validate_physics_rule_manifest_v1(rule)
    item = _plain_json(rule)
    errors = String[]
    required = ["rule_id", "version", "rule_class", "activation_predicate", "assumptions",
        "check_mode", "inputs", "outputs", "generated_obligations", "pass_conditions",
        "failure_scope_options", "evidence_requirements", "applicability_proof_requirements",
        "regression_fixtures", "promotion_scope_ceiling", "provenance"]
    for key in required
        haskey(item, key) || push!(errors, "PhysicsRuleManifest missing $key")
    end
    haskey(item, "check_mode") && !(String(item["check_mode"]) in OPEN_WORLD_RULE_CHECK_MODES_V1) &&
        push!(errors, "unsupported rule check_mode $(item["check_mode"])")
    return errors
end

