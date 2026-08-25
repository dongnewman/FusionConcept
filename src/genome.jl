struct MissionSpec
    kind::String
    fuel::String
    operating_mode::String
    targets::Dict{String,Quantity}
end

struct TopologySpec
    field_line_class::String
    rotation_transform_sources::Vector{String}
    expected_flux_surfaces::Union{Nothing,Bool}
    expected_separatrix::Union{Nothing,Bool}
end

struct SymmetrySpec
    class::String
    field_periods::Int
    hard_constraints::Vector{String}
end

struct PlasmaRegion
    id::String
    kind::String
    geometry_model::String
    parameters::Dict{String,Quantity}
end

struct FieldSource
    id::String
    kind::String
    geometry_model::String
    parameters::Dict{String,Quantity}
    material::String
end

struct Actuator
    id::String
    kind::String
    parameters::Dict{String,Quantity}
end

"A typed edge-bearing component that compresses one or more plasma targets."
struct CompressionSystem
    id::String
    kind::String
    geometry_model::String
    driver_actuator_ids::Vector{String}
    target_region_ids::Vector{String}
    parameters::Dict{String,Quantity}
    material::String
    source_ids::Vector{String}
end

struct StabilityMechanism
    id::String
    mechanism::String
    target_modes::Vector{String}
    actuator_ids::Vector{String}
    assumptions::Vector{String}
    required_evaluators::Vector{String}
    source_ids::Vector{String}
end

struct FluxConnection
    from_region_id::String
    to_region_id::String
    kind::String
end

struct ExhaustSpec
    kind::String
    region_ids::Vector{String}
    evaluation_requirements::Vector{String}
end

struct EngineeringSpec
    magnet_technology::Vector{String}
    blanket_required::Bool
    blanket_concept::Union{Nothing,String}
    target_tbr::Union{Nothing,Quantity}
    maintenance_architecture::String
    access_paths::Vector{String}
    required_evaluators::Vector{String}
end

struct ProvenanceSpec
    origin::String
    source_ids::Vector{String}
    parent_design_ids::Vector{String}
    claim_level::String
    notes::Vector{String}
end

"Typed, unit-normalized confinement concept plus deterministic hashes."
struct Genome
    schema_version::String
    design_id::String
    label::Union{Nothing,String}
    mission::MissionSpec
    family::String
    topology::TopologySpec
    symmetry::SymmetrySpec
    plasma_regions::Vector{PlasmaRegion}
    field_sources::Vector{FieldSource}
    actuators::Vector{Actuator}
    compression_systems::Vector{CompressionSystem}
    stability_mechanisms::Vector{StabilityMechanism}
    flux_connections::Vector{FluxConnection}
    exhaust::ExhaustSpec
    engineering::EngineeringSpec
    provenance::ProvenanceSpec
    normalized::Dict{String,Any}
    content_hash::String
    physics_hash::String
end

struct ValidationReport
    valid::Bool
    errors::Vector{String}
    warnings::Vector{String}
end

_strings(value) = String[String(item) for item in value]

function _required(dict::AbstractDict, key::String, context::String)
    haskey(dict, key) || throw(ArgumentError("$context is missing required field '$key'"))
    return dict[key]
end

function _quantity(value, context::String)
    value isa AbstractDict || throw(ArgumentError("$context must be a quantity object"))
    _is_quantity_dict(value) || throw(ArgumentError("$context must contain numeric value and unit"))
    return Quantity(value["value"], value["unit"], get(value, "basis", nothing))
end

function _quantity_dict(value, context::String)
    value isa AbstractDict || throw(ArgumentError("$context must be an object"))
    return Dict{String,Quantity}(String(key) => _quantity(item, "$context.$key")
        for (key, item) in value)
end

function _optional_bool(dict, key)
    haskey(dict, key) || return nothing
    dict[key] isa Bool || throw(ArgumentError("$key must be boolean"))
    return dict[key]
end

"Parse a schema-shaped object, normalize units, and compute content/physics hashes."
function parse_genome(value)
    raw = _plain_json(value)
    normalized = normalize_units(raw)

    schema_version = String(_required(normalized, "schema_version", "genome"))
    design_id = String(_required(normalized, "design_id", "genome"))

    mission_raw = _required(normalized, "mission", "genome")
    mission = MissionSpec(
        String(_required(mission_raw, "kind", "mission")),
        String(_required(mission_raw, "fuel", "mission")),
        String(_required(mission_raw, "operating_mode", "mission")),
        _quantity_dict(_required(mission_raw, "targets", "mission"), "mission.targets"),
    )

    topology_raw = _required(normalized, "topology", "genome")
    topology = TopologySpec(
        String(_required(topology_raw, "field_line_class", "topology")),
        _strings(_required(topology_raw, "rotation_transform_sources", "topology")),
        _optional_bool(topology_raw, "expected_flux_surfaces"),
        _optional_bool(topology_raw, "expected_separatrix"),
    )

    symmetry_raw = _required(normalized, "symmetry", "genome")
    symmetry = SymmetrySpec(
        String(_required(symmetry_raw, "class", "symmetry")),
        Int(_required(symmetry_raw, "field_periods", "symmetry")),
        _strings(get(symmetry_raw, "hard_constraints", Any[])),
    )

    plasma_regions = PlasmaRegion[]
    for item in _required(normalized, "plasma_regions", "genome")
        push!(plasma_regions, PlasmaRegion(
            String(_required(item, "id", "plasma_region")),
            String(_required(item, "kind", "plasma_region")),
            String(_required(item, "geometry_model", "plasma_region")),
            _quantity_dict(_required(item, "parameters", "plasma_region"),
                "plasma_region.parameters"),
        ))
    end

    field_sources = FieldSource[]
    for item in _required(normalized, "field_sources", "genome")
        push!(field_sources, FieldSource(
            String(_required(item, "id", "field_source")),
            String(_required(item, "kind", "field_source")),
            String(_required(item, "geometry_model", "field_source")),
            _quantity_dict(_required(item, "parameters", "field_source"),
                "field_source.parameters"),
            String(_required(item, "material", "field_source")),
        ))
    end

    actuators = Actuator[]
    for item in get(normalized, "actuators", Any[])
        push!(actuators, Actuator(
            String(_required(item, "id", "actuator")),
            String(_required(item, "kind", "actuator")),
            _quantity_dict(_required(item, "parameters", "actuator"),
                "actuator.parameters"),
        ))
    end

    compression_systems = CompressionSystem[]
    for item in get(normalized, "compression_systems", Any[])
        push!(compression_systems, CompressionSystem(
            String(_required(item, "id", "compression_system")),
            String(_required(item, "kind", "compression_system")),
            String(_required(item, "geometry_model", "compression_system")),
            _strings(_required(item, "driver_actuator_ids", "compression_system")),
            _strings(_required(item, "target_region_ids", "compression_system")),
            _quantity_dict(_required(item, "parameters", "compression_system"),
                "compression_system.parameters"),
            String(_required(item, "material", "compression_system")),
            _strings(_required(item, "source_ids", "compression_system")),
        ))
    end

    mechanisms = StabilityMechanism[]
    for item in _required(normalized, "stability_mechanisms", "genome")
        push!(mechanisms, StabilityMechanism(
            String(_required(item, "id", "stability_mechanism")),
            String(_required(item, "mechanism", "stability_mechanism")),
            _strings(_required(item, "target_modes", "stability_mechanism")),
            _strings(get(item, "actuator_ids", Any[])),
            _strings(_required(item, "assumptions", "stability_mechanism")),
            _strings(_required(item, "required_evaluators", "stability_mechanism")),
            _strings(_required(item, "source_ids", "stability_mechanism")),
        ))
    end

    connections = FluxConnection[]
    for item in get(normalized, "flux_connections", Any[])
        push!(connections, FluxConnection(
            String(_required(item, "from_region_id", "flux_connection")),
            String(_required(item, "to_region_id", "flux_connection")),
            String(_required(item, "kind", "flux_connection")),
        ))
    end

    exhaust_raw = _required(normalized, "exhaust", "genome")
    exhaust = ExhaustSpec(
        String(_required(exhaust_raw, "kind", "exhaust")),
        _strings(_required(exhaust_raw, "region_ids", "exhaust")),
        _strings(_required(exhaust_raw, "evaluation_requirements", "exhaust")),
    )

    engineering_raw = _required(normalized, "engineering", "genome")
    blanket_raw = _required(engineering_raw, "blanket", "engineering")
    maintenance_raw = _required(engineering_raw, "maintenance", "engineering")
    target_tbr = haskey(blanket_raw, "target_tbr") ?
        _quantity(blanket_raw["target_tbr"], "engineering.blanket.target_tbr") : nothing
    engineering = EngineeringSpec(
        _strings(_required(engineering_raw, "magnet_technology", "engineering")),
        Bool(_required(blanket_raw, "required", "engineering.blanket")),
        get(blanket_raw, "concept", nothing) === nothing ? nothing :
            String(blanket_raw["concept"]),
        target_tbr,
        String(_required(maintenance_raw, "architecture", "engineering.maintenance")),
        _strings(_required(maintenance_raw, "access_paths", "engineering.maintenance")),
        _strings(_required(engineering_raw, "required_evaluators", "engineering")),
    )

    provenance_raw = _required(normalized, "provenance", "genome")
    provenance = ProvenanceSpec(
        String(_required(provenance_raw, "origin", "provenance")),
        _strings(_required(provenance_raw, "source_ids", "provenance")),
        _strings(_required(provenance_raw, "parent_design_ids", "provenance")),
        String(_required(provenance_raw, "claim_level", "provenance")),
        _strings(get(provenance_raw, "notes", Any[])),
    )

    return Genome(
        schema_version,
        design_id,
        get(normalized, "label", nothing) === nothing ? nothing : String(normalized["label"]),
        mission,
        String(_required(normalized, "family", "genome")),
        topology,
        symmetry,
        plasma_regions,
        field_sources,
        actuators,
        compression_systems,
        mechanisms,
        connections,
        exhaust,
        engineering,
        provenance,
        normalized,
        canonical_hash(normalized),
        canonical_hash(physics_projection(normalized)),
    )
end

function load_genome(path::AbstractString)
    data = JSON3.read(read(path, String), Dict{String,Any})
    return parse_genome(data)
end

function load_genomes(path::AbstractString)
    data = _plain_json(JSON3.read(read(path, String), Dict{String,Any}))
    designs = haskey(data, "designs") ? data["designs"] : Any[data]
    return Genome[parse_genome(item) for item in designs]
end

function _check_unique!(errors, label, ids)
    duplicates = sort!(String[id for id in unique(ids) if count(==(id), ids) > 1])
    isempty(duplicates) || push!(errors, "$label IDs are not unique: $(join(duplicates, ", "))")
end

"Semantic graph checks beyond JSON Schema; missing physics remains warning/coverage, never zero."
function validate_genome(genome::Genome)
    errors = String[]
    warnings = String[]

    genome.schema_version == "0.1.0" ||
        push!(errors, "unsupported schema_version $(genome.schema_version)")
    genome.provenance.origin in
        ("known_device_seed", "literature_concept_seed", "generated", "human_authored") ||
        push!(errors, "unsupported provenance origin $(genome.provenance.origin)")
    isempty(genome.plasma_regions) && push!(errors, "at least one plasma region is required")
    isempty(genome.field_sources) && push!(errors, "at least one field source is required")
    isempty(genome.stability_mechanisms) && push!(errors, "at least one stability mechanism is required")

    _check_unique!(errors, "plasma region", getfield.(genome.plasma_regions, :id))
    _check_unique!(errors, "field source", getfield.(genome.field_sources, :id))
    _check_unique!(errors, "actuator", getfield.(genome.actuators, :id))
    _check_unique!(errors, "compression system",
        getfield.(genome.compression_systems, :id))
    _check_unique!(errors, "stability mechanism", getfield.(genome.stability_mechanisms, :id))

    region_ids = Set(getfield.(genome.plasma_regions, :id))
    actuator_ids = Set(getfield.(genome.actuators, :id))
    for connection in genome.flux_connections
        connection.from_region_id in region_ids ||
            push!(errors, "flux connection references missing region $(connection.from_region_id)")
        connection.to_region_id in region_ids ||
            push!(errors, "flux connection references missing region $(connection.to_region_id)")
    end
    for region_id in genome.exhaust.region_ids
        region_id in region_ids || push!(errors, "exhaust references missing region $region_id")
    end
    for mechanism in genome.stability_mechanisms
        for actuator_id in mechanism.actuator_ids
            actuator_id in actuator_ids ||
                push!(errors, "mechanism $(mechanism.id) references missing actuator $actuator_id")
        end
        mechanism.mechanism == "sheared_flow" && isempty(mechanism.actuator_ids) &&
            push!(errors, "sheared_flow mechanism $(mechanism.id) requires an actuator")
    end
    for system in genome.compression_systems
        isempty(system.driver_actuator_ids) &&
            push!(errors, "compression system $(system.id) requires a driver actuator")
        isempty(system.target_region_ids) &&
            push!(errors, "compression system $(system.id) requires a target region")
        for actuator_id in system.driver_actuator_ids
            actuator_id in actuator_ids || push!(errors,
                "compression system $(system.id) references missing actuator $actuator_id")
        end
        for region_id in system.target_region_ids
            region_id in region_ids || push!(errors,
                "compression system $(system.id) references missing region $region_id")
        end
    end

    if genome.family == "tokamak_axisymmetric"
        startswith(genome.topology.field_line_class, "closed_toroidal") ||
            push!(errors, "axisymmetric tokamak requires closed toroidal field lines")
        genome.symmetry.class == "axisymmetric" ||
            push!(errors, "axisymmetric tokamak requires axisymmetric symmetry class")
        "plasma_current" in genome.topology.rotation_transform_sources ||
            push!(errors, "tokamak must declare plasma_current as a transform source")
    elseif genome.family == "stellarator"
        startswith(genome.topology.field_line_class, "closed_toroidal") ||
            push!(errors, "stellarator requires closed toroidal field lines")
        "three_dimensional_external_field" in genome.topology.rotation_transform_sources ||
            push!(errors, "stellarator must declare three_dimensional_external_field")
    elseif genome.family == "magnetic_mirror"
        genome.topology.field_line_class == "open_mirror" ||
            push!(errors, "magnetic mirror requires open_mirror field lines")
        genome.topology.rotation_transform_sources == ["not_applicable"] ||
            push!(errors, "magnetic mirror transform source must be only not_applicable")
        open_connections = count(item -> item.kind == "open_field_line", genome.flux_connections)
        open_connections >= 2 ||
            push!(errors, "magnetic mirror requires at least two explicit open end connections")
    elseif genome.family == "magnetized_target_fusion"
        genome.mission.operating_mode == "pulsed" ||
            push!(errors, "magnetized target fusion requires pulsed operating mode")
        genome.topology.field_line_class in ("compact_toroid", "mixed") ||
            push!(errors, "magnetized target fusion requires compact_toroid or mixed target field lines")
        isempty(genome.compression_systems) &&
            push!(errors, "magnetized target fusion requires an explicit compression system")
        genome.exhaust.kind == "pulsed_chamber" ||
            push!(errors, "magnetized target fusion requires a pulsed chamber exhaust model")
    end

    if genome.mission.kind == "net_electric_pilot"
        genome.engineering.blanket_required ||
            push!(errors, "net_electric_pilot requires a breeding blanket")
        genome.engineering.blanket_concept === nothing &&
            push!(errors, "net_electric_pilot requires a concrete blanket concept")
        genome.engineering.target_tbr === nothing &&
            push!(errors, "net_electric_pilot requires target_tbr")
    elseif genome.engineering.blanket_required && genome.engineering.blanket_concept === nothing
        push!(warnings, "blanket is required but its concept is still unknown")
    end

    isempty(genome.engineering.required_evaluators) &&
        push!(warnings, "no engineering evaluators declared")
    genome.provenance.claim_level == "structural_example" &&
        push!(warnings, "structural seed: no performance claim is permitted")

    return ValidationReport(isempty(errors), errors, warnings)
end

function quantity(genome::Genome, collection::Symbol, entity_id::String, parameter::String)
    entities = getfield(genome, collection)
    matches = filter(item -> getfield(item, :id) == entity_id, entities)
    length(matches) == 1 || return nothing
    return get(getfield(only(matches), :parameters), parameter, nothing)
end
