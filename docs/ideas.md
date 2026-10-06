# Ideas on hold: Story mode and 2.5D

Plans to talk over, not built yet. Shipped work lives in the git log.

---

## Story mode

### Pitch

**ROUTE 99.** The driver is two days from retirement (they already say so when the bus wrecks).
Dispatch hands them Route 99, the one nobody finishes. Each leg is a hand-built road with a job
to do: pick people up, drop them off, deliver something, keep someone happy. At the end of most
legs the road forks, and the driver picks which way to go.

Between legs, a short **dispatch radio card** (typewriter text, `typewriter.wav`) sets up the
next leg. Passengers you picked up stay on board and talk about what happened earlier.

### Branching shape (first draft)

```
                    ┌─ 2A Oasis Express (desert) ─┐
1 Depot (city) ─────┤                             ├─ 3 Jungle Ferry ─┬─ 4A Temple Shortcut ─┐
                    └─ 2B Canyon Detour (mesa) ───┘                  └─ 4B River Road ──────┤
                                                                                            │
          ┌─ 6A Summit (mountain/snow) ── ENDING: "The Retirement Party" ──────────────────┤
5 Volcano Pass ─┤                                                                          │
          └─ 6B Dark Side (moon, via the rocket) ── ENDING: "Earthrise Express"            │
                                                                                            │
     Secret: deliver every passenger with all their luggage → 7 Borderworld ── ENDING: "Route ∞"
```

- About 10 legs per playthrough, 3 endings, and a secret one.
- Choices change the next road, which passengers are aboard, and which jokes and endings unlock.
- A playthrough takes about 20–30 minutes. Each leg can be replayed from a story map.

### New road challenges (the fun part)

Ranked by how much new gameplay each one gives for the build effort.

| # | Challenge | What the player does | Build notes |
|---|-----------|----------------------|-------------|
| 1 | **Hill stop** | Stop inside a marked bus stop on a steep incline and hold still while people board (progress ring). Then a hill start without rolling back into the gap behind you. | New `stop` segment (zone, board/drop count, slope). Level gets a STOPPING sub-state. The bot learns to brake into zones. |
| 2 | **Downhill drop-off** | Same idea on a descent: brake early, don't overshoot, don't launch Grandma. | Reuses #1. |
| 3 | **Passengers as cargo** | Hard landings can throw *one* rider out instead of wrecking the bus. Delivering N of M is the leg's goal. | `eject_one()` reuses the ragdolls. Passenger count goes on the HUD. |
| 4 | **Roof-rack delivery** | A wedding cake, a tuba, or a goat is strapped to the rack. Hard landings knock it loose. | The rack is already a breakable piece, so give it hit points. |
| 5 | **Requests** | The thrill-seeker kid shouts "DO A FRONT FLIP!" Grandma says "NO FLIPS, PLEASE." Pleasing each one earns tips. | Hooks the new flip tracking (`_jump_flips`). |
| 6 | **Ferry / raft** | Drive onto a moving raft and ride it across a river. | A kinematic platform segment. |
| 7 | **Drawbridge** | The bridge rises and falls on a timer. Time the jump or wait. | An animated StaticBody segment. |
| 8 | **Low tunnel** | A ceiling over the road. Keep the jump low and the rocket short. | A ceiling collision segment. |
| 9 | **Chase** | A lava flow, an avalanche or a goat stampede comes up behind you. Speed is forced. | A scrolling hazard wall with a trigger. |
| 10 | **Rope bridge** | Sags under the bus, bounces you, and loses planks. | A chain of pinned bodies. Needs a performance check on web. |
| 11 | **Night route** | Headlights only. The headlight cone already exists. | A darker tint plus fewer backdrop lights. |
| 12 | **Gravity flip** (Borderworld) | Drive on the underside of floating islands. | Per-zone gravity direction. The flashiest one, so save it for the secret leg. |

### Build plan (when we go)

1. **Prototype #1 (hill stop) inside one arcade level** to see whether stopping is fun next to
   all the flying. This is the cheapest test of the core Story idea.
2. `scripts/game/story.gd`: a node graph `{id, title, biome, segments, radio, board, choices:[{label, to}]}`.
   Story legs are hand-authored segment lists, not generated from recipes like `levels.gd`.
3. Terrain: add `stop`, `steep` and `ceiling` segments. Level: mode = arcade | story, stop sub-state,
   passenger count.
4. Story map screen (the branch graph with legs you've played), plus radio cards between legs.
5. Save the route, flags and passengers in `GameState`. Add a STORY entry to the main menu.
6. Extend the bot so `--botall` can still prove every leg can be beaten.

### Questions for us

- Should a missed stop fail the leg, or just cost points and annoy the passenger?
- Should the endings be about the driver (retirement) or the passengers (everyone gets home)?
- Does Story keep the stars-and-grade system, or use a different score (fares and tips)?

---

## 2.5D

The goal: make the world feel deep without losing the crisp 2D physics that makes it fun.

| Option | What it looks like | Cost | Risk |
|--------|--------------------|------|------|
| **A. Depth cues** (recommended first) | Far-side wheels peeking out under the body, a soft drop shadow under the bus that stretches with height (helps judge landings), a thin road **top plane** above the side face (lane line drawn on top), and props split into behind-road and in-front-of-road rows | Days | Low. Physics stays the same. |
| **B. 3D bus, 2D world** | The bus rendered from a low-poly 3D model in a SubViewport, camera tilted 15–20°, so you see the roof rack and front. Composited as a sprite and driven by the same 2D rigid bodies | 1–2 weeks | Medium. Breaking apart and the riders need rework. |
| **C. Full 3D presentation** | 3D terrain, backdrop and props with a perspective camera. 2D physics mapped onto the XY plane | Large | High. Rewrites terrain, backdrop, props and life. |

Plan: build **A** behind a toggle. The drop shadow alone probably improves landings. Then decide
whether **B** is worth it after playing with A.
