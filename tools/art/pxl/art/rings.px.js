// The hit rings on the hit line: a raised bone-white rim lying on the road, one per lane.
// The far (top) edge of its top catches the bonfire; the near outer wall and the far inner wall
// fall into shadow; four carved notches echo the pintadera's teeth. Ink outline outside and round
// the hollow. Idle is neutral so the game can tint it toward the coming note's colour; gold burns
// when a lane is struck, red while the buttons are locked.
//   node tools/art/pxl/bin/pxl.js build tools/art/pxl/art/rings.px.js
// Sizes are the cells the game asks for (StreetSkin._ring_pic): w x h art px.
include("palette.px.js")
keys({ k: "K0", K: "K1", a: "BONE0", b: "BONE1", c: "BONE2", d: "BONE3", e: "BONE4",
       A: "GOLD1", B: "GOLD2", C: "GOLD3", D: "GOLD4", E: "GOLD5",
       S: "GOLD4", T: "GOLD2", r: "RED0", s: "RED1", t: "RED2", u: "RED3", v: "RED4" })

const SIZES = [[60, 24], [64, 24], [56, 22], [68, 26]]
const WALL = 3      // how far the rim stands up, in art px

function rim(c) {
  const w = c.w, h = c.h
  const rx = w / 2 - 1, ry = (h - 2 - WALL) / 2
  const cx = w / 2, cy = 1 + ry
  const band = Math.max(4, Math.round(rx * 0.17))
  const irx = rx - band, iry = ry - band * ry / rx * 1.05
  const inE = (x, y, ax, ay, oy = 0) => ((x - cx) / ax) ** 2 + ((y - cy - oy) / ay) ** 2 <= 1
  const key = []
  for (let y = 0; y < h; y++) {
    key.push([])
    for (let x = 0; x < w; x++) {
      const px = x + 0.5, py = y + 0.5
      let k = "."
      const top = inE(px, py, rx, ry), hole = inE(px, py, irx, iry)
      if (top && !hole) {
        // the top of the rim, lit by where it faces on the ring
        const s = -(py - cy) / ry
        const outer = ((px - cx) / rx) ** 2 + ((py - cy) / ry) ** 2 > 0.8
        k = s > 0.6 && outer ? "e" : s > 0.1 ? "d" : "c"
        // a carved notch on each diagonal (a pintadera's teeth), two art px wide
        const ang = Math.atan2((py - cy) / ry, (px - cx) / rx) + Math.PI / 4
        const m = ((ang / (Math.PI / 2)) % 1 + 1) % 1
        const mid = ((px - cx) / ((rx + irx) / 2)) ** 2 + ((py - cy) / ((ry + iry) / 2)) ** 2
        if ((m < 0.05 || m > 0.95) && Math.abs(mid - 1) < 0.3) k = "b"
      } else if (hole && !inE(px, py, irx, iry, WALL)) {
        k = "b"                                              // the far inner wall, in shadow
      } else if (!top && inE(px, py, rx, ry, WALL) && py > cy) {
        k = inE(px, py, rx, ry, 1) ? "b" : "a"               // the near outer wall
      }
      key[y].push(k)
    }
  }
  // a bronze stud riveted on each side, where the hit line meets the ring
  for (const sx of [-1, 1]) {
    const x0 = Math.round(cx + sx * (rx + irx) / 2 - 1), y0 = Math.round(cy - 1)
    for (let y = y0; y < y0 + 2; y++) for (let x = x0; x < x0 + 2; x++) key[y][x] = y === y0 ? "S" : "T"
  }
  // ink round the outside and round the hollow's edge
  const solid = (x, y) => x >= 0 && y >= 0 && x < w && y < h && key[y][x] !== "."
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    if (solid(x, y)) { c.px(x, y, key[y][x]); continue }
    if (solid(x - 1, y) || solid(x + 1, y) || solid(x, y - 1) || solid(x, y + 1)) c.px(x, y, "k")
  }
}

for (const [w, h] of SIZES) {
  sprite(`ring_idle_${w}x${h}`, { w, h }, rim)
  sprite(`ring_gold_${w}x${h}`, { base: `ring_idle_${w}x${h}`, swap: { a: "A", b: "B", c: "C", d: "D", e: "E" } })
  sprite(`ring_red_${w}x${h}`, { base: `ring_idle_${w}x${h}`, swap: { a: "r", b: "s", c: "t", d: "u", e: "v" } })
}
