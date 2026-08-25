"""
Candidate-specific PF/shape geometry for a common-envelope tokamak survivor.

`layout` is a topology choice, while the clearance and X-point parameters are
continuous acquisition genes.  The builder creates a new child genome; it never
relabels a generic parent as though its geometry had already existed.
"""
struct TokamakPFShapeBuildSpec
    layout::String
    radial_clearance_scale::Float64
    vertical_clearance_scale::Float64
    xpoint_radial_shift_fraction::Float64
    xpoint_vertical_scale::Float64
    tikhonov_gamma::Float64
    grid_size::Int

    function TokamakPFShapeBuildSpec(; layout::AbstractString = "symmetric_8",
            radial_clearance_scale::Real = 1.0,
            vertical_clearance_scale::Real = 1.0,
            xpoint_radial_shift_fraction::Real = 0.0,
            xpoint_vertical_scale::Real = 1.0,
            tikhonov_gamma::Real = 1.0e-12,
            grid_size::Integer = 65)
        String(layout) in ("symmetric_8", "symmetric_12") ||
            throw(ArgumentError("unsupported PF layout"))
        0.75 <= radial_clearance_scale <= 1.5 ||
            throw(ArgumentError("radial_clearance_scale must be 0.75-1.5"))
        0.75 <= vertical_clearance_scale <= 1.5 ||
            throw(ArgumentError("vertical_clearance_scale must be 0.75-1.5"))
        -0.25 <= xpoint_radial_shift_fraction <= 0.25 ||
            throw(ArgumentError("xpoint shift must be within +/-0.25 minor radii"))
        0.85 <= xpoint_vertical_scale <= 1.20 ||
            throw(ArgumentError("xpoint_vertical_scale must be 0.85-1.20"))
        1.0e-15 <= tikhonov_gamma <= 1.0e-6 ||
            throw(ArgumentError("tikhonov_gamma must be 1e-15 to 1e-6"))
        33 <= grid_size <= 129 && isodd(grid_size) ||
            throw(ArgumentError("grid_size must be odd and 33-129"))
        return new(String(layout), Float64(radial_clearance_scale),
            Float64(vertical_clearance_scale),
            Float64(xpoint_radial_shift_fraction),
            Float64(xpoint_vertical_scale), Float64(tikhonov_gamma),
            Int(grid_size))
    end
end

"""Topology genes for a minimum-B mirror coil family."""
struct MirrorCoilTopologyBuildSpec
    layout::String
    cell_count::Int
    end_high_fraction::Float64
    central_radius_scale::Float64
    end_radius_scale::Float64
    axis_field_share::Float64

    function MirrorCoilTopologyBuildSpec(; layout::AbstractString,
            cell_count::Integer = 3, end_high_fraction::Real = 0.82,
            central_radius_scale::Real = 1.0, end_radius_scale::Real = 1.0,
            axis_field_share::Real = 0.75)
        String(layout) in ("split_ioffe_saddle_pair",
            "continuous_baseball_seam_pair", "yin_yang_end_anchor_pair") ||
            throw(ArgumentError("unsupported mirror coil layout"))
        2 <= cell_count <= 6 || throw(ArgumentError("cell_count must be 2-6"))
        0.65 <= end_high_fraction <= 1.05 ||
            throw(ArgumentError("end_high_fraction must be 0.65-1.05"))
        0.85 <= central_radius_scale <= 1.35 ||
            throw(ArgumentError("central_radius_scale must be 0.85-1.35"))
        0.85 <= end_radius_scale <= 1.35 ||
            throw(ArgumentError("end_radius_scale must be 0.85-1.35"))
        0.45 <= axis_field_share <= 0.95 ||
            throw(ArgumentError("axis_field_share must be 0.45-0.95"))
        return new(String(layout), Int(cell_count), Float64(end_high_fraction),
            Float64(central_radius_scale), Float64(end_radius_scale),
            Float64(axis_field_share))
    end
end

function _gtv2_quantity(raw_entity, name::String, unit::String)
    haskey(raw_entity["parameters"], name) || error("missing parameter $name")
    item = raw_entity["parameters"][name]
    String(item["unit"]) == unit || error("$name must use $unit")
    return Float64(item["value"])
end

_gtv2_q(value, unit; basis = "candidate-specific geometry topology v2") =
    Dict{String,Any}("value" => value, "unit" => unit, "basis" => basis)

function _gtv2_finish(raw::Dict{String,Any}, parent::Genome, rule_id::String,
        source_ids::Vector{String})
    provenance = raw["provenance"]
    provenance["origin"] = "generated"
    provenance["parent_design_ids"] = [parent.design_id]
    provenance["claim_level"] = "structural_example"
    _push_unique!(provenance["source_ids"], source_ids)
    notes = get!(provenance, "notes", Any[])
    push!(notes, "grammar_rule:$rule_id")
    push!(notes,
        "Geometry child only; solver or preview results must be attached separately.")
    raw["design_id"] = "pending_candidate"
    raw["label"] = "Generated geometry child via $rule_id"
    provisional = parse_genome(raw)
    raw["design_id"] = "concept_$(provisional.physics_hash[1:20])"
    candidate = parse_genome(raw)
    report = validate_genome(candidate)
    report.valid || error(join(report.errors, "; "))
    return candidate
end

"""
Build a candidate-specific FreeGS child from common-envelope shape genes.

PF locations, domain, X-points, isoflux targets, pressure, and profile inputs
are derived from the parent major/minor radius, elongation, triangularity,
beta, field, current, shielding, maintenance, and winding-pack assumptions.
No coordinates are copied from the packaged FreeGS regression fixture.
"""
function build_tokamak_pf_shape_genome(parent::Genome,
        spec::TokamakPFShapeBuildSpec)
    parent.family == "tokamak_axisymmetric" ||
        throw(ArgumentError("PF/shape builder requires tokamak_axisymmetric"))
    raw = deepcopy(parent.normalized)
    core = only(filter(item -> item["kind"] == "closed_toroidal_core",
        raw["plasma_regions"]))
    major_m = _gtv2_quantity(core, "major_radius", "m")
    minor_m = _gtv2_quantity(core, "minor_radius", "m")
    elongation = _gtv2_quantity(core, "elongation", "1")
    triangularity = _gtv2_quantity(core, "triangularity", "1")
    targets = raw["mission"]["targets"]
    field_T = Float64(targets["screen_plasma_field"]["value"])
    beta = Float64(targets["screen_beta"]["value"])
    plasma_current_A = Float64(targets["plasma_current"]["value"])
    pack_m = Float64(targets["screen_coil_pack_thickness"]["value"])
    contract = default_common_comparison_contract()
    fixed_clearance_m = contract.shield_thickness_m +
        contract.maintenance_gap_m + 0.5 * pack_m
    inner_radius_m = major_m - minor_m -
        spec.radial_clearance_scale * fixed_clearance_m
    outer_radius_m = major_m + minor_m +
        spec.radial_clearance_scale * fixed_clearance_m
    inner_radius_m >= 0.35 || error("PF geometry leaves no central access")
    vertical_clearance_m = elongation * minor_m +
        spec.vertical_clearance_scale * fixed_clearance_m
    vertical_fractions = spec.layout == "symmetric_8" ?
        (0.58, 1.08) : (0.42, 0.76, 1.10)

    filter!(source -> source["kind"] != "poloidal_field_coil",
        raw["field_sources"])
    for (radial_label, radius_m) in (("inner", inner_radius_m),
            ("outer", outer_radius_m))
        for (level, fraction) in enumerate(vertical_fractions), sign in (-1, 1)
            push!(raw["field_sources"], Dict{String,Any}(
                "id" => "pf_$(radial_label)_$(level)_$(sign < 0 ? "lower" : "upper")",
                "kind" => "poloidal_field_coil",
                "geometry_model" => "freegs_filament_coil_v1",
                "parameters" => Dict(
                    "major_radius" => _gtv2_q(radius_m, "m"),
                    "vertical_position" =>
                        _gtv2_q(sign * fraction * vertical_clearance_m, "m"),
                ),
                "material" => contract.magnet_material_envelope,
            ))
        end
    end

    tf = only(filter(source -> source["kind"] == "toroidal_field_coil",
        raw["field_sources"]))
    tf["geometry_model"] = "vacuum_f_reference_v1"
    tf["parameters"] = Dict(
        "on_axis_field" => _gtv2_q(field_T, "T"),
        "reference_radius" => _gtv2_q(major_m, "m"),
    )
    plasma_current = only(filter(source -> source["kind"] == "plasma_current",
        raw["field_sources"]))
    plasma_current["geometry_model"] = "freegs_constrain_paxis_ip_v1"
    axis_pressure_Pa = beta * field_T^2 / (2.0 * 4.0 * pi * 1.0e-7)
    plasma_current["parameters"] = Dict(
        "total_current" => _gtv2_q(plasma_current_A, "A"),
        "axis_pressure" => _gtv2_q(axis_pressure_Pa, "Pa"),
        "alpha_m" => _gtv2_q(1.0, "1"),
        "alpha_n" => _gtv2_q(2.0, "1"),
        "profile_axis_radius" => _gtv2_q(major_m, "m"),
    )

    xpoint_radius_m = major_m - triangularity * minor_m +
        spec.xpoint_radial_shift_fraction * minor_m
    xpoint_z_m = spec.xpoint_vertical_scale * elongation * minor_m
    domain_half_height_m = max(2.0 * elongation * minor_m,
        1.20 * maximum(abs(source["parameters"]["vertical_position"]["value"])
            for source in raw["field_sources"]
            if source["kind"] == "poloidal_field_coil"))
    core["geometry_model"] = "freegs_explicit_filament_v1"
    merge!(core["parameters"], Dict{String,Any}(
        "domain_r_min" => _gtv2_q(max(0.10, major_m - 2.8 * minor_m), "m"),
        "domain_r_max" => _gtv2_q(major_m + 2.8 * minor_m, "m"),
        "domain_z_min" => _gtv2_q(-domain_half_height_m, "m"),
        "domain_z_max" => _gtv2_q(domain_half_height_m, "m"),
        "grid_nx" => _gtv2_q(spec.grid_size, "1"),
        "grid_ny" => _gtv2_q(spec.grid_size, "1"),
        "xpoint_lower_r" => _gtv2_q(xpoint_radius_m, "m"),
        "xpoint_lower_z" => _gtv2_q(-xpoint_z_m, "m"),
        "xpoint_upper_r" => _gtv2_q(xpoint_radius_m, "m"),
        "xpoint_upper_z" => _gtv2_q(xpoint_z_m, "m"),
        "isoflux_reference_r" => _gtv2_q(xpoint_radius_m, "m"),
        "isoflux_reference_z" => _gtv2_q(-xpoint_z_m, "m"),
        "isoflux_match_r" => _gtv2_q(xpoint_radius_m, "m"),
        "isoflux_match_z" => _gtv2_q(xpoint_z_m, "m"),
        "solver_rtol" => _gtv2_q(1.0e-4, "1"),
        "solver_atol" => _gtv2_q(1.0e-10, "1"),
        "solver_max_iterations" => _gtv2_q(1000, "1"),
    ))
    filter!(actuator -> actuator["kind"] != "feedback_coil", raw["actuators"])
    push!(raw["actuators"], Dict{String,Any}(
        "id" => "candidate_pf_shape_feedback",
        "kind" => "feedback_coil",
        "parameters" => Dict(
            "tikhonov_gamma" => _gtv2_q(spec.tikhonov_gamma, "1")),
    ))
    _push_unique!(raw["engineering"]["required_evaluators"], [
        "free_boundary_grad_shafranov", "pf_coil_current_and_peak_field",
        "pf_coil_force_and_support", "xpoint_and_isoflux_robustness"])
    return _gtv2_finish(raw, parent,
        "tokamak_candidate_specific_pf_shape_$(spec.layout)",
        ["tokamak_iter_physics_basis_1999", "freegs_software_0_8_2"])
end

"""Build a new mirror child whose minimum-B coil family is an explicit gene."""
function build_mirror_coil_topology_genome(parent::Genome,
        spec::MirrorCoilTopologyBuildSpec)
    parent.family == "magnetic_mirror" ||
        throw(ArgumentError("mirror coil builder requires magnetic_mirror"))
    raw = deepcopy(parent.normalized)
    sources = filter(source -> source["kind"] == "minimum_b_coil",
        raw["field_sources"])
    source = if isempty(sources)
        new_source = Dict{String,Any}(
            "id" => "mirror_minimum_b_geometry_v2",
            "kind" => "minimum_b_coil",
            "geometry_model" => spec.layout,
            "parameters" => Dict{String,Any}(),
            "material" => default_common_comparison_contract().magnet_material_envelope,
        )
        push!(raw["field_sources"], new_source)
        new_source
    else
        first(sources)
    end
    source["geometry_model"] = spec.layout
    source["parameters"] = Dict{String,Any}(
        "coil_count" => _gtv2_q(2 * spec.cell_count, "1"),
        "cell_count" => _gtv2_q(spec.cell_count, "1"),
        "end_high_fraction" => _gtv2_q(spec.end_high_fraction, "1"),
        "central_radius_scale" => _gtv2_q(spec.central_radius_scale, "1"),
        "end_radius_scale" => _gtv2_q(spec.end_radius_scale, "1"),
        "axis_field_share" => _gtv2_q(spec.axis_field_share, "1"),
    )
    raw["symmetry"]["class"] = "minimum_b"
    _push_unique!(raw["symmetry"]["hard_constraints"], [
        "explicit minimum-B coil family", "central-cell accessibility"])
    targets = raw["mission"]["targets"]
    if Float64(targets["screen_minimum_b_strength"]["value"]) <= 0.0
        targets["screen_minimum_b_strength"] = _gtv2_q(0.50, "1")
    end
    if !any(mechanism -> mechanism["mechanism"] == "minimum_b",
            raw["stability_mechanisms"])
        push!(raw["stability_mechanisms"], Dict{String,Any}(
            "id" => "mirror_minimum_b_geometry_mechanism_v2",
            "mechanism" => "minimum_b",
            "target_modes" => ["interchange", "flute"],
            "actuator_ids" => Any[],
            "assumptions" => [
                "vacuum geometry must pass before finite-beta stability credit"],
            "required_evaluators" => [
                "layout_specific_vacuum_field", "anisotropic_equilibrium",
                "interchange_growth", "full_orbit"],
            "source_ids" => [
                "mirror_tandem_fowler_logan_1977", "mirror_post_review_1987"],
        ))
    end
    _push_unique!(raw["engineering"]["required_evaluators"], [
        "layout_specific_finite_build_coils", "minimum_b_coil_forces",
        "transition_region_field_lines", "end_region_access"])
    return _gtv2_finish(raw, parent,
        "mirror_coil_family_$(spec.layout)",
        ["mirror_tandem_fowler_logan_1977", "mirror_post_review_1987"])
end

function geometry_topology_v2_descriptor(genome::Genome)
    if genome.family == "tokamak_axisymmetric"
        pf_count = count(source -> source.kind == "poloidal_field_coil",
            genome.field_sources)
        layout = pf_count == 8 ? "pf8" : pf_count == 12 ? "pf12" : "pf_other"
        aspect = _screen_target(genome, "screen_aspect_ratio", 0.0, "1")
        return "tokamak_axisymmetric|$layout|A=$(round(aspect; digits=1))"
    elseif genome.family == "magnetic_mirror"
        sources = filter(source -> source.kind == "minimum_b_coil",
            genome.field_sources)
        layout = isempty(sources) ? "missing_minimum_b" : first(sources).geometry_model
        ratio = _screen_target(genome, "screen_mirror_ratio", 1.0, "1")
        aspect = _screen_target(genome, "screen_aspect_ratio", 0.0, "1")
        return "magnetic_mirror|$layout|Rm=$(round(ratio; digits=1))|A=$(round(aspect; digits=1))"
    end
    return "$(genome.family)|geometry_unmodified"
end

"""
Return the only permitted next evaluator for a geometry child.

New mirror layouts are deliberately not routed into the cage-only finite-coil
adapter.  This prevents an available backend from being mistaken for an
applicable backend.
"""
function geometry_topology_v2_route(genome::Genome)
    if genome.family == "tokamak_axisymmetric"
        applicable, reason = evaluator_applicability(
            TokamakFreeBoundaryFreeGSV1(), genome)
        return Dict{String,Any}(
            "task_id" => "tokamak_free_boundary_freegs_v1",
            "backend_status" => "available",
            "applicable" => applicable,
            "reason" => reason,
        )
    elseif genome.family == "magnetic_mirror"
        sources = filter(source -> source.kind == "minimum_b_coil",
            genome.field_sources)
        isempty(sources) && return Dict{String,Any}(
            "task_id" => "layout_specific_mirror_vacuum_geometry_v2",
            "backend_status" => "planned",
            "applicable" => false,
            "reason" => "no explicit minimum-B source")
        layout = first(sources).geometry_model
        if layout == "paired_finite_build_minimum_b_anchor_coils"
            applicable, reason = evaluator_applicability(
                MirrorFiniteCoilGeometryV1(), genome)
            return Dict{String,Any}(
                "task_id" => "mirror_finite_coil_geometry_v1",
                "backend_status" => "available",
                "applicable" => applicable,
                "reason" => reason,
            )
        end
        return Dict{String,Any}(
            "task_id" => "mirror_$(layout)_vacuum_geometry_v1",
            "backend_status" => "planned",
            "applicable" => false,
            "reason" => "layout-specific field and finite-build adapter not yet implemented; cage-only evidence is forbidden",
        )
    end
    return Dict{String,Any}(
        "task_id" => "family_specific_geometry_v2",
        "backend_status" => "planned",
        "applicable" => false,
        "reason" => "no geometry-v2 route for family $(genome.family)",
    )
end
