const SURFACE_CURRENT_POTENTIAL_INVERSE_V86_CLAIM_BOUNDARY =
    "v86 current-potential inversion uses candidate-bound finite-filament fields and periodic-axis-aligned short-horizon field-line acquisition to initialize later immutable requests. It grants no feasibility, Poincare, equilibrium, stability, minimality, engineering, or build-ready credit."

function _v86_inverse_serialized_plain(value)
    return _stage3_plain_v1(JSON3.read(JSON3.write(value), Dict{String,Any}))
end

_v86_inverse_serialized_hash(value) = canonical_hash(
    _v86_inverse_serialized_plain(value))

struct CurrentPotentialInverseRequestV1
    schema_version::String
    source_request_hash::String
    structure_hash::String
    source_design_hash::String
    source_basis_override_hash::String
    winding_model::String
    active_coefficient_indices::Vector{Int}
    target_rotational_transform::Float64
    theta_count::Int
    phi_count::Int
    acquisition_toroidal_turns::Int
    acquisition_steps_per_turn::Int
    axis_locator_refinement_levels::Int
    axis_locator_maximum_closure_residual::Float64
    maximum_iterations::Int
    finite_difference_step::Float64
    trust_radius::Float64
    tikhonov_regularization::Float64
    request_hash::String
end

function _v86_inverse_request_body(item::CurrentPotentialInverseRequestV1)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "source_request_hash" => item.source_request_hash,
        "structure_hash" => item.structure_hash,
        "source_design_hash" => item.source_design_hash,
        "source_basis_override_hash" => item.source_basis_override_hash,
        "winding_model" => item.winding_model,
        "active_coefficient_indices" => item.active_coefficient_indices,
        "target_rotational_transform" => item.target_rotational_transform,
        "theta_count" => item.theta_count,
        "phi_count" => item.phi_count,
        "acquisition_toroidal_turns" => item.acquisition_toroidal_turns,
        "acquisition_steps_per_turn" => item.acquisition_steps_per_turn,
        "axis_locator_refinement_levels" =>
            item.axis_locator_refinement_levels,
        "axis_locator_maximum_closure_residual" =>
            item.axis_locator_maximum_closure_residual,
        "maximum_iterations" => item.maximum_iterations,
        "finite_difference_step" => item.finite_difference_step,
        "trust_radius" => item.trust_radius,
        "tikhonov_regularization" => item.tikhonov_regularization,
        "inverse_solver_id" =>
            "candidate_bound_regularized_current_potential_gauss_newton_v1",
        "acquisition_model_id" =>
            "candidate_biot_savart_periodic_axis_fieldline_acquisition_v2",
        "next_request_sampling_only" => true,
        "retroactive_feasibility_credit" => false)
end

function current_potential_inverse_request_to_dict_v1(
        item::CurrentPotentialInverseRequestV1)
    body = _v86_inverse_request_body(item)
    body["request_hash"] = item.request_hash
    return body
end

function compile_current_potential_inverse_request_v1(
        source_request::CandidateSolveRequestV86,
        source_design::CandidateJointDesignV1, source_basis_override;
        active_coefficient_indices = nothing,
        target_rotational_transform::Real = 0.02,
        theta_count::Integer = 4, phi_count::Integer = 6,
        acquisition_toroidal_turns::Integer = 4,
        acquisition_steps_per_turn::Integer = 60,
        axis_locator_refinement_levels::Integer = 4,
        axis_locator_maximum_closure_residual::Real = 0.04,
        maximum_iterations::Integer = 1,
        finite_difference_step::Real = 0.015,
        trust_radius::Real = 0.10,
        tikhonov_regularization::Real = 0.05)
    override = _stage3_plain_v1(source_basis_override)
    model = String(get(override, "winding_model", ""))
    model == "winding_surface_current_potential_level_set_filaments_v7" ||
        throw(ArgumentError(
            "v86 inverse request requires the declared v7 contour grammar"))
    source_request.structure_hash == source_design.structure_hash || throw(
        ArgumentError("v86 inverse source structure mismatch"))
    source_request.initial_design.grammar_hash == source_design.grammar_hash ||
        throw(ArgumentError("v86 inverse source grammar mismatch"))
    coefficients = Float64.(override["current_potential_coefficients"])
    indices = active_coefficient_indices === nothing ?
        collect(eachindex(coefficients)) :
        sort!(unique(Int.(collect(active_coefficient_indices))))
    !isempty(indices) || throw(ArgumentError(
        "v86 inverse request requires active coefficients"))
    all(index -> 1 <= index <= length(coefficients), indices) || throw(
        ArgumentError("v86 inverse coefficient index is outside the basis"))
    target_rotational_transform > 0 || throw(ArgumentError(
        "v86 inverse target transform must be positive"))
    theta_count >= 2 && phi_count >= 2 || throw(ArgumentError(
        "v86 inverse boundary grid must be at least 2x2"))
    acquisition_toroidal_turns > 0 && acquisition_steps_per_turn > 0 || throw(
        ArgumentError("v86 inverse acquisition budget must be positive"))
    axis_locator_refinement_levels > 0 || throw(ArgumentError(
        "v86 inverse axis locator refinement count must be positive"))
    axis_locator_maximum_closure_residual > 0 || throw(ArgumentError(
        "v86 inverse axis locator closure threshold must be positive"))
    maximum_iterations >= 0 || throw(ArgumentError(
        "v86 inverse iteration count cannot be negative"))
    finite_difference_step > 0 && trust_radius > 0 || throw(ArgumentError(
        "v86 inverse step sizes must be positive"))
    tikhonov_regularization > 0 || throw(ArgumentError(
        "v86 inverse regularization must be positive"))
    provisional = CurrentPotentialInverseRequestV1("1.0.0",
        source_request.request_hash, source_request.structure_hash,
        source_design.design_hash, canonical_hash(override), model, indices,
        Float64(target_rotational_transform), Int(theta_count), Int(phi_count),
        Int(acquisition_toroidal_turns), Int(acquisition_steps_per_turn),
        Int(axis_locator_refinement_levels),
        Float64(axis_locator_maximum_closure_residual),
        Int(maximum_iterations), Float64(finite_difference_step),
        Float64(trust_radius), Float64(tikhonov_regularization), "")
    hash = _v86_inverse_serialized_hash(
        _v86_inverse_request_body(provisional))
    return CurrentPotentialInverseRequestV1(provisional.schema_version,
        provisional.source_request_hash, provisional.structure_hash,
        provisional.source_design_hash,
        provisional.source_basis_override_hash, provisional.winding_model,
        provisional.active_coefficient_indices,
        provisional.target_rotational_transform, provisional.theta_count,
        provisional.phi_count, provisional.acquisition_toroidal_turns,
        provisional.acquisition_steps_per_turn,
        provisional.axis_locator_refinement_levels,
        provisional.axis_locator_maximum_closure_residual,
        provisional.maximum_iterations, provisional.finite_difference_step,
        provisional.trust_radius, provisional.tikhonov_regularization, hash)
end

function _v86_inverse_signed_boundary_residuals(realization, binding;
        theta_count::Integer, phi_count::Integer)
    cache = compile_finite_filament_field_cache_v71(realization)
    boundary = binding["v85_boundary"]
    String(boundary["geometry_class"]) == "toroidal_volume_v1" || throw(
        ArgumentError("v86 current-potential inverse requires toroidal geometry"))
    residuals = Float64[]; magnitudes = Float64[]
    for theta_index in 0:Int(theta_count)-1,
            phi_index in 0:Int(phi_count)-1
        theta = 2pi * theta_index / Int(theta_count)
        phi = 2pi * phi_index / Int(phi_count)
        point, normal = _v85_boundary_point_and_normal(boundary, theta, phi)
        field = finite_filament_field_v71(cache, point)
        magnitude = norm(field)
        push!(magnitudes, magnitude)
        push!(residuals, dot(field, normal) / max(magnitude, 1.0e-12))
    end
    return (residuals = residuals,
        rms = sqrt(sum(abs2, residuals) / length(residuals)),
        maximum_absolute = maximum(abs.(residuals)),
        minimum_field_t = minimum(magnitudes),
        field_cache_hash = cache.cache_hash)
end

function _v86_inverse_design_and_override(grammar, template_design,
        template_override, coefficients, inverse_request_hash)
    low_count = length(template_design.current_potential_coefficients)
    length(coefficients) >= low_count || throw(ArgumentError(
        "v86 inverse coefficient vector truncates the low-order basis"))
    design = compile_candidate_joint_design_v1(grammar;
        route = template_design.route,
        coil_fourier_coefficients = template_design.coil_fourier_coefficients,
        coil_bspline_control_points =
            template_design.coil_bspline_control_points,
        current_potential_coefficients = coefficients[1:low_count],
        plasma_boundary_coefficients =
            template_design.plasma_boundary_coefficients,
        actuator_timing_coefficients =
            template_design.actuator_timing_coefficients,
        controller_modal_coefficients =
            template_design.controller_modal_coefficients,
        field_current_a = template_design.field_current_a,
        density_scale = template_design.density_scale,
        temperature_scale = template_design.temperature_scale)
    override = deepcopy(template_override)
    override["current_potential_coefficients"] = Float64.(coefficients)
    override["inverse_request_hash"] = String(inverse_request_hash)
    override["inverse_solver_id"] =
        "candidate_bound_regularized_current_potential_gauss_newton_v1"
    override["feedback_role"] = "next_request_sampling_only"
    override["retroactive_feasibility_credit"] = false
    return design, override
end

function _v86_inverse_evaluation(topology, compilation, grammar,
        template_design, template_override, coefficients, request;
        base_coil_count)
    design, override = _v86_inverse_design_and_override(grammar,
        template_design, template_override, coefficients,
        request.request_hash)
    compiled = compile_joint_physical_realization_v85(topology, compilation,
        design; basis_override = override, base_coil_count = base_coil_count)
    compiled.realization.completeness == :complete || throw(ArgumentError(
        "v86 inverse produced an incomplete finite-filament realization"))
    signed = _v86_inverse_signed_boundary_residuals(compiled.realization,
        compiled.binding; theta_count = request.theta_count,
        phi_count = request.phi_count)
    field = _v85_fast_field_summary(compiled.realization)
    acquisition = _v85_axis_aware_short_fieldline_acquisition_v2(
        compiled.realization;
        target_toroidal_turns = request.acquisition_toroidal_turns,
        steps_per_turn = request.acquisition_steps_per_turn,
        candidate_boundary = compiled.binding["v85_boundary"],
        axis_locator_refinement_levels =
            request.axis_locator_refinement_levels,
        axis_locator_maximum_closure_residual =
            request.axis_locator_maximum_closure_residual)
    field_component = first(_v71_field_components(compiled.realization))
    spacing = Float64(get(field_component,
        "minimum_same_theta_contour_spacing_m", 0.0))
    conductor_radius = Float64(field_component["conductor"]["radius_m"])
    required_spacing = 4.0 * conductor_radius
    spacing_violation = max(0.0, required_spacing - spacing) /
        max(required_spacing, 1.0e-12)
    minimum_field = Float64(field["minimum_field_t"])
    ripple = Float64(field["relative_field_ripple"])
    escape = Float64(acquisition["trace_escape_fraction"])
    completion = Float64(acquisition[
        "minimum_trace_completion_fraction"])
    transform = Float64(acquisition[
        "minimum_absolute_rotational_transform"])
    ordering = Float64(acquisition["surface_ordering_fraction"])
    axis_violation = Float64(acquisition["axis_location_violation"])
    target = request.target_rotational_transform
    hard_violation = axis_violation +
        max(0.0, (0.10 - minimum_field) / 0.10) +
        max(0.0, (ripple - 3.0) / 3.0) +
        max(0.0, (signed.rms - 0.18) / 0.18) + spacing_violation
    transform_deficit = max(0.0, target - transform) / target
    residual = vcat(2.0 .* signed.residuals,
        [2.0 * axis_violation, 1.5 * escape,
            1.0 * (1.0 - completion),
            1.4 * transform_deficit, 0.5 * (1.0 - ordering),
            0.5 * spacing_violation])
    rank = Float64[hard_violation, escape, 1.0 - completion,
        transform_deficit, 1.0 - ordering, signed.rms,
        norm(Float64.(coefficients)) / sqrt(length(coefficients))]
    return Dict{String,Any}(
        "design" => design, "basis_override" => override,
        "compiled" => compiled, "residual" => residual, "rank" => rank,
        "hard_constraint_violation" => hard_violation,
        "signed_boundary_normal_rms" => signed.rms,
        "signed_boundary_normal_maximum_absolute" => signed.maximum_absolute,
        "minimum_field_t" => minimum_field,
        "relative_field_ripple" => ripple,
        "minimum_contour_spacing_m" => spacing,
        "required_contour_spacing_m" => required_spacing,
        "spacing_violation" => spacing_violation,
        "axis_location_violation" => axis_violation,
        "acquisition" => acquisition)
end

_v86_inverse_rank_lt(left, right) = Tuple(Float64.(left["rank"])) <
    Tuple(Float64.(right["rank"]))

function run_current_potential_inverse_v1(
        request::CurrentPotentialInverseRequestV1, topology, compilation,
        grammar::JointOptimizationGrammarV1,
        source_design::CandidateJointDesignV1, source_basis_override;
        base_coil_count::Integer)
    request.structure_hash == source_design.structure_hash || throw(
        ArgumentError("v86 inverse run structure mismatch"))
    request.source_design_hash == source_design.design_hash || throw(
        ArgumentError("v86 inverse run design hash mismatch"))
    template_override = _stage3_plain_v1(source_basis_override)
    request.source_basis_override_hash == canonical_hash(template_override) ||
        throw(ArgumentError("v86 inverse run basis override hash mismatch"))
    coefficients = Float64.(template_override[
        "current_potential_coefficients"])
    source_coefficients = copy(coefficients)
    best = _v86_inverse_evaluation(topology, compilation, grammar,
        source_design, template_override, coefficients, request;
        base_coil_count = base_coil_count)
    evaluations = 1
    trace = Dict{String,Any}[Dict{String,Any}(
        "iteration" => 0, "event" => "initial",
        "rank" => best["rank"],
        "coefficient_hash" => canonical_hash(coefficients))]
    regularization = request.tikhonov_regularization
    trust_radius = request.trust_radius
    for iteration in 1:request.maximum_iterations
        base_residual = Float64.(best["residual"])
        active = request.active_coefficient_indices
        jacobian = zeros(length(base_residual), length(active))
        for (column, coefficient_index) in enumerate(active)
            trial_coefficients = copy(coefficients)
            trial_coefficients[coefficient_index] = clamp(
                trial_coefficients[coefficient_index] +
                    request.finite_difference_step, -0.35, 0.35)
            actual_step = trial_coefficients[coefficient_index] -
                coefficients[coefficient_index]
            abs(actual_step) > eps() || continue
            trial = _v86_inverse_evaluation(topology, compilation, grammar,
                source_design, template_override, trial_coefficients, request;
                base_coil_count = base_coil_count)
            evaluations += 1
            jacobian[:, column] .= (Float64.(trial["residual"]) .-
                base_residual) ./ actual_step
        end
        normal_matrix = transpose(jacobian) * jacobian +
            regularization * I
        step = -(normal_matrix \ (transpose(jacobian) * base_residual))
        step_norm = norm(step)
        step_norm > trust_radius && (step .*= trust_radius / step_norm)
        candidates = Tuple{Vector{Float64},Dict{String,Any},Float64}[]
        for scale in (1.0, 0.5, 0.25, -0.25)
            trial_coefficients = copy(coefficients)
            for (column, coefficient_index) in enumerate(active)
                trial_coefficients[coefficient_index] = clamp(
                    coefficients[coefficient_index] + scale * step[column],
                    -0.35, 0.35)
            end
            trial_coefficients == coefficients && continue
            trial = _v86_inverse_evaluation(topology, compilation, grammar,
                source_design, template_override, trial_coefficients, request;
                base_coil_count = base_coil_count)
            evaluations += 1
            push!(candidates, (trial_coefficients, trial, scale))
        end
        improved = false
        for (trial_coefficients, trial, scale) in candidates
            _v86_inverse_rank_lt(trial, best) || continue
            coefficients = trial_coefficients; best = trial; improved = true
            push!(trace, Dict{String,Any}(
                "iteration" => iteration, "event" => "accepted",
                "line_scale" => scale, "rank" => best["rank"],
                "coefficient_hash" => canonical_hash(coefficients)))
            break
        end
        if !improved
            regularization *= 4.0; trust_radius *= 0.5
            push!(trace, Dict{String,Any}(
                "iteration" => iteration, "event" => "no_improvement",
                "rank" => best["rank"],
                "regularization" => regularization,
                "trust_radius" => trust_radius))
        end
    end
    optimized_design = best["design"]::CandidateJointDesignV1
    optimized_override = best["basis_override"]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "inverse_request" => current_potential_inverse_request_to_dict_v1(
            request),
        "source_request_hash" => request.source_request_hash,
        "source_design_hash" => request.source_design_hash,
        "source_basis_override_hash" => request.source_basis_override_hash,
        "optimized_design" => candidate_joint_design_to_dict_v1(
            optimized_design),
        "optimized_basis_override" => optimized_override,
        "optimized_basis_override_hash" => canonical_hash(optimized_override),
        "source_coefficient_hash" => canonical_hash(source_coefficients),
        "optimized_coefficient_hash" => canonical_hash(coefficients),
        "initial_rank" => first(trace)["rank"],
        "final_rank" => best["rank"],
        "evaluation_count" => evaluations,
        "trace" => trace,
        "final_acquisition" => Dict{String,Any}(
            key => best["acquisition"][key] for key in (
                "status", "model_id", "axis_location_violation",
                "candidate_boundary_frame_used",
                "axis_relative_start_points",
                "start_minor_radius_fractions",
                "trace_escape_fraction",
                "minimum_trace_completion_fraction",
                "minimum_absolute_rotational_transform",
                "minimum_sampled_wall_margin_fraction",
                "surface_ordering_fraction", "periodic_magnetic_axis",
                "completion_semantics", "escape_semantics")),
        "final_field_metrics" => Dict{String,Any}(
            "signed_boundary_normal_rms" =>
                best["signed_boundary_normal_rms"],
            "signed_boundary_normal_maximum_absolute" =>
                best["signed_boundary_normal_maximum_absolute"],
            "minimum_field_t" => best["minimum_field_t"],
            "relative_field_ripple" => best["relative_field_ripple"],
            "minimum_contour_spacing_m" =>
                best["minimum_contour_spacing_m"],
            "required_contour_spacing_m" =>
                best["required_contour_spacing_m"]),
        "inverse_solver_id" =>
            "candidate_bound_regularized_current_potential_gauss_newton_v1",
        "next_request_sampling_only" => true,
        "candidate_feasibility_credit" => false,
        "retroactive_feasibility_credit" => false,
        "claim_boundary" =>
            SURFACE_CURRENT_POTENTIAL_INVERSE_V86_CLAIM_BOUNDARY)
    body["result_hash"] = _v86_inverse_serialized_hash(body)
    return body
end

function compile_v86_inverse_initialized_campaign_v1(parent_campaign,
        inverse_results)
    raw_by_hash = Dict(String(raw["request_hash"]) => raw for raw in
        parent_campaign["requests"])
    requests = Dict{String,Any}[]
    for (request_index, result_value) in enumerate(sort!(
            _stage3_plain_v1.(collect(inverse_results)); by = result ->
                String(result["source_request_hash"])))
        result = result_value
        source_hash = String(result["source_request_hash"])
        haskey(raw_by_hash, source_hash) || throw(ArgumentError(
            "v86 inverse result source request is absent from parent campaign"))
        restored = _v86_restore_request(raw_by_hash[source_hash])
        String(result["inverse_request"]["source_request_hash"]) ==
            source_hash || throw(ArgumentError(
                "v86 inverse result provenance mismatch"))
        design = _v86_joint_design_from_dict(result["optimized_design"],
            restored.grammar)
        override = _stage3_plain_v1(result["optimized_basis_override"])
        canonical_hash(override) == String(result[
            "optimized_basis_override_hash"]) || throw(ArgumentError(
                "v86 inverse result basis override hash mismatch"))
        request = compile_candidate_solve_request_v86(request_index,
            restored.request.structure_seed, restored.topology,
            restored.compilation, restored.grammar,
            restored.request.physical_variant,
            restored.request.operating_variant,
            restored.request.control_variant, restored.request.route;
            basis_level = restored.request.basis_level,
            initial_design_override = design,
            serialized_basis_override = override)
        raw = candidate_solve_request_to_dict_v86(request)
        raw["parent_request_hash"] = source_hash
        raw["inverse_request_hash"] = result["inverse_request"][
            "request_hash"]
        raw["inverse_result_hash"] = result["result_hash"]
        raw["frontier_rank"] = result["final_rank"]
        raw["retroactive_feasibility_credit"] = false
        push!(requests, raw)
    end
    schedule = _v86_hierarchical_stage_schedule(requests)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "campaign_kind" => "current_potential_inverse_followup_v1",
        "parent_campaign_hash" => parent_campaign["campaign_hash"],
        "request_count" => length(requests),
        "request_hashes" => [raw["request_hash"] for raw in requests],
        "capability_cell_count" => length(unique(String(raw[
            "capability_signature"]["capability_cell_hash"]) for raw in
            requests)),
        "budget_stratum_count" => length(unique(String(raw[
            "capability_signature"]["budget_stratum_hash"]) for raw in
            requests)),
        "fair_schedule_request_indices" => schedule,
        "fairness_policy" =>
            "budget_stratum_then_capability_cell_round_robin_v2",
        "inverse_result_hashes" => sort!(String[result["result_hash"] for
            result in inverse_results]),
        "seed_streams_independent" => true,
        "isomorphism_dedup_before_variants" => true,
        "inverse_solver_results_only_initialize_next_requests" => true,
        "retroactive_feasibility_credit" => false)
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "specification" => body,
        "requests" => requests,
        "campaign_hash" => _v86_inverse_serialized_hash(body),
        "claim_boundary" =>
            SURFACE_CURRENT_POTENTIAL_INVERSE_V86_CLAIM_BOUNDARY)
end
