"""Known installed-file adapters take priority over model guesses. Never change the game files."""
import configparser

def apply_installed_bindings(pack,request):
    executable=request['identity']['executable'].replace('\\','/').rsplit('/',1)[-1].casefold()
    if request['identity']['storeID']!='steam:2371890' and executable!='cotw.exe':return pack
    entry=next(((k,v) for k,v in request.get('bindings',{}).items() if k.endswith('Chronicles of the Wolf/config')),None)
    if not entry:return pack
    source,text=entry
    parser=configparser.ConfigParser(interpolation=None);parser.read_string(text)
    data=parser['varcom']
    names={'attack':('attaque','Attack','bolt'),'jump':('jump','Jump','arrow.up'),'special':('special','Special','sparkles'),'helper':('helper','Helper','person.2'),'map':('map','Map','map'),'subscreen':('subscreen','Subscreen','bag'),'confirm':('confirm','Confirm','checkmark'),'cancel':('cancel','Cancel','xmark'),'up':('up','Up','arrow.up'),'down':('down','Down','arrow.down'),'left':('left','Left','arrow.left'),'right':('right','Right','arrow.right')}
    codes={'return':13,'backspace':8,'up':38,'down':40,'left':37,'right':39,'space':32}
    actions=[]
    for id,(name,label,icon) in names.items():
        value=data[name].strip()
        code=ord(value.upper()) if len(value)==1 and value.isascii() and value.isalnum() else codes.get(value.lower())
        if code is None:raise ValueError('Unresolved installed key '+name)
        actions.append(dict(id=id,label=label,icon=icon,output='key:'+str(code),behavior='hold' if id in ['attack','jump','up','down','left','right'] else 'tap',evidence='installed-config',contexts=['onFoot','menu']))
    pack.update(id='chronicles-of-the-wolf-installed-v1',inputMode='keyboardMouse',actions=actions,contexts=['onFoot','menu'],radial=['map','subscreen','confirm','cancel'],gestures=[],evidence=[dict(id='installed-config',source=source,detail='Observed player key assignments in [varcom]: '+', '.join(name+'='+data[name] for name,_,_ in names.values()))],unresolved=['Numeric controller mappings M..U remain unresolved; this pack uses verified player keyboard bindings.','Actual guest delivery, current-build binding freshness, physical reach and game HUD clearance await device testing.'])
    for device in ['phone','pad']:
        ispad=device=='pad'
        positions={'up':(.14,.68,.05),'down':(.14,.88,.05),'left':(.07,.78,.05),'right':(.23,.78,.05),'attack':(.88,.65,.11),'jump':(.94,.9,.065),'special':(.91,.36,.05),'helper':(.8,.9,.045),'map':(.12,.10,.035),'subscreen':(.25,.10,.035)}
        if ispad:positions.update(up=(.11,.73,.05),down=(.11,.93,.05),left=(.055,.83,.05),right=(.19,.83,.05),attack=(.91,.73,.085),jump=(.94,.93,.05),special=(.94,.48,.04),helper=(.82,.94,.04))
        controls=[dict(id=id,action=id,role='button',x=x,y=y,radius=r,hitRadius=r,opacity=.35) for id,(x,y,r) in positions.items()]
        controls.append(dict(id='occasional',action='map',role='radial',x=.28,y=.88 if not ispad else .93,radius=.04,hitRadius=.04,opacity=.25))
        pack[device]=dict(aimRect=dict(x=.34,y=.2,width=.4,height=.5),controls=controls)
    return pack
