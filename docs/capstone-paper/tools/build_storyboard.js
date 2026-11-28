// Builds the AkeanQuest storyboard (Chapters 1-4) as a .docx that reuses the
// manuscript's package (styles, headers, page setup), like build_manual.js.
// Content comes from the Claude Doc's markdown export.
// usage: node build_storyboard.js <manuscriptDir(unzipped)> <outDir> <storyboard.md>
const fs = require("fs"), path = require("path");
const [, , MS, OUT, MD] = process.argv;

fs.rmSync(OUT, { recursive: true, force: true });
fs.cpSync(MS, OUT, { recursive: true });
fs.rmSync(path.join(OUT, "word/media"), { recursive: true, force: true });

const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const TNR = '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>';

// inline markdown -> runs: **bold**, *italic*, `code` (set as plain text), \* escapes
function runs(text, extra = "") {
  text = text.replace(/\\([*_`\[\]()#|\\-])/g, "$1");
  const out = [];
  let b = false, i = false, buf = "";
  const flush = () => {
    if (!buf) return;
    out.push(`<w:r><w:rPr>${TNR}${b ? "<w:b/><w:bCs/>" : ""}${i ? "<w:i/><w:iCs/>" : ""}${extra}</w:rPr><w:t xml:space="preserve">${esc(buf)}</w:t></w:r>`);
    buf = "";
  };
  for (let k = 0; k < text.length; k++) {
    if (text.startsWith("**", k)) { flush(); b = !b; k++; continue; }
    if (text[k] === "*" ) { flush(); i = !i; continue; }
    if (text[k] === "`") continue;
    buf += text[k];
  }
  flush();
  return out.join("");
}
const P = t => `<w:p><w:pPr><w:ind w:firstLine="720"/><w:rPr>${TNR}</w:rPr></w:pPr>${runs(t)}</w:p>`;
const Pflush = t => `<w:p><w:pPr><w:keepNext/><w:ind w:firstLine="0"/><w:rPr>${TNR}</w:rPr></w:pPr>${runs(t)}</w:p>`;
const item = (mark, t) => `<w:p><w:pPr><w:ind w:left="1080" w:hanging="360"/><w:rPr>${TNR}</w:rPr></w:pPr>${runs(mark + " " + t)}</w:p>`;
const H1 = t => `<w:p><w:pPr><w:pStyle w:val="Heading1"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="0"/></w:numPr><w:rPr>${TNR}</w:rPr></w:pPr>${runs(t)}</w:p>`;
const H2 = (t, brk) => `<w:p><w:pPr><w:pStyle w:val="Heading2"/><w:keepNext/>${brk ? "<w:pageBreakBefore/>" : ""}<w:numPr><w:ilvl w:val="0"/><w:numId w:val="0"/></w:numPr><w:ind w:left="0" w:firstLine="0"/><w:rPr>${TNR}</w:rPr></w:pPr>${runs(t)}</w:p>`;
const H3 = t => `<w:p><w:pPr><w:pStyle w:val="Heading3"/><w:keepNext/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="0"/></w:numPr><w:spacing w:before="360"/><w:ind w:left="0" w:firstLine="0"/><w:rPr>${TNR}</w:rPr></w:pPr>${runs(t)}</w:p>`;
const center = (t, sz = 24, before = 0) => `<w:p><w:pPr><w:spacing w:before="${before}" w:line="240" w:lineRule="auto"/><w:ind w:firstLine="0"/><w:jc w:val="center"/></w:pPr>${runs("**" + t + "**", `<w:sz w:val="${sz}"/><w:szCs w:val="${sz}"/>`)}</w:p>`;

let tableNo = 0;
function table(title, cols, widths, rows) {
  tableNo++;
  const cap = `<w:p><w:pPr><w:keepNext/><w:spacing w:after="120"/><w:ind w:firstLine="0"/><w:rPr>${TNR}<w:b/><w:bCs/></w:rPr></w:pPr>${runs(`**Table ${tableNo}. ${title}**`)}</w:p>`;
  const cell = (t, w, head) => `<w:tc><w:tcPr><w:tcW w:w="${w}" w:type="dxa"/>${head ? '<w:shd w:val="clear" w:color="auto" w:fill="D9D9D9"/>' : ""}</w:tcPr><w:p><w:pPr><w:spacing w:before="0" w:line="240" w:lineRule="auto"/><w:ind w:firstLine="0"/><w:jc w:val="left"/></w:pPr>${runs(head ? `**${t}**` : t, '<w:sz w:val="20"/><w:szCs w:val="20"/>')}</w:p></w:tc>`;
  const row = (r, head) => `<w:tr><w:trPr><w:cantSplit/>${head ? "<w:tblHeader/>" : ""}<w:jc w:val="center"/></w:trPr>${r.map((t, i) => cell(t ?? "", widths[i], head)).join("")}</w:tr>`;
  const b = k => `<w:${k} w:val="single" w:sz="4" w:space="0" w:color="000000"/>`;
  const tbl = `<w:tbl><w:tblPr><w:tblW w:w="${widths.reduce((a, c) => a + c, 0)}" w:type="dxa"/><w:jc w:val="center"/><w:tblBorders>${["top", "left", "bottom", "right", "insideH", "insideV"].map(b).join("")}</w:tblBorders><w:tblLayout w:type="fixed"/><w:tblCellMar><w:left w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/></w:tblCellMar><w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr><w:tblGrid>${widths.map(w => `<w:gridCol w:w="${w}"/>`).join("")}</w:tblGrid>${row(cols, true)}${rows.map(r => row(r, false)).join("")}</w:tbl>`;
  return cap + tbl + `<w:p><w:pPr><w:spacing w:before="0" w:line="240" w:lineRule="auto"/><w:rPr>${TNR}</w:rPr></w:pPr></w:p>`;
}
// column widths by table shape (text width = 8640 dxa)
function widthsFor(cols) {
  const h = cols.join("|");
  if (h.startsWith("#|Picture")) return [700, 3500, 4440];
  if (h.startsWith("Who|")) return [1500, 3240, 1100, 2800];
  if (h.startsWith("Location|")) return [3240, 3800, 1600];
  const w = Math.floor(8640 / cols.length);
  return cols.map((_, i) => (i === cols.length - 1 ? 8640 - w * (cols.length - 1) : w));
}
const splitRow = l => l.trim().replace(/^\|/, "").replace(/\|$/, "").split(/(?<!\\)\|/).map(c => c.trim());

// ---------- title page + TOC (as in the user manual) ----------
const body = [];
body.push(center("AkeanQuest: An Android-Based 2D Role-Playing Game for Learning", 28, 1200));
body.push(center("Standard Akeanon Vocabulary", 28, 120));
body.push(center("STORYBOARD", 32, 1440));
body.push(center("Chapters 1 to 4", 24, 240));
body.push(center("A Capstone Project by", 24, 1440));
for (const [i, n] of ["John Rey M. Bautista", "Francis Gael R. Gerardo", "Jaycob F. Gumban", "John Loys I. Iquiña", "Christian Glenn O. Jimenez"].entries())
  body.push(center(n, 24, i === 0 ? 600 : 0));
body.push(center("College of Computer Studies", 24, 960));
body.push(center("Aklan State University – Kalibo", 24, 0));
body.push(center("December 2026", 24, 1440));
const hdrs = '<w:headerReference w:type="even" r:id="rId8"/><w:headerReference w:type="default" r:id="rId9"/><w:footerReference w:type="even" r:id="rId10"/><w:footerReference w:type="default" r:id="rId11"/>';
const pg = '<w:pgSz w:w="12240" w:h="15840" w:code="1"/><w:pgMar w:top="2160" w:right="1440" w:bottom="1259" w:left="2160" w:header="720" w:footer="720" w:gutter="0"/>';
body.push(`<w:p><w:pPr><w:pageBreakBefore/><w:spacing w:before="0"/><w:ind w:firstLine="0"/><w:jc w:val="center"/></w:pPr>${runs("**TABLE OF CONTENTS**", '<w:sz w:val="28"/><w:szCs w:val="28"/>')}</w:p>`);
body.push(`<w:p><w:pPr><w:ind w:firstLine="0"/></w:pPr><w:r><w:rPr>${TNR}</w:rPr><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r><w:r><w:rPr>${TNR}</w:rPr><w:instrText xml:space="preserve"> TOC \\o "1-3" \\h \\z \\u </w:instrText></w:r><w:r><w:rPr>${TNR}</w:rPr><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:rPr>${TNR}</w:rPr><w:t>Right-click and choose Update Field to build the table of contents.</w:t></w:r><w:r><w:rPr>${TNR}</w:rPr><w:fldChar w:fldCharType="end"/></w:r></w:p>`);
body.push(`<w:p><w:pPr><w:sectPr>${hdrs}${pg}<w:pgNumType w:fmt="lowerRoman" w:start="1"/><w:cols w:space="720"/><w:titlePg/><w:docGrid w:linePitch="360"/></w:sectPr></w:pPr></w:p>`);

// ---------- body from markdown ----------
const lines = fs.readFileSync(MD, "utf8").replace(/\r/g, "").split("\n");
let chapter = "", scene = "", firstH2 = true;
for (let k = 0; k < lines.length; k++) {
  const l = lines[k];
  if (!l.trim()) continue;
  if (l.startsWith("# ")) { body.push(H1("AKEANQUEST STORYBOARD")); k++; continue; } // skip the doc's byline
  if (/^\d{1,2}\/|^[A-Z][a-z]{2} \d{1,2}, \d{4} ·/.test(l)) continue;
  if (l.startsWith("## ")) { chapter = l.slice(3); scene = ""; body.push(H2(chapter, !firstH2)); firstH2 = false; continue; }
  if (l.startsWith("### ")) { scene = l.slice(4); body.push(H3(scene)); continue; }
  if (l.startsWith("|")) {
    const tl = [];
    while (k < lines.length && lines[k].startsWith("|")) tl.push(lines[k++]);
    k--;
    const cols = splitRow(tl[0]);
    const rows = tl.slice(2).map(splitRow);
    const chNo = (chapter.match(/Chapter (\d)/) || [])[1];
    const title = scene ? `Chapter ${chNo}, ${scene.replace(/ — /, ": ")}`
      : cols[0] === "Who" ? "Cast" : cols[0] === "Location" ? "Locations" : chapter;
    body.push(table(title, cols, widthsFor(cols), rows));
    continue;
  }
  let m;
  if ((m = l.match(/^\s*(\d+)\. (.*)/))) { body.push(item(m[1] + ".", m[2])); continue; }
  if ((m = l.match(/^\s*[-*] (.*)/))) { body.push(item("•", m[1])); continue; }
  // a short bold lead-in line ("**Notation:**") introduces a list: keep it with the next line
  if (/^\*\*[^*]+:\*\*$/.test(l.trim())) { body.push(Pflush(l.trim())); continue; }
  // scene header line (file and flag names): left-aligned so long names don't stretch the line
  if (l.startsWith("**Where:**")) { body.push(`<w:p><w:pPr><w:keepNext/><w:ind w:firstLine="0"/><w:jc w:val="left"/><w:rPr>${TNR}</w:rPr></w:pPr>${runs(l.trim())}</w:p>`); continue; }
  body.push(P(l.trim()));
}

const finalSect = `<w:sectPr>${hdrs}${pg}<w:pgNumType w:start="1"/><w:cols w:space="720"/><w:docGrid w:linePitch="360"/></w:sectPr>`;
const msDoc = fs.readFileSync(path.join(MS, "word/document.xml"), "utf8");
const root = msDoc.match(/<w:document[^>]*>/)[0];
fs.writeFileSync(path.join(OUT, "word/document.xml"),
  `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n${root}<w:body>${body.join("")}${finalSect}</w:body></w:document>`);

// relationships: keep everything except old images and hyperlinks
let r = fs.readFileSync(path.join(MS, "word/_rels/document.xml.rels"), "utf8");
r = r.replace(/<Relationship [^>]*\/(image|hyperlink)"[^>]*\/>/g, "");
fs.writeFileSync(path.join(OUT, "word/_rels/document.xml.rels"), r);
const core = path.join(OUT, "docProps/core.xml");
fs.writeFileSync(core, fs.readFileSync(core, "utf8").replace(/<dc:title>[^<]*<\/dc:title>/, "<dc:title>AkeanQuest Storyboard</dc:title>"));
console.log("tables", tableNo);
