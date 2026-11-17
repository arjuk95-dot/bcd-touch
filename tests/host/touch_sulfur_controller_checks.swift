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
    for layout in [p.phone,p.pad] {
        let jump=layout.controls.first{$0.action == "jump"}!
        assert(jump.role == "button" && jump.showLabel == false && jump.y+jump.hitRadius <= layout.aimRect.y)
    }
    assert(p.actions.first{$0.id == "jump"}?.icon == "bcd.jump")
    assert(BCDSulfurPack.doubleTapAim(in:p,context:"onFoot")?.output == "LT")
    assert(BCDSulfurPack.doubleTapAim(in:p,context:"inventory") == nil)
    var rebound=p;rebound.actions[rebound.actions.firstIndex{$0.id == "aim"}!].output="RB"
    assert(BCDSulfurPack.doubleTapAim(in:rebound,context:"onFoot")?.output == "RB")
    var baseline=p
    for i in baseline.phone.controls.indices where baseline.phone.controls[i].action == "melee" {baseline.phone.controls[i].role="button"}
    for i in baseline.pad.controls.indices where baseline.pad.controls[i].action == "melee" {baseline.pad.controls[i].role="button"}
    baseline.radial.insert("jump",at:2)
    baseline.phone.controls.removeAll{$0.action == "jump"};baseline.pad.controls.removeAll{$0.action == "jump"}
    baseline.actions[baseline.actions.firstIndex{$0.id == "jump"}!].icon="arrow.up"
    assert(BCDSulfurPack.isPreviousDefault(baseline))
    var personal=baseline
    var jump=p.phone.controls.first{$0.action == "jump"}!;jump.id="my-jump";jump.x=0.6;jump.y=0.4;jump.radius=0.07;jump.hitRadius=0.07
    personal.phone.controls.append(jump)
    let merged=try BCDPackAuthoring.merge(base:p,personal:personal,baseline:baseline)
    assert(merged.phone.controls.filter{$0.action == "jump"} == [jump])
    assert(merged.pad.controls.contains{$0.action == "jump"})
    let defaults=UserDefaults(suiteName:"bcd.sulfur.gyro.tests."+UUID().uuidString)!
    let key="fixture.gyro",path="Games/Sulfur/Sulfur.exe"
    BCDSulfurGyroDefaults.seed(path,storeKey:key,defaults:defaults)
    assert((defaults.dictionary(forKey:key) as? [String:[String:String]])?[path]?["gyro-aim"] == "mouse")
    defaults.removeObject(forKey:key) // existing UI stores gyro-off by removing its line
    BCDSulfurGyroDefaults.seed(path,storeKey:key,defaults:defaults)
    assert(defaults.object(forKey:key) == nil)
    let customPath="custom/Sulfur.exe",custom=["gyro-aim":"stick","gyro-sens":"2"]
    defaults.set([customPath:custom],forKey:key)
    BCDSulfurGyroDefaults.seed(customPath,storeKey:key,defaults:defaults)
    assert((defaults.dictionary(forKey:key) as? [String:[String:String]])?[customPath] == custom)
    let savedChoices:[[String:String]]=[[:],["gyro-aim":"off"],["gyro-aim":""]]
    for saved in savedChoices {
        let savedPath="saved-"+UUID().uuidString+"/Sulfur.exe"
        defaults.set([savedPath:saved],forKey:key)
        BCDSulfurGyroDefaults.seed(savedPath,storeKey:key,defaults:defaults)
        assert((defaults.dictionary(forKey:key) as? [String:[String:String]])?[savedPath] == saved)
    }
    defaults.set("preserve malformed legacy data",forKey:key)
    BCDSulfurGyroDefaults.seed("other/Sulfur.exe",storeKey:key,defaults:defaults)
    assert(defaults.string(forKey:key) == "preserve malformed legacy data")
    var wrong=id;wrong.storeID="steam:881100";assert(!BCDSulfurPack.matches(wrong))
    for layout in [p.phone,p.pad] {
        assert(layout.controls.first{$0.action=="jump"}?.role=="button")
        assert(layout.controls.first{$0.action=="jump"}?.radius ?? 0 >= 0.05)
        for id in ["attack","melee"] {
            let current=layout.controls.first{$0.action==id}!
            assert(current.role=="fireAim")
            var old=current;old.role="button"
            assert(BCDSulfurPack.combatDragRole(pack:p,control:old,context:"onFoot"))
            assert(!BCDSulfurPack.combatDragRole(pack:p,control:old,context:"inventory"))
            var rebound=p;rebound.actions[rebound.actions.firstIndex{$0.id==id}!].output="Y"
            assert(!BCDSulfurPack.combatDragRole(pack:rebound,control:old,context:"onFoot"))
            var other=p;other.id="other-personal-pack"
            assert(!BCDSulfurPack.combatDragRole(pack:other,control:old,context:"onFoot"))
        }
    }
    assert(!p.radial.contains("jump"))
    assert(p.actions.first{$0.id=="jump"}?.output=="B")
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
