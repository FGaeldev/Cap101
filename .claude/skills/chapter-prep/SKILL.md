---
name: chapter-prep
description: Prepares one Cap101 (BueotHambaeon / AkeanQuest) chapter for implementation, the way Chapter 3 was done. It writes an implementation plan from the repo's real state, then a director's storyboard (shots, staging, camera, lines) as a Claude Doc, then reviews every Akeanon line with the user one at a time, checking words against the word bank and the Aklanon grammar/dictionary PDFs, and records each language rule learned in the shared "Akeanon Grammar Notes" doc. Use when the user says "prep chapter N", "storyboard chapter N", "get chapter N ready", "director's pass on chapter N", or asks to review a chapter's Akeanon lines.
---

# Chapter prep (plan → storyboard → line review)

Run it with a chapter number: `/chapter-prep 4`. If no number is given, ask which chapter.

The output for chapter N:
1. `docs/CHAPTER<N>_PLAN.md`: what exists, what's missing, decisions, build order.
2. A Claude Doc, **"Chapter N: <title> (Director's Storyboard)"**: shot-by-shot scenes with staging and every line.
3. Corrected Akeanon in that storyboard, after a one-line-at-a-time review with the user.
4. New rules added to the shared **Akeanon Grammar Notes** doc.
5. A list of word-bank additions and fixes, for when the chapter goes into the game.

This skill prepares only. It doesn't edit game files, JSON, scenes or the word bank, and it doesn't commit. Offer to implement at the end.

## Fixed references

| What | Where |
|---|---|
| Chapter list, titles, availability | `data/chapters.json` |
| Story target per chapter (build sheet, flags, quests, vocab ids) | `docs/STORY_ROADMAP.md` §6.N, §7.2, §8 |
| Chapter dialogue | `data/dialogue/chapter<N>.json` |
| Word bank (255 entries, almost all `verified: false`) | `data/word_bank.json` |
| Ch3 example of the finished output | `docs/CHAPTER3_PLAN.md` and the Ch3 storyboard https://claude.ai/artifact/VAVt1rJ2hKsuPTY2m1Fa2G |
| **Akeanon Grammar Notes** (shared, keep adding to it, never recreate) | https://claude.ai/artifact/4QkkDRJfzEFGQnfCGb9o67, doc id `1b9c7b46-b8a2-4ca9-89fa-0b3f5332c220` |
| Bug tracker (check for open bugs in this chapter's areas) | https://claude.ai/artifact/GS3YRzbQVMUXG9vRtGSZkS |
| Aklanon grammar, de la Cruz & Zorc 1968 | `C:/Users/ACER/Desktop/Francis/Files/dokumen.pub_a-study-of-the-aklanon-dialect-volume-one-grammar.pdf` |
| Aklanon dictionary, same authors | `C:/Users/ACER/Desktop/Francis/Files/dokumen.pub_a-study-of-the-aklanon-dialect-volume-two-dictionary.pdf` |

Helper scripts (run from the project root):
- `node .claude/skills/chapter-prep/scripts/print_chapter.js <N>` prints every scene: index, speaker, text, translation, choices with targets and rapport, word ids.
- `node .claude/skills/chapter-prep/scripts/check_words.js "<line>" ["<line>" …]` lists each word as in the bank (id, gloss) or missing, plus bank entries sharing its root.
- PDFs: `pdftotext -layout <pdf> <scratchpad>/grammar.txt` (and `dict.txt`), then grep. The scans are OCR'd and noisy, so quote them carefully and say when a passage is unreadable. Page images can't be rendered here (no `pdftoppm`).

Before any Claude Doc call, load the `anthropic-skills:docs` skill and follow the docs connector's instructions.

## Step 1: Plan from the real state

1. Read `docs/STORY_ROADMAP.md` §6.N (build sheet), the chapter's §2.3 content defects, §7.2 vocab ids and §8 flags/quests.
2. Check what's actually in the repo; the roadmap is older than the code:
   - dialogue: `print_chapter.js N` (routers, speakers, `\` markers, translations, `rapport_delta`, flags, minigame lines)
   - levels: `scenes/world/**` (built scenes, their `SceneMarkers`, warps and `required_flag`s), `data/map_data/level_areas.json`
   - NPCs: `scenes/entities/npc_*.tscn`, sprites in `assets/sprites/npcs/`, portraits in `assets/sprites/portraits/`
   - way in: what sets the gate flags, `scripts/autoload/TourGuide.gd` `STOPS`, Rose's trip menu in the previous chapter's dialogue
   - how the previous chapter ends (is there a `chapter<N-1>_complete`?)
   - minigames available in `scripts/autoload/DialogueUI.gd`
   - quests in `data/quest_data.json`, keepsakes via `RewardManager`
   - tooling: `CHAPTERS` in `.claude/skills/playtest/scripts/autoplay.gd`, flag lists and dev warps in `scripts/ui/page_dev.gd`
   - open tracker bugs that touch this chapter's levels
3. Write `docs/CHAPTER<N>_PLAN.md` in the shape of `docs/CHAPTER3_PLAN.md`: a "Where it stands" table; 3–5 decisions to make first, each with a recommendation; a build order where each step leaves the game playable; a flags list; "Done when".
4. Ask the decisions with AskUserQuestion, recommendation first, then carry the answers into the storyboard.

## Step 2: Director's storyboard (Claude Doc)

Create the doc skeleton first: title, byline, and one pending block per section. Then open it and fill **one section per call**.

Sections:
- **Director's intent:** the one feeling of the chapter; Rose's arc in it; the family thread (plant early, pay off at the end); what the player learns; pacing (minutes, longest stretch of dialogue before the player does something); a cast table (who, role, where, voice); locations in order.
- **One section per scene**, including new scenes the plan needs (morning brief, evening home):
  - header line: **Where** (level + markers), **Trigger**, **Cutscene** id, **Dialogue** key, **Sets** (flags, quest steps)
  - shot table `| # | Picture (staging, camera) | Dialogue |`. Keep every existing line. Mark new lines **NEW** and edited ones **CHANGED** (with what changed). Put the translation in italics after each Akeanon line. Flag every Akeanon line not yet confirmed with ⚑.
  - stage with what the engine can do: `conga`, `move_npc`, `sit`/`stand` (pews and `seat.tscn`), `camera`, `fade`, `chapter_card`, `spawn_npc`, `set_flag`, emotes, item pop-ups. If a shot needs something new (e.g. a `walk_to` with an arrow marker), say so in that scene's notes.
  - choices: three options get `rapport_delta` +2 / 0 / −2. Minigames and quizzes get pass **and** fail lines, and failing never blocks the story.
  - a short **Notes** paragraph: why the scene works, what to protect, cheaper fallbacks.
- **Lines to confirm:** a table of the new Akeanon you wrote (line + intended meaning), the existing lines to check, and story calls (question + your default).

Voice guide (from Ch1–3): Rose is dry and teasing, calls the player "balikbayan", and softens only in silent beats. Elders are warm and call the player "apo". The player speaks English and tries Akeanon. Narration lines have no speaker.

Never invent Akeanon you're unsure of without a ⚑. Prefer bank words when you write new lines; `check_words.js` shows which they are.

## Step 3: Story calls

Ask the story calls (backstory, relationships, timing to the next chapter, cuts) with AskUserQuestion, up to 4 at a time, recommendation first. Write each answer into the storyboard's story-calls table as **Decided**.

## Step 4: Line-by-line Akeanon review ("ask me 1 by 1")

Go through every ⚑ line, **one question per line**, numbered "Line k of M". Each question says:
- the shot number, who speaks, and the moment (what just happened, the staging)
- the line and its current translation
- which words are missing from the bank (from `check_words.js`)
- options such as *Correct as written* / *Make it English* / *Cut the line*, with corrections typed under Other

When the user answers:
- **A correction:** put it into the storyboard right away (line + translation, then "(Corrected)" or "(Corrected, confirmed)"). If a translation is your own reading of their line, ask to confirm it in the next question.
- **A question back** ("what does X mean?", "where is this from?"): answer it before moving on. For cultural or craft facts, search the web, report what the sources say with links, and say plainly what came from memory. Look in the grammar/dictionary PDFs for language questions.
- **A rule** ("adding -i makes it more descriptive", "vowel + it → add t"): add it to Akeanon Grammar Notes in the right section (Affixes, Contractions, Repetition, Akeanon vs Hiligaynon/Tagalog, Near-synonyms, Directions, Pronouns, Spelling), with an example line and **Confirmed**, or **To confirm** when it's your inference. Cite the PDF section when the book backs it. Add new open questions as tasks.
- **"Make it more natural" / "make it a thing where…":** redesign the beat (e.g. the Ch3 café directions walk with an arrow marker), write it into the storyboard, and ask about any new Akeanon in it.
- A change that affects other lines (e.g. *hinay-hinay* → *hinayi*): find the other uses and ask whether they change too.

Keep going until every ⚑ line is decided. Then update the "Lines to confirm" lead to say what's done and what's still open.

## Step 5: Wrap up

In chat:
- the corrected lines, as a short table (shot → final line)
- **word-bank work** for implementation: words to add (with glosses), and entries to rename or fix
- what's still open
- links to the storyboard and the grammar notes

Save a snapshot of the storyboard to `docs/CHAPTER<N>_STORYBOARD.md` (see `docs/CHAPTER3_STORYBOARD.md`), with a header line linking the live doc and naming the export date and doc revision. The docs `export` tool returns the markdown only as base64 inside the tool result and doesn't save it to disk, so write the file from the doc's content rather than retyping the base64.

Then offer to implement the plan's first step.

## Things learned in Ch3 (apply them)

- The roadmap can be stale: Ch3's planned "loom house" levels were already built as `scenes/world/haboean/`. Always check the repo.
- Fact-check the craft or culture behind a scene (piña: plate → *bastos*, coconut shell → *liniwan*, knotting, *paghaboe*). Cite sources.
- Hiligaynon and Tagalog words slip in (*bal-an* → *sayod*, *habi* → *haboe*). Check with the user and the dictionary PDF.
- Contractions are written without an apostrophe. The hyphen marks the glottal stop between a vowel and a consonant (*tan-aw*).
