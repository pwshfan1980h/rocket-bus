#!/usr/bin/env python3
"""Sets import flags on generated audio: loop *_loop.wav and music_*.wav, keep PCM.

Run after Godot has imported new files, then re-import:
  godot --headless --path . --import && python3 tools/fix_audio_imports.py && godot --headless --path . --import
"""
import glob
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
changed = 0
for path in glob.glob(os.path.join(ROOT, "assets", "audio", "*.wav.import")):
    name = os.path.basename(path)[: -len(".wav.import")]
    s = open(path).read()
    loop = name.endswith("_loop") or name.startswith("music_")
    new = re.sub(r"edit/loop_mode=\d", "edit/loop_mode=%d" % (2 if loop else 0), s)
    new = re.sub(r"compress/mode=\d", "compress/mode=0", new)
    if new != s:
        open(path, "w").write(new)
        changed += 1
print("audio imports updated:", changed)
