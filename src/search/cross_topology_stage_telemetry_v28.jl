const _V28_STAGE_IDS = (
    "candidate_binding",
    "topology_projection",
    "genome_annotation",
    "semantic_validation_and_compile",
    "fidelity0_prescreen",
    "record_materialization_and_gate_audit",
)

const _V28_CLAIM_BOUNDARY =
    "V28 profiles the sealed v20 fidelity-0 path with family-balanced candidate selection, stage-attributed failures, process CPU time, wall time, Julia allocations, GC time, and process peak RSS. Timing is host-specific and excluded from deterministic result identity. Controlled failure injection proves attribution only. This layer does not change a Genome, evaluator, gate, search result, physics fidelity, C1 status, or promotion authorization, and it is not a completed 1e7 run."

function process_cpu_seconds_v28()
    if Sys.iswindows()
        handle = ccall((:GetCurrentProcess, "kernel32"), Ptr{Cvoid}, ())
        creation = Ref{UInt64}(0)
        exit_time = Ref{UInt64}(0)
        kernel = Ref{UInt64}(0)
        user = Ref{UInt64}(0)
        ok = ccall((:GetProcessTimes, "kernel32"), Int32,
            (Ptr{Cvoid}, Ref{UInt64}, Ref{UInt64}, Ref{UInt64}, Ref{UInt64}),
            handle, creation, exit_time, kernel, user)
        ok != 0 || error("GetProcessTimes failed")
        return Float64(kernel[] + user[]) * 1.0e-7
    end
    # Portable fallback keeps the telemetry API available, but is explicitly
    # identified as elapsed-time fallback by the runner.
    return time_ns() * 1.0e-9
end

function _v28_stage!(operation::Function,
        trace::Vector{Dict{String,Any}}, stage_id::String;
        inject_failure::Bool = false)
    stage_id in _V28_STAGE_IDS || throw(ArgumentError(
        "unknown v28 telemetry stage $stage_id"))
    wall_start = time_ns()
    cpu_start = process_cpu_seconds_v28()
    rss_before = Int(Sys.maxrss())
    try
        inject_failure && error("injected v28 failure at $stage_id")
        measurement = @timed operation()
        metric = Dict{String,Any}(
            "stage_id" => stage_id,
            "status" => "passed",
            "wall_seconds" => (time_ns() - wall_start) * 1.0e-9,
            "cpu_seconds" => max(0.0,
                process_cpu_seconds_v28() - cpu_start),
            "allocated_bytes" => Int(measurement.bytes),
            "gc_seconds" => Float64(measurement.gctime),
            "process_peak_rss_before_bytes" => rss_before,
            "process_peak_rss_after_bytes" => Int(Sys.maxrss()),
            "exception_type" => nothing,
            "exception_message" => nothing)
        push!(trace, metric)
        return measurement.value
    catch exception
        push!(trace, Dict{String,Any}(
            "stage_id" => stage_id,
            "status" => "failed",
            "wall_seconds" => (time_ns() - wall_start) * 1.0e-9,
            "cpu_seconds" => max(0.0,
                process_cpu_seconds_v28() - cpu_start),
            "allocated_bytes" => nothing,
            "gc_seconds" => nothing,
            "process_peak_rss_before_bytes" => rss_before,
            "process_peak_rss_after_bytes" => Int(Sys.maxrss()),
            "exception_type" => string(typeof(exception)),
            "exception_message" => sprint(showerror, exception)))
        rethrow()
    end
end

function profile_cross_topology_candidate_v28(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        halton_skip::Integer = 4096,
        inject_failure_stage::Union{Nothing,AbstractString} = nothing)
    candidate_index > 0 || throw(ArgumentError(
        "candidate_index must be positive"))
    inject = inject_failure_stage === nothing ? nothing :
        String(inject_failure_stage)
    inject === nothing || inject in _V28_STAGE_IDS || throw(ArgumentError(
        "unknown injected v28 stage $inject"))
    trace = Dict{String,Any}[]
    family = nothing
    try
        binding = _v28_stage!(trace, "candidate_binding",
            inject_failure = inject == "candidate_binding") do
                topology_count = length(context.assemblies)
                assembly_index = mod1(Int(candidate_index), topology_count)
                sample_ordinal = cld(Int(candidate_index), topology_count)
                assembly = context.assemblies[assembly_index]
                values_u = _v20_unit_vector(sample_ordinal,
                    length(_V20_HALTON_PRIMES); skip = Int(halton_skip))
                (topology_count, assembly_index, sample_ordinal, assembly,
                    values_u)
            end
        topology_count, assembly_index, sample_ordinal, assembly, values_u =
            binding
        family = assembly.family
        projection = _v28_stage!(trace, "topology_projection",
            inject_failure = inject == "topology_projection") do
                _v20_projection(context.compiler_context, assembly, values_u)
            end
        proxy, evaluator_id, projection_id, limitations = projection
        genome = _v28_stage!(trace, "genome_annotation",
            inject_failure = inject == "genome_annotation") do
                annotated = _v18_annotate_proxy(proxy, assembly,
                    context.modules)
                _v20_sample_annotation(annotated, assembly, sample_ordinal)
            end
        compiled = _v28_stage!(trace,
            "semantic_validation_and_compile",
            inject_failure = inject ==
                "semantic_validation_and_compile") do
                report = validate_genome(genome)
                report.valid || throw(ArgumentError(
                    "sampled v28/v20 genome invalid: " *
                    join(report.errors, "; ")))
                family_report = assembly.family ==
                    "inertial_confinement_fusion" ?
                    validate_family(laser_icf_family_registry_v15(), genome) :
                    validate_family(default_family_registry(), genome)
                family_report.valid || throw(ArgumentError(
                    "sampled v28/v20 family invalid: " *
                    join(family_report.errors, "; ")))
                mission_contract_for(default_mission_contract_registry(),
                    genome).id == assembly.mission_contract_id ||
                    throw(ArgumentError(
                        "sampled v28/v20 mission contract drifted"))
                declared = _v20_declared_requirements(context, assembly)
                issubset(Set(declared), Set(_requirements(genome))) ||
                    throw(ArgumentError(
                        "sampled v28/v20 genome lost declared evaluator requirements"))
                warnings = sort!(unique(vcat(report.warnings,
                    family_report.warnings)))
                CompiledAttributeGenomeV18(assembly.assembly_id,
                    assembly.graph_hash, assembly.family,
                    assembly.mission_contract_id, copy(assembly.module_ids),
                    genome, evaluator_id, projection_id,
                    sort!(unique(limitations)), declared, warnings)
            end
        prescreen = _v28_stage!(trace, "fidelity0_prescreen",
            inject_failure = inject == "fidelity0_prescreen") do
                _v18_prescreen(compiled, context.evaluators,
                    context.evaluator_registry)
            end
        record = _v28_stage!(trace,
            "record_materialization_and_gate_audit",
            inject_failure = inject ==
                "record_materialization_and_gate_audit") do
                candidate = CrossTopologyCandidateV20(Int(candidate_index),
                    assembly_index, sample_ordinal, prescreen)
                item = cross_topology_candidate_to_dict_v20(candidate)
                item["candidate_index"] == Int(candidate_index) || error(
                    "v28 record candidate identity drifted")
                item
            end
        return Dict{String,Any}(
            "candidate_index" => Int(candidate_index),
            "family" => String(family),
            "status" => "complete",
            "failed_stage" => nothing,
            "stage_metrics" => trace,
            "deterministic_record" => record,
            "deterministic_record_hash" => canonical_hash(record),
            "claim_boundary" => _V28_CLAIM_BOUNDARY)
    catch exception
        failed = isempty(trace) ? nothing : trace[end]["stage_id"]
        return Dict{String,Any}(
            "candidate_index" => Int(candidate_index),
            "family" => family,
            "status" => "failed",
            "failed_stage" => failed,
            "stage_metrics" => trace,
            "deterministic_record" => nothing,
            "deterministic_record_hash" => nothing,
            "exception_type" => string(typeof(exception)),
            "exception_message" => sprint(showerror, exception),
            "claim_boundary" => _V28_CLAIM_BOUNDARY)
    end
end

function balanced_candidate_indices_v28(
        context::RecoverableCrossTopologyContextV20;
        candidates_per_family::Integer = 100)
    candidates_per_family > 0 || throw(ArgumentError(
        "candidates_per_family must be positive"))
    groups = Dict{String,Vector{Int}}()
    for (assembly_index, assembly) in enumerate(context.assemblies)
        push!(get!(groups, assembly.family, Int[]), assembly_index)
    end
    topology_count = length(context.assemblies)
    plan = Dict{String,Any}[]
    for family in sort!(collect(keys(groups)))
        assembly_indices = groups[family]
        for local_index in 1:Int(candidates_per_family)
            cycle = cld(local_index, length(assembly_indices))
            assembly_index = assembly_indices[mod1(local_index,
                length(assembly_indices))]
            candidate_index = assembly_index + (cycle - 1) * topology_count
            push!(plan, Dict{String,Any}(
                "family" => family,
                "family_local_index" => local_index,
                "assembly_index" => assembly_index,
                "sample_ordinal" => cycle,
                "candidate_index" => candidate_index))
        end
    end
    return plan
end

function _v28_quantile(values::Vector{Float64}, probability::Float64)
    isempty(values) && return nothing
    sorted = sort(values)
    position = clamp(Int(ceil(probability * length(sorted))), 1,
        length(sorted))
    return sorted[position]
end

function aggregate_cross_topology_stage_telemetry_v28(
        results::Vector{<:AbstractDict})
    complete = [result for result in results if result["status"] == "complete"]
    failed = [result for result in results if result["status"] == "failed"]
    stage_rows = Dict(stage => Dict{String,Any}[] for stage in _V28_STAGE_IDS)
    family_rows = Dict{String,Vector{Dict{String,Any}}}()
    for result in results
        family = result["family"] === nothing ? "unbound" :
            String(result["family"])
        push!(get!(family_rows, family, Dict{String,Any}[]),
            Dict{String,Any}(result))
        for metric in result["stage_metrics"]
            push!(stage_rows[String(metric["stage_id"])],
                Dict{String,Any}(metric))
        end
    end
    summarize_metrics = function(metrics)
        passed = [metric for metric in metrics if metric["status"] == "passed"]
        walls = Float64[metric["wall_seconds"] for metric in passed]
        cpus = Float64[metric["cpu_seconds"] for metric in passed]
        allocations = Float64[metric["allocated_bytes"] for metric in passed]
        return Dict{String,Any}(
            "attempt_count" => length(metrics),
            "passed_count" => length(passed),
            "failed_count" => length(metrics) - length(passed),
            "wall_seconds_sum" => sum(walls; init = 0.0),
            "wall_seconds_mean" => isempty(walls) ? nothing : sum(walls) /
                length(walls),
            "wall_seconds_p50" => _v28_quantile(walls, 0.50),
            "wall_seconds_p95" => _v28_quantile(walls, 0.95),
            "cpu_seconds_sum" => sum(cpus; init = 0.0),
            "cpu_seconds_mean" => isempty(cpus) ? nothing : sum(cpus) /
                length(cpus),
            "allocated_bytes_sum" => Int(round(sum(allocations; init = 0.0))),
            "allocated_bytes_mean" => isempty(allocations) ? nothing :
                sum(allocations) / length(allocations),
            "gc_seconds_sum" => sum(Float64[metric["gc_seconds"]
                for metric in passed]; init = 0.0))
    end
    stages = Dict(stage => summarize_metrics(stage_rows[stage])
        for stage in _V28_STAGE_IDS)
    families = Dict{String,Any}()
    for (family, rows) in family_rows
        family_complete = [row for row in rows if row["status"] == "complete"]
        all_metrics = Dict{String,Any}[Dict{String,Any}(metric)
            for row in family_complete for metric in row["stage_metrics"]]
        total_wall = sum(Float64[metric["wall_seconds"]
            for metric in all_metrics]; init = 0.0)
        total_cpu = sum(Float64[metric["cpu_seconds"]
            for metric in all_metrics]; init = 0.0)
        families[family] = Dict{String,Any}(
            "attempt_count" => length(rows),
            "completed_count" => length(family_complete),
            "failed_count" => length(rows) - length(family_complete),
            "end_to_end_stage_wall_seconds_sum" => total_wall,
            "end_to_end_stage_cpu_seconds_sum" => total_cpu,
            "candidates_per_stage_wall_second" => total_wall <= 0 ? nothing :
                length(family_complete) / total_wall,
            "allocated_bytes_sum" => sum(Int(metric["allocated_bytes"])
                for metric in all_metrics; init = 0),
            "stage_summaries" => Dict(stage => summarize_metrics(
                Dict{String,Any}[Dict{String,Any}(metric)
                    for row in family_complete for metric in row["stage_metrics"]
                    if metric["stage_id"] == stage]) for stage in _V28_STAGE_IDS))
    end
    failure_counts = Dict{String,Int}()
    for result in failed
        key = String(result["failed_stage"])
        failure_counts[key] = get(failure_counts, key, 0) + 1
    end
    return Dict{String,Any}(
        "attempt_count" => length(results),
        "completed_count" => length(complete),
        "failed_count" => length(failed),
        "stage_summaries" => stages,
        "family_summaries" => families,
        "failure_stage_counts" => failure_counts)
end
