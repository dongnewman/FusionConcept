using Test
using JSON3
using FusionConceptAI

function v93_test_declaration(; tag = "alpha", reverse_regions = false)
    regions = [
        Dict("region_id" => "left", "region_type" => "plasma", "dimension" => 3,
            "geometry_fields" => Dict("map" => "cube", "scale_m" => 1.0),
            "material_fields" => Dict("mu_relative" => 1.0),
            "boundary_conditions" => [Dict("condition_id" => "outer_flux", "kind" => "closed")],
            "display_label" => tag),
        Dict("region_id" => "right", "region_type" => "vacuum", "dimension" => 3,
            "geometry_fields" => Dict("map" => "shell", "scale_m" => 2.0),
            "material_fields" => Dict("mu_relative" => 1.0),
            "boundary_conditions" => [Dict("condition_id" => "far_field", "kind" => "closed")],
            "display_label" => tag * "-other")]
    reverse_regions && reverse!(regions)
    Dict{String,Any}(
        "family" => tag, "display_label" => tag,
        "regions" => regions,
        "states" => [
            Dict("state_id" => "magnetic_field", "region_id" => "left", "units" => "T",
                "space" => "H_div", "components" => 3),
            Dict("state_id" => "pressure", "region_id" => "left", "units" => "Pa",
                "space" => "H1", "components" => 1),
            Dict("state_id" => "current_density", "region_id" => "left", "units" => "A m^-2",
                "space" => "H_div", "components" => 3),
            Dict("state_id" => "vacuum_field", "region_id" => "right", "units" => "T",
                "space" => "H_curl", "components" => 3),
            Dict("state_id" => "interface_multiplier", "region_id" => "right", "units" => "T",
                "space" => "mortar_dual", "components" => 1)],
        "equations" => [
            Dict("equation_id" => "force", "region_id" => "left", "state_owner" => "pressure",
                "units" => "N m^-3", "governing_operator" => "declared_force_balance",
                "additive_operators" => String[], "jacobian_blocks" => ["pressure", "magnetic_field", "current_density"],
                "conserved_quantities" => ["momentum"], "validity_domain" => Dict("pressure_positive" => true),
                "source_citation" => "steady momentum balance"),
            Dict("equation_id" => "vacuum", "region_id" => "right", "state_owner" => "vacuum_field",
                "units" => "A m^-2", "governing_operator" => "vacuum_field_equations",
                "additive_operators" => String[], "jacobian_blocks" => ["vacuum_field"],
                "conserved_quantities" => ["magnetic_flux"], "validity_domain" => Dict("vacuum" => true),
                "source_citation" => "vacuum Maxwell equations")],
        "interfaces" => [Dict("interface_id" => "join", "minus_region_id" => "left",
            "plus_region_id" => "right", "geometry" => Dict("surface" => "plane"),
            "conditions" => [Dict("condition_id" => "normal_magnetic_flux_continuity")],
            "coupling_method" => "lagrange_multiplier", "multiplier_space" => "mortar_dual_scalar")],
        "sources_sinks" => Any[],
        "model_validity_domains" => [Dict("domain_id" => "positive_pressure")],
        "evidence_obligations" => ["equilibrium", "numerical_vvuq", "independent_solver_comparison"],
        "discretization" => Dict("form" => "mixed_conforming_fem", "monolithic_residual" => true,
            "domain_decomposition" => true, "mesh_levels" => ["coarse", "medium", "fine"]))
end

@testset "v93 sealed family-neutral multiregion protocol" begin
    root = normpath(joinpath(@__DIR__, ".."))
    seal = verify_protocol_seal_v93(root)
    @test seal["status"] == "pass"

    a = v93_test_declaration(tag = "first")
    b = v93_test_declaration(tag = "randomized-name", reverse_regions = true)
    ir = compile_multiregion_equilibrium_ir_v93(a)
    @test length(ir.regions) == 2
    @test length(ir.equations) == 2
    @test audit_label_erasure_invariance_v93(a, b)["status"] == "pass"
    @test audit_candidate_permutation_invariance_v93([a, b])["status"] == "pass"

    request = compile_multiregion_equilibrium_request_v93(a)
    @test request.compilation_status == "unsupported_operator_or_backend"
    @test execute_multiregion_equilibrium_request_v93(request).status == "unsupported_operator_or_backend"

    manufactured = run_manufactured_verification_v93()
    @test manufactured["status"] == "pass"
    @test manufactured["candidate_equilibrium_credit"] == false
    @test audit_holdout_capability_fixtures_v93(root)["status"] == "pass"
    @test audit_v93_static_anti_specialization(root)["status"] == "pass"
    @test run_v93_negative_controls()["status"] == "pass"

    penalty = deepcopy(a)
    penalty["interfaces"][1]["coupling_method"] = "penalty"
    @test_throws ArgumentError compile_multiregion_equilibrium_ir_v93(penalty)
    missing = deepcopy(a)
    delete!(missing["equations"][1], "governing_operator")
    @test_throws ArgumentError compile_multiregion_equilibrium_ir_v93(missing)

    v92_path = joinpath(root, "runs", "physical_closure_v92_formal_417_20260828",
        "realization_dossiers_v92.jsonl")
    if isfile(v92_path)
        first_record = JSON3.read(first(eachline(v92_path)))
        legacy = compile_v92_realization_request_v93(first_record;
            source_provenance = Dict("source_line" => 1))
        @test legacy.compilation_status == "unsupported_operator_or_backend"
        @test legacy.problem === nothing
        @test !isempty(legacy.translation_gaps)
        @test execute_multiregion_equilibrium_request_v93(legacy).solver_executed == false
    end
end
