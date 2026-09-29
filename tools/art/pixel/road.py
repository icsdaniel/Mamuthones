"""What comes down the street, drawn from scratch for readability (2026-09-29):

    step      a cast gold plate, a red diamond inlaid in its face: hit it on the beat
    call      a red plate, narrower, a gold diamond inlaid: an off-beat hit (the Issohadore's call)
    heal      a bone-white plate with a flame inlaid: hitting it brings health back
    stomp     a wide, doubly thick plate, fire-hot, two bone thumb prints on it: both thumbs at once
    hold_end  the knot at the end of a hold's rope: a small gold plate
    target    the hit line's slot on each lane: the step plate's own outline, hollow, so a note
              drops into it exactly when it is on time
    badge     the bell bar's medallion (warm gold for raise, cool steel for lower)
    bar       the bell bar across the road: a beam patterned with chevrons pointing the way to tilt,
              warm gold to raise the bells, cool steel to lower them

Every note is a plate seen from above and in front: a flat face (a rounded rectangle), its thickness
below it, a K0 outline. Colour says the kind (gold, red, bone, fire), shape says it too (the call is
narrower, the stomp wider and thicker, the heal carries a flame), so nothing relies on colour alone.
Plates are drawn at every half-width they take on the road (one art pixel apart) so they grow as they
come near while their pixels stay whole.

Used by field.py, which bakes everything into game/art/px/field/ and writes FireCells.
"""
import numpy as np

from px import Canvas

PLATE_P = 3.2          # squareness of the plate's face (2 = an ellipse, higher = squarer)

KINDS = {
    #          face (dark .. light)                side (dark, light)    inlay (dark, mid, light)
    "step": (["GOLD2", "GOLD3", "GOLD4", "GOLD5"], ["GOLD1", "GOLD2"], ["RED1", "RED3", "RED4"]),
    "call": (["RED1", "RED2", "RED3", "RED4"], ["RED0", "RED1"], ["GOLD2", "GOLD4", "GOLD5"]),
    "heal": (["BONE1", "BONE2", "BONE3", "BONE4"], ["BONE0", "BONE1"], ["FIRE3", "FIRE5", "FIRE6"]),
    "stomp": (["FIRE2", "FIRE3", "FIRE4", "FIRE5"], ["RED1", "RED2"], ["BONE2", "BONE3", "BONE4"]),
    "end": (["GOLD2", "GOLD3", "GOLD4", "GOLD5"], ["GOLD1", "GOLD2"], None),
}


def face_ry(rx):
    """The face's half-height for half-width rx: the road is seen from low, so plates are flat."""
    return max(2, int(round(rx * 0.36)))


def depth_of(rx, kind="step"):
    d = max(1, int(round(rx * 0.14)))
    return d * 2 if kind == "stomp" else d


def m_plate(cv, cx, cy, rx, ry, p=PLATE_P):
    xx, yy = cv.grid()
    X = np.abs(xx + 0.5 - cx) / max(rx, 0.01)
    Y = np.abs(yy + 0.5 - cy) / max(ry, 0.01)
    return X ** p + Y ** p < 0.999


def m_diamond(cv, cx, cy, hw, hh):
    xx, yy = cv.grid()
    return np.abs(xx + 0.5 - cx) / max(hw, 0.01) + np.abs(yy + 0.5 - cy) / max(hh, 0.01) <= 1.0


def plate(rx, kind="step"):
    """A plate of half-width rx (art px) of `kind`; returns (canvas, anchor at the face's centre)."""
    face, side, inlay = KINDS[kind]
    if kind == "call":
        rx = max(4, int(round(rx * 0.84)))
    if kind == "stomp":
        rx = int(round(rx * 1.22))
    if kind == "end":
        rx = max(3, int(round(rx * 0.6)))
    ry = face_ry(rx)
    d = depth_of(rx, kind)
    pad = 2
    W = 2 * rx + 2 * pad + 1
    H = 2 * ry + d + 2 * pad + 1
    cv = Canvas(W, H)
    cx = W / 2
    cy = pad + ry + 0.5
    xx, yy = cv.grid()
    # the thickness: the face's shape swept down d px, lit on its upper row
    body = np.zeros((cv.h, cv.w), bool)
    for k in range(d + 1):
        body |= m_plate(cv, cx, cy + k, rx, ry)
    top = m_plate(cv, cx, cy, rx, ry)
    cv._put(body & ~top, side[0])
    if d >= 2:
        lip = body & ~top & m_plate(cv, cx, cy + 1, rx, ry)
        cv._put(lip, side[1])
    # the face, lit from the fire up the road (top) and a little from the left
    ny = (yy + 0.5 - cy) / ry
    nx = (xx + 0.5 - cx) / rx
    v = 0.62 - 0.42 * ny - 0.12 * nx
    cv.ramp_fill(top, face[1:3], np.clip(v, 0, 1), dither=False)
    # the lit upper edge and the shaded lower edge of the face
    up_edge = top & ~m_plate(cv, cx, cy + 1, rx, ry)
    cv._put(up_edge, face[3])
    lo_edge = top & ~m_plate(cv, cx, cy - 1, rx, ry)
    cv._put(lo_edge & (ny > 0.2), face[0])
    if rx >= 11:
        # an engraved border one pixel in from the edge, broken where the light catches it
        ring = m_plate(cv, cx, cy, rx - 2, ry - 1) & ~m_plate(cv, cx, cy, rx - 3, ry - 2)
        cv._put(ring & top & (ny > -0.55), face[0])
        cv._put(ring & top & (ny <= -0.55), face[3])
    # a glint on the upper left
    if rx >= 8:
        gx = int(cx - rx * 0.62)
        gy = int(cy - ry + 1)
        cv.hline(gx, gx + max(1, rx // 6), gy, "BONE4" if kind != "heal" else "STAR1")
    if kind == "stomp":
        _thumbs(cv, cx, cy, rx, ry)
    elif kind == "heal":
        _flame(cv, cx, cy, rx, ry)
    elif inlay is not None:
        _inlay(cv, cx, cy, rx, ry, inlay)
    cv.outline("K0")
    return cv, (int(cx), int(cy))


def _inlay(cv, cx, cy, rx, ry, cols):
    """A diamond set into the face, cut round with K0."""
    if rx < 7:
        cv.rect(int(cx) - 1, int(cy) - 1 + (ry > 2), 2 if rx >= 5 else 1, 1, cols[1])
        return
    hw = max(1.5, rx * 0.26)
    hh = max(1.5, ry * 0.62)
    cyd = cy + 0.25
    cut = m_diamond(cv, cx, cyd, hw + 1.4, hh + 1.1)
    gem = m_diamond(cv, cx, cyd, hw, hh)
    cv._put(cut & ~gem, "K0")
    xx, yy = cv.grid()
    cv._put(gem, cols[1])
    cv._put(gem & (yy + 0.5 > cyd + hh * 0.25), cols[0])
    cv._put(gem & (yy + 0.5 < cyd - hh * 0.2) & (xx + 0.5 < cx + 0.5), cols[2])


def _flame(cv, cx, cy, rx, ry):
    """A small flame set into a heal plate."""
    fw = max(1.5, rx * 0.22)
    fh = max(2.0, ry * 1.5)
    base = cy + ry * 0.55
    xx, yy = cv.grid()
    outer = cv.m_poly([(cx - fw, base), (cx + fw, base), (cx + fw * 0.5, base - fh * 0.6), (cx + 0.2, base - fh)]) | cv.m_ellipse(cx, base - fw * 0.6, fw, fw * 0.8)
    edge = cv.m_poly([(cx - fw - 1.2, base + 1), (cx + fw + 1.2, base + 1), (cx + fw * 0.6 + 1, base - fh * 0.6), (cx + 0.2, base - fh - 1.4)]) | cv.m_ellipse(cx, base - fw * 0.6, fw + 1.2, fw * 0.8 + 1.1)
    cv._put(edge & ~outer, "K0")
    cv._put(outer, "FIRE4")
    inner = cv.m_poly([(cx - fw * 0.45, base), (cx + fw * 0.45, base), (cx + 0.2, base - fh * 0.55)])
    cv._put(inner, "FIRE6")


def _thumbs(cv, cx, cy, rx, ry):
    """Two thumb prints leaning in, one each side of the middle: press with both thumbs."""
    tw = max(1.4, rx * 0.15)
    th = max(1.8, ry * 0.72)
    xx, yy = cv.grid()
    for sx in (-1, 1):
        tx = cx + sx * rx * 0.36
        ty = cy + 0.3
        lean = -sx * 0.32
        X = xx + 0.5 - tx
        Y = yy + 0.5 - ty
        Xs = X - lean * Y
        m = (Xs / tw) ** 2 + (Y / th) ** 2 <= 1.0
        edge = (Xs / (tw + 1.1)) ** 2 + (Y / (th + 1.0)) ** 2 <= 1.0
        cv._put(edge & ~m, "K0")
        cv._put(m, "BONE3")
        cv._put(m & (Y < -th * 0.3), "BONE4")
        if tw >= 3.0:
            r = (Xs / tw) ** 2 + (Y / th) ** 2
            cv._put(m & (np.abs(r - 0.45) < 0.12) & (Y > -th * 0.5), "BONE2")


# --------------------------------------------------------------------------------- the hit line

def target(rx, state="idle"):
    """The slot a step plate lands in on the hit line: the plate's own outline, hollow. States:
    idle (old gold), beat (bright on the beat), lit (a pressed lane: the slot fills with fire),
    miss (dull red for an instant)."""
    ry = face_ry(rx)
    pad = 3
    W = 2 * rx + 2 * pad + 1
    H = 2 * ry + 2 * pad + 2
    cv = Canvas(W, H)
    cx = W / 2
    cy = pad + ry + 0.5
    ramp = {"idle": ("GOLD1", "GOLD3", "GOLD4"),
            "beat": ("GOLD2", "GOLD4", "GOLD5"),
            "lit": ("FIRE3", "FIRE6", "FIRE7"),
            "miss": ("RED0", "RED2", "RED3")}[state]
    outer = m_plate(cv, cx, cy, rx + 1, ry + 1)
    inner = m_plate(cv, cx, cy, rx - 1, ry - 1)
    frame = outer & ~inner
    xx, yy = cv.grid()
    cv._put(frame, ramp[1])
    cv._put(frame & (yy + 0.5 < cy - ry * 0.3), ramp[2])
    cv._put(frame & (yy + 0.5 > cy + ry * 0.45), ramp[0])
    if state == "lit":
        cv._put(inner, "FIRE4")
        cv._put(m_plate(cv, cx, cy, rx * 0.72, ry * 0.6), "FIRE5")
        cv._put(m_plate(cv, cx, cy, rx * 0.4, ry * 0.3), "FIRE7")
    # corner ticks: short marks just outside the slot's ends, so the slot reads even over a busy road
    cv.outline("K0")
    if state != "lit":
        # a K0 lip inside the frame, then the road shows through the hole
        lip = inner & ~m_plate(cv, cx, cy, rx - 2, ry - 2)
        cv._put(lip, "K0")
        cv._put(m_plate(cv, cx, cy, rx - 2, ry - 2), None)
    return cv, (int(cx), int(cy))


# --------------------------------------------------------------------------------- the bell bar

def badge(r, up=True):
    """The bell bar's medallion: a disc in a rim, a bone bell on it, and an arrow the way to tilt
    (raise: warm gold rim on red; lower: steel rim on navy)."""
    W = H = 2 * r + 5
    cv = Canvas(W, H)
    c = W / 2
    rim = ("GOLD3", "GOLD5") if up else ("NIGHT4", "STAR0")
    disc = ("RED2", "RED3") if up else ("NAVY2", "NAVY3")
    cv.ellipse(c, c, r, r, rim[0])
    top = cv.m_ellipse(c, c, r, r) & ~cv.m_ellipse(c, c + 1, r, r)
    cv._put(top, rim[1])
    cv.ellipse(c, c + 0.3, r - 1.6, r - 1.6, disc[0])
    cv.ellipse(c, c - 0.2, r - 2.2, r - 2.2, disc[1])
    # the bell, shifted the way to tilt
    bw = max(2, r * 0.5)
    bh = max(3, r * 0.82)
    off = -r * 0.1 if up else r * 0.1
    top_y = c - bh * 0.55 + off
    cv.poly([(c - bw * 0.42, top_y + bh * 0.25), (c + bw * 0.42, top_y + bh * 0.25), (c + bw * 0.62, top_y + bh), (c - bw * 0.62, top_y + bh)], "BONE4")
    cv.ellipse(c, top_y + bh * 0.28, bw * 0.42, bh * 0.3, "BONE4")
    cv.hline(int(c - bw * 0.62), int(c + bw * 0.62), int(top_y + bh), "BONE2")
    cv.outline("K0")
    return cv, (int(c), int(c))


def bar_tile(h, up):
    """One repeat of the bell bar's beam, h px tall: a beam with a chevron pointing the way to tilt.
    Raise: a warm gold beam with dark chevrons pointing up. Lower: a cool steel beam with pale
    chevrons pointing down. K0 above and below; the game tiles it across the road."""
    W = max(6, h + 1)
    cv = Canvas(W, h + 2)
    if up:
        base, hi, lo, chev = "GOLD4", "GOLD5", "GOLD3", "GOLD1"
    else:
        base, hi, lo, chev = "NIGHT4", "NIGHT5", "NIGHT3", "STAR1"
    cv.rect(0, 1, W, h, base)
    cv.hline(0, W - 1, 1, hi)
    cv.hline(0, W - 1, h, lo)
    if h >= 9:
        cv.hline(0, W - 1, h - 1, lo)
    cv.hline(0, W - 1, 0, "K0")
    cv.hline(0, W - 1, h + 1, "K0")
    # the chevron, centred in the tile: a V (or an inverted V) two rows thick when there is room
    th = 2 if h >= 10 else 1
    s = max(1, min((W - 3) // 2, (h - 2 - th) // 1 - 1))
    s = max(1, min(s, (h - 1 - th)))
    span = s + th                     # rows the chevron covers
    y0 = 1 + (h - span) // 2 + (1 if (h - span) % 2 else 0)
    cx = (W - 1) // 2
    for i in range(-s, s + 1):
        dy = abs(i) if up else s - abs(i)
        for t in range(th):
            cv.pset(cx + i, y0 + dy + t, chev)
    return cv


def bar_end(h, up):
    """The bar's end: a square cap with a stud (it sits on the road's kerb)."""
    W = max(4, h // 2 + 2)
    cv = Canvas(W, h + 2)
    base, hi, lo = ("GOLD3", "GOLD5", "GOLD2") if up else ("NIGHT3", "STAR0", "NIGHT2")
    cv.rect(0, 1, W - 1, h, base)
    cv.hline(0, W - 2, 1, hi)
    cv.hline(0, W - 2, h, lo)
    cv.vline(0, 0, h + 1, "K0")
    cv.vline(W - 1, 0, h + 1, "K0")
    cv.hline(0, W - 1, 0, "K0")
    cv.hline(0, W - 1, h + 1, "K0")
    cv.pset(W // 2, (h + 2) // 2, hi)
    return cv
