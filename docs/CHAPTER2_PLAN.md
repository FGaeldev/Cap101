# Chapter 2 "Kalibo Town": implementation plan

Prepared 2026-11-16 from the working tree on `feature/chapter3` (last commit `410c0f6`) and `docs/STORY_ROADMAP.md` §6.2. Unlike Chapter 3, Chapter 2 is already **playable end to end**: arrival → sleep → Rose's tour (park → market → cathedral) → walk home → Sunday mass → sleep sets `chapter2_complete`. This plan is a **polish pass**: fix continuity, add the missing beats (evening home, quest, Pedring's idle lines, one hands-on activity), and get every Akeanon line checked.

## Where it stands

| Piece | State | Notes |
|---|---|---|
| Chapter entry | `data/chapters.json` `chapter2`, `"available": true` | |
| Dialogue | `data/dialogue/chapter2.json`: 15 scene keys, ~90 lines | `\` markers and most translations in place; Pedring's lines 2, 3, 8 and Susan's lines have no `translation`; no `remarks` (idle) block |
| Arrival + first night | `chapter2_scene0` (chapter card, conga in, door signs *bituon/buean/adlaw*) → bed sets `chapter2_slept` → `chapter2_scene0b` (Susan: "ask Rose") | no notebook/journal beat; scene 0b is two lines |
| The tour | Rose menu (`scene_rose_walk_to_park`) → `chapter2_scene1` park → `chapter2_park_meet_pedring` → `chapter2_park_to_market` → `chapter2_scene2` / `chapter2_market_talk` → `chapter2_tour_to_cathedral` → `chapter2_cathedral_talk` (scene 3 talk + scene 4 vocab round) → walk home | all built; levels `pastrana_outdoors` (cathedral exterior lives here, markers `S3/*`), `market_outdoors`/`market_indoors`, `cathedral_indoors` (mass only) |
| Vocab round (scene 4) | numbers 6–10 quiz, colours choice + swatch quiz, size words, *daya/haron/dato*, food words | **continuity break**: the food block says "walking toward the market… good thing we're heading to the market", but the market was visited an hour earlier (roadmap D4) |
| Sunday mass | `chapter2_sunday_mass` → `chapter2_mass_service` → `chapter2_mass_market` → home | sets `chapter2_mass_attended`; works |
| Free trips | Rose menu: park, Bakhawan (after tour), weavers (after Ch3) | Bakhawan is Ch4's place, open in Ch2 |
| End of chapter | `sleep_bed.gd` sets `chapter2_complete` on the first sleep after `chapter2_tour_done` + `chapter2_mass_attended` | **no evening beat after the tour**, no chapter close; Rose's cathedral line already names the piña trip days early |
| Manong Pedring | `npc_Pedring.tscn`, sprite, portrait ✅ | speaker string is `Anong Pedring`; no idle remarks |
| Activity | two quizzes in the vocab round | no hands-on activity at the market or the map (roadmap: `market_order`, `map_match`). Panels available: quiz, `phrase_builder`, memory match, hangman, crossword, word search, habi-habi |
| Quest | none | quests jump q004 → q006; **q005 "Explore Kalibo with Rose" missing** |
| Tooling | `autoplay.gd` `CHAPTERS[2]` ✅, `page_dev.gd` `CH2_START_FLAGS` + dev warps ✅ | |
| Open tracker bugs here | **B4** four warps with no target (`aklan_living`, `aklan_home_outdoors`, `market_outdoors`), **B5** Pastrana exits need `map_open_caticlan` / `map_open_bakhawan` | B1, B3, B9 fixed |

## Decisions to make first

**Decided 2026-11-16:** 1 → move the food words to the park → market walk; 2 → add the dinner scene; 3 → phrase builder at Pedring's; 4 → q005 and Pedring's idle lines. 5 (Bakhawan) left open as before.

1. **Fix the vocab-round continuity: move the food words to the park → market walk.** Recommended: a short beat inside `chapter2_park_to_market` (Rose names *isda, manok, itlog, humay…* as they pass stalls) so the market uses them. The souvenir-shop round keeps numbers, colours, size and pointing words. Cheaper alternative: rewrite the two narration lines to "on the way home, past the market" and leave the order.
2. **Add an evening-home scene after the tour (`scene_5_evening_home`).** Recommended: dinner in `aklan_living` when the tour walk home ends. Jonabel asks what the player saw, Susan mentions Sunday mass, Rose keeps the piña trip as a tease ("another day"). Moves Rose's "next place is the piña weavers" line out of the cathedral talk, so Ch3's brief owns it. Sets `chapter2_evening_seen`.
3. **One hands-on activity at the market: `phrase_builder` "Pangabay, gusto ko it daya".** Recommended: after Rose teaches *pangabay*, the player builds the request to Pedring (pass → he hands the star fruit; fail → Rose whispers it, Pedring smiles, story continues). Uses an existing panel, no new code. `map_match` (roadmap) stays a later, optional step.
4. **Quest q005 and Pedring's idle lines.** Recommended: add q005 "Explore Kalibo with Rose" (Park → Market → Cathedral → Go home → Sunday mass) and a `remarks` block for Pedring (3–4 lines, gated by `seen_chapter2_scene2`). Alternative: skip the quest; the Rose menu already guides the player.
5. **Bakhawan during Chapter 2.** Leave it open for now (recommended, the autoplay run and Ch4 plan rely on it) or gate it behind `chapter3_complete`. Not part of the storyboard either way.

## Build order

Each step leaves the game playable.

1. **Script pass on `chapter2.json`** (after the line review)
   - Apply the storyboard's corrected Akeanon; add missing `translation`s (Pedring 2, 3, 8; Susan cathedral line already has one).
   - Speaker name per the review (`Anong Pedring` vs `Manong Pedring`), everywhere incl. `npc_Pedring.tscn` and `character_portraits.tres`.
   - Vocab round: cut the food block (idx 13–16) per decision 1; fix narration idx 1 ("before leaving the cathedral grounds" stays).
   - Cathedral talk idx 8: move the piña line to scene 5 / Ch3.
2. **Food-words walk** (decision 1): new `scene_1b_food_words` dialogue + a dialogue step in `chapter2_park_to_market.json`, with a 3-question quiz (pass and fail both continue).
3. **Market activity** (decision 3): `phrase_builder` line in `scene_2_market_talk` between idx 3 and idx 4; pass/fail lines.
4. **Evening home** (decision 2): `chapter2_scene5.json` + `scene_5_evening_home`; trigger in `aklan_living.gd._check_beats()` on `chapter2_tour_done` and not `chapter2_evening_seen`, once Jonabel and Susan are home (same pattern as `chapter3_scene5`).
5. **Quest + remarks** (decision 4): q005 in `data/quest_data.json`; `remarks.pedring_*` in `chapter2.json`.
6. **Bugs** B4 and B5 (targets or remove; set `map_open_bakhawan` where the Bakhawan walk starts).
7. **Word bank** additions/fixes from the review; then `/playtest chapter 2` and `/playtest full`.

## Flags

Existing: `seen_chapter2_scene0`, `chapter2_slept`, `seen_chapter2_scene0b`, `chapter2_with_rose`, `seen_chapter2_scene1..4`, `map_open_market`, `chapter2_tour_done`, `chapter2_mass_went`, `chapter2_mass_attended`, `chapter2_complete`.
New: `seen_chapter2_scene1b`, `bought_star_fruit` (choice +2 path), `chapter2_evening_seen`, `quest_005_done`.

## Done when

- `/playtest chapter 2` and `/playtest full` finish with no new findings; B4 and B5 closed.
- Every Akeanon line has `\` markers, correct ids and a translation, and the ⚑ lines in the storyboard are all decided.
- The food words come before the market; the market activity passes and fails without blocking.
- The evening scene plays once after the tour; q005 completes on `chapter2_complete`.
