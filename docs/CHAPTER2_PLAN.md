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
| Picture bubbles / emotes | none | the storyboard shows objects and feelings as picture bubbles over characters (decided 2026-11-16); the only bubble today is `word_popup.gd` (tapped words), and `RewardManager` pops up stars, badges, stamps and memory pages only |
| Quest | none | quests jump q004 → q006; **q005 "Explore Kalibo with Rose" missing** |
| Tooling | `autoplay.gd` `CHAPTERS[2]` ✅, `page_dev.gd` `CH2_START_FLAGS` + dev warps ✅ | |
| Open tracker bugs here | **B4** four warps with no target (`aklan_living`, `aklan_home_outdoors`, `market_outdoors`), **B5** Pastrana exits need `map_open_caticlan` / `map_open_bakhawan` | B1, B3, B9 fixed |

## Decisions to make first

**Decided 2026-11-16:** 1 → move the food words to the park → market walk; 2 → add the dinner scene; 3 → phrase builder at Pedring's; 4 → q005 and Pedring's idle lines. 5 (Bakhawan) left open as before.

1. **Fix the vocab-round continuity: move the food words to the park → market walk.** Recommended: a short beat inside `chapter2_park_to_market` (Rose names *isda, manok, itlog, bugas…* as they pass stalls) so the market uses them. The souvenir-shop round keeps numbers, colours, size and pointing words. Cheaper alternative: rewrite the two narration lines to "on the way home, past the market" and leave the order.
2. **Add an evening-home scene after the tour (`scene_5_evening_home`).** Recommended: dinner in `aklan_living` when the tour walk home ends. Jonabel asks what the player saw, Susan mentions Sunday mass, Rose keeps the piña trip as a tease ("another day"). Moves Rose's "next place is the piña weavers" line out of the cathedral talk, so Ch3's brief owns it. Sets `chapter2_evening_seen`.
3. **One hands-on activity at the market: `phrase_builder` "Pangabay it daya, Nong, ho" (corrected in the review).** Recommended: after Rose teaches *pangabay*, the player builds the request to Pedring (pass → he hands the star fruit; fail → Rose whispers it, Pedring smiles, story continues). Uses an existing panel, no new code. `map_match` (roadmap) stays a later, optional step.
4. **Quest q005 and Pedring's idle lines.** Recommended: add q005 "Explore Kalibo with Rose" (Park → Market → Cathedral → Go home → Sunday mass) and a `remarks` block for Pedring (3–4 lines, gated by `seen_chapter2_scene2`). Alternative: skip the quest; the Rose menu already guides the player.
5. **Bakhawan during Chapter 2.** Leave it open for now (recommended, the autoplay run and Ch4 plan rely on it) or gate it behind `chapter3_complete`. Not part of the storyboard either way.

## Build order

Each step leaves the game playable.

**Progress 2026-11-18:** step 2 done (picture bubbles: `scripts/autoload/PictureBubbles.gd`, `bubble` / `bubble_on` on dialogue lines, a list advances with each `\` word as it types, `bubble` cutscene action; icons are 16 px, not 24, so the bubble stays close to the 16 px sprites at zoom 2; `assets/ui/bubble_icons.png` has 28 pixel-art icons in one style, built by `art_requests/tools/make_bubble_icons.js` from editable pixel maps (preview: `art_requests/bubble_icons_preview.png`), cells named in `data/bubble_icons.json`; 16 Chapter 2 lines tagged; the playtest checker flags unknown icon names).

**Progress 2026-11-17:** step 1 done, step 3 done, step 4 done (phrase builder *Pangabay it daya, Nong, ho* at `scene_2_market_talk` idx 13–16; one check, pass → Pedring "Abaw! Batian mo to, apo?", fail → Rose whispers it; both reach "…What is it, anyway?"), step 5 done (dinner `chapter2_scene5` + `scene_5_evening_home` with the days-of-the-week quiz; plays once in the 6–7 PM block when Rose, Susan, Jonabel and Jobert are at the dining seats, `aklan_living.gd._dinner_due()`; the four sit on `Seats/Dining*`, the player stands at `SceneMarkers/S5/Player` at the foot of the table, since there are only four chairs; autoplay now stops at 6 PM on the tour day to cover it), step 6 done (q005 is a chain of six one-step quests like Ch3's q006–q008: q005 ask Rose → q011 park → q012 market → q013 cathedral → q014 dinner → q015 Sunday mass, each completed by `complete_quest` in its cutscene and gated with `unless_flag` so saves already past that point never see it; Pedring's four `remarks` in `chapter2.json`, one per talk), step 7 done (B4: new `closed_message` on `comp_warp.gd` makes a target-less door a wall with its own line, set on the CR door, the home's west road, the market's east street and the Bakhawan visitor center; B5: Bakhawan's gate was already set by its first walk, and Pastrana's Caticlan exit is a closed door until Chapter 6, which should restore `target_scene` caticlan_outdoors.tscn, spawn `FromPastrana` and gate `map_open_caticlan`), and the word-bank part of step 8 done (31 new words `w291`–`w321`, verified from the review; fixes to `w080` humay, `w038` berde, `w084` imaw, `w256` haron). Not yet in step 1: the dinner days-of-the-week beat (it belongs to step 5), Jonabel's window beat 0.8 and Pedring walking off at 1.11 (both need cutscene staging). The step-3 hook is in `chapter2_walk_market_street.json`, not `chapter2_park_to_market.json`: Rose stops at `Spawns/FromHall` by the hall door, and the beat plays once via a new `unless_flag` step gate in `CutsceneManager`.

1. **Script pass on `chapter2.json`** (after the line review)
   - Apply the storyboard's corrected Akeanon; add missing `translation`s (Pedring 2, 3, 8; Susan cathedral line already has one).
   - Final lines are in `docs/CHAPTER2_STORYBOARD.md` ("Lines to confirm", all decided 2026-11-16).
   - Speaker `Anong Pedring` → `Nong Pedring` everywhere: `chapter2.json` (10), `chapter3.json` (2), `npc_Pedring.tscn`, `character_portraits.tres`, cutscene actor ids.
   - Chapter 3 follow-ons from the review: Loleng's "Mag-dahan kamo sa biyahe" → "Magdahan…", "samitan mag ubra" → "mag-ubra".
   - Days-of-the-week beat at dinner (storyboard 5.12a–g) with its own quiz.
   - Vocab round: cut the food block (idx 13–16) per decision 1; fix narration idx 1 ("before leaving the cathedral grounds" stays).
   - Cathedral talk idx 8: move the piña line to scene 5 / Ch3.
2. **Picture bubbles** (storyboard section "Picture bubbles")
   - Code: a `bubble` field on dialogue lines (one icon, or a list that advances with each `\` word as the typewriter reaches it), `bubble_on` to put it over another actor, and a `bubble` cutscene action (`actor`, `icon`, `seconds`) for silent beats. Style it like `word_popup.gd` (dialogue-box texture and tail).
   - Test first with one icon: does a 24 px drawing read on a phone over 16 px sprites? If not, 32 px or 2× scale.
   - Art: `assets/ui/bubble_icons.png` + an id → cell map. Chapter 2 needs 23 icons: star, moon, sun, map, bell, calendar, star fruit; fish, chicken, egg, rice sack, bread, meat, pig; swatch (tinted from `word_colors`), small basket, big basket, thumbs up, shiny keychain, faded keychain; `!`, `?`, `zzz`.
   - Optional: an `icon` field on word-bank entries, for reuse in the dictionary, Journal and picture quizzes later.
   - Without it everything still plays; only the pictures are missing. So it can land before or after steps 3–6.
3. **Food-words walk** (decision 1): new `scene_1b_food_words` dialogue + a dialogue step in `chapter2_park_to_market.json`, with a 3-question quiz (pass and fail both continue).
4. **Market activity** (decision 3): `phrase_builder` line in `scene_2_market_talk` between idx 3 and idx 4; pass/fail lines.
5. **Evening home** (decision 2): `chapter2_scene5.json` + `scene_5_evening_home`; trigger in `aklan_living.gd._check_beats()` on `chapter2_tour_done` and not `chapter2_evening_seen`, once Jonabel and Susan are home (same pattern as `chapter3_scene5`).
6. **Quest + remarks** (decision 4): q005 in `data/quest_data.json`; `remarks.pedring_*` in `chapter2.json`.
7. **Bugs** B4 and B5 (targets or remove; set `map_open_bakhawan` where the Bakhawan walk starts).
8. **Word bank** additions/fixes from the review; then `/playtest chapter 2` and `/playtest full`.

## Flags

Existing: `seen_chapter2_scene0`, `chapter2_slept`, `seen_chapter2_scene0b`, `chapter2_with_rose`, `seen_chapter2_scene1..4`, `map_open_market`, `chapter2_tour_done`, `chapter2_mass_went`, `chapter2_mass_attended`, `chapter2_complete`.
New: `seen_chapter2_scene1b`, `bought_star_fruit` (choice +2 path), `chapter2_evening_seen`, `quest_005_done`.

## Done when

- `/playtest chapter 2` and `/playtest full` finish with no new findings; B4 and B5 closed.
- Every Akeanon line has `\` markers, correct ids and a translation, and the ⚑ lines in the storyboard are all decided.
- The food words come before the market; the market activity passes and fails without blocking.
- The evening scene plays once after the tour; q005 completes on `chapter2_complete`.
