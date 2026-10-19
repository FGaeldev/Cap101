# Systems Improvement Plan — BueotHambaeon (Cap101)

_Written 2026-10-19 against `main` @ `ddcac8e` plus the current uncommitted working tree._

This plan covers the systems already in the game: save/state, quests, challenges, tasks, rewards, dialogue, cutscenes, NPCs, interaction, warps/map, BookUI, tutorials, audio, and data loading. It doesn't propose new features. It's ordered so each phase can merge on its own and doesn't break the phases after it.

---

## 0. Snapshot: what's there today

| Layer | Pieces | Overall state |
|---|---|---|
| Autoloads (18) | GameState, WordBank, QuestManager, ChallengeManager, TaskManager, RewardManager, AchievementManager, MapManager, CutsceneManager, DialogueUI, BookUI, TutorialManager, AudioManager, FadeManager, ChapterLoader, CharacterRegistry, UIThemeApplier, BackButtonBridge | Well commented and follow a consistent "register on ready, call through the autoload" convention. They're tightly coupled to each other, and the file-loading and save code is copied from one to the next. |
| Data | 6 dialogue chapters, 6 cutscenes, quests, challenges, tasks, tutorials, regions, word bank (~145 KB JSON) | Data-driven, which is good. Nothing validates it, it has no schema, and dialogue branches point at lines by raw integer index. |
| Gameplay | Grid player FSM, Comp_Interactable, Comp_Warp, 3 NPC scripts, level scripts | Works. The NPC logic is copied across three scripts, and the level scripts hard-code spawn and story logic. |
| UI | DialogueRoot/Box, choice/quiz/phrase/puzzle/memory panels, BookUI tabs, HUD | Feature-rich. The dialogue layout has needed 10+ fix commits in a row, which is a sign the design is fragile, not a run of one-off bugs. |
| Tooling | Dev tab (warps/cutscenes), git plugin | No automated tests, no data linting, and no CI. |

---

## Phase 1: Correctness fixes (do these first, all small)

These are concrete bugs or regressions I found while reading the code. Each one is a small, self-contained PR.

### 1.1 Story dialogue can't be reached because Talk is disabled ⚠ highest priority
- `DialogueUI._build_npc_interaction_menu()` hard-disables the **Talk** button ("reworking idle_pool system").
- Every NPC script (`npc_generic.gd`, `npc_elder.gd`, `papaJobert.gd`) only reaches `_start_dialogue_or_idle()` through Talk.
- As a result, `scene_lola_susan`, `scene_rose`, Papa Jobert's scene and Lola Jonabel's post-cutscene dialogue never play, and their `story_done_*` flags are never set, so idle pools can't start either.
- **Fix:** turn Talk back on now with the existing story→idle routing. If the idle rework needs a gate, make it a data flag such as `idle_enabled`, not a disabled button. If Talk has nothing to say (story done and no idle pool), hide it instead of disabling it.

### 1.2 Hint tokens are wasted on repeat use
- `ChallengeManager.remove_wrong_option()` always returns the **first** wrong index. The second token you spend removes the same option again: the token is consumed and nothing changes on screen.
- **Fix:** pass the already-removed indices in (`remove_wrong_option(id, excluded: Array)`), pick a random eligible wrong index, and refuse to spend when one or fewer wrong options remain. Check eligibility **before** calling `spend_hint_token()`.

### 1.3 `current_area` gets overwritten on every boot
- `Game._ready()` sets `GameState.current_area = "village"` after the save has loaded, and `scene_2.gd` does the same. Warps (`MapManager.warp_to_scene`) never update the area at all.
- Any quest with an `"area"` field (`QuestManager.complete_quests_with_trigger`) will therefore misfire after Continue or a door warp.
- **Fix:** each level owns its area. Add `@export var area_id` on a shared `LevelRoot` script (see 3.4), and have `Game.load_level()` set `GameState.current_area` and play the level's BGM from it. Remove the hard-coded lines in `Game.gd` and `scene_2.gd`.

### 1.4 `CutsceneManager.abort()` doesn't stop the running coroutine
- `abort()` sets `_playing = false`, but the awaiting `_run_sequence` coroutine is still alive. If its awaited signal fires later, it keeps running steps, and at the end it sets `_playing = false` and emits `cutscene_finished`. That can happen in the middle of a **new** cutscene, clearing its playing state and letting the player move during it.
- **Fix:** add a run token. `play()` increments `_run_id`, `_run_sequence` and `_run_step` check `run_id == _run_id` after every await and return early if it changed, and only the current run's completion clears `_playing`. Also kill the actor tweens that `move_npc` and `conga` own (keep a list of active tweens on the manager).

### 1.5 Keyboard interact fires every interactable in range
- Each `InteractableComponent` handles `interact` in its own `_unhandled_input`. With two NPCs in range, **E** triggers both, while the HUD button correctly picks only the nearest.
- **Fix:** take keyboard handling out of the component. Add one input handler (in HUD or a small `InteractionRouter`) that calls `InteractableComponent.get_nearest(player_pos).try_interact()`. Also have `try_interact` refuse while `DialogueUI.is_active()` or `BookUI.visible` is true.
- Delete the dead `interact()` method too: it calls `interacted.emit()` with no argument, but the signal declares one, so it would error if anything called it.

### 1.6 Smaller defects
| Where | Issue | Fix |
|---|---|---|
| `GameState.load_game()` | No null check on `FileAccess.open`. `current_level_path` falls back to `null` when the key is missing. | Guard the open, default the path to the bedroom scene, and return a `bool`. |
| `QuestManager._load()` | Crashes if the file is missing or malformed (the only loader without guards). Leftover `print()`. | Use the shared loader (2.1) and remove the print. |
| `MapManager.travel_to_region()` | Doesn't check `is_transitioning` (warp does), so a double-tap on Go starts two travels. | Add the same guard. |
| `ChallengeManager.attempt()` | Re-attempting a passed challenge re-grants rewards. | Return early if it's already passed, and don't call `grant_reward` again. |
| `BookUI._unhandled_input` | Esc opens the Book during cutscenes, dialogue, name entry and fades, and pausing the tree mid-tween can desync things. | Block it while `CutsceneManager.is_playing()`, `MapManager.is_transitioning`, or the current scene isn't Game. |
| `DialogueUI` | Holds refs (`_root`, `_dialogue_box`) to nodes that are freed on return-to-menu. `is_active()` reads `_root.visible` on a freed object. | Wrap these in `is_instance_valid`, or have DialogueRoot unregister in `_exit_tree`. |
| `player.gd`, `DialogueBox.gd` | Read the private fields `DialogueUI._current_component` and `_root`. | Add public `DialogueUI.is_input_locked()` and `refresh_layout()`. |

---

## Phase 2: Infrastructure (makes the next phases cheap)

### 2.1 One data loader instead of seven copies
Seven autoloads each repeat open → parse → type-check, and three keep their own hard-coded file lists (`CHALLENGE_FILES`, `TASK_FILES`, `ACTION_SCRIPTS`).

- Create `scripts/util/DataLoader.gd` (static), with:
  - `load_json(path, expected_type) -> Variant`, which handles missing files, parse errors with line numbers, and type mismatches in one place.
  - `load_json_dir(manifest_key) -> Dictionary`, which reads a **single manifest** `data/manifest.json` listing every data file by category. That keeps the Android-safe "no DirAccess" rule while putting the list in one data file instead of three code constants.
- Move QuestManager, ChallengeManager, TaskManager, AchievementManager, MapManager, TutorialManager, ChapterLoader, WordBank and CutsceneManager file reads onto it.

### 2.2 A save system with a schema
Today every persisted field is listed **four times**: the declaration, `reset_game_state`, `save_game` and `load_game`. Forgetting one of them is the most likely future save bug.

- Add one `const SAVE_SCHEMA := { "flags": {}, "word_exposures": {}, ... }` (key → default). `save`, `load` and `reset` all loop over it, so a new field is one line.
- Add `"save_version": N` and a `_migrate(data, from_version)` chain for renames (see 3.3 on NPC ids).
- **Atomic writes:** write to `user://save.tmp`, then `DirAccess.rename_absolute` over `save.dat`, and keep `save.bak`. Today a crash in the middle of `store_var` destroys the save.
- **Debounced saves:** there are 20 `save_game()` call sites, and one quest completion triggers several writes (set_flag → refresh → complete → save, plus a save on first word exposure). Add `GameState.request_save()`, which sets a dirty flag and flushes once per frame via `call_deferred`, plus `save_now()` for quitting and warps. On mobile that means much less flash I/O.
- Consider `JSON` + `var_to_str` instead of `store_var`: saves become readable and diffable for debugging, and there's no risk from binary format changes.

### 2.3 Decouple GameState from QuestManager
`GameState.set_flag()` and `expose_word()` call `QuestManager.refresh_active_quests()` directly, which is a circular autoload dependency, and `reset_game_state()` reaches into `QuestManager.active_quests`.

- QuestManager should connect to `GameState.flag_changed` and `GameState.word_learned` (and a new `exposure_changed`) itself, and expose its own `reset()`. GameState then has no outgoing calls, and the autoload order matters less.

### 2.4 A data validator / linter (the biggest win for content work)
Authors hand-edit, or generate via the `rpg-script-to-json` skill, dialogue that uses integer `next` indices, word ids, flag names, speaker names, cutscene actor ids and quest ids. Nothing cross-checks any of it.

Build `tools/validate_data.gd` as an `EditorScript` and a headless `godot --headless --script` entry point. It should check:
- Dialogue: every `next`, `success`, `failure`, `next_on_pass`, `patience_branch.next` and router index is in range; no unreachable lines; no lines that dead-end without a `next` unless intended; `word_ids` exist in WordBank; speakers exist in CharacterRegistry.
- Cutscenes: action `type` is registered; `actor` is the player, the camera, or something spawned or registered in that level; referenced `chapter`/`scene` keys exist.
- Flags: every flag that's **read** (`requires_flag`, `required_flag`, `unlock_flag`, `*_seen_flag`, `start_index_if_flag`, idle `flag_overrides`) is **written** somewhere (`set_flag` steps, `completion_flag`, `set_flag_on_enter`, `on_complete.flag`). This catches typos like `seen_chapter1_scene3` vs `seen_chapter1_scene_3`.
- Quests, challenges, tasks: ids are unique and rewards use known keys.
- It prints a report and exits non-zero, so it can run as a pre-commit hook or in CI.

### 2.5 Tests
There are none today. Add **GUT** (Godot Unit Test) under `addons/gut` and start with the pure-logic systems, which are cheap to test and where regressions hurt most:
- GameState: save→load round trip, migration, reset clears everything, patience regen math (inject a clock, see 4.4).
- QuestManager: gating by flag and exposure, trigger completion with area.
- ChallengeManager: first try, fail-twice, hint-token selection (1.2), no re-reward (1.6).
- DialogueComponent: router, patience_branch, choose deltas, idle shuffle bag.
- WordBank: normalization, `top_up_pool` gloss de-dupe.
- CutsceneManager: parallel/sequence completion and abort (1.4) with stub actions.

Then set up GitHub Actions: headless Godot 4.7 → `validate_data` + GUT on every PR.

---

## Phase 3: Architecture cleanup

### 3.1 Collapse the three NPC scripts into one
`npc_generic.gd`, `npc_elder.gd` and `papaJobert.gd` repeat the same flow (cutscene-first, the menu, the story→idle switch, actor registration) with small differences: spawn facing, and the elder's `seen_flag` vs generic's `cutscene_seen_flag`.

- Create one `NpcController` (keep `npc_generic.gd` as the base) with all of the exports, plus `spawn_direction`.
- Move the elder- and Papa-specific defaults into their `.tscn` export values and delete the two subclasses.
- Name the interaction menu options in data (`menu_options: ["talk","review","goodbye"]`) so an NPC can, for example, have no Review.

### 3.2 Pull the NPC menu out of DialogueUI
`DialogueUI` builds a VBox of buttons in code and injects it into DialogueRoot through a hard-coded node path (`Layout/DialoguePanel/Margin/TextColumn`). That's one of the main reasons for the layout churn.

- Make `scenes/ui/npc_menu.tscn` a real child of `TextColumn` in `dialogue_root.tscn`, registered the same way DialogueBox and ChoiceBox are.
- Even better, render the menu **through ChoiceBox**: a menu is just a choice list with a header. That removes a whole parallel code path, and the three-choice minimum-height logic already covers it.

### 3.3 Stable ids instead of display names as keys
`npc_id` is the speaker display string ("Lola Jonabel"), and it's also the rapport and patience save key and the cutscene actor id. Renaming a character, localizing it, or using `[Player]` substitution breaks saves and rapport attribution.

- Introduce slugs (`lola_jonabel`) in `CharacterRegistry` (`id`, `display_name`, `portrait`, `rapport_tracked`).
- Dialogue lines carry `speaker_id`, and the display name resolves through the registry.
- Use migration v2 (2.2) to re-key `rapport`, `patience` and `_patience_last_update` from display names to slugs.

### 3.4 A LevelRoot base and data-driven level setup
Level scripts (`scene_2.gd`, `aklan_living.gd`, `us_bedroom.gd`, `airport_arival.gd`) each hand-code area, BGM, fade, spawn tables and "wait until the cutscene or transition finishes" polling loops.

- Create `LevelRoot.gd` with the exports `area_id`, `bgm_id` and `entry_cutscene` + `entry_seen_flag`, plus a `ready_for_story` signal that fires once `MapManager` is no longer transitioning and no cutscene is playing. Signals replace the `while ...: await process_frame` polling.
- Move NPC spawn rules (`spawn_if_flag`, `despawn_on_flag`, marker, export overrides) into a per-level `NpcSpawnTable` resource. `scene_2.gd`'s 60 lines of spawn and override code become data.

### 3.5 Cutscene system hardening
- **Action contract:** add a `CutsceneAction` base class (`action_type()`, `execute()`, `validate(step) -> Array[String]`) so the validator (2.4) can ask each action to check its own step.
- **Skippable cutscenes:** add a skip button that fast-forwards (moves snap to their targets, dialogue is skipped, flags are still set). This is important for replays and dev testing.
- `dialogue_action` awaits the **global** `DialogueUI.dialogue_finished`. Await the spawned component's own `dialogue_ended` instead, so an unrelated `DialogueUI.hide()` (for example from the review quiz) can't resolve it.
- Put a `TILE_SIZE` constant in one shared place (`DirectionUtil` or a `Grid` util). It's duplicated today in `move_npc_action`, `comp_warp` and `player.tile_size`.
- Add a step-level `"wait_for": "signal_name"`, and a `"when_flag"` guard so branching cutscenes don't need separate files.

### 3.6 Dialogue data authoring
- Allow optional **string labels** (`"id": "ask_photo"`) and `"next": "ask_photo"`. Resolve them to indices once at load time in ChapterLoader, so existing integer data keeps working. Inserting a line then stops renumbering every jump after it.
- Merge `resolve_phrase_builder`, `resolve_quiz` and `resolve_minigame` (currently identical) into one `resolve_activity(passed)`, and use a dispatch table in `_show_line` keyed by line `type`.
- Have ChapterLoader actually unload old chapters on chapter change (`unload_chapter` exists but nothing calls it).

### 3.7 DialogueRoot layout
The current approach (hide with alpha, re-measure over 3 frames, clamp to the viewport) is a workaround for measuring autowrap labels before they have a width.

- Give TextColumn a fixed width derived from the viewport (it's always full width minus margins), and set `custom_minimum_size.x` on the wrapping labels and buttons so the first measurement is correct. Then use a single deferred `_fit_to_content()`.
- Or let the containers size themselves: anchor DialoguePanel to the bottom with `grow_vertical = BEGIN` and drop the manual `offset_top` math.
- Either one removes the settle loop and the one-frame invisible flicker.

---

## Phase 4: System-level improvements

### 4.1 Quests
- Add `objectives` (multi-step quests like tasks: talk to X, collect Y) so quests and tasks share one HUD row model. Longer term, consider merging TaskManager into QuestManager as "quests with steps".
- Add a `quest_progress_changed` signal, and track or display exposure progress for word-gated quests ("Hear 3/5 words").
- Make `show_popup` (present in data but unused) actually control the completion popup.

### 4.2 Rewards and achievements
- `RewardManager` already queues popups. Check that something consumes `popup_queued` and calls `advance_popup()`; if nothing does, add a `RewardToast` UI that drains the queue.
- **Achievements:** recompute them on relevant signals, keep an `unlocked_achievements` set in the save (2.2 makes that a one-line change), and show a toast on first unlock. Add the condition types `flag`, `challenge_count`, `stars_min` and `all_of`/`any_of`.

### 4.3 Learning loop (WordBank, mastery, review)
- Review quiz: today it pulls from every exposed word, falling back to the **whole bank** for a new player, which quizzes words they've never seen. Use `get_weighted_review_word` over exposed words only. If fewer than 4 are known, skip the quiz with a friendly line.
- Add spaced repetition: store `last_reviewed` per word, and weight by mastery **and** time since last review (the GDD's Ebbinghaus hook). Exposure count is already there.
- Dictionary: show the mastery level as stars/dots, and add a "practice this word" action.

### 4.4 Rapport and patience
- Patience regen reads `Time.get_unix_time_from_system()`, so changing the device clock skips or rewinds it. Clamp `elapsed` to `>= 0` (backwards clocks currently clamp only implicitly), cap regen per session, and route time through a `Clock` util that tests can override.
- Rapport tier thresholds (3.0/7.0) live in `Comp_Dialogue`. Move them to a shared config so the Relationship page and idle pools agree.

### 4.5 Map and warps
- Write the map `unlocked` state into the save (static `unlocked: true` plus a challenge gate today), so story progress can unlock regions with `unlock_flag`.
- Give warp and travel one transition path: `MapManager._transition(scene_path, spawn_id, area_id)`. The two functions duplicate ~15 lines today.
- Load levels asynchronously with `ResourceLoader.load_threaded_request` behind the fade, to avoid hitches on Android.

### 4.6 BookUI
- `_ready` hand-wires 7 tabs and 20+ exported NodePaths. Replace that with a `BookTab` resource list (`id`, `title`, `button`, `left_scene`, `right_scene`, `full_spread`, `unlock_condition`, `tutorial_event`). The `match` block in `switch_tab` that maps tabs to tutorial events then becomes data.
- Don't pause the whole tree. Pause only the gameplay (`LevelContainer.process_mode = DISABLED`), which removes the need for `PROCESS_MODE_ALWAYS` workarounds in HUD, TutorialManager and so on.

### 4.7 Audio
- Only one BGM ("village") exists, and every level forces it. Add a BGM per level (from LevelRoot), crossfade with two players, and add duck-on-dialogue.
- Persist the volume settings, which aren't saved today. Store them in `user://settings.cfg` (ConfigFile), **separate** from the game save so New Game doesn't reset them.
- Preload SFX once; `play_sfx` currently calls `load()` on every play. Also add a small player pool instead of creating a new node for each sound.

### 4.8 Tutorials
- Support conditions (`"requires_flag"`, `"skip_if_flag"`) and queued tutorials, instead of `Game._on_quest_started` awaiting `tutorial_completed`.
- Move `QUEST_TUTORIALS` from `Game.gd` into `tutorials.json` (`"start_on_quest": "q002"`).

---

## Phase 5: Content pipeline and developer experience

- **Chapters 3–6 dialogue exists but nothing references it.** Before building those chapters, settle 3.3, 3.4 and 3.6 so new chapters are only data: a LevelRoot with exports, a spawn table, and labeled dialogue.
- Expand the dev tab with: set or clear any flag, grant words/stars/tokens, jump to any dialogue scene key, show the save as JSON, and a "run validator" button.
- Add a `docs/` index that links the TDD and GDD sections the code comments cite (TDD §2, §7, §9, the GDD numbers). Those docs aren't in the repo, so new contributors can't follow the references.
- Add a project `CLAUDE.md` / CONTRIBUTING covering the conventions already in use: the Android "no DirAccess" rule, register-on-ready, the RewardManager-only reward writes, the additive-only save rule, and the no-punishment rule.

---

## Suggested order and sizing

| # | Work | Size | Depends on |
|---|---|---|---|
| 1 | Phase 1.1 (re-enable Talk) | XS | none |
| 2 | Phase 1.2–1.6 bug fixes | S each | none |
| 3 | 2.1 DataLoader + manifest | S | none |
| 4 | 2.2 Save schema, version, atomic and debounced writes | M | none |
| 5 | 2.3 GameState↔QuestManager decouple | S | 4 |
| 6 | 2.4 Data validator | M | 3 |
| 7 | 2.5 GUT + CI | M | 4, 6 |
| 8 | 3.1 + 3.2 NPC consolidation, menu via ChoiceBox | M | 1 |
| 9 | 3.3 Stable character ids + save migration | M | 4, 8 |
| 10 | 3.4 LevelRoot + spawn tables | M | 1.3 |
| 11 | 3.5 Cutscene hardening and skip | M | 1.4 |
| 12 | 3.6 Labeled dialogue + 3.7 layout | M | 6 |
| 13 | Phase 4 items | S–M each | as noted |
| 14 | Phase 5 | ongoing | 6, 10, 12 |

**Definition of done for each item:** the validator passes, the GUT suite passes, an old save from before the change still loads (once 2.2 lands), and a manual run through Ch1 (bedroom → airport → Aklan) on desktop and on an Android export works.
