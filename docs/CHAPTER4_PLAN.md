# Chapter 4 "Roots of Bakhawan": implementation plan

Prepared 2026-11-16 from the working tree (on top of commit `7b452d0`, with the uncommitted Chapter 3 work) and `docs/STORY_ROADMAP.md` §6.4. The roadmap's build sheet is still the story target; this file maps it onto what's actually in the repo and orders the work. The map layout itself is in `docs/CHAPTER4_MAP_PLAN.md`.

## Where it stands

| Piece | State | Notes |
|---|---|---|
| Chapter entry | `data/chapters.json` has `chapter4`, `"available": false` | flip to `true` last |
| Dialogue | `data/dialogue/chapter4.json`: 5 scenes, 26 lines | routers fixed (`default: 1`); speaker is `Manong Ambo` everywhere; no `\` markers, few translations, no rapport deltas, no flags; s3 choice branch still wrong (1 and 2 → idx 3, idx 5 unreachable); s5 has Jonabel and Jobert at the park with nothing putting them there; s4 ids partly set (no `pamunit`); **no idle pool** (the roadmap's `manong_ambo` pool is gone) |
| How Ch3 ends | `chapter3_scene5` (evening home) sets `chapter3_complete` | Rose's last line is "Tomorrow's mud", and the Ch3 story call says Ch4 is the very next day. Nothing plays after `chapter3_complete` yet. |
| How a chapter starts | Ch3 pattern: sleep → next morning `aklan_living.gd` plays `chapter3_scene0` when NpcSchedule's `ch3_brief_pending` block has Rose, Susan, Jonabel in place | copy it as `ch4_brief_pending` + `chapter4_scene0` |
| Levels | `scenes/world/bakhawan/bakhawan_outdoors.tscn`: 42 × 25, visitor-centre facade, plaza, parking; **top half is plain grass**. `bakhawan_indoors.tscn`: empty shell, root misnamed `BakhawanOutdoors`. `bakhawan_tree.tscn` + `Bakhawan_tree.png` (two mangrove trees). | `docs/CHAPTER4_MAP_PLAN.md` extends the outdoor map north to 42 × 62 (forest, river, beach, sea). **No water, mud, sand or boardwalk tiles exist**; placeholder art is in `art_requests/bakhawan_*`. |
| Level script | `scripts/game_scenes/bakhawan_outdoors.gd`: Ch2 trip only (Rose walks in, stands at `Trip/Rose`) | |
| Way in | Ch2 Rose menu "Can we go to Bakhawan?" (`chapter2.json` `scene_rose_walk_to_park`) → `chapter2_walk_to_bakhawan` via Pastrana `WarpArea6` (`map_open_bakhawan`, never set: tracker B5). `TourGuide.STOPS` has a Bakhawan entry with no places. | Tracker: "Bakhawan has no story yet… Gate the trip until it has an activity." |
| Manong Ambo | portrait `assets/sprites/portraits/ambo_art.png` only | **no walk sprite**, no `npc_Ambo.tscn` |
| Jobert / Jonabel | `npc_PapaJobert.tscn`, `npc_LolaJonabel.tscn` exist | scene 5 needs whoever comes along spawned at the park |
| Fishing activity | none | panels: quiz, phrase builder, memory match, hangman, crossword, word search, puzzle, **weaving** (new in Ch3, the model to copy) |
| Challenges | `data/challenges/chapter2.json` has `ch2_tutorial_field_notes`, `ch2_bakhawan_gate1/2` (unlock `bakhawan_ecopark`, `bakhawan_boardwalk`); `regions.json` points Bakhawan at `stub_area_bakhawan.tscn` | roadmap: rename to `chapter4.json` / `ch4_*` |
| Quest / keepsake | quests stop at q008 (Ch3 used q006–q008) | Ch4 needs new ids from q009 on (the roadmap's q007 is taken) |
| Tooling | `autoplay.gd` `CHAPTERS` has 1–3; Ch2 "done" needs `_bakhawan_went`. `page_dev.gd` has a "Ch4 — Bakhawan" warp using Ch2 flags, no `CH4_START_FLAGS` | |
| Open bugs | tracker B5 (`map_open_bakhawan` never set), B7 (indoors and tree scenes have no `DefaultSpawn`), area-mapping bug (`current_area` stays `bakhawan_ecopark` after the trip home) | fix B7 with the indoor build |

## Decisions (decided 2026-11-16, all as recommended)

1. **The Ch2 Bakhawan trip.** Bakhawan is already a free Ch2 trip with nothing in it. Recommended: take "Can we go to Bakhawan?" out of Rose's Ch2 menu, so the first real visit is Chapter 4, and drop `_bakhawan_went` from autoplay's Ch2 "done". Keep and reuse the Ch2 walk cutscenes. Alternative: keep the trip and have Rose say Manong Ambo is away until "tomorrow".
2. **One big outdoor map or a separate beach scene.** **Default (not asked):** one map, extended north to 42 × 62 as the map plan draws it (gate → forest → river → beach → sea), so the walk-and-talk cutscenes never cut. The visitor-centre interior is optional and comes last.
3. **Who comes along.** **Decided:** **Jobert** comes on the trip (his "I used to fish there" in the brief pays off at the sunset scene); **Jonabel** stays home, and her existing reflection line moves to a short evening-home scene, as in Ch3.
4. **Fishing minigame now or later.** **Decided (changed 2026-11-18 in the line review):** fishing is a required quest step (q010) and the chapter ships with the real `fishing` panel, no quiz stand-in. Build the panel (wait for the bite, tap, name the catch in Akeanon from 2–3 choices, release it) using `habi_habi_panel.gd` as the model for a full-screen timed panel. Both pass and fail continue.
5. **Where Ambo greets.** **Decided:** outdoors at the bamboo trail gate (`Ch4/Ambo_Gate`), so all story scenes are outdoors and the indoor room stays optional.

## Build order

Each step leaves the game playable. Steps 1–2 can go in parallel with 3.

1. **Script pass on `chapter4.json`** (roadmap §2.3, §7.2)
   - `\` markers and `translation` on every Akeanon line; ids per §7.2 (`pamunit` missing; bank has `w139 magpamunit`).
   - s3 branch fix (1→3, 2→4, 3→5) with `rapport_delta` +2 / 0 / −2, then the `minigame_trigger` with pass and fail lines.
   - Add scene 0 (morning brief), scene 4b (planting a seedling, `tanom`), the sunset scene with Jobert, an evening-home beat with Jonabel, and `idle_pool_manong_ambo` (`anthropic-skills:idle-pool-append`).
   - Lines from the storyboard's "Lines to confirm" table go in as corrected there.
2. **Manong Ambo NPC**: walk sprite (asset needed; palette swap of `papaJobert_sprite.png` to start) and `scenes/entities/npc_Ambo.tscn` on `npc_generic.gd`, like `npc_Loleng.tscn`. 1–2 ambient visitors / KASAMA planters (random-guy sprites).
3. **The map** (`docs/CHAPTER4_MAP_PLAN.md` §5–7)
   - Placeholder tiles from `art_requests/bakhawan_sprites_template.png` into the tilesets; extend `bakhawan_outdoors` north; boardwalk with collision both sides; camera limits.
   - Markers `Ch4/Ambo_Gate`, `Ch4/S2_Platform`, `Ch4/S3_Pier`, `Ch4/S4_Shore`, `Ch4/S5_Cottage`, plus spawn markers for Jobert.
   - Examinables: KASAMA plaque, species sign, "Do not cut mangroves" sign.
4. **Getting there**
   - Decision 1: Ch2 menu change; `map_open_bakhawan` set in the Ch4 brief (fixes that part of B5).
   - `TourGuide.STOPS["bakhawan_outdoors.tscn"]` home cutscene for Ch4.
   - Walk cutscenes `chapter4_walk_to_bakhawan` (home → Pastrana → Bakhawan, with Jobert in the conga) and back. Copy the `chapter2_walk_*bakhawan*` ones.
5. **Level script** `bakhawan_outdoors.gd`: keep the Ch2 branch, add Ch4: arrival plays scene 1 at the gate; walking onto the S2 platform plays scene 2; the pier plays scene 3; the shore plays scene 4; then sunset scene 5.
6. **Cutscenes** `data/cutscenes/chapter4_*.json`: scene0 brief (`chapter_card`), arrive, scene1–5, walk home, evening home (sets `chapter4_complete`). Sunset: `DayNightManager` set to 17:30 for scene 5.
7. **Quests + keepsake**: q009 "Visit the Bakhawan Eco-Park: meet Manong Ambo", q010 "Go fishing with Manong Ambo", q011 "Plant a mangrove and go home" in `data/quest_data.json`; seedling keepsake through `RewardManager`.
8. **`fishing` minigame panel** (needed before the chapter ships, decision 4): `scripts/ui/fishing_panel.gd`, registered in `DialogueUI.MINIGAMES`, at scene 3 shot 3.8. Touch + keyboard.
9. **Challenges**: rename `data/challenges/chapter2.json` → `chapter4.json` and `ch2_*` → `ch4_*`; update `regions.json` and `ChallengeManager`; add `word_ids`.
10. **Tooling and release**
    - `page_dev.gd`: `CH4_START_FLAGS` (Ch3 done flags) and fix the "Ch4 — Bakhawan" warp to use them.
    - `autoplay.gd` `CHAPTERS[4]`: `start_level` `aklan_living.tscn`, `_setup_ch4`, `_done_ch4` (`chapter4_complete`).
    - `chapters.json` `"available": true`, then `/playtest chapter 4`.

## Flags (roadmap §8.1, adjusted)

`ch4_brief_pending` (schedule state), `chapter3_complete`, `chapter4_started`, `map_open_bakhawan`, `chapter4_going_bakhawan`, `chapter4_at_bakhawan`, `seen_chapter4_scene0..6`, `went_fishing`, `ch4_fishing_passed`, `planted_mangrove`, `story_done_ch4_ambo`, `chapter4_complete`.

## Done when

- A new game can reach Ch4 without the dev tab, and `/playtest chapter 4` and `/playtest full` finish with no new findings.
- Every Akeanon line has `\` markers, correct ids and a translation.
- The fishing activity works on touch and keyboard, and both pass and fail reach scene 4.
- The sunset lighting holds through scene 5; the seedling keepsake is in the Journal; `chapter4_complete` is set at home.
