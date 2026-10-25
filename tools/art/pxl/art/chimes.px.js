// The sound arcs thrown out beside a struck cowbell: "(" and ")" curves, on whole pixels. One left
// arc per radius (art px) and thickness; the game flips it for the right side and tints it (the
// sprite is pure white, so the tint is exactly the tilt's colour, white-hot to cooled).
//   node tools/art/pxl/bin/pxl.js build tools/art/pxl/art/chimes.px.js
// chime_<R>_<T>: R the arc's radius, T its thickness. Spans +-0.5 rad about the left, as StreetSkin.bell_strike.
include("palette.px.js")
keys({ w: "STAR1", k: "K0" })

const HALF = 0.5
for (let R = 14; R <= 72; R += 2) {
  for (const T of [1, 2]) {
    const sx = Math.max(2, Math.ceil(R * (1 - Math.cos(HALF))) + T + 1)
    const sy = Math.ceil(2 * R * Math.sin(HALF)) + 2
    sprite(`chime_${R}_${T}`, { w: sx, h: sy }, (c) => {
      // a circle of radius R centred R to the right of the sprite's left edge; the arc is its left side
      for (let y = 0; y < sy; y++) for (let x = 0; x < sx; x++) {
        const ddx = x + 0.5 - R, ddy = y + 0.5 - sy / 2
        const d = Math.hypot(ddx, ddy)
        if (Math.abs(Math.atan2(ddy, -ddx)) <= HALF && d <= R && d > R - T) c.px(x, y, "w")
      }
    })
  }
}
