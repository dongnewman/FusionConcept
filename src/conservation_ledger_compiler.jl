const _CONSERVATION_TERM_SIDES_V1 = Set((:storage_rate, :source, :loss, :exchange))
const _CONSERVATION_SOURCE_KINDS_V1 = Set((
    :manufactured_control, :candidate_bound_solver_accounting))
const _CONSERVATION_UNITS_V1 = Dict(
    "particle" => "s^-1",
    "mass" => "kg s^-1",
    "energy" => "W",
    "momentum" => "N",
    "current" => "A",
    "magnetic_flux" => "V")

struct ConservationBalanceKeyV1
    conserved_quantity::String
    species::String
    domain_id::String
    unit::String

    function ConservationBalanceKeyV1(conserved_quantity::AbstractString,
            species::AbstractString, domain_id::AbstractString,
            unit::AbstractString)
        quantity = String(conserved_quantity)
        haskey(_CONSERVATION_UNITS_V1, quantity) || throw(ArgumentError(
            "unsupported conserved quantity: $quantity"))
        String(unit) == _CONSERVATION_UNITS_V1[quantity] || throw(ArgumentError(
            "unit $(unit) is invalid for $quantity; expected $(_CONSERVATION_UNITS_V1[quantity])"))
        !isempty(species) && !isempty(domain_id) || throw(ArgumentError(
            "conservation species and domain must be nonempty"))
        return new(quantity, String(species), String(domain_id), String(unit))
    end
end

struct ConservationBalanceDeclarationV1
    key::ConservationBalanceKeyV1
    required_term_ids::Vector{String}
    term_inventory_complete::Bool

    function ConservationBalanceDeclarationV1(key::ConservationBalanceKeyV1,
            required_term_ids; term_inventory_complete::Bool)
        ids = sort!(String.(collect(required_term_ids)))
        !isempty(ids) && length(ids) == length(unique(ids)) || throw(ArgumentError(
            "each balance needs unique required term IDs"))
        return new(key, ids, term_inventory_complete)
    end
end

struct ConservationTermV1
    term_id::String
    key::ConservationBalanceKeyV1
    side::Symbol
    value::Float64
    evidence_hash::String
    exchange_group_id::Union{Nothing,String}

    function ConservationTermV1(term_id::AbstractString,
            key::ConservationBalanceKeyV1, side::Symbol, value::Real,
            evidence_hash::AbstractString;
            exchange_group_id::Union{Nothing,AbstractString} = nothing)
        side in _CONSERVATION_TERM_SIDES_V1 || throw(ArgumentError(
            "unsupported conservation term side: $side"))
        isfinite(value) || throw(ArgumentError("conservation terms must be finite"))
        side in (:source, :loss) && value < 0 && throw(ArgumentError(
            "source/loss magnitudes must be non-negative"))
        occursin(r"^[0-9a-f]{64}$", evidence_hash) || throw(ArgumentError(
            "conservation term evidence hash is malformed"))
        group = exchange_group_id === nothing ? nothing : String(exchange_group_id)
        (side == :exchange) == (group !== nothing) || throw(ArgumentError(
            "only exchange terms must declare an exchange group"))
        !isempty(term_id) || throw(ArgumentError("conservation term ID is empty"))
        return new(String(term_id), key, side, Float64(value),
            String(evidence_hash), group)
    end
end

struct InternalExchangeDeclarationV1
    group_id::String
    conserved_quantity::String
    domain_id::String
    unit::String
    required_species::Vector{String}

    function InternalExchangeDeclarationV1(group_id::AbstractString,
            conserved_quantity::AbstractString, domain_id::AbstractString,
            unit::AbstractString, required_species)
        quantity = String(conserved_quantity)
        haskey(_CONSERVATION_UNITS_V1, quantity) || throw(ArgumentError(
            "unsupported exchange quantity: $quantity"))
        String(unit) == _CONSERVATION_UNITS_V1[quantity] || throw(ArgumentError(
            "internal exchange unit is invalid for $quantity"))
        species = sort!(String.(collect(required_species)))
        length(species) >= 2 && length(species) == length(unique(species)) ||
            throw(ArgumentError("internal exchange needs at least two unique species"))
        !isempty(group_id) && !isempty(domain_id) || throw(ArgumentError(
            "internal exchange group/domain must be nonempty"))
        return new(String(group_id), quantity, String(domain_id), String(unit), species)
    end
end

struct ConservationLedgerConfigV1
    maximum_relative_residual::Float64
    absolute_residual_limits::Dict{String,Float64}
    minimum_activity_scales::Dict{String,Float64}

    function ConservationLedgerConfigV1(;
            maximum_relative_residual::Real = 1.0e-6,
            absolute_residual_limits = Dict(
                "particle" => 0.0, "mass" => 0.0, "energy" => 0.0,
                "momentum" => 0.0, "current" => 0.0,
                "magnetic_flux" => 0.0),
            minimum_activity_scales = Dict(
                "particle" => 1.0, "mass" => 1.0, "energy" => 1.0,
                "momentum" => 1.0, "current" => 1.0,
                "magnetic_flux" => 1.0))
        maximum_relative_residual >= 0 && isfinite(maximum_relative_residual) ||
            throw(ArgumentError("relative conservation tolerance must be finite and non-negative"))
        absolute = Dict{String,Float64}(String(key) => Float64(value)
            for (key, value) in pairs(absolute_residual_limits))
        scales = Dict{String,Float64}(String(key) => Float64(value)
            for (key, value) in pairs(minimum_activity_scales))
        Set(keys(absolute)) == Set(keys(_CONSERVATION_UNITS_V1)) &&
            Set(keys(scales)) == Set(keys(_CONSERVATION_UNITS_V1)) ||
            throw(ArgumentError("conservation tolerances must cover every quantity"))
        all(isfinite(value) && value >= 0 for value in values(absolute)) &&
            all(isfinite(value) && value > 0 for value in values(scales)) ||
            throw(ArgumentError("conservation absolute limits/scales are invalid"))
        return new(Float64(maximum_relative_residual), absolute, scales)
    end
end

struct ConservationBalanceResultV1
    key::ConservationBalanceKeyV1
    storage_rate::Union{Nothing,Float64}
    source_total::Float64
    loss_total::Float64
    exchange_total::Float64
    signed_residual::Union{Nothing,Float64}
    normalized_residual::Union{Nothing,Float64}
    missing_term_ids::Vector{String}
    status::Symbol
end

struct InternalExchangeResultV1
    group_id::String
    conserved_quantity::String
    domain_id::String
    unit::String
    represented_species::Vector{String}
    missing_species::Vector{String}
    signed_sum::Union{Nothing,Float64}
    normalized_residual::Union{Nothing,Float64}
    status::Symbol
end

struct ConservationLedgerResultV1
    schema_version::String
    design_id::String
    genome_physics_hash::String
    source_kind::Symbol
    candidate_binding_verified::Bool
    evidence_hashes::Vector{String}
    covered_domain_ids::Vector{String}
    required_quantities::Vector{String}
    balances::Vector{ConservationBalanceResultV1}
    internal_exchanges::Vector{InternalExchangeResultV1}
    checks::Dict{String,Bool}
    status::Symbol
    c2_support_authorized::Bool
    evidence_tasks::Vector{String}
    ledger_hash::String
end

_conservation_key_tuple_v1(key::ConservationBalanceKeyV1) =
    (key.conserved_quantity, key.species, key.domain_id, key.unit)

function _conservation_key_to_dict_v1(key::ConservationBalanceKeyV1)
    return Dict{String,Any}(
        "conserved_quantity" => key.conserved_quantity,
        "species" => key.species,
        "domain_id" => key.domain_id,
        "unit" => key.unit)
end

function _balance_result_to_dict_v1(item::ConservationBalanceResultV1)
    return merge(_conservation_key_to_dict_v1(item.key), Dict{String,Any}(
        "storage_rate" => item.storage_rate,
        "source_total" => item.source_total,
        "loss_total" => item.loss_total,
        "exchange_total" => item.exchange_total,
        "signed_residual" => item.signed_residual,
        "normalized_residual" => item.normalized_residual,
        "missing_term_ids" => item.missing_term_ids,
        "status" => String(item.status)))
end

function _exchange_result_to_dict_v1(item::InternalExchangeResultV1)
    return Dict{String,Any}(
        "group_id" => item.group_id,
        "conserved_quantity" => item.conserved_quantity,
        "domain_id" => item.domain_id,
        "unit" => item.unit,
        "represented_species" => item.represented_species,
        "missing_species" => item.missing_species,
        "signed_sum" => item.signed_sum,
        "normalized_residual" => item.normalized_residual,
        "status" => String(item.status))
end

function _conservation_ledger_payload_v1(item::ConservationLedgerResultV1)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "source_kind" => String(item.source_kind),
        "candidate_binding_verified" => item.candidate_binding_verified,
        "evidence_hashes" => item.evidence_hashes,
        "covered_domain_ids" => item.covered_domain_ids,
        "required_quantities" => item.required_quantities,
        "balances" => [_balance_result_to_dict_v1(balance) for balance in item.balances],
        "internal_exchanges" => [_exchange_result_to_dict_v1(exchange)
            for exchange in item.internal_exchanges],
        "checks" => item.checks,
        "status" => String(item.status),
        "c2_support_authorized" => item.c2_support_authorized,
        "evidence_tasks" => item.evidence_tasks)
end

function compile_conservation_ledger_v1(; design_id::AbstractString,
        genome_physics_hash::AbstractString, declarations,
        terms, internal_exchange_declarations = InternalExchangeDeclarationV1[],
        covered_domain_ids, required_quantities = collect(keys(_CONSERVATION_UNITS_V1)),
        source_kind::Symbol, candidate_binding_verified::Bool,
        config::ConservationLedgerConfigV1 = ConservationLedgerConfigV1())
    source_kind in _CONSERVATION_SOURCE_KINDS_V1 || throw(ArgumentError(
        "unknown conservation source kind: $source_kind"))
    source_kind == :manufactured_control && candidate_binding_verified &&
        throw(ArgumentError("manufactured conservation controls cannot claim binding"))
    occursin(r"^[0-9a-f]{64}$", genome_physics_hash) || throw(ArgumentError(
        "conservation Genome physics hash is malformed"))
    declaration_items = ConservationBalanceDeclarationV1[declarations...]
    term_items = ConservationTermV1[terms...]
    exchange_items = InternalExchangeDeclarationV1[internal_exchange_declarations...]
    !isempty(declaration_items) || throw(ArgumentError(
        "conservation ledger needs at least one balance declaration"))
    declaration_keys = [_conservation_key_tuple_v1(item.key) for item in declaration_items]
    length(declaration_keys) == length(unique(declaration_keys)) || throw(ArgumentError(
        "duplicate conservation balance declaration"))
    term_ids = getfield.(term_items, :term_id)
    length(term_ids) == length(unique(term_ids)) || throw(ArgumentError(
        "duplicate conservation term ID would permit double counting"))
    declared_key_set = Set(declaration_keys)
    all(_conservation_key_tuple_v1(term.key) in declared_key_set for term in term_items) ||
        throw(ArgumentError("conservation term has no declared balance"))
    group_ids = getfield.(exchange_items, :group_id)
    length(group_ids) == length(unique(group_ids)) || throw(ArgumentError(
        "duplicate internal exchange group declaration"))
    declared_groups = Set(group_ids)
    all(term.exchange_group_id === nothing || term.exchange_group_id in declared_groups
        for term in term_items) || throw(ArgumentError(
        "exchange term references an undeclared exchange group"))
    domains = sort!(unique(String.(collect(covered_domain_ids))))
    !isempty(domains) || throw(ArgumentError("conservation domain coverage is empty"))
    all(item.key.domain_id in domains for item in declaration_items) ||
        throw(ArgumentError("declared balance lies outside covered domains"))
    required = sort!(unique(String.(collect(required_quantities))))
    all(haskey(_CONSERVATION_UNITS_V1, quantity) for quantity in required) ||
        throw(ArgumentError("required conservation quantity is unsupported"))

    balances = ConservationBalanceResultV1[]
    for declaration in declaration_items
        matching = filter(term -> _conservation_key_tuple_v1(term.key) ==
            _conservation_key_tuple_v1(declaration.key), term_items)
        present_ids = Set(getfield.(matching, :term_id))
        missing_ids = sort!(String[id for id in declaration.required_term_ids
            if !(id in present_ids)])
        storage_terms = filter(term -> term.side == :storage_rate, matching)
        sources = filter(term -> term.side == :source, matching)
        losses = filter(term -> term.side == :loss, matching)
        exchanges = filter(term -> term.side == :exchange, matching)
        structural_complete = declaration.term_inventory_complete &&
            isempty(missing_ids) && length(storage_terms) == 1
        storage = length(storage_terms) == 1 ? only(storage_terms).value : nothing
        source_total = sum(term.value for term in sources; init = 0.0)
        loss_total = sum(term.value for term in losses; init = 0.0)
        exchange_total = sum(term.value for term in exchanges; init = 0.0)
        residual = structural_complete ? storage - source_total + loss_total -
            exchange_total : nothing
        activity = structural_complete ? max(config.minimum_activity_scales[
            declaration.key.conserved_quantity], abs(storage), source_total +
            loss_total + sum(abs(term.value) for term in exchanges; init = 0.0)) : 0.0
        normalized = structural_complete ? abs(residual) / activity : nothing
        tolerance = config.absolute_residual_limits[
            declaration.key.conserved_quantity] + config.maximum_relative_residual * activity
        status = !structural_complete ? :unknown : abs(residual) <= tolerance ?
            :pass : :fail
        push!(balances, ConservationBalanceResultV1(declaration.key, storage,
            source_total, loss_total, exchange_total, residual, normalized,
            missing_ids, status))
    end

    exchange_results = InternalExchangeResultV1[]
    for declaration in exchange_items
        matching = filter(term -> term.exchange_group_id == declaration.group_id,
            term_items)
        compatible = all(term.key.conserved_quantity == declaration.conserved_quantity &&
            term.key.domain_id == declaration.domain_id && term.key.unit == declaration.unit
            for term in matching)
        represented = sort!(unique(getfield.(getfield.(matching, :key), :species)))
        missing = sort!(String[species for species in declaration.required_species
            if !(species in represented)])
        exact_species = represented == declaration.required_species
        structurally_complete = compatible && exact_species && isempty(missing) &&
            length(matching) == length(declaration.required_species)
        signed_sum = structurally_complete ? sum(term.value for term in matching) : nothing
        activity = structurally_complete ? max(config.minimum_activity_scales[
            declaration.conserved_quantity], sum(abs(term.value) for term in matching)) : 0.0
        normalized = structurally_complete ? abs(signed_sum) / activity : nothing
        tolerance = config.absolute_residual_limits[declaration.conserved_quantity] +
            config.maximum_relative_residual * activity
        status = !structurally_complete ? :unknown : abs(signed_sum) <= tolerance ?
            :pass : :fail
        push!(exchange_results, InternalExchangeResultV1(declaration.group_id,
            declaration.conserved_quantity, declaration.domain_id, declaration.unit,
            represented, missing, signed_sum, normalized, status))
    end
    represented_quantities = Set(balance.key.conserved_quantity for balance in balances)
    checks = Dict{String,Bool}(
        "required_quantities_represented" => all(quantity in represented_quantities
            for quantity in required),
        "covered_domains_represented" => all(domain in Set(balance.key.domain_id
            for balance in balances) for domain in domains),
        "term_inventories_complete" => all(declaration.term_inventory_complete
            for declaration in declaration_items),
        "all_required_terms_present" => all(isempty(balance.missing_term_ids)
            for balance in balances),
        "exactly_one_storage_rate_per_balance" => all(balance.storage_rate !== nothing
            for balance in balances),
        "all_balance_residuals_pass" => all(balance.status == :pass for balance in balances),
        "all_internal_exchanges_cancel" => all(exchange.status == :pass
            for exchange in exchange_results))
    unknown = any(balance.status == :unknown for balance in balances) ||
        any(exchange.status == :unknown for exchange in exchange_results) ||
        !all(checks[id] for id in ("required_quantities_represented",
            "covered_domains_represented", "term_inventories_complete",
            "all_required_terms_present", "exactly_one_storage_rate_per_balance"))
    failed = any(balance.status == :fail for balance in balances) ||
        any(exchange.status == :fail for exchange in exchange_results)
    status = failed ? :fail : unknown ? :unknown : :pass
    authorized = status == :pass && source_kind == :candidate_bound_solver_accounting &&
        candidate_binding_verified
    tasks = String[]
    for (id, passed) in checks
        passed || push!(tasks, "repair conservation ledger check: $id")
    end
    for balance in balances
        balance.status == :unknown && push!(tasks,
            "complete $(balance.key.conserved_quantity)/$(balance.key.species)/$(balance.key.domain_id) term inventory")
        balance.status == :fail && push!(tasks,
            "close $(balance.key.conserved_quantity)/$(balance.key.species)/$(balance.key.domain_id) residual")
    end
    for exchange in exchange_results
        exchange.status == :unknown && push!(tasks,
            "complete internal exchange group $(exchange.group_id)")
        exchange.status == :fail && push!(tasks,
            "close internal exchange group $(exchange.group_id)")
    end
    placeholder = ConservationLedgerResultV1("1.0.0", String(design_id),
        String(genome_physics_hash), source_kind, candidate_binding_verified,
        sort!(unique(getfield.(term_items, :evidence_hash))), domains, required,
        balances, exchange_results, checks, status, authorized,
        sort!(unique(tasks)), "")
    return ConservationLedgerResultV1(placeholder.schema_version,
        placeholder.design_id, placeholder.genome_physics_hash,
        placeholder.source_kind, placeholder.candidate_binding_verified,
        placeholder.evidence_hashes, placeholder.covered_domain_ids,
        placeholder.required_quantities, placeholder.balances,
        placeholder.internal_exchanges, placeholder.checks, placeholder.status,
        placeholder.c2_support_authorized,
        placeholder.evidence_tasks,
        canonical_hash(_conservation_ledger_payload_v1(placeholder)))
end

function conservation_ledger_to_dict_v1(item::ConservationLedgerResultV1)
    payload = _conservation_ledger_payload_v1(item)
    payload["ledger_hash"] = item.ledger_hash
    payload["promotion_authorized"] = false
    return payload
end

"Candidate-bound conservation support; it cannot alone establish complete C2."
function conservation_ledger_evidence_bundle_v1(item::ConservationLedgerResultV1;
        fidelity::Integer = 2)
    authorized = item.c2_support_authorized
    status = item.status == :fail ? :fail : authorized ? :pass : :unknown
    warnings = authorized ? String[
        "conservation support does not establish equilibrium, stability, transport, magnet engineering, power/exhaust closure, or promotion"] :
        vcat(["conservation ledger lacks candidate-bound C2 support authority"],
            item.evidence_tasks)
    run_hash = canonical_hash(Dict{String,Any}(
        "evaluator" => "species_conservation_ledger_v1",
        "ledger_hash" => item.ledger_hash, "status" => String(status)))
    residuals = Dict{String,Float64}()
    for balance in item.balances
        balance.normalized_residual === nothing || (residuals[
            "$(balance.key.conserved_quantity):$(balance.key.species):$(balance.key.domain_id)"] =
            balance.normalized_residual)
    end
    metric = MetricResult("conservation_residuals_passed",
        authorized ? true : status == :fail ? false : nothing;
        fidelity = Int(fidelity), status = status,
        applicability = "Integrated candidate control volumes with explicit per-quantity, per-species, per-domain storage, source, loss, exchange, units, term completeness, and internal-exchange cancellation.",
        constraints_checked = sort!(collect(keys(item.checks))),
        solver_name = "species_conservation_ledger_v1", solver_version = "1.0.0",
        input_hash = item.genome_physics_hash, run_hash = run_hash,
        source_basis = item.evidence_hashes,
        warnings = warnings, residuals = residuals)
    bundle_hash = canonical_hash(Dict{String,Any}(
        "metric_run_hash" => run_hash, "ledger_hash" => item.ledger_hash))
    return EvaluationBundle("species_conservation_ledger_v1", item.design_id,
        "topology_independent", Int(fidelity), status, [metric], warnings,
        item.genome_physics_hash, bundle_hash,
        authorized ? "C2_support_species_conservation_only" :
            status == :fail ? "C2_conservation_hard_fail" :
            "C0_conservation_unknown")
end
