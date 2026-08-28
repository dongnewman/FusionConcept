# v86 多拓扑大范围搜索就绪性审计（2026-08-26）

> 后续状态：两级能力预算、逐层 stage frontier 和 500–1000 unique-input
> 中型试验已完成。668 个适用 field-pass 唯一输入仍为 0 个正式 Poincare
> 成活，停止规则已触发；随后 focused grammar transition 的最新 P32 仍为
> 0/7。当前权威进展见
> `reports/v86_medium_campaign_and_grammar_falsification_20260826.md`。

## 结论

受控的中等规模覆盖试验已经完成，当前仍不适合直接启动“最大范围全量搜索”。主要瓶颈已经从 campaign runtime 转为线圈/电流势 grammar 的 Poincare 成活率；开放场有限压执行链仍缺失并保持显式排除。

这不是物理候选失败结论，也不是装置族优劣结论。v86 只建立了候选绑定的有限导体场、渐进 Poincare、环形有限压/DESC、开放场双向端损失、内容寻址缓存、分片恢复和证据防火墙。

## 50-topology 编译覆盖试验

- 输入：structure seed 1–50；每个结构 1 个 physical、operating、control variant；两个声明 route；基阶 0。
- 原始拓扑：50。
- 图同构去重后的结构：50。
- 编译通过：47；失败/不支持：3。
- 不可变求解请求：94。
- capability cell：46。
- budget stratum：2（闭合场完整声明链、开放场不完整声明链）。
- comparison scope：2；不同 scope 之间仍禁止 Pareto 支配。
- 单结构 cell：45；单个 cell 最多仅 2 个结构。
- 可进入当前声明最简性链的请求：28（14 个 toroidal cell）。
- 明确排除的请求：66（32 个 linear/open cell），原因均为缺少候选绑定的开放场有限压能力。
- 装置族标签未用于路由；不同 capability cell 之间禁止 Pareto 支配声明。

编译未通过的 seed：

- seed 29：`unsupported_graph_capability_v69`
- seed 31：`undeclared_immediate_causal_loop`
- seed 37：`exclusive_output_conflict:r1:field_source:field_state`

## 当前最应完善的部分

### P0. 将能力描述拆成三个层级（已完成基础实现）

保留当前严格的 execution signature，继续由维数、时间语义、边界、state slot、port、operator、validity domain 和证据义务决定执行器；另增：

1. budget stratum：只用于分配探索、Poincare、DESC、例外和基阶升级预算；
2. comparison scope：只在硬门链、证据深度和 grammar 可比时允许跨拓扑 Pareto。

不能为了合并 cell 而放松执行路由。当前 47 个通过结构形成 46 个 cell，说明直接按精确 signature 做预算和跨拓扑统计几乎退化为“每个结构单独搜索”。

严格 execution cell、budget stratum 和 comparison scope 已分别落盘；campaign 采用 budget stratum -> exact capability cell 的两级轮转。后续仍需把固定预算写入 stage frontier。

### P0. 将一次性流水线改为合并后晋升的 stage frontier

每一层只消费本层输入并产出不可变 frontier：

`field -> P32 -> P64 -> P128 -> finite pressure -> stability -> engineering`

每个 budget stratum 固定记录：

- 初始探索额度；
- 各 Poincare 层晋升额度；
- DESC/工程额度；
- 异常/重试额度；
- 基阶升级额度。

只有前一层合并完成后，才按候选绑定证据选择下一层请求。不能在并行 shard 中按“先完成者先抢 token”，否则结果依赖运行时顺序；也不能让高保真结果反向给低保真候选补信用。

### P0. 补开放场候选绑定的有限压执行器，或保持排除

当前开放场已有真实有限导体积分、双向场线追踪、镜比/损失锥、端粒子流和端功率容量门，但没有 ambipolar/有限压平衡能力。因此 66/94 请求只能得到端损失证据，不能进入与闭合场相同意义的最简性 Pareto。

在该执行器完成前，可以搜索开放场并记录 fail/unknown，但必须保持 `minimality_eligible=false`，不得用代理端损失分数替代有限压可行性。

### P1. 让基阶升级由失败机理驱动

当前 2->3->4 阶基能保持低阶系数并追加高阶自由度，但“任何首个 non-pass 都升级”仍过宽。应区分：

- 场形/嵌套面不足：允许提高线圈/电流势/边界基；
- 电源、热排、支撑或端损失容量不足：优先换 operating/control/actuator variant，不自动提高线圈基；
- 执行器不支持或证据缺失：保持 unknown/unsupported，不生成物理升阶信用。

### P1. 升级优化器，但不要先追求单点 99%

当前为低差异初始化、确定性坐标搜索和短场线 acquisition。下一步应增加带硬约束的 trust-region/CMA-ES 或批量 surrogate/QD；目标是扩大不同 basin 和拓扑覆盖，不是把一个候选从 95% 反复磨到 99%。优化器输出仍须由独立硬门重算。

### P1. 先做 50–100 topology、500–1000 unique field-input 的中等试验

启动条件：

- 三层 capability 分工已落地；
- stage frontier 与每层预算可恢复、可严格合并；
- exact solver-input cache 保证每个输入最多真实执行一次；
- 开放场有限压能力已补齐，或在 campaign manifest 中明确排除；
- promotion 是失败机理驱动且没有 retroactive credit。

停止规则：若新增 unique topology 或 unique field input 连续两个批次不再增加通过场门/P32 的能力单元覆盖，或新增结果主要是重复 cache 命中，则停止扩规模，先修执行链或 grammar。

## 已验证基础

- v86 单元测试：62/62 通过。
- v84–v86 聚焦回归：180/180 通过。
- CLI：compile -> shard -> merge -> promote 全链通过。
- 中断、损坏 partial 尾部修复和恢复后的 stream/hash 与无中断运行一致。
- 两个 route 的相同物理输入只执行一次；相同物理设计只生成一次基阶升阶请求。
- schema 离线校验通过。

## 产物

- `reports/v86_multitopology_coverage_50_campaign.json`
- `reports/v86_capability_coverage_50topology.json`
