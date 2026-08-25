const _DIRECTED_SOURCE_FRAME_KINDS_V1 = Set((:cartesian_right_handed,))
const _DIRECTED_SOURCE_APERTURE_SHAPES_V1 = Set((:rectangle, :ellipse))
const _DIRECTED_SOURCE_FRACTION_BASES_V1 = Set((:neutral_particle_number_fraction,))
const _DIRECTED_SOURCE_NORMALIZATION_RULES_V1 = Set((
    :fractions_sum_to_one_and_total_power_sets_total_neutral_rate,))
const _ELEMENTARY_CHARGE_C_V1 = 1.602176634e-19

"A named, right-handed physical coordinate frame for a directed source."
struct DirectedSourceCoordinateFrameV1
    id::String
    kind::Symbol
    origin_definition::String
end

"A beamline aperture located along the source-to-target axis."
struct DirectedSourceApertureV1
    id::String
    shape::Symbol
    axial_distance_m::Float64
    size_m::Vector{Float64}
    transverse_offset_m::Vector{Float64}
end

"One monoenergetic component of a directed particle source."
struct DirectedSourceEnergyComponentV1
    id::String
    energy_ratio_to_primary::Float64
    molecular_energy_denominator::Int
    fraction::Float64
end

"Logical-to-Genome actuator parameter bindings; names are not physical identity."
struct DirectedSourceActuatorBindingsV1
    declared_power_parameter_id::String
    primary_energy_parameter_id::String
    source_current_parameter_id::String
    charge_state_parameter_id::String
    component_fraction_parameter_ids::Vector{String}
end

"Topology-independent geometry and spectrum IR for a directed particle source."
struct DirectedParticleSourceIRV1
    id::String
    actuator_id::String
    target_domain_ids::Vector{String}
    injected_species_id::String
    source_charge_state::Int
    particle_mass_kg::Float64
    coordinate_frame::DirectedSourceCoordinateFrameV1
    source_position_m::Vector{Float64}
    target_position_m::Vector{Float64}
    divergence_half_angles_rad::Vector{Float64}
    focal_lengths_m::Vector{Float64}
    emitter_size_m::Vector{Float64}
    apertures::Vector{DirectedSourceApertureV1}
    declared_power_w::Float64
    primary_particle_energy_j::Float64
    declared_source_current_a::Float64
    spectrum_fraction_basis::Symbol
    spectrum_normalization_rule::Symbol
    energy_components::Vector{DirectedSourceEnergyComponentV1}
    actuator_parameter_bindings::DirectedSourceActuatorBindingsV1
    source_ids::Vector{String}
end

"Executable Genome 0.3: equation modules plus concrete directed source physics."
struct ExecutableGenomeV2
    schema_version::String
    base_genome::Genome
    modules::Vector{ExecutablePhysicsModuleV1}
    directed_particle_sources::Vector{DirectedParticleSourceIRV1}
    document_hash::String
    candidate_physics_hash::String
end

function _finite_float_v1(value, context::String)
    result = Float64(value)
    isfinite(result) || throw(ArgumentError("$context must be finite"))
    return result
end

function _float_vector_v1(value, context::String)
    return Float64[_finite_float_v1(item, context) for item in value]
end

function _parse_directed_source_frame_v1(raw, context::String)
    return DirectedSourceCoordinateFrameV1(
        String(_required(raw, "id", context)),
        Symbol(_required(raw, "kind", context)),
        String(_required(raw, "origin_definition", context)))
end

function _parse_directed_source_aperture_v1(raw, context::String)
    return DirectedSourceApertureV1(
        String(_required(raw, "id", context)),
        Symbol(_required(raw, "shape", context)),
        _finite_float_v1(_required(raw, "axial_distance_m", context),
            "$context.axial_distance_m"),
        _float_vector_v1(_required(raw, "size_m", context), "$context.size_m"),
        _float_vector_v1(_required(raw, "transverse_offset_m", context),
            "$context.transverse_offset_m"))
end

function _parse_directed_source_component_v1(raw, context::String)
    return DirectedSourceEnergyComponentV1(
        String(_required(raw, "id", context)),
        _finite_float_v1(_required(raw, "energy_ratio_to_primary", context),
            "$context.energy_ratio_to_primary"),
        Int(_required(raw, "molecular_energy_denominator", context)),
        _finite_float_v1(_required(raw, "fraction", context), "$context.fraction"))
end

function _parse_directed_source_bindings_v1(raw, context::String)
    return DirectedSourceActuatorBindingsV1(
        String(_required(raw, "declared_power_parameter_id", context)),
        String(_required(raw, "primary_energy_parameter_id", context)),
        String(_required(raw, "source_current_parameter_id", context)),
        String(_required(raw, "charge_state_parameter_id", context)),
        _strings(_required(raw, "component_fraction_parameter_ids", context)))
end

function _parse_directed_particle_source_v1(raw, index::Int)
    context = "directed_particle_sources[$index]"
    return DirectedParticleSourceIRV1(
        String(_required(raw, "id", context)),
        String(_required(raw, "actuator_id", context)),
        _strings(_required(raw, "target_domain_ids", context)),
        String(_required(raw, "injected_species_id", context)),
        Int(_required(raw, "source_charge_state", context)),
        _finite_float_v1(_required(raw, "particle_mass_kg", context),
            "$context.particle_mass_kg"),
        _parse_directed_source_frame_v1(_required(raw, "coordinate_frame", context),
            "$context.coordinate_frame"),
        _float_vector_v1(_required(raw, "source_position_m", context),
            "$context.source_position_m"),
        _float_vector_v1(_required(raw, "target_position_m", context),
            "$context.target_position_m"),
        _float_vector_v1(_required(raw, "divergence_half_angles_rad", context),
            "$context.divergence_half_angles_rad"),
        _float_vector_v1(_required(raw, "focal_lengths_m", context),
            "$context.focal_lengths_m"),
        _float_vector_v1(_required(raw, "emitter_size_m", context),
            "$context.emitter_size_m"),
        DirectedSourceApertureV1[_parse_directed_source_aperture_v1(item,
            "$context.apertures[$j]") for (j, item) in
                enumerate(_required(raw, "apertures", context))],
        _finite_float_v1(_required(raw, "declared_power_w", context),
            "$context.declared_power_w"),
        _finite_float_v1(_required(raw, "primary_particle_energy_j", context),
            "$context.primary_particle_energy_j"),
        _finite_float_v1(_required(raw, "declared_source_current_a", context),
            "$context.declared_source_current_a"),
        Symbol(_required(raw, "spectrum_fraction_basis", context)),
        Symbol(_required(raw, "spectrum_normalization_rule", context)),
        DirectedSourceEnergyComponentV1[_parse_directed_source_component_v1(item,
            "$context.energy_components[$j]") for (j, item) in
                enumerate(_required(raw, "energy_components", context))],
        _parse_directed_source_bindings_v1(
            _required(raw, "actuator_parameter_bindings", context),
            "$context.actuator_parameter_bindings"),
        _strings(_required(raw, "source_ids", context)))
end

function directed_source_frame_to_dict_v1(item::DirectedSourceCoordinateFrameV1)
    return Dict{String,Any}("id" => item.id, "kind" => String(item.kind),
        "origin_definition" => item.origin_definition)
end

function directed_source_aperture_to_dict_v1(item::DirectedSourceApertureV1)
    return Dict{String,Any}("id" => item.id, "shape" => String(item.shape),
        "axial_distance_m" => item.axial_distance_m, "size_m" => item.size_m,
        "transverse_offset_m" => item.transverse_offset_m)
end

function directed_source_component_to_dict_v1(item::DirectedSourceEnergyComponentV1)
    return Dict{String,Any}("id" => item.id,
        "energy_ratio_to_primary" => item.energy_ratio_to_primary,
        "molecular_energy_denominator" => item.molecular_energy_denominator,
        "fraction" => item.fraction)
end

function directed_source_bindings_to_dict_v1(item::DirectedSourceActuatorBindingsV1)
    return Dict{String,Any}(
        "declared_power_parameter_id" => item.declared_power_parameter_id,
        "primary_energy_parameter_id" => item.primary_energy_parameter_id,
        "source_current_parameter_id" => item.source_current_parameter_id,
        "charge_state_parameter_id" => item.charge_state_parameter_id,
        "component_fraction_parameter_ids" => item.component_fraction_parameter_ids)
end

function directed_particle_source_to_dict_v1(item::DirectedParticleSourceIRV1;
        include_binding::Bool = true, include_sources::Bool = true)
    result = Dict{String,Any}(
        "id" => item.id, "actuator_id" => item.actuator_id,
        "target_domain_ids" => item.target_domain_ids,
        "injected_species_id" => item.injected_species_id,
        "source_charge_state" => item.source_charge_state,
        "particle_mass_kg" => item.particle_mass_kg,
        "coordinate_frame" => directed_source_frame_to_dict_v1(item.coordinate_frame),
        "source_position_m" => item.source_position_m,
        "target_position_m" => item.target_position_m,
        "divergence_half_angles_rad" => item.divergence_half_angles_rad,
        "focal_lengths_m" => item.focal_lengths_m,
        "emitter_size_m" => item.emitter_size_m,
        "apertures" => directed_source_aperture_to_dict_v1.(item.apertures),
        "declared_power_w" => item.declared_power_w,
        "primary_particle_energy_j" => item.primary_particle_energy_j,
        "declared_source_current_a" => item.declared_source_current_a,
        "spectrum_fraction_basis" => String(item.spectrum_fraction_basis),
        "spectrum_normalization_rule" => String(item.spectrum_normalization_rule),
        "energy_components" => directed_source_component_to_dict_v1.(item.energy_components))
    include_binding && (result["actuator_parameter_bindings"] =
        directed_source_bindings_to_dict_v1(item.actuator_parameter_bindings))
    include_sources && (result["source_ids"] = item.source_ids)
    return result
end

function _module_physics_dict_v2(item::ExecutablePhysicsModuleV1)
    result = executable_module_to_dict_v1(item)
    delete!(result, "source_ids")
    return result
end

function _candidate_physics_payload_v2(base_genome::Genome,
        modules::Vector{ExecutablePhysicsModuleV1},
        sources::Vector{DirectedParticleSourceIRV1})
    return Dict{String,Any}(
        "schema_version" => "0.3.0",
        "base_genome_physics_hash" => base_genome.physics_hash,
        "physics_modules" => _module_physics_dict_v2.(modules),
        "directed_particle_sources" => [directed_particle_source_to_dict_v1(item;
            include_binding = false, include_sources = false) for item in sources])
end

"Parse a self-contained executable Genome 0.3 and compute its physical identity."
function parse_executable_genome_v2(base_genome::Genome, raw)
    data = _plain_json(raw)
    version = String(_required(data, "schema_version", "executable_genome_v2"))
    expected_hash = String(_required(data, "base_genome_physics_hash",
        "executable_genome_v2"))
    expected_hash == base_genome.physics_hash || throw(ArgumentError(
        "executable Genome v2 base hash does not match the supplied Genome"))
    modules = ExecutablePhysicsModuleV1[_parse_executable_module_v1(item, index)
        for (index, item) in enumerate(_required(data, "physics_modules",
            "executable_genome_v2"))]
    sources = DirectedParticleSourceIRV1[_parse_directed_particle_source_v1(item, index)
        for (index, item) in enumerate(_required(data, "directed_particle_sources",
            "executable_genome_v2"))]
    physics_hash = canonical_hash(_candidate_physics_payload_v2(base_genome,
        modules, sources))
    return ExecutableGenomeV2(version, base_genome, modules, sources,
        canonical_hash(data), physics_hash)
end

function load_executable_genome_v2(base_genome_path::AbstractString,
        executable_path::AbstractString)
    genome = load_genome(base_genome_path)
    raw = JSON3.read(read(executable_path, String), Dict{String,Any})
    return parse_executable_genome_v2(genome, raw)
end

function executable_genome_v1_projection(item::ExecutableGenomeV2)
    payload = Dict{String,Any}("schema_version" => "0.2.0",
        "base_genome_physics_hash" => item.base_genome.physics_hash,
        "physics_modules" => executable_module_to_dict_v1.(item.modules))
    return ExecutableGenomeV1("0.2.0", item.base_genome, item.modules,
        canonical_hash(payload))
end

function _approximately_equal_v1(a::Real, b::Real; rtol = 1.0e-12, atol = 1.0e-15)
    return abs(Float64(a) - Float64(b)) <= atol + rtol * max(abs(Float64(a)), abs(Float64(b)))
end

function _validate_directed_particle_source_v1!(errors::Vector{String},
        warnings::Vector{String}, item::DirectedParticleSourceIRV1, genome::Genome)
    context = "directed source $(item.id)"
    item.coordinate_frame.kind in _DIRECTED_SOURCE_FRAME_KINDS_V1 ||
        push!(errors, "$context has unsupported coordinate frame kind")
    item.spectrum_fraction_basis in _DIRECTED_SOURCE_FRACTION_BASES_V1 ||
        push!(errors, "$context has unsupported spectrum fraction basis")
    item.spectrum_normalization_rule in _DIRECTED_SOURCE_NORMALIZATION_RULES_V1 ||
        push!(errors, "$context has unsupported spectrum normalization rule")
    length(item.source_position_m) == 3 || push!(errors, "$context source position must have 3 values")
    length(item.target_position_m) == 3 || push!(errors, "$context target position must have 3 values")
    if length(item.source_position_m) == 3 && length(item.target_position_m) == 3
        norm(item.target_position_m - item.source_position_m) > 0.0 ||
            push!(errors, "$context source and target positions must differ")
    end
    for (name, values) in (("divergence", item.divergence_half_angles_rad),
            ("focal lengths", item.focal_lengths_m), ("emitter size", item.emitter_size_m))
        length(values) == 2 || push!(errors, "$context $name must have 2 values")
        all(isfinite, values) || push!(errors, "$context $name must be finite")
    end
    all(>=(0.0), item.divergence_half_angles_rad) ||
        push!(errors, "$context divergence must be nonnegative")
    all(>(0.0), item.focal_lengths_m) || push!(errors, "$context focal lengths must be positive")
    all(>(0.0), item.emitter_size_m) || push!(errors, "$context emitter size must be positive")
    item.particle_mass_kg > 0.0 || push!(errors, "$context particle mass must be positive")
    item.source_charge_state > 0 || push!(errors, "$context source charge state must be positive")
    item.declared_power_w > 0.0 || push!(errors, "$context power must be positive")
    item.primary_particle_energy_j > 0.0 || push!(errors, "$context primary energy must be positive")
    item.declared_source_current_a > 0.0 || push!(errors, "$context source current must be positive")
    isempty(item.apertures) && push!(errors, "$context requires at least one aperture")
    aperture_ids = getfield.(item.apertures, :id)
    length(unique(aperture_ids)) == length(aperture_ids) ||
        push!(errors, "$context aperture IDs must be unique")
    distances = getfield.(item.apertures, :axial_distance_m)
    issorted(distances) || push!(errors, "$context apertures must be ordered from source to target")
    for aperture in item.apertures
        aperture.shape in _DIRECTED_SOURCE_APERTURE_SHAPES_V1 ||
            push!(errors, "$context aperture $(aperture.id) has unsupported shape")
        aperture.axial_distance_m > 0.0 ||
            push!(errors, "$context aperture $(aperture.id) distance must be positive")
        length(aperture.size_m) == 2 && all(>(0.0), aperture.size_m) ||
            push!(errors, "$context aperture $(aperture.id) size must contain 2 positive values")
        length(aperture.transverse_offset_m) == 2 ||
            push!(errors, "$context aperture $(aperture.id) offset must contain 2 values")
    end
    isempty(item.energy_components) && push!(errors, "$context requires energy components")
    component_ids = getfield.(item.energy_components, :id)
    length(unique(component_ids)) == length(component_ids) ||
        push!(errors, "$context energy-component IDs must be unique")
    fractions = getfield.(item.energy_components, :fraction)
    all(x -> x >= 0.0, fractions) || push!(errors, "$context component fractions must be nonnegative")
    _approximately_equal_v1(sum(fractions), 1.0) ||
        push!(errors, "$context component fractions must sum to one")
    for component in item.energy_components
        component.molecular_energy_denominator > 0 ||
            push!(errors, "$context component $(component.id) denominator must be positive")
        component.energy_ratio_to_primary > 0.0 ||
            push!(errors, "$context component $(component.id) energy ratio must be positive")
        _approximately_equal_v1(component.energy_ratio_to_primary,
            1.0 / component.molecular_energy_denominator) || push!(errors,
            "$context component $(component.id) energy ratio and denominator disagree")
    end
    actuator_index = findfirst(actuator -> actuator.id == item.actuator_id, genome.actuators)
    actuator_index === nothing && push!(errors, "$context actuator is absent from base Genome")
    known_domains = Set(getfield.(genome.plasma_regions, :id))
    unknown_domains = sort!(String[id for id in item.target_domain_ids if !(id in known_domains)])
    isempty(unknown_domains) || push!(errors, "$context has unknown target domains: $(join(unknown_domains, ", "))")
    isempty(item.target_domain_ids) && push!(errors, "$context requires at least one target domain")
    isempty(item.source_ids) && push!(warnings, "$context has no provenance source IDs")
    if actuator_index !== nothing
        params = genome.actuators[actuator_index].parameters
        binding = item.actuator_parameter_bindings
        ids = [binding.declared_power_parameter_id, binding.primary_energy_parameter_id,
            binding.source_current_parameter_id, binding.charge_state_parameter_id]
        append!(ids, binding.component_fraction_parameter_ids)
        missing = sort!(String[id for id in ids if !haskey(params, id)])
        isempty(missing) || push!(errors, "$context actuator bindings are missing: $(join(missing, ", "))")
        if isempty(missing)
            _approximately_equal_v1(params[binding.declared_power_parameter_id].value,
                item.declared_power_w) || push!(errors, "$context power disagrees with actuator")
            _approximately_equal_v1(params[binding.primary_energy_parameter_id].value,
                item.primary_particle_energy_j) || push!(errors, "$context primary energy disagrees with actuator")
            _approximately_equal_v1(params[binding.source_current_parameter_id].value,
                item.declared_source_current_a) || push!(errors, "$context current disagrees with actuator")
            _approximately_equal_v1(params[binding.charge_state_parameter_id].value,
                item.source_charge_state) || push!(errors, "$context charge state disagrees with actuator")
            length(binding.component_fraction_parameter_ids) == length(item.energy_components) ||
                push!(errors, "$context component binding count disagrees with spectrum")
            if length(binding.component_fraction_parameter_ids) == length(item.energy_components)
                for (parameter_id, component) in zip(binding.component_fraction_parameter_ids,
                        item.energy_components)
                    _approximately_equal_v1(params[parameter_id].value, component.fraction) ||
                        push!(errors, "$context component $(component.id) disagrees with actuator")
                end
            end
        end
    end
    voltage_v = item.primary_particle_energy_j /
        (item.source_charge_state * _ELEMENTARY_CHARGE_C_V1)
    _approximately_equal_v1(item.declared_power_w,
        item.declared_source_current_a * voltage_v; rtol = 2.0e-12, atol = 1.0e-9) ||
        push!(errors, "$context power, primary energy, charge state, and current do not close")
end

"Validate both the inherited 0.2 program and all concrete source declarations."
function validate_executable_genome_v2(item::ExecutableGenomeV2;
        registry::Vector{PhysicsOperatorSpecV1} = default_physics_operator_registry_v1())
    base = validate_executable_genome_v1(executable_genome_v1_projection(item);
        registry = registry)
    errors = copy(base.errors)
    warnings = copy(base.warnings)
    item.schema_version == "0.3.0" || push!(errors,
        "unsupported executable Genome v2 schema $(item.schema_version)")
    isempty(item.directed_particle_sources) && push!(errors,
        "at least one directed particle source is required")
    ids = getfield.(item.directed_particle_sources, :id)
    length(unique(ids)) == length(ids) || push!(errors,
        "directed particle source IDs must be unique")
    for source in item.directed_particle_sources
        _validate_directed_particle_source_v1!(errors, warnings, source, item.base_genome)
    end
    return ExecutablePhysicsValidationV1(isempty(errors), sort!(unique(errors)),
        sort!(unique(warnings)))
end

function executable_genome_to_dict_v2(item::ExecutableGenomeV2)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "base_genome_physics_hash" => item.base_genome.physics_hash,
        "physics_modules" => executable_module_to_dict_v1.(item.modules),
        "directed_particle_sources" => directed_particle_source_to_dict_v1.(
            item.directed_particle_sources),
        "document_hash" => item.document_hash,
        "candidate_physics_hash" => item.candidate_physics_hash)
end

"Compile the generic source IR to the exact public pyFIDASIM NBI input contract."
function compile_pyfidasim_nbi_input_v1(item::DirectedParticleSourceIRV1)
    length(item.apertures) == 2 || throw(ArgumentError(
        "pyFIDASIM v1 adapter requires exactly two apertures"))
    all(aperture -> aperture.shape == :rectangle, item.apertures) ||
        throw(ArgumentError("pyFIDASIM v1 adapter currently requires rectangular apertures"))
    voltage_kv = item.primary_particle_energy_j /
        (item.source_charge_state * _ELEMENTARY_CHARGE_C_V1) / 1.0e3
    aperture_fields = Dict{String,Any}()
    for (index, aperture) in enumerate(item.apertures)
        aperture_fields["aperture_$(index)_distance_cm"] = aperture.axial_distance_m * 100.0
        aperture_fields["aperture_$(index)_size_cm"] = aperture.size_m .* 100.0
        aperture_fields["aperture_$(index)_offset_cm"] = aperture.transverse_offset_m .* 100.0
        aperture_fields["aperture_$(index)_rectangular"] = true
    end
    result = Dict{String,Any}(
        "geometry_status" => "executable_genome_candidate_declaration",
        "source_ir_id" => item.id,
        "beam_mass_amu" => item.particle_mass_kg / 1.66053906660e-27,
        "power_mw" => item.declared_power_w / 1.0e6,
        "voltage_kv" => voltage_kv,
        "current_fractions" => getfield.(item.energy_components, :fraction),
        "current_fractions_semantic_basis" => String(item.spectrum_fraction_basis),
        "source_position_cm" => item.source_position_m .* 100.0,
        "target_position_cm" => item.target_position_m .* 100.0,
        "divergence_rad" => item.divergence_half_angles_rad,
        "focal_length_cm" => item.focal_lengths_m .* 100.0,
        "ion_source_size_cm" => item.emitter_size_m .* 100.0)
    merge!(result, aperture_fields)
    return result
end
