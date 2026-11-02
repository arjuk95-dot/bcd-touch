"""Dread pilot: reviewed installed input records, explicit contexts, controller outputs only."""
import copy
import json
from pathlib import Path

def apply_dread_bindings(pack, request):
    if request['identity']['storeID'] != 'steam:1574240': return pack
    if pack['inputMode'] != 'controller': return pack
    # Unrecognised actual remaps belong to the generator, never overwritten by defaults.
    if request.get('bindings'): return pack
    source=json.loads((Path(__file__).parent/'references/steam-1574240-installed.json').read_text(encoding='utf-8'))
    pack=copy.deepcopy(pack)
    contexts=['onFoot','menu','airship']; actions=[]; placements=[]
    evidence='installed-dread-inputasset'
    def add(id,label,output,icon,behavior,ctx,slot=None,role='button'):
        actions.append(dict(id=id,label=label,output=output,icon=icon,behavior=behavior,contexts=ctx,evidence=evidence))
        if slot: placements.append((id,slot,role))
    add('raw-ls','Move','LS','l.joystick','hold',contexts,'move','move')
    add('raw-rs','Look','RS','r.joystick','hold',contexts)
    add('raw-menu','Pause / Menu','Menu','pause','tap',contexts,'menu')
    add('map','Map','View','map','tap',['onFoot','airship'],'map')
    add('equipment','Inventory','X','bag','tap',['onFoot','menu'],'inventory')
    add('raw-rt','Attack','RT','figure.fencing','hold',['onFoot'],'primary','fireAim')
    add('raw-a','Interact','A','hand.tap','tap',['onFoot','airship'],'interact')
    add('raw-y','Jump','Y','arrow.up','tap',['onFoot'],'jump')
    add('block','Block / Parry','RB','shield.lefthalf.filled','hold',['onFoot'],'block')
    add('spell','Cast spell','LT','sparkles','hold',['onFoot'],'spell')
    add('sprint','Sprint','LB','figure.run','hold',['onFoot'],'sprint')
    add('crouch','Crouch','R3','arrow.down.to.line','tap',['onFoot'],'crouch')
    add('use-item','Use item','D↑','cross.case','tap',['onFoot'],'item')
    add('next-weapon','Next weapon','D↓','arrow.triangle.2.circlepath','tap',['onFoot'])
    add('next-item','Next item','D→','cross.case','tap',['onFoot'])
    add('next-spell','Next spell','D←','sparkles','tap',['onFoot'])
    add('menu-confirm','Confirm','A','checkmark','tap',['menu'],'interact')
    add('raw-b','Back / Cancel','B','arrow.uturn.backward','tap',['menu'],'crouch')
    add('page-left','Previous page','LB','chevron.left','tap',['menu'],'sprint')
    add('page-right','Next page','RB','chevron.right','tap',['menu'],'block')
    add('panel-left','Previous panel','LT','arrow.left','tap',['menu'],'spell')
    add('panel-right','Next panel','RT','arrow.right','tap',['menu'],'primary')
    add('landmarks','Toggle landmarks','Y','mappin','tap',['menu'],'jump')
    for id,label,output,icon,slot in [
        ('boost','Boost','Y','forward.fill','jump'),('exit-airship','Exit airship','X','rectangle.portrait.and.arrow.right','inventory'),
        ('tilt-down','Tilt down','RT','arrow.down.forward','primary'),('tilt-up','Tilt up','LT','arrow.up.forward','spell'),
        ('ascend','Ascend','RB','arrow.up','block'),('descend','Descend','LB','arrow.down','sprint'),
        ('reverse','Reverse','B','backward.fill','item'),('recenter','Recenter camera','R3','scope','crouch'),
        ('zoom-up','Zoom up','D↑','plus.magnifyingglass','zoom-up'),('zoom-down','Zoom down','D↓','minus.magnifyingglass','zoom-down')]:
        add(id,label,output,icon,'hold',['airship'],slot)
    # Every binding is checked against the installed table; no named weapon slots or keyboard fallback.
    outputs={'leftStick':'LS','rightStick':'RS','rightTrigger':'RT','leftTrigger':'LT','leftShoulder':'LB','rightShoulder':'RB',
             'buttonSouth':'A','buttonEast':'B','buttonWest':'X','buttonNorth':'Y','rightStickPress':'R3','start':'Menu','select':'View',
             'dpad/up':'D↑','dpad/down':'D↓','dpad/left':'D←','dpad/right':'D→','dpad/y':'D↑'}
    known={outputs[b['path'].split('>/',1)[1]] for b in source['bindings'] if b['path'].split('>/',1)[1] in outputs}
    assert all(a['output'] in known for a in actions)
    pack.update(actions=actions,contexts=contexts,radial=['next-weapon','next-item','next-spell'],gestures=[])
    pack['aim'].update(deadZone=.30,fullSpeed=600,vertical=1.25)
    pack['evidence']=[e for e in pack['evidence'] if e['id'] not in [evidence,'dread-aim-calibration']]
    pack['evidence'] += [dict(id=evidence,source='installed-game:steam:1574240/resources.assets',detail='Installed input asset SHA256 '+source['assetSHA256']+'. Gameplay/UI/Airship controller bindings extracted from serialized records. Block=RB, Spell=LT, Sprint=LB, Jump=Y, Interact=A, Crouch=R3, Item=D-pad Up. These are installed defaults; active personal remaps were not located. Parry uses a timed Block press per the installed tutorial.'),
        dict(id='dread-aim-calibration',source='https://docs.unity3d.com/Packages/com.unity.inputsystem@1.4/manual/ActionBindings.html',detail='Installed Look binding: StickDeadzone(min=0.2),ScaleVector2(x=50,y=40). Unity documents that control and binding dead zones stack. Assuming standard control defaults, the effective lower threshold is about .285; .30 compensation and 1.25 vertical scaling are provisional calibration, not physically accepted values.')]
    pack['unresolved']=['Installed defaults were extracted; in-game remaps still require comparison with the Controls screen.',
        'SwitchWeapon has a hold/tap interaction. No separate named weapon slots or independently verified controller Holster action are offered.',
        'Select onFoot, menu or airship explicitly in the pack tools. Automatic state detection is unavailable.',
        'Swipe timing, camera sensitivity, reach, simultaneous Block/Attack/movement and airship/menu mappings still need physical testing.']
    phone={'move':(.14,.79,.13),'primary':(.88,.68,.12),'interact':(.95,.43,.045),'jump':(.95,.91,.05),
           'block':(.82,.40,.055),'spell':(.95,.23,.045),'sprint':(.08,.28,.05),'crouch':(.81,.91,.045),
           'item':(.81,.22,.045),'inventory':(.08,.10,.035),'map':(.43,.08,.035),'menu':(.57,.08,.035),
           'zoom-up':(.25,.28,.04),'zoom-down':(.25,.10,.035)}
    pad=dict(phone,move=(.14,.79,.10),primary=(.89,.77,.085),interact=(.96,.48,.04),jump=(.95,.94,.04),
             block=(.84,.55,.05),spell=(.95,.30,.04),crouch=(.83,.94,.04),item=(.83,.30,.04))
    # Retain deployed control IDs for existing actions, including personal placements.
    for device,positions in [('phone',phone),('pad',pad)]:
        old=pack[device]['controls']; controls=[]
        for id,slot,role in placements:
            x,y,r=positions[slot]
            previous=next((c for c in old if c['action']==id and c['role']!='radial'),None)
            controlID=previous['id'] if previous else device+'-'+id
            controls.append(dict(id=controlID,action=id,role=role,x=x,y=y,radius=r,hitRadius=r,opacity=.35))
        radial=next((c for c in old if c['role']=='radial'),None)
        controls.append(dict(id=radial['id'] if radial else device+'-radial',action='next-weapon',role='radial',x=.5,y=.92,radius=.05,hitRadius=.05,opacity=.3))
        pack[device]=dict(aimRect=dict(x=.34,y=.18,width=.40,height=.58),controls=controls)
    return pack
