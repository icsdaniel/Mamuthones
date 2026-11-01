"""Woodcut variants: one factory, several inks, papers and layouts to compare."""
from pxkit import Style
from styles import note_style


def make(name, ink, ink2, paper, paper2, red, blue, gold, keyline=None, night=True,
         carve=(0.7, 0.5, 2), sky_lines=True, grain=None, overrides=None, figs=None, rim=0.6):
    """keyline: outline colour around the figures (None = ink)."""
    fig = Style({
        'fleece':      [ink, ink, ink2, paper2, red if night else paper2],
        'mask':        [ink, ink, ink2, paper],
        'scarf':       [ink, ink, ink2],
        'leather':     [ink2, red, red],
        'bronze':      [ink, gold, gold, paper],
        'bronze_in':   [ink, ink],
        'velvet':      [ink, ink, ink2],
        'boot':        [ink, ink2, paper2],
        'hand':        [ink, ink2, paper2],
        'hole':        [ink],
        'brass_small': [gold, paper, paper],
    }, outline='black', ink=ink)
    notes = note_style('black', ink,
                       [ink, paper2, paper],
                       [ink, blue, ('h', paper, blue)],
                       [ink, red, gold],
                       [ink, gold, paper])
    if night:
        pal = dict(
            sky=[ink, ink], sky_line=ink2, star=paper, star2=paper2, moon=paper,
            wall=[paper2, paper2, paper], wall_line=ink, seam=ink, roof=ink, win_lit=gold, win_dark=ink,
            door=ink, sidewalk=ink2, kerb=paper2,
            cobble=[ink, ink], mortar=ink2,
            fire=[red, red, gold, gold, paper, paper], fire_glow=ink2, log=paper2, log2=ink,
        )
    else:  # a day print: paper sky cut with ink lines, ink walls
        pal = dict(
            sky=[paper, paper], sky_line=paper2, star=paper, star2=paper2, moon=paper,
            cloud=paper, cloud_sh=paper2,
            wall=[ink2, ink2, ink], wall_line=paper2, seam=paper2, roof=ink, roof2=red, win_lit=paper2,
            win_dark=paper2, door=ink, sidewalk=paper2, kerb=ink2,
            cobble=[paper2, paper2], mortar=ink2,
            tower=ink2, tower_sh=ink, tower_open=paper, tower_bell=gold,
        )
    pal.update(dict(
        lane=paper, lane_edge=red,
        ring=paper, ring_hi=paper,
        bell_up=red, bell_up_hi=gold, bell_dn=blue, bell_dn_hi=paper2, bell_arrow=paper, note_ink=ink,
        rope=[ink, gold, paper2],
        panel_bg=ink, btn=[ink, ink2, paper2], btn_face=[paper, paper2], btn_ink=ink, rivet=ink, foot=ink,
        hud_ink=ink, hud_track=ink2, hud_fill=red, plate=paper, plate_hi=paper, plate_lo=paper2,
        hud_text=ink, hud_text_sh=paper2, hud_mult=red, hud_text2=paper2 if night else ink,
        combo=paper if night else ink, combo_sh=ink2 if night else paper2, judge=ink,
    ))
    if not night:
        pal.update(lane=ink, ring=ink, ring_hi=ink2)
    cfg = dict(
        name=name, size=(135, 300), style=fig, note_style=notes, scale=8,
        stars=0.0012 if night else 0, cross_stars=True, sky_lines=sky_lines, fire=night, tower=not night,
        clouds=not night, moon_cut=True, lane_glow=False, courses=True, btn=2, btn_dither=True, ring_w=1.9,
        sparks=14, font_scale=1, judge_scale=1, plate_border=0, fire_w=0.12, fire_h=0.085,
        keyline=keyline, fig_opts=dict(tuft_amp=0.95, bell_cords=False, sym_face=True, face_lines=True, carve=carve, fleece_clamp=0.55 if carve else 0.78, rim=rim),
        figures=figs or [(0.13, 0.50, 48, True), (0.87, 0.575, 70, False)],
        ridges=[(0.02, 0.305, ink2 if night else paper2, 1.0), (0.012, 0.322, ink if night else ink2, 2.5)],
        grain=grain, pal=pal,
    )
    if not night:
        del cfg['pal']['moon']
    cfg.update(overrides or {})
    return cfg


# Round 1 ------------------------------------------------------------------------
INK, INK2, PAPER, PAPER2 = '#17121d', '#2e2534', '#ece0c4', '#b9a784'

R1 = {
    # the draft, with carved fleece and a paper keyline so the Mamuthones stand out
    'w1_night_print': make('w1_night_print', INK, INK2, PAPER, PAPER2, '#e2562c', '#2e7a8a', '#e9a83e',
                           keyline=PAPER2, grain=[(INK, INK2, 0.03)]),
    # three inks only, like a two-block linocut: ink, paper, vermilion (gold kept for bells)
    'w2_lino_red': make('w2_lino_red', '#141014', '#141014', '#efe6d2', '#c9bba0', '#c8352a', '#9a8c74',
                        '#c8352a', keyline='#efe6d2', grain=[('#141014', '#3a2c2c', 0.035), ('#efe6d2', '#c9bba0', 0.05)]),
    # indigo ink on ochre paper, rust and old gold
    'w3_indigo_ochre': make('w3_indigo_ochre', '#1b2140', '#2e3660', '#ecd7a6', '#c2a874', '#b8482a', '#4f8fa8',
                            '#e0a640', keyline='#c2a874', grain=[('#1b2140', '#2e3660', 0.04), ('#ecd7a6', '#c2a874', 0.04)]),
    # mixup with Festa: a day print, paper sky cut with lines, ink town, ink figures on paper
    'w4_day_print': make('w4_day_print', INK, INK2, PAPER, PAPER2, '#d4452c', '#2a62a8', '#e0a03a',
                         night=False, keyline=PAPER, grain=[(PAPER, PAPER2, 0.03)], rim=0.3),
}
