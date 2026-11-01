# Claude's from-scratch pixel styles (drafts, 2026-11-01)

Three style drafts for Sonazzos drawn entirely in code at native pixel size:
Ember (90x200, black outlines), Woodcut (135x300, 10 colours), Festa (180x400,
selective outlines). Scaled by whole numbers only.

    python3 export.py /mnt/project-files/pixel-styles

- `pxkit.py` shaded shapes -> palette ramps / hatching / dithering -> outlines, 5x7 font
- `figure.py` the Mamuthone in six parts + 4-frame bob (game timings 200/90/80/130 ms)
- `scene.py` play screen (street, lanes, notes on a looping 8-beat pattern, rings, buttons, HUD)
- `styles.py` the three palettes and layouts
