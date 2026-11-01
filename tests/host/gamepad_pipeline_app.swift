import SwiftUI
import UIKit
@main struct PipelineApp:App {
    var body:some Scene {WindowGroup {Text("Production GamepadInput pipeline fixture · no guest").onAppear {run()}}}
    @MainActor func run() {
        guard UIApplication.shared.applicationState == .active else { DispatchQueue.main.asyncAfter(deadline:.now()+0.1){run()};return }
        let pad=GamepadInput.shared, move=UUID(), fire=UUID(), secondFire=UUID(), look=UUID()
        let c=BCDMouseJoystick.Calibration()
        pad.start()
        DispatchQueue.main.asyncAfter(deadline:.now()+0.5) {
            pad.configurePack(enabled:true,accepting:true,calibration:c)
            pad.packTouch(owner:move,value:TouchPadAction.sample("LS",x:-0.7))
            pad.packTouch(owner:fire,value:TouchPadAction.sample("RT"))
            pad.packTouch(owner:secondFire,value:TouchPadAction.sample("RT"))
            let t=ProcessInfo.processInfo.systemUptime
            pad.packLook(owner:look,phase:0,time:t-1.0/60)
            pad.packLook(owner:look,phase:1,dx:2,dy:0,time:t)
            DispatchQueue.main.asyncAfter(deadline:.now()+0.15) {
                let (state,simultaneous,gyro)=PipelineSpy.read()
                assert(simultaneous && gyro && state.lx<0 && state.right_trigger==255 && state.rx==0 && state.ry==0)
                pad.packTouch(owner:fire,value:nil)
                DispatchQueue.main.asyncAfter(deadline:.now()+0.1) {
                    assert(PipelineSpy.read().0.right_trigger==255)
                    pad.configurePack(enabled:true,accepting:false,calibration:c)
                    pad.packTouch(owner:move,value:TouchPadAction.sample("LS",x:1))
                    DispatchQueue.main.asyncAfter(deadline:.now()+0.1) {
                        let s=PipelineSpy.read().0
                        assert(s.connected==1 && s.lx==0 && s.right_trigger==0 && s.rx==0 && s.ry==0)
                        let receipt="PASS: production GamepadInput serial publisher observed simultaneous slot0 LS/RT/RS; stale aim neutralized; gyro stage saw held trigger; independent fire release; pause rejected delayed input. Engine-spy simulator fixture, no Wine guest or physical controller."
                        let file=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("pipeline-receipt.txt")
                        try? Data(receipt.utf8).write(to:file)
                    }
                }
            }
        }
    }
}
