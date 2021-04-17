#!/usr/bin/env python3
"""Independent, standard-library acceptance checks against the actual CLI."""
from pathlib import Path
import hashlib
import json
import math
import struct
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / 'bin' / 'murmur'


def run(*args, ok=True):
    result = subprocess.run([str(CLI), *map(str, args)], text=True, capture_output=True, timeout=120)
    if ok:
        assert result.returncode == 0, (args, result.returncode, result.stdout, result.stderr)
    else:
        assert result.returncode in (1, 2), (args, result.returncode, result.stderr)
    return result


def write_pcm(path, samples, rate=8000, channels=1):
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(channels)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(struct.pack('<' + 'h' * len(samples), *samples))


def project(path, source, mode='mute', effects=''):
    path.write_text(f'''(murmur (version 1) (rate 12000) (channels 2) (seed 7)
      (source field (path "{source.name}"))
      (redact field (from 0.05) (to 0.10) (guard 0) (mode {mode}) (level-db -24))
      (clip first (source field) (from 0) (to 0.25) (at 0.02) (fade-in 0.001))
      (clip repeated (source field) (from 0.025) (to 0.20) (at 0.10) (gain-db -12))
      {effects}
      (effect limit (ceiling-db -2)))\n''')


def noninterference(base, mode='mute', effects=''):
    samples = [round(5000 * math.sin(i * 0.17)) for i in range(2000)]
    changed = samples.copy()
    for i in range(400, 800):
        changed[i] = ((i * 7919) % 60000) - 30000
    write_pcm(base / 'a.wav', samples)
    write_pcm(base / 'b.wav', changed)
    for name in ('a', 'b'):
        project(base / f'{name}.mur', base / f'{name}.wav', mode, effects)
        run('render', base / f'{name}.mur', base / f'{name}-out', '--block-size', '137')
    left, right = base / 'a-out', base / 'b-out'
    names = sorted(p.name for p in left.iterdir())
    assert names == sorted(p.name for p in right.iterdir())
    differences = [n for n in names if (left / n).read_bytes() != (right / n).read_bytes()]
    assert not differences, f'Forbidden samples influenced publication files: {differences}'
    return {n: hashlib.sha256((left / n).read_bytes()).hexdigest() for n in names}


def main():
    with tempfile.TemporaryDirectory(prefix='murmur-acceptance-') as temp:
        report = {'noninterference': noninterference(Path(temp))}
        print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
