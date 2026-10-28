"""Optional local-asset regression suite; Python standard library only.

Runs every asset CLI into fresh build subdirectories, compares golden hashes,
validates PNG/WAV containers, and verifies input bytes remain unchanged.
"""
import argparse
import hashlib
import json
import re
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def digest(data):
    return hashlib.sha256(data).hexdigest()

def run(executable, *args, ok=True):
    p = subprocess.run([str(executable), *map(str,args)], cwd=ROOT, capture_output=True, text=True)
    if (p.returncode == 0) != ok:
        raise AssertionError(f'{executable.name}: exit {p.returncode}\n{p.stdout}\n{p.stderr}')
    return p

def png_pixels(path):
    data=path.read_bytes()
    assert data[:8]==b'\x89PNG\r\n\x1a\n'
    pos=8; compressed=bytearray(); width=height=None; ended=False
    while pos<len(data):
        size=struct.unpack_from('>I',data,pos)[0];tag=data[pos+4:pos+8]
        chunk=data[pos+8:pos+8+size]
        assert zlib.crc32(tag+chunk)&0xffffffff==struct.unpack_from('>I',data,pos+8+size)[0]
        pos+=size+12
        if tag==b'IHDR':
            width,height,depth,colour,compression,filter_,interlace=struct.unpack('>IIBBBBB',chunk)
            assert (depth,colour,compression,filter_,interlace)==(8,6,0,0,0)
        elif tag==b'IDAT': compressed.extend(chunk)
        elif tag==b'IEND': ended=True; break
    assert ended and pos==len(data)
    raw=zlib.decompress(compressed);stride=width*4+1
    assert len(raw)==height*stride
    assert all(raw[y*stride]==0 for y in range(height))
    return width,height,b''.join(raw[y*stride+1:(y+1)*stride] for y in range(height))

def indexed_frames(data):
    width,height,ox,oy,flags,count=struct.unpack_from('<hhhhHH',data,6)
    pos=18;frames=[]
    for _ in range(count):
        if flags&2:
            n=struct.unpack_from('<I',data,pos)[0];pos+=4
            encoded=data[pos:pos+n];pos+=n
            marker=encoded[0];cursor=0;pixels=bytearray()
            while len(pixels)<width*height:
                value=encoded[cursor];cursor+=1
                if value==marker:
                    repeat=encoded[cursor];cursor+=1;pixels.extend(bytes([marker])*repeat)
                else: pixels.append(value)
            assert len(pixels)==width*height and cursor==len(encoded)
        else:
            pixels=data[pos:pos+width*height];pos+=width*height
        frames.append(bytes(pixels))
    return width,height,flags,frames

def palette_tables():
    # Independent PNG comparison uses the established palette tables, not PNG output.
    source=(ROOT/'source/openbb/io/palette.d').read_text()
    result={}
    for name,body in re.findall(r'(\w+) = \(cast\(RGBA\*\) cast\(ubyte\[\]\) \[(.*?)\]',source,re.S):
        raw=bytes(int(v,16) for v in re.findall(r'0x([0-9A-Fa-f]{2})',body))
        assert len(raw)==1024,name
        result[name]=[raw[i:i+4] for i in range(0,1024,4)]
    return result

def check_sprite_sheet(png, mfb, name, palettes):
    width,height,flags,frames=indexed_frames(mfb)
    sw,sh,actual=png_pixels(png)
    cols=sw//width;rows=sh//height
    assert sw%width==0 and sh%height==0 and cols*rows>=len(frames)
    stem=Path(name).stem.lower()
    loading={'m1back','m2back','m3back','m4back','m5back','m7back','m9back','m11back','loading','credits','yakoff'}
    palette=palettes['LOADINGPALETTE' if stem in loading else 'MISSIONPALETTE' if stem=='mission' else 'PALETTE']
    # Native surfaces: raw frames each get a key; compressed frames share the
    # initial decoded surface key. See docs/asset-formats.md for code evidence.
    rgba=[b''.join(b'\0\0\0\0' if flags&1 and p==(frames[0][0] if flags&2 else f[0])
                   else palette[p] for p in f) for f in frames]
    empty=b'\xff\0\xff\xff'*(width*height)
    expected=bytearray()
    for row in range(rows):
        for y in range(height):
            for col in range(cols):
                i=row*cols+col;frame=rgba[i] if i<len(rgba) else empty
                expected.extend(frame[y*width*4:(y+1)*width*4])
    assert actual==expected,name

def check_cli_failures(output):
    """Exercise complete executables: bad resources must not become valid output."""
    def archive(name, payload):
        name = name.encode('ascii')
        return (b'BOX\0\0\0\1\0' + name + bytes(256-len(name)) + bytes(272)
                + struct.pack('<I',len(payload)) + payload)

    cases = [('unbox','../escape',b'x'),
             ('mfbdecoder','../escape.mfb',b'MFB'),
             ('m10decoder','../escape.m10',b'PT')]
    for tool,name,payload in cases:
        source=output/f'unsafe-{tool}.box';source.write_bytes(archive(name,payload))
        destination=output/f'unsafe-{tool}'
        run(ROOT/f'bin/{tool}.exe',source,destination,ok=False)
        assert not destination.exists(), 'Unsafe name must fail before mkdir'

    pt=b'PT\0\0'+struct.pack('<I',19)+bytes([0xfd,0x83,1,9,0x85,2,0x10,0,0x8a,0,0xff])+bytes(2)
    for tool,name,payload in [('mfbdecoder','broken.mfb',b'MFB'),
                              ('m10decoder','broken.m10',pt)]:
        source=output/f'truncated-{tool}.box';source.write_bytes(archive(name,payload))
        destination=output/f'truncated-{tool}'
        run(ROOT/f'bin/{tool}.exe',source,destination,ok=False)
        assert not list(destination.iterdir()), 'Decoder failure produced an output file'

    # All programs must refuse an existing directory without changing its contents.
    destination=output/'existing';destination.mkdir()
    sentinel=destination/'sentinel';sentinel.write_bytes(b'keep me')
    for tool,name in [('unbox','safe'),('mfbdecoder','safe.mfb'),('m10decoder','safe.m10')]:
        source=output/f'existing-{tool}.box';source.write_bytes(archive(name,b''))
        run(ROOT/f'bin/{tool}.exe',source,destination,ok=False)
        assert list(destination.iterdir())==[sentinel] and sentinel.read_bytes()==b'keep me'

def verify(game):
    golden=json.loads((ROOT/'tests/fixtures/corpus-hashes.json').read_text())
    expected_palettes=json.loads((ROOT/'tests/fixtures/palette-hashes.json').read_text())
    assert {name:digest(b''.join(values)) for name,values in palette_tables().items()}==expected_palettes, 'Palette table bytes changed'
    inputs=sorted([*game.glob('*.BOX'),*game.glob('*.FAT')])
    before={p.name:digest(p.read_bytes()) for p in inputs}
    for name,sha in golden['archives'].items():
        assert before.get(name)==sha,f'Corpus differs from the documented game edition: {name}'
    output=Path(tempfile.mkdtemp(prefix='corpus-',dir=ROOT/'build'))
    report={'output':str(output),'passed':False}
    try:
        run(ROOT/'build/asset-audit.exe',game,output/'native.json')
        native=json.loads((output/'native.json').read_text())
        by_key={(e['archive'],e['name']):e for e in native['entries']}
        assert len(by_key)==len(golden['entries'])
        for want in golden['entries']:
            got=by_key[want['archive'],want['name']]
            assert got==want,(want['archive'],want['name'])
        assert sorted(native['fat'],key=lambda b:b['file'])==sorted(golden['fat'],key=lambda b:b['file'])
        for tool in ('unbox','mfbdecoder','m10decoder'):
            run(ROOT/f'bin/{tool}.exe','--help')
            run(ROOT/f'bin/{tool}.exe',ok=False)
        palettes=palette_tables();sprite_count=speech_count=0
        for archive in sorted(game.glob('*.BOX')):
            print('Verifying',archive.name,flush=True)
            folder=output/archive.stem
            run(ROOT/'bin/unbox.exe',archive,folder)
            manifest=json.loads((folder/'_box_manifest.json').read_text())
            raw=archive.read_bytes();repacked=bytearray.fromhex(manifest['archive_header_hex'])
            assert len(list(folder.iterdir()))==len(manifest['entries'])+1
            for e in manifest['entries']:
                payload=(folder/e['name']).read_bytes()
                assert digest(payload)==e['sha256']==by_key[archive.name,e['name']]['sha256']
                repacked.extend(bytes.fromhex(e['header_hex']));repacked.extend(payload)
            assert repacked==raw,archive.name
            if archive.name=='VIDEO.BOX':
                images=output/'png'
                run(ROOT/'bin/mfbdecoder.exe',archive,images)
                assert len(list(images.glob('*.png')))==624
                for e in manifest['entries']:
                    check_sprite_sheet(images/(Path(e['name']).stem+'.png'),
                                       (folder/e['name']).read_bytes(),e['name'],palettes)
                    sprite_count+=1
            elif archive.name.startswith('SPEECH'):
                sound=output/(archive.stem+'-wav')
                run(ROOT/'bin/m10decoder.exe',archive,sound)
                assert len(list(sound.glob('*.wav')))==len(manifest['entries'])
                for e in manifest['entries']:
                    wav=(sound/(Path(e['name']).stem+'.wav')).read_bytes()
                    want=by_key[archive.name,e['name']]
                    assert digest(wav)==want['wav_sha256']
                    assert wav[:4]==b'RIFF' and wav[8:12]==b'WAVE'
                    assert struct.unpack_from('<I',wav,4)[0]==len(wav)-8
                    assert struct.unpack_from('<HHIIHH',wav,20)==(1,1,22050,44100,2,16)
                    assert wav[36:40]==b'data' and struct.unpack_from('<I',wav,40)[0]==want['samples']*2
                    assert len(wav)==44+want['samples']*2
                    speech_count+=1
            # Refuse existing output, without overwriting even the manifest.
            saved=digest((folder/'_box_manifest.json').read_bytes())
            run(ROOT/'bin/unbox.exe',archive,folder,ok=False)
            assert saved==digest((folder/'_box_manifest.json').read_bytes())
        bad=output/'broken.box';bad.write_bytes(b'BOX\0\0\0\1\0'+bytes(531))
        for tool in ('unbox','mfbdecoder','m10decoder'):
            run(ROOT/f'bin/{tool}.exe',bad,output/f'bad-{tool}',ok=False)
        check_cli_failures(output)
        report.update(passed=True,archives=13,entries=len(by_key),sprite_sheets=sprite_count,
                      indexed_frames=sum(len(e.get('frames',[])) for e in golden['entries']),
                      speech_files=speech_count,fat_entries=sum(len(b['payloads']) for b in native['fat']),
                      corrected_audio_boundaries=golden['audio_corrections'],
                      mfb_transparency_policy='raw: per-frame first pixel; compressed: frame-zero first pixel',
                      cli_failure_checks=True)
    finally:
        after={p.name:digest(p.read_bytes()) for p in inputs}
        report['input_hashes']=before;report['inputs_unchanged']=before==after
        (ROOT/'build/verification.json').write_text(json.dumps(report,indent=2))
        assert before==after,'Input files changed'
    print(json.dumps({k:v for k,v in report.items() if k not in ('input_hashes','corrected_audio_boundaries')},indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,required=True)
    verify(parser.parse_args().game.resolve())
