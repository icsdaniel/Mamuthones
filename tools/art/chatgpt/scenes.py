"""Scenes around the game from Daniele's ChatGPT village and workshop pictures:

    python3 tools/art/chatgpt/scenes.py

village_square.png -> game/art/px/scenery/title_scene{,_lit,_dim}.png: the night square under the
    stars, 240 art px wide (the base screen's width), cut so the lit middle of the square, where the
    title's bonfire burns (TitleScene.FIRE, 58 art px over the bottom), is the fire's place; the lit
    and dim twins are the same picture warmer and brighter / darker (the beat's light)
workshop_tall.png, village_well_night.png, village_banners_dusk.png, village_tree_dusk.png,
church_square.png, village_street_long.png -> game/art/px/stops/stop_{1,3,4,5,6,7}{,_bg}.png (and an empty
    _front): a band of each upright scene at the world's proportions (320 x 184, StopCells.WORLD), the
    card (StopCells.CARD) on its subject
village_street.png -> stop_2{,_bg}.png: the village street at night, its stone fire ring where the
    stop's bonfire burns
Then run tools/art/pixel/stops.py: it takes these stops' cards, fires and glows from stop_scenes.json.
village_lane.png   -> game/art/px/ui/backdrop.png: the stone every menu stands on, now a lit lane
    of the village, 360 x 540, darkened so the panels and their text read over it

All on the art grid, snapped to the style palette without the notes' colours.
"""
import os
import numpy as np
from PIL import Image
import common as c

PX = os.path.join(c.GAME, "art/px")
PAL = c.palette(reserved=False)


def rgba(name):
    a = c.load(c.src(name))
    a[..., 3] = 255
    return a


def tone(a, k, warm=0.0):
    f = a.astype(np.float32)
    f[..., :3] *= k
    if warm:
        f[..., 0] += warm * 40
        f[..., 1] += warm * 12
    return np.clip(f, 0, 255).astype(np.uint8)


def title():
    a = rgba("village_square.png")
    f = a.shape[1] / 240.0
    g = c.grid(a, f)
    # the lit middle of the square (row 1300 of the picture) 58 art px over the bottom
    bottom = int(round(1300 / f)) + 58
    g = g[:bottom]
    for name, k, w in (("title_scene", 1.0, 0.0), ("title_scene_lit", 1.18, 0.4), ("title_scene_dim", 0.72, 0.0)):
        c.save(c.snap(tone(g, k, w), PAL), os.path.join(PX, "scenery", name + ".png"))


# each stop card's top-left in its world (StopCells.STOPS[n].card), the card StopCells.CARD big
CARD = (212, 148)
WORLD = (320, 184)
# Stops from Daniele's upright (941 x 1672) scenes: a band of the picture as wide as it is, at the
# world's proportions (never stretched), its top row in the picture's px; and the card's place in it
# (the card shows the scene's subject, not the floor).
PORTRAIT = {
    1: ("workshop_tall.png", 500, (0, 6)),            # the carver's bench: the mask, the chisels, the shavings (the bells hang above the band)
    3: ("village_well_night.png", 724, (74, 26)),     # Around the Bonfires: the night lane, the well
    4: ("village_banners_dusk.png", 640, (54, 18)),   # Carnival Sunday: red cloths across the street
    5: ("village_tree_dusk.png", 655, (54, 18)),      # The Rope: the lane at dusk, the bare tree
    6: ("church_square.png", 560, (54, 18)),          # The Piazza: the church square
    7: ("village_street_long.png", 330, (54, 18)),    # Shrove Tuesday: the long lit street
}
# (each band's top is chosen so the paving shows along its lower part: the procession stands on it)
WIDE = {2: ("village_street.png", (100, 30))}         # Sant'Antonio's Fires: the stone fire ring
# the stops' fires and glows on the new pictures (the drawn worlds' ones fell on blank walls)
FIRES = {2: [[255, 152, "big"]]}
GLOWS = {1: [[293, 14, 36, 28]], 2: [[255, 120, 96, 72]]}
SMOKE = {2: [[255, 76]]}


def _save_stop(g, n, card_at, front=True):
    x, y = card_at
    c.save(g[y:y + CARD[1], x:x + CARD[0]], os.path.join(PX, "stops", "stop_%d.png" % n))
    c.save(g, os.path.join(PX, "stops", "stop_%d_bg.png" % n))
    if front:
        c.save(np.zeros_like(g), os.path.join(PX, "stops", "stop_%d_front.png" % n))
    mid = os.path.join(PX, "stops", "stop_%d_mid.png" % n)
    if os.path.exists(mid):
        os.remove(mid)
    top = g[0, WORLD[0] // 2, :3]
    return {"card": list(card_at), "layers": ["bg", "front"] if front else ["bg"],
            "fires": FIRES.get(n, []), "glows": GLOWS.get(n, []), "smoke": SMOKE.get(n, []),
            "top": "#%02x%02x%02x" % tuple(int(v) for v in top)}


def stop_wide(n):
    name, card_at = WIDE[n]
    a = rgba(name)
    h, w = a.shape[:2]
    # cropped to the world's proportions first (never stretched), then taken down to it
    ch = int(round(w * WORLD[1] / WORLD[0]))
    t = max(0, (h - ch) // 2)
    g = c.snap(c.grid(a[t:t + ch], None, WORLD), PAL)
    return _save_stop(g, n, card_at)


def stop_portrait(n):
    name, top, card_at = PORTRAIT[n]
    a = rgba(name)
    w = a.shape[1]
    band = a[top:top + int(round(w * WORLD[1] / WORLD[0]))]
    g = c.snap(c.grid(band, None, WORLD), PAL)
    return _save_stop(g, n, card_at)


def stops():
    """Every stop's picture, and tools/art/chatgpt/stop_scenes.json, which tools/art/pixel/stops.py
    reads to write their cards, fires and glows into stop_cells.gd (re-run it after this)."""
    import json
    out = {}
    for n in sorted(set(PORTRAIT) | set(WIDE)):
        out[str(n)] = stop_portrait(n) if n in PORTRAIT else stop_wide(n)
    with open(os.path.join(c.HERE, "stop_scenes.json"), "w") as f:
        json.dump(out, f, indent=1)


def backdrop():
    a = rgba("village_lane.png")
    h, w = a.shape[:2]
    top = h - int(round(w * 540 / 360))
    g = c.grid(a[top:], None, (360, 540))
    f = g.astype(np.float32)
    grey = f[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32)
    f[..., :3] = f[..., :3] * 0.6 + grey[..., None] * 0.4
    c.save(c.snap(tone(f.astype(np.uint8), 0.45), PAL), os.path.join(PX, "ui", "backdrop.png"))


if __name__ == "__main__":
    title()
    stops()
    backdrop()
