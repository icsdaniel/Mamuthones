"""Export one woodcut round: stills, animated play screens, bob GIFs, a side-by-side."""
import os, sys, numpy as np
from PIL import Image
from pxkit import to_img, hexc
import figure, render, woodcut

rnd = sys.argv[1]                     # e.g. R1
OUT = sys.argv[2]
page = sys.argv[3] if len(sys.argv) > 3 else None
sets = getattr(woodcut, rnd)
os.makedirs(OUT, exist_ok=True)
tiles = []
for k, cfg in sets.items():
    d = os.path.join(OUT, k); os.makedirs(os.path.join(d, 'parts'), exist_ok=True)
    img = render.still(cfg, 0.6, 0)
    to_img(img, 1).save(f'{d}/play_1x.png')
    to_img(img, 8).save(f'{d}/play_1080x2400.png')
    render.gif(cfg, f'{d}/play_animated.gif', 3)
    tiles.append(to_img(img, 4))
    H = cfg['figures'][-1][2]
    st = cfg['style']
    f, parts = figure.build(st, H, cfg.get('fig_opts'))
    rp = figure.render_parts(f, parts, st)
    for pk, arr in rp.items():
        to_img(arr, 1).save(f'{d}/parts/{pk}.png')
    kl = np.array(hexc(cfg['keyline']), np.uint8) if cfg.get('keyline') else None
    frames = [figure.compose(f, rp, i, kl) for i in range(4)]
    to_img(np.concatenate(frames, axis=1), 1).save(f'{d}/mamuthone_sheet.png')
    bg = tuple(int(cfg['pal']['sky'][0][i:i + 2], 16) for i in (1, 3, 5)) + (255,)
    g = []
    for a in frames:
        b = np.zeros_like(a); b[...] = bg
        g.append(to_img(np.where(a[..., 3:4] > 0, a, b), 4).convert('RGB'))
    g[0].save(f'{d}/mamuthone_bob.gif', save_all=True, append_images=g[1:], duration=figure.BOB_TIMES_MS, loop=0)
    if page:
        import shutil
        for src, dst in (('play_animated.gif', 'play.gif'), ('mamuthone_bob.gif', 'bob.gif')):
            shutil.copy(f'{d}/{src}', f'{page}/{rnd.lower()}_{k}_{dst}')
    print(k)
c = Image.new('RGB', (len(tiles) * 550 - 10, 1200), (40, 40, 40))
for i, t in enumerate(tiles):
    c.paste(t, (i * 550, 0))
c.save(f'{OUT}/compare.png')
if page:
    c.save(f'{page}/{rnd.lower()}_compare.png')
