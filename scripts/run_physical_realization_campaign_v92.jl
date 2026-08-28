using FusionConceptAI
using JSON3

root = normpath(joinpath(@__DIR__, ".."))
summary = run_physical_realization_campaign_v92(root)
JSON3.pretty(stdout, summary; allow_inf = false)
println()
