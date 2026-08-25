const _STABILITY_APPLICABILITY_STATUSES_V1 = Set((:active, :inactive, :unknown))
const _STABILITY_EVIDENCE_STATUSES_V1 = Set((:pass, :fail, :unknown))
const _STABILITY_SOURCE_KINDS_V1 = Set((:candidate_solver, :measured,
    :manufactured, :structural_declaration, :screening))

"Candidate-bound physical features used to decide which stability questions exist."
struct StabilityFeatureEvidenceV1
    design_id::String
    genome_physics_hash::String
    topology_signature_hash::String
    features::Dict{String,Union{Nothing,Bool}}
    derivations::Dict{String,String}
    source_kind::Symbol
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    candidate_binding_verified::Bool
    fidelity::Int
    evidence_tasks::Vector{String}
    feature_hash::String
end

"A device-label-independent rule for deciding whether one physical mode applies."
struct StabilityModeRuleV1
    mode_id::String
    physics_class::String
    required_true_features::Vector{String}
    evaluation_input_ids::Vector{String}
    minimum_fidelity::Int
    activation_rule::String
    claim_boundary::String
    source_ids::Vector{String}
end

struct StabilityModeApplicabilityV1
    mode_id::String
    status::Symbol
    satisfied_feature_ids::Vector{String}
    false_feature_ids::Vector{String}
    unknown_feature_ids::Vector{String}
    missing_evaluation_input_ids::Vector{String}
    reason::String
    applicability_hash::String

    function StabilityModeApplicabilityV1(mode_id, status, satisfied, false_ids,
            unknown, missing, reason, applicability_hash)
        status in _STABILITY_APPLICABILITY_STATUSES_V1 ||
            throw(ArgumentError("invalid stability applicability status $status"))
        return new(String(mode_id), status, sort!(unique(String.(satisfied))),
            sort!(unique(String.(false_ids))), sort!(unique(String.(unknown))),
            sort!(unique(String.(missing))), String(reason),
            String(applicability_hash))
    end
end

"One exact, mode-specific solver observation; it never represents all-mode stability."
struct StabilityModeEvidenceV1
    design_id::String
    genome_physics_hash::String
    mode_id::String
    solver_id::String
    source_kind::Symbol
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    candidate_binding_verified::Bool
    favorable::Union{Nothing,Bool}
    normalized_margin::Union{Nothing,Float64}
    fidelity::Int
    minimum_fidelity::Int
    resolution_verified::Bool
    status::Symbol
    mode_support_authorized::Bool
    covered_input_ids::Vector{String}
    constraints_checked::Vector{String}
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    evidence_hash::String
end

"Fail-closed inventory of applicable, unknown, evaluated, and missing stability modes."
struct StabilityModeInventoryV1
    design_id::String
    genome_physics_hash::String
    feature_hash::String
    registry_hash::String
    applicability::Vector{StabilityModeApplicabilityV1}
    mode_evidence::Vector{StabilityModeEvidenceV1}
    active_mode_ids::Vector{String}
    inactive_mode_ids::Vector{String}
    unknown_applicability_mode_ids::Vector{String}
    evaluated_active_mode_ids::Vector{String}
    favorable_active_mode_ids::Vector{String}
    failed_active_mode_ids::Vector{String}
    missing_active_mode_ids::Vector{String}
    applicability_complete::Bool
    evaluation_complete::Bool
    physical_stability_status::Symbol
    c2_support_authorized::Bool
    minimum_normalized_margin::Union{Nothing,Float64}
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    inventory_hash::String
end

function default_stability_mode_registry_v1()
    rule(id, class, required, inputs, activation, boundary, sources) =
        StabilityModeRuleV1(id, class, String.(required), String.(inputs), 2,
            activation, boundary, String.(sources))
    common_boundary = "Mode-specific linear or criterion evidence only; not nonlinear, " *
        "disruption, transport, engineering, robustness, or all-mode stability."
    return StabilityModeRuleV1[
        rule("ideal_current_driven_kink_v1", "ideal_mhd_global",
            ["closed_flux_region_present", "plasma_current_present"],
            ["equilibrium_state", "current_profile", "safety_factor_or_transform_profile"],
            "closed flux region and plasma current are both present", common_boundary,
            ["maxwell_mhd_conservation_basis"]),
        rule("resistive_tearing_v1", "resistive_mhd_global",
            ["closed_flux_region_present", "plasma_current_present"],
            ["equilibrium_state", "current_profile", "resistivity_profile"],
            "closed flux region and plasma current are both present", common_boundary,
            ["maxwell_mhd_conservation_basis"]),
        rule("pressure_curvature_interchange_v1", "ideal_mhd_interchange",
            ["confined_region_present", "finite_beta_present", "pressure_gradient_present"],
            ["equilibrium_state", "pressure_profile", "magnetic_curvature", "magnetic_shear"],
            "a confined finite-beta region has a pressure gradient", common_boundary,
            ["mercier_1954_energy_principle"]),
        rule("finite_n_global_ideal_mhd_v1", "ideal_mhd_global",
            ["closed_flux_region_present", "finite_beta_present", "pressure_gradient_present"],
            ["equilibrium_state", "pressure_profile", "global_ideal_mhd_spectrum"],
            "closed finite-beta flux region has a pressure gradient", common_boundary,
            ["ideal_mhd_energy_principle"]),
        rule("infinite_n_ideal_ballooning_v1", "ideal_mhd_local",
            ["closed_flux_region_present", "finite_beta_present", "pressure_gradient_present"],
            ["equilibrium_state", "pressure_profile", "field_line_geometry", "magnetic_shear"],
            "closed finite-beta flux region has a pressure gradient", common_boundary,
            ["desc_infinite_n_ballooning_documentation"]),
        rule("mercier_interchange_v1", "ideal_mhd_local",
            ["closed_flux_region_present", "finite_beta_present", "pressure_gradient_present",
                "nonaxisymmetric_3d_present"],
            ["equilibrium_state", "pressure_profile", "magnetic_well", "magnetic_shear"],
            "non-axisymmetric closed finite-beta flux region has a pressure gradient",
            common_boundary, ["mercier_1954_energy_principle"]),
        rule("open_field_flute_interchange_v1", "open_field_ideal_mhd",
            ["open_field_region_present", "finite_beta_present", "pressure_gradient_present"],
            ["finite_beta_state", "pressure_profile", "magnetic_curvature",
                "line_tying_or_stabilization_model"],
            "open finite-beta field region has a pressure gradient", common_boundary,
            ["wham_physics_basis_2023"]),
        rule("gradient_drift_modes_v1", "open_field_drift_kinetic",
            ["open_field_region_present", "pressure_gradient_present"],
            ["density_profile", "temperature_profile", "particle_distribution",
                "electric_field_and_flow_profile"],
            "open field region has a pressure gradient", common_boundary,
            ["wham_physics_basis_2023"]),
        rule("drift_cyclotron_loss_cone_v1", "open_field_kinetic",
            ["open_field_region_present", "loss_cone_distribution_present"],
            ["ion_distribution_function", "loss_cone_boundary", "density_gradient",
                "electron_temperature", "finite_larmor_radius"],
            "open field region has a loss-cone distribution", common_boundary,
            ["wham_physics_basis_2023"]),
        rule("alfven_ion_cyclotron_anisotropy_v1", "open_field_kinetic",
            ["open_field_region_present", "anisotropic_distribution_present"],
            ["ion_distribution_function", "pressure_anisotropy", "beta_profile",
                "cyclotron_resonance_spectrum"],
            "open field region has an anisotropic distribution", common_boundary,
            ["wham_physics_basis_2023"]),
        rule("mirror_mode_anisotropy_v1", "anisotropic_kinetic_mhd",
            ["open_field_region_present", "anisotropic_distribution_present"],
            ["pressure_tensor", "beta_parallel_profile", "beta_perpendicular_profile"],
            "open field region has an anisotropic distribution", common_boundary,
            ["anisotropic_energy_principle"]),
        rule("firehose_anisotropy_v1", "anisotropic_kinetic_mhd",
            ["open_field_region_present", "anisotropic_distribution_present"],
            ["pressure_tensor", "beta_parallel_profile", "beta_perpendicular_profile"],
            "open field region has an anisotropic distribution", common_boundary,
            ["anisotropic_energy_principle"]),
    ]
end

function stability_mode_registry_hash_v1(registry::Vector{StabilityModeRuleV1})
    payload = [Dict{String,Any}("mode_id" => item.mode_id,
        "physics_class" => item.physics_class,
        "required_true_features" => item.required_true_features,
        "evaluation_input_ids" => item.evaluation_input_ids,
        "minimum_fidelity" => item.minimum_fidelity,
        "activation_rule" => item.activation_rule,
        "claim_boundary" => item.claim_boundary,
        "source_ids" => item.source_ids) for item in sort(registry; by = x -> x.mode_id)]
    return canonical_hash(Dict("schema_version" => "1.0.0", "rules" => payload))
end

function _genome_parameter_names_v1(genome::Genome)
    names = String[]
    for region in genome.plasma_regions
        append!(names, lowercase.(collect(keys(region.parameters))))
    end
    for source in genome.field_sources
        append!(names, lowercase.(collect(keys(source.parameters))))
    end
    for actuator in genome.actuators
        append!(names, lowercase.(collect(keys(actuator.parameters))))
    end
    return names
end

function _declared_stability_text_v1(genome::Genome)
    return lowercase(join(vcat(
        [item.mechanism for item in genome.stability_mechanisms],
        [item.target_modes for item in genome.stability_mechanisms]...,
        [item.assumptions for item in genome.stability_mechanisms]...,
        [item.required_evaluators for item in genome.stability_mechanisms]...), " "))
end

"Extract only physically declared features; missing kinetic state remains nothing."
function compile_stability_feature_evidence_v1(genome::Genome;
        feature_overrides::Dict{String,Union{Nothing,Bool}} =
            Dict{String,Union{Nothing,Bool}}(),
        override_derivations::Dict{String,String} = Dict{String,String}(),
        source_kind::Symbol = :structural_declaration,
        source_artifact_id::AbstractString = "",
        source_artifact_hash::AbstractString = "",
        source_result_hash::AbstractString = "",
        candidate_binding_verified::Bool = false,
        fidelity::Integer = 0)
    source_kind in _STABILITY_SOURCE_KINDS_V1 ||
        throw(ArgumentError("invalid stability feature source kind $source_kind"))
    fidelity >= 0 || throw(ArgumentError("stability feature fidelity must be non-negative"))
    topology = _topology_descriptor_v1(genome)
    names = _genome_parameter_names_v1(genome)
    mechanism_text = _declared_stability_text_v1(genome)
    closed_present = topology.closure_class in (:closed, :mixed) &&
        topology.expected_flux_surfaces !== false
    open_present = topology.closure_class in (:open, :mixed) || topology.open_end_count > 0
    has_pressure = any(name -> occursin("pressure", name) || occursin("beta", name), names) ||
        occursin("finite-beta", mechanism_text) || occursin("finite_beta", mechanism_text)
    has_pressure_gradient = any(name -> occursin("pressure", name) &&
        any(token -> occursin(token, name), ("profile", "axis", "exponent", "power_series")), names) ||
        any(name -> occursin("pressure_exponent", name), names)
    plasma_current = "plasma_current" in topology.transform_sources ||
        any(source -> occursin("plasma_current", lowercase(source.kind)), genome.field_sources)
    scalar_pressure_only = occursin("scalar pressure", mechanism_text) ||
        occursin("isotropic", mechanism_text)
    features = Dict{String,Union{Nothing,Bool}}(
        "closed_flux_region_present" => closed_present,
        "open_field_region_present" => open_present,
        "confined_region_present" => closed_present || open_present,
        "finite_beta_present" => has_pressure ? true : nothing,
        "pressure_gradient_present" => has_pressure_gradient ? true : nothing,
        "plasma_current_present" => plasma_current,
        "nonaxisymmetric_3d_present" => topology.dimensionality in
            (:periodic_3d, :fully_3d, :general_3d),
        "anisotropic_distribution_present" => nothing,
        "loss_cone_distribution_present" => open_present ? nothing : false,
        "particle_distribution_resolved" => false,
        "magnetic_curvature_resolved" => false,
        "magnetic_shear_resolved" => false,
        "density_profile_resolved" => any(name -> occursin("density", name), names),
        "temperature_profile_resolved" => any(name -> occursin("temperature", name), names),
        "electric_field_and_flow_resolved" => false)
    derivations = Dict{String,String}(
        "closed_flux_region_present" => "field-line closure and expected flux surfaces",
        "open_field_region_present" => "field-line closure and explicit open connections",
        "confined_region_present" => "closed or open magnetic confinement region declared",
        "finite_beta_present" => has_pressure ? "pressure or beta parameter declared" :
            "no finite-beta state established",
        "pressure_gradient_present" => has_pressure_gradient ?
            "nonuniform pressure parameterization declared" : "pressure gradient not established",
        "plasma_current_present" => "transform source and magnetic source kinds",
        "nonaxisymmetric_3d_present" => "symmetry and field-period geometry",
        "anisotropic_distribution_present" => scalar_pressure_only ?
            "scalar/isotropic pressure model cannot establish the physical distribution" :
            "particle distribution not declared",
        "loss_cone_distribution_present" => open_present ?
            "open geometry alone does not determine the populated loss cone" :
            "no open field region",
        "particle_distribution_resolved" => "no candidate distribution-function product",
        "magnetic_curvature_resolved" => "no candidate curvature product",
        "magnetic_shear_resolved" => "no candidate shear product",
        "density_profile_resolved" => "Genome parameter declaration",
        "temperature_profile_resolved" => "Genome parameter declaration",
        "electric_field_and_flow_resolved" => "no candidate electric-field/flow product")
    for (id, value) in feature_overrides
        haskey(features, id) || throw(ArgumentError("unknown stability feature override $id"))
        features[id] = value
        derivations[id] = get(override_derivations, id, "explicit candidate-bound override")
    end
    tasks = String[]
    for id in ("finite_beta_present", "pressure_gradient_present")
        features[id] === nothing && push!(tasks, "resolve_stability_feature:$id")
    end
    if open_present
        for id in ("anisotropic_distribution_present", "loss_cone_distribution_present")
            features[id] === nothing && push!(tasks, "resolve_stability_feature:$id")
        end
    end
    candidate_binding_verified || push!(tasks, "verify_candidate_binding")
    isempty(source_artifact_id) && push!(tasks, "provide_source_artifact_id")
    isempty(source_artifact_hash) && push!(tasks, "provide_source_artifact_hash")
    isempty(source_result_hash) && push!(tasks, "provide_source_result_hash")
    topology_signature = canonical_hash(Dict{String,Any}(
        "closure_class" => String(topology.closure_class),
        "dimensionality" => String(topology.dimensionality),
        "symmetry_class" => topology.symmetry_class,
        "field_periods" => topology.field_periods,
        "expected_flux_surfaces" => topology.expected_flux_surfaces,
        "expected_separatrix" => topology.expected_separatrix,
        "open_end_count" => topology.open_end_count,
        "transform_sources" => topology.transform_sources,
        "field_source_kinds" => topology.field_source_kinds,
        "plasma_region_kinds" => topology.plasma_region_kinds))
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "design_id" => genome.design_id, "genome_physics_hash" => genome.physics_hash,
        "topology_signature_hash" => topology_signature, "features" => features,
        "derivations" => derivations, "source_kind" => String(source_kind),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "fidelity" => Int(fidelity), "evidence_tasks" => sort!(unique(tasks)))
    return StabilityFeatureEvidenceV1(genome.design_id, genome.physics_hash,
        topology_signature, features, derivations, source_kind,
        String(source_artifact_id), String(source_artifact_hash),
        String(source_result_hash), candidate_binding_verified, Int(fidelity),
        sort!(unique(tasks)), canonical_hash(core))
end

function stability_feature_evidence_to_dict_v1(item::StabilityFeatureEvidenceV1)
    return Dict{String,Any}("design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "topology_signature_hash" => item.topology_signature_hash,
        "features" => item.features, "derivations" => item.derivations,
        "source_kind" => String(item.source_kind),
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "fidelity" => item.fidelity, "evidence_tasks" => item.evidence_tasks,
        "feature_hash" => item.feature_hash)
end

function _mode_applicability_v1(rule::StabilityModeRuleV1,
        feature::StabilityFeatureEvidenceV1)
    satisfied = String[]
    false_ids = String[]
    unknown = String[]
    for id in rule.required_true_features
        value = get(feature.features, id, nothing)
        value === true ? push!(satisfied, id) :
            value === false ? push!(false_ids, id) : push!(unknown, id)
    end
    status = !isempty(false_ids) ? :inactive : !isempty(unknown) ? :unknown : :active
    missing = status == :active ? copy(rule.evaluation_input_ids) : String[]
    reason = status == :active ? "all physical activation features are present" :
        status == :inactive ? "at least one required physical feature is absent" :
        "one or more physical activation features are unresolved"
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "feature_hash" => feature.feature_hash, "mode_id" => rule.mode_id,
        "status" => String(status), "satisfied_feature_ids" => satisfied,
        "false_feature_ids" => false_ids, "unknown_feature_ids" => unknown,
        "missing_evaluation_input_ids" => missing, "reason" => reason)
    return StabilityModeApplicabilityV1(rule.mode_id, status, satisfied,
        false_ids, unknown, missing, reason, canonical_hash(core))
end

function compile_stability_mode_evidence_v1(genome::Genome,
        rule::StabilityModeRuleV1; solver_id::AbstractString,
        source_kind::Symbol, source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString, source_result_hash::AbstractString,
        candidate_binding_verified::Bool,
        favorable::Union{Nothing,Bool} = nothing,
        normalized_margin::Union{Nothing,Real} = nothing,
        fidelity::Integer, resolution_verified::Bool,
        covered_input_ids::Vector{String} = String[],
        constraints_checked::Vector{String} = String[],
        warnings::Vector{String} = String[])
    source_kind in _STABILITY_SOURCE_KINDS_V1 ||
        throw(ArgumentError("invalid stability evidence source kind $source_kind"))
    fidelity >= 0 || throw(ArgumentError("stability evidence fidelity must be non-negative"))
    margin = normalized_margin === nothing ? nothing : Float64(normalized_margin)
    margin === nothing || isfinite(margin) ||
        throw(ArgumentError("stability margin must be finite or nothing"))
    tasks = String[]
    candidate_binding_verified || push!(tasks, "verify_candidate_binding")
    isempty(source_artifact_id) && push!(tasks, "provide_source_artifact_id")
    isempty(source_artifact_hash) && push!(tasks, "provide_source_artifact_hash")
    isempty(source_result_hash) && push!(tasks, "provide_source_result_hash")
    favorable === nothing && push!(tasks, "evaluate_mode:$(rule.mode_id)")
    margin === nothing && push!(tasks, "provide_signed_normalized_margin:$(rule.mode_id)")
    resolution_verified || push!(tasks, "run_mode_resolution_convergence:$(rule.mode_id)")
    fidelity < rule.minimum_fidelity && push!(tasks,
        "raise_mode_fidelity:$(rule.mode_id):$(rule.minimum_fidelity)")
    source_kind in (:manufactured, :structural_declaration, :screening) &&
        push!(tasks, "replace_nonphysical_mode_source:$(rule.mode_id)")
    covered = sort!(unique(copy(covered_input_ids)))
    missing_inputs = sort!(setdiff(rule.evaluation_input_ids, covered))
    append!(tasks, ["provide_mode_input:$(rule.mode_id):$id" for id in missing_inputs])
    provenance_complete = !isempty(source_artifact_id) &&
        !isempty(source_artifact_hash) && !isempty(source_result_hash)
    authoritative = candidate_binding_verified && provenance_complete &&
        favorable !== nothing && margin !== nothing && resolution_verified &&
        fidelity >= rule.minimum_fidelity && isempty(missing_inputs) &&
        source_kind in (:candidate_solver, :measured)
    status = authoritative ? (favorable === true && margin >= 0 ? :pass : :fail) : :unknown
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "design_id" => genome.design_id, "genome_physics_hash" => genome.physics_hash,
        "mode_id" => rule.mode_id, "solver_id" => String(solver_id),
        "source_kind" => String(source_kind),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "favorable" => favorable, "normalized_margin" => margin,
        "fidelity" => Int(fidelity), "minimum_fidelity" => rule.minimum_fidelity,
        "resolution_verified" => resolution_verified, "status" => String(status),
        "mode_support_authorized" => authoritative,
        "covered_input_ids" => covered,
        "constraints_checked" => sort!(unique(copy(constraints_checked))),
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return StabilityModeEvidenceV1(genome.design_id, genome.physics_hash,
        rule.mode_id, String(solver_id), source_kind, String(source_artifact_id),
        String(source_artifact_hash), String(source_result_hash),
        candidate_binding_verified, favorable, margin, Int(fidelity),
        rule.minimum_fidelity, resolution_verified, status, authoritative,
        covered, sort!(unique(copy(constraints_checked))), sort!(unique(tasks)),
        copy(warnings), canonical_hash(core))
end

function stability_mode_evidence_to_dict_v1(item::StabilityModeEvidenceV1)
    return Dict{String,Any}("design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "mode_id" => item.mode_id, "solver_id" => item.solver_id,
        "source_kind" => String(item.source_kind),
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "favorable" => item.favorable,
        "normalized_margin" => item.normalized_margin,
        "fidelity" => item.fidelity, "minimum_fidelity" => item.minimum_fidelity,
        "resolution_verified" => item.resolution_verified,
        "status" => String(item.status),
        "mode_support_authorized" => item.mode_support_authorized,
        "covered_input_ids" => item.covered_input_ids,
        "constraints_checked" => item.constraints_checked,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "evidence_hash" => item.evidence_hash)
end

function compile_stability_mode_inventory_v1(genome::Genome,
        feature::StabilityFeatureEvidenceV1,
        evidence::Vector{StabilityModeEvidenceV1} = StabilityModeEvidenceV1[];
        registry::Vector{StabilityModeRuleV1} = default_stability_mode_registry_v1())
    feature.design_id == genome.design_id || throw(ArgumentError(
        "stability feature design mismatch"))
    feature.genome_physics_hash == genome.physics_hash || throw(ArgumentError(
        "stability feature Genome hash mismatch"))
    rule_ids = getfield.(registry, :mode_id)
    length(unique(rule_ids)) == length(rule_ids) || throw(ArgumentError(
        "stability registry mode IDs must be unique"))
    evidence_by_mode = Dict{String,StabilityModeEvidenceV1}()
    for item in evidence
        item.design_id == genome.design_id || throw(ArgumentError(
            "stability mode evidence design mismatch"))
        item.genome_physics_hash == genome.physics_hash || throw(ArgumentError(
            "stability mode evidence Genome hash mismatch"))
        item.mode_id in rule_ids || throw(ArgumentError(
            "stability mode evidence references an unknown mode"))
        haskey(evidence_by_mode, item.mode_id) && throw(ArgumentError(
            "duplicate stability evidence for $(item.mode_id)"))
        evidence_by_mode[item.mode_id] = item
    end
    applicability = [_mode_applicability_v1(rule, feature) for rule in registry]
    sort!(applicability; by = x -> x.mode_id)
    active = sort!(String[item.mode_id for item in applicability if item.status == :active])
    inactive = sort!(String[item.mode_id for item in applicability if item.status == :inactive])
    unknown = sort!(String[item.mode_id for item in applicability if item.status == :unknown])
    evaluated = sort!(String[id for id in active if haskey(evidence_by_mode, id) &&
        evidence_by_mode[id].mode_support_authorized])
    favorable = sort!(String[id for id in evaluated if evidence_by_mode[id].status == :pass])
    failed = sort!(String[id for id in evaluated if evidence_by_mode[id].status == :fail])
    missing = sort!(setdiff(active, evaluated))
    applicability_complete = isempty(unknown)
    feature_authoritative = feature.candidate_binding_verified &&
        !isempty(feature.source_artifact_id) && !isempty(feature.source_artifact_hash) &&
        !isempty(feature.source_result_hash) && feature.fidelity >= 2 &&
        feature.source_kind in
            (:candidate_solver, :measured)
    evaluation_complete = applicability_complete && !isempty(active) && isempty(missing) &&
        feature_authoritative
    stability_status = !isempty(failed) ? :fail :
        evaluation_complete && length(favorable) == length(active) ? :pass : :unknown
    c2_support = evaluation_complete && stability_status == :pass
    margins = Float64[evidence_by_mode[id].normalized_margin for id in evaluated]
    minimum_margin = isempty(margins) ? nothing : minimum(margins)
    tasks = copy(feature.evidence_tasks)
    append!(tasks, ["resolve_mode_applicability:$id" for id in unknown])
    append!(tasks, ["evaluate_mode:$id" for id in missing])
    for id in active
        haskey(evidence_by_mode, id) && append!(tasks, evidence_by_mode[id].evidence_tasks)
    end
    feature_authoritative || push!(tasks, "provide_candidate_bound_stability_feature_state")
    warnings = String[
        "stability modes are non-compensating; favorable modes cannot offset a failed or unknown mode",
        "mode inventory does not establish nonlinear saturation, disruption avoidance, transport, engineering, or robustness"]
    !isempty(unknown) && push!(warnings,
        "unknown mode applicability prevents complete stability evaluation")
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "design_id" => genome.design_id, "genome_physics_hash" => genome.physics_hash,
        "feature_hash" => feature.feature_hash,
        "registry_hash" => stability_mode_registry_hash_v1(registry),
        "applicability_hashes" => getfield.(applicability, :applicability_hash),
        "mode_evidence_hashes" => sort!(String[item.evidence_hash for item in evidence]),
        "active_mode_ids" => active, "inactive_mode_ids" => inactive,
        "unknown_applicability_mode_ids" => unknown,
        "evaluated_active_mode_ids" => evaluated,
        "favorable_active_mode_ids" => favorable,
        "failed_active_mode_ids" => failed, "missing_active_mode_ids" => missing,
        "applicability_complete" => applicability_complete,
        "evaluation_complete" => evaluation_complete,
        "physical_stability_status" => String(stability_status),
        "c2_support_authorized" => c2_support,
        "minimum_normalized_margin" => minimum_margin,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return StabilityModeInventoryV1(genome.design_id, genome.physics_hash,
        feature.feature_hash, stability_mode_registry_hash_v1(registry), applicability,
        sort!(collect(values(evidence_by_mode)); by = x -> x.mode_id), active,
        inactive, unknown, evaluated, favorable, failed, missing,
        applicability_complete, evaluation_complete, stability_status, c2_support,
        minimum_margin, sort!(unique(tasks)), warnings, canonical_hash(core))
end

function stability_mode_applicability_to_dict_v1(item::StabilityModeApplicabilityV1)
    return Dict{String,Any}("mode_id" => item.mode_id, "status" => String(item.status),
        "satisfied_feature_ids" => item.satisfied_feature_ids,
        "false_feature_ids" => item.false_feature_ids,
        "unknown_feature_ids" => item.unknown_feature_ids,
        "missing_evaluation_input_ids" => item.missing_evaluation_input_ids,
        "reason" => item.reason, "applicability_hash" => item.applicability_hash)
end

function stability_mode_inventory_to_dict_v1(item::StabilityModeInventoryV1)
    return Dict{String,Any}("design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "feature_hash" => item.feature_hash, "registry_hash" => item.registry_hash,
        "applicability" => stability_mode_applicability_to_dict_v1.(item.applicability),
        "mode_evidence" => stability_mode_evidence_to_dict_v1.(item.mode_evidence),
        "active_mode_ids" => item.active_mode_ids,
        "inactive_mode_ids" => item.inactive_mode_ids,
        "unknown_applicability_mode_ids" => item.unknown_applicability_mode_ids,
        "evaluated_active_mode_ids" => item.evaluated_active_mode_ids,
        "favorable_active_mode_ids" => item.favorable_active_mode_ids,
        "failed_active_mode_ids" => item.failed_active_mode_ids,
        "missing_active_mode_ids" => item.missing_active_mode_ids,
        "applicability_complete" => item.applicability_complete,
        "evaluation_complete" => item.evaluation_complete,
        "physical_stability_status" => String(item.physical_stability_status),
        "c2_support_authorized" => item.c2_support_authorized,
        "minimum_normalized_margin" => item.minimum_normalized_margin,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "inventory_hash" => item.inventory_hash, "promotion_authorized" => false)
end

function stability_mode_inventory_evidence_bundle_v1(item::StabilityModeInventoryV1)
    completeness_status = item.evaluation_complete ? :pass : :unknown
    stability_status = item.physical_stability_status
    completeness = MetricResult("applicable_stability_modes_evaluated",
        item.evaluation_complete ? true : nothing; fidelity = 2,
        status = completeness_status,
        applicability = "Every physically active mode is evaluated and no mode applicability remains unknown.",
        constraints_checked = item.active_mode_ids,
        solver_name = "stability_mode_compiler_v1", solver_version = "1.0.0",
        input_hash = item.genome_physics_hash, run_hash = item.inventory_hash,
        source_basis = String[evidence.evidence_hash for evidence in item.mode_evidence],
        warnings = item.warnings)
    stability_value = stability_status == :unknown ? nothing :
        item.minimum_normalized_margin
    stability = MetricResult("minimum_stability_margin",
        stability_value; fidelity = 2, status = stability_status,
        applicability = "Minimum signed normalized margin across authoritative active-mode evidence; modes are not mutually compensating.",
        constraints_checked = item.evaluated_active_mode_ids,
        solver_name = "stability_mode_compiler_v1", solver_version = "1.0.0",
        input_hash = item.genome_physics_hash, run_hash = item.inventory_hash,
        source_basis = String[evidence.evidence_hash for evidence in item.mode_evidence],
        warnings = item.warnings)
    bundle_status = stability_status == :fail ? :fail :
        item.c2_support_authorized ? :pass : :unknown
    return EvaluationBundle("stability_mode_compiler_v1", item.design_id,
        "topology_independent", 2, bundle_status, [completeness, stability],
        item.warnings, item.genome_physics_hash,
        canonical_hash(Dict("inventory_hash" => item.inventory_hash,
            "bundle_status" => String(bundle_status))),
        item.c2_support_authorized ? "C2_support_applicable_stability_modes_only" :
            stability_status == :fail ? "C2_stability_hard_fail" :
            "C0_stability_mode_inventory_incomplete")
end
