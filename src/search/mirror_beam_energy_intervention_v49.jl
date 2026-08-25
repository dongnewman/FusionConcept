const _V49_BEAM_ENERGIES_KEV = [25.0, 100.0, 150.0]

const _V49_CLAIM_BOUNDARY =
    "V49 is an append-only, source-complete algebraic intervention on the 724 " *
    "magnetic-mirror candidates already sealed by v46 and audited by v48. It " *
    "adds one explicit screen_beam_energy gene, synchronizes every NBI actuator " *
    "beam-energy declaration, and consumes that gene in the WHAM-reported " *
    "E_beam^(3/2) classical particle-confinement factor. The framework's use " *
    "of that particle-confinement estimate in an energy-confinement slot is " *
    "not independently validated. All non-beam physical and " *
    "engineering fields are held fixed by a canonical projection. The resulting " *
    "confinement, loss-power, auxiliary-power, net-electric, exhaust, rotation-" *
    "authority, and gate changes are counterfactual screening responses only. " *
    "Effective mirror-ratio semantics, fast-ion distribution, finite-beta " *
    "equilibrium, injection geometry, atomic processes, stability, and held-out " *
    "magnitude validation remain missing. The existing rotation-power term also " *
    "remains an authority margin rather than an added auxiliary-power ledger item. " *
    "Therefore V49 does not authorize performance ranking, a winner, medium " *
    "fidelity, C1, scale-up, superiority, reactor feasibility, or promotion."

_v49_isclose(a::Real, b::Real) = isapprox(Float64(a), Float64(b);
    rtol = 2.0e-12, atol = 1.0e-14)

function _v49_validate_evidence(evidence::AbstractDict)
    String(get(evidence, "catalog_version", "")) ==
        "mirror_beam_energy_intervention_v49_1.0.0" ||
        throw(ArgumentError("v49 evidence catalog identity mismatch"))
    Float64.(evidence["preregistered_beam_energies_keV"]) ==
        _V49_BEAM_ENERGIES_KEV ||
        throw(ArgumentError("v49 beam-energy levels changed"))
    source = evidence["primary_source"]
    String(source["id"]) == "mirror_wham_endrizzi_2023" ||
        throw(ArgumentError("v49 source identity mismatch"))
    Float64(source["beam_energy_exponent"]) == 1.5 ||
        throw(ArgumentError("v49 beam-energy exponent changed"))
    get(evidence, "promotion_credit", true) === false ||
        throw(ArgumentError("v49 evidence must grant zero promotion credit"))
    all(value === false for value in values(evidence["authorization_contract"])) ||
        throw(ArgumentError("v49 authorization contract weakened"))
    return nothing
end

function _v49_beam_energy_keV(genome::Genome)
    target = get(genome.mission.targets, "screen_beam_energy", nothing)
    target === nothing && throw(ArgumentError("v49 beam-energy gene missing"))
    target.unit == "J" || throw(ArgumentError(
        "v49 beam-energy gene must normalize to joules"))
    return target.value / 1.602176634e-16
end

function _v49_nbi_energies_keV(genome::Genome)
    energies = Float64[]
    for actuator in genome.actuators
        occursin("nbi", lowercase(actuator.kind)) || continue
        energy = get(actuator.parameters, "beam_energy", nothing)
        energy === nothing && continue
        energy.unit == "J" || throw(ArgumentError(
            "v49 NBI beam energy must normalize to joules"))
        push!(energies, energy.value / 1.602176634e-16)
    end
    return energies
end

function _v49_mutate_beam_energy(base::Genome, energy_keV::Float64)
    base.family == "magnetic_mirror" || throw(ArgumentError(
        "v49 mutation is restricted to magnetic mirrors"))
    energy_keV in _V49_BEAM_ENERGIES_KEV || throw(ArgumentError(
        "v49 energy is outside the preregistered intervention"))
    raw = deepcopy(base.normalized)
    basis = "v49 preregistered WHAM E_beam^(3/2) intervention"
    _ctv4_set_target!(raw, "screen_beam_energy", energy_keV, "keV";
        basis = basis)
    nbi_count = 0
    for actuator in raw["actuators"]
        occursin("nbi", lowercase(String(actuator["kind"]))) || continue
        haskey(actuator["parameters"], "beam_energy") || continue
        actuator["parameters"]["beam_energy"] =
            _ctv4_quantity(energy_keV, "keV"; basis = basis)
        nbi_count += 1
    end
    nbi_count > 0 || throw(ArgumentError(
        "v49 mirror candidate has no mutable NBI beam-energy declaration"))
    raw["design_id"] = "pending_mirror_beam_energy_v49"
    raw["label"] = "V49 mirror beam-energy intervention $(Int(energy_keV)) keV"
    provenance = raw["provenance"]
    provenance["origin"] = "generated"
    provenance["parent_design_ids"] = [base.design_id]
    provenance["claim_level"] = "C0_source_complete_algebraic_intervention_only"
    notes = get!(provenance, "notes", Any[])
    push!(notes, "v49_beam_energy_gene_and_formula_intervention")
    push!(notes, "zero_promotion_credit_source_domain_incomplete")
    provisional = parse_genome(raw)
    raw["design_id"] = "v49_$(provisional.physics_hash[1:20])"
    genome = parse_genome(raw)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError(join(report.errors, "; ")))
    family = validate_family(default_family_registry(), genome)
    family.valid || throw(ArgumentError(join(family.errors, "; ")))
    return genome
end

function _v49_non_beam_projection(genome::Genome)
    raw = deepcopy(genome.normalized)
    delete!(raw, "design_id")
    delete!(raw, "label")
    delete!(raw, "provenance")
    targets = raw["mission"]["targets"]
    delete!(targets, "screen_beam_energy")
    for actuator in raw["actuators"]
        occursin("nbi", lowercase(String(actuator["kind"]))) || continue
        delete!(actuator["parameters"], "beam_energy")
    end
    return raw
end

function _v49_effective_mirror_ratio(genome::Genome, features)
    mach = _ccv9_target(genome, "screen_rotation_mach", 0.0, "1")
    base_ratio = max(1.01, features.mirror_ratio *
        (1.0 + 1.5 * features.plug_strength +
            0.75 * features.minimum_b_strength))
    rotation_multiplier = 1.0 + min(2.0, 0.50 * mach^2)
    return min(1.0e4, base_ratio^rotation_multiplier)
end

function _v49_gate_ids(genome::Genome)
    mach = _ccv9_target(genome, "screen_rotation_mach", 0.0, "1")
    physics_ids = ["temperature_domain", "stability", "particle_loss",
        "fusion_gain", "auxiliary_power", "net_electric_power"]
    mach > 0.0 && append!(physics_ids, ["rotation_mach_domain",
        "rotation_voltage_authority", "neutral_fraction_control",
        "rotation_power_authority"])
    engineering_ids = ["peak_conductor_field", "engineering_current_density",
        "support_stress", "outer_radial_envelope", "outer_axial_envelope",
        "inboard_build", "coil_curvature", "neutron_wall_load",
        "exhaust_target_heat_flux", "finite_exhaust_and_voltage_build"]
    mach > 0.0 && push!(engineering_ids, "rotation_insulation_field")
    return physics_ids, engineering_ids
end

function _v49_source_complete_nominal(genome::Genome,
        current::AbstractDict, contract::SharedOuterEnvelopeContractV1,
        features)
    energy_keV = _v49_beam_energy_keV(genome)
    effective_ratio = _v49_effective_mirror_ratio(genome, features)
    density_20 = max(Float64(current["density_m3"]) / 1.0e20, 0.02)
    tau = 0.25 * (energy_keV / 100.0)^1.5 *
        log10(effective_ratio) / density_20
    tau > 1.0e-4 || throw(ArgumentError(
        "v49 source-complete confinement time hit the numerical floor"))

    nominal = deepcopy(current)
    stored_energy = Float64(nominal["stored_energy_MJ"]) * 1.0e6
    loss_power = stored_energy / tau
    alpha_power = Float64(nominal["alpha_power_W"])
    declared_power = Float64(nominal["declared_actuator_power_W"])
    transport_auxiliary = max(0.0, loss_power - alpha_power)
    total_auxiliary = transport_auxiliary + declared_power
    fusion_power = Float64(nominal["fusion_power_W"])
    fusion_gain = fusion_power / max(total_auxiliary, 1.0)
    base = contract.base
    net_power = base.thermal_conversion_efficiency * fusion_power -
        total_auxiliary / base.heating_wall_plug_efficiency -
        base.fixed_balance_of_plant_load_W
    target_area = Float64(nominal["effective_target_area_m2"])
    exhaust_heat_flux = loss_power / max(target_area, 1.0e-9)

    nominal["energy_confinement_time_s"] = tau
    nominal["mirror_time_proxy_s"] = tau
    nominal["transport_loss_power_W"] = loss_power
    nominal["required_transport_auxiliary_power_W"] = transport_auxiliary
    nominal["required_auxiliary_power_W"] = total_auxiliary
    nominal["fusion_gain_proxy"] = fusion_gain
    nominal["net_electric_power_W"] = net_power
    nominal["exhaust_heat_flux_W_m2"] = exhaust_heat_flux
    nominal["screen_beam_energy_keV"] = energy_keV
    nominal["effective_mirror_ratio_proxy"] = effective_ratio
    nominal["beam_energy_exponent"] = 1.5
    nominal["source_complete_beam_energy_formula_consumed"] = true

    margins = nominal["margins"]
    margins["fusion_gain"] = fusion_gain - 1.0
    margins["auxiliary_power"] =
        (base.auxiliary_heating_budget_W - total_auxiliary) /
        base.auxiliary_heating_budget_W
    margins["net_electric_power"] = net_power /
        max(base.fixed_balance_of_plant_load_W, 1.0)
    margins["exhaust_target_heat_flux"] =
        (contract.maximum_exhaust_heat_flux_W_m2 - exhaust_heat_flux) /
        contract.maximum_exhaust_heat_flux_W_m2

    mach = _ccv9_target(genome, "screen_rotation_mach", 0.0, "1")
    if mach > 0.0
        required_rotation_power = Float64(nominal["rotation_energy_inventory_J"]) /
            tau
        nominal["required_rotation_power_W"] = required_rotation_power
        margins["rotation_power_authority"] =
            (declared_power - required_rotation_power) /
            base.auxiliary_heating_budget_W
    end
    physics_ids, engineering_ids = _v49_gate_ids(genome)
    nominal["physics_gate_passed"] =
        all(margins[id] >= 0.0 for id in physics_ids)
    nominal["engineering_gate_passed"] =
        all(margins[id] >= 0.0 for id in engineering_ids)
    nominal["minimum_normalized_margin"] = minimum(values(margins))
    return nominal
end

function _v49_trial_record(context::RecoverableCrossTopologyContextV20,
        v46::AbstractDict, v48::AbstractDict, energy_keV::Float64,
        trial_index::Int)
    index = Int(v46["candidate_index"])
    candidate = evaluate_cross_topology_candidate_v20(context, index;
        halton_skip = 4096)
    core = cross_topology_candidate_to_dict_v20(candidate)
    canonical_hash(core) == String(v46["v46_v20_compatible_core_record_hash"]) ||
        throw(ArgumentError("v49 candidate $index drifted from sealed v46 core"))
    compiled = candidate.prescreen.compiled
    compiled.family == "magnetic_mirror" || throw(ArgumentError(
        "v49 received a non-mirror candidate"))
    String(v48["physics_hash"]) == compiled.genome.physics_hash ||
        throw(ArgumentError("v49 candidate $index drifted from sealed v48 audit"))
    v48["formula_numerically_reproduced"] === true || throw(ArgumentError(
        "v49 requires v48 mirror formula reproduction"))

    evaluator = context.evaluators[compiled.evaluator_id]
    evaluator isa ComposableCrossFamilyScreenV1 || throw(ArgumentError(
        "v49 evaluator type mismatch"))
    base = compiled.genome
    mutated = _v49_mutate_beam_energy(base, energy_keV)
    base_projection_hash = canonical_hash(_v49_non_beam_projection(base))
    mutated_projection_hash = canonical_hash(_v49_non_beam_projection(mutated))
    fixed_background = base_projection_hash == mutated_projection_hash
    fixed_background || throw(ArgumentError(
        "v49 non-beam background changed for candidate $index"))
    nbi_energies = _v49_nbi_energies_keV(mutated)
    !isempty(nbi_energies) && all(_v49_isclose(value, energy_keV)
        for value in nbi_energies) || throw(ArgumentError(
        "v49 NBI beam energy did not synchronize"))

    features = _oe_features(mutated)
    graph_errors = _ccv9_graph_errors(mutated, features, evaluator.contract)
    isempty(graph_errors) || throw(ArgumentError(
        "v49 mutated graph failed validation: $(join(graph_errors, "; "))"))
    current = _ccv9_nominal(mutated, evaluator.contract, features)
    source = _v49_source_complete_nominal(mutated, current,
        evaluator.contract, features)
    base_tau = Float64(v48["current_energy_confinement_time_s"])
    expected_ratio = (energy_keV / 100.0)^1.5
    tau_ratio = Float64(source["energy_confinement_time_s"]) / base_tau
    current_model_invariant = _v49_isclose(
        Float64(current["energy_confinement_time_s"]), base_tau)
    ratio_reproduced = _v49_isclose(tau_ratio, expected_ratio)
    response_changed = energy_keV == 100.0 ? false :
        !_v49_isclose(Float64(source["transport_loss_power_W"]),
            Float64(current["transport_loss_power_W"]))
    physics_ids, engineering_ids = _v49_gate_ids(mutated)
    margins = source["margins"]
    physics_failures = sort!([id for id in physics_ids if margins[id] < 0.0])
    engineering_failures = sort!([id for id in engineering_ids if margins[id] < 0.0])
    response_payload = Dict{String,Any}(
        "energy_confinement_time_s" => source["energy_confinement_time_s"],
        "transport_loss_power_W" => source["transport_loss_power_W"],
        "required_auxiliary_power_W" => source["required_auxiliary_power_W"],
        "net_electric_power_W" => source["net_electric_power_W"],
        "exhaust_heat_flux_W_m2" => source["exhaust_heat_flux_W_m2"],
        "physics_gate_passed" => source["physics_gate_passed"],
        "engineering_gate_passed" => source["engineering_gate_passed"],
        "physics_failure_ids" => physics_failures,
        "engineering_failure_ids" => engineering_failures,
        "named_margins" => deepcopy(margins),
    )
    return Dict{String,Any}(
        "trial_index" => trial_index,
        "candidate_index" => index,
        "assembly_index" => candidate.assembly_index,
        "assembly_id" => compiled.assembly_id,
        "sample_ordinal" => Int(v46["sample_ordinal"]),
        "family" => compiled.family,
        "module_ids" => copy(compiled.module_ids),
        "parent_design_id" => base.design_id,
        "design_id" => mutated.design_id,
        "parent_physics_hash" => base.physics_hash,
        "physics_hash" => mutated.physics_hash,
        "beam_energy_keV" => energy_keV,
        "beam_energy_gene_present" => true,
        "nbi_beam_energy_synchronized" => true,
        "source_complete_formula_consumed_gene" => true,
        "non_beam_projection_hash" => base_projection_hash,
        "fixed_non_beam_background" => fixed_background,
        "current_evaluator_still_ignores_beam_energy" => current_model_invariant,
        "v48_current_confinement_time_s" => base_tau,
        "current_evaluator_confinement_time_s" =>
            current["energy_confinement_time_s"],
        "source_complete_confinement_time_s" =>
            source["energy_confinement_time_s"],
        "expected_tau_ratio_to_100keV" => expected_ratio,
        "observed_tau_ratio_to_v48_100keV" => tau_ratio,
        "preregistered_ratio_reproduced" => ratio_reproduced,
        "source_complete_response_changed_from_current_implicit_100keV" =>
            response_changed,
        "effective_mirror_ratio_proxy" =>
            source["effective_mirror_ratio_proxy"],
        "source_complete_response" => response_payload,
        "cheap_robustness_screen_passed" => false,
        "source_domain_complete" => false,
        "candidate_specific_performance_ranking_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promotion_credit" => 0,
        "applicability_blockers" => [
            "particle_confinement_estimate_not_validated_as_energy_confinement_law",
            "effective_mirror_ratio_semantics_not_validated",
            "fast_ion_distribution_and_injection_geometry_not_validated",
            "finite_beta_equilibrium_and_stability_not_validated",
            "atomic_processes_and_held_out_magnitude_not_validated",
            "rotation_power_not_added_to_auxiliary_power_ledger",
        ],
        "response_hash" => canonical_hash(response_payload),
    )
end

function _v49_qd_archive(trials::Vector{Dict{String,Any}})
    cells = Dict{String,Dict{String,Any}}()
    for trial in trials
        key = "$(trial["assembly_id"])|E$(Int(trial["beam_energy_keV"]))keV"
        if !haskey(cells, key) ||
                Int(trial["candidate_index"]) < Int(cells[key]["candidate_index"])
            cells[key] = Dict{String,Any}(
                "cell_id" => key,
                "assembly_id" => trial["assembly_id"],
                "beam_energy_keV" => trial["beam_energy_keV"],
                "candidate_index" => trial["candidate_index"],
                "trial_index" => trial["trial_index"],
                "design_id" => trial["design_id"],
                "physics_hash" => trial["physics_hash"],
                "response_hash" => trial["response_hash"],
                "selection_rule" =>
                    "lowest_candidate_index_only_no_performance_ranking",
                "performance_ranking_used" => false,
                "source_domain_complete" => false,
                "promotion_credit" => 0,
            )
        end
    end
    return sort!(collect(values(cells)); by = record -> String(record["cell_id"]))
end

function mirror_beam_energy_intervention_v49(
        context::RecoverableCrossTopologyContextV20,
        v46_records::AbstractVector, v48_records::AbstractVector,
        evidence::AbstractDict)
    _v49_validate_evidence(evidence)
    length(v46_records) == 2_000 || throw(ArgumentError(
        "v49 requires all 2000 sealed v46 candidates"))
    v48_by_index = Dict(Int(record["candidate_index"]) => record
        for record in v48_records)
    mirror = sort!(filter(record -> String(record["family"]) ==
        "magnetic_mirror", collect(v46_records));
        by = record -> Int(record["candidate_index"]))
    length(mirror) == 724 || throw(ArgumentError(
        "v49 requires 724 sealed v46 mirror candidates"))
    length(unique(String(record["assembly_id"]) for record in mirror)) == 362 ||
        throw(ArgumentError("v49 requires 362 mirror assemblies"))

    trials = Dict{String,Any}[]
    trial_index = 0
    for v46 in mirror, energy_keV in _V49_BEAM_ENERGIES_KEV
        trial_index += 1
        index = Int(v46["candidate_index"])
        haskey(v48_by_index, index) || throw(ArgumentError(
            "v49 missing v48 record for candidate $index"))
        push!(trials, _v49_trial_record(context, v46,
            v48_by_index[index], energy_keV, trial_index))
    end
    qd = _v49_qd_archive(trials)
    by_energy = Dict{String,Any}()
    for energy_keV in _V49_BEAM_ENERGIES_KEV
        subset = filter(record ->
            Float64(record["beam_energy_keV"]) == energy_keV, trials)
        physics_failure_counts = Dict{String,Int}()
        engineering_failure_counts = Dict{String,Int}()
        for record in subset
            response = record["source_complete_response"]
            for id in response["physics_failure_ids"]
                key = String(id)
                physics_failure_counts[key] =
                    get(physics_failure_counts, key, 0) + 1
            end
            for id in response["engineering_failure_ids"]
                key = String(id)
                engineering_failure_counts[key] =
                    get(engineering_failure_counts, key, 0) + 1
            end
        end
        by_energy[string(Int(energy_keV))] = Dict{String,Any}(
            "trial_count" => length(subset),
            "preregistered_ratio_reproduced_count" => count(record ->
                record["preregistered_ratio_reproduced"] === true, subset),
            "response_changed_from_current_count" => count(record ->
                record["source_complete_response_changed_from_current_implicit_100keV"] === true,
                subset),
            "physics_gate_pass_count" => count(record ->
                record["source_complete_response"]["physics_gate_passed"] === true,
                subset),
            "engineering_gate_pass_count" => count(record ->
                record["source_complete_response"]["engineering_gate_passed"] === true,
                subset),
            "positive_net_electric_count" => count(record ->
                Float64(record["source_complete_response"]["net_electric_power_W"]) > 0.0,
                subset),
            "physics_failure_id_counts" => physics_failure_counts,
            "engineering_failure_id_counts" => engineering_failure_counts,
            "tau_s_range" => [
                minimum(Float64(record["source_complete_confinement_time_s"])
                    for record in subset),
                maximum(Float64(record["source_complete_confinement_time_s"])
                    for record in subset),
            ],
        )
    end
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "search_version" => "mirror_beam_energy_intervention_v49",
        "stage" => "sealed_mirror_beam_energy_gene_formula_counterfactual_qd",
        "experiment_contract" => Dict{String,Any}(
            "sealed_v46_core_reconstruction_required" => true,
            "sealed_v48_formula_reproduction_required" => true,
            "preregistered_beam_energies_keV" => copy(_V49_BEAM_ENERGIES_KEV),
            "non_beam_background_canonically_fixed" => true,
            "beam_gene_and_nbi_declaration_synchronized" => true,
            "source_complete_E_beam_exponent" => 1.5,
            "power_and_exhaust_closure_recomputed" => true,
            "qd_selection_uses_performance" => false,
            "experiment_can_promote_candidate" => false,
        ),
        "aggregate" => Dict{String,Any}(
            "input_candidate_count" => length(v46_records),
            "mirror_candidate_count" => length(mirror),
            "mirror_assembly_count" => 362,
            "beam_energy_level_count" => length(_V49_BEAM_ENERGIES_KEV),
            "trial_count" => length(trials),
            "fixed_non_beam_background_count" => count(record ->
                record["fixed_non_beam_background"] === true, trials),
            "beam_energy_gene_present_count" => count(record ->
                record["beam_energy_gene_present"] === true, trials),
            "nbi_beam_energy_synchronized_count" => count(record ->
                record["nbi_beam_energy_synchronized"] === true, trials),
            "source_complete_formula_consumed_gene_count" => count(record ->
                record["source_complete_formula_consumed_gene"] === true, trials),
            "unique_physics_hash_count" => length(unique(
                String(record["physics_hash"]) for record in trials)),
            "current_evaluator_beam_invariant_count" => count(record ->
                record["current_evaluator_still_ignores_beam_energy"] === true,
                trials),
            "preregistered_tau_ratio_reproduced_count" => count(record ->
                record["preregistered_ratio_reproduced"] === true, trials),
            "hundred_keV_v48_reproduction_count" => count(record ->
                Float64(record["beam_energy_keV"]) == 100.0 &&
                _v49_isclose(record["observed_tau_ratio_to_v48_100keV"], 1.0),
                trials),
            "nonbaseline_response_change_count" => count(record ->
                Float64(record["beam_energy_keV"]) != 100.0 &&
                record["source_complete_response_changed_from_current_implicit_100keV"] === true,
                trials),
            "source_domain_complete_count" => count(record ->
                record["source_domain_complete"] === true, trials),
            "performance_ranking_authorized_count" => count(record ->
                record["candidate_specific_performance_ranking_authorized"] === true,
                trials),
            "medium_fidelity_authorized_count" => count(record ->
                record["medium_fidelity_authorized"] === true, trials),
            "promotion_count" => count(record ->
                Int(record["promotion_credit"]) > 0, trials),
            "qd_cell_count" => length(qd),
            "qd_performance_selected_cell_count" => count(record ->
                record["performance_ranking_used"] === true, qd),
            "by_energy_keV" => by_energy,
        ),
        "next_actions" => [
            "Replace the effective-mirror-ratio proxy with candidate-specific finite-beta equilibrium and field-line loss-cone semantics.",
            "Add fast-ion distribution, injection geometry, charge exchange, atomic processes, and end-loss validation.",
            "Close the rotation-power ledger before interpreting auxiliary-power or net-electric changes for rotating mirrors.",
            "Validate confinement magnitudes against held-out mirror operating points before candidate comparison or ranking.",
            "Continue the horizontal bridge queue with tokamak regime gates, stellarator candidate f_ren, FRC transport, and spheromak transport.",
        ],
        "promotion_credit" => Dict{String,Any}(
            "candidate_count" => 0,
            "credit_granted" => false,
            "reason" => "A searched and formula-consumed gene is necessary search wiring, not candidate-specific validation.",
        ),
        "claim_boundary" => _V49_CLAIM_BOUNDARY,
        "trial_records" => trials,
        "qd_records" => qd,
    )
end
