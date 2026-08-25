const _V18_COMMON_FAMILIES = Set([
    "tokamak_axisymmetric", "tokamak_3d_hybrid", "stellarator",
    "magnetic_mirror", "field_reversed_configuration", "spheromak",
])

const _V18_CLAIM_BOUNDARY =
    "V18 compiles every retained v17 five-layer assembly into the typed Genome IR and " *
    "executes a declared family-specific fidelity-0 rejection projection. Attribute-graph " *
    "identity, dependency edges, source IDs, mission contract, and required evaluators are " *
    "preserved, but module-specific geometry is not thereby solved. A proxy five-gate pass " *
    "is not equilibrium, all-mode stability, transport, exhaust, coil, material, lifetime, " *
    "availability, net-electric, novelty, superiority, or reactor evidence. Missing declared " *
    "requirements remain unknown and block the medium-fidelity candidate queue."

"One v17 assembly compiled into a typed Genome plus its declared proxy projection."
struct CompiledAttributeGenomeV18
    assembly_id::String
    graph_hash::String
    family::String
    mission_contract_id::String
    module_ids::Vector{String}
    genome::Genome
    evaluator_id::String
    projection_id::String
    projection_limitations::Vector{String}
    declared_requirements::Vector{String}
    validation_warnings::Vector{String}
end

"A compact, claim-bounded record of the executable fidelity-0 route."
struct AttributeGenomePrescreenV18
    compiled::CompiledAttributeGenomeV18
    proxy_applicable::Bool
    applicability_reason::String
    gates::Dict{String,Bool}
    proxy_five_gate_passed::Bool
    robustness_pass_fraction::Float64
    positive_net_power_closure::Bool
    missing_proxy_requirements::Vector{String}
    proxy_coverage_complete::Bool
    medium_fidelity_candidate_eligible::Bool
    topology_graph_errors::Vector{String}
    proxy_result_hash::String
end

struct AttributeGraphGenomePipelineResultV18
    input_archive_hash::String
    catalog_hash::String
    records::Vector{AttributeGenomePrescreenV18}
    compiled_family_counts::Dict{String,Int}
    evaluator_route_counts::Dict{String,Int}
    proxy_five_gate_family_counts::Dict{String,Int}
    missing_requirement_counts::Dict{String,Int}
    evidence_gap_queue::Vector{Dict{String,Any}}
    medium_fidelity_candidate_queue::Vector{Dict{String,Any}}
    claim_boundary::String
end

struct _AttributeGraphCompilerContextV18
    seeds::Vector{Genome}
    tokamak_parent::Genome
    outer::SharedOuterEnvelopeContractV1
    icf::LaserICFPulsedContractV1
    v9_bases::Dict{String,Genome}
end

function _v18_context(seeds::Vector{Genome})
    tokamaks = filter(genome -> genome.family == "tokamak_axisymmetric", seeds)
    isempty(tokamaks) && throw(ArgumentError("v18 requires a tokamak structural parent"))
    outer = only(filter(contract -> contract.id == "outer_reference_B4_v1",
        shared_outer_envelope_contracts_v1()))
    icf = only(filter(contract -> contract.id == "laser_icf_reference_chamber_v1",
        laser_icf_pulsed_contracts_v1()))
    return _AttributeGraphCompilerContextV18(seeds, first(tokamaks), outer, icf,
        _ccv9_structural_bases(seeds))
end

function _v18_unit_vector(graph_hash::String, count::Int)
    length(graph_hash) == 64 || throw(ArgumentError("v18 graph hash must be SHA-256"))
    bytes = Float64[parse(Int, graph_hash[index:index + 1]; base = 16) / 255.0
        for index in 1:2:63]
    return Float64[0.02 + 0.96 * bytes[mod(index - 1, length(bytes)) + 1]
        for index in 1:count]
end

function _v18_target_count(assembly::TopologyAssemblyV17; default::Int = 2)
    tags = filter(tag -> startswith(tag, "target_count:"), assembly.tags)
    isempty(tags) && return default
    return parse(Int, split(first(tags), ":"; limit = 2)[2])
end

function _v18_nearest_target_count(value::Int; minimum::Int = 2)
    allowed = filter(>=(minimum), [2, 4, 8])
    return first(sort!(allowed; by = item -> (abs(item - value), item)))
end

function _v18_v9_key(assembly::TopologyAssemblyV17)
    family = assembly.family
    field, stability, exhaust = assembly.module_ids[2:4]
    requested_count = _v18_target_count(assembly)
    if family == "tokamak_axisymmetric"
        topology = exhaust == "super_x" ? "super_x_long_leg" : "distributed_targets"
        count = topology == "super_x_long_leg" ? 2 :
            _v18_nearest_target_count(requested_count)
        return join((family, "plasma_current_q_profile", topology,
            "targets=$count"), "|")
    elseif family == "tokamak_3d_hybrid"
        mechanism = occursin("programmable", field) || occursin("active", stability) ?
            "programmable_qa_current" : "fixed_qa_current"
        topology = occursin("island", exhaust) ?
            "boundary_island_divertor" : "distributed_targets"
        count = _v18_nearest_target_count(requested_count;
            minimum = topology == "boundary_island_divertor" ? 4 : 2)
        return join((family, mechanism, topology, "targets=$count"), "|")
    elseif family == "stellarator"
        mechanism = assembly.module_ids[1] == "stellarator_qi" ?
            "quasi_isodynamic" : "quasi_axisymmetric"
        topology = occursin("island", exhaust) ?
            "boundary_island_divertor" : "distributed_targets"
        count = _v18_nearest_target_count(requested_count;
            minimum = topology == "boundary_island_divertor" ? 4 : 2)
        return join((family, mechanism, topology, "targets=$count"), "|")
    elseif family == "magnetic_mirror"
        mechanism = stability == "mirror_vortex_bias" ?
            "centrifugal_exb_shear" : "minimum_b_beam_plug"
        return join((family, mechanism, "two_end_expander", "targets=2"), "|")
    elseif family == "field_reversed_configuration"
        mechanism = occursin("rmf", field) ? "rotating_magnetic_field" :
            occursin("nbi", field) ? "beam_driven_fast_ion" : "beam_plus_end_bias"
        count = _v18_nearest_target_count(requested_count)
        return join((family, mechanism, "distributed_targets", "targets=$count"), "|")
    elseif family == "spheromak"
        mechanism = occursin("inductive", field) ?
            "imposed_dynamo_current_drive" : "steady_inductive_helicity_injection"
        count = _v18_nearest_target_count(requested_count)
        return join((family, mechanism, "distributed_targets", "targets=$count"), "|")
    end
    throw(ArgumentError("family $family has no v9 projection"))
end

function _v18_common_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17)
    key = _v18_v9_key(assembly)
    haskey(context.v9_bases, key) || throw(ArgumentError(
        "v18 cannot locate v9 structural projection $key"))
    spec = only(filter(item -> _ccv9_key(item) == key, _ccv9_topology_specs()))
    values = _ccv9_ranges(spec, _v18_unit_vector(assembly.graph_hash, 12))
    genome = _ccv9_instantiate(context.v9_bases[key], values, context.outer)
    limitations = String[
        "v9 family projection retains high-level topology but does not realize every v17 module geometry",
    ]
    assembly.module_ids[1] == "stellarator_qh" && push!(limitations,
        "quasi-helical core is evaluated through the nearest registered stellarator proxy branch")
    requested = _v18_target_count(assembly)
    mapped = parse(Int, split(last(split(key, "|")), "="; limit = 2)[2])
    requested != mapped && push!(limitations,
        "declared target count $requested is projected to registered target count $mapped")
    return genome, "composable_cross_family_screen_v1", key, limitations
end

function _v18_rfp_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17)
    stability = assembly.module_ids[3]
    mechanism = stability == "rfp_boundary_control" ?
        "qsh_ppcd_boundary_mode_control" : stability == "rfp_ppcd_profile" ?
        "qsh_pulsed_poloidal_current_drive" : "self_organized_qsh"
    count = _v18_nearest_target_count(_v18_target_count(assembly))
    spec = ProfileCoupledRFPTopologySpecV8(mechanism, count)
    base = _pcrfp_structural_base_v8(context.tokamak_parent, spec)
    values = _pcrfp_ranges_v8(spec, _v18_unit_vector(assembly.graph_hash, 24))
    genome = _pcrfp_instantiate_v8(base, values, context.outer)
    return genome, "profile_coupled_rfp_screen_v1", _pcrfp_key_v8(spec), String[
        "profile-coupled cylindrical RFP proxy does not realize the selected boundary hardware in detail",
    ]
end

function _v18_dipole_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17)
    count = _v18_nearest_target_count(_v18_target_count(assembly; default = 2))
    spec = SelfOrganizedTopologySpecV7("levitated_dipole",
        "levitated_inward_pinch", count)
    base = _sov7_structural_base(context.tokamak_parent, spec)
    values = _sov7_ranges(spec, _v18_unit_vector(assembly.graph_hash, 24))
    genome = _sov7_instantiate(base, values, context.outer)
    limitations = String[
        "dipole proxy uses a levitated reference even when the v17 field module declares a supported coil",
        "internal-coil heat removal and support are unresolved module-specific requirements",
    ]
    return genome, "self_organized_screen_v1", _sov7_key(spec), limitations
end

function _v18_zpinch_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17)
    mechanism = assembly.module_ids[3] == "zpinch_active_profile" ?
        "sheared_flow_repetitive_z_pinch" : "sheared_flow_single_pulse_z_pinch"
    spec = MechanismExpansionTopologySpecV10("sheared_flow_z_pinch", mechanism,
        "two_linear_end_targets", 2)
    base = _mev10_build_z_pinch(context.tokamak_parent, spec)
    values = _mev10_ranges(spec, _v18_unit_vector(assembly.graph_hash, 24))
    genome = _mev10_instantiate(base, spec, values, context.outer)
    return genome, "mechanism_expansion_screen_v1", _mev10_key(spec), String[
        "steady net-electric v17 mission is tested with a pulsed/sheared-flow rejection formulation",
        "electrode lifetime and repetitive power coupling remain unresolved",
    ]
end

function _v18_mtf_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17)
    field = assembly.module_ids[2]
    spec = field == "mtf_pjmif" ?
        PulsedTopologySpecV6("frc", "spherical_plasma_liner", "spherical") :
        field == "mtf_maglif" ?
        PulsedTopologySpecV6("diffuse_pinch", "solid_conducting_liner", "cylindrical") :
        PulsedTopologySpecV6("frc", "solid_conducting_liner", "spherical")
    values = _pulsed_ranges_v6(spec, _v18_unit_vector(assembly.graph_hash, 14))
    genome = build_pulsed_compression_genome_v6(context.tokamak_parent, spec,
        values, context.outer)
    return genome, "pulsed_compression_screen_v1", _pulsed_key_v6(spec), String[
        "v6 non-igniting compression proxy does not realize chamber-protection or mix geometry",
    ]
end

function _v18_icf_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17)
    field, exhaust = assembly.module_ids[2], assembly.module_ids[4]
    path = field == "icf_indirect_drive" ? "laser_indirect_drive" :
        field == "icf_fast_ignition" ? "laser_fast_ignition" : "laser_direct_drive"
    protection = exhaust == "icf_liquid_protected" ? "liquid_protected" :
        exhaust == "icf_dry_wall" ? "dry_wall" : "replaceable_modular"
    spec = LaserICFTopologySpecV15(path, protection)
    values = _licfv15_ranges(spec, _v18_unit_vector(assembly.graph_hash, 18))
    genome = _licfv15_build_genome(context.tokamak_parent, spec, values, context.icf)
    limitations = String[
        "laser-ICF pulse ledger does not solve radiation hydrodynamics, mix, LPI, or lifetime",
    ]
    exhaust == "icf_gas_protected" && push!(limitations,
        "gas-protected chamber is projected to the nearest replaceable-modular v15 ledger")
    return genome, "laser_icf_screen_v1", _licfv15_key(spec), limitations
end

function _v18_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17)
    assembly.family in _V18_COMMON_FAMILIES &&
        return _v18_common_projection(context, assembly)
    assembly.family == "reversed_field_pinch" &&
        return _v18_rfp_projection(context, assembly)
    assembly.family == "levitated_dipole" &&
        return _v18_dipole_projection(context, assembly)
    assembly.family == "sheared_flow_z_pinch" &&
        return _v18_zpinch_projection(context, assembly)
    assembly.family == "magnetized_target_fusion" &&
        return _v18_mtf_projection(context, assembly)
    assembly.family == "inertial_confinement_fusion" &&
        return _v18_icf_projection(context, assembly)
    throw(ArgumentError("v18 has no proxy projection for $(assembly.family)"))
end

function _v18_push_unique!(items, additions)
    for item in additions
        String(item) in items || push!(items, String(item))
    end
    return items
end

function _v18_apply_mission_contract!(raw::Dict{String,Any}, contract_id::String)
    if contract_id == "net_electric_steady-state_v1"
        raw["mission"]["kind"] = "net_electric_pilot"
        raw["mission"]["fuel"] = "D-T"
        raw["mission"]["operating_mode"] = "steady_state"
    elseif contract_id == "net_electric_pulsed_v1"
        raw["mission"]["kind"] = "net_electric_pilot"
        raw["mission"]["fuel"] = "D-T"
        raw["mission"]["operating_mode"] = "pulsed"
    else
        throw(ArgumentError("unsupported v18 mission contract $contract_id"))
    end
    raw["engineering"]["blanket"] = Dict{String,Any}(
        "required" => true,
        "concept" => "v18_declared_breeding_blanket_screen_not_neutronics",
        "target_tbr" => Dict{String,Any}(
            "value" => 1.10, "unit" => "1",
            "basis" => "v18 declared screening target; no TBR credit"))
    return raw
end

function _v18_annotate_proxy(proxy::Genome, assembly::TopologyAssemblyV17,
        modules::Dict{String,TopologyModuleV17})
    raw = deepcopy(proxy.normalized)
    _v18_apply_mission_contract!(raw, assembly.mission_contract_id)
    constraints = raw["symmetry"]["hard_constraints"]
    _v18_push_unique!(constraints,
        ["v18_attribute_module:$(String(_V17_LAYERS[index])):$(module_id)"
            for (index, module_id) in enumerate(assembly.module_ids)])
    _v18_push_unique!(constraints, ["v18_attribute_tag:$tag" for tag in assembly.tags])
    _v18_push_unique!(constraints, ["v18_dependency_edge:$(edge.from_module_id)->" *
        "$(edge.to_module_id):$(edge.supplied_tag)" for edge in assembly.edges])
    _v18_push_unique!(constraints, ["v18_graph_hash:$(assembly.graph_hash)"])
    sort!(constraints)

    core_requirements = vcat(modules[assembly.module_ids[1]].required_evaluators,
        modules[assembly.module_ids[3]].required_evaluators)
    stability = raw["stability_mechanisms"][1]
    _v18_push_unique!(stability["required_evaluators"], core_requirements)
    _v18_push_unique!(stability["assumptions"],
        ["v18 compiled structural module $(assembly.module_ids[3]); not solved"])
    _v18_push_unique!(raw["exhaust"]["evaluation_requirements"],
        modules[assembly.module_ids[4]].required_evaluators)
    engineering_requirements = vcat(
        modules[assembly.module_ids[2]].required_evaluators,
        modules[assembly.module_ids[5]].required_evaluators)
    _v18_push_unique!(raw["engineering"]["required_evaluators"],
        engineering_requirements)
    sort!(stability["required_evaluators"])
    sort!(raw["exhaust"]["evaluation_requirements"])
    sort!(raw["engineering"]["required_evaluators"])

    provenance = raw["provenance"]
    provenance["origin"] = "generated"
    provenance["claim_level"] = "structural_example"
    _v18_push_unique!(provenance["source_ids"], assembly.source_ids)
    sort!(provenance["source_ids"])
    provenance["parent_design_ids"] = sort!(unique(String[
        proxy.design_id, assembly.assembly_id]))
    _v18_push_unique!(provenance["notes"], [
        "attribute_graph_genome_compiler_v18",
        "v17_graph_hash:$(assembly.graph_hash)",
        "typed structural compilation plus fidelity-0 projection; no performance credit",
    ])
    raw["label"] = "V18 attribute graph $(assembly.structural_descriptor)"
    raw["design_id"] = "pending_attribute_graph_v18"
    provisional = parse_genome(raw)
    raw["design_id"] = "v18_$(assembly.graph_hash[1:20])_$(provisional.physics_hash[1:12])"
    return parse_genome(raw)
end

function compile_attribute_graph_genome_v18(assembly::TopologyAssemblyV17,
        catalog::Vector{TopologyModuleV17}, seeds::Vector{Genome};
        context::_AttributeGraphCompilerContextV18 = _v18_context(seeds))
    modules = Dict(item.id => item for item in catalog)
    missing_modules = sort!(filter(id -> !haskey(modules, id), assembly.module_ids))
    isempty(missing_modules) || throw(ArgumentError(
        "v18 assembly references unknown modules: $(join(missing_modules, ", "))"))
    proxy, evaluator_id, projection_id, limitations = _v18_projection(context, assembly)
    genome = _v18_annotate_proxy(proxy, assembly, modules)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError("compiled v18 genome invalid: " *
        join(report.errors, "; ")))
    family_report = assembly.family == "inertial_confinement_fusion" ?
        validate_family(laser_icf_family_registry_v15(), genome) :
        validate_family(default_family_registry(), genome)
    family_report.valid || throw(ArgumentError("compiled v18 family invalid: " *
        join(family_report.errors, "; ")))
    genome.family == assembly.family || throw(ArgumentError(
        "compiled family does not match v17 assembly"))
    contract = mission_contract_for(default_mission_contract_registry(), genome)
    contract.id == assembly.mission_contract_id || throw(ArgumentError(
        "compiled mission contract $(contract.id) does not match " *
        assembly.mission_contract_id))
    constraints = Set(genome.symmetry.hard_constraints)
    all("v18_attribute_module:$(String(_V17_LAYERS[index])):$id" in constraints
        for (index, id) in enumerate(assembly.module_ids)) || throw(ArgumentError(
        "compiled genome lost v18 module identity"))
    "v18_graph_hash:$(assembly.graph_hash)" in constraints || throw(ArgumentError(
        "compiled genome lost graph hash"))
    issubset(Set(assembly.source_ids), Set(genome.provenance.source_ids)) ||
        throw(ArgumentError("compiled genome lost source provenance"))
    declared = sort!(unique(vcat(getfield.([modules[id]
        for id in assembly.module_ids], :required_evaluators)...)))
    issubset(Set(declared), Set(_requirements(genome))) || throw(ArgumentError(
        "compiled genome lost declared evaluator requirements"))
    warnings = sort!(unique(vcat(report.warnings, family_report.warnings)))
    return CompiledAttributeGenomeV18(assembly.assembly_id, assembly.graph_hash,
        assembly.family, assembly.mission_contract_id, copy(assembly.module_ids),
        genome, evaluator_id, projection_id, sort!(unique(limitations)), declared,
        warnings)
end

function _v18_evaluators(context::_AttributeGraphCompilerContextV18)
    return AbstractEvaluator[
        ComposableCrossFamilyScreenV1(context.outer),
        ProfileCoupledRFPScreenV1(context.outer),
        SelfOrganizedScreenV1(context.outer),
        MechanismExpansionScreenV1(context.outer),
        PulsedCompressionScreenV1(pulsed_compression_contract_v1(context.outer)),
        LaserICFScreenV1(context.icf),
    ]
end

function _v18_route_result(evaluator::AbstractEvaluator, genome::Genome)
    evaluator isa ComposableCrossFamilyScreenV1 &&
        return _composable_cross_family_result(evaluator, genome)
    evaluator isa ProfileCoupledRFPScreenV1 &&
        return _profile_coupled_rfp_result(evaluator, genome)
    evaluator isa SelfOrganizedScreenV1 &&
        return _self_organized_result(evaluator, genome)
    evaluator isa MechanismExpansionScreenV1 &&
        return _mechanism_expansion_result(evaluator, genome)
    evaluator isa PulsedCompressionScreenV1 &&
        return _pulsed_compression_result(evaluator, genome)
    evaluator isa LaserICFScreenV1 && return _laser_icf_result(evaluator, genome)
    throw(ArgumentError("unsupported v18 evaluator $(typeof(evaluator))"))
end

function _v18_float(value, default::Float64 = 0.0)
    value isa Real || return default
    return Float64(value)
end

function _v18_prescreen(compiled::CompiledAttributeGenomeV18,
        evaluators::Dict{String,AbstractEvaluator}, registry::EvaluatorRegistry)
    evaluator = evaluators[compiled.evaluator_id]
    applicable, reason = evaluator_applicability(evaluator, compiled.genome)
    if !applicable
        return AttributeGenomePrescreenV18(compiled, false, reason,
            Dict{String,Bool}(), false, 0.0, false,
            copy(compiled.declared_requirements), false, false, String[],
            canonical_hash(Dict("status" => "not_applicable", "reason" => reason,
                "input_hash" => compiled.genome.physics_hash)))
    end
    result = _v18_route_result(evaluator, compiled.genome)
    gates = Dict{String,Bool}(String(key) => value === true
        for (key, value) in result["gates"])
    coverage = coverage_report(registry, compiled.genome)
    by_requirement = Dict(item.requirement => item.support for item in coverage)
    missing = sort!(String[requirement for requirement in compiled.declared_requirements
        if get(by_requirement, requirement, :missing) == :missing])
    complete = isempty(missing)
    passed = result["all_five_gates_passed"] === true
    robustness = get(result, "robustness", Dict{String,Any}())
    pass_fraction = _v18_float(get(robustness, "pass_fraction", 0.0))
    positive = get(result, "positive_net_power_closure_passed",
        get(result, "positive_average_net_power_closure_passed", false)) === true
    graph_errors = String.(get(result, "topology_graph_errors", Any[]))
    eligible = applicable && passed && complete && isempty(graph_errors)
    return AttributeGenomePrescreenV18(compiled, true, reason, gates, passed,
        pass_fraction, positive, missing, complete, eligible, graph_errors,
        String(result["result_hash"]))
end

function _v18_queue_record(record::AttributeGenomePrescreenV18)
    return Dict{String,Any}(
        "assembly_id" => record.compiled.assembly_id,
        "graph_hash" => record.compiled.graph_hash,
        "design_id" => record.compiled.genome.design_id,
        "physics_hash" => record.compiled.genome.physics_hash,
        "family" => record.compiled.family,
        "evaluator_id" => record.compiled.evaluator_id,
        "missing_proxy_requirements" => copy(record.missing_proxy_requirements),
        "proxy_result_hash" => record.proxy_result_hash)
end

function run_attribute_graph_genome_pipeline_v18(
        grammar::AttributeGraphGrammarResultV17, seeds::Vector{Genome};
        catalog::Vector{TopologyModuleV17} = grammar.catalog)
    isempty(grammar.archive) && throw(ArgumentError("v18 requires a non-empty archive"))
    context = _v18_context(seeds)
    evaluators_vector = _v18_evaluators(context)
    evaluators = Dict(evaluator_spec(item).id => item for item in evaluators_vector)
    evaluator_registry = EvaluatorRegistry()
    for evaluator in evaluators_vector
        register!(evaluator_registry, evaluator)
    end
    records = AttributeGenomePrescreenV18[]
    for assembly in grammar.archive
        compiled = compile_attribute_graph_genome_v18(assembly, catalog, seeds;
            context = context)
        push!(records, _v18_prescreen(compiled, evaluators, evaluator_registry))
    end
    physics_hashes = getfield.(getfield.(getfield.(records, :compiled), :genome),
        :physics_hash)
    length(unique(physics_hashes)) == length(records) || throw(ArgumentError(
        "v18 compiled duplicate Genome physics hashes"))
    graph_hashes = getfield.(getfield.(records, :compiled), :graph_hash)
    length(unique(graph_hashes)) == length(records) || throw(ArgumentError(
        "v18 input archive contains duplicate graph hashes"))

    family_counts = Dict{String,Int}()
    route_counts = Dict{String,Int}()
    pass_family_counts = Dict{String,Int}()
    missing_counts = Dict{String,Int}()
    for record in records
        family = record.compiled.family
        family_counts[family] = get(family_counts, family, 0) + 1
        route = record.compiled.evaluator_id
        route_counts[route] = get(route_counts, route, 0) + 1
        record.proxy_five_gate_passed &&
            (pass_family_counts[family] = get(pass_family_counts, family, 0) + 1)
        for requirement in record.missing_proxy_requirements
            missing_counts[requirement] = get(missing_counts, requirement, 0) + 1
        end
    end
    evidence_candidates = filter(record -> record.proxy_five_gate_passed &&
        !record.proxy_coverage_complete, records)
    sort!(evidence_candidates; by = record ->
        (length(record.missing_proxy_requirements), -record.robustness_pass_fraction,
            record.compiled.graph_hash))
    evidence_queue = [_v18_queue_record(record)
        for record in first(evidence_candidates, min(25, length(evidence_candidates)))]
    medium_candidates = filter(record ->
        record.medium_fidelity_candidate_eligible, records)
    sort!(medium_candidates; by = record ->
        (-record.robustness_pass_fraction, record.compiled.graph_hash))
    medium_queue = _v18_queue_record.(medium_candidates)
    archive_hash = canonical_hash(topology_assembly_to_dict_v17.(grammar.archive))
    return AttributeGraphGenomePipelineResultV18(archive_hash,
        topology_module_catalog_hash_v17(catalog), records, family_counts,
        route_counts, pass_family_counts, missing_counts, evidence_queue,
        medium_queue, _V18_CLAIM_BOUNDARY)
end

function compiled_attribute_genome_to_dict_v18(item::CompiledAttributeGenomeV18;
        include_genome::Bool = false)
    result = Dict{String,Any}(
        "assembly_id" => item.assembly_id, "graph_hash" => item.graph_hash,
        "family" => item.family, "mission_contract_id" => item.mission_contract_id,
        "module_ids" => copy(item.module_ids),
        "genome_design_id" => item.genome.design_id,
        "genome_content_hash" => item.genome.content_hash,
        "genome_physics_hash" => item.genome.physics_hash,
        "evaluator_id" => item.evaluator_id, "projection_id" => item.projection_id,
        "structural_identity_preserved" => true,
        "module_geometry_solved" => false,
        "projection_limitations" => copy(item.projection_limitations),
        "declared_requirements" => copy(item.declared_requirements),
        "validation_warnings" => copy(item.validation_warnings),
        "claim_level" => "C0_compiled_plus_fidelity0_projection_only")
    include_genome && (result["genome"] = item.genome.normalized)
    return result
end

function attribute_genome_prescreen_to_dict_v18(record::AttributeGenomePrescreenV18)
    return Dict{String,Any}(
        "compilation" => compiled_attribute_genome_to_dict_v18(record.compiled),
        "proxy_applicable" => record.proxy_applicable,
        "applicability_reason" => record.applicability_reason,
        "gates" => record.gates,
        "proxy_five_gate_passed" => record.proxy_five_gate_passed,
        "robustness_pass_fraction" => record.robustness_pass_fraction,
        "positive_net_power_closure" => record.positive_net_power_closure,
        "missing_proxy_requirements" => copy(record.missing_proxy_requirements),
        "proxy_coverage_complete" => record.proxy_coverage_complete,
        "medium_fidelity_candidate_eligible" =>
            record.medium_fidelity_candidate_eligible,
        "topology_graph_errors" => copy(record.topology_graph_errors),
        "proxy_result_hash" => record.proxy_result_hash)
end

function attribute_graph_genome_pipeline_to_dict_v18(
        result::AttributeGraphGenomePipelineResultV18)
    records = result.records
    compiled_count = length(records)
    applicable_count = count(record -> record.proxy_applicable, records)
    five_gate_count = count(record -> record.proxy_five_gate_passed, records)
    coverage_count = count(record -> record.proxy_coverage_complete, records)
    eligible_count = count(record -> record.medium_fidelity_candidate_eligible, records)
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "stage" => "attribute_graph_genome_pipeline_v18",
        "algorithm" =>
            "deterministic_v17_graph_to_typed_genome_and_family_proxy_routing_v1",
        "input_archive" => Dict(
            "archive_hash" => result.input_archive_hash,
            "catalog_hash" => result.catalog_hash,
            "assembly_count" => compiled_count),
        "compilation_audit" => Dict(
            "compiled_genome_count" => compiled_count,
            "unique_genome_physics_hash_count" => length(unique(
                record.compiled.genome.physics_hash for record in records)),
            "family_counts" => result.compiled_family_counts,
            "semantic_validation_pass_count" => compiled_count,
            "mission_contract_match_count" => compiled_count,
            "source_traceability_pass_count" => compiled_count,
            "module_geometry_solved_count" => 0),
        "evaluator_routing" => Dict(
            "route_counts" => result.evaluator_route_counts,
            "applicable_count" => applicable_count,
            "not_applicable_count" => compiled_count - applicable_count,
            "all_eleven_families_have_executable_route" =>
                length(result.compiled_family_counts) == 11 && applicable_count == compiled_count),
        "prescreen_summary" => Dict(
            "proxy_five_gate_pass_count" => five_gate_count,
            "proxy_five_gate_family_counts" => result.proxy_five_gate_family_counts,
            "proxy_requirement_coverage_complete_count" => coverage_count,
            "positive_net_power_closure_count" => count(record ->
                record.positive_net_power_closure, records),
            "medium_fidelity_candidate_eligible_count" => eligible_count,
            "topology_graph_error_count" => count(record ->
                !isempty(record.topology_graph_errors), records)),
        "missing_requirement_audit" => Dict(
            "unique_missing_requirement_count" => length(result.missing_requirement_counts),
            "missing_requirement_counts" => result.missing_requirement_counts),
        "records" => attribute_genome_prescreen_to_dict_v18.(records),
        "evaluation_and_promotion_policy" => Dict(
            "evidence_gap_queue" => result.evidence_gap_queue,
            "evidence_gap_queue_count" => length(result.evidence_gap_queue),
            "medium_fidelity_candidate_queue" => result.medium_fidelity_candidate_queue,
            "medium_fidelity_candidate_queue_count" =>
                length(result.medium_fidelity_candidate_queue),
            "medium_fidelity_authorized_count" => 0,
            "rule" => "Only an applicable five-gate proxy pass with zero missing declared proxy requirements may enter the medium-fidelity candidate queue; execution remains separately unauthorized."),
        "claim_boundary" => result.claim_boundary)
end
