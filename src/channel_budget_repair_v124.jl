const V124_PROTOCOL_ID = "fusionconceptai-v124-channel-budget-repair-20260830"

const CHANNEL_BUDGET_REPAIR_V124_CLAIM_BOUNDARY =
    "v124 replaces the fixed 200 kPa assembly pumping proxy with an explicit 80 kPa loop " *
    "budget and searches 55/60/65 K coolant rises. The detailed channel provider must " *
    "independently solve an actual pressure drop no greater than that same budget, retain " *
    "50-percent-flow EUROFER temperature margin, and retain the 100 MW updated net-electric " *
    "gate. Passing remains sampled 1D numerical VVUQ, not complete engineering or validation."

const V124_COOLANT_DELTA_T_K = [55.0, 60.0, 65.0]
const V124_PRIMARY_PRESSURE_DROP_BUDGET_PA = 80_000.0

function generate_channel_budget_repair_assemblies_v124(candidate_raw)
    assemblies = generate_corrected_whole_device_assemblies_v115(candidate_raw;
        coolant_delta_t_values = V124_COOLANT_DELTA_T_K)
    for assembly in assemblies
        design = Dict{String,Any}(assembly["physical_design"])
        thermal = Dict{String,Any}(design["thermal_cycle"])
        thermal["primary_pressure_drop_pa"] = V124_PRIMARY_PRESSURE_DROP_BUDGET_PA
        thermal["sizing_rule"] = "declared_loop_budget_and_fault_temperature_scan_v124"
        design["thermal_cycle"] = thermal
        design["protocol_id"] = V124_PROTOCOL_ID
        design["claim_boundary"] = CHANNEL_BUDGET_REPAIR_V124_CLAIM_BOUNDARY
        assembly["physical_design"] = design
        assembly["claim_boundary"] = CHANNEL_BUDGET_REPAIR_V124_CLAIM_BOUNDARY
        _v115_rehash_assembly!(assembly)
    end
    assemblies
end

function run_channel_budget_repair_full_chain_v124(project_root::AbstractString, bundle_raw)
    body, artifacts = run_repaired_full_device_chain_v118(project_root, bundle_raw;
        assembly_generator = generate_channel_budget_repair_assemblies_v124)
    body["protocol_id"] = V124_PROTOCOL_ID
    body["thermal_cycle_proposal_delta_t_k"] = V124_COOLANT_DELTA_T_K
    body["declared_primary_pressure_drop_budget_pa"] =
        V124_PRIMARY_PRESSURE_DROP_BUDGET_PA
    body["claim_boundary"] = CHANNEL_BUDGET_REPAIR_V124_CLAIM_BOUNDARY
    pop!(body, "acceptance_hash", nothing); body["acceptance_hash"] = canonical_hash(body)
    body, artifacts
end
