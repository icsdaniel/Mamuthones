# Sonazzos - Menu Art Direction: "Su Manifestu" (The Festival Poster)

## 1. Concept

**Su Manifestu** treats every menu as a freshly pulled lino print: a frontal festival poster pinned flat to the picture plane, cut from two blocks (black key + red) on cream-and-black paper. The main screen is the poster for this year's festa: one big carved **visera** (mask) wrapped in sheepskin, a cluster of **sonazzos** hanging from a crossed leather **carriga** below it, the carved title, and the "programme" (the buttons) printed underneath like the dates on a real Mamoiada poster. Dividers are the Issohadore's **soha** rope; the frame is a Sardinian carved border. The play screen shows the *scene*; the menus show the *print itself* (blocks, gouge marks, registration, stamps): flat and frontal instead of deep perspective, one large object instead of many small figures, rectangular blocks instead of round notes, rope and carved borders instead of lanes and dots.

## 2. Visual language

**Grid (art pixels, 135x300).** Outer frame 4 px. Content margin x=8..126 (119 px wide). Vertical zones: top bar 0-15, logo 16-41, hero 42-147, programme 148-283, colophon 284-299. Everything snaps to whole pixels; centre axis x=67.

**Inks and proportions** (approx. screen area): black #141014 55%, brown #4a3c38 18%, warm grey #c9bba0 10%, cream #efe6d2 12%, vermilion #c8352a 5%.
- Black = paper. Brown = carving texture, shadows, locked. Warm grey = sheepskin, rope, captions. Cream = text, mask face, interactive outlines.
- **Red means "press here / now"**: only the Continue block, the currently selected item's marker, and the misregistration flash on the logo. Never decorative red elsewhere (one exception: the 2 px red tassel knots on the rope, max 4 pixels each).

**Textures (dithering only, no gradients).**
- *Gouge chatter*: on black areas, scattered 1x2 or 2x1 brown flecks at ~4% density, oriented in short parallel runs of 3-5 (V-gouge clearing marks); ~10% near carved objects.
- *Sheepskin*: brown and warm grey "c"/"s" curls, 3x3 px each, packed in offset rows, black between. Used only around the mask and in the hero.
- *Wood grain on the mask*: 1 px brown vertical lines every 3-4 px inside the cream face, broken irregularly.
- *Registration marks*: small cream crosshairs (5x5, 1 px lines) at the four corners of the hero zone.

**Lettering.**
- Logo "SONAZZOS": hand-carved caps, 12 px tall, letters 11 px wide, 2 px gap, strokes 2 px with 1 px chisel nicks (black notches) at random stroke ends, baseline jitter of 0 or 1 px per letter. Width = 8x11 + 7x2 = 102 px. Cream key layer; red layer is the same glyphs offset (+1, +1) underneath, showing as a 1 px red "misprint" edge bottom-right.
- UI text: 5x7 caps, 1 px spacing, cream on black/red, brown when locked. Small text (colophon, captions): 3x5 caps in warm grey. No other sizes.

**Buttons = carved blocks.** Rectangles with **notched corners** (1 px removed at each corner, plus a 2x2 cut on the top-left corner only, like a block's registration notch). 2 px brown "block thickness" shadow bottom and right. Secondary: 1 px cream outline; primary: solid red.

**States.**
- *Pressed* ("pulling the print"): block moves +1 px down/right onto its shadow (shadow disappears), interior inverts for 1 frame (cream fill, black text), then returns on release.
- *Selected/focused* (keyboard/gamepad, or last-used): a 3 px red rope knot appears left of the block, centred vertically, and the outline thickens to 2 px.
- *Locked*: block printed in brown only (outline, text), 1 px brown diagonal hatch every 4 px (the "uncut block"), 7x7 tongueless-bell icon instead of any arrow.

**Icons.** 9x9 or 11x11, 1 px cream lines on black, drawn as if stamped with a small carved stamp (one corner slightly broken - a 1 px gap). Subjects from the culture only: gear = a cart-wheel with 6 spokes; Learn = a single bell with a "?" tongue; Ranks = three bells of descending size; back = the rope curling left.

**Motion to the beat** (menu music, 60-180 BPM). Approved curve: drop on the beat, hold 0.03 s, ease back over 0.10 s (fast tempos) to 0.20 s (slow), scaled linearly by BPM.
- Bell cluster: drops 2 px, all bells together (the unison jump). Bell tongues (clappers) swing 1 px opposite and back.
- Mask + fleece: drops 1 px, same moment.
- Logo red layer: on beat 1 of each bar only, red offset jumps from (+1,+1) to (+2,+2) during the hold, then back.
- Nothing else moves. Buttons are always still.

## 3. Main screen spec (one layout)

Coordinates are (x, y, w, h) in art pixels.

| # | Element | Box | Content / colours | Motion |
|---|---|---|---|---|
| 0 | Background + frame | full | Black with gouge chatter. Outer 4 px border: carved "wolf-tooth" zig-zag (triangles 4 px wide, 3 px tall) in brown on black, inner 1 px warm grey line at inset 4. | none |
| 1 | Settings (gear) | 114, 5, 13, 13 | 11x11 cart-wheel icon, cream, inside a 13x13 touch box (invisible). Top-right corner, overlapping the border region by design. | none |
| 2 | Logo | 16, 22, 102, 14 | "SONAZZOS" carved lettering, cream + red misprint layer. 3x5 warm grey "MAMOIADA" centred at y=17. | red jump on bar downbeat |
| 3 | Hero: carriga straps | 22, 46, 91, 30 | Two leather straps crossing in an X, 4 px wide, brown with 1 px warm grey stitch marks every 3 px; meet at centre x=67, y=60 under a 7x5 warm grey buckle. | drops with bells |
| 4 | Hero: visera | 44, 52, 47, 50 | Frontal carved mask: cream face, wood grain lines, deep black eye sockets (6x4 each, at y+16), long carved nose ridge (brown 2 px), small closed mouth line. Calm and dignified. Surrounded by a 7 px ring of sheepskin curls (x 37-98, y 46-108), and a black kerchief knot under the chin (2 rows). | drops 1 px |
| 5 | Hero: sonazzos | 20, 108, 95, 36 | 7 bells hanging in a shallow arc from a strap, largest centre (15x20), then 12x16, 10x13, 8x10 each side. Bells: black body, 1 px cream outline, 2 px warm grey highlight stripe on left, brown carved bands, cream tongue visible under each mouth. | drop 2 px together, tongues swing |
| 6 | Registration marks | 10,44 / 120,44 / 10,140 / 120,140 | 5x5 cream crosshairs. | none |
| 7 | Rope divider | 8, 150, 119, 4 | Soha rope: twisted pattern, alternating 2-px diagonal warm grey / brown segments, red 2x2 knot at both ends. | none |
| 8 | **Continue** | 8, 160, 119, 44 | Red-filled carved block, 2 px brown shadow. Line 1 at y+8: "CONTINUE" 5x7 cream, left-aligned at x+8. Line 2 at y+20: "STOP 4" 5x7 cream; line 3 at y+31: "CARNIVAL SUNDAY" 5x7 cream (max 18 chars). Right side: 11x15 cream bell-in-arrow glyph pointing right at x+100, centred. First launch: single centred line "START" and a 3x5 "SANT'ANTONIO" caption. | none (still) |
| 9 | **Story** | 8, 212, 57, 34 | Outlined block, 1 px cream, black fill. 11x11 icon (a small mask profile) at x+6,y+6; "STORY" 5x7 cream at x+6, y+22. | none |
| 10 | **Songs** | 70, 212, 57, 34 | Same as Story; icon = single bell with 3 short sound strokes; "SONGS". | none |
| 11 | Rope divider | 8, 254, 119, 4 | As #7, no red knots. | none |
| 12 | Learn (small) | 8, 264, 40, 16 | No outline; 9x9 bell-"?" icon + "LEARN" in 5x7 warm grey. Touch box 40x20. | none |
| 13 | Ranks (small) | 87, 264, 40, 16 | Mirror of Learn: "RANKS" + 3-bell icon, right-aligned. | none |
| 14 | Colophon | 8, 288, 119, 6 | 3x5 warm grey, centred: "16 GENNAIO - MARTEDI GRASSO" (printer's credit line of a poster). | none |

Thumb reach: Continue, Story, Songs and Learn/Ranks all sit in the lower 47% (y >= 160). Minimum touch target 11x11 art px (44 real px); spacing between targets >= 5 px.

**Variants (optional, try only after the main layout works).**
- *A - Su Ennanu (the doorway)*: replace the hero frame with a frontal Mamoiada granite door lintel (blocky stones, brown with warm grey mortar), mask and bells seen inside the dark doorway; buttons become the door's planks.
- *B - Su Programma*: Continue printed as the highlighted date row in a festival calendar ("SUN 4 - CARNIVAL SUNDAY"), with the other stops faintly printed in brown above and below it.

**Other menus** reuse the kit: rope dividers, carved blocks, stamped icons, black chatter background, colophon line. The Story map is a printed programme (a vertical list of dated stops on a rope), not a road.

## 4. Do not

- No street, road, perspective or vanishing point; no procession of small figures.
- No hit rings, ovals or circular note-shaped buttons; no dotted lane lines; no star-field or sparkle backgrounds.
- No horror: no glowing/red eyes, fangs, blood-like red, skulls, fog, menacing angles. The mask is calm and frontal.
- No gradients, glows, anti-aliasing, rotations by non-90 degrees, or scaled sprites; dithering only; nearest-neighbour 4x.
- No ink outside the five; no red used as decoration.
- No scrolling, progress bars, Quit, shop, daily rewards, news, profile, badges or notification dots.
- Buttons never move to the beat; only the bells, mask and logo red layer do.
