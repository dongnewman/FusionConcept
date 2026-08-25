function _set_screen_target!(raw, name::AbstractString, value::Real, unit::AbstractString;
        basis::AbstractString = "cross-family five-gate search gene")
    raw["mission"]["targets"][String(name)] = Dict{String,Any}(
        "value" => Float64(value), "unit" => String(unit), "basis" => String(basis))
    return raw
end

function _screen_rule_finish_common!(raw)
    raw["mission"]["fuel"] = "D-T"
    raw["mission"]["operating_mode"] = "steady_state"
    _set_screen_target!(raw, "screen_common_envelope_version", 2.0, "1")
    return raw
end

function _set_common_quantity!(parameters, name::AbstractString, value::Real,
        unit::AbstractString; basis::Union{Nothing,AbstractString} = nothing)
    quantity = Dict{String,Any}("value" => Float64(value), "unit" => String(unit))
    basis === nothing || (quantity["basis"] = String(basis))
    parameters[String(name)] = quantity
    return parameters
end

"Make the explicit component declarations use exactly the same envelope as the scorer."
function _synchronize_common_envelope(genome::Genome,
        contract::CommonComparisonContract; id_prefix::Union{Nothing,String} = nothing)
    raw = deepcopy(genome.normalized)
    _screen_rule_finish_common!(raw)
    basis = "fixed $(contract.id) component synchronization"
    for (name, value, unit) in (
            ("screen_major_scale", contract.major_scale_m, "m"),
            ("screen_plasma_field", contract.plasma_field_T, "T"),
            ("screen_peak_conductor_field_limit",
                contract.peak_conductor_field_limit_T, "T"),
            ("screen_material_envelope_version", 1.0, "1"),
            ("on_axis_field", contract.plasma_field_T, "T"))
        _set_screen_target!(raw, name, value, unit; basis = basis)
    end

    features = _topology_features(parse_genome(raw))
    for (name, value) in (
            ("screen_closed_flux_fraction", features.closed_fraction),
            ("screen_plasma_current_transform_fraction",
                features.plasma_current_fraction),
            ("screen_external_transform_fraction",
                features.external_transform_fraction),
            ("screen_three_dimensional_field_fraction", features.three_d_fraction),
            ("screen_internal_coil_fraction", features.internal_coil_fraction),
            ("screen_mirror_ratio", features.mirror_ratio),
            ("screen_plug_strength", features.plug_strength),
            ("screen_minimum_b_strength", features.minimum_b_strength),
            ("screen_shear_strength", features.shear_strength))
        _set_screen_target!(raw, name, value, "1"; basis = basis)
    end
    minor_radius = contract.major_scale_m / features.aspect_ratio
    plasma_current_A = 1.0e6 * _expected_screen_plasma_current_MA(features, contract)
    mirror_peak_T = contract.plasma_field_T * max(features.mirror_ratio, 1.0)
    temperature_J = _screen_target(parse_genome(raw), "screen_temperature",
        15.0 * 1.602176634e-16, "J")
    pressure_Pa = features.beta * contract.plasma_field_T^2 / (2.0 * 4.0e-7 * pi)
    density_m3 = pressure_Pa / max(2.0 * temperature_J, 1.0e-30)
    open_volume_m3 = pi * minor_radius^2 * 2.0 * contract.major_scale_m

    has_plasma_current = false
    for source in raw["field_sources"]
        kind = lowercase(String(source["kind"]))
        parameters = source["parameters"]
        if kind == "plasma_current"
            has_plasma_current = true
            _set_common_quantity!(parameters, "total_current", plasma_current_A, "A";
                basis = basis)
            source["material"] = "plasma"
            continue
        end
        source["material"] = contract.magnet_material_envelope
        if occursin("toroidal_field", kind)
            _set_common_quantity!(parameters, "on_axis_field",
                contract.plasma_field_T, "T"; basis = basis)
        end
        if occursin("three_dimensional", kind)
            _set_common_quantity!(parameters, "nominal_field",
                contract.plasma_field_T, "T"; basis = basis)
            _set_common_quantity!(parameters, "external_transform_fraction_gene",
                features.external_transform_fraction, "1"; basis = basis)
        end
        if occursin("mirror", kind) || occursin("minimum_b", kind)
            _set_common_quantity!(parameters, "peak_field", mirror_peak_T, "T";
                basis = basis)
        end
    end
    raw["engineering"]["magnet_technology"] = Any[contract.magnet_material_envelope]
    if has_plasma_current
        _set_screen_target!(raw, "plasma_current", plasma_current_A, "A";
            basis = basis)
    end

    for region in raw["plasma_regions"]
        kind = lowercase(String(region["kind"]))
        parameters = region["parameters"]
        if kind == "closed_toroidal_core"
            _set_common_quantity!(parameters, "major_radius", contract.major_scale_m,
                "m"; basis = basis)
            _set_common_quantity!(parameters, "minor_radius", minor_radius, "m";
                basis = basis)
            haskey(parameters, "minor_radius_r") &&
                _set_common_quantity!(parameters, "minor_radius_r", minor_radius,
                    "m"; basis = basis)
            haskey(parameters, "minor_radius_z") &&
                _set_common_quantity!(parameters, "minor_radius_z", minor_radius,
                    "m"; basis = basis)
        elseif kind == "mirror_central_cell"
            _set_common_quantity!(parameters, "central_field",
                contract.plasma_field_T, "T"; basis = basis)
            _set_common_quantity!(parameters, "plasma_radius", minor_radius, "m";
                basis = basis)
            _set_common_quantity!(parameters, "cell_length",
                2.0 * contract.major_scale_m, "m"; basis = basis)
            _set_common_quantity!(parameters, "mirror_ratio_gene",
                features.mirror_ratio, "1"; basis = basis)
            _set_common_quantity!(parameters, "effective_plasma_volume",
                open_volume_m3, "m^3"; basis = basis)
            _set_common_quantity!(parameters, "ion_density", density_m3, "m^-3";
                basis = basis)
        elseif occursin("plug", kind)
            _set_common_quantity!(parameters, "peak_field", mirror_peak_T, "T";
                basis = basis)
        end
    end
    notes = get!(raw["provenance"], "notes", Any[])
    _push_unique!(notes, ["common_envelope_component_sync_v2",
        "Magnet and support material names are numerical screening envelopes, not qualified materials."])

    synchronized = parse_genome(raw)
    if id_prefix !== nothing
        raw = deepcopy(synchronized.normalized)
        raw["design_id"] = "$(id_prefix)_$(synchronized.physics_hash[1:20])"
        synchronized = parse_genome(raw)
    end
    return synchronized
end

function _screen_parameter_resample_transform!(raw, rng)
    _screen_rule_finish_common!(raw)
    line_class = raw["topology"]["field_line_class"]
    closed_default = startswith(line_class, "closed") ? 1.0 :
        line_class == "open_mirror" ? 0.0 : line_class == "mixed" ?
            rand(rng, (0.40, 0.60, 0.80)) : 0.95
    beta_values = line_class == "open_mirror" ? (0.05, 0.08, 0.12, 0.18, 0.24, 0.30) :
        line_class == "mixed" ? (0.025, 0.04, 0.06, 0.08, 0.12, 0.16) :
        (0.015, 0.02, 0.025, 0.04, 0.055, 0.07)
    _set_screen_target!(raw, "screen_closed_flux_fraction", closed_default, "1")
    _set_screen_target!(raw, "screen_aspect_ratio",
        rand(rng, (2.8, 3.2, 3.8, 4.5, 5.5, 6.5)), "1")
    _set_screen_target!(raw, "screen_beta", rand(rng, beta_values), "1")
    _set_screen_target!(raw, "screen_temperature",
        rand(rng, (10.0, 15.0, 20.0, 25.0)), "keV")
    _set_screen_target!(raw, "screen_field_quality",
        rand(rng, (0.70, 0.82, 0.90, 0.96)), "1")
    _set_screen_target!(raw, "screen_q95", rand(rng, (2.5, 3.0, 3.5, 4.0, 5.0)), "1")
    _set_screen_target!(raw, "screen_coil_pack_thickness",
        rand(rng, (0.30, 0.45, 0.60)), "m")
    _set_screen_target!(raw, "screen_support_thickness",
        rand(rng, (0.50, 0.70, 0.90)), "m")

    transform_sources = Set(String.(raw["topology"]["rotation_transform_sources"]))
    plasma_declared = "plasma_current" in transform_sources
    external_declared = "three_dimensional_external_field" in transform_sources
    if plasma_declared && external_declared
        plasma_fraction = rand(rng, (0.25, 0.50, 0.75))
        external_fraction = 1.0 - plasma_fraction
    else
        plasma_fraction = plasma_declared ? 1.0 : 0.0
        external_fraction = external_declared ? 1.0 : 0.0
    end
    _set_screen_target!(raw, "screen_plasma_current_transform_fraction",
        plasma_fraction, "1")
    _set_screen_target!(raw, "screen_external_transform_fraction",
        external_fraction, "1")
    three_d = raw["symmetry"]["class"] in
        ("axisymmetric", "minimum_b") ? 0.0 : rand(rng, (0.50, 0.75, 1.0))
    _set_screen_target!(raw, "screen_three_dimensional_field_fraction", three_d, "1")

    open_fraction = 1.0 - closed_default
    _set_screen_target!(raw, "screen_mirror_ratio",
        open_fraction > 0 ? rand(rng, (3.0, 4.0, 5.0, 6.0)) : 1.0, "1")
    plug_present = any(region -> occursin("plug", lowercase(String(region["kind"]))),
        raw["plasma_regions"])
    minimum_b_present = raw["symmetry"]["class"] == "minimum_b" ||
        any(source -> occursin("minimum_b", lowercase(String(source["kind"]))),
            raw["field_sources"])
    internal_present = any(source -> occursin("internal", lowercase(String(source["kind"]))) ||
        occursin("levitated", lowercase(String(source["kind"]))), raw["field_sources"])
    _set_screen_target!(raw, "screen_plug_strength",
        plug_present ? rand(rng, (0.40, 0.70, 1.0)) : 0.0, "1")
    _set_screen_target!(raw, "screen_minimum_b_strength",
        minimum_b_present ? rand(rng, (0.50, 0.75, 1.0)) : 0.0, "1")
    shear_present = any(mechanism -> String(mechanism["mechanism"]) == "sheared_flow",
        raw["stability_mechanisms"])
    _set_screen_target!(raw, "screen_shear_strength",
        shear_present ? rand(rng, (0.40, 0.70, 1.0)) : 0.0, "1")
    _set_screen_target!(raw, "screen_internal_coil_fraction",
        internal_present ? rand(rng, (0.25, 0.50, 0.75)) : 0.0, "1")
end

function _closed_open_hybrid_transform!(raw, rng)
    parent_family = String(raw["family"])
    raw["family"] = "closed_open_hybrid"
    raw["topology"]["field_line_class"] = "mixed"
    raw["topology"]["expected_flux_surfaces"] = true
    raw["topology"]["expected_separatrix"] = true
    sources = Set(String.(raw["topology"]["rotation_transform_sources"]))
    delete!(sources, "not_applicable")
    if isempty(sources)
        push!(sources, "three_dimensional_external_field")
    end
    parent_family == "magnetic_mirror" && push!(sources, "three_dimensional_external_field")
    raw["topology"]["rotation_transform_sources"] = sort!(collect(sources))
    raw["symmetry"]["class"] = "mixed"
    raw["symmetry"]["field_periods"] = rand(rng, 2:5)
    _push_unique!(raw["symmetry"]["hard_constraints"], [
        "closed-core/open-end separatrix compatibility",
        "field-line mapping through both mirror throats",
    ])
    raw["plasma_regions"] = Any[
        Dict{String,Any}(
            "id" => "hybrid_closed_core",
            "kind" => "closed_toroidal_core",
            "geometry_model" => "mixed_toroidal_fourier_core_proxy",
            "parameters" => Dict{String,Any}(),
        ),
        Dict{String,Any}(
            "id" => "hybrid_left_open_end",
            "kind" => "end_expander",
            "geometry_model" => "open_mirror_expander_proxy",
            "parameters" => Dict{String,Any}(),
        ),
        Dict{String,Any}(
            "id" => "hybrid_right_open_end",
            "kind" => "end_expander",
            "geometry_model" => "open_mirror_expander_proxy",
            "parameters" => Dict{String,Any}(),
        ),
    ]
    if !any(source -> String(source["id"]) == "hybrid_mirror_throats", raw["field_sources"])
        push!(raw["field_sources"], Dict{String,Any}(
            "id" => "hybrid_mirror_throats",
            "kind" => "mirror_coil",
            "geometry_model" => "paired_external_mirror_throats",
            "parameters" => Dict(
                "coil_count" => Dict("value" => 2, "unit" => "1"),
            ),
            "material" => "common-envelope conceptual superconducting winding",
        ))
    end
    raw["flux_connections"] = Any[
        Dict("from_region_id" => "hybrid_closed_core",
            "to_region_id" => "hybrid_left_open_end", "kind" => "open_field_line"),
        Dict("from_region_id" => "hybrid_closed_core",
            "to_region_id" => "hybrid_right_open_end", "kind" => "open_field_line"),
    ]
    raw["exhaust"] = Dict{String,Any}(
        "kind" => "closed_edge_plus_open_end_direct_conversion",
        "region_ids" => ["hybrid_left_open_end", "hybrid_right_open_end"],
        "evaluation_requirements" => [
            "particle_loss", "open_end_power", "peak_heat_flux", "direct_conversion"],
    )
    if !any(mechanism -> String(mechanism["id"]) == "hybrid_interface_stability",
            raw["stability_mechanisms"])
        push!(raw["stability_mechanisms"], Dict{String,Any}(
            "id" => "hybrid_interface_stability",
            "mechanism" => "favorable_curvature",
            "target_modes" => ["closed-open interface interchange", "open-end loss cone"],
            "actuator_ids" => Any[],
            "assumptions" => [
                "a common equilibrium joins the closed core to both mirror throats",
                "open-end exhaust does not destroy the closed-core flux surfaces",
            ],
            "required_evaluators" => [
                "coupled_closed_open_equilibrium", "field_line_and_particle_following",
                "interchange_growth", "particle_loss"],
            "source_ids" => ["mirror_tandem_fowler_logan_1977",
                "stellarator_garren_boozer_1991"],
        ))
    end
    engineering = raw["engineering"]
    _push_unique!(engineering["required_evaluators"], [
        "finite_build_coils", "coil_stress", "shielding", "maintenance_access",
        "power_balance"])
    _push_unique!(engineering["maintenance"]["access_paths"], [
        "axial open-end service corridor", "external toroidal coil sectors"])
    _screen_rule_finish_common!(raw)
    closed_fraction = rand(rng, (0.40, 0.60, 0.80))
    _set_screen_target!(raw, "screen_closed_flux_fraction", closed_fraction, "1")
    _set_screen_target!(raw, "screen_mirror_ratio", rand(rng, (3.0, 4.0, 5.0, 6.0)), "1")
    _set_screen_target!(raw, "screen_plug_strength", rand(rng, (0.40, 0.70, 1.0)), "1")
    _set_screen_target!(raw, "screen_three_dimensional_field_fraction",
        rand(rng, (0.50, 0.75, 1.0)), "1")
end

function _internal_coil_anchor_transform!(raw, rng)
    push!(raw["field_sources"], Dict{String,Any}(
        "id" => "internal_levitated_anchor",
        "kind" => "internal_levitated_dipole_coil",
        "geometry_model" => "shielded_internal_ring_proxy",
        "parameters" => Dict(
            "coil_count" => Dict("value" => 1, "unit" => "1"),
        ),
        "material" => "common-envelope conceptual superconducting winding",
    ))
    push!(raw["stability_mechanisms"], Dict{String,Any}(
        "id" => "internal_dipole_anchor_mechanism",
        "mechanism" => "favorable_curvature",
        "target_modes" => ["interchange", "radial drift"],
        "actuator_ids" => Any[],
        "assumptions" => [
            "the internal coil remains aligned and superconducting under nuclear loading",
            "shielding and remote replacement fit inside the plasma aperture",
        ],
        "required_evaluators" => [
            "finite_beta_dipole_equilibrium", "internal_coil_neutronics",
            "internal_coil_maintenance", "coil_stress"],
        "source_ids" => ["levitated_dipole_hasegawa_1990"],
    ))
    _push_unique!(raw["engineering"]["maintenance"]["access_paths"], [
        "levitated internal coil remote replacement path"])
    _push_unique!(raw["engineering"]["required_evaluators"], [
        "internal_coil_neutronics", "internal_coil_maintenance", "coil_stress"])
    _screen_rule_finish_common!(raw)
    _set_screen_target!(raw, "screen_internal_coil_fraction",
        rand(rng, (0.25, 0.50, 0.75)), "1")
end

function discovery_graph_rules_v2()
    families = collect(keys(default_family_registry().specs))
    parameter_rule = _graph_rule(
        "common_envelope_parameter_resample",
        "Resample only design genes while keeping the cross-family size, field, material, and evaluation budget fixed.",
        families,
        ["lawson_wurzel_hsu_2022", "bosch_hale_reactivity_1992",
            "process_physics_2015", "process_engineering_2016"],
        genome -> genome.mission.fuel == "D-T",
        _screen_parameter_resample_transform!)
    hybrid_rule = _graph_rule(
        "closed_open_mirror_exhaust_hybrid",
        "Join a closed toroidal core to two explicit mirror-throat/open-end exhaust branches.",
        ["tokamak_axisymmetric", "tokamak_3d_hybrid", "stellarator", "magnetic_mirror"],
        ["mirror_tandem_fowler_logan_1977", "stellarator_garren_boozer_1991"],
        genome -> genome.family != "closed_open_hybrid",
        _closed_open_hybrid_transform!)
    internal_rule = _graph_rule(
        "internal_levitated_anchor",
        "Add an internal levitated magnetic anchor with explicit shielding and maintenance obligations.",
        ["stellarator", "magnetic_mirror", "closed_open_hybrid", "tokamak_3d_hybrid"],
        ["levitated_dipole_hasegawa_1990"],
        genome -> !_has_entity(genome, :field_sources, "internal_levitated_anchor"),
        _internal_coil_anchor_transform!)
    common_rules = filter(rule -> rule.id != "tokamak_demountable_high_field",
        default_graph_rules())
    return vcat(common_rules, GraphRule[parameter_rule, hybrid_rule, internal_rule])
end

function _baseline_gene_defaults!(raw, family::String)
    _screen_rule_finish_common!(raw)
    if family == "tokamak_axisymmetric"
        values = (1.0, 0.0, 1.0, 0.0, 0.0, 3.1, 0.04, 0.90, 0.0, 0.0, 0.0)
    elseif family == "stellarator"
        values = (1.0, 0.0, 0.0, 1.0, 1.0, 5.5, 0.04, 0.92, 0.0, 0.0, 0.0)
    elseif family == "magnetic_mirror"
        values = (0.0, 5.0, 0.0, 0.0, 0.0, 4.5, 0.18, 0.90, 0.0, 0.0, 0.0)
    else
        values = (0.65, 4.0, 0.5, 0.5, 0.75, 4.0, 0.08, 0.86, 0.6, 0.6, 0.0)
    end
    closed, mirror, plasma, external, three_d, aspect, beta, quality,
        plug, minimum_b, internal = values
    for (name, value) in (
            ("screen_closed_flux_fraction", closed), ("screen_mirror_ratio", mirror),
            ("screen_plasma_current_transform_fraction", plasma),
            ("screen_external_transform_fraction", external),
            ("screen_three_dimensional_field_fraction", three_d),
            ("screen_aspect_ratio", aspect), ("screen_beta", beta),
            ("screen_field_quality", quality), ("screen_plug_strength", plug),
            ("screen_minimum_b_strength", minimum_b),
            ("screen_internal_coil_fraction", internal),
            ("screen_q95", 3.5), ("screen_shear_strength", 0.0))
        _set_screen_target!(raw, name, value, "1";
            basis = "fixed common-envelope baseline")
    end
    _set_screen_target!(raw, "screen_temperature", 15.0, "keV";
        basis = "fixed common-envelope baseline")
    _set_screen_target!(raw, "screen_coil_pack_thickness", 0.45, "m";
        basis = "fixed common-envelope baseline")
    _set_screen_target!(raw, "screen_support_thickness", 0.70, "m";
        basis = "fixed common-envelope baseline")
end

function _common_baseline_genomes(seeds::Vector{Genome},
        contract::CommonComparisonContract = default_common_comparison_contract())
    representatives = Genome[]
    for family in ("tokamak_axisymmetric", "stellarator", "magnetic_mirror")
        matches = filter(genome -> genome.family == family, seeds)
        isempty(matches) && continue
        chosen = family == "magnetic_mirror" ? begin
            preferred = filter(genome -> genome.design_id == "beam_2024_concept_seed", matches)
            isempty(preferred) ? first(matches) : only(preferred)
        end : first(matches)
        raw = deepcopy(chosen.normalized)
        _baseline_gene_defaults!(raw, family)
        raw["design_id"] = "common_baseline_$(family)"
        raw["label"] = "Common-envelope $(family) baseline"
        raw["provenance"]["origin"] = "generated"
        raw["provenance"]["parent_design_ids"] = [chosen.design_id]
        raw["provenance"]["claim_level"] = "structural_example"
        push!(raw["provenance"]["notes"], "common_comparison_baseline_v1")
        push!(representatives,
            _synchronize_common_envelope(parse_genome(raw), contract))
    end
    return representatives
end

function _common_doe_anchor_genomes(baselines::Vector{Genome},
        contract::CommonComparisonContract = default_common_comparison_contract())
    anchors = Genome[]
    for baseline in baselines
        beta_values = baseline.family == "magnetic_mirror" ? (0.08, 0.18) :
            (0.025, 0.055)
        for aspect in (2.8, 4.5), beta in beta_values, temperature_keV in (10.0, 20.0)
            raw = deepcopy(baseline.normalized)
            for (name, value, unit) in (
                    ("screen_aspect_ratio", aspect, "1"),
                    ("screen_beta", beta, "1"),
                    ("screen_temperature", temperature_keV, "keV"),
                    ("screen_field_quality", 0.96, "1"),
                    ("screen_q95", 2.5, "1"),
                    ("screen_coil_pack_thickness", 0.60, "m"),
                    ("screen_support_thickness", 0.90, "m"))
                _set_screen_target!(raw, name, value, unit;
                    basis = "common-envelope design-of-experiments anchor")
            end
            raw["design_id"] = "pending_doe_anchor"
            raw["label"] = "Common-envelope DOE anchor for $(baseline.family)"
            raw["provenance"]["origin"] = "generated"
            raw["provenance"]["parent_design_ids"] = [baseline.design_id]
            raw["provenance"]["claim_level"] = "structural_example"
            push!(raw["provenance"]["notes"], "common_envelope_doe_anchor_v1")
            provisional = _synchronize_common_envelope(parse_genome(raw), contract)
            raw = deepcopy(provisional.normalized)
            raw["design_id"] = "doe_$(provisional.physics_hash[1:20])"
            push!(anchors, parse_genome(raw))
        end
    end
    return anchors
end

function _synchronized_rule_application(rule::GraphRule, parent::Genome,
        rng::AbstractRNG, contract::CommonComparisonContract)
    return _synchronize_common_envelope(apply_rule(rule, parent, rng), contract;
        id_prefix = "topology_parent")
end

"Deterministic coverage anchors for topology strata that baseline-only DOE misses."
function _common_topology_doe_anchor_genomes(baselines::Vector{Genome},
        contract::CommonComparisonContract = default_common_comparison_contract())
    rules = Dict(rule.id => rule for rule in discovery_graph_rules_v2())
    by_family = Dict(genome.family => genome for genome in baselines)
    rng = MersenneTwister(20260812)
    parents = Genome[]

    tokamak = by_family["tokamak_axisymmetric"]
    stellarator = by_family["stellarator"]
    mirror = by_family["magnetic_mirror"]
    tokamak_3d = _synchronized_rule_application(
        rules["tokamak_external_transform"], tokamak, rng, contract)
    push!(parents, tokamak_3d)
    for parent in (tokamak, tokamak_3d, stellarator)
        push!(parents, _synchronized_rule_application(
            rules["closed_open_mirror_exhaust_hybrid"], parent, rng, contract))
    end
    mirror_bundle = mirror
    for id in ("mirror_minimum_b_anchors", "mirror_tandem_ambipolar_plugs",
            "mirror_gas_dynamic_regime")
        mirror_bundle = _synchronized_rule_application(rules[id], mirror_bundle,
            rng, contract)
    end
    push!(parents, mirror_bundle)

    anchors = Genome[]
    aspect_values = (2.8, 3.2, 3.8, 4.5)
    temperature_values = (10.0, 15.0, 20.0, 25.0)
    mirror_values = (3.0, 4.0, 5.0, 6.0)
    closed_values = (0.4, 0.6, 0.8, 0.6)
    transform_values = (0.50, 0.65, 0.75, 0.90)
    quality_values = (0.90, 0.96, 0.96, 0.90)
    for parent in parents, index in 0:15
        raw = deepcopy(parent.normalized)
        line_class = String(raw["topology"]["field_line_class"])
        beta_values = line_class == "open_mirror" ? (0.05, 0.08, 0.12, 0.18) :
            line_class == "mixed" ? (0.015, 0.025, 0.04, 0.06) :
            (0.015, 0.02, 0.025, 0.04)
        aspect = aspect_values[mod(index, 4) + 1]
        beta = beta_values[mod(div(index, 4), 4) + 1]
        temperature = temperature_values[mod(div(index, 2), 4) + 1]
        q95 = (2.5, 3.0, 3.5, 4.0)[mod(div(index, 8), 4) + 1]
        for (name, value, unit) in (
                ("screen_aspect_ratio", aspect, "1"),
                ("screen_beta", beta, "1"),
                ("screen_temperature", temperature, "keV"),
                ("screen_field_quality", quality_values[mod(index, 4) + 1], "1"),
                ("screen_q95", q95, "1"),
                ("screen_coil_pack_thickness", index % 2 == 0 ? 0.45 : 0.60, "m"),
                ("screen_support_thickness", index % 2 == 0 ? 0.70 : 0.90, "m"))
            _set_screen_target!(raw, name, value, unit;
                basis = "topology-stratified common-envelope DOE")
        end
        if line_class == "mixed"
            _set_screen_target!(raw, "screen_closed_flux_fraction",
                closed_values[mod(index, 4) + 1], "1";
                basis = "topology-stratified common-envelope DOE")
        elseif line_class == "open_mirror"
            _set_screen_target!(raw, "screen_closed_flux_fraction", 0.0, "1";
                basis = "topology-stratified common-envelope DOE")
        else
            _set_screen_target!(raw, "screen_closed_flux_fraction", 1.0, "1";
                basis = "topology-stratified common-envelope DOE")
        end
        if line_class in ("mixed", "open_mirror")
            _set_screen_target!(raw, "screen_mirror_ratio",
                mirror_values[mod(div(index, 2), 4) + 1], "1";
                basis = "topology-stratified common-envelope DOE")
        end

        transform_sources = Set(String.(raw["topology"]["rotation_transform_sources"]))
        plasma_declared = "plasma_current" in transform_sources
        external_declared = "three_dimensional_external_field" in transform_sources
        if plasma_declared && external_declared
            plasma_fraction = transform_values[mod(index, 4) + 1]
            _set_screen_target!(raw, "screen_plasma_current_transform_fraction",
                plasma_fraction, "1";
                basis = "topology-stratified common-envelope DOE")
            _set_screen_target!(raw, "screen_external_transform_fraction",
                1.0 - plasma_fraction, "1";
                basis = "topology-stratified common-envelope DOE")
        else
            _set_screen_target!(raw, "screen_plasma_current_transform_fraction",
                plasma_declared ? 1.0 : 0.0, "1";
                basis = "topology-stratified common-envelope DOE")
            _set_screen_target!(raw, "screen_external_transform_fraction",
                external_declared ? 1.0 : 0.0, "1";
                basis = "topology-stratified common-envelope DOE")
        end
        _set_screen_target!(raw, "screen_three_dimensional_field_fraction",
            external_declared ? (index % 2 == 0 ? 0.50 : 0.75) : 0.0, "1";
            basis = "topology-stratified common-envelope DOE")
        minimum_b_present = any(source ->
            occursin("minimum_b", lowercase(String(source["kind"]))),
            raw["field_sources"])
        plug_present = any(region -> occursin("plug", lowercase(String(region["kind"]))),
            raw["plasma_regions"])
        _set_screen_target!(raw, "screen_minimum_b_strength",
            minimum_b_present ? (index % 2 == 0 ? 0.50 : 0.75) : 0.0, "1";
            basis = "topology-stratified common-envelope DOE")
        _set_screen_target!(raw, "screen_plug_strength",
            plug_present ? (0.40, 0.70, 1.0, 0.70)[mod(index, 4) + 1] : 0.0,
            "1"; basis = "topology-stratified common-envelope DOE")
        raw["design_id"] = "pending_topology_doe"
        raw["label"] = "Topology-stratified common-envelope DOE anchor"
        raw["provenance"]["origin"] = "generated"
        raw["provenance"]["parent_design_ids"] = [parent.design_id]
        raw["provenance"]["claim_level"] = "structural_example"
        _push_unique!(get!(raw["provenance"], "notes", Any[]),
            ["common_topology_doe_anchor_v1"])
        push!(anchors, _synchronize_common_envelope(parse_genome(raw), contract;
            id_prefix = "topology_doe"))
    end
    unique_anchors = Dict(anchor.physics_hash => anchor for anchor in anchors)
    return sort!(collect(values(unique_anchors)); by = genome -> genome.physics_hash)
end

struct FiveGateSearchRecord
    genome::Genome
    descriptor::String
    architecture::String
    evaluation::Dict{String,Any}
    is_baseline::Bool
    novelty_from_baselines::Float64
end

mutable struct FiveGateQDArchive
    cells::Dict{String,FiveGateSearchRecord}
    seen_hashes::Set{String}
end

FiveGateQDArchive() = FiveGateQDArchive(Dict{String,FiveGateSearchRecord}(), Set{String}())

struct FiveGateSearchResult
    archive::FiveGateQDArchive
    baselines::Vector{FiveGateSearchRecord}
    discovered::Vector{FiveGateSearchRecord}
    prototypes::Vector{FiveGateSearchRecord}
    attempts::Int
    rejected::Int
    duplicates::Int
    random_seed::Int
    iterations::Int
    contract::CommonComparisonContract
    rejection_reasons::Dict{String,Int}
end

function _feature_bin(value, cuts, labels)
    for (cut, label) in zip(cuts, labels)
        value < cut && return label
    end
    return labels[end]
end

function five_gate_descriptor(genome::Genome)
    features = _topology_features(genome)
    closure = features.closed_fraction > 0.95 ? "closed" :
        features.closed_fraction < 0.05 ? "open" : "mixed"
    transform = features.plasma_current_fraction > 0.01 &&
        features.external_transform_fraction > 0.01 ? "mixed_transform" :
        features.plasma_current_fraction > 0.01 ? "plasma_transform" :
        features.external_transform_fraction > 0.01 ? "external_transform" : "no_transform"
    coil_location = features.internal_coil_fraction > 0.05 ? "internal_external" : "external_only"
    aspect = _feature_bin(features.aspect_ratio, (3.2, 4.5, 6.0, Inf),
        ("A_low", "A_mid", "A_high", "A_very_high"))
    beta = _feature_bin(features.beta, (0.06, 0.12, 0.24, Inf),
        ("beta_low", "beta_mid", "beta_high", "beta_very_high"))
    return join((genome.family, closure, genome.symmetry.class, transform,
        coil_location, aspect, beta), "|")
end

function _architecture_key(genome::Genome)
    features = _topology_features(genome)
    closure = features.closed_fraction > 0.95 ? "closed" :
        features.closed_fraction < 0.05 ? "open" : "mixed"
    internal = features.internal_coil_fraction > 0.05 ? "with_internal" : "external_only"
    transform = features.plasma_current_fraction > 0.01 &&
        features.external_transform_fraction > 0.01 ? "mixed_transform" :
        features.plasma_current_fraction > 0.01 ? "plasma_transform" :
        features.external_transform_fraction > 0.01 ? "external_transform" : "no_transform"
    return join((genome.family, closure, transform, internal), "|")
end

function _topology_vector(genome::Genome)
    f = _topology_features(genome)
    return Float64[f.closed_fraction, f.plasma_current_fraction,
        f.external_transform_fraction, f.three_d_fraction, f.internal_coil_fraction,
        min(f.mirror_ratio / 6.0, 1.0), f.plug_strength, f.minimum_b_strength,
        f.shear_strength]
end

function _novelty_from_baselines(genome::Genome, baselines::Vector{Genome})
    vector = _topology_vector(genome)
    distances = [sum(abs.(vector .- _topology_vector(baseline))) / length(vector)
        for baseline in baselines]
    return isempty(distances) ? 0.0 : minimum(distances)
end

function _five_gate_quality_key(record::FiveGateSearchRecord)
    result = record.evaluation
    gates = result["gates"]
    gate_count = count(value -> value === true, values(gates))
    nominal = result["nominal"]
    robustness = result["robustness"]
    volume = max(Float64(nominal["plasma_volume_m3"]), 1.0e-9)
    net_density = Float64(nominal["net_electric_power_W"]) / volume
    return (
        result["all_five_gates_passed"] === true ? 0 : 1,
        -gate_count,
        -Float64(robustness["pass_fraction"]),
        -Float64(nominal["minimum_normalized_margin"]),
        -net_density,
        -Float64(nominal["minimum_stability_margin_proxy"]),
        Float64(result["device_complexity_proxy"]),
        -record.novelty_from_baselines,
        record.genome.physics_hash,
    )
end

function _insert_five_gate!(archive::FiveGateQDArchive, record::FiveGateSearchRecord)
    record.genome.physics_hash in archive.seen_hashes && return :duplicate
    push!(archive.seen_hashes, record.genome.physics_hash)
    incumbent = get(archive.cells, record.descriptor, nothing)
    if incumbent === nothing || _five_gate_quality_key(record) < _five_gate_quality_key(incumbent)
        archive.cells[record.descriptor] = record
        return :inserted
    end
    return :discarded
end

function _make_five_gate_record(evaluator::UnifiedCrossFamilyScreenV1, genome::Genome,
        baseline_genomes::Vector{Genome}; is_baseline::Bool = false)
    evaluation = _unified_screen_result(evaluator, genome)
    return FiveGateSearchRecord(genome, five_gate_descriptor(genome),
        _architecture_key(genome), evaluation, is_baseline,
        is_baseline ? 0.0 : _novelty_from_baselines(genome, baseline_genomes))
end

function _select_prototypes(records::Vector{FiveGateSearchRecord}; maximum::Int = 10)
    passing = filter(record ->
        record.evaluation["all_five_gates_passed"] === true && !record.is_baseline, records)
    best_by_architecture = Dict{String,FiveGateSearchRecord}()
    for record in passing
        incumbent = get(best_by_architecture, record.architecture, nothing)
        if incumbent === nothing || _five_gate_quality_key(record) < _five_gate_quality_key(incumbent)
            best_by_architecture[record.architecture] = record
        end
    end
    candidates = collect(values(best_by_architecture))
    sort!(candidates; by = record -> (
        -record.novelty_from_baselines,
        _five_gate_quality_key(record),
    ))
    return first(candidates, min(maximum, length(candidates)))
end

function run_five_gate_qd(seeds::Vector{Genome}; iterations::Int = 5000,
        random_seed::Int = 20260811,
        contract::CommonComparisonContract = default_common_comparison_contract(),
        maximum_prototypes::Int = 10)
    iterations >= 0 || throw(ArgumentError("iterations must be non-negative"))
    rng = MersenneTwister(random_seed)
    evaluator = UnifiedCrossFamilyScreenV1(contract)
    baseline_genomes = _common_baseline_genomes(seeds, contract)
    archive = FiveGateQDArchive()
    baselines = FiveGateSearchRecord[]
    discovered = FiveGateSearchRecord[]
    for genome in baseline_genomes
        record = _make_five_gate_record(evaluator, genome, baseline_genomes;
            is_baseline = true)
        _insert_five_gate!(archive, record)
        push!(baselines, record)
        push!(discovered, record)
    end
    doe_genomes = _common_doe_anchor_genomes(baseline_genomes, contract)
    for genome in doe_genomes
        record = _make_five_gate_record(evaluator, genome, baseline_genomes)
        _insert_five_gate!(archive, record)
        push!(discovered, record)
    end
    topology_doe_genomes = _common_topology_doe_anchor_genomes(
        baseline_genomes, contract)
    for genome in topology_doe_genomes
        record = _make_five_gate_record(evaluator, genome, baseline_genomes)
        _insert_five_gate!(archive, record)
        push!(discovered, record)
    end
    rules = discovery_graph_rules_v2()
    rejected = 0
    duplicates = 0
    rejection_reasons = Dict{String,Int}()
    for _ in 1:iterations
        parents = collect(values(archive.cells))
        isempty(parents) && break
        sort!(parents; by = record -> record.genome.physics_hash)
        parent = rand(rng, parents).genome
        available = filter(rule -> applicable_rule(rule, parent), rules)
        sort!(available; by = rule -> rule.id)
        if isempty(available)
            rejected += 1
            rejection_reasons["no_applicable_grammar_rule"] =
                get(rejection_reasons, "no_applicable_grammar_rule", 0) + 1
            continue
        end
        parameter_rules = filter(rule ->
            rule.id == "common_envelope_parameter_resample", available)
        topology_rules = filter(rule ->
            rule.id != "common_envelope_parameter_resample", available)
        rule = if !isempty(parameter_rules) &&
                (isempty(topology_rules) || rand(rng) < 0.65)
            only(parameter_rules)
        else
            rand(rng, topology_rules)
        end
        try
            candidate = _synchronize_common_envelope(
                apply_rule(rule, parent, rng), contract; id_prefix = "concept")
            family = validate_family(default_family_registry(), candidate)
            family.valid || error(join(family.errors, "; "))
            record = _make_five_gate_record(evaluator, candidate, baseline_genomes)
            outcome = _insert_five_gate!(archive, record)
            if outcome == :duplicate
                duplicates += 1
            elseif all(item -> item.genome.physics_hash != candidate.physics_hash, discovered)
                push!(discovered, record)
            end
        catch error
            rejected += 1
            message = sprint(showerror, error)
            key = first(split(message, ':'; limit = 2))
            rejection_reasons[key] = get(rejection_reasons, key, 0) + 1
        end
    end
    sort!(discovered; by = record -> record.genome.physics_hash)
    prototypes = _select_prototypes(discovered; maximum = maximum_prototypes)
    return FiveGateSearchResult(archive, baselines, discovered, prototypes,
        iterations, rejected, duplicates, random_seed, iterations, contract,
        rejection_reasons)
end

function _promotion_tasks(record::FiveGateSearchRecord)
    family = record.genome.family
    physics_tasks = if family == "tokamak_axisymmetric"
        ["free_boundary_grad_shafranov", "ideal_mhd_stability", "orbit_and_transport"]
    elseif family in ("stellarator", "tokamak_3d_hybrid")
        ["three_dimensional_mhd_equilibrium", "field_line_and_orbit_following",
            "finite_build_coil_inverse_design"]
    elseif family == "magnetic_mirror"
        ["anisotropic_mirror_equilibrium", "fokker_planck_end_loss",
            "interchange_and_microstability"]
    elseif family == "closed_open_hybrid"
        ["coupled_closed_open_equilibrium", "separatrix_field_line_mapping",
            "kinetic_open_end_loss"]
    else
        ["family_specific_equilibrium", "family_specific_stability_and_transport"]
    end
    return Dict{String,Any}(
        "status" => "queued_not_yet_validated",
        "blocking_mid_fidelity_tasks" => vcat(physics_tasks, [
            "reduced_support_stress", "power_balance_with_exhaust", "robust_geometry_errors"]),
        "nonblocking_background_tasks" => [
            "high_resolution_internal_field_if_3d_coils_survive",
            "material_critical_surface", "thermal_and_quench", "neutronics_and_maintenance"],
        "claim_boundary" => "Promotion is a work queue, not evidence that the candidate passed medium fidelity.",
    )
end

function _five_gate_record_to_dict(record::FiveGateSearchRecord; include_genome::Bool = false)
    result = Dict{String,Any}(
        "design_id" => record.genome.design_id,
        "physics_hash" => record.genome.physics_hash,
        "family" => record.genome.family,
        "descriptor" => record.descriptor,
        "architecture" => record.architecture,
        "is_baseline" => record.is_baseline,
        "novelty_from_nearest_baseline" => record.novelty_from_baselines,
        "novel_topology_candidate" => record.novelty_from_baselines >= 0.15,
        "parent_design_ids" => record.genome.provenance.parent_design_ids,
        "grammar_notes" => filter(note -> startswith(note, "grammar_rule:"),
            record.genome.provenance.notes),
        "evaluation" => record.evaluation,
    )
    include_genome && (result["genome"] = record.genome.normalized)
    return result
end

function _near_frontier_rejections(records::Vector{FiveGateSearchRecord}; maximum::Int = 8)
    best_by_architecture = Dict{String,FiveGateSearchRecord}()
    for record in records
        record.is_baseline && continue
        record.novelty_from_baselines >= 0.15 || continue
        record.evaluation["all_five_gates_passed"] === true && continue
        incumbent = get(best_by_architecture, record.architecture, nothing)
        if incumbent === nothing || _five_gate_quality_key(record) < _five_gate_quality_key(incumbent)
            best_by_architecture[record.architecture] = record
        end
    end
    candidates = collect(values(best_by_architecture))
    sort!(candidates; by = _five_gate_quality_key)
    return first(candidates, min(maximum, length(candidates)))
end

function five_gate_search_to_dict(result::FiveGateSearchResult)
    archive_records = collect(values(result.archive.cells))
    sort!(archive_records; by = record -> record.descriptor)
    gate_failure_counts = Dict{String,Int}()
    for record in result.discovered
        for (gate, passed) in record.evaluation["gates"]
            passed === true && continue
            gate_failure_counts[gate] = get(gate_failure_counts, gate, 0) + 1
        end
    end
    near_frontier = _near_frontier_rejections(result.discovered)
    payload = Dict{String,Any}(
        "search_version" => "cross_family_five_gate_qd_v1",
        "algorithm" => "MAP-Elites-style attributed-graph grammar with five-gate lexicographic selection",
        "stage" => "common_low_fidelity_discovery_and_promotion_queue",
        "claim_boundary" => _UNIFIED_SCREEN_CLAIM_BOUNDARY,
        "contract" => _common_contract_dict(result.contract),
        "contract_hash" => canonical_hash(_common_contract_dict(result.contract)),
        "random_seed" => result.random_seed,
        "iterations" => result.iterations,
        "attempts" => result.attempts,
        "rejected" => result.rejected,
        "duplicates" => result.duplicates,
        "archive_cell_count" => length(archive_records),
        "discovered_unique_count" => length(result.discovered),
        "common_doe_anchor_count" => count(record ->
            startswith(record.genome.design_id, "doe_"), result.discovered),
        "topology_doe_anchor_count" => count(record ->
            startswith(record.genome.design_id, "topology_doe_"), result.discovered),
        "five_gate_pass_count" => count(record ->
            record.evaluation["all_five_gates_passed"] === true, result.discovered),
        "prototype_count" => length(result.prototypes),
        "novel_prototype_count" => count(record ->
            record.novelty_from_baselines >= 0.15, result.prototypes),
        "gate_failure_counts" => gate_failure_counts,
        "grammar_rejection_reasons" => result.rejection_reasons,
        "baselines" => [_five_gate_record_to_dict(record; include_genome = true)
            for record in result.baselines],
        "prototypes" => [merge(_five_gate_record_to_dict(record; include_genome = true),
            Dict("promotion" => _promotion_tasks(record))) for record in result.prototypes],
        "near_frontier_rejections" => [merge(_five_gate_record_to_dict(record), Dict(
            "failed_gates" => sort!(String[gate for (gate, passed) in
                record.evaluation["gates"] if passed !== true]),
            "promotion" => Dict("status" => "not_promoted")))
            for record in near_frontier],
        "archive" => [_five_gate_record_to_dict(record) for record in archive_records],
        "background_evidence_policy" => Dict(
            "blocking_for_search" => false,
            "tasks" => ["high_resolution_internal_field", "material_critical_surface",
                "detailed_support_stress", "thermal_and_quench"],
            "rule" => "Only run expensive vertical evidence after a candidate survives all five horizontal gates.",
        ),
    )
    payload["result_hash"] = canonical_hash(payload)
    return payload
end
