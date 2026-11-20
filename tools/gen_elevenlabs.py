#!/usr/bin/env python3
"""Generates Rocket Bus sound effects and music with the ElevenLabs CLI.

The SFX and MUSIC tables below are the source of truth for every generated
file and the prompt that made it (see docs/audio.md).

  python3 tools/gen_elevenlabs.py                 # generate anything missing, then process
  python3 tools/gen_elevenlabs.py horn crash      # only these names
  python3 tools/gen_elevenlabs.py --regen horn    # throw away the cached take and generate again
  python3 tools/gen_elevenlabs.py --process-only  # re-run ffmpeg on cached takes (no credits)

Needs `elevenlabs` (npm @elevenlabs/cli, logged in with `elevenlabs auth login`), ffmpeg and
oggenc (brew install vorbis-tools).
Raw takes are cached in tools/elevenlabs_raw/ (git-ignored, .gdignore'd) so
reprocessing never spends credits. Then import:
  godot --headless --path . --import && python3 tools/fix_audio_imports.py && godot --headless --path . --import

SFX are written over assets/audio/<name>.wav (mono 16-bit 44.1 kHz), loudness
matched to the synth file they replace so the volume_db values in code still
hold. tools/gen_audio.py skips every name listed here unless you name it
(see its _eleven_names()).
Music is written to assets/music/<name>.ogg with the tail crossfaded into the
head so it loops without a seam.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
RAW = os.path.join(ROOT, "tools", "elevenlabs_raw")
SFX_OUT = os.path.join(ROOT, "assets", "audio")
MUSIC_OUT = os.path.join(ROOT, "assets", "music")

# name: (prompt, seconds, loop)  -- seconds=None lets the model pick.
SFX = {
    # --- the bus -------------------------------------------------------------
    "engine_loop": ("Steady idle of an old rattly diesel city bus engine, constant RPM, low chugging "
                    "rumble, no revving, no gear changes", 4.0, True),
    "rocket_loop": ("A city bus strapped to a rocket, mid-burn: roaring blue-flame thrust with the "
                    "rattling metal bus body shaking underneath, powerful and steady", 4.0, True),
    "wind_loop": ("Fast rushing wind whooshing past a moving vehicle, airborne, steady", 6.0, True),
    "rocket_ignite": ("The rocket strapped to a bus kicks in: sharp ignition crack, whoomp of flame, "
                      "the bus lurching with a metal clunk", 1.5, False),
    "rocket_sputter": ("Rocket engine sputtering out of fuel, coughing pops and a weak dying hiss", 1.2, False),
    "vroom": ("Old diesel bus revving its engine hard then pulling away, cartoonish vroom", 2.0, False),
    "horn": ("A beloved old bus's horn: big brassy two-tone honk, cheerful and a bit silly, instantly "
              "recognisable", 1.2, False),
    "land_soft": ("A bus touching down perfectly after a stunt jump: satisfying springy tire bounce, "
                  "soft thud, a happy suspension squeak", 0.8, False),
    "land_hard": ("A bus slamming down after a huge jump: brutal chassis bang, springs bottoming out, "
                  "panels rattling, luggage jumping", 1.2, False),
    "crash": ("A rocket-powered bus wrecking: crunching sheet metal, rolling impacts, glass bursting, a "
              "hubcap clattering away, the rocket fizzling out", 2.5, False),
    "skid": ("Bus tires skidding on gravel and asphalt, short screech", 1.0, False),
    "glass": ("Bus window glass shattering, shards tinkling", 1.5, False),
    "creak_a": ("Old metal bus frame groaning under stress, deep metallic creak", 1.0, False),
    "creak_b": ("Rusty steel chassis twisting, short squealing metal creak", 0.9, False),
    "creak_c": ("Old vehicle body flexing, low wooden and metal groan", 1.1, False),
    "spring_creak": ("Squeaky old leaf spring suspension compressing once, short boing creak", 0.6, False),
    "rattle": ("Loose metal panels and windows rattling on a bumpy road, short burst", 0.8, False),
    "comet_whoosh": ("Huge fiery whoosh, something launching into the sky like a comet, rising roar "
                     "with crackling fire", 3.0, False),
    "fall_whistle": ("Classic cartoon falling whistle, descending pitch slide", 2.0, False),
    # --- what the bus hits ----------------------------------------------------
    "splash": ("Big heavy vehicle plunging into deep water, huge splash", 2.0, False),
    "bubbles": ("Large air bubbles rising underwater, glugging", 2.0, False),
    "mud_splash": ("Tires splashing through thick wet mud, squelchy slop", 1.2, False),
    "lava_sizzle": ("Metal falling into molten lava, violent hiss and sizzle, bubbling", 2.0, False),
    "splat": ("Cartoonish wet gory splat, squishy impact", 0.8, False),
    "squelch": ("Wet squelch, squishy gooey impact", 0.8, False),
    "clank": ("Small metal object clanking on rocks, tinny bounce", 0.7, False),
    "thunder": ("Loud crack of thunder with a long rolling rumble", 4.0, False),
    # --- passengers -------------------------------------------------------------
    "cheer": ("Small group of bus passengers cheering and whooping happily, short", 2.0, False),
    "groan": ("Small group of bus passengers groaning in disappointment, short", 1.5, False),
    "sigh": ("Tired old man sighing heavily", 1.2, False),
    "voice_scream": ("Cartoonish group scream of terrified bus passengers, short", 1.5, False),
    # --- weather and world loops -----------------------------------------------
    "rain_loop": ("Steady heavy rain falling on a jungle and a metal bus roof, no thunder", 8.0, True),
    "sandstorm_loop": ("Howling desert sandstorm, gusting wind, sand hissing against metal", 8.0, True),
    "blizzard_loop": ("Fierce howling blizzard wind, whistling snow gusts, icy and cold", 8.0, True),
    "ash_loop": ("Ash storm near an erupting volcano, low wind, distant deep rumbling, soft crackling "
                 "embers falling", 8.0, True),
    "mudslide_loop": ("Massive mudslide roaring downhill, deep earth rumble, sliding mud, cracking trees "
                      "and tumbling rocks", 6.0, True),
    "bug_buzz_loop": ("Swarm of jungle insects buzzing close by", 4.0, True),
    "amb_city_loop": ("City street ambience, distant traffic, birds, faint voices, early morning", 10.0, True),
    "amb_desert_loop": ("Hot desert ambience, dry wind, distant hawk cry, buzzing heat, sparse", 10.0, True),
    "amb_jungle_loop": ("Dense tropical jungle ambience, exotic birds, insects, distant monkeys", 10.0, True),
    "amb_mountain_loop": ("High mountain ambience, cold wind through pine trees, distant eagle", 10.0, True),
    "amb_snow_loop": ("Quiet snowy tundra ambience, soft cold wind, faint creaking ice", 10.0, True),
    "amb_volcano_loop": ("Volcano ambience, deep rumbling, bubbling lava, hissing steam vents", 10.0, True),
    "amb_moon_loop": ("Eerie space ambience on the moon, low humming drone, faint radio static", 10.0, True),
    "amb_border_loop": ("Mysterious floating sky islands ambience, airy wind, soft ethereal shimmering "
                        "tones, distant chimes", 10.0, True),
    # --- wildlife --------------------------------------------------------------
    "bird_chirp": ("Small flock of birds chirping, startled", 1.0, False),
    "bird_flap": ("Flock of birds suddenly taking off, flapping wings", 1.2, False),
    "monkey_screech": ("Monkey screeching angrily in a jungle", 1.2, False),
    "goat_bleat": ("Mountain goat bleating once, funny", 1.0, False),
    "vulture_caw": ("Vulture caw, raspy bird call in the desert", 1.0, False),
    "penguin_squawk": ("Penguin squawk, short honking call", 0.8, False),
}

# Written from each place's mood and moment, not from the old soundtrack. Every track
# shares one signature sound so the game has a recognisable identity.
MUSIC_STYLE = ("Original instrumental soundtrack for Rocket Bus, a playful pixel-art game about an old "
               "city bus driver close to retirement who straps a rocket to his bus. Signature sound in "
               "every track: a honking baritone saxophone hook like a bus horn, a buzzy analog synth "
               "bass, hand claps, and quick rising synth whooshes like a rocket igniting. Seamless "
               "loop, starts immediately with no intro, no fade out, no ending, steady energy. ")

# name: (prompt, seconds). Written as assets/music/<name>.ogg, played as Audio.music("music_<name>").
MUSIC = {
    "menu": ("Theme song. The bus revs up for another shift: swaggering, catchy and cheeky, a "
             "stop-start groove with a big honking sax hook and rocket-whoosh risers, 128 BPM, makes "
             "you grin.", 75),
    "results": ("After the run, the driver counts the tips: laid-back and satisfied, warm electric "
                "piano, soft sax honks, gentle clap groove, 100 BPM.", 45),
    "comet": ("The bus leaves the atmosphere as a blazing comet: euphoric and triumphant, soaring sax "
              "hook over racing drums and glittering synth arpeggios, 172 BPM, pure joy.", 45),
    "city_dawn": ("First shift at dawn as the city wakes up: hopeful, sleepy and sweet, soft muted sax, "
                  "glockenspiel, light clap groove, coffee and sunrise, 92 BPM.", 80),
    "city_night": ("The very last shift through a glowing city at night: bittersweet, proud and tender, "
                   "a slow warm sax melody over soft synth pads and a gentle heartbeat groove, neon "
                   "reflected on wet streets, 80 BPM.", 90),
    "desert": ("Crossing blazing canyons under a white-hot sun: dusty and swaggering heat shimmer, "
               "stomping kick and claps, wobbling synth bass, sax honks echoing off canyon walls, "
               "120 BPM.", 85),
    "jungle": ("A rain-soaked jungle road: humid and bouncy, wet wooden percussion, splashy rhythms, "
               "chirping synth blips like tree frogs, playful sax, 112 BPM.", 85),
    "temple": ("Sneaking past an ancient temple at night: hushed suspense, deep hand drums, breathy "
               "low sax, creeping bass, glowing eyes in the dark, 96 BPM.", 80),
    "mudslide": ("A mountain of mud is chasing the bus: frantic comic panic, breakneck drums, "
                 "screaming sax runs, siren-like synth, every second counts, 168 BPM.", 75),
    "mountain": ("Climbing switchbacks to the summit: big open skies, determined and uplifting, "
                 "thumping stomp-clap beat, bold sax hook, wide synth chords, 126 BPM.", 85),
    "snow": ("Sliding on icy roads: crisp, sparkly and mischievous, chiming bells, bouncy bass, light "
             "sax honks, a slippery off-beat rhythm, 108 BPM.", 80),
    "blizzard": ("Driving blind into a howling blizzard: tense and urgent, pulsing low synth, cold "
                 "metallic hits, a distant sax wail, 124 BPM.", 80),
    "volcano": ("The floor is lava: scorching, aggressive and fun, pounding drums, gritty distorted "
                "synth bass, blasting sax riffs, eruptions, 156 BPM.", 85),
    "finale": ("The final run through erupting volcanoes, everyone off at the last stop: climactic and "
               "heroic, huge drums, choir-like synth pads, the sax hook at full power, 148 BPM.", 85),
    "moon": ("Bouncing across the moon in low gravity: weightless, wonder-struck and goofy, slow "
             "floating synths, soft echoing sax, half-time beat, 88 BPM.", 85),
    "border": ("Floating islands at the edge of the world: strange and dreamlike, glassy chimes, "
               "warped pads, a lopsided 7/8 pulse, the sax motif drifting and reversed, 90 BPM.", 80),
}

XFADE = 2.0  # seconds of tail crossfaded into the head of each music loop


def run(cmd, **kw):
    return subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, **kw)


def eleven(args, body, out):
    r = subprocess.run(["elevenlabs"] + args + ["--json", "-", "-o", out], input=json.dumps(body),
                       capture_output=True, text=True, timeout=600)
    if r.returncode != 0 or not os.path.exists(out):
        raise RuntimeError("elevenlabs failed for %s: %s %s" % (out, r.stdout[-500:], r.stderr[-500:]))


def gen_sfx(name):
    prompt, secs, loop = SFX[name]
    body = {"text": prompt, "prompt_influence": 0.5, "loop": loop}
    if secs:
        body["duration_seconds"] = secs
    eleven(["text-to-sound-effects", "convert", "--output-format", "mp3_44100_192"], body, raw(name))


def gen_music(name):
    prompt, secs = MUSIC[name]
    body = {"prompt": MUSIC_STYLE + prompt, "music_length_ms": int(secs * 1000), "force_instrumental": True}
    eleven(["music", "compose", "--output-format", "mp3_44100_192"], body, raw("music_" + name))


def raw(name):
    return os.path.join(RAW, name + ".mp3")


def volume(path):
    r = run(["ffmpeg", "-hide_banner", "-i", path, "-af", "volumedetect", "-f", "null", "-"])
    mean = float(re.search(r"mean_volume: (-?[\d.]+)", r.stderr).group(1))
    peak = float(re.search(r"max_volume: (-?[\d.]+)", r.stderr).group(1))
    return mean, peak


def duration(path):
    return float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]).stdout)


def process_sfx(name):
    _, _, loop = SFX[name]
    out = os.path.join(SFX_OUT, name + ".wav")
    tmp = os.path.join(RAW, name + ".tmp.wav")
    # Loops stay whole (ElevenLabs made them seamless); one-shots lose silence at both ends.
    trim = [] if loop else ["-af", "silenceremove=start_periods=1:start_threshold=-50dB,areverse,"
                            "silenceremove=start_periods=1:start_threshold=-55dB,areverse"]
    run(["ffmpeg", "-y", "-hide_banner", "-i", raw(name)] + trim + ["-ac", "1", "-ar", "44100", tmp], check=True)
    mean, peak = volume(tmp)
    # Mean level (dB) of the synth file this replaces, recorded once in elevenlabs_levels.json
    # so reprocessing is repeatable; new names fall back to MATCH.
    target = LEVELS.get(name, MATCH.get(name, -16.0))
    # Match the old file's average level, letting a limiter take at most 6 dB of peaks
    # (10 dB for steady loops like the engine and rocket, which limit cleanly).
    gain = min(target - mean, (-1.0 - peak) + (10.0 if loop else 6.0))
    fx = "volume=%.2fdB,alimiter=limit=0.89:level=false" % gain
    if not loop:
        fx += ",afade=t=out:st=%.3f:d=0.05" % max(0.0, duration(tmp) - 0.05)
    run(["ffmpeg", "-y", "-hide_banner", "-i", tmp, "-af", fx, "-c:a", "pcm_s16le", out], check=True)
    os.remove(tmp)
    return gain


def process_music(name):
    src = raw("music_" + name)
    out = os.path.join(MUSIC_OUT, name + ".ogg")
    tmp = os.path.join(RAW, name + ".trim.wav")
    run(["ffmpeg", "-y", "-hide_banner", "-i", src, "-af",
         "silenceremove=start_periods=1:start_threshold=-60dB,areverse,"
         "silenceremove=start_periods=1:start_threshold=-60dB,areverse,loudnorm=I=-13:TP=-1.0:LRA=11",
         "-ar", "44100", tmp], check=True)
    start, end = _body(tmp)
    x = XFADE
    # Loop = crossfade(tail -> head) + middle, over the full-level body [start, end] (a quiet
    # intro or a fade-out would dip every loop). The end of the middle runs into the start
    # of the tail, and the crossfade ends on the head, so both seams are continuous.
    fc = ("[0:a]asplit=3[a][b][c];"
          "[a]atrim=%.3f:%.3f,asetpts=PTS-STARTPTS[tail];"
          "[b]atrim=%.3f:%.3f,asetpts=PTS-STARTPTS[head];"
          "[c]atrim=%.3f:%.3f,asetpts=PTS-STARTPTS[mid];"
          "[tail][head]acrossfade=d=%.3f:c1=tri:c2=tri[xf];"
          "[xf][mid]concat=n=2:v=0:a=1[out]") % (end - x, end, start, start + x, start + x, end - x, x)
    looped = os.path.join(RAW, name + ".loop.wav")
    run(["ffmpeg", "-y", "-hide_banner", "-i", tmp, "-filter_complex", fc, "-map", "[out]",
         "-c:a", "pcm_s16le", looped], check=True)
    run(["oggenc", "-Q", "-q", "4", "-o", out, looped], check=True)  # ffmpeg here has no libvorbis
    os.remove(tmp)
    os.remove(looped)


def _body(path, win=0.5):
    """(start, end) seconds of the part of a track that plays at full level: skips a quiet
    intro (6 dB under the track's average) and a fade-out or ending (3 dB under)."""
    import array
    import math
    sr = 11025
    pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(sr), "-f", "s16le", "-"],
                         stdin=subprocess.DEVNULL, capture_output=True, check=True).stdout
    a = array.array("h", pcm)
    n = int(win * sr)
    db = []
    for i in range(0, len(a) - n + 1, n):
        seg = a[i:i + n]
        rms = math.sqrt(sum(v * v for v in seg) / n) / 32768.0
        db.append(20 * math.log10(max(rms, 1e-6)))
    mean = 10 * math.log10(sum(10 ** (d / 10) for d in db) / len(db))
    first = next(i for i, d in enumerate(db) if d >= mean - 6)
    last = max(i for i, d in enumerate(db) if d >= mean - 3)
    return first * win, (last + 1) * win


# Loudness targets for new names with no synth file to match (mean dB).
MATCH = {"ash_loop": -14.0, "mudslide_loop": -12.0}
LEVELS_FILE = os.path.join(ROOT, "tools", "elevenlabs_levels.json")
LEVELS = json.load(open(LEVELS_FILE)) if os.path.exists(LEVELS_FILE) else {}


def main():
    args = sys.argv[1:]
    regen = "--regen" in args
    process_only = "--process-only" in args
    names = [a for a in args if not a.startswith("--")]
    os.makedirs(RAW, exist_ok=True)
    open(os.path.join(RAW, ".gdignore"), "a").close()
    jobs = [("sfx", n) for n in SFX] + [("music", n) for n in MUSIC]
    if names:
        jobs = [j for j in jobs if j[1] in names or ("music_" + j[1]) in names]
    for kind, name in jobs:
        path = raw(name if kind == "sfx" else "music_" + name)
        if regen and os.path.exists(path):
            os.remove(path)
        if not os.path.exists(path):
            if process_only:
                print("skip (no take):", name)
                continue
            print("generating %s %s ..." % (kind, name), flush=True)
            try:
                (gen_sfx if kind == "sfx" else gen_music)(name)
            except Exception as e:  # keep going; rerun picks up what's missing
                print("  FAILED:", e)
                continue
        if kind == "sfx":
            print("  %s.wav gain %+.1f dB" % (name, process_sfx(name)))
        else:
            process_music(name)
            print("  %s.ogg %.1fs" % (name, duration(os.path.join(MUSIC_OUT, name + ".ogg"))))


if __name__ == "__main__":
    main()
