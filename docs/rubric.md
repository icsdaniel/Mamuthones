# Quality rubric

Every aspect is scored out of 10 by a reviewer who did not build it, from evidence (tests, screenshots,
recorded play-throughs, audio measurements, code), never from the builder's description. The target is
**8 or more on every aspect**. After that, each reviewer writes down what would make the aspect a 10, and
the best of those ideas get built.

A score is the lowest band whose checks all pass. Anything that crashes, logs script errors, or breaks a
design rule caps the aspect at 5.

## 1. Core feel and timing
- 6: Session judges every note kind by the windows in the design; tests cover each judgement.
- 7: Song time follows the audio clock with output latency and the player's offset; never jumps back;
  a recorded autoplay run stays within ±10 ms of every note.
- 8: Every hit gives feedback within the same frame: sound, button flash, note burst, judgement word,
  vibration; misses are visible but not punishing to read. Pausing and resuming keeps sync.
- 9: The bell sound varies by judgement and unison; the row visibly tightens as unison rises.
- 10: A first-time player can tell, without reading, whether they were early or late.

## 2. Charts and difficulty
- 6: Every song has 4 valid charts that pass the validator (alternating bells, no impossible overlaps).
- 7: Notes sit on audible musical events (checked by comparing chart times to onset times of the stem
  that drives them; ≥ 95 % within 20 ms).
- 8: Clear difficulty curve: note density and variety rise across Easy → Expert and across stops; Easy
  is playable by a beginner (≤ 1.5 notes/s), Expert is demanding (≥ 4 notes/s peaks); each mechanic is
  introduced alone before it is combined.
- 9: Every song has a memorable signature pattern and a build-up and a climax that the chart follows.
- 10: Charts feel hand-written: phrases answer each other, and stand-stills land on real musical rests.

## 3. Music
- 6: Every story stop has an original track of 1.5–2.5 min; no clipping (peaks ≤ −1 dBFS).
- 7: Loudness within ±1.5 LU of −14 LUFS across tracks; clear count-in; tempo steady; the tracks sound
  like different songs.
- 8: Recognisably Sardinian in character (tenore-style voices, launeddas-style reeds with drone, drums),
  with arrangement changes every 8–16 bars, and a remix per stop in a distinct modern style.
- 9: Melodies are memorable; mixing leaves room for bells and steps; transitions are musical.
- 10: Someone would listen to the soundtrack on its own.

## 4. Bells and sound effects
- 6: Every event in the Sound API has a sound; nothing clicks or pops; latency path is one preloaded
  player per voice.
- 7: The three bell sets sound clearly different (spectral centroid and decay differ by ≥ 15 %), and up
  and down bells differ.
- 8: Bells sound like heavy cowbells, not synth beeps; quality variants (perfect/good/ok/miss) are
  audible; step pitches fit every song's key; calls and rope sounds are distinct.
- 9: Row bells swell with unison; ambience (fire, crowd, wind) sets each stop.
- 10: Ringing the bell is satisfying enough to do for its own sake.

## 5. Visual art and identity
- 6: One consistent palette and font family on every screen; nothing uses default Godot styling.
- 7: Woodcut look throughout: textures (grain, ink edges, paper), carved shapes, no flat vector blobs.
- 8: The logo, the mask and the Mamuthone figure are distinctive and read at small sizes (the icon at
  64 px); every stop has its own scene; notes, bells, holds, stomps and stand-stills are distinguishable
  in greyscale.
- 9: The procession scene is alive (fire flicker, fog, jolting row, Issohadores, crowd) at 60 fps.
- 10: A screenshot of any screen is good enough for the store page.

## 6. UI, flow and onboarding
- 6: Every screen is reachable and has a way back; nothing overflows at 720×1280 to 720×1600 and at
  tablet aspect 3:4; all text is in both English and Italian.
- 7: First launch to first played note takes under 60 seconds; touch targets are ≥ 88 px; text ≥ 24 px.
- 8: The tutorial teaches steps, bells, holds, stand-stills and two-thumb stomps one at a time, with pauses and
  retries, before the first real song; results explain what to improve; pause menu with resume,
  restart, quit.
- 9: Transitions and small animations make it feel finished; unlocks are celebrated.
- 10: Nothing ever needs explaining twice.

## 7. Motion input and calibration
- 6: Calibration and detection are covered by tests on synthetic signals (clean, noisy, soft, gyro-less).
- 7: One flick rings once; hard taps on the buttons do not ring (tested with synthetic tap bumps);
  a missing sensor is detected and explained.
- 8: Calibration takes under 20 s, is easy to redo, and the slam option fully replaces the tilt; the
  audio-delay tap test works and applies its result.
- 9: Detection adapts if the player's flicks get softer during a song.
- 10: Verified on a real iPhone and a real Android phone (needs a person).

## 8. Progression and replay
- 6: Seven story stops unlock in order; free play; bests saved per song and difficulty.
- 7: Mask carving, bell sets, sheepskin and straps work and show in the procession; remixes unlock.
- 8: Ghost runs and the daily procession work; each stop gives a new
  reason to replay (grades to raise, remix, carving points).
- 9: A player can see at a glance what to do next and what they are close to unlocking.
- 10: Players want to finish every song at every difficulty.

## 9. Scoring clarity and uniqueness
- 6: Score follows the formula in the design, tested.
- 7: Unison and weight are shown and explained in the tutorial or results.
- 8: The results screen breaks the score into accuracy, unison and weight, and shows early/late tendency.
- 9: The scoring makes the game's own ideas (unison, stillness, weight) the way to a high score.
- 10: Players talk about their unison, not their combo.

## 10. Respect and authenticity
- 6: No joke or neon options; masks are black wood; Issohadores in red with white masks.
- 7: Stop cards state only plain, checkable facts; uncertain words are kept out of player text and
  listed in `docs/community-check.md`.
- 8: Credits and an in-game note say the game is made with respect for the Mamoiada tradition and list
  what is still to be checked with the community.
- 9: A Mamoiada local would recognise the procession.
- 10: The community endorses it (needs people).

## 11. Technical quality
- 6: No script errors or warnings treated as errors on import and in tests; CI runs all tests.
- 7: Saves are versioned and survive corruption; no allocation-heavy work per frame in play.
- 8: Draw calls and frame time fit a mid-range phone (the play screen renders in under 8 ms on the
  desktop opengl3 driver at 720×1440); total download under 150 MB; code is readable and commented
  where it isn't obvious.
- 9: Export presets for Android and iOS are ready (only signing and SDKs missing).
- 10: Builds and runs on real phones (needs a person).

## 12. Scope and business fit
- 6: Offline; no servers, ads, accounts or analytics.
- 7: Everything is earned by play; nothing affects score that could be bought.
- 8: Leaderboards and daily work without online services and plug in to Game Center / Play Games.
- 9: Store listing material exists: description in EN/IT, screenshots, icon, privacy statement (no data
  collected).
- 10: Priced and positioned against Rotaeno with a clear reason to buy.
