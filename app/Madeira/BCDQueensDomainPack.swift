// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Bindings verified against shipped v1.01.03 DefaultInput.ini and custom DefaultBindings_DA; not inferred from genre.
enum BCDQueensDomainPack {
    static func matches(_ identity: BCDControlPack.Identity) -> Bool {
        let executable = identity.executable.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "’", with: "").replacingOccurrences(of: "'", with: "")
        return executable.contains("queensdomain")
    }
    static func make(identity: BCDControlPack.Identity, bindings: [String:String] = [:]) -> BCDControlPack {
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
        return .init(version:6,id:"queens-domain-v6",title:"Queen's Domain",identity:identity,inputMode:"controller",aim:.init(),actions:actions,phone:layout(),pad:layout(),gestures:gestures,radial:radial,contexts:["onFoot"],evidence:[
            .init(id:"shipped-input",source:"Queen's Domain v1.01.03 shipped DefaultInput.ini",detail:"Verified locally against PAK entry SHA1 d4e7a3684b94a91d144903de3c1a6da3d0838197. Status=Back; Journal=J/controller None; no Map action. Primary RT, secondary LT, jump A, interact X, item B, ultra Y, dagger LB, wind dash RB. Movement left stick; camera mouse. Custom DefaultBindings_DA overrides Run to Gamepad_LeftThumbstick (L3); Journal remains None."),
            .init(id:"verified-remaps",source:"Caller-verified personal controller bindings",detail:"Optional remaps must come from actual game configuration; absent mappings retain shipped defaults. Journal is enabled only with a verified controller remap.")
        ],unresolved:unresolved,lookMode:"relativeMouse")
    }
}
