using JSON3
using SHA
using FusionConceptAI

const PROJECT_ROOT_UJ55 = normpath(joinpath(@__DIR__, ".."))
include(joinpath(PROJECT_ROOT_UJ55, "test", "unified_judgment_fixture_factory_v55.jl"))

iter = representative_judgment_fixture_v55(:iter)
c2w = representative_judgment_fixture_v55(:c2w)
relabeled = deepcopy(iter)
relabeled["family"] = "deliberately_wrong_family"
relabeled["parent_family"] = "deliberately_wrong_parent"
relabeled["display_label"] = "label erasure control"

archive = evaluate_all_search_results_v55([iter, c2w])
iter_result = archive["results"][1]
c2w_result = archive["results"][2]
relabeled_result = evaluate_uniform_judgment_v55(relabeled)

full_log_path = joinpath(PROJECT_ROOT_UJ55, "reports",
    "full_test_uniform_judgment_v55_20260822.log")
function summarize_full_regression_v55(log_path::AbstractString)
    isfile(log_path) || return Dict{String,Any}("status" => "not_run")
    test_groups = 0
    passed = 0
    total = 0
    log_text = read(log_path, String)
    for line in split(log_text, '\n')
        parsed = match(r"\|\s+(\d+)\s+(\d+)\s+", line)
        parsed === nothing && continue
        test_groups += 1
        passed += parse(Int, parsed.captures[1])
        total += parse(Int, parsed.captures[2])
    end
    explicit_exit = get(ENV, "FCAI_FULL_TEST_EXIT_CODE", "not_supplied")
    exit_zero = explicit_exit == "0"
    return Dict{String,Any}(
        "status" => exit_zero && passed == total ? "pass" : "fail",
        "test_groups" => test_groups,
        "passed" => passed,
        "total" => total,
        "exit_code" => exit_zero ? 0 : explicit_exit,
        "exit_code_source" => "FCAI_FULL_TEST_EXIT_CODE supplied by the completed full-suite invocation",
        "log_path" => relpath(log_path, PROJECT_ROOT_UJ55),
        "log_sha256" => bytes2hex(sha256(read(log_path))),
    )
end
full_regression = summarize_full_regression_v55(full_log_path)

report = Dict{String,Any}(
    "report_id" => "uniform_fusion_judgment_regression_v55_20260822",
    "generated_on" => "2026-08-22",
    "chain_id" => "uniform_fusion_judgment_chain_v55",
    "stage_order" => collect(UNIFIED_JUDGMENT_STAGE_IDS_V55),
    "archive" => archive,
    "reference_contract_regression" => Dict(
        "iter_decision" => iter_result["decision"],
        "c2w_decision" => c2w_result["decision"],
        "iter_all_eight_stages_pass" => iter_result["passed_stage_count"] == 8,
        "c2w_all_eight_stages_pass" => c2w_result["passed_stage_count"] == 8,
        "labels_do_not_change_routing_hash" =>
            relabeled_result["routing_input_hash"] == iter_result["routing_input_hash"],
        "labels_do_not_change_stage_results" =>
            relabeled_result["stages"] == iter_result["stages"],
        "family_or_parent_routed_count" =>
            archive["summary"]["family_or_parent_routed_count"],
        "promotion_authorized_count" =>
            archive["summary"]["promotion_authorized_count"],
    ),
    "full_repository_regression" => full_regression,
    "fixture_scope" =>
        "Representative contract fixtures, not independent device validation or reactor promotion evidence",
    "implementation_files" => Any[
        "src/search/unified_judgment_chain_v55.jl",
        "schemas/uniform_fusion_judgment_candidate_v55.schema.json",
        "schemas/uniform_fusion_judgment_report_v55.schema.json",
        "test/unified_judgment_chain_v55.jl",
    ],
)

report["report_hash"] = bytes2hex(sha256(JSON3.write(report)))
output_path = joinpath(PROJECT_ROOT_UJ55, "reports",
    "uniform_fusion_judgment_regression_v55_20260822.json")
open(output_path, "w") do io
    JSON3.pretty(io, report)
    write(io, '\n')
end
println(JSON3.write(Dict(
    "output_path" => output_path,
    "report_hash" => report["report_hash"],
    "iter_decision" => iter_result["decision"],
    "c2w_decision" => c2w_result["decision"],
    "family_or_parent_routed_count" => archive["summary"]["family_or_parent_routed_count"],
)))
