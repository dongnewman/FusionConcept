const _CONSERVATION_TERM_EVIDENCE_SOURCE_KINDS_V2 = Set((
    :candidate_solver, :measured, :manufactured, :structural_declaration))
const _CONSERVATION_TERM_EVIDENCE_STATUSES_V2 = Set((:pass, :unknown))

struct ConservationIRTermAuditV2
    module_id::String
    term_id::String
    kind::Symbol
    conserved_quantities::Vector{String}
    domain_ids::Vector{String}
    status::Symbol
    gap_ids::Vector{String}
end

"One automatically generated balance problem, not a manually selected ledger row."
struct ConservationBalanceRequirementV2
    key::ConservationBalanceKeyV1
    control_volume_kind::Symbol
    required_slot_ids::Vector{String}
    declared_ir_term_ids::Vector{String}
    structural_gap_ids::Vector{String}
end

struct CompiledConservationProblemV2
    schema_version::String
    design_id::String
    genome_physics_hash::String
    executable_document_hash::String
    plasma_control_volume_ids::Vector{String}
    field_source_control_volume_ids::Vector{String}
    species_ids::Vector{String}
    required_quantities::Vector{String}
    balances::Vector{ConservationBalanceRequirementV2}
    ir_term_audit::Vector{ConservationIRTermAuditV2}
    compiler_issues::Vector{String}
    evidence_tasks::Vector{String}
    claim_ceiling::String
    problem_hash::String
end

"Exact runtime value for one compiler-generated conservation slot."
struct ConservationTermEvidenceV2
    design_id::String
    genome_physics_hash::String
    balance_key::ConservationBalanceKeyV1
    slot_id::String
    side::Symbol
    value::Union{Nothing,Float64}
    source_kind::Symbol
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    candidate_binding_verified::Bool
    resolution_verified::Bool
    fidelity::Int
    status::Symbol
    evidence_tasks::Vector{String}
    evidence_hash::String
end

struct CompiledCandidateConservationV2
    design_id::String
    genome_physics_hash::String
    problem_hash::String
    term_evidence::Vector{ConservationTermEvidenceV2}
    authoritative_slot_count::Int
    required_slot_count::Int
    ledger::ConservationLedgerResultV1
    status::Symbol
    c2_support_authorized::Bool
    evidence_tasks::Vector{String}
    compilation_hash::String
end

function _is_plasma_control_volume_v2(region::PlasmaRegion)
    text = lowercase("$(region.kind) $(region.geometry_model)")
    return !any(token -> occursin(token, text),
        ("wall", "exhaust", "divertor", "end_expander", "outside", "boundary_only"))
end

function _conservation_slots_v2(quantity::String; internal_exchange::Bool = false)
    base = quantity == "current" ?
        ["charge_storage_rate", "imposed_current_source", "conductive_current_loss",
            "boundary_current_flux"] :
        quantity == "magnetic_flux" ?
        ["flux_storage_rate", "applied_emf_source", "resistive_emf_loss",
            "boundary_emf"] :
        ["storage_rate", "volumetric_source", "volumetric_loss", "boundary_flux"]
    internal_exchange && push!(base, "inter_species_exchange")
    return base
end

function _slot_side_v2(slot_id::String)
    occursin("storage_rate", slot_id) && return :storage_rate
    occursin("source", slot_id) && return :source
    occursin("loss", slot_id) && return :loss
    startswith(slot_id, "boundary_") && return :loss
    slot_id == "boundary_flux" && return :loss
    slot_id == "inter_species_exchange" && return :exchange
    throw(ArgumentError("unknown conservation slot $slot_id"))
end

function _requirement_id_v2(key::ConservationBalanceKeyV1, slot_id::String)
    return join((key.conserved_quantity, key.species, key.domain_id, slot_id), "|")
end

function _ir_term_audit_v2(executable::ExecutableGenomeV1)
    result = ConservationIRTermAuditV2[]
    issues = String[]
    valid_quantities = Set(keys(_CONSERVATION_UNITS_V1))
    for physics_module in executable.modules, term in physics_module.source_loss_terms
        invalid = sort!(String[q for q in term.conserved_quantities if
            !(q in valid_quantities)])
        gaps = String[]
        isempty(invalid) || append!(gaps,
            ["invalid_conserved_quantity:$q" for q in invalid])
        push!(gaps, "species_scope_not_declared")
        isempty(term.output_ids) && push!(gaps, "numeric_output_not_declared")
        term.kind == :none && push!(gaps, "structural_none_term_has_no_balance_value")
        status = isempty(invalid) ? :structural_only : :invalid_quantity
        push!(result, ConservationIRTermAuditV2(physics_module.id, term.id,
            term.kind, sort!(unique(copy(term.conserved_quantities))),
            sort!(unique(copy(term.domain_ids))), status, sort!(unique(gaps))))
        for gap in gaps
            push!(issues, "$(physics_module.id)/$(term.id):$gap")
        end
    end
    sort!(result; by = item -> (item.module_id, item.term_id))
    return result, sort!(unique(issues))
end

function _matching_ir_terms_v2(audit::Vector{ConservationIRTermAuditV2},
        key::ConservationBalanceKeyV1)
    return sort!(String[item.term_id for item in audit if
        item.status == :structural_only && key.conserved_quantity in
        item.conserved_quantities && key.domain_id in item.domain_ids])
end

function _balance_requirement_v2(key::ConservationBalanceKeyV1,
        kind::Symbol, audit::Vector{ConservationIRTermAuditV2};
        internal_exchange::Bool = false)
    slots = _conservation_slots_v2(key.conserved_quantity;
        internal_exchange = internal_exchange)
    declared = _matching_ir_terms_v2(audit, key)
    gaps = String[]
    isempty(declared) && push!(gaps, "no_matching_executable_ir_term")
    push!(gaps, "candidate_numeric_terms_missing")
    key.species != "electromagnetic_field" &&
        push!(gaps, "species_resolved_terms_missing")
    return ConservationBalanceRequirementV2(key, kind, slots, declared,
        sort!(unique(gaps)))
end

"Compile plasma and electromagnetic control-volume balances from executable IR."
function compile_conservation_problem_v2(executable::ExecutableGenomeV1)
    validation = validate_executable_genome_v1(executable)
    validation.valid || throw(ArgumentError(
        "cannot compile conservation from an invalid executable Genome"))
    genome = executable.base_genome
    plasma_domains = sort!(String[region.id for region in genome.plasma_regions if
        _is_plasma_control_volume_v2(region)])
    source_domains = sort!(getfield.(genome.field_sources, :id))
    isempty(plasma_domains) && throw(ArgumentError(
        "no plasma control volume can be derived from the Genome"))
    species = sort!(unique(_species_v1(genome.mission.fuel)))
    audit, issues = _ir_term_audit_v2(executable)
    balances = ConservationBalanceRequirementV2[]
    for domain in plasma_domains
        exchange_species = sort!(unique(vcat(species, ["electromagnetic_field"])))
        for species_id in species, quantity in ("particle", "mass", "energy", "momentum")
            key = ConservationBalanceKeyV1(quantity, species_id, domain,
                _CONSERVATION_UNITS_V1[quantity])
            push!(balances, _balance_requirement_v2(key, :plasma_volume, audit;
                internal_exchange = quantity in ("energy", "momentum") &&
                    length(exchange_species) >= 2))
        end
        for quantity in ("energy", "momentum", "magnetic_flux")
            key = ConservationBalanceKeyV1(quantity, "electromagnetic_field", domain,
                _CONSERVATION_UNITS_V1[quantity])
            push!(balances, _balance_requirement_v2(key, :plasma_volume, audit;
                internal_exchange = quantity in ("energy", "momentum") &&
                    length(exchange_species) >= 2))
        end
        current_key = ConservationBalanceKeyV1("current", "charge_continuity",
            domain, _CONSERVATION_UNITS_V1["current"])
        push!(balances, _balance_requirement_v2(current_key, :plasma_volume, audit))
    end
    for domain in source_domains
        for quantity in ("energy", "momentum", "current", "magnetic_flux")
            species_id = quantity == "current" ? "external_circuit" :
                "electromagnetic_field"
            key = ConservationBalanceKeyV1(quantity, species_id, domain,
                _CONSERVATION_UNITS_V1[quantity])
            push!(balances, _balance_requirement_v2(key, :field_source_volume, audit))
        end
    end
    sort!(balances; by = item -> _conservation_key_tuple_v1(item.key))
    tasks = String[]
    for balance in balances, slot in balance.required_slot_ids
        push!(tasks, "provide_conservation_term:" * _requirement_id_v2(balance.key, slot))
    end
    append!(tasks, ["repair_executable_ir:$issue" for issue in issues])
    required = sort!(collect(keys(_CONSERVATION_UNITS_V1)))
    core = Dict{String,Any}(
        "schema_version" => "2.0.0", "design_id" => genome.design_id,
        "genome_physics_hash" => genome.physics_hash,
        "executable_document_hash" => executable.document_hash,
        "plasma_control_volume_ids" => plasma_domains,
        "field_source_control_volume_ids" => source_domains,
        "species_ids" => species, "required_quantities" => required,
        "balance_keys" => [_conservation_key_to_dict_v1(item.key) for item in balances],
        "balance_slots" => [item.required_slot_ids for item in balances],
        "ir_term_audit" => [Dict{String,Any}("module_id" => item.module_id,
            "term_id" => item.term_id, "kind" => String(item.kind),
            "conserved_quantities" => item.conserved_quantities,
            "domain_ids" => item.domain_ids, "status" => String(item.status),
            "gap_ids" => item.gap_ids) for item in audit],
        "compiler_issues" => issues, "evidence_tasks" => sort!(unique(tasks)),
        "claim_ceiling" => "C0_conservation_problem_compiled_no_numeric_credit")
    return CompiledConservationProblemV2("2.0.0", genome.design_id,
        genome.physics_hash, executable.document_hash, plasma_domains, source_domains,
        species, required, balances, audit, issues, sort!(unique(tasks)),
        "C0_conservation_problem_compiled_no_numeric_credit", canonical_hash(core))
end

function conservation_ir_term_audit_to_dict_v2(item::ConservationIRTermAuditV2)
    return Dict{String,Any}("module_id" => item.module_id, "term_id" => item.term_id,
        "kind" => String(item.kind), "conserved_quantities" => item.conserved_quantities,
        "domain_ids" => item.domain_ids, "status" => String(item.status),
        "gap_ids" => item.gap_ids)
end

function conservation_balance_requirement_to_dict_v2(
        item::ConservationBalanceRequirementV2)
    return merge(_conservation_key_to_dict_v1(item.key), Dict{String,Any}(
        "control_volume_kind" => String(item.control_volume_kind),
        "required_slot_ids" => item.required_slot_ids,
        "declared_ir_term_ids" => item.declared_ir_term_ids,
        "structural_gap_ids" => item.structural_gap_ids))
end

function conservation_problem_to_dict_v2(item::CompiledConservationProblemV2)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "executable_document_hash" => item.executable_document_hash,
        "plasma_control_volume_ids" => item.plasma_control_volume_ids,
        "field_source_control_volume_ids" => item.field_source_control_volume_ids,
        "species_ids" => item.species_ids,
        "required_quantities" => item.required_quantities,
        "balances" => conservation_balance_requirement_to_dict_v2.(item.balances),
        "ir_term_audit" => conservation_ir_term_audit_to_dict_v2.(item.ir_term_audit),
        "compiler_issues" => item.compiler_issues,
        "evidence_tasks" => item.evidence_tasks,
        "claim_ceiling" => item.claim_ceiling, "problem_hash" => item.problem_hash,
        "promotion_authorized" => false)
end

function _find_conservation_requirement_v2(problem::CompiledConservationProblemV2,
        key::ConservationBalanceKeyV1)
    matches = filter(item -> _conservation_key_tuple_v1(item.key) ==
        _conservation_key_tuple_v1(key), problem.balances)
    length(matches) == 1 || throw(ArgumentError(
        "expected exactly one compiler-generated conservation balance"))
    return only(matches)
end

function compile_conservation_term_evidence_v2(problem::CompiledConservationProblemV2,
        key::ConservationBalanceKeyV1, slot_id::AbstractString;
        value::Union{Nothing,Real}, source_kind::Symbol,
        source_artifact_id::AbstractString, source_artifact_hash::AbstractString,
        source_result_hash::AbstractString, candidate_binding_verified::Bool,
        resolution_verified::Bool, fidelity::Integer)
    source_kind in _CONSERVATION_TERM_EVIDENCE_SOURCE_KINDS_V2 ||
        throw(ArgumentError("invalid conservation term evidence source kind"))
    fidelity >= 0 || throw(ArgumentError("conservation term fidelity must be non-negative"))
    requirement = _find_conservation_requirement_v2(problem, key)
    slot = String(slot_id)
    slot in requirement.required_slot_ids || throw(ArgumentError(
        "slot $slot is not required by the compiler-generated balance"))
    side = _slot_side_v2(slot)
    numeric = value === nothing ? nothing : Float64(value)
    numeric === nothing || isfinite(numeric) || throw(ArgumentError(
        "conservation term value must be finite or nothing"))
    numeric !== nothing && side in (:source, :loss) && numeric < 0 &&
        throw(ArgumentError("source/loss conservation evidence must be non-negative"))
    tasks = String[]
    numeric === nothing && push!(tasks, "compute_conservation_term:" *
        _requirement_id_v2(key, slot))
    candidate_binding_verified || push!(tasks, "verify_candidate_binding")
    resolution_verified || push!(tasks, "run_conservation_term_resolution_audit")
    fidelity < 2 && push!(tasks, "raise_conservation_term_fidelity_to:2")
    isempty(source_artifact_id) && push!(tasks, "provide_source_artifact_id")
    occursin(r"^[0-9a-f]{64}$", source_artifact_hash) ||
        push!(tasks, "provide_valid_source_artifact_hash")
    occursin(r"^[0-9a-f]{64}$", source_result_hash) ||
        push!(tasks, "provide_valid_source_result_hash")
    source_kind in (:manufactured, :structural_declaration) &&
        push!(tasks, "replace_nonphysical_conservation_source")
    provenance = !isempty(source_artifact_id) &&
        occursin(r"^[0-9a-f]{64}$", source_artifact_hash) &&
        occursin(r"^[0-9a-f]{64}$", source_result_hash)
    authorized = numeric !== nothing && candidate_binding_verified &&
        resolution_verified && fidelity >= 2 && provenance &&
        source_kind in (:candidate_solver, :measured)
    status = authorized ? :pass : :unknown
    core = Dict{String,Any}("schema_version" => "2.0.0",
        "design_id" => problem.design_id,
        "genome_physics_hash" => problem.genome_physics_hash,
        "balance_key" => _conservation_key_to_dict_v1(key), "slot_id" => slot,
        "side" => String(side), "value" => numeric,
        "source_kind" => String(source_kind),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "resolution_verified" => resolution_verified, "fidelity" => Int(fidelity),
        "status" => String(status), "evidence_tasks" => sort!(unique(tasks)))
    return ConservationTermEvidenceV2(problem.design_id,
        problem.genome_physics_hash, key, slot, side, numeric, source_kind,
        String(source_artifact_id), String(source_artifact_hash),
        String(source_result_hash), candidate_binding_verified,
        resolution_verified, Int(fidelity), status, sort!(unique(tasks)),
        canonical_hash(core))
end

function conservation_term_evidence_to_dict_v2(item::ConservationTermEvidenceV2)
    return merge(_conservation_key_to_dict_v1(item.balance_key), Dict{String,Any}(
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "slot_id" => item.slot_id, "side" => String(item.side),
        "value" => item.value, "source_kind" => String(item.source_kind),
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "resolution_verified" => item.resolution_verified,
        "fidelity" => item.fidelity, "status" => String(item.status),
        "evidence_tasks" => item.evidence_tasks,
        "evidence_hash" => item.evidence_hash))
end

function compile_candidate_conservation_v2(problem::CompiledConservationProblemV2,
        evidence::Vector{ConservationTermEvidenceV2};
        config::ConservationLedgerConfigV1 = ConservationLedgerConfigV1())
    by_id = Dict{String,ConservationTermEvidenceV2}()
    for item in evidence
        item.design_id == problem.design_id || throw(ArgumentError(
            "conservation term evidence design mismatch"))
        item.genome_physics_hash == problem.genome_physics_hash ||
            throw(ArgumentError("conservation term evidence Genome hash mismatch"))
        id = _requirement_id_v2(item.balance_key, item.slot_id)
        haskey(by_id, id) && throw(ArgumentError(
            "duplicate conservation evidence for compiler slot $id"))
        _find_conservation_requirement_v2(problem, item.balance_key)
        by_id[id] = item
    end
    declarations = ConservationBalanceDeclarationV1[]
    terms = ConservationTermV1[]
    exchange_groups = Dict{Tuple{String,String},Vector{String}}()
    required_slot_count = 0
    authoritative = 0
    tasks = String[]
    for requirement in problem.balances
        ids = String[]
        for slot in requirement.required_slot_ids
            id = _requirement_id_v2(requirement.key, slot)
            push!(ids, id)
            required_slot_count += 1
            if haskey(by_id, id) && by_id[id].status == :pass
                item = by_id[id]
                authoritative += 1
                group = item.side == :exchange ?
                    "$(requirement.key.conserved_quantity):$(requirement.key.domain_id):inter_species_exchange" : nothing
                push!(terms, ConservationTermV1(id, requirement.key, item.side,
                    something(item.value), item.evidence_hash;
                    exchange_group_id = group))
                if group !== nothing
                    push!(get!(exchange_groups,
                        (requirement.key.conserved_quantity, requirement.key.domain_id),
                        String[]), requirement.key.species)
                end
            else
                push!(tasks, "provide_authoritative_conservation_term:$id")
                haskey(by_id, id) && append!(tasks, by_id[id].evidence_tasks)
            end
        end
        push!(declarations, ConservationBalanceDeclarationV1(requirement.key, ids;
            term_inventory_complete = true))
    end
    exchanges = InternalExchangeDeclarationV1[]
    for ((quantity, domain), species_ids) in exchange_groups
        expected = sort!(String[requirement.key.species for requirement in
            problem.balances if requirement.key.conserved_quantity == quantity &&
            requirement.key.domain_id == domain &&
            "inter_species_exchange" in requirement.required_slot_ids])
        # Declare the complete expected group even when some evidence is absent.
        length(expected) >= 2 && push!(exchanges, InternalExchangeDeclarationV1(
            "$quantity:$domain:inter_species_exchange", quantity, domain,
            _CONSERVATION_UNITS_V1[quantity], expected))
    end
    # Missing all exchange evidence still needs a declaration so incompleteness is explicit.
    for quantity in ("energy", "momentum"), domain in problem.plasma_control_volume_ids
        key = (quantity, domain)
        any(item -> item.conserved_quantity == quantity && item.domain_id == domain,
            exchanges) && continue
        expected = sort!(String[requirement.key.species for requirement in
            problem.balances if requirement.key.conserved_quantity == quantity &&
            requirement.key.domain_id == domain &&
            "inter_species_exchange" in requirement.required_slot_ids])
        length(expected) >= 2 && push!(exchanges, InternalExchangeDeclarationV1(
            "$quantity:$domain:inter_species_exchange", quantity, domain,
            _CONSERVATION_UNITS_V1[quantity], expected))
    end
    physical_sources = !isempty(evidence) && all(item ->
        item.source_kind in (:candidate_solver, :measured), evidence)
    all_bound = physical_sources && all(item -> item.candidate_binding_verified, evidence)
    ledger = compile_conservation_ledger_v1(design_id = problem.design_id,
        genome_physics_hash = problem.genome_physics_hash,
        declarations = declarations, terms = terms,
        internal_exchange_declarations = exchanges,
        covered_domain_ids = sort!(unique(vcat(problem.plasma_control_volume_ids,
            problem.field_source_control_volume_ids))),
        required_quantities = problem.required_quantities,
        source_kind = physical_sources ? :candidate_bound_solver_accounting :
            :manufactured_control,
        candidate_binding_verified = all_bound, config = config)
    append!(tasks, ledger.evidence_tasks)
    core = Dict{String,Any}("schema_version" => "2.0.0",
        "design_id" => problem.design_id,
        "genome_physics_hash" => problem.genome_physics_hash,
        "problem_hash" => problem.problem_hash,
        "term_evidence_hashes" => sort!(String[item.evidence_hash for item in evidence]),
        "authoritative_slot_count" => authoritative,
        "required_slot_count" => required_slot_count,
        "ledger_hash" => ledger.ledger_hash, "status" => String(ledger.status),
        "c2_support_authorized" => ledger.c2_support_authorized,
        "evidence_tasks" => sort!(unique(tasks)))
    return CompiledCandidateConservationV2(problem.design_id,
        problem.genome_physics_hash, problem.problem_hash,
        sort!(copy(evidence); by = item -> _requirement_id_v2(
            item.balance_key, item.slot_id)), authoritative, required_slot_count,
        ledger, ledger.status, ledger.c2_support_authorized,
        sort!(unique(tasks)), canonical_hash(core))
end

function compiled_candidate_conservation_to_dict_v2(
        item::CompiledCandidateConservationV2)
    return Dict{String,Any}("design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "problem_hash" => item.problem_hash,
        "term_evidence" => conservation_term_evidence_to_dict_v2.(item.term_evidence),
        "authoritative_slot_count" => item.authoritative_slot_count,
        "required_slot_count" => item.required_slot_count,
        "ledger" => conservation_ledger_to_dict_v1(item.ledger),
        "status" => String(item.status),
        "c2_support_authorized" => item.c2_support_authorized,
        "evidence_tasks" => item.evidence_tasks,
        "compilation_hash" => item.compilation_hash,
        "promotion_authorized" => false)
end
