# Art request: "Hang the weaves" (Chapter 3, Haboean gallery)

**For:** v1.1.9 minigame `weave_sort` (`scripts/ui/weave_sort_panel.gd`)
**Template:** `art_requests/weave_sort_template.png` (1x) and `weave_sort_template_x4.png` (zoomed)
**Deliver to:** `assets/ui/weaves/` (the game picks the files up by name; until then it draws the placeholders shown in the template)

## What the minigame is

The Haboean gallery curator has new piña weaves. The player takes each weave from a
basket and hangs it on the display rack labelled with its colour in Akeanon
(puea, asul, berde, dueaw, puti, itom). At higher difficulty there are two rows of
racks, one for big weaves (mabahoe) and one for small ones (maisot): the same
weave art is drawn at 60% for the small ones.

## Files needed

| File | Size (px) | What |
|---|---|---|
| `weave_puea.png` | 34 × 42 | Red piña cloth panel |
| `weave_asul.png` | 34 × 42 | Blue piña cloth panel |
| `weave_berde.png` | 34 × 42 | Green piña cloth panel |
| `weave_dueaw.png` | 34 × 42 | Yellow piña cloth panel |
| `weave_puti.png` | 34 × 42 | Natural white/cream piña cloth (the classic undyed piña) |
| `weave_itom.png` | 34 × 42 | Black piña cloth panel |
| `rack.png` | 50 × 60 | Wooden display rack / hanger the weave hangs on, empty |

## Style notes

- Pixel art, same palette feel as the Haboean tileset and the loom (`haboean_sprites_template.png`).
- Piña is sheer and fine: a light open lattice or small embroidered motif (*calado*
  style) reads better than a solid fill. Keep each colour clearly readable at 60% size.
- A short fringe or hemmed edge at the bottom helps it read as cloth.
- Transparent background around the cloth. The cloth should fill most of its box,
  centred, with the top edge flat (it hangs from the rack's bar).
- The rack is seen from the front: a top bar with two hooks and side posts, with the
  middle left empty so the hung weave shows through.

## How it looks in game

Racks sit in a grid (colour words across the top, size words down the side when
there are two rows); the basket of weaves sits below them. Tapping a weave
outlines it; tapping the right rack hangs it there.
