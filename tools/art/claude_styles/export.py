"""Build every draft: play screens (still + animated), Mamuthone sheets and parts."""
import json, os, sys
import numpy as np
from PIL import Image
from pxkit import to_img
import figure, render, scene, styles

OUT = sys.argv[1] if len(sys.argv) > 1 else '/mnt/project-files/pixel-styles'
SETS = [('ember', styles.EMBER_CFG, 4, 6), ('woodcut', styles.WOODCUT_CFG, 3, 4), ('festa', styles.FESTA_CFG, 2, 3)]

for name, cfg, gscale, fscale in SETS:
    d = os.path.join(OUT, name)
    os.makedirs(os.path.join(d, 'parts'), exist_ok=True)
    img = render.still(cfg, 0.6, 0)
    to_img(img, 1).save(f'{d}/play_1x.png')
    to_img(img, cfg['scale']).save(f'{d}/play_1080x2400.png')
    render.gif(cfg, f'{d}/play_animated.gif', gscale)
    # the Mamuthone: main size used on the play screen
    H = cfg['figures'][-1][2]
    f, parts = figure.build(cfg['style'], H, cfg.get('fig_opts'))
    rp = figure.render_parts(f, parts, cfg['style'])
    for k, arr in rp.items():
        to_img(arr, 1).save(f'{d}/parts/{k}.png')
    frames = [figure.compose(f, rp, i) for i in range(4)]
    sheet = np.concatenate(frames, axis=1)
    to_img(sheet, 1).save(f'{d}/mamuthone_sheet.png')
    to_img(sheet, fscale).save(f'{d}/mamuthone_sheet_x{fscale}.png')
    bg = {'ember': (38, 28, 46), 'woodcut': (236, 224, 196), 'festa': (166, 205, 234)}[name]
    gif = []
    for fi, ms in zip([0, 1, 2, 3], figure.BOB_TIMES_MS):
        a = frames[fi]
        b = np.zeros_like(a); b[...] = bg + (255,)
        gif.append(to_img(np.where(a[..., 3:4] > 0, a, b), fscale).convert('RGB'))
    gif[0].save(f'{d}/mamuthone_bob.gif', save_all=True, append_images=gif[1:],
                duration=figure.BOB_TIMES_MS, loop=0)
    meta = {
        'style': name, 'canvas': [f.W, f.CH], 'figure_height_px': H,
        'draw_order': figure.PART_ORDER,
        'frames_ms': figure.BOB_TIMES_MS,
        'frame_names': ['rest', 'snap down', 'low (bells land)', 'return'],
        'offsets_px': {k: [int(round(v * H)) for v in figure.BOB[k]] for k in figure.PART_ORDER},
        'note': 'Each part PNG shares one canvas; draw in order, shifted down by offsets_px[part][frame].',
    }
    json.dump(meta, open(f'{d}/mamuthone.json', 'w'), indent=1)
    print(name, 'done')

# side-by-side comparison at the same on-screen size
ims = [Image.open(f'{OUT}/{n}/play_1080x2400.png').resize((540, 1200), Image.NEAREST) for n, *_ in SETS]
c = Image.new('RGB', (540 * 3 + 40, 1200), (20, 16, 24))
for i, im in enumerate(ims):
    c.paste(im, (i * 560, 0))
c.save(f'{OUT}/compare_play.png')
figs = []
for n, cfg, g, fs in SETS:
    a = np.array(Image.open(f'{OUT}/{n}/mamuthone_sheet.png'))
    figs.append((n, a))
