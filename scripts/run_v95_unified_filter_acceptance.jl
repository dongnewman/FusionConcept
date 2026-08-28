#!/usr/bin/env julia

using FusionConceptAI

root = normpath(joinpath(@__DIR__, ".."))
result = write_unified_filter_acceptance_v95(root)
println("v95 selector acceptance: ", result.acceptance["selector_acceptance"])
println("known-positive recall: ", result.acceptance["known_positive_recall"]["passed"],
    "/", result.acceptance["known_positive_recall"]["total"])
println("generated classification: ", result.acceptance["candidate_status_histogram"])
println("acceptance hash: ", result.acceptance["acceptance_hash"])
