# 统一多拓扑装置生成与筛选 v89 验收

状态：`pass`<br>
产物哈希：`0b7cc61e12cc4af73dc0dbefe1121fa83dd40ad7d44afb9697d37314d685a0f2`

## 结论

ITER 与 C-2W 都由公开 reference description 反解为同一套 family-neutral topology、realization、operator obligation 和 candidate-bound solver input。两者与无标签混合拓扑控制共用同一个执行器，没有按名称、family 或 benchmark flag 路由，也没有专用阈值或 promotion credit。

整条链路均已执行：

`抽象拓扑生成 → 抽象一致性筛选 → physical realization 生成 → 硬物理漏斗 → 成活者稀疏化与 Pareto → integrated reduced-L2 整装筛选 → 证据边界内最简可信候选`

| 输入 | 反解区域数 | 边界 | operator 路由 | 多区域 residual | 硬门成活者 | Pareto | 整装筛选 | 公开区间回归 | 工程/实验 V&V |
|---|---:|---|---|---|---:|---:|---|---|---|
| ITER | 1 | closed | pass | pass | 2 | 1 | pass | pass | unknown |
| C-2W | 2 | mixed, open | pass | pass | 2 | 1 | pass | pass | unknown |

验收汇总：known-device chain `2/2`；不同 hard-survivor capability cells `2`；无标签控制 `pass`；负控制 `pass`；family routing `0`；benchmark threshold override `0`。

## ITER 与 C-2W 的反解含义

- ITER：反解为闭合等离子体控制体、闭合边界、内部电流/外部场导体/功率执行器/材料边界/传感控制组件，以及公开 operator obligations。
- C-2W：其 declared region semantics 被拆为闭合核心和开放平行损失区，二者通过粒子与能量成对守恒接口连接；核心为 mixed boundary，损失区为 open boundary。
- 两者的 anchor observables 均未进入 topology、realization 或模型预测；只在完成 candidate-bound 计算后作区间比较。标签擦除和加入 benchmark flag 后，topology hash、isomorphism hash、realization hash、solver input hash、route hash 与硬门结论保持不变。

## 物理与证据边界

这次的硬门包括类型/几何正值、界面守恒、有限压力 beta 上界、磁通库存一致性、热库存一致性、降阶电流密度界、执行器容量、capability fail-closed 和多区域 residual 收敛。整装层为三分辨率的 integrated reduced control-volume L2 数值筛选；ITER 的 D-T 功率来自 candidate state 与 Bosch-Hale 反应率，C-2W 温度来自 candidate state，公开区间仅用于事后回归。

因此本次可以声明统一软件链、反解 containment、降阶硬物理筛选和 numerical VVUQ 范围内通过；不能声明自由边界 MHD、完整 kinetic/transport、材料/结构/维护工程、实验 validation VVUQ、可部署装置、外部新颖性、专利性或 FTO。完整 engineering/V&V candidate 数仍为 `0`。

## 负控制

- 缺 operator manifest → `unsupported/missing_operator_capability`；
- 破坏内部界面成对守恒 → 静态编译拒绝；
- 执行器容量不足 → 硬门 `fail`；
- Pareto 输入含硬门失败候选 → 拒绝执行 Pareto。

完整逐候选、逐层、逐门和哈希证据见 `universal_multitopology_acceptance_v89_20260827.json`。
