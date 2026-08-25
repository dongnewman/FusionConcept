# FusionConceptAI 本周进展、重构后多拓扑统一物理搜索至 C2 总架构

日期：2026-08-25  
统计区间：2026-08-19 至 2026-08-25  
项目实质根目录：`D:\006-Programing\LMC\outputs\fusion_concept_ai`

## 0. 一句话结论

本周完成的核心变化不是“又增加了几个装置家族”，而是把系统从按既有装置标签组织的搜索，重构为：**先生成不带 family 路由的物理拓扑图，再按区域、边界、时间语义、守恒账户、算子和能力合同编译统一物理问题，随后让每个候选经过同一条八阶段判定链，并用候选绑定、哈希密封、可复算的证据逐步推进到 C2。**

目前已经具备十万结构 seed 的流式拓扑搜索、万级候选统一判定、候选绑定的非线性残差图、0D/1D/2D/3D/稳态/瞬态/index-1 DAE 的有限通用 Stage 3 运行时、实体部件编译、有限细丝磁场与低保真粒子/功率/工程筛选。**目前仍没有任何真实新候选完成完整 C2，也没有物理晋级、净电闭合、工程可建造或机制原创性结论。**

---

## 1. 本周我们做了什么

### 1.1 8 月 19 日：冻结开放世界 v2 架构，明确“表达开放、晋级封闭”

完成了开放世界聚变发现架构 v2、Open Typed Genome 2.0 和实施计划：

- 将 `family`、装置名、历史知名度降为非路由元数据；
- 建立 `Trusted Physics Compilation Kernel`、`PhysicsRuleManifest`、`RuleCoverageManifest`；
- 将未知问题编译成 `Evidence Obligation Graph`，由 `Evidence Acquisition Planner` 选择解析、数值、实验、诊断或求解器研发路径；
- 引入 `PromotionScope` 和 `FailureScope`，禁止把一个参数实例、一个控制策略或一个数值方法的失败扩大成整个拓扑失败；
- 建立 structural / semantic / behavioral / evaluation 等多层身份与哈希；
- 将 C0–C3 定义为非补偿证据成熟度，而不是可互相抵消的总分；
- 明确“更简单、更稳定、产出更高”必须保留为不同维度，不能压成单一代理分数。

主要基线：

- [开放世界架构 v2](open_world_fusion_discovery_architecture_v2_20260819.md)
- [Open Typed Genome 2.0](open_typed_genome_v2_architecture_20260819.md)
- [开放世界实施计划 v2](open_world_fusion_discovery_project_plan_v2_20260819.md)

同日还完成了 PLRMR 阶段的候选实现与交互演示。它是候选/数据产品/界面纵切片，不是后续统一架构的物理主证据。

### 1.2 8 月 21 日：把 v2 从蓝图变成可信纵切片

实现了 OTG v2 最小内核、可信规则编译、规则覆盖、适用性证明、工程下界、失败/晋级作用域、数值验证、UQ/OOD 和证据规划对象。三个人工候选走过同一条无 family 的 C0/C1 链，负控制和 unsupported 路径能保持各自语义。

同时实现开放世界搜索纵切片和能力路由：

- 候选可以声明未知或部分算子，但必须给出可检测、可区分、可识别合同；
- 没有匹配能力时返回 `unsupported`，不投影成某个已知装置；
- 一份证据不能因改名或改变 family 标签而改变路由和结论；
- 证据规划优先解决最有信息价值的未知，而不是盲目扩大候选数。

### 1.3 8 月 22 日：统一八阶段判定链，完成第一轮 10,000 候选全量执行

v55 固定了所有候选都必须经过的八阶段链：

1. 物理描述完整性；
2. 拓扑与因果；
3. 守恒与状态演化；
4. 扰动与稳定性；
5. 粒子/能量输运与燃烧；
6. 净能量闭合；
7. 工程可实现性；
8. 不确定性与证据。

装置之间只能在“阶段内部需要哪些物理算子”上不同，不能走不同的总判定链。`family`、`parent_family`、显示名和分类名均不能进入路由哈希。

v56 对 10,000 个候选、1,000 个拓扑、每拓扑 10 个样本执行了完整八阶段判定：

| 指标 | 结果 |
|---|---:|
| 请求 / 实际评估 | 10,000 / 10,000 |
| 丢弃候选 | 0 |
| `pass` | 0 |
| `fail` | 2,660 |
| `unknown` | 7,340 |
| family/parent 路由 | 0 |
| 晋级 | 0 |

2,660 个失败只是否定“未声明控制器的候选实例”；其余候选在 Stage 3–8 缺候选绑定数值/VVUQ 证据，因此保持 unknown。这个结果证明统一判定链真实执行，不证明候选物理闭合。

详见 [v55 统一判定链](unified_fusion_judgment_chain_v55_20260822.md) 和 [v56 全量报告](../reports/candidate_bound_full_search_v56_20260822.md)。

### 1.4 8 月 22–24 日：从“判定合同”推进到候选绑定求解、工程、厂辅和外部证据

这一段形成 v57–v67 的连续运行时演进：

| 版本 | 本周新增能力 | 全量结果的正确解释 |
|---|---|---|
| v57 | `CandidateSolveManifestV1`、候选绑定求解结果、守恒审计、solver-hash 功率账本 | 9,790 unknown、210 unsupported；无物理晋级 |
| v58 | 将数值收敛与执行器/工程实现分开；显式补给和辅助功率需求 | 9,790 Stage 3/5 低阶数值 pass，但 Stage 6/7 全部 unknown |
| v59 | 区域耦合、执行器容量和完整厂级功率角色 | 3,620 个候选实例执行器容量失败；6,380 unknown；净功率未闭合 |
| v60 | region-first 代表门 | 74/74 因缺区域/接口证据而 unsupported，正确阻止无意义的全量运行 |
| v61 | 显式有限体积区域、界面、区域执行器与 `[32,64]` 收敛 | 10,000 区域数值门通过，但后续独立物理门仍决定结论 |
| v62 | 状态反馈反应/辐射/执行器、Stage 4–8 producer 合同 | 6,429 fail、3,571 unknown；工程、净能量、独立证据仍未闭合 |
| v63 | 有限导体、结构、热工水力、失超/故障的工程代表门 | 74 个代表中工程数值 13 pass / 61 fail；仍无整体晋级 |
| v64 | 四分片万级厂辅/净功率下界运行 | 9,727 fail、273 unknown；9,040 个负净功率区间或 incomplete role，不是完备反应堆结论 |
| v65 | 两代码独立复算与候选绑定实验锚点队列 | 5 个候选入队，0 个完成双代码与校准实验锚点 |
| v66 | 稳态/瞬态/脉冲时间语义和 pulsed-RHD 输入合同 | Stage 8 外部输入 ready 为 0；不使用默认 EOS/opacity 填洞 |
| v67 | 外部证据资源按能力、适用域、哈希和独立组匹配 | 10,000/10,000 执行；Stage 8 resource-ready 为 0；0 晋级 |

v67 的 10,000 候选结果为 9,549 fail、451 unknown。资源状态为 390 个 `unknown_candidate_input_incomplete` 和 9,610 个 `unsupported_provider_capability_gap`。这里的 provider gap 是资源/能力缺口，不是对候选物理的否定。

### 1.5 8 月 24–25 日：实现 v68 非线性残差图和统一 C2 决策协议

v68 将此前线性 L1 区域状态、后处理反应/辐射/执行器的分散逻辑重构成候选绑定残差图：

- 每个状态方程只有一个 governing residual producer，可有多个 additive physics block；
- 明确 state、residual、Jacobian、mass matrix、region、dimension、time mode、boundary 和接口通量；
- 使用 `(1-λ)R_L1 + λR_full` 同伦，L1 只允许作初值、诊断基线和同伦起点；
- 参考后端包含尺度归一、守界线搜索、稀疏块装配、阻尼 Newton–Krylov 和 index-1 DAE 瞬态回退；
- 解析 Jacobian 与方向有限差分交叉检查；
- 解后执行独立残差复算、守恒、接口通量、状态界限、执行器和分辨率趋势审计；
- `unsupported`、`unknown`、`fail`、`pass` 保持严格语义。

随后建立统一 C2 状态包与决策信封：

- 粒子、离子能、电子能、物种、四类执行器、完整功率账本和证据使用同一字段；
- `completeness`、`candidate_conclusion`、`narrow_failures`、`terminate` 四件事分开；
- 一个必要条件可形成候选装配级终止失败，但不能自动否定基础边界、替代线圈语法或替代稳定机制；
- closed/open 只作为边界能力数据，不选择不同的 C2 汇总逻辑。

两条真实候选装配链已经进入同一 C2 汇总：

- closed pool-24：32 线圈装配 normalized Bn RMS `0.065081 > 0.01`，形成该装配的工程必要条件硬失败；
- open low-force：声明的 minimum-B 必要算子得到局部场强鞍点，形成该双线圈装配的 Stage 4 硬失败；
- closed pool-56 与 open high-ratio：仍为 incomplete/unknown，等待候选输入和 Stage 4 证据。

这两项是“真实装配级窄失败”，不是完整 C2 pass，也不是整个拓扑家族被否定。详见 [v68 残差图](candidate_residual_graph_runtime_v68.md)、[C2 决策运行时](c2_decision_runtime_v1.md) 和 [C2 前沿汇总](../reports/candidate_c2_reach_summary_v1_20260825.md)。

### 1.6 8 月 25 日：图原生多拓扑搜索、十万结构流式执行和实体装置层

#### v69：图原生拓扑

候选原始对象变成 `GraphNativeTopologyV69`，由区域、状态槽、代数约束、边界、端口、接口、依赖和义务构成。当前生成 grammar 为：

- 1–4 个区域；
- 每区维度从 0D/1D/2D/3D 中选择；
- 每区时间语义从 steady/transient/DAE 中选择；
- 每区边界为 closed/open/mixed；
- 对 particle、ion energy、electron energy、species、charge 建立守恒账户；
- 显式 field source、energy source、heat rejection、actuator、sensor 和 1–3 级 control 端口；
- 对称性为 none/reflection/rotational/helical；
- 强制 conservation、causal、validity、boundary、evidence 五类义务。

10,000 个 raw topology 中 9,090 个通过唯一拓扑编译。报告中的 2 个 `complete_c2` 是制造的协议控制样例，`complete_c2_pass=0`，不能当成真实候选。

#### v70：Stage 3 通用运行时和十万结构流式搜索

v70 将结构循环和数值循环分开，并加入确定性采样、预算、原子缓存、checkpoint、resume、内容寻址 evidence store 和独立平衡审计。原生能力覆盖：

- 0D 非线性稳态；
- 隐式 source-loss ODE；
- index-1 DAE 一致初始化与时间步复核；
- 1D/2D/3D 结构化保守扩散/反应，1D 保守平流；
- 多区域配对通量；
- sensor-controller-actuator 稳定/容量审计；
- 有限 mixed 0D–1D block coupling。

十万结构运行结果：

| 指标 | 结果 |
|---|---:|
| 原始结构 seed | 100,000 |
| 唯一结构同构哈希 | 99,873 |
| 重复结构 | 127 |
| 唯一 evidence hash | 1,000 |
| Stage 3 manufactured complete/pass evidence | 1,000 |
| QD 单元 | 768 |
| 未捕获异常 | 0 |
| 墙钟 | 973.138 s |

这里的 1,000 个 complete/pass evidence 来自制造的通用平衡 probe，证明执行与证据链，不代表 1,000 个真实装置完成 Stage 3。winner seed `73792` 也只是一个四区域计算职责图，不能外推成约束、点火、净功率或工程闭合。

#### v71–v80：从抽象图重新接回候选绑定实体部件与场线搜索

v71 将图端口编译成候选实体部件，建立：有限线圈/真空边界/注入/燃料排气/冷却/执行器/传感器/控制器 → Biot–Savart → Boris 粒子 → Bosch–Hale D-T 0D 功率 → 电流密度/磁应力/排热下界的低保真链。

- v71 的线性 seed 98 曾通过 6/6 低保真门，但 v72 的乐观开放场碰撞约束上界只有所需 `τE` 的 `0.61656`，因此已形成 `complete/fail` 并退出活动前沿；
- 当前走得最远的实体候选是环形 seed 35：v71 低保真 screen pass，但 v72 因缺闭合场/非局域输运能力为 `incomplete/unsupported`；
- v73 增加闭合场 RK4 场线、旋转变换和乐观曲率漂移淘汰门；
- v74–v76 增加环向基场线圈、螺旋扰动线圈、排热和运行点细化；
- v77–v78 对螺旋电流比例、径向尺度等进行局部场面搜索；
- v79 增加有界多谐波相位、径向/垂向谐波和电流不平衡；
- v80 进一步改为 3–8 个独立模块，每模块独立相位、电流符号、螺旋度、周期、半径与有界谐波，并对所有候选执行相同的快速场/工程筛选，再对 shortlist 执行相同的 4/8 圈场线门。

截至本文写作时，v74–v80 都有运行档案，但尚未产生新物理 survivor：

| 分支 | 已执行范围 | 当前最好结果 |
|---|---:|---|
| v74 | 64 个增强螺旋变体 | 43 个场线逃逸；3 个 closed-field unknown；选定记录仍为场线逃逸 fail |
| v75/v76 | 热排出与目标增益运行点细化 | 分别为装配筛选 fail、过大场面径向偏移 fail |
| v77 | 局部离散螺旋搜索并做 8 圈复核 | seed 170 不逃逸，但最小 `|ι|=0.01686 < 0.02`，fail |
| v78 | 连续局部 99 点细化并做 8 圈复核 | 最小 `|ι|=0.01638 < 0.02`，fail |
| v79 | 128 个多谐波候选及 64 圈诊断 | seed 80 长程场线逃逸，fail |
| v80 | 100 个独立模块 smoke；16 shortlist；2 finalist | winner seed 8 不逃逸，但最小 `|ι|=0.01856 < 0.02`，fail |

v80 是当前最新开发分支。它扩大了线圈语法，但还没有闭合 collisional kinetic transport、有限压力平衡、MHD/微观稳定性、粒子输运、完整工程或 C2。

---

## 2. 重构后的多拓扑 + 统一物理搜索到 C2 总架构

### 2.1 两个正交坐标：不要把它们混在一起

系统同时有两个维度：

1. **统一八阶段判定链**回答“每个候选必须检查哪些问题”；
2. **C0–C3 成熟度**回答“当前证据允许我们把结论说到哪一层”。

八阶段不是八个不同装置路线，C0–C3 也不是可相加的分数。一个候选可以在某个 Stage 4 必要条件上 fail，同时整体 evidence completeness 仍 incomplete；也可以完成一个 C1/C2 component，但整机仍没有 complete C2。

### 2.2 端到端主链

```text
Mission Contract + Governance Policy
                │
                ▼
Open Typed Genome 2.0
  identity / structural / semantic / behavioral / evaluation hashes
  regions / states / operators / materials / controllers / unknowns
                │
                ▼
Graph-native topology grammar (v69)
  region graph + ports + interfaces + dependencies + obligations
  only physical declarations; family/name cannot route
                │
                ├──────── structural loop ────────┐
                │                                  │
                ▼                                  ▼
Trusted Physics Compilation Kernel          Archive / dedup / QD
  ruleset + coverage + applicability        Pareto cells, no scalar score
  types + units + causality + conservation  evidence-cost feedback
                │                                  │
                ▼                                  └── next evidence budget
Evidence Obligation Graph
                │
                ▼
Capability Registry + Evidence Acquisition Planner
  analytic / numerical / experiment / diagnostics / solver R&D
                │
                ▼
Executable Physics IR + Candidate Manifest
  state / residual / Jacobian / mass matrix / boundary / interface
                │
                ▼
Candidate-bound execution (v68/v70)
  steady / ODE / index-1 DAE / structured PDE / coupled regions
  homotopy + convergence + resolution + independent residual audit
                │
                ▼
Candidate-bound physical modules
  equilibrium / stability / transport / reaction / radiation / burn
  actuators / plant ledger / finite engineering / faults / VVUQ
                │
                ▼
Uniform eight-stage evaluator (v55)
  1 description → 2 topology → 3 state → 4 stability
  → 5 transport/burn → 6 energy → 7 engineering → 8 evidence
                │
                ▼
C2CandidateStatePackage + C2DecisionEnvelope
  completeness ≠ conclusion ≠ failure scope ≠ termination
                │
                ▼
C0 / C1 / C2 / C3 scoped decision
  PromotionScope + FailureScope + independent confirmation status
```

### 2.3 结构循环和数值循环为什么分开

**结构循环**负责大量、便宜、可恢复地做图生成、规范化、图同构去重、静态合同检查和义务编译。它可以到十万甚至更高 seed，但不能产生物理可行性信用。

**数值循环**只接收通过结构合同、且具有匹配能力和候选输入的记录。它执行昂贵的状态解、稳定性、输运、燃烧、工程和 VVUQ，并形成候选绑定证据。只有这一循环的合格证据才能推进 C1/C2。

两者分开后，扩大结构搜索不会稀释物理证据标准；缺求解器时也不会把候选误判为物理失败。

### 2.4 family-free 的真正含义

统一不是“所有候选都用同一个方程”，而是：

- 所有候选都走同一条问题清单和状态语义；
- 内部算子由 physical capability 选择：维度、边界、时间语义、状态种类、守恒账户、有效域、离散方式和证据等级；
- mirror、stellarator、tokamak、ICF、Z-pinch 等名字只可在搜索后用于解释、聚类或展示；
- 如果一个候选需要 DCLC、AIC、interchange、ballooning 或 ablation stability，这些是 Stage 4 的算子义务，不是不同总路线；
- 如果没有匹配算子，结果是 `unsupported`；输入不完整是 `unknown`；完成并越过硬限值才是 `fail`；完整满足才可能是 `pass`。

### 2.5 C2 的完整定义和当前实现映射

完整 C2 至少要求：

1. 候选绑定的平衡或适用瞬态；
2. 粒子、组分、荷电、离子能、电子能、动量/场能联合账本；
3. 所有适用稳定性或受控不稳定证据；
4. 输运、反应、辐射、自加热、损失和排出；
5. 多区域/多模块耦合收敛、接口守恒和误差传播；
6. 候选绑定工程载荷、材料域和必要安全裕量；
7. verification、validation、UQ、OOD 和所需独立复算；
8. 全部证据绑定同一候选、运行点、状态哈希和适用域。

当前 `C2DecisionEnvelope` 实现的是 fail-closed 汇总协议；v68 实现的是通用残差图内核；v69/v70 实现图编译和有限 Stage 3 能力；v71–v80 实现实体化与低保真前置淘汰。它们拼成了到 C2 的软件骨架，但尚未提供所有真实物理模块和候选证据，所以完整 C2 仍为 0。

---

## 3. 目前已经做成了什么，尚未做成什么

### 3.1 已经做成并有当前证据的能力

| 能力 | 当前证据 |
|---|---|
| family/label 不参与统一总链路由 | v55 标签擦除、v56–v67 全量记录、v69–v80 代码合同 |
| 所有候选全量执行而非家族预筛 | v56 10,000/10,000、0 dropped |
| 区分 pass/fail/unknown/unsupported/N/A | 判定、求解、资源和 C2 汇总均保留五态语义 |
| 图原生多拓扑生成与静态编译 | v69 10,000 raw、9,090 compile pass |
| 可恢复、分片、流式大结构搜索 | v70 100,000 seeds、99,873 unique、0 uncaught exception |
| 候选绑定残差/Jacobian/mass matrix | v68 manufactured problems 与独立审计 |
| 有限 0D–3D、steady/transient/index-1 DAE 原生能力 | v70 正/负/unsupported 控制与图集成验收 |
| 候选实体部件与有限细丝磁场 | v71–v80 候选绑定 realization 和密封运行档案 |
| 低保真粒子/反应/工程淘汰 | v71 Boris、Bosch–Hale、导体/应力/排热下界 |
| C2 的 completeness/conclusion/failure/termination 分离 | C2DecisionEnvelope 与两条真实装配纵切片 |
| 厂辅、工程、独立证据和外部资源义务显式化 | v63–v67，缺口不会被默认值补齐 |
| 不使用单一总分 | QD/Pareto 分别保留证据成本、残差、工程裕量、结构新颖度等坐标 |

### 3.2 仍未完成，因此不能宣称的能力

- 没有对任一真实新候选完成统一全耦合 Maxwell/平衡 + MHD/动理学稳定 + 输运 + 反应/辐射 + 执行器反馈残差；
- 没有候选绑定的高维 kinetic/Fokker–Planck、alpha orbit、碰撞/散射、杂质/中性粒子完整闭合；
- 没有全适用模式稳定性和有限压力鲁棒运行域；
- 没有有限厚度线圈、完整电磁力/支撑/热/失超/疲劳/容差/故障闭合；
- 没有中子学、屏蔽、氚增殖、自持燃料循环、维护、寿命、可用率和完整 balance-of-plant；
- 没有独立软件组双代码复算和候选绑定校准实验锚点；
- 没有完整 C2 pass、C3、物理晋级、净电授权、工程可建造、经济性或可部署性结论；
- 没有机制级原创性、专利性、不侵权或 FTO 结论。

### 3.3 当前前沿的准确表述

- **结构搜索前沿**：v70 已证明十万结构流式、去重、恢复和制造平衡证据链；不是十万个可行装置。
- **统一求解前沿**：v68 已有真正的非线性残差图内核；真实候选物理块仍不完整。
- **真实 C2 装配前沿**：pool-24 和 low-force 已得到装配级窄硬失败；pool-56 和 high-ratio 仍 unknown；完整 C2 为 0。
- **实体新搜索前沿**：seed 35 在 v72 为 `incomplete/unsupported`；seed 98 已被乐观碰撞上界淘汰；v74–v80 新线圈语法当前均未越过场线/旋转变换门。
- **晋级前沿**：物理 promotion 仍为 0。

---

## 4. 目前与未来目标的最大搜索范围

“最大搜索范围”必须分成三层，否则候选数、拓扑表达力和物理证据深度会被混为一谈。

### 4.1 已实跑的最大规模

| 搜索层 | 已实跑最大规模 | 证据上限 |
|---|---:|---|
| 图结构流式搜索 | 100,000 raw seeds / 99,873 unique structures | 结构与 manufactured Stage 3 执行完整性 |
| 统一八阶段候选搜索 | 10,000 candidates / 1,000 topologies | 全链 fail/unknown 分布；0 promotion |
| 区域数值/工程/厂辅/资源全量链 | 10,000 candidates | L1/有限工程/资源义务；非完整 C2 |
| 当前 v80 实体模块搜索 | 100 candidates、16 shortlist、2 finalists | 有限细丝快速场/工程 + 4/8 圈场线筛选 |
| 真实候选 C2 纵切片 | 4 个前沿，2 个执行到装配级终止失败 | 候选装配窄失败；0 complete C2 pass |

### 4.2 当前可执行 grammar 的最大物理范围

当前主线可以组合搜索：

- **拓扑**：1–4 区域图、内部/外部接口、开放/闭合/混合边界；
- **时空**：0D/1D/2D/3D，steady/transient/index-1 DAE；
- **账户**：粒子、物种、荷电、离子能、电子能、场/热账户；
- **因果硬件**：场源、能量源、边界、燃料/排气、散热、传感、1–3 级控制、执行器；
- **对称性**：none/reflection/rotational/helical；
- **实体几何**：当前以线性体积、环形体积、有限细丝线圈、环向基场和多模块螺旋/多谐波线圈为已执行主线；
- **数值能力**：有限的非线性 0D、ODE、index-1 DAE、结构化保守 PDE、多区域通量和独立平衡审计；
- **低保真物理**：Biot–Savart、无碰撞 Boris、D-T 0D 反应/轫致辐射、导体/应力/排热下界、场线/旋转变换/乐观漂移淘汰。

当前原生运行时还不覆盖高指数 DAE、非结构网格、移动边界、任意非局域算子和高维动理学；这些必须通过 capability adapter 加入，不能由现有结果推断。

### 4.3 重构架构允许达到的理论最大范围

架构本身不把合法候选空间限制为 tokamak、stellarator、mirror、ICF 或任何固定家族。它的上限是：

```text
任意可类型化的区域/界面拓扑骨架
× 任意可声明适用域的场/流体/粒子/辐射/反应/回路/事件算子组合
× 连续几何、材料、运行点和控制参数
× steady / transient / pulsed / event / coupled DAE-PDE-kinetic 时间语义
× 解析、数值、现有实验、新实验、诊断和独立复算证据路径
× C0 → C1 → C2 → C3 的候选绑定成熟度
```

由于连续参数空间本身不可穷举，理论上不存在一个诚实的“总候选数上限”。实际最大搜索必须由版本化 grammar、参数边界、证据预算和停止条件定义。系统未来可以扩展到磁约束、惯性/脉冲、高能量密度、开放/闭合/混合边界、混合驱动、主动控制和新部分机制，但前提是这些机制能被类型化、产生可辨识预测，并能获得适用的证据能力。

### 4.4 建议的未来分层规模目标

以下是工程目标，不是已完成承诺：

| 层级 | 建议最大预算 | 进入条件 | 退出产品 |
|---|---:|---|---|
| U0/C0 结构生成 | `10^6–10^8` 个流式 seed | 静态规则、图哈希、恢复和存储可承受 | 去重拓扑、义务图、工程下界、falsification archive |
| 低成本候选绑定筛选 | `10^5–10^6` 个实例 | 有明确参数域、相同低保真能力和不偏置抽样 | 窄 fail / unknown / C1 acquisition queue |
| 真实 C1 数值/实验路径 | `10^3–10^4` 个候选 | C0 mandatory 全通过、证据路线有高信息增益 | 候选绑定 solve/experiment、作用域正确的 pass/fail |
| 高成本 C2 多物理闭合 | `10–10^2` 个候选 | mandatory C1 已闭合、模型处于校准域 | 完整耦合状态、稳定/输运/工程/VVUQ 包 |
| C3 整机任务闭合 | `1–10` 个候选 | C2 完整且有独立确认计划 | 完整任务、功率、燃料、寿命、故障、安全和部署证据 |

这里最重要的原则是：**只有当前一层的 evidence-resolution yield 足够高，才扩大下一层搜索。** 如果 C2 仍为 0，就不应把“再增加一个数量级的结构 seed”当作主要科学进展。

---

## 5. 下一阶段目标

### 5.1 近期：把 v73–v80 从场线语法搜索推进到可信 closed-field 物理证据

1. 对 v80 winner 和其他 Pareto 候选做分辨率、起始面、8/16/64 圈和容差鲁棒性复核；
2. 若 `|ι| < 0.02` 或长程逃逸稳定出现，保留窄失败并扩大线圈 grammar，而不是降低门槛；
3. 将有限压力平衡、误差场、粒子碰撞/散射和候选绑定输运接入同一能力路由；
4. 对线圈离散化、导体截面、电磁力、支撑和热闭合做独立分辨率/代码复核；
5. 继续保持该分支只是“helical-capable physical grammar”，不能演变为按 stellarator 标签走专用总路线。

### 5.2 主线优先级：完成真实候选的统一非线性残差闭合

下一项最关键工作不是继续堆搜索层，而是把下列项真正放入同一个候选绑定残差/DAE 中：

- 平衡/场；
- 粒子与物种连续性；
- 离子/电子能量；
- 输运与边界损失；
- 反应、自加热与完整辐射；
- 燃料、加热、排气和控制执行器反馈；
- 接口通量与厂级功率角色。

然后对每个实质候选要求 `λ=1` 收敛、分辨率趋势、独立残差复算、物理界限和不确定性。L1 只能保留为初值/同伦，不得继续作为高层证据。

### 5.3 C2 闭合目标

至少完成以下候选绑定纵切片：

- 一个 closed/mixed 边界候选；
- 一个 open/mixed 边界候选；
- 一个 pulsed/HEDP 候选；
- 一个负控制。

四者必须走同一 C2 汇总协议，但各自在内部使用声明能力匹配的算子。只有在其中至少一个候选完成 Stage 3、Stage 4、Stage 5、工程、UQ 和独立证据后，才可以讨论完整 C2 pass。

### 5.4 更远目标：从 C2 到 C3

在 C2 真实闭合后，再扩展：完整净电、热循环、低温/磁体电源、真空/排气、燃料循环、氚、中子学、屏蔽、寿命、维护、故障、安全、可用率、可制造性和独立确认。C3 才是“任务/整机是否成立”的层级；即使 C3 通过，也应把物理可行性、工程可行性、经济性、部署性和原创性分别报告。

---

## 6. 最终状态边界

截至 2026-08-25：

- 多拓扑、family-free、统一八阶段判定的软件架构已经建立；
- 十万结构流式搜索和万级候选统一判定已经实际运行；
- 非线性残差图、有限通用 Stage 3 执行、实体部件编译和 C2 汇总骨架已经接通；
- 两条旧前沿得到真实装配级窄失败，实体新搜索得到一个 unsupported 前沿和多批场线/旋转变换失败；
- **真实新候选 complete C2 pass = 0；promotion = 0；C3 = 0。**

因此目前最准确的项目定位是：**已经从“按家族筛选的候选生成器”重构成“可审计的多拓扑统一物理发现与证据编排系统”，并把软件主链推进到候选绑定非线性求解、实体化和 C2 决策入口；下一步的瓶颈是候选专属多物理证据闭合，而不是搜索数量。**
