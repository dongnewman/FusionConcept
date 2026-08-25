"""
Configuration for the deliberately cheap geometry feedback stage between the
common five-gate screen and the finite-coil admission calculation.

The preview is a ranking aid, not a lower-fidelity substitute for the full
finite-build calculation.  In particular, its winding-pack field is not
resolution qualified.
"""
struct MirrorGeometryFeedbackConfig
    random_starts::Int
    seed::Int
    segment_count::Int
    pack_grid::Int

    function MirrorGeometryFeedbackConfig(; random_starts::Integer = 32,
            seed::Integer = 20260811, segment_count::Integer = 64,
            pack_grid::Integer = 5)
        random_starts >= 16 || throw(ArgumentError(
            "random_starts must be at least 16"))
        segment_count >= 24 || throw(ArgumentError(
            "segment_count must be at least 24"))
        pack_grid >= 3 && isodd(pack_grid) || throw(ArgumentError(
            "pack_grid must be an odd integer of at least 3"))
        return new(Int(random_starts), Int(seed), Int(segment_count),
            Int(pack_grid))
    end
end

const _MIRROR_GEOMETRY_FEEDBACK_CLAIM_BOUNDARY =
    "Search-stage preview under the circular-axis-coil plus three-cell quadrupolar-cage grammar. It uses fewer random starts, a coarse segmented Biot-Savart field, and an unrefined sparse winding pack only to rank candidates for the full finite-coil evaluator. Preview passes and relative ranks are not geometry evidence. Inapplicability identifies a representation or promotion-interface gap, not a physical failure. Full-evaluator failure rejects only the tested realization under its declared grammar and budget, not the magnetic-mirror family."

function _mirror_feedback_inputs(genome::Genome)
    core = only(filter(region -> region.kind == "mirror_central_cell",
        genome.plasma_regions))
    central_field_T = _mirror_reduced_parameter(core, "central_field", "T")
    mirror_ratio = _mirror_reduced_parameter(core, "mirror_ratio_gene", "1")
    cell_length_m = _mirror_reduced_parameter(core, "cell_length", "m")
    plasma_radius_m = _mirror_reduced_parameter(core, "plasma_radius", "m")
    contract = default_common_comparison_contract()
    pack_m = _screen_target(genome, "screen_coil_pack_thickness", 0.45, "m")
    support_m = _screen_target(genome, "screen_support_thickness", 0.7, "m")
    return Dict{String,Any}(
        "central_field_T" => central_field_T,
        "mirror_ratio" => mirror_ratio,
        "cell_length_m" => cell_length_m,
        "half_length_m" => 0.5 * cell_length_m,
        "plasma_radius_m" => plasma_radius_m,
        "shield_m" => contract.shield_thickness_m,
        "maintenance_m" => contract.maintenance_gap_m,
        "pack_m" => pack_m,
        "support_m" => support_m,
        "current_density_limit_A_m2" =>
            contract.engineering_current_density_limit_A_mm2 * 1.0e6,
        "peak_field_limit_T" => contract.peak_conductor_field_limit_T,
        "support_stress_limit_Pa" => contract.support_stress_limit_Pa,
    )
end

function _mirror_feedback_inapplicable(genome::Genome, reason::String,
        config::MirrorGeometryFeedbackConfig)
    return Dict{String,Any}(
        "design_id" => genome.design_id,
        "physics_hash" => genome.physics_hash,
        "status" => "inapplicable",
        "reason" => reason,
        "configuration" => Dict(
            "random_starts" => config.random_starts,
            "seed" => config.seed,
            "segment_count" => config.segment_count,
            "pack_grid" => config.pack_grid,
        ),
        "claim_boundary" => _MIRROR_GEOMETRY_FEEDBACK_CLAIM_BOUNDARY,
    )
end

"""
Run a coarse, candidate-specific geometry preview for promotion ranking.

The full `MirrorFiniteCoilGeometryV1` applicability contract is used before any
field calculation, so an archive survivor without an explicit minimum-B source
is recorded as an interface gap rather than silently receiving a cage coil.
"""
function mirror_geometry_feedback_proxy(genome::Genome;
        config::MirrorGeometryFeedbackConfig = MirrorGeometryFeedbackConfig())
    applicability_evaluator = MirrorFiniteCoilGeometryV1(
        random_starts = config.random_starts,
        seed = config.seed,
        coarse_segments = config.segment_count,
        refined_segments = 2 * config.segment_count)
    applicable, reason = evaluator_applicability(applicability_evaluator, genome)
    applicable || return _mirror_feedback_inapplicable(genome, reason, config)

    inputs = _mirror_feedback_inputs(genome)
    half_length_m = inputs["half_length_m"]
    central_field_T = inputs["central_field_T"]
    mirror_ratio = inputs["mirror_ratio"]
    plasma_radius_m = inputs["plasma_radius_m"]
    pack_m = inputs["pack_m"]
    current_density_limit_A_m2 = inputs["current_density_limit_A_m2"]

    axis = _mf_axis_geometry_search(applicability_evaluator, central_field_T,
        mirror_ratio, half_length_m, plasma_radius_m, inputs["shield_m"],
        inputs["maintenance_m"], pack_m, pack_m,
        current_density_limit_A_m2)
    quadrupole = _mf_quadrupole_search(axis, half_length_m, central_field_T,
        mirror_ratio, plasma_radius_m, pack_m, current_density_limit_A_m2,
        config.segment_count)
    preview_peak = _mf_peak_winding_field(axis, quadrupole, half_length_m,
        pack_m, pack_m, config.pack_grid, config.segment_count)
    field_lines = _mf_field_line_audit(axis, quadrupole, half_length_m,
        central_field_T, mirror_ratio, plasma_radius_m, config.segment_count)

    center_error = abs(axis["center_field_T"] / central_field_T - 1.0)
    ratio_error = abs(axis["achieved_mirror_ratio"] / mirror_ratio - 1.0)
    maximum_axis_current_density = maximum(axis["currents_A"]) / pack_m^2
    maximum_quad_current_density = max(
        abs(quadrupole["central_bar_current_A"]),
        abs(quadrupole["end_bar_current_A"])) / pack_m^2
    maximum_current_density = max(maximum_axis_current_density,
        maximum_quad_current_density)
    magnetic_pressure_Pa = preview_peak["peak_field_T"]^2 /
        (2.0 * 4.0 * pi * 1.0e-7)
    support_stress_proxy_Pa = magnetic_pressure_Pa * maximum(axis["radii_m"]) /
        inputs["support_m"]

    ratios = Dict{String,Float64}(
        "axis_center_error_to_limit" => center_error / 0.02,
        "mirror_ratio_error_to_limit" => ratio_error / 0.02,
        "axis_rms_error_to_limit" => axis["axis_rms_relative_error"] / 0.08,
        "field_line_envelope_to_limit" =>
            field_lines["maximum_normalized_flux_tube_radius"] / 0.95,
        "preview_peak_field_to_limit" =>
            preview_peak["peak_field_T"] / inputs["peak_field_limit_T"],
        "current_density_to_limit" =>
            maximum_current_density / current_density_limit_A_m2,
        "preview_support_stress_to_limit" =>
            support_stress_proxy_Pa / inputs["support_stress_limit_Pa"],
    )
    violations = Dict(key => max(value - 1.0, 0.0) for (key, value) in ratios)
    minimum_b_violation = max((0.002 - quadrupole["minimum_well_fraction"]) /
        0.002, 0.0)
    violations["transverse_minimum_b_well"] = minimum_b_violation
    gates = Dict{String,Bool}(
        "axis_field_and_mirror_ratio_preview" => center_error <= 0.02 &&
            ratio_error <= 0.02 && axis["axis_rms_relative_error"] <= 0.08,
        "transverse_minimum_b_well_preview" => quadrupole["gate_passed"],
        "open_field_line_integrity_preview" => field_lines["passed"],
        "finite_build_peak_field_preview" =>
            preview_peak["peak_field_T"] <= inputs["peak_field_limit_T"],
        "winding_current_density_preview" =>
            maximum_current_density <= current_density_limit_A_m2,
        "membrane_support_stress_preview" =>
            support_stress_proxy_Pa <= inputs["support_stress_limit_Pa"],
    )

    return Dict{String,Any}(
        "design_id" => genome.design_id,
        "physics_hash" => genome.physics_hash,
        "status" => "rankable_preview",
        "applicability_reason" => reason,
        "configuration" => Dict(
            "random_starts" => config.random_starts,
            "seed" => config.seed,
            "segment_count" => config.segment_count,
            "pack_grid" => config.pack_grid,
        ),
        "inputs" => inputs,
        "axis" => Dict(
            "center_field_T" => axis["center_field_T"],
            "achieved_mirror_ratio" => axis["achieved_mirror_ratio"],
            "axis_rms_relative_error" => axis["axis_rms_relative_error"],
            "active_pair_count" => count(current -> current > 1.0e4,
                axis["currents_A"]),
        ),
        "quadrupole" => Dict(
            "central_bar_current_A" => quadrupole["central_bar_current_A"],
            "end_bar_current_A" => quadrupole["end_bar_current_A"],
            "minimum_well_fraction" => quadrupole["minimum_well_fraction"],
            "end_high_fraction" => quadrupole["end_high_fraction"],
        ),
        "preview_peak_field_T" => preview_peak["peak_field_T"],
        "preview_maximum_current_density_A_m2" => maximum_current_density,
        "preview_support_stress_proxy_Pa" => support_stress_proxy_Pa,
        "preview_maximum_normalized_flux_tube_radius" =>
            field_lines["maximum_normalized_flux_tube_radius"],
        "gates" => gates,
        "violation_ratios" => ratios,
        "positive_normalized_violations" => violations,
        "preview_failed_gate_count" => count(!, values(gates)),
        "claim_boundary" => _MIRROR_GEOMETRY_FEEDBACK_CLAIM_BOUNDARY,
    )
end

"""Deterministic lexicographic ranking key for rankable preview records."""
function mirror_geometry_feedback_rank_key(preview::AbstractDict)
    get(preview, "status", "") == "rankable_preview" || return
        (typemax(Int), Inf, Inf, Inf, String(get(preview, "physics_hash", "")))
    violations = Float64.(collect(values(
        preview["positive_normalized_violations"])))
    return (
        Int(preview["preview_failed_gate_count"]),
        maximum(violations),
        sum(violations),
        Float64(preview["preview_peak_field_T"]),
        String(preview["physics_hash"]),
    )
end
