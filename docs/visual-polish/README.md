# Visual polish pass

Before and after screenshots for every world: `before/` and `after/`, with matching
file names. Each world was shot with the bot at 13 s and 21 s of wall-clock time:
`godot --path . -s tools/shot.gd -- --level=N --bot --at=T`. The first 7 s or so is
the level intro card, so `*_13` shows the first ramp and `*_21` shows mid-level.
`compare_13.png` and `compare_21.png` put the two side by side (before on the
left, after on the right).

| File prefix | Level / leg |
|---|---|
| desert | 1-1 First Day |
| mesa | 1-4 Mesa Leap (sandstorm) |
| jungle | 2-1 River Run (rain) |
| jungle_night | 2-4 Temple Drop |
| mountain | 3-1 Switchback |
| snow | 4-2 Frozen Lake |
| blizzard | 4-3 Avalanche Alley |
| volcano | 5-1 Hot Foot |
| volcano_night | 5-2 Magma Mile |
| moon | 6-1 One Small Hop |
| border | 7-1 Anomalous Ride |
| city_dawn | story: First Shift |
| city_night | story: The Last Stop |
| mudslide | story: Mudslide |

## What changed

**Ground (every world).** The ground under the road used to be flat horizontal
stripes, and it fills about 40% of every frame. It's now shaded by depth below the
road. `terrain.gd` bakes a 1px strip of road heights that `terrain.gdshader` reads.
- The strata now bend with the road, with a dark seam on each layer.
- The ground falls into darkness in dithered steps the deeper it goes.
- There's a contact shadow right under the road band.
- Each world has its own buried details (set by `soil`, `rock` and `accent` in each
  biome's `ground`):
  - desert: bones and ammonite fossils
  - jungle: roots hanging down from the road
  - mountain: stones
  - snow: ice crystals with glints
  - volcano: magma cracks deep down that glow and pulse
  - moon: rimmed craters
  - Borderworld: glowing crystal shards
  - city: a sewer main with flanged joints, a cable duct and broken bricks

  The details are drawn in 2px art pixels, so they stay crisp at the camera's
  0.4–0.6 zoom.

**Borderworld islands (bug fix).** Four of the nine floating islands in 7-1 never
drew their body, because their polygons failed to triangulate. The game logged
"terrain body triangulation failed". The underside was cutting up through the steep
climb to each ramp lip. It now hangs below the lowest nearby road point. Only the
visual polygon changed; collision is untouched.

**Lava.**
- A stepped, additive glow rises out of each lava gap, washes up the cliff walls
  and lights the bus as it flies over.
- Heat-shimmer specks rise from the surface.
- The pool has a hot yellow skin with a dithered edge.
- Dark crust plates drift on the flow.

**Water, swamp and icy water.** Depth now falls off in dithered steps instead of thin
stripes, sky glints slide across the surface, and swamps send up marsh-gas bubbles.

**Volcano backdrop.** Glowing lava trickles down one flank of each distant volcano,
and lava bombs arc out of the craters.

**Night skies.** Starry skies get the odd shooting star: moon, snow, mountain,
Borderworld and any `@night` level.

**Bus.**
- A burst ring and muzzle flash kick out of the nozzles when the rocket lights.
- Every landing sends out a flattened shockwave ring in the world's dust colour
  (sand, mud, snow, sparks, moondust, spores). Big hits get a second ring.
- Both effects are in the new `scripts/bus/bus_fx.gd`. `bus.gd` only preloads it
  and spawns the effects.

## Less floating text
Feedback was "too much floating text". Only text that matters for play is left; the
rest is now shown with pictures. `text/before_after_text.png` compares the two.
- **Rider and driver speech** (`bus_passengers.gd`): at most one line of text every
  9 s. Any other line, and every landing or airtime reaction, shows as a small pixel
  speech bubble with a symbol instead (`!`, heart, note, star, dots, skull). The bubble
  is in the new `scripts/ui/speech_icon.gd` and is called with `Fx.bubble()`. The
  voices and the riders' faces and bounces are unchanged.
- **Crash quips** from flying riders are gone, but their screams still play. A ragdoll
  bonk now shows a star bubble and a lost head shows a skull bubble, instead of text.
- **Landings:**
  - The "NICE LANDING / SMOOTH / BUS-TASTIC" text is gone. A coloured ring on the
    ground now shows the grade: green for good, white and gold for perfect, orange
    for hard.
  - PERFECT!! keeps its big text.
  - HARD LANDING is now small text.
- **Horn and dog:** the horn shows yellow sound-wave arcs instead of "HONK!". The
  dog's "YIP!" is now a bubble.
- **Bus stops:** the bobbing "BOARD n / DROP n" label is replaced by pictograms. A
  green up-arrow is followed by one person icon per boarding rider, and a pink
  down-arrow by one person icon per drop-off.
- **Level start:** the gap-count card is gone, because the HUD already shows GAPS.
  The title and blurb stay.
- **Controls reminder:** "R RETRY  ESC PAUSE  H HORN  F1 HELP" fades out after 12 s.
- **Kept on purpose:** WRECKED and its reason, +FUEL, flips, tips, stop names,
  HOOKED and HITCH SNAPPED, and the hints.

## 2.5D
The question "could it be 2.5D?" is covered in `2.5d.md`, with a mock-up in
`mock25d.png` and `mock25d_volcano.png`. Nothing has been converted.

## Files touched
- `assets/shaders/terrain.gdshader` (rewritten)
- `scripts/world/terrain.gd`: `_bind_soil()` and the floating-underside fix
- `scripts/world/biomes.gd`: `soil`, `rock` and `accent` in each `ground`
- `scripts/world/gap_liquid.gd`
- `scripts/world/backdrop.gd`
- `scripts/bus/bus_fx.gd` (new)
- `scripts/bus/bus.gd`: the effect spawns, the landing and honk text, and the dog bubble
- `scripts/bus/bus_passengers.gd`, `scripts/bus/ragdoll.gd`: the speech limit and bubbles
- `scripts/ui/speech_icon.gd` (new), `scripts/autoload/fx.gd`: `Fx.bubble()`
- `scripts/world/stop_markers.gd`: the rider pictograms
- `scripts/game/level.gd` (2 small edits): the gap-count card is removed and the controls footer fades

## Checked
The bot sweeps before and after are in `bot-before.txt` and `bot-after.txt`:
`--botall` in three batches, plus `--botstory`. Physics and collision are unchanged.
- **Visual pass alone:** all 25 levels and 7 story legs WON, with no script or
  shader errors. The Borderworld triangulation warnings are gone.
- **After the text cut:** everything WON except the story leg RIVER CROSSING. Its bot
  stalls on a kicker after hooking the canoe.
- **That stall is not a regression.** The run is chaotic at the hitch:
  - Traces with `--fixed-fps 60 --trace` match frame for frame until the hitch
    `PinJoint2D` is created at x≈3450. They diverge slightly from there.
  - At that point the bus brakes from 280 to about 8. Whether the canoe settles
    cleanly then decides whether the bus can get going again.
  - Adding one unused `Node2D` to the **original, unchanged** code in the same step
    also makes the run fail.

  So it's about node allocation and joint order, not the speech change. The
  hitch is worth hardening, for example by hooking the canoe in a way that doesn't
  nearly stop the bus, but that's gameplay and out of scope here.
