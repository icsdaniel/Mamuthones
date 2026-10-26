"""Scenes around the game from Daniele's ChatGPT village and workshop pictures:

    python3 tools/art/chatgpt/scenes.py

village_square.png -> game/art/px/scenery/title_scene{,_lit,_dim}.png: the night square under the
    stars, 240 art px wide (the base screen's width), cut so the lit middle of the square, where the
    title's bonfire burns (TitleScene.FIRE, 58 art px over the bottom), is the fire's place; the lit
    and dim twins are the same picture warmer and brighter / darker (the beat's light)
workshop.png       -> game/art/px/stops/stop_1_bg.png (and an empty stop_1_front): the carver's
    workshop, 320 x 184 (StopCells.WORLD); stop_1.png is its card (StopCells.CARD, at CARD_AT)
village_street.png -> stop_2{,_bg}.png: the village street at night, its stone fire ring where the
    stop's bonfire burns
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
CARD_AT = {1: (54, 30), 2: (100, 30)}


def stop(name, n, front=True):
    a = rgba(name)
    g = c.snap(c.grid(a, None, (320, 184)), PAL)
    x, y = CARD_AT[n]
    c.save(g[y:y + CARD[1], x:x + CARD[0]], os.path.join(PX, "stops", "stop_%d.png" % n))
    c.save(g, os.path.join(PX, "stops", "stop_%d_bg.png" % n))
    if front:
        c.save(np.zeros_like(g), os.path.join(PX, "stops", "stop_%d_front.png" % n))


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
    stop("workshop.png", 1)
    stop("village_street.png", 2)
    backdrop()
