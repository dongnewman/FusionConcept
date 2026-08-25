"""
Compile an explicit three-dimensional Fourier boundary into a DESC solver
problem without using the candidate family label. The returned problem hash is
computed only from the numerical boundary, profiles, resolution and solver
contract; it is therefore stable under family-label changes.
"""
function compile_topology_desc_fourier_problem_v2(genome::Genome)
    mismatches = filter(!=("family"), _desc_fourier_mismatches(genome))
    isempty(mismatches) || return Dict{String,Any}(
        "compiler_version" => "topology_desc_fourier_problem_v2",
        "status" => "not_applicable",
        "candidate_physics_hash" => genome.physics_hash,
        "family_label_used" => false,
        "mismatches" => mismatches,
        "solver_input" => nothing,
        "solver_problem_hash" => nothing,
        "claim_boundary" => "No solver problem was authorized because the explicit physical geometry, topology, profile or numerical contract did not match.")
    input = _desc_fourier_inputs(genome)
    problem_hash = canonical_hash(input)
    return Dict{String,Any}(
        "compiler_version" => "topology_desc_fourier_problem_v2",
        "status" => "ready",
        "candidate_design_id" => genome.design_id,
        "candidate_physics_hash" => genome.physics_hash,
        "family_label_used" => false,
        "ignored_metadata_fields" => ["family", "label"],
        "physical_geometry_model" => "desc_stellarator_symmetric_fourier_v1",
        "solver_input" => input,
        "solver_problem_hash" => problem_hash,
        "claim_boundary" => "This contract authorizes only a candidate-specific fixed-boundary DESC equilibrium problem. It does not authorize stability, transport, coils, fusion performance, engineering or promotion.")
end

"""Compile the medium-resolution sampled stability problem without family identity."""
function compile_topology_desc_stability_problem_v2(genome::Genome)
    equilibrium = compile_topology_desc_fourier_problem_v2(genome)
    equilibrium["status"] == "ready" || return Dict{String,Any}(
        "compiler_version" => "topology_desc_stability_problem_v2",
        "status" => "not_applicable",
        "candidate_physics_hash" => genome.physics_hash,
        "family_label_used" => false,
        "mismatches" => get(equilibrium, "mismatches", String[]),
        "solver_input" => nothing,
        "solver_problem_hash" => nothing)
    input = _desc_stability_input(genome)
    # The upstream runner requires a 64-hex identity inside the payload. First
    # remove candidate identity, hash the complete physical/numerical problem,
    # then bind that problem hash back into the required identity field.
    problem_without_identity = deepcopy(input)
    delete!(problem_without_identity, "physics_hash")
    problem_hash = canonical_hash(problem_without_identity)
    input["physics_hash"] = problem_hash
    return Dict{String,Any}(
        "compiler_version" => "topology_desc_stability_problem_v2",
        "status" => "ready",
        "candidate_design_id" => genome.design_id,
        "candidate_physics_hash" => genome.physics_hash,
        "family_label_used" => false,
        "ignored_metadata_fields" => ["family", "label"],
        "equilibrium_solver_problem_hash" =>
            equilibrium["solver_problem_hash"],
        "solver_input" => input,
        "solver_problem_hash" => problem_hash,
        "claim_boundary" => "This contract authorizes a medium-resolution re-solved fixed-boundary Mercier and infinite-n ballooning sampling problem only; it does not establish all-mode stability or complete C2.")
end
