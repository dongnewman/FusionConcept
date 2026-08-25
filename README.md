# FusionConceptAI

## 一句话定位

FusionConceptAI 目前不是“输入目标，AI 自动输出一台可建造聚变反应堆”的系统，而是一套：

> 面向开放拓扑的候选生成器 + 物理问题编译器 + 求解能力路由器 + 多物理证据执行器 + 统一八阶段审计器 + 证据预算调度系统。

它的核心目标，是让任何候选——无论后来被人称为托卡马克、仿星器、磁镜、Z-pinch、ICF，还是尚无名称的新构型——都走同一套判断链；不同构型只是在每个阶段内部需要调用的物理算子不同。

当前软件骨架已经接到候选绑定非线性求解、Stage 3 通用数值运行、实体线圈/部件生成和 C2 决策入口，但截至目前：

- 真实新候选完整 C2 pass：0
- 物理 promotion：0
- C3 整机闭合：0
- 已有结果主要是结构搜索、软件链路验证、有限低保真筛选和候选装配级窄失败

当前总体架构说明集中在[本周统一架构文档](docs/weekly_multitopology_unified_c2_architecture_20260825.md)，主模块入口是[src/FusionConceptAI.jl](src/FusionConceptAI.jl)。

---

## 一、总体架构

```text
Mission Contract + Governance Policy
                │
                ▼
Open Typed Genome 2.0
候选身份、区域、状态、算子、材料、控制器、未知项
                │
                ▼
Graph-native Topology Grammar
区域图、端口、接口、依赖、守恒账户、证据义务
                │
        ┌───────┴────────┐
        ▼                ▼
结构搜索循环          Trusted Physics Kernel
生成/规范化/去重      类型/单位/因果/适用性/规则覆盖
QD/Pareto 档案              │
        │                  ▼
        └──────── Evidence Obligation Graph
                            │
                            ▼
             Capability Registry + Evidence Planner
                            │
                            ▼
              Executable Physics IR + Solve Manifest
                            │
                            ▼
             v68/v70 候选绑定数值执行与独立审计
                            │
                            ▼
 平衡/稳定/输运/反应/辐射/执行器/工程/厂辅/VVUQ
                            │
                            ▼
                  v55 统一八阶段判定
                            │
                            ▼
        C2CandidateStatePackage + C2DecisionEnvelope
                            │
                            ▼
             C0 / C1 / C2 / C3 作用域化结论
                            │
                            ▼
      Pareto/QD 档案更新 + 下一轮证据预算与求解任务
```

这里有两个特别重要的闭环：

1. **结构循环**负责廉价地生成、去重和编译大量候选。
2. **数值/证据循环**负责昂贵的候选绑定求解、稳定性、输运、工程和验证。

结构搜索可以跑到十万甚至百万规模，但只有第二条循环生成的合格证据才可能推进 C1/C2。

---

## 二、候选表示层：Open Typed Genome

旧版 `Genome` 仍保留在[src/genome.jl](src/genome.jl)，用于历史兼容；当前开放世界路线使用[src/open_world_genome_v2.jl](src/open_world_genome_v2.jl)。

`OpenWorldGenomeV2` 不只是一个参数数组，而是候选的完整物理声明，包括：

- 区域和控制体
- 状态变量
- 场源、粒子源、热源和损失项
- 边界、接口和通量
- 材料、执行器、传感器和控制器
- 方程、部分算子和适用域
- 已知量、未知量和证据缺口
- 来源、谱系和版本信息

它维护多层身份：

- `identity_hash`：原始声明、来源和谱系
- `structural_hash`：删除名称、family、节点排序后的物理结构
- `semantic_normal_form_hash`：单位、坐标、变量和算子等价归一
- `behavioral_signature_hash`：标准干预下的响应特征
- `evaluation_hash`：候选、任务、规则、求解器、数据和配置的联合身份

因此，“把某个候选从 stellarator 改名成 new_device”不能改变结构哈希、能力路由和判断结果。

旧 Genome 迁移到 v2 是单向 sidecar 迁移，不覆盖封存历史对象。

---

## 三、图原生拓扑搜索层

v69 把搜索对象进一步改造成[GraphNativeTopologyV69](src/search/graph_native_topology_search_v69.jl)。

一个拓扑图由以下对象构成：

- `regions`：1–4 个物理区域
- `interfaces`：区域之间的通量接口
- `ports`：场源、能量源、边界、排热、执行器、传感器和控制端口
- `dependencies`：算子、状态和硬件之间的因果依赖
- `obligations`：守恒、边界、有效域和证据义务
- `symmetry`：无、反射、旋转或螺旋对称

当前 grammar 可组合：

- 0D、1D、2D、3D
- steady、transient、index-1 DAE
- open、closed、mixed 边界
- 粒子、组分、荷电、离子能、电子能等账户
- 1–3 级传感—控制—执行器路径

编译时会生成：

- `topology_hash`
- 规范化哈希
- 图同构哈希
- 编译状态和失败代码
- 进入下一物理门的预计证据成本

然后进入 `StructuredQDArchiveV69`。它不使用一个总分，而是在每个行为单元分别保留：

- 最低补证成本
- 最小守恒残差
- 最大工程裕量
- 最高结构新颖度

这正是“更简单、更稳定、产出更高”不被压缩成单一代理分数的实现基础。

---

## 四、可信物理编译内核

可信编译层负责把“候选描述”变成“可执行的物理问题”。

早期核心对象定义在[src/physics_compiler.jl](src/physics_compiler.jl)，开放世界增强层包括：

- `PhysicsRuleManifest`
- `RuleCoverageManifest`
- `ApplicabilityProof`
- `FailureScope`
- `PromotionScope`
- `Evidence Obligation Graph`

编译器主要执行：

1. 类型和单位检查。
2. 区域、状态、边界和接口检查。
3. 因果链检查，阻止隐式能源、未绑定控制器和孤立模块。
4. 守恒账户编译。
5. 根据物理属性激活算子。
6. 检查算子适用域、输入和输出。
7. 将缺失项编译成证据义务。
8. 计算 routing hash 和证据上限。

它不会因为候选叫“磁镜”就直接套用磁镜公式。路由输入是：

- 空间维数
- 时间语义
- 边界类型
- 状态种类
- 守恒账户
- 算子类型
- 有效域
- Jacobian 能力
- 离散方式
- 所需输出

没有精确能力时返回 `unsupported`；输入缺失时返回 `unknown`。

---

## 五、Evidence Obligation Graph 和证据规划

系统不会简单地把所有缺口都交给“万能求解器”。

每个未知项会被转化为一个证据义务，例如：

- 缺平衡解
- 缺某种稳定性算子
- 缺候选绑定输运系数
- 缺材料极限
- 缺执行器效率
- 缺独立代码复算
- 缺实验校准
- 缺适用性证明

`Evidence Acquisition Planner` 再为每项义务选择路径：

- 解析界限
- 低保真数值淘汰
- 高保真数值求解
- 外部数据资源
- 现有实验锚点
- 新实验或诊断
- 求解器/适配器研发

调度依据是信息增益、成本、可复用性、失败影响范围以及能解锁哪些后续 gate，而不是单纯挑“看起来最好的候选”。

---

## 六、Stage 3 数值运行架构

### v68：通用非线性残差图

[candidate_residual_graph_runtime_v68.md](docs/candidate_residual_graph_runtime_v68.md)定义了后端中立的残差图协议。

核心原则是把所有相互反馈的物理量放入同一个残差：

\[
R(x,\dot x,p)=0
\]

每个状态方程只能有一个 governing residual producer，但可以有多个 additive block，例如：

- 粒子连续性
- 离子/电子能量
- 反应与辐射
- 输运和边界损失
- 区域接口通量
- 自加热
- 执行器反馈

它明确记录：

- state layout
- residual rows
- Jacobian block
- mass matrix
- 边界和接口
- 初值
- 同伦计划
- 求解结果和审计记录

L1 线性区域解只允许作为初值、诊断基线和同伦起点：

\[
R_\lambda=(1-\lambda)R_{L1}+\lambda R_{\text{full}}
\]

只有到达 `λ=1` 并通过残差、物理界限、接口守恒、Jacobian 和分辨率审计，才能获得完整数值结论。

### v70：可大规模运行的有限通用 Stage 3 Runtime

[stage3_universal_runtime_v70.jl](src/stage3_universal_runtime_v70.jl)把图候选编译成三个主要对象：

- `Stage3ExecutionRequestV1`
- `Stage3ExecutionPlanV1`
- `Stage3EvidenceEnvelopeV1`

当前原生能力覆盖：

- 0D 非线性稳态
- 隐式 source-loss ODE
- index-1 DAE
- 1D/2D/3D 结构化保守扩散/反应
- 1D 保守平流
- 多区域配对通量
- sensor-controller-actuator 稳定和容量审计
- 有限 mixed 0D–1D coupling

当前不原生覆盖：

- 高指数 DAE
- 非结构网格
- 移动边界
- 任意非局域算子
- 高维 kinetic/Fokker–Planck

这些必须通过新的 capability adapter 加入。

运行时还支持：

- Halton 确定性采样
- 预算限制
- 原子缓存
- checkpoint/resume
- 内容寻址 evidence store
- 独立平衡复算
- 软件源码哈希和环境哈希

`Stage3EvidenceEnvelopeV1`会保存最终状态、轨迹、守恒、接口、收敛、执行器、适用域、独立复算、成本和全部源哈希。

---

## 七、统一八阶段判定链

所有候选最终进入[v55 统一判定链](docs/unified_fusion_judgment_chain_v55_20260822.md)：

| 阶段 | 判断内容 |
|---|---|
| 1 | 物理描述是否完整 |
| 2 | 拓扑、接口和因果是否一致 |
| 3 | 守恒与状态演化是否闭合 |
| 4 | 扰动、稳定性和控制是否满足 |
| 5 | 粒子/能量输运、反应与燃烧是否闭合 |
| 6 | 净能量账本是否由求解结果闭合 |
| 7 | 工程、材料、热、力、故障和寿命是否可实现 |
| 8 | 收敛、UQ、模型误差、独立复算和实验是否完整 |

不同候选可以在 Stage 4 内分别需要 DCLC、AIC、ballooning、interchange 或 ablation stability，但不能跳过 Stage 4，也不能改走另一套总链。

所有阶段都会执行，不因前一阶段失败而把后续记录删除。总体语义是：

- 任一阶段物理完成并违反硬门：`fail`
- 全部适用阶段完整通过：`pass`
- 有必要输入或证据缺失：`unknown`
- 没有匹配能力：`unsupported`
- 有证据证明不适用：`not_applicable`

特别重要的是：不收敛、预算耗尽和求解器异常不能自动变成物理 `fail`。

---

## 八、C0–C3 与八阶段的关系

八阶段回答“必须检查什么”；C0–C3 回答“证据允许把结论说到哪里”。它们是正交坐标。

- **C0**：形式化、可检测、可区分、可识别、可编译。
- **C1**：某个原始机制获得第一条候选绑定真实证据路径。
- **C2**：平衡、状态、稳定性、输运、反应、执行器、工程与 VVUQ 的多域耦合闭合。
- **C3**：净电、厂辅、燃料、寿命、故障、安全、维护和任务级整机闭合。

一个候选可能：

- 有一个窄 C2 稳定性组件，但没有完整 C2；
- 在某个线圈装配必要条件上 fail，但不能否定整个拓扑；
- Stage 3 数值收敛，却因缺分辨率或独立验证仍为 unknown。

---

## 九、C2 状态包和决策信封

当前统一汇总对象定义在[c2_decision_runtime_v1.jl](src/c2_decision_runtime_v1.jl)。

`C2CandidateStatePackageV1`统一保存：

- 粒子账户
- 离子和电子能量账户
- 物种状态
- fueling/heating/exhaust/radiation-control 执行器
- 功率账本
- 状态解、残差、守恒、接口、稳定、工程等证据字段

`C2DecisionEnvelope`刻意把四件事分开：

- `completeness`：证据是否完整
- `candidate_conclusion`：候选结论
- `narrow_failures`：失败影响范围
- `terminate`：是否应停止该候选装配

所以“某个 32 线圈离散语法失败”不会自动变成“仿星器不可能”；“某个双线圈 minimum-B 必要条件失败”也不能否定所有开放场构型。

---

## 十、实体装置层：v71–v83

v71 开始把抽象端口重新接回实体部件：

- 有限细丝线圈
- 真空边界
- 粒子注入和排气
- 冷却
- 执行器
- 传感器与控制器

随后执行：

- Biot–Savart 磁场
- 无碰撞 Boris 粒子轨道
- Bosch–Hale D-T 0D 反应
- 燃料离子轫致辐射
- 电流密度、磁应力和排热下界

后续版本逐层扩展：

- v72：开放场碰撞约束上界
- v73：闭合场线、旋转变换和乐观曲率漂移淘汰
- v74–v76：环向基场、螺旋扰动、热排出和运行点细化
- v77–v78：局部螺旋场面搜索
- v79：多谐波线圈
- v80：独立模块化多谐波线圈
- v81：固定环向截面的 Poincaré 面、非圆形 Fourier 拟合、嵌套/漂移/随机扩散审计
- v82：周期重复的非平面模块线圈
- v83：对 v82 前沿进行形变、电流离散度和半径离散度正则化

v81–v83 已进入主模块；本次建库前实际执行的聚焦回归为：

- v81：9/9
- v82：9/9
- v83：6/6

但当前目录中还没有对应的正式 v81–v83 万级运行归档，因此它们现在应表述为“代码和小规模流程通过”，不能说已经产生新的物理 survivor。最新有正式报告的实体搜索仍是[v80 报告](reports/modular_multiharmonic_search_v80_10000_20260825.md)。

---

## 十一、“AI”具体体现在哪里

项目当前并不是以大型神经网络为核心。`Project.toml`主要依赖 Julia 标准数值库和 JSON3。

“AI/发现系统”主要体现在：

- 类型化开放候选生成
- 图 grammar 变异
- QD/MAP-Elites 档案
- 多目标 Pareto 保留
- 行为签名和等价识别
- 模型区分与 OOD 判断
- 主动证据获取
- 高保真任务预算分配
- 失败定向搜索
- 证据成本反馈
- 确定性重放与可恢复分片

因此它更接近“物理编译器 + 多保真搜索与科学证据编排器”，而不是黑箱回归模型。

---

## 十二、代码和产物目录

主要目录职责：

- `src/`：Julia 核心类型、编译器、运行时和物理模块
- `src/search/`：候选 grammar、QD、Pareto、分片搜索和各版本搜索
- `src/adapters/`：FreeGS、DESC、Pleiades、IMAS、OpenPMD、FMI 等适配层
- `src/solvers/`：通用 ODE/DAE/event 适配器
- `schemas/`：跨进程和长期归档 JSON Schema
- `fixtures/`：制造控制、负控制、参考候选
- `scripts/`：正式运行、分片、合并、审计和外部 Python 后端
- `test/`：聚焦与回归测试
- `runs/`：机器可读 JSON/JSONL、缓存、日志和分片记录
- `reports/`：人类可读的 Markdown 报告
- `knowledge/`：来源和知识资产
- `interactive_*`：Stage 3、PLRMR、实体装置的交互展示
- `output/`：网页截图、PDF、演示资产等派生产物

交互界面只读取和展示归档，不是新的物理证据来源。

---

## 十三、一次典型运行如何发生

以图原生候选为例：

1. 用确定性 seed 生成 `GraphNativeTopologyV69`。
2. 静态检查并计算规范化/同构哈希。
3. 去重后进入 QD 行为单元。
4. 编译 `Stage3PhysicsIRV1`。
5. 根据维度、时间、边界、算子和有效域匹配 capability。
6. 生成 `Stage3ExecutionPlanV1`。
7. 检查预算、网格、Jacobian、mass matrix 和证据义务。
8. 执行稳态/ODE/DAE/PDE 或返回 unsupported。
9. 对每个采样点执行收敛、守恒、接口和独立复算。
10. 写出 `Stage3EvidenceEnvelopeV1`。
11. 将状态结果绑定到稳定、输运、反应、工程和功率模块。
12. 执行统一八阶段判定。
13. 生成 C2 状态包和决策信封。
14. 更新 Pareto/QD 档案。
15. 将下一步最有信息价值的缺口加入 evidence queue。
16. JSON/JSONL 归档并写出 Markdown 报告。

所有下游结果都必须引用上游候选、状态和求解器哈希。Stage 6 功率项不能脱离 Stage 3/5 的 solver hash 自行填入。

---

## 十四、常用运行入口

在项目根目录中：

```powershell
cd D:\006-Programing\LMC\outputs\fusion_concept_ai

julia --project=. --startup-file=no scripts/run_common_chain_graph_search_v69.jl

julia --project=. --startup-file=no scripts/run_stage3_universal_acceptance_v70.jl

powershell -NoProfile -ExecutionPolicy Bypass `
  -File scripts/run_stage3_streaming_v70_100000.ps1

julia --project=. --startup-file=no scripts/run_physical_device_search_v71.jl

julia --project=. --startup-file=no scripts/run_modular_multiharmonic_search_v80.jl

julia --project=. --startup-file=no scripts/run_v80_poincare_frontier_v81.jl

julia --project=. --startup-file=no scripts/run_periodic_modular_search_v82.jl

julia --project=. --startup-file=no scripts/run_periodic_coil_regularization_v83.jl
```

不同命令不是互相替代：

- v69 验证结构和统一链接口；
- v70 执行有限通用 Stage 3；
- v71–v83 是当前实体线圈/场线物理搜索分支；
- v55–v67 保留为统一判定、区域求解、工程、厂辅和外部证据演进档案；
- v68 是全耦合非线性残差架构基础。

---

## 十五、最准确的当前评价

FusionConceptAI 已经完成了从“按装置家族写多个筛选器”到“开放图拓扑 + family-free 物理编译 + 统一证据语义”的关键重构。

软件上已经打通：

- 开放候选表达
- 图原生结构搜索
- 哈希和同构去重
- 证据义务编译
- 有限通用 Stage 3 数值运行
- 非线性残差图
- 实体部件和线圈生成
- 八阶段判定
- C2 fail-closed 汇总
- 分片、缓存、恢复和审计

真正的瓶颈已经不是“候选生成得不够多”，而是：

> 尚未把真实候选的平衡、粒子/物种连续性、离子/电子能量、输运、反应、自加热、完整辐射、执行器反馈和接口通量，在同一个候选绑定残差/DAE 中闭合，并补齐稳定性、工程、UQ 和独立验证。

所以它现在最合适的名称是：

> 可审计的、多拓扑、统一物理发现与证据编排平台。

而不是通用反应堆求解器，更不是已经发现可建造聚变装置的系统。
