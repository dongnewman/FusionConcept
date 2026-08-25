function _mirror_field_magnitude_v1(field, point)
    value = field(point)
    return sqrt(sum(component^2 for component in value))
end

"""
Evaluate candidate-field minimum-B structure and an engineering necessary
condition for a dual-route mirror C1 record.

An on-axis throat field above the candidate's declared peak-field screen is a
hard failure because conductor peak field cannot be lower than an already
excessive required plasma-axis field. Passing this check is not finite-coil
engineering evidence. A local saddle instead of minimum-B leaves stability
unknown because FLR, line tying and sheared-flow mechanisms are not solved.
"""
function evaluate_mirror_stability_engineering_screen_v1(
        record::AbstractDict)
    String(record["route"]) == "axisymmetric_mirror_field" ||
        throw(ArgumentError("axisymmetric mirror C1 record required"))
    record["candidate_c1_evidence_authorized"] === true ||
        throw(ArgumentError("mirror route C1 evidence is required"))
    parameters = record["parameters"]
    backend = record["backend_result"]
    radius = Float64(parameters["coil_radius_m"])
    plasma_radius = Float64(parameters["plasma_radius_m"])
    half_separation = Float64(parameters["derived_half_separation_m"])
    current = Float64(backend["current_per_loop_a"])
    declared_peak = Float64(parameters["declared_peak_field_screen_t"])
    field = _mirror_filament_field_v1(radius, 0.0, half_separation,
        current, 1024)
    step = min(radius, half_separation) / 240.0
    center = _mirror_field_magnitude_v1(field, (0.0, 0.0, 0.0))
    radial_plus = _mirror_field_magnitude_v1(field, (step, 0.0, 0.0))
    radial_minus = _mirror_field_magnitude_v1(field, (-step, 0.0, 0.0))
    axial_plus = _mirror_field_magnitude_v1(field, (0.0, 0.0, step))
    axial_minus = _mirror_field_magnitude_v1(field, (0.0, 0.0, -step))
    radial_curvature = (radial_plus - 2.0 * center + radial_minus) / step^2
    axial_curvature = (axial_plus - 2.0 * center + axial_minus) / step^2
    local_minimum_b = radial_curvature > 0.0 && axial_curvature > 0.0
    local_saddle = radial_curvature * axial_curvature < 0.0
    throat = center * Float64(backend["mirror_ratio"])
    peak_margin = declared_peak - throat
    peak_screen_pass = peak_margin >= 0.0
    hard_engineering_falsified = !peak_screen_pass
    magnetic_pressure = throat^2 / (2.0 * _MIRROR_FILAMENT_MU0_V1)
    current_density_sensitivities = Dict{String,Any}[]
    for engineering_j in (5.0e7, 1.0e8, 2.0e8)
        push!(current_density_sensitivities, Dict{String,Any}(
            "assumed_engineering_current_density_a_per_m2" => engineering_j,
            "minimum_winding_pack_area_m2" => abs(current) / engineering_j,
            "evidence_status" => "conditional_sensitivity_only"))
    end
    status = hard_engineering_falsified ? "fail" : "unknown"
    physical = Dict{String,Any}(
        "source_c0_candidate_hash" => record["c0_candidate_hash"],
        "source_physical_result_hash" => record["physical_result_hash"],
        "center_field_t" => center,
        "on_axis_throat_field_t" => throat,
        "declared_peak_field_screen_t" => declared_peak,
        "peak_field_margin_t" => peak_margin,
        "on_axis_peak_screen_pass" => peak_screen_pass,
        "magnetic_pressure_at_axis_throat_pa" => magnetic_pressure,
        "field_strength_radial_curvature_t_per_m2" => radial_curvature,
        "field_strength_axial_curvature_t_per_m2" => axial_curvature,
        "local_minimum_b" => local_minimum_b,
        "local_field_strength_saddle" => local_saddle,
        "radial_clearance_m" => radius - plasma_radius,
        "equivalent_filament_ampere_turns" => current,
        "current_density_sensitivities" => current_density_sensitivities,
        "hard_engineering_falsified" => hard_engineering_falsified,
        "status" => status)
    return merge(physical, Dict{String,Any}(
        "schema_version" => "1.0.0",
        "evaluator_version" => "mirror_stability_engineering_screen_v1",
        "physics_hash" => record["physics_hash"],
        "candidate_c1_evidence_authorized" => true,
        "minimum_b_evidence_authorized" => true,
        "minimum_b_stability_credit" => local_minimum_b,
        "flr_stability_evidence_authorized" => false,
        "flow_shear_stability_evidence_authorized" => false,
        "kinetic_microstability_evidence_authorized" => false,
        "finite_coil_engineering_evidence_authorized" => false,
        "stability_status" => "unknown",
        "c2_evidence_authorized" => false,
        "promotion_authorized" => false,
        "physical_result_hash" => canonical_hash(physical),
        "claim_ceiling" => hard_engineering_falsified ?
            "C1_engineering_necessary_condition_hard_falsification" :
            "C1_minimum_B_diagnostic_and_peak_field_necessary_condition",
        "claim_boundary" => "The candidate field supplies a local minimum-B diagnostic and an on-axis peak-field necessary condition. Passing does not validate a finite winding; the local saddle gives no minimum-B stability credit, while FLR, m=1, DCLC/AIC, flow shear, kinetic end loss, conductor critical surface, forces, stress, stored energy and C2 remain unknown."))
end
