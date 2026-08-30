# v103 mission-aware reference 与候选重筛验收

## Reference 结果

| 输入 | 声明任务 | numerical VVUQ | scoped regression | 完整资格 | validation | 未闭合项 |
|---|---|---|---|---|---|---|
| ITER | pulsed_fusion_research | pass | pass | qualification_incomplete | not_applicable_reference_design | cryogenic, maintenance, shielding, structure, thermal_material, transport_or_kinetic, validation_vvuq, complete_stability |
| C-2W | open_field_experimental_sustainment | pass | pass | qualification_incomplete | external_evidence_required | cryogenic, maintenance, shielding, structure, thermal_material, transport_or_kinetic, validation_vvuq, complete_stability |

新通道不再使用旧 v98 reference bypass。ITER/C-2W 都先以 v89 反解多区域图完成 v96
whole-graph solve，再执行各自 capability/mission 所需的 v90 provider stages；2/2 scoped
reference regression 通过，new bypass=0。反应堆净电、中子壁负荷等门不会再施加给未声明这些
任务的参考装置。

这不是完整资格通过。两者仍缺完整 kinetic/transport、非线性稳定性、结构材料、屏蔽、低温和
维护等证据。ITER 是设计基线，不能产生实验 validation；C-2W 虽有公开实验区间，但仓库没有
原始 shot、标定哈希、测量不确定度数据包和独立 owner attestation，因此 validation 仍为
external_evidence_required。

## 候选重筛

参考门通过后，79 个既有 v100 net-electric D-T reactor retained candidates 已按其显式
campaign mission 重新裁决；本次没有重写 v100 候选数据，也没有把这一批扩大解释成全拓扑重跑。
结果保持 78 physical_reject、1 qualification_incomplete、0 unsupported、0 provider system
failure、0 credible、0 validation pass。参考装置的任务门修复不会放宽新反应堆候选的门槛。

Acceptance hash: `15a898d9510193b414c361f5e44ea26c35c9a3414efe9e28d4d2570e078f8ecf`

v103 routes gates and providers only from declared mission observables, physical capabilities, operators, regions, dimensions, boundaries, and field semantics. A reference regression pass proves scoped software recall, not whole-device qualification or independent validation. Missing high-fidelity or measurement evidence remains qualification_incomplete and is never converted into physical failure or pass.
