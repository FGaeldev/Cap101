// merge_parallel.js -- merges a "run.sh parallel" report folder into summary.md
// and summary.json: one row per segment (finished? how long, where it ended)
// plus every finding, de-duplicated across segments, with the segments it came from.
//   node merge_parallel.js <report dir>
const fs = require("fs");
const path = require("path");

const out = process.argv[2];
const segDirs = fs.readdirSync(out).filter(d => d.startsWith("seg_")).sort();
const rows = [];
const merged = new Map();   // kind|message -> finding + segments
for (const d of segDirs) {
  const seg = d.slice(4);
  const file = path.join(out, d, "findings.json");
  if (!fs.existsSync(file)) {
    rows.push({ seg, ok: false, reason: "no findings.json (crashed or timed out before writing)", seconds: 0, level: "", findings: 0 });
    continue;
  }
  const r = JSON.parse(fs.readFileSync(file, "utf8"));
  const ok = r.end_reason === "all requested chapters played";
  rows.push({ seg, ok, reason: r.end_reason, seconds: Math.round(r.seconds || 0),
    level: (r.final_level || "").split("/").pop(), findings: (r.findings || []).length });
  for (const f of r.findings || []) {
    const key = `${f.kind}|${f.message}`;
    if (!merged.has(key)) merged.set(key, { kind: f.kind, message: f.message, count: 0, segments: [], screenshot: "", level: f.level || "" });
    const m = merged.get(key);
    m.count += f.count || 1;
    if (!m.segments.includes(seg)) m.segments.push(seg);
    if (!m.screenshot && f.screenshot) m.screenshot = path.posix.join(d, f.screenshot);
  }
}
const findings = [...merged.values()].sort((a, b) => (a.kind === "warning") - (b.kind === "warning") || b.segments.length - a.segments.length);
const longest = Math.max(0, ...rows.map(r => r.seconds));
const total = rows.reduce((s, r) => s + r.seconds, 0);

let md = `# Parallel playtest ${path.basename(out)}\n\n`;
md += `${rows.filter(r => r.ok).length} of ${rows.length} segments reached their finish line. `;
md += `Wall time about ${Math.round(longest / 60)} min for ${Math.round(total / 60)} min of play.\n\n`;
md += `| Segment | Finished | Time | Ended in | Findings | End reason |\n|---|---|---|---|---|---|\n`;
for (const r of rows) md += `| ${r.seg} | ${r.ok ? "yes" : "**no**"} | ${Math.round(r.seconds / 60)} min | ${r.level} | ${r.findings} | ${r.reason} |\n`;
md += `\n## Findings (${findings.length}, merged across segments)\n\n`;
md += `| Kind | Segments | Count | Message | Screenshot |\n|---|---|---|---|---|\n`;
for (const f of findings) md += `| ${f.kind} | ${f.segments.join(", ")} | ${f.count} | ${String(f.message).replace(/\|/g, "\\|").replace(/\n/g, " ").slice(0, 300)} | ${f.screenshot} |\n`;
fs.writeFileSync(path.join(out, "summary.md"), md);
fs.writeFileSync(path.join(out, "summary.json"), JSON.stringify({ segments: rows, findings }, null, "\t"));
console.log(`merged ${rows.length} segments, ${findings.length} findings -> summary.md`);
for (const r of rows) console.log(`   ${r.seg}: ${r.ok ? "finished" : "NOT finished"} in ${Math.round(r.seconds / 60)} min (${r.reason})`);
