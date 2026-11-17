// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Reviewed default touch controls. Detailed provenance remains in private review records.
enum BCDQueensDomainPack {
    static func matches(_ identity: BCDControlPack.Identity) -> Bool {
        // https://store.steampowered.com/app/1799840/Queens_Domain/
        if identity.storeID.lowercased().hasPrefix("steam:") {return identity.storeID.lowercased() == "steam:1799840"}
        let executable = identity.executable.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "")
        return executable.contains("queensdomain")
    }
    static func make(identity: BCDControlPack.Identity, bindings: [String:String] = [:], glyphs:Bool = true) -> BCDControlPack {
        let definitions: [(String,String,String,String,String)] = [
            ("move","Move","figure.walk","LS","hold"),
            ("attack","Attack / charge","bcd.sword","RT","hold"),
            ("secondary","Secondary attack","shield","LT","hold"),
            ("jump","Jump","arrow.up","A","tap"),
            ("interact","Interact","hand.tap","X","tap"),
            ("use-item","Use item","bcd.wand","B","tap"),
            ("ultra","Ultra attack","bolt","Y","tap"),
            ("throw-dagger","Throw dagger","arrow.up.forward","LB","tap"),
            ("wind-dash","Wind dash","wind","RB","tap"),
            ("next-item","Next item","arrow.up","D↑","tap"),
            ("last-item","Previous item","arrow.down","D↓","tap"),
            ("next-dagger","Next dagger","arrow.left","D←","tap"),
            ("next-weapon","Next weapon","arrow.right","D→","tap"),
            ("equipment","Equipment","bag","View","tap"),
            ("run","Run","figure.run","L3","tap"),
            ("pause","Pause","pause","Menu","tap")
        ]
        var actions = definitions.map { id,label,icon,output,behavior in
            BCDControlPack.Action(id:id,label:label,icon:icon,output:output,behavior:behavior,evidence:"shipped-input",contexts:["onFoot"])
        }
        var unresolved = ["Custom bindings default to L3 tap-to-run. Run is available in the radial; automatic forward latch awaits verified stop/reset behavior.","Phone gameplay and simultaneous controller/mouse look still require testing."]
        // Only caller-verified personal controller remaps are accepted. Never inject keyboard J.
        for index in actions.indices {
            if let output = bindings[actions[index].id], BCDControlPack.padOutputs.contains(output), !["LS","RS"].contains(output), actions[index].id != "move" {
                actions[index].output=output; actions[index].evidence="verified-remaps"
            }
        }
        var gestures: [BCDControlPack.Gesture] = [.init(kind:"twoFingerTap",action:"equipment")]
        if let journal=bindings["journal"], BCDControlPack.padOutputs.contains(journal), !["LS","RS"].contains(journal) {
            actions.append(.init(id:"journal",label:"Journal",icon:"book",output:journal,behavior:"tap",evidence:"verified-remaps",contexts:["onFoot"]))
            gestures.append(.init(kind:"twoFingerDoubleTap",action:"journal"))
        } else { unresolved.append("Journal defaults to J with no controller binding. Double tap remains disabled until a verified controller remap exists.") }
        let radial=["use-item","ultra","throw-dagger","next-item","last-item","next-dagger","next-weapon","run"]
        func layout() -> BCDControlPack.Layout {
            func c(_ id:String,_ role:String,_ x:Double,_ y:Double,_ r:Double) -> BCDControlPack.Control {
                .init(id:id,action:id,role:role,x:x,y:y,radius:r,hitRadius:r,opacity:0.7,labelPlacement:"inside")
            }
            return .init(aimRect:.init(x:0.43,y:0.55,width:0.57,height:0.45),controls:[
                c("move","move",0.17,0.76,0.13),
                // Invisible semantic surface role. UIKit adapter owns tap vs swipe arbitration.
                c("attack","gesture",0.55,0.36,0.05),
                c("secondary","button",0.89,0.31,0.09),
                c("interact","button",0.73,0.22,0.06),
                c("jump","button",0.76,0.43,0.065),
                c("wind-dash","button",0.61,0.18,0.055),
                c("use-item","radial",0.95,0.08,0.045),
                c("pause","button",0.04,0.08,0.04)
            ],movementRect:.init(x:0,y:0.25,width:0.42,height:0.75))
        }
        let pack=BCDControlPack(version:6,id:"queens-domain-v6",title:"Queen's Domain",identity:identity,inputMode:"controller",aim:.init(),actions:actions,phone:layout(),pad:layout(),gestures:gestures,radial:radial,contexts:["onFoot"],evidence:[
            .init(id:"shipped-input",source:"Reviewed default controls",detail:"Detailed binary-build provenance is omitted from this public source. User remaps are not inferred."),
            .init(id:"verified-remaps",source:"Caller-verified personal controller bindings",detail:"Optional remaps must come from actual game configuration; absent mappings retain shipped defaults. Journal is enabled only with a verified controller remap.")
        ],unresolved:unresolved,lookMode:"relativeMouse")
        return glyphs ? BCDPackCatalog.glyphPresentation(pack,icons:["attack":"bcd.blade","interact":"bcd.use","pause":"bcd.pause","equipment":"bcd.pack","jump":"bcd.jump","throw-dagger":"bcd.blade"]):pack
    }

    /// The old researched raw-output pack used different action/control IDs.
    /// Translate its saved delta, not its obsolete layout, onto the reviewed pack.
    /// A missing or unrecognized baseline never authorizes guessing away edits.
    static func migrateLegacyEdit(identity:BCDControlPack.Identity,bindings:[String:String] = [:],
                                  personal:BCDControlPack,baseline:BCDControlPack?) -> BCDControlPack? {
        guard matches(identity),let baseline,baseline.id == "queens-domain",baseline.version == 1,
              personal.id == baseline.id,baseline.inputMode == "controller",personal.inputMode == "controller",
              baseline.contexts == ["raw-controller"],baseline.gestures.isEmpty,
              baseline.radial == ["menu","view"],baseline.lookMode == nil,
              baseline.digitalMovement == nil,baseline.cursorControls == nil,
              baseline.identity.executable.lowercased() == identity.executable.lowercased(),
              personal.identity.executable.lowercased() == baseline.identity.executable.lowercased(),
              (try? baseline.validate(placement:.personal)) != nil,
              (try? personal.validate(placement:.personal)) != nil else {return nil}
        let outputs=["ls":"LS","rs":"RS","rt":"RT","a":"A","b":"B","x":"X","y":"Y","menu":"Menu","view":"View"]
        guard baseline.actions.count == outputs.count,
              baseline.actions.allSatisfy({outputs[$0.id] == $0.output && $0.contexts == ["raw-controller"]}),
              personal.actions.first(where:{$0.id == "rs"}) == baseline.actions.first(where:{$0.id == "rs"}),
              !personal.phone.controls.contains(where:{$0.action == "rs"}),
              !personal.pad.controls.contains(where:{$0.action == "rs"}) else {return nil}
        let mapping=["ls":"move","rt":"attack","a":"jump","b":"use-item","x":"interact","y":"ultra","menu":"pause","view":"equipment"]
        let approved=make(identity:identity,bindings:bindings)
        var before=approved,edited=approved
        func action(_ id:String) -> String {mapping[id] ?? id}
        func contexts(_ values:[String]) -> [String] {values.map {$0 == "raw-controller" ? "onFoot":$0}}
        func translatedAction(_ old:BCDControlPack.Action) -> BCDControlPack.Action {
            var value=old;value.id=action(old.id);value.contexts=contexts(old.contexts);return value
        }
        for old in baseline.actions where old.id != "rs" {
            let id=action(old.id)
            guard let index=before.actions.firstIndex(where:{$0.id == id}) else {return nil}
            before.actions[index]=translatedAction(old)
            if let value=personal.actions.first(where:{$0.id == old.id}),let i=edited.actions.firstIndex(where:{$0.id == id}) {edited.actions[i]=translatedAction(value)}
            else {edited.actions.removeAll{$0.id == id}}
        }
        for old in personal.actions where !baseline.actions.contains(where:{$0.id == old.id}) {
            var value=translatedAction(old)
            guard !edited.actions.contains(where:{$0.id == value.id}) else {return nil}
            // The editor's raw LB/hand defaults are presentation, not a new binding.
            // Keep an explicitly named/icon-selected action; otherwise use the verified glyph.
            if let semantic=approved.actions.first(where:{$0.output == old.output}) {
                if old.label == BCDPackCatalog.outputLabel(old.output) {value.label=semantic.label}
                if old.icon == "hand.tap" {value.icon=semantic.icon}
            }
            edited.actions.append(value)
        }
        func target(_ old:BCDControlPack.Control) -> String? {
            if old.action == "menu",old.role == "radial" {return "use-item"}
            // Raw B/Y buttons have no direct counterpart in the new radial design.
            if ["b","y"].contains(old.action) {return nil}
            return mapping[old.action]
        }
        func control(_ old:BCDControlPack.Control,id:String? = nil) -> BCDControlPack.Control {
            var value=old;value.id=id ?? old.id;value.action=action(old.action)
            if old.action == "menu",old.role == "radial" {value.action="use-item"}
            if let slide=old.slideToAction {value.slideToAction=action(slide)}
            return value
        }
        for pad in [false,true] {
            let old=pad ? baseline.pad:baseline.phone,personalLayout=pad ? personal.pad:personal.phone
            var oldLayout=pad ? approved.pad:approved.phone,newLayout=oldLayout
            oldLayout.aimRect=old.aimRect;newLayout.aimRect=personalLayout.aimRect
            oldLayout.movementRect=old.movementRect;newLayout.movementRect=personalLayout.movementRect
            var translatedIDs=[String:String]()
            for original in old.controls {
                let value=personalLayout.controls.first(where:{$0.id == original.id})
                if let id=target(original),let index=oldLayout.controls.firstIndex(where:{$0.id == id}) {
                    guard translatedIDs.values.allSatisfy({$0 != id}) else {return nil}
                    translatedIDs[original.id]=id
                    oldLayout.controls[index]=control(original,id:id)
                    if let value,let index=newLayout.controls.firstIndex(where:{$0.id == id}) {
                        newLayout.controls[index]=control(value,id:id)
                    } else {newLayout.controls.removeAll{$0.id == id}}
                } else if let value,value != original {
                    // A real edit to a retired direct button remains an extra button.
                    var extra=control(value);if extra.showLabel == nil {extra.showLabel=false}
                    guard !newLayout.controls.contains(where:{$0.id == extra.id}) else {return nil}
                    newLayout.controls.append(extra)
                }
            }
            for value in personalLayout.controls where !old.controls.contains(where:{$0.id == value.id}) {
                var extra=control(value);if extra.showLabel == nil {extra.showLabel=false}
                guard !newLayout.controls.contains(where:{$0.id == extra.id}) else {return nil}
                newLayout.controls.append(extra)
            }
            let retained=Set(personalLayout.controls.map(\.id)).intersection(old.controls.map(\.id))
            if personalLayout.controls.filter({retained.contains($0.id)}).map(\.id) != old.controls.filter({retained.contains($0.id)}).map(\.id) {
                let ids=personalLayout.controls.compactMap {translatedIDs[$0.id]}
                let priority=ids.compactMap {id in newLayout.controls.first(where:{$0.id == id})}
                newLayout.controls=priority+newLayout.controls.filter{!ids.contains($0.id)}
            }
            if pad {before.pad=oldLayout;edited.pad=newLayout} else {before.phone=oldLayout;edited.phone=newLayout}
        }
        before.contexts=contexts(baseline.contexts);edited.contexts=contexts(personal.contexts)
        before.radial=baseline.radial.map(action);edited.radial=personal.radial.map(action)
        before.aim=baseline.aim;edited.aim=personal.aim
        before.lookMode=baseline.lookMode;edited.lookMode=personal.lookMode
        before.digitalMovement=baseline.digitalMovement;edited.digitalMovement=personal.digitalMovement
        before.cursorControls=baseline.cursorControls;edited.cursorControls=personal.cursorControls
        func gestures(_ values:[BCDControlPack.Gesture]) -> [BCDControlPack.Gesture] {values.map {old in
            var value=old;value.action=action(old.action)
            if let when=old.whenToggled {value.whenToggled=action(when)}
            return value
        }}
        before.gestures=gestures(baseline.gestures);edited.gestures=gestures(personal.gestures)
        for evidence in personal.evidence where !baseline.evidence.contains(where:{$0.id == evidence.id}) && !edited.evidence.contains(where:{$0.id == evidence.id}) {edited.evidence.append(evidence)}
        return try? BCDPackAuthoring.merge(base:approved,personal:edited,baseline:before)
    }
}
