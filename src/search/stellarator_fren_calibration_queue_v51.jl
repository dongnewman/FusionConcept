const _V51_LAYERS = ["core", "field_source", "stability", "exhaust", "engineering"]
const _V51_CONFIGURATION_CLASSES = ["stellarator_qa", "stellarator_qh", "stellarator_qi"]

const _V51_CLAIM_BOUNDARY =
    "V51 is an append-only candidate-specific ISS04 f_ren calibration-readiness " *
    "audit and structural acquisition queue over the 288 stellarator candidates " *
    "sealed by v46 and audited by v48. It does not assign f_ren to any candidate. " *
    "ISS04 f_ren is an a-posteriori device/configuration empirical offset; the " *
    "published effective-ripple relation is approximate, proportional rather than " *
    "normalized, and reported over a bounded ripple interval. The one existing " *
    "DESC low-order effective-ripple fixture belongs to a source-disjoint Fourier " *
    "candidate, lacks high-order Bounce2D and drift-kinetic validation, and lies " *
    "below the cited empirical ripple interval at every sampled radius. Therefore " *
    "it proves only that a low-order numerical route exists, not that the v46 " *
    "candidates have known ripple or f_ren. V51 selects six structurally diverse " *
    "assemblies per QA/QH/QI class using only v17 module-set distance; no performance " *
    "value, current heuristic f_ren, or outcome label enters selection. The queue " *
    "authorizes geometry reconstruction and calibration-data acquisition only. It " *
    "does not authorize confinement comparison, common ranking, medium-fidelity " *
    "admission, C1, scale-up, superiority, reactor feasibility, or promotion."

function _v51_validate_evidence(evidence::AbstractDict)
    evidence["catalog_version"] == "stellarator_fren_calibration_queue_v51_1.0.0" ||
        throw(ArgumentError("unexpected v51 evidence catalog version"))
    ids = Set(String(record["id"]) for record in evidence["primary_sources"])
    required = Set(["stellarator_iss04_yamada_2005",
        "stellarator_lhd_configuration_funaba_2008",
        "stellarator_cnt_hammond_2017"])
    ids == required || throw(ArgumentError("v51 evidence source IDs changed"))
    evidence["authorization_contract"]["candidate_f_ren_value"] === false ||
        throw(ArgumentError("v51 evidence cannot authorize candidate f_ren"))
    evidence["promotion_credit"] === false ||
        throw(ArgumentError("v51 evidence cannot grant promotion credit"))
    return evidence
end

function _v51_layer_map(module_ids)
    length(module_ids) == length(_V51_LAYERS) || throw(ArgumentError(
        "v51 requires exactly five v17 layer modules"))
    return Dict(_V51_LAYERS[index] => String(module_ids[index])
        for index in eachindex(_V51_LAYERS))
end

function _v51_boundary_readiness(genome::Genome)
    core_regions = filter(region -> region.kind == "closed_toroidal_core",
        genome.plasma_regions)
    length(core_regions) == 1 || throw(ArgumentError(
        "v51 requires exactly one closed toroidal core"))
    raw_regions = genome.normalized["plasma_regions"]
    raw_core = only(filter(region ->
        String(region["kind"]) == "closed_toroidal_core", raw_regions))
    parameters = raw_core["parameters"]
    parameter_ids = sort!(String.(collect(keys(parameters))))
    coefficient_ids = sort!(filter(parameter_ids) do id
        startswith(id, "R_lmn") || startswith(id, "Z_lmn") ||
            startswith(id, "fourier_R") || startswith(id, "fourier_Z") ||
            id in ("boundary_R_lmn", "boundary_Z_lmn")
    end)
    profile_ids = sort!(filter(parameter_ids) do id
        occursin("profile", lowercase(id)) || occursin("iota_", lowercase(id)) ||
            occursin("current_", lowercase(id)) || occursin("pressure_", lowercase(id))
    end)
    return Dict{String,Any}(
        "geometry_model" => raw_core["geometry_model"],
        "parameter_ids" => parameter_ids,
        "explicit_fourier_boundary_coefficient_ids" => coefficient_ids,
        "explicit_fourier_boundary_coefficient_count" => length(coefficient_ids),
        "equilibrium_profile_parameter_ids" => profile_ids,
        "equilibrium_profile_parameter_count" => length(profile_ids),
        "candidate_boundary_reconstructable_for_DESC" => !isempty(coefficient_ids),
        "candidate_equilibrium_profiles_available" => !isempty(profile_ids),
    )
end

function _v51_current_performance_payload(nominal::AbstractDict)
    return Dict{String,Any}(
        "energy_confinement_time_s" => nominal["energy_confinement_time_s"],
        "iss04_time_s" => nominal["iss04_time_s"],
        "transport_loss_power_W" => nominal["transport_loss_power_W"],
        "required_auxiliary_power_W" => nominal["required_auxiliary_power_W"],
        "fusion_gain_proxy" => nominal["fusion_gain_proxy"],
        "net_electric_power_W" => nominal["net_electric_power_W"],
        "physics_gate_passed" => nominal["physics_gate_passed"],
        "engineering_gate_passed" => nominal["engineering_gate_passed"],
    )
end

function _v51_candidate_record(context::RecoverableCrossTopologyContextV20,
        v46::AbstractDict, v48::AbstractDict)
    index = Int(v46["candidate_index"])
    candidate = evaluate_cross_topology_candidate_v20(context, index;
        halton_skip = 4096)
    core = cross_topology_candidate_to_dict_v20(candidate)
    canonical_hash(core) == String(v46["v46_v20_compatible_core_record_hash"]) ||
        throw(ArgumentError("v51 candidate $index drifted from sealed v46 core"))
    compiled = candidate.prescreen.compiled
    compiled.family == "stellarator" || throw(ArgumentError(
        "v51 received a non-stellarator candidate"))
    String(v48["physics_hash"]) == compiled.genome.physics_hash ||
        throw(ArgumentError("v51 candidate $index drifted from sealed v48 audit"))
    v48["formula_numerically_reproduced"] === true || throw(ArgumentError(
        "v51 requires the sealed v48 ISS04 formula reproduction"))
    layers = _v51_layer_map(v46["module_ids"])
    layers["core"] in _V51_CONFIGURATION_CLASSES || throw(ArgumentError(
        "v51 unknown stellarator configuration class"))
    boundary = _v51_boundary_readiness(compiled.genome)
    evaluator = context.evaluators[compiled.evaluator_id]
    evaluator isa ComposableCrossFamilyScreenV1 || throw(ArgumentError(
        "v51 evaluator type mismatch"))
    features = _oe_features(compiled.genome)
    nominal = _ccv9_nominal(compiled.genome, evaluator.contract, features)
    current = _v51_current_performance_payload(nominal)
    checks = v48["source_domain_checks"]
    return Dict{String,Any}(
        "candidate_index" => index,
        "assembly_index" => candidate.assembly_index,
        "assembly_id" => compiled.assembly_id,
        "sample_ordinal" => Int(v46["sample_ordinal"]),
        "design_id" => compiled.genome.design_id,
        "physics_hash" => compiled.genome.physics_hash,
        "family" => compiled.family,
        "module_ids" => copy(compiled.module_ids),
        "layer_modules" => layers,
        "configuration_class" => layers["core"],
        "symmetry_class" => compiled.genome.symmetry.class,
        "field_periods" => compiled.genome.symmetry.field_periods,
        "sealed_v46_core_reproduced" => true,
        "sealed_v48_ISS04_formula_reproduced" => true,
        "boundary_readiness" => boundary,
        "current_heuristic_f_ren" => checks["current_heuristic_f_ren"],
        "current_iota_proxy" => checks["iota_proxy"],
        "current_performance_response" => current,
        "candidate_effective_ripple_at_rho_2_3_available" => false,
        "candidate_high_order_effective_ripple_converged" => false,
        "candidate_drift_kinetic_transport_validated" => false,
        "candidate_specific_empirical_f_ren_calibrated" => false,
        "candidate_specific_f_ren_value" => nothing,
        "source_domain_complete" => false,
        "candidate_specific_confinement_comparison_authorized" => false,
        "common_baseline_ranking_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promotion_credit" => 0,
        "required_pipeline_stages" => [
            "reconstruct_explicit_3D_boundary_and_profiles_from_candidate_modules",
            "solve_finite_beta_equilibrium_with_resolution_audit",
            "compute_high_order_effective_ripple_at_rho_2_3",
            "fit_source_disjoint_device_level_f_ren_calibration_with_uncertainty",
            "beat_f_ren_equals_one_and_device_mean_baselines_on_leave_one_device_out_validation",
            "validate_candidate_specific_neoclassical_and_turbulent_transport",
        ],
        "applicability_blockers" => [
            "explicit_candidate_fourier_boundary_coefficients_missing",
            "candidate_equilibrium_profiles_missing",
            "candidate_effective_ripple_at_rho_2_3_missing",
            "high_order_effective_ripple_convergence_missing",
            "source_disjoint_device_level_f_ren_calibration_missing",
            "candidate_specific_transport_validation_missing",
        ],
    )
end

function _v51_module_distance(first::AbstractDict, second::AbstractDict)
    a = Set(String.(first["module_ids"]))
    b = Set(String.(second["module_ids"]))
    union_count = length(union(a, b))
    union_count > 0 || return 0.0
    return length(symdiff(a, b)) / union_count
end

function _v51_select_class(records::Vector{Dict{String,Any}}, budget::Int)
    length(records) >= budget || throw(ArgumentError(
        "v51 class has fewer candidates than its acquisition budget"))
    pool = sort!(copy(records); by = record -> Int(record["candidate_index"]))
    average_distance(record) = sum(_v51_module_distance(record, other)
        for other in pool) / max(length(pool) - 1, 1)
    first = sort!(copy(pool); by = record ->
        (-average_distance(record), Int(record["candidate_index"])))[1]
    selected = Dict{String,Any}[first]
    while length(selected) < budget
        remaining = filter(record -> !(record in selected), pool)
        next = sort!(remaining; by = record ->
            (-minimum(_v51_module_distance(record, chosen)
                for chosen in selected), Int(record["candidate_index"])))[1]
        push!(selected, next)
    end
    return selected
end

function _v51_acquisition_queue(records::Vector{Dict{String,Any}};
        per_class_budget::Int = 6)
    representatives = filter(record -> Int(record["sample_ordinal"]) == 1, records)
    queue = Dict{String,Any}[]
    per_class = Dict(configuration => _v51_select_class(
        filter(record -> record["configuration_class"] == configuration,
            representatives), per_class_budget)
        for configuration in _V51_CONFIGURATION_CLASSES)
    rank = 0
    for within_class_rank in 1:per_class_budget
        for configuration in _V51_CONFIGURATION_CLASSES
            rank += 1
            record = per_class[configuration][within_class_rank]
            push!(queue, Dict{String,Any}(
                "acquisition_rank" => rank,
                "within_configuration_class_rank" => within_class_rank,
                "candidate_index" => record["candidate_index"],
                "assembly_id" => record["assembly_id"],
                "design_id" => record["design_id"],
                "physics_hash" => record["physics_hash"],
                "configuration_class" => configuration,
                "module_ids" => copy(record["module_ids"]),
                "selection_method" =>
                    "per_configuration_class_greedy_maximin_over_v17_module_sets_v1",
                "selection_used_performance" => false,
                "selection_used_current_heuristic_f_ren" => false,
                "authorized_action" =>
                    "geometry_reconstruction_and_calibration_evidence_acquisition_only",
                "medium_fidelity_authorized" => false,
                "promotion_credit" => 0,
                "required_pipeline_stages" => copy(record["required_pipeline_stages"]),
            ))
        end
    end
    return queue
end

function _v51_fixture_audit(fixture::AbstractDict, candidate_hashes::Set{String},
        evidence::AbstractDict)
    fixture["artifact_version"] == "stellarator_qs_effective_ripple_evidence_v1" ||
        throw(ArgumentError("v51 unexpected effective-ripple fixture"))
    fixture["evaluation"]["status"] == "pass" || throw(ArgumentError(
        "v51 requires a passing low-order effective-ripple fixture"))
    fixture_genome = parse_genome(fixture["genome"])
    metrics = Dict(String(metric["metric_id"]) => metric
        for metric in fixture["evaluation"]["metrics"])
    maximum_ripple = Float64(metrics[
        "refined_maximum_low_order_effective_ripple"]["value"])
    high_order = metrics["high_order_bounce2d_available"]
    lower, upper = Float64.(evidence["calibration_contract"][
        "published_effective_ripple_relation_domain"])
    return Dict{String,Any}(
        "design_id" => fixture_genome.design_id,
        "physics_hash" => fixture_genome.physics_hash,
        "source_disjoint_from_v46_candidates" =>
            !(fixture_genome.physics_hash in candidate_hashes),
        "low_order_effective_ripple_computation_completed" => true,
        "refined_maximum_low_order_effective_ripple" => maximum_ripple,
        "published_relation_domain" => [lower, upper],
        "all_sampled_radii_below_published_relation_domain" =>
            maximum_ripple < lower,
        "high_order_bounce2d_available" => high_order["value"],
        "high_order_bounce2d_status" => high_order["status"],
        "candidate_f_ren_calibration_authorized" => false,
        "role" => "solver_capability_fixture_only",
    )
end

function stellarator_fren_calibration_queue_v51(
        context::RecoverableCrossTopologyContextV20,
        v46_records::AbstractVector, v48_records::AbstractVector,
        evidence::AbstractDict, fixture::AbstractDict;
        per_class_budget::Int = 6)
    _v51_validate_evidence(evidence)
    v46 = sort!(filter(record -> record["family"] == "stellarator",
        collect(v46_records)); by = record -> Int(record["candidate_index"]))
    v48 = Dict(Int(record["candidate_index"]) => record
        for record in v48_records if record["family"] == "stellarator")
    length(v46) == 288 || throw(ArgumentError(
        "v51 requires the 288 sealed stellarator candidates"))
    length(v48) == 288 || throw(ArgumentError(
        "v51 requires the 288 sealed v48 stellarator audits"))
    records = Dict{String,Any}[]
    for record in v46
        index = Int(record["candidate_index"])
        haskey(v48, index) || throw(ArgumentError(
            "v51 missing v48 record for candidate $index"))
        push!(records, _v51_candidate_record(context, record, v48[index]))
    end
    queue = _v51_acquisition_queue(records;
        per_class_budget = per_class_budget)
    candidate_hashes = Set(String(record["physics_hash"]) for record in records)
    fixture_audit = _v51_fixture_audit(fixture, candidate_hashes, evidence)
    heuristic_values = Float64[record["current_heuristic_f_ren"] for record in records]
    iota_values = Float64[record["current_iota_proxy"] for record in records]
    by_class = Dict{String,Any}()
    for configuration in _V51_CONFIGURATION_CLASSES
        subset = filter(record -> record["configuration_class"] == configuration,
            records)
        selected = filter(record -> record["configuration_class"] == configuration,
            queue)
        by_class[configuration] = Dict{String,Any}(
            "candidate_count" => length(subset),
            "assembly_count" => length(unique(record["assembly_id"]
                for record in subset)),
            "acquisition_queue_count" => length(selected),
            "explicit_boundary_count" => count(record ->
                record["boundary_readiness"][
                    "candidate_boundary_reconstructable_for_DESC"] === true,
                subset),
            "candidate_effective_ripple_count" => count(record ->
                record["candidate_effective_ripple_at_rho_2_3_available"] === true,
                subset),
            "candidate_f_ren_count" => count(record ->
                record["candidate_specific_empirical_f_ren_calibrated"] === true,
                subset),
        )
    end
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "search_version" => "stellarator_fren_calibration_queue_v51",
        "stage" => "sealed_stellarator_fren_readiness_and_structural_acquisition_queue",
        "audit_contract" => Dict{String,Any}(
            "sealed_v46_core_reconstruction_required" => true,
            "sealed_v48_ISS04_reproduction_required" => true,
            "candidate_f_ren_value_emitted" => false,
            "fixture_can_transfer_to_v46_candidate" => false,
            "selection_budget_per_configuration_class" => per_class_budget,
            "selection_uses_performance" => false,
            "selection_uses_current_heuristic_f_ren" => false,
            "experiment_can_promote_candidate" => false,
        ),
        "calibration_contract" => deepcopy(evidence["calibration_contract"]),
        "fixture_audit" => fixture_audit,
        "aggregate" => Dict{String,Any}(
            "input_candidate_count" => 2000,
            "stellarator_candidate_count" => length(records),
            "stellarator_assembly_count" => length(unique(
                record["assembly_id"] for record in records)),
            "configuration_class_count" => length(_V51_CONFIGURATION_CLASSES),
            "sealed_v46_core_reproduced_count" => count(record ->
                record["sealed_v46_core_reproduced"] === true, records),
            "sealed_v48_ISS04_formula_reproduced_count" => count(record ->
                record["sealed_v48_ISS04_formula_reproduced"] === true, records),
            "explicit_candidate_boundary_count" => count(record ->
                record["boundary_readiness"][
                    "candidate_boundary_reconstructable_for_DESC"] === true,
                records),
            "candidate_equilibrium_profile_count" => count(record ->
                record["boundary_readiness"][
                    "candidate_equilibrium_profiles_available"] === true,
                records),
            "candidate_effective_ripple_count" => count(record ->
                record["candidate_effective_ripple_at_rho_2_3_available"] === true,
                records),
            "candidate_high_order_ripple_converged_count" => count(record ->
                record["candidate_high_order_effective_ripple_converged"] === true,
                records),
            "candidate_specific_f_ren_count" => count(record ->
                record["candidate_specific_empirical_f_ren_calibrated"] === true,
                records),
            "source_domain_complete_count" => count(record ->
                record["source_domain_complete"] === true, records),
            "candidate_specific_comparison_authorized_count" => count(record ->
                record["candidate_specific_confinement_comparison_authorized"] === true,
                records),
            "common_baseline_ranking_authorized_count" => count(record ->
                record["common_baseline_ranking_authorized"] === true, records),
            "medium_fidelity_authorized_count" => count(record ->
                record["medium_fidelity_authorized"] === true, records),
            "promotion_count" => count(record ->
                Int(record["promotion_credit"]) > 0, records),
            "current_heuristic_f_ren_range" =>
                [minimum(heuristic_values), maximum(heuristic_values)],
            "current_iota_proxy_range" =>
                [minimum(iota_values), maximum(iota_values)],
            "acquisition_queue_count" => length(queue),
            "acquisition_selection_used_performance_count" => count(record ->
                record["selection_used_performance"] === true, queue),
            "acquisition_selection_used_current_heuristic_f_ren_count" => count(record ->
                record["selection_used_current_heuristic_f_ren"] === true, queue),
            "by_configuration_class" => by_class,
        ),
        "next_actions" => [
            "Reconstruct explicit Fourier boundaries and equilibrium profiles for the 18 selected assemblies without changing their v17 module identities.",
            "Run finite-beta DESC/VMEC and high-order effective-ripple resolution audits at rho=2/3 for the queue.",
            "Build a device-level, source-disjoint ISS04 f_ren calibration dataset with uncertainty and leave-one-device-out baselines.",
            "Treat the ripple-to-f_ren relation only as an uncertain prior and reject extrapolation outside its observed domain.",
            "Validate neoclassical and turbulent transport before reopening candidate confinement comparison or ranking.",
        ],
        "promotion_credit" => Dict{String,Any}(
            "candidate_count" => 0,
            "credit_granted" => false,
            "reason" => "A diverse calibration queue is evidence acquisition planning, not candidate-specific confinement evidence.",
        ),
        "claim_boundary" => _V51_CLAIM_BOUNDARY,
        "candidate_records" => records,
        "acquisition_queue" => queue,
    )
end
