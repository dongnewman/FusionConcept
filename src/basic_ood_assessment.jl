function basic_ood_assessment_v1(query, calibration_domain)
    point = _plain_json(query)
    domain = _plain_json(calibration_domain)
    dimensions = Dict{String,Any}()
    silent = false
    for key in ("dimensionless", "operator_class", "geometry_class")
        requested = get(point, key, nothing)
        allowed = get(domain, key, Any[])
        status = if requested === nothing
            "unknown"
        elseif allowed isa AbstractDict && requested isa AbstractDict
            all(haskey(allowed, k) && Float64(allowed[k][1]) <= Float64(v) <= Float64(allowed[k][2])
                for (k, v) in requested) ? "in_domain" : "out_of_domain"
        else
            String(requested) in String.(allowed) ? "in_domain" : "out_of_domain"
        end
        dimensions[key] = Dict("requested" => requested, "calibration" => allowed, "status" => status)
    end
    overall = any(item -> item["status"] == "out_of_domain", values(dimensions)) ? "out_of_domain" :
        any(item -> item["status"] == "unknown", values(dimensions)) ? "unknown" : "in_domain"
    return Dict{String,Any}(
        "status" => overall, "dimensions" => dimensions,
        "promotion_action" => overall == "in_domain" ? "retain_scope" : "downgrade_to_unknown",
        "silent_extrapolation" => silent,
    )
end

