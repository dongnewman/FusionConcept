# v119 shared-state binding audit

ITER/C-2W scoped regression: 2/2, bypass=0.

Corrected v114 front: FreeGS 9/9 pass, but DESC equilibrium 0/9. Corrected low-beta
front: FreeGS 23/30 pass; DESC rejects 3 at equilibrium and 20 at sampled Mercier.
Therefore the current shared-state survivor count is 0.

The 101 v118 sampled downstream rows are retained as sealed history but their current
survivor credit is withdrawn: the old FreeGS and DESC artifacts represented different
volume-average pressure/beta/flux states. This is an evidence-binding correction, not a
new physical rejection of those candidates.

Unsupported=0, provider-system-failure=0, validation not executed, credible device=0.

Acceptance hash: `9ec8705bbc9b1d02ed7a389d30d00c4b35886c2b2ccdc8a27702dab057ea685f`
