#!/usr/bin/env python3
"""Render the exact source vector paths for local review; UIKit remains a separate gate."""
import json,re
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parents[2]
source=(root/'app/Madeira/BCDControlPackAuthoring.swift').read_text(encoding='utf-8')
block=source.split('static let glyphPaths:',1)[1].split('static let customIconNames:',1)[0]
glyphs={name:json.loads(paths) for name,paths in re.findall(r'"(bcd\.[a-z]+)": (\[.*\])[,\n]',block)}
assert len(glyphs)==14 and 'bcd.jump' in glyphs
scale=3;w,h=960,620
im=Image.new('RGB',(w*scale,h*scale),(17,24,31));d=ImageDraw.Draw(im)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',16*scale) if Path('C:/Windows/Fonts/segoeui.ttf').exists() else ImageFont.load_default(size=16*scale)
d.text((25*scale,18*scale),'SOURCE VECTOR PREVIEW — UIKit / device validation pending',fill=(210,220,230),font=font)
for index,(name,paths) in enumerate(glyphs.items()):
 x=95+(index%7)*128;y=145+(index//7)*215;r=45
 d.ellipse(((x-r)*scale,(y-r)*scale,(x+r)*scale,(y+r)*scale),outline=(110,125,140),width=scale)
 # Production icon-only extent is 1.18 * button radius, with a 48x48 viewbox.
 extent=1.18*r
 for path in paths:
  pts=[((x-extent/2+px/48*extent)*scale,(y-extent/2+py/48*extent)*scale) for px,py in path]
  width=max(1,round((5 if name=='bcd.pause' else 3)/48*extent*scale))
  d.line(pts,fill=(236,242,247),width=width,joint='curve')
  for px,py in pts:d.ellipse((px-width/2,py-width/2,px+width/2,py+width/2),fill=(236,242,247))
 d.text((x*scale,(y+65)*scale),name.removeprefix('bcd.'),anchor='mt',fill=(184,198,211),font=font)
d.text((25*scale,535*scale),'Gameplay defaults: glyph only. Names above are for this review sheet.',fill=(184,198,211),font=font)
out=root/'touch-evidence/feedback-glyphs.png';out.parent.mkdir(exist_ok=True)
im.resize((w,h),Image.Resampling.LANCZOS).save(out)
print(f'PASS: {len(glyphs)} exact production vector paths rendered to {out}')
