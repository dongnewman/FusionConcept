const UNIVERSAL_DEVICE_GRAMMAR_V89_CLAIM_BOUNDARY =
    "A compiled v89 device is a candidate-bound executable input inside the declared grammar, bounds, mission, solver capabilities, and evidence scope. It is not a validated or deployable fusion device."

struct UniversalDeviceCandidateV89
    schema_version::String
    candidate_id::String
    topology_hash::String
    isomorphism_hash::String
    realization_hash::String
    candidate_physics_hash::String
    structure_seed::Int
    physical_variant_seed::Int
    operating_variant_seed::Int
    control_variant_seed::Int
    stream_hashes::Dict{String,String}
    mission_scope::Dict{String,Any}
    evidence_scope::Dict{String,Any}
    capability_cell::String
    solver_input_hash::String
    candidate_hash::String
end

function _v89_capability_cell(topology::UniversalMultiRegionTopologyV89)
    signature = Dict{String,Any}(
        "dimensions" => sort!(unique(String(item["dimension"]) for item in topology.regions)),
        "time_semantics" => sort!(unique(String(item["time_semantics"])
            for item in topology.regions)),
        "boundary_kinds" => sort!(unique(String(item["kind"])
            for item in topology.boundaries)),
        "operator_ids" => sort!(unique(String(item["operator_id"])
            for item in topology.operator_obligations)),
        "region_roles" => sort!(unique(String(item["role"]) for item in topology.regions)))
    canonical_hash(signature)
end

function compile_universal_device_candidate_v89(candidate_id::AbstractString,
        topology::UniversalMultiRegionTopologyV89,
        realization::UniversalRealizationV89;
        structure_seed::Integer, mission_scope, evidence_scope)
    realization.topology_hash == topology.topology_hash || throw(ArgumentError(
        "realization is not bound to the supplied topology"))
    mission_scope = Dict{String,Any}(_v89_plain(mission_scope))
    evidence_scope = Dict{String,Any}(_v89_plain(evidence_scope))
    _v89_assert_scientific_payload_label_free(mission_scope, "mission_scope")
    isempty(String(get(mission_scope, "mission_id", ""))) && throw(ArgumentError(
        "a declared mission is required"))
    isempty(String(get(evidence_scope, "evidence_level", ""))) && throw(ArgumentError(
        "a declared evidence level is required"))
    structure_hash = _v89_stream_hash(topology.topology_hash, "structure", structure_seed)
    stream_hashes = merge(Dict("structure" => structure_hash), realization.stream_hashes)
    length(unique(values(stream_hashes))) == 4 || throw(ArgumentError(
        "topology, physical, operating, and control streams must be independent"))
    capability_cell = _v89_capability_cell(topology)
    solver_input_body = Dict{String,Any}(
        "topology" => universal_multiregion_topology_to_dict_v89(topology),
        "realization" => universal_realization_to_dict_v89(realization),
        "mission_scope" => mission_scope, "evidence_scope" => evidence_scope,
        "capability_cell" => capability_cell)
    # Claim-boundary prose is not a solver input.
    delete!(solver_input_body["topology"], "claim_boundary")
    delete!(solver_input_body["realization"], "claim_boundary")
    solver_input_hash = canonical_hash(solver_input_body)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "candidate_id" => String(candidate_id),
        "topology_hash" => topology.topology_hash,
        "isomorphism_hash" => topology.isomorphism_hash,
        "realization_hash" => realization.realization_hash,
        "candidate_physics_hash" => realization.candidate_physics_hash,
        "structure_seed" => Int(structure_seed),
        "physical_variant_seed" => realization.stream_seeds["physical"],
        "operating_variant_seed" => realization.stream_seeds["operating"],
        "control_variant_seed" => realization.stream_seeds["control"],
        "stream_hashes" => stream_hashes, "mission_scope" => mission_scope,
        "evidence_scope" => evidence_scope, "capability_cell" => capability_cell,
        "solver_input_hash" => solver_input_hash)
    candidate_hash = canonical_hash(body)
    UniversalDeviceCandidateV89("1.0.0", String(candidate_id), topology.topology_hash,
        topology.isomorphism_hash, realization.realization_hash,
        realization.candidate_physics_hash, Int(structure_seed),
        realization.stream_seeds["physical"], realization.stream_seeds["operating"],
        realization.stream_seeds["control"], stream_hashes, mission_scope,
        evidence_scope, capability_cell, solver_input_hash, candidate_hash)
end

function universal_device_candidate_to_dict_v89(item::UniversalDeviceCandidateV89)
    Dict{String,Any}(
        "schema_version" => item.schema_version, "candidate_id" => item.candidate_id,
        "topology_hash" => item.topology_hash,
        "isomorphism_hash" => item.isomorphism_hash,
        "realization_hash" => item.realization_hash,
        "candidate_physics_hash" => item.candidate_physics_hash,
        "structure_seed" => item.structure_seed,
        "physical_variant_seed" => item.physical_variant_seed,
        "operating_variant_seed" => item.operating_variant_seed,
        "control_variant_seed" => item.control_variant_seed,
        "stream_hashes" => item.stream_hashes, "mission_scope" => item.mission_scope,
        "evidence_scope" => item.evidence_scope,
        "capability_cell" => item.capability_cell,
        "solver_input_hash" => item.solver_input_hash,
        "candidate_hash" => item.candidate_hash,
        "claim_boundary" => UNIVERSAL_DEVICE_GRAMMAR_V89_CLAIM_BOUNDARY)
end

function compile_v89_device_complexity(candidate::UniversalDeviceCandidateV89,
        realization::UniversalRealizationV89; hard_gate_status::AbstractString)
    hard_gate_status == "pass" || throw(ArgumentError(
        "complexity and Pareto are forbidden before all declared hard gates pass"))
    component_count = sum(Int(item["count"]) for item in realization.components)
    supply_count = sum(Int(item["independent_power_supplies"])
        for item in realization.components)
    conductor_count = sum(Int(item["count"]) for item in realization.components
        if String(item["role"]) in ("plasma_internal_current", "external_field_conductor"))
    major = Float64(get(realization.physical_parameters, "major_radius_m",
        get(realization.physical_parameters, "characteristic_length_m", 1.0) / 2.0))
    minor = max(Float64(get(realization.physical_parameters, "minor_radius_m", 0.5)), 1e-9)
    conductor_length = 2pi * major * conductor_count
    basis_cost = sum(Float64(item["complexity_cost"])
        for item in realization.basis_coefficients)
    sensor_count = sum(Int(item["count"]) for item in realization.components
        if String(item["role"]) == "sensor")
    controller_count = sum(Int(item["count"]) for item in realization.components
        if String(item["role"]) == "controller")
    objectives = Dict{String,Float64}(
        "component_count" => component_count,
        "independent_power_supply_count" => supply_count,
        "conductor_length_m" => conductor_length,
        "maximum_curvature_1_per_m" => 1.0 / minor,
        "support_and_shield_mass_proxy" => component_count * max(major, 1.0),
        "thermal_cryogenic_maintenance_proxy" => component_count + 0.25basis_cost,
        "sensor_actuator_controller_complexity" => sensor_count + controller_count +
            Float64(get(realization.control_realization, "actuator_count", 0)),
        "operation_and_fault_recovery_complexity" => controller_count +
            (haskey(realization.control_realization, "fault_action") ? 1.0 : 0.0),
        "basis_complexity" => basis_cost)
    body = Dict{String,Any}(
        "candidate_hash" => candidate.candidate_hash,
        "capability_cell" => candidate.capability_cell,
        "mission_id" => candidate.mission_scope["mission_id"],
        "evidence_level" => candidate.evidence_scope["evidence_level"],
        "comparison_scope" => get(candidate.evidence_scope, "comparison_scope",
            "v89_default_scope"),
        "hard_gate_status" => hard_gate_status, "objectives" => objectives,
        "minimality_claim" => "Pareto minimal only within the declared grammar, bounds, mission, capability cell, comparison scope, and evidence level.")
    body["complexity_hash"] = canonical_hash(body)
    body
end

function _v89_complexity_dominates(left, right)
    keys_left = sort!(collect(keys(left["objectives"])))
    keys_left == sort!(collect(keys(right["objectives"]))) || return false
    values_left = Float64[left["objectives"][key] for key in keys_left]
    values_right = Float64[right["objectives"][key] for key in keys_left]
    all(values_left .<= values_right) && any(values_left .< values_right)
end

function build_v89_post_hard_gate_pareto(rows)
    all(row -> String(row["hard_gate_status"]) == "pass", rows) || throw(ArgumentError(
        "Pareto input contains a candidate that did not pass hard gates"))
    groups = Dict{String,Vector{Any}}()
    for row in rows
        scope = canonical_hash(Dict("capability_cell" => row["capability_cell"],
            "mission_id" => row["mission_id"], "evidence_level" => row["evidence_level"],
            "comparison_scope" => row["comparison_scope"]))
        push!(get!(groups, scope, Any[]), row)
    end
    archive = Dict{String,Any}[]
    for (scope, group) in sort!(collect(groups); by = first)
        for row in group
            any(other -> other !== row && _v89_complexity_dominates(other, row), group) &&
                continue
            kept = deepcopy(row); kept["pareto_scope_hash"] = scope
            push!(archive, kept)
        end
    end
    sort!(archive; by = row -> String(row["candidate_hash"]))
end
