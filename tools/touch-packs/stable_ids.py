"""Keep semantic action/control IDs across regeneration; generated bindings remain authoritative."""
def stabilize(pack,previous):
    if not previous:return pack
    changed={}
    used=set()
    for a in pack['actions']:
        matches=[old for old in previous['actions'] if old['label']==a['label'] and sorted(old['contexts'])==sorted(a['contexts'])]
        if not matches:matches=[old for old in previous['actions'] if old['label']==a['label']]
        exact=[old for old in matches if old['output']==a['output']]
        if len(exact)==1:matches=exact
        if len(matches)==1 and matches[0]['id'] not in used:
            changed[a['id']]=matches[0]['id'];a['id']=matches[0]['id'];used.add(a['id'])
    for device in ['phone','pad']:
        for c in pack[device]['controls']:
            c['action']=changed.get(c['action'],c['action'])
            if 'slideToAction' in c:c['slideToAction']=changed.get(c['slideToAction'],c['slideToAction'])
            matches=[old for old in previous[device]['controls'] if old['action']==c['action'] and old['role']==c['role']]
            if not matches:matches=[old for old in previous[device]['controls'] if old['action']==c['action']]
            if len(matches)==1:c['id']=matches[0]['id']
    pack['radial']=[changed.get(a,a) for a in pack['radial']]
    for g in pack['gestures']:
        g['action']=changed.get(g['action'],g['action'])
        if 'whenToggled' in g:g['whenToggled']=changed.get(g['whenToggled'],g['whenToggled'])
        if 'cancelOn' in g:g['cancelOn']=[changed.get(id,id) for id in g['cancelOn']]
    for name,keys in [('digitalMovement',['left','right','up','down']),('cursorControls',['fire','inventory','pause','throwAction','primaryClick','secondaryClick'])]:
        if name in pack:
            for key in keys:pack[name][key]=changed.get(pack[name][key],pack[name][key])
    return pack
