const V123_PROTOCOL_ID = "fusionconceptai-v123-material-thermal-window-repair-20260830"

const MATERIAL_THERMAL_WINDOW_REPAIR_V123_CLAIM_BOUNDARY =
    "v123 searches the narrow 122/124/125 K coolant temperature-rise interval implied " *
    "jointly by the 100 MW net-electric lower bound and the source-pinned 823.15 K EUROFER " *
    "loss-of-flow upper bound. All assembly, fault, material, conservation and channel " *
    "providers rerun. A survivor remains complete-physics and external-validation pending."

const V123_COOLANT_DELTA_T_K = [122.0, 124.0, 125.0]

function generate_material_thermal_window_assemblies_v123(candidate_raw)
    assemblies = generate_corrected_whole_device_assemblies_v115(candidate_raw;
        coolant_delta_t_values = V123_COOLANT_DELTA_T_K)
    for assembly in assemblies
        design = Dict{String,Any}(assembly["physical_design"])
        design["protocol_id"] = V123_PROTOCOL_ID
        design["thermal_cycle"]["sizing_rule"] =
            "joint_net_power_material_temperature_window_v123"
        design["claim_boundary"] = MATERIAL_THERMAL_WINDOW_REPAIR_V123_CLAIM_BOUNDARY
        assembly["physical_design"] = design
        assembly["claim_boundary"] = MATERIAL_THERMAL_WINDOW_REPAIR_V123_CLAIM_BOUNDARY
        _v115_rehash_assembly!(assembly)
    end
    assemblies
end

function run_material_thermal_window_full_chain_v123(project_root::AbstractString,
        bundle_raw)
    body, artifacts = run_repaired_full_device_chain_v118(project_root, bundle_raw;
        assembly_generator = generate_material_thermal_window_assemblies_v123)
    body["protocol_id"] = V123_PROTOCOL_ID
    body["thermal_cycle_proposal_delta_t_k"] = V123_COOLANT_DELTA_T_K
    body["claim_boundary"] = MATERIAL_THERMAL_WINDOW_REPAIR_V123_CLAIM_BOUNDARY
    pop!(body, "acceptance_hash", nothing); body["acceptance_hash"] = canonical_hash(body)
    body, artifacts
end
