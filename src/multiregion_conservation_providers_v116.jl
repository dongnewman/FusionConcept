const V116_PROTOCOL_ID = "fusionconceptai-v116-multiregion-conservation-providers-20260830"

const MULTIREGION_CONSERVATION_PROVIDERS_V116_CLAIM_BOUNDARY =
    "v116 executes candidate-bound core/edge particle and energy diffusion plus a " *
    "field-aligned Spitzer-Harm transformed-temperature exhaust solve through the v94 " *
    "operator registry, dependency closure planner and whole-graph residual/Jacobian " *
    "assembler. Three mesh levels and analytic independent solutions audit numerical " *
    "closure. These are one-dimensional collisional conservation providers, not 3D " *
    "turbulent or neoclassical transport, kinetic SOL/neutral transport, complete exhaust " *
    "qualification, experimental validation, or whole-device evidence."

const V116_MESH_LEVELS = [33, 65, 129]
const V116_CORE_EDGE_INTERFACE_FRACTION = 0.8
const V116_SPITZER_HARM_KAPPA0_W_M_EV_7_2 = 2000.0
const V116_SOL_TARGET_TEMPERATURE_EV = 5.0

function _v116_linear_registry(; include_interface::Bool = true)
    registry = OperatorProviderRegistryV94()
    register_provider_v94!(registry, ProviderCapabilityV94(
        "finite_volume_diffusion_v116", "available",
        ["thermal_energy", "species_inventory"],
        ["radial_diffusion", "transport_coefficient"], String[],
        ["finite_volume_1d"], [1], ["minor_radius_m"],
        ["residual_jacobian_fragment", "field_value"], "v116-20260830"),
        _declared_linear_fragment_v94)
    include_interface && register_provider_v94!(registry, ProviderCapabilityV94(
        "core_edge_conservative_transfer_v116", "available",
        ["thermal_energy", "species_inventory"], String[],
        ["state_continuity", "diffusive_flux_continuity"],
        ["finite_volume_1d"], [1], ["minor_radius_m"],
        ["residual_jacobian_fragment"], "v116-20260830"),
        _declared_linear_fragment_v94)
    register_provider_v94!(registry, ProviderCapabilityV94(
        "radial_boundary_conditions_v116", "available",
        ["thermal_energy", "species_inventory"], String[],
        ["axis_symmetry", "fixed_edge_state"], ["finite_volume_1d"], [1],
        ["minor_radius_m"], ["residual_jacobian_fragment"], "v116-20260830"),
        _declared_linear_fragment_v94)
    registry
end

function _v116_sol_registry()
    registry = OperatorProviderRegistryV94()
    register_provider_v94!(registry, ProviderCapabilityV94(
        "spitzer_harm_conduction_v116", "available",
        ["electron_temperature_transform"], ["spitzer_harm_conduction"], String[],
        ["finite_volume_1d"], [1], ["field_aligned_open"],
        ["residual_jacobian_fragment"], "v116-20260830"),
        _declared_linear_fragment_v94)
    register_provider_v94!(registry, ProviderCapabilityV94(
        "sol_boundary_conditions_v116", "available",
        ["electron_temperature_transform"], String[],
        ["upstream_heat_flux", "target_temperature"], ["finite_volume_1d"], [1],
        ["field_aligned_open"], ["residual_jacobian_fragment"], "v116-20260830"),
        _declared_linear_fragment_v94)
    registry
end

_v116_term(row, variable, coefficient) = Dict{String,Any}(
    "row_key" => row, "variable_key" => variable, "coefficient" => coefficient)

function _v116_internal_equation(state, region, index, grid, diffusivity, source)
    row = "$state:$region:eq:$index"
    r = grid[index + 1]; h = grid[index + 1] - grid[index]
    left = -diffusivity / h^2 + diffusivity / (2max(r, h / 2) * h)
    center = 2diffusivity / h^2
    right = -diffusivity / h^2 - diffusivity / (2max(r, h / 2) * h)
    Dict{String,Any}(
        "equation_key" => "$state:$region:$index", "region_key" => region,
        "row_key" => row, "operator" => "radial_diffusion",
        "required_fields" => ["$(state)_diffusivity", "$(state)_source"],
        "terms" => [_v116_term(row, "$state:$region:$(index - 1)", left),
            _v116_term(row, "$state:$region:$index", center),
            _v116_term(row, "$state:$region:$(index + 1)", right)],
        "rhs" => source)
end

function compile_core_edge_transport_graph_v116(candidate_raw; points::Integer = 65)
    points in V116_MESH_LEVELS || throw(ArgumentError("unsupported v116 mesh level"))
    candidate = Dict{String,Any}(_v93_plain(candidate_raw))
    point = Dict{String,Any}(candidate["operating_point"])
    metrics = Dict{String,Any}(candidate["physics_solve"]["metrics"])
    radius = Float64(point["minor_radius_m"])
    tau_e = Float64(metrics["energy_confinement_time_s"])
    tau_p = 3tau_e
    coefficients = Dict(
        "thermal_energy" => (core = radius^2 / (4tau_e),
            edge = 3radius^2 / (4tau_e),
            source = Float64(point["temperature_kev"]) / tau_e,
            edge_value = 0.2),
        "species_inventory" => (core = radius^2 / (4tau_p),
            edge = 3radius^2 / (4tau_p),
            source = Float64(point["density_m3"]) / tau_p,
            edge_value = 0.15Float64(point["density_m3"])))
    total_intervals = points - 1
    core_intervals = round(Int, V116_CORE_EDGE_INTERFACE_FRACTION * total_intervals)
    edge_intervals = total_intervals - core_intervals
    core_intervals >= 2 && edge_intervals >= 2 || throw(ArgumentError(
        "v116 mesh does not resolve both regions"))
    interface_radius = V116_CORE_EDGE_INTERFACE_FRACTION * radius
    core_grid = collect(range(0.0, interface_radius; length = core_intervals + 1))
    edge_grid = collect(range(interface_radius, radius; length = edge_intervals + 1))
    variables = Dict{String,Any}[]; equations = Dict{String,Any}[]
    regions = Dict{String,Any}[]
    for region in ("core", "edge")
        grid = region == "core" ? core_grid : edge_grid
        variable_keys = String[]; equation_keys = String[]
        for state in ("thermal_energy", "species_inventory")
            for index in 0:(length(grid) - 1)
                key = "$state:$region:$index"; push!(variable_keys, key)
                push!(variables, Dict("variable_key" => key, "region_key" => region,
                    "physical_state" => state, "function_space" => "finite_volume_1d"))
            end
            for index in 1:(length(grid) - 2)
                equation = _v116_internal_equation(state, region, index, grid,
                    getproperty(coefficients[state], Symbol(region)),
                    coefficients[state].source)
                push!(equation_keys, String(equation["equation_key"])); push!(equations, equation)
            end
        end
        push!(regions, Dict("region_key" => region, "dimension" => 1,
            "coordinate" => "minor_radius_m", "variable_keys" => variable_keys,
            "equation_keys" => equation_keys))
    end
    conditions = Dict{String,Any}[]
    for state in ("thermal_energy", "species_inventory")
        core_last = length(core_grid) - 1
        continuity_row = "$state:interface:continuity"
        push!(conditions, Dict("condition" => "state_continuity",
            "row_key" => continuity_row, "required_fields" => String[],
            "terms" => [_v116_term(continuity_row, "$state:core:$core_last", 1.0),
                _v116_term(continuity_row, "$state:edge:0", -1.0)], "rhs" => 0.0))
        flux_row = "$state:interface:flux"
        hc = core_grid[end] - core_grid[end - 1]; he = edge_grid[2] - edge_grid[1]
        dc = coefficients[state].core; de = coefficients[state].edge
        push!(conditions, Dict("condition" => "diffusive_flux_continuity",
            "row_key" => flux_row,
            "required_fields" => ["$(state)_diffusivity"],
            "terms" => [_v116_term(flux_row, "$state:core:$core_last", dc / hc),
                _v116_term(flux_row, "$state:core:$(core_last - 1)", -dc / hc),
                _v116_term(flux_row, "$state:edge:1", -de / he),
                _v116_term(flux_row, "$state:edge:0", de / he)], "rhs" => 0.0))
    end
    boundaries = Dict{String,Any}[]
    for state in ("thermal_energy", "species_inventory")
        axis_row = "$state:boundary:axis"
        push!(boundaries, Dict("boundary_key" => "$state:axis", "region_key" => "core",
            "row_key" => axis_row, "condition" => "axis_symmetry",
            "terms" => [_v116_term(axis_row, "$state:core:0", 1.0),
                _v116_term(axis_row, "$state:core:1", -1.0)], "rhs" => 0.0))
        edge_last = length(edge_grid) - 1; edge_row = "$state:boundary:edge"
        push!(boundaries, Dict("boundary_key" => "$state:edge", "region_key" => "edge",
            "row_key" => edge_row, "condition" => "fixed_edge_state",
            "terms" => [_v116_term(edge_row, "$state:edge:$edge_last", 1.0)],
            "rhs" => coefficients[state].edge_value))
    end
    fields = Dict{String,Any}[]
    for state in ("thermal_energy", "species_inventory")
        push!(fields, Dict("field_key" => "$(state)_input", "class" => "recovered",
            "available" => true, "value" => state == "thermal_energy" ?
                point["temperature_kev"] : point["density_m3"]))
        push!(fields, Dict("field_key" => "$(state)_diffusivity", "class" => "computable",
            "dependencies" => ["$(state)_input"], "states" => [state],
            "operator" => "transport_coefficient", "function_spaces" => ["finite_volume_1d"],
            "dimension" => 1, "coordinate" => "minor_radius_m"))
        push!(fields, Dict("field_key" => "$(state)_source", "class" => "derived",
            "dependencies" => ["$(state)_input"]))
    end
    Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V116_PROTOCOL_ID,
        "regions" => regions, "variables" => variables, "equations" => equations,
        "interfaces" => [Dict("interface_key" => "core_edge", "minus_region_key" => "core",
            "plus_region_key" => "edge", "conditions" => conditions)],
        "boundaries" => boundaries, "fields" => fields,
        "observables" => Dict("radius_m" => radius, "interface_radius_m" => interface_radius,
            "core_grid_m" => core_grid, "edge_grid_m" => edge_grid,
            "coefficients" => coefficients),
        "claim_boundary" => MULTIREGION_CONSERVATION_PROVIDERS_V116_CLAIM_BOUNDARY)
end

function _v116_analytic_radial(r, radius, interface_radius, source, core_d, edge_d,
        edge_value)
    if r <= interface_radius
        edge_value + source * (radius^2 - interface_radius^2) / (4edge_d) +
            source * (interface_radius^2 - r^2) / (4core_d)
    else
        edge_value + source * (radius^2 - r^2) / (4edge_d)
    end
end

function _v116_transport_level(candidate, points; include_interface = true)
    graph = compile_core_edge_transport_graph_v116(candidate; points = points)
    assembly = assemble_graph_residual_jacobian_v94(graph,
        _v116_linear_registry(; include_interface = include_interface))
    solve = solve_graph_system_v94(assembly)
    assembly.status == "closed" && solve["status"] == "pass" || return Dict{String,Any}(
        "points" => points, "status" => assembly.status == "closed" ? solve["status"] :
            "unsupported", "assembly" => graph_assembly_to_dict_v94(assembly), "solve" => solve)
    observations = graph["observables"]; radius = Float64(observations["radius_m"])
    interface_radius = Float64(observations["interface_radius_m"])
    outputs = Dict{String,Any}()
    for state in ("thermal_energy", "species_inventory")
        coefficient = observations["coefficients"][state]
        core_grid = Float64.(observations["core_grid_m"])
        edge_grid = Float64.(observations["edge_grid_m"])
        core = [Float64(solve["state_map"]["$state:core:$index"])
            for index in 0:(length(core_grid) - 1)]
        edge = [Float64(solve["state_map"]["$state:edge:$index"])
            for index in 0:(length(edge_grid) - 1)]
        analytic_core = [_v116_analytic_radial(r, radius, interface_radius,
            coefficient.source, coefficient.core, coefficient.edge,
            coefficient.edge_value) for r in core_grid]
        analytic_edge = [_v116_analytic_radial(r, radius, interface_radius,
            coefficient.source, coefficient.core, coefficient.edge,
            coefficient.edge_value) for r in edge_grid]
        error = maximum(abs.(vcat(core .- analytic_core, edge .- analytic_edge))) /
            max(maximum(abs.(vcat(analytic_core, analytic_edge))), eps())
        function radial_integral(grid, values)
            sum((grid[i + 1] - grid[i]) *
                (grid[i] * values[i] + grid[i + 1] * values[i + 1]) / 2
                for i in 1:(length(grid) - 1))
        end
        average = (radial_integral(core_grid, core) + radial_integral(edge_grid, edge)) /
            (radius^2 / 2)
        he = edge_grid[end] - edge_grid[end - 1]
        boundary_flux = coefficient.edge * (edge[end - 1] - edge[end]) / he
        expected_flux = coefficient.source * radius / 2
        balance_error = abs(boundary_flux - expected_flux) / max(abs(expected_flux), eps())
        outputs[state] = Dict("core_profile" => core, "edge_profile" => edge,
            "volume_average" => average, "axis_value" => core[1],
            "edge_value" => edge[end], "boundary_flux" => boundary_flux,
            "expected_boundary_flux" => expected_flux,
            "conservation_relative_error" => balance_error,
            "analytic_max_relative_error" => error)
    end
    Dict{String,Any}("points" => points, "status" => "pass",
        "assembly" => graph_assembly_to_dict_v94(assembly), "solve" => solve,
        "outputs" => outputs)
end

function execute_core_edge_transport_provider_v116(candidate_raw)
    candidate = Dict{String,Any}(_v93_plain(candidate_raw))
    levels = [_v116_transport_level(candidate, points) for points in V116_MESH_LEVELS]
    all(level -> level["status"] == "pass", levels) || return Dict{String,Any}(
        "status" => "provider_failure", "candidate_state" => "not_adjudicated_provider_failure",
        "levels" => levels, "unsupported_candidate_classification_used" => false)
    medium, fine = levels[end - 1], levels[end]
    convergence = Dict{String,Any}()
    for state in ("thermal_energy", "species_inventory")
        m = Float64(medium["outputs"][state]["volume_average"])
        f = Float64(fine["outputs"][state]["volume_average"])
        convergence[state] = abs(m - f) / max(abs(f), eps())
    end
    fine_outputs = fine["outputs"]
    point = candidate["operating_point"]
    gates = Dict{String,Bool}(
        "all_graphs_closed" => all(level -> level["assembly"]["status"] == "closed", levels),
        "all_solves_pass" => all(level -> level["solve"]["status"] == "pass", levels),
        "thermal_conservation" => fine_outputs["thermal_energy"][
            "conservation_relative_error"] <= 0.02,
        "particle_conservation" => fine_outputs["species_inventory"][
            "conservation_relative_error"] <= 0.02,
        "thermal_analytic_agreement" => fine_outputs["thermal_energy"][
            "analytic_max_relative_error"] <= 0.01,
        "particle_analytic_agreement" => fine_outputs["species_inventory"][
            "analytic_max_relative_error"] <= 0.01,
        "mesh_convergence" => maximum(values(convergence)) <= 0.01,
        "positive_profiles" => minimum(vcat(fine_outputs["thermal_energy"]["core_profile"],
            fine_outputs["thermal_energy"]["edge_profile"],
            fine_outputs["species_inventory"]["core_profile"],
            fine_outputs["species_inventory"]["edge_profile"])) > 0,
        "operating_temperature_consistency" => abs(Float64(fine_outputs[
            "thermal_energy"]["axis_value"]) - Float64(point["temperature_kev"])) /
            Float64(point["temperature_kev"]) <= 0.35,
        "operating_density_consistency" => abs(Float64(fine_outputs[
            "species_inventory"]["axis_value"]) - Float64(point["density_m3"])) /
            Float64(point["density_m3"]) <= 0.20)
    passed = all(values(gates))
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V116_PROTOCOL_ID,
        "candidate_result_hash" => candidate["result_hash"],
        "status" => passed ? "pass" : "fail",
        "candidate_state" => passed ? "core_edge_conservation_survivor" :
            "core_edge_conservation_reject",
        "mesh_levels" => levels, "mesh_convergence" => convergence,
        "gates" => gates, "failed_gates" => sort!([key for (key, value) in gates if !value]),
        "evidence_level" => "sampled_candidate_bound",
        "complete_transport_obligation_credit" => false,
        "unsupported_candidate_classification_used" => false,
        "identity_fields_used_for_routing" => false,
        "claim_boundary" => MULTIREGION_CONSERVATION_PROVIDERS_V116_CLAIM_BOUNDARY)
    body["result_hash"] = canonical_hash(body); body
end

function compile_sol_conduction_graph_v116(assembly_raw, candidate_raw; points::Integer = 65)
    points in V116_MESH_LEVELS || throw(ArgumentError("unsupported v116 SOL mesh level"))
    assembly = Dict{String,Any}(_v93_plain(assembly_raw))
    candidate = Dict{String,Any}(_v93_plain(candidate_raw))
    design = assembly["physical_design"]; edge = design["edge_exhaust"]
    metrics = candidate["physics_solve"]["metrics"]
    length_m = Float64(edge["connection_length_m"])
    target_flux = Float64(metrics["transport_loss_power_w"]) /
        Float64(edge["target_wetted_area_m2"])
    angle = deg2rad(Float64(edge["target_inclination_deg"]))
    parallel_flux = target_flux * Float64(edge["flux_expansion"]) / sin(angle)
    grid = collect(range(0.0, length_m; length = points)); h = grid[2] - grid[1]
    variables = [Dict("variable_key" => "sol:$index", "region_key" => "sol",
        "physical_state" => "electron_temperature_transform",
        "function_space" => "finite_volume_1d") for index in 0:(points - 1)]
    equations = Dict{String,Any}[]
    for index in 1:(points - 2)
        row = "sol:eq:$index"
        push!(equations, Dict("equation_key" => "sol:$index", "region_key" => "sol",
            "row_key" => row, "operator" => "spitzer_harm_conduction",
            "terms" => [_v116_term(row, "sol:$(index - 1)", -1 / h^2),
                _v116_term(row, "sol:$index", 2 / h^2),
                _v116_term(row, "sol:$(index + 1)", -1 / h^2)], "rhs" => 0.0))
    end
    flux_row = "sol:boundary:upstream"; target_row = "sol:boundary:target"
    flux_rhs = h * 7parallel_flux / (2V116_SPITZER_HARM_KAPPA0_W_M_EV_7_2)
    boundaries = [
        Dict("boundary_key" => "upstream", "region_key" => "sol", "row_key" => flux_row,
            "condition" => "upstream_heat_flux",
            "terms" => [_v116_term(flux_row, "sol:0", 1.0),
                _v116_term(flux_row, "sol:1", -1.0)], "rhs" => flux_rhs),
        Dict("boundary_key" => "target", "region_key" => "sol", "row_key" => target_row,
            "condition" => "target_temperature",
            "terms" => [_v116_term(target_row, "sol:$(points - 1)", 1.0)],
            "rhs" => V116_SOL_TARGET_TEMPERATURE_EV^(7 / 2))]
    Dict{String,Any}(
        "regions" => [Dict("region_key" => "sol", "dimension" => 1,
            "coordinate" => "field_aligned_open",
            "variable_keys" => String[item["variable_key"] for item in variables],
            "equation_keys" => String[item["equation_key"] for item in equations])],
        "variables" => variables, "equations" => equations, "interfaces" => Any[],
        "boundaries" => boundaries,
        "fields" => [Dict("field_key" => "parallel_heat_flux", "class" => "derived",
            "dependencies" => ["transport_loss_power"]), Dict("field_key" =>
            "transport_loss_power", "class" => "recovered", "available" => true,
            "value" => metrics["transport_loss_power_w"])],
        "observables" => Dict("grid_m" => grid, "parallel_heat_flux_w_m2" => parallel_flux,
            "target_heat_flux_w_m2" => target_flux, "connection_length_m" => length_m),
        "claim_boundary" => MULTIREGION_CONSERVATION_PROVIDERS_V116_CLAIM_BOUNDARY)
end

function _v116_sol_level(assembly, candidate, points)
    graph = compile_sol_conduction_graph_v116(assembly, candidate; points = points)
    assembled = assemble_graph_residual_jacobian_v94(graph, _v116_sol_registry())
    solve = solve_graph_system_v94(assembled)
    assembled.status == "closed" && solve["status"] == "pass" || return Dict(
        "points" => points, "status" => "provider_failure",
        "assembly" => graph_assembly_to_dict_v94(assembled), "solve" => solve)
    state = Float64.(solve["state"]); temperatures = max.(state, 0.0).^(2 / 7)
    obs = graph["observables"]; q = Float64(obs["parallel_heat_flux_w_m2"])
    length_m = Float64(obs["connection_length_m"])
    analytic_u = V116_SOL_TARGET_TEMPERATURE_EV^(7 / 2) +
        7q * length_m / (2V116_SPITZER_HARM_KAPPA0_W_M_EV_7_2)
    analytic_upstream = analytic_u^(2 / 7)
    error = abs(temperatures[1] - analytic_upstream) / analytic_upstream
    Dict("points" => points, "status" => "pass",
        "assembly" => graph_assembly_to_dict_v94(assembled), "solve" => solve,
        "upstream_temperature_ev" => temperatures[1],
        "target_temperature_ev" => temperatures[end],
        "analytic_upstream_temperature_ev" => analytic_upstream,
        "analytic_relative_error" => error, "parallel_heat_flux_w_m2" => q,
        "target_heat_flux_w_m2" => obs["target_heat_flux_w_m2"])
end

function execute_sol_exhaust_provider_v116(assembly_raw, candidate_raw)
    assembly = Dict{String,Any}(_v93_plain(assembly_raw))
    candidate = Dict{String,Any}(_v93_plain(candidate_raw))
    levels = [_v116_sol_level(assembly, candidate, points) for points in V116_MESH_LEVELS]
    all(level -> level["status"] == "pass", levels) || return Dict{String,Any}(
        "status" => "provider_failure", "candidate_state" => "not_adjudicated_provider_failure",
        "levels" => levels, "unsupported_candidate_classification_used" => false)
    fine = levels[end]; medium = levels[end - 1]
    mesh_change = abs(Float64(medium["upstream_temperature_ev"]) -
        Float64(fine["upstream_temperature_ev"])) /
        Float64(fine["upstream_temperature_ev"])
    design = assembly["physical_design"]; edge = design["edge_exhaust"]
    pump = Float64(edge["pump_speed_capacity_m3_s"]) *
        Float64(edge["neutral_pressure_operating_pa"]) / (1.380649e-23 * 300.0)
    reaction = Float64(candidate["physics_solve"]["metrics"]["fusion_power_w"]) /
        (17.6e6 * 1.602176634e-19)
    upstream_density = 0.15Float64(candidate["operating_point"]["density_m3"])
    upstream_j = Float64(fine["upstream_temperature_ev"]) * 1.602176634e-19
    free_stream = 0.2upstream_density * upstream_j * sqrt(2upstream_j / 9.1093837015e-31)
    gates = Dict{String,Bool}(
        "all_graphs_closed" => all(level -> level["assembly"]["status"] == "closed", levels),
        "all_solves_pass" => all(level -> level["solve"]["status"] == "pass", levels),
        "analytic_agreement" => fine["analytic_relative_error"] <= 1e-6,
        "mesh_convergence" => mesh_change <= 1e-6,
        "divertor_heat_flux" => fine["target_heat_flux_w_m2"] <= 10.0e6,
        "collisional_flux_limiter" => fine["parallel_heat_flux_w_m2"] <= free_stream,
        "particle_pumping_capacity" => pump >= 2reaction)
    passed = all(values(gates))
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V116_PROTOCOL_ID,
        "candidate_result_hash" => candidate["result_hash"],
        "physical_design_hash" => assembly["physical_design_hash"],
        "status" => passed ? "pass" : "fail",
        "candidate_state" => passed ? "sol_exhaust_conservation_survivor" :
            "sol_exhaust_conservation_reject",
        "mesh_levels" => levels, "mesh_convergence" => mesh_change,
        "neutral_pumping_capacity_particles_s" => pump,
        "required_fuel_ash_throughput_particles_s" => 2reaction,
        "free_streaming_heat_flux_limit_w_m2" => free_stream,
        "gates" => gates, "failed_gates" => sort!([key for (key, value) in gates if !value]),
        "model_sources" => [
            "https://scientific-publications.ukaea.uk/wp-content/uploads/Published/Miss13.pdf",
            "https://www.iter.org/machine/divertor"],
        "evidence_level" => "sampled_candidate_bound",
        "complete_exhaust_obligation_credit" => false,
        "unsupported_candidate_classification_used" => false,
        "identity_fields_used_for_routing" => false,
        "claim_boundary" => MULTIREGION_CONSERVATION_PROVIDERS_V116_CLAIM_BOUNDARY)
    body["result_hash"] = canonical_hash(body); body
end

function select_v115_source_assemblies_v116(project_root::AbstractString)
    root = abspath(project_root); directory = joinpath(root, "runs",
        "v115_corrected_whole_device_rescreen_20260830")
    assemblies = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in
        readlines(joinpath(directory, "assemblies.jsonl")) if !isempty(strip(line))]
    screens = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in
        readlines(joinpath(directory, "screens.jsonl")) if !isempty(strip(line))]
    materials = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in
        readlines(joinpath(directory, "materials.jsonl")) if !isempty(strip(line))]
    passing_hashes = Set(String(row["physical_design_hash"]) for row in materials if
        row["status"] == "pass")
    screen_by_hash = Dict(String(row["physical_design_hash"]) => row for row in screens)
    eligible = [item for item in assemblies if String(item["physical_design_hash"]) in
        passing_hashes]
    groups = Dict{String,Vector{Dict{String,Any}}}()
    for assembly in eligible
        push!(get!(groups, String(assembly["source_candidate_result_hash"]),
            Dict{String,Any}[]), assembly)
    end
    selected = Dict{String,Any}[]
    for source_hash in sort!(collect(keys(groups)))
        ranked = sort!(groups[source_hash]; by = assembly -> begin
            screen = screen_by_hash[String(assembly["physical_design_hash"])]
            (-Float64(screen["outputs"]["net_electric_power_w"]),
                canonical_hash(assembly["physical_design"]))
        end)
        push!(selected, first(ranked))
    end
    selected
end

function run_multiregion_conservation_campaign_v116(project_root::AbstractString)
    root = abspath(project_root)
    reference = run_mission_aware_reference_acceptance_v103(root)
    reference["status"] == "pass" && reference["reference_regression_pass_count"] == 2 &&
        reference["new_reference_bypass_count"] == 0 || throw(ArgumentError(
        "v116 requires ITER/C-2W 2/2 with no bypass"))
    frontier = load_v114_provider_frontier_v115(root)
    candidates = Dict(String(item["candidate"]["result_hash"]) => item["candidate"]
        for item in frontier)
    assemblies = select_v115_source_assemblies_v116(root)
    rows = Dict{String,Any}[]
    for assembly in assemblies
        candidate = candidates[String(assembly["source_candidate_result_hash"])]
        transport = execute_core_edge_transport_provider_v116(candidate)
        exhaust = transport["status"] == "pass" ?
            execute_sol_exhaust_provider_v116(assembly, candidate) :
            Dict{String,Any}("status" => "not_executed_upstream_reject")
        state = transport["status"] == "pass" && exhaust["status"] == "pass" ?
            "conservation_provider_survivor" : "conservation_provider_reject"
        row = Dict{String,Any}(
            "source_candidate_result_hash" => candidate["result_hash"],
            "physical_design_hash" => assembly["physical_design_hash"],
            "transport" => transport, "exhaust" => exhaust,
            "candidate_state" => state, "whole_device_pass_credit" => false,
            "validation_credit" => false, "unsupported_candidate_classification_used" => false,
            "claim_boundary" => MULTIREGION_CONSERVATION_PROVIDERS_V116_CLAIM_BOUNDARY)
        row["result_hash"] = canonical_hash(row); push!(rows, row)
    end
    inventory = default_whole_device_provider_inventory_v104()
    push!(inventory, Dict("provider_key" => "multiregion_core_edge_transport_v116",
        "obligation_id" => "transport_and_confinement",
        "evidence_level" => "sampled_candidate_bound", "status" => "available",
        "input_contract" => ["operating_point", "core_edge_finite_volume_graph",
            "three_mesh_levels", "analytic_solution_audit"]))
    push!(inventory, Dict("provider_key" => "spitzer_harm_sol_exhaust_v116",
        "obligation_id" => "particle_and_heat_exhaust",
        "evidence_level" => "sampled_candidate_bound", "status" => "available",
        "input_contract" => ["edge_exhaust", "field_aligned_finite_volume_graph",
            "three_mesh_levels", "analytic_solution_audit"]))
    post_preflight = isempty(assemblies) ? nothing : compile_whole_device_preflight_v104(
        candidates[String(first(assemblies)["source_candidate_result_hash"])][
            "capability_profile"]; providers = inventory)
    survivors = count(row -> row["candidate_state"] == "conservation_provider_survivor", rows)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V116_PROTOCOL_ID,
        "status" => "complete", "reference_regression_pass_count" => 2,
        "reference_bypass_count" => 0,
        "source_reference_acceptance_hash" => reference["acceptance_hash"],
        "selected_source_candidate_count" => length(rows),
        "transport_pass_count" => count(row -> row["transport"]["status"] == "pass", rows),
        "exhaust_pass_count" => count(row -> row["exhaust"]["status"] == "pass", rows),
        "conservation_provider_survivor_count" => survivors,
        "conservation_provider_reject_count" => length(rows) - survivors,
        "post_v116_preflight_status" => post_preflight === nothing ? "not_executed" :
            post_preflight["status"],
        "post_v116_closed_obligation_count" => post_preflight === nothing ? 0 :
            post_preflight["closed_obligation_count"],
        "post_v116_fidelity_gap_count" => post_preflight === nothing ? 0 :
            post_preflight["fidelity_gap_count"],
        "post_v116_provider_gap_count" => post_preflight === nothing ? 0 :
            post_preflight["provider_gap_count"],
        "post_v116_preflight_hash" => post_preflight === nothing ? nothing :
            post_preflight["preflight_hash"],
        "unsupported_candidate_count" => 0, "provider_system_failure_count" => count(row ->
            row["transport"]["status"] == "provider_failure" ||
            row["exhaust"]["status"] == "provider_failure", rows),
        "whole_device_credible_count" => 0, "validation_pass_count" => 0,
        "complete_transport_obligation_credit" => false,
        "complete_exhaust_obligation_credit" => false,
        "partial_subgraph_promotion_allowed" => false,
        "rows" => rows, "claim_boundary" =>
            MULTIREGION_CONSERVATION_PROVIDERS_V116_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body); body
end
