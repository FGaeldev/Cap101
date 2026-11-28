# Builds the user manual's labeled figures: a screenshot with highlighted parts
# joined by dotted leader lines to dark pill labels (the Face-IT manual's style),
# set in Times New Roman to match the manuscript.
#   python annotate.py <shots_dir> <paper_shots_dir> <out_dir>
import sys, os, math
from PIL import Image, ImageDraw, ImageFont

SHOTS, PAPER, OUT = sys.argv[1:4]
os.makedirs(OUT, exist_ok=True)
F = r"C:\Windows\Fonts"
PILL = ImageFont.truetype(os.path.join(F, "timesbd.ttf"), 46)
DESC = ImageFont.truetype(os.path.join(F, "times.ttf"), 38)
CAP = ImageFont.truetype(os.path.join(F, "times.ttf"), 40)
YEL = (242, 183, 5)
INK = (40, 40, 40)
GREY = (70, 70, 70)

def src(name):
    p = os.path.join(SHOTS, name)
    return p if os.path.exists(p) else os.path.join(PAPER, name)

def wrap(draw, text, font, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=font) <= width:
            cur = t
        else:
            lines.append(cur); cur = w
    if cur:
        lines.append(cur)
    return lines

def dotted(draw, a, b, gap=10, r=3):
    d = math.dist(a, b)
    n = max(1, int(d // gap))
    for i in range(n + 1):
        t = i / n
        x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        draw.ellipse([x - r, y - r, x + r, y + r], fill=INK)

def pill(draw, x, y, text, anchor_right):
    w = draw.textlength(text, font=PILL) + 56
    h = 70
    x0 = x - w if anchor_right else x
    draw.rounded_rectangle([x0, y - h / 2, x0 + w, y + h / 2], radius=h / 2, fill=(45, 45, 48))
    draw.text((x0 + 28, y), text, font=PILL, fill="white", anchor="lm")
    return x0, x0 + w

def labeled(name, out, callouts, img_w=1400, side=680):
    """callouts: (side 'L'/'R', label, description, (x0, y0, x1, y1) in screenshot px[, route])
    route: {"via": "up"|"down", "lane": y in screenshot px} leaves the box from its top or
    bottom centre, runs along that lane to the image edge, then to the label."""
    shot = Image.open(src(name)).convert("RGB")
    s = img_w / shot.width
    shot = shot.resize((img_w, round(shot.height * s)), Image.LANCZOS)
    tmp = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    PAD = 120  # pill edge distance from the image
    blocks = []
    for c in callouts:
        side_, label, desc, box = c[:4]
        route = c[4] if len(c) > 4 else None
        lines = wrap(tmp, desc, DESC, side - PAD - 30) if desc else []
        box = [v * s for v in box]
        ty = route["lane"] * s if route else (box[1] + box[3]) / 2
        blocks.append(dict(sd=side_, label=label, lines=lines, box=box, route=route, ty=ty, h=70 + 14 + len(lines) * 44))
    pos, rank, count = {}, {}, {}
    for sd in "LR":
        items = sorted([i for i, b in enumerate(blocks) if b["sd"] == sd], key=lambda i: blocks[i]["ty"])
        count[sd] = len(items)
        y = -10 ** 9
        for r, i in enumerate(items):
            y = max(blocks[i]["ty"] - 35, y)
            pos[i] = y
            rank[i] = r
            y += blocks[i]["h"] + 22
    lo = min([0] + list(pos.values()))
    hi = max([shot.height] + [pos[i] + blocks[i]["h"] for i in pos])
    off = 40 - lo
    W, H = img_w + 2 * side, int(hi - lo + 80)
    im = Image.new("RGB", (W, H), "white")
    ix, iy = side, off
    im.paste(shot, (ix, int(iy)))
    d = ImageDraw.Draw(im)
    d.rectangle([ix - 1, iy - 1, ix + img_w, iy + shot.height], outline=(150, 150, 150), width=2)
    for i, b in enumerate(blocks):
        bx0, by0, bx1, by1 = b["box"][0] + ix, b["box"][1] + iy, b["box"][2] + ix, b["box"][3] + iy
        d.rounded_rectangle([bx0, by0, bx1, by1], radius=8, outline=YEL, width=6)
    for i, b in enumerate(blocks):
        bx0, by0, bx1, by1 = b["box"][0] + ix, b["box"][1] + iy, b["box"][2] + ix, b["box"][3] + iy
        py = pos[i] + off + 35
        ty = b["ty"] + iy
        n = count[b["sd"]]
        # labels pushed down get the outer elbows, so no two lines cross
        dist = 22 + 16 * (n - 1 - rank[i])
        L = b["sd"] == "L"
        ex = ix - dist if L else ix + img_w + dist
        pts = []
        if b["route"]:
            cx = (bx0 + bx1) / 2
            pts = [(cx, by0 if b["route"]["via"] == "up" else by1), (cx, ty)]
        else:
            ty = min(max(ty, by0 + 6), by1 - 6)
            pts = [(bx0 if L else bx1, ty)]
        pts += [(ex, ty), (ex, py)]
        if L:
            px0, px1 = pill(d, ix - PAD, py, b["label"], True)
            pts.append((px1 + 6, py))
            for k, ln in enumerate(b["lines"]):
                d.text((ix - PAD, py + 44 + k * 44), ln, font=DESC, fill=GREY, anchor="ra")
        else:
            px0, px1 = pill(d, ix + img_w + PAD, py, b["label"], False)
            pts.append((px0 - 6, py))
            for k, ln in enumerate(b["lines"]):
                d.text((ix + img_w + PAD, py + 44 + k * 44), ln, font=DESC, fill=GREY, anchor="la")
        for a, c in zip(pts, pts[1:]):
            if math.dist(a, c) > 1:
                dotted(d, a, c)
    im.save(os.path.join(OUT, out + ".png"))
    print(out, im.size)

def pair(out, items, w=1060, gap=120):
    """items: up to two (file, label, caption)"""
    tmp = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    shots = []
    for f, label, cap in items:
        sh = Image.open(src(f)).convert("RGB")
        sh = sh.resize((w, round(sh.height * w / sh.width)), Image.LANCZOS)
        shots.append((sh, label, wrap(tmp, cap, CAP, w)))
    capH = max(len(c) for _, _, c in shots) * 50
    H = 90 + shots[0][0].height + 20 + capH + 30
    W = 2 * w + gap + 60
    im = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(im)
    for k, (sh, label, cap) in enumerate(shots):
        x = 30 + k * (w + gap)
        y = 90
        im.paste(sh, (x, y))
        d.rectangle([x - 1, y - 1, x + w, y + sh.height], outline=(150, 150, 150), width=2)
        dotted(d, (x - 18, 42), (x - 18, y + 30)); dotted(d, (x - 18, 42), (x + 4, 42))
        pill(d, x + 6, 42, label, False)
        for i, ln in enumerate(cap):
            d.text((x, y + sh.height + 20 + i * 50), ln, font=CAP, fill=GREY)
    im.save(os.path.join(OUT, out + ".png"))
    print(out, im.size)

# ---------------------------------------------------------------- labeled screens
labeled("m01_main_menu.png", "f_main_menu", [
    ("R", "Start", "Begins a new game in one of three save slots.", (1155, 243, 1670, 340)),
    ("R", "Continue", "Loads a saved game.", (1155, 366, 1670, 463)),
    ("R", "Settings", "Volume, screen size, and accessibility.", (1155, 490, 1670, 587)),
    ("R", "About", "Shows the credits.", (1425, 612, 1670, 710)),
    ("R", "Help", "How to play, the chapters, and every activity.", (1155, 612, 1400, 710), {"via": "down", "lane": 722}),
    ("L", "Exit", "Closes the game.", (1155, 735, 1670, 832)),
])
labeled("m02_save_slots.png", "f_save_slots", [
    ("R", "Save Slot", "Tap an empty slot to start. A used slot shows when it was last saved.", (387, 258, 1532, 418)),
    ("R", "Back", "Returns to the main menu.", (387, 835, 1532, 914)),
])
labeled("m04_game_screen.png", "f_game_screen", [
    ("L", "Current Quest", "What to do next. Tap it to see all quests.", (68, 43, 514, 125)),
    ("L", "Arrow Pad", "Hold an arrow to walk (W, A, S, D on a keyboard).", (92, 668, 412, 985)),
    ("R", "Pesos", "Your money. Tap it to learn how to earn and spend.", (1453, 43, 1585, 133), {"via": "up", "lane": 18}),
    ("R", "Day and Clock", "Tap it to open the calendar.", (1600, 43, 1853, 133)),
    ("R", "Map", "Travel to other places.", (1545, 150, 1636, 240), {"via": "down", "lane": 330}),
    ("R", "Dictionary", "Every Akeanon word you have met.", (1652, 150, 1743, 240), {"via": "down", "lane": 295}),
    ("R", "Menu", "Pauses the game (Esc).", (1760, 150, 1851, 240), {"via": "down", "lane": 260}),
    ("R", "Action Button", "Appears near a person or thing: Talk, Look, or Pick up (E).", (1717, 877, 1858, 1017)),
])
labeled("m05_npc_menu.png", "f_npc_menu", [
    ("L", "Person", "Who you are talking to.", (40, 688, 210, 742)),
    ("R", "Talk", "Chat. Talk again later for new lines.", (48, 760, 1871, 838)),
    ("R", "Review", "Practice words with a quick game.", (48, 856, 1871, 934)),
    ("R", "Goodbye", "Leave the conversation.", (48, 952, 1871, 1030)),
    ("R", "Help", "Explains this menu.", (1777, 668, 1840, 745)),
])
labeled("08_dialogue_word_tapped.png", "f_dialogue", [
    ("L", "Speaker", "The person talking.", (40, 895, 160, 950)),
    ("L", "Akeanon Word", "Colored and underlined. Tap it.", (45, 978, 145, 1032)),
    ("R", "Meaning", "The English meaning. Tap again to close.", (967, 795, 1137, 1033)),
    ("R", "Portrait", "The speaker's face.", (1728, 630, 1915, 822)),
])
labeled("m06_pause.png", "f_pause", [
    ("L", "Word Tier", "Fills as you practice. Higher tiers use more words.", (650, 193, 1268, 385)),
    ("R", "Continue", "Back to the game.", (650, 410, 1268, 480)),
    ("R", "Conversation Log", "Lines from recent conversations.", (650, 508, 1268, 578)),
    ("R", "Achievements", "Achievements and collections.", (650, 607, 1268, 677)),
    ("L", "Settings", "Volume, screen size, accessibility.", (650, 706, 1268, 776)),
    ("L", "Help", "How to play and every activity.", (650, 805, 1268, 875)),
    ("L", "Exit to Menu", "Saves and returns to the main menu.", (650, 898, 1268, 978)),
])
labeled("09_menu_dictionary.png", "f_dictionary", [
    ("L", "Back", "Returns to the game.", (48, 52, 100, 105)),
    ("L", "Search", "Type a word or an English meaning.", (54, 150, 918, 242)),
    ("L", "Category", "Show one kind of word only.", (54, 267, 918, 360)),
    ("L", "Words Known", "Words met out of all words.", (54, 395, 490, 442)),
    ("R", "Word Entry", "Word, word type, times seen, and meaning.", (995, 160, 1870, 300)),
    ("R", "Next Page", "More words.", (1830, 993, 1877, 1037)),
])
labeled("09_menu_bucket_list.png", "f_quests", [
    ("L", "Quest List", "Active quests. Tap one to read it.", (38, 200, 933, 440)),
    ("R", "Quest Details", "What the quest asks you to do.", (980, 135, 1870, 545)),
])
labeled("m08_map_travel.png", "f_map", [
    ("L", "Trip Details", "The fare, the walking time, and your pesos.", (590, 380, 1330, 600)),
    ("L", "Ride", "Pay the fare and go.", (592, 618, 825, 700)),
    ("R", "Walk", "Free, but takes longer.", (843, 618, 1077, 700), {"via": "down", "lane": 722}),
    ("R", "Balik", "Stay where you are.", (1095, 618, 1330, 700)),
    ("R", "Help", "Explains the map.", (1783, 165, 1853, 250)),
    ("R", "Place Not Open", "Dim places open later in the story.", (1135, 320, 1315, 425)),
])
labeled("09_menu_calendar.png", "f_calendar", [
    ("L", "Previous Month", "", (462, 143, 500, 188)),
    ("L", "Today", "The current day in the game.", (450, 405, 592, 466)),
    ("R", "Next Month", "", (1420, 143, 1460, 188)),
    ("R", "Events", "Holidays and events this month.", (105, 800, 870, 995)),
])
labeled("m07_log.png", "f_log", [
    ("L", "When and Where", "Date, time, and place of the talk.", (32, 172, 815, 222)),
    ("R", "Past Lines", "Akeanon words stay colored, so you can tap them again.", (32, 252, 1230, 395)),
])
labeled("m07_achievements.png", "f_achievements", [
    ("L", "Earned", "Achievements you have unlocked.", (36, 131, 1264, 295)),
    ("R", "Locked", "Not earned yet.", (1280, 131, 1884, 295)),
    ("R", "Progress", "Achievements earned so far.", (1805, 55, 1890, 110)),
    ("L", "Collections", "Sets of things to find around Kalibo.", (36, 505, 1884, 742)),
])
labeled("m07_settings.png", "f_settings", [
    ("L", "Volume", "Master, music, and sound effects.", (68, 160, 1830, 525)),
    ("R", "UI Scale", "Makes the screen bigger or smaller.", (68, 548, 548, 765)),
    ("R", "Color Blind Mode", "Names colors and changes answer colors.", (68, 790, 1700, 998)),
])
labeled("m03_help.png", "f_help", [
    ("R", "How to Play", "The basics, topic by topic.", (936, 111, 1182, 190)),
    ("R", "Chapters", "What each chapter teaches.", (1206, 111, 1395, 190)),
    ("R", "Activities", "How every game works.", (1419, 111, 1620, 190)),
    ("R", "Close", "", (1644, 111, 1767, 190)),
    ("L", "Topics", "Scroll to read them all.", (145, 215, 1745, 960)),
])

# ---------------------------------------------------------------- activity grids
pair("g_review", [("10_quiz.png", "Quiz", "Tap the right meaning. About seven in ten right answers pass."),
                  ("13_hangman.png", "Hangman", "Guess the hidden word letter by letter from its English clue.")])
pair("g_match", [("12_memory_match.png", "Memory Match", "Turn over two cards to match a word with its meaning."),
                 ("11_phrase_builder.png", "Phrase Builder", "Tap the words in the right order, then tap Check.")])
pair("g_chapter", [("15_habi_habi.png", "Habi-Habi", "Trace the word Manang Loleng calls to weave a row of cloth."),
                   ("14_fishing.png", "Fishing for Words", "Tap the fish carrying the right answer before time runs out.")])
pair("g_paper", [("16_puzzle_0.png", "Crossword", "The newspaper's daily puzzle. Fill the grid from the English clues."),
                 ("16_puzzle_1.png", "Word Search", "The other daily puzzle. Drag across each word's letters.")])
pair("g_town", [("m10_stall.png", "Help at the Stall", "Serve five customers who ask in Akeanon. Pays \u20b12 each."),
                ("m09_directions.png", "Help with Directions", "Steer the visitor with abante, atras, liko pa waea, and liko pa tuo.")])
pair("g_places1", [("02_world_pastrana.png", "Pastrana Park", "The town plaza. Read the monuments and help lost visitors."),
                   ("03_world_cathedral.png", "Kalibo Cathedral", "Visit with Rose and read about its history.")])
pair("g_places2", [("04_world_market.png", "Market", "Buy food at Nong Pedring's stall and help him serve customers."),
                   ("05_world_gallery.png", "Haboean Gallery", "Exhibits about the culture of Aklan, in Haboean.")])
pair("g_places3", [("06_world_bakhawan.png", "Bakhawan Eco-Park", "Walk the mangrove forest with Manong Ambo and go fishing."),
                   ("16_newspaper_0.png", "Newspaper", "At home: the Word of the Day and the daily puzzle (\u20b110).")])
