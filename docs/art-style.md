# Art style: "Bonfire Night" pixel art

Daniele's references (2026-09-28): a gameplay screen, a logo and a title menu, all in detailed pixel
art. Every screen of the game must look like it comes from the same game as those three pictures.

## The look in one paragraph
A winter night in Mamoiada, drawn in chunky pixel art. A deep blue starry sky over dark mountains and
the stone houses of the village, windows lit warm. A great bonfire burns at the heart of the square
and lights everything near it orange; everything far from it falls into cool navy shadow. The
Mamuthones are heavy black shaggy figures with dark carved masks and bronze bells; the Issohadores
wear red jackets, white masks and trousers, a black berritta, and throw a hemp rope. The interface is
made of dark navy panels framed in old gold, with small red diamond marks, and one red kilim-woven
banner for the main action. Text is cream on navy, in a serif face.

## Grid and scale
* Art is authored at **240 x 480** for the 720 x 1440 base screen: **1 art pixel = 3 screen pixels**.
  Sprites are baked at 1x and drawn with **nearest** filtering (no mipmaps, no linear blur).
* Only integer multiples where the layout allows (x3 on the base screen; x2 for small far figures).
  Moving sprites may land between pixels; still scenery sits on the 3 px grid.
* No anti-aliasing, no soft gradients inside sprites. Glows (fire light, beat flashes) are the one
  exception: they are additive light layered over the art, and they are stepped (banded) where they
  are large.

## Palette
`tools/art/pixel/palette.py` is the only source of colours (ramps NIGHT, HILL, STAR, FIRE, STONE,
SETT, GOLD, RED, BONE, FLEECE, WOOD, LEATHER, ROPE, NAVY, MOSS, SKIN, and K for outlines).
`px.Canvas.save` refuses a PNG with an off-palette colour. Godot code that draws pixel pieces uses
`PixelPalette` (game/scripts/art/pixel_palette.gd), generated from the same file.

## Light and outline rules
* One light: the bonfire. Figures are lit on the side facing the fire (a warm rim of FIRE4-6 or
  GOLD4) and fall to NIGHT/FLEECE on the far side. The sky side is cool.
* Characters, notes and UI frames get a **K0 outline**. Scenery (houses, hills, cobbles) does not;
  it separates by value.
* Dither only to describe something (sky gradient, glow falloff, fleece), at most 2-3 steps per band.
  No random noise fields, no orphan pixels.

## Type
* Titles and button labels: **IM Fell English SC** (serif small caps) in BONE3/BONE4 with a K0 shadow.
  Body text: Alegreya Sans in BONE3. Scores and HUD numbers: the pixel-style heavy weight with a K0
  outline, gold for the score.
* The logo's word mark is hand-drawn pixel lettering (cream with red shadow and K0 outline), not a font.

## UI kit (menus, results, workshop, map)
* Default button: NAVY1 fill with a faint woven pattern, 1 art-px K0 outline, a GOLD3 inner frame
  with GOLD4 corner studs, small RED3 diamonds either end. Pressed: fill darkens, frame goes GOLD4.
* Main action ("AccentButton"): a red kilim banner (RED2/RED3 with a woven diamond pattern in RED1
  and GOLD2), gold frame, gold diamond medallions at both ends.
* Panels: NAVY0 board with a gold rule frame; paper cards become BONE3 parchment with a WOOD frame.
* Screens stand on a dark stone backdrop (worn cobbles, a warm glow from below) so no screen is a
  flat colour.

## The street (notes, bells, road), redrawn 2026-09-29 for readability
Daniele asked for the notes, the bells and everything on the road to be redone from scratch, readable
first. Drawn in tools/art/pixel/road.py; the road itself is the shader in LaneView with its light
table in field.py.
* **Notes are plates**: a rounded-rectangle face seen from low in front, its thickness below, a K0
  outline, about three quarters of the lane wide. Kind is told by colour *and* shape:
  step = gold plate with a red diamond; off-beat / call = a narrower red plate with a gold diamond
  (the Issohadore's red); heal = a bone plate with a flame; stomp = a wider, twice-as-thick fire plate
  with two bone thumb prints; hold = a gold plate trailing a hemp rope that ends in a small gold
  knot plate, and the rope catches fire while held.
* **Bell bars** span the road: a warm gold beam of dark chevrons pointing up (raise the bells) or a
  cool steel beam of pale chevrons pointing down (lower them), a matching medallion in the middle.
* **Hit line**: a thin gold rule; on each lane a slot that is the step plate's own outline, so a note
  on time drops exactly into it. Hit effects are plate-shaped rings thrown out of the slot.
* **Road**: dark, quiet setts. Only warm, bright things on the road are notes; the lane dividers are
  pale cool stone lines, the edges a thin gold kerb inlay, and a faint line crosses the road on every
  beat (brighter on the first beat of a bar) so off-beat notes read as between the lines.

## Motion ("juice") rules
* Everything that moves on the beat lands **on** the beat: Mamuthones touch down on it, the fire
  flares on it, braziers and the hit line pulse on it. Anticipation happens before the beat.
* Mamuthones jump heavily: a crouch (anticipation) before the jump, a slow rise, a fast fall, a hard
  landing with squash, bells swinging and a puff of dust. Weight over bounce.
* The bonfire flares on every beat (taller, brighter core, a burst of sparks), bigger on the downbeat
  of a bar, and burns lower when health is low.
* Juice never moves or hides a note, the lanes, the hit line or the buttons. Screen shake, if any,
  touches the scenery only, never the lanes. Reduced motion cuts every amplitude to about a third.

## Solemnity
Night, fire, weight, ritual. No cartoon faces, no candy colours, no shouty effects. The costumes
are the real ones (see docs/community-check.md): Issohadore with a white mask, red jacket, white
shirt and trousers, a black berritta tied with a kerchief, bronze bell bandolier, rope of natural
hemp; Mamuthone with black sheepskin, a dark carved mask, a black kerchief over the head, bronze
bells on the back (the carriga) and small bells on the chest straps.

## Rubric (each 0-10; ship only when every line is 8+, then push toward 10)
1. **Reference match** - side by side with the three references, a stranger would say "same game".
2. **Coherence** - every screen uses the palette, the grid, the outline rule and the UI kit; no
   leftover woodcut or painterly pieces.
3. **Gameplay readability** - notes, lanes, hit line and buttons are the crispest, highest-contrast
   things on the play screen; nothing decorative on the road can be mistaken for a note.
4. **Juice** - the beat is visible everywhere (jumps, fire, braziers, hit line) and lands exactly on
   it; hits feel punchy; misses read instantly.
5. **Pixel craft** - strict grid, nearest filtering, palette only, clean clusters, no orphans.
6. **Appeal** - a screenshot you'd put on the store page.
7. **Solemnity and authenticity** - correct costumes, calm composition, night and fire.
