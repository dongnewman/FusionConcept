using JSON3
using FusionConceptAI

output_path = isempty(ARGS) ? joinpath(@__DIR__, "..", "runs",
    "fixed_topology_minimality_v84.json") : abspath(ARGS[1])

# Seed 72 identifies the already exercised fixed graph topology. It is used only
# to construct T; physical, operating, and control variants use independent streams.
topology = generate_graph_native_topology_v69(72)
structure_hash = graph_isomorphism_hash_v69(topology)
grammar = default_candidate_realization_grammar_v2(structure_hash)
artifact = run_fixed_topology_minimality_v84(grammar;
    physical_variants = 1:2, operating_variants = 1:2,
    control_variants = 1:2, routes = ["closed/mixed", "open/mixed"],
    evidence_level = "analytic_lower_bound")

mkpath(dirname(output_path))
open(output_path, "w") do io
    JSON3.pretty(io, artifact)
    write(io, '\n')
end
println("v84_output=", output_path)
println("v84_result_hash=", artifact["result_hash"])
println("v84_evaluated_count=", artifact["evaluated_count"])
println("v84_hard_gate_pass_count=", artifact["hard_gate_pass_count"])
println("v84_pareto_count=", length(artifact["pareto_archive"]["entries"]))
println("v84_simplest_candidate=", artifact[
    "simplest_candidate_within_declared_grammar_and_evidence"])
