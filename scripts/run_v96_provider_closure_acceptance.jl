#!/usr/bin/env julia

using FusionConceptAI

root = normpath(joinpath(@__DIR__, ".."))
result = write_provider_closure_acceptance_v96(root)
acceptance = result.acceptance
println("v96 selector acceptance: ", acceptance["selector_acceptance"])
println("reference recall: ", acceptance["known_positive_recall"]["passed"], "/",
    acceptance["known_positive_recall"]["total"])
println("generated classification: ", acceptance["candidate_status_histogram"])
println("million replay: ", acceptance["million_no_proxy_replay"]["status"])
println("acceptance hash: ", acceptance["acceptance_hash"])
