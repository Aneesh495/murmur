#!/usr/bin/env python3
"""Deterministic bounded mutation campaign over external input boundaries."""
from pathlib import Path
import json
import random
import struct
import tempfile
from acceptance import ROOT, run, write_pcm

rng = random.Random(20261021)
counts = {'wave':0,'project':0,'manifest':0}
with tempfile.TemporaryDirectory(prefix='murmur-malformed-') as temp:
    base = Path(temp)
    wave_path = base/'input.wav'
    write_pcm(wave_path,[0,32767,-32768,1000]*16)
    original = wave_path.read_bytes()
    corpus = [original[:n] for n in range(45)]
    for _ in range(160):
        b=bytearray(original)
        for _ in range(rng.randint(1,4)):
            at=rng.randrange(min(68,len(b))); b[at]^=rng.randint(1,255)
        corpus.append(bytes(b))
    for data in corpus:
        wave_path.write_bytes(data)
        result=run('inspect',wave_path,ok=False) if len(data)<12 else None
        if result is None:
            import subprocess
            result=subprocess.run([str(ROOT/'bin/murmur'),'inspect',str(wave_path)],capture_output=True,text=True,timeout=10)
            assert result.returncode in (0,1), (result.returncode,result.stderr)
            if result.returncode==0:
                info=json.loads(result.stdout)
                assert 1<=info['channels']<=8 and 1<=info['rate']<=384000
        counts['wave']+=1
    project_path=base/'input.mur'
    data_cases=[b'',b'\xff',b'\xc0\xaf',b'\x00',b'#1=(x . #1#)',b'#.(system "touch sentinel")',
                b'('+b'x '*50001+b')',b'('*40+b'x'+b')'*40,
                b'"'+b'a'*4097+b'"',b'(1/0)',b'(murmur (version 1) (source))']
    data_cases += [bytes(rng.randrange(256) for _ in range(rng.randrange(1,200))) for _ in range(80)]
    for body in data_cases:
        project_path.write_bytes(body)
        run('plan',project_path,ok=False)
        counts['project']+=1
    bundle=base/'bundle'; bundle.mkdir()
    for entry in ['(file)','(file "x")','(file "../escape" "'+'0'*64+'")',
                  '(file x x)','(file () ())','(file "audio.wav" "bad")',
                  '(file "audio.wav" "'+'0'*64+'") '*5]:
        (bundle/'manifest.mur').write_text('(murmur-bundle (version 1) (rate 8000) (channels 1) (frames 0) '+entry+')')
        run('verify',bundle,ok=False)
        counts['manifest']+=1
(ROOT/'build').mkdir(exist_ok=True)
(ROOT/'build/malformed.json').write_text(json.dumps({'seed':20261021,'cases':counts},indent=2)+'\n')
print('malformed:',counts,'all rejected or decoded without internal errors')
