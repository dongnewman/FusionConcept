#!/usr/bin/env julia

using FusionConceptAI
using JSON3

isempty(ARGS) && error("action required: compile, compile-transition, subset, budget-policy, coverage, initial-stage, next-stage, shard, merge, promote, or stop-audit")
action = first(ARGS)

function option(name, default = nothing)
    prefix = "--$(name)="
    match = findfirst(value -> startswith(value, prefix), ARGS[2:end])
    return match === nothing ? default : split(ARGS[match + 1], "="; limit = 2)[2]
end

integers(value) = Int[parse(Int, part) for part in split(String(value), ',')]
range_values(first_value, last_value) = parse(Int, first_value):parse(Int, last_value)

function read_json(path)
    return FusionConceptAI._stage3_plain_v1(JSON3.read(read(abspath(path), String),
        Dict{String,Any}))
end

function write_json(path, value)
    target = abspath(path); mkpath(dirname(target)); temporary = target * ".partial"
    open(temporary, "w") do io
        JSON3.pretty(io, value); write(io, '\n')
    end
    mv(temporary, target; force = true)
    return target
end

if action == "compile"
    first_seed = option("structure-first", "1")
    last_seed = option("structure-last", first_seed)
    campaign = compile_multitopology_campaign_v86(
        structure_seeds = range_values(first_seed, last_seed),
        physical_variants = integers(option("physical-variants", "1")),
        operating_variants = integers(option("operating-variants", "1")),
        control_variants = integers(option("control-variants", "1")),
        routes = split(option("routes", "closed/mixed,open/mixed"), ','),
        basis_levels = integers(option("basis-levels", "0")))
    output = write_json(option("output", "v86_campaign.json"), campaign)
    println(JSON3.write(Dict("status" => "complete", "output" => output,
        "campaign_hash" => campaign["campaign_hash"],
        "request_count" => length(campaign["requests"]))))
elseif action == "compile-transition"
    first_seed = option("structure-first", "1")
    last_seed = option("structure-last", first_seed)
    campaign = compile_structural_transition_campaign_v86(
        structure_seeds = range_values(first_seed, last_seed),
        physical_variants = integers(option("physical-variants", "1")),
        operating_variants = integers(option("operating-variants", "1")),
        control_variants = integers(option("control-variants", "1")),
        transition_id = option("transition"))
    output = write_json(option("output", "v86_transition_campaign.json"), campaign)
    println(JSON3.write(Dict("status" => "complete", "output" => output,
        "campaign_hash" => campaign["campaign_hash"],
        "structural_transition_id" => campaign["specification"][
            "structural_transition_id"],
        "request_count" => length(campaign["requests"]))))
elseif action == "subset"
    campaign = read_json(option("campaign"))
    eligibility_value = option("minimality-eligible")
    eligibility = eligibility_value === nothing ? nothing :
        lowercase(eligibility_value) == "true"
    subset = compile_v86_capability_subset_catalog_v1(campaign;
        required_gate = option("required-gate"),
        minimality_eligible = eligibility)
    output = write_json(option("output", "v86_capability_subset.json"), subset)
    println(JSON3.write(Dict("status" => "complete", "output" => output,
        "campaign_hash" => subset["campaign_hash"],
        "request_count" => length(subset["requests"]))))
elseif action == "budget-policy"
    base = compile_v86_capability_budget_policy_v1()
    per_cell = copy(base["maximum_stage_requests_per_cell"])
    per_stratum = copy(base["maximum_stage_requests_per_stratum"])
    per_cell["finite_filament_field"] = parse(Int, option(
        "field-per-cell", string(per_cell["finite_filament_field"])))
    per_stratum["finite_filament_field"] = parse(Int, option(
        "field-per-stratum", string(per_stratum["finite_filament_field"])))
    for (gate, prefix) in (("poincare_32", "p32"),
            ("poincare_64", "p64"), ("poincare_128", "p128"),
            ("finite_pressure_equilibrium", "finite-pressure"),
            ("sampled_ideal_mhd_stability", "stability"),
            ("open_field_end_loss", "open-end-loss"),
            ("open_field_finite_pressure_capability", "open-finite-pressure"))
        per_cell[gate] = parse(Int, option("$(prefix)-per-cell",
            string(per_cell[gate])))
        per_stratum[gate] = parse(Int, option("$(prefix)-per-stratum",
            string(per_stratum[gate])))
    end
    policy = compile_v86_capability_budget_policy_v1(
        minimum_initial_exploration_per_cell = parse(Int, option(
            "minimum-per-cell", "1")),
        maximum_stage_requests_per_cell = per_cell,
        maximum_stage_requests_per_stratum = per_stratum,
        maximum_exceptions_per_cell = parse(Int, option(
            "maximum-exceptions-per-cell", "3")),
        maximum_basis_upgrades_per_cell = parse(Int, option(
            "maximum-basis-upgrades-per-cell", "2")))
    output = write_json(option("output", "v86_budget_policy.json"), policy)
    println(JSON3.write(Dict("status" => "complete", "output" => output,
        "budget_policy_hash" => policy["budget_policy_hash"])))
elseif action == "coverage"
    campaign = read_json(option("campaign"))
    manifest = compile_v86_capability_coverage_manifest_v1(campaign)
    output = write_json(option("output", "v86_capability_coverage.json"), manifest)
    println(JSON3.write(Dict("status" => "complete", "output" => output,
        "campaign_hash" => manifest["campaign_hash"],
        "capability_cell_count" => manifest["capability_cell_count"])))
elseif action == "initial-stage"
    catalog = read_json(option("campaign"))
    policy_path = option("budget-policy")
    policy = policy_path === nothing ?
        compile_v86_capability_budget_policy_v1() : read_json(policy_path)
    stop_path = option("stop-manifest")
    stop_manifest = stop_path === nothing ? nothing : read_json(stop_path)
    staged = compile_v86_initial_stage_campaign_v1(catalog;
        budget_policy = policy, stop_manifest = stop_manifest,
        allow_after_stop = lowercase(option("allow-after-stop", "false")) ==
            "true",
        design_execution_policy = option("design-execution-policy",
            "joint_optimize_and_reaudit_v1"))
    output = write_json(option("output", "v86_initial_field_stage.json"), staged)
    println(JSON3.write(Dict("status" => "complete", "output" => output,
        "campaign_hash" => staged["campaign_hash"],
        "scheduled_gate" => staged["specification"]["scheduled_gate"],
        "request_count" => length(staged["requests"]))))
elseif action == "next-stage"
    campaign = read_json(option("campaign")); summary = read_json(option("summary"))
    policy_path = option("budget-policy")
    policy = policy_path === nothing ? get(campaign["specification"],
        "budget_policy", compile_v86_capability_budget_policy_v1()) :
        read_json(policy_path)
    target = option("target-gate")
    staged = compile_v86_next_stage_frontier_v1(campaign, summary;
        budget_policy = policy, target_gate = target)
    staged === nothing && error("no eligible next-stage frontier")
    output = write_json(option("output", "v86_next_stage.json"), staged)
    println(JSON3.write(Dict("status" => "complete", "output" => output,
        "campaign_hash" => staged["campaign_hash"],
        "scheduled_gate" => staged["specification"]["scheduled_gate"],
        "request_count" => length(staged["requests"]))))
elseif action == "shard"
    campaign = read_json(option("campaign"))
    summary = run_v86_campaign_shard_v1(campaign,
        parse(Int, option("shard-id")), parse(Int, option("first-position")),
        parse(Int, option("last-position"));
        output_directory = abspath(option("output-directory")),
        cache_directory = abspath(option("cache-directory",
            joinpath(option("output-directory"), "solver_cache"))),
        checkpoint_interval = parse(Int, option("checkpoint-interval", "5")),
        resume = lowercase(option("resume", "true")) == "true",
        maximum_sweeps = parse(Int, option("maximum-sweeps", "1")),
        maximum_evaluations = parse(Int, option("maximum-evaluations", "20")),
        poincare_steps_per_turn = parse(Int, option("poincare-steps", "180")),
        execute_desc = lowercase(option("execute-desc", "true")) == "true")
    println(JSON3.write(summary))
elseif action == "merge"
    campaign = read_json(option("campaign"))
    summary = merge_v86_campaign_shards_v1(campaign;
        output_directory = abspath(option("output-directory")),
        expected_shard_ids = integers(option("shard-ids")))
    println(JSON3.write(summary))
elseif action == "promote"
    campaign = read_json(option("campaign")); summary = read_json(option("summary"))
    promoted = compile_v86_promoted_campaign_v1(campaign, summary)
    output = write_json(option("output", "v86_promoted_campaign.json"), promoted)
    println(JSON3.write(Dict("status" => "complete", "output" => output,
        "campaign_hash" => promoted["campaign_hash"],
        "request_count" => length(promoted["requests"]))))
elseif action == "stop-audit"
    batch_groups = split(option("batches"), ';')
    batches = [[read_json(path) for path in split(group, ',')] for group in
        batch_groups]
    manifest = compile_v86_search_stop_manifest_v1(batches;
        minimum_unique_biot_pass_inputs = parse(Int, option(
            "minimum-unique-biot-pass", "500")),
        required_consecutive_zero_survival_batches = parse(Int, option(
            "zero-survival-batches", "2")),
        minimum_unique_inputs_per_basis_basin = parse(Int, option(
            "minimum-basis-inputs", "64")))
    output = write_json(option("output", "v86_search_stop_manifest.json"),
        manifest)
    println(JSON3.write(Dict("status" => "complete", "output" => output,
        "stop_topology_expansion" => manifest["stop_topology_expansion"],
        "unique_biot_pass_field_input_count" => manifest[
            "unique_biot_pass_field_input_count"],
        "formal_poincare_128_pass_count" => manifest[
            "formal_poincare_128_pass_count"])))
else
    error("unknown v86 campaign action $action")
end
