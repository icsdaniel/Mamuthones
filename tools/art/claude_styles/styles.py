from pxkit import Style

# A - "Ember": chunky 16-bit-era sprite, 3-step ramps, hard black outline.
EMBER = Style({
    'fleece':      ['#110b0e', '#21151a', '#382420', '#573a28', '#c06a2c'],
    'mask':        ['#0c0708', '#1e1214', '#3a2420', '#8a5a34'],
    'scarf':       ['#2e1c16', '#57361f', '#7f522c'],
    'leather':     ['#552a16', '#8f4f24', '#c97f38'],
    'bronze':      ['#5e3f16', '#a87828', '#e6b84c', '#fff0a0'],
    'bronze_in':   ['#140b0a', '#2f1d12'],
    'velvet':      ['#141220', '#262238', '#383052'],
    'boot':        ['#160f0e', '#33201a', '#54361f'],
    'hand':        ['#24150f', '#422a1c', '#63402a'],
    'hole':        ['#080508'],
    'brass_small': ['#a87828', '#e6b84c', '#fff0a0'],
}, outline='black', ink='#0b070c', dither=0.0)


def note_style(outline, ink, q, e, o, h, dither=0.0):
    r = {}
    for k, ramp in (('note_q', q), ('note_e', e), ('note_o', o), ('note_h', h)):
        r[k] = ramp
        r[k + '_side'] = ramp[:2] if not isinstance(ramp[0], tuple) else ramp[:2]
    return Style(r, outline=outline, ink=ink, dither=dither)


EMBER_NOTES = note_style('black', '#0b070c',
                         ['#5e3f16', '#a87828', '#e6b84c', '#fff0a0'],
                         ['#16204a', '#2a4aa0', '#4a86e0', '#a8d8ff'],
                         ['#2a1640', '#5a2a8a', '#9050c8', '#d8a8ff'],
                         ['#4a2010', '#8a4020', '#d07a3a', '#ffc080'])

EMBER_CFG = dict(
    name='ember', size=(90, 200), style=EMBER, note_style=EMBER_NOTES, scale=12,
    stars=0.004, fire=True, lane_glow=True, wide_edge=True, courses=True, btn=2, btn_planks=True, rivets=True,
    ring_w=1.9, sparks=10, ring_cord=False, font_scale=1, judge_scale=1,
    figures=[(0.13, 0.50, 32, True), (0.87, 0.575, 46, False)],
    ridges=[(0.022, 0.305, '#1d1631', 1.0), (0.012, 0.322, '#130e21', 2.5)],
    pal=dict(
        sky=['#0c0a1b', '#121027', '#1a1534', '#241a40', '#331f45', '#45264a'],
        star='#f4e3b0', star2='#7d6f9e',
        wall=['#1c1420', '#271a26', '#36202a', '#4c2a2c', '#6a382c', '#8a4a30'],
        wall_line='#110b15', seam='#0b080e', roof='#09070c', win_lit='#f0a040', win_dark='#100c19',
        door='#0e090f', sidewalk='#1b141f', kerb='#2a1d26',
        cobble=['#1c1626', '#221b2e', '#2a2034'], mortar='#110d18',
        fire=['#5a1a10', '#a3301a', '#e0602a', '#f6a23c', '#ffe08a', '#fff8e0'], fire_glow='#3c1f1c',
        log='#3a1e12', log2='#140a08',
        lane='#e07a2a', lane_edge='#ffb04a', lane_glow='#5a2a18', lane_glow2='#2e1a1e',
        ring='#e6a848', ring_hi='#fff0b0',
        bell_up='#c22c26', bell_up_hi='#f06a4a', bell_dn='#2440a8', bell_dn_hi='#4a86e0', bell_arrow='#fff0d0', note_ink='#0b070c',
        rope=['#4a2e14', '#c89040', '#8a5a24'],
        panel_bg='#0b070c', btn=['#2e170c', '#5a3018', '#9a5c2a'], btn_face=['#43261a', '#341c12'],
        btn_ink='#0b070c', rivet='#e6b84c', foot='#efd9b0',
        hud_ink='#0b070c', hud_track='#2a1e26', hud_fill='#f0a040', plate='#2a1912', plate_hi='#8f4f24',
        plate_lo='#170d0a', hud_text='#ffe08a', hud_text_sh='#0b070c', hud_mult='#fff0d0', hud_text2='#f0a040',
        judge='#ffe08a',
    ))


# B - "Woodcut": a carved print. Six inks, hatching instead of shading.
INK, INK2, PAPER, PAPER2, EMB, GOLD, TEAL = '#17121d', '#2e2534', '#ece0c4', '#b9a784', '#e2562c', '#e9a83e', '#2e7a8a'
WOODCUT = Style({
    'fleece':      [INK, INK, INK2, PAPER2, EMB],
    'mask':        [INK, INK, INK2, PAPER],
    'scarf':       [INK, INK2, PAPER2],
    'leather':     [INK2, EMB, EMB],
    'bronze':      [INK, GOLD, GOLD, PAPER],
    'bronze_in':   [INK, INK],
    'velvet':      [INK, INK, INK2],
    'boot':        [INK, INK2, ('h', PAPER2, INK2)],
    'hand':        [INK, INK2, PAPER2],
    'hole':        [INK],
    'brass_small': [GOLD, PAPER, PAPER],
}, outline='black', ink=INK)

WOODCUT_NOTES = note_style('black', INK,
                           [INK, PAPER2, PAPER],
                           [INK, TEAL, ('h', PAPER, TEAL)],
                           [INK, EMB, GOLD],
                           [INK, GOLD, PAPER])

WOODCUT_CFG = dict(
    name='woodcut', size=(135, 300), style=WOODCUT, note_style=WOODCUT_NOTES, scale=8,
    stars=0.0012, cross_stars=True, sky_lines=True, fire=True, lane_glow=False, courses=True, btn=2,
    btn_dither=True, ring_w=1.9, sparks=14, font_scale=1, judge_scale=1, plate_border=0, moon_cut=True,
    fire_w=0.12, fire_h=0.085, fig_opts=dict(tuft_amp=0.95),
    figures=[(0.13, 0.50, 48, True), (0.87, 0.575, 70, False)],
    ridges=[(0.02, 0.305, INK2, 1.0), (0.012, 0.322, INK, 2.5)],
    pal=dict(
        sky=[INK, INK], sky_line='#3a3040', star=PAPER, star2=PAPER2, moon=PAPER,
        wall=[PAPER2, '#cfc09c', PAPER], wall_line=INK, seam=INK, roof=INK, win_lit=GOLD, win_dark=INK,
        door=INK, sidewalk=INK2, kerb=PAPER2,
        cobble=[INK, INK], mortar='#3e3240',
        fire=[EMB, EMB, GOLD, GOLD, PAPER, PAPER], fire_glow=INK2, log=PAPER2, log2=INK,
        lane=PAPER, lane_edge=EMB,
        ring=PAPER, ring_hi=PAPER,
        bell_up=EMB, bell_up_hi=GOLD, bell_dn=TEAL, bell_dn_hi=PAPER2, bell_arrow=PAPER, note_ink=INK,
        rope=[INK, GOLD, PAPER2],
        panel_bg=INK, btn=[INK, INK2, PAPER2], btn_face=[PAPER, PAPER2], btn_ink=INK, rivet=INK, foot=INK,
        hud_ink=INK, hud_track=INK2, hud_fill=EMB, plate=PAPER, plate_hi=PAPER, plate_lo=PAPER2,
        hud_text=INK, hud_text_sh=PAPER2, hud_mult=EMB, hud_text2=PAPER2, combo=PAPER, combo_sh=INK2, judge=INK,
    ))


# C - "Festa": daylight Carnival Sunday, hi-res pixels, 5-6 step hue-shifted ramps,
# coloured (selective) outlines and light dithering.
FESTA = Style({
    'fleece':      ['#120d14', '#1f1720', '#2f2228', '#45302e', '#5e4234', '#d9a35a'],
    'mask':        ['#0e0a10', '#1c1418', '#2c1f20', '#4a3328', '#a07850'],
    'scarf':       ['#2a1a18', '#43291f', '#5f3c28', '#7d5334', '#9c6c42'],
    'leather':     ['#3e1f16', '#6a3420', '#9a5230', '#c47a44', '#e6a868'],
    'bronze':      ['#4a2e14', '#7e5420', '#b8862e', '#e3b44a', '#fbe08a', '#fff8d8'],
    'bronze_in':   ['#1a0f0c', '#2f1d14', '#43291a'],
    'velvet':      ['#100e1a', '#1a1828', '#262338', '#34304a'],
    'boot':        ['#130d0e', '#24181a', '#3a2622', '#56382c'],
    'hand':        ['#24170f', '#3c271a', '#5a3c28'],
    'hole':        ['#060406'],
    'brass_small': ['#b8862e', '#fbe08a', '#fff8d8'],
}, outline='selective', dither=0.55)

FESTA_NOTES = note_style('selective', '#000000',
                         ['#5e3f16', '#8a6020', '#c09030', '#e8c050', '#fff0a0'],
                         ['#14204a', '#1f3a8a', '#3062c8', '#5a96ec', '#b0daff'],
                         ['#2a1440', '#4e2280', '#7a3ab8', '#a868e0', '#e0b8ff'],
                         ['#4a1e10', '#7a3418', '#b05828', '#de8a48', '#ffc890'], dither=0.5)

FESTA_CFG = dict(
    name='festa', size=(180, 400), style=FESTA, note_style=FESTA_NOTES, scale=6,
    stars=0.0, clouds=True, fire=False, tower=True, lane_glow=True, courses=True, btn=3, ring_w=2.4,
    font_scale=2, judge_scale=2, roof_near=0.16, fig_opts=dict(rim=0.3, light=(-0.6, -0.7, 0.55), tuft_amp=0.95),
    figures=[(0.13, 0.50, 64, True), (0.87, 0.575, 92, False)],
    ridges=[(0.025, 0.30, '#8aa0b8', 1.0), (0.015, 0.322, '#6a8098', 2.5)],
    pal=dict(
        sky=['#4f96d2', '#69aadc', '#86bce4', '#a6cdea', '#c6dded', '#dde8ec'], cloud='#f6f4ee', cloud_sh='#c9dcea',
        wall=['#857464', '#9a8a78', '#b0a08c', '#c6b8a2', '#d8ccb6'], wall_line='#6e604f', seam='#5a4c40',
        roof='#a2442c', roof2='#cf6a40', win_lit='#2c3c4c', win_dark='#2c3c4c', door='#5a3a22',
        shutter='#3f7a52', win_frame='#ece4d4', sidewalk='#9a8c7c', kerb='#c4b8a4',
        cobble=['#6c645c', '#787068', '#857c72'], mortar='#4e4842',
        tower='#cbbba3', tower_sh='#a39380', tower_open='#2a2a34', tower_bell='#d8a03a',
        lane='#fff4d8', lane_edge='#ffd870', lane_glow='#9a9286', lane_glow2='#857c72',
        ring='#ffffff', ring_hi='#fff2c0',
        bell_up='#d4352a', bell_up_hi='#ff7a5a', bell_dn='#2a56b8', bell_dn_hi='#6a9ae8', bell_arrow='#ffffff', note_ink='#2a1a1e',
        rope=['#6a4520', '#e0b060', '#b08040'],
        panel_bg='#2a2430', btn=['#22406c', '#3462a0', '#6a9ad0'], btn_face=['#f0e6d2', '#d8ccb6'],
        btn_ink='#1a1424', rivet='#d8a03a', foot='#3462a0',
        hud_ink='#2a2430', hud_track='#d8ccb6', hud_fill='#d4352a', plate='#f4ecdc', plate_hi='#ffffff',
        plate_lo='#c8b89c', hud_text='#2a2430', hud_text_sh='#c8b89c', hud_mult='#d4352a',
        combo='#ffffff', combo_sh='#2a2430', hud_text2='#ffffff', judge='#d4352a',
    ))
