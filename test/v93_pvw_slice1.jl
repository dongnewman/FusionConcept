using Test
using JSON3
using FusionConceptAI

function synthetic_pvw_declaration_v1()
    states = [Dict("physical_state" => state) for state in
        ("poloidal_flux", "radial_flux_gradient", "pressure")]
    equations = [Dict("governing_operator" => operator) for operator in
        ("solenoidal_magnetic_constraint", "ampere_field_source_consistency",
            "declared_force_balance", "vacuum_field_equations")]
    body = Dict{String,Any}(
        "protocol_id" => V93_PVW_PROTOCOL_ID,
        "regions" => [Dict("region_type" => kind) for kind in ("plasma", "vacuum", "wall")],
        "states" => states, "equations" => equations,
        "declaration_completeness" => Dict("schema_complete" => true, "solver_complete" => true),
        "coordinate_reduction" => "axisymmetric_cylindrical_radial_reduction",
        "slice_parameters" => Dict("plasma_radius_m" => 1.0, "wall_radius_m" => 2.0,
            "psi_wall_wb_per_rad" => 0.0, "dp_dpsi_pa_per_wb_per_rad" => -8 * 0.1 / (4pi * 1e-7),
            "F_dF_dpsi_t2m2_per_wb_per_rad" => 0.0, "surface_current_a_per_m" => 0.0))
    body["declaration_hash"] = canonical_hash(body)
    body
end

@testset "v93 plasma-vacuum-wall real capability slice" begin
    root = normpath(joinpath(@__DIR__, ".."))
    seal = verify_v93_pvw_protocol_seal_v1(root)
    @test seal["status"] == "pass"
    @test seal["protocol_id"] == V93_PVW_PROTOCOL_ID

    verification = run_pvw_manufactured_verification_v1()
    @test verification["status"] == "pass"
    @test verification["candidate_equilibrium_credit"] == false
    @test 1.9 < verification["observed_order_medium_fine"] < 2.1
    @test verification["gci_fine_percent"] < 2.0
    @test all(level -> level["monolithic"]["audit"]["final_monolithic_reaudit"], verification["levels"])
    @test all(level -> level["domain_decomposed_state_difference"] <= 1e-9, verification["levels"])

    synthetic = synthetic_pvw_declaration_v1()
    @test route_pvw_slice_v1(synthetic)["status"] == "pass"
    executed = execute_pvw_slice_candidate_v1(synthetic)
    @test executed["solver_executed"] == true
    @test executed["primary_equilibrium_status"] == "pass"
    @test executed["numerical_vvuq_status"] == "pass"
    @test executed["validation_vvuq_status"] == "unknown_validation_domain"
    @test executed["status"] == "unknown_solver_disagreement"

    v91_path = joinpath(root, "runs", "multitopology_v91_formal_1000000_20260827",
        "survivor_dossiers_v91.jsonl")
    v92_path = joinpath(root, "runs", "physical_closure_v92_formal_417_20260828",
        "realization_dossiers_v92.jsonl")
    if isfile(v91_path) && isfile(v92_path)
        v91_index = Dict(String(item.dossier_hash) => item for item in
            (JSON3.read(line) for line in eachline(v91_path)))
        v92 = first(item for item in (JSON3.read(line) for line in eachline(v92_path))
            if String(item.qualification.status) == "pass")
        v91 = v91_index[String(v92.candidate_hash)]
        declaration = regenerate_complete_v93_declaration_v1(v91, v92)
        @test declaration["declaration_completeness"]["schema_complete"] == true
        @test declaration["declaration_completeness"]["solver_complete"] == false
        @test length(declaration["regions"]) == 6
        @test !isempty(declaration["states"])
        @test !isempty(declaration["equations"])
        @test !isempty(declaration["interfaces"])
        @test route_pvw_slice_v1(declaration)["status"] == "unsupported_operator_or_backend"
        @test execute_pvw_slice_candidate_v1(declaration)["solver_executed"] == false
        relabeled_v91 = Dict{String,Any}(String(k) => v for (k, v) in pairs(v91))
        relabeled_v92 = Dict{String,Any}(String(k) => v for (k, v) in pairs(v92))
        relabeled_v91["candidate_id"] = "changed"; relabeled_v91["family"] = "erased"
        relabeled_v92["candidate_id"] = "changed"; relabeled_v92["device_type"] = "erased"
        relabeled = regenerate_complete_v93_declaration_v1(relabeled_v91, relabeled_v92)
        @test declaration["declaration_hash"] == relabeled["declaration_hash"]
        @test route_pvw_slice_v1(declaration)["route_hash"] == route_pvw_slice_v1(relabeled)["route_hash"]
    end
end
