const _EVIDENCE_PROVENANCES = Set([
    "measured",
    "inferred",
    "model_calibrated",
    "searched_hypothesis",
    "no_direct_measurement",
])
const _EVIDENCE_VALUE_KINDS = Set([
    "point",
    "range",
    "lower_bound",
    "upper_bound",
    "qualitative",
    "missing",
])
const _EVIDENCE_VERIFICATION_STATUSES = Set([
    "metadata_only",
    "title_abstract",
    "catalog_summary",
    "full_text_verified",
])
const _EVIDENCE_UNCERTAINTY_KINDS = Set([
    "reported_range",
    "reported_lower_bound",
    "reported_upper_bound",
    "model_range",
    "qualitative",
    "not_reported",
    "missing_evidence",
])

struct QuantitativeEvidenceEntry
    id::String
    quantity_name::String
    families::Set{String}
    gate_ids::Vector{String}
    source_ids::Vector{String}
    evidence_provenance::String
    value_kind::String
    unit::Union{Nothing,String}
    nominal_value::Union{Nothing,Float64}
    lower_bound::Union{Nothing,Float64}
    upper_bound::Union{Nothing,Float64}
    qualitative_value::Union{Nothing,String}
    operating_condition::String
    definition::String
    location::String
    verification_status::String
    transferability::String
    claim_boundary::String
    reported_text::String
    promotion_credit::Bool
    uncertainty_kind::String
    uncertainty_description::String
end

struct CitationCorrection
    source_id::String
    legacy_doi::String
    corrected_doi::String
    reason::String
end

struct QuantitativeEvidenceTable
    schema_version::String
    catalog_version::String
    created_on::String
    purpose::String
    base_catalogs::Vector{String}
    citation_corrections::Vector{CitationCorrection}
    entries::Vector{QuantitativeEvidenceEntry}
end

function _optional_evidence_number(raw, key::String, context::String)
    haskey(raw, key) || return nothing
    value = raw[key]
    value === nothing && return nothing
    value isa Real || throw(ArgumentError("$context.$key must be numeric or null"))
    result = Float64(value)
    isfinite(result) || throw(ArgumentError("$context.$key must be finite"))
    return result
end

function _optional_evidence_string(raw, key::String, context::String)
    haskey(raw, key) || return nothing
    value = raw[key]
    value === nothing && return nothing
    value isa AbstractString || throw(ArgumentError("$context.$key must be a string or null"))
    result = String(value)
    isempty(result) && throw(ArgumentError("$context.$key must not be empty"))
    return result
end

function _evidence_entry(raw, index::Int)
    context = "evidence_entries[$index]"
    raw isa AbstractDict || throw(ArgumentError("$context must be an object"))
    data = _plain_json(raw)
    id = String(_required(data, "id", context))
    quantity_name = String(_required(data, "quantity_name", context))
    families = Set(_strings(_required(data, "family", context)))
    gate_ids = sort!(unique(_strings(_required(data, "gate_ids", context))))
    source_ids = sort!(unique(_strings(_required(data, "source_ids", context))))
    provenance = String(_required(data, "evidence_provenance", context))
    value_kind = String(_required(data, "value_kind", context))
    unit = _optional_evidence_string(data, "unit", context)
    nominal = _optional_evidence_number(data, "nominal_value", context)
    lower = _optional_evidence_number(data, "lower_bound", context)
    upper = _optional_evidence_number(data, "upper_bound", context)
    qualitative = _optional_evidence_string(data, "qualitative_value", context)
    condition = String(_required(data, "operating_condition", context))
    definition = String(_required(data, "definition", context))
    location = String(_required(data, "location", context))
    verification = String(_required(data, "verification_status", context))
    transferability = String(_required(data, "transferability", context))
    claim_boundary = String(_required(data, "claim_boundary", context))
    reported_text = String(_required(data, "reported_text", context))
    promotion_credit = _required(data, "promotion_credit", context)
    promotion_credit isa Bool ||
        throw(ArgumentError("$context.promotion_credit must be boolean"))
    uncertainty_raw = _required(data, "uncertainty", context)
    uncertainty_raw isa AbstractDict ||
        throw(ArgumentError("$context.uncertainty must be an object"))
    uncertainty_kind = String(_required(uncertainty_raw, "kind", "$context.uncertainty"))
    uncertainty_description =
        String(_required(uncertainty_raw, "description", "$context.uncertainty"))
    return QuantitativeEvidenceEntry(
        id, quantity_name, families, gate_ids, source_ids, provenance, value_kind,
        unit, nominal, lower, upper, qualitative, condition, definition, location,
        verification, transferability, claim_boundary, reported_text,
        promotion_credit, uncertainty_kind, uncertainty_description,
    )
end

function _citation_correction(raw, index::Int)
    context = "citation_corrections[$index]"
    raw isa AbstractDict || throw(ArgumentError("$context must be an object"))
    data = _plain_json(raw)
    return CitationCorrection(
        String(_required(data, "source_id", context)),
        String(_required(data, "legacy_doi", context)),
        String(_required(data, "corrected_doi", context)),
        String(_required(data, "reason", context)),
    )
end

function _quantitative_evidence_table(data)
    raw = _plain_json(data)
    corrections = CitationCorrection[
        _citation_correction(item, index)
        for (index, item) in enumerate(_required(raw, "citation_corrections",
            "quantitative evidence table"))
    ]
    entries = QuantitativeEvidenceEntry[
        _evidence_entry(item, index)
        for (index, item) in enumerate(_required(raw, "evidence_entries",
            "quantitative evidence table"))
    ]
    return QuantitativeEvidenceTable(
        String(_required(raw, "schema_version", "quantitative evidence table")),
        String(_required(raw, "catalog_version", "quantitative evidence table")),
        String(_required(raw, "created_on", "quantitative evidence table")),
        String(get(raw, "purpose", "")),
        _strings(_required(raw, "base_catalogs", "quantitative evidence table")),
        corrections, entries,
    )
end

function _evidence_value_errors(entry::QuantitativeEvidenceEntry)
    errors = String[]
    if entry.value_kind == "point"
        entry.nominal_value === nothing &&
            push!(errors, "point entry $(entry.id) requires nominal_value")
        entry.lower_bound === nothing ||
            push!(errors, "point entry $(entry.id) must have null lower_bound")
        entry.upper_bound === nothing ||
            push!(errors, "point entry $(entry.id) must have null upper_bound")
        entry.qualitative_value === nothing ||
            push!(errors, "point entry $(entry.id) must have null qualitative_value")
    elseif entry.value_kind == "range"
        entry.lower_bound === nothing &&
            push!(errors, "range entry $(entry.id) requires lower_bound")
        entry.upper_bound === nothing &&
            push!(errors, "range entry $(entry.id) requires upper_bound")
        entry.lower_bound !== nothing && entry.upper_bound !== nothing &&
            entry.lower_bound > entry.upper_bound &&
            push!(errors, "range entry $(entry.id) has lower_bound > upper_bound")
        entry.qualitative_value === nothing ||
            push!(errors, "range entry $(entry.id) must have null qualitative_value")
    elseif entry.value_kind == "lower_bound"
        entry.lower_bound === nothing &&
            push!(errors, "lower_bound entry $(entry.id) requires lower_bound")
        entry.upper_bound === nothing ||
            push!(errors, "lower_bound entry $(entry.id) must have null upper_bound")
        entry.qualitative_value === nothing ||
            push!(errors, "lower_bound entry $(entry.id) must have null qualitative_value")
    elseif entry.value_kind == "upper_bound"
        entry.upper_bound === nothing &&
            push!(errors, "upper_bound entry $(entry.id) requires upper_bound")
        entry.lower_bound === nothing ||
            push!(errors, "upper_bound entry $(entry.id) must have null lower_bound")
        entry.qualitative_value === nothing ||
            push!(errors, "upper_bound entry $(entry.id) must have null qualitative_value")
    elseif entry.value_kind == "qualitative"
        entry.nominal_value === nothing ||
            push!(errors, "qualitative entry $(entry.id) must have null nominal_value")
        entry.lower_bound === nothing ||
            push!(errors, "qualitative entry $(entry.id) must have null lower_bound")
        entry.upper_bound === nothing ||
            push!(errors, "qualitative entry $(entry.id) must have null upper_bound")
        entry.qualitative_value === nothing &&
            push!(errors, "qualitative entry $(entry.id) requires qualitative_value")
    elseif entry.value_kind == "missing"
        all(value === nothing for value in
            (entry.unit, entry.nominal_value, entry.lower_bound,
                entry.upper_bound, entry.qualitative_value)) ||
            push!(errors, "missing entry $(entry.id) must have null numeric and qualitative fields")
        entry.evidence_provenance == "no_direct_measurement" ||
            push!(errors, "missing entry $(entry.id) requires no_direct_measurement provenance")
        entry.uncertainty_kind == "missing_evidence" ||
            push!(errors, "missing entry $(entry.id) requires missing_evidence uncertainty")
    else
        push!(errors, "unknown value_kind for entry $(entry.id): $(entry.value_kind)")
    end
    return errors
end

"Validate quantitative-evidence records and their source cross references."
function validate_quantitative_evidence_table(data;
        known_source_ids::Set{String} = Set{String}())
    raw = _plain_json(data)
    errors = String[]
    warnings = String[]
    required = [
        "schema_version", "catalog_version", "created_on", "base_catalogs",
        "citation_corrections", "evidence_entries",
    ]
    for key in required
        haskey(raw, key) || push!(errors, "missing required field '$key'")
    end
    get(raw, "schema_version", nothing) == "1.0.0" ||
        push!(errors, "unsupported quantitative evidence schema_version")
    haskey(raw, "evidence_entries") && raw["evidence_entries"] isa AbstractVector &&
        isempty(raw["evidence_entries"]) &&
        push!(errors, "evidence_entries must not be empty")

    entries_raw = get(raw, "evidence_entries", Any[])
    corrections_raw = get(raw, "citation_corrections", Any[])
    entries = QuantitativeEvidenceEntry[]
    corrections = CitationCorrection[]
    for (index, item) in enumerate(entries_raw)
        entry = _evidence_entry(item, index)
        push!(entries, entry)
    end
    for (index, item) in enumerate(corrections_raw)
        push!(corrections, _citation_correction(item, index))
    end

    duplicate_ids = sort!(String[entry.id for entry in entries
        if count(item -> item.id == entry.id, entries) > 1] |> unique)
    isempty(duplicate_ids) ||
        push!(errors, "duplicate evidence entry IDs: $(join(duplicate_ids, ", "))")

    correction_ids = [correction.source_id for correction in corrections]
    duplicate_corrections = sort!(String[id for id in unique(correction_ids)
        if count(==(id), correction_ids) > 1])
    isempty(duplicate_corrections) ||
        push!(errors, "duplicate citation corrections: $(join(duplicate_corrections, ", "))")

    for entry in entries
        entry.evidence_provenance in _EVIDENCE_PROVENANCES ||
            push!(errors, "unknown evidence provenance for $(entry.id): $(entry.evidence_provenance)")
        entry.value_kind in _EVIDENCE_VALUE_KINDS ||
            push!(errors, "unknown value kind for $(entry.id): $(entry.value_kind)")
        entry.verification_status in _EVIDENCE_VERIFICATION_STATUSES ||
            push!(errors, "unknown verification status for $(entry.id): $(entry.verification_status)")
        entry.uncertainty_kind in _EVIDENCE_UNCERTAINTY_KINDS ||
            push!(errors, "unknown uncertainty kind for $(entry.id): $(entry.uncertainty_kind)")
        append!(errors, _evidence_value_errors(entry))
        isempty(entry.families) &&
            push!(errors, "entry $(entry.id) has no family")
        isempty(entry.gate_ids) &&
            push!(errors, "entry $(entry.id) has no gate_ids")
        isempty(entry.source_ids) &&
            push!(errors, "entry $(entry.id) has no source_ids")
        if !isempty(known_source_ids)
            missing = setdiff(Set(entry.source_ids), known_source_ids)
            isempty(missing) || push!(errors,
                "entry $(entry.id) references unknown source IDs: $(join(sort!(collect(missing)), ", "))")
        end
        entry.promotion_credit && entry.verification_status != "full_text_verified" &&
            push!(warnings,
                "entry $(entry.id) grants promotion credit before full-text verification")
    end

    for correction in corrections
        correction.legacy_doi == correction.corrected_doi &&
            push!(errors, "citation correction for $(correction.source_id) does not change the DOI")
        if !isempty(known_source_ids) && correction.source_id ∉ known_source_ids
            push!(errors, "citation correction references unknown source $(correction.source_id)")
        end
    end
    return ValidationReport(isempty(errors), errors, warnings)
end

function load_quantitative_evidence_table(path::AbstractString;
        known_source_ids::Set{String} = Set{String}())
    data = _plain_json(JSON3.read(read(path, String), Dict{String,Any}))
    report = validate_quantitative_evidence_table(data;
        known_source_ids = known_source_ids)
    report.valid || throw(ArgumentError(join(report.errors, "; ")))
    return _quantitative_evidence_table(data)
end

function quantitative_evidence_entry_to_dict(entry::QuantitativeEvidenceEntry)
    return Dict{String,Any}(
        "id" => entry.id,
        "quantity_name" => entry.quantity_name,
        "family" => sort!(collect(entry.families)),
        "gate_ids" => entry.gate_ids,
        "source_ids" => entry.source_ids,
        "evidence_provenance" => entry.evidence_provenance,
        "value_kind" => entry.value_kind,
        "unit" => entry.unit,
        "nominal_value" => entry.nominal_value,
        "lower_bound" => entry.lower_bound,
        "upper_bound" => entry.upper_bound,
        "qualitative_value" => entry.qualitative_value,
        "operating_condition" => entry.operating_condition,
        "definition" => entry.definition,
        "location" => entry.location,
        "verification_status" => entry.verification_status,
        "transferability" => entry.transferability,
        "claim_boundary" => entry.claim_boundary,
        "reported_text" => entry.reported_text,
        "promotion_credit" => entry.promotion_credit,
        "uncertainty" => Dict{String,Any}(
            "kind" => entry.uncertainty_kind,
            "description" => entry.uncertainty_description,
        ),
    )
end

function quantitative_evidence_table_to_dict(table::QuantitativeEvidenceTable)
    return Dict{String,Any}(
        "schema_version" => table.schema_version,
        "catalog_version" => table.catalog_version,
        "created_on" => table.created_on,
        "purpose" => table.purpose,
        "base_catalogs" => sort!(copy(table.base_catalogs)),
        "citation_corrections" => sort!([
            Dict{String,Any}(
                "source_id" => correction.source_id,
                "legacy_doi" => correction.legacy_doi,
                "corrected_doi" => correction.corrected_doi,
                "reason" => correction.reason,
            ) for correction in table.citation_corrections
        ]; by = correction -> correction["source_id"]),
        "evidence_entries" => sort!([
            quantitative_evidence_entry_to_dict(entry) for entry in table.entries
        ]; by = entry -> entry["id"]),
    )
end

function quantitative_evidence_hash(table::QuantitativeEvidenceTable)
    return canonical_hash(quantitative_evidence_table_to_dict(table))
end

function quantitative_gate_audit(table::QuantitativeEvidenceTable,
        gate_ids)
    result = Dict{String,Any}()
    for gate_id in sort!(unique(String.(collect(gate_ids))))
        matching = filter(entry -> gate_id in entry.gate_ids, table.entries)
        promotion = filter(entry -> entry.promotion_credit, matching)
        if !isempty(promotion)
            status = "promotion_credit_available"
        elseif any(entry -> entry.evidence_provenance != "no_direct_measurement",
                matching)
            status = "anchor_or_gap_record_only"
        elseif !isempty(matching)
            status = "gap_record_only"
        else
            status = "missing"
        end
        result[gate_id] = Dict{String,Any}(
            "status" => status,
            "entry_count" => length(matching),
            "promotion_credit_count" => length(promotion),
            "entry_ids" => sort!([entry.id for entry in matching]),
        )
    end
    return result
end

function missing_promotion_evidence(table::QuantitativeEvidenceTable,
        gate_ids)
    return sort!(String[gate_id for (gate_id, audit) in
        quantitative_gate_audit(table, gate_ids)
        if audit["status"] != "promotion_credit_available"])
end

function quantitative_evidence_summary(table::QuantitativeEvidenceTable)
    provenance_counts = Dict{String,Int}()
    kind_counts = Dict{String,Int}()
    for entry in table.entries
        provenance_counts[entry.evidence_provenance] =
            get(provenance_counts, entry.evidence_provenance, 0) + 1
        kind_counts[entry.value_kind] =
            get(kind_counts, entry.value_kind, 0) + 1
    end
    return Dict{String,Any}(
        "entry_count" => length(table.entries),
        "promotion_credit_count" =>
            count(entry -> entry.promotion_credit, table.entries),
        "provenance_counts" => provenance_counts,
        "value_kind_counts" => kind_counts,
    )
end
