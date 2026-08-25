"""
One deliberately low-fidelity hypothesis for a phase-locked reciprocal mirror ring.

The device is represented as a directed cycle of locally open magnetic buckets.  A
multi-phase coil drive translates the mirror barriers so that a plasma packet is
handed from one bucket to the next.  This is not a claim that closed flux surfaces
exist, nor that the handoff efficiency is attainable.
"""
struct PhaseLockedMirrorRingSpecV1
    cell_count::Int
    ring_major_radius_m::Float64
    tube_radius_m::Float64
    guide_field_T::Float64
    mirror_ratio::Float64
    ion_temperature_keV::Float64
    beta::Float64
    handoff_survival::Float64
    recovery_efficiency::Float64
    drive_power_per_cell_MW::Float64
    drive_frequency_Hz::Float64

    function PhaseLockedMirrorRingSpecV1(cell_count::Integer,
            ring_major_radius_m::Real, tube_radius_m::Real,
            guide_field_T::Real, mirror_ratio::Real,
            ion_temperature_keV::Real, beta::Real,
            handoff_survival::Real, recovery_efficiency::Real,
            drive_power_per_cell_MW::Real, drive_frequency_Hz::Real)
        cell_count >= 4 || throw(ArgumentError("mirror ring needs at least four cells"))
        ring_major_radius_m > tube_radius_m > 0 ||
            throw(ArgumentError("ring radius must exceed a positive tube radius"))
        guide_field_T > 0 || throw(ArgumentError("guide field must be positive"))
        mirror_ratio > 1 || throw(ArgumentError("mirror ratio must exceed one"))
        ion_temperature_keV > 0 || throw(ArgumentError("temperature must be positive"))
        0 < beta < 1 || throw(ArgumentError("beta must be between zero and one"))
        0 < handoff_survival < 1 ||
            throw(ArgumentError("handoff survival must be between zero and one"))
        0 <= recovery_efficiency < 1 ||
            throw(ArgumentError("recovery efficiency must be in [0, 1)"))
        drive_power_per_cell_MW >= 0 ||
            throw(ArgumentError("drive power must be nonnegative"))
        drive_frequency_Hz > 0 ||
            throw(ArgumentError("drive frequency must be positive"))
        return new(Int(cell_count), Float64(ring_major_radius_m),
            Float64(tube_radius_m), Float64(guide_field_T),
            Float64(mirror_ratio), Float64(ion_temperature_keV),
            Float64(beta), Float64(handoff_survival),
            Float64(recovery_efficiency), Float64(drive_power_per_cell_MW),
            Float64(drive_frequency_Hz))
    end
end

struct StageClosureContractV1
    id::String
    minimum_fusion_gain_proxy::Float64
    minimum_net_electric_MW::Float64
    maximum_recirc_to_fusion_ratio::Float64

    function StageClosureContractV1(id::AbstractString,
            minimum_fusion_gain_proxy::Real, minimum_net_electric_MW::Real,
            maximum_recirc_to_fusion_ratio::Real)
        isempty(id) && throw(ArgumentError("stage contract id must not be empty"))
        minimum_fusion_gain_proxy >= 0 ||
            throw(ArgumentError("minimum gain must be nonnegative"))
        maximum_recirc_to_fusion_ratio > 0 ||
            throw(ArgumentError("recirculating ratio cap must be positive"))
        return new(String(id), Float64(minimum_fusion_gain_proxy),
            Float64(minimum_net_electric_MW),
            Float64(maximum_recirc_to_fusion_ratio))
    end
end

default_phase_locked_mirror_ring_spec_v1() = PhaseLockedMirrorRingSpecV1(
    12, 5.0, 0.45, 4.5, 3.5, 12.0, 0.025,
    0.999995, 0.70, 0.35, 36_000.0)

"""A deliberately permissive computational-closure gate, not a reactor gate."""
default_stage_closure_contract_v1() = StageClosureContractV1(
    "stage_closure_low_bar_v1", 0.25, -15.0, 3.0)

_plrmr_q(value::Real, unit::String; basis::String) = Dict{String,Any}(
    "value" => Float64(value), "unit" => unit, "basis" => basis)

function phase_locked_mirror_ring_family_extension_v1()
    spec = FamilySpec(
        "phase_locked_reciprocal_mirror_ring",
        Set(["mixed"]), Set(["none"]),
        "directed cyclic graph of locally open flux-tube cells with time phase",
        ["time_dependent_maxwell_particle_handoff"], "structural_only")
    return FamilyExtensionPackage(
        "phase_locked_reciprocal_mirror_ring_v1", "1.0.0",
        "typed_genome_phase_locked_mirror_ring_overlay_v1", [spec],
        ["mirror_post_review_1987"],
        "The package registers a testable mechanism hypothesis only. The cited mirror review supports mirror loss-cone and energy-recovery problem framing, not cyclic phase-locked handoff, attainable survival, stability, or net power.")
end

function _plrmr_region(cell::Int, spec::PhaseLockedMirrorRingSpecV1)
    phase = 2pi * (cell - 1) / spec.cell_count
    arc_length = 2pi * spec.ring_major_radius_m / spec.cell_count
    return Dict{String,Any}(
        "id" => "bucket_cell_$(lpad(cell, 2, '0'))",
        "kind" => "locally_open_reciprocal_mirror_bucket",
        "geometry_model" => "toroidal_arc_flux_tube_cell_v1",
        "parameters" => Dict{String,Any}(
            "ring_major_radius" => _plrmr_q(spec.ring_major_radius_m, "m";
                basis = "human-authored exploratory geometry"),
            "tube_radius" => _plrmr_q(spec.tube_radius_m, "m";
                basis = "human-authored exploratory geometry"),
            "cell_arc_length" => _plrmr_q(arc_length, "m";
                basis = "2*pi*R/cell_count"),
            "toroidal_phase" => _plrmr_q(phase, "rad";
                basis = "uniform cell phase"),
            "guide_field" => _plrmr_q(spec.guide_field_T, "T";
                basis = "screening hypothesis"),
            "mirror_ratio" => _plrmr_q(spec.mirror_ratio, "1";
                basis = "screening hypothesis")))
end

"""Build a Typed Genome without projecting the new mechanism onto a legacy family."""
function build_phase_locked_mirror_ring_genome_v1(parent::Genome,
        spec::PhaseLockedMirrorRingSpecV1 = default_phase_locked_mirror_ring_spec_v1())
    raw = deepcopy(parent.normalized)
    raw["design_id"] = "pending_plrmr_v1"
    raw["label"] = "Phase-locked reciprocal mirror ring v1"
    raw["mission"] = Dict{String,Any}(
        "kind" => "science_gain_demo", "fuel" => "D-T",
        "operating_mode" => "long_pulse",
        "targets" => Dict{String,Any}(
            "ion_temperature" => _plrmr_q(spec.ion_temperature_keV, "keV";
                basis = "low-fidelity stage-screen hypothesis"),
            "beta" => _plrmr_q(spec.beta, "1";
                basis = "low-fidelity stage-screen hypothesis"),
            "handoff_survival" => _plrmr_q(spec.handoff_survival, "1";
                basis = "unvalidated per-cell hypothesis"),
            "recovery_efficiency" => _plrmr_q(spec.recovery_efficiency, "1";
                basis = "unvalidated recirculating-energy hypothesis")))
    raw["family"] = "phase_locked_reciprocal_mirror_ring"
    raw["topology"] = Dict{String,Any}(
        "field_line_class" => "mixed",
        "rotation_transform_sources" => ["time_phased_directed_handoff"],
        "expected_flux_surfaces" => false,
        "expected_separatrix" => false)
    raw["symmetry"] = Dict{String,Any}(
        "class" => "none", "field_periods" => spec.cell_count,
        "hard_constraints" => [
            "no credit for static closed toroidal flux surfaces",
            "every bucket is locally open",
            "directed handoff edges form one complete cycle",
            "phase slip and dephased exhaust remain explicit failure modes"])
    cells = Any[_plrmr_region(i, spec) for i in 1:spec.cell_count]
    push!(cells, Dict{String,Any}(
        "id" => "dephased_exhaust", "kind" => "phase_selective_exhaust_region",
        "geometry_model" => "distributed_ring_dump_collectors_v1",
        "parameters" => Dict{String,Any}(
            "collector_radius" => _plrmr_q(1.2spec.tube_radius_m, "m";
                basis = "exploratory clearance"))))
    raw["plasma_regions"] = cells
    raw["field_sources"] = Any[
        Dict{String,Any}(
            "id" => "static_ring_guide_array",
            "kind" => "segmented_toroidal_guide_coil_array",
            "geometry_model" => "finite_build_segmented_ring_coils_v1",
            "parameters" => Dict{String,Any}(
                "coil_count" => _plrmr_q(spec.cell_count, "1";
                    basis = "one guide segment per bucket"),
                "guide_field" => _plrmr_q(spec.guide_field_T, "T";
                    basis = "screening hypothesis"),
                "ring_major_radius" => _plrmr_q(spec.ring_major_radius_m, "m";
                    basis = "exploratory geometry")),
            "material" => "conceptual superconducting winding"),
        Dict{String,Any}(
            "id" => "traveling_mirror_barrier_array",
            "kind" => "multiphase_magnetic_mirror_coil_array",
            "geometry_model" => "phase_shifted_finite_build_cell_coils_v1",
            "parameters" => Dict{String,Any}(
                "coil_count" => _plrmr_q(spec.cell_count, "1";
                    basis = "one driven barrier per bucket"),
                "mirror_ratio" => _plrmr_q(spec.mirror_ratio, "1";
                    basis = "screening hypothesis"),
                "drive_frequency" => _plrmr_q(spec.drive_frequency_Hz, "Hz";
                    basis = "screening hypothesis")),
            "material" => "conceptual radiation-tolerant pulsed winding")]
    total_drive_W = spec.cell_count * spec.drive_power_per_cell_MW * 1.0e6
    raw["actuators"] = Any[
        Dict{String,Any}(
            "id" => "polyphase_barrier_drive",
            "kind" => "phase_locked_traveling_mirror_drive",
            "parameters" => Dict{String,Any}(
                "power" => _plrmr_q(total_drive_W, "W";
                    basis = "all cells, explicit recirculating-power debit"),
                "frequency" => _plrmr_q(spec.drive_frequency_Hz, "Hz";
                    basis = "screening hypothesis"),
                "phase_step" => _plrmr_q(2pi / spec.cell_count, "rad";
                    basis = "uniform directed handoff phase")))]
    raw["compression_systems"] = Any[]
    raw["stability_mechanisms"] = Any[
        Dict{String,Any}(
            "id" => "phase_locked_bucket_handoff",
            "mechanism" => "time_periodic_adiabatic_bucket_handoff",
            "target_modes" => ["axial_end_loss", "phase_slip", "bucket_dephasing"],
            "actuator_ids" => ["polyphase_barrier_drive"],
            "assumptions" => [
                "per-cell handoff survival is a free hypothesis, not measured evidence",
                "locally open field lines receive no closed-surface confinement credit",
                "cross-field transport and collective stability are not solved"],
            "required_evaluators" => [
                "time_dependent_maxwell", "guiding_center_bucket_handoff",
                "phase_error_sensitivity", "kinetic_stability_spectrum"],
            "source_ids" => ["mirror_post_review_1987"]),
        Dict{String,Any}(
            "id" => "distributed_dephased_exhaust",
            "mechanism" => "phase_selective_loss_collection",
            "target_modes" => ["uncontrolled_wall_interception", "helium_ash_accumulation"],
            "actuator_ids" => ["polyphase_barrier_drive"],
            "assumptions" => ["lost packets can be directed to distributed collectors"],
            "required_evaluators" => ["wall_interception_map", "direct_energy_recovery"],
            "source_ids" => ["mirror_post_review_1987"])]
    links = Any[]
    for i in 1:spec.cell_count
        j = mod1(i + 1, spec.cell_count)
        push!(links, Dict{String,Any}(
            "from_region_id" => "bucket_cell_$(lpad(i, 2, '0'))",
            "to_region_id" => "bucket_cell_$(lpad(j, 2, '0'))",
            "kind" => "phase_gated_open_field_handoff"))
        push!(links, Dict{String,Any}(
            "from_region_id" => "bucket_cell_$(lpad(i, 2, '0'))",
            "to_region_id" => "dephased_exhaust",
            "kind" => "controlled_dephased_particle_exhaust"))
    end
    raw["flux_connections"] = links
    raw["exhaust"] = Dict{String,Any}(
        "kind" => "distributed_phase_selective_collectors",
        "region_ids" => ["dephased_exhaust"],
        "evaluation_requirements" => [
            "phase_resolved_particle_loss", "collector_heat_flux",
            "direct_energy_recovery", "helium_ash_exhaust"])
    raw["engineering"] = Dict{String,Any}(
        "magnet_technology" => [
            "conceptual superconducting static guide array",
            "conceptual fast pulsed barrier array"],
        "blanket" => Dict{String,Any}(
            "required" => false, "concept" => nothing),
        "maintenance" => Dict{String,Any}(
            "architecture" => "distributed replaceable cell sectors",
            "access_paths" => ["radial access between adjacent cell coils"]),
        "required_evaluators" => [
            "finite_build_coils", "switching_loss", "quench",
            "neutronics", "structural_fea", "remote_maintenance"])
    raw["provenance"] = Dict{String,Any}(
        "origin" => "human_authored",
        "source_ids" => ["mirror_post_review_1987"],
        "parent_design_ids" => [parent.design_id],
        "claim_level" => "mechanism_hypothesis_stage_screen",
        "notes" => [
            "The cyclic phase-locked handoff mechanism is a new project hypothesis, not a literature-backed performance claim.",
            "A bounded prior-art search found related traveling-mirror, multiple-mirror, cusp and recirculating-field concepts; patent novelty is not established.",
            "No empirical confinement scaling from tokamaks, stellarators, mirrors, or FRCs is used for promotion."])
    provisional = parse_genome(raw)
    raw["design_id"] = "plrmr_v1_$(provisional.physics_hash[1:16])"
    genome = parse_genome(raw)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError("invalid PLRMR genome: " * join(report.errors, "; ")))
    family_registry = FamilyExtensionRegistry()
    register_extension!(family_registry, phase_locked_mirror_ring_family_extension_v1())
    family_report = validate_family(family_registry, genome)
    family_report.valid || throw(ArgumentError("invalid PLRMR family overlay: " *
        join(family_report.errors, "; ")))
    return genome
end

function _plrmr_reactivity_v1(temperature_keV::Float64)
    # Log-linear D-T screening table, intentionally only a rough 0-D proxy.
    temperatures = [5.0, 10.0, 15.0, 20.0, 30.0]
    values = [1.3e-23, 1.1e-22, 2.7e-22, 4.2e-22, 6.0e-22]
    t = clamp(temperature_keV, first(temperatures), last(temperatures))
    hi = findfirst(x -> x >= t, temperatures)
    hi == 1 && return first(values)
    lo = hi - 1
    f = (t - temperatures[lo]) / (temperatures[hi] - temperatures[lo])
    return exp(log(values[lo]) + f * (log(values[hi]) - log(values[lo])))
end

function _plrmr_spec_matches_genome_v1(genome::Genome,
        spec::PhaseLockedMirrorRingSpecV1)
    target(name) = get(genome.mission.targets, name, nothing)
    guide = quantity(genome, :field_sources, "static_ring_guide_array", "guide_field")
    radius = quantity(genome, :field_sources, "static_ring_guide_array", "ring_major_radius")
    mirror = quantity(genome, :field_sources, "traveling_mirror_barrier_array", "mirror_ratio")
    drive = quantity(genome, :actuators, "polyphase_barrier_drive", "power")
    frequency = quantity(genome, :actuators, "polyphase_barrier_drive", "frequency")
    expected_temperature_J = spec.ion_temperature_keV * 1.0e3 * 1.602176634e-19
    cell_count = count(region -> startswith(region.id, "bucket_cell_"),
        genome.plasma_regions)
    pairs = (
        (target("ion_temperature"), expected_temperature_J),
        (target("beta"), spec.beta),
        (target("handoff_survival"), spec.handoff_survival),
        (target("recovery_efficiency"), spec.recovery_efficiency),
        (guide, spec.guide_field_T),
        (radius, spec.ring_major_radius_m),
        (mirror, spec.mirror_ratio),
        (drive, spec.cell_count * spec.drive_power_per_cell_MW * 1.0e6),
        (frequency, spec.drive_frequency_Hz))
    return cell_count == spec.cell_count && all(item ->
        item[1] !== nothing && isapprox(item[1].value, item[2]; rtol = 1e-12,
            atol = 1e-15), pairs)
end

function evaluate_phase_locked_mirror_ring_stage_v1(genome::Genome,
        spec::PhaseLockedMirrorRingSpecV1 = default_phase_locked_mirror_ring_spec_v1();
        contract::StageClosureContractV1 = default_stage_closure_contract_v1())
    genome.family == "phase_locked_reciprocal_mirror_ring" ||
        throw(ArgumentError("stage evaluator requires a PLRMR genome"))
    _plrmr_spec_matches_genome_v1(genome, spec) || throw(ArgumentError(
        "PLRMR evaluator spec does not match the encoded Genome inputs"))
    mu0 = 4pi * 1.0e-7
    dt_energy_J = 17.6e6 * 1.602176634e-19
    mean_ion_mass_kg = 2.5 * 1.66053906660e-27
    temperature_J = spec.ion_temperature_keV * 1.0e3 * 1.602176634e-19
    pressure_Pa = spec.beta * spec.guide_field_T^2 / (2mu0)
    ion_density_m3 = pressure_Pa / (2temperature_J)
    volume_m3 = 2pi * spec.ring_major_radius_m * pi * spec.tube_radius_m^2
    thermal_inventory_MJ = 1.5 * pressure_Pa * volume_m3 / 1.0e6
    thermal_speed_m_s = sqrt(2temperature_J / mean_ion_mass_kg)
    circuit_time_s = 2pi * spec.ring_major_radius_m / thermal_speed_m_s
    circuit_survival = spec.handoff_survival^spec.cell_count
    confinement_time_s = circuit_time_s / max(1.0 - circuit_survival, eps())
    loss_power_MW = thermal_inventory_MJ / confinement_time_s
    reactivity_m3_s = _plrmr_reactivity_v1(spec.ion_temperature_keV)
    fusion_power_MW = (ion_density_m3^2 / 4) * reactivity_m3_s *
        dt_energy_J * volume_m3 / 1.0e6
    alpha_heating_MW = 0.2 * fusion_power_MW
    unrecovered_loss_MW = max(0.0, loss_power_MW - alpha_heating_MW) *
        (1.0 - spec.recovery_efficiency)
    plasma_heating_wallplug_MW = unrecovered_loss_MW / 0.70
    drive_power_MW = spec.cell_count * spec.drive_power_per_cell_MW
    cryogenic_and_aux_MW = 0.30 * drive_power_MW
    recirculating_power_MW = plasma_heating_wallplug_MW + drive_power_MW +
        cryogenic_and_aux_MW
    gross_electric_MW = 0.35 * fusion_power_MW
    net_electric_MW = gross_electric_MW - recirculating_power_MW
    gain_proxy = plasma_heating_wallplug_MW > 0 ?
        fusion_power_MW / plasma_heating_wallplug_MW : Inf
    recirc_ratio = fusion_power_MW > 0 ? recirculating_power_MW / fusion_power_MW : Inf
    gates = Dict{String,Bool}(
        "finite_energy_ledger" => all(isfinite, [fusion_power_MW,
            recirculating_power_MW, net_electric_MW]),
        "gain_proxy_floor" => gain_proxy >= contract.minimum_fusion_gain_proxy,
        "relaxed_net_electric_floor" => net_electric_MW >= contract.minimum_net_electric_MW,
        "recirculating_ratio_cap" => recirc_ratio <= contract.maximum_recirc_to_fusion_ratio)
    passed = all(values(gates))
    result = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "interface_contract_id" => "fusion_stage_control_interface_v1",
        "case_id" => genome.design_id,
        "case_role" => "novel_mechanism_candidate",
        "family" => genome.family,
        "stage_contract" => Dict{String,Any}(
            "id" => contract.id,
            "minimum_fusion_gain_proxy" => contract.minimum_fusion_gain_proxy,
            "minimum_net_electric_MW" => contract.minimum_net_electric_MW,
            "maximum_recirc_to_fusion_ratio" => contract.maximum_recirc_to_fusion_ratio),
        "model" => Dict{String,Any}(
            "kind" => "candidate_specific_zero_dimensional_bucket_survival_ledger",
            "fidelity" => 0,
            "empirical_family_scaling_used" => false,
            "measured_candidate_calibration_used" => false),
        "physics" => Dict{String,Any}(
            "volume_m3" => volume_m3,
            "pressure_Pa" => pressure_Pa,
            "ion_density_m3" => ion_density_m3,
            "thermal_inventory_MJ" => thermal_inventory_MJ,
            "circuit_time_s" => circuit_time_s,
            "circuit_survival" => circuit_survival,
            "confinement_time_proxy_s" => confinement_time_s,
            "dt_reactivity_proxy_m3_s" => reactivity_m3_s),
        "energy_ledger_MW" => Dict{String,Any}(
            "fusion" => fusion_power_MW,
            "alpha_heating" => alpha_heating_MW,
            "thermal_loss" => loss_power_MW,
            "plasma_heating_wallplug" => plasma_heating_wallplug_MW,
            "phase_drive" => drive_power_MW,
            "cryogenic_and_auxiliary" => cryogenic_and_aux_MW,
            "recirculating_total" => recirculating_power_MW,
            "gross_electric_proxy" => gross_electric_MW,
            "net_electric_proxy" => net_electric_MW),
        "metrics" => Dict{String,Any}(
            "fusion_gain_proxy" => gain_proxy,
            "recirculating_to_fusion_ratio" => recirc_ratio),
        "gates" => gates,
        "stage_status" => passed ? "conditional_pass" : "fail",
        "claim_ceiling" => "computational_stage_closure_only",
        "blocking_unknowns" => [
            "attainable per-cell handoff survival",
            "phase-error and switching-loss distributions",
            "cross-field transport and kinetic/MHD stability",
            "self-consistent time-dependent fields and plasma back-reaction",
            "collector heat flux, direct recovery, blanket and maintenance feasibility"])
    result["result_hash"] = canonical_hash(result)
    return result
end

"""Small deterministic hypothesis sweep; it cannot promote a candidate."""
function search_phase_locked_mirror_ring_stage_v1(parent::Genome;
        contract::StageClosureContractV1 = default_stage_closure_contract_v1())
    records = Dict{String,Any}[]
    for survival in (0.999990, 0.999995, 0.999997),
            recovery in (0.60, 0.70, 0.80), drive in (0.30, 0.35)
        spec = PhaseLockedMirrorRingSpecV1(12, 5.0, 0.45, 4.5, 3.5,
            12.0, 0.025, survival, recovery, drive, 36_000.0)
        genome = build_phase_locked_mirror_ring_genome_v1(parent, spec)
        evaluation = evaluate_phase_locked_mirror_ring_stage_v1(genome, spec;
            contract = contract)
        push!(records, Dict{String,Any}(
            "spec" => Dict{String,Any}(
                "handoff_survival" => survival,
                "recovery_efficiency" => recovery,
                "drive_power_per_cell_MW" => drive),
            "genome" => genome,
            "evaluation" => evaluation))
    end
    sort!(records; by = item -> (
        item["evaluation"]["stage_status"] == "conditional_pass" ? 0 : 1,
        -item["evaluation"]["energy_ledger_MW"]["net_electric_proxy"],
        item["genome"].design_id))
    return Dict{String,Any}(
        "search_kind" => "bounded_hypothesis_sweep",
        "candidate_count" => length(records),
        "conditional_pass_count" => count(item ->
            item["evaluation"]["stage_status"] == "conditional_pass", records),
        "selected" => first(records),
        "records" => records)
end

function evaluate_iter_stage_control_v1(iter::Genome)
    field = quantity(iter, :field_sources, "tokamak_tf_system", "on_axis_field")
    current = quantity(iter, :field_sources, "tokamak_plasma_current", "total_current")
    radius = quantity(iter, :plasma_regions, "tokamak_core", "major_radius")
    checks = Dict{String,Bool}(
        "typed_genome_valid" => validate_genome(iter).valid,
        "family_is_tokamak" => iter.family == "tokamak_axisymmetric",
        "on_axis_field_5_3T" => field !== nothing && isapprox(field.value, 5.3; atol = 1e-9),
        "plasma_current_15MA" => current !== nothing && isapprox(current.value, 15e6; atol = 1.0),
        "major_radius_6_2m" => radius !== nothing && isapprox(radius.value, 6.2; atol = 1e-9))
    result = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "interface_contract_id" => "fusion_stage_control_interface_v1",
        "case_id" => "ITER_public_design_control",
        "case_role" => "known_framework_positive_control",
        "family" => iter.family,
        "representation_checks" => checks,
        "published_anchor" => Dict{String,Any}(
            "fusion_power_MW" => 500.0,
            "external_heating_MW" => 50.0,
            "plasma_gain_Q" => 10.0,
            "status" => "design_goal_not_achieved_measurement",
            "source_urls" => [
                "https://www.iter.org/facts-figures",
                "https://www.iter.org/faqs?thematic=68"]),
        "energy_ledger_MW" => Dict{String,Any}(
            "fusion" => 500.0,
            "external_plasma_heating" => 50.0,
            "net_electric" => nothing),
        "stage_status" => all(values(checks)) ? "control_pass" : "fail",
        "claim_ceiling" => "representation_and_public_design_anchor_control",
        "blocking_unknowns" => [
            "ITER is not an electric-power plant, so net electric output is not inferred",
            "design goals are not treated as achieved measurements"])
    result["result_hash"] = canonical_hash(result)
    return result
end

function evaluate_c2w_stage_control_v1(c2w::Genome)
    nbi = filter(item -> item.kind == "neutral_beam_injector", c2w.actuators)
    source_ids = Set(vcat(c2w.provenance.source_ids,
        reduce(vcat, getfield.(c2w.stability_mechanisms, :source_ids);
            init = String[])))
    checks = Dict{String,Bool}(
        "typed_genome_valid" => validate_genome(c2w).valid,
        "family_is_frc" => c2w.family == "field_reversed_configuration",
        "beam_actuation_explicit" => !isempty(nbi),
        "open_end_exhaust_explicit" => any(connection ->
            connection.kind == "open_field_line", c2w.flux_connections),
        "c2w_source_boundary_attached" => "frc_c2w_gota_2024" in source_ids)
    result = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "interface_contract_id" => "fusion_stage_control_interface_v1",
        "case_id" => "C-2W_beam_driven_FRC_control",
        "case_role" => "experiment_mechanism_positive_control",
        "family" => c2w.family,
        "representation_checks" => checks,
        "published_anchor" => Dict{String,Any}(
            "sustainment_duration_ms" => 40.0,
            "status" => "reported_up_to_neutral_beam_pulse_limit",
            "duration_is_energy_confinement_time" => false,
            "source_url" => "https://doi.org/10.1088/1741-4326/ad4536"),
        "energy_ledger_MW" => Dict{String,Any}(
            "fusion" => nothing, "beam_input" => nothing,
            "net_electric" => nothing),
        "stage_status" => all(values(checks)) ? "control_pass" : "fail",
        "claim_ceiling" => "representation_and_published_mechanism_control",
        "blocking_unknowns" => [
            "the ~40 ms sustainment duration is not tau_E",
            "the control does not establish reactor extrapolation or net power"])
    result["result_hash"] = canonical_hash(result)
    return result
end
