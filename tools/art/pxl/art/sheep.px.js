// A sheep: a fresh pxl test (not used in the game). Side view facing right, lit from the upper left
// by a fire: warm cream wool in puffs, a dark Sardinian face and legs.
//   node tools/art/pxl/bin/pxl.js build tools/art/pxl/art/sheep.px.js
include("palette.px.js")
keys({
  k: "K0", K: "K1",
  // wool, dark to lit (shade -> light)
  a: "BONE0", b: "BONE1", c: "BONE2", d: "BONE3", e: "BONE4",
  // warm cast on the wool near the fire and cold on the far side
  w: "STONE5", W: "GOLD5", n: "NIGHT4",
  // face and legs: dark wood and fleece
  f: "FLEECE2", g: "FLEECE3", h: "FLEECE4", i: "STONE4",
  // skin (nose, ear inside, hoof highlight)
  s: "SKIN1", t: "SKIN2", u: "SKIN0",
  // eye
  y: "GOLD4"
})
ramps("abcde", "fghi", "ust")

// one puff of wool: lit from the upper left, a dark crescent of shade lower right, a curl line
function puff(c, cx, cy, r, curl = true) {
  c.circ(cx, cy, r, "b")                                    // shade: the whole puff, dark
  c.circ(cx - 1, cy - 1, r - 1, "c")                        // body, shifted up-left so the shade shows lower right
  c.circ(cx - 1, cy - 2, Math.max(1, r - 3), "d")           // lit
  if (r >= 5) c.circ(cx - 2, cy - 3, Math.max(1, r - 5), "e")
  if (curl && r >= 4) {                                     // a curl: a short dark arc through the puff
    c.px(cx + 1, cy, "b"); c.px(cx + 2, cy + 1, "b"); c.px(cx + 2, cy + 2, "b"); c.px(cx + 1, cy + 3, "b")
  }
}

// the wool: back puffs first, then the body mass, then big front puffs overlapping the rows behind
sprite("_wool", { w: 58, h: 38 },
  (c) => {
    for (const [x, y, r] of [[28, 8, 6], [37, 7, 7], [46, 11, 6], [20, 11, 6], [52, 18, 5], [12, 17, 5]]) puff(c, x, y, r, false)
  },
  ellipse(31, 22, 25, 11, "b"),
  (c) => {
    for (const [x, y, r, k] of [
      [10, 22, 6], [17, 17, 8], [27, 14, 7], [35, 16, 9], [45, 15, 7], [51, 22, 6],
      [13, 30, 6], [22, 27, 8], [32, 30, 7], [41, 27, 8], [49, 30, 5], [6, 26, 4]]) puff(c, x, y, r)
  },
  // wool tufts breaking the silhouette
  px(30, 3, "d"), px(31, 3, "d"), px(41, 1, "d"), px(42, 1, "c"), px(7, 21, "d"), px(55, 28, "c"))

// head, facing right and a little down: a long dark face with a lit brow and muzzle, a gold eye
// under a heavy lid, a pink nose, a thin mouth line
sprite("_head", { outline: "k" }, `
  .....hhhhh......
  ....hgggggh.....
  ...hggghggghh...
  ..hgggihhggggh..
  .hggggiiihgggggh
  .hgggggihgggggih
  hggggkkkggggggih
  hgggkyyykgggiiih
  hggggkkkgggiiiih
  hgggggggggiiiiih
  .hggggggghiiiisu
  .hgggggghiiiiiss
  ..hggggghiiiiisk
  ...hhgggghhiiiih
  ......hhhhhhhh..`)
// the ear flops out to the back, pink inside
sprite("_ear", { outline: "k" }, `
  ..ggh
  .gggg
  gssgg
  gsgg.
  ggg..
  gg...`)

// a leg: a wool sleeve, a dark shin that narrows to the knee, a black hoof
sprite("_leg", { outline: "k" }, `
  bcb
  bcb
  hgh
  hgh
  hgh
  hg.
  hg.
  hg.
  hg.
  hg.
  hg.
  kk.`)

sprite("sheep", { w: 76, h: 66, outline: "k" },
  // a soft ground shadow
  ellipse(36, 57, 26, 3, "K"), ellipse(36, 57, 18, 2, "k"),
  // far legs behind the body, in the cold
  stamp("_leg", 22, 40, { swap: { h: "f", g: "f", b: "a", c: "a" } }), stamp("_leg", 42, 40, { swap: { h: "f", g: "f", b: "a", c: "a" } }),
  stamp("_wool", 2, 4),
  stamp("_leg", 13, 42), stamp("_leg", 47, 42),
  (c) => puff(c, 4, 22, 4, false),
  // the neck ruff, so the head sits in wool rather than on it
  (c) => { puff(c, 50, 22, 5); puff(c, 52, 14, 4, false) },
  stamp("_ear", 51, 7),
  stamp("_head", 52, 8))
