const V100_PROTOCOL_ID = "fusionconceptai-v100-candidate-bound-design-refinement-20260829"

const DESIGN_REFINEMENT_V100_CLAIM_BOUNDARY =
    "v100 uses a deterministic low-discrepancy sequence only to propose candidate-bound " *
    "operating and finite radial-build inputs. All metric and gate credit comes from the " *
    "physics solve and explicit engineering prefilter. A prefilter pass is not FreeGS, " *
    "DESC, complete engineering, transport, validation, or whole-device credibility."

const V100_ENGINEERING_LIMITS = Dict{String,Float64}(
    "minimum_shield_thickness_m" => 1.0,
    "minimum_maintenance_gap_m" => 0.6,
    "minimum_central_bore_m" => 0.75,
    "maximum_pf_current_density_a_m2" => 500.0e6,
    "maximum_additive_peak_field_t" => 16.0,
    "maximum_membrane_support_stress_pa" => 650.0e6,
)

function engineering_prefilter_v100(point_raw, physics_raw, layout_raw)
    point = Dict{String,Any}(_v93_plain(point_raw))
    physics = Dict{String,Any}(_v93_plain(physics_raw))
    layout = Dict{String,Any}(_v93_plain(layout_raw))
    major = Float64(point["major_radius_m"])
    field = Float64(point["magnetic_field_t"])
    pack = Float64(layout["winding_pack_thickness_m"])
    support = Float64(layout["support_thickness_m"])
    shield = Float64(layout["shield_thickness_m"])
    maintenance = Float64(layout["maintenance_gap_m"])
    wall_minor = Float64(point["wall_minor_radius_m"])
    coil_minor = Float64(point["coil_minor_radius_m"])
    inner_center = major - (wall_minor + maintenance + 0.5pack)
    central_bore = inner_center - 0.5pack
    plasma_current = Float64(physics["confinement_model"]["plasma_current_ma"]) * 1e6
    maximum_pf_current = 0.75plasma_current
    current_density = maximum_pf_current / pack^2
    local_toroidal_field = field * major / max(inner_center, 1e-9)
    pf_self_field = 4e-7 * maximum_pf_current / pack
    additive_peak_field = local_toroidal_field + pf_self_field
    magnetic_pressure = additive_peak_field^2 / (2 * 4pi * 1e-7)
    membrane_stress = magnetic_pressure * inner_center / support
    gates = Dict{String,Bool}(
        "shield_thickness" => shield >=
            V100_ENGINEERING_LIMITS["minimum_shield_thickness_m"],
        "maintenance_gap" => maintenance >=
            V100_ENGINEERING_LIMITS["minimum_maintenance_gap_m"],
        "finite_radial_build" => coil_minor > wall_minor + maintenance,
        "central_bore" => central_bore >=
            V100_ENGINEERING_LIMITS["minimum_central_bore_m"],
        "pf_current_density" => current_density <=
            V100_ENGINEERING_LIMITS["maximum_pf_current_density_a_m2"],
        "additive_peak_field" => additive_peak_field <=
            V100_ENGINEERING_LIMITS["maximum_additive_peak_field_t"],
        "membrane_support_stress" => membrane_stress <=
            V100_ENGINEERING_LIMITS["maximum_membrane_support_stress_pa"],
    )
    body = Dict{String,Any}(
        "status" => all(values(gates)) ? "pass" : "fail",
        "model" => "explicit_shared_radial_build_pf_proxy_v100",
        "metrics" => Dict(
            "inner_pf_center_major_radius_m" => inner_center,
            "central_bore_m" => central_bore,
            "maximum_pf_current_a_turn" => maximum_pf_current,
            "pf_current_density_a_m2" => current_density,
            "local_toroidal_field_t" => local_toroidal_field,
            "pf_self_field_t" => pf_self_field,
            "additive_peak_field_t" => additive_peak_field,
            "membrane_support_stress_pa" => membrane_stress,
        ),
        "gates" => Dict(key => value ? "pass" : "fail" for (key, value) in gates),
        "failed_gates" => sort!([key for (key, value) in gates if !value]),
        "evidence_ceiling" => "candidate_bound_reduced_static_engineering_prefilter",
        "claim_boundary" => DESIGN_REFINEMENT_V100_CLAIM_BOUNDARY,
    )
    body["result_hash"] = canonical_hash(body)
    body
end

function _v100_design_point(sequence_index::Integer)
    major = 9.0 + 6.0_v98_halton(sequence_index, 2)
    aspect = 3.5 + 2.5_v98_halton(sequence_index, 3)
    minor = major / aspect
    shield = 1.0 + 0.5_v98_halton(sequence_index, 29)
    maintenance = 0.6 + 0.4_v98_halton(sequence_index, 31)
    pack = 0.8 + 1.2_v98_halton(sequence_index, 37)
    support = 1.0 + 2.0_v98_halton(sequence_index, 41)
    wall_minor = minor + shield
    coil_minor = wall_minor + maintenance + pack
    point = Dict{String,Any}(
        "major_radius_m" => major,
        "minor_radius_m" => minor,
        "elongation" => 1.4 + 0.7_v98_halton(sequence_index, 5),
        "triangularity" => -0.30 + 0.60_v98_halton(sequence_index, 19),
        "field_periods" => 1,
        "magnetic_field_t" => 4.0 + 4.0_v98_halton(sequence_index, 13),
        "density_m3" => 10.0^(19.60 + 0.60_v98_halton(sequence_index, 7)),
        "temperature_kev" => 8.0 + 14.0_v98_halton(sequence_index, 11),
        "wall_minor_radius_m" => wall_minor,
        "coil_minor_radius_m" => coil_minor,
        "open_branch_length_m" => 2major * (1 + 2_v98_halton(sequence_index, 23)),
        "fuel" => "D-T",
        "input_origin" => "candidate_bound_low_discrepancy_operating_and_radial_build_v100",
        "design_sequence" => "halton_physical_input_proposal_v100",
        "basis_direct_metric_credit" => false,
    )
    layout = Dict{String,Any}(
        "shield_thickness_m" => shield,
        "maintenance_gap_m" => maintenance,
        "winding_pack_thickness_m" => pack,
        "support_thickness_m" => support,
        "pf_current_fraction_upper_bound" => 0.75,
        "layout_model" => "shared_radial_build_v100",
    )
    point, layout
end

function refine_candidate_operating_points_v100(parent_raw;
        variant_count::Integer = 128, retain_count::Integer = 2)
    variant_count > 0 || throw(ArgumentError("variant_count must be positive"))
    retain_count > 0 || throw(ArgumentError("retain_count must be positive"))
    parent = Dict{String,Any}(_v93_plain(parent_raw))
    capability = Dict{String,Any}(parent["capability_profile"])
    String(capability["closed_core_route"]) == "axisymmetric_closed" ||
        throw(ArgumentError("v100 refinement requires an axisymmetric closed-core route"))
    parent_index = Int(parent["request_index"])
    accepted = Dict{String,Any}[]
    failure_histogram = Dict{String,Int}()
    for variant in 1:variant_count
        sequence_index = parent_index * variant_count + variant
        point, layout = _v100_design_point(sequence_index)
        physics = solve_candidate_physics_v98(point, capability)
        if physics["status"] != "pass"
            for gate in String.(physics["failed_gates"])
                failure_histogram["physics:" * gate] =
                    get(failure_histogram, "physics:" * gate, 0) + 1
            end
            continue
        end
        engineering = engineering_prefilter_v100(point, physics, layout)
        if engineering["status"] != "pass"
            for gate in String.(engineering["failed_gates"])
                failure_histogram["engineering:" * gate] =
                    get(failure_histogram, "engineering:" * gate, 0) + 1
            end
            continue
        end
        metrics = engineering["metrics"]
        peak_margin = 1 - Float64(metrics["additive_peak_field_t"]) /
            V100_ENGINEERING_LIMITS["maximum_additive_peak_field_t"]
        stress_margin = 1 - Float64(metrics["membrane_support_stress_pa"]) /
            V100_ENGINEERING_LIMITS["maximum_membrane_support_stress_pa"]
        net_power = Float64(physics["metrics"]["net_electric_power_w"])
        score = min(peak_margin, stress_margin) + 0.05log1p(max(net_power, 0.0) / 1e6)
        refinement_index = parent_index * 1_000_000 + variant
        body = Dict{String,Any}(
            "schema_version" => "1.0.0",
            "protocol_id" => V100_PROTOCOL_ID,
            "request_index" => refinement_index,
            "parent_request_index" => parent_index,
            "parent_candidate_result_hash" => parent["result_hash"],
            "graph_hash" => parent["graph_hash"],
            "capability_profile" => capability,
            "operating_point" => point,
            "magnet_layout" => layout,
            "physics_solve" => physics,
            "engineering_prefilter" => engineering,
            "candidate_state" => "computational_candidate",
            "selection_score" => score,
            "identity_fields_used_for_routing" => false,
            "basis_direct_metric_credit" => false,
            "unsupported_candidate_classification_used" => false,
            "claim_boundary" => DESIGN_REFINEMENT_V100_CLAIM_BOUNDARY,
        )
        body["solver_input_hash"] = canonical_hash(Dict(
            "parent_candidate_result_hash" => parent["result_hash"],
            "capability_hash" => capability["capability_hash"],
            "operating_point" => point, "magnet_layout" => layout))
        body["result_hash"] = canonical_hash(body)
        push!(accepted, body)
    end
    sort!(accepted; by = item -> (-Float64(item["selection_score"]),
        String(item["result_hash"])))
    total_pass_count = length(accepted)
    length(accepted) > retain_count && resize!(accepted, retain_count)
    Dict{String,Any}(
        "parent_request_index" => parent_index,
        "variant_count" => Int(variant_count),
        "prefilter_pass_count" => total_pass_count,
        "retained_count" => length(accepted),
        "retained" => accepted,
        "failure_histogram" => Dict(sort(collect(failure_histogram))),
        "identity_fields_used_for_routing" => false,
        "unsupported_candidate_count" => 0,
        "claim_boundary" => DESIGN_REFINEMENT_V100_CLAIM_BOUNDARY,
    )
end
