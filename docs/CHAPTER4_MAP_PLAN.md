# Chapter 4 map prep: Bakhawan Eco-Park (rough draft)

Two maps: **1 outdoor** (`scenes/world/bakhawan/bakhawan_outdoors.tscn`) and **1 indoor** (`scenes/world/bakhawan/bakhawan_indoors.tscn`).
This is a rough placement plan to argue over, not final art. All coordinates are TileMapLayer cells (16 px).

Diagrams:
- Outdoor: [maps/bakhawan_outdoor_draft.svg](maps/bakhawan_outdoor_draft.svg)
- Indoor: [maps/bakhawan_indoor_draft.svg](maps/bakhawan_indoor_draft.svg)

---

## 1. What exists right now

| Thing | State |
|---|---|
| `bakhawan_outdoors.tscn` | Tiled, 42 × 25 tiles (cells x −1..41, y −1..24). Visitor-center facade with "BAKHAWAN ECO-PARK" sign, two planters, grey plaza, road and parking, one raised planter. **The top half is plain grass.** No trees, water, boardwalk or NPCs. |
| Markers already used | Warp to indoor (15,14) · warp to park (4,22) · spawns `DefaultSpawn` (14,15), `FromPark` (6,22), `FromIndoors` (15,15) · `Trip/Rose` (6,19). Used by `chapter2_walk_into_bakhawan` and `bakhawan_outdoors.gd`. |
| `bakhawan_indoors.tscn` | Empty shell: one `Node2D`, and its root is wrongly named `BakhawanOutdoors`. |
| `bakhawan_tree.tscn` + `Bakhawan_tree.png` | A 64 × 48 sheet with two trees: a tall leaning one with flared roots, and a round mangrove with hanging prop roots. |
| Tilesets | `outdoors.tres` uses `pastrana_outdoors.png`, which has the eco-park facade, roofs, planters, brick plaza and road. `indoors.tres` (`Indoors.png`) has walls, floors, beds, tables and counters. **Neither has water, mud, sand, bamboo boardwalk, nipa huts or mangrove roots.** |

## 2. Team member's Aseprite files

**`Art/Bakawan_Ecopark.aseprite`** (256 × 256 canvas, 168 × 119 drawing)
- This is the visitor-center facade: thatched roof in two tiers, bamboo-rail window band, a glass panel with the sign, a dark arched doorway, and three bushes.
- **It is already in the game.** It was copied into `pastrana_outdoors.png` and placed in the outdoor scene.
- The Aseprite file's sign reads **"BAKAWAN"**. The in-game tile reads **"BAKHAWAN"**, which matches the real park's name. Keep BAKHAWAN, and tell the team member so the source file gets fixed.

**`Art/Bakawan_indoor_2.aseprite`** (144 × 173 drawing, about 9 × 11 tiles)
- This is the visitor-center interior.
- Along the back wall: a bookshelf of colourful items, a teal cabinet, a potted plant, a long wooden bench, two green wall boards, and a dark doorway in the top right.
- In the room: a U-shaped reception desk with a chair and a terminal, flanked by two potted plants, on a darker plank area. One more potted plant sits in the bottom-left corner.
- Doors: an opening in the right wall at mid-height, and a front opening in the bottom right.
- **None of these props are in `Indoors.png` yet.** It has no U-desk, bookshelf, potted plant or wood-plank floor in this style. Each one has to be cut into the tileset before the room can be built.

## 3. Reference: the real park

From [Wikipedia](https://en.wikipedia.org/wiki/Bakhawan_Eco-Park) and travel write-ups:
- A mangrove forest on the muddy shoreline of New Buswang, Kalibo.
- About 220 ha. Reforestation began in 1990 on 50 ha of reclaimed land, to stop floods and storm surges.
- Run by **KASAMA** (Kalibo Save the Mangroves Association), with the Kalibo LGU and DENR.
- "Bakhawan" means mangrove.
- **Centerpiece:** a bamboo boardwalk, given as 1.1 km in some sources and 1.3 km in others. It goes deep into the forest and **ends at the beach**, where propagules are planted.
- Other features: a watchtower, picnic huts, a canteen, a souvenir shop, a mangrove research centre, and a massage area.
- Later sources add sea-facing cottages, a mangrove nursery, a bamboo bridge over the river, and clam farming.
- Tree planting is an activity. **Kayaking is not confirmed** (one review asks for it), so leave it out.

## 4. What Chapter 4's script needs (`data/dialogue/chapter4.json`)

| Scene | Content | Place it needs |
|---|---|---|
| S1 arrival | Rose: mangroves protect. Manong Ambo greets the visitors. | Trail entrance, open space for 4–5 actors |
| S2 learning | Roots grip the **eugta**; storms; **baeas** and **tubi** | Mid-boardwalk platform beside visible roots and mud |
| S3 fishing | **Pamunit** choice, then the fishing minigame (roadmap §5.4) | Water edge: pier or platform |
| S4 vocab | **baybay**, tubi, eugta, baeas · tikang pa, pamati, pamunit, **tanom** | The shore, where sand, water and mud meet. Ideally a planting spot too. |
| S5 reflection | Jonabel and Jobert speak. The roadmap says they need spawning. | A sit-down spot: a cottage or hut |

The route from gate to forest to river to beach follows the script order and the real walk, so the outdoor map is built around it.

## 5. Outdoor plan (v2: merged with the teammate's layout)

**Sources merged**
- The teammate's `bakhawan_outdoors.tscn` (received 2026-11-17). It has a water floor everywhere, mangrove sprites lining a winding boardwalk, fishpond dikes in the lower right, a grass rest island halfway, and a T-shaped deck at the far end. Their scene plotted as a layout: [maps/teammate_outdoor_layout.png](maps/teammate_outdoor_layout.png).
- My v1 draft: the beach and cottages, watchtower, stalls, nursery, and the scene markers.

**Approach**
- Use the teammate's route and floor, but move it onto the repo's coordinates.
- Keep the existing 42 × 25 entrance block (rows 0..24) untouched. Extend north to **y = −60**, so the map is 43 × 85 tiles.
- All existing markers, warps and the Ch2 arrival cutscene keep their coordinates.
- Update the camera limits for the new size.

**Why not use their file as is**
- It needs three PNGs that aren't in the repo: `818516708_…_n.png` (ground tiles), `820238759_…_n.png` (tree) and `bakhawan_indoor.png`.
- It has no warps, spawns, `SceneMarkers` or script.
- It instances its own Player.
- Its building sits at other coordinates than the repo's entrance.

Bands, top to bottom:

| Rows | Band | Floor | Objects |
|---|---|---|---|
| −60..−50 | **Open bay** (Kalibo) | Sea water, animated; collision | **T-deck** (teammate): stem at x29–30 rising from the island, bar along y−55..−54 from x19 to x39, railed on the open sides. **S3 fishing** at the east end (x38). **S4 vocab** at the west end (x23), looking at the sand spit: baybay, tubi, baeas all in view. **Sand spit** (x8–19, y−57..−49), reached by the west end of the T, with **2 sea-facing cottages**. This is **S5**, the family reflection. **Clam stakes** in the water to the west (x3–6, y−48..−44). |
| −49..−43 | Mangroves | Water | Trees in pairs along the stem (teammate pattern) |
| −42..−35 | **Rest island** (teammate's grass block) | Grass, with a mud-bank edge | 2 picnic huts (x22, x26). **Watchtower** (x34–37). The boardwalk runs straight across it. |
| −34..−5 | **Mangroves in water** | Water. Root decals only along the edges of the land. | Teammate's route: north from the gate, a jog west to x14, north to y−18, then a **staircase diagonal** to the north-east (2-tile steps, using only straight and corner pieces), then east along y−28 to x31, then north to the island. **S2 platform** (4 × 4) beside the walk at x9–12, y−15..−12. **Fishpond dikes** (1-tile grass strips) in a grid at x25–40, y−20..−4. These are scenery: only NPCs walk on them. |
| −4..−1 | Mud bank / shore | Grass, with a mud-edge line | Young mangroves |
| 0..12 | Existing grass (new content) | Grass | **Bamboo gate** at x18–21, y4. This is **S1**, where Ambo waits. **Nursery** (x0–5, y2–9). **Canteen** and **souvenir kiosk** (x24 and x32, y2). |
| 13..24 | Existing plaza and parking | — | Unchanged |

**Dropped from v1:** the mud floor, the river channel and the bamboo bridge. The whole area is now water, so a bridge adds nothing. The bridge art can return later as a higher section of boardwalk.

**Boardwalk**
- 2 tiles wide, bamboo.
- The player walks **only** on boardwalk, the island, the sand spit and the land south of row −1. All water has collision.
- The route is about 95 tiles long.
- It's built from straight, corner and T pieces. The diagonal is a staircase of corners, as in the teammate's version, so no diagonal art is needed.
- Trees go in pairs on both sides of the walk, as in the teammate's scene, but leave a 1-tile gap so canopies don't hide the player.

**Markers to add** (in the `SceneMarkers/Ch4/...` style)
- `Ch4/Ambo_Gate` (19,5)
- `Ch4/S2_Platform` (11,−13)
- `Ch4/S3_DeckEast` (38,−54)
- `Ch4/S4_DeckWest` (23,−54)
- `Ch4/S5_Cottage` (16,−52), plus spawns for Jonabel and Jobert there
- `FromTrailDoor` beside the gate, for the indoor back door

**Examinables / field notes**
- KASAMA plaque at the gate
- Species sign on the S2 platform
- Watchtower: a camera pan over the canopy
- "Do not cut mangroves" sign on the sand spit

## 6. Indoor plan: visitor center / reception

Build from the team drawing, widened from 9 to **12 × 11** so the right side has room for info displays.

| Spot | Object (from the drawing unless marked new) | Use |
|---|---|---|
| Back wall, left | Bookshelf, reused as a **souvenir shelf** | Examine, or a later shop |
| Back wall | Teal cabinet, potted plant | Decor |
| Back wall, centre | Green wall boards, reused as a **KASAMA history board (new label)** | Field note: 1990 start, 220 ha |
| Back wall | Long bench | Sit spot (single-seat system) |
| Top right | Dark doorway: **staff / research room**, locked | "Staff only" line |
| Centre | U-shaped reception desk with chair, flanked by 2 potted plants, on a darker plank area | Ticket desk. Ambo could greet here instead of at the gate. |
| Right wall, upper (new) | **Trail map board** | Examinable showing the outdoor layout |
| Right wall, lower (new) | **Propagule display** | Teaches **tanom** |
| Bottom left (new) | Guestbook stand, plant | Flavour line |
| Bottom wall | **Front door** → outdoor `FromIndoors` (15,15) | Existing warp |
| Right wall | **Back door** → outdoor `FromTrailDoor` at the gate | Matches the drawing's side opening and the real "enter through reception" flow |

Also rename the indoor root node from `BakhawanOutdoors` to `BakhawanIndoors`.

## 7. Tiles and sprites to request from the art team

**Outdoor**
1. Mud floor, plus a mud ↔ grass edge
2. Shallow river water and sea water (2–4 animation frames), plus edges
3. Sand, plus sand ↔ water foam and sand ↔ mud edges
4. Bamboo boardwalk: horizontal, vertical, corners, T-joint, end cap, railing posts
5. Bamboo bridge, a variant of the boardwalk with higher rails
6. Root decals and mangrove seedlings in mud
7. Nipa cottage (4 × 3) and picnic hut (3 × 3)
8. Watchtower (4 × 4 base, about 6 tiles tall)
9. Nursery seedling bags and rack
10. Canteen and souvenir kiosk (nipa roof)
11. Signboards
12. Clam stakes, and the T-deck end piece (the old fishing pier)

**Indoor:** export from `Bakawan_indoor_2.aseprite` into `Indoors.png`:
- Plank floor (light and dark)
- U-desk
- Bookshelf
- Cabinet
- Potted plant
- Bench
- Wall boards
- Doorway
- New: map board, propagule display

**Fix:** "BAKAWAN" → "BAKHAWAN" in the source Aseprite file.

**Sample art (2026-11-16):** placeholder versions of everything above are in `art_requests/`. They were generated in code using the palette sampled from `pastrana_outdoors.png`.
- `bakhawan_sprites_template.png`: 1x sheet to draw over
- `bakhawan_sprites_preview.png`: 4x, numbered and labelled
- `bakhawan_mockup.png`: the pieces combined with the existing `Bakhawan_tree.png` in one test scene
- `tools/gen_bakhawan.gd.txt`: the generator. Rename it to `.gd` and run it with `--script` to regenerate.

The indoor items marked "from drawing" are cut straight from `Bakawan_indoor_2.aseprite`, with the floor colours removed.

## 8. Open questions

1. **Where does Ambo greet?** At the trail gate outside, or at the reception desk inside? The draft uses the gate so all five scenes happen outdoors and the indoor room stays optional.
2. **Map size:** is 43 × 85 tiles in one scene OK? One scene is simpler for the walk-and-talk cutscenes.
3. **Fishing:** *(settled in v2)* from the east end of the teammate's T-deck. The pier art becomes the T-deck's end piece.
4. **Teammate's textures:** ask for the three PNGs their scene uses, so their tree and ground art can replace the generated samples.
5. **Kayaks:** leave them out, since the real park doesn't confirm them.
