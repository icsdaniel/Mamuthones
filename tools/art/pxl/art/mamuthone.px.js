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

// ---------------------------------------------------------------- the mantle's outline
// Left and right edge per row, every 4 rows from y 34 (taken from the figure's own layout).
const LEFT = [56, 35, 17, 15, 14, 13, 13, 13, 13, 14, 15, 15, 16, 17, 18, 18, 17, 19, 20, 20, 18, 17, 17, 17, 18, 19, 21, 23, 25]
const RIGHT = [92, 92, 93, 98, 97, 96, 100, 103, 103, 103, 100, 97, 98, 100, 102, 102, 99, 102, 104, 104, 103, 103, 102, 101, 99, 98, 99, 100, 101]
const at = (arr, y) => {
  const f = Math.max(0, Math.min(arr.length - 1.001, (y - 34) / 4)), i = Math.floor(f)
  return arr[i] + (arr[i + 1] - arr[i]) * (f - i)
}
const HEM = 132
const mantle = []
for (let y = 36; y <= HEM; y += 4) mantle.push(Math.round(at(LEFT, y)), y)
for (let y = HEM; y >= 36; y -= 4) mantle.push(Math.round(at(RIGHT, y)), y)

sprite("_mass", { w: 140, h: 170 },
  poly(mantle, "a"),
  // the fire's side of the mantle a step lighter, falling off to the right
  clip([14, 40, 34, 94], rect(0, 0, 140, 170, "b")),
  clip([14, 40, 16, 60], rect(0, 0, 140, 170, "c")))

// Rows of tufts, bottom up so each row hangs over the one below. Which tone a tuft takes follows the
// fire: lit on the left and on the shoulders, cold on the right.
sprite("_fleece", { w: 140, h: 170 },
  stamp("_mass", 0, 0),
  (c) => {
    const r = c.rng(21)
    for (let y = 124; y >= 34; y -= 7) {
      const l = at(LEFT, y + 8), rr = at(RIGHT, y + 8), span = rr - l
      for (let x = l - 5 + (((y / 7) | 0) % 2) * 5; x < rr + 3; x += 10) {
        const t = (x - l) / span, up = 1 - (y - 34) / 100
        const lit = 1 - t * 1.25 + up * 0.35 + (r() - 0.5) * 0.3
        const tone = lit > 0.62 ? "lit" : lit > 0.18 ? "mid" : "cold"
        const size = y > 118 ? "l" : (r() < 0.45 ? "m" : "s")
        const w = size === "s" ? 9 : size === "m" ? 11 : 13
        c.stamp(`_t_${tone}_${size}`, Math.round(x - w / 2 + (r() * 3 - 1.5)), y + Math.round(r() * 3 - 1), { rflip: r() < 0.25 ? "x" : undefined })
      }
    }
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
    for (let y = y0 + 8; y < y1 - 3; y += 4) { c.hline(x0, y, x1 - x0 + 1, "m"); c.hline(x0, y + 1, x1 - x0 + 1, "l") }
  }
  leg(26, 39, 128, 162, true)
  leg(90, 104, 128, 156, false)
  // the planted boot, toe toward the road
  c.poly([10, 160, 40, 160, 41, 169, 9, 169], "x"); c.hline(10, 160, 30, "z"); c.hline(9, 168, 33, "w"); c.vline(10, 161, 7, "y")
  // the trailing boot, heel up, toe down
  c.poly([88, 154, 106, 154, 108, 160, 98, 168, 88, 168], "x"); c.hline(88, 154, 18, "y"); c.vline(88, 156, 12, "w")
}
const PIECE = { w: 140, h: 170, outline: "k" }   // 140 x 170 plus the 1 px outline = the 142 x 172 canvas
sprite("mamuthone_body", PIECE,
  legs,
  stamp("_fleece", 0, 0),
  forearm,
  // the bonfire's rim on the left edge of the mantle: warm leather, a fire pixel now and then
  (c) => { for (let y = 38; y < 132; y++) for (let x = 0; x < 72; x++) if (c.is(x, y, "*") && !c.is(x, y, "k")) { if (y % 4 === 0) c.px(x, y, "r"); break } })
sprite("mamuthone_back_bells", PIECE,
  (c) => { bell(c, 70, 14, 24, 27, 28); bell(c, 88, 30, 20, 23, 46); bell(c, 97, 50, 16, 19, 64) },
  line(60, 24, 94, 56, "m", 2))
sprite("mamuthone_front_bells", PIECE,
  line(26, 52, 62, 98, "n", 4), line(26, 52, 62, 98, "m", 1), line(28, 52, 64, 98, "o", 1),
  (c) => { [[32, 64], [42, 74], [52, 86], [38, 84], [48, 96]].forEach(([x, y], i) => bell(c, x, y, 12, 14, 0, i < 3)) })
sprite("mamuthone_head", { w: 142, h: 172 }, stamp("_head", 17, 5))
sprite("test_figure", { w: 142, h: 172 },
  stamp("mamuthone_body", 0, 0), stamp("mamuthone_back_bells", 0, 0), stamp("mamuthone_front_bells", 0, 0), stamp("mamuthone_head", 0, 0))
