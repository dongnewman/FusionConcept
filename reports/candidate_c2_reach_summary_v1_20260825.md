# Candidate C2 reach summary v1

本次先完成统一 C2 运行时与两条真实候选派生装配链，不启动新的磁镜专用物理模块。`family`、设备名和候选名均不参与编译或门控；路线名称只作为报告元数据。

## 真实候选前沿

| 候选前沿 | 当前最深位置 | 纵向输入缺口 | Stage 4 缺口 | 当前 C2 |
|---|---|---:|---:|---|
| closed candidate pool-24 | 已生成候选运行点和 32 线圈复合装配；同一残差图完成非线性状态求解、独立残差复算和 C2 汇总 | 原始前沿 55/56；新装配仍缺完整辐射闭合，故 Stage 3 conservation 保持 incomplete | error-field 与 fast-ion 完整证据仍缺 | `incomplete / fail / terminate=true`；选定 32 线圈装配的 normalized Bn RMS=0.065081，高于装配门 0.01，工程必要条件硬失败 |
| closed candidate pool-56 | 已进入统一采集 DAG 和同一 C2 状态包协议 | 55/56 | 5 个算子、11 个唯一输入 | `incomplete / unknown / terminate=false` |
| open candidate low-force | 已生成有限绕组复合装配；同一残差图完成非线性状态求解、独立残差复算和 C2 汇总 | 原始前沿 56/56；新装配仍缺完整辐射闭合，故 Stage 3 conservation 保持 incomplete | 声明的必要 minimum-B 算子已完成并失败；工程仍缺载荷路径和温度相关材料裕量 | `incomplete / fail / terminate=true`；收敛的局部场强鞍点硬失败仅终止所选双线圈 minimum-B 装配 |
| open candidate high-ratio | 已进入统一采集 DAG 和同一 C2 状态包协议 | 56/56 | 7 个算子、26 个唯一输入 | `incomplete / unknown / terminate=false` |

## 两条已执行装配链的共同结构

两条装配均经过相同门：`stage_3_residual`、`stage_4_stability`、`engineering`、`independent_evidence`，并使用相同粒子、能量、物种、执行器、功率账本和证据字段。两条链均完成独立残差门；闭合装配在 engineering 门产生终止性窄失败，开放装配在 Stage 4 必要算子产生终止性窄失败。

`completeness=incomplete` 与 `candidate_conclusion=fail` 不冲突：前者说明仍有未完成证据，后者说明已被一个候选装配级、权威且必要的条件否定。`terminate=true` 只终止该复合装配，不否定基础等离子体边界、替代线圈语法或替代稳定机制。

## 验证

- 完整 `julia --project=. test/runtests.jl`：退出码 0。
- C2 定向回归：365 项通过（154+20+26+19+25+10+10+45+30+7+19）。
- 新增垂直切片 JSON：12 个 operating/assembly/gate/state/decision 文档通过 Draft 2020-12 schema 校验。
- 双路线垂直切片 artifact：`95b90c3d17f94fe94dfb8cc6004e5173a28ab89e71882a5a6ab4082591f84406`。
- 四候选采集前沿 artifact：`039c43fd8d2e13f15bbb5bc4a2ea1d3118e201096f959a8932431547c9a43377`。

结论：pool-24 与 low-force 已从“统一协议但没有实际状态”推进到“同一 C2 汇总链上的真实装配级终止硬失败”；pool-56 与 high-ratio 仍停留在统一采集 DAG 的候选输入/Stage-4 证据获取阶段。下一步应补通用辐射闭合、候选绑定输运响应和剩余 Stage-4/工程证据，而不是新增磁镜专用模块或扩大搜索规模。
