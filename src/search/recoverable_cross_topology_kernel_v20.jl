const _V20_HALTON_PRIMES = (
    2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37,
    41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89,
)

const _V20_CLAIM_BOUNDARY =
    "V20 runs real registered fidelity-0 family projections across the v17 topology archive " *
    "with paired deterministic Halton samples and recoverable v19 execution. It remains a " *
    "proxy rejection search: nearest-route module projections, missing evaluators, and all " *
    "v18 claim limits remain binding. A positive ledger or five-gate proxy result is not C1, " *
    "medium-fidelity authorization, novelty, superiority, or reactor evidence."

struct RecoverableCrossTopologyContextV20
    assemblies::Vector{TopologyAssemblyV17}
    catalog::Vector{TopologyModuleV17}
    modules::Dict{String,TopologyModuleV17}
    compiler_context::_AttributeGraphCompilerContextV18
    evaluators::Dict{String,AbstractEvaluator}
    evaluator_registry::EvaluatorRegistry
    archive_hash::String
    catalog_hash::String
end

struct CrossTopologyCandidateV20
    candidate_index::Int
    assembly_index::Int
    sample_ordinal::Int
    prescreen::AttributeGenomePrescreenV18
end

struct RecoverableShardLeaseV20
    shard_id::Int
    input_hash::String
    worker_id::String
    lease_generation::Int
    issued_at_unix::Float64
    expires_at_unix::Float64
    claim_directory::String
end

function build_recoverable_cross_topology_context_v20(
        grammar::AttributeGraphGrammarResultV17, seeds::Vector{Genome})
    isempty(grammar.archive) && throw(ArgumentError("v20 requires a non-empty archive"))
    context = _v18_context(seeds)
    evaluator_vector = _v18_evaluators(context)
    evaluators = Dict(evaluator_spec(item).id => item for item in evaluator_vector)
    registry = EvaluatorRegistry()
    for evaluator in evaluator_vector
        register!(registry, evaluator)
    end
    catalog = copy(grammar.catalog)
    modules = Dict(item.id => item for item in catalog)
    assemblies = copy(grammar.archive)
    archive_hash = canonical_hash(topology_assembly_to_dict_v17.(assemblies))
    return RecoverableCrossTopologyContextV20(assemblies, catalog, modules,
        context, evaluators, registry, archive_hash,
        topology_module_catalog_hash_v17(catalog))
end

function _v20_unit_vector(sample_ordinal::Int, count::Int; skip::Int = 4096)
    sample_ordinal > 0 || throw(ArgumentError("sample_ordinal must be positive"))
    1 <= count <= length(_V20_HALTON_PRIMES) || throw(ArgumentError(
        "v20 Halton dimension must be between 1 and $(length(_V20_HALTON_PRIMES))"))
    index = sample_ordinal + skip
    return Float64[0.02 + 0.96 * _ctv4_halton(index, _V20_HALTON_PRIMES[axis])
        for axis in 1:count]
end

function _v20_common_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17, values_u::Vector{Float64})
    key = _v18_v9_key(assembly)
    haskey(context.v9_bases, key) || throw(ArgumentError(
        "v20 cannot locate v9 structural projection $key"))
    spec = only(filter(item -> _ccv9_key(item) == key, _ccv9_topology_specs()))
    values = _ccv9_ranges(spec, values_u[1:12])
    genome = _ccv9_instantiate(context.v9_bases[key], values, context.outer)
    limitations = String[
        "v9 family projection retains high-level topology but does not realize every v17 module geometry",
        "v20 varies registered proxy parameters with paired Halton coordinates; module geometry remains unsolved",
    ]
    assembly.module_ids[1] == "stellarator_qh" && push!(limitations,
        "quasi-helical core is evaluated through the nearest registered stellarator proxy branch")
    requested = _v18_target_count(assembly)
    mapped = parse(Int, split(last(split(key, "|")), "="; limit = 2)[2])
    requested != mapped && push!(limitations,
        "declared target count $requested is projected to registered target count $mapped")
    return genome, "composable_cross_family_screen_v1", key, limitations
end

function _v20_rfp_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17, values_u::Vector{Float64})
    stability = assembly.module_ids[3]
    mechanism = stability == "rfp_boundary_control" ?
        "qsh_ppcd_boundary_mode_control" : stability == "rfp_ppcd_profile" ?
        "qsh_pulsed_poloidal_current_drive" : "self_organized_qsh"
    count = _v18_nearest_target_count(_v18_target_count(assembly))
    spec = ProfileCoupledRFPTopologySpecV8(mechanism, count)
    base = _pcrfp_structural_base_v8(context.tokamak_parent, spec)
    values = _pcrfp_ranges_v8(spec, values_u[1:24])
    genome = _pcrfp_instantiate_v8(base, values, context.outer)
    return genome, "profile_coupled_rfp_screen_v1", _pcrfp_key_v8(spec), String[
        "profile-coupled cylindrical RFP proxy does not realize the selected boundary hardware in detail",
        "v20 paired Halton sample changes registered profile and engineering proxy genes only",
    ]
end

function _v20_dipole_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17, values_u::Vector{Float64})
    count = _v18_nearest_target_count(_v18_target_count(assembly; default = 2))
    spec = SelfOrganizedTopologySpecV7("levitated_dipole",
        "levitated_inward_pinch", count)
    base = _sov7_structural_base(context.tokamak_parent, spec)
    values = _sov7_ranges(spec, values_u[1:24])
    genome = _sov7_instantiate(base, values, context.outer)
    return genome, "self_organized_screen_v1", _sov7_key(spec), String[
        "dipole proxy uses a levitated reference even when the v17 field module declares a supported coil",
        "internal-coil heat removal and support are unresolved module-specific requirements",
        "v20 paired Halton sample changes registered proxy genes only",
    ]
end

function _v20_zpinch_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17, values_u::Vector{Float64})
    mechanism = assembly.module_ids[3] == "zpinch_active_profile" ?
        "sheared_flow_repetitive_z_pinch" : "sheared_flow_single_pulse_z_pinch"
    spec = MechanismExpansionTopologySpecV10("sheared_flow_z_pinch", mechanism,
        "two_linear_end_targets", 2)
    base = _mev10_build_z_pinch(context.tokamak_parent, spec)
    values = _mev10_ranges(spec, values_u[1:24])
    genome = _mev10_instantiate(base, spec, values, context.outer)
    return genome, "mechanism_expansion_screen_v1", _mev10_key(spec), String[
        "steady net-electric v17 mission is tested with a pulsed/sheared-flow rejection formulation",
        "electrode lifetime and repetitive power coupling remain unresolved",
        "v20 paired Halton sample changes registered proxy genes only",
    ]
end

function _v20_mtf_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17, values_u::Vector{Float64})
    field = assembly.module_ids[2]
    spec = field == "mtf_pjmif" ?
        PulsedTopologySpecV6("frc", "spherical_plasma_liner", "spherical") :
        field == "mtf_maglif" ?
        PulsedTopologySpecV6("diffuse_pinch", "solid_conducting_liner", "cylindrical") :
        PulsedTopologySpecV6("frc", "solid_conducting_liner", "spherical")
    values = _pulsed_ranges_v6(spec, values_u[1:14])
    genome = build_pulsed_compression_genome_v6(context.tokamak_parent, spec,
        values, context.outer)
    return genome, "pulsed_compression_screen_v1", _pulsed_key_v6(spec), String[
        "v6 non-igniting compression proxy does not realize chamber-protection or mix geometry",
        "v20 paired Halton sample changes registered compression proxy genes only",
    ]
end

function _v20_icf_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17, values_u::Vector{Float64})
    field, exhaust = assembly.module_ids[2], assembly.module_ids[4]
    path = field == "icf_indirect_drive" ? "laser_indirect_drive" :
        field == "icf_fast_ignition" ? "laser_fast_ignition" : "laser_direct_drive"
    protection = exhaust == "icf_liquid_protected" ? "liquid_protected" :
        exhaust == "icf_dry_wall" ? "dry_wall" : "replaceable_modular"
    spec = LaserICFTopologySpecV15(path, protection)
    values = _licfv15_ranges(spec, values_u[1:18])
    genome = _licfv15_build_genome(context.tokamak_parent, spec, values, context.icf)
    limitations = String[
        "laser-ICF pulse ledger does not solve radiation hydrodynamics, mix, LPI, or lifetime",
        "v20 paired Halton sample changes registered pulse-ledger genes only",
    ]
    exhaust == "icf_gas_protected" && push!(limitations,
        "gas-protected chamber is projected to the nearest replaceable-modular v15 ledger")
    return genome, "laser_icf_screen_v1", _licfv15_key(spec), limitations
end

function _v20_projection(context::_AttributeGraphCompilerContextV18,
        assembly::TopologyAssemblyV17, values_u::Vector{Float64})
    assembly.family in _V18_COMMON_FAMILIES &&
        return _v20_common_projection(context, assembly, values_u)
    assembly.family == "reversed_field_pinch" &&
        return _v20_rfp_projection(context, assembly, values_u)
    assembly.family == "levitated_dipole" &&
        return _v20_dipole_projection(context, assembly, values_u)
    assembly.family == "sheared_flow_z_pinch" &&
        return _v20_zpinch_projection(context, assembly, values_u)
    assembly.family == "magnetized_target_fusion" &&
        return _v20_mtf_projection(context, assembly, values_u)
    assembly.family == "inertial_confinement_fusion" &&
        return _v20_icf_projection(context, assembly, values_u)
    throw(ArgumentError("v20 has no proxy projection for $(assembly.family)"))
end

function _v20_sample_annotation(genome::Genome, assembly::TopologyAssemblyV17,
        sample_ordinal::Int)
    raw = deepcopy(genome.normalized)
    provenance = raw["provenance"]
    _v18_push_unique!(provenance["notes"], [
        "recoverable_cross_topology_kernel_v20",
        "paired_halton_sample_ordinal:$sample_ordinal",
        "sample ordinal is provenance only; physical identity comes from sampled genes",
    ])
    raw["label"] = "V20 sampled attribute graph $(assembly.structural_descriptor)"
    raw["design_id"] = "pending_cross_topology_v20"
    provisional = parse_genome(raw)
    raw["design_id"] = "v20_$(assembly.graph_hash[1:16])_s$(lpad(sample_ordinal, 6, '0'))_" *
        provisional.physics_hash[1:12]
    return parse_genome(raw)
end

function _v20_declared_requirements(context::RecoverableCrossTopologyContextV20,
        assembly::TopologyAssemblyV17)
    return sort!(unique(vcat(getfield.([context.modules[id]
        for id in assembly.module_ids], :required_evaluators)...)))
end

function evaluate_cross_topology_candidate_v20(
        context::RecoverableCrossTopologyContextV20, candidate_index::Int;
        halton_skip::Int = 4096)
    candidate_index > 0 || throw(ArgumentError("candidate_index must be positive"))
    topology_count = length(context.assemblies)
    assembly_index = mod1(candidate_index, topology_count)
    sample_ordinal = cld(candidate_index, topology_count)
    assembly = context.assemblies[assembly_index]
    values_u = _v20_unit_vector(sample_ordinal, length(_V20_HALTON_PRIMES);
        skip = halton_skip)
    proxy, evaluator_id, projection_id, limitations = _v20_projection(
        context.compiler_context, assembly, values_u)
    annotated = _v18_annotate_proxy(proxy, assembly, context.modules)
    genome = _v20_sample_annotation(annotated, assembly, sample_ordinal)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError("sampled v20 genome invalid: " *
        join(report.errors, "; ")))
    family_report = assembly.family == "inertial_confinement_fusion" ?
        validate_family(laser_icf_family_registry_v15(), genome) :
        validate_family(default_family_registry(), genome)
    family_report.valid || throw(ArgumentError("sampled v20 family invalid: " *
        join(family_report.errors, "; ")))
    mission_contract_for(default_mission_contract_registry(), genome).id ==
        assembly.mission_contract_id || throw(ArgumentError(
        "sampled v20 mission contract drifted"))
    declared = _v20_declared_requirements(context, assembly)
    issubset(Set(declared), Set(_requirements(genome))) || throw(ArgumentError(
        "sampled v20 genome lost declared evaluator requirements"))
    warnings = sort!(unique(vcat(report.warnings, family_report.warnings)))
    compiled = CompiledAttributeGenomeV18(assembly.assembly_id,
        assembly.graph_hash, assembly.family, assembly.mission_contract_id,
        copy(assembly.module_ids), genome, evaluator_id, projection_id,
        sort!(unique(limitations)), declared, warnings)
    prescreen = _v18_prescreen(compiled, context.evaluators,
        context.evaluator_registry)
    return CrossTopologyCandidateV20(candidate_index, assembly_index,
        sample_ordinal, prescreen)
end

function cross_topology_candidate_to_dict_v20(candidate::CrossTopologyCandidateV20)
    record = candidate.prescreen
    compiled = record.compiled
    gate_pass_count = count(values(record.gates))
    return Dict{String,Any}(
        "candidate_index" => candidate.candidate_index,
        "assembly_index" => candidate.assembly_index,
        "sample_ordinal" => candidate.sample_ordinal,
        "assembly_id" => compiled.assembly_id,
        "graph_hash" => compiled.graph_hash,
        "family" => compiled.family,
        "mission_contract_id" => compiled.mission_contract_id,
        "module_ids" => copy(compiled.module_ids),
        "design_id" => compiled.genome.design_id,
        "physics_hash" => compiled.genome.physics_hash,
        "evaluator_id" => compiled.evaluator_id,
        "projection_id" => compiled.projection_id,
        "proxy_applicable" => record.proxy_applicable,
        "gates" => copy(record.gates),
        "gate_pass_count" => gate_pass_count,
        "proxy_five_gate_passed" => record.proxy_five_gate_passed,
        "robustness_pass_fraction" => record.robustness_pass_fraction,
        "positive_net_power_closure" => record.positive_net_power_closure,
        "missing_proxy_requirements" => copy(record.missing_proxy_requirements),
        "missing_proxy_requirement_count" => length(record.missing_proxy_requirements),
        "proxy_coverage_complete" => record.proxy_coverage_complete,
        "medium_fidelity_candidate_eligible" =>
            record.medium_fidelity_candidate_eligible,
        "topology_graph_errors" => copy(record.topology_graph_errors),
        "proxy_result_hash" => record.proxy_result_hash,
        "claim_level" => "C0_plus_sampled_fidelity0_projection_only",
    )
end

function recoverable_cross_topology_kernel_v20(
        context::RecoverableCrossTopologyContextV20)
    return function(candidate_index::Int, config::Dict{String,Any})
        Int(get(config, "topology_archive_size", length(context.assemblies))) ==
            length(context.assemblies) || throw(ArgumentError(
            "v20 kernel config topology count mismatch"))
        String(get(config, "topology_archive_hash", context.archive_hash)) ==
            context.archive_hash || throw(ArgumentError(
            "v20 kernel config archive hash mismatch"))
        halton_skip = Int(get(config, "halton_skip", 4096))
        candidate = evaluate_cross_topology_candidate_v20(context,
            candidate_index; halton_skip = halton_skip)
        record = cross_topology_candidate_to_dict_v20(candidate)
        retain_policy = String(get(config, "retain_policy", "all"))
        retain = retain_policy == "all" ? true :
            retain_policy == "frontier_only" ?
            (record["proxy_five_gate_passed"] ||
             record["positive_net_power_closure"] ||
             record["medium_fidelity_candidate_eligible"]) :
            throw(ArgumentError("unsupported v20 retain policy $retain_policy"))
        return RecoverableKernelOutcomeV19(record, retain)
    end
end

function recoverable_cross_topology_spec_v20(
        context::RecoverableCrossTopologyContextV20,
        total_candidates::Integer, shard_size::Integer;
        run_id::AbstractString = "recoverable_cross_topology_search_v20",
        max_retries::Integer = 2, retain_policy::AbstractString = "all",
        halton_skip::Integer = 4096)
    retain_policy in ("all", "frontier_only") || throw(ArgumentError(
        "v20 retain_policy must be all or frontier_only"))
    max_retained = retain_policy == "all" ? Int(shard_size) : 64
    return RecoverableRunSpecV19(run_id,
        "recoverable_cross_topology_fidelity0_kernel",
        "20.0.0", total_candidates, shard_size;
        max_retries = max_retries,
        max_retained_per_shard = max_retained,
        kernel_config = Dict{String,Any}(
            "topology_archive_size" => length(context.assemblies),
            "topology_archive_hash" => context.archive_hash,
            "topology_catalog_hash" => context.catalog_hash,
            "halton_sequence" => "paired_global_ordinal_halton_24d_v1",
            "halton_skip" => Int(halton_skip),
            "retain_policy" => String(retain_policy),
            "claim_boundary" => _V20_CLAIM_BOUNDARY,
        ))
end

function _v20_candidate_selection_key(record::AbstractDict)
    return (
        record["medium_fidelity_candidate_eligible"] === true ? 0 : 1,
        record["proxy_five_gate_passed"] === true ? 0 : 1,
        record["positive_net_power_closure"] === true ? 0 : 1,
        -Int(record["gate_pass_count"]),
        Int(record["missing_proxy_requirement_count"]),
        -Float64(record["robustness_pass_fraction"]),
        String(record["physics_hash"]),
    )
end

function cross_topology_failure_aware_archive_v20(records::AbstractVector)
    cells = Dict{String,Dict{String,Any}}()
    for raw in records
        record = Dict{String,Any}(String(key) => _plain_json(value)
            for (key, value) in raw)
        graph_hash = String(record["graph_hash"])
        incumbent = get(cells, graph_hash, nothing)
        if incumbent === nothing ||
                _v20_candidate_selection_key(record) <
                _v20_candidate_selection_key(incumbent)
            cells[graph_hash] = record
        end
    end
    archive = sort!(collect(values(cells)); by = record -> String(record["graph_hash"]))
    family_counts = Dict{String,Int}()
    for record in archive
        family = String(record["family"])
        family_counts[family] = get(family_counts, family, 0) + 1
    end
    return Dict{String,Any}(
        "archive_version" => "cross_topology_failure_aware_archive_v20",
        "descriptor" => "v17_graph_hash",
        "selection_order" => [
            "medium_fidelity_candidate_eligible",
            "proxy_five_gate_passed",
            "positive_net_power_closure",
            "gate_pass_count",
            "missing_proxy_requirement_count",
            "robustness_pass_fraction",
            "physics_hash",
        ],
        "input_record_count" => length(records),
        "archive_cell_count" => length(archive),
        "family_counts" => family_counts,
        "five_gate_count" => count(record ->
            record["proxy_five_gate_passed"] === true, archive),
        "positive_net_count" => count(record ->
            record["positive_net_power_closure"] === true, archive),
        "medium_fidelity_candidate_count" => count(record ->
            record["medium_fidelity_candidate_eligible"] === true, archive),
        "records" => archive,
        "claim_boundary" => _V20_CLAIM_BOUNDARY,
    )
end

function collect_retained_records_v20(spec::RecoverableRunSpecV19,
        cache_directory::AbstractString)
    records = Any[]
    for shard in deterministic_shards_v19(spec)
        result_hash = _v19_load_commit(abspath(cache_directory), shard)
        result_hash === nothing && throw(ArgumentError(
            "v20 cannot collect incomplete shard $(shard.shard_id)"))
        object = _v19_read_json(_v19_object_path(abspath(cache_directory), result_hash))
        for envelope in object["retained_records"]
            push!(records, _plain_json(envelope["record"]))
        end
    end
    sort!(records; by = record -> Int(record["candidate_index"]))
    return records
end

function _v20_worker_slug(worker_id::String)
    slug = replace(worker_id, r"[^A-Za-z0-9_.-]" => "_")
    isempty(slug) && throw(ArgumentError("worker_id must contain a safe character"))
    return slug
end

function _v20_claim_root(cache_directory::AbstractString)
    return joinpath(abspath(cache_directory), "claims")
end

function _v20_claim_directory(cache_directory::AbstractString, input_hash::String)
    return joinpath(_v20_claim_root(cache_directory), input_hash[1:2], input_hash)
end

function _v20_lease_to_dict(lease::RecoverableShardLeaseV20; status::String = "claimed")
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "shard_id" => lease.shard_id,
        "input_hash" => lease.input_hash,
        "worker_id" => lease.worker_id,
        "lease_generation" => lease.lease_generation,
        "issued_at_unix" => lease.issued_at_unix,
        "expires_at_unix" => lease.expires_at_unix,
        "status" => status,
    )
end

function _v20_create_claim(cache_directory::String,
        shard::RecoverableShardSpecV19, worker_id::String,
        lease_generation::Int, lease_seconds::Float64)
    claim_directory = _v20_claim_directory(cache_directory, shard.input_hash)
    mkpath(dirname(claim_directory))
    try
        mkdir(claim_directory)
    catch exception
        (exception isa Base.IOError || exception isa SystemError) || rethrow()
        return nothing
    end
    issued = time()
    lease = RecoverableShardLeaseV20(shard.shard_id, shard.input_hash,
        worker_id, lease_generation, issued, issued + lease_seconds,
        claim_directory)
    _v19_atomic_write_json(joinpath(claim_directory, "lease.json"),
        _v20_lease_to_dict(lease))
    return lease
end

function _v20_try_reclaim(cache_directory::String,
        shard::RecoverableShardSpecV19, worker_id::String,
        lease_seconds::Float64)
    claim_directory = _v20_claim_directory(cache_directory, shard.input_hash)
    lease_path = joinpath(claim_directory, "lease.json")
    isfile(lease_path) || return nothing
    existing = _v19_read_json(lease_path)
    Float64(existing["expires_at_unix"]) < time() || return nothing
    generation = Int(existing["lease_generation"]) + 1
    stale_root = joinpath(_v20_claim_root(cache_directory), "stale")
    mkpath(stale_root)
    stale_name = "$(shard.input_hash).g$(generation - 1)." *
        "$(_v20_worker_slug(worker_id)).$(time_ns())"
    stale_path = joinpath(stale_root, stale_name)
    error_code = ccall(:jl_fs_rename, Int32, (Cstring, Cstring),
        claim_directory, stale_path)
    error_code < 0 && return nothing
    return _v20_create_claim(cache_directory, shard, worker_id,
        generation, lease_seconds)
end

function claim_next_recoverable_shard_v20(spec::RecoverableRunSpecV19;
        cache_directory::AbstractString, worker_id::AbstractString,
        lease_seconds::Real = 900.0,
        shard_ids::Union{Nothing,AbstractVector{<:Integer}} = nothing)
    lease_seconds >= 0 || throw(ArgumentError("lease_seconds must be non-negative"))
    cache_path = abspath(cache_directory)
    mkpath(cache_path)
    worker = _v20_worker_slug(String(worker_id))
    shards = deterministic_shards_v19(spec)
    selected = shard_ids === nothing ? collect(1:length(shards)) :
        sort!(unique(Int.(shard_ids)))
    all(id -> 1 <= id <= length(shards), selected) || throw(ArgumentError(
        "v20 claim shard_ids contains an out-of-range shard"))
    for shard_id in selected
        shard = shards[shard_id]
        _v19_load_commit(cache_path, shard) === nothing || continue
        lease = _v20_create_claim(cache_path, shard, worker, 1,
            Float64(lease_seconds))
        lease === nothing || return lease
        lease = _v20_try_reclaim(cache_path, shard, worker,
            Float64(lease_seconds))
        lease === nothing || return lease
    end
    return nothing
end

function run_claimed_recoverable_worker_v20(spec::RecoverableRunSpecV19,
        kernel::Function; run_directory::AbstractString,
        cache_directory::AbstractString, worker_id::AbstractString,
        lease_seconds::Real = 900.0, maximum_claims::Integer = typemax(Int),
        failure_injector::Function = (shard_id, attempt) -> false)
    maximum_claims >= 0 || throw(ArgumentError("maximum_claims must be non-negative"))
    completed = 0
    worker = _v20_worker_slug(String(worker_id))
    leases = RecoverableShardLeaseV20[]
    while completed < maximum_claims
        lease = claim_next_recoverable_shard_v20(spec;
            cache_directory = cache_directory, worker_id = worker,
            lease_seconds = lease_seconds)
        lease === nothing && break
        push!(leases, lease)
        result = run_recoverable_search_v19(spec, kernel;
            run_directory = run_directory, cache_directory = cache_directory,
            shard_ids = [lease.shard_id], failure_injector = failure_injector)
        result.complete || result.completed_shards >= completed + 1 ||
            throw(ArgumentError("v20 claimed worker failed to commit shard"))
        completed += 1
        if isdir(lease.claim_directory)
            _v19_atomic_write_json(joinpath(lease.claim_directory, "lease.json"),
                _v20_lease_to_dict(lease; status = "committed"))
        end
    end
    return Dict{String,Any}(
        "worker_id" => worker,
        "completed_claims" => completed,
        "claimed_shard_ids" => getfield.(leases, :shard_id),
        "lease_generations" => getfield.(leases, :lease_generation),
        "claim_boundary" => _V20_CLAIM_BOUNDARY,
    )
end
