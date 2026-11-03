"""Generation quality checks. Preserve researched per-game layouts and their reserved space."""
import math

def apply_layout_policy(pack, request):
    if request.get('requirements',{}).get('genre') != 'first-person' or pack['inputMode'] != 'controller':
        return pack
    actions={a['id']:a for a in pack['actions']}
    for device in ['phone','pad']:
        controls=pack[device]['controls']
        candidates=[c for c in controls if c['x']>.5 and actions.get(c['action'],{}).get('behavior')=='hold'
                    and (c['role']=='fireAim' or actions.get(c['action'],{}).get('output')=='RT')]
        if not candidates:continue
        primary=max(candidates,key=lambda c:(c['role']=='fireAim',c['radius']))
        primary['role']='fireAim'
        # A left duplicate holds fire only. It must never claim the right thumb's look owner.
        for c in controls:
            if c['id']!=primary['id'] and c['x']<.34 and c['role']=='fireAim':
                c['role']='button'
    return pack

def check_generated_geometry(pack):
    """Reject ambiguous generated targets; intentional personal layout edits remain an editor choice."""
    actions={a['id']:a for a in pack['actions']}
    def contexts(control):
        if control['role']=='radial':ids=pack['radial']
        elif control['role']=='gesture':ids=[g['action'] for g in pack['gestures']]
        else:ids=[control['action']]
        return {context for id in ids if id in actions for context in actions[id]['contexts']}
    for device,aspect in [('phone',1.8),('pad',1.33)]:
        controls=[c for c in pack[device]['controls'] if c['role']!='move']
        for i,c in enumerate(controls):
            for other in controls[i+1:]:
                if not contexts(c).intersection(contexts(other)):continue
                distance=math.hypot((c['x']-other['x'])*aspect,c['y']-other['y'])
                if distance+1e-6<c['hitRadius']+other['hitRadius']:
                    raise ValueError(f"Generated {device} hit regions overlap in the same context: {c['id']} / {other['id']}; move a control or put an occasional action on the radial")
    return pack
