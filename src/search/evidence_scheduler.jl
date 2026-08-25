const _TASK_KINDS = Set((:evaluation, :input_builder))
const _BACKEND_STATUSES = Set((:available, :planned, :blocked))

"""
One auditable unit of evidence acquisition.

`metric_outputs` lists metrics the task can actually compute; deliberately
unknown placeholder metrics must not be listed.  `uncertainty_outputs` is a
subset for which the task supplies an uncertainty suitable for an objective
contract.  Costs are relative budget units, not money or wall-clock promises.
"""
struct EvidenceTaskSpec
    id::String
    version::String
    kind::Symbol
    families::Set{String}
    fidelity::Int
    cost_units::Float64
    backend_status::Symbol
    requirement_support::Dict{String,Symbol}
    metric_outputs::Set{String}
    uncertainty_outputs::Set{String}
    required_field_source_geometry_models::Set{String}
    forbidden_field_source_geometry_models::Set{String}
    prerequisite_task_ids::Vector{String}
    unlock_task_ids::Vector{String}
    claim_ceiling::String

    function EvidenceTaskSpec(id::AbstractString, version::AbstractString,
            kind::Symbol, families, fidelity::Integer, cost_units::Real,
            backend_status::Symbol;
            requirement_support = Dict{String,Symbol}(),
            metric_outputs = String[], uncertainty_outputs = String[],
            required_field_source_geometry_models = String[],
            forbidden_field_source_geometry_models = String[],
            prerequisite_task_ids = String[], unlock_task_ids = String[],
            claim_ceiling::AbstractString = "structural_only")
        kind in _TASK_KINDS || throw(ArgumentError("invalid task kind $kind"))
        backend_status in _BACKEND_STATUSES ||
            throw(ArgumentError("invalid backend status $backend_status"))
        isfinite(cost_units) && cost_units > 0 ||
            throw(ArgumentError("task cost_units must be finite and positive"))
        fidelity >= 0 || throw(ArgumentError("task fidelity must be non-negative"))
        haskey(_CLAIM_LEVELS, String(claim_ceiling)) ||
            throw(ArgumentError("unknown task claim ceiling $claim_ceiling"))
        support = Dict{String,Symbol}(String(key) => Symbol(value)
            for (key, value) in requirement_support)
        all(level -> level in (:proxy, :full), values(support)) ||
            throw(ArgumentError("task requirement support must be :proxy or :full"))
        outputs = Set(String.(collect(metric_outputs)))
        uncertainty = Set(String.(collect(uncertainty_outputs)))
        issubset(uncertainty, outputs) ||
            throw(ArgumentError("uncertainty_outputs must be a subset of metric_outputs"))
        required_geometry_models = Set(String.(collect(
            required_field_source_geometry_models)))
        forbidden_geometry_models = Set(String.(collect(
            forbidden_field_source_geometry_models)))
        isempty(intersect(required_geometry_models, forbidden_geometry_models)) ||
            throw(ArgumentError("required and forbidden geometry models must be disjoint"))
        prereqs = sort!(unique(String.(collect(prerequisite_task_ids))))
        unlocks = sort!(unique(String.(collect(unlock_task_ids))))
        String(id) in prereqs && throw(ArgumentError("task cannot depend on itself"))
        String(id) in unlocks && throw(ArgumentError("task cannot unlock itself"))
        return new(String(id), String(version), kind,
            Set(String.(collect(families))), Int(fidelity), Float64(cost_units),
            backend_status, support, outputs, uncertainty,
            required_geometry_models, forbidden_geometry_models,
            prereqs, unlocks, String(claim_ceiling))
    end
end

"Actual observed metric metadata; it never contains a surrogate prediction."
struct ObservedMetricEvidence
    metric_id::String
    value::Any
    unit::String
    uncertainty::Union{Nothing,Float64}
    fidelity::Int
    status::Symbol
    input_hash::String
    run_hash::String
end

"Evidence tied to an exact evaluator version and exact genome physics hash."
struct CompletedEvidence
    task_id::String
    task_version::String
    design_id::String
    input_hash::String
    run_hash::String
    status::Symbol
    fidelity::Int
    claim_ceiling::String
    metrics::Vector{ObservedMetricEvidence}
end

function CompletedEvidence(bundle::EvaluationBundle)
    versions = unique(metric.solver_version for metric in bundle.metrics
        if metric.solver_name == bundle.evaluator_id)
    version = length(versions) == 1 ? only(versions) : ""
    metrics = ObservedMetricEvidence[
        ObservedMetricEvidence(metric.metric_id, metric.value, metric.unit,
            metric.uncertainty, metric.fidelity, metric.status,
            metric.input_hash, metric.run_hash)
        for metric in bundle.metrics
    ]
    return CompletedEvidence(bundle.evaluator_id, version, bundle.design_id,
        bundle.input_hash, bundle.run_hash, bundle.status, bundle.fidelity,
        bundle.claim_ceiling, metrics)
end

function completed_evidence_from_dict(raw)
    data = _plain_json(raw)
    metrics_raw = get(data, "metrics", Any[])
    metrics = ObservedMetricEvidence[]
    versions = String[]
    for item in metrics_raw
        uncertainty_raw = get(item, "uncertainty", nothing)
        uncertainty = uncertainty_raw === nothing ? nothing : Float64(uncertainty_raw)
        push!(metrics, ObservedMetricEvidence(
            String(item["metric_id"]), get(item, "value", nothing),
            String(get(item, "unit", "1")), uncertainty,
            Int(item["fidelity"]), Symbol(item["status"]),
            String(item["input_hash"]), String(item["run_hash"])))
        get(item, "solver_name", "") == data["evaluator_id"] &&
            push!(versions, String(get(item, "solver_version", "")))
    end
    unique_versions = unique(filter(!isempty, versions))
    version = length(unique_versions) == 1 ? only(unique_versions) :
        String(get(data, "evaluator_version", ""))
    return CompletedEvidence(String(data["evaluator_id"]), version,
        String(data["design_id"]), String(data["input_hash"]),
        String(data["run_hash"]), Symbol(data["status"]), Int(data["fidelity"]),
        String(data["claim_ceiling"]), metrics)
end

struct EvidenceTaskRecommendation
    design_id::String
    family::String
    physics_hash::String
    descriptor::String
    task_id::String
    task_version::String
    execution_status::Symbol
    cost_units::Float64
    acquisition_utility::Float64
    diversity_bonus::Float64
    cost_aware_score::Float64
    targeted_hard_constraints::Vector{String}
    targeted_objectives::Vector{String}
    targeted_requirements::Vector{String}
    unlocks::Vector{String}
    reasons::Vector{String}
end

struct EvidenceScheduleResult
    contract_id::String
    budget_units::Float64
    selected_cost_units::Float64
    selected::Vector{EvidenceTaskRecommendation}
    deferred_executable::Vector{EvidenceTaskRecommendation}
    development_priorities::Vector{Dict{String,Any}}
    unschedulable_gaps::Vector{Dict{String,Any}}
    candidate_audits::Vector{Dict{String,Any}}
    all_recommendations::Vector{EvidenceTaskRecommendation}
    task_catalog::Vector{EvidenceTaskSpec}
    completed_evidence::Vector{CompletedEvidence}
end

function _all_families()
    return Set(keys(default_family_registry().specs))
end

"Transparent baseline catalog. Planned and blocked entries are not executable."
function default_evidence_task_catalog()
    all_families = _all_families()
    return EvidenceTaskSpec[
        EvidenceTaskSpec("tokamak_axisymmetric_proxy_v1", "1.0.0", :evaluation,
            ["tokamak_axisymmetric"], 0, 1.0, :available;
            requirement_support = Dict(
                "guiding_center_orbits" => :proxy,
                "error_field_sensitivity" => :proxy,
                "finite_build_coils" => :proxy,
                "quench" => :proxy),
            metric_outputs = ["boundary_bn_rms_proxy", "boundary_bn_max_proxy",
                "q95_proxy", "q_spread_proxy", "toroidal_field_ripple_proxy",
                "engineering_feasible_proxy", "engineering_score_proxy",
                "current_utilization_proxy", "stress_utilization_proxy",
                "clearance_utilization_proxy", "quench_utilization_proxy",
                "thermal_hydraulic_utilization_proxy", "fatigue_utilization_proxy",
                "flux_utilization_proxy"], claim_ceiling = "screening_only"),
        EvidenceTaskSpec("mirror_beam_0d_v1", "1.0.0", :evaluation,
            ["magnetic_mirror"], 0, 1.0, :available;
            requirement_support = Dict(
                "fokker_planck" => :proxy, "flr_stability" => :proxy,
                "fast_ion_adiabaticity" => :proxy, "dclc" => :proxy,
                "actuator_power" => :proxy, "beam_absorption" => :proxy,
                "fusion_gain" => :proxy),
            metric_outputs = ["fusion_gain", "fusion_power",
                "fusion_gain_proxy", "fusion_power_proxy",
                "absorbed_beam_power_proxy", "effective_plasma_volume",
                "beta_limit_feasible_proxy", "beam_absorption_90pct_feasible_proxy",
                "dclc_size_feasible_proxy", "flr_m2_feasible_proxy",
                "fast_ion_adiabaticity_feasible_proxy",
                "peak_field_25T_feasible_proxy", "high_mirror_ratio_feasible_proxy"],
            uncertainty_outputs = ["fusion_gain", "fusion_power",
                "fusion_gain_proxy", "fusion_power_proxy",
                "absorbed_beam_power_proxy", "effective_plasma_volume"],
            claim_ceiling = "physics_proxy"),
        EvidenceTaskSpec("tokamak_free_boundary_freegs_v1", "1.0.0", :evaluation,
            ["tokamak_axisymmetric"], 1, 8.0, :available;
            requirement_support = Dict(
                "free_boundary_grad_shafranov" => :full,
                "axisymmetric_force_balance" => :full,
                "free_boundary_shape_control" => :full),
            metric_outputs = ["free_boundary_equilibrium_converged",
                "axisymmetric_force_balance_feasible",
                "grad_shafranov_residual_l2_relative", "plasma_volume", "q_95",
                "beta_n", "max_abs_pf_coil_current"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("tokamak_pf_static_robustness_v1", "1.0.0", :evaluation,
            ["tokamak_axisymmetric"], 1, 20.0, :available;
            requirement_support = Dict(
                "free_boundary_static_perturbation_resolve" => :full,
                "pf_static_control_authority" => :proxy,
                "error_field_sensitivity" => :proxy,
                "vertical_response" => :proxy,
                "finite_build_coils" => :proxy,
                "structural_fea" => :proxy),
            metric_outputs = ["pf_static_robustness_summary",
                "static_perturbation_cases_passed",
                "worst_normalized_axis_displacement",
                "worst_pf_current_amplification",
                "worst_paired_current_imbalance_fraction",
                "pf_static_robustness_disposition"],
            required_field_source_geometry_models = ["freegs_filament_coil_v1"],
            prerequisite_task_ids = ["tokamak_free_boundary_freegs_v1"],
            unlock_task_ids = ["tokamak_mhd_stability_v1"],
            claim_ceiling = "physics_proxy"),
        EvidenceTaskSpec("stellarator_fixed_boundary_desc_w7x_v1", "1.0.0",
            :evaluation, ["stellarator"], 1, 40.0, :available;
            requirement_support = Dict("vmec_or_desc" => :full,
                "finite_beta_equilibrium" => :full,
                "three_dimensional_force_balance" => :full),
            metric_outputs = ["fixed_boundary_equilibrium_converged",
                "three_dimensional_force_balance_feasible",
                "force_balance_residual_normalized_magnetic", "plasma_volume",
                "volume_average_beta", "aspect_ratio", "rotational_transform_axis",
                "rotational_transform_095"], claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("stellarator_fixed_boundary_desc_fourier_v1", "1.0.0",
            :evaluation, ["stellarator"], 1, 45.0, :available;
            requirement_support = Dict(
                "explicit_fourier_boundary" => :full,
                "vmec_or_desc" => :full,
                "finite_beta_equilibrium" => :full,
                "three_dimensional_force_balance" => :full),
            metric_outputs = ["fixed_boundary_equilibrium_converged",
                "three_dimensional_force_balance_feasible",
                "nested_flux_surfaces_feasible",
                "positive_coordinate_jacobian_feasible",
                "force_balance_residual_volume_average",
                "force_balance_residual_normalized_magnetic",
                "minimum_sampled_sqrt_g", "continuation_state_count",
                "boundary_mode_count", "plasma_volume", "volume_average_beta",
                "major_radius", "minor_radius", "aspect_ratio",
                "rotational_transform_axis", "rotational_transform_095",
                "field_peak_to_peak_over_mean_mid",
                "field_peak_to_peak_over_mean_095"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("mirror_isotropic_pleiades_wham_v1", "1.0.0",
            :evaluation, ["magnetic_mirror"], 1, 3.0, :available;
            requirement_support = Dict("axisymmetric_green_function_fields" => :full,
                "isotropic_mirror_equilibrium" => :full,
                "finite_beta_equilibrium" => :full),
            metric_outputs = ["axisymmetric_vacuum_field_feasible",
                "isotropic_equilibrium_converged", "finite_beta_equilibrium_feasible",
                "fixed_point_flux_residual_l2",
                "finite_difference_force_balance_relative_l2",
                "vacuum_center_field", "vacuum_sampled_mirror_ratio",
                "prescribed_axis_pressure", "relative_flux_change_l2",
                "plasma_diamagnetic_current_total"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("tokamak_freegs_input_builder_v1", "0.1.0",
            :input_builder, ["tokamak_axisymmetric"], 0, 5.0, :planned;
            unlock_task_ids = ["tokamak_free_boundary_freegs_v1"]),
        EvidenceTaskSpec("stellarator_fourier_input_builder_v1", "1.0.0",
            :input_builder, ["stellarator"], 0, 8.0, :available;
            unlock_task_ids = ["stellarator_fixed_boundary_desc_fourier_v1"]),
        EvidenceTaskSpec("stellarator_sampled_ideal_mhd_stability_desc_v1",
            "1.0.0", :evaluation, ["stellarator"], 1, 55.0, :available;
            requirement_support = Dict(
                "explicit_fourier_boundary" => :full,
                "finite_beta_equilibrium" => :full,
                "mercier" => :proxy,
                "ballooning" => :proxy,
                "sampled_mercier_criterion" => :full,
                "sampled_infinite_n_ballooning" => :full),
            metric_outputs = ["sampled_stability_computation_completed",
                "sampled_stability_equilibrium_converged",
                "minimum_sampled_mercier_D_normalized",
                "sampled_mercier_favorable",
                "sampled_mercier_positive_fraction",
                "maximum_sampled_infinite_n_ballooning_lambda",
                "sampled_infinite_n_ballooning_favorable",
                "sampled_local_ideal_mhd_favorable",
                "mercier_rho_sample_count",
                "ballooning_field_line_scan_count",
                "ballooning_field_line_point_count"],
            prerequisite_task_ids = ["stellarator_fixed_boundary_desc_fourier_v1"],
            unlock_task_ids = ["stellarator_qs_effective_ripple_desc_v1",
                "stellarator_stability_transport_v1"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("stellarator_qs_effective_ripple_desc_v1", "1.0.0",
            :evaluation, ["stellarator"], 1, 40.0, :available;
            requirement_support = Dict(
                "explicit_fourier_boundary" => :full,
                "finite_beta_equilibrium" => :full,
                "boozer_transform" => :full,
                "sampled_quasisymmetry_spectrum" => :full,
                "neoclassical_transport" => :proxy),
            metric_outputs = ["sampled_boozer_spectrum_computation_completed",
                "sampled_boozer_spectrum_resolution_audit_passed",
                "refined_sampled_qa_symmetry_breaking_rms",
                "refined_sampled_qh_symmetry_breaking_rms",
                "low_order_effective_ripple_computation_completed",
                "low_order_effective_ripple_resolution_audit_passed",
                "refined_maximum_low_order_effective_ripple",
                "refined_rms_low_order_effective_ripple",
                "low_order_effective_ripple_reference_met",
                "high_order_bounce2d_available"],
            prerequisite_task_ids = [
                "stellarator_sampled_ideal_mhd_stability_desc_v1"],
            unlock_task_ids = ["stellarator_stability_transport_v1"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("stellarator_surface_current_regcoil_desc_v1",
            "1.0.0", :evaluation, ["stellarator"], 1, 65.0, :available;
            requirement_support = Dict(
                "explicit_fourier_boundary" => :full,
                "finite_beta_equilibrium" => :full,
                "constant_offset_winding_surface" => :full,
                "continuous_surface_current_inverse_design" => :full,
                "finite_build_coils" => :proxy),
            metric_outputs = ["continuous_surface_current_computation_completed",
                "constant_offset_winding_surface_gates_passed",
                "minimum_sampled_plasma_winding_surface_separation",
                "minimum_continuous_surface_current_bn_rms_normalized",
                "surface_current_reference_normalized_bn_rms_met",
                "minimum_surface_current_k_rms_meeting_bn_reference",
                "surface_current_compromise_bn_rms_normalized",
                "surface_current_compromise_k_rms",
                "surface_current_compromise_k_max",
                "surface_current_compromise_phi_spectral_complexity",
                "surface_current_regularization_scan_count"],
            prerequisite_task_ids = [
                "stellarator_sampled_ideal_mhd_stability_desc_v1",
                "stellarator_qs_effective_ripple_desc_v1"],
            unlock_task_ids = ["stellarator_discrete_coil_cut_desc_v1"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("stellarator_discrete_coil_cut_desc_v1",
            "1.0.0", :evaluation, ["stellarator"], 1, 50.0, :available;
            requirement_support = Dict(
                "explicit_fourier_boundary" => :full,
                "finite_beta_equilibrium" => :full,
                "continuous_surface_current_inverse_design" => :full,
                "finite_discrete_coil_contours" => :full,
                "finite_build_coils" => :proxy),
            metric_outputs = ["discrete_coil_contours_created",
                "coil_shape_optimization_performed",
                "unoptimized_discrete_coil_count_scan_count",
                "minimum_unoptimized_discrete_coil_bn_rms_normalized",
                "continuous_to_discrete_bn_degradation_factor",
                "unoptimized_discrete_coil_bn_reference_met_by_any_cut",
                "best_bn_cut_total_physical_coil_count",
                "best_bn_cut_minimum_coil_coil_distance",
                "best_bn_cut_minimum_plasma_coil_distance",
                "best_bn_cut_maximum_sampled_curvature",
                "best_bn_cut_total_physical_coil_length",
                "unoptimized_discrete_coil_resolution_audit_passed"],
            prerequisite_task_ids = [
                "stellarator_surface_current_regcoil_desc_v1"],
            unlock_task_ids = ["stellarator_discrete_coil_optimization_desc_v1"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("mirror_pleiades_input_builder_v1", "0.1.0",
            :input_builder, ["magnetic_mirror"], 0, 5.0, :planned;
            unlock_task_ids = ["mirror_isotropic_pleiades_wham_v1"]),
        EvidenceTaskSpec("tokamak_mhd_stability_v1", "0.1.0", :evaluation,
            ["tokamak_axisymmetric", "tokamak_3d_hybrid"], 1, 30.0, :planned;
            requirement_support = Dict("ideal_mhd" => :full,
                "resistive_mhd" => :full, "vertical_stability" => :full),
            metric_outputs = ["tokamak_mhd_stability_margin"],
            uncertainty_outputs = ["tokamak_mhd_stability_margin"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("stellarator_stability_transport_v1", "0.1.0",
            :evaluation, ["stellarator", "tokamak_3d_hybrid"], 1, 45.0, :planned;
            requirement_support = Dict("finite_n_ideal_mhd" => :full,
                "resistive_mhd" => :full, "kinetic_ballooning" => :full,
                "neoclassical_transport" => :full, "alpha_orbits" => :full),
            metric_outputs = ["finite_n_ideal_mhd_stability_margin",
                "resistive_mhd_stability_margin", "kinetic_ballooning_margin",
                "neoclassical_transport_loss", "alpha_orbit_loss_fraction"],
            uncertainty_outputs = ["finite_n_ideal_mhd_stability_margin",
                "resistive_mhd_stability_margin", "kinetic_ballooning_margin",
                "neoclassical_transport_loss", "alpha_orbit_loss_fraction"],
            prerequisite_task_ids = [
                "stellarator_sampled_ideal_mhd_stability_desc_v1"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("stellarator_discrete_coil_optimization_desc_v1", "1.0.0",
            :evaluation, ["stellarator"], 1, 65.0, :available;
            requirement_support = Dict("finite_build_coils" => :proxy,
                "optimized_filament_coils" => :full,
                "line_current_geometry" => :full,
                "coil_curvature" => :full, "coil_separation" => :full,
                "plasma_coil_distance" => :full, "coil_length" => :full,
                "assembly_tolerance" => :proxy),
            metric_outputs = ["coil_shape_optimization_performed",
                "optimized_discrete_line_current_geometry_feasible",
                "optimized_discrete_coil_resolution_audit_passed",
                "deterministic_one_mm_tolerance_screen_passed",
                "deterministic_three_mm_stress_screen_passed",
                "optimized_discrete_coil_count",
                "refined_normalized_bn_rms_from_discrete_coils",
                "refined_source_relative_bn_improvement",
                "refined_minimum_coil_coil_distance",
                "refined_minimum_plasma_coil_distance",
                "refined_maximum_sampled_curvature",
                "refined_maximum_sampled_torsion",
                "refined_maximum_individual_coil_length",
                "refined_total_physical_coil_length",
                "one_mm_maximum_relative_bn_degradation"],
            uncertainty_outputs = ["refined_normalized_bn_rms_from_discrete_coils",
                "refined_minimum_coil_coil_distance",
                "refined_minimum_plasma_coil_distance",
                "refined_maximum_sampled_curvature",
                "refined_maximum_sampled_torsion",
                "refined_total_physical_coil_length"],
            prerequisite_task_ids = [
                "stellarator_discrete_coil_cut_desc_v1"],
            unlock_task_ids = ["stellarator_finite_build_coil_proxy_desc_v1"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("stellarator_finite_build_coil_proxy_desc_v1", "1.0.0",
            :evaluation, ["stellarator"], 1, 55.0, :available;
            requirement_support = Dict("finite_build_coils" => :proxy,
                "winding_pack_clearance" => :proxy,
                "winding_pack_current_density" => :proxy,
                "mutual_coil_electromagnetic_load" => :proxy),
            metric_outputs = ["finite_build_winding_pack_scan_completed",
                "finite_build_anchor_resolution_audit_passed",
                "refined_square_winding_pack_width",
                "refined_finite_build_bn_correction_rms_normalized",
                "refined_finite_build_bn_rms_upper_bound",
                "refined_finite_build_bn_comparison_reference_met",
                "equivalent_winding_pack_engineering_current_density",
                "circumscribed_pack_coil_coil_clearance_lower_bound",
                "circumscribed_pack_plasma_coil_clearance_lower_bound",
                "maximum_mutual_coil_field_at_centerline",
                "maximum_mutual_coil_lorentz_line_load"],
            uncertainty_outputs = [
                "refined_finite_build_bn_correction_rms_normalized",
                "maximum_mutual_coil_field_at_centerline",
                "maximum_mutual_coil_lorentz_line_load"],
            prerequisite_task_ids = [
                "stellarator_discrete_coil_optimization_desc_v1"],
            unlock_task_ids = ["stellarator_regularized_coil_force_desc_v1"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("stellarator_regularized_coil_force_desc_v1", "1.0.0",
            :evaluation, ["stellarator"], 1, 60.0, :available;
            requirement_support = Dict("finite_build_coils" => :proxy,
                "regularized_rectangular_coil_self_force" => :proxy,
                "coil_inductance" => :proxy,
                "coil_only_stored_magnetic_energy" => :proxy,
                "total_coil_electromagnetic_load" => :proxy),
            metric_outputs = [
                "regularized_rectangular_coil_force_resolution_audit_passed",
                "regularized_coil_self_force_computed",
                "maximum_regularized_self_force_field",
                "maximum_self_lorentz_line_load",
                "rms_self_lorentz_line_load",
                "maximum_total_coil_lorentz_line_load",
                "rms_total_coil_lorentz_line_load",
                "coil_only_stored_magnetic_energy",
                "equivalent_common_current_inductance",
                "maximum_conductor_width_times_curvature"],
            uncertainty_outputs = ["maximum_self_lorentz_line_load",
                "maximum_total_coil_lorentz_line_load",
                "coil_only_stored_magnetic_energy"],
            prerequisite_task_ids = [
                "stellarator_finite_build_coil_proxy_desc_v1"],
            unlock_task_ids = ["stellarator_rectangular_internal_field_desc_v1"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("stellarator_rectangular_internal_field_desc_v1", "1.0.0",
            :evaluation, ["stellarator"], 1, 70.0, :available;
            requirement_support = Dict("finite_build_coils" => :proxy,
                "rectangular_conductor_internal_field" => :proxy,
                "peak_conductor_magnetic_field" => :proxy,
                "plasma_current_field_at_conductor" => :proxy),
            metric_outputs = [
                "rectangular_internal_field_resolution_verified",
                "peak_internal_conductor_field_computed",
                "plasma_current_field_at_conductor_computed",
                "maximum_internal_self_field",
                "maximum_other_coil_field",
                "maximum_plasma_current_field",
                "maximum_coil_only_internal_field",
                "maximum_total_internal_field_including_plasma"],
            uncertainty_outputs = ["maximum_internal_self_field",
                "maximum_other_coil_field", "maximum_plasma_current_field",
                "maximum_coil_only_internal_field",
                "maximum_total_internal_field_including_plasma"],
            prerequisite_task_ids = [
                "stellarator_regularized_coil_force_desc_v1"],
            unlock_task_ids = String[],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("unified_cross_family_screen_v1", "1.0.0",
            :evaluation, all_families, 0, 5.0, :available;
            requirement_support = Dict("equilibrium" => :proxy,
                "basic_constraints" => :proxy, "stability" => :proxy,
                "particle_loss" => :proxy, "fusion_gain" => :proxy,
                "actuator_power" => :proxy, "finite_build_coils" => :proxy,
                "coil_stress" => :proxy, "shielding" => :proxy,
                "maintenance_access" => :proxy, "power_balance" => :proxy,
                "manufacturing_tolerance" => :proxy,
                "error_field_sensitivity" => :proxy),
            metric_outputs = ["temporarily_plausible_under_proxy_contract",
                "minimum_stability_margin_proxy", "particle_loss_fraction_proxy",
                "fusion_power_W", "fusion_gain_proxy", "net_electric_power_W",
                "peak_conductor_field_T", "support_stress_proxy_Pa",
                "robustness_pass_fraction"],
            uncertainty_outputs = ["minimum_stability_margin_proxy",
                "particle_loss_fraction_proxy", "fusion_power_W",
                "net_electric_power_W", "support_stress_proxy_Pa"],
            unlock_task_ids = ["cross_family_stability_aggregator_v1",
                "cross_family_burning_plasma_systems_v1",
                "cross_family_engineering_v1"],
            claim_ceiling = "physics_proxy"),
        EvidenceTaskSpec("mirror_reduced_orbit_review_v1", "1.0.0",
            :evaluation, ["magnetic_mirror"], 1, 8.0, :available;
            requirement_support = Dict(
                "field_line_and_particle_following" => :proxy,
                "magnetic_loss_cone" => :full,
                "fast_ion_adiabaticity" => :proxy),
            metric_outputs = ["magnetic_only_prompt_loss_fraction",
                "analytic_loss_cone_fraction",
                "orbit_ensemble_resolution_audit_passed",
                "thermal_gyroradius", "guiding_center_scale_ratio",
                "representative_collisionless_bounce_time",
                "reduced_mid_fidelity_disposition"],
            uncertainty_outputs = ["magnetic_only_prompt_loss_fraction"],
            unlock_task_ids = ["mirror_finite_coil_geometry_v1"],
            claim_ceiling = "physics_proxy"),
        EvidenceTaskSpec("mirror_finite_coil_geometry_v1", "1.0.0",
            :evaluation, ["magnetic_mirror"], 1, 18.0, :available;
            requirement_support = Dict(
                "finite_build_coils" => :proxy,
                "line_current_geometry" => :full,
                "axisymmetric_green_function_fields" => :full,
                "minimum_b_transverse_well" => :proxy,
                "field_line_and_particle_following" => :proxy,
                "coil_curvature" => :proxy,
                "coil_separation" => :proxy,
                "engineering_current_density" => :proxy,
                "peak_conductor_field" => :proxy,
                "assembly_tolerance" => :proxy,
                "structural_fea" => :proxy),
            metric_outputs = ["vacuum_axis_center_field",
                "vacuum_sampled_mirror_ratio", "axis_field_rms_relative_error",
                "minimum_sampled_transverse_well_fraction",
                "open_field_line_integrity_passed",
                "refined_peak_winding_field",
                "finite_build_field_resolution_audit_passed",
                "maximum_engineering_current_density",
                "minimum_declared_coil_clearance_margin",
                "membrane_support_stress_proxy",
                "finite_coil_geometry_disposition"],
            uncertainty_outputs = ["refined_peak_winding_field"],
            forbidden_field_source_geometry_models = [
                "split_ioffe_saddle_pair",
                "continuous_baseball_seam_pair",
                "yin_yang_end_anchor_pair",
            ],
            prerequisite_task_ids = ["mirror_reduced_orbit_review_v1"],
            unlock_task_ids = ["mirror_anisotropic_equilibrium_v1"],
            claim_ceiling = "physics_proxy"),
        EvidenceTaskSpec("mirror_split_ioffe_saddle_pair_vacuum_geometry_v1",
            "1.0.0", :evaluation, ["magnetic_mirror"], 1, 24.0, :available;
            requirement_support = Dict(
                "finite_build_coils" => :proxy,
                "line_current_geometry" => :full,
                "minimum_b_transverse_well" => :proxy,
                "field_line_and_particle_following" => :proxy,
                "coil_curvature" => :proxy,
                "coil_separation" => :proxy,
                "engineering_current_density" => :proxy,
                "peak_conductor_field" => :proxy,
                "structural_fea" => :proxy),
            metric_outputs = ["vacuum_axis_center_field",
                "vacuum_sampled_mirror_ratio",
                "minimum_sampled_transverse_well_fraction",
                "open_field_line_integrity_passed",
                "refined_peak_winding_field",
                "finite_build_field_resolution_audit_passed",
                "maximum_engineering_current_density",
                "minimum_declared_coil_clearance_margin",
                "membrane_support_stress_proxy",
                "layout_specific_vacuum_geometry_disposition"],
            uncertainty_outputs = ["refined_peak_winding_field"],
            required_field_source_geometry_models = [
                "split_ioffe_saddle_pair"],
            prerequisite_task_ids = ["unified_cross_family_screen_v1"],
            claim_ceiling = "physics_proxy"),
        EvidenceTaskSpec("mirror_continuous_baseball_seam_pair_vacuum_geometry_v1",
            "1.0.0", :evaluation, ["magnetic_mirror"], 1, 24.0, :available;
            requirement_support = Dict(
                "finite_build_coils" => :proxy,
                "line_current_geometry" => :full,
                "minimum_b_transverse_well" => :proxy,
                "field_line_and_particle_following" => :proxy,
                "coil_curvature" => :proxy,
                "coil_separation" => :proxy,
                "engineering_current_density" => :proxy,
                "peak_conductor_field" => :proxy,
                "structural_fea" => :proxy),
            metric_outputs = ["vacuum_axis_center_field",
                "vacuum_sampled_mirror_ratio",
                "minimum_sampled_transverse_well_fraction",
                "open_field_line_integrity_passed",
                "refined_peak_winding_field",
                "finite_build_field_resolution_audit_passed",
                "maximum_engineering_current_density",
                "minimum_declared_coil_clearance_margin",
                "membrane_support_stress_proxy",
                "layout_specific_vacuum_geometry_disposition"],
            uncertainty_outputs = ["refined_peak_winding_field"],
            required_field_source_geometry_models = [
                "continuous_baseball_seam_pair"],
            prerequisite_task_ids = ["unified_cross_family_screen_v1"],
            claim_ceiling = "physics_proxy"),
        EvidenceTaskSpec("mirror_yin_yang_end_anchor_pair_vacuum_geometry_v1",
            "1.0.0", :evaluation, ["magnetic_mirror"], 1, 24.0, :available;
            requirement_support = Dict(
                "finite_build_coils" => :proxy,
                "line_current_geometry" => :full,
                "minimum_b_transverse_well" => :proxy,
                "field_line_and_particle_following" => :proxy,
                "coil_curvature" => :proxy,
                "coil_separation" => :proxy,
                "engineering_current_density" => :proxy,
                "peak_conductor_field" => :proxy,
                "structural_fea" => :proxy),
            metric_outputs = ["vacuum_axis_center_field",
                "vacuum_sampled_mirror_ratio",
                "minimum_sampled_transverse_well_fraction",
                "open_field_line_integrity_passed",
                "refined_peak_winding_field",
                "finite_build_field_resolution_audit_passed",
                "maximum_engineering_current_density",
                "minimum_declared_coil_clearance_margin",
                "membrane_support_stress_proxy",
                "layout_specific_vacuum_geometry_disposition"],
            uncertainty_outputs = ["refined_peak_winding_field"],
            required_field_source_geometry_models = [
                "yin_yang_end_anchor_pair"],
            prerequisite_task_ids = ["unified_cross_family_screen_v1"],
            claim_ceiling = "physics_proxy"),
        EvidenceTaskSpec("mirror_anisotropic_equilibrium_v1", "0.1.0",
            :evaluation, ["magnetic_mirror"], 1, 35.0, :blocked;
            requirement_support = Dict("anisotropic_mirror_equilibrium" => :full,
                "finite_beta_equilibrium" => :full),
            metric_outputs = ["anisotropic_equilibrium_feasible"],
            prerequisite_task_ids = ["mirror_finite_coil_geometry_v1"],
            unlock_task_ids = ["mirror_stability_transport_v1"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("mirror_stability_transport_v1", "0.1.0", :evaluation,
            ["magnetic_mirror"], 1, 40.0, :planned;
            requirement_support = Dict("interchange_growth" => :full,
                "ballooning" => :full, "dclc" => :full, "aic" => :full,
                "electron_heat_loss" => :full, "ion_end_loss" => :full),
            metric_outputs = ["interchange_stability_margin",
                "ballooning_stability_margin", "dclc_stability_margin",
                "aic_stability_margin", "particle_confinement_time",
                "end_loss_power"],
            uncertainty_outputs = ["interchange_stability_margin",
                "ballooning_stability_margin", "dclc_stability_margin",
                "aic_stability_margin", "particle_confinement_time",
                "end_loss_power"],
            prerequisite_task_ids = ["mirror_anisotropic_equilibrium_v1"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("cross_family_stability_aggregator_v1", "0.1.0",
            :evaluation, all_families, 1, 10.0, :planned;
            metric_outputs = ["minimum_stability_margin",
                "plasma_stability_feasible"],
            uncertainty_outputs = ["minimum_stability_margin"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("cross_family_burning_plasma_systems_v1", "0.1.0",
            :evaluation, all_families, 1, 25.0, :planned;
            requirement_support = Dict("fusion_gain" => :full,
                "actuator_power" => :full),
            metric_outputs = ["fusion_power", "fusion_gain"],
            uncertainty_outputs = ["fusion_power", "fusion_gain"],
            claim_ceiling = "physics_concept"),
        EvidenceTaskSpec("cross_family_engineering_v1", "0.1.0", :evaluation,
            all_families, 1, 35.0, :planned;
            requirement_support = Dict("finite_build_coils" => :full,
                "coil_stress" => :full, "quench" => :full,
                "stray_field" => :full, "peak_heat_flux" => :full),
            metric_outputs = ["device_complexity_index", "engineering_feasible"],
            uncertainty_outputs = ["device_complexity_index"],
            claim_ceiling = "engineering_concept"),
    ]
end

function _validate_task_catalog(tasks::Vector{EvidenceTaskSpec})
    ids = getfield.(tasks, :id)
    length(unique(ids)) == length(ids) || throw(ArgumentError("duplicate evidence task ID"))
    known = Set(ids)
    for task in tasks
        all(id -> id in known, task.prerequisite_task_ids) ||
            throw(ArgumentError("task $(task.id) has unknown prerequisite"))
        all(id -> id in known, task.unlock_task_ids) ||
            throw(ArgumentError("task $(task.id) has unknown unlock target"))
    end
    return nothing
end

_terminal_evidence(evidence::CompletedEvidence) = evidence.status in (:pass, :fail)

_task_version_matches(observed::String, catalog::String) =
    observed == catalog || startswith(observed, catalog * "+")

function _exact_evidence(task::EvidenceTaskSpec, genome::Genome,
        completed::Vector{CompletedEvidence})
    return filter(item -> item.task_id == task.id &&
        _task_version_matches(item.task_version, task.version) &&
        item.input_hash == genome.physics_hash &&
        _terminal_evidence(item), completed)
end

function _observed_metrics(genome::Genome, completed::Vector{CompletedEvidence})
    result = Tuple{ObservedMetricEvidence,String}[]
    for evidence in completed
        evidence.input_hash == genome.physics_hash || continue
        _terminal_evidence(evidence) || continue
        for metric in evidence.metrics
            metric.input_hash == genome.physics_hash || continue
            push!(result, (metric, evidence.claim_ceiling))
        end
    end
    return result
end

function _objective_observed(spec::ObjectiveSpec, observed,
        minimum_claim_level::String)
    return any(observed) do item
        metric, claim = item
        metric.metric_id == spec.metric_id && metric.status == :pass &&
            metric.value isa Real && !(metric.value isa Bool) && isfinite(metric.value) &&
            metric.unit == spec.unit && metric.fidelity >= spec.minimum_fidelity &&
            (!spec.require_uncertainty || metric.uncertainty !== nothing) &&
            _claim_at_least(claim, minimum_claim_level)
    end
end

function _constraint_value_satisfied(spec::ConstraintSpec, value)
    if spec.relation == :is_true
        return value === true
    elseif spec.relation == :is_false
        return value === false
    elseif !(value isa Real) || value isa Bool
        return false
    elseif spec.relation == :ge
        return value >= spec.threshold
    elseif spec.relation == :le
        return value <= spec.threshold
    end
    return value == spec.threshold
end

function _constraint_observed(spec::ConstraintSpec, observed,
        minimum_claim_level::String)
    return any(observed) do item
        metric, claim = item
        metric.metric_id == spec.metric_id && metric.status == :pass &&
            metric.unit == spec.unit && metric.fidelity >= spec.minimum_fidelity &&
            (!spec.require_uncertainty || metric.uncertainty !== nothing) &&
            _claim_at_least(claim, minimum_claim_level) &&
            _constraint_value_satisfied(spec, metric.value)
    end
end

function _completed_requirement_support(genome::Genome,
        tasks::Vector{EvidenceTaskSpec}, completed::Vector{CompletedEvidence})
    support = Dict(requirement => :missing for requirement in _requirements(genome))
    rank = Dict(:missing => 0, :proxy => 1, :full => 2)
    by_id = Dict(task.id => task for task in tasks)
    for evidence in completed
        evidence.input_hash == genome.physics_hash || continue
        _terminal_evidence(evidence) || continue
        task = get(by_id, evidence.task_id, nothing)
        task === nothing && continue
        _task_version_matches(evidence.task_version, task.version) || continue
        for (requirement, level) in task.requirement_support
            haskey(support, requirement) || continue
            rank[level] > rank[support[requirement]] && (support[requirement] = level)
        end
    end
    return support
end

function _task_contract_targets(task::EvidenceTaskSpec,
        missing_objectives::Vector{ObjectiveSpec},
        missing_constraints::Vector{ConstraintSpec}, contract::ObjectiveContract)
    objectives = String[]
    constraints = String[]
    for spec in missing_objectives
        spec.metric_id in task.metric_outputs || continue
        task.fidelity >= spec.minimum_fidelity || continue
        !spec.require_uncertainty || spec.metric_id in task.uncertainty_outputs || continue
        _claim_at_least(task.claim_ceiling, contract.minimum_claim_level) || continue
        push!(objectives, spec.metric_id)
    end
    for spec in missing_constraints
        spec.metric_id in task.metric_outputs || continue
        task.fidelity >= spec.minimum_fidelity || continue
        !spec.require_uncertainty || spec.metric_id in task.uncertainty_outputs || continue
        _claim_at_least(task.claim_ceiling, contract.minimum_claim_level) || continue
        push!(constraints, spec.metric_id)
    end
    return sort!(objectives), sort!(constraints)
end

function _task_requirement_targets(task::EvidenceTaskSpec,
        current_support::Dict{String,Symbol})
    rank = Dict(:missing => 0, :proxy => 1, :full => 2)
    targets = String[]
    utility = 0.0
    for requirement in sort!(collect(keys(current_support)))
        offered = get(task.requirement_support, requirement, :missing)
        rank[offered] > rank[current_support[requirement]] || continue
        push!(targets, requirement)
        utility += rank[offered] - rank[current_support[requirement]]
    end
    return targets, utility
end

function _task_execution_status(task::EvidenceTaskSpec, genome::Genome,
        registry::EvaluatorRegistry, completed::Vector{CompletedEvidence})
    geometry_models = Set(source.geometry_model for source in genome.field_sources)
    if !isempty(task.required_field_source_geometry_models) &&
            isempty(intersect(geometry_models,
                task.required_field_source_geometry_models))
        required = join(sort!(collect(
            task.required_field_source_geometry_models)), ", ")
        return :input_incompatible,
            ["task requires one of the field-source geometry models: $required"]
    end
    forbidden = sort!(collect(intersect(geometry_models,
        task.forbidden_field_source_geometry_models)))
    isempty(forbidden) || return :input_incompatible,
        ["task forbids field-source geometry models: $(join(forbidden, ", "))"]
    !isempty(_exact_evidence(task, genome, completed)) &&
        return :already_completed, ["exact task version and physics hash already have terminal evidence"]
    task.backend_status == :planned &&
        return :backend_planned, ["backend is declared but not executable"]
    task.backend_status == :blocked &&
        return :backend_blocked, ["required backend is unavailable or blocked"]
    if task.kind == :input_builder
        return :executable, ["input builder is available"]
    end
    missing_prereqs = filter(task.prerequisite_task_ids) do id
        !any(item -> item.task_id == id && item.input_hash == genome.physics_hash &&
            item.status == :pass, completed)
    end
    !isempty(missing_prereqs) && return :prerequisite_missing,
        ["missing passing prerequisites: $(join(missing_prereqs, ", "))"]
    evaluator = get(registry.evaluators, task.id, nothing)
    evaluator === nothing && return :backend_unregistered,
        ["available task has no registered evaluator"]
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return :input_incompatible, [reason]
    return :executable, [reason]
end

function _recommendation_sort_key(item::EvidenceTaskRecommendation)
    return (-item.cost_aware_score, item.task_id, item.design_id, item.physics_hash)
end

function schedule_evidence_acquisition(genomes::Vector{Genome},
        registry::EvaluatorRegistry, tasks::Vector{EvidenceTaskSpec},
        completed::Vector{CompletedEvidence}, contract::ObjectiveContract;
        budget_units::Real = 50.0,
        descriptors::Dict{String,String} = Dict{String,String}())
    isfinite(budget_units) && budget_units >= 0 ||
        throw(ArgumentError("budget_units must be finite and non-negative"))
    _validate_task_catalog(tasks)
    family_counts = Dict{String,Int}()
    for genome in genomes
        family_counts[genome.family] = get(family_counts, genome.family, 0) + 1
    end
    total = max(length(genomes), 1)
    recommendations = EvidenceTaskRecommendation[]
    candidate_audits = Dict{String,Any}[]
    unschedulable_counts = Dict{String,Int}()

    for genome in sort(genomes; by = item -> (item.physics_hash, item.design_id))
        observed = _observed_metrics(genome, completed)
        in_contract = genome.mission.kind in contract.mission_kinds &&
            genome.mission.fuel in contract.fuels
        missing_objectives = in_contract ? filter(spec ->
            !_objective_observed(spec, observed, contract.minimum_claim_level),
            contract.objectives) : ObjectiveSpec[]
        missing_constraints = in_contract ? filter(spec ->
            !_constraint_observed(spec, observed, contract.minimum_claim_level),
            contract.hard_constraints) : ConstraintSpec[]
        current_support = _completed_requirement_support(genome, tasks, completed)
        missing_requirements = sort!([id for (id, level) in current_support if level != :full])
        diversity = min(2.0, sqrt(total / family_counts[genome.family]))
        per_task = Dict{String,EvidenceTaskRecommendation}()

        for task in tasks
            genome.family in task.families || continue
            objectives, constraints = _task_contract_targets(task,
                missing_objectives, missing_constraints, contract)
            requirements, requirement_utility =
                _task_requirement_targets(task, current_support)
            utility = 12.0 * length(constraints) + 6.0 * length(objectives) +
                requirement_utility
            status, reasons = _task_execution_status(task, genome, registry, completed)
            score = utility == 0 ? 0.0 : utility * diversity / task.cost_units
            per_task[task.id] = EvidenceTaskRecommendation(genome.design_id,
                genome.family, genome.physics_hash,
                get(descriptors, genome.physics_hash, "unassigned"), task.id,
                task.version, status, task.cost_units, utility, diversity, score,
                constraints, objectives, requirements, String[], sort!(unique(reasons)))
        end

        # Input builders inherit only the useful acquisition value of strict
        # downstream evaluators that rejected this exact genome.
        for task in tasks
            task.kind == :input_builder || continue
            genome.family in task.families || continue
            unlocked = String[]
            unlock_utility = 0.0
            for target_id in task.unlock_task_ids
                target = get(per_task, target_id, nothing)
                target === nothing && continue
                target.execution_status == :input_incompatible || continue
                target.acquisition_utility > 0 || continue
                push!(unlocked, target_id)
                unlock_utility += target.acquisition_utility
            end
            existing = get(per_task, task.id, nothing)
            existing === nothing && continue
            score = unlock_utility == 0 ? 0.0 :
                unlock_utility * diversity / task.cost_units
            per_task[task.id] = EvidenceTaskRecommendation(existing.design_id,
                existing.family, existing.physics_hash, existing.descriptor,
                existing.task_id, existing.task_version, existing.execution_status,
                existing.cost_units, unlock_utility, diversity, score,
                String[], String[], String[], sort!(unlocked), existing.reasons)
        end
        append!(recommendations, values(per_task))

        scope_reasons = String[]
        genome.mission.kind in contract.mission_kinds || push!(scope_reasons,
            "mission kind $(genome.mission.kind) is outside $(contract.id)")
        genome.mission.fuel in contract.fuels || push!(scope_reasons,
            "fuel $(genome.mission.fuel) is outside $(contract.id)")
        push!(candidate_audits, Dict{String,Any}(
            "design_id" => genome.design_id,
            "physics_hash" => genome.physics_hash,
            "family" => genome.family,
            "descriptor" => get(descriptors, genome.physics_hash, "unassigned"),
            "contract_applicable" => in_contract,
            "contract_scope_reasons" => scope_reasons,
            "missing_hard_constraints" => sort!(getfield.(missing_constraints, :metric_id)),
            "missing_objectives" => sort!(getfield.(missing_objectives, :metric_id)),
            "requirement_evidence" => Dict(id => String(level)
                for (id, level) in sort!(collect(current_support); by = first)),
            "missing_full_requirements" => missing_requirements,
            "terminal_exact_task_ids" => sort!(unique(item.task_id for item in completed
                if item.input_hash == genome.physics_hash && _terminal_evidence(item))),
        ))

        # A gap is unschedulable only if no catalog task for this family can
        # acquire it at the required evidence tier. Backend status is irrelevant
        # here: planned/blocked gaps still count as represented in the roadmap.
        for spec in missing_constraints
            represented = any(task -> genome.family in task.families &&
                spec.metric_id in task.metric_outputs &&
                task.fidelity >= spec.minimum_fidelity &&
                _claim_at_least(task.claim_ceiling, contract.minimum_claim_level), tasks)
            represented || (unschedulable_counts["hard_constraint:$(spec.metric_id)"] =
                get(unschedulable_counts, "hard_constraint:$(spec.metric_id)", 0) + 1)
        end
        for spec in missing_objectives
            represented = any(task -> genome.family in task.families &&
                spec.metric_id in task.metric_outputs &&
                task.fidelity >= spec.minimum_fidelity &&
                (!spec.require_uncertainty || spec.metric_id in task.uncertainty_outputs) &&
                _claim_at_least(task.claim_ceiling, contract.minimum_claim_level), tasks)
            represented || (unschedulable_counts["objective:$(spec.metric_id)"] =
                get(unschedulable_counts, "objective:$(spec.metric_id)", 0) + 1)
        end
        for requirement in missing_requirements
            represented = any(task -> genome.family in task.families &&
                get(task.requirement_support, requirement, :missing) == :full, tasks)
            represented || (unschedulable_counts["requirement:$requirement"] =
                get(unschedulable_counts, "requirement:$requirement", 0) + 1)
        end
    end

    useful = filter(item -> item.acquisition_utility > 0, recommendations)
    executable = sort!(filter(item -> item.execution_status == :executable, useful);
        by = _recommendation_sort_key)
    selected = EvidenceTaskRecommendation[]
    deferred = EvidenceTaskRecommendation[]
    spent = 0.0
    for item in executable
        if spent + item.cost_units <= Float64(budget_units) + 1.0e-12
            push!(selected, item)
            spent += item.cost_units
        else
            push!(deferred, item)
        end
    end

    development = Dict{String,Any}[]
    development_statuses = Set((:backend_planned, :backend_blocked,
        :backend_unregistered, :prerequisite_missing))
    for task in sort(tasks; by = item -> item.id)
        items = filter(item -> item.task_id == task.id &&
            item.execution_status in development_statuses &&
            item.acquisition_utility > 0, useful)
        isempty(items) && continue
        total_utility = sum(item.acquisition_utility * item.diversity_bonus for item in items)
        push!(development, Dict{String,Any}(
            "task_id" => task.id,
            "task_version" => task.version,
            "backend_status" => String(task.backend_status),
            "candidate_count" => length(items),
            "families" => sort!(unique(getfield.(items, :family))),
            "aggregate_diversity_weighted_utility" => total_utility,
            "cost_units_per_candidate" => task.cost_units,
            "development_priority_score" => total_utility / task.cost_units,
            "claim_boundary" => "Priority is an acquisition heuristic; this task has not produced candidate physics evidence.",
        ))
    end
    sort!(development; by = item ->
        (-item["development_priority_score"], item["task_id"]))
    unschedulable = [Dict{String,Any}("gap" => id, "candidate_count" => count)
        for (id, count) in sort!(collect(unschedulable_counts); by = first)]
    sort!(candidate_audits; by = item -> (item["physics_hash"], item["design_id"]))
    sort!(recommendations; by = item ->
        (item.physics_hash, item.task_id, item.design_id))
    return EvidenceScheduleResult(contract.id, Float64(budget_units), spent,
        selected, deferred, development, unschedulable, candidate_audits,
        recommendations, sort(copy(tasks); by = item -> item.id),
        sort(copy(completed); by = item ->
            (item.input_hash, item.task_id, item.task_version, item.run_hash)))
end

function _task_to_dict(task::EvidenceTaskSpec)
    return Dict{String,Any}(
        "task_id" => task.id,
        "task_version" => task.version,
        "kind" => String(task.kind),
        "families" => sort!(collect(task.families)),
        "fidelity" => task.fidelity,
        "cost_units" => task.cost_units,
        "backend_status" => String(task.backend_status),
        "requirement_support" => Dict(id => String(level)
            for (id, level) in sort!(collect(task.requirement_support); by = first)),
        "metric_outputs" => sort!(collect(task.metric_outputs)),
        "uncertainty_outputs" => sort!(collect(task.uncertainty_outputs)),
        "required_field_source_geometry_models" =>
            sort!(collect(task.required_field_source_geometry_models)),
        "forbidden_field_source_geometry_models" =>
            sort!(collect(task.forbidden_field_source_geometry_models)),
        "prerequisite_task_ids" => task.prerequisite_task_ids,
        "unlock_task_ids" => task.unlock_task_ids,
        "claim_ceiling" => task.claim_ceiling,
    )
end

function _completed_evidence_to_dict(evidence::CompletedEvidence)
    status_counts = Dict{String,Int}()
    metric_ids = Dict{String,Vector{String}}()
    for metric in evidence.metrics
        status = String(metric.status)
        status_counts[status] = get(status_counts, status, 0) + 1
        push!(get!(metric_ids, status, String[]), metric.metric_id)
    end
    return Dict{String,Any}(
        "task_id" => evidence.task_id,
        "task_version" => evidence.task_version,
        "design_id" => evidence.design_id,
        "input_hash" => evidence.input_hash,
        "run_hash" => evidence.run_hash,
        "status" => String(evidence.status),
        "fidelity" => evidence.fidelity,
        "claim_ceiling" => evidence.claim_ceiling,
        "metric_status_counts" => status_counts,
        "metric_ids_by_status" => Dict(status => sort!(ids)
            for (status, ids) in sort!(collect(metric_ids); by = first)),
        "claim_boundary" => "This is a pointer and status ledger for an actual stored evaluation; it is not a surrogate prediction.",
    )
end

function _recommendation_to_dict(item::EvidenceTaskRecommendation)
    return Dict{String,Any}(
        "design_id" => item.design_id,
        "family" => item.family,
        "physics_hash" => item.physics_hash,
        "descriptor" => item.descriptor,
        "task_id" => item.task_id,
        "task_version" => item.task_version,
        "execution_status" => String(item.execution_status),
        "cost_units" => item.cost_units,
        "acquisition_utility" => item.acquisition_utility,
        "diversity_bonus" => item.diversity_bonus,
        "cost_aware_score" => item.cost_aware_score,
        "targeted_hard_constraints" => item.targeted_hard_constraints,
        "targeted_objectives" => item.targeted_objectives,
        "targeted_requirements" => item.targeted_requirements,
        "unlocks" => item.unlocks,
        "reasons" => item.reasons,
    )
end

function evidence_schedule_to_dict(result::EvidenceScheduleResult)
    useful = filter(item -> item.acquisition_utility > 0, result.all_recommendations)
    status_counts = Dict{String,Int}()
    for item in useful
        key = String(item.execution_status)
        status_counts[key] = get(status_counts, key, 0) + 1
    end
    payload = Dict{String,Any}(
        "schedule_version" => "evidence_promotion_v1",
        "algorithm" => "deterministic diversity- and cost-aware evidence acquisition",
        "contract_id" => result.contract_id,
        "claim_boundary" => "Scores prioritize evidence acquisition only. They are not predicted stability, fusion output, engineering feasibility, or proof of a superior device. Planned and blocked tasks never satisfy a metric or hard gate.",
        "budget_units" => result.budget_units,
        "selected_cost_units" => result.selected_cost_units,
        "selected_count" => length(result.selected),
        "deferred_executable_count" => length(result.deferred_executable),
        "candidate_count" => length(result.candidate_audits),
        "task_catalog_count" => length(result.task_catalog),
        "completed_evidence_count" => length(result.completed_evidence),
        "useful_recommendation_status_counts" => status_counts,
        "task_catalog" => _task_to_dict.(result.task_catalog),
        "completed_evidence_ledger" =>
            _completed_evidence_to_dict.(result.completed_evidence),
        "selected_queue" => _recommendation_to_dict.(result.selected),
        "deferred_executable" => _recommendation_to_dict.(result.deferred_executable),
        "model_development_priorities" => result.development_priorities,
        "unschedulable_gaps" => result.unschedulable_gaps,
        "candidate_audits" => result.candidate_audits,
        "all_useful_recommendations" => _recommendation_to_dict.(useful),
    )
    payload["schedule_hash"] = canonical_hash(payload)
    return payload
end
