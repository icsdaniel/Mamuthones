# Mamuthones: The Weight of Bells — Game Design

A paid, offline mobile rhythm game (iOS and Android, portrait). You are a Mamuthone walking in the
procession of Mamoiada, Sardinia. Your thumbs tap the steps, and you ring the cowbells on your back by
sharply tilting the phone. The better your row keeps together, the louder and cleaner the bells ring.

This document is the source of truth for what the game is. `docs/architecture.md` says how it is built,
and `docs/rubric.md` says how every part is judged.

## 1. Pillars

1. **The bells are the game.** Every mode is built around the sound of a load of cowbells ringing in
   unison. Tilting to ring them has to feel physical and satisfying, and the bell sound is the reward.
2. **Keep the row together.** Scoring rewards staying in unison (steady streaks) and keeping still when
   the procession is still, more than isolated perfect hits.
3. **A living tradition, treated with respect.** Real Mamoiada forms only: black wooden masks, dark
   sheepskins, the Issohadores in red with their rope. No joke skins, no neon, no invented rituals.
   Uncertain facts and words are flagged for checking with the community (Museo delle Maschere
   Mediterranee, Mamoiada) and are kept out of player-facing text until then.
4. **Complete at launch, zero maintenance.** Offline-first. No servers, no live events, no ads, no
   energy timers, no pay-to-win. Paid up front. The only online features are friends' scores and a global
   ladder through Game Center and Google Play Games.

## 2. Controls

- Hold the phone in both hands, portrait.
- **Steps:** three buttons in a row at the bottom of the screen (Left, Middle, Right). Notes fall down
  three full-width lanes above them. Each button has its own step pitch.
- **Bell:** a sharp tilt of the phone (top edge toward you or away and back). Bells always alternate up,
  down, up, down, so the direction is shown but only the timing is judged. Read by the gyroscope when it
  tells directions apart better than the accelerometer; calibrated per phone.
- **Hold:** keep a step button pressed until the hold's end (drones and long chords).
- **Rope swipe:** drag a finger across the button row, left or right, when the Issohadore throws the rope.
- **Full ring (Hard and Expert):** a step and a bell on the same beat.
- **Stand still:** grey bars across the lanes. Ringing the bell during them costs points.
- **Accessibility "slam":** an option that replaces the tilt with pressing Left and Right together.
  Runs with slam on are marked, and don't go on the global ladder.
- On a computer (development and trailers): A S D steps, Space bell, Q/E swipes, Esc pause.

## 3. Timing and scoring

Timing windows (normal bell set):

| Judgement | Window | Points |
| --- | --- | --- |
| Perfect | ±45 ms | 300 |
| Good | ±90 ms | 150 |
| Early / Late | ±140 ms | 50 |
| Miss | beyond | 0 |

Swipes get ±170 ms. Bells from the tilt get an extra 15 ms on every window, because sensors are looser
than touch.

**Unison** is the multiplier: ×1, ×1.5, ×2, ×2.5, ×3, ×4. It goes up one level every 12 hits in a row
that are Good or better. A miss drops it **two** levels and a wrong step one (never to zero), so the
row can recover. It is shown as more of the Mamuthones beside the lanes jumping with you, and louder.

**Weight** is the bell set's multiplier. Heavier sets score more and have stricter windows:

| Bell set | Weight | Windows |
| --- | --- | --- |
| Light (first set) | ×1.0 | as above |
| Village | ×1.2 | ×0.9 |
| Full load | ×1.5 | ×0.8 |

Other rules:
- Hold kept to its end (released no earlier than 120 ms before): +150 × multiplier.
- Full ring: judged as one note on the later of its two inputs, both must land within the Early/Late
  window, and a Perfect full ring gives 450.
- Ringing during a stand-still: −100 for every ring (rings closer than 150 ms count once) and the unison
  drops one level. Keeping still through a stand-still is worth chasing: 800 × unison × weight for every beat
  it lasts, it counts as 2 hits per beat (up to 8) toward the next unison level, and the row visibly
  settles when it is kept. Stand-stills last at least 2 beats, sit on real halts in the music, and are
  often tempted by a call or a bell cue just before or inside them.
- Score = sum over notes of points × unison × weight, minus stand-still penalties, never below 0.
- Smaller rules chosen while building: a Good full ring gives 225 and an Early/Late one 75. Early/Late
  keeps the unison level but restarts the run of 12. Letting go of a hold early breaks the streak and
  lowers unison one level. A wrong-way swipe uses up the note. A tap only counts as a wrong step when
  another lane's note is in its window and the pressed lane has no note of its own within twice the
  Early/Late window; stray taps are free. A wrong step drops unison one level (a miss drops two).
  In slam mode, Left + Right within 80 ms is the bell.
- **Accuracy** = (Perfect + 0.7·Good + 0.3·Early/Late) / notes. Grades from accuracy: the row's own
  words, from "The Issohadores are waiting for you" to "The whole row rang as one", plus a letter-free
  1 to 3 bell rating (≥ 70 %, ≥ 85 %, ≥ 95 %). Bells are the stars of the game.
- The bell sound itself reacts to play: Perfect rings clean and full, Good slightly softer, Early/Late
  clanks, a miss is a dull knock. High unison adds the whole row's bells behind yours.

## 4. Difficulty

Every song has four charts, all written to the music:

| Level | Steps | Bells | Extras |
| --- | --- | --- | --- |
| Easy | the walking beat, one lane at a time | one per phrase, on strong beats | stand-stills |
| Medium | beat and some half-beats | alternating with the steps (step, step, step, bell) | holds |
| Hard | steady patterns across lanes | on beats different from the steps | swipes, off-beat calls, full rings |
| Expert | dense patterns, triplets in the finale | independent of the steps | everything, triple rings |

Charts follow simple readability rules: no more than one input per hand per eighth at Hard (per
sixteenth at Expert; in triplet sections an eighth is a triplet eighth), bells at least half a beat apart, and nothing hidden under a hold's own lane.

## 5. Modes

### Story: the procession
Seven stops that follow the real calendar, one song each. Finishing a stop with one bell unlocks the next.

| # | Stop | Song mood |
| --- | --- | --- |
| 1 | The Workshop (the night before; tutorial) | quiet, a single drum and voice |
| 2 | Sant'Antonio's Fires (16 January) | first appearance, bonfire, slow and heavy |
| 3 | Around the Bonfires (17 January) | circling, a dance feel |
| 4 | Carnival Sunday | full procession, launeddas and tenore |
| 5 | The Rope (the Issohadores work the crowd) | playful, calls and swipes |
| 6 | The Piazza | big, loud, fast |
| 7 | Shrove Tuesday (the last procession) | the finale, everything |

Before each stop, one short illustrated card of plain facts about the moment (two sentences, no invented
lore). Clearing a stop at Hard with 2 bells unlocks its **remix** (the same song rearranged with modern
drums and bass) as a separate playable track.

### Free play
Any unlocked song, any difficulty, any bell set. Shows your best score, bells, and ghost.

### Piazza
Sound-first, whole-body, party mode. 60 to 90 second rounds of bells only, with the crowd, the fire and
the Issohadores' calls. Only tilts count, with loose timing (±200 ms), and the screen shows one huge
cue so it can be played while moving. Pass-and-play: up to 6 named players take turns on one phone, and
the round ends on a ranking. Scores stay on the phone.

### Daily procession (offline)
Each day the date picks one song and whether the lanes are mirrored, so friends get the same
procession with no server. The player picks the difficulty, and each difficulty has its own daily
ladder when online services are available. A song from a stop the player hasn't reached plays with its
name and picture hidden ("a procession from later in the story"), so the daily never spoils the story.

## 6. Progression: your Mamuthone

The player builds their own Mamuthone. Nothing is bought; everything is earned by playing.

- **Mask** (carved in the workshop between songs): brow, eyes, nose, cheeks and mouth shapes from real
  Mamoiada forms, plus wood finish and patina. Each bell earned is a carving point; finer details unlock
  as the story advances.
- **Bells**: Light, Village, Full load. Each has its own sound and weight (section 3). Village unlocks
  at stop 3, Full load at stop 6.
- **Sheepskin and straps**: fleece shade (black, dark brown), strap leather and how the bells are tied.
  Cosmetic.
- **Ghost**: your best run on each song and difficulty is recorded on the phone. During play your ghost
  walks beside you in the row, and the HUD shows whether you are ahead of it.

## 7. Audio

- Original music, written for the game in the spirit of Sardinian traditional music: canto a tenore
  style voices (bassu, contra, boghe, mesu boghe), launeddas style reed melodies over a drone, frame and
  bass drums. Nothing copied from real recordings or known tunes.
- Bells are the constant: every tilt rings the player's bell set. Real field recordings of Mamoiada bells,
  made or licensed with the community's consent, replace the synthesized ones before launch.
- Songs last 1.5 to 2.5 minutes, with a count-in and an audible cue before every bell (the drum or a call).
- Mix targets: peaks below −1 dBFS, integrated loudness about −14 LUFS for music, bells clearly on top.
- Headphones are assumed and recommended at start. Vibration on hits is extra feel, never a replacement.

## 8. Look

Woodcut prints and carved wood, in black (#141110), bone (#ede6da) and red (#c0392b), with ember
(#e0a24a) for fire and highlights. Chisel marks, wood grain, ink edges, paper texture. Night, fire and
winter fog. The logo is the black mask front and centre, with the red rope around it and a hint of bells.

Portrait layout during play, top to bottom: HUD (score, unison, progress), then the three note lanes
and the three step buttons filling the rest of the screen, with a file of Mamuthones either side of
the road's far end, smaller with distance (Daniele, 2026-09-27: the scene on top took space and added little). Notes slide smoothly down
the lanes to the hit line (Daniele, 2026-09-28: a tried Rift-style tile hop is rolled back). The lanes
are a road laid back in perspective (Daniele, 2026-09-28): full width at the hit line, narrowing to 55%
at the far end, so notes come toward the player and grow as they near. The Mamuthones jump on the beat, landing on it; more of them join as the
unison grows, they stumble on a miss and stand still through a stand-still. The Piazza keeps the
procession scene.

## 9. Setup and settings

- First launch: language (English or Italiano, from the phone), a headphone suggestion, then the tilt
  calibration (three tilts up, three down) and a tap test that measures the audio delay. It all takes
  under a minute, then the Workshop tutorial starts.
- Settings: redo calibration and delay test, manual delay offset, vibration, slam mode, reduced motion,
  note speed, music and effects volume, language, credits.

## 10. Online (optional, never required)

Game Center and Google Play Games for friends' scores and a global ladder per song and difficulty, plus
the daily procession. Without them, everything works and scores stay on the phone. No accounts, no
analytics, no data collection.

## 11. Out of scope

Live events, seasonal content, multiplayer sync between phones, ads, in-app purchases, custom servers,
other bell traditions (a possible paid expansion later).

## 12. Things to check with the community

Local names (for the mask, sheepskin, bell load, the rope and the calls), the exact calendar and route,
depiction of masks and Issohadores, and the bell recordings. Until checked, player-facing text uses plain
English and Italian words ("mask", "sheepskin", "bells", "rope") and only "soha" for the rope.
