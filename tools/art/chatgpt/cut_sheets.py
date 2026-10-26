"""Cut Daniele's ChatGPT sheets (tools/art/sources/chatgpt/) into the play screen's pictures:

    python3 tools/art/chatgpt/cut_sheets.py

notes.png    -> game/art/ai/note_{step,offbeat,call,heal,six}.webp (blue, violet, red bell, green,
                bone-white: the sheet's plain row), note_hold (the bone-white coin in bronze) and
                note_stomp (the bone-white coin in black cloth, its emblem in bone)
controls.png -> crate_{idle,pressed}_{0,1,2}.webp (the step crates, feet carved in; the idle ones'
                feet lightened to bone), bar_up / bar_down (the red and blue tilt beams as drawn,
                their own arrow cut out as bar_arrow; their bells are too small, bar_bell stays the
                game's). The rope and knot: hemp.py
hud_kit.png  -> hud_plate, hud_badge_{1..4} (x1..x4 with the lettering taken out: the game writes
                the multiplier), hud_pause, hud_bar, hud_stud, heart_{full,empty,crack,broken},
                hud_combo, hud_seal, judge_plate (a judgement banner with its word taken out)

Every piece is keyed off the magenta, put on its own art grid, snapped to the style palette
(common.py) and saved 4x with nearest.
"""
import os
import numpy as np
import cv2
from scipy import ndimage
import common as c

AI = os.path.join(c.GAME, "art/ai")
K = 4


def lum(a):
    return (a[..., :3].astype(np.float32) @ np.array([0.299, 0.587, 0.114], np.float32)) / 255.0


def cut(sheet, box, f, pal=None, keep_all=False):
    """The piece inside box (l, t, r, b, sheet px) on its own art grid, snapped."""
    l, t, r, b = box
    a = sheet[t:b, l:r]
    k = c.keyed(a)
    if not keep_all:
        lab, n = ndimage.label(k[..., 3] > 0)
        if n > 1:
            sizes = ndimage.sum(k[..., 3] > 0, lab, range(1, n + 1))
            keep = [i + 1 for i, s in enumerate(sizes) if s > 0.02 * sizes.max()]
            k[~np.isin(lab, keep), 3] = 0
    g = c.grid(k, f)
    g = c.snap(g, pal)
    return c.crop_alpha(g)


def row_fill(a, mask, region):
    """Paints the masked pixels of region with the commonest unmasked colour of their row (the grain
    of the wood runs across)."""
    out = a.copy()
    t, b, l, r = region
    for y in range(t, b):
        row = a[y, l:r]
        ok = ~mask[y, l:r] & (row[:, 3] > 0)
        if not ok.any():
            ok = (row[:, 3] > 0) & ~mask[y, l:r]
        cols = row[ok][:, :3] if ok.any() else None
        if cols is None:
            # the rows above: carry the last fill down
            src = out[y - 1, l:r]
            out[y, l:r][mask[y, l:r]] = src[mask[y, l:r]]
            continue
        vals, counts = np.unique(cols.view([("", cols.dtype)] * 3), return_counts=True)
        mode = np.array(list(vals[counts.argmax()]), np.uint8)
        m = mask[y, l:r]
        out[y, l:r][m, :3] = mode
    return out


def erase_text(a, inset_x, inset_y, red=False):
    """Takes the carved lettering out of a plate: bright gold (or red) pixels well inside it and the
    dark outline round them, painted over with the plate's own wood."""
    h, w = a.shape[:2]
    t, b = int(h * inset_y), int(h * (1 - inset_y))
    l, r = int(w * inset_x), int(w * (1 - inset_x))
    hsv = cv2.cvtColor(np.ascontiguousarray(a[..., :3]), cv2.COLOR_RGB2HSV)
    text = lum(a) > 0.36
    if red:
        text |= (hsv[..., 0] < 8) | (hsv[..., 0] > 170)
        text &= hsv[..., 1] > 80
        text |= lum(a) > 0.36
    inner = np.zeros((h, w), bool)
    inner[t:b, l:r] = True
    text &= inner
    text = cv2.dilate(text.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    text &= inner
    return row_fill(a, text, (t, b, l, r))


def recolour_face(a, ramp, invert=False, emblem=None):
    """The bone-white coin's face in other colours: its linen pixels (and the emblem they enclose)
    remapped by lightness to ramp (dark first); invert: the face dark and the emblem light, emblem
    giving the emblem's colours then."""
    hexes = ["#6e6672", "#a89ea6", "#e2d6ca", "#fbf3e8"]
    lin = np.zeros(a.shape[:2], bool)
    for hx in hexes:
        lin |= (a[..., :3] == np.array(c._rgb(hx), np.uint8)).all(-1)
    face = ndimage.binary_fill_holes(cv2.morphologyEx(lin.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)) > 0)
    # only the big face, not specks on the rim
    lab, n = ndimage.label(face)
    if n > 1:
        sizes = ndimage.sum(face, lab, range(1, n + 1))
        face = lab == (sizes.argmax() + 1)
    L = lum(a)
    out = a.copy()
    rp = np.array([c._rgb(x) for x in ramp], np.uint8)
    lo, hi = L[face].min(), L[face].max()
    q = np.clip((L - lo) / max(hi - lo, 1e-3), 0, 0.999)
    if invert:
        light = face & lin
        dark = face & ~lin
        out[light, :3] = rp[np.minimum((q[light] * 0.8 * len(rp)).astype(int), len(rp) - 1)]
        ep = np.array([c._rgb(x) for x in emblem], np.uint8)
        out[dark, :3] = ep[np.minimum(((1 - q[dark]) * len(ep)).astype(int), len(ep) - 1)]
    else:
        out[face, :3] = rp[(q[face] * len(rp)).astype(int)]
    return out


def notes():
    s = c.load(c.src("notes.png"))
    f = 5.6
    xs = [(71, 422), (446, 799), (822, 1174), (1198, 1550), (1574, 1926)]
    names = ["note_step", "note_offbeat", "note_call", "note_heal", "note_six"]
    for (l, r), name in zip(xs, names):
        p = cut(s, (l - 8, 65, r + 8, 356), f)
        if name == "note_six":
            white = p
            p = plain_face(p)
        if name == "note_call":
            # the sheet's bell coin is magenta-pink, too near the off-beat's violet at a distance:
            # a true red face with a bone-white bell (review of round 1)
            p = swap(p, {"#701a46": "#a8161c", "#e0408c": "#e2d6ca", "#ffacd0": "#fbf3e8"})
        c.save(p, os.path.join(AI, name + ".webp"), K)
    c.save(recolour_face(white, ["#4a2c0e", "#8a5a1c", "#c0683a", "#d8802e", "#fba832"]), os.path.join(AI, "note_hold.webp"), K)
    stomp = recolour_face(white, ["#120e0e", "#251e1f", "#3a3132"], invert=True, emblem=["#a89ea6", "#e2d6ca", "#fbf3e8"])
    c.save(iron_rim(stomp), os.path.join(AI, "note_stomp.webp"), K)


def swap(a, table):
    out = a.copy()
    for k, v in table.items():
        m = (a[..., :3] == np.array(c._rgb(k), np.uint8)).all(-1) & (a[..., 3] > 0)
        out[m, :3] = c._rgb(v)
    return out


def _face(a, hexes):
    lin = np.zeros(a.shape[:2], bool)
    for hx in hexes:
        lin |= (a[..., :3] == np.array(c._rgb(hx), np.uint8)).all(-1)
    face = ndimage.binary_fill_holes(cv2.morphologyEx(lin.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)) > 0)
    lab, n = ndimage.label(face)
    if n > 1:
        sizes = ndimage.sum(face, lab, range(1, n + 1))
        face = lab == (sizes.argmax() + 1)
    return face


def plain_face(a):
    """The sixteenth: the bone coin with its emblem taken out, a plain bone face with a thin grey
    ring inside the rim and one small dot (it is drawn smaller too: StreetSkin.step)."""
    face = _face(a, ["#6e6672", "#a89ea6", "#e2d6ca", "#fbf3e8"])
    out = a.copy()
    out[face, :3] = c._rgb("#e2d6ca")
    inner = cv2.erode(face.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    out[face & ~inner, :3] = c._rgb("#a89ea6")
    top = cv2.erode(face.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    ys, xs = np.nonzero(face)
    cy, cx = int(ys.mean()), int(xs.mean())
    yy, xx = np.mgrid[:a.shape[0], :a.shape[1]]
    hi = face & (yy < cy - 0.35 * (ys.max() - ys.min())) & top
    out[hi, :3] = c._rgb("#fbf3e8")
    dot = (np.abs(yy - cy) <= 1) & (np.abs(xx - cx) <= 2)
    out[dot & face, :3] = c._rgb("#6e6672")
    return out


def iron_rim(a):
    """The stomp's bronze rim turned to dark iron (by lightness), its face kept: so the stomp, the
    hold (bronze face) and the sixteenth (bone face) never read alike."""
    face = _face(a, ["#120e0e", "#251e1f", "#3a3132", "#a89ea6", "#e2d6ca", "#fbf3e8"])
    rim = (a[..., 3] > 0) & ~face
    L = lum(a)
    ramp = np.array([c._rgb(x) for x in ["#07060a", "#1a1420", "#3a3132", "#6e6672", "#a89ea6", "#e2d6ca"]], np.uint8)
    lo, hi = L[rim].min(), L[rim].max()
    q = np.clip((L - lo) / max(hi - lo, 1e-3), 0, 0.999)
    out = a.copy()
    out[rim, :3] = ramp[(q[rim] * len(ramp)).astype(int)]
    return out


def controls():
    s = c.load(c.src("controls.png"))
    f = 5.9
    crates = [(68, 443), (495, 913), (962, 1337)]
    for row, (t, b), kind in [(0, (91, 421), "idle"), (1, (473, 791), "pressed")]:
        for i, (l, r) in enumerate(crates):
            p = cut(s, (l - 6, t - 6, r + 6, b + 6), f)
            if kind == "idle":
                p = bone_feet(p)
            c.save(p, os.path.join(AI, "crate_%s_%d.webp" % (kind, i)), K)
    # the beams: the red one tilts up, the blue one down
    for name, (t, b) in [("bar_up", (823, 928)), ("bar_down", (952, 1057))]:
        p = cut(s, (66, t - 6, 1050, b + 6), f)
        h, w = p.shape[:2]
        # its bell (left of the arrow) and arrow, before the beam is lengthened
        if name == "bar_up":
            # (its bells are 13 x 16 art px, too small to read once shrunk on the road: the
            # game keeps its own bar_bell picture; bell_of() is kept for a later, bigger cut)
            c.save(arrow_of(p), os.path.join(AI, "bar_arrow.webp"), K)
        # as drawn: never lengthened (Daniele, 2026-10-26: the art is never stretched); the game
        # fits it to the road's width at its own proportions
        c.save(p, os.path.join(AI, name + ".webp"), K)
    # (the rope and its knot are drawn by hemp.py: the sheet's were too small)


def bone_feet(p):
    """The idle crate's carved feet lightened to bone with a dark outline, so left / both / right
    read at a glance on the brown lid (the pressed crate keeps its glowing orange feet)."""
    h, w = p.shape[:2]
    peach = np.zeros((h, w), bool)
    for hx in ["#ecb894", "#c48262", "#e8975a", "#f6c48a"]:
        peach |= (p[..., :3] == np.array(c._rgb(hx), np.uint8)).all(-1)
    peach[int(h * 0.62):] = False
    lab, n = ndimage.label(peach)
    sizes = ndimage.sum(peach, lab, range(1, n + 1))
    feet = np.isin(lab, [i + 1 for i, sz in enumerate(sizes) if sz >= 6])
    feet = ndimage.binary_fill_holes(cv2.morphologyEx(feet.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)) > 0) & (p[..., 3] > 0)
    out = p.copy()
    L = lum(p)
    ramp = np.array([c._rgb(x) for x in ["#a89ea6", "#e2d6ca", "#e2d6ca", "#fbf3e8"]], np.uint8)
    lo, hi = L[feet].min(), L[feet].max()
    q = np.clip((L - lo) / max(hi - lo, 1e-3), 0, 0.999)
    out[feet, :3] = ramp[(q[feet] * len(ramp)).astype(int)]
    ring = (cv2.dilate(feet.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & ~feet & (p[..., 3] > 0)
    out[ring, :3] = c._rgb("#1a0e0a")
    return out


def bell_of(p):
    h, w = p.shape[:2]
    # the bells are bronze/gold standing on the cloth in the middle third
    reg = p[:, int(w * 0.3):int(w * 0.5)]
    hsv = cv2.cvtColor(np.ascontiguousarray(reg[..., :3]), cv2.COLOR_RGB2HSV)
    gold = (hsv[..., 0] >= 12) & (hsv[..., 0] <= 32) & (hsv[..., 1] > 90) & (reg[..., 3] > 0)
    lab, n = ndimage.label(cv2.dilate(gold.astype(np.uint8), np.ones((3, 3), np.uint8)))
    sizes = ndimage.sum(gold, lab, range(1, n + 1))
    m = lab == (sizes.argmax() + 1)
    ring = (cv2.dilate(m.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & ~m   # its dark outline
    out = reg.copy()
    out[~(m | ring), 3] = 0
    out[ring, :3] = c._rgb("#07060a")
    return c.crop_alpha(out)


def arrow_of(p):
    h, w = p.shape[:2]
    reg = p[:, int(w * 0.4):int(w * 0.6)]
    light = (lum(reg) > 0.6) & (reg[..., 3] > 0)
    lab, n = ndimage.label(light)
    sizes = ndimage.sum(light, lab, range(1, n + 1))
    m = lab == (sizes.argmax() + 1)
    m = cv2.dilate(m.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    out = reg.copy()
    out[~m, 3] = 0
    out[m & ~(lab == (sizes.argmax() + 1)), :3] = c._rgb("#07060a")
    return c.crop_alpha(out)


def lengthen(p, aspect):
    """The beam made aspect times as long as it is tall: its two ends (end cap and rope binding) as
    drawn, a plain stretch of its cloth (before the first bell) repeated between them."""
    h, w = p.shape[:2]
    a, b = int(w * 0.165), int(w * 0.835)
    left, right = p[:, :a], p[:, b:]
    plain = p[:, int(w * 0.19):int(w * 0.31)]
    total = int(round(h * aspect))
    n = max(1, total - left.shape[1] - right.shape[1])
    reps = int(np.ceil(n / plain.shape[1]))
    mid_part = np.concatenate([plain] * reps, 1)[:, :n]
    return np.concatenate([left, mid_part, right], 1)


def hud():
    s = c.load(c.src("hud_kit.png"))
    f = 5.6
    out = {
        "hud_plate": (66, 81, 586, 257),
        "hud_badge_1": (611, 50, 821, 293), "hud_badge_2": (842, 50, 1053, 293),
        "hud_badge_3": (1073, 50, 1285, 293), "hud_badge_4": (1306, 50, 1518, 293),
        "hud_pause": (66, 298, 211, 443), "hud_bar": (239, 327, 1410, 413), "hud_stud": (1436, 326, 1521, 413),
        "heart_full": (66, 484, 211, 619), "heart_empty": (235, 484, 381, 619),
        "heart_crack": (406, 484, 552, 619), "heart_broken": (575, 484, 731, 619),
        "hud_combo": (779, 488, 1213, 611), "hud_seal": (1256, 456, 1520, 722),
        "judge_perfect": (100, 666, 621, 792), "judge_good": (679, 666, 1200, 792),
        "judge_ok": (100, 805, 621, 933), "judge_miss": (679, 805, 1200, 933),
    }
    for name, box in out.items():
        p = cut(s, box, f)
        if name.startswith("hud_badge_"):
            p = erase_text(p, 0.2, 0.24)
        if name == "judge_good":
            c.save(erase_text(p, 0.14, 0.2), os.path.join(AI, "judge_plate.webp"), K)
        if name == "hud_combo":
            c.save(p, os.path.join(AI, name + ".webp"), K)
            continue
        if name.startswith("judge_"):
            continue
        c.save(p, os.path.join(AI, name + ".webp"), K)


if __name__ == "__main__":
    notes()
    controls()
    hud()
