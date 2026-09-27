class_name MaskSpec
extends RefCounted
## The carvable Mamuthone mask: its parts, the options for each part and the order they unlock in.
##
## A spec is a Dictionary {part: option} with one entry per part in PARTS, for example
## {"brow": "heavy", "eyes": "round", ...}. The first option of each part is the default and is always
## available. Every option stays within real Mamoiada forms: a dark carved wooden face with a heavy
## brow, deep eye holes, a large (often hooked) nose, pronounced cheeks and a neutral or grim mouth.
## There are no joke, bright or cartoon options, and none may be added.
##
## Unlocks (used by Core's Progression.mask_option_unlocked): requirement(part, option) returns
## {stop, cost}: the option is available once story stop `stop` is reached and the player's carving
## points (total bells earned) are at least `cost`. Finer details come later in the story.

const PARTS: Array[String] = ["brow", "eyes", "nose", "cheeks", "mouth", "finish", "patina"]

## Options per part, in unlock order. Ids are stable (they are saved in the profile).
const OPTIONS := {
	"brow": ["heavy", "furrowed", "knotted", "lined"],
	"eyes": ["round", "almond", "drooping", "narrow"],
	"nose": ["hooked", "long", "broad", "aquiline"],
	"cheeks": ["full", "high", "hollow", "creased"],
	"mouth": ["closed", "downturned", "open", "grimace"],
	"finish": ["soot_black", "smoked", "dark_walnut", "charred"],
	"patina": ["fresh", "worn", "old", "ancient"],
}

## Requirement for each option: [stop, cost]. The first option of every part is free.
const REQUIREMENTS := {
	"brow": [[1, 0], [2, 2], [4, 9], [6, 20]],
	"eyes": [[1, 0], [2, 3], [3, 6], [5, 15]],
	"nose": [[1, 0], [2, 1], [3, 7], [5, 13]],
	"cheeks": [[1, 0], [3, 4], [4, 10], [6, 22]],
	"mouth": [[1, 0], [2, 2], [4, 11], [7, 26]],
	"finish": [[1, 0], [3, 5], [5, 14], [7, 30]],
	"patina": [[1, 0], [4, 8], [6, 18], [7, 34]],
}

## Player-facing names (plain words, no local terms until checked with the community).
const NAMES := {
	"brow": {"en": "Brow", "it": "Fronte"},
	"eyes": {"en": "Eyes", "it": "Occhi"},
	"nose": {"en": "Nose", "it": "Naso"},
	"cheeks": {"en": "Cheeks", "it": "Guance"},
	"mouth": {"en": "Mouth", "it": "Bocca"},
	"finish": {"en": "Finish", "it": "Finitura"},
	"patina": {"en": "Patina", "it": "Patina"},
	"heavy": {"en": "Heavy", "it": "Pesante"},
	"furrowed": {"en": "Furrowed", "it": "Aggrottata"},
	"knotted": {"en": "Knotted", "it": "Nodosa"},
	"lined": {"en": "Lined", "it": "Rugosa"},
	"round": {"en": "Round", "it": "Rotondi"},
	"almond": {"en": "Almond", "it": "A mandorla"},
	"drooping": {"en": "Drooping", "it": "Cadenti"},
	"narrow": {"en": "Narrow", "it": "Stretti"},
	"hooked": {"en": "Hooked", "it": "Adunco"},
	"long": {"en": "Long", "it": "Lungo"},
	"broad": {"en": "Broad", "it": "Largo"},
	"aquiline": {"en": "Aquiline", "it": "Aquilino"},
	"full": {"en": "Full", "it": "Piene"},
	"high": {"en": "High", "it": "Alte"},
	"hollow": {"en": "Hollow", "it": "Scavate"},
	"creased": {"en": "Creased", "it": "Segnate"},
	"closed": {"en": "Closed", "it": "Chiusa"},
	"downturned": {"en": "Downturned", "it": "All'ingiù"},
	"open": {"en": "Open", "it": "Aperta"},
	"grimace": {"en": "Grimace", "it": "Smorfia"},
	"soot_black": {"en": "Soot black", "it": "Nero fumo"},
	"smoked": {"en": "Smoked", "it": "Affumicata"},
	"dark_walnut": {"en": "Dark walnut", "it": "Noce scuro"},
	"charred": {"en": "Charred", "it": "Bruciata"},
	"fresh": {"en": "Fresh", "it": "Nuova"},
	"worn": {"en": "Worn", "it": "Consumata"},
	"old": {"en": "Old", "it": "Vecchia"},
	"ancient": {"en": "Ancient", "it": "Antica"},
}

const FLEECES: Array[String] = ["black", "dark_brown"]
const STRAPS: Array[String] = ["natural", "dark"]


static func default() -> Dictionary:
	var spec := {}
	for part in PARTS:
		spec[part] = OPTIONS[part][0]
	return spec


static func options(part: String) -> Array:
	return OPTIONS.get(part, []).duplicate()


static func requirement(part: String, option: String) -> Dictionary:
	var opts: Array = OPTIONS.get(part, [])
	var i := opts.find(option)
	if i < 0:
		return {"stop": 99, "cost": 9999}
	var r: Array = REQUIREMENTS[part][i]
	return {"stop": int(r[0]), "cost": int(r[1])}


## Every non-default option as {part, option, stop, cost}, sorted by stop then cost.
static func unlock_order() -> Array:
	var out := []
	for part in PARTS:
		var opts: Array = OPTIONS[part]
		for i in range(1, opts.size()):
			var r := requirement(part, opts[i])
			out.append({"part": part, "option": opts[i], "stop": r.stop, "cost": r.cost})
	out.sort_custom(func(a, b): return a.stop < b.stop or (a.stop == b.stop and a.cost < b.cost))
	return out


## Problems with a spec, as readable strings (empty when the spec is valid).
static func errors(spec) -> Array[String]:
	var out: Array[String] = []
	if not (spec is Dictionary):
		out.append("spec is not a Dictionary")
		return out
	for part in PARTS:
		if not spec.has(part):
			out.append("missing part '%s'" % part)
		elif not (spec[part] is String) or not (spec[part] in OPTIONS[part]):
			out.append("unknown %s option '%s'" % [part, spec[part]])
	for key in spec.keys():
		if not (key in PARTS):
			out.append("unknown part '%s'" % key)
	return out


static func validate(spec) -> bool:
	return errors(spec).is_empty()


## A valid copy of `spec`: unknown parts dropped, missing or bad values replaced by defaults.
static func sanitize(spec) -> Dictionary:
	var out := default()
	if spec is Dictionary:
		for part in PARTS:
			if spec.has(part) and spec[part] is String and spec[part] in OPTIONS[part]:
				out[part] = spec[part]
	return out


static func name_of(id: String, lang := "en") -> String:
	var n: Dictionary = NAMES.get(id, {})
	return n.get(lang, n.get("en", id))
