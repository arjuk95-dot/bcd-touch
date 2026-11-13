// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
/// Render/hit-routing view only: NEVER mutate personal JSON, action definitions,
/// sizes or positions. Retain hidden Attack geometry for LT slide-to-action routing.
enum BCDTenebrisOwnerCompatibility {
    static let aim = "raw-lt", attack = "raw-rt", movement = "raw-ls"
    static func matches(_ pack: BCDControlPack) -> Bool {
        guard pack.version == 3,pack.id == "tenebris-owner-mockup-v3",
              pack.inputMode == "controller",pack.lookMode == "none",
              pack.contexts.sorted() == ["menu","onFoot"],pack.gestures.isEmpty,
              (try? pack.validate(placement:.personal)) != nil else { return false }
        func action(_ id:String,_ output:String,_ behavior:String,_ contexts:[String]) -> Bool {
            let found=pack.actions.filter { $0.id == id }
            return found.count == 1 && found[0].output == output && found[0].behavior == behavior && found[0].contexts.sorted() == contexts.sorted()
        }
        return action(aim,"LT","toggle",["onFoot"]) && action(attack,"RT","tap",["onFoot"]) && action(movement,"LS","hold",["onFoot","menu"])
    }
    static func hiddenAttack(_ control:BCDControlPack.Control,in pack:BCDControlPack) -> Bool {
        matches(pack) && control.action == attack
    }
    /// Same nonnil Aim owner UUID, not merely 'aim currently on': off/on invalidates.
    static func attackAction(in pack:BCDControlPack,context:String,aimOwner:UUID?,contactAimOwner:UUID?) -> String? {
        guard matches(pack),context == "onFoot",let owner=aimOwner,owner == contactAimOwner else { return nil }
        return attack
    }
}
/// Caller arms only clear right-half contacts after buttons/movement/menu ownership
/// checks. Feed every move (including final point); invalidate on owner/context loss.
/// No changes to Aim toggle itself. Existing recognizer supplies max excursion/time.
struct BCDTenebrisOwnerTap {
    private var tap: BCDPackSurfaceTap
    init(start:CGPoint,time:Double,aimOwner:UUID) {
        tap=BCDPackSurfaceTap(action:"raw-rt",gate:"raw-lt",gateOwner:aimOwner,start:start,began:time)
    }
    mutating func moved(to point:CGPoint) { tap.moved(to:point) }
    func recognizes(end:CGPoint,time:Double,aimOwner:UUID?) -> Bool {
        tap.recognizes(end:end,time:time,gateOwner:aimOwner) &&
            max(tap.travel,hypot(end.x-tap.start.x,end.y-tap.start.y)) <= 8
    }
}
