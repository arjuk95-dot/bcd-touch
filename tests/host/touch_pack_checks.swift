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
        // Real touch source timestamps can precede delivery by several frames.
        // Velocity uses source time; expiry must use the publisher's receipt clock.
        var delayed=BCDMouseJoystick()
        delayed.begin(time:1000,receivedAt:10)
        delayed.move(dx:5,dy:0,time:1000.016,receivedAt:10.056,calibration:calibration)
        assert(delayed.sample(time:10.057).x>0,"Delayed fresh motion was discarded on arrival")
        assert(delayed.sample(time:10.105).x==0,"Source clock offset sustained stale motion")
        delayed.reset();assert(delayed.sample(time:10.057).x==0)
        var deliveryRecords:[[String:Double]]=[]
        for sourceHz in [60.0,120.0] {
            for batchHz in [30.0,60.0,120.0] where batchHz<=sourceHz {
                for fps in [30.0,60.0] {
                    var aim=BCDMouseJoystick();aim.begin(time:0,receivedAt:50.04)
                    var previousSource=0.0,lastReceipt=0.0
                    for batch in 1...20 {
                        let source=floor(Double(batch)/batchHz*sourceHz+0.000001)/sourceHz
                        let receipt=50.04+Double(batch)/batchHz
                        aim.move(dx:300*(source-previousSource),dy:0,time:source,receivedAt:receipt,calibration:calibration)
                        assert(aim.sample(time:receipt+0.001).x>0,"Coalesced batch arrived expired")
                        // Four-millisecond publications remain live until the next batch.
                        for tick in stride(from:0.004,to:1/batchHz,by:0.004) {
                            assert(aim.sample(time:receipt+tick).x>0,"Continuous delivered sweep contains a neutral gap")
                        }
                        previousSource=source;lastReceipt=receipt
                    }
                    var neutral=0.0
                    for ms in stride(from:0.0,through:60.0,by:4.0) {
                        if aim.sample(time:lastReceipt+ms/1000).x==0 {neutral=ms;break}
                    }
                    assert(neutral>0 && neutral<=44,"Stationary thumb output outlived its delivery deadline")
                    // The publisher clock is independent of touch delivery and
                    // the game's frame clock. Exercise their relative phases;
                    // a loop that merely labels a result with FPS misses this.
                    var worstPublishedNeutral=0.0,worstFrameNeutral=0.0
                    let firstReceipt=50.04+1/batchHz
                    for publisherPhase in [0.0,0.001,0.0039] {
                        var sampledAim=BCDMouseJoystick()
                        sampledAim.begin(time:0,receivedAt:50.04)
                        var nextBatch=1,previous=0.0
                        var publications:[(time:Double,x:Double)]=[]
                        var firstNeutral:Double?
                        for tick in 0...Int(ceil((lastReceipt-50.04+0.15)/0.004)) {
                            let clock=50.04+publisherPhase+Double(tick)*0.004
                            while nextBatch<=20 && 50.04+Double(nextBatch)/batchHz<=clock {
                                let source=floor(Double(nextBatch)/batchHz*sourceHz+0.000001)/sourceHz
                                sampledAim.move(dx:300*(source-previous),dy:0,time:source,
                                                receivedAt:50.04+Double(nextBatch)/batchHz,calibration:calibration)
                                previous=source;nextBatch+=1
                            }
                            let output=sampledAim.sample(time:clock).x
                            publications.append((clock,output))
                            if clock>=firstReceipt+0.004 && clock<lastReceipt {
                                assert(output>0,"Independent publisher clock missed a continuous sweep")
                            }
                            if clock>=lastReceipt && output==0 && firstNeutral==nil {firstNeutral=clock}
                        }
                        let publishedNeutral=try require(firstNeutral,"Publisher did not neutralize")
                        let publishedMs=(publishedNeutral-lastReceipt)*1000
                        assert(publishedMs>0 && publishedMs<=46.001,"Independent clock exceeded expiry plus one 4ms tick")
                        worstPublishedNeutral=max(worstPublishedNeutral,publishedMs)
                        for framePhase in [0.0,0.25,0.5,0.75] {
                            var firstNeutralFrame:Double?
                            for frame in 0...Int(ceil((lastReceipt-50.04+0.15)*fps)) {
                                let time=50.04+(Double(frame)+framePhase)/fps
                                guard time>=firstReceipt+0.008,
                                      let snapshot=publications.last(where:{$0.time<=time}) else {continue}
                                if time<lastReceipt {assert(snapshot.x>0,"Game frame missed a continuous published sweep")}
                                if time>=lastReceipt && snapshot.x==0 {firstNeutralFrame=time;break}
                            }
                            let observed=try require(firstNeutralFrame,"Game frame never observed neutral")
                            let frameMs=(observed-lastReceipt)*1000
                            assert(frameMs<=46.001+1000/fps,"Neutral was not visible within one game frame of publication")
                            worstFrameNeutral=max(worstFrameNeutral,frameMs)
                        }
                    }
                    deliveryRecords.append(["sourceHz":sourceHz,"deliveryHz":batchHz,"gameFPS":fps,"deliveryDelayMs":40,
                                            "alignedNeutralMs":neutral,"worstPublishedNeutralMs":worstPublishedNeutral,
                                            "worstFrameNeutralMs":worstFrameNeutral])
                    // Work queued before a pause cannot renew itself when processed late.
                    assert(aim.sample(time:lastReceipt+0.2).x==0)
                }
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
        let d = try JSONSerialization.data(withJSONObject: ["kind":"host fixture, production Swift arithmetic/state", "timing":records,"delayedDelivery":deliveryRecords],options:[.prettyPrinted,.sortedKeys])
        print(String(data:d,encoding:.utf8)!)
        print("PASS: simultaneous LS/RT/RS, duplicate fire release, reversals, saturation, stale expiry, reset, pause, physical arbitration and invalid packs")
    }
    static func require<T>(_ value:T?,_ message:String) throws -> T {
        guard let value=value else {throw NSError(domain:"TouchPackChecks",code:1,userInfo:[NSLocalizedDescriptionKey:message])}
        return value
    }
}
