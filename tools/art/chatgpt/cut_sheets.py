"""Cut Daniele's ChatGPT sheets (tools/art/sources/chatgpt/) into the play screen's pictures:

    python3 tools/art/chatgpt/cut_sheets.py

notes.png    -> game/art/ai/note_{step,offbeat,call,heal,six}.webp (blue, violet, red bell, green,
                bone-white: the sheet's plain row), note_hold (the bone-white coin in bronze) and
                note_stomp (the bone-white coin in black cloth, its emblem in bone)
controls.png -> crate_{idle,pressed}_{0,1,2}.webp (the step crates, feet carved in), bar_up / bar_down
                (the red and blue tilt beams, lengthened, their own arrow cut out as
                bar_arrow; their bells are too small, bar_bell stays the game's), rope.webp (the segment, repeated), knot.webp
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
        c.save(p, os.path.join(AI, name + ".webp"), K)
        if name == "note_six":
            white = p
    c.save(recolour_face(white, ["#4a2c0e", "#8a5a1c", "#c0683a", "#d8802e", "#fba832"]), os.path.join(AI, "note_hold.webp"), K)
    c.save(recolour_face(white, ["#120e0e", "#251e1f", "#3a3132"], invert=True, emblem=["#a89ea6", "#e2d6ca", "#fbf3e8"]),
        os.path.join(AI, "note_stomp.webp"), K)


def controls():
    s = c.load(c.src("controls.png"))
    f = 5.9
    crates = [(68, 443), (495, 913), (962, 1337)]
    for row, (t, b), kind in [(0, (91, 421), "idle"), (1, (473, 791), "pressed")]:
        for i, (l, r) in enumerate(crates):
            p = cut(s, (l - 6, t - 6, r + 6, b + 6), f)
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
        c.save(lengthen(p, 14.0), os.path.join(AI, name + ".webp"), K)
    seg = cut(s, (1130, 845, 1192, 1018), f)
    reps = max(2, round(5.5 * seg.shape[1] / seg.shape[0]))
    c.save(np.concatenate([seg] * reps, 0), os.path.join(AI, "rope.webp"), K)
    c.save(cut(s, (1236, 885, 1340, 975), f), os.path.join(AI, "knot.webp"), K)


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
