# 统一多拓扑候选绑定非线性装置链 v90 验收

实现验收：`pass`<br>
可信大范围搜索声明：`fail`<br>
声明授权：`false`<br>
产物哈希：`e4a40853c2b1321a6df28317bd45808422ad8cd1dd8e3ff0d5044f879bf60f92`

## 已验证结果

- campaign：`10` 批，`100000` 条请求/结果，实际 solver input 唯一率 `1`。
- candidate-bound 多区域非线性闭合：`100000/100000`。
- 两个不同 capability cell 的硬门成活者：`2`；只对硬门调度的 survivor 进入后续高保真链。
- family/name 路由、benchmark threshold override、证据防火墙违规分别为 `0`、`0`、`0`、`0`。
- 缓存重放审计：`pass`；批次无缺口/重叠：`true`。
- 两个生成切片的 numerical VVUQ 为 PASS；ITER 与 C-2W 仅作为同链 sentinel containment，promotion credit 为 false。

## 严格封存边界

软件链通过不等于装置可行或大范围多拓扑搜索可信。当前仍缺 candidate-bound kinetic/碰撞验证、适用的自由边界或三维平衡、resistive/kinetic/nonlinear 稳定性、结构/热/材料/屏蔽/低温/维护闭合、实验 validation VVUQ，以及外部新颖性/专利/FTO。相关阶段保持 `unknown` 或 `unsupported`，不可由 Pareto、参考装置或 campaign 数量补偿。

因此 `credible_large_range_search_claim_status` 被固定封存为 `fail`，完整 engineering candidate 数为 0。完整逐请求、逐门、哈希、缓存及重放证据见 `universal_multitopology_acceptance_v90_20260827.json` 与 campaign 目录。
