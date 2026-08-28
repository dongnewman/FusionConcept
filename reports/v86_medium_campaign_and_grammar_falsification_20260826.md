# v86 中型 campaign 与线圈 grammar 证伪（2026-08-26）

## 当前结论

v86 的多拓扑运行时、全局真实输入缓存、分片恢复、严格合并、能力预算和逐层 stage frontier 已达到中型覆盖试验要求；当前仍不应启动最大范围或万级拓扑搜索。

物理停止条件已经触发：闭合 Poincare 能力链累计 668 个通过 finite-filament Biot-Savart 的唯一输入，覆盖旧 grammar 的 basis 0、1、2，但正式 P32/P64/P128 成活数均为 0。随后只对 7 个旧 grammar 中不逃逸但旋转变换不足的前沿做 grammar transition，没有增加 topology seed。二维绕组面电流势 v7 已把 field 提升到 7/7 pass，并首次得到 1 个完整跑完 32 圈但旋转变换不足的真实候选；正式 P32 pass 仍为 0。

因此当前状态是“运行时可放量、物理 grammar 尚不可放量”，不是候选可行性或装置可建造性的证明。

## 中型覆盖证据

### 75 topology x 8 variant 混合能力试验

- 75 个原始 topology seed，69 个编译通过的唯一结构。
- 1104 个不可变请求；field 预算实际调度 1056 个请求。
- 542 个唯一 field solver input，542 次真实执行、514 次缓存命中。
- 重复真实执行 key 为 0，证据防火墙通过，异常为 0。
- P32：208 个唯一输入，0 pass、208 fail。
- open-field end loss：256 个唯一输入，204 fail、52 unknown；没有开放场有限压能力，因此全部保持 `minimality_eligible=false`。

### 100 topology x 16 variant 闭合能力试验

- 100 个原始 seed，92 个编译通过结构。
- 2944 个总请求；按 P128 能力和 minimality eligibility 过滤后为 1088 个请求、33 个 exact capability cell。
- field：1056 个请求，536 个唯一输入、536 次真实执行、520 次缓存命中、0 异常、0 重复执行。
- P32：256 个唯一输入，0 pass、256 fail；249 个场线逃逸，7 个长期有界但旋转变换不足。
- basis1：66 个 field pass，P32 为 0/66。
- basis2：66 个 field pass，P32 为 0/66。
- basis0/1/2 的正式 P128 成活数均为 0；搜索停止 manifest 要求停止扩 seed 并修改线圈/电流势 grammar。

停止证据位于：

- `runs/v86_closed_100x16_20260826/search_stop_manifest_final.json`

## 数值链正例控制

为区分“grammar 没有表达能力”和“Poincare 求解链永远不会通过”，增加了 benchmark-only 的 TF 线圈加内部轴向环电流正例。该内部电流位于候选等离子体区，不属于允许候选部件，不进入复杂度 Pareto，也不给任何可行性或最简性信用。

- 扫描 20 个环电流比例。
- 20/20 通过 benchmark 的 field 门。
- 9/20 通过 P32。
- 这证明当前 finite-filament -> Poincare 数值链能够识别嵌套磁面；候选全灭主要指向候选 grammar，而不是永远 fail 的门。

正例记录：`reports/v86_poincare_positive_control_20260826.json`。

## 找到并修复的优化/语义问题

1. 升阶 override 遮蔽低阶优化：basis1/2 序列化完整低阶数组，编译时会覆盖优化器刚修改的低阶设计。现在 override 只贡献追加尾部，低阶坐标仍由当前优化点拥有。
2. 高阶尾部未优化：Fourier、B-spline 和电流势追加系数已纳入统一的可行性优先状态向量；阶段晋升保留优化后的 override。
3. 小预算坐标偏置：旧坐标循环在 15 次评估时只触及向量前部。现在使用确定性跨块坐标顺序与全向量低差异采样，小预算也会覆盖线圈、电流势、边界和高阶尾部。
4. 并发缓存生产竞争：producer 已移入跨进程执行锁，相同 solver input 在并行 shard 中最多真实执行一次。
5. Poincare 边界错配：起点、极角、归一化半径和逃逸判据已改为候选绑定的周期椭圆边界；无 v85 边界声明的旧调用保持圆边界语义。新边界语义进入 solver-input hash，禁止复用旧缓存。
6. acquisition horizon：field stage 使用 2 圈；P32/P64/P128 优化分别使用 8/16/32 圈 acquisition。acquisition 只指导下一次采样，正式信用仍仅来自独立 32/64/128 圈硬门。

## focused grammar transition 结果

所有轮次均只消费旧 basis2 的 7 个“不逃逸但变换不足”前沿，没有生成新 topology。

### winding-surface modular v3

- field：4/7 pass；其余只因 `Bn/B > 0.18` 被拒绝。
- P32：4/4 场门复算通过，但全部约在 1% 轨迹长度内逃逸。
- 结论：局部变换较强，但模块场形没有形成全局磁面；不继续放大。

### coherent helical v4

- 28 个 TF 基环加 12 条相位均匀的连续螺旋绕组。
- field：7/7 pass，`Bn/B` 约 0.02–0.05。
- P32：7/7 逃逸，最短完成度约 3%–6%，实际最小旋转变换约 0.10–0.20。
- 结论：变换足够但螺旋场过强，磁面快速破坏。

### current-scale optimized coherent helical v5

- 新增可优化的总螺旋电流尺度，范围 0.15–1.25，初值 0.35。
- field：7/7 pass；优化尺度落在 0.15–0.35，`Bn/B` 约 0.01。
- 2 圈 acquisition 后的 P32：7/7 逃逸，最短完成度约 8%–15%，实际最小变换约 0.04–0.07。
- 8 圈 acquisition 后的 P32：7/7 逃逸，最短完成度约 14%–26%，实际最小变换约 0.02–0.04。
- 候选绑定周期边界重算没有改变上述结论。

这说明螺旋电流尺度和长 horizon acquisition 确实改善了 pre-P32 生存，但尚未产生可晋级候选，不能获得任何 P64/P128 或下游物理信用。

### 2D winding-surface current-potential level sets v6

- 在周期二维 `(theta, phi)` 绕组面上声明电流势，并用隐式 Newton continuation 从等值线生成 28 条闭合有限导体。
- contour 数、NFP、主导 `(m,n)`、绕组面间隙和 2 个电源分组均进入候选绑定 realization。
- 初版采用强螺旋 secular branch；7/7 均因 `rms(Bn/B)=0.4034–0.4106 > 0.18` 在 field 门失败，最低场和 ripple 均不是阻塞。
- v6 语义保留为可重放的旧模型，未用同一 model id 静默替换几何；历史首个优化结果重编译得到的 field solver-input hash 与记录中的 `8bb0f933...b7ebbc` 完全一致。

### poloidal-modular 2D current-potential level sets v7

- 改为以 `phi` secular 项生成闭合极向 modular contour，二维 `(m,n)` 项只做非平面形变；所有导体仍来自电流势等值线。
- field：7/7 pass，7 个唯一 solver input，`rms(Bn/B)=0.0569–0.0826`，0 异常、0 重复执行。
- 正式 P32：0/7 pass；5 个场线逃逸、1 个周期磁轴未定位、1 个完整 32 圈但 `|iota|=0.006055 < 0.02`。
- 唯一有界前沿的最短正式轨迹完成度为 100%；其余可定位磁轴候选的完成度约 7.6%–49.9%。这比 v5 的 14%–26% acquisition 生存显著前移，但仍不构成硬门成活。

### v7 有界盆地停止审计

- 电流势幅值 `0.75, 1.0, 1.35, 1.70, 2.10` 倍扫描没有 P32 pass。0.75–1.0 倍保持完整 32 圈但 iota 仅 0.004307–0.006055；1.35–1.70 倍在 iota 提高到 0.008947–0.014124 时开始逃逸；2.10 倍无法定位周期磁轴。
- 离散主导模态 `(2,1), (3,1), (1,2), (2,2)` 扫描没有 P32 pass；后三者完整 32 圈但 iota 仅 0.000648–0.002497，`(2,1)` 在约 88.6% 处逃逸。
- 两个审计均明确为 next-request sampling feedback，`candidate_feasibility_credit=false`、`campaign_promotion_credit=false`。结果位于 `reports/v86_v7_shape_scale_frontier_20260826.json` 和 `reports/v86_v7_mode_frontier_20260826.json`。
- 按停止原则，不再围绕该单点细调，也不增加 topology seed。

### 多结构受约束电流势逆问题 v8

- 从 v7 正式 P32 前沿中按完成度选取 3 个不同闭合结构（seed 52、73、54），没有增加 topology seed。
- 每个结构只做 1 次正则化 Gauss–Newton；11 个已声明电流势系数进入有限差分，边界 `Bn/B`、短程逃逸、完成度、目标 `|iota|>=0.02`、磁面排序和 contour 间距共同进入可行性优先 rank。
- 逆求解只生成下一批不可变请求，所有结果均保持 `candidate_feasibility_credit=false`、`campaign_promotion_credit=false` 和 `retroactive_feasibility_credit=false`。
- 短程指标有局部改善：seed 52 的 4-turn `|iota|` 从约 0.0170 提升到 0.0190；seed 73 的最短完成度从约 0.671 提升到 0.675；seed 54 的 4-turn 轨迹完整且 `|iota|=0.02277`。
- 新请求正式 field 为 3/3 pass；正式 P32 为 0/3 pass，全部归类为 `poincare_field_line_escape`。最短 32-turn 完成度分别约为 seed 73 的 20.0%、seed 52 的 42.7%、seed 54 的 0.78%；没有候选获准进入 P64。
- 最终稳定证据链使用 JSON 往返规范哈希和按 `source_request_hash` 的稳定排序；field 与 P32 各 3 个 solver input 均由内容缓存重放，实际执行计数为 0，证据防火墙通过、重复执行 key 为 0。最终 P32 merge result hash 为 `0450a0f4...c46dae`。
- 批量逆问题现在按结构写原子检查点并支持恢复；既有 3 个结果的验证重放为 `recovered=3, fresh=0`。结果位于 `reports/v86_current_potential_inverse_frontier_20260826.json`。

这一轮还暴露出 surrogate/硬门不一致：逆问题复用了从候选边界中心发射的 4-turn acquisition，而正式 P32 先定位候选绑定周期磁轴、再从磁轴相对半径发射。短程 rank 的改善不能可靠预测正式 P32，因此在统一两者的磁轴、起点和逃逸语义前，不应继续扩大逆问题样本或 topology seed。

### 周期磁轴对齐 acquisition 与受限 v9 复验

- 新增版本化的 `candidate_biot_savart_periodic_axis_fieldline_acquisition_v2`，旧 acquisition v1 保持不变以供历史重放。
- v2 与正式 P32 复用同一个候选有限丝场、候选边界、周期磁轴定位器、轴相对 `0.15/0.35/0.55` 起点和逃逸判据；磁轴未定位直接进入首级约束违反，不能伪装成零逃逸。
- acquisition 完成度改为实际 toroidal-turn fraction，不再用积分步数近似。4-turn 诊断能捕获 seed 54 的早期逃逸，但漏掉 seed 73 在约 6.4 turns 和 seed 52 在约 13.6 turns 后的逃逸；16-turn 诊断则对 3 个冻结候选全部复现正式 `poincare_field_line_escape`。
- 只沿上一轮变化最大的电流势系数 6、7、8 做 1 次 16-turn、周期磁轴对齐的受限逆优化；没有增加 seed 或迭代。seed 52 的 acquisition 逃逸由 1/3 降为 0，seed 73 无改善，seed 54 仍逃逸。
- 新请求正式 field 为 3/3 pass；正式 P32 仍为 0/3 pass。seed 52 的最短正式轨迹由约 13.65 turns 提高到 14.65 turns 后仍逃逸；seed 73 约 6.40 turns、seed 54 约 0.26 turns。P64 继续未调度，promotion 为 0。
- 最终 merge 的 3 个 field input 中 2 个真实执行、1 个缓存命中；3 个 P32 input 中 2 个真实执行、1 个缓存命中；异常和重复执行均为 0，证据防火墙通过。P32 merge result hash 为 `ddc35532...107c27d`。
- 逆问题证据位于 `reports/v86_axis_aligned_current_potential_inverse_frontier_20260826.json`；所有 acquisition 和 inverse 结果继续保持零可行性、零 promotion 和零逆向信用。

因此周期磁轴/起点语义缺口已经修复并经正式链复验，但当前闭合场 v7/v9 grammar 盆地仍无 P32 成活。本轮停止该盆地，不继续增加活动系数、信赖域迭代或 topology seed。

## 下一物理动作

不继续扩大 topology 或 seed。下一轮应改变表达能力，而不是继续微调 v5：

1. 二维绕组面等值线、受约束电流势逆问题、候选绑定周期磁轴和轴对齐 acquisition 已经落地；v7/v9 受限 falsification 仍为 P32 0/3，因此停止当前闭合场盆地，不再做幅值、模式或系数细调。
2. 下一闭合场动作必须是结构性改变 winding-surface/coil grammar，而不是扩大 seed；新 grammar 仍须先在现有旧前沿做受限 P32 falsification。
3. 当前更直接的跨拓扑 P0 是开放场候选绑定有限压执行器。补齐前继续明确排除开放候选的最简性比较，不能与闭合候选混做全局 Pareto。
4. 只有真实 P32 pass 或开放场等价硬门完整通过者，才允许进入下一层有限压力/稳定性队列；否则不启动最大范围搜索。

暂不投入 DESC 扩容、稳定性高分辨率、kinetic transport、完整工程或 VVUQ 队列。

## 声明边界

本报告只证明 v86 运行时和候选绑定低阶物理执行的工程行为，以及上述 grammar 在声明预算内的证伪结果。它不证明有限压力平衡、稳定性、输运、净功率、完整工程、原创性、可制造性或可部署性；当前没有“最简物理可行候选”。

## 最终验证

- v81–v86 聚焦回归：298/298 通过；新增检查覆盖逆问题无信用边界、JSON 往返哈希、稳定 followup、停止拓扑扩张后的自适应请求，以及周期磁轴对齐 acquisition 的请求/结果语义。
- benchmark-only Poincare 正例：既有 20 点扫描为 9/20 P32 pass；加入周期磁轴定位后，`0.04` 环电流比例单点仍通过 P32，证明新磁轴门不是必失败门。
- 离线 JSON Schema：3 个 inverse request、3 个 inverse result、9 个最终目录/stage `CandidateSolveRequestV86` 全部通过；field/P32 JSONL 均可完整解析，最终 merge 的缓存、防火墙和 promotion 断言通过；166 个本地 schema 全部通过 Draft 2020-12 schema 自检。
- `git diff --check`：通过，仅有 Windows CRLF 提示。
