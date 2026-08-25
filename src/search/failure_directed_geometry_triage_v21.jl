const _V21_REJECTION_ONLY_CLAIM_BOUNDARY =
    "V21 may run a candidate-specific finite-coil geometry calculation before the horizontal fidelity-0 gates only to obtain additional rejection evidence. A failed geometry gate rejects that realization under the declared coil grammar and common envelope. A pass grants no horizontal-gate, C1, anisotropic-equilibrium, stability, end-loss, engineering-closure, medium-fidelity, novelty, superiority, or reactor credit. Exact full-budget geometry survivors remain blocked until every independent admission requirement is satisfied."

"""Return the deterministic v20 failure census used to freeze v21 routing."""
function failure_directed_census_v21(records::Vector{<:AbstractDict})
    family_counts = Dict{String,Int}()
    family_gate3_counts = Dict{String,Int}()
    family_positive_counts = Dict{String,Int}()
    missing_requirement_counts = Dict{String,Int}()
    gate_pass_histogram = Dict{String,Int}()
    for record in records
        family = String(record["family"])
        family_counts[family] = get(family_counts, family, 0) + 1
        gate_count = Int(record["gate_pass_count"])
        gate_pass_histogram[string(gate_count)] =
            get(gate_pass_histogram, string(gate_count), 0) + 1
        if gate_count == 3
            family_gate3_counts[family] =
                get(family_gate3_counts, family, 0) + 1
        end
        if record["positive_net_power_closure"] === true
            family_positive_counts[family] =
                get(family_positive_counts, family, 0) + 1
        end
        for requirement in record["missing_proxy_requirements"]
            id = String(requirement)
            missing_requirement_counts[id] =
                get(missing_requirement_counts, id, 0) + 1
        end
    end
    return Dict{String,Any}(
        "candidate_count" => length(records),
        "family_counts" => family_counts,
        "family_gate3_counts" => family_gate3_counts,
        "family_positive_counts" => family_positive_counts,
        "missing_requirement_counts" => missing_requirement_counts,
        "gate_pass_histogram" => gate_pass_histogram,
    )
end

function _v21_explicit_minimum_b_source(genome::Genome)
    return any(source ->
        source.kind in ("minimum_b_coil", "minimum_b_anchor_coil") &&
        source.geometry_model in ("paired_finite_build_minimum_b_anchor_coils",
            "finite_build_quadrupole_anchor"), genome.field_sources)
end

function _v21_geometry_ratios(summary::AbstractDict)
    inputs = summary["inputs"]
    axis = summary["axis_system"]
    finite = summary["finite_build"]
    field_lines = summary["field_line_audit"]
    quadrupole = summary["quadrupole_system"]
    target_field = Float64(inputs["central_field_T"])
    target_ratio = Float64(inputs["target_mirror_ratio"])
    clearance = Float64(finite["minimum_declared_clearance_margin_m"])
    ratios = Dict{String,Float64}(
        "center_field_relative_error_over_limit" =>
            abs(Float64(axis["center_field_T"]) / target_field - 1.0) / 0.02,
        "mirror_ratio_relative_error_over_limit" =>
            abs(Float64(axis["achieved_mirror_ratio"]) / target_ratio - 1.0) / 0.02,
        "axis_rms_error_over_limit" =>
            Float64(axis["axis_rms_relative_error"]) / 0.08,
        "minimum_b_well_requirement_over_value" =>
            0.002 / max(Float64(quadrupole["minimum_well_fraction"]), 1.0e-12),
        "flux_tube_radius_over_limit" =>
            Float64(field_lines["maximum_normalized_flux_tube_radius"]) / 0.95,
        "peak_field_over_limit" =>
            Float64(finite["refined_peak_field"]["peak_field_T"]) /
                Float64(inputs["peak_conductor_field_limit_T"]),
        "current_density_over_limit" =>
            Float64(finite["maximum_current_density_A_m2"]) /
                Float64(inputs["engineering_current_density_limit_A_m2"]),
        "clearance_violation" => clearance >= -1.0e-12 ? 1.0 :
            1.0 + abs(clearance),
        "bend_radius_requirement_over_value" =>
            0.35 / max(Float64(finite["reserved_minimum_elbow_radius_m"]),
                1.0e-12),
        "support_stress_over_limit" =>
            Float64(finite["membrane_support_stress_proxy_Pa"]) /
                Float64(inputs["support_stress_limit_Pa"]),
        "resolution_change_over_limit" =>
            Float64(finite["peak_field_resolution_change_fraction"]) / 0.08,
    )
    return ratios
end

"""Run the existing finite-coil calculation out of order for rejection only."""
function mirror_geometry_rejection_only_v21(genome::Genome;
        evaluator::MirrorFiniteCoilGeometryV1 = MirrorFiniteCoilGeometryV1(),
        evaluation_budget::AbstractString = "full")
    genome.family == "magnetic_mirror" || throw(ArgumentError(
        "v21 mirror geometry rejection applies only to magnetic_mirror"))
    genome.topology.field_line_class == "open_mirror" || throw(ArgumentError(
        "v21 mirror geometry rejection requires open_mirror field lines"))
    _mirror_reduced_core(genome) === nothing && throw(ArgumentError(
        "v21 mirror geometry rejection requires one mirror_central_cell"))
    _v21_explicit_minimum_b_source(genome) || throw(ArgumentError(
        "v21 mirror geometry rejection requires an explicit finite-build minimum-B source"))
    geometry = _mf_geometry_summary(evaluator, genome)
    ratios = _v21_geometry_ratios(geometry)
    gates = Dict{String,Bool}(String(key) => Bool(value)
        for (key, value) in geometry["gates"])
    failed_gates = sort!([key for (key, value) in gates if !value])
    violation_values = [max(1.0, value) for value in values(ratios)]
    return Dict{String,Any}(
        "evaluation_budget" => String(evaluation_budget),
        "geometry_result_hash" => canonical_hash(geometry),
        "all_geometry_gates_passed" =>
            geometry["all_geometry_gates_passed"] === true,
        "rejection_credit" => geometry["all_geometry_gates_passed"] !== true,
        "promotion_credit" => false,
        "failed_gate_count" => length(failed_gates),
        "failed_gates" => failed_gates,
        "gates" => gates,
        "normalized_violation_ratios" => ratios,
        "worst_normalized_violation" => maximum(violation_values),
        "sum_log_normalized_violation" => sum(log, violation_values),
        "key_metrics" => Dict{String,Any}(
            "center_field_T" => geometry["axis_system"]["center_field_T"],
            "achieved_mirror_ratio" =>
                geometry["axis_system"]["achieved_mirror_ratio"],
            "axis_rms_relative_error" =>
                geometry["axis_system"]["axis_rms_relative_error"],
            "minimum_well_fraction" =>
                geometry["quadrupole_system"]["minimum_well_fraction"],
            "maximum_normalized_flux_tube_radius" =>
                geometry["field_line_audit"][
                    "maximum_normalized_flux_tube_radius"],
            "refined_peak_field_T" =>
                geometry["finite_build"]["refined_peak_field"]["peak_field_T"],
            "membrane_support_stress_proxy_Pa" =>
                geometry["finite_build"]["membrane_support_stress_proxy_Pa"],
        ),
        "geometry" => geometry,
        "claim_boundary" => _V21_REJECTION_ONLY_CLAIM_BOUNDARY,
    )
end

function select_diverse_geometry_reviews_v21(previews::Vector{<:AbstractDict},
        budget::Integer)
    budget >= 1 || throw(ArgumentError("v21 review budget must be positive"))
    remaining = collect(eachindex(previews))
    selected = Int[]
    covered = Set{String}()
    while !isempty(remaining) && length(selected) < budget
        rank = function(index)
            item = previews[index]
            modules = Set(String.(item["module_ids"]))
            new_coverage = length(setdiff(modules, covered))
            return (-new_coverage, Int(item["preview"]["failed_gate_count"]),
                Float64(item["preview"]["sum_log_normalized_violation"]),
                Int(item["candidate_index"]))
        end
        sort!(remaining; by = rank)
        chosen = popfirst!(remaining)
        push!(selected, chosen)
        union!(covered, String.(previews[chosen]["module_ids"]))
    end
    return selected, sort!(collect(covered))
end
