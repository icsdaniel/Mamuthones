// The Mamuthone at rest, 142 x 172 art px (the game's figure canvas), drawn pixel by pixel from the
// style bible: black sheepskin mastruca hanging in tufts, dark carved mask under a brown kerchief,
// bells on the back and a bandolier on the chest. Lit from the bonfire: the figure stands on the
// right of the screen, so the fire is on its left and the left edges carry the warm rim.
//   node tools/art/pxl/bin/pxl.js build tools/art/pxl/art/mamuthone.px.js
include("palette.px.js")
keys({
  k: "K0", K: "K1",
  // fleece, dark to lit: near-black sheepskin whose tips take the firelight
  a: "FLEECE0", b: "FLEECE2", c: "FLEECE4", d: "FLEECE5", e: "LEATHER2", f: "LEATHER3", E: "STONE5",
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

include("mam_head.px.js")
// The mantle: a bell flaring from the shoulders (y 34) to the hem (y ~138).
const CX = 71
const half = (y) => y < 62 ? 13 + 22 * Math.pow(Math.max(0, (y - 34) / 28), 0.7) : 35 + 17 * Math.pow((y - 62) / 70, 0.9)
const edge = (y) => [Math.round(CX - half(y)), Math.round(CX + half(y))]

// Hanging tufts, shingled: each row hangs over the one below, so draw bottom up. A tuft is a clump
// of two points: body mid tone, the side away from the fire a step darker, a dark root under the
// row above, and on the fire's side a lit edge and warm tips.
function tuft(c, x, y, w, L, lean, lit) {
  const l = x - (w >> 1), r = x + (w >> 1), tx = x + lean, ty = y + L
  const body = lit > 0.55 ? "c" : "b"
  const dark = lit > 0.55 ? "b" : "a"
  // the second, shorter point, to the lit side
  c.poly([l - 1, y + 1, x, y + 1, l + lean - 2, y + L * 0.7], body)
  c.poly([l, y, r + 1, y, tx + 1, ty], body)
  c.poly([x + 1, y, r + 1, y, tx + 1, ty], dark)
  c.hline(l - 1, y, w + 2, "a"); c.hline(l - 1, y + 1, w + 2, "a")
  if (lit <= 0.3) {
    // away from the fire: only a dim strand edge and tip, in the cold
    c.line(l, y + 2, tx, ty - 1, "c")
    if (((x + y) & 3) === 0) c.px(tx, ty - 1, "d")
  }
  if (lit > 0.3) {
    c.line(l, y + 2, tx, ty - 1, lit > 0.7 ? "e" : "d")
    c.line(l - 1, y + 3, l + lean - 2, y + L * 0.7 - 1, lit > 0.6 ? "d" : "c")
    if (lit > 0.6) c.px(tx, ty - 1, "f")
    if (lit > 0.82) { c.px(tx, ty - 2, "E"); c.px(l + lean - 2, y + L * 0.7 - 1, "f") }
  }
}
function mantle(c) {
  const r = c.rng(5)
  for (let y = 118; y >= 36; y -= 7) {
    const [l, rr] = edge(y + 6)
    const pitch = 9
    for (let x = l - 3 + (((y / 7) | 0) % 2) * 4; x <= rr + 3; x += pitch) {
      const t = (x - l) / (rr - l)
      // lit toward the fire (left) and the shoulders, with a little tuft to tuft variety
      const lit = Math.max(0, 1 - t * 1.35) * (0.6 + 0.5 * (1 - (y - 36) / 100)) + (r() * 0.2 - 0.05)
      const out = ((x - CX) / 20) | 0
      tuft(c, x, y, 11 + (r() * 3 | 0), 16 + (r() * 7 | 0), out + (r() * 3 | 0) - 1, lit)
    }
  }
}

// ---- cowbells: a rotated, ramped bell drawn from its outline; (cx, cy) the bell's middle, a in degrees
function bell(c, cx, cy, w, h, a, lit = 1) {
  const A = a * Math.PI / 180, ca = Math.cos(A), sa = Math.sin(A)
  const P = (u, v) => [Math.round(cx + u * ca - v * sa), Math.round(cy + u * sa + v * ca)]
  // body: narrow shoulder at the top, wide mouth at the bottom
  const body = [P(-w * 0.28, -h / 2), P(w * 0.28, -h / 2), P(w / 2, h / 2), P(-w / 2, h / 2)].flat()
  c.poly(body, "h")
  // lit left half, dark right half, bright rim at the mouth and a hot streak
  c.poly([...P(-w * 0.28, -h / 2), ...P(0, -h / 2), ...P(0, h / 2), ...P(-w / 2, h / 2)], lit ? "i" : "h")
  c.poly([...P(w * 0.1, -h / 2), ...P(w * 0.28, -h / 2), ...P(w / 2, h / 2), ...P(w * 0.2, h / 2)], "g")
  c.line(...P(-w * 0.18, -h * 0.4), ...P(-w * 0.34, h * 0.3), "j")
  c.line(...P(-w / 2, h / 2), ...P(w / 2, h / 2), "j")
  c.line(...P(-w / 2, h / 2 - 1), ...P(w / 2, h / 2 - 1), "g")
  // the mouth: a dark slot, and the clapper
  c.line(...P(-w * 0.4, h / 2 + 1), ...P(w * 0.4, h / 2 + 1), "k")
  c.px(...P(0, h / 2 + 2), "j")
  c.px(...P(0, -h / 2 - 1), "j")
}
// ---- a forearm in a dark wool sleeve swinging out of the mantle, with a cuff and a hand
function arm(c, x0, y0, x1, y1, lit) {
  c.line(x0, y0, x1, y1, lit ? "c" : "b", 9)
  c.line(x0 + (lit ? 3 : -3), y0, x1 + (lit ? 3 : -3), y1, lit ? "b" : "a", 4)
  c.line(x0 + (lit ? -4 : 4), y0 + 1, x1 + (lit ? -4 : 4), y1, lit ? "d" : "c", 1)
  c.hline(x1 - 5, y1, 11, "m"); c.hline(x1 - 5, y1 + 1, 11, "l")      // the leather cuff
  const hx = x1, hy = y1 + 8
  c.ellipse(hx, hy, 5, 6, lit ? "t" : "s")
  c.ellipse(hx + (lit ? 1 : -1), hy + 1, 3, 4, lit ? "u" : "t")
  c.vline(hx - 1, hy + 2, 4, "s"); c.vline(hx + 1, hy + 2, 4, "s")     // fingers
}

sprite("test_figure", { w: 142, h: 172, outline: "k" },
  // back bells above the right shoulder, behind everything
  (c) => { bell(c, 99, 22, 17, 20, 25); bell(c, 112, 37, 14, 17, 40); bell(c, 119, 54, 11, 14, 60) },
  // legs: dark trousers, leather-banded gaiters, boots
  (c) => {
    for (const [x0, lit] of [[38, 1], [82, 0]]) {
      c.poly([x0 + 2, 120, x0 + 22, 120, x0 + 22, 166, x0, 166], lit ? "b" : "a")
      c.vline(x0 + 2, 122, 42, lit ? "c" : "b")
      for (let y = 134; y < 162; y += 4) { c.hline(x0, y, 22, "m"); c.hline(x0, y + 1, 22, "l") }
      c.poly([x0 - 4, 161, x0 + 24, 161, x0 + 31, 169, x0 + 30, 171, x0 - 6, 171], "x")
      c.poly([x0 - 4, 161, x0 + 8, 161, x0 + 8, 171, x0 - 6, 171], lit ? "y" : "x")
      c.hline(x0 - 6, 169, 36, "w"); c.hline(x0 - 4, 161, 28, lit ? "z" : "y")
    }
  },
  (c) => { for (let y = 34; y <= 124; y++) { const [l, r] = edge(y); c.hline(l, y, r - l + 1, "a") } },
  mantle,
  // arms hang at the sides over the mantle, hands at the hips
  (c) => { arm(c, 34, 80, 30, 96, true); arm(c, 108, 80, 112, 96, false) },
  // the strap and the bell bandolier across the chest
  line(52, 40, 90, 100, "n", 4), line(52, 40, 90, 100, "m", 1), line(54, 40, 92, 100, "o", 1),
  (c) => { [[58, 62], [68, 74], [78, 86], [64, 84], [74, 96]].forEach(([x, y], i) => bell(c, x, y, 11, 13, 0, i < 3)) },
  stamp("head", 36, 0),
  // the bonfire's rim on the left edge of the mantle (the fire is to the left of this figure)
  (c) => { for (let y = 36; y < 126; y++) for (let x = 0; x < 72; x++) if (c.is(x, y, "*")) { c.px(x, y, "r"); if (y % 3 === 0) c.px(x + 1, y, "R"); break } })
