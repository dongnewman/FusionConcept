# Stage 3 v70：100,000 结构搜索与 QRF-Assembly 解析

## 结论

本轮 100,000 个结构 seed 已按 `10 × 10,000` 分片、最多 4 个 worker 并行完成，并按结构同构哈希和 evidence hash 合并。合并验收状态为 `accepted`，8 项退出门全部通过。

演示候选是 seed `73792`。它与 seed `99780` 在已执行证据层级、守恒残差和结构丰富度上并列；系统没有伪造一个连续代理分数来打破并列，而是按预先声明的确定性结构哈希顺序选出 seed `73792` 作为唯一演示代表。因此“唯一”是可复现的展示选择，不表示它已被证明在物理上优于并列候选。

展示名为“四域镜像通量耦合装置（QRF-Assembly）”：`Q` 表示 four-region，`R` 表示候选声明的 reflection symmetry，`F` 表示显式 flux/account interfaces。这个名字和装置几何是在搜索完成后添加的解释层；搜索、路由、排序和验收均未使用装置家族标签。

## 搜索验收

| 项目 | 结果 |
|---|---:|
| 分片 / worker 上限 | 10 / 4 |
| 每片 seed 数 | 10,000 |
| 原始 seed | 100,000 |
| 唯一结构同构哈希 | 99,873 |
| 重复结构 | 127 |
| 唯一 evidence hash | 1,000 |
| Stage 3 complete/pass evidence | 1,000 |
| 合并后 QD 单元 | 768 |
| 未捕获异常 | 0 |
| 端到端墙钟 | 973.138 s（16 min 13.138 s） |
| 端到端平均吞吐 | 约 102.76 raw structures/s |

退出门：10 个分片完成、10×10,000 范围连续、原始计数精确、所有分片零未捕获异常、结构哈希合并完整、evidence hash 合并完整、winner 为 complete/pass、winner 独立审计通过，全部为 `true`。

密封标识：

- 合并结果哈希：`05fb4186b2455d149b2467672380fecc87983aea5cbf7a830bbce5007198c9d5`
- 合并结构流 SHA-256：`12012e84bcc7f4475eac392295eb5c30084f56b2cb62917663b67248129c30d4`
- 合并证据流 SHA-256：`1ea47d9a0dfc0aaefc2be0293230484946df31f1aa32c3ee3dfee0e92ad950a9`
- 结构流：`runs/stage3_v70_100000_20260825/stage3_v70_100000_structures_merged.jsonl`
- 证据流：`runs/stage3_v70_100000_20260825/stage3_v70_100000_evidence_merged.jsonl`
- 验收件：`runs/stage3_v70_100000_20260825/stage3_v70_100000_merged_acceptance.json`

## 为什么选择 seed 73792

选择使用词典序门链，而不是把不同含义压成一个“优秀度分数”：

1. Stage 3 plan/evidence 完整；
2. 结论为 pass；
3. 独立重算审计为 pass；
4. 分辨率证据完整；
5. 完成样本数 / 要求样本数最大；
6. 最大守恒残差最小；
7. 结构丰富度最大；
8. 若仍并列，以结构哈希、evidence hash 作确定性排序。

前两名均满足前六项、结构丰富度均为 221。seed `73792` 的结构哈希以 `073c…` 开头，seed `99780` 以 `1496…` 开头，所以 seed `73792` 成为演示代表。这个 tie-break 只保证复现，不增加物理证据。

winner 哈希链：

- seed：`73792`
- 结构同构哈希：`073c06b224bc1ed3a6b3035f49fb7103f709959a4d839f18e243c6162d16fa98`
- 具体拓扑哈希：`32af5f1a124284f3d18389df3d48469485aaa1a4fc3ef9514c1ad39ec7a0850c`
- solve plan hash：`0d59d73108d2b2a75e9b35770c418d4a72dd51801e476bbb805cc26a32d12359`
- evidence hash：`2eea7927ad28e31a6872bb04aa073e5e23d5165efafaa1127ea644d9a3a592f3`

## 候选原理：先是计算拓扑，后是装置解释

候选原始对象不是现成的 tokamak、stellarator、mirror 或其他装置家族，而是一个声明 `reflection` 对称性的四区域账户图。它包含 4 个区域、5 条边界/域间接口、37 个端口、21 条依赖、57 个状态和 83 个算子。

### R1：闭合瞬态库存域

- 数值语义：`0d / transient / closed`
- 9 个状态、4 个代数约束
- 向 R2 发送 `electron_energy`
- 具有外部 `ion_energy` 边界

解释上可把它看作短时间尺度的库存与热惯性缓冲区。这里的“闭合”只是边界类声明，不等于磁面已经闭合，也不等于粒子被物理约束。

### R2：闭合稳态账本域

- 数值语义：`0d / steady / closed`
- 12 个状态、4 个代数约束
- 接收 R1 的电子能量账户，向 R3 发送 `charge`
- 具有候选中最宽的外部接口：`electron_energy`、`ion_energy`、`particle`、`species`

解释上它承担稳态库存、杂质/中性粒子、壁温和冷却焓之间的账本联络。当前证据没有求出这些量的真实工程运行点。

### R3：混合边界 DAE 耦合域

- 数值语义：`0d / index-1 DAE / mixed`
- 10 个状态、4 个代数约束
- 接收 R2 的 `charge`
- 向 R4 发送 `electron_energy`、`particle`、`species`

这是拓扑中的多账户耦合关口。演示中的脉冲与交接动画只表达因果顺序；winner 的实际通用 probe 没有执行候选专属时变 DAE 闭合，证据记录中 DAE 一致初始化和时间步收敛均为 `not_applicable`。

### R4：三维稳态场响应域

- 数值语义：`3d / steady / mixed`
- 10 个状态、4 个代数约束
- 接收来自 R3 的电子能量、粒子和组分账户
- 是候选唯一的 3D 区域

解释上它是最适合承载场/空间分布求解的区域；当前运行只使用 manufactured generic balance，并没有求 Maxwell、Grad–Shafranov、MHD、Fokker–Planck 或输运方程。

### 分区闭环控制

四个区域均具有 sensor、control、actuator 和 heat-rejection 端口。R1/R2/R3/R4 分别声明 1/2/3/3 个 control 端口。Stage 3 能证明的是端口、依赖和执行义务能被编译并在通用平衡证据中履约；它不能证明真实传感器带宽、执行器饱和、延迟稳定性、故障安全或热排出能力。

## 当前真正具备的能力

| 能力声明 | 当前状态 | 证据 |
|---|---|---|
| 扩展到 100,000 个结构 seed | 已实跑并验收 | 10 个连续分片、4 worker、100,000/100,000 |
| 流式、低驻留结构执行 | 已实现 | 每条结构即时写 JSONL；内存仅保留 QD 代表，不保留全部 plan |
| 中断后续跑 | 已测试 | 小规模 partial stream 修复与连续 seed 恢复通过 |
| 结构哈希去重 | 已验收 | 100,000 → 99,873；127 个重复结构 |
| evidence hash 合并 | 已验收 | 1,000 个唯一证据对象，内容寻址落盘 |
| winner 通用守恒 probe | complete/pass | 1/1 Halton 样本；8/16/32 分辨率；最大 57 DOF |
| 域间接口审计 | pass | 3 条内部接口配对；最大守恒残差 0 |
| 独立重算 | pass | independent integral reconstruction |

“最大守恒残差 0”来自制造的通用平衡问题，不能外推成真实装置严格守恒，更不能外推成约束、点火、净功率或工程闭合。

## 当前不具备的能力

- 没有候选专属几何、线圈、材料、尺寸、场强、密度、温度或反应率运行点。
- 没有 Maxwell/平衡、MHD/动理学稳定性、输运、辐射、燃烧、杂质、中子学或热工水力闭合。
- 没有真实 DAE 瞬态、控制器时延/饱和、故障状态和安全系统证据。
- 没有工程应力、热负荷、冷却、维护、氚、自持或成本证据。
- 没有聚变增益、净电功率、可制造性、可部署性或物理可行性授权。
- QRF-Assembly 的同心层视觉比候选声明具有更多几何对称性；候选只声明 `reflection`。图片和 3D 场景是包装隐喻，不是拓扑证据。

## 演示系统

演示与此前 PLRMR 系统一样由 Julia 本地服务器提供密封 artifact 状态、Three.js 三维视图、教学/证据锁定模式、时间轴、图层开关、候选指标、区域卡片、账户链图和概念图画廊。

启动：

```powershell
& .\scripts\start_stage3_frontier_demo_v1.ps1 -Port 8196
```

打开 `http://127.0.0.1:8196/`，API 为 `http://127.0.0.1:8196/api/state`。

演示的通量粒子、发光、脉冲和同心层只用于解释四区域关系。证据锁定模式会锁住解释滑块，但不会把动画变成数值物理求解。

## 辅助图片

- `output/stage3_frontier_demo/assets/qrf_assembly_concept_render_v1.png`
  - SHA-256：`c454bcc9fda64876fecc908eafbabae3b8d148eda88fdd8ea7f6b0ee12983986`
  - 模式：新图生成
  - 提示要点：四个可区分的同心功能层、传感/执行模块、径向热排出、工业科学可视化、无文字/水印；明确是概念解释而非蓝图。
- `output/stage3_frontier_demo/assets/qrf_assembly_cutaway_v1.png`
  - SHA-256：`add7b529c05b08a7e5e0a76dade5fe0c6c22b0a01a15c1da0345287cc5727c1`
  - 模式：新图生成
  - 提示要点：移除一象限的四层剖面、三条内部接口、外部排出和分布式控制模块、无文字/箭头/水印；明确不是工程图。

图片在搜索完成后生成，未参与候选生成、路由、排序、证据计算或验收。

## 关键实现文件

- `src/stage3_sharded_streaming_v70.jl`
- `scripts/run_stage3_streaming_v70_shard.jl`
- `scripts/run_stage3_streaming_v70_100000.ps1`
- `scripts/merge_stage3_streaming_v70.jl`
- `test/stage3_sharded_streaming_v70.jl`
- `stage3_frontier_demo_server_v1.jl`
- `interactive_stage3_frontier_app/index.html`
- `interactive_stage3_frontier_app/app.js`
- `interactive_stage3_frontier_app/styles.css`

## 最终验收记录

- `Pkg.test()`：退出码 0；全部测试组通过，其中新增流式分片/恢复/合并测试 19/19。
- 10 个分片结构流：逐片均为 10,000 行。
- 合并结构流：99,873 行，SHA-256 与验收件一致。
- 合并证据流：1,000 行，证据对象目录也恰好为 1,000 个 JSON，SHA-256 与验收件一致。
- Julia 演示服务器：`/` 与 `/api/state` 均返回 HTTP 200；最终交付时进程 PID 为 `57028`。
- 浏览器：桌面和 390 px 移动布局均实测；证据锁定、剖面视图、图层开关均工作；控制台 0 error / 0 warning。
- 桌面截图：`output/playwright/qrf_assembly_desktop_final_1440.png`，SHA-256 `bb0faef416aac83076b0ec47e8b890f7e251cc6201ac97090d832b4ba1971f07`。
- 移动截图：`output/playwright/qrf_assembly_mobile_390.png`，SHA-256 `3c1490cbfb00244d292c35447a0d3c4a194354acca701d48b8c9b83896508438`。

## 最终边界

本轮结果证明的是：v70 已有可恢复、可分片、流式、4-worker 的十万结构搜索入口，并能把结构哈希、计划哈希和 evidence hash 连成可复核的计算证据链。它没有把图结构筛选结果升级成物理装置验证。QRF-Assembly 是对 winner 计算职责的可视化解释，也是下一轮候选专属方程、几何和实验/外部证据工作的起点。
