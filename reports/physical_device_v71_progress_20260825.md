# v71 实体装置搜索与演示进展（2026-08-25）

## 结论

v71 已补上 v69/v70 缺失的候选绑定实体部件层，并形成以下可执行链路：

```text
GraphNativeTopologyV69
→ label-free topology compilation
→ candidate-bound physical parameter sample
→ port-to-component realization
→ finite-filament magnetic-field screen
→ collisionless Boris particle-orbit screen
→ Bosch-Hale D-T 0D power screen
→ current-density / magnetic-stress / heat-rejection bounds
→ sealed ranking record
→ candidate-bound 3D and state demo
```

该链路没有使用 `family`、`device_type`、`mechanism_name`、`candidate_label`
或 `parent_family` 路由。v69/v70 历史结果未被覆盖。

## 128 候选粗筛

- 原始结构：128
- 通过图编译并形成实体装置清单：117
- 未捕获异常：0
- `screen_fail`：107
- `screen_unknown`：10
- 粗筛没有产生统计置信完整的 `screen_pass`
- 排名第一：seed 98，5/6 门；缺少的是粒子样本统计置信度

粗筛档案：`runs/physical_device_v71_20260825/search_128_wilson_current.json`

- artifact SHA-256: `2FB1D3EC4EF670493B3F88F236706878109088C4EBEA3E405D7EE824B9AC748A`
- result hash: `6a335ab37aaaa5c4bff3f089a2459e2b1c5fcb01a8c9c77d97fb9c5a49f5d390`

## v71 线性候选：seed 98（已在 v72 淘汰）

实体几何与硬件基线：

- 线性计算/真空区域，半径 `0.4364717397 m`，半长 `1.4558373303 m`
- 候选体积 `1.7426291673 m^3`
- 两个有限圆形线圈
- 单线圈电流 `97,992.038 A`，`13` 匝
- 导体代理半径 `0.0418689537 m`
- 总计 `10` 个部件，覆盖 `8` 类硬件：线圈、真空边界、定向能量注入、
  燃料/排气、冷却、功率执行器、传感器和三级数字控制

候选绑定运行点：

- 总离子密度 `4.4441512275e20 m^-3`
- `Ti = 32.1791 keV`
- `Te = 15.0972 keV`
- 注入加热 `8.05055 MW`
- 排热能力 `192.13212 MW`

256 粒子、完整一次规定穿越长度的复算结果：

- 场强采样范围：`0.33284–1.22678 T`
- 粒子保持：`229/256 = 89.4531%`
- 95% Wilson 下界：`85.0899%`，高于 `80%` 低保真门槛
- 目标时间覆盖：`100%`（`1.66159 μs / 1.65803 μs`）
- D-T `Q_plasma` 代理：`21.2019`
- 聚变功率代理：`170.687 MW`
- 目标运行点所需能量约束时间：`0.21383 s`
- 电流密度、磁应力和排热下界门：通过
- v71 结论：`screen_pass`，6/6 低保真门

复算档案：`runs/physical_device_v71_20260825/seed98_p256_full_transit.json`

- artifact SHA-256: `F21B8612BD9FDDF4E1E60F3101940D92FDAEDEF596F55EA55A70B7B0E0B79F7C`
- evidence hash: `adc25ee02bb272666014b3d0e0566b83585b0d5211b6c2ba330d7e209ee3d2f4`
- result hash: `f3d15f71f827fa125845b7f27e04349d6da698116d9aad25eca561d382809c0c`

v72 对该开放/混合边界候选执行了只用于淘汰的乐观碰撞约束上界：

- 乐观碰撞限制约束时间上界：`0.131838 s`
- 候选要求：`0.213828 s`
- 上界/要求：`0.61656`
- v72 结论：`complete/fail`
- classification：`optimistic_open_field_collision_bound_below_required_tau_e`

因此 seed 98 不再属于活动前沿。

## 当前证据走得最远的实体候选：seed 35

v72 重新排序后，seed 35 因没有已确认的输运硬失败而排在 seed 98 前面；但其闭合场
输运后端尚未实现，所以状态是 `unsupported`，不是通过。

实体几何与硬件基线：

- 旋转对称环形区域，主半径 `3.46038 m`，小半径 `0.64651 m`
- 候选体积 `28.54953 m^3`
- `18` 个有限线圈中心线
- 单线圈电流 `84,789.606 A`，`5` 匝
- 导体代理半径 `0.0593409 m`
- 总计 `9` 个部件，覆盖 `8` 类硬件

候选绑定运行点与 v71 复算：

- 总离子密度 `1.540418e20 m^-3`
- `Ti = 30.0383 keV`，`Te = 21.6669 keV`
- 场强采样范围：`0.43365–0.53084 T`
- 256 粒子完整一周轨道保持：`255/256 = 99.6094%`
- 95% Wilson 下界：`97.8209%`
- 时间覆盖：`12.81605 μs / 12.81453 μs`
- D-T `Q_plasma` 代理：`2.06607`
- 聚变功率代理：`319.016 MW`
- 目标运行点所需能量约束时间：`0.252970 s`
- v71：`screen_pass`，6/6 低保真门
- v72：`incomplete/unsupported`
- v72 classification：`missing_closed_or_nonlocal_transport_capability`

前沿档案：`runs/physical_device_v71_20260825/physical_frontier_v72.json`

- artifact SHA-256: `6D9BA720A0BB4F6CE14348B845D5186C1F781C08499BF920C2EA13D2E5E3DA86`
- v71 evidence hash: `b16d29adcc3c36287836e9bff8a0747f60fa0c5532abccd30209406dc8cb716b`
- v72 evidence hash: `869bf01a1c6e87b73c4ce1c79aca587f77184b4a2bff1014abd08a24d9e11901`
- result hash: `b779d8f3c0b060d10474cfd92c540121763cbe023aa95a78db15eb0f3cfdc988`

## 三维与状态演示

本地演示入口：`http://127.0.0.1:8197/`

演示直接读取 v72 前沿档案中的 seed 35，而不是对抽象拓扑做装置化猜图。它显示：

- 候选专属有限线圈中心线与真空边界；
- Biot-Savart 磁场采样矢量；
- 密封证据中的代表粒子轨迹和模拟时间；
- 由候选绑定密度、温度驱动的 D-T 状态动画；
- 全部实体部件和工程余量；
- 模型缺口与 claim boundary。

Playwright 验收：

- Chrome 控制台：0 error / 0 warning
- 桌面 `1440×1000`：通过
- 移动端 `390×844`：通过
- 图层切换：实体装置、磁场、粒子轨迹、等离子体状态均可操作
- 截图：`output/playwright/physical_frontier_v72_desktop_final.png`
- 截图：`output/playwright/physical_frontier_v72_mobile_final.png`

## 测试

定向回归共 75 项通过：

- v70 streaming resume / merge / hash sealing：19
- v71 physical realization / fail-closed / simulation / main-chain search：40
- v72 collision bound / unsupported routing / frontier selection：16

## 尚未完成的可行性门

`screen_pass` 只能用于调度下一层补证，不能称为可行聚变装置。当前仍缺：

1. 粒子碰撞、散射、电场、集体响应和多物种动力学；
2. 候选绑定输运系数与达到 `tau_E = 0.21383 s` 的证明；
3. MHD/微观稳定性、场误差和有限压力平衡；
4. 有限厚度线圈、电磁力、支撑、热、失超、疲劳和故障闭合；
5. 中子学、屏蔽、氚增殖、真空、燃料循环和完整净电功率账本；
6. 传感器—控制器—执行器闭环稳定性；
7. 独立软件路径复算和更长时间/更多状态点验证；
8. 工程可制造性与机制级原创性证据。

因此，本轮证明的是“实体装置搜索能力已重新接入主链，并获得一个 v71 通过、v72
等待闭合场输运能力的当前前沿候选”，不是“已经搜索到可行聚变装置”。
