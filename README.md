# Mamuthones: The Weight of Bells

A mobile rhythm game built around the Mamuthones of Mamoiada, Sardinia.

Live at https://icsdaniel.github.io/Mamuthones-/ (GitHub Pages, deployed from `main`). Open it in Safari or Chrome on a phone and allow motion access when asked.

## Prototype (`index.html`)

Two short songs, played holding the phone in both hands:

- **Calibration:** 3 sharp tilts up and 3 down. The game uses the gyroscope (or acceleration, whichever reads the direction better), sets the bell sensitivity from your moves and learns which way is up. It's saved on the phone and can be redone from the results screen.
- **Play:** three full-width lanes with Left, Middle and Right step buttons underneath. A tilt up or down rings the bell (red bars across all lanes), and grey bars mean stand still.
- **Songs:** *The First Steps* (84 bpm: steps and bells) and *The Rope* (92 bpm: adds held notes, off-beat Issohadore calls in ember, and rope swipes across the buttons). Bells always alternate up and down, so only their timing is judged. Charts are strings on an eighth-note grid in `SONGS` inside `index.html`.
- **Score:** Perfect 300, Good 150, Early/Late 50, times a combo multiplier up to ×3. Ringing during a stand-still costs 100. Each hold kept to the end adds 150. Your best score per song is kept on the phone.

## Sensor test (`test.html`)

Raw numbers for the inputs: tap and shake timing offsets, false shakes set off by taps, sensor rate and peak motion.

## Godot game (`game/`)

The real game, in Godot 4.6 (mobile renderer, portrait). It plays the same two songs with the same rules as the web prototype, and the charts now live in `game/data/songs.json`.

- **Open it:** install [Godot 4.6.2](https://godotengine.org/download) and open `game/project.godot`. Press F5 to play on your computer: **A S D** step, **Space** rings the bell, **Q / E** swipe left / right, **Esc** leaves the song.
- **Code:** the rules are plain scripts with no screen or sound, so tests can drive them.
  - `scripts/chart.gd` reads songs and parses charts, `scripts/session.gd` judges and scores a play.
  - `scripts/calibrator.gd` learns the bell tilt, `scripts/bell_detector.gd` turns sensor readings into rings, `scripts/motion_reader.gd` reads the sensors.
  - `scripts/play_view.gd` is the play screen, `scripts/main.gd` builds the other screens, `scripts/save_data.gd` keeps the calibration and best scores.
- **Tests:** `godot --headless --path game --import`, then `godot --headless --path game -s res://tests/run_tests.gd`. They also run on every pull request (`.github/workflows/godot-tests.yml`). `tests/screenshots.gd` saves a picture of every screen; it needs a display (for example `xvfb-run`) and `--rendering-driver opengl3`.
- **Audio:** the music and sounds are placeholders made by `tools/make_placeholder_audio.py`. Each song's `first_beat` in `songs.json` is the second in its audio file where the chart starts, so real recordings only need that number updated.
- **Phones:** exporting needs Godot's export templates plus the Android SDK (for Android) or a Mac with Xcode (for iOS). Not set up yet.
