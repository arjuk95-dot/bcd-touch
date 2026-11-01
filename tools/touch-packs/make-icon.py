"""Original code-drawn test-fork icon, independent of BCD's release icon."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
im=Image.new('RGB',(1024,1024),'#10191f');d=ImageDraw.Draw(im)
for x in [240,784]:d.ellipse((x-140,470,x+140,750),outline='#75e7d5',width=12)
d.ellipse((185,555,295,665),fill='#e3fff8')
d.line((650,610,870,470),fill='#e3fff8',width=18);d.line((800,470,870,470,870,540),fill='#e3fff8',width=18)
try:f=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',175);g=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',64)
except OSError:f=ImageFont.load_default(size=160);g=ImageFont.load_default(size=64)
d.text((512,125),'BCD',fill='white',font=f,anchor='mt');d.text((512,835),'TOUCH LAB',fill='#75e7d5',font=g,anchor='mt')
for name in ['AppIcon-1024.png','AppIcon-Dark-1024.png','AppIcon-Tinted-1024.png']:
    im.save(ROOT/'app/Madeira/Assets.xcassets/AppIcon.appiconset'/name,optimize=True)
