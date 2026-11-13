import Foundation
@main struct ApprovedDefaultChecks {
    static func main() throws {
        func identity(_ exe:String)->BCDControlPack.Identity {.init(executable:exe,storeID:"local",edition:"installed",build:"fixture",bindingDigest:"fixture")}
        let config="[varcom]\nM=32\nN=0\nO=5\nP=1\nQ=2\nR=3\nT=6\nU=7\n"
        let bindings=[BCDChroniclesPack.configPath:config]
        let games=["QueensDomain.exe","SULFUR.exe","Dread Delusion.exe","Cotw.exe","TenebrisSomnia.exe","SKALD Against the Black Priory.exe","SlayTheSpire2.exe","Inscryption.exe"]
        for exe in games {
            let i=identity(exe)
            var old=BCDQueensDomainPack.make(identity:i);old.id="obsolete-generated-default"
            let route=BCDApprovedDefaultRouting.choose(i,bindings:bindings,local:nil,cached:old,customized:false)
            if ["SKALD Against the Black Priory.exe","SlayTheSpire2.exe","Inscryption.exe"].contains(exe) {
                assert(route.pack == nil && !route.table.isEmpty,"Table default must beat old cache")
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
