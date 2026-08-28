from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / "runs" / "physical_closure_v92_formal_417_20260828"
BUNDLE = RUN / "farthest_candidate_v92" / "farthest_candidate_complete_dossier_v92.json"
OUT = ROOT / "interactive_v92_closure_explorer" / "index.html"


def main() -> None:
    data = json.loads(BUNDLE.read_text(encoding="utf-8"))
    payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    html = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="icon" href="data:,">
<title>FusionConceptAI V92 closure explorer</title>
<style>
:root{color-scheme:dark;--bg:#07111b;--card:#0e2030;--line:#27465c;--text:#d9edf7;--muted:#89a9ba;--cyan:#3ee2d0;--orange:#ffab52;--red:#ff6b75}*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 20% 0,#123047,#07111b 45%);font:14px/1.45 system-ui;color:var(--text)}header{padding:22px 28px;border-bottom:1px solid var(--line)}h1{margin:0 0 5px;font-size:22px}header p{margin:0;color:var(--muted)}nav{display:flex;gap:8px;padding:14px 28px;flex-wrap:wrap}button{background:#102b3e;color:var(--text);border:1px solid var(--line);border-radius:7px;padding:8px 12px;cursor:pointer}button.active{border-color:var(--cyan);color:var(--cyan)}main{padding:0 28px 28px}.panel{display:none}.panel.active{display:grid;grid-template-columns:minmax(460px,1.5fr) minmax(280px,.8fr);gap:16px}.card{background:rgba(14,32,48,.93);border:1px solid var(--line);border-radius:12px;padding:16px}canvas{width:100%;height:600px;background:#050c13;border-radius:8px}.controls{display:grid;grid-template-columns:auto 1fr;gap:10px;align-items:center;margin-top:12px}input{width:100%}.status{font-weight:700;color:var(--red)}.pass{color:var(--cyan)}pre{white-space:pre-wrap;word-break:break-word;color:#bcd5e2;max-height:620px;overflow:auto}.metric{padding:9px 0;border-bottom:1px solid var(--line)}.metric span{display:block;color:var(--muted);font-size:12px}@media(max-width:900px){.panel.active{grid-template-columns:1fr}canvas{height:450px}}
</style></head><body><header><h1>FusionConceptAI V92 closure explorer</h1><p id="subtitle"></p></header>
<nav><button data-tab="geometry" class="active">GeometryIR</button><button data-tab="surfaces">Magnetic surfaces</button><button data-tab="orbits">Orbits</button><button data-tab="modes">Modes</button><button data-tab="vvuq">VVUQ / decision</button></nav><main>
<section id="geometry" class="panel active"><div class="card"><canvas id="view" width="1000" height="650"></canvas><div class="controls"><label>Rotation</label><input id="rotation" type="range" min="0" max="628" value="70"><label>Elevation</label><input id="elevation" type="range" min="-120" max="120" value="35"><label>Zoom</label><input id="zoom" type="range" min="50" max="180" value="100"></div></div><div class="card" id="geometryInfo"></div></section>
<section id="surfaces" class="panel"><div class="card"><h2>Magnetic surfaces</h2><p class="status">UNSUPPORTED — no compatible mixed-topology equilibrium backend</p><p>No equilibrium field or magnetic-surface result exists. Candidate input surfaces are visible in GeometryIR; they are not equilibrium magnetic surfaces.</p></div><div class="card"><pre id="surfaceData"></pre></div></section>
<section id="orbits" class="panel"><div class="card"><h2>Field-line / orbit</h2><p class="status">UNSUPPORTED UPSTREAM</p><p>The orbit request was not scheduled because applicable_equilibrium did not pass. No synthetic trajectory is rendered.</p></div><div class="card"><pre id="orbitData"></pre></div></section>
<section id="modes" class="panel"><div class="card"><h2>Stability modes</h2><p class="status">UNSUPPORTED UPSTREAM</p><p>Applicable modes retain unsupported status. No eigenfunction or growth-rate curve is rendered.</p></div><div class="card"><pre id="modeData"></pre></div></section>
<section id="vvuq" class="panel"><div class="card"><h2>VVUQ and promotion</h2><div id="decisionInfo"></div></div><div class="card"><pre id="vvuqData"></pre></div></section>
</main><script id="bundle" type="application/json">__DATA__</script><script>
const d=JSON.parse(document.getElementById('bundle').textContent), g=d.GeometryIR, s=g.scales;
document.getElementById('subtitle').textContent=`${d.candidate_id} · ${d.candidate_hash.slice(0,16)}… · protocol ${d.protocol_id}`;
for(const b of document.querySelectorAll('nav button'))b.onclick=()=>{document.querySelectorAll('nav button,.panel').forEach(x=>x.classList.remove('active'));b.classList.add('active');document.getElementById(b.dataset.tab).classList.add('active')};
document.getElementById('geometryInfo').innerHTML=`<h2>Candidate-bound geometry</h2><div class=metric><span>Realization</span><b class=pass>${g.qualification.status}</b></div><div class=metric><span>Major / minor radius</span>${s.major_radius_m.toFixed(3)} m / ${s.minor_radius_m.toFixed(3)} m</div><div class=metric><span>Field periods</span>${s.field_periods}</div><div class=metric><span>Regions</span>${g.regions.map(x=>x.region_type).join(', ')}</div><div class=metric><span>Materialized meshes</span>${d.materialized_meshes.map(x=>`${x.role}: ${x.cell_count||x.face_count}`).join('<br>')}</div><div class=metric><span>Claim boundary</span>${d.claim_boundary}</div>`;
document.getElementById('surfaceData').textContent=JSON.stringify({input_oriented_surfaces:g.oriented_surfaces,equilibrium:d.equilibrium},null,2);
document.getElementById('orbitData').textContent=JSON.stringify(d.orbits,null,2);document.getElementById('modeData').textContent=JSON.stringify(d.modes,null,2);document.getElementById('vvuqData').textContent=JSON.stringify(d.VVUQ_and_validation,null,2);
document.getElementById('decisionInfo').innerHTML=`<div class=metric><span>Computationally credible</span><b class=status>${d.promotion_decision.computationally_credible_fusion_device_concept}</b></div><div class=metric><span>First blocker</span>${d.promotion_decision.first_blocker}</div><div class=metric><span>Candidate-bound validation</span>${d.VVUQ_and_validation.candidate_bound_validation_vvuq}</div>`;
const c=document.getElementById('view'),x=c.getContext('2d'),rot=document.getElementById('rotation'),elev=document.getElementById('elevation'),zoom=document.getElementById('zoom');
function project(X,Y,Z,a,e,z){let ca=Math.cos(a),sa=Math.sin(a),ce=Math.cos(e),se=Math.sin(e),u=ca*X-sa*Y,v=sa*X+ca*Y,w=Z;let vv=ce*v-se*w,ww=se*v+ce*w;return[c.width/2+u*z,c.height/2-vv*z,ww]}
function ring(rho,color,width,a,e,z){for(let t=0;t<12;t++){x.beginPath();for(let p=0;p<=160;p++){let ph=2*Math.PI*p/160,th=2*Math.PI*t/12,R=s.major_radius_m+rho*Math.cos(th+s.triangularity*Math.sin(th))+.06*rho*Math.cos(s.field_periods*ph),Z=rho*s.elongation*Math.sin(th)+.04*rho*Math.sin(s.field_periods*ph),q=project(R*Math.cos(ph),R*Math.sin(ph),Z,a,e,z);p?x.lineTo(q[0],q[1]):x.moveTo(q[0],q[1])}x.strokeStyle=color;x.lineWidth=width;x.stroke()}}
function draw(){x.clearRect(0,0,c.width,c.height);let a=+rot.value/100,e=+elev.value/100,z=+zoom.value/100*55;ring(s.minor_radius_m,'#3ee2d0',1.2,a,e,z);ring(1.4*s.minor_radius_m,'#89a9ba',.7,a,e,z);ring(1.85*s.minor_radius_m,'#ffab52',1.0,a,e,z);x.fillStyle='#d9edf7';x.fillText('Candidate input geometry — not an equilibrium magnetic surface',18,28)}[rot,elev,zoom].forEach(i=>i.oninput=draw);draw();
</script></body></html>'''.replace("__DATA__", payload)
    if OUT.exists() and OUT.read_text(encoding="utf-8") != html:
        raise RuntimeError(f"immutable explorer differs: {OUT}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(html, encoding="utf-8")
    print(json.dumps({"path": OUT.relative_to(ROOT).as_posix(), "bytes": OUT.stat().st_size}))


if __name__ == "__main__":
    main()
