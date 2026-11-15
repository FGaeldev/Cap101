---
name: playtest
description: Automated playthrough test of Cap101 (BueotHambaeon) that plays the real game by itself, finds bugs, and reports each one with screenshots. Modes - the whole game, a single chapter, or a static data check. Use when the user asks to playtest, do a playthrough test, test a chapter, smoke-test the game, or "find bugs by playing", or after content changes (new scenes, cutscenes, dialogue) that should be checked end to end.
---

# Cap101 playtest

Plays the game from a clean state with an auto-player, plus a static check of all
scenes and data, then turns the findings into a bug report. **Every bug in the
report has at least one screenshot.**

## Modes

| Ask | Command (from the project root) | Roughly |
|---|---|---|
| Whole game | `bash .claude/skills/playtest/scripts/run.sh full` | every playable chapter in order from a new game, ~8 min |
| One chapter | `bash .claude/skills/playtest/scripts/run.sh chapter <N>` | that chapter from its start state; ch1 ~1 min, ch2 ~6 min |
| Data only | `bash .claude/skills/playtest/scripts/run.sh static` | static check alone, ~30 s |

`full` and `chapter` also run the static check first. Run the command in the
background (`run_in_background`) for anything but `static`, and wait for the
completion notice. The last line printed is `REPORT_DIR=<folder>`.

Env overrides: `PLAYTEST_BUDGET=<seconds>` (real-time limit),
`PLAYTEST_ARGS="--speed=4 --no-fast-calendar"`, `GODOT=<console binary>`.

"Playable" chapters are those marked `"available": true` in `data/chapters.json`
**and** defined in `CHAPTERS` in `scripts/autoplay.gd` (currently 1 and 2). Asking
for another chapter ends at once with a "not defined" finding: say the chapter isn't
built yet rather than reporting it as a bug.

## Before you run

- Runs are **windowed** (a game window appears; screenshots need a real frame).
  Tell the user a window will pop up and not to type into it. Never add `--headless`.
- Don't run two playtests at once, and don't run while the user is playing in the
  editor: both write the same save file.
- `run.sh` backs up `save.dat`, `save.bak` and `settings.cfg` into
  `<report>/backup/` and restores only files the run changed. Check its last
  lines for `save.dat: restored/unchanged`. If it prints a WARNING, tell the user
  and point them at the backup; don't overwrite anything yourself.
- The auto-player forces dev mode off for the run (the user's own setting comes
  back with settings.cfg).

## What the auto-player does

Starts a new game (or the chapter's start state), runs at 3x speed, and:
skips dialogue lines, picks choices (first option; cycles options when the same
menu comes back without progress), **fails the first minigame of each kind** and
passes the rest, completes tutorial steps by sending their events, opens the
newspaper and closes it, picks "Review" for the first two NPC menus after Chapter 1,
and when idle interacts with the most story-relevant thing in the room (unseen
cutscene NPC > quest marker > pending story dialogue > untouched object), then
explores through warps, sleeps, and advances the clock if nothing else is left.
With the fast calendar on (default) it jumps to Saturday night after the Ch2 tour,
so Sunday mass gets tested, then asks Rose for Bakhawan.

It records a **finding** for every engine error and warning (via a Godot `Logger`,
with script backtrace), plus things it detects itself:
- `softlock`: a line authored with choices showing none, a choice box with no
  buttons, a dialogue UI it can't advance for 8 s
- `stuck`: a warp running 20 s, a cutscene running 3 min, nothing left to do
  before the chapter's finish line, time budget out
- `error` for warps with no target or a missing target scene, found while exploring

Each finding is screenshotted the moment it happens (the driver holds still until
the shot is taken), and every level gets one overview shot once it settles.

Shortcuts it takes, worth knowing when judging findings: it teleports next to
objects and fires warps/interacts directly (no real walking or collision), and it
resolves minigames without playing them. It can't judge art, layout or text, so
look at the level shots yourself for anything visibly wrong.

## Output folder (`playtest_reports/<stamp>_<mode>/`, gitignored)

- `findings.json`: run summary + `findings[]` with `kind`, `message`, `count`,
  `chapter`, `level`, `clock`, `where`, `backtrace`, `context` (the last 25
  events before it), `screenshot`; also `end_reason`, `final_flags`, `levels_visited`
  (level → overview shot)
- `static_findings.json`: `findings[]` with `category`, `message`, `file`/`level`,
  `snippet`, `screenshot` (level problems: the level rendered with a red box on the
  spot; data problems: an image of the offending JSON entry)
- `events.log`: everything the auto-player did, `!!! FINDING #n` marks findings
- `godot.log`, `validate.log`: raw engine output
- `shots/`: all images

## Writing the report

1. Read `findings.json` and `static_findings.json`. Check `end_reason`: anything
   other than "all requested chapters played" means the run didn't finish, so say
   where it stopped (last events in `events.log`).
2. **Verify before reporting.** For each finding, open the code/data at `where` or
   the backtrace and confirm it's a real game bug, not a side effect of the
   auto-player's shortcuts. Read the `context` lines to write repro steps a person
   can follow ("in Pastrana with Rose, walk into an exit, pick 'Somewhere else'").
   Drop what you can't confirm, or list it under "Unconfirmed".
3. Group duplicates: same cause = one bug (e.g. all `level_no_area` findings, or
   the same warning from several levels). Keep the `count`.
4. Known content-status noise, don't report as bugs unless asked:
   `WordBank: skipping '<word>' until it has a meaning` (list them once under
   "Content gaps").
5. **Every bug gets a screenshot.** Use the finding's own `screenshot`. If it's
   empty (budget of 60 shots hit, or the finding came before the game drew), use
   the overview shot of its `level` from `levels_visited`, and say it's the room,
   not the moment. Never submit a bug without an image.
6. Write `report.md` in the report folder. For each bug:

   ```markdown
   ### 1. <one-line title> (High)
   ![<what the image shows>](shots/finding_004_softlock.png)
   **Where:** Chapter 2, pastrana_outdoors.tscn, Wed 3:00 PM
   **What happens:** <what the player sees>
   **Repro:** <steps from the context log>
   **Cause:** [file.gd:22](../../scripts/ui/choice_box.gd:22) <one or two sentences>
   **Fix:** <suggested change>
   ```

   Order by severity (High: blocks progress or breaks a feature; Medium: wrong
   behaviour with a workaround; Low: cosmetic/noise). Then "Content gaps",
   "Unconfirmed", and "Not covered" (what this run couldn't test).
7. **Update the bug tracker doc**,
   [Cap101 Bug Tracker](https://claude.ai/artifact/GS3YRzbQVMUXG9vRtGSZkS) (a Claude
   Doc, project id `7cf83d9b-d32c-4be2-959a-e38a9c0fef8f`). It's the shared, living
   list; `report.md` is just this run's record.
   - Load the `anthropic-skills:docs` skill first and follow the docs connector's
     instructions. Read the doc's outline before writing: people edit it between runs
     (statuses, notes, fixed bugs), and their edits win.
   - A bug already in the tracker (same cause): don't add it again. If its row says
     Fixed but this run still hits it, add a comment on that row saying it came back,
     with the run folder. If an Open bug didn't show up this run, say so in chat; never
     change a Status yourself.
   - A new bug: a row in the **Tracker** table with the next free `B<n>` ID, Severity,
     Area, Found by (Playthrough / Static check / Code review) and a Status dropdown
     set to Open, plus a `### B<n>. <title>` section at the end of its severity
     section (Where, What happens, Repro, Cause, Fix, as the existing ones read).
   - Screenshots: upload the PNGs to the doc's link with the Artifact tool
     (`asset: true`, `file_paths`), make a blob per asset id, then insert
     `![<what it shows>](blob/<id>)` right under the bug's heading.
   - New content gaps or suggestions go in "Content gaps and suggestions".
8. Send `report.md` and its screenshots with `SendUserFile` (the report with
   `display: "render"`). In chat, list the new bugs by ID and give the tracker link.
   Links in chat to project files use paths relative to the project root.

## Adding a chapter

When a new chapter becomes playable, add it to `CHAPTERS` in
`scripts/autoplay.gd`:
- `start_level`: level a chapter-mode run boots into
- `setup`: a func that sets the flags/quests the chapter starts from (mirror the
  previous chapter's ending; `_setup_ch2` shows the pattern, and
  `scripts/ui/page_dev.gd` has the flag lists the dev warps use)
- `done`: a func that returns true once the chapter is fully played

If the chapter has beats that wait on the calendar or need a specific choice
(like Sunday mass or the Bakhawan request), add a nudge the way `_jump_sunday`
and `_want_bakhawan` do, or the run will spend its budget waiting.

## Troubleshooting

- Run ends at once with no screenshots: it ran headless, or Godot isn't at the
  `GODOT` path. Check `godot.log`.
- `validate exit 124` / `autoplay exit 124`: hit the hard timeout. Look at the
  tail of `events.log` for the last thing it did.
- A script error inside `autoplay.gd` itself shows in `godot.log` with a backtrace
  into `.claude/skills/playtest/scripts/`. Fix the driver, not the game.
