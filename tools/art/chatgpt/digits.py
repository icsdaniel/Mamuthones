"""The number font from Daniele's ChatGPT sheet (tools/art/sources/chatgpt/digits.png) as three bitmap
faces for the HUD:

    python3 tools/art/chatgpt/digits.py

Row 1 (small gold), row 2 (big gold) and row 3 (small white) of the sheet each give the figures
0-9, comma, dot and x. Each glyph is keyed off the magenta, put on the art grid, snapped to the style
palette and packed into game/art/px/field/font_num_{gold,big,white}.png with a BMFont text file
(.fnt) beside it, one font px per art px (PxType sets them at whole multiples).
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage
import common as c

OUT = os.path.join(c.GAME, "art/px/field")
CHARS = "0123456789,.x"
ROWS = {"gold": (75, 205, 7.3), "big": (255, 467, 7.3), "white": (525, 655, 7.3)}


def glyphs(sheet, t, b, f):
    k = c.keyed(sheet[t:b])
    on = k[..., 3] > 0
    cols = on.any(0)
    # runs of columns with ink: one per glyph (a gap of at least 2 art px between them)
    lab, n = ndimage.label(cols)
    runs = [np.nonzero(lab == i)[0] for i in range(1, n + 1)]
    runs = [r for r in runs if r.size > f * 1.5 or on[:, r].sum() > f * f * 4]
    out = []
    rows = on.any(1)
    ys = np.nonzero(rows)[0]
    y0, y1 = ys.min(), ys.max() + 1
    for r in runs:
        g = k[y0:y1, r.min():r.max() + 1]
        gg = c.snap(c.grid(g, f))
        out.append(gg)
    return out


def main():
    sheet = c.load(c.src("digits.png"))
    for face, (t, b, f) in ROWS.items():
        gs = glyphs(sheet, t, b, f)
        assert len(gs) == len(CHARS), (face, len(gs))
        h = max(g.shape[0] for g in gs)
        pad = 1
        W = sum(g.shape[1] + pad for g in gs) + pad
        atlas = np.zeros((h + 2 * pad, W, 4), np.uint8)
        x = pad
        lines = []
        base = h
        for ch, g in zip(CHARS, gs):
            gh, gw = g.shape[:2]
            # the comma and dot sit on the baseline: their bottom is the row's bottom in the sheet
            atlas[pad:pad + gh, x:x + gw] = g
            yo = 0
            lines.append('char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=%d xadvance=%d page=0 chnl=15'
                % (ord(ch), x, pad, gw, gh, yo, gw))
            x += gw + pad
        name = "font_num_" + face
        Image.fromarray(atlas).save(os.path.join(OUT, name + ".png"))
        space = max(2, gs[0].shape[1] // 2)
        fnt = ['info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0' % (name, h),
            'common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0' % (h + 1, base, W, h + 2 * pad),
            'page id=0 file="%s.png"' % name, 'chars count=%d' % (len(CHARS) + 1),
            'char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15' % space] + lines
        open(os.path.join(OUT, name + ".fnt"), "w").write("\n".join(fnt) + "\n")
        print(name, atlas.shape[:2], "glyph height", h)


if __name__ == "__main__":
    main()
