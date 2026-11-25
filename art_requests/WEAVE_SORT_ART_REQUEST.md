# Art request: "Help hang the weaves" (Chapter 3, Haboean loom house)

**For:** v1.1.9 world activity `weave_hang` (`scripts/entities/weave_hang.gd`)
**Template:** `art_requests/weave_sort_template.png` (1x) and `weave_sort_template_x4.png` (zoomed)
**Deliver to:** `assets/ui/weaves/` (the game picks the files up by name; until then it draws the placeholders shown in the template)

## What the activity is

The loom house curator has new piña weaves. They lie folded on the floor by the
door. The player walks over, picks one up (it shows above their head), carries it
to one of the room's wide display cases (the two-tile cases with cream glass, see
`haboean_gallery.tscn`) and hangs it there. Each case in the round has a sign with
a colour in Akeanon (puea, asul, berde, dueaw, puti, itom), so the player has to
read the word to find the right case.

## Files needed

| File | Size (px) | What |
|---|---|---|
| `weave_<color>.png` × 6 | 28 × 13 | The weave hanging inside a display case, covering the cream glass (drawn at 2,8 from the case's top-left tile) |
| `weave_<color>_folded.png` × 6 | 12 × 8 | The same weave folded on the floor, waiting to be picked up |

`<color>` is one of `puea` (red), `asul` (blue), `berde` (green), `dueaw` (yellow),
`puti` (natural white/cream, the classic undyed piña), `itom` (black). 12 files in all.

## Style notes

- Pixel art in the indoors tileset's palette; it sits inside the existing case
  frame, so no frame or shadow of its own.
- Piña is sheer and fine: a light open lattice or small *calado* motif reads better
  than a flat fill. Each colour must stay obvious at this size, since matching the
  colour to the word is the whole game.
- The folded version is a small neat stack with a visible fold line; transparent
  background around it.
