using Test
using JSON3
using FusionConceptAI

const REE_ROOT = normpath(joinpath(@__DIR__, ".."))
const REE_GENOME = joinpath(REE_ROOT, "examples",
    "freegs_pointcoil_wall_control_genome_v1.json")
const REE_EXECUTABLE = joinpath(REE_ROOT, "examples",
    "freegs_pointcoil_wall_control_executable_physics_v1.json")

function ree_fixture(; family = nothing)
    genome_raw = JSON3.read(read(REE_GENOME, String), Dict{String,Any})
    executable_raw = JSON3.read(read(REE_EXECUTABLE, String), Dict{String,Any})
    if family !== nothing
        genome_raw["family"] = family
        genome = parse_genome(genome_raw)
        executable_raw["base_genome_physics_hash"] = genome.physics_hash
        delete!(executable_raw, "document_hash")
        executable = parse_executable_genome_v1(genome, executable_raw)
    else
        executable = load_executable_genome_v1(REE_GENOME, REE_EXECUTABLE)
    end
    return executable, compile_executable_physics_program_v1(executable)
end

function ree_scale(executable; value = 0.243, binding = true, fidelity = 2,
        artifact_hash = repeat("a", 64))
    return resolve_applicability_scale_v1(executable,
        "axisymmetric_force_balance_module", "normalized_plasma_beta";
        value = value, unit = "1", derivation = "candidate solver beta_n",
        source_artifact_id = "candidate_equilibrium.json",
        source_artifact_hash = artifact_hash,
        source_result_hash = repeat("b", 64),
        candidate_binding_verified = binding, fidelity = fidelity)
end

function ree_equilibrium(executable, program, runtime; fidelity = 2,
        resolution = true, binding = true, solver_status = :pass,
        solver_converged = true, force_balance = true)
    return compile_equilibrium_convergence_evidence_v1(executable, program, runtime;
        implementation_id = "tokamak_free_boundary_freegs_v1",
        source_artifact_id = "candidate_equilibrium.json",
        source_artifact_hash = repeat("c", 64),
        source_result_hash = repeat("d", 64),
        source_solver_status = solver_status,
        solver_converged = solver_converged,
        force_balance_passed = force_balance,
        independent_residual_verified = true,
        resolution_verified = resolution,
        candidate_binding_verified = binding,
        fidelity = fidelity,
        residuals = Dict("force_balance_l2_relative" => 0.001),
        constraints_checked = ["solver convergence", "independent residual",
            "two-resolution agreement"])
end

@testset "Runtime applicability and equilibrium evidence v1" begin
    executable, program = ree_fixture()
    @test only(filter(item -> item.module_id ==
        "axisymmetric_force_balance_module", program.modules)).status ==
        :blocked_unknown_scale

    scale = ree_scale(executable)
    @test scale.status == :pass
    runtime = resolve_runtime_module_v1(executable, program,
        "axisymmetric_force_balance_module", [scale])
    @test runtime.runtime_status == :ready_for_execution
    @test runtime.resolved_scale_ids == ["normalized_plasma_beta"]
    @test isempty(runtime.unknown_input_ids)
    evidence = ree_equilibrium(executable, program, runtime)
    @test evidence.status == :pass
    @test evidence.c2_support_authorized
    bundle = equilibrium_convergence_evidence_bundle_v1(executable, evidence)
    @test bundle.status == :pass
    @test only(bundle.metrics).metric_id == "equilibrium_converged"
    @test only(bundle.metrics).fidelity == 2
    @test bundle.claim_ceiling == "C2_support_equilibrium_convergence_only"

    renamed, renamed_program = ree_fixture(family = "declassified_control_label")
    renamed_scale = ree_scale(renamed)
    renamed_runtime = resolve_runtime_module_v1(renamed, renamed_program,
        "axisymmetric_force_balance_module", [renamed_scale])
    renamed_evidence = ree_equilibrium(renamed, renamed_program, renamed_runtime)
    @test renamed_evidence.status == evidence.status
    @test renamed_evidence.c2_support_authorized == evidence.c2_support_authorized
    @test renamed_runtime.runtime_status == runtime.runtime_status

    wrong_hash = ApplicabilityScaleEvidenceV1(scale.design_id,
        repeat("0", 64), scale.module_id, scale.parameter_id, scale.value,
        scale.unit, scale.lower_bound, scale.upper_bound, scale.derivation,
        scale.source_artifact_id, scale.source_artifact_hash,
        scale.source_result_hash, scale.candidate_binding_verified,
        scale.fidelity, scale.status, scale.evidence_tasks, scale.warnings,
        scale.evidence_hash)
    @test_throws ArgumentError resolve_runtime_module_v1(executable, program,
        "axisymmetric_force_balance_module", [wrong_hash])

    missing = ree_scale(executable; value = nothing)
    @test missing.status == :unknown
    missing_runtime = resolve_runtime_module_v1(executable, program,
        "axisymmetric_force_balance_module", [missing])
    @test missing_runtime.runtime_status == :blocked_unknown_scale

    raw = JSON3.read(read(REE_EXECUTABLE, String), Dict{String,Any})
    scale_raw = raw["physics_modules"][2]["applicability_scales"][1]
    scale_raw["lower_bound"] = 0.1
    scale_raw["upper_bound"] = 0.2
    bounded = parse_executable_genome_v1(executable.base_genome, raw)
    bounded_program = compile_executable_physics_program_v1(bounded)
    ood = ree_scale(bounded; value = 0.3)
    @test ood.status == :fail
    ood_runtime = resolve_runtime_module_v1(bounded, bounded_program,
        "axisymmetric_force_balance_module", [ood])
    @test ood_runtime.runtime_status == :blocked_ood_scale

    low_fidelity = ree_equilibrium(executable, program, runtime; fidelity = 1)
    @test low_fidelity.status == :unknown
    @test !low_fidelity.c2_support_authorized
    no_resolution = ree_equilibrium(executable, program, runtime; resolution = false)
    @test no_resolution.status == :unknown
    unbound = ree_equilibrium(executable, program, runtime; binding = false)
    @test unbound.status == :unknown
    failed = ree_equilibrium(executable, program, runtime;
        solver_status = :fail, solver_converged = false)
    @test failed.status == :fail
end

@testset "Runtime input evidence is candidate bound" begin
    genome_path = joinpath(REE_ROOT, "examples", "desc_w7x_regression_genome.json")
    executable_path = joinpath(REE_ROOT, "examples", "desc_w7x_executable_physics_v1.json")
    executable = load_executable_genome_v1(genome_path, executable_path)
    program = compile_executable_physics_program_v1(executable)
    scale = resolve_applicability_scale_v1(executable,
        "desc_fixed_boundary_equilibrium_module", "volume_average_beta";
        value = 0.02, unit = "1", derivation = "candidate solver beta",
        source_artifact_id = "desc.json", source_artifact_hash = repeat("1", 64),
        source_result_hash = repeat("2", 64), candidate_binding_verified = true,
        fidelity = 2)
    missing = only(filter(item -> item.module_id ==
        "desc_fixed_boundary_equilibrium_module", program.modules)).missing_input_ids
    @test missing == ["packaged_pressure_profile"]
    input = resolve_runtime_input_v1(executable,
        "desc_fixed_boundary_equilibrium_module", "packaged_pressure_profile";
        source_artifact_id = "desc.json", source_artifact_hash = repeat("3", 64),
        source_result_hash = repeat("4", 64), candidate_binding_verified = true,
        fidelity = 2)
    runtime = resolve_runtime_module_v1(executable, program,
        "desc_fixed_boundary_equilibrium_module", [scale]; input_evidence = [input])
    @test runtime.runtime_status == :ready_for_execution
    @test runtime.resolved_input_ids == ["packaged_pressure_profile"]
    unbound = resolve_runtime_input_v1(executable,
        "desc_fixed_boundary_equilibrium_module", "packaged_pressure_profile";
        source_artifact_id = "desc.json", source_artifact_hash = repeat("3", 64),
        source_result_hash = repeat("4", 64), candidate_binding_verified = false,
        fidelity = 2)
    blocked = resolve_runtime_module_v1(executable, program,
        "desc_fixed_boundary_equilibrium_module", [scale]; input_evidence = [unbound])
    @test blocked.runtime_status == :blocked_unknown_inputs
end

@testset "Pleiades anisotropy remains unknown" begin
    genome_path = joinpath(REE_ROOT, "examples",
        "pleiades_wham_isotropic_regression_genome.json")
    executable_path = joinpath(REE_ROOT, "examples",
        "pleiades_wham_executable_physics_v1.json")
    executable = load_executable_genome_v1(genome_path, executable_path)
    program = compile_executable_physics_program_v1(executable)
    anisotropy = resolve_applicability_scale_v1(executable,
        "pleiades_open_field_equilibrium_module", "pressure_anisotropy_ratio";
        value = nothing, unit = "1",
        derivation = "scalar pressure cannot determine pressure anisotropy",
        source_artifact_id = "pleiades_scalar_pressure_control.json",
        source_artifact_hash = repeat("e", 64),
        source_result_hash = repeat("f", 64),
        candidate_binding_verified = true, fidelity = 2)
    @test anisotropy.status == :unknown
    runtime = resolve_runtime_module_v1(executable, program,
        "pleiades_open_field_equilibrium_module", [anisotropy])
    @test runtime.runtime_status == :blocked_unknown_inputs
    @test "pressure_anisotropy_ratio" in runtime.unknown_scale_ids
end
