import SwiftUI
import UIKit
@main struct PipelineApp:App {
    var body:some Scene {WindowGroup {Text("Production GamepadInput pipeline fixture · no guest").onAppear {run()}}}
    @MainActor func run() {
        let startupFolder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        try! FileManager.default.createDirectory(at:startupFolder,withIntermediateDirectories:true)
        try? Data("applicationState=\(UIApplication.shared.applicationState.rawValue)".utf8).write(to:startupFolder.appendingPathComponent("startup-state.txt"))
        guard UIApplication.shared.applicationState == .active else { DispatchQueue.main.asyncAfter(deadline:.now()+0.1){run()};return }
        if let selected=ProcessInfo.processInfo.environment["RESERVATION_FIXTURE"],let index=Int(selected) {
            let cases=[(false,false,true,0),(false,true,true,1),(true,false,true,1),(false,true,false,0),(true,false,false,0),(true,true,true,0)]
            let (force,game,touch,expected)=cases[index]
            BCDGyroLive.padNeeded=false
            MadeiraConfig.fixtureGameValues=game ? ["env.MADEIRA_PAD_EARLY_SLOT":"1"] : [:]
            if index==5 {
                GamepadInput.packKeyboardMouseSession=true
                MadeiraConfig.fixtureGameValues["env.MADEIRA_PAD_MODE"]="dualsense"
                GamepadInput.shared.beginPadSession()
                assert(GamepadInput.sessionHIDKind==nil && getenv("MADEIRA_HIDPAD")==nil)
                GamepadInput.shared.configurePack(enabled:true,accepting:true,calibration:.init())
                GamepadInput.shared.packTouch(owner:UUID(),value:TouchPadAction.sample("RT"))
            }
            GamepadInput.shared.reserveSessionSlot(touchControls:touch,force:force)
            DispatchQueue.main.asyncAfter(deadline:.now()+0.12) {
                assert(PipelineSpy.read().0.connected==Int32(expected),"Merged per-game and forced-pack startup policy failed")
                if index==5 {assert(PipelineSpy.disconnectedCount()>0,"KB/M isolation was never sampled")}
                let file=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("reservation-\(index).txt")
                try! Data("PASS: production reservation case \(index), connected=\(expected)\(index==5 ? "; cursor pack suppresses reserved XInput and configured DualSense HID":""). Simulator engine spy; no guest.".utf8).write(to:file)
            }
            return
        }
        let pad=GamepadInput.shared, move=UUID(), fire=UUID(), secondFire=UUID(), look=UUID()
        let c=BCDMouseJoystick.Calibration()
        pad.start()
        DispatchQueue.main.asyncAfter(deadline:.now()+0.5) {
            pad.configurePack(enabled:true,accepting:true,calibration:c)
            pad.packTouch(owner:move,value:TouchPadAction.sample("LS",x:-0.7))
            pad.packTouch(owner:fire,value:TouchPadAction.sample("RT"))
            pad.packTouch(owner:secondFire,value:TouchPadAction.sample("RT"))
            let t=ProcessInfo.processInfo.systemUptime
            // A real event can be 40 ms old when UIKit delivers it. It must
            // still publish now, then expire on the captured delivery clock.
            pad.packLook(owner:look,phase:0,time:t-0.09,receivedAt:t-1.0/60)
            pad.packLook(owner:look,phase:1,dx:2,dy:0,time:t-0.04,receivedAt:t)
            DispatchQueue.main.asyncAfter(deadline:.now()+0.15) {
                let (state,simultaneous,gyro)=PipelineSpy.read()
                assert(simultaneous && gyro && state.lx<0 && state.right_trigger==255 && state.rx==0 && state.ry==0)
                // A second finger/configuration pass must not clear held movement/fire.
                // Touch-only packs do not depend on the keyboard/mouse focus cache.
                HardwareInput.shared.baseFocused=false
                pad.configurePack(enabled:true,accepting:true,calibration:c)
                pad.packTouch(owner:fire,value:nil)
                DispatchQueue.main.asyncAfter(deadline:.now()+0.1) {
                    assert(PipelineSpy.read().0.right_trigger==255 && PipelineSpy.read().0.lx<0)
                    pad.packFocusLost()
                    pad.packTouch(owner:move,value:TouchPadAction.sample("LS",x:1))
                    DispatchQueue.main.asyncAfter(deadline:.now()+0.1) {
                        let s=PipelineSpy.read().0
                        assert(s.connected==1 && s.lx==0 && s.right_trigger==0 && s.rx==0 && s.ry==0)
                        let receipt="PASS: merged per-game/forced-pack/default-off startup reservations and no-source rejection; production GamepadInput serial publisher observed simultaneous slot0 LS/RT/RS from a 40ms-old touch event using captured delivery time; stale aim neutralized; gyro stage saw held trigger; repeated configuration preserved movement/fire; stale keyboard focus did not erase pack input; independent fire release; explicit pack focus loss rejected delayed input. Engine-spy simulator fixture, no Wine guest or physical controller."
                        let file=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("pipeline-receipt.txt")
                        try? Data(receipt.utf8).write(to:file)
                    }
                }
            }
        }
    }
}
