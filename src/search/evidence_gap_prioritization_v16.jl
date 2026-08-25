"One bounded evidence-development or verification action for a promotion gate."
struct EvidenceGapTaskSpecV16
    id::String
    families::Set{String}
    mechanisms::Set{String}
    gate_ids::Vector{String}
    evidence_entry_ids::Vector{String}
    action_kind::Symbol
    backend_status::Symbol
    cost_units::Float64
    falsification_leverage::Float64
    candidate_specific::Bool
    claim_boundary::String

    function EvidenceGapTaskSpecV16(id::AbstractString, families, mechanisms,
            gate_ids, evidence_entry_ids, action_kind::Symbol,
            backend_status::Symbol, cost_units::Real,
            falsification_leverage::Real, candidate_specific::Bool,
            claim_boundary::AbstractString)
        action_kind in (:full_text_transfer_audit,
            :candidate_specific_model_validation,
            :integrated_component_validation,
            :new_experimental_program) ||
            throw(ArgumentError("unsupported v16 evidence action $action_kind"))
        backend_status in (:executable, :development_required, :blocked_external) ||
            throw(ArgumentError("unsupported v16 backend status $backend_status"))
        cost_units > 0 || throw(ArgumentError("v16 task cost must be positive"))
        0 < falsification_leverage <= 1 || throw(ArgumentError(
            "v16 falsification leverage must be in (0,1]"))
        family_set = Set(String.(collect(families)))
        mechanism_set = Set(String.(collect(mechanisms)))
        gates = sort!(unique(String.(collect(gate_ids))))
        entries = sort!(unique(String.(collect(evidence_entry_ids))))
        any(isempty, (family_set, mechanism_set, gates)) && throw(ArgumentError(
            "v16 task families, mechanisms, and gates must not be empty"))
        isempty(claim_boundary) && throw(ArgumentError(
            "v16 task claim boundary must not be empty"))
        return new(String(id), family_set, mechanism_set, gates, entries,
            action_kind, backend_status, Float64(cost_units),
            Float64(falsification_leverage), candidate_specific,
            String(claim_boundary))
    end
end

"A compact cross-stage candidate view used only for evidence routing."
struct EvidenceFrontierCandidateV16
    candidate_id::String
    source_stage::String
    physics_hash::String
    family::String
    mechanism::String
    contract_id::String
    mission_contract_id::String
    disposition::String
    gap_ids::Vector{String}
    positive_net_power_closure_passed::Bool
    all_five_gates_passed::Bool
    minimum_normalized_margin::Float64
end

struct EvidenceGapPriorityV16
    rank::Int
    task_id::String
    families::Vector{String}
    mechanisms::Vector{String}
    gate_ids::Vector{String}
    action_kind::Symbol
    backend_status::Symbol
    evidence_status::String
    candidate_count::Int
    active_candidate_count::Int
    parked_candidate_count::Int
    structural_stratum_count::Int
    cost_units::Float64
    falsification_leverage::Float64
    heuristic_information_value::Float64
    selected::Bool
    candidate_specific::Bool
    claim_boundary::String
end

struct EvidenceGapPrioritizationResultV16
    candidates::Vector{EvidenceFrontierCandidateV16}
    priorities::Vector{EvidenceGapPriorityV16}
    selected_task_ids::Vector{String}
    spent_cost_units::Float64
    budget_units::Float64
    family_extension_manifest::Dict{String,Any}
    mission_contract_manifest::Dict{String,Any}
    quantitative_evidence_table_hash::String
    input_v14_result_hash::String
    input_v15_result_hash::String
    claim_boundary::String
end

function legacy_search_family_extension_v16()
    specs = FamilySpec[
        FamilySpec("inertial_electrostatic_confinement",
            Set(["electrostatic_radial"]), Set(["none"]),
            "finite spherical electrostatic grid and radial loss chart",
            ["iec_poisson_orbit_grid_model",
                "nonequilibrium_fokker_planck_power"], "structural_only"),
        FamilySpec("dense_plasma_focus", Set(["coaxial_pulsed_pinch"]),
            Set(["axisymmetric"]),
            "finite coaxial sheath, pinch, electrode, and pulse-energy chart",
            ["kinetic_dpf_and_electrode_model"], "structural_only"),
        FamilySpec("high_beta_magnetic_cusp", Set(["open_cusp"]),
            Set(["none", "axisymmetric"]),
            "explicit finite cusp coils, collectors, and ambipolar loss chart",
            ["high_beta_kinetic_pic", "ambipolar_potential_solver"],
            "structural_only"),
    ]
    return FamilyExtensionPackage("legacy_search_families_v16", "1.0.0",
        "cross_family_legacy_extension_v16", specs,
        ["iec_hirsch_1967", "dpf_kinetic_schmidt_2012",
            "high_beta_cusp_park_2015"],
        "Registry declarations only. They preserve prior search-family semantics " *
        "and grant no new physics, engineering, or promotion credit.")
end

function evidence_family_registry_v16()
    registry = FamilyExtensionRegistry()
    register_extension!(registry, legacy_search_family_extension_v16())
    register_extension!(registry, laser_icf_family_extension_v15())
    return registry
end

function default_evidence_gap_tasks_v16()
    bounded = "Planning task only; completion does not grant promotion unless " *
        "candidate-specific applicability, uncertainty, and independent review are recorded."
    icf = ["inertial_confinement_fusion"]
    all_icf = ["*"]
    mirror = ["magnetic_mirror"]
    two_component = ["two_component_gdt", "two_component_gdmt"]
    iec = ["inertial_electrostatic_confinement"]
    return EvidenceGapTaskSpecV16[
        EvidenceGapTaskSpecV16("icf_indirect_target_gain_validation_v16", icf,
            ["laser_indirect_drive"], ["target_gain_experimental_validation"],
            ["icf_nif_target_gain_lower_bound",
                "icf_indirect_drive_searched_target_gain"],
            :candidate_specific_model_validation, :development_required,
            8.0, 1.0, true, bounded),
        EvidenceGapTaskSpecV16("icf_direct_target_gain_lpi_validation_v16", icf,
            ["laser_direct_drive"],
            ["target_gain_experimental_validation", "laser_plasma_interaction"],
            ["icf_direct_drive_searched_target_gain"],
            :candidate_specific_model_validation, :development_required,
            8.0, 1.0, true, bounded),
        EvidenceGapTaskSpecV16("icf_fast_ignition_gain_transport_validation_v16", icf,
            ["laser_fast_ignition"],
            ["target_gain_experimental_validation", "fast_ignition_transport"],
            ["icf_fast_ignition_searched_target_gain"],
            :candidate_specific_model_validation, :development_required,
            8.0, 1.0, true, bounded),
        EvidenceGapTaskSpecV16("icf_repeat_rate_driver_integrated_validation_v16",
            icf, all_icf, ["driver_wall_plug_and_repeat_rate_validation"],
            ["icf_repeat_rate_driver_wall_plug_validation"],
            :integrated_component_validation, :blocked_external,
            8.0, 0.98, true, bounded),
        EvidenceGapTaskSpecV16("icf_target_factory_throughput_validation_v16",
            icf, all_icf, ["target_factory_throughput_and_yield_validation"],
            ["icf_target_factory_throughput_validation"],
            :integrated_component_validation, :blocked_external,
            5.0, 0.78, true, bounded),
        EvidenceGapTaskSpecV16("icf_pulsed_chamber_clearing_validation_v16",
            icf, all_icf, ["pulsed_chamber_clearing"],
            ["icf_injection_and_chamber_clearing_validation"],
            :integrated_component_validation, :development_required,
            5.0, 0.82, true, bounded),
        EvidenceGapTaskSpecV16("icf_first_wall_final_optics_lifetime_validation_v16",
            icf, all_icf, ["first_wall_and_final_optics_lifetime_validation"],
            ["icf_first_wall_and_final_optics_lifetime"],
            :new_experimental_program, :blocked_external,
            8.0, 0.92, true, bounded),
        EvidenceGapTaskSpecV16("gdt_fast_ion_source_transfer_audit_v16", mirror,
            two_component, ["gdt_fast_ion_relaxation"],
            ["gdt_fast_ion_relaxation_time_range"],
            :full_text_transfer_audit, :executable,
            1.0, 0.72, false, bounded),
        EvidenceGapTaskSpecV16("gdt_two_component_distribution_validation_v16",
            mirror, two_component,
            ["two_component_fokker_planck_gdt", "anisotropic_mirror_equilibrium"],
            ["gdt_two_component_non_maxwellian_equilibrium"],
            :candidate_specific_model_validation, :development_required,
            5.0, 0.96, true, bounded),
        EvidenceGapTaskSpecV16("gdt_end_loss_and_conversion_validation_v16",
            mirror, two_component, ["exhaust", "open_end_loss_conversion"],
            ["gdt_end_loss_exhaust_conversion"],
            :candidate_specific_model_validation, :development_required,
            5.0, 0.88, true, bounded),
        EvidenceGapTaskSpecV16("iec_power_ceiling_full_text_audit_v16", iec,
            ["gridded_iec_net_electric_candidate"],
            ["iec_power_closure_gate", "nonequilibrium_recirculating_power"],
            ["iec_fusion_to_input_energy_ceiling"],
            :full_text_transfer_audit, :executable,
            1.0, 0.98, false, bounded),
    ]
end

function _v16_validate_task_catalog(tasks::Vector{EvidenceGapTaskSpecV16},
        table::QuantitativeEvidenceTable)
    ids = getfield.(tasks, :id)
    length(unique(ids)) == length(ids) ||
        throw(ArgumentError("duplicate v16 task IDs"))
    evidence_ids = Set(getfield.(table.entries, :id))
    for task in tasks
        missing = sort!(collect(setdiff(Set(task.evidence_entry_ids), evidence_ids)))
        isempty(missing) || throw(ArgumentError(
            "task $(task.id) references missing evidence entries: $(join(missing, ", "))"))
    end
    return true
end

function _v16_get_bool(record, key::String)
    value = get(record, key, false)
    value isa Bool || throw(ArgumentError("$key must be boolean"))
    return value
end

function _v16_v14_candidates(v14, mission_registry::MissionContractRegistry,
        family_registry::FamilyExtensionRegistry)
    records = v14["hierarchical_gate_discovery"]["active_records"]
    result = EvidenceFrontierCandidateV16[]
    for record in records
        _v16_get_bool(record, "promotion_eligible") || continue
        _v16_get_bool(record, "anchor_only") && continue
        family = String(record["core_family"])
        family in ("magnetic_mirror", "inertial_electrostatic_confinement") ||
            continue
        family_spec(family_registry, family) === nothing &&
            throw(ArgumentError("v14 frontier family is unregistered: $family"))
        mission = MissionSpec("net_electric_pilot", "D-T", "steady_state",
            Dict{String,Quantity}())
        mission_contract = mission_contract_for(mission_registry, mission, family)
        positive = _v16_get_bool(record, "positive_net_power_closure_passed")
        five = _v16_get_bool(record, "all_five_gates_passed")
        mechanism = String(record["mechanism"])
        gaps = family == "magnetic_mirror" ?
            ["gdt_fast_ion_relaxation", "two_component_fokker_planck_gdt",
                "anisotropic_mirror_equilibrium", "exhaust",
                "open_end_loss_conversion"] :
            ["iec_power_closure_gate", "nonequilibrium_recirculating_power"]
        nominal = record["evaluation"]["nominal"]
        push!(result, EvidenceFrontierCandidateV16(
            String(record["physics_hash"]), "hierarchical_gate_discovery_v14",
            String(record["physics_hash"]), family, mechanism,
            String(record["contract_id"]), mission_contract.id,
            positive ? "conditional_evidence_frontier" :
                "parked_negative_net_at_fidelity0",
            sort!(gaps), positive, five,
            Float64(nominal["minimum_normalized_margin"])))
    end
    return result
end

function _v16_v15_candidates(v15, mission_registry::MissionContractRegistry,
        family_registry::FamilyExtensionRegistry)
    result = EvidenceFrontierCandidateV16[]
    for record in v15["conditional_frontier"]
        genome = parse_genome(record["genome"])
        family_report = validate_family(family_registry, genome)
        family_report.valid || throw(ArgumentError(join(family_report.errors, "; ")))
        mission_contract = mission_contract_for(mission_registry, genome)
        path = String(record["drive_path"])
        gaps = ["target_gain_experimental_validation",
            "driver_wall_plug_and_repeat_rate_validation",
            "target_factory_throughput_and_yield_validation",
            "pulsed_chamber_clearing",
            "first_wall_and_final_optics_lifetime_validation"]
        push!(gaps, path == "laser_fast_ignition" ?
            "fast_ignition_transport" : "laser_plasma_interaction")
        nominal = record["evaluation"]["nominal"]
        positive = _v16_get_bool(record,
            "positive_average_net_power_closure_passed")
        five = _v16_get_bool(record, "all_five_gates_passed")
        push!(result, EvidenceFrontierCandidateV16(
            String(record["design_id"]), "laser_icf_qd_v15",
            String(record["physics_hash"]), String(genome.family), path,
            String(record["contract_id"]), mission_contract.id,
            positive ? "conditional_evidence_frontier" :
                "parked_negative_net_at_fidelity0",
            sort!(gaps), positive, five,
            Float64(nominal["minimum_normalized_margin"])))
    end
    return result
end

function _v16_task_matches(task::EvidenceGapTaskSpecV16,
        candidate::EvidenceFrontierCandidateV16)
    candidate.family in task.families || return false
    ("*" in task.mechanisms || candidate.mechanism in task.mechanisms) ||
        return false
    return !isempty(intersect(Set(candidate.gap_ids), Set(task.gate_ids)))
end

function _v16_evidence_status(task::EvidenceGapTaskSpecV16,
        table::QuantitativeEvidenceTable)
    entries = filter(entry -> entry.id in task.evidence_entry_ids, table.entries)
    isempty(entries) && return "uncatalogued_gap"
    any(entry -> entry.promotion_credit, entries) &&
        return "promotion_credit_available"
    direct = filter(entry -> entry.evidence_provenance !=
        "no_direct_measurement", entries)
    missing = filter(entry -> entry.evidence_provenance ==
        "no_direct_measurement", entries)
    isempty(direct) && return "gap_record_only"
    isempty(missing) && return "nonpromotable_anchor_or_model_only"
    return "anchor_and_gap_records_only"
end

function _v16_gap_weight(status::String)
    return status == "promotion_credit_available" ? 0.0 :
        status == "nonpromotable_anchor_or_model_only" ? 0.45 :
        status == "anchor_and_gap_records_only" ? 0.95 : 1.0
end

function _v16_backend_weight(status::Symbol)
    return status == :executable ? 1.0 :
        status == :development_required ? 0.80 : 0.35
end

function _v16_priority_seed(task::EvidenceGapTaskSpecV16,
        candidates::Vector{EvidenceFrontierCandidateV16},
        table::QuantitativeEvidenceTable)
    matching = filter(candidate -> _v16_task_matches(task, candidate), candidates)
    active = count(candidate -> candidate.disposition ==
        "conditional_evidence_frontier", matching)
    parked = length(matching) - active
    strata = length(unique("$(candidate.family)|$(candidate.mechanism)|" *
        candidate.contract_id for candidate in matching))
    active_strata = length(unique("$(candidate.family)|$(candidate.mechanism)|" *
        candidate.contract_id for candidate in matching if
        candidate.disposition == "conditional_evidence_frontier"))
    parked_strata = strata - active_strata
    status = _v16_evidence_status(task, table)
    weighted_frontier = active + 0.01 * parked
    coverage_term = log1p(weighted_frontier) +
        0.25 * (sqrt(active_strata) + 0.02 * sqrt(parked_strata))
    value = task.falsification_leverage * _v16_gap_weight(status) *
        _v16_backend_weight(task.backend_status) * coverage_term /
        task.cost_units
    return (task = task, evidence_status = status,
        candidate_count = length(matching), active = active, parked = parked,
        strata = strata, value = value)
end

function run_evidence_gap_prioritization_v16(v14_input, v15_input,
        table::QuantitativeEvidenceTable;
        budget_units::Real = 30.0,
        tasks::Vector{EvidenceGapTaskSpecV16} = default_evidence_gap_tasks_v16(),
        family_registry::FamilyExtensionRegistry = evidence_family_registry_v16(),
        mission_registry::MissionContractRegistry =
            default_mission_contract_registry())
    budget_units > 0 || throw(ArgumentError("v16 budget must be positive"))
    _v16_validate_task_catalog(tasks, table)
    v14 = _plain_json(v14_input)
    v15 = _plain_json(v15_input)
    candidates = vcat(_v16_v14_candidates(v14, mission_registry,
            family_registry),
        _v16_v15_candidates(v15, mission_registry, family_registry))
    isempty(candidates) && throw(ArgumentError("v16 received no frontier candidates"))
    length(unique(candidate.candidate_id for candidate in candidates)) ==
        length(candidates) || throw(ArgumentError("duplicate v16 candidate IDs"))

    seeds = [_v16_priority_seed(task, candidates, table) for task in tasks]
    sort!(seeds; by = item -> (-item.value, item.task.id))
    selected = String[]
    spent = 0.0
    for item in seeds
        item.active > 0 || continue
        item.evidence_status == "promotion_credit_available" && continue
        if spent + item.task.cost_units <= Float64(budget_units) + 1.0e-12
            push!(selected, item.task.id)
            spent += item.task.cost_units
        end
    end
    priorities = EvidenceGapPriorityV16[]
    for (rank, item) in enumerate(seeds)
        push!(priorities, EvidenceGapPriorityV16(rank, item.task.id,
            sort!(collect(item.task.families)),
            sort!(collect(item.task.mechanisms)), copy(item.task.gate_ids),
            item.task.action_kind, item.task.backend_status,
            item.evidence_status, item.candidate_count, item.active, item.parked,
            item.strata, item.task.cost_units, item.task.falsification_leverage,
            item.value, item.task.id in selected,
            item.task.candidate_specific, item.task.claim_boundary))
    end
    claim = "Deterministic evidence-gap routing over sealed v14/v15 frontier " *
        "records. heuristic_information_value is a triage score, not a Bayesian " *
        "probability, expected scientific value, or evidence of feasibility. " *
        "Negative-net magnetic records remain parked; selected tasks authorize " *
        "evidence development or source verification only, never medium-fidelity " *
        "promotion."
    return EvidenceGapPrioritizationResultV16(candidates, priorities,
        selected, spent, Float64(budget_units),
        family_extension_manifest(family_registry),
        mission_contract_manifest(mission_registry),
        quantitative_evidence_hash(table), String(v14["result_hash"]),
        String(v15["result_hash"]), claim)
end

function _v16_candidate_to_dict(candidate::EvidenceFrontierCandidateV16)
    return Dict{String,Any}(
        "candidate_id" => candidate.candidate_id,
        "source_stage" => candidate.source_stage,
        "physics_hash" => candidate.physics_hash,
        "family" => candidate.family,
        "mechanism" => candidate.mechanism,
        "contract_id" => candidate.contract_id,
        "mission_contract_id" => candidate.mission_contract_id,
        "disposition" => candidate.disposition,
        "gap_ids" => copy(candidate.gap_ids),
        "positive_net_power_closure_passed" =>
            candidate.positive_net_power_closure_passed,
        "all_five_gates_passed" => candidate.all_five_gates_passed,
        "minimum_normalized_margin" => candidate.minimum_normalized_margin,
    )
end

function _v16_priority_to_dict(item::EvidenceGapPriorityV16)
    return Dict{String,Any}(
        "rank" => item.rank,
        "task_id" => item.task_id,
        "families" => copy(item.families),
        "mechanisms" => copy(item.mechanisms),
        "gate_ids" => copy(item.gate_ids),
        "action_kind" => String(item.action_kind),
        "backend_status" => String(item.backend_status),
        "evidence_status" => item.evidence_status,
        "candidate_count" => item.candidate_count,
        "active_candidate_count" => item.active_candidate_count,
        "parked_candidate_count" => item.parked_candidate_count,
        "structural_stratum_count" => item.structural_stratum_count,
        "cost_units" => item.cost_units,
        "falsification_leverage" => item.falsification_leverage,
        "heuristic_information_value" => item.heuristic_information_value,
        "selected" => item.selected,
        "candidate_specific" => item.candidate_specific,
        "claim_boundary" => item.claim_boundary,
    )
end

function evidence_gap_prioritization_to_dict(
        result::EvidenceGapPrioritizationResultV16)
    dispositions = Dict{String,Int}()
    families = Dict{String,Int}()
    for candidate in result.candidates
        dispositions[candidate.disposition] =
            get(dispositions, candidate.disposition, 0) + 1
        families[candidate.family] = get(families, candidate.family, 0) + 1
    end
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "stage" => "cross_family_evidence_gap_prioritization_v16",
        "algorithm" => "deterministic_falsification_leverage_per_cost_v1",
        "inputs" => Dict(
            "hierarchical_gate_discovery_v14_result_hash" =>
                result.input_v14_result_hash,
            "laser_icf_qd_v15_result_hash" => result.input_v15_result_hash,
            "quantitative_evidence_table_hash" =>
                result.quantitative_evidence_table_hash),
        "family_extension_registry" => Dict(
            "manifest_hash" => canonical_hash(result.family_extension_manifest),
            "manifest" => result.family_extension_manifest),
        "mission_contract_registry" => Dict(
            "manifest_hash" => canonical_hash(result.mission_contract_manifest),
            "manifest" => result.mission_contract_manifest),
        "frontier_summary" => Dict(
            "candidate_count" => length(result.candidates),
            "family_counts" => families,
            "disposition_counts" => dispositions,
            "five_gate_pass_count" => count(candidate ->
                candidate.all_five_gates_passed, result.candidates)),
        "frontier_candidates" => [_v16_candidate_to_dict(candidate) for
            candidate in sort!(copy(result.candidates); by = item ->
                (item.source_stage, item.family, item.mechanism,
                    item.contract_id, item.candidate_id))],
        "priorities" => _v16_priority_to_dict.(result.priorities),
        "budget" => Dict(
            "budget_units" => result.budget_units,
            "spent_cost_units" => result.spent_cost_units,
            "selected_task_ids" => copy(result.selected_task_ids)),
        "medium_fidelity_decision" => Dict(
            "authorized_candidate_count" => 0,
            "review_queue" => Any[],
            "reason" => "No candidate has independent promotion evidence and all five gates."),
        "claim_boundary" => result.claim_boundary,
    )
end
