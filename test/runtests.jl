using Test
using JSON3
using Random
using SHA
using FusionConceptAI

include(joinpath("open_world_v2", "runtests.jl"))
include("unified_search_architecture_v52.jl")
include("public_judgment_representative_validation_v53.jl")
include("solver_ready_contract_search_v54.jl")
include("unified_judgment_chain_v55.jl")
include("candidate_bound_eight_stage_search_v56.jl")
include("candidate_solver_runtime_v1.jl")
include("candidate_solver_runtime_search_v57.jl")
include("candidate_solver_runtime_search_v58.jl")
include("candidate_solver_runtime_search_v59.jl")
include("candidate_solver_runtime_search_v60.jl")
include("candidate_solver_runtime_search_v61.jl")
include("candidate_solver_evidence_search_v62.jl")
include("candidate_engineering_manifests_v1.jl")
include("candidate_engineering_search_v63.jl")
include("candidate_plant_subsystems_v1.jl")
include("candidate_plant_search_v64.jl")
include("candidate_independent_evidence_v1.jl")
include("candidate_vvuq_runtime_v87.jl")
include("candidate_independent_evidence_search_v65.jl")
include("candidate_icf_input_search_v66.jl")
include("external_evidence_resource_runtime_v1.jl")
include("candidate_external_resource_search_v67.jl")
include("candidate_residual_graph_runtime_v68.jl")
include("candidate_longitudinal_residual_module_v1.jl")
include("candidate_v68_real_panel_v1.jl")
include("stability_evidence_protocol_v2.jl")
include("open_field_linear_stability_runtime_v1.jl")
include("open_field_flow_shear_runtime_v1.jl")
include("open_field_flr_runtime_v1.jl")
include("open_field_dclc_dispersion_runtime_v1.jl")
include("open_field_aic_dispersion_runtime_v1.jl")
include("c2_decision_runtime_v1.jl")
include("stage34_topology_grammar_v2.jl")
include("hierarchical_energy_target_search_v2.jl")
include("candidate_c2_operating_assembly_v1.jl")
include("candidate_c2_vertical_slice_v1.jl")
include("candidate_common_graph_v69.jl")
include("stage3_sharded_streaming_v70.jl")
include("physical_device_v71.jl")
include("physical_transport_v72.jl")
include("closed_field_transport_v73.jl")
include("augmented_helical_field_v74.jl")
include("augmented_helical_frontier_v75.jl")
include("augmented_helical_operating_v76.jl")
include("local_helical_flux_surface_v77.jl")
include("local_helical_flux_surface_refinement_v78.jl")
include("multiharmonic_coil_search_v79.jl")
include("modular_multiharmonic_coil_search_v80.jl")
include("poincare_flux_surface_gate_v81.jl")
include("periodic_modular_coil_search_v82.jl")
include("periodic_coil_regularization_v83.jl")
include("candidate_realization_minimality_v84.jl")
include("candidate_realization_sharded_fidelity_v84.jl")
include("candidate_joint_physical_optimization_v85.jl")
include("multitopology_campaign_runtime_v86.jl")
include("surface_current_potential_inverse_v86.jl")
include("universal_multitopology_device_chain_v89.jl")
include("universal_multitopology_device_chain_v90.jl")
include("multitopology_search_campaign_v91.jl")
# The v92 test files can run standalone by including their source into Main. Under
# Pkg.test the package is already loaded, so expose the same two test helpers without
# changing the sealed v92 protocol or any v92 result artifact.
const _v92_json = FusionConceptAI._v92_json
const _v92_plain = FusionConceptAI._v92_plain
include("protocol_seal_runtime_v92.jl")
include("physical_realization_runtime_v92.jl")
include("high_fidelity_solver_portfolio_v92.jl")
include("qualification_vvuq_runtime_v92.jl")
include("multiregion_equilibrium_v93.jl")
include("v93_pvw_slice1.jl")
include("generic_capability_runtime_v94.jl")
include("unified_filter_v95.jl")
include("provider_closure_v96.jl")
include("exhaustive_physical_rescreen_v97.jl")
include("end_to_end_device_pipeline_v98.jl")
include("full_device_qualification_v99.jl")

include("stability_mode_compiler_v1.jl")
include("conservation_problem_compiler_v2.jl")
include("directed_particle_deposition_source_compiler_v1.jl")
include("pleiades_directed_particle_deposition_source_v1.jl")
include("cql3d_backend_audit_v1.jl")
include("external_kinetic_backend_contract_v1.jl")
include("cql3d_public_build_regression_v2.jl")
include("cql3d_m_physical_equivalence_audit_v1.jl")
include("pleiades_candidate_kinetic_problem_ir_v1.jl")
include("directed_multispecies_loss_cone_fokker_planck_v1.jl")
include("pleiades_directed_two_species_ambipolar_v1.jl")
include("pleiades_reduced_coupled_balance_overlay_v1.jl")
include("multitopology_system_initial_validation_v1.jl")
include("mechanism_frontier_evidence_queue_v1.jl")
include("mechanism_native_geometry_generation_v1.jl")
include("phase_locked_reciprocal_mirror_ring_v1.jl")
include("native_candidate_c1_backend_v1.jl")
include("pulsed_radiation_hydrodynamics_input_v1.jl")
include("pulsed_rhd_manifest_v1.jl")
include("axisymmetric_mirror_filament_search_v1.jl")
include("dual_route_multitopology_c1_search_v1.jl")
include("mirror_stability_engineering_screen_v1.jl")
include("levitated_dipole_ring_screen_v1.jl")
include("candidate_evidence_federation_v1.jl")
include("topology_desc_fourier_expansion_v2.jl")
include("three_route_evidence_acquisition_queue_v1.jl")
include("candidate_specific_mirror_winding_v1.jl")
include("candidate_specific_minimum_b_cage_search_v1.jl")
include("open_world_pleiades_geometry_search_v1.jl")
include("open_world_kinetic_stabilizer_branch_v1.jl")
include("topology_desc_stability_round2_v4.jl")
include("topology_desc_c2_horizontal_v5_v7.jl")

const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))
const SEEDS_PATH = joinpath(PROJECT_ROOT, "examples", "seed_devices.json")
const LEGACY_ROOT = normpath(joinpath(PROJECT_ROOT, "..", "iter_tokamak_julia_model"))
const FREEGS_REGRESSION_PATH = joinpath(PROJECT_ROOT, "examples",
    "freegs_testtokamak_regression_genome.json")
const FREEGS_PYTHON = joinpath(PROJECT_ROOT, ".venv-freegs", "Scripts", "python.exe")
const DESC_REGRESSION_PATH = joinpath(PROJECT_ROOT, "examples",
    "desc_w7x_regression_genome.json")
const DESC_PYTHON = joinpath(PROJECT_ROOT, ".venv-desc", "Scripts", "python.exe")
const DESC_FOURIER_INPUT_PATH = joinpath(PROJECT_ROOT, "examples",
    "desc_fourier_search_seed_runner_input.json")
const DESC_FOURIER_ARTIFACT_PATH = joinpath(PROJECT_ROOT, "runs",
    "fidelity1_desc_fourier_search_seed.json")
const DESC_FOURIER_AUDIT_PATH = joinpath(PROJECT_ROOT, "runs",
    "desc_fourier_search_seed_grid_audit.json")
const DESC_FOURIER_PILOT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_fourier_pilot_search_20260810.json")
const DESC_FOURIER_PILOT_RAW_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_fourier_pilot_batch_raw.json")
const DESC_STABILITY_COARSE_MEDIUM_AUDIT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_stability_nfp2_resolution_audit.json")
const DESC_STABILITY_MEDIUM_FINE_AUDIT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_stability_nfp2_medium_fine_audit.json")
const DESC_STABILITY_MEDIUM_PILOT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_stability_medium_pilot_20260810.json")
const DESC_STABILITY_MEDIUM_PILOT_RAW_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_stability_medium_pilot_batch_raw.json")
const DESC_STABILITY_ACTIVE_PLAN_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_stability_active_learning_round2_plan.json")
const DESC_STABILITY_ACTIVE_RAW_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_stability_active_round2_batch_raw.json")
const DESC_STABILITY_ACTIVE_RESULTS_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_stability_active_round2_results.json")
const DESC_STABILITY_ACTIVE_AUDIT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_stability_active_round2_nfp2_medium_fine_audit.json")
const DESC_SURFACE_CURRENT_INPUT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_surface_current_pilot_batch_input.json")
const DESC_SURFACE_CURRENT_RAW_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_surface_current_pilot_batch_raw.json")
const DESC_SURFACE_CURRENT_PILOT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_surface_current_pilot_20260810.json")
const DESC_SURFACE_CURRENT_POOL8_AUDIT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_surface_current_pool8_resolution_audit.json")
const DESC_SURFACE_CURRENT_POOL16_AUDIT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_surface_current_pool16_resolution_audit.json")
const DESC_DISCRETE_COIL_INPUT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_discrete_coil_cut_pool16_input.json")
const DESC_DISCRETE_COIL_RAW_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_discrete_coil_cut_pool16_raw.json")
const DESC_DISCRETE_COIL_AUDIT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_discrete_coil_cut_pool16_resolution_audit.json")
const DESC_DISCRETE_COIL_ARTIFACT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_discrete_coil_cut_pool16_20260810.json")
const DESC_OPTIMIZED_COIL_INPUT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_discrete_coil_optimization_pool16_v7_input.json")
const DESC_OPTIMIZED_COIL_RAW_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_discrete_coil_optimization_pool16_v7_raw.json")
const DESC_OPTIMIZED_COIL_REPAIR_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_discrete_coil_interpolation_screen_pool16_v3.json")
const DESC_OPTIMIZED_COIL_RESOLUTION_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_discrete_coil_interpolation_screen_pool16_v3_resolution_audit.json")
const DESC_OPTIMIZED_COIL_TOLERANCE_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_discrete_coil_interpolation_screen_pool16_v3_tolerance_audit.json")
const DESC_OPTIMIZED_COIL_ARTIFACT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_discrete_coil_optimization_pool16_20260811.json")
const DESC_TRANSPORT_BASE_RAW_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_transport_pool16_low_order_base_raw.json")
const DESC_TRANSPORT_REFINED_RAW_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_transport_pool16_low_order_refined_raw.json")
const DESC_TRANSPORT_AUDIT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_transport_pool16_low_order_resolution_audit.json")
const DESC_TRANSPORT_ARTIFACT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_transport_pool16_20260811.json")
const DESC_FINITE_BUILD_BASE_RAW_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_finite_build_coil_pool16_base_raw.json")
const DESC_FINITE_BUILD_REFINED_RAW_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_finite_build_coil_pool16_refined_raw.json")
const DESC_FINITE_BUILD_AUDIT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_finite_build_coil_pool16_resolution_audit.json")
const DESC_FINITE_BUILD_ARTIFACT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_finite_build_coil_pool16_20260811.json")
const DESC_REGULARIZED_COIL_BASE_RAW_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_regularized_coil_force_pool16_base_raw.json")
const DESC_REGULARIZED_COIL_REFINED_RAW_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_regularized_coil_force_pool16_refined_raw.json")
const DESC_REGULARIZED_COIL_AUDIT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_regularized_coil_force_pool16_resolution_audit.json")
const DESC_REGULARIZED_COIL_ARTIFACT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_regularized_coil_force_pool16_20260811.json")
const DESC_RECTANGULAR_INTERNAL_FIELD_RAW_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_rectangular_internal_field_pool16_ultra_raw.json")
const DESC_RECTANGULAR_INTERNAL_FIELD_INITIAL_AUDIT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_rectangular_internal_field_pool16_resolution_audit.json")
const DESC_RECTANGULAR_INTERNAL_FIELD_CONVERGENCE_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_rectangular_internal_field_pool16_convergence_verification.json")
const DESC_RECTANGULAR_INTERNAL_FIELD_COMPLETION_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_rectangular_internal_field_pool16_plasma_completion_audit.json")
const DESC_RECTANGULAR_INTERNAL_FIELD_VERIFICATION_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_rectangular_internal_field_pool16_ultra_verification.json")
const DESC_RECTANGULAR_INTERNAL_FIELD_ARTIFACT_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_rectangular_internal_field_pool16_20260811.json")
const CROSS_FAMILY_FIVE_GATE_ARTIFACT_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_five_gate_search_20260811.json")
const CROSS_FAMILY_FIVE_GATE_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_five_gate_search_20260811.md")
const CROSS_FAMILY_MID_FIDELITY_ARTIFACT_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_mid_fidelity_review_20260811.json")
const CROSS_FAMILY_MID_FIDELITY_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_mid_fidelity_review_20260811.md")
const MIRROR_FINITE_COIL_ARTIFACT_PATH = joinpath(PROJECT_ROOT, "runs",
    "mirror_finite_coil_geometry_review_20260811.json")
const MIRROR_FINITE_COIL_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "mirror_finite_coil_geometry_review_20260811.md")
const MIRROR_GEOMETRY_FEEDBACK_ARTIFACT_PATH = joinpath(PROJECT_ROOT, "runs",
    "mirror_geometry_feedback_batch_20260811.json")
const MIRROR_GEOMETRY_FEEDBACK_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "mirror_geometry_feedback_batch_20260811.md")
const CROSS_FAMILY_GEOMETRY_TOPOLOGY_V2_ARTIFACT_PATH = joinpath(PROJECT_ROOT,
    "runs", "cross_family_geometry_topology_v2_20260811.json")
const CROSS_FAMILY_GEOMETRY_TOPOLOGY_V2_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "cross_family_geometry_topology_v2_20260811.md")
const CROSS_FAMILY_FAILURE_AWARE_ARTIFACT_PATH = joinpath(PROJECT_ROOT,
    "runs", "cross_family_failure_aware_review_20260811.json")
const CROSS_FAMILY_FAILURE_AWARE_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "cross_family_failure_aware_review_20260811.md")
const CROSS_FAMILY_FAILURE_AWARE_QD_V3_ARTIFACT_PATH = joinpath(PROJECT_ROOT,
    "runs", "cross_family_failure_aware_qd_v3_20260811.json")
const CROSS_FAMILY_FAILURE_AWARE_QD_V3_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "cross_family_failure_aware_qd_v3_20260811.md")
const COMPACT_TOROID_EDGE_QD_V4_ARTIFACT_PATH = joinpath(PROJECT_ROOT,
    "runs", "compact_toroid_edge_qd_v4_20260811.json")
const COMPACT_TOROID_EDGE_QD_V4_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "compact_toroid_edge_qd_v4_20260811.md")
const SHARED_OUTER_ENVELOPE_QD_V5_ARTIFACT_PATH = joinpath(PROJECT_ROOT,
    "runs", "shared_outer_envelope_qd_v5_20260812.json")
const SHARED_OUTER_ENVELOPE_QD_V5_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "shared_outer_envelope_qd_v5_20260812.md")
const V5_TOKAMAK_FREEGS_REVIEW_PATH = joinpath(PROJECT_ROOT,
    "runs", "v5_tokamak_freegs_review_20260812.json")
const V5_TOKAMAK_FREEGS_REVIEW_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "v5_tokamak_freegs_review_20260812.md")
const V9_TOKAMAK_FREEGS_REVIEW_PATH = joinpath(PROJECT_ROOT,
    "runs", "v9_tokamak_freegs_review_20260813.json")
const V9_TOKAMAK_FREEGS_REVIEW_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "v9_tokamak_freegs_review_20260813.md")
const MECHANISM_EXPANSION_QD_V10_PATH = joinpath(PROJECT_ROOT,
    "runs", "mechanism_expansion_qd_v10_20260813.json")
const MECHANISM_EXPANSION_QD_V10_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "mechanism_expansion_qd_v10_20260813.md")
const OPEN_LOSS_PATHWAY_QD_V11_PATH = joinpath(PROJECT_ROOT,
    "runs", "open_loss_pathway_qd_v11_20260813.json")
const OPEN_LOSS_PATHWAY_QD_V11_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "open_loss_pathway_qd_v11_20260813.md")
const CAUSAL_BRIDGE_QD_V12_PATH = joinpath(PROJECT_ROOT,
    "runs", "causal_bridge_qd_v12_20260813.json")
const CAUSAL_BRIDGE_QD_V12_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "causal_bridge_qd_v12_20260813.md")
const SAFE_ACTIVE_CAUSAL_DISCOVERY_V13_PATH = joinpath(PROJECT_ROOT,
    "runs", "safe_active_causal_discovery_v13_20260813.json")
const SAFE_ACTIVE_CAUSAL_DISCOVERY_V13_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "safe_active_causal_discovery_v13_20260813.md")
const HIERARCHICAL_GATE_DISCOVERY_V14_PATH = joinpath(PROJECT_ROOT,
    "runs", "hierarchical_gate_discovery_v14_20260813.json")
const HIERARCHICAL_GATE_DISCOVERY_V14_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "hierarchical_gate_discovery_v14_20260813.md")
const LASER_ICF_QD_V15_PATH = joinpath(PROJECT_ROOT,
    "runs", "laser_icf_qd_v15_20260813.json")
const LASER_ICF_QD_V15_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "laser_icf_qd_v15_20260813.md")
const QUANTITATIVE_EVIDENCE_TABLE_PATH = joinpath(PROJECT_ROOT,
    "knowledge", "quantitative_evidence_icf_open_magnetic_v1.json")
const QUANTITATIVE_EVIDENCE_SCHEMA_PATH = joinpath(PROJECT_ROOT,
    "schemas", "quantitative_evidence_v1.schema.json")
const QUANTITATIVE_EVIDENCE_REPORT_PATH = joinpath(PROJECT_ROOT,
    "runs", "quantitative_evidence_s2_20260813.json")
const QUANTITATIVE_EVIDENCE_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "quantitative_evidence_s2_20260813.md")
const EVIDENCE_GAP_PRIORITIZATION_V16_PATH = joinpath(PROJECT_ROOT,
    "runs", "evidence_gap_prioritization_v16_20260813.json")
const EVIDENCE_GAP_PRIORITIZATION_V16_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "evidence_gap_prioritization_v16_20260813.md")
const ATTRIBUTE_GRAPH_GRAMMAR_V17_PATH = joinpath(PROJECT_ROOT,
    "runs", "attribute_graph_grammar_v17_20260813.json")
const ATTRIBUTE_GRAPH_GRAMMAR_V17_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "attribute_graph_grammar_v17_20260813.md")
const ATTRIBUTE_GRAPH_GENOME_V18_PATH = joinpath(PROJECT_ROOT,
    "runs", "attribute_graph_genome_pipeline_v18_20260813.json")
const ATTRIBUTE_GRAPH_GENOME_V18_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "attribute_graph_genome_pipeline_v18_20260813.md")
const ATTRIBUTE_GRAPH_GENOME_V18_ARCHIVE_PATH = joinpath(PROJECT_ROOT,
    "runs", "attribute_graph_genomes_v18_20260813.jsonl")
const RECOVERABLE_EXECUTION_V19_PATH = joinpath(PROJECT_ROOT,
    "runs", "recoverable_sharded_execution_v19_20260814.json")
const RECOVERABLE_EXECUTION_V19_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "recoverable_sharded_execution_v19_20260814.md")
const RECOVERABLE_CROSS_TOPOLOGY_V20_PATH = joinpath(PROJECT_ROOT,
    "runs", "recoverable_cross_topology_v20_20260814.json")
const RECOVERABLE_CROSS_TOPOLOGY_V20_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "recoverable_cross_topology_v20_20260814.md")
const RECOVERABLE_CROSS_TOPOLOGY_V20_CANDIDATES_PATH = joinpath(PROJECT_ROOT,
    "runs", "recoverable_cross_topology_candidates_v20_20260814.jsonl")
const RECOVERABLE_CROSS_TOPOLOGY_V20_ARCHIVE_PATH = joinpath(PROJECT_ROOT,
    "runs", "recoverable_cross_topology_archive_v20_20260814.jsonl")
const RECOVERABLE_CROSS_TOPOLOGY_SCALE_V20_PATH = joinpath(PROJECT_ROOT,
    "runs", "recoverable_cross_topology_scale_v20_20260814.json")
const RECOVERABLE_CROSS_TOPOLOGY_SCALE_V20_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "recoverable_cross_topology_scale_v20_20260814.md")
const RECOVERABLE_CROSS_TOPOLOGY_SCALE_V20_CANDIDATES_PATH = joinpath(
    PROJECT_ROOT, "runs",
    "recoverable_cross_topology_scale_candidates_v20_20260814.jsonl")
const RECOVERABLE_CROSS_TOPOLOGY_SCALE_V20_ARCHIVE_PATH = joinpath(PROJECT_ROOT,
    "runs", "recoverable_cross_topology_scale_archive_v20_20260814.jsonl")
const FAILURE_DIRECTED_GEOMETRY_V21_PATH = joinpath(PROJECT_ROOT, "runs",
    "failure_directed_geometry_triage_v21_20260814.json")
const FAILURE_DIRECTED_GEOMETRY_V21_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "failure_directed_geometry_triage_v21_20260814.md")
const MIRROR_GEOMETRY_PREVIEWS_V21_PATH = joinpath(PROJECT_ROOT, "runs",
    "mirror_geometry_previews_v21_20260814.jsonl")
const MIRROR_GEOMETRY_FULL_REVIEWS_V21_PATH = joinpath(PROJECT_ROOT, "runs",
    "mirror_geometry_full_reviews_v21_20260814.jsonl")
const VARIABLE_MIRROR_TOPOLOGY_V22_PATH = joinpath(PROJECT_ROOT, "runs",
    "variable_mirror_topology_search_v22_20260814.json")
const VARIABLE_MIRROR_TOPOLOGY_V22_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "variable_mirror_topology_search_v22_20260814.md")
const VARIABLE_MIRROR_PREVIEWS_V22_PATH = joinpath(PROJECT_ROOT, "runs",
    "variable_mirror_topology_previews_v22_20260814.jsonl")
const VARIABLE_MIRROR_QD_V22_PATH = joinpath(PROJECT_ROOT, "runs",
    "variable_mirror_topology_qd_archive_v22_20260814.jsonl")
const VARIABLE_MIRROR_FULL_V22_PATH = joinpath(PROJECT_ROOT, "runs",
    "variable_mirror_topology_full_reviews_v22_20260814.jsonl")
const ZPINCH_ADMISSION_V23_PATH = joinpath(PROJECT_ROOT, "runs",
    "zpinch_nonideal_electrode_audit_v23_20260814.json")
const ZPINCH_ADMISSION_V23_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "zpinch_nonideal_electrode_audit_v23_20260814.md")
const ZPINCH_ADMISSION_RECORDS_V23_PATH = joinpath(PROJECT_ROOT, "runs",
    "zpinch_nonideal_electrode_records_v23_20260814.jsonl")
const ZPINCH_ADMISSION_ARCHIVE_V23_PATH = joinpath(PROJECT_ROOT, "runs",
    "zpinch_failure_directed_archive_v23_20260814.jsonl")
const MISSION_CONSISTENT_ZPINCH_V24_PATH = joinpath(PROJECT_ROOT, "runs",
    "mission_consistent_zpinch_search_v24_20260814.json")
const MISSION_CONSISTENT_ZPINCH_V24_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "mission_consistent_zpinch_search_v24_20260814.md")
const MISSION_CONSISTENT_ZPINCH_RECORDS_V24_PATH = joinpath(PROJECT_ROOT,
    "runs", "mission_consistent_zpinch_records_v24_20260814.jsonl")
const MISSION_CONSISTENT_ZPINCH_ARCHIVE_V24_PATH = joinpath(PROJECT_ROOT,
    "runs", "mission_consistent_zpinch_qd_archive_v24_20260814.jsonl")
const DECOUPLED_MIRROR_V25_PATH = joinpath(PROJECT_ROOT, "runs",
    "decoupled_mirror_topology_search_v25_20260814.json")
const DECOUPLED_MIRROR_V25_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "decoupled_mirror_topology_search_v25_20260814.md")
const DECOUPLED_MIRROR_PREVIEW_V25_PATH = joinpath(PROJECT_ROOT, "runs",
    "decoupled_mirror_topology_preconditions_v25_20260814.jsonl")
const DECOUPLED_MIRROR_QD_V25_PATH = joinpath(PROJECT_ROOT, "runs",
    "decoupled_mirror_topology_qd_archive_v25_20260814.jsonl")
const DECOUPLED_MIRROR_FULL_V25_PATH = joinpath(PROJECT_ROOT, "runs",
    "decoupled_mirror_topology_full_reviews_v25_20260814.jsonl")
const ZPINCH_COVERAGE_V26_PATH = joinpath(PROJECT_ROOT, "runs",
    "zpinch_candidate_specific_coverage_v26_20260814.json")
const ZPINCH_COVERAGE_V26_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "zpinch_candidate_specific_coverage_v26_20260814.md")
const ZPINCH_COVERAGE_RECORDS_V26_PATH = joinpath(PROJECT_ROOT, "runs",
    "zpinch_candidate_specific_coverage_records_v26_20260814.jsonl")
const ZPINCH_COVERAGE_ARCHIVE_V26_PATH = joinpath(PROJECT_ROOT, "runs",
    "zpinch_candidate_specific_coverage_qd_v26_20260814.jsonl")
const ICF_LEDGER_V27_PATH = joinpath(PROJECT_ROOT, "runs",
    "icf_conditional_ledger_falsification_v27_20260814.json")
const ICF_LEDGER_V27_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "icf_conditional_ledger_falsification_v27_20260814.md")
const ICF_LEDGER_RECORDS_V27_PATH = joinpath(PROJECT_ROOT, "runs",
    "icf_conditional_ledger_records_v27_20260814.jsonl")
const ICF_LEDGER_ARCHIVE_V27_PATH = joinpath(PROJECT_ROOT, "runs",
    "icf_conditional_ledger_qd_v27_20260814.jsonl")
const STAGE_TELEMETRY_V28_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_topology_stage_telemetry_v28_20260814.json")
const STAGE_TELEMETRY_V28_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_topology_stage_telemetry_v28_20260814.md")
const STAGE_TELEMETRY_RECORDS_V28_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_topology_stage_records_v28_20260814.jsonl")
const STAGE_TELEMETRY_RAW_V28_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_topology_stage_metrics_v28_20260814.jsonl")
const STAGE_TELEMETRY_FAULTS_V28_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_topology_stage_fault_probes_v28_20260814.jsonl")
const FROZEN_ACQUISITION_V29_PATH = joinpath(PROJECT_ROOT, "runs",
    "frozen_acquisition_benchmark_v29_20260814.json")
const FROZEN_ACQUISITION_V29_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "frozen_acquisition_benchmark_v29_20260814.md")
const FROZEN_ACQUISITION_BATCHES_V29_PATH = joinpath(PROJECT_ROOT, "runs",
    "frozen_acquisition_batches_v29_20260814.jsonl")
const FROZEN_ACQUISITION_RECORDS_V29_PATH = joinpath(PROJECT_ROOT, "runs",
    "frozen_acquisition_records_v29_20260814.jsonl")
const FROZEN_ACQUISITION_V30_PATH = joinpath(PROJECT_ROOT, "runs",
    "frozen_acquisition_confirmation_v30_20260814.json")
const FROZEN_ACQUISITION_V30_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "frozen_acquisition_confirmation_v30_20260814.md")
const FROZEN_ACQUISITION_BATCHES_V30_PATH = joinpath(PROJECT_ROOT, "runs",
    "frozen_acquisition_confirmation_batches_v30_20260814.jsonl")
const FROZEN_ACQUISITION_RECORDS_V30_PATH = joinpath(PROJECT_ROOT, "runs",
    "frozen_acquisition_confirmation_records_v30_20260814.jsonl")
const GATE_OBSERVABILITY_V31_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_gate_observability_v31_20260814.json")
const GATE_OBSERVABILITY_V31_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_gate_observability_v31_20260814.md")
const GATE_OBSERVABILITY_RECORDS_V31_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_gate_observability_records_v31_20260814.jsonl")
const DIAGNOSTIC_QD_V32_PATH = joinpath(PROJECT_ROOT, "runs",
    "diagnostic_cross_family_qd_v32_20260814.json")
const DIAGNOSTIC_QD_V32_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "diagnostic_cross_family_qd_v32_20260814.md")
const DIAGNOSTIC_QD_CANDIDATES_V32_PATH = joinpath(PROJECT_ROOT, "runs",
    "diagnostic_cross_family_candidates_v32_20260814.jsonl")
const DIAGNOSTIC_QD_GRAPH_V32_PATH = joinpath(PROJECT_ROOT, "runs",
    "diagnostic_cross_family_graph_archive_v32_20260814.jsonl")
const DIAGNOSTIC_QD_MECHANISM_V32_PATH = joinpath(PROJECT_ROOT, "runs",
    "diagnostic_cross_family_mechanism_archive_v32_20260814.jsonl")
const DIAGNOSTIC_QD_FRONTIER_V32_PATH = joinpath(PROJECT_ROOT, "runs",
    "diagnostic_cross_family_frontier_v32_20260814.jsonl")
const FRONTIER_CAUSAL_V33_PATH = joinpath(PROJECT_ROOT, "runs",
    "frontier_causal_decomposition_v33_20260814.json")
const FRONTIER_CAUSAL_V33_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "frontier_causal_decomposition_v33_20260814.md")
const FRONTIER_CAUSAL_RECORDS_V33_PATH = joinpath(PROJECT_ROOT, "runs",
    "frontier_causal_decomposition_records_v33_20260814.jsonl")
const FRONTIER_SENSITIVITY_V34_PATH = joinpath(PROJECT_ROOT, "runs",
    "frontier_proxy_sensitivity_v34_20260814.json")
const FRONTIER_SENSITIVITY_V34_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "frontier_proxy_sensitivity_v34_20260814.md")
const FRONTIER_SENSITIVITY_RECORDS_V34_PATH = joinpath(PROJECT_ROOT, "runs",
    "frontier_proxy_sensitivity_records_v34_20260814.jsonl")
const TOPOLOGY_INFLUENCE_V35_PATH = joinpath(PROJECT_ROOT, "runs",
    "topology_module_influence_audit_v35_20260814.json")
const TOPOLOGY_INFLUENCE_V35_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "topology_module_influence_audit_v35_20260814.md")
const TOPOLOGY_ALIAS_PAIRS_V35_PATH = joinpath(PROJECT_ROOT, "runs",
    "topology_module_alias_pairs_v35_20260814.jsonl")
const TOPOLOGY_MODULE_QUEUE_V35_PATH = joinpath(PROJECT_ROOT, "runs",
    "topology_module_repair_queue_v35_20260814.jsonl")
const FULL_RESPONSE_AUDIT_V36_PATH = joinpath(PROJECT_ROOT, "runs",
    "full_margin_evidence_response_audit_v36_20260814.json")
const FULL_RESPONSE_AUDIT_V36_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "full_margin_evidence_response_audit_v36_20260814.md")
const FULL_RESPONSE_RECORDS_V36_PATH = joinpath(PROJECT_ROOT, "runs",
    "full_response_records_v36_20260814.jsonl")
const FULL_RESPONSE_PAIRS_V36_PATH = joinpath(PROJECT_ROOT, "runs",
    "full_response_graph_pairs_v36_20260814.jsonl")
const MODULE_RESPONSE_ROUTES_V36_PATH = joinpath(PROJECT_ROOT, "runs",
    "module_response_routes_v36_20260814.jsonl")
const DISCONNECTED_CONTRACT_V37_PATH = joinpath(PROJECT_ROOT, "runs",
    "disconnected_module_influence_contract_v37_20260814.json")
const DISCONNECTED_CONTRACT_V37_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "disconnected_module_influence_contract_v37_20260814.md")
const DISCONNECTED_MODULES_V37_PATH = joinpath(PROJECT_ROOT, "runs",
    "disconnected_module_contracts_v37_20260814.jsonl")
const FIXED_BACKGROUND_CASES_V37_PATH = joinpath(PROJECT_ROOT, "runs",
    "fixed_background_ablation_cases_v37_20260814.jsonl")
const DISCONNECTED_SOURCES_V37_PATH = joinpath(PROJECT_ROOT, "runs",
    "disconnected_module_source_ledger_v37_20260814.jsonl")
const TIER1_EVIDENCE_ABLATION_V38_PATH = joinpath(PROJECT_ROOT, "runs",
    "tier1_module_evidence_ablation_v38_20260814.json")
const TIER1_EVIDENCE_ABLATION_V38_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "tier1_module_evidence_ablation_v38_20260814.md")
const TIER1_MODULE_ROUTES_V38_PATH = joinpath(PROJECT_ROOT, "runs",
    "tier1_module_evidence_routes_v38_20260814.jsonl")
const TIER1_ABLATION_CASES_V38_PATH = joinpath(PROJECT_ROOT, "runs",
    "tier1_fixed_background_ablation_results_v38_20260814.jsonl")
const TIER1_GRAPH_RESPONSES_V38_PATH = joinpath(PROJECT_ROOT, "runs",
    "tier1_graph_evidence_responses_v38_20260814.jsonl")
const TIER1_SOURCES_V38_PATH = joinpath(PROJECT_ROOT, "runs",
    "tier1_module_source_ledger_v38_20260814.jsonl")
const REMAINING_EVIDENCE_ABLATION_V39_PATH = joinpath(PROJECT_ROOT, "runs",
    "remaining_module_evidence_ablation_v39_20260814.json")
const REMAINING_EVIDENCE_ABLATION_V39_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "remaining_module_evidence_ablation_v39_20260814.md")
const REMAINING_MODULE_ROUTES_V39_PATH = joinpath(PROJECT_ROOT, "runs",
    "remaining_module_evidence_routes_v39_20260814.jsonl")
const REMAINING_ABLATION_CASES_V39_PATH = joinpath(PROJECT_ROOT, "runs",
    "remaining_fixed_background_ablation_results_v39_20260814.jsonl")
const REMAINING_GRAPH_RESPONSES_V39_PATH = joinpath(PROJECT_ROOT, "runs",
    "remaining_graph_evidence_responses_v39_20260814.jsonl")
const REMAINING_SOURCES_V39_PATH = joinpath(PROJECT_ROOT, "runs",
    "remaining_module_source_ledger_v39_20260814.jsonl")
const MULTILAYER_ABLATION_V40_PATH = joinpath(PROJECT_ROOT, "runs",
    "multilayer_fixed_background_ablation_v40_20260814.json")
const MULTILAYER_ABLATION_V40_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "multilayer_fixed_background_ablation_v40_20260814.md")
const MULTILAYER_GROUPS_V40_PATH = joinpath(PROJECT_ROOT, "runs",
    "multilayer_intervention_groups_v40_20260814.jsonl")
const MULTILAYER_MODULES_V40_PATH = joinpath(PROJECT_ROOT, "runs",
    "multilayer_controlled_module_routes_v40_20260814.jsonl")
const MULTILAYER_TRIALS_V40_PATH = joinpath(PROJECT_ROOT, "runs",
    "multilayer_fixed_background_trials_v40_20260814.jsonl")
const MULTILAYER_REJECTIONS_V40_PATH = joinpath(PROJECT_ROOT, "runs",
    "multilayer_structural_rejections_v40_20260814.jsonl")
const MULTILAYER_RESPONSES_V40_PATH = joinpath(PROJECT_ROOT, "runs",
    "multilayer_counterfactual_responses_v40_20260814.jsonl")
const DEPENDENCY_CLOSED_ABLATION_V41_PATH = joinpath(PROJECT_ROOT, "runs",
    "dependency_closed_block_ablation_v41_20260814.json")
const DEPENDENCY_CLOSED_ABLATION_V41_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "dependency_closed_block_ablation_v41_20260814.md")
const DEPENDENCY_CLOSED_PAIRS_V41_PATH = joinpath(PROJECT_ROOT, "runs",
    "dependency_closed_module_pairs_v41_20260814.jsonl")
const DEPENDENCY_CLOSED_MODULES_V41_PATH = joinpath(PROJECT_ROOT, "runs",
    "dependency_closed_target_modules_v41_20260814.jsonl")
const DEPENDENCY_CLOSED_TRIALS_V41_PATH = joinpath(PROJECT_ROOT, "runs",
    "dependency_closed_trials_v41_20260814.jsonl")
const DEPENDENCY_CLOSED_RESPONSES_V41_PATH = joinpath(PROJECT_ROOT, "runs",
    "dependency_closed_responses_v41_20260814.jsonl")
const FORMULA_REUSE_V42_PATH = joinpath(PROJECT_ROOT, "runs",
    "candidate_specific_formula_reuse_v42_20260815.json")
const FORMULA_REUSE_V42_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "candidate_specific_formula_reuse_v42_20260815.md")
const FORMULA_REUSE_MODULES_V42_PATH = joinpath(PROJECT_ROOT, "runs",
    "formula_reuse_module_audit_v42_20260815.jsonl")
const FORMULA_REUSE_TRIALS_V42_PATH = joinpath(PROJECT_ROOT, "runs",
    "formula_reuse_trials_v42_20260815.jsonl")
const FORMULA_REUSE_RESPONSES_V42_PATH = joinpath(PROJECT_ROOT, "runs",
    "formula_reuse_responses_v42_20260815.jsonl")
const ANCHOR_REGRESSION_V43_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_anchor_regression_v43_20260815.json")
const ANCHOR_REGRESSION_V43_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_anchor_regression_v43_20260815.md")
const ANCHOR_ROUTES_V43_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_anchor_routes_v43_20260815.jsonl")
const SOLVER_CONTROLS_V43_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_solver_controls_v43_20260815.jsonl")
const DIRECTIONAL_REPLAY_V44_PATH = joinpath(PROJECT_ROOT, "runs",
    "experiment_anchored_directional_replay_v44_20260815.json")
const DIRECTIONAL_REPLAY_V44_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "experiment_anchored_directional_replay_v44_20260815.md")
const DIRECTIONAL_TRIALS_V44_PATH = joinpath(PROJECT_ROOT, "runs",
    "experiment_anchored_directional_trials_v44_20260815.jsonl")
const DIPOLE_SUPPORT_V45_PATH = joinpath(PROJECT_ROOT, "runs",
    "dipole_support_structural_regression_v45_20260815.json")
const DIPOLE_SUPPORT_V45_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "dipole_support_structural_regression_v45_20260815.md")
const DIPOLE_SUPPORT_ENDPOINTS_V45_PATH = joinpath(PROJECT_ROOT, "runs",
    "dipole_support_endpoints_v45_20260815.jsonl")
const SUPPORT_AWARE_V46_PATH = joinpath(PROJECT_ROOT, "runs",
    "support_aware_cross_topology_v46_20260815.json")
const SUPPORT_AWARE_V46_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "support_aware_cross_topology_v46_20260815.md")
const SUPPORT_AWARE_V46_CANDIDATES_PATH = joinpath(PROJECT_ROOT, "runs",
    "support_aware_cross_topology_candidates_v46_20260815.jsonl")
const SUPPORT_AWARE_V46_QD_PATH = joinpath(PROJECT_ROOT, "runs",
    "support_aware_cross_topology_qd_v46_20260815.jsonl")
const HELDOUT_QUANTITATIVE_V47_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_heldout_quantitative_benchmark_v47_20260815.json")
const HELDOUT_QUANTITATIVE_V47_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_heldout_quantitative_benchmark_v47_20260815.md")
const HELDOUT_QUANTITATIVE_V47_ROUTES_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_heldout_quantitative_routes_v47_20260815.jsonl")
const CONFINEMENT_APPLICABILITY_V48_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_confinement_applicability_v48_20260815.json")
const CONFINEMENT_APPLICABILITY_V48_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_confinement_applicability_v48_20260815.md")
const CONFINEMENT_APPLICABILITY_V48_CANDIDATES_PATH = joinpath(PROJECT_ROOT, "runs",
    "cross_family_confinement_candidates_v48_20260815.jsonl")
const MIRROR_BEAM_ENERGY_V49_PATH = joinpath(PROJECT_ROOT, "runs",
    "mirror_beam_energy_intervention_v49_20260815.json")
const MIRROR_BEAM_ENERGY_V49_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "mirror_beam_energy_intervention_v49_20260815.md")
const MIRROR_BEAM_ENERGY_V49_TRIALS_PATH = joinpath(PROJECT_ROOT, "runs",
    "mirror_beam_energy_trials_v49_20260815.jsonl")
const MIRROR_BEAM_ENERGY_V49_QD_PATH = joinpath(PROJECT_ROOT, "runs",
    "mirror_beam_energy_qd_v49_20260815.jsonl")
const TOKAMAK_REGIME_ACCESS_V50_PATH = joinpath(PROJECT_ROOT, "runs",
    "tokamak_regime_access_intervention_v50_20260815.json")
const TOKAMAK_REGIME_ACCESS_V50_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "tokamak_regime_access_intervention_v50_20260815.md")
const TOKAMAK_REGIME_ACCESS_V50_TRIALS_PATH = joinpath(PROJECT_ROOT, "runs",
    "tokamak_regime_access_trials_v50_20260815.jsonl")
const TOKAMAK_REGIME_ACCESS_V50_QD_PATH = joinpath(PROJECT_ROOT, "runs",
    "tokamak_regime_access_qd_v50_20260815.jsonl")
const STELLARATOR_FREN_V51_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_fren_calibration_queue_v51_20260815.json")
const STELLARATOR_FREN_V51_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_fren_calibration_queue_v51_20260815.md")
const STELLARATOR_FREN_V51_CANDIDATES_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_fren_candidates_v51_20260815.jsonl")
const STELLARATOR_FREN_V51_QUEUE_PATH = joinpath(PROJECT_ROOT, "runs",
    "stellarator_fren_acquisition_queue_v51_20260815.jsonl")
const FAILURE_AWARE_PULSED_QD_V6_PATH = joinpath(PROJECT_ROOT,
    "runs", "failure_aware_pulsed_qd_v6_20260812.json")
const FAILURE_AWARE_PULSED_QD_V6_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "failure_aware_pulsed_qd_v6_20260812.md")
const SELF_ORGANIZED_QD_V7_PATH = joinpath(PROJECT_ROOT,
    "runs", "self_organized_qd_v7_20260813.json")
const SELF_ORGANIZED_QD_V7_SUMMARY_PATH = joinpath(PROJECT_ROOT,
    "runs", "self_organized_qd_v7_20260813.md")
const SELF_ORGANIZED_V7_SOURCES_PATH = joinpath(PROJECT_ROOT,
    "knowledge", "self_organized_v7_sources.json")
const RFP_PROFILE_REVIEW_ARTIFACT_PATH = joinpath(PROJECT_ROOT, "runs",
    "v7_rfp_cylindrical_profile_review_20260813.json")
const RFP_PROFILE_REVIEW_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "v7_rfp_cylindrical_profile_review_20260813.md")
const RFP_PROFILE_REVIEW_SOURCES_PATH = joinpath(PROJECT_ROOT, "knowledge",
    "rfp_profile_review_v1_sources.json")
const PROFILE_COUPLED_RFP_QD_V8_PATH = joinpath(PROJECT_ROOT, "runs",
    "profile_coupled_rfp_qd_v8_20260813.json")
const PROFILE_COUPLED_RFP_QD_V8_SUMMARY_PATH = joinpath(PROJECT_ROOT, "runs",
    "profile_coupled_rfp_qd_v8_20260813.md")
const PLEIADES_REGRESSION_PATH = joinpath(PROJECT_ROOT, "examples",
    "pleiades_wham_isotropic_regression_genome.json")
const PLEIADES_PYTHON = joinpath(PROJECT_ROOT, ".conda-pleiades-public", "python.exe")

struct SchedulerFixtureEvaluator <: AbstractEvaluator
    id::String
    families::Set{String}
end

include("physics_compiler_v1.jl")
include("executable_physics_ir_v1.jl")
include("runtime_equilibrium_evidence_v1.jl")
include("field_topology_compiler_v1.jl")
include("magnetic_energy_inventory_v1.jl")
include("magnet_engineering_compiler_v1.jl")
include("transport_loss_compiler_v1.jl")
include("scalar_pressure_energy_inventory_v1.jl")
include("runtime_species_state_compiler_v1.jl")
include("spatial_thermodynamic_closure_compiler_v1.jl")
include("fusion_reaction_radiation_compiler_v1.jl")
include("fuel_state_admissibility_compiler_v1.jl")
include("coupled_plasma_balance_compiler_v1.jl")
include("open_flux_tube_streaming_compiler_v1.jl")
include("sourced_loss_cone_fokker_planck_compiler_v1.jl")
include("neutral_beam_source_compiler_v1.jl")
include("genome_actuator_derivation_compiler_v1.jl")
include("ambipolar_potential_response_compiler_v1.jl")
include("bounce_averaged_end_loss_compiler_v1.jl")
include("pleiades_pyfidasim_nbi_artifact_v1.jl")
include("neutral_transport_deposition_compiler_v1.jl")
include("pleiades_pyfidasim_nbi_deposition_v1.jl")
include("directed_particle_source_ir_v1.jl")
include("pleiades_pyfidasim_nbi_deposition_v2.jl")

@testset "Sealed mirror beam-energy intervention v49" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(MIRROR_BEAM_ENERGY_V49_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "51e0c6780f099896fc99c802d3fea8a8781ab3bb8dce62dbff7013c83d12a8ff"
    @test artifact["search_version"] ==
        "mirror_beam_energy_intervention_v49"
    @test artifact["stage"] ==
        "sealed_mirror_beam_energy_gene_formula_counterfactual_qd"

    trials = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(MIRROR_BEAM_ENERGY_V49_TRIALS_PATH)]
    qd = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(MIRROR_BEAM_ENERGY_V49_QD_PATH)]
    @test length(trials) == 2172
    @test length(qd) == 1086
    @test bytes2hex(sha256(read(MIRROR_BEAM_ENERGY_V49_TRIALS_PATH))) ==
        "2830a60609c4e8bc8627037b0b16d2c1be296b672f8f91409c395e518e0f1683"
    @test bytes2hex(sha256(read(MIRROR_BEAM_ENERGY_V49_QD_PATH))) ==
        "027da652bed91c1de3156f5c53eab1efd87d9d964c35dbe66d9a8b46d0ea8015"
    @test length(unique(record["physics_hash"] for record in trials)) == 2172
    @test length(unique(record["non_beam_projection_hash"] for record in trials)) == 724
    @test all(record -> record["family"] == "magnetic_mirror" &&
        record["fixed_non_beam_background"] === true &&
        record["beam_energy_gene_present"] === true &&
        record["nbi_beam_energy_synchronized"] === true &&
        record["source_complete_formula_consumed_gene"] === true &&
        record["current_evaluator_still_ignores_beam_energy"] === true &&
        record["preregistered_ratio_reproduced"] === true &&
        record["source_domain_complete"] === false &&
        record["candidate_specific_performance_ranking_authorized"] === false &&
        record["medium_fidelity_authorized"] === false &&
        record["promotion_credit"] == 0 &&
        !isempty(record["source_complete_response"]["physics_failure_ids"]) &&
        !isempty(record["source_complete_response"]["engineering_failure_ids"]),
        trials)
    @test all(record -> record["performance_ranking_used"] === false &&
        record["source_domain_complete"] === false &&
        record["promotion_credit"] == 0, qd)

    a = artifact["aggregate"]
    @test a["input_candidate_count"] == 2000
    @test a["mirror_candidate_count"] == 724
    @test a["mirror_assembly_count"] == 362
    @test a["trial_count"] == 2172
    @test a["fixed_non_beam_background_count"] == 2172
    @test a["source_complete_formula_consumed_gene_count"] == 2172
    @test a["preregistered_tau_ratio_reproduced_count"] == 2172
    @test a["hundred_keV_v48_reproduction_count"] == 724
    @test a["nonbaseline_response_change_count"] == 1448
    @test a["qd_cell_count"] == 1086
    @test a["source_domain_complete_count"] == 0
    @test a["performance_ranking_authorized_count"] == 0
    @test a["medium_fidelity_authorized_count"] == 0
    @test a["promotion_count"] == 0
    for energy in ("25", "100", "150")
        row = a["by_energy_keV"][energy]
        @test row["trial_count"] == 724
        @test row["preregistered_ratio_reproduced_count"] == 724
        @test row["physics_gate_pass_count"] == 0
        @test row["engineering_gate_pass_count"] == 0
        @test row["positive_net_electric_count"] == 0
        @test row["physics_failure_id_counts"]["fusion_gain"] == 724
        @test row["physics_failure_id_counts"]["net_electric_power"] == 724
        @test row["engineering_failure_id_counts"]["coil_curvature"] == 724
    end
    @test a["by_energy_keV"]["25"]["engineering_failure_id_counts"]["exhaust_target_heat_flux"] == 628
    @test a["by_energy_keV"]["100"]["engineering_failure_id_counts"]["exhaust_target_heat_flux"] == 266
    @test a["by_energy_keV"]["150"]["engineering_failure_id_counts"]["exhaust_target_heat_flux"] == 266

    source_paths = Dict(
        "v49_source" => joinpath(PROJECT_ROOT, "src", "search",
            "mirror_beam_energy_intervention_v49.jl"),
        "v48_source" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_family_confinement_applicability_v48.jl"),
        "v20_kernel" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "v9_generator" => joinpath(PROJECT_ROOT, "src", "search",
            "composable_cross_family_qd_v9.jl"),
        "composable_evaluator" => joinpath(PROJECT_ROOT, "src", "adapters",
            "composable_cross_family_screen_v1.jl"),
        "common_envelope_evaluator" => joinpath(PROJECT_ROOT, "src", "adapters",
            "shared_outer_envelope_screen_v1.jl"),
        "evidence_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "mirror_beam_energy_intervention_v49.json"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "mirror_beam_energy_intervention_v49.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_mirror_beam_energy_intervention_v49.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(MIRROR_BEAM_ENERGY_V49_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("Trials / non-performance QD cells: 2172/1086", summary)
    @test occursin("Preregistered tau ratios reproduced: 2172/2172", summary)
    @test occursin("Physics-gate passes at 25/100/150 keV: 0/0/0", summary)
    @test occursin(
        "Source-domain complete / ranking / medium fidelity / promotion: 0/0/0/0",
        summary)
end

@testset "Sealed tokamak regime-access intervention v50" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(TOKAMAK_REGIME_ACCESS_V50_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "ac8d6123ab168b7a2a668d149e4379d8bea2e420cf7f2b704264475b5c6ef5e7"
    @test artifact["search_version"] ==
        "tokamak_regime_access_intervention_v50"
    @test artifact["stage"] ==
        "sealed_tokamak_operating_regime_access_counterfactual_qd"

    trials = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(TOKAMAK_REGIME_ACCESS_V50_TRIALS_PATH)]
    qd = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(TOKAMAK_REGIME_ACCESS_V50_QD_PATH)]
    @test length(trials) == 720
    @test length(qd) == 360
    @test bytes2hex(sha256(read(TOKAMAK_REGIME_ACCESS_V50_TRIALS_PATH))) ==
        "21693b7a002d31b8287aa282e03452091e60099d94da661df18eaeeaebc385e1"
    @test bytes2hex(sha256(read(TOKAMAK_REGIME_ACCESS_V50_QD_PATH))) ==
        "8946a837000410a15321b6b53aa559b1a078ca0016265fd61f8413706e65ef3c"
    @test length(unique(record["physics_hash"] for record in trials)) == 720
    @test length(unique(record["non_regime_projection_hash"] for record in trials)) == 360
    @test all(record -> record["family"] == "tokamak_axisymmetric" &&
        record["fixed_non_regime_background"] === true &&
        record["regime_gene_present"] === true &&
        record["regime_gene_consumed_by_applicability_gate"] === true &&
        record["current_evaluator_performance_invariant_to_regime_gene"] === true &&
        record["source_domain_complete"] === false &&
        record["candidate_specific_confinement_comparison_authorized"] === false &&
        record["common_baseline_ranking_authorized"] === false &&
        record["medium_fidelity_authorized"] === false &&
        record["promotion_credit"] == 0 &&
        record["applicability_response"]["declared_actuator_power_upper_bound_MW"] == 0 &&
        record["applicability_response"]["actuator_upper_bound_threshold_passed"] === false &&
        record["applicability_response"]["IPB98_regime_access_precondition_passed"] === false &&
        record["applicability_response"]["actuator_heating_and_current_drive_partition_available"] === false &&
        record["applicability_response"]["absorbed_heating_fraction_available"] === false &&
        !isempty(record["performance_response"]["physics_failure_ids"]) &&
        !isempty(record["performance_response"]["engineering_failure_ids"]), trials)
    @test all(record -> record["performance_ranking_used"] === false &&
        record["source_domain_complete"] === false &&
        record["promotion_credit"] == 0, qd)

    a = artifact["aggregate"]
    @test a["input_candidate_count"] == 2000
    @test a["tokamak_candidate_count"] == 360
    @test a["tokamak_assembly_count"] == 180
    @test a["trial_count"] == 720
    @test a["fixed_non_regime_background_count"] == 720
    @test a["regime_gene_present_count"] == 720
    @test a["regime_gene_consumed_count"] == 720
    @test a["current_performance_invariant_count"] == 720
    @test a["candidate_declaration_state_change_count"] == 360
    @test a["candidate_applicability_response_state_change_count"] == 360
    @test a["candidate_precondition_state_change_count"] == 0
    @test a["qd_cell_count"] == 360
    @test a["source_domain_complete_count"] == 0
    @test a["candidate_specific_comparison_authorized_count"] == 0
    @test a["common_baseline_ranking_authorized_count"] == 0
    @test a["medium_fidelity_authorized_count"] == 0
    @test a["promotion_count"] == 0
    for state in ("0", "1")
        row = a["by_regime_state"][state]
        @test row["trial_count"] == 360
        @test row["formula_reproduced_count"] == 360
        @test row["epsilon_pass_count"] == 360
        @test row["density_band_pass_count"] == 240
        @test row["q95_pass_count"] == 360
        @test row["actuator_upper_bound_threshold_pass_count"] == 0
        @test row["regime_access_precondition_pass_count"] == 0
        @test row["physics_gate_pass_count"] == 0
        @test row["engineering_gate_pass_count"] == 0
        @test row["positive_net_electric_count"] == 0
        @test row["actuator_to_threshold_ratio_range"] == [0, 0]
        @test row["physics_failure_id_counts"]["fusion_gain"] == 360
        @test row["physics_failure_id_counts"]["net_electric_power"] == 360
        @test row["engineering_failure_id_counts"]["exhaust_target_heat_flux"] == 360
    end
    @test a["by_regime_state"]["0"]["declared_ELMy_H_mode_count"] == 0
    @test a["by_regime_state"]["1"]["declared_ELMy_H_mode_count"] == 360

    source_paths = Dict(
        "v50_source" => joinpath(PROJECT_ROOT, "src", "search",
            "tokamak_regime_access_intervention_v50.jl"),
        "v48_source" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_family_confinement_applicability_v48.jl"),
        "v20_kernel" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "v9_generator" => joinpath(PROJECT_ROOT, "src", "search",
            "composable_cross_family_qd_v9.jl"),
        "composable_evaluator" => joinpath(PROJECT_ROOT, "src", "adapters",
            "composable_cross_family_screen_v1.jl"),
        "common_envelope_evaluator" => joinpath(PROJECT_ROOT, "src", "adapters",
            "shared_outer_envelope_screen_v1.jl"),
        "evidence_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "tokamak_regime_access_intervention_v50.json"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "tokamak_regime_access_intervention_v50.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_tokamak_regime_access_intervention_v50.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(TOKAMAK_REGIME_ACCESS_V50_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("Trials / non-performance QD cells: 720/360", summary)
    @test occursin("Actuator-power upper-bound threshold pass off/on: 0/0", summary)
    @test occursin("Candidate declaration state changes: 360/360", summary)
    @test occursin("Candidate applicability-response state changes: 360/360", summary)
    @test occursin("Source-domain complete / comparison / common ranking / medium fidelity / promotion: 0/0/0/0/0", summary)
end

@testset "Sealed stellarator f_ren calibration queue v51" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(STELLARATOR_FREN_V51_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "84d171c00cae10d59b635865fdff7062acdbdb0f00ab0a78d9e930dcf1ff6eb8"
    @test artifact["search_version"] ==
        "stellarator_fren_calibration_queue_v51"
    @test artifact["stage"] ==
        "sealed_stellarator_fren_readiness_and_structural_acquisition_queue"

    read_jsonl(path) = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(path)]
    candidates = read_jsonl(STELLARATOR_FREN_V51_CANDIDATES_PATH)
    queue = read_jsonl(STELLARATOR_FREN_V51_QUEUE_PATH)
    @test length(candidates) == 288
    @test length(queue) == 18
    @test bytes2hex(sha256(read(STELLARATOR_FREN_V51_CANDIDATES_PATH))) ==
        "6304d876fb4ad9bbabebe0742c3f2502ce493203f00f7e05889e9aebc55738ea"
    @test bytes2hex(sha256(read(STELLARATOR_FREN_V51_QUEUE_PATH))) ==
        "0999ae4d531e14ee87163f3c660712f1e771fcbf095b4c9552add5a87acae159"
    @test length(unique(record["candidate_index"] for record in candidates)) == 288
    @test length(unique(record["assembly_id"] for record in candidates)) == 144
    @test all(record -> record["family"] == "stellarator" &&
        record["sealed_v46_core_reproduced"] === true &&
        record["sealed_v48_ISS04_formula_reproduced"] === true &&
        record["boundary_readiness"][
            "candidate_boundary_reconstructable_for_DESC"] === false &&
        record["boundary_readiness"][
            "candidate_equilibrium_profiles_available"] === false &&
        record["candidate_effective_ripple_at_rho_2_3_available"] === false &&
        record["candidate_high_order_effective_ripple_converged"] === false &&
        record["candidate_drift_kinetic_transport_validated"] === false &&
        record["candidate_specific_empirical_f_ren_calibrated"] === false &&
        record["candidate_specific_f_ren_value"] === nothing &&
        record["source_domain_complete"] === false &&
        record["candidate_specific_confinement_comparison_authorized"] === false &&
        record["common_baseline_ranking_authorized"] === false &&
        record["medium_fidelity_authorized"] === false &&
        record["promotion_credit"] == 0, candidates)
    @test length(unique(record["candidate_index"] for record in queue)) == 18
    @test length(unique(record["assembly_id"] for record in queue)) == 18
    @test length(unique(join(record["module_ids"], "|")
        for record in queue)) == 18
    @test all(record ->
        record["selection_method"] ==
            "per_configuration_class_greedy_maximin_over_v17_module_sets_v1" &&
        record["selection_used_performance"] === false &&
        record["selection_used_current_heuristic_f_ren"] === false &&
        record["authorized_action"] ==
            "geometry_reconstruction_and_calibration_evidence_acquisition_only" &&
        record["medium_fidelity_authorized"] === false &&
        record["promotion_credit"] == 0, queue)

    a = artifact["aggregate"]
    @test a["input_candidate_count"] == 2000
    @test a["stellarator_candidate_count"] == 288
    @test a["stellarator_assembly_count"] == 144
    @test a["configuration_class_count"] == 3
    @test a["sealed_v46_core_reproduced_count"] == 288
    @test a["sealed_v48_ISS04_formula_reproduced_count"] == 288
    @test a["explicit_candidate_boundary_count"] == 0
    @test a["candidate_equilibrium_profile_count"] == 0
    @test a["candidate_effective_ripple_count"] == 0
    @test a["candidate_high_order_ripple_converged_count"] == 0
    @test a["candidate_specific_f_ren_count"] == 0
    @test a["source_domain_complete_count"] == 0
    @test a["candidate_specific_comparison_authorized_count"] == 0
    @test a["common_baseline_ranking_authorized_count"] == 0
    @test a["medium_fidelity_authorized_count"] == 0
    @test a["promotion_count"] == 0
    @test a["acquisition_queue_count"] == 18
    @test a["acquisition_selection_used_performance_count"] == 0
    @test a["acquisition_selection_used_current_heuristic_f_ren_count"] == 0
    @test a["current_heuristic_f_ren_range"] ==
        [1.0532685649887303, 1.0619085649887303]
    @test a["current_iota_proxy_range"] == [0.8, 0.8]
    for configuration in ("stellarator_qa", "stellarator_qh", "stellarator_qi")
        row = a["by_configuration_class"][configuration]
        @test row["candidate_count"] == 96
        @test row["assembly_count"] == 48
        @test row["acquisition_queue_count"] == 6
        @test row["explicit_boundary_count"] == 0
        @test row["candidate_effective_ripple_count"] == 0
        @test row["candidate_f_ren_count"] == 0
        @test count(record -> record["configuration_class"] == configuration,
            queue) == 6
    end
    fixture = artifact["fixture_audit"]
    @test fixture["source_disjoint_from_v46_candidates"] === true
    @test fixture["low_order_effective_ripple_computation_completed"] === true
    @test fixture["refined_maximum_low_order_effective_ripple"] ==
        0.007480818674709714
    @test fixture["all_sampled_radii_below_published_relation_domain"] === true
    @test fixture["high_order_bounce2d_available"] === false
    @test fixture["candidate_f_ren_calibration_authorized"] === false

    source_paths = Dict(
        "v51_source" => joinpath(PROJECT_ROOT, "src", "search",
            "stellarator_fren_calibration_queue_v51.jl"),
        "v48_source" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_family_confinement_applicability_v48.jl"),
        "v20_kernel" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "v9_generator" => joinpath(PROJECT_ROOT, "src", "search",
            "composable_cross_family_qd_v9.jl"),
        "composable_evaluator" => joinpath(PROJECT_ROOT, "src", "adapters",
            "composable_cross_family_screen_v1.jl"),
        "evidence_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "stellarator_fren_calibration_queue_v51.json"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "stellarator_fren_calibration_queue_v51.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_stellarator_fren_calibration_queue_v51.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(STELLARATOR_FREN_V51_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("Explicit candidate boundaries / equilibrium profiles: 0/0",
        summary)
    @test occursin(
        "Candidate ripple / high-order convergence / calibrated f_ren: 0/0/0",
        summary)
    @test occursin("Structurally selected acquisition queue: 18", summary)
    @test occursin("Selection used performance / heuristic f_ren: 0/0", summary)
    @test occursin("Source-domain complete / comparison / common ranking / medium fidelity / promotion: 0/0/0/0/0", summary)
end

@testset "Sealed cross-family anchor regression v43" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(ANCHOR_REGRESSION_V43_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "8085024564ff0ad3cabf2824d58d542886214f251f744f2342e1d9ec30960dd2"
    @test artifact["search_version"] == "cross_family_anchor_regression_v43"
    @test artifact["stage"] ==
        "sealed_cross_family_known_device_anchor_regression"

    read_jsonl(path) = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(path)]
    routes = read_jsonl(ANCHOR_ROUTES_V43_PATH)
    controls = read_jsonl(SOLVER_CONTROLS_V43_PATH)
    @test length(routes) == 23
    @test length(controls) == 3
    @test bytes2hex(sha256(read(ANCHOR_ROUTES_V43_PATH))) ==
        "b72af02094d7e155eeaedcec59e412be4def089c4846c82a490a65baef1cb37c"
    @test bytes2hex(sha256(read(SOLVER_CONTROLS_V43_PATH))) ==
        "2786c051e5b11ebc35322da268b15bf311cd8c80529dcd7853a90ece77f0836f"
    @test count(item -> item["route_anchor_class"] ==
        "experimental_directional_anchor", routes) == 8
    @test count(item -> item["route_anchor_class"] ==
        "source_only_no_directional_regression", routes) == 14
    mismatches = filter(item -> item["route_anchor_class"] ==
        "source_family_mismatch", routes)
    @test length(mismatches) == 1
    @test only(mismatches)["module_id"] == "supported_dipole_cartridge"
    @test all(item -> item["candidate_specific_executable_validation_available"] ===
        false && item["candidate_specific_promotion_evidence_available"] === false &&
        item["medium_fidelity_authorized"] === false &&
        item["promotion_credit"] == 0, routes)
    @test all(item -> item["positive_control_passed"] === true &&
        item["unknown_claim_guard_passed"] === true &&
        item["candidate_specific_module_validation"] === false &&
        item["promotion_credit"] == 0, controls)

    aggregate = artifact["aggregate"]
    @test aggregate["observable_route_count"] == 23
    @test aggregate["family_count"] == 6
    @test aggregate["route_level_experimental_direction_count"] == 8
    @test aggregate["target_family_solver_baseline_count"] == 2
    @test aggregate["global_solver_control_pass_count"] == 3
    @test aggregate["unknown_claim_guard_pass_count"] == 3
    @test aggregate["candidate_specific_executable_validation_count"] == 0
    @test aggregate["source_family_mismatch_count"] == 1
    @test aggregate["medium_fidelity_authorized_count"] == 0
    @test aggregate["promotion_count"] == 0
    @test aggregate["old_domain_scale_up_authorized"] === false
    @test all(value === true for value in values(artifact["anchor_contract"]))

    source_paths = Dict(
        "v43_source" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_family_anchor_regression_v43.jl"),
        "source_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "cross_family_anchor_regression_v43_sources.json"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "cross_family_anchor_regression_v43.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_cross_family_anchor_regression_v43.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(ANCHOR_REGRESSION_V43_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin(
        "Experimental-direction / source-only / source-mismatch routes: 8/14/1",
        summary)
    @test occursin("Global solver positive controls passed: 3/3", summary)
    @test occursin(
        "Candidate-specific executable route validations: 0/23", summary)
end

@testset "Sealed experiment-anchored directional replay v44" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(DIRECTIONAL_REPLAY_V44_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "160bb34e7049c05ffc24895df3aa3c77c78d045aa2055418d42ec6dfcffab29c"
    @test artifact["search_version"] ==
        "experiment_anchored_directional_replay_v44"
    @test artifact["stage"] == "sealed_experiment_anchored_directional_replay"

    trials = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(DIRECTIONAL_TRIALS_V44_PATH)]
    @test length(trials) == 4
    @test bytes2hex(sha256(read(DIRECTIONAL_TRIALS_V44_PATH))) ==
        "71d6b71e66368dad104c93474101795b63ec3d0b6d842b7b0ef7f72184e50de9"
    @test all(item -> item["all_direction_checks_passed"] === true &&
        item["independent_known_device_validation"] === false &&
        item["candidate_module_validation"] === false &&
        item["medium_fidelity_authorized"] === false &&
        item["promotion_credit"] == 0, trials)
    @test count(item -> item["circular_calibration_replay"] === true,
        trials) == 2
    @test count(item -> item["both_endpoints_graph_valid"] === true,
        trials) == 3
    ldx = only(filter(item -> item["trial_id"] ==
        "ldx_supported_to_levitated_semantic_probe", trials))
    @test ldx["low_topology_graph_error_count"] > 0
    @test ldx["high_topology_graph_error_count"] == 0

    a = artifact["aggregate"]
    @test a["trial_count"] == 4
    @test a["mapped_experimental_anchor_module_count"] == 6
    @test a["all_direction_checks_passed_count"] == 4
    @test a["both_endpoints_graph_valid_trial_count"] == 3
    @test a["circular_calibration_replay_trial_count"] == 2
    @test a["formula_direction_replay_module_count"] == 4
    @test a["supported_topology_blocked_module_count"] == 2
    @test a["independent_known_device_validation_count"] == 0
    @test a["candidate_module_validation_count"] == 0
    @test a["medium_fidelity_authorized_count"] == 0
    @test a["promotion_count"] == 0
    @test a["old_domain_scale_up_authorized"] === false
    @test artifact["replay_contract"][
        "existing_equations_only"] === true
    @test all(value === false for (key, value) in artifact["replay_contract"]
        if key != "existing_equations_only")

    source_paths = Dict(
        "v44_source" => joinpath(PROJECT_ROOT, "src", "search",
            "experiment_anchored_directional_replay_v44.jl"),
        "v7_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "self_organized_screen_v1.jl"),
        "v7_search" => joinpath(PROJECT_ROOT, "src", "search",
            "self_organized_qd_v7.jl"),
        "v8_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "profile_coupled_rfp_screen_v1.jl"),
        "v8_search" => joinpath(PROJECT_ROOT, "src", "search",
            "profile_coupled_rfp_qd_v8.jl"),
        "source_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "cross_family_anchor_regression_v43_sources.json"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "experiment_anchored_directional_replay_v44.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_experiment_anchored_directional_replay_v44.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(DIRECTIONAL_REPLAY_V44_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("Trials / passed direction checks: 4/4", summary)
    @test occursin("Mapped experimental-anchor modules: 6/8", summary)
    @test occursin(
        "Independent known-device / candidate-module validations: 0/0",
        summary)
end

@testset "Sealed explicit dipole support topology regression v45" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(DIPOLE_SUPPORT_V45_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "36c179f709a9766fa766320d702cc1acb3f2b752736815f0251c7a4c96e4c1d4"
    @test artifact["search_version"] ==
        "dipole_support_structural_regression_v45"
    @test artifact["stage"] ==
        "sealed_explicit_dipole_support_topology_regression"

    endpoints = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(DIPOLE_SUPPORT_ENDPOINTS_V45_PATH)]
    @test length(endpoints) == 2
    @test bytes2hex(sha256(read(DIPOLE_SUPPORT_ENDPOINTS_V45_PATH))) ==
        "3555e94d3580612ae50d2710d9a10b311985846be5be9ba324f47eb95369de3c"
    @test all(item -> item["generic_genome_valid"] === true &&
        item["family_graph_valid"] === true &&
        item["v45_topology_graph_valid"] === true &&
        item["candidate_module_structurally_executed"] === true &&
        item["independent_known_device_validation"] === false &&
        item["candidate_module_independently_validated"] === false &&
        item["engineering_closure_status"] == "hard_unknown" &&
        item["medium_fidelity_authorized"] === false &&
        item["promotion_credit"] == 0 &&
        !("mars_engineering_henning_1986" in item["source_ids"]), endpoints)
    supported = only(filter(item -> item["endpoint_id"] ==
        "v45_dipole_supported", endpoints))
    levitated = only(filter(item -> item["endpoint_id"] ==
        "v45_dipole_levitated", endpoints))
    @test supported["legacy_v7_graph_error_count"] == 2
    @test levitated["legacy_v7_graph_error_count"] == 0
    @test supported["structural_graph_hash"] != levitated["structural_graph_hash"]
    @test supported["genome_physics_hash"] != levitated["genome_physics_hash"]
    @test supported["continuous_gene_hash_excluding_support_mode"] ==
        levitated["continuous_gene_hash_excluding_support_mode"]

    a = artifact["aggregate"]
    @test a["endpoint_count"] == 2
    @test a["mapped_v43_experimental_anchor_module_count"] == 2
    @test a["v43_observable_route_count"] == 23
    @test a["candidate_specific_structurally_executable_route_count"] == 2
    @test a["candidate_specific_independently_validated_route_count"] == 0
    @test a["independent_known_device_validation_count"] == 0
    @test a["paired_direction_trial_count"] == 1
    @test a["paired_direction_trial_pass_count"] == 1
    @test a["engineering_closure_count"] == 0
    @test a["medium_fidelity_authorized_count"] == 0
    @test a["promotion_count"] == 0
    @test a["old_domain_scale_up_authorized"] === false
    @test all(value === true for value in values(artifact["paired_trial"][
        "direction_and_structure_checks"]))
    @test artifact["paired_trial"]["independent_known_device_validation"] === false
    @test artifact["paired_trial"]["engineering_closure"] === false
    @test artifact["paired_trial"]["medium_fidelity_authorized"] === false
    @test artifact["paired_trial"]["promotion_credit"] == 0

    source_paths = Dict(
        "v45_source" => joinpath(PROJECT_ROOT, "src", "search",
            "dipole_support_structural_regression_v45.jl"),
        "v7_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "self_organized_screen_v1.jl"),
        "v7_search" => joinpath(PROJECT_ROOT, "src", "search",
            "self_organized_qd_v7.jl"),
        "v17_grammar" => joinpath(PROJECT_ROOT, "src", "search",
            "attribute_graph_grammar_v17.jl"),
        "source_correction" => joinpath(PROJECT_ROOT, "knowledge",
            "dipole_support_source_correction_v45.json"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "dipole_support_structural_regression_v45.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_dipole_support_structural_regression_v45.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(DIPOLE_SUPPORT_V45_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("Explicit endpoints / v45 graph-valid: 2/2", summary)
    @test occursin("Structurally executable v43 routes: 2/23", summary)
    @test occursin(
        "Independent known-device / candidate-route validations: 0/0",
        summary)
end

@testset "Sealed support-aware full-archive integration v46" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(SUPPORT_AWARE_V46_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    delete!(core["execution"]["first"], "manifest_hash")
    delete!(core["execution"]["cache_replay"], "manifest_hash")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "dd0ad59aa5cf905851b2d4d7a324d6e44a5a91256a9cac4bb489d9ecbea3151f"
    @test artifact["search_version"] ==
        "support_aware_cross_topology_kernel_v46"
    @test artifact["stage"] ==
        "sealed_full_archive_support_aware_integration_audit"

    candidates = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(SUPPORT_AWARE_V46_CANDIDATES_PATH)]
    qd = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(SUPPORT_AWARE_V46_QD_PATH)]
    @test length(candidates) == 2000
    @test length(qd) == 1000
    @test bytes2hex(sha256(read(SUPPORT_AWARE_V46_CANDIDATES_PATH))) ==
        "9d7a9f06fe72d4c44d94289257db96438d8f38dd27b8f92ee5cac507d36d1161"
    @test bytes2hex(sha256(read(SUPPORT_AWARE_V46_QD_PATH))) ==
        "84e350132708814a4d93075b32f423d2f319539e24c062b7618768b037b09c4d"
    dipole = filter(item -> item["v46_explicit_dipole_graph"] === true,
        candidates)
    passthrough = filter(item -> item["v46_integration_route"] ==
        "sealed_v20_non_dipole_passthrough", candidates)
    @test length(dipole) == 16
    @test length(passthrough) == 1984
    @test all(item -> isempty(item["topology_graph_errors"]) &&
        item["v46_source_mismatch_removed"] === true &&
        item["v46_candidate_specific_structural_route"] === true &&
        item["v46_independent_candidate_route_validation"] === false &&
        item["v46_medium_fidelity_authorized"] === false &&
        item["v46_promotion_credit"] == 0 &&
        item["proxy_five_gate_passed"] === false &&
        item["medium_fidelity_candidate_eligible"] === false, dipole)
    @test all(item -> item["v46_core_changed_from_v20"] === false,
        passthrough)
    @test length(unique(String(item["v46_structural_graph_hash"])
        for item in dipole)) == 2
    @test length(unique(String(item["physics_hash"])
        for item in dipole)) == 16

    a = artifact["aggregate"]
    @test a["candidate_count"] == 2000
    @test a["assembly_count"] == 1000
    @test a["family_count"] == 11
    @test a["samples_per_assembly"] == 2
    @test a["non_dipole_v20_core_preserved_count"] == 1984
    @test a["explicit_dipole_candidate_count"] == 16
    @test a["supported_dipole_candidate_count"] == 8
    @test a["levitated_dipole_candidate_count"] == 8
    @test a["supported_legacy_misroute_fixed_count"] == 8
    @test a["dipole_v45_graph_valid_count"] == 16
    @test a["mapped_candidate_specific_structural_route_ids"] ==
        ["dipole_levitated", "dipole_supported"]
    @test a["candidate_specific_independently_validated_route_count"] == 0
    @test a["proxy_five_gate_pass_count"] == 0
    @test a["medium_fidelity_candidate_count"] == 0
    @test a["promotion_count"] == 0
    @test a["qd_archive_cell_count"] == 1000
    @test a["old_domain_scale_up_authorized"] === false
    @test artifact["execution"]["first"]["new_commits"] == 20
    @test artifact["execution"]["cache_replay"]["new_commits"] == 0
    @test artifact["execution"]["cache_replay"]["cache_hits"] == 20
    @test artifact["execution"]["cache_replay_zero_recompute_and_hash_match"] === true
    @test artifact["execution"]["first"]["result_hash"] ==
        artifact["execution"]["cache_replay"]["result_hash"]

    source_paths = Dict(
        "v46_source" => joinpath(PROJECT_ROOT, "src", "search",
            "support_aware_cross_topology_kernel_v46.jl"),
        "v45_source" => joinpath(PROJECT_ROOT, "src", "search",
            "dipole_support_structural_regression_v45.jl"),
        "v20_kernel" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "v19_execution" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_sharded_execution_v19.jl"),
        "v17_grammar" => joinpath(PROJECT_ROOT, "src", "search",
            "attribute_graph_grammar_v17.jl"),
        "source_correction" => joinpath(PROJECT_ROOT, "knowledge",
            "dipole_support_source_correction_v45.json"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "support_aware_cross_topology_v46.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_support_aware_cross_topology_v46.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(SUPPORT_AWARE_V46_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("Candidates / assemblies / families: 2000/1000/11", summary)
    @test occursin("Non-dipole v20 core preserved: 1984/1984", summary)
    @test occursin("Five-gate / medium-fidelity / promotion counts: 0/0/0",
        summary)
end

@testset "Sealed cross-family held-out quantitative benchmark v47" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(HELDOUT_QUANTITATIVE_V47_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "1b8a9c60fab1e0955bb0705f0c50b2758934d6a31ac53b1cec6f92b9525cc0e2"
    @test artifact["search_version"] ==
        "cross_family_heldout_quantitative_benchmark_v47"
    @test artifact["stage"] ==
        "sealed_cross_family_heldout_benchmark_readiness_audit"

    routes = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            HELDOUT_QUANTITATIVE_V47_ROUTES_PATH)]
    @test length(routes) == 5
    @test bytes2hex(sha256(read(HELDOUT_QUANTITATIVE_V47_ROUTES_PATH))) ==
        "b597dd408b8eefb382e417e73d64e1ef0584c7553dc34ed64208fc7c0cfb362e"
    @test all(item ->
        item["calibration_source_disjoint_from_heldout"] === true &&
        item["independent_known_device_magnitude_validation"] === false &&
        item["candidate_specific_independently_validated"] === false &&
        item["medium_fidelity_authorized"] === false &&
        item["promotion_credit"] == 0, routes)
    rfp = filter(item -> item["family"] == "reversed_field_pinch", routes)
    missing = filter(item -> item["benchmark_status"] ==
        "model_output_missing", routes)
    @test length(rfp) == 2
    @test length(missing) == 3
    @test all(item -> item["benchmark_executable"] === true &&
        item["numeric_protocol_passed"] === false &&
        item["model_operating_point_matched"] === false &&
        item["comparison"]["factor_error"] > 2.0, rfp)
    @test all(item -> item["benchmark_executable"] === false &&
        !isempty(item["missing_required_model_output_ids"]), missing)
    @test isapprox(only(filter(item -> item["route_id"] == "rfp_ppcd",
        rfp))["comparison"]["factor_error"], 5.09906507347267; atol = 1e-12)
    @test isapprox(only(filter(item -> item["route_id"] ==
        "rfp_ppcd_profile", rfp))["comparison"]["factor_error"],
        7.648597610209; atol = 1e-12)

    a = artifact["aggregate"]
    @test a["route_record_count"] == 5
    @test a["family_count"] == 3
    @test a["heldout_primary_source_count"] == 3
    @test a["calibration_heldout_disjoint_route_count"] == 5
    @test a["numeric_comparator_executable_route_count"] == 2
    @test a["numeric_protocol_pass_route_count"] == 0
    @test a["numeric_protocol_fail_route_count"] == 2
    @test a["model_output_missing_route_count"] == 3
    @test a["missing_required_output_class_count"] == 7
    @test a["operating_point_matched_route_count"] == 0
    @test a["independent_known_device_magnitude_validation_route_count"] == 0
    @test a["candidate_specific_independently_validated_route_count"] == 0
    @test a["v43_observable_route_count"] == 23
    @test a["medium_fidelity_authorized_count"] == 0
    @test a["promotion_count"] == 0
    @test a["old_domain_scale_up_authorized"] === false
    @test all(value === true for (key, value) in artifact["benchmark_contract"]
        if key != "known_device_result_can_promote_candidate")
    @test artifact["benchmark_contract"][
        "known_device_result_can_promote_candidate"] === false

    source_paths = Dict(
        "v47_source" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_family_heldout_quantitative_benchmark_v47.jl"),
        "v44_source" => joinpath(PROJECT_ROOT, "src", "search",
            "experiment_anchored_directional_replay_v44.jl"),
        "v45_source" => joinpath(PROJECT_ROOT, "src", "search",
            "dipole_support_structural_regression_v45.jl"),
        "evidence_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "cross_family_heldout_quantitative_v47.json"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "cross_family_heldout_quantitative_benchmark_v47.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_cross_family_heldout_quantitative_benchmark_v47.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(HELDOUT_QUANTITATIVE_V47_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("Held-out routes / families / sources: 5/3/3", summary)
    @test occursin(
        "Numeric comparator executable / protocol pass / protocol fail: 2/0/2",
        summary)
    @test occursin(
        "Independent known-device / candidate-route validations: 0/0",
        summary)
end

@testset "Sealed cross-family confinement applicability audit v48" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(CONFINEMENT_APPLICABILITY_V48_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "b4b7f7d3d8775001ebbfd55572c064293a5d5770069bc7eac61e04862d22ac65"
    @test artifact["search_version"] ==
        "cross_family_confinement_applicability_v48"
    @test artifact["stage"] ==
        "sealed_cross_family_confinement_provenance_and_applicability_audit"

    records = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            CONFINEMENT_APPLICABILITY_V48_CANDIDATES_PATH)]
    @test length(records) == 1642
    @test bytes2hex(sha256(read(
        CONFINEMENT_APPLICABILITY_V48_CANDIDATES_PATH))) ==
        "c83c5428898c4a7e6717b6429333e99c2ad3bd7baf363fcf9188b74c9fd672cb"
    @test all(record -> record["source_domain_complete"] === false &&
        record["candidate_specific_confinement_comparison_authorized"] === false &&
        record["common_baseline_ranking_authorized"] === false &&
        record["medium_fidelity_authorized"] === false &&
        record["promotion_credit"] == 0 &&
        !isempty(record["applicability_blockers"]), records)

    tokamak = filter(record -> record["family"] ==
        "tokamak_axisymmetric", records)
    hybrid = filter(record -> record["family"] == "tokamak_3d_hybrid", records)
    stellarator = filter(record -> record["family"] == "stellarator", records)
    mirror = filter(record -> record["family"] == "magnetic_mirror", records)
    frc = filter(record -> record["family"] ==
        "field_reversed_configuration", records)
    spheromak = filter(record -> record["family"] == "spheromak", records)
    @test length(tokamak) == 360
    @test length(hybrid) == 48
    @test length(stellarator) == 288
    @test length(mirror) == 724
    @test length(frc) == 150
    @test length(spheromak) == 72
    @test all(record -> record["formula_numerically_reproduced"] === true &&
        record["source_domain_checks"]["explicit_ELMy_H_mode_declared"] === false &&
        record["source_domain_checks"]["standard_tokamak_epsilon_domain_passed"] === true &&
        record["source_domain_checks"]["high_density_degradation_warning"] === false,
        tokamak)
    @test all(record -> record["formula_numerically_reproduced"] === true &&
        record["source_domain_checks"]["candidate_specific_empirical_f_ren_calibrated"] === false,
        stellarator)
    @test all(record -> record["formula_numerically_reproduced"] === true &&
        record["source_domain_checks"]["both_parent_source_domains_complete"] === false,
        hybrid)
    @test all(record -> record["formula_numerically_reproduced"] === true &&
        record["source_domain_checks"]["screen_beam_energy_search_gene_present"] === false &&
        record["source_domain_checks"]["declared_beam_energy_used_by_current_model"] === false &&
        record["source_domain_checks"]["declared_beam_energy_matches_implicit_100keV"] === true &&
        record["source_domain_checks"]["declared_nbi_beam_energy_keV"] == 100.0 &&
        isapprox(record["source_domain_checks"]["current_to_source_complete_time_ratio"],
            1.0; atol = 1e-12), mirror)
    @test all(record -> record["formula_numerically_reproduced"] === false &&
        record["source_domain_checks"]["temperature_direction_consistent"] === false &&
        record["source_domain_checks"]["current_model_temperature_exponent_at_fixed_geometry_and_field"] == -1.0 &&
        record["source_domain_checks"]["C2_C2U_measured_temperature_exponent"] == 1.8,
        frc)
    @test all(record -> record["formula_numerically_reproduced"] === false &&
        record["source_domain_checks"]["family_specific_confinement_scaling_available"] === false,
        spheromak)

    a = artifact["aggregate"]
    @test a["input_candidate_count"] == 2000
    @test a["input_family_count"] == 11
    @test a["scoped_candidate_count"] == 1642
    @test a["scoped_family_count"] == 6
    @test a["outside_scope_candidate_count"] == 358
    @test a["formula_numerically_reproduced_candidate_count"] == 1420
    @test a["source_domain_complete_candidate_count"] == 0
    @test a["tokamak_standard_epsilon_domain_pass_count"] == 360
    @test a["mirror_declared_beam_energy_matches_implicit_count"] == 724
    @test a["frc_temperature_direction_conflict_count"] == 150
    @test a["candidate_specific_comparison_authorized_count"] == 0
    @test a["common_baseline_ranking_authorized_count"] == 0
    @test a["medium_fidelity_authorized_count"] == 0
    @test a["promotion_count"] == 0
    @test all(value === true for (key, value) in artifact["audit_contract"]
        if key != "audit_can_promote_candidate")
    @test artifact["audit_contract"]["audit_can_promote_candidate"] === false

    source_paths = Dict(
        "v48_source" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_family_confinement_applicability_v48.jl"),
        "v20_kernel" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "v9_generator" => joinpath(PROJECT_ROOT, "src", "search",
            "composable_cross_family_qd_v9.jl"),
        "composable_evaluator" => joinpath(PROJECT_ROOT, "src", "adapters",
            "composable_cross_family_screen_v1.jl"),
        "common_envelope_evaluator" => joinpath(PROJECT_ROOT, "src", "adapters",
            "shared_outer_envelope_screen_v1.jl"),
        "evidence_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "cross_family_confinement_applicability_v48.json"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "cross_family_confinement_applicability_v48.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_cross_family_confinement_applicability_v48.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(CONFINEMENT_APPLICABILITY_V48_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("Input / scoped / outside-scope candidates: 2000/1642/358",
        summary)
    @test occursin("Formula reproduced / source-domain complete: 1420/0", summary)
    @test occursin(
        "Candidate comparison / common ranking / medium fidelity / promotion: 0/0/0/0",
        summary)
end

@testset "Sealed 11-family frontier causal decomposition v33" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(FRONTIER_CAUSAL_V33_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "1c270745569ac534e7a843ad9dfeabd30a22b25b0c6d814f9dc8309727387a07"
    contract = artifact["decomposition_contract"]
    @test contract["record_count"] == 55
    @test contract["family_count"] == 11
    @test contract["records_per_family"] == 5
    @test contract["raw_result_reconstruction_required"] === true
    @test contract["named_margin_minimum_must_match_v32"] === true
    @test contract["classification_is_bookkeeping_not_causal_effect"] === true
    @test contract["gate_thresholds_changed"] === false
    @test contract["new_physics_evaluations"] == 0
    @test contract["robustness_evaluations"] == 0
    records = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            FRONTIER_CAUSAL_RECORDS_V33_PATH)]
    @test length(records) == 55
    @test bytes2hex(sha256(read(FRONTIER_CAUSAL_RECORDS_V33_PATH))) ==
        "7ebf8e8c41dc42c7ec7ec6271a8e6858eaf58ca686a2ee892e7548f77807c722"
    @test length(unique(String(record["family"]) for record in records)) == 11
    @test all(family -> count(record -> record["family"] == family,
        records) == 5, unique(String(record["family"])
            for record in records))
    @test all(record -> record["raw_result_reconstruction_match"] === true &&
        record["diagnostic_decomposition_authorized"] === true &&
        record["five_gate_comparison_authorized"] === false &&
        record["robustness_evaluation_authorized"] === false &&
        record["medium_fidelity_authorized"] === false &&
        record["promoted"] === false, records)
    @test all(record -> record["primary_limiting_margin"]["value"] ==
        first(record["limiting_named_margins"])["value"], records)
    aggregate = artifact["aggregate"]
    global_summary = aggregate["global_summary"]
    @test aggregate["record_count"] == 55
    @test aggregate["family_count"] == 11
    @test aggregate["records_per_family"] == 5
    @test aggregate["all_raw_results_reconstructed"] === true
    @test global_summary["primary_margin_counts"] == Dict(
        "net_electric_power" => 35,
        "compression_work_authority" => 5,
        "driver_wall_plug_and_repeat_rate_validation" => 5,
        "on_axis_regular_current_profile" => 5,
        "particle_loss" => 5)
    @test global_summary["primary_domain_counts"] == Dict(
        "power_cycle" => 40, "plasma_physics" => 10,
        "evidence_validation" => 5)
    @test global_summary["missing_requirement_counts"][
        "remote_maintenance"] == 35
    @test global_summary["missing_requirement_counts"]["edge_transport"] == 15
    @test global_summary["missing_requirement_counts"]["target_heat_flux"] == 15
    @test length(aggregate["systemic_primary_margins"]) == 1
    @test first(aggregate["systemic_primary_margins"])["margin_id"] ==
        "net_electric_power"
    @test first(aggregate["systemic_primary_margins"])["family_count"] == 7
    families = aggregate["family_summaries"]
    @test first(families["magnetic_mirror"]["top_primary_margins"])["id"] ==
        "net_electric_power"
    @test first(families["inertial_confinement_fusion"][
        "top_primary_margins"])["id"] ==
        "driver_wall_plug_and_repeat_rate_validation"
    @test first(families["magnetized_target_fusion"][
        "top_primary_margins"])["id"] == "compression_work_authority"
    @test first(families["reversed_field_pinch"][
        "top_primary_margins"])["id"] == "on_axis_regular_current_profile"
    @test first(families["sheared_flow_z_pinch"][
        "top_primary_margins"])["id"] == "particle_loss"
    @test aggregate["promotion_count"] == 0
    @test aggregate["medium_fidelity_authorized_count"] == 0
    @test aggregate["five_gate_comparison_authorized"] === false
    @test aggregate["robustness_evaluation_authorized"] === false
    source_paths = Dict(
        "v33_source" => joinpath(PROJECT_ROOT, "src", "search",
            "frontier_causal_decomposition_v33.jl"),
        "v32_source" => joinpath(PROJECT_ROOT, "src", "search",
            "diagnostic_cross_family_qd_v32.jl"),
        "v20_source" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "frontier_causal_decomposition_v33.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_frontier_causal_decomposition_v33.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(FRONTIER_CAUSAL_V33_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("Reconstructed records / families / records per family: 55/11/5",
        summary)
    @test occursin("net_electric_power:35", summary)
    @test occursin("remote_maintenance:35", summary)
    @test occursin("Promotions / medium-fidelity authorizations: 0/0", summary)
end

@testset "Frontier formula ownership and local proxy sensitivity v34" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(FRONTIER_SENSITIVITY_V34_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "bb8c55d557aa155dc2e5853c22dabcb3cba849fffa9c2a09eb25c3bf79954c26"
    contract = artifact["sensitivity_contract"]
    @test contract["record_count"] == 55
    @test contract["family_count"] == 11
    @test contract["records_per_family"] == 5
    @test contract["coordinates_per_record"] == 24
    @test contract["unit_delta"] == 0.02
    @test contract["coordinate_perturbation_pairs"] == 1_320
    @test contract["perturbed_proxy_evaluations"] == 2_640
    @test contract["base_raw_result_reconstruction_required"] === true
    @test contract["topology_changes_authorized"] === false
    @test contract["gate_thresholds_changed"] === false
    @test contract["physical_causal_effect_claimed"] === false
    records = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            FRONTIER_SENSITIVITY_RECORDS_V34_PATH)]
    @test length(records) == 55
    @test bytes2hex(sha256(read(FRONTIER_SENSITIVITY_RECORDS_V34_PATH))) ==
        "3e677129b91a61909aa05035092ce4b84377a650e01403ba44e9dbc57959fb03"
    @test length(unique(String(record["family"]) for record in records)) == 11
    @test all(family -> count(record -> record["family"] == family,
        records) == 5, unique(String(record["family"])
            for record in records))
    @test all(record -> record["coordinate_count"] == 24 &&
        length(record["coordinate_sensitivities"]) == 24 &&
        record["base_raw_result_reconstruction_match"] === true &&
        record["physical_causal_effect_claimed"] === false &&
        record["diagnostic_proxy_sensitivity_authorized"] === true &&
        record["robustness_evaluation_authorized"] === false &&
        record["five_gate_comparison_authorized"] === false &&
        record["medium_fidelity_authorized"] === false &&
        record["promoted"] === false, records)
    @test all(item -> item["changed_gene_path_count"] ==
        length(item["changed_gene_paths"]),
        (item for record in records for item in
            record["coordinate_sensitivities"]))
    aggregate = artifact["aggregate"]
    @test aggregate["record_count"] == 55
    @test aggregate["family_count"] == 11
    @test aggregate["coordinate_count_per_record"] == 24
    @test aggregate["total_coordinate_perturbation_pairs"] == 1_320
    @test aggregate["total_perturbed_proxy_evaluations"] == 2_640
    @test aggregate["local_zero_crossing_count"] == 0
    @test aggregate["all_raw_results_reconstructed"] === true
    @test aggregate["net_electric_primary_record_count"] == 35
    @test aggregate["net_electric_composable_evaluator_count"] == 30
    @test aggregate["net_electric_composable_evaluator_fraction"] == 6 / 7
    @test aggregate["shared_proxy_confounding_detected"] === true
    @test aggregate["family_count_with_topology_primary_response_aliasing"] == 11
    @test length(aggregate[
        "families_with_topology_primary_response_aliasing"]) == 11
    @test aggregate["topology_primary_response_aliasing_detected"] === true
    @test aggregate["physical_causal_effect_claimed"] === false
    @test aggregate["promotion_count"] == 0
    @test aggregate["medium_fidelity_authorized_count"] == 0
    families = aggregate["family_summaries"]
    @test all(summary["record_count"] == 5 &&
        summary["graph_count"] == 5 &&
        summary["unique_primary_response_signature_count"] == 1 &&
        summary["local_zero_crossing_count"] == 0 &&
        summary["raw_reconstruction_count"] == 5
        for summary in values(families))
    expected_dimensions = Dict(
        "field_reversed_configuration" => 2,
        "levitated_dipole" => 3,
        "magnetic_mirror" => 12,
        "magnetized_target_fusion" => 1,
        "reversed_field_pinch" => 8,
        "sheared_flow_z_pinch" => 13,
        "spheromak" => 3,
        "stellarator" => 3,
        "tokamak_3d_hybrid" => 3,
        "tokamak_axisymmetric" => 3)
    for (family, dimension) in expected_dimensions
        @test all(record["best_coordinate_dimension"] == dimension
            for record in records if record["family"] == family)
    end
    icf = [record for record in records if
        record["family"] == "inertial_confinement_fusion"]
    @test all(record["best_coordinate_dimension"] === nothing &&
        record["affected_coordinate_count"] == 0 &&
        record["best_endpoint_improvement"] == 0 for record in icf)
    @test length(artifact["formula_ownership_bindings"]) == 6
    for binding in artifact["formula_ownership_bindings"]
        source_path = joinpath(PROJECT_ROOT,
            split(String(binding["source_relative_path"]), '/')...)
        @test isfile(source_path)
        @test binding["source_sha256"] == bytes2hex(sha256(read(source_path)))
        @test !isempty(binding["formula_ownership_sites"])
        @test artifact["source_hashes"][
            "evaluator:$(binding["evaluator_id"])"] ==
            binding["source_sha256"]
    end
    source_paths = Dict(
        "v34_source" => joinpath(PROJECT_ROOT, "src", "search",
            "frontier_proxy_sensitivity_v34.jl"),
        "v33_source" => joinpath(PROJECT_ROOT, "src", "search",
            "frontier_causal_decomposition_v33.jl"),
        "v20_source" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "frontier_proxy_sensitivity_v34.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_frontier_proxy_sensitivity_v34.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(FRONTIER_SENSITIVITY_V34_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("Records / families / coordinates per record: 55/11/24",
        summary)
    @test occursin("Coordinate pairs / perturbed proxy evaluations: 1320/2640",
        summary)
    @test occursin("Local primary-margin zero crossings: 0/55", summary)
    @test occursin("Families with topology-primary-response aliasing: 11/11",
        summary)
    @test occursin("Promotions / medium-fidelity authorizations: 0/0", summary)
end

@testset "Topology-module matched-pair influence audit v35" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(TOPOLOGY_INFLUENCE_V35_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "5c807e3e8ce3fcbc4fb8f27420258e4b215bbf6c5bd5835ede9df561b7a80384"
    contract = artifact["audit_contract"]
    @test contract["record_count"] == 55
    @test contract["family_count"] == 11
    @test contract["graphs_per_family"] == 5
    @test contract["pairs_per_family"] == 10
    @test contract["graph_pair_count"] == 110
    @test contract["pairwise_co_difference_is_single_module_causality"] === false
    @test contract["topology_changes_authorized"] === false
    @test contract["gate_thresholds_changed"] === false
    pairs = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(TOPOLOGY_ALIAS_PAIRS_V35_PATH)]
    queue = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(TOPOLOGY_MODULE_QUEUE_V35_PATH)]
    @test length(pairs) == 110
    @test length(queue) == 74
    @test bytes2hex(sha256(read(TOPOLOGY_ALIAS_PAIRS_V35_PATH))) ==
        "1dfd2062e366e643cd83db3c9f237463c6ea53a653c4ce1b2895f7de5f569cd5"
    @test bytes2hex(sha256(read(TOPOLOGY_MODULE_QUEUE_V35_PATH))) ==
        "7b1115098b652e660c2fdd2ab11932e1f98111f3d3e646b0b3c6cd253ff31fd9"
    @test length(unique(String(pair["family"]) for pair in pairs)) == 11
    @test all(family -> count(pair -> pair["family"] == family, pairs) == 10,
        unique(String(pair["family"]) for pair in pairs))
    @test all(pair -> pair["first_graph_hash"] != pair["second_graph_hash"] &&
        !isempty(pair["module_symmetric_difference"]) &&
        pair["primary_response_signature_identical"] === true &&
        pair["topology_primary_response_alias_pair"] === true &&
        pair["module_causal_effect_claimed"] === false, pairs)
    @test count(pair -> pair["single_layer_substitution"] === true,
        pairs) == 25
    @test count(pair -> pair["single_layer_alias_pair"] === true,
        pairs) == 25
    @test count(pair -> pair["gene_path_signature_identical"] === false,
        pairs) == 22
    @test count(pair ->
        pair["missing_requirement_signature_identical"] === false,
        pairs) == 34
    aggregate = artifact["aggregate"]
    @test aggregate["input_record_count"] == 55
    @test aggregate["family_count"] == 11
    @test aggregate["graph_pair_count"] == 110
    @test aggregate["primary_response_alias_pair_count"] == 110
    @test aggregate["single_layer_substitution_pair_count"] == 25
    @test aggregate["single_layer_alias_pair_count"] == 25
    @test aggregate["gene_path_signature_difference_pair_count"] == 22
    @test aggregate["missing_requirement_difference_pair_count"] == 34
    @test aggregate["implicated_module_count"] == 74
    @test aggregate["tier_1_module_count"] == 24
    @test aggregate["topology_to_primary_proxy_binding_complete"] === false
    @test aggregate["old_domain_scale_up_authorized"] === false
    @test aggregate["module_causal_effect_claimed"] === false
    @test aggregate["promotion_count"] == 0
    @test aggregate["medium_fidelity_authorized_count"] == 0
    @test all(summary["graph_count"] == 5 &&
        summary["graph_pair_count"] == 10 &&
        summary["primary_response_alias_pair_count"] == 10
        for summary in values(aggregate["family_summaries"]))
    tier1 = [item for item in queue if
        item["repair_priority_tier"] == "tier_1_matched_layer_alias"]
    @test length(tier1) == 24
    tier1_counts = Dict(String(item["module_id"]) =>
        Int(item["single_layer_alias_pair_count"]) for item in tier1)
    @test tier1_counts["segmented_external_remote"] == 5
    @test tier1_counts["shielded_service_cassettes"] == 4
    @test tier1_counts["demountable_rebco"] == 4
    @test tier1_counts["fixed_external_superconducting"] == 3
    @test all(item["single_module_causal_effect_proven"] === false
        for item in queue)
    source_paths = Dict(
        "v35_source" => joinpath(PROJECT_ROOT, "src", "search",
            "topology_module_influence_audit_v35.jl"),
        "v34_source" => joinpath(PROJECT_ROOT, "src", "search",
            "frontier_proxy_sensitivity_v34.jl"),
        "v17_source" => joinpath(PROJECT_ROOT, "src", "search",
            "attribute_graph_grammar_v17.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "topology_module_influence_audit_v35.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_topology_module_influence_audit_v35.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(TOPOLOGY_INFLUENCE_V35_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("Input graphs / families / graph pairs: 55/11/110", summary)
    @test occursin("Primary-response alias pairs: 110/110", summary)
    @test occursin("Single-layer substitution / aliased pairs: 25/25", summary)
    @test occursin("Implicated / tier-1 modules: 74/24", summary)
    @test occursin("Old-domain scale-up authorized: `false`", summary)
    @test occursin("Promotions / medium-fidelity authorizations: 0/0", summary)
end

@testset "Full named-margin, gate, and evidence response audit v36" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(FULL_RESPONSE_AUDIT_V36_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "c183755775153f6d87ecd264e1a64062ff82506b9b490372c9653d4aa927afe6"
    contract = artifact["audit_contract"]
    @test contract["response_record_count"] == 55
    @test contract["family_count"] == 11
    @test contract["graphs_per_family"] == 5
    @test contract["graph_pair_count"] == 110
    @test contract["module_count"] == 74
    @test contract["complete_named_margin_vectors_required"] === true
    @test contract["raw_gate_dictionaries_required"] === true
    @test contract["evidence_gap_ledgers_kept_separate"] === true
    @test contract["pairwise_co_difference_is_single_module_causality"] === false
    @test contract["topology_changes_authorized"] === false
    @test contract["gate_thresholds_changed"] === false
    responses = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(FULL_RESPONSE_RECORDS_V36_PATH)]
    pairs = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(FULL_RESPONSE_PAIRS_V36_PATH)]
    queue = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(MODULE_RESPONSE_ROUTES_V36_PATH)]
    @test length(responses) == 55
    @test length(pairs) == 110
    @test length(queue) == 74
    @test bytes2hex(sha256(read(FULL_RESPONSE_RECORDS_V36_PATH))) ==
        "cf8fefad33ce1da18dd5a2c071802c794f25a1fd8ed76b8c7ecc59f85c541d2f"
    @test bytes2hex(sha256(read(FULL_RESPONSE_PAIRS_V36_PATH))) ==
        "787cb7a9cff8adef5b11ecd5fe27b28d344ad35e96e5b5a6506c27d0ae9a1952"
    @test bytes2hex(sha256(read(MODULE_RESPONSE_ROUTES_V36_PATH))) ==
        "20f798b6d0d10413fd54480dd3b336275595be24051202d82d596cd186e170e1"
    @test length(unique(String(record["family"]) for record in responses)) == 11
    @test all(family -> count(record -> record["family"] == family,
        responses) == 5, unique(String(record["family"])
            for record in responses))
    @test all(record -> length(record["raw_gates"]) == 5 &&
        record["named_margin_count"] == length(record["named_margins"]) &&
        record["failed_named_margin_count"] ==
            length(record["failed_named_margins"]) &&
        record["raw_result_reconstruction_match"] === true &&
        record["full_response_audit_authorized"] === true &&
        record["single_module_causal_effect_claimed"] === false &&
        record["old_domain_scale_up_authorized"] === false &&
        record["medium_fidelity_authorized"] === false &&
        record["promoted"] === false, responses)
    signature_mismatches = [record for record in responses if
        record["v34_archived_primary_response_signature_recomputed_match"] ===
            false]
    @test length(signature_mismatches) == 5
    @test all(record -> record["family"] ==
        "inertial_confinement_fusion", signature_mismatches)
    classifications = Dict(name => count(pair ->
        pair["response_classification"] == name, pairs) for name in (
        "evaluated_response_and_evidence_variation",
        "evaluated_response_variation_only", "evidence_variation_only",
        "full_evaluated_and_evidence_alias"))
    @test classifications["evaluated_response_and_evidence_variation"] == 12
    @test classifications["evaluated_response_variation_only"] == 27
    @test classifications["evidence_variation_only"] == 22
    @test classifications["full_evaluated_and_evidence_alias"] == 49
    @test count(pair -> pair["full_evaluated_response_identical"] === true,
        pairs) == 71
    @test count(pair -> pair["full_margin_vector_identical"] === true,
        pairs) == 71
    @test count(pair -> pair["raw_gate_dictionary_identical"] === true,
        pairs) == 110
    @test count(pair -> pair["evidence_gap_ledger_identical"] === true,
        pairs) == 76
    @test count(pair -> pair["raw_result_hash_identical"] === true,
        pairs) == 58
    @test count(pair -> pair["single_layer_substitution"] === true &&
        pair["full_evaluated_response_identical"] === true &&
        pair["evidence_gap_ledger_identical"] === true, pairs) == 21
    routes = Dict(name => count(item -> item["observed_response_route"] == name,
        queue) for name in (
        "matched_pair_evaluated_response_variation_observed",
        "matched_pair_evidence_variation_only",
        "matched_pair_no_named_margin_gate_or_evidence_variation",
        "multilayer_co_difference_evaluated_response_variation",
        "multilayer_co_difference_evidence_variation_only"))
    @test routes["matched_pair_evaluated_response_variation_observed"] == 4
    @test routes["matched_pair_evidence_variation_only"] == 2
    @test routes["matched_pair_no_named_margin_gate_or_evidence_variation"] == 18
    @test routes["multilayer_co_difference_evaluated_response_variation"] == 29
    @test routes["multilayer_co_difference_evidence_variation_only"] == 21
    @test all(item -> item["single_module_causal_effect_proven"] === false,
        queue)
    aggregate = artifact["aggregate"]
    @test aggregate["full_evaluated_response_alias_pair_count"] == 71
    @test aggregate["full_margin_alias_pair_count"] == 71
    @test aggregate["raw_gate_alias_pair_count"] == 110
    @test aggregate["evidence_alias_pair_count"] == 76
    @test aggregate["raw_result_hash_alias_pair_count"] == 58
    @test aggregate["single_layer_full_response_alias_pair_count"] == 21
    @test aggregate[
        "v34_archived_primary_response_signature_recomputed_match_count"] == 50
    @test aggregate["old_domain_scale_up_authorized"] === false
    @test aggregate["single_module_causal_effect_claimed"] === false
    @test aggregate["promotion_count"] == 0
    @test aggregate["medium_fidelity_authorized_count"] == 0
    source_paths = Dict(
        "v36_source" => joinpath(PROJECT_ROOT, "src", "search",
            "full_margin_evidence_response_audit_v36.jl"),
        "v35_source" => joinpath(PROJECT_ROOT, "src", "search",
            "topology_module_influence_audit_v35.jl"),
        "v34_source" => joinpath(PROJECT_ROOT, "src", "search",
            "frontier_proxy_sensitivity_v34.jl"),
        "v20_source" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "v17_source" => joinpath(PROJECT_ROOT, "src", "search",
            "attribute_graph_grammar_v17.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "full_margin_evidence_response_audit_v36.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_full_margin_evidence_response_audit_v36.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(FULL_RESPONSE_AUDIT_V36_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin(
        "Response records / families / graph pairs / modules: 55/11/110/74",
        summary)
    @test occursin("full_evaluated_and_evidence_alias=49", summary)
    @test occursin(
        "Full evaluated-response / margin / raw-gate / evidence aliases: 71/71/110/76",
        summary)
    @test occursin("Single-layer full-response aliases: 21", summary)
    @test occursin(
        "matched_pair_no_named_margin_gate_or_evidence_variation=18",
        summary)
    @test occursin("Old-domain scale-up authorized: `false`", summary)
    @test occursin("Promotions / medium-fidelity authorizations: 0/0", summary)
end

@testset "Disconnected-module hard-unknown influence contract v37" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(DISCONNECTED_CONTRACT_V37_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "d212d5a4514a7af0ff80e97614aaac0000063fee654f0f7f3b1e73471240c159"
    scope = artifact["contract_scope"]
    @test scope["contract_group_count"] == 8
    @test scope["contract_module_count"] == 18
    @test scope["family_count"] == 10
    @test scope["fixed_background_ablation_case_count"] == 21
    @test scope["source_record_count"] == 10
    @test scope["target_named_margin_count"] == 19
    @test scope["target_evidence_requirement_count"] == 17
    @test scope["numeric_formula_supplied"] === false
    @test scope["favorable_sign_preregistered"] === false
    @test scope["single_module_causality_claimed"] === false
    @test scope["gate_thresholds_changed"] === false
    modules = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(DISCONNECTED_MODULES_V37_PATH)]
    cases = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(FIXED_BACKGROUND_CASES_V37_PATH)]
    sources = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(DISCONNECTED_SOURCES_V37_PATH)]
    @test length(modules) == 18
    @test length(cases) == 21
    @test length(sources) == 10
    @test bytes2hex(sha256(read(DISCONNECTED_MODULES_V37_PATH))) ==
        "09c562ebac9dfda295568d8ea47acf43c9d782db76203294583ca4173e288688"
    @test bytes2hex(sha256(read(FIXED_BACKGROUND_CASES_V37_PATH))) ==
        "8a2e172265b860a5dd0d81c1e1ef83852230cba62f9d2e05e0eb3eb97e84d6b7"
    @test bytes2hex(sha256(read(DISCONNECTED_SOURCES_V37_PATH))) ==
        "83a9bdf17781a97987d629e0ecb061dfa9eb9cff4a170b71a6c90aa7960cecbf"
    @test length(unique(String(item["module_id"]) for item in modules)) == 18
    @test length(unique(String(item["group_id"]) for item in modules)) == 8
    @test all(item -> item["observed_v36_route"] ==
        "matched_pair_no_named_margin_gate_or_evidence_variation" &&
        item["binding_state"] ==
            "hard_unknown_until_candidate_specific_ablation_passes" &&
        !isempty(item["source_trace"]) &&
        item["matched_ablation_case_count"] > 0 &&
        !isempty(item["candidate_specific_input_semantics"]) &&
        !isempty(item["target_named_margin_ids"]) &&
        !isempty(item["target_evidence_requirement_ids"]) &&
        item["quantitative_input_evidence_complete"] === false &&
        item["candidate_specific_binding_implemented"] === false &&
        item["formula_implementation_authorized"] === false &&
        item["direct_gate_credit_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["single_module_physical_causality_proven"] === false &&
        item["promotion_credit"] == 0, modules)
    tier_counts = Dict(tier => count(item -> item["priority_tier"] == tier,
        modules) for tier in ("tier_1_physics_decision_surface",
        "tier_2_power_and_exhaust_closure", "tier_3_engineering_closure"))
    @test tier_counts["tier_1_physics_decision_surface"] == 7
    @test tier_counts["tier_2_power_and_exhaust_closure"] == 7
    @test tier_counts["tier_3_engineering_closure"] == 4
    @test length(unique(String(item["v35_pair_hash"]) for item in cases)) == 21
    @test all(item -> 1 <= item["contracted_module_count"] <= 2 &&
        item["contracted_module_count"] == length(item["module_ids"]) &&
        item["ablation_repair_accepted"] === false, cases)
    @test count(item -> item["contracted_module_count"] == 1, cases) == 1
    @test count(item -> item["contracted_module_count"] == 2, cases) == 20
    @test length(unique(String(item["id"]) for item in sources)) == 10
    @test all(item -> !isempty(String(item["title"])) &&
        !isempty(String(item["url"])) &&
        !isempty(String(item["claim_boundary"])), sources)
    aggregate = artifact["aggregate"]
    @test aggregate["contract_group_count"] == 8
    @test aggregate["contract_module_count"] == 18
    @test aggregate["family_count"] == 10
    @test aggregate["unique_fixed_background_ablation_case_count"] == 21
    @test aggregate["source_record_count"] == 10
    @test aggregate["target_named_margin_count"] == 19
    @test aggregate["target_evidence_requirement_count"] == 17
    @test aggregate["modules_with_source_trace_count"] == 18
    @test aggregate["modules_with_fixed_background_case_count"] == 18
    @test aggregate["hard_unknown_module_count"] == 18
    @test aggregate["formula_implementation_authorized_count"] == 0
    @test aggregate["direct_gate_credit_authorized_count"] == 0
    @test aggregate["old_domain_scale_up_authorized"] === false
    @test aggregate["single_module_physical_causality_claimed"] === false
    @test aggregate["promotion_count"] == 0
    @test aggregate["medium_fidelity_authorized_count"] == 0
    contract_spec = joinpath(PROJECT_ROOT, "knowledge",
        "disconnected_module_influence_contract_v37.json")
    source_catalogs = [joinpath(PROJECT_ROOT, "knowledge", name) for name in (
        "sources.json", "magnetized_target_v6_sources.json",
        "mechanism_expansion_v10_sources.json", "self_organized_v7_sources.json")]
    @test artifact["input_binding"]["contract_spec_sha256"] ==
        bytes2hex(sha256(read(contract_spec)))
    for path in source_catalogs
        relative = replace(relpath(path, PROJECT_ROOT), '\\' => '/')
        @test artifact["input_binding"]["source_catalog_hashes"][relative] ==
            bytes2hex(sha256(read(path)))
    end
    source_paths = Dict(
        "v37_source" => joinpath(PROJECT_ROOT, "src", "search",
            "disconnected_module_influence_contract_v37.jl"),
        "v36_source" => joinpath(PROJECT_ROOT, "src", "search",
            "full_margin_evidence_response_audit_v36.jl"),
        "v35_source" => joinpath(PROJECT_ROOT, "src", "search",
            "topology_module_influence_audit_v35.jl"),
        "v17_source" => joinpath(PROJECT_ROOT, "src", "search",
            "attribute_graph_grammar_v17.jl"),
        "contract_spec" => contract_spec,
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "disconnected_module_influence_contract_v37.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_disconnected_module_influence_contract_v37.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(DISCONNECTED_CONTRACT_V37_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("Contract groups / modules / families: 8/18/10", summary)
    @test occursin("Unique fixed-background ablation cases: 21", summary)
    @test occursin(
        "Source records / named-margin targets / evidence targets: 10/19/17",
        summary)
    @test occursin(
        "Source-traced / fixed-background / hard-unknown modules: 18/18/18",
        summary)
    @test occursin("Formula / direct-gate implementations authorized: 0/0",
        summary)
    @test occursin("Old-domain scale-up authorized: `false`", summary)
    @test occursin("Promotions / medium-fidelity authorizations: 0/0", summary)
end

@testset "Tier-1 module hard-unknown evidence ablation v38" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(TIER1_EVIDENCE_ABLATION_V38_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "1f79ce865486863b4325be09301e604c9bf09fc22f2eba2e96f350189751b6bd"
    scope = artifact["ablation_scope"]
    @test scope["tier1_group_count"] == 3
    @test scope["tier1_module_count"] == 7
    @test scope["fixed_background_case_count"] == 8
    @test scope["graph_response_count"] == 13
    @test scope["module_specific_hard_unknown_requirement_count"] == 14
    @test scope["source_record_count"] == 11
    @test scope["numeric_named_margin_changes_authorized"] === false
    @test scope["raw_gate_changes_authorized"] === false
    @test scope["solver_execution_authorized"] === false
    @test scope["formula_implementation_authorized"] === false
    modules = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(TIER1_MODULE_ROUTES_V38_PATH)]
    cases = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(TIER1_ABLATION_CASES_V38_PATH)]
    graphs = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(TIER1_GRAPH_RESPONSES_V38_PATH)]
    sources = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(TIER1_SOURCES_V38_PATH)]
    @test length(modules) == 7
    @test length(cases) == 8
    @test length(graphs) == 13
    @test length(sources) == 11
    @test bytes2hex(sha256(read(TIER1_MODULE_ROUTES_V38_PATH))) ==
        "7019762950332fe58a4df7c43373244623f14e9ad8166660f8b3581435dece2d"
    @test bytes2hex(sha256(read(TIER1_ABLATION_CASES_V38_PATH))) ==
        "dd4dda24726ac7d75821232e1b1bfafb5a506c324216b42e7b91bccc1f5e7411"
    @test bytes2hex(sha256(read(TIER1_GRAPH_RESPONSES_V38_PATH))) ==
        "f4304bb79c18a2cea61f79de6a52f7655f81e7e63497da3ce36a2689bec5c6c1"
    @test bytes2hex(sha256(read(TIER1_SOURCES_V38_PATH))) ==
        "d637d4e304d868fb990476c1ae4bc398903d527046a7aa07872e955ba41d7f1f"
    @test length(unique(String(item["module_id"]) for item in modules)) == 7
    @test length(unique(String(item["group_id"]) for item in modules)) == 3
    @test all(item -> item["matched_case_count"] > 0 &&
        item["accepted_matched_case_count"] == item["matched_case_count"] &&
        !isempty(item["module_specific_hard_unknown_requirements"]) &&
        !isempty(item["source_ids"]) &&
        item["hard_unknown_evidence_route_implemented"] === true &&
        item["numeric_formula_implemented"] === false &&
        item["direct_gate_credit_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["single_module_physical_causality_proven"] === false &&
        item["promotion_credit"] == 0, modules)
    @test length(unique(String(item["v35_pair_hash"]) for item in cases)) == 8
    @test all(item -> item["first_module_id"] != item["second_module_id"] &&
        item["module_specific_evidence_differentiated"] === true &&
        item["effective_evidence_ledger_differentiated"] === true &&
        item["numeric_named_margins_unchanged"] === true &&
        item["raw_gates_unchanged"] === true &&
        item["hard_unknowns_present_on_both_sides"] === true &&
        item["fixed_background_ablation_accepted"] === true &&
        item["single_module_physical_causality_proven"] === false &&
        item["formula_implemented"] === false &&
        item["direct_gate_credit_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["promoted"] === false, cases)
    @test length(unique(String(item["graph_hash"]) for item in graphs)) == 13
    @test length(unique(String(item["tier1_module_id"]) for item in graphs)) == 7
    @test all(item -> item[
            "module_specific_hard_unknown_requirement_count"] > 0 &&
        item["effective_missing_proxy_requirement_count"] >
            item["base_missing_proxy_requirement_count"] &&
        item["numeric_named_margins_changed"] === false &&
        item["raw_gates_changed"] === false &&
        item["hard_unknown_evidence_route_implemented"] === true &&
        item["solver_executed"] === false &&
        item["formula_implemented"] === false &&
        item["direct_gate_credit_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["promoted"] === false, graphs)
    signed_zero_mismatches = [item for item in graphs if
        item["archived_named_margin_signature_recomputed_match"] === false]
    @test length(signed_zero_mismatches) == 8
    @test all(item -> item["family"] in
        ("levitated_dipole", "sheared_flow_z_pinch"),
        signed_zero_mismatches)
    @test length(unique(String(item["id"]) for item in sources)) == 11
    @test all(item -> !isempty(String(item["title"])) &&
        !isempty(String(item["url"])) &&
        !isempty(String(item["claim_boundary"])), sources)
    aggregate = artifact["aggregate"]
    @test aggregate["tier1_group_count"] == 3
    @test aggregate["tier1_module_count"] == 7
    @test aggregate["tier1_fixed_background_case_count"] == 8
    @test aggregate["tier1_graph_response_count"] == 13
    @test aggregate["module_specific_hard_unknown_requirement_count"] == 14
    @test aggregate["source_record_count"] == 11
    @test aggregate["evidence_differentiated_case_count"] == 8
    @test aggregate["fixed_background_ablation_accepted_case_count"] == 8
    @test aggregate["evidence_route_connected_module_count"] == 7
    @test aggregate["remaining_v37_matched_full_disconnect_module_count"] == 11
    @test aggregate["numeric_named_margin_update_count"] == 0
    @test aggregate["raw_gate_update_count"] == 0
    @test aggregate["solver_execution_count"] == 0
    @test aggregate["formula_implementation_count"] == 0
    @test aggregate["direct_gate_credit_authorized_count"] == 0
    @test aggregate["old_domain_scale_up_authorized"] === false
    @test aggregate["single_module_physical_causality_claimed"] === false
    @test aggregate["promotion_count"] == 0
    @test aggregate["medium_fidelity_authorized_count"] == 0
    overlay = joinpath(PROJECT_ROOT, "knowledge",
        "tier1_module_evidence_overlay_v38.json")
    source_catalogs = [joinpath(PROJECT_ROOT, "knowledge", name) for name in (
        "magnetized_target_v6_sources.json", "self_organized_v7_sources.json",
        "zpinch_candidate_specific_coverage_v26_sources.json")]
    @test artifact["input_binding"]["overlay_sha256"] ==
        bytes2hex(sha256(read(overlay)))
    for path in source_catalogs
        relative = replace(relpath(path, PROJECT_ROOT), '\\' => '/')
        @test artifact["input_binding"]["source_catalog_hashes"][relative] ==
            bytes2hex(sha256(read(path)))
    end
    source_paths = Dict(
        "v38_source" => joinpath(PROJECT_ROOT, "src", "search",
            "tier1_module_evidence_ablation_v38.jl"),
        "v37_source" => joinpath(PROJECT_ROOT, "src", "search",
            "disconnected_module_influence_contract_v37.jl"),
        "v36_source" => joinpath(PROJECT_ROOT, "src", "search",
            "full_margin_evidence_response_audit_v36.jl"),
        "overlay" => overlay,
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "tier1_module_evidence_ablation_v38.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_tier1_module_evidence_ablation_v38.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(TIER1_EVIDENCE_ABLATION_V38_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin(
        "Tier-1 groups / modules / fixed-background cases / graph responses: 3/7/8/13",
        summary)
    @test occursin(
        "Module-specific hard-unknown requirements / source records: 14/11",
        summary)
    @test occursin("Evidence-differentiated / accepted cases: 8/8", summary)
    @test occursin(
        "Evidence-route-connected / remaining v37 full-disconnect modules: 7/11",
        summary)
    @test occursin("Numeric margin / raw-gate updates: 0/0", summary)
    @test occursin("Solver / formula executions: 0/0", summary)
    @test occursin("Old-domain scale-up authorized: `false`", summary)
    @test occursin("Promotions / medium-fidelity authorizations: 0/0", summary)
end

@testset "Remaining-module hard-unknown evidence ablation v39" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(REMAINING_EVIDENCE_ABLATION_V39_PATH, String),
        Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "563162db984b0dc85033992e408840df1d50649c8941b3af53246396bac4ff83"
    scope = artifact["ablation_scope"]
    @test scope["remaining_group_count"] == 5
    @test scope["remaining_module_count"] == 11
    @test scope["fixed_background_case_count"] == 13
    @test scope["graph_response_count"] == 21
    @test scope["module_specific_hard_unknown_requirement_count"] == 40
    @test scope["source_record_count"] == 10
    @test scope["numeric_named_margin_changes_authorized"] === false
    @test scope["raw_gate_changes_authorized"] === false
    @test scope["solver_execution_authorized"] === false
    @test scope["formula_implementation_authorized"] === false
    modules = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(REMAINING_MODULE_ROUTES_V39_PATH)]
    cases = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(REMAINING_ABLATION_CASES_V39_PATH)]
    graphs = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(REMAINING_GRAPH_RESPONSES_V39_PATH)]
    sources = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(REMAINING_SOURCES_V39_PATH)]
    @test length(modules) == 11
    @test length(cases) == 13
    @test length(graphs) == 21
    @test length(sources) == 10
    @test bytes2hex(sha256(read(REMAINING_MODULE_ROUTES_V39_PATH))) ==
        "5b92471b22df54f753e5783e9fbb447d7f4d80dc4c415010e5572857881bb026"
    @test bytes2hex(sha256(read(REMAINING_ABLATION_CASES_V39_PATH))) ==
        "343c4d5e261123fa706c6b00a917b4d9258cdc677281bf54f38663a4a99ea7d5"
    @test bytes2hex(sha256(read(REMAINING_GRAPH_RESPONSES_V39_PATH))) ==
        "5954fd20434cf48acbb78d7ac353dc43b3cdad6a5bac45ca1e7833a845d9440f"
    @test bytes2hex(sha256(read(REMAINING_SOURCES_V39_PATH))) ==
        "f1c6ceec21abdc4b6c75e9aa9d51f59878de5df62771ab156a45b3869dcaa1b9"
    @test length(unique(String(item["module_id"]) for item in modules)) == 11
    @test length(unique(String(item["group_id"]) for item in modules)) == 5
    @test count(item -> item["priority_tier"] ==
        "tier_2_power_and_exhaust_closure", modules) == 7
    @test count(item -> item["priority_tier"] ==
        "tier_3_engineering_closure", modules) == 4
    @test all(item -> item["matched_case_count"] > 0 &&
        item["accepted_matched_case_count"] == item["matched_case_count"] &&
        !isempty(item["module_specific_hard_unknown_requirements"]) &&
        !isempty(item["source_ids"]) &&
        item["hard_unknown_evidence_route_implemented"] === true &&
        item["numeric_formula_implemented"] === false &&
        item["direct_gate_credit_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["single_module_physical_causality_proven"] === false &&
        item["promotion_credit"] == 0, modules)
    @test length(unique(String(item["v35_pair_hash"]) for item in cases)) == 13
    @test all(item -> item["module_specific_evidence_differentiated"] === true &&
        item["effective_evidence_ledger_differentiated"] === true &&
        item["numeric_named_margins_unchanged"] === true &&
        item["raw_gates_unchanged"] === true &&
        item["routed_hard_unknown_present"] === true &&
        item["base_hard_unknowns_present_on_both_sides"] === true &&
        item["fixed_background_ablation_accepted"] === true &&
        item["single_module_physical_causality_proven"] === false &&
        item["formula_implemented"] === false &&
        item["direct_gate_credit_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["promoted"] === false, cases)
    graph_by_hash = Dict(String(item["graph_hash"]) => item for item in graphs)
    @test length(graph_by_hash) == 21
    for item in cases
        first = Set(String.(graph_by_hash[String(item["first_graph_hash"])][
            "routed_module_ids"]))
        second = Set(String.(graph_by_hash[String(item["second_graph_hash"])][
            "routed_module_ids"]))
        difference = union(setdiff(first, second), setdiff(second, first))
        @test difference == Set(String.(item["contracted_module_ids"]))
        @test sort!(collect(first)) == item["first_routed_module_ids"]
        @test sort!(collect(second)) == item["second_routed_module_ids"]
    end
    @test count(item -> item["routed_module_count"] == 1, graphs) == 15
    @test count(item -> item["routed_module_count"] == 2, graphs) == 6
    @test all(item -> item["routed_module_count"] > 0 &&
        item["module_specific_hard_unknown_requirement_count"] > 0 &&
        item["effective_missing_proxy_requirement_count"] >
            item["base_missing_proxy_requirement_count"] &&
        item["numeric_named_margins_changed"] === false &&
        item["raw_gates_changed"] === false &&
        item["hard_unknown_evidence_route_implemented"] === true &&
        item["solver_executed"] === false &&
        item["formula_implemented"] === false &&
        item["direct_gate_credit_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["promoted"] === false, graphs)
    signed_zero_mismatches = [item for item in graphs if
        item["archived_named_margin_signature_recomputed_match"] === false]
    @test length(signed_zero_mismatches) == 14
    @test Set(String(item["family"]) for item in signed_zero_mismatches) ==
        Set(["field_reversed_configuration", "levitated_dipole",
            "reversed_field_pinch", "sheared_flow_z_pinch", "spheromak"])
    @test length(unique(String(item["id"]) for item in sources)) == 10
    @test all(item -> !isempty(String(item["title"])) &&
        !isempty(String(item["url"])) &&
        !isempty(String(item["claim_boundary"])), sources)
    overlay_path = joinpath(PROJECT_ROOT, "knowledge",
        "remaining_module_evidence_overlay_v39.json")
    catalog_path = joinpath(PROJECT_ROOT, "knowledge",
        "remaining_module_evidence_v39_sources.json")
    overlay = FusionConceptAI._plain_json(JSON3.read(read(overlay_path, String),
        Dict{String,Any}))
    new_catalog = FusionConceptAI._plain_json(JSON3.read(read(catalog_path, String),
        Dict{String,Any}))
    @test length(new_catalog["sources"]) == 6
    @test all(item -> haskey(item, "doi") && !isempty(String(item["doi"])) &&
        !isempty(String(item["claim_boundary"])), new_catalog["sources"])
    compact = only(item for item in overlay["modules"] if
        item["module_id"] == "compact_liquid_limiter")
    @test "rfxmod_liquid_lithium_limiter_alfier_2011" in compact["source_ids"]
    @test !("frc_steinhauer_review_2011" in compact["source_ids"])
    aggregate = artifact["aggregate"]
    @test aggregate["remaining_group_count"] == 5
    @test aggregate["remaining_module_count"] == 11
    @test aggregate["remaining_fixed_background_case_count"] == 13
    @test aggregate["remaining_graph_response_count"] == 21
    @test aggregate["module_specific_hard_unknown_requirement_count"] == 40
    @test aggregate["source_record_count"] == 10
    @test aggregate["evidence_differentiated_case_count"] == 13
    @test aggregate["fixed_background_ablation_accepted_case_count"] == 13
    @test aggregate["evidence_route_connected_module_count"] == 11
    @test aggregate["cumulative_v38_v39_connected_module_count"] == 18
    @test aggregate["remaining_v37_matched_full_disconnect_module_count"] == 0
    @test aggregate["numeric_named_margin_update_count"] == 0
    @test aggregate["raw_gate_update_count"] == 0
    @test aggregate["solver_execution_count"] == 0
    @test aggregate["formula_implementation_count"] == 0
    @test aggregate["direct_gate_credit_authorized_count"] == 0
    @test aggregate["old_domain_scale_up_authorized"] === false
    @test aggregate["single_module_physical_causality_claimed"] === false
    @test aggregate["promotion_count"] == 0
    @test aggregate["medium_fidelity_authorized_count"] == 0
    source_catalogs = [joinpath(PROJECT_ROOT, "knowledge", name) for name in (
        "sources.json", "self_organized_v7_sources.json",
        "remaining_module_evidence_v39_sources.json")]
    @test artifact["input_binding"]["overlay_sha256"] ==
        bytes2hex(sha256(read(overlay_path)))
    for path in source_catalogs
        relative = replace(relpath(path, PROJECT_ROOT), '\\' => '/')
        @test artifact["input_binding"]["source_catalog_hashes"][relative] ==
            bytes2hex(sha256(read(path)))
    end
    source_paths = Dict(
        "v39_source" => joinpath(PROJECT_ROOT, "src", "search",
            "remaining_module_evidence_ablation_v39.jl"),
        "v38_source" => joinpath(PROJECT_ROOT, "src", "search",
            "tier1_module_evidence_ablation_v38.jl"),
        "v37_source" => joinpath(PROJECT_ROOT, "src", "search",
            "disconnected_module_influence_contract_v37.jl"),
        "v36_source" => joinpath(PROJECT_ROOT, "src", "search",
            "full_margin_evidence_response_audit_v36.jl"),
        "overlay" => overlay_path,
        "v39_source_catalog" => catalog_path,
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "remaining_module_evidence_ablation_v39.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_remaining_module_evidence_ablation_v39.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(REMAINING_EVIDENCE_ABLATION_V39_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin(
        "Remaining groups / modules / fixed-background cases / graph responses: 5/11/13/21",
        summary)
    @test occursin(
        "Module-specific hard-unknown requirements / source records: 40/10",
        summary)
    @test occursin("Evidence-differentiated / accepted cases: 13/13", summary)
    @test occursin(
        "V39 connected / cumulative v38+v39 connected / remaining v37 full-disconnect modules: 11/18/0",
        summary)
    @test occursin("Numeric margin / raw-gate updates: 0/0", summary)
    @test occursin("Solver / formula executions: 0/0", summary)
    @test occursin("Old-domain scale-up authorized: `false`", summary)
    @test occursin("Promotions / medium-fidelity authorizations: 0/0", summary)
end

@testset "Multilayer fixed-background counterfactual ablation v40" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(MULTILAYER_ABLATION_V40_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "399c80500bed099b7f770431f4468600d80f6f658bfb47f757aff2af0762c996"
    @test artifact["schema_version"] == "1.0.0"
    @test artifact["search_version"] ==
        "multilayer_fixed_background_ablation_v40"
    @test artifact["stage"] ==
        "sealed_multilayer_same_sample_fixed_background_ablation"

    scope = artifact["ablation_scope"]
    @test scope["target_module_count"] == 50
    @test scope["family_layer_group_count"] == 20
    @test scope["within_group_module_choice_pair_count"] == 41
    @test scope["frontier_backgrounds_per_family"] == 5
    @test scope["planned_fixed_background_trial_count"] == 205
    @test scope["all_other_layers_fixed"] === true
    @test scope["paired_halton_sample_fixed"] === true
    @test scope["existing_fidelity0_kernel_executed"] === true
    @test scope["new_numerical_formula_implemented"] === false
    @test scope["single_module_absolute_physical_causality_authorized"] === false

    groups = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(MULTILAYER_GROUPS_V40_PATH)]
    modules = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(MULTILAYER_MODULES_V40_PATH)]
    trials = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(MULTILAYER_TRIALS_V40_PATH)]
    rejections = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(MULTILAYER_REJECTIONS_V40_PATH)]
    responses = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(MULTILAYER_RESPONSES_V40_PATH)]
    @test length(groups) == 20
    @test length(modules) == 50
    @test length(trials) == 64
    @test length(rejections) == 141
    @test length(responses) == 150
    @test bytes2hex(sha256(read(MULTILAYER_GROUPS_V40_PATH))) ==
        "a74784053c40817acdb4c17c56c05afb4a0537729d0db22ad48e855b5878e761"
    @test bytes2hex(sha256(read(MULTILAYER_MODULES_V40_PATH))) ==
        "abece223c8e9b9f806822b95286b1e43b936a3e285e1f95a9043ab30f5928ecc"
    @test bytes2hex(sha256(read(MULTILAYER_TRIALS_V40_PATH))) ==
        "30d2ba4dde6932b863028e3f44c925f2716ba87119e8ba2fe2026e90dd9a5e84"
    @test bytes2hex(sha256(read(MULTILAYER_REJECTIONS_V40_PATH))) ==
        "5b6538e6561e351edebc1a1da3da3c00fd55fc4e3ca757535c911c5aa40af080"
    @test bytes2hex(sha256(read(MULTILAYER_RESPONSES_V40_PATH))) ==
        "29b2c0f7c8efb4f8d1a4caaefcdde4449532f797aee749d5b4d55d4ccf2e4c28"

    @test length(unique((item["family"], item["layer"]) for item in groups)) == 20
    @test sum(item["module_count"] for item in groups) == 50
    @test sum(item["module_choice_pair_count"] for item in groups) == 41
    @test sum(item["planned_trial_count"] for item in groups) == 205
    @test sum(item["accepted_trial_count"] for item in groups) == 64
    @test sum(item["structurally_rejected_trial_count"] for item in groups) == 141
    @test all(item -> item["module_choice_pair_count"] ==
        item["module_count"] * (item["module_count"] - 1) ÷ 2, groups)
    @test all(item -> item["planned_trial_count"] ==
        5 * item["module_choice_pair_count"], groups)
    @test all(item -> item["planned_trial_count"] ==
        item["accepted_trial_count"] + item["structurally_rejected_trial_count"],
        groups)

    class_counts = Dict(String(name) => count(item ->
        item["controlled_route_classification"] == name, modules) for name in (
        "controlled_evaluated_response_route_observed",
        "controlled_evidence_route_observed",
        "controlled_full_response_and_evidence_alias",
        "structurally_non_intervenable_in_frontier_backgrounds"))
    @test class_counts == Dict(
        "controlled_evaluated_response_route_observed" => 3,
        "controlled_evidence_route_observed" => 3,
        "controlled_full_response_and_evidence_alias" => 21,
        "structurally_non_intervenable_in_frontier_backgrounds" => 23)
    response_route_modules = sort([String(item["module_id"]) for item in modules if
        item["controlled_route_classification"] ==
            "controlled_evaluated_response_route_observed"])
    evidence_route_modules = sort([String(item["module_id"]) for item in modules if
        item["controlled_route_classification"] ==
            "controlled_evidence_route_observed"])
    @test response_route_modules ==
        ["icf_direct_drive", "icf_fast_ignition", "icf_indirect_drive"]
    @test evidence_route_modules == ["stellarator_boundary_control",
        "stellarator_qa_drift", "stellarator_qh_drift"]
    @test length(unique(String(item["module_id"]) for item in modules)) == 50
    @test all(item -> item["gate_credit_authorized"] === false &&
        item["medium_fidelity_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["promotion_credit"] == 0 &&
        item["single_module_absolute_physical_causality_proven"] === false,
        modules)

    @test length(unique(String(item["trial_hash"]) for item in trials)) == 64
    @test all(item -> item["all_other_layers_fixed"] === true &&
        item["paired_halton_sample_fixed"] === true &&
        item["first_module_id"] != item["second_module_id"], trials)
    @test count(item -> item["response_classification"] ==
        "evaluated_response_variation_only", trials) == 12
    @test count(item -> item["response_classification"] ==
        "evidence_variation_only", trials) == 2
    @test count(item -> item["response_classification"] ==
        "full_evaluated_and_evidence_alias", trials) == 50
    @test count(item -> item["single_layer_module_choice_effect_identified"] ===
        true, trials) == 14
    @test count(item -> item["raw_gate_dictionary_identical"] === false,
        trials) == 0
    @test Set(String(id) for item in trials for id in
        item["changed_named_margin_ids"]) == Set([
            "dual_pulse_fast_ignition_consistency",
            "path_coupling_hypothesis_domain"])
    @test Set(String(id) for item in trials for id in
        item["changed_evidence_requirement_ids"]) == Set([
            "alpha_orbits", "ideal_mhd", "island_spectrum_control",
            "neoclassical_transport"])
    @test all(item -> item["changed_raw_gate_count"] == 0 &&
        item["gate_credit_authorized"] === false &&
        item["medium_fidelity_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["promoted"] === false &&
        item["single_module_absolute_physical_causality_proven"] === false,
        trials)

    @test length(unique(String(item["rejection_hash"]) for item in rejections)) == 141
    @test all(item -> item["structural_counterfactual_accepted"] === false &&
        item["physical_infeasibility_proven"] === false &&
        (!isempty(item["first_reason_codes"]) ||
            !isempty(item["second_reason_codes"])), rejections)
    @test all(item -> all(code -> startswith(String(code),
        "missing_required_tag:"), vcat(item["first_reason_codes"],
        item["second_reason_codes"])), rejections)

    @test length(unique(String(item["response_key"]) for item in responses)) == 150
    @test length(unique(String(item["intervened_module_id"]) for item in responses)) == 50
    @test length(unique(String(item["family"]) for item in responses)) == 9
    @test all(item -> item["counterfactual_fixed_background_evaluation"] === true &&
        item["claim_level"] == "C0_controlled_fidelity0_module_choice_response" &&
        item["proxy_applicable"] === true &&
        isempty(item["topology_graph_errors"]) &&
        item["proxy_five_gate_passed"] === false &&
        item["proxy_coverage_complete"] === false &&
        item["medium_fidelity_candidate_eligible"] === false &&
        item["medium_fidelity_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["promoted"] === false, responses)

    aggregate = artifact["aggregate"]
    @test aggregate["target_module_count"] == 50
    @test aggregate["family_layer_group_count"] == 20
    @test aggregate["within_group_module_choice_pair_count"] == 41
    @test aggregate["planned_fixed_background_trial_count"] == 205
    @test aggregate["accepted_fixed_background_trial_count"] == 64
    @test aggregate["structurally_rejected_trial_count"] == 141
    @test aggregate["valid_counterfactual_intervention_count"] == 150
    @test aggregate["invalid_counterfactual_intervention_count"] == 100
    @test aggregate["unique_counterfactual_response_count"] == 150
    @test aggregate["evaluated_response_variation_trial_count"] == 12
    @test aggregate["evidence_variation_trial_count"] == 2
    @test aggregate["raw_gate_variation_trial_count"] == 0
    @test aggregate["controlled_module_choice_effect_trial_count"] == 14
    @test aggregate["full_response_and_evidence_alias_trial_count"] == 50
    @test aggregate["background_invariant_module_pair_count"] == 22
    @test aggregate["background_evaluated_module_pair_count"] == 22
    @test aggregate["module_route_classification_counts"] == class_counts

    credit = artifact["promotion_credit"]
    @test credit["single_module_absolute_physical_causality_claimed"] === false
    @test credit["gate_credit_authorized_count"] == 0
    @test credit["medium_fidelity_authorized_count"] == 0
    @test credit["old_domain_scale_up_authorized"] === false
    @test credit["promotion_count"] == 0
    @test credit["physics_evidence_level_change"] == 0
    @test credit["engineering_evidence_level_change"] == 0

    input = artifact["input_binding"]
    @test input["halton_skip"] == 4096
    @test input["v36_deterministic_result_hash"] ==
        "c183755775153f6d87ecd264e1a64062ff82506b9b490372c9653d4aa927afe6"
    @test input["v39_deterministic_result_hash"] ==
        "563162db984b0dc85033992e408840df1d50649c8941b3af53246396bac4ff83"
    @test input["v36_artifact_sha256"] == bytes2hex(sha256(read(
        FULL_RESPONSE_AUDIT_V36_PATH)))
    @test input["v36_full_response_records_sha256"] == bytes2hex(sha256(read(
        FULL_RESPONSE_RECORDS_V36_PATH)))
    @test input["v36_module_response_routes_sha256"] == bytes2hex(sha256(read(
        MODULE_RESPONSE_ROUTES_V36_PATH)))
    @test input["v39_artifact_sha256"] == bytes2hex(sha256(read(
        REMAINING_EVIDENCE_ABLATION_V39_PATH)))

    source_paths = Dict(
        "v40_source" => joinpath(PROJECT_ROOT, "src", "search",
            "multilayer_fixed_background_ablation_v40.jl"),
        "v36_source" => joinpath(PROJECT_ROOT, "src", "search",
            "full_margin_evidence_response_audit_v36.jl"),
        "v20_source" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "v17_source" => joinpath(PROJECT_ROOT, "src", "search",
            "attribute_graph_grammar_v17.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "multilayer_fixed_background_ablation_v40.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_multilayer_fixed_background_ablation_v40.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(MULTILAYER_ABLATION_V40_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin(
        "Target modules / family-layer groups / module-choice pairs: 50/20/41",
        summary)
    @test occursin(
        "Planned / accepted / structurally rejected fixed-background trials: 205/64/141",
        summary)
    @test occursin(
        "Evaluated-response / evidence / raw-gate variation trials: 12/2/0",
        summary)
    @test occursin(
        "Controlled module-choice effect / full response+evidence alias trials: 14/50",
        summary)
    @test occursin("Gate credit / medium-fidelity / promotion: 0/0/0", summary)
    @test occursin("Old-domain scale-up authorized: `false`", summary)
end

@testset "Dependency-closed block ablation v41" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(DEPENDENCY_CLOSED_ABLATION_V41_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "7e6c8d35fe7a6cddd5c3aa1d002f9a55b5e4703b299a65aba2ced92e08a85607"
    @test artifact["schema_version"] == "1.0.0"
    @test artifact["search_version"] ==
        "dependency_closed_block_ablation_v41"
    @test artifact["stage"] ==
        "sealed_exhaustive_minimum_dependency_closed_block_ablation"

    scope = artifact["ablation_scope"]
    @test scope["complete_compatible_assembly_count"] == 1129
    @test scope["source_v40_structural_rejection_count"] == 141
    @test scope["target_structurally_coupled_module_count"] == 23
    @test scope["complete_compatible_assembly_search"] === true
    @test scope["minimum_dependency_closed_pair_selection"] === true
    @test scope["paired_halton_sample_fixed"] === true
    @test scope["existing_fidelity0_kernel_executed"] === true
    @test scope["new_numerical_formula_implemented"] === false
    @test scope["single_module_absolute_physical_causality_authorized"] === false
    @test scope["physical_infeasibility_claim_authorized"] === false
    @test scope["pair_objective_order"] == [
        "comparison_changed_layer_count", "support_adjustment_layer_count",
        "total_source_hamming_distance", "maximum_source_hamming_distance"]

    pairs = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(DEPENDENCY_CLOSED_PAIRS_V41_PATH)]
    modules = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(DEPENDENCY_CLOSED_MODULES_V41_PATH)]
    trials = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(DEPENDENCY_CLOSED_TRIALS_V41_PATH)]
    responses = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(DEPENDENCY_CLOSED_RESPONSES_V41_PATH)]
    v40_modules = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(MULTILAYER_MODULES_V40_PATH)]
    v40_rejections = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(MULTILAYER_REJECTIONS_V40_PATH)]
    @test length(pairs) == 35
    @test length(modules) == 23
    @test length(trials) == 141
    @test length(responses) == 201
    @test bytes2hex(sha256(read(DEPENDENCY_CLOSED_PAIRS_V41_PATH))) ==
        "580087f0890a9f6a5a507cb3f19c65a9dee544b06733a818b70600fcc72a9373"
    @test bytes2hex(sha256(read(DEPENDENCY_CLOSED_MODULES_V41_PATH))) ==
        "30031f529a10747fa2d02de5d78795d08655497cbfd2f8f296249f7ca62c6b22"
    @test bytes2hex(sha256(read(DEPENDENCY_CLOSED_TRIALS_V41_PATH))) ==
        "762853c6a2f71aa16636f1b62b1d006fb098dbed6ae444a68ca3d40408fbeeed"
    @test bytes2hex(sha256(read(DEPENDENCY_CLOSED_RESPONSES_V41_PATH))) ==
        "5b046886f4b226b1c6da62a00c25c881d37265eda7b956cee0f3b32afe963c69"

    @test length(unique(String(item["pair_key"]) for item in pairs)) == 35
    @test sum(Int(item["repaired_trial_count"]) for item in pairs) == 141
    @test all(item -> item["background_route_invariant"] === true, pairs)
    @test count(item -> item["coupled_block_comparison_count"] == 0,
        pairs) == 18
    @test count(item -> item["matched_single_layer_comparison_count"] == 0,
        pairs) == 17
    @test all(item -> item["coupled_block_comparison_count"] == 0 ||
        item["matched_single_layer_comparison_count"] == 0, pairs)

    route_counts = Dict(String(name) => count(item ->
        item["dependency_closed_route_classification"] == name, modules)
        for name in ("dependency_closed_block_alias_observed",
            "dependency_closed_coupled_block_route_observed",
            "dependency_closed_matched_route_observed"))
    @test route_counts == Dict(
        "dependency_closed_block_alias_observed" => 12,
        "dependency_closed_coupled_block_route_observed" => 10,
        "dependency_closed_matched_route_observed" => 1)
    @test [String(item["module_id"]) for item in modules if item[
        "dependency_closed_route_classification"] ==
        "dependency_closed_matched_route_observed"] == ["stellarator_qi_drift"]
    v40_structural_ids = Set(String(item["module_id"]) for item in v40_modules
        if item["controlled_route_classification"] ==
            "structurally_non_intervenable_in_frontier_backgrounds")
    @test Set(String(item["module_id"]) for item in modules) ==
        v40_structural_ids
    @test all(item -> item["v40_controlled_route_classification"] ==
        "structurally_non_intervenable_in_frontier_backgrounds" &&
        item["single_module_absolute_physical_causality_proven"] === false &&
        item["physical_infeasibility_proven"] === false &&
        item["gate_credit_authorized"] === false &&
        item["medium_fidelity_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["promotion_credit"] == 0, modules)

    @test length(unique(String(item["trial_hash"]) for item in trials)) == 141
    @test Set(String(item["source_v40_rejection_hash"]) for item in trials) ==
        Set(String(item["rejection_hash"]) for item in v40_rejections)
    @test count(item -> item["comparison_changed_layer_count"] == 1,
        trials) == 56
    @test count(item -> item["comparison_changed_layer_count"] == 2,
        trials) == 85
    @test count(item -> item["support_adjustment_layer_count"] == 1,
        trials) == 126
    @test count(item -> item["support_adjustment_layer_count"] == 2,
        trials) == 15
    @test all(item -> item["minimum_dependency_closed_pair_selected"] === true &&
        item["complete_compatible_assembly_search"] === true &&
        item["paired_halton_sample_fixed"] === true &&
        length(item["comparison_changed_layer_ids"]) ==
            item["comparison_changed_layer_count"] &&
        length(item["first_source_changed_layer_ids"]) ==
            item["first_source_hamming_distance"] &&
        length(item["second_source_changed_layer_ids"]) ==
            item["second_source_hamming_distance"] &&
        length(item["support_adjustment_layer_ids"]) ==
            item["support_adjustment_layer_count"] &&
        item["intervened_layer"] in item["comparison_changed_layer_ids"] &&
        item["minimum_objective"][1] ==
            item["comparison_changed_layer_count"] &&
        item["minimum_objective"][2] ==
            item["support_adjustment_layer_count"] &&
        item["exhaustive_valid_pair_count"] >= 1 &&
        item["minimum_objective_tie_count"] >= 1, trials)
    @test all(item -> item["single_module_absolute_physical_causality_proven"] ===
        false && item["physical_infeasibility_proven"] === false &&
        item["gate_credit_authorized"] === false &&
        item["medium_fidelity_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["promoted"] === false, trials)
    @test count(item -> item["response_classification"] ==
        "evaluated_response_variation_only", trials) == 8
    @test count(item -> item["response_classification"] ==
        "evidence_variation_only", trials) == 33
    @test count(item -> item["response_classification"] ==
        "full_evaluated_and_evidence_alias", trials) == 100
    @test count(item -> item["dependency_closed_route_effect_identified"] ===
        true, trials) == 41
    @test all(item -> item["raw_gate_dictionary_identical"] === true &&
        isempty(item["changed_raw_gate_ids"]), trials)
    @test Set(String(id) for item in trials for id in
        item["changed_named_margin_ids"]) == Set([
            "auxiliary_power", "dual_pulse_fast_ignition_consistency",
            "engineering_current_density", "fusion_gain",
            "net_electric_power", "particle_loss",
            "path_coupling_hypothesis_domain", "peak_conductor_field",
            "support_stress"])
    @test Set(String(id) for item in trials for id in
        item["changed_evidence_requirement_ids"]) == Set([
            "alpha_orbits", "chamber_recovery", "driver_interface",
            "fatigue_lifetime", "ideal_mhd", "internal_coil_lifetime",
            "internal_coil_replacement", "island_spectrum_control",
            "levitation_control", "liquid_wall_recovery",
            "neoclassical_transport", "support_heat_leak"])

    @test length(unique(String(item["response_key"]) for item in responses)) == 201
    @test length(unique(String(item["intervened_module_id"])
        for item in responses)) == 43
    @test length(unique(String(item["family"]) for item in responses)) == 7
    @test all(item -> item["dependency_closed_block_evaluation"] === true &&
        item["counterfactual_fixed_background_evaluation"] === true &&
        item["claim_level"] ==
            "C0_dependency_closed_fidelity0_block_response" &&
        item["proxy_applicable"] === true &&
        isempty(item["topology_graph_errors"]) &&
        item["proxy_five_gate_passed"] === false &&
        item["proxy_coverage_complete"] === false &&
        item["medium_fidelity_candidate_eligible"] === false &&
        item["medium_fidelity_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["promoted"] === false, responses)

    aggregate = artifact["aggregate"]
    @test aggregate["complete_compatible_assembly_count"] == 1129
    @test aggregate["source_v40_structural_rejection_count"] == 141
    @test aggregate["target_structurally_coupled_module_count"] == 23
    @test aggregate["unique_module_pair_count"] == 35
    @test aggregate["accepted_dependency_closed_trial_count"] == 141
    @test aggregate["unresolved_dependency_closed_trial_count"] == 0
    @test aggregate["unique_dependency_closed_response_count"] == 201
    @test aggregate["matched_single_layer_comparison_count"] == 56
    @test aggregate["coupled_block_comparison_count"] == 85
    @test aggregate["comparison_changed_layer_count_histogram"] ==
        Dict("1" => 56, "2" => 85)
    @test aggregate["support_adjustment_layer_count_histogram"] ==
        Dict("1" => 126, "2" => 15)
    @test aggregate["maximum_comparison_changed_layer_count"] == 2
    @test aggregate["evaluated_response_variation_trial_count"] == 8
    @test aggregate["evidence_variation_trial_count"] == 33
    @test aggregate["raw_gate_variation_trial_count"] == 0
    @test aggregate["full_response_and_evidence_alias_trial_count"] == 100
    @test aggregate["dependency_closed_route_effect_trial_count"] == 41
    @test aggregate["target_module_route_classification_counts"] ==
        route_counts
    @test aggregate["proxy_five_gate_passed_response_count"] == 0
    @test aggregate["proxy_coverage_complete_response_count"] == 0
    @test aggregate["medium_fidelity_candidate_eligible_response_count"] == 0
    @test aggregate["new_numerical_formula_implemented"] === false
    @test aggregate["single_module_absolute_physical_causality_claimed"] === false
    @test aggregate["physical_infeasibility_claimed"] === false
    @test aggregate["gate_credit_authorized_count"] == 0
    @test aggregate["medium_fidelity_authorized_count"] == 0
    @test aggregate["old_domain_scale_up_authorized"] === false
    @test aggregate["promotion_count"] == 0

    credit = artifact["promotion_credit"]
    @test credit["single_module_absolute_physical_causality_claimed"] === false
    @test credit["physical_infeasibility_claimed"] === false
    @test credit["gate_credit_authorized_count"] == 0
    @test credit["medium_fidelity_authorized_count"] == 0
    @test credit["old_domain_scale_up_authorized"] === false
    @test credit["promotion_count"] == 0
    @test credit["physics_evidence_level_change"] == 0
    @test credit["engineering_evidence_level_change"] == 0

    input = artifact["input_binding"]
    @test input["halton_skip"] == 4096
    @test input["v36_deterministic_result_hash"] ==
        "c183755775153f6d87ecd264e1a64062ff82506b9b490372c9653d4aa927afe6"
    @test input["v40_deterministic_result_hash"] ==
        "399c80500bed099b7f770431f4468600d80f6f658bfb47f757aff2af0762c996"
    @test input["v36_artifact_sha256"] == bytes2hex(sha256(read(
        FULL_RESPONSE_AUDIT_V36_PATH)))
    @test input["v36_full_response_records_sha256"] == bytes2hex(sha256(read(
        FULL_RESPONSE_RECORDS_V36_PATH)))
    @test input["v40_artifact_sha256"] == bytes2hex(sha256(read(
        MULTILAYER_ABLATION_V40_PATH)))
    @test input["v40_modules_sha256"] == bytes2hex(sha256(read(
        MULTILAYER_MODULES_V40_PATH)))
    @test input["v40_rejections_sha256"] == bytes2hex(sha256(read(
        MULTILAYER_REJECTIONS_V40_PATH)))

    source_paths = Dict(
        "v41_source" => joinpath(PROJECT_ROOT, "src", "search",
            "dependency_closed_block_ablation_v41.jl"),
        "v40_source" => joinpath(PROJECT_ROOT, "src", "search",
            "multilayer_fixed_background_ablation_v40.jl"),
        "v36_source" => joinpath(PROJECT_ROOT, "src", "search",
            "full_margin_evidence_response_audit_v36.jl"),
        "v20_source" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "v17_source" => joinpath(PROJECT_ROOT, "src", "search",
            "attribute_graph_grammar_v17.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "dependency_closed_block_ablation_v41.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_dependency_closed_block_ablation_v41.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(DEPENDENCY_CLOSED_ABLATION_V41_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin(
        "Complete compatible assemblies / v40 structural rejections / target modules: 1129/141/23",
        summary)
    @test occursin(
        "Unique module pairs / accepted / unresolved trials: 35/141/0",
        summary)
    @test occursin(
        "Matched single-layer / coupled-block comparisons: 56/85", summary)
    @test occursin(
        "Evaluated-response / evidence / raw-gate variation trials: 8/33/0",
        summary)
    @test occursin(
        "Route-effect / full response+evidence alias trials: 41/100", summary)
    @test occursin(
        "Five-gate-pass / coverage-complete / medium-eligible responses: 0/0/0",
        summary)
    @test occursin(
        "Gate credit / medium-fidelity authorization / promotion: 0/0/0",
        summary)
    @test occursin("Old-domain scale-up authorized: `false`", summary)
end

@testset "Sealed candidate-specific formula reuse v42" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(FORMULA_REUSE_V42_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "88b90f3e1f46af7280845ce6a83d8aa6e75c804accd10a84b685d2f5c0e609ec"
    @test artifact["schema_version"] == "1.0.0"
    @test artifact["search_version"] ==
        "candidate_specific_formula_reuse_v42"
    @test artifact["stage"] ==
        "sealed_cross_family_candidate_formula_reuse_audit"

    read_jsonl(path) = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(path)]
    modules = read_jsonl(FORMULA_REUSE_MODULES_V42_PATH)
    trials = read_jsonl(FORMULA_REUSE_TRIALS_V42_PATH)
    responses = read_jsonl(FORMULA_REUSE_RESPONSES_V42_PATH)
    @test length(modules) == 50
    @test length(trials) == 15
    @test length(responses) == 23
    @test bytes2hex(sha256(read(FORMULA_REUSE_MODULES_V42_PATH))) ==
        "0bad49732214e27de6f593e0558b3910960b4e60d75bf02bb0c4b8a3b7d6a15d"
    @test bytes2hex(sha256(read(FORMULA_REUSE_TRIALS_V42_PATH))) ==
        "c59800486f375a4a10db76f71b81bbd3855cf41812814f9517e7338642890799"
    @test bytes2hex(sha256(read(FORMULA_REUSE_RESPONSES_V42_PATH))) ==
        "3cd2272f94dc774d440dd6fc3a1d52b292db286f6c3e7061f87ea623aab4487f"

    action_counts = Dict(action => count(item ->
        item["recommended_action"] == action, modules) for action in (
            "reuse_existing_candidate_formula",
            "candidate_specific_solver_required",
            "quantitative_evidence_missing_keep_unknown",
            "existing_observed_route_hold"))
    @test action_counts == Dict(
        "reuse_existing_candidate_formula" => 6,
        "candidate_specific_solver_required" => 18,
        "quantitative_evidence_missing_keep_unknown" => 9,
        "existing_observed_route_hold" => 17)
    @test Set(String(item["module_id"]) for item in modules if item[
        "recommended_action"] == "reuse_existing_candidate_formula") == Set([
            "mirror_direct_converter", "mirror_gas_dynamic_targets",
            "mirror_solenoidal_plugs", "mirror_tandem_plugs",
            "rfp_ppcd", "rfp_saddle_control"])
    @test all(item -> item["new_gate_credit_authorized"] === false &&
        item["medium_fidelity_authorized"] === false &&
        item["promotion_credit"] == 0 &&
        item["quantitative_evidence"][
            "candidate_specific_promotion_record_count"] == 0, modules)

    @test count(item -> item["formula_observable_response_change"] === true,
        trials) == 12
    @test count(item -> item["v42_response_classification"] ==
        "remaining_formula_and_evidence_alias", trials) == 3
    @test count(item -> item["changed_raw_gate_count"] > 0, trials) == 5
    @test all(item -> item[
        "single_module_absolute_physical_causality_proven"] === false &&
        item["gate_credit_authorized"] === false &&
        item["medium_fidelity_authorized"] === false &&
        item["old_domain_scale_up_authorized"] === false &&
        item["promoted"] === false, trials)
    @test length(unique(String(item["response_key"])
        for item in responses)) == 23
    @test all(item -> isempty(item["topology_graph_errors"]) &&
        item["proxy_five_gate_passed"] === false &&
        item["proxy_coverage_complete"] === false &&
        item["candidate_specific_formula_inputs_wired"] === true &&
        item["new_empirical_performance_multiplier_used"] === false &&
        item["gate_credit_authorized"] === false &&
        item["medium_fidelity_authorized"] === false &&
        item["promoted"] === false, responses)

    aggregate = artifact["aggregate"]
    @test aggregate["source_alias_module_count"] == 33
    @test aggregate["formula_observable_module_count"] == 6
    @test aggregate["remaining_alias_module_count"] == 27
    @test aggregate["observed_route_module_count_after_v42"] == 23
    @test aggregate["formula_response_variation_trial_count"] == 12
    @test aggregate["remaining_formula_alias_trial_count"] == 3
    @test aggregate["raw_gate_variation_trial_count"] == 5
    @test aggregate["topology_graph_error_response_count"] == 0
    @test aggregate["proxy_five_gate_passed_response_count"] == 0
    @test aggregate["proxy_coverage_complete_response_count"] == 0
    @test aggregate["new_empirical_performance_multiplier_used"] === false
    @test aggregate["new_physics_constant_introduced"] === false
    @test aggregate[
        "existing_candidate_formula_composition_implemented"] === true
    @test aggregate["gate_credit_authorized_count"] == 0
    @test aggregate["medium_fidelity_authorized_count"] == 0
    @test aggregate["old_domain_scale_up_authorized"] === false
    @test aggregate["promotion_count"] == 0

    source_paths = Dict(
        "v42_source" => joinpath(PROJECT_ROOT, "src", "search",
            "candidate_specific_formula_reuse_v42.jl"),
        "v20_source" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "v17_source" => joinpath(PROJECT_ROOT, "src", "search",
            "attribute_graph_grammar_v17.jl"),
        "v11_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "open_loss_pathway_screen_v1.jl"),
        "v10_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mechanism_expansion_screen_v1.jl"),
        "v8_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "profile_coupled_rfp_screen_v1.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "candidate_specific_formula_reuse_v42.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_candidate_specific_formula_reuse_v42.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(FORMULA_REUSE_V42_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin(
        "Formula-reuse targets / formula-observable modules: 6/6", summary)
    @test occursin(
        "Targeted / response-varying / remaining-alias trials: 15/12/3",
        summary)
    @test occursin(
        "Observed-route / remaining-alias modules after v42: 23/27", summary)
    @test occursin(
        "Five-gate-pass / coverage-complete responses: 0/0", summary)
end

@testset "Variable mirror coil-topology rejection search v22" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(VARIABLE_MIRROR_TOPOLOGY_V22_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    for key in ("worker_claimed_shard_ids", "worker_claim_counts",
            "claimed_shard_union_count", "worker_count", "execution_mode",
            "live_claim_overlap_count", "aggregate_cache_hits",
            "aggregate_new_commits", "new_commits", "cache_hits",
            "retry_failures")
        delete!(core["preview_execution"], key)
    end
    for key in ("new_commits", "cache_hits", "retry_failures")
        delete!(core["full_review_execution"], key)
    end
    @test canonical_hash(core) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "bc39f036873bba2518d4998dc1a27c4db54d49a3369b0344a605abae7d4ef700"
    @test artifact["input_binding"]["v20_candidate_count"] == 10_000
    @test artifact["input_binding"][
        "v20_mirror_three_gate_frontier_count"] == 362
    @test artifact["search_contract"]["candidate_count"] == 1_086
    @test artifact["search_contract"]["layout_count"] == 3
    @test artifact["search_contract"]["paired_halton_gene_dimensions"] == 5
    @test artifact["preview_execution"]["result_hash"] ==
        "587caa64293f2029ff0dd5c22504a2e0df9beaf8b1f997d209aa80dd221bea4e"
    @test artifact["preview_execution"]["total_shards"] == 181
    @test artifact["preview_execution"]["live_claim_overlap_count"] == 0
    @test artifact["preview_execution"]["claimed_shard_union_count"] == 181
    @test artifact["preview_execution"]["aggregate_cache_hits"] == 181
    @test artifact["preview_execution"]["aggregate_new_commits"] == 0
    @test sum(values(artifact["preview_execution"][
        "worker_claim_counts"])) == 181
    @test artifact["full_review_execution"]["result_hash"] ==
        "da5fadac2b60d7b430766251409ac76b7a3220991a4ba1e9996295fab8bf0cf6"
    @test artifact["full_review_execution"]["candidate_count"] == 18
    @test artifact["full_review_execution"]["selected_global_indices"] ==
        [246, 279, 21, 135, 360, 140, 627, 520, 695, 436, 676, 469,
            762, 960, 795, 873, 839, 924]
    @test artifact["outcome"]["preview_geometry_rejected_count"] == 1_086
    @test artifact["outcome"]["preview_geometry_survivor_count"] == 0
    @test artifact["outcome"]["qd_archive_cell_count"] == 117
    @test artifact["outcome"]["full_geometry_rejected_count"] == 18
    @test artifact["outcome"]["full_geometry_survivor_count"] == 0
    @test artifact["outcome"]["anisotropic_equilibrium_authorized_count"] == 0
    @test artifact["outcome"]["fokker_planck_end_loss_authorized_count"] == 0
    @test artifact["promotion_credit"]["medium_fidelity_authorized_count"] == 0
    @test length(readlines(VARIABLE_MIRROR_PREVIEWS_V22_PATH)) == 1_086
    @test length(readlines(VARIABLE_MIRROR_QD_V22_PATH)) == 117
    @test length(readlines(VARIABLE_MIRROR_FULL_V22_PATH)) == 18
    @test artifact["archives"]["preview_sha256"] == bytes2hex(sha256(
        read(VARIABLE_MIRROR_PREVIEWS_V22_PATH)))
    @test artifact["archives"]["qd_archive_sha256"] == bytes2hex(sha256(
        read(VARIABLE_MIRROR_QD_V22_PATH)))
    @test artifact["archives"]["full_review_sha256"] == bytes2hex(sha256(
        read(VARIABLE_MIRROR_FULL_V22_PATH)))
    previews = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            VARIABLE_MIRROR_PREVIEWS_V22_PATH)]
    full = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(VARIABLE_MIRROR_FULL_V22_PATH)]
    @test all(record -> record["geometry"]["rejection_credit"] === true &&
        record["geometry"]["promotion_credit"] === false, previews)
    @test all(record -> record["geometry"]["rejection_credit"] === true &&
        record["geometry"]["promotion_credit"] === false, full)
    @test count(record -> record["geometry"]["numerical_failure_count"] > 0,
        previews) == 5
    @test count(record -> record["geometry"]["numerical_failure_count"] > 0,
        full) == 0
    for layout in FusionConceptAI._V22_LAYOUTS
        @test count(record -> record["layout"] == layout, previews) == 362
        @test count(record -> record["layout"] == layout, full) == 6
        @test all(record -> "axis_field_and_mirror_ratio" in
            record["geometry"]["failed_gates"], filter(record ->
                record["layout"] == layout, full))
    end
    source_paths = Dict(
        "v22_source" => joinpath(PROJECT_ROOT, "src", "search",
            "variable_mirror_topology_search_v22.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "variable_mirror_topology_search_v22.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_variable_mirror_topology_search_v22.jl"),
        "worker" => joinpath(PROJECT_ROOT, "scripts",
            "run_variable_mirror_topology_worker_v22.jl"),
        "layout_geometry_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mirror_layout_vacuum_geometry_v1.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(VARIABLE_MIRROR_TOPOLOGY_V22_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Preview geometry rejections/survivors: 1086/0", summary)
    @test occursin("Full geometry rejections/survivors: 18/0", summary)
    @test occursin("Medium-fidelity authorizations: 0", summary)
end

@testset "Z-pinch non-ideal spectrum and electrode admission audit v23" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(ZPINCH_ADMISSION_V23_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    for key in ("new_commits", "cache_hits", "retry_failures")
        delete!(core["execution"], key)
    end
    @test canonical_hash(core) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "ec4236497f51c4a031dd5b45bc0034b9780a16dd7e8b923186f530a42c945224"
    @test artifact["input_binding"]["v20_candidate_count"] == 10_000
    @test artifact["input_binding"][
        "v20_zpinch_three_gate_frontier_count"] == 336
    @test artifact["input_binding"]["evidence_source_count"] == 9
    @test artifact["execution"]["result_hash"] ==
        "1634e31686e079aaa9027e3ca7ebfcce5f6b42b41dd24dfac0985c60700e6ef1"
    @test artifact["execution"]["record_count"] == 336
    @test artifact["execution"]["total_shards"] == 34
    @test artifact["execution"]["cache_hits"] == 34
    @test artifact["execution"]["new_commits"] == 0
    @test artifact["outcome"]["hard_rejected_count"] == 336
    @test artifact["outcome"]["blocking_unknown_only_count"] == 0
    @test artifact["outcome"]["nonrepetitive_count"] == 336
    @test artifact["outcome"][
        "optimistic_full_inventory_one_year_rejected_count"] == 0
    @test artifact["outcome"]["old_m1_reference_passed_count"] == 336
    @test artifact["outcome"]["pic_m0_reference_domain_overlap_count"] == 0
    @test artifact["outcome"][
        "candidate_specific_nonideal_spectrum_available_count"] == 0
    @test artifact["outcome"]["all_mode_stability_authorized_count"] == 0
    @test artifact["outcome"][
        "candidate_specific_electrode_lifetime_authorized_count"] == 0
    @test artifact["outcome"]["admission_authorized_count"] == 0
    @test artifact["outcome"]["medium_fidelity_authorized_count"] == 0
    @test artifact["outcome"]["descriptor_archive_cell_count"] == 24
    @test artifact["outcome"]["field_module_counts"] == Dict(
        "zpinch_coaxial_electrodes" => 168,
        "zpinch_distributed_electrodes" => 168)
    @test artifact["outcome"]["stability_module_counts"] == Dict(
        "zpinch_axial_shear" => 168, "zpinch_flr" => 168)
    @test length(readlines(ZPINCH_ADMISSION_RECORDS_V23_PATH)) == 336
    @test length(readlines(ZPINCH_ADMISSION_ARCHIVE_V23_PATH)) == 24
    @test artifact["archives"]["records_sha256"] == bytes2hex(sha256(
        read(ZPINCH_ADMISSION_RECORDS_V23_PATH)))
    @test artifact["archives"]["archive_sha256"] == bytes2hex(sha256(
        read(ZPINCH_ADMISSION_ARCHIVE_V23_PATH)))
    records = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            ZPINCH_ADMISSION_RECORDS_V23_PATH)]
    @test all(record -> record["hard_rejection_count"] == 1 &&
        record["hard_rejection_reasons"] ==
            ["no_repetitive_plant_operation"], records)
    @test all(record -> record["electrode_lifetime_audit"][
        "optimistic_full_inventory_one_year_gate"] === nothing, records)
    @test all(record -> record["reference_spectrum_audit"][
        "old_m1_0p1_kVA_reference_passed"] === true, records)
    @test all(record -> record["reference_spectrum_audit"][
        "pic_m0_reference_domain_overlap"] === false, records)
    @test all(record -> record["admission_authorized"] === false &&
        record["medium_fidelity_authorized"] === false &&
        record["promotion_credit"] === false, records)
    source_paths = Dict(
        "v23_source" => joinpath(PROJECT_ROOT, "src", "search",
            "zpinch_nonideal_electrode_audit_v23.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "zpinch_nonideal_electrode_audit_v23.schema.json"),
        "evidence_sources" => joinpath(PROJECT_ROOT, "knowledge",
            "zpinch_nonideal_electrode_v23_sources.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_zpinch_nonideal_electrode_audit_v23.jl"),
        "mechanism_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mechanism_expansion_screen_v1.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(ZPINCH_ADMISSION_V23_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Nonrepetitive plant hypotheses: 336", summary)
    @test occursin("Bounded PIC m=0 reference-domain overlaps: 0", summary)
    @test occursin("Medium-fidelity authorizations: 0", summary)
end

@testset "Mission-consistent repetitive Z-pinch search v24" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(MISSION_CONSISTENT_ZPINCH_V24_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    for key in ("new_commits", "cache_hits", "retry_failures")
        delete!(core["execution"], key)
    end
    @test canonical_hash(core) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "509d186cbe0312ffb72c238e374b6e18ce6b74a2e260b42e9c3c8f0a9e830279"
    @test artifact["input_binding"]["v20_candidate_count"] == 10_000
    @test artifact["input_binding"][
        "v20_zpinch_three_gate_frontier_count"] == 336
    @test artifact["search_contract"]["candidate_count"] == 672
    @test artifact["search_contract"]["parent_count"] == 336
    @test artifact["search_contract"]["boundary_count"] == 2
    @test artifact["search_contract"]["paired_halton_gene_dimensions"] == 5
    @test artifact["execution"]["result_hash"] ==
        "92c8b678bb1d081e57523bf80d425d5cf59f487807d9a8fd0678dd2ac47857e5"
    @test artifact["execution"]["record_count"] == 672
    @test artifact["execution"]["total_shards"] == 56
    @test artifact["execution"]["cache_hits"] == 56
    @test artifact["execution"]["new_commits"] == 0
    @test artifact["outcome"]["hard_rejected_count"] == 672
    @test artifact["outcome"]["blocking_unknown_only_count"] == 0
    @test artifact["outcome"]["pulsed_net_electric_contract_count"] == 672
    @test artifact["outcome"]["nonzero_repetition_count"] == 672
    @test artifact["outcome"]["pic_m0_reference_domain_overlap_count"] == 421
    @test artifact["outcome"]["horizontal_five_gate_passed_count"] == 0
    @test artifact["outcome"]["positive_net_power_closure_count"] == 0
    @test artifact["outcome"]["solid_graphite_count"] == 336
    @test artifact["outcome"]["flowing_liquid_metal_count"] == 336
    @test artifact["outcome"][
        "solid_optimistic_inventory_one_year_passed_count"] == 194
    @test artifact["outcome"][
        "solid_optimistic_inventory_one_year_rejected_count"] == 142
    @test artifact["outcome"]["liquid_boundary_blocking_unknown_count"] == 336
    @test artifact["outcome"][
        "candidate_specific_nonideal_spectrum_available_count"] == 0
    @test artifact["outcome"][
        "candidate_specific_boundary_admission_count"] == 0
    @test artifact["outcome"]["admission_authorized_count"] == 0
    @test artifact["outcome"]["medium_fidelity_authorized_count"] == 0
    @test artifact["outcome"]["descriptor_archive_cell_count"] == 48
    @test artifact["outcome"]["hard_rejection_reason_counts"] == Dict(
        "bounded_pic_m0_reference_domain" => 251,
        "cheap_robustness_screen" => 672,
        "minimal_engineering_closure" => 669,
        "optimistic_graphite_inventory_lifetime" => 142,
        "unified_low_fidelity_physics" => 672)
    @test length(readlines(MISSION_CONSISTENT_ZPINCH_RECORDS_V24_PATH)) == 672
    @test length(readlines(MISSION_CONSISTENT_ZPINCH_ARCHIVE_V24_PATH)) == 48
    @test artifact["archives"]["records_sha256"] == bytes2hex(sha256(
        read(MISSION_CONSISTENT_ZPINCH_RECORDS_V24_PATH)))
    @test artifact["archives"]["archive_sha256"] == bytes2hex(sha256(
        read(MISSION_CONSISTENT_ZPINCH_ARCHIVE_V24_PATH)))
    records = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            MISSION_CONSISTENT_ZPINCH_RECORDS_V24_PATH)]
    @test count(record -> record["boundary"] ==
        "replaceable_solid_graphite", records) == 336
    @test count(record -> record["boundary"] ==
        "flowing_liquid_metal", records) == 336
    @test all(record -> record["mission_contract_id"] ==
        "net_electric_pulsed_v1" &&
        record["genes"]["repetition_rate_Hz"] > 0.0, records)
    @test all(record -> record["horizontal_five_gate_passed"] === false &&
        record["positive_net_power_closure"] === false &&
        record["hard_rejection_count"] > 0, records)
    @test all(record -> record["admission_authorized"] === false &&
        record["medium_fidelity_authorized"] === false &&
        record["promotion_credit"] === false, records)
    source_paths = Dict(
        "v24_source" => joinpath(PROJECT_ROOT, "src", "search",
            "mission_consistent_zpinch_search_v24.jl"),
        "v23_spectrum_and_electrode_source" => joinpath(PROJECT_ROOT, "src",
            "search", "zpinch_nonideal_electrode_audit_v23.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "mission_consistent_zpinch_search_v24.schema.json"),
        "evidence_sources" => joinpath(PROJECT_ROOT, "knowledge",
            "zpinch_nonideal_electrode_v23_sources.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_mission_consistent_zpinch_search_v24.jl"),
        "mechanism_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mechanism_expansion_screen_v1.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(MISSION_CONSISTENT_ZPINCH_V24_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Pulsed net-electric contracts: 672", summary)
    @test occursin("Bounded PIC m=0 reference-domain overlaps: 421", summary)
    @test occursin("Horizontal five-gate passes: 0", summary)
    @test occursin("Medium-fidelity authorizations: 0", summary)
end

@testset "Decoupled mirror field-allocation topology search v25" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(DECOUPLED_MIRROR_V25_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    for key in ("worker_claimed_shard_ids", "worker_claim_counts",
            "claimed_shard_union_count", "worker_count", "execution_mode",
            "live_claim_overlap_count", "aggregate_cache_hits",
            "aggregate_new_commits", "new_commits", "cache_hits",
            "retry_failures")
        delete!(core["preview_execution"], key)
    end
    for key in ("new_commits", "cache_hits", "retry_failures")
        delete!(core["full_review_execution"], key)
    end
    @test canonical_hash(core) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "bf202e97cff8e1e9093af6763283d5c57e26d6f0443a9ac16de62782df81ac35"
    @test artifact["input_binding"]["v20_candidate_count"] == 10_000
    @test artifact["input_binding"][
        "v20_mirror_three_gate_frontier_count"] == 362
    @test artifact["search_contract"]["layout_count"] == 3
    @test artifact["search_contract"]["paired_halton_gene_dimensions"] == 10
    @test artifact["search_contract"][
        "paired_samples_per_parent_layout"] == 2
    @test artifact["search_contract"]["candidate_count"] == 2_172
    @test artifact["search_contract"][
        "precondition_is_rejection_only"] === true
    @test artifact["search_contract"][
        "strict_geometry_is_next_task_authorization_only"] === true
    @test artifact["preview_execution"]["result_hash"] ==
        "2f3ead8a90596794c69dd87b4e3e5626186efef2f3ca4c8e5f5cc281241d8b5f"
    @test artifact["preview_execution"]["total_shards"] == 362
    @test artifact["preview_execution"]["cache_hits"] == 362
    @test artifact["preview_execution"]["new_commits"] == 0
    @test artifact["preview_execution"]["live_claim_overlap_count"] == 0
    @test artifact["preview_execution"]["claimed_shard_union_count"] == 362
    @test sum(values(artifact["preview_execution"][
        "worker_claim_counts"])) == 362
    @test artifact["full_review_execution"]["result_hash"] ==
        "8911852872624f068b5cd9b287e309603d35460ce3fc6e65ad892bc20ab60da1"
    @test artifact["full_review_execution"]["candidate_count"] == 18
    @test artifact["full_review_execution"]["cache_hits"] == 18
    @test artifact["full_review_execution"]["new_commits"] == 0
    @test artifact["full_review_execution"]["selected_global_indices"] ==
        [1315, 1245, 95, 140, 347, 1383, 505, 459, 568, 623, 1658,
            1603, 754, 975, 2044, 888, 2063, 2010]
    @test artifact["outcome"]["precondition_rejected_count"] == 1_403
    @test artifact["outcome"]["precondition_passed_count"] == 769
    @test artifact["outcome"]["preview_layout_summary"][
        "split_ioffe_saddle_pair"]["precondition_passed_count"] == 88
    @test artifact["outcome"]["preview_layout_summary"][
        "continuous_baseball_seam_pair"]["precondition_passed_count"] == 270
    @test artifact["outcome"]["preview_layout_summary"][
        "yin_yang_end_anchor_pair"]["precondition_passed_count"] == 411
    @test artifact["outcome"]["anchor_sign_counts"] == Dict(
        "negative_anchor" => 1_086, "positive_anchor" => 1_086)
    @test artifact["outcome"]["qd_archive_cell_count"] == 281
    @test artifact["outcome"]["full_geometry_rejected_count"] == 18
    @test artifact["outcome"]["full_geometry_survivor_count"] == 0
    @test artifact["outcome"][
        "anisotropic_equilibrium_authorized_count"] == 0
    @test artifact["outcome"][
        "fokker_planck_end_loss_authorized_count"] == 0
    @test artifact["outcome"]["medium_fidelity_authorized_count"] == 0
    @test length(readlines(DECOUPLED_MIRROR_PREVIEW_V25_PATH)) == 2_172
    @test length(readlines(DECOUPLED_MIRROR_QD_V25_PATH)) == 281
    @test length(readlines(DECOUPLED_MIRROR_FULL_V25_PATH)) == 18
    @test artifact["archives"]["preview_sha256"] == bytes2hex(sha256(
        read(DECOUPLED_MIRROR_PREVIEW_V25_PATH)))
    @test artifact["archives"]["qd_archive_sha256"] == bytes2hex(sha256(
        read(DECOUPLED_MIRROR_QD_V25_PATH)))
    @test artifact["archives"]["full_review_sha256"] == bytes2hex(sha256(
        read(DECOUPLED_MIRROR_FULL_V25_PATH)))
    previews = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            DECOUPLED_MIRROR_PREVIEW_V25_PATH)]
    full = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(DECOUPLED_MIRROR_FULL_V25_PATH)]
    @test all(record -> record["geometry"]["finite_geometry_executed"] ===
        false && record["geometry"]["promotion_credit"] === false, previews)
    @test all(record -> record["geometry"]["finite_geometry_executed"] ===
        true && record["geometry"]["all_geometry_gates_passed"] === false &&
        record["promotion_credit"] === false, full)
    @test all(layout -> count(record -> record["layout"] == layout,
        full) == 6, FusionConceptAI._V25_MIRROR_LAYOUTS)
    best = only(filter(record -> record["global_index"] == 1658, full))
    @test best["geometry"]["finite_geometry"]["failed_gates"] ==
        ["axis_field_and_mirror_ratio", "transverse_minimum_b_well"]
    @test best["geometry"]["finite_geometry"]["key_metrics"][
        "refined_peak_field_T"] < 24.0
    @test best["geometry"]["finite_geometry"]["key_metrics"][
        "maximum_normalized_flux_tube_radius"] <= 0.95
    source_paths = Dict(
        "v25_source" => joinpath(PROJECT_ROOT, "src", "search",
            "decoupled_mirror_topology_search_v25.jl"),
        "v25_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mirror_decoupled_vacuum_geometry_v25.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "decoupled_mirror_topology_search_v25.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_decoupled_mirror_topology_search_v25.jl"),
        "worker" => joinpath(PROJECT_ROOT, "scripts",
            "run_decoupled_mirror_topology_worker_v25.jl"),
        "v22_layout_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mirror_layout_vacuum_geometry_v1.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(DECOUPLED_MIRROR_V25_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Precondition rejected/passed: 1403/769", summary)
    @test occursin("Full geometry rejected/survived: 18/0", summary)
    @test occursin("Medium-fidelity authorizations: 0", summary)
end

@testset "Candidate-specific Z-pinch scale and boundary coverage v26" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(ZPINCH_COVERAGE_V26_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    for key in ("new_commits", "cache_hits", "retry_failures")
        delete!(core["execution"], key)
    end
    @test canonical_hash(core) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "b1265d5e8058aec3e3aa9e8cd4d3e2a06c526d0a903b788ed84b94169f8b3d53"
    @test artifact["input_binding"]["v20_candidate_count"] == 10_000
    @test artifact["input_binding"][
        "v20_zpinch_three_gate_frontier_count"] == 336
    @test artifact["input_binding"]["v24_child_count"] == 672
    @test artifact["input_binding"]["evidence_source_count"] == 10
    @test artifact["search_contract"]["candidate_count"] == 672
    @test artifact["search_contract"]["boundary_count"] == 2
    @test length(artifact["search_contract"]["ka_scan"]) == 11
    @test length(artifact["search_contract"]["required_model_branches"]) == 4
    @test artifact["search_contract"][
        "dimensional_scales_are_not_growth_rates"] === true
    @test artifact["search_contract"][
        "reference_domain_overlap_is_not_stability_credit"] === true
    @test artifact["execution"]["result_hash"] ==
        "67cafc1d2c85aa9c9140db91c2b4ad0d8a6bc88e3485ff5f54383851e711fa79"
    @test artifact["execution"]["total_shards"] == 56
    @test artifact["execution"]["cache_hits"] == 56
    @test artifact["execution"]["new_commits"] == 0
    @test artifact["outcome"]["hard_rejected_count"] == 672
    @test artifact["outcome"]["candidate_specific_scale_matrix_count"] == 672
    @test artifact["outcome"][
        "candidate_specific_nonideal_spectrum_available_count"] == 0
    @test artifact["outcome"]["resolved_model_branch_candidate_count"] == 0
    @test artifact["outcome"]["pic_m0_reference_domain_overlap_count"] == 421
    @test artifact["outcome"]["pic_m0_mach_domain_count"] == 529
    @test artifact["outcome"]["boundary_input_ledger_count"] == 672
    @test artifact["outcome"]["solid_graphite_count"] == 336
    @test artifact["outcome"][
        "solid_optimistic_inventory_passed_count"] == 194
    @test artifact["outcome"][
        "solid_optimistic_inventory_rejected_count"] == 142
    @test artifact["outcome"]["flowing_liquid_metal_count"] == 336
    @test artifact["outcome"]["candidate_specific_boundary_admission_count"] == 0
    @test artifact["outcome"]["horizontal_five_gate_passed_count"] == 0
    @test artifact["outcome"]["positive_net_power_closure_count"] == 0
    @test artifact["outcome"]["all_mode_stability_authorized_count"] == 0
    @test artifact["outcome"]["medium_fidelity_authorized_count"] == 0
    @test artifact["outcome"]["descriptor_archive_cell_count"] == 16
    @test length(readlines(ZPINCH_COVERAGE_RECORDS_V26_PATH)) == 672
    @test length(readlines(ZPINCH_COVERAGE_ARCHIVE_V26_PATH)) == 16
    @test artifact["archives"]["records_sha256"] == bytes2hex(sha256(
        read(ZPINCH_COVERAGE_RECORDS_V26_PATH)))
    @test artifact["archives"]["archive_sha256"] == bytes2hex(sha256(
        read(ZPINCH_COVERAGE_ARCHIVE_V26_PATH)))
    records = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            ZPINCH_COVERAGE_RECORDS_V26_PATH)]
    @test all(record -> record["candidate_specific_spectrum_coverage"][
        "candidate_specific_scale_matrix_available"] === true, records)
    @test all(record -> record["candidate_specific_spectrum_coverage"][
        "candidate_specific_nonideal_spectrum_available"] === false, records)
    @test all(record -> record["candidate_specific_spectrum_coverage"][
        "resolved_model_branch_count"] == 0, records)
    @test all(record -> length(record[
        "candidate_specific_spectrum_coverage"]["dimensionless_scan"]) == 11,
        records)
    @test all(record -> record["boundary_admission_bridge"][
        "candidate_specific_input_ledger_available"] === true, records)
    @test all(record -> record["boundary_admission_bridge"][
        "candidate_specific_boundary_admission_passed"] === false, records)
    @test all(record -> record["admission_authorized"] === false &&
        record["medium_fidelity_authorized"] === false &&
        record["promotion_credit"] === false, records)
    source_paths = Dict(
        "v26_source" => joinpath(PROJECT_ROOT, "src", "search",
            "zpinch_candidate_specific_coverage_v26.jl"),
        "v24_source" => joinpath(PROJECT_ROOT, "src", "search",
            "mission_consistent_zpinch_search_v24.jl"),
        "v23_source" => joinpath(PROJECT_ROOT, "src", "search",
            "zpinch_nonideal_electrode_audit_v23.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "zpinch_candidate_specific_coverage_v26.schema.json"),
        "evidence_sources" => joinpath(PROJECT_ROOT, "knowledge",
            "zpinch_candidate_specific_coverage_v26_sources.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_zpinch_candidate_specific_coverage_v26.jl"),
        "mechanism_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mechanism_expansion_screen_v1.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(ZPINCH_COVERAGE_V26_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Candidate-specific scale matrices: 672 / 672", summary)
    @test occursin("Solved non-ideal spectra: 0", summary)
    @test occursin("Medium-fidelity authorizations: 0", summary)
end

@testset "ICF conditional positive-net ledger falsification v27" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(ICF_LEDGER_V27_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    for key in ("new_commits", "cache_hits", "retry_failures")
        delete!(core["execution"], key)
    end
    @test canonical_hash(core) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "e70fe40af22b1c7662096bcb6ff66989360d71d434c3841b0fe64858d10416f8"
    @test artifact["input_binding"]["v20_candidate_count"] == 10_000
    @test artifact["input_binding"][
        "v20_positive_net_icf_frontier_count"] == 42
    @test artifact["input_binding"]["evidence_source_count"] == 7
    @test artifact["search_contract"]["candidate_count"] == 42
    @test artifact["search_contract"][
        "zero_net_required_gain_is_algebraic_diagnostic_only"] === true
    @test artifact["search_contract"][
        "nif_anchor_transfer_forbidden"] === true
    @test artifact["search_contract"][
        "all_v20_horizontal_gates_remain_binding"] === true
    @test artifact["execution"]["result_hash"] ==
        "5cbb0a4d513202802f3503e4c5ad40a72dba97ca7c1c3d8cbb05ec0a4d293679"
    @test artifact["execution"]["record_count"] == 42
    @test artifact["execution"]["total_shards"] == 6
    @test artifact["execution"]["cache_hits"] == 6
    @test artifact["execution"]["new_commits"] == 0
    @test artifact["outcome"][
        "conditional_positive_net_ledger_count"] == 42
    @test artifact["outcome"]["ledger_exactly_reproduced_count"] == 42
    @test artifact["outcome"][
        "conditional_nominal_physics_passed_count"] == 0
    @test artifact["outcome"][
        "conditional_nominal_engineering_passed_count"] == 0
    @test artifact["outcome"]["conditional_nominal_both_passed_count"] == 0
    @test artifact["outcome"]["conditional_robustness_passed_count"] == 0
    @test artifact["outcome"][
        "candidate_specific_target_gain_validated_count"] == 0
    @test artifact["outcome"][
        "candidate_specific_chamber_recovery_model_count"] == 0
    @test artifact["outcome"][
        "candidate_specific_integrated_engineering_validated_count"] == 0
    @test artifact["outcome"][
        "nif_1p5_gain_would_meet_algebraic_zero_net_requirement_count"] == 0
    @test artifact["outcome"]["nif_anchor_transfer_authorized_count"] == 0
    @test artifact["outcome"]["fidelity0_admission_authorized_count"] == 0
    @test artifact["outcome"]["medium_fidelity_authorized_count"] == 0
    @test artifact["outcome"]["descriptor_archive_cell_count"] == 12
    @test artifact["outcome"]["drive_path_counts"] == Dict(
        "laser_direct_drive" => 12, "laser_fast_ignition" => 18,
        "laser_indirect_drive" => 12)
    @test artifact["outcome"]["required_target_gain_for_zero_net_range"] ≈
        [25.998452338458954, 311.5038217692444] rtol = 1.0e-12
    @test artifact["outcome"][
        "searched_gain_over_zero_net_requirement_range"] ≈
        [1.1019217606800389, 1.3037532711576827] rtol = 1.0e-12
    @test length(readlines(ICF_LEDGER_RECORDS_V27_PATH)) == 42
    @test length(readlines(ICF_LEDGER_ARCHIVE_V27_PATH)) == 12
    @test artifact["archives"]["records_sha256"] == bytes2hex(sha256(
        read(ICF_LEDGER_RECORDS_V27_PATH)))
    @test artifact["archives"]["archive_sha256"] == bytes2hex(sha256(
        read(ICF_LEDGER_ARCHIVE_V27_PATH)))
    records = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(ICF_LEDGER_RECORDS_V27_PATH)]
    @test all(record -> record["power_balance_audit"][
        "ledger_exactly_reproduced"] === true, records)
    @test all(record -> record["power_balance_audit"][
        "required_target_gain_for_zero_average_net_power"] > 1.5, records)
    @test all(record -> record["power_balance_audit"][
        "searched_gain_is_validated"] === false, records)
    @test all(record -> record["evidence_ledger"][
        "nif_2022_indirect_drive_anchor"][
            "transferable_to_candidate"] === false, records)
    @test all(record -> length(record["evidence_ledger"][
        "required_candidate_specific_evidence"]) == 8, records)
    @test all(record -> record["evidence_ledger"][
        "resolved_required_evidence_count"] == 0, records)
    @test all(record -> record["conditional_positive_net_ledger"] === true &&
        record["fidelity0_admission_authorized"] === false &&
        record["medium_fidelity_authorized"] === false &&
        record["promotion_credit"] === false, records)
    source_paths = Dict(
        "v27_source" => joinpath(PROJECT_ROOT, "src", "search",
            "icf_conditional_ledger_falsification_v27.jl"),
        "v20_source" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "v15_icf_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "laser_icf_screen_v1.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "icf_conditional_ledger_falsification_v27.schema.json"),
        "evidence_sources" => joinpath(PROJECT_ROOT, "knowledge",
            "icf_conditional_ledger_v27_sources.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_icf_conditional_ledger_falsification_v27.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(ICF_LEDGER_V27_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin(
        "Conditional positive-net ledgers / exact reconstructions: 42 / 42",
        summary)
    @test occursin(
        "NIF gain 1.5 sufficient by algebra alone / transferable: 0 / 0",
        summary)
    @test occursin("Fidelity-0 / medium-fidelity authorizations: 0 / 0",
        summary)
end

@testset "Cross-topology stage and resource telemetry v28" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(STAGE_TELEMETRY_V28_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "03e3f4ddbd1b309c61db25ad62ad8ab94700e6851c34f83f60932b5558876dea"
    @test artifact["input_binding"]["topology_archive_size"] == 1_000
    @test artifact["input_binding"]["family_count"] == 11
    @test length(artifact["input_binding"]["family_counts"]) == 11
    @test all(==(100), values(artifact["input_binding"]["family_counts"]))
    @test artifact["telemetry_contract"]["candidate_count"] == 1_100
    @test artifact["telemetry_contract"]["candidates_per_family"] == 100
    @test artifact["telemetry_contract"]["stage_count"] == 6
    @test artifact["telemetry_contract"]["stage_ids"] ==
        collect(FusionConceptAI._V28_STAGE_IDS)
    @test artifact["telemetry_contract"][
        "warmup_excluded_from_measurement"] === true
    @test artifact["telemetry_contract"][
        "instrumented_path_exact_v20_audit_count"] == 11
    @test artifact["telemetry_contract"][
        "timing_excluded_from_result_hash"] === true
    @test artifact["telemetry_contract"][
        "controlled_failure_probe_excluded_from_candidate_failures"] === true
    @test artifact["telemetry_contract"][
        "peak_rss_is_process_high_water_mark"] === true
    outcome = artifact["deterministic_outcome"]
    @test outcome["attempt_count"] == 1_100
    @test outcome["completed_count"] == 1_100
    @test outcome["actual_failed_count"] == 0
    @test isempty(outcome["actual_failure_stage_counts"])
    @test outcome["warmup_exact_v20_record_match_count"] == 11
    @test outcome["controlled_failure_stage_count"] == 6
    @test outcome["controlled_failure_attribution_pass_count"] == 6
    @test outcome["positive_net_power_ledger_count"] == 21
    @test outcome["five_gate_passed_count"] == 0
    @test outcome["medium_fidelity_candidate_count"] == 0
    @test outcome["deterministic_record_count"] == 1_100
    @test outcome["deterministic_records_sha256"] ==
        "49f8655ef98cb7fd614ba33f669a0b9c92ca52d0cb6e7a2e944938f281641456"
    @test artifact["promotion_credit"][
        "medium_fidelity_authorized_count"] == 0
    @test artifact["promotion_credit"]["physics_evidence_level_change"] == 0
    @test length(readlines(STAGE_TELEMETRY_RECORDS_V28_PATH)) == 1_100
    @test length(readlines(STAGE_TELEMETRY_RAW_V28_PATH)) == 1_100
    @test length(readlines(STAGE_TELEMETRY_FAULTS_V28_PATH)) == 6
    @test artifact["archives"]["deterministic_records_sha256"] ==
        bytes2hex(sha256(read(STAGE_TELEMETRY_RECORDS_V28_PATH)))
    records = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            STAGE_TELEMETRY_RECORDS_V28_PATH)]
    @test all(record -> record["record"]["proxy_five_gate_passed"] ===
        false, records)
    @test all(record -> record["record"][
        "medium_fidelity_candidate_eligible"] === false, records)
    telemetry = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(STAGE_TELEMETRY_RAW_V28_PATH)]
    @test all(record -> record["status"] == "complete" &&
        record["failed_stage"] === nothing &&
        length(record["stage_metrics"]) == 6, telemetry)
    @test all(metric -> metric["status"] == "passed" &&
        metric["wall_seconds"] >= 0 && metric["cpu_seconds"] >= 0 &&
        metric["allocated_bytes"] >= 0 && metric["gc_seconds"] >= 0,
        (metric for record in telemetry for metric in record["stage_metrics"]))
    faults = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(STAGE_TELEMETRY_FAULTS_V28_PATH)]
    @test Set(String(record["injected_stage"]) for record in faults) ==
        Set(FusionConceptAI._V28_STAGE_IDS)
    @test all(record -> record["attribution_passed"] === true &&
        record["injected_stage"] == record["observed_failed_stage"], faults)
    runtime = artifact["runtime_measurements"]
    @test runtime["measured_candidate_wall_seconds"] > 0
    @test runtime["measured_candidate_cpu_seconds"] > 0
    @test runtime["measured_candidates_per_wall_second"] > 0
    @test runtime["process_peak_rss_after_bytes"] >=
        runtime["process_peak_rss_before_bytes"]
    @test length(runtime["stage_and_family_summaries"][
        "stage_summaries"]) == 6
    @test length(runtime["stage_and_family_summaries"][
        "family_summaries"]) == 11
    source_paths = Dict(
        "v28_source" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_topology_stage_telemetry_v28.jl"),
        "v20_source" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "v19_source" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_sharded_execution_v19.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "cross_topology_stage_telemetry_v28.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_cross_topology_stage_telemetry_v28.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(STAGE_TELEMETRY_V28_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Balanced measured candidates / families: 1100 / 11",
        summary)
    @test occursin("Controlled failure attributions: 6 / 6", summary)
    @test occursin(
        "Positive-net ledgers / five-gate passes / medium-fidelity candidates: 21 / 0 / 0",
        summary)
end

@testset "Preregistered frozen acquisition benchmark v29" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(FROZEN_ACQUISITION_V29_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "dbe73630f89ec6c085553756745dbf71107d891604a1833f7a32103c6e598fea"
    @test artifact["input_binding"]["historical_observation_count"] == 1_182
    contract = artifact["benchmark_contract"]
    @test contract["batch_count"] == 5
    @test contract["algorithm_ids"] ==
        collect(FusionConceptAI._V29_ALGORITHM_IDS)
    @test contract["algorithm_count"] == 4
    @test contract["blind_baseline_samples_per_batch"] == 360
    @test contract["proposal_pool_samples_per_batch"] == 60_000
    @test contract["explicit_budget_per_algorithm_per_batch"] == 360
    @test contract["total_conceptual_explicit_budget"] == 7_200
    @test contract["window_overlap_count"] == 0
    @test contract["post_result_tuning_allowed"] === false
    @test length(artifact["batch_summaries"]) == 5
    @test all(batch -> batch["blind_sample_count"] == 360 &&
        batch["proposal_pool_count"] == 60_000 &&
        batch["explicit_budget_per_algorithm"] == 360,
        artifact["batch_summaries"])
    @test all(index -> artifact["batch_summaries"][index]["pool_end"] <
        artifact["batch_summaries"][index + 1]["baseline_start"], 1:4)
    @test length(readlines(FROZEN_ACQUISITION_BATCHES_V29_PATH)) == 5
    @test length(readlines(FROZEN_ACQUISITION_RECORDS_V29_PATH)) == 7_200
    @test artifact["archives"]["batch_sha256"] == bytes2hex(sha256(
        read(FROZEN_ACQUISITION_BATCHES_V29_PATH)))
    @test artifact["archives"]["records_sha256"] == bytes2hex(sha256(
        read(FROZEN_ACQUISITION_RECORDS_V29_PATH)))
    aggregates = artifact["outcome"]["algorithm_aggregates"]
    @test aggregates["stratified_blind_halton"]["gate_pass_counts"] == Dict(
        "engineering" => 49, "five_gate" => 16, "physics" => 60,
        "positive_net" => 1, "robustness" => 16)
    @test aggregates["failure_frontier_qd"]["gate_pass_counts"] == Dict(
        "engineering" => 168, "five_gate" => 26, "physics" => 60,
        "positive_net" => 10, "robustness" => 26)
    @test aggregates["uncertainty_only"]["gate_pass_counts"] == Dict(
        "engineering" => 24, "five_gate" => 9, "physics" => 60,
        "positive_net" => 3, "robustness" => 9)
    @test aggregates["hierarchical_gate_v14_style"][
        "gate_pass_counts"] == Dict(
        "engineering" => 168, "five_gate" => 22, "physics" => 60,
        "positive_net" => 10, "robustness" => 22)
    @test aggregates["failure_frontier_qd"][
        "strict_score_wins_against_blind"] == 5
    @test aggregates["hierarchical_gate_v14_style"][
        "strict_score_wins_against_blind"] == 5
    @test aggregates["uncertainty_only"][
        "strict_score_wins_against_blind"] == 1
    @test aggregates["failure_frontier_qd"]["discovery_score_sum"] == 567.0
    @test aggregates["hierarchical_gate_v14_style"][
        "discovery_score_sum"] == 519.5
    @test all(item -> item["explicit_evaluation_count"] == 1_800 &&
        item["promotion_count"] == 0 &&
        item["negative_anchor_promotion_count"] == 0 &&
        item["surrogate_only_promotion_count"] == 0,
        values(aggregates))
    decision = artifact["outcome"]["decision"]
    @test decision["retain_hierarchical_v14_style"] === true
    @test decision["recommended_algorithm"] ==
        "hierarchical_gate_v14_style"
    @test decision["post_result_tuning_applied"] === false
    @test artifact["promotion_credit"][
        "medium_fidelity_authorized_count"] == 0
    @test artifact["promotion_credit"]["physics_evidence_level_change"] == 0
    records = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            FROZEN_ACQUISITION_RECORDS_V29_PATH)]
    @test all(algorithm -> count(record -> record["algorithm_id"] == algorithm,
        records) == 1_800, FusionConceptAI._V29_ALGORITHM_IDS)
    @test all(record -> record["promoted"] === false &&
        record["surrogate_only_promotion"] === false, records)
    source_paths = Dict(
        "v29_source" => joinpath(PROJECT_ROOT, "src", "search",
            "frozen_acquisition_benchmark_v29.jl"),
        "v14_source" => joinpath(PROJECT_ROOT, "src", "search",
            "hierarchical_gate_discovery_v14.jl"),
        "v13_source" => joinpath(PROJECT_ROOT, "src", "search",
            "safe_active_causal_discovery_v13.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "frozen_acquisition_benchmark_v29.schema.json"),
        "preregistration" => joinpath(PROJECT_ROOT, "knowledge",
            "frozen_acquisition_benchmark_v29_preregistration.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_frozen_acquisition_benchmark_v29.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(FROZEN_ACQUISITION_V29_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Frozen disjoint batches / algorithms: 5 / 4", summary)
    @test occursin("Conceptual explicit evaluations: 7200", summary)
    @test occursin("Recommended algorithm: `hierarchical_gate_v14_style`",
        summary)
end

@testset "Frozen acquisition QD confirmation v30" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(FROZEN_ACQUISITION_V30_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "90455c0e86d4e5855eaebfac4eee70cfebc287cce4162251ae53379bfc19a6c3"
    @test artifact["input_binding"]["historical_observation_count"] == 1_182
    @test artifact["input_binding"]["parent_v29_result_hash"] ==
        "dbe73630f89ec6c085553756745dbf71107d891604a1833f7a32103c6e598fea"
    contract = artifact["benchmark_contract"]
    @test contract["batch_count"] == 5
    @test contract["algorithm_ids"] ==
        collect(FusionConceptAI._V30_ALGORITHM_IDS)
    @test contract["algorithm_count"] == 3
    @test contract["blind_baseline_samples_per_batch"] == 360
    @test contract["proposal_pool_samples_per_batch"] == 60_000
    @test contract["explicit_budget_per_algorithm_per_batch"] == 360
    @test contract["total_conceptual_explicit_budget"] == 5_400
    @test contract["window_overlap_count"] == 0
    @test contract["post_result_tuning_allowed"] === false
    @test length(artifact["batch_summaries"]) == 5
    @test all(batch -> batch["blind_sample_count"] == 360 &&
        batch["proposal_pool_count"] == 60_000 &&
        batch["explicit_budget_per_algorithm"] == 360,
        artifact["batch_summaries"])
    @test all(index -> artifact["batch_summaries"][index]["pool_end"] <
        artifact["batch_summaries"][index + 1]["baseline_start"], 1:4)
    @test length(readlines(FROZEN_ACQUISITION_BATCHES_V30_PATH)) == 5
    @test length(readlines(FROZEN_ACQUISITION_RECORDS_V30_PATH)) == 5_400
    @test artifact["archives"]["batch_sha256"] == bytes2hex(sha256(
        read(FROZEN_ACQUISITION_BATCHES_V30_PATH)))
    @test artifact["archives"]["records_sha256"] == bytes2hex(sha256(
        read(FROZEN_ACQUISITION_RECORDS_V30_PATH)))
    aggregates = artifact["outcome"]["algorithm_aggregates"]
    @test aggregates["stratified_blind_halton"]["gate_pass_counts"] == Dict(
        "engineering" => 55, "five_gate" => 19, "physics" => 60,
        "positive_net" => 3, "robustness" => 19)
    @test aggregates["failure_frontier_qd"]["gate_pass_counts"] == Dict(
        "engineering" => 171, "five_gate" => 21, "physics" => 60,
        "positive_net" => 10, "robustness" => 21)
    @test aggregates["hierarchical_gate_v14_style"][
        "gate_pass_counts"] == Dict(
        "engineering" => 171, "five_gate" => 22, "physics" => 60,
        "positive_net" => 10, "robustness" => 22)
    @test aggregates["failure_frontier_qd"][
        "strict_score_wins_against_blind"] == 5
    @test aggregates["hierarchical_gate_v14_style"][
        "strict_score_wins_against_blind"] == 5
    @test aggregates["failure_frontier_qd"]["discovery_score_sum"] == 510.5
    @test aggregates["hierarchical_gate_v14_style"][
        "discovery_score_sum"] == 522.5
    @test all(item -> item["explicit_evaluation_count"] == 1_800 &&
        item["promotion_count"] == 0 &&
        item["negative_anchor_promotion_count"] == 0 &&
        item["surrogate_only_promotion_count"] == 0,
        values(aggregates))
    primary = artifact["outcome"]["primary_comparison"]
    @test primary["qd_strict_score_wins"] == 2
    @test primary["hierarchical_strict_score_wins"] == 2
    @test primary["score_ties"] == 1
    @test primary["aggregate_gate_count_differences_qd_minus_hierarchical"] ==
        Dict("engineering" => 0, "five_gate" => -1, "physics" => 0,
            "positive_net" => 0, "robustness" => -1)
    @test primary[
        "aggregate_discovery_score_difference_qd_minus_hierarchical"] == -12.0
    @test all(value -> value === false,
        values(primary["primary_conditions"])) == false
    @test primary["primary_conditions"]["blind_sentinel_condition"] === true
    @test primary["primary_conditions"][
        "zero_unauthorized_promotion_condition"] === true
    decision = artifact["outcome"]["decision"]
    @test decision["confirmation_status"] == "qd_confirmation_failed"
    @test decision["operational_noninferiority_confirmed"] === false
    @test decision["superiority_confirmed"] === false
    @test decision["recommended_algorithm"] ==
        "hierarchical_gate_v14_style"
    @test decision["post_result_tuning_applied"] === false
    @test artifact["promotion_credit"][
        "medium_fidelity_authorized_count"] == 0
    @test artifact["promotion_credit"]["physics_evidence_level_change"] == 0
    records = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            FROZEN_ACQUISITION_RECORDS_V30_PATH)]
    @test all(algorithm -> count(record -> record["algorithm_id"] == algorithm,
        records) == 1_800, FusionConceptAI._V30_ALGORITHM_IDS)
    @test all(record -> record["promoted"] === false &&
        record["surrogate_only_promotion"] === false, records)
    source_paths = Dict(
        "v30_source" => joinpath(PROJECT_ROOT, "src", "search",
            "frozen_acquisition_confirmation_v30.jl"),
        "v29_source" => joinpath(PROJECT_ROOT, "src", "search",
            "frozen_acquisition_benchmark_v29.jl"),
        "v14_source" => joinpath(PROJECT_ROOT, "src", "search",
            "hierarchical_gate_discovery_v14.jl"),
        "v13_source" => joinpath(PROJECT_ROOT, "src", "search",
            "safe_active_causal_discovery_v13.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "frozen_acquisition_confirmation_v30.schema.json"),
        "preregistration" => joinpath(PROJECT_ROOT, "knowledge",
            "frozen_acquisition_confirmation_v30_preregistration.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_frozen_acquisition_confirmation_v30.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(FROZEN_ACQUISITION_V30_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Frozen disjoint batches / algorithms: 5 / 3", summary)
    @test occursin(
        "Conceptual explicit evaluations / deterministic rows: 5400 / 5400",
        summary)
    @test occursin("QD / hierarchical strict score wins / ties: 2/2/1",
        summary)
    @test occursin("Confirmation status: `qd_confirmation_failed`", summary)
    @test occursin("Recommended algorithm: `hierarchical_gate_v14_style`",
        summary)
end

@testset "Cross-family gate observability and transfer readiness v31" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(GATE_OBSERVABILITY_V31_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "60f69caeb5306c7cb41259e1cb0f9da72286491fac4a734e29ede9246fe721c1"
    @test artifact["input_binding"]["v20_historical_record_count"] == 10_000
    contract = artifact["audit_contract"]
    @test contract["family_count"] == 11
    @test contract["records_per_family"] == 100
    @test contract["record_count"] == 1_100
    @test contract["computed_gate_and_unknown_evidence_separated"] === true
    @test contract["skipped_and_evaluated_robustness_separated"] === true
    @test contract["candidate_selection_used_formal_labels"] === false
    @test contract["candidate_plan"] ==
        "ten_graph_hash_strata_by_ten_halton_ordinals_per_family"
    @test length(readlines(GATE_OBSERVABILITY_RECORDS_V31_PATH)) == 1_100
    @test artifact["archives"]["records_sha256"] == bytes2hex(sha256(
        read(GATE_OBSERVABILITY_RECORDS_V31_PATH)))
    records = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            GATE_OBSERVABILITY_RECORDS_V31_PATH)]
    @test length(unique(Int(record["candidate_index"])
        for record in records)) == 1_100
    @test length(unique(String(record["family"])
        for record in records)) == 11
    @test all(family -> count(record -> record["family"] == family,
        records) == 100, unique(String(record["family"])
            for record in records))
    @test all(record -> record["raw_result_reconstruction_match"] === true,
        records)
    @test all(record -> record["evidence_coverage_state"] ==
        "incomplete_unknown_requirements", records)
    @test all(record -> record["robustness_state"] ==
        "not_evaluated_nominal_failure", records)
    @test all(record -> record["medium_fidelity_candidate_eligible"] === false,
        records)
    aggregate = artifact["aggregate"]
    @test aggregate["global_semantic_gate_pass_counts"] == Dict(
        "topology" => 1_100, "physics" => 0, "engineering" => 59,
        "outer_envelope" => 1_100, "robustness" => 0)
    @test aggregate["global_positive_net_count"] == 20
    @test aggregate["evidence_complete_record_count"] == 0
    @test aggregate["robustness_not_evaluated_record_count"] == 1_100
    @test aggregate["families_with_physics_label_variation"] == 0
    @test aggregate["families_with_evaluated_robustness"] == 0
    @test aggregate["families_with_complete_evidence"] == 0
    families = aggregate["family_summaries"]
    @test families["magnetic_mirror"]["semantic_gate_pass_counts"][
        "engineering"] == 10
    @test families["sheared_flow_z_pinch"]["semantic_gate_pass_counts"][
        "engineering"] == 49
    @test families["inertial_confinement_fusion"][
        "positive_net_count"] == 20
    readiness = aggregate["readiness_conditions"]
    @test readiness["semantic_mapping_complete"] === true
    @test readiness["raw_result_reconstruction_complete"] === true
    @test readiness["all_11_families_have_physics_label_variation"] === false
    @test readiness["all_11_families_have_evaluated_robustness"] === false
    @test readiness[
        "all_11_families_have_evidence_complete_candidate"] === false
    @test aggregate["diagnostic_failure_frontier_search_authorized"] === true
    @test aggregate["five_gate_acquisition_transfer_authorized"] === false
    @test aggregate["cross_family_acquisition_transfer_authorized"] === false
    credit = artifact["promotion_credit"]
    @test credit["diagnostic_failure_frontier_search_authorized"] === true
    @test credit["five_gate_acquisition_transfer_authorized"] === false
    @test credit["acquisition_transfer_authorized"] === false
    @test credit["medium_fidelity_authorized_count"] == 0
    @test credit["physics_evidence_level_change"] == 0
    source_paths = Dict(
        "v31_source" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_family_gate_observability_v31.jl"),
        "v28_source" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_topology_stage_telemetry_v28.jl"),
        "v20_source" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "v18_source" => joinpath(PROJECT_ROOT, "src", "search",
            "attribute_graph_genome_pipeline_v18.jl"),
        "v17_source" => joinpath(PROJECT_ROOT, "src", "search",
            "attribute_graph_grammar_v17.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "cross_family_gate_observability_v31.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_cross_family_gate_observability_v31.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(GATE_OBSERVABILITY_V31_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin(
        "Topology / physics / engineering / envelope / robustness passes: 1100/0/59/1100/0",
        summary)
    @test occursin("Diagnostic failure-frontier search authorized: `true`",
        summary)
    @test occursin(
        "Five-gate acquisition comparison/promotion authorized: `false`",
        summary)
end

@testset "Diagnostic recoverable 11-family failure-frontier QD v32" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(DIAGNOSTIC_QD_V32_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "80c039d0bdd724527d0a1b2a129f235057e71f9056e5846f1c57fcc34c2a4a73"
    @test artifact["execution"]["result_hash"] ==
        "0bdde0c410e47f9da4551355d696024408326baf793494819e8026b5549a7d5c"
    contract = artifact["search_contract"]
    @test contract["logical_candidate_count"] == 22_000
    @test contract["candidate_offset"] == 10_000
    @test contract["physical_candidate_start"] == 10_001
    @test contract["physical_candidate_end"] == 32_000
    @test contract["sample_ordinal_start"] == 11
    @test contract["sample_ordinal_end"] == 32
    @test contract["samples_per_topology"] == 22
    @test contract["topology_count"] == 1_000
    @test contract["family_count"] == 11
    @test contract["shard_size"] == 100
    @test contract["shard_count"] == 220
    @test contract["diagnostic_search_authorized"] === true
    @test contract["five_gate_comparison_authorized"] === false
    @test contract["gate_thresholds_changed"] === false
    @test artifact["execution"]["total_shards"] == 220
    @test artifact["execution"]["completed_shards"] == 220
    @test artifact["execution"]["complete"] === true
    @test count(_ -> true, eachline(DIAGNOSTIC_QD_CANDIDATES_V32_PATH)) ==
        22_000
    @test count(_ -> true, eachline(DIAGNOSTIC_QD_GRAPH_V32_PATH)) == 1_000
    @test count(_ -> true, eachline(DIAGNOSTIC_QD_MECHANISM_V32_PATH)) == 68
    @test count(_ -> true, eachline(DIAGNOSTIC_QD_FRONTIER_V32_PATH)) == 55
    @test artifact["archives"]["candidate_sha256"] == bytes2hex(sha256(
        read(DIAGNOSTIC_QD_CANDIDATES_V32_PATH)))
    @test artifact["archives"]["graph_archive_sha256"] == bytes2hex(sha256(
        read(DIAGNOSTIC_QD_GRAPH_V32_PATH)))
    @test artifact["archives"]["mechanism_archive_sha256"] == bytes2hex(
        sha256(read(DIAGNOSTIC_QD_MECHANISM_V32_PATH)))
    @test artifact["archives"]["frontier_sha256"] == bytes2hex(sha256(
        read(DIAGNOSTIC_QD_FRONTIER_V32_PATH)))
    search = artifact["search_summary"]
    @test search["input_record_count"] == 22_000
    @test search["unique_physics_hash_count"] == 22_000
    @test search["family_count"] == 11
    @test search["global_semantic_gate_pass_counts"] == Dict(
        "topology" => 22_000, "physics" => 0, "engineering" => 624,
        "outer_envelope" => 22_000, "robustness" => 0)
    @test search["global_positive_net_count"] == 69
    @test search["evidence_complete_count"] == 0
    @test search["robustness_evaluated_count"] == 0
    @test search["graph_archive_cell_count"] == 1_000
    @test search["mechanism_archive_cell_count"] == 68
    @test search["frontier_record_count"] == 55
    @test search["frontier_per_family"] == 5
    @test search["promotion_count"] == 0
    @test search["medium_fidelity_authorized_count"] == 0
    families = search["family_summaries"]
    @test families["magnetic_mirror"]["record_count"] == 7_964
    @test families["magnetic_mirror"]["semantic_gate_pass_counts"][
        "engineering"] == 96
    @test families["sheared_flow_z_pinch"]["record_count"] == 1_584
    @test families["sheared_flow_z_pinch"][
        "semantic_gate_pass_counts"]["engineering"] == 528
    @test families["inertial_confinement_fusion"][
        "positive_net_count"] == 63
    @test families["magnetized_target_fusion"]["positive_net_count"] == 6
    frontier = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            DIAGNOSTIC_QD_FRONTIER_V32_PATH)]
    @test length(unique(String(record["family"])
        for record in frontier)) == 11
    @test all(family -> count(record -> record["family"] == family,
        frontier) == 5, unique(String(record["family"])
            for record in frontier))
    @test all(record -> record["promoted"] === false &&
        record["medium_fidelity_authorized"] === false &&
        record["five_gate_comparison_authorized"] === false &&
        record["diagnostic_search_authorized"] === true, frontier)
    credit = artifact["promotion_credit"]
    @test credit["diagnostic_search_authorized"] === true
    @test credit["five_gate_comparison_authorized"] === false
    @test credit["promotion_count"] == 0
    @test credit["medium_fidelity_authorized_count"] == 0
    @test credit["physics_evidence_level_change"] == 0
    source_paths = Dict(
        "v32_source" => joinpath(PROJECT_ROOT, "src", "search",
            "diagnostic_cross_family_qd_v32.jl"),
        "v31_source" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_family_gate_observability_v31.jl"),
        "v20_source" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "recoverable_execution" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_sharded_execution_v19.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "diagnostic_cross_family_qd_v32.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_diagnostic_cross_family_qd_v32.jl"),
        "worker" => joinpath(PROJECT_ROOT, "scripts",
            "run_diagnostic_cross_family_worker_v32.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(DIAGNOSTIC_QD_V32_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("New physical candidate range / records: 10001..32000 / 22000",
        summary)
    @test occursin(
        "Topology / physics / engineering / envelope / robustness passes: 22000/0/624/22000/0",
        summary)
    @test occursin("Graph / mechanism QD cells / family frontier: 1000/68/55",
        summary)
    @test occursin("Promotions / medium-fidelity authorizations: 0/0",
        summary)
end

@testset "Failure-directed rejection-only mirror geometry triage v21" begin
    synthetic = Dict{String,Any}[
        Dict("family" => "magnetic_mirror", "gate_pass_count" => 3,
            "positive_net_power_closure" => false,
            "missing_proxy_requirements" => ["finite_mirror_coils"]),
        Dict("family" => "inertial_confinement_fusion", "gate_pass_count" => 2,
            "positive_net_power_closure" => true,
            "missing_proxy_requirements" => ["mix_and_lpi"]),
    ]
    census = failure_directed_census_v21(synthetic)
    @test census["candidate_count"] == 2
    @test census["family_gate3_counts"]["magnetic_mirror"] == 1
    @test census["family_positive_counts"][
        "inertial_confinement_fusion"] == 1
    @test census["missing_requirement_counts"]["finite_mirror_coils"] == 1

    selection_fixture = Dict{String,Any}[
        Dict("candidate_index" => 2, "module_ids" => ["a", "b"],
            "preview" => Dict("failed_gate_count" => 4,
                "sum_log_normalized_violation" => 2.0)),
        Dict("candidate_index" => 1, "module_ids" => ["a", "c"],
            "preview" => Dict("failed_gate_count" => 3,
                "sum_log_normalized_violation" => 1.0)),
        Dict("candidate_index" => 3, "module_ids" => ["d"],
            "preview" => Dict("failed_gate_count" => 5,
                "sum_log_normalized_violation" => 4.0)),
    ]
    selected, covered = select_diverse_geometry_reviews_v21(
        selection_fixture, 2)
    @test selected == [2, 1]
    @test covered == ["a", "b", "c"]

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(FAILURE_DIRECTED_GEOMETRY_V21_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    @test canonical_hash(core) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "e17ed46a5189dab2fc3193cf53c357553c9a6d9c069874510bd1e392da4a557c"
    @test artifact["input_binding"]["v20_candidate_count"] == 10_000
    @test artifact["input_binding"]["v20_mirror_gate3_count"] == 362
    @test artifact["failure_census"]["family_gate3_counts"][
        "sheared_flow_z_pinch"] == 336
    @test artifact["failure_census"]["family_positive_counts"][
        "inertial_confinement_fusion"] == 42
    @test artifact["preview_execution"]["result_hash"] ==
        "0ad13806e1e87411f17482001b2c8d8cab52efa781bdd13bc2442dc6dd923477"
    @test artifact["preview_execution"]["candidate_count"] == 362
    @test artifact["preview_execution"]["total_shards"] == 37
    @test artifact["full_review_execution"]["result_hash"] ==
        "4fa55f95c723f8eaeb2c45bc320255ecc06cf7fea64130131385da9b8f94939e"
    @test artifact["full_review_execution"]["candidate_count"] == 12
    @test length(artifact["full_review_execution"]["covered_module_ids"]) == 22
    @test artifact["full_review_execution"]["selected_candidate_indices"] ==
        [3037, 3004, 3026, 3191, 3131, 3797, 3015, 3059, 3101, 3141,
            3171, 3181]
    @test artifact["outcome"]["preview_rejected_count"] == 362
    @test artifact["outcome"]["preview_geometry_survivor_count"] == 0
    @test artifact["outcome"]["full_rejected_count"] == 12
    @test artifact["outcome"]["full_geometry_survivor_count"] == 0
    @test artifact["outcome"]["anisotropic_equilibrium_authorized_count"] == 0
    @test artifact["outcome"]["fokker_planck_end_loss_authorized_count"] == 0
    @test artifact["promotion_credit"]["medium_fidelity_authorized_count"] == 0
    @test length(readlines(MIRROR_GEOMETRY_PREVIEWS_V21_PATH)) == 362
    @test length(readlines(MIRROR_GEOMETRY_FULL_REVIEWS_V21_PATH)) == 12
    @test artifact["archives"]["preview_sha256"] == bytes2hex(sha256(
        read(MIRROR_GEOMETRY_PREVIEWS_V21_PATH)))
    @test artifact["archives"]["full_review_sha256"] == bytes2hex(sha256(
        read(MIRROR_GEOMETRY_FULL_REVIEWS_V21_PATH)))
    preview_records = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(MIRROR_GEOMETRY_PREVIEWS_V21_PATH)]
    full_records = [FusionConceptAI._plain_json(JSON3.read(line,
        Dict{String,Any})) for line in eachline(
            MIRROR_GEOMETRY_FULL_REVIEWS_V21_PATH)]
    @test all(record -> record["preview"]["rejection_credit"] === true &&
        record["preview"]["promotion_credit"] === false &&
        record["preview"]["failed_gate_count"] == 5, preview_records)
    @test all(record -> record["full_review"]["rejection_credit"] === true &&
        record["full_review"]["promotion_credit"] === false &&
        record["full_review"]["failed_gate_count"] == 4, full_records)
    task_ids = Set(String(task["task_id"]) for task in artifact["task_schedule"])
    @test Set(["mirror_anisotropic_equilibrium_v21",
        "mirror_fokker_planck_end_loss_v21",
        "zpinch_nonideal_sausage_kink_spectrum_v21",
        "zpinch_electrode_boundary_lifetime_v21"]) <= task_ids
    source_paths = Dict(
        "v21_source" => joinpath(PROJECT_ROOT, "src", "search",
            "failure_directed_geometry_triage_v21.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "failure_directed_geometry_triage_v21.schema.json"),
        "evidence_sources" => joinpath(PROJECT_ROOT, "knowledge",
            "failure_directed_v21_sources.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_failure_directed_geometry_triage_v21.jl"),
        "finite_coil_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mirror_finite_coil_geometry_v1.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(FAILURE_DIRECTED_GEOMETRY_V21_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Preview geometry rejections/survivors: 362/0", summary)
    @test occursin("Full geometry rejections/survivors: 12/0", summary)
    @test occursin("Medium-fidelity authorizations: 0", summary)
end

@testset "Attribute-graph typed Genome and executable prescreen v18" begin
    seeds = load_genomes(SEEDS_PATH)
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    representatives = TopologyAssemblyV17[]
    seen = Set{String}()
    for assembly in grammar.archive
        assembly.family in seen && continue
        push!(representatives, assembly)
        push!(seen, assembly.family)
    end
    @test length(representatives) == 11
    small = AttributeGraphGrammarResultV17(grammar.catalog,
        grammar.compatible_assembly_count, grammar.compatible_family_counts,
        representatives, Dict(item.family => 1 for item in representatives),
        grammar.partial_extension_attempt_count,
        grammar.rejected_partial_extension_count,
        grammar.rejection_reason_counts, grammar.rejection_samples,
        grammar.catalog_hash, grammar.claim_boundary)
    first = run_attribute_graph_genome_pipeline_v18(small, seeds)
    second = run_attribute_graph_genome_pipeline_v18(small, seeds)
    @test canonical_hash(attribute_graph_genome_pipeline_to_dict_v18(first)) ==
        canonical_hash(attribute_graph_genome_pipeline_to_dict_v18(second))
    @test length(first.records) == 11
    @test length(first.compiled_family_counts) == 11
    @test all(record -> record.proxy_applicable &&
        isempty(record.topology_graph_errors), first.records)
    @test length(unique(record.compiled.genome.physics_hash
        for record in first.records)) == 11
    @test all(record -> validate_genome(record.compiled.genome).valid,
        first.records)
    @test all(record -> mission_contract_for(
        default_mission_contract_registry(), record.compiled.genome).id ==
        record.compiled.mission_contract_id, first.records)
    @test all(record -> Set(record.compiled.declared_requirements) ⊆
        Set(FusionConceptAI._requirements(record.compiled.genome)), first.records)
    @test all(record -> !record.proxy_five_gate_passed &&
        !record.proxy_coverage_complete &&
        !record.medium_fidelity_candidate_eligible, first.records)

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(ATTRIBUTE_GRAPH_GENOME_V18_PATH, String), Dict{String,Any}))
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "81ab442683cf0e5ce1d9fb188651488990169181949324e143ad3b6835458ebe"
    @test artifact["determinism_audit"]["core_hash"] ==
        "ef072e715b6a9ab3b5f83c74e183ae14535c3065ecfc8902d3358149c2d47c86"
    @test artifact["compilation_audit"]["compiled_genome_count"] == 1000
    @test artifact["compilation_audit"]["unique_genome_physics_hash_count"] == 1000
    @test artifact["compilation_audit"]["module_geometry_solved_count"] == 0
    @test artifact["evaluator_routing"]["applicable_count"] == 1000
    @test artifact["evaluator_routing"][
        "all_eleven_families_have_executable_route"] === true
    @test artifact["prescreen_summary"]["topology_graph_error_count"] == 0
    @test artifact["prescreen_summary"]["positive_net_power_closure_count"] == 3
    @test artifact["prescreen_summary"]["proxy_five_gate_pass_count"] == 0
    @test artifact["prescreen_summary"][
        "proxy_requirement_coverage_complete_count"] == 0
    @test artifact["evaluation_and_promotion_policy"][
        "medium_fidelity_candidate_queue_count"] == 0
    @test artifact["evaluation_and_promotion_policy"][
        "medium_fidelity_authorized_count"] == 0
    @test artifact["compiled_genome_archive"]["record_count"] == 1000
    @test artifact["compiled_genome_archive"]["file_sha256"] ==
        bytes2hex(sha256(read(ATTRIBUTE_GRAPH_GENOME_V18_ARCHIVE_PATH)))
    @test length(readlines(ATTRIBUTE_GRAPH_GENOME_V18_ARCHIVE_PATH)) == 1000
    @test artifact["sealed_inputs"]["genome_ir_sha256"] ==
        "251ffd0f325cd06f57a9ac96ec311e6644a2ae72b881b12e280189dae66470a5"
    @test artifact["sealed_inputs"]["family_registry_sha256"] ==
        "e92e59fc716ba35fda8879dcfda966d4196fc23cf21d20b0999d0e83db3785ed"
    source_paths = Dict(
        "attribute_graph_genome_pipeline" => joinpath(PROJECT_ROOT, "src",
            "search", "attribute_graph_genome_pipeline_v18.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "attribute_graph_genome_pipeline_v18.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_attribute_graph_genome_pipeline_v18.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(ATTRIBUTE_GRAPH_GENOME_V18_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Compiled typed Genomes: 1000", summary)
    @test occursin("Proxy five-gate passes: 0", summary)
    @test occursin("No candidate was promoted", summary)
end

@testset "Recoverable deterministic sharded execution v19" begin
    spec = RecoverableRunSpecV19("v19_test", "deterministic_test_kernel",
        "1.0.0", 257, 31; max_retries = 2,
        max_retained_per_shard = 8,
        kernel_config = Dict("seed" => "v19-test-seed"))
    shards = deterministic_shards_v19(spec)
    @test length(shards) == 9
    @test shards[1].first_index == 1
    @test shards[end].last_index == 257
    @test length(unique(getfield.(shards, :input_hash))) == 9

    kernel = function(candidate_index, config)
        digest = sha256(codeunits("$(config["seed"])|$candidate_index"))
        record = Dict{String,Any}(
            "candidate_hash" => bytes2hex(digest),
            "bucket" => Int(digest[1]) % 7,
            "value" => candidate_index * candidate_index,
        )
        return RecoverableKernelOutcomeV19(record, candidate_index % 53 == 0)
    end

    mktempdir() do directory
        uninterrupted = run_recoverable_search_v19(spec, kernel;
            run_directory = joinpath(directory, "uninterrupted"),
            cache_directory = joinpath(directory, "cache_a"))
        injector = (shard_id, attempt) -> shard_id in (2, 8) && attempt == 1
        interrupted = run_recoverable_search_v19(spec, kernel;
            run_directory = joinpath(directory, "resumed"),
            cache_directory = joinpath(directory, "cache_b"),
            stop_after_commits = 3, failure_injector = injector)
        @test interrupted.interrupted
        @test !interrupted.complete
        @test interrupted.completed_shards == 3
        resumed = run_recoverable_search_v19(spec, kernel;
            run_directory = joinpath(directory, "resumed"),
            cache_directory = joinpath(directory, "cache_b"),
            failure_injector = injector)
        reused = run_recoverable_search_v19(spec, kernel;
            run_directory = joinpath(directory, "reuse"),
            cache_directory = joinpath(directory, "cache_a"))
        @test uninterrupted.complete && resumed.complete && reused.complete
        @test uninterrupted.result_hash == resumed.result_hash == reused.result_hash
        @test interrupted.retry_failures + resumed.retry_failures == 2
        @test resumed.cache_hits == 3
        @test reused.cache_hits == 9
        @test reused.new_commits == 0
        manifest = recoverable_manifest_v19(joinpath(directory, "resumed"))
        @test manifest["complete"] === true
        @test manifest["result_hash"] == resumed.result_hash
        @test manifest["completed_shards"] == 9
        @test occursin("does not add physics fidelity", resumed.claim_boundary)
    end

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(RECOVERABLE_EXECUTION_V19_PATH, String), Dict{String,Any}))
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "c747d751c134fcedca3f4555cfeb446bbd86778cbc3b02822c8dc7dce521afb5"
    @test artifact["formal_probe"]["equivalence_audit"]["result_hash"] ==
        "d6bf16ad7ed8ca5b249d20e37843862117ec1bc27253c3f71efc2c15acafbdaa"
    @test artifact["formal_probe"]["spec"]["total_candidates"] == 50_000
    @test artifact["formal_probe"]["shard_plan"]["total_shards"] == 129
    @test artifact["formal_probe"]["interruption_stage"]["completed_shards"] == 23
    @test artifact["formal_probe"]["failure_injection"]["observed_failure_count"] == 6
    @test artifact["formal_probe"]["cache_reuse"]["new_commits"] == 0
    @test artifact["formal_probe"]["cache_reuse"]["cache_hits"] == 129
    @test artifact["formal_probe"]["equivalence_audit"][
        "all_result_hashes_equal"] === true
    @test artifact["acceptance"]["ten_million_candidate_run_demonstrated"] === false
    @test artifact["acceptance"][
        "parallel_multi_process_claiming_demonstrated"] === false
    @test artifact["promotion_credit"]["physical_candidates_evaluated"] == 0
    source_paths = Dict(
        "recoverable_execution" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_sharded_execution_v19.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "recoverable_sharded_execution_v19.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_recoverable_sharded_execution_v19.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(RECOVERABLE_EXECUTION_V19_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Synthetic candidates: 50,000", summary)
    @test occursin("Recomputed shards during cache reuse: 0", summary)
    @test occursin("infrastructure validation only", summary)
end

@testset "Recoverable real cross-topology fidelity-0 kernel v20" begin
    seeds = load_genomes(SEEDS_PATH)
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    @test length(context.assemblies) == 1000
    @test length(unique(getfield.(context.assemblies, :family))) == 11
    @test context.archive_hash ==
        "d2c59cf7221ec2689929ebcf149dd3fcd9fb979be361b7c0c18d5d666a80966f"

    representative_indices = Int[]
    seen = Set{String}()
    for (index, assembly) in enumerate(context.assemblies)
        assembly.family in seen && continue
        push!(representative_indices, index)
        push!(seen, assembly.family)
    end
    representatives = [evaluate_cross_topology_candidate_v20(context, index)
        for index in representative_indices]
    @test length(representatives) == 11
    @test all(candidate -> candidate.prescreen.proxy_applicable,
        representatives)
    @test all(candidate -> isempty(candidate.prescreen.topology_graph_errors),
        representatives)
    @test all(candidate -> !candidate.prescreen.proxy_five_gate_passed &&
        !candidate.prescreen.proxy_coverage_complete &&
        !candidate.prescreen.medium_fidelity_candidate_eligible,
        representatives)

    first = evaluate_cross_topology_candidate_v20(context, 1)
    repeated = evaluate_cross_topology_candidate_v20(context, 1)
    second_sample = evaluate_cross_topology_candidate_v20(context, 1001)
    @test canonical_hash(cross_topology_candidate_to_dict_v20(first)) ==
        canonical_hash(cross_topology_candidate_to_dict_v20(repeated))
    @test first.prescreen.compiled.graph_hash ==
        second_sample.prescreen.compiled.graph_hash
    @test first.sample_ordinal == 1 && second_sample.sample_ordinal == 2
    @test first.prescreen.compiled.genome.physics_hash !=
        second_sample.prescreen.compiled.genome.physics_hash

    spec = recoverable_cross_topology_spec_v20(context, 22, 11;
        run_id = "v20_real_kernel_test")
    kernel = recoverable_cross_topology_kernel_v20(context)
    mktempdir() do directory
        uninterrupted = run_recoverable_search_v19(spec, kernel;
            run_directory = joinpath(directory, "uninterrupted"),
            cache_directory = joinpath(directory, "cache_a"))
        interrupted = run_recoverable_search_v19(spec, kernel;
            run_directory = joinpath(directory, "resumed"),
            cache_directory = joinpath(directory, "cache_b"),
            stop_after_commits = 1,
            failure_injector = (shard_id, attempt) ->
                shard_id == 1 && attempt == 1)
        resumed = run_recoverable_search_v19(spec, kernel;
            run_directory = joinpath(directory, "resumed"),
            cache_directory = joinpath(directory, "cache_b"))
        @test uninterrupted.complete && resumed.complete
        @test interrupted.interrupted && !interrupted.complete
        @test uninterrupted.result_hash == resumed.result_hash
        records_a = collect_retained_records_v20(spec, joinpath(directory, "cache_a"))
        records_b = collect_retained_records_v20(spec, joinpath(directory, "cache_b"))
        @test canonical_hash(records_a) == canonical_hash(records_b)
        @test length(records_a) == 22
        archive = cross_topology_failure_aware_archive_v20(records_a)
        @test archive["archive_cell_count"] == 22
        @test archive["medium_fidelity_candidate_count"] == 0

        lease_spec = RecoverableRunSpecV19("v20_lease_test", "lease_probe",
            "1", 7, 7; max_retained_per_shard = 7)
        lease_cache = joinpath(directory, "lease_cache")
        stale = claim_next_recoverable_shard_v20(lease_spec;
            cache_directory = lease_cache, worker_id = "worker-a",
            lease_seconds = 0.0)
        sleep(0.01)
        reclaimed = claim_next_recoverable_shard_v20(lease_spec;
            cache_directory = lease_cache, worker_id = "worker-b",
            lease_seconds = 60.0)
        @test stale.shard_id == reclaimed.shard_id == 1
        @test stale.lease_generation == 1
        @test reclaimed.lease_generation == 2
    end

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(RECOVERABLE_CROSS_TOPOLOGY_V20_PATH, String), Dict{String,Any}))
    core = deepcopy(artifact)
    delete!(core, "deterministic_result_hash")
    delete!(core, "runtime_measurements")
    delete!(core, "source_hashes")
    delete!(core["failure_and_lease_audit"], "worker_a_claims")
    delete!(core["failure_and_lease_audit"], "worker_b_claims")
    @test canonical_hash(core) == artifact["deterministic_result_hash"]
    @test artifact["deterministic_result_hash"] ==
        "ae5eb64f9586f672ed09985cf3ea7adf4b5db641140f900b318b5e2ab3bff61e"
    @test artifact["execution_equivalence"]["result_hash"] ==
        "9c3bcb52b564dc2c3626c929395c66ccaf800085c446394808d7d51916459b52"
    @test artifact["physics_search_summary"]["candidate_count"] == 1100
    @test artifact["physics_search_summary"]["unique_physics_hash_count"] == 1100
    @test artifact["physics_search_summary"]["topology_count"] == 1000
    @test artifact["physics_search_summary"]["family_count"] == 11
    @test artifact["physics_search_summary"]["applicable_count"] == 1100
    @test artifact["physics_search_summary"]["topology_graph_error_count"] == 0
    @test artifact["physics_search_summary"]["five_gate_count"] == 0
    @test artifact["physics_search_summary"]["positive_net_count"] == 0
    @test artifact["physics_search_summary"]["coverage_complete_count"] == 0
    @test artifact["physics_search_summary"]["medium_fidelity_candidate_count"] == 0
    @test artifact["physics_search_summary"]["qd_archive_cell_count"] == 1000
    @test artifact["execution_equivalence"]["all_result_hashes_equal"] === true
    @test artifact["execution_equivalence"][
        "all_candidate_record_hashes_equal"] === true
    @test artifact["failure_and_lease_audit"]["observed_retry_failures"] == 4
    @test artifact["failure_and_lease_audit"][
        "maximum_observed_lease_generation"] == 2
    @test length(readlines(RECOVERABLE_CROSS_TOPOLOGY_V20_CANDIDATES_PATH)) == 1100
    @test length(readlines(RECOVERABLE_CROSS_TOPOLOGY_V20_ARCHIVE_PATH)) == 1000
    @test artifact["archives"]["candidate_sha256"] == bytes2hex(sha256(
        read(RECOVERABLE_CROSS_TOPOLOGY_V20_CANDIDATES_PATH)))
    @test artifact["archives"]["qd_archive_sha256"] == bytes2hex(sha256(
        read(RECOVERABLE_CROSS_TOPOLOGY_V20_ARCHIVE_PATH)))
    source_paths = Dict(
        "cross_topology_kernel" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "recoverable_execution" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_sharded_execution_v19.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "recoverable_cross_topology_v20.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_recoverable_cross_topology_v20.jl"),
        "worker" => joinpath(PROJECT_ROOT, "scripts",
            "run_cross_topology_worker_v20.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    summary = read(RECOVERABLE_CROSS_TOPOLOGY_V20_SUMMARY_PATH, String)
    @test occursin(artifact["deterministic_result_hash"], summary)
    @test occursin("Real fidelity-0 candidates: 1100", summary)
    @test occursin("Complete five-gate passes: 0", summary)
    @test occursin("1e7", summary) && occursin("not completed", summary)

    scale_artifact = FusionConceptAI._plain_json(JSON3.read(
        read(RECOVERABLE_CROSS_TOPOLOGY_SCALE_V20_PATH, String),
        Dict{String,Any}))
    scale_core = deepcopy(scale_artifact)
    delete!(scale_core, "deterministic_result_hash")
    delete!(scale_core, "runtime_measurements")
    delete!(scale_core, "source_hashes")
    delete!(scale_core["execution"], "worker_claimed_shard_ids")
    @test canonical_hash(scale_core) ==
        scale_artifact["deterministic_result_hash"]
    @test scale_artifact["deterministic_result_hash"] ==
        "7725d33f49db0dc113999e4ab1c127cdce1b6de61e0427febd95a6f7e2e6cf59"
    @test scale_artifact["execution"]["result_hash"] ==
        "74ddeaf80c217ede2f78543cdf54dca0414ab50fe22da40a29ce94fe7c8264b0"
    @test scale_artifact["execution"]["worker_count"] == 4
    @test scale_artifact["execution"]["total_shards"] == 100
    @test scale_artifact["execution"]["aggregate_cache_hits"] == 100
    @test scale_artifact["execution"]["aggregate_new_commits"] == 0
    @test scale_artifact["execution"]["all_shards_claimed_once"] === true
    @test scale_artifact["execution"]["live_claim_overlap_count"] == 0
    @test all(count == 25 for count in values(
        scale_artifact["execution"]["worker_claim_counts"]))
    @test scale_artifact["physics_search_summary"]["candidate_count"] == 10_000
    @test scale_artifact["physics_search_summary"][
        "unique_physics_hash_count"] == 10_000
    @test scale_artifact["physics_search_summary"]["topology_count"] == 1000
    @test scale_artifact["physics_search_summary"]["samples_per_topology"] == 10
    @test scale_artifact["physics_search_summary"]["family_count"] == 11
    @test scale_artifact["physics_search_summary"]["positive_net_count"] == 42
    @test scale_artifact["physics_search_summary"]["five_gate_count"] == 0
    @test scale_artifact["physics_search_summary"][
        "coverage_complete_count"] == 0
    @test scale_artifact["physics_search_summary"][
        "medium_fidelity_candidate_count"] == 0
    @test scale_artifact["physics_search_summary"][
        "qd_archive_positive_net_count"] == 21
    @test scale_artifact["promotion_credit"][
        "medium_fidelity_authorized_count"] == 0
    @test length(readlines(
        RECOVERABLE_CROSS_TOPOLOGY_SCALE_V20_CANDIDATES_PATH)) == 10_000
    @test length(readlines(
        RECOVERABLE_CROSS_TOPOLOGY_SCALE_V20_ARCHIVE_PATH)) == 1000
    @test scale_artifact["archives"]["candidate_sha256"] ==
        bytes2hex(sha256(read(
            RECOVERABLE_CROSS_TOPOLOGY_SCALE_V20_CANDIDATES_PATH)))
    @test scale_artifact["archives"]["qd_archive_sha256"] ==
        bytes2hex(sha256(read(
            RECOVERABLE_CROSS_TOPOLOGY_SCALE_V20_ARCHIVE_PATH)))
    scale_source_paths = Dict(
        "cross_topology_kernel" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_cross_topology_kernel_v20.jl"),
        "recoverable_execution" => joinpath(PROJECT_ROOT, "src", "search",
            "recoverable_sharded_execution_v19.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "recoverable_cross_topology_scale_v20.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_recoverable_cross_topology_scale_v20.jl"),
        "worker" => joinpath(PROJECT_ROOT, "scripts",
            "run_cross_topology_worker_v20.jl"))
    for (key, path) in scale_source_paths
        @test scale_artifact["source_hashes"][key] ==
            bytes2hex(sha256(read(path)))
    end
    scale_summary = read(
        RECOVERABLE_CROSS_TOPOLOGY_SCALE_V20_SUMMARY_PATH, String)
    @test occursin(scale_artifact["deterministic_result_hash"], scale_summary)
    @test occursin("Real fidelity-0 candidates: 10000", scale_summary)
    @test occursin("Positive-net proxy ledgers: 42", scale_summary)
    @test occursin("Complete five-gate passes: 0", scale_summary)
    @test occursin("1e7", scale_summary) && occursin("not a", scale_summary)
end

@testset "Cross-family five-gate topology discovery" begin
    seeds = load_genomes(SEEDS_PATH)
    contract = default_common_comparison_contract()
    contract_hash = canonical_hash(FusionConceptAI._common_contract_dict(contract))
    @test contract_hash == "f12ad6f273265d8183c40abe8e09c1be0fc61ec99eb399b2240d3697615c144d"
    @test contract.plasma_field_T == 4.0
    @test contract.robustness_samples == 64
    @test contract.magnet_material_envelope ==
        "generic_superconducting_winding_screen_v1_no_critical_surface"

    baselines = FusionConceptAI._common_baseline_genomes(seeds)
    @test Set(getfield.(baselines, :family)) ==
        Set(["tokamak_axisymmetric", "stellarator", "magnetic_mirror"])
    evaluator = UnifiedCrossFamilyScreenV1(contract)
    for genome in baselines
        @test evaluator_applicability(evaluator, genome)[1]
        first_result = FusionConceptAI._unified_screen_result(evaluator, genome)
        second_result = FusionConceptAI._unified_screen_result(evaluator, genome)
        @test canonical_hash(first_result) == canonical_hash(second_result)
        @test first_result["contract_hash"] == contract_hash
        @test length(first_result["gates"]) == 5
        @test first_result["classification"] in
            ("temporarily_plausible", "obviously_infeasible_or_unresolved")
        @test all(source -> source.kind == "plasma_current" ||
            source.material == contract.magnet_material_envelope,
            genome.field_sources)
    end

    tokamak_baseline = only(filter(genome ->
        genome.family == "tokamak_axisymmetric", baselines))
    tokamak_features = FusionConceptAI._topology_features(tokamak_baseline)
    @test tokamak_features.three_d_fraction == 0.0
    @test tokamak_features.internal_coil_fraction == 0.0
    @test tokamak_features.plug_strength == 0.0
    @test tokamak_features.minimum_b_strength == 0.0
    corrupted_tf_raw = deepcopy(tokamak_baseline.normalized)
    tf_index = findfirst(source -> occursin("toroidal_field",
        String(source["kind"])), corrupted_tf_raw["field_sources"])
    corrupted_tf_raw["field_sources"][tf_index]["parameters"][
        "on_axis_field"]["value"] = 8.0
    corrupted_tf = parse_genome(corrupted_tf_raw)
    corrupted_tf_result = FusionConceptAI._unified_screen_result(evaluator, corrupted_tf)
    @test corrupted_tf_result["gates"]["variable_topology_representation"] === false
    @test occursin("inconsistent", corrupted_tf_result["topology_gate_reason"])

    rules = discovery_graph_rules_v2()
    @test Set(["common_envelope_parameter_resample",
        "closed_open_mirror_exhaust_hybrid", "internal_levitated_anchor"]) <=
        Set(getfield.(rules, :id))
    @test !("tokamak_demountable_high_field" in Set(getfield.(rules, :id)))
    known = known_source_ids(joinpath(PROJECT_ROOT, "knowledge", "sources.json"))
    families = default_family_registry()
    rng = MersenneTwister(20260811)
    hybrid_rule = only(filter(rule ->
        rule.id == "closed_open_mirror_exhaust_hybrid", rules))
    stellarator = only(filter(genome -> genome.family == "stellarator", seeds))
    hybrid = apply_rule(hybrid_rule, stellarator, rng)
    @test hybrid.family == "closed_open_hybrid"
    @test hybrid.topology.field_line_class == "mixed"
    @test count(connection -> connection.kind == "open_field_line",
        hybrid.flux_connections) == 2
    @test validate_family(families, hybrid).valid
    @test isempty(source_reference_errors(hybrid, known))

    external_rule = only(filter(rule ->
        rule.id == "tokamak_external_transform", rules))
    synchronized_external = FusionConceptAI._synchronize_common_envelope(
        apply_rule(external_rule, tokamak_baseline, MersenneTwister(31)), contract)
    synchronized_external_features =
        FusionConceptAI._topology_features(synchronized_external)
    external_source = only(filter(source ->
        occursin("three_dimensional", source.kind),
        synchronized_external.field_sources))
    @test external_source.parameters["external_transform_fraction_gene"].value ≈
        synchronized_external_features.external_transform_fraction
    @test synchronized_external.mission.targets[
        "screen_external_transform_fraction"].value ≈
        synchronized_external_features.external_transform_fraction
    corrupted_external_raw = deepcopy(synchronized_external.normalized)
    external_index = findfirst(source -> occursin("three_dimensional",
        String(source["kind"])), corrupted_external_raw["field_sources"])
    corrupted_external_raw["field_sources"][external_index]["parameters"][
        "external_transform_fraction_gene"]["value"] = 0.99
    corrupted_external = parse_genome(corrupted_external_raw)
    corrupted_external_result =
        FusionConceptAI._unified_screen_result(evaluator, corrupted_external)
    @test corrupted_external_result["gates"][
        "variable_topology_representation"] === false
    @test occursin("inconsistent", corrupted_external_result[
        "topology_gate_reason"])

    first_search = run_five_gate_qd(seeds; iterations = 100, random_seed = 17)
    second_search = run_five_gate_qd(seeds; iterations = 100, random_seed = 17)
    first_dict = five_gate_search_to_dict(first_search)
    second_dict = five_gate_search_to_dict(second_search)
    @test canonical_hash(first_dict) == canonical_hash(second_dict)
    @test first_dict["archive_cell_count"] >= 50
    @test first_dict["five_gate_pass_count"] >= 1
    @test first_dict["prototype_count"] >= 1
    @test first_dict["topology_doe_anchor_count"] == 80
    @test first_dict["background_evidence_policy"]["blocking_for_search"] === false
    @test all(record -> record["promotion"]["status"] ==
        "queued_not_yet_validated", first_dict["prototypes"])
    @test all(record -> record["evaluation"]["all_five_gates_passed"] === true,
        first_dict["prototypes"])
    @test all(record -> record["evaluation"]["robustness"]["pass_fraction"] >=
        contract.robustness_required_pass_fraction, first_dict["prototypes"])

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(CROSS_FAMILY_FIVE_GATE_ARTIFACT_PATH, String), Dict{String,Any}))
    @test artifact["result_hash"] ==
        "5cdc3e7be243ce2fb67c1321e022f67b5b414566414c1c4ecf88d2b35e663fa9"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    @test artifact["contract_hash"] == contract_hash
    @test artifact["iterations"] == 10000
    @test artifact["discovered_unique_count"] == 9348
    @test artifact["archive_cell_count"] == 216
    @test artifact["five_gate_pass_count"] == 45
    @test artifact["prototype_count"] == 2
    @test artifact["novel_prototype_count"] == 1
    @test artifact["common_doe_anchor_count"] == 24
    @test artifact["topology_doe_anchor_count"] == 80
    @test all(record -> record["evaluation"]["all_five_gates_passed"] === true,
        artifact["prototypes"])
    @test all(record -> record["promotion"]["status"] ==
        "queued_not_yet_validated", artifact["prototypes"])
    @test all(record -> record["evaluation"]["robustness"]["pass_fraction"] >=
        contract.robustness_required_pass_fraction, artifact["prototypes"])
    @test count(record -> record["novel_topology_candidate"] === true,
        artifact["prototypes"]) == 1
    @test !any(record -> record["family"] == "closed_open_hybrid",
        artifact["prototypes"])
    @test any(record -> record["family"] == "magnetic_mirror",
        artifact["prototypes"])
    @test any(record -> "minimal_engineering_closure" in record["failed_gates"],
        artifact["near_frontier_rejections"])
    @test artifact["background_evidence_policy"]["blocking_for_search"] === false
    @test isfile(CROSS_FAMILY_FIVE_GATE_SUMMARY_PATH)
    source_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "source_catalog" => joinpath(PROJECT_ROOT, "knowledge", "sources.json"),
        "schema" => joinpath(PROJECT_ROOT, "schemas", "confinement_genome.schema.json"),
        "unified_evaluator" => joinpath(PROJECT_ROOT, "src", "adapters",
            "unified_cross_family_screen_v1.jl"),
        "topology_grammar" => joinpath(PROJECT_ROOT, "src", "search",
            "grammar.jl"),
        "discovery_search" => joinpath(PROJECT_ROOT, "src", "search",
            "five_gate_discovery.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_cross_family_five_gate_search.jl"),
    )
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end

    novel_record = only(filter(record ->
        record["novel_topology_candidate"] === true, artifact["prototypes"]))
    novel_genome = parse_genome(novel_record["genome"])
    orbit_adapter = MirrorReducedOrbitReviewV1()
    orbit_spec = evaluator_spec(orbit_adapter)
    @test orbit_spec.fidelity == 1
    @test orbit_spec.claim_ceiling == "physics_proxy"
    @test evaluator_applicability(orbit_adapter, novel_genome)[1]
    orbit_registry = EvaluatorRegistry()
    register!(orbit_registry, orbit_adapter)
    first_orbit = evaluate_design(orbit_registry, orbit_spec.id, novel_genome)
    second_orbit = evaluate_design(orbit_registry, orbit_spec.id, novel_genome)
    @test first_orbit.status == :pass
    @test first_orbit.run_hash == second_orbit.run_hash ==
        "d32260f70c6eef63c381ac6b242715b03ea347bedd0826a97a75fb2b6910e87c"
    orbit_metrics = Dict(metric.metric_id => metric for metric in first_orbit.metrics)
    @test orbit_metrics["magnetic_only_prompt_loss_fraction"].value ≈
        0.1055908203125 rtol = 1.0e-14
    @test orbit_metrics["analytic_loss_cone_fraction"].value ≈
        0.10557280900008414 rtol = 1.0e-14
    @test orbit_metrics["guiding_center_scale_ratio"].value ≈
        0.0033298285623461613 rtol = 1.0e-14
    @test orbit_metrics["reduced_mid_fidelity_disposition"].value ==
        "provisional_advance_with_blocking_unknowns"
    @test orbit_metrics["fokker_planck_end_loss_feasible"].status == :unknown
    @test orbit_metrics["electrostatic_plug_potential_self_consistent"].status ==
        :unknown

    failed_horizontal_raw = deepcopy(novel_genome.normalized)
    failed_horizontal_raw["mission"]["targets"]["screen_beta"]["value"] = 0.30
    failed_horizontal = parse_genome(failed_horizontal_raw)
    @test !evaluator_applicability(orbit_adapter, failed_horizontal)[1]

    mid_artifact = FusionConceptAI._plain_json(JSON3.read(
        read(CROSS_FAMILY_MID_FIDELITY_ARTIFACT_PATH, String), Dict{String,Any}))
    @test mid_artifact["result_hash"] ==
        "ac1e39df771895c74744095ed90be4f7f55d8e5ddaea913734a0c13cd1c09cb0"
    mid_without_hash = deepcopy(mid_artifact)
    delete!(mid_without_hash, "result_hash")
    @test canonical_hash(mid_without_hash) == mid_artifact["result_hash"]
    @test mid_artifact["source_search_result_hash"] == artifact["result_hash"]
    @test mid_artifact["reviewed_count"] == 2
    @test mid_artifact["solver_executed_count"] == 1
    @test mid_artifact["provisional_advance_count"] == 1
    @test mid_artifact["insufficient_geometry_count"] == 1
    mirror_review = only(filter(record -> record["family"] == "magnetic_mirror",
        mid_artifact["reviews"]))
    @test mirror_review["admission_status"] ==
        "provisional_advance_with_blocking_unknowns"
    @test mirror_review["evaluation"]["status"] == "pass"
    tokamak_review = only(filter(record ->
        record["family"] == "tokamak_axisymmetric", mid_artifact["reviews"]))
    @test tokamak_review["admission_status"] ==
        "insufficient_explicit_geometry_before_solver"
    @test tokamak_review["solver_executed"] === false
    @test isfile(CROSS_FAMILY_MID_FIDELITY_SUMMARY_PATH)
    mid_source_paths = Dict(
        "five_gate_artifact" => CROSS_FAMILY_FIVE_GATE_ARTIFACT_PATH,
        "mirror_reduced_orbit_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mirror_reduced_orbit_review_v1.jl"),
        "freegs_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "tokamak_freegs_v1.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_cross_family_mid_fidelity_review.jl"),
    )
    for (key, path) in mid_source_paths
        @test mid_artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end

    finite_adapter = MirrorFiniteCoilGeometryV1()
    finite_spec = evaluator_spec(finite_adapter)
    @test finite_spec.id == "mirror_finite_coil_geometry_v1"
    @test finite_spec.fidelity == 1
    @test finite_spec.claim_ceiling == "physics_proxy"
    @test finite_spec.requirement_support["line_current_geometry"] == :full
    @test finite_spec.requirement_support["finite_build_coils"] == :proxy
    @test evaluator_applicability(finite_adapter, novel_genome)[1]

    # The four alternating bars and half-current end arcs form a true
    # quadrupole: the field vanishes on axis but has opposite transverse
    # gradients off axis.  This is a fast regression of the explicit 3D
    # Biot-Savart construction, independent of the stored formal run.
    cage = FusionConceptAI._mf_cage_segments(3.0, -2.0, 2.0, 1.0e6,
        96, "test_cage")
    cage_axis = FusionConceptAI._mf_field((0.0, 0.0, 0.0), cage)
    cage_x = FusionConceptAI._mf_field((0.1, 0.0, 0.0), cage)
    cage_y = FusionConceptAI._mf_field((0.0, 0.1, 0.0), cage)
    @test sqrt(sum(component^2 for component in cage_axis)) < 1.0e-12
    @test cage_x[2] ≈ cage_y[1] rtol = 1.0e-10
    @test abs(cage_x[2]) > 1.0e-4

    loop_radius = 3.2
    loop_z = 1.7
    loop_current = 2.0e6
    loop_segments = vcat(
        FusionConceptAI._mf_circle_segments(loop_radius, -loop_z,
            loop_current, 384, "minus"),
        FusionConceptAI._mf_circle_segments(loop_radius, loop_z,
            loop_current, 384, "plus"))
    numeric_axis = FusionConceptAI._mf_field((0.0, 0.0, 0.4),
        loop_segments)[3] / loop_current
    analytic_axis = FusionConceptAI._mf_axis_basis_T_per_A(0.4, loop_z,
        loop_radius)
    @test numeric_axis ≈ analytic_axis rtol = 5.0e-5

    finite_artifact = FusionConceptAI._plain_json(JSON3.read(
        read(MIRROR_FINITE_COIL_ARTIFACT_PATH, String), Dict{String,Any}))
    @test finite_artifact["result_hash"] ==
        "92006b2260947357aa76b8e7374d6250a5e69c623db98d69c9e5ea5e0bd622a0"
    finite_without_hash = deepcopy(finite_artifact)
    delete!(finite_without_hash, "result_hash")
    @test canonical_hash(finite_without_hash) == finite_artifact["result_hash"]
    @test finite_artifact["input_search_result_hash"] == artifact["result_hash"]
    @test finite_artifact["design_id"] == novel_genome.design_id
    @test finite_artifact["evaluation"]["status"] == "fail"
    @test finite_artifact["evaluation"]["run_hash"] ==
        "2c0b03f88723e3b8091c0279e96044cf8219bd52f410f2e0422d25a98ae73094"
    @test finite_artifact["admission_status"] ==
        "rejected_before_anisotropic_equilibrium"
    finite_metric = only(filter(metric -> metric["metric_id"] ==
        "finite_coil_geometry_summary", finite_artifact["evaluation"]["metrics"]))
    finite_summary = finite_metric["value"]
    @test finite_summary["gates"]["axis_field_and_mirror_ratio"] === true
    @test finite_summary["gates"]["transverse_minimum_b_well"] === true
    @test finite_summary["gates"]["biot_savart_resolution_audit"] === true
    @test finite_summary["gates"]["finite_build_peak_field"] === false
    @test finite_summary["gates"]["open_field_line_integrity"] === false
    @test finite_summary["gates"]["membrane_support_stress_proxy"] === false
    @test finite_summary["axis_system"]["center_field_T"] ≈
        4.005249450064014 rtol = 1.0e-14
    @test finite_summary["axis_system"]["achieved_mirror_ratio"] ≈
        4.949838250808133 rtol = 1.0e-14
    @test finite_summary["quadrupole_system"]["end_bar_current_A"] == 5.0e7
    @test finite_summary["quadrupole_system"][
        "end_high_fraction_of_half_length"] == 0.88
    @test finite_summary["finite_build"]["refined_peak_field"][
        "peak_field_T"] ≈ 102.77775841445877 rtol = 1.0e-14
    @test finite_summary["finite_build"][
        "peak_field_resolution_change_fraction"] <= 0.08
    @test finite_summary["finite_build"]["maximum_current_density_A_m2"] <=
        5.0e8
    @test finite_summary["field_line_audit"][
        "maximum_normalized_flux_tube_radius"] > 1.0
    @test isfile(MIRROR_FINITE_COIL_SUMMARY_PATH)
    finite_source_paths = Dict(
        "five_gate_artifact" => CROSS_FAMILY_FIVE_GATE_ARTIFACT_PATH,
        "finite_coil_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mirror_finite_coil_geometry_v1.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_mirror_finite_coil_geometry_review.jl"),
    )
    for (key, path) in finite_source_paths
        @test finite_artifact["source_hashes"][key] ==
            bytes2hex(sha256(read(path)))
    end

    feedback_config = MirrorGeometryFeedbackConfig()
    @test feedback_config.random_starts == 32
    @test feedback_config.segment_count == 64
    @test feedback_config.pack_grid == 5
    @test_throws ArgumentError MirrorGeometryFeedbackConfig(random_starts = 15)
    @test_throws ArgumentError MirrorGeometryFeedbackConfig(segment_count = 23)
    @test_throws ArgumentError MirrorGeometryFeedbackConfig(pack_grid = 4)
    synthetic_preview = Dict{String,Any}(
        "status" => "rankable_preview",
        "physics_hash" => "abc",
        "preview_failed_gate_count" => 2,
        "preview_peak_field_T" => 40.0,
        "positive_normalized_violations" => Dict("a" => 1.0, "b" => 3.0),
    )
    @test mirror_geometry_feedback_rank_key(synthetic_preview) ==
        (2, 3.0, 4.0, 40.0, "abc")

    feedback_artifact = FusionConceptAI._plain_json(JSON3.read(
        read(MIRROR_GEOMETRY_FEEDBACK_ARTIFACT_PATH, String),
        Dict{String,Any}))
    @test feedback_artifact["result_hash"] ==
        "04a501e6af7aebd69876f5d63bbed2cea3bae79cce32d948508fe7abed37ec40"
    feedback_without_hash = deepcopy(feedback_artifact)
    delete!(feedback_without_hash, "result_hash")
    @test canonical_hash(feedback_without_hash) == feedback_artifact["result_hash"]
    @test feedback_artifact["input_search_result_hash"] == artifact["result_hash"]
    @test feedback_artifact["input_negative_control_result_hash"] ==
        finite_artifact["result_hash"]
    @test feedback_artifact["candidate_count"] == 8
    @test feedback_artifact["rankable_preview_count"] == 5
    @test feedback_artifact["inapplicable_count"] == 3
    @test feedback_artifact["new_full_evaluation_count"] == 2
    @test feedback_artifact["new_full_geometry_pass_count"] == 0
    @test Set(feedback_artifact["shortlisted_design_ids"]) == Set([
        "concept_7e2763fb195d90ba7d9c",
        "concept_b85fc5863b8cd715a093",
    ])
    @test length(feedback_artifact["full_results"]) == 3
    improved = only(filter(result -> result["design_id"] ==
        "concept_7e2763fb195d90ba7d9c", feedback_artifact["full_results"]))
    @test improved["all_geometry_gates_passed"] === false
    @test improved["refined_peak_field_T"] ≈ 62.567390999908 rtol = 1.0e-14
    @test improved["maximum_normalized_flux_tube_radius"] < 0.95
    @test Set(improved["failed_gates"]) == Set([
        "finite_build_peak_field", "membrane_support_stress_proxy"])
    ratio_four = only(filter(result -> result["design_id"] ==
        "concept_b85fc5863b8cd715a093", feedback_artifact["full_results"]))
    @test ratio_four["refined_peak_field_T"] ≈ 69.7823643042229 rtol = 1.0e-14
    @test ratio_four["maximum_normalized_flux_tube_radius"] > 7.0
    @test feedback_artifact["preview_negative_control_audit"]["sample_count"] == 1
    @test occursin("no fitted correction",
        feedback_artifact["preview_negative_control_audit"]["use"])
    @test feedback_artifact["next_action"] ==
        "add_alternative_mirror_coil_grammar_and_feed_failure_coordinates_to_cross_family_acquisition"
    @test isfile(MIRROR_GEOMETRY_FEEDBACK_SUMMARY_PATH)
    feedback_source_paths = Dict(
        "five_gate_artifact" => CROSS_FAMILY_FIVE_GATE_ARTIFACT_PATH,
        "negative_control_artifact" => MIRROR_FINITE_COIL_ARTIFACT_PATH,
        "seed_devices" => SEEDS_PATH,
        "finite_coil_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mirror_finite_coil_geometry_v1.jl"),
        "geometry_feedback_search" => joinpath(PROJECT_ROOT, "src", "search",
            "mirror_geometry_feedback.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_mirror_geometry_feedback_batch.jl"),
    )
    for (key, path) in feedback_source_paths
        @test feedback_artifact["source_hashes"][key] ==
            bytes2hex(sha256(read(path)))
    end

    tokamak_parent_record = only(filter(record ->
        record["family"] == "tokamak_axisymmetric", artifact["prototypes"]))
    tokamak_parent = parse_genome(tokamak_parent_record["genome"])
    pf8_spec = TokamakPFShapeBuildSpec(layout = "symmetric_8",
        xpoint_radial_shift_fraction = 0.15,
        xpoint_vertical_scale = 1.10, grid_size = 33)
    pf8_child = build_tokamak_pf_shape_genome(tokamak_parent, pf8_spec)
    @test pf8_child.design_id != tokamak_parent.design_id
    @test pf8_child.provenance.parent_design_ids == [tokamak_parent.design_id]
    @test count(source -> source.kind == "poloidal_field_coil",
        pf8_child.field_sources) == 8
    @test geometry_topology_v2_descriptor(pf8_child) ==
        "tokamak_axisymmetric|pf8|A=3.8"
    @test geometry_topology_v2_route(pf8_child)["task_id"] ==
        "tokamak_free_boundary_freegs_v1"
    @test geometry_topology_v2_route(pf8_child)["applicable"] === true
    @test FusionConceptAI._unified_screen_result(
        UnifiedCrossFamilyScreenV1(), pf8_child)["all_five_gates_passed"] === true
    @test_throws ArgumentError TokamakPFShapeBuildSpec(layout = "asymmetric_7")
    @test_throws ArgumentError TokamakPFShapeBuildSpec(grid_size = 34)

    mirror_layout = "continuous_baseball_seam_pair"
    mirror_child = build_mirror_coil_topology_genome(novel_genome,
        MirrorCoilTopologyBuildSpec(layout = mirror_layout))
    minimum_b_sources = filter(source -> source.kind == "minimum_b_coil",
        mirror_child.field_sources)
    @test length(minimum_b_sources) == 1
    @test only(minimum_b_sources).geometry_model == mirror_layout
    @test mirror_child.provenance.parent_design_ids == [novel_genome.design_id]
    @test occursin(mirror_layout,
        geometry_topology_v2_descriptor(mirror_child))
    mirror_route = geometry_topology_v2_route(mirror_child)
    @test mirror_route["task_id"] ==
        "mirror_continuous_baseball_seam_pair_vacuum_geometry_v1"
    @test mirror_route["backend_status"] == "planned"
    @test mirror_route["applicable"] === false
    @test occursin("cage-only evidence is forbidden", mirror_route["reason"])
    @test FusionConceptAI._unified_screen_result(
        UnifiedCrossFamilyScreenV1(), mirror_child)["all_five_gates_passed"] === true
    @test_throws ArgumentError MirrorCoilTopologyBuildSpec(layout = "generic")

    geometry_artifact = FusionConceptAI._plain_json(JSON3.read(
        read(CROSS_FAMILY_GEOMETRY_TOPOLOGY_V2_ARTIFACT_PATH, String),
        Dict{String,Any}))
    @test geometry_artifact["result_hash"] ==
        "8fa4596bf188ee8f9c4c32739338bb45ff449abd4bdf6aa7d6a39ba7da925653"
    geometry_without_hash = deepcopy(geometry_artifact)
    delete!(geometry_without_hash, "result_hash")
    @test canonical_hash(geometry_without_hash) == geometry_artifact["result_hash"]
    @test geometry_artifact["input_search_result_hash"] == artifact["result_hash"]
    @test geometry_artifact["input_mirror_feedback_result_hash"] ==
        feedback_artifact["result_hash"]
    @test geometry_artifact["tokamak"]["coarse_candidate_count"] == 8
    @test geometry_artifact["tokamak"]["full_candidate_count"] == 2
    @test geometry_artifact["tokamak"]["full_review_pass_count"] == 1
    @test geometry_artifact["mirror"]["parent_survivor_count"] == 8
    @test geometry_artifact["mirror"]["proposal_count"] == 24
    @test geometry_artifact["mirror"]["five_gate_pass_count"] == 24
    @test geometry_artifact["mirror"]["archive_cell_count"] == 12
    @test Set(geometry_artifact["mirror"]["geometry_layouts"]) == Set([
        "split_ioffe_saddle_pair", "continuous_baseball_seam_pair",
        "yin_yang_end_anchor_pair"])
    @test length(geometry_artifact["mirror"]["promoted"]) == 3
    @test all(record -> record["route"]["backend_status"] == "planned" &&
        record["route"]["applicable"] === false,
        geometry_artifact["mirror"]["promoted"])
    full_records = geometry_artifact["tokamak"]["full_records"]
    @test all(record -> record["evaluation"]["status"] == "pass", full_records)
    @test Set(record["design_id"] for record in full_records) == Set([
        "concept_a2ab3901cdff8406cdb6",
        "concept_601274ce60edfb7b89eb"])
    review_pass = only(filter(record ->
        record["review"]["all_review_gates_passed"] === true, full_records))
    @test review_pass["design_id"] == "concept_601274ce60edfb7b89eb"
    @test isempty(review_pass["review"]["failed_gates"])
    review_fail = only(filter(record ->
        record["review"]["all_review_gates_passed"] === false, full_records))
    @test review_fail["review"]["failed_gates"] ==
        ["minor_radius_alignment"]
    gs_metric = only(filter(metric -> metric["metric_id"] ==
        "grad_shafranov_residual_l2_relative",
        review_pass["evaluation"]["metrics"]))
    @test gs_metric["value"] ≈ 0.00592378569977249 rtol = 1.0e-14
    @test isfile(CROSS_FAMILY_GEOMETRY_TOPOLOGY_V2_SUMMARY_PATH)
    geometry_source_paths = Dict(
        "five_gate_artifact" => CROSS_FAMILY_FIVE_GATE_ARTIFACT_PATH,
        "mirror_feedback_artifact" => MIRROR_GEOMETRY_FEEDBACK_ARTIFACT_PATH,
        "seed_devices" => SEEDS_PATH,
        "geometry_topology_source" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_family_geometry_topology_v2.jl"),
        "freegs_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "tokamak_freegs_v1.jl"),
        "freegs_runner" => joinpath(PROJECT_ROOT, "scripts", "freegs_runner.py"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_cross_family_geometry_topology_v2.jl"),
    )
    for (key, path) in geometry_source_paths
        @test geometry_artifact["source_hashes"][key] ==
            bytes2hex(sha256(read(path)))
    end

    # Each v2 mirror family now has a distinct executable closed-current-path
    # adapter. Applicability is exact-layout, so no result can leak across a
    # different field-source geometry model.
    mirror_promoted = Dict(String(record["spec"]["layout"]) =>
        parse_genome(record["genome"])
        for record in geometry_artifact["mirror"]["promoted"])
    layouts = ("split_ioffe_saddle_pair",
        "continuous_baseball_seam_pair", "yin_yang_end_anchor_pair")
    for layout in layouts
        adapter = MirrorLayoutVacuumGeometryV1(layout)
        spec = evaluator_spec(adapter)
        @test spec.id == "mirror_$(layout)_vacuum_geometry_v1"
        @test spec.version == "1.0.0"
        @test spec.claim_ceiling == "physics_proxy"
        @test evaluator_applicability(adapter, mirror_promoted[layout])[1]
        other_layout = only(filter(!=(layout), collect(layouts))[1:1])
        @test !evaluator_applicability(adapter, mirror_promoted[other_layout])[1]

        segments = FusionConceptAI._mlv_layout_segments(layout, 3, 0.86,
            3.0, 3.4, 6.2, 0.17, 1.0e6, 32)
        @test !isempty(segments)
        groups = Dict{String,Vector{FusionConceptAI._MFSegment}}()
        for segment in segments
            push!(get!(groups, segment.group_id,
                FusionConceptAI._MFSegment[]), segment)
        end
        for group in values(groups)
            @test first(group).p1 == last(group).p2
            @test all(group[index].p2 == group[index + 1].p1
                for index in 1:(length(group) - 1))
        end
    end
    @test_throws ArgumentError MirrorLayoutVacuumGeometryV1("generic")

    tokamak_pass = only(filter(record ->
        record["review"]["all_review_gates_passed"] === true,
        geometry_artifact["tokamak"]["full_records"]))
    tokamak_robustness = TokamakPFStaticRobustnessV1(FREEGS_PYTHON)
    robustness_spec = evaluator_spec(tokamak_robustness)
    @test robustness_spec.id == "tokamak_pf_static_robustness_v1"
    @test robustness_spec.claim_ceiling == "physics_proxy"
    @test evaluator_applicability(tokamak_robustness,
        parse_genome(tokamak_pass["genome"]))[1]
    @test_throws ArgumentError TokamakPFStaticRobustnessV1(FREEGS_PYTHON;
        coil_offset_m = 0.03)

    failure_artifact = FusionConceptAI._plain_json(JSON3.read(
        read(CROSS_FAMILY_FAILURE_AWARE_ARTIFACT_PATH, String),
        Dict{String,Any}))
    @test failure_artifact["result_hash"] ==
        "bcfecb373c7751a16cdb0f529b10a8f356d7ce3e284f9efca6f91567a09846c4"
    failure_without_hash = deepcopy(failure_artifact)
    delete!(failure_without_hash, "result_hash")
    @test canonical_hash(failure_without_hash) == failure_artifact["result_hash"]
    @test failure_artifact["input_geometry_topology_result_hash"] ==
        geometry_artifact["result_hash"]
    @test failure_artifact["reviewed_candidate_count"] == 4
    @test failure_artifact["terminal_geometry_rejection_count"] == 3
    @test failure_artifact["conditional_advance_count"] == 1
    mirror_failures = filter(record -> record["family"] == "magnetic_mirror",
        failure_artifact["records"])
    @test length(mirror_failures) == 3
    @test all(record -> record["evaluation"]["status"] == "fail",
        mirror_failures)
    @test all(record -> record["admission_status"] ==
        "terminal_geometry_rejection_under_declared_contract", mirror_failures)
    yin_yang = only(filter(record -> record["layout"] ==
        "yin_yang_end_anchor_pair", mirror_failures))
    @test yin_yang["failure_feedback"]["minimum_well_fraction"] > 0.0
    @test yin_yang["failure_feedback"][
        "maximum_normalized_flux_tube_radius"] > 10.0
    tokamak_advance = only(filter(record -> record["family"] ==
        "tokamak_axisymmetric", failure_artifact["records"]))
    @test tokamak_advance["evaluation"]["status"] == "pass"
    @test tokamak_advance["admission_status"] ==
        "eligible_for_dynamic_vertical_and_mhd_review"
    @test tokamak_advance["failure_feedback"][
        "normalized_axis_displacement"] < 0.002
    @test tokamak_advance["failure_feedback"]["pf_current_amplification"] < 1.05
    @test isfile(CROSS_FAMILY_FAILURE_AWARE_SUMMARY_PATH)
    failure_source_paths = Dict(
        "geometry_topology_artifact" =>
            CROSS_FAMILY_GEOMETRY_TOPOLOGY_V2_ARTIFACT_PATH,
        "mirror_layout_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mirror_layout_vacuum_geometry_v1.jl"),
        "tokamak_static_robustness_adapter" => joinpath(PROJECT_ROOT, "src",
            "adapters", "tokamak_pf_static_robustness_v1.jl"),
        "freegs_runner" => joinpath(PROJECT_ROOT, "scripts", "freegs_runner.py"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_cross_family_failure_aware_review.jl"),
    )
    for (key, path) in failure_source_paths
        @test failure_artifact["source_hashes"][key] ==
            bytes2hex(sha256(read(path)))
    end

    repair_spec = HybridRepairTopologySpec(true, true, true)
    repair_child = build_closed_open_hybrid_repair_genome(tokamak_baseline,
        repair_spec)
    repair_features = FusionConceptAI._topology_features(repair_child)
    @test repair_child.family == "closed_open_hybrid"
    @test validate_family(default_family_registry(), repair_child).valid
    @test count(connection -> connection.kind == "open_field_line",
        repair_child.flux_connections) == 4
    @test repair_features.plug_strength >= 0.40
    @test repair_features.minimum_b_strength >= 0.50
    @test repair_features.shear_strength >= 0.40
    @test sum(actuator.parameters["power"].value for actuator in
        repair_child.actuators if startswith(actuator.id, "hybrid_") &&
        haskey(actuator.parameters, "power")) == 6.0e6
    @test isempty(source_reference_errors(repair_child, known))

    small_v3 = run_failure_aware_hybrid_qd(seeds;
        acquisition_samples = 128, maximum_graph_elites = 8)
    @test small_v3["acquisition_samples"] == 128
    @test small_v3["mechanism_count"] == 8
    @test small_v3["explicit_graph_elite_count"] == 8
    @test all(record -> parse_genome(record["genome"]).family ==
        "closed_open_hybrid", small_v3["records"])

    v3_artifact = FusionConceptAI._plain_json(JSON3.read(
        read(CROSS_FAMILY_FAILURE_AWARE_QD_V3_ARTIFACT_PATH, String),
        Dict{String,Any}))
    @test v3_artifact["result_hash"] ==
        "78137bfb0794a7a5f5fce78d6a53fc874158952c42ca836a31547cc294f2b931"
    v3_without_hash = deepcopy(v3_artifact)
    delete!(v3_without_hash, "result_hash")
    @test canonical_hash(v3_without_hash) == v3_artifact["result_hash"]
    v3_search = v3_artifact["hybrid_failure_aware_qd"]
    @test v3_search["acquisition_samples"] == 400000
    @test v3_search["acquisition_archive_cell_count"] == 90
    @test v3_search["nominal_physics_and_engineering_pass_count"] == 2395
    @test v3_search["positive_adjusted_net_power_count"] == 0
    @test v3_search["explicit_graph_elite_count"] == 90
    @test v3_search["explicit_graph_common_five_gate_pass_count"] == 15
    @test v3_search["explicit_graph_power_closure_pass_count"] == 0
    @test all(record -> record["common_five_gate_passed"] === true &&
        record["failure_aware_power_closure_passed"] === false,
        v3_artifact["hybrid_best_five_gate_controls"])
    @test v3_artifact["mirror_axis_share_boundary_probe"][
        "all_layouts_rejected"] === true
    @test all(record -> record["spec"]["axis_field_share"] == 0.95 &&
        record["all_geometry_gates_passed"] === false,
        v3_artifact["mirror_axis_share_boundary_probe"]["records"])
    @test v3_artifact["tokamak_conditional_carry"]["admission_status"] ==
        "eligible_for_dynamic_vertical_and_mhd_review"
    @test v3_artifact["stellarator_nonblocking_background"]["blocking"] === false
    @test isfile(CROSS_FAMILY_FAILURE_AWARE_QD_V3_SUMMARY_PATH)
    v3_source_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "source_catalog" => joinpath(PROJECT_ROOT, "knowledge", "sources.json"),
        "failure_aware_qd_source" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_family_failure_aware_qd_v3.jl"),
        "unified_cross_family_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "unified_cross_family_screen_v1.jl"),
        "mirror_layout_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mirror_layout_vacuum_geometry_v1.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_cross_family_failure_aware_qd_v3.jl"),
        "stellarator_background_stability" => joinpath(PROJECT_ROOT, "runs",
            "stellarator_stability_medium_pilot_20260810.json"),
    )
    for (key, path) in v3_source_paths
        @test v3_artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
end

@testset "Compact-toroid selective-exhaust topology v4" begin
    seeds = load_genomes(SEEDS_PATH)
    parent = only(filter(genome -> genome.family == "tokamak_axisymmetric", seeds))
    known = union(
        known_source_ids(joinpath(PROJECT_ROOT, "knowledge", "sources.json")),
        known_source_ids(joinpath(PROJECT_ROOT, "knowledge",
            "compact_toroid_v4_sources.json")))
    specs = CompactToroidBuildSpec[
        CompactToroidBuildSpec("field_reversed_configuration",
            "beam_driven_fast_ion"),
        CompactToroidBuildSpec("field_reversed_configuration",
            "rotating_magnetic_field"),
        CompactToroidBuildSpec("field_reversed_configuration",
            "beam_plus_end_bias"),
        CompactToroidBuildSpec("spheromak",
            "steady_inductive_helicity_injection"),
        CompactToroidBuildSpec("spheromak",
            "imposed_dynamo_current_drive"),
    ]
    evaluator = CompactToroidScreenV1()
    for spec in specs
        genome = build_compact_toroid_genome(parent, spec)
        @test validate_genome(genome).valid
        @test validate_family(default_family_registry(), genome).valid
        @test isempty(source_reference_errors(genome, known))
        @test genome.topology.field_line_class == "compact_toroid"
        @test count(region -> region.kind == "compact_toroid_closed_core",
            genome.plasma_regions) == 1
        @test count(region -> region.kind == "scrape_off_layer",
            genome.plasma_regions) == 1
        @test count(connection -> connection.kind == "cross_separatrix_transport",
            genome.flux_connections) == 1
        @test count(connection -> connection.kind == "open_field_line",
            genome.flux_connections) == 2
        @test !any(source -> occursin("toroidal_field_coil", source.kind),
            genome.field_sources)
        @test sum(actuator.parameters["power"].value for actuator in
            genome.actuators) > 0.0
        first_result = FusionConceptAI._compact_toroid_screen_result(
            evaluator, genome)
        second_result = FusionConceptAI._compact_toroid_screen_result(
            evaluator, genome)
        @test canonical_hash(first_result) == canonical_hash(second_result)
        @test isempty(first_result["topology_graph_errors"])
        @test length(first_result["gates"]) == 5
        @test first_result["claim_boundary"] ==
            FusionConceptAI._CT_SCREEN_CLAIM_BOUNDARY
    end

    corrupted = build_compact_toroid_genome(parent, specs[1])
    corrupted_raw = deepcopy(corrupted.normalized)
    push!(corrupted_raw["exhaust"]["region_ids"], "ct_closed_core")
    corrupted_result = FusionConceptAI._compact_toroid_screen_result(
        evaluator, parse_genome(corrupted_raw))
    @test corrupted_result["gates"]["variable_topology_representation"] === false
    @test any(contains("closed core cannot be listed"),
        corrupted_result["topology_graph_errors"])

    first_small = run_compact_toroid_edge_qd(seeds;
        acquisition_samples = 128, maximum_graph_elites = 32)
    second_small = run_compact_toroid_edge_qd(seeds;
        acquisition_samples = 128, maximum_graph_elites = 32)
    @test canonical_hash(first_small) == canonical_hash(second_small)
    @test first_small["topology_count"] == 5
    @test first_small["explicit_graph_elite_count"] <= 32
    @test all(record -> isempty(record["evaluation"]["topology_graph_errors"]),
        first_small["records"])
    @test Set(record["family"] for record in first_small["topologies"]) ==
        Set(["field_reversed_configuration", "spheromak"])

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(COMPACT_TOROID_EDGE_QD_V4_ARTIFACT_PATH, String),
        Dict{String,Any}))
    @test artifact["result_hash"] ==
        "695e07e2dcc01561f54b3c1bf2244eeb59d9e45d1f7adaefb003c33d7907b48c"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    search = artifact["compact_toroid_edge_qd"]
    @test search["acquisition_samples"] == 300000
    @test search["acquisition_archive_cell_count"] == 78
    @test search["acquisition_positive_net_count"] == 0
    @test search["acquisition_nominal_physics_and_engineering_pass_count"] == 0
    @test search["explicit_graph_elite_count"] == 78
    @test search["explicit_graph_five_gate_pass_count"] == 0
    @test search["explicit_graph_positive_net_count"] == 0
    @test search["promotion_count"] == 0
    @test length(artifact["near_frontier"]) == 10
    @test all(record -> isempty(record["evaluation"]["topology_graph_errors"]),
        search["records"])
    @test all(record -> record["promoted"] === false, search["records"])
    @test Set((record["family"], record["sustainment"]) for record in
        artifact["near_frontier"]) == Set((record["family"],
        record["sustainment"]) for record in search["topologies"])
    @test isfile(COMPACT_TOROID_EDGE_QD_V4_SUMMARY_PATH)
    source_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "source_catalog" => joinpath(PROJECT_ROOT, "knowledge", "sources.json"),
        "compact_toroid_v4_source_overlay" => joinpath(PROJECT_ROOT,
            "knowledge", "compact_toroid_v4_sources.json"),
        "compact_toroid_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "compact_toroid_screen_v1.jl"),
        "compact_toroid_search" => joinpath(PROJECT_ROOT, "src", "search",
            "compact_toroid_edge_qd_v4.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_compact_toroid_edge_qd_v4.jl"),
    )
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
end

@testset "Shared outer-envelope cross-family topology v5" begin
    seeds = load_genomes(SEEDS_PATH)
    contracts = shared_outer_envelope_contracts_v1()
    @test length(contracts) == 6
    @test length(FusionConceptAI._oev5_topology_specs()) == 22
    structural = FusionConceptAI._oev5_structural_bases(seeds)
    @test length(structural) == 22
    @test all(validate_genome(genome).valid for genome in Base.values(structural))

    contract = only(filter(item -> item.id == "outer_reference_B4_v1",
        contracts))
    spec2 = OuterEnvelopeTopologySpecV5("spheromak",
        "imposed_dynamo_current_drive", 2)
    spec8 = OuterEnvelopeTopologySpecV5("spheromak",
        "imposed_dynamo_current_drive", 8)
    genes = FusionConceptAI._oev5_ranges(spec2, ntuple(_ -> 0.5, 12))
    two_target = FusionConceptAI._oev5_instantiate(
        structural[FusionConceptAI._oev5_key(spec2)], genes, contract)
    eight_target = FusionConceptAI._oev5_instantiate(
        structural[FusionConceptAI._oev5_key(spec8)], genes, contract)
    evaluator = SharedOuterEnvelopeScreenV1(contract;
        allowed_contracts = contracts)
    two_result = FusionConceptAI._shared_outer_envelope_result(evaluator,
        two_target)
    eight_result = FusionConceptAI._shared_outer_envelope_result(evaluator,
        eight_target)
    @test isempty(two_result["topology_graph_errors"])
    @test isempty(eight_result["topology_graph_errors"])
    @test two_result["topology_features"]["shape_ratio"] ==
        eight_result["topology_features"]["shape_ratio"]
    @test two_result["topology_features"]["plasma_fill_fraction"] ==
        eight_result["topology_features"]["plasma_fill_fraction"]
    @test two_result["nominal"]["target_count"] == 2
    @test eight_result["nominal"]["target_count"] == 8
    @test eight_result["nominal"]["geometric_target_area_capacity_m2"] >
        two_result["nominal"]["geometric_target_area_capacity_m2"]
    @test two_result["nominal"]["plasma_minor_radius_m"] <
        contract.outer_radial_extent_m
    @test two_target.mission.targets["screen_outer_radial_extent"].value ==
        contract.outer_radial_extent_m
    @test two_target.mission.targets["screen_outer_axial_half_extent"].value ==
        contract.outer_axial_half_extent_m

    corrupted_raw = deepcopy(two_target.normalized)
    corrupted_raw["mission"]["targets"]["screen_outer_radial_extent"] =
        Dict("value" => contract.outer_radial_extent_m + 1.0, "unit" => "m")
    corrupted_result = FusionConceptAI._shared_outer_envelope_result(evaluator,
        parse_genome(corrupted_raw))
    @test corrupted_result["gates"]["same_outer_envelope_contract"] === true
    @test corrupted_result["gates"]["variable_topology_representation"] === false
    @test any(contains("screen_outer_radial_extent"),
        corrupted_result["topology_graph_errors"])

    first_small = run_shared_outer_envelope_qd_v5(seeds;
        acquisition_samples = 264, maximum_graph_elites = 32,
        elites_per_structural_stratum = 1)
    second_small = run_shared_outer_envelope_qd_v5(seeds;
        acquisition_samples = 264, maximum_graph_elites = 32,
        elites_per_structural_stratum = 1)
    @test canonical_hash(first_small) == canonical_hash(second_small)
    @test first_small["contract_count"] == 6
    @test first_small["topology_count_per_contract"] == 22
    @test first_small["structural_stratum_count"] == 132
    @test first_small["explicit_graph_elite_count"] == 32
    @test all(record -> isempty(record["evaluation"][
        "topology_graph_errors"]), first_small["records"])

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(SHARED_OUTER_ENVELOPE_QD_V5_ARTIFACT_PATH, String),
        Dict{String,Any}))
    @test artifact["result_hash"] ==
        "b787f77671f535cf3f737bc6e00bf787ea74b63f0426f732748edb5062637e90"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    search = artifact["shared_outer_envelope_qd"]
    @test search["acquisition_samples"] == 600000
    @test search["contract_count"] == 6
    @test search["structural_stratum_count"] == 132
    @test search["acquisition_archive_cell_count"] == 765
    @test search["acquisition_positive_net_count"] == 70
    @test search["acquisition_nominal_physics_and_engineering_pass_count"] == 12
    @test search["explicit_graph_elite_count"] == 381
    @test search["explicit_graph_five_gate_pass_count"] == 3
    @test search["explicit_graph_positive_net_count"] == 6
    @test search["promotion_count"] == 3
    promoted = filter(record -> record["promoted"] === true, search["records"])
    @test length(promoted) == 3
    @test all(record -> record["family"] == "tokamak_axisymmetric", promoted)
    @test all(record -> isempty(record["evaluation"][
        "topology_graph_errors"]), search["records"])
    @test all(record -> record["evaluation"]["robustness"]["pass_fraction"] >=
        0.95, promoted)
    @test length(artifact["medium_fidelity_review_queue"]) == 3
    @test isfile(SHARED_OUTER_ENVELOPE_QD_V5_SUMMARY_PATH)
    source_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "sealed_source_catalog" => joinpath(PROJECT_ROOT, "knowledge",
            "sources.json"),
        "compact_toroid_source_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "compact_toroid_v4_sources.json"),
        "outer_envelope_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "shared_outer_envelope_screen_v1.jl"),
        "outer_envelope_search" => joinpath(PROJECT_ROOT, "src", "search",
            "shared_outer_envelope_qd_v5.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_shared_outer_envelope_qd_v5.jl"),
    )
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
end

@testset "Evidence-constrained composable cross-family topology v9" begin
    seeds = load_genomes(SEEDS_PATH)
    contracts = shared_outer_envelope_contracts_v1()
    @test length(FusionConceptAI._ccv9_topology_specs()) == 41
    structural = FusionConceptAI._ccv9_structural_bases(seeds)
    @test length(structural) == 41
    @test all(validate_genome(genome).valid for genome in Base.values(structural))

    @test_throws ArgumentError ComposableTopologySpecV9(
        "magnetic_mirror", "centrifugal_exb_shear", "super_x_long_leg", 2)
    @test_throws ArgumentError ComposableTopologySpecV9(
        "tokamak_axisymmetric", "plasma_current_q_profile",
        "boundary_island_divertor", 4)
    @test_throws ArgumentError ComposableTopologySpecV9(
        "stellarator", "quasi_isodynamic", "boundary_island_divertor", 2)

    contract = only(filter(item -> item.id == "outer_reference_B4_v1",
        contracts))
    hybrid_spec = ComposableTopologySpecV9("tokamak_3d_hybrid",
        "fixed_qa_current", "boundary_island_divertor", 4)
    hybrid_values = FusionConceptAI._ccv9_ranges(hybrid_spec,
        ntuple(_ -> 0.5, 12))
    hybrid = FusionConceptAI._ccv9_instantiate(
        structural[FusionConceptAI._ccv9_key(hybrid_spec)], hybrid_values,
        contract)
    evaluator = ComposableCrossFamilyScreenV1(contract;
        allowed_contracts = contracts)
    hybrid_result = FusionConceptAI._composable_cross_family_result(evaluator,
        hybrid)
    @test isempty(hybrid_result["topology_graph_errors"])
    @test hybrid_result["composition"]["core_family"] == "tokamak_3d_hybrid"
    @test hybrid_result["composition"]["exhaust_topology"] ==
        "boundary_island_divertor"
    @test hybrid_result["nominal"]["experimental_performance_multiplier_used"] === false
    @test hybrid_result["nominal"]["hybrid_proxy_policy"] ==
        "elementwise margin intersection; lower-net confinement branch retained"
    @test hybrid_result["nominal"]["net_electric_power_W"] == min(
        hybrid_result["nominal"]["tokamak_branch"]["net_electric_power_W"],
        hybrid_result["nominal"]["stellarator_branch"]["net_electric_power_W"])

    mirror_spec = ComposableTopologySpecV9("magnetic_mirror",
        "centrifugal_exb_shear", "two_end_expander", 2)
    mirror_values = FusionConceptAI._ccv9_ranges(mirror_spec,
        ntuple(_ -> 0.5, 12))
    mirror = FusionConceptAI._ccv9_instantiate(
        structural[FusionConceptAI._ccv9_key(mirror_spec)], mirror_values,
        contract)
    mirror_result = FusionConceptAI._composable_cross_family_result(evaluator,
        mirror)
    @test isempty(mirror_result["topology_graph_errors"])
    @test mirror_result["nominal"]["centrifugal_confinement_multiplier_cap"] <= 3.0
    @test haskey(mirror_result["nominal"]["margins"],
        "rotation_voltage_authority")
    @test haskey(mirror_result["nominal"]["margins"],
        "rotation_insulation_field")
    corrupted_raw = deepcopy(mirror.normalized)
    delete!(corrupted_raw["mission"]["targets"],
        "screen_rotation_insulation_thickness")
    corrupted = parse_genome(corrupted_raw)
    corrupted_result = FusionConceptAI._composable_cross_family_result(evaluator,
        corrupted)
    @test corrupted_result["gates"][
        "variable_topology_representation_and_compatibility"] === false
    @test any(contains("insulation thickness"),
        corrupted_result["topology_graph_errors"])
    @test FusionConceptAI._ccv9_medium_fidelity_route(
        "tokamak_axisymmetric", "plasma_current_q_profile") ==
        ["free_boundary_grad_shafranov", "pf_static_robustness", "solps_exhaust"]

    first_small = run_composable_cross_family_qd_v9(seeds;
        acquisition_samples = 492, maximum_graph_elites = 64,
        elites_per_structural_stratum = 1)
    second_small = run_composable_cross_family_qd_v9(seeds;
        acquisition_samples = 492, maximum_graph_elites = 64,
        elites_per_structural_stratum = 1)
    @test canonical_hash(first_small) == canonical_hash(second_small)
    @test first_small["contract_count"] == 6
    @test first_small["topology_count_per_contract"] == 41
    @test first_small["structural_stratum_count"] == 246
    @test first_small["explicit_graph_elite_count"] == 64
    @test all(record -> isempty(record["evaluation"][
        "topology_graph_errors"]), first_small["records"])
    @test Set(record["core_family"] for record in first_small["records"]) ==
        Set(["tokamak_axisymmetric", "tokamak_3d_hybrid", "stellarator",
            "magnetic_mirror", "field_reversed_configuration", "spheromak"])

    artifact_path = joinpath(PROJECT_ROOT, "runs",
        "composable_cross_family_qd_v9_20260813.json")
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(artifact_path, String), Dict{String,Any}))
    @test artifact["result_hash"] ==
        "f1e71e6e548aa4962dfb8c47f3178fbb09b817988c7edba1347c9911e5dfe1b6"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    search = artifact["composable_cross_family_qd"]
    @test search["acquisition_samples"] == 300000
    @test search["topology_count_per_contract"] == 41
    @test search["structural_stratum_count"] == 246
    @test search["acquisition_archive_cell_count"] == 1793
    @test search["acquisition_positive_net_count"] == 197
    @test search["acquisition_nominal_physics_and_engineering_pass_count"] == 69
    @test search["explicit_graph_elite_count"] == 492
    @test search["explicit_graph_five_gate_pass_count"] == 6
    @test search["promotion_count"] == 6
    @test length(artifact["medium_fidelity_review_queue"]) == 6
    @test all(item -> item["route"] isa AbstractVector,
        artifact["medium_fidelity_review_queue"])
    @test length(artifact["paired_exhaust_ab_checks"]) == 1
    @test artifact["paired_exhaust_ab_checks"][1][
        "candidate_dominates_paired_baseline_on_net_and_exhaust"] === false
    v9_source_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "sealed_source_catalog" => joinpath(PROJECT_ROOT, "knowledge",
            "sources.json"),
        "composable_source_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "composable_cross_family_v9_sources.json"),
        "sealed_outer_envelope_screen" => joinpath(PROJECT_ROOT, "src",
            "adapters", "shared_outer_envelope_screen_v1.jl"),
        "composable_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "composable_cross_family_screen_v1.jl"),
        "composable_search" => joinpath(PROJECT_ROOT, "src", "search",
            "composable_cross_family_qd_v9.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_composable_cross_family_qd_v9.jl"))
    for (key, path) in v9_source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
end

@testset "V9 promoted tokamak survivor FreeGS rejection review" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(V9_TOKAMAK_FREEGS_REVIEW_PATH, String), Dict{String,Any}))
    @test artifact["result_hash"] ==
        "41b8341e19f440e58a75320a1f53d9da281086a5c27d9c00c96710b61cc0caa4"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    @test artifact["input_v9_result_hash"] ==
        "f1e71e6e548aa4962dfb8c47f3178fbb09b817988c7edba1347c9911e5dfe1b6"
    @test artifact["parent_count"] == 6
    @test artifact["coarse_solve_count"] == 48
    @test artifact["coarse_completed_count"] == 48
    @test artifact["refined_solve_count"] == 12
    @test artifact["refined_completed_count"] == 11
    @test artifact["resolution_pass_count"] == 11
    @test artifact["qualified_count"] == 0

    selected = artifact["selected_refinements"]
    completed = filter(item -> item["refined"]["status"] == "completed",
        selected)
    @test length(selected) == 12
    @test length(completed) == 11
    @test count(item -> item["exhaust_topology"] == "super_x_long_leg",
        selected) == 2
    @test all(item -> item["resolution_audit"][
        "all_resolution_gates_passed"] === true, completed)
    @test all(item -> item["resolution_audit"][
        "qualified_for_next_evidence"] === false, selected)
    @test all(item -> !isempty(item["refined"]["review"]["failed_gates"]),
        completed)
    failed_gates = reduce(vcat,
        [String.(item["refined"]["review"]["failed_gates"])
            for item in completed])
    @test count(==("pf_membrane_support_stress_proxy"), failed_gates) == 9
    @test count(==("pf_additive_peak_field_proxy"), failed_gates) == 8
    @test count(==("elongation_alignment"), failed_gates) == 8
    @test occursin("Super-X SOL transport", artifact["claim_boundary"])

    source_paths = Dict(
        "input_v9" => joinpath(PROJECT_ROOT, "runs",
            "composable_cross_family_qd_v9_20260813.json"),
        "geometry_builder" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_family_geometry_topology_v2.jl"),
        "freegs_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "tokamak_freegs_v1.jl"),
        "freegs_runner" => joinpath(PROJECT_ROOT, "scripts", "freegs_runner.py"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_v9_tokamak_freegs_review.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    @test isfile(V9_TOKAMAK_FREEGS_REVIEW_SUMMARY_PATH)
end

@testset "Mechanism-expansion cross-family QD v10" begin
    seeds = load_genomes(SEEDS_PATH)
    specs = FusionConceptAI._mev10_topology_specs()
    @test length(specs) == 49
    @test count(FusionConceptAI._mev10_is_control, specs) == 41
    @test count(spec -> !FusionConceptAI._mev10_is_control(spec), specs) == 8
    @test count(spec -> spec.core_family == "sheared_flow_z_pinch", specs) == 2
    @test count(spec -> spec.core_family == "magnetic_mirror" &&
        !FusionConceptAI._mev10_is_control(spec), specs) == 6

    structural = FusionConceptAI._mev10_structural_bases(seeds)
    @test length(structural) == 49
    contract = only(filter(item -> item.id == "outer_reference_B4_v1",
        shared_outer_envelope_contracts_v1()))
    u = ntuple(_ -> 0.5, 18)

    tandem_spec = only(filter(spec -> spec.mechanism ==
        "thermal_barrier_plus_kinetic" &&
        spec.exhaust_topology == "two_end_direct_converter", specs))
    tandem_values = FusionConceptAI._mev10_ranges(tandem_spec, u)
    tandem = FusionConceptAI._mev10_instantiate(
        structural[FusionConceptAI._mev10_key(tandem_spec)], tandem_spec,
        tandem_values, contract)
    @test validate_genome(tandem).valid
    tandem_result = FusionConceptAI._mechanism_expansion_result(
        MechanismExpansionScreenV1(contract), tandem)
    @test isempty(tandem_result["topology_graph_errors"])
    tandem_nominal = tandem_result["nominal"]
    @test tandem_nominal["experimental_performance_multiplier_used"] === false
    @test tandem_nominal["direct_converter_recovery_fraction"] <= 0.50
    @test tandem_nominal["direct_converter_recovered_electric_power_W"] <=
        tandem_nominal["charged_end_loss_power_W"]
    @test tandem_nominal["charged_actuator_power_W"] >=
        tandem_nominal["explicit_mechanism_actuator_requirement_W"]
    @test haskey(tandem_nominal["margins"],
        "tandem_trapped_particle_screen")
    @test haskey(tandem_nominal["margins"],
        "kinetic_stabilizer_replenishment")

    z_spec = only(filter(spec -> spec.mechanism ==
        "sheared_flow_repetitive_z_pinch", specs))
    z_values = FusionConceptAI._mev10_ranges(z_spec, u)
    z = FusionConceptAI._mev10_instantiate(
        structural[FusionConceptAI._mev10_key(z_spec)], z_spec,
        z_values, contract)
    @test validate_genome(z).valid
    @test validate_family(default_family_registry(), z).valid
    z_result = FusionConceptAI._mechanism_expansion_result(
        MechanismExpansionScreenV1(contract), z)
    @test isempty(z_result["topology_graph_errors"])
    @test z_result["nominal"]["experimental_performance_multiplier_used"] === false
    @test haskey(z_result["nominal"]["margins"],
        "mode_specific_normalized_shear")
    @test haskey(z_result["nominal"]["margins"], "m0_pressure_profile")
    @test haskey(z_result["nominal"]["margins"], "particle_loss")
    @test z_result["nominal"]["repetition_rate_Hz"] > 0.0

    first_small = run_mechanism_expansion_qd_v10(seeds;
        acquisition_samples = 294, maximum_graph_elites = 98,
        elites_per_structural_stratum = 1)
    second_small = run_mechanism_expansion_qd_v10(seeds;
        acquisition_samples = 294, maximum_graph_elites = 98,
        elites_per_structural_stratum = 1)
    @test canonical_hash(first_small) == canonical_hash(second_small)
    @test first_small["topology_count_per_contract"] == 49
    @test first_small["v9_control_topology_count_per_contract"] == 41
    @test first_small["new_mechanism_topology_count_per_contract"] == 8
    @test first_small["structural_stratum_count"] == 294
    @test first_small["explicit_graph_elite_count"] == 98
    @test all(record -> isempty(record["evaluation"]["topology_graph_errors"]),
        first_small["records"])
    @test first_small["v9_failure_label_lineage"]["review_result_hash"] ==
        "41b8341e19f440e58a75320a1f53d9da281086a5c27d9c00c96710b61cc0caa4"

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(MECHANISM_EXPANSION_QD_V10_PATH, String), Dict{String,Any}))
    @test artifact["result_hash"] ==
        "73c1086ee8be13231e89c657e28fafd90e5da0e098f24f1b7eec1a7b381c4d42"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    search = artifact["mechanism_expansion_qd"]
    @test search["acquisition_samples"] == 300000
    @test search["topology_count_per_contract"] == 49
    @test search["v9_control_topology_count_per_contract"] == 41
    @test search["new_mechanism_topology_count_per_contract"] == 8
    @test search["structural_stratum_count"] == 294
    @test search["acquisition_archive_cell_count"] == 2699
    @test search["acquisition_positive_net_count"] == 1
    @test search["acquisition_nominal_physics_and_engineering_pass_count"] == 0
    @test search["explicit_graph_elite_count"] == 588
    @test search["explicit_graph_five_gate_pass_count"] == 0
    @test search["explicit_graph_positive_net_count"] == 0
    @test search["promotion_count"] == 0
    @test isempty(artifact["medium_fidelity_review_queue"])
    @test artifact["direct_converter_energy_conservation_audit"]["passed"] === true
    @test artifact["direct_converter_energy_conservation_audit"][
        "recovery_bound_violation_count"] == 0
    @test artifact["direct_converter_energy_conservation_audit"][
        "neutron_power_recovery_credit"] === false
    @test artifact["direct_converter_energy_conservation_audit"][
        "maximum_recovery_fraction"] <= 0.50
    @test search["v9_failure_label_lineage"]["review_result_hash"] ==
        "41b8341e19f440e58a75320a1f53d9da281086a5c27d9c00c96710b61cc0caa4"
    @test artifact["sealed_input_hashes"]["composable_cross_family_qd_v9"] ==
        bytes2hex(sha256(read(joinpath(PROJECT_ROOT, "runs",
            "composable_cross_family_qd_v9_20260813.json"))))
    @test artifact["sealed_input_hashes"]["v9_tokamak_freegs_review"] ==
        bytes2hex(sha256(read(V9_TOKAMAK_FREEGS_REVIEW_PATH)))
    v10_source_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "sealed_source_catalog" => joinpath(PROJECT_ROOT, "knowledge", "sources.json"),
        "v9_source_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "composable_cross_family_v9_sources.json"),
        "mechanism_source_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "mechanism_expansion_v10_sources.json"),
        "family_registry" => joinpath(PROJECT_ROOT, "src", "registry.jl"),
        "mechanism_extension_schema" => joinpath(PROJECT_ROOT, "schemas",
            "mechanism_expansion_extension_v10.schema.json"),
        "mechanism_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "mechanism_expansion_screen_v1.jl"),
        "mechanism_search" => joinpath(PROJECT_ROOT, "src", "search",
            "mechanism_expansion_qd_v10.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_mechanism_expansion_qd_v10.jl"))
    for (key, path) in v10_source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    overlay = FusionConceptAI._plain_json(JSON3.read(read(
        joinpath(PROJECT_ROOT, "knowledge", "mechanism_expansion_v10_sources.json"),
        String), Dict{String,Any}))
    @test length(overlay["sources"]) == 6
    @test Set(source["id"] for source in overlay["sources"]) ==
        Set(FusionConceptAI._MEV10_SOURCE_BASIS)
    @test isfile(MECHANISM_EXPANSION_QD_V10_SUMMARY_PATH)
    summary = read(MECHANISM_EXPANSION_QD_V10_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("New-mechanism promotions: 0", summary)
    @test occursin("empty queue", summary)
end

@testset "Open-loss-pathway cross-family QD v11" begin
    seeds = load_genomes(SEEDS_PATH)
    specs = FusionConceptAI._olv11_topology_specs()
    @test length(specs) == 55
    @test count(FusionConceptAI._olv11_is_control, specs) == 49
    @test count(spec -> !FusionConceptAI._olv11_is_control(spec), specs) == 6
    @test count(spec -> spec.core_family == "magnetic_mirror" &&
        !FusionConceptAI._olv11_is_control(spec), specs) == 4
    @test count(spec -> spec.core_family == "high_beta_magnetic_cusp", specs) == 2

    structural = FusionConceptAI._olv11_structural_bases(seeds)
    @test length(structural) == 55
    contract = only(filter(item -> item.id == "outer_reference_B4_v1",
        shared_outer_envelope_contracts_v1()))
    u = ntuple(_ -> 0.5, 18)

    gdmt_spec = only(filter(spec -> spec.mechanism == "gas_dynamic_multimirror" &&
        spec.exhaust_topology == "two_end_bounded_direct_converter", specs))
    gdmt_values = FusionConceptAI._olv11_ranges(gdmt_spec, u)
    gdmt = FusionConceptAI._olv11_instantiate(
        structural[FusionConceptAI._olv11_key(gdmt_spec)], gdmt_spec,
        gdmt_values, contract)
    @test validate_genome(gdmt).valid
    @test validate_family(default_family_registry(), gdmt).valid
    gdmt_result = FusionConceptAI._open_loss_pathway_result(
        OpenLossPathwayScreenV1(contract), gdmt)
    @test isempty(gdmt_result["topology_graph_errors"])
    gdmt_nominal = gdmt_result["nominal"]
    @test gdmt_nominal["multiple_mirror_axial_suppression"] <= 4.0
    @test gdmt_nominal["ideal_N_or_N_squared_performance_transplanted"] === false
    @test gdmt_nominal["transverse_loss_power_W"] > 0.0
    @test gdmt_nominal["direct_converter_recovery_fraction"] <= 0.35
    @test gdmt_nominal["direct_converter_recovered_electric_power_W"] <=
        gdmt_nominal["charged_end_loss_power_W"]
    @test gdmt_nominal["ion_mean_free_path_m"] > 0.0
    @test haskey(gdmt_nominal["margins"],
        "multiple_mirror_cell_collisionality")
    @test haskey(gdmt_nominal["margins"], "transverse_loss_floor")

    cusp_spec = only(filter(spec -> spec.mechanism ==
        "high_beta_cusp_electrostatic_ion_candidate", specs))
    cusp_values = FusionConceptAI._olv11_ranges(cusp_spec, u)
    cusp = FusionConceptAI._olv11_instantiate(
        structural[FusionConceptAI._olv11_key(cusp_spec)], cusp_spec,
        cusp_values, contract)
    @test validate_genome(cusp).valid
    cusp_result = FusionConceptAI._open_loss_pathway_result(
        OpenLossPathwayScreenV1(contract), cusp)
    @test isempty(cusp_result["topology_graph_errors"])
    cusp_nominal = cusp_result["nominal"]
    @test cusp_nominal["electron_confinement_experiment_used_for_ion_credit"] === false
    @test cusp_nominal["low_beta_well_experiment_transplanted_to_high_beta"] === false
    @test cusp_nominal["margins"]["high_beta_ion_confinement_evidence"] < 0.0
    @test cusp_nominal["margins"]["high_beta_quasineutral_well_persistence"] < 0.0
    @test cusp_nominal["margins"]["cusp_loss_model_validity"] < 0.0
    @test cusp_nominal["physics_gate_passed"] === false

    first_small = run_open_loss_pathway_qd_v11(seeds;
        acquisition_samples = 330, maximum_graph_elites = 110,
        elites_per_structural_stratum = 1)
    second_small = run_open_loss_pathway_qd_v11(seeds;
        acquisition_samples = 330, maximum_graph_elites = 110,
        elites_per_structural_stratum = 1)
    @test canonical_hash(first_small) == canonical_hash(second_small)
    @test first_small["topology_count_per_contract"] == 55
    @test first_small["v10_control_topology_count_per_contract"] == 49
    @test first_small["new_mechanism_topology_count_per_contract"] == 6
    @test first_small["structural_stratum_count"] == 330
    @test first_small["explicit_graph_elite_count"] == 110
    @test all(record -> isempty(record["evaluation"]["topology_graph_errors"]),
        first_small["records"])
    @test first_small["sealed_v10_control_lineage"]["formal_result_hash"] ==
        "73c1086ee8be13231e89c657e28fafd90e5da0e098f24f1b7eec1a7b381c4d42"

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(OPEN_LOSS_PATHWAY_QD_V11_PATH, String), Dict{String,Any}))
    @test artifact["result_hash"] ==
        "5284d5cae8a79e3ef7a26bf241bbe8ad8836472f00873bcff8c4cabb5d76da27"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    search = artifact["open_loss_pathway_qd"]
    @test search["acquisition_samples"] == 300000
    @test search["topology_count_per_contract"] == 55
    @test search["v10_control_topology_count_per_contract"] == 49
    @test search["new_mechanism_topology_count_per_contract"] == 6
    @test search["structural_stratum_count"] == 330
    @test search["acquisition_archive_cell_count"] == 690
    @test search["acquisition_positive_net_count"] == 289
    @test search["acquisition_nominal_physics_and_engineering_pass_count"] == 0
    @test search["explicit_graph_elite_count"] == 576
    @test search["explicit_graph_five_gate_pass_count"] == 0
    @test search["explicit_graph_positive_net_count"] == 7
    @test search["promotion_count"] == 0
    @test isempty(artifact["medium_fidelity_review_queue"])
    @test count(record -> !record["is_v10_control"], search["records"]) == 66
    @test all(record -> isempty(record["evaluation"]["topology_graph_errors"]),
        search["records"])
    @test all(record -> record["genome_omitted_from_artifact"] === true,
        search["records"])

    gdt_audit = artifact["gdt_credit_and_energy_audit"]
    @test gdt_audit["passed"] === true
    @test gdt_audit["gdt_elite_count"] == 44
    @test gdt_audit["converter_elite_count"] == 22
    @test gdt_audit["multiple_mirror_credit_violation_count"] == 0
    @test gdt_audit["direct_converter_energy_violation_count"] == 0
    @test gdt_audit["maximum_multiple_mirror_axial_suppression"] <= 4.0
    @test gdt_audit["maximum_recovery_fraction"] <= 0.35
    @test gdt_audit["transverse_loss_channel_retained"] === true
    @test gdt_audit["neutron_power_recovery_credit"] === false
    cusp_audit = artifact["cusp_evidence_isolation_audit"]
    @test cusp_audit["passed"] === true
    @test cusp_audit["cusp_elite_count"] == 22
    @test cusp_audit["evidence_boundary_violation_count"] == 0
    @test cusp_audit["ion_confinement_status"] == "blocking unresolved"

    @test artifact["sealed_input_hashes"]["mechanism_expansion_qd_v10"] ==
        bytes2hex(sha256(read(MECHANISM_EXPANSION_QD_V10_PATH)))
    v11_source_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "sealed_source_catalog" => joinpath(PROJECT_ROOT, "knowledge", "sources.json"),
        "v9_source_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "composable_cross_family_v9_sources.json"),
        "v10_source_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "mechanism_expansion_v10_sources.json"),
        "open_loss_source_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "open_loss_pathways_v11_sources.json"),
        "open_loss_extension_schema" => joinpath(PROJECT_ROOT, "schemas",
            "open_loss_pathways_extension_v11.schema.json"),
        "open_loss_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "open_loss_pathway_screen_v1.jl"),
        "open_loss_search" => joinpath(PROJECT_ROOT, "src", "search",
            "open_loss_pathway_qd_v11.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_open_loss_pathway_qd_v11.jl"))
    for (key, path) in v11_source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    overlay = FusionConceptAI._plain_json(JSON3.read(read(joinpath(PROJECT_ROOT,
        "knowledge", "open_loss_pathways_v11_sources.json"), String),
        Dict{String,Any}))
    @test length(overlay["sources"]) == 8
    @test Set(source["id"] for source in overlay["sources"]) ==
        Set(FusionConceptAI._OLV11_SOURCE_BASIS)
    @test isfile(OPEN_LOSS_PATHWAY_QD_V11_SUMMARY_PATH)
    summary = read(OPEN_LOSS_PATHWAY_QD_V11_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("New-mechanism promotions: 0", summary)
    @test occursin("empty queue", summary)
end

@testset "Causal-bridge and negative-anchor QD v12" begin
    seeds = load_genomes(SEEDS_PATH)
    specs = FusionConceptAI._cbv12_topology_specs()
    @test length(specs) == 60
    @test count(FusionConceptAI._cbv12_is_control, specs) == 55
    @test count(spec -> !FusionConceptAI._cbv12_is_control(spec), specs) == 5
    @test count(spec -> spec.anchor_only, specs) == 2
    @test count(spec -> spec.promotion_eligible, specs) == 3

    structural = FusionConceptAI._cbv12_structural_bases(seeds)
    @test length(structural) == 60
    contract = only(filter(item -> item.id == "outer_reference_B4_v1",
        shared_outer_envelope_contracts_v1()))
    u = ntuple(_ -> 0.5, 18)

    gdmt_spec = only(filter(spec -> spec.mechanism == "two_component_gdmt", specs))
    gdmt_values = FusionConceptAI._cbv12_ranges(gdmt_spec, u)
    gdmt = FusionConceptAI._cbv12_instantiate(
        structural[FusionConceptAI._cbv12_key(gdmt_spec)], gdmt_spec,
        gdmt_values, contract)
    @test validate_genome(gdmt).valid
    @test validate_family(default_family_registry(), gdmt).valid
    gdmt_result = FusionConceptAI._causal_bridge_result(
        CausalBridgeScreenV1(contract), gdmt)
    @test isempty(gdmt_result["topology_graph_errors"])
    gdmt_nominal = gdmt_result["nominal"]
    @test gdmt_nominal["single_temperature_gdt_model_used"] === false
    @test gdmt_nominal["target_electron_temperature_keV"] !=
        gdmt_nominal["fast_ion_energy_keV"]
    @test gdmt_nominal["d_on_t_center_of_mass_energy_keV"] ≈
        0.6gdmt_nominal["fast_ion_energy_keV"]
    @test gdmt_nominal["t_on_d_center_of_mass_energy_keV"] ≈
        0.4gdmt_nominal["fast_ion_energy_keV"]
    @test gdmt_nominal["declared_nbi_power_W"] >=
        gdmt_nominal["required_injected_nbi_power_W"] ||
        gdmt_nominal["margins"]["nbi_inventory_closure"] < 0.0
    @test gdmt_nominal["multiple_mirror_axial_suppression"] <= 4.0
    @test gdmt_nominal["ideal_N_or_N_squared_performance_transplanted"] === false
    @test gdmt_nominal["margins"]["minimum_b_and_vortex_stability"] >= 0.0
    @test FusionConceptAI._cbv12_dt_cross_section_m2(50.0) / 1.0e-28 ≈
        4.218357113907128 rtol = 1.0e-12

    neutron_spec = only(filter(spec -> spec.mechanism ==
        "gridded_iec_neutron_anchor", specs))
    neutron = FusionConceptAI._cbv12_instantiate(
        structural[FusionConceptAI._cbv12_key(neutron_spec)], neutron_spec,
        FusionConceptAI._cbv12_ranges(neutron_spec, u), contract)
    neutron_result = FusionConceptAI._causal_bridge_result(
        CausalBridgeScreenV1(contract), neutron)["nominal"]
    @test neutron_result["anchor_only"] === true
    @test neutron_result["optimistic_fusion_to_input_efficiency_ceiling"] == 1.0e-5
    @test neutron_result["fusion_gain_proxy"] <= 1.0e-5
    @test neutron_result["reactor_scale_potential_well_credited"] === false
    @test neutron_result["unbounded_ion_recirculation_credited"] === false

    iec_candidate_spec = only(filter(spec -> spec.mechanism ==
        "gridded_iec_net_electric_candidate", specs))
    iec_candidate = FusionConceptAI._cbv12_instantiate(
        structural[FusionConceptAI._cbv12_key(iec_candidate_spec)],
        iec_candidate_spec,
        FusionConceptAI._cbv12_ranges(iec_candidate_spec, u), contract)
    iec_candidate_result = FusionConceptAI._causal_bridge_result(
        CausalBridgeScreenV1(contract), iec_candidate)["nominal"]
    @test iec_candidate_result["anchor_only"] === false
    @test iec_candidate_result["margins"]["nonequilibrium_recirculating_power"] < 0.0
    @test iec_candidate_result["physics_gate_passed"] === false

    dpf_spec = only(filter(spec -> spec.mechanism ==
        "dpf_experimental_saturation_anchor", specs))
    dpf = FusionConceptAI._cbv12_instantiate(
        structural[FusionConceptAI._cbv12_key(dpf_spec)], dpf_spec,
        FusionConceptAI._cbv12_ranges(dpf_spec, u), contract)
    dpf_result = FusionConceptAI._causal_bridge_result(
        CausalBridgeScreenV1(contract), dpf)["nominal"]
    @test dpf_result["anchor_only"] === true
    @test dpf_result["optimistic_q_ceiling"] == 0.01
    @test dpf_result["unbounded_current_power_law_used"] === false
    @test dpf_result["margins"]["electrode_lifetime_and_repetition_evidence"] < 0.0

    first_small = run_causal_bridge_qd_v12(seeds;
        acquisition_samples = 360, maximum_graph_elites = 120,
        elites_per_structural_stratum = 1)
    second_small = run_causal_bridge_qd_v12(seeds;
        acquisition_samples = 360, maximum_graph_elites = 120,
        elites_per_structural_stratum = 1)
    @test canonical_hash(first_small) == canonical_hash(second_small)
    @test first_small["topology_count_per_contract"] == 60
    @test first_small["v11_control_topology_count_per_contract"] == 55
    @test first_small["new_bridge_or_anchor_topology_count_per_contract"] == 5
    @test first_small["negative_anchor_topology_count_per_contract"] == 2
    @test first_small["promotion_eligible_new_topology_count_per_contract"] == 3
    @test first_small["structural_stratum_count"] == 360
    @test all(record -> isempty(record["evaluation"]["topology_graph_errors"]),
        first_small["records"])
    @test all(record -> !record["promoted"],
        filter(record -> record["anchor_only"], first_small["records"]))
    @test first_small["sealed_v11_control_lineage"]["formal_result_hash"] ==
        "5284d5cae8a79e3ef7a26bf241bbe8ad8836472f00873bcff8c4cabb5d76da27"

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(CAUSAL_BRIDGE_QD_V12_PATH, String), Dict{String,Any}))
    @test artifact["result_hash"] ==
        "583fa8dacdafbd017db705fa4cb5a4f40b2eae1ad337ac14ec142844ce1f1bec"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    search = artifact["causal_bridge_qd"]
    @test search["acquisition_samples"] == 300000
    @test search["contract_count"] == 6
    @test search["topology_count_per_contract"] == 60
    @test search["v11_control_topology_count_per_contract"] == 55
    @test search["new_bridge_or_anchor_topology_count_per_contract"] == 5
    @test search["negative_anchor_topology_count_per_contract"] == 2
    @test search["promotion_eligible_new_topology_count_per_contract"] == 3
    @test search["structural_stratum_count"] == 360
    @test search["acquisition_archive_cell_count"] == 504
    @test search["acquisition_positive_net_count"] == 244
    @test search["acquisition_nominal_physics_and_engineering_pass_count"] == 3398
    @test search["explicit_graph_elite_count"] == 462
    @test search["explicit_graph_five_gate_pass_count"] == 11
    @test search["explicit_graph_positive_net_count"] == 2
    @test search["promotion_count"] == 0
    records = search["records"]
    new_records = filter(record -> !record["is_v11_control"], records)
    anchors = filter(record -> record["anchor_only"], records)
    @test length(records) == 462
    @test length(new_records) == 60
    @test length(anchors) == 24
    @test count(record -> record["all_five_gates_passed"], new_records) == 11
    @test count(record -> record["positive_net_power_closure_passed"],
        new_records) == 0
    @test count(record -> record["all_five_gates_passed"], anchors) == 11
    @test all(record -> isempty(record["evaluation"]["topology_graph_errors"]),
        records)
    @test all(record -> !record["promoted"], anchors)
    @test isempty(artifact["medium_fidelity_review_queue"])

    gdt_audit = artifact["two_component_gdt_audit"]
    @test gdt_audit["passed"] === true
    @test gdt_audit["two_component_gdt_elite_count"] == 24
    @test gdt_audit["nbi_inventory_conservation_violation_count"] == 0
    @test gdt_audit["beam_target_cross_section_boundary_violation_count"] == 0
    @test gdt_audit["single_temperature_model_violation_count"] == 0
    @test gdt_audit["multiple_mirror_credit_violation_count"] == 0
    @test gdt_audit["maximum_fusion_gain_proxy"] ≈ 0.054277020228729544
    negative_audit = artifact["negative_anchor_audit"]
    @test negative_audit["passed"] === true
    @test negative_audit["negative_anchor_elite_count"] == 24
    @test negative_audit["negative_anchor_promotion_violation_count"] == 0
    @test negative_audit["iec_evidence_boundary_violation_count"] == 0
    @test negative_audit["dpf_evidence_boundary_violation_count"] == 0

    @test artifact["sealed_input_hashes"]["open_loss_pathway_qd_v11"] ==
        bytes2hex(sha256(read(OPEN_LOSS_PATHWAY_QD_V11_PATH)))
    v12_source_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "sealed_source_catalog" => joinpath(PROJECT_ROOT, "knowledge", "sources.json"),
        "v9_source_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "composable_cross_family_v9_sources.json"),
        "v10_source_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "mechanism_expansion_v10_sources.json"),
        "v11_source_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "open_loss_pathways_v11_sources.json"),
        "v12_source_overlay" => joinpath(PROJECT_ROOT, "knowledge",
            "causal_bridge_negative_anchors_v12_sources.json"),
        "v12_extension_schema" => joinpath(PROJECT_ROOT, "schemas",
            "causal_bridge_negative_anchors_extension_v12.schema.json"),
        "v12_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "causal_bridge_screen_v1.jl"),
        "v12_search" => joinpath(PROJECT_ROOT, "src", "search",
            "causal_bridge_qd_v12.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_causal_bridge_qd_v12.jl"))
    for (key, path) in v12_source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    overlay = FusionConceptAI._plain_json(JSON3.read(read(joinpath(PROJECT_ROOT,
        "knowledge", "causal_bridge_negative_anchors_v12_sources.json"), String),
        Dict{String,Any}))
    @test length(overlay["sources"]) == 10
    @test Set(source["id"] for source in overlay["sources"]) ==
        Set(FusionConceptAI._CBV12_SOURCE_BASIS)
    @test isfile(CAUSAL_BRIDGE_QD_V12_SUMMARY_PATH)
    summary = read(CAUSAL_BRIDGE_QD_V12_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Eligible new-bridge promotions: 0", summary)
    @test occursin("An empty queue", summary)
end

@testset "Safe active causal discovery v13 and hierarchical gate v14" begin
    seeds = load_genomes(SEEDS_PATH)
    v12 = FusionConceptAI._plain_json(JSON3.read(
        read(CAUSAL_BRIDGE_QD_V12_PATH, String), Dict{String,Any}))
    v13 = FusionConceptAI._plain_json(JSON3.read(
        read(SAFE_ACTIVE_CAUSAL_DISCOVERY_V13_PATH, String), Dict{String,Any}))
    v14 = FusionConceptAI._plain_json(JSON3.read(
        read(HIERARCHICAL_GATE_DISCOVERY_V14_PATH, String), Dict{String,Any}))

    v13_config = SafeActiveCausalDiscoveryConfigV13(
        calibration_samples = 60, proposal_pool_samples = 600,
        explicit_batch_size = 60, neighbor_count = 3)
    v13_small_a = run_safe_active_causal_discovery_v13(seeds, v12;
        config = v13_config)
    v13_small_b = run_safe_active_causal_discovery_v13(seeds, v12;
        config = v13_config)
    @test canonical_hash(v13_small_a) == canonical_hash(v13_small_b)
    @test v13_small_a["historical_reconstruction_violation_count"] == 0
    @test v13_small_a["path_count"] == 60
    @test v13_small_a["selected_structural_stratum_count"] == 60
    @test v13_small_a["surrogate_only_promotion_count"] == 0
    @test v13_small_a["negative_anchor_promotion_count"] == 0
    @test all(path -> path["surrogate_can_authorize_promotion"] === false,
        v13_small_a["causal_paths"])

    @test v13["result_hash"] ==
        "4ecf08031357668326a047dcb369a3bdc9e9f846ba66e2d5095a7db0c9afa7be"
    without_hash = deepcopy(v13)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == v13["result_hash"]
    v13_result = v13["safe_active_causal_discovery"]
    @test v13_result["historical_reconstruction_violation_count"] == 0
    @test v13_result["path_count"] == 60
    @test v13_result["structural_stratum_count"] == 360
    @test v13_result["proposal_pool_count"] == 60000
    @test v13_result["explicit_calibration_count"] == 360
    @test v13_result["selected_explicit_evaluation_count"] == 360
    @test v13_result["selected_structural_stratum_count"] == 360
    @test v13_result["explicit_promotion_count"] == 0
    @test v13_result["surrogate_only_promotion_count"] == 0
    @test v13_result["negative_anchor_promotion_count"] == 0
    @test isempty(v13_result["medium_fidelity_review_queue"])
    @test length(v13_result["model_audits"]) == 60
    @test all(audit ->
        audit["posterior_or_safeopt_guarantee_claimed"] === false,
        Base.values(v13_result["model_audits"]))
    v13_ab = v13["blind_vs_active_audit"]
    @test v13_ab["baseline"]["five_gate_pass_count"] == 3
    @test v13_ab["active"]["five_gate_pass_count"] == 2
    @test v13_ab["active"]["maximum_explicit_margin"] <
        v13_ab["baseline"]["maximum_explicit_margin"]
    @test v13_ab["sample_efficiency_or_superiority_claimed"] === false
    @test v13["admission_authority_audit"]["passed"] === true

    v14_config = HierarchicalGateDiscoveryConfigV14(sequence_skip = 660,
        blind_baseline_samples = 60, proposal_pool_samples = 600,
        active_batch_size = 60, neighbor_count = 3)
    v14_small_a = run_hierarchical_gate_discovery_v14(seeds, v12, v13;
        config = v14_config)
    v14_small_b = run_hierarchical_gate_discovery_v14(seeds, v12, v13;
        config = v14_config)
    @test canonical_hash(v14_small_a) == canonical_hash(v14_small_b)
    @test v14_small_a["historical_reconstruction_violation_count"] == 0
    @test v14_small_a["sequence_start"] == 361021
    @test v14_small_a["sequence_overlap_with_v13_count"] == 0
    @test v14_small_a["selected_structural_stratum_count"] == 60
    @test v14_small_a["surrogate_only_promotion_count"] == 0
    @test v14_small_a["negative_anchor_promotion_count"] == 0

    @test v14["result_hash"] ==
        "6ce0cba4a0e74806cd5ea068e8f84a5bc94d644aaec61ff5891e4126988b8540"
    without_hash = deepcopy(v14)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == v14["result_hash"]
    v14_result = v14["hierarchical_gate_discovery"]
    @test v14_result["historical_explicit_observation_count"] == 1182
    @test v14_result["historical_reconstruction_violation_count"] == 0
    @test v14_result["sequence_start"] == 361021
    @test v14_result["sequence_end"] == 421380
    @test v14_result["v13_max_sequence_index"] == 360360
    @test v14_result["smoke_sequence_skip"] == 660
    @test v14_result["sequence_overlap_with_v13_count"] == 0
    @test v14_result["proposal_pool_count"] == 60000
    @test v14_result["selected_structural_stratum_count"] == 360
    @test length(v14_result["classifier_audits"]) == 60
    @test all(path -> all(gate ->
        path[gate]["calibrated_probability_or_safety_guarantee_claimed"] === false,
        FusionConceptAI._HGV14_GATE_IDS),
        Base.values(v14_result["classifier_audits"]))
    @test v14_result["explicit_promotion_count"] == 0
    @test v14_result["surrogate_only_promotion_count"] == 0
    @test v14_result["negative_anchor_promotion_count"] == 0
    @test isempty(v14_result["medium_fidelity_review_queue"])
    @test all(record -> isempty(record["evaluation"]["topology_graph_errors"]),
        vcat(v14_result["blind_baseline_records"], v14_result["active_records"]))
    v14_ab = v14["blind_vs_active_gate_audit"]
    @test v14_ab["baseline"]["physics_pass_count"] == 12
    @test v14_ab["active"]["physics_pass_count"] == 12
    @test v14_ab["baseline"]["engineering_pass_count"] == 9
    @test v14_ab["active"]["engineering_pass_count"] == 35
    @test v14_ab["baseline"]["robustness_pass_count"] == 3
    @test v14_ab["active"]["robustness_pass_count"] == 4
    @test v14_ab["baseline"]["five_gate_pass_count"] == 3
    @test v14_ab["active"]["five_gate_pass_count"] == 4
    @test v14_ab["baseline"]["positive_net_count"] == 0
    @test v14_ab["active"]["positive_net_count"] == 2
    @test v14_ab["post_result_acquisition_tuning_allowed"] === false
    @test v14_ab["sample_efficiency_or_superiority_claimed"] === false
    @test v14["admission_authority_audit"]["passed"] === true
    @test count(record -> record["all_five_gates_passed"] === true &&
        record["anchor_only"] === true, v14_result["active_records"]) == 4
    @test count(record -> record["positive_net_power_closure_passed"] === true &&
        record["mechanism"] == "high_beta_cusp_electrostatic_ion_candidate",
        v14_result["active_records"]) == 2

    @test v13["sealed_input_hashes"]["causal_bridge_qd_v12"] ==
        bytes2hex(sha256(read(CAUSAL_BRIDGE_QD_V12_PATH)))
    @test v14["sealed_input_hashes"]["causal_bridge_qd_v12"] ==
        bytes2hex(sha256(read(CAUSAL_BRIDGE_QD_V12_PATH)))
    @test v14["sealed_input_hashes"]["safe_active_causal_discovery_v13"] ==
        bytes2hex(sha256(read(SAFE_ACTIVE_CAUSAL_DISCOVERY_V13_PATH)))
    source_overlay_path = joinpath(PROJECT_ROOT, "knowledge",
        "safe_active_causal_discovery_v13_sources.json")
    overlay = FusionConceptAI._plain_json(JSON3.read(
        read(source_overlay_path, String), Dict{String,Any}))
    @test length(overlay["sources"]) == 5
    @test Set(source["id"] for source in overlay["sources"]) ==
        Set(FusionConceptAI._SAV13_SOURCE_BASIS)
    v13_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "v12_artifact" => CAUSAL_BRIDGE_QD_V12_PATH,
        "v13_source_overlay" => source_overlay_path,
        "v13_search" => joinpath(PROJECT_ROOT, "src", "search",
            "safe_active_causal_discovery_v13.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_safe_active_causal_discovery_v13.jl"))
    for (key, path) in v13_paths
        @test v13["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    v14_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "v12_artifact" => CAUSAL_BRIDGE_QD_V12_PATH,
        "v13_artifact" => SAFE_ACTIVE_CAUSAL_DISCOVERY_V13_PATH,
        "v13_method_source_overlay" => source_overlay_path,
        "v14_search" => joinpath(PROJECT_ROOT, "src", "search",
            "hierarchical_gate_discovery_v14.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_hierarchical_gate_discovery_v14.jl"))
    for (key, path) in v14_paths
        @test v14["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    @test isfile(SAFE_ACTIVE_CAUSAL_DISCOVERY_V13_SUMMARY_PATH)
    @test isfile(HIERARCHICAL_GATE_DISCOVERY_V14_SUMMARY_PATH)
    @test occursin(v13["result_hash"],
        read(SAFE_ACTIVE_CAUSAL_DISCOVERY_V13_SUMMARY_PATH, String))
    @test occursin(v14["result_hash"],
        read(HIERARCHICAL_GATE_DISCOVERY_V14_SUMMARY_PATH, String))
end

@testset "Laser inertial-confinement pulsed contract and QD v15" begin
    seeds = load_genomes(SEEDS_PATH)
    parent = only(filter(genome -> genome.family == "tokamak_axisymmetric",
        seeds))
    contracts = laser_icf_pulsed_contracts_v1()
    specs = FusionConceptAI._licfv15_topology_specs()
    @test length(contracts) == 3
    @test length(specs) == 10
    @test count(spec -> spec.anchor_only, specs) == 1
    @test count(spec -> spec.promotion_eligible, specs) == 9
    @test Set(getfield.(specs, :drive_path)) == Set([
        "laser_indirect_drive", "laser_direct_drive", "laser_fast_ignition"])
    @test all(contract -> canonical_hash(FusionConceptAI.
        _laser_icf_contract_dict(contract)) in LaserICFScreenV1(
            contract).allowed_contract_hashes, contracts)

    overlay_path = joinpath(PROJECT_ROOT, "knowledge",
        "laser_icf_v15_sources.json")
    overlay = FusionConceptAI._plain_json(JSON3.read(read(overlay_path,
        String), Dict{String,Any}))
    overlay_ids = Set(String(source["id"]) for source in overlay["sources"])
    @test overlay["catalog_version"] == "laser_icf_v15_overlay_1.0.0"
    @test length(overlay_ids) == 6
    @test overlay_ids == Set(FusionConceptAI._LICFV15_SOURCE_BASIS)
    @test all(source -> !isempty(String(source["claim_boundary"])),
        overlay["sources"])
    @test occursin("net-electric", String(only(filter(source ->
        source["id"] == "nif_target_gain_unity_2024",
        overlay["sources"]))["claim_boundary"]))
    extension = FusionConceptAI._plain_json(JSON3.read(read(joinpath(
        PROJECT_ROOT, "schemas", "laser_icf_extension_v15.schema.json"),
        String), Dict{String,Any}))
    @test extension["properties"]["family"]["const"] ==
        "inertial_confinement_fusion"
    @test extension["x-lmc-base-schema"] == "confinement_genome.schema.json"
    @test family_spec(laser_icf_family_registry_v15(),
        "inertial_confinement_fusion") !== nothing

    anchor_spec = only(filter(spec -> spec.anchor_only, specs))
    anchor_values = FusionConceptAI._licfv15_ranges(anchor_spec,
        ntuple(_ -> 0.5, 18))
    anchor = FusionConceptAI._licfv15_build_genome(parent, anchor_spec,
        anchor_values, contracts[1])
    @test validate_genome(anchor).valid
    @test validate_family(laser_icf_family_registry_v15(), anchor).valid
    known = union(known_source_ids(joinpath(PROJECT_ROOT, "knowledge",
        "sources.json")), overlay_ids)
    @test isempty(source_reference_errors(anchor, known))
    anchor_result = FusionConceptAI._laser_icf_result(
        LaserICFScreenV1(contracts[1]), anchor)
    @test anchor_result["all_five_gates_passed"] === true
    @test anchor_result["anchor_only"] === true
    @test anchor_result["promotion_eligible"] === false
    @test anchor_result["promotable"] === false
    @test anchor_result["nominal"]["target_gain_lower_bound"] == 1.0
    @test anchor_result["nominal"]["wall_plug_or_net_electric_credit"] === false
    @test anchor_result["nominal"][
        "absolute_shot_energy_imported_from_memory"] === false

    candidate_specs = filter(spec -> !spec.anchor_only, specs)
    for (index, spec) in enumerate(candidate_specs)
        u = ntuple(axis -> mod(0.173 * index + 0.071 * axis, 1.0), 18)
        values = FusionConceptAI._licfv15_ranges(spec, u)
        candidate = FusionConceptAI._licfv15_build_genome(parent, spec,
            values, contracts[mod1(index, length(contracts))])
        @test validate_genome(candidate).valid
        @test validate_family(laser_icf_family_registry_v15(), candidate).valid
        @test isempty(source_reference_errors(candidate, known))
        result = FusionConceptAI._laser_icf_result(LaserICFScreenV1(
            contracts[mod1(index, length(contracts))]), candidate)
        @test isempty(result["topology_graph_errors"])
        @test result["nominal"]["searched_quantities_are_hypotheses"] === true
        @test result["nominal"]["margins"][
            "target_gain_experimental_validation"] < 0.0
        @test result["nominal"]["margins"][
            "driver_wall_plug_and_repeat_rate_validation"] < 0.0
        @test result["nominal"]["margins"][
            "target_factory_throughput_and_yield_validation"] < 0.0
        @test result["nominal"]["margins"][
            "first_wall_and_final_optics_lifetime_validation"] < 0.0
        @test result["all_five_gates_passed"] === false
        @test result["promotable"] === false
        @test result["nominal"]["driver_grid_energy_per_shot_J"] ≈
            result["nominal"]["on_target_energy_J"] /
                result["features"]["driver_wall_plug_efficiency"]
        inventory_ok = result["nominal"]["fusion_yield_assumption_J"] <=
            result["nominal"]["dt_fuel_energy_ceiling_J"]
        @test (result["nominal"]["margins"][
            "fuel_inventory_energy_conservation"] >= 0.0) == inventory_ok
    end

    corrupted_raw = deepcopy(anchor.normalized)
    corrupted_raw["mission"]["targets"]["screen_chamber_radius"]["value"] =
        99.0
    corrupted = parse_genome(corrupted_raw)
    corrupted_result = FusionConceptAI._laser_icf_result(
        LaserICFScreenV1(contracts[1]), corrupted)
    @test !isempty(corrupted_result["topology_graph_errors"])
    @test corrupted_result["gates"]["variable_topology_representation"] === false

    small_a = run_laser_icf_qd_v15(seeds; acquisition_samples = 3000,
        maximum_graph_elites = 90, elites_per_structural_stratum = 2)
    small_b = run_laser_icf_qd_v15(seeds; acquisition_samples = 3000,
        maximum_graph_elites = 90, elites_per_structural_stratum = 2)
    @test canonical_hash(small_a) == canonical_hash(small_b)
    @test small_a["structural_stratum_count"] == 30
    @test small_a["explicit_graph_elite_count"] == 57
    @test small_a["explicit_graph_science_anchor_five_gate_count"] == 3
    @test small_a["explicit_graph_net_candidate_five_gate_count"] == 0
    @test small_a["explicit_graph_positive_average_net_count"] > 0
    @test small_a["promotion_count"] == 0
    @test all(record -> isempty(record["evaluation"][
        "topology_graph_errors"]), small_a["records"])
    @test all(record -> record["anchor_only"] === true ||
        isempty(record["medium_fidelity_route"]), small_a["records"])

    artifact = FusionConceptAI._plain_json(JSON3.read(read(
        LASER_ICF_QD_V15_PATH, String), Dict{String,Any}))
    @test artifact["result_hash"] ==
        "6450cbcf0a207d6f73a131d95038a8646e3a93f7b2f009f7ddfe83d07eafafb6"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    formal = artifact["laser_icf_qd"]
    @test formal["acquisition_samples"] == 300_000
    @test formal["structural_stratum_count"] == 30
    @test formal["fixed_anchor_evaluation_count_outside_acquisition_budget"] == 3
    @test formal["acquisition_archive_cell_count"] == 489
    @test formal["explicit_graph_elite_count"] == 57
    @test formal["explicit_graph_science_anchor_five_gate_count"] == 3
    @test formal["explicit_graph_net_candidate_five_gate_count"] == 0
    @test formal["explicit_graph_conditional_survivor_count"] == 54
    @test formal["explicit_graph_positive_average_net_count"] == 54
    @test formal["promotion_count"] == 0
    @test formal["path_sample_count"]["laser_indirect_drive"] == 100_000
    @test formal["path_sample_count"]["laser_direct_drive"] == 100_000
    @test formal["path_sample_count"]["laser_fast_ignition"] == 100_000
    @test artifact["conservation_and_admission_audit"]["passed"] === true
    @test artifact["conservation_and_admission_audit"][
        "fuel_inventory_conservation_gate_escape_count"] == 0
    @test artifact["conservation_and_admission_audit"][
        "hard_evidence_gate_escape_count"] == 0
    @test artifact["conservation_and_admission_audit"][
        "science_anchor_admission_escape_count"] == 0
    @test artifact["conservation_and_admission_audit"][
        "target_gain_wall_plug_ledger_conflation_count"] == 0
    @test artifact["conservation_and_admission_audit"][
        "topology_graph_error_count"] == 0
    @test isempty(artifact["medium_fidelity_review_queue"])
    source_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "laser_icf_source_overlay" => overlay_path,
        "laser_icf_extension_schema" => joinpath(PROJECT_ROOT, "schemas",
            "laser_icf_extension_v15.schema.json"),
        "genome_ir" => joinpath(PROJECT_ROOT, "src", "genome.jl"),
        "family_registry" => joinpath(PROJECT_ROOT, "src", "registry.jl"),
        "laser_icf_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "laser_icf_screen_v1.jl"),
        "laser_icf_search" => joinpath(PROJECT_ROOT, "src", "search",
            "laser_icf_qd_v15.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_laser_icf_qd_v15.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    @test isfile(LASER_ICF_QD_V15_SUMMARY_PATH)
    summary = read(LASER_ICF_QD_V15_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Net-candidate five-gate passes: 0", summary)
    @test occursin("Promotions: 0", summary)
    @test occursin("not evidence", summary)
end

@testset "Append-only quantitative evidence S2 inventory" begin
    table_raw = FusionConceptAI._plain_json(JSON3.read(
        read(QUANTITATIVE_EVIDENCE_TABLE_PATH, String), Dict{String,Any}))
    known_source_ids = Set{String}()
    for catalog_name in table_raw["base_catalogs"]
        catalog = FusionConceptAI._plain_json(JSON3.read(read(joinpath(
            PROJECT_ROOT, "knowledge", String(catalog_name)), String),
            Dict{String,Any}))
        union!(known_source_ids, Set(String(source["id"])
            for source in catalog["sources"]))
    end

    report = validate_quantitative_evidence_table(table_raw;
        known_source_ids = known_source_ids)
    @test report.valid
    @test isempty(report.errors)
    table = load_quantitative_evidence_table(
        QUANTITATIVE_EVIDENCE_TABLE_PATH;
        known_source_ids = known_source_ids)
    @test table.schema_version == "1.0.0"
    @test table.catalog_version == "quantitative_evidence_icf_open_magnetic_v1"
    @test length(table.entries) == 30
    @test quantitative_evidence_hash(table) ==
        "990daf48f47e3473a2e8cdfa24c8321c5cfbda036074046dc35cd00df66b0ed6"
    @test count(entry -> entry.promotion_credit, table.entries) == 0

    nif = only(filter(entry -> entry.id == "icf_nif_target_gain_lower_bound",
        table.entries))
    @test nif.evidence_provenance == "measured"
    @test nif.value_kind == "lower_bound"
    @test nif.lower_bound == 1.0
    @test nif.promotion_credit === false
    @test occursin("not electrical break-even", nif.claim_boundary)

    gdt = only(filter(entry -> entry.id == "gdt_fast_ion_relaxation_time_range",
        table.entries))
    @test gdt.value_kind == "range"
    @test gdt.lower_bound ≈ 0.55
    @test gdt.upper_bound ≈ 0.77
    @test gdt.nominal_value ≈ 0.70
    @test gdt.promotion_credit === false

    missing = only(filter(entry ->
        entry.id == "icf_repeat_rate_driver_wall_plug_validation", table.entries))
    @test missing.evidence_provenance == "no_direct_measurement"
    @test missing.value_kind == "missing"
    @test missing.nominal_value === nothing
    @test missing.uncertainty_kind == "missing_evidence"

    blocking_gates = [
        "target_gain_experimental_validation",
        "driver_wall_plug_and_repeat_rate_validation",
        "target_factory_throughput_and_yield_validation",
        "first_wall_and_final_optics_lifetime_validation",
    ]
    @test missing_promotion_evidence(table, blocking_gates) == sort(blocking_gates)
    audit = quantitative_gate_audit(table, blocking_gates)
    @test all(item -> item["promotion_credit_count"] == 0, values(audit))
    @test audit["target_gain_experimental_validation"]["status"] ==
        "anchor_or_gap_record_only"
    for gate in blocking_gates[2:end]
        @test audit[gate]["status"] == "gap_record_only"
    end

    summary = quantitative_evidence_summary(table)
    @test summary["entry_count"] == 30
    @test summary["promotion_credit_count"] == 0
    @test summary["provenance_counts"]["measured"] == 11
    @test summary["provenance_counts"]["no_direct_measurement"] == 11

    correction = only(table.citation_corrections)
    @test correction.source_id == "iec_efficiency_anchor_biswas_2019"
    @test correction.legacy_doi == "10.1016/j.nima.2018.10.056"
    @test correction.corrected_doi == "10.1016/j.nima.2018.09.076"

    corrupted = deepcopy(table_raw)
    only(filter(entry -> entry["id"] == "rfp_ppcd_beta_range",
        corrupted["evidence_entries"]))["lower_bound"] = 9.0
    corrupted_report = validate_quantitative_evidence_table(corrupted;
        known_source_ids = known_source_ids)
    @test !corrupted_report.valid
    @test any(error -> occursin("lower_bound", error) &&
        occursin("upper_bound", error), corrupted_report.errors)

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(QUANTITATIVE_EVIDENCE_REPORT_PATH, String), Dict{String,Any}))
    @test artifact["result_hash"] ==
        "9af84f3971f93ca9c2582748390f2830d7441c59ccffd73106297d80bc320016"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    @test artifact["table_hash"] == quantitative_evidence_hash(table)
    @test artifact["table_entry_count"] == 30
    @test artifact["v15_input_result_hash"] ==
        "6450cbcf0a207d6f73a131d95038a8646e3a93f7b2f009f7ddfe83d07eafafb6"
    @test Set(artifact["missing_promotion_evidence"]) == Set(blocking_gates)
    @test artifact["source_hashes"]["quantitative_evidence_table"] ==
        bytes2hex(sha256(read(QUANTITATIVE_EVIDENCE_TABLE_PATH)))
    @test artifact["source_hashes"]["quantitative_evidence_schema"] ==
        bytes2hex(sha256(read(QUANTITATIVE_EVIDENCE_SCHEMA_PATH)))
    @test artifact["source_hashes"]["evidence_table_source"] ==
        bytes2hex(sha256(read(joinpath(PROJECT_ROOT, "src", "evidence_table.jl"))))
    @test artifact["source_hashes"]["laser_icf_qd_v15"] ==
        bytes2hex(sha256(read(LASER_ICF_QD_V15_PATH)))
    @test isfile(QUANTITATIVE_EVIDENCE_SUMMARY_PATH)
end

@testset "Versioned family, mission, and evidence-gap routing v16" begin
    @test bytes2hex(sha256(read(joinpath(PROJECT_ROOT, "src", "genome.jl")))) ==
        "251ffd0f325cd06f57a9ac96ec311e6644a2ae72b881b12e280189dae66470a5"
    @test bytes2hex(sha256(read(joinpath(PROJECT_ROOT, "src", "registry.jl")))) ==
        "e92e59fc716ba35fda8879dcfda966d4196fc23cf21d20b0999d0e83db3785ed"

    base = default_family_registry()
    @test family_registry_hash(base) ==
        "952ad4576299b8939909aef127484b90fd3aa25412648117b78058c8f8aeb051"
    @test family_spec(base, "inertial_confinement_fusion") === nothing
    extensions = evidence_family_registry_v16()
    @test family_spec(extensions, "inertial_confinement_fusion") !== nothing
    @test family_spec(extensions, "inertial_electrostatic_confinement") !== nothing
    @test family_spec(base, "inertial_electrostatic_confinement") === nothing
    extension_manifest = family_extension_manifest(extensions)
    @test canonical_hash(extension_manifest) ==
        "5093e418f99a674360a083cd1dd67bcd8c5a1d3c463796d7041638f3e4b14070"
    @test Set(package["id"] for package in extension_manifest["packages"]) ==
        Set(["legacy_search_families_v16", "laser_icf_v15"])

    duplicate_registry = FamilyExtensionRegistry()
    register_extension!(duplicate_registry, laser_icf_family_extension_v15())
    @test_throws ArgumentError register_extension!(duplicate_registry,
        laser_icf_family_extension_v15())
    icf_spec = only(laser_icf_family_extension_v15().family_specs)
    collision = FamilyExtensionPackage("collision_v16", "1.0.0",
        "collision_overlay", [icf_spec], ["nif_target_gain_unity_2024"],
        "test collision must be rejected")
    @test_throws ArgumentError register_extension!(duplicate_registry, collision)

    mission_registry = default_mission_contract_registry()
    @test length(mission_registry.specs) == 8
    @test mission_contract_hash(mission_registry) ==
        "5d9de17d569177f4ad4d3b85e5a12ea3ad4bf74b50931979abad62d0727d60f1"
    v15 = FusionConceptAI._plain_json(JSON3.read(
        read(LASER_ICF_QD_V15_PATH, String), Dict{String,Any}))
    plant = parse_genome(first(v15["conditional_frontier"])["genome"])
    @test mission_contract_for(mission_registry, plant).id ==
        "net_electric_pulsed_v1"
    anchor_raw = deepcopy(plant.normalized)
    anchor_raw["mission"]["kind"] = "single_shot_target_gain_science"
    anchor = parse_genome(anchor_raw)
    @test mission_contract_for(mission_registry, anchor).id ==
        "single_shot_target_gain_pulsed_v1"
    compatible, reasons = mission_comparison_compatible(
        mission_registry, plant, anchor)
    @test compatible === false
    @test any(reason -> occursin("mission contracts differ", reason), reasons)

    table = load_quantitative_evidence_table(QUANTITATIVE_EVIDENCE_TABLE_PATH)
    v14 = FusionConceptAI._plain_json(JSON3.read(
        read(HIERARCHICAL_GATE_DISCOVERY_V14_PATH, String), Dict{String,Any}))
    first_run = run_evidence_gap_prioritization_v16(v14, v15, table)
    second_run = run_evidence_gap_prioritization_v16(v14, v15, table)
    first_dict = evidence_gap_prioritization_to_dict(first_run)
    second_dict = evidence_gap_prioritization_to_dict(second_run)
    @test canonical_hash(first_dict) == canonical_hash(second_dict)
    @test canonical_hash(first_dict) ==
        "d6833602db5328246755338092714897420ec4252049c2968503b099de9ac40d"
    @test first_dict["frontier_summary"]["candidate_count"] == 45
    @test first_dict["frontier_summary"]["family_counts"] == Dict(
        "inertial_confinement_fusion" => 27,
        "magnetic_mirror" => 12,
        "inertial_electrostatic_confinement" => 6)
    @test first_dict["frontier_summary"]["disposition_counts"] == Dict(
        "conditional_evidence_frontier" => 27,
        "parked_negative_net_at_fidelity0" => 18)
    @test first_dict["frontier_summary"]["five_gate_pass_count"] == 0
    @test length(first_dict["priorities"]) == 11
    @test first_dict["budget"]["selected_task_ids"] == [
        "icf_pulsed_chamber_clearing_validation_v16",
        "icf_direct_target_gain_lpi_validation_v16",
        "icf_fast_ignition_gain_transport_validation_v16",
        "icf_indirect_target_gain_validation_v16"]
    @test first_dict["budget"]["spent_cost_units"] == 29.0
    @test all(item -> item["active_candidate_count"] > 0,
        filter(item -> item["selected"], first_dict["priorities"]))
    @test first_dict["medium_fidelity_decision"][
        "authorized_candidate_count"] == 0
    @test isempty(first_dict["medium_fidelity_decision"]["review_queue"])
    @test all(candidate -> candidate["positive_net_power_closure_passed"] ===
        false, filter(candidate -> candidate["disposition"] ==
            "parked_negative_net_at_fidelity0",
            first_dict["frontier_candidates"]))

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(EVIDENCE_GAP_PRIORITIZATION_V16_PATH, String), Dict{String,Any}))
    @test artifact["result_hash"] ==
        "8f61c947038e22b952228167cc1fc0bd07aa872f0fb0c145e554fca2b02f1a51"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    @test artifact["determinism_audit"]["core_hash"] == canonical_hash(first_dict)
    @test artifact["sealed_base_source_hashes"]["genome_ir"] ==
        bytes2hex(sha256(read(joinpath(PROJECT_ROOT, "src", "genome.jl"))))
    @test artifact["sealed_base_source_hashes"]["family_registry"] ==
        bytes2hex(sha256(read(joinpath(PROJECT_ROOT, "src", "registry.jl"))))
    source_paths = Dict(
        "hierarchical_gate_discovery_v14" => HIERARCHICAL_GATE_DISCOVERY_V14_PATH,
        "laser_icf_qd_v15" => LASER_ICF_QD_V15_PATH,
        "quantitative_evidence_table" => QUANTITATIVE_EVIDENCE_TABLE_PATH,
        "extension_registry" => joinpath(PROJECT_ROOT, "src", "extension_registry.jl"),
        "laser_icf_extension" => joinpath(PROJECT_ROOT, "src", "adapters",
            "laser_icf_screen_v1.jl"),
        "evidence_gap_prioritization" => joinpath(PROJECT_ROOT, "src", "search",
            "evidence_gap_prioritization_v16.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "evidence_gap_prioritization_v16.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_evidence_gap_prioritization_v16.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    @test isfile(EVIDENCE_GAP_PRIORITIZATION_V16_SUMMARY_PATH)
    summary = read(EVIDENCE_GAP_PRIORITIZATION_V16_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Five-gate passes: 0", summary)
    @test occursin("not evidence", summary)
end

@testset "Five-layer attribute-graph topology grammar v17" begin
    catalog = default_topology_module_catalog_v17()
    @test length(catalog) == 116
    @test Dict(layer => count(item -> item.layer == layer, catalog)
        for layer in (:core, :field_source, :stability, :exhaust, :engineering)) ==
        Dict(:core => 15, :field_source => 29, :stability => 34,
            :exhaust => 23, :engineering => 15)
    @test topology_module_catalog_hash_v17(catalog) ==
        "b7a370a31b7d71a818d4afd93e221f88762724d0c912e6de2344a9ae8c2a275b"
    report = validate_topology_module_catalog_v17(catalog)
    @test report.valid
    @test isempty(report.errors)

    result_a = run_attribute_graph_grammar_v17(catalog = catalog,
        maximum_archive = 1000)
    result_b = run_attribute_graph_grammar_v17(catalog = catalog,
        maximum_archive = 1000)
    dict_a = attribute_graph_grammar_to_dict_v17(result_a)
    dict_b = attribute_graph_grammar_to_dict_v17(result_b)
    @test canonical_hash(dict_a) == canonical_hash(dict_b)
    @test canonical_hash(dict_a) ==
        "4d91697d5f1a18ef331b2d2c26b192a2f503f092a3ab762b28018aae581d64a4"
    @test result_a.compatible_assembly_count == 1129
    @test length(result_a.archive) == 1000
    @test length(result_a.compatible_family_counts) == 11
    @test length(result_a.archive_family_counts) == 11
    @test result_a.partial_extension_attempt_count == 8164
    @test result_a.rejected_partial_extension_count == 6606
    @test length(unique(getfield.(result_a.archive, :graph_hash))) == 1000
    @test length(unique(getfield.(result_a.archive, :assembly_id))) == 1000
    @test all(assembly -> length(assembly.module_ids) == 5 &&
        length(assembly.edges) >= 4 && !isempty(assembly.source_ids) &&
        !isempty(assembly.missing_required_evaluators), result_a.archive)
    @test sum(count for (reason, count) in result_a.rejection_reason_counts
        if occursin("forbidden", reason)) == 224

    by_id = Dict(item.id => item for item in catalog)
    valid_ids = ["tokamak_conventional", "tokamak_tf_pf_cs",
        "tokamak_q_shear", "xpoint_two_target",
        "fixed_external_superconducting"]
    valid = explain_topology_combination_v17(catalog, valid_ids)
    @test valid.valid
    @test length(valid.edges) >= 4
    @test "family:tokamak_axisymmetric" in valid.tags
    invalid_family = explain_topology_combination_v17(catalog,
        ["tokamak_conventional", "icf_direct_drive", "tokamak_q_shear",
            "xpoint_two_target", "fixed_external_superconducting"])
    @test !invalid_family.valid
    @test any(reason -> occursin("assembly_requires_exactly_one_family", reason) ||
        occursin("missing_required_any", reason), invalid_family.reason_codes)
    invalid_forbidden = validate_topology_assembly_v17([
        by_id["levitated_dipole"], by_id["dipole_levitated"],
        by_id["dipole_favorable_curvature"], by_id["dipole_outer_limiter"],
        by_id["fixed_external_superconducting"]])
    @test !invalid_forbidden.valid
    @test any(reason -> occursin("forbidden_tag", reason) &&
        occursin("coil_location:internal", reason), invalid_forbidden.reason_codes)
    unknown = explain_topology_combination_v17(catalog,
        ["unknown_v17_module"])
    @test !unknown.valid
    @test unknown.reason_codes == ["unknown_module_id:unknown_v17_module"]
    @test_throws ArgumentError run_attribute_graph_grammar_v17(
        catalog = catalog, maximum_archive = 999)

    policy = dict_a["evaluation_and_promotion_policy"]
    @test policy["physics_credit_count"] == 0
    @test policy["engineering_credit_count"] == 0
    @test policy["five_gate_pass_count"] == 0
    @test policy["medium_fidelity_authorized_count"] == 0
    @test isempty(policy["medium_fidelity_review_queue"])

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(ATTRIBUTE_GRAPH_GRAMMAR_V17_PATH, String), Dict{String,Any}))
    @test artifact["result_hash"] ==
        "76b2e9f93d3bf5c7a6f3fc0cc4ce79255435a3a949800acd62c4cd1d612a031b"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    @test artifact["determinism_audit"]["core_hash"] == canonical_hash(dict_a)
    @test artifact["generation_audit"]["compatible_assembly_count"] == 1129
    @test artifact["structural_qd_archive"]["assembly_count"] == 1000
    @test artifact["sealed_base_source_hashes"]["genome_ir"] ==
        "251ffd0f325cd06f57a9ac96ec311e6644a2ae72b881b12e280189dae66470a5"
    @test artifact["sealed_base_source_hashes"]["family_registry"] ==
        "e92e59fc716ba35fda8879dcfda966d4196fc23cf21d20b0999d0e83db3785ed"
    source_paths = Dict(
        "attribute_graph_grammar" => joinpath(PROJECT_ROOT, "src", "search",
            "attribute_graph_grammar_v17.jl"),
        "artifact_schema" => joinpath(PROJECT_ROOT, "schemas",
            "attribute_graph_grammar_v17.schema.json"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_attribute_graph_grammar_v17.jl"))
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    @test isfile(ATTRIBUTE_GRAPH_GRAMMAR_V17_SUMMARY_PATH)
    summary = read(ATTRIBUTE_GRAPH_GRAMMAR_V17_SUMMARY_PATH, String)
    @test occursin(artifact["result_hash"], summary)
    @test occursin("Compatible unique structures: 1129", summary)
    @test occursin("Five-gate passes: 0", summary)
end

@testset "V5 tokamak candidate-specific FreeGS rejection review" begin
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(V5_TOKAMAK_FREEGS_REVIEW_PATH, String), Dict{String,Any}))
    @test artifact["result_hash"] ==
        "e0d9adabaebcaad618b45d77374554bc93269fc43bbb8d25be41344b0ba9fadf"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    @test artifact["input_v5_result_hash"] ==
        "b787f77671f535cf3f737bc6e00bf787ea74b63f0426f732748edb5062637e90"
    @test artifact["parent_count"] == 3
    @test artifact["coarse_solve_count"] == 24
    @test artifact["coarse_completed_count"] == 23
    @test artifact["refined_solve_count"] == 6
    @test artifact["refined_completed_count"] == 6
    @test artifact["resolution_pass_count"] == 6
    @test artifact["qualified_count"] == 0
    selected = artifact["selected_refinements"]
    @test length(selected) == 6
    @test all(item -> item["refined"]["evaluation"]["status"] == "pass",
        selected)
    @test all(item -> item["resolution_audit"][
        "all_resolution_gates_passed"] === true, selected)
    @test all(item -> item["resolution_audit"][
        "qualified_for_next_evidence"] === false, selected)
    @test all(item -> !isempty(item["refined"]["review"]["failed_gates"]),
        selected)
    @test all(item -> "elongation_alignment" in item["refined"][
        "review"]["failed_gates"], selected)
    @test all(item -> "pf_additive_peak_field_proxy" in item["refined"][
        "review"]["failed_gates"], selected)
    source_paths = Dict(
        "input_v5" => SHARED_OUTER_ENVELOPE_QD_V5_ARTIFACT_PATH,
        "geometry_builder" => joinpath(PROJECT_ROOT, "src", "search",
            "cross_family_geometry_topology_v2.jl"),
        "freegs_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "tokamak_freegs_v1.jl"),
        "freegs_runner" => joinpath(PROJECT_ROOT, "scripts", "freegs_runner.py"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_v5_tokamak_freegs_review.jl"),
    )
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    @test isfile(V5_TOKAMAK_FREEGS_REVIEW_SUMMARY_PATH)
end

@testset "Failure-aware pulsed-compression topology QD v6" begin
    seeds = load_genomes(SEEDS_PATH)
    parent = only(filter(genome -> genome.family == "tokamak_axisymmetric",
        seeds))
    outer = only(filter(contract -> contract.id == "outer_reference_B4_v1",
        shared_outer_envelope_contracts_v1()))
    contract = pulsed_compression_contract_v1(outer)
    @test contract.maximum_convergence_ratio == 15.0
    @test contract.maximum_recovery_fraction == 0.50
    @test length(FusionConceptAI._pulsed_specs_v6()) == 6

    spec = PulsedTopologySpecV6("frc", "spherical_plasma_liner", "spherical")
    values = FusionConceptAI._pulsed_ranges_v6(spec, ntuple(_ -> 0.5, 14))
    candidate = build_pulsed_compression_genome_v6(parent, spec, values, outer)
    @test candidate.family == "magnetized_target_fusion"
    @test length(candidate.compression_systems) == 1
    @test only(candidate.compression_systems).target_region_ids ==
        ["magnetized_target"]
    @test validate_genome(candidate).valid
    @test validate_family(default_family_registry(), candidate).valid
    known = union(known_source_ids(joinpath(PROJECT_ROOT, "knowledge",
        "sources.json")), known_source_ids(joinpath(PROJECT_ROOT, "knowledge",
        "magnetized_target_v6_sources.json")))
    @test isempty(source_reference_errors(candidate, known))
    result = FusionConceptAI._pulsed_compression_result(
        PulsedCompressionScreenV1(contract), candidate)
    @test isempty(result["topology_graph_errors"])
    @test haskey(result["nominal"], "net_electric_energy_per_shot_J")
    @test haskey(result["nominal"], "average_net_electric_power_W")
    @test result["nominal"]["recovered_electric_energy_J"] <=
        contract.maximum_recovery_fraction *
        result["nominal"]["liner_kinetic_energy_J"] + 1.0e-9

    first_small = run_failure_aware_pulsed_qd_v6(seeds;
        acquisition_samples = 72, maximum_graph_elites = 36,
        elites_per_structural_stratum = 1)
    second_small = run_failure_aware_pulsed_qd_v6(seeds;
        acquisition_samples = 72, maximum_graph_elites = 36,
        elites_per_structural_stratum = 1)
    @test canonical_hash(first_small) == canonical_hash(second_small)
    @test first_small["contract_count"] == 6
    @test first_small["topology_count_per_contract"] == 6
    @test first_small["structural_stratum_count"] == 36
    @test first_small["explicit_graph_elite_count"] == 36
    @test all(record -> isempty(record["evaluation"][
        "topology_graph_errors"]), first_small["records"])

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(FAILURE_AWARE_PULSED_QD_V6_PATH, String), Dict{String,Any}))
    @test artifact["result_hash"] ==
        "bae955343667b2b0dc1ccbbb88284ccb14da6df8ac83c9aa5825f9352f8a43d9"
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    search = artifact["pulsed_qd"]
    @test search["acquisition_samples"] == 300000
    @test search["contract_count"] == 6
    @test search["topology_count_per_contract"] == 6
    @test search["structural_stratum_count"] == 36
    @test search["acquisition_archive_cell_count"] == 486
    @test search["acquisition_positive_average_net_count"] == 1287
    @test search["acquisition_nominal_physics_and_engineering_pass_count"] == 0
    @test search["explicit_graph_elite_count"] == 108
    @test search["explicit_graph_five_gate_pass_count"] == 0
    @test search["promotion_count"] == 0
    @test isempty(artifact["medium_fidelity_review_queue"])
    @test contains(artifact["medium_fidelity_decision"],
        "no radiation-MHD")
    pf = artifact["tokamak_pf_failure_prescreen"]
    @test pf["candidate_count"] == 3
    @test pf["prescreen_pass_count"] == 0
    @test all(record -> record["admission_status"] ==
        "rejected_before_freegs", pf["records"])
    @test all(record -> record["prescreen"][
        "additive_peak_field_proxy_T"] > 24.0, pf["records"])
    source_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "sealed_source_catalog" => joinpath(PROJECT_ROOT, "knowledge",
            "sources.json"),
        "magnetized_target_source_overlay" => joinpath(PROJECT_ROOT,
            "knowledge", "magnetized_target_v6_sources.json"),
        "pulsed_extension_schema" => joinpath(PROJECT_ROOT, "schemas",
            "pulsed_compression_extension_v6.schema.json"),
        "genome_ir" => joinpath(PROJECT_ROOT, "src", "genome.jl"),
        "pulsed_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "pulsed_compression_screen_v1.jl"),
        "pf_prescreen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "failure_aware_prescreen_v6.jl"),
        "pulsed_search" => joinpath(PROJECT_ROOT, "src", "search",
            "failure_aware_pulsed_qd_v6.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_failure_aware_pulsed_qd_v6.jl"),
    )
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    @test isfile(FAILURE_AWARE_PULSED_QD_V6_SUMMARY_PATH)
end

@testset "Causal-closed self-organized and dipole topology QD v7" begin
    seeds = load_genomes(SEEDS_PATH)
    parent = only(filter(genome -> genome.family == "tokamak_axisymmetric",
        seeds))
    overlay = FusionConceptAI._plain_json(JSON3.read(
        read(SELF_ORGANIZED_V7_SOURCES_PATH, String), Dict{String,Any}))
    overlay_ids = String[source["id"] for source in overlay["sources"]]
    @test overlay["catalog_version"] == "self_organized_v7_overlay_1.0.0"
    @test length(overlay_ids) == 7
    @test length(unique(overlay_ids)) == 7
    @test all(!isempty(source["claim_boundary"]) for source in
        overlay["sources"])

    known = union(known_source_ids(joinpath(PROJECT_ROOT, "knowledge",
        "sources.json")), Set(overlay_ids))
    specs = FusionConceptAI._sov7_specs()
    @test length(specs) == 12
    @test Set(spec.mechanism for spec in specs) == Set([
        "self_organized_qsh", "qsh_pulsed_poloidal_current_drive",
        "qsh_ppcd_boundary_mode_control", "levitated_inward_pinch"])
    for spec in specs
        base = FusionConceptAI._sov7_structural_base(parent, spec)
        @test validate_genome(base).valid
        @test validate_family(default_family_registry(), base).valid
        @test isempty(source_reference_errors(base, known))
    end

    midpoint = ntuple(_ -> 0.5, 21)
    spontaneous = FusionConceptAI._sov7_ranges(
        SelfOrganizedTopologySpecV7("reversed_field_pinch",
            "self_organized_qsh", 2), midpoint)
    ppcd = FusionConceptAI._sov7_ranges(
        SelfOrganizedTopologySpecV7("reversed_field_pinch",
            "qsh_pulsed_poloidal_current_drive", 2), midpoint)
    combined = FusionConceptAI._sov7_ranges(
        SelfOrganizedTopologySpecV7("reversed_field_pinch",
            "qsh_ppcd_boundary_mode_control", 2), midpoint)
    @test spontaneous["screen_current_profile_control"] == 0.0
    @test spontaneous["screen_ppcd_power"] == 0.0
    @test spontaneous["screen_boundary_feedback_strength"] == 0.0
    @test ppcd["screen_current_profile_control"] > 0.0
    @test ppcd["screen_ppcd_power"] > 0.0
    @test ppcd["screen_boundary_feedback_strength"] == 0.0
    @test combined["screen_boundary_feedback_strength"] >= 0.10
    @test combined["screen_boundary_control_power"] > 0.0

    small = run_self_organized_qd_v7(seeds;
        acquisition_samples = 144, maximum_graph_elites = 72,
        elites_per_structural_stratum = 1)
    @test small["contract_count"] == 6
    @test small["topology_count_per_contract"] == 12
    @test small["structural_stratum_count"] == 72
    @test small["explicit_graph_elite_count"] == 72
    @test all(record -> isempty(record["evaluation"][
        "topology_graph_errors"]), small["records"])

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(SELF_ORGANIZED_QD_V7_PATH, String), Dict{String,Any}))
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    search = artifact["self_organized_qd"]
    @test search["acquisition_samples"] == 300000
    @test search["contract_count"] == 6
    @test search["topology_count_per_contract"] == 12
    @test search["structural_stratum_count"] == 72
    @test search["acquisition_archive_cell_count"] == 1056
    @test search["acquisition_positive_net_count"] == 648
    @test search["acquisition_nominal_physics_and_engineering_pass_count"] == 4
    @test search["explicit_graph_elite_count"] == 216
    @test search["explicit_graph_positive_net_count"] == 16
    @test search["explicit_graph_five_gate_pass_count"] == 1
    @test search["promotion_count"] == 1
    promoted = only(filter(record -> record["promoted"] === true,
        search["records"]))
    @test promoted["design_id"] == "concept_00f5ca7bb037e6230fd2"
    @test promoted["mechanism"] == "qsh_ppcd_boundary_mode_control"
    @test promoted["evaluation"]["nominal"][
        "rfp_total_extrapolation_from_3ms_anchor"] > 400.0
    @test promoted["evaluation"]["nominal"]["declared_ppcd_power_W"] > 0.0
    @test promoted["evaluation"]["nominal"][
        "declared_boundary_control_power_W"] > 0.0
    @test promoted["evaluation"]["robustness"]["pass_count"] == 64
    @test promoted["evaluation"]["robustness"][
        "worst_minimum_normalized_margin"] > 0.07
    queue = only(artifact["medium_fidelity_review_queue"])
    @test queue["status"] == "queued_for_resistive_mhd_rfp_falsification"
    @test length(queue["blocking_unknowns"]) == 6
    withdrawal = artifact["preaudit_withdrawal"]
    @test withdrawal["withdrawn_promotion_count"] == 2
    @test all(record -> record["corrected_five_gate_pass"] === false &&
        record["corrected_current_profile_control_credit"] == 0.0,
        withdrawal["records"])

    source_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "sealed_source_catalog" => joinpath(PROJECT_ROOT, "knowledge",
            "sources.json"),
        "self_organized_source_overlay" => SELF_ORGANIZED_V7_SOURCES_PATH,
        "shared_outer_envelope_contract" => joinpath(PROJECT_ROOT, "src",
            "adapters", "shared_outer_envelope_screen_v1.jl"),
        "self_organized_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "self_organized_screen_v1.jl"),
        "self_organized_search" => joinpath(PROJECT_ROOT, "src", "search",
            "self_organized_qd_v7.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_self_organized_qd_v7.jl"),
    )
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    @test isfile(SELF_ORGANIZED_QD_V7_SUMMARY_PATH)
    summary = read(SELF_ORGANIZED_QD_V7_SUMMARY_PATH, String)
    @test contains(summary, artifact["result_hash"])
    @test contains(summary, "Promotions: 1")
    @test contains(summary, "falsify")
    @test contains(summary, "not evidence of a viable reactor")
end

@testset "RFP cylindrical current-profile admission review v1" begin
    overlay = FusionConceptAI._plain_json(JSON3.read(
        read(RFP_PROFILE_REVIEW_SOURCES_PATH, String), Dict{String,Any}))
    overlay_ids = String[source["id"] for source in overlay["sources"]]
    @test overlay["catalog_version"] ==
        "rfp_profile_review_v1_overlay_1.0.0"
    @test length(overlay_ids) == length(unique(overlay_ids)) == 4
    @test Set(overlay_ids) == Set([
        "rfp_sheq_martines_2011", "rfp_mpfm_shen_sprott_1991",
        "mrxmhd_spec_hudson_2012", "nimrod_sovinec_2004"])
    @test all(!isempty(source["claim_boundary"]) for source in
        overlay["sources"])

    v7 = FusionConceptAI._plain_json(JSON3.read(
        read(SELF_ORGANIZED_QD_V7_PATH, String), Dict{String,Any}))
    promoted = only(filter(record -> record["promoted"] === true,
        v7["self_organized_qd"]["records"]))
    genome = parse_genome(promoted["genome"])
    adapter = RFPCylindricalProfileReviewV1()
    spec = evaluator_spec(adapter)
    @test spec.id == "rfp_cylindrical_profile_review_v1"
    @test spec.fidelity == 1
    @test spec.claim_ceiling == "physics_proxy"
    @test evaluator_applicability(adapter, genome)[1]
    registry = EvaluatorRegistry()
    register!(registry, adapter)
    first_bundle = evaluate_design(registry, spec.id, genome)
    second_bundle = evaluate_design(registry, spec.id, genome)
    @test first_bundle.status == :fail
    @test first_bundle.run_hash == second_bundle.run_hash
    metrics = Dict(metric.metric_id => metric for metric in first_bundle.metrics)
    @test metrics["rfp_profile_numerical_convergence_passed"].value === true
    @test metrics["rfp_unconstrained_profile_theta0"].value ≈
        2.9729605334955647 rtol = 1.0e-8
    @test metrics["rfp_unconstrained_profile_alpha"].value ≈
        0.8312773106862436 rtol = 1.0e-8
    @test metrics["rfp_unconstrained_profile_alpha"].status == :fail
    @test metrics["rfp_unconstrained_boundary_residual_norm"].value < 1.0e-12
    @test metrics["rfp_axis_regular_profile_alpha"].value ≈ 1.000001
    @test metrics["rfp_axis_regular_boundary_residual_norm"].value ≈
        0.022613858410962827 rtol = 1.0e-7
    @test metrics["rfp_axis_regular_boundary_residual_norm"].status == :fail
    @test metrics["rfp_profile_review_disposition"].value ==
        "returned_to_profile_design_loop_before_3d_mhd"
    for id in ("rfp_ohmic_constraint_feasible",
            "rfp_helical_equilibrium_feasible",
            "rfp_secondary_tearing_spectrum_feasible",
            "rfp_ppcd_repeatable_sustainment_feasible",
            "rfp_reactor_scale_transport_feasible")
        @test metrics[id].status == :unknown
        @test metrics[id].value === nothing
    end

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(RFP_PROFILE_REVIEW_ARTIFACT_PATH, String), Dict{String,Any}))
    without_hash = deepcopy(artifact)
    delete!(without_hash, "artifact_hash")
    @test canonical_hash(without_hash) == artifact["artifact_hash"]
    @test artifact["artifact_hash"] ==
        "9ed7270d166087c88368aa1f0e7c79a2d12748add6c468140a1d0d6076a6c7d7"
    @test artifact["sealed_v7_input"]["result_hash"] == v7["result_hash"]
    @test artifact["evaluation"]["status"] == "fail"
    @test artifact["profile_review"]["gates"]["numerical_convergence"] === true
    @test artifact["profile_review"]["gates"][
        "axis_regular_boundary_reconstruction"] === false
    @test artifact["backend_route_audit"]["SPEC"]["execution_status"] ==
        "not_launched_profile_prerequisite_failed"
    @test artifact["backend_route_audit"]["NIMROD"]["execution_status"] ==
        "not_bundled_not_launched"
    source_paths = Dict(
        "rfp_profile_source_overlay" => RFP_PROFILE_REVIEW_SOURCES_PATH,
        "profile_adapter" => joinpath(PROJECT_ROOT, "src", "adapters",
            "rfp_cylindrical_profile_review_v1.jl"),
        "python_runner" => joinpath(PROJECT_ROOT, "scripts",
            "rfp_cylindrical_profile_runner.py"),
        "artifact_runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_v7_rfp_profile_review.jl"),
    )
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    @test isfile(RFP_PROFILE_REVIEW_SUMMARY_PATH)
    summary = read(RFP_PROFILE_REVIEW_SUMMARY_PATH, String)
    @test contains(summary, artifact["artifact_hash"])
    @test contains(summary, "returned_to_profile_design_loop_before_3d_mhd")
    @test contains(summary, "remain unknown, not failed")
end

@testset "Profile-coupled RFP topology QD v8" begin
    fine_reference = FusionConceptAI._pcrfp_profile_projection(
        2.585662841796875, 1.1033175837016715; steps = 384)
    base_reference = FusionConceptAI._pcrfp_profile_projection(
        2.585662841796875, 1.1033175837016715; steps = 96)
    @test fine_reference.reversal_parameter ≈ -0.3463904926416192 rtol = 1.0e-10
    @test fine_reference.pinch_parameter ≈ 1.9220889195748936 rtol = 1.0e-10
    @test abs(base_reference.reversal_parameter -
        fine_reference.reversal_parameter) < 3.0e-7
    @test abs(base_reference.pinch_parameter -
        fine_reference.pinch_parameter) < 3.0e-7
    @test_throws ArgumentError FusionConceptAI._pcrfp_profile_projection(2.0, 1.0)

    seeds = load_genomes(SEEDS_PATH)
    small_first = run_profile_coupled_rfp_qd_v8(seeds;
        acquisition_samples = 180, maximum_graph_elites = 54,
        elites_per_structural_stratum = 1)
    small_second = run_profile_coupled_rfp_qd_v8(seeds;
        acquisition_samples = 180, maximum_graph_elites = 54,
        elites_per_structural_stratum = 1)
    @test canonical_hash(small_first) == canonical_hash(small_second)
    @test small_first["contract_count"] == 6
    @test small_first["topology_count_per_contract"] == 9
    @test small_first["structural_stratum_count"] == 54
    @test small_first["explicit_graph_elite_count"] == 54
    @test small_first["profile_parameterization"][
        "F_and_Theta_are_independent_genes"] === false
    @test all(record -> isempty(record["evaluation"][
        "topology_graph_errors"]), small_first["records"])
    for record in small_first["records"]
        genome = parse_genome(record["genome"])
        profile = FusionConceptAI._pcrfp_profile_parameters(genome)
        @test profile.alpha >= 1.05
        @test abs(profile.reversal_residual) <= 1.0e-8
        @test abs(profile.pinch_residual) <= 1.0e-8
        source = only(filter(item -> occursin(
            "self_organized_plasma_current", item.kind), genome.field_sources))
        @test source.parameters["profile_alpha"].value ≈ profile.alpha
        @test source.parameters["profile_theta0"].value ≈ profile.theta0
    end

    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(PROFILE_COUPLED_RFP_QD_V8_PATH, String), Dict{String,Any}))
    without_hash = deepcopy(artifact)
    delete!(without_hash, "result_hash")
    @test canonical_hash(without_hash) == artifact["result_hash"]
    @test artifact["result_hash"] ==
        "e44aa9b557286f4cf90dd9486a9ab20be125b51d1fa76cde5dbac35441462451"
    search = artifact["profile_coupled_rfp_qd"]
    @test search["acquisition_samples"] == 300000
    @test search["contract_count"] == 6
    @test search["topology_count_per_contract"] == 9
    @test search["structural_stratum_count"] == 54
    @test search["acquisition_archive_cell_count"] == 1728
    @test search["acquisition_profile_domain_pass_count"] == 19756
    @test search["acquisition_positive_net_count"] == 635
    @test search["acquisition_nominal_physics_and_engineering_pass_count"] == 0
    @test search["explicit_graph_elite_count"] == 216
    @test search["explicit_graph_positive_net_count"] == 11
    @test search["explicit_graph_five_gate_pass_count"] == 0
    @test search["promotion_count"] == 0
    @test isempty(artifact["medium_fidelity_review_queue"])
    @test artifact["superseded_v7_candidate"]["disposition"] ==
        "returned_to_profile_design_loop_before_3d_mhd"
    audit = artifact["projection_resolution_audit"]
    @test audit["sample_count"] == 20000
    @test audit["in_domain_sample_count"] == 1310
    @test audit["passed"] === true
    @test audit["maximum_96_to_384_F_or_Theta_change"] < 3.0e-7
    @test audit["maximum_192_to_384_F_or_Theta_change"] < 2.0e-8
    @test all(record -> record["promoted"] === false, search["records"])
    @test all(record -> isempty(record["evaluation"][
        "topology_graph_errors"]), search["records"])
    source_paths = Dict(
        "seed_devices" => SEEDS_PATH,
        "sealed_source_catalog" => joinpath(PROJECT_ROOT, "knowledge",
            "sources.json"),
        "self_organized_source_overlay" => SELF_ORGANIZED_V7_SOURCES_PATH,
        "rfp_profile_source_overlay" => RFP_PROFILE_REVIEW_SOURCES_PATH,
        "profile_coupled_screen" => joinpath(PROJECT_ROOT, "src", "adapters",
            "profile_coupled_rfp_screen_v1.jl"),
        "profile_coupled_search" => joinpath(PROJECT_ROOT, "src", "search",
            "profile_coupled_rfp_qd_v8.jl"),
        "runner" => joinpath(PROJECT_ROOT, "scripts",
            "run_profile_coupled_rfp_qd_v8.jl"),
    )
    for (key, path) in source_paths
        @test artifact["source_hashes"][key] == bytes2hex(sha256(read(path)))
    end
    @test artifact["sealed_input_hashes"]["v7_rfp_profile_review"] ==
        bytes2hex(sha256(read(RFP_PROFILE_REVIEW_ARTIFACT_PATH)))
    @test isfile(PROFILE_COUPLED_RFP_QD_V8_SUMMARY_PATH)
    summary = read(PROFILE_COUPLED_RFP_QD_V8_SUMMARY_PATH, String)
    @test contains(summary, artifact["result_hash"])
    @test contains(summary, "Promotions: 0")
    @test contains(summary, "No profile-coupled RFP candidate passes")
end

@testset "DESC regularized rectangular-coil self-force and energy boundary" begin
    base = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_REGULARIZED_COIL_BASE_RAW_PATH, String), Dict{String,Any}))
    refined = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_REGULARIZED_COIL_REFINED_RAW_PATH, String), Dict{String,Any}))
    audit = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_REGULARIZED_COIL_AUDIT_PATH, String), Dict{String,Any}))
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_REGULARIZED_COIL_ARTIFACT_PATH, String), Dict{String,Any}))
    genome = parse_genome(artifact["genome"])
    adapter = StellaratorDESCRegularizedCoilForceV1()
    spec = evaluator_spec(adapter)
    @test spec.id == "stellarator_regularized_coil_force_desc_v1"
    @test spec.claim_ceiling == "physics_concept"
    @test spec.requirement_support["regularized_rectangular_coil_self_force"] == :proxy
    @test spec.requirement_support["coil_inductance"] == :proxy
    @test spec.requirement_support["coil_only_stored_magnetic_energy"] == :proxy
    @test evaluator_applicability(adapter, genome)[1]

    @test base["result_hash"] ==
        "5b6ab597c57a722a7932b48d97664bea327f721cd9b6b98e9368ac30d14ae99b"
    @test refined["result_hash"] ==
        "41a520deac7d7ec0fa0a9284412e262119c4534d1718ad874753fd17987382b8"
    @test base["all_comparison_gates_passed"] === true
    @test refined["all_comparison_gates_passed"] === true
    @test refined["circle_analytic_regression"][
        "regularized_field_relative_error"] < 1.0e-12
    @test refined["circle_analytic_regression"][
        "stable_self_inductance_relative_error"] < 1.0e-4
    @test refined["actual_coil_formula_crosscheck"]["relative_difference"] < 1.0e-4
    force = refined["force_proxy"]
    @test force["maximum_regularized_self_force_field_T"] ≈
        0.465858869051027 rtol = 1.0e-12
    @test force["maximum_self_lorentz_line_load_N_per_m"] ≈
        367716.577883794 rtol = 1.0e-12
    @test force["maximum_total_coil_lorentz_line_load_N_per_m"] ≈
        1232655.12077782 rtol = 1.0e-12
    @test force["geometry_diagnostics"]["maximum_width_times_curvature"] ≈
        0.0825545440333988 rtol = 1.0e-12
    @test force["peak_internal_conductor_field_computed"] === false
    energy = refined["inductance_and_energy"]
    @test energy["total_coil_only_stored_magnetic_energy_J"] ≈
        96230175.7435049 rtol = 1.0e-12
    @test energy["equivalent_common_current_inductance_H"] ≈
        0.000308903996311185 rtol = 1.0e-12
    @test energy["plasma_current_coupling_energy_computed"] === false
    @test refined["interpretation"]["engineering_feasibility_established"] === false

    @test audit["audit_hash"] ==
        "5ff298187072ead7d77eacb5ab7df7b451c1c58f6d65a8252caf0ccd219ad823"
    @test audit["all_passed"] === true
    @test all(values(audit["gates"]))
    @test audit["comparisons"]["maximum_self_line_load_relative_change"] < 1.0e-5
    @test audit["comparisons"]["maximum_total_line_load_relative_change"] < 0.001
    @test audit["comparisons"]["stored_energy_relative_change"] < 1.0e-6
    @test audit["interpretation"]["engineering_feasibility_established"] === false

    registry = EvaluatorRegistry()
    register!(registry, adapter)
    first_bundle = evaluate_design(registry, spec.id, genome)
    second_bundle = evaluate_design(registry, spec.id, genome)
    @test first_bundle.status == :pass
    @test first_bundle.run_hash == second_bundle.run_hash ==
        "aa20faf1eadff87803b962508176ed67361229912f9d9ab96a6cc0f2d0f3227e"
    metrics = Dict(metric.metric_id => metric for metric in first_bundle.metrics)
    @test metrics["regularized_rectangular_coil_force_resolution_audit_passed"].value === true
    @test metrics["regularized_coil_self_force_computed"].value === true
    @test metrics["coil_only_stored_magnetic_energy"].value ≈
        96.2301757435049 rtol = 1.0e-12
    @test metrics["maximum_total_coil_lorentz_line_load"].value ≈
        1232655.12077782 rtol = 1.0e-12
    for metric_id in ("peak_internal_conductor_field_computed",
            "plasma_current_field_at_conductor_computed",
            "structural_stress_or_strain_feasible",
            "thermal_or_superconducting_margin_feasible", "engineering_feasible")
        @test metrics[metric_id].status == :unknown
        @test metrics[metric_id].value === nothing
    end
    @test artifact["artifact_hash"] ==
        "b3c949805bf9405dffb6406914ea89373d2c22fef9f48ec44cefb4c79aae709d"
end

@testset "DESC rectangular-conductor internal peak-field boundary" begin
    raw = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_RECTANGULAR_INTERNAL_FIELD_RAW_PATH, String), Dict{String,Any}))
    initial = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_RECTANGULAR_INTERNAL_FIELD_INITIAL_AUDIT_PATH, String),
        Dict{String,Any}))
    convergence = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_RECTANGULAR_INTERNAL_FIELD_CONVERGENCE_PATH, String),
        Dict{String,Any}))
    completion = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_RECTANGULAR_INTERNAL_FIELD_COMPLETION_PATH, String),
        Dict{String,Any}))
    verification = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_RECTANGULAR_INTERNAL_FIELD_VERIFICATION_PATH, String),
        Dict{String,Any}))
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_RECTANGULAR_INTERNAL_FIELD_ARTIFACT_PATH, String),
        Dict{String,Any}))
    genome = parse_genome(artifact["genome"])
    adapter = StellaratorDESCRectangularInternalFieldV1()
    spec = evaluator_spec(adapter)
    @test spec.id == "stellarator_rectangular_internal_field_desc_v1"
    @test spec.claim_ceiling == "physics_concept"
    @test spec.requirement_support["rectangular_conductor_internal_field"] == :proxy
    @test spec.requirement_support["peak_conductor_magnetic_field"] == :proxy
    @test spec.requirement_support["plasma_current_field_at_conductor"] == :proxy
    @test evaluator_applicability(adapter, genome)[1]

    @test raw["input_hash"] ==
        "39cd24154c22c817d969678ec6fa6c80b0e57451c457b1daaa4811694a914d1c"
    @test raw["result_hash"] ==
        "8a32b00f2ea97eb4bcf846d00e5d0b49dcf634463069cc14ede04f4645be91e6"
    @test raw["all_comparison_gates_passed"] === true
    @test raw["straight_conductor_ampere_regression"]["relative_error"] < 1.0e-6
    @test raw["circle_center_field_regression"]["relative_vector_error"] < 2.0e-12
    @test raw["force_average_regression"]["relative_vector_error"] < 1.0e-9
    peak = raw["sampled_internal_field"]["global_maximum"]
    @test peak["maximum_internal_self_field_T"] ≈ 5.079997192133039 rtol = 1.0e-12
    @test peak["maximum_other_coil_field_T"] ≈ 1.2290440233245816 rtol = 1.0e-12
    @test peak["maximum_plasma_current_field_T"] ≈ 0.6571780785163521 rtol = 1.0e-12
    @test peak["maximum_coil_only_internal_field_T"] ≈ 6.2896355422128725 rtol = 1.0e-12
    @test peak["maximum_total_internal_field_T"] ≈ 6.619208551337325 rtol = 1.0e-12
    @test peak["unique_representative_coil_index"] == 0
    @test abs(peak["maximum_location"]["u"]) == 1.0
    @test raw["interpretation"]["sampled_peak_total_field_including_plasma_computed"] === true
    @test raw["interpretation"]["superconductor_critical_surface_margin_computed"] === false
    @test raw["interpretation"]["engineering_feasibility_established"] === false

    @test initial["audit_hash"] ==
        "40ed4e39e3feb536f0c24957c971c00cb17acf98790d0ed5db969e569e1e49a6"
    @test convergence["verification_hash"] ==
        "af21635bcefcc92ffe4bbe756a3f344aebc11b7f53acdfb371727f079a8f2c0b"
    @test completion["audit_hash"] ==
        "4e3076e9a657e34461573f01046de61e2ce49cf7c7e7e62e03faa9827311c63b"
    @test initial["all_passed"] === false
    @test convergence["all_passed"] === false
    @test completion["all_passed"] === false
    @test convergence["gates"][
        "maximum_plasma_current_field_resolution_accepted"] === false
    @test completion["gates"][
        "maximum_plasma_current_field_resolution_accepted"] === false
    @test verification["verification_hash"] ==
        "617b1938233bd9bbf61e14e5712289e5647e2d521567652b030fd36a28a6e03d"
    @test verification["all_passed"] === true
    @test all(values(verification["gates"]))
    @test verification["comparisons"][
        "maximum_plasma_current_field_relative_change"] ≈
        0.0325521413822631 rtol = 1.0e-12
    @test verification["comparisons"][
        "maximum_total_internal_field_relative_change"] < 0.001
    @test verification["interpretation"][
        "peak_internal_conductor_field_continuous_upper_bound"] === false
    @test verification["interpretation"][
        "superconductor_critical_surface_margin_computed"] === false

    registry = EvaluatorRegistry()
    register!(registry, adapter)
    first_bundle = evaluate_design(registry, spec.id, genome)
    second_bundle = evaluate_design(registry, spec.id, genome)
    @test first_bundle.status == :pass
    @test first_bundle.run_hash == second_bundle.run_hash ==
        "a9315e2b0d9ffdf57c53d6e9c9aa70589540454c0e9df5593d13fe39dc030fb8"
    metrics = Dict(metric.metric_id => metric for metric in first_bundle.metrics)
    @test metrics["rectangular_internal_field_resolution_verified"].value === true
    @test metrics["peak_internal_conductor_field_computed"].value === true
    @test metrics["plasma_current_field_at_conductor_computed"].value === true
    @test metrics["maximum_total_internal_field_including_plasma"].value ≈
        6.619208551337325 rtol = 1.0e-12
    for metric_id in ("winding_turns_or_tapes_resolved",
            "nonuniform_current_distribution_computed",
            "superconductor_critical_surface_margin_feasible",
            "structural_stress_or_strain_feasible",
            "thermal_or_quench_margin_feasible", "engineering_feasible")
        @test metrics[metric_id].status == :unknown
        @test metrics[metric_id].value === nothing
    end
    @test artifact["artifact_hash"] ==
        "54a476d80a3dcf3b43ed6683fb5cbe36289cc46b4050b27f8e751b4d90dd9b56"
end

@testset "DESC sampled stellarator stability evidence and claim boundary" begin
    seeds = load_genomes(SEEDS_PATH)
    parent = only(filter(item -> item.design_id == "w7x_mechanism_seed", seeds))
    tokamak = only(filter(item -> item.design_id == "lmc_iter_proxy_seed", seeds))
    proposal_plan = plan_stellarator_fourier_pilot(parent)
    promoted = promoted_stellarator_fourier_proposals(proposal_plan)
    genome = promoted[3].genome
    @test genome.physics_hash ==
        "65c9e9e06828818bea259dafe18fd011e8a9c8232365f8061fb509c31702fdfe"

    adapter = StellaratorDESCStabilityV1(DESC_PYTHON)
    spec = evaluator_spec(adapter)
    @test spec.id == "stellarator_sampled_ideal_mhd_stability_desc_v1"
    @test spec.fidelity == 1
    @test spec.claim_ceiling == "physics_concept"
    @test evaluator_applicability(adapter, genome)[1]
    @test !evaluator_applicability(adapter, parent)[1]
    @test !evaluator_applicability(adapter, tokamak)[1]
    input = FusionConceptAI._desc_stability_input(genome)
    @test input["equilibrium_solver_input"]["resolution"] == Dict{String,Any}(
        "L" => 6, "M" => 6, "N" => 4,
        "L_grid" => 12, "M_grid" => 12, "N_grid" => 8)
    @test input["equilibrium_solver_input"]["solver"]["max_iterations"] == 40
    @test input["stability"]["mercier"]["angular_m"] == 12
    @test input["stability"]["mercier"]["angular_n"] == 9
    @test input["stability"]["ballooning"]["alpha_count"] == 8
    @test input["stability"]["ballooning"]["nzetaperturn"] == 128
    registry = EvaluatorRegistry()
    register!(registry, adapter)
    coverage = Dict(item.requirement => item.support
        for item in coverage_report(registry, genome))
    @test coverage["mercier"] == :proxy
    @test coverage["ballooning"] == :proxy
    @test coverage["neoclassical_transport"] == :missing

    coarse_medium = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_STABILITY_COARSE_MEDIUM_AUDIT_PATH, String), Dict{String,Any}))
    @test coarse_medium["all_passed"] === false
    @test coarse_medium["base"]["mercier"]["sampled_favorable"] === false
    @test coarse_medium["refined"]["mercier"]["sampled_favorable"] === true
    @test coarse_medium["comparisons"]["mercier_edge_base_normalized"] < 0
    @test coarse_medium["comparisons"]["mercier_edge_refined_normalized"] > 0
    @test coarse_medium["gates"]["mercier_edge_unfavorable_at_both_resolutions"] ===
        false

    audit = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_STABILITY_MEDIUM_FINE_AUDIT_PATH, String), Dict{String,Any}))
    @test audit["all_passed"] === true
    @test all(values(audit["gates"]))
    @test audit["audit_hash"] ==
        "ceca3f119861e751e1258ee5b80fe68e8fd3a580df09a0b087e044263757318c"
    @test audit["comparisons"]["mercier_minimum_medium_normalized"] ≈
        0.002344553403239794 rtol = 1.0e-12
    @test audit["comparisons"]["mercier_minimum_fine_normalized"] ≈
        0.0023750641253310243 rtol = 1.0e-12
    @test audit["comparisons"]["ballooning_maximum_medium"] < -1.0e-5
    @test audit["comparisons"]["ballooning_maximum_fine"] < -1.0e-5
    @test audit["interpretation"]["all_mode_plasma_stability_established"] === false

    medium = coarse_medium["refined"]
    raw = Dict{String,Any}(
        "status" => "pass",
        "runner_version" => FusionConceptAI._DESC_STABILITY_RUNNER_VERSION,
        "claim_boundary" => FusionConceptAI._DESC_STABILITY_CLAIM_BOUNDARY,
        "physics_hash" => genome.physics_hash,
        "input_hash" => medium["input_hash"],
        "result_hash" => medium["result_hash"],
        "environment" => medium["environment"],
        "equilibrium" => medium["equilibrium"],
        "equilibrium_reference" => Dict{String,Any}(
            "provided" => false, "matched" => nothing,
            "maximum_relative_difference" => nothing),
        "mercier" => medium["mercier"],
        "ballooning" => medium["ballooning"],
        "local_ideal_mhd" => medium["local_ideal_mhd"],
        "warnings" => medium["warnings"],
    )
    bundle = FusionConceptAI._desc_stability_bundle_from_raw(
        adapter, genome, medium["input"], raw)
    @test bundle.status == :pass
    metrics = Dict(metric.metric_id => metric for metric in bundle.metrics)
    @test metrics["sampled_stability_computation_completed"].value === true
    @test metrics["sampled_mercier_favorable"].value === true
    @test metrics["minimum_sampled_mercier_D_normalized"].value ≈
        0.002344553403239794 rtol = 1.0e-12
    @test metrics["sampled_infinite_n_ballooning_favorable"].value === true
    @test metrics["maximum_sampled_infinite_n_ballooning_lambda"].value ≈
        -0.00040594236754676327 rtol = 1.0e-12
    @test metrics["sampled_local_ideal_mhd_favorable"].value === true
    @test all(metrics[id].status == :unknown for id in
        ["sampled_stability_resolution_converged", "mercier_stability_feasible",
            "ballooning_stability_feasible", "plasma_stability_feasible",
            "minimum_stability_margin"])
    @test all(metrics[id].value === nothing for id in
        ["sampled_stability_resolution_converged", "mercier_stability_feasible",
            "ballooning_stability_feasible", "plasma_stability_feasible",
            "minimum_stability_margin"])
    @test Set(metrics["sampled_mercier_favorable"].source_basis) == Set([
        "desc_software_0_17_3", "landreman_jorge_mercier_2020",
        "gaur_omnigenous_stability_2024"])

    pilot = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_STABILITY_MEDIUM_PILOT_PATH, String), Dict{String,Any}))
    pilot_raw = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_STABILITY_MEDIUM_PILOT_RAW_PATH, String), Dict{String,Any}))
    @test pilot["search_version"] ==
        "stellarator_sampled_stability_medium_pilot_v1"
    @test pilot["candidate_count"] == 4
    @test pilot["completed_evaluation_count"] == 4
    @test pilot["medium_sampled_favorable_count"] == 3
    @test pilot["resolution_audited_favorable_count"] == 1
    @test pilot["all_mode_plasma_stability_established_count"] == 0
    @test pilot["first_principles_eligible_count"] == 0
    @test pilot["pilot_hash"] ==
        "7d85bfe357fb1fb8e130ccca33d353c4991b8b50ccf04fc0ee0efa77a302a23e"
    @test pilot["batch_hash"] == pilot_raw["batch_hash"]
    @test pilot_raw["completed_stability_count"] == 4
    @test pilot_raw["sampled_favorable_count"] == 3
    @test pilot_raw["status_counts"] == Dict{String,Any}("pass" => 4)
    by_nfp = Dict(Int(item["field_periods"]) => item for item in pilot["candidates"])
    @test by_nfp[2]["resolution_audit_status"] == "passed_medium_to_fine"
    @test by_nfp[2]["medium_sampled_local_ideal_mhd_favorable"] === true
    @test by_nfp[4]["medium_sampled_local_ideal_mhd_favorable"] === false
    @test all(item["first_principles_readiness"]["eligible"] === false
        for item in pilot["candidates"])
    @test all(any(metric["metric_id"] == "plasma_stability_feasible" &&
        metric["status"] == "unknown" for metric in item["evaluation"]["metrics"])
        for item in pilot["candidates"])

    observations = StellaratorStabilityObservation[
        stellarator_stability_observation_from_dict(proposal_plan,
            item["evaluation"];
            resolution_audited = item["resolution_audit_status"] ==
                "passed_medium_to_fine")
        for item in pilot["candidates"]
    ]
    active_first = plan_stellarator_stability_active_learning(proposal_plan,
        observations)
    active_second = plan_stellarator_stability_active_learning(proposal_plan,
        reverse(observations))
    active_dict = stellarator_stability_active_learning_plan_to_dict(active_first)
    @test active_first.chosen_lengthscale == 0.55
    @test active_first.mercier_loo_rmse ≈ 0.5075461561664427 rtol = 1.0e-12
    @test active_first.ballooning_loo_rmse ≈ 0.2634294601358591 rtol = 1.0e-12
    @test getfield.(getfield.(active_first.acquisitions, :proposal), :pool_index) ==
        [11, 13, 16, 14]
    @test Set(getfield.(getfield.(getfield.(active_first.acquisitions, :proposal),
        :build_spec), :field_periods)) == Set([2, 3, 4, 5])
    @test canonical_hash(active_dict) ==
        "690cf75a066aa493d853bc8eb4e11f44531b7d7809760b1e013ea0997a75b602"
    @test canonical_hash(active_dict) == canonical_hash(
        stellarator_stability_active_learning_plan_to_dict(active_second))
    @test all(item["physical_evidence_status"] == "not_evaluated"
        for item in active_dict["acquisitions"])
    @test occursin("not plasma-stability evidence", active_dict["claim_boundary"])
    @test_throws ArgumentError plan_stellarator_stability_active_learning(
        proposal_plan, observations[1:3])
    @test_throws ArgumentError StellaratorStabilityActiveLearningConfig(
        medium_noise_variance = 1.0e-8,
        audited_noise_variance = 1.0e-6)

    stored_plan = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_STABILITY_ACTIVE_PLAN_PATH, String), Dict{String,Any}))
    active_raw = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_STABILITY_ACTIVE_RAW_PATH, String), Dict{String,Any}))
    active_results = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_STABILITY_ACTIVE_RESULTS_PATH, String), Dict{String,Any}))
    @test stored_plan["plan_hash"] ==
        "0df261c392d90e0a9658bb8e0ec53f8449058bdac52d476fdc4f657567ac6320"
    @test stored_plan["training_observation_count"] == 4
    @test getindex.(stored_plan["acquisitions"], "pool_index") == [11, 13, 16, 14]
    @test all(item["physical_evidence_status"] == "not_evaluated"
        for item in stored_plan["acquisitions"])
    @test active_raw["completed_stability_count"] == 4
    @test active_raw["sampled_favorable_count"] == 3
    @test active_results["plan_hash"] == stored_plan["plan_hash"]
    @test active_results["plan_file_sha256"] ==
        bytes2hex(sha256(read(DESC_STABILITY_ACTIVE_PLAN_PATH)))
    @test active_results["medium_sampled_favorable_count"] == 3
    @test active_results["first_principles_eligible_count"] == 0
    @test active_results["all_mode_plasma_stability_established_count"] == 0
    @test active_results["round_hash"] ==
        "1e97acc023c4efae5ed8fb03b647982a108cd26ac12c0340c88749196fc1eaa3"
    active_by_pool = Dict(Int(item["pool_index"]) => item
        for item in active_results["records"])
    @test active_by_pool[11]["prediction"]["joint_scaled_margin"] > 0
    @test active_by_pool[11]["observation"]["joint_scaled_margin"] < 0
    @test active_by_pool[11]["observation"][
        "medium_sampled_local_ideal_mhd_favorable"] === false
    @test all(active_by_pool[index]["observation"][
        "medium_sampled_local_ideal_mhd_favorable"] === true
        for index in [13, 16, 14])
    @test getindex.(active_results[
        "round3_acquisition_plan_not_yet_evaluated"]["acquisitions"],
        "pool_index") == [9, 12, 10, 7]
    @test all(any(metric["metric_id"] == "plasma_stability_feasible" &&
        metric["status"] == "unknown" && metric["value"] === nothing
        for metric in item["evaluation"]["metrics"])
        for item in active_results["records"])

    active_audit = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_STABILITY_ACTIVE_AUDIT_PATH, String), Dict{String,Any}))
    @test active_audit["audit_hash"] ==
        "f33cd526c660a6f604d251a69530f70209068db3928a21e81e37cfc7effb2ee4"
    @test active_audit["target"]["physics_hash"] ==
        "8bc6df1ccf3cb758a4b76ee207315de6df8f31a15ae631dbb5d057f4a451dd6a"
    @test active_audit["all_passed"] === true
    @test all(values(active_audit["gates"]))
    @test active_audit["comparisons"]["mercier_minimum_medium_normalized"] ≈
        0.013180805351159149 rtol = 1.0e-12
    @test active_audit["comparisons"]["mercier_minimum_fine_normalized"] ≈
        0.013680382770779844 rtol = 1.0e-12
    @test active_audit["comparisons"]["ballooning_maximum_medium"] < -1.0e-5
    @test active_audit["comparisons"]["ballooning_maximum_fine"] < -1.0e-5
    @test active_audit["interpretation"][
        "all_mode_plasma_stability_established"] === false
end

@testset "DESC continuous surface-current proxy and engineering boundary" begin
    pilot = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_SURFACE_CURRENT_PILOT_PATH, String), Dict{String,Any}))
    batch_input = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_SURFACE_CURRENT_INPUT_PATH, String), Dict{String,Any}))
    batch_raw = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_SURFACE_CURRENT_RAW_PATH, String), Dict{String,Any}))
    pool8_audit = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_SURFACE_CURRENT_POOL8_AUDIT_PATH, String), Dict{String,Any}))
    pool16_audit = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_SURFACE_CURRENT_POOL16_AUDIT_PATH, String), Dict{String,Any}))

    @test pilot["pilot_version"] == "stellarator_surface_current_proxy_pilot_v1"
    @test pilot["candidate_count"] == 2
    @test pilot["completed_evaluation_count"] == 2
    @test pilot["reference_normalized_bn_rms_met_count"] == 2
    @test pilot["resolution_audited_proxy_count"] == 1
    @test pilot["discrete_coils_created_count"] == 0
    @test pilot["engineering_feasibility_established_count"] == 0
    @test pilot["first_principles_eligible_count"] == 0
    @test pilot["pilot_hash"] ==
        "b81235b9f079faade33a25ffcf8625f18e9da0a9bbdd4be0eb5e117a314164e0"
    @test batch_raw["candidate_count"] == 2
    @test batch_raw["completed_proxy_count"] == 2
    @test batch_raw["reference_normalized_bn_rms_met_count"] == 2
    @test batch_raw["status_counts"] == Dict{String,Any}("pass" => 2)
    @test batch_raw["batch_hash"] == pilot["batch_hash"]
    @test batch_input["selection_basis"] ==
        "The only two generated candidates with passed medium-to-fine sampled Mercier and infinite-n ballooning audits; not selected by a coil proxy."

    @test pool8_audit["audit_hash"] ==
        "64f67141fa53cb325174aabe8d1a9b3bf299bf68c64939d6f86d8f565d12104c"
    @test pool8_audit["all_passed"] === false
    @test sort!(String[key for (key, value) in pool8_audit["gates"]
        if value !== true]) == ["normalized_bn_rms_profile_change_accepted"]
    @test pool8_audit["comparisons"][
        "normalized_bn_rms_profile_max_absolute_change"] ≈
        0.0326201947496277 rtol = 1.0e-12
    @test pool16_audit["audit_hash"] ==
        "115a22fdb3133e3fa16a78c4b1779f4d36a8e8e2d806872f100a8e1d34a484e2"
    @test pool16_audit["all_passed"] === true
    @test all(values(pool16_audit["gates"]))
    @test pool16_audit["comparisons"][
        "normalized_bn_rms_profile_max_absolute_change"] ≈
        0.007282156812474839 rtol = 1.0e-12
    @test all(audit["interpretation"]["discrete_coils_created"] === false &&
        audit["interpretation"]["engineering_feasibility_established"] === false
        for audit in (pool8_audit, pool16_audit))

    adapter = StellaratorDESCSurfaceCurrentV1(DESC_PYTHON)
    spec = evaluator_spec(adapter)
    @test spec.id == "stellarator_surface_current_regcoil_desc_v1"
    @test spec.claim_ceiling == "physics_concept"
    @test spec.requirement_support["finite_build_coils"] == :proxy
    input_by_hash = Dict(String(item["physics_hash"]) => item
        for item in batch_input["candidates"])
    for record in pilot["records"]
        genome = parse_genome(record["genome"])
        @test evaluator_applicability(adapter, genome)[1]
        @test input_by_hash[genome.physics_hash]["surface_current_input"] ==
            FusionConceptAI._desc_surface_current_input(genome)
        @test record["evaluation"]["evaluator_id"] == spec.id
        @test record["evaluation"]["input_hash"] == genome.physics_hash
        @test record["first_principles_readiness"]["eligible"] === false
        metrics = Dict(String(metric["metric_id"]) => metric
            for metric in record["evaluation"]["metrics"])
        @test metrics["continuous_surface_current_computation_completed"]["value"] === true
        @test metrics["surface_current_reference_normalized_bn_rms_met"]["value"] === true
        @test metrics["surface_current_regularization_scan_count"]["value"] == 12
        @test Set(String.(metrics[
            "minimum_continuous_surface_current_bn_rms_normalized"]["source_basis"])) ==
            Set(["desc_software_0_17_3", "landreman_regcoil_2017",
                "desc_regcoil_tutorial_0_17_3"])
        for metric_id in ("surface_current_resolution_converged",
                "finite_build_coils_feasible", "discrete_coil_geometry_feasible",
                "device_complexity_index", "engineering_feasible")
            @test metrics[metric_id]["status"] == "unknown"
            @test metrics[metric_id]["value"] === nothing
        end
    end
end

@testset "DESC unoptimized discrete-coil contours and failed resolution audit" begin
    input = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_DISCRETE_COIL_INPUT_PATH, String), Dict{String,Any}))
    raw = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_DISCRETE_COIL_RAW_PATH, String), Dict{String,Any}))
    audit = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_DISCRETE_COIL_AUDIT_PATH, String), Dict{String,Any}))
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_DISCRETE_COIL_ARTIFACT_PATH, String), Dict{String,Any}))
    genome = parse_genome(artifact["genome"])
    @test genome.physics_hash ==
        "8bc6df1ccf3cb758a4b76ee207315de6df8f31a15ae631dbb5d057f4a451dd6a"
    adapter = StellaratorDESCDiscreteCoilCutV1(DESC_PYTHON)
    spec = evaluator_spec(adapter)
    @test spec.id == "stellarator_discrete_coil_cut_desc_v1"
    @test spec.claim_ceiling == "physics_concept"
    @test spec.requirement_support["finite_discrete_coil_contours"] == :full
    @test spec.requirement_support["finite_build_coils"] == :proxy
    @test evaluator_applicability(adapter, genome)[1]
    @test input == FusionConceptAI._desc_discrete_coil_cut_input(adapter, genome)

    @test raw["status"] == "pass"
    @test raw["result_hash"] ==
        "9f2179538f16806f61213f80b3e542fb5e02a269c56fd33c2def127a6f8ce850"
    @test raw["discrete_coils_created"] === true
    @test raw["coil_shape_optimization_performed"] === false
    @test raw["discrete_coil_geometry_feasibility_established"] === false
    @test raw["engineering_feasibility_established"] === false
    @test !haskey(raw, "elapsed_seconds")
    @test getindex.(raw["cuts"], "total_physical_coil_count") == [16, 24, 32]
    @test getindex.(raw["cuts"],
        "bn_total_rms_normalized_by_area_mean_B") ≈
        [0.2586154112881648, 0.11764213335793429,
            0.07707624047872338] rtol = 1.0e-12
    @test all(cut["all_integrity_gates_passed"] === true for cut in raw["cuts"])
    @test all(cut["comparison_references"][
        "normalized_bn_rms_reference_met"] === false for cut in raw["cuts"])

    @test audit["audit_hash"] ==
        "238197d831cffb70e27acee2e27baa0110746f7bcdfcf8856c439e63dffae5e3"
    @test audit["all_passed"] === false
    @test sort!(String[key for (key, value) in audit["gates"]
        if value !== true]) ==
        ["bn_rms_change_accepted", "maximum_curvature_change_accepted"]
    @test audit["interpretation"][
        "one_percent_bn_reference_met_by_any_cut"] === false
    @test audit["interpretation"][
        "unoptimized_discrete_contour_metrics_resolution_audited"] === false
    @test maximum(Float64(item["bn_rms_normalized_absolute_change"])
        for item in audit["comparisons"]) ≈
        0.028222970037894785 rtol = 1.0e-12

    bundle = FusionConceptAI._desc_discrete_coil_cut_bundle_from_raw(
        adapter, genome, input, raw, audit)
    @test bundle.status == :pass
    metrics = Dict(metric.metric_id => metric for metric in bundle.metrics)
    @test metrics["discrete_coil_contours_created"].value === true
    @test metrics["coil_shape_optimization_performed"].value === false
    @test metrics["minimum_unoptimized_discrete_coil_bn_rms_normalized"].value ≈
        0.07707624047872338 rtol = 1.0e-12
    @test metrics["continuous_to_discrete_bn_degradation_factor"].value > 10
    @test metrics["best_bn_cut_total_physical_coil_count"].value == 32
    @test metrics["unoptimized_discrete_coil_resolution_audit_passed"].status == :fail
    @test metrics["unoptimized_discrete_coil_resolution_audit_passed"].value === false
    for metric_id in ("unoptimized_discrete_coil_resolution_converged",
            "minimum_total_physical_coil_count_meeting_bn_reference",
            "discrete_coil_geometry_feasible", "finite_build_coils_feasible",
            "device_complexity_index", "engineering_feasible")
        @test metrics[metric_id].status == :unknown
        @test metrics[metric_id].value === nothing
    end
    @test Set(metrics["discrete_coil_contours_created"].source_basis) == Set([
        "desc_software_0_17_3", "landreman_regcoil_2017",
        "desc_regcoil_tutorial_0_17_3"])

    @test artifact["artifact_version"] ==
        "stellarator_discrete_coil_cut_proxy_v1"
    @test artifact["artifact_hash"] ==
        "6ec5968cb2972e9a6eab61c1223ae791f39e00fdeb5258f5ebb4084b8ed23e90"
    @test artifact["counts"]["candidate_count"] == 1
    @test artifact["counts"]["discrete_coils_created_count"] == 1
    @test artifact["counts"]["bn_reference_met_count"] == 0
    @test artifact["counts"]["resolution_audited_count"] == 0
    @test artifact["counts"]["geometry_feasibility_established_count"] == 0
    @test artifact["counts"]["engineering_feasibility_established_count"] == 0
    @test artifact["counts"]["first_principles_eligible_count"] == 0
end

@testset "DESC optimized filament coils, refined audit, and tolerance boundary" begin
    raw = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_OPTIMIZED_COIL_RAW_PATH, String), Dict{String,Any}))
    repair = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_OPTIMIZED_COIL_REPAIR_PATH, String), Dict{String,Any}))
    resolution = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_OPTIMIZED_COIL_RESOLUTION_PATH, String), Dict{String,Any}))
    tolerance = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_OPTIMIZED_COIL_TOLERANCE_PATH, String), Dict{String,Any}))
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_OPTIMIZED_COIL_ARTIFACT_PATH, String), Dict{String,Any}))
    genome = parse_genome(artifact["genome"])
    adapter = StellaratorDESCDiscreteCoilOptimizationV1()
    spec = evaluator_spec(adapter)
    @test spec.id == "stellarator_discrete_coil_optimization_desc_v1"
    @test spec.claim_ceiling == "physics_concept"
    @test spec.requirement_support["optimized_filament_coils"] == :full
    @test spec.requirement_support["line_current_geometry"] == :full
    @test spec.requirement_support["finite_build_coils"] == :proxy
    @test spec.requirement_support["assembly_tolerance"] == :proxy
    @test evaluator_applicability(adapter, genome)[1]

    @test raw["result_hash"] ==
        "87c3be3bf1fb309f99fbde70debae4191ad8b53e5b7ab282e164de1fc95e284e"
    @test raw["solver"]["success"] === true
    @test raw["base_margin_candidate_accepted"] === false
    @test sort!(String[key for (key, value) in raw["margin_geometry_gates"]
        if value !== true]) == ["maximum_length_met"]
    @test repair["result_hash"] ==
        "7ca03f5c44d050bab7f3664c19c5f3797c68bff8796e80b7c5a2e1c1d6fdae60"
    @test repair["maximum_sampled_accepted_fraction"] == 0.99999
    @test repair["base_repair_candidate_accepted"] === true
    @test repair["selected_metrics"]["maximum_unique_coil_length_m"] < 4.895
    @test repair["selected_cumulative_bn_relative_improvement"] > 0.52

    @test resolution["audit_hash"] ==
        "01d3110164e7041303d4ad59f984eb609f01dd1f8681fba6d04a29a3ca152e9c"
    @test resolution["all_passed"] === true
    @test all(values(resolution["gates"]))
    @test resolution["refined"][
        "bn_total_rms_normalized_by_area_mean_B"] ≈
        0.012892086981280857 rtol = 1.0e-12
    @test resolution["comparisons"][
        "refined_bn_relative_improvement_from_refined_source"] ≈
        0.508309905565809 rtol = 1.0e-12
    @test resolution["interpretation"]["one_percent_bn_reference_met"] === false

    @test tolerance["audit_hash"] ==
        "3512b62c6f47c964ad951306ff6240ec34b237bb2479e613b3a484b2a715888d"
    @test tolerance["candidate_one_mm_tolerance_screen_accepted"] === true
    @test tolerance["summaries"]["one_mm"]["accepted_sample_count"] == 4
    @test isempty(tolerance["summaries"]["one_mm"]["failed_gate_names"])
    @test tolerance["three_mm_stress_screen_accepted"] === false
    @test tolerance["summaries"]["three_mm"]["accepted_sample_count"] == 0
    @test Set(tolerance["summaries"]["three_mm"]["failed_gate_names"]) ==
        Set(["maximum_abs_torsion_met", "maximum_length_met"])
    @test tolerance["interpretation"][
        "statistical_manufacturing_tolerance_established"] === false
    @test tolerance["interpretation"][
        "finite_build_coils_feasibility_established"] === false
    @test tolerance["interpretation"]["engineering_feasibility_established"] ===
        false

    registry = EvaluatorRegistry()
    register!(registry, adapter)
    first_bundle = evaluate_design(registry, spec.id, genome)
    second_bundle = evaluate_design(registry, spec.id, genome)
    @test first_bundle.status == :pass
    @test first_bundle.run_hash == second_bundle.run_hash ==
        "c1ace22c5e3e94d832a338c69da15a76efc683d5ee0d509081940bb5e0db6b05"
    metrics = Dict(metric.metric_id => metric for metric in first_bundle.metrics)
    @test metrics["optimized_discrete_line_current_geometry_feasible"].value === true
    @test metrics["optimized_discrete_coil_resolution_audit_passed"].value === true
    @test metrics["deterministic_one_mm_tolerance_screen_passed"].value === true
    @test metrics["deterministic_three_mm_stress_screen_passed"].value === false
    @test metrics["deterministic_three_mm_stress_screen_passed"].status == :fail
    @test metrics["optimized_discrete_coil_count"].value == 48
    @test metrics["refined_normalized_bn_rms_from_discrete_coils"].value ≈
        0.012892086981280857 rtol = 1.0e-12
    @test metrics["one_mm_maximum_relative_bn_degradation"].value ≈
        0.0010580381167559771 rtol = 1.0e-12
    for metric_id in ("statistical_manufacturing_tolerance_established",
            "finite_build_coils_feasible", "device_complexity_index",
            "engineering_feasible")
        @test metrics[metric_id].status == :unknown
        @test metrics[metric_id].value === nothing
    end

    @test artifact["artifact_hash"] ==
        "4420b236bb01d9c118aeca16dbdc9576759d2b93344da9f3390409a63025af01"
    @test artifact["counts"]["resolution_audited_line_current_geometry_count"] == 1
    @test artifact["counts"]["one_mm_deterministic_screen_passed_count"] == 1
    @test artifact["counts"]["three_mm_deterministic_screen_passed_count"] == 0
    @test artifact["counts"]["finite_build_coils_feasibility_established_count"] == 0
    @test artifact["counts"]["engineering_feasibility_established_count"] == 0
    @test artifact["first_principles_readiness"]["eligible"] === false
end

@testset "DESC Boozer spectrum and low-order effective-ripple boundary" begin
    base = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_TRANSPORT_BASE_RAW_PATH, String), Dict{String,Any}))
    refined = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_TRANSPORT_REFINED_RAW_PATH, String), Dict{String,Any}))
    audit = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_TRANSPORT_AUDIT_PATH, String), Dict{String,Any}))
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_TRANSPORT_ARTIFACT_PATH, String), Dict{String,Any}))
    genome = parse_genome(artifact["genome"])
    adapter = StellaratorDESCTransportProxyV1()
    spec = evaluator_spec(adapter)
    @test spec.id == "stellarator_qs_effective_ripple_desc_v1"
    @test spec.claim_ceiling == "physics_concept"
    @test spec.requirement_support["boozer_transform"] == :full
    @test spec.requirement_support["sampled_quasisymmetry_spectrum"] == :full
    @test spec.requirement_support["neoclassical_transport"] == :proxy
    @test evaluator_applicability(adapter, genome)[1]

    @test base["result_hash"] ==
        "0ea2d21f2e0a164ce4d4f994f9443a9ce5676df98fe794071e887d088cf9f65b"
    @test refined["result_hash"] ==
        "d5460ed1ec5db1f8cca925224f58e7d701e79a85b4e6f5c888a24745aba877ba"
    @test base["equilibrium_reference"]["matched"] === true
    @test refined["equilibrium_reference"]["matched"] === true
    @test refined["environment"]["jax_finufft_available"] === false
    @test refined["interpretation"]["high_order_bounce2d_available"] === false
    @test refined["interpretation"][
        "neoclassical_transport_feasibility_established"] === false
    qa = only(filter(item -> item["helicity_M"] == 1 && item["helicity_N"] == 0,
        refined["quasisymmetry"]["records"]))
    qh = only(filter(item -> item["helicity_M"] == 1 && item["helicity_N"] == 2,
        refined["quasisymmetry"]["records"]))
    @test qa["rms_normalized_symmetry_breaking"] ≈
        0.0115126748236351 rtol = 1.0e-12
    @test qh["rms_normalized_symmetry_breaking"] ≈
        0.0959559811998826 rtol = 1.0e-12
    @test refined["effective_ripple"]["maximum_effective_ripple"] ≈
        0.007480818674709714 rtol = 1.0e-12
    @test refined["effective_ripple"][
        "all_sampled_radii_meet_comparison_reference"] === true

    @test audit["audit_hash"] ==
        "147691ca94968a7e871904c5279c294264a88096014b2885f89b369c903d584a"
    @test audit["all_passed"] === true
    @test all(values(audit["gates"]))
    @test audit["maximum_qs_normalized_absolute_change"] < 1.0e-12
    @test audit["effective_ripple_comparison"]["maximum_absolute_change"] ≈
        0.0018537650032334635 rtol = 1.0e-12
    @test audit["interpretation"]["high_order_bounce2d_available"] === false
    @test audit["interpretation"]["transport_feasibility_established"] === false

    registry = EvaluatorRegistry()
    register!(registry, adapter)
    first_bundle = evaluate_design(registry, spec.id, genome)
    second_bundle = evaluate_design(registry, spec.id, genome)
    @test first_bundle.status == :pass
    @test first_bundle.run_hash == second_bundle.run_hash ==
        "cba3496c257662e2ef781c8c10edbd79297ccb4927aab1a26a383ff9fe75a838"
    metrics = Dict(metric.metric_id => metric for metric in first_bundle.metrics)
    @test metrics["sampled_boozer_spectrum_resolution_audit_passed"].value === true
    @test metrics["low_order_effective_ripple_resolution_audit_passed"].value === true
    @test metrics["low_order_effective_ripple_reference_met"].value === true
    @test metrics["high_order_bounce2d_available"].value === false
    @test metrics["high_order_bounce2d_available"].status == :fail
    for metric_id in ("quasisymmetry_established", "drift_kinetic_transport_solved",
            "neoclassical_transport_feasible", "alpha_orbits_feasible",
            "transport_feasible")
        @test metrics[metric_id].status == :unknown
        @test metrics[metric_id].value === nothing
    end
    @test artifact["artifact_hash"] ==
        "7ae66e641f4208f821c7191179939ab7e6d5bb0590990841ad82fa26d6931c75"
end

@testset "DESC finite-build winding-pack electromagnetic proxy boundary" begin
    base = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_FINITE_BUILD_BASE_RAW_PATH, String), Dict{String,Any}))
    refined = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_FINITE_BUILD_REFINED_RAW_PATH, String), Dict{String,Any}))
    audit = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_FINITE_BUILD_AUDIT_PATH, String), Dict{String,Any}))
    artifact = FusionConceptAI._plain_json(JSON3.read(
        read(DESC_FINITE_BUILD_ARTIFACT_PATH, String), Dict{String,Any}))
    genome = parse_genome(artifact["genome"])
    adapter = StellaratorDESCFiniteBuildCoilProxyV1()
    spec = evaluator_spec(adapter)
    @test spec.id == "stellarator_finite_build_coil_proxy_desc_v1"
    @test spec.claim_ceiling == "physics_concept"
    @test spec.requirement_support["finite_build_coils"] == :proxy
    @test spec.requirement_support["winding_pack_clearance"] == :proxy
    @test spec.requirement_support["mutual_coil_electromagnetic_load"] == :proxy
    @test evaluator_applicability(adapter, genome)[1]

    @test base["result_hash"] ==
        "2b168c053f373142e42ee2c3a5fbda500def09c5cda5a2e3edcf3ac787484e09"
    @test refined["result_hash"] ==
        "e3d9ae65d414a9ffa7e625cd3b70e7934461bfbc415466db403d21f5a2001b28"
    @test base["all_comparison_gates_passed"] === true
    @test refined["all_comparison_gates_passed"] === true
    @test length(base["scan_records"]) == 4
    @test length(refined["scan_records"]) == 1
    anchor = only(refined["scan_records"])
    @test anchor["width_m"] == 0.06
    @test anchor["finite_build_correction_normalized_bn_rms"] ≈
        3.258379753883665e-5 rtol = 1.0e-12
    @test anchor["finite_build_normalized_bn_rms_upper_bound"] ≈
        0.012924670778819694 rtol = 1.0e-12
    @test anchor["equivalent_winding_pack_engineering_current_density_MA_per_m2"] ≈
        219.25846690506123 rtol = 1.0e-12
    @test anchor[
        "circumscribed_pack_minimum_coil_coil_clearance_lower_bound_m"] ≈
        0.2370201809073499 rtol = 1.0e-12
    @test anchor[
        "circumscribed_pack_minimum_plasma_coil_clearance_lower_bound_m"] ≈
        0.20098722371802563 rtol = 1.0e-12
    @test anchor["mutual_coil_proxy"][
        "maximum_mutual_coil_field_at_centerline_T"] ≈
        1.09863198618453 rtol = 1.0e-12
    @test anchor["mutual_coil_proxy"][
        "maximum_mutual_coil_lorentz_line_load_N_per_m"] ≈
        865743.2510713037 rtol = 1.0e-12
    @test refined["interpretation"]["self_field_or_self_force_computed"] === false
    @test refined["interpretation"]["engineering_feasibility_established"] === false

    @test audit["audit_hash"] ==
        "283c0785b6fa166bdbc8b9d5318ddc11c833bcfb5974d9119822d1b7f584ab5a"
    @test audit["all_passed"] === true
    @test all(values(audit["gates"]))
    @test audit["comparisons"][
        "anchor_finite_build_correction_absolute_change"] ≈
        1.9342040941194586e-6 rtol = 1.0e-12
    @test audit["comparisons"][
        "anchor_maximum_mutual_field_relative_change"] < 0.001
    @test audit["comparisons"][
        "anchor_maximum_mutual_line_load_relative_change"] < 0.001
    @test audit["interpretation"]["all_widths_resolution_audited"] === false
    @test audit["interpretation"]["engineering_feasibility_established"] === false

    registry = EvaluatorRegistry()
    register!(registry, adapter)
    first_bundle = evaluate_design(registry, spec.id, genome)
    second_bundle = evaluate_design(registry, spec.id, genome)
    @test first_bundle.status == :pass
    @test first_bundle.run_hash == second_bundle.run_hash ==
        "e5ba64c0d216fbc0115d003e04f3ff5ae2d8d2ac56d047731a2442386144ed8f"
    metrics = Dict(metric.metric_id => metric for metric in first_bundle.metrics)
    @test metrics["finite_build_winding_pack_scan_completed"].value === true
    @test metrics["finite_build_anchor_resolution_audit_passed"].value === true
    @test metrics["refined_finite_build_bn_comparison_reference_met"].value === true
    @test metrics["maximum_mutual_coil_lorentz_line_load"].value ≈
        865743.2510713037 rtol = 1.0e-12
    for metric_id in ("winding_pack_orientation_optimized",
            "coil_self_field_or_self_force_computed",
            "structural_stress_or_strain_feasible",
            "thermal_or_superconducting_margin_feasible", "engineering_feasible")
        @test metrics[metric_id].status == :unknown
        @test metrics[metric_id].value === nothing
    end
    @test artifact["artifact_hash"] ==
        "1ca0c2a6c9b6308933dcf0c2a67ec59cd3bb1925fea0f53e8d4246bfd3eb99d7"
end

FusionConceptAI.evaluator_spec(evaluator::SchedulerFixtureEvaluator) =
    EvaluatorSpec(evaluator.id, "1.0.0", evaluator.families, 1,
        Dict{String,Symbol}(), "physics_proxy")

function source_tree_hash(root)
    io = IOBuffer()
    for path in sort!(filter(path -> endswith(path, ".jl"), readdir(root; join = true)))
        write(io, basename(path), UInt8(0), read(path), UInt8(0))
    end
    return bytes2hex(sha256(take!(io)))
end

@testset "Public Pleiades Fidelity-1 WHAM isotropic regression" begin
    genome = load_genome(PLEIADES_REGRESSION_PATH)
    seeds = load_genomes(SEEDS_PATH)
    wham_seed = only(filter(item -> item.design_id == "wham_mechanism_seed", seeds))
    beam_seed = only(filter(item -> item.design_id == "beam_2024_concept_seed", seeds))
    iter_seed = only(filter(item -> item.design_id == "lmc_iter_proxy_seed", seeds))
    @test validate_genome(genome).valid
    @test validate_family(default_family_registry(), genome).valid
    @test isfile(PLEIADES_PYTHON)

    adapter = MirrorPleiadesWHAMIsotropicV1(PLEIADES_PYTHON)
    spec = evaluator_spec(adapter)
    @test spec.fidelity == 1
    @test spec.claim_ceiling == "physics_concept"
    @test evaluator_applicability(adapter, genome)[1]
    @test !evaluator_applicability(adapter, wham_seed)[1]
    @test !evaluator_applicability(adapter, beam_seed)[1]
    @test !evaluator_applicability(adapter, iter_seed)[1]

    registry = EvaluatorRegistry()
    register!(registry, adapter)
    coverage = coverage_report(registry, genome)
    support = Dict(item.requirement => item.support for item in coverage)
    @test length(coverage) == 16
    @test count(==( :full), values(support)) == 3
    @test all(requirement -> support[requirement] == :full,
        ["axisymmetric_green_function_fields", "isotropic_mirror_equilibrium",
            "finite_beta_equilibrium"])
    @test all(requirement -> support[requirement] == :missing,
        ["anisotropic_mirror_equilibrium", "interchange_growth", "ballooning",
            "dclc", "aic", "electron_heat_loss", "ion_end_loss",
            "neutral_recycling", "end_plate_heat_flux", "finite_build_coils",
            "coil_stress", "quench", "stray_field"])

    first_result = evaluate_design(registry, spec.id, genome)
    second_result = evaluate_design(registry, spec.id, genome)
    @test first_result.status == :pass
    @test first_result.run_hash == second_result.run_hash
    @test first_result.claim_ceiling == "physics_concept"
    @test length(first_result.warnings) == length(unique(first_result.warnings))
    metrics = Dict(metric.metric_id => metric for metric in first_result.metrics)
    @test metrics["axisymmetric_vacuum_field_feasible"].value === true
    @test metrics["isotropic_equilibrium_converged"].value === true
    @test metrics["finite_beta_equilibrium_feasible"].value === true
    @test metrics["equilibrium_iteration_count"].value == 6
    @test metrics["fixed_point_flux_residual_l2"].value ≈
        4.453294830169993e-14 rtol = 1.0e-10
    @test metrics["finite_difference_force_balance_relative_l2"].value ≈
        0.023947068638570365 rtol = 1.0e-10
    @test metrics["vacuum_center_field"].value ≈
        1.1856924536510536 rtol = 1.0e-12
    @test metrics["vacuum_sampled_mirror_ratio"].value ≈
        13.292099424640927 rtol = 1.0e-12
    @test metrics["prescribed_axis_pressure"].value ≈
        55937.65446638264 rtol = 1.0e-12
    @test metrics["anisotropic_equilibrium_feasible"].status == :unknown
    @test metrics["plasma_stability_feasible"].status == :unknown
    @test metrics["particle_confinement_time"].status == :unknown
    @test metrics["fusion_gain"].status == :unknown
    @test metrics["engineering_feasible"].status == :unknown

    prepared = prepare_candidate(genome, [first_result],
        first_principles_discovery_contract())
    @test !prepared.eligible
    @test any(reason -> occursin("fuel D-D", reason), prepared.reasons)
    @test any(reason -> occursin("plasma_stability_feasible", reason),
        prepared.reasons)

    raw = deepcopy(genome.normalized)
    raw["plasma_regions"][1]["parameters"]["nr"]["value"] = 32
    wrong_grid = parse_genome(raw)
    @test !evaluator_applicability(adapter, wrong_grid)[1]
    @test evaluate_design(registry, spec.id, wrong_grid).status == :not_applicable
end

@testset "DESC Fidelity-1 packaged W7-X regression" begin
    genome = load_genome(DESC_REGRESSION_PATH)
    seeds = load_genomes(SEEDS_PATH)
    w7x_seed = only(filter(item -> item.design_id == "w7x_mechanism_seed", seeds))
    iter_seed = only(filter(item -> item.design_id == "lmc_iter_proxy_seed", seeds))
    @test validate_genome(genome).valid
    @test validate_family(default_family_registry(), genome).valid
    @test isfile(DESC_PYTHON)

    adapter = StellaratorDESCW7XRegressionV1(DESC_PYTHON)
    spec = evaluator_spec(adapter)
    @test spec.fidelity == 1
    @test spec.claim_ceiling == "physics_concept"
    @test evaluator_applicability(adapter, genome)[1]
    @test !evaluator_applicability(adapter, w7x_seed)[1]
    @test !evaluator_applicability(adapter, iter_seed)[1]

    registry = EvaluatorRegistry()
    register!(registry, adapter)
    coverage = coverage_report(registry, genome)
    support = Dict(item.requirement => item.support for item in coverage)
    @test length(coverage) == 16
    @test count(==( :full), values(support)) == 3
    @test all(requirement -> support[requirement] == :full,
        ["vmec_or_desc", "finite_beta_equilibrium",
            "three_dimensional_force_balance"])
    @test all(requirement -> support[requirement] == :missing,
        ["mercier", "ballooning", "neoclassical_transport", "alpha_orbits",
            "coil_curvature", "peak_heat_flux"])

    first_result = evaluate_design(registry, spec.id, genome)
    second_result = evaluate_design(registry, spec.id, genome)
    @test first_result.status == :pass
    @test first_result.run_hash == second_result.run_hash
    @test first_result.claim_ceiling == "physics_concept"
    @test length(first_result.warnings) == length(unique(first_result.warnings))
    metrics = Dict(metric.metric_id => metric for metric in first_result.metrics)
    @test metrics["fixed_boundary_equilibrium_converged"].value === true
    @test metrics["three_dimensional_force_balance_feasible"].value === true
    @test metrics["equilibrium_iteration_count"].value == 3
    @test metrics["force_balance_residual_normalized_magnetic"].value ≈
        0.002847257131102358 rtol = 1.0e-10
    @test metrics["plasma_volume"].value ≈ 27.847963261733724 rtol = 1.0e-12
    @test metrics["volume_average_beta"].value ≈
        0.020234576915476737 rtol = 1.0e-10
    @test metrics["aspect_ratio"].value ≈ 10.897943829865405 rtol = 1.0e-12
    @test metrics["plasma_stability_feasible"].status == :unknown
    @test metrics["mercier_stability_feasible"].status == :unknown
    @test metrics["neoclassical_transport_feasible"].status == :unknown
    @test metrics["engineering_feasible"].status == :unknown

    prepared = prepare_candidate(genome, [first_result],
        first_principles_discovery_contract())
    @test !prepared.eligible
    @test any(reason -> occursin("fuel D-D", reason), prepared.reasons)
    @test any(reason -> occursin("plasma_stability_feasible", reason),
        prepared.reasons)

    raw = deepcopy(genome.normalized)
    raw["symmetry"]["field_periods"] = 4
    wrong_period = parse_genome(raw)
    @test !evaluator_applicability(adapter, wrong_period)[1]
    @test evaluate_design(registry, spec.id, wrong_period).status == :not_applicable
end

@testset "DESC Fidelity-1 explicit Fourier search candidate" begin
    seeds = load_genomes(SEEDS_PATH)
    parent = only(filter(item -> item.design_id == "w7x_mechanism_seed", seeds))
    tokamak = only(filter(item -> item.design_id == "lmc_iter_proxy_seed", seeds))
    w7x_regression = load_genome(DESC_REGRESSION_PATH)
    spec = StellaratorFourierBuildSpec()
    first_genome = build_stellarator_fourier_genome(parent, spec)
    second_genome = build_stellarator_fourier_genome(parent, spec)

    @test first_genome.design_id == "stellarator_fourier_631ee08ba888bc04"
    @test first_genome.physics_hash ==
        "e492f4b1f7763da63b44d284ea8f971a3c7b208478de58ebeb0595e3a5e8f854"
    @test first_genome.physics_hash == second_genome.physics_hash
    @test validate_genome(first_genome).valid
    @test validate_family(default_family_registry(), first_genome).valid
    known = known_source_ids(joinpath(PROJECT_ROOT, "knowledge", "sources.json"))
    @test isempty(source_reference_errors(first_genome, known))
    @test first_genome.provenance.origin == "generated"
    @test first_genome.provenance.claim_level == "structural_example"
    @test first_genome.provenance.parent_design_ids == [parent.design_id]
    @test Quantity(1.25, "Wb").value == 1.25
    @test Quantity(1.25, "Wb").unit == "Wb"
    @test_throws ArgumentError StellaratorFourierBuildSpec(field_periods = 1)
    @test_throws ArgumentError StellaratorFourierBuildSpec(
        major_radius_m = 1.0, minor_radius_r_m = 0.5)
    @test_throws ArgumentError StellaratorFourierBuildSpec(
        iota_axis = 0.45, iota_edge = -0.6)
    @test_throws ArgumentError build_stellarator_fourier_genome(tokamak, spec)

    adapter = StellaratorDESCFourierV1(DESC_PYTHON)
    adapter_spec = evaluator_spec(adapter)
    @test adapter_spec.fidelity == 1
    @test adapter_spec.claim_ceiling == "physics_concept"
    @test evaluator_applicability(adapter, first_genome)[1]
    @test !evaluator_applicability(adapter, parent)[1]
    @test !evaluator_applicability(adapter, w7x_regression)[1]
    @test !evaluator_applicability(adapter, tokamak)[1]
    expected_input = FusionConceptAI._plain_json(
        JSON3.read(read(DESC_FOURIER_INPUT_PATH, String)))
    # JSON3 may materialize integral-valued JSON decimals as Int, while the
    # adapter retains Float64 coefficients. Julia equality is numeric here and
    # still compares every key, array element, and value in the input contract.
    @test FusionConceptAI._desc_fourier_inputs(first_genome) == expected_input

    wrong_flux_raw = deepcopy(first_genome.normalized)
    wrong_flux_core = only(filter(item -> item["id"] == "fourier_stellarator_core",
        wrong_flux_raw["plasma_regions"]))
    wrong_flux_core["parameters"]["toroidal_flux"]["value"] += 0.1
    @test !evaluator_applicability(adapter, parse_genome(wrong_flux_raw))[1]
    wrong_symmetry_raw = deepcopy(first_genome.normalized)
    wrong_symmetry_raw["symmetry"]["class"] = "minimum_b"
    @test !evaluator_applicability(adapter, parse_genome(wrong_symmetry_raw))[1]

    registry = EvaluatorRegistry()
    register!(registry, adapter)
    coverage = coverage_report(registry, first_genome)
    support = Dict(item.requirement => item.support for item in coverage)
    @test count(==( :full), values(support)) == 4
    @test all(requirement -> support[requirement] == :full,
        ["explicit_fourier_boundary", "vmec_or_desc",
            "finite_beta_equilibrium", "three_dimensional_force_balance"])

    result = evaluate_design(registry, adapter_spec.id, first_genome)
    @test result.status == :pass
    @test result.claim_ceiling == "physics_concept"
    metrics = Dict(metric.metric_id => metric for metric in result.metrics)
    @test metrics["fixed_boundary_equilibrium_converged"].value === true
    @test metrics["three_dimensional_force_balance_feasible"].value === true
    @test metrics["nested_flux_surfaces_feasible"].value === true
    @test metrics["positive_coordinate_jacobian_feasible"].value === true
    @test metrics["continuation_state_count"].value == 5
    @test metrics["boundary_mode_count"].value == 5
    @test metrics["force_balance_residual_normalized_magnetic"].value ≈
        0.0034007269962801345 rtol = 1.0e-8
    @test metrics["plasma_volume"].value ≈ 14.804406601652236 rtol = 1.0e-8
    @test metrics["aspect_ratio"].value ≈ 6.0 rtol = 1.0e-10
    @test metrics["field_peak_to_peak_over_mean_095"].value ≈
        0.4379417355588265 rtol = 1.0e-8
    @test all(id -> metrics[id].status == :unknown,
        ["plasma_stability_feasible", "minimum_stability_margin",
            "quasi_symmetry_error", "mercier_stability_feasible",
            "ballooning_stability_feasible", "neoclassical_transport_feasible",
            "fast_ion_confinement_feasible", "fusion_gain", "fusion_power",
            "device_complexity_index", "engineering_feasible",
            "net_electric_power"])
    prepared = prepare_candidate(first_genome, [result],
        first_principles_discovery_contract())
    @test !prepared.eligible

    audit = FusionConceptAI._plain_json(
        JSON3.read(read(DESC_FOURIER_AUDIT_PATH, String)))
    @test audit["all_passed"] === true
    @test all(values(audit["gates"]))
    @test audit["comparisons"]["plasma_volume_relative_change"] < 0.02
    @test audit["comparisons"]["volume_average_beta_relative_change"] < 0.05
    @test audit["comparisons"]["force_residual_refined"] <
        audit["comparisons"]["force_residual_base"]
    @test occursin("not proof", audit["claim_boundary"])
end

@testset "Bounded stellarator Fourier Fidelity-1 pilot search" begin
    seeds = load_genomes(SEEDS_PATH)
    parent = only(filter(item -> item.design_id == "w7x_mechanism_seed", seeds))
    tokamak = only(filter(item -> item.design_id == "lmc_iter_proxy_seed", seeds))
    config = StellaratorFourierPilotConfig()
    first_plan = plan_stellarator_fourier_pilot(parent; config = config)
    second_plan = plan_stellarator_fourier_pilot(parent; config = config)
    first_dict = stellarator_fourier_pilot_plan_to_dict(first_plan)
    second_dict = stellarator_fourier_pilot_plan_to_dict(second_plan)
    @test length(first_plan.proposals) == 16
    @test first_plan.promotion_count == 4
    @test canonical_hash(first_dict) == canonical_hash(second_dict)
    @test canonical_hash(first_dict) ==
        "3b1472cfd8b03f93c9e499625133475189f81bebff6d90fff263fdd9547d89f7"
    @test length(unique(item.genome.physics_hash for item in first_plan.proposals)) == 16
    @test all(item -> validate_genome(item.genome).valid, first_plan.proposals)
    @test all(item -> validate_family(default_family_registry(), item.genome).valid,
        first_plan.proposals)
    promoted = promoted_stellarator_fourier_proposals(first_plan)
    @test getfield.(promoted, :pool_index) == [6, 15, 8, 1]
    @test getfield.(promoted, :promotion_rank) == [1, 2, 3, 4]
    @test getfield.(getfield.(promoted, :build_spec), :field_periods) == [3, 5, 2, 4]
    @test getfield.(getfield.(promoted, :genome), :design_id) == [
        "stellarator_fourier_ac5c34be2b6275e5",
        "stellarator_fourier_ced5f0297610d4ac",
        "stellarator_fourier_8eebd0fff02ab6d1",
        "stellarator_fourier_8cfc61eb02be8e23",
    ]
    @test all(item -> item.acquisition_distance !== nothing, promoted)
    @test_throws ArgumentError StellaratorFourierPilotConfig(proposal_count = 3)
    @test_throws ArgumentError StellaratorFourierPilotConfig(
        proposal_count = 8, promotion_count = 9)
    @test_throws ArgumentError plan_stellarator_fourier_pilot(tokamak)

    pilot = FusionConceptAI._plain_json(
        JSON3.read(read(DESC_FOURIER_PILOT_PATH, String)))
    raw = FusionConceptAI._plain_json(
        JSON3.read(read(DESC_FOURIER_PILOT_RAW_PATH, String)))
    @test pilot["search_version"] == "stellarator_fourier_fidelity1_pilot_v1"
    @test pilot["proposal_count"] == 16
    @test pilot["promoted_count"] == 4
    @test pilot["completed_evaluation_count"] == 4
    @test pilot["accepted_equilibrium_count"] == 4
    @test pilot["first_principles_eligible_count"] == 0
    @test pilot["pilot_hash"] ==
        "61fe4c0efec651894fbc920fddefd6b644573833635dbf2f5c20808c237cf0e9"
    @test raw["accepted_equilibrium_count"] == 4
    @test raw["status_counts"] == Dict{String,Any}("pass" => 4)
    @test pilot["batch_hash"] == raw["batch_hash"]
    @test length(pilot["accepted_equilibrium_archive"]) == 4
    @test all(item -> occursin("not a merit ranking", item["claim_boundary"]),
        pilot["accepted_equilibrium_archive"])
    raw_by_hash = Dict(String(item["physics_hash"]) => item for item in raw["results"])
    for record in pilot["promoted_candidates"]
        @test record["solver_status"] == "pass"
        @test record["equilibrium_accepted"] === true
        @test record["first_principles_readiness"]["eligible"] === false
        @test record["evaluation"]["status"] == "pass"
        @test record["evaluation"]["input_hash"] == record["physics_hash"]
        evidence = completed_evidence_from_dict(record["evaluation"])
        @test evidence.task_id == "stellarator_fixed_boundary_desc_fourier_v1"
        @test startswith(evidence.task_version, "1.0.0+")
        solver_record = raw_by_hash[record["physics_hash"]]
        @test record["solver_result_hash"] ==
            solver_record["solver_result"]["result_hash"]
        unknown = filter(item -> item["status"] == "unknown",
            record["evaluation"]["metrics"])
        @test any(item -> item["metric_id"] == "plasma_stability_feasible", unknown)
        @test any(item -> item["metric_id"] == "engineering_feasible", unknown)
        @test any(item -> item["metric_id"] == "fusion_power", unknown)
    end
    @test pilot["observed_equilibrium_diagnostic_ranges"][
        "force_residual_normalized_magnetic"]["max"] < 0.01
    @test pilot["observed_equilibrium_diagnostic_ranges"][
        "minimum_sampled_sqrt_g"]["min"] > 1.0e-4
    @test bytes2hex(sha256(read(DESC_FOURIER_PILOT_PATH))) ==
        "9e74214a21c1bcf506909480d8505d374e4366ea9a315e26c4bc08b93d26f356"
end

function seed_objects()
    wrapper = JSON3.read(read(SEEDS_PATH, String), Dict{String,Any})
    return FusionConceptAI._plain_json(wrapper)["designs"]
end

function test_objective_bundle(genome; gain = 10.0, stability = 2.0,
        complexity = 5.0, engineering_feasible = true, fidelity = 0,
        uncertainty = 0.2, claim_ceiling = "physics_proxy",
        omit = Set{String}(), unknown = Set{String}())
    values = Dict(
        "fusion_gain_proxy" => gain,
        "stability_margin_proxy" => stability,
        "physical_complexity_proxy" => complexity,
    )
    run_hash = canonical_hash(Dict(
        "design" => genome.design_id,
        "values" => values,
        "engineering" => engineering_feasible,
        "fidelity" => fidelity,
        "uncertainty" => uncertainty,
        "claim" => claim_ceiling,
        "omit" => sort!(collect(omit)),
        "unknown" => sort!(collect(unknown)),
    ))
    metrics = MetricResult[]
    for id in sort!(collect(keys(values)))
        id in omit && continue
        is_unknown = id in unknown
        push!(metrics, MetricResult(id, is_unknown ? nothing : values[id];
            uncertainty = is_unknown ? nothing : uncertainty,
            fidelity = fidelity,
            applicability = "unit-test physical contract",
            status = is_unknown ? :unknown : :pass,
            solver_name = "test_physics",
            solver_version = "1",
            input_hash = genome.physics_hash,
            run_hash = run_hash))
    end
    if !("engineering_feasible" in omit)
        is_unknown = "engineering_feasible" in unknown
        push!(metrics, MetricResult("engineering_feasible",
            is_unknown ? nothing : engineering_feasible;
            fidelity = fidelity,
            applicability = "unit-test hard gate",
            status = is_unknown ? :unknown : :pass,
            solver_name = "test_physics",
            solver_version = "1",
            input_hash = genome.physics_hash,
            run_hash = run_hash))
    end
    return EvaluationBundle("test_physics", genome.design_id, genome.family,
        fidelity, :pass, metrics, String[], genome.physics_hash, run_hash,
        claim_ceiling)
end

@testset "Confinement Genome parsing and units" begin
    genomes = load_genomes(SEEDS_PATH)
    @test length(genomes) == 4
    @test getfield.(genomes, :design_id) == [
        "lmc_iter_proxy_seed", "w7x_mechanism_seed", "wham_mechanism_seed",
        "beam_2024_concept_seed"]
    @test all(genome -> validate_genome(genome).valid, genomes)

    wham = only(filter(genome -> genome.design_id == "wham_mechanism_seed", genomes))
    beam_energy = quantity(wham, :actuators, "wham_nbi", "beam_energy")
    injection_angle = quantity(wham, :actuators, "wham_nbi", "injection_angle")
    @test beam_energy.unit == "J"
    @test beam_energy.value ≈ 25.0 * 1.602176634e-16 rtol = 1.0e-14
    @test injection_angle.unit == "rad"
    @test injection_angle.value ≈ pi / 4 rtol = 1.0e-14

    objects = seed_objects()
    original = parse_genome(objects[1])
    relabeled_raw = deepcopy(objects[1])
    relabeled_raw["design_id"] = "same_physics_new_identity"
    relabeled_raw["label"] = "Prose-only label change"
    relabeled = parse_genome(relabeled_raw)
    @test original.physics_hash == relabeled.physics_hash
    @test original.content_hash != relabeled.content_hash

    equivalent_raw = deepcopy(objects[1])
    equivalent_raw["mission"]["targets"]["plasma_current"] =
        Dict("value" => 15.0e6, "unit" => "A", "basis" => "Existing LMC fixed mission point")
    plasma_source = only(filter(item -> item["id"] == "tokamak_plasma_current",
        equivalent_raw["field_sources"]))
    plasma_source["parameters"]["total_current"] = Dict("value" => 15.0e6, "unit" => "A")
    equivalent = parse_genome(equivalent_raw)
    @test original.physics_hash == equivalent.physics_hash

    reversed_top = Dict{String,Any}()
    for key in reverse(collect(keys(original.normalized)))
        reversed_top[key] = original.normalized[key]
    end
    @test canonical_hash(reversed_top) == canonical_hash(original.normalized)
    @test_throws ArgumentError Quantity(1.0, "made_up_unit")
end

@testset "Semantic and family validation" begin
    genomes = load_genomes(SEEDS_PATH)
    families = default_family_registry()
    @test all(genome -> validate_family(families, genome).valid, genomes)
    @test family_spec(families, "tokamak_axisymmetric").claim_ceiling_without_fidelity1 ==
        "screening_only"

    objects = seed_objects()
    invalid_raw = deepcopy(objects[3])
    push!(invalid_raw["stability_mechanisms"][1]["actuator_ids"], "missing_actuator")
    invalid = parse_genome(invalid_raw)
    report = validate_genome(invalid)
    @test !report.valid
    @test any(contains("missing actuator"), report.errors)

    wrong_family_raw = deepcopy(objects[2])
    wrong_family_raw["symmetry"]["class"] = "axisymmetric"
    wrong_family = parse_genome(wrong_family_raw)
    @test !validate_family(families, wrong_family).valid
end

@testset "Evaluation contract keeps unknown distinct from zero" begin
    @test_throws ArgumentError MetricResult("missing_physics", 0.0;
        fidelity = 0,
        applicability = "not evaluated",
        status = :unknown,
        solver_name = "test",
        solver_version = "1",
        input_hash = "input",
        run_hash = "run")

    metric = MetricResult("missing_physics", nothing;
        fidelity = 0,
        applicability = "not evaluated",
        status = :unknown,
        solver_name = "test",
        solver_version = "1",
        input_hash = "input",
        run_hash = "run")
    @test metric.status == :unknown
    @test metric.value === nothing
end

@testset "Registry applicability and coverage" begin
    genomes = load_genomes(SEEDS_PATH)
    tokamak, stellarator, _ = genomes
    registry = EvaluatorRegistry()
    adapter = TokamakAxisymmetricProxyV1(LEGACY_ROOT)
    register!(registry, adapter)
    @test_throws ArgumentError register!(registry, adapter)

    stellarator_result = evaluate_design(registry, "tokamak_axisymmetric_proxy_v1", stellarator)
    @test stellarator_result.status == :not_applicable
    @test all(metric -> metric.value === nothing, stellarator_result.metrics)

    coverage = coverage_report(registry, tokamak)
    @test !coverage_complete(coverage)
    @test count(item -> item.support == :proxy, coverage) == 4
    @test count(item -> item.support == :full, coverage) == 0
    @test any(item -> item.requirement == "structural_fea" && item.support == :missing,
        coverage)

    changed_raw = deepcopy(seed_objects()[1])
    changed_raw["plasma_regions"][1]["parameters"]["major_radius"]["value"] = 5.9
    changed = parse_genome(changed_raw)
    changed_result = evaluate_design(registry, "tokamak_axisymmetric_proxy_v1", changed)
    @test changed_result.status == :not_applicable
    @test occursin("major_radius=6.2 m", only(changed_result.warnings))
    @test count(item -> item.support == :proxy,
        coverage_report(registry, changed)) == 0
end

@testset "Legacy tokamak adapter is isolated and deterministic" begin
    tokamak = first(load_genomes(SEEDS_PATH))
    registry = EvaluatorRegistry()
    register!(registry, TokamakAxisymmetricProxyV1(LEGACY_ROOT))
    before = source_tree_hash(LEGACY_ROOT)
    first_result = evaluate_design(registry, "tokamak_axisymmetric_proxy_v1", tokamak)
    second_result = evaluate_design(registry, "tokamak_axisymmetric_proxy_v1", tokamak)
    after = source_tree_hash(LEGACY_ROOT)

    @test before == after
    @test first_result.status == :pass
    @test second_result.status == :pass
    @test first_result.input_hash == tokamak.physics_hash
    @test first_result.run_hash == second_result.run_hash
    @test first_result.claim_ceiling == "screening_only"

    metrics = Dict(metric.metric_id => metric for metric in first_result.metrics)
    @test metrics["boundary_bn_rms_proxy"].value ≈ 0.021541166700511236 rtol = 1.0e-10
    @test metrics["engineering_feasible_proxy"].value === true
    @test all(metric -> metric.status == :pass, first_result.metrics)
    @test any(contains("not a self-consistent"), first_result.warnings)

    mktempdir() do directory
        path = joinpath(directory, "evaluation.json")
        write_evaluation(path, first_result)
        written = JSON3.read(read(path, String), Dict{String,Any})
        @test written["status"] == "pass"
        @test length(written["metrics"]) == length(first_result.metrics)
    end
end

@testset "FreeGS Fidelity-1 explicit-filament regression" begin
    genome = load_genome(FREEGS_REGRESSION_PATH)
    @test only(genome.actuators).kind == "feedback_coil"
    seeds = load_genomes(SEEDS_PATH)
    iter_seed = only(filter(item -> item.design_id == "lmc_iter_proxy_seed", seeds))
    mirror_seed = only(filter(item -> item.design_id == "beam_2024_concept_seed", seeds))
    @test validate_genome(genome).valid
    @test validate_family(default_family_registry(), genome).valid
    @test isfile(FREEGS_PYTHON)

    adapter = TokamakFreeBoundaryFreeGSV1(FREEGS_PYTHON)
    spec = evaluator_spec(adapter)
    @test spec.fidelity == 1
    @test spec.claim_ceiling == "physics_concept"
    @test evaluator_applicability(adapter, genome)[1]
    @test !evaluator_applicability(adapter, iter_seed)[1]
    @test !evaluator_applicability(adapter, mirror_seed)[1]

    registry = EvaluatorRegistry()
    register!(registry, adapter)
    coverage = coverage_report(registry, genome)
    @test length(coverage) == 5
    support = Dict(item.requirement => item.support for item in coverage)
    @test all(requirement -> support[requirement] == :full,
        ["axisymmetric_force_balance", "free_boundary_grad_shafranov",
            "free_boundary_shape_control"])
    @test support["edge_heat_flux"] == :missing
    @test support["finite_build_coils"] == :missing
    @test count(item -> item.support == :full,
        coverage_report(registry, iter_seed)) == 0

    first_result = evaluate_design(registry, spec.id, genome)
    second_result = evaluate_design(registry, spec.id, genome)
    @test first_result.status == :pass
    @test first_result.run_hash == second_result.run_hash
    @test first_result.claim_ceiling == "physics_concept"
    @test length(first_result.warnings) == length(unique(first_result.warnings))
    metrics = Dict(metric.metric_id => metric for metric in first_result.metrics)
    @test metrics["free_boundary_equilibrium_converged"].value === true
    @test metrics["axisymmetric_force_balance_feasible"].value === true
    @test metrics["equilibrium_iteration_count"].value == 44
    @test metrics["grad_shafranov_residual_l2_relative"].value ≈
        0.0038256324736742047 rtol = 1.0e-10
    @test metrics["picard_final_relative_change"].value < 1.0e-4
    @test metrics["plasma_current"].value ≈ 1.0e6 rtol = 1.0e-12
    @test metrics["q_95"].value ≈ 0.7786646698939796 rtol = 1.0e-10
    @test metrics["xpoint_field_residual_max"].value < 0.02
    @test metrics["isoflux_residual_relative"].value < 0.03
    @test metrics["plasma_stability_feasible"].status == :unknown
    @test metrics["fusion_gain"].status == :unknown
    @test metrics["engineering_feasible"].status == :unknown

    prepared = prepare_candidate(genome, [first_result],
        first_principles_discovery_contract())
    @test !prepared.eligible
    @test any(reason -> occursin("fuel other", reason), prepared.reasons)
    @test any(reason -> occursin("plasma_stability_feasible", reason),
        prepared.reasons)

    raw = deepcopy(genome.normalized)
    core = only(filter(item -> item["id"] == "freegs_regression_core",
        raw["plasma_regions"]))
    core["parameters"]["grid_nx"]["value"] = 64
    even_grid = parse_genome(raw)
    @test !evaluator_applicability(adapter, even_grid)[1]
    not_applicable = evaluate_design(registry, spec.id, even_grid)
    @test not_applicable.status == :not_applicable
end

@testset "Evidence-linked graph grammar" begin
    seeds = load_genomes(SEEDS_PATH)
    rules = default_graph_rules()
    known = known_source_ids(joinpath(PROJECT_ROOT, "knowledge", "sources.json"))
    families = default_family_registry()
    rng = MersenneTwister(17)
    generated = Genome[]
    used_rules = String[]
    for seed in seeds, rule in rules
        applicable_rule(rule, seed) || continue
        candidate = apply_rule(rule, seed, rng)
        push!(generated, candidate)
        push!(used_rules, rule.id)
        @test validate_genome(candidate).valid
        @test validate_family(families, candidate).valid
        @test isempty(source_reference_errors(candidate, known))
        @test candidate.provenance.origin == "generated"
        @test candidate.provenance.claim_level == "structural_example"
        @test candidate.provenance.parent_design_ids == [seed.design_id]
        @test any(==("grammar_rule:$(rule.id)"), candidate.provenance.notes)
    end
    @test Set(used_rules) == Set(getfield.(rules, :id))
    @test any(genome -> genome.family == "tokamak_3d_hybrid", generated)
    @test any(genome -> genome.symmetry.class == "minimum_b", generated)
    @test any(genome -> any(region -> region.id == "mirror_left_plug",
        genome.plasma_regions), generated)

    registry = EvaluatorRegistry()
    register!(registry, StructuralIREvaluatorV1())
    structural = evaluate_design(registry, "structural_ir_v1", first(generated))
    @test structural.status == :pass
    @test structural.claim_ceiling == "structural_only"
    @test any(contains("must not be called device simplicity"), structural.warnings)
end

@testset "Structural QD is deterministic and cannot claim performance" begin
    seeds = load_genomes(SEEDS_PATH)
    registry = EvaluatorRegistry()
    register!(registry, StructuralIREvaluatorV1())
    register!(registry, TokamakAxisymmetricProxyV1(LEGACY_ROOT))
    register!(registry, MirrorBeam0DV1())
    rules = default_graph_rules()
    objective_contract = first_principles_discovery_contract()
    first_run = run_structural_qd(seeds, rules, registry;
        iterations = 160, random_seed = 20260810,
        objective_contract = objective_contract)
    second_run = run_structural_qd(seeds, rules, registry;
        iterations = 160, random_seed = 20260810,
        objective_contract = objective_contract)
    first_dict = structural_qd_to_dict(first_run)
    second_dict = structural_qd_to_dict(second_run)

    @test canonical_hash(first_dict) == canonical_hash(second_dict)
    @test length(first_run.archive.cells) >= 20
    @test length(first_run.discovered) > length(seeds)
    @test all(record -> !record.performance_eligible, first_run.discovered)
    @test first_dict["performance_eligible_count"] == 0
    @test first_dict["stage"] == "structural_only"
    @test first_dict["objective_readiness_audited"]
    @test first_dict["objective_contract_id"] == "science_gain_first_principles_v1"
    @test all(record -> record.objective_readiness !== nothing,
        first_run.discovered)
    beam_record = only(filter(record ->
        record.genome.design_id == "beam_2024_concept_seed", first_run.discovered))
    @test Set(keys(beam_record.objective_readiness.objectives)) ==
        Set(["fusion_gain", "fusion_power"])
    @test any(reason -> occursin("device_complexity_index", reason),
        beam_record.objective_readiness.reasons)
    @test any(reason -> occursin("minimum_stability_margin", reason),
        beam_record.objective_readiness.reasons)
    @test any(reason -> occursin("engineering_feasible", reason),
        beam_record.objective_readiness.reasons)

    families = Set(record.genome.family for record in first_run.discovered)
    @test "tokamak_3d_hybrid" in families
    @test "stellarator" in families
    @test "magnetic_mirror" in families
    @test any(record -> any(mechanism ->
        mechanism.id == "mirror_ambipolar_plugging_mechanism",
        record.genome.stability_mechanisms), first_run.discovered)
    @test any(record -> occursin("collisional_gas_dynamic", record.descriptor),
        first_run.discovered)
end

@testset "Evidence-aware multi-fidelity promotion scheduler" begin
    seeds = load_genomes(SEEDS_PATH)
    beam = only(filter(genome -> genome.design_id == "beam_2024_concept_seed", seeds))
    contract = first_principles_discovery_contract()
    catalog = default_evidence_task_catalog()
    registry = EvaluatorRegistry()
    register!(registry, MirrorBeam0DV1())

    # Capability is not completed evidence. With no prior exact run, the BEAM
    # task is executable and targets only outputs it can truly compute.
    empty_result = schedule_evidence_acquisition([beam], registry, catalog,
        CompletedEvidence[], contract; budget_units = 1.0)
    beam_recommendation = only(filter(item ->
        item.task_id == "mirror_beam_0d_v1", empty_result.all_recommendations))
    @test beam_recommendation.execution_status == :executable
    @test Set(beam_recommendation.targeted_objectives) ==
        Set(["fusion_gain", "fusion_power"])
    @test isempty(beam_recommendation.targeted_hard_constraints)
    @test length(empty_result.selected) == 1
    @test empty_result.selected_cost_units == 1.0

    # Terminal evidence is exact-task-version plus exact physics hash. A fail
    # is still a completed physical evaluation, while a different hash is not.
    bundle = evaluate_design(registry, "mirror_beam_0d_v1", beam)
    @test bundle.status == :fail
    completed = CompletedEvidence(bundle)
    exact_result = schedule_evidence_acquisition([beam], registry, catalog,
        [completed], contract; budget_units = 10.0)
    exact_beam = only(filter(item -> item.task_id == "mirror_beam_0d_v1",
        exact_result.all_recommendations))
    @test exact_beam.execution_status == :already_completed
    @test !("mirror_beam_0d_v1" in getfield.(exact_result.selected, :task_id))
    exact_payload = evidence_schedule_to_dict(exact_result)
    @test exact_payload["task_catalog_count"] == length(catalog)
    @test exact_payload["completed_evidence_count"] == 1
    @test all(entry -> !haskey(entry, "value"),
        exact_payload["completed_evidence_ledger"])
    wrong_hash = CompletedEvidence(completed.task_id, completed.task_version,
        completed.design_id, repeat("0", 64), completed.run_hash,
        completed.status, completed.fidelity, completed.claim_ceiling,
        completed.metrics)
    wrong_result = schedule_evidence_acquisition([beam], registry, catalog,
        [wrong_hash], contract; budget_units = 1.0)
    wrong_beam = only(filter(item -> item.task_id == "mirror_beam_0d_v1",
        wrong_result.all_recommendations))
    @test wrong_beam.execution_status == :executable

    # Errors are retryable rather than silently treated as evidence.
    errored = CompletedEvidence(completed.task_id, completed.task_version,
        completed.design_id, completed.input_hash, completed.run_hash, :error,
        completed.fidelity, completed.claim_ceiling, completed.metrics)
    error_result = schedule_evidence_acquisition([beam], registry, catalog,
        [errored], contract; budget_units = 1.0)
    error_beam = only(filter(item -> item.task_id == "mirror_beam_0d_v1",
        error_result.all_recommendations))
    @test error_beam.execution_status == :executable

    # Planned and blocked models remain roadmap entries and can never consume
    # the execution budget or satisfy a hard gate.
    @test any(item -> item.execution_status == :backend_planned,
        empty_result.all_recommendations)
    @test any(item -> item.execution_status == :backend_blocked,
        empty_result.all_recommendations)
    @test all(item -> item.execution_status == :executable,
        empty_result.selected)
    beam_audit = only(empty_result.candidate_audits)
    @test Set(beam_audit["missing_hard_constraints"]) ==
        Set(["plasma_stability_feasible", "engineering_feasible"])

    # Geometry-model routing is stricter than family routing. A new mirror
    # layout must never inherit evidence from the available cage-only task and
    # exactly one layout-specific executable backend may claim the input.
    routed_artifact = JSON3.read(read(
        CROSS_FAMILY_GEOMETRY_TOPOLOGY_V2_ARTIFACT_PATH, String))
    routed_record = only(filter(record -> record["spec"]["layout"] ==
        "split_ioffe_saddle_pair", routed_artifact["mirror"]["promoted"]))
    routed_mirror = parse_genome(routed_record["genome"])
    register!(registry, UnifiedCrossFamilyScreenV1())
    register!(registry, MirrorLayoutVacuumGeometryV1(
        "split_ioffe_saddle_pair"))
    routed_horizontal = CompletedEvidence(evaluate_design(registry,
        "unified_cross_family_screen_v1", routed_mirror))
    @test routed_horizontal.status == :pass
    routed_result = schedule_evidence_acquisition([routed_mirror], registry,
        catalog, [routed_horizontal], contract; budget_units = 1.0)
    routed = Dict(item.task_id => item for item in
        routed_result.all_recommendations)
    @test routed["mirror_finite_coil_geometry_v1"].execution_status ==
        :input_incompatible
    @test occursin("forbids field-source geometry models",
        only(routed["mirror_finite_coil_geometry_v1"].reasons))
    @test routed[
        "mirror_split_ioffe_saddle_pair_vacuum_geometry_v1"].execution_status ==
        :executable
    @test routed[
        "mirror_continuous_baseball_seam_pair_vacuum_geometry_v1"].execution_status ==
        :input_incompatible
    @test routed[
        "mirror_yin_yang_end_anchor_pair_vacuum_geometry_v1"].execution_status ==
        :input_incompatible
    routed_payload = evidence_schedule_to_dict(routed_result)
    split_task = only(filter(item -> item["task_id"] ==
        "mirror_split_ioffe_saddle_pair_vacuum_geometry_v1",
        routed_payload["task_catalog"]))
    @test split_task["required_field_source_geometry_models"] ==
        ["split_ioffe_saddle_pair"]
    @test_throws ArgumentError EvidenceTaskSpec("bad_geometry_route", "1",
        :evaluation, ["magnetic_mirror"], 1, 1.0, :planned;
        required_field_source_geometry_models = ["same"],
        forbidden_field_source_geometry_models = ["same"])

    # Hard-gate information receives more acquisition utility than an objective
    # at equal cost, and deterministic tie-breaking/budgeting is reproducible.
    priority_registry = EvaluatorRegistry()
    register!(priority_registry,
        SchedulerFixtureEvaluator("fixture_hard_gate", Set(["magnetic_mirror"])))
    register!(priority_registry,
        SchedulerFixtureEvaluator("fixture_objective", Set(["magnetic_mirror"])))
    priority_tasks = EvidenceTaskSpec[
        EvidenceTaskSpec("fixture_hard_gate", "1.0.0", :evaluation,
            ["magnetic_mirror"], 1, 1.0, :available;
            metric_outputs = ["plasma_stability_feasible"],
            claim_ceiling = "physics_proxy"),
        EvidenceTaskSpec("fixture_objective", "1.0.0", :evaluation,
            ["magnetic_mirror"], 1, 1.0, :available;
            metric_outputs = ["fusion_power"],
            uncertainty_outputs = ["fusion_power"],
            claim_ceiling = "physics_proxy"),
    ]
    first_priority = schedule_evidence_acquisition([beam], priority_registry,
        priority_tasks, CompletedEvidence[], contract; budget_units = 1.0)
    second_priority = schedule_evidence_acquisition([beam], priority_registry,
        priority_tasks, CompletedEvidence[], contract; budget_units = 1.0)
    @test only(first_priority.selected).task_id == "fixture_hard_gate"
    @test first_priority.selected_cost_units <= first_priority.budget_units
    @test canonical_hash(evidence_schedule_to_dict(first_priority)) ==
        canonical_hash(evidence_schedule_to_dict(second_priority))
    @test only(first_priority.deferred_executable).task_id == "fixture_objective"

    @test_throws ArgumentError EvidenceTaskSpec("bad_cost", "1", :evaluation,
        ["magnetic_mirror"], 1, 0.0, :available)
    @test_throws ArgumentError schedule_evidence_acquisition([beam],
        priority_registry, [priority_tasks[1], priority_tasks[1]],
        CompletedEvidence[], contract)
    @test_throws ArgumentError schedule_evidence_acquisition([beam],
        priority_registry, priority_tasks, CompletedEvidence[], contract;
        budget_units = -1.0)

    # Stored Fidelity-1 artifacts use adapter+backend semantic versions. The
    # catalog adapter version prefix must recognize them without rerunning.
    fidelity_cases = [
        ("fidelity1_freegs_regression.json",
            "freegs_testtokamak_regression_genome.json",
            "tokamak_free_boundary_freegs_v1"),
        ("fidelity1_desc_w7x_regression.json",
            "desc_w7x_regression_genome.json",
            "stellarator_fixed_boundary_desc_w7x_v1"),
        ("fidelity1_pleiades_wham_regression.json",
            "pleiades_wham_isotropic_regression_genome.json",
            "mirror_isotropic_pleiades_wham_v1"),
    ]
    fidelity_registry = EvaluatorRegistry()
    register!(fidelity_registry, TokamakFreeBoundaryFreeGSV1(FREEGS_PYTHON))
    register!(fidelity_registry, StellaratorDESCW7XRegressionV1(DESC_PYTHON))
    register!(fidelity_registry, StellaratorDESCFourierV1(DESC_PYTHON))
    register!(fidelity_registry, StellaratorDESCStabilityV1(DESC_PYTHON))
    register!(fidelity_registry, StellaratorDESCTransportProxyV1())
    register!(fidelity_registry, StellaratorDESCSurfaceCurrentV1(DESC_PYTHON))
    register!(fidelity_registry, StellaratorDESCDiscreteCoilCutV1(DESC_PYTHON))
    register!(fidelity_registry, StellaratorDESCDiscreteCoilOptimizationV1())
    register!(fidelity_registry, StellaratorDESCFiniteBuildCoilProxyV1())
    register!(fidelity_registry, MirrorPleiadesWHAMIsotropicV1(PLEIADES_PYTHON))
    for (artifact_name, genome_name, task_id) in fidelity_cases
        artifact = JSON3.read(read(joinpath(PROJECT_ROOT, "runs", artifact_name), String))
        evidence = completed_evidence_from_dict(artifact["evaluation"])
        @test startswith(evidence.task_version, "1.0.0+")
        genome = load_genome(joinpath(PROJECT_ROOT, "examples", genome_name))
        result = schedule_evidence_acquisition([genome], fidelity_registry,
            catalog, [evidence], contract; budget_units = 50.0)
        recommendation = only(filter(item -> item.task_id == task_id,
            result.all_recommendations))
        @test recommendation.execution_status == :already_completed
        @test !(task_id in getfield.(result.selected, :task_id))
    end

    fourier_artifact = JSON3.read(read(DESC_FOURIER_ARTIFACT_PATH, String))
    fourier_genome = parse_genome(fourier_artifact["genome"])
    fourier_evidence = completed_evidence_from_dict(
        fourier_artifact["evaluation"])
    @test startswith(fourier_evidence.task_version, "1.0.0+")
    fourier_result = schedule_evidence_acquisition([fourier_genome],
        fidelity_registry, catalog, [fourier_evidence], contract;
        budget_units = 50.0)
    fourier_recommendation = only(filter(item ->
        item.task_id == "stellarator_fixed_boundary_desc_fourier_v1",
        fourier_result.all_recommendations))
    @test fourier_recommendation.execution_status == :already_completed
    @test !(fourier_recommendation.task_id in
        getfield.(fourier_result.selected, :task_id))

    # The builder is a transformation action: it can unlock a new child hash,
    # but it never fabricates terminal evidence for the parent candidate.
    stellarator_parent = only(filter(genome ->
        genome.design_id == "w7x_mechanism_seed", seeds))
    builder_result = schedule_evidence_acquisition([stellarator_parent],
        fidelity_registry, catalog, CompletedEvidence[], contract;
        budget_units = 8.0)
    builder = only(filter(item ->
        item.task_id == "stellarator_fourier_input_builder_v1",
        builder_result.all_recommendations))
    @test builder.execution_status == :executable
    @test builder.unlocks == ["stellarator_fixed_boundary_desc_fourier_v1"]
    @test only(builder_result.selected).task_id == builder.task_id
    parent_audit = only(builder_result.candidate_audits)
    @test isempty(parent_audit["terminal_exact_task_ids"])
    @test parent_audit["requirement_evidence"]["vmec_or_desc"] == "missing"

    pilot = JSON3.read(read(DESC_FOURIER_PILOT_PATH, String))
    for record in pilot["promoted_candidates"]
        genome = parse_genome(record["genome"])
        evidence = completed_evidence_from_dict(record["evaluation"])
        result = schedule_evidence_acquisition([genome], fidelity_registry,
            catalog, [evidence], contract; budget_units = 50.0)
        recommendation = only(filter(item ->
            item.task_id == "stellarator_fixed_boundary_desc_fourier_v1",
            result.all_recommendations))
        @test recommendation.execution_status == :already_completed
        @test isempty(result.selected)
    end

    stability_pilot = JSON3.read(read(DESC_STABILITY_MEDIUM_PILOT_PATH, String))
    equilibrium_by_hash = Dict(String(record["physics_hash"]) =>
        completed_evidence_from_dict(record["evaluation"])
        for record in pilot["promoted_candidates"])
    for record in stability_pilot["candidates"]
        genome = parse_genome(record["genome"])
        stability_evidence = completed_evidence_from_dict(record["evaluation"])
        @test stability_evidence.task_id ==
            "stellarator_sampled_ideal_mhd_stability_desc_v1"
        result = schedule_evidence_acquisition([genome], fidelity_registry,
            catalog, [equilibrium_by_hash[genome.physics_hash], stability_evidence],
            contract; budget_units = 100.0)
        recommendation = only(filter(item -> item.task_id ==
            "stellarator_sampled_ideal_mhd_stability_desc_v1",
            result.all_recommendations))
        @test recommendation.execution_status == :already_completed
        @test !(recommendation.task_id in getfield.(result.selected, :task_id))
    end

    active_results = JSON3.read(read(DESC_STABILITY_ACTIVE_RESULTS_PATH, String))
    for record in active_results["records"]
        genome = parse_genome(record["genome"])
        stability_evidence = completed_evidence_from_dict(record["evaluation"])
        result = schedule_evidence_acquisition([genome], fidelity_registry,
            catalog, [stability_evidence], contract; budget_units = 100.0)
        recommendation = only(filter(item -> item.task_id ==
            "stellarator_sampled_ideal_mhd_stability_desc_v1",
            result.all_recommendations))
        @test recommendation.execution_status == :already_completed
        @test !(recommendation.task_id in getfield.(result.selected, :task_id))
    end

    surface_pilot = JSON3.read(read(DESC_SURFACE_CURRENT_PILOT_PATH, String))
    for record in surface_pilot["records"]
        genome = parse_genome(record["genome"])
        surface_evidence = completed_evidence_from_dict(record["evaluation"])
        result = schedule_evidence_acquisition([genome], fidelity_registry,
            catalog, [surface_evidence], contract; budget_units = 100.0)
        surface_recommendation = only(filter(item -> item.task_id ==
            "stellarator_surface_current_regcoil_desc_v1",
            result.all_recommendations))
        @test surface_recommendation.execution_status == :already_completed
        @test !(surface_recommendation.task_id in
            getfield.(result.selected, :task_id))
    end

    discrete_artifact = JSON3.read(read(DESC_DISCRETE_COIL_ARTIFACT_PATH, String))
    discrete_genome = parse_genome(discrete_artifact["genome"])
    discrete_evidence = completed_evidence_from_dict(
        discrete_artifact["evaluation"])
    discrete_result = schedule_evidence_acquisition([discrete_genome],
        fidelity_registry, catalog, [discrete_evidence], contract;
        budget_units = 100.0)
    cut_recommendation = only(filter(item -> item.task_id ==
        "stellarator_discrete_coil_cut_desc_v1",
        discrete_result.all_recommendations))
    @test cut_recommendation.execution_status == :already_completed
    optimization_recommendation = only(filter(item -> item.task_id ==
        "stellarator_discrete_coil_optimization_desc_v1",
        discrete_result.all_recommendations))
    @test optimization_recommendation.execution_status == :executable
    @test !(cut_recommendation.task_id in
        getfield.(discrete_result.selected, :task_id))

    optimized_artifact = JSON3.read(
        read(DESC_OPTIMIZED_COIL_ARTIFACT_PATH, String))
    optimized_evidence = completed_evidence_from_dict(
        optimized_artifact["evaluation"])
    optimized_result = schedule_evidence_acquisition([discrete_genome],
        fidelity_registry, catalog, [discrete_evidence, optimized_evidence], contract;
        budget_units = 100.0)
    completed_optimization = only(filter(item -> item.task_id ==
        "stellarator_discrete_coil_optimization_desc_v1",
        optimized_result.all_recommendations))
    @test completed_optimization.execution_status == :already_completed
    @test !(completed_optimization.task_id in
        getfield.(optimized_result.selected, :task_id))

    finite_build_artifact = JSON3.read(read(DESC_FINITE_BUILD_ARTIFACT_PATH, String))
    finite_build_evidence = completed_evidence_from_dict(
        finite_build_artifact["evaluation"])
    finite_build_result = schedule_evidence_acquisition([discrete_genome],
        fidelity_registry, catalog,
        [discrete_evidence, optimized_evidence, finite_build_evidence], contract;
        budget_units = 100.0)
    completed_finite_build = only(filter(item -> item.task_id ==
        "stellarator_finite_build_coil_proxy_desc_v1",
        finite_build_result.all_recommendations))
    @test completed_finite_build.execution_status == :already_completed
    @test !(completed_finite_build.task_id in
        getfield.(finite_build_result.selected, :task_id))
    finite_build_audit = only(finite_build_result.candidate_audits)
    finite_build_task = only(filter(task -> task.id ==
        "stellarator_finite_build_coil_proxy_desc_v1", catalog))
    @test finite_build_task.requirement_support["finite_build_coils"] == :proxy
    @test finite_build_task.requirement_support[
        "mutual_coil_electromagnetic_load"] == :proxy
    @test "engineering_feasible" in
        finite_build_audit["missing_hard_constraints"]

    regularized_artifact = JSON3.read(
        read(DESC_REGULARIZED_COIL_ARTIFACT_PATH, String))
    regularized_evidence = completed_evidence_from_dict(
        regularized_artifact["evaluation"])
    regularized_result = schedule_evidence_acquisition([discrete_genome],
        fidelity_registry, catalog,
        [discrete_evidence, optimized_evidence, finite_build_evidence,
            regularized_evidence], contract;
        budget_units = 100.0)
    completed_regularized = only(filter(item -> item.task_id ==
        "stellarator_regularized_coil_force_desc_v1",
        regularized_result.all_recommendations))
    @test completed_regularized.execution_status == :already_completed
    @test !(completed_regularized.task_id in
        getfield.(regularized_result.selected, :task_id))
    regularized_task = only(filter(task -> task.id ==
        "stellarator_regularized_coil_force_desc_v1", catalog))
    @test regularized_task.requirement_support[
        "regularized_rectangular_coil_self_force"] == :proxy
    @test regularized_task.requirement_support["coil_inductance"] == :proxy
    regularized_audit = only(regularized_result.candidate_audits)
    @test "stellarator_regularized_coil_force_desc_v1" in
        regularized_audit["terminal_exact_task_ids"]
    @test "engineering_feasible" in
        regularized_audit["missing_hard_constraints"]

    internal_field_artifact = JSON3.read(
        read(DESC_RECTANGULAR_INTERNAL_FIELD_ARTIFACT_PATH, String))
    internal_field_evidence = completed_evidence_from_dict(
        internal_field_artifact["evaluation"])
    internal_field_result = schedule_evidence_acquisition([discrete_genome],
        fidelity_registry, catalog,
        [discrete_evidence, optimized_evidence, finite_build_evidence,
            regularized_evidence, internal_field_evidence], contract;
        budget_units = 100.0)
    completed_internal_field = only(filter(item -> item.task_id ==
        "stellarator_rectangular_internal_field_desc_v1",
        internal_field_result.all_recommendations))
    @test completed_internal_field.execution_status == :already_completed
    @test !(completed_internal_field.task_id in
        getfield.(internal_field_result.selected, :task_id))
    internal_field_task = only(filter(task -> task.id ==
        "stellarator_rectangular_internal_field_desc_v1", catalog))
    @test internal_field_task.requirement_support[
        "peak_conductor_magnetic_field"] == :proxy
    @test internal_field_task.requirement_support[
        "plasma_current_field_at_conductor"] == :proxy
    internal_field_audit = only(internal_field_result.candidate_audits)
    @test "stellarator_rectangular_internal_field_desc_v1" in
        internal_field_audit["terminal_exact_task_ids"]
    @test "engineering_feasible" in
        internal_field_audit["missing_hard_constraints"]

    transport_artifact = JSON3.read(read(DESC_TRANSPORT_ARTIFACT_PATH, String))
    transport_genome = parse_genome(transport_artifact["genome"])
    transport_evidence = completed_evidence_from_dict(
        transport_artifact["evaluation"])
    pool16_stability_record = only(filter(record ->
        record["physics_hash"] == transport_genome.physics_hash,
        active_results["records"]))
    pool16_stability_evidence = completed_evidence_from_dict(
        pool16_stability_record["evaluation"])
    transport_result = schedule_evidence_acquisition([transport_genome],
        fidelity_registry, catalog,
        [pool16_stability_evidence, transport_evidence], contract;
        budget_units = 100.0)
    completed_transport = only(filter(item -> item.task_id ==
        "stellarator_qs_effective_ripple_desc_v1",
        transport_result.all_recommendations))
    @test completed_transport.execution_status == :already_completed
    @test !(completed_transport.task_id in
        getfield.(transport_result.selected, :task_id))
    transport_audit = only(transport_result.candidate_audits)
    @test transport_audit["requirement_evidence"]["neoclassical_transport"] ==
        "proxy"
end

@testset "BEAM mirror 0-D applicability and regression" begin
    genomes = load_genomes(SEEDS_PATH)
    wham = only(filter(genome -> genome.design_id == "wham_mechanism_seed", genomes))
    beam = only(filter(genome -> genome.design_id == "beam_2024_concept_seed", genomes))
    registry = EvaluatorRegistry()
    register!(registry, MirrorBeam0DV1())

    wham_result = evaluate_design(registry, "mirror_beam_0d_v1", wham)
    @test wham_result.status == :not_applicable
    @test count(item -> item.support == :proxy, coverage_report(registry, wham)) == 0

    first_result = evaluate_design(registry, "mirror_beam_0d_v1", beam)
    second_result = evaluate_design(registry, "mirror_beam_0d_v1", beam)
    @test first_result.status == :fail
    @test first_result.run_hash == second_result.run_hash
    @test first_result.claim_ceiling == "physics_proxy"
    metrics = Dict(metric.metric_id => metric for metric in first_result.metrics)
    @test metrics["effective_mirror_ratio_proxy"].value ≈
        (25.0 / 3.0) / sqrt(1.0 - 1.0 / 3.0) rtol = 1.0e-12
    @test metrics["fusion_gain_proxy"].value ≈ 1.0088643834802158 rtol = 1.0e-12
    @test metrics["fusion_gain"].value == metrics["fusion_gain_proxy"].value
    @test metrics["absorbed_beam_power_proxy"].value ≈ 6.343766421728879e6 rtol = 1.0e-12
    @test metrics["fusion_power_proxy"].value ≈ 6.4e6 rtol = 1.0e-12
    @test metrics["fusion_power"].value == metrics["fusion_power_proxy"].value
    @test metrics["flr_m2_length_margin_proxy"].value ≈ 0.75 rtol = 1.0e-12
    @test metrics["beta_limit_feasible_proxy"].value === false
    @test metrics["m1_interchange_stability"].status == :unknown
    @test metrics["minimum_stability_margin"].status == :unknown
    @test metrics["plasma_stability_feasible"].status == :unknown
    @test metrics["device_complexity_index"].status == :unknown
    @test metrics["engineering_feasible"].status == :unknown
    @test metrics["net_electric_power"].status == :unknown
    @test metrics["fusion_gain_proxy"].uncertainty !== nothing
    @test count(item -> item.support == :proxy,
        coverage_report(registry, beam)) == 4

    higher_energy_raw = deepcopy(seed_objects()[4])
    higher_energy_raw["design_id"] = "beam_150kev_variant"
    only(filter(item -> item["id"] == "beam_nbi",
        higher_energy_raw["actuators"]))["parameters"]["beam_energy"]["value"] = 150.0
    higher_energy = parse_genome(higher_energy_raw)
    higher_result = evaluate_design(registry, "mirror_beam_0d_v1", higher_energy)
    higher_metrics = Dict(metric.metric_id => metric for metric in higher_result.metrics)
    @test higher_metrics["fusion_gain_proxy"].value > metrics["fusion_gain_proxy"].value

    out_of_range_raw = deepcopy(seed_objects()[4])
    out_of_range_raw["design_id"] = "beam_80kev_out_of_domain"
    only(filter(item -> item["id"] == "beam_nbi",
        out_of_range_raw["actuators"]))["parameters"]["beam_energy"]["value"] = 80.0
    out_of_range = parse_genome(out_of_range_raw)
    out_result = evaluate_design(registry, "mirror_beam_0d_v1", out_of_range)
    @test out_result.status == :not_applicable
    @test count(item -> item.support == :proxy,
        coverage_report(registry, out_of_range)) == 0

    contract = ObjectiveContract(
        "mirror_science_gain_complete_v1", ["science_gain_demo"], ["D-T"],
        [
            ObjectiveSpec("fusion_gain_proxy", :max, "1"),
            ObjectiveSpec("m1_interchange_stability", :max, "1"),
            ObjectiveSpec("net_electric_power", :max, "W"),
        ],
        [ConstraintSpec("engineering_feasible", :is_true)],
        minimum_claim_level = "physics_proxy")
    prepared = prepare_candidate(beam, [first_result], contract)
    @test !prepared.eligible
    @test any(contains("m1_interchange_stability"), prepared.reasons)
    @test any(contains("net_electric_power"), prepared.reasons)
    @test any(contains("engineering_feasible"), prepared.reasons)
end

@testset "Constrained BEAM proxy evolutionary search" begin
    beam = only(filter(genome -> genome.design_id == "beam_2024_concept_seed",
        load_genomes(SEEDS_PATH)))
    first_run = run_mirror_beam_proxy_search(beam;
        population_size = 12, generations = 6, random_seed = 20260810)
    second_run = run_mirror_beam_proxy_search(beam;
        population_size = 12, generations = 6, random_seed = 20260810)
    first_dict = mirror_beam_proxy_search_to_dict(first_run)
    second_dict = mirror_beam_proxy_search_to_dict(second_run)

    @test canonical_hash(first_dict) == canonical_hash(second_dict)
    @test first_dict["attempted"] == 72
    @test first_dict["unique_candidates"] == 72
    @test first_dict["screening_feasible_count"] > 0
    @test first_dict["pareto_count"] > 0
    @test first_dict["first_principles_eligible_count"] == 0
    @test first_dict["stage"] == "physics_proxy_screening"
    @test first_dict["screening_contract_id"] == "mirror_beam_proxy_screening_v1"
    @test all(!candidate.performance_readiness.eligible
        for candidate in first_run.candidates)
    @test all(record["proxy_evaluation_status"] == "pass"
        for record in first_dict["pareto_archive"])
    @test all(!isempty(record["first_principles_rejection_reasons"])
        for record in first_dict["pareto_archive"])
end

@testset "Objective readiness and evidence-tier Pareto gate" begin
    objects = seed_objects()
    raw_a = deepcopy(objects[1])
    raw_a["design_id"] = "pareto_candidate_a"
    raw_a["plasma_regions"][1]["parameters"]["major_radius"]["value"] = 6.1
    genome_a = parse_genome(raw_a)
    raw_b = deepcopy(objects[1])
    raw_b["design_id"] = "pareto_candidate_b"
    raw_b["plasma_regions"][1]["parameters"]["major_radius"]["value"] = 6.3
    genome_b = parse_genome(raw_b)
    raw_c = deepcopy(objects[1])
    raw_c["design_id"] = "pareto_candidate_c"
    raw_c["plasma_regions"][1]["parameters"]["major_radius"]["value"] = 6.5
    genome_c = parse_genome(raw_c)

    contract = ObjectiveContract(
        "science_gain_physics_proxy_v1",
        ["science_gain_demo"],
        ["D-T"],
        [
            ObjectiveSpec("fusion_gain_proxy", :max, "1";
                minimum_fidelity = 0, require_uncertainty = true),
            ObjectiveSpec("stability_margin_proxy", :max, "1";
                minimum_fidelity = 0, require_uncertainty = true),
            ObjectiveSpec("physical_complexity_proxy", :min, "1";
                minimum_fidelity = 0, require_uncertainty = true),
        ],
        [ConstraintSpec("engineering_feasible", :is_true;
            minimum_fidelity = 0)],
        minimum_claim_level = "physics_proxy",
    )

    bundle_a = test_objective_bundle(genome_a;
        gain = 12.0, stability = 3.0, complexity = 4.0)
    bundle_b = test_objective_bundle(genome_b;
        gain = 8.0, stability = 2.0, complexity = 6.0)
    bundle_c = test_objective_bundle(genome_c;
        gain = 15.0, stability = 1.0, complexity = 8.0)
    prepared_a = prepare_candidate(genome_a, [bundle_a], contract)
    prepared_b = prepare_candidate(genome_b, [bundle_b], contract)
    prepared_c = prepare_candidate(genome_c, [bundle_c], contract)
    @test prepared_a.eligible
    @test prepared_b.eligible
    @test prepared_c.eligible
    ab = compare_candidates(prepared_a, prepared_b, contract)
    ac = compare_candidates(prepared_a, prepared_c, contract)
    @test ab.comparable && ab.a_dominates && !ab.b_dominates
    @test ac.comparable && !ac.a_dominates && !ac.b_dominates

    missing = prepare_candidate(genome_a,
        [test_objective_bundle(genome_a; omit = Set(["fusion_gain_proxy"]))], contract)
    unknown = prepare_candidate(genome_a,
        [test_objective_bundle(genome_a; unknown = Set(["stability_margin_proxy"]))], contract)
    no_uncertainty = prepare_candidate(genome_a,
        [test_objective_bundle(genome_a; uncertainty = nothing)], contract)
    low_claim = prepare_candidate(genome_a,
        [test_objective_bundle(genome_a; claim_ceiling = "screening_only")], contract)
    hard_fail = prepare_candidate(genome_a,
        [test_objective_bundle(genome_a; engineering_feasible = false)], contract)
    @test !missing.eligible && any(contains("missing required metric"), missing.reasons)
    @test !unknown.eligible && any(contains("status unknown"), unknown.reasons)
    @test !no_uncertainty.eligible && any(contains("lacks required uncertainty"), no_uncertainty.reasons)
    @test !low_claim.eligible && any(contains("below physics_proxy"), low_claim.reasons)
    @test !hard_fail.eligible && any(contains("hard constraint engineering_feasible failed"), hard_fail.reasons)

    higher_fidelity = prepare_candidate(genome_b,
        [test_objective_bundle(genome_b; fidelity = 1)], contract)
    mixed_tier = compare_candidates(prepared_a, higher_fidelity, contract)
    @test !mixed_tier.comparable
    @test any(contains("different evidence tiers"), mixed_tier.reasons)

    archive = EvidenceParetoArchive(contract)
    @test insert_candidate!(archive, prepared_b).status == :inserted
    insertion_a = insert_candidate!(archive, prepared_a)
    @test insertion_a.status == :inserted
    @test insertion_a.removed_design_ids == [genome_b.design_id]
    @test insert_candidate!(archive, prepared_c).status == :inserted
    @test insert_candidate!(archive, higher_fidelity).status == :inserted
    @test length(archive.tiers) == 2
    @test insert_candidate!(archive, missing).status == :rejected

    structural_registry = EvaluatorRegistry()
    register!(structural_registry, StructuralIREvaluatorV1())
    structural_bundle = evaluate_design(structural_registry, "structural_ir_v1", genome_a)
    structural_only = prepare_candidate(genome_a, [structural_bundle], contract)
    @test !structural_only.eligible
    @test isempty(structural_only.objectives)
end
