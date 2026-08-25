# FusionConceptAI 开放世界聚变发现系统架构 v2

状态：评审后架构基线；取代 v1 作为后续实现依据，但不修改或删除 v1  
日期：2026-08-19  
配套规范：`docs/open_typed_genome_v2_architecture_20260819.md`  
实施计划：`docs/open_world_fusion_discovery_project_plan_v2_20260819.md`

## 1. v2 的核心调整

v1 的研究方向继续保留：可表达性开放、晋级信用封闭、family 非路由、未知与失败分离、C0-C3 非补偿门控。v2 不推倒重来，而是解决 v1 仍偏“完整平台蓝图”、缺少最小可信纵切片的问题。

本版做出九项实质调整：

1. 将万级开放搜索后移，先闭合三个人工候选的真实 C0/C1 评估链；
2. 在 Typed Genome 与义务图之间加入 `Trusted Physics Compilation Kernel`；
3. 新增 `PhysicsRuleManifest` 和 `RuleCoverageManifest`，显式报告规则库未覆盖的未知未知；
4. 将 Solver Router 扩展为 `Evidence Acquisition Planner`；
5. 为多求解器/多模型组合新增正式 `CouplingContract`；
6. 提高 `partial_operator` 的 C0 可辨识性门槛；
7. 将布尔 `promotion_authority` 升级为带任务、域、参数和 gate 作用域的 `PromotionScope`；
8. 新增 `FailureScope`、`ApplicabilityProof`、语义等价层和早期工程下界检查；
9. 正式冻结搜索档案的 Pareto 替换、最低调参预算和证据预算分配规则。

PLRMR 仍只是演示/回归夹具。ITER、C-2W、ICF、开放边界与材料模块只用于模块覆盖、校准和中立性回归，不定义合法装置空间。

## 2. 系统能够承诺什么

系统不能承诺自动识别任何未知基本物理是否真实。v2 的可审计结论格式是：

> 在规则集 R、规则覆盖域 D、证据版本 E、任务合同 M 和计算/实验预算 B 下，候选的义务状态为 S；系统未发现哪些矛盾、发现了哪些失败、还有哪些未知以及下一条可获取证据路径。

系统不得输出无边界结论“该候选不存在物理矛盾”。

系统承诺：

- family、名称、历史知名度不参与物理路由；
- 陌生机制可以被表示、编译和生成证据任务；
- 没有求解器不等于物理失败；
- 没有证据不等于通过；
- 一个参数实例、控制策略或闭合失败不会自动扩大为拓扑失败；
- 任意晋级结论都有适用域、证据范围和版本上限；
- 相同物理、相同预算、相同证据条件下的候选接受相同规则。

## 3. v2 总体架构

```text
Mission Contract + Governance Policy
                ↓
Open Typed Genome 2.0
                ↓
Trusted Physics Compilation Kernel
  ├─ PhysicsRuleManifest[]
  ├─ RuleCoverageManifest
  ├─ 类型 / 单位 / 张量 / 坐标
  ├─ 因果 / 自由度 / DAE / 初边值完整性
  ├─ 守恒 / 储库 / 接口账本
  ├─ detectability / distinguishability / identifiability
  └─ 早期工程下界 Preflight
                ↓
Evidence Obligation Graph
                ↓
Evidence Acquisition Planner
  ├─ 解析证明 / 符号界限
  ├─ 单求解器 / Solver Portfolio
  ├─ 现有实验数据
  ├─ 新判别实验 / Testbed
  ├─ 诊断系统研发
  └─ 求解器 / 模型研发任务
                ↓
Execution + Coupling Layer
  ├─ SolverCapabilityManifest
  ├─ ExperimentCapabilityManifest
  ├─ CouplingContract
  ├─ 标准数据产品
  └─ 资源、安全、回滚与可重放
                ↓
Verification / Validation / UQ / OOD
                ↓
C0 → C1 → C2 → C3
非补偿 + PromotionScope + FailureScope
                ↓
Archive Pareto Selection + Budget Allocation
                ↓
Generator / Human / AI / Symbolic Discovery
```

与 v1 最大的流程差异是：生成器在可信评估链之后才获得规模化预算。早期只保留极简变异器作为接口测试，不建立正式大档案。

## 4. Trusted Physics Compilation Kernel

### 4.1 目标

可信内核不是一套“万能物理方程”，而是版本化规则执行与覆盖声明系统。它负责：

- 判断哪些检查能静态完成；
- 将无法自动判定的内容转为符号、数值、实验或专家义务；
- 记录规则的假设、适用域和失败作用范围；
- 显式报告规则库没覆盖什么；
- 禁止以规则缺失为候选通过依据。

### 4.2 `PhysicsRuleManifest`

```text
PhysicsRuleManifest
├─ rule_id / version
├─ rule_class
├─ activation_predicate
├─ assumptions[]
├─ check_mode
│  ├─ static
│  ├─ symbolic
│  ├─ numerical
│  ├─ experimental
│  └─ expert_review
├─ inputs[] / outputs[]
├─ generated_obligations[]
├─ pass_conditions[]
├─ failure_scope_options[]
├─ evidence_requirements[]
├─ applicability_proof_requirements[]
├─ regression_fixtures[]
├─ promotion_scope_ceiling
└─ provenance
```

规则类别至少包括：类型量纲、自由度/方程数、因果与代数环、初边值完整性、守恒、热力学、反应通道、模型适用性、可观测性、数值可信度和工程下界。

### 4.3 `RuleCoverageManifest`

```text
RuleCoverageManifest
├─ ruleset_id / hash
├─ covered_domains[]
├─ covered_operator_classes[]
├─ covered_scale_ranges{}
├─ covered_boundary_classes[]
├─ covered_material_states[]
├─ partially_covered_regions[]
├─ uncovered_regions[]
├─ obligation_only_regions[]
├─ known_rule_interactions[]
├─ known_blind_spots[]
└─ fixture_coverage{}
```

每份评估报告必须绑定 ruleset hash 和 coverage manifest。`RuleCoverageManifest` 不仅列已覆盖内容，还要列“只能生成义务、不能自动判定”的区域。

### 4.4 `ApplicabilityProof`

`not_applicable` 必须引用可重放证明对象：

```text
ApplicabilityProof
├─ obligation_id
├─ predicate_id / version
├─ evaluated_inputs{}
├─ evidence_refs[]
├─ result
├─ validity_domain
├─ uncertainty
└─ reproduction_command_or_trace
```

人工备注不能单独把 mandatory 项改成 `not_applicable`。

## 5. 更严格的部分机制合同

`partial_operator` 是算子形态；`hypothesized` 和 `unknown_placeholder` 是认识论状态，三者不再混用。

一个没有完整方程的机制要通过 C0，除输入、输出、单位、作用域、守恒影响、尺度、可观测后果和失败上限外，还必须声明：

- `null_models[]`：零效应模型；
- `alternative_models[]`：至少一个竞争解释；
- `identifiability_conditions[]`：需要何种干预和观测才能区分；
- `minimum_effect_size`：效应须超过数值误差与测量噪声；
- `complexity_budget`：限制自由函数、参数和记忆长度；
- `parameter_bounds{}`：禁止无界参数吸收残差；
- `failure_scope_options[]`：失败可能否定到哪一层；
- `out_of_sample_prediction`：至少一个未用于补全机制的预测义务。

C0.3 拆分为：

- `C0.3a detectability`：效应在原则上可被测到；
- `C0.3b distinguishability`：可区别于空模型和竞争模型；
- `C0.3c identifiability`：在给定干预/观测下，参数或结构能被约束到预定精度。

形式正确但没有实际判别力的叙述只能得到 `unformalized_or_unidentifiable`，不能进入 C1。

## 6. Evidence Obligation Graph

`unknowns[]` 与 obligation ledger 明确分工：

- `unknowns[]`：记录认识论缺口是什么、影响哪些声明；
- `EvidenceObligationGraph`：记录消解缺口需要什么动作、依赖、资源和通过条件；
- 二者通过 `unknown_id` 关联，不能重复存储互相冲突的状态。

义务节点新增：

- `assessment_scope`；
- `failure_scope_options`；
- `promotion_scope_required`；
- `evidence_route_options`；
- `resolution_value`：消解该义务可减少多少关键不确定性；
- `termination_conditions`；
- `applicability_proof_ref`。

义务图允许多个证据路径指向同一问题，也允许一次实验同时消解多个义务，但必须防止同一数据重复计作独立证据。

## 7. Evidence Acquisition Planner

### 7.1 为什么不能只有 Solver Router

真正新机制的最便宜证伪方式可能是解析界限、现有数据或小型判别实验，而不是开发完整求解器。因此 v2 使用统一证据规划器，solver router 是其中一个子路由。

### 7.2 核心对象

```text
EvidenceRequest
├─ question / target_obligations[]
├─ admissible_evidence_classes[]
├─ required_discrimination_power
├─ required_uncertainty
├─ validity_domain
├─ safety_constraints[]
├─ budget_limits{}
└─ deadline_or_priority

EvidenceCapabilityManifest
├─ capability_id / type
├─ supported_requests[]
├─ assumptions[]
├─ outputs[]
├─ VVUQ_status
├─ validity_domain
├─ cost_model
├─ safety_envelope
└─ provenance

EvidenceAcquisitionPlan
├─ selected_routes[]
├─ route_dependencies[]
├─ expected_information_gain
├─ expected_total_cost
├─ decision_thresholds[]
├─ fallback_routes[]
└─ stop_conditions[]
```

证据能力类型：

- analytic proof / symbolic bound；
- numerical simulation；
- reduced model / surrogate；
- existing experimental data；
- new discriminating experiment；
- diagnostic development；
- solver/testbed R&D；
- expert review，仅能生成或确认义务，不能替代候选特定硬证据。

### 7.3 `unsupported` 细分

- `computationally_unsupported`；
- `experimentally_unsupported`；
- `diagnostically_unobservable`；
- `evidence_route_over_budget`；
- `capability_domain_mismatch`；
- `coupling_unsupported`；
- `evidence_route_unknown`。

这些状态都阻止相应 gate 晋级，但不等同于物理失败。

## 8. Execution 与 `CouplingContract`

### 8.1 单模块能力

Solver/experiment capability 必须给出 context of use、验证状态、校准域、误差模型、输出合同和已知失败域。verification、validation 与 UQ 分开报告；这与 ASME VVUQ 的术语边界一致（[ASME VVUQ](https://www.asme.org/codes-standards/publications-information/verification-validation-uncertainty)）。

### 8.2 多模块耦合合同

```text
CouplingContract
├─ coupling_id / version
├─ participants[]
├─ exchanged_variables[]
├─ interface_geometry
├─ units / basis / coordinates
├─ temporal_semantics
├─ interpolation / extrapolation
├─ synchronization_policy
├─ event / rollback semantics
├─ algebraic_loop_strategy
├─ interface_conservation_accounts[]
├─ duplicate_flux_prevention
├─ coupling_convergence_test
├─ local_error_budgets[]
├─ global_error_budget
├─ known_instability_conditions[]
└─ regression_fixtures[]
```

两个分别验证过的模块只有在耦合收敛、接口守恒和全局误差通过后，组合结果才可能获得晋级范围。FMI 可作为模型封装与协同仿真接口参考，但其规范明确说明 co-simulation algorithm 本身不由 FMI 定义，因此不能替代本项目的耦合算法与可信度合同（[FMI 3.0.2](https://fmi-standard.org/docs/3.0.2/)）。

### 8.3 标准数据产品适配

- OTG 是候选与义务表示，不替代外部科学数据标准；
- 将 IMAS 作为聚变实验/模拟数据的适配目标，尤其用于已知模块 anchor；ITER 已在 2025-12 发布开源 IMAS 基础设施和一批物理模型（[ITER 官方公告](https://www.iter.org/node/20687/release-imas-infrastructure-and-physics-models-open-source)）；
- 网格场和粒子数据优先提供 openPMD adapter；openPMD 为 mesh/particle 数据提供文件格式无关的元数据约定，可使用 HDF5、ADIOS 等后端（[openPMD 官方说明](https://www.openpmd.org/)）；
- 任何 adapter 都不改变 OTG 的 family-neutral 编译语义。

## 9. PromotionScope 与 FailureScope

### 9.1 `PromotionScope`

布尔 `promotion_authority` 废弃为兼容字段。正式对象：

```text
PromotionScope
├─ max_gate: none | C0 | C1 | C2 | C3
├─ valid_missions[]
├─ valid_domains[]
├─ valid_parameter_ranges{}
├─ valid_observables[]
├─ required_calibration_refs[]
├─ required_ruleset_hash
├─ independent_confirmation_required
└─ expiry_or_version
```

默认上限：

- empirical prior：`max_gate=none`，只能生成先验/任务；
- 未留出的 learned operator：`none`；
- 经过模块级留出验证的模型：最多 C1，且只限声明域；
- 候选特定实验：按其观测、工况和校准域授予 C1/C2 范围；
- C3 任务必须有整机任务合同下的候选特定闭合证据。

### 9.2 `FailureScope`

每个 `fail` 必须选择最小有证据支持的作用范围：

```text
parameter_instance
parameter_region
control_policy
closure_model
interaction_hypothesis
topology_skeleton
mission_contract
numerical_method
coupling_contract
```

只有覆盖参数域、替代闭合和规定最低调参预算后，失败才可扩大到 topology skeleton。数值方法失败不能自动升级为物理机制失败。

## 10. 哈希、等价与去重

v2 使用五层身份：

1. `identity_hash`：原始声明、谱系与来源；
2. `structural_hash`：消除节点改名、顺序和图同构；
3. `semantic_normal_form_hash`：处理可证明的单位、坐标、变量、gauge、边界和算子等价；
4. `behavioral_signature_hash`：标准干预下的响应签名，用于发现近似等价；
5. `evaluation_hash`：上述身份 + ruleset、mission、solver、coupling、data、calibration 和配置版本。

v1 `physics_hash` 保留为迁移字段，映射到 v2 的 structural/semantic bundle，不再单独承担全部等价判断。

无法证明等价时不得强行合并，使用：

- `possibly_equivalent`；
- `behaviorally_close`；
- `equivalence_unresolved`。

行为接近不等于机制相同，也不等于两者可共享晋级证据。

## 11. 早期工程下界 Preflight

v2 不把 `F0` 当作门级。`fidelity` 只是模型/证据的分辨率元数据；C0-C3 是声明成熟度门。新增无晋级权的 `Engineering Lower-Bound Preflight`：

- 磁场能量和 Maxwell 应力数量级；
- 电流密度与最小导体/储能规模；
- 脉冲功率、压缩速度和状态方程范围；
- 热流密度与最小散热面积；
- 驱动带宽、延迟、饱和和能量来源；
- 诊断时空分辨率与 minimum effect size；
- 真空、电击穿、绝缘和几何占据下界。

Preflight 结果：

- `bound_satisfied`；
- `parameter_instance_excluded`；
- `parameter_region_excluded`；
- `bound_inconclusive`；
- `model_out_of_scope`。

只有数学界限覆盖整个声明参数域时，才可在相应范围形成 fail；其余结果用于节省预算，不提供晋级信用，也不替代 C2 工程闭合。

## 12. C0-C3 v2

### C0：形式化、可检测、可区分、可编译

- C0.0 schema/引用/版本/哈希；
- C0.1 类型、单位、域、接口和因果；
- C0.2 源汇/储库/守恒账本或明确 residual obligation；
- C0.3a detectability；
- C0.3b distinguishability；
- C0.3c identifiability；
- C0.4 ruleset compilation、coverage 与 evidence plan；
- C0.5 engineering lower-bound preflight。

C0 允许未知控制方程，但不允许空洞、不可辨识或无界占位符。通过仅表示“值得进入受控求证”。

### C1：原始机制与第一条真实证据路径

- 候选原生场/粒子/流体/辐射/回路/事件问题的适用解；
- 一个真实解析、数值或实验路径；
- code/solution verification；
- 关键守恒、边界、时间尺度和 minimum effect；
- 负控制与留出预测；
- 明确 failure scope 与 promotion scope；
- mandatory unknown/unsupported 为零。

### C2：多域耦合物理闭合

- 平衡或适用瞬态；
- 粒子/核素/荷电/能量/动量/场能联合账本；
- 稳定性或受控不稳定；
- 输运、反应、辐射、损失；
- CouplingContract 收敛、接口守恒和误差传播；
- model validation、UQ、OOD；
- 工程载荷与材料域的最低可信闭合。

### C3：任务与整机闭合

- 完整功率/能量、燃料、热排出和废物账本；
- 控制、传感、扰动、故障和安全；
- 材料寿命、维护和可用率；
- 任务指定的科学增益/工程增益/净电要求；
- 候选特定证据、保守不确定性和独立确认。

### 旧 C4 的迁移

旧体系 C4 的独立跨代码、held-out known-device validation 和 uncertainty calibration 不再是所有候选排在 C3 之后的单独门。它们拆为：

- C1-C3 对应模型的 VVUQ 前置义务；
- 高声明等级的 `independent_confirmation_required`；
- C3 报告的 `confirmation_status` 修饰符。

因此不存在“先 C3 通过，之后才检查模型是否校准”的漏洞。

## 13. 搜索、替换与预算规则

### 13.1 候选三层身份

```text
topology_skeleton
→ model_and_closure_choice
→ continuous_parameters_and_control_policy
```

失败必须标注发生在哪一层。每个 topology skeleton 在允许 topology fail 前，必须获得预先冻结的最低闭合替代与参数优化预算。

### 13.2 硬资格门

进入正式档案必须满足：

```text
U0 hard rules pass
AND C0 mandatory pass
AND no unexplained type/conservation contradiction
AND ruleset coverage is reported
```

### 13.3 档案内 Pareto 替换

不合成物理总分。每个行为单元保留 Pareto 前沿：

- 行为/物理新颖度；
- 预期信息增益；
- 可证伪预测强度；
- unresolved high-risk obligations；
- 预计评估成本；
- 当前证据成熟度；
- 语义重复风险。

已失败候选进入 falsification archive，不与待评估候选竞争晋级预算，但可用于反例学习。

### 13.4 预算分配

```text
minimum archive coverage budget
+ expected information gain / estimated total cost
+ neutrality quota
+ minimum topology tuning budget
+ blind-fixture reserve
```

“相同预算”改为“相同复杂度和证据目标下的公平机会”。昂贵候选可以得到更多绝对资源，但必须证明单位成本的信息价值且不能挤占中立性配额。

## 14. 中立性与盲测

保留 v1 的 label scramble、family erase、graph isomorphism、counterfactual family、leave-topology-out、solver/fidelity/unknown parity，并新增：

- ruleset coverage parity；
- evidence route parity；
- promotion scope leak test；
- failure scope escalation test；
- semantic equivalence test；
- minimum tuning adequacy test；
- coupled conservation regression；
- blind fixture false-promotion/false-rejection test。

盲测夹具的期望结果应由独立维护者或封存哈希控制；开发过程中不可使用其标签调参。

## 15. 决策质量指标

除覆盖率、唯一 hash、C0 可编译率外，正式发布必须报告：

- `C0_to_C1_resolution_yield`；
- `cost_per_resolved_obligation`；
- `information_gain_per_compute`；
- `false_promotion_rate`；
- `false_rejection_rate`；
- `solver_routing_precision`；
- `evidence_route_success_rate`；
- `semantic_duplicate_rate`；
- `next_action_usefulness`；
- `parameter_tuning_adequacy`；
- `blind_fixture_performance`；
- `scope_escalation_error_rate`。

这些指标用于评估发现系统，而不是给候选物理表现打统一分。

## 16. v2 最小可信发布定义

`OpenWorld Discovery v0.1` 只有满足以下条件才可发布：

1. OTG v2 最小 schema、规则 manifest、coverage manifest 和 obligation graph 可用；
2. 三个无 family 的人工候选完成静态编译；
3. 至少一个通用 ODE/DAE/event 路径或现有真实求解器被执行；
4. 每个候选都有 detectability/distinguishability/identifiability 结果；
5. 至少一个负控制被正确拒绝且 failure scope 正确；
6. 至少一个 unsupported 候选获得非数值证据路径或研发任务；
7. family/label 擦除不改变编译和证据计划；
8. promotion scope、ruleset coverage 和未解义务随报告发布；
9. 没有启动正式万级搜索；
10. 声明上限仅为“可信链闭合到 C1”，不宣称发现可行反应堆。

## 17. 评审建议处置摘要

| 评审建议 | v2 处置 |
|---|---|
| 万级搜索后移 | 采纳；评估链和纵切片优先 |
| 可信物理规则内核 | 采纳；新增 rule/coverage manifest |
| 提高 partial operator 门槛 | 采纳；增加三类可辨识门 |
| Evidence Acquisition Planner | 采纳；替代单一 solver-first 流程 |
| CouplingContract | 采纳 |
| Pareto 替换与预算 | 采纳并冻结规则 |
| 多层语义哈希 | 采纳；扩展为五层身份 |
| promotion scope | 采纳；布尔字段废弃 |
| failure scope | 采纳；要求最小证据作用范围 |
| 早期工程下界 | 采纳；定义为无晋级权 Preflight |
| F0 术语冲突 | 采纳；Fidelity 与 C gate 分离，不再设 F0 gate |
| 旧 C4 迁移 | 采纳；拆入各层 VVUQ 与独立确认修饰符 |
| IMAS/openPMD/FMI 对接 | 采纳为 adapter/reference，不改变 OTG 核心 |
| 立即实现全部 learned/OOD/QD | 暂缓；纵切片完成后再推进 |

