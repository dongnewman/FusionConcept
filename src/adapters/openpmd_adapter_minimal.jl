function openpmd_adapter_manifest_minimal_v1()
    return Dict("adapter_id" => "openpmd_adapter_minimal_v1", "standard" => "openPMD",
        "supported_products" => Any["scalar_time_series", "mesh_metadata", "particle_metadata"],
        "backend" => "metadata_only_prototype", "units_policy" => "unitSI_required",
        "missing_field_policy" => "record_unknown", "family_routing" => false,
        "status" => "prototype_metadata_adapter")
end

function adapt_openpmd_product_minimal_v1(value)
    raw = _plain_json(value)
    missing = String[key for key in ("iteration", "time", "unitSI", "data", "provenance") if !haskey(raw, key)]
    return Dict{String,Any}(
        "adapter_manifest" => openpmd_adapter_manifest_minimal_v1(),
        "iteration" => get(raw, "iteration", nothing), "time" => get(raw, "time", nothing),
        "unitSI" => get(raw, "unitSI", nothing), "data" => get(raw, "data", nothing),
        "missing_fields" => missing, "information_loss" => Any["backend_specific_chunking_not_preserved"],
        "provenance" => get(raw, "provenance", Dict{String,Any}()),
        "status" => isempty(missing) ? "adapted" : "unknown",
    )
end

