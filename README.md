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
