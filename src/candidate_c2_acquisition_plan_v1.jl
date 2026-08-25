const _C2_LONGITUDINAL_BATCH_INPUTS_V1 = Dict{String,Vector{String}}(
    "s3_01_state_species_scales" => [
        "initial:fuel_a_inventory", "initial:fuel_b_inventory",
        "initial:electron_inventory", "initial:ion_thermal_energy",
        "initial:electron_thermal_energy", "parameter:charge_a",
        "parameter:charge_b", "parameter:particle_scale",
        "parameter:energy_scale", "parameter:particle_rate_scale",
        "parameter:power_scale", "parameter:fuel_fraction_a",
        "parameter:fuel_fraction_b", "parameter:exhaust_fraction_a",
        "parameter:exhaust_fraction_b"],
    "s3_02_physical_closure" => [
        "parameter:particle_transport_a_s", "parameter:particle_transport_b_s",
        "parameter:ion_energy_loss_s", "parameter:electron_energy_loss_s",
        "parameter:reaction_coefficient_per_particle_s", "parameter:reaction_energy_j",
        "parameter:alpha_ion_fraction", "parameter:alpha_electron_fraction",
        "parameter:radiation_coefficient_per_particle_s",
        "parameter:ion_electron_exchange_rate_s"],
    "s3_03_actuator_delivery" => [
        "initial:fueling_output", "initial:ion_heating_output",
        "initial:electron_heating_output", "initial:exhaust_output",
        "initial:radiation_control_output", "parameter:fueling_capacity_s",
        "parameter:ion_heating_capacity_w", "parameter:electron_heating_capacity_w",
        "parameter:exhaust_capacity_s", "parameter:radiation_control_capacity_w",
        "parameter:fueling_baseline_s", "parameter:ion_heating_baseline_w",
        "parameter:electron_heating_baseline_w", "parameter:exhaust_baseline_s",
        "parameter:radiation_control_baseline_w",
        "parameter:ion_heating_deposition_efficiency",
        "parameter:electron_heating_deposition_efficiency"],
    "s3_04_control_power_targets" => [
        "parameter:target_particle_inventory", "parameter:target_ion_energy_j",
        "parameter:target_electron_energy_j", "parameter:fueling_controller_gain_s",
        "parameter:ion_heating_controller_gain_s",
        "parameter:electron_heating_controller_gain_s",
        "parameter:exhaust_controller_gain_s", "parameter:radiation_controller_gain_s",
        "parameter:fueling_wall_energy_j_per_particle",
        "parameter:exhaust_wall_energy_j_per_particle",
        "parameter:ion_heating_wall_plug_efficiency",
        "parameter:electron_heating_wall_plug_efficiency",
        "parameter:radiation_control_wall_plug_efficiency",
        "parameter:electric_conversion_efficiency"])

const _C2_ACQUISITION_PREREQUISITES_V1 = Dict{String,Vector{String}}(
    "s3_01_state_species_scales" => String[],
    "s3_02_physical_closure" => ["s3_01_state_species_scales"],
    "s3_03_actuator_delivery" => ["s3_01_state_species_scales"],
    "s3_04_control_power_targets" =>
        ["s3_02_physical_closure", "s3_03_actuator_delivery"],
    "s3_05_v68_execution" => ["s3_04_control_power_targets"],
    "s4_01_operator_inputs" => ["s3_01_state_species_scales"],
    "s4_02_operator_execution_audit" =>
        ["s3_05_v68_execution", "s4_01_operator_inputs"],
    "s5_01_engineering_evidence" =>
        ["s3_05_v68_execution", "s4_02_operator_execution_audit"],
    "s6_01_independent_evidence" =>
        ["s3_05_v68_execution", "s4_02_operator_execution_audit"],
    "c2_01_recompute_and_aggregate" =>
        ["s5_01_engineering_evidence", "s6_01_independent_evidence"])

const _C2_LONGITUDINAL_CAPABILITY_REPLACEMENTS_V1 = Dict{String,String}(
    "initial:fuel_a_inventory" => "runtime_species_state",
    "initial:fuel_b_inventory" => "runtime_species_state",
    "initial:electron_inventory" => "runtime_species_state",
    "initial:ion_thermal_energy" => "runtime_species_state",
    "initial:electron_thermal_energy" => "runtime_species_state",
    "parameter:charge_a" => "runtime_species_state",
    "parameter:charge_b" => "runtime_species_state",
    "parameter:particle_scale" => "runtime_species_state",
    "parameter:energy_scale" => "runtime_species_state",
    "parameter:reaction_coefficient_per_particle_s" =>
        "candidate_reaction_bremsstrahlung",
    "parameter:reaction_energy_j" => "candidate_reaction_bremsstrahlung",
    "parameter:radiation_coefficient_per_particle_s" =>
        "candidate_reaction_bremsstrahlung",
    "parameter:particle_transport_a_s" => "candidate_transport_response",
    "parameter:particle_transport_b_s" => "candidate_transport_response",
    "parameter:ion_energy_loss_s" => "candidate_transport_response",
    "parameter:electron_energy_loss_s" => "candidate_transport_response")

struct CandidateC2AcquisitionBatchV1
    batch_id::String
    prerequisite_batch_ids::Vector{String}
    longitudinal_input_ids::Vector{String}
    stage4_operator_ids::Vector{String}
    stage4_input_ids::Vector{String}
    evidence_actions::Vector{String}
    status::Symbol
    batch_hash::String
end

struct CandidateC2AcquisitionPlanV1
    schema_version::String
    candidate_binding_hash::String
    state_package_hash::String
    shared_state_result_hash::Union{Nothing,String}
    longitudinal_readiness_hash::String
    stage4_compilation_hash::String
    status::Symbol
    batches::Vector{CandidateC2AcquisitionBatchV1}
    outstanding_longitudinal_input_ids::Vector{String}
    outstanding_stage4_operator_ids::Vector{String}
    outstanding_stage4_input_ids::Vector{String}
    outstanding_c2_evidence_gate_ids::Vector{String}
    plan_hash::String
end

function _c2_acquisition_batch_v1(batch_id::String;
        longitudinal_input_ids::Vector{String} = String[],
        stage4_operator_ids::Vector{String} = String[],
        stage4_input_ids::Vector{String} = String[],
        evidence_actions::Vector{String} = String[])
    longitudinal = sort!(unique(copy(longitudinal_input_ids)))
    operators = sort!(unique(copy(stage4_operator_ids)))
    stage4_inputs = sort!(unique(copy(stage4_input_ids)))
    actions = sort!(unique(copy(evidence_actions)))
    prerequisites = copy(_C2_ACQUISITION_PREREQUISITES_V1[batch_id])
    status = isempty(longitudinal) && isempty(operators) && isempty(stage4_inputs) &&
        isempty(actions) ? :complete : :acquire
    core = Dict{String,Any}("batch_id" => batch_id,
        "prerequisite_batch_ids" => prerequisites,
        "longitudinal_input_ids" => longitudinal,
        "stage4_operator_ids" => operators, "stage4_input_ids" => stage4_inputs,
        "evidence_actions" => actions, "status" => String(status))
    return CandidateC2AcquisitionBatchV1(batch_id, prerequisites, longitudinal,
        operators, stage4_inputs, actions, status, canonical_hash(core))
end

function _c2_stage4_operator_state_v1(operator_id::String,
        compilation::AbstractDict)
    for (key, status) in (("passed_operator_ids", :pass),
            ("failed_operator_ids", :fail), ("unknown_operator_ids", :unknown),
            ("missing_evidence_operator_ids", :missing),
            ("unsupported_operator_ids", :unsupported))
        operator_id in String.(get(compilation, key, Any[])) && return status
    end
    return :missing
end

"Compile the shortest candidate-bound Stage-3/4 acquisition DAG without label routing."
function compile_candidate_c2_acquisition_plan_v1(
        readiness::CandidateLongitudinalInputReadinessV1,
        stage4_compilation::AbstractDict;
        shared_state_result_hash::Union{Nothing,AbstractString} = nothing,
        current_c2_decision::Union{Nothing,C2DecisionEnvelope} = nothing,
        registry::Vector{StabilityCapabilityContractV2} =
            default_stability_capability_registry_v2())
    stage4_binding = String(stage4_compilation["candidate_binding_hash"])
    stage4_binding == readiness.candidate_binding_hash || throw(ArgumentError(
        "longitudinal and Stage-4 candidate bindings differ"))
    shared_state = shared_state_result_hash === nothing ? nothing :
        _c2_check_hash_v1(String(shared_state_result_hash), "shared v68 state result hash")
    requirements = Dict(item.input_id => item for item in readiness.requirements)
    mapped = reduce(vcat, values(_C2_LONGITUDINAL_BATCH_INPUTS_V1); init = String[])
    length(mapped) == length(unique(mapped)) || error(
        "longitudinal acquisition batches contain duplicate input IDs")
    Set(mapped) == Set(keys(requirements)) || error(
        "longitudinal acquisition batches do not cover the exact readiness contract")

    batches = CandidateC2AcquisitionBatchV1[]
    for batch_id in ("s3_01_state_species_scales", "s3_02_physical_closure",
            "s3_03_actuator_delivery", "s3_04_control_power_targets")
        outstanding = String[id for id in _C2_LONGITUDINAL_BATCH_INPUTS_V1[batch_id]
            if requirements[id].evidence_status != :complete]
        actions = String[]
        for id in outstanding
            status = requirements[id].evidence_status
            if haskey(_C2_LONGITUDINAL_CAPABILITY_REPLACEMENTS_V1, id)
                push!(actions, "bind_candidate_capability:$(
                    _C2_LONGITUDINAL_CAPABILITY_REPLACEMENTS_V1[id]):$id")
                continue
            end
            prefix = status == :partial ? "complete_input_evidence" :
                status == :unsupported ? "replace_unsupported_input" :
                "acquire_candidate_bound_input"
            push!(actions, "$prefix:$id")
        end
        push!(batches, _c2_acquisition_batch_v1(batch_id;
            longitudinal_input_ids = outstanding, evidence_actions = actions))
    end

    contracts = Dict(item.operator_id => item for item in registry)
    evidence_by_operator = Dict{String,AbstractDict}()
    for raw in get(stage4_compilation, "evidence", Any[])
        evidence_by_operator[String(raw["operator_id"])] = raw
    end
    required_operators = sort!(String.(stage4_compilation["required_operator_ids"]))
    incomplete_operators = String[]
    missing_stage4_inputs = String[]
    execution_actions = String[]
    for operator_id in required_operators
        haskey(contracts, operator_id) || continue
        status = _c2_stage4_operator_state_v1(operator_id, stage4_compilation)
        state_mismatch = shared_state !== nothing &&
            haskey(evidence_by_operator, operator_id) &&
            String(get(evidence_by_operator[operator_id], "state_result_hash", "")) !=
                shared_state
        state_mismatch && (status = :unknown)
        status in (:pass, :fail) && continue
        push!(incomplete_operators, operator_id)
        contract = contracts[operator_id]
        covered = haskey(evidence_by_operator, operator_id) && !state_mismatch ?
            String.(get(evidence_by_operator[operator_id], "covered_input_ids", Any[])) :
            String[]
        append!(missing_stage4_inputs, setdiff(contract.required_input_ids, covered))
        if status == :unsupported
            push!(execution_actions, "provide_capability_or_repair_context:$operator_id")
        elseif state_mismatch
            push!(execution_actions,
                "recompute_stability_operator_on_shared_state:$operator_id:$shared_state")
        elseif status == :unknown
            append!(execution_actions, String.(get(evidence_by_operator[operator_id],
                "evidence_tasks", Any[])))
            push!(execution_actions, "complete_stability_evidence:$operator_id")
        else
            append!(execution_actions, [
                "evaluate_stability_operator:$operator_id",
                "bind_candidate_state:$operator_id",
                "record_signed_margin:$operator_id",
                "record_convergence_history:$operator_id",
                "verify_resolution:$operator_id",
                "verify_validity_domain:$operator_id",
                "seal_source_provenance:$operator_id"])
        end
    end
    missing_stage4_inputs = sort!(unique(missing_stage4_inputs))
    stage4_input_actions = ["acquire_candidate_bound_stage4_input:$id"
        for id in missing_stage4_inputs]
    push!(batches, _c2_acquisition_batch_v1("s4_01_operator_inputs";
        stage4_operator_ids = incomplete_operators,
        stage4_input_ids = missing_stage4_inputs,
        evidence_actions = stage4_input_actions))
    outstanding_longitudinal = sort!(String[item.input_id for item in
        readiness.requirements if item.evidence_status != :complete])
    v68_actions = isempty(outstanding_longitudinal) ? String[] : [
        "execute_candidate_bound_v68_after_input_completion",
        "seal_shared_state_result_hash_for_stage4"]
    push!(batches, _c2_acquisition_batch_v1("s3_05_v68_execution";
        evidence_actions = v68_actions))
    push!(batches, _c2_acquisition_batch_v1("s4_02_operator_execution_audit";
        stage4_operator_ids = incomplete_operators,
        evidence_actions = execution_actions))

    gate_by_id = current_c2_decision === nothing ? Dict{String,C2GateDecisionV1}() :
        Dict(gate.gate_id => gate for gate in current_c2_decision.gate_decisions)
    downstream_gate_tasks = Dict(
        "engineering" => ["complete_candidate_bound_engineering_constraints"],
        "independent_evidence" => ["complete_candidate_bound_independent_residual_audit",
            "complete_candidate_bound_uncertainty_interval"])
    outstanding_c2_gates = String[]
    for (batch_id, gate_id) in (("s5_01_engineering_evidence", "engineering"),
            ("s6_01_independent_evidence", "independent_evidence"))
        gate = get(gate_by_id, gate_id, nothing)
        complete = gate !== nothing && gate.completeness == :complete &&
            gate.conclusion in (:pass, :fail)
        actions = complete ? String[] : gate === nothing ? downstream_gate_tasks[gate_id] :
            isempty(gate.evidence_tasks) ? downstream_gate_tasks[gate_id] :
            copy(gate.evidence_tasks)
        complete || push!(outstanding_c2_gates, gate_id)
        push!(batches, _c2_acquisition_batch_v1(batch_id;
            evidence_actions = actions))
    end
    final_actions = String[]
    isempty(incomplete_operators) || append!(final_actions,
        ["recompile_candidate_bound_stage4_on_shared_v68_state"])
    if !isempty(outstanding_longitudinal) || !isempty(incomplete_operators) ||
            !isempty(outstanding_c2_gates)
        push!(final_actions, "compile_uniform_c2_decision_envelope")
    end
    push!(batches, _c2_acquisition_batch_v1("c2_01_recompute_and_aggregate";
        evidence_actions = final_actions))

    status = isempty(outstanding_longitudinal) && isempty(incomplete_operators) &&
        isempty(outstanding_c2_gates) ?
        :ready_for_c2_aggregation : :acquisition_required
    stage4_hash = String(stage4_compilation["compilation_hash"])
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => readiness.candidate_binding_hash,
        "state_package_hash" => readiness.state_package_hash,
        "shared_state_result_hash" => shared_state,
        "longitudinal_readiness_hash" => readiness.readiness_hash,
        "stage4_compilation_hash" => stage4_hash, "status" => String(status),
        "batch_hashes" => getfield.(batches, :batch_hash),
        "outstanding_longitudinal_input_ids" => outstanding_longitudinal,
        "outstanding_stage4_operator_ids" => sort!(unique(incomplete_operators)),
        "outstanding_stage4_input_ids" => missing_stage4_inputs,
        "outstanding_c2_evidence_gate_ids" => sort!(unique(outstanding_c2_gates)))
    return CandidateC2AcquisitionPlanV1("1.0.0", readiness.candidate_binding_hash,
        readiness.state_package_hash, shared_state, readiness.readiness_hash,
        stage4_hash, status,
        batches, outstanding_longitudinal, sort!(unique(incomplete_operators)),
        missing_stage4_inputs, sort!(unique(outstanding_c2_gates)), canonical_hash(core))
end

function candidate_c2_acquisition_plan_to_dict_v1(plan::CandidateC2AcquisitionPlanV1)
    batches = [Dict{String,Any}("batch_id" => item.batch_id,
        "prerequisite_batch_ids" => item.prerequisite_batch_ids,
        "longitudinal_input_ids" => item.longitudinal_input_ids,
        "stage4_operator_ids" => item.stage4_operator_ids,
        "stage4_input_ids" => item.stage4_input_ids,
        "evidence_actions" => item.evidence_actions, "status" => String(item.status),
        "batch_hash" => item.batch_hash) for item in plan.batches]
    return Dict{String,Any}("schema_version" => plan.schema_version,
        "candidate_binding_hash" => plan.candidate_binding_hash,
        "state_package_hash" => plan.state_package_hash,
        "shared_state_result_hash" => plan.shared_state_result_hash,
        "longitudinal_readiness_hash" => plan.longitudinal_readiness_hash,
        "stage4_compilation_hash" => plan.stage4_compilation_hash,
        "status" => String(plan.status), "batches" => batches,
        "outstanding_longitudinal_input_ids" =>
            plan.outstanding_longitudinal_input_ids,
        "outstanding_stage4_operator_ids" => plan.outstanding_stage4_operator_ids,
        "outstanding_stage4_input_ids" => plan.outstanding_stage4_input_ids,
        "outstanding_c2_evidence_gate_ids" =>
            plan.outstanding_c2_evidence_gate_ids,
        "plan_hash" => plan.plan_hash)
end
