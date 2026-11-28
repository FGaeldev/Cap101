// Usage: node wordusage.js <Cap101/data dir> <out dir>
const fs = require("fs"), path = require("path");
const D = process.argv[2], OUT = process.argv[3];
const rd = f => fs.readFileSync(path.join(D, f), "utf8");
const wb = JSON.parse(rd("word_bank.json")).words;
const idsIn = f => new Set((rd(f).match(/"w\d+"/g) || []).map(x => x.slice(1, -1)));
const OTHER = ["daily_games.json", "economy_lines.json", "idle_ambient.json", "items.json", "map_data/places.json"];

const chIds = {}, chText = {};
for (let i = 1; i <= 6; i++) {
  const f = `dialogue/chapter${i}.json`;
  chIds[i] = idsIn(f);
  const t = [];
  const walk = o => {
    if (Array.isArray(o)) o.forEach(walk);
    else if (o && typeof o === "object") { if (typeof o.text === "string") t.push(o.text); for (const k in o) walk(o[k]); }
  };
  walk(JSON.parse(rd(f)));
  chText[i] = t.join("\n").toLowerCase().split("\\").join("");
}
const otherIds = new Set(); for (const f of OTHER) for (const x of idsIn(f)) otherIds.add(x);
// Word ids hard-coded in GDScript (idle talk, clock, stall, plaza directions).
const gdWalk = d => { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) gdWalk(p); else if (p.endsWith(".gd")) for (const x of fs.readFileSync(p, "utf8").match(/"w\d+"/g) || []) otherIds.add(x.slice(1, -1)); } };
gdWalk(path.join(D, "..", "scripts"));
const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const rows = [];
for (const w of wb) {
  const tagged = [1, 2, 3, 4, 5, 6].filter(i => chIds[i].has(w.id));
  const re = new RegExp("(^|[^a-zñ'-])" + esc(w.akeanon.toLowerCase()) + "($|[^a-zñ'-])");
  const inText = [1, 2, 3, 4].filter(i => re.test(chText[i]));
  const released = tagged.filter(i => i <= 4);
  let actual;
  if (released.length) actual = "chapter" + released[0];
  else if (otherIds.has(w.id)) actual = "outside_story";
  else if (tagged.length) actual = "unreleased";
  else if (inText.length) actual = "untagged_ch" + inText[0];
  else actual = "unused";
  rows.push({ id: w.id, akeanon: w.akeanon, gloss: w.gloss, area: w.area, verified: !!w.verified, tagged_chapters: tagged, text_chapters: inText, actual });
}
fs.writeFileSync(path.join(OUT, "word_usage.json"), JSON.stringify(rows, null, 1));

const count = k => rows.reduce((m, r) => (m[r[k]] = (m[r[k]] || 0) + 1, m), {});
console.log("BY ACTUAL FIRST USE:", JSON.stringify(count("actual")));
console.log("BY AREA TAG:", JSON.stringify(count("area")));
for (let i = 1; i <= 4; i++) console.log(`ch${i}: distinct words appearing ${[...chIds[i]].length}, introduced here ${rows.filter(r => r.actual === "chapter" + i).length}`);
const allUsed = rows.filter(r => r.tagged_chapters.filter(i => i <= 4).length >= 2).length;
console.log("words used in 2+ released chapters:", allUsed, " in all 4:", rows.filter(r => [1,2,3,4].every(i => chIds[i].has(r.id))).length);
const mism = rows.filter(r => r.area !== r.actual);
console.log("tag != actual:", mism.length);
const untag = rows.filter(r => r.actual.startsWith("untagged"));
console.log("untagged in text:", untag.length, untag.map(r => `${r.akeanon}(${r.area}->ch${r.text_chapters.join(",")})`).join(" "));
const missingTag = rows.filter(r => r.text_chapters.some(i => !r.tagged_chapters.includes(i)) && r.tagged_chapters.length);
console.log("appear in text of a chapter without being tagged there:", missingTag.length);
console.log("verified among used in released story:", rows.filter(r => /^chapter/.test(r.actual) && r.verified).length, "/", rows.filter(r => /^chapter/.test(r.actual)).length);
