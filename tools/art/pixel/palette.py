"""The one pixel-art palette every sprite, backdrop and UI piece is drawn from ("Bonfire Night").

Colours come in ramps, dark to light, one per material. Sample colours were taken from the three
reference pictures Daniele picked (gameplay, logo, menu). Every PNG the pixel tools write is checked
against this list (px.check_palette), so nothing off-palette slips in.

Rules (see docs/art-style.md):
  * K0 is the only outline colour for characters, notes and UI frames.
  * The night is blue (NIGHT ramp); firelight is warm (FIRE, STONE_W); nothing else is saturated
    except the Issohadore red, the kilim red and bronze/gold.
"""

RAMPS = {
    # outline / deepest shadow
    "K": ["#07060e", "#0e0d1a"],
    # night sky and cool shadows, darkest first
    "NIGHT": ["#0a0c24", "#10163a", "#18204e", "#222c62", "#303a78", "#434c8c"],
    # distant mountains and the cold side of houses
    "HILL": ["#141630", "#1d2040", "#2a2c50"],
    # stars, moon, hot white
    "STAR": ["#c9cde8", "#f4f1dc"],
    # fire, from ember-dark to white-hot
    "FIRE": ["#4a0a0c", "#7c1812", "#b8321a", "#e2561a", "#f47e22", "#fbb23a", "#fde07a", "#fff6cf"],
    # warm lit stone and plaster (houses, walls, the square's cobbles near the fire)
    "STONE": ["#1c1418", "#2c2026", "#3e2e30", "#58403a", "#7a5842", "#a07650", "#c89a64"],
    # cool road setts (the lanes) - kept dull so notes pop
    "SETT": ["#15151f", "#1d1d29", "#262634", "#302f3f", "#3d3b4c", "#4c4858"],
    # bronze and gold (bells, trims, frames)
    "GOLD": ["#2e1c0c", "#56340f", "#8a5a1c", "#c08a2e", "#e8b64c", "#f8dc8a"],
    # Issohadore / kilim red
    "RED": ["#2e0608", "#5c0c10", "#8e1a18", "#c02a22", "#e24a32"],
    # bone, cream, the white mask and shirt, UI text
    "BONE": ["#4e4540", "#8a7c6c", "#c4b494", "#ecdfbc", "#fdf6df"],
    # sheepskin (mastruca): near-black brown, lit edges go warm
    "FLEECE": ["#0c0908", "#171110", "#231915", "#33241c", "#4a3424", "#6a4a2e"],
    # the carved mask's dark wood
    "WOOD": ["#140f0e", "#241c19", "#382c26", "#544236", "#7a624c"],
    # leather straps, rope shadow
    "LEATHER": ["#2a150c", "#4a2616", "#6e3c20", "#96582e"],
    # rope (natural hemp)
    "ROPE": ["#6e5a3e", "#a88e62", "#d8c294"],
    # UI navy panels (the menu's buttons)
    "NAVY": ["#0b0c1c", "#12142a", "#1a1d3a", "#252a50"],
    # moss between stones, dark greenery
    "MOSS": ["#1a2216", "#28331e", "#3a4628"],
    # crowd skin, dim
    "SKIN": ["#5a3a2e", "#8a5e44", "#c08a64"],
}


def hexrgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


# Flat lookup: "FIRE3" -> (r, g, b). Index 0 is the darkest in each ramp.
P = {}
for _name, _cols in RAMPS.items():
    for _i, _c in enumerate(_cols):
        P[f"{_name}{_i}"] = hexrgb(_c)

ALL = sorted(set(P.values()))


def c(name):
    """A palette colour by name ("GOLD3"); raises on a typo."""
    return P[name]


def ramp(name):
    return [hexrgb(x) for x in RAMPS[name]]
