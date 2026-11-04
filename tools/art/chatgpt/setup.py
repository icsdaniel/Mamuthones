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


def glass(g, scr):
    """The game on the phone's glass, as the old drawing had it: the night road with its three lanes
    in gold, the hit line in bone near the bottom, and a step, an off-beat and a call note coming
    down (the glass's own outline kept)."""
    out = g.copy()
    inner = scr & (np.roll(scr, 1, 0) & np.roll(scr, -1, 0) & np.roll(scr, 1, 1) & np.roll(scr, -1, 1))
    ys, xs = np.nonzero(inner)
    t, b = ys.min(), ys.max()
    sky, road = c._rgb("#0b1a33"), c._rgb("#13284a")
    # the glass's sides as straight lines (the thumbs cut into some rows): fitted to the rows' ends
    rows = [(y, np.nonzero(inner[y])[0]) for y in range(t, b + 1)]
    rows = [(y, rr.min(), rr.max()) for y, rr in rows if rr.size]
    yy = np.array([q[0] for q in rows], float)
    lf = np.polyfit(yy, [q[1] for q in rows], 1)
    rf = np.polyfit(yy, [q[2] for q in rows], 1)
    lf[1] -= 0.0
    edge_l = lambda y: int(round(np.polyval(lf, y)))
    edge_r = lambda y: int(round(np.polyval(rf, y)))
    for y in range(t, b + 1):
        row = np.nonzero(inner[y])[0]
        if row.size == 0:
            continue
        out[y, row, :3] = sky if (y - t) / max(b - t, 1) < 0.12 else road
        l, r = edge_l(y), edge_r(y)
        v = (y - t) / max(b - t, 1)
        if v < 0.12:
            continue
        # the lanes narrow toward the top
        k = 0.45 + 0.55 * (v - 0.12) / 0.88
        mid, half = (l + r) / 2.0, (r - l) / 2.0 * k
        for u, col in ((-1.0, "#c8400c"), (-1 / 3, "#fba832"), (1 / 3, "#fba832"), (1.0, "#c8400c")):
            x = int(round(mid + u * (half - 0.5)))
            if inner[y, x]:
                out[y, x, :3] = c._rgb(col)
        if abs(v - 0.82) < 0.025:
            for x in range(l + 1, r):
                if (x - l) % 3 and inner[y, x]:
                    out[y, x, :3] = c._rgb("#e2d6ca")
    for lane, vv, cols in ((0, 0.5, ("#173c8a", "#2f78e0", "#9cc4ff")), (2, 0.34, ("#44176a", "#8a2fd0", "#c8a0ff")),
                           (1, 0.66, ("#5a0e12", "#a8161c", "#fbf3e8"))):
        y = int(round(t + vv * (b - t)))
        l, r = edge_l(y), edge_r(y)
        k = 0.45 + 0.55 * (vv - 0.12) / 0.88
        mid, half = (l + r) / 2.0, (r - l) / 2.0 * k
        cx = int(round(mid + (lane - 1) * 2 / 3 * half))
        rr = max(2, int(round(half / 3 * 0.6)))
        for dy in range(-rr, rr + 1):
            for dx in range(-rr - 1, rr + 2):
                d = (dx / (rr + 1.0)) ** 2 + (dy / float(rr)) ** 2
                yy, xx = y + dy, cx + dx
                if d <= 1.0 and inner[yy, xx]:
                    out[yy, xx, :3] = c._rgb(cols[0] if d > 0.6 else (cols[2] if d < 0.12 else cols[1]))
    return out


def fade_bottom(g, rows=10):
    """The hands' straight cut at the bottom of the picture dissolved in an ordered dither, so it
    does not end in a hard line."""
    out = g.copy()
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
    ys = np.nonzero(out[..., 3].any(1))[0]
    b = ys.max()
    for i in range(rows):
        y = b - i
        k = (rows - i) / (rows + 1.0)          # share of the row taken out
        for x in range(out.shape[1]):
            if bayer[y % 4, x % 4] < k:
                out[y, x, 3] = 0
                out[y, x, :3] = 0
    return out


def rim(g, col="#d8802e", hot="#fba832"):
    """A warm rim of firelight round a dark piece: a one px outline on its upper and outer sides,
    the topmost edge hotter."""
    out = g.copy()
    a = g[..., 3] > 0
    edge = np.zeros_like(a)
    for dy, dx in ((-1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1)):
        edge |= np.roll(np.roll(a, dy, 0), dx, 1)
    edge &= ~a
    out[edge, :3] = c._rgb(col)
    out[edge, 3] = 255
    top = edge & ~np.roll(edge | a, 1, 0)
    out[top, :3] = c._rgb(hot)
    return out


def phones():
    for i in range(9):
        a = biggest(c.keyed(c.load(c.src("phone-restart/phone_%d.png" % i)), loose=True))
        g = fit(a, (136, 150))
        scr = screen_of(g)
        ys, xs = np.nonzero(scr)
        t, b, l, r = ys.min(), ys.max(), xs.min(), xs.max()
        spots = [(l + (r - l) // 4, b - (b - t) // 5), (r - (r - l) // 4, b - (b - t) // 5)]
        g = fade_bottom(glass(g, scr))
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
    # dark grey on the dark scene: a rim of firelight round it (review of round 1)
    g = fit(biggest(c.keyed(c.load(c.src("headphones.png")))), (126, 102), "middle")
    out = np.zeros((104, 128, 4), np.uint8)
    out[1:103, 1:127] = g
    c.save(rim(out), os.path.join(SETUP, "headphones.png"))


def logo():
    """The word sits over the mask's beard and bells, so the picture is kept whole: logo.png and
    title.png are the whole logo (the title screen shows it over the sky), mark.png the mask and
    bells above the word (a seal)."""
    a = c.crop_alpha(biggest(c.keyed(c.load(c.src("logo.png")))))
    # 120 art px wide: drawn at one art px a texel (Logo, 3x on the base screen), on the play grid
    f = a.shape[1] / 120.0
    g = c.crop_alpha(c.snap(c.grid(a, f), PAL))
    c.save(g, os.path.join(LOGO, "logo.png"))
    c.save(g, os.path.join(LOGO, "title.png"))
    c.save(c.crop_alpha(g[:int(g.shape[0] * 0.7)]), os.path.join(LOGO, "mark.png"))


if __name__ == "__main__":
    phones()
    drum()
    headphones()
    logo()
