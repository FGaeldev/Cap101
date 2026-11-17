# Releasing an Android build

## Version numbers

Format: `MAJOR.MINOR.PATCH-stage`, for example `0.3.0-alpha`.

| Part | Bump when | Example |
|---|---|---|
| MINOR | a content milestone lands (a chapter, a system like the economy) | `0.3.0` → `0.4.0` |
| PATCH | a build that only fixes bugs or polishes a milestone | `0.3.0` → `0.3.1` |
| MAJOR | the finished game (capstone defense / public) | `1.0.0` |
| stage | `-alpha` until every chapter is playable, then `-beta`; none at `1.0.0` | |

Reset PATCH to 0 when MINOR goes up. No leading zeros (`0.3.1`, not `0.3.01`).

History: `0.1.0`–`0.1.19` used PATCH as a build counter. `0.2.0` is skipped;
`0.3.0` is the first release on this scheme (onboarding, Chapter 2 polish, economy).

## Version code

Android's `version/code` must always go up, or phones refuse the update:

```
code = MAJOR * 10000 + MINOR * 100 + PATCH
```

`0.3.0` → 300, `0.3.1` → 301, `0.4.0` → 400, `1.0.0` → 10000. Keep PATCH under 100.

## Steps

1. Merge everything for the release into `main` (through a PR). Godot exports the
   files on disk, so the working tree must be clean: `git status` shows nothing.
2. Set the version in **both** places, same string:
   - `project.godot` → `config/version="0.3.0-alpha"` (shown on the title screen)
   - `export_presets.cfg` → `version/name="0.3.0-alpha"` and `version/code=300`
3. Run the static check: `bash .claude/skills/playtest/scripts/run.sh static`.
4. Export: Project → Export → AkeanQuest → Export Project, to `../AkeanQuest.apk`
   (or `godot --headless --path . --export-debug AkeanQuest ../AkeanQuest.apk`;
   use `--export-release` once a release keystore is set up).
5. Commit the version bump to `main` and push.
6. Publish:
   ```bash
   gh release create v0.3.0-alpha ../AkeanQuest.apk --target main --title v0.3.0-alpha --prerelease --generate-notes
   ```
   Tag is `v` + the version name. Drop `--prerelease` from `1.0.0`.

## Signing

Builds up to `0.3.0-alpha` are signed with this PC's debug keystore
(`~/.android/debug.keystore`). A build signed with a different key can't update
over an installed one: the player has to uninstall, which deletes the save.

Before builds go to more testers, make a release keystore once, keep it and its
password out of the repo (backed up somewhere safe), and set it in
Project → Export → AkeanQuest → Keystore → Release. From then on export with
`--export-release`. Testers uninstall once at that switch.
