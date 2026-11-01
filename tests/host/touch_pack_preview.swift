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
            }
        }
    }
}
