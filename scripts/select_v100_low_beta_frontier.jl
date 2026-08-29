#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

length(ARGS) == 3 || error("usage: INPUT.jsonl OUTPUT.jsonl RETAIN_COUNT")
input_path, output_path = abspath(ARGS[1]), abspath(ARGS[2])
retain_count = parse(Int, ARGS[3])
retain_count > 0 || error("RETAIN_COUNT must be positive")
rows = [FusionConceptAI._v93_plain(JSON3.read(line)) for line in readlines(input_path)
    if !isempty(strip(line))]
all(row -> row["candidate_state"] == "computational_candidate" &&
    row["engineering_prefilter"]["status"] == "pass", rows) ||
    error("frontier input contains a non-prefilter survivor")
sort!(rows; by = row -> (
    Float64(row["physics_solve"]["metrics"]["beta_n"]),
    -Float64(row["physics_solve"]["metrics"]["net_electric_power_w"]),
    Float64(row["engineering_prefilter"]["metrics"]["additive_peak_field_t"]),
    Float64(row["engineering_prefilter"]["metrics"]["membrane_support_stress_pa"]),
    Float64(row["operating_point"]["major_radius_m"]),
    Float64(row["operating_point"]["magnetic_field_t"]),
    Float64(row["operating_point"]["density_m3"]),
    Float64(row["operating_point"]["temperature_kev"])))
length(rows) > retain_count && resize!(rows, retain_count)
mkpath(dirname(output_path))
open(output_path * ".partial", "w") do io
    for row in rows
        write(io, JSON3.write(row)); write(io, '\n')
    end
end
mv(output_path * ".partial", output_path; force = true)
println(JSON3.write(Dict(
    "selection" => "lowest_candidate_bound_beta_n_then_power_and_peak_field",
    "identity_fields_used_for_selection" => false,
    "retained_count" => length(rows),
    "minimum_beta_n" => minimum(Float64(row["physics_solve"]["metrics"]["beta_n"])
        for row in rows),
    "maximum_beta_n" => maximum(Float64(row["physics_solve"]["metrics"]["beta_n"])
        for row in rows),
    "output_sha256" => bytes2hex(sha256(read(output_path))),
)))
