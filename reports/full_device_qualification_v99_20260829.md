# v99 通用整机资格链验收报告

## 结论

v98 的 31 个 FreeGS 数值 VVUQ survivor 已全部进入 FreeGS→DESC 跨代码平衡与抽样理想 MHD 筛查。最终批次完整处理 31/31，provider 系统失败为 0，候选 `unsupported` 为 0，但没有整机可信候选，也没有 validation VVUQ 通过候选。

- 24 个：抽样 Mercier 门失败；
- 4 个：DESC 跨代码平衡失败；
- 1 个：m=24 时边界拟合仍超过 8% 门；
- 1 个：FreeGS q 样本导出的 iota 插值离开审计域；
- 1 个：通过跨代码平衡、Mercier 与 infinite-n ballooning 抽样门，但在 9 个 FreeGS PF 静态扰动工况中触发峰值场与支撑应力代理失败。

跨代码批次 hash 为 `2534cb995ac3b1f8fb08f6b8ca40a41e8fba592dec86d01955f583ef26d2b7da`，整机闭合验收 hash 为 `34c5a4ea3acd9beea147e29270554360a59bccc4871129bc323f4405634a755d`。

## 筛选器与候选原因的分离

初版 12 阶 Fourier 适配器对 7 个候选给出映射失败。保持 8% 误差门不变、改为预声明的 12/16/20/24 自适应模态后，6 个候选能够进入 DESC；其中 5 个随后明确触发 Mercier 失败，1 个触发 DESC 平衡延拓失败。说明初版适配器确有假阴性，但修复后并没有产生新的稳定候选。

唯一抽样局部理想 MHD 候选是 request 68443。9/9 个 FreeGS 工况均收敛，最大磁轴位移约为小半径的 0.155%，但最大 additive peak-field proxy 为 24.46 T（门限 16 T），最大 membrane support-stress proxy 为 3.38 GPa（门限 0.65 GPa）。这是候选绑定的工程代理拒绝，也说明 v98 低成本工程门不足以代表 PF/内侧绕组负载。

## 参考控制与证据边界

ITER 与 C-2W 参考控制均通过回归：ITER 仅验证轴对称桥接路由，C-2W 保持开放场 extended-MHD/kinetic provider 路由，没有被错误送入轴对称 DESC。两者均不作为新候选，也不提供 experimental validation credit。

DESC 通过仅覆盖固定边界平衡以及抽样 Mercier/infinite-n ballooning；FreeGS 工程阶段仅覆盖静态扰动和简化电流、场、应力代理。有限 n、电阻/动力学/非线性稳定性、输运与排热、材料、动态控制和候选绑定实验验证仍未闭合，不能据此扩大为整机物理可行或可信装置结论。

## 软件与产物验收

v99 轴对称扩展通过独立、hash-pinned runner 装载，历史 DESC Fourier 与稳定性 runner 分别保持封存 hash `9e0130...f252` 和 `274d91...dd67`。独立入口对 request 68443 的复算获得与原批次完全相同的 DESC result hash。完整 Julia `Pkg.test()` 套件、Python 编译、v99 产物 hash/绑定检查以及 NFP/非轴对称模态负控均通过。
