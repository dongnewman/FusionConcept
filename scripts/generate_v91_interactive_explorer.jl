#!/usr/bin/env julia

using FusionConceptAI
using JSON3

const ROOT_V91_UI = normpath(joinpath(@__DIR__, ".."))
acceptance_path = joinpath(ROOT_V91_UI, "runs",
    "multitopology_acceptance_v91_20260827.json")
formal_root = joinpath(ROOT_V91_UI, "runs",
    "multitopology_v91_formal_1000000_20260827")
acceptance = JSON3.read(read(acceptance_path, String), Dict{String,Any})
first_dossier = open(joinpath(formal_root, "survivor_dossiers_v91.jsonl"), "r") do io
    JSON3.read(readline(io), Dict{String,Any})
end
payload = JSON3.write(Dict("acceptance" => acceptance, "dossier" => first_dossier))
output_dir = joinpath(ROOT_V91_UI, "interactive_v91_device_explorer")
output_path = joinpath(output_dir, "index.html"); mkpath(output_dir)

html = """<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<link rel="icon" href="data:,">
<title>FusionConceptAI v91 — Million Topology Evidence Explorer</title>
<style>
:root{--ink:#e9f2ff;--muted:#91a6bf;--panel:#101b2d;--line:#29415f;--cyan:#3dd6d0;--amber:#ffc857;--red:#ff6b6b;--green:#76e6a5;--bg:#07111f}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 80% -20%,#173a58 0,var(--bg) 42%);color:var(--ink);font:14px/1.55 Inter,Segoe UI,system-ui,sans-serif}
header{padding:28px 34px 20px;border-bottom:1px solid var(--line);display:flex;justify-content:space-between;gap:24px;align-items:flex-end}.eyebrow{color:var(--cyan);letter-spacing:.16em;text-transform:uppercase;font-size:11px}.title{font-size:30px;font-weight:680;margin:4px 0}.hash{color:var(--muted);font:11px/1.4 Consolas,monospace;max-width:430px;word-break:break-all}
.layout{display:grid;grid-template-columns:250px 1fr;min-height:calc(100vh - 108px)}nav{border-right:1px solid var(--line);padding:22px 16px;position:sticky;top:0;height:calc(100vh - 108px)}button{width:100%;text-align:left;border:0;background:transparent;color:var(--muted);padding:11px 13px;border-radius:8px;margin:2px 0;cursor:pointer}button:hover,button.active{background:#17304a;color:var(--ink)}main{padding:26px 32px 60px;max-width:1450px}.view{display:none}.view.active{display:block}.grid{display:grid;grid-template-columns:repeat(4,minmax(160px,1fr));gap:12px}.card{background:linear-gradient(145deg,#122238,#0c1727);border:1px solid var(--line);border-radius:12px;padding:16px}.metric{font-size:25px;font-weight:700;color:var(--cyan)}.label{color:var(--muted);font-size:12px}.section{margin-top:22px}.section h2{font-size:17px;margin:0 0 12px}.pass{color:var(--green)}.fail,.unsupported{color:var(--red)}.unknown{color:var(--amber)}table{width:100%;border-collapse:collapse;background:#0d1929;border:1px solid var(--line)}th,td{padding:9px 11px;border-bottom:1px solid #1f344e;text-align:left;vertical-align:top}th{color:var(--muted);font-weight:600}.mono{font-family:Consolas,monospace;font-size:12px;word-break:break-all}.notice{border-left:3px solid var(--amber);background:#231f19;padding:12px 14px;color:#f6dfaa;border-radius:4px}.graph{width:100%;height:340px;background:#091523;border:1px solid var(--line);border-radius:12px}.node rect{fill:#142c44;stroke:var(--cyan);stroke-width:1.5}.node text{fill:var(--ink);font-size:10px}.edge{stroke:#53789e;stroke-width:2;marker-end:url(#arrow)}pre{white-space:pre-wrap;background:#08121f;border:1px solid var(--line);border-radius:8px;padding:14px;color:#b7d4ed}.pill{display:inline-block;padding:2px 8px;border:1px solid currentColor;border-radius:99px;font-size:11px}.two{display:grid;grid-template-columns:1fr 1fr;gap:14px}@media(max-width:900px){.layout{grid-template-columns:1fr}nav{position:static;height:auto;border-right:0;border-bottom:1px solid var(--line);display:flex;overflow:auto}nav button{min-width:130px}.grid{grid-template-columns:repeat(2,1fr)}main{padding:20px}.two{grid-template-columns:1fr}}
</style>
</head>
<body>
<header><div><div class="eyebrow">FusionConceptAI / v91 sealed evidence</div><div class="title">Million Topology Evidence Explorer</div><div>真实生成、候选绑定筛选与证据分层；不是装置可行性宣传页。</div></div><div class="hash" id="artifactHash"></div></header>
<div class="layout"><nav>
<button class="active" data-view="overview">Campaign 总览</button>
<button data-view="topology">最简审计候选</button>
<button data-view="evidence">Evidence dossier</button>
<button data-view="novelty">新颖性矩阵</button>
<button data-view="replay">重放与哈希</button>
</nav><main>
<section class="view active" id="overview"><div class="grid" id="metrics"></div><div class="section"><h2>三层实际执行</h2><table id="campaignTable"></table></div><div class="section notice">搜索能力完成与装置可信度是两条独立轴。这里的 1,000,000 指实际生成、canonicalize、编译并执行 reduced candidate-bound screen 的请求；不代表 1,000,000 个物理可行装置。</div><div class="section"><h2>证据等级</h2><table id="levels"></table></div></section>
<section class="view" id="topology"><div class="two"><div><h2 id="candidateTitle"></h2><div class="hash" id="candidateHash"></div></div><div class="notice">该候选最高只能命名为 <b>novel_topology_candidate</b>；validation 与工程义务未闭合。</div></div><div class="section"><svg class="graph" id="graph" viewBox="0 0 1120 340"></svg></div><div class="section two"><div><h2>Genome structural genes</h2><pre id="genes"></pre></div><div><h2>Basis coefficients</h2><pre id="basis"></pre></div></div><div class="section"><h2>Candidate-bound solver input</h2><table id="solverInput"></table></div></section>
<section class="view" id="evidence"><div class="section"><h2>全部审计 slots</h2><table id="stageTable"></table></div><div class="section"><h2>主要阻塞项</h2><pre id="blockers"></pre></div></section>
<section class="view" id="novelty"><div class="notice">矩阵只证明声明 region-abstraction 与检索目录内的非同构。它不是穷尽 prior-art、专利性或 FTO 意见。</div><div class="section"><table id="noveltyTable"></table></div></section>
<section class="view" id="replay"><div class="grid" id="replayMetrics"></div><div class="section"><h2>重放命令</h2><pre>julia --project=. scripts/verify_v91_campaign_replay.jl
julia --project=. scripts/seal_v91_acceptance.jl</pre></div><div class="section"><h2>封存哈希</h2><pre id="hashes"></pre></div></section>
</main></div>
<script id="payload" type="application/json">$payload</script>
<script>
const data=JSON.parse(document.getElementById('payload').textContent),a=data.acceptance,d=data.dossier;
const esc=x=>String(x??'').replace(/[&<>\"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;'}[c]));
document.getElementById('artifactHash').textContent='artifact SHA-256  '+a.artifact_hash;
document.querySelectorAll('nav button').forEach(b=>b.onclick=()=>{document.querySelectorAll('nav button,.view').forEach(x=>x.classList.remove('active'));b.classList.add('active');document.getElementById(b.dataset.view).classList.add('active')});
const lc=a.layer_counts, metricData=[['1,000,000','formal requests'],[lc.formal_unique_nonisomorphic_topologies,'unique non-isomorphic'],[lc.formal_capability_cells,'capability cells'],[lc.formal_reduced_hard_gate_survivors,'hard-gate survivors']];
document.getElementById('metrics').innerHTML=metricData.map(x=>'<div class="card"><div class="metric">'+x[0]+'</div><div class="label">'+x[1]+'</div></div>').join('');
const campaigns=a.campaigns;document.getElementById('campaignTable').innerHTML='<tr><th>tier</th><th>records</th><th>unique topology</th><th>solver inputs</th><th>cells</th><th>survivors</th><th>status</th></tr>'+Object.keys(campaigns).map(k=>{const x=campaigns[k];return '<tr><td>'+k+'</td><td>'+x.result_count+'</td><td>'+x.unique_nonisomorphic_topologies+'</td><td>'+x.unique_solver_inputs+'</td><td>'+x.capability_cell_count+'</td><td>'+x.hard_gate_survivor_count+'</td><td class="pass">'+x.status+'</td></tr>'}).join('');
const levelRows=[['novel_topology_candidate',lc.novel_topology_candidates],['computationally_credible_fusion_device_concept',lc.computationally_credible_fusion_device_concepts],['engineering_qualified_fusion_device_design',lc.engineering_qualified_fusion_device_designs],['experimentally_validated_new_fusion_device',lc.experimentally_validated_new_fusion_devices]];
document.getElementById('levels').innerHTML='<tr><th>严格名称</th><th>count</th></tr>'+levelRows.map(x=>'<tr><td>'+x[0]+'</td><td>'+x[1]+'</td></tr>').join('');
document.getElementById('candidateTitle').textContent=d.candidate_id;document.getElementById('candidateHash').textContent='dossier '+d.dossier_hash;document.getElementById('genes').textContent=JSON.stringify(d.genome.structural_gene_digits,null,2);document.getElementById('basis').textContent=JSON.stringify(d.basis,null,2);
const si=d.solver_input;document.getElementById('solverInput').innerHTML='<tr><th>field</th><th>value</th></tr>'+[['solver_input_hash',si.solver_input_hash],['backend_id',si.backend_id],['capability_cell',si.capability_cell],['structural genes consumed',si.structural_gene_consumers.length],['basis consumed',si.basis_consumers.length],['normalized residual',d.screen_result.normalized_residual],['independent balance',d.screen_result.independent_balance_error]].map(x=>'<tr><td>'+x[0]+'</td><td class="mono">'+x[1]+'</td></tr>').join('');
const stages=d.stages;document.getElementById('stageTable').innerHTML='<tr><th>stage</th><th>status</th><th>metric / blocker</th></tr>'+stages.map(s=>{const cls=s.status.startsWith('pass')?'pass':s.status==='unknown'?'unknown':s.status==='unsupported'?'unsupported':'';return '<tr><td>'+esc(s.stage_id)+'</td><td class="'+cls+'"><span class="pill">'+esc(s.status)+'</span></td><td>'+esc(s.unavailable_reason??s.metric??s.evidence_ceiling??'recorded in dossier')+'</td></tr>'}).join('');
document.getElementById('blockers').textContent=a.dominant_blockers.join('\\n');
const novelty=stages.find(s=>s.stage_id==='external_novelty').comparison_matrix;document.getElementById('noveltyTable').innerHTML='<tr><th>reference</th><th>mapped nodes</th><th>isomorphic</th><th>proof</th><th>source</th></tr>'+novelty.map(x=>'<tr><td>'+esc(x.reference_id)+'</td><td>'+x.mapped_region_count+'</td><td>'+x.isomorphic+'</td><td>'+esc(x.nonisomorphism_proof)+'</td><td><a style="color:#3dd6d0" href="'+esc(x.source_url)+'">'+esc(x.source_title)+'</a></td></tr>').join('');
const r=a.full_hash_replay;document.getElementById('replayMetrics').innerHTML=[['records',r.record_hashes_replayed],['dossiers',r.dossier_hashes_replayed],['status',r.status],['replay hash',r.replay_hash.slice(0,12)+'…']].map(x=>'<div class="card"><div class="metric">'+x[1]+'</div><div class="label">'+x[0]+'</div></div>').join('');document.getElementById('hashes').textContent=JSON.stringify({artifact:a.artifact_hash,replay:r.replay_hash,formal:a.campaigns.formal_1000000.merge_hash,source_integrity:a.source_integrity},null,2);
const topo=d.genome.topology,nodes=Object.fromEntries(topo.nodes.map(n=>[n.node_id,n])),next=Object.fromEntries(topo.interfaces.map(e=>[e.source_node_id,e]));let order=[],id=topo.root_id;while(id){order.push(id);id=next[id]?.target_node_id}const svg=document.getElementById('graph');svg.innerHTML='<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#53789e"/></marker></defs>'+order.slice(0,-1).map((id,i)=>'<line class="edge" x1="'+(95+i*155)+'" y1="170" x2="'+(155+i*155)+'" y2="170"/>').join('')+order.map((id,i)=>{const n=nodes[id],x=20+i*155;return '<g class="node"><rect x="'+x+'" y="115" width="125" height="110" rx="9"/><text x="'+(x+10)+'" y="140"><tspan x="'+(x+10)+'">'+esc(n.role)+'</tspan><tspan x="'+(x+10)+'" dy="18">'+esc(n.dimension)+' · '+esc(n.boundary)+'</tspan><tspan x="'+(x+10)+'" dy="18">'+esc(n.operator)+'</tspan><tspan x="'+(x+10)+'" dy="18">'+esc(n.field_semantics)+'</tspan></text></g>'}).join('');
</script></body></html>"""

temporary = output_path * ".partial"
open(temporary, "w") do io; write(io, html); end
mv(temporary, output_path; force = true)
println(JSON3.write(Dict("status" => "generated", "output" => output_path,
    "sha256" => FusionConceptAI._s70_file_sha256(output_path))))
