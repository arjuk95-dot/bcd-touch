"""Bind the second pilot to observed keyboard actions; apply the first-person reach policy."""
from pathlib import Path
import json
from layout_policy import apply_layout_policy
from worker import canonical,validate
ROOT=Path(__file__).resolve().parents[2]
for title,genre in [('dread-delusion','first-person'),('chronicles-of-the-wolf','side-scroller')]:
    path=ROOT/'packs/requests'/(title+'.json');req=json.loads(path.read_text(encoding='utf-8'))
    req['requirements']['genre']=genre
    if genre=='side-scroller':
        req['requirements']['mode']='Use keyboardMouse: the installed config establishes attack Z (VK90), jump X (88), special A (65), helper S (83), map C (67), subscreen V (86), confirm Return (13), cancel Backspace (8), up/down/left/right (38/40/37/39). Controller numeric M..U mapping is unresolved. Use labelled directional hold buttons low left, attack/jump in right thumb reach, occasional map/menu on periphery/radial. No LS, RS or fireAim actions. Do not emit any controller outputs. Action IDs attack,jump,special,helper,map,subscreen,confirm,cancel,up,down,left,right.'
    path.write_bytes(canonical(req))
    pilot=ROOT/'packs/pilots'/(title+'.json')
    if genre=='first-person' and pilot.exists():
        pack=apply_layout_policy(json.loads(pilot.read_text(encoding='utf-8')),req);validate(pack);pilot.write_bytes(canonical(pack))
