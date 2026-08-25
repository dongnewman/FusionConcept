using Test
using JSON3
using FusionConceptAI

const EPIR_ROOT = normpath(joinpath(@__DIR__, ".."))
const EPIR_BASE = joinpath(EPIR_ROOT, "examples", "freegs_testtokamak_regression_genome.json")
const EPIR_NATIVE = joinpath(EPIR_ROOT, "examples", "freegs_testtokamak_executable_physics_v1.json")

@testset "Executable physics Genome 0.2 and module DAG v1" begin
    executable = load_executable_genome_v1(EPIR_BASE, EPIR_NATIVE)
    validation = validate_executable_genome_v1(executable)
    program = compile_executable_physics_program_v1(executable)

    @test validation.valid
    @test isempty(validation.errors)
    @test length(executable.modules) == 3
    @test program.schedule == ["axisymmetric_magnetic_field_module",
        "axisymmetric_force_balance_module", "field_line_topology_module"]
    @test getfield.(program.modules, :status) == [:ready_for_execution,
        :blocked_unknown_scale, :blocked_unknown_inputs]
    @test program.explicit_module_count == 3
    @test program.migrated_unknown_module_count == 0
    @test program.ready_module_count == 1
    @test length(program.uncovered_operator_ids) == 8
    @test isempty(program.misapplied_operator_ids)
    @test program.claim_ceiling == "C0_executable_program_incomplete_unknown"
    @test !compiled_executable_program_to_dict_v1(program)["promotion_authorized"]
    @test "ipb98_calibration_prior_v1" in program.calibration_prior_operator_ids
    @test !("ipb98_calibration_prior_v1" in program.active_operator_ids)

    genome = load_genome(EPIR_BASE)
    migrated = migrate_legacy_genome_to_executable_v1(genome)
    migrated_validation = validate_executable_genome_v1(migrated)
    migrated_program = compile_executable_physics_program_v1(migrated)
    @test migrated_validation.valid
    @test migrated_program.migrated_unknown_module_count == 1
    @test migrated_program.ready_module_count == 0
    @test only(migrated_program.modules).status == :migrated_unknown
    @test length(migrated_program.uncovered_operator_ids) == 12
    @test any(contains("cannot authorize C1"), migrated_validation.warnings)

    genome_raw = JSON3.read(read(EPIR_BASE, String), Dict{String,Any})
    module_raw = JSON3.read(read(EPIR_NATIVE, String), Dict{String,Any})
    wrong_hash = deepcopy(module_raw)
    wrong_hash["base_genome_physics_hash"] = repeat("0", 64)
    @test_throws ArgumentError parse_executable_genome_v1(genome, wrong_hash)

    relabeled_raw = deepcopy(genome_raw)
    relabeled_raw["design_id"] = "executable_family_label_control"
    relabeled_raw["family"] = "arbitrary_unknown_family_label"
    relabeled_genome = parse_genome(relabeled_raw)
    relabeled_modules = deepcopy(module_raw)
    relabeled_modules["base_genome_physics_hash"] = relabeled_genome.physics_hash
    relabeled_program = compile_executable_physics_program_v1(
        parse_executable_genome_v1(relabeled_genome, relabeled_modules))
    @test program.base_problem.physical_signature_hash ==
        relabeled_program.base_problem.physical_signature_hash
    @test program.program_hash == relabeled_program.program_hash
    @test program.active_operator_ids == relabeled_program.active_operator_ids

    changed_geometry_raw = deepcopy(genome_raw)
    changed_geometry_raw["design_id"] = "executable_geometry_control"
    changed_geometry_raw["plasma_regions"][1]["parameters"]["domain_r_max"]["value"] = 2.1
    changed_genome = parse_genome(changed_geometry_raw)
    changed_modules = deepcopy(module_raw)
    changed_modules["base_genome_physics_hash"] = changed_genome.physics_hash
    changed_program = compile_executable_physics_program_v1(
        parse_executable_genome_v1(changed_genome, changed_modules))
    @test program.program_hash != changed_program.program_hash
    @test program.active_operator_ids == changed_program.active_operator_ids

    empty_equations = deepcopy(module_raw)
    empty_equations["physics_modules"][1]["equations"] = Any[]
    invalid_explicit = parse_executable_genome_v1(genome, empty_equations)
    invalid_report = validate_executable_genome_v1(invalid_explicit)
    @test !invalid_report.valid
    @test any(contains("no governing equations"), invalid_report.errors)

    cycle = deepcopy(module_raw)
    cycle["physics_modules"][1]["dependency_module_ids"] =
        ["field_line_topology_module"]
    invalid_cycle = parse_executable_genome_v1(genome, cycle)
    cycle_report = validate_executable_genome_v1(invalid_cycle)
    @test !cycle_report.valid
    @test "physics module dependency graph contains a cycle" in cycle_report.errors

    unknown_capability = deepcopy(module_raw)
    unknown_capability["physics_modules"][1]["backend_requirements"][1]["capability_id"] =
        "nonexistent_universal_solver"
    invalid_capability = parse_executable_genome_v1(genome, unknown_capability)
    capability_report = validate_executable_genome_v1(invalid_capability)
    @test !capability_report.valid
    @test any(contains("unknown capability"), capability_report.errors)

    registry = EvaluatorRegistry()
    register!(registry, TokamakFreeBoundaryFreeGSV1())
    freegs_bundle = evaluate_design(registry,
        "tokamak_free_boundary_freegs_v1", executable.base_genome)
    bridge = bridge_solver_evidence_v1(executable, program, freegs_bundle)
    normalized = Dict(metric.metric_id => metric for metric in bridge.normalized_bundle.metrics)
    @test freegs_bundle.status == :pass
    @test length(bridge.authorized_contract_ids) == 1
    @test length(bridge.rejected_contract_ids) == 1
    @test Set(keys(normalized)) == Set(["field_solution_converged"])
    @test normalized["field_solution_converged"].status == :pass
    @test all(metric.fidelity == 1 for metric in values(normalized))
    @test "field_line_topology_resolved" in bridge.unmapped_stage_metric_ids
    bridged_assessment = assess_physics_problem_v1(program.base_problem,
        executable.base_genome, [bridge.normalized_bundle])
    @test bridged_assessment.highest_evidence_stage == "C0"
    @test bridged_assessment.hard_gate_status == :unknown
    @test !bridged_assessment.promotion_authorized

    migrated_bridge = bridge_solver_evidence_v1(migrated, migrated_program, freegs_bundle)
    @test isempty(migrated_bridge.authorized_contract_ids)
    @test length(migrated_bridge.rejected_contract_ids) == 2
    @test isempty(migrated_bridge.normalized_bundle.metrics)
    @test migrated_bridge.normalized_bundle.status == :unknown

    @test_throws ArgumentError SolverEvidenceBridgeContractV1(
        "fake", "maxwell_magnetostatic_field_v1", "field_solution_converged",
        ["fake_metric"], "invalid promotion contract", "invalid";
        promotion_authority = true)

    desc_executable = load_executable_genome_v1(
        joinpath(EPIR_ROOT, "examples", "desc_w7x_regression_genome.json"),
        joinpath(EPIR_ROOT, "examples", "desc_w7x_executable_physics_v1.json"))
    desc_program = compile_executable_physics_program_v1(desc_executable)
    @test desc_program.validation.valid
    @test getfield.(desc_program.modules, :status) ==
        [:blocked_unknown_inputs, :blocked_unknown_inputs]
    @test desc_program.ready_module_count == 0
    @test length(desc_program.uncovered_operator_ids) == 8

    mirror_executable = load_executable_genome_v1(
        joinpath(EPIR_ROOT, "examples", "pleiades_wham_isotropic_regression_genome.json"),
        joinpath(EPIR_ROOT, "examples", "pleiades_wham_executable_physics_v1.json"))
    mirror_program = compile_executable_physics_program_v1(mirror_executable)
    @test mirror_program.validation.valid
    @test getfield.(mirror_program.modules, :status) ==
        [:ready_for_execution, :blocked_unknown_inputs, :blocked_unknown_inputs]
    @test mirror_program.ready_module_count == 1
    @test length(mirror_program.uncovered_operator_ids) == 7
end
