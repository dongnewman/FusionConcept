using Test
using JSON3
using FusionConceptAI

@testset "v92 family-neutral high-fidelity solver portfolio" begin
    root = normpath(joinpath(@__DIR__, ".."))
    audit = audit_solver_installations_v92(root)
    @test audit["records"] |> length == 8
    @test "grad_shafranov_free_boundary" in audit["available_capabilities"]
    @test "three_dimensional_finite_pressure_equilibrium" in
        audit["available_capabilities"]
    @test "independent_three_dimensional_finite_pressure_equilibrium" in
        audit["available_capabilities"]
    @test !("open_field_extended_mhd_or_kinetic" in
        audit["available_capabilities"])

    dossier_path = joinpath(root, "runs",
        "physical_closure_v92_formal_417_20260828",
        "realization_dossiers_v92.jsonl")
    realization = open(dossier_path, "r") do io
        for line in eachline(io)
            row = JSON3.read(line)
            row.qualification.status == "pass" && return row
        end
        error("no realization-pass dossier")
    end
    route = route_equilibrium_capability_v92(realization)
    @test route["route_id"] == "mixed_topology_coupled"
    @test route["family_or_device_label_used"] == false
    @test route["open_field_sent_to_nested_surface_solver"] == false
    @test Set(keys(route["routing_axes"])) == Set(V92_ROUTING_AXES)
    request = compile_equilibrium_request_v92(realization)
    @test request.payload["route"]["route_id"] == "mixed_topology_coupled"
    @test length(request.payload["mesh_levels"]) == 3
    result = execute_equilibrium_request_v92(request, audit)
    @test result.payload["status"] == "unsupported"
    @test result.payload["solver_executed"] == false
    @test result.payload["feasibility_credit"] == false
    @test result.payload["unresolved_solver_disagreement"] ==
        "unknown_independent_model_missing"

    pure3d = FusionConceptAI._v92_plain(realization)
    obligations = pure3d["applicability_obligations"]
    obligations["field_semantics"] = ["three_dimensional_closed"]
    obligations["boundary_conditions"] = ["closed", "periodic"]
    obligations["declared_operators"] = ["field_balance", "energy_balance"]
    pure_route = route_equilibrium_capability_v92(pure3d)
    @test pure_route["route_id"] ==
        "three_dimensional_nested_closed_surfaces"
    @test pure_route["primary_capability"] ==
        "three_dimensional_finite_pressure_equilibrium"
end
