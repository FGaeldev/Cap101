# Chapter 3: Threads of Piña (Director's Storyboard)

> Snapshot of the Claude Doc https://claude.ai/artifact/VAVt1rJ2hKsuPTY2m1Fa2G, exported 2026-11-16 (doc rev 55). The doc is the live version; edit there and re-export.

Nov 15, 2026 · @meister

A shot-by-shot version of Chapter 3 for building the cutscenes, levels and dialogue JSON. It keeps every line from `data/dialogue/chapter3.json`, adds staging, and marks new or changed lines **NEW** or **CHANGED**. Lines I'm not sure of are flagged ⚑ and collected at the end.

## Director's intent

**The one feeling:** *slow is a skill.* Chapters 1–2 were about getting your bearings fast: airports, tours, a town in a day. Chapter 3 is the first time the game asks the player to slow down. Manang Loleng's *hinay-hinay* is the theme, and the weaving minigame starts *hinay* and ends *paspas*, so the player earns speed instead of starting with it.

**Rose's arc in this chapter:** she arrives as the bored guide ("another field trip") and bets against the player at the loom. When the player finishes a row, she quietly stops teasing for one beat. That's the first time she's impressed and doesn't hide it in time. In the café she's back to teacher mode, a little warmer.

**Jonabel's thread:** her own lola wove. Planted in the morning brief and paid off in the evening when she holds the bookmark. This is the chapter's emotional beat, and it belongs to the family, not the trip.

**What the player learns:** action words (bakae, baligya, tan-aw, hambae, sabát, bangon, dayon), pace and size words (hinay, paspas, taas, naba, bug-at, maugan), plus Ch2 colours again through the loom.

**Pacing:** about 12–15 minutes. One walk there, one place with three rooms, one walk home. Longest dialogue run: 8 lines before the player does something.

| Who | Role in Ch3 | Where | Voice |
| --- | --- | --- | --- |
| Player | the balikbayan, curious, a bit clumsy | everywhere | English, tries Akeanon |
| Rose | guide, rival, teacher | all scenes | dry, teasing; calls the player "balikbayan" |
| Manang Loleng | master weaver, host | Haboean gallery | warm, patient; calls the player "apo"; mostly Akeanon |
| Lola Jonabel | grandmother, the heart | home, scenes 0 and 5 | gentle, nostalgic |
| Lola Susan | Rose's grandmother | home, scene 0 | brisk, practical |
| 2–3 weavers | ambient, at Loom1–5 | gallery loom loft | one line each, no rapport |
| Café staff, visitors | ambient | café, outdoors | random NPCs |

**Locations:** `aklan_living` (morning, evening) → walk via Pastrana → `habuean_outdoors` (arrival) → `haboean_gallery` (loom loft: scenes 1–3) → `haboean_cafe` (scene 4) → walk home.

## Scene 0 — "Hinay-hinay" starts at breakfast (NEW)

**Where:** `aklan_living`, 07:00, the first morning after Chapter 2 is complete. **Trigger:** waking up (the `aklan_living.gd` beat check). **Cutscene:** `chapter3_scene0`. **Sets:** `chapter2_complete`, `chapter3_started`, `map_open_habuean`, starts q006.

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 0.1 | Fade in on the chapter card: *Chapter 3: Threads of Piña*. | — |
| 0.2 | Living room, morning light. Jonabel sits at the dining table, Susan stands by the kitchen. Rose leans on the wall by the door, already in shoes. Player spawns at the hallway door. Camera holds wide. | — |
| 0.3 | Rose doesn't look up from her phone. | **Rose:** Finally. I said seven, balikbayan. |
| 0.4 | Player walks to the table (auto-move 3 tiles). | **Player:** It *is* seven. |
| 0.5 | Rose pockets the phone, pushes off the wall. | **Rose:** Seven means ready at seven. We're going out of town today. The weavers. |
| 0.6 | Susan turns from the kitchen, wiping her hands. | **Lola Susan:** Manang Loleng is expecting you. Be polite, and don't touch the looms unless she says. |
| 0.7 | Jonabel sets down her cup. Small push-in on her (camera 2 tiles closer, 1 s). | **Lola Jonabel:** Piña… My lola used to weave, you know. Every afternoon, under the house. The sound of it put me to sleep. |
| 0.8 | Player faces Jonabel. | **Player:** You never told me that. |
| 0.9 | Jonabel smiles, looks at her hands. Hold 1 s, no line. | **Lola Jonabel:** I'd forgotten I remembered. Go. Tell me everything tonight. |
| 0.10 | Rose opens the door; daylight spills in. Camera pulls back to wide. | **Rose:** Hinay-hinay, Lola. We'll be back before dark. *(to Player)* Stay close. |
| 0.11 | Quest toast: *q006 Visit the piña weavers*. Rose and Player conga out the door → walk cutscene via Pastrana (like `chapter2_walk_to_bakhawan`) → `habuean_outdoors`. | — |

**Notes:** 0.7–0.9 is the plant for scene 5. Keep it short and unforced: no music change, just the push-in. In 0.10 Rose using *hinay-hinay* jokingly before the player has learned it is a small setup for scene 2. ⚑ Should Rose speak to the Lolas in Akeanon here (0.10)? I've left it English apart from the one word.

## Scene 1 — Arrival at Haboean

**Where:** `habuean_outdoors` → `haboean_gallery` (loom loft). **Trigger:** end of the walk cutscene. **Cutscenes:** `chapter3_arrive` (outdoors), `chapter3_scene1` (gallery). **Dialogue:** `scene_1_arrival_at_the_loom_house`. **Sets:** `seen_chapter3_scene1`.

**Outdoors (arrival, no dialogue box):**

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 1.1 | Fade in at `FromPastrana`. Rose a step ahead. A low, steady *clack… clack* from the gallery (loom SFX, looping, quiet). Random NPCs at their markers. | — |
| 1.2 | Rose stops, turns back to the player. Emote bubble over Rose: "…" | **Rose:** Hear that? That's the looms. Come on, inside. |
| 1.3 | Control returns. The gallery door is the only story warp; the café door says "Later" (Rose intercepts, via `TourGuide`). Quest step: *Meet Manang Loleng*. | — |

**Gallery loom loft:**

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 1.4 | Enter at `FromOutdoors`. Camera pans slowly from the exhibits up to the loom loft (camera action, 2 s), landing on Manang Loleng at the `Weaver` marker, back to the room, weaving. Two weavers at `Loom2` and `Loom4`. Loom SFX louder. | — |
| 1.5 | Loleng stops, turns, stands. Rose and Player walk up (conga to 2 tiles below her). | **Manang Loleng:** Maliya, mga bisita! Tanawa ro amon nga ginhaboe. ⚑ *Come in, visitors! Look at our weaving.* (CHANGED: simplified to bank words, confirmed) |
| 1.6 | Player looks around: face left, right, then back (anim steps). | **Player:** Whoa. Amazing, Grandma — I mean, Manang. Sorry, it's my first time seeing a loom like this. |
| 1.7 | Loleng laughs (emote: music note). Rose covers her face (emote: sweat drop). | **Manang Loleng:** Uwat kaso. Abo man nga bisita ro nangangawa iya. ⚑ *No problem. Many visitors are amazed here too.* (Confirmed. Bank: uwat kaso = "no problem", lit. "there's no case", uwat = uwa it; nangangawa = wonder, amazed.) |
| 1.8 | Rose steps beside the nearest loom, gestures at it. | **Rose:** This whole community weaves piña cloth. Been doing it for generations — older than any of us. |
| 1.9 | Loleng lifts a strand from the loom (no art needed: facing up + emote sparkle). | **Manang Loleng:** Halin ra igto sa taeamnan, sa tanum nga piña, abu-abo pa nga ro kinahangean nga ubrahon para magin eambong ra. ⚑ *This comes from over there, the farm, from the piña plant. There's still a lot of work needed before it becomes cloth.* (Corrected. Bank: add tanum = plant, kinahangean = need, abu-abo = a lot, ubrahon = to be worked on, magin = to become, ra = it/this, pa = still/more.) |
| 1.10 | **Quiz (NEW):** "*Halin ra igto sa taeamnan* means…" → It comes from the farm ✓ / It comes from the sea / It comes from the shop. Pass or fail both continue. | **Rose** (on pass): Look at you, listening. / (on fail): Taeamnan. Farm. Keep up, balikbayan. |
| 1.11 | Choice: "What's your reaction?" **CHANGED: add rapport.** | → *This is beautiful work, Manang. I'd love to learn more.* **(+2)** → 1.12 · *It's really intricate, kind of hard to understand all at once.* **(0)** → 1.12 · *This looks like it takes forever, isn't a machine faster?* **(−2)** → 1.13 |
| 1.12 | Loleng bows her head slightly. | **Manang Loleng:** Saeamat, apo. Not many young ones say that anymore. |
| 1.13 | Loleng isn't offended; she pats the loom. Rose glares at the player (emote: anger) on the −2 path only. | **Manang Loleng:** Step by step. Even I took years. |
| 1.14 | Loleng runs a hand along the threads. Hold. | **Manang Loleng:** Machines can't feel the thread the way a hand does. That's the difference. |
| 1.15 | Loleng sits back down at the loom and pats the bench beside her. | **Manang Loleng:** Gusto mo samitan mag ubra? Iya, sunod ka kakon. ⚑ *Do you want to try making it? Here, follow me.* (Corrected. Bank: add samitan, root samit = to try, taste, sample.) |

**Notes:** the camera pan in 1.4 is the chapter's establishing shot; give it time. Keep the loom SFX under every gallery scene so the place has a heartbeat. 1.15 leads straight into scene 2 if the player walks to the loom (or optional scene 1b first: Loleng's exhibits).

## Scene 1b — From plant to thread (optional, NEW)

**Where:** `haboean_gallery`, the four `Exhibits` markers. **Type:** `Comp_WorldTask` `task_pina_process`, any order, numbered labels guide the eye. **Sets:** `task_pina_process` when all four are seen. No cutscene: the player walks it in their own time. The weavers' looms stay interactable throughout.

Each exhibit is one examine box (narration speaker, no portrait), followed by one line from whoever is nearest: Rose if the player hasn't finished the quiz well, otherwise Loleng. Keep each under 2 lines on screen.

| Exhibit | What's shown | Examine text | Follow-up line |
| --- | --- | --- | --- |
| `PlinthA` — 1 | A piña plant in a pot, long spiky leaves. | A pineapple plant. The fibre comes from its leaves, not the fruit. | **Rose:** The fruit's just a bonus. Don't tell the tourists. |
| `CabinetA` — 2 | A leaf, a broken plate and a coconut shell; two piles of strands, one rough, one fine. | Leaves are scraped twice: a broken plate for the coarse bastos, then a coconut shell for the fine liniwan that cloth is woven from. | **Rose:** Plate for the rough stuff, coconut shell for the fine stuff. Don't ask me why. (Decided; sources: PhilFIDA, Philstar, PieceWork.) |
| `CabinetB` — 3 | Fibres knotted end to end into one long thread, wound on a spool. | The strands are knotted one by one into a single thread. It can take days. | **Rose:** Days. For one thread. Now you know why it's expensive. |
| `PlinthB` — 4 | A finished barong on a stand, sheer, embroidered. | Piña cloth: light, see-through, and strong. Worn for weddings and special days. | — (cut; the exhibit text carries it) |

**On completing all four:** small chime + journal note "How piña is made". **Weavers at `Loom2`/`Loom4`** (ambient, one line each, repeat): *Weaver 1:* "Hinay-hinay eang." · *Weaver 2:* (doesn't look up) "Mm. Busy, apo."

**Notes:** this is the "show, don't tell" version of Loleng's 1.9 line. It should feel like a museum walk, not homework, so no quiz at the end. The plate-scraping detail (2) is real and memorable; keep it even if the line changes.

## Scene 2 — Balikbayan versus loom

**Where:** gallery, `Loom1` (Loleng's loom, beside the `Weaver` marker). **Trigger:** interact with Loom1 after scene 1. **Cutscene:** `chapter3_scene2` (seats the player at the loom with the `sit` action, Loleng beside them, Rose behind). **Dialogue:** `scene_2_trying_the_loom`. **Sets:** `seen_chapter3_scene2`, `wove_first_row` (pass or fail).

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 2.1 | Player sits at Loom1 (sit action, walk: true). Loleng stands at their left. Rose drags a stool behind them, sits backwards on it, chin on her arms. Camera tightens on the loom (zoom 1.25). | — |
| 2.2 | Rose grins. | **Rose:** Oh, this I have to see. Balikbayan versus loom. Place your bets. |
| 2.3 | Player turns around to face her. | **Player:** Gee, thanks for the confidence, Rose. |
| 2.4 | Loleng puts a hand on the loom frame. Loom SFX from the other weavers drops to almost nothing: the room is listening. | **Manang Loleng:** Hinayi eang. Bukon ra padasigan. ⚑ *Slower, that's all. This isn't a race.* (Corrected: hinayi = slower, -i suffix; padasigan from dasig.) |
| 2.5 | Choice: "Will you try weaving on your own?" **CHANGED: add rapport.** | → *I'll take it slow, Manang. Show me the first move again.* **(+2)** → 2.6 · *Can you guide my hands through it first?* **(0)** → 2.6 · *Maybe I'll just watch, this looks too hard for me.* **(−2)** → 2.7 |
| 2.6 | Loleng nods once. | **Manang Loleng:** That's the spirit, apo. One thread at a time. → 2.9 |
| 2.7 | Loleng sits beside the player, gentle. | **Manang Loleng:** Of course. Everyone starts guided. |
| 2.8 | Rose leans forward (only on the "watch" path). | **Rose:** Come on, at least try one row. I'll laugh either way, might as well earn it. |
| 2.9 | **Minigame `weaving` (NEW).** Full screen: the loom from above, six thread spools in the Ch2 colours. Loleng calls a colour in Akeanon; the player taps it as the shuttle passes. **Row 1 — hinay:** 4 calls, slow beat, the colour word shows with its English. **Row 2:** 5 calls, medium, word only. **Row 3 — paspas:** 6 calls, fast, word only. Loleng's calls use puti, itom, puea, asul, dueaw, berdi. A finished row shows as a woven stripe in the chosen colours. Pass = 2 of 3 rows clean. | Loleng between rows: *Row 1 done:* "Dasigi it sangkiri." ⚑ *A little faster.* (Corrected: dasigi = faster, root dasig w050; sangkiri = a little, root kiri, not in the bank.) · *Row 2 done:* "Paspas!" · *A missed thread:* "Hinay-hinay…" |
| 2.10a | **Pass.** Camera back to the room. Rose doesn't speak. She sits up, looks at the cloth, looks at the player. Hold 1.5 s, no box. | **Manang Loleng:** Abah, mayad ah, para sa una nga ubra pwede eon. ⚑ *Oh, good! For a first piece of work, that'll do.* (Corrected, confirmed) |
| 2.11a | Rose, quietly, looking away. | **Rose (NEW):** …Okay. I lost the bet. Don't let it go to your head. |
| 2.10b | **Fail (soft).** The cloth has a crooked stripe. Loleng laughs warmly, not at them. | **Manang Loleng (NEW):** Sayod mo, ro akong una nga ginhaboe, mas bulok pa karon. ⚑ *You know, my first weaving was worse than that.* |
| 2.11b | Rose, grinning but not mean. Offer "Try again?" (Yes → 2.9 / No → scene 3). | **Rose (NEW):** I'd have laughed, but… honestly, mine was worse too. |

**Notes:** the silence in 2.10a is the emotional peak of Rose's arc in this chapter. Don't fill it with music or an emote. The minigame stand-in until `weaving` exists: `memory_match` on the six colour words, same pass/fail lines. Set `wove_first_row` on both outcomes so a fail never blocks the story.

## Scene 3 — Tanda: the piña bookmark

**Where:** gallery, by Loom1, straight after scene 2. **Cutscene:** continues `chapter3_scene2` (no load). **Dialogue:** `scene_3_closing_gift`. **Sets:** `got_pina_bookmark` (keepsake via `RewardManager`), `story_done_ch3_loleng`. Quest step: *Try the loom* done.

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 3.1 | Player stands up from the loom (stand action). Loleng walks to `CabinetA`, takes something small, walks back. Rose stands too, kicks the stool back. | — |
| 3.2 | Loleng holds it out with both hands. Item pop-up: the bookmark (art: a slim cream strip of piña with a red-and-blue woven band and a tassel). | **Manang Loleng:** Hara, batuna, tanda halin sa amon nga komunidad. *Here, take this. A token from our community.* |
| 3.3 | **NEW line**, so the gift is named on screen. Loleng taps the woven band. | **Manang Loleng:** Para sing mga libro, ag agod indi mo kami malipatan. ⚑ *For your books, and so that you won't forget us.* (Corrected; the item pop-up names the bookmark. Bank: add sing = "your", short for sa imo nga.) |
| 3.4 | Player takes it with both hands (bow anim if available, else face down 0.3 s). Keepsake toast: *Piña bookmark added to your Journal.* | **Player:** Saeamat gid, Manang. I'll keep this. (CHANGED: double space) |
| 3.5 | Loleng walks them toward the stairs. | **Manang Loleng:** Mag-dahan kamo sa biyahe. Balik kamo kung may oras. ⚑ *Take care on your trip. Come back when you have time.* (Corrected; kamo = you, plural, to both Rose and the player.) (CHANGED: capitals) |
| 3.6 | ~~Loleng waves the player close~~ **CUT** (decided). | — |
| 3.7 | **CUT** with 3.6. | — |
| 3.8 | Rose heads down the stairs toward the café door. | **Rose:** Not bad for your first field trip, balikbayan. Two down, more to go. ⚑ |

**Notes:** 3.6–3.7 are cut; Rose's silent beat in 2.10a and her "mine was worse too" in 2.11b carry her side of the chapter. ⚑ 3.8 says "first field trip" and "two down": Chapter 2's town tour is arguably the first trip, so I'd change it to "Not bad for a field trip, balikbayan. Two down, more to go."

## Scene 4 — Verbs over coffee

**Where:** `haboean_cafe`, Rose and Player at `Seats/Table1Left` and `Table1Right`. **Trigger:** enter the café after scene 3 (Rose is already seated; talk to her). **Cutscene:** `chapter3_scene4`. **Dialogue:** `scene_4_vocabulary_practice_round_verbs_and_pace_words`. **Sets:** `seen_chapter3_scene4`.

The room is the lesson: every verb Rose names is happening in the café as she says it. The NPC actions are cutscene steps on the staff and random NPCs, timed to the lines.

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 4.1 | Player sits opposite Rose (sit action, walk: true). Two cups on the table (tile). Barista at `Staff/Barista`, a visitor queueing in front. A second visitor sits at a bench. | — |
| 4.2 | A visitor gets up from `BenchLeft1` (stand action) and walks to the door. Rose nods at them. | **Rose:** Tan-awa sanda. Panaw — to walk… wait, save that one. Bangon — to get up, like when you fall. |
| 4.3 | Player watches the visitor leave. | **Player:** These make sense with the actions right in front of us. |
| 4.4 | Rose crooks a finger at the player ("come here"), then points at the door ("go there"). | **Rose:** That's the point. Now, getting around. (Leads into the directions walk below: 4.4a–4.4g.) ⚑ (CHANGED: capitals and spacing) |
| 4.5 | At the counter the visitor pays, the barista hands over a cup. Rose points at each in turn. | **Rose:** Bakae — to buy. Baligya — to sell. Tan-aw — to look, to see. Hambae — to speak. Sabát — to answer. |
| 4.6 | Choice: "Will you try using the new words?" **CHANGED: add rapport.** | → *I'll try — "Gusto ko mag bakae," I want to buy? Something like that?* **(+2)** → 4.7 · *I get the meanings, but it's still hard to use them correctly.* **(0)** → 4.7 · *There are too many verbs now, I'm losing track.* **(−2)** → 4.8 |
| 4.7 | Rose raises her cup at the player. | **Rose:** Close enough! You're building sentences now, not just words. |
| 4.8 | Rose slides the player's cup closer. | **Rose:** That's normal. Meaning first, grammar later. |
| 4.9 | Both drink. Short pause (0.8 s). | **Rose:** Deep breath. We'll circle back to these. No rush. |
| 4.10 | **Quiz (NEW), 3 questions:** match the action in the room to the verb. "The visitor gives money for a coffee" → *bakae* ✓ / baligya / hambae. "The barista hands over the cup for money" → *baligya*. "Rose asks, you…" → *sabát*. | Rose on pass/fail, reusing 4.7/4.8 tone. |
| 4.11 | Rose points out of the window at the loom house roof (camera nudges toward the window). | **Rose:** Taas — tall, or long. Naba — short. Paspas — fast. Hinay — slow. Manang's "hinayi" means slower, and "hinay-hinay" means little by little. (CHANGED to match 2.4) |
| 4.12 | Rose lifts her full cup, then the empty one. | **Rose:** Bug-at — heavy. Maugan — light, not bug-at. Small words, but you'll need them everywhere. (CHANGED: removed the leftover gap) |
| 4.13 | | **Rose:** Kuntra naman — "against." Rarely used, but good to know. |
| 4.14 | **Memory match (NEW):** opposite pairs taas/naba, paspas/hinay, bug-at/maugan. | — |
| 4.15 | Player slumps in the chair. | **Player:** My head's kind of full now, but I think I actually get most of it. |
| 4.16 | Rose stands. | **Rose:** That's the goal. Not perfect. Just moving forward. |
| 4.17 | **NEW, pays off 4.2.** Rose at the door, looking back. | **Rose:** And panaw? To walk. Told you I'd save it. Let's panaw home, balikbayan. |

**Directions walk (4.4a–4.4g, NEW).** The player learns the direction words by walking them. Each leg: Rose gives the instruction in Akeanon, an **arrow marker** appears over the destination (reuse the quest-marker arrow), and control returns until the player steps into the target area. Text-box hints show the English only after a wrong move.

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 4.4a | Rose drains her cup, sets it down, stands. | **Rose:** Refill. Your treat, balikbayan. First, words. |
| 4.4b | Rose waves the player toward her (they stand up from the seat), then points across the room. | **Rose:** Maliya — come here. Agto — go. Igto — there. Diretso — straight. Liko — turn. Tuo — right. Waea — left. Dayon — then, or "continue." |
| 4.4c | **Leg 1.** Arrow appears over the counter. Rose points. | **Rose:** Agto igto sa counter, diresto kat sangkiri, tapos liko pa tuo. ⚑ *Go there to the counter, straight for a little bit, then turn to the right.* (Corrected) |
| 4.4d | Player walks. Wrong way (left, or toward the door) → Rose calls out once, the arrow pulses. | **Rose:** Tuo! Your other right, balikbayan. *(on a wrong turn)* |
| 4.4e | Player reaches the counter (target area). The barista hands over a cup; **this is where 4.5 plays** (bakae / baligya happen for real). | — |
| 4.4f | **Leg 2.** Arrow appears over the table. Rose, sitting back down, waves. | **Rose:** Maliya! Liko sa waea, dayon diretso. ⚑ *Come here! Turn left, then straight.* |
| 4.4g | Player reaches the table and sits (seat interact). | **Rose:** See? You didn't even need a map. |

**Build notes:** a `walk_to` cutscene step that shows the arrow on a marker (`SceneMarkers/Cafe/Counter`, `Cafe/Table1`), waits for the player to enter it, and fires optional `wrong_way` lines when the player enters a "wrong" area. The routes must really be straight-then-right and left-then-straight in the café layout; pick the counter and table spots to match. Words to add to the bank: maliya (have w150), agto (w004), igto (w082), diretso, liko, tuo, waea, dayon (w053).

**Notes:** this is the chapter's biggest word dump, so it's broken into three bursts with something to *do* after each (choice, quiz, memory match). If the staging steps are too costly, keep 4.2 and 4.5 (the walker and the purchase) and drop the rest: they carry the idea.

## Scene 5 — The sound of the loom (NEW)

**Where:** walk home (Haboean → Pastrana → home street) → `aklan_living`, dusk, 18:00+. **Trigger:** leaving the café after scene 4. **Cutscenes:** `chapter3_walk_home` then `chapter3_scene5`. **Sets:** `seen_chapter3_scene5`, `chapter3_complete`; q006 done. The bed then offers sleep into the next chapter.

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 5.1 | Walk home: conga, Rose leading, sunset tint. No dialogue on the walk. Let the day settle. | — |
| 5.2 | Living room, lamps on. Jonabel at the dining table, a cup in front of her. Susan and Jobert on the sofa (`Seats/SofaTop`, `SofaBottom`). Rose drops onto a dining chair. Player enters at the door. | **Lola Susan:** There they are. Did you behave, Rose? |
| 5.3 | Rose, deadpan. | **Rose:** I always behave. Ask the balikbayan how the loom went. |
| 5.4 | Player walks to Jonabel (auto-move) and sits at the table across from her. | **Lola Jonabel:** Well? Tell me everything. |
| 5.5 | **Branch on scene 2:** pass → | **Player:** I wove a whole row. Rose lost a bet. |
| 5.5b | fail → | **Player:** I wove a row. A very crooked row. |
| 5.6 | Rose, from her chair, not looking up. | **Rose:** It was… fine. *(pass)* / It was crooked. *(fail)* |
| 5.7 | Player takes out the bookmark (item pop-up, same art as 3.2) and hands it across the table. | **Player:** Manang Loleng gave me this. I thought you should see it. |
| 5.8 | Jonabel takes it. Push-in on her (camera, slow, 2 s). Ambient sound fades; very faint loom SFX fades in under the scene: a memory. | — |
| 5.9 | Jonabel runs her thumb along the woven band. | **Lola Jonabel:** My lola made one just like this for my missal. I lost it when we moved to America. Fifty years ago. |
| 5.10 | She holds it out to give it back. Player doesn't take it: choice. | → *Keep it, Lola. It's yours now.* **(+2 Jonabel)** · *Can we share it? I'll leave it in your missal.* **(+1 Jonabel)** · *(Take it back.)* **(0)** |
| 5.11 | (Keep / share) Jonabel holds it to her chest. Susan looks over from the sofa, smiles at Jobert. | **Lola Jonabel:** Saeamat, apo. Now I'll hear the loom when I read. |
| 5.11b | (Take it back) Jonabel presses it into the player's hand, warmly. | **Lola Jonabel:** Good. Use it. And go back and see her one day. |
| 5.12 | Loom SFX fades out. Room sound returns. Rose stands, stretches. | **Rose:** Okay, that's enough feelings for one day. Sleep, balikbayan. Tomorrow's mud. ⚑ |
| 5.13 | Quest complete: *q006*. Control returns. The bed glows (sleep prompt). | — |

**Notes:** whatever the player chooses at 5.10, the keepsake stays in the Journal (it records the gift, not who holds it). Store the choice as `ch3_bookmark_to_jonabel` for an epilogue callback. Jonabel's idle lines about the bookmark from here on are gated on `got_pina_bookmark`. 5.12's "Tomorrow's mud" teases Bakhawan's mangroves (Chapter 4); ⚑ drop it if Chapter 4 won't be the next day.

## Lines to confirm ⚑

**New Akeanon I wrote.** All reviewed line by line on 2026-11-16: the corrected lines are in the scenes above, and the rules learned are in Akeanon Grammar Notes. Still open: leg 2 of the café directions (4.4f) and the diretso / diresto spelling.

| # | Line | Meant to say |
| --- | --- | --- |
| 1b-2 | Ginagamit namon ro pinggan. | We use a plate (to scrape the leaves). |
| 1b-4 | Para sa mga importante nga adlaw. | For important days. |
| 2.9 | Mayad. Medyo paspas. | Good. A little faster. |
| 2.10b | Sayod mo, ro akong una nga ginhaboe, mas bulok pa karon. (Corrected) | You know, my first weaving was worse than that. |
| 3.3 | Para sing mga libro, ag agod indi mo kami malipatan. (Corrected) | For your books, and so you won't forget us. |
| 3.6 | Ag si Rose? Kada adlaw ina nagahambae parte kimo. | And Rose? She talks about you every day. |

**Existing Akeanon to check** (roadmap §7.4 already asks for a review of the first three): 1.5 "Naabi abi gid namon…", 1.7 "Uwat kaso…", 2.4 "Hinay-hinay eang. Bukon ra padasigan.", 1.9, 1.15, 2.10a, 3.5, 4.4 ("Agto iya / Agto idto").

**Story calls:**

| # | Question | Decision |
| --- | --- | --- |
| 3.6 | How does Loleng know Rose so well? | **Decided:** Rose came here as a kid with Lola Susan and wove her first row with Loleng. It was worse than the player's, which is why 2.11b works. |
| 5.9 | Jonabel's backstory | **Decided:** fifty years in the US; the bookmark was for her missal. |
| 5.12 | Is Chapter 4 the very next day? | **Decided:** yes, keep "Tomorrow's mud." |
| 0.10 | Does Rose talk to the Lolas in Akeanon at home? | Default kept: English with one Akeanon word. |
| 3.8 | Which trip is the "first field trip"? | Default kept: "Not bad for a field trip, balikbayan. Two down, more to go." |
| 3.2 | The bookmark's look | Default kept: cream piña, red-and-blue band, tassel. |
| Akeanon | Who checks the lines above? | You correct them; the ⚑ stays on each until it's done. |
