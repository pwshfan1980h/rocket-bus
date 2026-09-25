# Rocket Bus

A double-decker bus with a rocket strapped to the back. Launch off ramps, time the
rocket to clear the gap, and land it level, or the bus tears itself apart.

**Play:** https://pwshfan1980h.github.io/rocket-bus/

![Bus Lab demo](media/bus_lab_demo.gif)

Built with Godot 4.7 (GL Compatibility, 480x270 pixel art).

## Controls
| Key | Action |
|---|---|
| D / → | Throttle on the ground, nose down in the air |
| A / ← | Brake/reverse on the ground, nose up in the air |
| Space | Rocket (limited fuel) |
| H | Horn |
| R | Retry |
| Esc | Pause |

## Worlds
20 levels across 5 worlds with 1 to 6 gaps each: **Desert**, **Jungle**, **Mountains**, **Snow**, **Volcano**.
Gaps can be chasms, water, swamp, icy water or lava. Each world has its own wildlife (birds that
flush off signs, bug swarms, lizards, tumbleweeds, falling leaves), weather and music.

## Development
- Open the folder in Godot 4.7.2 and press play.
- `python3 tools/gen_art.py` regenerates the pixel art in `assets/sprites`.
- `python3 tools/gen_audio.py` re-synthesizes every sound effect and music loop into `assets/audio`.
- Levels are data in `scripts/game/levels.gd` (segment format documented in `scripts/world/terrain.gd`).
- Bus Lab (`scenes/bus_lab.tscn`, also in the main menu) shows every landing outcome for tuning.
- Tester bot plays every level headless and prints a report:
  `godot --headless --path . res://scenes/level.tscn -- --botall --fast`
- Level select: press **U** to unlock everything while testing.
- Every push to `main` builds the web version and deploys it to GitHub Pages.
