// make_bubble_icons.js -- builds assets/ui/bubble_icons.png, the picture-bubble
// icon sheet (scripts/autoload/PictureBubbles.gd), from the pixel maps below.
//
//   node art_requests/tools/make_bubble_icons.js        (from the project root)
//
// One style for every icon:
//   - 16 x 16 cells, one row, in the order of data/bubble_icons.json.
//   - Shapes are drawn with fills only; the 1 px outline (OUTLINE) is added
//     around every icon by this script, so all outlines match.
//   - One shared palette with a light and a shadow tone per colour; light
//     comes from the top left.
//   - Each icon is centred in its cell from its own bounds.
// Also writes art_requests/bubble_icons_preview.png: every icon on the bubble's
// fill colour, x6, with its name order matching the JSON.
//
// To change an icon, edit its rows (16 characters each, '.' = empty).
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const ROOT = path.resolve(__dirname, "..", "..");
const OUTLINE = "45283c";  // same outline as art_requests/tools/gen_bakhawan.gd.txt
const BUBBLE_FILL = "ffd6a8";
const BUBBLE_EDGE = "7d3f4b";

const PALETTE = {
	w: "ffffff", W: "d6d4e0", g: "a8a6b8", h: "7a7488",   // white / greys
	y: "ffd23a", Y: "e0961a", l: "fff2a0",                 // gold
	o: "f5962a", O: "c2621a",                              // orange
	r: "e8473f", R: "a82c38", p: "f7b0bf", P: "d97a92", q: "e8889a", // reds, pinks
	b: "4a90e0", B: "2c5ca8", c: "a6d4f7",                 // blues
	a: "c9dc46", A: "8ea62c",                              // star-fruit yellow-green
	G: "4caf50", D: "2e7d3c",                              // greens
	n: "c07a3a", N: "7e4a24", t: "ecd29c", T: "c9a364",    // browns, tan
	s: "f2c28a", S: "cf9660",                              // skin
	e: "fff4dc", E: "e2cfa6",                              // cream (egg)
	m: "e8508a", M: "b03268",                              // magenta (new tag)
	v: "bfa3ad", V: "8c7480", x: "a3967c",                 // faded tag, tarnished ring
	u: "7a72d8", U: "4c46a6",                              // zzz purple
	k: "2e2430",                                           // eye / pupil
};

// --- pixel maps ---------------------------------------------------------------
const MAPS = {
	star: [
		".......ly.......",
		".......ly.......",
		"......llyy......",
		"......lyyy......",
		".lllllyyyyyyyyY.",
		"..llyyyyyyyyYY..",
		"...lyyyyyyyyY...",
		"....yyyyyyyY....",
		"....yyyyyyyY....",
		"...yyyyyyyyyY...",
		"...yyyY..yyyY...",
		"..yyY......yYY..",
		"..yY........YY..",
	],
	moon: [
		"......lllll.....",
		"....llyyY.......",
		"...lyyY.........",
		"..lyyY..........",
		"..lyyY..........",
		".lyyy...........",
		".lyyy...........",
		".lyyy...........",
		".lyyyY..........",
		"..yyyyY.........",
		"...yyyyyY.......",
		"....YyyyyyyY....",
		"......YYYYY.....",
	],
	sun: [
		".......oo.......",
		"..o....oo....o..",
		"...o........o...",
		"......llyy......",
		".....lyyyyY.....",
		"....lyyyyyyY....",
		".oo.lyyyyyyY.oo.",
		".oo.yyyyyyyY.oo.",
		"....yyyyyyYY....",
		".....yyyyYY.....",
		"......YYYY......",
		"...o........o...",
		"..o....oo....o..",
		".......oo.......",
	],
	map: [
		".ttttTttttTtttt.",
		".tGGtTttttTtrrt.",
		".tGGtTttttTrrRt.",
		".ttttTttttTtRtt.",
		".bbttTttttTtttt.",
		".tbbbbbtttTtttt.",
		".ttttTbbbbbbttt.",
		".ttttTttttTbbbb.",
		".ttttTttttTtttt.",
		".TTTTTTTTTTTTTT.",
	],
	bell: [
		".......NN.......",
		"......yyyy......",
		".....lyyyyY.....",
		".....lyyyyY.....",
		"....lyyyyyyY....",
		"....lyyyyyyY....",
		"....lyyyyyyY....",
		"...lyyyyyyyyY...",
		"...lyyyyyyyyY...",
		"..lyyyyyyyyyyY..",
		"..YYYYYYYYYYYY..",
		".......NN.......",
	],
	calendar: [
		"....g......g....",
		"..rrgrrrrrrgrr..",
		"..rrrrrrrrrrrR..",
		"..RRRRRRRRRRRR..",
		"..wwwwwwwwwwwW..",
		"..wggwggwggwwW..",
		"..wwwwwwwwwwwW..",
		"..wggwggwggwwW..",
		"..wwwwwwwwwwwW..",
		"..wggwggwRRwwW..",
		"..wwwwwwwwwwwW..",
		"..WWWWWWWWWWWW..",
	],
	star_fruit: [
		".......aa.......",
		"......aaaa......",
		"......aaaa......",
		".....aallaa.....",
		".aaaaaallaaaaaA.",
		"..aaaallllaaaA..",
		"...aallNNllaA...",
		"....allllllA....",
		"....aaallaaA....",
		"...aaaaAaaaaA...",
		"...aaaA..aaaA...",
		"..aaA......aAA..",
		"..aA........AA..",
	],
	fish: [
		"......bbbB......",
		"...bbbbbbbB..BB.",
		"..bkbbbbbbbB.BB.",
		".bbbbbbbbbbbBB..",
		".cbbbbbbbbbBBB..",
		"..ccccccccbB.BB.",
		"...cccccccB..BB.",
	],
	crab: [
		"..r..........r..",
		".rr..........rr.",
		".rr.r......r.rr.",
		"..rrr......rrr..",
		"....rrrrrrrr....",
		"...rrkrrrrkrr...",
		"..rrrrrrrrrrrr..",
		"..RrrrrrrrrrrR..",
		"...RRRRRRRRRR...",
		"..R.R.R..R.R.R..",
		".R..R......R..R.",
	],
	chicken: [
		"....rr..........",
		"...rrrr.........",
		"...wwww.........",
		"..owkww.........",
		"...rwwww....W...",
		"...wwwwwwwwWW...",
		"...wwwwwwwwwW...",
		"...wwwwWWwwwW...",
		"....wwwwwwwW....",
		".....WWWWWW.....",
		"......o..o......",
		".....oo.oo......",
	],
	egg: [
		"......eeee......",
		".....eweeeE.....",
		"....ewweeeeE....",
		"....eweeeeeE....",
		"...eeeeeeeeeE...",
		"...eeeeeeeeeE...",
		"...eeeeeeeeeE...",
		"...eeeeeeeeeE...",
		"...eeeeeeeeEE...",
		"....eeeeeeEE....",
		".....EEEEEE.....",
	],
	rice_sack: [
		"......wwww......",
		".....twwwwT.....",
		"......NNNN......",
		".....ttttTT.....",
		"....tttttttT....",
		"...tttttttttT...",
		"...ttwwwwwttT...",
		"..tttwwwwwtttT..",
		"..ttttttttttTT..",
		"..ttttttttttTT..",
		"...TTTTTTTTTT...",
	],
	bread: [
		".....nnnnnn.....",
		"...nnttttttnn...",
		"..nttNttNttNtn..",
		".nttttttttttttn.",
		".nnnnnnnnnnnnnn.",
		".nnnnnnnnnnnnNN.",
		".nnnnnnnnnnnnNN.",
		".NNNNNNNNNNNNNN.",
	],
	meat: [
		".....rrrr.......",
		"....rpprrR......",
		"...rpprrrrR.....",
		"...rprrrrrR.....",
		"...rrrrrrrR.....",
		"...RrrrrrRR.....",
		"....RRrrRR......",
		"......RRww......",
		".........ww.....",
		"..........ww....",
		".........wwWw...",
		"..........wW....",
	],
	pig: [
		"..PP........PP..",
		"..PpP......PpP..",
		"..pppppppppppp..",
		".pppkppppppkppp.",
		".pppppppppppppP.",
		".pppqqqqqqqqpPP.",
		".pppqNqqqqNqpPP.",
		".pppqqqqqqqqpPP.",
		"..ppppppppppPP..",
		"...PPPPPPPPPP...",
	],
	thumbs_up: [
		"......ss........",
		"......ssS.......",
		".....sssS.......",
		".....sssS.......",
		"....ssssssssS...",
		".bb.sssssssssS..",
		".bbsssssssssSS..",
		".bbsSSSSSSSSSS..",
		".bbsssssssssS...",
		".bbsSSSSSSSS....",
		".bbssssssssS....",
		".bb.SSSSSSS.....",
	],
	keychain_new: [
		"...gg.......w...",
		"..g..g.....www..",
		"..g..g......w...",
		"...gg...........",
		"....g...........",
		".....mmmmmmM....",
		"....mppmmmmmM...",
		"....mpmmmmmmM...",
		"....mmmmmmmmM...",
		"....mmmmmmmMM...",
		".....MMMMMMM....",
	],
	keychain_old: [
		"...xx...........",
		"..x..x..........",
		"..x..x..........",
		"...xx...........",
		"....x...........",
		".....vvvvvvV....",
		"....vvvvvvvVV...",
		"....vvVvvvvvV...",
		"....vvvVvvvvV...",
		"....vvvvvvVVV...",
		".....VVVVVVV....",
	],
	basket_small: [
		"......NNNN......",
		".....N....N.....",
		"....NNNNNNNN....",
		"....ntntntnN....",
		".....tntntN.....",
		".....NNNNNN.....",
	],
	basket_big: [
		".....NNNNNN.....",
		"....N......N....",
		"...N........N...",
		"...N........N...",
		".NNNNNNNNNNNNNN.",
		".ntntntntntntnN.",
		"..tntntntntntN..",
		"..ntntntntntnN..",
		"..tntntntntntN..",
		"...ntntntntnN...",
		"...NNNNNNNNNN...",
	],
	exclaim: [
		"......lrrR......",
		"......rrrR......",
		"......rrrR......",
		".......rR.......",
		".......rR.......",
		".......rR.......",
		".......rR.......",
		"................",
		"......rrrR......",
		"......rrRR......",
	],
	question: [
		".....bbbbbB.....",
		"....bbB...bbB...",
		"....bB.....bB...",
		"...........bB...",
		"..........bbB...",
		".........bbB....",
		"........bbB.....",
		".......bbB......",
		".......bB.......",
		"................",
		".......bbB......",
		".......bBB......",
	],
	zzz: [
		"..........uuuuU.",
		".............U..",
		"............U...",
		".....uuuuU.U....",
		"........U.uuuuU.",
		".......U........",
		"......U.........",
		".....uuuuU......",
		".uuuU...........",
		"...U............",
		"..U.............",
		".uuuU...........",
	],
};

// Swatches: one cloth square, recoloured. Colours match the colour quiz's
// word_colors in data/dialogue/chapter2.json.
const SWATCH = [
	"222222222222",
	"211111111113",
	"211111111113",
	"211111111113",
	"211111111113",
	"211111111113",
	"211111111113",
	"211111111113",
	"21111111223.",
	"2111111223..",
	"211111223...",
	"3333333.....",
];
const SWATCH_COLORS = {
	swatch_white: ["ffffff", "ffffff", "d6d4e0"],
	swatch_black: ["1a1a1a", "4a4650", "0e0c10"],
	swatch_red: ["d32f2f", "f0645a", "9c1e2a"],
	swatch_blue: ["1e5fd0", "5a92f0", "143c90"],
	swatch_yellow: ["f5d000", "fff07a", "c89a00"],
	swatch_green: ["2e9e44", "5cc86a", "1e6e30"],
};

// --- build ----------------------------------------------------------------------
function hex(c) { return [parseInt(c.slice(0, 2), 16), parseInt(c.slice(2, 4), 16), parseInt(c.slice(4, 6), 16), 255]; }

// rows of letters -> 16x16 array of hex colours (null = empty), centred.
function place(rows, colorOf) {
	const h = rows.length, w = Math.max(...rows.map(r => r.length));
	let minX = w, maxX = -1, minY = h, maxY = -1;
	rows.forEach((r, y) => [...r].forEach((ch, x) => {
		if (ch !== ".") { minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y); }
	}));
	const bw = maxX - minX + 1, bh = maxY - minY + 1;
	if (bw > 14 || bh > 14) throw new Error(`shape is ${bw}x${bh}; max is 14x14 so the outline fits`);
	const ox = Math.floor((16 - bw) / 2) - minX, oy = Math.floor((16 - bh) / 2) - minY;
	const cell = Array.from({ length: 16 }, () => Array(16).fill(null));
	rows.forEach((r, y) => [...r].forEach((ch, x) => {
		if (ch === ".") return;
		const c = colorOf(ch);
		if (!c) throw new Error(`unknown palette letter '${ch}'`);
		cell[y + oy][x + ox] = c;
	}));
	// Outline: every empty pixel touching a filled one (4 directions).
	const out = cell.map(r => r.slice());
	for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) {
		if (cell[y][x]) continue;
		const near = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => cell[y + dy]?.[x + dx]);
		if (near) out[y][x] = OUTLINE;
	}
	return out;
}

function png(width, height, pixelAt) {
	const raw = Buffer.alloc((width * 4 + 1) * height);
	for (let y = 0; y < height; y++) {
		raw[y * (width * 4 + 1)] = 0;
		for (let x = 0; x < width; x++) {
			const p = pixelAt(x, y);
			p.forEach((v, i) => { raw[y * (width * 4 + 1) + 1 + x * 4 + i] = v; });
		}
	}
	const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
	const crc = buf => { let c = 0xffffffff; for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
	const chunk = (type, data) => {
		const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
		const td = Buffer.concat([Buffer.from(type), data]);
		const c = Buffer.alloc(4); c.writeUInt32BE(crc(td));
		return Buffer.concat([len, td, c]);
	};
	const ihdr = Buffer.alloc(13);
	ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
	ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
	return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr),
		chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
}

const names = JSON.parse(fs.readFileSync(path.join(ROOT, "data/bubble_icons.json"), "utf8")).icons;
const cells = names.map(name => {
	try {
		if (MAPS[name]) return place(MAPS[name], ch => PALETTE[ch]);
		if (SWATCH_COLORS[name]) return place(SWATCH, ch => SWATCH_COLORS[name][Number(ch) - 1]);
	} catch (err) {
		throw new Error(`${name}: ${err.message}`);
	}
	throw new Error(`${name}: no pixel map`);
});
const rowErrors = Object.entries(MAPS).flatMap(([n, rows]) => rows.map((r, i) => r.length !== 16 ? `${n} row ${i}: ${r.length} chars` : null).filter(Boolean));
if (rowErrors.length) console.warn("Rows that aren't 16 wide:\n  " + rowErrors.join("\n  "));

const sheet = png(16 * cells.length, 16, (x, y) => {
	const c = cells[Math.floor(x / 16)][y][x % 16];
	return c ? hex(c) : [0, 0, 0, 0];
});
fs.writeFileSync(path.join(ROOT, "assets/ui/bubble_icons.png"), sheet);

// Preview: each icon in a bubble-coloured box, 2 px gap, x6, 7 per row.
const PER_ROW = 7, BOX = 22, GAP = 4, SCALE = 6;
const rowsN = Math.ceil(cells.length / PER_ROW);
const pw = (PER_ROW * (BOX + GAP) + GAP), ph = (rowsN * (BOX + GAP) + GAP);
const preview = png(pw * SCALE, ph * SCALE, (X, Y) => {
	const x = Math.floor(X / SCALE), y = Math.floor(Y / SCALE);
	const col = Math.floor((x - GAP) / (BOX + GAP)), row = Math.floor((y - GAP) / (BOX + GAP));
	const bx = x - GAP - col * (BOX + GAP), by = y - GAP - row * (BOX + GAP);
	const i = row * PER_ROW + col;
	if (x < GAP || y < GAP || bx >= BOX || by >= BOX || i >= cells.length) return hex("2b2433");
	if (bx === 0 || by === 0 || bx === BOX - 1 || by === BOX - 1) return hex(BUBBLE_EDGE);
	const ix = bx - 3, iy = by - 3;
	if (ix >= 0 && iy >= 0 && ix < 16 && iy < 16 && cells[i][iy][ix]) return hex(cells[i][iy][ix]);
	return hex(BUBBLE_FILL);
});
fs.writeFileSync(path.join(ROOT, "art_requests/bubble_icons_preview.png"), preview);
console.log(`wrote ${cells.length} icons`);
