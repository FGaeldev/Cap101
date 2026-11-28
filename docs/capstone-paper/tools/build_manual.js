// Builds the AkeanQuest user manual as a .docx that reuses the manuscript's
// package (styles, headers, page setup) with new body content.
// usage: node build_manual.js <manuscriptDir(unzipped)> <outDir> <figuresDir> (labeled figures from annotate.py)
const fs = require("fs"), path = require("path");
const [, , MS, OUT, SHOTS] = process.argv;

fs.rmSync(OUT, { recursive: true, force: true });
fs.cpSync(MS, OUT, { recursive: true });
fs.rmSync(path.join(OUT, "word/media"), { recursive: true, force: true });
fs.mkdirSync(path.join(OUT, "word/media"));

const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const TNR = '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>';
// run: text with **bold** segments
function runs(text, extra = "") {
  return text.split(/(\*\*[^*]+\*\*)/).filter(Boolean).map(seg => {
    const b = seg.startsWith("**");
    const t = b ? seg.slice(2, -2) : seg;
    return `<w:r><w:rPr>${TNR}${b ? "<w:b/><w:bCs/>" : ""}${extra}</w:rPr><w:t xml:space="preserve">${esc(t)}</w:t></w:r>`;
  }).join("");
}
const P = t => `<w:p><w:pPr><w:ind w:firstLine="720"/><w:rPr>${TNR}</w:rPr></w:pPr>${runs(t)}</w:p>`;
const bullet = t => `<w:p><w:pPr><w:ind w:left="1080" w:hanging="360"/><w:rPr>${TNR}</w:rPr></w:pPr>${runs("• " + t)}</w:p>`;
const numbered = (n, t) => `<w:p><w:pPr><w:ind w:left="1080" w:hanging="360"/><w:rPr>${TNR}</w:rPr></w:pPr>${runs(n + ". " + t)}</w:p>`;
const H1 = t => `<w:p><w:pPr><w:pStyle w:val="Heading1"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="0"/></w:numPr><w:rPr>${TNR}</w:rPr></w:pPr>${runs(t)}</w:p>`;
const H2 = t => `<w:p><w:pPr><w:pStyle w:val="Heading2"/><w:keepNext/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="0"/></w:numPr><w:ind w:left="0" w:firstLine="0"/><w:rPr>${TNR}</w:rPr></w:pPr>${runs(t)}</w:p>`;
const center = (t, sz = 24, before = 0) => `<w:p><w:pPr><w:spacing w:before="${before}" w:line="240" w:lineRule="auto"/><w:ind w:firstLine="0"/><w:jc w:val="center"/></w:pPr>${runs("**" + t + "**", `<w:sz w:val="${sz}"/><w:szCs w:val="${sz}"/>`)}</w:p>`;

let tableNo = 0;
function table(title, cols, widths, rows) {
  tableNo++;
  const cap = `<w:p><w:pPr><w:keepNext/><w:spacing w:after="120"/><w:ind w:firstLine="0"/><w:rPr>${TNR}<w:b/><w:bCs/></w:rPr></w:pPr>${runs(`**Table ${tableNo}. ${title}**`)}</w:p>`;
  const cell = (t, w, head) => `<w:tc><w:tcPr><w:tcW w:w="${w}" w:type="dxa"/>${head ? '<w:shd w:val="clear" w:color="auto" w:fill="D9D9D9"/>' : ""}</w:tcPr><w:p><w:pPr><w:spacing w:before="0" w:line="240" w:lineRule="auto"/><w:ind w:firstLine="0"/><w:jc w:val="left"/></w:pPr>${runs(head ? `**${t}**` : t, '<w:sz w:val="22"/><w:szCs w:val="22"/>')}</w:p></w:tc>`;
  const row = (r, head) => `<w:tr><w:trPr><w:cantSplit/>${head ? "<w:tblHeader/>" : ""}<w:jc w:val="center"/></w:trPr>${r.map((t, i) => cell(t, widths[i], head)).join("")}</w:tr>`;
  const b = k => `<w:${k} w:val="single" w:sz="4" w:space="0" w:color="000000"/>`;
  const tbl = `<w:tbl><w:tblPr><w:tblW w:w="${widths.reduce((a, c) => a + c, 0)}" w:type="dxa"/><w:jc w:val="center"/><w:tblBorders>${["top", "left", "bottom", "right", "insideH", "insideV"].map(b).join("")}</w:tblBorders><w:tblLayout w:type="fixed"/><w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr><w:tblGrid>${widths.map(w => `<w:gridCol w:w="${w}"/>`).join("")}</w:tblGrid>${row(cols, true)}${rows.map(r => row(r, false)).join("")}</w:tbl>`;
  // empty spacer paragraph after the table, like the manuscript
  return cap + tbl + `<w:p><w:pPr><w:spacing w:before="0" w:line="240" w:lineRule="auto"/><w:rPr>${TNR}</w:rPr></w:pPr></w:p>`;
}

let figNo = 0, relNo = 100, docPr = 1000;
const rels = [];
function pngSize(f) { const b = fs.readFileSync(f); return [b.readUInt32BE(16), b.readUInt32BE(20)]; }
function figure(file, title) {
  figNo++;
  const src = path.join(SHOTS, file);
  const name = `image${figNo}.png`;
  fs.copyFileSync(src, path.join(OUT, "word/media", name));
  const rid = `rId${relNo++}`;
  rels.push(`<Relationship Id="${rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/${name}"/>`);
  const [w, h] = pngSize(src);
  const cx = 5486400; // 6 in, the text width
  const cy = Math.round(cx * h / w);
  const id = docPr++;
  const pic = `<w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="${cx}" cy="${cy}"/><wp:effectExtent l="0" t="0" r="0" b="0"/><wp:docPr id="${id}" name="Figure ${figNo}"/><wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="${id}" name="${name}"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="${rid}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="${cx}" cy="${cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>`;
  const img = `<w:p><w:pPr><w:keepNext/><w:spacing w:before="240" w:line="240" w:lineRule="auto"/><w:ind w:firstLine="0"/><w:jc w:val="center"/></w:pPr><w:r><w:rPr>${TNR}<w:noProof/></w:rPr>${pic}</w:r></w:p>`;
  const cap = `<w:p><w:pPr><w:spacing w:after="240"/><w:ind w:firstLine="0"/><w:jc w:val="center"/><w:rPr>${TNR}<w:b/><w:bCs/></w:rPr></w:pPr>${runs(`**Figure ${figNo}. **${title}`)}</w:p>`;
  return img + cap;
}

// ---------- content ----------
const body = [];
// Title page (section 1, no page number)
body.push(center("AkeanQuest: An Android-Based 2D Role-Playing Game for Learning", 28, 1200));
body.push(center("Standard Akeanon Vocabulary", 28, 120));
body.push(center("USER MANUAL", 32, 1440));
body.push(center("A Capstone Project by", 24, 1440));
for (const [i, n] of ["John Rey M. Bautista", "Francis Gael R. Gerardo", "Jaycob F. Gumban", "John Loys I. Iquiña", "Christian Glenn O. Jimenez"].entries())
  body.push(center(n, 24, i === 0 ? 600 : 0));
body.push(center("College of Computer Studies", 24, 960));
body.push(center("Aklan State University – Kalibo", 24, 0));
body.push(center("December 2026", 24, 1440));
const hdrs = '<w:headerReference w:type="even" r:id="rId8"/><w:headerReference w:type="default" r:id="rId9"/><w:footerReference w:type="even" r:id="rId10"/><w:footerReference w:type="default" r:id="rId11"/>';
const pg = '<w:pgSz w:w="12240" w:h="15840" w:code="1"/><w:pgMar w:top="2160" w:right="1440" w:bottom="1259" w:left="2160" w:header="720" w:footer="720" w:gutter="0"/>';

// Table of contents (page ii)
body.push(`<w:p><w:pPr><w:pageBreakBefore/><w:spacing w:before="0"/><w:ind w:firstLine="0"/><w:jc w:val="center"/></w:pPr>${runs("**TABLE OF CONTENTS**", '<w:sz w:val="28"/><w:szCs w:val="28"/>')}</w:p>`);
body.push(`<w:p><w:pPr><w:ind w:firstLine="0"/></w:pPr><w:r><w:rPr>${TNR}</w:rPr><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r><w:r><w:rPr>${TNR}</w:rPr><w:instrText xml:space="preserve"> TOC \\o "1-2" \\h \\z \\u </w:instrText></w:r><w:r><w:rPr>${TNR}</w:rPr><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:rPr>${TNR}</w:rPr><w:t>Right-click and choose Update Field to build the table of contents.</w:t></w:r><w:r><w:rPr>${TNR}</w:rPr><w:fldChar w:fldCharType="end"/></w:r></w:p>`);
body.push(`<w:p><w:pPr><w:sectPr>${hdrs}${pg}<w:pgNumType w:fmt="lowerRoman" w:start="1"/><w:cols w:space="720"/><w:titlePg/><w:docGrid w:linePitch="360"/></w:sectPr></w:pPr></w:p>`);

const H3 = t => `<w:p><w:pPr><w:pStyle w:val="Heading3"/><w:keepNext/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="0"/></w:numPr><w:spacing w:before="360"/><w:ind w:left="0" w:firstLine="0"/><w:rPr>${TNR}</w:rPr></w:pPr>${runs(t)}</w:p>`;

body.push(H1("AKEANQUEST USER MANUAL"));
body.push(P("This manual explains how to install and play AkeanQuest, an Android game that teaches the Akeanon language of Aklan, Philippines. The player is a young visitor who flies home to Kalibo with Lola Jonabel and Papa Jobert. The player's cousin Rose teaches Akeanon as the player explores the town, helps people, and plays word games. Each screen below is labeled to show what its parts do."));

body.push(H2("About the Game"));
body.push(P("The story is told in chapters, and each chapter adds new places and new words. Table 1 lists the chapters of the game."));
body.push(table("Chapters of AkeanQuest", ["Chapter", "Title", "What Happens", "Words Learned"], [1080, 1800, 3150, 2610], [
  ["1", "Homesick", "The player flies to Kalibo and meets Lola Susan and Rose.", "Greetings, pronouns, numbers 1 to 5"],
  ["2", "Kalibo Town", "Rose shows the player Pastrana Park, the market, and the cathedral.", "Places, food, numbers 6 to 10, colors, size words"],
  ["3", "Threads of Piña", "Manang Loleng teaches the player piña weaving.", "Action, speed, and size words"],
  ["4", "Roots of Bakhawan", "Manong Ambo shows the player the mangrove eco-park.", "Nature and action words"],
]));

body.push(H2("Installing and Starting the Game"));
body.push(P("To install the game, follow these steps:"));
body.push(numbered(1, "Copy the AkeanQuest APK file to an Android phone."));
body.push(numbered(2, "Tap the file. If the phone asks, allow installing apps from this source."));
body.push(numbered(3, "Tap Install, then open AkeanQuest from the app list."));
body.push(P("The game opens on the main menu, shown in Figure 1."));
body.push(figure("f_main_menu.png", "Main Menu"));
body.push(P("Tapping Start opens the save slots in Figure 2. The game has three slots, so up to three people can play on one phone. The game saves by itself while the player plays."));
body.push(figure("f_save_slots.png", "Choosing a Save Slot"));

body.push(H2("The Game Screen and Controls"));
body.push(P("Figure 3 shows the game screen while walking in Pastrana Park. Table 2 lists the controls for a phone and a keyboard."));
body.push(figure("f_game_screen.png", "Game Screen"));
body.push(table("Controls", ["Action", "On a Phone", "On a Keyboard"], [2400, 4040, 2200], [
  ["Walk", "Hold the arrow pad at the bottom left", "W, A, S, D"],
  ["Talk, look, or pick up", "Walk up, then tap the action button at the bottom right", "E"],
  ["Next line of dialogue", "Tap the screen", "E"],
  ["Open the menu", "Tap the menu button at the top right", "Esc"],
]));
body.push(P("Signs, plaques, and exhibits show a Look button and tell the player about the history and culture of Aklan. A twinkle on the ground is an item the player can pick up for an errand."));

body.push(H2("Talking to People and Learning Words"));
body.push(P("Walking up to a person and tapping the action button opens the talk menu in Figure 4. Sellers such as Nong Pedring also show a Buy choice."));
body.push(figure("f_npc_menu.png", "Talk Menu"));
body.push(P("Akeanon words are colored and underlined in every conversation. Tapping one shows its English meaning, as in Figure 5. Every word the player meets is saved in the Dictionary."));
body.push(figure("f_dialogue.png", "Tapping an Akeanon Word"));
body.push(P("People at home and around town ask the player for help, such as buying items on a shopping list. An accepted errand joins the quest list with a list of what to bring, and every finished errand earns a heart with that person. When a chapter ends, a few goals appear in the quest list: errands for the family and passed Reviews. The next chapter starts the morning after these goals are done."));

body.push(H2("The Menus"));
body.push(P("Tapping the menu button or pressing Esc pauses the game and opens the pause menu in Figure 6. The other screens open from the pause menu or from the buttons on the game screen."));
body.push(figure("f_pause.png", "Pause Menu"));
body.push(H3("Dictionary"));
body.push(figure("f_dictionary.png", "Dictionary"));
body.push(H3("Quests"));
body.push(figure("f_quests.png", "Quests"));
body.push(H3("Map"));
body.push(P("Tapping a place on the map shows the trip details. Walking is free, a tricycle around town costs ₱5, and a jeepney or van to Haboean or Bakhawan costs ₱15. Story trips with Rose or the family are always free."));
body.push(figure("f_map.png", "Map and Travel"));
body.push(H3("Calendar"));
body.push(figure("f_calendar.png", "Calendar"));
body.push(H3("Conversation Log"));
body.push(figure("f_log.png", "Conversation Log"));
body.push(H3("Achievements"));
body.push(figure("f_achievements.png", "Achievements and Collections"));
body.push(H3("Settings"));
body.push(figure("f_settings.png", "Settings"));
body.push(H3("Help"));
body.push(figure("f_help.png", "Help"));

body.push(H2("Mini-Games and Activities"));
body.push(P("Every activity has a ? button that explains how it works. Right answers raise how well the player knows a word, and words the player knows less come up more often. Choosing Review in the talk menu starts a quiz, hangman, or memory match at random (Figures 15 and 16)."));
body.push(figure("g_review.png", "Review Games: Quiz and Hangman"));
body.push(figure("g_match.png", "Memory Match and Phrase Builder"));
body.push(P("Some activities belong to a chapter's story, while others can be played once a day around town (Figures 17 to 19)."));
body.push(figure("g_chapter.png", "Chapter Activities: Habi-Habi and Fishing"));
body.push(figure("g_paper.png", "Daily Newspaper Puzzles"));
body.push(figure("g_town.png", "Town Activities: Stall and Directions"));

body.push(H2("Places to Explore"));
body.push(P("New places open as the story moves on. Figures 20 to 22 show the places the player can visit."));
body.push(figure("g_places1.png", "Pastrana Park and Kalibo Cathedral"));
body.push(figure("g_places2.png", "Market and Haboean Gallery"));
body.push(figure("g_places3.png", "Bakhawan Eco-Park and the Newspaper at Home"));

body.push(H2("Days, Money, and Saving"));
body.push(P("Sleeping in a bed starts a new day. Each day brings a new Word of the Day, a new newspaper puzzle, one stall shift, and one round of directions. The player earns pesos (₱) in the following ways:"));
body.push(bullet("₱5 for each story quiz or activity passed, or ₱2 for one not passed."));
body.push(bullet("₱3 for a passed Review and ₱1 for trying, up to ₱15 a day."));
body.push(bullet("A thank-you payment for errands, and ₱10 for the newspaper puzzle."));
body.push(bullet("₱10 from Lola each morning when the player has less than ₱20."));
body.push(P("The player never loses pesos for a wrong answer. To stop playing, open the pause menu and choose Exit to menu. To play again later, choose Continue on the main menu."));

body.push(H2("Tips"));
body.push(bullet("**Not sure what to do next?** Read the quest at the top left, or tap it to see all quests."));
body.push(bullet("**Do not know a word?** Tap it in the dialogue, or search for it in the Dictionary."));
body.push(bullet("**Text too small?** Raise the UI scale in Settings."));
body.push(bullet("**Hard to tell colors apart?** Turn on Color Blind Mode in Settings."));
body.push(bullet("**Need help with an activity?** Tap its ? button, or open Help."));

const finalSect = `<w:sectPr>${hdrs}${pg}<w:pgNumType w:start="1"/><w:cols w:space="720"/><w:docGrid w:linePitch="360"/></w:sectPr>`;

// keep the manuscript's root element (namespaces)
const msDoc = fs.readFileSync(path.join(MS, "word/document.xml"), "utf8");
const root = msDoc.match(/<w:document[^>]*>/)[0];
const xml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n${root}<w:body>${body.join("")}${finalSect}</w:body></w:document>`;
fs.writeFileSync(path.join(OUT, "word/document.xml"), xml);

// relationships: keep everything except old images and hyperlinks
let r = fs.readFileSync(path.join(MS, "word/_rels/document.xml.rels"), "utf8");
r = r.replace(/<Relationship [^>]*\/(image|hyperlink)"[^>]*\/>/g, "");
r = r.replace("</Relationships>", rels.join("") + "</Relationships>");
fs.writeFileSync(path.join(OUT, "word/_rels/document.xml.rels"), r);

// fresh title in core props
const core = path.join(OUT, "docProps/core.xml");
fs.writeFileSync(core, fs.readFileSync(core, "utf8").replace(/<dc:title>[^<]*<\/dc:title>/, "<dc:title>AkeanQuest User Manual</dc:title>"));
console.log("tables", tableNo, "figures", figNo);
