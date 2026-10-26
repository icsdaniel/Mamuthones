"""The setup screens' pictures and the logo from Daniele's ChatGPT pictures:

    python3 tools/art/chatgpt/setup.py

phone-restart/phone_<i>.png (nine drawn poses: 0 tilted furthest away, 4 level, 8 furthest toward)
    -> game/art/px/setup/phone_<i>_<l><r>.png (SetupCells.PHONE, 136 x 150, feet... the hands at the
       bottom): the same pose for every thumb state, with an ember ring on the glass under each thumb
       that is pressed; phone_screen_<i>.png: the glass alone in warm white (the flash of a counted tilt)
drum-animation-v2/drum_{rest,hit}.png -> drum_0..3.png (SetupCells.DRUM, 132 x 116): rest for no and a
       light hit, the struck drum for the rest
headphones.png -> headphones.png (SetupCells.HEADPHONES, 128 x 104)
logo.png (the SONAZZOS word mark under the carved mask and its two bells) -> game/art/px/logo/
       logo.png and title.png (whole), mark.png (the mask and bells)

All keyed off the magenta, on the art grid, snapped to the style palette without the notes' colours.
"""
import os
import numpy as np
from scipy import ndimage
import common as c

SETUP = os.path.join(c.GAME, "art/px/setup")
LOGO = os.path.join(c.GAME, "art/px/logo")
PAL = c.palette(reserved=False)


def fit(rgba, size, align="bottom"):
    """Shrunk whole onto a canvas of `size` art px (keeping its shape), centred across."""
    a = c.crop_alpha(rgba)
    h, w = a.shape[:2]
    f = max(w / size[0], h / size[1])
    g = c.snap(c.grid(a, f), PAL)
    out = np.zeros((size[1], size[0], 4), np.uint8)
    gh, gw = g.shape[:2]
    gh, gw = min(gh, size[1]), min(gw, size[0])
    x = (size[0] - gw) // 2
    y = size[1] - gh if align == "bottom" else (size[1] - gh) // 2
    out[y:y + gh, x:x + gw] = g[:gh, :gw]
    return out


def biggest(rgba):
    on = rgba[..., 3] > 0
    lab, n = ndimage.label(on)
    if n > 1:
        sizes = ndimage.sum(on, lab, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s > 0.03 * sizes.max()]
        rgba = rgba.copy()
        rgba[~np.isin(lab, keep), 3] = 0
    return rgba


def screen_of(g):
    """The phone's glass: the biggest patch of near-black inside the picture."""
    dark = (g[..., 3] > 0) & (g[..., :3].astype(int).sum(-1) < 90)
    lab, n = ndimage.label(dark)
    sizes = ndimage.sum(dark, lab, range(1, n + 1))
    return ndimage.binary_fill_holes(lab == (sizes.argmax() + 1))


def ring(g, cx, cy, r=4):
    out = g.copy()
    hot = [c._rgb(x) for x in ("#7a1c0a", "#f07018", "#ffd86a")]
    for y in range(cy - r - 1, cy + r + 2):
        for x in range(cx - r - 1, cx + r + 2):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if 0 <= y < g.shape[0] and 0 <= x < g.shape[1] and out[y, x, 3] > 0:
                if r - 1.2 <= d <= r + 0.5:
                    out[y, x, :3] = hot[1]
                elif d < r - 1.2:
                    out[y, x, :3] = hot[0] if d > 1.2 else hot[2]
    return out


def phones():
    for i in range(9):
        a = biggest(c.keyed(c.load(c.src("phone-restart/phone_%d.png" % i)), loose=True))
        g = fit(a, (136, 150))
        scr = screen_of(g)
        ys, xs = np.nonzero(scr)
        t, b, l, r = ys.min(), ys.max(), xs.min(), xs.max()
        spots = [(l + (r - l) // 4, b - (b - t) // 5), (r - (r - l) // 4, b - (b - t) // 5)]
        for lp in (0, 1):
            for rp in (0, 1):
                p = g
                if lp:
                    p = ring(p, *spots[0])
                if rp:
                    p = ring(p, *spots[1])
                c.save(p, os.path.join(SETUP, "phone_%d_%d%d.png" % (i, lp, rp)))
        s = np.zeros_like(g)
        s[scr] = c._rgb("#fff4cc") + [255]
        c.save(s, os.path.join(SETUP, "phone_screen_%d.png" % i))


def drum():
    rest = fit(biggest(c.keyed(c.load(c.src("drum-animation-v2/drum_rest.png")))), (132, 116), "middle")
    hit = fit(biggest(c.keyed(c.load(c.src("drum-animation-v2/drum_hit.png")))), (132, 116), "middle")
    for k, p in enumerate((rest, rest, hit, hit)):
        c.save(p, os.path.join(SETUP, "drum_%d.png" % k))


def headphones():
    c.save(fit(biggest(c.keyed(c.load(c.src("headphones.png")))), (128, 104), "middle"), os.path.join(SETUP, "headphones.png"))


def logo():
    """The word sits over the mask's beard and bells, so the picture is kept whole: logo.png and
    title.png are the whole logo (the title screen shows it over the sky), mark.png the mask and
    bells above the word (a seal)."""
    a = c.crop_alpha(biggest(c.keyed(c.load(c.src("logo.png")))))
    f = a.shape[1] / 200.0
    g = c.crop_alpha(c.snap(c.grid(a, f), PAL))
    c.save(g, os.path.join(LOGO, "logo.png"))
    c.save(g, os.path.join(LOGO, "title.png"))
    c.save(c.crop_alpha(g[:int(g.shape[0] * 0.7)]), os.path.join(LOGO, "mark.png"))


if __name__ == "__main__":
    phones()
    drum()
    headphones()
    logo()
