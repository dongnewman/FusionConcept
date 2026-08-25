using Test
using FusionConceptAI
using JSON3
using SHA

const SEPV2_ROOT = normpath(joinpath(@__DIR__, ".."))

function sepv2_contract(id)
    return only(filter(item -> item.operator_id == id,
        default_stability_capability_registry_v2()))
end

function sepv2_evidence(binding, id; favorable = true, complete = true)
    contract = sepv2_contract(id)
    perturbation = StabilityPerturbationSpecV2("test_$id", id;
        equations = ["manufactured operator equation"],
        state_input_ids = copy(contract.required_input_ids),
        boundary_conditions = ["declared boundary"], time_semantics = :steady,
        resolution_levels = ["32", "64", "128"], normalization = "unit test")
    return compile_stability_evidence_envelope_v2(binding, repeat("b", 64),
        contract, perturbation; favorable = favorable,
        signed_normalized_margin = favorable ? 0.2 : -0.2,
        convergence_history = complete ? Dict{String,Any}[
            Dict("resolution" => 32, "margin" => 0.19),
            Dict("resolution" => 64, "margin" => 0.20),
            Dict("resolution" => 128, "margin" => 0.20)] : Dict{String,Any}[],
        validity_domain_covered = complete, resolution_verified = complete,
        covered_input_ids = copy(contract.required_input_ids), source_kind = :candidate_solver,
        source_artifact_paths = ["test.json"], source_artifact_hashes = [repeat("c", 64)],
        source_result_hash = repeat("d", 64), candidate_binding_verified = true,
        minimal_failure_scope = favorable ? Dict{String,Any}() :
            Dict{String,Any}("scope" => "manufactured_operator_only"))
end

@testset "Common Stage-4 capability protocol v2" begin
    binding = repeat("a", 64)
    required = ["three_dimensional_equilibrium_v2", "mercier_interchange_v2"]
    context = Dict{String,Any}("dimension" => "periodic_3d",
        "boundary_class" => "closed_flux", "time_mode" => "steady")
    evidence = [sepv2_evidence(binding, id) for id in required]
    complete = compile_stability_stage_v2(binding, required, context, evidence)
    @test complete.stage_status == :pass
    @test complete.stage_complete
    @test complete.c2_stability_support_authorized
    @test isempty(complete.missing_evidence_operator_ids)

    partial = compile_stability_stage_v2(binding, required, context, evidence[1:1])
    @test partial.stage_status == :unknown
    @test !partial.stage_complete
    @test partial.missing_evidence_operator_ids == ["mercier_interchange_v2"]

    failed = compile_stability_stage_v2(binding, required, context,
        [sepv2_evidence(binding, required[1]; favorable = false), evidence[2]])
    @test failed.stage_status == :fail
    @test failed.authoritative_hard_failure
    @test failed.failed_operator_ids == [required[1]]
    @test !failed.c2_stability_support_authorized

    unknown_evidence = sepv2_evidence(binding, required[1]; complete = false)
    @test unknown_evidence.status == :unknown
    @test !unknown_evidence.evidence_authorized

    pulsed = compile_stability_stage_v2(binding, ["pulsed_rhd_stability_v2"],
        Dict{String,Any}("dimension" => "radial_1d",
            "boundary_class" => "moving_material", "time_mode" => "transient"))
    @test pulsed.stage_status == :unsupported
    @test pulsed.unsupported_operator_ids == ["pulsed_rhd_stability_v2"]

    renamed = repeat("e", 64)
    renamed_evidence = [sepv2_evidence(renamed, id) for id in required]
    renamed_result = compile_stability_stage_v2(renamed, required, context, renamed_evidence)
    @test stability_stage_structural_projection_v2(renamed_result) ==
        stability_stage_structural_projection_v2(complete)
end

@testset "Ambipolar solver bridge remains non-compensating" begin
    binding = repeat("7", 64)
    problem = compile_ambipolar_potential_response_problem_v1(
        design_id = "ambipolar_bridge_test", genome_physics_hash = binding,
        domain_id = "open_domain", axial_positions_m = [0.0, 1.0],
        elementary_charge_times_potential_grid_j = [-1.0, 0.0, 1.0],
        electron_density_response_m3 = ones(3, 2),
        ion_density_responses_m3 = Dict("D" => [0.5 0.5; 1.0 1.0; 1.5 1.5]),
        ion_charge_numbers = Dict("D" => 1), response_source_kind = :candidate_solver,
        response_source_artifact_id = "response.json",
        response_source_artifact_hash = repeat("8", 64),
        response_source_result_hash = repeat("9", 64),
        response_candidate_binding_verified = true,
        nonlinear_multispecies_response_verified = true,
        bounce_average_verified = true, resolution_verified = true,
        applicability_verified = true, source_solver_status = :pass,
        source_ids = ["candidate_kinetic_response"])
    observation = solve_ambipolar_potential_response_v1(problem)
    evidence = compile_ambipolar_stage4_evidence_v2(binding, observation;
        source_artifact_paths = ["response.json"],
        source_artifact_hashes = [repeat("8", 64)],
        convergence_history = Dict{String,Any}[
            Dict("resolution" => 64, "maximum_relative_residual" => 0.0),
            Dict("resolution" => 128, "maximum_relative_residual" => 0.0)],
        candidate_binding_verified = true)
    @test evidence.status == :pass
    @test evidence.operator_id == "ambipolar_response_v2"
    @test evidence.evidence_authorized
    required = ["interchange_flute_v2", "ambipolar_response_v2"]
    context = Dict{String,Any}("dimension" => "axisymmetric_2d",
        "boundary_class" => "open_flux", "time_mode" => "steady")
    stage = compile_stability_stage_v2(binding, required, context, [evidence])
    @test stage.stage_status == :unknown
    @test stage.passed_operator_ids == ["ambipolar_response_v2"]
    @test isempty(stage.unsupported_operator_ids)
    @test stage.missing_evidence_operator_ids == ["interchange_flute_v2"]
    @test !stage.c2_stability_support_authorized
end

@testset "DESC guiding-center backend manufactured algebra" begin
    runner = joinpath(SEPV2_ROOT, "scripts", "desc_fast_ion_guiding_center_runner_v1.py")
    artifact = joinpath(SEPV2_ROOT, "runs",
        "desc_fast_ion_guiding_center_self_test_v1_20260824.json")
    raw = JSON3.read(read(artifact, String), Dict{String,Any})
    @test raw["status"] == "pass"
    @test raw["accepted"] === true
    @test raw["runner_source_sha256"] == bytes2hex(sha256(read(runner)))
    @test length(raw["errors"]) == 5
    @test maximum(Float64.(collect(values(raw["errors"])))) <= Float64(raw["tolerance"])
    @test raw["claim_boundary"] ==
        "Manufactured algebra test only; no candidate physics or confinement evidence."
end

@testset "Fixed real panel Stage-4 adapters preserve evidence ceilings" begin
    result = audit_candidate_stage4_real_panel_v2(
        joinpath(SEPV2_ROOT, "fixtures", "candidate_v68_real_panel_v1.json"),
        joinpath(SEPV2_ROOT, "fixtures", "candidate_stage4_real_panel_v2.json");
        root = SEPV2_ROOT)
    @test result["summary"]["closed_flux"]["entry_count"] == 5
    @test result["summary"]["open_flux"]["entry_count"] == 5
    @test result["summary"]["closed_flux"]["complete_stage4_count"] == 0
    @test result["summary"]["open_flux"]["complete_stage4_count"] == 0
    @test result["summary"]["closed_flux"]["authoritative_hard_failure_count"] == 1
    @test result["summary"]["open_flux"]["authoritative_hard_failure_count"] == 0
    @test result["summary"]["open_flux"]["auxiliary_narrow_failure_count"] == 3
    @test result["summary"]["closed_flux"]["auxiliary_narrow_failure_count"] == 0
    pool24 = only(filter(row -> row["panel_entry_id"] == "closed_candidate_pool24",
        result["rows"]))
    @test Set(pool24["compilation"]["passed_operator_ids"]) == Set([
        "three_dimensional_equilibrium_v2", "mercier_interchange_v2",
        "infinite_n_ballooning_v2"])
    @test isempty(pool24["compilation"]["unsupported_operator_ids"])
    @test pool24["compilation"]["missing_evidence_operator_ids"] ==
        ["error_field_response_v2"]
    @test pool24["compilation"]["unknown_operator_ids"] == ["fast_ion_orbit_v2"]
    orbit = only(filter(item -> item["operator_id"] == "fast_ion_orbit_v2",
        pool24["compilation"]["evidence"]))
    @test orbit["status"] == "unknown"
    @test orbit["candidate_binding_verified"] === true
    @test orbit["resolution_verified"] === true
    @test orbit["signed_normalized_margin"] == -0.95
    @test Set(orbit["evidence_tasks"]) >= Set([
        "provide_operator_input:fast_ion_orbit_v2:fast_ion_distribution",
        "provide_operator_input:fast_ion_orbit_v2:wall_geometry",
        "verify_validity_domain:fast_ion_orbit_v2"])
    pool56 = only(filter(row -> row["panel_entry_id"] == "closed_candidate_pool56",
        result["rows"]))
    pool56_orbit = only(filter(item -> item["operator_id"] == "fast_ion_orbit_v2",
        pool56["compilation"]["evidence"]))
    @test pool56_orbit["status"] == "unknown"
    @test pool56_orbit["signed_normalized_margin"] == -0.95
    @test pool56_orbit["source_result_hash"] ==
        "c43004d7ffd0ba8ec5b4641b6f8d5a12dfa4f031b41f53b861c966ef779f24c9"
    @test pool24["compilation"]["stage_status"] == "unknown"
    closed_negative = only(filter(row ->
        row["panel_entry_id"] == "closed_negative_discrete_coil", result["rows"]))
    @test closed_negative["compilation"]["stage_status"] == "fail"
    @test closed_negative["compilation"]["failed_operator_ids"] ==
        ["error_field_response_v2"]
    @test isempty(closed_negative["compilation"]["unsupported_operator_ids"])
    @test closed_negative["compilation"]["authoritative_hard_failure"] === true
    error_field = only(closed_negative["compilation"]["evidence"])
    @test error_field["status"] == "fail"
    @test error_field["candidate_binding_verified"] === true
    @test error_field["resolution_verified"] === true
    @test error_field["source_result_hash"] ==
        "97d7d602f0a0e379e7c3e57fc991f3b17c3609a7563f3447ed517cc151d4ae58"
    @test isapprox(error_field["signed_normalized_margin"],
        -0.033593640062556926; atol = 1.0e-15)
    @test error_field["minimal_failure_scope"]["scope"] ==
        "fixed_current_32_filament_grammar_nominal_boundary_field"
    @test "plasma_error_field_response" in
        error_field["minimal_failure_scope"]["not_falsified"]
    open_candidate = only(filter(row ->
        row["panel_entry_id"] == "open_candidate_mirror_low_force", result["rows"]))
    @test isempty(open_candidate["compilation"]["unsupported_operator_ids"])
    @test open_candidate["compilation"]["missing_evidence_operator_ids"] == [
        "alfven_ion_cyclotron_v2", "ambipolar_response_v2",
        "drift_cyclotron_loss_cone_v2",
        "finite_larmor_radius_v2", "flow_shear_v2", "interchange_flute_v2",
        "m1_global_v2"]
    @test open_candidate["compilation"]["stage_status"] == "unknown"
    @test open_candidate["compilation"]["auxiliary_failed_operator_ids"] ==
        ["minimum_b_stabilization_path_v2"]
    @test open_candidate["compilation"]["authoritative_hard_failure"] === false
    saddle = only(open_candidate["compilation"]["evidence"])
    @test saddle["status"] == "fail"
    @test saddle["resolution_verified"] === true
    @test saddle["signed_normalized_margin"] < 0.0
    @test saddle["minimal_failure_scope"]["scope"] ==
        "repaired_two_coil_finite_winding_local_vacuum_minimum_b_path"
    @test "finite_larmor_radius_stabilization" in
        saddle["minimal_failure_scope"]["not_falsified"]
    negative = only(filter(row -> row["panel_entry_id"] == "open_negative_local_saddle",
        result["rows"]))
    @test negative["compilation"]["stage_status"] == "unknown"
    @test negative["compilation"]["auxiliary_failed_operator_ids"] ==
        ["minimum_b_stabilization_path_v2"]
    @test !negative["compilation"]["stage_complete"]
    @test result["acceptance"]["pulse_route_deferred_without_rhd_eos_opacity"] === true
end
