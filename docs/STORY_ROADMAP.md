# Story Roadmap: BueotHambaeon (Cap101), Chapters 1–6

_Written 2026-10-25 against `main` @ `f1a98ec` plus the current uncommitted working tree (day/night, calendar, lights)._

This roadmap covers building the **whole story** from the six dialogue files in `data/dialogue/` into a playable game, from the US living room to the Boracay finale. It sits alongside [SYSTEMS_IMPROVEMENT_PLAN.md](SYSTEMS_IMPROVEMENT_PLAN.md). That plan fixes the engine; this one ships the content. Where a story step depends on a systems item, it's cited as **SIP x.y**.

How to read it:
- **§1–3**: what the story is and where it stands today, including every defect I found in the data.
- **§4**: decisions to lock before building (each has a recommendation).
- **§5**: engine features the script needs that don't exist yet.
- **§6**: chapter-by-chapter build sheets. This is the bulk.
- **§7–10**: cross-cutting work (vocabulary, flags, assets, QA).
- **§11**: milestones and order.

---

## 1. The story at a glance

**Premise.** Lola Jonabel, living in the US, is homesick for Aklan. The player (her grandchild, a _balikbayan_ who doesn't speak Akeanon) goes back with her and Papa Jobert. In Kalibo they meet Lola Susan and her granddaughter **Rose**, a sharp-tongued cousin who reluctantly agrees to teach the player Akeanon. Over a series of field trips (town, piña weaving, mangroves, Ati-Atihan, Boracay) the player learns the language and the culture, and Rose slowly warms up.

**Emotional throughline.** Jonabel's longing becomes peace ("coming home means never really leaving"). Rose goes from "don't expect me to go easy on you" to "text me when you land." The player goes from outsider (_bisita_, _turista_) to someone who belongs (_balikbayan_, "bukon ka eon outsider").

| Ch | Title (working) | Location(s) | New cast | Vocabulary domain | Learning activities in the script |
|---|---|---|---|---|---|
| 1 | Homesick | US home → Kalibo Int'l Airport → parking lot | Lola Jonabel, Papa Jobert, Lola Susan, Rose | Greetings, pronouns, numbers 1–5 | phrase builder ×2, quiz ×2, memory match ×2 |
| 2 | Kalibo Town | Aklan home, Pastrana Park, Public Market, Cathedral (+ souvenir shop) | Anong Pedring | Places, food, numbers 6–10, colors, size/age adjectives, demonstratives, "please" | **none** (choices only) |
| 3 | Threads of Piña | Piña loom house | Manang/Anang Loleng | Verbs (buy, sell, speak, answer, rise), pace/size adjectives | **none** |
| 4 | Roots of Bakhawan | Bakhawan Eco-Park | Manong/Anong Ambo | Nature (shore, water, soil, sand), qualities, nature verbs | **none** |
| 5 | Hala Bira! (Ati-Atihan) | Festival grounds and parade route | Kapitan Julian | Festival words, people (person, visitor, balikbayan) | **none** |
| 6 | Homeward | Caticlan jetty → boat → Boracay White Beach | Tita Beth | Travel and tourism | **none** |

Every chapter follows the same five-beat shape: **arrive → learn the place → do a hands-on thing → Rose's vocabulary round → reflect.** The build sheets in §6 lean on that so each chapter is a template plus content, not a one-off.

---

## 2. Where it stands today

### 2.1 Readiness matrix

| | Ch1 | Ch2 | Ch3 | Ch4 | Ch5 | Ch6 |
|---|---|---|---|---|---|---|
| Dialogue JSON | ✅ full, branching | ✅ full (scene 0 is a stub) | ⚠ thin, broken router | ⚠ very thin, broken router | ⚠ very thin, broken router | ⚠ very thin, broken router |
| `\word` highlight markers | ✅ | ✅ | ❌ none | ❌ none | ❌ none | ❌ none |
| `word_ids` correct | mostly | mostly | ❌ wrong ids | ❌ wrong ids | ❌ wrong ids | ❌ wrong ids |
| Translations on Akeanon lines | ✅ | ✅ | partial | partial | partial | partial |
| Rapport deltas on choices | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Cutscenes | ✅ 5 files | scene 0 only | ❌ | ❌ | ❌ | ❌ |
| Levels (`.tscn`) | ✅ 4 | home ✅ (7 rooms), town ❌ | ❌ | shells only (1 node each) | ❌ | ❌ |
| NPC scenes | ✅ 4 | Pedring ❌ | Loleng ❌ | Ambo ❌ | Julian ❌ | Beth ❌ |
| Portraits | Jonabel, Jobert only | ❌ | ❌ | ❌ | ❌ | ❌ |
| Quests | q002–q004 | ❌ | ❌ | ❌ | ❌ | ❌ |
| Hands-on activity | ✅ | ❌ | ❌ loom | ❌ fishing | ❌ chant | ❌ souvenir |
| Playable end to end | ✅ (with bugs below) | only scene 0 | ❌ | ❌ | ❌ | ❌ |

### 2.2 Blocking defects (fix before anything else)

> **Status 2026-10-25: all three fixed in the working tree** (not yet play-tested in Godot). Routers are now `default: 1`. `Comp_Dialogue` supports `set_flag` and `check_flag`/`check_flag_next`. The Ch3–6 ids are corrected per §7.2. Placeholder ids on lines that don't contain the word were cleared rather than guessed, and idle "Magtuon ka gid" is now tagged `w142`. The words §7.2 lists as **missing** are still untagged until they're added to the bank.

1. **The Ch3–6 start routers point at themselves.** Every scene in `chapter3.json`–`chapter6.json` opens with `"start_index_if_flag": {"default": 0}`. `Comp_Dialogue._resolve_start_router()` (`scripts/components/Comp_Dialogue.gd:59`) detects the self-loop, calls `push_error` and **ends the dialogue before the first line**. All 21 of those scenes are currently unplayable. Fix: `"default": 1` everywhere.
2. **The dialogue keys `set_flag` and `check_flag` / `check_flag_next` aren't implemented.** Ch1 scene 4 uses them (`data/dialogue/chapter1.json:718`, `:786`) to send the numbers-refresher path to "Do you want to play again?" (index 36). Nothing in `scripts/` reads either key, so the refresher always falls through to index 31 and index 36 is unreachable. Fix: implement both in `Comp_Dialogue` (§5.1), or rewrite the line as a router.
3. **The Ch3–6 `word_ids` are placeholders.** The ids `w128`–`w137` are reused across chapters for unrelated words. For example, Ch4's "baybay, tubi, eugta, baeas" is tagged `w128 mabahoe, w129 mabakae, w130 mabuot, w131 madali`. Exposure, mastery, the dictionary and the review quiz would all teach the wrong words. The correct ids are in §7.2.

### 2.3 Content defects by chapter

**Chapter 1** (`data/dialogue/chapter1.json`)
| Where | Issue | Fix |
|---|---|---|
| scene 4, idx 16 (`:633`) | Choosing "Later, keep going for now" gets the reply "That's what I like to hear." | Change the text to something like "Alright, we'll review later." |
| scene 4, idx 25 (`:736`) | Speaker is `Player`, but the line is Rose's ("Ok I'll teach you one(1) to five(5)"). | Speaker → Rose. |
| scene 4, idx 21 | The "Wow! You know more than I thought." path ends with `next: null`, which skips "Let's go home." | `next: 35`. |
| scene 4, idx 14 / 18 | `word_ids` don't match the text (`w210` sanda on "a few more words"; `w033` balikbayan on "count to five"). | Clear them. |
| scene 4, idx 36 | Typo "agin". The choice labels "No\n" have a trailing newline. | Fix. |
| scene 3, idx 3 | Rose says "Lola Susan is asking if you are [Player]" right after Susan has already said "ikaw siguro si [Player]". Lines 3–5 read out of order. | Reorder to Susan's question → Rose interprets → Player answers. |
| scene 1, idx 4 | `w147` (makauli) is tagged on a line that doesn't contain it. | Remove it. |
| idle `lola_jonabel.med[0]` (`:863`) | "Don't forget to write to your Lola back home", but Jonabel **is** the Lola and she's here. | Rewrite (for example, "write to your Mama back home"). |
| `scene_0_on_game_start` | "Is Lola Jonabel still watching TV" fits, but it's the only bedroom line. | Fine as is. Optionally add a notebook examine line. |

**Chapter 2** (`data/dialogue/chapter2.json`)
| Where | Issue | Fix |
|---|---|---|
| scene 4 (`:512`, `:534`) | The vocab round happens "before leaving the cathedral grounds… walking toward the market", but the market was scene 2. Continuity break. | See decision **D4**. |
| scene 1 | Rose calls him "Anong Pedring". The idle pools (Rose, Lola Susan) call him "Manong Pedring". | See decision **D3**. |
| scene 0 | One line ("Welcome home everyone!"). There's no setup for tomorrow's town walk. | Expand (§6.2). |
| all scenes | No learning activity. The chapter is pure reading. | Add the activities in §6.2. |

**Chapter 3** (`data/dialogue/chapter3.json`)
| Where | Issue | Fix |
|---|---|---|
| all | Speaker is `Manang Loleng` on line 1 and `Anang Loleng` everywhere else. That gives two portraits and two rapport keys. | **D3**. |
| scene 1, idx 6 | The three reaction choices have no `rapport_delta`. | Add +2 / 0 / −2. |
| scene 2, idx 4→8 | The player picks how to try weaving, and then line 8 praises a result that never happened. | Insert the weaving minigame between the choice and idx 8 (§5.4). |
| scene 2, idx 6 | The "I'll just watch" branch → Rose's taunt → praise for weaving the player didn't do. | Route it through the minigame too (gently: "at least one row"). |
| scene 3 | The gift ("tanda") is never named. Jonabel's Ch3 and Ch6 idle lines say it's a **bookmark**. | Name it and grant a keepsake (§5.6). |
| scene 4, idx 1 | "panaw — to walk… wait, save that one" is a dangling joke, and _panaw_ isn't in the word bank. | Keep it and add the word, or cut it. |
| scene 4, idx 10 | "Maugan — light, not bug-at.  — small words…" has a leftover gap where a word was deleted. | Fix the text. |

**Chapter 4** (`data/dialogue/chapter4.json`)
| Where | Issue | Fix |
|---|---|---|
| all | `Manong Ambo` on scene 1 and in the idle pool, `Anong Ambo` everywhere else. | **D3**. |
| scene 3, idx 2 | Choices 1 ("Yes") and 2 ("Maybe later, just watch") both go to idx 3 ("Mayad! sunod kakon"). Choice 3 goes to idx 4 ("Watching teaches too"). Idx 5 (Rose, "You'll miss out") can't be reached. | 1→3, 2→4, 3→5. Then add the fishing minigame (§5.4). |
| scene 5 | Jonabel and Jobert speak, but nothing puts them at the eco-park. | Spawn them in the scene 5 cutscene. |
| idle `manong_ambo.med[1]` (`:217`) | The translation field contains an editorial note: `[NEW-VERIFY: soft reference to Boracay…]`. | Remove it once verified. |

**Chapter 5** (`data/dialogue/chapter5.json`)
| Where | Issue | Fix |
|---|---|---|
| scene 3, idx 2 | Same branch bug as Ch4. Choices 1 and 2 → idx 3, choice 3 → idx 4 ("Even a little effort counts", which is the reply to choice 2), and idx 5 can't be reached. | 1→3, 2→4, 3→5. Add the call-and-response activity. |
| scene 5, idx 1 | Contains Tagalog "hindi" and "Mingko unga ako uman" (verify the spelling). | Native review. |
| content | The festival's Ati origins are never mentioned. Ati-Atihan honours the Ati people. | **D6**. |
| idle `kapitan_julian.med[0]` | "Ni, practice pa lang" says this is a rehearsal, but scene 1 presents it as the real festival. | **D1**. |

**Chapter 6** (`data/dialogue/chapter6.json`)
| Where | Issue | Fix |
|---|---|---|
| idle `rose.high[-1]` (`:584`) | "Summary — full script status (amended, vocab-sequenced)" is a leaked authoring note **in player-visible text**. | Delete it. |
| scene 5 | Rose's line "And worth every word you've learned, balikbayan." duplicates Ch5 scene 5 word for word. | Rewrite one of them. |
| scene 5 | The finale ends on Tita Beth. There's no epilogue, no credits and no farewell to Lola Susan and Rose. | §6.6 epilogue. |

**All idle pools (Ch1–6).** Many lines are in Tagalog or Hiligaynon rather than Akeanon (for example "Kung pagod ka na, Apo, sabihin mo lang…", "Wag mo akong tignan nang ganyan…"). Several narration lines (`speaker: ""`) are first person ("Kadugay ko na di nakatilaw…"). The pools are also copy-pasted cumulatively from chapter to chapter, so Ch6 Rose repeats every earlier line. They need a language pass (§7.4) and a per-chapter de-duplication.

### 2.4 Systems plan status (spot check, verify before relying on it)
- SIP 1.1 (Talk disabled) **looks done**: Talk is built and wired in `DialogueUI.gd:117`.
- SIP 1.4 (cutscene run token) **looks done**: `CutsceneManager` has `current_run()`, `is_run_current()` and `track_tween()`.
- Not started: SIP 2.4 validator, 3.1 NPC consolidation, 3.3 stable ids, 3.4 LevelRoot, 3.6 labeled dialogue, 4.5 map unlock flags.

---

## 3. Inventory: what can be reused

| Asset / system | Reuse for |
|---|---|
| Cutscene actions (camera, move, conga, spawn/despawn, fade, load_scene, set_flag, set_visible, dialogue, parallel/sequence) | Every chapter's arrival, walk-and-talk, and exit. `conga` handles the "family follows Rose" pattern used in every chapter. |
| Dialogue line types: dialogue, choices (+rapport/patience), phrase_builder, quiz (static and dynamic), minigame_trigger (`memory_match`), start_router, patience_branch, set_flag_on_enter | All vocabulary rounds and conversations. |
| `puzzle_panel`, `quiz_panel`, `phrase_builder`, `memory_match_panel` | Vocabulary rounds; market ordering; map matching. |
| `ChallengeManager` + `data/challenges/chapter2.json` (bakhaw / tuon gates, `unlock_target: bakhawan_ecopark`) | **Ch4** gates. The file is named "chapter2" but its content is the Bakhawan chapter. Rename it to `chapter4.json` (§6.4). |
| `RewardManager` reward keys `stars`, `badge`, `stamp`, `memory_page`, `hint_tokens` | Keepsakes (§5.6), with one passport stamp per location. |
| `DayNightManager` + `GameState.START_DATE` + `calendar_events.json` (Ati-Atihan = 3rd Sunday of Jan) | Day-per-chapter pacing (§5.2) and lining up the festival (D1). |
| `Comp_WorldTask` / `TaskManager` (test data only) | "Talk to X, then Y" objectives, such as greeting three vendors at the market. |
| `field_notes`, `examinable_object` | Optional lore pickups (signs, plaques, the cathedral map). |
| Tilesets: `Aklan_Home_Indoors`, `Bakhawan_Tiles`, `Bakhawan_tree`, `AirportWall`; `assets/pastrana/pastrana_outdoors.aseprite` | Ch2 Pastrana Park and Ch4 eco-park art are already started. |
| Sprites: player, grandma (Jonabel), Lola Susan, Papa Jobert, Rose | The core cast is done. Five new NPCs are needed (§9). |
| Dev tab warps and cutscene list (`page_dev.gd`) | Extend with one entry per chapter and scene as they land. |

---

## 4. Decisions to lock first

Each one blocks writing or level work. I've put my recommendation first.

| # | Decision | Options | Recommendation |
|---|---|---|---|
| **D1** | **Timeline vs Ati-Atihan.** `START_DATE` is 2026-11-15, and the festival is the 3rd Sunday of January. | **A.** Move `START_DATE` to **2027-01-10 (Sun)**: Ch1 Jan 10, Ch2 Jan 11, Ch3 Jan 12, Ch4 Jan 13, free/review days Jan 14–16, **Ch5 Jan 17 (festival Sunday)**, Ch6 Jan 18–19. **B.** Keep November and make Ch5 a rehearsal (matches Julian's "practice pa lang" idle line), with the real festival as a post-game bonus. | **A.** The calendar page then shows the festival coming, Rose's Ch2 "wait until festival season" pays off in-world, and Ch5 can be the real thing. Rewrite Julian's idle line. (`START_DATE` isn't committed yet, so changing it is free.) |
| **D2** | **World structure.** | **A.** The Aklan home is the hub. Each chapter is one day: wake up → morning brief → travel → location → return → evening reflection → sleep. **B.** A linear chain of scenes with no return home. | **A.** It reuses the seven home rooms already built, gives idle pools somewhere to live, and gives the calendar/day-night system a purpose. |
| **D3** | **Honorific consistency.** Pedring, Loleng and Ambo each appear under two names (Anong/Manong, Anang/Manang). The speaker string is also the portrait and rapport key (SIP 3.3). | One display name per character. Use **Anong/Anang** (the Akeanon forms Rose uses on screen) in dialogue, and accept Manong/Manang only as in-text variants. | Do **SIP 3.3 stable ids first** (`anong_pedring`, `anang_loleng`, `anong_ambo`), so the display name can change later without breaking saves. |
| **D4** | **The Ch2 scene 4 continuity break.** | **A.** Split scene 4: the food words move into a short "walking to the market" round between scenes 1 and 2, and numbers/colors/adjectives stay at the cathedral souvenir shop. **B.** Rewrite the two transition lines so the group is "heading home past the market". | **A.** Teaching food words right before the market gives them an immediate use, which is the game's whole pedagogy ("use it or lose it"). |
| **D5** | **Ending.** | **A.** An epilogue back in the US bedroom: the notebook (Book UI) shows the trip summary, Rose texts, credits. **B.** End on Boracay with credits. | **A.** It mirrors the Ch1 opening (bedroom, notebook) and pays off Rose's "text me when you land." Flavour text varies with Rose's rapport tier. All endings are warm, because the game has a no-punishment rule. |
| **D6** | **Ati-Atihan cultural sensitivity.** The festival honours the Ati and Sto. Niño devotion, and traditionally involves soot face/body paint. | Don't put the player in face paint. Add a respectful line (Julian or Lola Susan) on the festival's Ati origins. Keep the chant to a widely used, non-sacred street cheer, as the script already intends. | Have a cultural consultant review the Ch5 script and art before art production starts. |
| **D7** | **Map regions vs story locations.** `regions.json` lists placeholder regions that aren't in the story (`leaf_weaving`, `pottery`, `abaca`, `farming`, `bonus`, `puzzle_test`). | Replace them with the story locations: `kalibo_town` (park, market, cathedral), `pina_loom`, `bakhawan_ecopark`, `festival`, `caticlan_port`, `boracay`. Each is unlocked by a story flag (SIP 4.5). | Do it as part of M1 (§11). Remove or hide `puzzle_test` from release builds. |
| **D8** | **Rapport in Ch3–6.** | Add `rapport_delta` (+2 / 0 / −2) to every 3-option choice, following the Ch1–2 pattern. | Yes. Rapport drives the idle tiers and the epilogue variant. |
| **D9** | **Language source of truth.** Only **1 of 247** words in the bank is `verified: true`. | Every new or changed Akeanon line and gloss gets reviewed by a native speaker before it ships. Nothing is invented (this is also the rule in the project's script-conversion skills). | Set up a review sheet (§7.4) and block each chapter's "done" on it. |

---

## 5. Engine features the story needs

These are new or extended systems. Each is sized XS–L. Do them in M1 unless noted.

### 5.1 Dialogue: flag operations on lines (XS) — fixes blocker 2.2-2
- `set_flag: {flag, value}`: set when the line is shown (generalises `set_flag_on_enter`, which only sets `true`).
- `check_flag: "<flag>"` + `check_flag_next: <idx>`: on advance, go to `check_flag_next` if the flag is set, otherwise to `next`.
- Also allow `requires_flag` on **choices**, to hide an option (for example, "Show Rose the bookmark" only if `got_pina_bookmark`).
- Add the keys to the validator (SIP 2.4).

### 5.2 Day and chapter progression (M)
- `GameState.current_chapter: int` (an additive save field), set by a `chapterN_start` cutscene step.
- **Sleep to advance:** interacting with the player's Aklan bed (`aklan_BR_Player.tscn`) is allowed only when `chapterN_complete` is set and `chapterN+1` hasn't started. It fades out, the date goes forward one day, the clock is set to 07:00, and the next chapter's morning cutscene runs. Before the chapter is complete, the bed gives a friendly "Not tired yet" line.
- **Morning brief** in `aklan_living`: Rose and Lola Susan tell you today's destination, and the quest starts.
- **Evening return** (a load_scene back to `aklan_living` at 18:00+): a family reflection line, a journal entry, and "go to bed" quest objectives.
- **Title card UI** ("Chapter 3: Threads of Piña", with the date) shown at the start of each chapter. Small scene with a fade in and out.
- Pause `DayNightManager` during cutscenes and story beats, so the clock can't roll past midnight mid-scene.

### 5.3 Travel between locations (S–M)
- One reusable **travel cutscene** pattern: fade out → a short vehicle vignette (tricycle in town, van to the loom house and the eco-park, jeep and boat to Caticlan/Boracay) → title strip with the location name → fade in at the destination spawn. One cutscene JSON per trip, or a `travel` action with a `vehicle` parameter.
- Story travel is driven by cutscenes. The Book **Map** page can also reopen unlocked locations for free roam on review days (D1 days 5–7), using `regions.json` unlock flags (SIP 4.5).
- Set `GameState.current_area` from `level_areas.json` on every warp (SIP 1.3).

### 5.4 New hands-on activities (L in total, M each)
Register each as a `minigame_trigger` type, next to `memory_match`. Each one resolves pass/fail through `resolve_minigame`, and **failure is never punished**: offer a retry, and a soft fail still continues the story.

| Activity | Chapter | Mechanic | Vocab reinforced |
|---|---|---|---|
| `market_order` | 2 | A phrase-builder variant: build "Pangabay, gusto ko it ___" by picking the item word from pictures of fish, chicken, eggs, rice and so on. Two or three orders. | pangabay, gusto, isda, manok, itlog, humay, tinapay |
| `map_match` | 2 | Drag Kalibo place labels onto Rose's map (the cathedral, market and park the player has already visited, plus the next destinations). Completing it unlocks those regions on the Book Map page. | lugar, mapa, places |
| `weaving` | 3 | A thread-colour sequence: Anang Loleng calls a colour **in Akeanon** (puti, puea, asul…), and the player taps the matching thread in rhythm. Three short rows that get faster (hinay → paspas). | Ch2 colours (spaced repetition) + hinay, paspas |
| `fishing` | 4 | Timing: wait for the bobber, tap. Each catch is named in Akeanon, and the player picks the right word (2–3 choices). Catch-and-release framing (conservation theme). | isda + Ch4 nature words |
| `call_response` | 5 | A rhythm prompt: drum beats, Rose or Julian calls, the player taps or selects the response. Needs audio. If there's no audio budget, fall back to a phrase builder. | saot, tamboe, pyesta, kasadyahan |
| `souvenir_shop` | 6 | Choose a handmade craft and say the buy phrase (bakae, from Ch3). It closes the "support the maker" lesson. | bakae, baligya, turista, bisita |

### 5.5 Generic NPCs and crowds (M) — SIP 3.1 first
- One `NpcController` scene per character via exports (SIP 3.1), so the five new characters are `.tscn` files with export values, not new scripts.
- **Ambient townsfolk**: non-interactive or one-line NPCs (market vendors, churchgoers, festival dancers, tourists) with a wander/idle behaviour. They're needed to make the town, the festival and the beach feel alive. Use `examinable_object`-style single lines with no rapport.

### 5.6 Keepsakes and memories (S)
Use the reward keys `RewardManager` already has. Show them in the Journal tab.

| Chapter | Keepsake / stamp | Granted by |
|---|---|---|
| 1 | Stamp: Kalibo Airport | end of Ch1 |
| 2 | Star fruit (if bought); Rose's paper map of Kalibo; stamps for Pastrana Park, Market, Cathedral | scene 2 choice; scene 3; arrivals |
| 3 | **Piña bookmark** (referenced by Jonabel's idle lines) | scene 3 gift |
| 4 | Mangrove seedling memory, a planting moment (tanom) | scene 4 / 5 |
| 5 | Festival accessory (Julian's high-rapport idle line already describes this) | scene 3 or high-rapport idle |
| 6 | Boracay souvenir; Rose's "starter list" of next words (her Ch6 high idle line) | scene 3; epilogue |

One `memory_page` per chapter: a picture-book recap shown in the Journal, generated from the chapter's flags (what you chose, what you bought).

### 5.7 Quests per chapter (S) — SIP 4.1
Every chapter gets one main quest with steps (objectives) so the HUD always says what to do next. IDs continue from q004. The full list is in §8.2.

### 5.8 Ending and credits (S)
An epilogue scene (D5), a "trip summary" spread in the Book UI (words learned, stamps, hearts per NPC), a credits roll, and a return to the main menu with the save kept (New Game+ or free roam is optional).

### 5.9 Dialogue authoring for long chapters (M) — SIP 3.6
The Ch3–6 scripts will roughly triple in length once activities, branches and setup lines are added. Labeled `next` ids (`"next": "after_weave"`) stop every insertion from renumbering the jumps. Do this before expanding Ch3–6, or every edit will reintroduce index bugs like those in §2.3.

---

## 6. Chapter build sheets

Conventions used below:
- **Flags:** `seen_chapterN_sceneM` (cutscene played), `story_done_<scene>_<npc>` (NPC switches to its idle pool), `chapterN_complete`.
- **Cutscene ids:** `chapterN_sceneM` → `data/cutscenes/chapterN_sceneM.json`.
- **Levels:** `scenes/world/chapterN/<place>.tscn`, each with an entry in `data/map_data/level_areas.json`.
- Every chapter's **definition of done** is at the end of its sheet.

### 6.1 Chapter 1: Homesick (polish only)

**Status:** playable end to end. bedroom → living room (scene 1) → book quest (q002) → airport indoors (1_5) → outdoors (scenes 2, 3, 4) → conga → warp to the Aklan home.

Work:
1. Fix every Ch1 item in §2.3 and blocker 2.2-2 (`check_flag`).
2. Add a title card for "Chapter 1: Homesick" at game start (§5.2).
3. Add an airport stamp reward on `chapter1_complete`.
4. Make `chapter1_scene4`'s conga hand off to `chapter2_scene0` cleanly (it already does through `aklan_living.gd`; check that the fade still matches after the title card is added).
5. Rewrite idle pools for language (§7.4).

**Done when:** a new game → Aklan living room with no errors in the output log; both branches of the numbers path (knows numbers / refresher) reach "Let's go home"; q002–q004 complete.

---

### 6.2 Chapter 2: Kalibo Town

**Synopsis.** Home at last. The next morning Rose takes the player through town: Pastrana Park (meet Anong Pedring), the public market (first real request: _pangabay_), the cathedral (the family's history, Rose's map), and a souvenir-shop vocabulary round. Home in the evening.

| # | Scene key | Location (level) | Trigger | Cast | Activity | Sets |
|---|---|---|---|---|---|---|
| 0 | `scene_0_home_atlast` | `chapter2/aklan_living` ✅ | arrival warp (exists) | family + Susan, Rose | — (expand: Susan shows the rooms; Rose: "Tomorrow. 7 AM. Don't be late, balikbayan.") | `seen_chapter2_scene0` ✅, `chapter2_day1_done` |
| 0b | _new_ `scene_0b_first_night` | `chapter2/aklan_BR_Player` ✅ | player enters own room | — | examine notebook → journal; sleep (§5.2) | `chapter2_slept` |
| 0c | _new_ `scene_0c_morning_brief` | `aklan_living` | wake up | Rose, Susan | — | `chapter2_started` → q005 |
| 1 | `scene_1_pastrana_park_morning_walk` | **new** `chapter2/pastrana_park` | auto on arrival | Rose, Anong Pedring, townsfolk | 3-way choice (exists); **add:** phrase builder "Mayad nga agahon" to greet Pedring (reinforces Ch1) | `seen_chapter2_scene1`, `met_pedring` |
| 1b | _new, D4-A_ `scene_1b_food_words` | walking cutscene, park → market | after scene 1 | Rose | food-word lines moved here from scene 4 + a quick quiz | `seen_chapter2_scene1b` |
| 2 | `scene_2_kalibo_public_market` | **new** `chapter2/kalibo_market` | auto on arrival | Pedring, Rose, vendors | **`market_order`** after "how do I say I want this?"; star-fruit choice (exists) | `seen_chapter2_scene2`, `bought_star_fruit` (optional) |
| 2b | _optional_ world task | market | free | 3 vendors | `Comp_WorldTask`: greet three vendors with the right greeting | `task_market_greetings` |
| 3 | `scene_3_kalibo_cathedral_midday` | **new** `chapter2/kalibo_cathedral` (exterior + plaza) | auto on arrival | Lola Susan, Lola Jonabel, Rose | 3-way map choice (exists); **add `map_match`** → unlocks map regions | `seen_chapter2_scene3`, `got_kalibo_map` |
| 4 | `scene_4_vocabulary_practice_round_numbers_colors_market_goods` | cathedral souvenir shop (an area of the cathedral level or a small interior) | after scene 3 | Rose | numbers 6–10 **memory match**; colour choice (exists); adjectives/demonstratives **quiz** | `seen_chapter2_scene4`, `story_done_ch2_rose` |
| 5 | _new_ `scene_5_evening_home` | `aklan_living` (evening) | travel home | family | reflection; Rose names tomorrow's trip (piña); sleep | `chapter2_complete` |

**Levels to build:** `pastrana_park` (art started in `assets/pastrana/`), `kalibo_market`, `kalibo_cathedral` (+ souvenir shop). Add each to `level_areas.json` → area `kalibo_town`.
**NPCs:** Anong Pedring (sprite + portrait, rapport-tracked, idle pool `idle_pool_anong_pedring`, **which doesn't exist yet, so write one**), and 4–6 townsfolk.
**Cutscenes:** `chapter2_scene0b`, `0c`, `1`, `1b` (walk), `2`, `3`, `4`, `5`, plus travel (tricycle) ×2.
**Quests:** q005 "Explore Kalibo with Rose" with steps park → market → cathedral → return home.
**Vocab check:** w189 pangabay, w091/w152/w093/w080/w230/w107/w024 food, w017/w196/w244/w215/w178 numbers 6–10, w199/w094/w198/w021/w056/w038 colours, w145/w128/w163/w028/w047 adjectives, w052/w051 demonstratives. **Missing from the bank:** _haron_ ("that, near me"); "Daya/Haron/Dato" is tagged with only two ids.
**Done when:** a player can go from scene 0 to scene 5 without the dev tab; every Akeanon line has `\` markers, correct ids and a translation; two or more activities have pass and fail paths that both continue; q005 completes; the map page shows the unlocked town regions.

---

### 6.3 Chapter 3: Threads of Piña

**Synopsis.** A van ride out to a piña weaving community. Anang Loleng shows the loom and how piña goes from plant to cloth. The player tries a row (Rose bets against them), receives a piña bookmark, and Rose runs a verb round.

| # | Scene key | Location | Cast | Activity | Sets |
|---|---|---|---|---|---|
| 0 | _new_ `scene_0_morning_brief` | `aklan_living` | Rose, Susan, Jonabel | — (Jonabel mentions her own lola wove: set up her idle lines) | `chapter3_started` → q006 |
| 1 | `scene_1_arrival_at_the_loom_house` | **new** `chapter3/loom_house_exterior` → interior | Anang Loleng, Rose | reaction choice (**add rapport**); **add** quiz: "Halin ra sa ___" (from where?) | `seen_chapter3_scene1` |
| 1b | _optional_ | piña plants beside the house | Loleng | examine objects: plant → stripping fibres → thread → loom (a 3–4 step world task that teaches the process) | `task_pina_process` |
| 2 | `scene_2_trying_the_loom` | `loom_house_interior` | Loleng, Rose | **`weaving` minigame** inserted before idx 8 | `seen_chapter3_scene2`, `wove_first_row` |
| 3 | `scene_3_closing_gift` | interior | Loleng, Rose | — | `got_pina_bookmark` (keepsake), `story_done_ch3_loleng` |
| 4 | `scene_4_vocabulary_practice_round_verbs_and_pace_words` | exterior, watching weavers work | Rose | **quiz** (verbs) + **memory match** (taas/naba, paspas/hinay, bug-at/maugan as opposite pairs) | `seen_chapter3_scene4` |
| 5 | _new_ `scene_5_evening_home` | `aklan_living` | family | Jonabel holds the bookmark → her memory of her lola; sleep | `chapter3_complete` |

**Script work:** fix the router; unify Loleng's name (D3); add `\` markers, the correct ids (§7.2), translations for every Akeanon line, rapport deltas, and the minigame insertion point; name the gift. Use a native review to check "Naabi abi gid namon…", "Uwat kaso" and "Hinay-hinay eang. bukon ra padasigan" (whose translation has the typo "whose faster").
**Levels:** `loom_house_exterior`, `loom_house_interior` (area `pina_loom`). **NPC:** Anang Loleng + 2–3 weaver NPCs (ambient, at looms).
**Quest:** q006 "Visit the piña weavers".
**Done when:** the weaving minigame works on touch and keyboard; the bookmark appears in the Journal; Jonabel's bookmark idle line is gated on `got_pina_bookmark` (not shown before).

---

### 6.4 Chapter 4: Roots of Bakhawan

**Synopsis.** The Bakhawan Eco-Park. Anong Ambo, the caretaker, explains how mangrove roots protect the town from storms. Fishing lesson, nature words, and a quiet family reflection on the boardwalk.

| # | Scene key | Location | Cast | Activity | Sets |
|---|---|---|---|---|---|
| 0 | _new_ `scene_0_morning_brief` | `aklan_living` | Rose, Jobert | — (Jobert: "I used to fish there") | `chapter4_started` → q007 |
| 1 | `scene_1_arrival_at_the_eco_park` | `bakhawan/bakhawan_outdoors` (**fill the shell**) | Rose, Anong Ambo | **add** greeting phrase builder (Ambo greets: reply in kind) | `seen_chapter4_scene1` |
| 1b | gate | boardwalk entrance | — | **reuse `ch2_tutorial_field_notes` / `ch2_bakhawan_gate1/2`** challenges (rename to `ch4_*`), with `field_notes` placed along the boardwalk | `bakhawan_boardwalk` unlocked |
| 2 | `scene_2_learning_about_mangroves` | boardwalk / `bakhawan_tree` | Ambo, Rose | examine roots (ugat w238), storm (bagyo w030); quiz | `seen_chapter4_scene2` |
| 3 | `scene_3_fishing_lesson` | river edge | Ambo, Rose | **fix the branch** (§2.3) + **`fishing` minigame** | `seen_chapter4_scene3`, `went_fishing` |
| 4 | `scene_4_vocabulary_practice_round_nature_and_actions` | boardwalk | Rose | memory match: opposite pairs (maisog/maeuya, malimpyo/mahigko); **add** planting a mangrove seedling (tanom) as a hands-on finish | `seen_chapter4_scene4`, `planted_mangrove` |
| 5 | `scene_5_reflection` | boardwalk at sunset (DayNight 17:30) | Jonabel, Jobert, Rose | — | `story_done_ch4_ambo`, `chapter4_complete` (after the evening at home) |

**Script work:** router, D3 naming, `\` markers, ids, translations, rapport, and the branch fix. Remove the `[NEW-VERIFY]` note once it's verified. Verify "ro mga ugat ru gakapyot sa eugta" and "magkantoguhan magpamunit" with a native speaker. Add _pamunit_ to the bank (once verified).
**Levels:** `bakhawan_outdoors`, `bakhawan_indoors` (visitor centre: a good spot for the field notes), `bakhawan_tree`. All exist as empty shells with tiles in `assets/tilesets/Bakhawan_*`. Retire `scenes/map/stub_area_bakhawan.tscn` once the real level carries its field notes and challenges.
**Challenges:** rename `data/challenges/chapter2.json` → `chapter4.json` and its ids `ch2_*` → `ch4_*`. Update `regions.json` `gate_challenge_id` and the `ChallengeManager` file list. Add `word_ids` to each challenge (they're empty today).
**Quest:** q007 "Visit the Bakhawan Eco-Park".
**Done when:** the boardwalk gate works; the fishing pass and soft-fail paths both reach scene 4; the sunset lighting holds through scene 5.

---

### 6.5 Chapter 5: Hala Bira! (Ati-Atihan)

**Synopsis.** Festival Sunday (D1-A). Kalibo's streets are full of drums. Kapitan Julian welcomes the family and explains that the festival is both faith (Sto. Niño) and culture (and, per D6, its Ati origins). The player joins a street cheer and is told they're no longer an outsider.

| # | Scene key | Location | Cast | Activity | Sets |
|---|---|---|---|---|---|
| 0 | _new_ `scene_0_festival_morning` | `aklan_living` | everyone | drums heard from the house; Lola Susan: "my favourite time of year" | `chapter5_started` → q008 |
| 1 | `scene_1_festival_grounds_morning` | **new** `chapter5/festival_street`: a festival-dressed variant of `pastrana_park` (same layout, new props, crowd) | Rose, Kapitan Julian, crowd | **add** greeting exchange | `seen_chapter5_scene1` |
| 2 | `scene_2_parade_and_dance` | parade route | Julian | parade cutscene (conga of dancers + drummers); **add** the D6 origins line | `seen_chapter5_scene2` |
| 3 | `scene_3_call_and_response` | street | Rose, Julian | **fix the branch** + **`call_response`** | `seen_chapter5_scene3`, `joined_chant` (if 1/2) |
| 4 | `scene_4_vocabulary_practice_round_festival_words` | street corner | Rose | quiz + memory match (saot, tamboe, pyesta, kasadyahan, balikbayan, bisita, tawo) | `seen_chapter5_scene4` |
| 5 | `scene_5_reflection` | festival street, evening (lights/lanterns: use `light_source.tscn` + DayNight) | Jonabel, Jobert, Rose | — | `story_done_ch5_julian`, `chapter5_complete` |

**Script work:** router, `\` markers, ids, translations, rapport, the branch fix; rewrite Julian's "practice pa lang" idle (D1); native review of Jonabel's scene 5 line; consultant review (D6). Note that "Pyesta" and "Sto. Niño" are proper nouns. Keep them unmarked unless they're bank words.
**Levels:** `festival_street` (reuses Pastrana Park). **NPC:** Kapitan Julian + a dancer/drummer crowd (animated idle loops). **Audio:** drum loop BGM + chant SFX (needed for `call_response`).
**Quest:** q008 "Join the Ati-Atihan".
**Done when:** the D6 review is signed off; the festival plays on the in-game date that the calendar page marks as Ati-Atihan; frame rate is acceptable on Android with the crowd on screen.

---

### 6.6 Chapter 6: Homeward (Boracay) + Epilogue

**Synopsis.** One last trip: from the Caticlan jetty across to Boracay. Rose's aunt, Tita Beth, explains how tourism supports local people. The player buys a handmade souvenir. A finale reflection on White Beach, a farewell, then the flight home.

| # | Scene key | Location | Cast | Activity | Sets |
|---|---|---|---|---|---|
| 0 | _new_ `scene_0_packing` | `aklan_BR_Player` → `aklan_living` | family | packing; Lola Susan: "Balik kamo, ha" (move her farewell lines here from the idle pool) | `chapter6_started` → q009 |
| 1 | `scene_1_caticlan_jetty_departure` | **new** `chapter6/caticlan_jetty` | Rose, Jobert, tourists | **add** a ticket/boarding phrase (sakay) | `seen_chapter6_scene1` |
| 1b | _new_ boat ride | boat cutscene (a short scrolling-water scene or a vignette) | family | Rose's quiet moment (her idle "alone at the end of the boat" becomes a story beat) | `seen_chapter6_boat` |
| 2 | `scene_2_arrival_at_boracay_white_beach` | **new** `chapter6/boracay_white_beach` | Tita Beth, Rose | greeting | `seen_chapter6_scene2` |
| 3 | `scene_3_tourism_lesson` | beach-front market stalls | Tita Beth | **`souvenir_shop`** | `seen_chapter6_scene3`, `bought_souvenir` |
| 4 | `scene_4_vocabulary_practice_round_tourism_and_travel` | beach | Rose | quiz + **final review**: a cumulative quiz drawing from every chapter's words (weighted by mastery, SIP 4.3) | `seen_chapter6_scene4` |
| 5 | `scene_5_finale_reflection` | beach at sunset | everyone | — | `chapter6_complete` |
| E1 | _new_ `epilogue_flight` | airport (reuse `airport_arival`, reversed) | family, Rose, Susan | farewell; Rose: "Text me when you land." Variant by Rose's rapport tier (D5, all warm) | `epilogue_farewell` |
| E2 | _new_ `epilogue_home` | `chapter1/us_bedroom` ✅ | player | open the notebook → trip summary spread (§5.8); phone buzz: Rose's text; credits | `game_complete` |

**Script work:** router, `\` markers, ids, translations, rapport; delete the leaked "Summary — full script status" line; de-duplicate Rose's scene 5 line against Ch5; write the epilogue (new script, native review).
**Levels:** `caticlan_jetty`, `boracay_white_beach` (+ stall area), boat vignette. Map region `caticlan_port` can replace the placeholder `port`.
**NPC:** Tita Beth + tourists and boatmen.
**Quest:** q009 "One last trip".
**Done when:** a full new-game playthrough reaches the credits; the trip summary is correct for a fresh save and for a save with every keepsake; the main menu afterwards offers Continue (free roam) without crashing.

---

## 7. Vocabulary and language work

### 7.1 Rules (already the project's conventions)
- Akeanon in dialogue is marked with a `\` prefix (`\Mayad \nga \agahon`). Ch3–6 have none, so add them.
- Every marked word must be in `word_ids`, and every id in `word_ids` must appear in the line.
- Every non-English line gets a `translation`.
- Never invent glosses or spellings. New words are added to `data/word_bank.json` only with a source and a native-speaker check.

### 7.2 Corrected word ids for the Ch3–6 vocabulary rounds
| Chapter / line | Words in the line → correct id |
|---|---|
| Ch3 s4 idx 1 | bangon **w034** (+ _panaw_: **missing**) |
| Ch3 s4 idx 3 | dayon **w053** (+ _agto_: **missing**) |
| Ch3 s4 idx 4 | bakae **w031**, baligya **w032**, hambae **w073**, sabat **w205** (+ _tan-aw_: **missing**; check whether `tan-awa` exists) |
| Ch3 s4 idx 9 | taas **w218**, naba **w170**, paspas **w192**, hinay **w079** |
| Ch3 s4 idx 10 | bug-at **w044**, maugan **w161** |
| Ch3 s4 idx 11 | kuntra **w120** |
| Ch4 s4 idx 1 | baybay **w037**, tubi **w233**, eugta **w062**, baeas **w026** |
| Ch4 s4 idx 2 | maisog **w144**, maeuya **w135**, malimpyo **w149**, mahigko **w143** |
| Ch4 s4 idx 3 | tikang **w229**, pamati **w187**, tanom **w225** (+ _pamunit_: **missing**) |
| Ch4 s2 | ugat **w238**, bagyo **w030**, tubi **w233**, baeas **w026** |
| Ch5 s4 idx 1 | saot **w211**, tamboe **w220**, pyesta **w200**, kasadyahan **w108** |
| Ch5 s4 idx 2 | balikbayan **w033**, bisita **w042**, tawo **w228** |
| Ch6 s4 idx 1 | eangoy **w060**, baybay **w037** (+ _sakay_, _pahuway_: **missing**) |
| Ch6 s4 idx 2 | warang **w245**, bisita **w042** (+ _balik_: missing, though `w137 magbalik` exists; + _turista_: **missing**) |

The story-scene lines (s1–s3, s5) of Ch3–6 need the same pass. Run it with the validator (SIP 2.4) rather than by hand.

### 7.3 Words to add (only after verification)
_panaw, agto, tan-aw, pamunit, sakay, pahuway, balik, turista, haron, hablon (weaving)_, plus any word the new activities introduce (fish names for `fishing`, craft names for `souvenir_shop`).

### 7.4 Native-speaker review
- Build a review sheet: every Akeanon line (dialogue and idle) with the speaker, current text, translation, word ids, and a "verified" column. Generate it from the JSON so it stays in sync.
- Priorities: (1) every line the player is **quizzed** on, (2) story lines, (3) idle pools. The idle pools need rewriting from Tagalog/Hiligaynon into Akeanon, or a deliberate decision that some characters code-switch, which should then be documented.
- Fix the `area` field in `word_bank.json` to match where each word is now taught (for example, the Ch4 nature words, the Ch6 travel words).
- Flip `verified: true` per word as it's signed off. Target: 100% of quizzed words before release.

### 7.5 Spaced repetition across chapters
Each vocabulary round should re-test 2–3 words from **earlier** chapters (the weaving colours are the model). Use `get_weighted_review_word` over exposed words (SIP 4.3). Ch6 scene 4 is the cumulative final review.

---

## 8. Flags and quests ledger

### 8.1 Flags (proposed, by chapter)
| Chapter | Flags |
|---|---|
| 1 (existing) | `seen_chapter1_scene1`, `_scene1_5`, `_scene2`, `_scene3`, `_scene4`, `warm_toward_lola`, `is_numbers_refresher`, `story_done_scene_3_reunion`, `story_done_scene_4_rose`, `chapter1_complete`, `quest_002/003/004_done` |
| 2 | `seen_chapter2_scene0` ✅, `chapter2_slept`, `chapter2_started`, `seen_chapter2_scene1/1b/2/3/4`, `met_pedring`, `bought_star_fruit`, `got_kalibo_map`, `story_done_ch2_rose`, `chapter2_complete` |
| 3 | `chapter3_started`, `seen_chapter3_scene1..4`, `wove_first_row`, `got_pina_bookmark`, `story_done_ch3_loleng`, `chapter3_complete` |
| 4 | `chapter4_started`, `seen_chapter4_scene1..5`, `went_fishing`, `planted_mangrove`, `story_done_ch4_ambo`, `chapter4_complete` |
| 5 | `chapter5_started`, `seen_chapter5_scene1..5`, `joined_chant`, `story_done_ch5_julian`, `chapter5_complete` |
| 6 | `chapter6_started`, `seen_chapter6_scene1..5`, `seen_chapter6_boat`, `bought_souvenir`, `chapter6_complete`, `epilogue_farewell`, `game_complete` |

Rules: flags are only ever added (saves are additive), never renamed after release without a migration (SIP 2.2), and every flag that's **read** must be **written** somewhere (the validator checks this).

### 8.2 Quests
| Id | Title | Requires flag | Steps (objectives) | Completion flag |
|---|---|---|---|---|
| q005 | Explore Kalibo with Rose | `chapter2_started` | Pastrana Park → Market → Cathedral → Go home | `chapter2_complete` |
| q006 | Visit the piña weavers | `chapter3_started` | Meet Anang Loleng → Try the loom → Go home | `chapter3_complete` |
| q007 | Visit the Bakhawan Eco-Park | `chapter4_started` | Meet Anong Ambo → Cross the boardwalk → Go fishing → Go home | `chapter4_complete` |
| q008 | Join the Ati-Atihan | `chapter5_started` | Meet Kapitan Julian → Watch the parade → Join the cheer | `chapter5_complete` |
| q009 | One last trip | `chapter6_started` | Board at Caticlan → Meet Tita Beth → Buy a souvenir → Say goodbye | `game_complete` |
| q0x0 (side) | Go to bed | `chapterN_complete` | Sleep in your room | `chapterN+1_started` |

Add one achievement per chapter (`flag` condition type, SIP 4.2), plus "Bookworm" (all keepsakes) and "Hala Bira!" (joined the chant).

---

## 9. Asset checklist

| Type | Needed | Have |
|---|---|---|
| **Character sprites** (walk 4-dir) | Anong Pedring, Anang Loleng, Anong Ambo, Kapitan Julian, Tita Beth; townsfolk ×4–6; weavers ×2; dancers/drummers ×3–4 (palette swaps OK); tourists ×2–3 | player, Jonabel, Susan, Jobert, Rose |
| **Portraits** | Susan, Rose, + the five new NPCs | Jonabel, Jobert |
| **Tilesets / maps** | Pastrana Park (started), market, cathedral + plaza, souvenir shop, loom house in/out, Bakhawan (tiles exist, maps empty), festival-dressed park, Caticlan jetty, boat vignette, White Beach + stalls | home, airport, Bakhawan tiles |
| **Props** | market stalls, fruit/fish, loom, piña plants, fishing rod/bobber, mangrove seedling, drums, banners, boats, life vests, souvenirs | furniture set |
| **Keepsake icons** | star fruit, map, bookmark, seedling, festival accessory, souvenir; stamps ×8 | — |
| **Minigame UI** | weaving threads, fishing bobber/meter, rhythm lane, market item cards | quiz/phrase/memory panels |
| **BGM** | home (Aklan), town, market (busy), cathedral (calm), loom house, eco-park, festival drums, beach, finale/credits | "village" only |
| **SFX** | drum hits, loom shuttle, water splash, crowd, boat engine, phone buzz | basic UI |
| **Title cards** | one per chapter + credits | — |

Tie each level's BGM to its area once SIP 3.4 / 4.7 lands (one BGM per level, crossfades).

---

## 10. QA and test plan

**Per chapter, before it counts as done:**
1. The validator passes (SIP 2.4): indices, word ids, speakers, flags read vs written, cutscene actors.
2. Every scene can be reached from a **new game** without the dev tab, and every choice branch reaches the scene's end.
3. Every activity: pass path, fail → retry path, fail → continue path.
4. Save mid-chapter → quit → Continue: you resume at the right level, with NPCs in the right state, and no cutscene replays.
5. A save from the **previous** milestone still loads (additive fields only).
6. Android export: touch controls in every minigame, text fits in the dialogue box, frame rate is OK in crowd scenes.
7. Native-speaker sign-off on the chapter's lines (§7.4).

**Dev tab:** add a warp and cutscene entry per new scene, a "start chapter N" preset (sets that chapter's prerequisite flags and quests, the way `CH2_START_FLAGS` already does), and "grant all keepsakes" for testing the ending.

**Full-run checks at M7:** a complete playthrough at low, medium and high rapport; the trip summary numbers match the save; the calendar date lands on Ati-Atihan for Ch5 (D1-A).

---

## 11. Milestones and order

| M | Scope | Contents | Size | Depends on |
|---|---|---|---|---|
| **M0** | Unblock | Fix blockers 2.2-1/2/3 (routers, `check_flag`, Ch3–6 ids); lock D1–D9; delete leaked editor notes | S | none |
| **M1** | Story foundations | SIP 2.4 validator, 3.1 NPC consolidation, 3.3 stable ids, 3.4 LevelRoot, 3.6 labeled dialogue, 4.5 map unlock flags; §5.1 flag ops, §5.2 day/chapter progression + title cards, §5.3 travel, §5.7 quest steps | L | M0 |
| **M2** | Ch1 polish + **Ch2 vertical slice** | §6.1 and §6.2 in full, `market_order` + `map_match`, Pedring, three town levels, townsfolk. **This proves the per-chapter pipeline; adjust the template before going on.** | L | M1 |
| **M3** | Ch3 | §6.3, `weaving`, keepsake system (§5.6), Loleng, loom levels | M–L | M2 |
| **M4** | Ch4 | §6.4, `fishing`, fill the Bakhawan levels, rename challenges, Ambo | M–L | M2 (M3 for keepsakes) |
| **M5** | Ch5 | §6.5, `call_response` + audio, festival level variant, crowd, Julian, D6 review | L | M2, D1/D6 |
| **M6** | Ch6 + ending | §6.6, `souvenir_shop`, jetty/boat/beach, Beth, epilogue, trip summary, credits | L | M3–M5 (summary needs every keepsake) |
| **M7** | Language and release QA | §7.4 review complete, idle-pool rewrite, full playthroughs (§10), Android pass, achievements | M | all |

M3 and M4 can run in parallel once M2 has fixed the template, as long as different people own the levels. M5 is the riskiest (audio, crowd performance, cultural review), so start the D6 consultation during M2.

**Critical path:** M0 → M1 → M2 → (M3 ∥ M4 ∥ M5) → M6 → M7.

---

## 12. Open questions for the team
1. Is there a native Akeanon speaker or consultant available, and what's their turnaround? That gates every chapter's "done".
2. Is there an audio budget for `call_response` (drum loop + chant recording), and for word pronunciation clips in general? Spoken audio would help a language game a lot.
3. Should the Ch3 loom house and Ch4 eco-park be depicted as the real named sites, or kept generic? Naming real places may call for permission or a fact check.
4. Is post-game free roam (revisiting places, idle pools, review quizzes) in scope, or does the game end at the credits?
5. Who owns pixel art for the five new NPCs and seven-plus maps? Art is likely the longest pole after M1.
