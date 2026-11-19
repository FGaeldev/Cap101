// Builds multi-panel screenshot figures as HTML (rendered to PNG by render.sh).
const fs = require('fs'), path = require('path');
const [, , SHOTS, OUT] = process.argv;
fs.mkdirSync(OUT, { recursive: true });
const figs = [
  ['fig7_main_screens', 2, [
    ['01_main_menu', 'Main menu'], ['04_world_market', 'Exploring the Kalibo Public Market'],
    ['08_dialogue_word_tapped', 'Dialogue with a tapped Akeanon word'], ['09_menu_dictionary', 'Dictionary of discovered words'],
  ]],
  ['fig8_minigames', 3, [
    ['10_quiz', 'Vocabulary quiz'], ['11_phrase_builder', 'Phrase builder'], ['12_memory_match', 'Memory match'],
    ['13_hangman', 'Hangman'], ['14_fishing', 'Fishing for words'], ['15_habi_habi', 'Habi-Habi loom game'],
    ['16_puzzle_0', 'Newspaper crossword'], ['16_puzzle_1', 'Newspaper word search'], ['17_market_pay', 'Market payment'],
  ]],
  ['fig9_menus', 3, [
    ['09_menu_pause', 'Pause menu'], ['09_menu_bucket_list', 'Quests'], ['09_menu_achievements', 'Achievements and collections'],
    ['09_menu_map', 'Map'], ['09_menu_calendar', 'Calendar of events'], ['09_menu_settings', 'Settings'],
  ]],
  ['fig10_places', 2, [
    ['02_world_pastrana', 'Pastrana Park'], ['03_world_cathedral', 'Kalibo Cathedral'],
    ['05_world_gallery', 'Piña weaving gallery (Haboean)'], ['06_world_bakhawan', 'Bakhawan Eco-Park'],
  ]],
];
const made = [];
const letters = 'abcdefghi';
for (const [name, cols, items] of figs) {
  const cellW = cols === 3 ? 560 : 820, imgH = Math.round(cellW * 9 / 16), gap = 22, capH = 44;
  const rows = Math.ceil(items.length / cols);
  const W = cols * cellW + (cols + 1) * gap, H = rows * (imgH + capH) + (rows + 1) * gap;
  const cells = items.map(([f, label], i) => {
    const src = 'file:///' + path.join(SHOTS, f + '.png').replace(/\\/g, '/');
    return `<div style="width:${cellW}px"><img src="${src}" style="width:${cellW}px;height:${imgH}px;display:block;border:2px solid #000;box-sizing:border-box"><div style="height:${capH}px;line-height:${capH}px;text-align:center;font:24px 'Times New Roman',serif">(${letters[i]}) ${label}</div></div>`;
  }).join('');
  const html = `<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:#fff;overflow:hidden}</style></head><body><div style="display:grid;grid-template-columns:repeat(${cols},${cellW}px);gap:${gap}px;padding:${gap}px">${cells}</div></body></html>`;
  fs.writeFileSync(path.join(OUT, name + '.html'), html);
  made.push({ name, w: W, h: H });
}
fs.writeFileSync(path.join(OUT, 'list.json'), JSON.stringify(made));
console.log(made.map(m => `${m.name} ${m.w}x${m.h}`).join('\n'));
