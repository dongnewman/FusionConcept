using Test
using JSON3
using SHA

if !isdefined(Main, :verify_protocol_seal_v92)
    include(joinpath(@__DIR__, "..", "src", "protocol_seal_runtime_v92.jl"))
end

@testset "v92 stage-0 protocol seal" begin
    root = normpath(joinpath(@__DIR__, ".."))
    audit = verify_protocol_seal_v92(root)
    @test audit["status"] == "pass"
    @test audit["protocol_id"] == V92_PROTOCOL_ID
    @test audit["seal_material_sha256"] ==
        "84e26b5011f0e50d4989160633846490bd3ca79264e6495f735100e5c5a73328"
    @test length(audit["manifest_hashes_sha256"]) == 5
    @test length(audit["input_audit"]) == 2
    @test audit["input_audit"][2]["count"] == 417
    @test audit["result_file_count_now"] >= 0
    seal = JSON3.read(read(joinpath(root, "config", "v92",
        "protocol_seal_v92.json"), String))
    @test seal.high_fidelity_result_count_at_seal == 0
    @test seal.sealed_before_any_v92_high_fidelity_result_was_generated_or_read == true

    route = JSON3.read(read(joinpath(root, "config", "v92",
        "capability_route_manifest_v92.json"), String))
    @test Set(String.(route.allowed_routing_axes)) == Set([
        "declared_operators", "state_variables", "region_dimensions",
        "boundary_conditions", "interface_conditions", "field_semantics",
        "evidence_obligations", "solver_input_compatibility"])
    @test route.forbidden_key_scan_required_for_requests_and_routes == true

    validation = JSON3.read(read(joinpath(root, "config", "v92",
        "validation_dataset_split_v92.json"), String))
    @test validation.verification_controls.validation_credit == false
    @test validation.verification_controls.ITER_experimental_validation_credit == false

    mktemp() do path, io
        write(io, UInt8[0xef, 0xbb, 0xbf])
        write(io, "{\"status\":\"pass\"}")
        close(io)
        @test _v92_json(path)["status"] == "pass"
    end
end
