const V122_PROTOCOL_ID = "fusionconceptai-v122-thermal-cycle-repair-20260830"

const THERMAL_CYCLE_REPAIR_V122_CLAIM_BOUNDARY =
    "v122 extends the explicitly declared helium coolant temperature-rise proposal grid " *
    "to 130/140/150 K after a 90/110/120 K assembly front missed the 100 MW net-electric " *
    "mission gate. Pumping, outlet temperature, dynamic faults, source-pinned materials, " *
    "multi-region conservation and three-level channel thermal hydraulics are recomputed. " *
    "A numerical survivor remains incomplete stability/transport and validation pending."

const V122_COOLANT_DELTA_T_K = [130.0, 140.0, 150.0]

function generate_thermal_cycle_repair_assemblies_v122(candidate_raw)
    assemblies = generate_corrected_whole_device_assemblies_v115(candidate_raw;
        coolant_delta_t_values = V122_COOLANT_DELTA_T_K)
    for assembly in assemblies
        design = Dict{String,Any}(assembly["physical_design"])
        design["protocol_id"] = V122_PROTOCOL_ID
        design["thermal_cycle"]["sizing_rule"] =
            "candidate_power_balance_declared_delta_t_v122"
        design["claim_boundary"] = THERMAL_CYCLE_REPAIR_V122_CLAIM_BOUNDARY
        assembly["physical_design"] = design
        assembly["claim_boundary"] = THERMAL_CYCLE_REPAIR_V122_CLAIM_BOUNDARY
        _v115_rehash_assembly!(assembly)
    end
    assemblies
end

function run_thermal_cycle_repair_full_chain_v122(project_root::AbstractString, bundle_raw)
    body, artifacts = run_repaired_full_device_chain_v118(project_root, bundle_raw;
        assembly_generator = generate_thermal_cycle_repair_assemblies_v122)
    body["protocol_id"] = V122_PROTOCOL_ID
    body["thermal_cycle_proposal_delta_t_k"] = V122_COOLANT_DELTA_T_K
    body["claim_boundary"] = THERMAL_CYCLE_REPAIR_V122_CLAIM_BOUNDARY
    pop!(body, "acceptance_hash", nothing); body["acceptance_hash"] = canonical_hash(body)
    body, artifacts
end
