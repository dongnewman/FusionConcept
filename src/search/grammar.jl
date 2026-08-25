struct GraphRule
    id::String
    description::String
    parent_families::Set{String}
    source_ids::Vector{String}
    guard::Function
    transform!::Function
end

function _graph_rule(id, description, parent_families, source_ids, guard, transform!)
    return GraphRule(String(id), String(description), Set(String.(parent_families)),
        String.(source_ids), guard, transform!)
end

applicable_rule(rule::GraphRule, genome::Genome) =
    genome.family in rule.parent_families && rule.guard(genome)

function _raw_entity(raw, collection, id)
    matches = filter(item -> item["id"] == id, raw[collection])
    length(matches) == 1 || error("expected one $collection entity named $id")
    return only(matches)
end

function _raw_entity_by_kind(raw, collection, kind)
    matches = filter(item -> item["kind"] == kind, raw[collection])
    length(matches) == 1 || error("expected one $collection entity of kind $kind")
    return only(matches)
end

function _push_unique!(items, values)
    for value in values
        value in items || push!(items, value)
    end
    return items
end

function _has_entity(genome::Genome, collection::Symbol, id::String)
    return any(item -> item.id == id, getfield(genome, collection))
end

function _finish_rule(raw, parent::Genome, rule::GraphRule)
    provenance = raw["provenance"]
    provenance["origin"] = "generated"
    provenance["parent_design_ids"] = [parent.design_id]
    provenance["claim_level"] = "structural_example"
    _push_unique!(provenance["source_ids"], rule.source_ids)
    notes = get!(provenance, "notes", Any[])
    push!(notes, "grammar_rule:$(rule.id)")
    push!(notes, "Structural proposal only; performance objectives remain unevaluated.")
    raw["design_id"] = "pending_candidate"
    raw["label"] = "Generated concept via $(rule.id)"
    provisional = parse_genome(raw)
    raw["design_id"] = "concept_$(provisional.physics_hash[1:20])"
    return parse_genome(raw)
end

function apply_rule(rule::GraphRule, genome::Genome, rng::AbstractRNG)
    applicable_rule(rule, genome) ||
        throw(ArgumentError("rule $(rule.id) is not applicable to $(genome.design_id)"))
    raw = deepcopy(genome.normalized)
    rule.transform!(raw, rng)
    candidate = _finish_rule(raw, genome, rule)
    report = validate_genome(candidate)
    report.valid || error("rule $(rule.id) produced invalid genome: $(join(report.errors, "; "))")
    return candidate
end

function _tokamak_hybrid_transform!(raw, rng)
    plasma_fraction = rand(rng, (0.35, 0.50, 0.65, 0.80))
    external_fraction = 1.0 - plasma_fraction
    periods = rand(rng, 2:4)
    raw["family"] = "tokamak_3d_hybrid"
    raw["topology"]["rotation_transform_sources"] =
        ["plasma_current", "three_dimensional_external_field"]
    raw["symmetry"]["class"] = "quasi_axisymmetric"
    raw["symmetry"]["field_periods"] = periods
    _push_unique!(raw["symmetry"]["hard_constraints"],
        ["quasi-axisymmetric error bound", "finite-build 3D coil clearance"])
    raw["mission"]["targets"]["plasma_current"] = Dict(
        "value" => 15.0e6 * plasma_fraction, "unit" => "A",
        "basis" => "grammar scan of plasma-current transform fraction")
    raw["mission"]["targets"]["screen_plasma_current_transform_fraction"] = Dict(
        "value" => plasma_fraction, "unit" => "1",
        "basis" => "tokamak external-transform grammar")
    raw["mission"]["targets"]["screen_external_transform_fraction"] = Dict(
        "value" => external_fraction, "unit" => "1",
        "basis" => "tokamak external-transform grammar")
    raw["mission"]["targets"]["screen_three_dimensional_field_fraction"] = Dict(
        "value" => max(external_fraction, 0.50), "unit" => "1",
        "basis" => "tokamak external-transform grammar")
    plasma = _raw_entity(raw, "field_sources", "tokamak_plasma_current")
    plasma["parameters"]["total_current"] =
        Dict("value" => 15.0e6 * plasma_fraction, "unit" => "A")
    push!(raw["field_sources"], Dict{String,Any}(
        "id" => "hybrid_3d_transform_coils",
        "kind" => "three_dimensional_modular_coil",
        "geometry_model" => "near_axis_quasi_axisymmetric_transform_coils",
        "parameters" => Dict(
            "coil_count" => Dict("value" => 4 * periods, "unit" => "1"),
            "field_periods" => Dict("value" => periods, "unit" => "1"),
            "external_transform_fraction_gene" =>
                Dict("value" => external_fraction, "unit" => "1"),
        ),
        "material" => "conceptual superconducting winding",
    ))
    push!(raw["stability_mechanisms"], Dict{String,Any}(
        "id" => "hybrid_quasi_axisymmetry_mechanism",
        "mechanism" => "quasi_symmetry",
        "target_modes" => ["collisionless radial drift", "plasma-current disruption burden"],
        "actuator_ids" => Any[],
        "assumptions" => [
            "external transform and plasma-current profiles admit a common equilibrium",
            "quasi-axisymmetric error remains small with finite-build coils and ports",
        ],
        "required_evaluators" => [
            "vmec_or_desc", "free_boundary_grad_shafranov", "boozer_transform",
            "alpha_orbits", "hybrid_current_profile", "coil_curvature", "coil_separation",
        ],
        "source_ids" => [
            "stellarator_garren_boozer_1991", "stellarator_precise_qs_landreman_paul_2022",
            "simsopt_2021", "desc_part3_2023",
        ],
    ))
    engineering = raw["engineering"]
    _push_unique!(engineering["magnet_technology"], ["three-dimensional transform coils"])
    _push_unique!(engineering["required_evaluators"],
        ["coil_curvature", "coil_separation", "port_access", "assembly_tolerance"])
end

function _tokamak_high_field_transform!(raw, rng)
    field_T = rand(rng, (8.0, 10.0, 12.0))
    raw["mission"]["targets"]["on_axis_field"] = Dict(
        "value" => field_T, "unit" => "T",
        "basis" => "high-field REBCO structural search gene")
    tf = _raw_entity(raw, "field_sources", "tokamak_tf_system")
    tf["parameters"]["on_axis_field"] = Dict("value" => field_T, "unit" => "T")
    tf["material"] = "conceptual REBCO demountable winding"
    engineering = raw["engineering"]
    engineering["maintenance"]["architecture"] = "demountable TF sectors"
    _push_unique!(engineering["maintenance"]["access_paths"],
        ["demountable TF joint", "replaceable blanket sector"])
    _push_unique!(engineering["magnet_technology"], ["demountable REBCO TF coils"])
    _push_unique!(engineering["required_evaluators"],
        ["demountable_joint", "joint_cryogenic_load", "nuclear_heating"])
end

function _stellarator_variant_transform!(raw, rng)
    current_class = raw["symmetry"]["class"]
    choices = filter(!=(current_class),
        ["quasi_axisymmetric", "quasi_helical", "quasi_isodynamic"])
    symmetry = rand(rng, choices)
    periods = rand(rng, 2:6)
    coils_per_period = rand(rng, (6, 8, 10, 12))
    raw["symmetry"]["class"] = symmetry
    raw["symmetry"]["field_periods"] = periods
    raw["symmetry"]["hard_constraints"] =
        ["finite field-period symmetry", "finite-build coil curvature and separation"]
    coils = _raw_entity(raw, "field_sources", "w7x_nonplanar_coils")
    coils["parameters"]["coil_count"] =
        Dict("value" => periods * coils_per_period, "unit" => "1")
    coils["parameters"]["unique_coils_per_period_gene"] =
        Dict("value" => max(2, coils_per_period ÷ 2), "unit" => "1")
    mechanism = raw["stability_mechanisms"][1]
    if symmetry == "quasi_isodynamic"
        mechanism["mechanism"] = "omnigenity"
        mechanism["source_ids"] = [
            "stellarator_omnigenity_landreman_catto_2012", "w7x_neoclassical_transport_2021"]
    else
        mechanism["mechanism"] = "quasi_symmetry"
        mechanism["source_ids"] = [
            "stellarator_garren_boozer_1991", "stellarator_precise_qs_landreman_paul_2022"]
    end
    mechanism["required_evaluators"] = [
        "vmec_or_desc", "boozer_transform", "neoclassical_transport", "alpha_orbits"]
    engineering = raw["engineering"]
    _push_unique!(engineering["required_evaluators"],
        ["finite_build_coils", "blanket_clearance", "port_access", "remote_maintenance"])
end

function _mirror_minimum_b_transform!(raw, rng)
    coil_count = rand(rng, (4, 6, 8))
    raw["symmetry"]["class"] = "minimum_b"
    _push_unique!(raw["symmetry"]["hard_constraints"],
        ["paired end minimum-B wells", "central-cell accessibility"])
    push!(raw["field_sources"], Dict{String,Any}(
        "id" => "mirror_minimum_b_set",
        "kind" => "minimum_b_coil",
        "geometry_model" => "paired_finite_build_minimum_b_anchor_coils",
        "parameters" => Dict("coil_count" => Dict("value" => coil_count, "unit" => "1")),
        "material" => "conceptual superconducting winding",
    ))
    push!(raw["stability_mechanisms"], Dict{String,Any}(
        "id" => "mirror_minimum_b_mechanism",
        "mechanism" => "minimum_b",
        "target_modes" => ["interchange", "flute"],
        "actuator_ids" => Any[],
        "assumptions" => [
            "finite-beta anisotropic equilibrium retains an average magnetic well",
            "anchor losses and coil end fields are included in power balance",
        ],
        "required_evaluators" => [
            "anisotropic_equilibrium", "interchange_growth", "anchor_end_loss", "full_orbit"],
        "source_ids" => ["mirror_tandem_fowler_logan_1977", "mirror_post_review_1987"],
    ))
    _push_unique!(raw["engineering"]["required_evaluators"],
        ["minimum_b_coil_forces", "end_region_access"])
end

function _mirror_tandem_transform!(raw, rng)
    plug_field = rand(rng, (12.0, 16.0, 20.0))
    plug_power = rand(rng, (1.0e6, 2.0e6, 4.0e6))
    central_id = _raw_entity_by_kind(raw, "plasma_regions", "mirror_central_cell")["id"]
    expanders = sort!(String[item["id"] for item in raw["plasma_regions"]
        if item["kind"] == "end_expander"])
    length(expanders) == 2 || error("tandem rule requires exactly two end expanders")
    sides = (("left", expanders[1]), ("right", expanders[2]))
    for (side, _) in sides
        plug_id = "mirror_$(side)_plug"
        push!(raw["plasma_regions"], Dict{String,Any}(
            "id" => plug_id,
            "kind" => "mirror_plug_or_anchor",
            "geometry_model" => "anisotropic_ambipolar_plug",
            "parameters" => Dict("peak_field" => Dict("value" => plug_field, "unit" => "T")),
        ))
        actuator_id = "mirror_$(side)_plug_ech"
        push!(raw["actuators"], Dict{String,Any}(
            "id" => actuator_id,
            "kind" => "ech",
            "parameters" => Dict("power" => Dict("value" => plug_power, "unit" => "W")),
        ))
    end
    raw["flux_connections"] = Any[item for item in raw["flux_connections"]
        if !(item["from_region_id"] == central_id && item["to_region_id"] in expanders)]
    for (side, expander) in sides
        plug_id = "mirror_$(side)_plug"
        push!(raw["flux_connections"], Dict(
            "from_region_id" => central_id, "to_region_id" => plug_id,
            "kind" => "open_field_line"))
        push!(raw["flux_connections"], Dict(
            "from_region_id" => plug_id, "to_region_id" => expander,
            "kind" => "open_field_line"))
    end
    push!(raw["field_sources"], Dict{String,Any}(
        "id" => "mirror_plug_coils",
        "kind" => "mirror_coil",
        "geometry_model" => "paired_high_field_plug_coils",
        "parameters" => Dict(
            "coil_count" => Dict("value" => 4, "unit" => "1"),
            "peak_field" => Dict("value" => plug_field, "unit" => "T"),
        ),
        "material" => "conceptual REBCO high-field winding",
    ))
    push!(raw["stability_mechanisms"], Dict{String,Any}(
        "id" => "mirror_ambipolar_plugging_mechanism",
        "mechanism" => "other",
        "target_modes" => ["electron end loss", "ion end loss", "central-cell axial loss"],
        "actuator_ids" => ["mirror_left_plug_ech", "mirror_right_plug_ech"],
        "assumptions" => [
            "plug electron temperature sustains the required ambipolar potential",
            "plug heating and end recovery are included in net power",
        ],
        "required_evaluators" => [
            "fokker_planck", "ambipolar_potential", "plug_microstability",
            "electron_heat_loss", "actuator_power"],
        "source_ids" => ["mirror_tandem_fowler_logan_1977", "mirror_post_review_1987"],
    ))
    raw["engineering"]["maintenance"]["architecture"] = "linear central cell with replaceable end plugs"
    _push_unique!(raw["engineering"]["required_evaluators"],
        ["plug_coil_forces", "plug_neutral_shielding", "end_energy_recovery"])
end

function _mirror_gdt_transform!(raw, rng)
    cell = _raw_entity_by_kind(raw, "plasma_regions", "mirror_central_cell")
    cell["geometry_model"] = "collisional_gas_dynamic_central_cell"
    cell["parameters"]["cell_length"] =
        Dict("value" => rand(rng, (12.0, 20.0, 35.0, 50.0)), "unit" => "m")
    cell["parameters"]["mirror_ratio_gene"] =
        Dict("value" => rand(rng, (10.0, 15.0, 20.0, 30.0)), "unit" => "1")
    push!(raw["stability_mechanisms"], Dict{String,Any}(
        "id" => "mirror_gas_dynamic_regime_mechanism",
        "mechanism" => "finite_larmor_radius",
        "target_modes" => ["loss-cone anisotropy", "short-wavelength interchange"],
        "actuator_ids" => Any[],
        "assumptions" => [
            "central-cell length exceeds the ion scattering mean free path",
            "velocity distribution remains sufficiently close to isotropic Maxwellian",
        ],
        "required_evaluators" => [
            "collisionality", "fokker_planck", "gas_dynamic_end_loss", "interchange_growth"],
        "source_ids" => ["mirror_gdt_neutron_source_2004"],
    ))
end

function _tokamak_high_field_applicable(genome)
    sources = filter(item -> item.id == "tokamak_tf_system", genome.field_sources)
    return length(sources) == 1 && !occursin("REBCO", only(sources).material)
end

function default_graph_rules()
    return GraphRule[
        _graph_rule(
            "tokamak_external_transform",
            "Move part of the rotational-transform burden from plasma current to a QA external field.",
            ["tokamak_axisymmetric"],
            ["stellarator_garren_boozer_1991", "stellarator_precise_qs_landreman_paul_2022",
                "simsopt_2021", "desc_part3_2023"],
            genome -> !_has_entity(genome, :field_sources, "hybrid_3d_transform_coils"),
            _tokamak_hybrid_transform!),
        _graph_rule(
            "tokamak_demountable_high_field",
            "Introduce a high-field demountable REBCO TF architecture as an engineering trade.",
            ["tokamak_axisymmetric", "tokamak_3d_hybrid"],
            ["arc_sorbom_2015"],
            _tokamak_high_field_applicable,
            _tokamak_high_field_transform!),
        _graph_rule(
            "stellarator_symmetry_family",
            "Explore QA, QH, and QI symmetry families with finite coil-period genes.",
            ["stellarator"],
            ["stellarator_omnigenity_landreman_catto_2012",
                "stellarator_precise_qs_landreman_paul_2022", "stellarator_precise_qs_coils_2022"],
            genome -> _has_entity(genome, :field_sources, "w7x_nonplanar_coils"),
            _stellarator_variant_transform!),
        _graph_rule(
            "mirror_minimum_b_anchors",
            "Pay finite-build coil complexity for explicit minimum-B interchange stabilization.",
            ["magnetic_mirror"],
            ["mirror_tandem_fowler_logan_1977", "mirror_post_review_1987"],
            genome -> !_has_entity(genome, :field_sources, "mirror_minimum_b_set"),
            _mirror_minimum_b_transform!),
        _graph_rule(
            "mirror_tandem_ambipolar_plugs",
            "Add paired heated plugs and explicit axial-loss power accounting requirements.",
            ["magnetic_mirror"],
            ["mirror_tandem_fowler_logan_1977", "mirror_post_review_1987"],
            genome -> !_has_entity(genome, :plasma_regions, "mirror_left_plug"),
            _mirror_tandem_transform!),
        _graph_rule(
            "mirror_gas_dynamic_regime",
            "Explore a collisional gas-dynamic central-cell regime with explicit validity assumptions.",
            ["magnetic_mirror"],
            ["mirror_gdt_neutron_source_2004"],
            genome -> !any(item -> item.id == "mirror_gas_dynamic_regime_mechanism",
                genome.stability_mechanisms),
            _mirror_gdt_transform!),
    ]
end

function known_source_ids(path::AbstractString)
    data = _plain_json(JSON3.read(read(path, String), Dict{String,Any}))
    return Set(String(item["id"]) for item in data["sources"])
end

function source_reference_errors(genome::Genome, known_ids::Set{String})
    referenced = Set(genome.provenance.source_ids)
    for mechanism in genome.stability_mechanisms
        union!(referenced, mechanism.source_ids)
    end
    return sort!(String[id for id in referenced if !(id in known_ids)])
end
