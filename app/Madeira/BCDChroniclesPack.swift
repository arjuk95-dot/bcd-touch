// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Exact installed Clickteam XBOX Gamepad ABI, not a generic joystick-number guess.
/// This factory is a fallback only; the store preserves selected personal/researched packs.
enum BCDChroniclesPack {
    static let configPath = "users/mobile/AppData/Roaming/Chronicles of the Wolf/config"
    static func matches(_ identity: BCDControlPack.Identity) -> Bool {
        let path = identity.executable.replacingOccurrences(of:"\\",with:"/").lowercased()
        return path.split(separator:"/").last == "cotw.exe"
    }
    /// Module condition16 dispatch, plus the game's explicit trigger cases31/32.
    static func output(for code: Int) -> String? {
        let buttons = ["A","B","X","Y","LB","RB","View","Menu","L3","R3","D↑","D↓","D←","D→"]
        if buttons.indices.contains(code) { return buttons[code] }
        if code == 31 { return "LT" }
        if code == 32 { return "RT" }
        return nil
    }
    /// Consume only the known, bounded input section. Never rewrite game settings.
    /// Case matters: uppercase M..U are controller mappings; lowercase labels are keyboard UI.
    static func configuredOutputs(_ text: String) throws -> [String:String] {
        guard text.utf8.count <= 32768 else { throw BCDControlPack.Invalid.reason("Chronicles config is too large") }
        let fields = ["M":"attack","N":"jump","O":"special","P":"helper","Q":"map","R":"subscreen","T":"confirm","U":"cancel"]
        var section = "", result: [String:String] = [:], seen = Set<String>()
        for raw in text.replacingOccurrences(of:"\u{feff}",with:"").split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in:.whitespaces)
            if line.hasPrefix(";") || line.hasPrefix("#") || line.isEmpty { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") { section=String(line.dropFirst().dropLast());continue }
            guard section == "varcom", let equal=line.firstIndex(of:"=") else { continue }
            let key=line[..<equal].trimmingCharacters(in:.whitespaces)
            guard let action=fields[key] else { continue }
            let value=line[line.index(after:equal)...].trimmingCharacters(in:.whitespaces)
            guard seen.insert(key).inserted, let code=Int(value), let output=output(for:code) else {
                throw BCDControlPack.Invalid.reason("Chronicles controller mapping \(key) is invalid or ambiguous")
            }
            result[action]=output
        }
        guard result.count == fields.count else { throw BCDControlPack.Invalid.reason("Chronicles controller mappings are incomplete") }
        return result
    }
    static func make(identity: BCDControlPack.Identity, bindings: [String:String] = [:]) throws -> BCDControlPack {
        guard matches(identity) else { throw BCDControlPack.Invalid.reason("Not Chronicles of the Wolf") }
        guard let text=bindings[configPath] else { throw BCDControlPack.Invalid.reason("Chronicles input config is unavailable; existing controls retained") }
        let outputs=try configuredOutputs(text)
        let definitions: [(String,String,String,String)] = [
            ("attack","Attack","bcd.sword","hold"), ("jump","Jump","arrow.up","hold"),
            ("special","Special","sparkles","hold"), ("helper","Helper","person.2","hold"),
            ("map","Map","map","tap"), ("subscreen","Inventory","bag","tap"),
            ("confirm","Confirm","checkmark","tap"), ("cancel","Cancel / pause","xmark","tap")
        ]
        var actions=definitions.map { id,label,icon,behavior in
            BCDControlPack.Action(id:id,label:label,icon:icon,output:outputs[id]!,behavior:behavior,evidence:"installed-config",contexts:["onFoot"])
        }
        actions.insert(.init(id:"move",label:"Move / deep down",icon:"arrow.left.arrow.right",output:"LS",behavior:"hold",evidence:"installed-module",contexts:["onFoot"]),at:0)
        // The approved sidepad intentionally has no accidental Up. Keep native Up reachable
        // for menu navigation / game interactions without adding a full free-angle stick.
        actions.append(.init(id:"up",label:"Up",icon:"arrow.up",output:"D↑",behavior:"hold",evidence:"installed-module",contexts:["onFoot"]))
        func layout(pad: Bool) -> BCDControlPack.Layout {
            func c(_ id:String,_ role:String,_ x:Double,_ y:Double,_ radius:Double) -> BCDControlPack.Control {
                .init(id:id,action:id,role:role,x:x,y:y,radius:radius,hitRadius:radius,opacity:0.5,labelPlacement:"inside")
            }
            return .init(aimRect:.init(x:0.35,y:0.25,width:0.3,height:0.5),controls:[
                c("move","move",0.17,0.72,pad ? 0.11:0.13),
                c("attack","button",0.82,0.75,pad ? 0.09:0.105),
                c("jump","button",0.94,0.89,0.06),
                c("special","button",0.94,0.52,0.055),
                c("helper","button",0.79,0.46,0.055),
                c("map","button",0.39,0.08,0.04),
                c("subscreen","button",0.52,0.08,0.04),
                c("confirm","radial",0.65,0.08,0.04)
            ],movementRect:.init(x:0,y:0.28,width:0.40,height:0.72))
        }
        let pack=BCDControlPack(version:6,id:"chronicles-reviewed-controller-v6",title:"Chronicles of the Wolf",identity:identity,inputMode:"controller",aim:.init(),actions:actions,phone:layout(pad:false),pad:layout(pad:true),gestures:[],radial:["confirm","cancel","up"],contexts:["onFoot"],evidence:[
            .init(id:"installed-module",source:"Installed Cotw.dat events and XBOXGamepad.mfx",detail:"Module SHA256 85ae68187c7020bf5701e9ac9942dc7978d3b7cc426aef1445483f7e5394f25a. GetRunObjectInfos RVA2480; condition16 jump table RVA14b4 maps 0..13 to exact XInput masks. Expressions80/81 read left-stick X/Y; Dpad conditions -93..-96 also supported. Event166 reads trigger expressions84/85; events173/174 map codes31/32 to LT/RT. Static installed-source proof, not device validation."),
            .init(id:"installed-config",source:"Current Chronicles [varcom] input config",detail:"M/N/O/P/Q/R/T/U load controller slots12/13/14/15/16/17/19/20 for Attack/Jump/Special/Helper/Map/Subscreen/Confirm/Cancel. Parsed at pack selection; no defaults or keyboard bindings substituted. Binding digest invalidates stale generated packs. Existing personal packs are preserved by the caller.")
        ],unresolved:["Phone testing required: native route activation, combat timing, menu navigation and safe-area reach.","Floating sidepad emits crisp left/right LS; deliberate deep downward gesture holds Down only until lifted or withdrawn. No latch, Up or camera gesture.","If game mappings change, reselect the preset to read them again. Config is never changed."],lookMode:"none")
        try pack.validate(for:identity)
        return pack
    }
}
