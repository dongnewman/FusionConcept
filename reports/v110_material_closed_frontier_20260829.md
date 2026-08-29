# v110 material-closed high-fidelity frontier

ITER/C-2W reference regression reran first and passed 2/2 with 0 bypasses.

The material-closed frontier retained 40 previously unexecuted candidates. FreeGS passed 39; DESC cross-code equilibrium plus sampled ideal-MHD retained 2; the nine-case static engineering provider retained 0. Final high-fidelity frontier survivors: 0.

Blockers: `{"free_boundary_equilibrium":1,"static_engineering_proxy":2,"cross_code_equilibrium":5,"sampled_local_ideal_mhd":32}`.

The temporary six-worker DESC OOM was rerun at three workers and is absent from the final artifact: provider system failure=0, unsupported=0. No partial result receives whole-device, validation or credibility credit.

Acceptance hash: `b885b2d561a42dd62652139ce206ec2e7631580f9d143d92cba40bb9bef3151f`

v110 selects previously unexecuted reduced-physics candidates using only declared reactor mission output, radial build, beta_n and conservative material-screen inputs. Candidate hashes are used only to avoid duplicate computation, never as provider or metric inputs. Selection grants no FreeGS, stability, engineering, validation or whole-device credit.
