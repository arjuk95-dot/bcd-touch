import Foundation
// Execute from the integration's existing model test main after adding the two sources.
func checkDreadTenebrisHelpers(root: URL) throws {
    let dread=try BCDControlPack.decode(Data(contentsOf:root.appendingPathComponent("packs/pilots/dread-delusion.json")))
    var id=dread.identity;id.executable="Games/Dread Delusion/DreadDelusion.exe";id.storeID="local"
    assert(BCDDreadPack.matches(id));var made=try BCDDreadPack.make(identity:id);made.identity=dread.identity;var expected=dread;expected.version=6;expected.lookMode="relativeMouse";assert(made==expected)
    id.storeID="steam:881100";assert(!BCDDreadPack.matches(id));id.storeID="steam:1574240";assert(BCDDreadPack.matches(id))
    id.storeID="local";id.executable="Dread Delusion.exe.bak";assert(!BCDDreadPack.matches(id))
    let owner=try BCDControlPack.decode(Data(contentsOf:root.appendingPathComponent("packs/personal/tenebris-somnia-owner-iphone.json")),placement:.personal)
    assert(BCDTenebrisOwnerCompatibility.matches(owner))
    var bad=owner;bad.version=5;assert(!BCDTenebrisOwnerCompatibility.matches(bad))
    for index in owner.actions.indices where ["raw-lt","raw-rt","raw-ls"].contains(owner.actions[index].id) {
        bad=owner;bad.actions[index].output="A";assert(!BCDTenebrisOwnerCompatibility.matches(bad))
        bad=owner;bad.actions[index].contexts=["menu"];assert(!BCDTenebrisOwnerCompatibility.matches(bad))
    }
    let token=UUID();assert(BCDTenebrisOwnerCompatibility.attackAction(in:owner,context:"onFoot",aimOwner:token,contactAimOwner:token)=="raw-rt")
    assert(BCDTenebrisOwnerCompatibility.attackAction(in:owner,context:"menu",aimOwner:token,contactAimOwner:token)==nil)
    assert(BCDTenebrisOwnerCompatibility.attackAction(in:owner,context:"onFoot",aimOwner:UUID(),contactAimOwner:token)==nil)
    let untouched=owner
    for c in owner.phone.controls { assert(BCDTenebrisOwnerCompatibility.hiddenAttack(c,in:owner)==(c.action=="raw-rt")) }
    assert(owner==untouched)
    var tap=BCDTenebrisOwnerTap(start:.zero,time:0,aimOwner:token)
    assert(tap.recognizes(end:CGPoint(x:8,y:0),time:0.35,aimOwner:token))
    assert(!tap.recognizes(end:CGPoint(x:8.01,y:0),time:0.2,aimOwner:token))
    assert(!tap.recognizes(end:.zero,time:0.351,aimOwner:token))
    assert(!tap.recognizes(end:.zero,time:-0.1,aimOwner:token))
    assert(!tap.recognizes(end:.zero,time:0.1,aimOwner:UUID()))
    tap.moved(to:CGPoint(x:9,y:0));tap.moved(to:.zero);assert(!tap.recognizes(end:.zero,time:0.2,aimOwner:token))
}
