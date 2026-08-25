const _V17_LAYERS = (:core, :field_source, :stability, :exhaust, :engineering)

"One evidence-linked module in the five-layer topology attribute grammar."
struct TopologyModuleV17
    id::String
    layer::Symbol
    description::String
    provides::Set{String}
    requires_all::Set{String}
    requires_any::Vector{Set{String}}
    forbids::Set{String}
    source_ids::Vector{String}
    required_evaluators::Vector{String}

    function TopologyModuleV17(id::AbstractString, layer::Symbol,
            description::AbstractString, provides, requires_all, requires_any,
            forbids, source_ids, required_evaluators)
        layer in _V17_LAYERS ||
            throw(ArgumentError("unknown v17 topology layer $layer"))
        module_id = String(id)
        isempty(module_id) && throw(ArgumentError("v17 module ID must not be empty"))
        supplied = Set(String.(collect(provides)))
        isempty(supplied) && throw(ArgumentError(
            "v17 module $module_id must provide at least one tag"))
        all_required = Set(String.(collect(requires_all)))
        any_required = [Set(String.(collect(group))) for group in requires_any]
        any(isempty, any_required) && throw(ArgumentError(
            "v17 module $module_id has an empty requires-any group"))
        prohibited = Set(String.(collect(forbids)))
        isempty(intersect(supplied, prohibited)) || throw(ArgumentError(
            "v17 module $module_id both provides and forbids a tag"))
        sources = sort!(unique(String.(collect(source_ids))))
        isempty(sources) && throw(ArgumentError(
            "v17 module $module_id must cite at least one source"))
        evaluators = sort!(unique(String.(collect(required_evaluators))))
        isempty(evaluators) && throw(ArgumentError(
            "v17 module $module_id must declare evaluator needs"))
        return new(module_id, layer, String(description), supplied, all_required,
            any_required, prohibited, sources, evaluators)
    end
end

struct TopologyDependencyEdgeV17
    from_module_id::String
    to_module_id::String
    supplied_tag::String
end

struct TopologyAssemblyValidationV17
    valid::Bool
    reason_codes::Vector{String}
    tags::Vector{String}
    edges::Vector{TopologyDependencyEdgeV17}
end

"A C0-only structural hypothesis. No physical or engineering gate is credited."
struct TopologyAssemblyV17
    assembly_id::String
    family::String
    mission_contract_id::String
    module_ids::Vector{String}
    tags::Vector{String}
    edges::Vector{TopologyDependencyEdgeV17}
    source_ids::Vector{String}
    missing_required_evaluators::Vector{String}
    structural_descriptor::String
    graph_hash::String
end

struct AttributeGraphGrammarResultV17
    catalog::Vector{TopologyModuleV17}
    compatible_assembly_count::Int
    compatible_family_counts::Dict{String,Int}
    archive::Vector{TopologyAssemblyV17}
    archive_family_counts::Dict{String,Int}
    partial_extension_attempt_count::Int
    rejected_partial_extension_count::Int
    rejection_reason_counts::Dict{String,Int}
    rejection_samples::Vector{Dict{String,Any}}
    catalog_hash::String
    claim_boundary::String
end

function _v17_module(id, layer, description, provides;
        requires = String[], requires_any = Vector{Vector{String}}(),
        forbids = String[], sources = String[], evaluators = String[])
    return TopologyModuleV17(id, layer, description, provides, requires,
        requires_any, forbids, sources, evaluators)
end

_v17_family_tag(family) = "family:$(String(family))"
_v17_family_group(families) = [[_v17_family_tag(family) for family in families]]

function _v17_union_tags(modules::Vector{TopologyModuleV17})
    tags = Set{String}()
    for module_spec in modules
        union!(tags, module_spec.provides)
    end
    return tags
end

"Evidence-linked module catalog. Repeated constructors encode modules, not full paths."
function default_topology_module_catalog_v17()
    modules = TopologyModuleV17[]
    add(args...; kwargs...) = push!(modules, _v17_module(args...; kwargs...))

    function core(id, family, description, topology_tags, source, evaluators;
            operating = "steady", contract = "net_electric_steady-state_v1")
        add(id, :core, description,
            vcat(["layer:core", _v17_family_tag(family),
                "operating:$operating", "contract:$contract", "core:$id"],
                topology_tags); sources = [source], evaluators = evaluators)
    end
    core("tokamak_conventional", "tokamak_axisymmetric",
        "Axisymmetric closed-separatrix tokamak with plasma-current transform.",
        ["device:magnetic", "topology:closed_toroidal", "topology:separatrix",
            "symmetry:axisymmetric", "transform:plasma_current",
            "coil_location:external"], "tokamak_iter_physics_basis_1999",
        ["free_boundary_grad_shafranov", "ideal_mhd"])
    core("tokamak_spherical", "tokamak_axisymmetric",
        "Low-aspect-ratio axisymmetric tokamak with plasma-current transform.",
        ["device:magnetic", "topology:closed_toroidal", "topology:separatrix",
            "symmetry:axisymmetric", "transform:plasma_current",
            "coil_location:external", "geometry:low_aspect_ratio"],
        "spherical_torus_peng_1986",
        ["free_boundary_grad_shafranov", "vertical_stability"])
    core("tokamak_qa_hybrid", "tokamak_3d_hybrid",
        "Closed torus sharing transform between current and a 3D QA field.",
        ["device:magnetic", "topology:closed_toroidal", "topology:separatrix",
            "symmetry:3d", "symmetry:quasi_axisymmetric",
            "transform:plasma_current", "transform:external_3d",
            "coil_location:external"], "ncsx_physics_zarnstorff_2001",
        ["coupled_free_boundary_equilibrium", "hybrid_current_profile"])
    for (id, symmetry, source) in (
            ("stellarator_qa", "quasi_axisymmetric",
                "stellarator_garren_boozer_1991"),
            ("stellarator_qh", "quasi_helical",
                "stellarator_nuhrenberg_zille_1988"),
            ("stellarator_qi", "quasi_isodynamic",
                "stellarator_omnigenity_landreman_catto_2012"))
        core(id, "stellarator", "Externally transformed 3D $symmetry torus.",
            ["device:magnetic", "topology:closed_toroidal", "symmetry:3d",
                "symmetry:$symmetry", "transform:external_3d",
                "coil_location:external"], source,
            ["vmec_or_desc", "boozer_transform"])
    end
    core("mirror_single_cell", "magnetic_mirror",
        "Finite open mirror central cell with two explicit axial loss ends.",
        ["device:magnetic", "topology:open_mirror", "topology:two_open_ends",
            "symmetry:axisymmetric", "transform:not_applicable",
            "coil_location:external"], "mirror_wham_physics_basis_2023",
        ["anisotropic_mirror_equilibrium", "open_end_loss"])
    core("mirror_multicell", "magnetic_mirror",
        "Open mirror line with finite repeated multiple-mirror cells.",
        ["device:magnetic", "topology:open_mirror", "topology:two_open_ends",
            "symmetry:axisymmetric", "transform:not_applicable",
            "coil_location:external", "geometry:multiple_mirror_cells"],
        "multiple_mirror_logan_1974",
        ["multiple_mirror_kinetics", "open_end_loss"])
    core("frc", "field_reversed_configuration",
        "Field-reversed compact toroid with an explicit open SOL.",
        ["device:magnetic", "topology:compact_toroid", "topology:open_sol",
            "symmetry:axisymmetric", "transform:self_organized",
            "coil_location:external"], "frc_steinhauer_review_2011",
        ["two_fluid_or_hybrid_frc", "separatrix_transport"])
    core("spheromak", "spheromak",
        "Self-organized spheromak in a finite flux conserver with open SOL.",
        ["device:magnetic", "topology:compact_toroid", "topology:open_sol",
            "symmetry:axisymmetric", "transform:self_organized",
            "coil_location:external", "hardware:electrodes"],
        "spheromak_jarboe_review_1994",
        ["resistive_mhd_spheromak", "helicity_balance"])
    core("rfp", "reversed_field_pinch",
        "Reversed-field pinch torus with a self-organized current profile.",
        ["device:magnetic", "topology:closed_toroidal",
            "symmetry:axisymmetric", "transform:plasma_current",
            "transform:self_organized", "coil_location:external"],
        "rfp_reactor_1981", ["resistive_mhd_rfp", "profile_relaxation"])
    core("sheared_z_pinch", "sheared_flow_z_pinch",
        "Open linear current channel with finite electrodes and axial flow.",
        ["device:magnetic", "topology:open_linear", "topology:two_open_ends",
            "symmetry:axisymmetric", "transform:not_applicable",
            "coil_location:external", "hardware:electrodes"],
        "zpinch_shear_shumlak_hartman_1995",
        ["resistive_mhd_with_axial_flow", "electrode_sheath"])
    core("mtf", "magnetized_target_fusion",
        "Magnetized compact target explicitly compressed in a pulsed chamber.",
        ["device:magnetic", "topology:compact_toroid",
            "topology:pulsed_chamber", "symmetry:axisymmetric",
            "transform:self_organized", "coil_location:external",
            "hardware:compression_driver"], "mtf_overview_kirkpatrick_1995",
        ["liner_target_radiation_mhd", "target_formation"];
        operating = "pulsed", contract = "net_electric_pulsed_v1")
    core("levitated_dipole", "levitated_dipole",
        "Closed dipole flux surfaces around an internal coil.",
        ["device:magnetic", "topology:closed_dipole",
            "symmetry:axisymmetric", "transform:not_applicable",
            "coil_location:internal"], "dipole_ldx_design_garnier_2006",
        ["finite_beta_dipole_equilibrium", "internal_coil_heat_load"])
    core("laser_icf", "inertial_confinement_fusion",
        "Inertial D-T capsule, target factory, and pulsed chamber.",
        ["device:inertial", "topology:inertial_capsule",
            "topology:pulsed_chamber", "symmetry:not_applicable",
            "transform:not_applicable", "coil_location:not_applicable",
            "hardware:target_factory"], "ife_assessment_nas_2013",
        ["icf_radiation_hydrodynamics", "target_factory_and_injection"];
        operating = "pulsed", contract = "net_electric_pulsed_v1")

    function field(id, families, description, provides, source, evaluators;
            requires = String[])
        add(id, :field_source, description,
            vcat(["layer:field_source", "field_source:declared"], provides);
            requires = requires, requires_any = _v17_family_group(families),
            sources = [source], evaluators = evaluators)
    end
    field("tokamak_tf_pf_cs", ["tokamak_axisymmetric"],
        "Fixed external TF/PF/CS superconducting system.",
        ["field:external_axisymmetric", "hardware:tf_pf",
            "hardware:central_solenoid"], "tokamak_iter_physics_basis_1999",
        ["finite_build_coils", "pf_cs_flux_swing"])
    field("tokamak_demountable_rebco", ["tokamak_axisymmetric"],
        "External demountable high-field REBCO TF/PF architecture.",
        ["field:external_axisymmetric", "hardware:tf_pf",
            "hardware:demountable_coils", "material:rebco"], "arc_sorbom_2015",
        ["rebco_critical_surface", "demountable_joint"])
    field("tokamak_compact_tf_pf", ["tokamak_axisymmetric"],
        "Compact TF/PF set without assumed solenoid flux credit.",
        ["field:external_axisymmetric", "hardware:tf_pf",
            "hardware:no_central_solenoid"], "spherical_torus_peng_1986",
        ["noninductive_current_drive", "finite_build_coils"];
        requires = ["geometry:low_aspect_ratio"])
    for (id, programmable, source) in (
            ("hybrid_modular_qa_current", false, "ncsx_physics_zarnstorff_2001"),
            ("hybrid_programmable_qa_current", true,
                "programmable_hybrid_yu_2026_preprint"))
        tags = ["field:external_3d", "field:plasma_current",
            "hardware:3d_transform_coils"]
        programmable && push!(tags, "hardware:programmable_coils")
        field(id, ["tokamak_3d_hybrid"],
            "External 3D transform set plus plasma current.", tags, source,
            ["free_boundary_3d_equilibrium", "hybrid_coil_optimization"])
    end
    for (id, tag, source) in (
            ("stellarator_modular", "hardware:modular_3d_coils",
                "stellarator_precise_qs_coils_2022"),
            ("stellarator_helical", "hardware:helical_coils",
                "stellarator_nuhrenberg_zille_1988"),
            ("stellarator_programmable", "hardware:programmable_coils",
                "programmable_hybrid_yu_2026_preprint"))
        field(id, ["stellarator"], "External 3D stellarator winding architecture.",
            ["field:external_3d", tag], source,
            ["coil_optimization", "finite_build_coils"])
    end
    for (id, provides, requires, source) in (
            ("mirror_solenoidal_plugs", ["field:mirror_solenoidal",
                "hardware:paired_end_coils"], String[],
                "mirror_wham_physics_basis_2023"),
            ("mirror_minimum_b", ["field:mirror_solenoidal", "field:minimum_b",
                "hardware:paired_end_coils"], String[], "mirror_post_review_1987"),
            ("mirror_tandem_plugs", ["field:mirror_solenoidal", "field:tandem_plugs",
                "hardware:paired_end_coils", "hardware:plug_heating"], String[],
                "mirror_tandem_fowler_logan_1977"),
            ("mirror_multicell_stack", ["field:mirror_solenoidal",
                "field:multiple_mirror", "hardware:paired_end_coils"],
                ["geometry:multiple_mirror_cells"], "multiple_mirror_logan_1974"))
        field(id, ["magnetic_mirror"], "Finite open-mirror coil architecture.",
            provides, source, ["finite_mirror_coils", "peak_conductor_field"];
            requires = requires)
    end
    for (id, tag, source) in (
            ("frc_theta_pinch", "formation:theta_pinch", "frc_steinhauer_review_2011"),
            ("frc_rmf", "formation:rotating_magnetic_field",
                "frc_gerhardt_inductive_sustainment_2007"),
            ("frc_nbi", "formation:nbi_fast_ion", "frc_c2w_gota_2024"))
        field(id, ["field_reversed_configuration"],
            "FRC formation and sustainment architecture.",
            ["field:compact_toroid", tag], source,
            ["frc_formation", "actuator_power"])
    end
    for (id, tag, source) in (
            ("spheromak_coaxial_injector", "formation:coaxial_helicity_injection",
                "spheromak_hit_si_jarboe_2006"),
            ("spheromak_inductive", "formation:inductive_helicity",
                "spheromak_jarboe_review_1994"))
        field(id, ["spheromak"], "Spheromak helicity-drive architecture.",
            ["field:compact_toroid", tag, "hardware:electrodes"], source,
            ["helicity_injection", "electrode_power"])
    end
    for (id, tag, source) in (
            ("rfp_ppcd", "drive:ppcd", "rfp_ppcd_sarff_1997"),
            ("rfp_saddle_control", "drive:active_saddle_coils",
                "rfp_active_control_luchetta_2009"))
        field(id, ["reversed_field_pinch"], "RFP profile/control winding set.",
            ["field:reversed_toroidal", tag], source,
            ["rfp_profile_drive", "boundary_mode_spectrum"])
    end
    for (id, tag) in (("zpinch_coaxial_electrodes", "drive:coaxial_electrodes"),
            ("zpinch_distributed_electrodes", "drive:distributed_electrodes"))
        field(id, ["sheared_flow_z_pinch"],
            "Finite electrode and current-return architecture.",
            ["field:self_azimuthal", tag, "hardware:electrodes"],
            "zpinch_shear_shumlak_hartman_1995",
            ["coaxial_accelerator", "electrode_erosion"])
    end
    for (id, tag, source) in (
            ("mtf_solid_liner", "compression:solid_liner",
                "mtf_centimeter_liner_ryutov_2005"),
            ("mtf_pjmif", "compression:plasma_jet_liner",
                "pjmif_target_hsu_langendorf_2019"),
            ("mtf_maglif", "compression:maglif_liner",
                "maglif_high_gain_slutz_vesey_2012"))
        field(id, ["magnetized_target_fusion"],
            "Explicit pulsed MTF compression driver.",
            [tag, "hardware:pulsed_power"], source,
            ["driver_energy_ledger", "implosion_symmetry"])
    end
    for (id, tag, source) in (("dipole_levitated", "support:levitated",
            "dipole_ldx_design_garnier_2006"),
            ("dipole_supported", "support:mechanical", "mars_engineering_henning_1986"))
        field(id, ["levitated_dipole"], "Internal dipole support architecture.",
            ["field:internal_dipole", tag], source,
            ["internal_coil_support", "nuclear_heat_removal"])
    end
    for (id, tag, source) in (
            ("icf_indirect_drive", "drive:laser_indirect",
                "nif_indirect_drive_basis_lindl_2004"),
            ("icf_direct_drive", "drive:laser_direct",
                "direct_drive_review_campbell_2015"),
            ("icf_fast_ignition", "drive:laser_fast_ignition",
                "fast_ignition_tabak_1994"))
        field(id, ["inertial_confinement_fusion"],
            "Laser driver and capsule-coupling path.",
            [tag, "hardware:repeat_rate_laser"], source,
            ["icf_radiation_hydrodynamics",
                tag == "drive:laser_fast_ignition" ?
                    "fast_ignition_transport" : "laser_plasma_interaction"])
    end

    function stability(id, families, description, provides, source, evaluators;
            requires = String[])
        add(id, :stability, description,
            vcat(["layer:stability", "stability:declared"], provides);
            requires = requires, requires_any = _v17_family_group(families),
            sources = [source], evaluators = evaluators)
    end
    for (id, tag) in (("tokamak_q_shear", "mechanism:q_profile_shear"),
            ("tokamak_active_rwm", "mechanism:active_rwm_control"),
            ("tokamak_passive_wall", "mechanism:passive_conducting_wall"))
        stability(id, ["tokamak_axisymmetric"], "Tokamak stability/control mechanism.",
            [tag], "tokamak_iter_physics_basis_1999",
            ["ideal_mhd", "disruption_control"])
    end
    stability("hybrid_transform_share", ["tokamak_3d_hybrid"],
        "Hybrid current/3D-transform stability intersection.",
        ["mechanism:hybrid_transform_share"], "ncsx_physics_zarnstorff_2001",
        ["coupled_3d_mhd", "hybrid_current_profile"];
        requires = ["field:external_3d", "field:plasma_current"])
    stability("hybrid_active_spectrum", ["tokamak_3d_hybrid"],
        "Programmable hybrid mode and error-field control.",
        ["mechanism:programmable_3d_control"],
        "programmable_hybrid_yu_2026_preprint",
        ["active_3d_spectrum", "coil_control_authority"];
        requires = ["hardware:programmable_coils"])
    for (id, symmetry, source) in (("stellarator_qa_drift", "quasi_axisymmetric",
            "stellarator_precise_qs_landreman_paul_2022"),
            ("stellarator_qh_drift", "quasi_helical",
                "stellarator_nuhrenberg_zille_1988"),
            ("stellarator_qi_drift", "quasi_isodynamic",
                "stellarator_omnigenity_landreman_catto_2012"))
        stability(id, ["stellarator"], "Stellarator drift optimization.",
            ["mechanism:optimized_3d_drift"], source,
            ["neoclassical_transport", "alpha_orbits"];
            requires = ["symmetry:$symmetry"])
    end
    stability("stellarator_boundary_control", ["stellarator"],
        "Programmable 3D boundary-mode control.",
        ["mechanism:boundary_trim_control"], "w7x_island_divertor_2019",
        ["ideal_mhd", "island_spectrum_control"];
        requires = ["hardware:programmable_coils"])
    for (id, tag, needs, source, evaluator) in (
            ("stability_mirror_minimum_b", "mechanism:minimum_b", ["field:minimum_b"],
                "mirror_post_review_1987", "interchange_stability"),
            ("mirror_kinetic_stabilizer", "mechanism:kinetic_stabilizer",
                ["hardware:paired_end_coils"], "kinetic_stabilizer_post_2004",
                "kinetic_stabilizer_dispersion"),
            ("mirror_tandem_ambipolar", "mechanism:ambipolar_plug",
                ["field:tandem_plugs"], "mirror_tandem_fowler_logan_1977",
                "fokker_planck_ambipolar"),
            ("mirror_vortex_bias", "mechanism:vortex_bias",
                ["field:mirror_solenoidal"], "gdt_bagryansky_2019",
                "vortex_shear_stability"),
            ("mirror_gas_dynamic", "mechanism:gas_dynamic",
                ["field:mirror_solenoidal"], "mirror_gdt_neutron_source_2004",
                "gas_dynamic_collisionality"),
            ("mirror_multiple_mirror", "mechanism:multiple_mirror",
                ["field:multiple_mirror"], "golnb_postupaev_2026",
                "multiple_mirror_kinetics"))
        stability(id, ["magnetic_mirror"], "Open-mirror stability mechanism.",
            [tag], source, [evaluator, "anisotropic_equilibrium"];
            requires = needs)
    end
    for (id, tag, need, source) in (
            ("frc_fast_ion", "mechanism:fast_ion_orbit_stabilization",
                "formation:nbi_fast_ion", "frc_c2w_gota_2024"),
            ("stability_frc_rmf", "mechanism:rmf_sustainment",
                "formation:rotating_magnetic_field",
                "frc_gerhardt_inductive_sustainment_2007"),
            ("frc_end_bias", "mechanism:end_bias_shear", "field:compact_toroid",
                "frc_steinhauer_review_2011"))
        stability(id, ["field_reversed_configuration"], "FRC stability mechanism.",
            [tag], source, ["frc_mode_spectrum", "sustainment_power"];
            requires = [need])
    end
    for (id, need, source) in (("spheromak_steady_helicity",
            "formation:coaxial_helicity_injection", "spheromak_hit_si_jarboe_2006"),
            ("stability_spheromak_inductive", "formation:inductive_helicity",
                "spheromak_jarboe_review_1994"))
        stability(id, ["spheromak"], "Spheromak helicity sustainment.",
            ["mechanism:helicity_sustainment"], source,
            ["resistive_mhd_dynamo", "helicity_balance"];
            requires = [need])
    end
    for (id, need, source) in (("rfp_ppcd_profile", "drive:ppcd",
            "rfp_ppcd_sarff_1997"),
            ("rfp_boundary_control", "drive:active_saddle_coils",
                "rfp_active_control_luchetta_2009"),
            ("rfp_shax", "field:reversed_toroidal", "rfp_sha_lorenzini_2008"))
        stability(id, ["reversed_field_pinch"], "RFP profile/control mechanism.",
            ["mechanism:rfp_profile_control"], source,
            ["resistive_mhd_rfp", "tearing_spectrum"];
            requires = [need])
    end
    for (id, tag) in (("zpinch_axial_shear", "mechanism:axial_flow_shear"),
            ("zpinch_flr", "mechanism:finite_larmor_radius"),
            ("zpinch_active_profile", "mechanism:active_current_profile"))
        stability(id, ["sheared_flow_z_pinch"], "Z-pinch stability hypothesis.",
            [tag], "zpinch_shear_shumlak_hartman_1995",
            ["resistive_mhd_with_axial_flow", "sausage_kink_spectrum"];
            requires = ["hardware:electrodes"])
    end
    for (id, tag, source) in (("mtf_magnetized_target",
            "mechanism:magnetized_target_suppression", "mtf_overview_kirkpatrick_1995"),
            ("mtf_implosion_symmetry", "mechanism:implosion_symmetry",
                "pjmif_semi_analytic_langendorf_hsu_2017"),
            ("mtf_timescale", "mechanism:compression_timescale",
                "mtf_centimeter_liner_ryutov_2005"))
        stability(id, ["magnetized_target_fusion"], "MTF stability hypothesis.",
            [tag], source, ["radiation_mhd_instability", "mix_model"];
            requires = ["hardware:pulsed_power"])
    end
    for (id, tag) in (("dipole_favorable_curvature",
            "mechanism:dipole_favorable_curvature"),
            ("dipole_rotation_feedback", "mechanism:dipole_rotation_feedback"))
        stability(id, ["levitated_dipole"], "Dipole profile/stability mechanism.",
            [tag], "dipole_inward_pinch_boxer_2010",
            ["dipole_interchange", "profile_transport"];
            requires = ["field:internal_dipole"])
    end
    for (id, tag, need, source) in (
            ("icf_hotspot_alpha", "mechanism:hotspot_alpha_heating",
                "hardware:repeat_rate_laser", "nif_burning_plasma_2022"),
            ("icf_shock_timing", "mechanism:shock_timing_control",
                "hardware:repeat_rate_laser", "nif_indirect_drive_basis_lindl_2004"),
            ("icf_fast_ignition_transport", "mechanism:fast_ignition_transport",
                "drive:laser_fast_ignition", "fast_ignition_tabak_1994"))
        stability(id, ["inertial_confinement_fusion"], "ICF ignition hypothesis.",
            [tag], source, ["icf_radiation_hydrodynamics", "mix_and_lpi"];
            requires = [need])
    end

    function exhaust(id, families, description, provides, source, evaluators;
            requires = String[])
        add(id, :exhaust, description,
            vcat(["layer:exhaust", "exhaust:declared"], provides);
            requires = requires, requires_any = _v17_family_group(families),
            sources = [source], evaluators = evaluators)
    end
    current_tori = ["tokamak_axisymmetric", "tokamak_3d_hybrid"]
    exhaust("xpoint_two_target", current_tori, "Two-target X-point divertor.",
        ["exhaust:magnetic_divertor", "target_count:2"],
        "tokamak_iter_physics_basis_1999", ["scrape_off_layer", "detachment"];
        requires = ["topology:separatrix"])
    exhaust("distributed_four_target", current_tori,
        "Four finite distributed magnetic targets.",
        ["exhaust:magnetic_divertor", "target_count:4"],
        "tokamak_iter_physics_basis_1999", ["sol_heat_flux", "target_geometry"];
        requires = ["topology:separatrix"])
    exhaust("super_x", current_tori, "Long-leg Super-X target geometry.",
        ["exhaust:super_x", "target_count:2"], "superx_havlickova_2014",
        ["solps_exhaust", "divertor_coil_build"];
        requires = ["symmetry:axisymmetric"])
    for (id, targets) in (("stellarator_island_5", 5),
            ("stellarator_island_10", 10), ("stellarator_distributed", 20))
        exhaust(id, ["stellarator"], "3D boundary-island target architecture.",
            ["exhaust:island_divertor", "target_count:$targets"],
            "w7x_island_divertor_2019", ["island_divertor_topology", "detachment"];
            requires = ["symmetry:3d"])
    end
    for (id, tag, needs, source) in (
            ("mirror_two_end_expander", "exhaust:two_end_expander",
                ["topology:two_open_ends"], "mirror_wham_physics_basis_2023"),
            ("mirror_direct_converter", "exhaust:direct_converter",
                ["topology:two_open_ends"], "mirror_post_review_1987"),
            ("mirror_gas_dynamic_targets", "exhaust:gas_dynamic_targets",
                ["topology:two_open_ends"], "mirror_gdt_neutron_source_2004"),
            ("mirror_staged_multicell", "exhaust:staged_multicell",
                ["geometry:multiple_mirror_cells"], "multiple_mirror_logan_1974"))
        exhaust(id, ["magnetic_mirror"], "Open-mirror axial exhaust architecture.",
            [tag, "target_count:2"], source,
            ["end_expander_transport", "target_heat_flux"]; requires = needs)
    end
    compact = ["field_reversed_configuration", "spheromak", "reversed_field_pinch"]
    for (id, tag, count) in (("compact_two_target", "exhaust:open_sol_targets", 2),
            ("compact_four_target", "exhaust:distributed_targets", 4),
            ("compact_liquid_limiter", "exhaust:liquid_limiter", 8))
        exhaust(id, compact, "Compact-toroid/RFP edge architecture.",
            [tag, "target_count:$count"], "frc_steinhauer_review_2011",
            ["edge_transport", "target_heat_flux"])
    end
    for (id, tag) in (("zpinch_two_end", "exhaust:two_end_collector"),
            ("zpinch_electrode_chamber", "exhaust:electrode_chamber"))
        exhaust(id, ["sheared_flow_z_pinch"], "Z-pinch end/electrode exhaust.",
            [tag, "target_count:2"], "zpinch_shear_shumlak_hartman_1995",
            ["end_loss", "electrode_heat_flux"];
            requires = ["topology:two_open_ends"])
    end
    for (id, wall, source) in (("mtf_dry_chamber", "chamber:dry_wall",
            "mtf_centimeter_liner_ryutov_2005"),
            ("mtf_liquid_wall", "chamber:liquid_wall", "mtf_overview_kirkpatrick_1995"),
            ("mtf_expendable_liner", "chamber:expendable_liner",
                "pjmif_target_hsu_langendorf_2019"))
        exhaust(id, ["magnetized_target_fusion"], "Pulsed MTF chamber architecture.",
            [wall, "exhaust:pulsed_chamber"], source,
            ["pulsed_chamber_recovery", "first_wall_lifetime"];
            requires = ["topology:pulsed_chamber"])
    end
    for (id, tag) in (("dipole_outer_limiter", "exhaust:outer_limiter"),
            ("dipole_annular_collector", "exhaust:annular_collector"))
        exhaust(id, ["levitated_dipole"], "Dipole heat/particle collection.",
            [tag], "dipole_ldx_design_garnier_2006",
            ["dipole_edge_transport", "collector_heat_flux"];
            requires = ["topology:closed_dipole"])
    end
    for (id, wall) in (("icf_dry_wall", "chamber:dry_wall"),
            ("icf_liquid_protected", "chamber:liquid_wall"),
            ("icf_gas_protected", "chamber:gas_protected"))
        exhaust(id, ["inertial_confinement_fusion"], "ICF chamber protection.",
            [wall, "exhaust:pulsed_chamber"], "ife_assessment_nas_2013",
            ["pulsed_chamber_clearing", "first_wall_lifetime"];
            requires = ["topology:pulsed_chamber"])
    end

    function engineering(id, families, description, provides, source, evaluators;
            requires = String[], forbids = String[])
        add(id, :engineering, description,
            vcat(["layer:engineering", "engineering:minimum_closure_declared"],
                provides); requires = requires,
            requires_any = _v17_family_group(families), forbids = forbids,
            sources = [source], evaluators = evaluators)
    end
    external = ["tokamak_axisymmetric", "tokamak_3d_hybrid", "stellarator",
        "magnetic_mirror", "field_reversed_configuration", "spheromak",
        "reversed_field_pinch", "sheared_flow_z_pinch", "levitated_dipole",
        "magnetized_target_fusion"]
    for (id, tag, source) in (
            ("fixed_external_superconducting", "maintenance:fixed_external_sectors",
                "aries_cs_power_plant_2008"),
            ("demountable_rebco", "maintenance:demountable_sectors", "arc_sorbom_2015"),
            ("segmented_external_remote", "maintenance:segmented_remote",
                "process_engineering_2016"),
            ("shielded_service_cassettes", "maintenance:shielded_service_cassettes",
                "process_engineering_2016"))
        engineering(id, external, "External-coil engineering and maintenance architecture.",
            [tag], source, ["coil_stress", "shielding", "remote_maintenance"];
            requires = ["coil_location:external", "operating:steady"],
            forbids = ["coil_location:internal", "operating:pulsed"])
    end
    engineering("linear_replaceable_ends", ["magnetic_mirror", "sheared_flow_z_pinch"],
        "Replaceable end cells with axial access.",
        ["maintenance:replaceable_end_cells"], "mirror_post_review_1987",
        ["end_cell_replacement", "axial_shielding"];
        requires = ["topology:two_open_ends", "operating:steady"])
    engineering("direct_conversion_ends", ["magnetic_mirror"],
        "Axial direct-conversion modules outside replaceable ends.",
        ["maintenance:replaceable_end_cells", "power:direct_conversion_declared"],
        "mirror_post_review_1987", ["direct_conversion_efficiency", "grid_lifetime"];
        requires = ["exhaust:direct_converter"])
    engineering("compact_vessel_cartridge",
        ["field_reversed_configuration", "spheromak", "reversed_field_pinch"],
        "Replaceable compact-toroid vessel cartridge.",
        ["maintenance:compact_vessel_cartridge"], "process_engineering_2016",
        ["vessel_fatigue", "remote_maintenance", "shielding"];
        requires = ["operating:steady"])
    engineering("electrode_cartridge", ["spheromak", "sheared_flow_z_pinch"],
        "Replaceable electrode/current-return cartridge.",
        ["maintenance:electrode_cartridge"], "spheromak_hit_si_jarboe_2006",
        ["electrode_erosion", "feedthrough_lifetime"];
        requires = ["hardware:electrodes"])
    engineering("levitated_coil_service", ["levitated_dipole"],
        "Levitated-coil lift, recharge, shielding, and retrieval path.",
        ["maintenance:levitated_internal_coil"], "dipole_ldx_design_garnier_2006",
        ["levitation_control", "internal_coil_lifetime"];
        requires = ["support:levitated"])
    engineering("supported_dipole_cartridge", ["levitated_dipole"],
        "Supported internal-dipole replaceable cartridge.",
        ["maintenance:supported_internal_coil"], "mars_engineering_henning_1986",
        ["support_heat_leak", "internal_coil_replacement"];
        requires = ["support:mechanical"])
    engineering("pulsed_dry_replaceable", ["magnetized_target_fusion"],
        "Replaceable dry pulsed chamber and driver service modules.",
        ["maintenance:pulsed_dry_chamber"], "mtf_overview_kirkpatrick_1995",
        ["fatigue_lifetime", "chamber_recovery", "target_throughput"];
        requires = ["chamber:dry_wall", "operating:pulsed"])
    engineering("pulsed_liquid_modular", ["magnetized_target_fusion"],
        "Modular liquid-protected chamber and recirculation plant.",
        ["maintenance:pulsed_liquid_chamber"], "mtf_overview_kirkpatrick_1995",
        ["liquid_wall_recovery", "driver_interface", "target_throughput"];
        requires = ["chamber:liquid_wall", "operating:pulsed"])
    for (id, wall) in (("icf_dry_target_factory", "chamber:dry_wall"),
            ("icf_liquid_target_factory", "chamber:liquid_wall"),
            ("icf_gas_target_factory", "chamber:gas_protected"))
        engineering(id, ["inertial_confinement_fusion"],
            "Laser driver, target factory, chamber, and maintenance ledger.",
            ["maintenance:icf_target_factory"], "ife_assessment_nas_2013",
            ["repeat_rate_laser_driver", "target_factory_and_injection",
                "first_wall_lifetime"];
            requires = [wall, "hardware:target_factory", "operating:pulsed"])
    end
    return modules
end

function topology_module_to_dict_v17(module_spec::TopologyModuleV17)
    return Dict{String,Any}(
        "id" => module_spec.id, "layer" => String(module_spec.layer),
        "description" => module_spec.description,
        "provides" => sort!(collect(module_spec.provides)),
        "requires_all" => sort!(collect(module_spec.requires_all)),
        "requires_any" => [sort!(collect(group)) for group in module_spec.requires_any],
        "forbids" => sort!(collect(module_spec.forbids)),
        "source_ids" => copy(module_spec.source_ids),
        "required_evaluators" => copy(module_spec.required_evaluators))
end

function topology_module_catalog_hash_v17(catalog::Vector{TopologyModuleV17})
    return canonical_hash(Dict("schema_version" => "1.0.0",
        "layer_order" => String.(collect(_V17_LAYERS)),
        "modules" => [topology_module_to_dict_v17(item) for item in
            sort!(copy(catalog); by = item -> item.id)]))
end

function validate_topology_module_catalog_v17(catalog::Vector{TopologyModuleV17};
        known_source_ids::Set{String} = Set{String}())
    errors = String[]
    ids = getfield.(catalog, :id)
    length(unique(ids)) == length(ids) || push!(errors, "duplicate v17 module IDs")
    for layer in _V17_LAYERS
        any(item -> item.layer == layer, catalog) ||
            push!(errors, "v17 catalog has no $layer modules")
    end
    provided = _v17_union_tags(catalog)
    for item in catalog
        missing = setdiff(item.requires_all, provided)
        isempty(missing) || push!(errors,
            "module $(item.id) requires unprovided tags: " *
            join(sort!(collect(missing)), ", "))
        for group in item.requires_any
            isempty(intersect(group, provided)) && push!(errors,
                "module $(item.id) has an unsatisfiable requires-any group")
        end
        if !isempty(known_source_ids)
            missing_sources = setdiff(Set(item.source_ids), known_source_ids)
            isempty(missing_sources) || push!(errors,
                "module $(item.id) references unknown sources: " *
                join(sort!(collect(missing_sources)), ", "))
        end
    end
    return ValidationReport(isempty(errors), sort!(unique(errors)), String[])
end

function _v17_prefix_errors(prefix::Vector{TopologyModuleV17},
        next_module::TopologyModuleV17)
    tags = _v17_union_tags(prefix)
    errors = String[]
    for tag in sort!(collect(setdiff(next_module.requires_all, tags)))
        push!(errors, "missing_required_tag:$(next_module.id):$tag")
    end
    for group in next_module.requires_any
        isempty(intersect(group, tags)) || continue
        push!(errors, "missing_required_any:$(next_module.id):" *
            join(sort!(collect(group)), "|"))
    end
    for tag in sort!(collect(intersect(next_module.forbids, tags)))
        push!(errors, "forbidden_existing_tag:$(next_module.id):$tag")
    end
    for previous in prefix, tag in sort!(collect(intersect(previous.forbids,
            next_module.provides)))
        push!(errors, "forbidden_new_tag:$(previous.id):$tag")
    end
    return sort!(unique(errors))
end

function _v17_edges(modules::Vector{TopologyModuleV17})
    edges = TopologyDependencyEdgeV17[]
    for index in 2:length(modules)
        consumer = modules[index]
        earlier = modules[1:index-1]
        earlier_tags = _v17_union_tags(earlier)
        required = collect(consumer.requires_all)
        for group in consumer.requires_any
            available = sort!(collect(intersect(group, earlier_tags)))
            isempty(available) || push!(required, first(available))
        end
        for tag in sort!(unique(required))
            providers = sort!(filter(item -> tag in item.provides, earlier);
                by = item -> item.id)
            isempty(providers) || push!(edges, TopologyDependencyEdgeV17(
                first(providers).id, consumer.id, tag))
        end
    end
    sort!(edges; by = edge -> (edge.from_module_id, edge.to_module_id,
        edge.supplied_tag))
    return edges
end

function validate_topology_assembly_v17(modules::Vector{TopologyModuleV17})
    errors = String[]
    length(modules) == length(_V17_LAYERS) ||
        push!(errors, "assembly_requires_exactly_five_layers")
    if length(modules) == length(_V17_LAYERS)
        for (expected, item) in zip(_V17_LAYERS, modules)
            item.layer == expected ||
                push!(errors, "layer_order_mismatch:$expected:$(item.id)")
        end
    end
    tags = _v17_union_tags(modules)
    for item in modules
        for tag in setdiff(item.requires_all, tags)
            push!(errors, "missing_required_tag:$(item.id):$tag")
        end
        for group in item.requires_any
            isempty(intersect(group, tags)) && push!(errors,
                "missing_required_any:$(item.id):" *
                join(sort!(collect(group)), "|"))
        end
        for tag in intersect(item.forbids, tags)
            push!(errors, "forbidden_tag:$(item.id):$tag")
        end
    end
    family_tags = filter(tag -> startswith(tag, "family:"), collect(tags))
    length(family_tags) == 1 || push!(errors, "assembly_requires_exactly_one_family")
    contract_tags = filter(tag -> startswith(tag, "contract:"), collect(tags))
    length(contract_tags) == 1 || push!(errors, "assembly_requires_exactly_one_contract")
    for tag in ("layer:core", "field_source:declared", "stability:declared",
            "exhaust:declared", "engineering:minimum_closure_declared")
        tag in tags || push!(errors, "missing_mandatory_closure_tag:$tag")
    end
    edges = isempty(errors) ? _v17_edges(modules) : TopologyDependencyEdgeV17[]
    isempty(errors) && length(edges) < 4 &&
        push!(errors, "assembly_dependency_graph_is_not_connected")
    return TopologyAssemblyValidationV17(isempty(errors),
        sort!(unique(errors)), sort!(collect(tags)), edges)
end

_v17_edge_to_dict(edge::TopologyDependencyEdgeV17) = Dict{String,Any}(
    "from_module_id" => edge.from_module_id,
    "to_module_id" => edge.to_module_id,
    "supplied_tag" => edge.supplied_tag)

function _v17_build_assembly(modules::Vector{TopologyModuleV17},
        validation::TopologyAssemblyValidationV17)
    validation.valid || throw(ArgumentError(join(validation.reason_codes, "; ")))
    family_tag = only(filter(tag -> startswith(tag, "family:"), validation.tags))
    contract_tag = only(filter(tag -> startswith(tag, "contract:"), validation.tags))
    module_ids = getfield.(modules, :id)
    sources = sort!(unique(vcat(getfield.(modules, :source_ids)...)))
    evaluators = sort!(unique(vcat(getfield.(modules, :required_evaluators)...)))
    graph = Dict{String,Any}(
        "module_ids" => module_ids, "tags" => validation.tags,
        "edges" => _v17_edge_to_dict.(validation.edges),
        "source_ids" => sources, "missing_required_evaluators" => evaluators,
        "claim_level" => "C0_structural_hypothesis_only")
    graph_hash = canonical_hash(graph)
    family = split(family_tag, ":"; limit = 2)[2]
    contract = split(contract_tag, ":"; limit = 2)[2]
    descriptor = join(vcat([family], module_ids), "|")
    return TopologyAssemblyV17("assembly_$(graph_hash[1:20])", family,
        contract, module_ids, validation.tags, validation.edges, sources,
        evaluators, descriptor, graph_hash)
end

function explain_topology_combination_v17(catalog::Vector{TopologyModuleV17},
        module_ids)
    by_id = Dict(item.id => item for item in catalog)
    ids = String.(collect(module_ids))
    missing = sort!(filter(id -> !haskey(by_id, id), ids))
    isempty(missing) || return TopologyAssemblyValidationV17(false,
        ["unknown_module_id:$id" for id in missing], String[],
        TopologyDependencyEdgeV17[])
    return validate_topology_assembly_v17([by_id[id] for id in ids])
end

function _v17_round_robin_archive(assemblies::Vector{TopologyAssemblyV17},
        maximum_archive::Int)
    groups = Dict{String,Vector{TopologyAssemblyV17}}()
    for assembly in assemblies
        push!(get!(groups, assembly.family, TopologyAssemblyV17[]), assembly)
    end
    for items in values(groups)
        sort!(items; by = item -> (item.graph_hash, item.assembly_id))
    end
    families = sort!(collect(keys(groups)))
    archive = TopologyAssemblyV17[]
    cursor = Dict(family => 1 for family in families)
    target = min(maximum_archive, length(assemblies))
    while length(archive) < target
        progressed = false
        for family in families
            index = cursor[family]
            index > length(groups[family]) && continue
            push!(archive, groups[family][index])
            cursor[family] = index + 1
            progressed = true
            length(archive) == target && break
        end
        progressed || break
    end
    return archive
end

function run_attribute_graph_grammar_v17(;
        catalog::Vector{TopologyModuleV17} = default_topology_module_catalog_v17(),
        maximum_archive::Int = 1200, maximum_rejection_samples::Int = 80,
        known_source_ids::Set{String} = Set{String}())
    maximum_archive >= 1000 || throw(ArgumentError(
        "v17 formal archive must retain at least 1000 structures"))
    maximum_rejection_samples >= 0 || throw(ArgumentError(
        "maximum_rejection_samples must be non-negative"))
    report = validate_topology_module_catalog_v17(catalog;
        known_source_ids = known_source_ids)
    report.valid || throw(ArgumentError(join(report.errors, "; ")))
    by_layer = Dict(layer => sort!(filter(item -> item.layer == layer, catalog);
        by = item -> item.id) for layer in _V17_LAYERS)
    partials = Vector{Vector{TopologyModuleV17}}([TopologyModuleV17[]])
    attempts = 0
    rejected = 0
    reason_counts = Dict{String,Int}()
    samples = Dict{String,Dict{String,Any}}()
    for layer in _V17_LAYERS
        next_partials = Vector{Vector{TopologyModuleV17}}()
        for prefix in partials, item in by_layer[layer]
            attempts += 1
            errors = _v17_prefix_errors(prefix, item)
            if isempty(errors)
                push!(next_partials, vcat(prefix, [item]))
            else
                rejected += 1
                for reason in errors
                    reason_counts[reason] = get(reason_counts, reason, 0) + 1
                end
                signature = join(errors, ";")
                if length(samples) < maximum_rejection_samples &&
                        !haskey(samples, signature)
                    samples[signature] = Dict{String,Any}(
                        "attempted_layer" => String(layer),
                        "prefix_module_ids" => getfield.(prefix, :id),
                        "attempted_module_id" => item.id,
                        "reason_codes" => errors)
                end
            end
        end
        partials = next_partials
        isempty(partials) && throw(ArgumentError(
            "v17 grammar produced no partials after $layer"))
    end
    assemblies = TopologyAssemblyV17[]
    for modules in partials
        validation = validate_topology_assembly_v17(modules)
        validation.valid || throw(ArgumentError(
            "prefix-valid assembly failed: " * join(validation.reason_codes, "; ")))
        push!(assemblies, _v17_build_assembly(modules, validation))
    end
    length(unique(getfield.(assemblies, :graph_hash))) == length(assemblies) ||
        throw(ArgumentError("v17 generated duplicate graph hashes"))
    length(assemblies) >= 1000 || throw(ArgumentError(
        "v17 generated only $(length(assemblies)) compatible structures"))
    family_counts = Dict{String,Int}()
    for assembly in assemblies
        family_counts[assembly.family] = get(family_counts, assembly.family, 0) + 1
    end
    archive = _v17_round_robin_archive(assemblies, maximum_archive)
    length(archive) >= 1000 || throw(ArgumentError(
        "v17 archive retained only $(length(archive)) structures"))
    archive_counts = Dict{String,Int}()
    for assembly in archive
        archive_counts[assembly.family] =
            get(archive_counts, assembly.family, 0) + 1
    end
    claim = "Five-layer attribute-graph grammar and structural diversity archive. " *
        "Every retained assembly is C0 only: module compatibility, dependency " *
        "closure, source traceability, and explicit missing-evaluator routing are " *
        "checked, but no equilibrium, stability, particle-loss, power, engineering, " *
        "robustness, novelty, or superiority gate is credited. The archive is not " *
        "a medium-fidelity queue."
    rejection_samples = sort!(collect(values(samples)); by = item ->
        (item["attempted_layer"], item["attempted_module_id"],
            join(item["reason_codes"], ";")))
    return AttributeGraphGrammarResultV17(catalog, length(assemblies),
        family_counts, archive, archive_counts, attempts, rejected,
        reason_counts, rejection_samples, topology_module_catalog_hash_v17(catalog),
        claim)
end

function topology_assembly_to_dict_v17(assembly::TopologyAssemblyV17)
    return Dict{String,Any}(
        "assembly_id" => assembly.assembly_id, "family" => assembly.family,
        "mission_contract_id" => assembly.mission_contract_id,
        "module_ids" => copy(assembly.module_ids), "tags" => copy(assembly.tags),
        "dependency_edges" => _v17_edge_to_dict.(assembly.edges),
        "source_ids" => copy(assembly.source_ids),
        "missing_required_evaluators" =>
            copy(assembly.missing_required_evaluators),
        "structural_descriptor" => assembly.structural_descriptor,
        "graph_hash" => assembly.graph_hash,
        "claim_level" => "C0_structural_hypothesis_only")
end

function attribute_graph_grammar_to_dict_v17(result::AttributeGraphGrammarResultV17)
    layer_counts = Dict(String(layer) => count(item -> item.layer == layer,
        result.catalog) for layer in _V17_LAYERS)
    reasons = sort!(collect(result.rejection_reason_counts);
        by = item -> (-last(item), first(item)))
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "stage" => "five_layer_attribute_graph_grammar_v17",
        "algorithm" =>
            "deterministic_tag_constraint_composition_and_family_round_robin_qd_v1",
        "layer_order" => String.(collect(_V17_LAYERS)),
        "catalog" => Dict("catalog_hash" => result.catalog_hash,
            "module_count" => length(result.catalog), "layer_counts" => layer_counts,
            "modules" => [topology_module_to_dict_v17(item) for item in
                sort!(copy(result.catalog); by = item -> item.id)]),
        "generation_audit" => Dict(
            "partial_extension_attempt_count" =>
                result.partial_extension_attempt_count,
            "rejected_partial_extension_count" =>
                result.rejected_partial_extension_count,
            "compatible_assembly_count" => result.compatible_assembly_count,
            "compatible_family_counts" => result.compatible_family_counts,
            "unique_graph_hash_count" => result.compatible_assembly_count,
            "rejection_reason_counts" => Dict(first(item) => last(item)
                for item in reasons), "rejection_samples" => result.rejection_samples),
        "structural_qd_archive" => Dict(
            "selection_policy" =>
                "family round-robin over graph-hash-sorted compatible assemblies",
            "assembly_count" => length(result.archive),
            "family_counts" => result.archive_family_counts,
            "assemblies" => topology_assembly_to_dict_v17.(result.archive)),
        "evaluation_and_promotion_policy" => Dict(
            "physics_credit_count" => 0, "engineering_credit_count" => 0,
            "five_gate_pass_count" => 0,
            "medium_fidelity_authorized_count" => 0,
            "medium_fidelity_review_queue" => Any[],
            "reason" => "V17 establishes C0 structural breadth only; all solver requirements remain explicit unknowns."),
        "claim_boundary" => result.claim_boundary)
end
