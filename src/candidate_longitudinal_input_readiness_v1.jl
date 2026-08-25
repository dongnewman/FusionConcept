const _LONGITUDINAL_INITIAL_UNITS_V1 = Dict{String,String}(
    "fuel_a_inventory" => "particle", "fuel_b_inventory" => "particle",
    "electron_inventory" => "particle", "ion_thermal_energy" => "J",
    "electron_thermal_energy" => "J", "fueling_output" => "particle/s",
    "ion_heating_output" => "W", "electron_heating_output" => "W",
    "exhaust_output" => "particle/s", "radiation_control_output" => "W")

const _LONGITUDINAL_PARAMETER_UNITS_V1 = Dict{String,String}(
    "charge_a" => "1", "charge_b" => "1", "particle_scale" => "particle",
    "energy_scale" => "J", "particle_rate_scale" => "particle/s",
    "power_scale" => "W", "particle_transport_a_s" => "1/s",
    "particle_transport_b_s" => "1/s", "ion_energy_loss_s" => "1/s",
    "electron_energy_loss_s" => "1/s",
    "reaction_coefficient_per_particle_s" => "1/(particle*s)",
    "reaction_energy_j" => "J", "alpha_ion_fraction" => "1",
    "alpha_electron_fraction" => "1",
    "radiation_coefficient_per_particle_s" => "1/(particle*s)",
    "ion_electron_exchange_rate_s" => "1/s", "fuel_fraction_a" => "1",
    "fuel_fraction_b" => "1", "exhaust_fraction_a" => "1",
    "exhaust_fraction_b" => "1", "fueling_capacity_s" => "particle/s",
    "ion_heating_capacity_w" => "W", "electron_heating_capacity_w" => "W",
    "exhaust_capacity_s" => "particle/s", "radiation_control_capacity_w" => "W",
    "fueling_baseline_s" => "particle/s", "ion_heating_baseline_w" => "W",
    "electron_heating_baseline_w" => "W", "exhaust_baseline_s" => "particle/s",
    "radiation_control_baseline_w" => "W",
    "target_particle_inventory" => "particle", "target_ion_energy_j" => "J",
    "target_electron_energy_j" => "J",
    "fueling_controller_gain_s" => "1/(particle*s)",
    "ion_heating_controller_gain_s" => "1/s",
    "electron_heating_controller_gain_s" => "1/s",
    "exhaust_controller_gain_s" => "1/(particle*s)",
    "radiation_controller_gain_s" => "1/s",
    "ion_heating_deposition_efficiency" => "1",
    "electron_heating_deposition_efficiency" => "1",
    "fueling_wall_energy_j_per_particle" => "J/particle",
    "exhaust_wall_energy_j_per_particle" => "J/particle",
    "ion_heating_wall_plug_efficiency" => "1",
    "electron_heating_wall_plug_efficiency" => "1",
    "radiation_control_wall_plug_efficiency" => "1",
    "electric_conversion_efficiency" => "1")

const _LONGITUDINAL_REAL_SOURCE_KINDS_V1 = Set((:candidate_solver, :measured,
    :experiment_calibrated, :published_candidate_design_input,
    :compiler_derived_numerical))

struct CandidateLongitudinalInputRequirementV1
    input_id::String
    input_role::Symbol
    unit::String
    value::Union{Nothing,Float64}
    evidence_status::Symbol
    source_kind::Symbol
    source_result_hash::Union{Nothing,String}
    requirement_hash::String
end

struct CandidateLongitudinalInputReadinessV1
    schema_version::String
    candidate_binding_hash::String
    state_package_hash::String
    status::Symbol
    requirements::Vector{CandidateLongitudinalInputRequirementV1}
    missing_input_ids::Vector{String}
    partial_input_ids::Vector{String}
    unsupported_input_ids::Vector{String}
    evidence_tasks::Vector{String}
    readiness_hash::String
end

function _longitudinal_requirement_v1(input_id::String, input_role::Symbol,
        unit::String, overlay::Union{Nothing,AbstractDict})
    value = nothing
    status = :unknown
    source_kind = :missing
    source_hash = nothing
    if overlay !== nothing
        raw_value = get(overlay, "value", nothing)
        value = raw_value === nothing ? nothing : Float64(raw_value)
        value === nothing || isfinite(value) || throw(ArgumentError(
            "longitudinal input $input_id must be finite"))
        String(get(overlay, "unit", "")) == unit || throw(ArgumentError(
            "longitudinal input $input_id unit mismatch"))
        status = Symbol(get(overlay, "evidence_status", "unknown"))
        status in (:complete, :partial, :unknown, :unsupported) || throw(ArgumentError(
            "invalid longitudinal input evidence status"))
        source_kind = Symbol(get(overlay, "source_kind", "missing"))
        raw_hash = get(overlay, "source_result_hash", nothing)
        source_hash = raw_hash === nothing ? nothing :
            _c2_check_hash_v1(String(raw_hash), "longitudinal input source result hash")
    end
    source_allowed = source_kind in _LONGITUDINAL_REAL_SOURCE_KINDS_V1
    authorized_complete = value !== nothing && status == :complete && source_allowed &&
        source_hash !== nothing
    effective_status = authorized_complete ? :complete :
        status == :unsupported || (value !== nothing && !source_allowed) ? :unsupported :
        value !== nothing || status == :partial ? :partial : :unknown
    core = Dict{String,Any}("input_id" => input_id, "input_role" => String(input_role),
        "unit" => unit, "value" => value, "evidence_status" => String(effective_status),
        "source_kind" => String(source_kind), "source_result_hash" => source_hash)
    return CandidateLongitudinalInputRequirementV1(input_id, input_role, unit,
        value, effective_status, source_kind, source_hash, canonical_hash(core))
end

function compile_candidate_longitudinal_input_readiness_v1(
        state::C2CandidateStatePackageV1;
        overlays::Dict{String,<:AbstractDict} = Dict{String,Dict{String,Any}}())
    specs = Tuple{String,Symbol,String}[]
    append!(specs, [("initial:$id", :initial_condition, unit)
        for (id, unit) in _LONGITUDINAL_INITIAL_UNITS_V1])
    append!(specs, [("parameter:$id", :parameter, unit)
        for (id, unit) in _LONGITUDINAL_PARAMETER_UNITS_V1])
    expected = Set(first(spec) for spec in specs)
    extras = setdiff(Set(keys(overlays)), expected)
    isempty(extras) || throw(ArgumentError(
        "unknown longitudinal input overlays: $(join(sort!(collect(extras)), ", "))"))
    requirements = CandidateLongitudinalInputRequirementV1[
        _longitudinal_requirement_v1(id, role, unit, get(overlays, id, nothing))
        for (id, role, unit) in specs]
    sort!(requirements; by = item -> item.input_id)
    missing = sort!(String[item.input_id for item in requirements
        if item.evidence_status == :unknown])
    partial = sort!(String[item.input_id for item in requirements
        if item.evidence_status == :partial])
    unsupported = sort!(String[item.input_id for item in requirements
        if item.evidence_status == :unsupported])
    status = !isempty(unsupported) ? :unsupported :
        isempty(missing) && isempty(partial) ? :pass : :unknown
    tasks = String[]
    append!(tasks, ["acquire_candidate_bound_input:$id" for id in missing])
    append!(tasks, ["complete_input_evidence:$id" for id in partial])
    append!(tasks, ["replace_unsupported_input:$id" for id in unsupported])
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => state.candidate_binding_hash,
        "state_package_hash" => state.package_hash, "status" => String(status),
        "requirement_hashes" => getfield.(requirements, :requirement_hash),
        "missing_input_ids" => missing, "partial_input_ids" => partial,
        "unsupported_input_ids" => unsupported, "evidence_tasks" => tasks)
    return CandidateLongitudinalInputReadinessV1("1.0.0",
        state.candidate_binding_hash, state.package_hash, status, requirements,
        missing, partial, unsupported, tasks, canonical_hash(core))
end

function compile_candidate_longitudinal_module_from_readiness_v1(
        readiness::CandidateLongitudinalInputReadinessV1; module_id::AbstractString,
        region_id::AbstractString, transport_operator_id::AbstractString)
    readiness.status == :pass || throw(ArgumentError(
        "candidate longitudinal inputs are not complete"))
    values = Dict(item.input_id => something(item.value) for item in readiness.requirements)
    parameters = Dict{String,Float64}(replace(id, "parameter:" => "") => value
        for (id, value) in values if startswith(id, "parameter:"))
    initials = Dict{String,Float64}(replace(id, "initial:" => "") => value
        for (id, value) in values if startswith(id, "initial:"))
    module_instance = CandidateLongitudinalBalanceModuleV1(
        module_id = String(module_id), region_id = String(region_id),
        transport_operator_id = String(transport_operator_id), parameters = parameters,
        parameter_evidence = Dict(id => "complete" for id in keys(parameters)))
    return module_instance, initials
end

function candidate_longitudinal_input_readiness_to_dict_v1(
        item::CandidateLongitudinalInputReadinessV1)
    requirements = [Dict{String,Any}("input_id" => value.input_id,
        "input_role" => String(value.input_role), "unit" => value.unit,
        "value" => value.value, "evidence_status" => String(value.evidence_status),
        "source_kind" => String(value.source_kind),
        "source_result_hash" => value.source_result_hash,
        "requirement_hash" => value.requirement_hash) for value in item.requirements]
    return Dict{String,Any}("schema_version" => item.schema_version,
        "candidate_binding_hash" => item.candidate_binding_hash,
        "state_package_hash" => item.state_package_hash, "status" => String(item.status),
        "requirements" => requirements, "missing_input_ids" => item.missing_input_ids,
        "partial_input_ids" => item.partial_input_ids,
        "unsupported_input_ids" => item.unsupported_input_ids,
        "evidence_tasks" => item.evidence_tasks, "readiness_hash" => item.readiness_hash)
end

function compile_reference_anchor_longitudinal_overlays_v1(anchor::AbstractDict,
        source_result_hash::AbstractString; source_kind::Symbol)
    source_kind in (:experiment_calibrated, :published_candidate_design_input) ||
        throw(ArgumentError("reference anchor source kind is not authorized"))
    source_hash = _c2_check_hash_v1(source_result_hash,
        "reference anchor source result hash")
    initials = get(anchor, "initial_conditions", Dict{String,Any}())
    parameters = get(anchor, "parameters", Dict{String,Any}())
    particle = Float64(initials["particle_inventory"])
    energy = Float64(initials["thermal_energy"])
    duration = Float64(parameters["pulse_duration_s"])
    power = Float64(parameters["input_power_w"])
    all(value -> isfinite(value) && value > 0,
        (particle, energy, duration, power)) || throw(ArgumentError(
        "reference anchor numerical scales must be positive and finite"))
    overlay(id, value, unit, kind) = Dict{String,Any}("value" => value,
        "unit" => unit, "evidence_status" => "complete",
        "source_kind" => String(kind), "source_result_hash" => source_hash)
    return Dict{String,Dict{String,Any}}(
        "parameter:target_particle_inventory" => overlay(
            "target_particle_inventory", particle, "particle", source_kind),
        "parameter:particle_scale" => overlay("particle_scale", particle,
            "particle", :compiler_derived_numerical),
        "parameter:energy_scale" => overlay("energy_scale", energy, "J",
            :compiler_derived_numerical),
        "parameter:particle_rate_scale" => overlay("particle_rate_scale",
            particle / duration, "particle/s", :compiler_derived_numerical),
        "parameter:power_scale" => overlay("power_scale", power, "W",
            :compiler_derived_numerical))
end

function compile_desc_candidate_scalar_pressure_energy_overlays_v1(
        batch::AbstractDict, candidate_binding_hash::AbstractString)
    String(get(batch, "status", "error")) == "pass" || throw(ArgumentError(
        "candidate DESC scalar-pressure energy batch did not pass"))
    binding = _c2_check_hash_v1(candidate_binding_hash, "candidate binding hash")
    matches = [item for item in batch["candidates"]
        if String(item["candidate_binding_hash"]) == binding]
    length(matches) == 1 || throw(ArgumentError(
        "candidate DESC scalar-pressure energy binding is missing or non-unique"))
    item = only(matches)
    String(item["status"]) == "pass" || throw(ArgumentError(
        "candidate DESC scalar-pressure energy result did not pass"))
    String.(item["authorized_longitudinal_input_ids"]) ==
        ["parameter:energy_scale"] || throw(ArgumentError(
        "candidate DESC scalar-pressure energy result exceeded its slot authority"))
    gates = item["gates"]
    all(Bool(value) for value in values(gates)) || throw(ArgumentError(
        "candidate DESC scalar-pressure energy gates did not all pass"))
    observations = item["observations"]
    length(observations) >= 2 || throw(ArgumentError(
        "candidate DESC scalar-pressure energy lacks resolution history"))
    changes = Float64.(item["adjacent_relative_changes"])
    !isempty(changes) && maximum(changes) <= 0.02 || throw(ArgumentError(
        "candidate DESC scalar-pressure energy did not converge below two percent"))
    energy = Float64(item["finest_scalar_mhd_thermal_energy_j"])
    isfinite(energy) && energy > 0 || throw(ArgumentError(
        "candidate DESC scalar-pressure energy must be positive and finite"))
    result_hash = _c2_check_hash_v1(String(item["result_hash"]),
        "candidate DESC scalar-pressure energy result hash")
    return Dict{String,Dict{String,Any}}(
        "parameter:energy_scale" => Dict{String,Any}(
            "value" => energy, "unit" => "J", "evidence_status" => "complete",
            "source_kind" => "candidate_solver", "source_result_hash" => result_hash))
end

function compile_runtime_species_state_longitudinal_overlays_v1(
        problem::RuntimeSpeciesStateProblemV1,
        assessment::RuntimeSpeciesStateAssessmentV1,
        candidate_binding_hash::AbstractString)
    binding = _c2_check_hash_v1(candidate_binding_hash,
        "runtime species longitudinal candidate binding hash")
    problem.genome_physics_hash == binding &&
        assessment.genome_physics_hash == binding || throw(ArgumentError(
        "runtime species state is detached from the candidate binding"))
    assessment.design_id == problem.design_id || throw(ArgumentError(
        "runtime species state problem/assessment design mismatch"))
    assessment.status == :pass && assessment.complete_required_state &&
        assessment.c2_state_component_authorized || throw(ArgumentError(
        "runtime species state is not complete and C2-authorized"))
    length(problem.population_domain_ids) == 1 || throw(ArgumentError(
        "longitudinal adapter currently requires exactly one populated domain"))
    domain = only(problem.population_domain_ids)
    ions = sort!([item for item in problem.species_catalog
        if item.required_initial_population && item.charge_number > 0];
        by = item -> item.species_id)
    electrons = [item for item in problem.species_catalog
        if item.required_initial_population && item.role == :electron]
    length(ions) == 2 && length(electrons) == 1 || throw(ArgumentError(
        "longitudinal two-fuel adapter requires two distinct fuel ions and one electron"))
    inventory(species) = assessment.particle_inventories[
        "$domain:$(species.species_id):particle_inventory"]
    energy(species) = assessment.thermal_energy_inventories_j[
        "$domain:$(species.species_id):thermal_energy"]
    na, nb, ne = inventory(ions[1]), inventory(ions[2]), inventory(only(electrons))
    wi = sum(energy(item) for item in ions)
    we = energy(only(electrons))
    all(value -> isfinite(value) && value > 0.0, (na, nb, ne, wi, we)) ||
        throw(ArgumentError("runtime species inventories and energies must be positive"))
    source_hash = _c2_check_hash_v1(assessment.assessment_hash,
        "runtime species state assessment hash")
    overlay(value, unit, source_kind = :candidate_solver) = Dict{String,Any}(
        "value" => Float64(value), "unit" => unit,
        "evidence_status" => "complete", "source_kind" => String(source_kind),
        "source_result_hash" => source_hash)
    return Dict{String,Dict{String,Any}}(
        "initial:fuel_a_inventory" => overlay(na, "particle"),
        "initial:fuel_b_inventory" => overlay(nb, "particle"),
        "initial:electron_inventory" => overlay(ne, "particle"),
        "initial:ion_thermal_energy" => overlay(wi, "J"),
        "initial:electron_thermal_energy" => overlay(we, "J"),
        "parameter:charge_a" => overlay(ions[1].charge_number, "1"),
        "parameter:charge_b" => overlay(ions[2].charge_number, "1"),
        "parameter:particle_scale" => overlay(na + nb, "particle",
            :compiler_derived_numerical),
        "parameter:energy_scale" => overlay(wi + we, "J",
            :compiler_derived_numerical))
end
