function fmi_adapter_manifest_minimal_v1()
    return Dict("adapter_id" => "fmi_adapter_minimal_v1", "standard" => "FMI",
        "purpose" => "model_packaging_and_interface_metadata_only",
        "co_simulation_algorithm_provided" => false,
        "required_external_contract" => "CouplingContractV1",
        "family_routing" => false, "status" => "prototype")
end

