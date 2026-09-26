# Rules for everyone building the game

- Read `docs/design.md` (what the game is), `docs/architecture.md` (APIs, file formats, who owns which
  folders) and `docs/rubric.md` (how it is judged) before starting.
- Only write inside the folders your area owns. If you need something from another area, write it
  down in your final report; the lead passes it on. `game/project.godot` belongs to the lead: ask for
  changes (for example a new autoload or input setting) in your report.
- Other areas are being built at the same time in the same checkout. Keep every script you save
  parse-clean (write whole files, check them right away), because a broken script breaks the import for
  everyone.
- Do not run `git commit`, `git push`, `git checkout` or anything else that changes git state. The lead
  commits.
- Godot 4.6.2 is installed as `godot`. To avoid clashing with other agents' imports, run Godot on your
  own copy: `rm -rf /tmp/w-<area> && mkdir -p /tmp/w-<area> && cp -r game /tmp/w-<area>/`, then
  `godot --headless --path /tmp/w-<area>/game --import` and
  `godot --headless --path /tmp/w-<area>/game -s res://tests/run_tests.gd -- <area folder>`.
  For pictures: `xvfb-run -a godot --path ... --rendering-driver opengl3 --resolution 720x1440 -s <script>`.
- Python 3 with numpy, scipy and soundfile (OGG Vorbis writing works) is installed. Don't install other
  packages. Fonts or other assets you download must be openly licensed (SIL OFL, CC0, CC-BY); record
  the source and licence in `docs/credits.md` under a heading for your area (create the heading if it
  isn't there; keep edits to your own section).
- GDScript: static typing where it helps, `class_name` for shared classes, short comments where a
  reason isn't obvious, no warnings about unused variables left behind. Tests go in
  `game/tests/<your folder>/test_*.gd`, extending `TestCase` (see `game/tests/test_case.gd`).
- Rate your own work against the rubric aspects you own, with evidence, and keep improving until each is
  8 or more. Then ask what would make it a 10 and do the most valuable of those that fit your area.
  Independent reviewers will re-score everything afterwards.
- Finish with a short report: what you built, how to use it, your honest scores per rubric aspect with
  the evidence, what's missing, and what you need from other areas.
