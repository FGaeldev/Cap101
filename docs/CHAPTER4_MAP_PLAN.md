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

## 5. Outdoor plan

**Approach:** keep the existing 42 × 25 block untouched and **extend the map north into negative rows**, out to y = −37. That makes the map 42 × 62.
- All existing markers, warps and the Ch2 arrival cutscene keep their coordinates.
- The camera limits need updating for the new size.

Bands, top to bottom:

| Rows | Band | Floor | Objects |
|---|---|---|---|
| −37..−34 | **Sea** (Kalibo bay) | Water, animated if possible; collision | Fishing pier from the end of the boardwalk (x16–19, about 4 × 6). Clam-farm stakes on the right (x30–38). |
| −33..−28 | **Beach / baybay** | Sand, with a foam line where it meets the water | 4 sea-facing cottages, 4 × 3 each (x2, 7, 31, 36). Mark the S4 spot near the boardwalk end. A propagule planting row on the sand edge could serve **tanom** and an optional tree-planting interaction. |
| −27..−5 | **Mangrove forest** | Mud, with root decals on FloorDecals | Dense `Bakhawan_tree` instances, mostly the round prop-root variant, with roots on Objects and canopy on Roof. A **river channel** winds east–west around rows −20..−16, crossed by a **bamboo bridge**. A **watchtower** (4 × 4 base, tall sprite) sits on a spur at x27–30, y−26..−22. A **rest platform** (5 × 4) at x11–15, y−12..−9 is the **S2** spot. |
| −4..−1 | Forest edge | Grass becoming mud | 2 picnic huts (x30, x35). Young mangroves. |
| 0..12 | Existing grass (new content) | Grass | **Bamboo gate + trail sign** at x18–20, y4. This is **S1**, where Ambo waits. **Nursery** (6 × 8, x0–5, y2–9) with rows of seedling bags. **Canteen** and **souvenir kiosk** (6 × 4 each, x24 and x32, y2) with two tables. |
| 13..24 | Existing plaza and parking | — | Unchanged. |

**Boardwalk**
- 2 tiles wide, bamboo, collision on both sides.
- It zig-zags north from the gate (x20, y7) to the pier (x18, y−31). That's about 60 tiles, a game-scale stand-in for 1.3 km.
- Keep the turns at right angles so it only needs straight, corner and T pieces.
- Rule: the player walks **only** on boardwalk, beach and land. Mud and water get collision.

**Markers to add** (in the `SceneMarkers/Ch4/...` style)
- `Ch4/Ambo_Gate`, `Ch4/S2_Platform`, `Ch4/S3_Pier`, `Ch4/S4_Shore`, `Ch4/S5_Cottage`
- Spawn points for Jonabel and Jobert at the cottage
- `FromTrailDoor`, beside the gate, for the indoor back door

**Examinables / field notes**
- KASAMA plaque at the gate
- Species sign on the S2 platform
- Watchtower view: a camera pan over the canopy
- "Do not cut mangroves" sign at the beach

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
12. Clam stakes and fishing pier

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
2. **Map size:** is 42 × 62 in one scene OK, or should the beach be a separate scene? One scene is simpler for the walk-and-talk cutscenes.
3. **Fishing:** from the pier into the sea, or from the bamboo bridge into the river? The river is more mangrove-like; the pier reads better for the minigame.
4. **Kayaks:** leave them out, since the real park doesn't confirm them.
