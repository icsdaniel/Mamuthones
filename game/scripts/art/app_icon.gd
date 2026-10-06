class_name AppIcon
extends RefCounted
## The app icon: the hooded mask of the logo with three bronze bells over a banded fire glow on night
## blue, in pixel art. The PNGs are drawn by tools/art/pixel/logo.py (64 art px, scaled x16 and x3, and
## the Android adaptive layers at 72 art px x6): icon.png (1024), icon_192.png, icon_fg_432.png
## (transparent, the mark inside the safe zone) and icon_bg_432.png. paint() draws those same files,
## so a re-bake through tests/art/bake.gd gives back the same pictures.

const FILES := {
	"icon": "res://art/icon.png",
	"icon_192": "res://art/icon_192.png",
	"foreground": "res://art/icon_fg_432.png",
	"background": "res://art/icon_bg_432.png",
}


static func _tex(key: String) -> Texture2D:
	var path: String = FILES[key]
	if ResourceLoader.exists(path):
		return load(path)
	return ImageTexture.create_from_image(Image.load_from_file(path)) if FileAccess.file_exists(path) else null


## The full icon on a square of side `s` (nearest filtering keeps the pixels square).
static func paint(ci: CanvasItem, s: float) -> void:
	var t := _tex("icon")
	if t != null:
		ci.draw_texture_rect(t, Rect2(0, 0, s, s), false)


static func paint_background(ci: CanvasItem, s: float) -> void:
	var t := _tex("background")
	if t != null:
		ci.draw_texture_rect(t, Rect2(0, 0, s, s), false)


## Adaptive foreground: the mark only, kept inside the central safe zone.
static func paint_foreground(ci: CanvasItem, s: float) -> void:
	var t := _tex("foreground")
	if t != null:
		ci.draw_texture_rect(t, Rect2(0, 0, s, s), false)
