const STAGE3_INDEPENDENT_AUDITOR_SOFTWARE_HASH_V1 =
    bytes2hex(SHA.sha256(read(@__FILE__)))

_stage3_persisted_hash_v1(value) =
    canonical_hash(JSON3.read(JSON3.write(_stage3_plain_v1_for_hash(value))))

function _stage3_plain_v1_for_hash(value)
    value isa AbstractDict && return Dict{String,Any}(String(key) =>
        _stage3_plain_v1_for_hash(child) for (key, child) in pairs(value))
    value isa AbstractMatrix && return Any[Any[_stage3_plain_v1_for_hash(
        value[row, column]) for column in axes(value, 2)] for row in axes(value, 1)]
    value isa AbstractVector && return Any[_stage3_plain_v1_for_hash(child)
        for child in value]
    value isa Tuple && return Any[_stage3_plain_v1_for_hash(child) for child in value]
    value isa Symbol && return String(value)
    return value
end

struct Stage3IndependentAuditV1
    schema_version::String
    status::Symbol
    classification_code::String
    maximum_balance_residual::Float64
    per_account_residuals::Dict{String,Float64}
    software_hash::String
    numerical_path::String
    reasons::Vector{String}
    audit_hash::String
end

"""
Independently reconstruct integral balances from archived primitive quantities.

The input contains cell volumes, previous/final cell states, oriented face fluxes and
cell sources.  This module deliberately does not accept a solver residual or callback.
"""
function stage3_independent_balance_auditor_v1(record::AbstractDict;
        absolute_tolerance::Real = 1.0e-8,
        relative_tolerance::Real = 1.0e-6)
    reasons = String[]
    cells = get(record, "cells", nothing)
    faces = get(record, "faces", nothing)
    sources = get(record, "sources", nothing)
    duration = get(record, "duration", 0.0)
    accounts = String.(get(record, "accounts", String[]))
    if !(cells isa AbstractVector)
        push!(reasons, "missing_independent_audit_cells")
    end
    if !(faces isa AbstractVector)
        push!(reasons, "missing_independent_audit_faces")
    end
    if !(sources isa AbstractVector)
        push!(reasons, "missing_independent_audit_sources")
    end
    isempty(accounts) && push!(reasons, "missing_independent_audit_accounts")
    duration isa Real || push!(reasons, "invalid_independent_audit_duration")
    if !isempty(reasons)
        body = Dict{String,Any}("schema_version" => "1.0.0",
            "status" => "unknown",
            "classification_code" => "unknown_independent_audit_input_incomplete",
            "maximum_balance_residual" => Inf,
            "per_account_residuals" => Dict{String,Float64}(),
            "software_hash" => STAGE3_INDEPENDENT_AUDITOR_SOFTWARE_HASH_V1,
            "numerical_path" => "independent_integral_reconstruction_v1",
            "reasons" => sort!(unique(reasons)))
        return Stage3IndependentAuditV1("1.0.0", :unknown,
            body["classification_code"], Inf, Dict{String,Float64}(),
            STAGE3_INDEPENDENT_AUDITOR_SOFTWARE_HASH_V1,
            body["numerical_path"], body["reasons"], _stage3_persisted_hash_v1(body))
    end

    residuals = Dict{String,Float64}()
    scales = Dict{String,Float64}()
    cell_by_id = Dict{String,Any}(String(cell["cell_id"]) => cell for cell in cells)
    for account in accounts
        inventory_change = 0.0
        source_integral = 0.0
        boundary_outflow = 0.0
        for cell in cells
            volume = Float64(get(cell, "volume", 1.0))
            initial = Float64(get(get(cell, "initial", Dict{String,Any}()), account, 0.0))
            final = Float64(get(get(cell, "final", Dict{String,Any}()), account, initial))
            inventory_change += volume * (final - initial)
        end
        for source in sources
            String(get(source, "account", "")) == account || continue
            source_integral += Float64(get(source, "integrated_amount", 0.0))
        end
        for face in faces
            String(get(face, "account", "")) == account || continue
            left = get(face, "left_cell_id", nothing)
            right = get(face, "right_cell_id", nothing)
            left === nothing || haskey(cell_by_id, String(left)) ||
                push!(reasons, "independent_audit_face_left_cell_missing")
            right === nothing || haskey(cell_by_id, String(right)) ||
                push!(reasons, "independent_audit_face_right_cell_missing")
            # Internal paired faces cancel in a global balance.  A missing endpoint is
            # an external boundary and the archived orientation is outward-positive.
            if left === nothing || right === nothing
                boundary_outflow += Float64(get(face, "integrated_flux", 0.0))
            end
        end
        value = inventory_change + boundary_outflow - source_integral
        residuals[account] = value
        scales[account] = max(abs(inventory_change), abs(boundary_outflow),
            abs(source_integral), 1.0)
    end
    normalized = Dict(account => abs(residuals[account]) / scales[account]
        for account in accounts)
    maximum_residual = isempty(normalized) ? Inf : maximum(values(normalized))
    tolerance = max(Float64(relative_tolerance), Float64(absolute_tolerance))
    invalid = !all(isfinite, values(residuals)) || !isfinite(maximum_residual)
    status = invalid || !isempty(reasons) ? :unknown : maximum_residual <= tolerance ?
        :pass : :fail
    code = status == :pass ? "pass_independent_balance_recomputation" :
        status == :fail ? "fail_independent_balance_recomputation" :
        "unknown_independent_balance_recomputation"
    status == :fail && push!(reasons, "independent_balance_tolerance_exceeded")
    body = Dict{String,Any}("schema_version" => "1.0.0", "status" => String(status),
        "classification_code" => code,
        "maximum_balance_residual" => maximum_residual,
        "per_account_residuals" => Dict(sort!(collect(residuals))),
        "software_hash" => STAGE3_INDEPENDENT_AUDITOR_SOFTWARE_HASH_V1,
        "numerical_path" => "independent_integral_reconstruction_v1",
        "reasons" => sort!(unique(reasons)))
    return Stage3IndependentAuditV1("1.0.0", status, code, maximum_residual,
        residuals, STAGE3_INDEPENDENT_AUDITOR_SOFTWARE_HASH_V1,
        "independent_integral_reconstruction_v1", body["reasons"],
        _stage3_persisted_hash_v1(body))
end

function stage3_independent_audit_to_dict_v1(audit::Stage3IndependentAuditV1)
    return Dict{String,Any}("schema_version" => audit.schema_version,
        "status" => String(audit.status),
        "classification_code" => audit.classification_code,
        "maximum_balance_residual" => audit.maximum_balance_residual,
        "per_account_residuals" => audit.per_account_residuals,
        "software_hash" => audit.software_hash,
        "numerical_path" => audit.numerical_path,
        "reasons" => audit.reasons, "audit_hash" => audit.audit_hash)
end
