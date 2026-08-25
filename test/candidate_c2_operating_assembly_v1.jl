using Test
using JSON3
using FusionConceptAI

function c2_declaration_v1(id, value; provenance = "candidate_design_declaration",
        role = nothing, unit = "1", source_hash = repeat("a", 64))
    record = Dict{String,Any}("declaration_id" => id, "value" => value,
        "unit" => unit, "provenance_kind" => provenance,
        "source_hash" => source_hash)
    role === nothing || (record["role"] = role)
    return record
end

@testset "candidate operating point and composite assembly binding v1" begin
    states = [c2_declaration_v1("fuel_a_inventory", 1.0; unit = "particle"),
        c2_declaration_v1("ion_thermal_energy", 2.0; unit = "J")]
    actuators = [
        c2_declaration_v1("fueling_capacity", 2.0; role = "fueling", unit = "particle/s"),
        c2_declaration_v1("heating_capacity", 3.0; role = "heating", unit = "W"),
        c2_declaration_v1("exhaust_capacity", 2.0; role = "exhaust", unit = "particle/s"),
        c2_declaration_v1("radiation_capacity", 1.0; role = "radiation_control", unit = "W")]
    models = [c2_declaration_v1("transport_response", 0.1;
        provenance = "module_derived", source_hash = repeat("b", 64))]
    operating = compile_candidate_operating_point_v1(
        base_candidate_binding_hash = repeat("c", 64),
        state_declarations = states, actuator_declarations = actuators,
        model_declarations = models)
    @test operating.operating_point_hash ==
        compile_candidate_operating_point_v1(
            base_candidate_binding_hash = repeat("c", 64),
            state_declarations = reverse(states),
            actuator_declarations = reverse(actuators),
            model_declarations = models).operating_point_hash
    assembly = compile_candidate_assembly_binding_v1(operating;
        plasma_configuration_hash = repeat("d", 64),
        field_source_component_hashes = [repeat("e", 64)],
        boundary_hash = repeat("f", 64), actuator_manifest_hash = repeat("1", 64),
        engineering_manifest_hash = repeat("2", 64))
    @test assembly.base_candidate_binding_hash == repeat("c", 64)
    @test candidate_assembly_binding_to_dict_v1(assembly)["assembly_hash"] ==
        assembly.assembly_hash
    for schema_name in ("candidate_operating_point_v1.schema.json",
            "candidate_assembly_binding_v1.schema.json")
        schema = JSON3.read(read(joinpath(@__DIR__, "..", "schemas", schema_name), String))
        @test schema[Symbol("\$schema")] ==
            "https://json-schema.org/draft/2020-12/schema"
    end
    @test_throws ArgumentError compile_candidate_operating_point_v1(
        base_candidate_binding_hash = repeat("c", 64),
        state_declarations = [merge(states[1], Dict("family" => "forbidden"))],
        actuator_declarations = actuators, model_declarations = models)
    @test_throws ArgumentError compile_candidate_assembly_binding_v1(operating;
        plasma_configuration_hash = repeat("d", 64),
        field_source_component_hashes = String[], boundary_hash = repeat("f", 64),
        actuator_manifest_hash = repeat("1", 64),
        engineering_manifest_hash = repeat("2", 64))
end
