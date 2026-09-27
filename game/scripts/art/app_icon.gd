class_name AppIcon
extends RefCounted
## Sources for the app icon (the Logo on a night-black tile). The PNGs are baked by
## tools/art/bake.sh into game/art/: icon.png (1024), icon_192.png, and the Android adaptive layers
## icon_fg_432.png (transparent, mark inside the 66 % safe zone) and icon_bg_432.png.

const FILES := {
	"icon": "res://art/icon.png",
	"icon_192": "res://art/icon_192.png",
	"foreground": "res://art/icon_fg_432.png",
	"background": "res://art/icon_bg_432.png",
}


## The full icon on a square of side `s`.
static func paint(ci: CanvasItem, s: float) -> void:
	paint_background(ci, s)
	Logo.paint(ci, Vector2(s, s) * 0.5, s * 0.5, s < 200.0)


static func paint_background(ci: CanvasItem, s: float) -> void:
	var sq := PackedVector2Array([Vector2.ZERO, Vector2(s, 0), Vector2(s, s), Vector2(0, s)])
	WoodcutDraw.fill(ci, sq, Palette.BLACK)
	WoodcutDraw.fill(ci, sq, Color(Palette.BONE, 0.05), Palette.tex("grain"), 2.0 / s)
	WoodcutDraw.glow(ci, Vector2(s, s) * 0.5, s * 0.62, Color(Palette.RED_DEEP, 0.5))


## Adaptive foreground: the mark only, kept inside the central safe zone.
static func paint_foreground(ci: CanvasItem, s: float) -> void:
	Logo.paint(ci, Vector2(s, s) * 0.5, s * 0.34, false)
