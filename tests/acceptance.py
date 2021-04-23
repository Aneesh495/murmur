#!/usr/bin/env python3
"""Independent, standard-library acceptance checks against the actual CLI."""
from pathlib import Path
import hashlib
import json
import math
import re
import shutil
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


def decode_wave(path):
    raw = path.read_bytes()
    assert raw[:4] == b'RIFF' and raw[8:12] == b'WAVE'
    assert struct.unpack_from('<I', raw, 4)[0] + 8 == len(raw)
    at, fmt, data, chunks = 12, None, None, []
    while at < len(raw):
        name, size = struct.unpack_from('<4sI', raw, at)
        body = raw[at+8:at+8+size]
        assert len(body) == size
        chunks.append(name.decode('ascii'))
        if name == b'fmt ':
            fmt = struct.unpack_from('<HHIIHH', body)
            if fmt[0] == 65534:
                fmt = (struct.unpack_from('<H', body, 24)[0], *fmt[1:])
        if name == b'data':
            data = body
        at += 8 + size + size % 2
    assert at == len(raw) and fmt and data is not None
    tag, channels, rate, _, align, bits = fmt
    assert align == channels * (bits // 8) and len(data) % align == 0
    if tag == 1:
        width = bits // 8
        samples = [int.from_bytes(data[i:i+width], 'little', signed=True) / 2**(bits-1)
                   for i in range(0, len(data), width)]
    else:
        assert tag == 3 and bits in (32,64)
        samples = list(struct.unpack('<' + ('f' if bits == 32 else 'd') * (len(data)//(bits//8)), data))
    return rate, channels, samples, chunks


def independent_manifest(bundle):
    text = (bundle / 'manifest.mur').read_text()
    entries = re.findall(r'\(file "([a-z.]+)" "([0-9a-f]{64})"\)', text)
    assert len(entries) == 6 - 1
    for name, expected in entries:
        assert hashlib.sha256((bundle/name).read_bytes()).hexdigest() == expected, name
    receipt = json.loads((bundle/'receipt.json').read_text())
    for entry in receipt['files']:
        assert hashlib.sha256((bundle/entry['name']).read_bytes()).hexdigest() == entry['sha256']
    return len(entries)


def codec_and_meter(base):
    values = [-32768,-20000,-1,0,1,12345,32767] * 10
    write_pcm(base/'input.wav', values)
    (base/'edit.mur').write_text(f'''(murmur (version 1) (rate 8000) (channels 1)
      (source field (path "input.wav")) (clip exact (source field) (to {len(values)}/8000)))''')
    checked = []
    for name, options, tolerance in [('pcm16',[],0),('pcm24',['--bits','24'],0),('float32',['--float'],1e-7)]:
        out = base/name
        run('render',base/'edit.mur',out,'--no-dither',*options)
        rate, channels, samples, chunks = decode_wave(out/'audio.wav')
        assert rate == 8000 and channels == 1 and len(samples) == len(values)
        assert max(abs(x-y/32768) for x,y in zip(samples,values)) <= tolerance
        assert set(chunks) <= {'fmt ','fact','data'}
        analysis = json.loads((out/'analysis.json').read_text())['audio']
        m = analysis['channels'][0]
        assert abs(m['rms'] - math.sqrt(sum(x*x for x in samples)/len(samples))) < 1e-12
        assert abs(m['dc'] - sum(samples)/len(samples)) < 1e-12
        assert abs(m['peak'] - max(map(abs,samples))) < 1e-12
        independent_manifest(out)
        checked.append(name)
    return checked


def negative_controls(base):
    samples = [2000] * 2000
    changed = samples.copy(); changed[900] = 10000
    for name,values in [('a',samples),('b',changed)]:
        write_pcm(base/f'{name}.wav',values)
        project(base/f'{name}.mur',base/f'{name}.wav')
        run('render',base/f'{name}.mur',base/f'{name}-out')
    assert (base/'a-out/audio.wav').read_bytes() != (base/'b-out/audio.wav').read_bytes(), 'control outside forbidden region must change output'
    bundle = base/'a-out'
    original = (bundle/'audio.wav').read_bytes()
    (bundle/'audio.wav').write_bytes(original[:-1]+bytes([original[-1]^1]))
    result = run('verify',bundle,ok=False)
    assert 'checksum' in result.stderr
    (bundle/'audio.wav').write_bytes(original)
    (bundle/'unlisted.txt').write_text('extra')
    assert 'unlisted' in run('verify',bundle,ok=False).stderr
    return ['observable outside-region change','tamper rejection','unlisted-file rejection']


def main():
    report = {'privacy':{},'codec':None,'negativeControls':None}
    with tempfile.TemporaryDirectory(prefix='murmur-acceptance-') as temp:
        base = Path(temp)
        for mode in ('mute','tone','noise'):
            for name,effects in [('stream','(effect highpass (hz 90)) (effect compress)'),
                                  ('spectral','(effect denoise (profile-from 0) (profile-to 0.04) (size 64)) (effect normalize (peak-db -3))')]:
                case = base/f'{mode}-{name}'; case.mkdir()
                report['privacy'][f'{mode}-{name}'] = noninterference(case,mode,effects)
                independent_manifest(case/'a-out')
                raw_digest = hashlib.sha256((case/'a.wav').read_bytes()).hexdigest().encode()
                for artifact in (case/'a-out').iterdir():
                    assert raw_digest not in artifact.read_bytes(), 'raw source fingerprint escaped'
        codecs = base/'codecs'; codecs.mkdir()
        report['codec'] = codec_and_meter(codecs)
        controls = base/'controls'; controls.mkdir()
        report['negativeControls'] = negative_controls(controls)
    destination = ROOT/'build'/'acceptance.json'
    destination.parent.mkdir(exist_ok=True)
    destination.write_text(json.dumps(report,indent=2)+'\n')
    print('acceptance: 6 whole-bundle privacy pairs, 3 independent codecs, 3 negative controls passed')


if __name__ == '__main__':
    main()
