"""Regenerate every sample in game/audio/sfx, then measure them.

    python3 tools/audio/sfx/build_all.py          (about two minutes)
"""
import bells
import fx
import hits
import measure
import steps
import voices

if __name__ == "__main__":
    bells.main()
    steps.main()
    voices.main()
    fx.main()
    hits.main()
    measure.main()
