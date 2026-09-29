class_name MaskPixels
extends RefCounted
## The carved Mamuthone mask as pixel art, built from a MaskSpec at any size (docs/art-style.md).
##
## The mask is carved, so it is drawn as carved wood: every part option adds raised or cut forms to a
## height field over the face (a brow ridge, a hooked nose, cheekbones, grooves), the eye and mouth
## holes are cut right through, and the fire lights the result from the upper right. The light is
## quantised to the finish's five-step palette ramp with an ordered dither only where two steps meet,
## then the finish adds its grain (walnut, smoked) or crackle (charred), the patina adds wear, scratches,
## chips and cracks, and a K0 outline closes it. Around it: the black kerchief tied over the head and
## the leather strap at the temples.
##
##   MaskPixels.texture(spec, unit, kerchief, straps, highlight) -> ImageTexture   (cached)
##   unit: art pixels per mask unit (the face is 2 units wide); the image spans
##   [-HALF_W, HALF_W] x [TOP, BOTTOM] mask units, so the centre of the image is the mask's (0, MID).
## Only palette colours are written (PixelPalette).

const HALF_W := 1.42
const TOP := -1.82
const BOTTOM := 2.05
const MID := (TOP + BOTTOM) * 0.5

## Five-step wood ramps per finish, shadow to firelit edge (all very dark: the mask stays black).
const FINISH_RAMP := {
	"soot_black": ["K1", "WOOD0", "WOOD1", "WOOD2", "WOOD3"],
	"smoked": ["K1", "WOOD1", "WOOD2", "WOOD3", "BONE0"],
	"dark_walnut": ["WOOD0", "FLEECE2", "FLEECE3", "LEATHER1", "LEATHER2"],
	"charred": ["K0", "K1", "WOOD0", "SETT2", "SETT4"],
}

const PART_ID := {"brow": 1, "eyes": 2, "nose": 3, "cheeks": 4, "mouth": 5}

static var _cache := {}
static var _order: Array = []


const _RAMPS := {"K": PixelPalette.K, "WOOD": PixelPalette.WOOD, "FLEECE": PixelPalette.FLEECE, "LEATHER": PixelPalette.LEATHER,
	"BONE": PixelPalette.BONE, "SETT": PixelPalette.SETT, "FIRE": PixelPalette.FIRE, "GOLD": PixelPalette.GOLD, "NAVY": PixelPalette.NAVY}


## A palette colour by name ("WOOD2").
static func col(name: String) -> Color:
	var ramp := name.rstrip("0123456789")
	var i := int(name.substr(ramp.length()))
	return (_RAMPS[ramp] as Array)[i]


## The face's half width at height v (mask units): a long face, widest at the cheekbones, narrowing
## to the chin.
static func half_width(v: float, cheeks := "full") -> float:
	var pts := [[-1.34, 0.0], [-1.28, 0.5], [-1.12, 0.78], [-0.85, 0.9], [-0.3, 0.96], [0.1, 1.0], [0.5, 0.94], [0.9, 0.8], [1.3, 0.6], [1.6, 0.45], [1.8, 0.3], [1.9, 0.0]]
	if v <= pts[0][0] or v >= pts[-1][0]:
		return 0.0
	var w := 0.0
	for i in pts.size() - 1:
		if v <= pts[i + 1][0]:
			var t: float = (v - pts[i][0]) / (pts[i + 1][0] - pts[i][0])
			var a: float = pts[i][1]
			var b: float = pts[i + 1][1]
			if i == 0:
				w = b * sqrt(t)  # the rounded crown
			elif i == pts.size() - 2:
				w = a * sqrt(1.0 - t)
			else:
				w = lerpf(a, b, smoothstep(0.0, 1.0, t))
			break
	if cheeks == "hollow" and v > 0.25 and v < 1.1:
		w -= 0.07 * sin((v - 0.25) / 0.85 * PI)
	return w


## The carved forms of each option: raised bumps ["b", u, v, ru, rv, amp], ridges and grooves
## ["c", u0, v0, u1, v1, r, amp] (negative amp cuts in), holes cut through ["he", u, v, ru, rv]
## (ellipse), ["ha", u, v, half_w, half_h, droop] (almond, pointed at the corners) and
## ["hl", [points], thickness] (a slit along a line).
static func forms(part: String, option: String) -> Array:
	match part:
		"brow":
			match option:
				"furrowed":
					return [["c", -0.82, -0.74, -0.1, -0.54, 0.17, 0.34], ["c", 0.82, -0.74, 0.1, -0.54, 0.17, 0.34],
						["c", -0.07, -1.0, -0.05, -0.62, 0.05, -0.14], ["c", 0.07, -1.0, 0.05, -0.62, 0.05, -0.14]]
				"knotted":
					return [["b", -0.43, -0.66, 0.3, 0.18, 0.4], ["b", 0.43, -0.66, 0.3, 0.18, 0.4], ["b", 0.0, -0.74, 0.15, 0.13, 0.28],
						["c", -0.75, -0.62, 0.75, -0.62, 0.1, 0.12]]
				"lined":
					return [["c", -0.8, -0.6, 0.8, -0.6, 0.12, 0.24], ["c", -0.6, -0.84, 0.6, -0.84, 0.04, -0.12],
						["c", -0.5, -0.99, 0.5, -0.99, 0.04, -0.12], ["c", -0.36, -1.12, 0.36, -1.12, 0.035, -0.1]]
				_:  # heavy
					return [["c", -0.8, -0.63, 0.8, -0.63, 0.21, 0.36], ["b", 0.0, -0.66, 0.24, 0.16, 0.12]]
		"eyes":
			var sock := [["b", -0.42, -0.34, 0.32, 0.24, -0.14], ["b", 0.42, -0.34, 0.32, 0.24, -0.14]]
			match option:
				"almond":
					return sock + [["ha", -0.42, -0.34, 0.3, 0.085, 0.0], ["ha", 0.42, -0.34, 0.3, 0.085, 0.0]]
				"drooping":
					return sock + [["ha", -0.42, -0.31, 0.25, 0.09, 0.24], ["ha", 0.42, -0.31, 0.25, 0.09, 0.24],
						["c", -0.66, -0.34, -0.24, -0.48, 0.07, 0.14], ["c", 0.66, -0.34, 0.24, -0.48, 0.07, 0.14]]
				"narrow":
					return sock + [["ha", -0.42, -0.33, 0.25, 0.03, 0.0], ["ha", 0.42, -0.33, 0.25, 0.03, 0.0],
						["c", -0.64, -0.43, -0.22, -0.43, 0.07, 0.14], ["c", 0.22, -0.43, 0.64, -0.43, 0.07, 0.14],
						["c", -0.6, -0.24, -0.26, -0.24, 0.06, 0.1], ["c", 0.26, -0.24, 0.6, -0.24, 0.06, 0.1]]
				_:  # round
					return sock + [["he", -0.42, -0.34, 0.2, 0.2], ["he", 0.42, -0.34, 0.2, 0.2]]
		"nose":
			match option:
				"long":
					# thin and straight, reaching almost to the mouth
					return [["c", 0.0, -0.5, 0.0, 0.9, 0.1, 0.5], ["b", 0.0, 0.92, 0.11, 0.08, 0.2],
						["he", -0.08, 0.95, 0.04, 0.03], ["he", 0.08, 0.95, 0.04, 0.03]]
				"broad":
					# short and wide, heavy nostril wings
					return [["c", 0.0, -0.4, 0.0, 0.4, 0.24, 0.42], ["b", -0.26, 0.48, 0.17, 0.14, 0.34], ["b", 0.26, 0.48, 0.17, 0.14, 0.34],
						["b", 0.0, 0.5, 0.17, 0.13, 0.22], ["he", -0.19, 0.6, 0.09, 0.05], ["he", 0.19, 0.6, 0.09, 0.05]]
				"aquiline":
					# a hump high on the bridge, a sharp straight tip
					return [["c", 0.0, -0.5, 0.0, 0.62, 0.12, 0.36], ["b", 0.02, -0.08, 0.15, 0.24, 0.34], ["b", 0.02, 0.64, 0.09, 0.09, 0.28],
						["he", -0.09, 0.68, 0.045, 0.035], ["he", 0.1, 0.68, 0.045, 0.035]]
				_:  # hooked
					# a big beak bending down over the nostrils
					return [["c", 0.0, -0.5, 0.05, 0.5, 0.15, 0.46], ["b", 0.06, 0.62, 0.19, 0.2, 0.44], ["c", 0.04, 0.72, 0.0, 0.86, 0.08, 0.26],
						["he", -0.17, 0.72, 0.055, 0.04], ["he", 0.22, 0.72, 0.05, 0.04]]
		"cheeks":
			match option:
				"high":
					return [["c", -0.8, 0.02, -0.4, 0.1, 0.12, 0.34], ["c", 0.8, 0.02, 0.4, 0.1, 0.12, 0.34],
						["b", -0.56, 0.4, 0.22, 0.2, -0.14], ["b", 0.56, 0.4, 0.22, 0.2, -0.14]]
				"hollow":
					return [["b", -0.62, 0.0, 0.26, 0.12, 0.22], ["b", 0.62, 0.0, 0.26, 0.12, 0.22],
						["b", -0.55, 0.5, 0.24, 0.3, -0.32], ["b", 0.55, 0.5, 0.24, 0.3, -0.32]]
				"creased":
					return [["b", -0.56, 0.24, 0.3, 0.26, 0.22], ["b", 0.56, 0.24, 0.3, 0.26, 0.22],
						["c", -0.24, 0.58, -0.44, 1.22, 0.05, -0.22], ["c", 0.24, 0.58, 0.44, 1.22, 0.05, -0.22]]
				_:  # full
					return [["b", -0.56, 0.28, 0.34, 0.3, 0.3], ["b", 0.56, 0.28, 0.34, 0.3, 0.3]]
		"mouth":
			var chin := [["bx", 0.0, 1.56, 0.26, 0.18, 0.2]]
			match option:
				"downturned":
					return chin + [["c", -0.3, 1.0, 0.3, 1.0, 0.08, 0.12], ["hl", [Vector2(-0.38, 1.34), Vector2(-0.2, 1.14), Vector2(0.2, 1.14), Vector2(0.38, 1.34)], 0.04]]
				"open":
					return chin + [["b", 0.0, 1.15, 0.34, 0.2, 0.18], ["he", 0.0, 1.15, 0.22, 0.12]]
				"grimace":
					return chin + [["c", -0.44, 1.04, 0.44, 1.04, 0.07, 0.14], ["c", -0.44, 1.27, 0.44, 1.27, 0.07, 0.14],
						["hr", 0.0, 1.155, 0.42, 0.07], ["c", -0.5, 0.9, -0.54, 1.34, 0.045, -0.18], ["c", 0.5, 0.9, 0.54, 1.34, 0.045, -0.18]]
				_:  # closed
					return chin + [["c", -0.34, 1.06, 0.34, 1.06, 0.08, 0.1], ["c", -0.28, 1.21, 0.28, 1.21, 0.07, 0.1],
						["hl", [Vector2(-0.36, 1.135), Vector2(0.36, 1.135)], 0.028]]
	return []


## The mask as a texture, `unit` art pixels to the mask unit. Cached (the last 48 looks).
static func texture(spec: Dictionary, unit: float, kerchief := true, straps := "natural", highlight := "") -> ImageTexture:
	var m := MaskSpec.sanitize(spec)
	var key := "%s|%.2f|%s|%s|%s" % [str(m), unit, kerchief, straps, highlight]
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(render(m, unit, kerchief, straps, highlight))
	_cache[key] = tex
	_order.append(key)
	if _order.size() > 48:
		_cache.erase(_order.pop_front())
	return tex


static func size_for(unit: float) -> Vector2i:
	return Vector2i(maxi(4, int(round(HALF_W * 2.0 * unit))), maxi(4, int(round((BOTTOM - TOP) * unit))))


static func render(spec: Dictionary, unit: float, kerchief := true, straps := "natural", highlight := "") -> Image:
	var m := MaskSpec.sanitize(spec)
	var sz := size_for(unit)
	var W := sz.x
	var H := sz.y
	var n := W * H
	var fine := unit >= 9.0
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hgt := PackedFloat32Array()
	hgt.resize(n)
	var face := PackedByteArray()
	face.resize(n)
	var hole := PackedByteArray()
	hole.resize(n)
	var part := PackedByteArray()
	part.resize(n)
	var groove := PackedByteArray()
	groove.resize(n)
	var hw_row := PackedFloat32Array()
	hw_row.resize(H)
	for y in H:
		hw_row[y] = half_width(_v(y, unit), m.cheeks)
	# The face: a rounded dome, a little fuller down the middle.
	for y in H:
		var v := _v(y, unit)
		var hw := hw_row[y]
		for x in W:
			var u := _u(x, unit)
			if hw > 0.0 and absf(u) < hw:
				var i := y * W + x
				face[i] = 1
				var q := u / hw
				hgt[i] = 0.55 * sqrt(maxf(0.0, 1.0 - q * q)) + 0.12 * (1.0 - clampf(absf(v - 0.2) / 1.7, 0.0, 1.0))
	# The carved forms, part by part.
	for p in ["cheeks", "brow", "eyes", "nose", "mouth"]:
		var pid: int = PART_ID[p]
		for f in forms(p, m[p]):
			_apply(f, pid, unit, W, H, hgt, face, hole, part, groove)
	# Light: the fire from the upper right, quantised to five steps with a narrow ordered dither.
	var ramp: Array = FINISH_RAMP.get(m.finish, FINISH_RAMP.soot_black)
	var cols: Array[Color] = []
	for r in ramp:
		cols.append(col(r))
	var L := Vector3(0.62, -0.5, 0.6).normalized()
	var level := PackedByteArray()
	level.resize(n)
	var k := 1.5 * unit
	for y in H:
		for x in W:
			var i := y * W + x
			if face[i] == 0 or hole[i] == 1:
				continue
			var hl := hgt[i - 1] if x > 0 and face[i - 1] == 1 else hgt[i] - 0.25
			var hr := hgt[i + 1] if x < W - 1 and face[i + 1] == 1 else hgt[i] - 0.25
			var hu := hgt[i - W] if y > 0 and face[i - W] == 1 else hgt[i] - 0.25
			var hd := hgt[i + W] if y < H - 1 and face[i + W] == 1 else hgt[i] - 0.25
			var nrm := Vector3(-(hr - hl) * k * 0.5, -(hd - hu) * k * 0.5, 1.0).normalized()
			var s := nrm.dot(L) - L.z
			var t := 2.0 + s * 4.2 + _u(x, unit) * 0.7
			var d := (_bayer(x, y) - 0.5) * 0.36
			# The wood itself never falls to the darkest step: that is kept for cuts and grooves, so a
			# shadowed bump never reads as a hole.
			var lo := 0 if groove[i] == 1 else 1
			level[i] = clampi(int(floor(t + d + 0.5)), lo, 4)
	# Cast shadows: march from each pixel towards the fire (up and right); a higher form on the way
	# shades it, so the nose, the brow and the cheekbones throw their shadows down and to the left.
	var rise := 0.8 / unit  # height gained per pixel of the march (the fire is about 40 degrees up)
	var reach := int(ceil(0.7 * unit))
	for y in H:
		for x in W:
			var i := y * W + x
			if face[i] == 0 or hole[i] == 1:
				continue
			var h0 := hgt[i]
			for st in range(1, reach):
				var sx := x + st
				var sy := y - int(st * 0.8)
				if sx >= W or sy < 0:
					break
				var j := sy * W + sx
				if face[j] == 0:
					break
				if hgt[j] > h0 + rise * float(st) * 1.25 + 0.02:
					level[i] = maxi(0, level[i] - 2)
					break
	# Crests catch the fire: a pixel standing above its left and right (or upper and lower)
	# neighbours on the lit half of a form gets the brightest step.
	if fine:
		var crest := PackedByteArray()
		crest.resize(n)
		for y in range(1, H - 1):
			for x in range(1, W - 1):
				var i := y * W + x
				if face[i] == 0 or hole[i] == 1 or level[i] < 2:
					continue
				var hx := hgt[i] - 0.5 * (hgt[i - 1] + hgt[i + 1])
				var hy := hgt[i] - 0.5 * (hgt[i - W] + hgt[i + W])
				if maxf(hx, hy) > 0.0035 * (22.0 / unit) * 22.0 / unit:
					crest[i] = 1
		for i in n:
			if crest[i] == 1:
				level[i] = mini(4, level[i] + 1)
	# The holes' rims: dark under the upper lip of each cut, lit on the lower lip (the fire is above).
	for y in range(1, H - 1):
		for x in W:
			var i := y * W + x
			if face[i] == 0 or hole[i] == 1:
				continue
			if hole[i + W] == 1:
				level[i] = maxi(0, level[i] - 2)
			elif hole[i - W] == 1:
				level[i] = mini(4, level[i] + 1)
	if fine:
		_finish(m.finish, level, face, hole, W, H)
		_patina(m.patina, level, face, hole, W, H, unit)
	# Paint.
	for y in H:
		for x in W:
			var i := y * W + x
			if face[i] == 0:
				continue
			img.set_pixel(x, y, PixelPalette.K[0] if hole[i] == 1 else cols[level[i]])
	# Dust settled in the cuts of an ancient mask.
	if fine and m.patina == "ancient":
		for y in range(1, H):
			for x in W:
				var i := y * W + x
				if hole[i] == 1 and hole[i - W] == 0 and face[i - W] == 1 and (x * 7 + y) % 3 == 0:
					img.set_pixel(x, y, col("BONE0"))
	if kerchief:
		_kerchief(img, face, W, H, unit, straps)
	_outline(img, W, H)
	if highlight != "" and PART_ID.has(highlight):
		_ring(img, part, face, int(PART_ID[highlight]), W, H)
	return img


static func _u(x: int, unit: float) -> float:
	return (float(x) + 0.5) / unit - HALF_W


static func _v(y: int, unit: float) -> float:
	return (float(y) + 0.5) / unit + TOP


static func _bayer(x: int, y: int) -> float:
	const B := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return (float(B[(y % 4) * 4 + (x % 4)]) + 0.5) / 16.0


static func _apply(f: Array, pid: int, unit: float, W: int, H: int, hgt: PackedFloat32Array, face: PackedByteArray, hole: PackedByteArray, part: PackedByteArray, groove: PackedByteArray) -> void:
	var kind: String = f[0]
	var box := Rect2()
	match kind:
		"hr":
			box = Rect2(f[1] - f[3], f[2] - f[4], f[3] * 2.0, f[4] * 2.0)
		"b", "bx", "he", "ha":
			var ru: float = f[3]
			var rv: float = f[4] + (absf(f[5]) if kind == "ha" else 0.0)
			box = Rect2(f[1] - ru, f[2] - rv, ru * 2.0, rv * 2.0)
		"c":
			var r: float = f[5]
			box = Rect2(minf(f[1], f[3]) - r, minf(f[2], f[4]) - r, absf(f[3] - f[1]) + r * 2.0, absf(f[4] - f[2]) + r * 2.0)
		"hl":
			var pts: Array = f[1]
			box = Rect2(pts[0], Vector2.ZERO)
			for p in pts:
				box = box.expand(p)
			box = box.grow(float(f[2]) + 1.0 / unit)
	var x0 := clampi(int(floor((box.position.x + HALF_W) * unit)) - 1, 0, W - 1)
	var x1 := clampi(int(ceil((box.end.x + HALF_W) * unit)) + 1, 0, W - 1)
	var y0 := clampi(int(floor((box.position.y - TOP) * unit)) - 1, 0, H - 1)
	var y1 := clampi(int(ceil((box.end.y - TOP) * unit)) + 1, 0, H - 1)
	for y in range(y0, y1 + 1):
		var v := _v(y, unit)
		for x in range(x0, x1 + 1):
			var i := y * W + x
			if face[i] == 0:
				continue
			var u := _u(x, unit)
			match kind:
				"b", "bx":
					var q := 1.0 - pow((u - f[1]) / f[3], 2) - pow((v - f[2]) / f[4], 2)
					if q > 0.0:
						hgt[i] += float(f[5]) * pow(q, 1.5)
						if q > 0.15 and f[5] > 0.0 and kind == "b":
							part[i] = pid
				"c":
					var a := Vector2(f[1], f[2])
					var b := Vector2(f[3], f[4])
					var d := Geometry2D.get_closest_point_to_segment(Vector2(u, v), a, b).distance_to(Vector2(u, v))
					var q := 1.0 - pow(d / float(f[5]), 2)
					if q > 0.0:
						hgt[i] += float(f[6]) * pow(q, 1.5)
						if q > 0.2:
							part[i] = pid
						if f[6] < 0.0 and q > 0.45:
							groove[i] = 1
				"hr":
					if absf(u - f[1]) < f[3] and absf(v - f[2]) < maxf(f[4], 0.5 / unit):
						# teeth: every third column of the cut is left as wood, short of the lips
						var col_i := int(floor((u - f[1] + f[3]) * unit))
						var tooth: bool = posmod(col_i, 3) == 1 and absf(v - f[2]) < f[4] * 0.7 and absf(u - f[1]) < f[3] * 0.8
						if not tooth:
							hole[i] = 1
						part[i] = pid
				"he":
					if pow((u - f[1]) / f[3], 2) + pow((v - f[2]) / f[4], 2) < 1.0:
						hole[i] = 1
						part[i] = pid
				"ha":
					# almond: pointed at both corners; droop lowers the outer corner (away from the nose)
					var t := (u - float(f[1])) / float(f[3])
					if absf(t) < 1.0:
						var outer := t * signf(float(f[1]))
						var cy := float(f[2]) + absf(float(f[5])) * maxf(0.0, outer)
						var half := float(f[4]) * pow(1.0 - t * t, 0.7)
						if absf(v - cy) < maxf(half, 0.5 / unit):
							hole[i] = 1
							part[i] = pid
				"hl":
					var pts: Array = f[1]
					var best := 99.0
					for j in pts.size() - 1:
						best = minf(best, Geometry2D.get_closest_point_to_segment(Vector2(u, v), pts[j], pts[j + 1]).distance_to(Vector2(u, v)))
					if best < maxf(float(f[2]), 0.55 / unit):
						hole[i] = 1
						part[i] = pid


## The finish's surface: walnut and smoked wood show a wavy vertical grain, charred wood a crackle.
static func _finish(finish: String, level: PackedByteArray, face: PackedByteArray, hole: PackedByteArray, W: int, H: int) -> void:
	for y in H:
		for x in W:
			var i := y * W + x
			if face[i] == 0 or hole[i] == 1:
				continue
			match finish:
				"dark_walnut", "smoked":
					var wave := int(round(1.6 * sin(float(y) * 0.23 + float(x) * 0.9)))
					var every := 4 if finish == "dark_walnut" else 6
					if posmod(x + wave, every) == 0 and level[i] >= 1 and level[i] <= 3 and (y / 3) % 4 != 0:
						level[i] -= 1
				"charred":
					# alligator crackle: the edges between irregular cells, cut into the lit wood
					if level[i] >= 2 and _crackle(x, y):
						level[i] = 1 if level[i] >= 3 else 0


## True on the cracks of an irregular cell pattern (cells about 6 x 5 px with jittered centres).
static func _crackle(x: int, y: int) -> bool:
	var cx := x / 6
	var cy := y / 5
	var d1 := 99.0
	var d2 := 99.0
	for j in range(-1, 2):
		for i in range(-1, 2):
			var gx := cx + i
			var gy := cy + j
			var h := (gx * 73856093) ^ (gy * 19349663)
			var px := float(gx * 6) + float(posmod(h, 6))
			var py := float(gy * 5) + float(posmod(h / 7, 5))
			var d := Vector2(float(x) - px, float(y) - py).length()
			if d < d1:
				d2 = d1
				d1 = d
			elif d < d2:
				d2 = d
	return d2 - d1 < 0.9


## Age: worn polishes the high points; old dulls the edge, scratches and chips it; ancient cracks it.
static func _patina(patina: String, level: PackedByteArray, face: PackedByteArray, hole: PackedByteArray, W: int, H: int, unit: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	match patina:
		"worn":
			for i in level.size():
				if face[i] == 1 and hole[i] == 0 and level[i] == 3 and (i % W + i / W) % 2 == 0:
					level[i] = 4
		"old", "ancient":
			for i in level.size():
				if face[i] == 1 and hole[i] == 0 and level[i] == 4 and (patina == "ancient" or (i % W) % 3 != 0):
					level[i] = 3
			# scratches: short diagonal gouges across the lit wood
			var count := int(round(unit * (0.35 if patina == "old" else 0.5)))
			for s in count:
				var x := rng.randi_range(2, W - 3)
				var y := rng.randi_range(int(H * 0.15), int(H * 0.8))
				var dx := 1 if rng.randf() < 0.5 else -1
				for j in rng.randi_range(2, 4):
					var xi := x + j * dx
					var yi := y + j
					if xi >= 0 and xi < W and yi < H:
						var i := yi * W + xi
						if face[i] == 1 and hole[i] == 0:
							level[i] = maxi(0, level[i] - 2)
			# chips out of the rim
			var chips := 3 if patina == "old" else 6
			for c in chips:
				var y := rng.randi_range(int(H * 0.12), int(H * 0.85))
				var row := PackedInt32Array()
				for x in W:
					if face[y * W + x] == 1:
						row.append(x)
				if row.is_empty():
					continue
				var x0 := row[0] if rng.randf() < 0.5 else row[row.size() - 1]
				var dir := 1 if x0 == row[0] else -1
				for dy in 2:
					for dx in (2 if patina == "ancient" else 1):
						var yy := y + dy
						var xx := x0 + dx * dir
						if yy < H and xx >= 0 and xx < W:
							face[yy * W + xx] = 0
			if patina == "ancient":
				# a long crack down the forehead and a split in the chin
				for seg in [[Vector2(0.28, -1.3), Vector2(0.2, -1.0), Vector2(0.3, -0.78)], [Vector2(-0.1, 1.9), Vector2(-0.06, 1.62)]]:
					for j in seg.size() - 1:
						var a: Vector2 = seg[j]
						var b: Vector2 = seg[j + 1]
						var steps := int(ceil(a.distance_to(b) * unit)) + 1
						for q in steps + 1:
							var p := a.lerp(b, float(q) / float(steps))
							var x := int(floor((p.x + HALF_W) * unit))
							var y := int(floor((p.y - TOP) * unit))
							if x >= 0 and x < W and y >= 0 and y < H:
								var i := y * W + x
								if face[i] == 1:
									hole[i] = 1


## The black kerchief tied over the head round the mask, knotted under the chin, and the leather
## strap that holds the mask, across the cloth at the temples.
static func _kerchief(img: Image, face: PackedByteArray, W: int, H: int, unit: float, straps: String) -> void:
	var shades: Array[Color] = [col("K0"), col("K1"), col("FLEECE1"), col("FLEECE2"), col("FLEECE3")]
	var strap_a := col("LEATHER2") if straps != "dark" else col("K1")
	var strap_b := col("LEATHER3") if straps != "dark" else col("LEATHER1")
	var pad := 0.32
	var crown_w := half_width(-0.95) + pad
	var kv := BOTTOM - 0.16
	for y in H:
		var v := _v(y, unit)
		var hw := 0.0
		if v < -1.1:
			var t := clampf((v - (TOP + 0.04)) / (-1.1 - (TOP + 0.04)), 0.0, 1.0)
			hw = crown_w * sqrt(1.0 - (1.0 - t) * (1.0 - t))
		elif v < 1.55:
			hw = half_width(v) + pad
		else:
			hw = lerpf(half_width(1.55) + pad, 0.12, clampf((v - 1.55) / (kv - 1.55), 0.0, 1.0))
		for x in W:
			var i := y * W + x
			if face[i] == 1:
				continue
			var u := _u(x, unit)
			var knot := pow(u / 0.24, 2) + pow((v - kv) / 0.13, 2) < 1.0
			if absf(u) >= hw and not knot:
				continue
			var q := u / maxf(hw, 0.01)
			var lvl := 1
			if q > 0.35:
				lvl = 2
			if q > 0.62:
				lvl = 3
			if q > 0.84:
				lvl = 4
			if q < -0.5:
				lvl = 0
			if v < -1.2 and u > -0.2 and q < 0.84:
				lvl = maxi(lvl, 2 if u < 0.4 else 3)  # the crown catches the light
			# folds: soft diagonal creases in the cloth
			var f := sin(u * 6.5 - v * 3.2)
			if f > 0.8 and lvl > 0:
				lvl -= 1
			elif f < -0.93 and lvl < 4 and q > 0.0:
				lvl += 1
			if knot:
				lvl = 3 if u > 0.05 else (1 if u < -0.08 else 2)
			img.set_pixel(x, y, shades[lvl])
	# a K0 seam where the cloth meets the mask's edge
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var i := y * W + x
			if face[i] == 0 and img.get_pixel(x, y).a > 0.0 and (face[i - 1] == 1 or face[i + 1] == 1 or face[i - W] == 1 or face[i + W] == 1):
				img.set_pixel(x, y, col("K0"))
	# the strap: across the kerchief at the temples, from the face's edge to the cloth's
	var y0 := int(floor((-0.44 - TOP) * unit))
	var th := maxi(1, int(round(unit * 0.08)))
	for y in range(y0 - 1, mini(H, y0 + th + 1)):
		for x in W:
			var i := y * W + x
			if face[i] == 1 or img.get_pixel(x, y).a == 0.0:
				continue
			if y == y0 - 1 or y == y0 + th:
				img.set_pixel(x, y, col("K1"))
			else:
				img.set_pixel(x, y, strap_b if y == y0 and _u(x, unit) > 0.0 else strap_a)


static func _outline(img: Image, W: int, H: int) -> void:
	var solid := PackedByteArray()
	solid.resize(W * H)
	for y in H:
		for x in W:
			solid[y * W + x] = 1 if img.get_pixel(x, y).a > 0.0 else 0
	var k0: Color = PixelPalette.K[0]
	for y in H:
		for x in W:
			if solid[y * W + x] == 1:
				continue
			var near := (x > 0 and solid[y * W + x - 1] == 1) or (x < W - 1 and solid[y * W + x + 1] == 1) \
				or (y > 0 and solid[(y - 1) * W + x] == 1) or (y < H - 1 and solid[(y + 1) * W + x] == 1)
			if near:
				img.set_pixel(x, y, k0)
	# the border pixels themselves, where the drawing touches the image edge
	for y in H:
		for x in [0, W - 1]:
			if solid[y * W + x] == 1:
				img.set_pixel(x, y, k0)
	for x in W:
		for y in [0, H - 1]:
			if solid[y * W + x] == 1:
				img.set_pixel(x, y, k0)


## A gold ring round one part's carving (the part being carved in the workshop), drawn a pixel clear
## of it round the part's area so the carving itself stays visible.
static func _ring(img: Image, part: PackedByteArray, face: PackedByteArray, pid: int, W: int, H: int) -> void:
	var region := PackedByteArray()
	region.resize(W * H)
	for i in W * H:
		region[i] = 1 if part[i] == pid else 0
	for pass_n in 2:
		region = _dilate(region, W, H)
	var outer := _dilate(region, W, H)
	var gold := col("GOLD4")
	for y in H:
		for x in W:
			var i := y * W + x
			if outer[i] == 1 and region[i] == 0:
				img.set_pixel(x, y, gold)


static func _dilate(m: PackedByteArray, W: int, H: int) -> PackedByteArray:
	var out := m.duplicate()
	for y in H:
		for x in W:
			var i := y * W + x
			if m[i] == 1:
				continue
			if (x > 0 and m[i - 1] == 1) or (x < W - 1 and m[i + 1] == 1) or (y > 0 and m[i - W] == 1) or (y < H - 1 and m[i + W] == 1):
				out[i] = 1
	return out
