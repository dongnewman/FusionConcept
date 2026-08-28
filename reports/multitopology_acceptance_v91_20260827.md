# v91 真实多拓扑百万级搜索与候选审计验收

搜索能力状态：`complete`<br>
验收产物哈希：`8fa5921ce89fdd1d3f3abc11fe2a1853a066925aafc5dd07b1c8c67d5934c016`

## 实际执行规模

| campaign | 请求/结果 | unique non-isomorphic topology | unique solver input | capability cells | reduced hard-gate survivors | 状态 |
|---|---:|---:|---:|---:|---:|---|
| pilot | 10000 | 10000 | 10000 | 1152 | 1 | pass |
| qualification | 100000 | 100000 | 100000 | 3118 | 46 | pass |
| formal | 1000000 | 1000000 | 1000000 | 5464 | 417 | pass |

formal campaign 是实际执行的 1,000,000 条请求，不是外推。全部拓扑位于预注册的 20-bit injective typed-rooted-tree grammar 内；canonicalization、重命名不变性、重复控制、断点恢复、无缺口分片、完整记录哈希和确定性重放均通过。family/name/parent 路由与证据防火墙违规均为 0。

## 分层结论

- `novel_topology_candidate = 417`：只表示仓库历史语法及声明外部目录的 region abstraction 内非同构。
- `credible_new_device_count = 0`
- `computationally_credible_new_device_count = 0`
- `engineering_qualified_new_device_count = 0`
- `experimentally_validated_new_fusion_device_count = 0`

没有把 reduced balance、三分辨率数值收敛、同模型数值复制、sentinel、manufactured control 或公开区间回归升级为 validation VVUQ。最主要阻塞项为：candidate-bound free-boundary/3D equilibrium、field-line/orbit、resistive/kinetic/nonlinear stability、独立物理求解器比较、结构/热/材料/屏蔽/低温/维护闭合，以及候选绑定真实实验验证。

由于 `computationally_credible_new_device_count = 0`，不存在“最简可信候选”。验收 JSON 中封存的是同复杂度下 request index 最小的 `novel_topology_candidate`（v91-candidate-3052）的完整 Genome、basis、topology、solver input、残差、reduced VVUQ 与缺失工程义务，且没有将它升格。

## 新颖性边界

外部目录覆盖 ITER、C-2W、W7-X、NIF、Sandia Z、NSTX-U、IAEA mirror survey 和代表性 FRC/stellarator patents，并保存查询、来源、范围、日期与 URL 列表哈希。它不是穷尽性 prior-art 检索，不授予专利性或 FTO；两者均明确为 false。

## 产物

逐请求记录、shard SHA-256、merge、recovery drill、完整 hash replay、全部 survivor dossiers、最简已审计候选的 Genome/basis/topology/solver input/residual/VVUQ/工程清单，以及 source/schema/test 哈希均由 JSON 验收封存。

全量 schema 校验覆盖 3 份 campaign manifests、1110000 条结果记录与 417 份 dossiers，状态 `pass`。全仓 `julia --project=. test/runtests.jl` 退出码为 0，状态 `pass`。
