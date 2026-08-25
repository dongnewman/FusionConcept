const PHYSICAL_TRANSPORT_V72_CLAIM_BOUNDARY =
    "The v72 open-field collision bound is a one-sided falsification screen. Falling below the candidate-required energy-confinement time is a screen_fail; meeting the proxy remains unknown until candidate-bound kinetic transport and stability solvers close the obligation."

struct PhysicalTransportGateV72
    schema_version::String
    topology_hash::String
    realization_hash::String
    screen_evidence_hash::String
    completeness::Symbol
    conclusion::Symbol
    classification_code::String
    applicability::Dict{String,Any}
    evidence::Dict{String,Any}
    missing_requirements::Vector{String}
    claim_boundary::String
    evidence_hash::String
end

function _v72_result(realization, screen, completeness, conclusion, code,
        applicability, evidence, missing)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "topology_hash" => realization.topology_hash,
        "realization_hash" => realization.realization_hash,
        "screen_evidence_hash" => screen.evidence_hash,
        "completeness" => String(completeness),
        "conclusion" => String(conclusion),
        "classification_code" => code,
        "applicability" => applicability,
        "evidence" => evidence,
        "missing_requirements" => sort!(unique(String.(missing))),
        "claim_boundary" => PHYSICAL_TRANSPORT_V72_CLAIM_BOUNDARY)
    return PhysicalTransportGateV72("1.0.0", realization.topology_hash,
        realization.realization_hash, screen.evidence_hash, completeness, conclusion,
        String(code), Dict{String,Any}(applicability), Dict{String,Any}(evidence),
        sort!(unique(String.(missing))), PHYSICAL_TRANSPORT_V72_CLAIM_BOUNDARY,
        canonical_hash(body))
end

"""Apply an optimistic collision-limited open-field confinement upper proxy."""
function evaluate_physical_transport_gate_v72(
        realization::PhysicalDeviceRealizationV71,
        screen::PhysicalDeviceScreenV71, parameter_binding;
        coulomb_log_bounds = (12.0, 20.0), mean_ion_mass_number = 2.5)
    binding = _v71_plain(parameter_binding)
    canonical_hash(binding) == realization.candidate_binding_hash ||
        throw(ArgumentError("v72 transport binding differs from physical realization"))
    screen.realization_hash == realization.realization_hash ||
        throw(ArgumentError("v72 transport screen differs from physical realization"))
    realization.completeness == :complete || return _v72_result(realization, screen,
        :incomplete, :unknown, "physical_realization_incomplete",
        Dict("status" => "unknown"), Dict{String,Any}(),
        ["complete_physical_realization"])
    region = _v71_primary_region(realization)
    geometry_class = String(region["geometry_class"])
    boundary_class = String(get(region, "boundary_class", "unknown"))
    applicability = Dict{String,Any}(
        "geometry_class" => geometry_class,
        "boundary_class" => boundary_class,
        "routing_inputs" => ["geometry_class", "boundary_class", "field_evidence"],
        "device_family_routing_used" => false)
    if geometry_class != "linear_volume_v1" || !(boundary_class in ("open", "mixed"))
        applicability["status"] = "unsupported"
        return _v72_result(realization, screen, :incomplete, :unsupported,
            "missing_closed_or_nonlocal_transport_capability", applicability,
            Dict{String,Any}(), ["candidate_bound_closed_field_transport_backend"])
    end
    haskey(screen.field_evidence, "minimum_field_t") || return _v72_result(
        realization, screen, :incomplete, :unknown, "missing_field_evidence",
        merge(applicability, Dict("status" => "unknown")), Dict{String,Any}(),
        ["minimum_and_maximum_field_evidence"])
    minimum_field = Float64(screen.field_evidence["minimum_field_t"])
    maximum_field = Float64(screen.field_evidence["maximum_field_t"])
    required_tau = Float64(screen.plasma_evidence["required_energy_confinement_s"])
    density_m3 = _v71_binding_number(binding, "target_total_ion_density_m3")
    temperature_ev = 1.0e3 * _v71_binding_number(binding, "target_ion_temperature_kev")
    lower_log, upper_log = Float64.(coulomb_log_bounds)
    0 < lower_log <= upper_log || throw(ArgumentError("invalid Coulomb-log bounds"))
    minimum_field > 0 && maximum_field >= minimum_field || return _v72_result(
        realization, screen, :incomplete, :unknown, "invalid_field_bound",
        merge(applicability, Dict("status" => "unknown")), Dict{String,Any}(),
        ["positive_ordered_field_bounds"])
    # NRL-formulary ion-ion 90-degree collision-time proxy, n in cm^-3 and T in eV.
    density_cm3 = density_m3 * 1.0e-6
    numerator = 2.09e7 * sqrt(Float64(mean_ion_mass_number)) * temperature_ev^(3 / 2)
    collision_time_short = numerator / (density_cm3 * upper_log)
    collision_time_long = numerator / (density_cm3 * lower_log)
    mirror_ratio = maximum_field / minimum_field
    loss_cone_half_angle = asin(sqrt(clamp(1.0 / mirror_ratio, 0.0, 1.0)))
    collision_limited_upper = collision_time_long * mirror_ratio
    margin_ratio = collision_limited_upper / required_tau
    evidence = Dict{String,Any}(
        "model_id" => "optimistic_open_field_collision_loss_upper_v1",
        "model_role" => "one_sided_falsification_only",
        "minimum_field_t" => minimum_field,
        "maximum_field_t" => maximum_field,
        "mirror_ratio" => mirror_ratio,
        "loss_cone_half_angle_deg" => rad2deg(loss_cone_half_angle),
        "mean_ion_mass_number" => Float64(mean_ion_mass_number),
        "ion_temperature_ev" => temperature_ev,
        "ion_density_m3" => density_m3,
        "coulomb_log_bounds" => [lower_log, upper_log],
        "ion_ion_collision_time_bounds_s" => [collision_time_short, collision_time_long],
        "optimistic_collision_limited_confinement_upper_s" => collision_limited_upper,
        "required_energy_confinement_s" => required_tau,
        "upper_to_required_ratio" => margin_ratio,
        "ambipolar_potential_credit" => 0.0,
        "electrostatic_plug_credit" => 0.0,
        "kinetic_distribution_credit" => 0.0)
    applicability["status"] = "applicable"
    if collision_limited_upper < required_tau
        evidence["status"] = "fail"
        return _v72_result(realization, screen, :complete, :fail,
            "optimistic_open_field_collision_bound_below_required_tau_e",
            applicability, evidence, String[])
    end
    evidence["status"] = "unknown"
    return _v72_result(realization, screen, :incomplete, :unknown,
        "open_field_collision_proxy_not_sufficient_for_promotion",
        applicability, evidence,
        ["candidate_bound_collisional_kinetic_transport",
            "ambipolar_potential_solution", "microstability_evidence"])
end

function physical_transport_gate_to_dict_v72(item::PhysicalTransportGateV72)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "topology_hash" => item.topology_hash,
        "realization_hash" => item.realization_hash,
        "screen_evidence_hash" => item.screen_evidence_hash,
        "completeness" => String(item.completeness),
        "conclusion" => String(item.conclusion),
        "classification_code" => item.classification_code,
        "applicability" => item.applicability,
        "evidence" => item.evidence,
        "missing_requirements" => item.missing_requirements,
        "claim_boundary" => item.claim_boundary,
        "evidence_hash" => item.evidence_hash)
end

function evaluate_physical_frontier_candidate_v72(seed::Integer;
        particle_count::Integer = 256, step_count::Integer = 2000,
        required_transit_fraction::Real = 1.0)
    topology = generate_graph_native_topology_v69(seed)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    compilation.status == :pass || return Dict{String,Any}(
        "seed" => Int(seed), "status" => "not_admitted",
        "classification_code" => compilation.classification_code)
    binding = generate_physical_parameter_binding_v71(topology, seed)
    realization = compile_physical_device_realization_v71(topology, compilation;
        parameter_binding = binding)
    screen = screen_physical_device_v71(realization, binding;
        particle_count = particle_count, step_count = step_count,
        required_transit_fraction = required_transit_fraction)
    transport = evaluate_physical_transport_gate_v72(realization, screen, binding)
    return Dict{String,Any}(
        "seed" => Int(seed), "status" => "evaluated",
        "topology" => _s70_topology_to_dict(topology),
        "parameter_binding" => binding,
        "realization" => physical_device_realization_to_dict_v71(realization),
        "screen" => physical_device_screen_to_dict_v71(screen),
        "transport" => physical_transport_gate_to_dict_v72(transport))
end

function _v72_frontier_rank(candidate)
    candidate["status"] == "evaluated" || return (3, 3, 0, 0.0, 0.0, Int(candidate["seed"]))
    screen = candidate["screen"]; transport = candidate["transport"]
    lower_gate_rank = screen["conclusion"] == "screen_pass" ? 0 :
        (screen["conclusion"] == "screen_unknown" ? 1 : 2)
    transport_rank = transport["conclusion"] == "pass" ? 0 :
        (transport["conclusion"] in ("unknown", "unsupported") ? 1 : 2)
    coverage = Float64(get(screen["particle_evidence"], "duration_coverage_fraction", 0.0))
    confidence = Float64(get(screen["particle_evidence"],
        "retained_fraction_wilson_lower_95", 0.0))
    return (lower_gate_rank, transport_rank, -Int(screen["passed_gate_count"]),
        -coverage, -confidence, Int(candidate["seed"]))
end

function run_physical_frontier_v72(candidate_specs;
        output_path::Union{Nothing,AbstractString} = nothing)
    results = Dict{String,Any}[]; exception_count = 0
    for raw in candidate_specs
        spec = _v71_plain(raw)
        try
            push!(results, evaluate_physical_frontier_candidate_v72(Int(spec["seed"]);
                particle_count = Int(get(spec, "particle_count", 256)),
                step_count = Int(get(spec, "step_count", 2000)),
                required_transit_fraction = Float64(get(spec,
                    "required_transit_fraction", 1.0))))
        catch error
            exception_count += 1
            push!(results, Dict{String,Any}(
                "seed" => Int(spec["seed"]), "status" => "exception",
                "exception_type" => String(nameof(typeof(error)))))
        end
    end
    sort!(results; by = _v72_frontier_rank)
    winner = isempty(results) || first(results)["status"] != "evaluated" ? nothing : first(results)
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "status" => exception_count == 0 && winner !== nothing ? "complete" : "incomplete",
        "candidate_count" => length(results),
        "uncaught_exception_count" => exception_count,
        "selection_method" =>
            "lower_gate_then_transport_disposition_then_gate_depth_and_orbit_evidence_v1",
        "winner" => winner, "candidate_results" => results,
        "device_family_routing_used" => false,
        "claim_boundary" => PHYSICAL_TRANSPORT_V72_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
    return artifact
end
