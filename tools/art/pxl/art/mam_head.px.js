include("palette.px.js")
keys({
  k: "K0", K: "K1",
  w: "WOOD0", x: "WOOD1", y: "WOOD2", z: "WOOD3", v: "WOOD4",
  l: "LEATHER0", m: "LEATHER1", n: "LEATHER2", o: "LEATHER3",
  r: "FIRE4", R: "FIRE5", e: "STONE5",
})
ramps("wxyzv", "lmno")
// Mask, 3/4 view facing left, the fire on the left: lit left cheek, brow and nose bridge.
// 18 wide x 30 tall. Slit eyes (k), long straight nose, thin mouth.
sprite("mask", { outline: "k" }, `
  ....xyyyyyyyxx....
  ..xyyzzzzyyyyxxx..
  .xyzzzvzzyyyyyxxx.
  .xyzzvvzzyyyyyxxx.
  xyzzzzzzzyyyyyxxxx
  xyzvzzzzzyyyyyxxxx
  xyzzkkkzzyyxkkkxxx
  xyzzxkkzyyyxkkkxxx
  xyzzzzzzyyyyyyxxxx
  xyzzzzvzyyyxxxxxxx
  xyzzzzvzyyyxxxxxxx
  xyzzzzvyyxxxxxxxxx
  xyzzzzvyyxxxxxxxxx
  .yzzzzvyyxxxxxxxx.
  .yzzzzvyxxxxxxxxx.
  .yzzzzzyyxxxxxxxx.
  .xyzzzzyxxxxxxxxx.
  .xyzzzyyyxxxxxxx..
  ..xyzzzyyyxxxxxx..
  ..xyzzyyyyxxxxx...
  ..xyzzyyyyxxxxx...
  ...xyyyyyyxxxx....
  ...xyyyyyyxxxx....
  ....xyyyyxxx......
  ....xxyyyxxx......
  .....xxxxxx.......
`)
// Kerchief: brown, wrapped over the head, falling past the mask on both sides, knotted under the chin.
// Drawn as one silhouette, then tone steps along the leather ramp and a few folds.
sprite("hood", { w: 36, h: 46, outline: "k" },
  poly([8, 4, 14, 1, 24, 1, 31, 5, 34, 14, 34, 28, 32, 36, 28, 41, 20, 43, 10, 41, 5, 34, 3, 22, 4, 12], "n"),
  // lit on the left (the fire), dark on the right
  light([0, 0, 14, 46], 1, 1),
  shade([22, 0, 14, 46], 1, 1),
  shade([27, 0, 9, 46], 1, 1),
  // top of the head catches the light
  light([10, 1, 14, 6], 1, 1),
  // folds: strokes of the darker leather running from the crown down past the mask
  line(10, 5, 5, 26, "m"), line(13, 4, 8, 30, "m"), line(28, 6, 32, 28, "l"), line(25, 4, 30, 26, "l"),
  line(6, 30, 12, 40, "m"), line(32, 30, 27, 40, "l"))
// the knot and the two ends falling from it, under the chin
sprite("knot", { outline: "k" }, `
  .mnnnm.
  mnooonm
  mnonnnm
  .mnnnm.
  mnn.mnm
  mnn.mnn
  mn...nn
  m.....n`)
scene("head", { w: 40, h: 56 },
  layer("hood", stamp("hood", 2, 0)),
  layer("mask", stamp("mask", 11, 8)),
  layer("knot", stamp("knot", 16, 38)))
