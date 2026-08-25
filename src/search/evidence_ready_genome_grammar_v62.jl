const _V62_CLAIM_BOUNDARY =
    "V62 adds explicit species, perturbation, plant-role applicability and VVUQ request " *
    "contracts to the candidate Genome before screening. These declarations enter the " *
    "physics hash. They are search coordinates and applicability declarations, not solver " *
    "results, material qualification, independent-code replication or experiment."

function _v62_species_records(genome::Genome)
    fuel = uppercase(replace(genome.mission.fuel, " " => ""))
    templates = if fuel in ("D-T", "DT")
        [("deuterium", 2.014101778, 1, "fuel_ion", 0.5),
            ("tritium", 3.016049281, 1, "fuel_ion", 0.5),
            ("electrons", 5.48579909065e-4, -1, "charge_balance", 1.0)]
    elseif fuel in ("D-D", "DD")
        [("deuterium", 2.014101778, 1, "fuel_ion", 1.0),
            ("electrons", 5.48579909065e-4, -1, "charge_balance", 1.0)]
    else
        Tuple{String,Float64,Int,String,Float64}[]
    end
    region_ids = sort!(getfield.(genome.plasma_regions, :id))
    return Dict{String,Any}[
        Dict("species_id" => id, "mass_amu" => mass, "charge_state" => charge,
            "role" => role, "number_fraction_of_total_ion_density" => fraction,
            "region_ids" => copy(region_ids),
            "density_profile_binding" => "regional_solver_contract_v1.state_profile.particle_density",
            "temperature_profile_binding" => "regional_solver_contract_v1.state_profile.temperature",
            "distribution_model" => "isotropic_maxwellian_l1",
            "declaration_basis" => "explicit mission fuel=$(genome.mission.fuel); deterministic chemistry expansion")
        for (id, mass, charge, role, fraction) in templates]
end

function _v62_reaction_reserve!(raw, genome::Genome, seed::String)
    regional = raw["regional_solver_contract_v1"]
    channels = fusion_reaction_channels_v1(genome.mission.fuel)
    fractions = Dict(String(item["species_id"]) =>
        Float64(item["number_fraction_of_total_ion_density"])
        for item in _v62_species_records(genome))
    burn_rate = 0.0; charged_power = 0.0; radiation_power = 0.0
    applicable = !isempty(channels)
    observations = Dict{String,Any}[]
    for region in regional["region_records"]
        volume = Float64(region["volume_m3"])
        particles = Float64(region["analytic_integrals"]["particle_inventory"])
        energy = Float64(region["analytic_integrals"]["thermal_energy_j"])
        temperature_j = energy / max(3.0 * particles, eps())
        temperature_kev = temperature_j / (_CSR_V1_E_CHARGE * 1.0e3)
        density = particles / volume
        local_rate = 0.0; local_charged = 0.0
        for channel in channels
            reactivity = bosch_hale_maxwellian_reactivity_v1(channel.channel_id,
                temperature_kev)
            if !isfinite(reactivity)
                applicable = false
                continue
            end
            na = density * get(fractions, channel.reactant_a, 0.0)
            nb = density * get(fractions, channel.reactant_b, 0.0)
            rate = channel.identical_reactant_factor * na * nb * reactivity * volume
            local_rate += rate
            local_charged += rate * sum((value for (product, value) in channel.product_energy_j
                if product != "neutron"); init = 0.0)
        end
        electron_density = density
        temperature_ev = temperature_j / _CSR_V1_E_CHARGE
        local_radiation = 1.69e-38 * electron_density^2 *
            sqrt(max(temperature_ev, 0.0)) * volume
        burn_rate += local_rate; charged_power += local_charged
        radiation_power += local_radiation
        push!(observations, Dict("region_id" => region["region_id"],
            "temperature_kev" => temperature_kev, "reaction_rate_per_s" =>
                applicable ? local_rate : nothing,
            "charged_power_w" => applicable ? local_charged : nothing,
            "bremsstrahlung_power_w" => local_radiation))
    end
    requirements = Dict{String,Float64}(
        "particle_source" => applicable ? 2.0 * burn_rate : 0.0,
        "radiation_control" => applicable ? max(charged_power - radiation_power, 0.0) : 0.0,
        "deposited_energy_source" => applicable ? max(radiation_power - charged_power, 0.0) : 0.0)
    records = regional["actuator_sizing_records"]
    allocations = Dict{String,Any}[]
    for (capability, requirement) in requirements
        matching = [item for item in records if String(item["capability"]) == capability]
        isempty(matching) && requirement > 0.0 && continue
        share = isempty(matching) ? 0.0 : requirement / length(matching)
        for (index, item) in enumerate(matching)
            old = Float64(item["capacity"])
            reserve_factor = 1.10 + 0.40 * _v61_unit(seed * ":reaction_reserve:$capability", index)
            target = Float64(item["demand"]) + share * reserve_factor
            item["capacity"] = max(old, target)
            item["reaction_feedback_reserve"] = max(Float64(item["capacity"]) -
                Float64(item["demand"]), 0.0)
            item["reaction_feedback_reserve_basis"] =
                "generation-time species/profile reaction estimate; never runtime capacity expansion"
            push!(allocations, Dict("actuator_id" => item["actuator_id"],
                "capability" => capability, "old_capacity" => old,
                "new_capacity" => item["capacity"], "allocated_requirement" => share,
                "reserve_factor" => reserve_factor))
        end
    end
    reserve = Dict{String,Any}("schema_version" => "1.0.0",
        "status" => applicable ? "sized" : "unsupported_outside_reactivity_fit",
        "requirements" => requirements, "region_observations" => observations,
        "allocations" => allocations,
        "basis" => "candidate-bound profiles and Bosch-Hale reaction channels before screening")
    reserve["contract_hash"] = canonical_hash(reserve)
    raw["reaction_actuator_reserve_contract_v1"] = reserve
    regional["contract_hash"] = canonical_hash(Dict{String,Any}(String(key) => deepcopy(value)
        for (key, value) in regional if String(key) != "contract_hash"))
    return reserve
end

function generate_evidence_ready_genome_v62(base::Genome, module_ids,
        sample_ordinal::Integer)
    raw = deepcopy(base.normalized)
    species = _v62_species_records(base)
    channels = fusion_reaction_channel_to_dict_v1.(
        fusion_reaction_channels_v1(base.mission.fuel))
    species_contract = Dict{String,Any}(
        "schema_version" => "1.0.0", "generator_id" => "evidence_ready_genome_grammar_v62",
        "generation_stage" => "before_common_screen", "fuel_declaration" => base.mission.fuel,
        "species_records" => species, "reaction_channels" => channels,
        "status" => isempty(species) || isempty(channels) ? "unsupported" : "complete",
        "unsupported_reason" => isempty(species) || isempty(channels) ?
            "mission fuel lacks an implemented explicit chemistry/reaction contract" : nothing,
        "family_label_used" => false)
    species_contract["contract_hash"] = canonical_hash(species_contract)
    raw["species_state_contract_v1"] = species_contract
    seed = canonical_hash(Dict("base_physics_hash" => base.physics_hash,
        "module_ids" => String.(module_ids), "sample_ordinal" => Int(sample_ordinal),
        "generator" => "evidence_ready_genome_grammar_v62"))
    _v62_reaction_reserve!(raw, base, seed)

    mode = lowercase(String(raw["mission"]["operating_mode"]))
    if occursin("pulse", mode) || occursin("transient", mode)
        duration = 10.0^(-2.0 + 4.0 * _v61_unit(seed * ":pulse_duration", 1))
        duty = 0.05 + 0.75 * _v61_unit(seed * ":pulse_duty", 2)
        repetition = duty / duration
        raw["mission"]["targets"]["v62_pulse_duration"] =
            Dict("value" => duration, "unit" => "s")
        raw["mission"]["targets"]["v62_repetition_frequency"] =
            Dict("value" => repetition, "unit" => "Hz")
        time_contract = Dict{String,Any}("schema_version" => "1.0.0",
            "mode" => "pulsed", "pulse_duration_s" => duration,
            "repetition_rate_hz" => repetition, "duty_factor" => duty,
            "event_times_s" => [0.0, duration],
            "generation_basis" => "explicit deterministic v62 time-design genes")
        time_contract["contract_hash"] = canonical_hash(time_contract)
        raw["time_integration_contract_v1"] = time_contract
    end

    perturbation = Dict{String,Any}(
        "schema_version" => "1.0.0", "classes" => Any[
            Dict("perturbation_class" => "state", "relative_amplitude" => 1.0e-3),
            Dict("perturbation_class" => "boundary", "relative_amplitude" => 1.0e-2),
            Dict("perturbation_class" => "source", "relative_amplitude" => 1.0e-2),
            Dict("perturbation_class" => "controller", "relative_amplitude" => 1.0e-2),
            Dict("perturbation_class" => "manufacturing", "relative_amplitude" => 1.0e-2)],
        "acceptance" => Dict("maximum_positive_growth_rate_per_s" => 1.0e-10,
            "maximum_relative_response" => 0.05),
        "operator_scope" => "regional finite-volume state and bounded actuator Jacobian",
        "missing_scope" => ["ideal_mhd_spectrum", "kinetic_microstability",
            "nonlinear_disruption", "material_failure_propagation"],
        "family_label_used" => false)
    perturbation["contract_hash"] = canonical_hash(perturbation)
    raw["perturbation_contract_v1"] = perturbation

    evidence_request = Dict{String,Any}(
        "schema_version" => "1.0.0", "resolution_levels" => [32, 64],
        "manufacturing_relative_perturbations" => [-0.01, 0.01],
        "model_error_ensembles_required" => true,
        "independent_code_replication_required" => true,
        "experimental_anchor_required" => true,
        "routing_basis" => "uniform evidence obligations; no family routing")
    evidence_request["contract_hash"] = canonical_hash(evidence_request)
    raw["vvuq_request_contract_v1"] = evidence_request

    provenance = raw["provenance"]
    _v18_push_unique!(provenance["notes"], ["evidence_ready_genome_grammar_v62",
        "explicit species and uniform perturbation/VVUQ obligations generated before screening"])
    raw["design_id"] = "pending_evidence_ready_v62"
    provisional = parse_genome(raw)
    raw["design_id"] = "v62_$(canonical_hash(module_ids)[1:12])_s$(lpad(Int(sample_ordinal), 6, '0'))_" *
        provisional.physics_hash[1:12]
    result = parse_genome(raw)
    result.physics_hash != base.physics_hash || error("v62 declarations did not enter physics hash")
    return result
end

function evaluate_evidence_ready_candidate_v62(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        halton_skip::Integer = 4096)
    base = evaluate_regional_solver_candidate_v61(context, candidate_index;
        halton_skip = halton_skip)
    old = base.prescreen.compiled
    genome = generate_evidence_ready_genome_v62(old.genome, old.module_ids,
        base.sample_ordinal)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError("generated v62 genome invalid: " *
        join(report.errors, "; ")))
    compiled = CompiledAttributeGenomeV18(old.assembly_id, old.graph_hash, old.family,
        old.mission_contract_id, copy(old.module_ids), genome, old.evaluator_id,
        old.projection_id, sort!(unique(vcat(old.projection_limitations,
            ["v62 L1 evidence producers do not close independent code or experiment"]))),
        copy(old.declared_requirements), sort!(unique(vcat(old.validation_warnings,
            report.warnings))))
    prescreen = _v18_prescreen(compiled, context.evaluators, context.evaluator_registry)
    return CrossTopologyCandidateV20(Int(candidate_index), base.assembly_index,
        base.sample_ordinal, prescreen)
end

function evidence_ready_contract_audit_v62(genome::Genome)
    errors = String[]
    for id in ("species_state_contract_v1", "perturbation_contract_v1",
            "vvuq_request_contract_v1")
        contract = get(genome.normalized, id, nothing)
        contract isa AbstractDict || (push!(errors, "$id missing"); continue)
        expected = String(get(contract, "contract_hash", ""))
        body = Dict{String,Any}(String(key) => deepcopy(value) for (key, value) in contract
            if String(key) != "contract_hash")
        expected == canonical_hash(body) || push!(errors, "$id hash mismatch")
        get(contract, "family_label_used", false) === true &&
            push!(errors, "$id used family label")
    end
    species = get(get(genome.normalized, "species_state_contract_v1", Dict{String,Any}()),
        "species_records", Any[])
    isempty(species) && push!(errors, "no explicit species records")
    return Dict{String,Any}("status" => isempty(errors) ? "ready" : "invalid",
        "errors" => sort!(unique(errors)))
end
