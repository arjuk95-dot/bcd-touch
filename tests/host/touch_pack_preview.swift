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
                if ProcessInfo.processInfo.environment["PACK_FIXTURES"] == "1" { captureFixtures() }
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
}
