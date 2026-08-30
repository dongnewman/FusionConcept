# v127 扩展候选前沿验收

ITER/C-2W scoped regression 为 2/2，bypass=0。修正低-β 前沿 23 个父候选经
`(alpha_m, alpha_n)=(2,1)` profile 重筛后：FreeGS 16 pass、DESC sampled ideal-MHD
12 pass；静态修复生成 108 条，reduced gates 留下 29 条，最终 17 条通过 DESC、9 条
通过九情景静态扰动。

完整下游图得到 40 条 sampled numerical-VVUQ pass，覆盖 4 个候选、14 个 assembly。
通过行的更新净电最小值为 116875611.422 W，
50% 流量故障结构温度最大值为
820.955 K，实际压降最大值为
62380.189 Pa。

Unsupported=0，provider/system failure=0。Validation VVUQ 仍为
`external_evidence_required`，完整稳定性、完整 transport 与 3D 工程资格也未建立，
因此 credible new device=0。这里的 4 条是计算 survivor，不是物理装置验证通过。

Acceptance hash: `7b2b8e1bb0f629cad3c93a55329c8b5c96e8c099930f42a85421915da7c646a3`
