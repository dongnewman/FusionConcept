using Test
using FusionConceptAI

const _ACTUATOR_DERIVATION_GENOME_PATH = joinpath(@__DIR__, "..", "examples",
    "pleiades_wham_isotropic_regression_genome.json")

function _wham_nbi_declaration_v1(; id = "wham_25kev_40a_nbi")
    Dict{String,Any}(
        "id" => id,
        "kind" => "neutral_beam",
        "parameters" => Dict{String,Any}(
            "declared_beam_power" => Dict("value" => 1.0, "unit" => "MW"),
            "primary_particle_energy" => Dict("value" => 25.0, "unit" => "keV"),
            "equivalent_current" => Dict("value" => 40.0, "unit" => "A"),
            "injection_pitch_angle" => Dict("value" => 45.0, "unit" => "deg"),
            "primary_energy_fraction" => Dict("value" => 0.70, "unit" => "1"),
            "half_energy_fraction" => Dict("value" => 0.20, "unit" => "1"),
            "third_energy_fraction" => Dict("value" => 0.10, "unit" => "1"),
            "charge_state" => Dict("value" => 1.0, "unit" => "1")))
end

@testset "Actuator derivation creates a new executable physics hash v1" begin
    base = load_genome(_ACTUATOR_DERIVATION_GENOME_PATH)
    base_content = base.content_hash
    derived, audit = derive_genome_with_actuators_v1(base;
        design_id = "pleiades_wham_nbi_kinetic_control_v1",
        label = "Pleiades WHAM NBI kinetic control",
        actuator_declarations = [_wham_nbi_declaration_v1()],
        source_ids = ["wham_physics_basis_2023"],
        notes = ["NBI is a structural candidate declaration only."])
    @test isempty(base.actuators)
    @test base.content_hash == base_content
    @test length(derived.actuators) == 1
    @test derived.actuators[1].id == "wham_25kev_40a_nbi"
    @test derived.physics_hash != base.physics_hash
    @test audit.base_unchanged
    @test audit.physics_hash_changed
    @test audit.validation_valid
    @test audit.added_actuator_ids == ["wham_25kev_40a_nbi"]
    @test length(audit.derivation_hash) == 64
end

@testset "Actuator derivation is deterministic and unit-normalized v1" begin
    base = load_genome(_ACTUATOR_DERIVATION_GENOME_PATH)
    args = (design_id = "pleiades_wham_nbi_kinetic_control_v1",
        actuator_declarations = [_wham_nbi_declaration_v1()],
        source_ids = ["wham_physics_basis_2023"])
    first, first_audit = derive_genome_with_actuators_v1(base; args...)
    second, second_audit = derive_genome_with_actuators_v1(base; args...)
    @test first.content_hash == second.content_hash
    @test first.physics_hash == second.physics_hash
    @test first_audit.derivation_hash == second_audit.derivation_hash
    params = first.actuators[1].parameters
    @test isapprox(params["declared_beam_power"].value, 1.0e6)
    @test params["declared_beam_power"].unit == "W"
    @test isapprox(params["primary_particle_energy"].value,
        25.0e3 * 1.602176634e-19; rtol = 1.0e-14)
    @test params["primary_particle_energy"].unit == "J"
    @test isapprox(params["injection_pitch_angle"].value, pi / 4)
end

@testset "Actuator derivation rejects aliasing and duplicate IDs v1" begin
    base = load_genome(_ACTUATOR_DERIVATION_GENOME_PATH)
    @test_throws ArgumentError derive_genome_with_actuators_v1(base;
        design_id = base.design_id,
        actuator_declarations = [_wham_nbi_declaration_v1()])
    @test_throws ArgumentError derive_genome_with_actuators_v1(base;
        design_id = "duplicate_actuator_probe",
        actuator_declarations = [_wham_nbi_declaration_v1(),
            _wham_nbi_declaration_v1()])
    @test_throws ArgumentError derive_genome_with_actuators_v1(base;
        design_id = "empty_actuator_probe", actuator_declarations = Any[])
end
