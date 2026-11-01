from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'tools/touch-packs/worker.py';s=p.read_text(encoding='utf-8')
s=s.replace("    for action in pack['radial']: assert action in actions", """        reachable={c['action'] for c in layout['controls'] if c['role']!='radial'} | set(pack['radial']) | {g['action'] for g in pack['gestures']}
        assert all(k in reachable or (pack['inputMode']=='controller' and a['output']=='RS') for k,a in actions.items()), 'Declared action has no reachable control'
        for c in layout['controls']:
            if c['role'] in ['button','fireAim','gesture']: assert actions[c['action']]['output'] not in ['LS','RS'], 'Axes require continuous surfaces'
    for action in pack['radial']: assert action in actions and actions[action]['output'] not in ['LS','RS'], 'Unknown radial action or pulsed axis'""")
s=s.replace("for g in pack['gestures']: assert g['action'] in actions", "for g in pack['gestures']: assert g['action'] in actions and actions[g['action']]['output'] not in ['LS','RS'], 'Unknown gesture or pulsed axis'")
s=s.replace("if path.exists() and receipt.get('generation','initial') == generation:", "if path.exists() and receipt.get('validated',True) and receipt.get('generation','initial') == generation:")
s=s.replace('Every action id must correspond to an attainable input,', 'EVERY declared action except RS MUST appear in EACH device controls, radial, or gestures. Never reference missing action ids in radial. Axes cannot be pulsed. Include accessible Menu and View. Raw RT may have fireAim role but keep the honest RT label. Use common real SF Symbols such as scope, hand.tap, map, pause, figure.walk, a.circle. Every action id must correspond to an attainable input,')
p.write_text(s,encoding='utf-8')
p=ROOT/'app/Madeira/BCDControlPack.swift';s=p.read_text(encoding='utf-8')
needle='                // Conservative normalized square'
s=s.replace(needle,'''                if ["button", "fireAim", "gesture"].contains(c.role) { try require(!["LS", "RS"].contains(actions.first { $0.id == c.action }?.output ?? ""), "Axes require continuous surfaces") }
'''+needle)
needle='        try require(aim.sensitivity.isFinite'
s=s.replace(needle,'''        for layout in [phone, pad] {
            let reachable = Set(layout.controls.filter { $0.role != "radial" }.map(\\.action) + radial + gestures.map(\\.action))
            try require(actions.allSatisfy { reachable.contains($0.id) || (inputMode == "controller" && $0.output == "RS") }, "Declared action has no reachable control")
        }
        try require(radial.allSatisfy { id in !["LS", "RS"].contains(actions.first { $0.id == id }?.output ?? "") } && gestures.allSatisfy { g in !["LS", "RS"].contains(actions.first { $0.id == g.action }?.output ?? "") }, "Axes cannot be pulsed")
'''+needle)
p.write_text(s,encoding='utf-8')
