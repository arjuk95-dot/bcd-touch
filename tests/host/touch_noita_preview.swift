// Actual production UIKit renders; simulated geometry and engine spies, no Noita guest.
import SwiftUI
import UIKit
extension TouchPackPreview {
    @MainActor func captureNoitaFixtures() throws {
        let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        let identity=BCDControlPack.Identity(executable:"noita.exe",storeID:"steam:881100",edition:"fixture",build:"fixture",bindingDigest:"fixture")
        let original=BCDNoitaPack.make(identity:identity);try original.validate()
        let store=BCDPackStore.shared
        var entry=LibraryEntry();entry.title="Noita";entry.steamAppID=881100;entry.launchRelativePath="noita.exe";entry.relativePath="noita.exe"
        store.applyLaunchPreference(entry);store.activate(entry)
        var edited=store.pack!;edited.phone.controls[0].radius=0.16;edited.phone.controls[0].hitRadius=0.16
        assert(store.saveEdits(edited));store.usePreset(entry);store.activate(nil)
        store.applyLaunchPreference(entry);store.activate(entry);assert(store.pack!.phone.controls[0].radius==0.16)
        store.setLaunchPreference(entry,generated:true);store.activate(nil);store.applyLaunchPreference(entry);store.activate(entry)
        assert(store.pack!.phone.controls[0].radius==0.16,"Built-in/local cursor pack switch lost personal controls")
        store.activate(nil)
        for isPad in [false,true] {
            let size=isPad ? CGSize(width:1180,height:820):CGSize(width:956,height:440)
            var p=original;if isPad {p.phone=p.pad}
            let view=BCDPackView();view.frame=CGRect(origin:.zero,size:size)
            view.configure(p,context:"onFoot",debug:false,editing:false)
            view.layoutIfNeeded()
            func render(_ name:String,debug:Bool=false) {
                view.configure(p,context:"onFoot",debug:debug,editing:false)
                let format=UIGraphicsImageRendererFormat();format.scale=1
                let image=UIGraphicsImageRenderer(size:size,format:format).image { context in
                    UIColor(red:0.07,green:0.08,blue:0.09,alpha:1).setFill();context.fill(CGRect(origin:.zero,size:size));view.draw(view.bounds)
                    let label="NOITA PACK · SIMULATOR PRODUCTION UI · \(isPad ? "iPad geometry":"phone geometry") · NO GAME"
                    (label as NSString).draw(at:CGPoint(x:8,y:size.height-14),withAttributes:[.font:UIFont.systemFont(ofSize:10),.foregroundColor:UIColor.white])
                }
                try! image.pngData()!.write(to:folder.appendingPathComponent("noita-"+(isPad ? "pad-":"phone-")+name+".png"))
            }
            render("idle-hud");render("idle-hits",debug:true)
            let engine=view.cursorEngine!
            assert(view.movementVisual==nil)
            let launcher=engine.center(p.phone.controls.first{$0.role=="radial"}!)
            if !isPad {
                let now=ProcessInfo.processInfo.systemUptime
                view.beginTouch("move",at:CGPoint(x:size.width*0.17,y:size.height*0.76),time:now)
                view.moveTouch("move",to:CGPoint(x:size.width*0.13,y:size.height*0.64),time:now+0.01)
                let fire=engine.center(p.phone.controls.first{$0.role=="fireAim"}!)
                view.beginTouch("look",at:CGPoint(x:size.width*0.62,y:size.height*0.5),time:now+0.02)
                view.moveTouch("look",to:fire,time:now+0.03)
                assert(engine.firing && engine.activeOutputs.contains("key:65") && engine.activeOutputs.contains("key:87"))
                render("move-flight-fire")
                view.clear();assert(engine.activeOutputs.isEmpty)
                view.beginTouch("radial",at:launcher,time:now+1)
                let r=engine.radialFrame
                view.moveTouch("radial",to:CGPoint(x:r.midX,y:r.minY+15),time:now+1.1)
                assert(!engine.firing && engine.mode == .equipment)
            } else { engine.begin("radial",at:launcher,time:1) }
            render("equipment")
            if !isPad {
                engine.switchMode(.utilities);render("more")
                engine.switchMode(.pointer);render("inventory-pointer")
                view.clear();assert(engine.activeOutputs.isEmpty)
                assert(engine.mode == .pointer,"Focus-style input clear must retain the explicit pointer mode")
                engine.switchMode(.gameplay)
                // Rotation invokes the production layoutSubviews cancellation.
                engine.begin("held",at:engine.center(p.phone.controls.first{$0.role=="fireAim"}!),time:4)
                assert(engine.firing);view.frame.size=CGSize(width:440,height:956);view.layoutIfNeeded();assert(!engine.firing && engine.activeOutputs.isEmpty)
                view.frame.size=size;view.layoutIfNeeded()
                view.configure(p,context:"onFoot",debug:true,editing:true)
                let image=UIGraphicsImageRenderer(size:size).image { _ in view.draw(view.bounds) }
                try image.pngData()!.write(to:folder.appendingPathComponent("noita-phone-editor-hits.png"))
                view.configure(p,context:"onFoot",debug:false,editing:false)
                let live=view.cursorEngine!
                for notification in [UIDevice.orientationDidChangeNotification,BCDPackFocus.didLoseFocus,UIApplication.willResignActiveNotification] {
                    view.beginTouch("interrupted-fire",at:view.controlCenter(p.phone.controls.first{$0.role=="fireAim"}!),time:ProcessInfo.processInfo.systemUptime)
                    assert(live.firing);NotificationCenter.default.post(name:notification,object:nil);assert(live.activeOutputs.isEmpty)
                }
            }
            view.clear()
        }
        let text="PASS: production UIKit cursor pack rendered idle/active movement+flight+fire, equipment, utilities, pointer and editor; actual activation regions; rotation and clear release outputs. iPhone simulator with offscreen phone/iPad geometry and engine spies, no running Noita or physical device."
        try Data(text.utf8).write(to:folder.appendingPathComponent("noita-ui-regression.txt"))
    }
}
