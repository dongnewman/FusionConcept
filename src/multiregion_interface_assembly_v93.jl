const MULTIREGION_INTERFACE_ASSEMBLY_V93_CLAIM_BOUNDARY =
    "The native assembly is a verification kernel for explicit Lagrange-multiplier conservation contracts. It is not a candidate FEM backend and grants no candidate equilibrium credit."

struct AssembledInterfaceSystemV93
    matrix::Matrix{Float64}
    rhs::Vector{Float64}
    region_ranges::Vector{UnitRange{Int}}
    multiplier_range::UnitRange{Int}
    constraint_matrix::Matrix{Float64}
    coupling_method::String
    assembly_hash::String
end

function assemble_lagrange_multiplier_system_v93(region_matrices, region_rhs,
        constraint_matrix)
    length(region_matrices) == length(region_rhs) || throw(ArgumentError("region block count mismatch"))
    sizes = [size(Matrix{Float64}(K), 1) for K in region_matrices]
    all(i -> size(Matrix{Float64}(region_matrices[i])) == (sizes[i], sizes[i]), eachindex(sizes)) ||
        throw(ArgumentError("region Jacobian blocks must be square"))
    all(i -> length(region_rhs[i]) == sizes[i], eachindex(sizes)) ||
        throw(ArgumentError("region residual block size mismatch"))
    total = sum(sizes); C = Matrix{Float64}(constraint_matrix)
    size(C, 2) == total || throw(ArgumentError("constraint trace width mismatch"))
    K = zeros(Float64, total, total); f = zeros(Float64, total)
    ranges = UnitRange{Int}[]; offset = 0
    for i in eachindex(sizes)
        range = (offset + 1):(offset + sizes[i]); push!(ranges, range)
        K[range, range] .= Matrix{Float64}(region_matrices[i])
        f[range] .= Float64.(region_rhs[i]); offset += sizes[i]
    end
    m = size(C, 1); A = [K C'; C zeros(Float64, m, m)]; rhs = [f; zeros(Float64, m)]
    body = Dict("region_block_hashes" => [canonical_hash(vec(Matrix{Float64}(x))) for x in region_matrices],
        "rhs_hashes" => [canonical_hash(Float64.(x)) for x in region_rhs],
        "constraint_hash" => canonical_hash(vec(C)), "coupling_method" => "lagrange_multiplier")
    AssembledInterfaceSystemV93(A, rhs, ranges, (total + 1):(total + m), C,
        "lagrange_multiplier", canonical_hash(body))
end

monolithic_residual_v93(system::AssembledInterfaceSystemV93, x) = system.matrix * Float64.(x) - system.rhs

function solve_monolithic_verification_v93(system::AssembledInterfaceSystemV93)
    x = system.matrix \ system.rhs
    residual = monolithic_residual_v93(system, x)
    Dict{String,Any}("state" => x, "normalized_residual" => norm(residual) / max(norm(system.rhs), 1.0),
        "interface_conservation_residual" => norm(system.constraint_matrix * x[1:first(system.multiplier_range)-1]),
        "algorithm" => "exact_linear_monolithic_lagrange_multiplier",
        "final_monolithic_reaudit" => true)
end

function solve_domain_decomposed_verification_v93(system::AssembledInterfaceSystemV93;
        tolerance = 1e-12, max_iterations = 50)
    K = system.matrix[1:first(system.multiplier_range)-1, 1:first(system.multiplier_range)-1]
    C = system.constraint_matrix; f = system.rhs[1:size(K, 1)]
    lambda = zeros(Float64, size(C, 1)); history = Float64[]
    S = C * (K \ C'); rhs_s = C * (K \ f)
    for _ in 1:max_iterations
        u = K \ (f - C' * lambda); r = C * u; push!(history, norm(r))
        norm(r) <= tolerance && break
        lambda += S \ r
    end
    u = K \ (f - C' * lambda); x = [u; lambda]
    final = monolithic_residual_v93(system, x)
    Dict{String,Any}("state" => x, "interface_history" => history,
        "interface_conservation_residual" => norm(C * u),
        "normalized_monolithic_residual" => norm(final) / max(norm(system.rhs), 1.0),
        "algorithm" => "nonoverlapping_schur_domain_decomposition",
        "final_monolithic_reaudit" => true)
end

function manufactured_interface_system_v93()
    system = assemble_lagrange_multiplier_system_v93([reshape([2.0], 1, 1), reshape([3.0], 1, 1)],
        [[2.5], [2.5]], reshape([1.0, -1.0], 1, 2))
    exact = [1.0, 1.0, 0.5]
    system, exact
end
