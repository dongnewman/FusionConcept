function _pulsed_rhd_quantity_v1(items, parameter_id::String)
    values = Any[]
    for item in items
        parameters = get(item, "parameters", Dict{String,Any}())
        haskey(parameters, parameter_id) || continue
        push!(values, parameters[parameter_id])
    end
    length(values) == 1 || return nothing
    value = only(values)
    return Dict{String,Any}("value" => Float64(value["value"]),
        "unit" => String(value["unit"]), "basis" => String(value["basis"]))
end

function _pulsed_rhd_requirement_v1(id::String, available::Bool,
        source, blocking::Bool, note::String)
    return Dict{String,Any}("id" => id, "available" => available,
        "source" => source, "blocking" => blocking, "note" => note)
end

function _pulsed_rhd_physical_summary_v1(contract::AbstractDict)
    return Dict{String,Any}(
        "geometry" => contract["geometry"],
        "drive" => contract["drive"],
        "requirements" => contract["requirements"],
        "backend_readiness" => contract["backend_readiness"],
        "status" => contract["status"])
end

"""
Compile a generated pulse-route C1 record into a backend-neutral radiation-
hydrodynamics input contract. The compiler never manufactures material data,
EOS/opacity tables, pulse histories or burn results. Missing evidence remains
explicitly blocking and therefore cannot authorize C2.
"""
function compile_pulsed_rhd_input_contract_v1(record::AbstractDict)
    source_design_id = nothing
    execution_design_id = nothing
    execution_physics_hash = nothing
    regions = Any[]
    outer_radius = nothing
    shell_half_width = nothing
    fuel_mass = nothing
    on_target_energy = nothing
    wall_plug_efficiency = nothing
    emitter_maps = Any[]
    procedural_emitter_count = 0

    if haskey(record, "execution_genome")
        genome = record["execution_genome"]
        regions = get(genome, "plasma_regions", Any[])
        actuators = get(genome, "actuators", Any[])
        pulse = get(record, "pulse", Dict{String,Any}())
        target_regions = filter(regions) do item
            text = lowercase(String(get(item, "id", "")) * "|" *
                String(get(item, "geometry_model", "")))
            occursin("capsule", text) && !occursin("hotspot", text)
        end
        outer_radius = _pulsed_rhd_quantity_v1(target_regions,
            "generated_outer_radius")
        shell_half_width = _pulsed_rhd_quantity_v1(target_regions,
            "generated_shell_half_width")
        fuel_mass = _pulsed_rhd_quantity_v1(target_regions, "dt_fuel_mass")
        on_target_energy = _pulsed_rhd_quantity_v1(actuators,
            "on_target_energy")
        wall_plug_efficiency = _pulsed_rhd_quantity_v1(actuators,
            "wall_plug_efficiency")
        emitter_maps = get(pulse, "emitter_maps", Any[])
        procedural_emitter_count = Int(get(pulse,
            "procedural_emitter_count", 0))
        source_design_id = String(record["source_design_id"])
        execution_design_id = String(record["execution_design_id"])
        execution_physics_hash = String(record["execution_physics_hash"])
    elseif get(record, "route", nothing) == "pulsed_drive_geometry"
        parameters = get(record, "parameters", Dict{String,Any}())
        backend = get(record, "backend_result", Dict{String,Any}())
        required = ("capsule_outer_radius_m", "shell_half_width_m",
            "dt_fuel_mass_kg", "on_target_energy_j")
        missing = String[id for id in required if !haskey(parameters, id)]
        isempty(missing) || throw(ArgumentError(
            "dual-route pulse record is missing parameters: " *
            join(missing, ", ")))
        quantity(id, unit, basis) = Dict{String,Any}(
            "value" => Float64(parameters[id]), "unit" => unit,
            "basis" => basis)
        outer_radius = quantity("capsule_outer_radius_m", "m",
            "dual_route_search_parameter")
        shell_half_width = quantity("shell_half_width_m", "m",
            "dual_route_search_parameter")
        fuel_mass = quantity("dt_fuel_mass_kg", "kg",
            "dual_route_search_parameter")
        on_target_energy = quantity("on_target_energy_j", "J",
            "dual_route_search_parameter")
        emitter_maps = get(backend, "emitter_maps", Any[])
        procedural_emitter_count = Int(get(backend,
            "procedural_emitter_count", 0))
        candidate_index = Int(record["candidate_index"])
        source_design_id = "dual_route_c0_candidate_$(candidate_index)"
        execution_design_id = "dual_route_c1_candidate_$(candidate_index)"
        execution_physics_hash = String(record["physics_hash"])
        regions = Any[Dict{String,Any}(
            "geometry_model" => "candidate_bound_spherical_capsule")]
    else
        throw(ArgumentError("execution_genome or a dual-route pulse record is required"))
    end
    source_map_hashes = sort!(String[get(item, "source_map_hash", "")
        for item in emitter_maps if !isempty(String(get(item,
            "source_map_hash", "")))])

    geometry = Dict{String,Any}(
        "outer_radius" => outer_radius,
        "shell_half_width" => shell_half_width,
        "dt_fuel_mass" => fuel_mass,
        "region_models" => sort!(String[String(get(item,
            "geometry_model", "")) for item in regions]),
        "spherical_1d_mapping_declared" => outer_radius !== nothing &&
            shell_half_width !== nothing)
    drive = Dict{String,Any}(
        "on_target_energy" => on_target_energy,
        "wall_plug_efficiency" => wall_plug_efficiency,
        "emitter_count" => procedural_emitter_count,
        "source_map_hashes" => source_map_hashes)

    requirements = Dict{String,Any}[
        _pulsed_rhd_requirement_v1("spherical_target_geometry",
            geometry["spherical_1d_mapping_declared"],
            outer_radius === nothing ? nothing :
                "execution_genome.plasma_regions", true,
            "Candidate-bound outer radius and shell scale."),
        _pulsed_rhd_requirement_v1("fuel_inventory",
            fuel_mass !== nothing,
            fuel_mass === nothing ? nothing :
                "execution_genome.plasma_regions.dt_fuel_mass", true,
            "Total D-T mass alone does not define isotope fractions or profile."),
        _pulsed_rhd_requirement_v1("on_target_drive_energy",
            on_target_energy !== nothing,
            on_target_energy === nothing ? nothing :
                "execution_genome.actuators.on_target_energy", true,
            "Integrated energy is known; temporal power is a separate input."),
        _pulsed_rhd_requirement_v1("candidate_bound_emitter_map",
            !isempty(source_map_hashes),
            isempty(source_map_hashes) ? nothing :
                "pulse.emitter_maps.source_map_hash", true,
            "Geometric ray origins and focus are bound to the candidate."),
        _pulsed_rhd_requirement_v1("layer_material_and_isotope_fractions",
            false, nothing, true,
            "A D-T label is not a layer-resolved material definition."),
        _pulsed_rhd_requirement_v1("initial_density_temperature_profiles",
            false, nothing, true,
            "Mass and radius do not uniquely determine a compressed or layered profile."),
        _pulsed_rhd_requirement_v1("equation_of_state_tables",
            false, nothing, true,
            "No candidate-bound EOS table and validity range are supplied."),
        _pulsed_rhd_requirement_v1("multigroup_opacity_tables",
            false, nothing, true,
            "No candidate-bound absorption or emission opacity table is supplied."),
        _pulsed_rhd_requirement_v1("laser_wavelength_and_spatial_profile",
            false, nothing, true,
            "Emitter positions do not define wavelength, spot size or beam profile."),
        _pulsed_rhd_requirement_v1("time_resolved_drive_history",
            false, nothing, true,
            "Integrated energy cannot be converted into an arbitrary pulse shape."),
        _pulsed_rhd_requirement_v1("mesh_and_timestep_convergence_plan",
            false, nothing, true,
            "Two-resolution target and time discretizations are not yet declared."),
        _pulsed_rhd_requirement_v1("burn_alpha_and_energy_ledger_outputs",
            false, nothing, true,
            "Requires an executed backend with time-resolved conservation outputs."),
        _pulsed_rhd_requirement_v1("mix_instability_model_or_bound",
            false, nothing, false,
            "Required for credibility beyond 1D; absence limits the claim ceiling.")]
    blocking_missing = sort!(String[item["id"] for item in requirements
        if item["blocking"] === true && item["available"] === false])
    c1_authorized = get(record, "candidate_c1_evidence_authorized", false) === true
    input_ready = c1_authorized && isempty(blocking_missing)
    backend_readiness = Dict{String,Any}(
        "multi_ife" => Dict{String,Any}(
            "scientific_route_match" => true,
            "source_acquired" => false,
            "license_use_confirmed" => false,
            "build_regression_passed" => false,
            "candidate_input_ready" => input_ready,
            "execution_authorized" => false),
        "flash_hedp" => Dict{String,Any}(
            "scientific_route_match" => true,
            "source_acquired" => false,
            "build_regression_passed" => false,
            "dt_burn_and_alpha_pipeline_verified" => false,
            "candidate_input_ready" => input_ready,
            "execution_authorized" => false))
    status = input_ready ? "ready_for_external_backend" : "unknown"
    contract = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "compiler_version" => "pulsed_radiation_hydrodynamics_input_v1",
        "source_design_id" => source_design_id,
        "execution_design_id" => execution_design_id,
        "execution_physics_hash" => execution_physics_hash,
        "candidate_c1_evidence_authorized" => c1_authorized,
        "geometry" => geometry,
        "drive" => drive,
        "requirements" => requirements,
        "blocking_missing_inputs" => blocking_missing,
        "backend_readiness" => backend_readiness,
        "status" => status,
        "c2_evidence_authorized" => false,
        "promotion_authorized" => false,
        "claim_ceiling" => "C1_pulsed_geometry_plus_fail_closed_C2_input_contract",
        "claim_boundary" => "This contract binds candidate geometry and integrated drive data but does not solve radiation hydrodynamics, absorption, compression, burn, alpha transport, mix, gain, chamber clearing, net power or engineering feasibility.")
    contract["physical_contract_hash"] = canonical_hash(
        _pulsed_rhd_physical_summary_v1(contract))
    return contract
end
