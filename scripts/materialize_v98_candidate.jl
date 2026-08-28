using JSON3
using FusionConceptAI

length(ARGS) == 2 || error("usage: materialize_v98_candidate.jl REQUEST_INDEX OUTPUT.json")
index = parse(Int, ARGS[1])
result = evaluate_indexed_device_v98(index)
result["candidate_state"] == "computational_candidate" || error(
    "request $index is not a v98 computational candidate: $(result["candidate_state"])")
path = abspath(ARGS[2])
mkpath(dirname(path))
temporary = path * ".partial"
open(temporary, "w") do io
    JSON3.pretty(io, result)
    write(io, '\n')
end
mv(temporary, path; force = true)
println(path)
println(result["result_hash"])
