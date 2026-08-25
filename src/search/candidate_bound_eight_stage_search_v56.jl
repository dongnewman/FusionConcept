const _V56_CLAIM_BOUNDARY =
    "V56 compiles the same eight candidate-bound problem and evidence obligations for " *
    "every generated candidate, executes the available native candidate solver routes, " *
    "and then delegates the decision to v55. Problem compilation is not a solved state. " *
    "Missing state, mode, transport, burn, engineering, VVUQ, cross-code, or experimental " *
    "evidence remains unknown. V54 generated ledgers and legacy family proxies are archived " *
    "as rejected non-promoting inputs and never satisfy v55 stages 3, 5, 6, 7, or 8."

const _V56_ENGINEERING_CHECK_IDS = (
    "field_strength", "force", "stress", "heat_flux", "material_temperature",
    "irradiation", "quench", "repetition_rate", "maintenance_space",
    "fuel_cycle", "component_lifetime",
)

const _V56_UNCERTAINTY_CHECK_IDS = (
    "perturbation_uncertainty", "manufacturing_tolerance", "model_error",
    "resolution_convergence", "cross_code_replication", "experimental_anchor",
)

const _V56_PERTURBATION_CLASSES = (
    "state", "boundary", "source", "controller", "manufacturing",
)

function _v56_capture(action::Function, id::String)
    try
        details = _plain_json(action())
        details isa AbstractDict || (details = Dict{String,Any}("value" => details))
        record = Dict{String,Any}(
            "artifact_id" => id,
            "status" => String(get(details, "status", "compiled")),
            "details" => details,
        )
        record["artifact_hash"] = canonical_hash(record)
        return record
    catch exception
        details = Dict{String,Any}(
            "exception_type" => string(typeof(exception)),
            "message" => sprint(showerror, exception),
        )
        record = Dict{String,Any}(
            "artifact_id" => id,
            "status" => "unsupported",
            "details" => details,
        )
        record["artifact_hash"] = canonical_hash(record)
        return record
    end
end

function _v56_native_summary(native)
    magnetic = get(native, "magnetic", Dict{String,Any}())
    pulse = get(native, "pulse", Dict{String,Any}())
    return Dict{String,Any}(
        "status" => String(get(native, "status", "unknown")),
        "candidate_c1_evidence_authorized" =>
            get(native, "candidate_c1_evidence_authorized", false) === true,
        "hard_falsified" => get(native, "hard_falsified", false) === true,
        "physical_result_hash" => String(get(native, "physical_result_hash", "")),
        "magnetic" => Dict(
            "status" => String(get(magnetic, "status", "unknown")),
            "backend_executed" => get(magnetic, "backend_executed", false) === true,
            "field_solution_evidence_authorized" =>
                get(magnetic, "field_solution_evidence_authorized", false) === true,
            "hard_falsified" => get(magnetic, "hard_falsified", false) === true,
            "reason" => get(magnetic, "reason", nothing),
        ),
        "pulse" => Dict(
            "status" => String(get(pulse, "status", "unknown")),
            "backend_executed" => get(pulse, "backend_executed", false) === true,
            "drive_geometry_evidence_authorized" =>
                get(pulse, "drive_geometry_evidence_authorized", false) === true,
            "hard_falsified" => get(pulse, "hard_falsified", false) === true,
            "reason" => get(pulse, "reason", nothing),
        ),
    )
end

function _v56_route_summary(value)
    plain = _plain_json(value)
    return Dict{String,Any}(
        "status" => String(get(plain, "status", "unknown")),
        "backend_executed" => get(plain, "backend_executed", false) === true,
        "candidate_c1_evidence_authorized" =>
            get(plain, "candidate_c1_evidence_authorized", false) === true,
        "hard_falsified" => get(plain, "hard_falsified", false) === true,
        "physical_result_hash" => String(get(plain, "physical_result_hash", "")),
        "reason" => get(plain, "reason", nothing),
    )
end

function _v56_candidate_problem_artifacts(genome::Genome, module_ids;
        execute_native_routes::Bool = true)
    artifacts = Dict{String,Any}[]

    push!(artifacts, _v56_capture("executable_conservation_problem_v56") do
        executable = migrate_legacy_genome_to_executable_v1(genome)
        program = compile_executable_physics_program_v1(executable)
        problem = compile_conservation_problem_v2(executable)
        assessment = compile_candidate_conservation_v2(problem,
            ConservationTermEvidenceV2[])
        Dict{String,Any}(
            "status" => String(assessment.status),
            "executable_hash" => executable.document_hash,
            "program_hash" => program.program_hash,
            "conservation_problem_hash" => problem.problem_hash,
            "conservation_assessment_hash" => assessment.compilation_hash,
            "ready_module_count" => program.ready_module_count,
            "blocked_module_count" => length(program.modules) - program.ready_module_count,
            "required_balance_count" => length(problem.balances),
            "required_slot_count" => assessment.required_slot_count,
            "authoritative_slot_count" => assessment.authoritative_slot_count,
            "c2_support_authorized" => assessment.c2_support_authorized,
        )
    end)

    push!(artifacts, _v56_capture("stability_mode_inventory_v56") do
        feature = compile_stability_feature_evidence_v1(genome;
            source_kind = :structural_declaration,
            source_artifact_id = "candidate_genome",
            source_artifact_hash = genome.physics_hash,
            source_result_hash = genome.physics_hash,
            candidate_binding_verified = true,
            fidelity = 0)
        inventory = compile_stability_mode_inventory_v1(genome, feature)
        Dict{String,Any}(
            "status" => String(inventory.physical_stability_status),
            "feature_hash" => feature.feature_hash,
            "inventory_hash" => inventory.inventory_hash,
            "active_mode_ids" => inventory.active_mode_ids,
            "unknown_applicability_mode_ids" => inventory.unknown_applicability_mode_ids,
            "missing_active_mode_ids" => inventory.missing_active_mode_ids,
            "evaluation_complete" => inventory.evaluation_complete,
            "c2_support_authorized" => inventory.c2_support_authorized,
            "evidence_task_count" => length(inventory.evidence_tasks),
        )
    end)

    push!(artifacts, _v56_capture("transport_loss_problem_v56") do
        problem = compile_transport_loss_problem_v1(genome)
        assessment = assess_transport_loss_v1(problem, TransportLossEvidenceV1[])
        Dict{String,Any}(
            "status" => String(assessment.status),
            "problem_hash" => problem.problem_hash,
            "assessment_hash" => assessment.assessment_hash,
            "required_metric_ids" => assessment.required_metric_ids,
            "unknown_metric_ids" => assessment.unknown_metric_ids,
            "complete_transport_c2_authorized" =>
                assessment.complete_transport_c2_authorized,
        )
    end)

    push!(artifacts, _v56_capture("fusion_reaction_radiation_problem_v56") do
        problem = compile_fusion_reaction_radiation_problem_v1(genome)
        Dict{String,Any}(
            "status" => isempty(problem.channels) ? "unsupported" : "unknown",
            "problem_hash" => problem.problem_hash,
            "channel_ids" => getfield.(problem.channels, :channel_id),
            "required_state_ids" => problem.required_input_ids,
            "evidence_tasks" => problem.evidence_tasks,
            "solver_observation_present" => false,
        )
    end)

    push!(artifacts, _v56_capture("runtime_species_state_problem_v56") do
        problem = compile_runtime_species_state_problem_v1(genome)
        assessment = assess_runtime_species_state_v1(problem,
            RuntimeSpeciesStateEvidenceV1[])
        Dict{String,Any}(
            "status" => String(assessment.status),
            "problem_hash" => problem.problem_hash,
            "assessment_hash" => assessment.assessment_hash,
            "species_ids" => getfield.(problem.species_catalog, :species_id),
            "required_state_count" => length(problem.requirements),
            "complete_required_state" => assessment.complete_required_state,
            "c2_state_component_authorized" => assessment.c2_state_component_authorized,
        )
    end)

    push!(artifacts, _v56_capture("magnet_engineering_problem_v56") do
        problem = compile_magnet_engineering_problem_v1(genome)
        assessment = assess_magnet_engineering_v1(problem,
            MagnetEngineeringEvidenceV1[])
        Dict{String,Any}(
            "status" => String(assessment.status),
            "problem_hash" => problem.problem_hash,
            "assessment_hash" => assessment.assessment_hash,
            "required_metric_ids" => assessment.required_metric_ids,
            "feasibility_unknown_metric_ids" => assessment.feasibility_unknown_metric_ids,
            "complete_magnet_engineering_authorized" =>
                assessment.complete_magnet_engineering_authorized,
        )
    end)

    if execute_native_routes
        push!(artifacts, _v56_capture("native_candidate_c1_backend_v56") do
            _v56_native_summary(execute_native_candidate_c1_backend_v1(genome))
        end)
        if _v54_module_match(module_ids, ("mirror",))
            push!(artifacts, _v56_capture("axisymmetric_mirror_filament_c1_v56") do
                _v56_route_summary(execute_axisymmetric_mirror_filament_c1_v1(genome))
            end)
        end
        if _v54_module_match(module_ids, ("dipole",))
            push!(artifacts, _v56_capture("levitated_dipole_ring_c1_v56") do
                _v56_route_summary(evaluate_levitated_dipole_ring_screen_v1(genome))
            end)
        end
    end
    return artifacts
end

function _v56_artifact_by_id(artifacts, id::String)
    matches = [artifact for artifact in artifacts if artifact["artifact_id"] == id]
    return isempty(matches) ? nothing : only(matches)
end

function _v56_primary_region(genome::Genome)
    isempty(genome.plasma_regions) && return "missing_plasma_region"
    return first(genome.plasma_regions).id
end

function _v56_description(genome::Genome, artifacts)
    primary = _v56_primary_region(genome)
    species_artifact = _v56_artifact_by_id(artifacts,
        "runtime_species_state_problem_v56")
    species_ids = species_artifact === nothing ? String[] :
        String.(get(species_artifact["details"], "species_ids", Any[]))
    materials = sort!(unique(filter(!isempty, vcat(
        String[source.material for source in genome.field_sources],
        String[item.material for item in genome.compression_systems],
        copy(genome.engineering.magnet_technology),
        genome.engineering.blanket_concept === nothing ? String[] :
            [String(genome.engineering.blanket_concept)]))))
    sources = Dict{String,Any}[]
    for item in genome.field_sources
        push!(sources, Dict("id" => item.id, "kind" => item.kind,
            "target_ref" => primary, "binding_basis" => "candidate_genome_field_source"))
    end
    for item in genome.actuators
        push!(sources, Dict("id" => item.id, "kind" => item.kind,
            "target_ref" => primary, "binding_basis" => "candidate_genome_actuator"))
    end
    for item in genome.compression_systems
        target = isempty(item.target_region_ids) ? primary : first(item.target_region_ids)
        push!(sources, Dict("id" => item.id, "kind" => item.kind,
            "target_ref" => target, "binding_basis" => "explicit_compression_target"))
    end
    sinks = Dict{String,Any}[
        Dict("id" => "exhaust_$(region)", "kind" => genome.exhaust.kind,
            "source_ref" => region)
        for region in genome.exhaust.region_ids]
    active_mechanisms = [item for item in genome.stability_mechanisms if
        !isempty(item.actuator_ids)]
    actuator_ids = Set(getfield.(genome.actuators, :id))
    active_refs = sort!(unique(reduce(vcat,
        [item.actuator_ids for item in active_mechanisms]; init = String[])))
    filter!(id -> id in actuator_ids, active_refs)
    controllers = Dict{String,Any}[]
    control_policy = if !isempty(active_refs)
        for mechanism in active_mechanisms
            refs = sort!(unique(filter(id -> id in actuator_ids, mechanism.actuator_ids)))
            isempty(refs) && continue
            push!(controllers, Dict("id" => mechanism.id, "kind" => mechanism.mechanism,
                "target_ref" => primary, "actuator_refs" => refs,
                "binding_basis" => "candidate_genome_stability_mechanism"))
        end
        Dict{String,Any}("mode" => "active_closed_loop",
            "actuator_refs" => active_refs,
            "applicability_basis" => "stability mechanisms explicitly bind candidate actuators")
    elseif !isempty(genome.actuators)
        Dict{String,Any}("mode" => "open_loop_actuation",
            "actuator_refs" => sort!(getfield.(genome.actuators, :id)),
            "applicability_basis" => "candidate declares actuators but no closed-loop control binding")
    elseif !isempty(genome.stability_mechanisms)
        Dict{String,Any}("mode" => "passive_stability", "actuator_refs" => String[],
            "applicability_basis" => "candidate stability mechanisms declare no actuator dependency")
    else
        Dict{String,Any}("mode" => "explicit_no_controller", "actuator_refs" => String[],
            "applicability_basis" => "no control or stabilization operator is declared for this candidate scope")
    end
    observables = Dict{String,Any}[]
    for artifact in artifacts
        push!(observables, Dict("id" => "observe_$(artifact["artifact_id"])",
            "source_ref" => primary, "artifact_hash" => artifact["artifact_hash"]))
    end
    boundaries = Dict{String,Any}[
        Dict("id" => "boundary_$(index)", "from_ref" => item.from_region_id,
            "to_ref" => item.to_region_id, "kind" => item.kind)
        for (index, item) in enumerate(genome.flux_connections)]
    return Dict{String,Any}(
        "regions" => Any[Dict("id" => item.id, "kind" => item.kind,
            "geometry_model" => item.geometry_model) for item in genome.plasma_regions],
        "species" => Any[Dict("id" => id) for id in species_ids],
        "fields" => Any[Dict("id" => item.id, "kind" => item.kind,
            "geometry_model" => item.geometry_model) for item in genome.field_sources],
        "materials" => Any[Dict("id" => id) for id in materials],
        "boundaries" => boundaries,
        "sources" => sources,
        "sinks" => sinks,
        "controllers" => controllers,
        "control_policy" => control_policy,
        "observables" => observables,
    )
end

function _v56_topology(genome::Genome)
    nodes = Any[Dict("node_id" => item.id, "kind" => item.kind)
        for item in genome.plasma_regions]
    edges = Any[Dict(
        "from" => item.from_region_id,
        "to" => item.to_region_id,
        "direction" => "directed",
        "accounts" => Any["particles", "energy"],
        "kind" => item.kind)
        for item in genome.flux_connections]
    return Dict{String,Any}("nodes" => nodes, "edges" => edges)
end

function _v56_operating_mode(genome::Genome)
    mode = lowercase(genome.mission.operating_mode)
    occursin("steady", mode) && return "steady"
    occursin("pulse", mode) && return "pulsed"
    return "transient"
end

function _v56_evidence(artifacts, genome::Genome, proxy_hash::String,
        rejected_contract_hash::String)
    evidence = Dict{String,Any}[
        Dict("evidence_id" => "candidate_genome", "artifact_hash" => genome.physics_hash,
            "evidence_class" => "candidate_bound_genome"),
        Dict("evidence_id" => "legacy_proxy_diagnostic", "artifact_hash" => proxy_hash,
            "evidence_class" => "legacy_family_proxy_nonpromoting"),
        Dict("evidence_id" => "rejected_v54_generated_contract",
            "artifact_hash" => rejected_contract_hash,
            "evidence_class" => "generated_nominal_contract_rejected_for_promotion"),
    ]
    for artifact in artifacts
        push!(evidence, Dict(
            "evidence_id" => String(artifact["artifact_id"]),
            "artifact_hash" => String(artifact["artifact_hash"]),
            "evidence_class" => "candidate_bound_problem_or_solver_attempt"))
    end
    return evidence
end

function _v56_problem_ref(artifacts, id::String)
    artifact = _v56_artifact_by_id(artifacts, id)
    return artifact === nothing ? "candidate_genome" : String(artifact["artifact_id"])
end

"Compile one v54 candidate into a family-label-independent v55 judgment input."
function compile_candidate_bound_judgment_input_v56(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        candidate_record = nothing, execute_native_routes::Bool = true,
        compile_problem_artifacts::Bool = true)
    candidate = candidate_record === nothing ?
        evaluate_solver_ready_candidate_v54(context, candidate_index) : candidate_record
    compiled = candidate.prescreen.compiled
    genome = compiled.genome
    artifacts = compile_problem_artifacts ?
        _v56_candidate_problem_artifacts(genome, compiled.module_ids;
            execute_native_routes = execute_native_routes) : Dict{String,Any}[]
    contracts = genome.normalized["solver_ready_contracts"]
    contract_hash = String(contracts["contract_hash"])
    evidence = _v56_evidence(artifacts, genome,
        candidate.prescreen.proxy_result_hash, contract_hash)
    conservation_ref = _v56_problem_ref(artifacts,
        "executable_conservation_problem_v56")
    stability_ref = _v56_problem_ref(artifacts, "stability_mode_inventory_v56")
    transport_ref = _v56_problem_ref(artifacts, "transport_loss_problem_v56")
    reaction_ref = _v56_problem_ref(artifacts,
        "fusion_reaction_radiation_problem_v56")
    engineering_ref = _v56_problem_ref(artifacts,
        "magnet_engineering_problem_v56")
    native_ref = _v56_problem_ref(artifacts, "native_candidate_c1_backend_v56")
    description = _v56_description(genome, artifacts)
    primary = _v56_primary_region(genome)
    flux_paths = ["$(item.from_region_id)->$(item.to_region_id)"
        for item in genome.flux_connections]
    particle_paths = Any[
        Dict("role" => "production", "path" => "declared_sources->$primary"),
        Dict("role" => "loss", "path" => isempty(flux_paths) ?
            "unresolved_exhaust_path" : join(flux_paths, ";")),
        Dict("role" => "burn", "path" => "reaction_problem:$reaction_ref"),
    ]
    energy_paths = Any[
        Dict("role" => "deposition", "path" => "declared_actuators->$primary"),
        Dict("role" => "transport", "path" => "transport_problem:$transport_ref"),
        Dict("role" => "escape", "path" => isempty(flux_paths) ?
            "unresolved_exhaust_path" : join(flux_paths, ";")),
    ]
    perturbation_tests = Any[Dict(
        "perturbation_class" => class,
        "operator_id" => "unresolved_uniform_$(class)_operator",
        "evidence_refs" => Any[stability_ref],
        "resolution_state" => "unknown_no_candidate_solver_output")
        for class in _V56_PERTURBATION_CLASSES]
    engineering_checks = Any[Dict(
        "check_id" => id,
        "status" => "unknown",
        "evidence_refs" => Any[id in ("field_strength", "force", "stress", "quench") ?
            engineering_ref : native_ref])
        for id in _V56_ENGINEERING_CHECK_IDS]
    uncertainty_checks = Any[Dict(
        "check_id" => id,
        "status" => "unknown",
        "evidence_refs" => Any[id == "perturbation_uncertainty" ? stability_ref :
            id == "resolution_convergence" ? conservation_ref : "candidate_genome"])
        for id in _V56_UNCERTAINTY_CHECK_IDS]
    input = Dict{String,Any}(
        "candidate_id" => genome.design_id,
        "display_label" => genome.label,
        "family" => compiled.family,
        "parent_family" => nothing,
        "candidate_index" => Int(candidate_index),
        "physics_hash" => genome.physics_hash,
        "benchmark_scope" => "v56_full_candidate_bound_search",
        "mission" => Dict(
            "mission_id" => compiled.mission_contract_id,
            "fusion_burn_required" => occursin("net_electric",
                lowercase(compiled.mission_contract_id)),
            "positive_net_energy_required" => occursin("net_electric",
                lowercase(compiled.mission_contract_id))),
        "physical_description" => description,
        "topology_causality" => _v56_topology(genome),
        "state_evolution" => Dict(
            "mode" => _v56_operating_mode(genome),
            "solver_derived" => false,
            "generated_nominal" => false,
            "solver_output_hash" => "",
            "time_samples_s" => Any[],
            "complete_time_trajectory" => false,
            "normalized_residual_tolerance" => 1.0e-6,
            "steady_time_term_tolerance" => 1.0e-6,
            "required_accounts" => Any["energy", "particles"],
            "residuals" => Any[],
            "candidate_bound_problem_ref" => conservation_ref),
        "perturbation_stability" => Dict(
            "tests" => perturbation_tests,
            "candidate_bound_inventory_ref" => stability_ref),
        "transport_burn" => Dict(
            "solver_derived" => false,
            "generated_nominal" => false,
            "state_solution_hash" => "",
            "solver_output_hash" => "",
            "particle_paths" => particle_paths,
            "energy_paths" => energy_paths,
            "candidate_bound_transport_problem_ref" => transport_ref,
            "candidate_bound_reaction_problem_ref" => reaction_ref),
        "net_energy" => Dict(
            "generated_nominal" => false,
            "artificially_closed" => false,
            "terms" => Any[],
            "rejected_generated_ledger_hash" =>
                canonical_hash(contracts["ledgers"])),
        "engineering" => Dict("checks" => engineering_checks),
        "uncertainty_evidence" => Dict("checks" => uncertainty_checks),
        "evidence" => evidence,
        "stage_artifacts" => artifacts,
        "generation_audit" => Dict(
            "legacy_generation_family" => compiled.family,
            "legacy_projection_id" => compiled.projection_id,
            "legacy_proxy_result_hash" => candidate.prescreen.proxy_result_hash,
            "v54_generated_contract_hash" => contract_hash,
            "v54_generated_ledgers_rejected_for_v55" => true,
            "family_label_used_by_v55" => false,
            "parent_synthesized_for_v55" => false),
        "claim_boundary" => _V56_CLAIM_BOUNDARY,
    )
    input_hash = canonical_hash(input)
    artifact_summary = Dict{String,Any}(
        "candidate_index" => Int(candidate_index),
        "candidate_id" => genome.design_id,
        "physics_hash" => genome.physics_hash,
        "input_hash" => input_hash,
        "assembly_index" => candidate.assembly_index,
        "sample_ordinal" => candidate.sample_ordinal,
        "module_ids" => copy(compiled.module_ids),
        "legacy_family_nonrouting" => compiled.family,
        "artifact_count" => length(artifacts),
        "artifact_statuses" => Dict(String(item["artifact_id"]) =>
            String(item["status"]) for item in artifacts),
        "executed_native_backend_count" => count(item -> begin
            details = get(item, "details", Dict{String,Any}())
            magnetic = get(details, "magnetic", Dict{String,Any}())
            pulse = get(details, "pulse", Dict{String,Any}())
            get(details, "backend_executed", false) === true ||
                get(magnetic, "backend_executed", false) === true ||
                get(pulse, "backend_executed", false) === true
        end, artifacts),
        "candidate_c1_authorized_artifact_count" => count(item ->
            get(get(item, "details", Dict{String,Any}()),
                "candidate_c1_evidence_authorized", false) === true, artifacts),
        "hard_falsified_artifact_count" => count(item ->
            get(get(item, "details", Dict{String,Any}()),
                "hard_falsified", false) === true, artifacts),
        "promotion_authorized" => false,
    )
    return Dict{String,Any}(
        "judgment_input" => input,
        "artifact_summary" => artifact_summary,
        "input_hash" => input_hash,
    )
end

"Compile and evaluate a bounded collection without dropping unsupported candidates."
function evaluate_candidate_bound_search_batch_v56(
        context::RecoverableCrossTopologyContextV20, candidate_indices)
    bundles = [compile_candidate_bound_judgment_input_v56(context, index)
        for index in candidate_indices]
    inputs = getindex.(bundles, "judgment_input")
    archive = evaluate_all_search_results_v55(inputs)
    length(archive["results"]) == length(bundles) || error("v56 dropped a candidate")
    return Dict{String,Any}(
        "bundles" => bundles,
        "judgment_archive" => archive,
        "claim_boundary" => _V56_CLAIM_BOUNDARY,
    )
end
