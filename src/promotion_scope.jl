function _intersect_string_arrays_v1(items, key)
    arrays = [Set(String.(get(item, key, Any[]))) for item in items]
    isempty(arrays) && return Any[]
    any(isempty, arrays) && return Any[]
    return sort!(collect(reduce(intersect, arrays)))
end

function intersect_promotion_scopes_v1(scopes; current_ruleset_hash = nothing)
    items = [_plain_json(scope) for scope in scopes]
    isempty(items) && return Dict("status" => "unknown", "max_gate" => "none", "reason" => "no scopes")
    errors = reduce(vcat, [validate_promotion_scope_v1(item; ruleset_hash = current_ruleset_hash) for item in items])
    gate = first(sort!(String[String(get(item, "max_gate", "none")) for item in items]; by = g -> _OWV2_GATE_ORDER[g]))
    rule_hashes = unique(String(get(item, "required_ruleset_hash", "")) for item in items)
    ranges = Dict{String,Any}()
    range_keys = unique(vcat([String.(collect(keys(get(item, "valid_parameter_ranges", Dict{String,Any}())))) for item in items]...))
    for key in range_keys
        bounds = [get(item, "valid_parameter_ranges", Dict{String,Any}())[key]
            for item in items if haskey(get(item, "valid_parameter_ranges", Dict{String,Any}()), key)]
        if length(bounds) == length(items) && all(bound -> bound isa AbstractVector && length(bound) == 2, bounds)
            lower = maximum(Float64(bound[1]) for bound in bounds)
            upper = minimum(Float64(bound[2]) for bound in bounds)
            lower <= upper ? (ranges[key] = Any[lower, upper]) : push!(errors, "empty parameter intersection for $key")
        end
    end
    status = isempty(errors) ? "valid" : "unknown"
    return Dict{String,Any}(
        "status" => status, "max_gate" => isempty(errors) ? gate : "none",
        "valid_missions" => _intersect_string_arrays_v1(items, "valid_missions"),
        "valid_domains" => _intersect_string_arrays_v1(items, "valid_domains"),
        "valid_observables" => _intersect_string_arrays_v1(items, "valid_observables"),
        "valid_parameter_ranges" => ranges, "required_ruleset_hashes" => rule_hashes,
        "independent_confirmation_required" => any(item -> get(item, "independent_confirmation_required", false), items),
        "errors" => unique(errors),
    )
end

function promotion_scope_authorizes_v1(scope, gate::AbstractString; mission = nothing, domain = nothing)
    item = _plain_json(scope)
    requested = String(gate)
    max_gate = String(get(item, "max_gate", "none"))
    authorized = haskey(_OWV2_GATE_ORDER, requested) && haskey(_OWV2_GATE_ORDER, max_gate) &&
        _OWV2_GATE_ORDER[requested] <= _OWV2_GATE_ORDER[max_gate]
    mission !== nothing && !(String(mission) in String.(get(item, "valid_missions", Any[]))) && (authorized = false)
    domain !== nothing && !(String(domain) in String.(get(item, "valid_domains", Any[]))) && (authorized = false)
    return authorized
end

