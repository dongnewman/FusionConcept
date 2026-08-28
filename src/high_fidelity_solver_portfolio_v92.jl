const HIGH_FIDELITY_SOLVER_PORTFOLIO_V92_CLAIM_BOUNDARY =
    "V92 routes only by declared operators, states, region dimensions, boundaries/interfaces, field semantics, evidence obligations, and solver-input compatibility. Availability or startup is not convergence, cross-code agreement, physical closure, or validation credit."

const V92_ROUTING_AXES = ("declared_operators", "state_variables",
    "region_dimensions", "boundary_conditions", "interface_conditions",
    "field_semantics", "evidence_obligations",
    "solver_input_compatibility")

struct EquilibriumRequestV92
    payload::Dict{String,Any}
    request_hash::String
end
struct EquilibriumResultV92
    payload::Dict{String,Any}
    result_hash::String
end
struct OrbitRequestV92
    payload::Dict{String,Any}
    request_hash::String
end
struct OrbitResultV92
    payload::Dict{String,Any}
    result_hash::String
end
struct StabilityRequestV92
    payload::Dict{String,Any}
    request_hash::String
end
struct StabilityResultV92
    payload::Dict{String,Any}
    result_hash::String
end

function _v92_installation_record(root, backend_id, relative_executable,
        version, capabilities; lineage, discretization, organization)
    path = joinpath(root, split(relative_executable, '/')...)
    available = isfile(path)
    return Dict{String,Any}(
        "backend_id" => backend_id, "available" => available,
        "executable" => replace(relative_executable, '\\' => '/'),
        "version" => available ? version : nothing,
        "executable_sha256" => available ? _v92_sha256_file(path) : nothing,
        "capabilities" => capabilities, "equation_model_lineage" => lineage,
        "discretization" => discretization,
        "development_maintenance_organization" => organization,
        "execution_environment_hash" => available ? canonical_hash(Dict(
            "executable_sha256" => _v92_sha256_file(path),
            "version" => version, "path" => relative_executable)) : nothing,
        "availability_credit" => false)
end

function audit_solver_installations_v92(project_root::AbstractString)
    root = abspath(project_root)
    records = Dict{String,Any}[
        _v92_installation_record(root, "desc_0_17_3",
            ".venv-desc/Scripts/python.exe", "DESC 0.17.3",
            ["three_dimensional_finite_pressure_equilibrium"],
            lineage = "spectral force_or_energy_balance optimization",
            discretization = "Fourier_Zernike_spectral",
            organization = "DESC maintainers"),
        _v92_installation_record(root, "freegs_0_8_2",
            ".venv-freegs/Scripts/python.exe", "FreeGS 0.8.2",
            ["grad_shafranov_free_boundary"],
            lineage = "Python Grad_Shafranov finite_element implementation",
            discretization = "finite_element",
            organization = "FreeGS maintainers"),
        _v92_installation_record(root, "vmex_0_7_0",
            ".conda-vmex/Scripts/vmec.exe", "VMEX 0.7.0",
            ["independent_three_dimensional_finite_pressure_equilibrium",
                "fixed_or_free_boundary_nested_surface_equilibrium"],
            lineage = "JAX VMEC_equation implementation",
            discretization = "Fourier_radial_multigrid",
            organization = "VMEX maintainers"),
        _v92_installation_record(root, "open_extended_mhd_primary",
            ".external/open_extended_mhd.exe", "not_installed",
            ["open_field_extended_mhd_or_kinetic"],
            lineage = "required external extended_MHD",
            discretization = "required independent high_order_FE_or_DG",
            organization = "external project required"),
        _v92_installation_record(root, "open_kinetic_independent",
            ".external/open_kinetic.exe", "not_installed",
            ["independent_open_field_extended_mhd_or_kinetic"],
            lineage = "required external kinetic or two_fluid",
            discretization = "required independent DG_or_particle",
            organization = "external project required"),
        _v92_installation_record(root, "spec_multiregion",
            ".external/spec.exe", "not_installed",
            ["multi_region_relaxed_or_extended_mhd"],
            lineage = "multi_region_relaxed_MHD",
            discretization = "spectral_multi_region",
            organization = "SPEC maintainers"),
        _v92_installation_record(root, "coupled_extended_mhd",
            ".external/coupled_extended_mhd.exe", "not_installed",
            ["monolithic_or_domain_decomposed_coupled_physics"],
            lineage = "candidate_bound coupled extended_MHD",
            discretization = "independent high_order finite_element",
            organization = "external project required"),
        _v92_installation_record(root, "ascot5_independent_orbit",
            ".external/ascot5.exe", "not_installed",
            ["independent_guiding_center_and_full_orbit"],
            lineage = "ASCOT independent Monte_Carlo orbit following",
            discretization = "ASCOT native",
            organization = "ASCOT maintainers")]
    available_capabilities = sort!(unique(vcat((String.(record["capabilities"])
        for record in records if record["available"])...)))
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "records" => records,
        "available_capabilities" => available_capabilities,
        "path_global_discovery_at_seal" => Dict("desc" => false,
            "freegs" => false, "vmec" => false, "spec" => false,
            "ascot5" => false, "gkeyll" => false),
        "local_environment_discovery" => true,
        "claim_boundary" => HIGH_FIDELITY_SOLVER_PORTFOLIO_V92_CLAIM_BOUNDARY)
    body["audit_hash"] = canonical_hash(body)
    return body
end

function route_equilibrium_capability_v92(realization_raw)
    realization = _v92_plain(realization_raw)
    obligations = realization["applicability_obligations"]
    axes = Dict{String,Any}(axis => obligations[axis] for axis in
        V92_ROUTING_AXES)
    semantics = Set(String.(axes["field_semantics"]))
    boundaries = Set(String.(axes["boundary_conditions"]))
    operators = Set(String.(axes["declared_operators"]))
    mixed = "hybrid_field" in semantics ||
        (("open_guiding_field" in semantics || "open" in boundaries) &&
         any(item -> item in semantics,
            ("axisymmetric_closed", "three_dimensional_closed")))
    route_id, primary, independent = if mixed
        ("mixed_topology_coupled",
            "monolithic_or_domain_decomposed_coupled_physics",
            "independent_coupled_physics_auditor")
    elseif "open_guiding_field" in semantics || "open" in boundaries ||
            "terminal_balance" in operators
        ("open_field_extended_state", "open_field_extended_mhd_or_kinetic",
            "independent_open_field_extended_mhd_or_kinetic")
    elseif any(item -> item in semantics, ("island", "current_sheet",
            "multi_region_field")) || any(item -> item in operators,
            ("multi_region_relaxation", "current_sheet_balance",
                "reconnection_operator"))
        ("island_current_sheet_multi_region",
            "multi_region_relaxed_or_extended_mhd",
            "independent_multi_region_or_extended_mhd")
    elseif "three_dimensional_closed" in semantics
        ("three_dimensional_nested_closed_surfaces",
            "three_dimensional_finite_pressure_equilibrium",
            "independent_three_dimensional_finite_pressure_equilibrium")
    elseif "axisymmetric_closed" in semantics
        ("axisymmetric_closed_free_boundary",
            "grad_shafranov_free_boundary", "independent_grad_shafranov")
    else
        ("unsupported_declared_equations", "unsupported", "unsupported")
    end
    body = Dict{String,Any}(
        "route_id" => route_id, "routing_axes" => axes,
        "primary_capability" => primary,
        "independent_capability" => independent,
        "family_or_device_label_used" => false,
        "open_field_sent_to_nested_surface_solver" => false)
    body["route_hash"] = canonical_hash(body)
    return body
end

function compile_equilibrium_request_v92(realization_raw)
    realization = _v92_plain(realization_raw)
    realization["qualification"]["status"] == "pass" || throw(ArgumentError(
        "equilibrium request requires physical_realization=pass"))
    route = route_equilibrium_capability_v92(realization)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "stage_id" => "equilibrium", "candidate_id" => realization["candidate_id"],
        "candidate_hash" => realization["candidate_hash"],
        "realization_hash" => realization["realization_hash"],
        "route" => route,
        "equations" => ["candidate_bound_magnetic_force_balance",
            "divergence_free_magnetic_field", "declared_region_balance",
            "declared_interface_particle_energy_current_flux_force_balance"],
        "state_variables" => route["routing_axes"]["state_variables"],
        "regions" => realization["regions"],
        "oriented_surfaces" => realization["oriented_surfaces"],
        "mesh_levels" => realization["volume_meshes"],
        "field_sources" => realization["field_sources"],
        "profiles" => realization["profiles"],
        "interface_conditions" => realization["interface_conditions"],
        "threshold_manifest_sha256" =>
            "5c6ca832d0693a341429fab44b1876196bd6fcde3153b3e78659656686679bd1",
        "solver_independence_manifest_sha256" =>
            "466131703754454c9f75a406402e6114ab53044c87da60c518dfb39d6caa5a19",
        "random_seed" => 920001,
        "claim_boundary" => HIGH_FIDELITY_SOLVER_PORTFOLIO_V92_CLAIM_BOUNDARY)
    hash = canonical_hash(body); body["request_hash"] = hash
    return EquilibriumRequestV92(body, hash)
end

function execute_equilibrium_request_v92(request::EquilibriumRequestV92,
        installation_audit_raw)
    audit = _v92_plain(installation_audit_raw)
    available = Set(String.(audit["available_capabilities"]))
    route = request.payload["route"]
    primary = String(route["primary_capability"])
    independent = String(route["independent_capability"])
    primary_available = primary in available
    independent_available = independent in available
    status = primary_available ? "unknown_not_executed_by_portfolio_adapter" :
        "unsupported"
    reason = primary_available ?
        "compatible_primary_backend_present_but_candidate_transformer_and_execution_not_completed" :
        "no_compatible_primary_backend_for_declared_route"
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "stage_id" => "equilibrium", "candidate_id" =>
            request.payload["candidate_id"], "candidate_hash" =>
            request.payload["candidate_hash"], "realization_hash" =>
            request.payload["realization_hash"], "request_hash" =>
            request.request_hash, "route_id" => route["route_id"],
        "primary_capability" => primary,
        "independent_capability" => independent,
        "primary_backend_available" => primary_available,
        "independent_backend_available" => independent_available,
        "status" => status, "reason" => reason,
        "solver_executed" => false, "converged" => false,
        "residuals" => nothing, "force_balance" => nothing,
        "divB" => nothing, "boundary_mismatch" => nothing,
        "unresolved_solver_disagreement" => independent_available ?
            "unknown_comparison_not_executed" : "unknown_independent_model_missing",
        "feasibility_credit" => false,
        "claim_boundary" => HIGH_FIDELITY_SOLVER_PORTFOLIO_V92_CLAIM_BOUNDARY)
    hash = canonical_hash(body); body["result_hash"] = hash
    return EquilibriumResultV92(body, hash)
end

function compile_orbit_request_v92(realization_raw, equilibrium::EquilibriumResultV92)
    realization = _v92_plain(realization_raw)
    equilibrium.payload["status"] == "pass" || throw(ArgumentError(
        "orbit request requires applicable_equilibrium=pass"))
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "stage_id" => "field_line_orbit", "candidate_id" =>
            realization["candidate_id"], "candidate_hash" =>
            realization["candidate_hash"], "realization_hash" =>
            realization["realization_hash"], "equilibrium_result_hash" =>
            equilibrium.result_hash, "field_state_source" =>
            "same_candidate_bound_equilibrium_state",
        "integrators" => ["independent_field_line_RK", "guiding_center",
            "full_gyro_Boris_when_applicable"],
        "physics" => ["collisions", "pitch_angle_scattering",
            "charge_exchange_when_applicable", "nbi_birth_when_applicable",
            "three_dimensional_wall_interaction"],
        "time_step_levels" => [0.05, 0.025, 0.0125],
        "marker_counts" => [10000, 50000, 250000], "seed" => 920003)
    hash = canonical_hash(body); body["request_hash"] = hash
    return OrbitRequestV92(body, hash)
end

function compile_stability_request_v92(realization_raw,
        equilibrium::EquilibriumResultV92)
    realization = _v92_plain(realization_raw)
    equilibrium.payload["status"] == "pass" || throw(ArgumentError(
        "stability request requires applicable_equilibrium=pass"))
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "stage_id" => "stability", "candidate_id" =>
            realization["candidate_id"], "candidate_hash" =>
            realization["candidate_hash"], "realization_hash" =>
            realization["realization_hash"], "equilibrium_result_hash" =>
            equilibrium.result_hash,
        "applicability_basis" =>
            realization["applicability_obligations"],
        "mode_catalog" => ["ideal_mhd", "resistive_mhd",
            "kinetic_fast_particle", "microinstability", "finite_n_global",
            "nonlinear_initial_value", "controller_actuator_fault_coupled"],
        "resolution_levels" => ["coarse", "medium", "fine"],
        "mode_numbers" => [0, 1, 2, 3, 4, 5, 8, 12, 16, 24, 32],
        "profile_uncertainty_quantiles" => [0.05, 0.5, 0.95],
        "nonlinear_perturbation_amplitudes" => [1e-6, 1e-4, 1e-2],
        "seed" => 920005)
    hash = canonical_hash(body); body["request_hash"] = hash
    return StabilityRequestV92(body, hash)
end
