const V109_PROTOCOL_ID = "fusionconceptai-v109-material-engineering-screen-20260829"

const MATERIAL_ENGINEERING_PROVIDER_V109_CLAIM_BOUNDARY =
    "v109 applies source-pinned, one-sided conservative material and radial-build " *
    "rejection gates to v108 dynamic survivors. A failed computed gate rejects that exact " *
    "assembly/controller design. Passing every computed gate would remain a reduced screen " *
    "only: 3D neutronics, irradiation damage and lifetime, detailed thermal hydraulics, " *
    "component stress/strain, joints, fatigue, manufacturing, numerical VVUQ and validation " *
    "remain independent obligations. Missing catalog data is a provider-system failure, never " *
    "a candidate unsupported or physical-failure classification."

const V109_REQUIRED_RECORDS = Set([
    "full_nuclear_radial_build_tokamak_scope",
    "iter_tungsten_divertor_steady_heat_flux",
    "eurofer_blanket_structure_temperature",
    "rebco_high_field_screen",
    "tokamak_overall_winding_current_density_scope",
    "iter_316ln_support_screen",
    "eu_demo_coil_neutronics_limits",
])

function _v109_source_record_hash(record_raw)
    record = Dict{String,Any}(_v93_plain(record_raw))
    pop!(record, "source_assertion_hash", nothing)
    canonical_hash(record)
end

function _v109_catalog_hash(catalog_raw)
    catalog = Dict{String,Any}(_v93_plain(catalog_raw))
    records = Dict{String,Any}.(catalog["records"])
    sort!(records; by = item -> String(item["record_id"]))
    body = Dict{String,Any}(
        "schema_version" => catalog["schema_version"],
        "catalog_id" => catalog["catalog_id"], "records" => records,
        "record_count" => length(records),
        "claim_boundary" => catalog["claim_boundary"])
    canonical_hash(body)
end

function material_screen_provider_capability_v109()
    ProviderCapabilityV94(
        "source_pinned_material_engineering_screen_v109", "available",
        ["heat_flux", "temperature", "electromagnetic_load", "stress", "radial_build"],
        ["engineering_rejection_screen"],
        ["plasma_wall", "blanket_shield", "coil_support", "coolant_fault"],
        ["candidate_bound_lumped_component"], [0, 1, 2, 3],
        ["component_geometry"], ["conservative_component_gate_inventory"],
        "v109-20260829")
end

function material_screen_requirement_v109()
    CapabilityRequirementV94(
        "whole_device_material_rejection_screen", "additional_operator",
        ["heat_flux", "temperature", "electromagnetic_load", "stress", "radial_build"],
        "engineering_rejection_screen", nothing,
        ["candidate_bound_lumped_component"], 3, "component_geometry",
        "conservative_component_gate_inventory",
        Dict{String,Any}("candidate_identity_fields_required" => false))
end

function load_material_property_catalog_v109(project_root::AbstractString;
        path = joinpath(abspath(project_root), "knowledge",
            "whole_device_material_catalog_v109.json"))
    isfile(path) || throw(ArgumentError("missing v109 material catalog: $path"))
    catalog = Dict{String,Any}(_v93_plain(JSON3.read(read(path, String))))
    catalog["schema_version"] == "1.0.0" ||
        throw(ArgumentError("unsupported v109 material catalog schema"))
    records = Dict{String,Any}.(catalog["records"])
    ids = String[String(record["record_id"]) for record in records]
    length(ids) == length(unique(ids)) || throw(ArgumentError(
        "duplicate v109 material catalog record"))
    missing = sort!(collect(setdiff(V109_REQUIRED_RECORDS, Set(ids))))
    isempty(missing) || throw(ArgumentError(
        "missing v109 material catalog records: $(join(missing, ","))"))
    required = ("record_id", "component_role", "quantity", "value", "unit",
        "gate_sense", "source_url", "source_locator", "source_scope",
        "screening_transform", "complete_qualification_credit")
    normalized = Dict{String,Any}[]
    for record in records
        absent = [key for key in required if !haskey(record, key)]
        isempty(absent) || throw(ArgumentError(
            "incomplete v109 record $(get(record, "record_id", "unknown")): " *
            join(absent, ",")))
        startswith(String(record["source_url"]), "https://") ||
            throw(ArgumentError("v109 source URL must use https"))
        record["complete_qualification_credit"] === false ||
            throw(ArgumentError("v109 catalog cannot grant qualification credit"))
        item = deepcopy(record)
        item["source_assertion_hash"] = _v109_source_record_hash(record)
        push!(normalized, item)
    end
    sort!(normalized; by = item -> String(item["record_id"]))
    body = Dict{String,Any}(
        "schema_version" => catalog["schema_version"],
        "catalog_id" => catalog["catalog_id"], "records" => normalized,
        "record_count" => length(normalized),
        "claim_boundary" => catalog["claim_boundary"])
    body["catalog_hash"] = _v109_catalog_hash(body)
    body
end

function audit_material_property_catalog_v109(catalog_raw)
    catalog = Dict{String,Any}(_v93_plain(catalog_raw))
    records = Dict{String,Any}.(catalog["records"])
    ids = Set(String(record["record_id"]) for record in records)
    missing = sort!(collect(setdiff(V109_REQUIRED_RECORDS, ids)))
    source_complete = all(record -> startswith(String(record["source_url"]), "https://") &&
        !isempty(String(record["source_locator"])) &&
        record["complete_qualification_credit"] === false &&
        get(record, "source_assertion_hash", nothing) ==
            _v109_source_record_hash(record), records)
    stored_hash = get(catalog, "catalog_hash", nothing)
    computed_hash = _v109_catalog_hash(catalog)
    integrity_pass = stored_hash == computed_hash
    body = Dict{String,Any}(
        "status" => isempty(missing) && source_complete && integrity_pass ?
            "closed_for_rejection_screen" : "provider_catalog_invalid",
        "missing_record_ids" => missing,
        "source_metadata_complete" => source_complete,
        "catalog_integrity_pass" => integrity_pass,
        "record_count" => length(records),
        "catalog_hash" => stored_hash,
        "complete_engineering_credit" => false,
        "unsupported_candidate_classification_used" => false)
    body["audit_hash"] = canonical_hash(body)
    body
end

function _v109_record_index(catalog)
    Dict(String(record["record_id"]) => Dict{String,Any}(record)
        for record in Dict{String,Any}.(catalog["records"]))
end

function _v109_gate(id, raw_value, conservative_value, record, passed)
    Dict{String,Any}(
        "gate_id" => String(id), "status" => passed ? "pass" : "fail",
        "raw_value" => raw_value, "conservative_value" => conservative_value,
        "threshold" => record["value"], "unit" => record["unit"],
        "gate_sense" => record["gate_sense"],
        "source_record_id" => record["record_id"],
        "source_assertion_hash" => record["source_assertion_hash"],
        "complete_qualification_credit" => false)
end

function execute_material_engineering_provider_v109(assembly_raw, screen_raw,
        dynamic_raw, catalog_raw)
    assembly = Dict{String,Any}(_v93_plain(assembly_raw))
    screen = Dict{String,Any}(_v93_plain(screen_raw))
    dynamic = Dict{String,Any}(_v93_plain(dynamic_raw))
    catalog = Dict{String,Any}(_v93_plain(catalog_raw))
    audit = audit_material_property_catalog_v109(catalog)
    audit["status"] == "closed_for_rejection_screen" || throw(ArgumentError(
        "v109 material catalog is not closed for rejection screening"))
    design_hash = String(assembly["physical_design_hash"])
    screen["status"] == "pass" || throw(ArgumentError(
        "v109 requires a v106 screen survivor"))
    dynamic["status"] == "pass" || throw(ArgumentError(
        "v109 requires a v108 dynamic survivor"))
    screen["physical_design_hash"] == design_hash || throw(ArgumentError(
        "v109 v106 assembly binding mismatch"))
    dynamic["physical_design_hash"] == design_hash || throw(ArgumentError(
        "v109 v108 assembly binding mismatch"))

    registry = OperatorProviderRegistryV94()
    register_provider_v94!(registry, material_screen_provider_capability_v109(),
        (_, _) -> nothing)
    route = route_provider_v94(registry, material_screen_requirement_v109())
    route["status"] == "closed" || throw(ArgumentError(
        "v109 provider capability route did not close"))

    records = _v109_record_index(catalog)
    design = Dict{String,Any}(assembly["physical_design"])
    thermal = Dict{String,Any}(design["thermal_cycle"])
    material_stack = Dict{String,Any}(design["material_stack"])
    outputs = Dict{String,Any}(screen["outputs"])
    loss_of_flow = only(item for item in Dict{String,Any}.(
        dynamic["scenario_results"]) if item["scenario_id"] == "loss_of_coolant_flow")

    radial = Float64(material_stack["total_plasma_to_wall_build_m"])
    exhaust = Float64(outputs["exhaust_heat_flux_w_m2"])
    nominal_temperature = Float64(thermal["outlet_temperature_k"])
    fault_temperature = Float64(loss_of_flow["pre_shutdown_outlet_temperature_k"])
    peak_field = Float64(outputs["peak_field_t"])
    current_density = Float64(outputs["engineering_current_density_a_m2"])
    support_stress = Float64(outputs["support_stress_pa"])

    radial_record = records["full_nuclear_radial_build_tokamak_scope"]
    heat_record = records["iter_tungsten_divertor_steady_heat_flux"]
    temperature_record = records["eurofer_blanket_structure_temperature"]
    field_record = records["rebco_high_field_screen"]
    current_record = records["tokamak_overall_winding_current_density_scope"]
    stress_record = records["iter_316ln_support_screen"]
    gates = Dict{String,Any}[
        _v109_gate("full_nuclear_radial_build", radial, radial, radial_record,
            radial >= Float64(radial_record["value"])),
        _v109_gate("divertor_steady_heat_flux", exhaust, 1.20exhaust, heat_record,
            1.20exhaust <= Float64(heat_record["value"])),
        _v109_gate("blanket_nominal_temperature", nominal_temperature,
            nominal_temperature, temperature_record,
            nominal_temperature <= Float64(temperature_record["value"])),
        _v109_gate("blanket_loss_of_flow_temperature", fault_temperature,
            fault_temperature, temperature_record,
            fault_temperature <= Float64(temperature_record["value"])),
        _v109_gate("rebco_peak_field", peak_field, 1.05peak_field, field_record,
            1.05peak_field <= Float64(field_record["value"])),
        _v109_gate("winding_current_density", current_density,
            1.10current_density, current_record,
            1.10current_density <= Float64(current_record["value"])),
        _v109_gate("cryogenic_support_stress", support_stress,
            1.05support_stress, stress_record,
            1.05support_stress <= Float64(stress_record["value"])),
    ]
    passed = all(gate -> gate["status"] == "pass", gates)
    unresolved = [
        "candidate_bound_3d_neutron_transport",
        "irradiation_damage_and_lifetime",
        "3d_component_thermal_hydraulics",
        "3d_component_stress_strain_fatigue_and_buckling",
        "conductor_joint_insulation_and_manufacturing_qualification",
    ]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V109_PROTOCOL_ID,
        "physical_design_hash" => design_hash,
        "controller_design_hash" => dynamic["controller_design_hash"],
        "status" => passed ? "pass" : "fail",
        "candidate_state" => passed ? "material_screen_survivor" :
            "material_screen_reject",
        "gates" => gates,
        "failed_gates" => String[gate["gate_id"] for gate in gates if
            gate["status"] == "fail"],
        "catalog_hash" => catalog["catalog_hash"],
        "catalog_audit_hash" => audit["audit_hash"],
        "provider_route_hash" => route["route_hash"],
        "uncomputed_complete_engineering_obligations" => unresolved,
        "complete_engineering_obligation_credit" => false,
        "whole_device_pass_credit" => false, "validation_credit" => false,
        "unsupported_candidate_classification_used" => false,
        "identity_fields_used_for_routing" => false,
        "evidence_ceiling" => "source_pinned_conservative_material_rejection_screen",
        "claim_boundary" => MATERIAL_ENGINEERING_PROVIDER_V109_CLAIM_BOUNDARY)
    body["result_hash"] = canonical_hash(body)
    body
end

function run_material_engineering_campaign_v109(project_root::AbstractString;
        catalog_path = joinpath(abspath(project_root), "knowledge",
            "whole_device_material_catalog_v109.json"))
    root = abspath(project_root)
    reference = run_mission_aware_reference_acceptance_v103(root)
    reference["status"] == "pass" || throw(ArgumentError(
        "v109 requires ITER/C-2W reference regression pass before candidate rescreen"))
    dynamic = run_dynamic_fault_campaign_v108(root)
    screen, _ = run_whole_device_assembly_screen_v106(root)
    generation, assemblies = run_whole_device_assembly_generation_v105(root)
    catalog = load_material_property_catalog_v109(root; path = catalog_path)
    audit = audit_material_property_catalog_v109(catalog)
    audit["status"] == "closed_for_rejection_screen" || throw(ArgumentError(
        "v109 catalog preflight failed"))
    assembly_by_hash = Dict(String(item["physical_design_hash"]) => item
        for item in assemblies)
    screen_by_hash = Dict(String(item["physical_design_hash"]) => item
        for item in screen["rows"] if item["status"] == "pass")
    rows = Dict{String,Any}[]
    for upstream in dynamic["rows"]
        upstream["status"] == "pass" || continue
        hash = String(upstream["physical_design_hash"])
        push!(rows, execute_material_engineering_provider_v109(
            assembly_by_hash[hash], screen_by_hash[hash], upstream, catalog))
    end
    histogram = Dict{String,Int}(); blockers = Dict{String,Int}()
    for row in rows
        state = String(row["candidate_state"])
        histogram[state] = get(histogram, state, 0) + 1
        for gate in String.(row["failed_gates"])
            blockers[gate] = get(blockers, gate, 0) + 1
        end
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V109_PROTOCOL_ID,
        "status" => "complete", "source_v108_acceptance_hash" =>
            dynamic["acceptance_hash"], "source_v106_acceptance_hash" =>
            screen["acceptance_hash"], "source_v105_acceptance_hash" =>
            generation["acceptance_hash"],
        "reference_regression_status" => reference["status"],
        "reference_regression_pass_count" => reference["reference_regression_pass_count"],
        "reference_bypass_count" => reference["new_reference_bypass_count"],
        "catalog_hash" => catalog["catalog_hash"],
        "catalog_audit" => audit,
        "input_dynamic_survivor_count" => length(rows),
        "candidate_state_histogram" => Dict(sort!(collect(histogram))),
        "material_screen_survivor_count" => count(row -> row["status"] == "pass", rows),
        "material_screen_reject_count" => count(row -> row["status"] == "fail", rows),
        "blocker_histogram" => Dict(sort!(collect(blockers))),
        "unsupported_candidate_count" => 0, "provider_system_failure_count" => 0,
        "whole_device_pass_count" => 0, "whole_device_credible_count" => 0,
        "validation_pass_count" => 0,
        "complete_engineering_obligation_credit" => false,
        "high_cost_expansion_authorized" => false,
        "identity_fields_used_for_routing" => false,
        "rows" => rows, "claim_boundary" =>
            MATERIAL_ENGINEERING_PROVIDER_V109_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body
end
