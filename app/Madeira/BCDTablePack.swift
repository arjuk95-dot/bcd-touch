// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Data-only controls use the common editor, personal keys and three-way merge.
/// Pointer gestures belong to the surface, never to an inferred game context.
enum BCDTablePack {
    /// Posted synchronously before the store discards/replaces the session.
    /// Views own the actual key counts and pulses; the store owns no keys.
    static let willChangeSession = Notification.Name("BCDTablePackWillChangeSession")
    static func kind(_ pack: BCDControlPack) -> String {
        switch pack.id {
        case "inscryption-walking-v6": return "inscryption"
        case "skald-trackpad-v6": return "skald"
        case "spire2-touch-v6": return "spire2"
        default: return ""
        }
    }
    static func make(_ identity: BCDControlPack.Identity, kind: String) -> BCDControlPack? {
        if kind == "spire2" {
            let specs=[("cancel","Cancel","xmark","B",0.43),("map","Map","map","View",0.64)]
            let actions=specs.map { id,label,icon,output,_ in
                BCDControlPack.Action(id:id,label:label,icon:icon,output:output,behavior:"tap",evidence:"spire-shipped-input",contexts:["onFoot"])
            }
            let controls=specs.map { id,_,_,_,y in
                BCDControlPack.Control(id:id,action:id,role:"button",x:0.94,y:y,radius:0.065,hitRadius:0.065,opacity:0.8,labelPlacement:"inside")
            }
            let layout=BCDControlPack.Layout(aimRect:.init(x:0.25,y:0.2,width:0.5,height:0.6),controls:controls)
            return .init(version:6,id:"spire2-touch-v6",title:"Slay the Spire 2",identity:identity,inputMode:"controller",aim:.init(),
                actions:actions,phone:layout,pad:layout,gestures:[],radial:[],contexts:["onFoot"],evidence:[
                    .init(id:"spire-shipped-input",source:"Exact transferred STS2 v0.111.0 project input + IL audit",
                          detail:"Cancel B and Map View are gated by installed-file verification. Drag cancellation uses right mouse press before left release. Direct touch remains mouse input; these native utilities do not disable XInput. No inspect-only toggle.")
                ],unresolved:["In-game remaps and menus require phone testing; the raw Controller fallback is always explicit."],lookMode:"none")
        }
        guard ["inscryption","skald"].contains(kind) else { return nil }
        let inscryption = kind == "inscryption"
        let specs: [(String,String,String,String,String,Double,Double,Double)] = inscryption ? [
            ("forward","Step forward","bcd.up","key:87","hold",0.13,0.66,0.058),
            ("left","Turn left","bcd.left","key:65","hold",0.065,0.82,0.058),
            ("back","Step back","bcd.down","key:83","hold",0.13,0.82,0.058),
            ("right","Turn right","bcd.right","key:68","hold",0.195,0.82,0.058),
            ("interact","Interact","bcd.use","key:90","tap",0.86,0.77,0.075)
        ] : [
            ("interact","Interact","bcd.use","key:32","tap",0.87,0.77,0.075),
            ("confirm","Confirm","bcd.confirm","key:13","tap",0.95,0.52,0.055),
            ("back","Back","bcd.back","key:27","tap",0.95,0.29,0.055),
            ("journal","Journal","bcd.journal","key:74","tap",0.76,0.08,0.05),
            ("inventory","Inventory","bcd.pack","key:69","tap",0.88,0.08,0.05)
        ]
        let evidence = inscryption ? "inscryption-pc-input":"skald-shipped-input"
        let actions = specs.map { id,label,icon,output,behavior,_,_,_ in
            BCDControlPack.Action(id:id,label:label,icon:icon,output:output,behavior:behavior,evidence:evidence,contexts:["onFoot"])
        }
        let controls = specs.map { id,_,_,_,_,x,y,r in
            BCDControlPack.Control(id:id,action:id,role:"button",x:x,y:y,radius:r,hitRadius:r,opacity:0.72,labelPlacement:"inside",showLabel:false)
        }
        let layout = BCDControlPack.Layout(aimRect:.init(x:0.28,y:0.22,width:0.42,height:0.62),controls:controls)
        var padLayout=layout
        if inscryption {for i in 0..<4 {padLayout.controls[i].radius=0.048;padLayout.controls[i].hitRadius=0.048}}
        return .init(version:6,id:inscryption ? "inscryption-walking-v6":"skald-trackpad-v6",
            title:inscryption ? "Inscryption":"SKALD",identity:identity,inputMode:"keyboardMouse",aim:.init(),
            actions:actions,phone:layout,pad:padLayout,gestures:[],radial:[],contexts:["onFoot"],evidence:[
                .init(id:evidence,source:inscryption ? "Reviewed Inscryption PC input":"Reviewed SKALD keyboard controls",
                    detail:inscryption ? "W/S step forward/back, A/D turn, Z interact. The former left-side arrow cluster is a directional swipe zone during play, with unchanged editable anchors and bindings. Tap there still clicks; clean cardinal swipes pulse the existing binding without a click. Outside the zone, pointer dragging, stationary hold right-click and two-finger input remain unchanged. No Explore/Inspect mode.":
                    "Reviewed keyboard controls. Binary checksums and reverse-engineering offsets are omitted from this public source. Current personal remaps are not inferred.")
            ],unresolved:[inscryption ? "Physical game test pending.":"Utilities require the reviewed installed input files; personal game remaps can be assigned in the editor. Physical game test pending."],lookMode:"none")
    }
}
