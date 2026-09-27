class_name BellSets
extends RefCounted
## The three bell loads (docs/design.md section 3): heavier sets score more and judge tighter.

const IDS: Array[String] = ["light", "village", "full"]
const WEIGHTS := {"light": 1.0, "village": 1.2, "full": 1.5}
const SCALES := {"light": 1.0, "village": 0.9, "full": 0.8}
const NAMES := {
	"light": {"en": "Light", "it": "Leggero"},
	"village": {"en": "Village", "it": "Paese"},
	"full": {"en": "Full load", "it": "Carico pieno"},
}


static func ids() -> Array[String]:
	return IDS.duplicate()


static func is_valid(id: String) -> bool:
	return WEIGHTS.has(id)


static func weight(id: String) -> float:
	return WEIGHTS.get(id, 1.0)


static func window_scale(id: String) -> float:
	return SCALES.get(id, 1.0)


static func name(id: String, lang := "en") -> String:
	var n: Dictionary = NAMES.get(id, {})
	return str(n.get(lang, n.get("en", id)))
