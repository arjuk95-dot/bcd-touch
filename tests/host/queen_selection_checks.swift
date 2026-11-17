import Foundation

/// Production store fixture. Only simulator Documents and synthetic identities are touched.
@MainActor func checkQueenExplicitSelection() throws {
    var store=BCDPackStore.shared
    for (executable,expectedID) in [("QueensDomain.exe","queens-domain-v6"),("Sulfur.exe","sulfur-minimal-controller-v6")] {
    var entry=LibraryEntry();entry.title="Explicit selection fixture"
    entry.relativePath="fixture-reviewed-selection/"+executable;entry.launchRelativePath=entry.relativePath
    let identity=store.request(entry).identity
    let key=BCDPackStore.hash(BCDPackStore.encoded([identity.executable,identity.storeID,identity.edition]))
    let local=store.folder.appendingPathComponent("local-"+key+".json")
    var previous=BCDApprovedDefaultRouting.defaultPack(identity,bindings:[:],cached:nil)!
    previous.id="old-personal-queen-fixture"
    previous.actions[0].label="Previous custom move"
    let bytes=BCDPackStore.encoded(previous);try bytes.write(to:local,options:.atomic)
    UserDefaults.standard.set(true,forKey:"TouchPackLocal."+key)
    store.selectReviewedProfile(entry,selected:false)
    store.activate(nil);store.applyLaunchPreference(entry);store.activate(entry)
    assert(store.pack?.id==previous.id,"Previous local Queen layout not selected")
    var edited=store.pack!;edited.actions[0].label="Retained custom move"
    assert(store.saveEdits(edited),"Could not create old custom edit")
    let editsURL=store.folder.appendingPathComponent("personal-edits-v2.json")
    let editsBefore=try Data(contentsOf:editsURL)
    store.selectReviewedProfile(entry,selected:true)
    assert(store.pack?.id==previous.id,"Selection mutated running input session")
    store.activate(nil);store.applyLaunchPreference(entry);store.activate(entry)
    assert(store.enabled && store.pack?.id==expectedID,"Explicit new profile lost to local choice")
    assert(store.pack?.actions[0].label != "Retained custom move","Old edits leaked into new profile")
    let retained=try Data(contentsOf:local),retainedEdits=try Data(contentsOf:editsURL)
    assert(retained==bytes && retainedEdits==editsBefore,"Explicit choice modified previous data")
    var newEdit=store.pack!;newEdit.actions[0].label="New custom move"
    assert(store.saveEdits(newEdit),"New profile customization failed")
    store.selectReviewedProfile(entry,selected:false)
    store.activate(nil);store=BCDPackStore(folder:store.folder);store.applyLaunchPreference(entry);store.activate(entry)
    assert(store.pack?.id==previous.id && store.pack?.actions[0].label=="Retained custom move","Restoring previous lost its edits")
    store.selectReviewedProfile(entry,selected:true)
    store.activate(nil);store=BCDPackStore(folder:store.folder);store.applyLaunchPreference(entry);store.activate(entry)
    assert(store.pack?.id==expectedID && store.pack?.actions[0].label=="New custom move","New profile edits did not survive switch")
    store.setLaunchPreference(entry,generated:false);store.prepare(entry);store.applyLaunchPreference(entry)
    assert(!store.enabled,"Preparation overrode explicit stock choice")
    store.activate(nil)
    }
    let output=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("queen-explicit-selection.txt")
    try Data("PASS: explicit Queen and SULFUR selection bypasses old local layout, preserves old and new edits separately, retains local/cache files, waits for relaunch and honors stock choice. Simulator store, not guest.".utf8).write(to:output)
}
