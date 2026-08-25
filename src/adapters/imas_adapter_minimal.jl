function imas_adapter_manifest_minimal_v1()
    return Dict("adapter_id" => "imas_adapter_minimal_v1", "standard" => "IMAS",
        "supported_objects" => Any["equilibrium_summary", "core_profiles_summary"],
        "units_policy" => "explicit_SI", "coordinate_policy" => "declared_not_inferred",
        "missing_field_policy" => "record_unknown", "family_routing" => false,
        "status" => "prototype_metadata_adapter")
end

function adapt_imas_record_minimal_v1(value)
    raw = _plain_json(value)
    missing = String[key for key in ("time", "coordinates", "quantities", "provenance") if !haskey(raw, key)]
    return Dict{String,Any}(
        "adapter_manifest" => imas_adapter_manifest_minimal_v1(),
        "time" => get(raw, "time", nothing), "coordinates" => get(raw, "coordinates", nothing),
        "quantities" => get(raw, "quantities", Dict{String,Any}()),
        "missing_fields" => missing, "information_loss" => Any["full_IMAS_IDS_not_preserved_by_minimal_summary"],
        "provenance" => get(raw, "provenance", Dict{String,Any}()),
        "status" => isempty(missing) ? "adapted" : "unknown",
    )
end

