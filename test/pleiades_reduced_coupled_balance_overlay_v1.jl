@testset "Pleiades reduced coupled balance overlay v1" begin
    path = joinpath(@__DIR__, "..", "knowledge",
        "pleiades_reduced_coupled_balance_overlay_v1.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    proxy = raw["numeric_proxy_balance"]
    authoritative = raw["authoritative_c2_assessment"]
    @test raw["gates"]["all_required_terms_have_numeric_proxy_values"]
    @test raw["gates"]["numeric_proxy_equations_closed"]
    @test !raw["gates"]["all_mechanisms_physically_solved"]
    @test !raw["gates"]["complete_c2_balance_authorized"]
    @test length(raw["term_evidence"]) == length(raw["problem"]["terms"])
    @test length(raw["term_evidence"]) == 21
    @test all(value == "pass" for value in values(proxy["equation_statuses"]))
    @test maximum(Float64.(collect(values(
        proxy["equation_relative_residuals"])))) <= 1.0e-12
    @test proxy["conditional_thermal_storage_rate_w"] > 0.0
    @test authoritative["status"] == "unknown"
    @test authoritative["observed_term_count"] == 21
    @test authoritative["c2_authorized_term_count"] == 0
    @test length(authoritative["unknown_equation_ids"]) == 3
    @test !authoritative["complete_c2_balance_authorized"]
    @test !authoritative["promotion_authorized"]
    @test all(!item["c2_term_authorized"] for item in raw["term_evidence"])
    @test occursin("screening-zero hypotheses", raw["claim_boundary"])
    @test raw["deterministic_hash"] == canonical_hash(Dict{String,Any}(
        key => value for (key, value) in raw if key != "deterministic_hash"))
end
