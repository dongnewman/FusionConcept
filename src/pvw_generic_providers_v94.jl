const PVW_GENERIC_PROVIDERS_V94_CLAIM_BOUNDARY =
    "These providers cover declared linear mixed radial operators and trace constraints. Their finite one-dimensional capability does not generalize to undeclared coordinates, dimensions, operators, dynamics, or devices."

function default_operator_provider_registry_v94()
    registry = OperatorProviderRegistryV94()
    register_provider_v94!(registry, ProviderCapabilityV94(
        "mixed_radial_flux_kinematic_v1", "available",
        ["poloidal_flux", "radial_flux_gradient"], ["radial_flux_kinematic"], String[],
        ["H1_radial", "L2_radial"], [1], ["radial_axisymmetric"],
        ["residual_jacobian_fragment"], "v94.1"), _declared_linear_fragment_v94)
    register_provider_v94!(registry, ProviderCapabilityV94(
        "radial_source_balance_v1", "available",
        ["radial_flux_gradient"], ["radial_field_source_balance"], String[],
        ["L2_radial"], [1], ["radial_axisymmetric"],
        ["residual_jacobian_fragment"], "v94.1"), _declared_linear_fragment_v94)
    register_provider_v94!(registry, ProviderCapabilityV94(
        "radial_axis_regularity_v1", "available",
        ["radial_flux_gradient"], String[], ["axis_regularity"], ["L2_radial"],
        [1], ["radial_axisymmetric"], ["residual_jacobian_fragment"], "v94.1"),
        _declared_linear_fragment_v94)
    register_provider_v94!(registry, ProviderCapabilityV94(
        "essential_flux_trace_v1", "available",
        ["poloidal_flux"], String[], ["essential_flux_trace"], ["H1_radial"],
        [1], ["radial_axisymmetric"], ["residual_jacobian_fragment"], "v94.1"),
        _declared_linear_fragment_v94)
    register_provider_v94!(registry, ProviderCapabilityV94(
        "mixed_trace_continuity_v1", "available",
        ["poloidal_flux", "radial_flux_gradient"], String[],
        ["poloidal_flux_continuity", "radial_field_jump"], ["H1_radial", "L2_radial"],
        [1], ["radial_axisymmetric"], ["residual_jacobian_fragment"], "v94.1"),
        _declared_linear_fragment_v94)
    register_provider_v94!(registry, ProviderCapabilityV94(
        "cartesian_scalar_balance_v1", "available",
        ["scalar_field"], ["linear_conservation_balance"], String[], ["H1"],
        [1, 2, 3], ["cartesian"], ["residual_jacobian_fragment"], "v94.1"),
        _declared_linear_fragment_v94)
    register_provider_v94!(registry, ProviderCapabilityV94(
        "cartesian_trace_multiplier_v1", "available",
        ["scalar_field", "interface_multiplier"], String[], ["state_trace_continuity"],
        ["H1", "mortar_dual"], [1, 2, 3], ["cartesian"],
        ["residual_jacobian_fragment"], "v94.1"), _declared_linear_fragment_v94)
    registry
end

_v94_term(row, variable, coefficient) = Dict{String,Any}(
    "row_key" => String(row), "variable_key" => String(variable),
    "coefficient" => Float64(coefficient))

function compile_pvw_graph_v94(problem::PlasmaVacuumWallProblemV1; points = 65,
        region_keys = ("inner-domain", "outer-domain"), labels = ("inner", "outer"),
        extra_inner_operator = nothing)
    points >= 5 && isodd(points) ||
        throw(ArgumentError("PVW graph mesh points must be odd and at least five"))
    length(region_keys) == 2 && length(unique(region_keys)) == 2 ||
        throw(ArgumentError("PVW graph requires two distinct region keys"))
    np = (Int(points) + 1) ÷ 2; nv = Int(points) - np + 1
    rp = collect(range(0.0, problem.plasma_radius_m; length = np))
    rv = collect(range(problem.plasma_radius_m, problem.wall_radius_m; length = nv))
    inner = String(region_keys[1]); outer = String(region_keys[2])
    psi_p = ["$(inner):psi:$i" for i in 1:np]
    q_p = ["$(inner):q:$i" for i in 1:np]
    psi_v = ["$(outer):psi:$i" for i in 1:nv]
    q_v = ["$(outer):q:$i" for i in 1:nv]
    variables = Dict{String,Any}[]
    for (region, psi, q) in ((inner, psi_p, q_p), (outer, psi_v, q_v))
        append!(variables, [Dict("variable_key" => key, "region_key" => region,
            "physical_state" => "poloidal_flux", "function_space" => "H1_radial") for key in psi])
        append!(variables, [Dict("variable_key" => key, "region_key" => region,
            "physical_state" => "radial_flux_gradient", "function_space" => "L2_radial") for key in q])
    end
    equations = Dict{String,Any}[]
    inner_equation_keys = String[]; outer_equation_keys = String[]
    mu0 = 4pi * 1e-7
    function add_region_equations!(region, grid, psi, q, source, equation_keys)
        for i in 1:(length(grid) - 1)
            dr = grid[i + 1] - grid[i]; rm = (grid[i + 1] + grid[i]) / 2
            key = "$(region):kinematic:$i"; push!(equation_keys, key)
            additional = Any[]
            if extra_inner_operator !== nothing && region == inner && i == 1
                push!(additional, Dict("operator" => String(extra_inner_operator),
                    "terms" => Any[], "rhs" => 0.0))
            end
            push!(equations, Dict{String,Any}(
                "equation_key" => key, "region_key" => region, "row_key" => key,
                "operator" => "radial_flux_kinematic",
                "terms" => [_v94_term(key, psi[i], -1 / dr),
                    _v94_term(key, psi[i + 1], 1 / dr),
                    _v94_term(key, q[i], -rm / 2), _v94_term(key, q[i + 1], -rm / 2)],
                "rhs" => 0.0, "additional_operators" => additional,
                "required_fields" => ["mesh.coordinates"]))
        end
        for i in 1:(length(grid) - 1)
            dr = grid[i + 1] - grid[i]; rm = (grid[i + 1] + grid[i]) / 2
            key = "$(region):balance:$i"; push!(equation_keys, key)
            rhs = -(mu0 * rm^2 * source[1] + source[2])
            push!(equations, Dict{String,Any}(
                "equation_key" => key, "region_key" => region, "row_key" => key,
                "operator" => "radial_field_source_balance",
                "terms" => [_v94_term(key, q[i], -rm / dr),
                    _v94_term(key, q[i + 1], rm / dr)], "rhs" => rhs,
                "additional_operators" => Any[],
                "required_fields" => ["mesh.coordinates", "source.coefficients"]))
        end
    end
    add_region_equations!(inner, rp, psi_p, q_p,
        (problem.dp_dpsi_pa_per_wb_per_rad, problem.F_dF_dpsi_t2m2_per_wb_per_rad),
        inner_equation_keys)
    add_region_equations!(outer, rv, psi_v, q_v, (0.0, 0.0), outer_equation_keys)
    boundaries = [
        Dict{String,Any}("boundary_key" => "axis", "region_key" => inner,
            "row_key" => "boundary:axis", "condition" => "axis_regularity",
            "terms" => [_v94_term("boundary:axis", q_p[1], 1.0)], "rhs" => 0.0,
            "required_fields" => ["mesh.coordinates"]),
        Dict{String,Any}("boundary_key" => "outer-trace", "region_key" => outer,
            "row_key" => "boundary:outer-trace", "condition" => "essential_flux_trace",
            "terms" => [_v94_term("boundary:outer-trace", psi_v[end], 1.0)],
            "rhs" => problem.psi_wall_wb_per_rad, "required_fields" => ["boundary.outer_flux"])]
    interface = Dict{String,Any}(
        "interface_key" => "shared-trace", "minus_region_key" => inner,
        "plus_region_key" => outer, "required_fields" => ["interface.surface"],
        "conditions" => [
            Dict{String,Any}("condition" => "poloidal_flux_continuity",
                "row_key" => "interface:flux", "terms" => [
                    _v94_term("interface:flux", psi_p[end], 1.0),
                    _v94_term("interface:flux", psi_v[1], -1.0)], "rhs" => 0.0,
                "required_fields" => ["interface.surface"]),
            Dict{String,Any}("condition" => "radial_field_jump",
                "row_key" => "interface:field", "terms" => [
                    _v94_term("interface:field", q_p[end], 1.0),
                    _v94_term("interface:field", q_v[1], -1.0)],
                "rhs" => mu0 * problem.surface_current_a_per_m,
                "required_fields" => ["interface.surface", "surface.current"])] )
    fields = [
        Dict("field_key" => "radius.inner", "class" => "recovered", "value" => problem.plasma_radius_m),
        Dict("field_key" => "radius.outer", "class" => "recovered", "value" => problem.wall_radius_m),
        Dict("field_key" => "source.coefficients", "class" => "recovered",
            "value" => [problem.dp_dpsi_pa_per_wb_per_rad, problem.F_dF_dpsi_t2m2_per_wb_per_rad]),
        Dict("field_key" => "boundary.outer_flux", "class" => "recovered", "value" => problem.psi_wall_wb_per_rad),
        Dict("field_key" => "surface.current", "class" => "recovered", "value" => problem.surface_current_a_per_m),
        Dict("field_key" => "mesh.coordinates", "class" => "derived",
            "dependencies" => ["radius.inner", "radius.outer"], "recipe" => "piecewise_uniform_radial_mesh"),
        Dict("field_key" => "interface.surface", "class" => "derived",
            "dependencies" => ["radius.inner"], "recipe" => "shared_radial_trace"),
        Dict("field_key" => "validation.measurements", "class" => "external_evidence",
            "evidence_available" => false)]
    regions = [
        Dict{String,Any}("region_key" => inner, "dimension" => 1,
            "coordinate" => "radial_axisymmetric", "display_label" => String(labels[1]),
            "variable_keys" => vcat(psi_p, q_p), "equation_keys" => inner_equation_keys),
        Dict{String,Any}("region_key" => outer, "dimension" => 1,
            "coordinate" => "radial_axisymmetric", "display_label" => String(labels[2]),
            "variable_keys" => vcat(psi_v, q_v), "equation_keys" => outer_equation_keys)]
    Dict{String,Any}(
        "protocol_id" => V94_PROTOCOL_ID, "graph_key" => "two-domain-radial-mixed-system",
        "regions" => regions, "variables" => variables, "equations" => equations,
        "interfaces" => [interface], "boundaries" => boundaries, "fields" => fields,
        "observables" => Dict("inner_grid" => rp, "outer_grid" => rv,
            "inner_psi_keys" => psi_p, "inner_q_keys" => q_p,
            "outer_psi_keys" => psi_v, "outer_q_keys" => q_v),
        "source_fingerprint" => problem.problem_hash,
        "claim_boundary" => PVW_GENERIC_PROVIDERS_V94_CLAIM_BOUNDARY)
end

function manufactured_chain_graph_v94(region_count::Int = 4; order = collect(1:region_count),
        labels = ["zone-$i" for i in 1:region_count])
    region_count >= 3 || throw(ArgumentError("manufactured chain requires at least three regions"))
    sort(order) == collect(1:region_count) || throw(ArgumentError("order must be a permutation"))
    length(labels) == region_count || throw(ArgumentError("one label per region required"))
    variables = Dict{String,Any}[]; equations = Dict{String,Any}[]
    regions = Dict{String,Any}[]; interfaces = Dict{String,Any}[]
    for i in 1:region_count
        region = "r$i"; state = "u$i"; equation = "e$i"
        owned_variables = [state]
        if i < region_count
            multiplier = "lambda$i"
            push!(variables, Dict("variable_key" => multiplier, "region_key" => region,
                "physical_state" => "interface_multiplier", "function_space" => "mortar_dual"))
            push!(owned_variables, multiplier)
        end
        push!(variables, Dict("variable_key" => state, "region_key" => region,
            "physical_state" => "scalar_field", "function_space" => "H1"))
        rhs = i == 1 ? 1.0 : i == region_count ? -1.0 : 0.0
        push!(equations, Dict("equation_key" => equation, "region_key" => region,
            "row_key" => equation, "operator" => "linear_conservation_balance",
            "terms" => [_v94_term(equation, state, 2.0)], "rhs" => rhs,
            "additional_operators" => Any[], "required_fields" => ["coefficient.scalar"]))
        push!(regions, Dict("region_key" => region, "dimension" => 2,
            "coordinate" => "cartesian", "display_label" => labels[i],
            "variable_keys" => owned_variables, "equation_keys" => [equation]))
    end
    for i in 1:(region_count - 1)
        row = "trace$i"; multiplier = "lambda$i"
        terms = [_v94_term(row, "u$i", 1.0), _v94_term(row, "u$(i + 1)", -1.0),
            _v94_term("e$i", multiplier, 1.0), _v94_term("e$(i + 1)", multiplier, -1.0)]
        push!(interfaces, Dict("interface_key" => "i$i", "minus_region_key" => "r$i",
            "plus_region_key" => "r$(i + 1)", "conditions" => [
                Dict("condition" => "state_trace_continuity", "row_key" => row,
                    "terms" => terms, "rhs" => 0.0, "required_fields" => ["trace.geometry"])],
            "required_fields" => ["trace.geometry"]))
    end
    region_rank = Dict(value => index for (index, value) in enumerate(order))
    sort!(regions; by = item -> region_rank[parse(Int, String(item["region_key"])[2:end])])
    reverse!(variables); reverse!(equations); reverse!(interfaces)
    Dict{String,Any}(
        "protocol_id" => V94_PROTOCOL_ID, "graph_key" => "manufactured-unseen-chain",
        "regions" => regions, "variables" => variables, "equations" => equations,
        "interfaces" => interfaces, "boundaries" => Any[],
        "fields" => [
            Dict("field_key" => "coefficient.scalar", "class" => "recovered", "value" => 2.0),
            Dict("field_key" => "trace.geometry", "class" => "derived",
                "dependencies" => ["coefficient.scalar"], "recipe" => "chain_trace")],
        "claim_boundary" => "Manufactured algebraic topology for graph closure regression only.")
end
