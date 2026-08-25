const _V34_CLAIM_BOUNDARY =
    "V34 performs symmetric local perturbations of the 24 paired-Halton projection coordinates for the 55 sealed v33 failure-frontier records. It traces changed Genome numeric fields and evaluator formula sites, but these are sensitivities of the existing fidelity-0 proxies, not physical causal effects or uncertainty propagation. It changes no topology, gate, evidence level, or mission contract, runs no robustness or medium-fidelity solver, and grants no feasibility, novelty, C1, family-ranking, or promotion credit."

const _V34_EVALUATOR_SOURCE_RELATIVE = Dict(
    "composable_cross_family_screen_v1" =>
        joinpath("src", "adapters", "composable_cross_family_screen_v1.jl"),
    "laser_icf_screen_v1" =>
        joinpath("src", "adapters", "laser_icf_screen_v1.jl"),
    "self_organized_screen_v1" =>
        joinpath("src", "adapters", "self_organized_screen_v1.jl"),
    "pulsed_compression_screen_v1" =>
        joinpath("src", "adapters", "pulsed_compression_screen_v1.jl"),
    "profile_coupled_rfp_screen_v1" =>
        joinpath("src", "adapters", "profile_coupled_rfp_screen_v1.jl"),
    "mechanism_expansion_screen_v1" =>
        joinpath("src", "adapters", "mechanism_expansion_screen_v1.jl"))

function evaluator_source_relative_v34(evaluator_id::AbstractString)
    id = String(evaluator_id)
    haskey(_V34_EVALUATOR_SOURCE_RELATIVE, id) || throw(ArgumentError(
        "v34 has no sealed source owner for evaluator $id"))
    return _V34_EVALUATOR_SOURCE_RELATIVE[id]
end

function formula_ownership_sites_v34(project_root::AbstractString,
        evaluator_id::AbstractString, margin_id::AbstractString)
    relative = evaluator_source_relative_v34(evaluator_id)
    source_path = joinpath(String(project_root), relative)
    isfile(source_path) || throw(ArgumentError(
        "v34 evaluator source is missing: $source_path"))
    lines = readlines(source_path)
    needle = "\"$(String(margin_id))\""
    sites = Dict{String,Any}[]
    for (index, line) in enumerate(lines)
        occursin(needle, line) || continue
        function_signature = "top_level"
        for prior in index:-1:1
            stripped = strip(lines[prior])
            if startswith(stripped, "function ")
                function_signature = stripped
                break
            end
        end
        push!(sites, Dict{String,Any}(
            "line_number" => index,
            "function_signature" => function_signature,
            "source_relative_path" => replace(relative, '\\' => '/'),
            "source_line" => strip(line)))
    end
    isempty(sites) && error(
        "v34 found no literal formula site for $evaluator_id/$margin_id")
    return sites
end

function _v34_candidate_from_values(context::RecoverableCrossTopologyContextV20,
        candidate_index::Int, values_u::AbstractVector{<:Real})
    candidate_index > 0 || throw(ArgumentError(
        "v34 candidate index must be positive"))
    length(values_u) == length(_V20_HALTON_PRIMES) || throw(ArgumentError(
        "v34 requires all paired-Halton coordinates"))
    all(value -> 0.0 <= Float64(value) <= 1.0, values_u) ||
        throw(ArgumentError("v34 unit coordinates left [0,1]"))
    topology_count = length(context.assemblies)
    assembly_index = mod1(candidate_index, topology_count)
    sample_ordinal = cld(candidate_index, topology_count)
    assembly = context.assemblies[assembly_index]
    values = Float64.(values_u)
    proxy, evaluator_id, projection_id, limitations = _v20_projection(
        context.compiler_context, assembly, values)
    annotated = _v18_annotate_proxy(proxy, assembly, context.modules)
    genome = _v20_sample_annotation(annotated, assembly, sample_ordinal)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError(
        "v34 perturbed genome invalid: " * join(report.errors, "; ")))
    family_report = assembly.family == "inertial_confinement_fusion" ?
        validate_family(laser_icf_family_registry_v15(), genome) :
        validate_family(default_family_registry(), genome)
    family_report.valid || throw(ArgumentError(
        "v34 perturbed family invalid: " * join(family_report.errors, "; ")))
    mission_contract_for(default_mission_contract_registry(), genome).id ==
        assembly.mission_contract_id || throw(ArgumentError(
        "v34 perturbed mission contract drifted"))
    declared = _v20_declared_requirements(context, assembly)
    issubset(Set(declared), Set(_requirements(genome))) || throw(ArgumentError(
        "v34 perturbed genome lost evaluator requirements"))
    warnings = sort!(unique(vcat(report.warnings, family_report.warnings)))
    compiled = CompiledAttributeGenomeV18(assembly.assembly_id,
        assembly.graph_hash, assembly.family, assembly.mission_contract_id,
        copy(assembly.module_ids), genome, evaluator_id, projection_id,
        sort!(unique(limitations)), declared, warnings)
    prescreen = _v18_prescreen(compiled, context.evaluators,
        context.evaluator_registry)
    return CrossTopologyCandidateV20(candidate_index, assembly_index,
        sample_ordinal, prescreen)
end

function _v34_raw_result(context::RecoverableCrossTopologyContextV20,
        candidate::CrossTopologyCandidateV20)
    compiled = candidate.prescreen.compiled
    return _plain_json(_v18_route_result(
        context.evaluators[compiled.evaluator_id], compiled.genome))
end

function _v34_margin_value(raw_result::AbstractDict, margin_id::String)
    nominal = get(raw_result, "nominal", Dict{String,Any}())
    margins = get(nominal, "margins", Dict{String,Any}())
    haskey(margins, margin_id) || error(
        "v34 perturbed result lost primary margin $margin_id")
    value = margins[margin_id]
    value isa Real || error("v34 primary margin is not numeric")
    converted = Float64(value)
    isfinite(converted) || error("v34 primary margin is not finite")
    return converted
end

function _v34_numeric_leaves!(leaves::Dict{String,Float64}, value,
        prefix::String)
    if value isa AbstractDict
        for key in sort!(collect(keys(value)); by = string)
            child = isempty(prefix) ? String(key) : "$prefix.$(String(key))"
            _v34_numeric_leaves!(leaves, value[key], child)
        end
    elseif value isa AbstractVector
        for (index, item) in enumerate(value)
            _v34_numeric_leaves!(leaves, item, "$prefix[$index]")
        end
    elseif value isa Bool || value === nothing
        return leaves
    elseif value isa Real
        converted = Float64(value)
        isfinite(converted) && (leaves[prefix] = converted)
    end
    return leaves
end

function _v34_numeric_leaves(value)
    leaves = Dict{String,Float64}()
    return _v34_numeric_leaves!(leaves, value, "")
end

function _v34_changed_gene_paths(low_genome::Genome, high_genome::Genome)
    low = _v34_numeric_leaves(low_genome.normalized)
    high = _v34_numeric_leaves(high_genome.normalized)
    paths = String[]
    for path in sort!(collect(union(keys(low), keys(high))))
        haskey(low, path) && haskey(high, path) || continue
        isapprox(low[path], high[path]; atol = 1.0e-12,
            rtol = 1.0e-12) && continue
        push!(paths, path)
    end
    return paths
end

function local_frontier_proxy_sensitivity_v34(
        context::RecoverableCrossTopologyContextV20, v33_raw;
        unit_delta::Real = 0.02, halton_skip::Integer = 4096)
    record = _plain_json(v33_raw)
    record["diagnostic_decomposition_authorized"] === true ||
        throw(ArgumentError("v34 requires a v33 diagnostic decomposition"))
    record["promoted"] === false || throw(ArgumentError(
        "v34 cannot perturb a promoted record"))
    delta = Float64(unit_delta)
    0.0 < delta <= 0.10 || throw(ArgumentError(
        "v34 unit delta must be in (0,0.10]"))
    candidate_index = Int(record["candidate_index"])
    base_candidate = evaluate_cross_topology_candidate_v20(context,
        candidate_index; halton_skip = Int(halton_skip))
    base_raw = _v34_raw_result(context, base_candidate)
    String(base_raw["result_hash"]) == String(record["raw_result_hash"]) ||
        error("v34 base raw-result reconstruction drifted")
    compiled = base_candidate.prescreen.compiled
    evaluator_id = compiled.evaluator_id
    margin_id = String(record["primary_limiting_margin"]["margin_id"])
    baseline_margin = _v34_margin_value(base_raw, margin_id)
    baseline_margin == Float64(record["primary_limiting_margin"]["value"]) ||
        error("v34 baseline primary margin drifted")
    base_values = _v20_unit_vector(base_candidate.sample_ordinal,
        length(_V20_HALTON_PRIMES); skip = Int(halton_skip))
    sensitivities = Dict{String,Any}[]
    for dimension in eachindex(base_values)
        low_values = copy(base_values)
        high_values = copy(base_values)
        low_values[dimension] = max(0.0, base_values[dimension] - delta)
        high_values[dimension] = min(1.0, base_values[dimension] + delta)
        high_values[dimension] > low_values[dimension] || error(
            "v34 collapsed perturbation interval")
        low_candidate = _v34_candidate_from_values(context,
            candidate_index, low_values)
        high_candidate = _v34_candidate_from_values(context,
            candidate_index, high_values)
        low_compiled = low_candidate.prescreen.compiled
        high_compiled = high_candidate.prescreen.compiled
        low_compiled.family == compiled.family == high_compiled.family ||
            error("v34 family changed under coordinate perturbation")
        low_compiled.evaluator_id == evaluator_id ==
            high_compiled.evaluator_id || error(
            "v34 evaluator changed under coordinate perturbation")
        low_raw = _v34_raw_result(context, low_candidate)
        high_raw = _v34_raw_result(context, high_candidate)
        low_margin = _v34_margin_value(low_raw, margin_id)
        high_margin = _v34_margin_value(high_raw, margin_id)
        interval = high_values[dimension] - low_values[dimension]
        slope = (high_margin - low_margin) / interval
        changed_paths = _v34_changed_gene_paths(low_compiled.genome,
            high_compiled.genome)
        best_margin = max(low_margin, high_margin)
        best_direction = high_margin > low_margin ? "increase_coordinate" :
            high_margin < low_margin ? "decrease_coordinate" : "no_margin_effect"
        push!(sensitivities, Dict{String,Any}(
            "coordinate_dimension" => Int(dimension),
            "baseline_coordinate" => Float64(base_values[dimension]),
            "low_coordinate" => Float64(low_values[dimension]),
            "high_coordinate" => Float64(high_values[dimension]),
            "low_margin" => low_margin,
            "high_margin" => high_margin,
            "signed_unit_slope" => slope,
            "absolute_unit_slope" => abs(slope),
            "symmetric_margin_span" => high_margin - low_margin,
            "absolute_margin_span" => abs(high_margin - low_margin),
            "best_endpoint_margin" => best_margin,
            "best_endpoint_improvement" => best_margin - baseline_margin,
            "best_direction" => best_direction,
            "changed_gene_path_count" => length(changed_paths),
            "changed_gene_paths" => changed_paths,
            "coordinate_active_in_projection" => !isempty(changed_paths),
            "primary_margin_locally_affected" => !isapprox(low_margin,
                high_margin; atol = 1.0e-12, rtol = 1.0e-12),
            "crosses_primary_zero" => best_margin >= 0.0,
            "low_raw_result_hash" => String(low_raw["result_hash"]),
            "high_raw_result_hash" => String(high_raw["result_hash"])))
    end
    active = [item for item in sensitivities if
        item["coordinate_active_in_projection"] === true]
    affected = [item for item in active if
        item["primary_margin_locally_affected"] === true]
    ranked = sort!(deepcopy(affected); by = item ->
        (-Float64(item["absolute_margin_span"]),
            Int(item["coordinate_dimension"])))
    best = isempty(ranked) ? nothing : first(ranked)
    primary_response_signature = canonical_hash([Dict{String,Any}(
        "coordinate_dimension" => item["coordinate_dimension"],
        "low_margin" => item["low_margin"],
        "high_margin" => item["high_margin"])
        for item in sensitivities])
    gene_path_signature = canonical_hash([Dict{String,Any}(
        "coordinate_dimension" => item["coordinate_dimension"],
        "changed_gene_paths" => item["changed_gene_paths"])
        for item in sensitivities])
    formula_sites = formula_ownership_sites_v34(
        normpath(joinpath(@__DIR__, "..", "..")), evaluator_id, margin_id)
    return Dict{String,Any}(
        "candidate_index" => candidate_index,
        "family" => String(record["family"]),
        "graph_hash" => String(record["graph_hash"]),
        "physics_hash" => String(record["physics_hash"]),
        "module_ids" => String.(copy(record["module_ids"])),
        "missing_proxy_requirements" => String.(copy(
            record["missing_proxy_requirements"])),
        "evaluator_id" => evaluator_id,
        "evaluator_source_relative_path" => replace(
            evaluator_source_relative_v34(evaluator_id), '\\' => '/'),
        "primary_margin_id" => margin_id,
        "primary_margin_domain" => String(record["primary_failure_domain"]),
        "baseline_primary_margin" => baseline_margin,
        "formula_ownership_sites" => formula_sites,
        "unit_delta" => delta,
        "coordinate_count" => length(sensitivities),
        "active_coordinate_count" => length(active),
        "affected_coordinate_count" => length(affected),
        "coordinate_sensitivities" => sensitivities,
        "primary_response_signature_hash" => primary_response_signature,
        "gene_path_signature_hash" => gene_path_signature,
        "top_affected_coordinates" => first(ranked, min(5, length(ranked))),
        "best_coordinate_dimension" => best === nothing ? nothing :
            Int(best["coordinate_dimension"]),
        "best_coordinate_direction" => best === nothing ? nothing :
            String(best["best_direction"]),
        "best_endpoint_improvement" => best === nothing ? 0.0 :
            Float64(best["best_endpoint_improvement"]),
        "best_endpoint_margin" => best === nothing ? baseline_margin :
            Float64(best["best_endpoint_margin"]),
        "any_local_zero_crossing" => any(item ->
            item["crosses_primary_zero"] === true, sensitivities),
        "base_raw_result_reconstruction_match" => true,
        "sensitivity_scope" => "local_fidelity0_projection_coordinates_only",
        "physical_causal_effect_claimed" => false,
        "diagnostic_proxy_sensitivity_authorized" => true,
        "robustness_evaluation_authorized" => false,
        "five_gate_comparison_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promoted" => false,
        "claim_level" => "C0_local_proxy_sensitivity_only")
end

function _v34_family_summary(rows)
    best_dimensions = String[string(row["best_coordinate_dimension"])
        for row in rows if row["best_coordinate_dimension"] !== nothing]
    evaluators = String[row["evaluator_id"] for row in rows]
    margins = String[row["primary_margin_id"] for row in rows]
    improvements = Float64[Float64(row["best_endpoint_improvement"])
        for row in rows]
    return Dict{String,Any}(
        "record_count" => length(rows),
        "evaluator_counts" => _v33_count_strings(evaluators),
        "primary_margin_counts" => _v33_count_strings(margins),
        "graph_count" => length(unique(String(row["graph_hash"])
            for row in rows)),
        "unique_primary_response_signature_count" => length(unique(String(
            row["primary_response_signature_hash"]) for row in rows)),
        "unique_gene_path_signature_count" => length(unique(String(
            row["gene_path_signature_hash"]) for row in rows)),
        "dominant_coordinate_counts" => _v33_count_strings(best_dimensions),
        "mean_active_coordinate_count" => sum(Int(
            row["active_coordinate_count"]) for row in rows) / length(rows),
        "mean_affected_coordinate_count" => sum(Int(
            row["affected_coordinate_count"]) for row in rows) / length(rows),
        "minimum_best_endpoint_improvement" => minimum(improvements),
        "median_best_endpoint_improvement" =>
            _v28_quantile(improvements, 0.50),
        "maximum_best_endpoint_improvement" => maximum(improvements),
        "local_zero_crossing_count" => count(row ->
            row["any_local_zero_crossing"] === true, rows),
        "raw_reconstruction_count" => count(row ->
            row["base_raw_result_reconstruction_match"] === true, rows))
end

function aggregate_frontier_proxy_sensitivity_v34(records::AbstractVector;
        expected_families::Integer = 11, expected_per_family::Integer = 5)
    rows = [Dict{String,Any}(String(key) => _plain_json(value)
        for (key, value) in record) for record in records]
    length(rows) == Int(expected_families) * Int(expected_per_family) ||
        throw(ArgumentError("v34 sensitivity record count changed"))
    families = sort!(unique(String(row["family"]) for row in rows))
    length(families) == Int(expected_families) || throw(ArgumentError(
        "v34 sensitivity family count changed"))
    family_summaries = Dict{String,Any}()
    for family in families
        family_rows = [row for row in rows if row["family"] == family]
        length(family_rows) == Int(expected_per_family) || throw(ArgumentError(
            "v34 per-family sensitivity count changed for $family"))
        family_summaries[family] = _v34_family_summary(family_rows)
    end
    evaluator_counts = _v33_count_strings(String[row["evaluator_id"]
        for row in rows])
    margin_counts = _v33_count_strings(String[row["primary_margin_id"]
        for row in rows])
    net_rows = [row for row in rows if
        row["primary_margin_id"] == "net_electric_power"]
    net_evaluator_counts = _v33_count_strings(String[row["evaluator_id"]
        for row in net_rows])
    composable_net_count = get(net_evaluator_counts,
        "composable_cross_family_screen_v1", 0)
    aliased_families = String[family for family in families if
        Int(family_summaries[family]["graph_count"]) > 1 &&
        Int(family_summaries[family][
            "unique_primary_response_signature_count"]) == 1]
    return Dict{String,Any}(
        "record_count" => length(rows),
        "family_count" => length(families),
        "records_per_family" => Int(expected_per_family),
        "coordinate_count_per_record" => 24,
        "total_coordinate_perturbation_pairs" => 24 * length(rows),
        "total_perturbed_proxy_evaluations" => 2 * 24 * length(rows),
        "evaluator_counts" => evaluator_counts,
        "primary_margin_counts" => margin_counts,
        "family_summaries" => family_summaries,
        "local_zero_crossing_count" => count(row ->
            row["any_local_zero_crossing"] === true, rows),
        "all_raw_results_reconstructed" => all(row ->
            row["base_raw_result_reconstruction_match"] === true, rows),
        "net_electric_primary_record_count" => length(net_rows),
        "net_electric_evaluator_counts" => net_evaluator_counts,
        "net_electric_composable_evaluator_count" => composable_net_count,
        "net_electric_composable_evaluator_fraction" => isempty(net_rows) ?
            0.0 : composable_net_count / length(net_rows),
        "shared_proxy_confounding_detected" => composable_net_count >= 2,
        "shared_proxy_interpretation" =>
            "A shared evaluator can create correlated proxy bottlenecks; local coordinate sensitivity cannot distinguish model-form bias from physical infeasibility.",
        "families_with_topology_primary_response_aliasing" =>
            sort!(aliased_families),
        "family_count_with_topology_primary_response_aliasing" =>
            length(aliased_families),
        "topology_primary_response_aliasing_detected" =>
            !isempty(aliased_families),
        "topology_aliasing_interpretation" =>
            "Distinct frontier graph hashes share an identical primary-margin response to all 24 projection-coordinate perturbations within these families; topology modules are not resolved by the current primary proxy response.",
        "physical_causal_effect_claimed" => false,
        "diagnostic_proxy_sensitivity_authorized" => true,
        "robustness_evaluation_authorized" => false,
        "five_gate_comparison_authorized" => false,
        "promotion_count" => 0,
        "medium_fidelity_authorized_count" => 0,
        "claim_boundary" => _V34_CLAIM_BOUNDARY)
end
