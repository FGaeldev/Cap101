# Plaza and market minigames (v1.1.5)

From the v1.1.3 playtest (Loys): nothing to do at the plaza, nothing to do at
the market after mass, nothing to do after Chapter 4. Decision 2026-11-22: two
activities, one per place, both repeatable, both paying a little.

## 1. Stall helper (market)

**Where / when:** Nong Pedring's stall in `market_indoors`, from the Sunday
after-mass market on (`chapter2_mass_market` seen), and any day after
Chapter 2. Pedring's NPC menu gets **Help at the stall**. Once per day.

**Play:** a short shift of 5 customers. Each walks up and asks for one thing in
Akeanon; the player taps the right goods from the stall row (4 choices, the
item's picture and its Akeanon word, no English). A wrong tap sends the customer
away unpaid, and 3 misses end the shift early. Misses cost, but money the player
already has is never taken (rule change 2026-11-22).

**Pay:** ₱2 per customer served, so ₱0–10 a shift. Hidden mastery +1 for each
item word served right (same rule as the crossword). Counts as a Review try?
No: it's its own activity.

**Build:** `scripts/ui/stall_panel.gd` (new minigame_type `stall`), shown with
`DialogueUI.show_standalone_minigame` like fishing. Customers are portraits
only (no walking NPCs), so no new map work. Stock = Pedring's shop stock
(`data/items.json`), which already has Akeanon words.

**Akeanon (reviewed live 2026-11-22, all confirmed):**
- Customer: `Pangabay it {item}, gha.` / price customer: `Tig pila ro {item}, gha?`
- Player button: `Pilang bato?`; customer answers `{number}ng bato.` (Tatlong bato, Siyam nga bato: joins like piso)
- Price customer flow: player taps the price on Pedring's board, asks Pilang bato?, then enters the COUNT
- Thanks: `Saeamat.`
- Pedring (English + phrases): lesson before the first shift on Tig pila / Pilang bato; invite "Busy day, gha. Can you help me at the stall?"; pay "Saeamat, gha. Here's your pay."
- isda, tubi: verified

## 2. Plaza directions (Pastrana)

**Where / when:** Pastrana Park, after the Chapter 2 tour. A visitor NPC
(tourist) stands by the fountain with a "?" marker. Talk → **Help with
directions**. Once per day.

**Play:** a miniature Pastrana map fills the panel (the plaza's floor and walls
layers drawn small), with the goal place marked. Each of 3 visitors asks
`\Siin \ro {place}?` and their tiny figure starts walking from the fountain. It walks
non-stop, tile by tile, in its current heading until it reaches the goal or the
player gives a new direction: `Diretso` (keep going), `Atras` (turn back),
`liko pa waea` (turn left), `liko pa tuo` (turn right), left/right from the
walker's own heading. Walking into a wall or out a wrong exit = lost.

**Pay:** ₱3 per visitor who arrives, +₱3 if all three arrive (₱0–12 a round).
A lost visitor is unpaid and loses the bonus. Mastery +1 on each direction word
used on a successful walk.

**Build:** `scripts/ui/directions_panel.gd` (minigame_type `directions`): draws
the plaza tile layers into a small viewport, moves the figure on the grid at a
steady pace, reads places and direction words from `data/map_data/places.json`
(already reviewed). The visitor is a culture-spot style NPC placed from
`data/culture_spots.json`.

**Steering (decided 2026-11-22):** Akeanon word buttons, turning from the
walker's own heading, not the D-pad.

**Akeanon (reviewed live 2026-11-22, all confirmed):**
- Visitor: `Gha, siin ro {place}?` (greeting and question in one); places: simbahan, tindahan, souvenir shop, baeay ni Lola Jonabel, airport
- Buttons: `Abante` · `Atras` · `liko pa waea` · `liko pa tuo` (Abante replaces Diretso on the buttons only)
- Thanks: `Saeamat!`

## Order of work

1. ~~Review the new Akeanon lines~~ done 2026-11-22 (Grammar Notes: "Stall and plaza minigames").
2. Stall helper (smaller, reuses the shop data).
3. Plaza directions.
4. Help topics, a tutorial step for each, playtest driver support, then a
   parallel playtest.
