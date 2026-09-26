class_name Palette
extends RefCounted
## The woodcut colours: black, bone, red, with ember for fire and calls.

const BLACK := Color("141110")
const BONE := Color("ede6da")
const RED := Color("c0392b")
const EMBER := Color("e0a24a")
const ASH := Color("a89c8c")
const WOOD := Color("2e2620")
const GOOD := Color("9fd08a")


static func tone_color(tone: String) -> Color:
	match tone:
		"perfect", "held":
			return GOOD
		"good":
			return BONE
		"wrong", "let_go":
			return EMBER
		"silence":
			return RED
	return ASH
