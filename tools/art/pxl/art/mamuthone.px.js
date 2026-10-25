// The Mamuthone at rest, 142 x 172 art px (the game's figure canvas), drawn pixel by pixel from the
// style bible: black sheepskin mastruca hanging in tufts, dark carved mask under a brown kerchief,
// bells on the back and a bandolier on the chest. Lit from the bonfire: the figure stands on the
// right of the screen, so the fire is on its left and the left edges carry the warm rim.
//   node tools/art/pxl/bin/pxl.js build tools/art/pxl/art/mamuthone.px.js
include("palette.px.js")
keys({
  k: "K0", K: "K1",
  // fleece, dark to lit
  a: "FLEECE0", b: "FLEECE1", c: "FLEECE2", d: "FLEECE3", e: "FLEECE4", f: "FLEECE5",
  // kerchief / leather
  l: "LEATHER0", m: "LEATHER1", n: "LEATHER2", o: "LEATHER3",
  // mask wood
  w: "WOOD0", x: "WOOD1", y: "WOOD2", z: "WOOD3", v: "WOOD4",
  // bells
  g: "GOLD1", h: "GOLD2", i: "GOLD3", j: "GOLD4", J: "GOLD5",
  // skin
  s: "SKIN0", t: "SKIN1", u: "SKIN2",
  // rim light from the fire
  r: "FIRE4", R: "FIRE5",
  // cloth
  p: "NIGHT0", q: "NIGHT1", Q: "NIGHT2"
})

// --- a hanging tuft: a few strands pointing down, lighter at the tip -------------------------
sprite("_tuft_a", `
  .cc.
  .cdc
  .cdc
  .cde
  ..de
  ..de
  ..e.`)
sprite("_tuft_b", `
  c.c.
  cdc.
  cdd.
  .dde
  .dde
  ..ee
  ..e.`)
sprite("_tuft_c", `
  ..cc
  .cdc
  .cdd
  cdde
  cde.
  .ee.`)
group("_tufts", ["_tuft_a", "_tuft_b", "_tuft_c"])
sprite("_tuft_dark", `
  .bb.
  .bcb
  .bcb
  ..cb
  ..c.`)

// the mantle's outline: shoulders (y 36) down to a ragged hem near y 138
const MANTLE = [
  38, 42, 50, 36, 62, 33, 80, 33, 92, 37, 103, 46, 111, 62, 117, 86, 124, 112, 128, 134,
  118, 140, 110, 136, 100, 144, 90, 138, 80, 146, 70, 139, 60, 145, 50, 138, 40, 144,
  30, 136, 20, 141, 14, 134, 18, 110, 24, 86, 29, 62
]

sprite("mamuthone", { w: 142, h: 172, outline: "k" },
  // --- back bells, peeking over the right shoulder
  layer("backbells",
    poly([88, 6, 104, 4, 108, 22, 94, 28], "h"),
    poly([88, 6, 104, 4, 105, 9, 89, 11], "j"),
    ellipse(96, 6, 8, 3, "g"),
    poly([104, 20, 120, 18, 124, 34, 108, 40], "h"),
    ellipse(112, 20, 8, 3, "g"),
    poly([114, 32, 126, 31, 128, 46, 116, 50], "h"),
    ellipse(120, 32, 6, 2, "g")),
  // --- legs: dark cloth, striped gaiters, boots
  layer("legs",
    poly([44, 136, 66, 136, 64, 150, 62, 166, 44, 166, 46, 150], "p"),
    poly([76, 136, 98, 136, 100, 150, 100, 162, 82, 162, 80, 150], "p"),
    // gaiter stripes
    ...[148, 152, 156, 160].map((y) => rect(46, y, 18, 2, "m")),
    ...[146, 150, 154, 158].map((y) => rect(80, y, 18, 2, "m")),
    // boots
    poly([40, 164, 66, 164, 68, 170, 36, 171], "x"),
    poly([82, 160, 106, 160, 112, 168, 104, 171, 82, 170], "x"),
    rect(40, 168, 28, 2, "w"), rect(84, 167, 26, 2, "w")),
  // --- the fleece mantle
  layer("mantle",
    poly(MANTLE, "b"),
    // the dark inner mass under the tufts, darker toward the right (away from the fire)
    poly([34, 60, 110, 60, 118, 120, 28, 120], "a"),
    // tufts from the shoulders down, rows getting lighter at the edges on the fire's side
    scatter("_tuft_dark", 20, 40, 100, 100, 220, { on: "ab", clip: true, seed: 3, rflip: "x" }),
    scatter("_tufts", 14, 36, 112, 112, 360, { on: "abc", clip: true, seed: 7, rflip: "x" })),
  // --- arms: dark sleeves, hands
  layer("arms",
    poly([24, 72, 40, 66, 46, 96, 36, 112, 24, 104], "c"),
    poly([24, 72, 40, 66, 41, 74, 26, 80], "d"),
    ellipse(30, 116, 6, 7, "t"), ellipse(30, 116, 6, 7, "s", true),
    poly([100, 66, 116, 72, 120, 104, 108, 112, 98, 96], "b"),
    ellipse(112, 118, 6, 7, "t")),
  // --- bandolier of bells at the chest
  layer("bandolier",
    poly([46, 44, 58, 44, 84, 100, 74, 104], "n"),
    poly([86, 44, 98, 44, 72, 104, 62, 100], "m"),
    ...[[54, 74], [64, 82], [74, 74], [60, 92], [70, 90]].map(([x, y]) => [
      poly([x - 5, y - 2, x + 5, y - 2, x + 7, y + 10, x - 7, y + 10], "h"),
      rect(x - 5, y - 2, 10, 3, "j"), rect(x - 1, y + 9, 2, 3, "g")]).flat()),
  // --- kerchief and mask
  layer("head",
    poly([44, 12, 60, 4, 78, 4, 94, 14, 98, 36, 88, 44, 76, 40, 66, 40, 54, 44, 42, 38], "n"),
    poly([44, 12, 60, 4, 78, 4, 90, 10, 80, 12, 62, 12, 50, 20], "o"),
    // the mask: dark carved wood, oval, with slit eyes and a long nose
    ellipse(70, 28, 12, 17, "x"),
    ellipse(70, 28, 12, 17, "w", true),
    // lit cheek on the fire's side
    rect(60, 22, 3, 14, "z"),
    // eyes, nose, mouth
    rect(62, 22, 5, 2, "k"), rect(73, 22, 5, 2, "k"),
    vline(70, 24, 11, "y"), rect(68, 34, 4, 1, "w"),
    rect(66, 40, 8, 1, "k")),
  // the rim light: a one pixel warm edge on the fire's (left) side of the mantle
  (c) => {
    for (let y = 36; y < 140; y++) for (let x = 0; x < 70; x++) {
      if (c.is(x, y, "*") && !c.is(x - 1, y, "*")) { c.px(x, y, "r"); break }
    }
  })
