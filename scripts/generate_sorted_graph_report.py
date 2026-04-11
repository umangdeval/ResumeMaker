import json
from collections import Counter, defaultdict
from pathlib import Path

root = Path("graphify-out")
obj = json.loads((root / "graph.json").read_text())
nodes = obj.get("nodes", [])
links = obj.get("links", [])

community_counts = Counter(n.get("community", -1) for n in nodes)
community_samples = defaultdict(list)
for n in nodes:
    cid = n.get("community", -1)
    if len(community_samples[cid]) < 5:
        community_samples[cid].append(n.get("label") or n.get("id"))

id_to_label = {n.get("id"): (n.get("label") or n.get("id")) for n in nodes}
deg = Counter()
for e in links:
    s = e.get("source")
    t = e.get("target")
    if s is not None:
        deg[s] += 1
    if t is not None:
        deg[t] += 1


def color_for_size(size: int) -> str:
    if size >= 40:
        return "RED"
    if size >= 20:
        return "ORANGE"
    if size >= 10:
        return "YELLOW"
    if size >= 5:
        return "GREEN"
    return "BLUE"


def color_for_degree(d: int) -> str:
    if d >= 15:
        return "RED"
    if d >= 10:
        return "ORANGE"
    if d >= 6:
        return "YELLOW"
    if d >= 3:
        return "GREEN"
    return "BLUE"


sorted_communities = sorted(community_counts.items(), key=lambda x: (-x[1], x[0]))
top_nodes = sorted(deg.items(), key=lambda x: (-x[1], str(x[0])))[:25]

out = []
out.append("# Graph Report (Sorted + Color Coded)")
out.append("")
out.append("Generated from `graphify-out/graph.json`.")
out.append("")
out.append("## Legend")
out.append("- RED: very high")
out.append("- ORANGE: high")
out.append("- YELLOW: medium")
out.append("- GREEN: low")
out.append("- BLUE: very low")
out.append("")
out.append("## Snapshot")
out.append(f"- Nodes: {len(nodes)}")
out.append(f"- Edges: {len(links)}")
out.append(f"- Communities: {len(sorted_communities)}")
out.append("")
out.append("## Communities (Sorted By Node Count)")
out.append("")
out.append("| Rank | Community | Size | Color | Sample Nodes |")
out.append("|---:|---:|---:|:---:|---|")
for i, (cid, size) in enumerate(sorted_communities, start=1):
    sample = ", ".join(community_samples[cid]) if community_samples[cid] else "-"
    out.append(f"| {i} | {cid} | {size} | {color_for_size(size)} | {sample} |")
out.append("")
out.append("## Top Nodes (Sorted By Degree)")
out.append("")
out.append("| Rank | Node | Degree | Color |")
out.append("|---:|---|---:|:---:|")
for i, (nid, d) in enumerate(top_nodes, start=1):
    label = id_to_label.get(nid, str(nid)).replace("|", "\\|")
    out.append(f"| {i} | {label} | {d} | {color_for_degree(d)} |")
out.append("")
out.append("## Notes")
out.append("- Community colors are based on cluster size (largest clusters are RED).")
out.append("- Node colors are based on node degree (most connected nodes are RED).")

(root / "GRAPH_REPORT_SORTED.md").write_text("\n".join(out))
print("Wrote graphify-out/GRAPH_REPORT_SORTED.md")
