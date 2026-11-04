# Credits

Made with respect for the Mamuthones and Issohadores of Mamoiada, Sardinia. See
`docs/community-check.md` for what is still being checked with the community.

Built with [Godot Engine](https://godotengine.org) (MIT licence).

## Core

## Music

The story songs and their remixes are made with Suno from the project's own prompts, in the spirit of
Sardinian traditional music (see `/mnt/project-files/music-sourcing/suno-prompts.md`), and charted by
`tools/audio/music/`. Nothing is taken from real recordings or known tunes. The in-game credits say
the same (`cred_music`). Older synthesized songs written from scores by `tools/audio/music/`
(numpy/scipy) remain only for the tutorial.

## Sound

- Every bell, step, drone, call, rope, UI sound and ambience is synthesized from scratch by the game's
  own tools (`tools/audio/sfx/`: a modal model of hammered sheet-iron cowbells, a source-filter voice
  model, filtered-noise fire, wind and crowd). No recordings or third-party samples are used.
- The bells are stand-ins: real field recordings of Mamoiada bells, made or licensed with the
  community's consent, are meant to replace them before launch.

## Art

- **IM Fell English SC** (titles), by Igino Marini, from the Fell Types revival. SIL Open Font
  License 1.1. Source: https://github.com/google/fonts/tree/main/ofl/imfellenglishsc
  (`game/fonts/IMFellEnglishSC-Regular.ttf`, licence in `game/fonts/OFL-IMFellEnglishSC.txt`).
- **Alegreya Sans** Regular, Bold and ExtraBold (text), by Juan Pablo del Peral / Huerta Tipográfica
  (The Alegreya Sans Project Authors). SIL Open Font License 1.1. Source:
  https://github.com/google/fonts/tree/main/ofl/alegreyasans (`game/fonts/AlegreyaSans-*.ttf`, licence
  in `game/fonts/OFL-AlegreyaSans.txt`).
- **Alegreya** Bold and ExtraBold (button labels, headings) and **Alegreya SC** Bold (small-caps
  section labels and HUD words), by Juan Pablo del Peral / Huerta Tipográfica (The Alegreya Project
  Authors). SIL Open Font License 1.1. Source: https://fonts.google.com/specimen/Alegreya and
  https://github.com/google/fonts/tree/main/ofl/alegreya, .../alegreyasc (`game/fonts/Alegreya-*.ttf`,
  `game/fonts/AlegreyaSC-Bold.ttf`, licence in `game/fonts/OFL-Alegreya.txt`).
- The pixel UI kit, logo, word mark, menu backdrop and app icon are drawn pixel by pixel by the game's
  own tools (`tools/art/pixel/ui_kit.py`, `tools/art/pixel/logo.py`) from the one palette.
- The figures, the play road, the phone and headphones pictures and other scene art are made with
  image AI (ChatGPT) from the project's own designs and prompts, then cut and fitted by the game's
  tools without stretching (`tools/art/chatgpt/`). The in-game credits say the same (`cred_art`).
  Smaller pieces (notes, rings, frames) are drawn by the game's own code and tools (`tools/art/`,
  `game/scripts/art/`, `game/shaders/`). No photographs are used.

## UI

- All screens, layouts, widgets (lane view, HUD, unison meter, judgement words, tilt-phone and lesson
  pictures, tendency histogram) and the Italian and English text are original work written for this
  game, released under the project's license.
- No downloaded images, icons, fonts or sounds are used by the UI. Fonts, textures, icons and the
  woodcut theme come from the Art area and are credited above; every sound comes from the Sound area.
