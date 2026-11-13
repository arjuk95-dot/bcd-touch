// Run with production BCDControlPack + V6 hybrid-look validator after integration.
import Foundation
func checkSulfurControllerModel() throws {
    let id=BCDControlPack.Identity(executable:"Games/SULFUR/Sulfur.exe",storeID:"local",edition:"installed",build:"fixture",bindingDigest:"fixture")
    let p=try BCDSulfurPack.make(identity:id)
    assert(p.inputMode=="controller" && p.lookMode=="relativeMouse")
    assert(p.contexts==["onFoot","inventory"])
    assert(p.actions.first{$0.id=="inventory-close"}?.output=="B")
    assert(p.actions.first{$0.id=="inventory"}?.output=="Menu")
    assert(p.actions.filter{$0.contexts.contains("inventory")}.allSatisfy{["LS","A","B","X","LB","RB"].contains($0.output)})
    assert(p.actions.allSatisfy { !$0.output.hasPrefix("key:") && !$0.output.hasPrefix("mouse:") })
    var wrong=id;wrong.storeID="steam:881100";assert(!BCDSulfurPack.matches(wrong))
    let sprint=p.actions.first{$0.id=="sprint"}!
    var choice=BCDSulfurSprintChoice()
    func allowed(_ c:BCDSulfurSprintChoice,_ action:BCDControlPack.Action?=nil)->Bool {
        c.allowed(active:true,verifiedBuild:true,inventory:false,identity:id,sprintAction:action ?? sprint)
    }
    choice.begin(saved:nil);assert(!allowed(choice))
    choice.begin(saved:nil,verifiedShippedDefault:true);assert(allowed(choice))
    let malformed:[Any] = [true,false,0,1,"","hold-left-shift-v1",BCDSulfurSprintChoice.disabled]
    for saved in malformed {
        choice.begin(saved:saved,verifiedShippedDefault:true);assert(!allowed(choice))
    }
    choice.begin(saved:BCDSulfurSprintChoice.nativeL3);assert(allowed(choice))
    var changed=sprint;changed.output="RT";assert(!allowed(choice,changed))
    changed=sprint;changed.behavior="hold";assert(!allowed(choice,changed))
    assert(!choice.allowed(active:true,verifiedBuild:false,inventory:false,identity:id,sprintAction:sprint))
    assert(!choice.allowed(active:true,verifiedBuild:true,inventory:true,identity:id,sprintAction:sprint))
    assert(!choice.allowed(active:false,verifiedBuild:true,inventory:false,identity:id,sprintAction:sprint))
    assert(!choice.allowed(active:true,verifiedBuild:true,inventory:false,identity:wrong,sprintAction:sprint))
    choice.end();assert(!allowed(choice))
    print("PASS: production SULFUR controller factory and strict sprint preference gates")
}
