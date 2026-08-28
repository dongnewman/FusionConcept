const V84_SHARDED_FUNNEL_CLAIM_BOUNDARY =
    "The v84 sharded funnel exhausts only the declared fixed-topology variant grid. Analytic, finite-filament Biot-Savart, and Poincare dispositions remain separate candidate-bound evidence levels; later evidence never rewrites an earlier disposition and survival grants no finite-pressure, stability, kinetic, engineering, VVUQ, net-power, or originality credit."

function _v84_variant_to_dict(item::RealizationVariantTupleV1)
    return Dict{String,Any}("structure_hash" => item.structure_hash,
        "physical_variant" => item.physical_variant,
        "operating_variant" => item.operating_variant,
        "control_variant" => item.control_variant, "tuple_hash" => item.tuple_hash)
end

function _v84_complexity_from_dict(raw)
    item = Dict{String,Any}(String(key) => value for (key, value) in raw)
    provisional = DeviceComplexityManifestV1(String(item["schema_version"]),
        String(item["candidate_binding_hash"]), String(item["grammar_hash"]),
        String(item["structure_hash"]), String(item["evidence_level"]),
        Int(item["component_count"]), Int(item["power_supply_count"]),
        Float64(item["conductor_length_m"]),
        Float64(item["maximum_curvature_m_inv"]),
        Float64(item["support_mass_kg"]), Int(item["control_complexity"]),
        String(item["source_hash"]), String(item["manifest_hash"]))
    canonical_hash(_v84_complexity_body(provisional)) == provisional.manifest_hash ||
        throw(ArgumentError("complexity manifest hash mismatch"))
    return provisional
end

function _v84_complexity_sort_key(row)
    complexity = row["complexity"]
    return (Int(complexity["component_count"]),
        Int(complexity["power_supply_count"]),
        Float64(complexity["conductor_length_m"]),
        Float64(complexity["maximum_curvature_m_inv"]),
        Float64(complexity["support_mass_kg"]),
        Int(complexity["control_complexity"]), String(row["candidate_id"]))
end

"Hash only the finite-filament field inputs, not operating/control metadata."
function _v84_physical_signature(row)
    binding = row["binding"]
    return canonical_hash(Dict{String,Any}(
        "structure_hash" => row["structure_hash"],
        "physical" => binding["physical"],
        "field_model" => "v84_joint_low_order_finite_filament_v1",
        "field_current_a" => 2.2e5, "field_turns" => 10,
        "major_radius_m" => 3.0, "minor_radius_m" => 0.65,
        "coil_clearance_m" => 0.22))
end

function _v84_stratified_limit(rows, limit::Integer; stratum_key)
    limit > 0 || throw(ArgumentError("queue limit must be positive"))
    groups = Dict{String,Vector{Dict{String,Any}}}()
    for row in rows
        push!(get!(groups, String(stratum_key(row)), Dict{String,Any}[]), row)
    end
    keys_sorted = sort!(collect(keys(groups)))
    for key in keys_sorted
        sort!(groups[key]; by = _v84_complexity_sort_key)
    end
    selected = Dict{String,Any}[]
    depth = 1
    while length(selected) < limit
        added = false
        for key in keys_sorted
            depth <= length(groups[key]) || continue
            push!(selected, groups[key][depth]); added = true
            length(selected) == limit && break
        end
        added || break
        depth += 1
    end
    return selected
end

function compile_v84_candidate_grid_v1(grammar::CandidateRealizationGrammarV2;
        physical_variants, operating_variants, control_variants,
        routes = grammar.allowed_routes)
    physical = sort!(unique(Int.(collect(physical_variants))))
    operating = sort!(unique(Int.(collect(operating_variants))))
    control = sort!(unique(Int.(collect(control_variants))))
    route_values = sort!(unique(String.(collect(routes))))
    all(>(0), vcat(physical, operating, control)) ||
        throw(ArgumentError("v84 grid variants must be positive"))
    all(route -> route in grammar.allowed_routes, route_values) ||
        throw(ArgumentError("v84 grid route is outside the grammar"))
    entries = Dict{String,Any}[]
    index = 0
    for p in physical, o in operating, c in control, route in route_values
        index += 1
        variants = compile_realization_variant_tuple_v1(grammar;
            physical_variant = p, operating_variant = o, control_variant = c)
        push!(entries, Dict{String,Any}("candidate_index" => index,
            "physical_variant" => p, "operating_variant" => o,
            "control_variant" => c, "route" => route,
            "variant_tuple_hash" => variants.tuple_hash))
    end
    body = Dict{String,Any}("grammar_hash" => grammar.grammar_hash,
        "structure_hash" => grammar.structure_hash,
        "physical_variants" => physical, "operating_variants" => operating,
        "control_variants" => control, "routes" => route_values,
        "candidate_count" => length(entries))
    return Dict{String,Any}("schema_version" => "1.0.0",
        "entries" => entries, "grid_spec" => body,
        "grid_hash" => canonical_hash(body))
end

function _v84_record_hash(row)
    return canonical_hash(Dict{String,Any}(String(key) => value
        for (key, value) in row if String(key) != "record_hash"))
end

function _v84_write_json_line(io, row)
    write(io, canonical_json(row)); write(io, '\n')
end

function _v84_read_valid_json_lines(path::AbstractString; repair = false)
    isfile(path) || return Dict{String,Any}[]
    rows = Dict{String,Any}[]; valid_lines = String[]; damaged = false
    open(path, "r") do io
        for line in eachline(io)
            isempty(strip(line)) && continue
            try
                row = _stage3_plain_v1(JSON3.read(line, Dict{String,Any}))
                String(get(row, "record_hash", "")) == _v84_record_hash(row) ||
                    throw(ArgumentError("v84 record hash mismatch"))
                push!(rows, row); push!(valid_lines, line)
            catch
                damaged = true
                break
            end
        end
    end
    if damaged && repair
        temporary = path * ".repair"
        open(temporary, "w") do io
            for line in valid_lines
                write(io, line); write(io, '\n')
            end
        end
        mv(temporary, path; force = true)
    elseif damaged
        throw(ArgumentError("invalid or truncated v84 JSONL stream $path"))
    end
    return rows
end

function _v84_analytic_record(grammar, entry, shard_id, evidence_root)
    variants = compile_realization_variant_tuple_v1(grammar;
        physical_variant = Int(entry["physical_variant"]),
        operating_variant = Int(entry["operating_variant"]),
        control_variant = Int(entry["control_variant"]))
    String(entry["variant_tuple_hash"]) == variants.tuple_hash ||
        throw(ArgumentError("candidate grid variant tuple hash mismatch"))
    evaluation = evaluate_realization_vertical_slice_v84(grammar, variants,
        String(entry["route"]); evidence_level = "analytic_lower_bound")
    plan = evaluation["plan"]; result = evaluation["result"]
    evidence_body = Dict{String,Any}(
        "schema_version" => "1.0.0", "stage" => "analytic_lower_bound",
        "candidate_id" => evaluation["candidate_id"],
        "candidate_binding_hash" => evaluation["binding"]["candidate_binding_hash"],
        "plan" => coupled_solve_plan_to_dict_v1(plan),
        "result" => nonlinear_solve_result_to_dict_v1(result),
        "claim_boundary" => REALIZATION_MINIMALITY_V84_CLAIM_BOUNDARY)
    evidence_hash = canonical_hash(evidence_body)
    evidence_path = joinpath(evidence_root, evidence_hash[1:2], evidence_hash * ".json")
    isfile(evidence_path) || _stage3_atomic_json_v1(evidence_path, evidence_body)
    row = Dict{String,Any}(
        "schema_version" => "1.0.0", "stage" => "analytic_lower_bound",
        "shard_id" => Int(shard_id),
        "candidate_index" => Int(entry["candidate_index"]),
        "candidate_id" => String(evaluation["candidate_id"]),
        "route" => String(entry["route"]), "variant_tuple" => _v84_variant_to_dict(variants),
        "structure_hash" => grammar.structure_hash, "grammar_hash" => grammar.grammar_hash,
        "candidate_binding_hash" => String(evaluation["binding"]["candidate_binding_hash"]),
        "binding" => evaluation["binding"], "hard_gates" => evaluation["hard_gates"],
        "hard_gate_passed" => Bool(evaluation["hard_gate_passed"]),
        "complexity" => device_complexity_manifest_to_dict_v1(evaluation["complexity"]),
        "plan_status" => String(plan.status), "result_status" => String(result.status),
        "classification_code" => result.classification_code,
        "v68_result_hash" => result.result_hash,
        "evidence_object_hash" => evidence_hash,
        "evidence_object_path" => relpath(evidence_path, dirname(evidence_root)),
        "claim_boundary" => REALIZATION_MINIMALITY_V84_CLAIM_BOUNDARY)
    row["record_hash"] = _v84_record_hash(row)
    return row
end

"Run one contiguous analytic v84 shard with repairable append-only checkpoints."
function run_v84_analytic_shard_v1(grammar::CandidateRealizationGrammarV2,
        grid, shard_id::Integer, first_candidate_index::Integer,
        last_candidate_index::Integer; output_directory::AbstractString,
        checkpoint_interval::Integer = 25, resume::Bool = true,
        stop_after_candidates::Union{Nothing,Integer} = nothing)
    shard_id > 0 || throw(ArgumentError("shard_id must be positive"))
    entries = grid["entries"]
    1 <= first_candidate_index <= last_candidate_index <= length(entries) ||
        throw(ArgumentError("invalid v84 analytic shard candidate range"))
    checkpoint_interval > 0 || throw(ArgumentError("checkpoint_interval must be positive"))
    String(grid["grid_spec"]["grammar_hash"]) == grammar.grammar_hash ||
        throw(ArgumentError("v84 grid and grammar differ"))
    mkpath(output_directory)
    prefix = "v84_analytic_shard_$(lpad(Int(shard_id), 3, '0'))"
    partial_path = joinpath(output_directory, prefix * ".jsonl.partial")
    stream_path = joinpath(output_directory, prefix * ".jsonl")
    summary_path = joinpath(output_directory, prefix * ".summary.json")
    if isfile(summary_path) && isfile(stream_path)
        summary = _stage3_plain_v1(JSON3.read(read(summary_path, String),
            Dict{String,Any}))
        String(summary["grid_hash"]) == String(grid["grid_hash"]) ||
            throw(ArgumentError("completed v84 analytic shard grid hash mismatch"))
        String(summary["grammar_hash"]) == grammar.grammar_hash ||
            throw(ArgumentError("completed v84 analytic shard grammar mismatch"))
        Int(summary["first_candidate_index"]) == Int(first_candidate_index) &&
            Int(summary["last_candidate_index"]) == Int(last_candidate_index) ||
            throw(ArgumentError("completed v84 analytic shard range mismatch"))
        String(summary["stream_sha256"]) == _s70_file_sha256(stream_path) ||
            throw(ArgumentError("completed v84 analytic shard hash mismatch"))
        return summary
    end
    !resume && isfile(partial_path) && rm(partial_path; force = true)
    previous = resume ? _v84_read_valid_json_lines(partial_path; repair = true) :
        Dict{String,Any}[]
    expected_previous = collect(Int(first_candidate_index):
        Int(first_candidate_index) + length(previous) - 1)
    Int.(getindex.(previous, "candidate_index")) == expected_previous ||
        throw(ArgumentError("partial v84 analytic shard is not contiguous"))
    for row in previous
        index = Int(row["candidate_index"]); expected = entries[index]
        String(row["grammar_hash"]) == grammar.grammar_hash &&
            String(row["structure_hash"]) == grammar.structure_hash &&
            String(row["route"]) == String(expected["route"]) ||
            throw(ArgumentError("partial v84 analytic shard binding mismatch"))
    end
    start_index = Int(first_candidate_index) + length(previous)
    added = 0; interrupted = false; exceptions = 0; start_time = time()
    evidence_root = joinpath(output_directory, "evidence_objects", "analytic")
    open(partial_path, isempty(previous) ? "w" : "a") do io
        for candidate_index in start_index:Int(last_candidate_index)
            entry = entries[candidate_index]
            row = try
                _v84_analytic_record(grammar, entry, shard_id, evidence_root)
            catch error
                exceptions += 1
                failure = Dict{String,Any}(
                    "schema_version" => "1.0.0", "stage" => "analytic_lower_bound",
                    "shard_id" => Int(shard_id), "candidate_index" => candidate_index,
                    "candidate_id" => "exception://v84/$candidate_index",
                    "route" => String(entry["route"]),
                    "structure_hash" => grammar.structure_hash,
                    "grammar_hash" => grammar.grammar_hash,
                    "hard_gate_passed" => false,
                    "classification_code" => "uncaught_$(nameof(typeof(error)))",
                    "exception_type" => String(nameof(typeof(error))),
                    "claim_boundary" => V84_SHARDED_FUNNEL_CLAIM_BOUNDARY)
                failure["record_hash"] = _v84_record_hash(failure); failure
            end
            _v84_write_json_line(io, row); added += 1
            added % checkpoint_interval == 0 && flush(io)
            if stop_after_candidates !== nothing && added >= stop_after_candidates
                flush(io); interrupted = true; break
            end
        end
        flush(io)
    end
    if interrupted
        return Dict{String,Any}("status" => "interrupted", "shard_id" => Int(shard_id),
            "processed_count" => length(previous) + added,
            "partial_path" => partial_path,
            "claim_boundary" => V84_SHARDED_FUNNEL_CLAIM_BOUNDARY)
    end
    mv(partial_path, stream_path; force = true)
    rows = _v84_read_valid_json_lines(stream_path)
    summary = Dict{String,Any}(
        "schema_version" => "1.0.0", "stage" => "analytic_lower_bound",
        "status" => "complete", "shard_id" => Int(shard_id),
        "first_candidate_index" => Int(first_candidate_index),
        "last_candidate_index" => Int(last_candidate_index),
        "candidate_count" => length(rows), "grid_hash" => String(grid["grid_hash"]),
        "grammar_hash" => grammar.grammar_hash, "structure_hash" => grammar.structure_hash,
        "hard_gate_pass_count" => count(row -> Bool(get(row,
            "hard_gate_passed", false)), rows),
        "uncaught_exception_count" => count(row -> startswith(String(get(row,
            "classification_code", "")), "uncaught_"), rows),
        "stream_sha256" => _s70_file_sha256(stream_path),
        "elapsed_seconds" => time() - start_time,
        "claim_boundary" => V84_SHARDED_FUNNEL_CLAIM_BOUNDARY)
    deterministic = Dict{String,Any}(key => value for (key, value) in summary
        if key != "elapsed_seconds")
    summary["shard_result_hash"] = canonical_hash(deterministic)
    _stage3_atomic_json_v1(summary_path, summary)
    return summary
end

function _v84_write_jsonl_atomic(path, rows)
    mkpath(dirname(path)); temporary = path * ".partial"
    open(temporary, "w") do io
        for row in rows
            _v84_write_json_line(io, row)
        end
    end
    mv(temporary, path; force = true)
    return path
end

"Merge completed analytic shards and emit the global feasibility-first Pareto queue."
function merge_v84_analytic_shards_v1(grammar::CandidateRealizationGrammarV2,
        grid; output_directory::AbstractString, expected_shard_ids,
        expected_candidate_count::Integer = length(grid["entries"]),
        max_biot_savart_candidates::Integer = 100)
    max_biot_savart_candidates > 0 || throw(ArgumentError(
        "max_biot_savart_candidates must be positive"))
    all_rows = Dict{String,Any}[]; shard_hashes = String[]
    for shard_id in sort!(unique(Int.(collect(expected_shard_ids))))
        prefix = "v84_analytic_shard_$(lpad(shard_id, 3, '0'))"
        stream_path = joinpath(output_directory, prefix * ".jsonl")
        summary_path = joinpath(output_directory, prefix * ".summary.json")
        isfile(stream_path) && isfile(summary_path) || throw(ArgumentError(
            "missing completed v84 analytic shard $shard_id"))
        summary = _stage3_plain_v1(JSON3.read(read(summary_path, String),
            Dict{String,Any}))
        String(summary["grid_hash"]) == String(grid["grid_hash"]) ||
            throw(ArgumentError("analytic shard grid hash mismatch"))
        String(summary["grammar_hash"]) == grammar.grammar_hash ||
            throw(ArgumentError("analytic shard grammar hash mismatch"))
        String(summary["stream_sha256"]) == _s70_file_sha256(stream_path) ||
            throw(ArgumentError("analytic shard stream hash mismatch"))
        append!(all_rows, _v84_read_valid_json_lines(stream_path))
        push!(shard_hashes, String(summary["shard_result_hash"]))
    end
    sort!(all_rows; by = row -> Int(row["candidate_index"]))
    Int.(getindex.(all_rows, "candidate_index")) == collect(1:expected_candidate_count) ||
        throw(ArgumentError("analytic shards do not cover the expected contiguous grid"))
    length(unique(String(row["record_hash"]) for row in all_rows)) == length(all_rows) ||
        throw(ArgumentError("duplicate analytic records across shards"))
    scope = compile_minimality_scope_v1(grammar; evidence_level = "analytic_lower_bound")
    archive = RealizationParetoArchiveV1(scope)
    by_candidate = Dict{String,Dict{String,Any}}()
    for row in all_rows
        get(row, "stage", "") == "analytic_lower_bound" || continue
        all(key -> haskey(row, key),
            ("complexity", "hard_gates", "v68_result_hash", "variant_tuple")) ||
            continue
        candidate_id = String(row["candidate_id"]); by_candidate[candidate_id] = row
        complexity = _v84_complexity_from_dict(row["complexity"])
        insert_realization_pareto_v1!(archive; candidate_id = candidate_id,
            complexity = complexity, hard_gates = row["hard_gates"],
            payload = Dict{String,Any}("route" => row["route"],
                "variant_tuple_hash" => row["variant_tuple"]["tuple_hash"],
                "result_hash" => row["v68_result_hash"],
                "analytic_record_hash" => row["record_hash"]))
    end
    pareto_rows = [by_candidate[String(item["candidate_id"])] for item in archive.entries]
    selected_rows = _v84_stratified_limit(pareto_rows, max_biot_savart_candidates;
        stratum_key = row -> "$(row["route"])|$(row["variant_tuple"]["physical_variant"])")
    queue = Dict{String,Any}[]
    for (queue_index, row) in enumerate(selected_rows)
        physical_signature = _v84_physical_signature(row)
        queued = Dict{String,Any}(
            "schema_version" => "1.0.0", "queue_stage" => "fast_biot_savart",
            "queue_index" => queue_index, "candidate_index" => row["candidate_index"],
            "candidate_id" => row["candidate_id"], "route" => row["route"],
            "structure_hash" => row["structure_hash"],
            "grammar_hash" => row["grammar_hash"],
            "candidate_binding_hash" => row["candidate_binding_hash"],
            "variant_tuple" => row["variant_tuple"], "binding" => row["binding"],
            "complexity" => row["complexity"],
            "physical_signature" => physical_signature,
            "selection_policy" => "route_physical_stratified_complexity_lexicographic_v1",
            "analytic_record_hash" => row["record_hash"],
            "analytic_evidence_hash" => row["evidence_object_hash"],
            "claim_boundary" => V84_SHARDED_FUNNEL_CLAIM_BOUNDARY)
        queued["record_hash"] = _v84_record_hash(queued); push!(queue, queued)
    end
    merged_stream = joinpath(output_directory, "v84_analytic_merged.jsonl")
    queue_path = joinpath(output_directory, "v84_fast_biot_savart_queue.jsonl")
    _v84_write_jsonl_atomic(merged_stream, all_rows)
    _v84_write_jsonl_atomic(queue_path, queue)
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0", "status" => "complete",
        "stage" => "analytic_lower_bound_merge", "grid_hash" => grid["grid_hash"],
        "grammar_hash" => grammar.grammar_hash, "structure_hash" => grammar.structure_hash,
        "candidate_count" => length(all_rows),
        "hard_gate_pass_count" => count(row -> Bool(get(row,
            "hard_gate_passed", false)), all_rows),
        "pareto_archive_count" => length(pareto_rows),
        "pareto_queue_count" => length(queue),
        "biot_savart_queue_limit" => Int(max_biot_savart_candidates),
        "biot_savart_dropped_by_limit_count" => length(pareto_rows) - length(queue),
        "physical_signature_unique_count" => length(unique(String(
            row["physical_signature"]) for row in queue)),
        "physical_signature_duplicate_count" => length(queue) - length(unique(String(
            row["physical_signature"]) for row in queue)),
        "physical_signature_duplicate_rate" => isempty(queue) ? 0.0 :
            (length(queue) - length(unique(String(row["physical_signature"])
                for row in queue))) / length(queue),
        "archive" => realization_pareto_archive_to_dict_v1(archive),
        "merged_stream_sha256" => _s70_file_sha256(merged_stream),
        "queue_sha256" => _s70_file_sha256(queue_path),
        "source_shard_hashes" => sort!(shard_hashes),
        "claim_boundary" => V84_SHARDED_FUNNEL_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    _stage3_atomic_json_v1(joinpath(output_directory,
        "v84_analytic_merged.summary.json"), artifact)
    return artifact
end

function _v84_physical_execution_binding(topology::GraphNativeTopologyV69,
        grammar::CandidateRealizationGrammarV2, queue_row)
    graph_isomorphism_hash_v69(topology) == grammar.structure_hash ||
        throw(ArgumentError("v84 physical topology differs from fixed structure hash"))
    variants = queue_row["variant_tuple"]
    physical_variant = Int(variants["physical_variant"])
    base = generate_physical_parameter_binding_v71(topology,
        8_400_001 + physical_variant)
    v84_binding = queue_row["binding"]
    String(v84_binding["candidate_binding_hash"]) == String(
        queue_row["candidate_binding_hash"]) ||
        throw(ArgumentError("queued v84 binding hash mismatch"))
    physical = v84_binding["physical"]; operating = v84_binding["operating"]
    control = v84_binding["control"]
    base["geometry_class"] = "toroidal_volume_v1"
    base["major_radius_m"] = 3.0
    base["minor_radius_m"] = 0.65
    base["half_length_m"] = 1.5
    base["coil_clearance_m"] = 0.22
    base["field_coil_count"] = Int(physical["field_coil_count"])
    base["field_current_a"] = 2.2e5
    base["field_turns"] = 10
    base["conductor_radius_m"] = 0.045
    base["target_ion_temperature_kev"] *= Float64(operating["temperature_scale"])
    base["target_electron_temperature_kev"] *= Float64(
        operating["temperature_scale"])
    base["target_total_ion_density_m3"] *= Float64(operating["density_scale"])
    base["heating_power_w"] *= 0.8 + 0.1 * Int(
        control["active_controller_modes"])
    base["actuator_capacity_w"] = 1.25 * Float64(base["heating_power_w"])
    base["v84_candidate_binding_hash"] = String(queue_row["candidate_binding_hash"])
    base["v84_analytic_record_hash"] = String(queue_row["analytic_record_hash"])
    base["v84_variant_tuple_hash"] = String(variants["tuple_hash"])
    base["v84_route"] = String(queue_row["route"])
    base["v84_low_order_bases"] = Dict{String,Any}(
        "coil_fourier_coefficients" => physical["coil_fourier_coefficients"],
        "coil_bspline_control_points" => physical["coil_bspline_control_points"],
        "current_potential_coefficients" => physical[
            "current_potential_coefficients"],
        "plasma_boundary_coefficients" => physical[
            "plasma_boundary_coefficients"],
        "actuator_timing_coefficients" => control[
            "actuator_timing_coefficients"],
        "controller_modal_coefficients" => control[
            "controller_modal_coefficients"])
    _graph_v69_assert_label_free(base, "v84_physical_execution_binding")
    return base
end

function _v84_finite_filament_field_component(port, region, binding)
    major = Float64(region["major_radius_m"])
    minor = Float64(region["minor_radius_m"])
    clearance = Float64(binding["coil_clearance_m"])
    base_radius = minor + clearance
    current = Float64(binding["field_current_a"])
    turns = Int(binding["field_turns"])
    bases = binding["v84_low_order_bases"]
    fourier = Float64.(bases["coil_fourier_coefficients"])
    bspline = Float64.(bases["coil_bspline_control_points"])
    potential = Float64.(bases["current_potential_coefficients"])
    coil_count = Int(binding["field_coil_count"])
    helical_periods = 2
    loops = Dict{String,Any}[]; point_count = 192
    for coil_index in 1:coil_count
        phase = 2pi * (coil_index - 1) / coil_count
        centerline = Vector{Vector{Float64}}()
        potential_scale = clamp(1.0 + _v84_fourier(potential, phase, 2), 0.5, 1.5)
        for point_index in 0:point_count
            phi = 2pi * point_index / point_count
            theta = helical_periods * phi + phase
            deformation = clamp(_v84_fourier(fourier, phi + phase, 2) +
                _v84_periodic_cubic_bspline(bspline, phi - phase), -0.35, 0.35)
            local_radius = base_radius * (1.0 + 0.30 * deformation)
            cylindrical_radius = major + local_radius * cos(theta)
            push!(centerline, [cylindrical_radius * cos(phi),
                cylindrical_radius * sin(phi), local_radius * sin(theta)])
        end
        push!(loops, Dict{String,Any}(
            "loop_id" => "$(port["port_id"])_v84_helical_$coil_index",
            "winding_role" => "v84_fourier_bspline_current_potential",
            "centerline_m" => centerline,
            "current_a" => current * potential_scale, "turns" => turns,
            "helical_periods" => helical_periods,
            "basis_binding_hash" => canonical_hash(bases)))
    end
    return Dict{String,Any}(
        "component_kind" => "finite_filament_coil_array_v1",
        "winding_basis" => "v84_joint_fourier_periodic_bspline_current_potential_v1",
        "loops" => loops,
        "conductor" => Dict{String,Any}(
            "material_model" => "bounded_hts_screening_proxy_v1",
            "radius_m" => Float64(binding["conductor_radius_m"]),
            "current_density_limit_a_m2" => 3.0e8,
            "allowable_magnetic_stress_pa" => 4.0e8),
        "model_fidelity" => "candidate_bound_finite_filament_biot_savart_v1")
end

"Compile the exact queued v84 basis coefficients into a finite-filament v71 realization."
function compile_v84_finite_filament_realization_v1(
        topology::GraphNativeTopologyV69,
        compilation::GraphTopologyCompilationV69,
        grammar::CandidateRealizationGrammarV2, queue_row)
    binding = _v84_physical_execution_binding(topology, grammar, queue_row)
    base = compile_physical_device_realization_v71(topology, compilation;
        parameter_binding = binding)
    base.completeness == :complete || return (binding = binding, realization = base)
    regions = Dict(String(item["region_id"]) => item for item in
        base.geometry["regions"])
    ports = Dict(String(item["port_id"]) => item for item in topology.ports)
    components = deepcopy(base.components); mappings = deepcopy(base.port_mappings)
    for index in eachindex(components)
        component = components[index]
        String(component["component_kind"]) == "finite_filament_coil_array_v1" ||
            continue
        port = ports[String(component["bound_port_id"])]
        body = _v84_finite_filament_field_component(port,
            regions[String(component["region_id"])], binding)
        replacement = merge(Dict{String,Any}(
            "component_id" => component["component_id"],
            "realizer_id" => "v84_joint_low_order_finite_filament_v1",
            "region_id" => component["region_id"],
            "bound_port_id" => component["bound_port_id"],
            "bound_resource_ids" => component["bound_resource_ids"]), body)
        replacement["component_hash"] = canonical_hash(replacement)
        components[index] = replacement
    end
    for mapping in mappings
        port = ports[String(mapping["port_id"])]
        String(port["port_kind"]) == "field_source" || continue
        mapping["realizer_id"] = "v84_joint_low_order_finite_filament_v1"
    end
    registry_hash = canonical_hash(Dict{String,Any}(
        "base_registry_hash" => base.registry_hash,
        "extension_id" => "v84_joint_low_order_finite_filament_v1",
        "v84_candidate_binding_hash" => queue_row["candidate_binding_hash"]))
    claim = "Candidate-bound v84 Fourier, periodic B-spline, and current-potential coefficients compiled to finite filaments for Biot-Savart and field-line tracing. This is not finite-build coil engineering or plasma feasibility evidence."
    body = Dict{String,Any}(
        "schema_version" => base.schema_version, "topology_hash" => base.topology_hash,
        "compilation_hash" => base.compilation_hash,
        "candidate_binding_hash" => base.candidate_binding_hash,
        "v84_candidate_binding_hash" => queue_row["candidate_binding_hash"],
        "registry_hash" => registry_hash, "completeness" => String(base.completeness),
        "conclusion" => String(base.conclusion),
        "classification_code" => "v84_finite_filament_requires_biot_savart",
        "geometry" => base.geometry, "components" => components,
        "port_mappings" => mappings,
        "dependency_mappings" => base.dependency_mappings,
        "missing_requirements" => base.missing_requirements,
        "claim_boundary" => claim)
    realization = PhysicalDeviceRealizationV71(base.schema_version,
        base.topology_hash, base.compilation_hash, base.candidate_binding_hash,
        registry_hash, base.completeness, base.conclusion,
        "v84_finite_filament_requires_biot_savart", base.geometry, components,
        mappings, base.dependency_mappings, base.missing_requirements, claim,
        canonical_hash(body))
    return (binding = binding, realization = realization)
end

"Execute candidate-bound finite-filament Biot-Savart, then admit only field-pass rows to v81."
function evaluate_v84_physical_fidelity_v1(topology::GraphNativeTopologyV69,
        compilation::GraphTopologyCompilationV69,
        grammar::CandidateRealizationGrammarV2, queue_row;
        poincare_turns::Integer = 32, poincare_steps_per_turn::Integer = 180,
        poincare_fourier_order::Integer = 4, poincare_bin_count::Integer = 16,
        execute_poincare::Bool = true)
    String(queue_row["grammar_hash"]) == grammar.grammar_hash ||
        throw(ArgumentError("physical queue grammar mismatch"))
    String(queue_row["structure_hash"]) == grammar.structure_hash ||
        throw(ArgumentError("physical queue structure mismatch"))
    String(queue_row["record_hash"]) == _v84_record_hash(queue_row) ||
        throw(ArgumentError("physical queue record hash mismatch"))
    compiled = compile_v84_finite_filament_realization_v1(topology, compilation,
        grammar, queue_row)
    binding = compiled.binding; realization = compiled.realization
    screen = screen_physical_device_v71(realization, binding;
        particle_count = 1, step_count = 1, required_transit_fraction = 1.0e-6)
    if haskey(queue_row, "expected_screen_evidence_hash")
        String(queue_row["expected_screen_evidence_hash"]) == screen.evidence_hash ||
            throw(ArgumentError("Poincare queue Biot-Savart evidence mismatch"))
    end
    field_status = String(get(screen.field_evidence, "status", "unknown"))
    fast_gate_status = realization.completeness != :complete ? "unknown" :
        field_status == "pass" ? "pass" : field_status == "fail" ? "fail" : "unknown"
    poincare = nothing; poincare_gate_status = "not_admitted"
    if execute_poincare && fast_gate_status == "pass"
        poincare = evaluate_poincare_flux_surface_gate_v81(realization, screen, binding;
            target_toroidal_turns = poincare_turns,
            steps_per_turn = poincare_steps_per_turn,
            fourier_order = poincare_fourier_order, bin_count = poincare_bin_count)
        poincare_gate_status = poincare.conclusion == :fail ? "fail" :
            poincare.classification_code ==
                "poincare_surfaces_bounded_requires_downstream_physics" ? "pass" :
            poincare.conclusion == :unsupported ? "unsupported" : "unknown"
    end
    analytic_hash = String(queue_row["analytic_evidence_hash"])
    fast_progression = compile_realization_fidelity_progression_v1(
        candidate_binding_hash = queue_row["candidate_binding_hash"], records = [
            Dict("level" => "analytic_lower_bound", "status" => "pass",
                "evidence_hash" => analytic_hash),
            Dict("level" => "fast_biot_savart", "status" => fast_gate_status,
                "evidence_hash" => screen.evidence_hash)])
    progression = if poincare === nothing
        fast_progression
    else
        compile_realization_fidelity_progression_v1(
            candidate_binding_hash = queue_row["candidate_binding_hash"], records = [
                Dict("level" => "analytic_lower_bound", "status" => "pass",
                    "evidence_hash" => analytic_hash),
                Dict("level" => "fast_biot_savart", "status" => fast_gate_status,
                    "evidence_hash" => screen.evidence_hash),
                Dict("level" => "poincare", "status" => poincare_gate_status,
                    "evidence_hash" => poincare.evidence_hash)])
    end
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "stage" => "physical_fidelity_funnel",
        "candidate_id" => queue_row["candidate_id"], "route" => queue_row["route"],
        "candidate_binding_hash" => queue_row["candidate_binding_hash"],
        "physical_execution_binding_hash" => realization.candidate_binding_hash,
        "analytic_record_hash" => queue_row["analytic_record_hash"],
        "realization" => physical_device_realization_to_dict_v71(realization),
        "physical_execution_binding" => binding,
        "screen" => physical_device_screen_to_dict_v71(screen),
        "fast_biot_savart_gate_status" => fast_gate_status,
        "poincare_eligible" => fast_gate_status == "pass",
        "poincare_admitted" => execute_poincare && fast_gate_status == "pass",
        "poincare_gate_status" => poincare_gate_status,
        "poincare" => poincare === nothing ? nothing :
            poincare_flux_surface_gate_to_dict_v81(poincare),
        "fidelity_progression" => progression,
        "claim_boundary" => V84_SHARDED_FUNNEL_CLAIM_BOUNDARY)
end

function _v84_physical_record(grammar, queue_row, shard_id, topology,
        compilation, evidence_root; poincare_turns, poincare_steps_per_turn,
        poincare_fourier_order, poincare_bin_count, execute_poincare,
        stage_prefix)
    evidence = evaluate_v84_physical_fidelity_v1(topology, compilation, grammar,
        queue_row; poincare_turns = poincare_turns,
        poincare_steps_per_turn = poincare_steps_per_turn,
        poincare_fourier_order = poincare_fourier_order,
        poincare_bin_count = poincare_bin_count,
        execute_poincare = execute_poincare)
    evidence_hash = canonical_hash(evidence)
    evidence_path = joinpath(evidence_root, evidence_hash[1:2], evidence_hash * ".json")
    isfile(evidence_path) || _stage3_atomic_json_v1(evidence_path, evidence)
    row = Dict{String,Any}(
        "schema_version" => "1.0.0", "stage" => "physical_fidelity_funnel",
        "shard_id" => Int(shard_id), "queue_index" => queue_row["queue_index"],
        "candidate_index" => queue_row["candidate_index"],
        "candidate_id" => queue_row["candidate_id"], "route" => queue_row["route"],
        "structure_hash" => grammar.structure_hash, "grammar_hash" => grammar.grammar_hash,
        "candidate_binding_hash" => queue_row["candidate_binding_hash"],
        "analytic_record_hash" => queue_row["analytic_record_hash"],
        "biot_savart_record_hash" => get(queue_row,
            "biot_savart_record_hash", nothing),
        "physical_execution_binding_hash" =>
            evidence["physical_execution_binding_hash"],
        "realization_hash" => evidence["realization"]["realization_hash"],
        "screen_evidence_hash" => evidence["screen"]["evidence_hash"],
        "fast_biot_savart_gate_status" => evidence[
            "fast_biot_savart_gate_status"],
        "execution_mode" => execute_poincare ? "biot_savart_then_poincare" :
            "biot_savart_only",
        "physical_signature" => get(queue_row, "physical_signature",
            _v84_physical_signature(queue_row)),
        "poincare_eligible" => evidence["poincare_eligible"],
        "poincare_admitted" => evidence["poincare_admitted"],
        "poincare_gate_status" => evidence["poincare_gate_status"],
        "poincare_evidence_hash" => evidence["poincare"] === nothing ? nothing :
            evidence["poincare"]["evidence_hash"],
        "poincare_budget_hash" => canonical_hash(Dict{String,Any}(
            "turns" => poincare_turns,
            "steps_per_turn" => poincare_steps_per_turn,
            "fourier_order" => poincare_fourier_order,
            "bin_count" => poincare_bin_count,
            "execute_poincare" => execute_poincare,
            "stage_prefix" => stage_prefix)),
        "evidence_object_hash" => evidence_hash,
        "evidence_object_path" => relpath(evidence_path, dirname(evidence_root)),
        "claim_boundary" => V84_SHARDED_FUNNEL_CLAIM_BOUNDARY)
    row["record_hash"] = _v84_record_hash(row)
    return row
end

"Run a repairable physical-fidelity shard over a contiguous merged Pareto queue range."
function run_v84_physical_fidelity_shard_v1(
        grammar::CandidateRealizationGrammarV2, queue_path::AbstractString,
        shard_id::Integer, first_queue_index::Integer, last_queue_index::Integer;
        output_directory::AbstractString, checkpoint_interval::Integer = 5,
        resume::Bool = true, stop_after_candidates::Union{Nothing,Integer} = nothing,
        poincare_turns::Integer = 32, poincare_steps_per_turn::Integer = 180,
        poincare_fourier_order::Integer = 4, poincare_bin_count::Integer = 16,
        execute_poincare::Bool = true,
        stage_prefix::AbstractString = "v84_physical")
    shard_id > 0 || throw(ArgumentError("shard_id must be positive"))
    queue = _v84_read_valid_json_lines(queue_path)
    1 <= first_queue_index <= last_queue_index <= length(queue) ||
        throw(ArgumentError("invalid v84 physical queue shard range"))
    Int.(getindex.(queue, "queue_index")) == collect(1:length(queue)) ||
        throw(ArgumentError("v84 physical queue is not contiguous"))
    mkpath(output_directory)
    occursin(r"^v84_[a-z_]+$", stage_prefix) || throw(ArgumentError(
        "invalid v84 physical shard stage prefix"))
    prefix = "$(stage_prefix)_shard_$(lpad(Int(shard_id), 3, '0'))"
    partial_path = joinpath(output_directory, prefix * ".jsonl.partial")
    stream_path = joinpath(output_directory, prefix * ".jsonl")
    summary_path = joinpath(output_directory, prefix * ".summary.json")
    queue_sha = _s70_file_sha256(queue_path)
    poincare_budget = Dict{String,Any}(
        "turns" => poincare_turns, "steps_per_turn" => poincare_steps_per_turn,
        "fourier_order" => poincare_fourier_order, "bin_count" => poincare_bin_count,
        "execute_poincare" => execute_poincare, "stage_prefix" => stage_prefix)
    poincare_budget_hash = canonical_hash(poincare_budget)
    if isfile(summary_path) && isfile(stream_path)
        summary = _stage3_plain_v1(JSON3.read(read(summary_path, String),
            Dict{String,Any}))
        String(summary["queue_sha256"]) == queue_sha ||
            throw(ArgumentError("completed physical shard queue hash mismatch"))
        String(summary["grammar_hash"]) == grammar.grammar_hash ||
            throw(ArgumentError("completed physical shard grammar mismatch"))
        Int(summary["first_queue_index"]) == Int(first_queue_index) &&
            Int(summary["last_queue_index"]) == Int(last_queue_index) ||
            throw(ArgumentError("completed physical shard range mismatch"))
        canonical_hash(summary["poincare_budget"]) == poincare_budget_hash ||
            throw(ArgumentError("completed physical shard Poincare budget mismatch"))
        String(summary["stream_sha256"]) == _s70_file_sha256(stream_path) ||
            throw(ArgumentError("completed physical shard stream hash mismatch"))
        return summary
    end
    !resume && isfile(partial_path) && rm(partial_path; force = true)
    previous = resume ? _v84_read_valid_json_lines(partial_path; repair = true) :
        Dict{String,Any}[]
    expected_previous = collect(Int(first_queue_index):
        Int(first_queue_index) + length(previous) - 1)
    Int.(getindex.(previous, "queue_index")) == expected_previous ||
        throw(ArgumentError("partial v84 physical shard is not contiguous"))
    for row in previous
        index = Int(row["queue_index"]); expected = queue[index]
        String(row["candidate_binding_hash"]) == String(
            expected["candidate_binding_hash"]) &&
            String(get(row, "poincare_budget_hash", "")) == poincare_budget_hash ||
            throw(ArgumentError("partial v84 physical shard binding or budget mismatch"))
    end
    topology = generate_graph_native_topology_v69(72)
    graph_isomorphism_hash_v69(topology) == grammar.structure_hash ||
        throw(ArgumentError("v84 physical shard topology hash mismatch"))
    compilation = compile_graph_native_topology_candidate_v69(topology)
    compilation.status == :pass || throw(ArgumentError(
        "v84 physical fixed topology does not compile"))
    start_index = Int(first_queue_index) + length(previous)
    evidence_root = joinpath(output_directory, "evidence_objects", "physical")
    added = 0; interrupted = false; start_time = time()
    open(partial_path, isempty(previous) ? "w" : "a") do io
        for queue_index in start_index:Int(last_queue_index)
            queue_row = queue[queue_index]
            row = try
                _v84_physical_record(grammar, queue_row, shard_id, topology,
                    compilation, evidence_root; poincare_turns = poincare_turns,
                    poincare_steps_per_turn = poincare_steps_per_turn,
                    poincare_fourier_order = poincare_fourier_order,
                    poincare_bin_count = poincare_bin_count,
                    execute_poincare = execute_poincare,
                    stage_prefix = stage_prefix)
            catch error
                failure = Dict{String,Any}(
                    "schema_version" => "1.0.0", "stage" => "physical_fidelity_funnel",
                    "shard_id" => Int(shard_id), "queue_index" => queue_index,
                    "candidate_index" => queue_row["candidate_index"],
                    "candidate_id" => queue_row["candidate_id"],
                    "route" => queue_row["route"],
                    "structure_hash" => grammar.structure_hash,
                    "grammar_hash" => grammar.grammar_hash,
                    "candidate_binding_hash" => queue_row["candidate_binding_hash"],
                    "analytic_record_hash" => queue_row["analytic_record_hash"],
                    "biot_savart_record_hash" => get(queue_row,
                        "biot_savart_record_hash", nothing),
                    "fast_biot_savart_gate_status" => "exception",
                    "execution_mode" => execute_poincare ?
                        "biot_savart_then_poincare" : "biot_savart_only",
                    "physical_signature" => get(queue_row, "physical_signature",
                        _v84_physical_signature(queue_row)),
                    "poincare_eligible" => false,
                    "poincare_admitted" => false,
                    "poincare_gate_status" => "not_admitted",
                    "poincare_budget_hash" => poincare_budget_hash,
                    "classification_code" => "uncaught_$(nameof(typeof(error)))",
                    "exception_type" => String(nameof(typeof(error))),
                    "claim_boundary" => V84_SHARDED_FUNNEL_CLAIM_BOUNDARY)
                failure["record_hash"] = _v84_record_hash(failure); failure
            end
            _v84_write_json_line(io, row); added += 1
            added % checkpoint_interval == 0 && flush(io)
            if stop_after_candidates !== nothing && added >= stop_after_candidates
                flush(io); interrupted = true; break
            end
        end
        flush(io)
    end
    if interrupted
        return Dict{String,Any}("status" => "interrupted", "shard_id" => Int(shard_id),
            "processed_count" => length(previous) + added,
            "partial_path" => partial_path,
            "claim_boundary" => V84_SHARDED_FUNNEL_CLAIM_BOUNDARY)
    end
    mv(partial_path, stream_path; force = true)
    rows = _v84_read_valid_json_lines(stream_path)
    summary = Dict{String,Any}(
        "schema_version" => "1.0.0", "stage" => "physical_fidelity_funnel",
        "status" => "complete", "shard_id" => Int(shard_id),
        "first_queue_index" => Int(first_queue_index),
        "last_queue_index" => Int(last_queue_index), "candidate_count" => length(rows),
        "grammar_hash" => grammar.grammar_hash, "structure_hash" => grammar.structure_hash,
        "queue_sha256" => queue_sha,
        "execution_mode" => execute_poincare ? "biot_savart_then_poincare" :
            "biot_savart_only",
        "stage_prefix" => String(stage_prefix),
        "fast_biot_savart_pass_count" => count(row -> get(row,
            "fast_biot_savart_gate_status", "") == "pass", rows),
        "poincare_admitted_count" => count(row -> Bool(get(row,
            "poincare_admitted", false)), rows),
        "poincare_gate_pass_count" => count(row -> get(row,
            "poincare_gate_status", "") == "pass", rows),
        "uncaught_exception_count" => count(row -> get(row,
            "fast_biot_savart_gate_status", "") == "exception", rows),
        "stream_sha256" => _s70_file_sha256(stream_path),
        "elapsed_seconds" => time() - start_time,
        "poincare_budget" => poincare_budget,
        "claim_boundary" => V84_SHARDED_FUNNEL_CLAIM_BOUNDARY)
    deterministic = Dict{String,Any}(key => value for (key, value) in summary
        if key != "elapsed_seconds")
    summary["shard_result_hash"] = canonical_hash(deterministic)
    _stage3_atomic_json_v1(summary_path, summary)
    return summary
end

function run_v84_biot_savart_shard_v1(
        grammar::CandidateRealizationGrammarV2, queue_path::AbstractString,
        shard_id::Integer, first_queue_index::Integer, last_queue_index::Integer;
        output_directory::AbstractString, checkpoint_interval::Integer = 5,
        resume::Bool = true, stop_after_candidates::Union{Nothing,Integer} = nothing)
    return run_v84_physical_fidelity_shard_v1(grammar, queue_path, shard_id,
        first_queue_index, last_queue_index; output_directory = output_directory,
        checkpoint_interval = checkpoint_interval, resume = resume,
        stop_after_candidates = stop_after_candidates, execute_poincare = false,
        stage_prefix = "v84_biot_savart")
end

function run_v84_poincare_shard_v1(
        grammar::CandidateRealizationGrammarV2, queue_path::AbstractString,
        shard_id::Integer, first_queue_index::Integer, last_queue_index::Integer;
        output_directory::AbstractString, checkpoint_interval::Integer = 5,
        resume::Bool = true, stop_after_candidates::Union{Nothing,Integer} = nothing,
        poincare_turns::Integer = 32, poincare_steps_per_turn::Integer = 180,
        poincare_fourier_order::Integer = 4, poincare_bin_count::Integer = 16)
    return run_v84_physical_fidelity_shard_v1(grammar, queue_path, shard_id,
        first_queue_index, last_queue_index; output_directory = output_directory,
        checkpoint_interval = checkpoint_interval, resume = resume,
        stop_after_candidates = stop_after_candidates,
        poincare_turns = poincare_turns,
        poincare_steps_per_turn = poincare_steps_per_turn,
        poincare_fourier_order = poincare_fourier_order,
        poincare_bin_count = poincare_bin_count, execute_poincare = true,
        stage_prefix = "v84_poincare")
end

function _v84_collect_physical_stage_shards_v1(
        grammar::CandidateRealizationGrammarV2, queue_path::AbstractString;
        output_directory::AbstractString, expected_shard_ids,
        stage_prefix::AbstractString, expected_execution_mode::AbstractString)
    queue = _v84_read_valid_json_lines(queue_path)
    queue_sha = _s70_file_sha256(queue_path)
    all_rows = Dict{String,Any}[]; shard_hashes = String[]; budgets = String[]
    for shard_id in sort!(unique(Int.(collect(expected_shard_ids))))
        prefix = "$(stage_prefix)_shard_$(lpad(shard_id, 3, '0'))"
        stream_path = joinpath(output_directory, prefix * ".jsonl")
        summary_path = joinpath(output_directory, prefix * ".summary.json")
        isfile(stream_path) && isfile(summary_path) || throw(ArgumentError(
            "missing completed $stage_prefix shard $shard_id"))
        summary = _stage3_plain_v1(JSON3.read(read(summary_path, String),
            Dict{String,Any}))
        String(summary["queue_sha256"]) == queue_sha || throw(ArgumentError(
            "$stage_prefix shard queue hash mismatch"))
        String(summary["grammar_hash"]) == grammar.grammar_hash || throw(
            ArgumentError("$stage_prefix shard grammar hash mismatch"))
        String(summary["stage_prefix"]) == stage_prefix || throw(ArgumentError(
            "$stage_prefix shard stage prefix mismatch"))
        String(summary["execution_mode"]) == expected_execution_mode || throw(
            ArgumentError("$stage_prefix shard execution mode mismatch"))
        String(summary["stream_sha256"]) == _s70_file_sha256(stream_path) || throw(
            ArgumentError("$stage_prefix shard stream hash mismatch"))
        append!(all_rows, _v84_read_valid_json_lines(stream_path))
        push!(shard_hashes, String(summary["shard_result_hash"]))
        push!(budgets, canonical_hash(summary["poincare_budget"]))
    end
    isempty(budgets) || length(unique(budgets)) == 1 || throw(ArgumentError(
        "$stage_prefix shards used different execution budgets"))
    sort!(all_rows; by = row -> Int(row["queue_index"]))
    Int.(getindex.(all_rows, "queue_index")) == collect(1:length(queue)) || throw(
        ArgumentError("$stage_prefix shards do not cover the complete queue"))
    for (row, queued) in zip(all_rows, queue)
        String(row["candidate_binding_hash"]) == String(
            queued["candidate_binding_hash"]) || throw(ArgumentError(
            "$stage_prefix result and queue candidate binding differ"))
        String(get(row, "analytic_record_hash", "")) == String(
            queued["analytic_record_hash"]) || throw(ArgumentError(
            "$stage_prefix result and analytic evidence differ"))
        String(get(row, "execution_mode", "")) == expected_execution_mode || throw(
            ArgumentError("$stage_prefix row execution mode mismatch"))
        if haskey(queued, "biot_savart_record_hash")
            String(get(row, "biot_savart_record_hash", "")) == String(
                queued["biot_savart_record_hash"]) || throw(ArgumentError(
                "$stage_prefix result and Biot-Savart evidence differ"))
        end
    end
    return (queue = queue, queue_sha = queue_sha, rows = all_rows,
        shard_hashes = sort!(shard_hashes), budgets = budgets)
end

"Merge the bounded Biot-Savart queue and emit a separately bounded Poincare queue."
function merge_v84_biot_savart_shards_v1(
        grammar::CandidateRealizationGrammarV2, queue_path::AbstractString;
        output_directory::AbstractString, expected_shard_ids,
        max_poincare_candidates::Integer = 20)
    max_poincare_candidates > 0 || throw(ArgumentError(
        "max_poincare_candidates must be positive"))
    collected = _v84_collect_physical_stage_shards_v1(grammar, queue_path;
        output_directory = output_directory, expected_shard_ids = expected_shard_ids,
        stage_prefix = "v84_biot_savart",
        expected_execution_mode = "biot_savart_only")
    rows = collected.rows; source_queue = collected.queue
    merged_path = joinpath(output_directory, "v84_biot_savart_merged.jsonl")
    _v84_write_jsonl_atomic(merged_path, rows)
    eligible = [row for row in rows if get(row,
        "fast_biot_savart_gate_status", "") == "pass"]
    unique_rows = Dict{String,Any}[]; seen = Set{String}()
    for row in eligible
        key = "$(row["route"])|$(row["physical_signature"])"
        key in seen && continue
        push!(seen, key); push!(unique_rows, row)
    end
    selected = unique_rows[1:min(length(unique_rows), max_poincare_candidates)]
    poincare_queue = Dict{String,Any}[]
    for (queue_index, row) in enumerate(selected)
        source = deepcopy(source_queue[Int(row["queue_index"])])
        source["queue_stage"] = "poincare"
        source["biot_savart_queue_index"] = source["queue_index"]
        source["queue_index"] = queue_index
        source["biot_savart_record_hash"] = row["record_hash"]
        source["expected_screen_evidence_hash"] = row["screen_evidence_hash"]
        source["selection_policy"] =
            "biot_pass_unique_route_physical_signature_then_queue_order_v1"
        delete!(source, "record_hash")
        source["record_hash"] = _v84_record_hash(source)
        push!(poincare_queue, source)
    end
    poincare_queue_path = joinpath(output_directory, "v84_poincare_queue.jsonl")
    _v84_write_jsonl_atomic(poincare_queue_path, poincare_queue)
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0", "status" => "complete",
        "stage" => "fast_biot_savart_merge", "grammar_hash" => grammar.grammar_hash,
        "structure_hash" => grammar.structure_hash,
        "candidate_count" => length(rows), "source_queue_sha256" => collected.queue_sha,
        "fast_biot_savart_pass_count" => length(eligible),
        "fast_biot_savart_fail_count" => count(row -> get(row,
            "fast_biot_savart_gate_status", "") == "fail", rows),
        "uncaught_exception_count" => count(row -> get(row,
            "fast_biot_savart_gate_status", "") == "exception", rows),
        "poincare_eligible_unique_route_physical_count" => length(unique_rows),
        "poincare_duplicate_dropped_count" => length(eligible) - length(unique_rows),
        "poincare_duplicate_rate" => isempty(eligible) ? 0.0 :
            (length(eligible) - length(unique_rows)) / length(eligible),
        "poincare_queue_limit" => Int(max_poincare_candidates),
        "poincare_queue_count" => length(poincare_queue),
        "poincare_dropped_by_limit_count" => length(unique_rows) -
            length(poincare_queue),
        "merged_stream_sha256" => _s70_file_sha256(merged_path),
        "poincare_queue_sha256" => _s70_file_sha256(poincare_queue_path),
        "source_shard_hashes" => collected.shard_hashes,
        "claim_boundary" => V84_SHARDED_FUNNEL_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    _stage3_atomic_json_v1(joinpath(output_directory,
        "v84_biot_savart_merged.summary.json"), artifact)
    return artifact
end

"Merge only the explicitly admitted Poincare queue."
function merge_v84_poincare_shards_v1(
        grammar::CandidateRealizationGrammarV2, queue_path::AbstractString;
        output_directory::AbstractString, expected_shard_ids)
    collected = _v84_collect_physical_stage_shards_v1(grammar, queue_path;
        output_directory = output_directory, expected_shard_ids = expected_shard_ids,
        stage_prefix = "v84_poincare",
        expected_execution_mode = "biot_savart_then_poincare")
    rows = collected.rows
    merged_path = joinpath(output_directory, "v84_poincare_merged.jsonl")
    _v84_write_jsonl_atomic(merged_path, rows)
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0", "status" => "complete",
        "stage" => "poincare_merge", "grammar_hash" => grammar.grammar_hash,
        "structure_hash" => grammar.structure_hash,
        "candidate_count" => length(rows), "queue_sha256" => collected.queue_sha,
        "poincare_gate_pass_count" => count(row -> get(row,
            "poincare_gate_status", "") == "pass", rows),
        "poincare_gate_fail_count" => count(row -> get(row,
            "poincare_gate_status", "") == "fail", rows),
        "poincare_gate_unknown_count" => count(row -> get(row,
            "poincare_gate_status", "") in ("unknown", "unsupported"), rows),
        "uncaught_exception_count" => count(row -> get(row,
            "fast_biot_savart_gate_status", "") == "exception", rows),
        "merged_stream_sha256" => _s70_file_sha256(merged_path),
        "source_shard_hashes" => collected.shard_hashes,
        "evidence_firewall" => Dict{String,Any}(
            "retroactive_analytic_credit" => false,
            "retroactive_biot_savart_credit" => false,
            "fast_biot_savart_admission_requires_analytic_pareto" => true,
            "poincare_admission_requires_fast_biot_savart_pass" => true),
        "claim_boundary" => V84_SHARDED_FUNNEL_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    _stage3_atomic_json_v1(joinpath(output_directory,
        "v84_poincare_merged.summary.json"), artifact)
    return artifact
end

"Merge physical shards, verify queue coverage, and preserve per-level dispositions."
function merge_v84_physical_fidelity_shards_v1(
        grammar::CandidateRealizationGrammarV2, queue_path::AbstractString;
        output_directory::AbstractString, expected_shard_ids)
    queue = _v84_read_valid_json_lines(queue_path); queue_sha = _s70_file_sha256(queue_path)
    all_rows = Dict{String,Any}[]; shard_hashes = String[]; budgets = String[]
    for shard_id in sort!(unique(Int.(collect(expected_shard_ids))))
        prefix = "v84_physical_shard_$(lpad(shard_id, 3, '0'))"
        stream_path = joinpath(output_directory, prefix * ".jsonl")
        summary_path = joinpath(output_directory, prefix * ".summary.json")
        isfile(stream_path) && isfile(summary_path) || throw(ArgumentError(
            "missing completed v84 physical shard $shard_id"))
        summary = _stage3_plain_v1(JSON3.read(read(summary_path, String),
            Dict{String,Any}))
        String(summary["queue_sha256"]) == queue_sha ||
            throw(ArgumentError("physical shard queue hash mismatch"))
        String(summary["grammar_hash"]) == grammar.grammar_hash ||
            throw(ArgumentError("physical shard grammar hash mismatch"))
        String(summary["stream_sha256"]) == _s70_file_sha256(stream_path) ||
            throw(ArgumentError("physical shard stream hash mismatch"))
        append!(all_rows, _v84_read_valid_json_lines(stream_path))
        push!(shard_hashes, String(summary["shard_result_hash"]))
        push!(budgets, canonical_hash(summary["poincare_budget"]))
    end
    length(unique(budgets)) == 1 || throw(ArgumentError(
        "physical shards used different Poincare budgets"))
    sort!(all_rows; by = row -> Int(row["queue_index"]))
    Int.(getindex.(all_rows, "queue_index")) == collect(1:length(queue)) ||
        throw(ArgumentError("physical shards do not cover the complete Pareto queue"))
    for (row, queued) in zip(all_rows, queue)
        String(row["candidate_binding_hash"]) == String(
            queued["candidate_binding_hash"]) || throw(ArgumentError(
            "physical result and queue candidate binding differ"))
        String(get(row, "analytic_record_hash", "")) == String(
            queued["analytic_record_hash"]) || throw(ArgumentError(
            "physical result and analytic evidence differ"))
    end
    merged_path = joinpath(output_directory, "v84_physical_fidelity_merged.jsonl")
    _v84_write_jsonl_atomic(merged_path, all_rows)
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0", "status" => "complete",
        "stage" => "physical_fidelity_merge", "grammar_hash" => grammar.grammar_hash,
        "structure_hash" => grammar.structure_hash, "queue_sha256" => queue_sha,
        "candidate_count" => length(all_rows),
        "fast_biot_savart_pass_count" => count(row -> get(row,
            "fast_biot_savart_gate_status", "") == "pass", all_rows),
        "fast_biot_savart_fail_count" => count(row -> get(row,
            "fast_biot_savart_gate_status", "") == "fail", all_rows),
        "poincare_admitted_count" => count(row -> Bool(get(row,
            "poincare_admitted", false)), all_rows),
        "poincare_gate_pass_count" => count(row -> get(row,
            "poincare_gate_status", "") == "pass", all_rows),
        "poincare_gate_fail_count" => count(row -> get(row,
            "poincare_gate_status", "") == "fail", all_rows),
        "poincare_gate_unknown_count" => count(row -> get(row,
            "poincare_gate_status", "") == "unknown", all_rows),
        "uncaught_exception_count" => count(row -> get(row,
            "fast_biot_savart_gate_status", "") == "exception", all_rows),
        "merged_stream_sha256" => _s70_file_sha256(merged_path),
        "source_shard_hashes" => sort!(shard_hashes),
        "evidence_firewall" => Dict{String,Any}(
            "retroactive_analytic_credit" => false,
            "fast_biot_savart_admission_requires_analytic_pareto" => true,
            "poincare_admission_requires_fast_biot_savart_pass" => true),
        "claim_boundary" => V84_SHARDED_FUNNEL_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    _stage3_atomic_json_v1(joinpath(output_directory,
        "v84_physical_fidelity_merged.summary.json"), artifact)
    return artifact
end
