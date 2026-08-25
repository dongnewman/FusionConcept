using Test
using JSON3
using FusionConceptAI

const PCV1_ROOT = normpath(joinpath(@__DIR__, ".."))
const PCV1_FIXTURES = [
    "freegs_testtokamak_regression_genome.json",
    "desc_w7x_regression_genome.json",
    "pleiades_wham_isotropic_regression_genome.json",
]

function pcv1_pass_bundle(genome::Genome)
    criterion_metrics = [
        "minimum_coil_separation", "coil_curvature", "assembly_tolerance",
        "maintenance_access", "fault_tolerance", "force_balance_residual",
        "minimum_stability_margin", "orbit_loss_fraction", "perturbation_robustness",
        "fusion_power", "recirculating_power", "net_electric_power",
        "peak_heat_flux", "wall_load", "availability",
    ]
    stage_metrics = [
        "field_solution_converged", "field_line_topology_resolved",
        "equilibrium_converged", "conservation_residuals_passed",
        "applicable_stability_modes_evaluated", "candidate_specific_transport_evaluated",
        "magnet_engineering_evaluated", "coupled_power_exhaust_closure",
        "fault_scenario_robustness", "independent_cross_code_agreement",
        "heldout_known_device_validation", "uncertainty_calibration_validated",
    ]
    ids = sort!(unique(vcat(criterion_metrics, stage_metrics)))
    run_hash = canonical_hash(Dict("test" => "pcv1_full_evidence",
        "physics_hash" => genome.physics_hash))
    metrics = MetricResult[
        MetricResult(id, true; fidelity = 4,
            applicability = "contract logic test only", status = :pass,
            solver_name = "pcv1_contract_test", solver_version = "1",
            input_hash = genome.physics_hash, run_hash = run_hash)
        for id in ids
    ]
    return EvaluationBundle("pcv1_contract_test", genome.design_id, genome.family,
        4, :pass, metrics, ["Synthetic contract test; no physics claim."],
        genome.physics_hash, run_hash, "validation_control")
end

@testset "Topology-independent physics compiler v1" begin
    genomes = [load_genome(joinpath(PCV1_ROOT, "examples", file))
        for file in PCV1_FIXTURES]
    problems = compile_physics_problem_v1.(genomes)
    @test getfield.(getfield.(problems, :topology), :closure_class) ==
        [:closed, :closed, :open]

    operator_ids(problem) = Set(item.spec.id for item in problem.operators)
    @test "axisymmetric_current_equilibrium_v1" in operator_ids(problems[1])
    @test "three_dimensional_mhd_equilibrium_v1" in operator_ids(problems[2])
    @test "open_field_finite_beta_equilibrium_v1" in operator_ids(problems[3])
    @test "classical_open_end_loss_prior_v1" in operator_ids(problems[3])
    @test !("ipb98_calibration_prior_v1" in operator_ids(problems[2]))
    @test all(!item.spec.promotion_authority for problem in problems
        for item in problem.operators if item.spec.empirical_prior)

    assessments = [assess_physics_problem_v1(problem, genome)
        for (problem, genome) in zip(problems, genomes)]
    @test all(item.highest_evidence_stage == "C0" for item in assessments)
    @test all(item.hard_gate_status == :unknown for item in assessments)
    @test all(!item.promotion_authorized for item in assessments)
    @test all(!isempty(item.evidence_tasks) for item in problems)

    original_raw = JSON3.read(read(joinpath(PCV1_ROOT, "examples",
        PCV1_FIXTURES[1]), String), Dict{String,Any})
    relabeled_raw = deepcopy(original_raw)
    relabeled_raw["design_id"] = "family_label_invariance_control"
    relabeled_raw["family"] = "arbitrary_unseen_family_label"
    relabeled = parse_genome(relabeled_raw)
    relabeled_problem = compile_physics_problem_v1(relabeled)
    @test problems[1].genome_physics_hash != relabeled_problem.genome_physics_hash
    @test problems[1].physical_signature_hash == relabeled_problem.physical_signature_hash
    @test problems[1].routing_hash == relabeled_problem.routing_hash

    renamed_raw = deepcopy(original_raw)
    renamed_raw["design_id"] = "component_identity_invariance_control"
    region_map = Dict(item["id"] => "region_$(index)"
        for (index, item) in enumerate(renamed_raw["plasma_regions"]))
    actuator_map = Dict(item["id"] => "actuator_$(index)"
        for (index, item) in enumerate(renamed_raw["actuators"]))
    for (index, item) in enumerate(renamed_raw["plasma_regions"])
        item["id"] = "region_$index"
    end
    for (index, item) in enumerate(renamed_raw["field_sources"])
        item["id"] = "source_$index"
    end
    for (index, item) in enumerate(renamed_raw["actuators"])
        item["id"] = "actuator_$index"
    end
    for item in renamed_raw["flux_connections"]
        item["from_region_id"] = region_map[item["from_region_id"]]
        item["to_region_id"] = region_map[item["to_region_id"]]
    end
    renamed_raw["exhaust"]["region_ids"] =
        [region_map[id] for id in renamed_raw["exhaust"]["region_ids"]]
    for item in renamed_raw["stability_mechanisms"]
        item["actuator_ids"] = [actuator_map[id] for id in item["actuator_ids"]]
    end
    renamed_problem = compile_physics_problem_v1(parse_genome(renamed_raw))
    @test problems[1].physical_signature_hash == renamed_problem.physical_signature_hash
    @test problems[1].routing_hash == renamed_problem.routing_hash

    changed_geometry_raw = deepcopy(original_raw)
    changed_geometry_raw["design_id"] = "geometry_sensitivity_control"
    changed_geometry_raw["plasma_regions"][1]["parameters"]["domain_r_max"]["value"] = 2.1
    changed_geometry_problem = compile_physics_problem_v1(parse_genome(changed_geometry_raw))
    @test problems[1].physical_signature_hash != changed_geometry_problem.physical_signature_hash
    @test problems[1].routing_hash == changed_geometry_problem.routing_hash

    mixed_raw = deepcopy(original_raw)
    mixed_raw["design_id"] = "mixed_topology_operator_composition_control"
    mixed_raw["family"] = "arbitrary_unseen_hybrid_label"
    mixed_raw["topology"]["field_line_class"] = "mixed"
    push!(mixed_raw["plasma_regions"], Dict{String,Any}(
        "id" => "open_end_control", "kind" => "end_expander",
        "geometry_model" => "bounded_axial_end_domain_v1",
        "parameters" => Dict("length" => Dict("value" => 1.0, "unit" => "m"))))
    push!(mixed_raw["flux_connections"], Dict{String,Any}(
        "from_region_id" => "freegs_regression_core",
        "to_region_id" => "open_end_control", "kind" => "open_field_line"))
    mixed_problem = compile_physics_problem_v1(parse_genome(mixed_raw))
    mixed_ids = Set(item.spec.id for item in mixed_problem.operators)
    @test mixed_problem.topology.closure_class == :mixed
    @test "closed_flux_surface_analysis_v1" in mixed_ids
    @test "open_field_connection_analysis_v1" in mixed_ids
    @test "open_field_finite_beta_equilibrium_v1" in mixed_ids

    full_assessment = assess_physics_problem_v1(problems[1], genomes[1],
        [pcv1_pass_bundle(genomes[1])])
    @test full_assessment.highest_evidence_stage == "C4"
    @test full_assessment.hard_gate_status == :pass
    @test full_assessment.promotion_authorized

    wrong_hash = pcv1_pass_bundle(genomes[1])
    bad_bundle = EvaluationBundle(wrong_hash.evaluator_id, wrong_hash.design_id,
        wrong_hash.family, wrong_hash.fidelity, wrong_hash.status, wrong_hash.metrics,
        wrong_hash.warnings, "wrong_hash", wrong_hash.run_hash, wrong_hash.claim_ceiling)
    @test_throws ArgumentError assess_physics_problem_v1(problems[1], genomes[1], [bad_bundle])

    conservation_domain = "manufactured_control_volume"
    conservation_hash = repeat("a", 64)
    key(quantity, species) = ConservationBalanceKeyV1(quantity, species,
        conservation_domain, Dict("particle" => "s^-1", "energy" => "W",
            "momentum" => "N", "current" => "A",
            "magnetic_flux" => "V")[quantity])
    balance_keys = [
        key("particle", "plasma_bulk"),
        key("energy", "electron"),
        key("energy", "ion"),
        key("momentum", "plasma_bulk"),
        key("current", "charge"),
        key("magnetic_flux", "field")]
    term_specs = Dict(
        "particle" => (10.0, 10.0),
        "momentum" => (10.0, 10.0),
        "current" => (10.0, 10.0),
        "magnetic_flux" => (10.0, 10.0))
    declarations = ConservationBalanceDeclarationV1[]
    terms = ConservationTermV1[]
    for item in balance_keys
        prefix = "$(item.conserved_quantity)_$(item.species)"
        ids = ["$(prefix)_storage", "$(prefix)_source", "$(prefix)_loss"]
        if item.conserved_quantity == "energy"
            push!(ids, "$(prefix)_exchange")
        end
        push!(declarations, ConservationBalanceDeclarationV1(item, ids;
            term_inventory_complete = true))
        push!(terms, ConservationTermV1(ids[1], item, :storage_rate, 0.0,
            conservation_hash))
        if item.conserved_quantity == "energy" && item.species == "electron"
            push!(terms, ConservationTermV1(ids[2], item, :source, 100.0,
                conservation_hash))
            push!(terms, ConservationTermV1(ids[3], item, :loss, 95.0,
                conservation_hash))
            push!(terms, ConservationTermV1(ids[4], item, :exchange, -5.0,
                conservation_hash; exchange_group_id = "electron_ion_energy"))
        elseif item.conserved_quantity == "energy"
            push!(terms, ConservationTermV1(ids[2], item, :source, 50.0,
                conservation_hash))
            push!(terms, ConservationTermV1(ids[3], item, :loss, 55.0,
                conservation_hash))
            push!(terms, ConservationTermV1(ids[4], item, :exchange, 5.0,
                conservation_hash; exchange_group_id = "electron_ion_energy"))
        else
            source, loss = term_specs[item.conserved_quantity]
            push!(terms, ConservationTermV1(ids[2], item, :source, source,
                conservation_hash))
            push!(terms, ConservationTermV1(ids[3], item, :loss, loss,
                conservation_hash))
        end
    end
    exchange_declarations = [InternalExchangeDeclarationV1(
        "electron_ion_energy", "energy", conservation_domain, "W",
        ["electron", "ion"])]
    ledger_args = (design_id = "conservation_contract_control",
        genome_physics_hash = repeat("b", 64),
        internal_exchange_declarations = exchange_declarations,
        covered_domain_ids = [conservation_domain],
        required_quantities = ["particle", "energy", "momentum", "current",
            "magnetic_flux"])
    candidate_ledger = compile_conservation_ledger_v1(; ledger_args...,
        declarations = declarations, terms = terms,
        source_kind = :candidate_bound_solver_accounting,
        candidate_binding_verified = true)
    @test candidate_ledger.status == :pass
    @test candidate_ledger.c2_support_authorized
    @test all(balance.normalized_residual == 0 for balance in
        candidate_ledger.balances)
    @test only(candidate_ledger.internal_exchanges).status == :pass
    @test conservation_ledger_to_dict_v1(candidate_ledger)["ledger_hash"] ==
        candidate_ledger.ledger_hash
    candidate_ledger_repeat = compile_conservation_ledger_v1(; ledger_args...,
        declarations = declarations, terms = terms,
        source_kind = :candidate_bound_solver_accounting,
        candidate_binding_verified = true)
    @test candidate_ledger_repeat.ledger_hash == candidate_ledger.ledger_hash
    conservation_bundle = conservation_ledger_evidence_bundle_v1(candidate_ledger)
    @test conservation_bundle.status == :pass
    @test conservation_bundle.claim_ceiling ==
        "C2_support_species_conservation_only"
    @test only(conservation_bundle.metrics).metric_id ==
        "conservation_residuals_passed"
    @test only(conservation_bundle.metrics).source_basis == [conservation_hash]

    manufactured_ledger = compile_conservation_ledger_v1(; ledger_args...,
        declarations = declarations, terms = terms,
        source_kind = :manufactured_control,
        candidate_binding_verified = false)
    @test manufactured_ledger.status == :pass
    @test !manufactured_ledger.c2_support_authorized
    @test conservation_ledger_evidence_bundle_v1(manufactured_ledger).status ==
        :unknown

    failed_terms = copy(terms)
    current_loss_index = findfirst(term -> term.term_id == "current_charge_loss",
        failed_terms)
    old_current_loss = failed_terms[current_loss_index]
    failed_terms[current_loss_index] = ConservationTermV1(
        old_current_loss.term_id, old_current_loss.key, old_current_loss.side,
        8.0, old_current_loss.evidence_hash)
    failed_ledger = compile_conservation_ledger_v1(; ledger_args...,
        declarations = declarations, terms = failed_terms,
        source_kind = :candidate_bound_solver_accounting,
        candidate_binding_verified = true)
    @test failed_ledger.status == :fail
    @test !failed_ledger.c2_support_authorized
    @test conservation_ledger_evidence_bundle_v1(failed_ledger).status == :fail
    @test only(filter(balance -> balance.key.conserved_quantity == "current",
        failed_ledger.balances)).status == :fail

    incomplete_declarations = copy(declarations)
    first_declaration = first(incomplete_declarations)
    incomplete_declarations[1] = ConservationBalanceDeclarationV1(
        first_declaration.key, first_declaration.required_term_ids;
        term_inventory_complete = false)
    incomplete_ledger = compile_conservation_ledger_v1(; ledger_args...,
        declarations = incomplete_declarations, terms = terms,
        source_kind = :candidate_bound_solver_accounting,
        candidate_binding_verified = true)
    @test incomplete_ledger.status == :unknown
    @test !incomplete_ledger.c2_support_authorized
    @test any(contains("term_inventories_complete"),
        incomplete_ledger.evidence_tasks)
    @test_throws ArgumentError compile_conservation_ledger_v1(; ledger_args...,
        declarations = declarations, terms = vcat(terms, [first(terms)]),
        source_kind = :candidate_bound_solver_accounting,
        candidate_binding_verified = true)
    @test_throws ArgumentError compile_conservation_ledger_v1(; ledger_args...,
        declarations = declarations, terms = terms, source_kind = :manufactured_control,
        candidate_binding_verified = true)
    @test_throws ArgumentError ConservationBalanceKeyV1("energy", "ion",
        conservation_domain, "J")
end
