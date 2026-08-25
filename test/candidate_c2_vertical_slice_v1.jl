using Test
using JSON3

@testset "real closed/open assemblies traverse the same C2 chain" begin
    path = joinpath(@__DIR__, "..", "runs",
        "candidate_c2_vertical_slice_v1_20260825.json")
    artifact = JSON3.read(read(path, String))
    @test artifact.chain_contract.family_or_device_routing_used === false
    @test artifact.chain_contract.candidate_declarations_are_feasibility_evidence === false
    @test artifact.summary.evaluated_assembly_count == 2
    @test artifact.summary.terminal_hard_failure_count == 2
    @test artifact.summary.complete_c2_evidence_count == 0
    rows = collect(artifact.rows)
    @test Set(String(row.route_metadata) for row in rows) ==
        Set(["closed_flux", "open_flux"])
    gate_sets = [String.(row.slice.decision.required_gate_ids) for row in rows]
    @test gate_sets[1] == gate_sets[2] ==
        ["engineering", "independent_evidence", "stage_3_residual",
            "stage_4_stability"]
    for row in rows
        @test String(row.slice.decision.completeness) == "incomplete"
        @test String(row.slice.decision.candidate_conclusion) == "fail"
        @test row.slice.decision.terminate === true
        @test String(row.slice.decision.termination_reason) ==
            "authoritative_terminal_failure"
        @test any(failure -> failure.authoritative_for_gate === true &&
            failure.terminates_candidate === true,
            row.slice.decision.narrow_failures)
    end
    @test rows[1].slice.state_package.particle_accounts[1].field_id ==
        rows[2].slice.state_package.particle_accounts[1].field_id
    @test String.(getproperty.(rows[1].slice.state_package.evidence_fields, :field_id)) ==
        String.(getproperty.(rows[2].slice.state_package.evidence_fields, :field_id))
end
