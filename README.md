# Mamuthones: The Weight of Bells

A mobile rhythm game built around the Mamuthones of Mamoiada, Sardinia.

Live at https://icsdaniel.github.io/Mamuthones-/ (GitHub Pages, deployed from `main`). Open it in Safari or Chrome on a phone and allow motion access when asked.

## Prototype (`index.html`)

A 45-second playable procession, one-handed:

- **Calibration:** 3 shakes up and 3 down. The game sets the bell sensitivity from your shakes and learns which way is up on your phone. It's saved on the phone and can be redone from the results screen.
- **Play:** the thumb taps the top and bottom step pads, a shake up or down rings the bell, and grey bars mean stand still. A Right hand / Left hand switch mirrors the pads.
- **Score:** Perfect 300, Good 150, Early/Late 50, times a combo multiplier up to ×3. Ringing during a stand-still costs 100. Your best score is kept on the phone.

## Sensor test (`test.html`)

Raw numbers for the inputs: tap and shake timing offsets, false shakes set off by taps, sensor rate and peak motion.
