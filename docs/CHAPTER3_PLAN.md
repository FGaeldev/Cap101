# Chapter 3 "Threads of Piña": implementation plan

Prepared 2026-11-15 from the current code (commit `7b452d0`) and `docs/STORY_ROADMAP.md` §6.3. The roadmap's build sheet is still the story target; this file maps it onto what's actually in the repo now and orders the work.

## Where it stands

| Piece | State | Notes |
|---|---|---|
| Chapter entry | `data/chapters.json` has `chapter3`, `"available": false` | flip to `true` last |
| Dialogue | `data/dialogue/chapter3.json`: 4 scenes, 39 lines | routers fixed (`default: 1`); speaker is `Manang Loleng` everywhere; no `\` markers, no rapport deltas, no flags, gift unnamed, no minigame |
| Levels | `scenes/world/haboean/`: `habuean_outdoors`, `haboean_cafe`, `haboean_gallery` (gallery + loom loft) | built and warp-linked to each other and to Pastrana. Has markers for `Staff/Weaver`, `Staff/Curator`, `Looms/Loom1..5`, `Exhibits/*`, random NPC spots, café seats. No level scripts yet |
| Way in | Pastrana `WarpArea4` → Haboean, gated on `map_open_habuean` | nothing sets that flag (tracker B5); Rose's trip menu (`scene_rose_walk_to_park` in `chapter2.json`) has no Haboean option; `TourGuide.STOPS` has no Haboean entry |
| Manang Loleng | portrait `assets/sprites/portraits/loleng_art.png` only | **no walk sprite**, no `npc_Loleng.tscn`, no idle pool |
| Weaving activity | none | panels that exist: quiz, phrase builder, memory match, hangman, crossword, puzzle |
| Quest / keepsake | none | quests stop at q004; no bookmark keepsake; Jonabel has no bookmark line yet |
| End of Chapter 2 | no `chapter2_complete` flag anywhere | the tour ends with `chapter2_tour_done`, then free trips (park, market, Bakhawan) and Sunday mass |
| Tooling | `autoplay.gd` `CHAPTERS` has 1 and 2; `page_dev.gd` has no Ch3 flag list | |

## Decisions to make first

1. **Location: use the Haboean scenes.** The roadmap planned new `loom_house_exterior/interior` levels, but Haboean ("weaving place") is already built for this: outdoors = arrival, gallery loom loft = the loom scenes, café = Rose's vocab round. *Recommended.* Level-area name stays `haboean`.
2. **How Chapter 2 ends and Chapter 3 starts.** Recommended: Chapter 2 is complete once `chapter2_tour_done` and `chapter2_mass_went` are both set. The next morning, the `aklan_living` script plays a Ch3 morning brief (chapter card + Rose names the trip) that sets `chapter2_complete` and `chapter3_started`, and opens `map_open_habuean`. Alternative: just add "Can we see the weavers?" to Rose's trip menu after the tour, which is simpler but has no chapter beat.
3. **Weaving minigame now or later.** Recommended: ship the story with a stand-in (`memory_match` on Ch2 colours + hinay/paspas) at the insertion point, then build the real `weaving` panel (roadmap §5.4: Loleng calls a colour in Akeanon, tap the matching thread, three rows getting faster) as its own step. That way the chapter is playable end to end early.
4. **Bakhawan in Chapter 2.** Bakhawan (Chapter 4's location) is already a Ch2 trip. Leave it for now or gate it behind `chapter3_complete`? This affects the Ch2 autoplay run and the Ch4 story.

## Build order

Each step leaves the game playable. Steps 1–2 can go in parallel with 3.

1. **Script pass on `chapter3.json`** (roadmap §2.3, §7.2)
   - `\` markers and `translation` on every Akeanon line; check word ids against §7.2 (e.g. s4 idx 4 needs `tan-aw`, s4 idx 1 `panaw`, both missing from the bank).
   - `rapport_delta` +2 / 0 / −2 on the three choice lines (s1 idx 6, s2 idx 4, s4 idx 5).
   - s2: insert the `minigame_trigger` between the choice and idx 8, and route the "just watch" branch through it too.
   - s3: name the gift (piña bookmark) and set `got_pina_bookmark`.
   - Fix s4 idx 1 ("save that one") and idx 10 (leftover gap), and the "whose faster" typo.
   - Add a scene 0 (morning brief), scene 5 (evening home, Jonabel and the bookmark), and an `idle_pool_manang_loleng` (`anthropic-skills:idle-pool-append`).
   - Flag lines for a native-speaker check: "Naabi abi gid namon…", "Uwat kaso", "Hinay-hinay eang…".
2. **Manang Loleng NPC**: walk sprite (asset needed; a palette swap of `grandma_sprite.png` will do for now) and `scenes/entities/npc_Loleng.tscn` on `npc_generic.gd`, like `npc_Pedring.tscn`. Plus 2–3 weaver NPCs at the `Looms` markers (random-guy sprites are fine to start).
3. **Getting there**
   - Set `map_open_habuean` on the first arrival with Rose (scene 1), so the player can walk there alone afterwards (see "Going out alone" below).
   - Add a Haboean stop to `TourGuide.STOPS` (home cutscene + "The park" option) and a Rose menu option gated on `chapter3_started`.
   - Walk cutscenes: home → Pastrana → `habuean_outdoors`, and back home. Copy the `chapter2_walk_*bakhawan*` ones.
4. **Level scripts** `scripts/game_scenes/haboean_*.gd`, following `market_indoors.gd`/`cathedral_indoors.gd`: arrival plays scene 1 at the Weaver marker. In the gallery, loom interactables play scene 2 then scene 3. In the café, Rose plays scene 4. Optional 1b: examine plant → fibre → thread → loom as a `Comp_WorldTask` (`task_pina_process`).
5. **Cutscenes** `data/cutscenes/chapter3_*.json`: scene0 brief (with `{"type": "chapter_card", "chapter": "chapter3"}`), scene1–4, scene5 evening home (sets `chapter3_complete`).
6. **Quest + keepsake**: q006 "Visit the piña weavers" (Meet Manang Loleng → Try the loom → Go home) in `data/quest_data.json`; bookmark keepsake through `RewardManager`, shown in the Journal; Jonabel's bookmark idle line gated on `got_pina_bookmark`.
7. **Loom minigame**: done as Habi-Habi (`scripts/ui/habi_habi_panel.gd`, see below). A first colour-tapping `weaving` panel was built and then removed in its favour.
8. **Tooling and release**
   - `page_dev.gd`: `CH3_START_FLAGS` and dev warps for the three Haboean scenes.
   - `autoplay.gd` `CHAPTERS[3]`: `start_level` `aklan_living.tscn`, `_setup_ch3` (Ch2 done flags), `_done_ch3` (`chapter3_complete`).
   - `chapters.json` `"available": true`, then `/playtest chapter 3`.

## Habi-Habi (replay activity at Loleng's loom)

Built 2026-11-16 (`scripts/ui/habi_habi_panel.gd`, minigame type `habi_habi`). A word-forming game in the spirit of letter-grid games, reshaped to fit the chapter's "slow is a skill" theme. It is also the story loom in scene 2 (the six colour words), replacing the earlier colour-tapping `weaving` panel, which is no longer used.

- **Loleng calls, you spell.** She calls a word, shown the whole time in Akeanon with its English meaning. The player traces its letters on a 5×5 grid of thread-spool tiles (8-direction adjacency). Only her word counts, so no open dictionary is needed.
- **Hinay to paspas by time.** Three stages of 3 words each, with 13, 10 and 8 seconds per word (the shuttle crossing the loom). Running out of time weaves a crooked grey row and lights the answer on the grid. The game always moves on.
- **The trace is the thread.** Each spelled word weaves one row of cloth in its colour (colour words in their own colour). Its tiles drop out and new letters fall in. The next word is always made spellable.
- **Input:** drag and release; tap letter by letter and tap the last again (or Weave); tap the previous letter to step back; type the word and press Enter.
- **Outcome:** passes with 60% clean rows. A fully clean cloth sets `habi_habi_clean_cloth`, ready to unlock a woven design for the Journal keepsakes. Each woven word is +1 mastery.
- **Between stages** Loleng says "Dasigi it sangkiri." then "Paspas!".
- **Where:** in scene 2 at the loom (colour words), and once `story_done_ch3_loleng` is set, talking to Loleng in the gallery offers it (`scene_loleng_habi_habi`, replays every time). Getting back to Haboean after Chapter 3 still needs Rose's revisit menu.

All numbers (stages, seconds, words, pass ratio, grid size, word pool and colours) live in the dialogue line, not the code.

## Going out alone (built 2026-11-16)

Once Rose has taken the player somewhere, they can walk there on their own.

- **Street → Pastrana** opens when `chapter2_tour_done` is set (was `chapter2_with_rose`), with an 8 PM–6 AM curfew ("It's late. I should stay home."). Curfew is a new `curfew_hour` export on `comp_warp.gd`.
- **Pastrana gates** keep their `map_open_*` flags, now each set on the first visit with Rose: market (market talk), Haboean (`chapter3_scene1`), Bakhawan (`chapter2_walk_into_bakhawan`). Blocked message: "I haven't been there yet. I should ask Rose."
- Level scripts only play story when `chapter2_with_rose` is set, so solo visits never trigger or skip story. Loleng's Habi-Habi is reachable alone after Chapter 3.
- Rose's revisit trip ("Can we go to the weavers?") stays as the escorted option.

## Flags (roadmap §8.1, adjusted)

`chapter2_complete`, `chapter3_started`, `map_open_habuean`, `seen_chapter3_scene0..5`, `task_pina_process` (optional), `wove_first_row`, `got_pina_bookmark`, `story_done_ch3_loleng`, `chapter3_complete`.

## Done when

- A new game can reach Ch3 without the dev tab, and `/playtest chapter 3` and `/playtest full` finish with no new findings.
- Every Akeanon line has `\` markers, correct ids and a translation.
- The weaving activity works on touch and keyboard, and both pass and fail continue the story.
- q006 completes, the bookmark is in the Journal, and Jonabel's bookmark line only shows after it.
