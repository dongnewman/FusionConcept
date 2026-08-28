const CAPABILITY_SOLVER_PORTFOLIO_V90_CLAIM_BOUNDARY =
    "Capability-routed repository-native reduced finite-pressure, open-field transport, finite-mode stability, and nonlinear DAE portfolio. Each result is candidate-bound and validity-scoped; it does not stand in for full free-boundary MHD, kinetic transport, or experimental validation."

struct SolverCapabilityManifestV90
    schema_version::String
    manifest_id::String
    executor_id::String
    operator_ids::Vector{String}
    state_variables::Vector{String}
    spatial_dimensions::Vector{String}
    boundary_kinds::Vector{String}
    time_semantics::Vector{String}
    validity_domain::Dict{String,Any}
    supported_observables::Vector{String}
    evidence_obligations::Vector{String}
    numerical_tolerances::Dict{String,Float64}
    mesh_levels::Vector{Int}
    software_hash::String
    container_hash::String
    independence_group::String
    manifest_hash::String
end

function _v90_manifest_body(item::SolverCapabilityManifestV90)
    Dict{String,Any}(
        "schema_version" => item.schema_version, "manifest_id" => item.manifest_id,
        "executor_id" => item.executor_id, "operator_ids" => item.operator_ids,
        "state_variables" => item.state_variables,
        "spatial_dimensions" => item.spatial_dimensions,
        "boundary_kinds" => item.boundary_kinds,
        "time_semantics" => item.time_semantics,
        "validity_domain" => item.validity_domain,
        "supported_observables" => item.supported_observables,
        "evidence_obligations" => item.evidence_obligations,
        "numerical_tolerances" => item.numerical_tolerances,
        "mesh_levels" => item.mesh_levels, "software_hash" => item.software_hash,
        "container_hash" => item.container_hash,
        "independence_group" => item.independence_group)
end

function compile_solver_capability_manifest_v90(; manifest_id, executor_id,
        operator_ids, state_variables, spatial_dimensions, boundary_kinds,
        time_semantics, validity_domain, supported_observables,
        evidence_obligations, numerical_tolerances, mesh_levels,
        software_hash, container_hash, independence_group)
    provisional = SolverCapabilityManifestV90("1.0.0", String(manifest_id),
        String(executor_id), sort!(unique(String.(operator_ids))),
        sort!(unique(String.(state_variables))),
        sort!(unique(String.(spatial_dimensions))),
        sort!(unique(String.(boundary_kinds))),
        sort!(unique(String.(time_semantics))),
        Dict{String,Any}(_v89_plain(validity_domain)),
        sort!(unique(String.(supported_observables))),
        sort!(unique(String.(evidence_obligations))),
        Dict{String,Float64}(String(key) => Float64(value)
            for (key, value) in pairs(numerical_tolerances)),
        sort!(unique(Int.(mesh_levels))), String(software_hash),
        String(container_hash), String(independence_group), "")
    _v89_assert_scientific_payload_label_free(_v90_manifest_body(provisional),
        "solver_manifest_v90")
    isempty(provisional.operator_ids) && throw(ArgumentError(
        "v90 solver manifest requires operators"))
    length(provisional.mesh_levels) >= 3 || throw(ArgumentError(
        "v90 solver manifest requires at least three declared mesh levels"))
    all(>(1), provisional.mesh_levels) || throw(ArgumentError(
        "v90 solver mesh levels must exceed one"))
    hash = canonical_hash(_v90_manifest_body(provisional))
    SolverCapabilityManifestV90(provisional.schema_version,
        provisional.manifest_id, provisional.executor_id,
        provisional.operator_ids, provisional.state_variables,
        provisional.spatial_dimensions, provisional.boundary_kinds,
        provisional.time_semantics, provisional.validity_domain,
        provisional.supported_observables, provisional.evidence_obligations,
        provisional.numerical_tolerances, provisional.mesh_levels,
        provisional.software_hash, provisional.container_hash,
        provisional.independence_group, hash)
end

function solver_capability_manifest_to_dict_v90(item::SolverCapabilityManifestV90)
    body = _v90_manifest_body(item); body["manifest_hash"] = item.manifest_hash; body
end

function default_solver_capability_manifests_v90()
    common = (software_hash = canonical_hash(Dict("repository" => "FusionConceptAI",
        "portfolio" => "v90")), container_hash = canonical_hash(Dict(
        "runtime" => "julia_project", "version" => string(VERSION))),
        numerical_tolerances = Dict("normalized_residual" => 1.0e-9,
            "balance" => 2.0e-8), mesh_levels = [16, 32, 64])
    definitions = [
        ("multiregion_nonlinear_dae_native_v90", "native_multiregion_dae_v90",
            ["candidate_bound_multiregion_nonlinear_dae_v90",
                "coupled_transport_reaction_radiation_self_heating_v90",
                "bounded_actuator_controller_fault_v90"],
            ["particle_inventory", "thermal_energy", "plasma_current",
                "magnetic_flux", "particle_actuator_output",
                "heating_actuator_output"],
            collect(V89_BOUNDARY_KINDS),
            ["nonlinear_dae_closure", "coupled_source_loss_closure",
                "control_fault_closure"],
            ["coupled_residual_norm", "independent_balance_error",
                "actuator_capacity_margin"], "native_nonlinear_dae_v90"),
        ("axisymmetric_finite_pressure_fd_v90", "native_axisymmetric_fd_v90",
            ["axisymmetric_fixed_boundary_finite_pressure_equilibrium_v90"],
            ["particle_inventory", "thermal_energy", "plasma_current", "magnetic_flux"],
            ["closed", "mixed", "free_boundary"],
            ["finite_pressure_equilibrium"],
            ["flux_profile", "force_balance_residual", "beta_proxy",
                "current_profile"], "native_axisymmetric_fd_v90"),
        ("open_core_parallel_transport_fd_v90", "native_open_parallel_fd_v90",
            ["open_core_anisotropic_parallel_transport_v90"],
            ["particle_inventory", "thermal_energy"],
            ["open", "mixed", "sheath", "absorbing"],
            ["open_parallel_transport"],
            ["parallel_energy_flux", "parallel_particle_flux",
                "target_temperature_ratio"], "native_open_parallel_fd_v90"),
        ("finite_mode_stability_native_v90", "native_finite_mode_stability_v90",
            ["finite_n_energy_principle_stability_v90",
                "finite_n_open_core_stability_v90"],
            ["particle_inventory", "thermal_energy", "plasma_current", "magnetic_flux"],
            collect(V89_BOUNDARY_KINDS),
            ["finite_mode_stability"],
            ["mode_margins", "minimum_eigenvalue", "applicable_modes"],
            "native_finite_mode_stability_v90")]
    manifests = SolverCapabilityManifestV90[]
    for (manifest_id, executor_id, operators, states, boundaries, obligations,
            observables, independence) in definitions
        push!(manifests, compile_solver_capability_manifest_v90(
            manifest_id = manifest_id, executor_id = executor_id,
            operator_ids = operators,
            state_variables = states, spatial_dimensions = ["0d", "1d", "2d"],
            boundary_kinds = boundaries,
            time_semantics = collect(V89_TIME_SEMANTICS),
            validity_domain = Dict("minimum_volume_m3" => 1.0e-6,
                "minimum_magnetic_field_t" => 1.0e-4,
                "maximum_beta_proxy" => 0.85, "finite_inputs_required" => true),
            supported_observables = observables,
            evidence_obligations = obligations,
            numerical_tolerances = common.numerical_tolerances,
            mesh_levels = common.mesh_levels, software_hash = common.software_hash,
            container_hash = common.container_hash, independence_group = independence))
    end
    manifests
end

function _v90_validity_match(manifest::SolverCapabilityManifestV90,
        realization::UniversalRealizationV89)
    p = realization.physical_parameters; u = realization.operating_state
    finite_values = Real[value for value in values(p) if value isa Real]
    append!(finite_values, Real[value for value in values(u) if value isa Real])
    all(isfinite, finite_values) || return false, "nonfinite_input"
    volume = Float64(get(p, "volume_m3", 0.0))
    field = Float64(get(p, "magnetic_field_t", 0.0))
    volume >= Float64(get(manifest.validity_domain, "minimum_volume_m3", 0.0)) ||
        return false, "minimum_volume_m3"
    field >= Float64(get(manifest.validity_domain, "minimum_magnetic_field_t", 0.0)) ||
        return false, "minimum_magnetic_field_t"
    particles = Float64(get(u, "particle_inventory", 0.0))
    temperature = Float64(get(p, "temperature_j", 0.0))
    beta = volume > 0 && field > 0 ? 2.0 * (4pi * 1.0e-7) *
        (2.0 * particles * temperature / volume) / field^2 : Inf
    beta <= Float64(get(manifest.validity_domain, "maximum_beta_proxy", Inf)) ||
        return false, "maximum_beta_proxy"
    true, "pass"
end

function _v90_manifest_matches(obligation, manifest::SolverCapabilityManifestV90,
        realization::UniversalRealizationV89)
    String(obligation["operator_id"]) in manifest.operator_ids ||
        return false, "operator_id"
    String(obligation["spatial_dimension"]) in manifest.spatial_dimensions ||
        return false, "spatial_dimension"
    String(obligation["time_semantics"]) in manifest.time_semantics ||
        return false, "time_semantics"
    isempty(setdiff(Set(String.(obligation["boundary_kinds"])),
        Set(manifest.boundary_kinds))) || return false, "boundary_kind"
    isempty(setdiff(Set(String.(obligation["required_state_ids"])),
        Set(manifest.state_variables))) || return false, "state_variables"
    String(obligation["evidence_obligation"]) in manifest.evidence_obligations ||
        return false, "evidence_obligation"
    required_observables = String.(get(obligation, "required_observables", String[]))
    isempty(setdiff(Set(required_observables), Set(manifest.supported_observables))) ||
        return false, "supported_observables"
    _v90_validity_match(manifest, realization)
end

function route_operator_capabilities_v90(topology::UniversalMultiRegionTopologyV89,
        realization::UniversalRealizationV89;
        manifests = default_solver_capability_manifests_v90())
    bindings = Dict{String,Any}[]; missing = Dict{String,Any}[]
    for obligation in topology.operator_obligations
        matches = SolverCapabilityManifestV90[]; mismatch_axes = String[]
        for manifest in manifests
            matched, axis = _v90_manifest_matches(obligation, manifest, realization)
            matched ? push!(matches, manifest) : push!(mismatch_axes, axis)
        end
        if isempty(matches)
            push!(missing, Dict{String,Any}(
                "obligation_id" => obligation["obligation_id"],
                "operator_id" => obligation["operator_id"], "status" => "unsupported",
                "reason" => "missing_operator_capability",
                "mismatch_axes" => sort!(unique(mismatch_axes))))
        else
            selected = first(sort!(matches; by = item -> item.manifest_hash))
            push!(bindings, Dict{String,Any}(
                "obligation_id" => obligation["obligation_id"],
                "operator_id" => obligation["operator_id"], "status" => "pass",
                "manifest_id" => selected.manifest_id,
                "executor_id" => selected.executor_id,
                "manifest_hash" => selected.manifest_hash,
                "independence_group" => selected.independence_group,
                "validity_domain_checked" => true,
                "evidence_obligation_matched" => true,
                "observables_matched" => true))
        end
    end
    status = isempty(missing) ? "pass" : "unsupported"
    body = Dict{String,Any}(
        "topology_hash" => topology.topology_hash,
        "candidate_physics_hash" => realization.candidate_physics_hash,
        "status" => status, "classification" => status == "pass" ?
            "all_operator_capabilities_routed_v90" : "missing_operator_capability",
        "bindings" => bindings, "missing" => missing,
        "routing_axes" => ["operator", "state", "dimension", "boundary",
            "time_semantics", "validity_domain", "observable", "evidence_obligation"],
        "family_routing_used" => false, "name_routing_used" => false,
        "candidate_id_routing_used" => false, "parent_routing_used" => false,
        "sentinel_routing_used" => false, "benchmark_routing_used" => false)
    body["route_hash"] = canonical_hash(body)
    body["claim_boundary"] = CAPABILITY_SOLVER_PORTFOLIO_V90_CLAIM_BOUNDARY
    body
end

function _v90_vertical_slice_obligations(topology, pattern)
    core = _v90_core_region(topology); open_regions = _v90_open_regions(topology)
    boundary_by_region = Dict(String(item["region_id"]) => String(item["kind"])
        for item in topology.boundaries)
    obligations = Dict{String,Any}[]
    function add(operator, region, evidence, states, observables)
        region_record = only(filter(item -> String(item["region_id"]) == region,
            topology.regions))
        push!(obligations, Dict{String,Any}(
            "obligation_id" => "o$(length(obligations) + 1)",
            "operator_id" => operator, "region_id" => region,
            "spatial_dimension" => String(region_record["dimension"]),
            "time_semantics" => String(region_record["time_semantics"]),
            "boundary_kinds" => [boundary_by_region[region]],
            "required_state_ids" => states,
            "required_observables" => observables,
            "evidence_obligation" => evidence))
    end
    add("candidate_bound_multiregion_nonlinear_dae_v90", core,
        "nonlinear_dae_closure", ["particle_inventory", "thermal_energy",
            "plasma_current", "magnetic_flux"], ["coupled_residual_norm",
            "independent_balance_error"])
    add("coupled_transport_reaction_radiation_self_heating_v90", core,
        "coupled_source_loss_closure", ["particle_inventory", "thermal_energy"],
        ["coupled_residual_norm"])
    add("bounded_actuator_controller_fault_v90", core, "control_fault_closure",
        ["particle_inventory", "thermal_energy"], ["actuator_capacity_margin"])
    if isempty(open_regions)
        add("axisymmetric_fixed_boundary_finite_pressure_equilibrium_v90", core,
            "finite_pressure_equilibrium", ["particle_inventory", "thermal_energy",
                "plasma_current", "magnetic_flux"], ["flux_profile",
                "force_balance_residual", "beta_proxy", "current_profile"])
        add("finite_n_energy_principle_stability_v90", core,
            "finite_mode_stability", ["particle_inventory", "thermal_energy",
                "plasma_current", "magnetic_flux"], ["mode_margins",
                "minimum_eigenvalue", "applicable_modes"])
    else
        open_region = first(open_regions)
        add("open_core_anisotropic_parallel_transport_v90", open_region,
            "open_parallel_transport", ["particle_inventory", "thermal_energy"],
            ["parallel_energy_flux", "parallel_particle_flux",
                "target_temperature_ratio"])
        add("finite_n_open_core_stability_v90", core, "finite_mode_stability",
            ["particle_inventory", "thermal_energy", "plasma_current", "magnetic_flux"],
            ["mode_margins", "minimum_eigenvalue", "applicable_modes"])
    end
    obligations
end

function _v90_generated_reference(structure_seed::Integer, pattern::Symbol)
    phase = mod(Int(structure_seed), 997) / 997.0
    open = pattern == :closed_core_open_loss
    field = 1.2 + 0.35sin(2pi * phase)^2
    minor = 0.45 + 0.08cos(2pi * phase)^2
    volume = (open ? 7.0 : 9.0) * (0.92 + 0.16phase)
    temperature = (0.8 + 0.25phase) * 1.0e-15
    particles = (0.75 + 0.30phase) * 1.0e20
    thermal = 3.0 * particles * temperature * (0.78 + 0.04sin(phase * 11))
    flux = pi * minor^2 * field * (0.88 + 0.03cos(phase * 7))
    current = (0.65 + 0.22phase) * 1.0e6
    Dict{String,Any}(
        "time_mode" => "pulsed",
        "regions" => [Dict("kind" => open ?
            "closed_core_with_open_parallel_loss_boundary" : "closed_plasma_core")],
        "capabilities" => [Dict("capability_id" => "conserved_particle_inventory")],
        "module_bindings" => [Dict("operator_id" =>
            "candidate_bound_multiregion_nonlinear_dae_v90",
            "state_ids" => ["particle_inventory", "thermal_energy",
                "plasma_current", "magnetic_flux"],
            "evidence_ceiling" => "nonlinear_dae_closure")],
        "state_variables" => [
            Dict("state_id" => "particle_inventory", "account" => "particles",
                "unit" => "1", "positivity_required" => true),
            Dict("state_id" => "thermal_energy", "account" => "energy",
                "unit" => "J", "positivity_required" => true),
            Dict("state_id" => "plasma_current", "account" => "current",
                "unit" => "A", "positivity_required" => false),
            Dict("state_id" => "magnetic_flux", "account" => "magnetic_flux",
                "unit" => "Wb", "positivity_required" => false)],
        "initial_conditions" => Dict("particle_inventory" => particles,
            "thermal_energy" => thermal, "plasma_current" => current,
            "magnetic_flux" => flux),
        "parameters" => Dict("volume_m3" => volume, "minor_radius_m" => minor,
            "characteristic_length_m" => open ? 4.2 : 3.2,
            "magnetic_field_t" => field, "temperature_j" => temperature,
            "input_power_w" => (3.5 + phase) * 1.0e6,
            "pulse_duration_s" => 0.2 + 0.1phase,
            "fuel" => "declared candidate-bound screening plasma"))
end

"Generate a non-sentinel vertical slice. No anchor, family, parent, or benchmark input is read."
function compile_generated_vertical_slice_v90(structure_seed::Integer;
        pattern::Symbol = isodd(structure_seed) ? :closed_multiregion :
            :closed_core_open_loss, topology_template = nothing)
    reference = _v90_generated_reference(structure_seed, pattern)
    topology = if topology_template === nothing
        base = generate_universal_multiregion_topology_v89(structure_seed; pattern)
        regions = deepcopy(base.regions)
        for region in regions, slot in region["state_slots"]
            slot["slot_id"] = replace(String(slot["slot_id"]), "loss_" => "")
        end
        obligations = _v90_vertical_slice_obligations(base, pattern)
        compile_universal_multiregion_topology_v89(regions = regions,
            interfaces = base.interfaces, boundaries = base.boundaries,
            field_topologies = base.field_topologies, control_paths = base.control_paths,
            event_transitions = base.event_transitions, operator_obligations = obligations)
    else
        topology_template isa UniversalMultiRegionTopologyV89 || throw(ArgumentError(
            "v90 topology template has wrong type"))
        topology_template
    end
    realization, _ = inverse_compile_reference_realization_v89(topology, reference;
        physical_variant_seed = 10_000 + structure_seed,
        operating_variant_seed = 20_000 + structure_seed,
        control_variant_seed = 30_000 + structure_seed)
    candidate = compile_universal_device_candidate_v89(
        "generated_v90_$(structure_seed)", topology, realization;
        structure_seed, mission_scope = Dict("mission_id" =>
            "candidate_bound_reduced_vertical_slice", "operating_mode" => "pulsed"),
        evidence_scope = Dict("evidence_level" => "v90_reduced_hard_physics",
            "comparison_scope" => "same_capability_cell_and_evidence"))
    (topology = topology, realization = realization, candidate = candidate,
        pattern = pattern)
end

"Compile a sealed reference through the same v90 scientific chain; UI labels remain outside hashes."
function compile_reference_vertical_slice_v90(anchor_raw;
        structure_seed::Integer, physical_variant_seed::Integer,
        operating_variant_seed::Integer, control_variant_seed::Integer)
    anchor = _v89_plain(anchor_raw)
    base, provenance = inverse_compile_reference_topology_v89(anchor)
    pattern = isempty(_v90_open_regions(base)) ? :closed_multiregion :
        :closed_core_open_loss
    regions = deepcopy(base.regions)
    for region in regions, slot in region["state_slots"]
        slot["slot_id"] = replace(String(slot["slot_id"]), "loss_" => "")
    end
    obligations = _v90_vertical_slice_obligations(base, pattern)
    topology = compile_universal_multiregion_topology_v89(regions = regions,
        interfaces = base.interfaces, boundaries = base.boundaries,
        field_topologies = base.field_topologies, control_paths = base.control_paths,
        event_transitions = base.event_transitions, operator_obligations = obligations)
    realization, realization_provenance = inverse_compile_reference_realization_v89(
        topology, anchor; physical_variant_seed, operating_variant_seed,
        control_variant_seed)
    candidate = compile_universal_device_candidate_v89(
        "sealed_reference_$(first(topology.topology_hash, 12))", topology,
        realization; structure_seed, mission_scope = Dict("mission_id" =>
            "sealed_reference_regression", "operating_mode" => get(anchor,
                "time_mode", "declared")), evidence_scope = Dict(
            "evidence_level" => "v90_reduced_hard_physics",
            "comparison_scope" => "same_capability_cell_and_evidence"))
    (topology = topology, realization = realization, candidate = candidate,
        pattern = pattern, inverse_topology_provenance = provenance,
        inverse_realization_provenance = realization_provenance)
end

function _v90_final_normalized(result, id)
    Float64(result["final_normalized_state"][id])
end

function solve_axisymmetric_finite_pressure_v90(contract, nonlinear_result;
        resolution::Integer = 32)
    Int(resolution) >= 8 || throw(ArgumentError("v90 equilibrium resolution too small"))
    core = String(contract.model_parameters["core_region_id"]); n = Int(resolution)
    current = _v90_final_normalized(nonlinear_result, "$core::plasma_current")
    inventory = _v90_final_normalized(nonlinear_result, "$core::particle_inventory")
    energy = _v90_final_normalized(nonlinear_result, "$core::thermal_energy")
    beta = Float64(contract.model_parameters["beta_reference"]) * inventory * energy
    dr = 1.0 / (n - 1); matrix = zeros(Float64, n, n); rhs = zeros(Float64, n)
    matrix[1, 1] = 1.0; matrix[1, 2] = -1.0
    for index in 2:n-1
        radius = (index - 1) * dr
        matrix[index, index - 1] = -1.0 + dr / max(2radius, dr)
        matrix[index, index] = 2.0 + dr^2 * (0.2 + 0.4beta)
        matrix[index, index + 1] = -1.0 - dr / max(2radius, dr)
        rhs[index] = dr^2 * current * (1.0 - radius^2) * (1.0 - 0.25beta)
    end
    matrix[n, n] = 1.0
    flux_profile = try matrix \ rhs catch; fill(NaN, n) end
    residual = matrix * flux_profile - rhs
    residual_norm = all(isfinite, residual) ? maximum(abs, residual; init = 0.0) : nothing
    status = residual_norm !== nothing && residual_norm <= 1.0e-9 ? "pass" : "unknown"
    input = Dict("contract_hash" => contract.contract_hash,
        "nonlinear_result_hash" => nonlinear_result["result_hash"],
        "resolution" => n, "operator_id" =>
            "axisymmetric_fixed_boundary_finite_pressure_equilibrium_v90")
    body = Dict{String,Any}("status" => status,
        "classification" => status == "pass" ? "pass_reduced_fixed_boundary_equilibrium" :
            "unknown_numerical_nonconvergence", "solver_input_hash" => canonical_hash(input),
        "resolution" => n, "mesh_hash" => canonical_hash(Dict("radial_cells" => n)),
        "flux_profile" => all(isfinite, flux_profile) ? flux_profile : nothing,
        "force_balance_residual" => residual_norm, "beta_proxy" => beta,
        "current_profile_parameter" => current,
        "applicability_proof" => Dict("axisymmetric" => true,
            "fixed_boundary" => true, "finite_pressure" => true,
            "candidate_bound" => true),
        "evidence_ceiling" => "reduced_axisymmetric_fixed_boundary_finite_pressure")
    body["result_hash"] = canonical_hash(body); body
end

function solve_open_parallel_transport_v90(contract, nonlinear_result;
        resolution::Integer = 32)
    Int(resolution) >= 8 || throw(ArgumentError("v90 open transport resolution too small"))
    opens = String.(contract.model_parameters["open_region_ids"])
    isempty(opens) && return Dict{String,Any}("status" => "not_applicable",
        "reason" => "no_open_region")
    core = String(contract.model_parameters["core_region_id"]); n = Int(resolution)
    core_energy = _v90_final_normalized(nonlinear_result, "$core::thermal_energy")
    target = 0.15core_energy; ds = 1.0 / (n - 1)
    temperature = collect(range(core_energy, target; length = n))
    converged = false; history = Float64[]
    for _ in 1:30
        residual = zeros(Float64, n); jacobian = zeros(Float64, n, n)
        residual[1] = temperature[1] - core_energy; jacobian[1, 1] = 1.0
        for index in 2:n-1
            value = max(temperature[index], 1.0e-10)
            residual[index] = -(temperature[index + 1] - 2temperature[index] +
                temperature[index - 1]) + ds^2 * 0.35value^1.5
            jacobian[index, index - 1] = -1.0
            jacobian[index, index] = 2.0 + ds^2 * 0.525sqrt(value)
            jacobian[index, index + 1] = -1.0
        end
        residual[n] = temperature[n] - target; jacobian[n, n] = 1.0
        norm_value = maximum(abs, residual; init = 0.0); push!(history, norm_value)
        norm_value <= 1.0e-9 && (converged = true; break)
        delta = try -(jacobian \ residual) catch; fill(NaN, n) end
        all(isfinite, delta) || break
        temperature .= max.(temperature .+ delta, 1.0e-8)
    end
    parallel_flux = converged ? -(temperature[end] - temperature[end - 1]) / ds : nothing
    input = Dict("contract_hash" => contract.contract_hash,
        "nonlinear_result_hash" => nonlinear_result["result_hash"],
        "resolution" => n, "operator_id" =>
            "open_core_anisotropic_parallel_transport_v90")
    body = Dict{String,Any}("status" => converged ? "pass" : "unknown",
        "classification" => converged ? "pass_reduced_anisotropic_parallel_transport" :
            "unknown_numerical_nonconvergence", "solver_input_hash" => canonical_hash(input),
        "resolution" => n, "mesh_hash" => canonical_hash(Dict("parallel_cells" => n)),
        "temperature_profile" => converged ? temperature : nothing,
        "parallel_energy_flux" => parallel_flux,
        "parallel_particle_flux" => converged ? 0.8parallel_flux : nothing,
        "target_temperature_ratio" => converged ? temperature[end] / temperature[1] : nothing,
        "convergence_history" => history,
        "applicability_proof" => Dict("open_region" => first(opens),
            "anisotropic_parallel_model" => true, "sheath_target" => true,
            "candidate_bound" => true),
        "evidence_ceiling" => "reduced_open_field_parallel_transport")
    body["result_hash"] = canonical_hash(body); body
end

function evaluate_finite_mode_stability_v90(contract, nonlinear_result,
        equilibrium_or_transport_result)
    core = String(contract.model_parameters["core_region_id"])
    inventory = _v90_final_normalized(nonlinear_result, "$core::particle_inventory")
    energy = _v90_final_normalized(nonlinear_result, "$core::thermal_energy")
    beta = Float64(contract.model_parameters["beta_reference"]) * inventory * energy
    open = !isempty(contract.model_parameters["open_region_ids"])
    modes = Dict{String,Any}[]
    if open
        for mode in 1:4
            margin = 1.0 + 0.12mode^2 - 0.65beta
            push!(modes, Dict("mode" => "axial_finite_n_$mode", "margin" => margin,
                "status" => margin > 0 ? "pass" : "fail"))
        end
        push!(modes, Dict("mode" => "firehose", "margin" => 1.0 - 0.8beta,
            "status" => beta < 1.25 ? "pass" : "fail"))
        push!(modes, Dict("mode" => "mirror_anisotropy", "margin" => 0.75 - 0.4beta,
            "status" => beta < 1.875 ? "pass" : "fail"))
    else
        grid = 24; dr = 1.0 / (grid + 1)
        for mode in 1:4
            operator = SymTridiagonal(fill(2.0 / dr^2 + mode^2 - 1.4beta, grid),
                fill(-1.0 / dr^2, grid - 1))
            minimum_eigenvalue = minimum(eigvals(operator))
            push!(modes, Dict("mode" => "finite_n_$mode",
                "minimum_eigenvalue" => minimum_eigenvalue,
                "margin" => minimum_eigenvalue,
                "status" => minimum_eigenvalue > 0 ? "pass" : "fail"))
        end
    end
    converged_upstream = String(equilibrium_or_transport_result["status"]) == "pass"
    unfavorable = any(item -> item["status"] == "fail", modes)
    status = !converged_upstream ? "unknown" : unfavorable ? "fail" : "pass"
    body = Dict{String,Any}("status" => status,
        "classification" => status == "pass" ? "pass_applicable_finite_modes" :
            status == "fail" ? "fail_converged_unfavorable_finite_mode" :
                "unknown_upstream_nonconvergence",
        "solver_input_hash" => canonical_hash(Dict("contract_hash" =>
            contract.contract_hash, "upstream_result_hash" =>
            equilibrium_or_transport_result["result_hash"], "modes" => 1:4)),
        "applicable_modes" => modes, "beta_proxy" => beta,
        "missing_modes" => open ? ["full_kinetic_global_modes", "nonlinear_saturation"] :
            ["resistive_modes", "kinetic_modes", "nonlinear_saturation"],
        "applicability_proof" => Dict("field_semantics" => open ?
            "closed_core_connected_open_loss" : "closed_flux_fixed_boundary",
            "finite_mode_inventory" => [1, 2, 3, 4], "candidate_bound" => true),
        "evidence_ceiling" => "reduced_finite_mode_linear_stability")
    body["result_hash"] = canonical_hash(body); body
end

function evaluate_v90_hard_physics_vertical_slice(slice)
    route = route_operator_capabilities_v90(slice.topology, slice.realization)
    if route["status"] != "pass"
        return Dict{String,Any}("status" => "unsupported", "route" => route,
            "reason" => "missing_operator_capability")
    end
    contract = compile_multiregion_nonlinear_dae_v90(slice.candidate,
        slice.topology, slice.realization, route)
    nonlinear = solve_multiregion_nonlinear_dae_v90(contract)
    if nonlinear["status"] != "pass"
        return Dict{String,Any}("status" => "unknown", "route" => route,
            "contract" => contract, "nonlinear" => nonlinear,
            "reason" => "numerical_nonconvergence")
    end
    open = !isempty(contract.model_parameters["open_region_ids"])
    deep = open ? solve_open_parallel_transport_v90(contract, nonlinear;
        resolution = 24) : solve_axisymmetric_finite_pressure_v90(contract, nonlinear;
        resolution = 24)
    stability = evaluate_finite_mode_stability_v90(contract, nonlinear, deep)
    gates = Dict{String,Any}[
        Dict("gate_id" => "candidate_bound_nonlinear_dae", "status" => nonlinear["status"],
            "evidence_hash" => nonlinear["result_hash"]),
        Dict("gate_id" => open ? "open_parallel_transport" :
            "finite_pressure_equilibrium", "status" => deep["status"],
            "evidence_hash" => deep["result_hash"]),
        Dict("gate_id" => "applicable_finite_mode_stability",
            "status" => stability["status"], "evidence_hash" => stability["result_hash"]),
        Dict("gate_id" => "actuator_capacity",
            "status" => Float64(contract.model_parameters[
                "actuator_capacity_ratio"]) >= 1.0 ? "pass" : "fail",
            "evidence_hash" => canonical_hash(Dict("capacity_ratio" =>
                contract.model_parameters["actuator_capacity_ratio"])))]
    status = any(gate -> gate["status"] == "fail", gates) ? "fail" :
        any(gate -> gate["status"] != "pass", gates) ? "unknown" : "pass"
    body = Dict{String,Any}("status" => status, "route" => route,
        "contract" => contract, "nonlinear" => nonlinear,
        "equilibrium_or_transport" => deep, "stability" => stability,
        "gates" => gates, "hard_gate_survivor" => status == "pass",
        "candidate_hash" => slice.candidate.candidate_hash,
        "candidate_physics_hash" => slice.realization.candidate_physics_hash,
        "capability_cell" => slice.candidate.capability_cell,
        "sentinel" => false, "retroactive_feasibility_credit" => false,
        "evidence_ceiling" => "v90_reduced_candidate_bound_hard_physics")
    body["result_hash"] = canonical_hash(Dict(key => value for (key, value) in body
        if key != "contract"))
    body
end
