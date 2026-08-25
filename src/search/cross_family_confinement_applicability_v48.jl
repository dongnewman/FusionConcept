const _V48_SCOPE_FAMILIES = Set([
    "tokamak_axisymmetric",
    "tokamak_3d_hybrid",
    "stellarator",
    "magnetic_mirror",
    "field_reversed_configuration",
    "spheromak",
])

const _V48_CLAIM_BOUNDARY =
    "V48 is an append-only provenance and applicability audit of the confinement " *
    "branches already used by the sealed v46 common-envelope archive. It does not " *
    "replace a transport model, alter a candidate, repair a coefficient, or add " *
    "promotion evidence. Reproducing a published algebraic form is separated from " *
    "satisfying its regime, geometry, calibration, and operating-point domain. " *
    "IPB98(y,2) candidates lack an explicit ELMy H-mode declaration; ISS04 candidates " *
    "lack a candidate-specific empirical configuration renormalization; the mirror " *
    "branch does not consume beam energy and is algebraically equal only to an implicit " *
    "100 keV assumption (which happens to match the fixed, unsearched 100 keV value in " *
    "the current archive); the FRC Bohm reference has a temperature " *
    "direction opposite to the C-2/C-2U measured direction; and the spheromak branch " *
    "has no family-specific confinement scaling. Therefore no audited candidate is " *
    "authorized for confinement-based cross-family ranking, medium fidelity, C1, " *
    "scale-up, superiority, or promotion."

_v48_isclose(a::Real, b::Real) = isapprox(Float64(a), Float64(b);
    rtol = 2.0e-12, atol = 1.0e-14)

function _v48_source_ids(evidence::AbstractDict)
    sources = get(evidence, "primary_sources", Any[])
    return Set(String(source["id"]) for source in sources)
end

function _v48_validate_evidence(evidence::AbstractDict)
    String(get(evidence, "catalog_version", "")) ==
        "cross_family_confinement_applicability_v48_1.0.0" ||
        throw(ArgumentError("v48 evidence catalog identity mismatch"))
    required = Set([
        "tokamak_ipb98_doyle_2007",
        "stellarator_iss04_yamada_2005",
        "mirror_wham_endrizzi_2023",
        "frc_c2u_gota_2017",
        "spheromak_hit_si_jarboe_2006",
    ])
    required == _v48_source_ids(evidence) ||
        throw(ArgumentError("v48 primary-source set mismatch"))
    get(evidence, "promotion_credit", true) === false ||
        throw(ArgumentError("v48 evidence must grant zero promotion credit"))
    contract = evidence["evidence_contract"]
    all(value === false for value in values(contract)) ||
        throw(ArgumentError("v48 fail-closed evidence contract weakened"))
    return nothing
end

function _v48_formula_ipb98(nominal::AbstractDict,
        contract::SharedOuterEnvelopeContractV1)
    a = Float64(nominal["plasma_minor_radius_m"])
    R = Float64(nominal["major_radius_or_half_length_m"])
    current_MA = Float64(nominal["plasma_current_MA"])
    density_19 = Float64(nominal["density_m3"]) / 1.0e19
    loss_power_MW = Float64(nominal["transport_loss_power_W"]) / 1.0e6
    epsilon = a / R
    return 0.0562 * current_MA^0.93 * contract.plasma_field_T^0.15 *
        density_19^0.41 * loss_power_MW^(-0.69) * R^1.97 *
        epsilon^0.58 * 1.65^0.78 * 2.5^0.19
end

function _v48_formula_iss04(nominal::AbstractDict, features,
        contract::SharedOuterEnvelopeContractV1)
    a = Float64(nominal["plasma_minor_radius_m"])
    R = Float64(nominal["major_radius_or_half_length_m"])
    density_19 = Float64(nominal["density_m3"]) / 1.0e19
    loss_power_MW = Float64(nominal["transport_loss_power_W"]) / 1.0e6
    iota = clamp(0.25 + 0.55 * features.external_transform_fraction, 0.2, 1.0)
    renormalization = clamp(0.55 + 0.55 * features.field_quality, 0.55, 1.10)
    tau = 0.134 * renormalization * a^2.28 * R^0.64 *
        loss_power_MW^(-0.61) * density_19^0.54 *
        contract.plasma_field_T^0.84 * iota^0.41
    return tau, iota, renormalization
end

function _v48_nbi_beam_energy_keV(genome::Genome)
    energies = Float64[]
    for actuator in genome.actuators
        occursin("nbi", lowercase(actuator.kind)) || continue
        haskey(actuator.parameters, "beam_energy") || continue
        push!(energies, actuator.parameters["beam_energy"].value /
            1.602176634e-16)
    end
    return isempty(energies) ? nothing : maximum(energies)
end

function _v48_explicit_h_mode(context::RecoverableCrossTopologyContextV20,
        module_ids::AbstractVector)
    tokens = String[]
    append!(tokens, lowercase.(String.(module_ids)))
    for module_id in module_ids
        topology_module = context.modules[String(module_id)]
        append!(tokens, lowercase.(collect(topology_module.provides)))
    end
    return any(token -> occursin("h_mode", token) ||
        occursin("elmy_h", token), tokens)
end

function _v48_common_record(v46::AbstractDict,
        candidate::CrossTopologyCandidateV20, nominal::AbstractDict)
    compiled = candidate.prescreen.compiled
    return Dict{String,Any}(
        "candidate_index" => candidate.candidate_index,
        "assembly_index" => candidate.assembly_index,
        "assembly_id" => compiled.assembly_id,
        "family" => compiled.family,
        "module_ids" => copy(compiled.module_ids),
        "physics_hash" => compiled.genome.physics_hash,
        "evaluator_id" => compiled.evaluator_id,
        "projection_id" => compiled.projection_id,
        "v46_v20_compatible_core_record_hash" =>
            v46["v46_v20_compatible_core_record_hash"],
        "current_energy_confinement_time_s" =>
            Float64(nominal["energy_confinement_time_s"]),
        "formula_numerically_reproduced" => false,
        "source_domain_complete" => false,
        "candidate_specific_confinement_comparison_authorized" => false,
        "common_baseline_ranking_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promotion_credit" => 0,
    )
end

function _v48_tokamak_record!(record::Dict{String,Any},
        nominal::AbstractDict, features, contract, explicit_h_mode::Bool)
    reproduced = _v48_formula_ipb98(nominal, contract)
    epsilon = Float64(nominal["plasma_minor_radius_m"]) /
        Float64(nominal["major_radius_or_half_length_m"])
    current_MA = Float64(nominal["plasma_current_MA"])
    greenwald_20 = current_MA /
        (pi * Float64(nominal["plasma_minor_radius_m"])^2)
    n_over_greenwald = (Float64(nominal["density_m3"]) / 1.0e20) /
        max(greenwald_20, 1.0e-30)
    model_tau = Float64(nominal["ipb98y2_time_s"])
    record["current_model_id"] = "IPB98(y,2)"
    record["source_ids"] = ["tokamak_ipb98_doyle_2007"]
    record["formula_recomputed_time_s"] = reproduced
    record["formula_numerically_reproduced"] = _v48_isclose(reproduced, model_tau)
    record["source_domain_checks"] = Dict{String,Any}(
        "explicit_ELMy_H_mode_declared" => explicit_h_mode,
        "inverse_aspect_ratio_epsilon" => epsilon,
        "standard_tokamak_epsilon_domain_passed" =>
            0.15 < epsilon < 0.45,
        "n_over_greenwald" => n_over_greenwald,
        "high_density_degradation_warning" => n_over_greenwald > 0.8,
    )
    blockers = String[]
    explicit_h_mode || push!(blockers, "ELMy_H_mode_regime_not_explicit_in_candidate_graph")
    0.15 < epsilon < 0.45 || push!(blockers, "epsilon_outside_standard_IPB98_database_domain")
    n_over_greenwald > 0.8 && push!(blockers, "high_density_scaling_degradation_warning")
    push!(blockers, "candidate_specific_transport_validation_missing")
    record["applicability_blockers"] = blockers
    return record
end

function _v48_stellarator_record!(record::Dict{String,Any},
        nominal::AbstractDict, features, contract)
    reproduced, iota, renormalization = _v48_formula_iss04(
        nominal, features, contract)
    model_tau = Float64(nominal["iss04_time_s"])
    record["current_model_id"] = "ISS04_with_field_quality_heuristic_f_ren"
    record["source_ids"] = ["stellarator_iss04_yamada_2005"]
    record["formula_recomputed_time_s"] = reproduced
    record["formula_numerically_reproduced"] = _v48_isclose(reproduced, model_tau)
    record["source_domain_checks"] = Dict{String,Any}(
        "iota_proxy" => iota,
        "current_heuristic_f_ren" => renormalization,
        "candidate_specific_empirical_f_ren_calibrated" => false,
        "candidate_effective_ripple_validation_available" => false,
    )
    record["applicability_blockers"] = [
        "candidate_specific_empirical_f_ren_missing",
        "effective_ripple_or_equivalent_configuration_validation_missing",
        "candidate_specific_transport_validation_missing",
    ]
    return record
end

function _v48_mirror_record!(record::Dict{String,Any}, genome::Genome,
        nominal::AbstractDict, features)
    mach = _ccv9_target(genome, "screen_rotation_mach", 0.0, "1")
    base_ratio = max(1.01, features.mirror_ratio *
        (1.0 + 1.5 * features.plug_strength +
            0.75 * features.minimum_b_strength))
    rotation_multiplier = 1.0 + min(2.0, 0.50 * mach^2)
    effective_ratio = min(1.0e4, base_ratio^rotation_multiplier)
    density_20 = max(Float64(nominal["density_m3"]) / 1.0e20, 0.02)
    current_reproduction = max(1.0e-4,
        0.25 * log10(effective_ratio) / density_20)
    beam_energy_keV = _v48_nbi_beam_energy_keV(genome)
    complete_at_declared = beam_energy_keV === nothing ? nothing :
        0.25 * (beam_energy_keV / 100.0)^1.5 *
            log10(effective_ratio) / density_20
    model_tau = Float64(nominal["mirror_time_proxy_s"])
    record["current_model_id"] = "WHAM_like_mirror_time_with_implicit_fixed_100keV_factor"
    record["source_ids"] = ["mirror_wham_endrizzi_2023"]
    record["formula_recomputed_time_s"] = current_reproduction
    record["formula_numerically_reproduced"] =
        _v48_isclose(current_reproduction, model_tau)
    record["source_complete_time_at_declared_beam_energy_s"] =
        complete_at_declared
    record["source_domain_checks"] = Dict{String,Any}(
        "screen_beam_energy_search_gene_present" =>
            haskey(genome.mission.targets, "screen_beam_energy"),
        "declared_nbi_beam_energy_keV" => beam_energy_keV,
        "declared_beam_energy_used_by_current_model" => false,
        "declared_beam_energy_matches_implicit_100keV" =>
            beam_energy_keV !== nothing && _v48_isclose(beam_energy_keV, 100.0),
        "implicit_current_model_beam_energy_keV" => 100.0,
        "source_beam_energy_exponent" => 1.5,
        "effective_mirror_ratio_proxy" => effective_ratio,
        "effective_mirror_ratio_semantics_validated" => false,
        "current_to_source_complete_time_ratio" =>
            complete_at_declared === nothing ? nothing :
                model_tau / max(complete_at_declared, 1.0e-30),
    )
    record["applicability_blockers"] = [
        "beam_energy_not_a_search_gene",
        "beam_energy_input_not_consumed_by_current_model",
        "effective_mirror_ratio_semantics_not_validated",
        "candidate_distribution_and_equilibrium_not_validated",
    ]
    return record
end

function _v48_frc_record!(record::Dict{String,Any})
    record["current_model_id"] = "Bohm_diffusion_reference_as_confinement"
    record["source_ids"] = ["frc_c2u_gota_2017"]
    record["source_domain_checks"] = Dict{String,Any}(
        "current_model_temperature_exponent_at_fixed_geometry_and_field" => -1.0,
        "C2_C2U_measured_temperature_exponent" => 1.8,
        "temperature_direction_consistent" => false,
        "candidate_regime_overlap_established" => false,
    )
    record["applicability_blockers"] = [
        "temperature_direction_contradicts_C2_C2U_anchor",
        "family_specific_candidate_transport_model_missing",
        "candidate_regime_overlap_not_established",
    ]
    return record
end

function _v48_spheromak_record!(record::Dict{String,Any})
    record["current_model_id"] = "Bohm_diffusion_reference_as_confinement"
    record["source_ids"] = ["spheromak_hit_si_jarboe_2006"]
    record["source_domain_checks"] = Dict{String,Any}(
        "family_specific_confinement_scaling_available" => false,
        "known_device_confinement_magnitude_regression_passed" => false,
        "HIT_SI_source_role" => "formation_and_sustainment_anchor_only",
    )
    record["applicability_blockers"] = [
        "family_specific_confinement_scaling_missing",
        "known_device_confinement_magnitude_regression_missing",
        "Bohm_reference_not_validated_as_spheromak_confinement_law",
    ]
    return record
end

function _v48_candidate_record(context::RecoverableCrossTopologyContextV20,
        v46::AbstractDict)
    index = Int(v46["candidate_index"])
    candidate = evaluate_cross_topology_candidate_v20(context, index;
        halton_skip = 4096)
    core = cross_topology_candidate_to_dict_v20(candidate)
    canonical_hash(core) == String(v46["v46_v20_compatible_core_record_hash"]) ||
        throw(ArgumentError("v48 candidate $index drifted from sealed v46 core"))
    compiled = candidate.prescreen.compiled
    compiled.evaluator_id == "composable_cross_family_screen_v1" ||
        throw(ArgumentError("v48 scoped candidate $index uses unexpected evaluator"))
    evaluator = context.evaluators[compiled.evaluator_id]
    evaluator isa ComposableCrossFamilyScreenV1 ||
        throw(ArgumentError("v48 evaluator type mismatch"))
    genome = compiled.genome
    result = _composable_cross_family_result(evaluator, genome)
    nominal = result["nominal"]
    raw_features = _oe_features(genome)
    scored = _ccv9_scored_features(genome, evaluator.contract, raw_features)
    mach = _ccv9_target(genome, "screen_rotation_mach", 0.0, "1")
    features = mach > 0.0 ? first(_ccv9_rotation_features(scored, mach)) : scored
    family = compiled.family
    record = _v48_common_record(v46, candidate, nominal)

    if family == "tokamak_axisymmetric"
        _v48_tokamak_record!(record, nominal, features, evaluator.contract,
            _v48_explicit_h_mode(context, compiled.module_ids))
    elseif family == "stellarator"
        _v48_stellarator_record!(record, nominal, features, evaluator.contract)
    elseif family == "tokamak_3d_hybrid"
        tokamak = _oe_nominal(genome, evaluator.contract,
            merge(features, (family = "tokamak_axisymmetric",)))
        stellarator = _oe_nominal(genome, evaluator.contract,
            merge(features, (family = "stellarator",)))
        tokamak_audit = Dict{String,Any}()
        stellarator_audit = Dict{String,Any}()
        _v48_tokamak_record!(tokamak_audit, tokamak, features,
            evaluator.contract, _v48_explicit_h_mode(context, compiled.module_ids))
        _v48_stellarator_record!(stellarator_audit, stellarator, features,
            evaluator.contract)
        record["current_model_id"] = "conservative_IPB98_ISS04_parent_intersection"
        record["source_ids"] = ["tokamak_ipb98_doyle_2007",
            "stellarator_iss04_yamada_2005"]
        record["formula_numerically_reproduced"] =
            tokamak_audit["formula_numerically_reproduced"] &&
            stellarator_audit["formula_numerically_reproduced"]
        record["parent_branch_audit"] = Dict(
            "tokamak" => tokamak_audit,
            "stellarator" => stellarator_audit)
        record["source_domain_checks"] = Dict{String,Any}(
            "tokamak_parent_source_domain_complete" => false,
            "stellarator_parent_source_domain_complete" => false,
            "both_parent_source_domains_complete" => false,
            "hybrid_interpolation_validated" => false,
        )
        record["applicability_blockers"] = [
            "tokamak_parent_source_domain_incomplete",
            "stellarator_parent_source_domain_incomplete",
            "hybrid_interpolation_not_validated",
        ]
    elseif family == "magnetic_mirror"
        _v48_mirror_record!(record, genome, nominal, raw_features)
    elseif family == "field_reversed_configuration"
        _v48_frc_record!(record)
    elseif family == "spheromak"
        _v48_spheromak_record!(record)
    else
        throw(ArgumentError("unexpected v48 family $family"))
    end
    return record
end

function _v48_family_summary(records::Vector{Dict{String,Any}}, family::String)
    subset = filter(record -> record["family"] == family, records)
    return Dict{String,Any}(
        "candidate_count" => length(subset),
        "formula_numerically_reproduced_count" => count(record ->
            record["formula_numerically_reproduced"] === true, subset),
        "source_domain_complete_count" => count(record ->
            record["source_domain_complete"] === true, subset),
        "candidate_specific_comparison_authorized_count" => count(record ->
            record["candidate_specific_confinement_comparison_authorized"] === true,
            subset),
        "common_baseline_ranking_authorized_count" => count(record ->
            record["common_baseline_ranking_authorized"] === true, subset),
    )
end

function cross_family_confinement_applicability_v48(
        context::RecoverableCrossTopologyContextV20,
        v46_records::AbstractVector, evidence::AbstractDict)
    _v48_validate_evidence(evidence)
    length(v46_records) == 2_000 ||
        throw(ArgumentError("v48 requires all 2000 sealed v46 candidates"))
    indices = sort!(Int[Int(record["candidate_index"])
        for record in v46_records])
    indices == collect(1:2_000) ||
        throw(ArgumentError("v48 requires contiguous candidate indices 1:2000"))
    scoped_input = sort!(filter(record ->
        String(record["family"]) in _V48_SCOPE_FAMILIES, collect(v46_records));
        by = record -> Int(record["candidate_index"]))
    records = Dict{String,Any}[_v48_candidate_record(context, record)
        for record in scoped_input]
    families = sort!(collect(_V48_SCOPE_FAMILIES))
    summaries = Dict(family => _v48_family_summary(records, family)
        for family in families)
    outside = Dict{String,Int}()
    for record in v46_records
        family = String(record["family"])
        family in _V48_SCOPE_FAMILIES && continue
        outside[family] = get(outside, family, 0) + 1
    end
    mirror = filter(record -> record["family"] == "magnetic_mirror", records)
    frc = filter(record -> record["family"] ==
        "field_reversed_configuration", records)
    spheromak = filter(record -> record["family"] == "spheromak", records)
    tokamak = filter(record -> record["family"] ==
        "tokamak_axisymmetric", records)
    stellarator = filter(record -> record["family"] == "stellarator", records)
    hybrid = filter(record -> record["family"] == "tokamak_3d_hybrid", records)
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "search_version" => "cross_family_confinement_applicability_v48",
        "stage" => "sealed_cross_family_confinement_provenance_and_applicability_audit",
        "audit_contract" => Dict{String,Any}(
            "sealed_v46_core_reconstruction_required" => true,
            "formula_reproduction_separate_from_source_domain" => true,
            "source_domain_separate_from_candidate_validation" => true,
            "missing_gene_or_calibration_fails_closed" => true,
            "directional_contradiction_fails_closed" => true,
            "ranking_requires_candidate_specific_authorization" => true,
            "audit_can_promote_candidate" => false,
        ),
        "aggregate" => Dict{String,Any}(
            "input_candidate_count" => length(v46_records),
            "input_family_count" => length(unique(String(record["family"])
                for record in v46_records)),
            "scoped_candidate_count" => length(records),
            "scoped_family_count" => length(families),
            "scoped_families" => families,
            "outside_scope_candidate_count" => length(v46_records) - length(records),
            "outside_scope_family_candidate_counts" => outside,
            "family_summaries" => summaries,
            "formula_numerically_reproduced_candidate_count" => count(record ->
                record["formula_numerically_reproduced"] === true, records),
            "source_domain_complete_candidate_count" => 0,
            "tokamak_explicit_ELMy_H_mode_count" => count(record ->
                record["source_domain_checks"]["explicit_ELMy_H_mode_declared"] === true,
                tokamak),
            "tokamak_standard_epsilon_domain_pass_count" => count(record ->
                record["source_domain_checks"]["standard_tokamak_epsilon_domain_passed"] === true,
                tokamak),
            "tokamak_high_density_degradation_warning_count" => count(record ->
                record["source_domain_checks"]["high_density_degradation_warning"] === true,
                tokamak),
            "stellarator_candidate_specific_f_ren_count" => count(record ->
                record["source_domain_checks"]["candidate_specific_empirical_f_ren_calibrated"] === true,
                stellarator),
            "mirror_beam_energy_search_gene_count" => count(record ->
                record["source_domain_checks"]["screen_beam_energy_search_gene_present"] === true,
                mirror),
            "mirror_declared_beam_energy_used_count" => count(record ->
                record["source_domain_checks"]["declared_beam_energy_used_by_current_model"] === true,
                mirror),
            "mirror_declared_beam_energy_matches_implicit_count" => count(record ->
                record["source_domain_checks"]["declared_beam_energy_matches_implicit_100keV"] === true,
                mirror),
            "mirror_declared_beam_energy_keV_range" => [
                minimum(record["source_domain_checks"]["declared_nbi_beam_energy_keV"] for record in mirror),
                maximum(record["source_domain_checks"]["declared_nbi_beam_energy_keV"] for record in mirror),
            ],
            "frc_temperature_direction_conflict_count" => count(record ->
                record["source_domain_checks"]["temperature_direction_consistent"] === false,
                frc),
            "spheromak_family_specific_scaling_available_count" => count(record ->
                record["source_domain_checks"]["family_specific_confinement_scaling_available"] === true,
                spheromak),
            "hybrid_both_parent_domains_complete_count" => count(record ->
                record["source_domain_checks"]["both_parent_source_domains_complete"] === true,
                hybrid),
            "candidate_specific_comparison_authorized_count" => 0,
            "common_baseline_ranking_authorized_count" => 0,
            "medium_fidelity_authorized_count" => 0,
            "promotion_count" => 0,
        ),
        "candidate_records" => records,
        "next_actions" => [
            "add an explicit searched mirror beam-energy gene, consume it in the WHAM source-complete equation, and regress both 25 keV WHAM and 100 keV reference cases",
            "add an explicit tokamak operating-regime declaration and block IPB98 use unless ELMy H-mode and density-domain checks are satisfied",
            "replace stellarator field-quality f_ren with a candidate-specific configuration metric calibrated on source-disjoint devices",
            "replace FRC and spheromak Bohm references with family-specific, known-device-regressed transport bridges before allowing confinement ranking",
            "rerun the unchanged 2000-candidate archive before increasing candidate count or opening medium-fidelity admission",
        ],
        "promotion_credit" => Dict{String,Any}(
            "physics_evidence_level_change" => 0,
            "engineering_evidence_level_change" => 0,
            "medium_fidelity_authorized_count" => 0,
            "promotion_count" => 0,
        ),
        "claim_boundary" => _V48_CLAIM_BOUNDARY,
    )
end
