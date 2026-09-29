"""The pictures of the setup screens in pixel art (docs/art-style.md): the headphones with a cowbell,
the phone held in two hands (tilt frames, thumbs up or pressed), and the frame drum (hit frames).

    python3 tools/art/pixel/setup_pics.py [--preview DIR]

Writes game/art/px/setup/ and game/scripts/art/setup_cells.gd (read by SetupArt).
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import figures  # noqa: E402
from px import Canvas  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../game"))
OUT = os.path.join(ROOT, "art/px/setup")

TILTS = [-0.9, -0.675, -0.45, -0.225, 0.0, 0.225, 0.45, 0.675, 0.9]
DRUM_FRAMES = 4


def lerp(a, b, t):
    return a + (b - a) * t


# ---------------------------------------------------------------------------------------------------
# Headphones
# ---------------------------------------------------------------------------------------------------

def headphones():
    W, H = 128, 104
    cv = Canvas(W, H)
    xx, yy = cv.grid()
    cx, cy = 64, 62
    # the headband: a thick arc over the top, dark navy with a lit top edge, a stitched leather pad
    r = np.hypot(xx + 0.5 - cx, yy + 0.5 - cy)
    ang = np.degrees(np.arctan2(yy + 0.5 - cy, xx + 0.5 - cx))
    band = (r >= 36) & (r <= 43) & (yy + 0.5 < cy + 2)
    cv._put(band, "NAVY2")
    cv._put(band & (r > 41.5), "NAVY3")
    cv._put(band & (r < 37.5), "NAVY1")
    cv._put(band & (r > 41.5) & (xx > cx + 8) & (xx < cx + 30), "BONE0")
    pad = (r >= 37) & (r <= 42) & (ang > -125) & (ang < -55)
    cv._put(pad, "LEATHER1")
    cv._put(pad & (r > 40.5), "LEATHER2")
    cv._put(pad & (r > 41.2) & (xx > cx), "LEATHER3")
    stitch = pad & (np.abs(r - 39) < 0.5) & ((xx % 3) == 0)
    cv._put(stitch, "LEATHER3")
    # sliders from the band down to the cups
    for sx in (cx - 40, cx + 39):
        cv.rect(sx - 1, cy - 2, 3, 10, "GOLD2")
        cv.vline(sx + 1, cy - 2, cy + 7, "GOLD4")
        cv.pset(sx - 1, cy + 2, "GOLD1")
    # the cups: bronze-rimmed, dark shells, lit from the right
    for (ux, flip) in ((cx - 40, -1), (cx + 40, 1)):
        m = cv.shade_ellipse(ux, cy + 18, 13, 17, ["NAVY0", "NAVY1", "NAVY2", "NAVY3"], light=(0.6, -0.6))
        ring = m & ~cv.m_ellipse(ux, cy + 18, 11, 15)
        cv._put(ring, "GOLD2")
        cv._put(ring & (xx + 0.5 > ux + 3), "GOLD3")
        cv._put(ring & (xx + 0.5 > ux + 7) & (yy + 0.5 < cy + 14), "GOLD4")
        boss = cv.m_ellipse(ux, cy + 18, 4, 5)
        cv._put(boss, "GOLD2")
        cv.pset(ux + 1, cy + 16, "GOLD5")
        cv.pset(ux + 2, cy + 17, "GOLD4")
        # the cushion showing at the inner side
        cush = cv.m_ellipse(ux - flip * 11, cy + 18, 4, 14) & ~m
        cv._put(cush, "FLEECE2")
        cv._put(cush & (yy % 3 == 0), "FLEECE3")
    # a small cowbell hanging on a thong from the top of the band
    cv.line(cx, cy - 42, cx + 1, cy - 30, "LEATHER2")
    cv.outline("K0")
    b, (hx, hy) = figures.bell("xl")
    cv.blit(b, cx + 1 - hx, cy - 30 - hy)
    # sound: three stepped arcs out of each cup, gold near, ember further
    for (ux, d) in ((cx - 40, -1), (cx + 40, 1)):
        for i, (rad, col) in enumerate(((20, "GOLD4"), (26, "FIRE4"), (32, "FIRE3"))):
            for a in range(-34, 35, 3):
                t = math.radians(a)
                px_ = ux + d * rad * math.cos(t)
                py_ = cy + 18 + rad * math.sin(t)
                if (a // 3 + i) % 3 == 2:
                    continue
                cv.pset(px_, py_, col)
    return cv


# ---------------------------------------------------------------------------------------------------
# Phone in two hands
# ---------------------------------------------------------------------------------------------------

PW, PH = 136, 150
BOT = 124          # the phone's bottom edge (y)
BASE_W = 60        # its width at the bottom


def phone_quad(t):
    """The phone's corners (tl, tr, br, bl) at tilt t: the top edge swings toward (t > 0: wider, the face
    foreshortened) or away (narrower)."""
    h = 96 * math.cos(t * 0.95)
    top_w = BASE_W * (1 + 0.28 * math.sin(t))
    cx = PW / 2
    ty = BOT - h
    return [(cx - top_w / 2, ty), (cx + top_w / 2, ty), (cx + BASE_W / 2, BOT), (cx - BASE_W / 2, BOT)]


def quad_point(q, u, v):
    """Bilinear point in quad q at (u, v) in 0..1 (u across, v down)."""
    tl, tr, br, bl = q
    top = (lerp(tl[0], tr[0], u), lerp(tl[1], tr[1], u))
    bot = (lerp(bl[0], br[0], u), lerp(bl[1], br[1], u))
    return (lerp(top[0], bot[0], v), lerp(top[1], bot[1], v))


def inset(q, du, dv_top, dv_bot):
    return [quad_point(q, du, dv_top), quad_point(q, 1 - du, dv_top), quad_point(q, 1 - du, 1 - dv_bot), quad_point(q, du, 1 - dv_bot)]


def phone(t, left, right):
    cv = Canvas(PW, PH)
    xx, yy = cv.grid()
    q = phone_quad(t)
    # sleeves and the backs of the hands behind the phone: fingers curl round both sides
    for side in (-1, 1):
        bx = PW / 2 + side * (BASE_W / 2 + 4)
        cv.poly([(bx - 12, PH), (bx + 12, PH), (bx + 10 * side + 6, BOT - 6), (bx - 6 + 10 * side, BOT - 10)], "NAVY2")
        for k in range(3):
            fy = lerp(q[1][1] if side > 0 else q[0][1], BOT, 0.42 + k * 0.15)
            ex = lerp(q[1][0] if side > 0 else q[0][0], q[2][0] if side > 0 else q[3][0], 0.42 + k * 0.15)
            cv.ellipse(ex + side * 2, fy, 4.5, 3.5, "SKIN1")
            cv.pset(ex + side * 3, fy - 2, "SKIN2" if side > 0 else "SKIN1")
    cv.outline("K0")
    # the phone: bezel and screen
    body = cv.m_poly(q)
    cv._put(body, "K1")
    scr = inset(q, 0.07, 0.06, 0.1)
    sm = cv.m_poly(scr)
    cv._put(sm, "NAVY1")
    # the game on the screen: three lanes, the gold hit line, a note on its way
    for u0 in (0.33, 0.66):
        for v in np.linspace(0.02, 0.98, 60):
            p = quad_point(scr, u0, v)
            cv.pset(p[0], p[1], "NAVY2")
    for u in np.linspace(0.02, 0.98, 60):
        p = quad_point(scr, u, 0.8)
        cv.pset(p[0], p[1], "GOLD4")
    for (u, v, col) in ((0.5, 0.45, "FIRE4"), (0.17, 0.2, "GOLD3"), (0.83, 0.62, "FIRE4")):
        a = quad_point(scr, u - 0.08, v)
        b = quad_point(scr, u + 0.08, v + 0.05)
        cv.rect(a[0], a[1], max(2, b[0] - a[0]), max(1, b[1] - a[1]), col)
    # a glint on the glass, up the right side
    for v in np.linspace(0.05, 0.4, 20):
        p = quad_point(scr, 0.86 - v * 0.3, v)
        cv.pset(p[0], p[1], "NAVY3")
    # the phone's top edge: seen as a thin lit strip when tilted toward you
    if t > 0.1:
        cv.line(q[0][0], q[0][1], q[1][0], q[1][1], "SETT4")
    # palms and cuffs in front of the lower corners, and the thumbs
    for side, pressed in ((-1, left), (1, right)):
        corner = q[2] if side > 0 else q[3]
        c0 = corner[0]
        # the sleeve cuff, then the palm wrapped round the phone's lower corner (a mitten shape)
        cv.poly([(c0 - side * 4, PH), (c0 + side * 20, PH), (c0 + side * 18, BOT + 16), (c0 - side * 6, BOT + 18)], "NAVY2")
        cv.line(c0 - side * 6, BOT + 18, c0 + side * 18, BOT + 16, "NAVY3")
        palm = cv.m_poly([(c0 - side * 3, BOT - 9), (c0 + side * 9, BOT - 7), (c0 + side * 16, BOT + 4), (c0 + side * 16, BOT + 16),
                          (c0 - side * 7, BOT + 18), (c0 - side * 9, BOT + 6)])
        cv._put(palm, "SKIN1")
        lit = palm & (((xx + 0.5 - c0) * side > 6) if side > 0 else ((yy + 0.5) < BOT - 2))
        cv._put(lit, "SKIN2")
        # the thumb: a thick capsule from the palm to its tip over the screen's lower corner
        tip = quad_point(scr, 0.5 + side * 0.24, 0.87)
        base = (c0 - side * 1, BOT + 2)
        lift = 0 if pressed else 6
        tip = (tip[0], tip[1] - lift)
        if not pressed:
            cv.ellipse(tip[0] - 2, tip[1] + lift + 2, 4, 2, "NAVY0")  # its shadow on the glass
        n = 12
        for k in range(n + 1):
            u = k / n
            x = lerp(base[0], tip[0], u)
            y = lerp(base[1], tip[1], u)
            cv.ellipse(x, y, 4.2 - 0.8 * u, 3.6 - 0.6 * u, "SKIN1")
        for k in range(n + 1):
            u = k / n
            x = lerp(base[0], tip[0], u)
            y = lerp(base[1], tip[1], u)
            cv.pset(x + 1, y - 2, "SKIN2")
        # the nail
        cv.rect(tip[0] - 1, tip[1] - 2, 3, 2, "BONE2")
        cv.pset(tip[0] + 1, tip[1] - 2, "BONE3")
        if pressed:
            for a in range(0, 360, 24):
                cv.pset(tip[0] + 8 * math.cos(math.radians(a)), tip[1] + 5 * math.sin(math.radians(a)), "FIRE4")
    cv.outline("K0")
    return cv, scr


def screen_mask(scr):
    cv = Canvas(PW, PH)
    cv._put(cv.m_poly(scr), "FIRE3")
    return cv


def arrow(direction):
    """A carved gold arrow curving over the top of the phone: 1 = tilt the top toward you (it bends down
    toward the viewer), -1 = away."""
    cv = Canvas(64, 30)
    pts = []
    for i in range(21):
        u = i / 20
        x = 8 + u * 44
        y = 22 - math.sin(u * math.pi) * 14
        pts.append((x, y))
    if direction < 0:
        pts = pts[::-1]
    cv.curve(pts, "GOLD3", w=3)
    cv.curve([(x, y - 1) for (x, y) in pts], "GOLD4", w=1)
    ex, ey = pts[-1]
    d = 1 if direction > 0 else -1
    cv.poly([(ex - 5 * d, ey - 7), (ex + 3 * d, ey + 1), (ex - 7 * d, ey + 3)], "GOLD4")
    cv.outline("K0")
    return cv


# ---------------------------------------------------------------------------------------------------
# Frame drum (tumbarinu)
# ---------------------------------------------------------------------------------------------------

def drum(hit):
    W, H = 132, 116
    cv = Canvas(W, H)
    xx, yy = cv.grid()
    cx, cy, rx, ry = 64, 50, 48, 30
    depth = 16
    swell = hit * 2
    # the shell: a wooden band below the head, laced with hemp in a zigzag
    shell = cv.m_rect(cx - rx, cy, rx * 2 + 1, depth) | cv.m_ellipse(cx, cy + depth, rx, ry)
    cv._put(shell, "WOOD1")
    nx = (xx + 0.5 - cx) / rx
    cv._put(shell & (nx > 0.2), "WOOD2")
    cv._put(shell & (nx > 0.7), "WOOD3")
    cv._put(shell & (nx < -0.6), "WOOD0")
    for i in range(-8, 9):
        u0 = i / 8.6
        x0 = cx + u0 * rx
        y0 = cy + ry * math.sqrt(max(0, 1 - u0 * u0))
        u1 = (i + 0.5) / 8.6
        x1 = cx + u1 * rx
        y1 = cy + depth + ry * math.sqrt(max(0, 1 - min(1, u1 * u1))) - 2
        cv.line(x0, y0 + 1, x1, y1, "ROPE1" if u0 > 0 else "ROPE0")
    # the head: the skin, lit from the right; on a hit it swells and warms at the centre
    head = cv.m_ellipse(cx, cy - swell * 0.5, rx, ry + swell * 0.3)
    d = np.hypot((xx + 0.5 - cx) / rx, (yy + 0.5 - cy) / ry)
    val = np.clip(0.55 + 0.35 * nx - 0.25 * d, 0, 0.999)
    cv.ramp_fill(head, ["BONE1", "BONE2", "BONE3"], val)
    # the carved rim round the head
    rim = head & ~cv.m_ellipse(cx, cy - swell * 0.5, rx - 3, ry - 2 + swell * 0.3)
    cv._put(rim, "WOOD2")
    cv._put(rim & (nx > 0.3) & (yy < cy), "WOOD3")
    cv._put(rim & (nx > 0.6) & (yy < cy - ry * 0.4), "WOOD4")
    if hit > 0:
        glow = head & ~rim & (d < 0.25 + 0.35 * hit)
        cv._put(glow, "FIRE6" if hit > 0.6 else "BONE4")
        cv._put(head & ~rim & (d < 0.12 + 0.2 * hit), "FIRE5" if hit > 0.6 else "FIRE6")
        # ripples on the skin
        for rr in (0.45, 0.7):
            ring = head & ~rim & (np.abs(d - rr * (0.8 + 0.3 * hit)) < 0.03)
            cv._put(ring & ((xx + yy) % 2 == 0), "FIRE4" if hit > 0.5 else "BONE1")
    # the stick resting across the front
    cv.line(cx + 30, cy + depth + ry - 2, cx + 58, cy - 4, "WOOD2", w=2)
    cv.line(cx + 30, cy + depth + ry - 3, cx + 58, cy - 5, "WOOD3")
    cv.ellipse(cx + 58, cy - 5, 2.5, 2.5, "WOOD3")
    cv.outline("K0")
    # ember gouges springing out round the rim on a strong hit
    if hit > 0.3:
        n = 14
        for i in range(n):
            a = 2 * math.pi * i / n + 0.2
            r0 = 1.12
            r1 = 1.12 + 0.18 * hit
            for s in np.linspace(r0, r1, 5):
                cv.pset(cx + rx * s * math.cos(a), cy + ry * s * math.sin(a), "FIRE5" if s < (r0 + r1) / 2 else "FIRE3")
    return cv


def thumb(pressed):
    """A thumb coming up from below onto a button, tip at the top, lit from the right: raised (round
    tip, a lit nail) or pressed (the tip flattened and widened on the button)."""
    W, H = 16, 34
    cv = Canvas(W, H)
    tip_y = 4 if not pressed else 6
    for y in range(tip_y, H):
        u = (y - tip_y) / (H - tip_y)
        half = 4.2 + 1.8 * u if not pressed else 5.0 + 1.2 * u
        if y < tip_y + 3:
            half -= (tip_y + 3 - y) * (1.2 if not pressed else 0.6)
        x0 = W / 2 - half
        x1 = W / 2 + half
        for x in range(int(round(x0)), int(round(x1))):
            f = (x + 0.5 - x0) / max(1, x1 - x0)
            cv.pset(x, y, "SKIN0" if f < 0.22 else ("SKIN1" if f < 0.7 else "SKIN2"))
    # the nail, on the back of the thumb near the tip
    ny = tip_y + (2 if not pressed else 1)
    cv.rect(W / 2 - 2, ny, 4, 4 if not pressed else 3, "BONE2")
    cv.pset(W / 2 + 1, ny, "BONE3")
    cv.hline(int(W / 2 - 2), int(W / 2 + 1), ny + (3 if not pressed else 2), "SKIN0")
    # a knuckle crease
    cv.hline(int(W / 2 - 3), int(W / 2 + 2), 16, "SKIN0")
    cv.outline("K0")
    return cv


def main():
    prev = None
    if "--preview" in sys.argv:
        prev = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(prev, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    hp = headphones()
    hp.save(os.path.join(OUT, "headphones.png"))
    phones = []
    for i, t in enumerate(TILTS):
        for l in (0, 1):
            for r in (0, 1):
                cv, scr = phone(t, l, r)
                cv.save(os.path.join(OUT, f"phone_{i}_{l}{r}.png"))
                if l == 0 and r == 0:
                    phones.append(cv)
        screen_mask(scr).save(os.path.join(OUT, f"phone_screen_{i}.png"))
    arrow(1).save(os.path.join(OUT, "arrow_toward.png"))
    arrow(-1).save(os.path.join(OUT, "arrow_away.png"))
    thumb(False).save(os.path.join(OUT, "thumb_up.png"))
    thumb(True).save(os.path.join(OUT, "thumb_down.png"))
    drums = []
    for k in range(DRUM_FRAMES):
        d = drum(k / (DRUM_FRAMES - 1))
        d.save(os.path.join(OUT, f"drum_{k}.png"))
        drums.append(d)
    gd = f'''class_name SetupCells
extends RefCounted
## Generated by tools/art/pixel/setup_pics.py - do not edit.
const DIR := "res://art/px/setup/"
const TILTS: Array[float] = {TILTS}
const DRUM_FRAMES := {DRUM_FRAMES}
const HEADPHONES := Vector2i({hp.w}, {hp.h})
const PHONE := Vector2i({PW}, {PH})
const DRUM := Vector2i({drums[0].w}, {drums[0].h})
const ARROW := Vector2i(64, 30)
## thumb_up / thumb_down: a thumb coming up from below, tip at the top centre.
const THUMB := Vector2i(16, 34)
'''
    with open(os.path.join(ROOT, "scripts/art/setup_cells.gd"), "w") as f:
        f.write(gd)
    if prev:
        from PIL import Image
        sheet = Image.new("RGBA", (PW * 5, PH * 2 + 120), (18, 20, 42, 255))
        for i, p in enumerate(phones[::2]):
            sheet.alpha_composite(p.image(), (i * PW, 0))
        pr, _ = phone(0.3, 1, 0)
        sheet.alpha_composite(pr.image(), (0, PH))
        sheet.alpha_composite(hp.image(), (PW, PH))
        for k, d in enumerate(drums[1:]):
            sheet.alpha_composite(d.image(), (PW * (2 + k), PH))
        sheet.alpha_composite(arrow(1).image(), (0, PH * 2 + 10))
        sheet = sheet.resize((sheet.width * 2, sheet.height * 2), 0)
        sheet.save(os.path.join(prev, "setup_sheet.png"))
    print("setup pictures written to", OUT)


if __name__ == "__main__":
    main()
