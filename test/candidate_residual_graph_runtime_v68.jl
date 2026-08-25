using Test
using FusionConceptAI
using JSON3
using LinearAlgebra
import FusionConceptAI: residual_module_id, state_layout, residual_contracts,
    jacobian_contracts, mass_matrix_contracts, residual_block!, jacobian_block!,
    mass_matrix_block!, validity_domain, applicability

struct V68AdditiveExchangeFixture <: AbstractResidualPhysicsModuleV1
    module_id::String
    validity_status::String
    jacobian_gain::Float64
end

V68AdditiveExchangeFixture(module_id, validity_status) =
    V68AdditiveExchangeFixture(module_id, validity_status, 0.03)

residual_module_id(m::V68AdditiveExchangeFixture) = m.module_id
state_layout(m::V68AdditiveExchangeFixture, manifest::CandidateSolveManifestV1) =
    StateBlockSpecV1[]
residual_contracts(m::V68AdditiveExchangeFixture, manifest::CandidateSolveManifestV1) =
    [ResidualBlockContractV1(m.module_id, "additive_exchange", :additive,
        ["particle_inventory", "thermal_energy"], ["1/s", "W"],
        ["particle_inventory", "thermal_energy"], ["control_volume_0"],
        String[], Dict{String,Any}[], String[])]
jacobian_contracts(m::V68AdditiveExchangeFixture, manifest::CandidateSolveManifestV1) =
    [JacobianBlockContractV1(m.module_id, "additive_exchange", :analytic,
        ["particle_inventory", "thermal_energy"],
        ["particle_inventory", "thermal_energy"], 2.0e-6, 1.0e-10)]
mass_matrix_contracts(m::V68AdditiveExchangeFixture, manifest::CandidateSolveManifestV1) =
    MassMatrixBlockContractV1[]
validity_domain(m::V68AdditiveExchangeFixture) = Dict{String,Any}(
    "status" => m.validity_status, "reason" => m.validity_status == "unknown" ?
        "exchange_coefficient_range_unverified" : "declared_manufactured_range")
applicability(m::V68AdditiveExchangeFixture, manifest::CandidateSolveManifestV1) =
    Dict{String,Any}("status" => "applicable")
function residual_block!(r, m::V68AdditiveExchangeFixture, u, du, p, t, context)
    index = context["state_index"]
    exchange = 0.03 * (u[index["particle_inventory"]] -
        u[index["thermal_energy"]])
    r[1] = exchange
    r[2] = -exchange
    return r
end
function jacobian_block!(J, m::V68AdditiveExchangeFixture, u, du, p, t, context)
    J[1, 1] = m.jacobian_gain; J[1, 2] = -m.jacobian_gain
    J[2, 1] = -m.jacobian_gain; J[2, 2] = m.jacobian_gain
    return J
end

struct V68NoSteadyFixture <: AbstractResidualPhysicsModuleV1 end
residual_module_id(::V68NoSteadyFixture) = "no_steady_transient_fixture"
state_layout(::V68NoSteadyFixture, manifest::CandidateSolveManifestV1) =
    [StateBlockSpecV1("no_steady_transient_fixture", "trajectory_state", "volume_0",
        ["inventory"], ["1"], ["1/s"], [1.0], [0.0], [floatmax(Float64)],
        0, ["steady", "transient", "pulsed"])]
residual_contracts(::V68NoSteadyFixture, manifest::CandidateSolveManifestV1) =
    [ResidualBlockContractV1("no_steady_transient_fixture", "constant_source",
        :governing, ["inventory"], ["1/s"], ["inventory"], ["volume_0"],
        String[], Dict{String,Any}[], String[])]
jacobian_contracts(::V68NoSteadyFixture, manifest::CandidateSolveManifestV1) =
    [JacobianBlockContractV1("no_steady_transient_fixture", "constant_source",
        :analytic, ["inventory"], ["inventory"], 1.0e-8, 1.0e-12)]
mass_matrix_contracts(::V68NoSteadyFixture, manifest::CandidateSolveManifestV1) =
    [MassMatrixBlockContractV1("no_steady_transient_fixture", "trajectory_mass",
        ["inventory"], [:differential])]
validity_domain(::V68NoSteadyFixture) = Dict{String,Any}("status" => "applicable")
applicability(::V68NoSteadyFixture, manifest::CandidateSolveManifestV1) =
    Dict{String,Any}("status" => "applicable")
function residual_block!(r, ::V68NoSteadyFixture, u, du, p, t, context)
    r[1] = -1.0
    return r
end
function jacobian_block!(J, ::V68NoSteadyFixture, u, du, p, t, context)
    J[1, 1] = 0.0
    return J
end
function mass_matrix_block!(M, ::V68NoSteadyFixture, u, p, t, context)
    M[1, 1] = 1.0
    return M
end

struct V68TwoRegionDiffusionFixture <: AbstractResidualPhysicsModuleV1 end
residual_module_id(::V68TwoRegionDiffusionFixture) = "two_region_diffusion_fixture"
function state_layout(::V68TwoRegionDiffusionFixture, manifest::CandidateSolveManifestV1)
    return [StateBlockSpecV1("two_region_diffusion_fixture", "left_state", "left",
            ["left_inventory"], ["1"], ["1/s"], [1.0], [0.0],
            [floatmax(Float64)], 1, ["steady", "transient"]),
        StateBlockSpecV1("two_region_diffusion_fixture", "right_state", "right",
            ["right_inventory"], ["1"], ["1/s"], [1.0], [0.0],
            [floatmax(Float64)], 1, ["steady", "transient"])]
end
function residual_contracts(::V68TwoRegionDiffusionFixture,
        manifest::CandidateSolveManifestV1)
    paired = [Dict{String,Any}("interface_id" => "left_right", "account" => "particle",
            "unit" => "1/s", "sign" => 1.0),
        Dict{String,Any}("interface_id" => "left_right", "account" => "particle",
            "unit" => "1/s", "sign" => -1.0)]
    return [ResidualBlockContractV1("two_region_diffusion_fixture", "paired_diffusion",
        :governing, ["left_inventory", "right_inventory"], ["1/s", "1/s"],
        ["left_inventory", "right_inventory"], ["left", "right"], String[],
        paired, String[])]
end
jacobian_contracts(::V68TwoRegionDiffusionFixture, manifest::CandidateSolveManifestV1) =
    [JacobianBlockContractV1("two_region_diffusion_fixture", "paired_diffusion",
        :analytic, ["left_inventory", "right_inventory"],
        ["left_inventory", "right_inventory"], 1.0e-7, 1.0e-12)]
mass_matrix_contracts(::V68TwoRegionDiffusionFixture, manifest::CandidateSolveManifestV1) =
    [MassMatrixBlockContractV1("two_region_diffusion_fixture", "diffusion_mass",
        ["left_inventory", "right_inventory"], [:differential, :differential])]
validity_domain(::V68TwoRegionDiffusionFixture) =
    Dict{String,Any}("status" => "applicable")
applicability(::V68TwoRegionDiffusionFixture, manifest::CandidateSolveManifestV1) =
    Dict{String,Any}("status" => "applicable")
function residual_block!(r, ::V68TwoRegionDiffusionFixture, u, du, p, t, context)
    index = context["state_index"]
    flux = 0.4 * (u[index["left_inventory"]] - u[index["right_inventory"]])
    r[1] = du[index["left_inventory"]] + flux
    r[2] = du[index["right_inventory"]] - flux
    return r
end
function jacobian_block!(J, ::V68TwoRegionDiffusionFixture, u, du, p, t, context)
    J .= [0.4 -0.4; -0.4 0.4]
    return J
end
function mass_matrix_block!(M, ::V68TwoRegionDiffusionFixture, u, p, t, context)
    M[1, 1] = 1.0; M[2, 2] = 1.0
    return M
end
function FusionConceptAI.boundary_flux!(f, ::V68TwoRegionDiffusionFixture,
        u, boundary, t, context)
    index = context["state_index"]
    flux = 0.4 * (u[index["left_inventory"]] - u[index["right_inventory"]])
    f[1] = Float64(boundary["sign"]) * flux
    return f
end

struct V68ThreeRegionLoopFixture <: AbstractResidualPhysicsModuleV1 end
residual_module_id(::V68ThreeRegionLoopFixture) = "three_region_loop_fixture"
function state_layout(::V68ThreeRegionLoopFixture, manifest::CandidateSolveManifestV1)
    return [StateBlockSpecV1("three_region_loop_fixture", "$(id)_state", id,
        ["$(id)_inventory"], ["1"], ["1/s"], [1.0], [1.0e-12],
        [floatmax(Float64)], 0, ["steady", "transient"]) for id in ("core", "edge", "wall")]
end
function residual_contracts(::V68ThreeRegionLoopFixture, manifest::CandidateSolveManifestV1)
    fluxes = Dict{String,Any}[]
    for (interface_id, account) in (("core_edge", "particle"), ("edge_wall", "particle")),
            sign in (1.0, -1.0)
        push!(fluxes, Dict("interface_id" => interface_id, "account" => account,
            "unit" => "1/s", "sign" => sign))
    end
    ids = ["core_inventory", "edge_inventory", "wall_inventory"]
    return [ResidualBlockContractV1("three_region_loop_fixture", "core_edge_wall_balance",
        :governing, ids, fill("1/s", 3), ids, ["core", "edge", "wall"],
        String[], fluxes, String[])]
end
jacobian_contracts(::V68ThreeRegionLoopFixture, manifest::CandidateSolveManifestV1) =
    [JacobianBlockContractV1("three_region_loop_fixture", "core_edge_wall_balance",
        :analytic, ["core_inventory", "edge_inventory", "wall_inventory"],
        ["core_inventory", "edge_inventory", "wall_inventory"], 1.0e-7, 1.0e-12)]
mass_matrix_contracts(::V68ThreeRegionLoopFixture, manifest::CandidateSolveManifestV1) =
    [MassMatrixBlockContractV1("three_region_loop_fixture", "three_region_mass",
        ["core_inventory", "edge_inventory", "wall_inventory"],
        fill(:differential, 3))]
validity_domain(::V68ThreeRegionLoopFixture) = Dict{String,Any}("status" => "applicable")
applicability(::V68ThreeRegionLoopFixture, manifest::CandidateSolveManifestV1) =
    Dict{String,Any}("status" => "applicable")
function residual_block!(r, ::V68ThreeRegionLoopFixture, u, du, p, t, context)
    index = context["state_index"]
    local_u = [u[index[id]] for id in ("core_inventory", "edge_inventory", "wall_inventory")]
    A = [0.6 -0.4 0.0; -0.4 0.8 -0.3; 0.0 -0.3 0.5]
    r .= [du[index[id]] for id in ("core_inventory", "edge_inventory", "wall_inventory")] .+
        A * local_u .- [0.2, 0.07, 0.02]
    return r
end
function jacobian_block!(J, ::V68ThreeRegionLoopFixture, u, du, p, t, context)
    J .= [0.6 -0.4 0.0; -0.4 0.8 -0.3; 0.0 -0.3 0.5]
    return J
end
function mass_matrix_block!(M, ::V68ThreeRegionLoopFixture, u, p, t, context)
    M .= Matrix{Float64}(I, 3, 3)
    return M
end
function FusionConceptAI.boundary_flux!(f, ::V68ThreeRegionLoopFixture,
        u, boundary, t, context)
    index = context["state_index"]
    id = String(boundary["interface_id"])
    flux = id == "core_edge" ? 0.4 * (u[index["core_inventory"]] -
        u[index["edge_inventory"]]) : 0.3 * (u[index["edge_inventory"]] -
        u[index["wall_inventory"]])
    f[1] = Float64(boundary["sign"]) * flux
    return f
end

struct V68ScalarTrajectoryFixture <: AbstractResidualPhysicsModuleV1
    module_id::String
    state_id::String
    gain::Float64
    lower_bound::Float64
end
residual_module_id(m::V68ScalarTrajectoryFixture) = m.module_id
state_layout(m::V68ScalarTrajectoryFixture, manifest::CandidateSolveManifestV1) =
    [StateBlockSpecV1(m.module_id, "scalar_state", "volume_0", [m.state_id],
        ["1"], ["1/s"], [1.0], [m.lower_bound], [floatmax(Float64)], 0,
        ["steady", "transient", "pulsed"])]
residual_contracts(m::V68ScalarTrajectoryFixture, manifest::CandidateSolveManifestV1) =
    [ResidualBlockContractV1(m.module_id, "scalar_balance", :governing,
        [m.state_id], ["1/s"], [m.state_id], ["volume_0"], String[],
        Dict{String,Any}[], String[])]
jacobian_contracts(m::V68ScalarTrajectoryFixture, manifest::CandidateSolveManifestV1) =
    [JacobianBlockContractV1(m.module_id, "scalar_balance", :analytic,
        [m.state_id], [m.state_id], 1.0e-8, 1.0e-12)]
mass_matrix_contracts(m::V68ScalarTrajectoryFixture, manifest::CandidateSolveManifestV1) =
    [MassMatrixBlockContractV1(m.module_id, "scalar_mass", [m.state_id], [:differential])]
validity_domain(m::V68ScalarTrajectoryFixture) = Dict{String,Any}("status" => "applicable")
applicability(m::V68ScalarTrajectoryFixture, manifest::CandidateSolveManifestV1) =
    Dict{String,Any}("status" => "applicable")
function residual_block!(r, m::V68ScalarTrajectoryFixture, u, du, p, t, context)
    index = context["state_index"][m.state_id]
    r[1] = du[index] + m.gain * u[index]
    return r
end
function jacobian_block!(J, m::V68ScalarTrajectoryFixture, u, du, p, t, context)
    J[1, 1] = m.gain
    return J
end
function mass_matrix_block!(M, m::V68ScalarTrajectoryFixture, u, p, t, context)
    M[1, 1] = 1.0
    return M
end

function v68_manifest(; particle_output = 0.2, heating_output = 0.2,
        levels = [32, 64, 128])
    ids_units = [
        ("particle_inventory", "1"),
        ("thermal_energy", "J"),
        ("particle_actuator_output", "1/s"),
        ("heating_actuator_output", "W")]
    return CandidateSolveManifestV1(candidate_id = "v68_manufactured_zero_d",
        physics_hash = repeat("6", 64), regions = [Dict{String,Any}(
            "region_id" => "control_volume_0", "spatial_dimension" => 0)],
        state_variables = [Dict{String,Any}("state_id" => id, "unit" => unit)
            for (id, unit) in ids_units],
        capability_declarations = [Dict{String,Any}(
            "capability_id" => "coupled_particle_energy_reaction_radiation_actuator")],
        module_bindings = [Dict{String,Any}(
            "module_id" => "zero_d_particle_energy_actuator_v1")],
        time_mode = "steady", initial_conditions = Dict(
            "particle_inventory" => 0.7, "thermal_energy" => 0.6,
            "particle_actuator_output" => particle_output,
            "heating_actuator_output" => heating_output),
        numerical_tolerances = Dict("normalized_residual" => 1.0e-8,
            "steady_time_term" => 1.0e-8, "relative_resolution" => 1.0e-8),
        discretization_levels = levels, parameters = Dict{String,Any}())
end

@testset "v68 universal residual graph and nonlinear coupled runtime" begin
    manifest = v68_manifest()
    module_instance = ZeroDParticleEnergyActuatorModuleV1()
    modules = AbstractResidualPhysicsModuleV1[module_instance]
    plan = compile_coupled_solve_plan_v1(manifest, modules)
    @test plan.status == :pass
    @test plan.state_ids == plan.residual_row_ids
    @test count(plan.differential_mask) == 2
    @test plan.compiler_audits["mass_or_constraint"] == "pass"
    @test plan.compiler_audits["jacobian_slots"] == "pass"
    @test plan.compiler_audits["routing_inputs"] ==
        "declared_capabilities_states_operators_domains_boundaries_only"
    @test plan.plan_hash == compile_coupled_solve_plan_v1(manifest, modules).plan_hash

    empty_modules = AbstractResidualPhysicsModuleV1[]
    unsupported_plan = compile_coupled_solve_plan_v1(manifest, empty_modules)
    @test unsupported_plan.status == :unsupported
    unsupported_result = solve_coupled_plan_v1(manifest, empty_modules, unsupported_plan)
    @test unsupported_result.status == :unsupported
    @test unsupported_result.classification_code == "unsupported_compiled_graph"

    result = solve_coupled_plan_v1(manifest, modules, plan)
    @test result.status == :pass
    @test result.classification_code == "pass_v68_full_coupled_residual"
    @test result.convergence_status == "homotopy_and_damped_newton_krylov_converged"
    @test isapprox(result.final_state["particle_inventory"], 1.0; atol = 1.0e-7)
    @test isapprox(result.final_state["thermal_energy"], 1.0; atol = 1.0e-7)
    @test result.audits["all_residual_blocks"] == "pass"
    @test result.audits["independent_residual_recalculation"] == "pass"
    @test all(item -> item["status"] == "pass",
        result.audits["jacobian_directional_audits"])
    @test result.audits["full_model_lambda"] == 1.0
    @test result.audits["l1_role"] ==
        "initial_state_homotopy_origin_and_diagnostic_baseline"
    @test result.result_hash == solve_coupled_plan_v1(manifest, modules, plan).result_hash

    additive = V68AdditiveExchangeFixture("additive_exchange_fixture", "applicable")
    additive_modules = AbstractResidualPhysicsModuleV1[module_instance, additive]
    additive_plan = compile_coupled_solve_plan_v1(manifest, additive_modules)
    @test additive_plan.status == :pass
    @test additive_plan.compiler_audits["residual_producers"] == "pass"
    additive_result = solve_coupled_plan_v1(manifest, additive_modules, additive_plan)
    @test additive_result.status == :pass
    @test any(item -> item["block_id"] == "additive_exchange",
        additive_result.block_residuals)

    bad_jacobian = V68AdditiveExchangeFixture(
        "bad_jacobian_exchange_fixture", "applicable", 0.0)
    bad_jacobian_modules = AbstractResidualPhysicsModuleV1[module_instance, bad_jacobian]
    bad_jacobian_plan = compile_coupled_solve_plan_v1(manifest, bad_jacobian_modules)
    bad_jacobian_result = solve_coupled_plan_v1(manifest, bad_jacobian_modules,
        bad_jacobian_plan)
    @test bad_jacobian_result.status == :unknown
    @test bad_jacobian_result.classification_code == "unknown_numerical_audit_failure"
    @test any(item -> item["status"] == "fail",
        bad_jacobian_result.audits["jacobian_directional_audits"])

    unknown_module = V68AdditiveExchangeFixture("unknown_exchange_fixture", "unknown")
    unknown_plan = compile_coupled_solve_plan_v1(manifest,
        AbstractResidualPhysicsModuleV1[module_instance, unknown_module])
    @test unknown_plan.status == :unknown
    unknown_result = solve_coupled_plan_v1(manifest,
        AbstractResidualPhysicsModuleV1[module_instance, unknown_module], unknown_plan)
    @test unknown_result.status == :unknown
    @test unknown_result.classification_code == "unknown_input_or_validity_evidence"

    saturated_module = ZeroDParticleEnergyActuatorModuleV1(
        particle_capacity = 0.1, heating_capacity = 0.1)
    saturated_modules = AbstractResidualPhysicsModuleV1[saturated_module]
    saturated_manifest = v68_manifest(particle_output = 0.05, heating_output = 0.05)
    saturated_plan = compile_coupled_solve_plan_v1(saturated_manifest, saturated_modules)
    saturated = solve_coupled_plan_v1(saturated_manifest, saturated_modules, saturated_plan)
    @test saturated.status == :fail
    @test saturated.classification_code == "fail_actuator_capacity_shortfall"
    @test saturated.observables[saturated_module.module_id]["capacity_shortfall"]

    transient_manifest = CandidateSolveManifestV1(candidate_id = "v68_no_steady",
        physics_hash = repeat("7", 64),
        regions = [Dict{String,Any}("region_id" => "volume_0", "spatial_dimension" => 0)],
        state_variables = [Dict{String,Any}("state_id" => "inventory", "unit" => "1")],
        capability_declarations = [Dict{String,Any}("capability_id" => "constant_source")],
        module_bindings = [Dict{String,Any}("module_id" => "no_steady_transient_fixture")],
        time_mode = "steady", initial_conditions = Dict("inventory" => 1.0),
        numerical_tolerances = Dict("normalized_residual" => 1.0e-8,
            "steady_time_term" => 1.0e-8, "relative_resolution" => 1.0e-8),
        discretization_levels = [32, 64, 128])
    transient_modules = AbstractResidualPhysicsModuleV1[V68NoSteadyFixture()]
    transient_plan = compile_coupled_solve_plan_v1(transient_manifest, transient_modules)
    @test transient_plan.status == :pass
    transient = solve_coupled_plan_v1(transient_manifest, transient_modules, transient_plan;
        backend = NativeSparseNewtonKrylovBackendV1(dae_steps = 4, dae_dt = 0.25))
    @test transient.status == :unknown
    @test transient.classification_code == "unknown_no_steady_state_transient_complete"
    @test transient.convergence_status == "implicit_dae_trajectory_complete"
    @test length(transient.trajectory) == 4

    diffusion_manifest = CandidateSolveManifestV1(candidate_id = "v68_two_region_diffusion",
        physics_hash = repeat("8", 64), regions = [
            Dict{String,Any}("region_id" => "left", "spatial_dimension" => 1),
            Dict{String,Any}("region_id" => "right", "spatial_dimension" => 1)],
        state_variables = [Dict{String,Any}("state_id" => "left_inventory", "unit" => "1"),
            Dict{String,Any}("state_id" => "right_inventory", "unit" => "1")],
        capability_declarations = [Dict{String,Any}("capability_id" => "paired_diffusion")],
        module_bindings = [Dict{String,Any}("module_id" => "two_region_diffusion_fixture")],
        time_mode = "steady", initial_conditions = Dict("left_inventory" => 0.8,
            "right_inventory" => 0.2), numerical_tolerances = Dict(
            "normalized_residual" => 1.0e-8, "steady_time_term" => 1.0e-8,
            "relative_resolution" => 1.0e-8), discretization_levels = [32, 64, 128])
    diffusion_modules = AbstractResidualPhysicsModuleV1[V68TwoRegionDiffusionFixture()]
    diffusion_plan = compile_coupled_solve_plan_v1(diffusion_manifest, diffusion_modules)
    @test diffusion_plan.status == :pass
    diffusion = solve_coupled_plan_v1(diffusion_manifest, diffusion_modules, diffusion_plan)
    @test diffusion.status == :unknown
    @test diffusion.classification_code == "unknown_missing_resolution_trend"
    @test isapprox(diffusion.final_state["left_inventory"],
        diffusion.final_state["right_inventory"]; atol = 1.0e-8)
    @test diffusion.audits["interface_flux_pair_closure"]["status"] == "pass"
    @test diffusion.audits["interface_flux_pair_closure"]["pair_count"] == 1
    @test diffusion.audits["resolution_trend"]["status"] == "unknown"

    three_manifest = CandidateSolveManifestV1(candidate_id = "v68_three_region_loop",
        physics_hash = repeat("9", 64), regions = [Dict{String,Any}(
            "region_id" => id, "spatial_dimension" => 0) for id in ("core", "edge", "wall")],
        state_variables = [Dict{String,Any}("state_id" => "$(id)_inventory", "unit" => "1")
            for id in ("core", "edge", "wall")],
        capability_declarations = [Dict{String,Any}("capability_id" => "three_region_loop")],
        module_bindings = [Dict{String,Any}("module_id" => "three_region_loop_fixture")],
        time_mode = "steady", initial_conditions = Dict("core_inventory" => 1.0,
            "edge_inventory" => 0.5, "wall_inventory" => 0.1),
        numerical_tolerances = Dict("normalized_residual" => 1.0e-8,
            "steady_time_term" => 1.0e-8, "relative_resolution" => 1.0e-8),
        discretization_levels = [32, 64, 128])
    three_modules = AbstractResidualPhysicsModuleV1[V68ThreeRegionLoopFixture()]
    three_plan = compile_coupled_solve_plan_v1(three_manifest, three_modules)
    three = solve_coupled_plan_v1(three_manifest, three_modules, three_plan)
    @test three.status == :pass
    @test three.audits["interface_flux_pair_closure"]["pair_count"] == 2
    @test three.audits["interface_flux_pair_closure"]["status"] == "pass"

    function scalar_manifest(candidate_id, state_id, module_id, initial, hash_character)
        CandidateSolveManifestV1(candidate_id = candidate_id,
            physics_hash = repeat(hash_character, 64),
            regions = [Dict{String,Any}("region_id" => "volume_0", "spatial_dimension" => 0)],
            state_variables = [Dict{String,Any}("state_id" => state_id, "unit" => "1")],
            capability_declarations = [Dict{String,Any}("capability_id" => module_id)],
            module_bindings = [Dict{String,Any}("module_id" => module_id)],
            time_mode = "steady", initial_conditions = Dict(state_id => initial),
            numerical_tolerances = Dict("normalized_residual" => 1.0e-8,
                "steady_time_term" => 1.0e-8, "relative_resolution" => 1.0e-8),
            discretization_levels = [32, 64, 128])
    end
    depletion_module = V68ScalarTrajectoryFixture("open_boundary_depletion_fixture",
        "inventory", 0.5, 0.1)
    depletion_manifest = scalar_manifest("v68_open_boundary_depletion", "inventory",
        depletion_module.module_id, 1.0, "a")
    depletion_modules = AbstractResidualPhysicsModuleV1[depletion_module]
    depletion_plan = compile_coupled_solve_plan_v1(depletion_manifest, depletion_modules)
    depletion = solve_coupled_plan_v1(depletion_manifest, depletion_modules, depletion_plan;
        backend = NativeSparseNewtonKrylovBackendV1(dae_steps = 4, dae_dt = 0.1))
    @test depletion.status == :unknown
    @test depletion.classification_code == "unknown_no_steady_state_transient_complete"
    @test depletion.trajectory[end]["state"]["inventory"] <
        depletion.trajectory[1]["state"]["inventory"]

    instability_module = V68ScalarTrajectoryFixture("thermal_instability_fixture",
        "thermal_energy", -0.2, 0.1)
    instability_manifest = scalar_manifest("v68_thermal_instability", "thermal_energy",
        instability_module.module_id, 1.0, "b")
    instability_modules = AbstractResidualPhysicsModuleV1[instability_module]
    instability_plan = compile_coupled_solve_plan_v1(instability_manifest, instability_modules)
    instability = solve_coupled_plan_v1(instability_manifest, instability_modules,
        instability_plan; backend = NativeSparseNewtonKrylovBackendV1(
            dae_steps = 4, dae_dt = 0.1))
    @test instability.status == :unknown
    @test instability.classification_code == "unknown_no_steady_state_transient_complete"
    @test instability.trajectory[end]["state"]["thermal_energy"] >
        instability.trajectory[1]["state"]["thermal_energy"]

    source = read(joinpath(@__DIR__, "..", "src",
        "candidate_residual_graph_runtime_v68.jl"), String)
    @test !occursin("genome.family", source)
    @test !occursin("family ==", source)
    @test occursin("finite_difference_l1_only", source)
    @test occursin("implicit_dae", source)
    schema = JSON3.read(read(joinpath(@__DIR__, "..", "schemas",
        "coupled_residual_runtime_v68.schema.json"), String))
    @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
    @test Set(String.(keys(schema[Symbol("\$defs")]))) == Set([
        "StateBlockSpecV1", "ResidualBlockContractV1", "JacobianBlockContractV1",
        "MassMatrixBlockContractV1", "CoupledSolvePlanV1",
        "NonlinearSolveResultEnvelopeV1"])
end
