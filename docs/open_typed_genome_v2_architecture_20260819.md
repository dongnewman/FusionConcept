# Open Typed Genome 2.0 架构与编译合同

状态：评审后设计规范；取代 OTG 1.0 作为实现依据，但保留 v1 文档和历史产物  
日期：2026-08-19  
上位架构：`docs/open_world_fusion_discovery_architecture_v2_20260819.md`

## 1. v2 目标

OTG 2.0 是“候选物理 + 认识论缺口 + 证据权限 + 失败作用域”的统一类型语言。它不只是描述一个装置长什么样，还必须让系统回答：

- 声称的机制由哪些域、变量、相互作用和边界构成；
- 哪些是已知、测量、推导、学习、假设或未知；
- 哪些规则能够检查，哪些规则库尚未覆盖；
- 哪个观测能检测、区分并识别该机制；
- 应通过解析、数值、现有数据、实验还是研发任务取得证据；
- 一条证据最多允许支持到哪个 gate、任务和参数域；
- 一个失败到底否定参数、策略、闭合、机制、拓扑还是数值方法；
- 两个不同写法是否结构等价、语义等价或仅行为接近。

## 2. 顶层对象

```text
OpenWorldGenomeV2
├─ schema_version
├─ identity
├─ provenance
├─ mission_contracts[]
├─ governance_policy_ref
├─ spacetime_support
├─ domains[]
├─ populations[]
├─ state_variables[]
├─ interactions[]
├─ boundaries[]
├─ reservoirs[]
├─ invariants[]
├─ actuators[]
├─ sensors[]
├─ controls[]
├─ observables[]
├─ predictions[]
├─ engineering_objects[]
├─ hazards[]
├─ applicability_claims[]
├─ unknowns[]
├─ evidence_obligation_graph
├─ promotion_scopes[]
├─ classifications[]
├─ equivalence_claims[]
└─ extensions{}
```

`family` 不存在于核心 required 字段。历史分类只允许存入 `classifications[]`，并强制 `non_routing=true`。

## 3. 核心身份与谱系

### 3.1 `identity`

```text
identity
├─ design_id
├─ revision_id
├─ parent_revision_ids[]
├─ topology_skeleton_id
├─ model_choice_id
├─ parameter_instance_id
└─ human_label
```

候选被拆为三层：

1. `topology_skeleton`：域、接口、能量/物质路径和时序事件；
2. `model_and_closure_choice`：算子、闭合与近似；
3. `parameter_and_control_instance`：连续参数、初值和控制策略。

任何评估或失败都必须绑定具体层级，不能只绑定显示名称。

### 3.2 五层哈希

```text
identity_hash
structural_hash
semantic_normal_form_hash
behavioral_signature_hash
evaluation_hash
```

- `identity_hash` 保留原始来源和谱系；
- `structural_hash` 消除 ID、顺序和图同构差异；
- `semantic_normal_form_hash` 处理可证明的单位、坐标、变量、gauge、边界和算子等价；
- `behavioral_signature_hash` 在标准干预集上计算响应签名；
- `evaluation_hash` 加入 ruleset、mission、evidence plan、solver、coupling、data 和 calibration 版本。

旧 `physics_hash` 作为 migration alias 保存，不再被当作完整物理等价证明。

### 3.3 `equivalence_claims[]`

```text
EquivalenceClaim
├─ subject_ids[]
├─ status
│  ├─ proven_equivalent
│  ├─ possibly_equivalent
│  ├─ behaviorally_close
│  ├─ proven_distinct
│  └─ equivalence_unresolved
├─ transformation_or_intervention_set
├─ proof_or_evidence_refs[]
├─ validity_domain
└─ uncertainty
```

只有 `proven_equivalent` 可自动合并语义档案；行为接近不能共享候选特定晋级证据。

## 4. 物理值、声明和认识论状态

### 4.1 Typed value

每个值必须声明：

- scalar/vector/tensor/field/distribution/event/graph/random variable；
- SI 维度向量、单位和规范化参考；
- domain、坐标图、基底和张量变换；
- 时间语义和采样语义；
- value/interval/distribution/function/symbol/unknown；
- 参数边界和不确定性；
- 来源、校准域和 promotion scope 引用。

### 4.2 Epistemic state

```text
derived
measured
declared_known
hypothesized
learned
empirical_prior
unknown_placeholder
not_applicable
```

`partial_operator` 不是 epistemic state，而是 operator 表示形态。一个 partial operator 可以是 `hypothesized`，也可以是 `unknown_placeholder`。

### 4.3 Assessment status

```text
pass
fail
unknown
unsupported
not_applicable
```

每个状态必须同时给出 `assessment_scope`、`ruleset_hash`、`evidence_refs`、`promotion_scope_ref` 和 `failure_scope`（如适用）。

## 5. 时空、域与边界超图

沿用 v1 的开放表示：

- 空间维数、时间维数和多个坐标图；
- 固定、移动、形变、周期重映射和拓扑事件边界；
- 任意数量的 plasma/vacuum/material/radiation/circuit/environment domain；
- domain-domain、domain-environment、domain-actuator 关系及 hyperedge；
- 拓扑描述符是编译或求解输出，不是 schema 入口许可条件。

v2 新增：

- `interface_conservation_accounts[]`；
- `event_and_rollback_semantics`；
- `domain_birth_death_events[]`；
- `coordinate_equivalence_claims[]`；
- `topology_event_observables[]`。

## 6. Interaction 与 Operator

### 6.1 Interaction

```text
InteractionV2
├─ interaction_id
├─ role_annotations[]
├─ inputs[] / outputs[]
├─ affected_domains[]
├─ operator_spec
├─ parameter_specs[]
├─ assumptions[]
├─ validity_claims[]
├─ conservation_effects[]
├─ symmetry_claims[]
├─ timescale_claims[]
├─ observable_links[]
├─ epistemic_state
├─ unknown_refs[]
├─ promotion_scope_ref
├─ failure_scope_options[]
└─ provenance
```

`role_annotations` 为开放注解，不形成固定层或路由。

### 6.2 Operator 形态

```text
equation_set
known_operator_ref
program
learned_operator
partial_operator
```

### 6.3 `partial_operator` v2 最小合同

```text
PartialOperatorV2
├─ inputs[] / outputs[]
├─ domain_and_time_scope
├─ dimension_signature
├─ causal_direction
├─ allowed_conservation_effects[]
├─ forbidden_conservation_effects[]
├─ parameter_bounds{}
├─ scale_bounds{}
├─ symmetry_or_limit_constraints[]
├─ null_models[]
├─ alternative_models[]
├─ identifiability_conditions[]
├─ minimum_effect_size
├─ noise_and_numerical_floor
├─ complexity_budget
├─ out_of_sample_prediction_refs[]
├─ failure_scope_options[]
├─ safety_limits[]
├─ completion_routes[]
└─ promotion_scope_ref
```

`minimum_effect_size` 必须与数值误差和传感器噪声同量纲比较。`complexity_budget` 至少限制自由参数、自由函数、非局部记忆长度和可调用子算子数。

### 6.4 Completion routes

允许的补全路径：

- first-principles derivation；
- symmetry/conservation constrained symbolic inference；
- data-driven identification；
- analytic bound without full equation；
- discriminating experiment；
- diagnostic development；
- unresolved R&D task。

任何 learned/symbolic 结果都必须保留训练集、候选函数库、复杂度选择、留出集和 OOD 范围。

## 7. Null、替代模型和可辨识性

### 7.1 `ModelDiscriminationContract`

```text
ModelDiscriminationContract
├─ target_interaction_id
├─ null_model_refs[]
├─ alternative_model_refs[]
├─ interventions[]
├─ observable_refs[]
├─ expected_signatures{}
├─ minimum_effect_size
├─ noise_model
├─ numerical_error_model
├─ identifiability_metric
├─ decision_thresholds[]
├─ blind_or_holdout_partition
└─ failure_interpretation
```

### 7.2 C0.3 机器状态

```text
detectability_status
distinguishability_status
identifiability_status
```

三者均为五态。mandatory 的三项必须全部 pass，候选才可完成 C0；无法检测、无法区分或无法识别的机制仍可保留在 draft archive，但不能进入正式 C0 档案。进入 C1 前也不得保留任何 C1 mandatory unknown。

## 8. Unknown 与 Obligation

### 8.1 `UnknownRecord`

```text
UnknownRecord
├─ unknown_id
├─ subject_refs[]
├─ kind
│  ├─ missing_equation
│  ├─ missing_closure
│  ├─ missing_parameter
│  ├─ missing_boundary
│  ├─ missing_conservation_path
│  ├─ missing_observable
│  ├─ missing_solver
│  ├─ missing_experiment
│  └─ ruleset_coverage_gap
├─ impact_scope
├─ risk_class
└─ obligation_refs[]
```

### 8.2 `EvidenceObligationGraph`

```text
EvidenceObligationV2
├─ obligation_id
├─ unknown_refs[]
├─ level: C0 | C1 | C2 | C3
├─ activation_predicate
├─ assessment_scope
├─ mandatory_for_missions[]
├─ required_data_products[]
├─ acceptable_evidence_classes[]
├─ discrimination_requirement
├─ calibration_requirements[]
├─ uncertainty_requirement
├─ promotion_scope_required
├─ failure_scope_options[]
├─ applicability_proof_ref
├─ dependencies[]
├─ resolution_value
├─ status
├─ evidence_refs[]
├─ next_action_refs[]
└─ termination_conditions[]
```

同一 evidence 可支持多个义务，但必须记录共享相关性；不得把共享数据当作独立复现。

## 9. PhysicsRuleManifest 与 Coverage

OTG schema 不内嵌所有物理规则。Genome 通过以下引用绑定评估环境：

```text
governance_policy_ref
required_ruleset_refs[]
rule_coverage_requirement
```

### 9.1 `PhysicsRuleManifest`

字段至少包括：rule ID/version、activation predicate、assumptions、check mode、I/O、pass/fail 条件、生成义务、failure scope、证据要求、regression fixtures 和 promotion scope ceiling。

### 9.2 `RuleCoverageManifest`

字段至少包括：ruleset hash、已覆盖/部分覆盖/未覆盖的 domain/operator/scale/boundary/material 状态、只能生成义务的区域、known blind spots 和 fixture coverage。

`ruleset_coverage_gap` 必须成为 unknown record，而不是被忽略。

## 10. Applicability 与证明

### 10.1 `ApplicabilityClaim`

```text
ApplicabilityClaim
├─ subject_ref
├─ required_dimensionless_ranges{}
├─ geometry_requirements[]
├─ scale_and_ordering_assumptions[]
├─ temporal_assumptions[]
├─ boundary_requirements[]
├─ excluded_regimes[]
├─ evidence_refs[]
└─ status
```

### 10.2 `ApplicabilityProof`

任何 `not_applicable` 绑定：predicate version、evaluated inputs、evidence refs、validity domain、uncertainty 和 reproduction trace。

无法证明不适用时，状态保持 unknown，不得人工跳过。

## 11. PromotionScope

```text
PromotionScope
├─ scope_id
├─ max_gate: none | C0 | C1 | C2 | C3
├─ valid_missions[]
├─ valid_domains[]
├─ valid_parameter_ranges{}
├─ valid_observables[]
├─ calibration_refs[]
├─ required_ruleset_hash
├─ independent_confirmation_required
└─ expiry_or_version
```

规则：

- 证据最终权限为所有上游 scope 的交集；
- 任何缺失字段按更窄范围解释；
- empirical prior 和未留出 learned operator 为 `max_gate=none`；
- scope 不能通过人工覆写扩大，只能新增证据对象；
- 过期或 ruleset 不匹配时自动降级为 unknown/evidence refresh obligation。

## 12. FailureScope

```text
FailureRecord
├─ failure_id
├─ failed_obligation_ids[]
├─ scope_type
│  ├─ parameter_instance
│  ├─ parameter_region
│  ├─ control_policy
│  ├─ closure_model
│  ├─ interaction_hypothesis
│  ├─ topology_skeleton
│  ├─ mission_contract
│  ├─ numerical_method
│  └─ coupling_contract
├─ scope_refs[]
├─ excluded_alternatives[]
├─ tuning_budget_consumed
├─ evidence_refs[]
├─ ruleset_hash
└─ escalation_conditions[]
```

Failure scope 只允许从小到大升级，且每次升级必须有额外证据与预定义条件。

## 13. Evidence Acquisition 对象

### 13.1 `EvidenceRequest`

定义目标义务、可接受证据类型、所需判别力、不确定性、有效域、安全和预算。

### 13.2 Capability manifests

```text
SolverCapabilityManifest
ExperimentCapabilityManifest
DiagnosticCapabilityManifest
AnalyticCapabilityManifest
DataSourceCapabilityManifest
```

共有字段：supported request predicates、assumptions、outputs、VVUQ status、validity domain、cost model、safety envelope、provenance。

### 13.3 `EvidenceAcquisitionPlan`

记录 selected routes、依赖、expected information gain、cost、decision thresholds、fallback 和 stop conditions。

证据规划器可推荐路线，但物理 gate 仍由 obligation 状态决定，不能用信息增益分数覆盖失败。

## 14. SolverRequest 与 CouplingContract

### 14.1 `SolverRequestV2`

- equation/operator classes；
- domain/boundary graph；
- steady/transient/event/DAE；
- scale、stiffness、multi-rate；
- required fidelity 和 error targets；
- conservation diagnostics；
- required data products；
- admissible/prohibited approximations；
- budget and reproducibility requirements。

### 14.2 `CouplingContract`

```text
CouplingContract
├─ participants[]
├─ exchanged_variables[]
├─ interface_geometry
├─ units_basis_coordinates
├─ temporal_semantics
├─ interpolation_extrapolation
├─ synchronization_policy
├─ event_rollback_semantics
├─ algebraic_loop_strategy
├─ interface_conservation_accounts[]
├─ duplicate_flux_prevention
├─ convergence_test
├─ local_error_budgets[]
├─ global_error_budget
├─ known_instability_conditions[]
└─ regression_fixtures[]
```

`composed_match` 只有在 CouplingContract 可满足时成立；否则为 `coupling_unsupported`。

## 15. 工程下界 Preflight 对象

```text
EngineeringBoundCheck
├─ bound_id / version
├─ activation_predicate
├─ quantity_and_units
├─ analytic_or_empirical_bound
├─ valid_domain
├─ assumptions[]
├─ evaluated_parameter_region
├─ result
├─ failure_scope_ceiling
├─ evidence_refs[]
└─ promotion_scope: none
```

Preflight 只排除有严格界限支持的参数实例/区域；不替代 C2 工程模型，也不为候选提供通过信用。

## 16. 搜索元数据

Genome 中只保存搜索谱系和预算，不保存一个可覆盖物理门的总 fitness：

```text
SearchMetadata
├─ generator_id / version
├─ parent_ids[]
├─ mutation_trace[]
├─ archive_descriptor
├─ pareto_dimensions{}
├─ novelty_status
├─ expected_information_gain
├─ estimated_evidence_cost
├─ minimum_tuning_budget
├─ tuning_budget_consumed
├─ neutrality_quota_class
└─ semantic_duplicate_risk
```

novelty、证据成熟度、成本和可证伪强度保持独立维度。

## 17. Mission Contract v2

任务合同新增：

- `claim_ceiling`；
- `mandatory_ruleset_refs[]`；
- `required_promotion_scope`；
- `required_independent_confirmation`；
- `allowed_evidence_classes[]`；
- `minimum_tuning_budget_policy`；
- `engineering_preflight_policy`；
- `prohibited_claims[]`。

降低净输出要求必须创建新的 mission revision，不能覆写原合同。

## 18. 外部数据适配

OTG 表示候选原生物理和证据义务；外部数据通过 adapter 对接：

- `IMASAdapterManifest`：已知聚变实验/模拟数据；
- `OpenPMDAdapterManifest`：网格场和粒子数据；
- `FMIAdapterManifest`：模型封装和执行接口；
- 自定义实验/诊断 schema。

Adapter 必须声明单位、坐标、时间、缺失字段、信息损失和 provenance；不得以外部格式的 family 假设改变 OTG 路由。

## 19. Schema 拆分建议

新增而不覆盖 v1：

- `schemas/open_world_genome_v2.schema.json`
- `schemas/typed_value_v2.schema.json`
- `schemas/partial_operator_v2.schema.json`
- `schemas/model_discrimination_contract_v1.schema.json`
- `schemas/unknown_record_v1.schema.json`
- `schemas/evidence_obligation_graph_v2.schema.json`
- `schemas/physics_rule_manifest_v1.schema.json`
- `schemas/rule_coverage_manifest_v1.schema.json`
- `schemas/applicability_proof_v1.schema.json`
- `schemas/promotion_scope_v1.schema.json`
- `schemas/failure_record_v1.schema.json`
- `schemas/evidence_request_v1.schema.json`
- `schemas/evidence_capability_manifest_v1.schema.json`
- `schemas/evidence_acquisition_plan_v1.schema.json`
- `schemas/coupling_contract_v1.schema.json`
- `schemas/engineering_bound_check_v1.schema.json`
- `schemas/mission_contract_v2.schema.json`

## 20. Julia 模块建议

- `src/open_world_genome_v2.jl`
- `src/semantic_normalization.jl`
- `src/partial_operator_v2.jl`
- `src/trusted_physics_kernel.jl`
- `src/physics_rule_registry.jl`
- `src/rule_coverage.jl`
- `src/model_discrimination.jl`
- `src/evidence_obligation_graph_v2.jl`
- `src/evidence_acquisition_planner.jl`
- `src/promotion_scope.jl`
- `src/failure_scope.jl`
- `src/coupling_contract.jl`
- `src/engineering_lower_bounds.jl`

## 21. 最小正负夹具

### 正夹具

1. 时变开放—闭合多域、周期拓扑事件；
2. 移动边界脉冲、无磁约束；
3. 自组织 + 主动控制 + 未知饱和闭合；
4. 静电—惯性接力与直接能量转换；
5. 多储库、选择性粒子通道和事件边界。

### 负夹具

1. 能量储库缺失；
2. 形式正确但无 null/alternative/identifiability；
3. minimum effect 小于数值和测量噪声；
4. 用数值发散宣称拓扑失败；
5. 两个守恒模块通过但耦合接口重复计算通量；
6. empirical prior 试图越权到 C1；
7. family 改名导致 solver route 改变；
8. 规则库未覆盖但报告“无物理矛盾”。

部分夹具应保存为盲测，开发期间不可见期望标签。

## 22. OTG 2.0 硬验收

- family 删除、重命名或伪装不改变编译和证据计划；
- partial operator 必须通过 detectability/distinguishability/identifiability；
- ruleset coverage gap 成为 unknown，不成为 pass；
- promotion scope 不允许跨 mission/domain/parameter/gate；
- fail 必须绑定最小 failure scope；
- parameter instance fail 不自动升级为 topology fail；
- composed solver 必须绑定 CouplingContract；
- unknown 与 obligation 通过 ID 关联且无重复状态源；
- empirical prior 的 max gate 为 none；
- 工程 preflight 无晋级权；
- 五层身份可以区分同构、语义等价和行为接近；
- 旧 Genome/OTG v1 可单向迁移且历史 hash 保留；
- 每份报告绑定 ruleset、coverage、mission、evidence、evaluation hash。
