const V117_PROTOCOL_ID = "fusionconceptai-v117-channel-thermal-hydraulics-20260830"

const CHANNEL_THERMAL_HYDRAULICS_V117_CLAIM_BOUNDARY =
    "v117 generates explicit helium-channel overlays and solves nominal and 50-percent-flow " *
    "axial energy graphs at three mesh levels through the v94 registry and whole-graph " *
    "assembler. Gnielinski heat transfer, Petukhov smooth-tube friction, a 20-percent " *
    "one-sided heat-transfer derating, coolant pumping power and source-pinned EUROFER " *
    "temperature limits are evaluated candidate-by-candidate. A pass is a one-dimensional " *
    "lumped channel screen, not 3D conjugate CFD, manifold/maldistribution qualification, " *
    "irradiation damage, LOCA safety, component certification or whole-device evidence."

const V117_MESH_LEVELS = [17, 33, 65]
const V117_HYDRAULIC_DIAMETERS_M = [0.005, 0.010]
const V117_FLOW_PATH_LENGTHS_M = [1.0, 2.0, 4.0, 6.0, 8.0]
const V117_TARGET_VELOCITIES_M_S = [75.0, 125.0, 175.0]
const V117_HELIUM_DYNAMIC_VISCOSITY_PA_S = 3.5e-5
const V117_HELIUM_THERMAL_CONDUCTIVITY_W_M_K = 0.26
const V117_HEAT_TRANSFER_DERATING = 0.80

function _v117_registry()
    registry = OperatorProviderRegistryV94()
    register_provider_v94!(registry, ProviderCapabilityV94(
        "coolant_axial_energy_v117", "available", ["coolant_temperature"],
        ["steady_advection_energy"], String[], ["finite_volume_1d"], [1],
        ["normalized_channel_axial"], ["residual_jacobian_fragment"], "v117-20260830"),
        _declared_linear_fragment_v94)
    register_provider_v94!(registry, ProviderCapabilityV94(
        "coolant_inlet_boundary_v117", "available", ["coolant_temperature"],
        String[], ["fixed_inlet_temperature"], ["finite_volume_1d"], [1],
        ["normalized_channel_axial"], ["residual_jacobian_fragment"], "v117-20260830"),
        _declared_linear_fragment_v94)
    registry
end

function generate_channel_overlays_v117(assembly_raw)
    assembly = Dict{String,Any}(_v93_plain(assembly_raw))
    thermal = assembly["physical_design"]["thermal_cycle"]
    density = Float64(thermal["coolant_density_kg_m3"])
    mass_flow = Float64(thermal["mass_flow_kg_s"])
    overlays = Dict{String,Any}[]; sequence = 0
    for diameter in V117_HYDRAULIC_DIAMETERS_M,
            length_m in V117_FLOW_PATH_LENGTHS_M,
            target_velocity in V117_TARGET_VELOCITIES_M_S
        sequence += 1
        flow_area = pi * diameter^2 / 4
        channels = ceil(Int, mass_flow / (density * target_velocity * flow_area))
        design = Dict{String,Any}(
            "schema_version" => "1.0.0", "protocol_id" => V117_PROTOCOL_ID,
            "sequence_index" => sequence, "hydraulic_diameter_m" => diameter,
            "parallel_channel_count" => channels, "flow_path_length_m" => length_m,
            "target_nominal_velocity_m_s" => target_velocity,
            "maximum_pressure_drop_pa" => 4.0e6,
            "maximum_mach_number" => 0.30,
            "heat_transfer_derating" => V117_HEAT_TRANSFER_DERATING,
            "identity_fields_used_for_generation" => false,
            "basis_direct_metric_credit" => false,
            "claim_boundary" => CHANNEL_THERMAL_HYDRAULICS_V117_CLAIM_BOUNDARY)
        design["channel_design_hash"] = canonical_hash(design)
        body = Dict{String,Any}(
            "physical_design_hash" => assembly["physical_design_hash"],
            "channel_design" => design, "channel_design_hash" => design["channel_design_hash"],
            "candidate_state" => "channel_overlay_proposal",
            "physical_pass_credit" => false, "validation_credit" => false,
            "unsupported_candidate_classification_used" => false)
        body["overlay_hash"] = canonical_hash(body); push!(overlays, body)
    end
    overlays
end

function compile_coolant_channel_graph_v117(assembly_raw, overlay_raw;
        points::Integer = 33, flow_fraction::Real = 1.0)
    points in V117_MESH_LEVELS || throw(ArgumentError("unsupported v117 mesh level"))
    0 < flow_fraction <= 1 || throw(ArgumentError("invalid v117 flow fraction"))
    assembly = Dict{String,Any}(_v93_plain(assembly_raw))
    overlay = Dict{String,Any}(_v93_plain(overlay_raw))
    assembly["physical_design_hash"] == overlay["physical_design_hash"] ||
        throw(ArgumentError("v117 assembly/overlay binding mismatch"))
    thermal = assembly["physical_design"]["thermal_cycle"]
    design = overlay["channel_design"]
    grid = collect(range(0.0, 1.0; length = points))
    mass_flow = flow_fraction * Float64(thermal["mass_flow_kg_s"])
    cp = Float64(thermal["specific_heat_j_kg_k"])
    heat = Float64(thermal["recoverable_heat_input_w"])
    variables = [Dict("variable_key" => "coolant:$index", "region_key" => "channel",
        "physical_state" => "coolant_temperature", "function_space" => "finite_volume_1d")
        for index in 0:(points - 1)]
    equations = Dict{String,Any}[]; segment_heat = heat / (points - 1)
    for index in 1:(points - 1)
        row = "coolant:eq:$index"
        push!(equations, Dict("equation_key" => "coolant:$index",
            "region_key" => "channel", "row_key" => row,
            "operator" => "steady_advection_energy",
            "required_fields" => ["coolant_mass_flow", "recoverable_heat"],
            "terms" => [_v116_term(row, "coolant:$(index - 1)", -mass_flow * cp),
                _v116_term(row, "coolant:$index", mass_flow * cp)],
            "rhs" => segment_heat))
    end
    inlet_row = "coolant:boundary:inlet"
    Dict{String,Any}(
        "regions" => [Dict("region_key" => "channel", "dimension" => 1,
            "coordinate" => "normalized_channel_axial",
            "variable_keys" => String[item["variable_key"] for item in variables],
            "equation_keys" => String[item["equation_key"] for item in equations])],
        "variables" => variables, "equations" => equations, "interfaces" => Any[],
        "boundaries" => [Dict("boundary_key" => "inlet", "region_key" => "channel",
            "row_key" => inlet_row, "condition" => "fixed_inlet_temperature",
            "terms" => [_v116_term(inlet_row, "coolant:0", 1.0)],
            "rhs" => Float64(thermal["inlet_temperature_k"]))],
        "fields" => [
            Dict("field_key" => "coolant_mass_flow", "class" => "recovered",
                "available" => true, "value" => mass_flow),
            Dict("field_key" => "recoverable_heat", "class" => "recovered",
                "available" => true, "value" => heat)],
        "observables" => Dict("grid_m" => grid, "mass_flow_kg_s" => mass_flow,
            "specific_heat_j_kg_k" => cp, "recoverable_heat_w" => heat,
            "analytic_outlet_temperature_k" => Float64(thermal["inlet_temperature_k"]) +
                heat / (mass_flow * cp)),
        "claim_boundary" => CHANNEL_THERMAL_HYDRAULICS_V117_CLAIM_BOUNDARY)
end

function _v117_channel_level(assembly, overlay, points, flow_fraction)
    graph = compile_coolant_channel_graph_v117(assembly, overlay;
        points = points, flow_fraction = flow_fraction)
    assembled = assemble_graph_residual_jacobian_v94(graph, _v117_registry())
    solve = solve_graph_system_v94(assembled)
    assembled.status == "closed" && solve["status"] == "pass" || return Dict(
        "points" => points, "status" => "provider_failure",
        "assembly" => graph_assembly_to_dict_v94(assembled), "solve" => solve)
    outlet = Float64(solve["state"][end])
    analytic = Float64(graph["observables"]["analytic_outlet_temperature_k"])
    body = Dict{String,Any}("points" => points, "status" => "pass",
        "assembly" => graph_assembly_to_dict_v94(assembled), "solve" => solve,
        "outlet_temperature_k" => outlet, "analytic_outlet_temperature_k" => analytic,
        "analytic_relative_error" => abs(outlet - analytic) / analytic)
    body["level_hash"] = canonical_hash(body); body
end

function _v117_level_summary(level)
    Dict{String,Any}(
        "points" => level["points"], "status" => level["status"],
        "assembly_hash" => get(level["assembly"], "assembly_hash", nothing),
        "solve_hash" => get(level["solve"], "solve_hash", nothing),
        "outlet_temperature_k" => get(level, "outlet_temperature_k", nothing),
        "analytic_outlet_temperature_k" => get(level,
            "analytic_outlet_temperature_k", nothing),
        "analytic_relative_error" => get(level, "analytic_relative_error", nothing),
        "level_hash" => get(level, "level_hash", nothing))
end

function _v117_hydraulics(assembly, overlay, flow_fraction)
    thermal = assembly["physical_design"]["thermal_cycle"]
    design = overlay["channel_design"]
    density = Float64(thermal["coolant_density_kg_m3"])
    cp = Float64(thermal["specific_heat_j_kg_k"])
    mass_flow = flow_fraction * Float64(thermal["mass_flow_kg_s"])
    diameter = Float64(design["hydraulic_diameter_m"])
    length_m = Float64(design["flow_path_length_m"])
    channels = Int(design["parallel_channel_count"])
    area = pi * diameter^2 / 4
    velocity = mass_flow / (density * channels * area)
    reynolds = density * velocity * diameter / V117_HELIUM_DYNAMIC_VISCOSITY_PA_S
    prandtl = cp * V117_HELIUM_DYNAMIC_VISCOSITY_PA_S /
        V117_HELIUM_THERMAL_CONDUCTIVITY_W_M_K
    friction = (0.79log(reynolds) - 1.64)^(-2)
    nusselt = (friction / 8) * (reynolds - 1000) * prandtl /
        (1 + 12.7sqrt(friction / 8) * (prandtl^(2 / 3) - 1))
    h = nusselt * V117_HELIUM_THERMAL_CONDUCTIVITY_W_M_K / diameter
    conservative_h = Float64(design["heat_transfer_derating"]) * h
    internal_area = channels * pi * diameter * length_m
    heat_flux = Float64(thermal["recoverable_heat_input_w"]) / internal_area
    film_rise = heat_flux / conservative_h
    pressure_drop = friction * length_m / diameter * density * velocity^2 / 2
    sound_speed = sqrt(1.66 * 2077.1 * Float64(thermal["outlet_temperature_k"]))
    Dict{String,Any}(
        "flow_fraction" => flow_fraction, "mass_flow_kg_s" => mass_flow,
        "actual_velocity_m_s" => velocity, "mach_number" => velocity / sound_speed,
        "reynolds_number" => reynolds, "prandtl_number" => prandtl,
        "petukhov_friction_factor" => friction, "gnielinski_nusselt_number" => nusselt,
        "raw_heat_transfer_coefficient_w_m2_k" => h,
        "conservative_heat_transfer_coefficient_w_m2_k" => conservative_h,
        "internal_heat_transfer_area_m2" => internal_area,
        "internal_heat_flux_w_m2" => heat_flux, "film_temperature_rise_k" => film_rise,
        "pressure_drop_pa" => pressure_drop)
end

function execute_channel_thermal_hydraulics_v117(assembly_raw, overlay_raw,
        screen_raw, catalog_raw; nominal_levels_raw = nothing, fault_levels_raw = nothing)
    assembly = Dict{String,Any}(_v93_plain(assembly_raw))
    overlay = Dict{String,Any}(_v93_plain(overlay_raw))
    screen = Dict{String,Any}(_v93_plain(screen_raw))
    catalog = Dict{String,Any}(_v93_plain(catalog_raw))
    assembly["physical_design_hash"] == screen["physical_design_hash"] ||
        throw(ArgumentError("v117 assembly/screen binding mismatch"))
    records = _v109_record_index(catalog)
    temperature_limit = Float64(records["eurofer_blanket_structure_temperature"]["value"])
    nominal_levels = nominal_levels_raw === nothing ?
        [_v117_channel_level(assembly, overlay, points, 1.0)
            for points in V117_MESH_LEVELS] : nominal_levels_raw
    fault_levels = fault_levels_raw === nothing ?
        [_v117_channel_level(assembly, overlay, points, 0.5)
            for points in V117_MESH_LEVELS] : fault_levels_raw
    numerical_pass = all(level -> level["status"] == "pass" &&
        level["analytic_relative_error"] <= 1e-10, vcat(nominal_levels, fault_levels))
    nominal_hydraulic = _v117_hydraulics(assembly, overlay, 1.0)
    fault_hydraulic = _v117_hydraulics(assembly, overlay, 0.5)
    nominal_outlet = Float64(nominal_levels[end]["outlet_temperature_k"])
    fault_outlet = Float64(fault_levels[end]["outlet_temperature_k"])
    nominal_structure = nominal_outlet + Float64(nominal_hydraulic[
        "film_temperature_rise_k"])
    fault_structure = fault_outlet + Float64(fault_hydraulic["film_temperature_rise_k"])
    thermal = assembly["physical_design"]["thermal_cycle"]
    new_pump = Float64(thermal["mass_flow_kg_s"]) *
        Float64(nominal_hydraulic["pressure_drop_pa"]) /
        (Float64(thermal["coolant_density_kg_m3"]) * Float64(thermal["pump_efficiency"]))
    outputs = screen["outputs"]
    updated_net = Float64(outputs["net_electric_power_w"]) +
        Float64(outputs["primary_pump_power_w"]) - new_pump
    design = overlay["channel_design"]
    re_nominal = Float64(nominal_hydraulic["reynolds_number"])
    re_fault = Float64(fault_hydraulic["reynolds_number"])
    pr = Float64(nominal_hydraulic["prandtl_number"])
    gates = Dict{String,Bool}(
        "whole_graph_numerical_vvuq" => numerical_pass,
        "gnielinski_nominal_domain" => 3000 <= re_nominal <= 5.0e6 && 0.5 <= pr <= 2000,
        "gnielinski_fault_domain" => 3000 <= re_fault <= 5.0e6 && 0.5 <= pr <= 2000,
        "fully_developed_path" => Float64(design["flow_path_length_m"]) /
            Float64(design["hydraulic_diameter_m"]) >= 10,
        "subsonic_velocity" => Float64(nominal_hydraulic["mach_number"]) <=
            Float64(design["maximum_mach_number"]),
        "pressure_drop" => Float64(nominal_hydraulic["pressure_drop_pa"]) <=
            Float64(design["maximum_pressure_drop_pa"]),
        "nominal_structure_temperature" => nominal_structure <= temperature_limit,
        "loss_of_flow_structure_temperature" => fault_structure <= temperature_limit,
        "updated_net_electric_power" => updated_net >= 100.0e6)
    passed = all(values(gates))
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V117_PROTOCOL_ID,
        "source_candidate_result_hash" => assembly["source_candidate_result_hash"],
        "physical_design_hash" => assembly["physical_design_hash"],
        "channel_design_hash" => overlay["channel_design_hash"],
        "channel_design" => deepcopy(overlay["channel_design"]),
        "status" => passed ? "pass" : "fail",
        "candidate_state" => passed ? "channel_thermal_hydraulics_survivor" :
            "channel_thermal_hydraulics_reject",
        "nominal_mesh_levels" => _v117_level_summary.(nominal_levels),
        "fault_mesh_levels" => _v117_level_summary.(fault_levels),
        "nominal_hydraulics" => nominal_hydraulic, "fault_hydraulics" => fault_hydraulic,
        "nominal_structure_temperature_k" => nominal_structure,
        "loss_of_flow_structure_temperature_k" => fault_structure,
        "temperature_limit_k" => temperature_limit,
        "updated_primary_pump_power_w" => new_pump,
        "updated_net_electric_power_w" => updated_net,
        "gates" => gates, "failed_gates" => sort!([key for (key, value) in gates if !value]),
        "model_sources" => [
            "https://mooseframework.inl.gov/docs/site/source/scmclosures/SCMHTCGnielinski.html",
            "https://inldigitallibrary.inl.gov/content/uploads/50/2026/04/6899506.pdf",
            records["eurofer_blanket_structure_temperature"]["source_url"]],
        "evidence_level" => "sampled_candidate_bound",
        "complete_thermal_hydraulics_credit" => false,
        "whole_device_pass_credit" => false, "validation_credit" => false,
        "unsupported_candidate_classification_used" => false,
        "identity_fields_used_for_routing" => false,
        "claim_boundary" => CHANNEL_THERMAL_HYDRAULICS_V117_CLAIM_BOUNDARY)
    body["result_hash"] = canonical_hash(body); body
end

function select_v116_survivor_assemblies_v117(project_root::AbstractString)
    root = abspath(project_root)
    v116_rows = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in readlines(
        joinpath(root, "runs", "v116_multiregion_conservation_20260830",
            "provider_results.jsonl")) if !isempty(strip(line))]
    transport_sources = Set(String(row["source_candidate_result_hash"]) for row in v116_rows
        if row["transport"]["status"] == "pass")
    material_rows = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in readlines(
        joinpath(root, "runs", "v115_corrected_whole_device_rescreen_20260830",
            "materials.jsonl")) if !isempty(strip(line))]
    material_hashes = Set(String(row["physical_design_hash"]) for row in material_rows
        if row["status"] == "pass")
    assemblies = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in readlines(
        joinpath(root, "runs", "v115_corrected_whole_device_rescreen_20260830",
            "assemblies.jsonl")) if !isempty(strip(line))]
    eligible = [assembly for assembly in assemblies if
        String(assembly["physical_design_hash"]) in material_hashes &&
        String(assembly["source_candidate_result_hash"]) in transport_sources]
    screens = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in readlines(
        joinpath(root, "runs", "v115_corrected_whole_device_rescreen_20260830",
            "screens.jsonl")) if !isempty(strip(line))]
    screen_by_hash = Dict(String(row["physical_design_hash"]) => row for row in screens)
    groups = Dict{Tuple{String,Float64,Float64},Vector{Dict{String,Any}}}()
    for assembly in eligible
        design = assembly["physical_design"]
        key = (String(assembly["source_candidate_result_hash"]),
            Float64(design["thermal_cycle"]["declared_coolant_delta_t_k"]),
            Float64(design["edge_exhaust"]["target_wetted_area_m2"]))
        push!(get!(groups, key, Dict{String,Any}[]), assembly)
    end
    representatives = Dict{String,Any}[]
    for key in sort!(collect(keys(groups)); by = canonical_hash)
        ranked = sort!(groups[key]; by = assembly -> begin
            screen = screen_by_hash[String(assembly["physical_design_hash"])]
            (-Float64(screen["outputs"]["net_electric_power_w"]),
                canonical_hash(assembly["physical_design"]))
        end)
        push!(representatives, first(ranked))
    end
    frontier = load_v114_provider_frontier_v115(root)
    candidates = Dict(String(item["candidate"]["result_hash"]) => item["candidate"]
        for item in frontier)
    exhaust_cache = Dict{Tuple{String,Float64},Bool}()
    selected = Dict{String,Any}[]
    for assembly in representatives
        source_hash = String(assembly["source_candidate_result_hash"])
        area = Float64(assembly["physical_design"]["edge_exhaust"][
            "target_wetted_area_m2"])
        passed = get!(exhaust_cache, (source_hash, area)) do
            execute_sol_exhaust_provider_v116(assembly, candidates[source_hash])[
                "status"] == "pass"
        end
        passed && push!(selected, assembly)
    end
    selected
end

function run_channel_thermal_hydraulics_campaign_v117(project_root::AbstractString)
    root = abspath(project_root)
    reference = run_mission_aware_reference_acceptance_v103(root)
    reference["status"] == "pass" && reference["reference_regression_pass_count"] == 2 &&
        reference["new_reference_bypass_count"] == 0 || throw(ArgumentError(
        "v117 requires ITER/C-2W 2/2 with no bypass"))
    assemblies = select_v116_survivor_assemblies_v117(root)
    screens = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in readlines(joinpath(root,
        "runs", "v115_corrected_whole_device_rescreen_20260830", "screens.jsonl"))
        if !isempty(strip(line))]
    screen_by_hash = Dict(String(row["physical_design_hash"]) => row for row in screens)
    catalog = load_material_property_catalog_v109(root)
    rows = Dict{String,Any}[]
    level_cache = Dict{Tuple{String,Float64},Tuple{Any,Any}}()
    for assembly in assemblies, overlay in generate_channel_overlays_v117(assembly)
        thermal = assembly["physical_design"]["thermal_cycle"]
        cache_key = (canonical_hash(Dict(
            "inlet_temperature_k" => thermal["inlet_temperature_k"],
            "mass_flow_kg_s" => thermal["mass_flow_kg_s"],
            "specific_heat_j_kg_k" => thermal["specific_heat_j_kg_k"],
            "recoverable_heat_input_w" => thermal["recoverable_heat_input_w"])), 0.0)
        nominal_levels, fault_levels = get!(level_cache, cache_key) do
            ([_v117_channel_level(assembly, overlay, points, 1.0)
                for points in V117_MESH_LEVELS],
             [_v117_channel_level(assembly, overlay, points, 0.5)
                for points in V117_MESH_LEVELS])
        end
        push!(rows, execute_channel_thermal_hydraulics_v117(assembly, overlay,
            screen_by_hash[String(assembly["physical_design_hash"])], catalog;
            nominal_levels_raw = nominal_levels, fault_levels_raw = fault_levels))
    end
    survivors = [row for row in rows if row["status"] == "pass"]
    unique_assemblies = unique(String(row["physical_design_hash"]) for row in survivors)
    unique_sources = unique(String(row["source_candidate_result_hash"]) for row in survivors)
    blockers = Dict{String,Int}()
    for row in rows, gate in String.(row["failed_gates"])
        blockers[gate] = get(blockers, gate, 0) + 1
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V117_PROTOCOL_ID,
        "status" => "complete", "reference_regression_pass_count" => 2,
        "reference_bypass_count" => 0,
        "source_reference_acceptance_hash" => reference["acceptance_hash"],
        "source_v116_acceptance_hash" => _v115_read_json(joinpath(root, "runs",
            "v116_multiregion_conservation_20260830", "acceptance.json"))[
                "acceptance_hash"],
        "source_v115_acceptance_hash" => _v115_read_json(joinpath(root, "runs",
            "v115_corrected_whole_device_rescreen_20260830", "acceptance.json"))[
                "acceptance_hash"],
        "source_assembly_count" => length(assemblies),
        "channel_overlay_count" => length(rows),
        "channel_thermal_hydraulics_survivor_count" => length(survivors),
        "unique_survivor_assembly_count" => length(unique_assemblies),
        "unique_survivor_source_candidate_count" => length(unique_sources),
        "channel_thermal_hydraulics_reject_count" => length(rows) - length(survivors),
        "blocker_histogram" => Dict(sort!(collect(blockers))),
        "unsupported_candidate_count" => 0,
        "provider_system_failure_count" => count(row -> any(level ->
            level["status"] == "provider_failure", vcat(row["nominal_mesh_levels"],
                row["fault_mesh_levels"])), rows),
        "whole_device_credible_count" => 0, "validation_pass_count" => 0,
        "complete_thermal_hydraulics_credit" => false,
        "partial_subgraph_promotion_allowed" => false,
        "rows" => rows, "claim_boundary" => CHANNEL_THERMAL_HYDRAULICS_V117_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body); body
end
