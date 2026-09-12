from pathlib import Path
import subprocess
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE / 'renders'
ROOT.mkdir(exist_ok=True)
WORK = ROOT
SOURCE = HERE.parent.parent / 'assets' / 'options-storyboard.png'

def run(args):
    subprocess.run(args, check=True, cwd=ROOT)

def probe(path):
    return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_format','-show_streams','-of','json',str(path)]))

# Existing storyboard panels are edited directly into a video timeline.
# No new character art is synthesized by this script.
panels = [(28,126,476,356),(526,126,486,356),(1034,126,474,356),
          (28,554,476,338),(526,554,486,338)]
shots = [(0,1.8),(1,1.5),(2,2.5),(3,2.0),(1,3.0),(4,2.9),(0,1.3)]
for i,(panel,duration) in enumerate(shots):
    x,y,w,h=panels[panel]
    filters=f'crop={w}:{h}:{x}:{y},scale=1080:810:flags=lanczos,setsar=1,pad=1080:1920:0:460:color=0xF3EFE5,format=yuv420p'
    run(['ffmpeg','-hide_banner','-loglevel','error','-y','-loop','1','-framerate','30',
         '-i',str(SOURCE),'-t',str(duration),'-vf',filters,'-an','-c:v','libx264',
         '-preset','fast','-crf','19',str(WORK/f'shot-{i}.mp4')])

(WORK/'concat.txt').write_text(''.join(f"file 'shot-{i}.mp4'\n" for i in range(len(shots))))
run(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i',
     str(WORK/'concat.txt'),'-c','copy',str(WORK/'picture.mp4')])

ass=r'''[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Brand,Helvetica,94,&H00252725,&H00252725,&H00E5EFF3,&H00E5EFF3,-1,0,0,0,100,100,-3,0,1,0,0,5,70,70,0,1
Style: Small,Menlo,23,&H006A706A,&H006A706A,&H00E5EFF3,&H00E5EFF3,0,0,0,0,100,100,2,0,1,0,0,5,70,70,0,1
Style: Caption,Helvetica,61,&H00252725,&H00252725,&H00E5EFF3,&H00E5EFF3,-1,0,0,0,100,100,0,0,1,0,0,5,80,80,0,1
Style: Speaker,Menlo,24,&H004588E8,&H004588E8,&H00E5EFF3,&H00E5EFF3,-1,0,0,0,100,100,2,0,1,0,0,5,70,70,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.00,0:00:15.00,Brand,,0,0,0,,{\pos(540,270)}meo meo meo
Dialogue: 0,0:00:00.00,0:00:15.00,Small,,0,0,0,,{\pos(540,365)}01 / OPTIONS
Dialogue: 0,0:00:00.00,0:00:15.00,Small,,0,0,0,,{\pos(540,1650)}404 / THOUGHT NOT FOUND
Dialogue: 0,0:00:00.00,0:00:15.00,Small,,0,0,0,,{\pos(540,1710)}ANIMATIC / SCRATCH VOICES
Dialogue: 1,0:00:00.00,0:00:01.80,Speaker,,0,0,0,,{\pos(540,1360)}MEO
Dialogue: 1,0:00:00.00,0:00:01.80,Caption,,0,0,0,,{\pos(540,1450)}Open the door.\NIt's urgent.
Dialogue: 1,0:00:03.30,0:00:04.50,Speaker,,0,0,0,,{\pos(540,1360)}ME
Dialogue: 1,0:00:03.30,0:00:04.50,Caption,,0,0,0,,{\pos(540,1440)}Are we going?
Dialogue: 1,0:00:05.80,0:00:08.20,Speaker,,0,0,0,,{\pos(540,1360)}MO
Dialogue: 1,0:00:05.80,0:00:08.20,Caption,,0,0,0,,{\pos(540,1450)}We requested\Noptions.
'''
(WORK/'captions.ass').write_text(ass)

# Synthetic timing cues are deliberately quiet beneath the temporary dialogue.
audio_inputs=[]
for name in ['meo','me','mo']:
    audio_inputs += ['-i',str(HERE/f'{name}.aiff')]
filters=[
    '[1:a]aresample=48000,adelay=120:all=1,apad,atrim=0:15[a1]',
    '[2:a]aresample=48000,adelay=3350:all=1,apad,atrim=0:15[a2]',
    '[3:a]aresample=48000,adelay=5890:all=1,apad,atrim=0:15[a3]',
]
for i,(freq,start) in enumerate([(440,8100),(523.25,8600),(329.63,9100)]):
    filters.append(f'sine=frequency={freq}:sample_rate=48000:duration=0.16,afade=t=out:st=0.04:d=0.12,volume=0.12,adelay={start}:all=1,apad,atrim=0:15[n{i}]')
filters += [
    'anoisesrc=color=pink:sample_rate=48000:duration=0.06:amplitude=0.12,afade=t=out:st=0:d=0.06,adelay=1810:all=1,apad,atrim=0:15[latch1]',
    'anoisesrc=color=pink:sample_rate=48000:duration=0.06:amplitude=0.12,afade=t=out:st=0:d=0.06,adelay=13650:all=1,apad,atrim=0:15[latch2]',
    '[a1][a2][a3][n0][n1][n2][latch1][latch2]amix=inputs=8:normalize=0,alimiter=limit=0.85:level=false[audio]',
    "[0:v]ass=captions.ass[v]",
]
out=ROOT/'episode-01-options-animatic-v1.mp4'
run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(WORK/'picture.mp4'),
     *audio_inputs,'-filter_complex',';'.join(filters),'-map','[v]','-map','[audio]',
     '-t','15','-r','30','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p',
     '-c:a','aac','-b:a','192k','-ar','48000','-ac','2','-movflags','+faststart',str(out)])
metadata=probe(out)
(WORK/'verification.json').write_text(json.dumps(metadata,indent=2))
video=next(s for s in metadata['streams'] if s['codec_type']=='video')
assert (video['width'],video['height'])==(1080,1920)
assert video['nb_frames']=='450'
assert abs(float(metadata['format']['duration'])-15)<0.1
print('Verified 1080x1920, 30 fps, 450 frames, 15 seconds, with stereo audio.')
