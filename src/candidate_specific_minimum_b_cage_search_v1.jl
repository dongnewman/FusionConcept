function _cmbc_axis_problem_v1(winding_record::AbstractDict,
        quadrupole_pack_width_m::Float64)
    selected = winding_record["selected_repair"]
    repair = selected["minimum_similarity_repair"]
    explicit = winding_record["explicit_input"]
    contract = default_common_comparison_contract()
    central_field_T = Float64(repair["target_central_field_T"])
    mirror_ratio = Float64(repair["target_mirror_ratio"])
    half_length_m = Float64(repair["pair_half_separation_m"])
    plasma_radius_m = Float64(repair["plasma_radius_m"])
    central_cage_radius_m = plasma_radius_m + contract.shield_thickness_m +
        contract.maintenance_gap_m + 0.5 * quadrupole_pack_width_m
    anchor_target = _mf_target_field_T(0.44 * half_length_m,
        central_field_T, mirror_ratio, half_length_m)
    anchor_plasma_radius_m = plasma_radius_m *
        sqrt(central_field_T / anchor_target)
    end_cage_radius_m = anchor_plasma_radius_m +
        contract.shield_thickness_m + contract.maintenance_gap_m +
        0.5 * quadrupole_pack_width_m
    axis = Dict{String,Any}(
        "positions_m" => [Float64(repair["pair_half_separation_m"])],
        "radii_m" => [Float64(repair["coil_centerline_radius_m"])],
        "currents_A" => [Float64(repair["ampere_turns_per_coil_A"])],
        "central_cage_radius_m" => central_cage_radius_m,
        "end_cage_radius_m" => end_cage_radius_m)
    return axis, Dict{String,Any}(
        "parent_repair_candidate_id" => winding_record["repair_candidate_id"],
        "parent_repair_problem_hash" =>
            repair["repair_problem_hash"],
        "axis_winding_pack_width_m" => repair["winding_pack_width_m"],
        "quadrupole_pack_width_m" => quadrupole_pack_width_m,
        "central_field_T" => central_field_T,
        "target_mirror_ratio" => mirror_ratio,
        "half_length_m" => half_length_m,
        "plasma_radius_m" => plasma_radius_m,
        "central_cage_radius_m" => central_cage_radius_m,
        "end_cage_radius_m" => end_cage_radius_m,
        "peak_conductor_field_limit_T" =>
            explicit["declared_peak_field_screen_T"],
        "engineering_current_density_limit_A_m2" =>
            contract.engineering_current_density_limit_A_mm2 * 1.0e6)
end

"""
Search an explicit three-cell quadrupolar cage around a finite-winding circular
mirror pair. The search consumes physical geometry only; family and route labels
do not participate. A negative result rejects only this bounded cage grammar.
"""
function search_candidate_specific_minimum_b_cage_v1(
        winding_record::AbstractDict;
        quadrupole_pack_widths_m = (0.45, 0.70, 1.00, 1.50, 2.00, 3.00),
        end_high_fractions = (0.73, 0.80, 0.88),
        coarse_segments::Integer = 128,
        refined_segments::Integer = 256,
        coarse_pack_grid::Integer = 7,
        refined_pack_grid::Integer = 9)
    winding_record[
        "candidate_specific_finite_winding_vacuum_component_authorized"] ===
        true || throw(ArgumentError(
            "a converged finite-winding parent component is required"))
    widths = Float64.(collect(quadrupole_pack_widths_m))
    highs = Float64.(collect(end_high_fractions))
    all(>(0.0), widths) || throw(ArgumentError("pack widths must be positive"))
    all(value -> 0.44 < value < 1.0, highs) ||
        throw(ArgumentError("end-high fractions must lie in (0.44, 1)"))
    selected = winding_record["selected_repair"]
    repair = selected["minimum_similarity_repair"]
    search_contract = Dict{String,Any}(
        "geometry_model" =>
            "three_divergence_free_quadrupolar_cage_cells_v1",
        "parent_repair_problem_hash" => repair["repair_problem_hash"],
        "quadrupole_pack_widths_m" => widths,
        "end_low_fraction" => 0.44,
        "end_high_fractions" => highs,
        "minimum_sampled_transverse_well_fraction" => 0.002,
        "current_grid_rule" =>
            "pack<=1m: -100:10:100 MA-turn; pack>1m: -200:20:200 MA-turn",
        "field_line_maximum_normalized_radius" => 0.95,
        "coarse_segments" => Int(coarse_segments),
        "refined_segments" => Int(refined_segments),
        "coarse_pack_grid" => Int(coarse_pack_grid),
        "refined_pack_grid" => Int(refined_pack_grid))
    search_problem_hash = canonical_hash(search_contract)
    pack_summaries = Dict{String,Any}[]
    line_survivors = Dict{String,Any}[]
    evaluated_count = 0
    well_pass_count = 0
    line_pass_count = 0
    coarse_peak_pass_count = 0
    for pack_width_m in widths
        axis, physical = _cmbc_axis_problem_v1(winding_record, pack_width_m)
        half_length_m = Float64(physical["half_length_m"])
        central_field_T = Float64(physical["central_field_T"])
        mirror_ratio = Float64(physical["target_mirror_ratio"])
        plasma_radius_m = Float64(physical["plasma_radius_m"])
        axis_segments = _mf_centerline_axis_segments(axis, Int(coarse_segments))
        central_basis, _, _ = _mf_cage_basis_segments(axis, half_length_m,
            Int(coarse_segments))
        current_max_A = pack_width_m <= 1.0 ? 100.0e6 : 200.0e6
        current_step_A = pack_width_m <= 1.0 ? 10.0e6 : 20.0e6
        current_grid_A = collect(-current_max_A:current_step_A:current_max_A)
        local_evaluated = local_well = local_line = local_peak = 0
        for end_high_fraction in highs
            _, left_basis, right_basis = _mf_cage_basis_segments(axis,
                half_length_m, Int(coarse_segments);
                end_low_fraction = 0.44,
                end_high_fraction = end_high_fraction)
            for central_current_A in current_grid_A,
                    end_current_A in current_grid_A
                local_evaluated += 1
                records = _mf_transverse_wells(axis_segments, central_basis,
                    left_basis, right_basis, central_current_A, end_current_A,
                    half_length_m, central_field_T, mirror_ratio,
                    plasma_radius_m)
                minimum_well = minimum(Float64(record[
                    "minimum_well_fraction"]) for record in records)
                minimum_well >= 0.002 || continue
                local_well += 1
                quadrupole = Dict{String,Any}(
                    "central_bar_current_A" => central_current_A,
                    "end_bar_current_A" => end_current_A,
                    "end_low_fraction" => 0.44,
                    "end_high_fraction" => end_high_fraction)
                field_lines = _mf_field_line_audit(axis, quadrupole,
                    half_length_m, central_field_T, mirror_ratio,
                    plasma_radius_m, Int(coarse_segments))
                field_lines["passed"] === true || continue
                local_line += 1
                peak = _mf_peak_winding_field(axis, quadrupole,
                    half_length_m, Float64(repair["winding_pack_width_m"]),
                    pack_width_m, Int(coarse_pack_grid), Int(coarse_segments))
                peak_passed = Float64(peak["peak_field_T"]) <= Float64(
                    physical["peak_conductor_field_limit_T"])
                local_peak += Int(peak_passed)
                current_density = max(abs(central_current_A),
                    abs(end_current_A)) / pack_width_m^2
                candidate_physical = Dict{String,Any}(
                    "parent_repair_problem_hash" =>
                        repair["repair_problem_hash"],
                    "quadrupole_pack_width_m" => pack_width_m,
                    "central_bar_current_A" => central_current_A,
                    "end_bar_current_A" => end_current_A,
                    "end_low_fraction" => 0.44,
                    "end_high_fraction" => end_high_fraction)
                push!(line_survivors, Dict{String,Any}(
                    "candidate_id" => "minimum_b_cage_" * first(
                        canonical_hash(candidate_physical), 16),
                    "candidate_physical_hash" =>
                        canonical_hash(candidate_physical),
                    "physical_input" => merge(physical, candidate_physical),
                    "minimum_sampled_transverse_well_fraction" => minimum_well,
                    "well_records" => records,
                    "field_line_audit" => field_lines,
                    "coarse_peak_winding_field" => peak,
                    "engineering_current_density_A_m2" => current_density,
                    "gates" => Dict{String,Bool}(
                        "sampled_transverse_minimum_b_well" => true,
                        "open_field_line_integrity" => true,
                        "engineering_current_density" => current_density <=
                            Float64(physical[
                                "engineering_current_density_limit_A_m2"]),
                        "coarse_peak_winding_field" => peak_passed)))
            end
        end
        evaluated_count += local_evaluated
        well_pass_count += local_well
        line_pass_count += local_line
        coarse_peak_pass_count += local_peak
        push!(pack_summaries, Dict{String,Any}(
            "quadrupole_pack_width_m" => pack_width_m,
            "evaluated_count" => local_evaluated,
            "sampled_well_pass_count" => local_well,
            "open_field_line_pass_count" => local_line,
            "coarse_peak_field_pass_count" => local_peak))
    end
    sort!(line_survivors; by = item -> (
        Float64(item["coarse_peak_winding_field"]["peak_field_T"]),
        abs(Float64(item["physical_input"]["central_bar_current_A"])) +
            2.0 * abs(Float64(item["physical_input"]["end_bar_current_A"])),
        String(item["candidate_id"])))
    best = isempty(line_survivors) ? nothing : first(line_survivors)
    if best !== nothing
        input = best["physical_input"]
        axis, _ = _cmbc_axis_problem_v1(winding_record,
            Float64(input["quadrupole_pack_width_m"]))
        quadrupole = Dict{String,Any}(
            "central_bar_current_A" => input["central_bar_current_A"],
            "end_bar_current_A" => input["end_bar_current_A"],
            "end_low_fraction" => input["end_low_fraction"],
            "end_high_fraction" => input["end_high_fraction"])
        refined_peak = _mf_peak_winding_field(axis, quadrupole,
            Float64(input["half_length_m"]),
            Float64(repair["winding_pack_width_m"]),
            Float64(input["quadrupole_pack_width_m"]),
            Int(refined_pack_grid), Int(refined_segments))
        peak_change = abs(Float64(refined_peak["peak_field_T"]) -
            Float64(best["coarse_peak_winding_field"]["peak_field_T"])) /
            max(Float64(refined_peak["peak_field_T"]), 1.0e-12)
        best["refined_peak_winding_field"] = refined_peak
        best["peak_field_relative_change"] = peak_change
        best["refined_peak_field_passed"] = Float64(
            refined_peak["peak_field_T"]) <= Float64(
                input["peak_conductor_field_limit_T"])
        best["peak_field_refinement_passed"] = peak_change <= 0.08
        best["all_vacuum_minimum_b_gates_passed"] = all(values(best["gates"])) &&
            best["refined_peak_field_passed"] === true &&
            best["peak_field_refinement_passed"] === true
    end
    component = best !== nothing &&
        best["all_vacuum_minimum_b_gates_passed"] === true
    physical = Dict{String,Any}(
        "search_contract" => search_contract,
        "search_problem_hash" => search_problem_hash,
        "pack_summaries" => pack_summaries,
        "evaluated_configuration_count" => evaluated_count,
        "sampled_well_pass_count" => well_pass_count,
        "open_field_line_pass_count" => line_pass_count,
        "coarse_peak_field_pass_count" => coarse_peak_pass_count,
        "line_survivors" => line_survivors,
        "best_bounded_cage_attempt" => best,
        "minimum_b_vacuum_component_authorized" => component)
    return merge(physical, Dict{String,Any}(
        "schema_version" => "1.0.0",
        "evaluator_version" =>
            "candidate_specific_minimum_b_cage_search_v1",
        "parent_repair_candidate_id" =>
            winding_record["repair_candidate_id"],
        "family_label_used" => false,
        "physical_result_hash" => canonical_hash(physical),
        "complete_stability_evidence_authorized" => false,
        "complete_c2_evidence_authorized" => false,
        "promotion_authorized" => false,
        "status" => component ?
            "narrow_minimum_b_vacuum_component" :
            "bounded_cage_grammar_no_complete_vacuum_survivor",
        "claim_boundary" => "This is a bounded search over an explicit three-cell divergence-free quadrupolar cage. A pass would establish only a sampled vacuum minimum-B and open-field-line component. A negative result rejects this cage grammar and search bounds, not all mirror stabilization mechanisms. Finite-beta equilibrium, FLR/m=1/DCLC/AIC, conductor critical surfaces, structural support, kinetics, balances and complete C2 remain unknown."))
end
