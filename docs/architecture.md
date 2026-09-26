# Architecture

Godot 4.6.2, GDScript, mobile renderer, portrait 720×1440 base size (stretch `canvas_items`, aspect
`expand`). Everything the game needs is in `game/`. Offline tools that generate assets are in `tools/`.

## Ownership

Four areas are built in parallel. Each owns its folders and nothing else; change another area's files
only by asking its owner (through the lead). `game/project.godot` belongs to the lead.

| Area | Owns |
| --- | --- |
| Core (rules, input, saves) | `game/scripts/core/`, `game/tests/core/` |
| Audio (music, bells, charts) | `tools/audio/`, `game/audio/`, `game/data/songs/`, `game/scripts/audio/`, `game/tests/audio/` |
| Art (look, figures, theme) | `tools/art/`, `game/art/`, `game/fonts/`, `game/shaders/`, `game/scripts/art/`, `game/tests/art/` |
| UI (screens, flow, text) | `game/scenes/`, `game/scripts/ui/`, `game/i18n/`, `game/tests/ui/`, `game/tests/screenshots.gd`, `game/export_presets.cfg` |

## Autoloads (registered in project.godot)

| Name | Script | Owner |
| --- | --- | --- |
| `Profile` | `scripts/core/profile.gd` | Core |
| `Leaderboards` | `scripts/core/leaderboards.gd` | Core |
| `Sound` | `scripts/audio/sound.gd` | Audio |

Everything else is a `class_name` script. Game rules are `RefCounted` classes with no scene, sound or
sensor access, so headless tests can drive them.

## Song files: `game/data/songs/<id>.json`

```json
{
  "id": "fires",
  "title": {"en": "Sant'Antonio's Fires", "it": "I fuochi di Sant'Antonio"},
  "stop": 2,
  "kind": "story",
  "bpm": 76,
  "offset": 2.105,
  "audio": "res://audio/music/fires.ogg",
  "remix": {"id": "fires_remix", "bpm": 76, "offset": 1.2, "audio": "res://audio/music/fires_remix.ogg"},
  "length": 128.4,
  "preview": 32.0,
  "charts": {
    "easy":   [{"b": 0, "k": "step", "lane": 1}],
    "medium": [],
    "hard":   [],
    "expert": []
  }
}
```

- `kind` is `story`, `piazza` (bells only; one chart named `piazza`) or `tutorial`.
- `offset` is the time in seconds of beat 0 in the audio file. A note's time is `offset + b * 60 / bpm`.
  Tempo is constant within a song.
- `remix`, when present, is a second track that uses the same charts with its own `offset`/`audio`
  (same bpm and beat grid, so the charts line up).
- Notes are sorted by `b`. `k` is one of:
  - `step` — `lane` 0, 1 or 2; optional `"call": true` plays the Issohadore's call with it (off-beat hits).
  - `hold` — `lane`, `len` in beats.
  - `bell` — a tilt. Direction is not stored: bells alternate up, down, up, down through the chart,
    counting `bell` and `ring` notes together.
  - `ring` — full ring: a step on `lane` and a bell on the same beat.
  - `swipe` — `dir` 1 (to the right) or −1.
  - `rest` — stand still. Optional `len` in beats (default 1).
- `tools/audio/validate_charts.py` and the core tests check every chart against the readability rules in
  `docs/design.md` section 4.

## Core API (`scripts/core/`)

- `SongLibrary.all() -> Array[SongData]`, `SongLibrary.get_song(id) -> SongData`, `SongLibrary.story()`.
- `SongData`: `id`, `title(lang)`, `stop`, `kind`, `bpm`, `offset`, `audio`, `remix` (Dictionary or
  empty), `length`, `preview`, `difficulties()`, `notes(difficulty) -> Array[Note]`, `time_of(beat)`.
- `Note`: `kind` (`Note.Kind.STEP/HOLD/BELL/RING/SWIPE/REST`), `t`, `end_t`, `lane`, `up` (bells, rings),
  `dir`, `call`, `beat`, plus play state (`done`, `holding`, `finished`, `hit_at`, `judgement`).
- `Session.new(song: SongData, difficulty: String, bell_set: String, options := {})`, options
  `slam: bool`, `piazza: bool`, `remix: bool`. Times are seconds of song time.
  - Input: `tap(lane, t, touch_id)`, `release(t, touch_id)`, `swipe(dir, t)`, `ring(t) -> Dictionary`
    (`{up: bool, quality: "perfect"|"good"|"ok"|"miss"|"silence"|"free"}` so the bell sound can match).
  - `update(t)` every frame; `is_over(t)`.
  - Signals: `judged(note, judgement, offset)` with judgement `perfect|good|early|late|miss|wrong|held|let_go|silence`,
    `unison_changed(level)`, `hold_started(lane)`, `hold_ended(lane, kept)`.
  - State: `score`, `unison_level` (0–5), `unison_mult()`, `weight()`, `combo`, `max_combo`, `stats`,
    `accuracy()`, `bells()` (0–3), `input_log` (for ghosts), `score_timeline` (time, score pairs).
- `BellSets`: `ids()`, `weight(id)`, `window_scale(id)`, `name(id, lang)`.
- `Calibrator`, `BellDetector`, `MotionReader`: tilt calibration and detection (see design section 2).
- `LatencyTest`: feeds tap times against click times, returns a median offset and a spread.
- `Conductor` (Node): owns the music `AudioStreamPlayer`; `play(song, remix)`, `song_time()` (smooth,
  never backwards, includes output latency and the player's audio offset), `pause()`, `resume()`,
  `finished` signal. Tests can drive it with `use_manual_clock(true)` and `advance(delta)`.
- `InputRouter` (Control, full rect): turns touches in the button row, keys and motion into `Session`
  calls, handles slam mode, emits `stepped(lane)`, `rang(result)`, `swiped(dir)` for sound and visuals.
  Needs `buttons_rect: Rect2` set by the play screen.
- `Ghost`: `from_session(session)`, `score_at(t)`, `to_dict()`, `from_dict()`.
- `Progression`: story order, `is_unlocked(song_id)`, `remix_unlocked(song_id)`, `bell_set_unlocked(id)`,
  `carving_points()`, `mask_option_unlocked(part, option)`.
- `Daily`: `for_date(date_dict) -> {song_id, difficulty, mirror}` from a hash of the date.
- `Profile` (autoload): versioned `user://profile.cfg`, corrupted files fall back to a fresh profile
  without crashing. Settings, calibration, audio offset, per song+difficulty bests `{score, accuracy,
  bells, ghost}`, look (`mask`, `fleece`, `straps`, `bell_set`), piazza players, first-run flags.
  `record_result(session) -> {prev_best, new_best, unlocked: [...]}`. Signal `changed`.
- `Leaderboards` (autoload): `available()`, `submit(board_id, score)`, `show()`; a local backend now,
  with Game Center and Google Play Games backends to plug in at export time.

## Audio API (`scripts/audio/sound.gd`, autoload `Sound`)

`step(lane)`, `bell(set_id, up, quality)`, `row_bells(unison_level)`, `call()`, `rope()`,
`hold_start(lane)`, `hold_stop(lane)`, `ui(name)` (`tap`, `back`, `unlock`, `carve`, `result`),
`ambience(name)` / `stop_ambience()` (`fire`, `crowd`, `wind`), `count_in(bpm)`. Low latency: short
samples preloaded, a pool of players, no allocation on the hot path.

## Art API (`scripts/art/`)

- `Palette` constants and `WoodcutTheme.build() -> Theme` (fonts, buttons, panels, labels, sliders).
- `MaskSpec`: the parts, options and unlock order of the carvable mask; `default()`, `validate(spec)`.
- `MaskView` (Control): draws a mask from `spec: Dictionary`.
- `ProcessionScene` (Control): `set_stop(n)`, `set_look(mask, fleece, straps)`, `jolt(kind)` with kind
  `step|bell|miss|ring`, `set_unison(level)`, `set_ghost_delta(seconds)`, `set_still(bool)`,
  `throw_rope()`, `set_reduced_motion(bool)`.
- `LaneSkin` (static drawing onto any CanvasItem): `draw_lanes`, `draw_hit_line`, `draw_step`,
  `draw_hold`, `draw_bell`, `draw_ring`, `draw_swipe`, `draw_rest`, `draw_button(rect, lane, state)`,
  `draw_hit_burst`.
- `Logo` (Control), `StopArt.card(n) -> Texture2D` for the stop cards, `Icon` sources for the app icon.

## Tests

`game/tests/run_tests.gd` finds every `game/tests/**/test_*.gd`. Each test file `extends TestCase`
(`game/tests/test_case.gd`) and defines `test_*` methods (they may `await`). Use `check(cond, msg)`,
`check_eq(a, b, msg)`, `check_near(a, b, tol, msg)`.

```
godot --headless --path game --import
godot --headless --path game -s res://tests/run_tests.gd            # all
godot --headless --path game -s res://tests/run_tests.gd -- core    # one folder
```

Visual checks: `xvfb-run -a godot --path game --rendering-driver opengl3 -s res://tests/screenshots.gd -- <dir>`.
Recorded play-throughs: Godot's movie maker (`--write-movie out.avi --fixed-fps 60`) with autoplay.
