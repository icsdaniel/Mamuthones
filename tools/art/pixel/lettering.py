"""Hand-built pixel lettering for the word mark MAMUTHONES (not a font): each capital is put together
from stems, bars, bowls and bracketed serifs at the pixel size it is drawn at, so stems stay whole
pixels at every height. Used by logo.py for the full logo (tall, arched) and the title block.

    mask = letter("M", 17)          # boolean (h, w) array
    cv = word("MAMUTHONES", [17] * 10)   # finished: cream, red shadow, K0 outline
"""
import numpy as np

from px import Canvas

# Width of each capital as a fraction of its height.
WIDTH = {"M": 1.18, "A": 0.98, "U": 0.86, "T": 0.84, "H": 0.9, "O": 0.94, "N": 0.94, "E": 0.72, "S": 0.72}


def _metrics(h, weight=1.0):
    t = max(3, round(h * 0.19 * weight))       # thick stem
    n = max(1, round(h * 0.085))      # thin stroke
    sh = max(2, round(h * 0.11))      # serif slab height
    sp = max(1, round(h * 0.075))     # serif overhang
    b = max(2, round(h * 0.15))       # bar thickness
    return t, n, sh, sp, b


def letter(ch, h, w=None, weight=1.0, wscale=1.0):
    """A capital as a boolean mask of height h (width from WIDTH unless given); `weight` thickens the
    stems, `wscale` condenses the letter."""
    t, n, sh, sp, b = _metrics(h, weight)
    w = w or max(5, round(h * WIDTH[ch] * wscale))
    cv = Canvas(w, h)
    C = "BONE3"

    def slab(x, y, ww, top):
        # a bracketed serif: the slab, then one pixel of bracket narrowing toward the stem
        cv.rect(x - sp, y if top else y - sh + 1, ww + 2 * sp, sh, C)
        by = y + sh if top else y - sh
        cv.rect(x - max(0, sp - 1), by, ww + 2 * max(0, sp - 1), 1, C)

    if ch == "T":
        cx = w // 2
        cv.rect(0, 0, w, b, C)
        cv.rect(0, b, 1 + sp // 2, max(1, sh - 1), C)
        cv.rect(w - 1 - sp // 2, b, 1 + sp // 2, max(1, sh - 1), C)
        cv.rect(cx - t // 2, 0, t, h, C)
        slab(cx - t // 2, h - 1, t, False)
    elif ch == "H":
        cv.rect(sp, 0, t, h, C)
        cv.rect(w - sp - t, 0, t, h, C)
        for x in (sp, w - sp - t):
            slab(x, 0, t, True)
            slab(x, h - 1, t, False)
        cv.rect(sp, h // 2 - b // 2, w - 2 * sp, b, C)
    elif ch == "E":
        cv.rect(sp, 0, t, h, C)
        slab(sp, 0, t, True)
        slab(sp, h - 1, t, False)
        cv.rect(0, 0, w, b, C)
        cv.rect(0, h - b, w, b, C)
        cv.rect(sp, h // 2 - b // 2, w - sp - max(2, w // 5), b, C)
        # spurs: the arms' ends turn toward the middle
        cv.rect(w - max(1, n + 1), b, max(1, n + 1), sh, C)
        cv.rect(w - max(1, n + 1), h - b - sh, max(1, n + 1), sh, C)
        cv.rect(w - sp - max(2, w // 5) - 1, h // 2 - b // 2 - 1, 1, b + 2, C)
    elif ch == "N":
        cv.rect(sp, 0, n + 1, h, C)
        cv.rect(w - sp - n - 1, 0, n + 1, h, C)
        cv.poly([(sp, 0), (sp + t + 0.5, 0), (w - sp, h), (w - sp - t - 0.5, h)], C)
        slab(sp, h - 1, n + 1, False)
        cv.rect(0, 0, sp + t, sh, C)
        slab(w - sp - n - 1, 0, n + 1, True)
    elif ch == "M":
        cx = w / 2
        cv.rect(sp, 0, n + 1, h, C)
        cv.rect(w - sp - t, 0, t, h, C)
        cv.poly([(sp, 0), (sp + t, 0), (cx + t * 0.45, h), (cx - t * 0.55, h)], C)
        cv.poly([(w - sp - t, 0), (w - sp - t + n + 1, 0), (cx + n * 0.6 + 0.5, h), (cx - n * 0.6 - 0.2, h)], C)
        cv.rect(0, 0, sp + t, sh, C)
        cv.rect(w - sp - t - 1, 0, t + sp + 1, sh, C)
        slab(sp, h - 1, n + 1, False)
        slab(w - sp - t, h - 1, t, False)
    elif ch == "A":
        cx = w / 2
        top = max(2, t - 1)
        cv.poly([(cx - top / 2, 0), (cx + top / 2, 0), (sp + n + 1, h), (sp, h)], C)
        cv.poly([(cx - top / 2, 0), (cx + top / 2 + 0.5, 0), (w - sp, h), (w - sp - t - 0.5, h)], C)
        cy = round(h * 0.6)
        cv.rect(round(cx - (cy / h) * (cx - sp)) + 1, cy, round(2 * (cy / h) * (cx - sp)) - 1, max(2, b - 1), C)
        slab(sp, h - 1, n + 1, False)
        slab(w - sp - t, h - 1, t, False)
    elif ch == "U":
        bowl = round(h * 0.42)
        cv.rect(sp, 0, t, h - bowl // 2, C)
        cv.rect(w - sp - n - 1, 0, n + 1, h - bowl // 2, C)
        outer = cv.m_ellipse(w / 2 + 0.2, h - bowl / 2 - 0.5, (w - 2 * sp) / 2, bowl / 2 + 0.5)
        inner = cv.m_ellipse(w / 2 + 0.6, h - bowl / 2 - 0.5 - n, (w - 2 * sp) / 2 - t + 0.4, bowl / 2 + 0.5 - n - 0.3)
        lower = np.zeros_like(outer)
        lower[h - bowl:, :] = True
        cv._put(outer & ~inner & lower, C)
        slab(sp, 0, t, True)
        slab(w - sp - n - 1, 0, n + 1, True)
    elif ch == "O":
        outer = cv.m_ellipse(w / 2, h / 2, w / 2, h / 2)
        inner = cv.m_ellipse(w / 2, h / 2, w / 2 - t, h / 2 - max(1, n + 0.5))
        cv._put(outer & ~inner, C)
    elif ch == "S":
        # two stacked bowls with a heavy spine, built from ellipse rings, then the terminals
        r_top = h * 0.27
        ring_top = cv.m_ellipse(w / 2, r_top + 0.5, w / 2 - 0.3, r_top + 0.5) & ~cv.m_ellipse(w / 2 + 0.3, r_top + 0.5, w / 2 - t + 0.2, r_top - n + 0.2)
        ring_bot = cv.m_ellipse(w / 2, h - r_top - 0.5 - 0.3, w / 2 - 0.1, r_top + 0.7) & ~cv.m_ellipse(w / 2 - 0.3, h - r_top - 0.8, w / 2 - t, r_top - n + 0.3)
        xx, yy = cv.grid()
        # keep the top bowl's upper-left half and the bottom bowl's lower-right half
        top_keep = ring_top & ((yy + 0.5 < r_top + 0.5) | (xx + 0.5 < w / 2))
        bot_keep = ring_bot & ((yy + 0.5 > h - r_top - 0.8) | (xx + 0.5 > w / 2))
        cv._put(top_keep | bot_keep, C)
        # spine: the diagonal from the top bowl's left to the bottom bowl's right
        cv.poly([(1, r_top), (1 + t, r_top - 0.5), (w - 1, h - r_top - 0.5), (w - 1 - t, h - r_top)], C)
        # terminals: small vertical serifs
        cv.rect(w - 1 - n, 1, n + 1, max(2, round(h * 0.2)), C)
        cv.rect(0, h - 1 - max(2, round(h * 0.2)), n + 1, max(2, round(h * 0.2)), C)
    return cv.solid()


def word(text, heights, gap=1, base="bottom", shadow=(1, 2), speckle=False, seed=3, weight=1.0, wscale=1.0, border=False):
    """Sets the letters side by side (tops aligned for base='top', bottoms for 'bottom', or a list of y
    offsets) and finishes them: a cream face that warms toward its foot, a red drop shadow, and a K0
    outline round everything."""
    masks = [letter(c, hh, weight=weight, wscale=wscale) for c, hh in zip(text, heights)]
    W = sum(m.shape[1] for m in masks) + gap * (len(masks) - 1)
    H = max(heights)
    offs = base if isinstance(base, list) else [0 if base == "top" else H - hh for hh in heights]
    H = max(o + hh for o, hh in zip(offs, heights))
    sx, sy = shadow
    pad = 2
    pad = 3 if border else pad
    cv = Canvas(W + 2 * pad + sx, H + 2 * pad + sy)
    face = np.zeros((cv.h, cv.w), bool)
    x = pad
    rel = np.zeros((cv.h, cv.w))   # 0 at a letter's top, 1 at its foot
    for m, o, hh in zip(masks, offs, heights):
        mh, mw = m.shape
        face[pad + o:pad + o + mh, x:x + mw] |= m
        rel[pad + o:pad + o + mh, x:x + mw] = np.linspace(0, 1, mh)[:, None]
        x += mw + gap
    sh = np.zeros_like(face)
    for i in range(1, max(sx, sy) + 1):
        dx, dy = min(i, sx), min(i, sy)
        sh[dy:, dx:] |= face[:cv.h - dy, :cv.w - dx]
    cv._put(sh & ~face, "RED2")
    # a lighter red on the shadow's upper edge where it leaves the letter
    edge = sh & ~face
    top_edge = edge.copy()
    top_edge[1:, :] &= ~edge[:-1, :]
    cv._put(top_edge, "RED3")
    cv.ramp_fill(face, ["BONE4", "BONE3", "BONE3", "BONE2"], rel * 0.999)
    if speckle:
        rnd = np.random.default_rng(seed)
        r = rnd.random((cv.h, cv.w))
        inner = face.copy()
        inner[1:, :] &= face[:-1, :]
        inner[:-1, :] &= face[1:, :]
        cv._put(inner & (r < 0.05), "BONE2")
        cv._put(inner & (r > 0.985), "STONE5")
    if border:
        # the logo's heavier finish: a red rim all round the letters inside the K0 outline
        cv.outline("RED2")
        cv.recolor("RED2", "RED3", mask=np.roll(face, 1, axis=0) | np.roll(face, 1, axis=1))
    cv.outline("K0")
    return cv
