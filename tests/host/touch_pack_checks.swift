import Foundation

@main struct TouchPackChecks {
    static func main() throws {
        var records: [[String:Double]] = []
        let calibration = BCDMouseJoystick.Calibration()
        for hz in [60.0, 120.0] {
            for fps in [30.0, 60.0] {
                var aim = BCDMouseJoystick(); aim.begin(time: 0)
                var state = TouchGamepadState()
                let control = UUID(), move = UUID(), fire1 = UUID(), fire2 = UUID()
                state.configure([control])
                state.update(owner: move, control: control, value: TouchPadAction.sample("LS", x: -0.7, y: 0.2))
                state.update(owner: fire1, control: control, value: TouchPadAction.sample("RT"))
                state.update(owner: fire2, control: control, value: TouchPadAction.sample("RT"))
                let t = 1 / hz
                aim.move(dx: 0.2, dy: 0, time: t, calibration: calibration)
                let fine = aim.sample(time: t)
                assert(fine.x > 0 && fine.x < 0.3)
                assert(state.sample.lx < 0 && state.sample.rt == 255 && fine.x > 0)
                state.update(owner: fire1, control: control, value: nil)
                assert(state.sample.rt == 255) // independently held duplicate fire
                aim.move(dx: 10000, dy: 0, time: t*2, calibration: calibration)
                assert(aim.sample(time: t*2).x == 1) // saturation discards excess
                aim.move(dx: -1, dy: 0, time: t*3, calibration: calibration)
                assert(aim.sample(time: t*3).x < 0) // no accumulated flick to pay back
                var neutral = 0.0
                for ms in stride(from: 0.0, through: 40.0, by: 4.0) {
                    if aim.sample(time: t*3 + ms/1000).x == 0 { neutral = ms; break }
                }
                assert(neutral > 0 && neutral <= 28)
                records.append(["inputHz":hz,"gameFPS":fps,"samplingNeutralMs":neutral,"gameObservationUpperBoundMs":neutral+1000/fps])
                let resumed=t*3+1
                aim.move(dx:0.2,dy:0,time:resumed,calibration:calibration)
                assert(abs(aim.sample(time:resumed).x-fine.x)<0.00001, "First fine correction after resting was lost or diluted")
                assert(aim.sample(time:resumed+0.05).x==0, "An old queued event replayed motion")
                aim.begin(time:100)
                aim.move(dx:0.2,dy:0,time:100.5,calibration:calibration)
                assert(aim.sample(time:100.5).x>0, "First correction after landing and resting was lost")
                aim.reset(); assert(aim.sample(time:t*3).x == 0)
                state.configure([control], acceptingInput:false)
                assert(state.sample == GamepadSample())
                state.update(owner:move,control:control,value:TouchPadAction.sample("LS",x:1))
                assert(state.sample == GamepadSample()) // pause rejects delayed events
                state.configure([control]); state.clear()
                assert(state.sample == GamepadSample())
                let physical = TouchPadAction.sample("RS",x:0.9)
                assert(GamepadSample.merge(physical:physical,touch:TouchPadAction.sample("RS",x:-0.7)).rx == physical.rx)
            }
        }
        for path in CommandLine.arguments.dropFirst() {
            let p = try BCDControlPack.decode(Data(contentsOf: URL(fileURLWithPath:path)))
            var invalid = p; invalid.version = 2
            assert((try? invalid.validate()) == nil)
            invalid = p; invalid.phone.controls[0].hitRadius = 0.9
            assert((try? invalid.validate()) == nil)
            invalid = p; invalid.actions[0].output = "mouse:left"; invalid.inputMode = "controller"
            assert((try? invalid.validate()) == nil)
            invalid = p; invalid.identity.build = "wrong-build"
            assert((try? invalid.validate(for:p.identity)) == nil)
        }
        let d = try JSONSerialization.data(withJSONObject: ["kind":"host fixture, production Swift arithmetic/state", "timing":records],options:[.prettyPrinted,.sortedKeys])
        print(String(data:d,encoding:.utf8)!)
        print("PASS: simultaneous LS/RT/RS, duplicate fire release, reversals, saturation, stale expiry, reset, pause, physical arbitration and invalid packs")
    }
}
