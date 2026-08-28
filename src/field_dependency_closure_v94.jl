const FIELD_DEPENDENCY_CLOSURE_V94_CLAIM_BOUNDARY =
    "Field closure records provenance and recomputation reachability. External evidence and unsupported fields remain independent from computed or derived values."

const V94_FIELD_CLASSES = Set([
    "recovered", "derived", "computable", "external_evidence", "unsupported"])

struct FieldClosurePlanV94
    status::String
    records::Vector{Dict{String,Any}}
    recompute_dag::Vector{Dict{String,Any}}
    recompute_order::Vector{String}
    unresolved_fields::Vector{String}
    plan_hash::String
end

function _field_requirement_v94(field::Dict{String,Any})
    CapabilityRequirementV94(
        "field:" * String(field["field_key"]), "field",
        sort!(unique(String.(get(field, "states", Any[])))),
        haskey(field, "operator") ? String(field["operator"]) : nothing,
        nothing,
        sort!(unique(String.(get(field, "function_spaces", Any[])))),
        Int(get(field, "dimension", 0)),
        String(get(field, "coordinate", "scalar")),
        "field_value",
        Dict{String,Any}("field_key" => String(field["field_key"]),
            "recipe" => get(field, "recipe", nothing)))
end

function _topological_field_order_v94(fields::Dict{String,Dict{String,Any}})
    indegree = Dict(key => 0 for key in keys(fields))
    outgoing = Dict(key => String[] for key in keys(fields))
    missing = Dict{String,Vector{String}}()
    for (key, field) in fields
        dependencies = unique(String.(get(field, "dependencies", Any[])))
        missing[key] = sort!(collect(setdiff(Set(dependencies), Set(keys(fields)))))
        for dependency in dependencies
            haskey(fields, dependency) || continue
            indegree[key] += 1
            push!(outgoing[dependency], key)
        end
    end
    queue = sort!([key for (key, degree) in indegree if degree == 0])
    order = String[]
    while !isempty(queue)
        key = popfirst!(queue)
        push!(order, key)
        for child in sort!(outgoing[key])
            indegree[child] -= 1
            indegree[child] == 0 && push!(queue, child)
        end
        sort!(queue)
    end
    cyclic = sort!([key for (key, degree) in indegree if degree > 0])
    order, cyclic, missing
end

function plan_field_dependency_closure_v94(field_declarations;
        registry = OperatorProviderRegistryV94())
    fields = Dict{String,Dict{String,Any}}()
    for raw in field_declarations
        field = Dict{String,Any}(_v93_plain(raw))
        key = String(get(field, "field_key", ""))
        isempty(key) && throw(ArgumentError("every field declaration requires field_key"))
        haskey(fields, key) && throw(ArgumentError("field_key must be unique"))
        declared_class = String(get(field, "class", "unsupported"))
        declared_class in V94_FIELD_CLASSES || throw(ArgumentError("invalid field class"))
        fields[key] = field
    end
    order, cyclic, missing = _topological_field_order_v94(fields)
    available = Dict{String,Bool}()
    records_by_key = Dict{String,Dict{String,Any}}()
    dag = Dict{String,Any}[]
    for key in order
        field = fields[key]
        declared_class = String(field["class"])
        dependencies = unique(String.(get(field, "dependencies", Any[])))
        blockers = String[]
        append!(blockers, ["missing_dependency:" * item for item in missing[key]])
        unavailable_dependencies = [item for item in dependencies
            if haskey(available, item) && !available[item]]
        append!(blockers, ["unavailable_dependency:" * item for item in unavailable_dependencies])
        provider_route = nothing
        effective_class = declared_class
        is_available = false
        if declared_class == "recovered"
            is_available = get(field, "available", haskey(field, "value")) === true
            is_available || push!(blockers, "recovered_value_unavailable")
        elseif declared_class == "derived"
            isempty(dependencies) && push!(blockers, "derived_field_requires_dependencies")
            is_available = isempty(blockers) && all(get(available, item, false) for item in dependencies)
        elseif declared_class == "computable"
            provider_route = route_provider_v94(registry, _field_requirement_v94(field))
            if provider_route["status"] != "closed"
                effective_class = "unsupported"
                push!(blockers, "provider_capability_unavailable")
            end
            is_available = isempty(blockers) && provider_route["status"] == "closed" &&
                all(get(available, item, false) for item in dependencies)
        elseif declared_class == "external_evidence"
            is_available = get(field, "evidence_available", false) === true
            is_available || push!(blockers, "external_evidence_unavailable")
        else
            push!(blockers, String(get(field, "reason", "explicitly_unsupported")))
        end
        available[key] = is_available
        record = Dict{String,Any}(
            "field_key" => key,
            "declared_class" => declared_class,
            "class" => effective_class,
            "available" => is_available,
            "dependencies" => sort!(dependencies),
            "blockers" => unique(blockers),
            "provider_route" => provider_route,
            "external_evidence_used_as_computed_value" => false)
        records_by_key[key] = record
        if declared_class in ("derived", "computable")
            push!(dag, Dict("field_key" => key, "dependencies" => sort!(dependencies),
                "operation" => declared_class,
                "provider_key" => provider_route === nothing ? nothing : provider_route["selected_provider"],
                "ready" => is_available))
        end
    end
    for key in cyclic
        field = fields[key]
        records_by_key[key] = Dict{String,Any}(
            "field_key" => key,
            "declared_class" => String(field["class"]),
            "class" => "unsupported",
            "available" => false,
            "dependencies" => sort!(unique(String.(get(field, "dependencies", Any[])))),
            "blockers" => ["dependency_cycle"],
            "provider_route" => nothing,
            "external_evidence_used_as_computed_value" => false)
        push!(dag, Dict("field_key" => key,
            "dependencies" => records_by_key[key]["dependencies"],
            "operation" => String(field["class"]), "provider_key" => nothing, "ready" => false))
    end
    records = [records_by_key[key] for key in sort!(collect(keys(records_by_key)))]
    unresolved = sort!([String(record["field_key"]) for record in records if !record["available"]])
    recompute_order = [key for key in order if String(fields[key]["class"]) in ("derived", "computable")]
    body = Dict{String,Any}(
        "status" => isempty(unresolved) ? "closed" : "incomplete",
        "records" => records, "recompute_dag" => dag,
        "recompute_order" => recompute_order, "unresolved_fields" => unresolved,
        "claim_boundary" => FIELD_DEPENDENCY_CLOSURE_V94_CLAIM_BOUNDARY)
    FieldClosurePlanV94(body["status"], records, dag, recompute_order, unresolved,
        canonical_hash(body))
end

function field_closure_plan_to_dict_v94(plan::FieldClosurePlanV94)
    Dict{String,Any}(
        "status" => plan.status, "records" => plan.records,
        "recompute_dag" => plan.recompute_dag,
        "recompute_order" => plan.recompute_order,
        "unresolved_fields" => plan.unresolved_fields,
        "plan_hash" => plan.plan_hash,
        "claim_boundary" => FIELD_DEPENDENCY_CLOSURE_V94_CLAIM_BOUNDARY)
end
