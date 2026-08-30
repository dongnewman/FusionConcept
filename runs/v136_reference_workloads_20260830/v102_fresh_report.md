# v102 ITER/C-2W 反解结果普通候选全流程实验

## 结果

| 输入 | 反解区域 | v89 | v96 numerical VVUQ | 普通候选 v98 | 失败门 | 旧 reference 状态 | 适用性审计 |
|---|---:|---|---|---|---|---|---|
| ITER | 1 | pass | pass | fail | fusion_gain, net_electric_power, exhaust_heat_flux | pass | selector_applicability_mismatch |
| C-2W | 2 | pass | pass | fail | temperature_fit_domain, fusion_gain, net_electric_power, neutron_wall_load | pass | selector_applicability_mismatch |

ITER 与 C-2W 的 v89 反解均可表示、可闭合，并以完整反解多区域图通过 v96 whole-graph
solve 和 numerical VVUQ；但把同一反解状态按普通候选送入当前 v98 后，两者都在 reduced
reactor physics screen 被拒绝，后续高保真和 validation 按严格顺序不执行。因此当前普通候选
全流程通过数是 **0/2**。

## 筛选器诊断

现有 reference-control 汇总仍报告 2/2 pass，但两行内部的 `physics_screen_status` 都是 fail。
reference pass 只要求 numerical replay 和公开区间回归，没有要求普通候选物理门通过；本实验
因此检出 **2** 个 reference-control bypass。ITER 还被施加未由其参考任务声明的净电
功率和反应堆排热门；C-2W 是非 D-T、反转场开放损失区实验，却被施加 D-T 增益、净电功率、
中子壁负荷等门，且其温度超出当前 reduced reactor model 的适用域。两者当前 rejection 均不能
提升为装置物理失败。

## 证据边界

本实验没有按名称路由，没有给参考装置候选或 validation credit，也没有绕过失败继续提升。
ITER 的公开值是设计目标而非 D-T 实验验证；C-2W 的公开区间未形成与本求解输入独立、含测量
不确定度和适用域签署的 validation contract。可信整机和 validation pass 均为 0。

Acceptance hash: `6b9d652f7d7cc8ef070944cdead2e6c121a3103ed0a31e27147d839146445928`

This experiment tests whether family-neutral inverse representations of published ITER and C-2W descriptions survive the current ordinary-candidate chain. A reduced screen rejection with an applicability mismatch is a selector diagnosis, not a physical falsification of either device. Reference data, design targets, and input-derived observables provide no new-candidate or independent-validation credit.
