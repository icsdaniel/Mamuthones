// Hit bursts on the hit line, as 8-frame pixel animations (50 ms a frame, StreetSkin.BURST_FRAMES):
// a white flash filling the slot, the pintadera's rim and teeth stamped in the hit's colour and
// breaking up, a short shock ring that stays inside its own lane, and square embers thrown up that
// cool from white through gold to red. A miss: a dull red ring sinking and a few grey cinders.
//   node tools/art/pxl/bin/pxl.js build tools/art/pxl/art/bursts.px.js
// burst_<quality>_<w>x<h>: w x h is the slot's footprint in art px (the canvas is larger: the
// shock ring and the embers above). The footprint's centre sits at (canvas w / 2, canvas h - FOOT).
include("palette.px.js")
keys({ w: "STAR1", W: "FIRE7", g: "GOLD5", G: "GOLD4", o: "FIRE5", O: "FIRE4", r: "FIRE3", R: "FIRE2",
       x: "RED3", X: "RED2", s: "BONE1", S: "BONE0", k: "K1" })
pal({ h: "#9cf0a8", H: "#26b862" })      // heal: the green notes' own colours

const N = 8
const RISE = 30          // art px above the footprint for the embers
// each quality: [stamp colour, light colour, footprint scale]
const Q = {
  perfect: ["w", "W", 1.25], good: ["G", "g", 1.0], ok: ["O", "o", 1.0], heal: ["H", "h", 1.0],
  held: ["G", "g", 1.0], stomp: ["o", "W", 1.6],
}
const EMBER = ["w", "W", "g", "o", "O", "r", "R"]

function ellipsePx(c, cx, cy, rx, ry, col, thick = 0) {
  // filled (thick 0), or only its edge `thick` px deep: a clean contour on whole pixels
  const inside = (x, y) => ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1
  for (let y = Math.floor(cy - ry - 1); y <= cy + ry + 1; y++)
    for (let x = Math.floor(cx - rx - 1); x <= cx + rx + 1; x++) {
      if (!inside(x, y)) continue
      if (thick) {
        let edge = false
        for (let d = 1; d <= thick && !edge; d++)
          edge = !inside(x - d, y) || !inside(x + d, y) || !inside(x, y - d) || !inside(x, y + d)
        if (!edge) continue
      }
      if (x >= 0 && y >= 0 && x < c.w && y < c.h) c.px(x, y, col)
    }
}

function burst(fw, fh, q) {
  const [col, hot, big] = Q[q]
  const rx0 = fw / 2 * big, ry0 = fh / 2 * big
  const W = Math.ceil(rx0 * 2 * 1.3) + 4, H = Math.ceil(ry0 * 2 * 1.3) + RISE + 2
  const cx = W / 2, cy = H - Math.ceil(ry0 * 1.3) - 2
  return (c) => {
    const f = c.frame, t = f / (N - 1), e = 1 - (1 - t) ** 3
    const rx = rx0 * (1 + 0.15 * e), ry = ry0 * (1 + 0.15 * e)
    // the flash: the slot lit white for the first frame
    // (a checkerboard of the slot, so the ring under it still shows through)
    if (f === 0) {
      ellipsePx(c, cx, cy, rx * 0.95, ry * 0.95, "W", 3)
      for (let y = 0; y < c.h; y++) for (let x = (y + 1) % 2; x < c.w; x += 2)
        if (((x + 0.5 - cx) / (rx * 0.8)) ** 2 + ((y + 0.5 - cy) / (ry * 0.8)) ** 2 <= 1) c.px(x, y, "W")
    }
    if (f === 1) ellipsePx(c, cx, cy, rx * 0.9, ry * 0.9, hot, 2)
    // the stamp: rim and twelve teeth, whole, then every other piece, then gone
    const keep = f <= 2 ? 1 : f <= 4 ? 2 : 0
    if (keep) {
      ellipsePx(c, cx, cy, rx * 0.86, ry * 0.86, col, f <= 2 ? 2 : 1)
      for (let i = 0; i < 12; i += keep) {
        const a0 = Math.PI * 2 * i / 12, a1 = Math.PI * 2 * (i + 1) / 12, am = (a0 + a1) / 2
        const P = (a, k) => [Math.round(cx + Math.cos(a) * rx * k), Math.round(cy + Math.sin(a) * ry * k)]
        c.poly([...P(a0, 0.46), ...P(am, 0.72), ...P(a1, 0.46)], col)
      }
    }
    // the shock ring: out to 1.3x the slot and gone by frame 5, 2 px then 1 px
    if (f >= 1 && f <= 4) {
      const k = 1 + 0.3 * (f / 4)
      ellipsePx(c, cx, cy, rx0 * k, ry0 * k, f <= 2 ? hot : col, f <= 2 ? 2 : 1)
    }
    // embers: thrown up out of the slot, falling back, cooling; some die early so the spray thins
    for (let i = 0; i < (q === "stomp" ? 14 : 10); i++) {
      const hsh = Math.sin(i * 127.1 + fw * 3.7) * 43758.5453
      const r1 = hsh - Math.floor(hsh), r2 = (hsh * 7.13) % 1, r3 = (hsh * 3.31) % 1
      if (t > 0.5 + 0.5 * Math.abs(r3)) continue
      const ang = -Math.PI * (0.15 + 0.7 * r1)
      const spd = (RISE + ry0) * (0.9 + 0.8 * Math.abs(r2)) * big
      const tt = t * 0.9
      const x = Math.round(cx + Math.cos(ang) * spd * tt * (rx0 / RISE) * 0.9)
      const y = Math.round(cy - ry0 * 0.3 + Math.sin(ang) * spd * tt + spd * 0.9 * tt * tt)
      const ec = EMBER[Math.min(EMBER.length - 1, Math.floor(t * EMBER.length + i % 2))]
      const sz = t < 0.55 && i % 2 === 0 ? 2 : 1
      c.rect(x, y, sz, sz, q === "heal" && t < 0.5 ? "h" : ec)
    }
  }
}

function miss(fw, fh) {
  const rx0 = fw / 2, ry0 = fh / 2
  const W = Math.ceil(rx0 * 2 * 1.3) + 4, H = Math.ceil(ry0 * 2 * 1.3) + RISE + 2
  const cx = W / 2, cy = H - Math.ceil(ry0 * 1.3) - 2
  return (c) => {
    const f = c.frame, t = f / (N - 1)
    if (f <= 5) ellipsePx(c, cx, cy + f * 0.3, rx0 * (1 + 0.05 * f), ry0 * (1 + 0.05 * f), f <= 2 ? "x" : "X", f <= 3 ? 2 : 1)
    for (let i = 0; i < 5; i++) {
      const hsh = Math.sin(i * 91.7 + fw) * 43758.5453
      const r1 = hsh - Math.floor(hsh)
      const x = Math.round(cx + (r1 - 0.5) * rx0 * 1.4)
      const y = Math.round(cy - ry0 * 0.5 - 10 * t + 14 * t * t - i % 2 * 3)
      if (t < 0.8) c.px(x, y, t < 0.4 ? "s" : "S")
    }
  }
}

for (const fw of [56, 60, 64]) {
  const fh = Math.round(fw * 0.36)
  for (const q of Object.keys(Q)) anim(`burst_${q}_${fw}x${fh}`, { frames: N, fps: 20, ...size(fw, fh, Q[q][2]) }, burst(fw, fh, q))
  anim(`burst_miss_${fw}x${fh}`, { frames: N, fps: 20, ...size(fw, fh, 1) }, miss(fw, fh))
}

function size(fw, fh, big) {
  const rx0 = fw / 2 * big, ry0 = fh / 2 * big
  return { w: Math.ceil(rx0 * 2 * 1.3) + 4, h: Math.ceil(ry0 * 2 * 1.3) + RISE + 2 }
}
