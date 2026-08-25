using Test
using JSON3
using SHA
using FusionConceptAI

const SMC_ROOT = normpath(joinpath(@__DIR__, ".."))

function smc_load(name)
    return load_genome(joinpath(SMC_ROOT, "examples", name))
end

function smc_feature(genome; kind = :candidate_solver, fidelity = 2,
        overrides = Dict{String,Union{Nothing,Bool}}())
    return compile_stability_feature_evidence_v1(genome;
        feature_overrides = overrides,
        source_kind = kind, source_artifact_id = "candidate_state.json",
        source_artifact_hash = repeat("a", 64),
        source_result_hash = repeat("b", 64),
        candidate_binding_verified = true, fidelity = fidelity)
end

function smc_rule(id)
    return only(filter(item -> item.mode_id == id,
        default_stability_mode_registry_v1()))
end

function smc_mode(genome, id; favorable = true, margin = 0.1,
        kind = :candidate_solver, fidelity = 2, resolution = true,
        binding = true)
    return compile_stability_mode_evidence_v1(genome, smc_rule(id);
        solver_id = "candidate_mode_solver_v1", source_kind = kind,
        source_artifact_id = "mode.json", source_artifact_hash = repeat("c", 64),
        source_result_hash = repeat("d", 64),
        candidate_binding_verified = binding, favorable = favorable,
        normalized_margin = margin, fidelity = fidelity,
        resolution_verified = resolution,
        covered_input_ids = copy(smc_rule(id).evaluation_input_ids),
        constraints_checked = ["candidate binding", "resolution convergence"])
end

@testset "Device-label-independent stability applicability v1" begin
    freegs = smc_load("freegs_pointcoil_wall_control_genome_v1.json")
    feature = smc_feature(freegs)
    inventory = compile_stability_mode_inventory_v1(freegs, feature)
    @test "ideal_current_driven_kink_v1" in inventory.active_mode_ids
    @test "resistive_tearing_v1" in inventory.active_mode_ids
    @test "infinite_n_ideal_ballooning_v1" in inventory.active_mode_ids
    @test "open_field_flute_interchange_v1" in inventory.active_mode_ids
    @test "drift_cyclotron_loss_cone_v1" in inventory.unknown_applicability_mode_ids
    @test "alfven_ion_cyclotron_anisotropy_v1" in
        inventory.unknown_applicability_mode_ids
    @test inventory.physical_stability_status == :unknown
    @test !inventory.c2_support_authorized

    raw = JSON3.read(read(joinpath(SMC_ROOT, "examples",
        "freegs_pointcoil_wall_control_genome_v1.json"), String), Dict{String,Any})
    raw["family"] = "declassified_label"
    renamed = parse_genome(raw)
    renamed_inventory = compile_stability_mode_inventory_v1(renamed,
        smc_feature(renamed))
    @test renamed_inventory.active_mode_ids == inventory.active_mode_ids
    @test renamed_inventory.inactive_mode_ids == inventory.inactive_mode_ids
    @test renamed_inventory.unknown_applicability_mode_ids ==
        inventory.unknown_applicability_mode_ids

    desc = smc_load("desc_w7x_regression_genome.json")
    desc_inventory = compile_stability_mode_inventory_v1(desc, smc_feature(desc;
        overrides = Dict{String,Union{Nothing,Bool}}(
            "pressure_gradient_present" => true)))
    @test "mercier_interchange_v1" in desc_inventory.active_mode_ids
    @test "infinite_n_ideal_ballooning_v1" in desc_inventory.active_mode_ids
    @test "finite_n_global_ideal_mhd_v1" in desc_inventory.active_mode_ids
    @test "ideal_current_driven_kink_v1" in desc_inventory.inactive_mode_ids
    @test isempty(desc_inventory.unknown_applicability_mode_ids)
    @test !desc_inventory.evaluation_complete

    pleiades = smc_load("pleiades_wham_isotropic_regression_genome.json")
    mirror_inventory = compile_stability_mode_inventory_v1(pleiades,
        smc_feature(pleiades))
    @test "open_field_flute_interchange_v1" in mirror_inventory.active_mode_ids
    @test "gradient_drift_modes_v1" in mirror_inventory.active_mode_ids
    @test Set(["drift_cyclotron_loss_cone_v1",
        "alfven_ion_cyclotron_anisotropy_v1", "mirror_mode_anisotropy_v1",
        "firehose_anisotropy_v1"]) <= Set(mirror_inventory.unknown_applicability_mode_ids)
    @test !mirror_inventory.applicability_complete
end

@testset "Mode-specific evidence is fail-closed v1" begin
    genome = smc_load("freegs_pointcoil_wall_control_genome_v1.json")
    overrides = Dict{String,Union{Nothing,Bool}}(
        "anisotropic_distribution_present" => false,
        "loss_cone_distribution_present" => false)
    feature = smc_feature(genome; overrides = overrides)
    base = compile_stability_mode_inventory_v1(genome, feature)
    evidence = [smc_mode(genome, id) for id in base.active_mode_ids]
    complete = compile_stability_mode_inventory_v1(genome, feature, evidence)
    @test complete.applicability_complete
    @test complete.evaluation_complete
    @test complete.physical_stability_status == :pass
    @test complete.c2_support_authorized
    bundle = stability_mode_inventory_evidence_bundle_v1(complete)
    @test bundle.status == :pass
    @test only(filter(m -> m.metric_id ==
        "applicable_stability_modes_evaluated", bundle.metrics)).value === true

    failed_evidence = copy(evidence)
    failed_id = first(base.active_mode_ids)
    failed_evidence[findfirst(item -> item.mode_id == failed_id, failed_evidence)] =
        smc_mode(genome, failed_id; favorable = false, margin = -0.02)
    failed = compile_stability_mode_inventory_v1(genome, feature, failed_evidence)
    @test failed.evaluation_complete
    @test failed.physical_stability_status == :fail
    @test !failed.c2_support_authorized
    failed_bundle = stability_mode_inventory_evidence_bundle_v1(failed)
    @test failed_bundle.status == :fail
    @test only(filter(m -> m.metric_id ==
        "applicable_stability_modes_evaluated", failed_bundle.metrics)).value === true

    manufactured_feature = smc_feature(genome; kind = :manufactured,
        overrides = overrides)
    manufactured = [smc_mode(genome, id; kind = :manufactured) for id in
        base.active_mode_ids]
    manufactured_inventory = compile_stability_mode_inventory_v1(genome,
        manufactured_feature, manufactured)
    @test !manufactured_inventory.evaluation_complete
    @test manufactured_inventory.physical_stability_status == :unknown
    @test !manufactured_inventory.c2_support_authorized

    low = smc_mode(genome, first(base.active_mode_ids); fidelity = 1)
    @test low.status == :unknown
    @test !low.mode_support_authorized
    unresolved = smc_mode(genome, first(base.active_mode_ids); resolution = false)
    @test unresolved.status == :unknown
    unbound = smc_mode(genome, first(base.active_mode_ids); binding = false)
    @test unbound.status == :unknown
    missing_inputs = compile_stability_mode_evidence_v1(genome,
        smc_rule(first(base.active_mode_ids)); solver_id = "incomplete_solver_v1",
        source_kind = :candidate_solver, source_artifact_id = "mode.json",
        source_artifact_hash = repeat("c", 64), source_result_hash = repeat("d", 64),
        candidate_binding_verified = true, favorable = true,
        normalized_margin = 0.1, fidelity = 2, resolution_verified = true)
    @test missing_inputs.status == :unknown
    @test any(startswith("provide_mode_input:"), missing_inputs.evidence_tasks)

    wrong = StabilityFeatureEvidenceV1(feature.design_id, repeat("0", 64),
        feature.topology_signature_hash, feature.features, feature.derivations,
        feature.source_kind, feature.source_artifact_id, feature.source_artifact_hash,
        feature.source_result_hash, feature.candidate_binding_verified,
        feature.fidelity, feature.evidence_tasks, feature.feature_hash)
    @test_throws ArgumentError compile_stability_mode_inventory_v1(genome, wrong)
end

@testset "Real DESC evidence remains partial mode support v1" begin
    results_path = joinpath(SMC_ROOT, "runs",
        "stellarator_stability_active_round2_results.json")
    audit_path = joinpath(SMC_ROOT, "runs",
        "stellarator_stability_active_round2_nfp2_medium_fine_audit.json")
    results = JSON3.read(read(results_path, String), Dict{String,Any})
    audit = JSON3.read(read(audit_path, String), Dict{String,Any})
    target_hash = String(audit["target"]["physics_hash"])
    record = only(filter(item -> String(item["physics_hash"]) == target_hash,
        results["records"]))
    genome = parse_genome(record["genome"])
    @test genome.physics_hash == target_hash
    file_hash = bytes2hex(sha256(read(audit_path)))
    feature = compile_stability_feature_evidence_v1(genome;
        source_kind = :candidate_solver,
        source_artifact_id = basename(audit_path), source_artifact_hash = file_hash,
        source_result_hash = String(audit["audit_hash"]),
        candidate_binding_verified = true, fidelity = 2)
    mercier = compile_stability_mode_evidence_v1(genome,
        smc_rule("mercier_interchange_v1"); solver_id = "desc_sampled_mercier_v1",
        source_kind = :candidate_solver, source_artifact_id = basename(audit_path),
        source_artifact_hash = file_hash, source_result_hash = String(audit["audit_hash"]),
        candidate_binding_verified = true, favorable = Bool(audit["fine"]["mercier"]["sampled_favorable"]),
        normalized_margin = Float64(audit["comparisons"]["mercier_minimum_fine_normalized"]),
        fidelity = 2, resolution_verified = Bool(audit["all_passed"]),
        covered_input_ids = copy(smc_rule("mercier_interchange_v1").evaluation_input_ids),
        constraints_checked = sort!(collect(String.(keys(audit["gates"])))),
        warnings = [String(audit["claim_boundary"])])
    ballooning_margin = -Float64(audit["comparisons"]["ballooning_maximum_fine"])
    ballooning = compile_stability_mode_evidence_v1(genome,
        smc_rule("infinite_n_ideal_ballooning_v1");
        solver_id = "desc_sampled_infinite_n_ballooning_v1",
        source_kind = :candidate_solver, source_artifact_id = basename(audit_path),
        source_artifact_hash = file_hash, source_result_hash = String(audit["audit_hash"]),
        candidate_binding_verified = true,
        favorable = Bool(audit["fine"]["ballooning"]["sampled_favorable"]),
        normalized_margin = ballooning_margin, fidelity = 2,
        resolution_verified = Bool(audit["all_passed"]),
        covered_input_ids = copy(smc_rule("infinite_n_ideal_ballooning_v1").evaluation_input_ids),
        constraints_checked = sort!(collect(String.(keys(audit["gates"])))),
        warnings = [String(audit["claim_boundary"])])
    inventory = compile_stability_mode_inventory_v1(genome, feature,
        [mercier, ballooning])
    @test Set(inventory.evaluated_active_mode_ids) ==
        Set(["mercier_interchange_v1", "infinite_n_ideal_ballooning_v1"])
    @test isempty(inventory.failed_active_mode_ids)
    @test !isempty(inventory.missing_active_mode_ids)
    @test !inventory.evaluation_complete
    @test inventory.physical_stability_status == :unknown
    @test !inventory.c2_support_authorized
end
