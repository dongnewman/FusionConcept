const UNIVERSAL_MULTIREGION_TOPOLOGY_V89_CLAIM_BOUNDARY =
    "Family-neutral multi-region topology compilation proves typed representability, conservation/interface consistency, and stable structural identity. It is not equilibrium, stability, transport, engineering, or experimental validation."

const V89_REGION_DIMENSIONS = Set(("0d", "1d", "2d", "3d"))
const V89_TIME_SEMANTICS = Set(("steady", "transient", "dae", "event_driven"))
const V89_BOUNDARY_KINDS = Set(("closed", "open", "mixed", "periodic",
    "material", "absorbing", "reflecting", "sheath", "free_boundary"))

struct UniversalMultiRegionTopologyV89
    schema_version::String
    regions::Vector{Dict{String,Any}}
    interfaces::Vector{Dict{String,Any}}
    boundaries::Vector{Dict{String,Any}}
    field_topologies::Vector{Dict{String,Any}}
    control_paths::Vector{Dict{String,Any}}
    event_transitions::Vector{Dict{String,Any}}
    operator_obligations::Vector{Dict{String,Any}}
    topology_hash::String
    isomorphism_hash::String
end

function _v89_plain(value)
    value isa AbstractDict && return Dict{String,Any}(String(key) =>
        _v89_plain(child) for (key, child) in pairs(value))
    value isa AbstractVector && return Any[_v89_plain(child) for child in value]
    value isa Tuple && return Any[_v89_plain(child) for child in value]
    return value
end

function _v89_assert_scientific_payload_label_free(value, path = "topology")
    forbidden = Set(("family", "device_family", "device_type", "parent",
        "parent_family", "display_name", "benchmark", "benchmark_flag",
        "sentinel_name", "known_device_name"))
    if value isa AbstractDict
        for (key_any, child) in pairs(value)
            key = lowercase(String(key_any))
            key in forbidden && throw(ArgumentError(
                "label/benchmark field is forbidden in scientific payload at $path.$key"))
            _v89_assert_scientific_payload_label_free(child, "$path.$key")
        end
    elseif value isa AbstractVector
        for (index, child) in enumerate(value)
            _v89_assert_scientific_payload_label_free(child, "$path[$index]")
        end
    end
    true
end

function _v89_topology_body(; regions, interfaces, boundaries, field_topologies,
        control_paths, event_transitions, operator_obligations)
    Dict{String,Any}(
        "schema_version" => "1.0.0",
        "regions" => regions, "interfaces" => interfaces,
        "boundaries" => boundaries, "field_topologies" => field_topologies,
        "control_paths" => control_paths, "event_transitions" => event_transitions,
        "operator_obligations" => operator_obligations)
end

function _v89_isomorphism_hash(regions, interfaces, boundaries, field_topologies,
        control_paths, event_transitions, operator_obligations)
    ids = sort!(String[String(item["region_id"]) for item in regions])
    length(ids) <= 6 || throw(ArgumentError(
        "v89 exact isomorphism canonicalization supports at most six regions"))
    candidates = String[]
    for permutation in _graph_v69_permutations(ids)
        mapping = Dict(permutation[index] => "n$(index)" for index in eachindex(permutation))
        mapped_regions = [Dict{String,Any}(
            "node" => mapping[String(item["region_id"])],
            "role" => String(item["role"]),
            "dimension" => String(item["dimension"]),
            "time_semantics" => String(item["time_semantics"]),
            "reservoir_accounts" => sort!(String.(item["reservoir_accounts"])),
            "state_slots" => sort!([_v89_plain(slot) for slot in item["state_slots"]];
                by = slot -> String(slot["slot_id"]))) for item in regions]
        sort!(mapped_regions; by = item -> String(item["node"]))
        mapped_interfaces = [Dict{String,Any}(
            "source" => mapping[String(item["source_region_id"])],
            "target" => get(item, "target_region_id", nothing) === nothing ? nothing :
                mapping[String(item["target_region_id"])],
            "kind" => String(item["kind"]),
            "flux_pairs" => sort!([_v89_plain(pair) for pair in item["flux_pairs"]];
                by = pair -> String(pair["account_id"]))) for item in interfaces]
        sort!(mapped_interfaces; by = canonical_hash)
        mapped_boundaries = [merge(_v89_plain(item), Dict(
            "region_id" => mapping[String(item["region_id"])])) for item in boundaries]
        sort!(mapped_boundaries; by = canonical_hash)
        mapped_fields = [merge(_v89_plain(item), Dict(
            "region_id" => mapping[String(item["region_id"])])) for item in field_topologies]
        sort!(mapped_fields; by = canonical_hash)
        mapped_controls = [Dict{String,Any}(
            "sensor_region" => mapping[String(item["sensor_region_id"])],
            "actuator_region" => mapping[String(item["actuator_region_id"])],
            "observed_state_ids" => sort!(String.(item["observed_state_ids"])),
            "actuated_account_ids" => sort!(String.(item["actuated_account_ids"])),
            "delay_s" => Float64(item["delay_s"])) for item in control_paths]
        sort!(mapped_controls; by = canonical_hash)
        mapped_events = [merge(_v89_plain(item), Dict(
            "region_id" => mapping[String(item["region_id"])])) for item in event_transitions]
        sort!(mapped_events; by = canonical_hash)
        mapped_operators = [Dict{String,Any}(
            "operator_id" => String(item["operator_id"]),
            "region" => mapping[String(item["region_id"])],
            "spatial_dimension" => String(item["spatial_dimension"]),
            "time_semantics" => String(item["time_semantics"]),
            "boundary_kinds" => sort!(String.(item["boundary_kinds"])),
            "required_state_ids" => sort!(String.(item["required_state_ids"])),
            "evidence_obligation" => String(item["evidence_obligation"]))
            for item in operator_obligations]
        sort!(mapped_operators; by = canonical_hash)
        push!(candidates, canonical_hash(Dict(
            "regions" => mapped_regions, "interfaces" => mapped_interfaces,
            "boundaries" => mapped_boundaries, "field_topologies" => mapped_fields,
            "control_paths" => mapped_controls, "event_transitions" => mapped_events,
            "operator_obligations" => mapped_operators)))
    end
    minimum(candidates)
end

function compile_universal_multiregion_topology_v89(; regions, interfaces,
        boundaries, field_topologies, control_paths = Dict{String,Any}[],
        event_transitions = Dict{String,Any}[], operator_obligations)
    regions = Dict{String,Any}.(_v89_plain(regions))
    interfaces = Dict{String,Any}.(_v89_plain(interfaces))
    boundaries = Dict{String,Any}.(_v89_plain(boundaries))
    field_topologies = Dict{String,Any}.(_v89_plain(field_topologies))
    control_paths = Dict{String,Any}.(_v89_plain(control_paths))
    event_transitions = Dict{String,Any}.(_v89_plain(event_transitions))
    operator_obligations = Dict{String,Any}.(_v89_plain(operator_obligations))
    payload = _v89_topology_body(; regions, interfaces, boundaries,
        field_topologies, control_paths, event_transitions, operator_obligations)
    _v89_assert_scientific_payload_label_free(payload)
    region_ids = String[String(item["region_id"]) for item in regions]
    !isempty(region_ids) || throw(ArgumentError("v89 topology requires at least one region"))
    length(unique(region_ids)) == length(region_ids) || throw(ArgumentError(
        "v89 topology region identifiers must be unique"))
    region_set = Set(region_ids)
    for region in regions
        String(region["dimension"]) in V89_REGION_DIMENSIONS || throw(ArgumentError(
            "invalid region dimension for $(region["region_id"])"))
        String(region["time_semantics"]) in V89_TIME_SEMANTICS || throw(ArgumentError(
            "invalid time semantics for $(region["region_id"])"))
        isempty(region["reservoir_accounts"]) && throw(ArgumentError(
            "region $(region["region_id"]) has no conserved reservoir account"))
        isempty(region["state_slots"]) && throw(ArgumentError(
            "region $(region["region_id"]) has no state slots"))
        for slot in region["state_slots"]
            isempty(String(get(slot, "unit", ""))) && throw(ArgumentError(
                "state slot $(slot["slot_id"]) lacks a unit"))
        end
    end
    interface_ids = String[]
    for interface in interfaces
        push!(interface_ids, String(interface["interface_id"]))
        String(interface["source_region_id"]) in region_set || throw(ArgumentError(
            "interface source region is missing"))
        target = get(interface, "target_region_id", nothing)
        target === nothing || String(target) in region_set || throw(ArgumentError(
            "interface target region is missing"))
        isempty(interface["flux_pairs"]) && throw(ArgumentError(
            "interface $(interface["interface_id"]) has no flux accounts"))
        for pair in interface["flux_pairs"]
            isempty(String(pair["unit"])) && throw(ArgumentError("interface flux unit missing"))
            if target !== nothing
                isapprox(Float64(pair["source_sign"]) + Float64(pair["target_sign"]),
                    0.0; atol = 0.0) || throw(ArgumentError(
                    "internal interface flux signs must be paired and opposite"))
            end
        end
    end
    length(unique(interface_ids)) == length(interface_ids) || throw(ArgumentError(
        "v89 interface identifiers must be unique"))
    covered_boundaries = Set{String}()
    for boundary in boundaries
        region_id = String(boundary["region_id"])
        region_id in region_set || throw(ArgumentError("boundary region is missing"))
        String(boundary["kind"]) in V89_BOUNDARY_KINDS || throw(ArgumentError(
            "unsupported boundary kind $(boundary["kind"])"))
        push!(covered_boundaries, region_id)
    end
    isempty(setdiff(region_set, covered_boundaries)) || throw(ArgumentError(
        "every region must have an explicit boundary contract"))
    field_regions = Set(String(item["region_id"]) for item in field_topologies)
    isempty(setdiff(region_set, field_regions)) || throw(ArgumentError(
        "every region must declare field topology semantics"))
    for control in control_paths
        String(control["sensor_region_id"]) in region_set || throw(ArgumentError(
            "control sensor region is missing"))
        String(control["actuator_region_id"]) in region_set || throw(ArgumentError(
            "control actuator region is missing"))
        isempty(control["observed_state_ids"]) && throw(ArgumentError(
            "control observation path is open"))
        isempty(control["actuated_account_ids"]) && throw(ArgumentError(
            "control actuation path is open"))
    end
    for obligation in operator_obligations
        String(obligation["region_id"]) in region_set || throw(ArgumentError(
            "operator obligation region is missing"))
        isempty(String(obligation["operator_id"])) && throw(ArgumentError(
            "operator obligation id is required"))
        String(obligation["spatial_dimension"]) in V89_REGION_DIMENSIONS ||
            throw(ArgumentError("operator spatial dimension is invalid"))
        String(obligation["time_semantics"]) in V89_TIME_SEMANTICS ||
            throw(ArgumentError("operator time semantics is invalid"))
    end
    body = _v89_topology_body(; regions, interfaces, boundaries,
        field_topologies, control_paths, event_transitions, operator_obligations)
    topology_hash = canonical_hash(body)
    isomorphism_hash = _v89_isomorphism_hash(regions, interfaces, boundaries,
        field_topologies, control_paths, event_transitions, operator_obligations)
    UniversalMultiRegionTopologyV89("1.0.0", regions, interfaces, boundaries,
        field_topologies, control_paths, event_transitions, operator_obligations,
        topology_hash, isomorphism_hash)
end

function universal_multiregion_topology_to_dict_v89(item::UniversalMultiRegionTopologyV89)
    merge(_v89_topology_body(regions = item.regions, interfaces = item.interfaces,
        boundaries = item.boundaries, field_topologies = item.field_topologies,
        control_paths = item.control_paths, event_transitions = item.event_transitions,
        operator_obligations = item.operator_obligations), Dict(
        "topology_hash" => item.topology_hash,
        "isomorphism_hash" => item.isomorphism_hash,
        "claim_boundary" => UNIVERSAL_MULTIREGION_TOPOLOGY_V89_CLAIM_BOUNDARY))
end

function _v89_anchor_state_slots(anchor)
    [Dict{String,Any}("slot_id" => String(item["state_id"]),
        "account" => String(item["account"]), "unit" => String(item["unit"]),
        "positivity_required" => Bool(item["positivity_required"]))
        for item in anchor["state_variables"]]
end

"Inverse-compile a sealed reference description without using its device label or observables."
function inverse_compile_reference_topology_v89(anchor_raw)
    anchor = _v89_plain(anchor_raw)
    capability_ids = Set(String(item["capability_id"]) for item in anchor["capabilities"])
    operator_ids = String[String(item["operator_id"]) for item in anchor["module_bindings"]]
    declared_region_semantics = lowercase(join((String(item["kind"])
        for item in anchor["regions"]), " "))
    has_open = any(contains(id, "parallel_streaming") for id in operator_ids) ||
        any(contains(id, "open_field") for id in capability_ids) ||
        occursin("open", declared_region_semantics)
    has_closed = any(contains(id, "closed_field") for id in capability_ids) ||
        occursin("closed", declared_region_semantics)
    slots = _v89_anchor_state_slots(anchor)
    core_dimension = "2d"
    mode = lowercase(String(anchor["time_mode"])) == "steady" ? "steady" : "transient"
    regions = Dict{String,Any}[Dict(
        "region_id" => "r1", "role" => has_closed ? "closed_plasma_core" : "plasma_core",
        "dimension" => core_dimension, "time_semantics" => mode,
        "reservoir_accounts" => sort!(unique(String(item["account"]) for item in slots)),
        "state_slots" => slots)]
    if has_open
        push!(regions, Dict{String,Any}(
            "region_id" => "r2", "role" => "open_parallel_loss_region",
            "dimension" => "1d", "time_semantics" => mode,
            "reservoir_accounts" => ["energy", "particles"],
            "state_slots" => [Dict("slot_id" => "loss_particle_inventory",
                "account" => "particles", "unit" => "1", "positivity_required" => true),
                Dict("slot_id" => "loss_thermal_energy", "account" => "energy",
                    "unit" => "J", "positivity_required" => true)]))
    end
    flux_pairs = [Dict{String,Any}("account_id" => account,
        "unit" => account == "particles" ? "1/s" : "W",
        "source_sign" => -1.0, "target_sign" => 1.0)
        for account in ("particles", "energy")]
    interfaces = Dict{String,Any}[]
    has_open && push!(interfaces, Dict("interface_id" => "i1",
        "source_region_id" => "r1", "target_region_id" => "r2",
        "kind" => "conservative_coupling", "flux_pairs" => flux_pairs))
    exhaust_region = has_open ? "r2" : "r1"
    push!(interfaces, Dict("interface_id" => has_open ? "i2" : "i1",
        "source_region_id" => exhaust_region, "target_region_id" => nothing,
        "kind" => "declared_external_boundary_flux",
        "flux_pairs" => [Dict("account_id" => "energy", "unit" => "W",
            "source_sign" => -1.0, "target_sign" => 0.0)]))
    boundaries = Dict{String,Any}[Dict("region_id" => "r1",
        "kind" => has_open ? "mixed" : "closed", "time_varying" => false)]
    has_open && push!(boundaries, Dict("region_id" => "r2", "kind" => "open",
        "time_varying" => false))
    field_topologies = Dict{String,Any}[Dict("region_id" => "r1",
        "kind" => has_closed ? "closed_flux" : "declared_flux",
        "separatrix" => has_open, "reversal_surface" => has_open)]
    has_open && push!(field_topologies, Dict("region_id" => "r2",
        "kind" => "open_flux", "separatrix" => true, "reversal_surface" => false))
    control_paths = Dict{String,Any}[Dict(
        "control_path_id" => "c1", "sensor_region_id" => "r1",
        "actuator_region_id" => "r1",
        "observed_state_ids" => String[item["slot_id"] for item in slots],
        "actuated_account_ids" => ["energy", "particles"], "delay_s" => 0.0)]
    operator_obligations = Dict{String,Any}[]
    for binding in anchor["module_bindings"]
        operator_id = String(binding["operator_id"])
        region_id = occursin("parallel_streaming", operator_id) && has_open ? "r2" : "r1"
        region = only(filter(item -> item["region_id"] == region_id, regions))
        boundary_kinds = sort!(unique(String(item["kind"]) for item in boundaries
            if item["region_id"] == region_id))
        push!(operator_obligations, Dict(
            "obligation_id" => "o$(length(operator_obligations) + 1)",
            "operator_id" => operator_id, "region_id" => region_id,
            "spatial_dimension" => String(region["dimension"]),
            "time_semantics" => String(region["time_semantics"]),
            "boundary_kinds" => boundary_kinds,
            "required_state_ids" => String.(binding["state_ids"]),
            "evidence_obligation" => String(binding["evidence_ceiling"])))
    end
    if has_open
        push!(operator_obligations, Dict(
            "obligation_id" => "o$(length(operator_obligations) + 1)",
            "operator_id" => "conservative_multiregion_interface_v89",
            "region_id" => "r1", "spatial_dimension" => core_dimension,
            "time_semantics" => mode, "boundary_kinds" => ["mixed"],
            "required_state_ids" => ["particle_inventory", "thermal_energy"],
            "evidence_obligation" => "paired_interface_conservation"))
    end
    push!(operator_obligations, Dict(
        "obligation_id" => "o$(length(operator_obligations) + 1)",
        "operator_id" => "bounded_control_response_v89", "region_id" => "r1",
        "spatial_dimension" => core_dimension, "time_semantics" => mode,
        "boundary_kinds" => [has_open ? "mixed" : "closed"],
        "required_state_ids" => ["particle_inventory", "thermal_energy"],
        "evidence_obligation" => "actuator_capacity_and_feedback_closure"))
    push!(operator_obligations, Dict(
        "obligation_id" => "o$(length(operator_obligations) + 1)",
        "operator_id" => "integrated_reduced_device_audit_v89", "region_id" => "r1",
        "spatial_dimension" => core_dimension, "time_semantics" => mode,
        "boundary_kinds" => [has_open ? "mixed" : "closed"],
        "required_state_ids" => ["particle_inventory", "thermal_energy",
            "plasma_current", "magnetic_flux"],
        "evidence_obligation" => "reduced_multiresolution_integrated_screen"))
    topology = compile_universal_multiregion_topology_v89(; regions, interfaces,
        boundaries, field_topologies, control_paths, operator_obligations)
    provenance = Dict{String,Any}(
        "inverse_method" => "operator_and_region_semantics_inverse_v89",
        "source_description_hash" => canonical_hash(Dict(
            "regions" => anchor["regions"], "capabilities" => anchor["capabilities"],
            "module_bindings" => anchor["module_bindings"],
            "state_variables" => anchor["state_variables"])),
        "anchor_observables_consumed_by_inverse" => false,
        "labels_consumed_by_inverse" => false,
        "representability_status" => "pass")
    topology, provenance
end

function generate_universal_multiregion_topology_v89(structure_seed::Integer;
        pattern::Symbol = isodd(structure_seed) ? :closed_multiregion :
            :closed_core_open_loss)
    pattern in (:closed_multiregion, :closed_core_open_loss) || throw(ArgumentError(
        "unknown v89 topology production"))
    synthetic = Dict{String,Any}(
        "time_mode" => "pulsed",
        "regions" => [Dict("kind" => pattern == :closed_multiregion ?
            "closed_plasma" : "closed_plasma_with_open_loss")],
        "capabilities" => [Dict("capability_id" => "conserved_particle_inventory"),
            Dict("capability_id" => "conserved_thermal_energy"),
            Dict("capability_id" => "axisymmetric_mhd_equilibrium")],
        "module_bindings" => [
            Dict("operator_id" => "control_volume_particle_inventory_v1",
                "state_ids" => ["particle_inventory"], "evidence_ceiling" => "L1_screening_only"),
            Dict("operator_id" => "control_volume_thermal_energy_v1",
                "state_ids" => ["thermal_energy"], "evidence_ceiling" => "L1_screening_only"),
            Dict("operator_id" => "fixed_current_flux_inventory_l1_v1",
                "state_ids" => ["plasma_current", "magnetic_flux"],
                "evidence_ceiling" => "inventory_screen_only")],
        "state_variables" => [
            Dict("state_id" => "particle_inventory", "account" => "particles",
                "unit" => "1", "positivity_required" => true),
            Dict("state_id" => "thermal_energy", "account" => "energy",
                "unit" => "J", "positivity_required" => true),
            Dict("state_id" => "plasma_current", "account" => "current",
                "unit" => "A", "positivity_required" => false),
            Dict("state_id" => "magnetic_flux", "account" => "magnetic_flux",
                "unit" => "Wb", "positivity_required" => false)])
    if pattern == :closed_core_open_loss
        push!(synthetic["capabilities"], Dict("capability_id" =>
            "open_field_kinetic_transport"))
        push!(synthetic["module_bindings"], Dict(
            "operator_id" => "state_derived_parallel_streaming_l1_v1",
            "state_ids" => ["particle_inventory", "thermal_energy"],
            "evidence_ceiling" => "open_loss_screen_only"))
    end
    first(inverse_compile_reference_topology_v89(synthetic))
end
