const _V50_REGIME_STATES = [0, 1]

const _V50_CLAIM_BOUNDARY =
    "V50 is an append-only fixed-background operating-regime intervention on " *
    "the 360 axisymmetric-tokamak candidates sealed by v46 and audited by v48. " *
    "It adds an explicit binary ELMy-H-mode declaration gene and consumes that " *
    "gene in an IPB98 applicability precondition rather than changing the " *
    "candidate's confinement or performance values. The precondition also " *
    "checks the standard IPB98 inverse-aspect-ratio interval, the 0.3-to-0.8 " *
    "n/n_G band containing most of the cited H-mode database, the q95>=3 region " *
    "that avoids the reported low-q threshold increase, and a conservative " *
    "envelope of three published fits from two multi-machine L-H threshold " *
    "analyses. The current " *
    "volume-average density is used as a line-average proxy, first-wall area as " *
    "an LCFS-area proxy, and declared external actuator power (excluding alpha " *
    "heating) as an optimistic transition-power upper bound. Actuator heating " *
    "versus current-drive partition, absorbed fraction, core radiation, P_sep, " *
    "time-dependent access, density-profile " *
    "peaking, divertor topology/drift dependence, ELM transient loads and " *
    "mitigation, and candidate-specific transport validation remain missing. " *
    "Therefore passing the V50 precondition is not source-domain completeness, " *
    "H-mode proof, stability proof, performance ranking authority, medium " *
    "fidelity, C1, scale-up, superiority, reactor feasibility, or promotion."

_v50_isclose(a::Real, b::Real) = isapprox(Float64(a), Float64(b);
    rtol = 2.0e-12, atol = 1.0e-14)

function _v50_validate_evidence(evidence::AbstractDict)
    String(get(evidence, "catalog_version", "")) ==
        "tokamak_regime_access_intervention_v50_1.0.0" ||
        throw(ArgumentError("v50 evidence catalog identity mismatch"))
    Int.(evidence["preregistered_regime_states"]) == _V50_REGIME_STATES ||
        throw(ArgumentError("v50 regime states changed"))
    required = Set(["tokamak_ipb98_doyle_2007",
        "tokamak_lh_martin_2008", "tokamak_itpa_snipes_threshold"])
    sources = Set(String(source["id"]) for source in evidence["primary_sources"])
    sources == required || throw(ArgumentError("v50 primary-source set mismatch"))
    contract = evidence["calculation_contract"]
    Float64(contract["density_band_n_over_greenwald"][1]) == 0.3 ||
        throw(ArgumentError("v50 lower density-band bound changed"))
    Float64(contract["density_band_n_over_greenwald"][2]) == 0.8 ||
        throw(ArgumentError("v50 upper density-band bound changed"))
    Float64(contract["minimum_q95_without_extra_threshold_correction"]) == 3.0 ||
        throw(ArgumentError("v50 q95 guard changed"))
    get(evidence, "promotion_credit", true) === false ||
        throw(ArgumentError("v50 evidence must grant zero promotion credit"))
    all(value === false for value in values(evidence["authorization_contract"])) ||
        throw(ArgumentError("v50 authorization contract weakened"))
    return nothing
end

function _v50_regime_declared(genome::Genome)
    value = get(genome.mission.targets,
        "screen_ELMy_H_mode_regime_declared", nothing)
    value === nothing && throw(ArgumentError("v50 regime gene missing"))
    value.unit == "1" || throw(ArgumentError("v50 regime gene must be dimensionless"))
    state = Int(round(value.value))
    state in _V50_REGIME_STATES && _v50_isclose(state, value.value) ||
        throw(ArgumentError("v50 regime gene is not binary"))
    return state == 1
end

function _v50_mutate_regime(base::Genome, state::Int)
    base.family == "tokamak_axisymmetric" || throw(ArgumentError(
        "v50 mutation is restricted to axisymmetric tokamaks"))
    state in _V50_REGIME_STATES || throw(ArgumentError(
        "v50 state is outside the preregistered intervention"))
    raw = deepcopy(base.normalized)
    basis = "v50 preregistered IPB98 ELMy-H-mode applicability intervention"
    _ctv4_set_target!(raw, "screen_ELMy_H_mode_regime_declared",
        Float64(state), "1"; basis = basis)
    raw["design_id"] = "pending_tokamak_regime_v50"
    raw["label"] = state == 1 ?
        "V50 explicit ELMy H-mode regime" :
        "V50 unspecified or non-ELMy-H-mode regime"
    provenance = raw["provenance"]
    provenance["origin"] = "generated"
    provenance["parent_design_ids"] = [base.design_id]
    provenance["claim_level"] = "C0_operating_regime_applicability_intervention_only"
    notes = get!(provenance, "notes", Any[])
    push!(notes, "v50_explicit_ELMy_H_mode_regime_gene")
    push!(notes, "zero_promotion_credit_source_domain_incomplete")
    provisional = parse_genome(raw)
    raw["design_id"] = "v50_$(provisional.physics_hash[1:20])"
    genome = parse_genome(raw)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError(join(report.errors, "; ")))
    family = validate_family(default_family_registry(), genome)
    family.valid || throw(ArgumentError(join(family.errors, "; ")))
    return genome
end

function _v50_non_regime_projection(genome::Genome)
    raw = deepcopy(genome.normalized)
    delete!(raw, "design_id")
    delete!(raw, "label")
    delete!(raw, "provenance")
    delete!(raw["mission"]["targets"],
        "screen_ELMy_H_mode_regime_declared")
    return raw
end

function _v50_thresholds_MW(n20::Float64, B_T::Float64,
        surface_area_m2::Float64, a_m::Float64, R_m::Float64)
    martin_DT = 0.0488 * n20^0.717 * B_T^0.803 *
        surface_area_m2^0.941 * (2.0 / 2.5)
    snipes_deuterium = 0.042 * n20^0.64 * B_T^0.78 *
        surface_area_m2^0.94
    martin_geometry = 1.67 * n20^0.75 * B_T^0.73 *
        a_m^0.96 * R_m^1.07
    values = [martin_DT, snipes_deuterium, martin_geometry]
    return Dict{String,Any}(
        "martin_2008_DT_mass_corrected_MW" => martin_DT,
        "snipes_ITPA_surface_scaling_MW" => snipes_deuterium,
        "martin_ITPA_geometry_scaling_MW" => martin_geometry,
        "conservative_envelope_MW" => maximum(values),
        "lower_envelope_MW" => minimum(values),
    )
end

function _v50_applicability(genome::Genome, nominal::AbstractDict,
        contract::SharedOuterEnvelopeContractV1, features)
    declared = _v50_regime_declared(genome)
    a = Float64(nominal["plasma_minor_radius_m"])
    R = Float64(nominal["major_radius_or_half_length_m"])
    epsilon = a / max(R, 1.0e-30)
    current_MA = Float64(nominal["plasma_current_MA"])
    greenwald_20 = current_MA / (pi * a^2)
    density_20 = Float64(nominal["density_m3"]) / 1.0e20
    n_over_greenwald = density_20 / max(greenwald_20, 1.0e-30)
    q95 = features.q95
    thresholds = _v50_thresholds_MW(max(density_20, 1.0e-6),
        contract.plasma_field_T, Float64(nominal["first_wall_area_m2"]), a, R)
    declared_actuator_MW = Float64(nominal["declared_actuator_power_W"]) / 1.0e6
    current_loss_MW = Float64(nominal["transport_loss_power_W"]) / 1.0e6
    access_ratio = declared_actuator_MW /
        max(Float64(thresholds["conservative_envelope_MW"]), 1.0e-30)
    epsilon_pass = 0.15 < epsilon < 0.45
    density_band_pass = 0.3 <= n_over_greenwald <= 0.8
    high_density_warning = n_over_greenwald > 0.8
    low_density_warning = n_over_greenwald < 0.3
    q95_pass = q95 >= 3.0
    actuator_upper_bound_pass = access_ratio >= 1.0
    precondition = declared && epsilon_pass && density_band_pass &&
        q95_pass && actuator_upper_bound_pass
    failures = String[]
    declared || push!(failures, "ELMy_H_mode_regime_not_declared")
    epsilon_pass || push!(failures, "epsilon_outside_standard_IPB98_domain")
    density_band_pass || push!(failures,
        low_density_warning ? "below_main_H_mode_database_density_band" :
            "above_main_H_mode_database_density_band")
    q95_pass || push!(failures, "q95_below_3_requires_threshold_correction")
    actuator_upper_bound_pass || push!(failures,
        "declared_actuator_power_below_conservative_LH_threshold_envelope")
    return Dict{String,Any}(
        "ELMy_H_mode_regime_declared" => declared,
        "IPB98_formula_numerically_reproduced" =>
            _v50_isclose(_v48_formula_ipb98(nominal, contract),
                Float64(nominal["ipb98y2_time_s"])),
        "inverse_aspect_ratio_epsilon" => epsilon,
        "standard_IPB98_epsilon_passed" => epsilon_pass,
        "density_m3_volume_average_proxy" => nominal["density_m3"],
        "greenwald_density_1e20_m3" => greenwald_20,
        "n_over_greenwald" => n_over_greenwald,
        "main_H_mode_database_density_band_passed" => density_band_pass,
        "low_density_threshold_warning" => low_density_warning,
        "high_density_degradation_warning" => high_density_warning,
        "q95" => q95,
        "q95_without_extra_threshold_correction_passed" => q95_pass,
        "declared_actuator_power_upper_bound_MW" => declared_actuator_MW,
        "current_IPB98_derived_transport_loss_power_MW_not_used_for_access_gate" =>
            current_loss_MW,
        "thresholds" => thresholds,
        "actuator_upper_bound_to_conservative_threshold_ratio" => access_ratio,
        "actuator_upper_bound_threshold_passed" => actuator_upper_bound_pass,
        "IPB98_regime_access_precondition_passed" => precondition,
        "regime_gene_consumed_by_applicability_gate" => true,
        "line_average_density_available" => false,
        "LCFS_surface_area_available" => false,
        "core_radiation_power_available" => false,
        "P_sep_available" => false,
        "actuator_heating_and_current_drive_partition_available" => false,
        "absorbed_heating_fraction_available" => false,
        "time_dependent_access_validated" => false,
        "ELM_transient_load_model_available" => false,
        "ELM_control_or_mitigation_declared" => false,
        "candidate_specific_transport_validation_available" => false,
        "precondition_failure_ids" => sort!(failures),
    )
end

function _v50_performance_payload(nominal::AbstractDict)
    physics_ids = ["temperature_domain", "stability", "particle_loss",
        "fusion_gain", "auxiliary_power", "net_electric_power"]
    engineering_ids = ["peak_conductor_field", "engineering_current_density",
        "support_stress", "outer_radial_envelope", "outer_axial_envelope",
        "inboard_build", "coil_curvature", "neutron_wall_load",
        "exhaust_target_heat_flux", "finite_exhaust_and_voltage_build"]
    margins = nominal["margins"]
    physics_failures = sort!([id for id in physics_ids if margins[id] < 0.0])
    engineering_failures = sort!([id for id in engineering_ids if margins[id] < 0.0])
    return Dict{String,Any}(
        "energy_confinement_time_s" => nominal["energy_confinement_time_s"],
        "transport_loss_power_W" => nominal["transport_loss_power_W"],
        "required_auxiliary_power_W" => nominal["required_auxiliary_power_W"],
        "fusion_gain_proxy" => nominal["fusion_gain_proxy"],
        "net_electric_power_W" => nominal["net_electric_power_W"],
        "exhaust_heat_flux_W_m2" => nominal["exhaust_heat_flux_W_m2"],
        "physics_gate_passed" => nominal["physics_gate_passed"],
        "engineering_gate_passed" => nominal["engineering_gate_passed"],
        "physics_failure_ids" => physics_failures,
        "engineering_failure_ids" => engineering_failures,
        "named_margins" => deepcopy(margins),
    )
end

function _v50_trial_record(context::RecoverableCrossTopologyContextV20,
        v46::AbstractDict, v48::AbstractDict, state::Int, trial_index::Int)
    index = Int(v46["candidate_index"])
    candidate = evaluate_cross_topology_candidate_v20(context, index;
        halton_skip = 4096)
    core = cross_topology_candidate_to_dict_v20(candidate)
    canonical_hash(core) == String(v46["v46_v20_compatible_core_record_hash"]) ||
        throw(ArgumentError("v50 candidate $index drifted from sealed v46 core"))
    compiled = candidate.prescreen.compiled
    compiled.family == "tokamak_axisymmetric" || throw(ArgumentError(
        "v50 received a non-axisymmetric-tokamak candidate"))
    String(v48["physics_hash"]) == compiled.genome.physics_hash ||
        throw(ArgumentError("v50 candidate $index drifted from sealed v48 audit"))
    v48["formula_numerically_reproduced"] === true || throw(ArgumentError(
        "v50 requires v48 IPB98 formula reproduction"))
    v48["source_domain_checks"]["explicit_ELMy_H_mode_declared"] === false ||
        throw(ArgumentError("v50 requires the sealed v48 missing-regime baseline"))

    evaluator = context.evaluators[compiled.evaluator_id]
    evaluator isa ComposableCrossFamilyScreenV1 || throw(ArgumentError(
        "v50 evaluator type mismatch"))
    base = compiled.genome
    mutated = _v50_mutate_regime(base, state)
    base_projection_hash = canonical_hash(_v50_non_regime_projection(base))
    mutated_projection_hash = canonical_hash(_v50_non_regime_projection(mutated))
    fixed_background = base_projection_hash == mutated_projection_hash
    fixed_background || throw(ArgumentError(
        "v50 non-regime background changed for candidate $index"))
    features = _oe_features(mutated)
    graph_errors = _ccv9_graph_errors(mutated, features, evaluator.contract)
    isempty(graph_errors) || throw(ArgumentError(
        "v50 mutated graph failed validation: $(join(graph_errors, "; "))"))
    current = _ccv9_nominal(mutated, evaluator.contract, features)
    base_features = _oe_features(base)
    base_nominal = _ccv9_nominal(base, evaluator.contract, base_features)
    performance = _v50_performance_payload(current)
    base_performance = _v50_performance_payload(base_nominal)
    invariant = canonical_hash(performance) == canonical_hash(base_performance)
    applicability = _v50_applicability(mutated, current,
        evaluator.contract, features)
    return Dict{String,Any}(
        "trial_index" => trial_index,
        "candidate_index" => index,
        "assembly_index" => candidate.assembly_index,
        "assembly_id" => compiled.assembly_id,
        "sample_ordinal" => Int(v46["sample_ordinal"]),
        "family" => compiled.family,
        "module_ids" => copy(compiled.module_ids),
        "parent_design_id" => base.design_id,
        "design_id" => mutated.design_id,
        "parent_physics_hash" => base.physics_hash,
        "physics_hash" => mutated.physics_hash,
        "regime_state" => state,
        "regime_label" => state == 1 ? "explicit_ELMy_H_mode" :
            "unspecified_or_non_ELMy_H_mode",
        "regime_gene_present" => true,
        "regime_gene_consumed_by_applicability_gate" => true,
        "non_regime_projection_hash" => base_projection_hash,
        "fixed_non_regime_background" => fixed_background,
        "current_evaluator_performance_invariant_to_regime_gene" => invariant,
        "performance_response" => performance,
        "performance_response_hash" => canonical_hash(performance),
        "applicability_response" => applicability,
        "applicability_response_hash" => canonical_hash(applicability),
        "source_domain_complete" => false,
        "candidate_specific_confinement_comparison_authorized" => false,
        "common_baseline_ranking_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promotion_credit" => 0,
        "applicability_blockers" => [
            "volume_average_density_not_validated_as_line_average_density",
            "first_wall_area_not_validated_as_LCFS_surface_area",
            "declared_actuator_power_not_partitioned_or_validated_as_absorbed_heating",
            "core_radiation_and_P_sep_missing",
            "time_dependent_LH_access_and_hysteresis_not_validated",
            "ELM_transient_load_and_mitigation_missing",
            "candidate_specific_transport_validation_missing",
        ],
    )
end

function _v50_qd_archive(trials::Vector{Dict{String,Any}})
    cells = Dict{String,Dict{String,Any}}()
    for trial in trials
        key = "$(trial["assembly_id"])|regime$(trial["regime_state"])"
        if !haskey(cells, key) ||
                Int(trial["candidate_index"]) < Int(cells[key]["candidate_index"])
            cells[key] = Dict{String,Any}(
                "cell_id" => key,
                "assembly_id" => trial["assembly_id"],
                "regime_state" => trial["regime_state"],
                "regime_label" => trial["regime_label"],
                "candidate_index" => trial["candidate_index"],
                "trial_index" => trial["trial_index"],
                "design_id" => trial["design_id"],
                "physics_hash" => trial["physics_hash"],
                "performance_response_hash" => trial["performance_response_hash"],
                "IPB98_regime_access_precondition_passed" =>
                    trial["applicability_response"]["IPB98_regime_access_precondition_passed"],
                "selection_rule" =>
                    "lowest_candidate_index_only_no_performance_ranking",
                "performance_ranking_used" => false,
                "source_domain_complete" => false,
                "promotion_credit" => 0,
            )
        end
    end
    return sort!(collect(values(cells)); by = record -> String(record["cell_id"]))
end

function tokamak_regime_access_intervention_v50(
        context::RecoverableCrossTopologyContextV20,
        v46_records::AbstractVector, v48_records::AbstractVector,
        evidence::AbstractDict)
    _v50_validate_evidence(evidence)
    length(v46_records) == 2_000 || throw(ArgumentError(
        "v50 requires all 2000 sealed v46 candidates"))
    v48_by_index = Dict(Int(record["candidate_index"]) => record
        for record in v48_records)
    tokamak = sort!(filter(record -> String(record["family"]) ==
        "tokamak_axisymmetric", collect(v46_records));
        by = record -> Int(record["candidate_index"]))
    length(tokamak) == 360 || throw(ArgumentError(
        "v50 requires 360 sealed axisymmetric-tokamak candidates"))
    length(unique(String(record["assembly_id"]) for record in tokamak)) == 180 ||
        throw(ArgumentError("v50 requires 180 tokamak assemblies"))

    trials = Dict{String,Any}[]
    trial_index = 0
    for v46 in tokamak, state in _V50_REGIME_STATES
        trial_index += 1
        index = Int(v46["candidate_index"])
        haskey(v48_by_index, index) || throw(ArgumentError(
            "v50 missing v48 record for candidate $index"))
        push!(trials, _v50_trial_record(context, v46,
            v48_by_index[index], state, trial_index))
    end
    qd = _v50_qd_archive(trials)
    by_state = Dict{String,Any}()
    for state in _V50_REGIME_STATES
        subset = filter(record -> Int(record["regime_state"]) == state, trials)
        physics_failure_counts = Dict{String,Int}()
        engineering_failure_counts = Dict{String,Int}()
        for record in subset
            for id in record["performance_response"]["physics_failure_ids"]
                key = String(id)
                physics_failure_counts[key] = get(physics_failure_counts, key, 0) + 1
            end
            for id in record["performance_response"]["engineering_failure_ids"]
                key = String(id)
                engineering_failure_counts[key] =
                    get(engineering_failure_counts, key, 0) + 1
            end
        end
        access_ratios = [Float64(record["applicability_response"][
            "actuator_upper_bound_to_conservative_threshold_ratio"])
            for record in subset]
        density_ratios = [Float64(record["applicability_response"][
            "n_over_greenwald"]) for record in subset]
        by_state[string(state)] = Dict{String,Any}(
            "trial_count" => length(subset),
            "declared_ELMy_H_mode_count" => count(record ->
                record["applicability_response"]["ELMy_H_mode_regime_declared"] === true,
                subset),
            "formula_reproduced_count" => count(record ->
                record["applicability_response"]["IPB98_formula_numerically_reproduced"] === true,
                subset),
            "epsilon_pass_count" => count(record ->
                record["applicability_response"]["standard_IPB98_epsilon_passed"] === true,
                subset),
            "density_band_pass_count" => count(record ->
                record["applicability_response"]["main_H_mode_database_density_band_passed"] === true,
                subset),
            "low_density_warning_count" => count(record ->
                record["applicability_response"]["low_density_threshold_warning"] === true,
                subset),
            "high_density_warning_count" => count(record ->
                record["applicability_response"]["high_density_degradation_warning"] === true,
                subset),
            "q95_pass_count" => count(record ->
                record["applicability_response"]["q95_without_extra_threshold_correction_passed"] === true,
                subset),
            "actuator_upper_bound_threshold_pass_count" => count(record ->
                record["applicability_response"]["actuator_upper_bound_threshold_passed"] === true,
                subset),
            "regime_access_precondition_pass_count" => count(record ->
                record["applicability_response"]["IPB98_regime_access_precondition_passed"] === true,
                subset),
            "physics_gate_pass_count" => count(record ->
                record["performance_response"]["physics_gate_passed"] === true,
                subset),
            "engineering_gate_pass_count" => count(record ->
                record["performance_response"]["engineering_gate_passed"] === true,
                subset),
            "positive_net_electric_count" => count(record ->
                Float64(record["performance_response"]["net_electric_power_W"]) > 0.0,
                subset),
            "physics_failure_id_counts" => physics_failure_counts,
            "engineering_failure_id_counts" => engineering_failure_counts,
            "actuator_to_threshold_ratio_range" =>
                [minimum(access_ratios), maximum(access_ratios)],
            "n_over_greenwald_range" =>
                [minimum(density_ratios), maximum(density_ratios)],
        )
    end
    pairs = Dict{Int,Vector{Dict{String,Any}}}()
    for trial in trials
        push!(get!(pairs, Int(trial["candidate_index"]), Dict{String,Any}[]), trial)
    end
    state_change_count = count(values(pairs)) do pair
        length(pair) == 2 || return false
        values_by_state = Dict(Int(record["regime_state"]) =>
            record["applicability_response"]["IPB98_regime_access_precondition_passed"]
            for record in pair)
        values_by_state[0] != values_by_state[1]
    end
    declaration_state_change_count = count(values(pairs)) do pair
        length(pair) == 2 || return false
        values_by_state = Dict(Int(record["regime_state"]) =>
            record["applicability_response"]["ELMy_H_mode_regime_declared"]
            for record in pair)
        values_by_state[0] != values_by_state[1]
    end
    applicability_response_state_change_count = count(values(pairs)) do pair
        length(pair) == 2 || return false
        length(unique(String(record["applicability_response_hash"])
            for record in pair)) == 2
    end
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "search_version" => "tokamak_regime_access_intervention_v50",
        "stage" => "sealed_tokamak_operating_regime_access_counterfactual_qd",
        "experiment_contract" => Dict{String,Any}(
            "sealed_v46_core_reconstruction_required" => true,
            "sealed_v48_formula_reproduction_required" => true,
            "preregistered_regime_states" => copy(_V50_REGIME_STATES),
            "non_regime_background_canonically_fixed" => true,
            "regime_gene_consumed_by_applicability_gate" => true,
            "current_performance_values_must_remain_invariant" => true,
            "threshold_model_count" => 3,
            "threshold_envelope_is_conservative_maximum" => true,
            "qd_selection_uses_performance" => false,
            "experiment_can_promote_candidate" => false,
        ),
        "aggregate" => Dict{String,Any}(
            "input_candidate_count" => length(v46_records),
            "tokamak_candidate_count" => length(tokamak),
            "tokamak_assembly_count" => 180,
            "regime_state_count" => length(_V50_REGIME_STATES),
            "trial_count" => length(trials),
            "fixed_non_regime_background_count" => count(record ->
                record["fixed_non_regime_background"] === true, trials),
            "regime_gene_present_count" => count(record ->
                record["regime_gene_present"] === true, trials),
            "regime_gene_consumed_count" => count(record ->
                record["regime_gene_consumed_by_applicability_gate"] === true,
                trials),
            "current_performance_invariant_count" => count(record ->
                record["current_evaluator_performance_invariant_to_regime_gene"] === true,
                trials),
            "unique_physics_hash_count" => length(unique(
                String(record["physics_hash"]) for record in trials)),
            "candidate_precondition_state_change_count" => state_change_count,
            "candidate_declaration_state_change_count" =>
                declaration_state_change_count,
            "candidate_applicability_response_state_change_count" =>
                applicability_response_state_change_count,
            "source_domain_complete_count" => count(record ->
                record["source_domain_complete"] === true, trials),
            "candidate_specific_comparison_authorized_count" => count(record ->
                record["candidate_specific_confinement_comparison_authorized"] === true,
                trials),
            "common_baseline_ranking_authorized_count" => count(record ->
                record["common_baseline_ranking_authorized"] === true, trials),
            "medium_fidelity_authorized_count" => count(record ->
                record["medium_fidelity_authorized"] === true, trials),
            "promotion_count" => count(record ->
                Int(record["promotion_credit"]) > 0, trials),
            "qd_cell_count" => length(qd),
            "qd_performance_selected_cell_count" => count(record ->
                record["performance_ranking_used"] === true, qd),
            "by_regime_state" => by_state,
        ),
        "next_actions" => [
            "Add candidate line-averaged density and LCFS surface area instead of volume-density and first-wall proxies.",
            "Add core-radiation and P_sep closure plus time-dependent L-H access and hysteresis.",
            "Represent ELM transient heat loads and a candidate-specific mitigation or ELM-free regime route.",
            "Calibrate threshold and confinement magnitudes against held-out tokamak operating points before comparison.",
            "Continue horizontally with candidate-specific stellarator f_ren, FRC transport, and spheromak transport bridges.",
        ],
        "promotion_credit" => Dict{String,Any}(
            "candidate_count" => 0,
            "credit_granted" => false,
            "reason" => "An explicit regime declaration and proxy access gate are necessary applicability wiring, not H-mode or candidate validation.",
        ),
        "claim_boundary" => _V50_CLAIM_BOUNDARY,
        "trial_records" => trials,
        "qd_records" => qd,
    )
end
