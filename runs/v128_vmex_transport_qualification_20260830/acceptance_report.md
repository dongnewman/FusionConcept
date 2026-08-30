# v128 VMEX/transport 候选重筛验收

ITER 与 C-2W 已先按普通 capability/mission 通道重跑：scoped regression 2/2，
bypass=0，unsupported=0；完整资格与 validation 均为 0。

v127 的 4 个 computational survivors 全部重新执行候选绑定 FreeGS。2 个在当前复跑中
直接违反 FreeGS 几何/压力绑定门；2 个可复现并完成 DESC wout、VMEX 局部稳定性、NEO_JAX、
GKX 梯度分解敏感性及 ESSOS alpha 轨道诊断。其中 1 个数值 VVUQ 不闭合，另 1 个通过数值
VVUQ 后违反 Glasser 电阻交换必要条件。最终 physical reject=3，
numerical VVUQ reject=1，provider/system failure=
0，unsupported=0，advanced numerical survivor=0。

本轮没有可进入 validation VVUQ 的候选，因此 credible new device=0。NEO/GKX/短时 alpha
结果不被扩大为完整 transport、完整稳定性、实验验证或整机可信结论。标签擦除、ID/顺序置换、
未见拓扑、缺 provider、部分闭合和 wout 哈希篡改负控均通过。

Acceptance hash: `e71dc305df2ebb941940adb8486d23ea54c6c7408fb96e479b9bffe0aa95f24f`
