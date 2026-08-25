struct ProfileCoupledRFPTopologySpecV8
    mechanism::String
    target_count::Int

    function ProfileCoupledRFPTopologySpecV8(mechanism::AbstractString,
            target_count::Integer)
        m, n = String(mechanism), Int(target_count)
        m in ("self_organized_qsh", "qsh_pulsed_poloidal_current_drive",
            "qsh_ppcd_boundary_mode_control") || throw(ArgumentError(
            "unsupported profile-coupled RFP mechanism $m"))
        n in (2, 4, 8) || throw(ArgumentError(
            "target count must be 2, 4, or 8"))
        new(m, n)
    end
end

_pcrfp_specs_v8() = [ProfileCoupledRFPTopologySpecV8(m, n)
    for m in ("self_organized_qsh", "qsh_pulsed_poloidal_current_drive",
        "qsh_ppcd_boundary_mode_control") for n in (2, 4, 8)]
_pcrfp_key_v8(s::ProfileCoupledRFPTopologySpecV8) =
    "reversed_field_pinch|$(s.mechanism)|targets=$(s.target_count)"
_pcrfp_v7_spec(s::ProfileCoupledRFPTopologySpecV8) =
    SelfOrganizedTopologySpecV7("reversed_field_pinch", s.mechanism,
        s.target_count)

function _pcrfp_structural_base_v8(parent::Genome,
        spec::ProfileCoupledRFPTopologySpecV8)
    old = _sov7_structural_base(parent, _pcrfp_v7_spec(spec))
    raw = deepcopy(old.normalized)
    raw["design_id"] = "pending_profile_coupled_rfp_v8"
    raw["label"] = "Profile-coupled RFP v8 $(_pcrfp_key_v8(spec))"
    source = only(filter(item ->
        item["kind"] == "self_organized_plasma_current",
        raw["field_sources"]))
    source["geometry_model"] = "alpha_theta0_on_axis_regular_current_profile"
    sources = raw["provenance"]["source_ids"]
    for id in ("rfp_sheq_martines_2011", "rfp_mpfm_shen_sprott_1991")
        id in sources || push!(sources, id)
    end
    raw["provenance"]["notes"] = [
        "profile_coupled_rfp_qd_v8",
        "F and Theta are ODE-derived from an on-axis-regular profile",
        "same outer envelope; fidelity-0 rejection only"]
    provisional = parse_genome(raw)
    raw["design_id"] = "structure_$(provisional.physics_hash[1:20])"
    parse_genome(raw)
end

function _pcrfp_ranges_v8(spec::ProfileCoupledRFPTopologySpecV8, u)
    values = _sov7_ranges(_pcrfp_v7_spec(spec), u)
    theta0 = 1.25 + 1.50u[7]
    alpha = 1.05 + 6.95u[8]
    profile = _pcrfp_profile_projection(theta0, alpha)
    values["screen_rfp_profile_theta0"] = theta0
    values["screen_rfp_profile_alpha"] = alpha
    values["screen_reversal_parameter"] = profile.reversal_parameter
    values["screen_pinch_parameter"] = profile.pinch_parameter
    values
end

function _pcrfp_acquisition_features_v8(spec, values)
    _sov7_acquisition_features(_pcrfp_v7_spec(spec), values)
end

function _pcrfp_nominal_v8(base, contract, features, values)
    profile = _pcrfp_profile_projection(
        values["screen_rfp_profile_theta0"],
        values["screen_rfp_profile_alpha"])
    _pcrfp_nominal(base, contract, features, profile)
end

function _pcrfp_instantiate_v8(base::Genome, values, contract)
    old = _sov7_instantiate(base, values, contract)
    raw = deepcopy(old.normalized)
    raw["design_id"] = "pending_profile_coupled_rfp_v8"
    for (name, value, basis) in (
            ("screen_rfp_profile_theta0",
                values["screen_rfp_profile_theta0"],
                "profile-coupled RFP QD v8 gene"),
            ("screen_rfp_profile_alpha",
                values["screen_rfp_profile_alpha"],
                "profile-coupled RFP QD v8 gene"),
            ("screen_reversal_parameter",
                values["screen_reversal_parameter"],
                "derived by cylindrical profile ODE"),
            ("screen_pinch_parameter",
                values["screen_pinch_parameter"],
                "derived by cylindrical profile ODE"))
        _ctv4_set_target!(raw, name, value, "1"; basis = basis)
    end
    source = only(filter(item ->
        item["kind"] == "self_organized_plasma_current",
        raw["field_sources"]))
    source["geometry_model"] = "alpha_theta0_on_axis_regular_current_profile"
    source["parameters"]["profile_theta0"] =
        _ctv4_quantity(values["screen_rfp_profile_theta0"], "1")
    source["parameters"]["profile_alpha"] =
        _ctv4_quantity(values["screen_rfp_profile_alpha"], "1")
    source["parameters"]["derived_reversal_parameter"] =
        _ctv4_quantity(values["screen_reversal_parameter"], "1")
    source["parameters"]["derived_pinch_parameter"] =
        _ctv4_quantity(values["screen_pinch_parameter"], "1")
    provisional = parse_genome(raw)
    raw["design_id"] = "concept_$(provisional.physics_hash[1:20])"
    candidate = parse_genome(raw)
    validate_genome(candidate).valid || error("invalid profile-coupled RFP candidate")
    candidate
end

function _pcrfp_descriptor_v8(contract, spec, features, values)
    beta_bin = clamp(floor(Int, 5features.beta), 0, 4)
    alpha_bin = clamp(floor(Int,
        4(values["screen_rfp_profile_alpha"] - 1.05) / 6.95), 0, 3)
    theta0_bin = clamp(floor(Int,
        4(values["screen_rfp_profile_theta0"] - 1.25) / 1.50), 0, 3)
    "$(contract.id)|$(_pcrfp_key_v8(spec))|beta=$beta_bin|alpha=$alpha_bin|theta0=$theta0_bin"
end

function _pcrfp_quality_v8(record)
    nominal = record["nominal"]
    margins = Float64.(collect(values(nominal["margins"])))
    (count(x -> x < 0.0, margins),
        sum(log1p(-min(0.0, x)) for x in margins),
        -Float64(nominal["net_electric_power_W"]),
        canonical_hash(record["features"]))
end

function run_profile_coupled_rfp_qd_v8(seeds::Vector{Genome};
        acquisition_samples::Int = 300_000, random_seed::Int = 20260813,
        maximum_graph_elites::Int = 216,
        elites_per_structural_stratum::Int = 4,
        contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    acquisition_samples >= 0 || throw(ArgumentError("negative sample count"))
    parent = only(filter(g -> g.family == "tokamak_axisymmetric", seeds))
    specs = _pcrfp_specs_v8()
    structural = Dict(_pcrfp_key_v8(spec) =>
        _pcrfp_structural_base_v8(parent, spec) for spec in specs)
    strata = [(contract, spec) for contract in contracts for spec in specs]
    primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37,
        41, 43, 47, 53, 59, 61, 67, 71, 73)
    archive = Dict{String,Dict{String,Any}}()
    positive_net, nominal_pass, profile_domain_pass = 0, 0, 0
    for index in 1:acquisition_samples
        contract, spec = strata[mod1(index, length(strata))]
        u = ntuple(axis -> _ctv4_halton(index, primes[axis]), length(primes))
        values = _pcrfp_ranges_v8(spec, u)
        base = structural[_pcrfp_key_v8(spec)]
        features = _pcrfp_acquisition_features_v8(spec, values)
        nominal = _pcrfp_nominal_v8(base, contract, features, values)
        nominal["margins"]["on_axis_regular_current_profile"] >= 0 &&
            (profile_domain_pass += 1)
        nominal["net_electric_power_W"] > 0 && (positive_net += 1)
        nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true && (nominal_pass += 1)
        proposal = Dict{String,Any}(
            "descriptor" => _pcrfp_descriptor_v8(contract, spec, features, values),
            "stratum" => "$(contract.id)|$(_pcrfp_key_v8(spec))",
            "contract_id" => contract.id,
            "spec_key" => _pcrfp_key_v8(spec),
            "features" => values, "nominal" => nominal)
        incumbent = get(archive, proposal["descriptor"], nothing)
        if incumbent === nothing ||
                _pcrfp_quality_v8(proposal) < _pcrfp_quality_v8(incumbent)
            archive[proposal["descriptor"]] = proposal
        end
    end
    by_stratum = Dict{String,Vector{Dict{String,Any}}}()
    for proposal in values(archive)
        push!(get!(by_stratum, proposal["stratum"], Dict{String,Any}[]),
            proposal)
    end
    acquisitions = Dict{String,Any}[]
    for stratum in sort!(collect(keys(by_stratum)))
        items = by_stratum[stratum]
        sort!(items; by = _pcrfp_quality_v8)
        append!(acquisitions, first(items,
            min(elites_per_structural_stratum, length(items))))
    end
    sort!(acquisitions; by = proposal ->
        (proposal["stratum"], _pcrfp_quality_v8(proposal)))
    length(acquisitions) > maximum_graph_elites &&
        (acquisitions = first(acquisitions, maximum_graph_elites))
    contract_by_id = Dict(contract.id => contract for contract in contracts)
    spec_by_key = Dict(_pcrfp_key_v8(spec) => spec for spec in specs)
    records = Dict{String,Any}[]
    for acquisition in acquisitions
        contract = contract_by_id[acquisition["contract_id"]]
        spec = spec_by_key[acquisition["spec_key"]]
        candidate = _pcrfp_instantiate_v8(structural[acquisition["spec_key"]],
            acquisition["features"], contract)
        result = _profile_coupled_rfp_result(
            ProfileCoupledRFPScreenV1(contract;
                allowed_contracts = contracts), candidate)
        push!(records, Dict{String,Any}(
            "contract_id" => contract.id, "design_id" => candidate.design_id,
            "physics_hash" => candidate.physics_hash,
            "family" => "reversed_field_pinch",
            "mechanism" => spec.mechanism,
            "target_count" => spec.target_count,
            "descriptor" => acquisition["descriptor"],
            "genome" => candidate.normalized,
            "acquisition" => acquisition, "evaluation" => result,
            "all_five_gates_passed" => result["all_five_gates_passed"],
            "positive_net_power_closure_passed" =>
                result["positive_net_power_closure_passed"],
            "promoted" => result["all_five_gates_passed"] === true &&
                result["positive_net_power_closure_passed"] === true))
    end
    sort!(records; by = record -> (
        record["promoted"] === true ? 0 : 1,
        _pcrfp_quality_v8(Dict(
            "nominal" => record["evaluation"]["nominal"],
            "features" => record["acquisition"]["features"])),
        record["physics_hash"]))
    Dict{String,Any}(
        "algorithm" =>
            "21D Halton acquisition plus profile-stratified failure-aware MAP-Elites",
        "random_seed" => random_seed,
        "acquisition_samples" => acquisition_samples,
        "contract_count" => length(contracts),
        "contracts" => [_oe_contract_dict(contract) for contract in contracts],
        "topology_count_per_contract" => length(specs),
        "structural_stratum_count" => length(strata),
        "topologies" => [Dict("family" => "reversed_field_pinch",
            "mechanism" => spec.mechanism,
            "target_count" => spec.target_count) for spec in specs],
        "profile_parameterization" => Dict(
            "model" => "force_free_alpha_theta0_cylindrical_base",
            "theta0_range" => [1.25, 2.75],
            "alpha_range" => [1.05, 8.0],
            "projection_steps" => 96,
            "F_and_Theta_are_independent_genes" => false),
        "acquisition_archive_cell_count" => length(archive),
        "acquisition_profile_domain_pass_count" => profile_domain_pass,
        "acquisition_positive_net_count" => positive_net,
        "acquisition_nominal_physics_and_engineering_pass_count" => nominal_pass,
        "explicit_graph_elite_count" => length(records),
        "explicit_graph_five_gate_pass_count" =>
            count(record -> record["all_five_gates_passed"] === true, records),
        "explicit_graph_positive_net_count" => count(record ->
            record["positive_net_power_closure_passed"] === true, records),
        "promotion_count" => count(record -> record["promoted"] === true,
            records),
        "records" => records,
        "claim_boundary" => _PROFILE_COUPLED_RFP_CLAIM_BOUNDARY)
end
