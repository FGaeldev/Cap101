# Pesos, fares and the market: economy plan

Drafted 2026-11-16. Phases 1–3 and the first fetch quest built 2026-11-18 (see "Build status" at the end). Cross-chapter design, so it lives here rather than in a chapter plan.

## Why

Today the story is the only strong pull. Learning is visible only in quizzes, which never change anything (no-punishment rule, GDD §7), so doing well is its own reward. Hearts, mastery and `RewardManager` rewards exist but the player never feels them.

A small peso economy makes Akeanon **useful**: right answers earn the fare, the fare gets you places, and the market asks you to buy, sell and count in Akeanon. It fits Aklan (tricycles, jeepneys, Pedring's stall, Haboean's cloth) and reuses vocabulary the chapters already teach: numbers 1–10 (Ch2), *bakae* w031 / *baligya* w032 (Ch3), *pangabay* w189 (Ch2), *humay* w080, *uga* w249.

## Rules that keep it fair

The no-punishment rule stays. Money is a **gate on optional things**, never on the story.

1. **Story trips are free.** When Rose (or the family) takes the player somewhere as part of a chapter, she pays. Only map fast travel and optional trips cost a fare.
2. **Money is never taken away.** A wrong answer earns less, not nothing. Nothing is lost on failing or quitting.
3. **There is always a floor.** Lola gives a small daily allowance (line to write, Akeanon to confirm ⚑), so even a struggling learner can afford a cheap fare every day.
4. **Walking is always free.** Every fare has a walk option that costs in-game hours instead (the day/night clock is the price). The fare buys time; answers earn the fare.
5. **The gate is "can you afford it", not "did you pass".** Farther, optional places cost more, so they open naturally as the player plays and learns.

## The currency

- **Pesos**, shown as ₱ with an Akeanon label (word to confirm ⚑: *piso* / *kwarta* / other).
- One saved integer, `GameState.pesos`. Added to save and load together, default 0, so old saves load unchanged (TDD §7 rule).
- `RewardManager` becomes the only writer (`award_pesos(amount)`, `spend_pesos(amount) -> bool`), like the other reward fields. Its unused "stars" field is retired or renamed rather than kept alongside.
- HUD counter beside the clock; a small "+₱5" toast when earned (reuse the `popup_queued` pipeline, which has no listener yet).

## Earning

| Source | Amount (starting values, tune later) | Notes |
|---|---|---|
| Story quiz or minigame passed | ₱5 | Failed: ₱2. Same for every chapter's story activities. |
| Habi-Habi | ₱1 per clean row, +₱3 for a clean cloth | Its score already exists to scale this. |
| NPC "Review" (quiz, hangman, memory match) | ₱3 pass / ₱1 fail | **Daily cap** (e.g. ₱15/day) so review can't be farmed. |
| First time a word reaches "mastered" | ₱2 | Ties earning to real learning. |
| Lola's allowance | ₱10 each morning | The floor. Only while the player has under ₱20. |
| Fetch quests | ₱10–20 | See below. Bigger than quizzes on purpose. |
| Selling goods | varies | See below. |

Quizzes should feel like pocket money; quests and selling are the real income. That keeps the "grind review" loop unattractive.

## Spending

| On | Price | Notes |
|---|---|---|
| Tricycle within Kalibo (home ↔ park, market, cathedral) | ₱5 | Walk = +30 min. |
| Jeepney/van to Haboean | ₱15 | Walk = +2 h (and arrives later in the day). |
| Van to Bakhawan | ₱15 | Ch4. |
| Caticlan / Boracay | ₱50+ | Ch6; story trip itself stays free. |
| Market goods for fetch quests | ₱2–10 | Bought with an Akeanon exchange. |
| Café snack (Haboean) | ₱5 | Small comfort spend, maybe a tiny bonus (e.g. +1 hint in the next minigame). |
| Cosmetics (outfits, room decor) | ₱30–100 | Long-term goal, later phase. |

### Paying a fare (the language moment)

Paying is a short exchange, not a button:

1. Driver names the fare in Akeanon (a number from Ch2).
2. Player picks the right coins/amount (tap ₱1/₱5/₱10 coins) or the right phrase from 2–3 choices.
3. Wrong amount: the driver repeats it with the English, the player tries again. Never blocks, never charges extra.

This lives in `MapManager.travel_to_region()` before the fade: the region gets a `"fare": int` in `regions.json`, the pay step runs, then the existing travel code. The region's existing `gate_challenge_id` stays available for story gates.

## Inventory, keepsakes vs goods

New saved field `GameState.inventory: Dictionary` (item id → count), with item data in `data/items.json` (`id, name, akeanon_word_id, kind, base_price, sellable`).

- **Keepsakes** (`kind: keepsake`): the piña bookmark, Grandma's memory pages, future chapter gifts. Shown in **Achievements → Collections** (built 2026-11-16, `data/collections.json`). **Never sellable**: selling Loleng's gift would undercut the chapter.
- **Goods** (`kind: good`): woven cloth, market produce, fish (Ch4). Live in the inventory, can be bought, used in quests, or sold.

## Fetch quests (side quests)

Optional, offered by family and townsfolk once Ch2's tour is done. Each one asks the player to *use* words, not just recognise them.

Example, **"Susan's list"**: Susan gives ₱20 and a list in Akeanon (*humay*, *uga*). At Pedring's stall the player names each item, pays, and checks the change (numbers). Bring them home: Susan keeps the change as the reward, +hearts.

Building blocks:
- Quest data gains `"category": "side"` and steps that check inventory (`has_item`), not just flags.
- A shop exchange in dialogue: a new line type (`"type": "shop"`) or a small panel that lists goods with Akeanon names and prices, tap to *bakae*.
- Hearts finally do something: higher hearts → better prices from that NPC, new requests, extra dialogue.

## Selling (weaves and goods)

- A Habi-Habi cloth becomes an inventory item when finished (clean cloth worth more: e.g. ₱8 vs ₱4).
- Sell at the Haboean gallery (Loleng / the curator) or the market (Pedring), through a short haggle: the buyer offers a number in Akeanon, the player accepts or counters from 2–3 choices. Uses *baligya*, numbers, *pangabay*.
- Ch4 fish follow the same path.
- Keepsakes never appear in the sell list.

## Guard rails

- **No grind:** daily cap on review earnings; quizzes are small money.
- **No wall:** allowance floor + free walking + free story trips. A player who never earns a peso can still finish every chapter.
- **No stress:** no fines, no theft, no prices that rise. Failing a fare exchange just repeats it.
- **No spoilers:** fares and prices shown up front; nothing hidden behind a random roll.

## Build order

Each phase ships on its own and leaves the game playable.

1. **Wallet and earning:** `GameState.pesos` (save/load), `RewardManager.award_pesos/spend_pesos`, HUD counter + toast, earn hooks in quiz/minigame resolution (`DialogueUI` resolve paths), Lola's allowance in the morning check, review daily cap. Dev menu: "+₱50" button.
2. **Fares on the map:** fill in real regions in `data/map_data/regions.json` (home, park, market, cathedral, Haboean, Bakhawan) with `fare`; the pay-the-fare exchange; walk option that advances the clock; story trips untouched.
3. **Inventory and buying:** `GameState.inventory`, `data/items.json`, shop exchange at Pedring's stall, first fetch quest ("Susan's list"), side-quest category in the Journal.
4. **Selling:** Habi-Habi cloth as an item, sell exchange at the gallery and market, prices by quality.
5. **Hearts and cosmetics:** heart-based prices and requests; outfits/decor shop as the long-term sink.

Tooling per phase: a playtest/autoplay hook so the auto-player can pay fares and finish a fetch quest, and static checks that every region with a `fare` has a scene and every item id used in a quest exists.

## Open questions

| # | Question | Default if not decided |
|---|---|---|
| 1 | Akeanon word for the money and for "fare" ⚑ | **Decided 2026-11-18: piso.** ₱1 = *Piso*; a number word ending in a vowel takes -ng (*Limang piso*), one ending in a consonant takes nga (*Siyam nga piso*); above 10, digits + *pisos*. |
| 2 | Coin-picking or phrase-choice for paying? | Coin-picking (practises numbers) |
| 3 | Does Bakhawan move out of Ch2 (CHAPTER3_PLAN decision 4)? | Fares make it a paid optional trip either way |
| 4 | Should the café snack give a gameplay bonus? | No, cosmetic comfort only |
| 5 | Cosmetics in scope for this game? | Later phase, after Ch4 |

## Build status (2026-11-18)

Phases 1–3 are in. Starting values as in the tables above unless noted.

- **Wallet:** `GameState.pesos`, `inventory`, `allowance_date`, `review_earn_date` / `review_earned_today`, `quest_offer_declined` (all saved, default empty, so old saves load). `RewardManager.award_pesos / spend_pesos / award_story_activity / award_review / check_allowance`. HUD "₱N" panel left of the clock (shown from Ch2, or once the player has money) and a "+₱N" toast through `popup_queued`. Dev menu: Money → +₱50.
- **Earning hooks:** story quiz and minigame lines (DialogueUI) ₱5 / ₱2; NPC Review ₱3 / ₱1, capped at ₱15 per day; Lola's allowance ₱10 from 6 AM while under ₱20 (from Ch2).
- **Fares:** `regions.json` has Home, Pastrana Park, Kalibo Cathedral, Market (tricycle ₱5, walk 30 min), Haboean (jeepney ₱15, walk 2 h, after `quest_007_done`) and Bakhawan (van ₱15, walk 2 h, after `map_open_bakhawan`; its old archived gate challenge is gone). Map markers are placeholders around the airport marker. `MapManager.travel_to_region(id, "ride" | "walk")`; the coin exchange is `Economy.pay()` (scripts/ui/market_panel.gd). Map trips are refused while out with Rose or the family (the trip flags), so story trips stay free and untouched.
- **Inventory and buying:** `data/items.json` (goods; the piña bookmark as a never-sellable keepsake), `Economy` autoload, "Buy" in Nong Pedring's NPC menu at the market.
- **Side quests:** `"category": "side"` quests with `giver`, `offer_flag`, `start_pesos`, `needs_items`, `reward_rapport`, `lines` (scripts/util/side_quests.gd). Journal: "Side quests" section and a "Bring:" item checklist. First one: qs001 "Susan's list".
- **Lines:** `data/economy_lines.json`; draft Akeanon waits for review. Money/fare word still open (question 1).

**Balance pass (2026-11-20, v1.1.2):** errands already hand over enough money for what they ask, so required purchases are always affordable; the reward was only the change (₱0–24) and pick-up errands paid nothing. Side quests gained `reward_pesos`, a thank-you paid on hand-in on top of the change: ₱10 for Susan's list, merienda, pasalubong, Rose's notebook, taho and the twelve fruits, ₱20 for cleaning the Bakhawan trail; packing (Ch1, no wallet yet), Bea's lola (no giver) and Noche Buena (₱24 change) stay at ₱0. One or two errands now pay for a ₱30 Haboean or Bakhawan round trip. Prices, fares, start money, quiz and Review pay, and the allowance are unchanged. The HUD lists what an errand still needs (item, held/needed, price, "Need ₱N more").

Not built yet from phases 1–3: ₱2 for a word's first "mastered", Habi-Habi per-row pay, retiring `akeanon_stars`, and an autoplay hook that pays fares / finishes a fetch quest. The static check (`validate.gd` `_check_economy`) is in.
