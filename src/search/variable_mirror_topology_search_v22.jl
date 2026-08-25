const _V22_LAYOUTS = (
    "split_ioffe_saddle_pair",
    "continuous_baseball_seam_pair",
    "yin_yang_end_anchor_pair",
)

const _V22_CLAIM_BOUNDARY =
    "V22 searches explicit closed-current-path mirror layouts and finite-build geometry genes under the same v20 plasma, mission, shield, maintenance, conductor-field, current-density, and support envelopes. Preview and full geometry calculations may reject a realization but cannot grant horizontal-gate, C1, anisotropic-equilibrium, stability, end-loss, medium-fidelity, novelty, superiority, or reactor credit. Passing geometry would authorize only the next independent admission task. Failure rejects only the sampled layout realization and bounded search grammar, not magnetic mirrors as a family."

struct VariableMirrorTopologyContextV22
    v20_context::RecoverableCrossTopologyContextV20
    frontier_records::Vector{Dict{String,Any}}
    parent_genomes::Vector{Genome}
    input_candidate_sha256::String
    frontier_hash::String
end

function build_variable_mirror_topology_context_v22(
        v20_context::RecoverableCrossTopologyContextV20,
        records::Vector{<:AbstractDict}; input_candidate_sha256::AbstractString)
    frontier = Dict{String,Any}[Dict{String,Any}(record) for record in records
        if String(record["family"]) == "magnetic_mirror" &&
            Int(record["gate_pass_count"]) == 3]
    sort!(frontier; by = record -> Int(record["candidate_index"]))
    length(frontier) == 362 || throw(ArgumentError(
        "v22 expects the sealed 362-record v20 mirror frontier"))
    parents = Genome[]
    for record in frontier
        reconstructed = evaluate_cross_topology_candidate_v20(v20_context,
            Int(record["candidate_index"]))
        reconstructed.prescreen.compiled.graph_hash == record["graph_hash"] ||
            throw(ArgumentError("v22 parent graph reconstruction drifted"))
        reconstructed.prescreen.compiled.genome.physics_hash ==
            record["physics_hash"] || throw(ArgumentError(
                "v22 parent physics reconstruction drifted"))
        push!(parents, reconstructed.prescreen.compiled.genome)
    end
    frontier_hash = canonical_hash([Dict{String,Any}(
        "candidate_index" => Int(record["candidate_index"]),
        "graph_hash" => String(record["graph_hash"]),
        "physics_hash" => String(record["physics_hash"]),
        "module_ids" => String.(record["module_ids"]),
    ) for record in frontier])
    return VariableMirrorTopologyContextV22(v20_context, frontier, parents,
        String(input_candidate_sha256), frontier_hash)
end

function _v22_gene_spec(global_index::Int, frontier_count::Int)
    total = frontier_count * length(_V22_LAYOUTS)
    1 <= global_index <= total || throw(BoundsError(1:total, global_index))
    parent_position = mod1(global_index, frontier_count)
    layout_position = cld(global_index, frontier_count)
    values = _v20_unit_vector(global_index, 5; skip = 8192)
    cell_count = clamp(2 + floor(Int, 5.0 * values[1]), 2, 6)
    return parent_position, String(_V22_LAYOUTS[layout_position]),
        MirrorCoilTopologyBuildSpec(
            layout = _V22_LAYOUTS[layout_position],
            cell_count = cell_count,
            end_high_fraction = 0.65 + 0.40 * values[2],
            central_radius_scale = 0.85 + 0.50 * values[3],
            end_radius_scale = 0.85 + 0.50 * values[4],
            axis_field_share = 0.45 + 0.50 * values[5]), values
end

function _v22_layout_violation_ratios(summary::AbstractDict)
    inputs = summary["inputs"]
    axis = summary["axis_system"]["combined_refined"]
    finite = summary["finite_build"]
    field_lines = summary["field_line_audit"]
    minimum_b = summary["minimum_b_system"]
    target_field = Float64(inputs["central_field_T"])
    target_ratio = Float64(inputs["target_mirror_ratio"])
    clearance = Float64(finite["minimum_declared_clearance_margin_m"])
    reached_ends = field_lines["all_seeds_reached_both_open_ends"] === true
    finite_ratio(value) = isfinite(Float64(value)) ?
        min(abs(Float64(value)), 1.0e99) : 1.0e99
    return Dict{String,Float64}(
        "axis_field_and_mirror_ratio" => maximum((
            finite_ratio(axis["center_field_T"] / target_field - 1.0) / 0.03,
            finite_ratio(axis["mirror_ratio"] / target_ratio - 1.0) / 0.05,
            finite_ratio(axis["rms_relative_error"]) / 0.10,
            finite_ratio(axis["maximum_on_axis_transverse_fraction"]) / 0.01)),
        "transverse_minimum_b_well" => finite_ratio(0.002 / max(Float64(
            minimum_b["minimum_well_fraction"]), 1.0e-12)),
        "open_field_line_integrity" => reached_ends ? finite_ratio(
            field_lines["maximum_normalized_flux_tube_radius"] / 0.95) : 10.0,
        "finite_build_peak_field" => finite_ratio(
            finite["refined_peak_field"]["peak_field_T"] /
            inputs["peak_conductor_field_limit_T"]),
        "winding_current_density" => finite_ratio(
            finite["maximum_current_density_A_m2"] /
            inputs["engineering_current_density_limit_A_m2"]),
        "plasma_shield_maintenance_and_coil_clearance" =>
            isfinite(clearance) && clearance >= -1.0e-12 ? 1.0 :
                finite_ratio(1.0 + abs(clearance)),
        "minimum_bend_radius_reservation" => finite_ratio(0.35 / max(Float64(
            finite["reserved_minimum_bend_radius_m"]), 1.0e-12)),
        "membrane_support_stress_proxy" => finite_ratio(
            finite["membrane_support_stress_proxy_Pa"] /
            inputs["support_stress_limit_Pa"]),
        "biot_savart_resolution_audit" => finite_ratio(
            finite["peak_field_resolution_change_fraction"] / 0.15),
    )
end

function _v22_nonfinite_paths(value, prefix::String = "root")
    paths = String[]
    if value isa Real && !(value isa Bool)
        isfinite(Float64(value)) || push!(paths, prefix)
    elseif value isa AbstractDict
        for key in sort!(String.(collect(keys(value))))
            append!(paths, _v22_nonfinite_paths(value[key], "$prefix.$key"))
        end
    elseif value isa AbstractVector || value isa Tuple
        for (index, item) in enumerate(value)
            append!(paths, _v22_nonfinite_paths(item, "$prefix[$index]"))
        end
    end
    return paths
end

function _v22_json_safe(value)
    if value isa Real && !(value isa Bool)
        return isfinite(Float64(value)) ? value : nothing
    elseif value isa AbstractDict
        return Dict{String,Any}(String(key) => _v22_json_safe(item)
            for (key, item) in value)
    elseif value isa AbstractVector || value isa Tuple
        return Any[_v22_json_safe(item) for item in value]
    end
    return value
end

_v22_safe_metric(value) = value isa Real && isfinite(Float64(value)) ?
    Float64(value) : nothing

function _v22_compact_geometry(summary::AbstractDict)
    gates = Dict{String,Bool}(String(key) => Bool(value)
        for (key, value) in summary["gates"])
    nonfinite_paths = _v22_nonfinite_paths(summary)
    gates["numerical_finiteness"] = isempty(nonfinite_paths)
    failed = sort!([key for (key, value) in gates if !value])
    ratios = _v22_layout_violation_ratios(summary)
    ratios["numerical_finiteness"] = isempty(nonfinite_paths) ? 1.0 : 1.0e99
    violations = [max(1.0, value) for value in values(ratios)]
    axis = summary["axis_system"]["combined_refined"]
    finite = summary["finite_build"]
    return Dict{String,Any}(
        "geometry_result_hash" => canonical_hash(_v22_json_safe(summary)),
        "all_geometry_gates_passed" =>
            summary["all_geometry_gates_passed"] === true &&
                isempty(nonfinite_paths),
        "rejection_credit" => summary["all_geometry_gates_passed"] !== true ||
            !isempty(nonfinite_paths),
        "promotion_credit" => false,
        "numerical_failure_count" => length(nonfinite_paths),
        "nonfinite_paths" => nonfinite_paths,
        "failed_gate_count" => length(failed),
        "failed_gates" => failed,
        "gates" => gates,
        "normalized_violation_ratios" => ratios,
        "worst_normalized_violation" => maximum(violations),
        "sum_log_normalized_violation" => sum(log, violations),
        "key_metrics" => Dict{String,Any}(
            "center_field_T" => _v22_safe_metric(axis["center_field_T"]),
            "achieved_mirror_ratio" => _v22_safe_metric(axis["mirror_ratio"]),
            "axis_rms_relative_error" =>
                _v22_safe_metric(axis["rms_relative_error"]),
            "maximum_on_axis_transverse_fraction" =>
                _v22_safe_metric(axis["maximum_on_axis_transverse_fraction"]),
            "minimum_well_fraction" =>
                _v22_safe_metric(summary["minimum_b_system"][
                    "minimum_well_fraction"]),
            "maximum_normalized_flux_tube_radius" =>
                _v22_safe_metric(summary["field_line_audit"][
                    "maximum_normalized_flux_tube_radius"]),
            "refined_peak_field_T" =>
                _v22_safe_metric(finite["refined_peak_field"]["peak_field_T"]),
            "membrane_support_stress_proxy_Pa" =>
                _v22_safe_metric(finite["membrane_support_stress_proxy_Pa"]),
            "minimum_clearance_margin_m" =>
                _v22_safe_metric(finite["minimum_declared_clearance_margin_m"]),
        ),
    )
end

function evaluate_variable_mirror_topology_candidate_v22(
        context::VariableMirrorTopologyContextV22, global_index::Integer;
        full_budget::Bool = false)
    parent_position, layout, spec, values = _v22_gene_spec(Int(global_index),
        length(context.frontier_records))
    parent_record = context.frontier_records[parent_position]
    parent = context.parent_genomes[parent_position]
    child = build_mirror_coil_topology_genome(parent, spec)
    evaluator = full_budget ? MirrorLayoutVacuumGeometryV1(layout) :
        MirrorLayoutVacuumGeometryV1(layout; random_starts = 16,
            coarse_segments = 32, refined_segments = 64,
            coarse_pack_grid = 3, refined_pack_grid = 5)
    geometry = _mlv_geometry_summary(evaluator, child)
    compact = _v22_compact_geometry(geometry)
    module_ids = String.(parent_record["module_ids"])
    descriptor = join((layout, module_ids[1], module_ids[3], module_ids[4]), "|")
    return Dict{String,Any}(
        "global_index" => Int(global_index),
        "parent_position" => parent_position,
        "parent_candidate_index" => Int(parent_record["candidate_index"]),
        "parent_graph_hash" => String(parent_record["graph_hash"]),
        "parent_physics_hash" => String(parent_record["physics_hash"]),
        "parent_module_ids" => module_ids,
        "layout" => layout,
        "descriptor" => descriptor,
        "genes" => Dict{String,Any}(
            "cell_count" => spec.cell_count,
            "end_high_fraction" => spec.end_high_fraction,
            "central_radius_scale" => spec.central_radius_scale,
            "end_radius_scale" => spec.end_radius_scale,
            "axis_field_share" => spec.axis_field_share,
            "halton_coordinates" => values,
        ),
        "child_design_id" => child.design_id,
        "child_physics_hash" => child.physics_hash,
        "evaluation_budget" => full_budget ? "full_default_v1" :
            "preview_16_starts_32_64_segments_pack_3_5",
        "geometry" => compact,
        "claim_boundary" => _V22_CLAIM_BOUNDARY,
    )
end

function recoverable_variable_mirror_topology_spec_v22(
        context::VariableMirrorTopologyContextV22;
        run_id::AbstractString = "variable_mirror_topology_preview_v22",
        shard_size::Integer = 6, source_sha256::AbstractString)
    total = length(context.frontier_records) * length(_V22_LAYOUTS)
    return RecoverableRunSpecV19(String(run_id),
        "variable_mirror_topology_preview_kernel", "22.0.0", total,
        Int(shard_size); max_retries = 2,
        max_retained_per_shard = Int(shard_size),
        kernel_config = Dict{String,Any}(
            "input_candidate_sha256" => context.input_candidate_sha256,
            "frontier_hash" => context.frontier_hash,
            "frontier_count" => length(context.frontier_records),
            "layouts" => collect(_V22_LAYOUTS),
            "gene_sequence" => "halton_5d_skip_8192",
            "preview_budget" => "16_starts_32_64_segments_pack_3_5",
            "retain_all" => true,
            "source_sha256" => String(source_sha256),
            "credit" => "rejection_only",
        ))
end

function recoverable_variable_mirror_topology_kernel_v22(
        context::VariableMirrorTopologyContextV22)
    return function(global_index, config)
        record = evaluate_variable_mirror_topology_candidate_v22(context,
            global_index; full_budget = false)
        return RecoverableKernelOutcomeV19(record, true)
    end
end

function _v22_rank(record::AbstractDict)
    geometry = record["geometry"]
    return (geometry["all_geometry_gates_passed"] === true ? 0 : 1,
        Int(geometry["failed_gate_count"]),
        Float64(geometry["sum_log_normalized_violation"]),
        Float64(geometry["worst_normalized_violation"]),
        Int(record["global_index"]))
end

function variable_mirror_qd_archive_v22(records::Vector{<:AbstractDict})
    cells = Dict{String,Dict{String,Any}}()
    for record in records
        key = String(record["descriptor"])
        item = Dict{String,Any}(record)
        if !haskey(cells, key) || _v22_rank(item) < _v22_rank(cells[key])
            cells[key] = item
        end
    end
    return sort!(collect(values(cells)); by = item -> String(item["descriptor"]))
end

function select_balanced_full_reviews_v22(records::Vector{<:AbstractDict};
        per_layout::Integer = 6)
    per_layout >= 1 || throw(ArgumentError("per_layout must be positive"))
    selected = Dict{String,Any}[]
    for layout in _V22_LAYOUTS
        candidates = Dict{String,Any}[Dict{String,Any}(record)
            for record in records if String(record["layout"]) == layout]
        layout_selected = Int[index for index in eachindex(candidates)
            if candidates[index]["geometry"]["all_geometry_gates_passed"] === true]
        covered = Set{String}()
        for index in layout_selected
            union!(covered, String.(candidates[index]["parent_module_ids"]))
        end
        remaining = [index for index in eachindex(candidates)
            if index ∉ Set(layout_selected)]
        target_count = max(per_layout, length(layout_selected))
        while !isempty(remaining) && length(layout_selected) < target_count
            rank = function(index)
                item = candidates[index]
                modules = Set(String.(item["parent_module_ids"]))
                new_coverage = length(setdiff(modules, covered))
                return (-new_coverage, _v22_rank(item)...)
            end
            sort!(remaining; by = rank)
            chosen = popfirst!(remaining)
            push!(layout_selected, chosen)
            union!(covered, String.(candidates[chosen]["parent_module_ids"]))
        end
        append!(selected, candidates[layout_selected])
    end
    sort!(selected; by = item -> (findfirst(==(String(item["layout"])),
        _V22_LAYOUTS), _v22_rank(item)))
    return selected
end
