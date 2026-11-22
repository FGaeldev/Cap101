# Chapter 2: Kalibo Town (Director's Storyboard)

> Snapshot of the Claude Doc https://claude.ai/artifact/THhvpphGphSxvW1zeKfNtv, exported 2026-11-16 (doc rev 140). The doc is the live version; edit there and re-export.

Nov 16, 2026 · @meister

A shot-by-shot version of Chapter 2 for polishing the cutscenes and dialogue JSON. Chapter 2 already plays end to end; this keeps every line from `data/dialogue/chapter2.json`, adds staging, and marks new or changed lines **NEW** or **CHANGED**. Every Akeanon line was reviewed one at a time on 2026-11-16; the results are collected at the end. Plan: `docs/CHAPTER2_PLAN.md`.

## Director's intent

**The one feeling:** *this town is yours too.* Chapter 1 was a reunion with people. Chapter 2 is a reunion with a place: the park Lola Jonabel walked through, the church she sat in, the vendor who still knows the family. Every stop should make the player feel recognised before they feel taught.

**Rose's arc in this chapter:** she starts as the reluctant tour guide ("Finally. Let's start with the park.") and treats the player as a tourist. At the market she sees them try *pangabay* on a real vendor, and at the cathedral she hands over her own map. By dinner she has stopped calling the trip a chore. She still won't say it out loud.

**The family thread:** Lola Jonabel's past in Kalibo. Plant it at the cathedral (Susan: "your Lola Jonabel was the most devout"; Jonabel: "we were all equally naughty"). Pay it off at dinner (scene 5), when Jonabel asks what the player saw and quietly names one place she missed. That line also points at Chapter 3 without Rose spelling out the trip.

**What the player learns:** places (*lugar, mapa, agtunan*), market words (*pangabay, suki, eab-as, matam-is*), food (*isda, manok, itlog, bugas, tinapay, karne, baboy*), numbers 6–10, six colours, size and age (*maisot, mabahoe, bag-o, daan*), *pointing words (daya, duyon, dato), and the days of the week*.

**Pacing:** about 15–20 minutes for the tour, plus a short Sunday mass trip. Three stops, each with a walk between. Longest dialogue run before the player acts: 6 lines (the cathedral talk, before the map choice). The souvenir-shop round is long, so it is broken up by two quizzes and a choice.

| Who | Role in Ch2 | Where | Voice |
| --- | --- | --- | --- |
| Player | the balikbayan, first full day in town | everywhere | English, tries Akeanon |
| Rose | tour guide, teacher | all stops | dry, teasing; calls the player "balikbayan" |
| Nong Pedring | the family's regular vendor (*suki*) | park, then his market stall | warm, quick to laugh; calls the player "apo"; mostly Akeanon |
| Lola Susan | Rose's grandmother, the host | home, cathedral, mass | brisk, practical, proud of the town |
| Lola Jonabel | the player's grandmother | home, cathedral | gentle, nostalgic, a little mischievous |
| Papa Jobert | the player's father | home | quiet, tired from the flight |
| Vendors, townsfolk | ambient | park, market | random NPCs, no lines |

**Locations in order:** `aklan_living` (arrival, night, morning) → `aklan_home_outdoors` → `pastrana_outdoors` (park) → `market_outdoors` / `market_indoors` → `pastrana_outdoors` (cathedral front, `S3` markers) → home (dinner) → Sunday: `cathedral_indoors` → market → home.

## Scene 0: Home at last

**Where:** `aklan_living`, front door → `S0/Rose`, `S0/Susan`, `S0/Jonabel`, `S0/Jobert`, `S0/Player` · **Trigger:** arrival warp from `airport_ourdoors` (`EdgeExit_Ch2`) · **Cutscene:** `chapter2_scene0` · **Dialogue:** `scene_0_home_atlast` · **Sets:** `seen_chapter2_scene0`; the bed then sets `chapter2_slept`

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 0.1 | `chapter_card` "Chapter 2: Kalibo Town" over black. | — |
| 0.2 | Fade in on the living room. Conga through the front door, Rose leading, then Susan, Jonabel, Jobert, the player. Each peels to their `S0` mark. Camera holds wide on the room. | — |
| 0.3 | Susan turns to face the group, arms open. | **Lola Susan:** Welcome home everyone! |
| 0.4 | Susan, same shot. Jobert stifles a yawn; bubble over Jobert: zzz. | **Lola Susan:** That flight must have worn you all out. Go on upstairs and sleep in your rooms. |
| 0.5 | Susan points toward the hallway. Bubble over Susan: star. | **Lola Susan:** Look next to the doors. Yours is the one with the *bituon*. *(Yours is the one with the star.)* (Confirmed) |
| 0.6 | Same. Bubble over Susan: moon, then sun, as she names each. | **Lola Susan:** Jonabel has the *buean*, and Jobert has the *adlaw*. *(Jonabel has the moon, and Jobert has the sun.)* (Confirmed) |
| 0.7 **NEW** | Rose, already halfway to the stairs, stops and looks back at the player. | **Rose:** Rest up, balikbayan. When you're up tomorrow, come find me. I'll show you the town. |
| 0.8 **NEW** | Silent beat. Jonabel stays by the window a moment, looking out at the street, then follows the others. No camera move. | *(narration)* Lola Jonabel stays by the window a little longer than the others. |
| 0.9 | Player is free. Door signs (star, moon, sun) on the upstairs doors. Sleeping in their own bed fades to the next 6 AM. | — |

**Notes.** The scene works because it's short: a long flight, a tired family, a bed. Rose's NEW line hands the player the next goal (find Rose) before Susan repeats it in scene 0b, and the Jonabel beat plants the family thread with no words. Protect the door-sign game: it's the first time the player reads Akeanon to find their way. Cheaper fallback for 0.8: cut it; the dinner scene still pays the thread off.

## Scene 0b: The first morning

**Where:** `aklan_living`, Susan at her morning spot (`npc_schedule.json`), Rose in the house · **Trigger:** first time in the living room after `chapter2_slept`, once Susan is there (`aklan_living.gd._check_beats`) · **Cutscene:** `chapter2_scene0b` · **Dialogue:** `scene_0b_ask_rose` · **Sets:** `seen_chapter2_scene0b` (opens the front door); q005 starts here (**NEW**, see the q005 section)

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 0b.1 **CHANGED** (Akeanon greeting added in front) | Player comes down the stairs. Susan looks up from the table and smiles. | **Lola Susan:** *Mayad nga agahon!* There you are! Did you sleep well? *(Good morning! …)* (Corrected, confirmed: the Chapter 1 form) |
| 0b.2 | Susan nods toward Rose across the room. | **Lola Susan:** Whenever you want to look around, always ask Rose to go with you. |
| 0b.3 **NEW** | Quest pop-up: "Explore Kalibo with Rose". | — |
| 0b.4 | Player is free. Talking to Rose opens her trip menu (`scene_rose_walk_to_park`): "Can you show me around?" → **Rose:** Finally. Let's start with the park. Stay close. (sets `chapter2_with_rose`) | **Rose:** Need something, balikbayan? |

**Notes.** Susan's greeting reuses the Chapter 1 phrase the player already knows, so the first Akeanon of the day is one they can read. The scene stays two lines on purpose: the player has just woken up and wants to go out. Rose's "Finally" is the start of her arc (the reluctant guide), so keep it.

## Scene 1: Pastrana Park and Nong Pedring

**Where:** `pastrana_outdoors`, `S1/RoseStart` → `S1/ParkGate` → plaza; Pedring `S1/Pedring Start` → `S1/PedringStand` · **Trigger:** arrival with Rose (`pastrana_outdoors.gd._next_cutscene`); the Pedring half plays when the player talks to Rose again · **Cutscenes:** `chapter2_scene1`, then `chapter2_park_meet_pedring` · **Dialogue:** `scene_1_pastrana_park_morning_walk`, `scene_1_meet_pedring` · **Sets:** `chapter2_arrived_park`, `seen_chapter2_scene1`; q005 step "Pastrana Park" (**NEW**)

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 1.1 | Fade in at the park gate. Conga: Rose leads the player through `S1/ParkGate` into the plaza. Joggers and walkers (random NPCs) cross the frame. | — |
| 1.2 | Rose stops, turns, one arm out at the park. | **Rose:** *Raya do Pastrana Park. Ga tikang iya ro mga tawo kon agahon.* *(This is Pastrana Park. People walk here in the mornings.)* (Corrected, confirmed) |
| 1.3 | Player looks around (face left, then right). | **Player:** It's nice here. Peaceful, unlike the busy streets in the States. |
| 1.4 | Rose, smirking. | **Rose:** Wait until festival season. Not peaceful at all then. But that's later. |
| 1.5 | Rose steps aside. Player is free to explore the park. | **Rose:** Look around first, balikbayan. Talk to me when you want to keep going. |
| 1.6 | Player talks to Rose. Pedring walks in from `S1/Pedring Start` with a basket, stops at `S1/PedringStand`. Rose waves him over. | **Rose:** *Ruyon, si Nong Pedring. Suki namon igto sa tindahan.* *(That's Nong Pedring. He's our regular vendor at the market.)* (Confirmed) |
| 1.7 | Choice. | *Will you talk to Nong Pedring?* → **CHANGED** "*Mayad nga agahon!* I'm Jonabel's grandchild." (+2, corrected, confirmed; was "Good morning! I'm here with Jonabel's family.") · "Uh, hi. Sorry, I'm still nervous speaking Akeanon." (0) · "I'll just wait here, you go ahead." (−2) |
| 1.8 (+2) | Pedring beams, sets the basket down. | **Nong Pedring:** *Mayad man nga agahon, apo ka gali ni Jonabel. Siin ka halin?* *(Good morning to you too! So you're Jonabel's grandchild. Where are you from?)* **CHANGED** (Corrected) |
| 1.8a **NEW** (+2) | Player answers. | **Player:** From the States. California. |
| 1.8b **NEW** (+2) | Pedring laughs, shakes his head. | **Nong Pedring:** *Abaw, abroad gid gali!* *(Wow, all the way from abroad!)* (Corrected, confirmed) |
| 1.9 (0) | Pedring, kindly, pats the air: slow down. | **Nong Pedring:** *Ayaw manirbyus.* Slow only. Learning takes time, *apo*. *(Don't be nervous. …)* **CHANGED** (Corrected, confirmed: ma- + the loan word nirbyus, written joined) |
| 1.10 (−2) | Rose rolls her eyes and greets Pedring for both of them. | **Rose:** Suit yourself. But you'll have to talk to people eventually. |
| 1.11 **CHANGED** (split; first half now Pedring's) | Pedring picks up his basket and heads for the market, waving back. | **Nong Pedring:** *Sunod kamo sa tindahan.* *(Come by the market, you two.)* (Corrected, confirmed: tindahan) |
| 1.12 **CHANGED** (*iya* → *idto*: they're at the park, the market is "there") | Rose watches him go, then nods at the player. | **Rose:** *Idto kita magtuon it mga pangaean.* *(That's where we'll learn the names of things.)* (Confirmed) |

**Notes.** This is the player's first stranger in Akeanon, so the +2 path now lets them *say* the Chapter 1 greeting instead of reading English. Pedring's question ("Siin ka halin?") was left unanswered; 1.8a–b close it with a laugh. The old last line had Rose say "follow (you all)" to the player and "here" about the market; splitting it fixes both. Protect Rose's "Suit yourself": the −2 path should sting a little. Story call* decided: he is Nong Pedring*.

## Scene 1b (NEW): Food words on the way in

**Where:** `market_outdoors`, the outdoor stalls between the street and the hall door · **Trigger:** the walk-in cutscene that `market_outdoors.gd` plays after `chapter2_park_to_market`, first time only · **Cutscene:** the market\_outdoors walk-in (add a `dialogue` step, gated `if_flag` not `seen_chapter2_scene1b`) · **Dialogue:** `scene_1b_food_words` (**NEW**; lines moved from scene 4 idx 13–16) · **Sets:** `seen_chapter2_scene1b`

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 1b.1 | Conga arrives from the street. Outdoor stalls: fish on ice, live chickens, egg trays, rice sacks, a bread stand. Rose stops before the hall door. | — |
| 1b.2 **NEW** | Rose turns to the player, thumb at the stalls. | **Rose:** Before we go in. You'll want these. |
| 1b.3 **MOVED** (was 4.14) | **CHANGED** (camera pan → bubbles) Camera holds on Rose by the stalls. A picture bubble over her changes with each word as the text reaches it: fish, chicken, egg, rice sack, bread, meat, pig. | **Rose:** *Isda* — fish. *Manok* — chicken. *Itlog* — egg. *Bugas* — rice. *Tinapay* — bread. *Karne* — meat. *Baboy* — pig. (Corrected, confirmed: bugas = uncooked rice, humay = cooked rice) |
| 1b.4 **MOVED, CHANGED** (was 4.15; "heading to the market" → "going in right now") | Player, overwhelmed. | **Player:** Okay, that's a lot of food words. Good thing we're going in right now. |
| 1b.5 **MOVED** (was 4.16) | Rose, already walking. Stops. | **Rose:** Exactly why I taught them now. Use it or lose it, balikbayan. |
| 1b.6 **NEW** | Rose blocks the door with one arm. | **Rose:** Quick check first. |
| 1b.7 **NEW** quiz | `quiz`, dynamic, 3 questions, pool w091 *isda*, w152 *manok*, w093 *itlog*, *bugas (new bank entry)*, w230 *tinapay*, w107 *karne*, w024 *baboy*; templates "What does "\[word\]" mean?" / "What Akeanon word means "\[gloss\]"?"; `pass_ratio` 0.5. | — |
| 1b.8 **NEW** (pass) | Rose drops her arm, holds the door. | **Rose:** Not bad. Now try them on a real vendor. |
| 1b.9 **NEW** (fail) | Rose shrugs and holds the door anyway. | **Rose:** Close enough. You'll hear every one of them inside. |
| 1b.10 | Conga into the hall (`market_indoors`), scene 2 continues. | — |

**Notes.** The words now arrive right where the player can see them, and the market scene that follows uses *bugas*, *uga* and *tubi* in Pedring's first line, so the quiz pays off within a minute. The picture bubbles pair each word with its picture, so the player learns isda as a fish, not as the English word. Fail never blocks: both branches walk in. Language check for the review: *bugas (uncooked rice) replaced humay (cooked rice), confirmed;* and *tinapay* / *karne* may be Tagalog or Spanish loans.

## Scene 2: The public market

**Where:** `market_indoors`, entry `Down` → `S2/Rose`; Pedring at his stall `S2/Pedring` (placed by `stall_vendors.gd`) · **Trigger:** arrival with Rose; the talk plays when the player talks to Rose · **Cutscenes:** `chapter2_scene2`, then `chapter2_market_talk` · **Dialogue:** `scene_2_kalibo_public_market`, `scene_2_market_talk` · **Sets:** `chapter2_arrived_market`, `seen_chapter2_scene2`, `map_open_market`, `bought_star_fruit` (+2 path, **NEW**); q005 step "Market" (**NEW**)

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 2.1 | Fade in at the hall entrance. Conga to `S2/Rose`. Vendors at every stall marker. | *(narration)* The market is full of color and noise — fruits, fish, cloth, everything mixed together. The smell of dried fish and freshly cooked rice fills the air. |
| 2.2 | Rose steps back. Player is free. | **Rose:** Go on, look around. Talk to me when you are done. |
| 2.3 | Player talks to Rose; she walks them to Pedring's stall. Pedring spreads his arms over his goods. | **Nong Pedring:** *Ano ing gusto, apo? Abo iya nga bugas, tubi, uga.* *(What would you like, apo? There's plenty here: rice, water, dried fish.)* (Corrected, confirmed: alin → ano, humay → bugas) |
| 2.4 | Player leans over the stall. | **Player:** Everything smells so good. |
| 2.5 | Player turns to Rose, half whispering. | **Player:** Rose, how do I say I want this? |
| 2.6 | Rose, arms crossed. | **Rose:** Say "*pangabay*" first. Means please. Basic manners, balikbayan. (Confirmed) |
| 2.7 **NEW** | Rose points at the fruit, then at the player. | **Rose:** Then "*it daya*", this one. He's older, so add "*Nong*" and "*ho*". Point when you say *daya*. **CHANGED** (was "gusto ko it daya") (Corrected, confirmed) |
| 2.8 | Player points at a round, ridged yellow fruit. | *(narration)* Player points at a round fruit, unfamiliar. |
| 2.9 **NEW** phrase builder | `phrase_builder`, prompt "Ask Nong Pedring for the fruit". Tiles: *pangabay, it, daya, Nong, ho, gusto, dato*. Answer: *pangabay it daya Nong ho*. | — |
| 2.10 **NEW** (pass) | Pedring's eyebrows go up. He looks at Rose. Bubble over Pedring: !. | **Nong Pedring:** *Abaw! Batian mo to, apo?* *(Wow! Did you hear that, apo?)* (Corrected, confirmed) |
| 2.11 **NEW** (fail) | Rose leans in and whispers; the player repeats it slowly. Pedring waits, smiling. | **Rose:** *Pangabay it daya, Nong, ho.* Again, slowly. *(May I have this one, Nong, please.)* (Corrected, confirmed) |
| 2.12 **CHANGED** (both paths; "Pangabay, what's that?" → a follow-up) | Player, still pointing. Bubble over the player: ?. | **Player:** …What is it, anyway? |
| 2.13 | Pedring holds one up. Bubble over Pedring: star fruit (whole, plus a star-shaped slice). | **Nong Pedring:** Star fruit, *apo*. *Matam-is imaw.* *(Star fruit, apo. It's sweet.)* (Corrected, confirmed: no Akeanon name; *gid* → *imaw*) |
| 2.14 | Choice. | *Will you buy it?* → "Yes, *pangabay*, I'd like to try it." (+2) · "Maybe later, let me look around first." (0) · "I'm okay, I'm not a fan of exotic fruits, sorry." (−2) |
| 2.15 (+2) | Pedring wraps it in paper. Bubble over the player as they take it: star fruit. `set_flag` `bought_star_fruit`. | **Nong Pedring:** Enjoy! **CHANGED** (was "Mayad! Dahan sa pagkaon."; dropped, English) |
| 2.16 (0) | Pedring waves it off. | **Nong Pedring:** That's fine, my goods won't disappear quickly. |
| 2.17 (−2) | Rose takes one herself and bites it. | **Rose:** Your loss. This is literally one of the best things here. |
| 2.18 | Pedring, to both of them. | **Nong Pedring:** *Siin do masunod ninyo nga agtunan? Magsimba?* *(Where are you off to next? To church?)* (Corrected, confirmed: magsimba joined) |
| 2.19 **NEW** | Rose, already turning to go. | **Rose:** The cathedral. Thanks, Nong. |

**Notes.** The scene's job is the player's first real request, so the phrase builder sits exactly where the player asks "how do I say I want this?" Pass and fail both reach 2.12, and fail is gentle (Rose whispers, no penalty). The old 2.5 "Pangabay, what's that?" used *pangabay* as "excuse me"; now it's used as "please" in a full request, which matches Rose's explanation. *The fruit keeps its English name, star fruit (decided in the review)*. *Rose calls him Nong in 2.19, matching the decided title*.

## Scene 3: The cathedral

**Where:** `pastrana_outdoors`, cathedral front; Rose `FromMarket` → `S3/Rose`; Susan `S3/SusanEnter` → `S3/Susan`, Jonabel `S3/JonabelEnter` → `S3/Jonabel` · **Trigger:** arrival from the market with Rose; the talk plays when the player talks to Rose · **Cutscenes:** `chapter2_tour_to_cathedral`, then `chapter2_cathedral_talk` (first half) · **Dialogue:** `scene_3_kalibo_cathedral_midday`, `scene_3_cathedral_talk` · **Sets:** `chapter2_arrived_cathedral`, `seen_chapter2_scene3`, `got_kalibo_map` (**NEW**); q005 step "Cathedral" (**NEW**)

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 3.1 | Fade in from the market side. Conga to `S3/Rose`. Camera tilts up the cathedral front, then settles. People going in and out. | *(narration)* A large church, strong walls, people going in and out — everyday life, not just for festivals. |
| 3.2 | Rose stops. Player is free. | **Rose:** Take your time, balikbayan. Talk to me when you are ready. |
| 3.3 | Player talks to Rose. Susan and Jonabel walk in together (parallel `move_npc`), Susan facing right, Jonabel left. | **Lola Susan:** *Iya kami kato tanan pirme ga simba. Inyong Lola Jonabel gid ro pinaka masueundun.* *(Back then, we all always went to church here. Your Lola Jonabel most of all, she was the most devout.)* (Corrected, confirmed) |
| 3.4 | Jonabel laughs, swats Susan's arm. | **Lola Jonabel:** (laughs) Don't believe her, *Apo*. We were all equally naughty back then. |
| 3.5 **NEW** | Silent beat. Jonabel looks up at the bell tower; bubble over her: bell. Camera holds on her for two seconds (pays off at 5.8, "how loud the bells are"). Susan notices and says nothing. | — |
| 3.6 | Everyone sits on the plaza benches (`sit` on `seat.tscn` at `S3`, if placed; otherwise they stand in a half circle). Rose unfolds a paper map. | *(narration)* The group sits outside the church, Rose holding a town map. |
| 3.7 | Rose hands the map over. Bubble over Rose: map, then over the player as they take it. `set_flag` `got_kalibo_map`. | **Rose:** *Hara, tan-awa. Mapa it Kalibo. Kon magtuon ka it mga lugar, mas madali ka makaagto bisan siin.* *(Here, look. A map of Kalibo. If you learn the places, you'll find your way anywhere more easily.)* (Confirmed) |
| 3.8 | Choice. | *What will you say to Rose?* → "This is actually really helpful. *Saeamat*, Rose." (+2) · "I'll try to remember the names, no promises though." (0) · "A physical map? Can't I just use my phone?" (−2) |
| 3.9 (+2) | Rose looks away, pleased. | **Rose:** See, not completely hopeless after all. |
| 3.10 (0) | Rose raises an eyebrow. | **Rose:** That's more effort than I expected, honestly. |
| 3.11 (−2) | Rose folds the map back into the player's hands anyway. | **Rose:** Sure, and when your phone dies, then what, balikbayan? |
| 3.12 **CHANGED** (was the piña-weavers line; it moves to Ch3's morning brief, and Rose teases it at dinner, 5.7) | Susan stands, helps Jonabel up. | **Lola Susan:** We'll go ahead home. Don't keep them out too long, Rose. |
| 3.13 | Susan and Jonabel walk back out (`S3/SusanEnter`, `S3/JonabelEnter`) and despawn. | — |
| 3.14 **NEW** | Rose nods at the little shop beside the church. | **Rose:** One more stop. Round two, balikbayan. |

**Notes.** The cathedral is where the family thread is planted: Susan's teasing gives Jonabel a past here, and the silent look at the tower (3.5) says more than a line would. Moving the piña line out keeps Chapter 3's news for Chapter 3, and the scene now ends by pointing at the very next stop. The map gift is Rose's first real kindness; keep her reaction to +2 understated. Cheaper fallback for 3.6: skip `sit` and stand everyone in a half circle.

## Scene 4: Round two at the souvenir shop

**Where:** `pastrana_outdoors`, the souvenir stall beside the cathedral (`S3` area) · **Trigger:** straight after scene 3 · **Cutscene:** `chapter2_cathedral_talk` (second half) · **Dialogue:** `scene_4_vocabulary_practice_round_numbers_colors_market_goods` · **Sets:** `seen_chapter2_scene4`, then `chapter2_tour_done` (`pastrana_outdoors.gd`) and the walk home

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 4.1 | Rose and the player at the stall: woven bags, keychains, fabric bolts in six colours. | *(narration)* Before leaving the cathedral grounds, they pass by a small souvenir shop full of colorful items. |
| 4.2 | Rose holds up her fingers, counting on from five. | **Rose:** Round two. *An-om, pito, waeo, siyam, napueo* — six through ten. Finish counting to ten this time. (Confirmed) |
| 4.3 | Player counts on their fingers, eyes closed. | **Player:** *Isaea, daywa, tatlo, ap-at, lima, an-om, pito, waeo, siyam, napueo.* Ten! I did it. (Confirmed) |
| 4.4 | Rose, unimpressed. | **Rose:** Not so fast. Let's see if you know what they mean. |
| 4.5 quiz | `quiz`, 3 questions on six–ten (w017, w196, w244, w215, w178), with one–five as distractors. | — |
| 4.6 (pass) |  | **Rose:** Not bad. You were listening. |
| 4.7 (fail) |  | **Rose:** Almost. Say them again on the way home. |
| 4.8 | Rose sweeps a hand over the fabric bolts. | **Rose:** Now, colors — look at the fabrics there. |
| 4.9 | Camera close on the bolts; she touches each as she names it. A swatch bubble over Rose changes colour with each word. | **Rose:** *Puti* — white. *Itom* — black. *Puea* — red. *Asul* — blue. *Dueaw* — yellow. *Berde* — green. (Corrected, confirmed: berdi → berde) |
| 4.10 | Choice. | *Which color do you like?* → "I like the *puea* one — the red one. It really stands out." (+2) · "Maybe the *puti*, the white one. Simple." (0) · "Honestly, I can't tell half these colors apart yet, sorry Rose." (−2) |
| 4.11 (+2) |  | **Rose:** Good eye. Bold color for a bold first attempt at counting. |
| 4.12 (0) |  | **Rose:** Safe choice. That works too. |
| 4.13 (−2) |  | **Rose:** They'll stick eventually. Nobody gets it all at once. |
| 4.14 |  | **Rose:** Now let's test your eyes. Look at each color and tell me its name. |
| 4.15 quiz | `quiz`, 4 questions, colour swatches (existing `word_colors`). | — |
| 4.16 (pass) |  | **Rose:** Good. You know your colors now. |
| 4.17 (fail) |  | **Rose:** Not bad for a first try. Look at the fabrics again later. |
| 4.18 **CHANGED** (stones → baskets, so the props fit a souvenir stall) | Rose holds up a small woven basket, then a big one. | *(narration)* Rose holds up a small basket, then a big one. |
| 4.19 | Same props; she lifts each as she says it, then a new keychain and a faded old one. Bubbles: small basket, big basket, thumbs up, shiny keychain, faded keychain. | **Rose:** *Maisot* — small. *Mabahoe* — big. *Mayad* — good. *Bag-o* — new. *Daan* — old. (Confirmed) |
| 4.20 **CHANGED** (haron → duyon) | Rose points: at a keychain in her own hand, at one on the counter between them, at the cathedral bell tower far off. | **Rose:** *Daya* — "this." *Duyon* — "that," near us both. *Dato* — "that," farther away. Point when you say it, it's easier. (Corrected, confirmed: the plain set) |
| 4.21 **MOVED** | The food block (old 4.13–4.16) now plays in scene 1b. | — |
| 4.22 **NEW** | Rose pockets the keychain, nods toward the street. | **Rose:** That's enough for one day. Let's go home, balikbayan. |

**Notes.** The round is long, so it's broken up by two quizzes and a choice; keep that rhythm. Pass and fail both continue. Grammar check for 4.20: de la Cruz & Zorc (Vol. 1, "Deictics", p. 161–162) give **four** distances, not three: *daya* (near the speaker), *duyon* (near both speaker and listener), *danhi* (near the listener), *dato* (far). The emphatic, pointing forms are *hara*, *haron*, *hana*, *hato*. So *haron* is "that, near both of us" and belongs to the pointing set, while *daya* and *dato* belong to the plain set. *Decided in the review: Rose teaches the plain set, daya / duyon / dato*.

## Scene 5 (NEW): Dinner after the tour

**Where:** `aklan_living`, the dining table; new markers `S5/Susan`, `S5/Jonabel`, `S5/Jobert`, `S5/Rose`, `S5/Player` (seats if the table has them) · **Trigger:** `aklan_living.gd._check_beats()`: `chapter2_tour_done` and not `chapter2_evening_seen`, from 6 PM, once Susan and Jonabel are home and settled (same pattern as `chapter3_scene5`) · **Cutscene:** `chapter2_scene5` (**NEW**) · **Dialogue:** `scene_5_evening_home` (**NEW**) · **Sets:** `chapter2_evening_seen`; q005 step "Go home"

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| 5.1 | `fade` in on the table, evening light. Everyone seated (`sit`), plates out. Camera wide. | — |
| 5.2 | Susan sets down the last dish. | **Lola Susan:** *Kaon kita!* *(Let's eat!)* (Confirmed) |
| 5.3 | Jonabel turns to the player. Camera eases in on the two of them. | **Lola Jonabel:** So, *apo*. What did you like best today? |
| 5.4 | Choice. | *What do you tell Lola Jonabel?* → "The market. So much food." (0) · "Honestly? It was hot. I mostly wanted to sit down." (−2). The cathedral answer was cut in v1.1.4: Jonabel was there with you, so only places she missed are offered. |
| 5.6 (0) | Susan, pleased. | **Lola Susan:** Wait until Sunday. After mass, the market is even busier. |
| 5.7 (−2) | Rose, not looking up from her plate. | **Rose:** You sat on every bench in Kalibo, balikbayan. Every one. |
| 5.9 | Jonabel, softer, to the player. | **Lola Jonabel:** There's one more place I'd like you to see. Another day. |
| 5.10 | Rose, a half smile, then back to dry. | **Rose:** Another trip, another day. Don't get comfortable, balikbayan. |
| 5.11 | Susan, to the table. | **Lola Susan:** *Sa Domingo, magsimba kita.* All of us. *(On Sunday, we go to mass.)* (Confirmed) |
| 5.12 | Jobert, half asleep, nods; bubble: zzz. Laughter. | **Papa Jobert:** Mm. Mass. Good. |
| 5.12a **NEW** | Rose, smirking across the table. | **Rose:** You don't even know what day it is, do you, balikbayan? |
| 5.12b **NEW** | Rose counts the days on her fingers. Bubble over Rose: calendar (the day names have no picture, so they stay as text). | **Rose:** *Lunes, Martes, Miyerkoles, Hwebes, Biyernes, Sabado, Domingo.* *(Monday to Sunday.)* (Confirmed: Hwebes, as in the dictionary) |
| 5.12c **NEW** | Player, relieved. | **Player:** Wait, those sound Spanish. |
| 5.12d **NEW** | Rose shrugs, pushes her plate aside. | **Rose:** They are. Free points for you. Now prove it. |
| 5.12e **NEW** quiz | `quiz`, 3 questions, pool: the seven days (new bank entries); templates "What does \\"\[word\]\\" mean?" / "What Akeanon word means \\"\[gloss\]\\"?"; pass\_ratio 0.5. | — |
| 5.12f **NEW** (pass) | Rose, grudging nod. | **Rose:** Fine. *Sa Domingo*, then. Don't oversleep. |
| 5.12g **NEW** (fail) | Rose, back to her plate. | **Rose:** You have until *Domingo* to learn them. |
| 5.13 | `fade` out. `set_flag` `chapter2_evening_seen`. Player wakes up free in the living room (no forced sleep). | — |

**Notes.** This scene closes the tour and pays off the family thread planted at the cathedral: Jonabel's line about the steps is the only time she talks about her own past here, so keep it short and leave the silence around it. Line 5.9 points at Chapter 3 (the weavers) without naming it; Chapter 3's morning brief says where. 5.11 sets up the Sunday mass, which is the last thing Chapter 2 needs. Every choice is safe; the −2 one just earns a Rose jab. Cheaper fallback: no `sit`, everyone stands around the table.

## Sunday mass and the market after

**Where:** `aklan_living` → `pastrana_outdoors` → `cathedral_indoors` (`Pews/Row5LeftAisle`) → `market_indoors` → home · **Trigger:** every Sunday morning (`NpcSchedule.is_mass_pending()`) · **Cutscenes:** `chapter2_sunday_mass`, `chapter2_mass_to_cathedral`, `chapter2_mass_service`, `chapter2_mass_to_market`, `chapter2_mass_market`, `chapter2_mass_walk_living` · **Dialogue:** `scene_sunday_mass_invite`, `scene_house_farewell`, `scene_mass_market` · **Sets:** `chapter2_mass_went`, `chapter2_mass_attended`; the next sleep sets `chapter2_complete` (with `chapter2_tour_done`); q005 step "Sunday mass" (**NEW**)

| # | Picture (staging, camera) | Dialogue |
| --- | --- | --- |
| M.1 | Sunday morning, living room. Susan in her church clothes, Rose by the door. | **Lola Susan:** It's Sunday! Rose and I are going to the cathedral for mass, then to the market after. |
| M.2 **CHANGED** (comma, translation) | Rose, hand on the door. | **Rose:** Come with us, *kampod*. *(cousin)* (Confirmed) → "Sure, I'll go with you." (+2) · "Maybe another time." (−2) |
| M.3 **CUT** | Old idx 3 "So, are you coming?" can't be reached (no line points to it). | — |
| M.4 (+2) | Susan claps once. `set_flag` `chapter2_mass_went`. | **Lola Susan:** Good! Let's go before all the seats are taken. |
| M.5 (−2) | Rose shrugs, opens the door. | **Rose:** Suit yourself. We'll be back by noon. |
| M.6 | Leaving: whoever stays home calls after them (`said_by_npc_here`). | *Magdahan kamo ha.* *(You all be careful.)* Solo: *Magdahan ka ha.* **CHANGED** (Corrected, confirmed: *magdahan* joined) |
| M.7 | Cathedral: conga in, Rose, Susan and the player sit in row 5. Hold one second. `fade` out, clock +1 h, `fade` in. They stand and file out. | — |
| M.8 **NEW** (optional) | Market: Pedring at his stall waves them over as they pass. | **Nong Pedring:** *Hay, apo! Kamusta ro star fruit?* *(Hey, apo! How was the star fruit?)* (only with `bought_star_fruit`; otherwise *Hay, apo! Kamusta?*) (Corrected, confirmed: *uy* → *hay*) |
| M.9 | Susan, basket full. | **Lola Susan:** That's everything. Let's go home before the food gets cold. |
| M.10 | Walk home. That night, sleeping sets `chapter2_complete`; the next morning plays Chapter 3's brief. | — |

**Notes.** The mass stays wordless on purpose: sitting, a fade, standing up. It's the quietest beat in the chapter and gives the town a rhythm beyond the tour. M.8 is the one addition: Pedring remembering the player is the proof that the town now knows them. *Decided in the review: magdahan, joined (Chapter 3's Mag-dahan should match)*.

## Nong Pedring's idle lines and q005 (NEW)

**Pedring's remarks** go in `chapter2.json` under `remarks` (same format as Chapter 3's), speaker `Nong Pedring`, all requiring `seen_chapter2_scene2`. They play when the player talks to him at his stall on later visits.

| Key | Requires | Line |
| --- | --- | --- |
| `pedring_hello` | `seen_chapter2_scene2` | **Nong Pedring:** *Hay, apo! Kamusta ka?* *(Hey, apo! How are you?)* (Corrected, confirmed: hay) |
| `pedring_fish` | `seen_chapter2_scene2` | **Nong Pedring:** *Bakae kat isda, apo, eab-as pa.* *(Buy some fish, apo, it's still fresh.)* (Corrected, confirmed: *eab-as* for fresh produce, not *presko*) |
| `pedring_suki` | `seen_chapter2_scene2` | **Nong Pedring:** Your Lola Susan has been my *suki* for thirty years. Don't tell her I said thirty. |
| `pedring_star_fruit` | `bought_star_fruit` | **Nong Pedring:** Another *star fruit*, *apo*? I kept the sweetest one for you. |

**Quest q005 "Explore Kalibo with Rose"** (`data/quest_data.json`, between q004 and q006):

| Step | Objective | Done on |
| --- | --- | --- |
| 1 | Ask Rose to show you around | `chapter2_with_rose` (first time) |
| 2 | Visit Pastrana Park | `seen_chapter2_scene1` |
| 3 | Visit the market | `seen_chapter2_scene2` |
| 4 | Visit the cathedral | `seen_chapter2_scene4` |
| 5 | Have dinner at home | `chapter2_evening_seen` |
| 6 | Go to Sunday mass | `chapter2_mass_attended` |

Starts with `seen_chapter2_scene0b`; completes with `chapter2_complete` (sets `quest_005_done`).

**Notes.** The remarks reuse words the player met that day (*kamusta, isda, suki, balimbing*), so talking to Pedring is free review. Two of the four are English with one Akeanon word, which matches his voice in the story scenes.

## Picture bubbles (NEW)

When an object is shown or named, a small speech bubble with a drawing of it appears above the character, in place of item pop-ups and emotes. The game has neither yet; this one feature covers both. It also teaches: the player links *isda* to a picture of a fish, not to the English word.

**How it works**

- A `bubble` field on a dialogue line: `"bubble": "star_fruit"` shows that icon above the speaker while the line is on screen, and closes with it. `"bubble_on": "player"` puts it over someone else.
- A list, `"bubble": ["fish", "chicken", …]`, changes the picture each time the typewriter reaches the next `\` word, for lines that name several things (1b.3, 4.9, 4.19).
- A `bubble` cutscene action for silent beats: `{"type": "bubble", "actor": "Lola Jonabel", "icon": "bell", "seconds": 2}`.
- The look reuses the dialogue-box texture and tail from `word_popup.gd`, so it matches the rest of the UI.
- Icons live on one sheet, `assets/ui/bubble_icons.png`, with a map from icon id to cell. A word-bank entry can name its icon (`"icon": "fish"`), so the same art can later show in the dictionary, the Journal and picture quizzes.

**Icons Chapter 2 needs** (23 drawings; the swatch is one drawing tinted with the quiz's existing `word_colors`)

| Group | Icons | Used in |
| --- | --- | --- |
| Objects | star, moon, sun, map, bell, calendar, star fruit | 0.5–0.6, 2.13, 2.15, 3.5, 3.7, 5.12b |
| Food | fish, chicken, egg, rice sack, bread, meat, pig | 1b.3 |
| Souvenir stall | swatch (tinted ×6), small basket, big basket, thumbs up, shiny keychain, faded keychain | 4.9, 4.19 |
| Emotes | !, ?, zzz | 0.4, 2.10, 2.12, 5.12 |

**Before drawing the sheet:** build the bubble with one test icon and check that a 24 px drawing reads well on a phone over the 16 px sprites. If it doesn't, go to 32 px or show the bubble at 2×. Fallback: without the feature, the flags still set and the lines still play; only the pictures are missing.

## Lines to confirm

All 30 review items are decided (2026-11-16): 13 confirmed as written, 17 corrected, and one new teaching beat added (days of the week at dinner). Nothing is still open. Every line below is the final text for `chapter2.json`.

| Shot | Final line | Translation | Result |
| --- | --- | --- | --- |
| 0.5–0.6 | *bituon, buean, adlaw* | star, moon, sun | Confirmed |
| 0b.1, 1.7 | *Mayad nga agahon!* | Good morning! | Corrected (was *Mayad-ayad*) |
| 1.2 | *Raya do Pastrana Park. Ga tikang iya ro mga tawo kon agahon.* | This is Pastrana Park. People walk here in the mornings. | Corrected |
| 1.6 | *Ruyon, si Nong Pedring. Suki namon igto sa tindahan.* | That's Nong Pedring. He's our regular vendor at the market. | Confirmed (title *Nong*) |
| 1.8 | *Mayad man nga agahon, apo ka gali ni Jonabel. Siin ka halin?* | Good morning to you too! So you're Jonabel's grandchild. Where are you from? | Corrected |
| 1.8b | *Abaw, abroad gid gali!* | Wow, all the way from abroad! | Corrected |
| 1.9 | *Ayaw manirbyus.* Slow only. Learning takes time, *apo*. | Don't be nervous. … | Corrected (was *Indi baea*) |
| 1.11 | *Sunod kamo sa tindahan.* | Come by the market, you two. | Corrected |
| 1.12 | *Idto kita magtuon it mga pangaean.* | That's where we'll learn the names of things. | Confirmed |
| 1b.3 | *Isda, manok, itlog, bugas, tinapay, karne, baboy* | fish, chicken, egg, rice, bread, meat, pig | Corrected (*humay* → *bugas*) |
| 2.3 | *Ano ing gusto, apo? Abo iya nga bugas, tubi, uga.* | What would you like, apo? There's plenty here: rice, water, dried fish. | Corrected |
| 2.6 | *pangabay* = please | — | Confirmed |
| 2.7, 2.9, 2.11 | *Pangabay it daya, Nong, ho.* | May I have this one, Nong, please. | Corrected (was *gusto ko it daya*) |
| 2.10 | *Abaw! Batian mo to, apo?* | Wow! Did you hear that, apo? | Corrected |
| 2.13 | Star fruit, *apo*. *Matam-is imaw.* | Star fruit, apo. It's sweet. | Corrected (no *balimbing*; *gid* → *imaw*) |
| 2.15 | Enjoy! | — | Corrected (Akeanon dropped) |
| 2.18 | *Siin do masunod ninyo nga agtunan? Magsimba?* | Where are you off to next? To church? | Corrected (joined) |
| 3.3 | *Iya kami kato tanan pirme ga simba. Inyong Lola Jonabel gid ro pinaka masueundun.* | Back then, we all always went to church here. Your Lola Jonabel most of all, she was the most devout. | Corrected |
| 3.7 | *Hara, tan-awa. Mapa it Kalibo. Kon magtuon ka it mga lugar, mas madali ka makaagto bisan siin.* | Here, look. A map of Kalibo. … | Confirmed |
| 4.2–4.3 | *An-om … napueo*; *Isaea … napueo* | six to ten; one to ten | Confirmed |
| 4.9 | *Puti, itom, puea, asul, dueaw, berde* | colours | Corrected (*berdi* → *berde*) |
| 4.19 | *Maisot, mabahoe, mayad, bag-o, daan* | small, big, good, new, old | Confirmed |
| 4.20 | *Daya, duyon, dato* | this; that, near us both; that, far | Corrected (*haron* → *duyon*) |
| 5.2 | *Kaon kita!* | Let's eat! | Confirmed |
| 5.11 | *Sa Domingo, magsimba kita.* All of us. | On Sunday, we go to mass. | Confirmed |
| 5.12b | *Lunes, Martes, Miyerkoles, Hwebes, Biyernes, Sabado, Domingo* | Monday to Sunday | New beat, confirmed (*Hwebes*) |
| M.2 | Come with us, *kampod*. | cousin | Confirmed |
| M.6 | *Magdahan kamo ha.* / *Magdahan ka ha.* | You (all) be careful. | Corrected (joined) |
| M.8 | *Hay, apo! Kamusta ro star fruit?* | Hey, apo! How was the star fruit? | Corrected (*uy* → *hay*) |
| R1 | *Hay, apo! Kamusta ka?* | Hey, apo! How are you? | Corrected |
| R3 | *Bakae kat isda, apo, eab-as pa.* | Buy some fish, apo, it's still fresh. | Corrected |

**Lines in other chapters that change with these answers:** Chapter 3's speaker `Anong Pedring` → `Nong Pedring` (2 lines); Loleng's "Mag-dahan kamo sa biyahe" → "Magdahan…"; "Gusto mo samitan mag ubra?" → "mag-ubra".

**Story calls**

| Question | Answer |
| --- | --- |
| Pedring's title: *Anong Pedring* or *Manong Pedring*? | **Decided:** *Nong Pedring* (the short form), everywhere |
| Jonabel's past at the cathedral: just the bell-tower look and the steps line, or more (married there, sang in the choir)? | **Decided:** keep those two beats |
| Rose calls the player *kampod* (cousin) once, on Sunday. Keep it as her one soft moment in Ch2? | **Decided:** keep |
| Should 5.9 ("one more place I'd like you to see") point at the weavers in Ch3? | **Decided:** yes, without naming it |
