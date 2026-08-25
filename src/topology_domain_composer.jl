const _TOPOLOGY_DOMAIN_CLASSES_V1 = Set((:closed, :open, :mixed))

struct TopologyDomainSupportV1
    support_id::String
    design_id::String
    genome_physics_hash::String
    covered_domain_ids::Vector{String}
    topology_class::Symbol
    status::Symbol
    c1_support_authorized::Bool
    evidence_hashes::Vector{String}
    claim_ceiling::String
    support_hash::String
end

struct TopologyDomainCompositionResultV1
    schema_version::String
    design_id::String
    genome_physics_hash::String
    topology_module_id::Union{Nothing,String}
    topology_implementation_id::String
    required_domain_ids::Vector{String}
    covered_domain_ids::Vector{String}
    support_hashes::Vector{String}
    represented_topology_classes::Vector{Symbol}
    checks::Dict{String,Bool}
    status::Symbol
    c1_evidence_authorized::Bool
    evidence_tasks::Vector{String}
    composition_hash::String
end

function _topology_domain_support_v1(support_id, design_id, physics_hash,
        covered_domains, topology_class, status, authorized, evidence_hashes,
        claim_ceiling)
    topology_class in _TOPOLOGY_DOMAIN_CLASSES_V1 || throw(ArgumentError(
        "unknown topology-domain class: $topology_class"))
    isempty(support_id) && throw(ArgumentError("topology support id cannot be empty"))
    isempty(covered_domains) && throw(ArgumentError(
        "topology support must cover at least one physical domain"))
    length(unique(covered_domains)) == length(covered_domains) || throw(ArgumentError(
        "topology support domain ids must be unique"))
    isempty(evidence_hashes) && throw(ArgumentError(
        "topology support needs at least one evidence hash"))
    payload = Dict{String,Any}(
        "support_id" => String(support_id),
        "design_id" => String(design_id),
        "genome_physics_hash" => String(physics_hash),
        "covered_domain_ids" => sort(String.(covered_domains)),
        "topology_class" => String(topology_class),
        "status" => String(status),
        "c1_support_authorized" => Bool(authorized),
        "evidence_hashes" => sort(String.(evidence_hashes)),
        "claim_ceiling" => String(claim_ceiling))
    return TopologyDomainSupportV1(String(support_id), String(design_id),
        String(physics_hash), payload["covered_domain_ids"], topology_class,
        status, Bool(authorized), payload["evidence_hashes"],
        String(claim_ceiling), canonical_hash(payload))
end

function topology_domain_support_v1(support_id::AbstractString,
        result::ClosedFluxSurfaceConvergenceResultV1)
    return _topology_domain_support_v1(support_id, result.design_id,
        result.genome_physics_hash, result.covered_domain_ids, :closed,
        result.status, result.c1_support_authorized,
        [result.coarse_product_hash, result.fine_product_hash,
            result.convergence_hash],
        "C1_support_closed_scalar_flux_surfaces_only")
end

function topology_domain_support_v1(support_id::AbstractString,
        result::FieldTopologyConvergenceResultV1)
    topology_class = result.topology_class == :open_dominated ? :open :
        result.topology_class == :closed_dominated ? :closed :
        result.topology_class == :mixed ? :mixed : throw(ArgumentError(
            "unresolved field topology cannot become a domain support"))
    return _topology_domain_support_v1(support_id, result.design_id,
        result.genome_physics_hash, result.covered_domain_ids, topology_class,
        result.status, result.c1_evidence_authorized,
        [result.coarse_product_hash, result.fine_product_hash,
            result.convergence_hash],
        "C1_support_field_line_topology_domain_only")
end

function topology_domain_support_to_dict_v1(item::TopologyDomainSupportV1)
    return Dict{String,Any}(
        "support_id" => item.support_id,
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "covered_domain_ids" => item.covered_domain_ids,
        "topology_class" => String(item.topology_class),
        "status" => String(item.status),
        "c1_support_authorized" => item.c1_support_authorized,
        "evidence_hashes" => item.evidence_hashes,
        "claim_ceiling" => item.claim_ceiling,
        "support_hash" => item.support_hash,
        "promotion_authorized" => false)
end

function _topology_domain_support_integrity_v1(item::TopologyDomainSupportV1)
    all(hash -> length(hash) == 64 && all(character ->
        character in "0123456789abcdef", lowercase(hash)), item.evidence_hashes) ||
        return false
    payload = Dict{String,Any}(
        "support_id" => item.support_id,
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "covered_domain_ids" => item.covered_domain_ids,
        "topology_class" => String(item.topology_class),
        "status" => String(item.status),
        "c1_support_authorized" => item.c1_support_authorized,
        "evidence_hashes" => item.evidence_hashes,
        "claim_ceiling" => item.claim_ceiling)
    return canonical_hash(payload) == item.support_hash
end

function _declared_topology_classes_represented_v1(genome::Genome,
        represented::Set{Symbol})
    declared = genome.topology.field_line_class
    declared == "mixed" && return :closed in represented && :open in represented
    startswith(declared, "closed_toroidal") && return :closed in represented
    occursin("open", declared) && return :open in represented
    declared == "compact_toroid" && return :closed in represented
    return false
end

"""Compose non-compensating domain evidence for one executable topology module."""
function compose_topology_domain_evidence_v1(executable::ExecutableGenomeV1,
        program::CompiledExecutablePhysicsProgramV1,
        supports::Vector{TopologyDomainSupportV1},
        topology_implementation_id::AbstractString)
    implementation_id = String(topology_implementation_id)
    ready_module = _ready_topology_module_v1(executable, program, implementation_id)
    required_domains = ready_module === nothing ? String[] :
        sort(copy(ready_module.domain_ids))
    covered = isempty(supports) ? String[] : sort!(unique(vcat(
        [support.covered_domain_ids for support in supports]...)))
    support_domain_occurrences = Dict{String,Int}()
    for support in supports, domain_id in support.covered_domain_ids
        support_domain_occurrences[domain_id] =
            get(support_domain_occurrences, domain_id, 0) + 1
    end
    represented = Set(support.topology_class for support in supports)
    checks = Dict{String,Bool}(
        "nonempty_support_set" => !isempty(supports),
        "topology_module_ready" => ready_module !== nothing,
        "all_supports_same_design" => all(support -> support.design_id ==
            executable.base_genome.design_id, supports),
        "all_supports_same_genome_physics_hash" => all(support ->
            support.genome_physics_hash == executable.base_genome.physics_hash,
            supports),
        "all_supports_pass" => all(support -> support.status == :pass, supports),
        "all_supports_candidate_authorized" => all(support ->
            support.c1_support_authorized, supports),
        "all_support_records_integrity_verified" => all(
            _topology_domain_support_integrity_v1, supports),
        "support_domains_do_not_overlap" => all(==(1),
            values(support_domain_occurrences)),
        "domain_union_exactly_matches_topology_module" => ready_module !== nothing &&
            covered == required_domains,
        "declared_topology_classes_represented" =>
            _declared_topology_classes_represented_v1(executable.base_genome,
                represented))
    status = all(values(checks)) ? :pass : :unknown
    authorized = status == :pass
    tasks = sort!(String["repair topology-domain composition check: $id"
        for (id, passed) in checks if !passed])
    support_hashes = sort(getfield.(supports, :support_hash))
    payload = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "design_id" => executable.base_genome.design_id,
        "genome_physics_hash" => executable.base_genome.physics_hash,
        "program_hash" => program.program_hash,
        "topology_module_id" => ready_module === nothing ? nothing : ready_module.id,
        "topology_implementation_id" => implementation_id,
        "required_domain_ids" => required_domains,
        "covered_domain_ids" => covered,
        "support_hashes" => support_hashes,
        "represented_topology_classes" => sort!(String.(collect(represented))),
        "checks" => checks,
        "status" => String(status),
        "c1_evidence_authorized" => authorized,
        "evidence_tasks" => tasks)
    return TopologyDomainCompositionResultV1("1.0.0",
        executable.base_genome.design_id, executable.base_genome.physics_hash,
        ready_module === nothing ? nothing : ready_module.id, implementation_id,
        required_domains, covered, support_hashes,
        sort!(collect(represented); by = String), checks, status, authorized,
        tasks, canonical_hash(payload))
end

function topology_domain_composition_to_dict_v1(
        item::TopologyDomainCompositionResultV1)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "topology_module_id" => item.topology_module_id,
        "topology_implementation_id" => item.topology_implementation_id,
        "required_domain_ids" => item.required_domain_ids,
        "covered_domain_ids" => item.covered_domain_ids,
        "support_hashes" => item.support_hashes,
        "represented_topology_classes" => String.(item.represented_topology_classes),
        "checks" => item.checks,
        "status" => String(item.status),
        "c1_evidence_authorized" => item.c1_evidence_authorized,
        "evidence_tasks" => item.evidence_tasks,
        "composition_hash" => item.composition_hash,
        "promotion_authorized" => false)
end

function topology_domain_composition_evidence_bundle_v1(
        executable::ExecutableGenomeV1,
        program::CompiledExecutablePhysicsProgramV1,
        result::TopologyDomainCompositionResultV1;
        fidelity::Integer = 1)
    result.design_id == executable.base_genome.design_id || throw(ArgumentError(
        "topology composition design does not match executable Genome"))
    result.genome_physics_hash == executable.base_genome.physics_hash ||
        throw(ArgumentError(
            "topology composition is not bound to the executable Genome physics hash"))
    authorized = result.status == :pass && result.c1_evidence_authorized
    status = authorized ? :pass : :unknown
    warnings = copy(result.evidence_tasks)
    metric_hash = canonical_hash(Dict{String,Any}(
        "evaluator" => "topology_domain_composer_v1",
        "program_hash" => program.program_hash,
        "composition_hash" => result.composition_hash,
        "status" => String(status)))
    metric = MetricResult("field_line_topology_resolved",
        authorized ? true : nothing; fidelity = Int(fidelity),
        applicability = "Exact non-overlapping physical-domain coverage by candidate-bound topology supports compiled for one executable topology module.",
        status = status, constraints_checked = sort!(collect(keys(result.checks))),
        solver_name = "topology_domain_composer_v1", solver_version = "1.0.0",
        input_hash = executable.base_genome.physics_hash, run_hash = metric_hash,
        source_basis = result.support_hashes, warnings = warnings)
    bundle_hash = canonical_hash(Dict{String,Any}(
        "metric_run_hash" => metric.run_hash,
        "program_hash" => program.program_hash))
    return EvaluationBundle("topology_domain_composer_v1", result.design_id,
        executable.base_genome.family, Int(fidelity), status, [metric], warnings,
        executable.base_genome.physics_hash, bundle_hash,
        authorized ? "C1_candidate_specific_topology_evidence" :
            "C0_topology_evidence_unknown")
end
