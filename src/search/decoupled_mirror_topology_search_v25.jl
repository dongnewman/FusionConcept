const _V25_MIRROR_LAYOUTS = _V22_LAYOUTS
const _V25_ALLOCATIONS_PER_LAYOUT = 2
const _V25_MIRROR_CLAIM_BOUNDARY =
    "V25 searches a bounded ten-gene decoupled mirror allocation grammar over the sealed v20 three-gate mirror frontier. Central and end axis currents, end-axis positions, minimum-B anchor current, anchor axial extent and phase, and central/end radii are independent genes. The coarse allocation precondition and finite-build vacuum geometry may reject but never grant anisotropic equilibrium, stability, end-loss, C1, medium-fidelity, novelty, superiority, or reactor credit. A strict geometry survivor authorizes only separate candidate-specific admission tasks. Failure rejects only this grammar and sample, not magnetic mirrors as a family."

struct DecoupledMirrorBuildSpecV25
    layout::String
    cell_count::Int
    anchor_axial_fraction::Float64
    central_radius_scale::Float64
    end_radius_scale::Float64
    axis_field_share::Float64
    central_axis_current_scale::Float64
    end_axis_current_scale::Float64
    end_axis_position_scale::Float64
    anchor_current_fraction::Float64
    anchor_phase_rad::Float64
end

struct DecoupledMirrorTopologyContextV25
    v22_context::VariableMirrorTopologyContextV22
    input_candidate_sha256::String
    frontier_hash::String
end

function build_decoupled_mirror_topology_context_v25(
        v20_context::RecoverableCrossTopologyContextV20,
        records::Vector{<:AbstractDict}; input_candidate_sha256::AbstractString)
    v22 = build_variable_mirror_topology_context_v22(v20_context, records;
        input_candidate_sha256 = input_candidate_sha256)
    return DecoupledMirrorTopologyContextV25(v22,
        String(input_candidate_sha256), v22.frontier_hash)
end

function _v25_mirror_gene_spec(global_index::Int, frontier_count::Int)
    allocation_count = length(_V25_MIRROR_LAYOUTS) *
        _V25_ALLOCATIONS_PER_LAYOUT
    total = frontier_count * allocation_count
    1 <= global_index <= total || throw(BoundsError(1:total, global_index))
    parent_position = mod1(global_index, frontier_count)
    allocation_position = cld(global_index, frontier_count)
    layout_position = mod1(allocation_position, length(_V25_MIRROR_LAYOUTS))
    replicate = cld(allocation_position, length(_V25_MIRROR_LAYOUTS))
    values = _v20_unit_vector(global_index, 10; skip = 16384)
    cell_count = clamp(2 + floor(Int, 5.0 * values[1]), 2, 6)
    raw_anchor_fraction = -0.25 + 0.50 * values[9]
    anchor_current_fraction = abs(raw_anchor_fraction) < 0.02 ?
        copysign(0.02, raw_anchor_fraction == 0.0 ? 1.0 : raw_anchor_fraction) :
        raw_anchor_fraction
    spec = DecoupledMirrorBuildSpecV25(
        String(_V25_MIRROR_LAYOUTS[layout_position]),
        cell_count,
        0.65 + 0.35 * values[2],
        0.85 + 0.50 * values[3],
        0.85 + 0.50 * values[4],
        0.50 + 0.45 * values[5],
        0.65 + 0.70 * values[6],
        0.65 + 0.80 * values[7],
        0.82 + 0.30 * values[8],
        anchor_current_fraction,
        0.50 * pi * values[10],
    )
    return parent_position, replicate, spec, values
end

function build_decoupled_mirror_topology_genome_v25(parent::Genome,
        spec::DecoupledMirrorBuildSpecV25)
    base = MirrorCoilTopologyBuildSpec(
        layout = spec.layout,
        cell_count = spec.cell_count,
        end_high_fraction = spec.anchor_axial_fraction,
        central_radius_scale = spec.central_radius_scale,
        end_radius_scale = spec.end_radius_scale,
        axis_field_share = spec.axis_field_share)
    child = build_mirror_coil_topology_genome(parent, base)
    raw = deepcopy(child.normalized)
    sources = filter(source -> source["kind"] == "minimum_b_coil" &&
        source["geometry_model"] == spec.layout, raw["field_sources"])
    length(sources) == 1 || error("v25 requires one layout minimum-B source")
    source = only(sources)
    source["parameters"]["anchor_axial_fraction"] =
        _gtv2_q(spec.anchor_axial_fraction, "1";
            basis = "v25 decoupled mirror topology gene")
    source["parameters"]["central_axis_current_scale"] =
        _gtv2_q(spec.central_axis_current_scale, "1";
            basis = "v25 decoupled mirror topology gene")
    source["parameters"]["end_axis_current_scale"] =
        _gtv2_q(spec.end_axis_current_scale, "1";
            basis = "v25 decoupled mirror topology gene")
    source["parameters"]["end_axis_position_scale"] =
        _gtv2_q(spec.end_axis_position_scale, "1";
            basis = "v25 decoupled mirror topology gene")
    source["parameters"]["anchor_current_fraction"] =
        _gtv2_q(spec.anchor_current_fraction, "1";
            basis = "signed fraction of generic winding current-density cap")
    source["parameters"]["anchor_phase"] =
        _gtv2_q(spec.anchor_phase_rad, "rad";
            basis = "v25 decoupled mirror topology gene")
    _push_unique!(raw["engineering"]["required_evaluators"], [
        "decoupled_axis_end_anchor_vacuum_geometry_v25",
        "candidate_specific_anisotropic_equilibrium",
        "candidate_specific_fokker_planck_end_loss"])
    provenance = raw["provenance"]
    notes = get!(provenance, "notes", Any[])
    push!(notes, "v25 independently varies central/end axis allocation and minimum-B anchor allocation")
    return _gtv2_finish(raw, parent,
        "decoupled_mirror_axis_end_anchor_$(spec.layout)_v25",
        String.(provenance["source_ids"]))
end

function _v25_precondition_score(precondition::AbstractDict)
    well_penalty = max(0.0, -Float64(precondition["minimum_well_fraction"])) /
        0.08
    clearance_penalty = max(0.0,
        -Float64(precondition["minimum_clearance_margin_m"]))
    transverse_penalty = Float64(
        precondition["maximum_on_axis_transverse_fraction"]) / 0.15
    return Float64(precondition["center_relative_error"]) / 0.75 +
        Float64(precondition["mirror_ratio_relative_error"]) / 1.00 +
        well_penalty + clearance_penalty + transverse_penalty
end

function _v25_compact_geometry(summary::AbstractDict)
    precondition = Dict{String,Any}(summary["precondition"])
    result = Dict{String,Any}(
        "precondition_passed" => precondition["passed"],
        "precondition_failed_gates" => precondition["failed_gates"],
        "precondition_score" => _v25_precondition_score(precondition),
        "precondition_key_metrics" => Dict{String,Any}(
            "center_field_T" => precondition["center_field_T"],
            "mirror_ratio" => precondition["mirror_ratio"],
            "center_relative_error" => precondition["center_relative_error"],
            "mirror_ratio_relative_error" =>
                precondition["mirror_ratio_relative_error"],
            "minimum_well_fraction" => precondition["minimum_well_fraction"],
            "maximum_on_axis_transverse_fraction" =>
                precondition["maximum_on_axis_transverse_fraction"],
            "minimum_clearance_margin_m" =>
                precondition["minimum_clearance_margin_m"],
        ),
        "finite_geometry_executed" => summary["finite_geometry_executed"],
        "finite_geometry" => nothing,
        "all_geometry_gates_passed" => false,
        "rejection_credit" => true,
        "promotion_credit" => false,
    )
    if summary["finite_geometry_executed"] === true
        finite = Dict{String,Any}(summary["finite_geometry"])
        compatibility = merge(Dict{String,Any}(finite),
            Dict{String,Any}("inputs" => summary["inputs"]))
        compact = _v22_compact_geometry(compatibility)
        result["finite_geometry"] = compact
        result["all_geometry_gates_passed"] =
            compact["all_geometry_gates_passed"]
        result["rejection_credit"] =
            compact["all_geometry_gates_passed"] !== true
    end
    return result
end

function evaluate_decoupled_mirror_topology_candidate_v25(
        context::DecoupledMirrorTopologyContextV25, global_index::Integer;
        full_budget::Bool = false)
    v22 = context.v22_context
    parent_position, replicate, spec, values = _v25_mirror_gene_spec(
        Int(global_index), length(v22.frontier_records))
    parent_record = v22.frontier_records[parent_position]
    parent = v22.parent_genomes[parent_position]
    child = build_decoupled_mirror_topology_genome_v25(parent, spec)
    evaluator = full_budget ? MirrorDecoupledVacuumGeometryV25(spec.layout;
        random_starts = 24, coarse_segments = 48, refined_segments = 96,
        coarse_pack_grid = 5, refined_pack_grid = 7) :
        MirrorDecoupledVacuumGeometryV25(spec.layout)
    summary = _mdv25_geometry_summary(evaluator, child;
        run_finite_geometry = full_budget)
    compact = _v25_compact_geometry(summary)
    module_ids = String.(parent_record["module_ids"])
    current_regime = spec.end_axis_current_scale >
        spec.central_axis_current_scale ? "end_axis_dominant" :
        "central_axis_dominant"
    anchor_sign = spec.anchor_current_fraction >= 0.0 ?
        "positive_anchor" : "negative_anchor"
    descriptor = join((spec.layout, current_regime, anchor_sign,
        module_ids[3], module_ids[4]), "|")
    return Dict{String,Any}(
        "global_index" => Int(global_index),
        "parent_position" => parent_position,
        "replicate" => replicate,
        "parent_candidate_index" => Int(parent_record["candidate_index"]),
        "parent_graph_hash" => String(parent_record["graph_hash"]),
        "parent_physics_hash" => String(parent_record["physics_hash"]),
        "parent_module_ids" => module_ids,
        "layout" => spec.layout,
        "descriptor" => descriptor,
        "allocation_regime" => current_regime,
        "anchor_sign" => anchor_sign,
        "genes" => Dict{String,Any}(
            "cell_count" => spec.cell_count,
            "anchor_axial_fraction" => spec.anchor_axial_fraction,
            "central_radius_scale" => spec.central_radius_scale,
            "end_radius_scale" => spec.end_radius_scale,
            "axis_field_share" => spec.axis_field_share,
            "central_axis_current_scale" => spec.central_axis_current_scale,
            "end_axis_current_scale" => spec.end_axis_current_scale,
            "end_axis_position_scale" => spec.end_axis_position_scale,
            "anchor_current_fraction" => spec.anchor_current_fraction,
            "anchor_phase_rad" => spec.anchor_phase_rad,
            "halton_coordinates" => values,
        ),
        "child_design_id" => child.design_id,
        "child_physics_hash" => child.physics_hash,
        "evaluation_budget" => full_budget ?
            "full_24_starts_48_96_segments_pack_5_7" :
            "preview_16_starts_24_48_segments_pack_3_5",
        "geometry" => compact,
        "anisotropic_equilibrium_authorized" => false,
        "fokker_planck_end_loss_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promotion_credit" => false,
        "claim_boundary" => _V25_MIRROR_CLAIM_BOUNDARY,
    )
end

function recoverable_decoupled_mirror_topology_spec_v25(
        context::DecoupledMirrorTopologyContextV25;
        run_id::AbstractString = "decoupled_mirror_topology_preview_v25",
        shard_size::Integer = 6, source_sha256::AbstractString,
        adapter_sha256::AbstractString)
    frontier_count = length(context.v22_context.frontier_records)
    total = frontier_count * length(_V25_MIRROR_LAYOUTS) *
        _V25_ALLOCATIONS_PER_LAYOUT
    return RecoverableRunSpecV19(String(run_id),
        "decoupled_mirror_topology_preview_kernel", "25.0.0", total,
        Int(shard_size); max_retries = 2,
        max_retained_per_shard = Int(shard_size),
        kernel_config = Dict{String,Any}(
            "input_candidate_sha256" => context.input_candidate_sha256,
            "frontier_hash" => context.frontier_hash,
            "frontier_count" => frontier_count,
            "layouts" => collect(_V25_MIRROR_LAYOUTS),
            "allocations_per_layout" => _V25_ALLOCATIONS_PER_LAYOUT,
            "gene_sequence" => "halton_10d_skip_16384",
            "preview_budget" => "16_starts_24_48_segments_pack_3_5",
            "source_sha256" => String(source_sha256),
            "adapter_sha256" => String(adapter_sha256),
            "retain_all" => true,
            "credit" => "rejection_or_next_task_authorization_only",
        ))
end

function recoverable_decoupled_mirror_topology_kernel_v25(
        context::DecoupledMirrorTopologyContextV25)
    return function(global_index, config)
        record = evaluate_decoupled_mirror_topology_candidate_v25(context,
            global_index; full_budget = false)
        return RecoverableKernelOutcomeV19(record, true)
    end
end

function _v25_mirror_rank(record::AbstractDict)
    geometry = record["geometry"]
    finite = geometry["finite_geometry"]
    finite_pass = geometry["all_geometry_gates_passed"] === true
    finite_executed = geometry["finite_geometry_executed"] === true
    failure_count = finite_executed ? Int(finite["failed_gate_count"]) : 100
    worst = finite_executed ? Float64(finite["worst_normalized_violation"]) :
        1.0e6
    precondition_pass = geometry["precondition_passed"] === true
    return (finite_pass ? 0 : 1, precondition_pass ? 0 : 1,
        finite_executed ? 0 : 1, failure_count, worst,
        Float64(geometry["precondition_score"]),
        Int(record["global_index"]))
end

function decoupled_mirror_qd_archive_v25(records::Vector{<:AbstractDict})
    cells = Dict{String,Dict{String,Any}}()
    for record in records
        key = String(record["descriptor"])
        item = Dict{String,Any}(record)
        if !haskey(cells, key) ||
                _v25_mirror_rank(item) < _v25_mirror_rank(cells[key])
            cells[key] = item
        end
    end
    return sort!(collect(values(cells));
        by = record -> String(record["descriptor"]))
end

function select_decoupled_mirror_full_reviews_v25(
        records::Vector{<:AbstractDict}; per_layout::Integer = 6)
    selected = Dict{String,Any}[]
    for layout in _V25_MIRROR_LAYOUTS
        eligible = Dict{String,Any}[Dict{String,Any}(record) for record in records
            if record["layout"] == layout &&
                record["geometry"]["precondition_passed"] === true]
        sort!(eligible; by = _v25_mirror_rank)
        chosen = Dict{String,Any}[]
        seen_module_signatures = Set{String}()
        for record in eligible
            signature = join(String.(record["parent_module_ids"]), "|")
            signature in seen_module_signatures && continue
            push!(chosen, record); push!(seen_module_signatures, signature)
            length(chosen) >= per_layout && break
        end
        if length(chosen) < per_layout
            chosen_indices = Set(Int(record["global_index"]) for record in chosen)
            for record in eligible
                Int(record["global_index"]) in chosen_indices && continue
                push!(chosen, record)
                length(chosen) >= per_layout && break
            end
        end
        append!(selected, chosen)
    end
    return selected
end
