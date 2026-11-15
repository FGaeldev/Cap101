// Prints a chapter's dialogue: every scene, line index, speaker, text, translation,
// choices (label -> next, rapport), word ids and flag keys.
// Usage (from the project root): node .claude/skills/chapter-prep/scripts/print_chapter.js <N>
const fs = require("fs");
const path = require("path");

const n = process.argv[2];
if (!n) {
	console.error("usage: print_chapter.js <chapter number>");
	process.exit(1);
}
const file = path.join("data", "dialogue", `chapter${n}.json`);
if (!fs.existsSync(file)) {
	console.error(`no ${file}`);
	process.exit(1);
}
const data = JSON.parse(fs.readFileSync(file, "utf8"));
const FLAG_KEYS = ["set_flag", "set_flag_on_enter", "check_flag", "check_flag_next", "requires_flag", "minigame_type", "challenge_id"];

for (const [scene, value] of Object.entries(data)) {
	const lines = Array.isArray(value) ? value : value && value.lines;
	if (!Array.isArray(lines)) continue;
	console.log(`\n== ${scene} (${lines.length} lines)`);
	lines.forEach((l, i) => {
		if (typeof l === "string") {
			console.log(`${i} ${l}`);
			return;
		}
		if (l.type === "start_router") {
			console.log(`${i} [router] ${JSON.stringify(l.start_index_if_flag || {})}`);
			return;
		}
		const kind = l.type && l.type !== "dialogue" ? `[${l.type}] ` : "";
		console.log(`${i} ${kind}${l.speaker || "(narration)"}: ${l.text || ""}`);
		if (l.translation) console.log(`    T: ${l.translation}`);
		if (l.word_ids && l.word_ids.length) console.log(`    ids: ${l.word_ids.join(", ")}`);
		const extras = FLAG_KEYS.filter((k) => l[k] !== undefined).map((k) => `${k}=${JSON.stringify(l[k])}`);
		if (extras.length) console.log(`    ${extras.join("  ")}`);
		for (const c of l.choices || []) {
			const rap = c.rapport_delta !== undefined ? ` (${c.rapport_delta > 0 ? "+" : ""}${c.rapport_delta})` : " (no rapport)";
			console.log(`    > ${c.label || c.text} -> ${c.next}${rap}`);
		}
		if (l.next !== undefined && !l.choices) console.log(`    next=${l.next}`);
	});
}
