# 跨构型核聚变装置 AI 设计与搜索系统

版本：0.2（文献、证据门禁与首个磁镜物理代理，2026-08-10）

## 1. 结论先行

LMC 现有系统已经证明了一个有价值的最小闭环：生成线圈候选、低阶物理与工程筛选、提高粒子验证保真度、保存搜索记录、在网页中解释结果。但它当前搜索的是固定 ITER 尺度、固定轴对称托卡马克等离子体代理周围的 TF/PF/CS 线圈，而不是“聚变装置”本身。要搜索托卡马克、仿星器、磁镜和可能的新构型，不能只扩大线圈坐标范围；必须同时替换设计表示、物理求解器、目标定义和证据制度。

推荐的系统不是一个端到端神经网络，也不是让大语言模型直接画线圈。它由五部分组成：

1. **机制知识库**：记录每个构型用什么机制取得约束、稳定、稳态、排热和工程简化，并记录机制成立的假设与失败模式。
2. **带属性的构型图语法**：先生成物理上有明确含义的装置拓扑，再优化连续几何和运行参数。
3. **按构型分族的多保真评估器**：托卡马克、三维环形装置和开放磁镜使用不同的平衡、输运与稳定性模型，只在共同的结果契约层比较。
4. **质量-多样性 + 约束多目标 + 局部梯度优化**：搜索得到一组不同机制和复杂度的 Pareto 候选，而不是由任意权重压成一个“总分”。
5. **反伪解验证门**：硬约束、模型适用域、制造误差、故障场景、独立高保真复核和已知装置回归，任何缺失项都记为 unknown，绝不按零风险处理。

最重要的设计原则是：**跨构型共享的是问题、指标语义和证据格式，不是一个错误的通用低阶物理公式。**

## 2. 文献中真正可迁移的设计思想

### 2.1 托卡马克：用轴对称与等离子体电流换取轨道约束

托卡马克的核心优势是轴对称带来的守恒量、成熟的平衡/输运/控制工具链，以及已经在多台装置上积累的运行数据库。H-mode 说明边缘输运屏障可以显著改变约束；Troyon 与 Greenwald 工作则说明高压强和高密度并非可以无代价增加，而是与电流、磁场、尺寸、边缘过程和 MHD 稳定边界耦合。相关原始来源包括 [ASDEX H-mode](https://doi.org/10.1103/PhysRevLett.49.1408)、[Troyon MHD limit](https://doi.org/10.1088/0741-3335/26/1A/319)、[Greenwald density limit](https://doi.org/10.1088/0029-5515/28/12/009) 和 [ITER Physics Basis](https://www-pub.iaea.org/mtcd/publications/pdf/csp_008c/fec1998/html/node196.htm)。

需要被 AI 系统显式建模的交换关系是：

- 环向等离子体电流提供旋转变换，但同时提供 kink、tearing、NTM、垂直不稳定和破裂的自由能。
- 稳态需要 bootstrap current 与外部非感应电流驱动的幅值和剖面对齐；高 bootstrap fraction 会降低循环功率，却会增强压力剖面与电流剖面的自组织耦合。
- 高磁场可提高功率密度并缩小装置，但峰值导体场、结构应力、屏蔽厚度、低温热负荷和偏滤器热流并不会随装置一起“免费缩小”。[ARC](https://arxiv.org/abs/1409.3540) 很好地展示了磁体、屏蔽、维护、电流驱动与功率密度必须一体化优化。
- 低纵横比球形托卡马克可进入高 beta、强螺旋节距区，但中柱空间、屏蔽、启动和电流维持会成为新的主导约束。[Peng 与 Strickler 1986](https://doi.org/10.1088/0029-5515/26/6/005) 应作为这一分支的原型来源。
- 边界形状不是装饰变量。伸长率、三角度、负三角形、X 点和偏滤器拓扑会共同影响稳定性、约束、垂直控制和热排出。

可迁移经验：**对称性非常有价值，但产生旋转变换的方法及其自由能来源必须作为一级设计变量。**

### 2.2 仿星器：把旋转变换移到外部磁场，并优化漂移不变量

经典仿星器用三维线圈在真空场中产生旋转变换，天然适合稳态运行并减少大环向电流导致的破裂风险；代价是三维轨道输运、磁岛、复杂线圈、装配误差、端口和维护困难。

现代仿星器设计思想不是一般性的“扭曲”，而是利用特殊的磁场强度结构恢复粒子漂移约束：

- [Nührenberg–Zille 1988](https://doi.org/10.1016/0375-9601(88)90080-1) 给出准螺旋对称原型。
- [Garren–Boozer 1991](https://doi.org/10.1063/1.859916) 给出近轴准对称构造的重要理论基础。
- [Landreman–Catto 2012](https://doi.org/10.1063/1.3693187) 将 omnigenity 视为更广的轨道漂移约束类别。
- [Landreman–Paul 2022](https://doi.org/10.1103/PhysRevLett.128.035001) 证明在显著体积内可以数值找到极高精度的准轴对称和准螺旋对称场。
- [Wechsung 等 2022](https://doi.org/10.1073/pnas.2202084119) 进一步表明这类场可以由具有适中曲率和间距的电磁线圈逼近，因此“等离子体边界可优化”与“线圈可制造”必须同环求解。

[W7-X 的实验结果](https://doi.org/10.1038/s41586-021-03687-w) 支持低有效波纹设计确实可以降低新古典输运；[岛式偏滤器实验](https://doi.org/10.1103/PhysRevLett.123.025002) 则表明高辐射、低靶板热负荷的稳定耗散态能够实现。这些结果同时提醒：只优化核心粒子轨道仍然不够，边缘磁岛和功率排出必须进入设计目标。

可迁移经验：**几何复杂度只有在它创造可验证的近似守恒量、稳定性或排热收益时才值得支付；等离子体形状与真实有限截面线圈必须一起优化。**

### 2.3 磁镜：用开放、线性和模块化换取轴向损失与稳定成本

简单磁镜通过磁矩近似守恒把大横向速度粒子反射在高场端，但存在损失锥；碰撞会不断把粒子散射进损失锥，电子还会形成复杂的双极电势和轴向热损失。轴对称简单磁镜本身对互换模不稳定，需要 minimum-B、端锚、有限拉莫尔半径、导体壁、剪切流或反馈等机制。

历史分支给出了不同的“支付方式”：

- [Fowler–Logan 1977 tandem mirror](https://pascal-francis.inist.fr/vibad/index.php?action=getRecordDetail&idt=PASCAL7730419573) 用高温端塞和双极势提高长中央室的轴向约束，并用 minimum-B 锚室处理 MHD 稳定性；但端塞、热障和中性束系统提高了系统复杂度与循环功率。
- [Post 1987 磁镜综述](https://cir.nii.ac.jp/crid/1361418520356859136) 汇总了燃料循环、损失和能量回收问题，是知识库中镜机失败模式的重要来源。
- [GDT](https://doi.org/10.1016/j.fusengdes.2003.08.002) 选择高镜比、较暖且较稠密、装置长度大于散射平均自由程的气动力学区，使等离子体接近各向同性并抑制许多不稳定性，适合作为简单中子源，但高 Q 功率堆路径并不由此自动成立。
- [WHAM 物理基础](https://doi.org/10.1017/S0022377823000806) 使用高场 HTS 磁体、ECH 靶等离子体、斜向 NBI 和偏置边缘剪切流。论文同时明确给出 25 keV 下电荷交换主导加料、轴对称镜仍需主动稳定、快离子绝热性等风险。
- [BEAM 2024](https://doi.org/10.1017/S0022377823001290) 进一步把高镜比、高能 NBI、大回旋半径数和 DCLC/AIC 稳定性放在同一设计权衡中；例如斜向 sloshing ions 可缓解 DCLC，却缩短粒子约束。

可迁移经验：**开放场线不等于不受约束；端损失、端区功率处理、原子过程和稳定执行器必须成为装置主体，而不是后处理修正。**

### 2.4 其他构型提供的机制原型

- **FRC**：极低或无外加环向场、高 beta、紧凑，但形成、平移/合并、倾斜/旋转和维持是核心风险。可从 [Steinhauer 的 FRC review](https://doi.org/10.1063/1.3613680) 建立机制与失败模式，而不能只保留“高 beta”标签。
- **RFP**：以强极向场、磁场反转和 dynamo 自组织获得高 beta 与紧凑性，但 tearing、磁随机性和维持决定约束。[RFP reactor study](https://doi.org/10.1016/0029-5493(81)90046-7) 可作为工程原型。
- **Spheromak / Dynomak**：无材料中心柱和较简单外部磁体具有吸引力，但 Taylor relaxation、闭合磁通形成、helicity 注入与电流维持不能被省略。[Dynomak](https://doi.org/10.1016/j.fusengdes.2014.03.072) 是系统级假设来源。
- **悬浮偶极**：利用偶极场与压强剖面产生高 beta 稳定区，可能适合先进燃料；但内置悬浮超导磁体的中子、维护、供能和热设计是构型本身的一部分。[Hasegawa–Chen–Mauel 1990](https://doi.org/10.1088/0029-5515/30/11/018) 是原型来源。

这些分支不应立即与托卡马克做一个数值总分排名。它们首先扩展“可选机制词汇”，随后在相同任务定义和证据等级下比较。

## 3. 把“更简单、更稳定、产出更高”变成可计算问题

这三个目标不能直接相加。绝对融合功率偏好无限增大装置；单一稳定分可掩盖一个致命模；按线圈数量衡量简单会奖励无法维护的紧凑结构。系统应采用任务约束加 Pareto 目标。

### 3.1 先固定任务，而不是先找“万能装置”

每次搜索必须选择 mission，例如：

- `science_gain_demo`：在不要求氚自持的条件下最大化可诊断的 Q 和物理信息量；
- `fusion_neutron_source`：满足指定 14.1 MeV 中子通量与可用面积，最小化氚消耗、资本量和风险；
- `net_electric_pilot`：满足净电功率、氚自持、热排出、可用率和维护周期；
- `advanced_fuel_experiment`：允许较低功率，但把燃料反应率、辐射损失和直接能量转换显式建模。

不同 mission 的硬约束不同，禁止用一个通用排行榜跨任务宣传“更优”。

### 3.2 简单性不是一个计数器

保留一个复杂度向量而非总分：

- 总部件数、独特部件/线圈族数、重复与对称度；
- 线圈总长度、最小弯曲半径、最大曲率/扭率、最小线圈间距、有限截面重叠裕度；
- 超导材料体积、低温质量、储能与保护回路数量；
- 加热/电流驱动/稳定执行器数及总循环功率；
- 真空边界、端区、偏滤器、泵口和诊断端口数量；
- 包层覆盖率、端口遮挡、远程维护可达性、最大可更换模块质量、平均更换路径复杂度；
- 独特制造工艺数、装配公差敏感度、故障后可隔离性；
- 建造成本与 RAMI 模型有依据时再纳入，不用无来源常数伪装精确经济性。

### 3.3 稳定性采用硬门和裕度谱

通用硬门包括：

- 求解器收敛且平衡残差低于构型相应阈值；
- 预期存在的闭合磁面、开放端区或 separatrix 拓扑确实存在；
- 关键粒子族、聚变 alpha、杂质与热粒子的损失均在限值内；
- 所有已声明稳定机制在其适用假设内工作；
- 制造误差、剖面变化、控制延迟和单故障场景下仍有可接受裕度。

分族指标包括：

- 托卡马克：`q_min/q_95`、`beta_N`、密度极限裕度、垂直增长率、理想 kink/ballooning、NTM/tearing、bootstrap/current-drive 剖面对齐、破裂场景与 halo load；
- 仿星器：准对称误差、`epsilon_eff^(3/2)`、omnigenity、旋转变换对低阶有理面的裕度、Mercier/ballooning、bootstrap current、磁岛、alpha loss、线圈误差敏感度；
- 磁镜：镜比、损失锥与 `n tau`、电子轴向热损失、压力各向异性、互换能量积分、DCLC/AIC、快离子绝热性、端区/剪切流稳定功率、NBI 电荷交换与 shine-through；
- 紧凑环：形成与维持时间、tilt/shift/rotation、tearing/dynamo、磁通与 helicity 损失、压缩循环效率。

稳健可行性写成场景化 chance constraint，例如 `P(g_i(x,s) <= 0) >= 1-epsilon_i`，报告最差值、低分位裕度和 epistemic uncertainty；不能只报告均值。

### 3.4 “产出”必须从融合功率走到净系统产出

至少同时输出：

- `P_fusion`、`Q_plasma`、Lawson/triple product；
- 聚变功率密度和装置体积，但附带中子壁负荷和表面热流；
- `P_aux`、电流驱动、NBI、RF、低温、泵、稳定控制和燃料循环用电；
- 热转换效率、`P_gross_electric`、`P_recirculating`、`P_net_electric`；
- D-T 装置的 TBR、库存、停机衰变与处理时间；
- 可用率、计划/非计划停机、部件寿命和年净发电量；
- 当 mission 固定净功率时，优化 `P_net / installed_mass`、包层面积、成本区间和风险，而不是继续增大绝对功率。

[Lawson criterion review](https://doi.org/10.1063/5.0083990) 明确指出 Lawson 指标只是商业系统判断中的一个因素。[PROCESS](https://www.sciencedirect.com/science/article/pii/S0920379614005961) 与其[工程部分](https://www.sciencedirect.com/science/article/pii/S0920379616300072) 展示了为什么磁体、包层、热转换、可用率和功率平衡必须与等离子体同时闭合。

## 4. 设计中间表示：Confinement Genome

一个跨构型候选应表示为带属性图，而不是固定长度浮点向量。

### 4.1 图的节点

- `plasma_region`：闭合环形区、镜机中央室、端塞/锚室、expander、紧凑环、形成/压缩区；
- `field_source`：TF/PF/CS、三维模块线圈、螺旋线圈、镜线圈、minimum-B 线圈、等离子体电流、被动导体；
- `actuator`：NBI、ECH/ICRH/LHCD、欧姆驱动、helicity injection、偏置电极、反馈线圈；
- `exhaust_region`：X 点偏滤器、岛式偏滤器、limiter、开放端板、膨胀直接转换器；
- `nuclear_region`：第一壁、包层、屏蔽、磁体、低温边界；
- `maintenance_module`：可拆磁体接头、扇区、端部可抽换模块、远程维护通道。

### 4.2 图的边

- 磁通连接和预期场线拓扑；
- 粒子/能量/灰分流向；
- 机械载荷路径；
- 电路、低温和冷却连接；
- 装配与维护依赖。

### 4.3 图语法

图语法只负责生成“结构上有定义”的候选，例如：

- 闭合环形等离子体必须声明旋转变换来源；
- 开放镜中央室必须连接两个端区和粒子/能量处置模块；
- D-T power mission 必须包含包层、屏蔽、燃料循环和维护路径；
- 声明 `sheared_flow_stabilization` 就必须存在偏置/波加热执行器、功率预算和剪切率评估器；
- 声明 `quasi_symmetry` 就必须指定对称类别、场周期和对应误差指标；
- 任何混合机制必须列出相容性条件，不能仅因名称新颖而生成。

连续几何使用分族坐标图：轴对称 Fourier/样条边界、三维 Fourier-Boozer 或近轴参数、开放镜轴向 `B(z)` 与有限截面线圈、紧凑环的 separatrix/flux conserver 参数。跨图切换由离散拓扑操作完成，避免把不连续物理硬塞入一个连续向量。

初始 JSON Schema 见 `schemas/confinement_genome.schema.json`。

## 5. 评估器契约与多保真阶梯

所有评估器返回同一契约：

```text
metric_id, value, unit, uncertainty, fidelity,
applicability, status, constraints_checked,
solver_name, solver_version, input_hash, run_hash,
source_basis, warnings, residuals, wall_time
```

`status` 只能是 `pass/fail/unknown/not_applicable/error`。`unknown` 不能转成零惩罚。只有满足 evaluator 声明的构型、参数区间和模型假设时，结果才可参与 Pareto 排序。

### 5.1 Fidelity -1：语法和量纲

- JSON/IR、单位、几何闭合、部件连接和任务完整性；
- Maxwell 基础约束、线圈自交、包层/屏蔽最小空间、明显能量守恒错误；
- 微秒到毫秒级，拒绝大量无意义候选。

### 5.2 Fidelity 0：场拓扑与 0-D/1-D 系统筛选

- Biot-Savart/轴向场、场线追踪、磁面/损失锥/separatrix 分类；
- 0-D 燃烧、反应率、辐射、功率平衡、磁体与热负荷缩放；
- 简单制造、间隙、应力、储能、TBR/屏蔽代理；
- 用于质量-多样性大规模探索，不允许产生“稳定反应堆”结论。

### 5.3 Fidelity 1：自洽平衡

- 托卡马克：free-boundary Grad–Shafranov，加电路与被动结构；
- 仿星器：VMEC/DESC；可能含岛或弱随机区时使用 SPEC/Poincaré 交叉检查；
- 磁镜：含压力各向异性、双极势和有限 beta 的轴对称平衡；
- 紧凑环：两流体/混合或相应平衡与形成模型；
- 平衡不收敛即失败，禁止由 surrogate 填补成“可行”。

### 5.4 Fidelity 2：轨道、输运和稳定

- 全轨道/导心，含 alpha、碰撞、原子过程和误差场；
- 新古典输运、gyrokinetic/湍流代理与高保真选点；
- ideal/resistive MHD、kinetic 模、垂直控制或开放镜互换/DCLC/AIC；
- 边缘与排热模型；
- 各构型只调用适用模型。

### 5.5 Fidelity 3：核工程与装置工程

- 有限截面线圈、结构/接触/电磁载荷、quench、低温和电源；
- 中子学、TBR、屏蔽、核热、材料损伤和寿命；
- 第一壁/偏滤器/端板热流与冷却；
- 端口、装配、远程维护、RAMI 与成本区间；
- 多物理耦合迭代到功率、热、应力和空间同时闭合。

### 5.6 Fidelity 4：场景、控制与实验闭环

- 启动、加热、燃烧、停机、故障与恢复的时间演化；
- 控制器、传感器、执行器饱和、延迟和丢失；
- 与公开实验数据或合作装置数据校准，更新模型差异而非直接覆盖物理；
- 只有本层通过的设计才能进入实验 proposal 或详细工程设计。

## 6. AI 与优化算法的职责分工

### 6.1 外层拓扑发现：图语法 + Quality Diversity

使用图语法产生合法的机制组合，以 [MAP-Elites](https://arxiv.org/abs/1504.04909) 或 CMA-ME 类方法维护多样化精英档案。行为描述符可以是：

- open/closed field line；
- vacuum transform fraction / plasma-current fraction；
- axisymmetry / QA / QH / QI / minimum-B；
- steady/pulsed；
- field periods or mirror cells；
- unique coil families；
- exhaust topology；
- active stabilization power fraction；
- normalized device size and beta regime。

QD 的任务是照亮不同机制区的最好候选，不是证明全局最优。新颖性只用于保持探索多样性，不能补偿物理不可行。

### 6.2 中层混合变量多目标搜索

在每个构型族内使用 NSGA-II/III、MOEA/D、差分进化或 CMA-ES 搜索离散+连续参数，维护明确的 Pareto front。现有 LMC 的低差异采样、差分进化和对称约束搜索可以成为托卡马克 adapter 的初始实现，但应移除单一人为加权总分作为最终决策依据。[NSGA-II 原始论文](https://doi.org/10.1109/4235.996017) 是基线而非默认赢家。

### 6.3 内层可微局部优化

对可微平衡、边界和线圈问题采用自动微分、adjoint 和 trust-region 局部优化。[DESC](https://arxiv.org/abs/2204.00078) 表明精确导数可显著加速三维平衡优化；[SIMSOPT](https://doi.org/10.21105/joss.03525) 提供了 VMEC/SPEC、线圈和目标组合的成熟接口。梯度优化只在固定拓扑内工作，不能代替外层拓扑搜索。

### 6.4 多保真约束贝叶斯优化

高保真调用由 cost-aware acquisition 决定：优先提升 Pareto hypervolume、降低关键可行性不确定性或验证新机制区，而不是只验证当前最高代理分。[Constrained BO](https://proceedings.mlr.press/v32/gardner14.html) 和 [multi-fidelity BO](https://proceedings.mlr.press/v70/kandasamy17a.html) 提供方法基础。

对质量-多样性档案，[SAIL](https://arxiv.org/abs/1806.05865) 说明可以用代理模型减少昂贵设计评估，同时保留跨行为描述符的照明目标；[BOP-Elites](https://arxiv.org/abs/2307.09326) 则联合建模 fitness 与 behavior descriptor 来选择下一批昂贵评估。不过二者的代理预测都只能用于 acquisition，不能写入“已完成物理证据”。当前每个构型/保真层的对齐观测太少，因此系统先实现确定性、可审计的证据价值/成本基线；积累足够真实调用后再用校准的 GP/ensemble 替换打分函数。

代理模型使用分族模型、物理特征、深度 ensemble/GP 和显式 OOD 检测。高低保真差值单独建模。训练域外或机制未见过时，必须提高不确定性并回退真实求解器。

### 6.5 大语言模型的限定角色

LLM 可以：

- 从论文抽取“机制—假设—指标—失败模式—证据”候选；
- 生成符合 DSL 的拓扑提案和解释；
- 关联相邻构型的相似机制；
- 生成审查清单和实验 proposal 草案。

LLM 不可以：

- 给数值物理结果或稳定性结论；
- 绕过 schema 直接写求解器输入；
- 将文献摘要中的设计预测当成实验验证；
- 修改硬约束或决定最终构型。

## 7. 机制知识库

仅做向量检索不够。知识库需要 claim-evidence graph：

```text
Mechanism -> intended_effect
          -> required_assumptions
          -> conflicting_effects
          -> measurable_metrics
          -> validated_device_and_range
          -> failure_modes
          -> compatible/incompatible mechanisms
          -> source DOI/URL and evidence type
```

证据分级：

1. 理论或解析原型；
2. 数值平衡/单物理模拟；
3. 多物理概念设计；
4. 非燃烧实验；
5. 反应堆相关参数实验；
6. 燃烧等离子体或核环境验证。

“W7-X 证明优化降低新古典输运”与“某 stellarator power plant 可建造”必须处在不同 claim 上。“BEAM 预测 Q≈1”必须标为概念预测而非实验事实。首批机器可读来源见 `knowledge/sources.json`。

## 8. 防止优化器制造伪解

1. **硬约束优先**：物理/工程硬门在 Pareto 排序前执行；罚函数只处理柔性目标。
2. **独立 verifier**：生成器与最终验证器使用不同代码路径或独立求解器。
3. **已知装置回归**：先复现 ITER/ARC 类 tokamak、W7-X/HSX、GDT/WHAM 的有限公开指标；不能回归的模型不能外推新构型。
4. **多随机种子和等预算对照**：自由、对称、机制受限搜索在相同预算下比较，报告均值/方差与最佳值。
5. **镜像/置换不变量测试**：检查坐标、标签和线圈顺序不会改变物理结论。
6. **参数与时间步收敛**：粒子数、网格、时间步、模数、场周期和迭代容差逐层收敛。
7. **扰动与故障场景**：制造偏差、线圈电流误差、单线圈失效、剖面漂移、控制延迟、杂质与 alpha 压力。
8. **optimizer's curse 校正**：保留 holdout 情景和未参与搜索的高保真模型；报告验证回落。
9. **完整溯源**：输入、代码、环境、求解器版本、随机种子、预算、失败调用和选择历史不可变记录。
10. **证据边界措辞**：只能写“在 X 模型、Y 约束、Z 预算下找到的候选”，除非已有更强证据。

## 9. LMC 当前能力与缺口

### 9.1 可直接复用

- Julia 搜索运行、结果目录、随机种子和历史 CSV/JSON；
- TF/PF/CS 离散拓扑、几何与电流搜索；
- Biot-Savart、导心/全轨道演示和扰动验证框架；
- 低阶磁体电流密度、峰值场、间隙、应力、储能、quench、低温、疲劳代理；
- Three.js 线圈/等离子体/轨道展示和 API 模式；
- 对称约束、多种子和等预算对照的实践。

### 9.2 必须明确降级为“托卡马克低保真 adapter”的部分

- 固定 `R0=6.2 m`、`a=2.0 m`、`Ip=15 MA`、`B0=5.3 T`；
- 解析 q-profile 等离子体场，不是自洽 free-boundary Grad–Shafranov；
- 固定椭圆/三角形边界和 `Bphi ~ 1/R`；
- `q95/beta_N/Greenwald` 与固定剖面组合成启发式 score；
- 最长 1 ms 的粒子损失与有限碰撞代理；
- 以 ITER 公共值校准的低阶工程模型；
- 缺少燃烧、alpha、湍流、破裂、偏滤器、TBR、中子学、材料寿命、净电功率和 RAMI 闭环。

这些能力适合做前筛和 UI 演示，不能直接评价仿星器、磁镜或新的场线拓扑。

## 10. 实施路线

### Phase A：可信设计 IR 与已知装置基线

- 实现 schema 对应的 Julia types、单位系统、canonical hash 和 evaluator result；
- 建立 family registry 与 applicability；
- 封装现有 LMC 为 `tokamak_axisymmetric_proxy_v1`，不改变数值；
- 加入 3–5 个公开 seed，每个只声明可回归的公开量；
- 建立测试：schema、镜像、置换、单位、未知值和结果溯源。

退出条件：相同输入可重复得到相同 hash/结果；未知 evaluator 不会被误算为通过。

### Phase B：三类物理求解器

- tokamak：接入真实 Grad–Shafranov/系统代码；
- stellarator：接入 DESC/SIMSOPT，并从近轴构型到有限截面线圈；
- mirror：实现轴向 `B(z)`、损失锥、Fokker–Planck/原子过程、各向异性平衡和稳定性接口；
- Three.js 改为读取通用场线、磁面/开放端区和部件网格。

退出条件：每族至少一个已知装置通过有限公开指标回归，且跨族错误调用被拒绝。

### Phase C：QD + 多目标 + 多保真搜索

- 图语法和 QD 档案；
- 每族局部连续优化；
- constrained multi-fidelity BO 调度；
- Pareto UI：性能、稳定、复杂度、证据等级和不确定性共同展示。

退出条件：等预算多种子搜索优于随机/单算法基线，且输出保留构型多样性。

### Phase D：工程闭环与独立验证

- 有限截面线圈、FEA、quench、低温、核热/TBR、热排出和维护；
- holdout 高保真 verifier；
- 失效/制造误差场景；
- 把候选分成 `numerical`, `physics-concept`, `engineering-concept`, `experiment-proposal` 四级。

退出条件：至少一个候选在完整任务约束下优于同任务已知基线的某个 Pareto 方向，并明确没有在哪些方向占优。

## 11. 第一轮应搜索什么，而不应搜索什么

第一轮不应允许任意三维线圈和任意等离子体拓扑同时变化，维度过高且最容易产生代理伪解。建议三个并行但不互相冒充的搜索域：

1. **Tokamak–QA continuum**：固定闭合环形磁面，扫描旋转变换由等离子体电流与外部三维场共同承担的比例；目标是降低破裂/电流驱动负担，同时约束线圈复杂度。
2. **QI/QS stellarator with maintainability**：在近轴或低阶边界空间搜索准对称/准等动力学，同时把有限截面线圈、端口、包层和扇区维护作为硬约束。
3. **Axisymmetric mirror mechanism map**：扫描 collisional GDT、classical mirror、tandem/plug、minimum-B/剪切流稳定机制，输出 Q、端损失、稳定功率和线性模块复杂度的 QD 地图。

三域各自通过已知装置回归后，再开放有限的“机制迁移”操作。这样新构型来自可解释的机制重组，而不是不受控的几何突变。

## 12. 本轮证据边界

本设计基于原始论文、同行评议概念设计、实验论文、官方技术资料与现有 LMC 源码审查。它建立的是研究系统架构，不宣称已经发现新聚变构型，也不宣称现有 LMC 分数代表真实稳定性或工程可建造性。后续每新增一个构型族，都必须新增该族的物理适用域、已知装置回归和独立验证器，不能只新增生成器。

## 13. Phase A 实现状态

Phase A 的软件底座已经实现于本目录的 Julia project：

- `Genome` 将 schema 中的 mission、拓扑、对称性、区域、场源、执行器、稳定机制、排热、工程和溯源信息解析为带类型 IR；
- 数量进入 IR 时统一到显式 SI-like 单位，等价单位产生相同 physics hash；身份、标签和 provenance 不参与 physics hash，但参与完整 content hash；
- family registry 拒绝不相容的场线类型或对称性；evaluator registry 区分 `full/proxy/missing` 支持；
- 结果契约强制 `unknown/not_applicable/error` 的值为 `null`，从类型层阻止“缺失即零风险”；
- `tokamak_axisymmetric_proxy_v1` 通过隔离 Julia 子进程读取现有 `optimized_coil_config.jl`，不修改旧模型，也不在错误构型或改动任务点上复用结果；
- 四个 seed 的机器基线记录在 `runs/phase_a_baseline.json`，新增
  `beam_2024_concept_seed` 作为高能经典轴对称磁镜的公式回归点。

当前覆盖审计再次确认：LMC 托卡马克 seed 的声明需求中为
`0 full / 4 proxy / 10 missing`；W7-X 没有适用的物理 adapter；WHAM 被
BEAM adapter 严格拒绝；BEAM 为 `0 full / 4 proxy / 16 missing`，且其代理
门本身未全部通过。因此 Phase A 证明的是跨构型软件边界、旧模型安全接入
以及首个磁镜公式回归，不是跨构型物理已经闭合。

## 14. 首次结构级 Quality-Diversity 搜索

在物理 adapter 尚未闭合时，系统已实现一个刻意受限的 MAP-Elites 式图语法搜索。六条变换规则均带论文来源、成立假设和必须新增的 evaluator：

- 托卡马克：外部准轴对称旋转变换、可拆卸高场 REBCO TF；
- 仿星器：QA/QH/QI 对称族、场周期和有限线圈数量基因；
- 磁镜：minimum-B 锚、串联双极势端塞、气动力学碰撞区间。

固定随机种子 `20260810`、250 次迭代的运行产生 134 个不重复结构，保留
41 个行为单元。档案描述符包含构型族、场线类型、对称性、场周期、旋转变换
来源、排热形式、执行器数量、磁场区间、稳定机制集合和镜机中央室区间。
同一命令连续重建得到完全相同的文件 SHA-256
`B181E8C276405EBFEF9B9AC81A4722AE24B84BD65B108C3F6AF51DDDFA46A795`。

这次搜索的 `performance_eligible_count = 0` 已不再是脚本固定值。每个候选都
经过 `science_gain_first_principles_v1`：目标为构型无关的设备复杂度、最小
稳定裕度、融合功率和融合增益，并以全模态稳定与工程可行为硬门。所有数值还
必须满足任务、燃料、适用域、单位、最低 fidelity、claim ceiling 和不确定性
要求。单元内的结构替换仍只依据 evaluator 覆盖等级与 `ir_complexity_proxy`；
后者只是 IR 记账量，不会被目标契约接受为装置简单性。生成结果见
`runs/structural_qd_seed_20260810.json`。

这一阶段证明“AI 可以在受物理语法和文献溯源约束下生成多样结构，并拒绝
越权排名”；还没有证明任何结构更稳定或产出更高。当前 133/134 个结构缺少
统一产出、稳定和复杂度指标；唯一 BEAM 点只提供 `fusion_gain` 与
`fusion_power` Fidelity-0 代理，全模态稳定、物理复杂度和工程可行仍为
`unknown`，因此也被门禁拒绝。下一硬门不再是门禁代码，而是托卡马克自由
边界、仿星器 VMEC/DESC 和磁镜各向异性平衡/m=1/输运等 Fidelity-1 证据。

## 15. 首个磁镜物理代理与公式边界

`mirror_beam_0d_v1` 实现 WHAM/BEAM 文献中的高能经典轴对称简单磁镜缩放：
有限 beta 有效镜比、经典平行约束、`Q`、NBI 功率、`N_rho`、FLR m=2、
90% 束吸收和快离子绝热性。它只适用于 100--200 keV、近垂直 NBI 的 BEAM
类定义域，明确拒绝 WHAM、GDT、tandem 和 minimum-B 候选。

BEAM 近似点回归得到 `R_eff=10.2062`、`Q_proxy=1.00886`、
`P_beam=6.34377 MW` 和 `P_fusion=6.4 MW`。但同一输入给出
`beta=0.3333 > 0.30` 以及 `N_rho=22.5 < 25`，所以 evaluation 为
`fail`。这保留了概念论文近似参数间的张力，没有反向调参制造通过结果。完整
公式、单位、适用域、不确定性与 unknown 清单见
`docs/mirror_beam_0d_v1.md`。

## 16. 证据分层 Pareto 门禁实现

`src/search/pareto.jl` 已实现：

- 任务和燃料绑定的 objective contract；
- hard constraints 先于 Pareto；
- `unknown/not_applicable/error`、错单位、低 fidelity、缺不确定性、低 claim
  ceiling 全部拒绝；
- 只在相同 evidence signature 内比较支配关系；
- 不同证据等级使用不同 Pareto tier，禁止低阶代理击败高保真结果；
- 每个被拒候选在 JSON 档案中保存具体缺项，供多保真调度器选择下一次求解。

因此当前系统已经能安全回答“为什么这个候选还不能称为更优”，但必须在下一
阶段补齐分族平衡、稳定、输运与工程求解器，才能回答“哪些候选确实在某个
Pareto 方向更优”。

## 17. 磁镜代理域内的首轮受约束进化搜索

在结构 QD 之后，系统新增 `mirror_beam_proxy_evolution_v1`。它不是跨构型最终
排名，而是在 `mirror_beam_0d_v1` 严格定义域内搜索连续参数：中央场、镜喉峰值
场、半径、长度、密度和 NBI 能量。算法以一个解析可行锚点避免小种群卡在全不
可行初始状态，随后用固定种子的 Pareto 前沿亲本选择、算术交叉和有界高斯变异
产生候选。

局部 screening contract 同时：

- 最大化 `fusion_gain`、`fusion_power`；
- 最小化 `absorbed_beam_power_proxy`、`effective_plasma_volume`；
- 强制 beta、90% 束吸收、`N_rho>=25`、FLR m=2、快离子绝热性、25 T 峰值场
  和有效镜比等全部代理门。

固定种子 `20260810`、32 x 16 的运行得到 512 个唯一候选，266 个通过代理硬门，
153 个保留在四目标代理 Pareto 前沿，文件 SHA-256 为
`27B3B4938FEB7792858DB03D0CC17F7C46B021981EF73923F7498F84982A6494`。
前沿的 `Q_proxy` 为 1.0003--1.1002，融合功率代理为 46.9--129.0 MW，吸收束
功率为 45.6--126.8 MW，有效体积为 16.4--38.6 m^3。

前沿明显靠近 23.6--25 T 峰值场、2.50--2.94 T 中央场和 100--115 keV 的低束能
边界。这是很重要的 optimizer-pressure 诊断：当前代理奖励了高峰值场和低束能，
但还没有磁体应力/淬火、全局 m=1、原子损失和横向输运来判断这些点是否真实。
所以 153 个代理前沿候选的 `first_principles_eligible_count` 仍严格为 0；它们是
下一保真层的选点集合，不是“发现了更优聚变装置”。

## 18. 首个真实 Fidelity-1 自由边界平衡接入

系统现已接入 FreeGS 0.8.2，而不是继续用 LMC 的解析 q-profile 冒充自洽平衡。
`tokamak_free_boundary_freegs_v1` 只接受显式 PF 线圈 R/Z 坐标、
`ConstrainPaxisIp` 压力/电流剖面、计算域、X 点与 isoflux 约束。FreeGS 官方
文档明确指出自由边界求解需要线圈位置、剖面和形状约束，并以 Picard 迭代闭合
非线性 Grad--Shafranov 方程。因此现有 ITER seed 只有 PF 数量、没有位置和剖面
输入时，适用域必须为 `not_applicable`，不能套用 TestTokamak 结果。

官方四线圈 TestTokamak 集成回归在 65 x 65 网格得到 44 次迭代、最终相对变化
`6.52e-5`、独立等离子体区 GS 残差 `0.00383`、`Ip=1 MA`。33/65/129 网格审计
中，65→129 的体积变化 0.17%、q95 变化 0.0045%、betaN 变化 0.20%，所有审计
阈值通过。Python runner、三网格审计和 Julia evaluator 产物均逐字节确定。

这仍只是求解器集成与数值收敛，不是已知装置实验回归。该 evaluator 对理想/
电阻 MHD 稳定、融合功率、复杂度、工程可行和净电继续返回 `unknown`，所以主
Pareto 门禁仍拒绝它。覆盖账本也只把 3 项平衡需求标为 `full`，把
`edge_heat_flux` 与 `finite_build_coils` 保持为 `missing`。下一托卡马克证据门是
使用公开 MAST-U/EFIT++ 重构数据做
已知装置回归；FreeGSNKE/Fiesta 的 2025 验证论文只提供验证协议，不能自动为
FreeGS 0.8.2 背书。详细接口、哈希和非声明边界见 `docs/freegs_fidelity1.md`。

## 19. 首个真实三维 Fidelity-1 平衡接入

系统现已在独立 Python/JAX 环境中接入 DESC 0.17.3，并对该版本随包提供的 W7-X
五场周期有限 beta 平衡执行固定边界 `lsq-exact` 修正。3 次迭代以 `gtol=1e-6`
成功停止；体积平均力残差相对磁压梯度为 `0.002847`，等离子体体积
`27.848 m^3`，体平均 beta 为 `2.023%`。固定 R/Z 边界系数最大变化
`2.78e-17 m`，压力、iota 与环向磁通在记录精度下未变。

这条接口严格绑定 `desc_builtin_w7x_0_17_3`、谱/网格阶数、系数数量和初始状态
指纹。原 `w7x_mechanism_seed` 没有可重建 Fourier 边界和剖面，仍必须返回
`not_applicable`，不能因为标签写着 W7-X 就借用结果。Windows 上
`jax-finufft` 没有 wheel，因此只启用不依赖 NUFFT 的固定边界力平衡；新经典与
快离子目标明确保持 `missing`。

该回归声明的 16 项需求只有 `vmec_or_desc`、`finite_beta_equilibrium` 和
`three_dimensional_force_balance` 三项为 `full`。Mercier、ballooning、Boozer、
新经典、alpha 轨道、岛偏滤器、热流、线圈曲率/间距/装配公差和端口全部仍是
`missing`；全模态稳定、融合增益/功率、复杂度、工程可行和净电则返回
`unknown`。所以第一性 Pareto 门禁继续拒绝它。

DESC/JAX/NumPy 版本、CPU 单线程归约和 W7-X 数据指纹均被锁定；Python 与 Julia
产物各自跨独立进程逐字节一致。VMEC++ 当前官方二进制只支持 Linux/macOS，因而
下一步是在 WSL/Linux 上用 VMEC++ 对同一显式 Fourier Genome 做独立交叉验证，
而不是在 Windows 上把缺失后端冒充通过。详细环境、指标和哈希见
`docs/desc_fidelity1.md`。

## 20. 公开磁镜 Fidelity-1 平衡接入与 RealTwin 边界

系统现已固定并运行公开 `eepeterson/pleiades` 的最后一个 `develop` 提交
`0161abb3`（2021-08-18，包版本 `0.2.0-dev`）。公开 WHAM 示例用轴对称线圈
Green 函数和标量 `P(psi)` 迭代静态平衡；它不是 2025 RealTwin 论文所述的
定制各向异性 Pleiades fork。RealTwin 将 CQL3D-m 分布函数积分成
`p_parallel(psi,s)` 与 `p_perpendicular(psi,s)`，再与平衡反复耦合，并把稳定性
交给 Hybrid-VPIC 等独立工具；论文还明确承认当时没有 edge-neutral 模型。

`mirror_isotropic_pleiades_wham_v1` 因而只接受精确的公开 WHAM 数值 fixture。
31 x 81 回归在 6 次迭代后达到 `9.02e-11`，独立固定点磁通残差
`4.45e-14`，有限差分力平衡相对残差 `0.02395`。31 x 81、46 x 121、
61 x 161 三网格中，中到细网格总电流变化 `0.0138%`，磁通扰动诊断变化
`0.530%`，细网格力残差低于 `1%`。轴上镜比直接取离散最大值会因网格是否
落在线圈中心而变化 `0.259%`，所以它只作为带 `0.5%` 阈值的采样诊断，不能
充当稳定性证明。

该基因组声明 16 项需求，只有轴对称 Green 场、各向同性镜平衡和有限 beta
平衡三项为 `full`。各向异性平衡、interchange、ballooning、DCLC、AIC、电子/
离子端损失、中性粒子、端板热流以及磁体工程共 13 项仍是 `missing`；全模态
稳定、约束时间、融合增益/功率、复杂度、工程和净电继续返回 `unknown`。所以
第一性 Pareto 门禁仍拒绝该 fixture，原 `wham_mechanism_seed` 也不会借用其结果。

文献门禁还加入了 2026 年 RealTwin corrigendum：原 POPCON 的 Powell hybrid
求根器曾在方程无有效根时把稳定最小值当成收敛点，生成不满足功率平衡的无效
工况。修正论文给出新的自洽工况并保留作者的概念级 `Q>5` 结论，但对本系统的
直接规则是：任何优化器 `success` 都不是物理可行证据，必须逐个记录并约束功率
平衡方程残差。详细环境、网格、哈希和下一后端缺口见
`docs/pleiades_fidelity1.md`。

## 21. 证据感知多保真提升调度器

结构 QD 已经能产生候选并说明其 Pareto 缺项，但原来的 `coverage_report` 只表示
“已注册且适用的 evaluator 理论上支持哪些 requirement”，不能表示该候选真的
完成过求解。`src/search/evidence_scheduler.jl` 因此把状态拆成四层：

1. **能力目录**：任务可能产出的非 unknown 指标、可提供不确定度的指标、
   requirement 支持等级、保真度、claim ceiling 和相对成本；
2. **已完成证据**：只接受任务版本相容、精确 `physics_hash` 相同且 bundle 状态为
   `pass/fail` 的实际运行；`error` 可重试，其他候选或版本的结果不能借用；
3. **候选适用性**：已安装 evaluator 仍必须逐个通过 `evaluator_applicability`；
   FreeGS、DESC 和公开 Pleiades 的严格 fixture 不会自动泛化到结构候选；
4. **研发状态**：`planned/blocked` 任务只进入 model-development 队列，永远不
   满足目标、hard gate 或 requirement。

默认目录现有 16 项任务：7 个 `available` 后端（包含 6 个 evaluator 和通用
Fourier builder）、8 个计划中的输入构建器/稳定性/系统/工程模块，以及 1 个被
公开后端能力阻塞的磁镜各向异性平衡任务。任务明确
列出真正可计算的输出；已有 adapter 为接口完整性而返回的 `unknown` 占位指标
不在 `metric_outputs` 中。

### 21.1 当前确定性 acquisition 基线

在尚无足够同构型、多保真配对数据训练可靠 GP 前，调度器使用透明规则：

- 一个缺失 hard gate 的信息价值为 12；
- 一个缺失 objective 为 6；
- requirement 从 missing→proxy、proxy→full 各计 1；
- 族稀缺度奖励为 `min(2, sqrt(N / N_family))`；
- 最终排序为 `utility * diversity_bonus / cost_units`，再以 task、design 和
  physics hash 确定性破同分。

这个分数只回答“固定预算下一步最值得获取哪条证据”，不预测稳定性、融合功率、
工程可行性或装置优劣。hard gate 权重大于 objective 是为了先减少伪可行候选，
而不是把 12/6 当成物理权重。未来可用 SAIL/BOP-Elites、约束 BO 和 cost-aware
multi-fidelity BO 的校准 acquisition 替换这部分，但四层证据门禁保持不变。

### 21.2 49 候选基线结果

运行：

```powershell
julia --startup-file=no --project=. .\scripts\run_evidence_promotion_schedule.jl
```

输入是结构档案的 41 个 elite，加上 FreeGS、packaged W7-X DESC、通用
Fourier-DESC 基准、4 个 Fourier pilot 子代和 Pleiades，共 8 个 Fidelity-1
候选；完成证据台账共 16 条。50 单位预算的结果是：

- 候选数 49；15 个有价值的 builder 动作为 `executable`，选中 6 个，成本 48；
- 8 个 Fidelity-1 候选均按 adapter 版本前缀和精确 physics hash 识别为已完成；
- 另有 50 项有价值的 evaluator 建议为 `input_incompatible`，没有把 fixture 或
  已生成子代的结果迁移到其他基因组；
- 160 项候选-任务组合进入 `backend_planned`，1 项进入 `backend_blocked`；
- 研发优先级前列是 common stability aggregator、integrated engineering、
  burning-plasma systems，随后是 stellarator input builder 和分族稳定/输运链。

六个选中项都是 `stellarator_fourier_input_builder_v1`。它们只创建带新物理哈希
的显式 Fourier 子代，然后由 DESC evaluator 另行运行；不会在父代上合成任何
数值或通过状态。九个同类动作因预算不足而确定性延后。计划/阻塞任务即使排在
研发优先级首位，也没有生成任何物理证据。

产物 `runs/evidence_promotion_schedule_seed_20260810.json` 连续两次逐字节一致：
内部 schedule hash 为
`8430cd5565a34b6c3919f658c82f02472327e9c86ca586d715bb53f8849e1c00`，文件
SHA-256 为
`4930C84DC87D66F1E78764D1D9BAAEA4F259F7B2F20589C2135A3599C935338A`。
仍有未被任何目录任务覆盖的 requirement 被逐项汇总在 `unschedulable_gaps`，供
下一轮扩展知识/求解器目录，而不是静默丢弃。

## 22. 从结构候选到新三维平衡：通用 Fourier-DESC 晋级链

上一节测得的关键瓶颈之一已经被解除：系统不再只能对 DESC 自带 W7-X 状态做
严格回归。新增 `StellaratorFourierBuildSpec` 把结构级 stellarator 父代转换为
一个新的、显式、有限维、可审计的求解器子代。v1 搜索图只含 5 个非零边界模态：
`R(0,0)`、`R(1,0)`、`R(0,1)`、`Z(-1,0)` 和 `Z(0,-1)`；搜索变量还包括场周期、
名义磁场、轴压强、轴/边缘 iota、谱分辨率、网格和 continuation 设置。所有变量
先经过几何、量纲、剖面、磁通和求解范围检查，再进入 DESC 0.17.3。

这个设计刻意把三种身份分开：

1. 父代只提供“stellarator 机制家族”的来源谱系；
2. builder 产生新的 `design_id` 与 `physics_hash`，不会把 W7-X 的准等动力学、
   岛偏滤器或线圈实现继承成新候选的属性；
3. DESC 证据只绑定新子代的精确物理哈希和 evaluator 版本，不能反向证明父代。

默认三场周期种子的物理哈希为
`e492f4b1f7763da63b44d284ea8f971a3c7b208478de58ebeb0595e3a5e8f854`。
它用 `p=5000(1-rho^2)^2 Pa`、`iota=0.45+0.15 rho^2` 和由
`B_nominal*pi*a_R*a_Z` 参数化的 `1.1781 Wb` 磁通运行自动 continuation。这里的
名义磁场不是线圈反演出的轴上场，只是显式磁通输入。

求解器 `success` 仍不作为物理接受条件。runner 独立检查：归一化力残差、固定边界/
压强/iota/磁通漂移、最终嵌套性和离轴采样的正 `sqrt(g)`。基准网格得到 5 个
continuation 状态、`0.0034007` 磁压力梯度归一化力残差、`14.8044 m^3` 体积、
`0.1812%` 体平均 beta 与 `0.06975` 最小采样 `sqrt(g)`，所有声明门槛通过。

`(4,4,3)/(8,8,6)` 与 `(6,6,4)/(12,12,8)` 的两分辨率比较也通过：体积变化
`1.23e-12`，beta 变化 `0.6705%`，力残差从 `3.40e-3` 降到 `5.45e-5`。这是一个
种子的两分辨率数值审计，不是连续极限证明。`rho=0.5/0.95` 上记录的场强峰峰值/
平均值只是坐标面诊断，不是 Boozer 准对称误差、新经典输运或快粒子约束。

调度目录因此从 15 项增至 16 项：通用 Fourier-DESC evaluator 和 builder 都已
`available`。在单种子里程碑，基线从 44 个候选变为 45 个候选，并增加第 12 条
完成证据。50
单位预算现在真正选择 6 个结构 stellarator 的子代构建动作，共 48 单位；已求解
子代被识别为 `already_completed`。builder 只表示“创建新输入”的可执行转换，
不会在父代上合成 terminal evidence。

这一步打通了“结构发现 → 可求解几何 → 真实三维平衡 → 证据台账”，但尚未打通
“更稳定、更高产出、更易工程化”。新子代 19 项 requirement 中只有显式边界、
DESC/VMEC 级平衡、有限 beta 和三维力平衡四项为 `full`；稳定性、输运、线圈、
排热、中子学、维护和结构工程等 15 项仍缺失，融合增益、功率、复杂度、稳定
裕量和工程 hard gate 继续为 `unknown`。详细输入、验收门槛、网格结果与复现命令
见 `docs/desc_fourier_fidelity1.md`。

## 23. 首轮有界多候选仿星器搜索

通用 runner 之后，系统进行了第一轮不是“单个手工种子”的仿星器搜索。候选生成
使用 9 维 Halton 低差异序列，16 个提案覆盖 NFP、长宽比、截面椭圆度、径向/
垂向螺旋幅度、轴/边缘 iota、轴压强和名义磁场。所有提案先经过
`StellaratorFourierBuildSpec` 的硬边界，因而不会把非法几何交给昂贵求解器。

当前没有足够的同构型真值去训练可信 GP，所以 acquisition 不预测装置性能。
它从归一化空间中心附近开始，随后做贪心 maximin，并优先补齐尚未出现的场周期。
选出的 pool index 为 `6,15,8,1`，分别覆盖 NFP `3,5,2,4`。这相当于一个
space-filling active-learning 基线；acquisition distance 只表示输入空间覆盖，不是
稳定性、产出或简易度分数。

为避免 Python import warning 状态和批次顺序改变单候选证据，每个候选都在新的
DESC 子进程中运行同一个 `desc_fourier_runner.py`。四个候选全部通过独立力残差、
固定输入、嵌套性和正 Jacobian 门禁：

| NFP | design 后缀 | 归一化力残差 | 最小 `sqrt(g)` | 体积 (`m^3`) | 体平均 beta | `rho=.95` 场强起伏 |
|---:|---|---:|---:|---:|---:|---:|
| 3 | `ac5c34be2b6275e5` | `0.005619` | `0.05012` | `11.277` | `0.001749` | `0.58646` |
| 5 | `ced5f0297610d4ac` | `0.007677` | `0.04730` | `10.669` | `0.001680` | `0.63508` |
| 2 | `8eebd0fff02ab6d1` | `0.001210` | `0.10702` | `21.569` | `0.001876` | `0.24486` |
| 4 | `8cfc61eb02be8e23` | `0.002392` | `0.05588` | `11.882` | `0.001560` | `0.49734` |

这个表没有“最优行”。尤其 NFP=2 的场强起伏较小，仍不能推出 Boozer 准对称、
低新经典输运、良好 alpha 约束、简单线圈、稳定或高净功率。4/4 只是 equilibrium
accepted，第一性装置资格仍是 0/4。

原始 batch、typed evidence 和调度器都逐字节复现。batch hash 为
`2fea80735654364d48837c22461921b08d6d356ae382c0b07a5dca77349c537e`，pilot
hash 为 `61fe4c0efec651894fbc920fddefd6b644573833635dbf2f5c20808c237cf0e9`。
四条证据首次进入调度台账时，状态为 49 候选、16 条完成证据；这四个子代均为
`already_completed`，不会重复消耗预算。

## 24. 下一证据层：从“有平衡”到“可能稳定且可工程化”

下一轮不能直接把 4 个候选送进融合功率排序。正确的晋级依赖图是：

1. **平衡复核**：每个候选做候选级两分辨率审计；优先候选再在 WSL/Linux 用
   VMEC++ 独立交叉求解。DESC 与 VMEC++ 不一致时，候选停止晋级。
2. **理想 MHD 稳定**：固定 DESC 0.17.3 源码和网格契约，分别输出径向
   `D_Mercier` 最小值与无限 n 理想 ballooning 最大增长率/特征值；不能把
   magnetic well 或平衡收敛当成稳定。系统只在两个门禁都通过且完成分辨率审计
   后，才允许生成 stellarator 局部稳定证据。
3. **对称性与输运**：Boozer 变换后的准对称误差、有效 ripple、新经典热/粒子
   输运和 alpha 轨道必须是不同指标。当前 native-Windows 环境缺 `jax-finufft`，
   不能把未执行的 NUFFT 目标标成通过；必要时在 WSL/Linux 建立单独版本绑定。
4. **线圈反问题**：从 plasma surface 生成有界 winding surface，先用 quadratic
   flux/Bn 误差求可实现线圈，再硬约束 coil-plasma 距离、coil-coil 距离、曲率、
   扭率、长度、链接数、场峰值与电流。DESC 0.17.3 本地源码已确认含
   `QuadraticFlux`、`CoilSetMinDistance`、`PlasmaCoilSetMinDistance`、
   `CoilCurvature`、`CoilTorsion` 和 `CoilLength`，但“类存在”不是结果证据。
5. **系统工程**：线圈几何通过后才能评估结构载荷、超导裕量、屏蔽/包层空间、
   端口、维护、偏滤/排热和中子学；这些共同形成 `engineering_feasible` hard
   gate。IR 节点数量或 Fourier 模态数不能替代装置复杂度。
6. **燃烧等离子体闭合**：最后才把输运、加热、电流/旋转驱动、杂质、辐射、
   alpha 加热、热转换和内部耗电闭合成 fusion gain、fusion power 与 net electric
   power，并携带模型和参数不确定度。

AI 层因此继续采用“约束优先的主动学习”：先用 cheap stability/coil screens
淘汰不可行点，再用 cost-aware multi-fidelity acquisition 选择独立输运和工程
求解；训练数据不足时仍退化为可解释的 maximin/QD，而不是输出未经校准的代理
均值。任何 hard gate 未知或失败，候选都不能进入跨族 performance Pareto。

## 25. 已实现的采样稳定性与主动学习闭环

本轮把第 24 节的前两项推进成可执行证据链，但没有把“局部有限采样有利”改写成
“装置稳定”。`StellaratorDESCStabilityV1` 在独立 DESC 0.17.3 进程中以中等
分辨率重求固定边界平衡，然后分别计算：

- 7 个 `rho` 上的 `D_Mercier * Psi^2`，全部必须大于等于 `1e-5`；
- 4 个 `rho`、8 个 `alpha`、15 个 `zeta0` 组成的 480 条场线上的无限 n 理想
  ballooning `lambda=gamma^2`，最大值必须小于等于 `-1e-5`。

所有结果先过固定输入、力残差、嵌套坐标、正 Jacobian、Mercier 项闭合和
ballooning 双 shift 提取门禁。第一轮粗网格曾把 NFP=2 候选的 Mercier 边缘值
算成 `-0.00344013`，中等网格变成 `+0.00234455`，因此粗网格分类被明确拒绝。
该候选后续在中→精细网格上保持 Mercier 正值和 ballooning 负值。

首轮 4 个 medium 候选中 3 个采样有利。随后用异方差 RBF GP 对 Mercier 与
ballooning 裕量分别建模，以 LOO 误差选择长度尺度，再用 joint margin、后验
不确定度、diversity 和 NFP 分层决定第二批算力。GP 选出 pool
`11,13,16,14`；真实 DESC 结果仍为 3/4 有利。但 pool 11 是重要反例：GP 预测
joint scaled margin `+0.3637`，实测却为 `-1.1419`，对应 Mercier
`-0.0114085`。所以 acquisition 只回答“下一次求解算谁”，不能回答“谁稳定”。

第二批 joint margin 最好的 pool 16（NFP=2）随后通过独立中→精细审计：
Mercier 最小值 `+0.0131808 → +0.0136804`，最大 ballooning lambda
`-4.7267e-4 → -3.0219e-4`，力残差 `8.0138e-5 → 6.0412e-5`；全部预声明
门禁通过。累计 8 个 medium 样本中 6 个有限采样有利，2 个候选通过中→精细
审计；`all_mode_plasma_stability_established` 和第一性装置资格仍都是 0。

加入第二批后，GP 使用 8 个观测，Mercier/ballooning scaled-margin LOO RMSE
分别为 `0.6450/0.2029`，说明 Mercier 代理仍很弱。第三批 pool
`9,12,10,7` 只是 `not_evaluated` 队列。连续面电流阶段加入后，当前调度台账为
53 个候选、20 个任务、27 条完成证据；50 单位预算仍只选择 6 个可执行 Fourier
builder，花费 48，
没有任何代理预测进入物理指标。

下一保真度优先级因此变为：对两个已审计候选做 VMEC++ 独立交叉求解；增加
finite-n、阻性、动力学与非线性稳定性；随后做 Boozer 准对称、新经典/alpha
输运、线圈反问题和集成工程。详细符号、扫描网格、逐候选结果、哈希绑定与复现
命令见 `docs/desc_stability_fidelity1.md`。

## 26. 已实现的连续面电流线圈可实现性代理

线圈证据链先实现了一个严格受限的中间层，而没有把 winding surface 上的连续
电流片称为可制造线圈。依据 Landreman 的 REGCOIL 公式和固定到 DESC 0.17.3
提交 `fcc29be` 的官方教程，runner 在 `0.25 m` 常法向偏置面上求解
`chi_B^2 + lambda chi_K^2`。这里 `chi_B` 惩罚 plasma surface 上的法向场，
`chi_K` 惩罚 winding surface 上的面电流密度；`lambda` 从 0 到 `1e-10` 共 12
点。求解包含有限 beta 平衡的 plasma current（`vacuum=false`），并检查面拟合、
偏置根残差、正面积元、相邻场周期采样间距、积分闭合和整条正则化曲线的单调性。

输入只选取两个已经通过 Mercier/无限 n ballooning 中→精细审计的 NFP=2 候选，
而不是先用线圈代理挑选候选。两者在基础网格上都达到仅用于比较的 `1%` 归一化
Bn 参考值。pool 8 的最小 Bn/B 为 `0.00257081`，满足参考点时 K-rms 为
`1.42242 MA/m`；pool 16 分别为 `0.000150595` 和 `1.84398 MA/m`。前者 Bn 更差
但电流较低，后者 Bn 更好但电流较高，因此没有单一“赢家”。

独立提高 winding-surface、电流势、场评估、source 和 virtual-casing 网格后，
pool 8 的整条 Bn 曲线最大绝对漂移为 `0.0326202`，超过预声明 `0.02` 门限，
所以审计失败；pool 16 为 `0.00728216`，且 K-rms 曲线最大相对漂移仅
`0.00175020`，全部门禁通过。即使 pool 16 通过，证据也只表示连续电流片代理在
这两档分辨率下稳健。

typed adapter 将 `finite_build_coils` 只记为 `proxy`，并把
`finite_build_coils_feasible`、`discrete_coil_geometry_feasible`、
`device_complexity_index` 和 `engineering_feasible` 保持为 null/`unknown`。
调度器因此新增一个可用连续面电流任务和一个仍为 `planned` 的离散线圈优化任务；
前者只能解锁后者，不能跨过工程 hard gate。下一步必须显式生成有限条线圈并审计
coil-plasma/coil-coil 距离、曲率、扭率、长度、电流、应力、超导裕量、容差、端口、
包层和维护空间。完整公式、门限、哈希和复现命令见
`docs/desc_surface_current_fidelity1.md`。

## 27. 显式离散线圈轮廓：一个必要的负结果

连续面电流审计通过的 pool 16 随后进入 `to_CoilSet` 轮廓切分。系统固定使用
refined winding surface 和满足 `1%` 比较参考时电流最低的电流势解，分别切出每
半场周期 4/6/8 条恒电流势轮廓；NFP=2 且采用恒星器对称，因此全机总数是
16/24/32。样条轮廓再拟合为 20 阶 Fourier XYZ 线圈，以消除直接样条微分产生的
虚假尖峰；runner 同时计算包含 plasma current 的总 Bn，而不是只算真空线圈场。

结果没有支持“连续电流片容易变成少量线圈”的假设：

| 全机线圈数 | 单线圈电流 | RMS Bn/B | 最小 coil-coil 距离 | 最大采样曲率 | 总线圈长度 |
|---:|---:|---:|---:|---:|---:|
| 16 | `-2.368 MA` | `0.258615` | `0.9767 m` | `1.8906 1/m` | `73.54 m` |
| 24 | `-1.579 MA` | `0.117642` | `0.6545 m` | `2.0576 1/m` | `110.31 m` |
| 32 | `-1.184 MA` | `0.0770762` | `0.4905 m` | `2.1637 1/m` | `147.08 m` |

增加线圈数显著降低 Bn，但 32 条线圈仍比来源连续电流片差 `10.89` 倍，三组都
没有达到仅用于比较的 `1%` Bn 值。这个趋势不能用距离参考“通过”来抵消，因为
线电流没有导体截面、绝缘、支撑、容差或载流密度。

更高离散度审计把轮廓/源点提高到 384、Fourier 阶数提高到 24、Bn 网格提高到
16x16、virtual-casing 网格提高到 12x12。16/24/32 条线圈的归一化 Bn 绝对变化
为 `0.028223/0.018931/0.011770`，整组未通过 `0.01` 门限；16 条线圈的最大曲率
变化 `10.0033%` 也略超 `10%` 门限。审计因此明确失败，而不是事后放宽阈值。

当时的调度器新增可用 cut-only 任务，并把下游受约束线圈优化保持为 `planned`。
cut-only 只提供 `finite_discrete_coil_contours=full` 和
`finite_build_coils=proxy`，不会生成 `discrete_coil_geometry_feasible` 或
`engineering_feasible`。这一负结果随后促成第 28 节的高网格 40/48 线圈路径，
而不是继续仅靠增加同一低分辨率轮廓数逼近连续电流片。

## 28. 从贴边最优到鲁棒裕量：48 条 filament 线圈

后续搜索没有把上述失败审计当成“线圈不可行”的证明，而是先诊断离散化。8x8、
10x10 和 12x12 的 filament Bn 出现强烈混叠，同一形状在低网格可呈现约 65%
虚假改进；28x28 到 40x40 才趋于稳定。因此系统先扩展到 40/48 条全机线圈，并
把基础 Bn 评估固定为 40x40、Biot-Savart 源点 512、virtual-casing 12x8。
48 条未优化线圈的 RMS Bn/B 为 `0.02611498`，且通过 40→48 网格固定状态审计。

第一条通过基础硬约束的 48 线圈解把 RMS Bn/B 降至 `0.01237654`，但扭率和
最大长度几乎恰好贴住 `0.1 1/m` 与 `4.9 m` 上限。同种子、破坏恒星器对称性的
1 mm 误差筛查随后 0/4 通过：磁场最坏只劣化 `0.109%`，失败集中在扭率
`0.12311 1/m` 和长度 `4.90282 m`。这说明主要问题不是场对微扰敏感，而是优化
目标没有制造裕量。

系统把这个负结果转化成下一轮冻结约束：名义扭率 `<=0.070 1/m`、最大长度
`<=4.895 m`、coil-coil `>=0.31 m`、plasma-coil `>=0.22 m`、曲率
`<=1.80 1/m`。v7 求解器收敛并达到 `52.13%` 基础场改进，但长度比新门限多
`2.642 um`，因此仍判失败。随后预声明 12 个近端插值点；比例 `0.99999` 是满足
全部名义几何门禁和 `>=50%` 场改进的最深点，比例 1 保持失败。

所选状态在独立 48x48 Bn、768 源点、16x12 virtual-casing、512 几何点审计中
仍通过：RMS Bn/B 为 `0.01289209`，相对同分辨率未优化 48 线圈改善 `50.83%`；
coil-coil/plasma-coil 最小距离为 `0.32187/0.24341 m`，最大曲率/扭率为
`1.37593/0.066661 1/m`，最大单线圈长度 `4.89499965 m`。

使用与旧解完全相同的物理线圈展开、随机种子和 Fourier 误差模型后，新解的 1 mm
筛查 4/4 通过，最坏 Bn 劣化 `0.106%`、扭率 `0.08812 1/m`、长度
`4.89778 m`；3 mm 筛查仍 0/4 通过，失败项仍是扭率和长度。这个 A/B 支持
“显式优化裕量改善小误差鲁棒性”的机制判断，但 4 个确定性样本不构成制造统计。

类型化任务 `stellarator_discrete_coil_optimization_desc_v1` 现为 `available`，
并把 pool-16 结果识别为已完成证据。它只对 optimized filament centre-lines 和
sampled line-current geometry 给出 `full`；`finite_build_coils` 与
`assembly_tolerance` 仍为 `proxy`，`statistical_manufacturing_tolerance_established`、
`finite_build_coils_feasible`、`device_complexity_index` 和
`engineering_feasible` 继续为 null/`unknown`。完整门限、来源、命令和哈希见
`docs/desc_discrete_coil_optimization_fidelity1.md`。

## 29. Boozer 对称谱与低阶有效 ripple：首个输运代理

pool 16 的固定边界平衡现在进入了独立于稳定性与线圈指标的输运代理链。系统重新
求解同一个显式 Fourier 平衡，并在 `rho=0.2/0.4/0.6/0.8/0.95` 同时计算预声明的
QA `(1,0)` 与 QH `(1,2)` Boozer `|B|` 非对称模态。精化结果的 RMS 分别为
`0.0115127/0.0959560`，所以在这一有限采样与这一指标下更接近 QA；这不是
“已实现准对称”，因为近似准对称不存在通用标量门槛。

高阶 `Bounce2D` 计算首先被真实执行，但 native Windows 环境缺少 `jax_finufft`，
NUFFT 调用链以 `NameError: options is not defined` 失败。失败输入和 traceback 被保留，
没有被改写为通过。随后采用 DESC 官方教程仍用于比较的旧 `Bounce1D` 有效 ripple
路径：基础/精化最大值为 `0.00743815/0.00748082`，都低于仅作比较的 `0.02`；
最大逐半径绝对漂移为 `0.00185377`，通过预声明 `0.002` 门槛但已很接近边界。

类型化任务 `stellarator_qs_effective_ripple_desc_v1` 因而只提供
`sampled_quasisymmetry_spectrum=full`、`boozer_transform=full` 和
`neoclassical_transport=proxy`。`high_order_bounce2d_available=false` 明确为 fail；
`quasisymmetry_established`、`drift_kinetic_transport_solved`、
`neoclassical_transport_feasible`、`alpha_orbits_feasible` 和
`transport_feasible` 仍为 null/unknown。调度目录现在有 23 项任务、31 份已完成证据，
pool 16 的 `neoclassical_transport` 从 missing 升到 proxy，但完整输运和整机硬门禁
没有跨越。公式、两档设置、失败证据、命令和固定哈希见
`docs/desc_transport_proxy_fidelity1.md`。

## 30. 矩形截面正则化自力、电感与 coil-only 储能

在 60 mm 方形 winding-pack 的有限截面 Bn 修正、间隙和 mutual-only 载荷通过
3x3→5x5 审计后，系统继续补上该阶段明确保留的自力与储能缺口。新 runner 采用
Landreman、Hurwitz 与 Antonsen 2025 年矩形截面高线圈长径比模型：论文式 (22)
计算数值平滑自感，式 (23) 计算产生截面平均自力的正则化场，并以
`dF/dl = I t x Breg` 得到自力线载荷。不同线圈间仍使用分离中心线 Neumann 互感，
48 条物理线圈的 coil-only 储能由 `0.5 I' L I` 得到。

加密结果的正则化自力场峰值为 `0.465859 T`，自力线载荷峰值/RMS 为
`0.367717/0.355928 MN/m`。与其他 47 个 winding pack 的场合并后，总 coil-only
线载荷峰值/RMS 为 `1.232655/0.999287 MN/m`。48 线圈储能为 `96.230176 MJ`，
共同电流幅值下的等效电感为 `0.308904 mH`。当前
`width*max(curvature)=0.082555` 只作为渐近小参数诊断，没有施加无来源的通用门限。

圆环 `Breg` 解析误差约 `1e-14`，圆环自感相对论文高长径比展开误差 `8.43e-5`；
实际线圈的直接式 (11) 与平滑式 (22) 相差 `9.56e-5`。3x3→5x5、48→72 载荷点、
96→144 电感点的加密审计全部通过；总载荷峰值漂移 `7.00e-4`，储能漂移
`1.30e-7`。

这个里程碑仍没有计算导体内部峰值场、等离子体电流场/耦合能、支撑应力应变、
真实导体截面分配、临界电流面、温度/应变裕量或失超保护。因此
`peak_internal_conductor_field_computed`、`thermal_or_superconducting_margin_feasible`、
`structural_stress_or_strain_feasible` 和 `engineering_feasible` 都保持 unknown。
完整公式、来源、门限、哈希和复现命令见
`docs/desc_regularized_coil_force_fidelity1.md`。

## 31. 60 mm 矩形导体包内部峰值场与等离子体外场

上一节保留的“正则化自力场不是导体内部峰值场”边界现已由一个独立适配器补上。
新 runner 按 Landreman、Hurwitz 与 Antonsen 2025 年式 (16)--(21) 计算均匀电流
矩形导体的 `Breg+B0+Bkappa+Bb`，并与作者 `CoilForces.jl` 固定提交
`45a21454` 的 `B0/K/Bkappa` 符号实现交叉核对。其他 47 条线圈仍用分离中心线
Biot--Savart；有限 beta 等离子体电流场用 DESC `K_vc=n x B/mu0` 在外部线圈点
做非奇异虚拟壳层面积分。DESC 自带 `compute_B_plasma` 是边界表面奇异积分器，
不用于这些外部导体点。

直矩形导体安培环路、中心对称、圆环中心场式 (97)、截面平均力
`I t x Breg` 四项基准全部通过。更重要的是，预声明门限后前三档数值审计没有被
改写为成功：等离子体场最大值漂移依次为 `14.99%`、`6.585%`、`5.219%`，都
超过 `5%` 门；对应失败文件和哈希全部保留。最终把外部虚拟壳层从 32x24 加密到
48x36 后，等离子体场漂移降为 `3.255%`，总峰值漂移 `0.0817%`，代表线圈与
截面边界分类不变，收敛链才通过。

通过层使用 40 个纵向点、每截面轴 13 点、每物理线圈 160 个 mutual 源点和
48x36 虚拟壳层。内部自场、其他线圈场、等离子体场、coil-only 总场和含等离子体
总场的采样最大值分别为 `5.079997`、`1.229044`、`0.657178`、`6.289636` 和
`6.619209 T`。这些标量分量的最大值不保证发生在同一点，不能直接相加。

类型化任务 `stellarator_rectangular_internal_field_desc_v1` 现在把
`peak_internal_conductor_field_computed` 与
`plasma_current_field_at_conductor_computed` 提升为 proxy/pass，并把目录扩展到
24 项任务、32 份完成证据。它没有选择超导材料或带材排布，因此
`winding_turns_or_tapes_resolved`、`nonuniform_current_distribution_computed`、
`superconductor_critical_surface_margin_feasible`、应力、热/失超和
`engineering_feasible` 仍为 null/unknown。完整失败链、最终哈希与复现命令见
`docs/desc_rectangular_internal_field_fidelity1.md`。

## 32. 横向机制扩展 v10：串列镜、动理学稳定器与剪切流 Z 箍缩

V9 的六个托卡马克低保真晋级点已经被候选特定 FreeGS/PF 审计全部退回，因此
下一轮没有继续围绕这些点局部调参。V10 保留原有 41 种组合为同外包络控制组，
新增六种串列磁镜机制/排气组合和两种剪切流 Z 箍缩运行方式；六个外包络下合计
294 个结构层。串列镜显式记账端塞势垒一致性、束流/ECH 功率、动理学稳定器压力
库存与补充功率、俘获粒子阻塞门禁，以及有限电压和径向建造空间。直接转换最多
回收模型中 50% 的带电端损失，不回收中子功率。

Z 箍缩分支采用独立圆柱脉冲账本：方位磁场由电流决定，压力和 D-T 反应率由同一
状态派生；脉冲时长、重复频率、剪切流、Alfven 速度、对流损失、流动库存、驱动
峰值功率、电极电流密度与两端靶热流均显式进入门禁。1995 年工作中的归一化剪切
约 0.1 只作为特定 `m=1` 模式的拒绝阈值，`m=0` 压力剖面另设门禁；FuZE 的中子
产额、持续时间、温度或密度没有被搬到 D-T 反应堆尺度。

正式 300,000 点 failure-aware MAP-Elites 搜索占据 2,699 个 QD 单元并构造 588
个显式图精英，所有图均一致，但五门同时通过数、显式正净电数和新机制晋级数都
为零。96 个磁镜精英全部失败于净电，91 个同时失败于增益；24 个 Z 箍缩精英全部
失败于增益与净电，并呈现剪切、粒子损失、峰值驱动功率和端靶热流的次级矛盾。
36 个直接转换精英的最大回收比例为 `0.4910973`，没有能量上界违规。

因此没有启动中保真计算。这个空队列只说明当前机制和约束盒内没有候选赢得下一
级计算，不说明串列镜或剪切流 Z 箍缩不可能。下一轮应继续横向改变损失路径和能量
回收的因果拓扑，例如长单元/多单元开放系统或保持完整脉冲吞吐账本的分级流动，
而不是放宽同一门限。完整来源映射、复现命令和声明边界见
`docs/mechanism_expansion_qd_v10.md`。

## 33. 开放端损失路径 v11：GDT/GDMT 与高 beta 磁尖点

V11 没有围绕 v10 的零晋级近前沿继续调参，而是改变开放系统的损失因果路径。
49 个 v10 组合全部作为只读控制保留；新增气体动力单磁镜、多磁镜端段及其普通端
扩展/受限直转换四种组合，再加入高 beta cusp 电子约束机制锚点和显式电子注入/
离子势阱候选。六合同下共 55 种结构、330 个结构层。

GDT/GDMT 模型不把碰撞性当自由基因。系统从搜索到的压力、密度和温度按 NRL
碰撞时间公式计算离子平均自由程，再得到中央气动力条件与单元 `nu*=l/lambda`。
多磁镜轴向信用上限为 4，离开适用碰撞区间时连续回落到 1；Bohm 参考横向损失
始终单独保留。NBI、涡旋偏压、有限线圈、两端接收器、壁热流和直转换建造/电压
均显式记账。直转换最多回收模型带电轴损失的 35%，不记中子回收。

Cusp 分支严格分离三层事实：实验观察到高 beta 时注入高能电子约束改善；低 beta
纯电子装置测得势阱；高 beta 准中性 D-T 等离子体中的离子约束和势阱持久性尚未
建立。因此系统可以计算有限多面体线圈、电子束电压/电流、势阱电容库存、离子/
电子回旋半径、诊断漏孔面积和 cusp 收集器热流，但高 beta 离子约束、准中性势阱
持久性和可靠漏孔模型三项保持不可被目标函数补偿的负门禁。

正式 300,000 点 failure-aware MAP-Elites 搜索占据 690 个 QD 单元并实例化 576 个
图一致精英，五门通过和晋级均为零。44 个新 GDT/GDMT 精英全部失败于增益、辅
功率、端热流、稳定代理和净电；42 个不满足单温气动力碰撞条件，22 个 GDMT 又
全部不满足单元碰撞条件和轴向外包络。多磁镜有效轴向抑制最高只有 `1.002282`，
说明当前 5--30 keV 单温盒中，长平均自由程使单元数几乎没有物理信用。

12 个 cusp 离子候选中有 7 个出现条件性正净电，但全部失败于离子约束、势阱持久
性、漏孔模型和收集器热流，因此没有被晋级。这个结果不是“正净电被忽略”，而是
证明多目标值不能抵消缺失的因果前提。证据隔离审计确认没有任何记录把电子实验
偷换为离子信用。

下一步模型桥接应按失败机制分叉：GDT/GDMT 需要温靶等离子体和快离子双群体，
显式计算 NBI 慢化、各向异性、微观不稳定性、电子加热以及轴/横损失；cusp 需要
自洽电子--离子 Poisson/准中性势阱和可容纳收集器的漏孔几何。二者在跨过这些
低--中保真桥接门之前都不应直接消耗全 PIC 或高保真 MHD 预算。完整来源、哈希、
复现命令和声明边界见 `docs/open_loss_pathway_qd_v11.md`。

## 34. 因果桥与负锚点 v12：双组分 GDT、IEC 与 DPF

V12 实施了 v11 指出的双群体桥接，而没有在旧单温模型上继续调参。55 个 v11
结构和方程全部作为只读控制保留；六合同中各增加双组分 GDT、双组分 GDMT、
栅极 IEC 中子源锚点、栅极 IEC 净电假设和 DPF 实验饱和锚点，共 60 种结构、
360 个结构层。后两个“锚点”概念被允许进入 QD 档案，但在类型层面永远不能晋级，
用于阻止 AI 把结构简单或实验出中子误学为电站可行。

GDT 因果桥显式分离温靶电子温度、温靶离子温度、温靶密度、快离子能量和两部分
beta。快离子慢化参考只在实验邻域内缩放；D-on-T 与 T-on-D 分别按实验室束流
能量的 `0.6` 和 `0.4` 计算 Bosch--Hale 截面，并使用不同弹丸速度。快离子库存、
慢化/直接损失、NBI 吸收与墙插效率、温靶轴向/横向损失、辐射、线圈、支撑和
热流全部闭合。GDMT 的多镜段信用仍按单元碰撞适用性衰减并封顶为 4，不允许
理想 `N` 或 `N^2` 外推。

IEC 分支把实验中子产出限制在乐观 `fusion/input <= 1e-5`，不给反应堆尺度持久
势阱或无界离子循环信用；净电假设保留 Rider 非平衡维持功率为硬负门。DPF 分支
将增益上限固定为 `Q<=0.01`，不允许高电流产额幂律无界延伸，并把电极寿命与
反应堆重复频率证据缺口设为硬负门。这样，负证据不是后处理说明，而是搜索空间
本身的一部分。

正式 300,000 点搜索占据 504 个 QD 单元，实例化 462 个图一致精英；完整临时目录
复跑得到相同结果哈希
`583fa8dacdafbd017db705fa4cb5a4f40b2eae1ad337ac14ec142844ce1f1bec`。
60 个新增结构精英中有 24 个负锚点和 36 个可晋级假设。11 个新增“五门通过”
全部是 IEC 中子源锚点：它们只通过受限中子源任务，净电全为负且类型上不可晋级。
两个显式正净电精英来自旧控制组，不是 v12 新赢家。

双组分修复确实消除了 v11 中由单温假设制造的主要碰撞性/稳定性冲突，但没有制造
电站。24 个 GDT/GDMT 精英均通过两群体、截面能量、NBI 库存和多镜段信用审计，
最大低保真聚变增益仅 `0.0542770`；最好的 GDMT 近前沿仍约为 `-90.33 MWe`，
快离子库存补充与墙插功率在净电闭合前已占主导。因此中保真队列保持为空，这只
拒绝当前声明域，不构成 GDT、IEC 或 DPF 的不可能性证明。

下一步不应放松门限追逐假赢家，而应把 v9--v12 已测失败标签提升为族中立的因果
路径语法和不确定性感知采集器：学习器只可加速拒绝、保持机制多样性或选择最有
信息量的缺失评估，不能替代未解决物理门。激光/惯性约束装置则应另建脉冲能量、
靶丸工厂、腔室清空、重复频率和壁载荷合同，不能被强塞进稳态磁约束账本。完整
来源映射、代码边界、复现命令和声明范围见 `docs/causal_bridge_qd_v12.md`。

## 35. 安全主动搜索 v13--v14：先保留失败，再修复门语义

在 v12 完成装置机制横向扩展后，系统转向 AI 采集层本身。V13 把 462 个封存精英
逐哈希重建，加入 360 个真实校准点，在 60 条因果路径内分别拟合局部核代理，再从
60,000 点池中选择 360 点做真实评估；每个“合同 × 因果路径”结构层至少保留一点。
代理只分配计算，永远不能通过物理门或进入中保真队列。

V13 的冻结 A/B 是负结果：同为 360 次真实评估，盲 Halton 五门通过 3 个，主动批
只有 2 个，最佳真实标量裕量也更差。根因不是录取越权，而是标签语义错误：把所有
报告裕量压成一个最小值，会让合法通过受限中子源任务的 IEC 锚点仍因反事实
`fusion_gain/net_electric_power` 被标成约 `-1`，也让不同家族的巨幅失败项互相混淆。
因此哈希 `4ecf0803...9afa7be` 被保留为“安全但无效”的算法负基线，没有被隐藏或
改写成成功。

V14 不修改 v13 结果，而是把标签拆成物理、工程、鲁棒、五门和正净电五层。候选
构建时已经能精确计算的名义物理/工程/净电事实定义严格排序层级；局部通过率只作
同层平局项，不确定性奖励封顶，不能抵消已知硬门失败。正式规则在查看测试区间前
冻结：v13 全池截止索引 `360360`，v14 smoke 后正式区间从 `361021` 到 `421380`，
与所有已看序列零重叠；盲基线没有进入主动模型训练。

完整复跑得到相同 v14 哈希
`6ce0cba4a0e74806cd5ea068e8f84a5bc94d644aaec61ff5891e4126988b8540`。
同预算下，物理命中 `12 vs 12`，工程 `35 vs 9`，鲁棒 `4 vs 3`，五门 `4 vs 3`，
正净电 `2 vs 0`，仍为零晋级。这个结果只有限支持“分层门比错误标量更合理”，
不构成普遍样本效率、校准概率、算法安全或收敛证明。

证据隔离仍然成立：主动批 4 个五门点全是不可晋级 IEC 中子锚点；2 个正净电点
全是仍缺高 beta 离子约束/势阱/损失模型的旧 cusp 条件候选。系统没有把两类性质
拼接成一个假装置。360 个结构层全部覆盖也意味着 317 个主动点仍来自廉价精确门
数为零的路径，这是“广泛探索”与短期命中率之间的明确权衡。完整算法来源、失败
历史、复现和声明边界见 `docs/safe_active_hierarchical_discovery_v13_v14.md`。

## 36. Laser inertial-confinement pathway extension v15

V15 adds a separate pulsed laser-ICF mission contract rather than reusing the
steady magnetic or magnetized-target semantics. It distinguishes target gain,
driver wall-plug energy, and average net electricity; represents indirect drive,
direct drive, and fast ignition across three chamber-protection choices; and
uses fuel-inventory, injection, clearing, average wall-load, and component-life
gates under three same-envelope contracts.

The 300,000-point deterministic plant search produces 489 QD cells and 57 explicit
graph elites. Fifty-four plant hypotheses survive the conditional conservation and
engineering robustness screen, and all 54 plant elites have positive net power
under their searched assumptions. None passes the independent target-gain,
repeat-rate driver, target-factory, and chamber/final-optics lifetime evidence
gates. The only five-gate passes are three non-promotable NIF single-shot science
anchors, one per chamber contract. Net-electric promotions remain zero.

This is a useful negative admission result: the system can represent and search
laser ICF without translating a target-gain experiment into a reactor claim.
Formal equations, evidence boundaries, audits, and hashes are in
`docs/laser_icf_qd_v15.md`.

## 2026-08-13 update: typed extensions, mission contracts, and v16 evidence routing

The horizontal search now has a versioned extension registry that leaves the
sealed base Genome and family-registry sources unchanged. Mission comparison is
typed: steady net electricity, pulsed average net electricity, fusion-neutron
sources, science gain, and single-shot target gain cannot silently enter the
same comparison set.

The v16 evidence router joins 27 laser-ICF conditional frontiers with 12
two-component magnetic-mirror and 6 IEC active-search records. The latter 18 are
parked by negative fidelity-0 net-power closure before evidence cost is assigned.
The ranked information-value field is explicitly a deterministic triage
heuristic, not a posterior feasibility probability. No v16 candidate has five
independently evidenced gates, so the medium-fidelity queue remains empty.

## 2026-08-13 update: five-layer attribute-graph grammar v17

The structural generator no longer depends on a complete list of hand-written
device paths. It composes five independently declared module layers using
required, alternative, and forbidden tags, then writes explicit dependency
edges, sources, and missing evaluator routes. The 116-module formal catalog
produces 1,129 unique compatible structures and a 1,000-member family-balanced
structural archive. This closes only the first representation milestone: every
member remains C0 and no physical, engineering, five-gate, or promotion credit
is granted before graph-to-Genome compilation and unified evaluation.

## 2026-08-13 update: graph-to-Genome executable breadth v18

V18 compiles the complete 1,000-member structural archive into 1,000 unique
typed Genomes. It preserves the five module IDs, graph hash, dependency edges,
mission contract, sources, and specialized evaluator requirements rather than
collapsing them into an opaque parameter vector. Semantic validation, family
validation, mission matching, and source traceability pass for every record.

Each of the 11 families now has an executable fidelity-0 rejection route. Six
common magnetic families use the composable same-envelope screen; RFP,
sheared-flow Z-pinch, levitated dipole, MTF, and laser ICF use their existing
family-specific screens. A route is explicitly a projection: it does not claim
that every selected module has a solved geometry. The projection limitations
and every still-missing declared requirement remain machine-readable and block
promotion.

The formal run has zero topology-graph errors. Three candidates close a
positive-net proxy ledger, but none passes all five gates, none has complete
declared proxy coverage, and no candidate enters or is authorized for medium
fidelity. This is the first executable open-grammar breadth baseline, not a
feasibility or superiority result.

## 2026-08-14 update: recoverable sharded execution v19

V19 separates deterministic candidate generation from execution recovery. A
run specification hashes the kernel identity and configuration; stable global
index ranges define the shards. Each completed shard is stored as an immutable
result object and becomes visible only through a subsequent atomic input-hash
commit. Run manifests and attempt states are atomically replaced, and every
cache hit revalidates the object content hash.

The formal infrastructure-only probe evaluates 50,000 synthetic records in 129
shards. Six shards fail on their first attempt, the resumed path is deliberately
stopped after 23 commits, and a third path reads a shared completed cache. The
uninterrupted, resumed, and cache-reuse paths all produce execution hash
`d6bf16ad7ed8ca5b249d20e37843862117ec1bc27253c3f71efc2c15acafbdaa`;
the cache-reuse path computes zero shards. This validates deterministic recovery
semantics, not the physical content or quality of a search. Concurrent worker
claiming, real v18-kernel integration, resource telemetry, and `1e7` scale are
still open.

## 2026-08-14 update: recoverable real cross-topology search v20

V20 maps stable global candidate indices onto the complete 1,000-member v17
archive and paired 24-dimensional Halton samples, then executes the existing
v18 family-specific fidelity-0 routes. Graph/module identity, mission contract,
sources, evaluator gaps, gates, and the varied physics hash remain explicit in
every retained record. The mapping covers all 11 families and no longer uses a
synthetic recovery kernel.

Concurrent workers now use atomic lease-directory creation and generation-based
stale-lease recovery over the v19 content-addressed commit model. The 1,100-item
correctness run gives identical hashes for uninterrupted, resumed, and
two-worker paths, while exercising four retries and an expired lease. A JSON
number-normalization bug (`0.0` versus `0` after generic parsing) was fixed at
all v19 hash boundaries before sealing these artifacts.

The first actual 10,000-candidate scale run evaluates every structure at ten
paired samples. Four Julia workers claim 25 disjoint shards each, and a second
pass reuses all 100 shard commits with zero recomputation. It produces 42
positive-net proxy ledgers, all laser ICF, but all 42 fail cheap robustness,
pulse/evidence separation, and minimal engineering closure. Another 698
mirror/Z-pinch candidates reach three gates but fail robustness and unified
low-fidelity physics. No record passes all five gates, closes declared coverage,
or enters medium fidelity. This is a measured rejection/failure-census result,
not a discovered fusion device. Full method and hashes are in
`docs/recoverable_cross_topology_v20.md`.

## 2026-08-14 update: failure-directed mirror geometry triage v21

The v20 maximum three-gate frontier contained 362 magnetic-mirror and 336
sheared-flow-Z-pinch records. V21 first audits evaluator identity and finds a
real interface gap: every mirror Genome declares a finite-build
`minimum_b_anchor_coil`, while the historical finite-coil evaluator recognizes
only the earlier `minimum_b_coil` name. V20 correctly left the requirement
unknown; V21 adds recognition only inside an out-of-order, rejection-only API,
so a geometry pass cannot manufacture horizontal or promotion credit.

All 362 mirror records run a recoverable reduced preview. A deterministic
module set-cover then sends 12 records spanning 22 five-layer module IDs to the
unchanged full finite-coil evaluator. Every preview is rejected, and all 12
full calculations still fail axis-field/mirror-ratio, open field-line envelope,
peak winding field, and membrane-stress gates. Full peak field is
164.43--167.73 T against 24 T; the support proxy is 21.81--23.71 GPa against
0.8 GPa. No anisotropic-equilibrium, end-loss, or medium-fidelity task is
authorized.

This is the intended use of AI acquisition under hard constraints: it locates
the nearest apparent frontier, tests the cheapest missing causal layer that can
reject it, preserves structural diversity, and stops downstream compute when
the layer fails. The result rejects the current quadrupolar-anchor projection,
not all mirror configurations. Mirror search must now expose coil topology and
field allocation as real genes; the then-unresolved 336-record Z-pinch frontier
is audited separately in v23, with non-ideal stability and electrode lifetime
treated as independent gates. Details are in
`docs/failure_directed_geometry_triage_v21.md`.

## 2026-08-14 update: variable mirror coil topology search v22

V22 projects every one of the 362 v20 three-gate mirror parents into three
explicit closed-current-path coil layouts and one paired five-gene geometry
sample per layout. The 1,086 preview calculations are distributed over 181
content-addressed shards; four workers cover every shard without overlap, and
cache replay is exact. A layout-aware QD archive retains 117 mechanism cells,
then six module-diverse records per layout receive the full geometry budget.

All 1,086 previews and all 18 full reviews are rejected. Split-Ioffe largely
repairs the extreme peak-field/stress failure of v21 but loses the transverse
minimum-B well. Baseball seams can form a well but retain coupled field,
resolution, clearance, and open-field failures. Yin-yang anchors form a well
but fail open-field-line integrity. Every layout fails axis field/mirror ratio.
This is a grammar-bounded negative result, not a rejection of mirror physics.
Details are in `docs/variable_mirror_topology_search_v22.md`.

## 2026-08-14 update: Z-pinch admission audit v23

V23 separates non-ideal spectrum admission from electrode lifetime for the 336
remaining v20 three-gate Z-pinch records. The old m=1 shear threshold is retained
as a reference diagnostic, while bounded m=0 PIC, gyrokinetic short-wavelength,
resistive/viscous, Hall/finite-orbit-width, and the recent ideal-spectrum model
disagreement define mandatory independent branches. An experimental ZaP-HD net
graphite erosion interval is bound to an intentionally optimistic full-electrode
inventory calculation and cannot grant lifetime credit.

The audit finds a still earlier failure: all 336 records are zero-frequency
single-pulse projections attached to the steady net-electric mission. They are
hard-rejected for task inconsistency. All pass the old m=1 scalar check, none
overlaps the bounded m=0 reference shear domain, and none has a candidate-
specific non-ideal spectrum. Because no record is repetitive, the electrode
one-year gate is explicitly not applicable rather than failed. Details are in
`docs/zpinch_nonideal_electrode_audit_v23.md`.

## 2026-08-14 update: mission-consistent repetitive Z-pinch search v24

V24 repairs the v23 mission mismatch before any medium-fidelity spend. Every one
of the 336 v20 Z-pinch parents produces a pulsed net-electric child with a
replaceable-solid-graphite boundary and a paired child with a flowing-liquid-
metal boundary. Five deterministic genes vary repetition, candidate-scaled
shear, the bounded m=0 profile coordinate, accelerator efficiency, and declared
power. The 672 candidates run in 56 recoverable shards; a cache A/B reproduces
all result and JSONL hashes with zero recomputation.

All children declare nonzero repetition and the correct pulsed mission. 421/672
enter the bounded PIC m=0 reference domain, and 194/336 solid cases pass the
deliberately optimistic one-year inventory bound. Neither observation grants
admission. Zero candidates pass all five horizontal gates or positive net-power
closure; candidate-specific all-mode spectra, solid/liquid boundary admission,
C1 credit, and medium-fidelity authorization remain zero. V24 therefore moves
the limiting question from mission inconsistency to robust unified physics,
engineering closure, non-ideal spectra, and repetitive boundary survival.
Details and sealed hashes are in
`docs/mission_consistent_zpinch_search_v24.md`.

## 2026-08-14 update: decoupled mirror field allocation v25

V25 repairs the remaining v22 field-allocation coupling without modifying the
sealed v22 negative baseline. Ten genes independently vary central/end axis
currents, end-axis positions, minimum-B anchor current, extent and phase, radii,
and nominal field share. The 362 v20 mirror parents receive two samples for each
of three layouts, yielding 2,172 rejection-only preconditions in 362 atomic
shards. Four live workers have zero claim overlap; a cache A/B later hits all
preview and full-review shards with identical hashes.

The precondition retains 769 records and 281 QD cells. Eighteen balanced strict
finite-build reviews are all rejected. The best baseball-seam record passes
peak field (17.16 T), support-stress proxy (0.232 GPa), clearance (0.222 m),
open flux-tube radius (0.948), and resolution, but fails the axis-field/mirror-
ratio gate and has a negative minimum-B well (−0.0151). V25 therefore narrows
the mirror residual rather than discovering a device. All anisotropic-
equilibrium, end-loss, C1, and medium-fidelity authorizations remain zero.
Details are in `docs/decoupled_mirror_topology_search_v25.md`.

## 2026-08-14 update: candidate-specific Z-pinch scale coverage v26

V26 returns to the paired v24 Z-pinch children but stops before an unjustified
high-fidelity spend. For all 672 candidates it reconstructs the sealed Genome,
checks the child physics hash, and derives an eleven-point `ka` scan together
with `k rho_i`, `k d_i`, Lundquist, magnetic-Reynolds, Mach, shear, pulse,
gyro-radius, and ion-inertial scales. The 56 recoverable shards reproduce from
cache with zero recomputation and unchanged result/JSONL hashes.

All 672 scale matrices are complete, 421 candidates overlap the bounded m=0 PIC
shear/Mach reference domain, and 529 satisfy the Mach-only portion. The sampled
domain spans `d_i/a = 0.0235--0.1053` and `rho_i/a = 0.00830--0.04224`, so Hall
and finite-orbit-width terms cannot be silently discarded. These values do not
predict growth rates. The ideal complex-frequency, resistive-viscous, Hall/FOW,
and kinetic branches each expose their missing profiles, closures, boundaries,
and solver; all four remain unresolved for every candidate.

The solid branch preserves 194 optimistic inventory passes and 142 rejections,
then separately blocks sheath/redeposition, temperature history, crack growth,
contacts/feedthroughs, and replacement availability. The liquid branch blocks
all 336 cases on material identity/properties, film geometry, free-surface MHD,
corrosion, pumping, feedthroughs, and off-normal inventory control. No spectrum,
boundary admission, horizontal five-gate pass, positive-net closure, C1, or
medium-fidelity authorization is created. Because all 672 candidates were
already horizontally rejected, v26 is a future solver-input contract and
failure map, not a reason to run four expensive spectrum solvers on the entire
set. Details are in `docs/zpinch_candidate_specific_coverage_v26.md`.

## 2026-08-14 update: ICF conditional-ledger falsification v27

V27 moves horizontally to the last v20 records that can look attractive in a
scalar report: 42 laser-ICF candidates with positive average net electricity
under searched assumptions. It reconstructs all 42 sealed graph/physics
identities, reruns the unchanged v15 evaluator, exactly reproduces every power
ledger, and solves only the algebraic target gain required for zero average net
power. Required gain spans 25.998--311.504; the searched values span
28.648--406.124 and exceed their break-even thresholds by only
1.102--1.304 times.

No record passes the conditional physics gate, conditional engineering gate,
or cheap robustness gate. The NIF N221204 gain-1.5 indirect-drive result would
not meet any candidate's algebraic zero-net threshold even before evidence
transfer is considered, and transfer remains explicitly forbidden. Each
record retains eight candidate-specific evidence requirements covering target
physics/mix, repeat-rate driver, target factory/injection, chamber recovery,
wall/blanket/optics, tritium, and integrated availability. Resolved evidence,
candidate-specific gain validation, chamber models, integrated engineering,
C1, and medium-fidelity authorizations all remain zero. V27 therefore removes
the apparent ICF positive-net frontier as a winner set and preserves it only as
a 12-cell falsification/QD map. Details and sources are in
`docs/icf_conditional_ledger_falsification_v27.md`.

## 2026-08-14 update: cross-topology stage telemetry v28

V28 instruments the unchanged v20 path at six explicit boundaries: candidate
binding, topology projection, Genome annotation, semantic/family/mission
validation and compilation, fidelity-0 prescreen, and record/gate
materialization. The deterministic plan measures 100 candidates from each of
the 11 families rather than weighting the profile by archive size. Eleven
family representatives are independently rerun through the original v20
function; all 11 instrumented records match exactly.

All 1,100 measured candidates complete with zero actual stage failures. Six
controlled faults, one per boundary, are attributed 6/6 to the intended stage
and kept outside candidate-failure statistics. On the current Windows host the
replay measures 68.5 candidates/s; wall and process CPU are close, and Genome
annotation plus topology projection dominate aggregate wall time and
allocation. Family rates range from roughly 50.7--130.0 candidates/s on the replay
(host- and run-specific). Process peak RSS remains a high-water mark, not a
per-candidate memory measurement.

The 1,100 deterministic records and result hash reproduce despite different
raw timing hashes. Timing, CPU, allocation, GC, and RSS therefore cannot alter
search identity. V28 completes the stage/resource-observability portion of
S3.1, but does not execute `1e7`, prove multiprocess scaling, modify a gate, or
create C1/medium-fidelity credit. Details are in
`docs/cross_topology_stage_telemetry_v28.md`.

## 2026-08-14 update: preregistered acquisition benchmark v29

V29 replaces the one-batch v14 comparison with five label-hidden, disjoint
Halton windows. Its preregistration fixes 60,000 proposals per window, 360
explicit evaluations per algorithm, four algorithms, metrics, and the decision
rule before any new label is evaluated. Historical v12/v13 records are training
evidence only. The four strategies are a stratified blind baseline, a simple
exact-gate failure-frontier QD rule, uncertainty-only exploration, and the
v14-style hierarchical gate classifier.

Across 1,800 conceptual evaluations per algorithm, blind / failure-QD /
uncertainty / hierarchy find respectively 16/26/9/22 five-gate labels,
16/26/9/22 robustness labels, 1/10/3/10 positive-net labels, and
49/168/24/168 engineering labels. Physics counts are 60 for all four. The
hierarchy strictly beats the blind discovery score in 5/5 batches and satisfies
the preregistered retention rule; it remains an allowed scheduler. No method
creates a promotion or medium-fidelity route.

The simpler failure-frontier QD rule also wins 5/5, exceeds the hierarchy in
five-gate count (26 versus 22), matches its positive-net and engineering counts,
and has a lower mean Brier score. Because v29's preregistered rule first decides
whether to retain v14, this post-result observation cannot replace the formal
recommendation. It becomes a new confirmatory hypothesis: test simple QD versus
hierarchy on fresh disjoint windows and, if non-inferior, prefer the simpler
default. The benchmark remains bounded to the v12/v13 causal-path domain and
does not prove transfer to the full 11-family grammar.

An initial replay exposed numeric JSON representation drift (`0.0` versus `0`)
in checkpoint hashes. V29 now normalizes every batch and record before commit
and binds checkpoints to source, preregistration, and runner hashes. Direct and
checkpoint paths reproduce result, batch, and 7,200-record hashes exactly.
Details are in `docs/frozen_acquisition_benchmark_v29.md`.

## 2026-08-14 update: frozen QD confirmation v30

V30 turns the post-v29 observation into a preregistered falsifiable test. Five
new Halton windows start after the final v29 window. Each batch freezes a
60,000-proposal pool and gives 360 explicit evaluations to blind Halton,
failure-frontier QD, and the unchanged v14-style hierarchy. The resulting
5,400 rows are disjoint from v29 and equal-budget by construction.

The confirmatory outcome is negative for the simpler challenger. QD versus
hierarchy has 2 strict score wins, 2 losses, and 1 tie. Aggregate QD / hierarchy
counts are 21/22 five-gate, 21/22 robustness, 10/10 positive-net, 60/60 physics,
and 171/171 engineering, with discovery scores 510.5/522.5. Both methods beat
the blind sentinel in 5/5 batches, so the failure is not explained by windows
with no discovery signal. QD nevertheless misses both the required 3/5 direct
wins and the no-decrease conditions for five-gate and robustness counts.

The preregistered recommendation therefore remains
`hierarchical_gate_v14_style`. The system will not keep searching the bounded
v12/v13 domain for a favorable QD window; the next algorithm question is
transfer to the v17/v20 11-family grammar. No method creates a promotion, C1
credit, or medium-fidelity route. Direct and five-checkpoint replay reproduce
result `90455c0e86d4e5855eaebfac4eee70cfebc287cce4162251ae53379bfc19a6c3`,
batch, and 5,400-record hashes exactly. Details are in
`docs/frozen_acquisition_confirmation_v30.md`.

## 2026-08-14 update: 11-family gate observability v31

Before transferring the retained hierarchy, v31 tests whether the v17/v20
labels support a fair five-gate comparison. Its label-blind deterministic plan
selects 100 unique candidates per family, normally as ten graph-hash strata by
ten Halton parameter ordinals. The eight-graph levitated-dipole family extends
to ordinal 13. This corrects an initial topology-only sample that underexposed
parameter-dependent engineering variation.

All 1,100 raw evaluator results reconstruct their v20 proxy hashes and map
exactly onto common topology, physics, engineering, outer-envelope, and
robustness semantics. Pass counts are 1100/0/59/1100/0. The 59 engineering
passes split into 10 magnetic-mirror and 49 sheared-flow-Z-pinch records; 20
ICF records retain conditional positive-net ledgers. No record has complete
declared evaluator coverage, every robustness loop is skipped because nominal
gates fail, and no family has physics-label variation.

V31 therefore separates authorization levels. Exact mapping and reconstruction
authorize a diagnostic 11-family failure-frontier search using continuous
margins and explicit failure states. They do not authorize a five-gate
algorithm-performance conclusion, C1, medium fidelity, or promotion. Unknown
evidence is not relabeled as physical failure, while computed proxy failure is
still recorded honestly. The deterministic result is
`60f69caeb5306c7cb41259e1cb0f9da72286491fac4a734e29ede9246fe721c1`;
details are in `docs/cross_family_gate_observability_v31.md`.

## 2026-08-14 update: diagnostic 11-family failure-frontier QD v32

V32 uses the authorization v31 actually granted. It does not compare acquisition
algorithms on degenerate Boolean labels. Instead, it evaluates candidate indices
10,001--32,000, which are 22 new Halton parameter ordinals for each of the 1,000
v17/v20 graphs. The 22,000 unique evaluations are split into 220 content-addressed
shards and executed by four recoverable workers.

For diagnostic ranking only, the raw minimum continuous margin is transformed
with each family's sealed v31 q10/q90 anchors. This monotone normalization does
not alter a physics or engineering threshold and cannot create a gate pass. One
archive retains the best near-miss for every graph; a second spans family,
explicit failure signature, normalized-margin bin, and missing-evidence-count
bin. Five records with distinct graph hashes per family form the 55-record
explainable frontier.

The run completes with topology/physics/engineering/envelope/robustness counts
`22000/0/624/22000/0`. The 624 engineering labels are concentrated in magnetic
mirrors (96) and sheared-flow Z-pinches (528). Sixty-three ICF and six MTF rows
retain conditional positive-net ledgers, but evidence-complete and actually
evaluated robustness counts are both zero. Consequently all 22,000 records stay
C0 and promotion, C1, medium-fidelity, novelty, and algorithm-superiority credit
remain zero.

The result is useful as a causal work queue, not as evidence for a preferred
device family. The next horizontal step is to decompose the 55 frontier records
into their limiting named margins and missing evaluator requirements, then make
model or grammar changes that can alter those failure mechanisms. Scaling the
unchanged domain directly to `1e7` would mostly reproduce already diagnosed
failures. Cache-only replay begins with all 220 shards complete, creates no new
commits, and reproduces the deterministic result
`80c039d0bdd724527d0a1b2a129f235057e71f9056e5846f1c57fcc34c2a4a73`
and all archive hashes. Details are in
`docs/diagnostic_cross_family_qd_v32.md`.

## 2026-08-14 update: frontier causal decomposition v33

V33 converts the five distinct-graph v32 records for each family into an
explicit repair queue. It reconstructs every raw v20 result rather than relying
on the compressed v32 row, verifies raw-result, graph, and physics hashes, and
sorts all executed nominal margins by their actual signed value. Missing
evaluator requirements remain a separate unknown-evidence ledger.

All 55 reconstructions match. Seven families share the same primary limiting
margin, `net_electric_power`, for all 35 of their retained records: FRC,
levitated dipole, magnetic mirror, spheromak, stellarator, 3-D tokamak hybrid,
and axisymmetric tokamak. The other family-consistent primary limits are MTF
`compression_work_authority`, ICF
`driver_wall_plug_and_repeat_rate_validation`, RFP
`on_axis_regular_current_profile`, and sheared-flow Z-pinch `particle_loss`.
Each accounts for five records.

The broader failed-margin census shows that net electric fails in 45/55,
fusion gain in 40/55, auxiliary power in 35/55, exhaust target heat flux in
35/55, and inboard build in 25/55. Remote maintenance is missing for 35 records;
edge transport and target heat flux for 15 each, detachment for 10, and ideal
MHD for 6. These counts reveal shared bottlenecks that v32's family-normalized
score could not safely compare.

The result does not yet distinguish a genuine cross-family energy-balance
barrier from a common-proxy bottleneck. The next step must add formula/gene/
module/evidence ownership and controlled local perturbations for each limiting
margin. Until that causal trace exists, changing a grammar solely to raise the
reported margin risks optimizer exploitation. V33 changes no threshold,
evaluates no new physics or robustness sample, and grants zero C1,
medium-fidelity, family-ranking, or promotion credit. Its deterministic result
is `1c270745569ac534e7a843ad9dfeabd30a22b25b0c6d814f9dc8309727387a07`;
details are in `docs/frontier_causal_decomposition_v33.md`.

## 2026-08-14 update: formula ownership and local proxy sensitivity v34

V34 follows the v33 bottleneck names into their actual evaluator sources and
projection inputs. For each of the 55 sealed records, it perturbs every one of
the 24 paired-Halton coordinates at `±0.02`, rebuilds and validates the Genome,
holds topology, family, evaluator, and mission contract fixed, and records both
changed numeric Genome paths and the primary-margin response. Formula sites and
the six adapter source hashes are sealed with the artifact.

All 2,640 perturbed evaluations complete and reproduce on an independent run.
No record crosses its primary margin locally. ICF's validation placeholder is
unaffected by all coordinates, as required: searched target variables cannot
manufacture experimental wall-plug/repetition evidence. The other families
have local directions that make the scalar less negative, but none creates a
gate pass.

The decisive audit result is structural. Each family contributes five distinct
graph hashes, but all five share one complete 24-coordinate primary-response
signature. This occurs in 11/11 families. Gene-path signatures sometimes differ
(FRC, ICF, RFP, and spheromak), proving that the genomes are not byte-identical,
but those differences still do not reach the leading margin. In addition,
30/35 net-electric-primary records use the same composable evaluator. The
previous seven-family net-electric pattern is therefore confounded by shared
model form as well as by actual power-balance deficits.

V34 changes the immediate engineering priority. The next horizontal gate is no
longer simply “sample more.” The compiler/evaluator contract must declare, for
every topology module, which candidate-specific equation, margin, and evidence
it influences. A module with no resolved influence is a hard unknown and cannot
participate in cross-topology ranking. Dynamic graph-ablation tests must then
show that meaningful topology changes alter an appropriate response while known
device and negative-anchor regressions remain fixed.

These are proxy implementation sensitivities, not physical causal effects or
uncertainty propagation. No topology, threshold, robustness loop, C1,
medium-fidelity route, or promotion changes. The deterministic result is
`bb8c55d557aa155dc2e5853c22dabcb3cba849fffa9c2a09eb25c3bf79954c26`;
details are in `docs/frontier_proxy_sensitivity_v34.md`.

## 2026-08-14 update: topology-module matched-pair influence audit v35

V35 turns the v34 family-level signature collapse into a module repair queue.
For each family it forms all ten pairs among the five distinct frontier graphs,
compares module sets, layers, Genome-path signatures, and missing-evaluator
ledgers, and retains whether the entire 24-coordinate primary-margin response is
identical. A one-for-one substitution in one grammar layer is marked separately
from a multi-layer co-difference.

All 110 graph pairs are primary-response aliases. Twenty-five are matched
single-layer substitutions, and all 25 remain aliased. Twenty-two pairs do
change compiled numeric paths, while 34 change missing evaluator requirements;
neither is sufficient to change the primary response. This produces 74
implicated modules and 24 tier-1 matched-layer entries. Shared engineering and
maintenance architectures lead the queue (`segmented_external_remote` 5,
`shielded_service_cassettes` 4, `demountable_rebco` 4,
`fixed_external_superconducting` 3), followed by MTF target/timescale, exhaust,
dipole, and Z-pinch modules.

The queue is not yet a license to add arbitrary penalties. V35 observes
co-differences, and even the matched layer swaps are not physical single-module
experiments. It also examines the leading margin response rather than every
secondary margin. Several families have multiple raw-result hashes or secondary
failure vectors even though the primary signature is fixed. V36 must seal the
complete named-margin/evidence response per graph and distinguish three cases:
an active secondary influence, a declared hard unknown, or a genuinely missing
compiler/evaluator connection. Only the third should trigger a new low-fidelity
formula; the second must block ranking rather than receive a guessed score.

V35 authorizes neither old-domain scale-up nor promotion. Its deterministic
result is `5c807e3e8ce3fcbc4fb8f27420258e4b215bbf6c5bd5835ede9df561b7a80384`;
details are in `docs/topology_module_influence_audit_v35.md`.

## 2026-08-14 update: complete margin, gate, and evidence response v36

V36 reconstructs the complete nominal response for each of the 55 sealed v34
frontier records instead of examining only the leading margin. Each record now
seals its 15--21 named margins, failed-margin subset, five raw gates, missing-
evaluator ledger, and raw-result hash. Candidate index, graph, physics hash,
module list, evaluator, baseline primary margin, and prescreen/raw-result hash
all reproduce. Five ICF v34 response signatures cannot be recomputed from their
JSONL values because signed zero was normalized during serialization; this is
recorded explicitly and the sealed archive SHA remains the input authority.

The full response changes the interpretation of v35. Forty-nine of 110 graph
pairs are aliases in both evaluated response and evidence. Twenty-seven vary
the named-margin response only, 22 vary the evidence ledger only, and 12 vary
both. Hence topology is not universally absent from every proxy path: complete
margin vectors differ in 39 pairs and evidence ledgers in 34. However, all 110
pairs still produce the same five Boolean gate dictionary on these frontier
records. The topology effects currently observed are therefore insufficient to
move the executed decision surface.

The 74-module repair queue is now routed rather than uniformly penalized. Four
modules have matched-pair secondary-response variation, two have matched-pair
evidence-only variation, and 18 remain fully disconnected in a matched one-layer
comparison. The other 50 only co-differ in multilayer comparisons and require a
controlled fixed-background ablation before any single-module interpretation.
The 18 disconnects are the strongest candidates for a sourced module-to-input-
to-equation-to-margin contract, but even they are implementation binding gaps,
not proof of a physical benefit or penalty.

V36 grants no single-module causal claim, gate pass, C1 status, medium-fidelity
authorization, or old-domain scale-up. Its deterministic result is
`c183755775153f6d87ecd264e1a64062ff82506b9b490372c9653d4aa927afe6`;
details are in `docs/full_margin_evidence_response_audit_v36.md`.

## 2026-08-14 update: disconnected-module influence contracts v37

V37 preregisters the implementation boundary for the 18 modules that remain
fully disconnected in at least one v36 matched one-layer comparison. Eight
groups cover physics stability, power/exhaust, and engineering/maintenance.
Every module is bound to its catalog source and claim boundary, semantic
candidate-specific inputs, existing named-margin targets, explicit missing
evaluator targets, eventual gate observability, and a fixed-background graph
pair. The output contains 21 unique matched cases, ten source records, 19 named
margin targets, and 17 evidence/evaluator targets across ten families.

This contract is deliberately more restrictive than a scoring patch. A repair
must change a preregistered candidate input and either the appropriate named
response or an explicit evaluated/hard-rejected evidence state in its matched
case. Constant module bonuses or penalties, missing-as-zero behavior, family-
external evidence transfer, and gate credit while a required solver is absent
are forbidden. Seven modules are physics-decision priorities, seven close
power/exhaust ledgers, and four close engineering/maintenance, but this routing
is not a ranking of scientific promise.

All 18 modules remain hard unknown. V37 implements no formula, chooses no sign,
and grants no gate, C1, scale-up, or promotion credit. Its deterministic result
is `d212d5a4514a7af0ff80e97614aaac0000063fee654f0f7f3b1e73471240c159`;
details are in `docs/disconnected_module_influence_contract_v37.md`.

## 2026-08-14 update: tier-1 hard-unknown evidence routing v38

V38 executes the evidence-routing portion of the seven v37 tier-1 physics
contracts for dipole, MTF, and Z-pinch modules. Fourteen module-specific
candidate requirements are bound to eleven source records and applied to eight
sealed fixed-background substitutions, producing thirteen graph responses.
Favorable-curvature and rotation-feedback dipoles, three MTF mechanism routes,
and axial-shear versus Hall/FLR Z-pinch routes now request different evidence
rather than collapsing to the same missing-evaluator ledger.

All 8/8 matched cases have different module-specific and effective evidence
signatures, while all archived numerical named margins and raw five-gate values
remain unchanged. This reduces the v37 matched full-disconnect count from 18 to
11. It is an executable topology-to-evidence connection, not an executed
stability, transport, implosion, or power calculation. Eight of thirteen graph
records also preserve the sealed v36 margin signature because JSON serialization
normalized signed zero; that archive limitation is recorded rather than hidden.

V38 grants zero numeric-margin changes, raw-gate changes, solver executions,
formula implementations, direct-gate credit, C1 states, medium-fidelity calls,
scale-up authorizations, or promotions. Its deterministic result is
`1f79ce865486863b4325be09301e604c9bf09fc22f2eba2e96f350189751b6bd`;
details are in `docs/tier1_module_evidence_ablation_v38.md`.

## 2026-08-14 update: remaining power/exhaust and engineering routes v39

V39 connects the other eleven v37 matched full-disconnect modules: seven
power/exhaust choices and four external-coil engineering/maintenance choices.
The overlay defines forty unique candidate-specific hard-unknown requirements
and binds them to ten source records. A new append-only source catalog corrects
the compact liquid-limiter route from an unrelated FRC review to the RFX-mod
liquid-lithium limiter experiment, and adds direct FuZE electrode/device and
DEMO maintenance/attachment constraints.

Unlike a case-local scoring patch, each graph carries all v39 routes for all
covered modules it contains. The thirteen fixed-background comparisons are
accepted only when the symmetric difference of their routed-module sets equals
the contracted topology substitution. Fifteen of 21 unique graph responses
carry one v39 module and six carry two. All 13/13 cases differentiate both the
module-specific signature and complete effective evidence ledger while
preserving every v36 numerical margin and raw gate.

V38 and v39 cumulatively connect all 18/18 v37 full disconnects at the evidence-
routing layer. This does not mean their physics or engineering is solved. V39
executes zero solvers and formulas, changes zero margins or gates, and grants no
C1, engineering-evidence upgrade, medium-fidelity, scale-up, or promotion
credit. Its deterministic result is
`563162db984b0dc85033992e408840df1d50649c8941b3af53246396bac4ff83`;
details are in `docs/remaining_module_evidence_ablation_v39.md`.

## 2026-08-14 update: multilayer fixed-background ablation v40

V40 performs the controlled intervention that v36 required for the 50 modules
previously visible only through multilayer co-variation. It reconstructs 20
family-layer groups, enumerates all 41 module-choice pairs within those groups,
and holds the other four layers plus the Halton sample fixed across each of five
sealed frontier backgrounds. This creates 205 preregistered trials using the
existing v20 fidelity-0 kernel; no new numerical formula is inserted.

Sixty-four trials compile and produce 150 unique counterfactual graph
responses. Twelve trials change an evaluated response, two change the evidence
ledger only, and 50 are complete response-and-evidence aliases. The changed
responses are confined to two ICF named margins, while the evidence changes are
confined to four stellarator requirements. All raw five-gate dictionaries stay
identical. At module level, three ICF drive choices expose controlled evaluated-
response routes, three stellarator choices expose controlled evidence routes,
21 choices remain full aliases, and 23 cannot be changed alone on the sealed
frontier backgrounds because another layer has an explicit dependency.

The 141 structural rejections are useful design information, not family or
module infeasibility proofs. They show that the next intervention unit must
sometimes be a coupled two-layer block, such as ICF target factory plus chamber,
stellarator drift control plus core symmetry, or FRC/RFP/spheromak stability
plus formation/drive. V40 therefore narrows the repair work but does not move
the search decision surface: gate changes, medium-fidelity authorization,
scale-up, and promotion all remain zero. Its deterministic result is
`399c80500bed099b7f770431f4468600d80f6f658bfb47f757aff2af0762c996`;
details are in `docs/multilayer_fixed_background_ablation_v40.md`.

## 2026-08-15 update: dependency-closed block ablation v41

V41 closes the structural-intervention gap left by v40 without weakening the
typed grammar. For every one of the 141 rejected single-layer counterfactuals,
it exhaustively searches all 1,129 compatible v17 assemblies for the legal pair
with the fewest compared layers, fewest repaired support layers, and smallest
source-background Hamming distances. Both sides then run at the original Halton
sample through the unchanged fidelity-0 kernel.

Fifty-six rejected trials can be recovered as matched single-layer comparisons
after both sides share a repaired support background. Eighty-five require a
true two-layer block, so their effects cannot be assigned to one module. All
141 trials are resolved; 41 change an evaluated response or evidence ledger,
while 100 remain complete aliases. Raw five-gate changes remain zero. The 23
v40 structural modules now divide into one matched route (`stellarator_qi_drift`),
ten coupled-block routes, and twelve dependency-closed aliases.

This removes structural non-intervenability as an undifferentiated queue, but it
does not establish physical benefit or infeasibility. The next implementation
units are 21 v40 single-layer aliases, twelve v41 block aliases, ten two-layer
routes, and seven observed matched/single-layer routes requiring known-device
and negative-anchor regression. V41 grants no gate, evidence-level, medium-
fidelity, scale-up, or promotion credit. Its deterministic result is
`7e6c8d35fe7a6cddd5c3aa1d002f9a55b5e4703b299a65aba2ced92e08a85607`;
details are in `docs/dependency_closed_block_ablation_v41.md`.

## 2026-08-15 update: candidate-specific formula reuse v42

V42 converts the v41 alias inventory into an executable formula-readiness
audit across all 50 modules. It selects only modules whose candidate inputs can
be mapped to existing numerical owners without importing device performance:
four magnetic-mirror field/exhaust modules reuse v9-v11, and two RFP field
modules reuse v7-v8. The simple-mirror direct-converter path composes the exact
v10 charged-end-loss allocation, recovery, voltage/build, field, and energy-
conservation equations with the v9 mirror ledger. The RFP boundary-only path
removes the PPCD actuator and its power/control genes from the registered
combined branch rather than inventing a boundary-control gain.

Of 15 complete-alias source trials, 12 now vary candidate-specific named
margins and five change `minimal_engineering_closure`; all 23 unique responses
have zero topology-graph errors. Three simple-plug/tandem-plug comparisons on
gas-dynamic backgrounds remain aliases because the current v11 GDT model does
not resolve plug hardware. At module level the inventory changes from 17
observed / 33 aliases to 23 observed / 27 aliases. The remaining aliases are
split into 9 ICF quantitative-evidence hard unknowns and 18 candidate-specific
solver/model gaps. There are still zero five-gate passes, coverage-complete
responses, medium-fidelity authorizations, or promotions. The deterministic
result is
`88b90f3e1f46af7280845ce6a83d8aa6e75c804accd10a84b685d2f5c0e609ec`;
details are in `docs/candidate_specific_formula_reuse_v42.md`.

## 2026-08-15 update: cross-family known-device anchor regression v43

V43 separates three evidence axes that previous module accounting could not
distinguish: route-level experimental direction, family-level known-solution
solver control, and candidate-specific executable module validation. All 23 v42
observable routes are bound to an append-only primary-source overlay. Eight have
experimental directional anchors (NIF indirect drive, the LDX supported/levitated
pair, MST PPCD, RFX-mod boundary control, and the W7-X island divertor), 14 have
only source/design lineage, and `supported_dipole_cartridge` is blocked by a
source-family mismatch because its current source is the magnetic-mirror MARS
study.

Three sealed solver artifacts are checked in both directions. FreeGS, Pleiades/
WHAM, and DESC/W7-X pass all required known-solution metrics, and each preserves
the declared unknowns that prohibit interpreting equilibrium convergence as
stability, transport, engineering, or net-electric closure. Only mirror and
stellarator are target-family solver baselines; tokamak is a global out-of-set
sanity control. None of the three validates a v42 module identity.

The central result is therefore 0/23 candidate-specific executable route
validations, despite 8/23 experimental direction anchors and 3/3 passing global
controls. V43 authorizes no gate credit, medium fidelity, scale-up, or promotion.
The next highest-value work is to turn the measured RFP and LDX pairs into
executable route regressions, then build mirror end-loss/plug/direct-conversion,
MTF chamber, and stellarator QA/QH/QI route fixtures. Formal artifacts and claim
boundaries are in `docs/cross_family_anchor_regression_v43.md`.

## 2026-08-15 update: experiment-anchored directional replay v44

V44 executes four fixed-background response probes for six of the eight v43
experimentally anchored modules. The v7 and profile-coupled v8 PPCD paths both
reproduce a fourfold confinement-time ratio at full current-profile control;
the RFP boundary block reduces the particle-loss proxy while increasing field
and retaining its power ledger; the LDX levitation coordinate increases the
confinement proxy and reduces particle loss.

These are not independent validation results. The PPCD multiplier is explicitly
calibrated from the MST result, so the two passes are circular implementation
replays. The boundary and saddle identities still share one proxy response
block. Most importantly, the low-levitation LDX endpoint violates the current
levitated-only topology graph, proving that the supported-dipole comparison is
not structurally executable. V44 therefore reports 4/4 direction checks, 3/4
two-endpoint graph-valid pairs, 6/8 mapped anchor modules, but 0 independent
known-device and 0 candidate-module validations. No gate credit, medium fidelity,
scale-up, or promotion is authorized. Details are in
`docs/experiment_anchored_directional_replay_v44.md`.

## 2026-08-15 update: explicit dipole support topology regression v45

V45 turns the LDX supported-versus-levitated comparison into two actual
candidate graphs. Both use the same `outer_small_B3_v1` envelope, exhaust
layout, and non-support continuous genes. The levitated route keeps the
floating internal coil, external levitation hardware, and hot-cell retrieval
path. The supported route removes the levitation coil, replaces the field
source with a mechanically supported internal ring, declares four finite
supports, adds a support-intercept loss region and core-to-loss edge, and uses
a replaceable supported-coil cartridge path.

Both graphs pass the generic genome validator, the dipole family registry, and
the v45 support-aware graph contract. Their structural and physics hashes are
different. Reusing the unchanged v7 `0.65 + 0.35*levitation_quality` response
also gives the measured LDX direction for confinement, particle loss, and the
stability proxy. That is an implementation and structural-direction replay,
not held-out magnitude validation. The legacy v7 evaluator still rejects the
supported route, as expected, while the v45 adapter makes the missing topology
explicit.

The v17 MARS source mismatch is corrected only in an append-only v45 overlay;
sealed v17-v20 artifacts are unchanged. Two of the 23 v43 observable routes
are now candidate-specific and structurally executable, but independent
validation remains 0/23. Support conduction, material-temperature properties,
nuclear heating, lifetime, finite-beta equilibrium, transport, engineering
closure, medium fidelity, and promotion all remain unresolved or zero. Details
are in `docs/dipole_support_structural_regression_v45.md`.

## 2026-08-15 update: support-aware full-archive integration v46

V46 routes the v45 supported/levitated dipole distinction through the actual
v17/v20 broad-search kernel. The sealed formal run evaluates two paired Halton
samples for each of 1,000 archived assemblies: 2,000 candidates, 20 recoverable
shards, and 1,000 graph-keyed QD cells. The first run commits all shards; the
same-cache replay has 20 cache hits, zero new commits, and identical execution
and candidate-record hashes.

The integration preserves all 1,984 non-dipole v20 core records exactly. The
remaining 16 candidates use explicit dipole graphs: eight mechanically
supported and eight levitated. All are graph-valid, all eight legacy supported
misroutes are corrected, and the MARS magnetic-mirror source is absent from the
dipole route. The two support modes have distinct structural graphs, while all
16 parameterized candidates have distinct physics hashes.

This closes an actual broad-kernel routing defect, not the dipole physics or
engineering problem. The v7 fidelity-0 equations are unchanged; v17 stability
and exhaust modules are still identities rather than solved geometry. Support
heat leak, materials, nuclear heating, lifetime/replacement, finite-beta
equilibrium, transport, and held-out magnitude validation remain hard unknown.
Independent route validation, complete five-gate, medium-fidelity, and
promotion counts therefore remain zero. Details are in
`docs/support_aware_cross_topology_v46.md`.

## 2026-08-15 update: cross-family held-out quantitative benchmark v47

V47 separates calibration, experimental direction, held-out magnitude, and
candidate promotion into distinct records. Three later or disjoint primary
sources define five route requirements: absolute MST PPCD confinement time,
paired LDX supported/levitated density and stored-energy ratios, and W7-X
island-divertor radiation, target load, and particle-flux response. The
factor-two benchmark tolerance is explicitly a protocol gate, not a fabricated
measurement uncertainty.

The existing RFP routes produce numerical confinement-time predictions, but
the predicted-to-measured factor errors are 5.10 and 7.65. More importantly,
their v44 midpoint inputs do not reconstruct the held-out MST discharge, so the
result is a benchmark-readiness failure rather than a clean physical
falsification. The structurally explicit v45 dipole routes do not predict the
reported density or stored energy, and the current stellarator boundary route
does not predict radiated-power fraction, divertor load, or particle flux.

Consequently, all five routes have calibration-disjoint held-out requirements,
two have an executable numeric comparator, zero pass, three are fail-closed on
seven missing output classes, and zero reproduce a held-out operating point.
Independent known-device magnitude validation and candidate-specific route
validation remain 0/5 and 0/23 respectively. No gate, medium-fidelity,
scale-up, or promotion credit is granted. The deterministic result is
`1b8a9c60fab1e0955bb0705f0c50b2758934d6a31ac53b1cec6f92b9525cc0e2`;
details are in
`docs/cross_family_heldout_quantitative_benchmark_v47.md`.

## 2026-08-15 update: cross-family confinement provenance and applicability v48

V48 applies the principle “share metric semantics, not an unjustified universal
formula” to the complete common-envelope archive. It regenerates every sealed
v46 core and audits 1,642 candidates across tokamak, 3D tokamak hybrid,
stellarator, magnetic mirror, FRC, and spheromak branches against five primary
source records. The remaining 358 candidates are explicitly outside this
specific audit, not counted as passes.

The result separates four levels that had previously been easy to conflate:
algebraic reproduction, source-domain applicability, candidate-specific
validation, and ranking/promotion authority. Current algebra is exactly
reproduced for 1,420 candidates. Nevertheless, none is source-domain complete:
the tokamak grammar does not declare the ELMy H-mode regime of IPB98(y,2);
ISS04 has no candidate-specific empirical configuration renormalization; mirror
beam energy is fixed at 100 keV, not searched, and not consumed as a model
input; the FRC Bohm reference has a `T^-1` direction opposite the C-2/C-2U
`T^1.8` direction anchor; and no family-specific spheromak confinement scaling
has been regressed. The 3D hybrid inherits both unresolved parent domains.

Accordingly, source-domain completeness, candidate confinement comparison,
common ranking, medium-fidelity admission, and promotion all remain zero. V48
is a horizontal falsification and model-governance advance, not new evidence
that any family or candidate is infeasible. The deterministic result is
`b4b7f7d3d8775001ebbfd55572c064293a5d5770069bc7eac61e04862d22ac65`;
details are in `docs/cross_family_confinement_applicability_v48.md`.

## 2026-08-15 update: mirror beam-energy intervention v49

V49 turns one v48 audit finding into a real search intervention. It adds a
canonical beam-energy gene to every sealed magnetic-mirror candidate,
synchronizes the NBI component declaration, and consumes 25/100/150 keV in the
WHAM-reported `E_beam^1.5` factor while holding every other normalized Genome
field fixed. The 724 candidates from 362 assemblies produce 2,172 trials and a
1,086-cell diagnostic QD archive whose selector never uses performance.

All 2,172 trials reproduce the preregistered confinement-time ratio; 724/724 at
100 keV reproduce v48 and all 1,448 nonbaseline interventions change the
source-complete power/exhaust response. This demonstrates successful
gene-to-formula wiring. It does not produce a viable candidate: every energy
bin has zero physics-gate passes, engineering-gate passes, or positive-net-
electric responses. Fusion gain and net electric power fail for all 724
candidates per bin, coil curvature fails for all 724, and reducing the beam
energy to 25 keV increases exhaust failures from 266 to 628.

The primary equation is a classical particle-confinement estimate, so its use
as an energy-confinement law remains an explicit hard unknown. Effective mirror-
ratio semantics, fast-ion distribution/injection, finite-beta equilibrium,
atomic losses, rotation-power closure, and held-out magnitude validation also
remain missing. Source-domain completeness, ranking authority, medium fidelity,
and promotion remain zero. The deterministic result is
`51e0c6780f099896fc99c802d3fea8a8781ab3bb8dce62dbff7013c83d12a8ff`;
the dedicated validator and all 74 Julia test groups pass (v49: 67/67).
Details are in `docs/mirror_beam_energy_intervention_v49.md`.

## 2026-08-15 update: tokamak operating-regime access intervention v50

V50 converts the v48 IPB98 applicability finding into a fixed-background
counterfactual gate. It gives each of the 360 sealed axisymmetric-tokamak
candidates an explicit binary ELMy-H-mode declaration and evaluates both
states, producing 720 trials and 360 diagnostic QD cells. The declaration and
full applicability payload change for every pair, while the current confinement
and performance payload remains unchanged for all 720 trials.

The gate uses the conservative maximum of three published L-H-threshold fits
and compares it only with declared external actuator power, excluding alpha
heating. It deliberately does not compare the threshold with the
IPB98-derived transport-loss power, because that would use the confinement law
to prove its own regime access. All 360 candidates have a standard IPB98
inverse aspect ratio and `q95 >= 3`; 240 lie in the main cited H-mode database
density band. Yet all 360 declare zero external actuator power, so the access-
power upper-bound gate and complete regime-access precondition both pass zero
candidates.

This is a causal model-governance result, not evidence against tokamaks. The
next tokamak bridge must introduce searchable heating/current-drive actuators,
absorbed-power partition, line-density/LCFS geometry, core radiation and
`P_sep`, dynamics/hysteresis, and ELM loads/mitigation. Candidate comparison,
common ranking, medium fidelity, C1, and promotion stay unauthorized. The
deterministic result is
`ac8d6123ab168b7a2a668d149e4379d8bea2e420cf7f2b704264475b5c6ef5e7`;
the dedicated validator and all 75 Julia test groups pass (v50: 74/74).
Details are in
`docs/tokamak_regime_access_intervention_v50.md`.

## 2026-08-15 update: stellarator candidate `f_ren` calibration queue v51

V51 audits all 288 sealed stellarator candidates instead of replacing the v48
field-quality heuristic with another unvalidated scalar. All candidates
reproduce their v46 core and current ISS04 algebra, but zero contain explicit
Fourier boundary coefficients or equilibrium profiles; candidate effective
ripple, high-order convergence, empirical `f_ren`, source-domain completeness,
confinement comparison, common ranking, medium fidelity, and promotion are all
zero. The current heuristic `f_ren` spans only `1.0532686–1.0619086`, and the
iota proxy is fixed at `0.8`, confirming that neither is a credible
topology-resolving calibration target.

The one existing DESC low-order effective-ripple fixture is retained only as a
solver-capability control. It is source-disjoint from the 288 candidates, its
maximum ripple `0.0074808` lies below the cited empirical-relation interval, and
high-order Bounce2D plus candidate transport validation are unavailable. It
cannot transfer a value or evidence credit.

V51 uses only v17 five-layer module-set distance to retain 18 distinct sample-1
assemblies, six each QA/QH/QI. The queue authorizes boundary/profile
reconstruction, finite-beta equilibrium, high-order ripple, source-disjoint
device-level calibration with leave-one-device-out baselines, and transport
validation. It does not authorize an invented `f_ren` or candidate ranking.
The deterministic result is
`84d171c00cae10d59b635865fdff7062acdbdb0f00ab0a78d9e930dcf1ff6eb8`;
the dedicated validator and all 76 Julia test groups pass (v51: 77/77);
details are in `docs/stellarator_fren_calibration_queue_v51.md`.
