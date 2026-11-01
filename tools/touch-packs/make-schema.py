"""Generate the data-only wire contract. Checked in for non-Python clients and codex exec."""
import json
from pathlib import Path
def obj(properties):
    return dict(type='object',properties=properties,required=list(properties),additionalProperties=False)
def arr(items,lo=0,hi=64): return dict(type='array',items=items,minItems=lo,maxItems=hi)
def num(lo,hi): return dict(type='number',minimum=lo,maximum=hi)
def enum(*values): return dict(type='string',enum=list(values))
text=dict(type='string',minLength=1,maxLength=256,pattern=r'^[^\x00-\x1f]+$')
identity=obj({k:text for k in ['executable','storeID','edition','build','bindingDigest']})
action=obj(dict(id=text,label=text,icon=dict(type='string',pattern=r'^[A-Za-z0-9.-]+$',maxLength=256),output=text,behavior=enum('hold','tap','release'),evidence=text,contexts=arr(text,1,8)))
control=obj(dict(id=text,action=text,role=enum('button','move','fireAim','radial','gesture'),x=num(0,1),y=num(0,1),radius=num(.035,.2),hitRadius=num(.035,.23),opacity=num(.1,1)))
layout=obj(dict(aimRect=obj(dict(x=num(0,1),y=num(0,1),width=num(.25,1),height=num(.25,1))),controls=arr(control,1,48)))
schema=obj(dict(version=dict(type='integer',const=1),id=text,title=text,identity=identity,inputMode=enum('controller','keyboardMouse'),
    aim=obj(dict(sensitivity=num(.1,8),vertical=num(.25,2),invertY=dict(type='boolean'),deadZone=num(0,.4),fullSpeed=num(200,3000))),
    actions=arr(action,1,64),phone=layout,pad=layout,gestures=arr(obj(dict(kind=enum('swipeUp','swipeDown','swipeLeft','swipeRight'),action=text)),0,4),
    radial=arr(text,0,8),contexts=arr(text,1,8),evidence=arr(obj(dict(id=text,source=text,detail=dict(type='string',minLength=1,maxLength=4096))),1,128),unresolved=arr(text)))
schema['$schema']='https://json-schema.org/draft/2020-12/schema'
(Path(__file__).parent/'pack.schema.json').write_text(json.dumps(schema,indent=2)+'\n')
