# Mamuthones: The Weight of Bells

A mobile rhythm game built around the Mamuthones of Mamoiada, Sardinia.

Live at https://icsdaniel.github.io/Mamuthones-/ (GitHub Pages, deployed from `main`). Open it in Safari or Chrome on a phone and allow motion access when asked.

## Prototype (`index.html`)

A 45-second playable procession, held in both hands:

- **Calibration:** 3 sharp tilts up and 3 down. The game uses the gyroscope (or acceleration, whichever reads the direction better), sets the bell sensitivity from your moves and learns which way is up. It's saved on the phone and can be redone from the results screen.
- **Play:** the thumbs tap the left and right step pads, a tilt up or down rings the bell (middle lane), and grey bars mean stand still.
- **Score:** Perfect 300, Good 150, Early/Late 50, times a combo multiplier up to ×3. Ringing during a stand-still costs 100. Your best score is kept on the phone.

## Sensor test (`test.html`)

Raw numbers for the inputs: tap and shake timing offsets, false shakes set off by taps, sensor rate and peak motion.
