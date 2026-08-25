const _PRHM_V1_HASH_RE = r"^[0-9a-f]{64}$"

_prhm_v1_hash(value) = value isa AbstractString &&
    occursin(_PRHM_V1_HASH_RE, String(value))

function _prhm_v1_contains(value, token::String)
    needle = lowercase(token)
    if value isa AbstractDict
        return any(_prhm_v1_contains(key, needle) ||
            _prhm_v1_contains(item, needle) for (key, item) in value)
    elseif value isa AbstractVector
        return any(_prhm_v1_contains(item, needle) for item in value)
    end
    return occursin(needle, lowercase(string(value)))
end

function _prhm_v1_quantity(items, id::String)
    found = Any[]
    for item in items
        parameters = get(item, "parameters", Dict{String,Any}())
        haskey(parameters, id) && push!(found, parameters[id])
    end
    length(found) == 1 || return nothing
    value = only(found)
    value isa AbstractDict || return nothing
    get(value, "value", nothing) isa Real || return nothing
    return Dict{String,Any}("value" => Float64(value["value"]),
        "unit" => String(get(value, "unit", "")),
        "basis" => String(get(value, "basis", "")))
end

function _prhm_v1_requirement(id, available, source, note)
    return Dict{String,Any}("requirement_id" => String(id),
        "available" => available === true, "source" => source,
        "blocking" => true, "note" => String(note))
end

function _prhm_v1_layer_complete(layer)
    layer isa AbstractDict || return false
    required = ("layer_id", "inner_radius_m", "outer_radius_m", "material_id",
        "material_version", "isotope_fractions", "initial_density_profile",
        "initial_temperature_profile", "mesh_region_id")
    all(haskey(layer, key) for key in required) || return false
    inner = layer["inner_radius_m"]; outer = layer["outer_radius_m"]
    inner isa Real && outer isa Real && 0.0 <= Float64(inner) < Float64(outer) ||
        return false
    fractions = layer["isotope_fractions"]
    fractions isa AbstractDict || return false
    fraction_values = Float64[value for value in Base.values(fractions) if value isa Real]
    length(fraction_values) == length(fractions) && !isempty(fraction_values) &&
        all(value -> 0.0 <= value <= 1.0, fraction_values) &&
        abs(sum(fraction_values) - 1.0) <= 1.0e-8 || return false
    return !isempty(String(layer["layer_id"])) &&
        !isempty(String(layer["material_id"])) &&
        !isempty(String(layer["material_version"]))
end

function _prhm_v1_table_complete(value)
    value isa AbstractDict || return false
    return _prhm_v1_hash(get(value, "table_hash", nothing)) &&
        !isempty(String(get(value, "model_or_table_id", ""))) &&
        !isempty(String(get(value, "version", ""))) &&
        get(value, "validity_domain", nothing) isa AbstractDict &&
        get(value, "relative_uncertainty", nothing) isa Real
end

function _prhm_v1_history_complete(value)
    value isa AbstractDict || return false
    knots = get(value, "temporal_power_knots", Any[])
    return get(value, "wavelength_m", nothing) isa Real &&
        Float64(value["wavelength_m"]) > 0.0 && length(knots) >= 2 &&
        all(item -> item isa AbstractDict &&
            get(item, "time_s", nothing) isa Real &&
            get(item, "power_w", nothing) isa Real, knots) &&
        _prhm_v1_hash(get(value, "spatial_profile_hash", nothing)) &&
        _prhm_v1_hash(get(value, "deposition_operator_hash", nothing))
end

function _prhm_v1_numerics_complete(value)
    value isa AbstractDict || return false
    levels = get(value, "radial_cell_levels", Any[])
    groups = get(value, "radiation_group_levels", Any[])
    outputs = get(value, "convergence_observables", Any[])
    return length(unique(Int.(levels))) >= 2 &&
        length(unique(Int.(groups))) >= 2 &&
        get(value, "cfl_target", nothing) isa Real &&
        0.0 < Float64(value["cfl_target"]) <= 1.0 &&
        get(value, "relative_tolerance", nothing) isa Real &&
        Float64(value["relative_tolerance"]) > 0.0 && !isempty(outputs)
end

"""
Compile the external radiation-hydrodynamics acquisition boundary for one
candidate. Only explicit declarations can make an input ready. Generic regional
profiles are retained for diagnosis but cannot be reinterpreted as target-layer
material, EOS, opacity or laser-pulse data.
"""
function compile_pulsed_rhd_manifest_v1(raw::AbstractDict,
        candidate_id::AbstractString, physics_hash::AbstractString)
    normalized = Dict{String,Any}(String(key) => value for (key, value) in raw)
    declared_capability = _prhm_v1_contains(
        get(normalized, "solver_ready_contracts", Any[]),
        "radiation_hydrodynamics") ||
        _prhm_v1_contains(get(normalized, "compression_systems", Any[]),
            "laser")
    regions = get(normalized, "plasma_regions", Any[])
    actuators = get(normalized, "actuators", Any[])
    compression = get(normalized, "compression_systems", Any[])
    regional = get(normalized, "regional_solver_contract_v1", Dict{String,Any}())
    explicit = get(normalized, "pulsed_rhd_manifest_v1", Dict{String,Any}())

    target_layers = get(explicit, "target_layers", Any[])
    microphysics = get(explicit, "material_microphysics", Dict{String,Any}())
    drive = get(explicit, "drive_history", Dict{String,Any}())
    numerics = get(explicit, "numerical_convergence_plan", Dict{String,Any}())
    outputs = sort!(unique(String.(get(explicit, "required_outputs", String[]))))
    layer_complete = !isempty(target_layers) && all(_prhm_v1_layer_complete, target_layers)
    eos_complete = _prhm_v1_table_complete(get(microphysics, "equation_of_state", nothing))
    opacity_complete = _prhm_v1_table_complete(get(microphysics, "multigroup_opacity", nothing))
    drive_complete = _prhm_v1_history_complete(drive)
    numerics_complete = _prhm_v1_numerics_complete(numerics)
    required_outputs = Set(["shock_radius_history", "shock_timing",
        "convergence_ratio", "areal_density", "hotspot_temperature",
        "absorbed_drive_energy", "radiation_loss", "burn_yield",
        "alpha_deposition", "conservation_ledger"])
    outputs_complete = required_outputs <= Set(outputs)

    requirements = Dict{String,Any}[
        _prhm_v1_requirement("layer_material_isotope_and_radial_geometry",
            layer_complete, layer_complete ? "pulsed_rhd_manifest_v1.target_layers" : nothing,
            "Every target layer needs finite radii, versioned material, isotope fractions and radial initial profiles."),
        _prhm_v1_requirement("equation_of_state",
            eos_complete, eos_complete ? "pulsed_rhd_manifest_v1.material_microphysics.equation_of_state" : nothing,
            "A versioned candidate-bound EOS hash, validity domain and uncertainty are required."),
        _prhm_v1_requirement("multigroup_opacity",
            opacity_complete, opacity_complete ? "pulsed_rhd_manifest_v1.material_microphysics.multigroup_opacity" : nothing,
            "A versioned candidate-bound opacity hash, validity domain and uncertainty are required."),
        _prhm_v1_requirement("time_and_space_resolved_drive",
            drive_complete, drive_complete ? "pulsed_rhd_manifest_v1.drive_history" : nothing,
            "Integrated energy and emitter locations do not define wavelength, pulse shape, deposition or spot profile."),
        _prhm_v1_requirement("mesh_timestep_and_radiation_group_convergence",
            numerics_complete, numerics_complete ? "pulsed_rhd_manifest_v1.numerical_convergence_plan" : nothing,
            "At least two radial and radiation-group levels with a CFL and observable tolerance are required."),
        _prhm_v1_requirement("burn_alpha_and_conservation_outputs",
            outputs_complete, outputs_complete ? "pulsed_rhd_manifest_v1.required_outputs" : nothing,
            "The backend package must request compression, burn, alpha and conservation observables.")]

    conflicts = String[]
    system_rate = _prhm_v1_quantity(compression, "repetition_rate")
    time_contract = get(normalized, "time_integration_contract_v1", Dict{String,Any}())
    contract_rate = get(time_contract, "repetition_rate_hz", nothing)
    if system_rate !== nothing && contract_rate isa Real
        a = Float64(system_rate["value"]); b = Float64(contract_rate)
        abs(a - b) <= 1.0e-8 * max(abs(a), abs(b), 1.0) || push!(conflicts,
            "compression_system repetition_rate conflicts with time_integration_contract_v1.repetition_rate_hz")
    end
    declared_hash = String(get(explicit, "candidate_physics_hash", String(physics_hash)))
    declared_hash == String(physics_hash) || push!(conflicts,
        "pulsed_rhd_manifest_v1 candidate_physics_hash mismatch")

    blocking = sort!(String[item["requirement_id"] for item in requirements
        if item["available"] === false])
    status = !declared_capability ? "not_applicable" :
        !isempty(conflicts) ? "unsupported" :
        !isempty(blocking) ? "unknown" : "ready_for_external_backend"
    region_diagnostics = Dict{String,Any}[
        Dict("region_id" => String(get(item, "region_id", "")),
            "volume_m3" => get(item, "volume_m3", nothing),
            "state_profile_declared" => haskey(item, "state_profile"),
            "usable_as_target_layer_initial_condition" => false,
            "reason" => "generic normalized-volume state lacks layer material, radial mapping and microphysics binding")
        for item in get(regional, "region_records", Any[])]
    drive_summary = Dict{String,Any}(
        "integrated_on_target_energy" => _prhm_v1_quantity(actuators, "on_target_energy"),
        "compression_system_repetition_rate" => system_rate,
        "time_contract_repetition_rate_hz" => contract_rate,
        "explicit_drive_history_declared" => drive_complete)
    backends = Dict{String,Any}[
        Dict("backend_id" => "multi_ife", "capability_match" => declared_capability,
            "source_state" => "not_acquired", "access_state" =>
                "user_license_eligibility_confirmation_and_acquisition_authorization_required",
            "candidate_input_state" => status, "execution_authorized" => false),
        Dict("backend_id" => "flash_hedp", "capability_match" => declared_capability,
            "source_state" => "not_acquired_code_request_required",
            "candidate_input_state" => status, "execution_authorized" => false),
        Dict("backend_id" => "artemis_rhd", "capability_match" => false,
            "source_state" => "public", "candidate_input_state" => "unsupported",
            "missing_capabilities" => ["candidate_laser_deposition", "dt_burn",
                "alpha_deposition", "icf_capsule_regression"],
            "execution_authorized" => false),
        Dict("backend_id" => "magnetic_equilibrium_backends",
            "capability_match" => false, "candidate_input_state" => "not_applicable",
            "reason" => "declared radiation_hydrodynamics route is not a magnetic equilibrium problem",
            "execution_authorized" => false)]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "candidate_id" => String(candidate_id),
        "physics_hash" => String(physics_hash),
        "declared_solver_capability_match" => declared_capability,
        "status" => status, "target_layers" => target_layers,
        "material_microphysics" => microphysics, "drive_history" => drive,
        "numerical_convergence_plan" => numerics, "required_outputs" => outputs,
        "requirements" => requirements, "blocking_missing_inputs" => blocking,
        "declaration_conflicts" => sort!(conflicts),
        "regional_state_diagnostics" => region_diagnostics,
        "drive_summary" => drive_summary, "backend_acquisition" => backends,
        "family_label_used_for_routing" => false,
        "claim_ceiling" => status == "ready_for_external_backend" ?
            "candidate-bound external-backend input package only" :
            "input-readiness and backend-access diagnosis only",
        "claim_boundary" => "No radiation-hydrodynamics, compression, burn, gain, cross-code agreement or experimental validation is claimed by this manifest.")
    body["manifest_hash"] = canonical_hash(body)
    return body
end

compile_pulsed_rhd_manifest_v1(genome::Genome, candidate_id::AbstractString) =
    compile_pulsed_rhd_manifest_v1(genome.normalized, candidate_id,
        genome.physics_hash)
