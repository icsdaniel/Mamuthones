// The Mamuthone, 142 x 172 art px (the game's figure canvas), as the four pieces PixelFigure bobs:
// body, back bells, front bells, head. Same layout as the figure it would replace: the mantle spans
// x 14..102 from the shoulders (y 36) to a ragged hem (y ~140), head at x 16..63 / y 7..59, back bells
// up and to the right, a bandolier of bells on the chest, legs planted wide apart.
// Lit by the bonfire, which is to this figure's LEFT: warm tips and a lit edge on the left, cold
// dark tufts to the right. Fleece is black sheepskin: near-black body, tips taking the firelight.
//   node tools/art/pxl/bin/pxl.js build tools/art/pxl/art/mamuthone.px.js --only mamuthone_body
include("palette.px.js")
include("mam_head.px.js")
keys({
  k: "K0", K: "K1",
  // fleece, dark to lit
  a: "FLEECE0", b: "FLEECE2", c: "FLEECE4", d: "FLEECE5", e: "LEATHER2", f: "LEATHER3", E: "STONE5",
  // cold shadow for the side away from the fire
  N: "NIGHT0", M: "NIGHT1",
  // leather, wood, bronze, skin
  l: "LEATHER0", m: "LEATHER1", n: "LEATHER2", o: "LEATHER3",
  w: "WOOD0", x: "WOOD1", y: "WOOD2", z: "WOOD3",
  g: "GOLD1", h: "GOLD2", i: "GOLD3", j: "GOLD4", J: "GOLD5",
  s: "SKIN0", t: "SKIN1", u: "SKIN2",
  r: "FIRE4", R: "FIRE5"
})
ramps("abcd", "wxyz", "lmno", "ghijJ", "stu")

// ---------------------------------------------------------------- tufts (hanging, tip down)
// A tuft is a clump of strands: a curved body that narrows to a tip, a dark root where the row above
// hangs over it, its right half a step darker, a lit edge down the left and a bright tip. Three
// tones: lit (the fire's side: warm tips), mid, and cold (away from the fire).
const TONES = {
  lit:  { root: "b", body: "d", shade: "c", edge: "f", tip: "E", spark: "E" },
  mid:  { root: "a", body: "c", shade: "b", edge: "e", tip: "f", spark: "e" },
  cold: { root: "a", body: "b", shade: "a", edge: "c", tip: "d", spark: "d" },
}
for (const tone of Object.keys(TONES)) for (const [size, w, h] of [["s", 9, 15], ["m", 11, 19], ["l", 13, 25]]) {
  const T = TONES[tone]
  sprite(`_t_${tone}_${size}`, { w, h },
    (c) => {
      // the clump: wide at the root, narrowing with a slight curve to the left toward the tip
      const hw = (w - 1) / 2
      for (let y = 0; y < h; y++) {
        const k = y / (h - 1)
        const half = hw * (1 - Math.pow(k, 1.3))
        const mid = hw - k * k * 1.6
        const x0 = Math.round(mid - half), x1 = Math.round(mid + half)
        c.hline(x0, y, x1 - x0 + 1, y < 2 ? T.root : T.body)
        // the right half a step darker
        if (y >= 2) c.hline(Math.round(mid) + 1, y, Math.max(0, x1 - Math.round(mid)), T.shade)
        // lit left edge, brighter toward the tip
        if (y >= 2) c.px(x0, y, k > 0.55 ? T.tip : T.edge)
      }
      // a strand split in the body and a bright tip
      const tipx = Math.round(hw - 1.6)
      c.px(tipx, h - 1, T.spark)
      c.vline(Math.round(hw) - 1, 4, Math.floor(h * 0.45), T.shade)
    })
}

// ---------------------------------------------------------------- the two tiers
// Like the figure it replaces: a short fleece cape over the shoulders (y 38..92), a dark wool torso and
// sleeves showing under it, a belt, and a longer ragged skirt of fleece (y 96..142) over the legs.
const capeL = (y) => 12 + Math.max(0, 52 - y) * 0.9 - (y - 52) * 0.1
const capeR = (y) => 96 + (y - 38) * 0.18
const skirtL = (y) => 19 - (y - 96) * 0.3
const skirtR = (y) => 98 + (y - 96) * 0.25

sprite("_torso", { w: 140, h: 170 },
  // dark wool torso and sleeves under the cape, lit on the left
  poly([26, 44, 84, 44, 88, 96, 22, 96], "b"),
  clip([18, 44, 26, 58], rect(0, 0, 140, 170, "c")),
  clip([60, 44, 30, 54], rect(0, 0, 140, 170, "a")),
  // sleeves: the fire's arm swings forward-left, the far arm hangs dark at the right
  line(20, 56, 12, 90, "c", 11), line(24, 58, 16, 90, "b", 4), line(15, 58, 8, 88, "d", 1),
  line(94, 56, 99, 92, "a", 10), line(92, 58, 96, 90, "b", 1),
  // the belt
  rect(20, 92, 76, 3, "m"), rect(20, 94, 76, 2, "l"), rect(46, 91, 7, 6, "i"), rect(48, 92, 3, 4, "g"),
  // the skirt's dark base
  poly([17, 100, 101, 100, 103, 134, 15, 134], "a"),
  clip([15, 100, 26, 34], rect(0, 0, 140, 170, "b")))

// A row of tufts along x0..x1 at row y, tone chosen by `toneAt(t, y)` (t 0 at the fire's side).
function row(c, r, y, x0, x1, pitch, sizes, toneAt) {
  for (let x = x0 + (((y / 7) | 0) % 2) * (pitch / 2); x < x1; x += pitch) {
    const t = (x - x0) / (x1 - x0)
    const size = sizes[(r() * sizes.length) | 0]
    const w = size === "s" ? 9 : size === "m" ? 11 : 13
    // outward on the right half: flip so the tips curve away from the body
    c.stamp(`_t_${toneAt(t, y)}_${size}`, Math.round(x - w / 2 + (r() * 3 - 1.5)), y + Math.round(r() * 3 - 1.5), { flip: t > 0.5 ? "x" : undefined })
  }
}
const fire = (t, y) => { const lit = 1 - t * 1.3 + (1 - (y - 38) / 100) * 0.3; return lit > 0.55 ? "lit" : lit > 0.12 ? "mid" : "cold" }

sprite("_fleece", { w: 140, h: 170 },
  stamp("_torso", 0, 0),
  (c) => {
    const r = c.rng(31)
    // the skirt, bottom up
    for (let y = 126; y >= 92; y -= 7) row(c, r, y, skirtL(y) - 3, skirtR(y) + 4, 10, y > 108 ? ["l", "l", "m"] : ["m", "l"], fire)
    // the far shoulder's fleece hangs lower on the right
    for (let y = 80; y >= 68; y -= 6) row(c, r, y, 68, 100, 10, ["m", "l"], () => "cold")
    // the cape, bottom up: long tufts at its hem, shorter above
    for (let y = 66; y >= 38; y -= 6) row(c, r, y, capeL(y) - 3, capeR(y) + 4, 10, y > 56 ? ["m", "l"] : ["s", "m"], fire)
  })

// ---------------------------------------------------------------- bells, arms, legs
// a cowbell: narrow shoulder, wide mouth, lit on the left half; (cx, cy) its middle, a in degrees
function bell(c, cx, cy, w, h, a, lit = 1) {
  const A = a * Math.PI / 180, ca = Math.cos(A), sa = Math.sin(A)
  const P = (u, v) => [Math.round(cx + u * ca - v * sa), Math.round(cy + u * sa + v * ca)]
  c.poly([...P(-w * 0.28, -h / 2), ...P(w * 0.28, -h / 2), ...P(w / 2, h / 2), ...P(-w / 2, h / 2)], "h")
  c.poly([...P(-w * 0.28, -h / 2), ...P(0, -h / 2), ...P(0, h / 2), ...P(-w / 2, h / 2)], lit ? "i" : "h")
  c.poly([...P(w * 0.1, -h / 2), ...P(w * 0.28, -h / 2), ...P(w / 2, h / 2), ...P(w * 0.2, h / 2)], "g")
  c.line(...P(-w * 0.18, -h * 0.4), ...P(-w * 0.34, h * 0.3), "J")
  c.line(...P(-w / 2, h / 2), ...P(w / 2, h / 2), "j")
  c.line(...P(-w * 0.4, h / 2 + 1), ...P(w * 0.4, h / 2 + 1), "k")
  c.px(...P(0, h / 2 + 2), "j")
  c.px(...P(0, -h / 2 - 1), "j")
}
const forearm = (c) => {
  // the fire's side arm swings out in front: a dark wool sleeve, a leather cuff and a hand
  c.line(20, 64, 12, 88, "c", 9)
  c.line(23, 64, 15, 88, "b", 4)
  c.line(16, 66, 8, 88, "d", 1)
  c.hline(5, 91, 11, "n"); c.hline(5, 92, 11, "m")
  c.ellipse(9, 99, 5, 7, "u"); c.ellipse(10, 100, 3, 5, "t"); c.vline(8, 102, 4, "s"); c.vline(11, 102, 4, "s")
}
const legs = (c) => {
  const leg = (x0, x1, y0, y1, lit) => {
    c.poly([x0, y0, x1, y0, x1, y1, x0, y1], lit ? "b" : "a")
    c.vline(x0 + 1, y0, y1 - y0, lit ? "c" : "b")
    // leather straps wound round the gaiter, slanting like a spiral wrap
    for (let y = y0 + 8; y < y1 - 3; y += 5) { c.line(x0, y + 2, x1, y, "m"); c.line(x0, y + 3, x1, y + 1, "l") }
  }
  leg(26, 39, 124, 162, true)
  leg(90, 104, 124, 156, false)
  // the planted boot, toe toward the road: black leather, a lit top edge, laces, a thick sole
  c.poly([10, 159, 40, 159, 41, 170, 9, 170], "x"); c.hline(10, 159, 30, "z"); c.poly([9, 166, 41, 166, 41, 170, 9, 170], "w")
  c.vline(10, 160, 6, "y"); c.hline(28, 162, 8, "n"); c.hline(30, 164, 6, "n"); c.hline(8, 169, 34, "l")
  // the trailing boot, heel up, toe down
  c.poly([88, 154, 106, 154, 109, 160, 99, 169, 88, 168], "x"); c.hline(88, 154, 18, "y"); c.vline(88, 156, 11, "w")
  c.hline(94, 157, 7, "n"); c.line(98, 164, 108, 160, "w")
}
const PIECE = { w: 140, h: 170, outline: "k" }   // 140 x 170 plus the 1 px outline = the 142 x 172 canvas
sprite("mamuthone_body", PIECE,
  legs,
  stamp("_fleece", 0, 0),
  forearm,
  // the bonfire's rim on the left edge of the mantle: warm leather, a fire pixel now and then
  (c) => { for (let y = 38; y < 132; y++) for (let x = 0; x < 40; x++) if (c.is(x, y, "*") && !c.is(x, y, "k")) { if (y % 4 === 0) c.px(x, y, "r"); break } })
sprite("mamuthone_back_bells", PIECE,
  (c) => { bell(c, 70, 14, 24, 27, 28); bell(c, 88, 30, 20, 23, 46); bell(c, 97, 50, 16, 19, 64) },
  line(60, 24, 94, 56, "m", 2))
sprite("mamuthone_front_bells", PIECE,
  line(26, 52, 62, 98, "n", 4), line(26, 52, 62, 98, "m", 1), line(28, 52, 64, 98, "o", 1),
  (c) => { [[32, 64], [42, 74], [52, 86], [38, 84], [48, 96]].forEach(([x, y], i) => bell(c, x, y, 12, 14, 0, i < 3)) })
sprite("mamuthone_head", { w: 142, h: 172 }, stamp("_head", 17, 5))
sprite("_test_figure", { w: 142, h: 172 },
  stamp("mamuthone_body", 0, 0), stamp("mamuthone_back_bells", 0, 0), stamp("mamuthone_front_bells", 0, 0), stamp("mamuthone_head", 0, 0))
