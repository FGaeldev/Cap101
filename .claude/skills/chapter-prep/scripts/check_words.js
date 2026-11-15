// Checks each word of one or more Akeanon lines against data/word_bank.json.
// For every word: the bank entry (id, gloss, verified) or "missing", plus entries
// that share its root (so "ubrahon" shows "ubra").
// Usage (from the project root):
//   node .claude/skills/chapter-prep/scripts/check_words.js "Hinayi eang. Bukon ra padasigan." ["another line" ...]
const fs = require("fs");

const lines = process.argv.slice(2);
if (!lines.length) {
	console.error('usage: check_words.js "<line>" ["<line>" ...]');
	process.exit(1);
}
const raw = JSON.parse(fs.readFileSync("data/word_bank.json", "utf8"));
const words = Array.isArray(raw) ? raw : raw.words || Object.values(raw);

const norm = (s) =>
	String(s).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/\\/g, "").trim();

// Exact forms: "katamnan/taeamnan" and "a, b" give several forms per entry.
const exact = new Map();
for (const w of words) {
	for (const form of String(w.akeanon).split(/[\/,]/)) {
		const f = norm(form).replace(/\s*\(\?\)\s*$/, "");
		if (f) exact.set(f, w);
	}
}
const show = (w) => `${w.id} ${w.akeanon} = ${w.gloss}${w.verified ? "" : " [unverified]"}`;

// Root guess: strip common affixes, then find entries containing the remainder.
const PREFIXES = ["nagaka", "naga", "nag", "mag", "gin", "pag", "pa", "ma", "na", "ka", "ga"];
const SUFFIXES = ["hon", "han", "on", "an", "i"];
function roots(word) {
	const out = new Set();
	let stems = [word, word.replace(/-/g, "")];
	for (const p of PREFIXES) if (word.startsWith(p) && word.length - p.length >= 3) stems.push(word.slice(p.length).replace(/^-/, ""));
	for (const s of [...stems]) for (const x of SUFFIXES) if (s.endsWith(x) && s.length - x.length >= 3) stems.push(s.slice(0, -x.length));
	if (word.includes("-")) stems.push(word.split("-")[0]); // hinay-hinay -> hinay
	for (const s of stems) if (s.length >= 3) out.add(s);
	return [...out];
}

for (const line of lines) {
	console.log(`\n"${line}"`);
	const tokens = [...new Set(line.split(/[\s.,!?;:"“”()—–]+/).map(norm).filter(Boolean))];
	for (const t of tokens) {
		const hit = exact.get(t);
		if (hit) {
			console.log(`  ${t.padEnd(14)} IN    ${show(hit)}`);
			continue;
		}
		const related = new Map();
		for (const r of roots(t)) {
			for (const w of words) {
				if (norm(w.akeanon).split(/[\s\/,]/).some((f) => f === r || (r.length >= 4 && f.includes(r)))) related.set(w.id, w);
			}
		}
		const rel = [...related.values()].slice(0, 4).map(show).join("; ");
		console.log(`  ${t.padEnd(14)} MISSING${rel ? `  (related: ${rel})` : ""}`);
	}
}
