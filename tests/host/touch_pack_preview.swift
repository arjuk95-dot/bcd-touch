// Simulator-only harness. Production renderer, engine stubs, no guest game.
import SwiftUI
import UIKit
@main struct TouchPackPreview: App {
    let pack: BCDControlPack = try! BCDControlPack.decode(Data(contentsOf: Bundle.main.url(forResource:"pack",withExtension:"json")!))
    var body: some Scene {
        WindowGroup {
            ZStack(alignment:.top) {
                Color(red:0.06,green:0.08,blue:0.09)
                BCDPackSurface(pack:pack,context:pack.contexts[0],debug:ProcessInfo.processInfo.environment["PACK_DEBUG"] == "1",editing:false)
                VStack {
                    Text("SIMULATOR HUD PREVIEW · NO GAME").font(.caption.bold())
                    Text(pack.title + " · binding meanings unresolved").font(.caption2)
                }.foregroundStyle(.white).allowsHitTesting(false).padding(.top,8)
            }.ignoresSafeArea().statusBarHidden().onAppear {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue,forKey:"orientation")
                if ProcessInfo.processInfo.environment["PACK_FIXTURES"] == "1" {
                    captureFixtures()
                    Task { @MainActor in
                        do { try await checkStoreClient() }
                        catch {
                            let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
                            try? Data(String(describing:error).utf8).write(to:folder.appendingPathComponent("client-error.txt"))
                            assertionFailure("Production store client fixture failed: \(error)")
                        }
                    }
                }
            }
        }
    }
    @MainActor private func captureFixtures() {
        let folder = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        for title in ["dread-delusion","chronicles-of-the-wolf"] {
            guard let url=Bundle.main.url(forResource:title,withExtension:"json"), let data=try? Data(contentsOf:url), let original=try? BCDControlPack.decode(data) else { continue }
            let expected = ["steam:1574240":"b2c8962db5b66d02870857cbc88678f5bc0f7e2357445534b137f349aeada2c8", "steam:2371890":"e055f885bade4adf937e0229ee017112a040cebef41b3f6202d0039a49115a65"]
            let key = BCDPackStore.hash(BCDPackStore.encoded(original.identity))
            assert(key == expected[original.identity.storeID], "Swift/worker identity hash mismatch")
            try? Data(key.utf8).write(to:folder.appendingPathComponent(title+"-swift-identity.txt"))
            for isPad in [false,true] {
                let size=isPad ? CGSize(width:1194,height:834) : CGSize(width:956,height:440)
                let insets=isPad ? UIEdgeInsets(top:24,left:0,bottom:20,right:0) : UIEdgeInsets(top:0,left:62,bottom:21,right:62)
                var p=original
                if isPad { p.phone=p.pad }
                for debug in [false,true] {
                    let view=BCDPackView();view.frame=CGRect(origin:.zero,size:CGSize(width:size.width-insets.left-insets.right,height:size.height-insets.top-insets.bottom))
                    view.configure(p,context:p.contexts[0],debug:debug,editing:false)
                    let format=UIGraphicsImageRendererFormat();format.scale=isPad ? 2 : 3;format.opaque=true
                    let image=UIGraphicsImageRenderer(size:size,format:format).image { context in
                        UIColor(red:0.06,green:0.08,blue:0.09,alpha:1).setFill();context.fill(CGRect(origin:.zero,size:size))
                        context.cgContext.saveGState();context.cgContext.translateBy(x:insets.left,y:insets.top)
                        view.draw(view.bounds);context.cgContext.restoreGState()
                        let label="SIMULATOR RENDERER FIXTURE · \(isPad ? "iPad geometry" : "phone geometry") · NO GAME"
                        (label as NSString).draw(at:CGPoint(x:size.width*0.27,y:5),withAttributes:[.font:UIFont.systemFont(ofSize:10),.foregroundColor:UIColor.white])
                    }
                    let name=title+"-"+(isPad ? "pad" : "phone")+"-"+(debug ? "hits" : "hud")+".png"
                    try? image.pngData()?.write(to:folder.appendingPathComponent(name))
                }
                // Unsupported context must leave no button, radial or gesture drawing.
                // Acquisition uses the same visibility predicate, avoiding invisible blockers.
                let hidden=BCDPackView();hidden.frame=CGRect(x:0,y:0,width:320,height:180)
                hidden.configure(p,context:"unsupported-context-fixture",debug:false,editing:false)
                let transparent=UIGraphicsImageRendererFormat();transparent.scale=1;transparent.opaque=false
                let empty=UIGraphicsImageRenderer(size:hidden.bounds.size,format:transparent).image { _ in hidden.draw(hidden.bounds) }
                let pixels=empty.cgImage!.dataProvider!.data! as Data
                assert(pixels.allSatisfy { $0 == 0 }, "Inactive context has visible controls")
            }
            try? Data("PASS: inactive context hides all acquisition regions, radial and gesture controls".utf8).write(to:folder.appendingPathComponent(title+"-context-visibility.txt"))
        }
    }
    @MainActor private func checkStoreClient() async throws {
        let original=try BCDControlPack.decode(Data(contentsOf:Bundle.main.url(forResource:"dread-delusion",withExtension:"json")!))
        var entry=LibraryEntry();entry.title="Dread Delusion";entry.steamAppID=1574240
        entry.launchRelativePath=original.identity.executable;entry.relativePath=original.identity.executable
        let store=BCDPackStore.shared, folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        let req=store.request(entry)
        assert(req.identity==original.identity)
        let key=BCDPackStore.hash(BCDPackStore.encoded(req.identity))
        let cached=store.folder.appendingPathComponent(key+".json")
        let index=original.phone.controls.firstIndex { $0.role=="move" }!
        let movedX=0.13
        if ProcessInfo.processInfo.environment["PACK_CLIENT_RESUME"]=="1" {
            store.activate(entry)
            assert(store.pack?.phone.controls[index].x==movedX, "Personal edit lost after process restart")
            assert(store.pack?.title==original.title+" fixture regeneration", "Wrong cached pack after restart")
            try Data("PASS: fresh simulator app process restored generated cache and personal override; engine boundaries stubbed, no installed game".utf8).write(to:folder.appendingPathComponent("client-phase-2.txt"),options:.atomic)
            return
        }
        try BCDPackStore.encoded(original).write(to:cached,options:.atomic)
        store.prepare(entry);store.prepare(entry)
        assert(store.status=="Validated cached pack")
        store.activate(entry)
        var moved=store.pack!;moved.phone.controls[index].x=movedX;store.saveEdits(moved)
        var regenerated=original;regenerated.title += " fixture regeneration"
        try BCDPackStore.encoded(regenerated).write(to:cached,options:.atomic)
        LibraryModel.shared.blocksGameplayTouch=true;store.activate(entry)
        assert(store.pack?.title==regenerated.title && store.pack?.phone.controls[index].x==movedX)
        LibraryModel.shared.blocksGameplayTouch=false
        var invalid=original;invalid.version=999
        try BCDPackStore.encoded(invalid).write(to:cached,options:.atomic)
        let offline=BCDPackStore.Worker(url:"https://127.0.0.1:9",token:"simulator-loopback-fixture-only")
        try BCDPackStore.encoded(offline).write(to:store.folder.appendingPathComponent("worker.json"),options:.atomic)
        entry.id=UUID();store.activate(entry);store.prepare(entry);store.prepare(entry)
        assert(store.pack==nil, "Invalid cache became active")
        for _ in 0..<100 {
            if store.status.hasPrefix("Stock/cached fallback") { break }
            try await Task.sleep(nanoseconds:100_000_000)
        }
        assert(store.status.hasPrefix("Stock/cached fallback"), "Offline worker did not preserve fallback")
        let jobs=try JSONDecoder().decode([String:BCDPackStore.Job].self,from:Data(contentsOf:store.folder.appendingPathComponent("jobs.json")))
        assert(jobs.count==1 && jobs[key]?.attempts==1, "Duplicate preparation created duplicate jobs")
        try BCDPackStore.encoded(regenerated).write(to:cached,options:.atomic)
        try Data("PASS: production Swift store cached/duplicate preparation, invalid cache rejection, real loopback connection failure fallback, and moved override after simulated cache regeneration. Simulator fixture; no real install-completion event or guest.".utf8).write(to:folder.appendingPathComponent("client-phase-1.txt"),options:.atomic)
    }
}
