import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
@main struct ApprovedDefaultChecks {
    static func main() throws {
        func identity(_ exe:String)->BCDControlPack.Identity {.init(executable:exe,storeID:"local",edition:"installed",build:"fixture",bindingDigest:"fixture")}
        let config="[varcom]\nM=32\nN=0\nO=5\nP=1\nQ=2\nR=3\nT=6\nU=7\n"
        let bindings=[BCDChroniclesPack.configPath:config]
        let wgi="MADEIRA_WGI_HOST_PADS"
        func currentWGI()->String? {getenv(wgi).map{String(cString:$0)}}
        let originalWGI=currentWGI()
        defer {if let originalWGI {setenv(wgi,originalWGI,1)} else {unsetenv(wgi)}}
        // Exercise production route/factory code for two consecutive titles;
        // ContentView's separate source contract forbids a late global mutation.
        let inheritedChoices:[String?]=[nil,"0","1"]
        for explicit in inheritedChoices {
            if let explicit {setenv(wgi,explicit,1)} else {unsetenv(wgi)}
            let sulfur=BCDApprovedDefaultRouting.choose(identity("Sulfur.exe"),bindings:[:],local:nil,cached:nil,customized:false)
            assert(sulfur.pack?.id == "sulfur-minimal-controller-v6" && currentWGI() == explicit)
            let next=BCDApprovedDefaultRouting.choose(identity("QueensDomain.exe"),bindings:[:],local:nil,cached:nil,customized:false)
            assert(next.pack?.id == "queens-domain-v6" && currentWGI() == explicit,"Sulfur -> another title must leave the inherited WGI setting unchanged, including explicit zero")
        }
        let games=["QueensDomain.exe","SULFUR.exe","Dread Delusion.exe","Cotw.exe","TenebrisSomnia.exe","SKALD Against the Black Priory.exe","SlayTheSpire2.exe","Inscryption.exe"]
        for exe in games {
            let i=identity(exe)
            var old=BCDQueensDomainPack.make(identity:i);old.id="obsolete-generated-default"
            let route=BCDApprovedDefaultRouting.choose(i,bindings:bindings,local:nil,cached:old,customized:false)
            if exe == "SlayTheSpire2.exe" {
                assert(route.pack?.id == "spire2-touch-v6" && route.table.isEmpty,"Editable direct-touch default must beat old cache")
                try route.pack!.validate(for:i,placement:.personal)
            } else {
                assert(route.pack != nil && route.pack!.id != old.id,"Reviewed pack must beat old generated cache: \(exe)")
                try route.pack!.validate(for:i,placement:.personal)
            }
            let personal=BCDApprovedDefaultRouting.choose(i,bindings:bindings,local:old,cached:nil,customized:false)
            assert(personal.pack?.id == old.id && personal.table.isEmpty,"Explicit personal layout retained")
            let edited=BCDApprovedDefaultRouting.choose(i,bindings:bindings,local:nil,cached:old,customized:true)
            assert(edited.pack?.id == old.id && edited.table.isEmpty,"Genuine saved edits retained")
            let fresh=BCDApprovedDefaultRouting.choose(i,bindings:bindings,local:nil,cached:nil,customized:false)
            assert(fresh.pack != nil || !fresh.table.isEmpty,"No cache required: \(exe)")
        }
        let wolf=identity("Cotw.exe")
        assert(BCDApprovedDefaultRouting.choose(wolf,bindings:[:],local:nil,cached:nil,customized:false).pack == nil)
        let unknown=identity("unknown.exe")
        assert(BCDApprovedDefaultRouting.choose(unknown,bindings:[:],local:nil,cached:nil,customized:false).pack == nil)
        // Dock folder identities remain unchanged; only matching/proof paths differ.
        var dock=identity("Steam/common/Opaque folder");dock.storeID="steam:2371890"
        let dockPack=BCDApprovedDefaultRouting.choose(dock,bindings:bindings,local:nil,cached:nil,customized:false).pack
        assert(dockPack?.id == "chronicles-reviewed-controller-v6" && dockPack?.identity == dock)
        for (id,kind) in [(1069160,"skald"),(2868840,"spire2"),(1092790,"inscryption")] {
            dock.storeID="steam:\(id)"
            assert(BCDApprovedDefaultRouting.tableKind(dock)==kind)
        }
        dock.storeID="steam:1";assert(!BCDChroniclesPack.matches(dock) && BCDApprovedDefaultRouting.tableKind(dock).isEmpty)
        dock.storeID="steam:1799840"
        assert(BCDQueensDomainPack.matches(dock))
        assert(BCDApprovedDefaultRouting.choose(dock,bindings:[:],local:nil,cached:nil,customized:false).pack?.id == "queens-domain-v6")
        dock.storeID="steam:1";dock.executable="QueensDomain.exe"
        assert(!BCDQueensDomainPack.matches(dock),"A different Steam ID must not borrow Queen's bindings")
        let queenID=identity("QueensDomain.exe")
        let previous=BCDQueensDomainPack.make(identity:queenID,glyphs:false)
        let upgraded=BCDApprovedDefaultRouting.choose(queenID,bindings:[:],local:previous,cached:nil,customized:false).pack!
        assert(upgraded.phone.controls.allSatisfy{$0.showLabel == false})
        var moved=previous;moved.phone.controls[2].x=0.63
        assert(BCDApprovedDefaultRouting.choose(queenID,bindings:[:],local:moved,cached:nil,customized:false).pack == moved)
        var provenance=previous;provenance.unresolved=["updated diagnostic"]
        assert(!BCDApprovedDefaultRouting.hasPersonalChanges(provenance,baseline:previous))
        assert(BCDApprovedDefaultRouting.hasPersonalChanges(moved,baseline:previous))
        assert(BCDApprovedDefaultRouting.choose(queenID,bindings:[:],local:previous,cached:nil,customized:true,mergeable:false).pack == previous,"Unknown legacy edit provenance must block default migration")
        assert(BCDApprovedDefaultRouting.choose(queenID,bindings:[:],local:nil,cached:previous,customized:true,mergeable:true).pack == upgraded)
        let merged=try BCDPackAuthoring.merge(base:upgraded,personal:moved,baseline:previous)
        assert(merged.phone.controls[2].x == moved.phone.controls[2].x && merged.phone.controls[2].showLabel == false)
        let reloaded=try BCDControlPack.decode(JSONEncoder().encode(merged),for:queenID,placement:.personal)
        assert(reloaded == merged)
        for kind in ["inscryption","skald","spire2"] {
            let base=BCDTablePack.make(identity("fixture-\(kind).exe"),kind:kind)!
            try base.validate()
            assert(base.contexts == ["onFoot"])
            if kind != "spire2" {assert(base.phone.controls.allSatisfy{$0.showLabel == false})}
            var personal=base
            personal.phone.controls[0].x=0.5;personal.phone.controls[0].y=0.55
            personal.phone.controls[0].radius=0.09;personal.phone.controls[0].hitRadius=0.095
            personal.phone.controls[0].showLabel=true;personal.phone.controls[0].coordinateSpace="screen"
            personal.pad.controls[1].opacity=0.8;personal.actions[0].output=kind == "spire2" ? "X":"key:88"
            let result=try BCDPackAuthoring.merge(base:base,personal:personal,baseline:base)
            assert(result.phone.controls[0] == personal.phone.controls[0] && result.pad.controls[1] == personal.pad.controls[1])
            assert(result.actions[0].output == (kind == "spire2" ? "X":"key:88"))
            let restored=try BCDControlPack.decode(JSONEncoder().encode(result),for:base.identity,placement:.personal)
            assert(restored == result,"Customized table controls must survive encode/reload")
        }
        let drive=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:drive,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:drive)}
        func put(_ path:String) throws {
            let file=drive.appendingPathComponent(path)
            try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
            try Data("fixture".utf8).write(to:file)
        }
        let root="Steam/common/Opaque"
        try put(root+"/Sulfur.exe")
        let known=BCDApprovedDefaultRouting.installedExecutable(relativePath:root,launchRelativePath:root,steamProgram:nil,steamAppID:2124120,drive:drive)
        assert(known?.lastPathComponent=="Sulfur.exe")
        let direct=BCDApprovedDefaultRouting.installedExecutable(relativePath:root+"/Sulfur.exe",launchRelativePath:root+"/Sulfur.exe",steamProgram:nil,steamAppID:nil,drive:drive)
        assert(direct==known)
        try put(root+"/bin/Recorded.exe")
        assert(BCDApprovedDefaultRouting.installedExecutable(relativePath:root,launchRelativePath:root,steamProgram:"bin/Recorded.exe",steamAppID:2124120,drive:drive)?.lastPathComponent=="Recorded.exe")
        for (id,name) in [(1069160,"SKALD Against the Black Priory.exe"),(2868840,"SlayTheSpire2.exe"),(2371890,"Cotw.exe")] {
            try put(root+"/"+name)
            assert(BCDApprovedDefaultRouting.installedExecutable(relativePath:root,launchRelativePath:root,steamProgram:nil,steamAppID:id,drive:drive)?.lastPathComponent==name)
        }
        for bad in ["../escape","/absolute","C:\\escape","a//b","a/./b"] {
            assert(BCDApprovedDefaultRouting.installedExecutable(relativePath:bad,launchRelativePath:root,steamProgram:nil,steamAppID:2124120,drive:drive)==nil)
        }
        try put("outside.exe")
        assert(BCDApprovedDefaultRouting.installedExecutable(relativePath:root,launchRelativePath:"outside.exe",steamProgram:"../../outside.exe",steamAppID:1,drive:drive)==nil)
        try FileManager.default.createSymbolicLink(at:drive.appendingPathComponent(root+"/escape.exe"),withDestinationURL:drive.appendingPathComponent("outside.exe"))
        assert(BCDApprovedDefaultRouting.installedExecutable(relativePath:root,launchRelativePath:root,steamProgram:"escape.exe",steamAppID:1,drive:drive)==nil)
        print("PASS: all eight approved launch defaults replace stale generated caches; personal/local preserved; missing binding fails closed")
    }
}
