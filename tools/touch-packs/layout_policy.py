"""BLACK reach policy applied after generation, before validation. No binding changes."""
def apply_layout_policy(pack, request):
    if request.get('requirements',{}).get('genre') != 'first-person': return pack
    for device in ['phone','pad']:
        layout=pack[device]
        layout['aimRect']=dict(x=.34,y=.18,width=.40,height=.58)
        secondary=iter([(.95,.43),(.82,.38),(.96,.23),(.95,.91),(.81,.90),(.08,.25)])
        primary=False
        actions={a['id']:a for a in pack['actions']}
        for c in layout['controls']:
            output=actions.get(c['action'],{}).get('output','')
            if output=='RT' and c['role']=='button' and actions[c['action']]['behavior']=='hold':c['role']='fireAim'
            if c['role']=='move':x,y,r=.14,.79,.13 if device=='phone' else .10
            elif c['role']=='fireAim' and not primary:
                primary=True;x,y,r=(.88,.68,.12) if device=='phone' else (.89,.77,.085)
            elif output=='Menu':x,y,r=.57,.08,.035
            elif output=='View':x,y,r=.43,.08,.035
            elif c['role']=='radial':x,y,r=.50,.92,.05
            else:
                x,y=next(secondary,(.08,.4));r=.045
            c.update(x=x,y=y,radius=r,hitRadius=r,opacity=max(.25,c['opacity']))
    return pack
