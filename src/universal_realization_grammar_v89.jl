const UNIVERSAL_REALIZATION_V89_CLAIM_BOUNDARY =
    "A v89 realization binds abstract regions and ports to generic physical components, geometry, coefficients, operating state, and declared consumers. Passing compilation does not grant hard-physics or engineering feasibility."

const V89_COMPONENT_ROLES = Set((
    "plasma_internal_current", "external_field_conductor", "power_actuator",
    "particle_source", "material_boundary", "open_loss_target", "sensor",
    "controller", "protection_actuator", "heat_sink"))

struct UniversalRealizationV89
    schema_version::String
    topology_hash::String
    stream_seeds::Dict{String,Int}
    stream_hashes::Dict{String,String}
    components::Vector{Dict{String,Any}}
    basis_coefficients::Vector{Dict{String,Any}}
    physical_parameters::Dict{String,Any}
    operating_state::Dict{String,Float64}
    control_realization::Dict{String,Any}
    consumer_proofs::Vector{Dict{String,Any}}
    realization_hash::String
    candidate_physics_hash::String
end

function _v89_stream_hash(topology_hash, stream_id, seed)
    canonical_hash(Dict("topology_hash" => String(topology_hash),
        "stream_id" => String(stream_id), "seed" => Int(seed)))
end

function compile_universal_realization_v89(topology::UniversalMultiRegionTopologyV89;
        physical_variant_seed::Integer, operating_variant_seed::Integer,
        control_variant_seed::Integer, components, basis_coefficients,
        physical_parameters, operating_state, control_realization, consumer_proofs)
    stream_seeds = Dict{String,Int}(
        "physical" => Int(physical_variant_seed),
        "operating" => Int(operating_variant_seed),
        "control" => Int(control_variant_seed))
    stream_hashes = Dict{String,String}(key => _v89_stream_hash(topology.topology_hash,
        key, seed) for (key, seed) in stream_seeds)
    length(unique(values(stream_hashes))) == 3 || throw(ArgumentError(
        "physical, operating, and control random streams must be independent"))
    components = Dict{String,Any}.(_v89_plain(components))
    basis_coefficients = Dict{String,Any}.(_v89_plain(basis_coefficients))
    physical_parameters = Dict{String,Any}(_v89_plain(physical_parameters))
    operating_state = Dict{String,Float64}(String(key) => Float64(value)
        for (key, value) in pairs(operating_state))
    control_realization = Dict{String,Any}(_v89_plain(control_realization))
    consumer_proofs = Dict{String,Any}.(_v89_plain(consumer_proofs))
    scientific_payload = Dict("components" => components,
        "basis_coefficients" => basis_coefficients,
        "physical_parameters" => physical_parameters,
        "operating_state" => operating_state,
        "control_realization" => control_realization,
        "consumer_proofs" => consumer_proofs)
    _v89_assert_scientific_payload_label_free(scientific_payload, "realization")
    region_ids = Set(String(item["region_id"]) for item in topology.regions)
    component_ids = String[]
    for component in components
        push!(component_ids, String(component["component_id"]))
        String(component["role"]) in V89_COMPONENT_ROLES || throw(ArgumentError(
            "unsupported v89 component role $(component["role"])"))
        String(component["region_id"]) in region_ids || throw(ArgumentError(
            "component $(component["component_id"]) binds an unknown region"))
        Int(component["count"]) >= 1 || throw(ArgumentError("component count must be positive"))
    end
    length(unique(component_ids)) == length(component_ids) || throw(ArgumentError(
        "v89 realization component identifiers must be unique"))
    gene_ids = String[]
    for gene in basis_coefficients
        push!(gene_ids, String(gene["gene_id"]))
        isempty(String(gene["unit"])) && throw(ArgumentError("basis gene unit is required"))
        haskey(gene, "lower") && haskey(gene, "upper") || throw(ArgumentError(
            "basis gene bounds are required"))
        Float64(gene["lower"]) <= Float64(gene["value"]) <= Float64(gene["upper"]) ||
            throw(ArgumentError("basis gene $(gene["gene_id"]) is outside bounds"))
        Float64(gene["complexity_cost"]) >= 0 || throw(ArgumentError(
            "basis gene complexity cost must be nonnegative"))
    end
    length(unique(gene_ids)) == length(gene_ids) || throw(ArgumentError(
        "basis gene identifiers must be unique"))
    proof_by_gene = Dict(String(item["gene_id"]) => item for item in consumer_proofs)
    missing = sort!(collect(setdiff(Set(gene_ids), Set(keys(proof_by_gene)))))
    isempty(missing) || throw(ArgumentError(
        "every generated basis gene needs a residual or hard-gate consumer: $(join(missing, ','))"))
    for gene_id in gene_ids
        proof = proof_by_gene[gene_id]
        String(proof["consumer_kind"]) in ("residual_block", "hard_gate",
            "operator_input", "engineering_constraint") || throw(ArgumentError(
            "gene $gene_id has no physical consumer"))
        isempty(String(proof["consumer_id"])) && throw(ArgumentError(
            "gene $gene_id consumer id is empty"))
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "topology_hash" => topology.topology_hash,
        "stream_seeds" => stream_seeds, "stream_hashes" => stream_hashes,
        "components" => components, "basis_coefficients" => basis_coefficients,
        "physical_parameters" => physical_parameters,
        "operating_state" => operating_state,
        "control_realization" => control_realization,
        "consumer_proofs" => consumer_proofs)
    realization_hash = canonical_hash(body)
    physics_body = copy(body)
    delete!(physics_body, "consumer_proofs")
    candidate_physics_hash = canonical_hash(physics_body)
    UniversalRealizationV89("1.0.0", topology.topology_hash, stream_seeds,
        stream_hashes, components, basis_coefficients, physical_parameters,
        operating_state, control_realization, consumer_proofs, realization_hash,
        candidate_physics_hash)
end

function universal_realization_to_dict_v89(item::UniversalRealizationV89)
    Dict{String,Any}(
        "schema_version" => item.schema_version, "topology_hash" => item.topology_hash,
        "stream_seeds" => item.stream_seeds, "stream_hashes" => item.stream_hashes,
        "components" => item.components, "basis_coefficients" => item.basis_coefficients,
        "physical_parameters" => item.physical_parameters,
        "operating_state" => item.operating_state,
        "control_realization" => item.control_realization,
        "consumer_proofs" => item.consumer_proofs,
        "realization_hash" => item.realization_hash,
        "candidate_physics_hash" => item.candidate_physics_hash,
        "claim_boundary" => UNIVERSAL_REALIZATION_V89_CLAIM_BOUNDARY)
end

function _v89_parameter_gene(id, value, unit; relative_span = 0.5,
        consumer_kind = "hard_gate", consumer_id = "hard_physics_preflight_v89",
        complexity_cost = 1.0)
    numeric = Float64(value)
    span = max(abs(numeric) * relative_span, eps(Float64))
    gene = Dict{String,Any}("gene_id" => String(id), "basis_family" =>
        "declared_scalar_profile_v89", "value" => numeric, "unit" => String(unit),
        "lower" => numeric - span, "upper" => numeric + span,
        "regularization" => "bounded_l2", "complexity_cost" => complexity_cost)
    proof = Dict{String,Any}("gene_id" => String(id),
        "consumer_kind" => consumer_kind, "consumer_id" => consumer_id,
        "changes_candidate_physics_hash" => true)
    gene, proof
end

"Inverse-compile parameters and state; published comparison observables are never used."
function inverse_compile_reference_realization_v89(
        topology::UniversalMultiRegionTopologyV89, anchor_raw;
        physical_variant_seed::Integer = 1, operating_variant_seed::Integer = 1,
        control_variant_seed::Integer = 1)
    anchor = _v89_plain(anchor_raw)
    parameters = Dict{String,Any}(_v89_plain(anchor["parameters"]))
    initial = Dict{String,Float64}(String(key) => Float64(value)
        for (key, value) in pairs(anchor["initial_conditions"]))
    core = String(first(topology.regions)["region_id"])
    open_regions = String[String(item["region_id"]) for item in topology.regions
        if String(item["role"]) == "open_parallel_loss_region"]
    components = Dict{String,Any}[
        Dict("component_id" => "cmp_internal_current", "role" =>
            "plasma_internal_current", "region_id" => core, "count" => 1,
            "required" => true, "independent_power_supplies" => 1),
        Dict("component_id" => "cmp_field_conductor", "role" =>
            "external_field_conductor", "region_id" => core, "count" => 1,
            "required" => true, "independent_power_supplies" => 1),
        Dict("component_id" => "cmp_power", "role" => "power_actuator",
            "region_id" => core, "count" => 1, "required" => true,
            "independent_power_supplies" => 1),
        Dict("component_id" => "cmp_wall", "role" => "material_boundary",
            "region_id" => core, "count" => 1, "required" => true,
            "independent_power_supplies" => 0),
        Dict("component_id" => "cmp_sensor_primary", "role" => "sensor",
            "region_id" => core, "count" => 1, "required" => true,
            "independent_power_supplies" => 0),
        Dict("component_id" => "cmp_sensor_redundant", "role" => "sensor",
            "region_id" => core, "count" => 1, "required" => false,
            "independent_power_supplies" => 0),
        Dict("component_id" => "cmp_controller", "role" => "controller",
            "region_id" => core, "count" => 1, "required" => true,
            "independent_power_supplies" => 0)]
    for region_id in open_regions
        push!(components, Dict("component_id" => "cmp_loss_target_$region_id",
            "role" => "open_loss_target", "region_id" => region_id, "count" => 1,
            "required" => true, "independent_power_supplies" => 0))
        push!(components, Dict("component_id" => "cmp_heat_sink_$region_id",
            "role" => "heat_sink", "region_id" => region_id, "count" => 1,
            "required" => true, "independent_power_supplies" => 0))
    end
    units = Dict("volume_m3" => "m^3", "major_radius_m" => "m",
        "minor_radius_m" => "m", "characteristic_length_m" => "m",
        "magnetic_field_t" => "T", "temperature_j" => "J",
        "input_power_w" => "W", "pulse_duration_s" => "s")
    genes = Dict{String,Any}[]; proofs = Dict{String,Any}[]
    for id in sort!(collect(intersect(Set(keys(parameters)), Set(keys(units)))))
        parameters[id] isa Real || continue
        kind = id in ("input_power_w", "pulse_duration_s") ? "residual_block" : "hard_gate"
        consumer = id in ("input_power_w", "pulse_duration_s") ?
            "operating_and_control_residual_v89" : "hard_physics_preflight_v89"
        gene, proof = _v89_parameter_gene(id, parameters[id], units[id];
            consumer_kind = kind, consumer_id = consumer)
        push!(genes, gene); push!(proofs, proof)
    end
    control = Dict{String,Any}(
        "controller_model" => "bounded_state_feedback_v89",
        "sensor_count" => 2, "actuator_count" => 1,
        "command_min" => 0.0,
        "command_max" => Float64(get(parameters, "input_power_w", 0.0)),
        "delay_s" => 0.0, "fault_action" => "safe_power_zero")
    realization = compile_universal_realization_v89(topology;
        physical_variant_seed, operating_variant_seed, control_variant_seed,
        components, basis_coefficients = genes, physical_parameters = parameters,
        operating_state = initial, control_realization = control,
        consumer_proofs = proofs)
    provenance = Dict{String,Any}(
        "inverse_method" => "parameter_state_and_operator_binding_inverse_v89",
        "anchor_observables_consumed_by_inverse" => false,
        "source_parameter_hash" => canonical_hash(Dict("parameters" => parameters,
            "initial_conditions" => initial)),
        "realization_status" => "pass")
    realization, provenance
end

function sparse_realization_variants_v89(item::UniversalRealizationV89)
    variants = UniversalRealizationV89[item]
    optional_ids = String[String(component["component_id"]) for component in item.components
        if !Bool(component["required"])]
    for optional_id in optional_ids
        components = deepcopy(item.components)
        filter!(component -> String(component["component_id"]) != optional_id, components)
        body = Dict{String,Any}(
            "schema_version" => item.schema_version, "topology_hash" => item.topology_hash,
            "stream_seeds" => item.stream_seeds, "stream_hashes" => item.stream_hashes,
            "components" => components, "basis_coefficients" => item.basis_coefficients,
            "physical_parameters" => item.physical_parameters,
            "operating_state" => item.operating_state,
            "control_realization" => item.control_realization,
            "consumer_proofs" => item.consumer_proofs)
        physics_body = copy(body); delete!(physics_body, "consumer_proofs")
        push!(variants, UniversalRealizationV89(item.schema_version, item.topology_hash,
            copy(item.stream_seeds), copy(item.stream_hashes), components,
            deepcopy(item.basis_coefficients), copy(item.physical_parameters),
            copy(item.operating_state), copy(item.control_realization),
            deepcopy(item.consumer_proofs), canonical_hash(body),
            canonical_hash(physics_body)))
    end
    variants
end
