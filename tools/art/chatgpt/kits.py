"""Cut Daniele's ChatGPT kits of 2026-10-28 (tools/art/sources/chatgpt/review-1028/, from the
graphics review's prompts A1-A3) into the play screen's pictures:

    python3 tools/art/chatgpt/kits.py

a1_straps.png      -> bar_up / bar_down (the red and blue bell straps: left cap, whole middle tiles,
                      right cap, laid side by side, never stretched), bar_arrow (the big arrow),
                      bar_bell, bar_bell_l / bar_bell_r (the cowbell and its two swings)
a2_rings_coins.png -> ring_idle / ring_gold / ring_red and the note coins, all drawn at the same
                      angle so a coin lands exactly on its ring: note_step (blue star), note_offbeat
                      (the violet open ring), note_hold (bronze spiral), note_heal (green sprout),
                      note_call (pink shout), note_stomp (black spiral, iron rim), note_six (plain bone)
a3_hud_plates.png  -> hud_bar (the progress groove), hud_plate (score and health)
                      and judge_plate (the judgement banner), each as [left cap | one middle tile |
                      right cap]; Hud.sliced() lays the caps and repeats the tile (cropping the last
                      one), so a plate takes any width without stretching

controls.png       -> crate_idle_{0,1,2}: the idle crates' feet redrawn from the pressed crates' clean
                      feet in bone (the sheet's idle feet had a stray grey nub over the toes)

Every piece is keyed off the magenta, put on its own art grid, snapped to the style palette
(common.py) and saved 4x with nearest.
"""
import os
import numpy as np
from scipy import ndimage
import cv2
import common as c
import cut_sheets as cs

AI = os.path.join(c.GAME, "art/ai")
SRC = os.path.join(c.SRC, "review-1028")
K = 4


def sheet(name):
    return c.load(os.path.join(SRC, name))


def piece(s, box, f, keep_holes=True):
    """The piece inside box (l, t, r, b, sheet px): keyed, on its art grid, snapped, cropped."""
    l, t, r, b = box
    k = c.keyed(s[t:b, l:r])
    lab, n = ndimage.label(k[..., 3] > 0)
    if n > 1:
        sizes = ndimage.sum(k[..., 3] > 0, lab, range(1, n + 1))
        keep = [i + 1 for i, sz in enumerate(sizes) if sz > 0.02 * sizes.max()]
        k[~np.isin(lab, keep), 3] = 0
    g = c.snap(c.grid(k, f))
    return c.crop_alpha(g)


def period(tile):
    """The repeat of a patterned strip (its columns' best self-match), in art px."""
    a = tile[..., :3].astype(np.float32)
    w = a.shape[1]
    best, score = w, np.inf
    for p in range(6, w // 2 + 1):
        d = np.abs(a[:, p:] - a[:, :-p]).mean()
        if d < score - 1e-3:
            best, score = p, d
    return best, score


def seamless(tile):
    """A whole number of the strip's repeats from its middle, so tiles laid side by side join."""
    p, score = period(tile)
    w = tile.shape[1]
    if score > 40.0:
        return tile
    n = max(1, (w - 4) // p)
    x0 = (w - n * p) // 2
    return tile[:, x0:x0 + n * p]


def same_height(parts):
    """The pieces cut to the height they share, centred (a cap's buckle or corner may stand out)."""
    h = min(p.shape[0] for p in parts)
    out = []
    for p in parts:
        t = (p.shape[0] - h) // 2
        out.append(p[t:t + h])
    return out


def pad_to(p, h):
    """p padded with clear rows (top and bottom alike) to height h."""
    if p.shape[0] >= h:
        return p
    t = (h - p.shape[0]) // 2
    out = np.zeros((h, p.shape[1], 4), np.uint8)
    out[t:t + p.shape[0]] = p
    return out


def inner(p, left=0, right=0):
    """p without its outline on the sides that join another piece (ChatGPT outlines every piece
    all round; a cap's inner end and a tile's two ends must run straight on)."""
    return p[:, left:p.shape[1] - right]


def strip(left, mid, right, tiles=1):
    h = max(left.shape[0], mid.shape[0], right.shape[0])
    return np.concatenate([pad_to(left, h)] + [pad_to(mid, h)] * tiles + [pad_to(right, h)], 1)


def straps():
    s = sheet("a1_straps.png")
    f = 7.8
    for name, (t, b) in [("bar_up", (100, 310)), ("bar_down", (372, 584))]:
        left = inner(piece(s, (76, t, 428, b), f), right=2)
        mid = seamless(inner(piece(s, (488, t, 1048, b), f), 2, 2))
        right = inner(piece(s, (1106, t, 1462, b), f), left=2)
        # about 15 to 1, the road's width at the hit line over the strap's depth there
        h = max(left.shape[0], mid.shape[0])
        n = max(1, int(round((15.0 * h - left.shape[1] - right.shape[1]) / mid.shape[1])))
        c.save(strip(left, mid, right, n), os.path.join(AI, name + ".webp"), K)
    c.save(piece(s, (110, 664, 362, 928), f), os.path.join(AI, "bar_arrow.webp"), K)
    c.save(piece(s, (490, 662, 678, 934), f), os.path.join(AI, "bar_bell.webp"), K)
    c.save(piece(s, (855, 662, 1058, 934), f), os.path.join(AI, "bar_bell_l.webp"), K)
    c.save(piece(s, (1146, 662, 1350, 934), f), os.path.join(AI, "bar_bell_r.webp"), K)


def coins():
    s = sheet("a2_rings_coins.png")
    f = 5.1
    rows = {
        "ring_idle": (28, 116, 383, 294), "ring_gold": (402, 115, 755, 295), "ring_red": (776, 113, 1132, 295),
        "note_step": (19, 403, 387, 611), "note_offbeat": (398, 405, 760, 610),
        "note_hold": (772, 403, 1137, 610), "note_heal": (1149, 403, 1515, 610),
        "note_call": (20, 706, 388, 915), "note_stomp": (393, 699, 764, 920),
        "note_six": (1146, 704, 1513, 915),
    }
    for name, box in rows.items():
        c.save(piece(s, box, f), os.path.join(AI, name + ".webp"), K)


def hud():
    s = sheet("a3_hud_plates.png")
    f = 6.7
    kits = {
        "hud_bar": [(446, 81, 589, 224), (615, 83, 921, 223), (947, 81, 1090, 224)],
        "hud_plate": [(290, 374, 531, 687), (557, 382, 979, 679), (1005, 374, 1246, 687)],
        "judge_plate": [(466, 712, 608, 938), (631, 716, 905, 934), (928, 711, 1070, 938)],
    }
    caps = {}
    for name, boxes in kits.items():
        left, mid, right = [piece(s, b, f) for b in boxes]
        left, mid, right = inner(left, right=2), seamless(inner(mid, 2, 2)), inner(right, left=2)
        left, mid, right = same_height([left, mid, right])
        caps[name] = left.shape[1]
        c.save(strip(left, mid, right), os.path.join(AI, name + ".webp"), K)
    print("caps (art px; x%d in the files):" % K, caps)


BONE = ["#6e6672", "#a89ea6", "#e2d6ca", "#fbf3e8", "#ecb894", "#c48262", "#e8975a", "#f6c48a"]


def _mask(p, hexes, top=1.0, side=0.0):
    """The idle feet: pixels of hexes above row share top and inside the lid (side: share of the
    width left out at each edge), holes filled."""
    m = np.zeros(p.shape[:2], bool)
    for hx in hexes:
        m |= (p[..., :3] == np.array(c._rgb(hx), np.uint8)).all(-1) & (p[..., 3] > 0)
    h, w = m.shape
    m[int(h * top):] = False
    m[:int(h * 0.06)] = False
    m[:, :int(w * side)] = False
    m[:, w - int(w * side):] = False
    return ndimage.binary_fill_holes(cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)) > 0)


def foot(w=15, h=25):
    """A bare left footprint seen from above, drawn here (a small flat piece): five toes, the big one
    on the right, the ball, the arch cut in on the big toe's side, the heel. A bool mask."""
    yy, xx = np.mgrid[:h, :w].astype(np.float32) + 0.5
    sx, sy = w / 15.0, h / 23.0
    X, Y = xx / sx, yy / sy

    def ell(cx, cy, rx, ry):
        return ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 <= 1.0
    ball = ell(7.8, 10.2, 6.4, 3.6)
    heel = ell(6.4, 19.2, 4.2, 3.6)
    mid = (Y >= 10.2) & (Y <= 19.2)
    t = np.clip((Y - 10.2) / 9.0, 0, 1)
    left = 1.0 + 1.2 * t
    right = 14.2 - 3.6 * t
    body = ball | heel | (mid & (X >= left) & (X <= right))
    body &= ~ell(16.6, 14.8, 6.4, 4.6)
    toes = ell(1.9, 5.4, 1.2, 1.3) | ell(4.4, 3.9, 1.3, 1.4) | ell(7.1, 2.8, 1.4, 1.5) | ell(10.0, 2.2, 1.5, 1.6) | ell(13.2, 2.4, 1.8, 2.1)
    return body, toes & ~body


def _stamp_foot(out, at, mirror):
    """A bone footprint (foot()) centred at at (row, col) on crate picture out, with a dark outline."""
    body, toes = foot()
    if mirror:
        body, toes = body[:, ::-1], toes[:, ::-1]
    fh, fw = body.shape
    y0, x0 = at[0] - fh // 2, at[1] - fw // 2
    h, w = out.shape[:2]

    def place(m):
        g = np.zeros((h, w), bool)
        g[y0:y0 + fh, x0:x0 + fw] = m
        return g & (out[..., 3] > 0)
    body, toes = place(body), place(toes)
    feet = body | toes
    out[body, :3] = c._rgb("#e2d6ca")
    # lit from the top: the sole's upper-left edge bright, its lower-right in shade; the toes plain
    up = body & ~np.roll(body, 1, 0)
    lt = body & ~np.roll(body, 1, 1)
    dn = body & ~np.roll(body, -1, 0)
    rt = body & ~np.roll(body, -1, 1)
    out[up | lt, :3] = c._rgb("#fbf3e8")
    out[dn | rt, :3] = c._rgb("#a89ea6")
    out[toes, :3] = c._rgb("#fbf3e8")
    ring = (cv2.dilate(feet.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & ~feet & (out[..., 3] > 0)
    out[ring, :3] = c._rgb("#1a0e0a")


def crates():
    s = c.load(c.src("controls.png"))
    f = 5.9
    boxes = [(68, 443), (495, 913), (962, 1337)]
    for i, (l, r) in enumerate(boxes):
        idle = cs.cut(s, (l - 6, 85, r + 6, 427), f)
        old = _mask(idle, BONE, 0.62, 0.08)
        h, w = idle.shape[:2]
        gone = cv2.dilate(old.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
        out = cs.row_fill(idle, gone, (0, h, 0, w))
        lab, n = ndimage.label(cv2.dilate(old.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0)
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        big = sorted(range(1, n + 1), key=lambda k: -sizes[k - 1])[:2 if i == 1 else 1]
        spots = sorted([tuple(int(round(v)) for v in ndimage.center_of_mass(lab == k)) for k in big], key=lambda q: q[1])
        for j, at in enumerate(spots):
            # left / both / right: the left crate a left foot, the right crate a right one
            _stamp_foot(out, at, mirror=(i == 2 or (i == 1 and j == 1)))
        c.save(out, os.path.join(AI, "crate_idle_%d.webp" % i), cs.K)


if __name__ == "__main__":
    crates()
    straps()
    coins()
    hud()
