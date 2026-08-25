using Test
using JSON3
using FusionConceptAI

@testset "Directed particle source is executable candidate physics v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    genome_path = joinpath(root, "examples", "pleiades_wham_nbi_kinetic_control_v1.json")
    executable_path = joinpath(root, "examples",
        "pleiades_wham_nbi_kinetic_control_executable_physics_v2.json")
    binding_path = joinpath(root, "knowledge",
        "pleiades_wham_nbi_kinetic_control_executable_binding_v2.json")
    genome = load_genome(genome_path)
    executable = load_executable_genome_v2(genome_path, executable_path)
    binding = JSON3.read(read(binding_path, String), Dict{String,Any})
    validation = validate_executable_genome_v2(executable)
    @test validation.valid
    @test isempty(validation.errors)
    @test executable.schema_version == "0.3.0"
    @test executable.candidate_physics_hash ==
        binding["executable_candidate_physics_hash"]
    @test executable.document_hash == binding["executable_document_hash"]
    @test validate_executable_genome_v1(
        executable_genome_v1_projection(executable)).valid
    source = only(executable.directed_particle_sources)
    @test source.spectrum_fraction_basis == :neutral_particle_number_fraction
    @test length(source.apertures) == 2
    @test length(source.energy_components) == 3
    @test isapprox(sum(getfield.(source.energy_components, :fraction)), 1.0;
        atol = 1.0e-15)
    backend = compile_pyfidasim_nbi_input_v1(source)
    @test canonical_hash(backend) == binding["pyfidasim_nbi_input_hash"]
    @test backend == binding["pyfidasim_nbi_input"]

    raw = JSON3.read(read(executable_path, String), Dict{String,Any})
    moved_raw = deepcopy(raw)
    moved_raw["directed_particle_sources"][1]["target_position_m"][1] = 0.11
    moved = parse_executable_genome_v2(genome, moved_raw)
    @test validate_executable_genome_v2(moved).valid
    @test moved.candidate_physics_hash != executable.candidate_physics_hash
    @test compile_pyfidasim_nbi_input_v1(only(moved.directed_particle_sources)) != backend

    provenance_raw = deepcopy(raw)
    push!(provenance_raw["directed_particle_sources"][1]["source_ids"],
        "additional_provenance_only")
    provenance = parse_executable_genome_v2(genome, provenance_raw)
    @test provenance.candidate_physics_hash == executable.candidate_physics_hash
    @test provenance.document_hash != executable.document_hash

    bad_fraction_raw = deepcopy(raw)
    bad_fraction_raw["directed_particle_sources"][1]["energy_components"][1]["fraction"] = 0.69
    @test !validate_executable_genome_v2(
        parse_executable_genome_v2(genome, bad_fraction_raw)).valid
    bad_basis_raw = deepcopy(raw)
    bad_basis_raw["directed_particle_sources"][1]["spectrum_fraction_basis"] =
        "source_ion_current_fraction"
    @test !validate_executable_genome_v2(
        parse_executable_genome_v2(genome, bad_basis_raw)).valid
    bad_binding_raw = deepcopy(raw)
    bad_binding_raw["directed_particle_sources"][1]["actuator_parameter_bindings"][
        "declared_power_parameter_id"] = "missing_power"
    @test !validate_executable_genome_v2(
        parse_executable_genome_v2(genome, bad_binding_raw)).valid
end
