# Audio

All 16 music tracks and all 82 sound effects are generated with the ElevenLabs CLI (`elevenlabs`,
npm `@elevenlabs/cli`) by `tools/gen_elevenlabs.py`. That script's `SFX` and `MUSIC`
tables are the source of truth.

## Sound identity

The new audio was written from the game's own places, moods and moments (each world, rocket
burns, landings, crashes, the mudslide, the city at night), not by describing or imitating
the old synth sounds or the Kevin MacLeod tracks it replaces.

Every music track shares one signature palette so Rocket Bus has a sound you'd recognise:
- a honking baritone sax hook, like the bus horn turned into an instrument
- a buzzy analog synth bass
- hand claps
- quick rising synth whooshes, like the rocket igniting

Each world bends that palette to its mood: dusty canyon swagger, a humid rain-soaked
jungle, tense blizzard, scorching lava, weightless moon, and a bittersweet last shift at night.

## How it fits together

- `Audio.music("music_<name>")` plays `assets/music/<name>.ogg`. If there is no ogg, it falls
  back to the synthesized `assets/audio/music_<name>.wav` from `tools/gen_audio.py`.
- Each world's default track is the `music` key in `scripts/world/biomes.gd`. A level
  (the `music` option in `scripts/game/levels.gd`) or a story leg (the `music` key in
  `scripts/game/story.gd`) can override it, and `World.start_ambience()` plays the override.
- Sound effects are still `assets/audio/<name>.wav` with the same names as before, so every
  `Audio.play(...)` call is unchanged. Each new file is loudness-matched to the synth file
  it replaced, so the `volume_db` values in code still balance. That matching is only about
  the mix level, not the sound. The levels are recorded in `tools/elevenlabs_levels.json`.
  Real recordings measure quieter than the old square-wave synth at the same perceived
  loudness, so a few core sounds were raised in code: engine +4 dB and rocket +5 dB
  (`bus_audio.gd`), and horn +3 dB.
- New hooks: `ash_loop` (ash weather, `weather.gd`), `mudslide_loop` (the chase in
  `chase.gd`, louder as the wave nears the middle of the screen and fading out when the
  run ends; it replaces the repeated thunder claps).
- Ultra-short UI, scoring, and voice cues (`ui_move`, `score_tick`, `typewriter`, `count_beep`,
  `voice_blip`, etc.) are capped via `MAX_SEC` in `tools/gen_elevenlabs.py` with a peak-relative
  silence trim and proportional fade-out so ElevenLabs' 0.5 s minimum length stays snappy in-game.

## Which track plays where

| Where | Track |
|---|---|
| Menu, story map, bus lab, intro | `menu` |
| Results screen | `results` |
| Comet exit | `comet` |
| Desert world (levels 1-4), story Water Run and Canyon Stops | `desert` |
| Jungle world (levels 5-7), story River Crossing | `jungle` |
| Temple Drop (level 8), story Temple Shortcut (night) | `temple` |
| Story Mudslide chase | `mudslide` |
| Mountain world (levels 9-12) | `mountain` |
| Snow: First Frost, Frozen Lake | `snow` |
| Snow: Avalanche Alley, Polar Express (blizzard) | `blizzard` |
| Volcano world (levels 17-19) | `volcano` |
| The Last Stop (level 20, volcano finale) | `finale` |
| Moon world (levels 21-24) | `moon` |
| Border floating islands (level 25) | `border` |
| City biome default, story First Shift (dawn) | `city_dawn` |
| Story The Last Stop (city at night, final leg) | `city_night` |

## Regenerating

```bash
python3 tools/gen_elevenlabs.py                 # make anything missing
python3 tools/gen_elevenlabs.py --regen horn    # reroll one take
python3 tools/gen_elevenlabs.py --process-only  # re-run ffmpeg only (no credits)
godot --headless --path . --import && python3 tools/fix_audio_imports.py && godot --headless --path . --import
```

If a new `_loop.wav` doesn't loop in game, the import cache is stale (this happened once
with `mudslide_loop`): delete `.godot/imported/<name>.wav-*` and re-import.

Raw takes are cached in `tools/elevenlabs_raw/` (git-ignored). Processing:
- **Sound effects:** trim silence from one-shots, convert to mono 16-bit 44.1 kHz, match the
  old file's mean volume (up to 6 dB of limiting, 10 dB for loops), and add a 50 ms fade-out.
- **Music:** trim silence, apply loudnorm at -13 LUFS (about the level of the old tracks),
  cut any quiet intro or fade-out ending (`_body()`), then crossfade the last 2 s into the
  start. The loop has no click or volume dip, but the beat isn't guaranteed to line up.
  Encode to Vorbis at q4 (about 128 kbps) with `oggenc` (Homebrew ffmpeg has
  no libvorbis).
- `fix_audio_imports.py` sets `loop=true` on every `assets/music/*.ogg`.
- The synthesized `music_*.wav` loops were deleted, since the oggs replace all of them.
  `gen_audio.py` builds one only when you name it.

Cost on the Creator plan (measured): about 11 credits per second of sound effect, about
800 credits per minute of music. The full set of 51 sound effects and 16 tracks (about
20 minutes of music) used about 18.4k credits.

Licensing: see CREDITS.md. Creator-plan output may be used commercially in an indie game,
no attribution required.

## Prompts

Every music prompt starts with this shared style line:

> Original instrumental soundtrack for Rocket Bus, a playful pixel-art game about an old city bus driver close to retirement who straps a rocket to his bus. Signature sound in every track: a honking baritone saxophone hook like a bus horn, a buzzy analog synth bass, hand claps, and quick rising synth whooshes like a rocket igniting. Seamless loop, starts immediately with no intro, no fade out, no ending, steady energy.

### Music

| Track | Length | Prompt |
|---|---|---|
| `menu` | 75s | Theme song. The bus revs up for another shift: swaggering, catchy and cheeky, a stop-start groove with a big honking sax hook and rocket-whoosh risers, 128 BPM, makes you grin. |
| `results` | 45s | After the run, the driver counts the tips: laid-back and satisfied, warm electric piano, soft sax honks, gentle clap groove, 100 BPM. |
| `comet` | 45s | The bus leaves the atmosphere as a blazing comet: euphoric and triumphant, soaring sax hook over racing drums and glittering synth arpeggios, 172 BPM, pure joy. |
| `city_dawn` | 80s | First shift at dawn as the city wakes up: hopeful, sleepy and sweet, soft muted sax, glockenspiel, light clap groove, coffee and sunrise, 92 BPM. |
| `city_night` | 90s | The very last shift through a glowing city at night: bittersweet, proud and tender, a slow warm sax melody over soft synth pads and a gentle heartbeat groove, neon reflected on wet streets, 80 BPM. |
| `desert` | 85s | Crossing blazing canyons under a white-hot sun: dusty and swaggering heat shimmer, stomping kick and claps, wobbling synth bass, sax honks echoing off canyon walls, 120 BPM. |
| `jungle` | 85s | A rain-soaked jungle road: humid and bouncy, wet wooden percussion, splashy rhythms, chirping synth blips like tree frogs, playful sax, 112 BPM. |
| `temple` | 80s | Sneaking past an ancient temple at night: hushed suspense, deep hand drums, breathy low sax, creeping bass, glowing eyes in the dark, 96 BPM. |
| `mudslide` | 75s | A mountain of mud is chasing the bus: frantic comic panic, breakneck drums, screaming sax runs, siren-like synth, every second counts, 168 BPM. |
| `mountain` | 85s | Climbing switchbacks to the summit: big open skies, determined and uplifting, thumping stomp-clap beat, bold sax hook, wide synth chords, 126 BPM. |
| `snow` | 80s | Sliding on icy roads: crisp, sparkly and mischievous, chiming bells, bouncy bass, light sax honks, a slippery off-beat rhythm, 108 BPM. |
| `blizzard` | 80s | Driving blind into a howling blizzard: tense and urgent, pulsing low synth, cold metallic hits, a distant sax wail, 124 BPM. |
| `volcano` | 85s | The floor is lava: scorching, aggressive and fun, pounding drums, gritty distorted synth bass, blasting sax riffs, eruptions, 156 BPM. |
| `finale` | 85s | The final run through erupting volcanoes, everyone off at the last stop: climactic and heroic, huge drums, choir-like synth pads, the sax hook at full power, 148 BPM. |
| `moon` | 85s | Bouncing across the moon in low gravity: weightless, wonder-struck and goofy, slow floating synths, soft echoing sax, half-time beat, 88 BPM. |
| `border` | 80s | Floating islands at the edge of the world: strange and dreamlike, glassy chimes, warped pads, a lopsided 7/8 pulse, the sax motif drifting and reversed, 90 BPM. |

All music is made with `force_instrumental: true` and output format `mp3_44100_192`.

### Sound effects

All use `prompt_influence: 0.5`. Loops use `loop: true`.

| File | Seconds | Loop | Prompt |
|---|---|---|---|
| `engine_loop` | 4.0 | yes | Steady idle of an old rattly diesel city bus engine, constant RPM, low chugging rumble, no revving, no gear changes |
| `rocket_loop` | 4.0 | yes | A city bus strapped to a rocket, mid-burn: roaring blue-flame thrust with the rattling metal bus body shaking underneath, powerful and steady |
| `wind_loop` | 6.0 | yes | Fast rushing wind whooshing past a moving vehicle, airborne, steady |
| `rocket_ignite` | 1.5 |  | The rocket strapped to a bus kicks in: sharp ignition crack, whoomp of flame, the bus lurching with a metal clunk |
| `rocket_sputter` | 1.2 |  | Rocket engine sputtering out of fuel, coughing pops and a weak dying hiss |
| `vroom` | 2.0 |  | Old diesel bus revving its engine hard then pulling away, cartoonish vroom |
| `horn` | 1.2 |  | A beloved old bus's horn: big brassy two-tone honk, cheerful and a bit silly, instantly recognisable |
| `land_soft` | 0.8 |  | A bus touching down perfectly after a stunt jump: satisfying springy tire bounce, soft thud, a happy suspension squeak |
| `land_hard` | 1.2 |  | A bus slamming down after a huge jump: brutal chassis bang, springs bottoming out, panels rattling, luggage jumping |
| `crash` | 2.5 |  | A rocket-powered bus wrecking: crunching sheet metal, rolling impacts, glass bursting, a hubcap clattering away, the rocket fizzling out |
| `skid` | 1.0 |  | Bus tires skidding on gravel and asphalt, short screech |
| `glass` | 1.5 |  | Bus window glass shattering, shards tinkling |
| `creak_a` | 1.0 |  | Old metal bus frame groaning under stress, deep metallic creak |
| `creak_b` | 0.9 |  | Rusty steel chassis twisting, short squealing metal creak |
| `creak_c` | 1.1 |  | Old vehicle body flexing, low wooden and metal groan |
| `spring_creak` | 0.6 |  | Squeaky old leaf spring suspension compressing once, short boing creak |
| `rattle` | 0.8 |  | Loose metal panels and windows rattling on a bumpy road, short burst |
| `comet_whoosh` | 3.0 |  | Huge fiery whoosh, something launching into the sky like a comet, rising roar with crackling fire |
| `fall_whistle` | 2.0 |  | Classic cartoon falling whistle, descending pitch slide |
| `splash` | 2.0 |  | Big heavy vehicle plunging into deep water, huge splash |
| `bubbles` | 2.0 |  | Large air bubbles rising underwater, glugging |
| `mud_splash` | 1.2 |  | Tires splashing through thick wet mud, squelchy slop |
| `lava_sizzle` | 2.0 |  | Metal falling into molten lava, violent hiss and sizzle, bubbling |
| `splat` | 0.8 |  | Cartoonish wet gory splat, squishy impact |
| `squelch` | 0.8 |  | Wet squelch, squishy gooey impact |
| `clank` | 0.7 |  | Small metal object clanking on rocks, tinny bounce |
| `thunder` | 4.0 |  | Loud crack of thunder with a long rolling rumble |
| `cheer` | 2.0 |  | Small group of bus passengers cheering and whooping happily, short |
| `groan` | 1.5 |  | Small group of bus passengers groaning in disappointment, short |
| `sigh` | 1.2 |  | Tired old man sighing heavily |
| `voice_scream` | 1.5 |  | Cartoonish group scream of terrified bus passengers, short |
| `rain_loop` | 8.0 | yes | Steady heavy rain falling on a jungle and a metal bus roof, no thunder |
| `sandstorm_loop` | 8.0 | yes | Howling desert sandstorm, gusting wind, sand hissing against metal |
| `blizzard_loop` | 8.0 | yes | Fierce howling blizzard wind, whistling snow gusts, icy and cold |
| `ash_loop` | 8.0 | yes | Ash storm near an erupting volcano, low wind, distant deep rumbling, soft crackling embers falling |
| `mudslide_loop` | 6.0 | yes | Massive mudslide roaring downhill, deep earth rumble, sliding mud, cracking trees and tumbling rocks |
| `bug_buzz_loop` | 4.0 | yes | Swarm of jungle insects buzzing close by |
| `amb_city_loop` | 10.0 | yes | City street ambience, distant traffic, birds, faint voices, early morning |
| `amb_desert_loop` | 10.0 | yes | Hot desert ambience, dry wind, distant hawk cry, buzzing heat, sparse |
| `amb_jungle_loop` | 10.0 | yes | Dense tropical jungle ambience, exotic birds, insects, distant monkeys |
| `amb_mountain_loop` | 10.0 | yes | High mountain ambience, cold wind through pine trees, distant eagle |
| `amb_snow_loop` | 10.0 | yes | Quiet snowy tundra ambience, soft cold wind, faint creaking ice |
| `amb_volcano_loop` | 10.0 | yes | Volcano ambience, deep rumbling, bubbling lava, hissing steam vents |
| `amb_moon_loop` | 10.0 | yes | Eerie space ambience on the moon, low humming drone, faint radio static |
| `amb_border_loop` | 10.0 | yes | Mysterious floating sky islands ambience, airy wind, soft ethereal shimmering tones, distant chimes |
| `bird_chirp` | 1.0 |  | Small flock of birds chirping, startled |
| `bird_flap` | 1.2 |  | Flock of birds suddenly taking off, flapping wings |
| `monkey_screech` | 1.2 |  | Monkey screeching angrily in a jungle |
| `goat_bleat` | 1.0 |  | Mountain goat bleating once, funny |
| `vulture_caw` | 1.0 |  | Vulture caw, raspy bird call in the desert |
| `penguin_squawk` | 0.8 |  | Penguin squawk, short honking call |
