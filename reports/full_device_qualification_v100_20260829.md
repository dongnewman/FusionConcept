# v100 通用候选绑定整机资格验收

## 结论

v100 已完成两条互补物理前沿的统一高保真链路。79 个唯一设计候选中，
73 个通过 FreeGS 三网格数值 VVUQ，4 个通过
FreeGS→DESC 跨代码平衡与抽样 Mercier/infinite-n ballooning，1 个通过
9 工况静态 PF 扰动及显式绕组/支撑工程代理。

唯一静态工程代理幸存者为 request `609214000287`。其最终状态是
`qualification_incomplete`，不是可信整机：完整稳定性、输运/约束、粒子与热排出、完整材料和
工程、动态控制/故障响应及候选绑定独立 validation VVUQ 均未闭合。因此整机可信数和
validation pass 数均为 0。

## 筛选器诊断

- v99 将工程代理与 FreeGS 的 PF 几何分开定义；v100 以同一显式径向布局贯通预筛、FreeGS 和静态扰动。
- 旧 DESC bridge 在 m=24 平衡下仍固定用 m=18 Mercier 采样，产生 provider error；现改为
  `max(18, equilibrium M)`，审计上限仍为 24，复算后 system failure 为 0。
- 修复显著减少了平衡阶段误拒，但主要淘汰原因仍是候选绑定的 Mercier、跨代码平衡及工程门，
  不是 `unsupported`。

## 参考控制与证据边界

ITER/C-2W 参考控制 2/2 通过同链 capability 路由和数值回归，候选信用与 validation credit
均为 0。provider system failure=0，unsupported=0，子图提升被禁止。

Acceptance hash: `175d97b1d423ced583b484768f1c4099cc833c8850f41b6a018aa2d9df55bedc`

v100 separates reduced physics, FreeGS equilibrium and numerical VVUQ, cross-code equilibrium, sampled local ideal-MHD, static engineering proxies, complete qualification, and independent validation. A static-proxy pass remains qualification_incomplete; no subgraph result, reference control, candidate label, ID, or hash grants physical or validation promotion.
