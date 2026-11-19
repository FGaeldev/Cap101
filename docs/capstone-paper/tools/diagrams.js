// Generates capstone diagrams as standalone HTML (one SVG each) for headless rendering.
const fs = require('fs');
const OUT = process.argv[2];
fs.mkdirSync(OUT, { recursive: true });
const F = "font-family:'Times New Roman',Times,serif";
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function text(x, y, s, o = {}) {
  const lines = String(s).split('\n'); const size = o.size || 26; const lh = o.lh || size * 1.22;
  const y0 = y - ((lines.length - 1) * lh) / 2;
  return lines.map((l, i) => `<text x="${x}" y="${y0 + i * lh}" font-size="${size}" text-anchor="${o.anchor || 'middle'}" dominant-baseline="central" ${o.bold ? 'font-weight="bold"' : ''} ${o.italic ? 'font-style="italic"' : ''} fill="${o.fill || '#000'}">${esc(l)}</text>`).join('');
}
function box(x, y, w, h, s, o = {}) {
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${o.rx == null ? 10 : o.rx}" fill="${o.fill || '#fff'}" stroke="#000" stroke-width="${o.sw || 2.5}" ${o.dash ? 'stroke-dasharray="10 7"' : ''}/>` + (s ? text(x + w / 2, y + h / 2, s, o) : '');
}
function line(pts, o = {}) {
  const d = pts.map((p, i) => (i ? 'L' : 'M') + p[0] + ' ' + p[1]).join(' ');
  return `<path d="${d}" fill="none" stroke="#000" stroke-width="${o.sw || 2.5}" ${o.dash ? 'stroke-dasharray="10 7"' : ''} ${o.head === false ? '' : 'marker-end="url(#ah)"'}/>`;
}
const defs = `<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="9" markerHeight="9" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="#000"/></marker><marker id="ao" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="10" markerHeight="10" orient="auto"><path d="M0 0 L10 5 L0 10" fill="none" stroke="#000" stroke-width="1.5"/></marker></defs>`;
function page(name, w, h, body) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" style="${F}"><rect width="${w}" height="${h}" fill="#fff"/>${defs}${body}</svg>`;
  fs.writeFileSync(`${OUT}/${name}.svg`, svg);
  fs.writeFileSync(`${OUT}/${name}.html`, `<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;background:#fff;overflow:hidden}</style></head><body>${svg}</body></html>`);
  return { name, w, h };
}
const made = [];

// ---------- Figure 1: IPO conceptual framework ----------
{
  const W = 1600, H = 1000; let b = '';
  const cols = [
    ['INPUT', ['Akeanon word bank', 'NPC dialogue scripts,\nquests, and cutscenes', 'Cultural content of Aklan\n(places, folklore, traditions)', 'Sprites, tilesets,\nand audio assets', 'Player actions: movement,\ndialogue choices, answers']],
    ['PROCESS', ['Quest and chapter system', 'NPC dialogue system\nwith tappable Akeanon words', 'Quizzes and mini-games', 'Progress tracking:\ndictionary, word mastery,\nsave slots']],
    ['OUTPUT', ['AkeanQuest:\nAn Android-Based 2D\nRole-Playing Game\nfor Learning Standard\nAkeanon Vocabulary']],
  ];
  const cw = 440, gap = 90, x0 = (W - (3 * cw + 2 * gap)) / 2, top = 40, ch = 800, hh = 100;
  cols.forEach(([title, items], i) => {
    const x = x0 + i * (cw + gap);
    b += `<rect x="${x}" y="${top}" width="${cw}" height="${ch}" rx="22" fill="#fff" stroke="#000" stroke-width="4"/>`;
    b += `<path d="M${x} ${top + hh} V${top + 22} Q${x} ${top} ${x + 22} ${top} H${x + cw - 22} Q${x + cw} ${top} ${x + cw} ${top + 22} V${top + hh} Z" fill="#000"/>`;
    b += text(x + cw / 2, top + hh / 2, title, { size: 46, bold: true, fill: '#fff' });
    if (i === 1) b += text(x + cw / 2, top + hh + 45, 'Godot 4 engine (GDScript)', { size: 27, italic: true });
    const startY = top + hh + (i === 1 ? 80 : 20), avail = ch - (startY - top) - 20, seg = avail / items.length;
    items.forEach((it, k) => {
      b += text(x + cw / 2, startY + seg * k + seg / 2, it, { size: i === 2 ? 36 : 29, bold: i === 2 });
      if (k < items.length - 1) b += `<line x1="${x + 35}" x2="${x + cw - 35}" y1="${startY + seg * (k + 1)}" y2="${startY + seg * (k + 1)}" stroke="#000" stroke-width="2"/>`;
    });
    if (i < 2) { const ax = x + cw + 15, ay = top + ch / 2; b += `<path d="M${ax} ${ay - 18} H${ax + 32} V${ay - 36} L${ax + 62} ${ay} L${ax + 32} ${ay + 36} V${ay + 18} H${ax} Z" fill="#000"/>`; }
  });
  // feedback loop
  const fy = top + ch + 75, xin = x0 + cw / 2, xout = x0 + 2 * (cw + gap) + cw / 2;
  b += line([[xout, top + ch], [xout, fy], [xin, fy], [xin, top + ch + 4]], { dash: true });
  b += `<rect x="${(xin + xout) / 2 - 300}" y="${fy - 22}" width="600" height="44" fill="#fff"/>`;
  b += text((xin + xout) / 2, fy, 'Feedback from playtesting and evaluation', { size: 28, italic: true });
  made.push(page('fig1_ipo', W, H, b));
}

// ---------- Figure 2: Agile iterative development ----------
{
  const W = 1600, H = 760; let b = '';
  const y = 330, bh = 150;
  b += box(40, y - bh / 2, 250, bh, 'Phase 1\nRequirements\nGathering', { size: 28 });
  b += box(1310, y - bh / 2, 250, bh, 'Phase 5\nEvaluation\n(ISO/IEC 25010)', { size: 28 });
  // sprint loop container
  b += box(370, 70, 860, 540, '', { dash: true, rx: 26, sw: 2.5 });
  b += text(800, 112, 'Repeated every sprint (one chapter or system per release)', { size: 27, italic: true });
  const cx = 800, cy = 360, R = 165;
  const nodes = [['Phase 2\nSystem Design', -90], ['Phase 3\nDevelopment', 30], ['Phase 4\nTesting', 150]];
  const pos = nodes.map(([, a]) => [cx + R * 1.45 * Math.cos(a * Math.PI / 180), cy + R * Math.sin(a * Math.PI / 180)]);
  nodes.forEach(([t], i) => { b += box(pos[i][0] - 140, pos[i][1] - 60, 280, 120, t, { size: 28, rx: 60 }); });
  // cycle arrows
  b += line([[pos[0][0] + 140, pos[0][1]], [pos[1][0] + 40, pos[0][1]], [pos[1][0] + 40, pos[1][1] - 62]]);
  b += line([[pos[1][0] - 142, pos[1][1] + 30], [pos[2][0] + 142, pos[2][1] + 30]]);
  b += line([[pos[2][0] - 40, pos[2][1] - 62], [pos[2][0] - 40, pos[0][1]], [pos[0][0] - 142, pos[0][1]]]);
  b += text(pos[2][0] - 25, 335, 'playtest feedback\nand bug fixes', { size: 24, italic: true, anchor: 'start' });
  // in and out
  b += line([[290, y], [368, y]]);
  b += line([[1232, y], [1308, y]]);
  // release strip
  b += box(370, 650, 860, 70, 'Releases: v0.1 → v0.3.0-alpha → v0.4.0-alpha (Chapters 1–4) → v1.0.0', { size: 26, rx: 8 });
  b += line([[800, 612], [800, 648]]);
  made.push(page('fig2_agile', W, H, b));
}

// ---------- Figure 3: System architecture ----------
{
  const W = 1600, H = 1240; let b = '';
  const L = 60, R = 1540, IW = R - L;
  const layer = (y, h, title, items, cols) => {
    let s = box(L, y, IW, h, '', { rx: 14, sw: 3 });
    s += `<rect x="${L}" y="${y}" width="${IW}" height="46" rx="14" fill="#000"/><rect x="${L}" y="${y + 30}" width="${IW}" height="16" fill="#000"/>`;
    s += text(L + IW / 2, y + 23, title, { size: 28, bold: true, fill: '#fff' });
    const rows = Math.ceil(items.length / cols), gx = 22, gy = 18;
    const cw = (IW - gx * (cols + 1)) / cols, rh = (h - 46 - gy * (rows + 1)) / rows;
    items.forEach((t, i) => { const r = Math.floor(i / cols), c = i % cols; s += box(L + gx + c * (cw + gx), y + 46 + gy + r * (rh + gy), cw, rh, t, { size: 24, rx: 8, sw: 2 }); });
    return s;
  };
  b += box(560, 20, 480, 90, 'Player\n(Android smartphone: touch screen)', { size: 26, rx: 45 });
  b += line([[760, 110], [760, 160]]); b += line([[840, 160], [840, 112]]);
  b += text(700, 135, 'touch input', { size: 22, italic: true, anchor: 'end' }); b += text(900, 135, 'screen and sound', { size: 22, italic: true, anchor: 'start' });
  b += layer(162, 290, 'PRESENTATION LAYER (Godot scenes and UI)', ['Main menu and\nsave slot picker', 'World scenes:\nplayer, NPCs, objects', 'Dialogue box and\nword meaning pop-up', 'Pause menu and panels:\ndictionary, quests, map,\ncalendar, settings', 'Mini-game panels', 'HUD, settings,\nD-pad or joystick'], 3);
  b += line([[800, 452], [800, 498]]); b += line([[860, 498], [860, 454]]);
  b += layer(500, 330, 'GAME LOGIC LAYER (GDScript autoload managers)', ['GameState\n(game state, saving)', 'ChapterLoader and\nCutsceneManager', 'DialogueUI', 'QuestManager and\nTaskManager', 'WordBank', 'ChallengeManager\n(word mastery)', 'Economy\n(market, coins)', 'DayNightManager\nand NpcSchedule', 'AudioManager', 'Accessibility\nand UIScale'], 5);
  b += line([[800, 830], [800, 876]]); b += line([[860, 876], [860, 832]]);
  b += layer(878, 220, 'DATA LAYER', ['Game content (JSON): word bank,\ndialogue, quests, cutscenes,\nchapters, culture spots', 'Assets: sprites, tilesets,\nportraits, music,\nsound effects', 'Local device storage:\nthree save slots with backup,\nsettings file'], 3);
  b += box(L, 1130, IW, 80, '', { rx: 10, fill: '#e6e6e6' }) + text(L + IW / 2, 1170, 'Godot Engine 4.7 (GL Compatibility renderer)  ·  Android, 64-bit (arm64-v8a)  ·  offline, no server', { size: 27, bold: true });
  made.push(page('fig3_architecture', W, H, b));
}

// ---------- Figure 4: Use case diagram ----------
{
  const W = 1600, H = 1400; let b = '';
  const actor = (x, y, name) => `<circle cx="${x}" cy="${y - 70}" r="26" fill="#fff" stroke="#000" stroke-width="3"/><line x1="${x}" y1="${y - 44}" x2="${x}" y2="${y + 30}" stroke="#000" stroke-width="3"/><line x1="${x - 45}" y1="${y - 15}" x2="${x + 45}" y2="${y - 15}" stroke="#000" stroke-width="3"/><line x1="${x}" y1="${y + 30}" x2="${x - 35}" y2="${y + 95}" stroke="#000" stroke-width="3"/><line x1="${x}" y1="${y + 30}" x2="${x + 35}" y2="${y + 95}" stroke="#000" stroke-width="3"/>` + text(x, y + 130, name, { size: 30, bold: true });
  b += box(260, 30, 1080, 1340, '', { rx: 4, sw: 3 });
  b += text(800, 72, 'AkeanQuest', { size: 34, bold: true });
  const ell = (cx, cy, t, rx = 230) => `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="44" fill="#fff" stroke="#000" stroke-width="2.5"/>` + text(cx, cy, t, { size: 23 });
  const P = [['Start or continue a game\n(choose save slot)'], ['Enter player name'], ['Explore Aklan locations'], ['Talk to NPCs'], ['Answer quizzes and\nbuild phrases'], ['View word meanings'], ['Play mini-games'], ['Pay at the market'], ['Open the menus (dictionary,\nquests, map, calendar)'], ['Solve the daily\nnewspaper puzzle'], ['Change settings']];
  const px = 600, ax = 130, ay = 700;
  const py = i => 140 + i * 113;
  P.forEach(([t], i) => { b += line([[ax + 50, ay - 20], [px - 230, py(i)]], { head: false, sw: 2 }); });
  P.forEach(([t], i) => { b += ell(px, py(i), t); });
  b += actor(ax, ay, 'Player');
  // extend/include relations (to the right of the column)
  const rel = (from, to, label) => {
    const x1 = px + 230, xm = px + 300;
    b += `<path d="M${x1} ${py(from)} H${xm} V${py(to)} H${x1 + 4}" fill="none" stroke="#000" stroke-width="2" stroke-dasharray="9 6" marker-end="url(#ao)"/>`;
    b += text(xm + 8, (py(from) + py(to)) / 2, label, { size: 21, italic: true, anchor: 'start' });
  };
  rel(4, 3, '«extend»'); rel(6, 3, '«extend»'); rel(1, 0, '«include»');
  // developer side
  const dx = 1470, dy = 1085, ux = 1115;
  const D = ['Manage the word bank\n(editor plug-in)', 'Write dialogue, quests,\nand cutscenes (JSON)', 'Run playtests and\ndata checks', 'Build and release\nthe Android app'];
  const dyy = i => 890 + i * 130;
  D.forEach((t, i) => { b += line([[dx - 50, dy - 20], [ux + 200, dyy(i)]], { head: false, sw: 2 }); });
  D.forEach((t, i) => { b += ell(ux, dyy(i), t, 200); });
  b += actor(dx, dy, 'Developer');
  // view word meanings extends talk... placed: 5 → 3 extends (tapping is optional)
  rel(5, 3, '«extend»');
  made.push(page('fig4_usecase', W, H, b));
}

// ---------- Figure 5: Context diagram ----------
{
  const W = 1600, H = 820; let b = '';
  b += box(40, 330, 260, 130, 'Player', { size: 34, bold: true, rx: 0, sw: 3 });
  b += box(1300, 330, 260, 130, 'Developer', { size: 34, bold: true, rx: 0, sw: 3 });
  b += `<circle cx="800" cy="395" r="190" fill="#fff" stroke="#000" stroke-width="3.5"/>` + text(800, 340, '0', { size: 34, bold: true }) + `<line x1="640" x2="960" y1="370" y2="370" stroke="#000" stroke-width="2"/>` + text(800, 435, 'AkeanQuest\nGame System', { size: 34, bold: true });
  const flow = (pts, label, lx, ly, anchor = 'middle') => { b += line(pts); b += text(lx, ly, label, { size: 23, anchor }); };
  flow([[300, 350], [612, 330]], 'Movement and interaction commands,\ndialogue choices, answers, settings', 455, 270);
  flow([[620, 460], [300, 440]], 'Akeanon dialogue and word meanings,\nmini-games and feedback, quest progress,\ndictionary, map, calendar', 455, 540);
  flow([[1300, 350], [988, 330]], 'Word bank entries, dialogue scripts,\nquests, cutscenes, sprites and audio', 1145, 270);
  flow([[980, 460], [1300, 440]], 'Playtest reports and\ndata check results,\nAndroid build (APK)', 1145, 540);
  made.push(page('fig5_context', W, H, b));
}

// ---------- Figure 6: Game flowchart ----------
{
  const W = 1500, H = 2470; let b = '';
  const cx = 820;
  const term = (x, y, t) => `<rect x="${x - 150}" y="${y - 40}" width="300" height="80" rx="40" fill="#fff" stroke="#000" stroke-width="2.5"/>` + text(x, y, t, { size: 27, bold: true });
  const proc = (x, y, t, w = 400, h = 90) => box(x - w / 2, y - h / 2, w, h, t, { size: 25, rx: 0 });
  const io = (x, y, t, w = 400, h = 90) => `<path d="M${x - w / 2 + 30} ${y - h / 2} H${x + w / 2 + 30} L${x + w / 2 - 30} ${y + h / 2} H${x - w / 2 - 30} Z" fill="#fff" stroke="#000" stroke-width="2.5"/>` + text(x, y, t, { size: 25 });
  const dec = (x, y, t, w = 400, h = 150) => `<path d="M${x} ${y - h / 2} L${x + w / 2} ${y} L${x} ${y + h / 2} L${x - w / 2} ${y} Z" fill="#fff" stroke="#000" stroke-width="2.5"/>` + text(x, y, t, { size: 24 });
  const lab = (x, y, t, a = 'start') => text(x, y, t, { size: 24, bold: true, anchor: a });
  const Y = { start: 60, menu: 180, newq: 330, slotN: 490, name: 620, ch1: 750, slotC: 490, load: 620, explore: 900, inter: 1060, dlg: 1230, chal: 1400, ans: 1570, mast: 1700, quest: 1850, save: 2030 };
  b += term(cx, Y.start, 'Start');
  b += line([[cx, Y.start + 40], [cx, Y.menu - 45]]);
  b += proc(cx, Y.menu, 'Open main menu');
  b += line([[cx, Y.menu + 45], [cx, Y.newq - 75]]);
  b += dec(cx, Y.newq, 'New game?');
  // yes branch (left)
  const lx = 560, rx = 1080;
  b += line([[cx - 200, Y.newq], [lx, Y.newq], [lx, Y.slotN - 45]]); b += lab(cx - 215, Y.newq - 22, 'Yes', 'end');
  b += io(lx, Y.slotN, 'Choose a save slot', 380);
  b += line([[lx, Y.slotN + 45], [lx, Y.name - 45]]);
  b += io(lx, Y.name, 'Enter player name', 380);
  b += line([[lx, Y.name + 45], [lx, Y.ch1 - 45]]);
  b += proc(lx, Y.ch1, 'Start Chapter 1', 380);
  b += line([[lx, Y.ch1 + 45], [lx, 810], [cx - 60, 810], [cx - 60, Y.explore - 45]]);
  // no branch (right)
  b += line([[cx + 200, Y.newq], [rx, Y.newq], [rx, Y.slotC - 45]]); b += lab(cx + 215, Y.newq - 22, 'No (Continue)');
  b += io(rx, Y.slotC, 'Choose a saved slot', 380);
  b += line([[rx, Y.slotC + 45], [rx, Y.load - 45]]);
  b += proc(rx, Y.load, 'Load saved game', 380);
  b += line([[rx, Y.load + 45], [rx, 810], [cx + 60, 810], [cx + 60, Y.explore - 45]]);
  // main loop
  b += proc(cx, Y.explore, 'Explore the game world');
  b += line([[cx, Y.explore + 45], [cx, Y.inter - 75]]);
  b += dec(cx, Y.inter, 'Interact with an\nNPC or object?', 420);
  const loopX = 130;
  const back = y => { b += line([[loopX, y], [loopX, Y.explore], [cx - 200, Y.explore]]); };
  b += line([[cx - 210, Y.inter], [loopX, Y.inter]], { head: false }); b += lab(cx - 225, Y.inter - 22, 'No', 'end');
  b += line([[cx, Y.inter + 75], [cx, Y.dlg - 45]]); b += lab(cx + 14, Y.inter + 98, 'Yes');
  b += io(cx, Y.dlg, 'Show Akeanon dialogue\n(tap a word to see its meaning)', 470, 100);
  b += line([[cx, Y.dlg + 50], [cx, Y.chal - 75]]);
  b += dec(cx, Y.chal, 'Quiz, phrase, or\nmini-game in dialogue?', 460, 160);
  b += line([[cx, Y.chal + 80], [cx, Y.ans - 45]]); b += lab(cx + 14, Y.chal + 102, 'Yes');
  b += io(cx, Y.ans, 'Player answers', 380);
  b += line([[cx, Y.ans + 45], [cx, Y.mast - 45]]);
  b += proc(cx, Y.mast, 'Update word mastery\n(+1 correct, −1 wrong)', 420);
  b += line([[cx, Y.mast + 45], [cx, Y.quest - 75]]);
  // no challenge -> skip to quest decision (right side)
  b += line([[cx + 230, Y.chal], [1260, Y.chal], [1260, 1775], [cx + 10, 1775]]); b += lab(cx + 245, Y.chal - 22, 'No');
  b += dec(cx, Y.quest, 'Quest complete?', 400);
  b += line([[cx - 200, Y.quest], [loopX, Y.quest]], { head: false }); b += lab(cx - 215, Y.quest - 22, 'No', 'end');
  b += line([[cx, Y.quest + 75], [cx, Y.save - 45]]); b += lab(cx + 14, Y.quest + 98, 'Yes');
  b += proc(cx, Y.save, 'Update quest journal\nand auto-save', 420);
  b += line([[cx, Y.save + 45], [cx, 2110]]);
  b += dec(cx, 2180, 'Chapter complete?', 400, 140);
  b += line([[cx - 200, 2180], [loopX, 2180]], { head: false }); b += lab(cx - 215, 2158, 'No', 'end');
  b += line([[cx, 2250], [cx, 2320]]); b += lab(cx + 14, 2273, 'Yes');
  b += dec(cx, 2390, 'Next chapter\navailable?', 380, 140);
  b += line([[cx - 190, 2390], [loopX, 2390], [loopX, Y.explore], [cx - 200, Y.explore]]); b += lab(cx - 205, 2368, 'Yes: show chapter card', 'end');
  b += line([[cx + 190, 2390], [1180, 2390]]); b += lab(cx + 205, 2368, 'No');
  b += `<rect x="1180" y="2350" width="300" height="80" rx="40" fill="#fff" stroke="#000" stroke-width="2.5"/>` + text(1330, 2390, 'End of available\nchapters', { size: 23, bold: true });
  b += text(loopX + 14, 1000, 'continue exploring', { size: 22, italic: true, anchor: 'start' });
  made.push(page('fig6_flowchart', W, H, b));
}

fs.writeFileSync(`${OUT}/list.json`, JSON.stringify(made));
console.log(made.map(m => `${m.name} ${m.w}x${m.h}`).join('\n'));
